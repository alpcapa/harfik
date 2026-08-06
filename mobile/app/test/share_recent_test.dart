// Paylaşma + "Son Oynadıklarım" (parça 5c).
//
// Paylaşım gerçek platform kanalına (share_plus/path_provider) GİTMEZ:
// `GameHistoryModal` paylaşımı `ShareBoardFn` olarak alıyor, test sahte bir
// fonksiyonla AKIŞI doğruluyor (markShared → görsel yakala → paylaş).
// Gerçek paylaş sayfası cihazda doğrulanır.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/games_api.dart';
import 'package:kelimeki/src/ui/score/game_history_modal.dart';
import 'package:kelimeki/src/util/share_board.dart';
import 'package:kelimeki/src/ui/score/score_box_row.dart';
import 'package:kelimeki/src/ui/setup/recent_games_section.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// Paylaş çağrısının kaydı.
class _ShareCall {
  final Uint8List? png;
  final String text;
  final String? url;
  _ShareCall(this.png, this.text, this.url);
}

List<Map<String, Object?>> _tiles() => [
      {'r': 0, 'c': 0, 'l': 'K', 'o': 0},
      {'r': 0, 'c': 1, 'l': 'E', 'o': 0},
      {'r': 0, 'c': 2, 'l': 'L', 'o': 0},
      {'r': 6, 'c': 6, 'l': 'A', 'o': 1},
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(loadAppFonts);
  setUp(clearRecentGamesCache);

  Future<List<_ShareCall>> pumpHistoryWithShare(
    WidgetTester tester,
    GamesRepo repo, {
    String? initialExpandedId,
    Key? boundaryKey,
  }) async {
    final calls = <_ShareCall>[];
    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(
        key: boundaryKey,
        child: Scaffold(
          body: GameHistoryModal(
            games: repo,
            userId: 'u-me',
            playerCount: null,
            currentName: 'Ironman',
            initialExpandedId: initialExpandedId,
            share: ({required png, required text, required url}) async {
              calls.add(_ShareCall(png, text, url));
            },
            // Gerçek `toImage` sahte zamanda tamamlanmıyor (bkz.
            // CaptureBoardFn notu) — akış testinde sahte bayt, gerçek
            // yakalama ayrı bir testte `runAsync` ile doğrulanıyor.
            capture: (_) async => Uint8List.fromList(List.filled(2048, 7)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('paylaş: önce set_game_shared, sonra görsel + link',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g1', players: [
          snap('Ironman', 150, colorIndex: 0),
          snap('Yapay Zeka 2', 120, ai: true, colorIndex: 1),
        ])
      ]
      ..snapshots = {'g1': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    final calls = await pumpHistoryWithShare(tester, repo);

    // Kartı aç → tahta gelir.
    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    expect(find.byType(ScoreBoxRow), findsOneWidget);

    // Tahtaya dokun → aksiyon menüsü.
    await tester.tap(find.byType(ScoreBoxRow));
    await tester.pumpAndSettle();
    expect(find.text('Paylaş'), findsOneWidget);
    expect(find.text('Kapat'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);

    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();

    expect(gw.sharedGames, ['g1']); // link ancak bu bayrakla çalışır
    expect(calls, hasLength(1));
    expect(calls.single.text, "Kelimeki'deki şu oyunu görmeni istedim.");
    expect(calls.single.url, 'https://kelimeki.com/game/g1');
    // Görsel paylaşıma iletildi (yakalayıcı çağrıldı).
    expect(calls.single.png, isNotNull);
    expect(calls.single.png!.length, greaterThan(1000));

    // Paylaşılacak GÖRSELİN kendisi: aynı düğümü gerçek yakalayıcıyla
    // çekip diske yazıyoruz — ekran görüntüsü, paylaşılan PNG'nin birebir
    // aynısı (skor şeridi + tahta).
    await tester.runAsync(() async {
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(find.ancestor(
              of: find.byType(ScoreBoxRow),
              matching: find.byType(RepaintBoundary))
            .first);
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/share_image.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });

  testWidgets('paylaş: işaretleme düşerse LİNKSİZ paylaşılır', (tester) async {
    final gw = _NoShareMarkGateway(userId: 'u-me')
      ..history = [gameRow(id: 'g1')]
      ..snapshots = {'g1': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    final calls = await pumpHistoryWithShare(tester, repo);

    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ScoreBoxRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();

    expect(calls.single.url, isNull);
    expect(calls.single.text, isNotEmpty);
  });

  testWidgets('menüdeki "Kapat" tahtayı kapatır', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'g1')]
      ..snapshots = {'g1': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistoryWithShare(tester, repo);

    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    expect(find.byType(ScoreBoxRow), findsOneWidget);

    await tester.tap(find.byType(ScoreBoxRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(find.byType(ScoreBoxRow), findsNothing);
  });

  testWidgets('initialExpandedId: hedef ilk sayfada YOKSA sayfalanır ve açılır',
      (tester) async {
    // 30 kayıt, hedef 25. sırada → ilk sayfa (20) yetmiyor; web'in aynı
    // düzeltmesi: hedef bulunana kadar sayfa sayfa çekilir.
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        for (var i = 0; i < 30; i++)
          gameRow(
            id: 'g$i',
            createdAt: '2026-07-${(i % 28 + 1).toString().padLeft(2, '0')}'
                'T12:00:00.000Z',
            players: [
              snap('Ironman', 150 - i, colorIndex: 0),
              snap('Yapay Zeka 2', 100, ai: true, colorIndex: 1),
            ],
          )
      ]
      ..snapshots = {'g25': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistoryWithShare(tester, repo, initialExpandedId: 'g25');

    // İki sayfa çekildi (20 + kalan) ve hedefin tahtası AÇIK.
    expect(gw.listCalls.length, greaterThanOrEqualTo(2));
    expect(find.byType(ScoreBoxRow), findsOneWidget);

    // Kart görünür alanda ve makul biçimde ortalanmış olmalı.
    final box = tester.getRect(find.byType(ScoreBoxRow));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(box.top, greaterThanOrEqualTo(screen.top));
    expect(box.bottom, lessThanOrEqualTo(screen.bottom));
  });

  testWidgets('Son Oynadıklarım: satır + ekran görüntüsü', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
          id: 'g-ai',
          createdAt: '2026-08-03T09:30:00.000Z',
          playerScore: 238,
          aiScore: 179,
          rank: 1,
          players: [
            snap('Ironman', 238, colorIndex: 0),
            snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
          ],
        ),
        gameRow(
          id: 'g-ai2',
          createdAt: '2026-08-01T12:00:00.000Z',
          playerCount: 4,
          playerScore: 120,
          aiScore: 190,
          rank: 3,
          players: [
            snap('Yapay Zeka 2', 190, ai: true, colorIndex: 1),
            snap('Yapay Zeka 3', 150, ai: true, colorIndex: 2),
            snap('Ironman', 120, colorIndex: 0),
            snap('Yapay Zeka 4', 90, ai: true, colorIndex: 3),
          ],
        ),
        // Canlı oyun: onlineOnly=false filtresiyle GÖRÜNMEMELİ.
        gameRow(id: 'g-online', onlineGameId: 'og-1'),
      ]
      ..snapshots = {'g-ai': _tiles()};
    final repo = await newRepoForWidget(tester, gw);

    final key = GlobalKey();
    await setPhoneViewSize(tester, const Size(420, 520));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RecentGamesSection(
                games: repo,
                userId: 'u-me',
                onlineOnly: false,
                currentName: 'Ironman',
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('SON OYNADIKLARIM'), findsOneWidget);
    expect(find.text('TÜM OYUNLARIM'), findsOneWidget);
    expect(find.text('03.08.2026'), findsOneWidget);
    expect(find.text('01.08.2026'), findsOneWidget);
    expect(find.text('238'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget); // 2 kişilik birincilik
    expect(find.text('-'), findsOneWidget); // 4 kişilik 3.lük puan getirmez
    // Canlı oyun bu sekmede yok (onlineOnly filtresi sunucuda uygulanıyor).
    expect(gw.listCalls, isNotEmpty);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/recent_games.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });

  testWidgets('captureBoundaryAsPng gerçek PNG üretir', (tester) async {
    // Paylaşılan görselin GERÇEK yolu: RepaintBoundary → toImage → PNG.
    // `runAsync` şart — sahte zamanda toImage hiç tamamlanmıyor.
    final key = GlobalKey();
    await setPhoneViewSize(tester, const Size(200, 200));
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: const ColoredBox(color: Colors.red, child: SizedBox(width: 100, height: 100)),
      ),
    ));
    await tester.pumpAndSettle();

    Uint8List? png;
    await tester.runAsync(() async {
      png = await captureBoundaryAsPng(key);
    });
    expect(png, isNotNull);
    // PNG imzası: 89 50 4E 47
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('Son Oynadıklarım: hiç bitmiş oyun yoksa bölüm GİZLİ',
      (tester) async {
    final repo =
        await newRepoForWidget(tester, FakeGamesGateway(userId: 'u-me'));
    await setPhoneViewSize(tester, const Size(420, 520));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecentGamesSection(
            games: repo, userId: 'u-me', onlineOnly: false),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('SON OYNADIKLARIM'), findsNothing);
  });

  testWidgets('Son Oynadıklarım: satıra dokunmak geçmişi O OYUNLA açar',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g-ai', players: [
          snap('Ironman', 238, colorIndex: 0),
          snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
        ])
      ]
      ..snapshots = {'g-ai': _tiles()};
    final repo = await newRepoForWidget(tester, gw);

    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        body: RecentGamesSection(
            games: repo, userId: 'u-me', onlineOnly: false),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('238'));
    await tester.pumpAndSettle();

    expect(find.text('TÜM GEÇMİŞ OYUNLAR'), findsOneWidget);
    // Hedef oyunun tahtası ayrıca dokunmaya gerek kalmadan AÇIK geldi.
    expect(find.byType(ScoreBoxRow), findsOneWidget);
  });
}

/// `set_game_shared` düşen uç — link olmadan paylaşılmalı.
class _NoShareMarkGateway extends FakeGamesGateway {
  _NoShareMarkGateway({super.userId});

  @override
  Future<void> markShared(String gameId) async => throw Exception('ağ hatası');
}
