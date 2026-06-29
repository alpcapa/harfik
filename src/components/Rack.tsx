// Harfik — aktif oyuncunun harf rafı
import type { PlayerColor } from '../game/constants';
import type { Tile as TileModel } from '../game/types';
import { Tile } from './Tile';

interface RackProps {
  tiles: TileModel[];
  selectedTile: number | null;
  onSelect: (index: number) => void;
  /** Aktif oyuncunun adı. */
  title: string;
  /** Aktif oyuncunun rengi. */
  color: PlayerColor;
  /** Taş değiştirme modu aktif mi? */
  swapMode?: boolean;
  /** Değiştirmek için seçilen taş indeksleri. */
  swapSelection?: number[];
}

export function Rack({
  tiles,
  selectedTile,
  onSelect,
  title,
  color,
  swapMode = false,
  swapSelection = [],
}: RackProps) {
  return (
    <div
      className="bg-panel rounded-lg p-2 border"
      style={{ borderColor: swapMode ? '#D97706' : color.base }}
    >
      <div className="flex justify-between text-[9px] uppercase tracking-[1.5px] font-mono mb-1.5">
        <span className="font-bold" style={{ color: swapMode ? '#D97706' : color.base }}>
          {swapMode ? `${title} — değiştirilecek taşları seç` : title}
        </span>
        <span className="text-muted">
          {swapMode
            ? `${swapSelection.length} seçili`
            : `${tiles.length} harf`}
        </span>
      </div>
      <div className="flex gap-[3px] min-h-[46px]">
        {tiles.map((tile, i) => (
          <div key={`${tile.letter}-${i}`} className="flex-1 min-w-0 max-w-[38px] h-[46px]">
            <Tile
              tile={tile}
              variant="rack"
              selected={swapMode ? swapSelection.includes(i) : selectedTile === i}
              onClick={() => onSelect(i)}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
