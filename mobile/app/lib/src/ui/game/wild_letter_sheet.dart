// Joker harf seçici — src/components/WildcardModal.tsx portu.
//
// **Yapı web'in BİREBİR aynısı: ortalanmış `KModal`** (web `Modal.tsx`), 6
// sütunlu ızgara, taş yüksekliği SABİT 44px (web `h-11`), editing modunda
// başlık değişir ve altta "GERİ AL" çıkar (web'deki aynı akış:
// yerleştirilmiş jokere dokunmak taşı GERİ ALMAZ, bu seçiciyi yeniden açar).
//
// 10 Ağustos 2026'ya kadar burada `showModalBottomSheet` vardı ve bu iki
// ayrı soruna yol açıyordu: (1) sheet'in kendi yükseklik sınırı içeriği
// kırpıyordu (Parça 20 bunu `isScrollControlled` ile yamamıştı — semptom
// düzeldi, yapı farkı kaldı); (2) sheet ekran genişliğini kapladığından
// `GridView.count`un KARE hücreleri iPad'de ~128px'e şişiyor, web'in 360px
// kartındaki ~48×44 taşlarıyla hiç benzeşmiyordu. KModal'a geçmek ikisini
// birden kökünden çözüyor — web'in düzenini uygulamak, sheet'i ayarlamaktan
// her zaman daha ucuza geldi (bkz. mobile/CLAUDE.md, "Sorun Bildirildiğinde
// İLK ADIM").
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show Tile, tileData;

import 'modal_shell.dart';
import 'neo_button.dart';
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
  return showDialog<WildLetterChoice>(
    context: context,
    builder: (context) => KModal(
      title: editing ? 'Jokeri Hangi Harfe Çevir?' : 'Joker Hangi Harf Olsun?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Web: `grid grid-cols-6 gap-1.5` + her hücre `h-11` (44px). Kare
          // bir GridView DEĞİL — yükseklik sabit, genişlik kartın 6'ya
          // bölünmüş payı kadar.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: letters.length,
            // `GridView.count` sabit yükseklik veremiyor (yalnızca en-boy
            // oranı) — web'in `h-11`i için mainAxisExtent şart.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              mainAxisExtent: 44,
            ),
            itemBuilder: (context, i) {
              final letter = letters[i];
              return GestureDetector(
                onTap: () => Navigator.of(context)
                    .pop(WildLetterChoice.letter(letter)),
                child: TileWidget(
                  tile: Tile(letter: letter, pts: tileData[letter]!.pts),
                  variant: TileVariant.rack,
                ),
              );
            },
          ),
          if (editing) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: NeoButton(
                key: const Key('wild-recall'),
                label: 'GERİ AL',
                variant: NeoButtonVariant.neutral,
                fontSize: 12,
                letterSpacing: 1,
                onPressed: () =>
                    Navigator.of(context).pop(const WildLetterChoice.recall()),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
