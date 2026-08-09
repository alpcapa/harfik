// Beğeni zinciri + sohbet arşivi (parça 5b) — kalp/iyimser güncelleme,
// Beğenenler listesi, Tümü/Favoriler sekmeleri ve sohbet rozeti.
// Gerçek uçlar (toggle_game_like / game_likers / list_liked_games /
// chat_flags_for_finished_game RPC'leri) cihazda doğrulanır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/games_api.dart';
import 'package:kelimeki/src/ui/chat/chat_thread.dart';
import 'package:kelimeki/src/ui/chat/game_chat_history_modal.dart';
import 'package:kelimeki/src/ui/score/game_history_modal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(loadAppFonts);

  group('GamesRepo — beğeni', () {
    test('history beğeni sayılarını TEK sorguda birleştirir', () async {
      final gw = FakeGamesGateway(userId: 'u-me')
        ..history = [gameRow(id: 'a'), gameRow(id: 'b')]
        ..likeCounts = {'a': 3}
        ..likedByMe = {'a'};
      final repo = await newRepo(gw);

      final res = await repo.history(userId: 'u-me', playerCount: null, offset: 0);
      expect(res.games[0].likeCount, 3);
      expect(res.games[0].likedByMe, isTrue);
      expect(res.games[1].likeCount, 0);
      expect(res.games[1].likedByMe, isFalse);
    });

    test('misafirde beğeni sorgusu HİÇ yapılmaz', () async {
      // Beğeni oturum gerektiriyor; web de misafirde bu ikinci sorguyu
      // atlıyor. Sahte uç çağrılırsa fırlatarak bunu kanıtlıyoruz.
      final gw = _NoLikeStatsGateway()..history = [gameRow(id: 'a')];
      final repo = await newRepo(gw);
      final res = await repo.history(userId: 'u-me', playerCount: null, offset: 0);
      expect(res.games.single.likeCount, 0);
    });

    test('beğeni sorgusu düşerse liste yine döner (kartlar beğenisiz)',
        () async {
      final gw = _FailingLikeStatsGateway(userId: 'u-me')
        ..history = [gameRow(id: 'a')];
      final repo = await newRepo(gw);
      final res = await repo.history(userId: 'u-me', playerCount: null, offset: 0);
      expect(res.games, hasLength(1));
      expect(res.games.single.likeCount, 0);
    });

    test('toggleLike hatada null döner (çağıran geri alsın diye)', () async {
      final gw = FakeGamesGateway(userId: 'u-me')..failNextToggleLike = true;
      final repo = await newRepo(gw);
      expect(await repo.toggleLike('a'), isNull);
      expect(await repo.toggleLike('a'), isTrue); // ikinci deneme başarılı
    });

    test('Favoriler: sahiplik DEĞİL beğeni belirler', () async {
      final gw = FakeGamesGateway(userId: 'u-me')
        ..history = [
          gameRow(id: 'mine'),
          // Başkasının oyunu — ama ben beğenmişim, favorilerde ÇIKMALI.
          gameRow(id: 'theirs', userId: 'u-other'),
        ]
        ..likedByMe = {'theirs'}
        ..likeCounts = {'theirs': 1};
      final repo = await newRepo(gw);

      final all = await repo.history(userId: 'u-me', playerCount: null, offset: 0);
      expect(all.games.map((g) => g.id), ['mine']); // listGames sahiplik filtreli

      final favs = await repo.history(
          userId: 'u-me', playerCount: null, offset: 0, favoritesOnly: true);
      expect(favs.games.map((g) => g.id), ['theirs']);
    });
  });

  Future<void> pumpHistory(WidgetTester tester, GamesRepo repo,
      {Key? key, Size size = const Size(420, 900)}) async {
    await setPhoneViewSize(tester, size);
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
            currentName: 'Ironman',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('kalp: iyimser güncelleme, sayı anında artar', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')..history = [gameRow(id: 'a')];
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistory(tester, repo);

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    // Beğenilmemiş kalp gri kalmalı (renk yalnızca beğenildiğinde değişir).
    expect(tester.widget<Icon>(find.byIcon(Icons.favorite_border)).color,
        isNot(const Color(0xFFDC2626)));

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    // Web: `entry.liked_by_me ? 'text-red' : 'text-muted'` — beğenilen kalp
    // KIRMIZI. Port ikonu doldurup rengi koşulsuz gri bırakmıştı (9 Ağustos
    // 2026, cihaz testinde "like yapınca kalp gri/siyah kalıyor").
    expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
        const Color(0xFFDC2626));
    // Sayı rozeti belirdi. Key ile aranıyor: düz '1' metni PlayerBadge'in
    // koltuk numarasıyla çakışıyor.
    expect(
        tester
            .widget<Text>(find.descendant(
                of: find.byKey(const ValueKey('like-count-a')),
                matching: find.byType(Text)))
            .data,
        '1');
    expect(gw.toggledLikes, ['a']);
  });

  testWidgets('kalp: istek düşerse iyimser güncelleme GERİ ALINIR',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'a')]
      ..failNextToggleLike = true;
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistory(tester, repo);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('beğeni sayısına dokunmak Beğenenler listesini açar',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'a')]
      ..likeCounts = {'a': 2}
      ..likersByGame = {
        'a': [
          {
            'user_id': 'u-1',
            'display_name': 'Bobola',
            'first_name': 'Ebru',
            'avatar_url': null,
          },
          // Nickname yoksa yalnız ad gösterilir (soyad hiçbir zaman).
          {
            'user_id': 'u-2',
            'display_name': null,
            'first_name': 'Deniz',
            'avatar_url': null,
          },
        ]
      };
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistory(tester, repo);

    await tester.tap(find.byKey(const ValueKey('like-count-a')));
    await tester.pumpAndSettle();

    expect(find.text('BEĞENENLER'), findsOneWidget);
    expect(find.text('Bobola'), findsOneWidget);
    expect(find.text('Deniz'), findsOneWidget);
  });

  testWidgets('Favoriler sekmesi listeyi değiştirir', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'mine', createdAt: '2026-08-01T12:00:00.000Z'),
        gameRow(
            id: 'theirs',
            userId: 'u-other',
            createdAt: '2026-07-20T12:00:00.000Z'),
      ]
      ..likedByMe = {'theirs'}
      ..likeCounts = {'theirs': 1};
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistory(tester, repo);

    expect(find.text('01.08.2026'), findsOneWidget);
    expect(find.text('20.07.2026'), findsNothing);

    await tester.tap(find.text('FAVORİLER'));
    await tester.pumpAndSettle();

    expect(find.text('20.07.2026'), findsOneWidget);
    expect(find.text('01.08.2026'), findsNothing);
  });

  testWidgets('favorilerde BAŞKASININ satırı "ben" sanılmaz', (tester) async {
    // Web'de gerçek bir hataydı: list_liked_games başkasının katılımcı
    // satırını döndürdüğünde meIndex hesaplanıp görüntüleyenin GÜNCEL adı
    // rakibin skoruna yapıştırılıyordu.
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
          id: 'theirs',
          userId: 'u-other',
          playerCount: 2,
          rank: 1,
          players: [
            snap('Esiner', 200, colorIndex: 0),
            snap('Bobola', 150, colorIndex: 1),
          ],
        ),
      ]
      ..likedByMe = {'theirs'};
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistory(tester, repo);

    await tester.tap(find.text('FAVORİLER'));
    await tester.pumpAndSettle();

    // Dondurulmuş isimler olduğu gibi durur; 'Ironman' (görüntüleyenin
    // güncel adı) hiçbir satıra sızmaz.
    expect(find.text('Esiner'), findsOneWidget);
    expect(find.text('Bobola'), findsOneWidget);
    expect(find.text('Ironman'), findsNothing);
  });

  testWidgets('eski yerel kayıt (players yok) "Yapay Zeka" rozeti ALMAZ',
      (tester) async {
    // Web koşulu: rozet yalnızca kayıtta GERÇEKTEN bir YZ koltuğu varsa.
    // İlk port bunu "Canlı değilse Yapay Zeka" diye basitleştirmişti.
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'eski')]; // players: null
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistory(tester, repo);

    expect(find.text('Yapay Zeka'), findsNothing);
    expect(find.text('Canlı'), findsNothing);
    // Yedek satır ("Sen") kendi satırında GÜNCEL adla ikame edilir — web'in
    // myCurrentName kuralı; 'En iyi rakip' olduğu gibi kalır.
    expect(find.text('Ironman'), findsOneWidget);
    expect(find.text('En iyi rakip'), findsOneWidget);
  });

  testWidgets('sohbet rozeti arşivi açar (rozetler renk indeksinden)',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
          id: 'g-online',
          playerCount: 2,
          onlineGameId: 'og-1',
          messageCount: 2,
          players: [
            snap('Ironman', 150, colorIndex: 0),
            snap('Esiner', 120, colorIndex: 1),
          ],
        )
      ]
      ..messagesByGame = {
        'g-online': [
          {
            'name': 'Ironman',
            'colorIndex': 0,
            'message': 'iyi oyunlar',
            'created_at': '2026-08-01T09:05:00.000Z',
          },
          {
            'name': 'Esiner',
            'colorIndex': 1,
            'message': 'sana da',
            'created_at': '2026-08-01T09:06:00.000Z',
          },
        ]
      }
      ..chatFlagsByGame = {
        'og-1': [
          {'color_index': 1, 'muted': true, 'reported': false},
        ]
      };
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistory(tester, repo);

    expect(
        tester
            .widget<Text>(find.descendant(
                of: find.byKey(const ValueKey('chat-count-g-online')),
                matching: find.byType(Text)))
            .data,
        '2'); // rozetteki mesaj sayısı
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    expect(find.text('SOHBET GEÇMİŞİ'), findsOneWidget);
    expect(find.text('iyi oyunlar'), findsOneWidget);
    expect(find.text('sana da'), findsOneWidget);
    // İsim başlığı Türkçe büyük harf (native toUpperCase "IRONMAN" verirdi
    // ama burada fark yok; asıl kontrol trUpper'ın uygulandığı).
    expect(find.text('IRONMAN'), findsOneWidget);
    // Sessize alınan koltuk (colorIndex 1) rozet taşır, diğeri taşımaz.
    expect(find.text('🚫'), findsOneWidget);
    expect(find.text('🚩'), findsNothing);
    // Arşiv: hepsi solda — "kimin ekranı" kavramı geçmişte yok.
    final bubbles =
        tester.widgetList<ChatThread>(find.byType(ChatThread)).single;
    expect(bubbles.messages.every((m) => !m.mine), isTrue);
  });

  testWidgets('sohbet arşivi ekran görüntüsü', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
          id: 'g-online',
          playerCount: 2,
          onlineGameId: 'og-1',
          messageCount: 3,
          players: [
            snap('Ironman', 150, colorIndex: 0),
            snap('Esiner', 120, colorIndex: 1),
          ],
        )
      ]
      ..messagesByGame = {
        'g-online': [
          {
            'name': 'Ironman',
            'colorIndex': 0,
            'message': 'İyi oyunlar, bol şans!',
            'created_at': '2026-08-01T09:05:00.000Z',
          },
          {
            'name': 'Esiner',
            'colorIndex': 1,
            'message':
                'Sana da. Şu köşeyi almana izin vermeyeceğim ama, haberin olsun.',
            'created_at': '2026-08-01T09:06:00.000Z',
          },
          {
            'name': 'Ironman',
            'colorIndex': 0,
            'message': 'Görüşürüz o zaman :)',
            'created_at': '2026-08-01T09:08:00.000Z',
          },
        ]
      };
    final repo = await newRepoForWidget(tester, gw);
    final key = GlobalKey();

    await setPhoneViewSize(tester, const Size(420, 620));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: GameChatHistoryModal(
              games: repo,
              gameId: 'g-online',
              onlineGameId: 'og-1',
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Sıralama: en yeni mesaj en ÜSTTE (9 Ağustos 2026, kullanıcı isteği —
    // mesajlar HER YERDE aynı yönde okunur; bkz. mobile/CLAUDE.md Parça 36).
    // Fixture kronolojik artan (09:05 → 09:06 → 09:08) geliyor; ekranda tam
    // tersi sırada durmalı.
    final enYeni = tester.getTopLeft(find.text('Görüşürüz o zaman :)')).dy;
    final ortanca = tester
        .getTopLeft(find.textContaining('Şu köşeyi almana izin vermeyeceğim'))
        .dy;
    final enEski = tester.getTopLeft(find.text('İyi oyunlar, bol şans!')).dy;
    expect(enYeni, lessThan(ortanca));
    expect(ortanca, lessThan(enEski));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/chat_history.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}

/// `game_like_stats`'e HİÇ gitmemesi gerektiğini kanıtlayan sahte uç:
/// çağrılırsa test patlar. `currentUserId` null (misafir).
class _NoLikeStatsGateway extends FakeGamesGateway {
  _NoLikeStatsGateway() : super(userId: null);

  @override
  Future<List<Map<String, Object?>>> likeStats(List<String> gameIds) async {
    fail('misafirde beğeni sorgusu yapılmamalı');
  }
}

/// Beğeni sorgusu düşse bile listenin dönmesi gerekiyor.
class _FailingLikeStatsGateway extends FakeGamesGateway {
  _FailingLikeStatsGateway({super.userId});

  @override
  Future<List<Map<String, Object?>>> likeStats(List<String> gameIds) async {
    throw Exception('ağ hatası');
  }
}
