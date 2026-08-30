// Faz 3 — bildirimdeki/dışarıdan gelen oyun linkinin YÖNLENDİRİLMESİ
// (`_HomeGate._oyunLinkiniIsle`).
//
// Üç dal, üçü de ürün kararı:
//   1. Oyun AKTİF → Canlı tahta doğrudan açılır ("SIRA SENDE" bildirimine
//      dokunan kişi tahtada biter — Faz 3'ün asıl vaadi).
//   2. Oyun beklemede (davet) ya da listede yok → Arkadaşınla sekmesi
//      (davetse LiveGamesTab kendi kuralıyla "Oyun Davetleri"ni açar).
//   3. Girişsizken link BEKLETİLİR (take edilmez); giriş gelince işlenir.
//
// FCM'in kendisi burada YOK: FirebasePushTapSource cihaz ister; bu testler
// aynı `handleUri` kapısını doğrudan besliyor (deep_link_test'in birim
// testleri Uri → id çevirisini ayrıca kilitliyor). Cihaz doğrulaması:
// mobile/docs/testing-bildirimler.md §3b.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/game_link_inbox.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki/src/ui/live/live_games_tab.dart';
import 'package:kelimeki/src/ui/live/online_game_screen.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show SetWordSource;

import 'push_lifecycle_test.dart' show TestAuth;
import 'support/fake_online_gateway.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

void main() {
  setUpAll(loadAppFonts);

  AppServices services({
    required FakeOnlineGamesGateway gw,
    required GameLinkInbox inbox,
    required TestAuth auth,
  }) =>
      AppServices(
        onlineStatus: OnlineStatus.fake(),
        dictionary: Future.value(SetWordSource(const ['ab'])),
        meanings: MeaningStore(bundle: rootBundle),
        auth: auth,
        supabase: null,
        versionGate: VersionGateStatus.ok,
        onlineGames: OnlineGamesRepo(gw),
        gameLinks: inbox,
      );

  Future<void> pumpApp(WidgetTester tester, AppServices s) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(KelimekiApp(services: s));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('aktif oyun linki Canlı tahtayı DOĞRUDAN açar', (tester) async {
    final gw = FakeOnlineGamesGateway()
      ..rows = [gameRow(id: 'g1', myId: 'u1', status: 'active')];
    final inbox = GameLinkInbox();
    final s = services(
        gw: gw, inbox: inbox, auth: TestAuth(user: fakeUser('u1')));
    await pumpApp(tester, s);
    expect(find.byType(OnlineGameScreen), findsNothing);

    inbox.handleUri(Uri.parse('kelimeki://oyun/g1'));
    await tester.pump(); // load() (sahte uç, mikrotask)
    await tester.pump(); // popUntil + push
    await tester.pump();
    expect(find.byType(OnlineGameScreen), findsOneWidget);
    // Tüketildi: aynı link bir daha işlenmez.
    expect(inbox.pendingGameId, isNull);
    await tester.pumpWidget(const SizedBox.shrink()); // ekran timer'ları
  });

  testWidgets('bekleyen davet linki tahta DEĞİL Arkadaşınla sekmesini açar',
      (tester) async {
    final gw = FakeOnlineGamesGateway()
      ..rows = [
        gameRow(
            id: 'g2',
            myId: 'u1',
            status: 'pending',
            myInviteStatus: 'pending',
            myInviteId: 'i1'),
      ];
    final inbox = GameLinkInbox();
    final s = services(
        gw: gw, inbox: inbox, auth: TestAuth(user: fakeUser('u1')));
    await pumpApp(tester, s);
    // Bekleyen davet varken Setup ZATEN otomatik Arkadaşınla'ya geçer
    // (hesap başına bir kez — kendi kuralı, kendi testi var). Dinleyicinin
    // GERÇEK işini ayırt etmek için kullanıcıyı elle YZ sekmesine döndür:
    // link, sekmeyi GERİ getirmeli.
    await tester.pump();
    if (tester.any(find.byType(LiveGamesTab))) {
      await tester.tap(find.text('YAPAY ZEKA İLE'));
      await tester.pump();
    }
    expect(find.byType(LiveGamesTab), findsNothing);

    inbox.handleUri(Uri.parse('kelimeki://oyun/g2'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(OnlineGameScreen), findsNothing);
    expect(find.byType(LiveGamesTab), findsOneWidget);
    expect(s.liveTabRequests.value, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('girişsizken BEKLETİLİR, giriş gelince işlenir', (tester) async {
    final gw = FakeOnlineGamesGateway()
      ..rows = [gameRow(id: 'g3', myId: 'u1', status: 'active')];
    final inbox = GameLinkInbox();
    final auth = TestAuth(user: null);
    final s = services(gw: gw, inbox: inbox, auth: auth);
    await pumpApp(tester, s);

    inbox.handleUri(Uri.parse('kelimeki://oyun/g3'));
    await tester.pump();
    await tester.pump();
    // Girişsiz: ne tahta ne sekme — link take EDİLMEDEN bekliyor.
    expect(find.byType(OnlineGameScreen), findsNothing);
    expect(inbox.pendingGameId, 'g3');

    auth.setUser(fakeUser('u1'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(OnlineGameScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
