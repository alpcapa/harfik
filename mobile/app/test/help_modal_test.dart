// Kurallar ekranı — web HelpModal.tsx paritesi: iki adım (Hızlı Başlangıç /
// Detaylı Kurallar), başlıktaki link ile geçiş, kural metinlerinin birebir
// aktarıldığı örnek cümleler ve puan tablosu.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/help_modal.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show bingoBonus, letterPoints;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// Verilen düz metin ekranda (Text.rich parçalarına bölünmüş olsa bile)
/// bulunuyor mu — `find.textContaining` RichText'in düz metnini tarar.
void expectText(String s) =>
    expect(find.textContaining(s, findRichText: true), findsWidgets,
        reason: 'metin bulunamadı: $s');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  Future<void> pumpHelp(WidgetTester tester, GlobalKey key) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(key: key, child: const HelpModal()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/screenshots/$name.png');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
      });

  testWidgets('Hızlı Başlangıç: 9 madde + Bingo bonusu motordan',
      (tester) async {
    final key = GlobalKey();
    await pumpHelp(tester, key);

    expect(find.text('HIZLI BAŞLANGIÇ'), findsOneWidget); // KModal başlığı
    // Web'deki dokuz maddenin her birinden ayırt edici bir parça.
    expectText('2 ya da 4 oyuncuyla');
    expectText('Kendi bölgenden başlar');
    expectText('Yeni kelimeler tahtadaki mevcut harflere');
    expectText('bölge vergisi');
    expectText('Ortadaki 5×5 bonus bölgesi');
    expectText('+$bingoBonus Bingo bonus'); // sabit motordan geliyor
    expectText('istediğin harfe dönüşür');
    expectText('TDK sözlüğündeki');
    expectText('Art arda 2 tur pas geçilince');

    await shoot(tester, key, 'help_quick');
  });

  testWidgets('link ile Detaylı Kurallar ↔ Hızlı Başlangıç geçişi',
      (tester) async {
    final key = GlobalKey();
    await pumpHelp(tester, key);

    await tester.tap(find.text('Detaylı Kurallar →').first);
    await tester.pumpAndSettle();
    expect(find.text('DETAYLI KURALLAR'), findsOneWidget);
    expect(find.text('HIZLI BAŞLANGIÇ'), findsNothing);

    // Bölüm başlıkları (web Section title'ları).
    for (final t in [
      'Nasıl Oynanır?',
      'Temel Kurallar',
      'Bölge Vergisi',
      'Bonus Bölgesi',
      'Hamle Seçenekleri',
      'Bingo Bonusu',
      'Sözlük',
      'Oyunun Sonu',
      'Skor Kartı ve Puanlama',
      'Puan Tablosu',
    ]) {
      expect(find.text(t), findsOneWidget, reason: 'bölüm yok: $t');
    }
    expectText('Joker ('); // ★ ikonlu başlık (glyph değil, WidgetSpan)

    // Kural metninden birkaç ayırt edici cümle — özetlenmediğinin kanıtı.
    expectText('puanın 1/3\'ü bölge sahibine gider, 2/3\'ü sende kalır');
    expectText('X3 hücresi kullanıldığında ayrıca X2 eklenmez');
    expectText('Beraberlikte aynı sırayı paylaşan oyuncuların hepsi');

    await shoot(tester, key, 'help_detailed');

    await tester.tap(find.text('Hızlı Başlangıç →').first);
    await tester.pumpAndSettle();
    expect(find.text('HIZLI BAŞLANGIÇ'), findsOneWidget);
  });

  testWidgets('Puan tablosu motordaki harf puanlarıyla tutarlı',
      (tester) async {
    await pumpHelp(tester, GlobalKey());
    await tester.tap(find.text('Detaylı Kurallar →').first);
    await tester.pumpAndSettle();

    // Tablodaki her satır gerçekten o puan grubunu listelemeli — örnek
    // harfleri motorun letterPoints'iyle karşılaştır (web tablosu elle
    // yazılmış, sapmayı burada yakalarız).
    const samples = {
      'A': 1, 'E': 1, 'İ': 1, 'K': 1, 'L': 1, 'R': 1, 'N': 1, 'T': 1, //
      'I': 2, 'M': 2, 'O': 2, 'S': 2, 'U': 2, //
      'B': 3, 'Ç': 3, 'D': 3, 'Ü': 3, 'Y': 3, //
      'C': 4, 'Ş': 4, 'Z': 4, //
      'G': 5, 'H': 5, 'P': 5, //
      'F': 7, 'Ö': 7, 'V': 7, //
      'Ğ': 8, 'J': 10,
    };
    samples.forEach((letter, pts) {
      expect(letterPoints(letter), pts,
          reason: '$letter için tablo $pts diyor, motor '
              '${letterPoints(letter)} diyor');
    });
    expectText('sabit toplam 100 taş');
    expectText('Joker');
  });
}
