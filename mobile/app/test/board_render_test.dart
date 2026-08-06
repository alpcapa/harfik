// BoardWidget render testi — golden fixture'daki GERÇEK bir bitmiş oyun
// (reducer_ai4: teslim olmuş oyuncu, bölge dış hatları, dolu tahta) çizilir;
// hata fırlamadığı ve taş sayısının state'le eşleştiği doğrulanır. Ayrıca
// PNG ekran görüntüleri build/screenshots/ altına yazılır (görsel inceleme
// için — commit edilmez, build/ gitignore'da).
//
// Not: flutter_test varsayılan fontu metinleri blok (Ahem) çizer — ekran
// görüntüsü okunur olsun diye Flutter SDK'nın kendi Roboto'su FontLoader'la
// yüklenir; bulunamazsa görüntü yine üretilir (bloklu), test geçer.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/tile_widget.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';

GameState loadFixtureState(String name) {
  final golden = jsonDecode(
    File('../kelimeki_core/test/goldens/$name.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final steps = golden['steps'] as List;
  final last = (steps.last as Map)['state'] as Map;
  return gameStateFromJson(last.cast<String, Object?>());
}

Future<void> capturePng(
    WidgetTester tester, GlobalKey key, String outPath) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File(outPath);
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> pumpBoard(WidgetTester tester, GlobalKey key, GameState state,
    {MoveOverlay? overlay}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
        fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: RepaintBoundary(
          key: key,
          // Beyaz zemin boundary'nin İÇİNDE olmalı ve pay gölgelerin tam
          // sönümlenmesine yetmeli — aksi halde PNG'de gölgeler saydam zemin
          // üzerine ham yarı-şeffaf gri kaydedilip kesiliyor ve "kalın gri
          // levha" gibi görünüyordu (kullanıcı bildirimi, 6 Ağustos 2026).
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(90),
              child: SizedBox(
                width: 560,
                height: 560,
                // Bu testler yalnızca IZGARA render'ını ölçer; kartın alt
                // bilgi şeridi (Hamleler/X2-X3) sabit 560×560 kutuya
                // sığmayacağından kapatılır — şeridin kendi testi
                // move_history_test.dart'ta.
                child: BoardWidget(
                    state: state, moveOverlay: overlay, hideFooter: true),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoIfAvailable);

  testWidgets('reducer_ai4 final tahtası hatasız çizilir, taş sayısı tutar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 760));
    final state = loadFixtureState('reducer_ai4');
    var tileCount = 0;
    for (final row in state.board) {
      for (final t in row) {
        if (t != null) tileCount++;
      }
    }
    expect(tileCount, greaterThan(30)); // gerçekten dolu bir tahta

    final key = GlobalKey();
    await pumpBoard(tester, key, state);
    expect(tester.takeException(), isNull);
    expect(find.byType(TileWidget), findsNWidgets(tileCount));

    await capturePng(tester, key, 'build/screenshots/board_ai4.png');
  });

  testWidgets('hamle çerçevesi + puan rozeti çizilir (geçerli/yeşil)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 760));
    final state = loadFixtureState('reducer_ai2');
    final overlay = MoveOverlay(
      valid: true,
      cells: state.lastMoveCells,
      score: 23,
    );
    final key = GlobalKey();
    await pumpBoard(tester, key, state, overlay: overlay);
    expect(tester.takeException(), isNull);
    expect(find.text('+23'), findsOneWidget);

    await capturePng(tester, key, 'build/screenshots/board_ai2_overlay.png');
  });
}
