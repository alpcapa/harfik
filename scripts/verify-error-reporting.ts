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
  __setClientErrorSinkForTests,
  __resetErrorReportingForTests,
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

function kur(opts: { fail?: boolean } = {}) {
  const sent: Kayit[] = [];
  __resetErrorReportingForTests();
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

  // 4) Tekrar bastırma.
  {
    const sent = kur();
    reportClientError(new Error('aynı hata'));
    await bekle();
    reportClientError(new Error('aynı hata'));
    await bekle();
    check('aynı imza İKİNCİ kez gönderilmez', sent.length === 1, `sent=${sent.length}`);
  }

  // 5) Hız sınırı — çökme döngüsü koruması.
  {
    const sent = kur();
    for (let i = 0; i < 25; i++) {
      reportClientError(new Error(`hata ${i}`));
      await bekle();
    }
    check('oturum başına en fazla 10 kayıt', sent.length === 10, `sent=${sent.length}`);
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

  console.log(failures === 0 ? '\nTÜMÜ GEÇTİ' : `\n${failures} KONTROL DÜŞTÜ`);
  if (failures > 0) process.exit(1);
}

void main();
