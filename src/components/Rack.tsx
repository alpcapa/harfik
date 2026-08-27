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
      // Dolgu ARTIK SİMETRİK DEĞİL ve sebebi dokunma alanı (27 Ağustos 2026,
      // kullanıcı uygulamada bildirdi: "harfi yakalamak bazen zor oluyor").
      // Taşın tıklama kutusu taşın kendisi kadardı (46×46) ve çevresi ÖLÜ
      // alandı: altında kutunun 12 px dolgusu, üstünde seçili taşın 7 px
      // kalkma payı, aralarında 3 px boşluk. Ölü alan taşlara devredildi —
      // alt dolgu (`pb-0`) satırın içine, yatay dolgunun 1,5 px'i her
      // hücreye (`px-[10.5px]` + hücre `px-[1.5px]` = eski 12). Taşların
      // ÖLÇÜSÜ VE KONUMU birebir aynı kalır; büyüyen yalnızca hedef.
      // Flutter portundaki eşi: `rack_widget.dart`, aynı sayılar.
      className="bg-[#DDE4EE] rounded-[16px] pt-3 pb-0 px-[10.5px]"
      style={{
        boxShadow: '5px 5px 14px rgba(163,177,198,0.65), -3px -3px 10px rgba(255,255,255,0.9)',
      }}
    >
      {/* `uppercase` YOK (17 Ağustos 2026, kullanıcı isteği: "Web'i app'le aynı
          yap"): Flutter portu (rack_widget.dart) adı olduğu gibi yazıyor.
          Kullanıcının "bold yazılmış" dediği fark AĞIRLIKTAN DEĞİL büyük
          harften geliyordu — ölçüldü, iki taraf da 700; bu yüzden `font-bold`
          KALDI, kaldırmak porttan ayrışma üretirdi. */}
      {/* Yatay dolgunun 1,5 px'i hücrelere taşındığından başlık satırı onu
          kendisi geri alır — adın x'i değişmesin. */}
      <div className="flex justify-between text-[9px] tracking-[1.5px] font-mono mb-1.5 px-[1.5px]">
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
        // 53 → 65: alttaki 12 px artık satırın İÇİNDE ve tıklanabilir.
        // `gap` KALDIRILDI — boşluk her hücrenin kendi `px-[1.5px]`'ine
        // taşındı, yani ölü değil hedefin parçası. Seçili taşın 7 px'lik
        // kalkma payı da (`pt-[7px]`) ızgaradan hücrenin içine indi:
        // portla aynı 65'lik hedef çıksın diye.
        className="min-h-[65px]"
        style={{
          display: 'grid',
          gridTemplateColumns: `repeat(${tiles.length || 1}, 1fr)`,
          gap: 0,
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
              // Hedef HÜCRENİN TAMAMI (7 kalkma payı + 46 taş + 12 alt
              // dolgu + boşluk yarıları); taş kendi boyutunda ve yerinde.
              className="h-[65px] pt-[7px] px-[1.5px] pb-3"
              style={isDraggable ? { touchAction: 'none' } : undefined}
              onPointerDown={isDraggable ? (e) => onTilePointerDown?.(i, e) : undefined}
              onPointerMove={isDraggable ? onTilePointerMove : undefined}
              onPointerUp={isDraggable ? onTilePointerUp : undefined}
              onPointerCancel={isDraggable ? onTilePointerCancel : undefined}
            >
              <div
                className="h-[46px]"
                style={{ opacity: dragHiddenIndex === i ? 0 : 1 }}
              >
                <Tile
                  tile={tile}
                  variant="rack"
                  selected={swapMode ? swapSelection.includes(i) : selectedTile === i}
                  onClick={isDraggable ? undefined : () => onSelect(i)}
                />
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
