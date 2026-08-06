// Tek harf taşı — src/components/Tile.tsx portu.
// Web'deki WebkitTextStroke konturu Flutter'da birebir yok; kalın ağırlıkla
// yaklaşılıyor (Nunito fontu ve ince kontur ayarı font/parlatma fazının işi).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show Tile, tileLetter;

import 'player_colors.dart';

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

    final BoxDecoration decoration;
    final Color letterColor;
    final Color ptsColor;
    if (color != null) {
      decoration = BoxDecoration(
        color: color!.tint,
        border: Border.all(color: color!.base, width: 1),
        borderRadius: BorderRadius.circular(5),
      );
      letterColor = color!.text;
      ptsColor = const Color(0xFF2563EB); // web text-accent
    } else if (isRack) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0A0), Color(0xFFFFD800), Color(0xFFF0C000)],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8CA38200),
            offset: Offset(4, 4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Color(0x59A38200),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      );
      letterColor = const Color(0xFF5A3800);
      ptsColor = const Color(0xFF8B5E00);
    } else {
      decoration = BoxDecoration(borderRadius: BorderRadius.circular(5));
      letterColor = const Color(0xFF3A4A5C);
      ptsColor = const Color(0xFF2563EB);
    }

    final body = Container(
      decoration: decoration,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.all(compact ? 1 : 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  display,
                  style: TextStyle(
                    color: letterColor,
                    fontWeight: FontWeight.w800,
                    fontSize: isRack ? 24 : (compact ? 12 : 20),
                    height: 1,
                  ),
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
                  fontWeight: FontWeight.bold,
                  fontSize: isRack ? 10 : 7,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );

    // Seçili raf taşı hafif yukarı kalkar (web: -translate-y-[7px]).
    return selected ? Transform.translate(offset: const Offset(0, -7), child: body) : body;
  }
}
