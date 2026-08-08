// Canlı oyun tahtası — OnlineGameScreen portunun testleri. Veri katmanı
// (loadGame/buildMoveHistory), GameController'ın koltuk sabitlemesi
// (actingSeat — Canlı'nın en ince kuralı) ve ekran akışları: sıra banner'ı,
// sıra bende değilken taş yerleştirme ("egzersiz"), gerçek hamle gönderimi,
// pas, YZ turu tetikleme, süre taraması, Realtime tazelenmesi.
// Gerçek RPC'ler/Realtime cihazda doğrulanacak (mobile/TESTING.md, bölüm 11).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart'
    show DashedBorderPainter;
import 'package:kelimeki/src/ui/live/online_game_screen.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/fake_online_gateway.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

late SetWordSource words;

Tile t(String letter) => Tile(letter: letter, pts: letterPoints(letter));

Player _player(String name,
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

/// Rafım: KELİME + joker (game_screen_test ile aynı kurulum — (0,0)'dan
/// başlayan KELİME köşe hücresine değer ve 7 puan eder).
List<Tile> get myRackTiles => [
      t('K'),
      t('E'),
      t('L'),
      t('İ'),
      t('M'),
      t('E'),
      const Tile(letter: '?', pts: 0),
    ];

GameState _baseState({bool opponentIsAi = false}) => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: List<Tile>.filled(60, const Tile(letter: 'A', pts: 1)),
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        _player('Ironman', isAI: false, index: 0, rack: myRackTiles),
        _player(opponentIsAi ? 'Yapay Zeka 2' : 'Esiner',
            isAI: opponentIsAi,
            index: 1,
            rack: List<Tile>.filled(7, const Tile(letter: 'A', pts: 1))),
      ],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 0,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

/// GameState → `online_game_states` satırının JSON şekli (sunucunun public
/// kopyası: raf YOK, yalnızca rackCount).
Map<String, Object?> stateJson(
  GameState s, {
  int? current,
  int? turnCount,
  bool isGameOver = false,
}) =>
    {
      'board': [
        for (final row in s.board) [for (final tile in row) tile?.toJson()]
      ],
      'bonuses': {for (final e in s.bonuses.entries) e.key: 'TW'},
      'players': [
        for (final p in s.players)
          {
            'name': p.name,
            'corners': p.corners,
            'colorIndex': p.colorIndex,
            'isAI': p.isAI,
            'surrendered': p.surrendered,
            'rackCount': p.rack.length,
            'score': p.score,
            'bestMoveScore': p.bestMoveScore,
            'bestWordScore': p.bestWordScore,
            'longestWord': p.longestWord,
            'moveCount': p.moveCount,
            'moveScoreSum': p.moveScoreSum,
          }
      ],
      'current': current ?? s.current,
      'turn_count': turnCount ?? s.turnCount,
      'consecutive_passes': s.consecutivePasses,
      'is_game_over': isGameOver,
      'end_reason': null,
      'last_move_cells': const <List<int>>[],
      'bag_count': s.bag.length,
      'started_at': s.startedAt,
    };

Finder rackTile(int i) => find.byKey(ValueKey('rack-$i'));
Finder boardCell(int r, int c) => find.byKey(ValueKey('cell-$r-$c'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
    final f = File('assets/dictionary/words_tr.txt');
    words = SetWordSource(const LineSplitter()
        .convert(f.readAsStringSync())
        .where((w) => w.isNotEmpty));
    expect(words.contains('kelime'), isTrue);
  });

  group('buildMoveHistory', () {
    test('bölge vergisi AYRI satır olur; pas/değiştir action taşır', () {
      final rows = [
        OnlineMoveRow(
          turn: 0,
          playerIndex: 0,
          action: 'play',
          words: const ['KELİME'],
          points: 7,
          lostShares: const [LostShare(to: 1, amount: 3)],
          tileCount: 6,
          finishJokerCount: 0,
          bingo: true,
        ),
        const OnlineMoveRow(
          turn: 1,
          playerIndex: 1,
          action: 'exchange',
          words: [],
          points: 0,
          lostShares: [],
          tileCount: 3,
          finishJokerCount: 0,
          bingo: false,
        ),
        const OnlineMoveRow(
          turn: 2,
          playerIndex: 0,
          action: 'pass',
          words: [],
          points: 0,
          lostShares: [],
          tileCount: 0,
          finishJokerCount: 0,
          bingo: false,
        ),
      ];
      final h = buildMoveHistory(rows);
      expect(h, hasLength(4)); // play + vergi satırı + exchange + pass
      expect(h[0].action, isNull);
      expect(h[0].bingo, isTrue);
      expect(h[0].lostShares, hasLength(1));
      // Vergi satırı: alan oyuncu adına, invasionFrom dolu.
      expect(h[1].player, 1);
      expect(h[1].points, 3);
      expect(h[1].invasionFrom, 0);
      expect(h[2].action, 'exchange');
      expect(h[2].tileCount, 3);
      expect(h[3].action, 'pass');
      expect(h[3].tileCount, isNull);
    });
  });

  group('OnlineGamesRepo.loadGame', () {
    test('state + kendi rafım + hamleler birlikte çözülür', () async {
      final s = _baseState();
      final gw = FakeOnlineGamesGateway()
        ..stateRow = stateJson(s)
        ..rackRows = [for (final tile in myRackTiles) tile.toJson()]
        ..moveRows = [
          {
            'turn': 0,
            'player_index': 1,
            'action': 'pass',
            'words': <String>[],
            'points': 0,
            'lost_shares': null,
            'tile_count': 0,
            'finish_joker_count': 0,
            'bingo': false,
          }
        ];
      final snap = await OnlineGamesRepo(gw).loadGame('g1');
      expect(snap, isNotNull);
      expect(snap!.state.players, hasLength(2));
      expect(snap.myRack.map((t) => t.letter).join(), 'KELİME?');
      expect(snap.moves.single.action, 'pass');
    });

    test('state satırı yoksa / hata olursa null', () async {
      final gw = FakeOnlineGamesGateway(); // stateRow null
      expect(await OnlineGamesRepo(gw).loadGame('g1'), isNull);
      gw.gameLoadFailWith = Exception('ağ');
      expect(await OnlineGamesRepo(gw).loadGame('g1'), isNull);
    });
  });

  group('GameController.actingSeat (Canlı koltuk sabitleme)', () {
    test('sıra rakipteyken PLACE_TILE BENİM rafımdan işler, current korunur',
        () {
      final c = GameController(
          words: words, autoPlayAi: false, nowIso: () => '', actingSeat: 0);
      // Sunucu state'i: sıra 1. oyuncuda.
      c.restore(_baseState().copyWith(current: 1));
      c.dispatch(const PlaceTileAction(r: 0, c: 0, rackIndex: 0));

      expect(c.state.placed[cellKey(0, 0)]?.letter, 'K');
      // Taş BENİM rafımdan düştü (rakibinkinden değil).
      expect(c.state.players[0].rack, hasLength(6));
      expect(c.state.players[1].rack, hasLength(7));
      // Sunucu sırası korundu — sabitleme yalnızca reduce süresince.
      expect(c.state.current, 1);
      // Taşın sahibi de ben olmalıyım (Board rengi buradan geliyor).
      expect(c.state.placed[cellKey(0, 0)]?.owner, 0);
    });

    test('no-op action orijinal state nesnesini korur', () {
      final c = GameController(
          words: words, autoPlayAi: false, nowIso: () => '', actingSeat: 0);
      c.restore(_baseState().copyWith(current: 1));
      final before = c.state;
      // Dolu olmayan ama geçersiz indeks → reducer no-op.
      c.dispatch(const PlaceTileAction(r: 0, c: 0, rackIndex: 99));
      expect(identical(c.state, before), isTrue);
    });

    test('actingSeat verilmezse davranış değişmez (yerel oyun)', () {
      final c =
          GameController(words: words, autoPlayAi: false, nowIso: () => '');
      c.restore(_baseState().copyWith(current: 1));
      c.dispatch(const PlaceTileAction(r: 0, c: 0, rackIndex: 0));
      // Sıra 1'de olduğundan taş 1. oyuncunun rafından düşer (yerel kural).
      expect(c.state.players[1].rack, hasLength(6));
      expect(c.state.players[0].rack, hasLength(7));
    });
  });

  group('OnlineGameScreen', () {
    Future<FakeOnlineGamesGateway> pumpScreen(
      WidgetTester tester, {
      int current = 0,
      bool opponentIsAi = false,
      String myUserId = 'me',
      List<Map<String, Object?>>? moveRows,
      GlobalKey? boundaryKey,
    }) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final s = _baseState(opponentIsAi: opponentIsAi);
      final gw = FakeOnlineGamesGateway()
        ..stateRow = stateJson(s, current: current)
        ..rackRows = [for (final tile in myRackTiles) tile.toJson()]
        ..moveRows = moveRows ?? const [];
      final row = gameRow(
        id: 'g1',
        myId: 'me',
        status: 'active',
        slots: [
          slotHuman('me', name: 'Ironman', relation: 'self'),
          if (opponentIsAi) slotAi else slotHuman('esiner', name: 'Esiner'),
        ],
      );
      Widget screen = OnlineGameScreen(
        game: game(row),
        myUserId: myUserId,
        onlineGames: OnlineGamesRepo(gw),
        words: words,
        auth: AuthService.fake(user: fakeUser('me')),
      );
      if (boundaryKey != null) {
        screen = RepaintBoundary(key: boundaryKey, child: screen);
      }
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
        home: screen,
      ));
      await tester.pump(); // initState → loadGame (sahte uç, mikrotask)
      await tester.pump();
      return gw;
    }

    /// Ekranın periyodik Timer'ı dispose'da iptal ediliyor — test sonunda
    /// ağacı söküp bunu tetiklemezsek "A Timer is still pending" düşer.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    testWidgets('katılımcı değilsen dürüst uyarı', (tester) async {
      await pumpScreen(tester, myUserId: 'baskasi');
      expect(find.text('Bu oyunun katılımcısı değilsin.'), findsOneWidget);
      expect(find.text('GERİ DÖN'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sıra rakipte: banner, süre taraması, YZ tetiklenmez',
        (tester) async {
      final gw = await pumpScreen(tester, current: 1);
      expect(find.textContaining('SIRA: ESİNER'), findsOneWidget);
      expect(gw.turnTimeoutChecks, ['g1']);
      expect(gw.aiTriggers, isEmpty); // rakip insan
      await unmount(tester);
    });

    testWidgets(
        'TORBA sayacı ayrı stilli — game_screen.dart ile AYNI NeoButton '
        'richLabel deseni (bkz. mobile/CLAUDE.md Parça 26)', (tester) async {
      await pumpScreen(tester, current: 0);
      // _baseState: bag 60 taş.
      final torbaText = tester.widget<Text>(find.text('TORBA 60'));
      final richLabel = torbaText.textSpan as TextSpan;
      final countSpan = richLabel.children!
          .whereType<TextSpan>()
          .firstWhere((s) => s.text == '60');
      expect(countSpan.style!.fontSize, 13);
      expect(countSpan.style!.color, const Color(0xFF2563EB));
      await unmount(tester);
    });

    testWidgets('sıra YZ koltuğunda: nabızlı banner + play-ai-turn tetiklenir',
        (tester) async {
      final gw = await pumpScreen(tester, current: 1, opponentIsAi: true);
      expect(find.textContaining('HAMLESİNİ HESAPLIYOR'), findsOneWidget);
      expect(gw.aiTriggers, ['g1']);
      await unmount(tester);
    });

    testWidgets(
        'sıra rakipteyken taş yerleştirilebilir (egzersiz): banner yerini '
        'mesaja bırakır, OYNA pasif kalır', (tester) async {
      final gw = await pumpScreen(tester, current: 1);

      for (var c = 0; c < 6; c++) {
        await tester.tap(rackTile(0));
        await tester.pump();
        await tester.tap(boardCell(0, c));
        await tester.pump();
      }
      // Geçerlilik geri bildirimi sıra bende değilken de çalışır.
      expect(find.text('+7'), findsOneWidget);
      expect(find.textContaining('SIRA: ESİNER —'), findsNothing);
      expect(find.text('Kelime geçerli — Sıra: Esiner'), findsOneWidget);

      // OYNA pasif: dokunmak hiçbir şey göndermez.
      await tester.tap(find.text('OYNA'));
      await tester.pump();
      expect(gw.submitted, isEmpty);
      await unmount(tester);
    });

    testWidgets('sıra bende: KELİME → OYNA → submit_move doğru payload',
        (tester) async {
      final gw = await pumpScreen(tester, current: 0);

      expect(find.textContaining('kendi köşenden'), findsOneWidget);
      for (var c = 0; c < 6; c++) {
        await tester.tap(rackTile(0));
        await tester.pump();
        await tester.tap(boardCell(0, c));
        await tester.pump();
      }
      expect(find.text('Oyna tuşuyla kelimeyi onayla.'), findsOneWidget);

      await tester.tap(find.text('OYNA'));
      await tester.pump();
      await tester.pump();

      expect(gw.submitted, hasLength(1));
      final sent = gw.submitted.single;
      expect(sent['gameId'], 'g1');
      expect(sent['action'], 'play');
      expect(sent['words'], ['KELİME']);
      expect(sent['basePoints'], 7);
      expect(sent['lostShares'], isEmpty); // rakip bölgesine değmiyor
      final placements = sent['placements']! as List<Map<String, Object?>>;
      expect(placements, hasLength(6));
      expect(placements.first['r'], 0);
      expect(placements.first['letter'], 'K');
      await unmount(tester);
    });

    testWidgets(
        'sürükleme sırasında sayfa kaymıyor (game_screen.dart ile aynı düzeltme)',
        (tester) async {
      await pumpScreen(tester, current: 0);
      ScrollPhysics? scrollPhysics() => tester
          .widget<SingleChildScrollView>(find.byWidgetPredicate((w) =>
              w is SingleChildScrollView && w.scrollDirection == Axis.vertical))
          .physics;
      expect(scrollPhysics(), isNull);

      final start = tester.getCenter(rackTile(0));
      final target = tester.getCenter(boardCell(0, 0)) + const Offset(0, 30);
      final g = await tester.startGesture(start);
      await g.moveTo(start + const Offset(0, -40)); // eşik aşılır
      await tester.pump();
      expect(scrollPhysics(), isA<NeverScrollableScrollPhysics>());
      await g.moveTo(target);
      await tester.pump();
      // Hover çerçevesinin geometrisi — game_screen_test.dart'taki AYNI
      // kontrol (bkz. orada, "hayalet taş hedefi görsel olarak örtüyor"
      // notu): konum gözle değil `DashedBorderPainter`'ın gerçek render
      // rect'i (0,0) hücresinin rect'iyle karşılaştırılarak doğrulanıyor.
      final hoverFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DashedBorderPainter);
      expect(hoverFinder, findsOneWidget);
      final hoverRect = tester.getRect(hoverFinder);
      final targetCellRect = tester.getRect(boardCell(0, 0));
      expect((hoverRect.center - targetCellRect.center).distance, lessThan(1),
          reason: 'Hover çerçevesi (0,0) hücresinin merkezinde değil — '
              'hover=$hoverRect hücre=$targetCellRect');
      await g.up();
      await tester.pump();
      expect(scrollPhysics(), isNull);
      await unmount(tester);
    });

    testWidgets('PAS GEÇ: onay → submit_move pass', (tester) async {
      final gw = await pumpScreen(tester, current: 0);

      await tester.tap(find.text('PAS GEÇ'));
      await tester.pumpAndSettle();
      expect(find.text('Pas Geçiyorsun!'), findsOneWidget);
      await tester.tap(find.text('VAZGEÇ'));
      await tester.pumpAndSettle();
      expect(gw.submitted, isEmpty);

      await tester.tap(find.text('PAS GEÇ'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'PAS GEÇ'));
      await tester.pumpAndSettle();
      expect(gw.submitted.single['action'], 'pass');
      await unmount(tester);
    });

    testWidgets('sunucu reddi mesaj satırına düşer', (tester) async {
      final gw = await pumpScreen(tester, current: 0);
      gw.submitFailWith = Exception('Sıra sende değil.');

      await tester.tap(find.text('PAS GEÇ'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'PAS GEÇ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sıra sende değil.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Realtime olayı ekranı tazeler', (tester) async {
      final gw = await pumpScreen(tester, current: 1);
      expect(gw.gameSubscribeCount, 1);
      final before = gw.gameStateCalls;

      // Rakip oynadı: sunucu state'i güncellendi, olay geldi.
      final s = _baseState();
      gw.stateRow = stateJson(s, current: 0, turnCount: 1);
      gw.gameListener!();
      await tester.pump();
      await tester.pump();

      expect(gw.gameStateCalls, greaterThan(before));
      // Sıra bana geçti: banner gitti, OYNA görünür durumda.
      expect(find.textContaining('SIRA: ESİNER'), findsNothing);
      await unmount(tester);
      expect(gw.gameUnsubscribeCount, 1);
    });

    testWidgets('son hamle mesajı sunucudaki satırdan türetilir + görüntü',
        (tester) async {
      final key = GlobalKey();
      await pumpScreen(
        tester,
        current: 0,
        boundaryKey: key,
        moveRows: [
          {
            'turn': 0,
            'player_index': 1,
            'action': 'play',
            'words': ['ARA'],
            'points': 13,
            'lost_shares': [
              {'to': 0, 'amount': 4}
            ],
            'tile_count': 3,
            'finish_joker_count': 0,
            'bingo': false,
          }
        ],
      );

      expect(
          find.text('Esiner: +13 puan (4 puanı Ironman kaptı) Kelimeler: ARA'),
          findsOneWidget);

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/screenshots/online_game.png');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      await unmount(tester);
    });
  });
}
