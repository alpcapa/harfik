// Harfik — YZ rakip mantığı (çok oyunculu, köşe temelli)
//
// YZ, rafından heceleyebildiği kelimeler arasından, bölge kurallarına uyan
// ve sözlükçe geçerli en yüksek puanlı hamleyi arar. İlk hamlesini kendi
// köşesinden başlatır; sonra mevcut taşları çapa alarak yeni kelimeler kurar.
import { SIZE, cornerBounds, inCorner } from '../game/constants';
import type { AIMove, BonusType, Placement, Tile } from '../game/types';
import { WORD_SET } from '../data/words';
import { letterPoints } from '../data/tiles';
import { canSpell, calcScore, cellAllowed } from './validator';
import { trLower, trUpper } from './turkish';
import { getFormedWords, key, tileLetter, type Board } from './board';

/**
 * Verilen pozisyon/harf listesi için rafı tüketerek taşları üretir. Tam harf
 * yoksa joker ('?') kullanılır ve taş wild olarak işaretlenir. Raf yetmezse null.
 */
function consumeRack(
  letters: string[],
  rackLetters: string[],
  owner: number,
): Tile[] | null {
  const avail = [...rackLetters];
  const tiles: Tile[] = [];
  for (const L of letters) {
    const i = avail.indexOf(L);
    if (i >= 0) {
      avail.splice(i, 1);
      tiles.push({ letter: L, pts: letterPoints(L), owner });
    } else {
      const wi = avail.indexOf('?');
      if (wi < 0) return null;
      avail.splice(wi, 1);
      tiles.push({ letter: '?', pts: 0, wild: true, wildLetter: L, owner });
    }
  }
  return tiles;
}

/**
 * Sırası gelen YZ oyuncusu için en iyi hamleyi döndürür (yoksa null → pas).
 * `corner` YZ'nin köşesi, `openCorners` açık köşeler, `isFirstMove` bu
 * oyuncunun ilk hamlesi mi.
 */
export function findAIMove(
  board: Board,
  rack: Tile[],
  bonuses: Record<string, BonusType>,
  owner: number,
  corner: number,
  openCorners: boolean[],
  isFirstMove: boolean,
): AIMove | null {
  const rackLetters = rack.map((t) => t.letter);
  const candidates = [...WORD_SET]
    .filter((w) => w.length >= 2 && w.length <= 7)
    .map((w) => trUpper(w))
    .filter((w) => canSpell(w, rackLetters));

  let best: AIMove | null = null;

  const consider = (placements: Placement[], word: string) => {
    const placed: Record<string, Tile> = {};
    for (const p of placements) placed[key(p.r, p.c)] = p.tile;
    // Oluşan tüm kelimeler (çapraz dahil) sözlükte olmalı.
    for (const fw of getFormedWords(board, placed)) {
      if (!WORD_SET.has(trLower(fw.word))) return;
    }
    const score = calcScore(board, placed, bonuses);
    if (!best || score > best.score) best = { word, score, placements };
  };

  // Yeni konacak tüm hücreler bölge kurallarına uymalı.
  const allowed = (r: number, c: number) =>
    cellAllowed(corner, openCorners, r, c);

  // ── İlk hamle: kendi köşesinden başla ───────────────────────────────────────
  if (isFirstMove) {
    const b = cornerBounds(corner);
    for (let sr = b.r0; sr <= b.r1; sr++) {
      for (let sc = b.c0; sc <= b.c1; sc++) {
        for (const W of candidates) {
          for (const horiz of [true, false]) {
            const er = horiz ? sr : sr + W.length - 1;
            const ec = horiz ? sc + W.length - 1 : sc;
            if (er >= SIZE || ec >= SIZE) continue;
            let ok = true;
            let touchesCorner = false;
            const positions: [number, number][] = [];
            for (let i = 0; i < W.length; i++) {
              const rr = horiz ? sr : sr + i;
              const cc = horiz ? sc + i : sc;
              if (board[rr][cc] || !allowed(rr, cc)) {
                ok = false;
                break;
              }
              if (inCorner(corner, rr, cc)) touchesCorner = true;
              positions.push([rr, cc]);
            }
            if (!ok || !touchesCorner) continue;
            const tiles = consumeRack(W.split(''), rackLetters, owner);
            if (!tiles) continue;
            consider(
              positions.map(([pr, pc], i) => ({ r: pr, c: pc, tile: tiles[i] })),
              W,
            );
          }
        }
      }
    }
    return best;
  }

  // ── Çapalı hamleler: tahtadaki her taşı eksen alarak dene ────────────────────
  const tryPlace = (
    W: string,
    r: number,
    c: number,
    idx: number,
    horiz: boolean,
  ) => {
    const sr = horiz ? r : r - idx;
    const sc = horiz ? c - idx : c;
    if (horiz) {
      if (sc < 0 || sc + W.length > SIZE) return;
      if (
        !(
          (sc === 0 || !board[r][sc - 1]) &&
          (sc + W.length === SIZE || !board[r][sc + W.length])
        )
      )
        return;
    } else {
      if (sr < 0 || sr + W.length > SIZE) return;
      if (
        !(
          (sr === 0 || !board[sr - 1]?.[c]) &&
          (sr + W.length === SIZE || !board[sr + W.length]?.[c])
        )
      )
        return;
    }

    const newLetters: string[] = [];
    const newPositions: [number, number][] = [];
    for (let i = 0; i < W.length; i++) {
      const rr = horiz ? r : sr + i;
      const cc = horiz ? sc + i : c;
      const existing = board[rr][cc];
      if (existing) {
        if (tileLetter(existing) !== W[i]) return; // mevcut taşla uyuşmuyor
      } else {
        if (!allowed(rr, cc)) return; // bölge kuralı
        newLetters.push(W[i]);
        newPositions.push([rr, cc]);
      }
    }
    if (newLetters.length === 0) return; // en az bir yeni taş konmalı
    if (newLetters.length > rackLetters.length) return;
    const tiles = consumeRack(newLetters, rackLetters, owner);
    if (!tiles) return;
    consider(
      newPositions.map(([pr, pc], i) => ({ r: pr, c: pc, tile: tiles[i] })),
      W,
    );
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
