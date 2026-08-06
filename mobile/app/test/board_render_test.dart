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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/tile_widget.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

GameState loadFixtureState(String name) {
  final golden = jsonDecode(
    File('../kelimeki_core/test/goldens/$name.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final steps = golden['steps'] as List;
  final last = (steps.last as Map)['state'] as Map;
  return gameStateFromJson(last.cast<String, Object?>());
}

Future<void> loadRobotoIfAvailable() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    final f = File('${dir.path}/$name');
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await loader.load();
}

Future<void> capturePng(WidgetTester tester, GlobalKey key, String outPath) async {
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
    theme: ThemeData(fontFamily: 'Roboto'),
    home: Scaffold(
      backgroundColor: const Color(0xFFEDF1F7),
      body: Center(
        child: RepaintBoundary(
          key: key,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 560,
              height: 560,
              child: BoardWidget(state: state, moveOverlay: overlay),
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
    await tester.binding.setSurfaceSize(const Size(700, 700));
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
    await tester.binding.setSurfaceSize(const Size(700, 700));
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
