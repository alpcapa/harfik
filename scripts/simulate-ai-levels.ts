// Kelimeki — YZ seviye kadranı için YZ↔YZ ölçüm aleti (ROADMAP #23, Faz 0).
//
// NE ÖLÇER: bugünkü üretim motoru (N=1, "en yüksek puanlı hamle") ile
// "en iyi N hamleden RASTGELE biri" oynayan zayıflatılmış bir motoru
// birbirine karşı koşturur; N başına kazanma oranı, ortalama skor ve
// ortalama hamle puanı çıkarır. Tablonun kolonları backlog'daki 5 Eylül 2026
// ölçümüyle (docs/decisions/product-backlog.md → "YZ zorluk seviyesi")
// BİREBİR aynı ki eski ölçümle yan yana okunabilsin.
//
// ⚠ Bu YZ↔YZ oranıdır, insan oranı DEĞİL. N=1 satırı iki aynı motorun
// birbirine oynaması, yani yapısı gereği ~%50 — yalnızca sıfır çizgisi.
// Kolay/Zor hedefleri (YZ insana karşı ~%30 / ~%70) SAHADA
// `admin_ai_balance` ile ölçülür; burası ön eleme.
//
// KOD ÜRÜNE GİRMEZ: `src/utils/ai.ts`e dokunulmadı (Faz 2'nin işi; o
// değişiklik golden vector + Edge kopyası + `play-ai-turn` deploy'u ister).
// Bunun yerine `findAIMove`'un arama döngüsü buraya KOPYALANDI ve tek fark
// olarak "iki en-iyi" yerine "iki sınırlı liste" tutuyor — Faz 2'de motora
// girecek tasarımın prototipi (ROADMAP 23.3 → Faz 2). Kopya ayrışmasın diye
// `--dogrula` ile her hamlede listenin başı üretim `findAIMove`'un
// sonucuyla karşılaştırılır (kelime + puan + yerleşim); fark varsa betik
// hata verir. Bu kontrol Faz 2 bittiğinde anlamsızlaşır — o zaman bu betik
// motorun kendi `level` parametresini çağırmalı.
//
// KOLTUK DEĞİŞİMİ: çift numaralı oyunlarda top-N motoru 2. koltukta
// (köşe 3), tek numaralılarda 1. koltukta (köşe 0) — ilk hamle avantajı
// ve köşe farkı ortalamaya dağılır. Üretim (N=1) tarafı reducer'ın kendi
// `AI_PLAY` action'ıyla oynar, yani gerçekten üretim kodudur; top-N tarafı
// `PLACE_TILE`+`PLAY` (hamle yoksa YZ ile aynı: torba doluysa tüm rafı
// değiştir, boşsa pas) ile sürülür.
//
// RASTGELELİK: oyun başına tohum = temel tohum + oyun sırası; tohumlu
// mulberry32 hem torbaya (`setRandomSource`) hem top-N seçimine aynı akıştan
// verilir. N=1'de rastgele ÇAĞRI YAPILMAZ (Faz 2 sözleşmesinin aynısı: N=1
// yolu bayt-eş kalmalı). Aynı tohum + aynı N → aynı oyun.
//
// Koşum (repo kökünden):
//   npm run simulate-ai-levels                       # N ∈ {1,2,3,5}, 100 oyun, tohum 1
//   npm run simulate-ai-levels -- --oyun 200 --n 2,3 --tohum 42
//   npm run simulate-ai-levels -- --dogrula 0        # üretimle karşılaştırmayı kapat
//   npm run simulate-ai-levels -- --dogrula hepsi    # HER oyunun her hamlesinde karşılaştır
// Varsayılan `--dogrula 3`: N başına ilk 3 oyunun her hamlesi doğrulanır.
import { performance } from 'node:perf_hooks';
import { SIZE, cornerCell } from '../src/game/constants';
import type { AIMove, BonusType, Placement, Player, Tile } from '../src/game/types';
import type { GameState } from '../src/game/types';
import { gameReducer, createInitialState, isFirstMove, type Action } from '../src/game/gameReducer';
import { preloadWordSet, getWordSet } from '../src/data/wordSetLoader';
import { letterPoints } from '../src/data/tiles';
import { canSpell, calcScore, computeAllTerritories, freshCorners } from '../src/utils/validator';
import { trLower, trUpper } from '../src/utils/turkish';
import { getFormedWords, key, tileLetter, type Board } from '../src/utils/board';
import { findAIMove } from '../src/utils/ai';
import { setRandomSource } from '../src/utils/random';

// ── Argümanlar ───────────────────────────────────────────────────────────────
interface Args {
  games: number;
  ns: number[];
  seed: number;
  /** Kaç oyunda üretimle karşılaştırılacak (Infinity = hepsi). */
  verifyGames: number;
}

function parseArgs(argv: string[]): Args {
  const a: Args = { games: 100, ns: [1, 2, 3, 5], seed: 1, verifyGames: 3 };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const val = argv[i + 1];
    const need = (): string => {
      if (val === undefined) throw new Error(`${flag} bir değer ister`);
      i++;
      return val;
    };
    switch (flag) {
      case '--oyun':
        a.games = Number(need());
        break;
      case '--n':
        a.ns = need().split(',').map((s) => Number(s.trim())).filter((n) => n >= 1);
        break;
      case '--tohum':
        a.seed = Number(need());
        break;
      case '--dogrula': {
        const v = need();
        a.verifyGames = v === 'hepsi' ? Infinity : Number(v);
        break;
      }
      default:
        throw new Error(`bilinmeyen argüman: ${flag}`);
    }
  }
  if (!Number.isFinite(a.games) || a.games < 1) throw new Error('--oyun ≥ 1 olmalı');
  if (a.ns.length === 0) throw new Error('--n en az bir N ister');
  return a;
}

// ── PRNG: golden üreticisiyle aynı mulberry32 ────────────────────────────────
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ── Motor kopyası: findAIMove'un arama döngüsü + sınırlı en-iyi listesi ──────
// `src/utils/ai.ts`teki `findAIMove` ile satır satır aynı; TEK fark
// `consider`ın `bestSafe`/`bestAny` yerine `safe`/`any` listelerini
// beslemesi. Listeye ekleme "puan eşitse ilk bulunan önde" kuralını korur
// (üretimdeki kesin `>` karşılaştırmasının liste hâli) — `sort` YOK, sıralı
// ekleme var (ROADMAP 23.4 tuzağı).
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

interface Ranked {
  move: AIMove;
  /** Sıralama anahtarı: güvenli listede ham puan, vergili listede YZ'ye kalan. */
  rank: number;
}

/** Azalan `rank` sırasıyla, eşitte SONA (ilk bulunan önde) ekler; boyutu n'de tutar. */
function insertBounded(list: Ranked[], item: Ranked, n: number): void {
  let i = 0;
  while (i < list.length && list[i].rank >= item.rank) i++;
  if (i >= n) return;
  list.splice(i, 0, item);
  if (list.length > n) list.length = n;
}

/**
 * Üretim `findAIMove`'unun sıralı en-iyi-N listesi. Dönüş: güvenli (vergisiz)
 * liste boş değilse o, değilse vergili liste. `list[0]` her zaman üretimin
 * döndüreceği hamledir (`--dogrula` bunu kanıtlar).
 */
function findTopMoves(
  board: Board,
  rack: Tile[],
  bonuses: Record<string, BonusType>,
  owner: number,
  corners: number[],
  firstMove: boolean,
  players: Player[],
  n: number,
): AIMove[] {
  const rackLetters = rack.map((t) => t.letter);
  const pool = getWordPool();
  let candidatesCache: string[] | undefined;
  const candidates = (): string[] => {
    if (!candidatesCache) candidatesCache = pool.filter((w) => canSpell(w, rackLetters));
    return candidatesCache;
  };
  const anchoredCandidatesCache = new Map<string, string[]>();
  const candidatesForAnchor = (letter: string): string[] => {
    let cached = anchoredCandidatesCache.get(letter);
    if (!cached) {
      cached = pool.filter((w) => w.includes(letter) && canSpell(w, [...rackLetters, letter]));
      anchoredCandidatesCache.set(letter, cached);
    }
    return cached;
  };

  const safe: Ranked[] = [];
  const any: Ranked[] = [];
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
    const move: AIMove = { word, score, placements };
    if (touchedIdx.size === 0) {
      insertBounded(safe, { move, rank: score }, n);
      insertBounded(any, { move, rank: score }, n);
      return;
    }
    const k = touchedIdx.size;
    const share = Math.round((score * (k + 1)) / (6 * k));
    insertBounded(any, { move, rank: score - share * k }, n);
  };

  const tryCornerStart = (homeCorner: number) => {
    const [homeR, homeC] = cornerCell(homeCorner);
    for (const W of candidates()) {
      for (let idx = 0; idx < W.length; idx++) {
        for (const horiz of [true, false]) {
          const sr = horiz ? homeR : homeR - idx;
          const sc = horiz ? homeC - idx : homeC;
          if (sr < 0 || sc < 0) continue;
          const er = horiz ? sr : sr + W.length - 1;
          const ec = horiz ? sc + W.length - 1 : sc;
          if (er >= SIZE || ec >= SIZE) continue;
          let ok = true;
          const positions: [number, number][] = [];
          for (let i = 0; i < W.length; i++) {
            const rr = horiz ? sr : sr + i;
            const cc = horiz ? sc + i : sc;
            if (board[rr][cc]) {
              ok = false;
              break;
            }
            positions.push([rr, cc]);
          }
          if (!ok) continue;
          const tiles = consumeRack(W.split(''), rackLetters, owner);
          if (!tiles) continue;
          consider(positions.map(([pr, pc], i) => ({ r: pr, c: pc, tile: tiles[i] })), W);
        }
      }
    }
  };

  if (firstMove) {
    for (const homeCorner of corners) tryCornerStart(homeCorner);
    return safe.map((x) => x.move);
  }

  const tryPlace = (W: string, r: number, c: number, idx: number, horiz: boolean) => {
    const sr = horiz ? r : r - idx;
    const sc = horiz ? c - idx : c;
    if (horiz) {
      if (sc < 0 || sc + W.length > SIZE) return;
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
    consider(newPositions.map(([pr, pc], i) => ({ r: pr, c: pc, tile: tiles[i] })), W);
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
  for (const homeCorner of freshCorners(board, corners, owner)) tryCornerStart(homeCorner);

  return (safe.length > 0 ? safe : any).map((x) => x.move);
}

// ── Oyun sürücüsü ────────────────────────────────────────────────────────────
interface GameResult {
  /** top-N motorunun skoru ve üretimin skoru. */
  topN: number;
  prod: number;
  topNMoves: number;
  topNMoveScoreSum: number;
  topNSeat: 0 | 1;
}

function moveKey(m: AIMove): string {
  return JSON.stringify([
    m.word,
    m.score,
    m.placements.map((p) => [p.r, p.c, p.tile.letter, p.tile.wildLetter ?? null]),
  ]);
}

function playOne(n: number, seed: number, topNSeat: 0 | 1, verify: boolean): GameResult {
  const rng = mulberry32(seed);
  setRandomSource(rng);
  let state: GameState = createInitialState();
  const d = (a: Action) => {
    state = gameReducer(state, a);
  };
  const setups = [
    { name: 'Normal', isAI: true },
    { name: 'Normal', isAI: true },
  ];
  // top-N koltuğu insan gibi sürülür (TOGGLE_SWAP_MODE isAI'yi reddediyor).
  setups[topNSeat] = { name: `Top${n}`, isAI: false };
  d({ type: 'START', players: setups });

  let guard = 0;
  while (!state.isGameOver && guard++ < 400) {
    if (state.current !== topNSeat) {
      d({ type: 'AI_PLAY' });
      continue;
    }
    const me = state.players[state.current];
    const first = isFirstMove(state);
    const list = findTopMoves(state.board, me.rack, state.bonuses, state.current, me.corners, first, state.players, n);
    if (verify) {
      const prod = findAIMove(state.board, me.rack, state.bonuses, state.current, me.corners, first, state.players);
      const a = prod ? moveKey(prod) : 'null';
      const b = list.length > 0 ? moveKey(list[0]) : 'null';
      if (a !== b) {
        throw new Error(
          `KOPYA AYRIŞTI (tohum ${seed}, tur ${state.turnCount}): üretim ${a} ≠ liste başı ${b}`,
        );
      }
    }
    if (list.length === 0) {
      if (state.bag.length > 0) {
        // YZ'nin zorunlu değişimiyle aynı: tüm raf torbaya, yenisi çekilir.
        d({ type: 'TOGGLE_SWAP_MODE' });
        const rackLen = state.players[state.current].rack.length;
        for (let i = 0; i < rackLen; i++) d({ type: 'TOGGLE_SWAP_TILE', index: i });
        d({ type: 'CONFIRM_SWAP' });
      } else {
        d({ type: 'PASS' });
      }
      continue;
    }
    // N=1 → rastgele ÇAĞRI YOK (Faz 2 sözleşmesi); N>1 → tek çağrı.
    const move = list.length === 1 ? list[0] : list[Math.floor(rng() * list.length)];
    for (const p of move.placements) {
      const rack = state.players[state.current].rack;
      const idx = p.tile.wild
        ? rack.findIndex((t) => t.letter === '?')
        : rack.findIndex((t) => t.letter === p.tile.letter);
      if (idx < 0) throw new Error(`raf tutarsız (tohum ${seed}): ${p.tile.letter}`);
      d(
        p.tile.wild
          ? { type: 'PLACE_TILE', r: p.r, c: p.c, rackIndex: idx, wildLetter: p.tile.wildLetter }
          : { type: 'PLACE_TILE', r: p.r, c: p.c, rackIndex: idx },
      );
    }
    const before = state.turnCount;
    d({ type: 'PLAY' });
    if (state.turnCount === before && !state.isGameOver) {
      throw new Error(`PLAY reddedildi (tohum ${seed}): ${state.message}`);
    }
  }
  if (!state.isGameOver) throw new Error(`oyun bitmedi (tohum ${seed}, 400 tur)`);

  const top = state.players[topNSeat];
  const prod = state.players[1 - topNSeat];
  return {
    topN: top.score,
    prod: prod.score,
    topNMoves: top.moveCount,
    topNMoveScoreSum: top.moveScoreSum,
    topNSeat,
  };
}

// ── İstatistik ───────────────────────────────────────────────────────────────
/** Wilson %95 güven aralığı — oran ± yerine [alt, üst]. */
function wilson(wins: number, total: number): [number, number] {
  if (total === 0) return [0, 0];
  const z = 1.96;
  const p = wins / total;
  const denom = 1 + (z * z) / total;
  const centre = p + (z * z) / (2 * total);
  const half = z * Math.sqrt((p * (1 - p)) / total + (z * z) / (4 * total * total));
  return [(centre - half) / denom, (centre + half) / denom];
}

const pct = (x: number) => `%${Math.round(x * 100)}`;
const fmt1 = (x: number) => x.toFixed(1).replace('.', ',');

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  await preloadWordSet();
  console.log(
    `YZ↔YZ koşumu — N ∈ {${args.ns.join(', ')}}, N başına ${args.games} oyun, temel tohum ${args.seed}, ` +
      `doğrulama: ${args.verifyGames === Infinity ? 'her oyun' : `ilk ${args.verifyGames} oyun`}`,
  );
  console.log('Üretim motoru (N=1) reducer AI_PLAY ile; top-N motoru bu betiğin kopyasıyla oynar.\n');

  const rows: string[] = [];
  rows.push('| N | Top-N kazanma | %95 GA | Berabere | Ort. Normal | Ort. Top-N | Top-N ort. hamle puanı | Oyun |');
  rows.push('|---|---|---|---|---|---|---|---|');

  for (const n of args.ns) {
    const t0 = performance.now();
    let wins = 0;
    let draws = 0;
    let sumProd = 0;
    let sumTop = 0;
    let moves = 0;
    let moveScore = 0;
    let winsAsFirst = 0;
    let firstGames = 0;
    for (let g = 0; g < args.games; g++) {
      const seat: 0 | 1 = g % 2 === 0 ? 1 : 0;
      const r = playOne(n, args.seed + g, seat, g < args.verifyGames);
      if (r.topN > r.prod) wins++;
      else if (r.topN === r.prod) draws++;
      if (seat === 0) {
        firstGames++;
        if (r.topN > r.prod) winsAsFirst++;
      }
      sumProd += r.prod;
      sumTop += r.topN;
      moves += r.topNMoves;
      moveScore += r.topNMoveScoreSum;
    }
    const decided = args.games - draws;
    const [lo, hi] = wilson(wins, decided);
    const secs = ((performance.now() - t0) / 1000).toFixed(0);
    console.log(
      `N=${n}: ${wins}/${decided} galibiyet (${pct(wins / decided)}; GA ${pct(lo)}–${pct(hi)}), ` +
        `${draws} berabere · ilk koltukta ${winsAsFirst}/${firstGames}, ikincide ${wins - winsAsFirst}/${args.games - firstGames} · ${secs} sn`,
    );
    rows.push(
      `| ${n}${n === 1 ? ' (bugünkü)' : ''} | ${pct(wins / decided)} | ${pct(lo)}–${pct(hi)} | ${draws} | ` +
        `${Math.round(sumProd / args.games)} | ${Math.round(sumTop / args.games)} | ${fmt1(moveScore / Math.max(1, moves))} | ${args.games} |`,
    );
  }
  console.log('\n' + rows.join('\n'));
  console.log('\nKazanma oranı beraberlikler dışında hesaplandı; GA = Wilson %95 güven aralığı.');
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
