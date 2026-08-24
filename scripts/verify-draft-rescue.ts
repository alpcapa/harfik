// Kelimeki — `src/utils/draftRescue.ts`'in saf karar fonksiyonunu
// (`nearbyDraftCell`) ÜRETİM kodunu import ederek doğrular.
//
// NEDEN AYRI BİR BETİK: web tarafında birim test çatısı yok (`npm run test`
// Playwright duman testleri). `verify-cloud-save-mirror` ile AYNI desen.
//
// NEDEN ÖNEMLİ: bu fonksiyon kullanıcının dokunuşunu BAŞKA bir hücreye
// yönlendiriyor. Yanlış taşı geri almak, hiç tepki vermemekten daha kötü —
// o yüzden "belirsizlikte tahmin etme" kuralı burada tek tek sınanıyor.
// Flutter portundaki eşi `_nearbyDraftCell` ve aynı vakalar orada widget
// testleriyle koşuyor (`game_screen_test.dart`).
//
// Koşum: npm run verify-draft-rescue
import { nearbyDraftCell, type CellRect } from '../src/utils/draftRescue';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const SIZE = 13;
const CELL = 24;
const GAP = 3;
// Hücre (r,c) ekranda: sol/üst = c/r * (24+3), boyut 24.
const rectOf = (r: number, c: number): CellRect => ({
  left: c * (CELL + GAP),
  top: r * (CELL + GAP),
  width: CELL,
  height: CELL,
});
const center = (r: number, c: number) => ({
  x: rectOf(r, c).left + CELL / 2,
  y: rectOf(r, c).top + CELL / 2,
});
const draft = (...cells: [number, number][]) => (r: number, c: number) =>
  cells.some(([rr, cc]) => rr === r && cc === c);

console.log('\nIskalama kurtarma — nearbyDraftCell\n');

// 1 — komşuda taslak yoksa hiçbir şey.
check(
  'komşuda taslak yok → null',
  nearbyDraftCell(SIZE, 5, 5, draft(), center(5, 5), rectOf) === null,
);

// 2 — TEK komşu taslak: dokunuş noktası önemsiz, o seçilir.
check(
  'tek komşu (üst) → o seçilir',
  JSON.stringify(
    nearbyDraftCell(SIZE, 5, 5, draft([4, 5]), center(5, 5), rectOf),
  ) === '[4,5]',
);
check(
  'tek komşu (sol) → o seçilir',
  JSON.stringify(
    nearbyDraftCell(SIZE, 5, 5, draft([5, 4]), center(5, 5), rectOf),
  ) === '[5,4]',
);

// 3 — İKİ komşu, dokunuş TAM ORTADA: eşit uzaklık → TAHMİN YOK.
check(
  'iki komşu + tam orta dokunuş → null (tahmin yok)',
  nearbyDraftCell(SIZE, 5, 5, draft([4, 5], [6, 5]), center(5, 5), rectOf) ===
    null,
);

// 4 — İKİ komşu, dokunuş YUKARI kaymış: üstteki seçilir.
check(
  'iki komşu + yukarı kaymış dokunuş → üstteki',
  JSON.stringify(
    nearbyDraftCell(
      SIZE,
      5,
      5,
      draft([4, 5], [6, 5]),
      { x: center(5, 5).x, y: center(5, 5).y - 6 },
      rectOf,
    ),
  ) === '[4,5]',
);

// 5 — ...ve aşağı kaymışsa alttaki. (Kullanıcının bildirdiği asıl yön:
// parmağın temas merkezi aşağıda kaldığından hedefin ÜSTÜNE nişan alınır.)
check(
  'iki komşu + aşağı kaymış dokunuş → alttaki',
  JSON.stringify(
    nearbyDraftCell(
      SIZE,
      5,
      5,
      draft([4, 5], [6, 5]),
      { x: center(5, 5).x, y: center(5, 5).y + 6 },
      rectOf,
    ),
  ) === '[6,5]',
);

// 6 — dokunuş noktası YOKSA (ölçüm alınamadı) belirsizlikte tahmin edilmez.
check(
  'iki komşu + nokta yok → null',
  nearbyDraftCell(SIZE, 5, 5, draft([4, 5], [6, 5]), null, rectOf) === null,
);

// 7 — ...ama tek komşu varken nokta gerekmez.
check(
  'tek komşu + nokta yok → yine seçilir',
  JSON.stringify(
    nearbyDraftCell(SIZE, 5, 5, draft([4, 5]), null, rectOf),
  ) === '[4,5]',
);

// 8 — ölçüm alınamıyorsa (rect null) belirsizlikte tahmin edilmez.
check(
  'iki komşu + rect ölçülemiyor → null',
  nearbyDraftCell(SIZE, 5, 5, draft([4, 5], [6, 5]), center(5, 5), () => null) ===
    null,
);

// 9 — tahta kenarı: dışarı taşan komşular aday olmaz.
check(
  'sol üst köşe: yalnızca içerideki komşular sayılır',
  JSON.stringify(nearbyDraftCell(SIZE, 0, 0, draft([0, 1]), null, rectOf)) ===
    '[0,1]',
);

// 10 — ÇAPRAZ komşu aday DEĞİL (yalnızca ortogonal).
check(
  'çapraz komşudaki taslak aday değil',
  nearbyDraftCell(SIZE, 5, 5, draft([4, 4]), center(5, 5), rectOf) === null,
);

console.log('');
if (failures > 0) {
  console.log(`${failures} kontrol BAŞARISIZ`);
  process.exit(1);
}
console.log('Tüm kontroller geçti.');
