import { useEffect, useState } from 'react';
import { isStandaloneDisplay } from '../utils/visitTracking';

const DISMISSED_KEY = 'kelimeki_a2hs_dismissed';

// Basit User-Agent tabanlı ayrım — kod incelemesinde "tüm platformlara
// iOS'a özgü talimat gösteriyor" bulgusu için eklendi. Android Chrome'un
// kurulum akışı (tarayıcı menüsü → "Ana ekrana ekle"/"Yükle") iOS'un paylaş
// sayfası jestinden tamamen farklı olduğundan, yanlış platforma iOS
// talimatı göstermek kafa karıştırıcıydı. `beforeinstallprompt` API'sine
// (yalnızca bazı Chromium sürümlerinde var) bağlanmak yerine bilinçli
// olarak basit tutuldu — masaüstü/diğer tarayıcılar genel bir talimata düşer.
function detectPlatform(): 'ios' | 'android' | 'other' {
  const ua = navigator.userAgent;
  if (/iPhone|iPad|iPod/.test(ua)) return 'ios';
  if (/Android/.test(ua)) return 'android';
  return 'other';
}

export function AddToHomeScreen() {
  const [visible, setVisible] = useState(false);
  const [platform] = useState(detectPlatform);

  useEffect(() => {
    if (isStandaloneDisplay()) return;
    if (localStorage.getItem(DISMISSED_KEY)) return;
    // Short delay so the banner doesn't flash on first paint.
    const t = setTimeout(() => setVisible(true), 1200);
    return () => clearTimeout(t);
  }, []);

  const dismiss = () => {
    setVisible(false);
    localStorage.setItem(DISMISSED_KEY, '1');
  };

  if (!visible) return null;

  return (
    <div
      className="fixed bottom-4 left-0 right-0 z-[60] flex justify-center px-3 pb-4 animate-slide-up"
      style={{ animation: 'slideUp 0.35s cubic-bezier(0.16,1,0.3,1) both' }}
    >
      <style>{`
        @keyframes slideUp {
          from { transform: translateY(110%); opacity: 0; }
          to   { transform: translateY(0);    opacity: 1; }
        }
      `}</style>
      <div className="w-full max-w-[460px] bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_20px_45px_rgba(15,23,42,0.5)] px-4 py-3.5 flex items-center gap-3">
        {/* Genel "yükle/paylaş" ikonu — platforma özel metin altta ayrışıyor. */}
        <svg
          width="28" height="28" viewBox="0 0 28 28" fill="none"
          className="shrink-0 text-accent"
          aria-hidden
        >
          <rect width="28" height="28" rx="7" fill="currentColor" fillOpacity="0.12"/>
          <path
            d="M14 4v12M10 8l4-4 4 4M8 14v8h12v-8"
            stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
          />
        </svg>

        <div className="flex-1 min-w-0">
          <p className="text-xs font-bold text-text font-sans leading-snug">
            Ana ekrana ekle
          </p>
          {platform === 'ios' ? (
            <p className="text-[10px] text-muted font-mono leading-relaxed mt-0.5">
              Paylaş{' '}
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none" className="inline-block align-middle -mt-0.5" aria-hidden>
                <path d="M5 1v6M3 3l2-2 2 2M1 6v3h8V6" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              {' '}düğmesine dokun, ardından{' '}
              <span className="text-text font-bold">"Ana Ekrana Ekle"</span>'yi seç.
            </p>
          ) : platform === 'android' ? (
            <p className="text-[10px] text-muted font-mono leading-relaxed mt-0.5">
              Tarayıcı menüsünden (⋮) <span className="text-text font-bold">"Ana ekrana ekle"</span> ya da <span className="text-text font-bold">"Yükle"</span>'yi seç.
            </p>
          ) : (
            <p className="text-[10px] text-muted font-mono leading-relaxed mt-0.5">
              Tarayıcının menüsünden <span className="text-text font-bold">"Yükle"</span> ya da <span className="text-text font-bold">"Ana ekrana ekle"</span>'yi seç.
            </p>
          )}
        </div>

        <button
          onClick={dismiss}
          aria-label="Kapat"
          className="shrink-0 w-6 h-6 flex items-center justify-center rounded-full text-muted hover:text-text transition-colors"
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden>
            <path d="M2 2l10 10M12 2L2 12" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
          </svg>
        </button>
      </div>
    </div>
  );
}
