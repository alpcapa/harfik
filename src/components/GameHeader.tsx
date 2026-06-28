// Harfik — başlık: skorlar, torba ve hesap menüsü
import { useState } from 'react';
import { PLAYER_COLORS } from '../game/constants';
import type { GameState } from '../game/types';
import { UserMenu } from './UserMenu';
import { RemainingTilesModal } from './RemainingTilesModal';

interface GameHeaderProps {
  state: GameState;
}

export function GameHeader({ state }: GameHeaderProps) {
  const { players, current } = state;
  const bagCount = state.bag.length;
  const [showTiles, setShowTiles] = useState(false);
  return (
    <header className="w-full max-w-[680px] flex items-center justify-between gap-2 px-3 py-2.5 border-b border-border">
      <div className="font-mono text-lg font-bold text-accent tracking-[2px] shrink-0">
        HARFİK
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

        <button
          onClick={() => setShowTiles(true)}
          aria-label="Kalan taşlar"
          className="text-center px-1.5 py-0.5 rounded-md hover:bg-bg active:scale-95 transition-all"
        >
          <div className="text-[8px] uppercase tracking-[1px] text-muted font-mono">
            Torba
          </div>
          <div className="font-mono text-sm font-bold leading-none text-muted">
            {bagCount}
          </div>
        </button>

        <UserMenu />
      </div>

      {showTiles && (
        <RemainingTilesModal state={state} onClose={() => setShowTiles(false)} />
      )}
    </header>
  );
}
