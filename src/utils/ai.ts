// Kelimeki — YZ rakip mantığı (çok oyunculu, köşe temelli)
//
// YZ, rafından heceleyebildiği kelimeler arasından, bölge kurallarına uyan
// ve sözlükçe geçerli en yüksek puanlı hamleyi arar. İlk hamlesini kendi
// köşesinden başlatır; sonra mevcut taşları çapa alarak yeni kelimeler kurar.
import { SIZE, cornerBounds, cornerCell } from '../game/constants';
import type { AIMove, BonusType, Placement, Player, Tile } from '../game/types';
import { getWordSet } from '../data/wordSetLoader';
import { letterPoints } from '../data/tiles';
import { canSpell, calcScore, computeAllTerritories, freshCorners } from './validator';
import { trLower, trUpper } from './turkish';
import { getFormedWords, key, tileLetter, type Board } from './board';

// WORD_SET sabit olduğundan (oyun boyunca değişmez), rafa/tahtaya/oyuncuya
// bağlı olmayan bu türetilmiş liste ilk `findAIMove` çağrısında bir kez
// hesaplanıp önbelleğe alınır — önceden her çağrıda baştan yeniden
// üretiliyordu, bu da tahtada çapa harfi arttıkça YZ'nin "düşünme"
// süresini gereksiz yere uzatıyordu. Modül yüklenirken DEĞİL ilk
// kullanımda hesaplanmasının sebebi, WORD_SET'in artık ayrı bir chunk'tan
// (bkz. wordSetLoader.ts) geldiği ve modül değerlendirme anında henüz
// yüklenmemiş olabilmesidir.
let wordPool: readonly string[] | undefined;
function getWordPool(): readonly string[] {
  if (!wordPool) {
    wordPool = [...getWordSet()]
      .filter((w) => w.length >= 2 && w.length <= 7)
      .map((w) => trUpper(w));
  }
  return wordPool;
}

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
  const wordPool = getWordPool();
  // tryCornerStart dışında hiç kullanılmıyor — bu da yalnızca isFirstMove
  // (ya da nadir freshCorners) dallarında tetikleniyor. Her normal hamlede
  // onbinlerce kelimeyi boşuna filtrelememek için tembel/önbellekli hesap.
  let candidatesCache: string[] | undefined;
  const candidates = (): string[] => {
    if (!candidatesCache) {
      candidatesCache = wordPool.filter((w) => canSpell(w, rackLetters));
    }
    return candidatesCache;
  };

  // Çapalı hamlelerde kelimenin bir harfi tahtada zaten var olabilir (çapa).
  // O harfi rafta aramaya gerek yok — rafa + çapa harfine göre gevşetilmiş
  // aday listesi, harfe göre önbelleklenir (bu çağrı için — rafın kendisi
  // her hamlede değiştiğinden bu seviyedeki cache modül seviyesine taşınamaz).
  const anchoredCandidatesCache = new Map<string, string[]>();
  const candidatesForAnchor = (letter: string): string[] => {
    let cached = anchoredCandidatesCache.get(letter);
    if (!cached) {
      cached = wordPool.filter(
        (w) => w.includes(letter) && canSpell(w, [...rackLetters, letter]),
      );
      anchoredCandidatesCache.set(letter, cached);
    }
    return cached;
  };

  // Bir rakip köşesine girilen ya da sınırına dışarıdan değinilen hamlede
  // puan paylaşılır (bkz. computeInvasionSplit) — girmek için artık hiçbir
  // ön koşul yok, her zaman serbest. YZ, mecbur kalmadıkça (böyle bir
  // paylaşım gerektirmeyen geçerli bir hamlesi varken) paylaşım yapmamalı.
  // Bu yüzden iki ayrı en-iyi takip edilir: `bestSafe` yalnızca hiçbir rakip
  // köşeyle etkileşmeyen hamleler için, `bestAny` (paylaşım sonrası
  // kendisine kalacak puana göre sıralanan) tüm hamleler için. `bestSafe`
  // varsa her zaman o tercih edilir.
  let bestSafe: AIMove | null = null;
  let bestAny: AIMove | null = null;
  let bestAnyEffective = -Infinity;

  // Rakiplerin bölgeleri (kendi köşelerinden, kendi taşlarıyla genişleyen
  // dinamik alan) — arama boyunca tahta sabit olduğundan bir kez hesaplanır.
  const territories = computeAllTerritories(board, players);

  const consider = (placements: Placement[], word: string) => {
    const placed: Record<string, Tile> = {};
    for (const p of placements) placed[key(p.r, p.c)] = p.tile;
    // Oluşan tüm kelimeler (çapraz dahil) sözlükte olmalı.
    for (const fw of getFormedWords(board, placed)) {
      if (!getWordSet().has(trLower(fw.word))) return;
    }
    // Yeni taşlardan biri bir rakip bölgesinin içine düşüyorsa (girme) ya da
    // dışarıdan sınırına bitişikse (değme), o bölgeyle puan paylaşılır.
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
    // Paylaşım sonrası YZ'ye kalacak gerçek puan — validator.ts'teki
    // `computeInvasionSplit`'in AYNI formülü (`round(basePts*(n+1)/(6n))`),
    // burada `territories`nin zaten önbelleğe alınmış olmasından
    // yararlanmak için elle tekrarlanıyor (computeInvasionSplit'in
    // kendisini çağırmak, aday hamle başına computeAllTerritories'i
    // yeniden hesaplayıp arama performansını ciddi biçimde düşürürdü).
    // Önceki hâli n=2/3'te yanlış bir bölen kullanıyordu (bkz. kod
    // incelemesi) — bu, YZ'nin kârlı çoklu-bölge hamlelerini olduğundan
    // az kazançlı sanmasına yol açıyordu.
    const n = touchedIdx.size;
    const share = Math.round((score * (n + 1)) / (6 * n));
    const effective = score - share * n;
    if (effective > bestAnyEffective) {
      bestAnyEffective = effective;
      bestAny = { word, score, placements };
    }
  };

  // Verilen köşeden, tahtadaki mevcut taşlardan bağımsız yeni bir kelimeyle
  // başlayan tüm yerleşimleri dener (yalnızca ilk hamle — her oyuncunun tek
  // köşesi olduğundan bu, o köşe hiç kullanılmamışken geçerli tek durumdur).
  const tryCornerStart = (homeCorner: number) => {
    const b = cornerBounds(homeCorner);
    const [homeR, homeC] = cornerCell(homeCorner);
    for (let sr = b.r0; sr <= b.r1; sr++) {
      for (let sc = b.c0; sc <= b.c1; sc++) {
        for (const W of candidates()) {
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

  // ── İlk hamle: kendi köşelerinden birinden başla ────────────────────────────
  if (isFirstMove) {
    for (const homeCorner of corners) tryCornerStart(homeCorner);
    return bestSafe;
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

  // Her oyuncunun tek köşesi olduğundan (bkz. cornersFor, constants.ts) bu
  // döngü pratikte hiç tetiklenmez — isFirstMove true iken zaten yukarıdaki
  // dal çalışıyor, o hamleden sonra tek köşe artık "taze" olmaktan çıkıyor.
  // `freshCorners` genel bir yardımcı olduğundan burada da bilgi amaçlı
  // çağrılıyor; oyuncu başına birden fazla köşe atanırsa devreye girer.
  for (const homeCorner of freshCorners(board, corners, owner)) {
    tryCornerStart(homeCorner);
  }

  // Hiçbir rakip köşeyle etkileşmeyen geçerli bir hamle varsa, puanı
  // paylaşmak zorunda kalmamak için o hamle her zaman tercih edilir.
  // Yalnızca hiç güvenli hamle yoksa (mecburen) rakip köşeye girilir/sınırına
  // değilir — bu durumda da paylaşım sonrası kendisine kalacak puana göre en
  // iyi seçenek kullanılır.
  return bestSafe ?? bestAny;
}
