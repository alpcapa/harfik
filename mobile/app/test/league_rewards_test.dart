// k-lig Ödül & Rütbe Sistemi (Parça 61) — web `leagueRank.ts` /
// `LeagueRewardsHost.buildSummary` / `RewardBanner` / `RankInfoModal`
// portunun testleri. Veri katmanı sahte bir gateway ile sınanır; gerçek uç
// (`league_rewards` tablosu + `mark_league_rewards_seen` RPC'si) cihazda
// doğrulanır (bkz. mobile/TESTING.md bölüm 12).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/league_rewards_api.dart';
import 'package:kelimeki/src/data/stats_api.dart';
import 'package:kelimeki/src/ui/rank/league_rank.dart';
import 'package:kelimeki/src/ui/rank/league_rewards_host.dart';
import 'package:kelimeki/src/ui/rank/rank_info_modal.dart';
import 'package:kelimeki/src/ui/rank/rank_progress_bar.dart';
import 'package:kelimeki/src/ui/rank/rank_seal.dart';
import 'package:kelimeki/src/ui/rank/reward_banner.dart';
import 'package:kelimeki/src/ui/tokens.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

class FakeRewardsGateway implements LeagueRewardsGateway {
  List<Map<String, Object?>> rows;
  int markSeenCalls = 0;
  int unseenCalls = 0;
  bool throwOnUnseen = false;
  bool throwOnMark = false;

  FakeRewardsGateway({this.rows = const []});

  @override
  Future<List<Map<String, Object?>>> unseen(String userId) async {
    unseenCalls++;
    if (throwOnUnseen) throw Exception('ağ hatası');
    return rows;
  }

  @override
  Future<void> markSeen() async {
    markSeenCalls++;
    if (throwOnMark) throw Exception('ağ hatası');
    // Gerçek RPC gibi: bir daha görülmemiş satır dönmez.
    rows = const [];
  }
}

Map<String, Object?> rewardRow(String kind, int threshold, {int points = 0}) =>
    {
      'id': '$kind-$threshold',
      'kind': kind,
      'threshold': threshold,
      'points': points,
      'seen_at': null,
      'created_at': '2026-08-12T09:00:00Z',
    };

List<LeagueReward> parse(List<Map<String, Object?>> rows) =>
    [for (final r in rows) LeagueReward.fromJson(r)];

class FakeStatsGatewayForRank implements StatsGateway {
  final Map<String, Object?>? rank;
  FakeStatsGatewayForRank(this.rank);

  @override
  Future<Map<String, Object?>?> playerStats(
          String userId, int? playerCount) async =>
      null;

  @override
  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset) async =>
      const [];

  @override
  Future<Map<String, Object?>?> myLeaderboardRank(String userId) async => rank;
}

User fakeUser([String id = 'u-me']) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  tearDown(debugResetLeagueRewardHosts);

  group('tierFor — eşik merdiveni (web leagueRank.ts birebir)', () {
    test('eşik sınırları: eşiğin KENDİSİ yeni kademeye girer', () {
      expect(tierFor(0).name, 'Çaylak');
      expect(tierFor(49).name, 'Çaylak');
      expect(tierFor(50).name, 'Meraklı');
      expect(tierFor(99).name, 'Meraklı');
      expect(tierFor(100).name, 'Oyuncu');
      expect(tierFor(199).name, 'Oyuncu');
      expect(tierFor(200).name, 'Usta');
      expect(tierFor(499).name, 'Usta');
      expect(tierFor(500).name, 'Şampiyon');
      expect(tierFor(999).name, 'Şampiyon');
      expect(tierFor(1000).name, 'Destan');
      expect(tierFor(99999).name, 'Destan');
    });

    test('negatif puan ve null Çaylak\'a düşer (-2 cezaları mümkün kılıyor)',
        () {
      expect(tierFor(-2).name, 'Çaylak');
      expect(tierFor(-500).name, 'Çaylak');
      expect(tierFor(null).name, 'Çaylak');
    });

    test('renkler token\'dan gelir — yerel kopya YOK', () {
      expect(tierFor(0).color, kTilePts);
      expect(tierFor(50).color, kAccent);
      expect(tierFor(100).color, kGreen);
      expect(tierFor(200).color, kGold);
      expect(tierFor(500).color, kOrange);
      expect(tierFor(1000).color, kRed);
    });

    test('ödül tablosu SQL ile aynı: 50→5, 100→10, 200→25, 500→50, 1000→100',
        () {
      expect([for (final t in kRankTiers) t.threshold],
          [0, 50, 100, 200, 500, 1000]);
      expect([for (final t in kRankTiers) t.reward], [0, 5, 10, 25, 50, 100]);
    });

    test('nextTierAfter: en üstte null', () {
      expect(nextTierAfter(tierFor(0))!.name, 'Meraklı');
      expect(nextTierAfter(tierFor(500))!.name, 'Destan');
      expect(nextTierAfter(tierFor(1000)), isNull);
    });
  });

  group('rewardAlreadyClaimed — bonus_points\'ten prefix çıkarımı', () {
    RankTier t(int th) => tierFor(th);

    test('kümülatif toplam hangi eşiklerin ödendiğini tekil belirler', () {
      // 0 → hiçbiri
      expect(rewardAlreadyClaimed(t(50), 0), isFalse);
      // 5 → yalnızca 50
      expect(rewardAlreadyClaimed(t(50), 5), isTrue);
      expect(rewardAlreadyClaimed(t(100), 5), isFalse);
      // 15 → 50 + 100
      expect(rewardAlreadyClaimed(t(100), 15), isTrue);
      expect(rewardAlreadyClaimed(t(200), 15), isFalse);
      // 40 → 50 + 100 + 200
      expect(rewardAlreadyClaimed(t(200), 40), isTrue);
      expect(rewardAlreadyClaimed(t(500), 40), isFalse);
      // 190 → hepsi
      expect(rewardAlreadyClaimed(t(1000), 190), isTrue);
    });

    test('Çaylak\'ın ödülü yok → hiçbir bonus değerinde "alınmış" olmaz', () {
      expect(rewardAlreadyClaimed(t(0), 0), isFalse);
      expect(rewardAlreadyClaimed(t(0), 190), isFalse);
    });
  });

  group('buildRewardSummary — birleştirme + öncelik kuralı', () {
    test('ödüller toplanır, en yüksek eşik taşınır', () {
      final s = buildRewardSummary(parse([
        rewardRow('points_reward', 50, points: 5),
        rewardRow('points_reward', 100, points: 10),
      ]));
      expect(s.rewardPoints, 15);
      expect(s.rewardThreshold, 100);
      expect(s.rankUpTier, isNull);
      expect(s.rankDown, isNull);
    });

    test('rank_up: en yüksek eşiğin kademesi', () {
      final s = buildRewardSummary(parse([
        rewardRow('rank_up', 50),
        rewardRow('rank_up', 100),
      ]));
      expect(s.rankUpTier!.name, 'Oyuncu');
    });

    test('milestone: en yüksek', () {
      final s = buildRewardSummary(parse([
        rewardRow('points_milestone', 100),
        rewardRow('points_milestone', 200)
      ]));
      expect(s.milestone, 200);
    });

    test('rank_down tek başınayken: EN DÜŞÜK eşik + yeni (alt) kademe', () {
      final s = buildRewardSummary(parse([
        rewardRow('rank_down', 200),
        rewardRow('rank_down', 100),
      ]));
      expect(s.rankDown!.fromThreshold, 100);
      // 100'ün altı → Meraklı (50).
      expect(s.rankDown!.newTier.name, 'Meraklı');
    });

    test('ÖNCELİK: olumlu bir olay varsa üzgün banner BASTIRILIR', () {
      for (final positive in [
        rewardRow('rank_up', 100),
        rewardRow('points_milestone', 100),
        rewardRow('points_reward', 50, points: 5),
      ]) {
        final s =
            buildRewardSummary(parse([rewardRow('rank_down', 100), positive]));
        expect(s.rankDown, isNull,
            reason:
                'olumlu olay ${positive['kind']} varken rankDown dolmamalı');
      }
      // Negatif eş: olumlu olay YOKKEN gerçekten doluyor.
      expect(buildRewardSummary(parse([rewardRow('rank_down', 100)])).rankDown,
          isNotNull);
    });

    test('bilinmeyen tür YOK SAYILIR (eski istemci banner uydurmaz)', () {
      final s = buildRewardSummary(parse([rewardRow('gelecekteki_tur', 999)]));
      expect(s.isEmpty, isTrue);
    });
  });

  group('LeagueRewardsRepo — sahte gateway', () {
    test('unseen ayrıştırır; markSeen RPC\'yi çağırır', () async {
      final gw =
          FakeRewardsGateway(rows: [rewardRow('points_reward', 50, points: 5)]);
      final repo = LeagueRewardsRepo(gw);
      final rows = await repo.unseen('u-me');
      expect(rows, hasLength(1));
      expect(rows.first.kind, LeagueRewardKind.pointsReward);
      expect(rows.first.points, 5);
      expect(rows.first.seenAt, isNull);
      await repo.markSeen();
      expect(gw.markSeenCalls, 1);
      expect(await repo.unseen('u-me'), isEmpty);
    });

    test('ağ hatası fırlatmaz — boş liste / sessiz markSeen', () async {
      final gw = FakeRewardsGateway()
        ..throwOnUnseen = true
        ..throwOnMark = true;
      final repo = LeagueRewardsRepo(gw);
      expect(await repo.unseen('u-me'), isEmpty);
      await repo.markSeen(); // fırlatmamalı
    });
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    required FakeRewardsGateway gw,
    AuthService? auth,
    StatsRepo? stats,
    bool suppress = false,
  }) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: LeagueRewardsHost(
        rewards: LeagueRewardsRepo(gw),
        auth: auth ?? AuthService.fake(user: fakeUser()),
        stats: stats,
        suppress: suppress,
        child: const Scaffold(body: Center(child: Text('EKRAN'))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('LeagueRewardsHost — banner akışı', () {
    testWidgets('görülmemiş ödül → banner; DEVAM işaretler ve kapatır',
        (tester) async {
      final gw = FakeRewardsGateway(rows: [
        rewardRow('rank_up', 100),
        rewardRow('points_reward', 100, points: 10),
      ]);
      await pumpHost(tester, gw: gw);

      expect(find.text('Yeni rütben: Oyuncu!'), findsOneWidget);
      expect(find.text('100 k-lig puanına ulaştın'), findsOneWidget);
      expect(find.text('+10 ödül puanı eklendi'), findsOneWidget);
      expect(gw.markSeenCalls, 0, reason: 'işaretleme yalnızca DEVAM\'da');

      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();
      expect(gw.markSeenCalls, 1);
      expect(find.byType(RewardBanner), findsNothing);
    });

    testWidgets('suppress=true iken banner ÇIKMAZ; düşünce gösterilir',
        (tester) async {
      final gw = FakeRewardsGateway(rows: [rewardRow('rank_up', 50)]);
      await pumpHost(tester, gw: gw, suppress: true);
      expect(find.byType(RewardBanner), findsNothing);

      // Oyun bitti → suppress düşer → host kendiliğinden kontrol eder.
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'SpaceGrotesk'),
        home: LeagueRewardsHost(
          rewards: LeagueRewardsRepo(gw),
          auth: AuthService.fake(user: fakeUser()),
          child: const Scaffold(body: Center(child: Text('EKRAN'))),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(RewardBanner), findsOneWidget);
      expect(find.text('Yeni rütben: Meraklı!'), findsOneWidget);
    });

    testWidgets('misafirde (user yok) hiç sorgulanmaz', (tester) async {
      final gw = FakeRewardsGateway(rows: [rewardRow('rank_up', 50)]);
      await pumpHost(tester, gw: gw, auth: AuthService.fake());
      expect(gw.unseenCalls, 0);
      expect(find.byType(RewardBanner), findsNothing);
    });

    testWidgets('düşüş banner\'ı: konfetisiz, geri dönüş çubuğu + rozetler',
        (tester) async {
      final gw = FakeRewardsGateway(rows: [rewardRow('rank_down', 100)]);
      await pumpHost(
        tester,
        gw: gw,
        stats: StatsRepo(
            FakeStatsGatewayForRank(const {'rank': 4, 'total_score': 88})),
      );

      expect(find.text('Rütben geriledi'), findsOneWidget);
      expect(find.text('Kazandıkça geri yükselirsin!'), findsOneWidget);
      // Sayıya iyelik eki YOK — "100 eşiğinin altına" kalıbı.
      final para = tester.widget<Text>(find.byWidgetPredicate((w) =>
          w is Text &&
          (w.textSpan?.toPlainText() ?? '').startsWith('Üzgünüz')));
      expect(para.textSpan!.toPlainText(),
          'Üzgünüz — puanın 100 eşiğinin altına indi. Yeni rütben: Meraklı');
      // Geri dönüş çubuğunun etiketleri: alt eşik 50, güncel 88, hedef 100.
      expect(find.text('50'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('100 puan'), findsOneWidget);
      // İki ödül de ALINMIŞ → yeşil + ✓ (geri düşmek ödülü götürmez).
      final badges = tester.widgetList<RewardBadge>(find.byType(RewardBadge));
      expect([for (final b in badges) (b.reward, b.claimed)],
          [(5, true), (10, true)]);
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('güncel puan çekilemezse çubuk gizlenir, banner yine çıkar',
        (tester) async {
      final gw = FakeRewardsGateway(rows: [rewardRow('rank_down', 100)]);
      await pumpHost(tester,
          gw: gw, stats: StatsRepo(FakeStatsGatewayForRank(null)));
      expect(find.text('Rütben geriledi'), findsOneWidget);
      expect(find.text('100 puan'), findsNothing);
    });
  });

  group('RankInfoModal — ilerleme çubuğu ve rozet renk kuralı', () {
    Future<void> pumpInfo(WidgetTester tester,
        {required int total, required int bonus}) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'SpaceGrotesk'),
        home: Scaffold(
          body: RankInfoModal(
              tier: tierFor(total), totalScore: total, bonusPoints: bonus),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('alınmış ödül yeşil+✓, alınmamış hedef GRİ (✓ yok)',
        (tester) async {
      // 83 puan, Meraklı; 50'nin ödülü alınmış (bonus 5), 100'ünki değil.
      await pumpInfo(tester, total: 83, bonus: 5);
      expect(find.text('Meraklı'), findsOneWidget);
      expect(find.text('83 k-lig puanı'), findsOneWidget);
      expect(find.text('+5 eşik ödülü dahil'), findsOneWidget);
      expect(find.text('Sıradaki rütbe: Oyuncu · 100 puan'), findsOneWidget);

      final badges = tester.widgetList<RewardBadge>(find.byType(RewardBadge));
      expect([for (final b in badges) (b.reward, b.claimed)],
          [(5, true), (10, false)]);
      // Alınmış YEŞİL, alınmamış hedef GRİ.
      Text label(String t) => tester.widget<Text>(find.text(t));
      expect(label('(+5)').style!.color, kGreen);
      expect(label('(+10)').style!.color, kMuted);
      // Onay işareti YALNIZCA alınmış ödülde. (Space Mono '✓' glyph'ini
      // İÇERMİYOR — düz karakter tofu çiziyordu, ekran görüntüsünde
      // yakalandı; Material `Icons.check` her platformda garanti.)
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('en üst kademede çubuk yok', (tester) async {
      await pumpInfo(tester, total: 1200, bonus: 190);
      expect(find.text('Destan'), findsOneWidget);
      expect(find.text('En yüksek rütbedesin!'), findsOneWidget);
      expect(find.text('1200'), findsNothing, reason: 'çubuk etiketi olmamalı');
    });

    testWidgets('bonus 0 iken "eşik ödülü dahil" satırı çizilmez',
        (tester) async {
      await pumpInfo(tester, total: 12, bonus: 0);
      expect(find.textContaining('eşik ödülü dahil'), findsNothing);
      expect(find.text('Çaylak'), findsOneWidget);
    });
  });

  // Görsel doğrulama — bu üç ekran görüntüsü `build/screenshots/` altına
  // yazılır (commit edilmez); animasyonun SON karesi yakalanır. Cihazdaki
  // son onay yine kullanıcıdan (mobile/TESTING.md bölüm 12).
  group('ekran görüntüleri', () {
    Future<void> shot(WidgetTester tester, GlobalKey key, String name) =>
        tester.runAsync(() async {
          final b =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await b.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = File('build/screenshots/$name.png');
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(bytes!.buffer.asUint8List());
        });

    testWidgets('kutlama / düşüş banner\'ı ve rütbe bilgi popup\'ı',
        (tester) async {
      Future<void> pumpShot(Widget w, String name) async {
        await setPhoneViewSize(tester, const Size(420, 900));
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              fontFamily: 'SpaceGrotesk',
              scaffoldBackgroundColor: Colors.white),
          home: RepaintBoundary(key: key, child: w),
        ));
        await tester.pumpAndSettle();
        await shot(tester, key, name);
      }

      await pumpShot(
        LeagueRewardsHost(
          rewards: LeagueRewardsRepo(FakeRewardsGateway(rows: [
            rewardRow('rank_up', 100),
            rewardRow('points_reward', 100, points: 10),
          ])),
          auth: AuthService.fake(user: fakeUser()),
          child: const Scaffold(body: Center(child: Text('EKRAN'))),
        ),
        'reward_banner',
      );
      debugResetLeagueRewardHosts();

      await pumpShot(
        LeagueRewardsHost(
          rewards: LeagueRewardsRepo(
              FakeRewardsGateway(rows: [rewardRow('rank_down', 100)])),
          auth: AuthService.fake(user: fakeUser()),
          stats: StatsRepo(
              FakeStatsGatewayForRank(const {'rank': 4, 'total_score': 88})),
          child: const Scaffold(body: Center(child: Text('EKRAN'))),
        ),
        'reward_banner_rank_down',
      );
      debugResetLeagueRewardHosts();

      await pumpShot(
        const Scaffold(
          body: RankInfoModal(
              tier: RankTier(
                  name: 'Meraklı',
                  letter: 'M',
                  color: kAccent,
                  threshold: 50,
                  reward: 5),
              totalScore: 83,
              bonusPoints: 5),
        ),
        'rank_info_modal',
      );
    });
  });

  group('RankSeal', () {
    test('kompakt eşiği ve punto merdiveni (web RankSeal kuralları)', () {
      // 24 sınırı: k-lig satırı (18) kompakt, başlık (34) ve banner (76)
      // tam detaylı.
      expect(sealIsCompact(18), isTrue);
      expect(sealIsCompact(23.9), isTrue);
      expect(sealIsCompact(24), isFalse);
      expect(sealIsCompact(34), isFalse);
      expect(sealIsCompact(76), isFalse);
      // Tek harf kompaktta BÜYÜR (okunurluk düzeltmesi).
      expect(sealFontSize('Ç', compact: true), 27);
      expect(sealFontSize('Ç', compact: false), 19);
      // Banner glyph'leri: "50"/"+5" orta, "+100" küçük.
      expect(sealFontSize('50', compact: false), 14);
      expect(sealFontSize('+5', compact: false), 14);
      expect(sealFontSize('+100', compact: false), 11);
    });

    testWidgets('kompakt (<24px) ve tam boy çizim ayrımı', (tester) async {
      await setPhoneViewSize(tester, const Size(200, 200));
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RankSeal(
                    tier: RankTier(
                        name: 'Oyuncu',
                        letter: 'O',
                        color: kGreen,
                        threshold: 100,
                        reward: 10),
                    size: 18),
                RankSeal(
                    tier: RankTier(
                        name: 'Oyuncu',
                        letter: 'O',
                        color: kGreen,
                        threshold: 100,
                        reward: 10),
                    size: 34),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final seals = tester.widgetList<CustomPaint>(find.descendant(
          of: find.byType(RankSeal), matching: find.byType(CustomPaint)));
      expect(seals, hasLength(2));
      // Boyutlar RankSeal'ın verdiği size'a eşit (viewBox ölçeklemesi).
      expect(
          seals.map((p) => p.size), [const Size(18, 18), const Size(34, 34)]);
    });
  });
}
