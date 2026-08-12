// Tek harf taşı — src/components/Tile.tsx portu.
// Harf fontu web'le aynı: Nunito 800 + ince kontur (web -webkit-text-stroke
// karşılığı: aynı renkte stroke katmanı). Harf rengi tahta/yerleştirme
// varyantında HER ZAMAN #1B2430 (web text-tile-letter) — oyuncu rengi
// yalnızca zemin/çerçevede.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show Tile, tileLetter;

import 'fluid.dart';
import 'neo_box.dart';
import 'player_colors.dart';
import '../tokens.dart';

enum TileVariant { rack, placed, board }

class TileWidget extends StatelessWidget {
  final Tile tile;
  final TileVariant variant;

  /// Tahta/yerleştirme taşları için sahibinin rengi; rafta null (altın).
  final PlayerColor? color;
  final bool selected;

  /// Küçük salt-okunur önizlemeler: harf küçük, puan üst simgesi yok.
  final bool compact;

  const TileWidget({
    super.key,
    required this.tile,
    required this.variant,
    this.color,
    this.selected = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isRack = variant == TileVariant.rack;
    final raw = tileLetter(tile).isNotEmpty ? tileLetter(tile) : tile.letter;
    // Joker rafta yıldız; oynanınca seçilen harfe döner (web ile aynı).
    final display = raw == '?' ? '★' : raw;

    final Decoration? decoration;
    final Color letterColor;
    final Color ptsColor;
    if (color != null) {
      decoration = BoxDecoration(
        color: color!.tint,
        border: Border.all(color: color!.base, width: 1),
        borderRadius: BorderRadius.circular(5),
      );
      letterColor = kText; // web text-tile-letter
      ptsColor = kAccent; // web text-accent
    } else if (isRack) {
      // Web Tile.tsx raf taşı gölge üçlüsü — CSS semantiğiyle (tahta/raf
      // kartındaki aynı ders: BoxShadow yoğun + katman sırası ters).
      decoration = const ShapeDecorationWithCssShadows(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0A0), Color(0xFFFFD800), Color(0xFFF0C000)],
          stops: [0.0, 0.6, 1.0],
        ),
        radius: 10,
        shadows: [
          CssShadow(color: Color(0x8CA38200), offset: Offset(4, 4), blur: 10),
          CssShadow(color: Color(0xCCFFFAC8), offset: Offset(-2, -2), blur: 6),
          CssShadow(color: Color(0x59A38200), offset: Offset(0, 6), blur: 14),
        ],
      );
      letterColor = const Color(0xFF5A3800);
      ptsColor = const Color(0xFF8B5E00);
    } else {
      decoration = null; // tahta varyantı — zemin/çerçeve hücrenin işi
      letterColor = kText;
      ptsColor = kAccent;
    }

    // Web -webkit-text-stroke: harfin üstüne aynı renkte ince kontur bindirir
    // (glyph'i kalınlaştırır) — rafta 0.7px, tahtada 0.35px.
    final strokeWidth = isRack ? 0.7 : 0.35;
    // Web'de tahta/compact harf puntosu HÜCREYE değil EKRAN genişliğine
    // (vw) bağlı — Tile.tsx: rafta sabit 24px, tahtada
    // `clamp(14px,3.8vw,24px)`, compact önizlemede `clamp(8px,2.4vw,14px)`.
    // Geniş ekranlarda (ör. iPad, >631px) web 24px'e kilitlenirken port
    // sabit 20px kullanıyordu — gerçek, ölçülebilir bir boyut farkı (bkz.
    // mobile/CLAUDE.md Parça 24). Rack sabit kalıyor (web de sabit).
    final screenWidth = MediaQuery.sizeOf(context).width;
    final boardLetterSize = compact
        ? fluidSize(screenWidth, 8, 0, 2.4, 14)
        : fluidSize(screenWidth, 14, 0, 3.8, 24);
    final letterStyle = TextStyle(
      color: letterColor,
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w800,
      fontSize: isRack ? 24 : boardLetterSize,
      height: 1,
    );

    final body = Container(
      decoration: decoration,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.all(compact ? 1 : 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // Joker yıldızı: ★ glyph'i Nunito'da yok (web'de tarayıcı
                // yedek fonttan basar) — Flutter'da Material ikonu kullanılır.
                child: display == '★'
                    ? Icon(Icons.star,
                        size: letterStyle.fontSize, color: letterColor)
                    : Stack(
                        children: [
                          Text(
                            display,
                            style: letterStyle.copyWith(
                              color: null,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = strokeWidth
                                ..color = letterColor,
                            ),
                          ),
                          Text(display, style: letterStyle),
                        ],
                      ),
              ),
            ),
          ),
          if (!compact)
            Positioned(
              top: isRack ? 3 : 1,
              right: isRack ? 4 : 1.5,
              child: Text(
                '${tile.pts}',
                style: TextStyle(
                  color: ptsColor,
                  fontFamily: 'SpaceMono',
                  fontWeight: FontWeight.bold,
                  // Web: rafta sabit 10px, tahtada `clamp(6px,1.6vw,10px)`
                  // (aynı vw-tabanlı sistem, bkz. yukarıdaki letterStyle notu).
                  fontSize: isRack ? 10 : fluidSize(screenWidth, 6, 0, 1.6, 10),
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );

    // Seçili raf taşı hafif yukarı kalkar (web: -translate-y-[7px]).
    return selected
        ? Transform.translate(offset: const Offset(0, -7), child: body)
        : body;
  }
}
