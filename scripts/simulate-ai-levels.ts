// Kelimeki — YZ seviye kadranı için YZ↔YZ ölçüm aleti (ROADMAP #23, Faz 0;
// Faz 2'de motora bağlandı).
//
// NE ÖLÇER: bugünkü Normal motor (N=1, "en yüksek puanlı hamle") ile "en iyi
// N hamleden RASTGELE biri" oynayan zayıflatılmış motoru birbirine karşı
// koşturur; N başına kazanma oranı, ortalama skor ve ortalama hamle puanı
// çıkarır. Tablonun kolonları backlog'daki 5 Eylül 2026 ölçümüyle
// (docs/decisions/product-backlog.md → "YZ zorluk seviyesi") BİREBİR aynı ki
// eski ölçümle yan yana okunabilsin.
//
// ⚠ Bu YZ↔YZ oranıdır, insan oranı DEĞİL. N=1 satırı iki aynı motorun
// birbirine oynaması, yani yapısı gereği ~%50 — yalnızca sıfır çizgisi.
// Kolay/Zor hedefleri (YZ insana karşı ~%30 / ~%70) SAHADA
// `admin_ai_balance` ile ölçülür; burası ön eleme.
//
// MOTOR: Faz 2'ye kadar alet `findAIMove`'un arama döngüsünün bir KOPYASINI
// taşıyor ve CI her PR'da kopyayı üretimle karşılaştırıyordu. Faz 2 (6 Eylül
// 2026) o tasarımı motora aldı — top-N tarafı artık ÜRETİMİN kendi
// `findAIMoves` (sıralı en-iyi-N listesi) + `pickTopMove` (rastgelelik
// sözleşmesi) çiftiyle oynuyor; kopya ve CI adımı silindi. Kolay seviyesi
// (`AI_LEVEL_TOP_N.kolay`) bu aletin N=4 satırının ta kendisidir; Faz 5'in
// Zor motoru da aynı aletle ölçülecek.
//
// KOLTUK DEĞİŞİMİ: çift numaralı oyunlarda top-N motoru 2. koltukta
// (köşe 3), tek numaralılarda 1. koltukta (köşe 0) — ilk hamle avantajı
// ve köşe farkı ortalamaya dağılır. Üretim (N=1) tarafı reducer'ın kendi
// `AI_PLAY` action'ıyla oynar; top-N tarafı `PLACE_TILE`+`PLAY` (hamle
// yoksa YZ ile aynı: torba doluysa tüm rafı değiştir, boşsa pas) ile sürülür.
//
// RASTGELELİK: oyun başına tohum = temel tohum + oyun sırası; tohumlu
// mulberry32 `setRandomSource` ile takılır, hem torba hem `pickTopMove` aynı
// akıştan tüketir. N=1'de rastgele ÇAĞRI YAPILMAZ (pickTopMove sözleşmesi).
// Aynı tohum + aynı N → aynı oyun.
//
// Koşum (repo kökünden):
//   npm run simulate-ai-levels                       # N ∈ {1,2,3,5}, 100 oyun, tohum 1
//   npm run simulate-ai-levels -- --oyun 200 --n 2,3,4 --tohum 42
import { performance } from 'node:perf_hooks';
import type { GameState } from '../src/game/types';
import { gameReducer, createInitialState, isFirstMove, type Action } from '../src/game/gameReducer';
import { preloadWordSet } from '../src/data/wordSetLoader';
import { findAIMoves, pickTopMove } from '../src/utils/ai';
import { setRandomSource } from '../src/utils/random';

// ── Argümanlar ───────────────────────────────────────────────────────────────
interface Args {
  games: number;
  ns: number[];
  seed: number;
}

function parseArgs(argv: string[]): Args {
  const a: Args = { games: 100, ns: [1, 2, 3, 5], seed: 1 };
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

// ── Oyun sürücüsü ────────────────────────────────────────────────────────────
interface GameResult {
  /** top-N motorunun skoru ve üretimin skoru. */
  topN: number;
  prod: number;
  topNMoves: number;
  topNMoveScoreSum: number;
  topNSeat: 0 | 1;
}

function playOne(n: number, seed: number, topNSeat: 0 | 1): GameResult {
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
    // Üretimin kendi liste + seçim çifti (Kolay = N=4 ile birebir aynı yol).
    const move = pickTopMove(
      findAIMoves(state.board, me.rack, state.bonuses, state.current, me.corners, first, state.players, n),
    );
    if (!move) {
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
    `YZ↔YZ koşumu — N ∈ {${args.ns.join(', ')}}, N başına ${args.games} oyun, temel tohum ${args.seed}`,
  );
  console.log('Üretim motoru (N=1) reducer AI_PLAY ile; top-N motoru üretimin findAIMoves + pickTopMove çiftiyle oynar.\n');

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
      const r = playOne(n, args.seed + g, seat);
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
