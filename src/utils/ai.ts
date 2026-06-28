// Harfik — YZ rakip mantığı
//
// YZ, rafından heceleyebildiği kelimeler arasından tahtaya en yüksek puanlı
// (ve sözlükçe geçerli) hamleyi arar. İlk hamlede kendi bölgesine (sağ-üst)
// yatay oynar; sonra mevcut taşları çapa alarak yeni kelimeler kurar.
import { SIZE, aiZone } from '../game/constants';
import type { AIMove, BonusType, Placement, Tile } from '../game/types';
import { WORD_SET } from '../data/words';
import { letterPoints } from '../data/tiles';
import { canSpell, calcScore } from './validator';
import {
  getFormedWords,
  isEmpty,
  key,
  tileLetter,
  type Board,
} from './board';

/**
 * Verilen pozisyon/harf listesi için rafı tüketerek taşları üretir.
 * Tam harf yoksa joker ('?') kullanılır ve taş wild olarak işaretlenir.
 * Raf yetmezse null döner.
 */
function consumeRack(
  letters: string[],
  rackLetters: string[],
): Tile[] | null {
  const avail = [...rackLetters];
  const tiles: Tile[] = [];
  for (const L of letters) {
    const i = avail.indexOf(L);
    if (i >= 0) {
      avail.splice(i, 1);
      tiles.push({ letter: L, pts: letterPoints(L), owner: 'ai' });
    } else {
      const wi = avail.indexOf('?');
      if (wi < 0) return null;
      avail.splice(wi, 1);
      tiles.push({ letter: '?', pts: 0, wild: true, wildLetter: L, owner: 'ai' });
    }
  }
  return tiles;
}

export function findAIMove(
  board: Board,
  aiRack: Tile[],
  cellState: Record<string, string>,
  bonuses: Record<string, BonusType>,
): AIMove | null {
  const rackLetters = aiRack.map((t) => t.letter);
  const candidates = [...WORD_SET]
    .filter((w) => w.length >= 2 && w.length <= 7)
    .map((w) => w.toUpperCase())
    .filter((w) => canSpell(w, rackLetters));

  let best: AIMove | null = null;

  const consider = (placements: Placement[], word: string) => {
    const placed: Record<string, Tile> = {};
    for (const p of placements) placed[key(p.r, p.c)] = p.tile;
    // Oluşan tüm kelimeler (çapraz dahil) sözlükte olmalı.
    for (const fw of getFormedWords(board, placed)) {
      if (!WORD_SET.has(fw.word.toLowerCase())) return;
    }
    const score = calcScore(board, placed, bonuses);
    if (!best || score > best.score) best = { word, score, placements };
  };

  // İlk hamle: YZ bölgesinde yatay yerleştir.
  if (isEmpty(board)) {
    const r = 1;
    const startC = 9;
    for (const W of candidates) {
      if (startC + W.length > SIZE) continue;
      if (!aiZone(r, startC)) continue;
      const letters: string[] = [];
      const positions: [number, number][] = [];
      let ok = true;
      for (let i = 0; i < W.length; i++) {
        const c = startC + i;
        const st = cellState[key(r, c)];
        if (board[r][c] || st === 'void' || st === 'crack') {
          ok = false;
          break;
        }
        letters.push(W[i]);
        positions.push([r, c]);
      }
      if (!ok) continue;
      const tiles = consumeRack(letters, rackLetters);
      if (!tiles) continue;
      const placements = positions.map(([pr, pc], i) => ({
        r: pr,
        c: pc,
        tile: tiles[i],
      }));
      consider(placements, W);
    }
    return best;
  }

  // Çapalı hamleler: tahtadaki her taşı eksen alarak dene.
  const tryPlace = (W: string, r: number, c: number, idx: number, horiz: boolean) => {
    const sr = horiz ? r : r - idx;
    const sc = horiz ? c - idx : c;
    if (horiz) {
      if (sc < 0 || sc + W.length > SIZE) return;
      // Kelimenin uçları bitişik bir taşa değmemeli.
      if (!((sc === 0 || !board[r][sc - 1]) && (sc + W.length === SIZE || !board[r][sc + W.length]))) return;
    } else {
      if (sr < 0 || sr + W.length > SIZE) return;
      if (!((sr === 0 || !board[sr - 1]?.[c]) && (sr + W.length === SIZE || !board[sr + W.length]?.[c]))) return;
    }

    const newLetters: string[] = [];
    const newPositions: [number, number][] = [];
    for (let i = 0; i < W.length; i++) {
      const rr = horiz ? r : sr + i;
      const cc = horiz ? sc + i : c;
      const st = cellState[key(rr, cc)];
      if (st === 'void' || st === 'crack') return;
      const existing = board[rr][cc];
      if (existing) {
        if (tileLetter(existing) !== W[i]) return; // mevcut taşla uyuşmuyor
      } else {
        newLetters.push(W[i]);
        newPositions.push([rr, cc]);
      }
    }
    if (newLetters.length === 0) return; // en az bir yeni taş konmalı
    if (newLetters.length > rackLetters.length) return;
    const tiles = consumeRack(newLetters, rackLetters);
    if (!tiles) return;
    const placements = newPositions.map(([pr, pc], i) => ({
      r: pr,
      c: pc,
      tile: tiles[i],
    }));
    consider(placements, W);
  };

  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const anchorTile = board[r][c];
      if (!anchorTile) continue;
      const anchor = tileLetter(anchorTile);
      for (const W of candidates) {
        let idx = W.indexOf(anchor);
        while (idx >= 0) {
          tryPlace(W, r, c, idx, true);
          tryPlace(W, r, c, idx, false);
          idx = W.indexOf(anchor, idx + 1);
        }
      }
    }
  }

  return best;
}
