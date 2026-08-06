// Kalan (dışarıdaki) taşlar dökümü — src/components/RemainingTilesModal.tsx
// portu. Tahtada olmayan ve bakan oyuncuda bulunmayan taşlar (torba +
// rakipler); tükenen harfler soluk. myIndex state.current DEĞİL — modal
// YZ'nin sırasında da açılabilir (web'deki aynı not).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'tile_widget.dart';

Future<void> showRemainingTilesModal(
    BuildContext context, GameState state, int myIndex) {
  return showDialog<void>(
    context: context,
    builder: (context) => RemainingTilesModal(state: state, myIndex: myIndex),
  );
}

class RemainingTilesModal extends StatelessWidget {
  final GameState state;
  final int myIndex;
  const RemainingTilesModal(
      {super.key, required this.state, required this.myIndex});

  @override
  Widget build(BuildContext context) {
    final myRack =
        myIndex < state.players.length ? state.players[myIndex].rack : <Tile>[];
    final rows = remainingTiles(state.board, myRack);
    var total = 0;
    for (final r in rows) {
      total += r.count;
    }

    return Dialog(
      backgroundColor: const Color(0xFFF5F7FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kalan Taşlar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2430),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                text: 'Tahtada olmayan ve sende bulunmayan taşlar '
                    '(torba + rakipler). Toplam ',
                children: [
                  TextSpan(
                    text: '$total',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const TextSpan(text: ' taş dışarıda.'),
                ],
              ),
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 10,
                height: 1.5,
                color: Color(0xFF5A6673),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.05,
                  children: [
                    for (final r in rows)
                      Opacity(
                        opacity: r.count == 0 ? 0.3 : 1,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: TileWidget(
                                tile: Tile(letter: r.letter, pts: r.pts),
                                variant: TileVariant.rack,
                              ),
                            ),
                            // Kalan adet — harfin altında (puan sağ üstte).
                            Positioned(
                              bottom: 3,
                              left: 0,
                              right: 0,
                              child: Text(
                                '×${r.count}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  height: 1,
                                  color: Color(0xFF8B5E00),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
