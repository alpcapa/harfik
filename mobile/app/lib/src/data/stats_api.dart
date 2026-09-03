// Skor kartı / k-lig verisi — web `fetchPlayerStats`/`fetchLeaderboard`/
// `fetchMyLeaderboardRank` (src/lib/api.ts) portu.
//
// Üç view/RPC de SALT OKUNUR; hepsi girişli her kullanıcıya açık (k-lig
// herkese görünür bir sıralama, `games`in SELECT RLS'i de girişliye açık) —
// bu yüzden ne yazma kuyruğu ne dayanıklılık katmanı var: ağ hatasında null
// dönülür, çağıran "yükleniyor/hata" ile "veri yok"u ayırt eder.
import 'package:flutter/foundation.dart';

import '../util/head_to_head.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/offline_notice.dart';
import 'error_reporter.dart';
import 'profile_fields.dart';

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
  /// 12 Ağustos 2026'dan beri eşik ödülleri de DAHİL (bkz. [bonusPoints]).
  final int totalScore;

  /// [totalScore]'a dahil edilen toplam eşik ödülü puanı — "Genel =
  /// 2 kişilik + 4 kişilik" değişmezi artık "… + ödül puanı"; farkı bu alan
  /// taşır ve rütbe bilgi popup'ı bunu açıkça gösterir. YALNIZCA
  /// `player_stats_overall`'da var (ödül moda bölünemez) — mod bazlı
  /// satırlarda null.
  final int? bonusPoints;

  /// Ulaşılan en yüksek rütbe eşiği (0=Çaylak) — yalnızca
  /// `player_stats_overall`'da. **UI bunu OKUMUYOR:** rütbe 12 Ağustos
  /// 2026'dan beri güncel puandan türetiliyor ("düşmeli" sürüm,
  /// `tierFor(totalScore)`); kolon yalnızca "hangi eşikler daha önce
  /// kutlandı" kaydı. Web `PlayerStats.rank_tier` ile aynı gerekçeyle
  /// modelde duruyor.
  final int? rankTier;

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
    this.bonusPoints,
    this.rankTier,
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
        bonusPoints: _ni(j['bonus_points']),
        rankTier: _ni(j['rank_tier']),
      );
}

/// Web `LeaderboardRow` — `leaderboard` view satırı.
class LeaderboardRow {
  /// k-lig sırası — SUNUCUDA hesaplanır (`k_lig_siralama.sira`): puan desc,
  /// eşitse OHP desc, o da eşitse user_id. Listedeki indeksten (`i + 1`)
  /// TÜRETİLMEZ; `my_leaderboard_rank` de aynı view'dan okuduğundan liste ile
  /// "senin sıran"/Skor Kartı başlığı ancak böyle aynı sayıyı gösterir.
  final int sira;

  final String userId;
  final String? displayName;
  final String? firstName;
  final String? avatarUrl;
  final int totalScore;

  /// OHP — ortalama hamle puanı (hamle başına alınan ortalama puan).
  /// Sunucuda `player_stats_overall.avg_move_score` ile BİREBİR AYNI
  /// ifadeden gelir (ağırlıklı ortalama, 2 basamak): k-lig satırındaki OHP
  /// ile o oyuncunun Skor Kartı'ndaki "Ortalama Hamle Puanı" AYNI sayı
  /// olmak zorunda. Hiç hamle verisi olmayan (eski) kayıtlarda null.
  final double? avgMoveScore;

  const LeaderboardRow({
    required this.sira,
    required this.userId,
    required this.displayName,
    required this.firstName,
    required this.avatarUrl,
    required this.totalScore,
    required this.avgMoveScore,
  });

  /// Herkese açık bir sıralama olduğundan tam ad/soyad DEĞİL, oyun içindeki
  /// kısa kimlik kuralı (web `shortDisplayName`): nickname yoksa yalnız ad.
  String get shortName => (displayName?.isNotEmpty ?? false)
      ? displayName!
      : (firstName?.isNotEmpty ?? false)
          ? firstName!
          : 'Anonim';

  factory LeaderboardRow.fromJson(Map<String, Object?> j) => LeaderboardRow(
        sira: (j['sira'] as num?)?.toInt() ?? 0,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String?,
        firstName: j['first_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        totalScore: (j['total_score'] as num?)?.toInt() ?? 0,
        avgMoveScore: parseNullableDouble(j['avg_move_score']),
      );
}

/// Postgres `numeric` alanları için TOLERANT ayrıştırıcı. `PlayerStats`
/// düz `as num?` kullanıyor ve cihazda çalıştığı doğrulandı (yani PostgREST
/// numeric'i JSON SAYISI olarak döndürüyor); ama bu ortamdan REST ucuna
/// erişilemediğinden (proxy engelliyor) OHP alanları için bu varsayım
/// ÖLÇÜLEMEDİ — bir dize gelirse `as num?` tüm k-lig listesini bir
/// TypeError ile düşürürdü. İki olasılığı da kabul etmek iki satır.
double? parseNullableDouble(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

/// Web `MyLeaderboardRank` — `my_leaderboard_rank` RPC çıktısı.
class MyLeaderboardRank {
  final int rank;
  final int totalScore;

  /// Bkz. [LeaderboardRow.avgMoveScore] — "senin sıran" kısayolu AYNI
  /// tabloda AYNI kolonları çizdiğinden RPC bunu da döndürüyor; yoksa o tek
  /// satırda OHP boş kalır ve tablo hizasız görünürdü.
  final double? avgMoveScore;

  const MyLeaderboardRank({
    required this.rank,
    required this.totalScore,
    required this.avgMoveScore,
  });
}

/// Üç sorgunun soyutlaması — testler bellek içi sahteyle çalışır, gerçek uç
/// (`SupabaseStatsGateway`) cihazda doğrulanır.
abstract class StatsGateway {
  /// [playerCount] null ise `player_stats_overall` ("Genel" sekmesi), aksi
  /// halde `player_stats` (o oyuncu sayısı). Satır yoksa null.
  Future<Map<String, Object?>?> playerStats(String userId, int? playerCount);

  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset);

  Future<Map<String, Object?>?> myLeaderboardRank(String userId);

  /// Verilen kullanıcıların k-lig toplam puanları (`leaderboard` view'ından
  /// `user_id,total_score`) — isimlerin yanındaki rütbe mührü için.
  Future<List<Map<String, Object?>>> rankScores(List<String> userIds);

  /// Skor kartındaki "Y:59/C:E" satırı için BAŞKA bir oyuncunun yaş+cinsiyeti
  /// (`get_profile_age_gender` RPC'si). `profiles`in SELECT RLS'i yalnızca
  /// KENDİ satırını okuttuğundan doğrudan tabloya bakılamıyor; RPC ham
  /// `birth_date`i DEĞİL türetilmiş yaşı döndürür. Satır yoksa null.
  Future<Map<String, Object?>?> profileAgeGender(String userId);

  /// Kafa kafaya: çağıran ile [otherUserId] arasında oynanmış 2 KİŞİLİK
  /// Canlı oyunların sayısı ve kazanma dağılımı (`head_to_head_stats`).
  /// Sonuç ÇAĞIRANIN bakış açısından (`wins` = çağıran kazandı).
  Future<Map<String, Object?>?> headToHead(String otherUserId);
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
    // Kaynak `leaderboard` DEĞİL `k_lig_siralama` (20 Ağustos 2026): sıra
    // sunucuda tek yerde hesaplanıyor ve eşit puanlılar OHP'ye göre ayrışıyor.
    // Öncesinde sıralama yalnızca `total_score`'a göreydi; eşitlikte satır
    // sırası sorgudan sorguya değişebildiğinden `range()` ile sayfalanan bu
    // listede bir satır iki kez görünebilir ya da hiç görünmeyebilirdi.
    final rows = await client
        .from('k_lig_siralama')
        .select()
        .order('sira', ascending: true)
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

  @override
  Future<List<Map<String, Object?>>> rankScores(List<String> userIds) async {
    final rows = await client
        .from('leaderboard')
        .select('user_id,total_score')
        .inFilter('user_id', userIds);
    return [for (final r in rows) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<Map<String, Object?>?> profileAgeGender(String userId) async {
    final data = await client
        .rpc('get_profile_age_gender', params: {'p_user_id': userId});
    final row = data is List && data.isNotEmpty ? data.first : data;
    return row is Map ? row.cast<String, Object?>() : null;
  }

  @override
  Future<Map<String, Object?>?> headToHead(String otherUserId) async {
    // `returns table(...)` → tek satırlık dizi (myLeaderboardRank deseni).
    final data =
        await client.rpc('head_to_head_stats', params: {'p_other': otherUserId});
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

  /// Kafa kafaya istatistik — hata/veri yok durumunda null (UI bloğu hiç
  /// çizmez). Web ikizi `fetchHeadToHead`.
  ///
  /// **Neden RPC, neden istemcide sayılmıyor:** oyun geçmişi sayfalı
  /// (20'şer) ve donmuş `games.players` anlık görüntüsü `user_id`
  /// TAŞIMIYOR — istemcide eşleme ancak isimle olurdu, takma adlar ise
  /// değiştirilebiliyor. Sunucuda `online_games.slots` gerçek `user_id`
  /// taşıyor.
  Future<HeadToHead?> headToHead(String otherUserId) async {
    try {
      final row = await gateway.headToHead(otherUserId);
      return row == null ? null : HeadToHead.fromJson(row);
    } catch (e) {
      debugPrint('[Kelimeki] headToHead hatası: $e');
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

  /// Web `fetchRankScores` portu — isimlerin yanındaki rütbe mührü için
  /// TOPLU puan çekimi (satır başına istek YOK).
  ///
  /// **Yeni bir migration gerekmedi:** `leaderboard` view'ı zaten girişli
  /// herkese açık ve `total_score` ödül puanlarını da içeriyor, yani mühür
  /// Skor Kartı'ndaki k-lig puanıyla AYNI sayıdan türüyor.
  ///
  /// View `games`e INNER JOIN yaptığından hiç oyun bitirmemiş kullanıcı
  /// sonuçta YOKTUR — çağıran eksik id'yi 0 (Çaylak) saymalı. Hata durumunda
  /// `null` döner ("bilinmiyor"): mühür o zaman HİÇ çizilmemeli, aksi halde
  /// liste bir an herkesi Çaylak gösterir.
  Future<Map<String, int>?> rankScores(List<String> userIds) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await gateway.rankScores(ids);
      return {
        for (final r in rows)
          (r['user_id'] as String): ((r['total_score'] as num?) ?? 0).toInt(),
      };
    } catch (e) {
      debugPrint('[Kelimeki] rankScores hatası: $e');
      return null;
    }
  }

  Future<MyLeaderboardRank?> myRank(String userId) async {
    try {
      final row = await gateway.myLeaderboardRank(userId);
      if (row == null) return null;
      return MyLeaderboardRank(
        rank: (row['rank'] as num).toInt(),
        totalScore: (row['total_score'] as num).toInt(),
        avgMoveScore: parseNullableDouble(row['avg_move_score']),
      );
    } catch (e, st) {
      // 26 Ağustos 2026: bu satır YALNIZCA `debugPrint`ti ve k-lig mührü
      // menüde çıkmadığında elde hiçbir kanıt yoktu — aynı gün
      // `OnlineGamesRepo.load()`ta ölçülen sınıfın aynısı. Ağ hatası
      // BİLEREK elenir (`report` varsayılan `manual` türünde o filtreyi
      // kendisi uygulamaz); geriye yalnızca gerçek kusurlar kalır.
      debugPrint('[Kelimeki] myLeaderboardRank hatası: $e');
      if (!isNetworkError(e)) {
        errorReporter.report(e, stack: st, context: 'stats_repo.my_rank');
      }
      return null;
    }
  }

  /// Skor kartındaki "Y:59/C:E" satırı — BAŞKA bir oyuncu için. Hata ya da
  /// veri girilmemişse boş dizge döner, yani satır hiç çizilmez (web'de de
  /// öyle: `formatAgeGender` boş dönünce blok render edilmiyor).
  Future<String> ageGenderLabel(String userId) async {
    try {
      final row = await gateway.profileAgeGender(userId);
      if (row == null) return '';
      return formatAgeGender(
        (row['age'] as num?)?.toInt(),
        row['gender'] as String?,
      );
    } catch (e, st) {
      debugPrint('[Kelimeki] profileAgeGender hatası: $e');
      if (!isNetworkError(e)) {
        errorReporter.report(e,
            stack: st, context: 'stats_repo.age_gender');
      }
      return '';
    }
  }
}
