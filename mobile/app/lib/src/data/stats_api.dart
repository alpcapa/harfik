// Skor kartı / k-lig verisi — web `fetchPlayerStats`/`fetchLeaderboard`/
// `fetchMyLeaderboardRank` (src/lib/api.ts) portu.
//
// Üç view/RPC de SALT OKUNUR; hepsi girişli her kullanıcıya açık (k-lig
// herkese görünür bir sıralama, `games`in SELECT RLS'i de girişliye açık) —
// bu yüzden ne yazma kuyruğu ne dayanıklılık katmanı var: ağ hatasında null
// dönülür, çağıran "yükleniyor/hata" ile "veri yok"u ayırt eder.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Skor kartı sekmesi: Genel (iki modun toplamı) / 2 / 4 kişilik.
/// Web `TabKey` ('all' | 2 | 4).
enum StatsTab {
  all('Genel'),
  two('2 Oyunculu'),
  four('4 Oyunculu');

  final String label;
  const StatsTab(this.label);

  /// `player_stats.player_count` filtresi — 'all' ayrı bir view kullanır.
  int? get playerCount => switch (this) {
        StatsTab.all => null,
        StatsTab.two => 2,
        StatsTab.four => 4,
      };
}

/// Web `PlayerStats` — `player_stats` / `player_stats_overall` view satırı.
class PlayerStats {
  final int gamesPlayed;
  final int localGamesPlayed;
  final int onlineGamesPlayed;
  final int firstPlaces;
  final int secondPlaces;
  final int surrenderedCount;
  final int bestScore;
  final int? bestMoveScore;
  final int? bestWordScore;
  final double? avgMoveScore;
  final String? longestWord;

  /// Lig puanı (k-lig) — ham oyun skorlarının toplamı DEĞİL.
  final int totalScore;

  const PlayerStats({
    required this.gamesPlayed,
    required this.localGamesPlayed,
    required this.onlineGamesPlayed,
    required this.firstPlaces,
    required this.secondPlaces,
    required this.surrenderedCount,
    required this.bestScore,
    required this.bestMoveScore,
    required this.bestWordScore,
    required this.avgMoveScore,
    required this.longestWord,
    required this.totalScore,
  });

  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
  static int? _ni(Object? v) => (v as num?)?.toInt();

  factory PlayerStats.fromJson(Map<String, Object?> j) => PlayerStats(
        gamesPlayed: _i(j['games_played']),
        localGamesPlayed: _i(j['local_games_played']),
        onlineGamesPlayed: _i(j['online_games_played']),
        firstPlaces: _i(j['first_places']),
        secondPlaces: _i(j['second_places']),
        surrenderedCount: _i(j['surrendered_count']),
        bestScore: _i(j['best_score']),
        bestMoveScore: _ni(j['best_move_score']),
        bestWordScore: _ni(j['best_word_score']),
        avgMoveScore: (j['avg_move_score'] as num?)?.toDouble(),
        longestWord: j['longest_word'] as String?,
        totalScore: _i(j['total_score']),
      );
}

/// Web `LeaderboardRow` — `leaderboard` view satırı.
class LeaderboardRow {
  final String userId;
  final String? displayName;
  final String? firstName;
  final String? avatarUrl;
  final int totalScore;

  const LeaderboardRow({
    required this.userId,
    required this.displayName,
    required this.firstName,
    required this.avatarUrl,
    required this.totalScore,
  });

  /// Herkese açık bir sıralama olduğundan tam ad/soyad DEĞİL, oyun içindeki
  /// kısa kimlik kuralı (web `shortDisplayName`): nickname yoksa yalnız ad.
  String get shortName => (displayName?.isNotEmpty ?? false)
      ? displayName!
      : (firstName?.isNotEmpty ?? false)
          ? firstName!
          : 'Anonim';

  factory LeaderboardRow.fromJson(Map<String, Object?> j) => LeaderboardRow(
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String?,
        firstName: j['first_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        totalScore: (j['total_score'] as num?)?.toInt() ?? 0,
      );
}

/// Web `MyLeaderboardRank` — `my_leaderboard_rank` RPC çıktısı.
class MyLeaderboardRank {
  final int rank;
  final int totalScore;
  const MyLeaderboardRank({required this.rank, required this.totalScore});
}

/// Üç sorgunun soyutlaması — testler bellek içi sahteyle çalışır, gerçek uç
/// (`SupabaseStatsGateway`) cihazda doğrulanır.
abstract class StatsGateway {
  /// [playerCount] null ise `player_stats_overall` ("Genel" sekmesi), aksi
  /// halde `player_stats` (o oyuncu sayısı). Satır yoksa null.
  Future<Map<String, Object?>?> playerStats(String userId, int? playerCount);

  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset);

  Future<Map<String, Object?>?> myLeaderboardRank(String userId);
}

class SupabaseStatsGateway implements StatsGateway {
  final SupabaseClient client;
  SupabaseStatsGateway(this.client);

  @override
  Future<Map<String, Object?>?> playerStats(
      String userId, int? playerCount) async {
    // 'Genel' AYRI bir view'dan gelir: avg_move_score bir AĞIRLIKLI ortalama,
    // longest_word iki alt sorgu arası karşılaştırma — iki hazır satırdan
    // client-side doğru birleştirilemezler (web'in aynı gerekçesi).
    final q = playerCount == null
        ? client.from('player_stats_overall').select().eq('user_id', userId)
        : client
            .from('player_stats')
            .select()
            .eq('user_id', userId)
            .eq('player_count', playerCount);
    final row = await q.maybeSingle();
    return row?.cast<String, Object?>();
  }

  @override
  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset) async {
    final rows = await client
        .from('leaderboard')
        .select()
        .order('total_score', ascending: false)
        .range(offset, offset + limit - 1);
    return [for (final r in rows) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<Map<String, Object?>?> myLeaderboardRank(String userId) async {
    final data =
        await client.rpc('my_leaderboard_rank', params: {'p_user_id': userId});
    final row = data is List && data.isNotEmpty ? data.first : data;
    return row is Map ? row.cast<String, Object?>() : null;
  }
}

class StatsRepo {
  final StatsGateway gateway;
  StatsRepo(this.gateway);

  /// null: satır yok (hiç oyun kaydı yok) YA DA ağ hatası — ikisi de UI'da
  /// aynı "veri yok" hâline düşer (web davranışı birebir).
  Future<PlayerStats?> playerStats(String userId, StatsTab tab) async {
    try {
      final row = await gateway.playerStats(userId, tab.playerCount);
      return row == null ? null : PlayerStats.fromJson(row);
    } catch (e) {
      debugPrint('[Kelimeki] playerStats hatası: $e');
      return null;
    }
  }

  Future<List<LeaderboardRow>> leaderboard(
      {required int limit, required int offset}) async {
    try {
      final rows = await gateway.leaderboard(limit, offset);
      return [for (final r in rows) LeaderboardRow.fromJson(r)];
    } catch (e) {
      debugPrint('[Kelimeki] leaderboard hatası: $e');
      return const [];
    }
  }

  Future<MyLeaderboardRank?> myRank(String userId) async {
    try {
      final row = await gateway.myLeaderboardRank(userId);
      if (row == null) return null;
      return MyLeaderboardRank(
        rank: (row['rank'] as num).toInt(),
        totalScore: (row['total_score'] as num).toInt(),
      );
    } catch (e) {
      debugPrint('[Kelimeki] myLeaderboardRank hatası: $e');
      return null;
    }
  }
}
