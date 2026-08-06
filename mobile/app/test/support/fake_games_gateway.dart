// `GamesGateway`'in bellek içi sahtesi — üç test dosyası paylaşır
// (game_record, local_game_repo, setup_cloud). Gerçek uç
// (`SupabaseGamesGateway`) cihazda doğrulanır.
import 'package:kelimeki/src/data/games_api.dart';

class FakeGamesGateway implements GamesGateway {
  /// null = misafir (oturum yok) — flush ağa hiç dokunmaz.
  String? userId;
  final inserted = <Map<String, Object?>>[];
  final finishes = <Map<String, Object?>>[];
  final notified = <({String gameId, int playerCount})>[];

  /// Bir sonraki insert ağ hatasıyla düşsün (kuyruk davranışı testi).
  bool failNextInsert = false;

  FakeGamesGateway({this.userId});

  Map<String, Object?>? rowById(String id) {
    for (final r in inserted) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  @override
  String? get currentUserId => userId;

  @override
  Future<({String id, bool alreadyExisted})> insertGame(
      Map<String, Object?> row, String uid) async {
    if (failNextInsert) {
      failNextInsert = false;
      throw Exception('ağ hatası');
    }
    final id = row['id'] as String;
    if (rowById(id) != null) {
      return (id: id, alreadyExisted: true); // sunucudaki 23505 eşleniği
    }
    inserted.add({...row, 'user_id': uid});
    return (id: id, alreadyExisted: false);
  }

  @override
  Future<void> logGameFinish({
    required String? userId,
    required int playerCount,
    required int durationSeconds,
    required bool multiSession,
    required bool endedBySurrender,
  }) async {
    finishes.add({
      'user_id': userId,
      'player_count': playerCount,
      'duration_seconds': durationSeconds,
      'multi_session': multiSession,
      'ended_by_surrender': endedBySurrender,
    });
  }

  @override
  Future<void> notifyLocalGameAbandoned(String gameId, int playerCount) async {
    notified.add((gameId: gameId, playerCount: playerCount));
  }
}
