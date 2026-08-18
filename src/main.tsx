// Kelimeki — giriş noktası (ince kabuk).
//
// 18 Ağustos 2026'da İKİYE bölündü: bu dosya artık YALNIZCA yazı tiplerini,
// derleme kimliğini ve "karşılama katmanı mı, uygulama mı?" kararını taşıyor;
// React ağacının TAMAMI (`setupPwaUpdates`, `preloadWordSet`, path eşlemesi,
// `createRoot`, `StrictMode`/`ErrorBoundary` ağacı) olduğu gibi `./boot.tsx`'e
// taşındı ve oraya DİNAMİK olarak import ediliyor.
//
// NEDEN DİNAMİK: `index.html` bu dosyayı `<script type="module">` ile
// çağırıyor, yani paket `createRoot`'a hiç gelmeden İNİYOR. `createRoot`
// çağrısını geciktirmek indirmeyi engellemez — karşılama katmanını gören
// ziyaretçiye 0 KB uygulama JS'i göndermenin TEK yolu import'un KENDİSİNİN
// dinamik olması. Rollup burayı ikiye böler: bu minik giriş parçası +
// `boot-*.js` (bugünkü paket). Dönen kullanıcı için fazladan bir ağ turu
// oluşmasın diye `<head>`'e derleme zamanında bir `<link rel="modulepreload">`
// enjekte ediliyor (bkz. scripts/landing-plugin.js).

// Derleme kimliği — hangi commit'in çalıştığı devtools'tan tek satırda
// okunabilsin diye (bkz. vite.config.ts, `BUILD_ID`'nin varlık gerekçesi).
// Normal kullanıcıya hiçbir şey göstermez.
window.__KELIMEKI_BUILD__ = __KELIMEKI_BUILD__;

// Kendi sunucumuzdan servis edilen yazı tipleri (Google'a gidip gelmek yok).
// Türkçe için yalnızca latin + latin-ext alt kümeleri yüklenir.
//
// Caveat artık bir web fontu DEĞİL — logo ("kelimeki") tamamen statik SVG
// glyph path'lerine (LogoMark.tsx, bkz. scripts/generate-logo-paths.mjs)
// dönüştürüldü, çünkü font-display: swap + gerçek .woff2 dosyasına geçiş
// (23 Temmuz 2026) logoyu her açılışta yedek fonttan gerçek Caveat'e
// görünür biçimde sıçratıyordu (FOUT) — hatta PWA service worker'ın
// arka planda güncelleme uyguladığı her deploy sonrası ilk açılışta bu
// tekrar yaşanıyordu (bu uygulama sık deploy edildiğinden bu, nadir değil
// sürekli tekrar eden bir sorundu). Vektör path'ler hiçbir fonta veya ağ
// isteğine bağlı olmadığından bu sorunu kökten çözüyor.
import './fonts/space-grotesk-inline.css';
import './fonts/space-mono-inline.css';
import './fonts/nunito-tile.css';

// Karşılama katmanı da Tailwind kullanıyor — bu import KALIR.
import './index.css';

import { SEEN_INTRO_KEY } from './utils/onboarding';
import {
  captureUtmSource,
  getDeviceType,
  getOrCreateAnonId,
  getStoredUtmSource,
  isStandaloneDisplay,
  markVisitLoggedToday,
  visitAlreadyLoggedToday,
} from './utils/visitTracking';

/** Uygulamayı (React ağacı + PWA + sözlük ön yüklemesi) başlatır. */
function baslat(): void {
  void import('./boot').then((m) => m.mount());
}

/**
 * Karşılama katmanından uygulamaya geçişin TEK yolu — iki buton da buradan
 * geçer. Sayfa YENİDEN YÜKLENMEZ (`location.href = '/'` hem yavaş olurdu hem
 * `seen-intro` yazımıyla yarışırdı).
 *
 * SIRA ÖNEMLİ: önce `scrollTo(0, 0)`, SONRA katmanın kaldırılması. Ters
 * sırada katman kalkınca sayfa aniden kısalır, tarayıcı kaydırma konumunu
 * kendi düzeltir ve kullanıcı uygulamayı ortasından görür.
 */
function gec(niyet: 'oyna' | 'giris'): void {
  try {
    localStorage.setItem(SEEN_INTRO_KEY, '1');
  } catch {
    // Depolama kapalıysa (gizli sekme) katman bir daha gösterilir — geçiş
    // yine de çalışmalı.
  }
  window.scrollTo(0, 0);
  if (niyet === 'giris') {
    // `App.tsx` bunu okuyup giriş penceresini açar ve parametreyi
    // `history.replaceState` ile temizler — `?contact=1` ile aynı kalıp.
    window.history.replaceState(null, '', window.location.pathname + '?giris=1');
  }
  document.documentElement.classList.add('uygulama-modu');
  document.getElementById('karsilama')?.remove();
  baslat();
}

/**
 * Logo park efekti (18 Ağustos 2026, kullanıcı isteği): kahraman logo kilitli
 * şeridin altına girdiği an, şeridin ORTA yuvasındaki küçük kopya belirir
 * ("kaybolduğu anda oyna ve giriş butonun arasına küçülmüş olarak yerleşsin").
 *
 * Tetikleyici SABİT BİR KAYDIRMA EŞİĞİ DEĞİL: ölçüldü, şeridin ALTI ile
 * kahraman logonun ÜSTÜ arası tam 0.00 px ve şerit yüksekliği akışkan
 * (`clamp`) — yani eşik ekran genişliğine göre değişir ve sabit yazılırsa
 * bazı genişliklerde erken/geç tetiklenir. Bunun yerine logonun görünürlüğü
 * izleniyor ve `rootMargin` çalışma zamanında şeridin `offsetHeight`'inden
 * okunuyor.
 *
 * `root` BELGE DEĞİL `#karsilama`: bu sayfada belge hiç kaydırılmıyor
 * (`index.css` → `body { position: fixed; overflow: hidden }`), gerçek
 * kaydırma kabı katmanın kendisi. Varsayılan (viewport) kök ile gözlemci
 * hiçbir zaman tetiklenmezdi.
 *
 * Yeniden boyutlandırmada gözlemci baştan kuruluyor — `rootMargin` bir kez
 * okunan bir sayı ve şerit yüksekliği `vw` tabanlı olduğundan döndürmede
 * bayatlar.
 */
function logoParkiKur(): void {
  const katman = document.getElementById('karsilama');
  const serit = document.getElementById('karsilama-serit');
  const logo = document.getElementById('karsilama-logo');
  if (!katman || !serit || !logo) return;
  if (typeof IntersectionObserver === 'undefined') return;

  let gozlemci: IntersectionObserver | null = null;
  const kur = (): void => {
    gozlemci?.disconnect();
    gozlemci = new IntersectionObserver(
      (girisler) => {
        for (const g of girisler) katman.classList.toggle('logo-parkli', !g.isIntersecting);
      },
      { root: katman, rootMargin: `-${serit.offsetHeight}px 0px 0px 0px`, threshold: 0 },
    );
    gozlemci.observe(logo);
  };
  kur();
  window.addEventListener('resize', kur);
}

/**
 * Misafir ziyaret pingi — karşılama katmanı modunda `App.tsx` hiç mount
 * edilmediğinden oradaki `logGuestVisit` effect'i çalışmaz ve admin
 * panelindeki Büyüme > Kullanıcı "M. Ziyaret" serisi SESSİZCE düşerdi;
 * üstelik tam da o serinin var olma sebebi olan kitle (kayıt olmadan gelip
 * bakıp giden ziyaretçi) artık hiç sayılmazdı.
 *
 * Supabase SDK'sı (54 KB gzip) yerine düz `fetch`: bu insert'e RLS'te zaten
 * `anon` rolü yetkili (`guest_visits_insert_anon`), yani PostgREST'e düz bir
 * POST birebir aynı işi yapıyor. Anon anahtarı zaten JS paketinde ve
 * `index.html`'in `preconnect`'inde açık — yeni bir sır ifşası yok.
 *
 * ⚠ `guest_visits`in artık İKİ yazarı var: burası ve `logGuestVisit`
 * (`src/lib/api.ts`). Tabloya kolon eklenirse İKİSİ de güncellenmeli.
 *
 * Günde-bir-kez koruması `visitTracking.ts`'in ortak damgasını kullandığından,
 * kişi sonra "Oyna"ya basıp uygulamaya geçse bile `App.tsx` bunu görüp atlar —
 * mükerrer sayım olmaz.
 */
function misafirZiyaretiBildir(): void {
  const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
  const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;
  if (!url || !anonKey) return;
  if (visitAlreadyLoggedToday()) return;
  const anonId = getOrCreateAnonId();
  if (!anonId) return;
  markVisitLoggedToday();
  void fetch(`${url}/rest/v1/guest_visits`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify({
      anon_id: anonId,
      utm_source: getStoredUtmSource(),
      device_type: getDeviceType(),
      is_standalone: isStandaloneDisplay(),
    }),
  }).catch(() => {
    // Telemetri hiçbir koşulda karşılama katmanını etkilemez.
  });
}

// `<head>`'deki senkron kapı script'i (bkz. scripts/landing-plugin.js) dönen
// ziyaretçiyi ZATEN uygulama moduna almış olabilir — o durumda bugünkü
// davranış bit bit aynı: katman hiç render edilmez, doğrudan boot.
if (document.documentElement.classList.contains('uygulama-modu')) {
  // Katman zaten CSS ile gizli (`.uygulama-modu #karsilama`), ama DOM'da
  // BIRAKILMIYOR: Bölüm 3'te içerik büyüyecek ve dönen kullanıcının ağacında
  // ölü bir kopya taşımanın hiçbir faydası yok (metin sorguları/erişilebilirlik
  // ağacı için de gereksiz gürültü). Kaldırma `gec()` ile aynı satır.
  document.getElementById('karsilama')?.remove();
  baslat();
} else {
  // `?ref=` etiketini ilk temas olarak sakla — `App.tsx` de aynı çağrıyı
  // yapıyor, ama karşılama katmanında uygulama hiç mount edilmiyor.
  captureUtmSource();
  misafirZiyaretiBildir();
  // Sayfada birden fazla "Oyna"/"Giriş" düğmesi var (başlık + kahraman +
  // sayfa sonu). Hepsi öznitelikle bağlanıyor — id ile bağlamak yalnızca
  // başlıktakileri yakalardı ve yeni bir düğme eklendiğinde SESSİZCE ölü
  // kalırdı (bkz. Landing.tsx'in "buton bağlama sözleşmesi" notu).
  document
    .querySelectorAll<HTMLElement>('[data-kelimeki-oyna]')
    .forEach((el) => el.addEventListener('click', () => gec('oyna')));
  document
    .querySelectorAll<HTMLElement>('[data-kelimeki-giris]')
    .forEach((el) => el.addEventListener('click', () => gec('giris')));
  logoParkiKur();
}
