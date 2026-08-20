// Kelimeki — reel çekimi için sahne: tanıtım tahtası (`demoBoard`) üzerinde,
// insan oyuncunun rafında ARKADAŞ olan bir oyun ortası durumu.
//
// NEDEN BU HAMLE: `scripts/reel/senaryo.ts` üretim YZ'sini (`findAIMove`)
// çağırıp bu rafın en iyi hamlesinin 7. sütunda dikey ARKADAŞ (50 puan, X2
// bölgesinde 4 hücre) olduğunu ölçtü — yani hamlenin sözlükte olduğu ve
// bitişik/geçerli olduğu motorun kendisiyle doğrulandı, elle seçilmedi.
// Kelime aynı zamanda reklamın mesajıyla örtüşüyor ("arkadaşınla oyna").
//
// ⚠ TAHTA FİZİKSEL OLARAK TUTARLI olmalı: 100 taşın tamamı ya tahtada, ya bir
// rafta, ya torbada. Torba elle uydurulmuyor, tam dağılımdan tahtadaki ve
// raflardaki taşlar düşülerek üretiliyor (bkz. CLAUDE.md → "Kalan Taşlar"
// dersi: eksik kova sayan bir kurulum dökümü sessizce yanlış gösterir).
import { buildSnapshotGameState } from '../../src/utils/boardSnapshot';
import { DEMO_TILES_2 } from '../../src/landing/demoBoard';
import { buildBag } from '../../src/utils/bag';
import { letterPoints } from '../../src/data/tiles';
import type { GameState, Tile } from '../../src/game/types';

/** İnsan oyuncunun rafı — sıra, sürükleme adımlarının sırasıdır. */
export const RAF = ['A', 'R', 'K', 'A', 'D', 'A', 'Ş'];

/**
 * ARKADAŞ'ın dikey yerleşimi: (5,7) tahtadaki mevcut A, o yüzden listede yok.
 *
 * ⚠ SIRA GÖRSEL: yukarıdan aşağı dizince ara adımlar (A, AR, ARK…) tahtada
 * "bitişik değil" / "ARKAD geçerli bir kelime değil" uyarısı üretiyor ve
 * reklamda saniyelerce KIRMIZI bir uyarı görünüyordu. Mevcut A'nın ALTINDAN
 * başlayınca ara adımların çoğu gerçek kelime oluyor — AD ✓, ADA ✓, ADAŞ ✓ —
 * yani doğrulama satırı hamlenin büyük bölümünde yeşil kalıyor; yalnızca
 * KADAŞ/RKADAŞ adımları kırmızı ve onlar da anında ARKADAŞ'a kapanıyor.
 */
export const HAMLE: { rafHarfi: string; r: number; c: number }[] = [
  { rafHarfi: 'D', r: 6, c: 7 },
  { rafHarfi: 'A', r: 7, c: 7 },
  { rafHarfi: 'Ş', r: 8, c: 7 },
  { rafHarfi: 'K', r: 4, c: 7 },
  { rafHarfi: 'R', r: 3, c: 7 },
  { rafHarfi: 'A', r: 2, c: 7 },
];

function tas(l: string): Tile {
  return { letter: l, pts: letterPoints(l) };
}

export function sahne(): GameState {
  const st = buildSnapshotGameState(DEMO_TILES_2, 2, [
    { name: 'Sen', score: 148, is_ai: false, colorIndex: 0 },
    { name: 'Yapay Zeka', score: 132, is_ai: true, colorIndex: 1 },
  ]);

  const insanRaf = RAF.map(tas);
  const yzRaf = ['E', 'L', 'M', 'İ', 'T', 'O', 'N'].map(tas);

  // Torba = tam dağılım − tahta − iki raf.
  const kalan = buildBag();
  const dus = (letter: string) => {
    const i = kalan.findIndex((t) => t.letter === letter);
    if (i >= 0) kalan.splice(i, 1);
  };
  for (const row of st.board) for (const cell of row) if (cell) dus(cell.wild ? '?' : cell.letter);
  for (const t of [...insanRaf, ...yzRaf]) dus(t.letter);

  // Tanıtım tahtası görsel amaçlı yazıldığından bazı harflerden gerçek
  // dağılımdakinden fazla kullanıyor (ölçüldü: 4 taş). Bu, reel'de görünen
  // hiçbir şeyi etkilemiyor ama torba sayısını 100'ün üstüne çıkarıyordu —
  // sahne dürüst kalsın diye torba, toplam 100'e denk gelecek şekilde
  // kırpılıyor.
  const hedefTorba = Math.max(0, 100 - 52 - insanRaf.length - yzRaf.length);
  kalan.length = Math.min(kalan.length, hedefTorba);

  st.players[0].rack = insanRaf;
  st.players[1].rack = yzRaf;
  st.bag = kalan;
  // ⚠ `buildSnapshotGameState` BİTMİŞ oyun önizlemeleri için yazıldığından
  // `isGameOver: true` döndürüyor; `loadGameState` bu bayrağı gören kaydı
  // "bitmiş" sayıp null dönüyor ve App ilk effect'te kaydı SİLİYOR (ölçüldü:
  // localStorage 4215 bayt yazılıyor, ~1 sn sonra null).
  st.isGameOver = false;
  st.current = 0;
  st.turnCount = 24;
  st.startedAt = new Date(0).toISOString();
  st.message = 'Sen, sıra sende.';
  st.messageType = '';
  return st;
}
