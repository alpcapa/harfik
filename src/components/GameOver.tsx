// Harfik — oyun sonu ekranı (çok oyunculu)
import { PLAYER_COLORS } from '../game/constants';
import type { Player } from '../game/types';
import { trUpper } from '../utils/turkish';

interface GameOverProps {
  show: boolean;
  players: Player[];
  turnCount: number;
  onRestart: () => void;
}

export function GameOver({ show, players, turnCount, onRestart }: GameOverProps) {
  if (!show) return null;

  const ranked = players
    .map((p, i) => ({ p, i }))
    .sort((a, b) => b.p.score - a.p.score);
  const top = ranked[0];
  const tie = ranked.length > 1 && ranked[1].p.score === top.p.score;
  const winColor = PLAYER_COLORS[top.p.colorIndex];

  return (
    <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center gap-[18px] p-6 bg-[rgba(255,255,255,0.94)]">
      <div
        className="font-mono text-[30px] font-bold tracking-[2px] text-center"
        style={{ color: tie ? '#B7791F' : winColor.base }}
      >
        {tie ? 'BERABERE' : `${trUpper(top.p.name)} KAZANDI`}
      </div>

      <div className="bg-panel border border-border rounded-[10px] px-7 py-5 text-center flex flex-col gap-2.5 min-w-[240px]">
        {ranked.map(({ p, i }, rank) => {
          const col = PLAYER_COLORS[p.colorIndex];
          return (
            <div key={i} className="flex justify-between items-center gap-8 text-[15px]">
              <span className="flex items-center gap-2">
                <span
                  className="w-3 h-3 rounded-sm"
                  style={{ background: col.base }}
                />
                <span className="text-text">
                  {rank + 1}. {p.name}
                </span>
              </span>
              <span
                className="font-mono text-[22px] font-bold"
                style={{ color: col.base }}
              >
                {p.score}
              </span>
            </div>
          );
        })}
        <div className="flex justify-between gap-8 text-[12px] border-t border-border pt-2 mt-1">
          <span className="text-muted">Toplam hamle</span>
          <span className="font-mono font-bold text-muted">{turnCount}</span>
        </div>
      </div>

      <button
        onClick={onRestart}
        className="bg-accent text-white rounded-lg px-9 py-3.5 text-[13px] font-bold tracking-[2px] uppercase font-sans active:scale-95 transition-transform"
      >
        Yeni Oyun
      </button>
    </div>
  );
}
