// Skor Kartı + k-lig + oyuncu kartı (parça 4) — sahte bir StatsGateway ile.
// Gerçek uç (SupabaseStatsGateway: player_stats/player_stats_overall/
// leaderboard/my_leaderboard_rank) cihazda doğrulanır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/stats_api.dart';
import 'package:kelimeki/src/ui/score/klig_mark.dart';
import 'package:kelimeki/src/ui/score/leaderboard_modal.dart';
import 'package:kelimeki/src/ui/score/player_score_card_modal.dart';
import 'package:kelimeki/src/ui/score/score_card_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

class FakeStatsGateway implements StatsGateway {
  /// playerCount → satır (null anahtarı 'Genel' = player_stats_overall).
  final Map<String, Map<int?, Map<String, Object?>>> stats;
  final List<Map<String, Object?>> rows;
  final Map<String, Object?>? rank;

  /// Kaç kez sayfa istendi (lazy yükleme testi).
  final pageRequests = <({int limit, int offset})>[];

  FakeStatsGateway({this.stats = const {}, this.rows = const [], this.rank});

  @override
  Future<Map<String, Object?>?> playerStats(String userId, int? playerCount) async =>
      stats[userId]?[playerCount];

  @override
  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset) async {
    pageRequests.add((limit: limit, offset: offset));
    return rows.skip(offset).take(limit).toList();
  }

  @override
  Future<Map<String, Object?>?> myLeaderboardRank(String userId) async => rank;
}

Map<String, Object?> statRow({
  int games = 10,
  int local = 7,
  int online = 3,
  int first = 4,
  int second = 2,
  int surrendered = 1,
  int bestScore = 238,
  int bestMove = 39,
  int bestWord = 30,
  double avgMove = 13.5,
  String? longest = 'LÖSEMİT',
  int total = 8,
}) =>
    {
      'games_played': games,
      'local_games_played': local,
      'online_games_played': online,
      'first_places': first,
      'second_places': second,
      'surrendered_count': surrendered,
      'best_score': bestScore,
      'best_move_score': bestMove,
      'best_word_score': bestWord,
      'avg_move_score': avgMove,
      'longest_word': longest,
      'total_score': total,
    };

User fakeUser() => User(
      id: 'u-me',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: 'alp.capa@hotmail.com',
    );

const ironman = KProfile(
  id: 'u-me',
  displayName: 'Ironman',
  firstName: 'Alp',
  birthDate: '1990-01-01',
  gender: 'male',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  Future<void> pumpModal(WidgetTester tester, Widget modal) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(body: modal),
    ));
    await tester.pumpAndSettle();
  }

  group('PlayerStats/LeaderboardRow ayrıştırma', () {
    test('eksik/null alanlar güvenli varsayılana düşer', () {
      final s = PlayerStats.fromJson(const {'games_played': 3});
      expect(s.gamesPlayed, 3);
      expect(s.totalScore, 0);
      expect(s.bestWordScore, isNull);
      expect(s.avgMoveScore, isNull);
      expect(s.longestWord, isNull);
    });

    test('shortName: nickname → ad → Anonim (web kısa kimlik kuralı)', () {
      LeaderboardRow row(String? d, String? f) => LeaderboardRow.fromJson({
            'user_id': 'x',
            'display_name': d,
            'first_name': f,
            'total_score': 1,
          });
      expect(row('Ironman', 'Alp').shortName, 'Ironman');
      expect(row(null, 'Alp').shortName, 'Alp');
      expect(row(null, null).shortName, 'Anonim');
    });

    test('StatsTab.playerCount: Genel null, diğerleri 2/4', () {
      expect(StatsTab.all.playerCount, isNull);
      expect(StatsTab.two.playerCount, 2);
      expect(StatsTab.four.playerCount, 4);
    });

    test('repo ağ hatasında null/boş döner, fırlatmaz', () async {
      final repo = StatsRepo(_ThrowingGateway());
      expect(await repo.playerStats('u', StatsTab.all), isNull);
      expect(await repo.leaderboard(limit: 10, offset: 0), isEmpty);
      expect(await repo.myRank('u'), isNull);
    });
  });

  testWidgets('Skor Kartı: kimlik satırı, sekmeler, kutular + ekran görüntüsü',
      (tester) async {
    final gw = FakeStatsGateway(
      stats: {
        'u-me': {
          null: statRow(total: 8),
          2: statRow(games: 6, local: 6, online: 0, total: 6),
          4: statRow(games: 4, local: 1, online: 3, total: 2),
        }
      },
      rank: const {'rank': 3, 'total_score': 8},
    );
    final auth = AuthService.fake(user: fakeUser(), profile: ironman);

    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: ScoreCardModal(auth: auth, stats: StatsRepo(gw)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('SKOR KARTI'), findsOneWidget);
    expect(find.text('Ironman'), findsOneWidget);
    // Doğum tarihi + cinsiyet → "Y:36/C:E" (yaş bugüne göre hesaplanır).
    expect(find.textContaining('/C:E'), findsOneWidget);
    // k-lig satırı: sıra + Genel sekmesinin lig puanı + "?" bilgi rozeti.
    expect(find.text('#3 · 8 puan'), findsOneWidget);
    expect(find.byType(KLigInfoBadge), findsOneWidget);
    // Web `KLigMark`'ın `color` prop varsayılanı mavi (`KLIG_COLOR`) —
    // kapsayan `text-muted` div'i SVG fill'ini etkilemiyor (bkz. dosyadaki
    // düzeltme yorumu); burada `color` OVERRIDE EDİLMEMİŞ olmalı.
    expect(tester.widget<KLigMark>(find.byType(KLigMark)).color, isNull);
    // Sekme çubuğu her sekmenin kendi puanını gösterir.
    expect(find.text('(8 puan)'), findsOneWidget);
    expect(find.text('(6 puan)'), findsOneWidget);
    expect(find.text('(2 puan)'), findsOneWidget);
    // Genel sekmesinin kutuları.
    expect(find.text('TOPLAM OYUN'), findsOneWidget);
    // Türkçe büyük harf: native toUpperCase 'BIRINCILIK'/'KELIME' üretirdi
    // (ekran görüntüsünde yakalandı) — trUpper şart.
    expect(find.text('BİRİNCİLİK'), findsOneWidget);
    expect(find.text('YAPAY ZEKA İLE'), findsOneWidget);
    expect(find.text('EN UZUN KELİME'), findsOneWidget);
    expect(find.text('LÖSEMİT'), findsOneWidget);
    expect(find.text('13.50'), findsOneWidget); // ortalama iki ondalık
    expect(find.text('%70'), findsOneWidget); // Yapay Zeka ile 7/10

    // 4 Oyunculu sekmesine geç — kutular o sekmenin verisine döner.
    await tester.tap(find.text('4 OYUNCULU'));
    await tester.pumpAndSettle();
    expect(find.text('%75'), findsOneWidget); // Arkadaşınla 3/4

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/score_card.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  testWidgets('Skor Kartı: hiç kaydı yoksa boş metin + sıfır kutular',
      (tester) async {
    final gw = FakeStatsGateway(stats: const {}); // satır yok
    await pumpModal(
      tester,
      ScoreCardModal(
        auth: AuthService.fake(user: fakeUser(), profile: ironman),
        stats: StatsRepo(gw),
      ),
    );
    expect(find.text('Henüz hiç oyun kaydın yok.'), findsOneWidget);
    expect(find.text('(0 puan)'), findsNWidgets(3));
    expect(find.text('—'), findsOneWidget); // En Uzun Kelime
  });

  testWidgets('k-lig: ilk 10 + kaydırınca sonraki sayfa + ekran görüntüsü',
      (tester) async {
    final gw = FakeStatsGateway(
      rows: [
        for (var i = 0; i < 25; i++)
          {
            'user_id': 'u-$i',
            'display_name': 'Oyuncu$i',
            'total_score': 100 - i,
          }
      ],
      rank: const {'rank': 42, 'total_score': 5},
      stats: {'u-0': {null: statRow()}},
    );
    final auth = AuthService.fake(user: fakeUser(), profile: ironman);

    // Kısa görünüm — liste (maxHeight = %50) 10 satırla GERÇEKTEN taşsın ki
    // kaydırma/lazy yükleme sınanabilsin.
    await setPhoneViewSize(tester, const Size(420, 620));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: LeaderboardModal(auth: auth, stats: StatsRepo(gw)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Oyuncu0'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(gw.pageRequests.single.limit, 10); // web INITIAL_PAGE_SIZE
    // Kullanıcı listede YOK → "senin sıran" kısayolu.
    expect(find.text('SENİN SIRAN'), findsOneWidget);
    expect(find.text('Sen'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/leaderboard.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    // Sona kaydır → ikinci sayfa (20'lik) istenir.
    await tester.drag(find.text('Oyuncu0'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(gw.pageRequests.length, 2);
    expect(gw.pageRequests.last.limit, 20); // web PAGE_SIZE
    expect(gw.pageRequests.last.offset, 10);
  });

  testWidgets(
      'regresyon (9 Ağustos 2026): liste ilk 10\'a SIĞACAK KADAR uzun bir '
      'ekranda açılırsa (kaydırmaya gerek kalmadan) sonraki sayfa OTOMATİK '
      'yüklenmeli — kullanıcı web/mobil ekran görüntüsü karşılaştırmasıyla '
      'bildirdi: mobilde liste "SENİN SIRAN" kısayoluna takılı kalıyordu, '
      'web aynı kısa listeyi anında tam gösteriyordu', (tester) async {
    final gw = FakeStatsGateway(
      rows: [
        for (var i = 0; i < 12; i++)
          {
            'user_id': i == 11 ? 'u-me' : 'u-$i',
            'display_name': i == 11 ? 'Ironman' : 'Oyuncu$i',
            'total_score': 100 - i,
          }
      ],
      rank: const {'rank': 12, 'total_score': 89},
    );
    final auth = AuthService.fake(user: fakeUser(), profile: ironman);

    // Web'in IntersectionObserver'ı sentinel açılışta zaten görünürse
    // (kısa liste) kaydırmadan tetiklenir — burada da liste (12 satır)
    // %50'lik maxHeight'e (uzun bir viewport'ta) sığacak kadar kısa
    // tutuluyor, kaydırma HİÇ SİMÜLE EDİLMİYOR.
    await setPhoneViewSize(tester, const Size(420, 1600));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        body: LeaderboardModal(auth: auth, stats: StatsRepo(gw)),
      ),
    ));
    await tester.pumpAndSettle();

    // İkinci sayfa (kalan 2 satır) kendiliğinden istenmiş olmalı.
    expect(gw.pageRequests.length, 2,
        reason: 'Liste kaydırmaya gerek kalmadan otomatik tamamlanmalıydı — '
            'gerçek istek sayısı: ${gw.pageRequests.length}');
    expect(gw.pageRequests.last, (limit: 20, offset: 10));

    // Kullanıcı artık listede GERÇEK adıyla görünmeli — "senin sıran"
    // kısayolu/"Sen" yer tutucusu hiç çizilmemeli.
    expect(find.text('SENİN SIRAN'), findsNothing);
    expect(find.text('Sen'), findsNothing);
    expect(find.text('Ironman'), findsOneWidget);
    expect(find.text('89'), findsOneWidget); // gerçek puanı — myRank'in 89'u değil
  });

  testWidgets('k-lig: satıra dokunmak o oyuncunun kartını açar',
      (tester) async {
    final gw = FakeStatsGateway(
      rows: const [
        {'user_id': 'u-9', 'display_name': 'Esiner', 'total_score': 12}
      ],
      stats: {
        'u-9': {null: statRow(games: 5, longest: 'KELİMEKİ', total: 12)}
      },
    );
    await pumpModal(
      tester,
      LeaderboardModal(
        auth: AuthService.fake(user: fakeUser(), profile: ironman),
        stats: StatsRepo(gw),
      ),
    );
    await tester.tap(find.text('Esiner'));
    await tester.pumpAndSettle();

    expect(find.text('SKOR KARTI'), findsOneWidget);
    expect(find.text('KELİMEKİ'), findsOneWidget); // o oyuncunun verisi
  });

  testWidgets(
      'regresyon (9 Ağustos 2026): PlayerScoreCard\'ta k-lig satırı + "?" '
      'bilgi rozeti — web ScoreCard/PlayerScoreCard\'ın koşulsuz görünen '
      'butonu (KLigMark mavi + "?" + "#sıra · puan puan"), dokununca '
      '(auth verilmişse) k-lig açılır', (tester) async {
    final gw = FakeStatsGateway(
      rank: const {'rank': 7, 'total_score': 33},
      stats: {'u-9': {null: statRow(total: 33)}},
    );
    final auth = AuthService.fake(user: fakeUser(), profile: ironman);
    await pumpModal(
      tester,
      PlayerScoreCardModal(
        stats: StatsRepo(gw),
        userId: 'u-9',
        name: 'Esiner',
        auth: auth,
      ),
    );

    expect(find.byType(KLigMark), findsOneWidget);
    expect(tester.widget<KLigMark>(find.byType(KLigMark)).color, isNull);
    expect(find.byType(KLigInfoBadge), findsOneWidget);
    expect(find.textContaining('#7'), findsOneWidget);
    expect(find.textContaining('33'), findsWidgets);

    await tester.tap(find.byType(KLigInfoBadge));
    await tester.pumpAndSettle();
    expect(find.textContaining('k-lig, senin gibi'), findsOneWidget);
  });

  testWidgets('k-lig: hiç satır yoksa davet metni', (tester) async {
    await pumpModal(
      tester,
      LeaderboardModal(
        auth: AuthService.fake(user: fakeUser(), profile: ironman),
        stats: StatsRepo(FakeStatsGateway()),
      ),
    );
    expect(find.text('Henüz skor yok. İlk sen ol!'), findsOneWidget);
  });
}

class _ThrowingGateway implements StatsGateway {
  @override
  Future<Map<String, Object?>?> playerStats(String userId, int? playerCount) =>
      Future.error(Exception('ağ'));
  @override
  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset) =>
      Future.error(Exception('ağ'));
  @override
  Future<Map<String, Object?>?> myLeaderboardRank(String userId) =>
      Future.error(Exception('ağ'));
}
