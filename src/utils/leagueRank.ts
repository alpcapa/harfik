// Kelimeki — k-lig rütbe kademeleri ("Mühür" konsepti, 11 Ağustos 2026,
// kullanıcı onaylı tasarım). Eşikler k-lig PUANINA bağlıdır (oyun sayısına
// değil — o ayrı bir mekanik, bkz. `league_rewards.kind='games_reward'`).
//
// Sunucudaki karşılığı: `_award_league_rewards` (migration
// `league_rewards_rank_system`) aynı eşiklerle `rank_up` satırları açar —
// buradaki liste değişirse ORADAKİ (values ...) listesi de değişmeli, ikisi
// tek kaynak değil (SQL ile TS arasında paylaşım mümkün olmadığından).
//
// Rütbe DÜŞMEZ: gösterilen kademe her zaman sunucuda kaydedilmiş en yüksek
// `rank_up.threshold`tur (`rank_tier` kolonu, leaderboard/player_stats_overall
// view'ları) — puan -2 cezalarıyla eşiğin altına inse bile damga kalır.

export interface RankTier {
  /** Kullanıcıya görünen ad. */
  name: string;
  /** Mühür damgasının ortasındaki harf. */
  letter: string;
  /** Damga rengi (tailwind paletinden birebir değerler). */
  color: string;
  /** Bu kademeye ulaşmak için gereken k-lig puanı. */
  threshold: number;
}

export const RANK_TIERS: RankTier[] = [
  { name: 'Çaylak', letter: 'Ç', color: '#8A93A2', threshold: 0 },
  { name: 'Meraklı', letter: 'M', color: '#2563EB', threshold: 25 },
  { name: 'Oyuncu', letter: 'O', color: '#16A34A', threshold: 100 },
  { name: 'Usta', letter: 'U', color: '#B7791F', threshold: 200 },
  { name: 'Şampiyon', letter: 'Ş', color: '#F2650F', threshold: 500 },
  { name: 'Destan', letter: 'D', color: '#DC2626', threshold: 1000 },
];

/**
 * Bir puan/eşik değerine karşılık gelen kademe — hem `rank_tier` kolonundan
 * (ulaşılan en yüksek eşik: 0/25/100/200/500/1000) hem ham bir puandan
 * (banner'daki kilometre taşı rengi için) çağrılabilir; ikisi de "threshold'u
 * geçmeyen en yüksek kademe" kuralıyla çözülür.
 */
export function tierFor(value: number | null | undefined): RankTier {
  const v = value ?? 0;
  let tier = RANK_TIERS[0];
  for (const t of RANK_TIERS) {
    if (t.threshold <= v) tier = t;
  }
  return tier;
}
