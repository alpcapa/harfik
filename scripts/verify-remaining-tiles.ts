// Kelimeki — "Kalan Taşlar" (TORBA) dökümü doğrulaması.
//
// Neden var: dökümdeki sayı, oyun bitişinde rakibin puanından düşülecek
// tutarın kullanıcıya gösterilen TEK önizlemesi. 18 Ağustos 2026'da bir
// kullanıcı son hamlesinden önce 10 puanlık taş sayıp bitiş kartında -7
// görünce bildirdi: `PLACE_TILE` taşı raftan çıkarıp `state.placed`e koyuyor
// ama `board`a ancak `PLAY` yazıyor, döküm ise yalnızca board+raf'ı
// düşürdüğünden bekleyen taşlar "dışarıda" (rakibin elinde) sayılıyordu.
//
// Bu betik ÜRETİM reducer'ını ve üretim `remainingTiles`ini gerçekten
// koşturur; sahte bir kopya değil. Çalıştırma: `npm run verify-remaining-tiles`.
import { gameReducer, createInitialState } from '../src/game/gameReducer';
import type { GameState, Player, Tile } from '../src/game/types';
import { remainingTiles } from '../src/utils/bag';
import { TILE_DATA } from '../src/data/tiles';

let pass = 0;
const fails: string[] = [];
function check(ok: boolean, msg: string): void {
  if (ok) pass++;
  else fails.push(msg);
}

/** Dökümün gösterdiği toplam adet ve puan — modalın yaptığı hesabın aynısı. */
function outside(state: GameState, myIndex: number): { count: number; pts: number } {
  const rows = remainingTiles(
    state.board,
    state.players[myIndex].rack,
    Object.values(state.placed),
  );
  return {
    count: rows.reduce((s, r) => s + r.count, 0),
    pts: rows.reduce((s, r) => s + r.count * r.pts, 0),
  };
}

/** Bir rafın toplam puanı — `endGame`'in düştüğü tutarın aynısı. */
function rackPts(p: Player): number {
  return p.rack.reduce((s, t) => s + t.pts, 0);
}

const t = (letter: string): Tile => ({ letter, pts: TILE_DATA[letter].pts });

/**
 * Bildirilen senaryonun kurgusu — FİZİKSEL OLARAK TUTARLI bir oyun sonu:
 * 100 taşlık dağılımın tamamı dağıtılır (torba BOŞ), 4'ü insanın rafında
 * (biri joker), 3'ü YZ'nin rafında (7 puan), kalan 93'ü tahtada. Döküm ancak
 * böyle bir state'te anlamlı: "dağılım − tahta − kendi rafım" gerçekten
 * "torba + rakip rafı"na eşit olur.
 *
 * İnsan taşlarını (0,1)…(0,4) hücrelerine tek tek koyar; döküm HER adımda
 * yalnızca YZ'nin rafını göstermeli.
 */
function endgameState(): { state: GameState; boardTiles: number } {
  const myRack: Tile[] = [t('A'), t('R'), { letter: '?', pts: 0 }, t('M')];
  // 3 + 3 + 1 = 7 puan — bitiş kartında görülen düşüm.
  const aiRack: Tile[] = [t('Ç'), t('D'), t('A')];

  // Dağılımın tamamı → raflara verilenleri düş → kalanı tahtaya yay.
  const pool: string[] = [];
  for (const [letter, { cnt }] of Object.entries(TILE_DATA)) {
    for (let i = 0; i < cnt; i++) pool.push(letter);
  }
  for (const tile of [...myRack, ...aiRack]) {
    const k = tile.letter;
    const i = pool.indexOf(k);
    if (i < 0) throw new Error(`dağılımda kalmayan taş: ${k}`);
    pool.splice(i, 1);
  }
  // İnsanın ev karesi kullanılmış olmalı (ilk hamle kuralı) — 'K' oraya.
  const homeIdx = pool.indexOf('K');
  pool.splice(homeIdx, 1);

  const st = JSON.parse(JSON.stringify(createInitialState())) as GameState;
  st.phase = 'play';
  st.bonuses = {};
  st.board[0][0] = { ...t('K'), owner: 0 } as Tile;
  // Kalanları 2. satırdan itibaren yay — 0. ve 1. satır hamleye açık kalsın.
  let n = 1;
  let pi = 0;
  for (let r = 2; r < 13 && pi < pool.length; r++) {
    for (let c = 0; c < 13 && pi < pool.length; c++) {
      const letter = pool[pi++];
      const tile: Tile = { ...t(letter), owner: (r + c) % 2 } as Tile;
      if (letter === '?') {
        // Tahtadaki joker: harfe çevrilmiş görünür ama dağılımda '?' sayılır —
        // döküm bunu KARIŞTIRMAMALI (çevrildiği harfi torbada eksiltmemeli).
        tile.wild = true;
        tile.wildLetter = 'Z';
      }
      st.board[r][c] = tile;
      n++;
    }
  }
  if (pi !== pool.length) throw new Error('tahtaya sığmayan taş kaldı');

  st.bag = [];
  st.players = [
    {
      name: 'Ben', corners: [0], colorIndex: 0, isAI: false, surrendered: false,
      rack: myRack, score: 100, bestMoveScore: 8, bestWordScore: 6,
      longestWord: 'KAR', moveCount: 2, moveScoreSum: 12,
    },
    {
      name: 'Yapay Zeka 2', corners: [3], colorIndex: 1, isAI: true, surrendered: false,
      rack: aiRack, score: 200, bestMoveScore: 9, bestWordScore: 7,
      longestWord: 'JETON', moveCount: 2, moveScoreSum: 14,
    },
  ] as Player[];
  st.current = 0;
  st.turnCount = 8;
  return {
    state: gameReducer(createInitialState(), { type: 'RESUME_SAVED', state: st }),
    boardTiles: n,
  };
}

// ── 1) Bekleyen taş yokken döküm = rakibin rafı (taban çizgisi) ──────────────
const built = endgameState();
let state = built.state;
const aiPts = rackPts(state.players[1]);
const aiCount = state.players[1].rack.length;
check(aiPts === 7, `taban: YZ rafı 7 puan olmalı, ${aiPts} çıktı`);
check(
  built.boardTiles + state.players[0].rack.length + aiCount === 100,
  `taban: tahta(${built.boardTiles}) + raflar ≠ 100 taş`,
);
{
  const o = outside(state, 0);
  check(o.count === aiCount, `hamlesiz döküm adedi ${o.count} ≠ ${aiCount}`);
  check(o.pts === aiPts, `hamlesiz döküm puanı ${o.pts} ≠ ${aiPts}`);
}

// ── 2) Taşlar tahtaya konarken döküm DEĞİŞMEMELİ (asıl regresyon) ───────────
// Joker de dahil: 'A'ya çevrilen bir joker dökümde fazladan bir 'A' üretmemeli.
const moves: { r: number; c: number; wildLetter?: string }[] = [
  { r: 0, c: 1 },
  { r: 0, c: 2 },
  { r: 0, c: 3, wildLetter: 'A' }, // rafın 3. taşı joker
  { r: 0, c: 4 },
];
moves.forEach((m, i) => {
  // rackIndex hep 0: her yerleştirmede raf bir eleman kısalıyor, ama joker
  // (3. taş) 3. adımda başa geldiğinden sıra korunuyor.
  const idx = m.wildLetter ? 0 : 0;
  state = gameReducer(state, {
    type: 'PLACE_TILE', r: m.r, c: m.c, rackIndex: idx, wildLetter: m.wildLetter,
  });
  const o = outside(state, 0);
  check(
    o.count === aiCount && o.pts === aiPts,
    `${i + 1}. taş konduktan sonra döküm ${o.count} taş / ${o.pts} puan — ` +
      `beklenen ${aiCount} taş / ${aiPts} puan (bekleyen taş rakibe sayılıyor)`,
  );
});

// ── 3) Jokerin çevrildiği harf dökümde SIZMAMALI ────────────────────────────
{
  const rows = remainingTiles(
    state.board,
    state.players[0].rack,
    Object.values(state.placed),
  );
  const jokerRow = rows.find((r) => r.letter === '?')!;
  const aRow = rows.find((r) => r.letter === 'A')!;
  // İki joker de tahtada (biri baştan, biri az önce 'A' olarak konuldu) —
  // dışarıda joker KALMAMALI ve çevrildikleri harfler ('A'/'Z') dışarıdaki
  // sayıları etkilememeli. Dışarıdaki tek 'A' YZ'nin rafındaki.
  check(jokerRow.count === 0, `dışarıdaki joker sayısı ${jokerRow.count} ≠ 0`);
  check(aRow.count === 1, `dışarıdaki 'A' sayısı ${aRow.count} ≠ 1 (joker sızdı)`);
}

// ── 4) Bitişte düşülen puan, dökümde gösterilen puanla AYNI olmalı ──────────
{
  const before = outside(state, 0);
  const scoreBefore = state.players[1].score;
  const played = gameReducer(state, { type: 'PLAY', skipWordCheck: true });
  check(played.isGameOver, `oyun bitmeliydi (raf+torba boş), bitmedi`);
  const deducted = scoreBefore - played.players[1].score;
  check(
    deducted === before.pts,
    `bitişte düşülen ${deducted} puan, dökümdeki ${before.pts} puanla eşleşmiyor`,
  );
  check(deducted === aiPts, `bitişte düşülen ${deducted} ≠ ${aiPts}`);
}

// ── sonuç ───────────────────────────────────────────────────────────────────
if (fails.length) {
  console.error(`✗ ${fails.length} kontrol düştü (${pass} geçti):`);
  for (const f of fails) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(`✓ kalan taşlar dökümü: ${pass} kontrol geçti`);
