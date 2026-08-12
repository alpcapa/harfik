// Oyun başına "son görülen sohbet mesajı" damgası — web'deki
// kelimeki:chat-last-read:<gameId> anahtarlarının tablo karşılığı.
// Tamamen cihaza özel/tek taraflı bir işaret; sunucuya okundu bilgisi
// gitmez (web'deki aynı bilinçli sınır).
import 'package:sqflite/sqflite.dart';

class ChatReadStore {
  final Database db;
  ChatReadStore(this.db);

  Future<int?> lastReadAt(String gameId) async {
    final rows = await db
        .query('chat_last_read', where: 'game_id = ?', whereArgs: [gameId]);
    return rows.isEmpty ? null : rows.first['last_read_at'] as int;
  }

  Future<void> markRead(String gameId, int atMs) async {
    await db.insert(
      'chat_last_read',
      {'game_id': gameId, 'last_read_at': atMs},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Oyun listeden tamamen düştüğünde damga da temizlenir (sınırsız satır
  /// birikmesin — prefs yerine tablo seçilmesinin gerekçesi).
  Future<void> remove(String gameId) async {
    await db
        .delete('chat_last_read', where: 'game_id = ?', whereArgs: [gameId]);
  }
}
