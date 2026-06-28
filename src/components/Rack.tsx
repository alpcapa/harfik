// Harfik — oyuncunun harf rafı
import type { Tile as TileModel } from '../game/types';
import { Tile } from './Tile';

interface RackProps {
  tiles: TileModel[];
  selectedTile: number | null;
  onSelect: (index: number) => void;
}

export function Rack({ tiles, selectedTile, onSelect }: RackProps) {
  return (
    <div className="bg-panel border border-border rounded-lg p-2">
      <div className="flex justify-between text-[8px] uppercase tracking-[2px] text-muted font-mono mb-1.5">
        <span>Rafın</span>
        <span>{tiles.length} harf</span>
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
