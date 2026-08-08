// Tahta taşı harf/puan puntosu — web `Tile.tsx`'in EKRAN GENİŞLİĞİNE (vw)
// bağlı `clamp()` sistemiyle birebir eşleşmeli: rafta sabit (24/10px),
// tahtada `clamp(14px,3.8vw,24px)`/`clamp(6px,1.6vw,10px)`. 8 Ağustos
// 2026'da kullanıcı web (kelimeki.com) ile app (alpcapa.github.io) ekran
// görüntülerini yan yana koyup "taş fontları farklı, web daha büyük mi?"
// diye sordu — iPad gibi geniş bir ekranda (vw eşiği 631px'i aşınca) web
// harfi 24px'e kilitlenirken port sabit 20px kullanıyordu (bkz. mobile/
// CLAUDE.md Parça 24). Testler formülü doğrudan `fluidSize` ile değil,
// GERÇEK render edilmiş `Text` widget'ının `fontSize`'ından okuyarak
// doğruluyor — yardımcı fonksiyonun kendisiyle "aynı formülü" karşılaştırıp
// hiçbir şey kanıtlamayan bir tautoloji kurmamak için.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/player_colors.dart';
import 'package:kelimeki/src/ui/game/tile_widget.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_view.dart';

Tile _tile(String letter, int pts) => Tile(letter: letter, pts: pts);

Future<double> _letterFontSizeAt(
    WidgetTester tester, double screenWidth, TileVariant variant,
    {PlayerColor? color}) async {
  await setPhoneViewSize(tester, Size(screenWidth, 800));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 60,
        height: 60,
        child: TileWidget(tile: _tile('A', 1), variant: variant, color: color),
      ),
    ),
  ));
  await tester.pump();
  // Kontur+dolgu katmanı aynı harfi iki kez çizer (bkz. proje geneli
  // "find.text(...).first" dersi) — ikisi de aynı letterStyle'ı paylaşır.
  final texts = tester.widgetList<Text>(find.text('A'));
  return texts.first.style!.fontSize!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final board = playerColors[0];

  testWidgets(
      'tahta harfi GENİŞ ekranda (iPad, >631px) web gibi 24px tavana kilitlenir '
      '— önceki sabit 20px BURADA gerçekten farklı çıkardı', (tester) async {
    final size = await _letterFontSizeAt(tester, 1024, TileVariant.board,
        color: board);
    expect(size, 24);
  });

  testWidgets(
      'tahta harfi DAR ekranda (iPhone, 390px) web`in ölçeğiyle ~14.8px olur '
      '— sabit 20px yerine küçülüyor (13x13 ızgarada web de aynı şekilde küçük)',
      (tester) async {
    final size = await _letterFontSizeAt(tester, 390, TileVariant.board,
        color: board);
    expect(size, closeTo(14.82, 0.01));
  });

  testWidgets('tahta harfi 631px altında TABANA (14px) kilitlenir',
      (tester) async {
    final size = await _letterFontSizeAt(tester, 300, TileVariant.board,
        color: board);
    expect(size, 14);
  });

  testWidgets('raf harfi ekran genişliğinden ETKİLENMEZ — web`de de sabit',
      (tester) async {
    final narrow = await _letterFontSizeAt(tester, 320, TileVariant.rack);
    final wide = await _letterFontSizeAt(tester, 1024, TileVariant.rack);
    expect(narrow, 24);
    expect(wide, 24);
  });

  testWidgets(
      'puan üst simgesi de aynı vw sistemini paylaşır — geniş ekranda 10px tavanı',
      (tester) async {
    await setPhoneViewSize(tester, const Size(1024, 800));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 60,
          height: 60,
          child: TileWidget(
              tile: _tile('A', 7), variant: TileVariant.board, color: board),
        ),
      ),
    ));
    await tester.pump();
    final ptsText = tester.widget<Text>(find.text('7'));
    expect(ptsText.style!.fontSize, 10);
  });
}
