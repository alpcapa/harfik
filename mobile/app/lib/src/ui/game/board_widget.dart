// 13×13 oyun tahtası — src/components/Board.tsx'in render katmanı portu.
// Bu parça SALT GÖRSEL + hücre dokunuşu: sürükle-bırak, taş yerleştirme
// etkileşimi ve alt bilgi şeridi (Hamleler/Mesajlaşma) sonraki parçaların
// işi (mobile/CLAUDE.md, "UI portu — parça planı").
//
// Web'le bilinçli küçük farklar (parlatma fazında ele alınacak):
// nömorfik iç gölgeler düz tonlarla, taş harfi konturu kalın ağırlıkla
// yaklaşık; yerleştirilen taşın nabız animasyonu henüz yok.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'neo_box.dart';
import 'outline.dart';
import 'player_colors.dart';
import 'tile_widget.dart';

/// Dış hat köşe yarıçapı (ızgara birimi) ve kalınlığı — web sabitleri.
const double _outlineRadius = 0.16;
const double _outlineStroke = 2.5;

const Color _boardBg = Color(0xFFDDE4EE);

const LinearGradient _goldZone = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFDE68A), Color(0xFFFBBF24)],
);
const LinearGradient _centerZone = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
);
const Color _centerText = Color(0xFF7C2D12);

/// Oyna'ya basmadan önceki anlık geçerlilik çerçevesi (web MoveStatus'un
/// tahtaya bakan yüzü) — hesaplama ekran katmanında.
class MoveOverlay {
  final bool valid;
  final List<Cell> cells;
  final int score;
  const MoveOverlay({required this.valid, required this.cells, required this.score});
}

class BoardWidget extends StatelessWidget {
  final GameState state;
  final void Function(int r, int c)? onCellTap;
  final MoveOverlay? moveOverlay;
  final bool compact;

  const BoardWidget({
    super.key,
    required this.state,
    this.onCellTap,
    this.moveOverlay,
    this.compact = false,
  });

  PlayerColor _colorOfIndex(int playerIndex) =>
      playerColors[state.players[playerIndex].colorIndex % playerColors.length];

  @override
  Widget build(BuildContext context) {
    final players = state.players;

    // Bölgeler: köşe + kendi taşlarıyla genişleyen alan (core'dan).
    final territories = computeAllTerritories(state.board, players);
    final territoryOwner = <String, int>{};
    for (var i = 0; i < territories.length; i++) {
      for (final k in territories[i]) {
        territoryOwner[k] = i;
      }
    }

    final homeCellColor = <String, PlayerColor>{};
    final cornerColor = List<PlayerColor?>.filled(4, null);
    final cornerNumber = List<int?>.filled(4, null);
    for (var i = 0; i < players.length; i++) {
      for (final corner in players[i].corners) {
        cornerColor[corner] = _colorOfIndex(i);
        cornerNumber[corner] = i + 1;
        final cc = cornerCell(corner);
        homeCellColor[cellKey(cc.$1, cc.$2)] = _colorOfIndex(i);
      }
    }

    final lastMoveSet = {
      for (final c in state.lastMoveCells) cellKey(c.$1, c.$2)
    };
    final currentColor = players.isEmpty
        ? playerColors.first
        : _colorOfIndex(state.current);

    final outlines = <(Path, Color)>[
      for (var i = 0; i < players.length; i++)
        if (territories[i].isNotEmpty)
          (
            buildRoundedOutlinePath(
              [for (final k in territories[i]) parseKey(k)],
              _outlineRadius,
            ),
            _colorOfIndex(i).base,
          ),
      if (moveOverlay != null && moveOverlay!.cells.isNotEmpty)
        (
          buildRoundedOutlinePath(moveOverlay!.cells, _outlineRadius),
          moveOverlay!.valid ? const Color(0xFF1FA05C) : const Color(0xFFE0483A),
        ),
    ];

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: const ShapeDecorationWithCssShadows(
          color: _boardBg,
          radius: 18,
          // Web Board.tsx'in gölge üçlüsü — CSS değerleriyle: koyu sağ-alt,
          // beyaz sol-üst parlama, altta geniş yumuşak gölge. Flutter'ın
          // BoxShadow'u CSS'ten hem daha koyu/kısa boyuyor hem katman sırası
          // ters; bu decoration gölgeleri CSS matematiğiyle (sigma=blur/2,
          // ilk yazılan en üstte) kendisi çizer — kullanıcı web/app
          // karşılaştırması, 6 Ağustos 2026.
          shadows: [
            CssShadow(
                color: Color(0xB3A3B1C6), offset: Offset(8, 8), blur: 20),
            CssShadow(
                color: Color(0xE6FFFFFF), offset: Offset(-4, -4), blur: 14),
            CssShadow(
                color: Color(0x80A3B1C6), offset: Offset(0, 20), blur: 60),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            GridView.count(
              crossAxisCount: boardSize,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var r = 0; r < boardSize; r++)
                  for (var c = 0; c < boardSize; c++)
                    _buildCell(r, c, territoryOwner, homeCellColor,
                        lastMoveSet, currentColor),
              ],
            ),
            // Bölge/hamle dış hatları — ızgara alanının tamamını kaplayan tek
            // katman (web'deki tek SVG'nin eşleniği), dokunuşları engellemez.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _OutlinesPainter(outlines)),
              ),
            ),
            if (!compact)
              Positioned.fill(child: IgnorePointer(child: _watermarks(cornerColor, cornerNumber))),
            if (moveOverlay != null && moveOverlay!.cells.isNotEmpty)
              Positioned.fill(child: IgnorePointer(child: _moveBadge())),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(
    int r,
    int c,
    Map<String, int> territoryOwner,
    Map<String, PlayerColor> homeCellColor,
    Set<String> lastMoveSet,
    PlayerColor currentColor,
  ) {
    final k = cellKey(r, c);
    final boardTile = state.board[r][c];
    final placedTile = state.placed[k];
    final isCenter = state.bonuses[k] == BonusType.tw;
    final inZone = inBonusZone(r, c);
    final zoneOwner = territoryOwner[k];
    final homeColor = homeCellColor[k];

    Widget? content;
    Widget Function(Widget? child)? cellBox;

    if (boardTile != null) {
      final tileColor = boardTile.owner != null
          ? _colorOfIndex(boardTile.owner!)
          : currentColor;
      final isLastMove = lastMoveSet.contains(k);
      content = TileWidget(
        tile: boardTile,
        variant: TileVariant.board,
        compact: compact,
        color: isLastMove
            ? PlayerColor(
                base: darken(tileColor.base, 0.12),
                tint: darken(tileColor.tint, 0.14),
                zone: tileColor.zone,
                text: tileColor.text,
              )
            : tileColor,
      );
    } else if (placedTile != null) {
      content = TileWidget(
        tile: placedTile,
        variant: TileVariant.placed,
        color: placedTile.owner != null
            ? _colorOfIndex(placedTile.owner!)
            : currentColor,
      );
    } else if (inZone) {
      // Web GOLD_ZONE_STYLE/CENTER_ZONE_STYLE — iç gölgeler + hafif dış gölge.
      final radius = BorderRadius.circular(5);
      cellBox = (child) => NeoBox(
            borderRadius: radius,
            gradient: isCenter ? _centerZone : _goldZone,
            insetShadows: isCenter
                ? const [
                    InsetShadow(
                        color: Color(0x59B4500A), offset: Offset(2, 2), blur: 5),
                    InsetShadow(
                        color: Color(0xB3FFFFFF), offset: Offset(-1, -1), blur: 3),
                  ]
                : const [
                    InsetShadow(
                        color: Color(0x4DB4820A), offset: Offset(2, 2), blur: 5),
                    InsetShadow(
                        color: Color(0xB3FFFFFF), offset: Offset(-1, -1), blur: 3),
                  ],
            outerShadows: isCenter
                ? const [
                    BoxShadow(
                        color: Color(0x40B4500A),
                        offset: Offset(0, 2),
                        blurRadius: 4),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0x33B4820A),
                        offset: Offset(0, 2),
                        blurRadius: 4),
                  ],
            child: child,
          );
      if (isCenter && !compact) {
        content = const Center(
          child: FittedBox(
            child: Text(
              'X3',
              style: TextStyle(
                color: _centerText,
                fontFamily: 'SpaceMono',
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        );
      }
    } else if (zoneOwner != null) {
      // Web: bölge hücresi — oyuncu tonu + içe gömülü gölge (base%13 + beyaz).
      final zone = _colorOfIndex(zoneOwner);
      cellBox = (child) => NeoBox(
            borderRadius: BorderRadius.circular(5),
            color: zone.tint,
            insetShadows: [
              InsetShadow(
                  color: zone.base.withValues(alpha: 0.133),
                  offset: const Offset(2, 2),
                  blur: 5),
              const InsetShadow(
                  color: Color(0x99FFFFFF), offset: Offset(-1, -1), blur: 3),
            ],
            child: child,
          );
    } else {
      // Web: tarafsız boş kare — tahta zemin rengi + nömorfik içe gömülü.
      cellBox = (child) => NeoBox(
            borderRadius: BorderRadius.circular(5),
            color: _boardBg,
            insetShadows: const [
              InsetShadow(
                  color: Color(0x99A3B1C6), offset: Offset(3, 3), blur: 6),
              InsetShadow(
                  color: Color(0xCCFFFFFF), offset: Offset(-2, -2), blur: 5),
            ],
            child: child,
          );
    }

    if (homeColor != null && boardTile == null && placedTile == null) {
      content = Center(
        child: FractionallySizedBox(
          widthFactor: 0.55,
          heightFactor: 0.55,
          child: CustomPaint(painter: _HomeMarkPainter(homeColor.base)),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCellTap == null ? null : () => onCellTap!(r, c),
      child: cellBox != null
          ? cellBox(content)
          : SizedBox.expand(child: content),
    );
  }

  /// Köşe numarası + X2 filigranları (web'deki soluk arka yazılar).
  Widget _watermarks(List<PlayerColor?> cornerColor, List<int?> cornerNumber) {
    const cornerFrac = cornerSize / boardSize;
    const zoneFrac = (boardSize - 2 * cornerSize) / boardSize;
    return Stack(
      children: [
        for (var i = 0; i < 4; i++)
          if (cornerColor[i] != null && cornerNumber[i] != null)
            Align(
              alignment: Alignment(
                (i == 0 || i == 2) ? -1 : 1,
                (i == 0 || i == 1) ? -1 : 1,
              ),
              child: FractionallySizedBox(
                widthFactor: cornerFrac,
                heightFactor: cornerFrac,
                child: Opacity(
                  opacity: 0.20,
                  child: FittedBox(
                    child: Text(
                      '${cornerNumber[i]}',
                      style: TextStyle(
                        color: cornerColor[i]!.base,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        Center(
          child: FractionallySizedBox(
            widthFactor: zoneFrac,
            heightFactor: zoneFrac,
            child: Opacity(
              opacity: 0.28,
              child: FittedBox(
                child: const Text(
                  'X2',
                  style: TextStyle(
                    color: Color(0xFF92660A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Hamle çerçevesinin puan rozeti — kümenin en üst-sol hücresinde
  /// (taşın kendi puan üst simgesiyle çakışmasın diye, web ile aynı kural).
  Widget _moveBadge() {
    final overlay = moveOverlay!;
    Cell? badge;
    for (final cell in overlay.cells) {
      if (badge == null ||
          cell.$1 < badge.$1 ||
          (cell.$1 == badge.$1 && cell.$2 < badge.$2)) {
        badge = cell;
      }
    }
    final color =
        overlay.valid ? const Color(0xFF1FA05C) : const Color(0xFFE0483A);
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = badge!.$2 / boardSize * constraints.maxWidth;
        final top = badge.$1 / boardSize * constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              child: FractionalTranslation(
                translation: const Offset(-0.35, -0.35),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Text(
                    '+${overlay.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OutlinesPainter extends CustomPainter {
  /// Izgara birimi (0..13) cinsinden path + renk çiftleri.
  final List<(Path, Color)> outlines;
  _OutlinesPainter(this.outlines);

  @override
  void paint(Canvas canvas, Size size) {
    final m = Matrix4.diagonal3Values(
        size.width / boardSize, size.height / boardSize, 1);
    for (final (path, color) in outlines) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _outlineStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      canvas.drawPath(path.transform(m.storage), paint);
    }
  }

  @override
  bool shouldRepaint(_OutlinesPainter oldDelegate) => true;
}

/// Başlangıç hücresindeki ev işareti — web'deki HomeMark SVG path'inin portu
/// (M12 2.5 L1.5 11 H4.5 V21 H10.5 V15 H13.5 V21 H19.5 V11 H22.5 Z).
class _HomeMarkPainter extends CustomPainter {
  final Color color;
  _HomeMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24, sy = size.height / 24;
    final path = Path()
      ..moveTo(12 * sx, 2.5 * sy)
      ..lineTo(1.5 * sx, 11 * sy)
      ..lineTo(4.5 * sx, 11 * sy)
      ..lineTo(4.5 * sx, 21 * sy)
      ..lineTo(10.5 * sx, 21 * sy)
      ..lineTo(10.5 * sx, 15 * sy)
      ..lineTo(13.5 * sx, 15 * sy)
      ..lineTo(13.5 * sx, 21 * sy)
      ..lineTo(19.5 * sx, 21 * sy)
      ..lineTo(19.5 * sx, 11 * sy)
      ..lineTo(22.5 * sx, 11 * sy)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_HomeMarkPainter oldDelegate) => oldDelegate.color != color;
}
