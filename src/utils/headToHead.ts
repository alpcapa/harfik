// Kafa kafaya oran çubuğunun SAF kuralı — port ikizi
// `mobile/app/lib/src/util/head_to_head.dart`.
//
// Kullanıcı isteği (3 Eylül 2026): *"bir kişi başka kişinin skor kartına
// baktığında alt kısımda aralarında kaç oyun oynandığını ve kazanma
// oranlarını görecek"* — barın SOLUNDA bakılan kişinin avatarı, SAĞINDA
// bakana ait avatar, üstünde oyun sayısı, isim YOK.
//
// Veri `head_to_head_stats` RPC'sinden ve ÇAĞIRANIN bakış açısından geliyor:
// `wins` = çağıran kazandı, `losses` = bakılan kişi kazandı. Bar bu yüzden
// TERS okunuyor — sol uç `losses`, sağ uç `wins`.

export interface HeadToHead {
  games: number;
  wins: number; // çağıran (bakan kişi)
  losses: number; // bakılan kişi
  draws: number;
}

export interface HeadToHeadBar {
  /** Bakılan kişinin payı — barın SOL ucu, yüzde. */
  left: number;
  /** Beraberlikler — ortada nötr bant, yüzde. */
  middle: number;
  /** Bakanın payı — barın SAĞ ucu, yüzde. */
  right: number;
}

/**
 * Üç dilimi yüzdeye çevirir ve **toplamlarının tam 100 olmasını GARANTİ
 * eder** (oyun varsa).
 *
 * ⚠ Yuvarlama üçünü de bağımsız yuvarlamakla yapılmıyor: 1/3-1/3-1/3 gibi
 * bir dağılımda üç ayrı `round` 33+33+33 = 99 verir ve barın ucunda
 * görünür bir boşluk kalır. Bunun yerine soldan kümülatif yuvarlama
 * (largest-remainder'ın basit hâli) kullanılıyor — son dilim artanı alır.
 *
 * `games === 0` → üçü de 0; çağıran bloğu HİÇ çizmemeli (bkz. `hasHeadToHead`).
 */
export function headToHeadBar(h: HeadToHead): HeadToHeadBar {
  if (h.games <= 0) return { left: 0, middle: 0, right: 0 };
  const pay = (n: number) => (n * 100) / h.games;
  const left = Math.round(pay(h.losses));
  const middle = Math.round(pay(h.losses + h.draws)) - left;
  return { left, middle, right: 100 - left - middle };
}

/** Blok çizilsin mi — hiç oynanmamışsa yer kaplamasın. */
export function hasHeadToHead(h: HeadToHead | null): h is HeadToHead {
  return h != null && h.games > 0;
}
