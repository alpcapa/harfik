// Kelimeki — reel senaryosu: tanıtım tahtasında OYNANABİLİR bir hamle bulur.
//
// Hamleyi elle seçmiyoruz: ÜRETİM YZ'si (`findAIMove`) çağrılıyor, yani
// bulunan hamlenin sözlükte olduğu, bitişiklik/köşe kurallarına uyduğu ve
// puanının doğru hesaplandığı motorun kendisi tarafından garanti ediliyor.
// Elle "şu kelimeyi şuraya koyayım" demek, videoyu çekerken tahtanın
// kırmızıya dönmesiyle sonuçlanabilirdi.
import { preloadWordSet } from '../../src/data/wordSetLoader';
import { buildSnapshotGameState } from '../../src/utils/boardSnapshot';
import { DEMO_TILES_2 } from '../../src/landing/demoBoard';
import { findAIMove } from '../../src/utils/ai';
import { letterPoints } from '../../src/data/tiles';
import { inBonusZone, SIZE } from '../../src/game/constants';
import type { GameState, Tile } from '../../src/game/types';

function tas(l: string): Tile {
  return { letter: l, pts: letterPoints(l) };
}

function taban(): GameState {
  return buildSnapshotGameState(DEMO_TILES_2, 2, [
    { name: 'Sen', score: 148, is_ai: false, colorIndex: 0 },
    { name: 'Yapay Zeka', score: 132, is_ai: true, colorIndex: 1 },
  ]);
}

const ADAYLAR = [
  'ARKADAŞ', 'KELİMEK', 'OYUNCAK', 'BÖLGELİ', 'TAHTALI', 'STRATEJ',
  'ZAFERLİ', 'KAZANIR', 'HAMLESİ', 'PUANLAR', 'MERKEZİ', 'SINIRDA',
  'VERGİSİ', 'KÖŞEDEN', 'BÜYÜTÜR', 'ELEGEÇİ', 'AKILLIC', 'ÇEVİKÇE',
];

async function main() {
  await preloadWordSet();
  const sonuclar: { raf: string; kelime: string; puan: number; hucreler: string; x3: boolean; x2: number }[] = [];

  for (const raf of ADAYLAR) {
    const st = taban();
    st.players[0].rack = Array.from(raf).map(tas);
    st.current = 0;
    const move = findAIMove(st.board, st.players[0].rack, st.bonuses, 0, st.players[0].corners, false, st.players);
    if (!move) continue;
    const merkez = move.placements.some((p) => p.r === (SIZE - 1) / 2 && p.c === (SIZE - 1) / 2);
    const x2 = move.placements.filter((p) => inBonusZone(p.r, p.c)).length;
    sonuclar.push({
      raf,
      kelime: move.word,
      puan: move.score,
      hucreler: move.placements.map((p) => `${p.r},${p.c}`).join(' '),
      x3: merkez,
      x2,
    });
  }

  sonuclar.sort((a, b) => (Number(b.x3) - Number(a.x3)) || (b.x2 - a.x2) || (b.puan - a.puan));
  for (const s of sonuclar) {
    console.log(
      `${s.raf}  →  ${s.kelime.padEnd(9)} ${String(s.puan).padStart(3)} puan  ` +
        `${s.x3 ? 'X3! ' : '    '}x2hücre=${s.x2}  [${s.hucreler}]`,
    );
  }
}

main();
