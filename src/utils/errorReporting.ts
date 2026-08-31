// Kelimeki — istemci hata telemetrisi (ROADMAP #3, 21 Ağustos 2026).
//
// NEDEN VAR: bugüne kadar istemcideki her çökme KULLANICININ CİHAZINDA
// ölüyordu — `console.error`, `ErrorBoundary`, portta `debugPrint`. Kimse
// görmüyor, aranamıyor, "kaç kişide oldu?" sorusu sorulamıyordu. Bu projede
// bedeli ölçülmüş: avatar yükleme 20 Temmuz'dan 13 Ağustos'a kadar 403
// veriyordu ve kimse fotoğrafını değiştirmediği için ÜÇ HAFTA görünmedi.
//
// ÜÇ DEĞİŞMEZ (biri bozulursa telemetri ürünü bozar):
//   1. FIRE-AND-FORGET — asla `await` edilmez, ASLA fırlatmaz. Bir hata
//      raporlama hatası uygulamayı etkileyemez.
//   2. TEKRAR BASTIRMA + HIZ SINIRI — bir çökme döngüsü aksi halde binlerce
//      satır yazar (`ErrorBoundary`'nin kendi yorumunda o döngü zaten
//      tanımlı: bozuk kayıt → her reload'da aynı hata).
//   3. DERLEME KİMLİĞİ her kayda eklenir — "Deploy Doğrulaması" bölümünün
//      tamamı zaten "kullanıcı hangi derlemeyi görüyor?" sorusunu çözmek
//      için var; telemetri onu bedavaya alır.
//
// NE KAYDEDİLMEZ — bu, bu dosyanın en önemli kısmı. Bir kayıt "birinin
// bakması gereken bir şey" demek olmalı; gürültü sinyali boğarsa panel bir
// daha açılmaz:
//   * ÇEVRİMDIŞILIK ve `isNetworkError`'a düşen her şey. Bunlar BEKLENEN
//     durumlar — uygulamanın zaten ele aldığı, kullanıcıya kendi metniyle
//     anlattığı şeyler (bkz. `offlineNotice.ts`).
//   * Sunucunun KENDİ reddi ("Sıra sende değil." gibi). O bir kural, hata
//     değil. Bunlar zaten `catch`lenip kullanıcıya gösteriliyor, buraya
//     yalnızca yakalanMAMIŞ olanlar düşer — ki o zaman gerçekten bir bug'dır.
//   * BİZE AİT OLMAYAN koddan doğan hatalar (bkz. `isThirdPartyError`).
//     23 Ağustos 2026'da panelin İLK gerçek verisi bunu zorunlu kıldı: yedi
//     kaydın yedisi de gürültüydü ve beşi tek bir kaynaktan geliyordu —
//     Instagram/Facebook'un Android'deki uygulama-içi tarayıcısının sayfaya
//     enjekte ettiği ölçüm script'i (`iabjs://navigation_performance_logger_
//     android`), sekme kapanırken `postMessage`ta patlıyor. Bizim kodumuzla
//     hiçbir ilgisi yok, düzeltemeyiz ve reklam trafiği arttıkça KATLANARAK
//     artacak. Filtre olmadan panel ilk haftasında kullanılamaz hâle gelirdi.
import { getOrCreateAnonId } from './visitTracking';
import { CLIENT_PLATFORM } from './platform';
import { isNetworkError } from './offlineNotice';
import { supabase } from '../lib/supabase';

export type ClientErrorKind = 'uncaught' | 'promise' | 'boundary' | 'manual';

/** Sunucudaki kırpma ile aynı tavan — ağa gereksiz bayt göndermemek için. */
const MAX_MESSAGE = 500;
const MAX_STACK = 4000;

/**
 * Çökme döngüsü koruması: son `WINDOW_MS` içinde en fazla `MAX_PER_WINDOW`
 * kayıt, ve aynı imza pencere başına BİR kez.
 *
 * ⚠ PENCERE, SÜREÇ ÖMRÜ DEĞİL (31 Ağustos 2026, ROADMAP #10). Önceki hâl
 * "oturum başına 10"du ve sayaç/imza kümesi hiç temizlenmiyordu. Web'de
 * bedeli yoktu — bir sayfa yenilemesi ikisini de sıfırlıyor. **App süreci
 * ise günlerce yaşıyor:** 10 FARKLI hatadan sonra o cihaz kalıcı olarak
 * susuyor ve tekrar eden bir hata süreç başına yalnızca BİR kez sayılıyordu.
 * Panelin "kaç cihaz" ölçütü bundan etkilenmiyordu (o zaten cihaz başına
 * tekil sayar) ama "kaç kez" olduğundan küçük geliyordu.
 *
 * Sayılar İKİ İSTEMCİDE AYNI olmak zorunda — `error_rate_limit_parity_test`
 * ikisini de kaynaktan okuyup karşılaştırıyor.
 */
const MAX_PER_WINDOW = 10;
const WINDOW_MS = 60 * 60 * 1000;

/**
 * Kaydın gideceği yer. Varsayılanı Supabase; testler (ve yalnızca testler)
 * bunu değiştirebilir — Dart tarafındaki `ClientErrorSink` ile aynı desen,
 * karar mantığı ağdan bağımsız sınanabilsin diye.
 */
export type ClientErrorSink = (record: Record<string, unknown>) => Promise<unknown>;

let hedef: ClientErrorSink | null = null;

/** Yalnızca testler için — hedefi değiştirir. Üretim kodu ÇAĞIRMAZ. */
export function __setClientErrorSinkForTests(sink: ClientErrorSink | null): void {
  hedef = sink;
}

/** Pencere içinde gönderilmiş kayıtların zaman damgaları. */
const gonderimZamanlari: number[] = [];
/** İmza → o imzanın en son gönderildiği an. */
const imzaZamanlari = new Map<string, number>();
/** Raporlama SIRASINDA doğan bir hata yeni bir rapor tetiklemesin. */
let raporlaniyor = false;

/** Saat — testler dışında her zaman `Date.now`. */
let saat: () => number = () => Date.now();

/** Yalnızca testler için — saati değiştirir. Üretim kodu ÇAĞIRMAZ. */
export function __setClockForTests(fn: (() => number) | null): void {
  saat = fn ?? (() => Date.now());
}

/**
 * Pencerenin dışına düşen kayıtları/imzaları unutur.
 *
 * ⚠ GELECEKTEKİ damga da düşer (`t > simdi`). Kaynak duvar saati ve cihazın
 * saati geriye alınabilir (elle ayar, NTP düzeltmesi); o durumda `simdi - t`
 * negatif olur ve girdi normalde HİÇ eskimezdi — yani düzeltmenin bedeli
 * tam da bu maddenin kapatmaya çalıştığı körlük olurdu.
 */
function pencereyiKaydir(simdi: number): void {
  const gecerli = (t: number) => t <= simdi && simdi - t < WINDOW_MS;
  for (let i = gonderimZamanlari.length - 1; i >= 0; i--) {
    if (!gecerli(gonderimZamanlari[i]!)) gonderimZamanlari.splice(i, 1);
  }
  for (const [imza, t] of imzaZamanlari) {
    if (!gecerli(t)) imzaZamanlari.delete(imza);
  }
}

/**
 * `/davet/<token>` HAM YAZILAMAZ — o token bir yetenek (capability), hata
 * tablosuna düşmesi onu sızdırır. Sunucuda ayrıca bir maskeleme trigger'ı
 * var (`_mask_route`) ama tek savunma hattı OLMAMALI: burada da normalleştir.
 */
export function normalizeRoute(pathname: string): string {
  if (/^\/davet\//.test(pathname)) return '/davet/:token';
  if (/^\/game\//.test(pathname)) return '/game/:id';
  return pathname.length > 60 ? pathname.slice(0, 60) : pathname;
}

/**
 * Bir URL bizim kaynağımızdan mı? Bilinmiyorsa (göreli yol, satır içi kod,
 * `origin` okunamıyor) BİZİM sayılır — bu filtrenin yanlış POZİTİFİ gerçek
 * bir hatayı sessizce düşürmek demek, yanlış negatifi ise yalnızca bir
 * gürültü satırı. Şüphede kal ve raporla.
 */
function bizeAitUrl(url: string): boolean {
  const origin =
    typeof window !== 'undefined' && window.location ? (window.location.origin ?? '') : '';
  if (!origin) return true;
  // Kendi Worker/Blob URL'lerimiz `blob:https://origin/…` biçiminde.
  const u = url.startsWith('blob:') ? url.slice(5) : url;
  if (!u.includes('://')) return true; // göreli/satır içi
  return u === origin || u.startsWith(`${origin}/`);
}

/**
 * Hata BİZİM kodumuzdan mı doğdu? Üç sinyal — herhangi biri "hayır" derse
 * kayıt DÜŞER:
 *
 * 1. **`Script error.`** — çapraz kaynaklı bir script'ten gelen hatada
 *    tarayıcı mesajı, yığını ve satır bilgisini SİLER; geriye teşhis değeri
 *    SIFIR olan bu dize kalır. Kaydetmek "bir yerde bir şey oldu" demekten
 *    ibaret.
 * 2. **Dosya adı (`ErrorEvent.filename`) bize ait değil.** Uygulama-içi
 *    tarayıcıların enjekte ettiği script'ler kendi şemalarını kullanıyor
 *    (`iabjs://…`), yani ayrım kesin.
 * 3. **Yığındaki HİÇBİR kare bizim kaynağımızdan değil.** `filename` boş
 *    geldiğinde tek elimizde kalan bu. Yığında hiç URL yoksa karar
 *    verilemez → raporlanır (bkz. `bizeAitUrl`'in "şüphede kal" kuralı).
 *
 * ⚠ Üçüncü kural ancak sayfada ÜÇÜNCÜ TARAF script'i olmadığı için güvenli:
 * Kelimeki hiçbir dış script yüklemiyor (yalnızca kendi paketimiz). Bir gün
 * bir analytics/SDK eklenirse o script'in GERÇEK hataları da bu filtreye
 * takılır — o zaman kural yeniden düşünülmeli.
 */
export function isThirdPartyError(
  message: string,
  stack: string | null,
  filename?: string | null,
): boolean {
  if (!stack && /^script error\.?$/i.test(message.trim())) return true;
  if (filename && !bizeAitUrl(filename)) return true;
  const urls = stack ? (stack.match(/\b[a-z][a-z0-9+.-]*:\/\/[^\s)]+/gi) ?? []) : [];
  if (urls.length > 0 && !urls.some(bizeAitUrl)) return true;
  return false;
}

function mesajdan(err: unknown): { message: string; stack: string | null } {
  if (err instanceof Error) {
    return {
      message: (err.message || err.name || 'Error').slice(0, MAX_MESSAGE),
      stack: err.stack ? err.stack.slice(0, MAX_STACK) : null,
    };
  }
  return { message: String(err ?? 'bilinmeyen hata').slice(0, MAX_MESSAGE), stack: null };
}

/**
 * Bir hatayı anonim olarak bildirir. Fire-and-forget: dönüşü beklenmez ve
 * hiçbir koşulda fırlatmaz.
 *
 * `context` çağıranın verdiği kısa etiket ("cloud_save_repo" gibi) — mesajın
 * başına ekleniyor ki panelde aynı mesaj farklı yerlerden geldiğinde ayrışsın.
 */
export function reportClientError(
  err: unknown,
  kind: ClientErrorKind = 'manual',
  context?: string,
): void {
  try {
    if (!hedef && !supabase) return;
    // BEKLENEN durum — bkz. dosya başlığı, "NE KAYDEDİLMEZ".
    //
    // ⚠ Filtre YALNIZCA otomatik yakalamalara uygulanır. `manual` çağrılarda
    // sinyal hatanın KENDİSİ değil, ÇAĞIRANIN bildiği bağlamdır: `cloud_save`
    // "KAYIP" noktasında elimizdeki hata sunucu hatasıdır (çoğu zaman ağ),
    // ama raporlanmaya değer kılan şey AYNANIN DA yazılamamış olmasıdır.
    // Ağ filtresini oraya da uygulamak, telemetrinin var olma sebebi olan
    // kaydı tam da sessizce düşürürdü.
    if (kind !== 'manual' && isNetworkError(err)) return;
    if (raporlaniyor) return;
    const simdi = saat();
    pencereyiKaydir(simdi);
    if (gonderimZamanlari.length >= MAX_PER_WINDOW) return;

    const { message, stack } = mesajdan(err);
    // Bize ait olmayan koddan doğan hata — aynı gerekçeyle YALNIZCA otomatik
    // yakalamalarda elenir: `manual` bildirimde kaynak zaten bizim çağrı
    // yerimizdir, yığın da genelde yoktur.
    if (kind !== 'manual' && isThirdPartyError(message, stack)) return;
    const tamMesaj = context ? `[${context}] ${message}`.slice(0, MAX_MESSAGE) : message;
    // İmza mesajın BAŞINDAN türetiliyor: aynı hatanın farklı satır/sütun
    // numaralarıyla gelen kopyaları tek kayda inmeli.
    const imza = `${kind}|${tamMesaj.slice(0, 120)}`;
    if (imzaZamanlari.has(imza)) return;
    imzaZamanlari.set(imza, simdi);
    gonderimZamanlari.push(simdi);

    raporlaniyor = true;
    const kayit = {
      anon_id: getOrCreateAnonId(),
      platform: CLIENT_PLATFORM,
      build: typeof window !== 'undefined' ? (window.__KELIMEKI_BUILD__ ?? null) : null,
      kind,
      message: tamMesaj,
      stack,
      route: normalizeRoute(window.location.pathname),
      // Web'de ÜRÜN SÜRÜMÜ YOK ve bu bilinçli: aynı anda tek bir canlı
      // derleme var, `build` (sha) onu zaten tekil belirliyor. Mobilde ise
      // mağazada aynı anda birden çok sürüm yaşayacağından port bu alanı
      // `appVersion` ile dolduruyor — null burada "sürümü olmayan istemci",
      // yani web demek (bkz. `telemetry_app_version` migration'ı).
      app_version: null,
    };
    const gonder = hedef ?? ((r: Record<string, unknown>) => supabase!.from('client_errors').insert(r));
    void Promise.resolve(gonder(kayit)).then(
        () => {
          raporlaniyor = false;
        },
        () => {
          // Yutuluyor: telemetri hatası konsola bile yazılmıyor, çünkü
          // `console.error`'ı sarmalayan bir gelecek sürümde bu bir döngü
          // olurdu.
          raporlaniyor = false;
        },
      );
  } catch {
    raporlaniyor = false;
  }
}

/**
 * Global yakalayıcılar — `boot.tsx`ten BİR KEZ çağrılır. `ErrorBoundary`
 * React render hatalarını ayrıca kendi `componentDidCatch`inden bildiriyor
 * (React onları global handler'a bırakmaz).
 */
export function installGlobalErrorReporting(): void {
  window.addEventListener('error', (e) => {
    // `filename` YALNIZCA burada var (ErrorEvent'in alanı, Error'ın değil) —
    // `reportClientError` onu göremez, o yüzden karar burada da veriliyor.
    const stack = e.error instanceof Error ? (e.error.stack ?? null) : null;
    if (isThirdPartyError(String(e.message ?? ''), stack, e.filename)) return;
    reportClientError(e.error ?? e.message, 'uncaught');
  });
  window.addEventListener('unhandledrejection', (e) => {
    reportClientError(e.reason, 'promise');
  });
}

/** Yalnızca testler için — sayaçları sıfırlar. */
export function __resetErrorReportingForTests(): void {
  imzaZamanlari.clear();
  gonderimZamanlari.length = 0;
  raporlaniyor = false;
  hedef = null;
  saat = () => Date.now();
}
