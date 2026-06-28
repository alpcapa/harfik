// Harfik — tahta evrimi
//
// Her birkaç hamlede bir tahta "evrilir": önceden çatlamış boş kareler
// boşluğa (oynanamaz) dönüşür, yeni boş kareler çatlar ve birkaç yeni bonus
// kare belirir. Köşe bölgeleri (oyuncu/YZ başlangıçları) çatlamadan korunur.
import { SIZE } from '../game/constants';
import type { BonusType, CellKey, CellState } from '../game/types';
import { key, type Board } from './board';
import { pick, shuffle } from './random';

const BONUS_POOL: BonusType[] = ['dw', 'dw', 'tw', 'dl', 'dl', 'tl'];

export interface EvolveResult {
  cellState: Record<CellKey, CellState>;
  bonuses: Record<CellKey, BonusType>;
}

/** Hücre, başlangıç köşe bölgelerinden birinde mi? (çatlamadan korunur) */
function isProtected(r: number, c: number): boolean {
  return (r >= 10 && c <= 2) || (r <= 2 && c >= 10);
}

export function evolveBoard(
  board: Board,
  cellState: Record<CellKey, CellState>,
  bonuses: Record<CellKey, BonusType>,
  turnCount: number,
): EvolveResult {
  const nextCellState: Record<CellKey, CellState> = { ...cellState };
  const nextBonuses: Record<CellKey, BonusType> = { ...bonuses };

  // 1) Üzerinde taş olmayan çatlak kareler boşluğa dönüşür.
  for (const [k, state] of Object.entries(nextCellState)) {
    if (state === 'crack') {
      const [r, c] = k.split(',').map(Number);
      if (!board[r][c]) nextCellState[k] = 'void';
    }
  }

  // 2) Yeni boş kareler çatlar (köşe bölgeleri ve dolu kareler hariç).
  const empties: [number, number][] = [];
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const k = key(r, c);
      if (!board[r][c] && !nextCellState[k] && !isProtected(r, c)) {
        empties.push([r, c]);
      }
    }
  }
  shuffle(empties);
  const toCrack = Math.min(4 + Math.floor(turnCount / 4), empties.length, 6);
  for (let i = 0; i < toCrack; i++) {
    const [r, c] = empties[i];
    nextCellState[key(r, c)] = 'crack';
  }

  // 3) Birkaç yeni bonus kare belirir (boş, bonusu olmayan, normal karelerde).
  const openForBonus: CellKey[] = [];
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const k = key(r, c);
      if (!board[r][c] && !nextBonuses[k] && !nextCellState[k]) {
        openForBonus.push(k);
      }
    }
  }
  shuffle(openForBonus);
  const toAdd = Math.min(2, openForBonus.length);
  for (let i = 0; i < toAdd; i++) {
    nextBonuses[openForBonus[i]] = pick(BONUS_POOL);
  }

  return { cellState: nextCellState, bonuses: nextBonuses };
}
