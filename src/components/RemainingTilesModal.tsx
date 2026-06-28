// Harfik — kalan (dışarıdaki) taşlar dökümü
import { Modal } from './Modal';
import { remainingTiles } from '../utils/bag';
import type { GameState } from '../game/types';

interface RemainingTilesModalProps {
  state: GameState;
  onClose: () => void;
}

export function RemainingTilesModal({ state, onClose }: RemainingTilesModalProps) {
  const myRack = state.players[state.current]?.rack ?? [];
  const rows = remainingTiles(state.board, myRack);
  const total = rows.reduce((s, r) => s + r.count, 0);

  return (
    <Modal title="Kalan Taşlar" onClose={onClose}>
      <p className="text-[10px] font-mono text-muted mb-3 leading-relaxed">
        Tahtada olmayan ve sende bulunmayan taşlar (torba + rakipler).
        Toplam <span className="font-bold text-accent">{total}</span> taş dışarıda.
      </p>

      <div className="grid grid-cols-5 gap-1.5">
        {rows.map((r) => {
          const out = r.count === 0;
          const display = r.letter === '?' ? '★' : r.letter;
          return (
            <div
              key={r.letter}
              className={[
                'relative flex items-center justify-center rounded border bg-tile-bg border-tile-border h-12',
                out ? 'opacity-30' : '',
              ].join(' ')}
            >
              <span
                style={{ WebkitTextStrokeWidth: '0.5px' }}
                className="font-mono font-bold text-[19px] text-tile-letter [-webkit-text-stroke-color:currentColor] leading-none"
              >
                {display}
              </span>
              {/* Puan — sağ üstte mavi üst simge (taşlardaki gibi). */}
              <span className="absolute top-[2px] right-[3px] font-mono font-bold text-[8px] text-accent leading-none">
                {r.pts}
              </span>
              {/* Kalan adet — sağ altta. */}
              <span className="absolute bottom-[2px] right-[3px] font-mono font-bold text-[10px] text-muted leading-none">
                ×{r.count}
              </span>
            </div>
          );
        })}
      </div>
    </Modal>
  );
}
