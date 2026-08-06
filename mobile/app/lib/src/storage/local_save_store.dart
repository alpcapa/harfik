// Devam eden yerel (YZ) oyunun kalıcılığı — web'deki gameStorage.ts'in
// karşılığı, üç yapısal garantiyle:
//
// 1. "Parse, don't validate": yükleme ya TAMAMEN geçerli bir GameState verir
//    ya hiç vermez — gameStateFromJson fırlatarak yarım state'i temsil
//    edilemez kılar (kelimeki_core codec sözleşmesi).
// 2. Karantina, ASLA silme: çözülemeyen/bilinmeyen-sürümlü kayıt
//    quarantined_saves'e taşınır ve kullanıcı temiz başlar — veri teşhis
//    için durur. Web'in "ErrorBoundary'den elle kaydı sil" kaçış kapağının
//    (PORT_BRIEF §7: gameStorage çökmeye karşı tam güvenli değil) kayıpsız
//    otomatiği.
// 3. Versiyonlu payload: her kayıt payload_version taşır; şekil değişirse
//    _payloadMigrations'a adım eklenir. Zinciri olmayan sürüm = karantina.
//
// 7 günlük terk-edilme kuralı web ile AYNI (ABANDON_TIMEOUT_MS/savedAt
// gerekçeleri dahil): süre SON KAYIT anından sayılır; dolmuşsa kayıt
// pending_events'e (abandonedGameKind) taşınır — ceza/telemetri kararını
// üst katman verir (web'deki takePendingAbandonedGame akışı), depolama
// yalnızca mekaniği sağlar. Yüklenen oyun web'deki gibi multiSession=true
// işaretlenir.
import 'dart:convert';

import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:sqflite/sqflite.dart';

import 'pending_event_store.dart' show abandonedGameKind;

/// Kayıt payload'ının şema sürümü — GameState JSON şekli değişirse artır ve
/// _payloadMigrations'a eski→yeni dönüştürme adımı ekle.
const int kSavePayloadVersion = 1;

/// Web'deki ABANDON_TIMEOUT_MS ile aynı süre/gerekçe.
const Duration abandonTimeout = Duration(days: 7);

/// Misafirin tekil kayıt slotu (web'deki tek localStorage anahtarının
/// karşılığı; girişli kullanıcı sunucudaki local_game_saves'i kullanır —
/// senkron katmanı ayrı faz).
const String guestSaveSlot = 'guest';

/// Sürüm N-1 → N payload dönüşümleri. Anahtar: HEDEF sürüm.
final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
    _payloadMigrations = {};

class LocalSaveStore {
  final Database db;
  final int Function() nowMs;
  LocalSaveStore(this.db, this.nowMs);

  Future<void> save(String slot, GameState state) async {
    await db.insert(
      'local_saves',
      {
        'slot': slot,
        'payload_version': kSavePayloadVersion,
        'payload': jsonEncode(gameStateToJson(state)),
        'saved_at': nowMs(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clear(String slot) async {
    await db.delete('local_saves', where: 'slot = ?', whereArgs: [slot]);
  }

  Future<bool> exists(String slot) async {
    final rows = await db.query('local_saves',
        columns: ['slot'], where: 'slot = ?', whereArgs: [slot]);
    return rows.isNotEmpty;
  }

  /// Kaydı yükler. Üç sonuç: geçerli state (multiSession=true ile), null
  /// (kayıt yok / süresi dolup pending_events'e taşındı / bozuk olup
  /// karantinaya taşındı). null dönüşünde slot her durumda temizlenmiştir —
  /// çökme döngüsü yapısal olarak imkânsız: aynı bozuk kayıt ikinci kez
  /// yüklenemez.
  Future<GameState?> load(String slot) async {
    final rows =
        await db.query('local_saves', where: 'slot = ?', whereArgs: [slot]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final savedAt = row['saved_at'] as int;
    final version = row['payload_version'] as int;
    final payload = row['payload'] as String;

    // Terk edilme: son kayıttan bu yana 7 gün — kayıt cezalandırma kararı
    // için olay kuyruğuna taşınır (web: PendingAbandonedGame).
    if (nowMs() - savedAt > abandonTimeout.inMilliseconds) {
      await db.transaction((txn) async {
        await txn.insert('pending_events', {
          'kind': abandonedGameKind,
          'payload': jsonEncode({'savedAt': savedAt, 'state': payload}),
          'created_at': nowMs(),
        });
        await txn.delete('local_saves', where: 'slot = ?', whereArgs: [slot]);
      });
      return null;
    }

    try {
      var json = (jsonDecode(payload) as Map).cast<String, Object?>();
      var v = version;
      while (v < kSavePayloadVersion) {
        final step = _payloadMigrations[v + 1];
        if (step == null) {
          throw StateError('payload migrasyonu eksik: v${v + 1}');
        }
        json = step(json);
        v++;
      }
      if (v != kSavePayloadVersion) {
        // Gelecekten gelen kayıt (uygulama geri alınmış) — asla tahmin etme.
        throw StateError('bilinmeyen payload sürümü: $version');
      }
      final state = gameStateFromJson(json);
      // Web parity: kayıttan dönen oyun "çok oturumlu" işaretlenir
      // (gameStorage.ts loadGameState — geri dönüşü yok).
      return state.copyWith(multiSession: true);
    } catch (e) {
      await _quarantine(slot, version, payload, e.toString());
      return null;
    }
  }

  Future<void> _quarantine(
      String slot, int version, String payload, String reason) async {
    await db.transaction((txn) async {
      await txn.insert('quarantined_saves', {
        'slot': slot,
        'payload_version': version,
        'payload': payload,
        'reason': reason,
        'quarantined_at': nowMs(),
      });
      await txn.delete('local_saves', where: 'slot = ?', whereArgs: [slot]);
    });
  }

  /// Teşhis amaçlı: karantinadaki kayıt sayısı (UI'da "kurtarılamayan kayıt"
  /// bildirimi ileride buradan beslenebilir).
  Future<int> quarantineCount() async {
    final rows =
        await db.rawQuery('select count(*) as c from quarantined_saves');
    return rows.first['c'] as int;
  }
}
