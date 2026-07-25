import { useEffect, useState } from 'react';

const DISMISSED_KEY = 'kelimeki_landscape_hint_dismissed';

/**
 * iPad'de trackpad'li bir klavye kılıfı takılıyken bile iPadOS `pointer`/
 * `any-pointer` media feature'larını güvenilmez şekilde raporluyor (bkz.
 * WebKit bug 212580/209292) — bu yüzden "gerçekten dokunmatik-only mu"
 * sorusunu CSS/JS'le kesin olarak çözmeye çalışmıyoruz. Bunun yerine
 * dokunmatik cihazlarda (pointer: coarse — trackpad'li iPad'lerde de
 * kasıtlı olarak coarse raporlanır) yatay modda kapatılabilir, App'in
 * kendisini hiç gizlemeyen düşük riskli bir öneri banner'ı gösteriyoruz;
 * trackpad kullanan biri bunu bir kez kapatır, dokunmatik-only kullanan
 * biri dikeye geçebilir. Önceden burada #root'u tamamen gizleyen sert bir
 * blok vardı (index.html/index.css'teki #landscape-block) — iPad'de
 * yanlış tetiklenmesi (trackpad varken de bloke etmesi) üzerine kaldırıldı.
 */
export function LandscapeHint() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (sessionStorage.getItem(DISMISSED_KEY)) return;
    const coarse = window.matchMedia('(pointer: coarse)');
    const landscape = window.matchMedia('(orientation: landscape)');
    const update = () => {
      setVisible(coarse.matches && landscape.matches && !sessionStorage.getItem(DISMISSED_KEY));
    };
    update();
    coarse.addEventListener('change', update);
    landscape.addEventListener('change', update);
    return () => {
      coarse.removeEventListener('change', update);
      landscape.removeEventListener('change', update);
    };
  }, []);

  const dismiss = () => {
    setVisible(false);
    sessionStorage.setItem(DISMISSED_KEY, '1');
  };

  if (!visible) return null;

  return (
    <div className="fixed top-0 left-0 right-0 z-[60] flex justify-center px-3 pt-3">
      <div className="w-full max-w-[460px] bg-panel border border-[#B8C2D1] rounded-2xl shadow-[0_12px_30px_rgba(15,23,42,0.35)] px-4 py-3 flex items-center gap-3">
        <svg width="24" height="24" viewBox="0 0 48 48" fill="none" className="shrink-0 text-accent" aria-hidden>
          <rect x="6" y="12" width="24" height="36" rx="4" stroke="currentColor" strokeWidth="2.5" fill="none" />
          <path d="M36 8 Q44 16 36 24" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" fill="none" />
          <polyline points="33,20 36,24 40,21" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" fill="none" />
        </svg>

        <p className="flex-1 min-w-0 text-xs font-bold text-text font-sans leading-snug">
          Dikey konumda daha iyi bir deneyim yaşarsınız
        </p>

        <button
          onClick={dismiss}
          aria-label="Kapat"
          className="shrink-0 w-6 h-6 flex items-center justify-center rounded-full text-muted hover:text-text transition-colors"
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden>
            <path d="M2 2l10 10M12 2L2 12" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
        </button>
      </div>
    </div>
  );
}
