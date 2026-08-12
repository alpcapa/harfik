// k-lig ödül/rütbe kayıtları (`league_rewards` tablosu) — web
// `fetchUnseenLeagueRewards`/`markLeagueRewardsSeen` (src/lib/api.ts) portu.
//
// **Neden `stats_api.dart`'a eklenmedi (Parça 61 kararı):** stats_api üç
// SALT OKUNUR view/RPC taşıyor ve bilinçli olarak dayanıklılık katmanı
// içermiyor; burada bir YAZMA yolu var (`mark_league_rewards_seen`) ve kendi
// modeli/kind enum'ı var. Projedeki desen zaten alan başına bir dosya
// (chat_api, friends_api, feedback_api…) — aynı çizgide ayrı tutuldu.
//
// Yazma kuyruğuna (`TableWriteQueue`) GİRMİYOR: `mark_league_rewards_seen`
// bir RPC (satır sahibi tabloya doğrudan DELETE/UPDATE değil) ve okuma yolu
// onu takip etmiyor — banner kapandıktan sonra listeyi yeniden çekmiyoruz,
// yani `local_game_saves`teki DELETE→SELECT yarışı burada kurulamıyor.
// (Aynı gerekçeyle `feedback` da o kuyruğa girmiyor.)
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `league_rewards.kind` — dört tür. Bilinmeyen bir değer (sunucu ileride
/// beşincisini eklerse) [unknown]'a düşer ve özet üretiminde YOK SAYILIR;
/// eski bir istemci yeni bir türü uydurma bir banner'a çevirmemeli.
enum LeagueRewardKind {
  /// Puan eşiği ödülü — rütbe eşikleriyle AYNI liste (50→+5 … 1000→+100).
  /// 12 Ağustos 2026'ya kadar oyun sayısına bağlı `games_reward`dı.
  pointsReward,

  /// Her 100 puan kutlaması (points=0).
  pointsMilestone,

  /// Rütbe eşiği aşımı (points=0).
  rankUp,

  /// Rütbe düşüş bildirimi (points=0) — diğerlerinin aksine TEKRARLANABİLİR:
  /// aynı eşikten yeniden düşülürse sunucu `seen_at`'i sıfırlar.
  rankDown,

  unknown;

  static LeagueRewardKind parse(Object? raw) => switch (raw) {
        'points_reward' => LeagueRewardKind.pointsReward,
        'points_milestone' => LeagueRewardKind.pointsMilestone,
        'rank_up' => LeagueRewardKind.rankUp,
        'rank_down' => LeagueRewardKind.rankDown,
        _ => LeagueRewardKind.unknown,
      };
}

/// Web `LeagueReward` — `league_rewards` satırı.
class LeagueReward {
  final String id;
  final LeagueRewardKind kind;
  final int threshold;
  final int points;
  final DateTime? seenAt;

  const LeagueReward({
    required this.id,
    required this.kind,
    required this.threshold,
    required this.points,
    this.seenAt,
  });

  factory LeagueReward.fromJson(Map<String, Object?> j) => LeagueReward(
        id: j['id'] as String? ?? '',
        kind: LeagueRewardKind.parse(j['kind']),
        threshold: (j['threshold'] as num?)?.toInt() ?? 0,
        points: (j['points'] as num?)?.toInt() ?? 0,
        seenAt: switch (j['seen_at']) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
      );
}

/// Testler bellek içi sahteyle çalışır; gerçek uç
/// ([SupabaseLeagueRewardsGateway]) cihazda doğrulanır.
abstract class LeagueRewardsGateway {
  /// Çağıranın görülmemiş (`seen_at is null`) satırları, en eski önce.
  Future<List<Map<String, Object?>>> unseen(String userId);

  /// `mark_league_rewards_seen` — çağıranın TÜM görülmemiş satırlarını
  /// işaretler (parametresiz; sunucu `auth.uid()` kullanır).
  Future<void> markSeen();
}

class SupabaseLeagueRewardsGateway implements LeagueRewardsGateway {
  final SupabaseClient client;
  SupabaseLeagueRewardsGateway(this.client);

  @override
  Future<List<Map<String, Object?>>> unseen(String userId) async {
    // RLS SELECT'i tüm girişli kullanıcılara açık (rütbe, herkese görünür
    // lig verisinin parçası) — daraltma web'deki gibi client'ta.
    final rows = await client
        .from('league_rewards')
        .select()
        .eq('user_id', userId)
        .isFilter('seen_at', null)
        .order('created_at', ascending: true);
    return [for (final r in rows) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<void> markSeen() => client.rpc('mark_league_rewards_seen');
}

class LeagueRewardsRepo {
  final LeagueRewardsGateway gateway;
  LeagueRewardsRepo(this.gateway);

  /// Ağ hatasında boş liste — "ödül yok" ile "bakılamadı" UI'da aynı sonuca
  /// düşer (banner çıkmaz), bir sonraki kontrol yeniden dener (web davranışı).
  Future<List<LeagueReward>> unseen(String userId) async {
    try {
      final rows = await gateway.unseen(userId);
      return [for (final r in rows) LeagueReward.fromJson(r)];
    } catch (e) {
      debugPrint('[Kelimeki] league_rewards okunamadı: $e');
      return const [];
    }
  }

  /// Banner'ın "Devam"ı. Başarısız olursa satırlar görülmemiş kalır ve
  /// kutlama bir sonraki girişte tekrar gösterilir — bilinçli (yutulan bir
  /// kutlamadansa tekrarlanan bir kutlama).
  Future<void> markSeen() async {
    try {
      await gateway.markSeen();
    } catch (e) {
      debugPrint('[Kelimeki] mark_league_rewards_seen hatası: $e');
    }
  }
}
