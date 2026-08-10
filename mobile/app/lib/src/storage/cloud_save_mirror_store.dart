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

/// Sunucudan SON BAŞARIYLA çekilen listenin yerel kopyası — yalnızca
/// offline'da "Devam Eden Oyunlar"ı çizebilmek için (Parça 43).
///
/// **`CloudSaveMirrorStore` ile karıştırma:** o, sunucuya YAZILAMAMIŞ
/// state'i tutar (kaynak kayıt — kaybolursa gerçekten veri kaybı olur, bu
/// yüzden çözülemeyen satır karantinaya alınır). Bu ise sunucuda ZATEN
/// duran satırların salt gösterim kopyasıdır; bozulursa en fazla offline
/// liste eksik görünür, o yüzden çözülemeyen satır sessizce atlanır.
class CloudSaveCacheStore {
  final Database db;
  final int Function() nowMs;
  CloudSaveCacheStore(this.db, this.nowMs);

  /// Bu kullanıcının önbelleğini TAMAMEN değiştirir — sunucudan başarılı bir
  /// liste geldiğinde çağrılır. Silinen satırların önbellekte kalmaması için
  /// tek transaction'da önce temizler, sonra yazar.
  Future<void> replaceAll(
      String userId, List<({String id, GameState state, int updatedAtMs})> rows) async {
    await db.transaction((txn) async {
      await txn
          .delete('cloud_save_cache', where: 'user_id = ?', whereArgs: [userId]);
      for (final r in rows) {
        await txn.insert('cloud_save_cache', {
          'id': r.id,
          'user_id': userId,
          'payload_version': kSavePayloadVersion,
          'payload': jsonEncode(gameStateToJson(r.state)),
          'updated_at': r.updatedAtMs,
        });
      }
    });
  }

  /// Önbellekteki satırlar, en yeni önce. Çözülemeyen/bilinmeyen sürümlü
  /// satır ATLANIR (bkz. sınıf yorumu — burada karantina gereksiz).
  Future<List<MirroredSave>> read(String userId) async {
    final rows = await db.query('cloud_save_cache',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'updated_at desc');
    final out = <MirroredSave>[];
    for (final row in rows) {
      final version = row['payload_version'] as int;
      if (version != kSavePayloadVersion) continue;
      try {
        final json =
            (jsonDecode(row['payload'] as String) as Map).cast<String, Object?>();
        out.add(MirroredSave(
          id: row['id'] as String,
          state: gameStateFromJson(json),
          savedAtMs: row['updated_at'] as int,
        ));
      } catch (_) {
        // Gösterim kopyası — sessizce atla.
      }
    }
    return out;
  }

  Future<void> remove(String id) async {
    await db.delete('cloud_save_cache', where: 'id = ?', whereArgs: [id]);
  }
}


/// Sunucuda silinmeyi bekleyen bulut kayıtları (Parça 46). Yalnızca id
/// taşır — silinecek satırın içeriğini saklamanın anlamı yok; `user_id`
/// kuyruğu hesaba göre kapsamak için (başka bir hesap açıkken onun adına
/// silme denemek RLS'te sessiz no-op olur ve kuyruk sonsuza dek dolu
/// kalırdı).
class CloudSaveDeleteQueue {
  final Database db;
  final int Function() nowMs;
  CloudSaveDeleteQueue(this.db, this.nowMs);

  Future<void> add(String id, String userId) async {
    await db.insert(
      'pending_cloud_deletes',
      {'id': id, 'user_id': userId, 'queued_at': nowMs()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String id) async {
    await db.delete('pending_cloud_deletes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> pending(String userId) async {
    final rows = await db.query('pending_cloud_deletes',
        columns: ['id'],
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'queued_at');
    return [for (final r in rows) r['id'] as String];
  }
}
