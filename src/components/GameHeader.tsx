// Harfik — başlık: skorlar, torba ve sıralama düğmesi
import { PLAYER_COLORS } from '../game/constants';
import type { Player } from '../game/types';

interface GameHeaderProps {
  players: Player[];
  current: number;
  bagCount: number;
  /** Sıralama tablosu açılabilir mi? (Supabase yapılandırılmışsa) */
  showLeaderboard: boolean;
  onLeaderboard: () => void;
}

export function GameHeader({
  players,
  current,
  bagCount,
  showLeaderboard,
  onLeaderboard,
}: GameHeaderProps) {
  return (
    <header className="w-full max-w-[460px] flex items-center justify-between gap-2 px-3 py-2.5 border-b border-border">
      <div className="font-mono text-lg font-bold text-accent tracking-[2px] shrink-0">
        HARFİK
      </div>

      <div className="flex gap-2 items-center flex-wrap justify-end">
        {players.map((p, i) => {
          const col = PLAYER_COLORS[p.colorIndex];
          const active = i === current;
          return (
            <div
              key={i}
              className="text-center rounded-md px-2 py-0.5 transition-all"
              style={{
                background: active ? col.tint : 'transparent',
                boxShadow: active ? `inset 0 0 0 1.5px ${col.base}` : 'none',
              }}
            >
              <div
                className="text-[8px] uppercase tracking-[1px] font-mono truncate max-w-[72px]"
                style={{ color: col.base }}
              >
                {p.name}
              </div>
              <div
                className="font-mono text-lg font-bold leading-none"
                style={{ color: col.base }}
              >
                {p.score}
              </div>
            </div>
          );
        })}

        <div className="text-center px-1">
          <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono">
            Torba
          </div>
          <div className="font-mono text-sm font-bold leading-none text-muted">
            {bagCount}
          </div>
        </div>

        {showLeaderboard && (
          <button
            onClick={onLeaderboard}
            title="Sıralama"
            className="font-mono text-base px-2 py-1.5 rounded-md border border-border bg-panel active:scale-95 transition-transform"
          >
            🏆
          </button>
        )}
      </div>
    </header>
  );
}
