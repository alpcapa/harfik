// k-lig rütbe kademeleri ("Mühür" konsepti) — web `src/utils/leagueRank.ts`
// portu (12 Ağustos 2026, Parça 61).
//
// Eşikler k-lig PUANINA bağlıdır. Sunucudaki karşılığı
// `_award_league_rewards` (migration `league_rewards_rank_system` +
// `points_threshold_rewards` + `rank_tier_merakli_50`) AYNI eşiklerle
// `rank_up`/`points_reward` satırları açar.
//
// ⚠ ÜÇ KOPYA ELLE SENKRON: buradaki liste, web'in `leagueRank.ts`'i ve
// SQL'deki `(values ...)` listeleri tek kaynak DEĞİL (SQL ↔ TS ↔ Dart
// arasında paylaşım mümkün olmadığından). Biri değişirse üçü birden
// değişmeli — hiçbir derleyici/test bunu yakalamaz.
//
// Rütbe DÜŞMELİ (12 Ağustos 2026, kullanıcı kararı): gösterilen kademe her
// zaman GÜNCEL toplam puandan (`tierFor`) türetilir; puan -2 cezalarıyla
// eşiğin altına inerse damga da iner. Sunucudaki `rank_up` satırları /
// `rank_tier` kolonu gösterimi SÜRMEZ — yalnızca "bu eşik daha önce
// kutlandı mı" kaydıdır (her eşik hayatta bir kez kutlanır; düşüp tekrar
// çıkmak banner'ı tekrarlamaz).
library;

import 'dart:ui' show Color;

import '../tokens.dart';

class RankTier {
  /// Kullanıcıya görünen ad.
  final String name;

  /// Mühür damgasının ortasındaki harf.
  final String letter;

  /// Damga rengi — tailwind paletinden (web'de sabit yazılmış olan değerler
  /// burada token'a bağlandı; değerler birebir aynı, bkz. `tokens.dart`).
  final Color color;

  /// Bu kademeye ulaşmak için gereken k-lig puanı.
  final int threshold;

  /// Bu puan eşiğine İLK ulaşmada verilen tek seferlik ödül puanı. Çaylak'ta
  /// 0. Verilmiş ödül, puan sonradan eşiğin altına inse de GERİ ALINMAZ.
  final int reward;

  const RankTier({
    required this.name,
    required this.letter,
    required this.color,
    required this.threshold,
    required this.reward,
  });
}

const kRankTiers = <RankTier>[
  // Çaylak'ın rengi web'de `#8A93A2` = tailwind `tile-pts` (bkz. kTilePts).
  RankTier(
      name: 'Çaylak', letter: 'Ç', color: kTilePts, threshold: 0, reward: 0),
  RankTier(
      name: 'Meraklı', letter: 'M', color: kAccent, threshold: 50, reward: 5),
  RankTier(
      name: 'Oyuncu', letter: 'O', color: kGreen, threshold: 100, reward: 10),
  RankTier(name: 'Usta', letter: 'U', color: kGold, threshold: 200, reward: 25),
  RankTier(
      name: 'Şampiyon',
      letter: 'Ş',
      color: kOrange,
      threshold: 500,
      reward: 50),
  RankTier(
      name: 'Destan', letter: 'D', color: kRed, threshold: 1000, reward: 100),
];

/// Bir puan/eşik değerine karşılık gelen kademe — "threshold'u geçmeyen en
/// yüksek kademe". Hem güncel toplamdan (damga) hem bir eşik değerinden
/// (banner'daki kilometre taşı rengi) çağrılabilir. Negatif puan (yalnızca
/// -2 cezalarıyla mümkün) Çaylak'a düşer.
RankTier tierFor(int? value) {
  final v = value ?? 0;
  var tier = kRankTiers.first;
  for (final t in kRankTiers) {
    if (t.threshold <= v) tier = t;
  }
  return tier;
}

/// Bir sonraki kademe — en üstteyse null.
RankTier? nextTierAfter(RankTier tier) {
  for (final t in kRankTiers) {
    if (t.threshold > tier.threshold) return t;
  }
  return null;
}

/// Bu eşiğin tek seferlik ödülü daha önce alınmış mı — toplam ödül puanından
/// (`player_stats_overall.bonus_points`) TÜRETİLİR, ekstra sorgu gerekmez:
/// `_award_league_rewards` eşikleri her zaman soldan sağa, atlamasız (prefix)
/// verdiğinden ve verilmiş ödül asla geri alınmadığından toplam, hangi
/// eşiklerin ödendiğini tekil olarak belirler (5→{50}, 15→{50,100}, 40→
/// {50,100,200}…).
bool rewardAlreadyClaimed(RankTier tier, int bonusPoints) {
  var cum = 0;
  for (final t in kRankTiers) {
    cum += t.reward;
    if (t.threshold == tier.threshold) return bonusPoints >= cum && cum > 0;
  }
  return false;
}
