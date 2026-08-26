// Kelimeki — aktif oyuncunun harf rafı
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
  /** Raftaki taşların sürüklenerek tahtaya konabilmesi mümkün mü? */
  draggable?: boolean;
  /** Şu an sürüklenmekte olan raf taşının indeksi — o slot boşmuş gibi çizilir. */
  dragHiddenIndex?: number | null;
  onTilePointerDown?: (index: number, e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerMove?: (e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerUp?: (e: React.PointerEvent<HTMLDivElement>) => void;
  onTilePointerCancel?: (e: React.PointerEvent<HTMLDivElement>) => void;
}

export function Rack({
  tiles,
  selectedTile,
  onSelect,
  title,
  color,
  swapMode = false,
  swapSelection = [],
  draggable = false,
  dragHiddenIndex = null,
  onTilePointerDown,
  onTilePointerMove,
  onTilePointerUp,
  onTilePointerCancel,
}: RackProps) {
  return (
    <div
      data-rack="true"
      className="bg-[#DDE4EE] rounded-[16px] p-3"
      style={{
        boxShadow: '5px 5px 14px rgba(163,177,198,0.65), -3px -3px 10px rgba(255,255,255,0.9)',
      }}
    >
      {/* `uppercase` YOK (17 Ağustos 2026, kullanıcı isteği: "Web'i app'le aynı
          yap"): Flutter portu (rack_widget.dart) adı olduğu gibi yazıyor.
          Kullanıcının "bold yazılmış" dediği fark AĞIRLIKTAN DEĞİL büyük
          harften geliyordu — ölçüldü, iki taraf da 700; bu yüzden `font-bold`
          KALDI, kaldırmak porttan ayrışma üretirdi. */}
      <div className="flex justify-between text-[9px] tracking-[1.5px] font-mono mb-1.5">
        {/* Yalnızca oyuncunun adı — swap modunda buraya bir de
            "— değiştirilecek taşları seç" ekleniyordu. 17 Ağustos 2026'da
            kullanıcı isteğiyle KALDIRILDI: aynı talimat zaten tahtanın
            altındaki mesaj satırında yazıyor ("Değiştireceğin taşları seç,
            sonra "Değiştir"e bas."), ismin yanında tekrar edilmesi gereksizdi.
            Swap modu yine dört yerden belli: adın altın rengi, sağdaki
            "N seçili" sayacı, mesaj satırı ve DEĞİŞTİR/VAZGEÇ butonları.
            Flutter portu bunu 6 Ağustos 2026'da kaldırmıştı — o gün bilinçli
            bir sapma olarak kaydedilmişti, artık iki taraf aynı. */}
        <span className="font-bold" style={{ color: swapMode ? '#D97706' : color.text }}>
          {title}
        </span>
        {/* Taş sayısı ("7 harf") kaldırıldı — aynı gün, aynı istek: rafta zaten
            görünen bir şeyi tekrar yazıyordu. Swap modundaki seçim sayacı bir
            DURUM bilgisi taşıdığından kalıyor (port da öyle). */}
        {swapMode && (
          <span className="text-muted">{`${swapSelection.length} seçili`}</span>
        )}
      </div>
      {/* `pt-[7px]` + `min-h-[53px]`: portun raf kutusu seçili taşın 7px yukarı
          kalkması için yer AYIRIYOR (`SizedBox(height: 53)` + bottomCenter),
          web ise `-translate-y-[7px]` ile başlığın üstüne taşıyordu. Kullanıcı
          portun görünümünü seçti; ölçülen başlık→taş arası 6 → 13px, ikisi
          birebir. */}
      <div
        className="min-h-[53px] pt-[7px]"
        style={{
          display: 'grid',
          gridTemplateColumns: `repeat(${tiles.length || 1}, 1fr)`,
          gap: '3px',
        }}
      >
        {tiles.map((tile, i) => {
          const isDraggable = draggable && !swapMode;
          return (
            <div
              key={`${tile.letter}-${i}`}
              // `data-cell`/`data-rack` ile aynı amaç: testlerin taşı sınıf
              // adına ya da çocuk sırasına göre aramak zorunda kalmaması
              // (raf'ın ilk çocuğu taş DEĞİL, etiket satırı).
              data-rack-tile={i}
              className="h-[46px]"
              style={{
                opacity: dragHiddenIndex === i ? 0 : 1,
                ...(isDraggable ? { touchAction: 'none' } : null),
              }}
              onPointerDown={isDraggable ? (e) => onTilePointerDown?.(i, e) : undefined}
              onPointerMove={isDraggable ? onTilePointerMove : undefined}
              onPointerUp={isDraggable ? onTilePointerUp : undefined}
              onPointerCancel={isDraggable ? onTilePointerCancel : undefined}
            >
              <Tile
                tile={tile}
                variant="rack"
                selected={swapMode ? swapSelection.includes(i) : selectedTile === i}
                onClick={isDraggable ? undefined : () => onSelect(i)}
              />
            </div>
          );
        })}
      </div>
    </div>
  );
}
