// Kelimeki — herkese açık paylaşım sayfası: /game/:id
// Girişsiz de erişilebilir (get_shared_game RPC'si), yalnızca kullanıcının
// "Paylaş"a bastığı (shared=true işaretlenmiş) oyunlar görünür.
import { useEffect, useState } from 'react';
import { fetchSharedGame } from '../lib/api';
import type { GamePlayerSnapshot, SharedGameData } from '../lib/database.types';
import { LogoMark } from './LogoMark';
import { GameBoardPreview } from './GameBoardPreview';
import { PlayerBadge } from './PlayerBadge';
import { AiLevelBadge } from './AiLevelBadge';
import { aiLevelForBadge } from '../utils/aiLevel';
import { leaguePoints, formatLeaguePoints, computeRanks } from '../utils/leaguePoints';

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
  const ranks = computeRanks(players);

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
            <div className="flex items-center justify-between gap-2 text-[9px] font-mono text-muted uppercase tracking-[0.5px]">
              <span className="flex items-center gap-1.5 min-w-0">
                <span className="truncate">{formatDateTime(data.created_at)} · {data.player_count} Oyunculu</span>
                {/* Zorluk rozeti — RPC `ai_level` döndürüyor; YZ oyunu (kadroda YZ var) ise her seviyede, Canlı'da yok. */}
                <AiLevelBadge level={aiLevelForBadge(data.ai_level, players.some((p) => p.is_ai))} />
              </span>
              <span className="flex items-center gap-2 shrink-0">
                <span className="w-9 text-right">Puan</span>
                {/* Bkz. GameHistoryModal'daki aynı sütun — "SL" yerine küçük
                    harf "k-lig" (satır `uppercase` olduğundan `normal-case`),
                    w-6→w-8 çünkü 5 karakter 24px'e sığmıyor. */}
                <span className="w-8 text-right normal-case">k-lig</span>
              </span>
            </div>
            <div className="flex flex-col gap-0.5">
              {players.map((p, i) => {
                const points = leaguePoints(ranks[i], data.player_count, p.surrendered, data.ai_level);
                return (
                  <div key={i} className="flex items-center justify-between gap-2 text-[12px] font-mono">
                    <span className="flex items-center gap-1.5 min-w-0">
                      <span className="w-3 text-right text-muted shrink-0">{ranks[i]}.</span>
                      <PlayerBadge index={p.colorIndex ?? i} size={14} />
                      <span className="truncate text-text font-bold">{p.name}</span>
                      {p.surrendered && (
                        <span className="text-[8px] font-bold uppercase tracking-[0.5px] text-red border border-red/40 bg-red/10 rounded px-1 py-[1px] shrink-0">
                          Teslim Oldu
                        </span>
                      )}
                    </span>
                    <span className="flex items-center gap-2 shrink-0">
                      <span className="font-bold w-9 text-right text-gold">{p.score}</span>
                      <span
                        className={`font-bold w-8 text-right ${points > 0 ? 'text-green' : points < 0 ? 'text-red' : 'text-muted'}`}
                      >
                        {formatLeaguePoints(points)}
                      </span>
                    </span>
                  </div>
                );
              })}
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
