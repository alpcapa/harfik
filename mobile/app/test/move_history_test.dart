// Hamle geçmişi modalı — web MoveHistoryModal.tsx paritesi.
// İki katman: (1) zengin bir moveHistory ile modalın kendisi (tüm rozetler
// + vergi satırı filtresi + ekran görüntüsü), (2) GameScreen'den gerçek bir
// hamle sonrası Board footer'daki "Hamleler" linkiyle açılış.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/game/move_history_modal.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

late SetWordSource words;

Tile t(String letter) => Tile(letter: letter, pts: letterPoints(letter));

Player player(String name,
        {required bool isAI, required int index, required List<Tile> rack}) =>
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

/// Web'deki tüm gösterim dallarını tek listede toplayan geçmiş: çarpanlı
/// kelime hamlesi, bingo, jokerli bitiş, bölge vergisi (hem kaptıran hem
/// GÖSTERİLMEYEN gelir satırı), pas ve taş değiştirme.
const _history = [
  HistoryEntry(
    turn: 0,
    player: 0,
    words: ['KELİME'],
    wordScores: [WordScore(word: 'KELİME', score: 7, x2: false, x3: false)],
    points: 7,
  ),
  HistoryEntry(turn: 1, player: 1, words: [], points: 0, action: 'pass'),
  HistoryEntry(
    turn: 2,
    player: 0,
    words: ['MASA', 'AS'],
    wordScores: [
      WordScore(word: 'MASA', score: 6, x2: true, x3: false),
      WordScore(word: 'AS', score: 3, x2: false, x3: false),
    ],
    points: 15,
    lostShares: [LostShare(to: 1, amount: 5)],
  ),
  // Vergi GELİRİ satırı — web'de ayrı kart olarak GÖSTERİLMEZ ve hamle
  // sayısına katılmaz (invasionFrom dolu).
  HistoryEntry(turn: 2, player: 1, words: [], points: 5, invasionFrom: 0),
  HistoryEntry(
      turn: 3,
      player: 1,
      words: [],
      points: 0,
      action: 'exchange',
      tileCount: 3),
  HistoryEntry(
    turn: 4,
    player: 0,
    words: ['YILDIZ'],
    wordScores: [WordScore(word: 'YILDIZ', score: 12, x2: false, x3: true)],
    points: 36,
    bingo: true,
    finishJokerCount: 2,
  ),
];

GameState _stateWithHistory() => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: [t('A'), t('T'), t('R'), t('N'), t('E'), t('K')],
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        player('Ironman', isAI: false, index: 0, rack: [t('K'), t('E')]),
        player('Yapay Zeka', isAI: true, index: 1, rack: [t('A'), t('A')]),
      ],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 5,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: _history,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
    final f = File('assets/dictionary/words_tr.txt');
    words = SetWordSource(const LineSplitter()
        .convert(f.readAsStringSync())
        .where((w) => w.isNotEmpty));
  });

  testWidgets('modal: rozetler, vergi satırı filtresi, ters sıra',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(
        key: key,
        child: MoveHistoryModal(state: _stateWithHistory()),
      ),
    ));
    await tester.pumpAndSettle();

    // Puan toplamı TÜM satırlardan (vergi geliri dahil, web'deki gibi):
    // 7 + 0 + 15 + 5 + 0 + 36 = 63. Hamle sayısı ise yalnızca gösterilen
    // ve aksiyonsuz olanlar: KELİME, MASA, YILDIZ = 3.
    // (Text.rich olduğundan düz metin üzerinden aranır.)
    expect(find.textContaining('kazanılan 3 hamle'), findsOneWidget);
    expect(find.textContaining('Toplam 63 puan.'), findsOneWidget);

    // Aksiyon satırları web metinleriyle birebir.
    expect(find.text('Pas geçti'), findsOneWidget);
    expect(find.text('3 taş değiştirdi'), findsOneWidget);

    // Rozetler: Bingo, çift yıldız, sınır ihlali + çarpanlar.
    expect(find.text('Bingo'), findsOneWidget);
    // Jokerli bitiş rozeti: 2 joker → 2 yıldız ikonu (glyph değil, bkz.
    // move_history_modal.dart).
    expect(find.byIcon(Icons.star), findsNWidgets(2));
    expect(find.text('Sınır İhlali'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);

    // Açıklama satırları (bonus tutarları motordan hesaplanır).
    expect(
        find.text('Çift yıldız ile biterek +${jokerFinishBonus(2)} puan '
            'kazandı.'),
        findsOneWidget);
    expect(
        find.text('7 harfi birden koyup +$bingoBonus puan Bingo Bonus '
            'kazandı.'),
        findsOneWidget);
    expect(find.text('5 puanı Yapay Zeka kaptı'), findsOneWidget);

    // Vergi GELİRİ satırı ayrı bir kart açmaz: 2. tur yalnızca oynayanın
    // (Ironman) satırında görünür.
    expect(find.text('3. Yapay Zeka'), findsNothing);
    expect(find.text('3. Ironman'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/move_history.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  testWidgets('boş geçmiş: "Henüz kazanılmış bir puan yok."', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final empty = _stateWithHistory().copyWith(moveHistory: const []);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'SpaceGrotesk'),
      home: MoveHistoryModal(state: empty),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Henüz kazanılmış bir puan yok.'), findsOneWidget);
    expect(find.textContaining('kazanılan 0 hamle'), findsOneWidget);
  });

  testWidgets('Board footer: "Hamleler" oynanan hamleyi gösterir',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller =
        GameController(words: words, autoPlayAi: false, nowIso: () => '');
    controller.dispatch(ResumeSavedAction(GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: [t('A'), t('T'), t('R')],
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        player('Ironman',
            isAI: false,
            index: 0,
            rack: [t('K'), t('E'), t('L'), t('İ'), t('M'), t('E')]),
        player('Yapay Zeka', isAI: true, index: 1, rack: [t('A'), t('A')]),
      ],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 2,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    )));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: GameScreen(controller: controller, words: words),
    ));
    await tester.pump();

    for (var c = 0; c < 6; c++) {
      await tester.tap(find.byKey(const ValueKey('rack-0')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('cell-0-$c')));
      await tester.pump();
    }
    await tester.tap(find.text('OYNA'));
    await tester.pumpAndSettle();
    expect(controller.state.moveHistory.length, 1);

    await tester.tap(find.text('Hamleler'));
    await tester.pumpAndSettle();
    expect(find.text('OYUN GEÇMİŞİ'), findsOneWidget); // KModal başlığı
    expect(find.textContaining('KELİME (7'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);
  });
}
