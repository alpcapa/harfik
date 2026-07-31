// Kelimeki — joker taş oynanırken hangi harfe dönüşeceğini seçme penceresi
import { Modal } from './Modal';
import { TILE_DATA } from '../data/tiles';
import { Tile } from './Tile';

const LETTERS = Object.keys(TILE_DATA).filter((l) => l !== '?');

interface WildcardModalProps {
  title?: string;
  onSelect: (letter: string) => void;
  onClose: () => void;
  /** Doluysa (tahtaya zaten konmuş bir jokeri düzenlerken) altta ayrı bir
   * "Geri Al" butonu gösterilir — taşı harf değiştirmeden rafa döndürür. */
  onRecall?: () => void;
}

export function WildcardModal({ title, onSelect, onClose, onRecall }: WildcardModalProps) {
  return (
    <Modal title={title ?? 'Joker Hangi Harf Olsun?'} onClose={onClose}>
      <div className="grid grid-cols-6 gap-1.5">
        {LETTERS.map((letter) => (
          <div key={letter} className="h-11">
            <Tile
              tile={{ letter, pts: TILE_DATA[letter].pts }}
              variant="rack"
              onClick={() => onSelect(letter)}
            />
          </div>
        ))}
      </div>
      {onRecall && (
        <button
          onClick={onRecall}
          className="btn-raised-neutral w-full mt-3 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
        >
          Geri Al
        </button>
      )}
    </Modal>
  );
}
