// Oyun başlığı — src/components/GameHeader.tsx portu: solda logo (dokunuş =
// oyundan çık), sağda oyuncu skor kutuları. Web'in akıcı clamp() sistemi
// (375px'te min → 465px'te max) burada _fluid() ile birebir hesaplanır;
// UserMenu (hesap menüsü) BİLİNÇLİ eksik — auth sonraki fazın işi.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'logo_mark.dart';
import 'player_colors.dart';

/// Web'deki `clamp(min, calc(a + b·vw), max)` eşleniği — vw = ekran
/// genişliği / 100. Uç noktalar web'le aynı (375 → min, 465 → max).
double _fluid(double screenWidth, double min, double a, double b, double max) {
  final v = a + b * (screenWidth / 100);
  return v.clamp(min, max);
}

class GameHeader extends StatelessWidget {
  final GameState state;
  final VoidCallback? onLogoTap;

  /// Verilirse insan koltuklarının kutuları tıklanabilir olur (Canlı oyunda
  /// skor kartı — web onPlayerClick'in eşleniği; yerel oyunda verilmez).
  final void Function(int index)? onPlayerTap;

  const GameHeader({
    super.key,
    required this.state,
    this.onLogoTap,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Web sabitleri (GameHeader.tsx) — aynı katsayılar.
    final playerBoxWidth = _fluid(w, 43, -52.83, 25.56, 66);
    final yzBoxWidth = _fluid(w, 28, -34.5, 16.67, 43);
    final labelFontSize = _fluid(w, 6, -2.33, 2.22, 8);
    final scoreFontSize = _fluid(w, 13, -7.83, 5.56, 18);
    final boxPaddingX = _fluid(w, 1.5, -6.83, 2.22, 3.5);
    final boxGap = _fluid(w, 4, -4.33, 2.22, 6);
    final boxPaddingY = _fluid(w, 2.7, -0.63, 0.89, 3.5);
    final logoHeight = _fluid(w, 28, -5.33, 8.89, 36);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onLogoTap,
            child: LogoMark(height: logoHeight),
          ),
          const SizedBox(width: 8),
          // Web güvenlik ağıyla aynı: sığmazsa şerit görünmez biçimde yatay
          // kaydırılır (satır kırmak yerine), 0. kutu her zaman erişilebilir.
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: false,
              child: Row(
                children: [
                  for (var i = 0; i < state.players.length; i++) ...[
                    if (i > 0) SizedBox(width: boxGap),
                    _PlayerBox(
                      player: state.players[i],
                      index: i,
                      active: i == state.current,
                      width:
                          state.players[i].isAI ? yzBoxWidth : playerBoxWidth,
                      paddingX: boxPaddingX,
                      paddingY: boxPaddingY,
                      labelFontSize: labelFontSize,
                      scoreFontSize: scoreFontSize,
                      onTap: (onPlayerTap != null && !state.players[i].isAI)
                          ? () => onPlayerTap!(i)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBox extends StatelessWidget {
  final Player player;
  final int index;
  final bool active;
  final double width;
  final double paddingX;
  final double paddingY;
  final double labelFontSize;
  final double scoreFontSize;
  final VoidCallback? onTap;

  const _PlayerBox({
    required this.player,
    required this.index,
    required this.active,
    required this.width,
    required this.paddingX,
    required this.paddingY,
    required this.labelFontSize,
    required this.scoreFontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = playerColors[player.colorIndex % playerColors.length];
    final label = player.isAI ? 'YZ ${index + 1}' : trUpper(player.name);

    final box = Opacity(
      opacity: player.surrendered ? 0.45 : 1,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(horizontal: paddingX, vertical: paddingY),
        decoration: BoxDecoration(
          color: col.tint,
          borderRadius: BorderRadius.circular(6),
        ),
        // Çerçeve foregroundDecoration'da: web'deki `outline` dersiyle aynı
        // sebep — aktif/pasif kalınlık farkı (2/0.5px) iç içerik genişliğini
        // değiştirirse dar YZ kutusunda 3 haneli skor kırpılır. Flutter'da
        // BoxDecoration.border da içeriden yer kapladığından çerçeve layout'a
        // hiç dokunmayan ön katmana çizilir.
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: col.base, width: active ? 2 : 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontWeight: FontWeight.bold,
                fontSize: labelFontSize,
                letterSpacing: 1,
                color: col.base,
              ),
            ),
            Text(
              player.surrendered ? 'TESLİM' : '${player.score}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontWeight: FontWeight.bold,
                fontSize: player.surrendered ? labelFontSize : scoreFontSize,
                height: 1,
                letterSpacing: player.surrendered ? 1 : 0,
                color: col.base,
              ),
            ),
          ],
        ),
      ),
    );

    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }
}
