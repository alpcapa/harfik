// Kelimeki — kalan (dışarıdaki) taşlar dökümü
import { Modal } from './Modal';
import { remainingTiles } from '../utils/bag';
import type { GameState } from '../game/types';
import { Tile } from './Tile';

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
          return (
            <div key={r.letter} className={['relative h-12', out ? 'opacity-30' : ''].join(' ')}>
              <Tile tile={{ letter: r.letter, pts: r.pts }} variant="rack" />
              {/* Kalan adet — taşın içinde, harfin tam altında (puan rozeti
                  sağ üstte olduğundan çakışmıyor). */}
              <span className="absolute bottom-[3px] left-1/2 -translate-x-1/2 font-mono font-bold text-[10px] text-[#8B5E00] leading-none">
                ×{r.count}
              </span>
            </div>
          );
        })}
      </div>
    </Modal>
  );
}
