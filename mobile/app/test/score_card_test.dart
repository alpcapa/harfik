// Skor Kartı + k-lig + oyuncu kartı (parça 4) — sahte bir StatsGateway ile.
// Gerçek uç (SupabaseStatsGateway: player_stats/player_stats_overall/
// leaderboard/my_leaderboard_rank) cihazda doğrulanır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/text_scale.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/data/stats_api.dart';
import 'package:kelimeki/src/ui/score/klig_mark.dart';
import 'package:kelimeki/src/ui/tokens.dart';
import 'package:kelimeki/src/ui/score/leaderboard_modal.dart';
import 'package:kelimeki/src/ui/score/player_score_card_modal.dart';
import 'package:kelimeki/src/ui/score/score_card_modal.dart';
import 'package:kelimeki/src/ui/rank/rank_seal.dart';
import 'package:kelimeki/src/ui/score/score_stats_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

class FakeStatsGateway implements StatsGateway {
  /// playerCount → satır (null anahtarı 'Genel' = player_stats_overall).
  final Map<String, Map<int?, Map<String, Object?>>> stats;
  final List<Map<String, Object?>> rows;
  final Map<String, Object?>? rank;

  /// userId → `get_profile_age_gender` satırı (`{'age': .., 'gender': ..}`).
  /// Verilmeyen kullanıcı için null döner, yani kartta satır çizilmez.
  final Map<String, Map<String, Object?>?> ageGender;

  /// Kaç kez sayfa istendi (lazy yükleme testi).
  final pageRequests = <({int limit, int offset})>[];

  FakeStatsGateway({
    this.stats = const {},
    this.rows = const [],
    this.rank,
    this.ageGender = const {},
  });

  @override
  Future<Map<String, Object?>?> playerStats(String userId, int? playerCount) async =>
      stats[userId]?[playerCount];

  @override
  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset) async {
    pageRequests.add((limit: limit, offset: offset));
    // Gerçek uç gibi: sıra SUNUCUDAN gelir (`k_lig_siralama.sira`), istemci
    // onu listedeki indeksten türetmez. Fikstür `sira` vermediyse burada
    // konumdan damgalanır (fikstürlerin `rows`u zaten sıralı) — açıkça
    // verilmişse dokunulmaz, böylece "indeksten türetmiyor" negatif eşi
    // yazılabiliyor.
    return [
      for (final (i, r) in rows.skip(offset).take(limit).indexed)
        {'sira': offset + i + 1, ...r},
    ];
  }

  @override
  Future<Map<String, Object?>?> myLeaderboardRank(String userId) async => rank;

  /// Gerçek uç gibi: `leaderboard` view'ı `games`e INNER JOIN yaptığından
  /// hiç oyunu olmayan (yani `rows`ta bulunmayan) id sonuçta YOKTUR.
  @override
  Future<List<Map<String, Object?>>> rankScores(List<String> userIds) async => [
        for (final r in rows)
          if (userIds.contains(r['user_id']))
            {'user_id': r['user_id'], 'total_score': r['total_score']},
      ];

  @override
  Future<Map<String, Object?>?> profileAgeGender(String userId) async =>
      ageGender[userId];

  /// Kafa kafaya satırı — testler tek tek doldurabilsin diye alan.
  Map<String, Object?>? h2h;

  @override
  Future<Map<String, Object?>?> headToHead(String otherUserId) async => h2h;
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
      theme: kelimekiTheme(),
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
      theme: kelimekiTheme(),
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
    // Satır artık düz bir `Text` DEĞİL `Text.rich` — ayırıcının iki yanındaki
    // boşluk web'in `mx-0.5`'i (2px WidgetSpan), boşluk KARAKTERİ değil
    // (17 Ağustos 2026, Blok 6 madde 9; Space Mono'da bir boşluk 13px'te
    // ~7.8px eder ve kullanıcı "nokta sağı ve solu web'e göre daha açık"
    // diye bildirmişti). Bu yüzden `find.text('#3 · 8 puan')` ARTIK
    // EŞLEŞMEZ; test hem metni hem 2px'lik boşluğu doğruluyor.
    final kligLine = tester.widgetList<Text>(find.byType(Text)).firstWhere(
        (w) =>
            w.textSpan?.toPlainText(includePlaceholders: false).contains('#3') ??
            false);
    expect(kligLine.textSpan!.toPlainText(includePlaceholders: false),
        '#3·8 puan');
    final gaps =
        (kligLine.textSpan! as TextSpan).children!.whereType<WidgetSpan>();
    expect(gaps.length, 2);
    for (final g in gaps) {
      expect((g.child as SizedBox).width, 2);
    }
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
      theme: kelimekiTheme(),
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
    // 18 Ağustos 2026'dan beri kartta İKİ mühür var (başlıktaki 34px +
    // ismin yanındaki 20px) — sıraya güvenme, BOYA göre seç.
    final muhur = tester.getRect(
        find.byWidgetPredicate((w) => w is RankSeal && w.size == 34));

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

  testWidgets(
      'Skor Kartı: ismin yanında da 20px rütbe mührü (18 Ağustos 2026) — '
      'başlıktaki 34px mühür DURUYOR, o tıklanabilir olan', (tester) async {
    final gw = FakeStatsGateway(
      stats: {
        'u-me': {null: statRow(total: 85)}
      },
      rank: const {'rank': 1, 'total_score': 85},
    );
    final auth = AuthService.fake(user: fakeUser(), profile: ironman);
    await pumpModal(tester, ScoreCardModal(auth: auth, stats: StatsRepo(gw)));

    expect(find.byWidgetPredicate((w) => w is RankSeal && w.size == 34),
        findsOneWidget,
        reason: 'başlık mührü kaybolmamalı');
    final name = find.byWidgetPredicate((w) => w is RankSeal && w.size == 20);
    expect(name, findsOneWidget, reason: 'isim yanında mühür çizilmemiş');
    expect(tester.getTopLeft(name).dx,
        greaterThanOrEqualTo(tester.getTopRight(find.text('Ironman')).dx),
        reason: 'mühür ismin SAĞINDA olmalı');
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
      theme: kelimekiTheme(),
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
      theme: kelimekiTheme(),
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

  testWidgets(
      'regresyon (20 Ağustos 2026): sıra numarası SUNUCUDAN okunuyor, '
      'listedeki indeksten TÜRETİLMİYOR — eşit puanlılar OHP\'ye göre '
      'ayrıştığından liste ile Skor Kartı\'ndaki "#sıra" ancak böyle aynı '
      'sayıyı gösterir (kullanıcı bildirdi: aynı oyuncu listede 13., kendi '
      'kartında #10 görünüyordu)', (tester) async {
    // Fikstür `sira`yı AÇIKÇA veriyor ve bilerek indeksle ÇAKIŞMIYOR:
    // indeksten türeten bir uygulama 1/2/3 çizerdi.
    final gw = FakeStatsGateway(
      rows: const [
        {
          'sira': 10,
          'user_id': 'u-a',
          'display_name': 'T3',
          'total_score': 20,
          'avg_move_score': 12.79
        },
        {
          'sira': 11,
          'user_id': 'u-b',
          'display_name': 'Tess',
          'total_score': 20,
          'avg_move_score': 10.59
        },
        {
          'sira': 12,
          'user_id': 'u-c',
          'display_name': 'Bobola',
          'total_score': 20,
          'avg_move_score': 10.15
        },
      ],
    );
    await pumpModal(
      tester,
      LeaderboardModal(
        auth: AuthService.fake(user: fakeUser(), profile: ironman),
        stats: StatsRepo(gw),
      ),
    );

    expect(find.text('10'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    // Negatif eş: indeksten türetilseydi bunlar çizilirdi.
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);
    // Eşit puanda sıra OHP'ye göre: yüksek OHP üstte.
    expect(find.text('12.79'), findsOneWidget);
    expect(find.text('10.15'), findsOneWidget);
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

  testWidgets(
      '29 Ağustos 2026 (kullanıcı isteği): yaş/cinsiyet satırı BAŞKASININ '
      'kartında da çizilir — veri `profiles`ten değil `get_profile_age_gender` '
      "RPC'sinden gelir (o satırın SELECT RLS'i başkasına kapalı)",
      (tester) async {
    final gw = FakeStatsGateway(
      stats: {'u-9': {null: statRow(total: 33)}},
      ageGender: const {
        'u-9': {'age': 59, 'gender': 'male'},
      },
    );
    await pumpModal(
      tester,
      PlayerScoreCardModal(
        stats: StatsRepo(gw),
        userId: 'u-9',
        name: 'Esiner',
      ),
    );

    expect(find.text('Y:59/C:E'), findsOneWidget);
  });

  testWidgets(
      'yaş/cinsiyet satırı: veri girilmemişse (RPC null alanlar döndürür) '
      'satır HİÇ çizilmez — boş bir satır yer kaplamamalı', (tester) async {
    final gw = FakeStatsGateway(
      stats: {'u-9': {null: statRow(total: 33)}},
      ageGender: const {
        'u-9': {'age': null, 'gender': null},
      },
    );
    await pumpModal(
      tester,
      PlayerScoreCardModal(
        stats: StatsRepo(gw),
        userId: 'u-9',
        name: 'Esiner',
      ),
    );

    expect(find.textContaining('Y:'), findsNothing);
    expect(find.textContaining('C:'), findsNothing);
  });

  // ------------------------------------------------------------------
  // Kafa kafaya oran çubuğu (3 Eylül 2026, kullanıcı isteği, Parça 185).
  // Saf kural `head_to_head_test.dart`te; buradakiler çubuğun DOĞRU KARTTA
  // çizildiğini (ve yanlış kartlarda ÇİZİLMEDİĞİNİ) kilitliyor — üçü de
  // pozitif testin negatif eşi.
  // ------------------------------------------------------------------
  testWidgets(
      'kafa kafaya: BAŞKASININ kartında oyun sayısı + üç dilimli çubuk '
      'çizilir; isim YAZILMAZ (kullanıcı: "İsim yazmayacak")', (tester) async {
    final gw = FakeStatsGateway(stats: {
      'u-9': {null: statRow(total: 33)}
    })
      ..h2h = const {'games': 14, 'wins': 9, 'losses': 5, 'draws': 0};
    final gamesRepo = await newRepoForWidget(tester, FakeGamesGateway());
    await pumpModal(
      tester,
      PlayerScoreCardModal(
        auth: AuthService.fake(user: fakeUser(), profile: ironman),
        stats: StatsRepo(gw),
        games: Future.value(gamesRepo),
        userId: 'u-9',
        name: 'Esiner',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('14 oyun'), findsOneWidget);
    // 5 kayıp / 0 beraberlik / 9 galibiyet → sol 36, orta 0 (ÇİZİLMEZ),
    // sağ 64. Yani tam İKİ dilim olmalı; üç değil.
    final dilimler = tester
        .widgetList<ColoredBox>(find.descendant(
            of: find.byType(Semantics), matching: find.byType(ColoredBox)))
        .where((b) => b.color == kRed || b.color == kMuted || b.color == kGreen)
        .toList();
    expect(dilimler.length, 2);
    expect(dilimler.map((b) => b.color), [kRed, kGreen]);
    // İsim çubuğun yanında YAZILMAZ — yalnızca başlıkta geçer.
    expect(find.text('Esiner'), findsOneWidget);
    expect(find.text('Sen'), findsNothing);
  });

  testWidgets(
      'kafa kafaya: KENDİ kartında çubuk HİÇ çizilmez — istek de atılmaz',
      (tester) async {
    final gw = FakeStatsGateway(stats: {
      'u-me': {null: statRow(total: 33)}
    })
      ..h2h = const {'games': 14, 'wins': 9, 'losses': 5, 'draws': 0};
    final gamesRepo = await newRepoForWidget(tester, FakeGamesGateway());
    await pumpModal(
      tester,
      PlayerScoreCardModal(
        auth: AuthService.fake(user: fakeUser(), profile: ironman),
        stats: StatsRepo(gw),
        games: Future.value(gamesRepo),
        userId: 'u-me',
        name: 'Ironman',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('14 oyun'), findsNothing);
  });

  testWidgets(
      'kafa kafaya: hiç oynanmamışsa (games=0) çubuk çizilmez — "0 oyun" '
      'yazan boş bir şerit kalmamalı', (tester) async {
    final gw = FakeStatsGateway(stats: {
      'u-9': {null: statRow(total: 33)}
    })
      ..h2h = const {'games': 0, 'wins': 0, 'losses': 0, 'draws': 0};
    final gamesRepo = await newRepoForWidget(tester, FakeGamesGateway());
    await pumpModal(
      tester,
      PlayerScoreCardModal(
        auth: AuthService.fake(user: fakeUser(), profile: ironman),
        stats: StatsRepo(gw),
        games: Future.value(gamesRepo),
        userId: 'u-9',
        name: 'Esiner',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 oyun'), findsNothing);
    expect(find.text('TÜM OYUNLAR'), findsOneWidget);
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

    // 14 Ağustos 2026 (kullanıcı isteği): OHP, Puan'a YAKLAŞTIRILDI.
    // OHP sağa hizalı olduğundan KENDİ genişliği konumunu etkilemiyor —
    // onu sağa taşıyan tek şey Puan kutusunun daralması (52 → 44, web'de
    // w-12 → w-10 ile AYNI 8px). Ölçülen şey bu yüzden OHP'nin SAĞ kenarı
    // ile satırın sağ kenarı arasındaki mesafe.
    // İki değer de kendi kutusunda SAĞA hizalı ve kutular Row'da bitişik,
    // yani aradaki mesafe tam olarak Puan kutusunun genişliği: 52 iken 44.
    final ohpRight = tester.getBottomRight(find.text('12.78')).dx;
    final puanRight = tester.getBottomRight(find.text('100')).dx;
    expect(puanRight - ohpRight, closeTo(44, 0.5),
        reason: 'OHP, Puan\'a yaklaştırıldı — Puan kutusu 52 değil 44');

    // 14 Ağustos 2026 (kullanıcı: "OHP başlığı ortalı değil") — başlık ile
    // değerin ink MERKEZLERİ çakışmalı. Sözleşme üç parçalı ve üçü birden
    // gerekli: sütun genişliği DEĞERİN ink genişliğine eşit + değer SAĞA
    // yaslı + başlık ORTALI. Biri bozulursa merkezler ayrışır (eski hâlde
    // kutu 52 + başlık sağa yaslıydı, başlık değerin ~7px sağındaydı).
    // ⚠ ÖLÇÜM `Text`TEN `ScaledCell`E TAŞINDI (2 Eylül 2026). Sütun sınıf
    // 3 için `ScaledCell`e çevrildiğinde (`Align`+`FittedBox`) `Text` artık
    // kutuyu DOLDURMUYOR, kendi mürekkebine küçülüyor: başlık 19,5 px,
    // değer 33,7 px ölçüldü ve bu iddia düştü. Sözleşme değişmedi —
    // ölçülecek şey KUTU, ve kutu artık `ScaledCell`.
    Rect hucre(String metin) => tester.getRect(find.ancestor(
        of: find.text(metin), matching: find.byType(ScaledCell)));
    final ohpBox = hucre('12.78');
    final hdrBox = hucre('OHP');
    expect(hdrBox.width, closeTo(ohpBox.width, 0.5),
        reason: 'başlık ve değer AYNI genişlikte kutuda olmalı');
    // Merkezler de çakışmalı (başlık ortalı + değer sağa yaslı + kutular
    // eşit → aynı eksen). Kutu ölçümüne geçince bu doğrudan sınanabilir.
    // Tolerans 1,5 px ve bu ÖLÇÜLDÜ, tahmin edilmedi: başlık satırının
    // kendi yatay dolgusu (8) veri satırınınkinden farklı olduğundan
    // merkezler tam çakışmıyor, 1,0 px kayıyor. Asıl yakalanmak istenen
    // 14 Ağustos'taki ~7 px'lik kayma; 1 px göze görünmüyor.
    expect(hdrBox.center.dx, closeTo(ohpBox.center.dx, 1.5),
        reason: 'başlık ile değer aynı eksende olmalı');
    expect(tester.widget<Text>(find.text('OHP')).textAlign, TextAlign.center);
    expect(tester.widget<Text>(find.text('12.78')).textAlign, TextAlign.right);
    // Kutu genişliği gerçekten değerin ink genişliği mi? (Sabit tahminle
    // değil, aynı stille ÖLÇÜLEREK — punto/biçim değişirse bu düşer.)
    final tp = TextPainter(
      text: const TextSpan(
        text: '12.78',
        style: TextStyle(fontFamily: 'SpaceMono', fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(tp.width, closeTo(ohpBox.width, 1.0),
        reason: 'sütun genişliği = değerin ink genişliği (≈34)');

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
        'Ortalama Hamle Puanı tüm oyunlarda yapılan tüm hamlelerin ortalamasıdır. '
        'Puanlar eşitse OHP yüksek olan üstte sıralanır.';
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
  @override
  Future<List<Map<String, Object?>>> rankScores(List<String> userIds) =>
      Future.error(Exception('ağ'));
  @override
  Future<Map<String, Object?>?> profileAgeGender(String userId) =>
      Future.error(Exception('ağ'));

  @override
  Future<Map<String, Object?>?> headToHead(String otherUserId) =>
      Future.error(Exception('ağ'));
}
