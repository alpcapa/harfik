// Kelimeki — kelime doğrulama, bölge kuralları ve puanlama
//
// src/utils/validator.ts'in KOPYASI (yalnızca play-ai-turn'ün ihtiyaç
// duyduğu kısım — validatePlacement/validatePlacementStructural burada
// yok, çünkü findAIMove zaten yalnızca sözlükte gerçekten var olan
// kelimeleri değerlendiriyor, sözlük kontrolünü kendi içinde yapıyor) —
// bkz. types.ts'teki not.
import { BINGO_BONUS, RACK_SIZE, SIZE, cornerBounds, inBonusZone } from './constants.ts';
import type { BonusType, Player } from './types.ts';
import type { Board, Placed } from './board.ts';
import { getFormedWords, key } from './board.ts';

/** Verilen harf havuzuyla kelime hecelenebilir mi? Joker ('?') jokeri sayar. */
export function canSpell(word: string, rack: string[]): boolean {
  const avail = [...rack];
  for (const ch of word) {
    const i = avail.indexOf(ch);
    if (i >= 0) {
      avail.splice(i, 1);
    } else {
      const wi = avail.indexOf('?');
      if (wi >= 0) avail.splice(wi, 1);
      else return false;
    }
  }
  return true;
}

/**
 * Oyuncunun sahip olduğu köşelerden, henüz hiç kendi taşının bulunmadığı
 * ("taze") olanları döner.
 */
export function freshCorners(board: Board, ownCorners: number[], owner: number): number[] {
  return ownCorners.filter((corner) => {
    const b = cornerBounds(corner);
    for (let r = b.r0; r <= b.r1; r++) {
      for (let c = b.c0; c <= b.c1; c++) {
        if (board[r][c]?.owner === owner) return false;
      }
    }
    return true;
  });
}

function computeConqueredChain(board: Board, ownCorners: number[], owner: number): Set<string> {
  const chain = new Set<string>();
  const stack: [number, number][] = [];
  for (const corner of ownCorners) {
    const b = cornerBounds(corner);
    for (let r = b.r0; r <= b.r1; r++) {
      for (let c = b.c0; c <= b.c1; c++) {
        const cell = board[r][c];
        if (cell && cell.owner !== owner) continue;
        const k = key(r, c);
        if (!chain.has(k)) {
          chain.add(k);
          stack.push([r, c]);
        }
      }
    }
  }
  while (stack.length > 0) {
    const [r, c] = stack.pop()!;
    const neighbors: [number, number][] = [
      [r - 1, c],
      [r + 1, c],
      [r, c - 1],
      [r, c + 1],
    ];
    for (const [nr, nc] of neighbors) {
      if (nr < 0 || nr >= SIZE || nc < 0 || nc >= SIZE) continue;
      const k = key(nr, nc);
      if (chain.has(k)) continue;
      if (board[nr][nc]?.owner === owner) {
        chain.add(k);
        stack.push([nr, nc]);
      }
    }
  }
  return chain;
}

/** Tüm oyuncuların bölgelerini (indekslerine göre) hesaplar. */
export function computeAllTerritories(board: Board, players: Player[]): Set<string>[] {
  const chains = players.map((p, i) =>
    p.surrendered ? new Set<string>() : computeConqueredChain(board, p.corners, i),
  );
  return players.map((p, i) => {
    if (p.surrendered) return new Set<string>();
    const territory = new Set(chains[i]);
    for (const corner of p.corners) {
      const b = cornerBounds(corner);
      for (let r = b.r0; r <= b.r1; r++) {
        for (let c = b.c0; c <= b.c1; c++) {
          const k = key(r, c);
          if (territory.has(k)) continue;
          const capturedByOther = chains.some((chain, j) => j !== i && chain.has(k));
          if (!capturedByOther) territory.add(k);
        }
      }
    }
    return territory;
  });
}

/** Rakip bölge(ler)ine sınır vergisini hesaplar (bkz. src/utils/validator.ts'teki tam not). */
export function computeInvasionSplit(
  coords: [number, number][],
  ownerIndex: number,
  players: Player[],
  basePts: number,
  board: Board,
): { pts: number; shares: { index: number; amount: number }[] } {
  const territories = computeAllTerritories(board, players);
  const touchedIdx = new Set<number>();
  const addIfForeign = (r: number, c: number) => {
    const k = key(r, c);
    for (let i = 0; i < territories.length; i++) {
      if (i !== ownerIndex && territories[i].has(k)) touchedIdx.add(i);
    }
  };
  for (const [r, c] of coords) {
    addIfForeign(r, c);
    const neighbors: [number, number][] = [
      [r - 1, c],
      [r + 1, c],
      [r, c - 1],
      [r, c + 1],
    ];
    for (const [nr, nc] of neighbors) {
      if (nr < 0 || nr >= SIZE || nc < 0 || nc >= SIZE) continue;
      addIfForeign(nr, nc);
    }
  }
  if (touchedIdx.size === 0) return { pts: basePts, shares: [] };
  const n = touchedIdx.size;
  const share = Math.round((basePts * (n + 1)) / (6 * n));
  const shares = [...touchedIdx].map((index) => ({ index, amount: share }));
  const pts = basePts - share * n;
  return { pts, shares };
}

function wordRawPoints(coords: [number, number][], board: Board, placed: Placed): number {
  let sum = 0;
  for (const [r, c] of coords) {
    const k = key(r, c);
    const pts = placed[k]?.pts ?? board[r][c]?.pts ?? 0;
    sum += pts;
  }
  return sum;
}

function wordBonusFlags(
  coords: [number, number][],
  placed: Placed,
  bonuses: Record<string, BonusType>,
): { x2: boolean; x3: boolean } {
  let hasTw = false;
  let touchesZone = false;
  for (const [r, c] of coords) {
    const k = key(r, c);
    const newTile = placed[k];
    if (newTile && bonuses[k] === 'tw') hasTw = true;
    if (newTile && inBonusZone(r, c)) touchesZone = true;
  }
  return { x2: !hasTw && touchesZone, x3: hasTw };
}

function wordPoints(
  coords: [number, number][],
  board: Board,
  placed: Placed,
  bonuses: Record<string, BonusType>,
): number {
  const { x2, x3 } = wordBonusFlags(coords, placed, bonuses);
  const wordMult = x3 ? 3 : x2 ? 2 : 1;
  return wordRawPoints(coords, board, placed) * wordMult;
}

/** Bu turda oluşan tüm kelimelerin toplam puanını hesaplar (bingo bonusu dahil). */
export function calcScore(board: Board, placed: Placed, bonuses: Record<string, BonusType>): number {
  let total = 0;
  for (const { coords } of getFormedWords(board, placed)) {
    total += wordPoints(coords, board, placed, bonuses);
  }
  if (Object.keys(placed).length >= RACK_SIZE) total += BINGO_BONUS;
  return total;
}

/** Bu turda oluşan her kelimenin harf puanları toplamı (X2/X3 UYGULANMADAN) + bonus rozetleri. */
export function calcWordRawScores(
  board: Board,
  placed: Placed,
  bonuses: Record<string, BonusType>,
): { word: string; score: number; x2: boolean; x3: boolean }[] {
  return getFormedWords(board, placed).map(({ word, coords }) => ({
    word,
    score: wordRawPoints(coords, board, placed),
    ...wordBonusFlags(coords, placed, bonuses),
  }));
}
