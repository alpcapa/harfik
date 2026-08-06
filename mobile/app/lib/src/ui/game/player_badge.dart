// Oyuncu sıra numarası karesi — src/components/PlayerBadge.tsx portu:
// renkli kare + beyaz numara (index+1).
import 'package:flutter/material.dart';

import 'player_colors.dart';

class PlayerBadge extends StatelessWidget {
  /// 0 tabanlı koltuk indeksi — karede gösterilen numara (index+1).
  final int index;

  /// Renk kaynağı farklıysa (Player.colorIndex) ayrıca verilir.
  final int? colorIndex;
  final double size;

  const PlayerBadge({
    super.key,
    required this.index,
    this.colorIndex,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final col = playerColors[(colorIndex ?? index) % playerColors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: col.base,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: (size * 0.55).roundToDouble(),
          height: 1,
        ),
      ),
    );
  }
}
