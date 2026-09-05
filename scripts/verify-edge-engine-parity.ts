// Kelimeki — motorun ÜÇÜNCÜ kopyasının (`supabase/functions/_game/`)
// `src/`'deki aslıyla aynı davranıp davranmadığını ölçer.
//
// NEDEN VAR (5 Eylül 2026, hata avı geçişi #23 — CANLIDA bulundu):
// Bu kod tabanında motorun üç kopyası var — web `src/`, Flutter portu
// `mobile/kelimeki_core/`, ve Edge Function `supabase/functions/_game/`
// (`play-ai-turn` onu kullanıyor, yani CANLI OYUNLARDAKİ YZ bu kodla
// oynuyor). Ama otomatik parite kanıtı yalnızca İLK İKİSİ arasındaydı:
// golden vector'lar web↔port'u kanıtlıyor, üçüncü kopyaya HİÇ bakmıyor.
// Derleyici de bakmıyor — `tsconfig.json` yalnızca `src`'i içeriyor ve
// CI'da Edge işi yok, yani `_game/` HİÇBİR kapıdan geçmiyordu.
//
// Sonuç: iki motor değişikliği bu kopyaya hiç işlenmedi ve aylarca canlıda
// kaldı — YZ'nin köşe açılışı (17 Ağustos) ve bölgenin "iletken hücre"
// kuralı (24 Ağustos). İkincisi PUANA dönüşüyordu: YZ bölge vergisini
// eksik ödüyor, o skor `submit_move` ile veritabanına ve k-lig puanına
// yazılıyordu.
//
// ⚠ ARIZA SESSİZ: `play-ai-turn`in `catch`i son çare olarak "pas geç"e
// düşüyor, yani bozuk bir motor hata vermez — YZ sadece sürekli pas geçer.
// Bu yüzden kanıt DEPLOY'DAN ÖNCE burada üretilmeli.
//
// Metin karşılaştırması bilerek YAPILMIYOR: `_game/` kopyası KISMİ
// (validatePlacement* orada yok, yorumlar kırpılmış, importlar farklı),
// yani düz bir diff gürültüden ibaret olurdu. Ölçülen şey DAVRANIŞ.
//
// Koşum: npm run verify-edge-engine-parity
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  computeAllTerritories as webTerritories,
  computeInvasionSplit as webInvasion,
  calcScore as webScore,
} from '../src/utils/validator';
import { findAIMove as webAI } from '../src/utils/ai';
import { createEmptyBoard } from '../src/utils/board';
import { buildInitialBonuses, cornersFor } from '../src/game/constants';
import { letterPoints } from '../src/data/tiles';
import { preloadWordSet, getWordSet } from '../src/data/wordSetLoader';
import { gameReducer, createInitialState, type Action } from '../src/game/gameReducer';
import { setRandomSource } from '../src/utils/random';
import type { GameState, Player, Tile } from '../src/game/types';

import {
  computeAllTerritories as edgeTerritories,
  computeInvasionSplit as edgeInvasion,
  calcScore as edgeScore,
} from '../supabase/functions/_game/validator.ts';
import { findAIMove as edgeAI } from '../supabase/functions/_game/ai.ts';
import { loadWordSet } from '../supabase/functions/_game/wordSet.ts';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const GOLDENS = join(process.cwd(), 'mobile/kelimeki_core/test/goldens');
const golden = (n: string) => JSON.parse(readFileSync(join(GOLDENS, `${n}.json`), 'utf8'));

async function main(): Promise<void> {
  await preloadWordSet();

  // Edge kopyası sözlüğü `public.words` tablosundan çeker. Buraya AYNI
  // sözlüğü sahte bir istemciyle veriyoruz — böylece iki motor aynı kelime
  // havuzuyla karşılaştırılır ve fark yalnızca ALGORİTMADAN gelir.
  const kelimeler = [...getWordSet()];
  const sahteIstemci = {
    from: () => ({
      select: (_c: string, opts?: { head?: boolean }) =>
        opts?.head
          ? { count: kelimeler.length, error: null }
          : {
              range: (a: number, b: number) => ({
                data: kelimeler.slice(a, b + 1).map((word) => ({ word })),
                error: null,
              }),
            },
    }),
  };
  await loadWordSet(sahteIstemci as never);

  console.log('\nEdge Function motor kopyası ↔ src/ paritesi\n');

  // ── 1. Bölge hesabı — golden fixture'ın TAMAMI ─────────────────────────────
  {
    const cases = golden('territory').cases as {
      name: string;
      cells: { r: number; c: number; owner: number }[];
      players: { corners: number[]; surrendered: boolean }[];
    }[];
    let ayrisan = 0;
    for (const c of cases) {
      const board = createEmptyBoard();
      for (const cell of c.cells) {
        board[cell.r][cell.c] = { letter: 'A', pts: 1, owner: cell.owner };
      }
      const players = c.players as unknown as Player[];
      const w = webTerritories(board, players).map((s) => [...s].sort());
      const e = edgeTerritories(board, players).map((s) => [...s].sort());
      if (JSON.stringify(w) !== JSON.stringify(e)) {
        ayrisan++;
        check(
          `bölge: ${c.name}`,
          false,
          `web [${w.map((t) => t.length)}] ↔ edge [${e.map((t) => t.length)}]`,
        );
      }
    }
    check(`bölge hesabı: ${cases.length} vakanın tamamı aynı`, ayrisan === 0);
  }

  // ── 2. Puanlama — golden fixture'ın TAMAMI ─────────────────────────────────
  {
    const cases = golden('scoring').cases as {
      board: unknown[];
      placed: Record<string, Tile>;
      total: number;
    }[];
    let ayrisan = 0;
    for (const c of cases) {
      const board = createEmptyBoard();
      for (const [k, t] of Object.entries((c.board ?? []) as Record<string, Tile>)) {
        const [r, cc] = k.split(',').map(Number);
        board[r][cc] = t;
      }
      const bonuses = buildInitialBonuses();
      if (webScore(board, c.placed, bonuses) !== edgeScore(board, c.placed, bonuses)) ayrisan++;
    }
    check(`puanlama: ${cases.length} vakanın tamamı aynı`, ayrisan === 0);
  }

  // ── 3. Bölge vergisi formülü — bölge farkı PUANA dönüşür mü ────────────────
  // `computeInvasionSplit`in kendisi iki kopyada aynı olsa bile
  // `computeAllTerritories`i çağırdığından sonuç ayrışabilir; 24 Ağustos
  // kuralı kaçırıldığında tam olarak bu oldu (30 ham puanda 20/10 ↔ 30/0).
  {
    const cases = golden('territory').cases as {
      cells: { r: number; c: number; owner: number }[];
      players: { corners: number[]; surrendered: boolean }[];
    }[];
    let ayrisan = 0;
    let toplam = 0;
    for (const c of cases) {
      const board = createEmptyBoard();
      for (const cell of c.cells) {
        board[cell.r][cell.c] = { letter: 'A', pts: 1, owner: cell.owner };
      }
      const players = c.players as unknown as Player[];
      for (let r = 0; r < 13; r++) {
        for (let cc = 0; cc < 13; cc++) {
          for (const base of [7, 30]) {
            toplam++;
            const w = webInvasion([[r, cc]], 0, players, base, board);
            const e = edgeInvasion([[r, cc]], 0, players, base, board);
            if (JSON.stringify(w) !== JSON.stringify(e)) ayrisan++;
          }
        }
      }
    }
    check(`bölge vergisi: ${toplam} hücre×puan kombinasyonunun tamamı aynı`, ayrisan === 0);
  }

  // ── 4. YZ'nin İLK hamlesi — dört köşenin dördü de ──────────────────────────
  // 17 Ağustos düzeltmesi tam buradaydı: eski `tryCornerStart` sağ-alt köşeyi
  // yapısal olarak cezalandırıyordu (7 taş/35 puan yerine 4 taş/6 puan) ve
  // 2 kişilik oyunda YZ HER ZAMAN o köşede.
  {
    const raf: Tile[] = 'A B A R T M A'
      .split(' ')
      .map((l) => ({ letter: l, pts: letterPoints(l) }));
    for (const count of [2, 4] as const) {
      const corners = cornersFor(count);
      const players: Player[] = corners.map((c, i) => ({
        name: `P${i}`, corners: c, colorIndex: i, isAI: true, surrendered: false,
        rack: raf, score: 0, bestMoveScore: 0, bestWordScore: 0, longestWord: '',
        moveCount: 0, moveScoreSum: 0,
      }));
      for (let i = 0; i < count; i++) {
        const board = createEmptyBoard();
        const bonuses = buildInitialBonuses();
        const w = webAI(board, raf, bonuses, i, corners[i], true, players);
        const e = edgeAI(board, raf, bonuses, i, corners[i], true, players);
        check(
          `YZ ilk hamle (${count} kişilik, köşe ${corners[i][0]})`,
          w?.word === e?.word && JSON.stringify(w?.placements) === JSON.stringify(e?.placements),
          `web ${w ? `${w.placements.length} taş "${w.word}" ${w.score}p` : 'yok'} ↔ ` +
            `edge ${e ? `${e.placements.length} taş "${e.word}" ${e.score}p` : 'yok'}`,
        );
      }
    }
  }

  // ── 5. YZ'nin oyun ORTASI hamleleri — gerçek tahtalar üzerinde ─────────────
  // İlk hamle dalı tek başına yetmez: çapalı arama, bölge değerlendirmesi ve
  // "güvenli ↔ vergili" karşılaştırması ancak dolu bir tahtada çalışır.
  {
    let seed = 20260905;
    setRandomSource(() => {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    });
    let s: GameState = gameReducer(createInitialState(), {
      type: 'START',
      players: [{ name: 'A', isAI: true }, { name: 'B', isAI: true }],
    } as Action);
    let ayrisan = 0;
    let sorulan = 0;
    for (let adim = 0; adim < 40 && !s.isGameOver; adim++) {
      const me = s.players[s.current];
      const firstMove = !s.board.some((row) => row.some((t) => t && t.owner === s.current));
      const w = webAI(s.board, me.rack, s.bonuses, s.current, me.corners, firstMove, s.players);
      const e = edgeAI(s.board, me.rack, s.bonuses, s.current, me.corners, firstMove, s.players);
      sorulan++;
      if (w?.word !== e?.word || JSON.stringify(w?.placements) !== JSON.stringify(e?.placements)) {
        ayrisan++;
        if (ayrisan === 1) {
          check(
            `YZ oyun ortası hamlesi (adım ${adim})`,
            false,
            `web ${w ? `"${w.word}" ${w.score}p` : 'yok'} ↔ edge ${e ? `"${e.word}" ${e.score}p` : 'yok'}`,
          );
        }
      }
      s = gameReducer(s, { type: 'AI_PLAY' });
    }
    check(`YZ hamlesi: ${sorulan} gerçek tahta pozisyonunun tamamı aynı`, ayrisan === 0);
    setRandomSource();
  }

  console.log('');
  if (failures > 0) {
    console.log(`${failures} kontrol BAŞARISIZ`);
    console.log(
      '\n⚠ `supabase/functions/_game/` `src/`den AYRIŞMIŞ. Bu dosyalar ELLE\n' +
        '  kopyalanıyor ve `play-ai-turn` onları kullanıyor — yani fark CANLI\n' +
        '  oyunlardaki YZ demek. Ayrışan fonksiyonu `src/`den taşı, sonra\n' +
        '  `play-ai-turn`ü yeniden deploy et (⚠ deploy öncesi\n' +
        '  `list_edge_functions` ile `verify_jwt`i OKU ve AYNI değeri geç).',
    );
    process.exit(1);
  }
  console.log('Üç motor kopyasından üçüncüsü de aynı davranıyor.');
}

void main();
