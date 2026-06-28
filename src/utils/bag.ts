// Harfik — taş torbası
import { TILE_DATA } from '../data/tiles';
import type { Tile } from '../game/types';
import { shuffle } from './random';

/** TILE_DATA dağılımına göre karıştırılmış torba oluşturur. */
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
