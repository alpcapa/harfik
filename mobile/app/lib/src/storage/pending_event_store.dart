// Tek seferlik oku-ve-temizle olayları — web'deki iki read-then-clear
// deseninin (kelimeki:pending-abandoned-game, pending-friend-invite-token)
// ortak tabanı. takeAll SELECT+DELETE'i TEK transaction'da yapar: web'de
// StrictMode'un çift çalıştırmasına karşı "ikinci okuma boş döner" diye
// savunulan davranış burada atomiklikle garanti.
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

const String abandonedGameKind = 'abandoned-game';
const String friendInviteTokenKind = 'friend-invite-token';

class PendingEventStore {
  final Database db;
  final int Function() nowMs;
  PendingEventStore(this.db, this.nowMs);

  Future<void> add(String kind, Map<String, Object?> payload) async {
    await db.insert('pending_events', {
      'kind': kind,
      'payload': jsonEncode(payload),
      'created_at': nowMs(),
    });
  }

  /// Türün TÜM olaylarını döner ve siler — atomik; aynı olay iki kez
  /// işlenemez.
  Future<List<Map<String, Object?>>> takeAll(String kind) async {
    return db.transaction((txn) async {
      final rows = await txn.query('pending_events',
          where: 'kind = ?', whereArgs: [kind], orderBy: 'created_at asc');
      if (rows.isNotEmpty) {
        await txn
            .delete('pending_events', where: 'kind = ?', whereArgs: [kind]);
      }
      return [
        for (final r in rows)
          (jsonDecode(r['payload'] as String) as Map).cast<String, Object?>(),
      ];
    });
  }
}
