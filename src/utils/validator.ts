// Harfik — kelime doğrulama, bölge kuralları ve puanlama
import { BINGO_BONUS, SIZE, inCorner, regionOf } from '../game/constants';
import type { BonusType, Player, ValidationResult } from '../game/types';
import { WORD_SET } from '../data/words';
import {
  getFormedWords,
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
 * Hangi köşelerin "açıldığını" hesaplar. Bir köşe, sahibi kendi 5×5'inin
 * dışına taş taşırdığında (yani bölgesinden çıktığında) açılır; açılınca
 * diğer oyuncular da o köşeye ekleme yapabilir.
 */
export function computeOpenCorners(board: Board, players: Player[]): boolean[] {
  const open = [false, false, false, false];
  // Hiçbir oyuncuya ait olmayan köşeler (örn. 2 kişilik oyunda) baştan açıktır.
  const owned = new Set(players.map((p) => p.corner));
  for (let i = 0; i < 4; i++) if (!owned.has(i)) open[i] = true;

  players.forEach((p, idx) => {
    // Bu oyuncunun, kendi köşesi dışında tahtaya koyduğu bir taşı var mı?
    for (let r = 0; r < SIZE && !open[p.corner]; r++) {
      for (let c = 0; c < SIZE; c++) {
        const t = board[r][c];
        if (t && t.owner === idx && !inCorner(p.corner, r, c)) {
          open[p.corner] = true;
          break;
        }
      }
    }
  });
  return open;
}

/**
 * Sırası gelen oyuncu (r,c) hücresine taş koyabilir mi? Bölge kuralı:
 *  - Merkez (köşe dışı) hücreler herkese açık.
 *  - Kendi köşen her zaman açık.
 *  - Başka bir köşeye yalnızca o köşe "açıldıysa" oynanabilir.
 */
export function cellAllowed(
  ownCorner: number,
  openCorners: boolean[],
  r: number,
  c: number,
): boolean {
  const region = regionOf(r, c);
  if (region === -1) return true; // merkez
  if (region === ownCorner) return true; // kendi köşen
  return openCorners[region]; // yabancı köşe yalnızca açıksa
}

/**
 * Oyuncunun bu turdaki yerleştirmesini doğrular: hizalama, bölge kuralları,
 * bağlantı, geçersiz hücreler ve sözlük. Geçerliyse oluşan kelimeleri döndürür.
 */
export function validatePlacement(
  board: Board,
  placed: Placed,
  ownCorner: number,
  openCorners: boolean[],
  isFirstMove: boolean,
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

  // Bölge kuralı: her yeni taş izinli bir hücreye konmalı.
  for (const [r, c] of coords) {
    if (!cellAllowed(ownCorner, openCorners, r, c)) {
      return {
        valid: false,
        reason: 'O bölge henüz açılmadı — önce kendi köşenden çıkıp ona ulaşmalısın.',
      };
    }
  }

  if (isFirstMove) {
    // İlk hamlede en az bir taş kendi köşenin içinde olmalı.
    const startsHome = coords.some(([r, c]) => inCorner(ownCorner, r, c));
    if (!startsHome) {
      return { valid: false, reason: 'İlk kelimen kendi köşenden başlamalı.' };
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
