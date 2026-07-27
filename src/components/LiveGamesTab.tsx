// Kelimeki — Canlı sekmesi: davet bekleyen/rakip bekleyen/aktif Canlı
// oyunların listesi (Faz 2 iskeleti — kurulum/davet gönderme henüz yok,
// bkz. src/App.tsx'teki mainView tab'ı).
import { useEffect, useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { listMyOnlineGames } from '../lib/api';
import type { OnlineGame } from '../lib/database.types';
import { AuthModal } from './AuthModal';

function statusLabel(game: OnlineGame): string {
  if (game.my_role === 'invitee' && game.my_invite_status === 'pending') return 'Davet bekliyor';
  if (game.status === 'active') return 'Aktif — oynanış yakında';
  if (game.status === 'pending') return 'Rakip bekleniyor';
  if (game.status === 'finished') return 'Bitti';
  return 'Terk edildi';
}

function GameRow({ game }: { game: OnlineGame }) {
  return (
    <div className="shadow-raised flex items-center gap-2.5 rounded-md px-2.5 py-2 border border-border bg-panel">
      <span className="flex-1 min-w-0 font-sans text-sm font-bold text-text truncate">
        {game.player_count} Kişilik Canlı Oyun
      </span>
      <span className="text-[9px] font-mono uppercase tracking-[1px] text-muted shrink-0">
        {statusLabel(game)}
      </span>
    </div>
  );
}

function Section({ title, games }: { title: string; games: OnlineGame[] }) {
  if (games.length === 0) return null;
  return (
    <div className="flex flex-col gap-2">
      <div className="text-[10px] uppercase tracking-[1.5px] text-muted font-mono">{title}</div>
      <div className="flex flex-col gap-2">
        {games.map((g) => (
          <GameRow key={g.id} game={g} />
        ))}
      </div>
    </div>
  );
}

export function LiveGamesTab() {
  const { user, loading: authLoading } = useAuth();
  // null = henüz çekilmedi (yükleniyor), [] = çekildi ama hiç oyun yok.
  const [games, setGames] = useState<OnlineGame[] | null>(null);
  const [showAuthModal, setShowAuthModal] = useState(false);

  useEffect(() => {
    if (!user) {
      setGames(null);
      return;
    }
    let cancelled = false;
    listMyOnlineGames().then((rows) => {
      if (!cancelled) setGames(rows);
    });
    return () => {
      cancelled = true;
    };
  }, [user]);

  if (authLoading) return null;

  if (!user) {
    return (
      <>
        {showAuthModal && <AuthModal onClose={() => setShowAuthModal(false)} />}
        <div className="w-full max-w-[460px] px-4 py-10 flex flex-col items-center gap-4 text-center">
          <p className="text-sm text-muted font-sans">
            Canlı oyun oynamak (arkadaşlarınla davet/kabul ile) için giriş yapmalısın.
          </p>
          <button
            onClick={() => setShowAuthModal(true)}
            className="btn-raised py-2.5 px-6 rounded-md bg-accent text-white text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
          >
            Giriş Yap
          </button>
        </div>
      </>
    );
  }

  const invites = (games ?? []).filter((g) => g.my_role === 'invitee' && g.my_invite_status === 'pending');
  const active = (games ?? []).filter((g) => g.status === 'active');
  const waiting = (games ?? []).filter((g) => g.my_role === 'creator' && g.status === 'pending');

  return (
    <div className="w-full max-w-[460px] px-4 py-6 flex flex-col gap-5">
      <button
        disabled
        title="Yakında"
        className="btn-raised py-3.5 rounded-md font-sans text-sm font-bold uppercase tracking-[2px] bg-accent text-white opacity-35 cursor-not-allowed"
      >
        + Yeni Canlı Oyun
      </button>

      {games === null ? (
        <p className="text-center text-xs text-muted font-mono py-8">Yükleniyor…</p>
      ) : games.length === 0 ? (
        <p className="text-center text-xs text-muted font-mono py-8">
          Henüz bir Canlı oyunun yok.
        </p>
      ) : (
        <>
          <Section title="Davet Bekliyor" games={invites} />
          <Section title="Aktif" games={active} />
          <Section title="Rakip Bekleniyor" games={waiting} />
        </>
      )}
    </div>
  );
}
