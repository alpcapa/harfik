// Harfik — sağ üst köşedeki hesap menüsü.
// Oturum yoksa "Giriş / Kayıt" düğmesi; oturum varsa profil küçük resmi ve
// açılır menü (Hesap Ayarları, Skor Kartı, Sıralama, Çıkış) gösterir.
// Yalnızca Supabase yapılandırıldığında görünür.
import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { signOut } from '../lib/api';
import { Avatar } from './Avatar';
import { AuthModal } from './AuthModal';
import { ScoreCard } from './ScoreCard';
import { AccountSettingsModal } from './AccountSettingsModal';
import { Leaderboard } from './Leaderboard';

type ActiveModal = 'auth' | 'account' | 'score' | 'leaderboard' | null;

export function UserMenu() {
  const { user, profile, configured, loading } = useAuth();
  const [open, setOpen] = useState(false);
  const [modal, setModal] = useState<ActiveModal>(null);
  const wrapRef = useRef<HTMLDivElement>(null);

  // Dışarı tıklayınca / Esc ile menüyü kapat.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node))
        setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  if (!configured) return null;

  const name =
    profile?.username || profile?.display_name || user?.email || 'Hesabım';

  // ── Oturum yok: Giriş / Kayıt düğmesi ──────────────────────────────────────
  if (!loading && !user) {
    return (
      <>
        <button
          onClick={() => setModal('auth')}
          className="font-mono text-[10px] uppercase tracking-[1px] px-3 py-1.5 rounded-md border bg-accent border-accent text-white font-bold active:scale-[0.97] transition-transform"
        >
          Giriş / Kayıt
        </button>
        {modal === 'auth' && <AuthModal onClose={() => setModal(null)} />}
      </>
    );
  }

  const item =
    'w-full flex items-center gap-2.5 px-3 py-2.5 text-left text-xs font-mono text-text hover:bg-bg transition-colors';

  return (
    <>
      <div className="relative" ref={wrapRef}>
        <button
          onClick={() => setOpen((v) => !v)}
          aria-label="Hesap menüsü"
          aria-expanded={open}
          className="rounded-full active:scale-95 transition-transform ring-offset-2 focus:outline-none"
        >
          {loading ? (
            <span className="w-8 h-8 rounded-full bg-panel border border-border flex items-center justify-center text-muted text-[10px] font-mono">
              …
            </span>
          ) : (
            <Avatar url={profile?.avatar_url} name={name} size={32} />
          )}
        </button>

        {open && (
          <div className="absolute right-0 top-full mt-2 w-56 bg-panel border border-border rounded-xl shadow-lg overflow-hidden z-[160]">
            <div className="flex items-center gap-2.5 px-3 py-3 border-b border-border">
              <Avatar url={profile?.avatar_url} name={name} size={36} />
              <div className="min-w-0">
                <div className="text-sm font-bold text-text truncate">{name}</div>
                {user?.email && (
                  <div className="text-[10px] text-muted font-mono truncate">
                    {user.email}
                  </div>
                )}
              </div>
            </div>

            <button
              className={item}
              onClick={() => {
                setModal('account');
                setOpen(false);
              }}
            >
              <span aria-hidden>⚙️</span> Hesap Ayarları
            </button>
            <button
              className={item}
              onClick={() => {
                setModal('score');
                setOpen(false);
              }}
            >
              <span aria-hidden>📊</span> Skor Kartı
            </button>
            <button
              className={item}
              onClick={() => {
                setModal('leaderboard');
                setOpen(false);
              }}
            >
              <span aria-hidden>🏆</span> Sıralama
            </button>

            <button
              className={`${item} border-t border-border hover:text-red`}
              onClick={async () => {
                setOpen(false);
                await signOut();
              }}
            >
              <span aria-hidden>↩</span> Çıkış Yap
            </button>
          </div>
        )}
      </div>

      {modal === 'account' && (
        <AccountSettingsModal onClose={() => setModal(null)} />
      )}
      {modal === 'score' && (
        <ScoreCard
          onClose={() => setModal(null)}
          onLeaderboard={() => setModal('leaderboard')}
        />
      )}
      {modal === 'leaderboard' && (
        <Leaderboard onClose={() => setModal(null)} />
      )}
    </>
  );
}
