// Kelimeki — uygulamanın GERÇEK açılışı (React ağacı, PWA, sözlük ön yüklemesi).
//
// 18 Ağustos 2026'da `main.tsx`'ten AYRILDI (karşılama katmanı iskelesi):
// içerik satır satır AYNI, yalnızca yer değiştirdi ve bir `mount()`
// fonksiyonuna sarıldı. `main.tsx` bu modülü DİNAMİK import ediyor — böylece
// karşılama katmanını gören ziyaretçi bu paketi (ve service worker'ın
// precache'ini) hiç indirmiyor; dönen kullanıcı için hiçbir şey değişmiyor.
//
// Yazı tipi/`index.css` import'ları ve `window.__KELIMEKI_BUILD__` ataması
// BİLEREK `main.tsx`'te kaldı: katmanın kendisi de o CSS'i kullanıyor ve
// derleme kimliği her iki modda da yayınlanmalı.
import { StrictMode, Suspense, lazy } from 'react';
import { createRoot } from 'react-dom/client';
// `App`, `SharedGamePage` ve `FriendInvitePage` DİNAMİK import ediliyor —
// 25 Ağustos 2026'da ÖLÇÜLDÜ (üretim derlemesi + gerçek Chromium, aktarılan
// ham bayt): `/davet/:token` **2026 KB** indiriyordu ve bunun 787 KB'ı
// `boot` paketiydi, yani OYUNUN TAMAMI — tahta, motor, tüm pencereler, k-lig,
// sohbet. Davet linkine tıklayan kişi tanım gereği Kelimeki'yi hiç bilmeyen
// biri ve büyük ihtimalle mobil veride; ona ödettiğimiz şeyin neredeyse
// tamamını o sayfa kullanmıyordu.
//
// Bölmenin YÖNÜ önemli: önce yalnızca iki route sayfası lazy yapıldı ve
// kazanç **0.75 KB gzip** çıktı — çünkü ayrılan şey iki ince sarmalayıcıydı,
// ağır bağımlılıkları (`App` ile ortak olanlar) boot'ta kalıyordu. Kazancı
// veren, GÖVDEYİ (`App`) ayırmak: `/davet` **2026 → 885 KB**.
//
// Uygulama route'u artık `boot.js` → `App.js` diye iki adımda yükleniyor.
// Bu takas da ölçüldü (5 koşu, medyan, Setup görünene kadar): **333 → 331 ms**,
// yani anlamlı bir fark yok — zaten 2 MB indiren bir yolda ikinci bir istek
// gürültüde kalıyor.
const App = lazy(() => import('./App'));
import { AuthProvider } from './hooks/useAuth';
import { ErrorBoundary } from './components/ErrorBoundary';
const SharedGamePage = lazy(() =>
  import('./components/SharedGamePage').then((m) => ({ default: m.SharedGamePage })));
const FriendInvitePage = lazy(() =>
  import('./components/FriendInvitePage').then((m) => ({ default: m.FriendInvitePage })));
import { captureUtmSource } from './utils/visitTracking';
import { installGlobalErrorReporting } from './utils/errorReporting';

import { setupPwaUpdates } from './lib/pwa';
import { preloadWordSet } from './data/wordSetLoader';

/**
 * Uygulamayı başlatır. `main.tsx`'ten TEK çağrı yeri var; gövde 18 Ağustos
 * 2026'daki ayrımdan önce `main.tsx`'in modül gövdesiydi ve satır satır
 * aynıdır (ağaç, sıra, `StrictMode`, `ErrorBoundary`, path regex'leri).
 */
export function mount(): void {
  setupPwaUpdates();

  // Yakalanmamış istisna + reddedilen promise'leri anonim olarak bildir
  // (ROADMAP #3). EN BAŞTA kuruluyor ki açılış sırasında doğan bir hata da
  // yakalansın. Çevrimdışılık/ağ hataları BİLEREK bildirilmiyor — bkz.
  // `errorReporting.ts`, "NE KAYDEDİLMEZ".
  installGlobalErrorReporting();

  // `?ref=` etiketini ilk temas (first-touch) olarak sakla — ROUTE'DAN ÖNCE,
  // çünkü uygulamanın ÜÇ dalı var ve etiketi yalnızca biri yakalıyordu.
  //
  // 21 Ağustos 2026'da ÖLÇÜLDÜ (dev sunucusu + Chromium, localStorage
  // okunarak): `/davet/:token?ref=arkadas` ve gerçek bir uuid'li
  // `/game/:id?ref=tiktok` etiketi **hiç kaydetmiyordu** (`null`), yalnızca
  // `/` çalışıyordu. Sebep: çağrı `App.tsx`'in bir effect'indeydi, ama bu iki
  // route `App`'i hiç mount etmiyor (`SharedGamePage`/`FriendInvitePage`
  // render ediliyor) — yani dolaşımdaki her davet/paylaşım linki kaynağını
  // sessizce kaybediyordu. Buraya taşındı: burası üç dalın da tek ortak
  // giriş noktası, dolayısıyla ileride dördüncü bir route eklendiğinde de
  // kendiliğinden kapsanır.
  //
  // Karşılama katmanı ayrı: uygulama hiç mount edilmediğinden `main.tsx`
  // kendi dalında AYNI çağrıyı yapıyor. İkisi birlikte tüm yüzeyleri örtüyor
  // ve çağrı zaten idempotent (first-touch, üzerine yazmaz).
  captureUtmSource();

  // Projede genel bir router yok — herkese açık route'lar (/game/:id paylaşılan
  // oyun sayfası, /davet/:token arkadaşlık davet linki) için ayrı bir kütüphane
  // eklemek yerine burada hafif bir path kontrolü yeterli. vercel.json'daki
  // genel SPA rewrite'ı bu path'leri de index.html'e yönlendiriyor.
  const sharedGameMatch = window.location.pathname.match(/^\/game\/([0-9a-fA-F-]{36})\/?$/);
  const friendInviteMatch = window.location.pathname.match(/^\/davet\/([0-9a-fA-F]{10,64})\/?$/);

  // Kelime listesini (~63k kelime, 789 KB ham) ayrı bir chunk olarak arka
  // planda indirmeye başlar — ilk render'ı bloklamaz (bkz. wordSetLoader.ts).
  // Bu ilk tetikleme fire-and-forget; gerçek retry mantığı App.tsx/Setup.tsx'in
  // kendi preloadWordSet() effect'lerinde — burada yalnızca bir kerelik ağ
  // hatasının konsola "Uncaught (in promise)" olarak düşmesini (App/Setup zaten
  // kendi çağrılarında yeniden deneyecek) önlemek için sessizce yutuluyor.
  //
  // ⚠ ROUTE KARARININ ARDINDA: 25 Ağustos 2026'ya kadar bu çağrı `mount()`'ın
  // en başındaydı, yani `/davet/:token` ve `/game/:id` ziyaretçileri de 789 KB'lık
  // sözlüğü indiriyordu. İki sayfa da kelime doğrulaması yapmıyor (ikisinde de
  // `wordSet`e tek bir referans yok — grep'le doğrulandı), yani bu tamamen
  // boşa giden bir indirmeydi.
  if (!sharedGameMatch && !friendInviteMatch) preloadWordSet().catch(() => {});

  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <ErrorBoundary>
        {/* `fallback={null}`: üç dal da kendi yükleme durumunu kendi içinde
            yönetiyor (App'in Setup'ı, iki sayfanın kendi iskeletleri) — burada
            ikinci bir ara ekran göstermek yanıp sönme yaratırdı. */}
        <Suspense fallback={null}>
          {sharedGameMatch ? (
            <SharedGamePage gameId={sharedGameMatch[1]} />
          ) : friendInviteMatch ? (
            <AuthProvider>
              <FriendInvitePage token={friendInviteMatch[1]} />
            </AuthProvider>
          ) : (
            <AuthProvider>
              <App />
            </AuthProvider>
          )}
        </Suspense>
      </ErrorBoundary>
    </StrictMode>,
  );
}
