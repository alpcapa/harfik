// Harfik — tahta boyutu, bonus yerleşimi ve etiketler
import type { BonusType, CellKey } from './types';

/** Tahta 13x13. */
export const SIZE = 13;

/** Tahta evriminin tetiklendiği hamle aralığı. */
export const EVOLVE_INTERVAL = 3;

/** Üst üste pas sayısı bu değere ulaşınca oyun biter. */
export const MAX_CONSECUTIVE_PASSES = 4;

/** Tüm rafı kullanan hamleye verilen bonus puan. */
export const BINGO_BONUS = 50;

/** Rafta tutulan taş sayısı. */
export const RACK_SIZE = 7;

/** Bonus kare kısa etiketleri (3K = üç kat kelime vb.). */
export const BONUS_LABELS: Record<BonusType, string> = {
  tw: '3K',
  dw: '2K',
  tl: '3H',
  dl: '2H',
};

// Başlangıç bonus yerleşimi (LexFront prototipinden).
const TW: [number, number][] = [
  [0, 0], [0, 12], [12, 0], [12, 12], [3, 6], [6, 3], [6, 9], [9, 6],
];
const TL: [number, number][] = [
  [0, 3], [0, 9], [3, 0], [9, 0], [3, 12], [9, 12], [12, 3], [12, 9],
  [2, 2], [2, 10], [10, 2], [10, 10],
];
const DL: [number, number][] = [
  [1, 1], [1, 11], [11, 1], [11, 11], [3, 4], [4, 3], [3, 8], [4, 9],
  [8, 3], [9, 4], [8, 9], [9, 8], [6, 6],
];
const DW: [number, number][] = [
  [1, 4], [4, 1], [1, 8], [4, 11], [8, 1], [11, 4], [8, 11], [11, 8],
  [5, 5], [5, 7], [7, 5], [7, 7],
];

export function buildInitialBonuses(): Record<CellKey, BonusType> {
  const b: Record<CellKey, BonusType> = {};
  TW.forEach(([r, c]) => (b[`${r},${c}`] = 'tw'));
  TL.forEach(([r, c]) => (b[`${r},${c}`] = 'tl'));
  DL.forEach(([r, c]) => (b[`${r},${c}`] = 'dl'));
  DW.forEach(([r, c]) => (b[`${r},${c}`] = 'dw'));
  return b;
}

/** Oyuncu bölgesi: sol-alt köşe. İlk hamle buradan başlamalı. */
export function playerZone(r: number, c: number): boolean {
  return r >= 9 && c <= 3;
}

/** YZ bölgesi: sağ-üst köşe. */
export function aiZone(r: number, c: number): boolean {
  return r <= 3 && c >= 9;
}
