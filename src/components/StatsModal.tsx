// Harfik — profil & istatistik
import { useEffect, useState } from 'react';
import { Modal } from './Modal';
import { fetchPlayerStats, signOut } from '../lib/api';
import type { PlayerStats } from '../lib/database.types';
import { useAuth } from '../hooks/useAuth';

interface StatsModalProps {
  onClose: () => void;
}

export function StatsModal({ onClose }: StatsModalProps) {
  const { user, profile } = useAuth();
  const [stats, setStats] = useState<PlayerStats | null | undefined>(undefined);

  useEffect(() => {
    fetchPlayerStats().then(setStats);
  }, []);

  const name = profile?.username || profile?.display_name || user?.email || 'Oyuncu';

  const cells: { label: string; value: number | string; cls?: string }[] = stats
    ? [
        { label: 'Oyun', value: stats.games_played },
        { label: 'Galibiyet', value: stats.wins, cls: 'text-green' },
        { label: 'Mağlubiyet', value: stats.losses, cls: 'text-red' },
        { label: 'Berabere', value: stats.ties, cls: 'text-gold' },
        { label: 'En İyi Skor', value: stats.best_score, cls: 'text-accent' },
        { label: 'Ortalama', value: stats.avg_score },
      ]
    : [];

  return (
    <Modal title="Profil" onClose={onClose}>
      <div className="mb-4">
        <div className="text-base font-bold text-text">{name}</div>
        {user?.email && (
          <div className="text-xs text-muted font-mono">{user.email}</div>
        )}
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
              className="bg-bg border border-border rounded-md py-3 text-center"
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
        onClick={async () => {
          await signOut();
          onClose();
        }}
        className="mt-5 w-full bg-panel border border-border text-muted rounded-md py-2.5 text-xs font-bold uppercase tracking-[1.5px] active:scale-[0.97] transition-transform hover:text-red"
      >
        Çıkış Yap
      </button>
    </Modal>
  );
}
