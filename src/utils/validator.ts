// Harfik — kelime doğrulama ve puanlama
import { BINGO_BONUS, SIZE, playerZone } from '../game/constants';
import type { BonusType, ValidationResult } from '../game/types';
import { WORD_SET } from '../data/words';
import {
  getFormedWords,
  isEmpty,
  key,
  type Board,
  type Placed,
} from './board';

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
 * Oyuncunun bu turdaki yerleştirmesini doğrular: hizalama, bölge/bağlantı,
 * geçersiz hücreler ve sözlük kontrolü. Geçerliyse oluşan kelimeleri döndürür.
 */
export function validatePlacement(
  board: Board,
  placed: Placed,
  cellState: Record<string, string>,
): ValidationResult {
  const keys = Object.keys(placed);
  if (keys.length === 0) {
    return { valid: false, reason: 'Harf yerleştirilmedi.' };
  }

  const coords = keys.map((k) => k.split(',').map(Number) as [number, number]);
  const rows = [...new Set(coords.map((p) => p[0]))];
  const cols = [...new Set(coords.map((p) => p[1]))];
  const horiz = rows.length === 1;
  const vert = cols.length === 1;
  if (!horiz && !vert) {
    return { valid: false, reason: 'Harfler aynı satır ya da sütunda olmalı.' };
  }

  // Geçersiz hücre kontrolü (boşluk/çatlak üstüne oynanamaz).
  for (const [r, c] of coords) {
    const st = cellState[key(r, c)];
    if (st === 'void' || st === 'crack') {
      return { valid: false, reason: 'Çatlamış ya da boş kareye oynanamaz.' };
    }
  }

  const first = isEmpty(board);
  if (first) {
    // İlk kelime oyuncunun bölgesinden (sol-alt) başlamalı.
    const inZone = coords.some(([r, c]) => playerZone(r, c));
    if (!inZone) {
      return { valid: false, reason: 'İlk kelime sol-alt köşeden başlamalı.' };
    }
  } else {
    // Sonraki hamleler mevcut bir taşa değmeli.
    const connects = coords.some(([r, c]) =>
      [
        [r - 1, c],
        [r + 1, c],
        [r, c - 1],
        [r, c + 1],
      ].some(
        ([nr, nc]) =>
          nr >= 0 && nr < SIZE && nc >= 0 && nc < SIZE && board[nr][nc],
      ),
    );
    if (!connects) {
      return { valid: false, reason: 'Kelime mevcut harflere bağlanmalı.' };
    }
  }

  const formed = getFormedWords(board, placed);
  if (formed.length === 0) {
    return { valid: false, reason: 'Geçerli kelime oluşmadı.' };
  }

  for (const { word } of formed) {
    if (!WORD_SET.has(word.toLowerCase())) {
      return { valid: false, reason: `"${word}" geçerli bir kelime değil.` };
    }
  }

  return { valid: true, words: formed.map((f) => f.word) };
}

/**
 * Bu turda oluşan tüm kelimelerin toplam puanını hesaplar. Bonuslar yalnızca
 * bu turda yeni konan taşlara uygulanır. Tüm raf kullanılırsa bingo bonusu.
 */
export function calcScore(
  board: Board,
  placed: Placed,
  bonuses: Record<string, BonusType>,
): number {
  let total = 0;
  for (const { coords } of getFormedWords(board, placed)) {
    let sum = 0;
    let wordMult = 1;
    for (const [r, c] of coords) {
      const k = key(r, c);
      const newTile = placed[k];
      const pts = newTile?.pts ?? board[r][c]?.pts ?? 0;
      const b = newTile ? bonuses[k] : undefined; // bonus yalnızca yeni taşta
      if (b === 'dl') sum += pts * 2;
      else if (b === 'tl') sum += pts * 3;
      else if (b === 'dw') {
        wordMult *= 2;
        sum += pts;
      } else if (b === 'tw') {
        wordMult *= 3;
        sum += pts;
      } else {
        sum += pts;
      }
    }
    total += sum * wordMult;
  }
  if (Object.keys(placed).length >= 7) total += BINGO_BONUS;
  return total;
}
