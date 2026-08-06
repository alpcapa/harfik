// Offline/misafir kuyrukları — web'deki gameSync.ts (bitmiş oyunlar) ve
// feedbackSync.ts (geri bildirim) desenlerinin ortak depolama tabanı:
// istemci üretimli id (sunucu 23505 dedup'ıyla eşleşir), tür başına üst
// sınır (en eskiler düşer), okumada 7 günlük TTL süpürmesi. Kuyruğu
// SUNUCUYA boşaltan flush mantığı senkron fazının işi — burada yalnızca
// dayanıklı saklama.
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Web'deki MAX_PENDING_GAMES ile aynı sınır/gerekçe.
const int kMaxPendingPerKind = 300;

/// Web'deki PENDING_EXPIRY_MS ile aynı süre/gerekçe (ABANDON_TIMEOUT'la
/// bilinçli olarak aynı 7 gün).
const Duration pendingExpiry = Duration(days: 7);

const String finishedGameKind = 'finished-game';
const String feedbackKind = 'feedback';

class QueueEntry {
  final String id;
  final String kind;
  final Map<String, Object?> payload;
  final int createdAt;
  const QueueEntry({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });
}

class PendingQueueStore {
  final Database db;
  final int Function() nowMs;
  PendingQueueStore(this.db, this.nowMs);

  /// Aynı id ikinci kez eklenirse SESSİZCE yok sayılır (ilk kayıt kalır) —
  /// id'nin varlık sebebi zaten "aynı kayıt iki kez işlenmesin".
  Future<void> enqueue({
    required String kind,
    required String id,
    required Map<String, Object?> payload,
    int? createdAt,
  }) async {
    await db.transaction((txn) async {
      await txn.insert(
        'pending_queue',
        {
          'id': id,
          'kind': kind,
          'payload': jsonEncode(payload),
          'created_at': createdAt ?? nowMs(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      // Tür başına üst sınır: en eskiler düşer (web'deki aynı politika).
      await txn.rawDelete('''
        delete from pending_queue where kind = ? and id not in (
          select id from pending_queue where kind = ?
          order by created_at desc limit ?
        )''', [kind, kind, kMaxPendingPerKind]);
    });
  }

  /// Süresi dolanları KALICI olarak düşürüp kalanları en eskiden yeniye
  /// döner (web readQueue davranışı: TTL okuma anında uygulanır).
  Future<List<QueueEntry>> readAll(String kind) async {
    final cutoff = nowMs() - pendingExpiry.inMilliseconds;
    await db.delete('pending_queue',
        where: 'kind = ? and created_at < ?', whereArgs: [kind, cutoff]);
    final rows = await db.query('pending_queue',
        where: 'kind = ?', whereArgs: [kind], orderBy: 'created_at asc');
    return [
      for (final r in rows)
        QueueEntry(
          id: r['id'] as String,
          kind: r['kind'] as String,
          payload:
              (jsonDecode(r['payload'] as String) as Map).cast<String, Object?>(),
          createdAt: r['created_at'] as int,
        ),
    ];
  }

  /// Başarıyla sunucuya işlenen kayıt kuyruktan düşer (flush fazı çağırır).
  Future<void> remove(String id) async {
    await db.delete('pending_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count(String kind) async {
    final rows = await db.rawQuery(
        'select count(*) as c from pending_queue where kind = ?', [kind]);
    return rows.first['c'] as int;
  }
}
