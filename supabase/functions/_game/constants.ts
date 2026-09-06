// Kelimeki — tahta boyutu, bölgeler, bonus yerleşimi
//
// src/game/constants.ts'in KOPYASI (yalnızca play-ai-turn'ün ihtiyaç
// duyduğu saf hesap fonksiyonları/sabitleri) — bkz. types.ts'teki not.
import type { AiLevel, BonusType, CellKey } from './types.ts';

/** Tahta 13x13. */
export const SIZE = 13;

/** Köşe bölgelerinin kenar uzunluğu (4x4). */
export const CORNER = 4;

/** Tüm rafı kullanan hamleye verilen bonus puan. */
export const BINGO_BONUS = 25;

/** Rafta tutulan taş sayısı. */
export const RACK_SIZE = 7;

/**
 * YZ seviyesi → "en iyi N'den rastgele" kadranı — src/game/constants.ts'teki
 * AI_LEVEL_TOP_N'in kopyası (`verify-edge-engine-parity` eşitliği kilitler).
 */
export const AI_LEVEL_TOP_N: Record<AiLevel, number> = { kolay: 4, normal: 1, zor: 1 };

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

/** Bir köşe bölgesinin en uç (tek) hücresi — ilk hamlede mutlaka değmesi gereken nokta. */
export function cornerCell(corner: number): [number, number] {
  const b = cornerBounds(corner);
  const top = corner === 0 || corner === 1;
  const left = corner === 0 || corner === 2;
  return [top ? b.r0 : b.r1, left ? b.c0 : b.c1];
}

/** Oyuncu sayısına göre köşe ataması. */
export function cornersFor(playerCount: number): number[][] {
  return playerCount === 2 ? [[0], [3]] : [[0], [1], [2], [3]];
}

/** Merkez bonus bölgesi (5×5, X2). */
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

export function buildInitialBonuses(): Record<CellKey, BonusType> {
  const [r, c] = BOARD_CENTER;
  return { [`${r},${c}`]: 'tw' };
}
