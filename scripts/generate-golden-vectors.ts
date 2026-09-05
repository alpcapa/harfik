// Kelimeki — Flutter portu için golden vector üreticisi.
//
// Web'in ÜRETİM motorunu (src/game + src/utils) tohumlu bir PRNG'yle
// (mulberry32, setRandomSource üzerinden) koşturup, her senaryonun action
// dizisini + beklenen state anlık görüntülerini JSON fixture'ları olarak
// mobile/kelimeki_core/test/goldens/ altına yazar. Dart motoru
// (mobile/kelimeki_core) aynı action'ları aynı tohumla yeniden oynatıp
// state'leri derin karşılaştırır — iki implementasyonun ayrışmasını bu
// dosyalar yakalar. Ayrıntı: mobile/CLAUDE.md, "Golden vector" bölümü.
//
// Çalıştırma (repo kökünden):
//   node_modules/.bin/esbuild scripts/generate-golden-vectors.ts \
//     --bundle --platform=node --format=esm --outfile=<tmp>/gen.mjs
//   node <tmp>/gen.mjs
// (npm script'i: `npm run generate-golden-vectors`)
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  gameReducer,
  createInitialState,
  isFirstMove,
  type Action,
} from '../src/game/gameReducer';
import type { GameState, HistoryEntry, Player, Tile } from '../src/game/types';
import { setRandomSource } from '../src/utils/random';
import { findAIMove } from '../src/utils/ai';
import { calcScore, calcWordRawScores, computeAllTerritories } from '../src/utils/validator';
import { rankPlayers } from '../src/utils/ranking';
import { leaguePoints, computeRanks } from '../src/utils/leaguePoints';
import { trLower, trUpper, trCompare } from '../src/utils/turkish';
import { preloadWordSet } from '../src/data/wordSetLoader';
import { WORD_LIST } from '../src/data/words';
import { TILE_DATA, letterPoints } from '../src/data/tiles';
import { remainingTiles } from '../src/utils/bag';
import { key, type Board, type Placed } from '../src/utils/board';

const ROOT = process.cwd();
const GOLDENS = join(ROOT, 'mobile/kelimeki_core/test/goldens');
// Sözlük asset'i Flutter uygulama paketinin İÇİNDE yaşar (Flutter, paket kökü
// dışındaki asset'lere izin vermez) — tek kopya, kelimeki_core testleri de
// buradan okur.
const ASSETS = join(ROOT, 'mobile/app/assets/dictionary');

// ── PRNG: Dart tarafındaki Mulberry32 ile bit-eş ─────────────────────────────
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

// ── Kanonik serileştirme (Dart codec'iyle aynı sözleşme) ─────────────────────
// Opsiyonel alanlar yalnızca doluyken yazılır; startedAt '' olarak normalize
// edilir (TS motoru gerçek saati gömer, Dart motoruna nowIso='' enjekte edilir).
function serTile(t: Tile): Record<string, unknown> {
  const o: Record<string, unknown> = { letter: t.letter, pts: t.pts };
  if (t.wild) o.wild = true;
  if (t.wildLetter !== undefined) o.wildLetter = t.wildLetter;
  if (t.owner !== undefined) o.owner = t.owner;
  return o;
}

function serPlayer(p: Player): Record<string, unknown> {
  return {
    name: p.name,
    corners: p.corners,
    colorIndex: p.colorIndex,
    isAI: p.isAI,
    surrendered: p.surrendered,
    rack: p.rack.map(serTile),
    score: p.score,
    bestMoveScore: p.bestMoveScore,
    bestWordScore: p.bestWordScore,
    longestWord: p.longestWord,
    moveCount: p.moveCount,
    moveScoreSum: p.moveScoreSum,
  };
}

function serHistory(h: HistoryEntry): Record<string, unknown> {
  const o: Record<string, unknown> = {
    turn: h.turn,
    player: h.player,
    words: h.words,
    points: h.points,
  };
  if (h.wordScores !== undefined) o.wordScores = h.wordScores;
  if (h.invasionFrom !== undefined) o.invasionFrom = h.invasionFrom;
  if (h.lostShares !== undefined) o.lostShares = h.lostShares;
  if (h.action !== undefined) o.action = h.action;
  if (h.tileCount !== undefined) o.tileCount = h.tileCount;
  if (h.finishJokerCount !== undefined) o.finishJokerCount = h.finishJokerCount;
  if (h.bingo) o.bingo = true;
  return o;
}

function serState(s: GameState): Record<string, unknown> {
  return {
    phase: s.phase,
    startedAt: '',
    multiSession: s.multiSession,
    endReason: s.endReason,
    board: s.board.map((row) => row.map((c) => (c ? serTile(c) : null))),
    bag: s.bag.map(serTile),
    bonuses: s.bonuses,
    placed: Object.fromEntries(
      Object.entries(s.placed).map(([k, t]) => [k, serTile(t)]),
    ),
    players: s.players.map(serPlayer),
    current: s.current,
    selectedTile: s.selectedTile,
    swapMode: s.swapMode,
    swapSelection: s.swapSelection,
    turnCount: s.turnCount,
    consecutivePasses: s.consecutivePasses,
    isGameOver: s.isGameOver,
    message: s.message,
    messageType: s.messageType,
    lastMoveCells: s.lastMoveCells,
    moveHistory: s.moveHistory.map(serHistory),
  };
}

function serAction(a: Action): Record<string, unknown> {
  if (a.type === 'SYNC_ONLINE_STATE') {
    return {
      type: a.type,
      publicState: a.publicState as unknown as Record<string, unknown>,
      myRack: a.myRack.map(serTile),
      mySlotIndex: a.mySlotIndex,
    };
  }
  if (a.type === 'RESUME_SAVED') {
    return { type: a.type, state: serState(a.state) };
  }
  return { ...a } as Record<string, unknown>;
}

// ── Senaryo koşucusu ─────────────────────────────────────────────────────────
interface Step {
  action: Record<string, unknown>;
  state?: Record<string, unknown>;
}

class Runner {
  state: GameState = createInitialState();
  steps: Step[] = [];
  constructor(
    public seed: number,
    public snapshotEvery: number,
  ) {
    setRandomSource(mulberry32(seed));
  }
  dispatch(a: Action): void {
    this.state = gameReducer(this.state, a);
    const snap = this.snapshotEvery === 1 || this.steps.length % this.snapshotEvery === 0;
    this.steps.push(
      snap
        ? { action: serAction(a), state: serState(this.state) }
        : { action: serAction(a) },
    );
  }
  finish(name: string): void {
    // Son adım her zaman tam snapshot taşımalı.
    if (this.steps.length > 0) {
      this.steps[this.steps.length - 1].state = serState(this.state);
    }
    writeFileSync(
      join(GOLDENS, `${name}.json`),
      JSON.stringify({ name, seed: this.seed, steps: this.steps }),
    );
    console.log(`${name}: ${this.steps.length} adım`);
  }
}

/** Sırası gelen oyuncu için en iyi hamleyi (YZ arayışıyla) oynar; yoksa pas. */
function playBestMove(run: Runner): void {
  const s = run.state;
  const me = s.players[s.current];
  const move = findAIMove(
    s.board, me.rack, s.bonuses, s.current, me.corners, isFirstMove(s), s.players,
  );
  if (!move) {
    run.dispatch({ type: 'PASS' });
    return;
  }
  for (const p of move.placements) {
    const rack = run.state.players[run.state.current].rack;
    const idx = p.tile.wild
      ? rack.findIndex((t) => t.letter === '?')
      : rack.findIndex((t) => t.letter === p.tile.letter);
    const act: Action = p.tile.wild
      ? { type: 'PLACE_TILE', r: p.r, c: p.c, rackIndex: idx, wildLetter: p.tile.wildLetter }
      : { type: 'PLACE_TILE', r: p.r, c: p.c, rackIndex: idx };
    run.dispatch(act);
  }
  run.dispatch({ type: 'PLAY' });
}

function findEmptyCell(s: GameState): [number, number] {
  for (let r = 0; r < 13; r++) {
    for (let c = 0; c < 13; c++) {
      if (!s.board[r][c] && !s.placed[key(r, c)]) return [r, c];
    }
  }
  throw new Error('boş hücre yok');
}

// ── Senaryolar ───────────────────────────────────────────────────────────────
function aiScenario(name: string, seed: number, playerCount: 2 | 4, surrenderAt?: number): void {
  const run = new Runner(seed, 5);
  run.dispatch({
    type: 'START',
    players: Array.from({ length: playerCount }, () => ({ name: '', isAI: true })),
  });
  let moves = 0;
  while (!run.state.isGameOver && moves < 400) {
    if (surrenderAt !== undefined && moves === surrenderAt) {
      run.dispatch({ type: 'SURRENDER', index: 2 });
      if (run.state.isGameOver) break;
    }
    run.dispatch({ type: 'AI_PLAY' });
    moves++;
  }
  run.finish(name);
}

function humanScenario(): void {
  const run = new Runner(7, 1);
  const d = (a: Action) => run.dispatch(a);
  d({ type: 'START', players: [{ name: 'Alice ', isAI: false }, { name: '', isAI: false }] });
  d({ type: 'SELECT_TILE', index: 0 });
  d({ type: 'SELECT_TILE', index: 0 }); // toggle: seçim kalkar
  d({ type: 'SELECT_TILE', index: 1 });
  d({ type: 'PLACE_TILE', r: 0, c: 1 }); // selectedTile üzerinden
  d({ type: 'RECALL_CELL', r: 0, c: 1 });
  // Hizasız → err
  d({ type: 'PLACE_TILE', r: 0, c: 0, rackIndex: 0 });
  d({ type: 'PLACE_TILE', r: 1, c: 1, rackIndex: 0 });
  d({ type: 'PLAY' });
  d({ type: 'RECALL_ALL' });
  // Boşluklu → err
  d({ type: 'PLACE_TILE', r: 0, c: 0, rackIndex: 0 });
  d({ type: 'PLACE_TILE', r: 0, c: 2, rackIndex: 0 });
  d({ type: 'PLAY' });
  d({ type: 'RECALL_ALL' });
  // İlk hamle köşeye değmiyor → err
  d({ type: 'PLACE_TILE', r: 5, c: 5, rackIndex: 0 });
  d({ type: 'PLACE_TILE', r: 5, c: 6, rackIndex: 1 });
  d({ type: 'PLAY' });
  d({ type: 'RECALL_ALL' });
  // Köşede rastgele iki harf → büyük olasılıkla sözlük hatası (deterministik)
  d({ type: 'PLACE_TILE', r: 0, c: 0, rackIndex: 0 });
  d({ type: 'PLACE_TILE', r: 0, c: 1, rackIndex: 0 });
  d({ type: 'PLAY' });
  if (Object.keys(run.state.placed).length > 0) d({ type: 'RECALL_ALL' });
  // Geçerli hamleler (YZ arayışı insan adına oynuyor)
  playBestMove(run); // Alice
  playBestMove(run); // Oyuncu 2
  d({ type: 'SHUFFLE_RACK' });
  d({ type: 'RENAME_PLAYER', index: 0, name: 'Alicia' });
  d({ type: 'SET_MESSAGE', message: 'test mesajı', messageType: 'warn' });
  // Taş değiştirme akışı
  d({ type: 'TOGGLE_SWAP_MODE' });
  d({ type: 'TOGGLE_SWAP_TILE', index: 0 });
  d({ type: 'TOGGLE_SWAP_TILE', index: 1 });
  d({ type: 'TOGGLE_SWAP_TILE', index: 0 }); // seçimden çıkar
  d({ type: 'CONFIRM_SWAP' });
  d({ type: 'PASS' });
  // Joker garantili bölüm: mevcut state'in kanonik kopyası, raf elle jokerli
  const crafted = JSON.parse(JSON.stringify(serState(run.state))) as GameState;
  crafted.players[crafted.current].rack = [
    { letter: '?', pts: 0 },
    { letter: '?', pts: 0 },
    { letter: 'A', pts: 1 },
    { letter: 'K', pts: 1 },
    { letter: 'E', pts: 1 },
    { letter: 'L', pts: 1 },
    { letter: 'İ', pts: 1 },
  ] as Tile[];
  d({ type: 'RESUME_SAVED', state: crafted });
  const [er, ec] = findEmptyCell(run.state);
  d({ type: 'PLACE_TILE', r: er, c: ec, rackIndex: 0, wildLetter: 'ş' });
  d({ type: 'SET_WILD_LETTER', r: er, c: ec, wildLetter: 'k' });
  const [er2, ec2] = findEmptyCell(run.state);
  d({ type: 'MOVE_PLACED_TILE', from: { r: er, c: ec }, to: { r: er2, c: ec2 } });
  d({ type: 'RECALL_CELL', r: er2, c: ec2 });
  // Jokerle sözlüksüz (skipWordCheck) oynama: mevcut bir taşın yanına tek joker
  const s = run.state;
  outer: for (let r = 0; r < 13; r++) {
    for (let c = 0; c < 13; c++) {
      if (!s.board[r][c]) continue;
      const right: [number, number] = [r, c + 1];
      if (right[1] < 13 && !s.board[right[0]][right[1]] && !s.placed[key(right[0], right[1])]) {
        const rack = run.state.players[run.state.current].rack;
        const wi = rack.findIndex((t) => t.letter === '?');
        if (wi >= 0) {
          d({ type: 'PLACE_TILE', r: right[0], c: right[1], rackIndex: wi, wildLetter: 'e' });
          d({ type: 'PLAY', skipWordCheck: true });
        }
        break outer;
      }
    }
  }
  // Teslim → 2 kişilikte oyun anında biter (endReason 'surrender')
  d({ type: 'SURRENDER', index: 1 });
  // Oyun bittikten sonra no-op action'lar
  d({ type: 'PLACE_TILE', r: 12, c: 12, rackIndex: 0 });
  d({ type: 'PLAY' });
  d({ type: 'ABANDON' });
  run.finish('reducer_human2');
}

/** Jokerli bitiş bonusu + X3 + oyun sonu raf düşümü — elle kurgulanmış state. */
function craftedFinishScenario(): void {
  const run = new Runner(11, 1);
  const blank = JSON.parse(JSON.stringify(serState(createInitialState()))) as GameState;
  const st = blank as GameState;
  st.phase = 'play';
  st.bonuses = { '6,6': 'tw' };
  st.board[6][4] = { letter: 'A', pts: 1, owner: 0 } as Tile;
  st.board[0][0] = { letter: 'K', pts: 1, owner: 0 } as Tile; // p0 köşesi kullanılmış
  st.board[12][12] = { letter: 'E', pts: 1, owner: 1 } as Tile;
  st.bag = [];
  st.players = [
    {
      name: 'Jokerci', corners: [0], colorIndex: 0, isAI: false, surrendered: false,
      rack: [{ letter: '?', pts: 0 }, { letter: '?', pts: 0 }] as Tile[],
      score: 10, bestMoveScore: 8, bestWordScore: 6, longestWord: 'KAR', moveCount: 2, moveScoreSum: 12,
    },
    {
      name: 'Rakip', corners: [3], colorIndex: 1, isAI: false, surrendered: false,
      rack: [{ letter: 'J', pts: 10 }, { letter: 'A', pts: 1 }] as Tile[],
      score: 20, bestMoveScore: 9, bestWordScore: 7, longestWord: 'JETON', moveCount: 2, moveScoreSum: 14,
    },
  ] as Player[];
  st.current = 0;
  st.turnCount = 4;
  run.dispatch({ type: 'RESUME_SAVED', state: st });
  run.dispatch({ type: 'PLACE_TILE', r: 6, c: 5, rackIndex: 0, wildLetter: 'B' });
  run.dispatch({ type: 'PLACE_TILE', r: 6, c: 6, rackIndex: 0, wildLetter: 'C' });
  run.dispatch({ type: 'PLAY', skipWordCheck: true });
  run.finish('reducer_crafted_finish');
}

/**
 * Bingo (7 taşın hepsi tek hamlede) — hem İNSAN hem YZ mesaj şablonu.
 *
 * NEDEN AYRI BİR SENARYO: `reducer_ai4` bingo İÇERİYOR ama YZ oyunlarında
 * snapshot her 5 adımda bir alındığından o hamlenin `message` alanı hiçbir
 * snapshot'a düşmüyor — yani bingo mesaj metni golden vector'larla KORUNMUYORDU
 * (17 Ağustos 2026'da bingo notu eklenirken fark edildi: fixture'lar yeniden
 * üretildiğinde sıfır fark çıktı). Metin dört yerde birden yaşadığından
 * (gameReducer insan + YZ dalı, OnlineGameScreen, ve ikisinin Dart portu)
 * korumasız bırakmak sessiz ayrışma davetiydi.
 */
function craftedBingoScenario(): void {
  const run = new Runner(31, 1);
  const st = JSON.parse(JSON.stringify(serState(createInitialState()))) as GameState;
  st.phase = 'play';
  st.bonuses = { '6,6': 'tw' };
  // YZ SOL-ÜST köşede (0), insan SAĞ-ALT köşede (3) — sıra bilinçli:
  // `tryCornerStart` (ai.ts) başlangıç hücresini köşe bloğunun İÇİNDEN seçip
  // kelimeyi sağa/aşağı uzatıyor, yani sağ-alt köşede 7 harflik bir ilk hamle
  // tahtadan taşar ve YZ asla bingo yapamaz. Sol-üstte (0,0)→(0,6) sığıyor.
  st.players = [
    {
      name: 'Yapay Zeka 2', corners: [0], colorIndex: 0, isAI: true, surrendered: false,
      rack: [
        { letter: 'A', pts: 1 }, { letter: 'B', pts: 3 }, { letter: 'L', pts: 1 },
        { letter: 'A', pts: 1 }, { letter: 'L', pts: 1 }, { letter: 'I', pts: 2 },
        { letter: 'K', pts: 1 },
      ] as Tile[],
      score: 0, bestMoveScore: 0, bestWordScore: 0, longestWord: '', moveCount: 0, moveScoreSum: 0,
    },
    {
      name: 'Bingocu', corners: [3], colorIndex: 1, isAI: false, surrendered: false,
      rack: [
        { letter: 'A', pts: 1 }, { letter: 'B', pts: 3 }, { letter: 'A', pts: 1 },
        { letter: 'R', pts: 1 }, { letter: 'T', pts: 1 }, { letter: 'M', pts: 2 },
        { letter: 'A', pts: 1 },
      ] as Tile[],
      score: 0, bestMoveScore: 0, bestWordScore: 0, longestWord: '', moveCount: 0, moveScoreSum: 0,
    },
  ] as Player[];
  st.bag = Array.from({ length: 14 }, () => ({ letter: 'E', pts: 1 })) as Tile[];
  st.current = 0;
  st.turnCount = 0;
  run.dispatch({ type: 'RESUME_SAVED', state: st });
  // YZ: rafı tam bir kelime hecelediğinden en yüksek puanlı hamle 7 taşlıdır.
  run.dispatch({ type: 'AI_PLAY' });
  // İnsan: 7 taşın tamamı, köşe hücresine (12,12) değerek → Bingo.
  for (let c = 6; c <= 12; c++) {
    run.dispatch({ type: 'PLACE_TILE', r: 12, c, rackIndex: 0 });
  }
  run.dispatch({ type: 'PLAY', skipWordCheck: true });
  run.finish('reducer_crafted_bingo');
}

/**
 * YZ'nin "hamle yok → raf değiştir" dalı (torba doluyken) — doğal oyunlarda
 * nadiren tetiklenir, burada garanti edilir: yalnız B'lerden oluşan bir rafla
 * hiçbir kelime hecelenemez (ilk hamle, köşe adayları boş küme).
 */
function craftedAiExchangeScenario(): void {
  const run = new Runner(21, 1);
  const st = JSON.parse(JSON.stringify(serState(createInitialState()))) as GameState;
  st.phase = 'play';
  st.bonuses = { '6,6': 'tw' };
  st.current = 1;
  st.turnCount = 2;
  st.bag = [
    { letter: 'C', pts: 4 }, { letter: 'D', pts: 3 }, { letter: 'E', pts: 1 },
    { letter: 'K', pts: 1 }, { letter: 'A', pts: 1 }, { letter: 'L', pts: 1 },
    { letter: 'İ', pts: 1 }, { letter: 'M', pts: 2 }, { letter: 'R', pts: 1 },
    { letter: 'T', pts: 1 },
  ] as Tile[];
  st.players = [
    {
      name: 'İnsan', corners: [0], colorIndex: 0, isAI: false, surrendered: false,
      rack: [{ letter: 'A', pts: 1 }] as Tile[],
      score: 5, bestMoveScore: 5, bestWordScore: 5, longestWord: 'AT', moveCount: 1, moveScoreSum: 5,
    },
    {
      name: 'Yapay Zeka', corners: [3], colorIndex: 1, isAI: true, surrendered: false,
      rack: Array.from({ length: 7 }, () => ({ letter: 'B', pts: 3 })) as Tile[],
      score: 0, bestMoveScore: 0, bestWordScore: 0, longestWord: '', moveCount: 0, moveScoreSum: 0,
    },
  ] as Player[];
  run.dispatch({ type: 'RESUME_SAVED', state: st });
  run.dispatch({ type: 'AI_PLAY' }); // hamle bulunamaz → torba dolu → değişim
  run.finish('reducer_crafted_ai_exchange');
}

/**
 * Taş değiştirme + tahtada taslak taş — TAŞ KORUNUMU (5 Eylül 2026, hata avı
 * geçişi #24).
 *
 * NEDEN AYRI BİR SENARYO: `CONFIRM_SWAP` eskiden `placed`i rafa geri almadan
 * `{}` yazıyordu, yani swap modunda tahtada duran taslak taşlar oyundan
 * tamamen siliniyordu (rastgele eylem koşumu 100 taşlık torbayı 93'e
 * düşürdü). Bu kombinasyonu bugün DÖRT ekrandaki dört ayrı `if` engelliyor,
 * yani mevcut senaryoların hiçbiri bu dala girmiyordu — düzeltme
 * korumasız kalırdı. Fixture doğrudan reducer'a konuşuyor: UI guard'ları
 * burada yok, dolayısıyla dal gerçekten çalışıyor.
 */
function craftedSwapDraftScenario(): void {
  const run = new Runner(31, 1);
  const d = (a: Action) => run.dispatch(a);
  d({ type: 'START', players: [{ name: 'Taslakçı', isAI: false }, { name: 'Rakip', isAI: false }] });
  // Swap moduna gir, sonra (UI'ın izin vermediği ama reducer'ın kabul ettiği
  // yoldan) tahtaya iki taslak taş koy ve taş değiştir.
  d({ type: 'TOGGLE_SWAP_MODE' });
  d({ type: 'PLACE_TILE', r: 0, c: 0, rackIndex: 0 });
  d({ type: 'PLACE_TILE', r: 0, c: 1, rackIndex: 0 });
  d({ type: 'TOGGLE_SWAP_TILE', index: 0 });
  d({ type: 'TOGGLE_SWAP_TILE', index: 2 });
  d({ type: 'CONFIRM_SWAP' });
  run.finish('reducer_crafted_swap_draft');
}

function syncScenario(): void {
  const run = new Runner(2024, 1);
  const d = (a: Action) => run.dispatch(a);
  d({ type: 'START', players: [{ name: 'Ayşe', isAI: false }, { name: '', isAI: true }] });
  playBestMove(run);
  d({ type: 'AI_PLAY' });
  playBestMove(run);
  d({ type: 'AI_PLAY' });

  const toPublic = (s: GameState, turnCount: number) => ({
    board: s.board.map((row) => row.map((c) => (c ? serTile(c) : null))),
    bonuses: s.bonuses,
    players: s.players.map((p) => ({
      name: p.name,
      corners: p.corners,
      colorIndex: p.colorIndex,
      isAI: p.isAI,
      surrendered: p.surrendered,
      rackCount: p.rack.length,
      score: p.score,
      bestMoveScore: p.bestMoveScore,
      bestWordScore: p.bestWordScore,
      longestWord: p.longestWord,
      moveCount: p.moveCount,
      moveScoreSum: p.moveScoreSum,
    })),
    current: s.current,
    turn_count: turnCount,
    consecutive_passes: s.consecutivePasses,
    is_game_over: s.isGameOver,
    end_reason: s.endReason,
    last_move_cells: s.lastMoveCells,
    bag_count: s.bag.length,
    started_at: '',
  });

  // 1) Aynı turn_count ile sync: taslak korunur (henüz taslak yok)
  const myRack1 = run.state.players[0].rack.map(serTile) as unknown as Tile[];
  d({
    type: 'SYNC_ONLINE_STATE',
    publicState: toPublic(run.state, run.state.turnCount) as never,
    myRack: myRack1,
    mySlotIndex: 0,
  });
  // 2) Taslak taş koy, sonra aynı turn_count ile tekrar sync:
  //    placed korunmalı + myRack'ten düşülmeli (subtractPlacedFromRack)
  const [er, ec] = findEmptyCell(run.state);
  d({ type: 'PLACE_TILE', r: er, c: ec, rackIndex: 0 });
  const myRack2 = JSON.parse(JSON.stringify(myRack1)) as Tile[]; // sunucu hâlâ eski rafı bilir
  d({
    type: 'SYNC_ONLINE_STATE',
    publicState: toPublic(run.state, run.state.turnCount) as never,
    myRack: myRack2,
    mySlotIndex: 0,
  });
  // 2b) "Karıştır → Değiştir → taş seç → arka plan senkronu" (hata avı #25):
  //     turn İLERLEMEZ, yani swapMode bilerek korunur; ama raf sunucudaki
  //     sıraya geri yazıldığından aynı indeks artık BAŞKA bir taşı gösterir →
  //     swapSelection DÜŞMELİ. Fixture olmadan bu davranış korumasız kalırdı
  //     (öteki sync vakalarının hiçbirinde dolu bir swapSelection yok).
  //     ⚠ Bilerek 3. adımdan ÖNCE: orada `current` 1'e geçiyor ve
  //     SHUFFLE_RACK sırası gelen oyuncunun rafına işlediğinden benim
  //     rafımı hiç karıştırmazdı (senaryo sessizce anlamsızlaşırdı).
  d({ type: 'TOGGLE_SWAP_MODE' }); // taslak taşı rafa geri alır
  const sunucuRafi = JSON.parse(
    JSON.stringify(run.state.players[0].rack.map(serTile)),
  ) as Tile[];
  d({ type: 'TOGGLE_SWAP_MODE' }); // moddan çık (karıştırma modda kapalı)
  d({ type: 'SHUFFLE_RACK' });
  d({ type: 'TOGGLE_SWAP_MODE' });
  d({ type: 'TOGGLE_SWAP_TILE', index: 0 });
  d({ type: 'TOGGLE_SWAP_TILE', index: 2 });
  d({
    type: 'SYNC_ONLINE_STATE',
    publicState: toPublic(run.state, run.state.turnCount) as never,
    myRack: sunucuRafi,
    mySlotIndex: 0,
  });
  d({ type: 'TOGGLE_SWAP_MODE' }); // modu kapat, 3. adım temiz başlasın

  // 3) turn_count ilerlemiş sync: taslak temizlenir, raf sunucudan gelir
  const pubAdvanced = toPublic(run.state, run.state.turnCount + 1);
  pubAdvanced.current = 1;
  d({
    type: 'SYNC_ONLINE_STATE',
    publicState: pubAdvanced as never,
    myRack: JSON.parse(JSON.stringify(myRack1)) as Tile[],
    mySlotIndex: 0,
  });
  run.finish('reducer_sync');
}

// ── Birim vektörleri ─────────────────────────────────────────────────────────
function scoringVectors(): void {
  const rnd = mulberry32(555);
  const letters = Object.keys(TILE_DATA).filter((l) => l !== '?');
  const pick = <T,>(arr: T[]): T => arr[Math.floor(rnd() * arr.length)];
  const cases: Record<string, unknown>[] = [];

  const addCase = (boardCells: { r: number; c: number; tile: Tile }[], placed: Placed) => {
    const board: Board = Array.from({ length: 13 }, () => Array(13).fill(null));
    for (const bc of boardCells) board[bc.r][bc.c] = bc.tile;
    const bonuses = { '6,6': 'tw' as const };
    cases.push({
      board: boardCells.map((bc) => ({ r: bc.r, c: bc.c, tile: serTile(bc.tile) })),
      placed: Object.fromEntries(Object.entries(placed).map(([k, t]) => [k, serTile(t)])),
      total: calcScore(board, placed, bonuses),
      words: calcWordRawScores(board, placed, bonuses),
    });
  };

  // El yapımı kenar durumları
  const t = (letter: string, owner = 0): Tile => ({ letter, pts: letterPoints(letter), owner });
  const w = (wl: string, owner = 0): Tile => ({ letter: '?', pts: 0, wild: true, wildLetter: wl, owner });
  addCase([], { '6,5': t('K'), '6,6': t('A'), '6,7': t('R') }); // merkez → X3
  addCase([], { '4,4': t('E'), '4,5': t('V') }); // bölge → X2
  addCase([], { '0,5': t('A'), '0,6': t('T') }); // dışarıda → x1
  addCase([{ r: 5, c: 6, tile: t('A', 1) }], { '6,5': t('K'), '6,6': t('A'), '6,7': t('R') }); // çapraz + X3
  addCase([], {
    '0,5': t('A'), '0,6': t('B'), '0,7': t('C'), '0,8': t('D'),
    '0,9': t('E'), '0,10': t('F'), '0,11': t('G'),
  }); // bingo +25
  addCase([{ r: 6, c: 4, tile: t('A', 1) }], { '6,5': w('B'), '6,6': w('C') }); // jokerler + X3

  // Rastgele türetilmiş durumlar — geçerlilik aranmaz, iki motor aynı sonucu
  // vermek zorunda (fark testi)
  for (let i = 0; i < 60; i++) {
    const occupied = new Set<string>();
    const boardCells: { r: number; c: number; tile: Tile }[] = [];
    const nBoard = Math.floor(rnd() * 12);
    for (let b = 0; b < nBoard; b++) {
      const r = Math.floor(rnd() * 13);
      const c = Math.floor(rnd() * 13);
      if (occupied.has(key(r, c))) continue;
      occupied.add(key(r, c));
      const isWild = rnd() < 0.1;
      const L = pick(letters);
      boardCells.push({
        r, c,
        tile: isWild
          ? { letter: '?', pts: 0, wild: true, wildLetter: L, owner: Math.floor(rnd() * 4) }
          : { letter: L, pts: letterPoints(L), owner: Math.floor(rnd() * 4) },
      });
    }
    const placed: Placed = {};
    const horiz = rnd() < 0.5;
    const len = 1 + Math.floor(rnd() * 5);
    const sr = Math.floor(rnd() * 13);
    const sc = Math.floor(rnd() * 13);
    for (let j = 0; j < len; j++) {
      const r = horiz ? sr : sr + j;
      const c = horiz ? sc + j : sc;
      if (r >= 13 || c >= 13 || occupied.has(key(r, c))) break;
      const L = pick(letters);
      placed[key(r, c)] =
        rnd() < 0.12
          ? { letter: '?', pts: 0, wild: true, wildLetter: L, owner: 0 }
          : { letter: L, pts: letterPoints(L), owner: 0 };
    }
    if (Object.keys(placed).length === 0) continue;
    addCase(boardCells, placed);
  }
  writeFileSync(join(GOLDENS, 'scoring.json'), JSON.stringify({ cases }));
  console.log(`scoring: ${cases.length} durum`);
}

/**
 * Bölge (fetih zinciri) vektörleri. 24 Ağustos 2026'da eklendi: o gün
 * eklenen "kendi bloğundaki DESTEKSİZ rakip taşı zinciri kesmez" kuralı
 * mevcut fixture'ların HİÇBİRİNDE geçmiyordu (golden'lar yeniden üretildi
 * ve sıfır fark çıktı) — yani iki motor bu kuralda sessizce ayrışabilirdi.
 * Vakalar bilerek elle kurgulandı, rastgele değil: kuralın her dalı bir
 * vaka.
 */
function territoryVectors(): void {
  const cases: Record<string, unknown>[] = [];

  const add = (
    name: string,
    cells: { r: number; c: number; owner: number }[],
    playerSpecs: { corners: number[]; surrendered?: boolean }[],
  ) => {
    const board: Board = Array.from({ length: 13 }, () => Array(13).fill(null));
    for (const cell of cells) {
      board[cell.r][cell.c] = { letter: 'A', pts: 1, owner: cell.owner as Tile['owner'] };
    }
    const players = playerSpecs.map((ps, i) => ({
      name: `P${i}`,
      score: 0,
      rack: [],
      isAI: false,
      corners: ps.corners,
      colorIndex: i,
      surrendered: ps.surrendered ?? false,
    })) as unknown as Player[];
    const terr = computeAllTerritories(board, players);
    cases.push({
      name,
      cells,
      players: playerSpecs.map((ps) => ({
        corners: ps.corners,
        surrendered: ps.surrendered ?? false,
      })),
      territories: terr.map((t) => [...t].sort()),
    });
  };

  // 1) BİLDİRİLEN VAKA: rakip, senin 4×4 bloğunun içine DESTEKSİZ taş koydu
  //    (kendi zincirine bağlı değil). Sen onun taşına asarak blok DIŞINA
  //    kelime kurdun. Yeni kural: o hücre iletken, bölgen büyür.
  add('desteksiz_rakip_tasi_iletken', [
    { r: 9, c: 9, owner: 1 },
    { r: 9, c: 10, owner: 0 },
    { r: 9, c: 11, owner: 0 },
    { r: 9, c: 12, owner: 0 },
    { r: 8, c: 12, owner: 1 },
    { r: 7, c: 12, owner: 1 },
  ], [{ corners: [0] }, { corners: [3] }]);

  // 2) AYNI GEOMETRİ, ama rakip bölgesini GERÇEKTEN oraya taşımış: kendi
  //    köşesinden (9,12)'ye kadar kesintisiz kendi taşları var. O zaman
  //    hücre ONUNDUR, zinciri keser ve senin blok dışı taşların bağlanmaz.
  {
    const cells = [
      { r: 9, c: 9, owner: 1 },
      { r: 8, c: 12, owner: 1 },
      { r: 7, c: 12, owner: 1 },
    ];
    for (let r = 4; r <= 9; r++) cells.push({ r, c: 3, owner: 0 });
    for (let c = 4; c <= 12; c++) cells.push({ r: 9, c, owner: 0 });
    add('destekli_rakip_tasi_keser', cells, [{ corners: [0] }, { corners: [3] }]);
  }

  // 3) Taban: blok kenarına bitişik kendi taşın, köşe ucundan taş taş
  //    ilerlemeden zincire katılır (blok içi BOŞ hücreler geçit).
  add('blok_ici_bos_hucre_gecit', [
    { r: 8, c: 9, owner: 1 },
    { r: 8, c: 8, owner: 1 },
  ], [{ corners: [0] }, { corners: [3] }]);

  // 4) Teslim olan oyuncunun bölgesi boş küme; taşları da kimseyi tutmaz.
  add('teslim_olan_bolgesiz', [
    { r: 9, c: 9, owner: 1 },
    { r: 9, c: 10, owner: 0 },
    { r: 8, c: 12, owner: 1 },
  ], [{ corners: [0] }, { corners: [3], surrendered: true }]);

  // 5) 4 oyunculu: dört köşe birden, araya serpiştirilmiş desteksiz taşlar.
  add('dort_oyuncu_karisik', [
    { r: 0, c: 0, owner: 0 },
    { r: 0, c: 12, owner: 1 },
    { r: 12, c: 0, owner: 2 },
    { r: 12, c: 12, owner: 3 },
    { r: 3, c: 3, owner: 1 },
    { r: 4, c: 3, owner: 1 },
    { r: 9, c: 9, owner: 0 },
    { r: 8, c: 9, owner: 0 },
  ], [{ corners: [0] }, { corners: [1] }, { corners: [2] }, { corners: [3] }]);

  writeFileSync(join(GOLDENS, 'territory.json'), JSON.stringify({ cases }));
  console.log(`territory: ${cases.length} durum`);
}

function invasionFormulaVectors(): void {
  const shares: Record<string, number[]> = {};
  for (const n of [1, 2, 3]) {
    shares[String(n)] = [];
    for (let base = 0; base <= 1500; base++) {
      shares[String(n)].push(Math.round((base * (n + 1)) / (6 * n)));
    }
  }
  writeFileSync(join(GOLDENS, 'invasion_formula.json'), JSON.stringify({ maxBase: 1500, shares }));
  console.log('invasion_formula: 3×1501 değer');
}

function rankingVectors(): void {
  const rnd = mulberry32(4242);
  const cases: Record<string, unknown>[] = [];
  for (let i = 0; i < 200; i++) {
    const n = [2, 2, 4, 4, 3, 5, 6][Math.floor(rnd() * 7)];
    const players = Array.from({ length: n }, () => ({
      score: Math.floor(rnd() * 40),
      surrendered: rnd() < 0.3,
    }));
    const ranked = rankPlayers(players as unknown as Player[]).map((r) => ({
      index: r.index,
      rank: r.rank,
    }));
    const ranks = computeRanks(players as never);
    const league = players.map((p, idx) =>
      leaguePoints(ranks[idx], players.length, p.surrendered),
    );
    cases.push({ players, ranked, ranks, league });
  }
  writeFileSync(join(GOLDENS, 'ranking.json'), JSON.stringify({ cases }));
  console.log(`ranking: ${cases.length} durum`);
}

/**
 * "Kalan Taşlar" (TORBA) dökümü — `remainingTiles`.
 *
 * 18 Ağustos 2026'ya kadar bu fonksiyonun HİÇ parite kapsaması yoktu ve tam o
 * gün iki tarafta birden aynı hata bulundu: bu turda tahtaya konmuş ama henüz
 * onaylanmamış taşlar (`state.placed`) hiçbir kovaya düşmediğinden "dışarıda"
 * (rakibin elinde) sayılıyordu. Vektörler bekleyen taşlı ve jokerli durumları
 * bilerek içeriyor.
 */
function remainingTilesVectors(): void {
  const rnd = mulberry32(777);
  const letters = Object.keys(TILE_DATA);
  const mk = (letter: string, wild: boolean): Tile =>
    wild
      ? ({ letter: '?', pts: 0, wild: true, wildLetter: letter } as Tile)
      : ({ letter, pts: TILE_DATA[letter].pts } as Tile);

  const cases: Record<string, unknown>[] = [];
  for (let i = 0; i < 60; i++) {
    // Dağılımdan rastgele bir alt küme çekip tahta / raf / bekleyen diye böl.
    const pool: string[] = [];
    for (const [letter, { cnt }] of Object.entries(TILE_DATA)) {
      for (let k = 0; k < cnt; k++) pool.push(letter);
    }
    for (let k = pool.length - 1; k > 0; k--) {
      const j = Math.floor(rnd() * (k + 1));
      [pool[k], pool[j]] = [pool[j], pool[k]];
    }
    const nBoard = Math.floor(rnd() * 90);
    const nRack = Math.floor(rnd() * 8);
    const nPlaced = Math.floor(rnd() * 5);

    const board: (Tile | null)[][] = Array.from({ length: 13 }, () =>
      Array.from({ length: 13 }, () => null),
    );
    const boardEnc: unknown[] = [];
    for (let k = 0; k < nBoard; k++) {
      const letter = pool[k];
      // Jokerler tahtada her zaman bir harfe çevrilmiş görünür.
      const wild = letter === '?';
      const shown = wild ? letters[1 + Math.floor(rnd() * (letters.length - 1))] : letter;
      const tile = mk(wild ? shown : letter, wild);
      const r = Math.floor(k / 13);
      const c = k % 13;
      board[r][c] = tile;
      boardEnc.push([r, c, wild ? shown : letter, wild]);
    }
    const rack: Tile[] = [];
    const rackEnc: unknown[] = [];
    for (let k = nBoard; k < nBoard + nRack; k++) {
      const letter = pool[k];
      rack.push(mk(letter, false)); // raftaki joker HAM '?' olarak durur
      rackEnc.push([letter, false]);
    }
    const placed: Tile[] = [];
    const placedEnc: unknown[] = [];
    for (let k = nBoard + nRack; k < nBoard + nRack + nPlaced; k++) {
      const letter = pool[k];
      const wild = letter === '?';
      const shown = wild ? letters[1 + Math.floor(rnd() * (letters.length - 1))] : letter;
      placed.push(mk(wild ? shown : letter, wild));
      placedEnc.push([wild ? shown : letter, wild]);
    }

    const rows = remainingTiles(board, rack, placed).map((r) => [r.letter, r.pts, r.count]);
    cases.push({ board: boardEnc, rack: rackEnc, placed: placedEnc, rows });
  }
  writeFileSync(join(GOLDENS, 'remaining_tiles.json'), JSON.stringify({ cases }));
  console.log(`remaining_tiles: ${cases.length} durum`);
}

function turkishVectors(): void {
  const words = [
    'İSTANBUL', 'istanbul', 'DİYARBAKIR', 'IĞDIR', 'ırmak', 'IRMAK', 'içim',
    'DİŞÇİ', 'KELİMEKİ', 'ÇĞÖŞÜİI', 'çğöşüiı', 'Muğla', 'ISPARTA', 'III',
    'iii', 'Iı İi', 'JOKER', 'ağustos', 'ŞÖLEN', 'gül', 'GÜL', 'ödül',
    'yağmur', 'ÜZÜM', 'cık', 'AbCçDdEe', 'kebap arası', 'x-ray', 'a1b2',
  ];
  const pairs: [string, string][] = [
    ['Ayşe', 'Ali'], ['ırmak', 'irmak'], ['İnci', 'Irmak'], ['çilek', 'cilek'],
    ['şeker', 'sel'], ['ömer', 'omuz'], ['ülkü', 'usta'], ['deniz', 'Deniz'],
    ['a', 'A'], ['abc', 'abcd'], ['Zeynep', 'ali'], ['a1', 'a2'],
    ['oyuncu 2', 'oyuncu 10'], ['Aa', 'aA'], ['ğ', 'g'], ['İ', 'i'],
    ['I', 'ı'], ['ismail', 'İsmail'], ['osman', 'ÖMER'], ['ceyda', 'Çağla'],
    ['su', 'ŞU'], ['udo', 'ÜMİT'], ['güneş', 'güneş'], ['', 'a'], ['', ''],
    ['kel', 'kelime'], ['zebra', 'çadır'], ['Öykü', 'öykü'],
  ];
  const sign = (x: number) => (x > 0 ? 1 : x < 0 ? -1 : 0);
  writeFileSync(
    join(GOLDENS, 'turkish.json'),
    JSON.stringify({
      lower: words.map((wd) => [wd, trLower(wd)]),
      upper: words.map((wd) => [wd, trUpper(wd)]),
      compare: pairs.map(([a, b]) => [a, b, sign(trCompare(a, b))]),
    }),
  );
  console.log(`turkish: ${words.length} kelime, ${pairs.length} çift`);
}

function writeDictionaryAsset(): void {
  mkdirSync(ASSETS, { recursive: true });
  writeFileSync(join(ASSETS, 'words_tr.txt'), WORD_LIST.join('\n') + '\n');
  console.log(`words_tr.txt: ${WORD_LIST.length} kelime`);
}

// ── main ─────────────────────────────────────────────────────────────────────
async function main(): Promise<void> {
  await preloadWordSet();
  mkdirSync(GOLDENS, { recursive: true });
  writeDictionaryAsset();
  turkishVectors();
  invasionFormulaVectors();
  territoryVectors();
  rankingVectors();
  scoringVectors();
  remainingTilesVectors();
  aiScenario('reducer_ai2', 12345, 2);
  aiScenario('reducer_ai4', 99, 4, 8); // 8. hamleden önce 2. koltuk teslim olur
  humanScenario();
  craftedFinishScenario();
  craftedBingoScenario();
  craftedAiExchangeScenario();
  craftedSwapDraftScenario();
  syncScenario();
  setRandomSource(); // Math.random'a geri dön
  console.log('tamam');
}

void main();
