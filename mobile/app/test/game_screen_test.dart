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
import 'package:kelimeki/src/ui/game/game_over_modal.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/game/rack_widget.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

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

// Hücre/raf taşları artık ValueKey taşıyor — sürükleme parçasıyla raf
// taşları ve yerleştirilmiş hücreler GestureDetector'dan Listener'a geçti,
// tip tabanlı indeksleme iki widget türü arasında kayardı.
Finder rackTile(int i) => find.byKey(ValueKey('rack-$i'));

Finder boardCell(int r, int c) => find.byKey(ValueKey('cell-$r-$c'));

Future<GameController> pumpGame(WidgetTester tester, GlobalKey key) async {
  final controller = GameController(words: words, autoPlayAi: false, nowIso: () => '');
  controller.dispatch(ResumeSavedAction(craftedState()));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
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
    await setPhoneViewSize(tester, const Size(420, 900));
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
    expect(find.text('Oyna tuşuyla kelimeyi onayla.'), findsOneWidget);

    // Bayat mesaj türetilmiş metni EZEMEZ (web'de kullanıcı buldu): taş
    // seçmeden boş hücreye dokunmak reducer'a "Önce bir harf seç." yazar ama
    // taslak geçerliyken satır yine "Oyna tuşuyla kelimeyi onayla." demeli.
    await tester.tap(boardCell(5, 5));
    await tester.pump();
    expect(controller.state.message, 'Önce bir harf seç.');
    expect(find.text('Oyna tuşuyla kelimeyi onayla.'), findsOneWidget);
    expect(find.text('Önce bir harf seç.'), findsNothing);
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
    await setPhoneViewSize(tester, const Size(420, 900));
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
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(rackTile(6)); // '?' (rafta ★)
    await tester.pump();
    await tester.tap(boardCell(1, 0));
    await tester.pumpAndSettle();
    expect(find.text('Joker Hangi Harf Olsun?'), findsOneWidget);
    // Kontur katmanı her taş harfini iki Text yapar (stroke+dolgu, aynı taş)
    // — .first ikisinden birine dokunmak için yeterli.
    await tester.tap(find.text('B').first);
    await tester.pumpAndSettle();
    final placed = controller.state.placed['1,0'];
    expect(placed, isNotNull);
    expect(placed!.wild, isTrue);
    expect(placed.wildLetter, 'B');

    // Yerleştirilmiş jokere dokunmak taşı GERİ ALMAZ — seçici yeniden açılır.
    await tester.tap(boardCell(1, 0));
    await tester.pumpAndSettle();
    expect(find.text('Jokeri Hangi Harfe Çevir?'), findsOneWidget);
    await tester.tap(find.text('Ç').first);
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

  testWidgets('taş değiştirme akışı: DEĞİŞTİR → seç (N) → onayla → sıra YZ\'de',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    final controller = await pumpGame(tester, key);

    await tester.tap(find.text('DEĞİŞTİR'));
    await tester.pump();
    expect(controller.state.swapMode, isTrue);
    // Swap modunda OYNA gizli, satır DEĞİŞTİR/VAZGEÇ'e döner (web düzeni).
    expect(find.text('OYNA'), findsNothing);
    expect(find.text('VAZGEÇ'), findsOneWidget);
    expect(find.textContaining('değiştirilecek taşları seç'), findsOneWidget);

    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(rackTile(2));
    await tester.pump();
    expect(controller.state.swapSelection, [0, 2]);
    expect(find.text('DEĞİŞTİR (2)'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_screen_swap.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    final bagBefore = controller.state.bag.length;
    await tester.tap(find.text('DEĞİŞTİR (2)'));
    await tester.pump();
    expect(controller.state.swapMode, isFalse);
    expect(controller.state.players[0].rack.length, 7);
    expect(controller.state.bag.length, bagBefore); // 2 çek + 2 iade
    expect(controller.state.current, 1); // değişim sırayı devreder
    expect(controller.state.consecutivePasses, 1); // puansız tur sayacı
  });

  testWidgets('VAZGEÇ swap modundan işlemsiz çıkar', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(find.text('DEĞİŞTİR'));
    await tester.pump();
    await tester.tap(rackTile(1));
    await tester.pump();
    await tester.tap(find.text('VAZGEÇ'));
    await tester.pump();
    expect(controller.state.swapMode, isFalse);
    expect(controller.state.swapSelection, isEmpty);
    expect(controller.state.current, 0); // sıra devretmedi
  });

  testWidgets('TORBA butonu Kalan Taşlar dökümünü açar', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());

    await tester.tap(find.text('TORBA 6'));
    await tester.pumpAndSettle();
    expect(find.text('Kalan Taşlar'), findsOneWidget);
    // Dağılım 100 − tahta 0 − benim rafım 7 = 93 taş dışarıda.
    expect(find.textContaining('93'), findsOneWidget);
  });

  testWidgets('oyun bitince GameOver modalı: kazanan + Teslim + YENİ OYUN',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final golden = jsonDecode(
      File('../kelimeki_core/test/goldens/reducer_ai4.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final steps = golden['steps'] as List;
    final finished = gameStateFromJson(
        ((steps.last as Map)['state'] as Map).cast<String, Object?>());
    expect(finished.isGameOver, isTrue);

    final controller =
        GameController(words: words, autoPlayAi: false, nowIso: () => '');
    controller.restore(finished);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: GameScreen(controller: controller, words: words),
    ));
    await tester.pumpAndSettle();

    // Fixture: Yapay Zeka 2 kazanır (162), Yapay Zeka 3 teslim olmuştur.
    expect(find.text('YAPAY ZEKA 2 KAZANDI'), findsOneWidget);
    expect(find.text('(TESLİM)'), findsOneWidget);
    expect(find.text('Toplam hamle'), findsOneWidget);

    await tester.tap(find.text('KAPAT'));
    await tester.pumpAndSettle();
    expect(find.text('YAPAY ZEKA 2 KAZANDI'), findsNothing);
    // Modal kapanınca tahta görünür kalır, raf satırında YENİ OYUN çıkar.
    expect(find.textContaining('YENİ'), findsOneWidget);
  });

  testWidgets(
      'sürükle-bırak: raftan tahtaya + tahtada taşıma + rafa geri alma',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    final controller = await pumpGame(tester, key);

    // 1) Raftan (0,0)'a sürükle. DRAG_LIFT telafisi: hayalet/bırakma hedefi
    // parmağın 30px ÜZERİNDE hesaplanır — hedef hücre merkezinin +30
    // altına bırakılır (web Playwright testindeki aynı ders,
    // mobile/CLAUDE.md "Test notu").
    final start = tester.getCenter(rackTile(0)); // K
    final target = tester.getCenter(boardCell(0, 0)) + const Offset(0, 30);
    final g = await tester.startGesture(start);
    await g.moveTo(start + const Offset(0, -40)); // eşik aşılır
    await tester.pump();
    await g.moveTo(target);
    await tester.pump();
    // Sürükleme sırasında: kaynak raf taşı gizli (opacity 0), taş henüz
    // yerleşmedi.
    expect(controller.state.placed, isEmpty);
    final hidden = tester
        .widgetList<Opacity>(find.descendant(
            of: find.byType(RackWidget), matching: find.byType(Opacity)))
        .where((o) => o.opacity == 0);
    expect(hidden, hasLength(1));
    // Ekran görüntüsü: hayalet taş + kesikli hedef çerçevesi.
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_drag.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await g.up();
    await tester.pump();
    expect(controller.state.placed['0,0']?.letter, 'K');
    expect(controller.state.players[0].rack.length, 6);

    // 2) Tahtada taşı: (0,0) → (2,2).
    final from = tester.getCenter(boardCell(0, 0));
    final to = tester.getCenter(boardCell(2, 2)) + const Offset(0, 30);
    final g2 = await tester.startGesture(from);
    await g2.moveTo(from + const Offset(0, 40));
    await tester.pump();
    await g2.moveTo(to);
    await tester.pump();
    await g2.up();
    await tester.pump();
    expect(controller.state.placed['0,0'], isNull);
    expect(controller.state.placed['2,2']?.letter, 'K');

    // 3) Tahtadan rafa sürükleyerek geri al.
    final from2 = tester.getCenter(boardCell(2, 2));
    final rackTarget =
        tester.getCenter(find.byType(RackWidget)) + const Offset(0, 30);
    final g3 = await tester.startGesture(from2);
    await g3.moveTo(from2 + const Offset(0, 40));
    await tester.pump();
    await g3.moveTo(rackTarget);
    await tester.pump();
    await g3.up();
    await tester.pump();
    expect(controller.state.placed, isEmpty);
    expect(controller.state.players[0].rack.length, 7);

    // 4) Dolu hücreye bırakma reddedilir: iki taş koy, birini diğerinin
    // üstüne sürükle — hiçbir şey değişmemeli.
    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(0, 0));
    await tester.pump();
    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(0, 1));
    await tester.pump();
    expect(controller.state.placed.length, 2);
    final a = tester.getCenter(boardCell(0, 0));
    final b = tester.getCenter(boardCell(0, 1)) + const Offset(0, 30);
    final g4 = await tester.startGesture(a);
    await g4.moveTo(a + const Offset(0, 40));
    await tester.pump();
    await g4.moveTo(b);
    await tester.pump();
    await g4.up();
    await tester.pump();
    expect(controller.state.placed['0,0'], isNotNull);
    expect(controller.state.placed['0,1'], isNotNull);
  });

  testWidgets('GameOver modalı ekran görüntüsü (beraberlik varyantı yok)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(520, 700));
    final golden = jsonDecode(
      File('../kelimeki_core/test/goldens/reducer_ai4.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final steps = golden['steps'] as List;
    final finished = gameStateFromJson(
        ((steps.last as Map)['state'] as Map).cast<String, Object?>());

    final key = GlobalKey();
    // Dialog overlay'i Navigator'da yaşadığından ekran görüntüsü için modal
    // doğrudan bir widget olarak (showDialog'suz) çizilir.
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'SpaceGrotesk'),
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: Colors.white,
          child: Center(child: GameOverModal(state: finished)),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_over.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
