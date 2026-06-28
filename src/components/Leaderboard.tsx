// Harfik — liderlik tablosu
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { fetchLeaderboard } from '../lib/api';
import type { LeaderboardRow } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';

interface LeaderboardProps {
  onClose: () => void;
}

export function Leaderboard({ onClose }: LeaderboardProps) {
  const { user } = useAuth();
  const [rows, setRows] = useState<LeaderboardRow[] | null>(null);

  useEffect(() => {
    fetchLeaderboard(20).then(setRows);
  }, []);

  return (
    <Modal title="🏆 Sıralama" onClose={onClose}>
      {rows === null ? (
        <p className="text-muted text-xs font-mono text-center py-6">Yükleniyor…</p>
      ) : rows.length === 0 ? (
        <p className="text-muted text-xs font-mono text-center py-6">
          Henüz skor yok. İlk sen ol!
        </p>
      ) : (
        <ol className="flex flex-col gap-1">
          <li className="flex items-center text-[9px] uppercase tracking-[1px] text-muted font-mono px-2 pb-1">
            <span className="w-6">#</span>
            <span className="flex-1">Oyuncu</span>
            <span className="w-10 text-right">Galibiyet</span>
            <span className="w-12 text-right">En İyi</span>
          </li>
          {rows.map((r, i) => {
            const me = user && r.user_id === user.id;
            const name = r.username || r.display_name || 'Anonim';
            return (
              <li
                key={r.user_id}
                className={[
                  'flex items-center text-sm font-mono rounded-md px-2 py-1.5',
                  me ? 'bg-accent/10 border border-accent' : 'bg-bg',
                ].join(' ')}
              >
                <span
                  className={[
                    'w-6 font-bold',
                    i === 0 ? 'text-gold' : i < 3 ? 'text-accent' : 'text-muted',
                  ].join(' ')}
                >
                  {i + 1}
                </span>
                <Avatar
                  url={r.avatar_url}
                  name={name}
                  size={22}
                  className="mr-2 shrink-0"
                />
                <span className="flex-1 truncate text-text">{name}</span>
                <span className="w-10 text-right text-muted">{r.wins}</span>
                <span className="w-12 text-right font-bold text-accent">
                  {r.best_score}
                </span>
              </li>
            );
          })}
        </ol>
      )}
    </Modal>
  );
}
