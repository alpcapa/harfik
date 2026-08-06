// GameScreen etkileşim testleri — dokunarak taş yerleştirme, canlı
// geçerlilik çerçevesi, joker akışı, geri alma ve OYNA. Kontrollü raf için
// state ResumeSavedAction ile kurulur (golden üreticisindeki aynı desen);
// sözlük gerçek asset dosyasından yüklenir.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/game/rack_widget.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';

late SetWordSource words;

Tile t(String letter) => Tile(letter: letter, pts: letterPoints(letter));

Player player(String name, {required bool isAI, required int index, required List<Tile> rack}) =>
    Player(
      name: name,
      corners: cornersFor(2)[index],
      colorIndex: index,
      isAI: isAI,
      surrendered: false,
      rack: rack,
      score: 0,
      bestMoveScore: 0,
      bestWordScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    );

GameState craftedState() => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: [t('A'), t('T'), t('R'), t('N'), t('E'), t('K')],
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        player('Sen', isAI: false, index: 0,
            rack: [t('K'), t('E'), t('L'), t('İ'), t('M'), t('E'), const Tile(letter: '?', pts: 0)]),
        player('Yapay Zeka', isAI: true, index: 1,
            rack: [t('A'), t('A'), t('A'), t('A'), t('A'), t('A'), t('A')]),
      ],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 2, // her iki taraf da "ilk hamle" durumunda değilmiş gibi
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

Finder rackTile(int i) => find
    .descendant(of: find.byType(RackWidget), matching: find.byType(GestureDetector))
    .at(i);

Finder boardCell(int r, int c) => find
    .descendant(of: find.byType(BoardWidget), matching: find.byType(GestureDetector))
    .at(r * boardSize + c);

Future<GameController> pumpGame(WidgetTester tester, GlobalKey key) async {
  final controller = GameController(words: words, autoPlayAi: false, nowIso: () => '');
  controller.dispatch(ResumeSavedAction(craftedState()));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Roboto'),
    home: RepaintBoundary(
      key: key,
      child: GameScreen(controller: controller, words: words),
    ),
  ));
  await tester.pump();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadRobotoIfAvailable();
    final f = File('assets/dictionary/words_tr.txt');
    words = SetWordSource(const LineSplitter()
        .convert(f.readAsStringSync())
        .where((w) => w.isNotEmpty));
    expect(words.contains('kelime'), isTrue); // test kelimesi sözlükte olmalı
  });

  testWidgets('dokunarak KELİME dizilir: yeşil çerçeve + doğru puan + OYNA',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final key = GlobalKey();
    final controller = await pumpGame(tester, key);

    // Raf K,E,L,İ,M,E,? — hep 0. taşı seçip sırayla (0,0)..(0,5)'e koymak
    // KELİME'yi dizer (yerleşen taş raftan düştüğünden 0. indeks kayar).
    for (var c = 0; c < 6; c++) {
      await tester.tap(rackTile(0));
      await tester.pump();
      await tester.tap(boardCell(0, c));
      await tester.pump();
    }
    expect(controller.state.placed.length, 6);
    // KELİME = 1+1+1+1+2+1 = 7; 0. satır bonus bölgesi dışında → çarpan yok.
    expect(find.text('+7'), findsOneWidget);
    // Ekran görüntüsü: yeşil çerçeveli taslak hamle + raf + butonlar.
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_screen_kelime.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    await tester.tap(find.text('OYNA'));
    await tester.pumpAndSettle();
    expect(controller.state.players[0].score, 7);
    expect(controller.state.players[0].longestWord, 'KELİME');
    expect(controller.state.placed, isEmpty);
    expect(controller.state.current, 1); // sıra YZ'de (autoPlayAi kapalı)
  });

  testWidgets('geçersiz dizilim: kırmızı sebep mesajı + geri alma',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(rackTile(0)); // K
    await tester.pump();
    await tester.tap(boardCell(0, 0));
    await tester.pump();
    await tester.tap(rackTile(3)); // M (K düşünce raf E,L,İ,M,...)
    await tester.pump();
    await tester.tap(boardCell(0, 1));
    await tester.pump();

    expect(words.contains('km'), isFalse);
    expect(find.text('"KM" geçerli bir kelime değil.'), findsOneWidget);

    // Joker olmayan yerleştirilmiş taşa dokunmak geri alır (web davranışı).
    await tester.tap(boardCell(0, 1));
    await tester.pump();
    expect(controller.state.placed.length, 1);
    expect(controller.state.players[0].rack.length, 6);

    await tester.tap(find.text('GERİ AL'));
    await tester.pump();
    expect(controller.state.placed, isEmpty);
    expect(controller.state.players[0].rack.length, 7);
  });

  testWidgets('joker akışı: harf seçici → yerleştir → düzenle → geri al',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(rackTile(6)); // '?' (rafta ★)
    await tester.pump();
    await tester.tap(boardCell(1, 0));
    await tester.pumpAndSettle();
    expect(find.text('Joker Hangi Harf Olsun?'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    final placed = controller.state.placed['1,0'];
    expect(placed, isNotNull);
    expect(placed!.wild, isTrue);
    expect(placed.wildLetter, 'B');

    // Yerleştirilmiş jokere dokunmak taşı GERİ ALMAZ — seçici yeniden açılır.
    await tester.tap(boardCell(1, 0));
    await tester.pumpAndSettle();
    expect(find.text('Jokeri Hangi Harfe Çevir?'), findsOneWidget);
    await tester.tap(find.text('Ç'));
    await tester.pumpAndSettle();
    expect(controller.state.placed['1,0']!.wildLetter, 'Ç');

    // Düzenleme modundaki "Geri Al" butonu taşı rafa döndürür.
    await tester.tap(boardCell(1, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wild-recall')));
    await tester.pumpAndSettle();
    expect(controller.state.placed, isEmpty);
    expect(controller.state.players[0].rack.any((t) => t.letter == '?'), isTrue);
  });
}
