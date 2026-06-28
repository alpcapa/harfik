// Harfik — 13x13 oyun tahtası
import { BONUS_LABELS, SIZE, aiZone, playerZone } from '../game/constants';
import type { GameState } from '../game/types';
import { key } from '../utils/board';
import { Tile } from './Tile';

interface BoardProps {
  state: GameState;
  onCellClick: (r: number, c: number) => void;
}

const BONUS_CLASSES: Record<string, string> = {
  dw: 'bg-[#1A3A1A] text-[#40C840] border-[#1A4A1A]',
  tw: 'bg-[#3A1A00] text-[#FF8000] border-[#5A2A00]',
  dl: 'bg-[#001A3A] text-[#40A0FF] border-[#003A7A]',
  tl: 'bg-[#1A0030] text-[#C040FF] border-[#4A0080]',
};

export function Board({ state, onCellClick }: BoardProps) {
  const { board, placed, bonuses, cellState } = state;
  const cells = [];

  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const k = key(r, c);
      const boardTile = board[r][c];
      const placedTile = placed[k];
      const st = cellState[k];
      const bonus = bonuses[k];

      let content: React.ReactNode = null;
      const classes = [
        'aspect-square rounded-[2px] flex items-center justify-center',
        'font-mono font-bold text-[clamp(5px,1.4vw,8px)] select-none',
        'transition-[background,opacity] duration-300 border',
      ];

      if (st === 'void') {
        classes.push('bg-void border-[#080808] opacity-30 cursor-not-allowed');
      } else if (boardTile) {
        classes.push('bg-transparent border-transparent cursor-default');
        content = (
          <Tile tile={boardTile} variant={boardTile.owner === 'ai' ? 'ai' : 'player'} />
        );
      } else if (placedTile) {
        classes.push('bg-transparent border-transparent');
        content = <Tile tile={placedTile} variant="placed" />;
      } else if (st === 'crack') {
        classes.push('bg-[#1A1000] border-[#3A2800] border-dashed cursor-pointer');
        content = <span className="text-[clamp(6px,1.6vw,10px)] opacity-50">⚡</span>;
      } else if (bonus) {
        classes.push(BONUS_CLASSES[bonus], 'cursor-pointer');
        content = BONUS_LABELS[bonus];
      } else {
        classes.push('bg-[#0A1218] border-[#0F1E2A] cursor-pointer');
      }

      // Bölge vurguları (boş karelerde).
      if (!boardTile && !placedTile && st !== 'void') {
        if (playerZone(r, c)) classes.push('shadow-[inset_0_0_0_1px_rgba(0,200,255,0.15)]');
        else if (aiZone(r, c)) classes.push('shadow-[inset_0_0_0_1px_rgba(255,64,96,0.15)]');
      }

      const clickable = st !== 'void';
      cells.push(
        <div
          key={k}
          className={classes.join(' ')}
          onClick={clickable ? () => onCellClick(r, c) : undefined}
        >
          {content}
        </div>,
      );
    }
  }

  return (
    <div className="w-full px-2 py-2 max-w-[460px] mx-auto">
      <div
        className="w-full aspect-square grid gap-[2px] bg-[#060A0D] border border-border rounded-lg p-1 shadow-[0_0_40px_rgba(0,200,255,0.04),0_0_80px_rgba(255,64,96,0.04)]"
        style={{ gridTemplateColumns: `repeat(${SIZE}, 1fr)` }}
      >
        {cells}
      </div>
    </div>
  );
}
