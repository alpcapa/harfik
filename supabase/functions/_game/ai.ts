// Kelimeki — YZ rakip mantığı (çok oyunculu, köşe temelli)
//
// src/utils/ai.ts'in KOPYASI — bkz. types.ts'teki not.
import { SIZE, cornerBounds, cornerCell } from './constants.ts';
import type { AIMove, BonusType, Placement, Player, Tile } from './types.ts';
import { getWordSet } from './wordSet.ts';
import { letterPoints } from './tiles.ts';
import { canSpell, calcScore, computeAllTerritories, freshCorners } from './validator.ts';
import { trLower, trUpper } from './turkish.ts';
import type { Board } from './board.ts';
import { getFormedWords, key, tileLetter } from './board.ts';

let wordPool: readonly string[] | undefined;
function getWordPool(): readonly string[] {
  if (!wordPool) {
    wordPool = [...getWordSet()]
      .filter((w) => w.length >= 2 && w.length <= 7)
      .map((w) => trUpper(w));
  }
  return wordPool;
}

function consumeRack(letters: string[], rackLetters: string[], owner: number): Tile[] | null {
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
 * `corners` YZ'nin köşeleri, `isFirstMove` bu oyuncunun ilk hamlesi mi.
 */
export function findAIMove(
  board: Board,
  rack: Tile[],
  bonuses: Record<string, BonusType>,
  owner: number,
  corners: number[],
  isFirstMove: boolean,
  players: Player[],
): AIMove | null {
  const rackLetters = rack.map((t) => t.letter);
  const wordPoolLocal = getWordPool();
  const candidates = wordPoolLocal.filter((w) => canSpell(w, rackLetters));

  const anchoredCandidatesCache = new Map<string, string[]>();
  const candidatesForAnchor = (letter: string): string[] => {
    let cached = anchoredCandidatesCache.get(letter);
    if (!cached) {
      cached = wordPoolLocal.filter(
        (w) => w.includes(letter) && canSpell(w, [...rackLetters, letter]),
      );
      anchoredCandidatesCache.set(letter, cached);
    }
    return cached;
  };

  let bestSafe: AIMove | null = null;
  let bestAny: AIMove | null = null;
  let bestAnyEffective = -Infinity;

  const territories = computeAllTerritories(board, players);

  const consider = (placements: Placement[], word: string) => {
    const placed: Record<string, Tile> = {};
    for (const p of placements) placed[key(p.r, p.c)] = p.tile;
    for (const fw of getFormedWords(board, placed)) {
      if (!getWordSet().has(trLower(fw.word))) return;
    }
    const touchedIdx = new Set<number>();
    const addIfForeign = (r: number, c: number) => {
      const k = key(r, c);
      for (let i = 0; i < territories.length; i++) {
        if (i !== owner && territories[i].has(k)) touchedIdx.add(i);
      }
    };
    for (const p of placements) {
      addIfForeign(p.r, p.c);
      const neighbors: [number, number][] = [
        [p.r - 1, p.c],
        [p.r + 1, p.c],
        [p.r, p.c - 1],
        [p.r, p.c + 1],
      ];
      for (const [nr, nc] of neighbors) {
        if (nr < 0 || nr >= SIZE || nc < 0 || nc >= SIZE) continue;
        addIfForeign(nr, nc);
      }
    }
    const score = calcScore(board, placed, bonuses);
    if (touchedIdx.size === 0) {
      if (!bestSafe || score > bestSafe.score) bestSafe = { word, score, placements };
      if (score > bestAnyEffective) {
        bestAnyEffective = score;
        bestAny = { word, score, placements };
      }
      return;
    }
    const denom = touchedIdx.size === 1 ? 3 : touchedIdx.size + 1;
    const share = Math.round(score / denom);
    const effective = score - share * touchedIdx.size;
    if (effective > bestAnyEffective) {
      bestAnyEffective = effective;
      bestAny = { word, score, placements };
    }
  };

  const tryCornerStart = (homeCorner: number) => {
    const b = cornerBounds(homeCorner);
    const [homeR, homeC] = cornerCell(homeCorner);
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
              if (board[rr][cc]) {
                ok = false;
                break;
              }
              if (rr === homeR && cc === homeC) touchesCorner = true;
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
  };

  if (isFirstMove) {
    for (const homeCorner of corners) tryCornerStart(homeCorner);
    return bestSafe;
  }

  const tryPlace = (W: string, r: number, c: number, idx: number, horiz: boolean) => {
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
        if (tileLetter(existing) !== W[i]) return;
      } else {
        newLetters.push(W[i]);
        newPositions.push([rr, cc]);
      }
    }
    if (newLetters.length === 0) return;
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
      for (const W of candidatesForAnchor(anchor)) {
        let idx = W.indexOf(anchor);
        while (idx >= 0) {
          tryPlace(W, r, c, idx, true);
          tryPlace(W, r, c, idx, false);
          idx = W.indexOf(anchor, idx + 1);
        }
      }
    }
  }

  for (const homeCorner of freshCorners(board, corners, owner)) {
    tryCornerStart(homeCorner);
  }

  return bestSafe ?? bestAny;
}
