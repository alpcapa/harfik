// Kelimeki — herkese açık paylaşım sayfası: /game/:id
// Girişsiz de erişilebilir (get_shared_game RPC'si), yalnızca kullanıcının
// "Paylaş"a bastığı (shared=true işaretlenmiş) oyunlar görünür.
import { useEffect, useState } from 'react';
import { fetchSharedGame } from '../lib/api';
import type { GamePlayerSnapshot, SharedGameData } from '../lib/database.types';
import { LogoMark } from './LogoMark';
import { GameBoardPreview } from './GameBoardPreview';
import { PlayerBadge } from './PlayerBadge';

interface SharedGamePageProps {
  gameId: string;
}

function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return `${d.toLocaleDateString('tr-TR')} · ${d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })}`;
}

export function SharedGamePage({ gameId }: SharedGamePageProps) {
  const [data, setData] = useState<SharedGameData | null | undefined>(undefined);

  useEffect(() => {
    let cancelled = false;
    void fetchSharedGame(gameId).then((result) => {
      if (!cancelled) setData(result);
    });
    return () => {
      cancelled = true;
    };
  }, [gameId]);

  const players: GamePlayerSnapshot[] = data?.players ?? [];

  return (
    <div className="min-h-screen bg-panel flex flex-col items-center px-4 py-8 gap-6">
      <a href="/" aria-label="Kelimeki anasayfa">
        <LogoMark height={44} />
      </a>

      {data === undefined ? (
        <p className="text-muted text-xs font-mono">Yükleniyor…</p>
      ) : data === null ? (
        <p className="text-muted text-xs font-mono text-center max-w-[320px]">
          Bu oyun bulunamadı ya da artık paylaşılmıyor.
        </p>
      ) : (
        <div className="w-full max-w-[400px] flex flex-col gap-3">
          <div className="shadow-raised bg-bg border border-border rounded-md py-2 px-2.5 flex flex-col gap-1.5">
            <div className="text-[9px] font-mono text-muted uppercase tracking-[0.5px]">
              {formatDateTime(data.created_at)} · {data.player_count} Oyunculu
            </div>
            <div className="flex flex-col gap-0.5">
              {players.map((p, i) => (
                <div key={i} className="flex items-center justify-between gap-2 text-[12px] font-mono">
                  <span className="flex items-center gap-1.5 min-w-0">
                    <span className="w-3 text-right text-muted shrink-0">{i + 1}.</span>
                    <PlayerBadge index={p.colorIndex ?? i} size={14} />
                    <span className="truncate text-text font-bold">{p.name}</span>
                  </span>
                  <span className="font-bold text-gold">{p.score}</span>
                </div>
              ))}
            </div>
          </div>

          {data.board_snapshot && (
            <GameBoardPreview
              snapshot={data.board_snapshot}
              playerCount={data.player_count}
              players={players}
            />
          )}
        </div>
      )}

      <a
        href="/"
        className="mt-2 px-6 py-3 rounded-md bg-accent text-white font-mono font-bold text-sm tracking-[0.5px] shadow-raised active:scale-95 transition-transform"
      >
        Sen de Kelimeki Oyna
      </a>
    </div>
  );
}
