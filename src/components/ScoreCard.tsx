// Harfik — skor kartı: oyuncu istatistikleri ve sıralamaya geçiş
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { fetchPlayerStats } from '../lib/api';
import type { PlayerStats } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';

interface ScoreCardProps {
  onClose: () => void;
  /** Sıralama tablosunu açar. */
  onLeaderboard: () => void;
}

export function ScoreCard({ onClose, onLeaderboard }: ScoreCardProps) {
  const { user, profile } = useAuth();
  const [stats, setStats] = useState<PlayerStats | null | undefined>(undefined);

  useEffect(() => {
    fetchPlayerStats().then(setStats);
  }, []);

  const name =
    profile?.display_name || profile?.first_name || user?.email || 'Oyuncu';

  const winRatio =
    stats && stats.games_played > 0
      ? `%${Math.round((stats.wins / stats.games_played) * 100)}`
      : '%0';

  const cells: { label: string; value: number | string; cls?: string }[] = stats
    ? [
        { label: 'Toplam Oyun', value: stats.games_played },
        { label: 'Galibiyet', value: stats.wins, cls: 'text-green' },
        { label: 'Mağlubiyet', value: stats.losses, cls: 'text-red' },
        { label: 'Kazanma Oranı', value: winRatio, cls: 'text-accent' },
        { label: 'En Yüksek', value: stats.best_score, cls: 'text-gold' },
        { label: 'Beraberlik', value: stats.ties, cls: 'text-muted' },
      ]
    : [];

  return (
    <Modal title="Skor Kartı" onClose={onClose}>
      <div className="mb-4 flex items-center gap-3">
        <Avatar url={profile?.photo_url} name={name} size={44} />
        <div className="min-w-0">
          <div className="text-base font-bold text-text truncate">{name}</div>
          {user?.email && (
            <div className="text-xs text-muted font-mono truncate">{user.email}</div>
          )}
        </div>
      </div>

      {stats === undefined ? (
        <p className="text-muted text-xs font-mono text-center py-4">Yükleniyor…</p>
      ) : !stats ? (
        <p className="text-muted text-xs font-mono text-center py-4">
          Henüz oyun kaydın yok. Bir oyun bitir!
        </p>
      ) : (
        <div className="grid grid-cols-3 gap-2">
          {cells.map((c) => (
            <div
              key={c.label}
              className="bg-bg border border-border rounded-md py-3 px-1 text-center"
            >
              <div className={`font-mono text-xl font-bold ${c.cls ?? 'text-text'}`}>
                {c.value}
              </div>
              <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono mt-0.5">
                {c.label}
              </div>
            </div>
          ))}
        </div>
      )}

      <button
        onClick={onLeaderboard}
        className="mt-5 w-full bg-accent text-white rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform"
      >
        🏆 Sıralamayı Gör
      </button>
    </Modal>
  );
}
