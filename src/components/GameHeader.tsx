// Harfik — başlık: skorlar ve hesap menüsü
import { PLAYER_COLORS } from '../game/constants';
import type { GameState } from '../game/types';
import { UserMenu } from './UserMenu';

interface GameHeaderProps {
  state: GameState;
}

export function GameHeader({ state }: GameHeaderProps) {
  const { players, current } = state;
  return (
    <header className="w-full max-w-[680px] flex items-center justify-between gap-2 px-3 py-2.5 border-b border-border">
      <div className="shrink-0 flex flex-col items-center leading-none" style={{ fontFamily: "'Caveat', cursive", fontSize: 28, fontWeight: 700, color: '#2563EB', letterSpacing: 3 }}>
        harfik
        <svg width="64" height="6" viewBox="0 0 64 6" fill="none">
          <path d="M2 3 Q16 1 32 3 Q48 5 62 3" stroke="#2563EB" strokeWidth="2" strokeLinecap="round" fill="none" />
        </svg>
      </div>

      <div className="flex gap-2 items-center flex-wrap justify-end">
        {players.map((p, i) => {
          const col = PLAYER_COLORS[p.colorIndex];
          const active = i === current;
          // Başlıkta dar alan için YZ oyuncusu kısaca "YZ" (4 kişilikse "YZ 2").
          const label = p.isAI
            ? players.length === 2
              ? 'YZ'
              : `YZ ${i + 1}`
            : p.name;
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
                {label}
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

        <UserMenu />
      </div>
    </header>
  );
}
