// Kelimeki — `src/utils/awayReturn.ts`'in saf karar mantığını ÜRETİM kodunu
// import ederek doğrular.
//
// NEDEN AYRI BİR BETİK: web'de birim test çatısı yok (`npm run test`
// Playwright duman testleri) ve bu mantık duman testiyle SINANAMAZ — Setup'ın
// rozet/varsayılan-sekme effect'i yalnızca giriş yapılmış kullanıcıda ve
// Supabase yapılandırılmışken çalışıyor, dev sunucusunda ikisi de yok.
// `verify-cloud-save-mirror`in aynı deseni (esbuild + node).
//
// Koşum: npm run verify-away-return
import { createAwayTracker, LONG_AWAY_MS } from '../src/utils/awayReturn';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const MIN = 60 * 1000;

/** Kontrol edilebilir bir saatle izleyici kurar. */
function tracker(startMs = 1_760_000_000_000) {
  let t = startMs;
  return {
    at: createAwayTracker(() => t),
    advance(ms: number) {
      t += ms;
    },
  };
}

console.log('awayReturn — uzakta kalma izleyicisi');

// 1 — hiç uzaklaşılmadıysa karar VERİLMEZ. Bu, ilk açılışın (odaksız açılan
// sekme, otomatik yeniden yükleme) yolu: bilinmiyorsa mevcut sekmede kalınır.
{
  const { at } = tracker();
  check('uzaklaşma görülmediyse false', at.takeLongAway() === false);
}

// 2 — kısa bir alt-tab yeniden silahlandırMAZ. Bu değişikliğin bütün riski
// burada: eşik olmasaydı kullanıcı bilerek oturduğu sekmeden koparılırdı.
{
  const { at, advance } = tracker();
  at.markAway();
  advance(30 * 1000);
  check('30 sn uzakta → false', at.takeLongAway() === false);
}

// 3 — uzun bir aradan sonra dönüş yeniden silahlandırır.
{
  const { at, advance } = tracker();
  at.markAway();
  advance(30 * MIN);
  check('30 dk uzakta → true', at.takeLongAway() === true);
}

// 4 — eşiğin tam kendisi de sayılır (`>=`).
{
  const { at, advance } = tracker();
  at.markAway();
  advance(LONG_AWAY_MS);
  check('eşiğin tam üstünde → true', at.takeLongAway() === true);
  const { at: at2, advance: adv2 } = tracker();
  at2.markAway();
  adv2(LONG_AWAY_MS - 1);
  check('eşiğin 1 ms altında → false', at2.takeLongAway() === false);
}

// 5 — İLK işaret kazanır. Masaüstünde `blur` ve `visibilitychange` art arda
// geliyor; ikincisi damgayı tazeleseydi uzakta geçen süre olduğundan kısa
// ölçülür ve uzun bir arada bile yeniden silahlanma OLMAZDI.
{
  const { at, advance } = tracker();
  at.markAway();
  advance(20 * MIN);
  at.markAway(); // ikinci olay (ör. visibilitychange → hidden)
  check('ikinci markAway damgayı tazelemez', at.takeLongAway() === true);
}

// 6 — karar bir kez tüketilir. Dönüşte de iki olay (focus + visibilitychange)
// art arda geliyor; ikincisi `true` deseydi ref ikinci kez sıfırlanır ve
// aradaki `refresh()` sonucu (kullanıcının o an yaptığı seçim) ezilebilirdi.
{
  const { at, advance } = tracker();
  at.markAway();
  advance(30 * MIN);
  check('ilk dönüş kararı verir', at.takeLongAway() === true);
  check('aynı dönüşün ikinci olayı false', at.takeLongAway() === false);
}

// 7 — tüketildikten sonra yeni bir uzaklaşma yeniden ölçülür (izleyici tek
// kullanımlık değil; uygulama gün boyunca defalarca arka plana alınabilir).
{
  const { at, advance } = tracker();
  at.markAway();
  advance(30 * MIN);
  at.takeLongAway();
  at.markAway();
  advance(10 * 1000);
  check('yeni kısa uzaklaşma → false', at.takeLongAway() === false);
  at.markAway();
  advance(2 * LONG_AWAY_MS);
  check('yeni uzun uzaklaşma → true', at.takeLongAway() === true);
}

// 8 — eşik çağrı yerinden geçilebiliyor (testler ve olası ileri kullanım).
{
  const { at, advance } = tracker();
  at.markAway();
  advance(MIN);
  check('özel eşik uygulanır', at.takeLongAway(30 * 1000) === true);
}

// 9 — varsayılan eşik 5 dakika. Sayı burada KİLİTLİ: mobil portun karşılığı
// (`mobile/app/lib/src/util/away_return.dart`) ELLE senkron ve iki platformun
// aynı süreyi kullanması gerekiyor.
check('LONG_AWAY_MS = 5 dakika', LONG_AWAY_MS === 5 * MIN, String(LONG_AWAY_MS));

console.log('');
if (failures > 0) {
  console.log(`${failures} kontrol BAŞARISIZ`);
  process.exit(1);
}
console.log('Tüm kontroller geçti.');
