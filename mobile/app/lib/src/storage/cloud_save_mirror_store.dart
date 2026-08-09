// Girişli kullanıcının devam eden YZ oyunlarının YEREL AYNASI — sunucudaki
// `local_game_saves`e yazılamayan state'i tutar ve bağlantı dönünce itilir.
//
// **Neden `local_saves`i (misafir slotu) yeniden kullanmıyoruz:** o tablonun
// `load()`u iki karar veriyor ve ikisi de bulut kayıtları için YANLIŞ olurdu:
// (1) 7 günlük terk-edilme süpürmesi — bulut satırının cezası sunucu
// tarafında `claimAbandoned` ile veriliyor, aynı oyunu bir de yerelden
// süpürmek MÜKERRER -2 cezası demek olurdu (girişli kullanıcının yerele hiç
// yazmama kararının asıl gerekçesi buydu, bkz. Parça 3a); (2) yüklenen
// state'i `multiSession=true` işaretlemesi — bulut devamı web'de de mobilde
// de bunu bilinçli olarak İŞARETLEMİYOR.
//
// Depolama katmanının diğer üç kuralı aynen geçerli: versiyonlu payload,
// "parse, don't validate", ve çözülemeyen kaydın SİLİNMEYİP karantinaya
// taşınması.
import 'dart:convert';

import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:sqflite/sqflite.dart';

import 'local_save_store.dart' show kSavePayloadVersion;

/// Sunucuya henüz yazılamamış tek bir bulut kaydı.
class MirroredSave {
  final String id;
  final GameState state;
  final int savedAtMs;

  const MirroredSave(
      {required this.id, required this.state, required this.savedAtMs});
}

class CloudSaveMirrorStore {
  final Database db;
  final int Function() nowMs;
  CloudSaveMirrorStore(this.db, this.nowMs);

  /// Ayna kaydını yazar/günceller. Her autosave'de çağrılır — yerel yazma
  /// her zaman başarılı olduğundan, sunucu erişilemese bile hamle kaybolmaz.
  Future<void> put(String id, String userId, GameState state) async {
    await db.insert(
      'pending_cloud_saves',
      {
        'id': id,
        'user_id': userId,
        'payload_version': kSavePayloadVersion,
        'payload': jsonEncode(gameStateToJson(state)),
        'saved_at': nowMs(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Sunucuya başarıyla yazıldığında (ya da satır silindiğinde) çağrılır.
  Future<void> remove(String id) async {
    await db.delete('pending_cloud_saves', where: 'id = ?', whereArgs: [id]);
  }

  /// Bu kullanıcının bekleyen TÜM aynaları, en yeni önce. Çözülemeyen
  /// kayıtlar karantinaya taşınır ve sonuçta yer ALMAZ — bozuk bir ayna
  /// listeyi ya da flush'ı kilitleyemez.
  Future<List<MirroredSave>> pending(String userId) async {
    final rows = await db.query('pending_cloud_saves',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'saved_at desc');
    final out = <MirroredSave>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final version = row['payload_version'] as int;
      final payload = row['payload'] as String;
      try {
        if (version != kSavePayloadVersion) {
          // Gelecekten gelen kayıt (uygulama geri alınmış) — asla tahmin
          // etme. `local_saves`'in migrasyon zinciriyle aynı ilke; bu tablo
          // v1'de doğduğu için henüz dönüştürme adımı yok.
          throw StateError('bilinmeyen payload sürümü: $version');
        }
        final json = (jsonDecode(payload) as Map).cast<String, Object?>();
        out.add(MirroredSave(
          id: id,
          state: gameStateFromJson(json),
          savedAtMs: row['saved_at'] as int,
        ));
      } catch (e) {
        await _quarantine(id, version, payload, e.toString());
      }
    }
    return out;
  }

  Future<void> _quarantine(
      String id, int version, String payload, String reason) async {
    await db.transaction((txn) async {
      await txn.insert('quarantined_saves', {
        // `local_saves` ile aynı karantina tablosunu paylaşıyoruz; kaynağı
        // ayırt etmek için slot'a önek konuyor.
        'slot': 'cloud:$id',
        'payload_version': version,
        'payload': payload,
        'reason': reason,
        'quarantined_at': nowMs(),
      });
      await txn
          .delete('pending_cloud_saves', where: 'id = ?', whereArgs: [id]);
    });
  }
}
