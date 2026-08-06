// Oyun geçmişi (parça 5a) — liste, sayfalama, kart içeriği (sıra/SL/teslim),
// eski kayıtların yedek satırları ve tahta önizlemesinin lazy açılışı.
// Gerçek uç (games SELECT + RLS) cihazda doğrulanır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/game_record.dart';
import 'package:kelimeki/src/data/games_api.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/player_badge.dart';
import 'package:kelimeki/src/ui/score/game_history_modal.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_games_gateway.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// `games` satırı — yalnızca liste sütunları (web ile aynı set).
Map<String, Object?> gameRow({
  required String id,
  String userId = 'u-me',
  String createdAt = '2026-08-01T12:00:00.000Z',
  int playerCount = 2,
  int playerScore = 238,
  int aiScore = 179,
  int? rank = 1,
  bool surrendered = false,
  String? onlineGameId,
  List<Map<String, Object?>>? players,
}) =>
    {
      'id': id,
      'user_id': userId,
      'created_at': createdAt,
      'player_count': playerCount,
      'player_score': playerScore,
      'ai_score': aiScore,
      'rank': rank,
      'surrendered': surrendered,
      'online_game_id': onlineGameId,
      'players': players,
    };

Map<String, Object?> snap(String name, int score,
        {bool ai = false, bool surrendered = false, int colorIndex = 0}) =>
    {
      'name': name,
      'score': score,
      'is_ai': ai,
      'surrendered': surrendered,
      'colorIndex': colorIndex,
    };

Future<GamesRepo> newRepo(FakeGamesGateway gw) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await AppStorage.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    prefs: await SharedPreferences.getInstance(),
    nowMs: () => DateTime.now().millisecondsSinceEpoch,
  );
  return GamesRepo(gw, storage.queue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(loadAppFonts);

  group('GamesRepo.history', () {
    test('sayfalama: bir FAZLA satır istenir, hasMore ondan çıkar', () async {
      final gw = FakeGamesGateway(userId: 'u-me')
        ..history = [for (var i = 0; i < 25; i++) gameRow(id: 'g$i')];
      final repo = await newRepo(gw);

      final first = await repo.history(userId: 'u-me', playerCount: null, offset: 0, limit: 20);
      expect(first.games, hasLength(20));
      expect(first.hasMore, isTrue);
      expect(gw.listCalls.single.limit, 20);

      final second = await repo.history(userId: 'u-me', playerCount: null, offset: 20, limit: 20);
      expect(second.games, hasLength(5));
      expect(second.hasMore, isFalse);
    });

    test('playerCount filtresi: null ise uygulanmaz', () async {
      final gw = FakeGamesGateway(userId: 'u-me')
        ..history = [
          gameRow(id: 'a', playerCount: 2),
          gameRow(id: 'b', playerCount: 4),
        ];
      final repo = await newRepo(gw);
      expect((await repo.history(userId: 'u-me', playerCount: null, offset: 0)).games,
          hasLength(2));
      expect((await repo.history(userId: 'u-me', playerCount: 4, offset: 0)).games.single.id,
          'b');
    });

    test('ağ hatası: boş sayfa, fırlatmaz', () async {
      final repo = await newRepo(_ThrowingGateway());
      final res = await repo.history(userId: 'u', playerCount: null, offset: 0);
      expect(res.games, isEmpty);
      expect(res.hasMore, isFalse);
    });

    test('boardSnapshot: kayıt yoksa null (eski kayıt)', () async {
      final gw = FakeGamesGateway(userId: 'u-me')
        ..snapshots = {
          'g1': [
            {'r': 0, 'c': 0, 'l': 'A', 'o': 0}
          ]
        };
      final repo = await newRepo(gw);
      expect((await repo.boardSnapshot('g1'))!.single.l, 'A');
      expect(await repo.boardSnapshot('yok'), isNull);
    });
  });

  test('buildSnapshotGameState: koltuk kimliği colorIndex\'ten okunur', () {
    // players SIRALAMA sırasında (kazanan önce) ama colorIndex koltuğu
    // taşıyor — web'in kuralı: renk/köşe sıralamadan BAĞIMSIZ.
    final state = buildSnapshotGameState(
      [
        const BoardSnapshotTile(r: 0, c: 0, l: 'A', o: 0),
        const BoardSnapshotTile(r: 1, c: 1, l: 'B', o: 1, w: true),
      ],
      2,
      [
        const GamePlayerSnapshot(
            name: 'Yapay Zeka 2', score: 200, isAi: true, surrendered: false, colorIndex: 1),
        const GamePlayerSnapshot(
            name: 'Ironman', score: 100, isAi: false, surrendered: false, colorIndex: 0),
      ],
    );
    expect(state.players[0].name, 'Ironman'); // koltuk 0
    expect(state.players[1].name, 'Yapay Zeka 2'); // koltuk 1
    expect(state.players[0].corners, isNotEmpty);
    expect(state.isGameOver, isTrue);
    expect(state.board[0][0]!.letter, 'A');
    // Joker: tahtada '?' taşı, görünen harf wildLetter'da (web ile aynı).
    expect(state.board[1][1]!.wild, isTrue);
    expect(state.board[1][1]!.letter, '?');
    expect(state.board[1][1]!.wildLetter, 'B');
    expect(state.board[1][1]!.pts, 0);
  });

  Future<void> pumpHistory(WidgetTester tester, GamesRepo repo,
      {String? currentName = 'Ironman', bool isMe = true, Key? key}) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: GameHistoryModal(
            games: repo,
            userId: 'u-me',
            playerCount: null,
            currentName: currentName,
            isMe: isMe,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('kart: tarih, rozet, sıra/puan/SL sütunları + ekran görüntüsü',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        // Canlı, 4 kişilik: biri teslim olmuş.
        gameRow(
          id: 'g-online',
          createdAt: '2026-08-03T09:30:00.000Z',
          playerCount: 4,
          playerScore: 150,
          rank: 1,
          onlineGameId: 'og-1',
          players: [
            snap('Ironman', 150, colorIndex: 0),
            snap('Esiner', 120, colorIndex: 1),
            snap('Bobola', 90, colorIndex: 2),
            snap('T2', 0, surrendered: true, colorIndex: 3),
          ],
        ),
        // YZ, 2 kişilik: kaybedilmiş.
        gameRow(
          id: 'g-ai',
          createdAt: '2026-08-01T12:00:00.000Z',
          playerScore: 179,
          aiScore: 238,
          rank: 2,
          players: [
            snap('Yapay Zeka 2', 238, ai: true, colorIndex: 1),
            snap('Ironman', 179, colorIndex: 0),
          ],
        ),
      ];
    final repo = await newRepo(gw);

    final key = GlobalKey();
    await pumpHistory(tester, repo, key: key);

    expect(find.text('TÜM GEÇMİŞ OYUNLAR'), findsOneWidget); // KModal başlığı
    expect(find.text('03.08.2026'), findsOneWidget);
    expect(find.text('01.08.2026'), findsOneWidget);
    expect(find.text('Canlı'), findsOneWidget);
    expect(find.text('Yapay Zeka'), findsOneWidget);
    expect(find.text('TESLİM OLDU'), findsOneWidget);
    // Rozet koltuk kimliğinden gelir (final sıralamadan BAĞIMSIZ) — dört
    // oyuncu dört FARKLI koltuk göstermeli. İlk portta bu satır düşmüştü ve
    // dördü de "1" çıkıyordu (ekran görüntüsü yakaladı).
    final badges = tester
        .widgetList<PlayerBadge>(find.byType(PlayerBadge))
        .map((b) => b.colorIndex ?? b.index)
        .toList();
    expect(badges.take(4), [0, 1, 2, 3]);

    // SL: 1.=+2, 4 kişilikte 2.=+1, 3.= '-', teslim=-2.
    // İKİ tane +2 var: Canlı oyunun birincisi VE YZ oyununu kazanan YZ —
    // web de her satır için SL gösteriyor (YZ satırları dahil).
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('-2'), findsOneWidget);
    // 2 kişilik oyunda 2. olmak SL getirmez (web kuralı) → '-'.
    expect(find.text('-'), findsWidgets);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_history.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  testWidgets('kendi satırında GÜNCEL ad gösterilir (dondurulmuş ad değil)',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g1', rank: 1, players: [
          snap('EskiNick', 238, colorIndex: 0),
          snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
        ])
      ];
    await pumpHistory(tester, await newRepo(gw), currentName: 'YeniNick');
    expect(find.text('YeniNick'), findsOneWidget);
    expect(find.text('EskiNick'), findsNothing);
  });

  testWidgets('eski kayıt (players boş): Sen / En iyi rakip yedeği',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'old', playerCount: 4, playerScore: 100, aiScore: 150, rank: null)
      ];
    // currentName VERİLMEDEN: yedek satır "Sen" etiketini kullanmalı.
    await pumpHistory(tester, await newRepo(gw), currentName: null);
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('En iyi rakip'), findsOneWidget);
    expect(find.textContaining('+2 diğer oyuncu'), findsOneWidget);
  });

  testWidgets('başkasının geçmişi: yedek satır "Sen" değil o kişinin adı',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'old', rank: null)];
    await pumpHistory(tester, await newRepo(gw),
        currentName: 'Esiner', isMe: false);
    expect(find.text('Sen'), findsNothing);
    expect(find.text('Esiner'), findsOneWidget);
  });

  testWidgets('karta dokunmak tahtayı lazy açar, tekrar dokunmak kapatır',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g1', rank: 1, players: [
          snap('Ironman', 10, colorIndex: 0),
          snap('Yapay Zeka 2', 5, ai: true, colorIndex: 1),
        ])
      ]
      ..snapshots = {
        'g1': [
          {'r': 0, 'c': 0, 'l': 'A', 'o': 0},
          {'r': 0, 'c': 1, 'l': 'B', 'o': 0},
        ]
      };
    await pumpHistory(tester, await newRepo(gw));

    expect(find.byType(BoardWidget), findsNothing); // liste sorgusunda YOK
    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    expect(find.byType(BoardWidget), findsOneWidget);

    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    expect(find.byType(BoardWidget), findsNothing);
  });

  testWidgets('tahta kaydı yoksa açıklama gösterilir', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'g1', rank: 1)]; // snapshots boş
    await pumpHistory(tester, await newRepo(gw));
    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    expect(find.text('Bu oyun için tahta görüntüsü kaydedilmemiş.'),
        findsOneWidget);
    expect(find.byType(BoardWidget), findsNothing);
  });

  testWidgets('hiç kayıt yoksa boş metin', (tester) async {
    await pumpHistory(tester, await newRepo(FakeGamesGateway(userId: 'u-me')));
    expect(find.text('Henüz kayıtlı bir oyunun yok.'), findsOneWidget);
  });
}

class _ThrowingGateway extends FakeGamesGateway {
  @override
  Future<List<Map<String, Object?>>> listGames({
    required String userId,
    required int? playerCount,
    required int offset,
    required int limit,
  }) =>
      Future.error(Exception('ağ'));
}
