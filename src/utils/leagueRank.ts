// Kelimeki — k-lig rütbe kademeleri ("Mühür" konsepti, 11 Ağustos 2026,
// kullanıcı onaylı tasarım). Eşikler k-lig PUANINA bağlıdır (oyun sayısına
// değil — o ayrı bir mekanik, bkz. `league_rewards.kind='games_reward'`).
//
// Sunucudaki karşılığı: `_award_league_rewards` (migration
// `league_rewards_rank_system`) aynı eşiklerle `rank_up` satırları açar —
// buradaki liste değişirse ORADAKİ (values ...) listesi de değişmeli, ikisi
// tek kaynak değil (SQL ile TS arasında paylaşım mümkün olmadığından).
//
// Rütbe DÜŞMELİ (12 Ağustos 2026, kullanıcı kararı — ilk sürüm "düşmez"di):
// gösterilen kademe her zaman GÜNCEL k-lig puanından (`total_score`)
// `tierFor` ile türetilir; puan -2 cezalarıyla eşiğin altına inerse damga da
// iner. Sunucudaki `rank_up` satırları / `rank_tier` kolonu artık gösterimi
// SÜRMEZ — yalnızca "bu eşik daha önce kutlandı mı" kaydıdır (her eşik
// hayatta bir kez kutlanır; düşüp tekrar çıkmak banner'ı tekrarlamaz).

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
