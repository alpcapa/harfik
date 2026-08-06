// Aktif oyuncunun harf rafı — src/components/Rack.tsx portu.
// Sürükleme prop'ları bilinçli olarak henüz yok (sürükle-bırak ayrı parça);
// dokunma-esaslı seçim/yerleştirme bu parçanın kapsamı.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show Tile;

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

  const RackWidget({
    super.key,
    required this.tiles,
    required this.selectedTile,
    required this.onSelect,
    required this.title,
    required this.color,
    this.swapMode = false,
    this.swapSelection = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDDE4EE),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xA6A3B1C6),
            offset: Offset(5, 5),
            blurRadius: 14,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  swapMode ? '$title — değiştirilecek taşları seç' : title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: swapMode ? const Color(0xFFD97706) : color.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Text(
                swapMode
                    ? '${swapSelection.length} seçili'
                    : '${tiles.length} harf',
                style: const TextStyle(
                  color: Color(0xFF8A93A2),
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 53, // 46px taş + seçili taşın 7px yukarı kalkma payı
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: 46,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(i),
                          child: TileWidget(
                            tile: tiles[i],
                            variant: TileVariant.rack,
                            selected: swapMode
                                ? swapSelection.contains(i)
                                : selectedTile == i,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
