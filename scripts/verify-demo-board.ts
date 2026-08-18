// Kelimeki — karşılama katmanındaki tanıtım tahtalarının (`src/landing/demoBoard.ts`)
// GERÇEK bir oyun tahtası gibi okunduğunu doğrular.
//
// NEDEN VAR: o tahtalar gerçek `Board.tsx` ile render ediliyor, yani ziyaretçi
// harfleri okuyabiliyor. Yatay/dikey dizilimlerden biri Türkçe bir kelime
// değilse, kelime oyunu bilen bir ziyaretçiye tahta anında sahte görünür — ve
// bu, gözle bakarken KAÇIRILIR (kesişen kelimelerin ürettiği "kaza kelimeleri"
// tam olarak insanın göremediği şey). Bu yüzden ölçerek doğrulanıyor.
//
// NE KONTROL EDİLİYOR (her tahta için ayrı ayrı):
//   1. İki taş aynı hücreye düşmüyor (kesişimlerde harfler UYUŞUYOR).
//   2. ≥2 uzunluktaki HER yatay ve dikey dizilim `src/data/words.ts`te var.
//   3. Her harf gerçekten torbada olan bir harf (`TILE_DATA`).
//   4. Her oyuncunun taşları kendi EV karesinden başlayarak ortogonal olarak
//      bağlı — YALNIZCA `*_BAGIMSIZ` listesinde AÇIKÇA bildirilenler hariç.
//      Kontrol İKİ YÖNLÜ (küme eşitliği): ana zincirden kopan bir taş da,
//      yanlışlıkla zincire yapışıp artık izole OLMAYAN bir "bağımsız" taş da
//      hata verir. Birincisi bölge dış hattını sessizce eksik bırakırdı,
//      ikincisi tanıtımın anlattığı kuralı (izole taş bölge kazandırmaz)
//      yalanlardı.
//   5. Tahtadaki her koltuk gerçekten kullanılıyor (4 kişilik tanıtımda bir
//      köşe boş kalırsa görsel "3 rakip" mesajını taşımaz).
//
// Betik çatısı `verify-cloud-save-mirror` ile aynı (esbuild + node); web'de
// birim test çatısı yok. Koşum: npm run verify-demo-board
import { WORD_LIST } from '../src/data/words';
import { TILE_DATA } from '../src/data/tiles';
import { trLower } from '../src/utils/turkish';
import { SIZE, cornerCell, cornersFor } from '../src/game/constants';
import { DEMO_BOARDS } from '../src/landing/demoBoard';
import type { BoardSnapshotTile } from '../src/lib/database.types';

const SOZLUK = new Set(WORD_LIST.map((w) => trLower(w)));
let hata = 0;

function tahtayiDogrula(
  baslik: string,
  playerCount: number,
  tiles: BoardSnapshotTile[],
  bagimsizHucreler: string[],
): void {
  const bildir = (mesaj: string): void => {
    hata++;
    console.log(`  ✗ ${mesaj}`);
  };

  // ── 1 + 3: ızgarayı kur, çakışma ve harf geçerliliği ────────────────────
  const g: (string | null)[][] = Array.from({ length: SIZE }, () => Array(SIZE).fill(null));
  const sahip: (number | null)[][] = Array.from({ length: SIZE }, () => Array(SIZE).fill(null));
  for (const t of tiles) {
    if (g[t.r][t.c] !== null) bildir(`aynı hücrede iki taş: (${t.r},${t.c})`);
    if (!(t.l in TILE_DATA)) bildir(`torbada olmayan harf "${t.l}" @(${t.r},${t.c})`);
    g[t.r][t.c] = t.l;
    sahip[t.r][t.c] = t.o;
  }

  // ── 2: her dizilim gerçek bir kelime mi ─────────────────────────────────
  const bulunan: string[] = [];
  function dizilimleriTara(
    oku: (i: number) => string | null,
    etiket: (bas: number, son: number) => string,
  ): void {
    let bas = -1;
    for (let i = 0; i <= SIZE; i++) {
      const v = i < SIZE ? oku(i) : null;
      if (v !== null && bas < 0) bas = i;
      if (v === null && bas >= 0) {
        if (i - bas >= 2) {
          let kelime = '';
          for (let k = bas; k < i; k++) kelime += oku(k);
          if (SOZLUK.has(trLower(kelime))) bulunan.push(`${kelime} (${etiket(bas, i - 1)})`);
          else bildir(`sözlükte yok: "${kelime}" — ${etiket(bas, i - 1)}`);
        }
        bas = -1;
      }
    }
  }
  for (let r = 0; r < SIZE; r++) dizilimleriTara((c) => g[r][c], (a, b) => `yatay r${r} c${a}-${b}`);
  for (let c = 0; c < SIZE; c++) dizilimleriTara((r) => g[r][c], (a, b) => `dikey c${c} r${a}-${b}`);

  // ── 4 + 5: her koltuk dolu mu ve ev karesinden bağlı mı ─────────────────
  const KOSELER = cornersFor(playerCount);
  let izoleSayisi = 0;
  for (let koltuk = 0; koltuk < playerCount; koltuk++) {
    const toplam = tiles.filter((t) => t.o === koltuk).length;
    if (toplam === 0) {
      bildir(`${koltuk + 1}. koltuğun hiç taşı yok`);
      continue;
    }
    const ev = cornerCell(KOSELER[koltuk][0]);
    if (sahip[ev[0]][ev[1]] !== koltuk) {
      bildir(`${koltuk + 1}. oyuncunun ev karesi (${ev[0]},${ev[1]}) boş ya da rakibin`);
      continue;
    }
    const gorulen = new Set<string>([`${ev[0]},${ev[1]}`]);
    const yigin: [number, number][] = [[ev[0], ev[1]]];
    while (yigin.length) {
      const [r, c] = yigin.pop()!;
      for (const [dr, dc] of [[1, 0], [-1, 0], [0, 1], [0, -1]] as const) {
        const rr = r + dr;
        const cc = c + dc;
        if (rr < 0 || cc < 0 || rr >= SIZE || cc >= SIZE) continue;
        if (sahip[rr][cc] !== koltuk) continue;
        const key = `${rr},${cc}`;
        if (gorulen.has(key)) continue;
        gorulen.add(key);
        yigin.push([rr, cc]);
      }
    }
    // Zincire bağlanmayanlar, TAM OLARAK bildirilen izole hücreler olmalı.
    const kopuk = tiles
      .filter((t) => t.o === koltuk && !gorulen.has(`${t.r},${t.c}`))
      .map((t) => `${t.r},${t.c}`);
    const beklenen = new Set(
      bagimsizHucreler.filter((k) => {
        const [r, c] = k.split(',').map(Number);
        return sahip[r][c] === koltuk;
      }),
    );
    for (const k of kopuk) {
      if (!beklenen.has(k)) bildir(`${koltuk + 1}. oyuncunun (${k}) taşı zincire bağlı DEĞİL ama izole olarak da bildirilmemiş`);
    }
    for (const k of beklenen) {
      if (!kopuk.includes(k)) bildir(`(${k}) izole bildirildi ama ${koltuk + 1}. oyuncunun zincirine BAĞLI`);
    }
    izoleSayisi += beklenen.size;
  }

  console.log(
    `${baslik} — ${tiles.length} taş, ${bulunan.length} kelime, ${izoleSayisi} izole taş:`,
  );
  for (const k of bulunan) console.log(`  ✓ ${k}`);
}

for (const { playerCount, tiles, bagimsizHucreler } of DEMO_BOARDS) {
  tahtayiDogrula(
    `${playerCount} kişilik tanıtım tahtası`,
    playerCount,
    tiles,
    bagimsizHucreler,
  );
}

if (hata) {
  console.log(`\n${hata} hata.`);
  process.exit(1);
}
console.log('\nHepsi geçti.');
