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
import 'package:kelimeki/src/ui/tokens.dart';
import 'package:kelimeki/src/ui/score/leaderboard_modal.dart';
import 'package:kelimeki/src/ui/score/player_score_card_modal.dart';
import 'package:kelimeki/src/ui/score/score_card_modal.dart';
import 'package:kelimeki/src/ui/rank/rank_seal.dart';
import 'package:kelimeki/src/ui/score/score_stats_section.dart';
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

  Future<void> pumpModal(WidgetTester tester, Widget modal,
      [Size view = const Size(420, 900)]) async {
    await setPhoneViewSize(tester, view);
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
    // Web `({c.rate})` — oran PARANTEZ İÇİNDE (9 Ağustos 2026'da port
    // eksiği olarak bulundu, web "(%70)" derken mobil "%70" yazıyordu).
    expect(find.text('(%70)'), findsOneWidget); // Yapay Zeka ile 7/10
    expect(find.text('%70'), findsNothing);

    // 4 Oyunculu sekmesine geç — kutular o sekmenin verisine döner.
    await tester.tap(find.text('4 OYUNCULU'));
    await tester.pumpAndSettle();
    expect(find.text('(%75)'), findsOneWidget); // Arkadaşınla 3/4

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

  // 9 Ağustos 2026 — cihaz testinde "web'deki skor kartı tam açık geliyor
  // ama mobildekini scroll etmek gerekiyor" bildirimi üzerine web'in
  // DERLENMİŞ Tailwind CSS'i (dist/assets/index-*.css) Chromium'da
  // ölçüldü: sekme çubuğu tam 44px. Port 53px çiziyordu — `text-sm`
  // (14px) yerine 13px kullanıyor ve `leading-none`u (line-height 1)
  // hiç taşımamıştı. Bu test o ölçülen değeri sabitliyor.
  testWidgets('Sekme çubuğu web ile aynı yükseklikte (44px)', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final stats = PlayerStats.fromJson(statRow());
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'SpaceGrotesk'),
      home: Scaffold(
        // ÜRETİMDEKİ kısıtı taklit etmek ŞART: modalda çubuk bir
        // SingleChildScrollView'ın Column'unda yaşar, yani SINIRSIZ
        // yükseklik alır. Doğrudan `Center`/`SizedBox` altına konursa
        // sekme butonunun iç Column'u (MainAxisSize.max) tüm ekranı
        // kaplar ve ölçüm 900 çıkar — widget'ın kendi hatası değil,
        // test kurgusunun hatası olur.
        body: SizedBox(
          width: 320, // web: modal 360 − px-5×2
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScoreTabsBar(
                tab: StatsTab.all,
                onChanged: (_) {},
                statsByTab: {
                  StatsTab.all: stats,
                  StatsTab.two: stats,
                  StatsTab.four: stats,
                },
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ScoreTabsBar)).height, 44.0);
  });

  // 9 Ağustos 2026 — kullanıcı web test derlemesinde kartın kesildiğini
  // (kaydırma gerektiğini) bildirdi. ÖLÇÜLDÜ: kartın gerçek içerik
  // yüksekliği 633 logical px, web'in aynı kartı (derlenmiş Tailwind CSS'i
  // Chromium'da ölçüldü) 655 — yani içerik paritesi sorun DEĞİL. Kaydırma
  // yalnızca ÜST SINIRDAN geliyor: `KModal` web'in `max-h-[85vh]`ini
  // `MediaQuery.height × 0.85` olarak porta taşıyor; web test derlemesinde
  // Flutter canvas'ı tarayıcı kromu kadar KISA (iPad'de ~700 logical),
  // CSS `vh` ise kromu saymadığından web'in sınırı bağlamıyor. Bu test,
  // GERÇEK cihaz boyutlarında kartın sınıra HİÇ dayanmadığını (yani
  // kaydırma GEREKMEDİĞİNİ) sabitliyor — ileride içerik büyürse yakalar.
  testWidgets('Skor Kartı gerçek cihaz boyutlarında kaydırmasız sığar',
      (tester) async {
    final gw = FakeStatsGateway(
      stats: {
        'u-me': {
          // En uzun gerçek içerik: 3 haneli rakamlar + 8 harfli kelime.
          null: statRow(games: 89, local: 74, online: 15, first: 35,
              second: 32, surrendered: 6, bestScore: 333, bestMove: 96,
              bestWord: 36, avgMove: 12.72, longest: 'ÇALIŞKAN', total: 70),
        },
      },
      rank: const {'rank': 1, 'total_score': 70},
    );
    final auth = AuthService.fake(user: fakeUser(), profile: ironman);

    // iPhone 14 (390×844) ve iPad portre (834×1194) — MediaQuery, native
    // uygulamada TAM EKRANDIR (tarayıcı kromu yok).
    for (final view in const [Size(390, 844), Size(834, 1194)]) {
      await pumpModal(
          tester, ScoreCardModal(auth: auth, stats: StatsRepo(gw)), view);
      final card = tester.getSize(find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 360));
      expect(card.height, lessThan(view.height * 0.85),
          reason: '$view: kart %85 sınırına dayanıyor → kaydırma gerekir');
    }
  });

  testWidgets('Skor Kartı başlığı: ✕ sağa dayalı, mühür başlık ile ✕ arasında',
      (tester) async {
    // 12 Ağustos 2026, kullanıcı cihazda bildirdi: "mobilde skor kartta X
    // kaymış". Kök sebep `KModal._headerTitle`: web'in `shrink-0`'ı porta
    // `Flexible(child: label)` diye geçmişti, ama `Flexible`ın varsayılanı
    // `flex: 1` — başlık boş alanın YARISINI pay olarak alıyor, `fit: loose`
    // olduğundan doğal genişliğinde kalıyor ve ARTAN pay yeniden
    // dağıtılmadığından Row'un sonunda ölü boşluk olarak birikiyordu.
    // Ölçüldü: ✕ merkezi sağ kenardan 75.3px içerideydi (web: 35.0).
    final gw = FakeStatsGateway(
      stats: {
        'u-me': {null: statRow(total: 85)}
      },
      rank: const {'rank': 1, 'total_score': 85},
    );
    final auth = AuthService.fake(user: fakeUser(), profile: ironman);
    await pumpModal(tester, ScoreCardModal(auth: auth, stats: StatsRepo(gw)));

    final kart = tester.getRect(find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 360));
    final kapat = tester.getRect(find.byType(IconButton).first);
    final muhur = tester.getRect(find.byType(RankSeal).first);

    // Web'de ✕'in merkezi sağ kenardan 35.0px içeride (ölçüldü: p-5 dolgu +
    // 28px buton). Portta buton daha büyük (40px, dokunma hedefi) ve sağ
    // dolgu 12 — merkez 32.0'a düşüyor, yani GÖRSEL konum aynı.
    expect(kart.right - kapat.center.dx, closeTo(32, 4),
        reason: '✕ sağa dayalı olmalı (web ile aynı görsel konum)');
    // Mühür kartın ortasında DEĞİL, başlık ile ✕ arasının ortasında —
    // yani merkezden SAĞDA (web ölçümü: +35.6).
    expect(muhur.center.dx - kart.center.dx, closeTo(35, 6),
        reason: 'mühür başlık ile ✕ arasında ortalanmalı');
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

  // OHP = ortalama hamle puanı (12 Ağustos 2026, kullanıcı isteği): "Puan"ın
  // SOLUNDA, düz gri, 2 basamak; başlığa dokununca açıklama açılıp kapanıyor.
  // Sayı sunucuda `player_stats_overall.avg_move_score` ile AYNI ifadeden
  // geliyor — burada sınanan, o sayının doğru YERDE ve doğru BİÇİMDE
  // gösterilmesi.
  testWidgets('k-lig: OHP kolonu — düz gri, 2 basamak, boşta —, hint toggle',
      (tester) async {
    final gw = FakeStatsGateway(
      rows: [
        {
          'user_id': 'u-0',
          'display_name': 'Oyuncu0',
          'total_score': 100,
          'avg_move_score': 12.78,
        },
        {
          // Hiç hamle verisi olmayan (eski) kayıt → satırın "Puan"
          // hücresiyle AYNI kuralla "—".
          'user_id': 'u-1',
          'display_name': 'Oyuncu1',
          'total_score': 90,
          'avg_move_score': null,
        },
      ],
      // "Senin sıran" kısayolu da AYNI kolonu doldurmalı; boş kalsaydı o tek
      // satırda tablo hizasız görünürdü (RPC bu yüzden alanı döndürüyor).
      rank: const {'rank': 42, 'total_score': 5, 'avg_move_score': 6.7},
    );
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpModal(
      tester,
      LeaderboardModal(
        auth: AuthService.fake(user: fakeUser(), profile: ironman),
        stats: StatsRepo(gw),
      ),
    );

    // Başlık sırası: … OYUNCU | OHP | PUAN  (OHP, PUAN'ın SOLUNDA)
    expect(find.text('OHP'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('OHP')).dx,
      lessThan(tester.getTopLeft(find.text('PUAN')).dx),
    );

    // Değer 2 basamak, DÜZ GRİ, kalın DEĞİL ve satırın kendi 14px'inden
    // KÜÇÜK (Puan mavi/kalın/14 kalır — "gri yaptım" iddiası Puan'ı da
    // griye çekseydi bu ikinci blok olmadan geçerdi).
    final ohp = tester.widget<Text>(find.text('12.78'));
    expect(ohp.style?.color, kMuted);
    expect(ohp.style?.fontWeight, isNot(FontWeight.bold));
    expect(ohp.style?.fontSize, 11);
    final puan = tester.widget<Text>(find.text('100'));
    expect(puan.style?.color, kAccent);
    expect(puan.style?.fontWeight, FontWeight.bold);
    expect(puan.style?.fontSize, 14);

    // Verisi olmayan satır ve "senin sıran" kısayolu.
    expect(find.text('—'), findsOneWidget); // Oyuncu1
    expect(find.text('6.70'), findsOneWidget); // myRank

    // Açıklama balonu: başlangıçta kapalı, başlığa dokununca açılıyor,
    // TEKRAR dokununca VE dışarı dokununca kapanıyor (dokunmatikte hover
    // DİYE BİR ŞEY olmadığından keşfedilebilir tek yol dokunuş). Metin
    // BİLEREK dizeyle yazılıyor, `ohpHint` sabitiyle değil: sabite
    // bağlanan bir assertion, widget balonu hiç göstermese bile derlenir
    // — negatif eş kanıtlanamazdı.
    const hint =
        'Ortalama Hamle Puanı tüm oyunlarda yapılan tüm hamlelerin ortalamasıdır.';
    expect(find.text(hint), findsNothing);
    await tester.tap(find.text('OHP'));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);

    // Balon başlığın TAM ÜSTÜNDE (altında/yanında değil).
    expect(
      tester.getRect(find.text(hint)).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('OHP')).top),
    );

    // Dışarı dokunuş kapatır (tam ekran bariyer).
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);

    // Tekrar aç, bu kez başlığın kendisine dokunarak kapat — bariyer
    // başlığı da kapladığından dokunuş oraya düşüyor (warnIfMissed
    // kapalı: hedef widget ağaçta ama üstünde bariyer var).
    await tester.tap(find.text('OHP'));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
    await tester.tap(find.text('OHP'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);
  });

  test('parseNullableDouble: sayı da dize de kabul edilir', () {
    // PostgREST'in `numeric`i JSON'da sayı olarak döndürdüğü varsayılıyor
    // (PlayerStats bunu cihazda kanıtladı) ama bu ortamdan REST ucuna
    // erişilemiyor; bir dize gelirse `as num?` tüm listeyi düşürürdü.
    expect(parseNullableDouble(12.78), 12.78);
    expect(parseNullableDouble(12), 12.0);
    expect(parseNullableDouble('12.78'), 12.78);
    expect(parseNullableDouble(null), isNull);
    expect(parseNullableDouble('abc'), isNull);
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
