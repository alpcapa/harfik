// Harfik — tahta yardımcıları (saf fonksiyonlar)
import { SIZE } from '../game/constants';
import type { CellKey, Tile } from '../game/types';

export type Board = (Tile | null)[][];
export type Placed = Record<CellKey, Tile>;

export function createEmptyBoard(): Board {
  return Array.from({ length: SIZE }, () => Array<Tile | null>(SIZE).fill(null));
}

export function key(r: number, c: number): CellKey {
  return `${r},${c}`;
}

export function inBounds(r: number, c: number): boolean {
  return r >= 0 && r < SIZE && c >= 0 && c < SIZE;
}

/** Tahtada hiç taş yoksa true. */
export function isEmpty(board: Board): boolean {
  return board.every((row) => row.every((cell) => !cell));
}

/** Bir taşın görünen harfini döndürür (joker ise seçilen harf). */
export function tileLetter(tile: Tile): string {
  return tile.wild ? tile.wildLetter ?? '' : tile.letter;
}

/**
 * (r,c) konumundaki etkin harfi döndürür. Önce geçici yerleştirmelere,
 * sonra tahtaya bakar; harf yoksa null.
 */
export function getLetterAt(
  board: Board,
  placed: Placed,
  r: number,
  c: number,
): string | null {
  const p = placed[key(r, c)];
  if (p) return tileLetter(p);
  const b = board[r]?.[c];
  if (b) return tileLetter(b);
  return null;
}

/**
 * (r,c) hücresinden (dr,dc) yönünde uzanan tam kelimeyi döndürür.
 * Önce başa kadar geri gider, sonra sona kadar harfleri toplar.
 */
export function getFullWordAt(
  board: Board,
  placed: Placed,
  r: number,
  c: number,
  dr: number,
  dc: number,
): string {
  let sr = r;
  let sc = c;
  while (
    inBounds(sr - dr, sc - dc) &&
    getLetterAt(board, placed, sr - dr, sc - dc)
  ) {
    sr -= dr;
    sc -= dc;
  }
  let word = '';
  let rr = sr;
  let rc = sc;
  while (inBounds(rr, rc) && getLetterAt(board, placed, rr, rc)) {
    word += getLetterAt(board, placed, rr, rc);
    rr += dr;
    rc += dc;
  }
  return word;
}

export interface FormedWord {
  word: string;
  coords: [number, number][];
}

/** (r,c)'den (dr,dc) yönünde uzanan kelimeyi koordinatlarıyla döndürür. */
function fullWordWithCoords(
  board: Board,
  placed: Placed,
  r: number,
  c: number,
  dr: number,
  dc: number,
): FormedWord {
  let sr = r;
  let sc = c;
  while (
    inBounds(sr - dr, sc - dc) &&
    getLetterAt(board, placed, sr - dr, sc - dc)
  ) {
    sr -= dr;
    sc -= dc;
  }
  let word = '';
  const coords: [number, number][] = [];
  let rr = sr;
  let rc = sc;
  while (inBounds(rr, rc) && getLetterAt(board, placed, rr, rc)) {
    word += getLetterAt(board, placed, rr, rc);
    coords.push([rr, rc]);
    rr += dr;
    rc += dc;
  }
  return { word, coords };
}

/**
 * Bu turdaki yerleştirmelerle oluşan tüm kelimeleri (ana + çapraz)
 * koordinatlarıyla birlikte döndürür. 2 harften kısa kelimeler atlanır.
 */
export function getFormedWords(board: Board, placed: Placed): FormedWord[] {
  const coords = Object.keys(placed).map(
    (k) => k.split(',').map(Number) as [number, number],
  );
  if (coords.length === 0) return [];

  const rows = [...new Set(coords.map((p) => p[0]))];
  const horiz = rows.length === 1;

  const seen = new Set<string>();
  const result: FormedWord[] = [];

  const addWord = (fw: FormedWord) => {
    if (fw.word.length < 2) return;
    const sig = `${fw.coords[0][0]},${fw.coords[0][1]}:${fw.word}`;
    if (seen.has(sig)) return;
    seen.add(sig);
    result.push(fw);
  };

  // Ana kelime (yerleştirme yönünde).
  addWord(
    fullWordWithCoords(
      board,
      placed,
      coords[0][0],
      coords[0][1],
      horiz ? 0 : 1,
      horiz ? 1 : 0,
    ),
  );

  // Her yerleştirme için çapraz kelime.
  for (const [r, c] of coords) {
    const [cdr, cdc] = horiz ? [1, 0] : [0, 1];
    addWord(fullWordWithCoords(board, placed, r, c, cdr, cdc));
  }

  return result;
}
