// Kelimeki — `src/utils/rematchSlots.ts`in saf kadro kuralını ÜRETİM kodunu
// import ederek doğrular. Port ikizi `rematchSlots` (online_games_api.dart),
// vakaları `mobile/app/test/rematch_slots_test.dart` — AYNI vakalar.
//
// NEDEN AYRI BİR BETİK: web'de birim test çatısı yok (`npm run test`
// Playwright). `verify-game-list-order` ile aynı desen.
//
// NEDEN ÖNEMLİ: bu sıralama kozmetik DEĞİL, `create_online_game`in üç
// kısıtının karşılığı — ilk koltuk çağıran, YZ'ler sonda. Kural sessizce
// bozulursa RPC reddeder ve hata ancak "Tekrar Oyna çalışmıyor" olarak,
// kullanıcıda görünür. 4 Eylül 2026'da ikinci bir çağıran doğduğu için
// (oyun geçmişindeki "Tekrar Oyna") ortak dosyaya çıkarıldı; bu betik
// iki yüzeyin de aynı kuralı kullandığını değil, KURALIN kendisini korur.
//
// Koşum: npm run verify-rematch-slots
import { buildRematchSlots, rematchHasAi, rematchOpponentNames } from '../src/utils/rematchSlots';
import type { OnlineGameSlot } from '../src/lib/database.types';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) console.log(`  ✓ ${name}`);
  else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const human = (id: string, name?: string): OnlineGameSlot =>
  name === undefined ? { type: 'human', user_id: id } : { type: 'human', user_id: id, name };
const ai = (): OnlineGameSlot => ({ type: 'ai' });
const özet = (slots: OnlineGameSlot[]) =>
  slots.map((s) => (s.type === 'ai' ? 'YZ' : s.user_id)).join(',');

console.log('Rövanş kadrosu — kural kontrolleri\n');

// (1) İlk koltuk HER ZAMAN çağıran — biten oyunu ben kurmamış olsam bile.
check(
  'kuran bensem sıra korunur',
  özet(buildRematchSlots([human('ben'), human('rakip')], 'ben')) === 'ben,rakip',
);
check(
  'kuran BEN DEĞİLSEM kendimi başa alırım',
  özet(buildRematchSlots([human('rakip'), human('ben')], 'ben')) === 'ben,rakip',
  özet(buildRematchSlots([human('rakip'), human('ben')], 'ben')),
);

// (2) 4 kişilikte YZ yalnız SON koltukta olabilir.
check(
  'YZ ortadayken sona taşınır, insanların sırası korunur',
  özet(buildRematchSlots([human('a'), ai(), human('ben'), human('b')], 'ben')) ===
    'ben,a,b,YZ',
  özet(buildRematchSlots([human('a'), ai(), human('ben'), human('b')], 'ben')),
);
check(
  'iki YZ de sonda ve SAYISI korunur',
  özet(buildRematchSlots([ai(), human('ben'), ai(), human('a')], 'ben')) === 'ben,a,YZ,YZ',
);

// (3) Koltuk sayısı hiçbir koşulda değişmez — RPC oyuncu sayısını ayrıca
// alıyor, kadro ondan kısa/uzun gelirse sessizce reddedilir.
for (const [ad, slots] of [
  ['2 kişilik', [human('ben'), human('a')]],
  ['4 kişilik insan', [human('ben'), human('a'), human('b'), human('c')]],
  ['4 kişilik YZ karışık', [human('ben'), human('a'), ai(), ai()]],
] as [string, OnlineGameSlot[]][]) {
  check(`${ad}: koltuk sayısı korunur`, buildRematchSlots(slots, 'ben').length === slots.length);
}

// (4) RPC'ye YALNIZCA type + user_id gider — görüntü alanları sızmaz.
const kirli = buildRematchSlots([human('ben', 'Ben'), human('a', 'Ali')], 'ben');
check(
  'name/avatar gibi görüntü alanları RPC yüküne sızmaz',
  kirli.every((s) => Object.keys(s).sort().join(',') === (s.type === 'ai' ? 'type' : 'type,user_id')),
  JSON.stringify(kirli),
);

// (5) Yardımcılar — onay metninin girdileri.
check(
  'rakip adları: kendim hariç, adsız koltuk için yer tutucu',
  rematchOpponentNames([human('ben', 'Ben'), human('a', 'Ali'), human('b')], 'ben').join('|') ===
    'Ali|Bir arkadaşın',
);
check('YZ var mı — yok', rematchHasAi([human('ben'), human('a')]) === false);
check('YZ var mı — var', rematchHasAi([human('ben'), ai()]) === true);

console.log(failures === 0 ? '\nTümü geçti.' : `\n${failures} kontrol DÜŞTÜ.`);
process.exit(failures === 0 ? 0 : 1);
