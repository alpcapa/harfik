// Harfik — tek harf bileşeni (rafta ya da tahtada)
import type { Tile as TileModel } from '../game/types';
import { tileLetter } from '../utils/board';

export type TileVariant = 'rack' | 'player' | 'ai' | 'placed';

interface TileProps {
  tile: TileModel;
  variant: TileVariant;
  selected?: boolean;
  onClick?: () => void;
}

const VARIANT_CLASSES: Record<TileVariant, string> = {
  rack:
    'w-[38px] h-[46px] bg-tile-bg border border-tile-border rounded active:scale-105',
  player:
    'w-full h-full bg-[#0A2030] border border-player rounded-[3px] shadow-[0_0_6px_rgba(0,200,255,0.3)]',
  ai:
    'w-full h-full bg-[#2A0A10] border border-ai rounded-[3px] shadow-[0_0_6px_rgba(255,64,96,0.3)]',
  placed:
    'w-full h-full bg-[#0A1A28] border border-accent rounded-[3px] animate-tile-pulse',
};

export function Tile({ tile, variant, selected = false, onClick }: TileProps) {
  const isRack = variant === 'rack';
  const raw = tileLetter(tile) || tile.letter;
  // Joker (?) rafta yıldız olarak görünür; oynanınca seçilen harfe döner.
  const display = raw === '?' ? '★' : raw;

  return (
    <div
      onClick={onClick}
      className={[
        'flex flex-col items-center justify-center select-none transition-transform',
        'cursor-pointer flex-shrink-0',
        VARIANT_CLASSES[variant],
        selected
          ? '!-translate-y-[7px] !border-accent shadow-[0_4px_12px_rgba(0,200,255,0.4)]'
          : '',
      ].join(' ')}
    >
      <span
        className={[
          'font-mono font-bold leading-none text-tile-letter',
          isRack ? 'text-[17px]' : 'text-[clamp(7px,1.8vw,12px)]',
        ].join(' ')}
      >
        {display}
      </span>
      <span
        className={[
          'leading-none text-tile-pts',
          isRack ? 'text-[8px]' : 'text-[clamp(4px,0.9vw,6px)]',
        ].join(' ')}
      >
        {tile.pts}
      </span>
    </div>
  );
}
