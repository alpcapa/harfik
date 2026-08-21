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
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { AuthProvider } from './hooks/useAuth';
import { ErrorBoundary } from './components/ErrorBoundary';
import { SharedGamePage } from './components/SharedGamePage';
import { FriendInvitePage } from './components/FriendInvitePage';
import { captureUtmSource } from './utils/visitTracking';

import { setupPwaUpdates } from './lib/pwa';
import { preloadWordSet } from './data/wordSetLoader';

/**
 * Uygulamayı başlatır. `main.tsx`'ten TEK çağrı yeri var; gövde 18 Ağustos
 * 2026'daki ayrımdan önce `main.tsx`'in modül gövdesiydi ve satır satır
 * aynıdır (ağaç, sıra, `StrictMode`, `ErrorBoundary`, path regex'leri).
 */
export function mount(): void {
  setupPwaUpdates();

  // Kelime listesini (~63k kelime) ayrı bir chunk olarak arka planda
  // hemen indirmeye başlar — ilk render'ı bloklamaz (bkz. wordSetLoader.ts).
  // Bu ilk tetikleme fire-and-forget; gerçek retry mantığı App.tsx/Setup.tsx'in
  // kendi preloadWordSet() effect'lerinde — burada yalnızca bir kerelik ağ
  // hatasının konsola "Uncaught (in promise)" olarak düşmesini (App/Setup zaten
  // kendi çağrılarında yeniden deneyecek) önlemek için sessizce yutuluyor.
  preloadWordSet().catch(() => {});

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

  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <ErrorBoundary>
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
      </ErrorBoundary>
    </StrictMode>,
  );
}
