// Kelimeki — tahta boyutu, bölgeler, oyuncu renkleri, bonus yerleşimi
import type { BonusType, CellKey } from './types';

/** Tahta 13x13. */
export const SIZE = 13;

/** Köşe bölgelerinin kenar uzunluğu (4x4). */
export const CORNER = 4;

/** Tüm oyuncular üst üste bu kadar tur pas geçtiğinde oyun biter. */
export const MAX_PASS_ROUNDS = 2;

/** Tüm rafı kullanan hamleye verilen bonus puan. */
export const BINGO_BONUS = 25;

/** Rafta tutulan taş sayısı. */
export const RACK_SIZE = 7;

/**
 * Girişsiz (misafir) oyuncunun `GameState`'e gömülen adı — yerel/YZ
 * oyunlarda 0. koltuk için `accountName` yoksa kullanılır (bkz. `Setup`'un
 * `doStart`'ı). Sabit olarak dışa açılmasının sebebi: bu isim oyun bitince
 * `games.players` anlık görüntüsüne KALICI olarak donuyor (`buildGameRecord`,
 * `r.player.name`) ve okuma tarafı (`RecentGamesSection`) "bu koltuk misafir
 * miydi" sorusunu yalnızca bu string'e bakarak cevaplayabiliyor — snapshot
 * bilerek `user_id` taşımıyor. Yazan ile okuyanın sessizce ayrışmaması için
 * ikisi de bu tek sabiti kullanır.
 */
export const GUEST_PLAYER_NAME = 'Misafir';

/**
 * Oyunu bitiren hamlede (raf + torba tamamen boşalırsa) oynanan taşların
 * TAMAMI jokerse verilen ekstra bonus: 1 joker (tek taş) +25, 2 joker
 * (iki taş) +50. Hamlede joker dışında herhangi bir taş varsa (jokerle
 * birlikte normal harf oynanmışsa) bonus uygulanmaz — bu yüzden çok nadir
 * gerçekleşir.
 */
export function jokerFinishBonus(jokerCount: number): number {
  if (jokerCount >= 2) return 50;
  if (jokerCount === 1) return 25;
  return 0;
}

/** Bonus kare kısa etiketi: X3 = üç kat kelime. */
export const BONUS_LABELS: Record<BonusType, string> = {
  tw: 'X3',
};

// ── Oyuncu renkleri ──────────────────────────────────────────────────────────
// Beyaz zemin üzerinde okunur, birbirinden net ayrılan renkler. Her oyuncu
// kendi köşesini bu renge göre tanır.

export interface PlayerColor {
  /** Ana çizgi/çerçeve rengi. */
  base: string;
  /** Köşe bölgesi ve taş arka planı için açık ton. */
  tint: string;
  /** Bölge vurgusu için daha da soluk ton. */
  zone: string;
  /** Renk üzerinde okunan koyu metin. */
  text: string;
}

export const PLAYER_COLORS: PlayerColor[] = [
  // camgöbeği text'i eskiden #063542'ydi (HSL L=14%) — diğer üç rengin
  // text'i L=%18-33 aralığındayken bu belirgin biçimde daha karanlıktı,
  // bu yüzden (tam da düşük tonlu bir mavi-yeşil hue'da) siyahtan ayırt
  // edilemiyordu; kontrast rengi ("Misafir hâlâ siyah duruyor" olarak
  // bildirildi) DEĞİL, algısal karanlıktı — text-on-tint kontrastı zaten
  // 9.4:1 ile diğerlerinden yüksekti. #0A6076 (L=25%, aynı hue/doygunluk)
  // net biçimde camgöbeği okunuyor, kontrast hâlâ WCAG AA'nın üstünde
  // (tint üzerinde 5.1:1, zone üzerinde 6.4:1).
  { base: '#0891B2', tint: '#A9E4EF', zone: '#E7F6FA', text: '#0A6076' }, // camgöbeği
  { base: '#DC2626', tint: '#FBDADA', zone: '#FDEFEF', text: '#7A1414' }, // kırmızı
  { base: '#16A34A', tint: '#D6F3E1', zone: '#EDFAF1', text: '#0B5128' }, // yeşil
  { base: '#7C3AED', tint: '#DCC8FC', zone: '#F3ECFE', text: '#4A1A90' }, // mor
];

// ── Köşe bölgeleri ───────────────────────────────────────────────────────────
// 0 = sol-üst, 1 = sağ-üst, 2 = sol-alt, 3 = sağ-alt. Her biri CORNER×CORNER.

/** Köşe indeksinin satır/sütun aralığını döndürür. */
export function cornerBounds(corner: number): {
  r0: number;
  r1: number;
  c0: number;
  c1: number;
} {
  const top = corner === 0 || corner === 1;
  const left = corner === 0 || corner === 2;
  return {
    r0: top ? 0 : SIZE - CORNER,
    r1: top ? CORNER - 1 : SIZE - 1,
    c0: left ? 0 : SIZE - CORNER,
    c1: left ? CORNER - 1 : SIZE - 1,
  };
}

/**
 * Bir köşe bölgesinin en uç (tek) hücresi — oyuncunun ilk hamlesinde mutlaka
 * değmesi gereken başlangıç noktası. Görsel olarak burada bir "ev" işareti
 * gösterilir.
 */
export function cornerCell(corner: number): [number, number] {
  const b = cornerBounds(corner);
  const top = corner === 0 || corner === 1;
  const left = corner === 0 || corner === 2;
  return [top ? b.r0 : b.r1, left ? b.c0 : b.c1];
}

/**
 * Oyuncu sayısına göre köşe ataması (her oyuncunun sahip olduğu köşe indeksleri).
 *  - 2 oyuncu: her oyuncu tek bir köşeye sahip olur — 1. oyuncu sol-üst (0),
 *    2. oyuncu sağ-alt (3).
 *  - 4 oyuncu: her oyuncu tek bir köşeye sahip olur.
 */
export function cornersFor(playerCount: number): number[][] {
  return playerCount === 2 ? [[0], [3]] : [[0], [1], [2], [3]];
}

// ── Merkez bonus bölgesi ─────────────────────────────────────────────────────
// Köşeler (CORNER×CORNER) küçülünce ortada kalan CORNER genişliğindeki şerit
// otomatik olarak (SIZE - 2*CORNER) kenar uzunluğunda bir kare olur — 13 ve
// CORNER=4 için 5×5. Bu alandaki bir hücreye bu turda yeni bir taş konursa o
// kelimenin puanı ikiye katlanır — klasik bonus kare gibi, yalnızca hücre ilk
// kullanıldığında; sonraki turlarda o hücredeki (artık eski) taşa bağlanan
// kelimeler x2 almaz. Alanın tam ortası (tek hücre) ayrıca X3 (üç kat kelime)
// olarak işaretlidir.
export const BONUS_ZONE = {
  r0: CORNER,
  r1: SIZE - CORNER - 1,
  c0: CORNER,
  c1: SIZE - CORNER - 1,
};

/** Verilen hücre, merkezdeki x2 bonus bölgesinin içinde mi? */
export function inBonusZone(r: number, c: number): boolean {
  return r >= BONUS_ZONE.r0 && r <= BONUS_ZONE.r1 && c >= BONUS_ZONE.c0 && c <= BONUS_ZONE.c1;
}

/** Tahtanın tam merkezi — bonus bölgesinin tek X3 hücresi. */
export const BOARD_CENTER: [number, number] = [Math.floor(SIZE / 2), Math.floor(SIZE / 2)];

// ── Başlangıç bonus yerleşimi ────────────────────────────────────────────────
// Tüm klasik bonus kareleri kaldırıldı; tek istisna tahtanın tam ortası, o da
// hâlâ X3 (üç kat kelime) olarak işaretli — geri kalan puan katlaması artık
// `inBonusZone` ile ayrıca uygulanan x2 bölge bonusundan gelir (bkz. yukarı).
export function buildInitialBonuses(): Record<CellKey, BonusType> {
  const [r, c] = BOARD_CENTER;
  return { [`${r},${c}`]: 'tw' };
}
