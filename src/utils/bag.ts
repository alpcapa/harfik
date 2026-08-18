// Kelimeki — taş torbası
import { TILE_DATA } from '../data/tiles';
import type { Tile } from '../game/types';
import { shuffle } from './random';

/** Karıştırılmış taş torbası oluşturur. */
export function buildBag(): Tile[] {
  const b: Tile[] = [];
  for (const [letter, { pts, cnt }] of Object.entries(TILE_DATA)) {
    for (let i = 0; i < cnt; i++) b.push({ letter, pts });
  }
  return shuffle(b);
}

/**
 * Torbadan en fazla `n` taş çeker. Torbayı yerinde değiştirir
 * ve çekilen taşları döndürür.
 */
export function drawTiles(bag: Tile[], n: number): Tile[] {
  const d: Tile[] = [];
  for (let i = 0; i < n && bag.length > 0; i++) {
    d.push(bag.pop()!);
  }
  return d;
}

/** Bir harfin kalan taş dökümündeki satırı. */
export interface RemainingLetter {
  /** Ham harf ('?' joker). */
  letter: string;
  pts: number;
  /** Kalan adet. */
  count: number;
}

/** Bir taşın dağılımdaki anahtarı (joker her zaman '?'). */
function tileKey(t: Tile): string {
  return t.wild || t.letter === '?' ? '?' : t.letter;
}

/**
 * "Dışarıda" kalan taşları döndürür: tüm dağılımdan tahtadaki taşlar,
 * verilen raftaki (bakan oyuncunun) taşlar ve bu turda tahtaya konmuş ama
 * henüz onaylanmamış taşlar çıkarılır. Sonuçta torbadaki ve diğer
 * oyuncuların elindeki (görünmeyen) taşlar kalır.
 *
 * `placedTiles` ATLANMAMALI: bekleyen taşlar `PLACE_TILE` ile raftan ÇIKAR
 * ama `board`a ancak `PLAY` onayıyla yazılır (`state.placed`da beklerler) —
 * sayılmazlarsa iki kova arasındaki bu boşlukta "dışarıda" görünür ve
 * rakibin elinde sanılırlar (18 Ağustos 2026'da bildirilen hata).
 */
export function remainingTiles(
  board: (Tile | null)[][],
  myRack: Tile[],
  placedTiles: Tile[] = [],
): RemainingLetter[] {
  const counts: Record<string, number> = {};
  for (const [letter, { cnt }] of Object.entries(TILE_DATA)) counts[letter] = cnt;

  const dec = (t: Tile) => {
    const k = tileKey(t);
    if (counts[k] != null) counts[k] -= 1;
  };
  for (const row of board) for (const cell of row) if (cell) dec(cell);
  for (const t of myRack) dec(t);
  for (const t of placedTiles) dec(t);

  return Object.entries(TILE_DATA).map(([letter, { pts }]) => ({
    letter,
    pts,
    count: Math.max(0, counts[letter]),
  }));
}
