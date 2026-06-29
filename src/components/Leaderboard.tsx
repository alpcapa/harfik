// Harfik — liderlik tablosu
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { Avatar } from './Avatar';
import { fetchLeaderboard, fetchMyLeaderboardRank } from '../lib/api';
import type { LeaderboardRow, MyLeaderboardRank } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';

interface LeaderboardProps {
  onClose: () => void;
}

export function Leaderboard({ onClose }: LeaderboardProps) {
  const { user } = useAuth();
  const [rows, setRows] = useState<LeaderboardRow[] | null>(null);
  const [myRank, setMyRank] = useState<MyLeaderboardRank | null>(null);

  useEffect(() => {
    fetchLeaderboard(10).then(setRows);
  }, []);

  useEffect(() => {
    if (!user) return;
    fetchMyLeaderboardRank(user.id).then(setMyRank);
  }, [user]);

  // Giriş yapmış kullanıcı ilk 10'da mı?
  const meInTop = user && rows ? rows.some((r) => r.user_id === user.id) : false;

  return (
    <Modal title="🏆 Sıralama" onClose={onClose}>
      {rows === null ? (
        <p className="text-muted text-xs font-mono text-center py-6">Yükleniyor…</p>
      ) : (
        <div className="flex flex-col gap-2">
          <ol className="flex flex-col gap-1">
            <li className="flex items-center text-[9px] uppercase tracking-[1px] text-muted font-mono px-2 pb-1">
              <span className="w-6">#</span>
              <span className="flex-1">Oyuncu</span>
              <span className="w-14 text-right">Toplam</span>
              <span className="w-10 text-right">Galibiyet</span>
            </li>
            {rows.length === 0 ? (
              <li className="text-muted text-xs font-mono text-center py-4">
                Henüz skor yok. İlk sen ol!
              </li>
            ) : (
              rows.map((r, i) => {
                const me = user && r.user_id === user.id;
                const name =
                  r.username ||
                  [r.first_name, r.last_name].filter(Boolean).join(' ').trim() ||
                  'Anonim';
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
                    <span className="w-14 text-right font-bold text-accent">
                      {r.total_score?.toLocaleString('tr-TR') ?? '—'}
                    </span>
                    <span className="w-10 text-right text-muted">{r.wins}</span>
                  </li>
                );
              })
            )}
          </ol>

          {user && !meInTop && myRank && (
            <>
              <div className="flex items-center gap-2 px-2">
                <div className="flex-1 border-t border-dashed border-border" />
                <span className="text-[9px] text-muted font-mono uppercase tracking-[1px]">senin sıran</span>
                <div className="flex-1 border-t border-dashed border-border" />
              </div>
              <div className="flex items-center text-sm font-mono rounded-md px-2 py-1.5 bg-accent/10 border border-accent">
                <span className="w-6 font-bold text-muted">{myRank.rank}</span>
                <span className="flex-1 text-text">Sen</span>
                <span className="w-14 text-right font-bold text-accent">
                  {myRank.total_score.toLocaleString('tr-TR')}
                </span>
                <span className="w-10 text-right text-muted">—</span>
              </div>
            </>
          )}
        </div>
      )}
    </Modal>
  );
}
