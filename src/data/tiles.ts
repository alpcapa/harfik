// Türkçe harf dağılımı ve puanları — Harfik
// LexFront HTML prototipindeki TILE_DATA dağılımından çıkarılmıştır.
// '?' jokerdir: 0 puan, oynanırken bir harfe dönüşür.

export interface TileInfo {
  /** Harfin puan değeri. */
  pts: number;
  /** Torbadaki adet. */
  cnt: number;
}

export const TILE_DATA: Readonly<Record<string, TileInfo>> = {
  '?': { pts: 0, cnt: 2 },
  A: { pts: 1, cnt: 12 },
  B: { pts: 3, cnt: 2 },
  C: { pts: 4, cnt: 2 },
  Ç: { pts: 3, cnt: 2 },
  D: { pts: 3, cnt: 2 },
  E: { pts: 1, cnt: 8 },
  F: { pts: 7, cnt: 1 },
  G: { pts: 5, cnt: 1 },
  Ğ: { pts: 8, cnt: 1 },
  H: { pts: 5, cnt: 1 },
  I: { pts: 2, cnt: 4 },
  İ: { pts: 1, cnt: 7 },
  J: { pts: 10, cnt: 1 },
  K: { pts: 1, cnt: 7 },
  L: { pts: 1, cnt: 7 },
  M: { pts: 2, cnt: 4 },
  N: { pts: 1, cnt: 5 },
  O: { pts: 2, cnt: 3 },
  Ö: { pts: 7, cnt: 1 },
  P: { pts: 5, cnt: 1 },
  R: { pts: 1, cnt: 6 },
  S: { pts: 2, cnt: 3 },
  Ş: { pts: 4, cnt: 2 },
  T: { pts: 1, cnt: 5 },
  U: { pts: 2, cnt: 3 },
  Ü: { pts: 3, cnt: 2 },
  V: { pts: 7, cnt: 1 },
  Y: { pts: 3, cnt: 2 },
  Z: { pts: 4, cnt: 2 },
};

/** Bir harfin puanını döndürür (joker ya da bilinmeyen harf için 0). */
export function letterPoints(letter: string): number {
  return TILE_DATA[letter]?.pts ?? 0;
}
