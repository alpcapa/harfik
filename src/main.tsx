import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { AuthProvider } from './hooks/useAuth';
import { ErrorBoundary } from './components/ErrorBoundary';
import { SharedGamePage } from './components/SharedGamePage';
import { FriendInvitePage } from './components/FriendInvitePage';

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

import './index.css';

import { setupPwaUpdates } from './lib/pwa';
import { preloadWordSet } from './data/wordSetLoader';

setupPwaUpdates();

// Kelime listesini (~63k kelime) ayrı bir chunk olarak arka planda
// hemen indirmeye başlar — ilk render'ı bloklamaz (bkz. wordSetLoader.ts).
// Bu ilk tetikleme fire-and-forget; gerçek retry mantığı App.tsx/Setup.tsx'in
// kendi preloadWordSet() effect'lerinde — burada yalnızca bir kerelik ağ
// hatasının konsola "Uncaught (in promise)" olarak düşmesini (App/Setup zaten
// kendi çağrılarında yeniden deneyecek) önlemek için sessizce yutuluyor.
preloadWordSet().catch(() => {});

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
