// Aktif oyuncunun harf rafı — src/components/Rack.tsx portu.
// Drag handler'ları verildiğinde (ve swap modunda DEĞİLKEN — web
// `isDraggable = draggable && !swapMode`) taşlar GestureDetector yerine
// Listener taşır: dokunuş/sürükleme ayrımını ekran katmanının pointer akışı
// yapar (dokunuş = hareketsiz bırakış → onSelect oradan çağrılır). Swap
// modunda eski dokunuş yolu aynen kalır.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show Tile;

import 'neo_box.dart';
import 'player_colors.dart';
import 'tile_widget.dart';

class RackWidget extends StatelessWidget {
  final List<Tile> tiles;
  final int? selectedTile;
  final void Function(int index) onSelect;

  /// Aktif oyuncunun adı.
  final String title;
  final PlayerColor color;
  final bool swapMode;
  final List<int> swapSelection;

  /// Sürüklenen taşın indeksi — görünmez çizilir, yeri korunur (web
  /// dragHiddenIndex: opacity 0).
  final int? dragHiddenIndex;
  final void Function(int index, PointerDownEvent e)? onTilePointerDown;
  final void Function(PointerMoveEvent e)? onTilePointerMove;
  final void Function(PointerUpEvent e)? onTilePointerUp;
  final VoidCallback? onTilePointerCancel;

  const RackWidget({
    super.key,
    required this.tiles,
    required this.selectedTile,
    required this.onSelect,
    required this.title,
    required this.color,
    this.swapMode = false,
    this.swapSelection = const [],
    this.dragHiddenIndex,
    this.onTilePointerDown,
    this.onTilePointerMove,
    this.onTilePointerUp,
    this.onTilePointerCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Web Rack.tsx gölge çifti — CSS semantiğiyle (tahtadaki aynı ders:
      // BoxShadow hem daha yoğun boyar hem katman sırası ters; ilk sürüm
      // ayrıca beyaz sol-üst parlamayı hiç taşımamıştı).
      decoration: const ShapeDecorationWithCssShadows(
        color: Color(0xFFDDE4EE),
        radius: 16,
        shadows: [
          CssShadow(color: Color(0xA6A3B1C6), offset: Offset(5, 5), blur: 14),
          CssShadow(color: Color(0xE6FFFFFF), offset: Offset(-3, -3), blur: 10),
        ],
      ),
      // Dolgu ARTIK SİMETRİK DEĞİL ve sebebi dokunma alanı (27 Ağustos
      // 2026, kullanıcı bildirdi: *"harfi yakalamak bazen zor oluyor"*).
      // Ölçüldü (390×844): taşın dokunma kutusu 46.3 × 46 idi ve çevresi
      // ÖLÜ alandı — altında kutunun 12 px'lik dolgusu, üstünde seçili
      // taşın 7 px'lik kalkma payı, arasında 3 px'lik boşluklar. Parmağın
      // bildirdiği temas merkezi nişan alınan noktanın ALTINDA kaldığından
      // (projenin "biraz üstüne basınca çalışıyor" hata sınıfı,
      // `docs/decisions/touch-ux-bugs.md`) ıskalamalar tam da alttaki o ölü
      // banda düşüyordu.
      //
      // Çözüm: ölü alanı taşlara DEVRET. Alt dolgu (12) satırın kendisine,
      // yatay dolgunun 1,5 px'i her yuvaya taşındı; 12 → 10,5 + yuva başına
      // 1,5 toplamı KORUYOR, yani taşların genişliği ve konumu birebir aynı
      // kalıyor (ölçüldü: taş 0 hâlâ x 24.0–70.3, y 412–458). Değişen tek
      // şey dokunma kutusu: 46.3 × 46 → 49.3 × 65, alan 2,1 katı.
      padding: const EdgeInsets.fromLTRB(10.5, 12, 10.5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Yatay dolgunun 1,5 px'i yuvalara taşındığından (bkz. yukarı)
          // başlık satırı onu kendisi geri alır — adın x'i değişmesin.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                // Yalnızca oyuncunun adı. Web de swap modunda buraya bir
                // "— değiştirilecek taşları seç" ekliyordu; kullanıcı
                // 6 Ağustos 2026'da portta, 17 Ağustos 2026'da web'de
                // (Rack.tsx) kaldırttı — aksiyon metni zaten tahtanın
                // altındaki mesaj satırında yazıyor, rafta tekrar edilmesi
                // gereksiz. İKİ TARAF ARTIK AYNI: geri eklenecekse ikisine
                // birden eklenmeli.
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // #D97706 BİLİNÇLİ olarak token DEĞİL — web `Rack.tsx`
                    // de tam bu değeri sabit yazıyor (`text-gold` #B7791F
                    // değil). Renk denetiminde "token'a çek" diye
                    // düzeltilmemeli.
                    color: swapMode ? const Color(0xFFD97706) : color.text,
                    fontFamily: 'SpaceMono',
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              // Taş sayısı ("7 harf") 17 Ağustos 2026'da kullanıcı isteğiyle
              // İKİ platformdan da kaldırıldı — rafta zaten görünen bir şeyi
              // tekrar yazıyordu. Swap modundaki seçim sayacı bir DURUM
              // bilgisi taşıdığından kalıyor (web Rack.tsx de öyle).
              if (swapMode)
                Text(
                  '${swapSelection.length} seçili',
                  style: const TextStyle(
                    color: Color(0xFF8A93A2),
                    fontFamily: 'SpaceMono',
                    fontSize: 9,
                    letterSpacing: 1.5,
                  ),
                ),
            ],
          ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            // 7 (seçili taşın kalkma payı) + 46 (taş) + 12 (kutunun eski alt
            // dolgusu). Yükseklik toplamı değişmedi, yalnızca alt 12 px artık
            // satırın İÇİNDE ve dokunulabilir.
            height: 65,
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i++)
                  Expanded(child: _tileTouchArea(i)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dokunma kutusu YUVANIN TAMAMI (boşlukların yarısı + alttaki eski
  /// dolgu); taş kendi doğal boyutunda, yuvanın altına hizalı çizilir.
  /// `Listener`/`GestureDetector` bu yüzden dolgunun DIŞINDA duruyor —
  /// içeride olsaydı kutu yine yalnızca taş kadar olurdu.
  Widget _tileTouchArea(int i) {
    final tile = Padding(
      padding: const EdgeInsets.fromLTRB(1.5, 0, 1.5, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: 46,
          child: Opacity(
            opacity: dragHiddenIndex == i ? 0 : 1,
            child: TileWidget(
              tile: tiles[i],
              variant: TileVariant.rack,
              selected:
                  swapMode ? swapSelection.contains(i) : selectedTile == i,
            ),
          ),
        ),
      ),
    );
    final isDraggable = onTilePointerDown != null && !swapMode;
    if (isDraggable) {
      return Listener(
        key: ValueKey('rack-$i'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => onTilePointerDown!(i, e),
        onPointerMove: onTilePointerMove,
        onPointerUp: onTilePointerUp,
        onPointerCancel:
            onTilePointerCancel == null ? null : (_) => onTilePointerCancel!(),
        child: tile,
      );
    }
    return GestureDetector(
      key: ValueKey('rack-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(i),
      child: tile,
    );
  }
}
