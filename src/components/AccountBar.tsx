// Harfik — hesap & sıralama kontrol çubuğu
// Yalnızca Supabase yapılandırıldığında görünür.
import { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { AuthModal } from './AuthModal';
import { Leaderboard } from './Leaderboard';
import { StatsModal } from './StatsModal';

type OpenModal = 'auth' | 'leaderboard' | 'stats' | null;

export function AccountBar() {
  const { user, profile, configured, loading } = useAuth();
  const [open, setOpen] = useState<OpenModal>(null);

  if (!configured) return null;

  const name = profile?.username || profile?.display_name || user?.email || 'Hesabım';
  const btn =
    'font-mono text-[10px] uppercase tracking-[1px] px-3 py-1.5 rounded-md border active:scale-[0.97] transition-transform';

  return (
    <>
      <div className="w-full max-w-[460px] flex items-center justify-between px-3.5 py-1.5 gap-2">
        <button
          onClick={() => setOpen('leaderboard')}
          className={`${btn} bg-panel border-border text-accent`}
        >
          🏆 Sıralama
        </button>

        {loading ? (
          <span className="text-muted text-[10px] font-mono">…</span>
        ) : user ? (
          <button
            onClick={() => setOpen('stats')}
            className={`${btn} bg-panel border-border text-text max-w-[55%] truncate`}
          >
            {name}
          </button>
        ) : (
          <button
            onClick={() => setOpen('auth')}
            className={`${btn} bg-accent border-accent text-[#060A0D] font-bold`}
          >
            Giriş
          </button>
        )}
      </div>

      {open === 'auth' && <AuthModal onClose={() => setOpen(null)} />}
      {open === 'leaderboard' && <Leaderboard onClose={() => setOpen(null)} />}
      {open === 'stats' && <StatsModal onClose={() => setOpen(null)} />}
    </>
  );
}
