// Türkçe harf dağılımı ve puanları — Harfik
// Toplam 186 taş (orijinal 100'ün yaklaşık iki katı).
// '?' jokerdir: 0 puan, oynanırken bir harfe dönüşür.

export interface TileInfo {
  /** Harfin puan değeri. */
  pts: number;
  /** Torbadaki adet. */
  cnt: number;
}

export const TILE_DATA: Readonly<Record<string, TileInfo>> = {
  '?': { pts: 0, cnt: 4 },
  A:  { pts: 1, cnt: 20 },
  B:  { pts: 3, cnt: 4 },
  C:  { pts: 4, cnt: 4 },
  Ç:  { pts: 3, cnt: 4 },
  D:  { pts: 3, cnt: 4 },
  E:  { pts: 1, cnt: 14 },
  F:  { pts: 7, cnt: 2 },
  G:  { pts: 5, cnt: 2 },
  Ğ:  { pts: 8, cnt: 2 },
  H:  { pts: 5, cnt: 2 },
  I:  { pts: 2, cnt: 7 },
  İ:  { pts: 1, cnt: 13 },
  J:  { pts: 10, cnt: 2 },
  K:  { pts: 1, cnt: 13 },
  L:  { pts: 1, cnt: 13 },
  M:  { pts: 2, cnt: 7 },
  N:  { pts: 1, cnt: 9 },
  O:  { pts: 2, cnt: 6 },
  Ö:  { pts: 7, cnt: 2 },
  P:  { pts: 5, cnt: 2 },
  R:  { pts: 1, cnt: 11 },
  S:  { pts: 2, cnt: 6 },
  Ş:  { pts: 4, cnt: 4 },
  T:  { pts: 1, cnt: 9 },
  U:  { pts: 2, cnt: 6 },
  Ü:  { pts: 3, cnt: 4 },
  V:  { pts: 7, cnt: 2 },
  Y:  { pts: 3, cnt: 4 },
  Z:  { pts: 4, cnt: 4 },
};

/** Bir harfin puanını döndürür (joker ya da bilinmeyen harf için 0). */
export function letterPoints(letter: string): number {
  return TILE_DATA[letter]?.pts ?? 0;
}
