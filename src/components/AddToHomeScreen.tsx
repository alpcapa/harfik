import { useEffect, useState } from 'react';

const DISMISSED_KEY = 'harfik_a2hs_dismissed_session';

function isStandalone() {
  return (
    ('standalone' in navigator && (navigator as { standalone?: boolean }).standalone === true) ||
    window.matchMedia('(display-mode: standalone)').matches
  );
}

export function AddToHomeScreen() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (isStandalone()) return;
    if (sessionStorage.getItem(DISMISSED_KEY)) return;
    // Short delay so the banner doesn't flash on first paint.
    const t = setTimeout(() => setVisible(true), 1200);
    return () => clearTimeout(t);
  }, []);

  const dismiss = () => {
    setVisible(false);
    sessionStorage.setItem(DISMISSED_KEY, '1');
  };

  if (!visible) return null;

  return (
    <div
      className="fixed bottom-0 left-0 right-0 z-[300] flex justify-center px-3 pb-4 animate-slide-up"
      style={{ animation: 'slideUp 0.35s cubic-bezier(0.16,1,0.3,1) both' }}
    >
      <style>{`
        @keyframes slideUp {
          from { transform: translateY(110%); opacity: 0; }
          to   { transform: translateY(0);    opacity: 1; }
        }
      `}</style>
      <div className="w-full max-w-[460px] bg-panel border border-border rounded-2xl shadow-2xl px-4 py-3.5 flex items-center gap-3">
        {/* iOS share icon */}
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
          <p className="text-[10px] text-muted font-mono leading-relaxed mt-0.5">
            Paylaş{' '}
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none" className="inline-block align-middle -mt-0.5" aria-hidden>
              <path d="M5 1v6M3 3l2-2 2 2M1 6v3h8V6" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            {' '}düğmesine dokun, ardından{' '}
            <span className="text-text font-bold">"Ana Ekrana Ekle"</span>'yi seç.
          </p>
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
