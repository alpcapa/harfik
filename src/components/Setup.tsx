// Harfik — oyun kurulum ekranı: oyuncu sayısı (2/4), isimler ve YZ seçimi
import { useState } from 'react';
import { PLAYER_COLORS } from '../game/constants';
import type { PlayerSetup } from '../game/gameReducer';
import { useAuth } from '../hooks/useAuth';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { HelpModal } from './HelpModal';

interface SetupProps {
  onStart: (players: PlayerSetup[]) => void;
}

export function Setup({ onStart }: SetupProps) {
  const { user, profile, loading } = useAuth();
  // Oturum açıldıysa 1. oyuncu her zaman hesap sahibidir.
  const accountName =
    profile?.username ||
    profile?.first_name ||
    (user?.email ? user.email.split('@')[0] : null);

  const [count, setCount] = useState<2 | 4>(2);
  const [names, setNames] = useState<string[]>(['', '', '', '']);
  // 2. oyuncu varsayılan olarak YZ — klasik "YZ'ye karşı" deneyimi.
  const [ai, setAi] = useState<boolean[]>([false, true, false, false]);

  const [showWarningPopup, setShowWarningPopup] = useState(false);
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [showHelp, setShowHelp] = useState(false);

  const setName = (i: number, v: string) =>
    setNames((cur) => cur.map((n, idx) => (idx === i ? v : n)));
  const setAiAt = (i: number, v: boolean) =>
    setAi((cur) => cur.map((a, idx) => (idx === i ? v : a)));

  const doStart = () => {
    const list: PlayerSetup[] = Array.from({ length: count }, (_, i) => {
      // 1. oyuncu giriş yapan kişidir (insan, hesap adıyla).
      if (i === 0 && accountName) {
        return { name: accountName, isAI: false };
      }
      return {
        name: names[i].trim()
          ? names[i].trim()
          : ai[i]
            ? count === 2
              ? 'Yapay Zeka'
              : `Yapay Zeka ${i + 1}`
            : `Oyuncu ${i + 1}`,
        isAI: ai[i],
      };
    });
    onStart(list);
  };

  const handleStart = () => {
    if (!loading && !user) {
      setShowWarningPopup(true);
    } else {
      doStart();
    }
  };

  return (
    <>
    {showAuthModal && <AuthModal onClose={() => setShowAuthModal(false)} />}
    {showHelp && <HelpModal onClose={() => setShowHelp(false)} />}

    {showWarningPopup && (
      <div className="fixed inset-0 z-[200] flex items-center justify-center bg-black/40 px-4">
        <div className="w-full max-w-sm bg-panel rounded-2xl shadow-2xl p-6 flex flex-col gap-4">
          <p className="text-sm text-text font-sans leading-relaxed">
            Giriş yapmadan sadece yapay zeka ile oynayabilirsiniz. Ayrıca, elde ettiğiniz
            puanlar ve istatistikler tutulmaz, lider tablosunda yer almaz.
          </p>
          <div className="flex gap-2 mt-1">
            <button
              onClick={() => { setShowWarningPopup(false); setShowAuthModal(true); }}
              className="flex-1 py-2.5 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
            >
              Giriş Yap
            </button>
            <button
              onClick={() => { setShowWarningPopup(false); doStart(); }}
              className="flex-1 py-2.5 rounded-md border border-border text-muted text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
            >
              Devam
            </button>
          </div>
        </div>
      </div>
    )}

    <div className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-5">
      <div className="text-center flex flex-col items-center gap-1">
        <div style={{ fontFamily: "'Caveat', cursive", fontSize: 52, fontWeight: 700, color: '#2563EB', letterSpacing: 4, lineHeight: 1 }}>
          harfik
        </div>
        <svg width="100" height="8" viewBox="0 0 100 8" fill="none">
          <path d="M4 4 Q25 1 50 4 Q75 7 96 4" stroke="#2563EB" strokeWidth="2.5" strokeLinecap="round" fill="none" />
        </svg>
        <p className="text-muted text-xs font-mono mt-1">
          Her oyuncu kendi köşesinden başlar. 5×5 köşenden çıkmadan
          diğerlerine ulaşamazsın.
        </p>
        <button
          onClick={() => setShowHelp(true)}
          className="mt-1 font-mono text-[10px] uppercase tracking-[1px] text-accent hover:underline active:opacity-70 transition-opacity"
        >
          Nasıl oynanır?
        </button>
      </div>

      <div className="flex flex-col gap-2">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          Oyuncu sayısı
        </div>
        <div className="flex gap-2">
          {([2, 4] as const).map((n) => (
            <button
              key={n}
              onClick={() => {
                setCount(n);
                // Varsayılan: 1. oyuncu sen (kişi), kalan tüm oyuncular YZ.
                setAi(Array.from({ length: 4 }, (_, idx) => idx > 0 && idx < n));
              }}
              className={[
                'flex-1 py-3 rounded-md font-sans text-sm font-bold uppercase tracking-[1px] border transition-transform active:scale-[0.97]',
                count === n
                  ? 'bg-accent text-white border-accent'
                  : 'bg-panel text-text border-border',
              ].join(' ')}
            >
              {n} Kişi
            </button>
          ))}
        </div>
      </div>

      <div className="flex flex-col gap-2.5">
        <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">
          Oyuncular
        </div>
        {Array.from({ length: count }, (_, i) => {
          const col = PLAYER_COLORS[i];
          // 1. oyuncu giriş yapan hesaptır: kilitli isim + avatar, YZ olamaz.
          const isAccount = i === 0 && !!accountName;
          return (
            <div
              key={i}
              className="flex items-center gap-2.5 rounded-md px-2.5 py-2 border"
              style={{ background: col.zone, borderColor: `${col.base}55` }}
            >
              {isAccount ? (
                <Avatar
                  url={profile?.avatar_url}
                  name={accountName}
                  size={20}
                  className="shrink-0"
                />
              ) : (
                <span
                  className="w-4 h-4 rounded-sm shrink-0 flex items-center justify-center text-[9px] font-bold text-white"
                  style={{ background: col.base }}
                >
                  {i + 1}
                </span>
              )}

              {isAccount ? (
                <span className="flex-1 min-w-0 font-sans text-sm font-bold text-text truncate">
                  {accountName}
                </span>
              ) : (
                <input
                  value={names[i]}
                  onChange={(e) => setName(i, e.target.value)}
                  placeholder={
                    ai[i]
                      ? count === 2
                        ? 'Yapay Zeka'
                        : `Yapay Zeka ${i + 1}`
                      : `Oyuncu ${i + 1}`
                  }
                  maxLength={14}
                  className="flex-1 min-w-0 bg-transparent outline-none font-sans text-sm text-text placeholder:text-muted"
                />
              )}

              {isAccount ? (
                <span
                  className="text-[9px] font-mono uppercase tracking-[1px] shrink-0 px-1"
                  style={{ color: col.base }}
                >
                  Sen
                </span>
              ) : (
                /* Kişi / YZ seçimi */
                <div
                  className="flex rounded-md overflow-hidden border shrink-0"
                  style={{ borderColor: `${col.base}55` }}
                >
                  {([false, true] as const).map((v) => (
                    <button
                      key={String(v)}
                      onClick={() => setAiAt(i, v)}
                      className="px-2 py-1 text-[9px] font-mono uppercase tracking-[1px] transition-colors"
                      style={
                        ai[i] === v
                          ? { background: col.base, color: '#fff' }
                          : { background: 'transparent', color: col.base }
                      }
                    >
                      {v ? 'YZ' : 'Kişi'}
                    </button>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {accountName && ai.slice(1, count).every(Boolean) && (
        <p className="text-[11px] font-mono text-muted text-center leading-relaxed px-1">
          Sadece yapay zekaya karşı oynanan oyunların hiçbir kaydı tutulmaz.
        </p>
      )}

      <button
        onClick={handleStart}
        className="py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-accent text-white active:scale-[0.97] transition-transform"
      >
        Oyunu Başlat
      </button>
    </div>
    </>
  );
}
