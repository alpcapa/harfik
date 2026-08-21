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
import { getOrCreateAnonId } from './visitTracking';
import { CLIENT_PLATFORM } from './platform';
import { isNetworkError } from './offlineNotice';
import { supabase } from '../lib/supabase';

export type ClientErrorKind = 'uncaught' | 'promise' | 'boundary' | 'manual';

/** Sunucudaki kırpma ile aynı tavan — ağa gereksiz bayt göndermemek için. */
const MAX_MESSAGE = 500;
const MAX_STACK = 4000;

/** Sayfa oturumu başına toplam rapor tavanı (çökme döngüsü koruması). */
const MAX_PER_SESSION = 10;

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

const gonderilenImzalar = new Set<string>();
let toplamGonderilen = 0;
/** Raporlama SIRASINDA doğan bir hata yeni bir rapor tetiklemesin. */
let raporlaniyor = false;

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
    if (toplamGonderilen >= MAX_PER_SESSION) return;

    const { message, stack } = mesajdan(err);
    const tamMesaj = context ? `[${context}] ${message}`.slice(0, MAX_MESSAGE) : message;
    // İmza mesajın BAŞINDAN türetiliyor: aynı hatanın farklı satır/sütun
    // numaralarıyla gelen kopyaları tek kayda inmeli.
    const imza = `${kind}|${tamMesaj.slice(0, 120)}`;
    if (gonderilenImzalar.has(imza)) return;
    gonderilenImzalar.add(imza);
    toplamGonderilen += 1;

    raporlaniyor = true;
    const kayit = {
      anon_id: getOrCreateAnonId(),
      platform: CLIENT_PLATFORM,
      build: typeof window !== 'undefined' ? (window.__KELIMEKI_BUILD__ ?? null) : null,
      kind,
      message: tamMesaj,
      stack,
      route: normalizeRoute(window.location.pathname),
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
    reportClientError(e.error ?? e.message, 'uncaught');
  });
  window.addEventListener('unhandledrejection', (e) => {
    reportClientError(e.reason, 'promise');
  });
}

/** Yalnızca testler için — sayaçları sıfırlar. */
export function __resetErrorReportingForTests(): void {
  gonderilenImzalar.clear();
  toplamGonderilen = 0;
  raporlaniyor = false;
  hedef = null;
}
