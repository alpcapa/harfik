// Harfik — 13x13 oyun tahtası (çok oyunculu, renkli bölgeler)
import {
  BONUS_LABELS,
  PLAYER_COLORS,
  SIZE,
  regionOf,
  type PlayerColor,
} from '../game/constants';
import type { GameState } from '../game/types';
import { key } from '../utils/board';
import { Tile } from './Tile';

interface BoardProps {
  state: GameState;
  onCellClick: (r: number, c: number) => void;
}

// Beyaz zemine uyumlu bonus kareleri (kısaltma rengi + arka plan).
const BONUS_CLASSES: Record<string, string> = {
  dw: 'bg-[#E4F6EA] text-[#16A34A] border-[#BEE6CC]',
  tw: 'bg-[#FCEBDC] text-[#D97706] border-[#F2D2B0]',
  dl: 'bg-[#E1ECFD] text-[#2563EB] border-[#C4D8FA]',
  tl: 'bg-[#F0E6FB] text-[#7C3AED] border-[#DCC8F4]',
};

export function Board({ state, onCellClick }: BoardProps) {
  const { board, placed, bonuses, cellState, lastWords, players, current } = state;

  // Köşe bölgesi -> o köşenin sahibinin rengi (boş kareleri renklendirmek için).
  const cornerColor: (PlayerColor | undefined)[] = [
    undefined,
    undefined,
    undefined,
    undefined,
  ];
  for (const p of players) cornerColor[p.corner] = PLAYER_COLORS[p.colorIndex];

  const colorOf = (owner: number | undefined): PlayerColor | undefined =>
    owner === undefined ? undefined : PLAYER_COLORS[players[owner]?.colorIndex ?? 0];

  const currentColor = PLAYER_COLORS[players[current]?.colorIndex ?? 0];

  const cells = [];

  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const k = key(r, c);
      const boardTile = board[r][c];
      const placedTile = placed[k];
      const st = cellState[k];
      const bonus = bonuses[k];
      const region = regionOf(r, c);
      const zone = region >= 0 ? cornerColor[region] : undefined;

      let content: React.ReactNode = null;
      let style: React.CSSProperties | undefined;
      const classes = [
        'min-w-0 min-h-0 rounded-[2px] flex items-center justify-center',
        'font-mono font-bold text-[clamp(5px,1.4vw,8px)] select-none',
        'transition-[background,opacity] duration-300 border',
      ];

      const isLastWord = !!lastWords[k];

      if (st === 'void') {
        classes.push('bg-void border-[#DDE1E6] opacity-60 cursor-not-allowed');
      } else if (boardTile) {
        classes.push(
          isLastWord
            ? 'bg-transparent border-transparent cursor-pointer rounded-[3px] ring-2 ring-gold/60'
            : 'bg-transparent border-transparent cursor-default',
        );
        content = <Tile tile={boardTile} variant="board" color={colorOf(boardTile.owner)} />;
      } else if (placedTile) {
        classes.push('bg-transparent border-transparent');
        content = <Tile tile={placedTile} variant="placed" color={currentColor} />;
      } else if (st === 'crack') {
        classes.push('bg-[#FBF3E0] border-[#EAD9A8] border-dashed cursor-pointer');
        content = <span className="text-[clamp(6px,1.6vw,10px)] opacity-50">⚡</span>;
      } else if (bonus) {
        classes.push(BONUS_CLASSES[bonus], 'cursor-pointer');
        content = BONUS_LABELS[bonus];
        // Bonus, bir oyuncu köşesindeyse o köşenin rengiyle ince çerçeve.
        if (zone) classes.push('ring-1 ring-inset');
        if (zone) style = { boxShadow: `inset 0 0 0 1px ${zone.base}33` };
      } else if (zone) {
        // Bir oyuncunun köşesindeki boş kare: o oyuncunun açık tonu.
        classes.push('cursor-pointer');
        style = { background: zone.zone, border: `1px solid ${zone.base}55` };
      } else {
        // Merkez (tarafsız) boş kare.
        classes.push('bg-white border-[#E3E7EC] cursor-pointer');
      }

      const clickable = st !== 'void';
      cells.push(
        <div
          key={k}
          className={classes.join(' ')}
          style={style}
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
        className="w-full aspect-square grid gap-[2px] bg-panel border border-border rounded-lg p-1 shadow-[0_2px_16px_rgba(27,36,48,0.08)]"
        style={{
          gridTemplateColumns: `repeat(${SIZE}, 1fr)`,
          gridTemplateRows: `repeat(${SIZE}, 1fr)`,
        }}
      >
        {cells}
      </div>
    </div>
  );
}
