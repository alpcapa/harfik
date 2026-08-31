// Kelimeki — `src/utils/errorReporting.ts`'in KARAR mantığını ÜRETİM kodunu
// import ederek doğrular (ROADMAP #3).
//
// NEDEN AYRI BİR BETİK: web tarafında birim test çatısı yok (`npm run test`
// Playwright duman testleri) ve bu modül duman testiyle sınanamaz — üretimde
// yalnızca Supabase yapılandırılmışken çalışıyor, dev sunucusunda ise
// yapılandırılmamış. `verify-cloud-save-mirror`/`verify-fetch-my-games` ile
// aynı desen: esbuild + node, yeni bir bağımlılık yok.
//
// KAPSAM: telemetrinin ürünü BOZMAMASINI sağlayan üç değişmez (fire-and-forget,
// tekrar bastırma + hız sınırı, derleme kimliği) ve "NE KAYDEDİLMEZ" kuralı.
// Dart tarafındaki eşleniği: `mobile/app/test/error_reporter_test.dart` — aynı
// vakalar, aynı sıra.
//
// Koşum: npm run verify-error-reporting

// ⚠ Tarayıcı globalleri (`window`) bu dosyada DEĞİL, sürücüde
// (`run-verify-error-reporting.mjs`) kuruluyor: ESM import'ları hoisted
// olduğundan buraya yazılan bir atama modül gövdelerinden SONRA çalışırdı.
import { __setFake } from './support/fake-supabase';
import {
  reportClientError,
  normalizeRoute,
  isThirdPartyError,
  __setClientErrorSinkForTests,
  __resetErrorReportingForTests,
  __setClockForTests,
} from '../src/utils/errorReporting';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

type Kayit = Record<string, unknown>;

/**
 * Hız sınırı ZAMAN penceresine bağlı olduğundan saat sahte: testler `saatMs`i
 * elle ilerletiyor. Gerçek `Date.now` ile "1 saat sonra" sınanamazdı.
 *
 * ⚠ `__resetErrorReportingForTests` saati de gerçeğine döndürüyor — sahte
 * saat ondan SONRA kurulmalı.
 */
let saatMs = 1_000_000;

/** Üretim kaynağındaki `WINDOW_MS` ile aynı olmak zorunda. */
const PENCERE_MS = 60 * 60 * 1000;

function kur(opts: { fail?: boolean } = {}) {
  const sent: Kayit[] = [];
  __resetErrorReportingForTests();
  saatMs = 1_000_000;
  __setClockForTests(() => saatMs);
  __setClientErrorSinkForTests(async (r) => {
    sent.push(r);
    if (opts.fail) throw new Error('hedef patladı');
  });
  return sent;
}

/** Rapor fire-and-forget olduğundan mikrogörevlerin tamamlanmasını bekle. */
const bekle = () => new Promise((r) => setTimeout(r, 0));

/** `isNetworkError`'a düşen gerçek bir kalıp (bkz. offlineNotice.ts). */
const agHatasi = () => new Error('TypeError: Failed to fetch');

async function main() {
  console.log('errorReporting — karar mantığı');

  // 1) Yol normalleştirme: token/uuid HAM YAZILAMAZ.
  check('/davet/<token> maskelenir', normalizeRoute('/davet/abc123def456') === '/davet/:token');
  check('/game/<uuid> maskelenir', normalizeRoute('/game/9c1f5d2e-0000-4000-8000-0000') === '/game/:id');
  check('kök yol olduğu gibi kalır', normalizeRoute('/') === '/');
  check('çok uzun yol 60 karakterde kırpılır', normalizeRoute('/' + 'a'.repeat(200)).length === 60);

  // 2) Supabase HİÇ yapılandırılmamışken (misafir/offline derleme) modül
  // sessizce hiçbir şey yapmamalı. `noClient` gerçekten `supabase = null`
  // atıyor — bir Proxy her zaman truthy olduğundan bu dal ancak böyle
  // sınanabiliyor (bkz. `fake-supabase.__setFake` yorumu).
  {
    __resetErrorReportingForTests();
    __setFake({ noClient: true });
    // Hedef ATANMIYOR. "Gönderilmedi"yi doğrudan gözlemek mümkün değil
    // (gidecek bir yer yok), o yüzden AYIRT EDİCİ bir iz kullanılıyor: erken
    // dönüş gerçekleştiyse imza/sayaç HİÇ yazılmamış olmalı — yani AYNI hata
    // istemci geri gelince hâlâ gönderilebilmeli. Erken dönüş olmasaydı imza
    // kaydedilir ve ikinci çağrı tekrar-bastırmaya takılırdı.
    reportClientError(new Error('aynı mesaj'));
    await bekle();
    __setFake({});
    const sent = kur();
    reportClientError(new Error('aynı mesaj'));
    await bekle();
    check('Supabase yokken sayaç/imza da yazılmaz', sent.length === 1, `sent=${sent.length}`);
  }

  // 3) Kayıt alanları — derleme kimliği ve maskelenmiş yol dahil.
  {
    const sent = kur();
    reportClientError(new Error('patladı'), 'manual', 'test_ctx');
    await bekle();
    check('tek kayıt gönderilir', sent.length === 1, `sent=${sent.length}`);
    const r = sent[0] ?? {};
    check('kind taşınır', r.kind === 'manual');
    check('context mesajın başına eklenir', String(r.message).startsWith('[test_ctx] '));
    check('derleme kimliği taşınır', r.build === 'a1b2c3d');
    check('platform taşınır', r.platform === 'web');
    check('yol maskelenmiş gider', r.route === '/game/:id', String(r.route));
  }

  // 4) Tekrar bastırma — PENCERE İÇİNDE.
  {
    const sent = kur();
    reportClientError(new Error('aynı hata'));
    await bekle();
    reportClientError(new Error('aynı hata'));
    await bekle();
    check('aynı imza pencere içinde İKİNCİ kez gönderilmez', sent.length === 1, `sent=${sent.length}`);

    // Pencere kayınca imza da düşer. Süreç ömrüne bağlı eski hâlde bu kayıt
    // ASLA gelmezdi — günlerce yaşayan app sürecinde tekrar eden bir hata
    // yalnızca BİR kez sayılıyordu (ROADMAP #10).
    saatMs += PENCERE_MS;
    reportClientError(new Error('aynı hata'));
    await bekle();
    check('aynı imza pencere GEÇİNCE yeniden gönderilir', sent.length === 2, `sent=${sent.length}`);
  }

  // 5) Hız sınırı — çökme döngüsü koruması. Tavan KORUNUYOR, yalnızca
  // penceresi süreç ömründen zamana taşındı.
  {
    const sent = kur();
    for (let i = 0; i < 25; i++) {
      reportClientError(new Error(`hata ${i}`));
      await bekle();
    }
    check('pencere başına en fazla 10 kayıt', sent.length === 10, `sent=${sent.length}`);

    // Pencere DOLMADAN açılmaz: çökme döngüsü koruması gevşemiş olmamalı.
    saatMs += PENCERE_MS - 1;
    reportClientError(new Error('pencere dolmadan'));
    await bekle();
    check('pencere dolmadan tavan açılmaz', sent.length === 10, `sent=${sent.length}`);

    // Pencere kayınca yeniden açılır — maddenin kendisi bu.
    saatMs += 1;
    reportClientError(new Error('pencere kaydıktan sonra'));
    await bekle();
    check('pencere kayınca sayaç düşer', sent.length === 11, `sent=${sent.length}`);
  }

  // 5b) Cihaz saati GERİYE alınırsa körlük kalıcı olmamalı — damgalar
  // "gelecekte" kalır ve normalde hiç eskimezdi.
  {
    const sent = kur();
    for (let i = 0; i < 10; i++) {
      reportClientError(new Error(`hata ${i}`));
      await bekle();
    }
    check('saat testi: tavan doldu', sent.length === 10, `sent=${sent.length}`);
    saatMs -= 5 * PENCERE_MS;
    reportClientError(new Error('saat geriye alındı'));
    await bekle();
    check('saat geriye alınınca kalıcı körlük olmaz', sent.length === 11, `sent=${sent.length}`);
  }

  // 6) NE KAYDEDİLMEZ — beklenen durumlar.
  {
    const sent = kur();
    reportClientError(agHatasi(), 'uncaught');
    await bekle();
    check('OTOMATİK yakalamada ağ hatası ELENİR', sent.length === 0, `sent=${sent.length}`);
  }
  {
    // Filtrenin `kind !== 'manual'` koşulunun TEK sebebi: `cloud_save`
    // "KAYIP" noktasında elimizdeki hata ağ hatasıdır, ama raporlanmaya
    // değer kılan şey AYNANIN DA yazılamamış olmasıdır.
    const sent = kur();
    reportClientError(agHatasi(), 'manual', 'cloud_save');
    await bekle();
    check('MANUEL bildirimde ağ hatası ELENMEZ', sent.length === 1, `sent=${sent.length}`);
  }

  // 7) Kırpma.
  {
    const sent = kur();
    const e = new Error('x'.repeat(2000));
    e.stack = 'y'.repeat(9000);
    reportClientError(e, 'boundary');
    await bekle();
    check('mesaj 500 karakterde kırpılır', String(sent[0]?.message).length === 500);
    check('yığın 4000 karakterde kırpılır', String(sent[0]?.stack).length === 4000);
  }

  // 8) Hedef fırlatırsa uygulama etkilenmez, sonraki rapor yine gider.
  {
    const sent = kur({ fail: true });
    reportClientError(new Error('ilk'));
    await bekle();
    __setClientErrorSinkForTests(async (r) => {
      sent.push(r);
    });
    reportClientError(new Error('ikinci'));
    await bekle();
    check('hedef hatası yutulur, akış devam eder', sent.length === 2, `sent=${sent.length}`);
  }

  // 9) Error olmayan bir değer de kaydedilir (promise reddi genelde string).
  {
    const sent = kur();
    reportClientError('düz bir dize', 'promise');
    await bekle();
    check('Error olmayan değer de kaydedilir', sent[0]?.message === 'düz bir dize');
    check('yığın yoksa null gider', sent[0]?.stack === null);
  }

  // 10) BİZE AİT OLMAYAN kod — panelin ilk gerçek verisinden gelen kurallar.
  //
  // Gerçek yığın: Instagram/Facebook'un Android'deki uygulama-içi tarayıcısı
  // sayfaya bir ölçüm script'i enjekte ediyor ve sekme kapanırken patlıyor.
  // Bizim kodumuz yığında HİÇ geçmiyor.
  const IAB_STACK = [
    'Error: Error invoking postMessage: Java exception was raised during method invocation',
    '    at sendDataToNative (iabjs://navigation_performance_logger_android:1:10198)',
    '    at sendBeforeUnloadMessage (iabjs://navigation_performance_logger_android:1:13750)',
    '    at window._handleBrowserPreparingToClose (iabjs://navigation_performance_logger_android:1:15718)',
    '    at <anonymous>:1:22',
  ].join('\n');
  const BIZIM_STACK = [
    'TypeError: x is not a function',
    '    at Board (https://kelimeki.com/assets/index-abc123.js:12:345)',
    '    at renderWithHooks (https://kelimeki.com/assets/index-abc123.js:9:87)',
  ].join('\n');

  check('IAB yığını üçüncü taraf sayılır', isThirdPartyError('Error invoking postMessage', IAB_STACK));
  check('IAB dosya adı üçüncü taraf sayılır', isThirdPartyError('boş', null, 'iabjs://navigation_performance_logger_android'));
  check('"Script error." üçüncü taraf sayılır', isThirdPartyError('Script error.', null));
  check('BİZİM yığın üçüncü taraf SAYILMAZ', !isThirdPartyError('TypeError: x is not a function', BIZIM_STACK));
  check('kendi paketimizin dosya adı SAYILMAZ', !isThirdPartyError('x', null, 'https://kelimeki.com/assets/index-abc.js'));
  // Yığınsız/URL'siz bir hata KARAR VERİLEMEZ → raporlanır (şüphede kal).
  check('yığınsız sıradan hata SAYILMAZ', !isThirdPartyError('bir şey patladı', null));
  check('göreli/satır içi kare SAYILMAZ', !isThirdPartyError('x', 'Error\n    at <anonymous>:1:22'));

  {
    const sent = kur();
    const e = new Error('Error invoking postMessage: Java exception was raised during method invocation');
    e.stack = IAB_STACK;
    reportClientError(e, 'uncaught');
    await bekle();
    check('OTOMATİK yakalamada üçüncü taraf hatası ELENİR', sent.length === 0, `sent=${sent.length}`);
  }
  {
    // Aynı hata MANUEL bildirilirse elenmez — orada kaynak zaten bizim çağrı
    // yerimiz (ağ filtresiyle birebir aynı gerekçe).
    const sent = kur();
    const e = new Error('Error invoking postMessage');
    e.stack = IAB_STACK;
    reportClientError(e, 'manual', 'test_ctx');
    await bekle();
    check('MANUEL bildirimde üçüncü taraf filtresi UYGULANMAZ', sent.length === 1, `sent=${sent.length}`);
  }
  {
    // Pozitif kontrol: gerçek bir uygulama hatası HÂLÂ gidiyor.
    const sent = kur();
    const e = new Error('TypeError: x is not a function');
    e.stack = BIZIM_STACK;
    reportClientError(e, 'uncaught');
    await bekle();
    check('BİZİM koddan gelen hata raporlanır', sent.length === 1, `sent=${sent.length}`);
  }

  console.log(failures === 0 ? '\nTÜMÜ GEÇTİ' : `\n${failures} KONTROL DÜŞTÜ`);
  if (failures > 0) process.exit(1);
}

void main();
