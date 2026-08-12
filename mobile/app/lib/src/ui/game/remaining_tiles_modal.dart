// Kalan (dışarıdaki) taşlar dökümü — src/components/RemainingTilesModal.tsx
// portu. Tahtada olmayan ve bakan oyuncuda bulunmayan taşlar (torba +
// rakipler); tükenen harfler soluk. myIndex state.current DEĞİL — modal
// YZ'nin sırasında da açılabilir (web'deki aynı not).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'modal_shell.dart';
import 'tile_widget.dart';
import '../tokens.dart';

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

    return KModal(
      title: 'Kalan Taşlar',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Tahtada olmayan ve sende bulunmayan taşlar '
                  '(torba + rakipler). Toplam ',
              children: [
                TextSpan(
                  text: '$total',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                ),
                const TextSpan(text: ' taş dışarıda.'),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              height: 1.5,
              color: kMuted,
            ),
          ),
          const SizedBox(height: 12),
          // Web `grid grid-cols-5 gap-1.5` + hücre `h-12`: yükseklik SABİT
          // 48px, en-boy oranı DEĞİL — kart 360px'e sınırlı olduğundan
          // web'de hücre ~59×48 çıkıyor. Port kare hücre (oran 1.05)
          // kullanıp kendi Dialog'unu kurduğundan iPad'de kart ekrana
          // yayılıyor ve taşlar devleşiyordu (Parça 47'nin joker
          // seçicideki AYNI hatası).
          // `GridView.count` sabit yükseklik veremiyor (yalnızca en-boy
          // oranı) — Parça 47'de joker seçicide öğrenilen aynı sebeple
          // builder + `mainAxisExtent`.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              mainAxisExtent: 48,
            ),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              return Opacity(
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
              );
            },
          ),
        ],
      ),
    );
  }
}
