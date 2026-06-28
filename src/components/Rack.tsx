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
}

export function Rack({ tiles, selectedTile, onSelect, title, color }: RackProps) {
  return (
    <div
      className="bg-panel rounded-lg p-2 border"
      style={{ borderColor: color.base }}
    >
      <div className="flex justify-between text-[9px] uppercase tracking-[1.5px] font-mono mb-1.5">
        <span className="font-bold" style={{ color: color.base }}>
          {title} — rafın
        </span>
        <span className="text-muted">{tiles.length} harf</span>
      </div>
      <div className="flex justify-center gap-[5px] flex-wrap min-h-[50px]">
        {tiles.map((tile, i) => (
          <Tile
            key={`${tile.letter}-${i}`}
            tile={tile}
            variant="rack"
            selected={selectedTile === i}
            onClick={() => onSelect(i)}
          />
        ))}
      </div>
    </div>
  );
}
