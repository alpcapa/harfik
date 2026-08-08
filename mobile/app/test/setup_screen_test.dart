// Setup ekranı testleri — web Setup.tsx misafir akışının paritesi: oyuncu
// sayısı seçimi, Misafir+YZ kadrosuyla oyun başlatma, Arkadaşınla sekmesinin
// misafir görünümü (LiveGamesTab giriş çağrısı), tekil kayıt varken
// anti-kaçış (form yok, Devam Eden Oyun satırı) ve kayıttan devam.
// Gerçek SQLite (ffi) + gerçek sözlük.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/game/local_game_repo.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/auth/auth_modal.dart';
import 'package:kelimeki/src/ui/game/count_badge.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/live/live_games_tab.dart';
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_online_gateway.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

late SetWordSource words;

Future<AppStorage> openTestStorage() async {
  SharedPreferences.setMockInitialValues({});
  return AppStorage.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    prefs: await SharedPreferences.getInstance(),
  );
}

AppServices services({Future<AppStorage>? storage}) => AppServices(
      dictionary: Future.value(words),
      meanings: MeaningStore(bundle: rootBundle),
      auth: AuthService(null),
      supabase: null,
      versionGate: VersionGateStatus.ok,
      storage: storage,
    );

/// "Arkadaşınla (N)" rozeti/girişte otomatik sekme testleri için — girişli,
/// depolamasız (bu davranış `local_game_saves`e hiç dokunmuyor).
AppServices liveBadgeServices(AuthService auth, OnlineGamesRepo onlineGames) =>
    AppServices(
      dictionary: Future.value(words),
      meanings: MeaningStore(bundle: rootBundle),
      auth: auth,
      supabase: null,
      versionGate: VersionGateStatus.ok,
      onlineGames: onlineGames,
    );

Future<void> pumpSetup(WidgetTester tester, AppServices s) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
        fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
    home: SetupScreen(services: s),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    await loadRobotoIfAvailable();
    final f = File('assets/dictionary/words_tr.txt');
    words = SetWordSource(const LineSplitter()
        .convert(f.readAsStringSync())
        .where((w) => w.isNotEmpty));
  });

  testWidgets('form: 2/4 seçimi kadroyu değiştirir, ekran görüntüsü',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: Colors.white,
          child: SetupScreen(services: services()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Varsayılan 2 oyunculu: Misafir + Yapay Zeka 2.
    expect(find.text('Misafir'), findsOneWidget);
    expect(find.text('Yapay Zeka 2'), findsOneWidget);
    expect(find.text('Yapay Zeka 4'), findsNothing);

    await tester.tap(find.text('4 OYUNCULU'));
    await tester.pump();
    expect(find.text('Yapay Zeka 3'), findsOneWidget);
    expect(find.text('Yapay Zeka 4'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/setup_form.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  testWidgets('OYUNU BAŞLAT: Misafir + YZ kadrosuyla GameScreen açılır',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(tester, services());

    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    final players = screen.controller.state.players;
    expect(players, hasLength(2));
    expect(players[0].name, guestPlayerName);
    expect(players[0].isAI, isFalse);
    expect(players[1].name, 'Yapay Zeka 2');
    expect(players[1].isAI, isTrue);
  });

  testWidgets(
      'misafirde "Neden Ücretsiz Üye Olmalıyım?" kutusu: 6 madde + giriş açar',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(tester, services());

    expect(find.text('Neden Ücretsiz Üye Olmalıyım?'), findsOneWidget);
    // web MEMBERSHIP_PERKS ile birebir aynı sıra — ilk ve son madde yeterli
    // kanıt (aradakiler aynı listeden geliyor, tek tek tekrar etmeye gerek yok).
    expect(
        find.text('Arkadaşlarınla çoklu canlı oyun oynama'), findsOneWidget);
    expect(find.text('Arkadaş ekleyip listende tutma'), findsOneWidget);
    // Kutu, üstündeki OYUNU BAŞLAT butonuna yapışık durmamalı — web'in dıştaki
    // flex kapsayıcısının (`gap-5`) verdiği 20px boşluğu karşılayan SizedBox
    // eskiden bu tek geçişte eksikti (kullanıcı web derlemesinde bizzat buldu).
    final buttonBottom =
        tester.getBottomLeft(find.text('OYUNU BAŞLAT')).dy;
    final boxTop =
        tester.getTopLeft(find.text('Neden Ücretsiz Üye Olmalıyım?')).dy;
    expect(boxTop - buttonBottom, greaterThan(15));

    await tester.tap(find.text('GİRİŞ YAP / KAYIT OL'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthModal), findsOneWidget);
  });

  testWidgets('ARKADAŞINLA sekmesi misafire giriş çağrısı gösterir, geri döner',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(tester, services());

    await tester.tap(find.text('ARKADAŞINLA'));
    await tester.pumpAndSettle();
    // Girişsiz + Supabase yapılandırılmamış: LiveGamesTab'ın misafir görünümü;
    // GİRİŞ YAP butonu yalnızca auth.configured iken çizilir (burada değil).
    expect(find.text('Canlı oyun oynamak için giriş yapmalısın.'),
        findsOneWidget);
    expect(find.text('OYUNU BAŞLAT'), findsNothing);

    await tester.tap(find.text('YAPAY ZEKA İLE'));
    await tester.pumpAndSettle();
    expect(find.text('OYUNU BAŞLAT'), findsOneWidget);
  });

  testWidgets(
      'kayıt varken anti-kaçış: form yok, Devam Eden Oyun satırı + devam',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    // SQLite (ffi) I/O'su GERÇEK async — testWidgets'ın fake-async bölgesi
    // bunları asla çözmez (ilk sürüm 10 dakika asılı kaldı); depolamaya
    // dokunan her adım runAsync köprüsünden geçmek zorunda.
    late AppStorage storage;
    late int savedTurn;
    await tester.runAsync(() async {
      // Önce gerçek bir yarım oyun kaydet (turnCount>=2, sıra misafirde).
      storage = await openTestStorage();
      final repo = LocalGameRepo(storage);
      final c =
          GameController(words: words, autoPlayAi: false, nowIso: () => '');
      final session = repo.attach(c);
      c.dispatch(StartAction(const [
        PlayerSetup(name: guestPlayerName, isAI: false),
        PlayerSetup(name: 'Yapay Zeka 2', isAI: true),
      ]));
      c.dispatch(const PassAction());
      c.dispatch(const AiPlayAction());
      expect(c.state.turnCount, greaterThanOrEqualTo(2));
      savedTurn = c.state.turnCount;
      await session.end();
    });

    await pumpSetup(tester, services(storage: Future.value(storage)));
    // initState'in depolama zinciri (loadSave/drain) gerçek async — çözülene
    // kadar runAsync ile bekleyip yeniden çiz.
    for (var i = 0;
        i < 50 && tester.any(find.text('KAYITLAR KONTROL EDİLİYOR…'));
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('DEVAM EDEN OYUN'), findsOneWidget);
    expect(find.text('SENİN HAMLEN BEKLENİYOR'), findsOneWidget);
    expect(find.textContaining('SONRA SİLİNECEK'), findsOneWidget);
    // Anti-kaçış: yeni oyun formu hiç yok.
    expect(find.text('OYUNU BAŞLAT'), findsNothing);
    expect(find.text('OYUNCU SAYISI'), findsNothing);
    // Web: bu görünümde de (form yerine) kutu çıkıyor — className="mt-2" ile.
    expect(find.text('Neden Ücretsiz Üye Olmalıyım?'), findsOneWidget);

    // Devam: satıra dokun → GameScreen aynı turdan açılır. Dokunuş
    // loadSave (gerçek I/O) tetiklediğinden yine runAsync köprüsü gerekir.
    await tester.tap(find.text('SENİN HAMLEN BEKLENİYOR'));
    for (var i = 0; i < 50 && !tester.any(find.byType(GameScreen)); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.controller.state.turnCount, savedTurn);
    expect(screen.controller.state.multiSession, isTrue);
    await tester.runAsync(() => storage.close());
  });

  testWidgets(
      'ARKADAŞINLA rozeti: bekleyen davet + sırası bende olan oyun toplamı, '
      'girişte otomatik sekme açılışı',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final gw = FakeOnlineGamesGateway()
      ..rows = [
        gameRow(
            id: 'inv',
            myId: 'me',
            status: 'pending',
            myRole: 'invitee',
            myInviteStatus: 'pending',
            myInviteId: 'i1'),
      ];
    await pumpSetup(
        tester, liveBadgeServices(AuthService.fake(user: fakeUser('me')), OnlineGamesRepo(gw)));

    expect(tester.widget<CountBadge>(find.byType(CountBadge)).count, 1);
    // Bekleyen iş varken girişte "Arkadaşınla" kendiliğinden açılmalı (web
    // `appliedLoginDefaultRef`).
    expect(find.byType(LiveGamesTab), findsOneWidget);
  });

  testWidgets(
      'ARKADAŞINLA rozeti: bekleyen iş YOKKEN rozet çıkmaz ve sekme otomatik '
      'açılmaz (negatif eşi — kök CLAUDE.md dersi)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final gw = FakeOnlineGamesGateway();
    await pumpSetup(
        tester, liveBadgeServices(AuthService.fake(user: fakeUser('me')), OnlineGamesRepo(gw)));

    expect(find.byType(CountBadge), findsNothing);
    expect(find.byType(LiveGamesTab), findsNothing);
    expect(find.text('OYUNU BAŞLAT'), findsOneWidget);
  });

  testWidgets(
      'hesap değişiminde (çıkış) Arkadaşınla seçimi sıfırlanır; ikinci hesap '
      'kendi bekleyen işi için ayrıca otomatik geçer (web 5 Ağustos dersi)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final gw = FakeOnlineGamesGateway()
      ..rows = [
        gameRow(
            id: 'inv',
            myId: 'a',
            status: 'pending',
            myRole: 'invitee',
            myInviteStatus: 'pending',
            myInviteId: 'i1'),
      ];
    final auth = AuthService.fake(user: fakeUser('a'));
    await pumpSetup(tester, liveBadgeServices(auth, OnlineGamesRepo(gw)));
    expect(find.byType(LiveGamesTab), findsOneWidget);

    // Çıkış: `_liveView` bomboş kalmasın diye sıfırlanmalı.
    auth.debugSetUser(null);
    await tester.pumpAndSettle();
    expect(find.byType(LiveGamesTab), findsNothing);
    expect(find.text('OYUNU BAŞLAT'), findsOneWidget);

    // İkinci hesap (b) kendi bekleyen işiyle girer — `appliedLoginDefault`
    // hesap başına sıfırlanmadıysa bu hesap hiç Canlı'ya geçirilmezdi.
    gw.rows = [
      gameRow(
          id: 'inv2',
          myId: 'b',
          status: 'pending',
          myRole: 'invitee',
          myInviteStatus: 'pending',
          myInviteId: 'i2'),
    ];
    auth.debugSetUser(fakeUser('b'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveGamesTab), findsOneWidget);
  });

  testWidgets('"Arkadaşınla paylaş" ?ref=arkadas linkini paylaşır',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    String? sharedText;
    String? sharedUrl;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: SetupScreen(
        services: services(),
        share: ({required png, required text, required url}) async {
          sharedText = text;
          sharedUrl = url;
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arkadaşınla paylaş'));
    await tester.pump();

    expect(sharedText, 'Hemen ücretsiz dene!');
    expect(sharedUrl, 'https://kelimeki.com/?ref=arkadas');
  });
}
