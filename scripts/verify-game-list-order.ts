// Kelimeki — `src/utils/gameListOrder.ts`in saf sıralama kuralını ÜRETİM
// kodunu import ederek doğrular. Port ikizi `util/game_list_order.dart`,
// vakaları `game_list_order_test.dart` — AYNI vakalar.
//
// NEDEN AYRI BİR BETİK: web'de birim test çatısı yok (`npm run test`
// Playwright). `verify-draft-rescue` ile aynı desen.
//
// NEDEN ÖNEMLİ: bu kural İKİ ayrı isteğin kesişimi ve biri ötekini
// geçersiz kılmadan yaşamak zorunda —
//   31 Ağustos: "son oynanan her zaman en üstte olacak"
//    3 Eylül  : "sıra sende bekleyenlerde bitmeye en yakın üstte"
// Çözüm asimetrik: sıra BENDE artan, sıra RAKİPTE azalan. Aşağıdaki iki
// yön iddiası bu dengenin negatif eşleri — biri ters çevrilirse düşerler.
//
// Koşum: npm run verify-game-list-order
import { orderActiveGames, orderByExpiry } from '../src/utils/gameListOrder';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) console.log(`  ✓ ${name}`);
  else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

interface G { id: string; mine: boolean; dl: number | null }
const sirala = (gs: G[]) =>
  orderActiveGames(gs, { myTurn: (g) => g.mine, deadlineMs: (g) => g.dl })
    .map((g) => g.id)
    .join(',');

console.log('Aktif oyunlar — grup önceliği');
check(
  'sırası bende olanlar HER ZAMAN üstte',
  sirala([
    { id: 'rakip', mine: false, dl: 900 },
    { id: 'bende', mine: true, dl: 100 },
  ]) === 'bende,rakip',
);

console.log('Aktif oyunlar — grup İÇİ yön (asimetri)');
check(
  'SIRA BENDE: en yakın bitiş üstte (ARTAN)',
  sirala([
    { id: 'gec', mine: true, dl: 900 },
    { id: 'yakin', mine: true, dl: 100 },
    { id: 'orta', mine: true, dl: 500 },
  ]) === 'yakin,orta,gec',
  '3 Eylül isteği',
);
check(
  'SIRA RAKİPTE: son oynanan üstte (AZALAN) — 31 Ağustos kararı KORUNUR',
  sirala([
    { id: 'eski', mine: false, dl: 100 },
    { id: 'yeni', mine: false, dl: 900 },
    { id: 'orta', mine: false, dl: 500 },
  ]) === 'yeni,orta,eski',
  'listenin tamamı artana çevrilirse bu düşer',
);

console.log('Aktif oyunlar — NULL tuzağı');
check(
  'deadline null "sıra bende" grubunda EN SONA düşer',
  sirala([
    { id: 'bilinmiyor', mine: true, dl: null },
    { id: 'yakin', mine: true, dl: 100 },
  ]) === 'yakin,bilinmiyor',
  "null'ı 0 saymak onu EN ÜSTE taşırdı — eski koddaki hazır tuzak",
);
check(
  'deadline null "sıra rakipte" grubunda da EN SONA düşer',
  sirala([
    { id: 'bilinmiyor', mine: false, dl: null },
    { id: 'yeni', mine: false, dl: 900 },
  ]) === 'yeni,bilinmiyor',
);

console.log('Aktif oyunlar — kararlılık');
check(
  'eşit ölçütte giriş sırası korunur',
  sirala([
    { id: 'a', mine: true, dl: 100 },
    { id: 'b', mine: true, dl: 100 },
    { id: 'c', mine: true, dl: 100 },
  ]) === 'a,b,c',
);

console.log('orderByExpiry — davetler ve yerel kayıtlar');
const exp = (xs: (number | null)[]) =>
  orderByExpiry(
    xs.map((v, i) => ({ v, i })),
    (t) => t.v,
  )
    .map((t) => t.i)
    .join(',');
check('bitmeye en yakın üstte (ARTAN)', exp([300, 100, 200]) === '1,2,0');
check('null EN SONA', exp([null, 200, 100]) === '2,1,0');
check('hepsi null → giriş sırası', exp([null, null, null]) === '0,1,2');
check('eşit değerlerde giriş sırası korunur', exp([100, 100]) === '0,1');

console.log(failures === 0 ? '\nTÜMÜ GEÇTİ' : `\n${failures} KONTROL DÜŞTÜ`);
process.exit(failures === 0 ? 0 : 1);
