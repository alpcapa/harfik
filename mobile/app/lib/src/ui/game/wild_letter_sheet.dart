// Joker harf seçici — src/components/WildcardModal.tsx portu (alttan açılan
// sayfa olarak). Harfler tileData'dan ('?' hariç), 6 sütunlu ızgara; editing
// modunda başlık değişir ve "Geri Al" butonu çıkar (web'deki aynı akış:
// yerleştirilmiş jokere dokunmak taşı GERİ ALMAZ, bu seçiciyi yeniden açar).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show Tile, tileData;

import 'tile_widget.dart';

/// Seçilen harfi, `recallRequested` true ise geri-al isteğini döner;
/// kapatılırsa null.
class WildLetterChoice {
  final String? letter;
  final bool recallRequested;
  const WildLetterChoice.letter(String this.letter) : recallRequested = false;
  const WildLetterChoice.recall()
      : letter = null,
        recallRequested = true;
}

Future<WildLetterChoice?> showWildLetterSheet(
  BuildContext context, {
  bool editing = false,
}) {
  final letters = [
    for (final l in tileData.keys)
      if (l != '?') l,
  ];
  return showModalBottomSheet<WildLetterChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Jokeri Hangi Harfe Çevir?' : 'Joker Hangi Harf Olsun?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final letter in letters)
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pop(WildLetterChoice.letter(letter)),
                    child: TileWidget(
                      tile: Tile(letter: letter, pts: tileData[letter]!.pts),
                      variant: TileVariant.rack,
                    ),
                  ),
              ],
            ),
            if (editing) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('wild-recall'),
                onPressed: () =>
                    Navigator.of(context).pop(const WildLetterChoice.recall()),
                child: const Text('GERİ AL'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
