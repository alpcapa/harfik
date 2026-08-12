// Kelimeki — k-lig rütbe kademeleri ("Mühür" konsepti, 11 Ağustos 2026,
// kullanıcı onaylı tasarım). Eşikler k-lig PUANINA bağlıdır, oyun sayısına
// değil. (Bir dönem burada "oyun sayısı AYRI bir mekanik, bkz.
// `kind='games_reward'`" yazıyordu; o mekanik 12 Ağustos 2026'da
// `points_threshold_rewards` ile TAMAMEN KALDIRILDI — mevcut satırlar
// `points_reward`a çevrildi ve `league_rewards_kind_check` artık yalnızca
// points_reward / points_milestone / rank_up / rank_down'a izin veriyor.
// Yani "ayrı bir mekanik" cümlesi o günden beri bayattı.)
//
// ⚠ ÜÇ KOPYA ELLE SENKRON: buradaki liste, Flutter portunun
// `mobile/app/lib/src/ui/rank/league_rank.dart`'ı ve SQL'deki
// `_award_league_rewards` (values ...) listeleri tek kaynak DEĞİL (SQL ↔ TS ↔
// Dart arasında paylaşım mümkün olmadığından). Biri değişirse ÜÇÜ birden
// değişmeli — hiçbir derleyici/test bunu yakalamaz. Son senkron: 12 Ağustos
// 2026 (`rank_tiers_efsane_uzayli_tanri` migration'ı).
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
  /**
   * Bu puan eşiğine İLK ulaşmada verilen tek seferlik ödül puanı (12 Ağustos
   * 2026'dan beri ödüller oyun sayısına değil puan eşiğine bağlı —
   * `points_threshold_rewards` migration'ı). Çaylak'ta 0. Verilmiş ödül,
   * puan sonradan eşiğin altına inse de geri alınmaz.
   */
  reward: number;
}

/**
 * Kademeler. **Ödül = eşik/10**, istisnasız (12 Ağustos 2026 — Usta 200'den
 * 250'ye çekilince bu kural tabloya tam oturdu; öncesinde tek kırık o değerdi).
 * Yeni bir kademe eklerken aynı orandan devam et.
 *
 * Kümülatif ödüller (0/5/15/40/90/190/440/940/1940) BİRBİRİNDEN FARKLI olmak
 * ZORUNDA — `rewardAlreadyClaimed` hangi eşiklerin ödendiğini yalnızca toplam
 * ödül puanından türetiyor (aşağı bkz.); iki farklı prefix aynı toplamı
 * verirse o çıkarım bozulur.
 */
export const RANK_TIERS: RankTier[] = [
  { name: 'Çaylak', letter: 'Ç', color: '#8A93A2', threshold: 0, reward: 0 },
  { name: 'Meraklı', letter: 'M', color: '#2563EB', threshold: 50, reward: 5 },
  { name: 'Oyuncu', letter: 'O', color: '#16A34A', threshold: 100, reward: 10 },
  { name: 'Usta', letter: 'U', color: '#B7791F', threshold: 250, reward: 25 },
  { name: 'Şampiyon', letter: 'Ş', color: '#F2650F', threshold: 500, reward: 50 },
  { name: 'Destan', letter: 'D', color: '#DC2626', threshold: 1000, reward: 100 },
  { name: 'Efsane', letter: 'E', color: '#4F46E5', threshold: 2500, reward: 250 },
  // Uzaylı'nın harfi Z — "U" Usta'da kullanılıyor ve mühür tek glyph
  // gösterdiğinden iki kademe yalnızca renkleriyle ayrışırdı (12 Ağustos
  // 2026, kullanıcı kararı).
  { name: 'Uzaylı', letter: 'Z', color: '#06B6D4', threshold: 5000, reward: 500 },
  // Tanrı EN ÜST kademe — üstüne kademe eklenmez, oraya varan orada kalır.
  // Ödülü (1000) `league_rewards_points_check`'in tavanına (points <= 1000)
  // TAM oturuyor: bir üst kademe eklenecekse o kısıt da büyütülmeli.
  { name: 'Tanrı', letter: 'T', color: '#EAB308', threshold: 10000, reward: 1000 },
];

/**
 * Bir puan/eşik değerine karşılık gelen kademe — hem `rank_tier` kolonundan
 * (ulaşılan en yüksek eşik: 0/50/100/250/500/1000/2500/5000/10000) hem ham bir puandan
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

/**
 * Bu eşiğin tek seferlik ödülü daha önce alınmış mı — toplam ödül puanından
 * (`player_stats_overall.bonus_points`) türetilir, ekstra sorgu gerekmez:
 * `_award_league_rewards` eşikleri her zaman soldan sağa, atlamasız (prefix)
 * verdiğinden ve verilmiş ödül asla geri alınmadığından, toplam hangi
 * eşiklerin ödendiğini tekil olarak belirler (5→{50}, 15→{50,100}, 40→
 * {50,100,250}…). Puan eşiğin altına düşüp yeniden yaklaşan biri için
 * ilerleme çubuğu hedef etiketi bununla "(+10)" yerine "(0)" gösterir —
 * kişi tekrar ödül alacağını sanmasın (12 Ağustos 2026, kullanıcı isteği).
 */
export function rewardAlreadyClaimed(tier: RankTier, bonusPoints: number): boolean {
  let cum = 0;
  for (const t of RANK_TIERS) {
    cum += t.reward;
    if (t.threshold === tier.threshold) return bonusPoints >= cum && cum > 0;
  }
  return false;
}
