// Harfik — tek harf bileşeni (rafta ya da tahtada)
import type { PlayerColor } from '../game/constants';
import type { Tile as TileModel } from '../game/types';
import { tileLetter } from '../utils/board';

export type TileVariant = 'rack' | 'placed' | 'board';

interface TileProps {
  tile: TileModel;
  variant: TileVariant;
  /** Tahta/yerleştirme taşları için sahibinin rengi. */
  color?: PlayerColor;
  selected?: boolean;
  onClick?: () => void;
}

export function Tile({ tile, variant, color, selected = false, onClick }: TileProps) {
  const isRack = variant === 'rack';
  const raw = tileLetter(tile) || tile.letter;
  // Joker (?) rafta yıldız olarak görünür; oynanınca seçilen harfe döner.
  const display = raw === '?' ? '★' : raw;

  // Renkli varyantlarda (tahta/yerleştirme) sahibinin paleti kullanılır.
  const style: React.CSSProperties = color
    ? {
        background: color.tint,
        border: `1px solid ${color.base}`,
        color: color.text,
      }
    : {};

  const sizeClass = isRack
    ? 'w-[38px] h-[46px] bg-tile-bg border border-tile-border rounded text-tile-letter active:scale-105'
    : variant === 'placed'
      ? 'w-full h-full rounded-[3px] animate-tile-pulse'
      : 'w-full h-full rounded-[3px]';

  return (
    <div
      onClick={onClick}
      style={style}
      className={[
        'flex flex-col items-center justify-center select-none transition-transform',
        'cursor-pointer flex-shrink-0',
        sizeClass,
        selected
          ? '!-translate-y-[7px] !border-accent shadow-[0_4px_12px_rgba(37,99,235,0.35)]'
          : '',
      ].join(' ')}
    >
      <span
        className={[
          'font-mono font-bold leading-none',
          isRack ? 'text-[17px] text-tile-letter' : 'text-[clamp(7px,1.8vw,12px)]',
        ].join(' ')}
      >
        {display}
      </span>
      <span
        className={[
          'leading-none',
          isRack ? 'text-[8px] text-tile-pts' : 'text-[clamp(4px,0.9vw,6px)] opacity-70',
        ].join(' ')}
      >
        {tile.pts}
      </span>
    </div>
  );
}
