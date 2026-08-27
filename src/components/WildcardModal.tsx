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
      {/* DİKEY boşluk hücrenin İÇİNE alındı (27 Ağustos 2026, portla birebir
          aynı sayılar — bkz. `wild_letter_sheet.dart`). Ölçüldü: hücrenin
          dokunma kutusu 48 × **44** idi (genişlik tam sınırda, yükseklik
          Material asgarisinin altında) ve satırlar arasında 6 px ölü bant
          vardı. Buradaki ıskalamanın bedeli gerçek — YANLIŞ HARF seçilir.
          `gap-y-0` + hücre `h-[50px] pb-1.5`: satırlar dikeyde aralıksız,
          hedef 48 × 50, taşın çizildiği yer her satırda birebir aynı (satır
          adımı iki durumda da 50). Tıklama artık HÜCREDE, taşta değil.
          YATAY boşluk (`gap-x-1.5`) bilerek duruyor: genişlik zaten 48 ve
          onu da hücreye almak taşları 1 px daraltırdı. */}
      <div className="grid grid-cols-6 gap-x-1.5 gap-y-0">
        {LETTERS.map((letter) => (
          <div
            key={letter}
            className="h-[50px] pb-1.5 cursor-pointer"
            onClick={() => onSelect(letter)}
          >
            <div className="h-11">
              <Tile tile={{ letter, pts: TILE_DATA[letter].pts }} variant="rack" />
            </div>
          </div>
        ))}
      </div>
      {onRecall && (
        <button
          onClick={onRecall}
          // mt-3 → mt-1.5: ızgara yukarıdaki değişiklikle 6 px uzadı, bu
          // boşluk aynı kadar kısıldı — buton yerinde kalıyor (portta da
          // aynı telafi: SizedBox 12 → 6).
          className="btn-raised-neutral w-full mt-1.5 py-2.5 rounded-md bg-void border border-border text-text text-xs font-bold uppercase tracking-[1px] active:scale-[0.97] transition-transform"
        >
          Geri Al
        </button>
      )}
    </Modal>
  );
}
