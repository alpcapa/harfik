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
import 'package:kelimeki/src/ui/game/neo_button.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/auth/auth_modal.dart';
import 'package:kelimeki/src/ui/game/count_badge.dart';
import 'package:kelimeki/src/ui/auth/account_button.dart';
import 'package:kelimeki/src/ui/game/logo_mark.dart';
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

  testWidgets(
      'regresyon (Parça 29): içerik sütunu web\'in max-w-[460px]\'iyle AYNI '
      'genişlikte sınırlı — GameHeader/Board\'un 680\'iyle KARIŞTIRILMAMALI',
      (tester) async {
    // Geniş bir viewport (iPad yatay benzeri) — dar bir ekranda maxWidth'in
    // hiç devreye girmediğini (içerik zaten daha dar olduğunu) fark etmeyiz.
    await setPhoneViewSize(tester, const Size(1024, 900));
    await pumpSetup(tester, services());

    final constrainedBoxes = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .where((c) => c.constraints.maxWidth == 460);
    expect(constrainedBoxes, isNotEmpty,
        reason: 'Setup içeriği 460px\'e kısıtlanmış bir ConstrainedBox '
            'içermeli (web Setup.tsx max-w-[460px])');
    expect(
        tester
            .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
            .where((c) => c.constraints.maxWidth == 480),
        isEmpty,
        reason: 'Eski (yanlış) 480px sabiti hâlâ kullanılıyor');

    // ⚠ Yukarıdaki iki iddia YETMEZ — 13 Ağustos 2026'da kullanıcı aynı
    // şikâyeti ("app web'den geniş duruyor") ikinci kez bildirdiğinde bu
    // test YEŞİLDİ. Sebep: `max-w-[460px] px-4` Tailwind'de border-box,
    // yani 460 dolguyu İÇERİR ve içerik 428'dir; port ise yatay dolguyu
    // ConstrainedBox'ın DIŞINA koyduğundan içerik 460 kalıyordu (%7.5
    // geniş). Ölçülen değer artık burada: tam genişlik bir buton (Column
    // `stretch`) tam olarak 428 olmalı.
    final baslat = tester.getSize(find.widgetWithText(NeoButton, 'OYUNU BAŞLAT'));
    expect(baslat.width, 428,
        reason: 'içerik genişliği web ile aynı olmalı: 460 − 2×16 (px-4)');
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
    expect(find.text('Arkadaşlarınla çoklu canlı oyun oynama'), findsOneWidget);
    expect(find.text('Arkadaş ekleyip listende tutma'), findsOneWidget);
    // Kutu, üstündeki OYUNU BAŞLAT butonuna yapışık durmamalı — web'in dıştaki
    // flex kapsayıcısının (`gap-5`) verdiği 20px boşluğu karşılayan SizedBox
    // eskiden bu tek geçişte eksikti (kullanıcı web derlemesinde bizzat buldu).
    final buttonBottom = tester.getBottomLeft(find.text('OYUNU BAŞLAT')).dy;
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
    expect(
        find.text('Canlı oyun oynamak için giriş yapmalısın.'), findsOneWidget);
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

  testWidgets('GİRİŞ satırının üstü/altı web ile aynı (12/4)', (tester) async {
    // 13 Ağustos 2026, kullanıcı yan yana karşılaştırmayla bildirdi: "sağ
    // üstteki giriş butonunun üstündeki boşluk app'de daha fazla, biraz
    // aşağıda duruyor."
    //
    // Web'de bu satır Setup içeriğinden AYRI bir kutu (`App.tsx`):
    //   <div … px-3.5 pt-3>   <UserMenu/>        → ÜSTTE 12
    //   <main><div … px-4 py-6>                  → 24
    //     <div … -mt-5>  <LogoMark/>             → −20  ⇒ ARADA 4
    // Yani `py-6`nın 24'ü logo bloğunun NEGATİF margin'iyle eriyor — o
    // margin gözden kaçarsa hesap 24 çıkar. Derlenmiş CSS + Chromium'da
    // iki viewport'ta (1000/420) ölçüldü: 12.0 ve 4.0.
    //
    // Port ise tek sütun kullandığından üstte 24 (kaydırma dolgusu)
    // veriyordu; ARADAKİ 4'ü baştan doğruydu ve 13 Ağustos 2026'da
    // kullanıcı onu tercih edince web `-mt-3`ten `-mt-5`e çekildi.
    await setPhoneViewSize(tester, const Size(1000, 800));
    final gw = FakeOnlineGamesGateway();
    await pumpSetup(tester,
        liveBadgeServices(AuthService.fake(), OnlineGamesRepo(gw)));

    final ekran = tester.getRect(find.byType(SetupScreen));
    final giris = tester.getRect(find.byType(AccountButton));
    final logo = tester.getRect(find.byType(LogoMark).first);

    expect(giris.top - ekran.top, 12, reason: 'GİRİŞ üstü web pt-3 = 12');
    expect(logo.top - giris.bottom, 4,
        reason: 'GİRİŞ ile logo arası web py-6 (24) + -mt-5 (−20) = 4');
  });

  testWidgets(
      'ARKADAŞINLA rozeti: bekleyen davet + sırası bende olan oyun toplamı, '
      'girişte otomatik sekme açılışı', (tester) async {
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
        tester,
        liveBadgeServices(
            AuthService.fake(user: fakeUser('me')), OnlineGamesRepo(gw)));

    expect(tester.widget<CountBadge>(find.byType(CountBadge)).count, 1);
    // Bekleyen iş varken girişte "Arkadaşınla" kendiliğinden açılmalı (web
    // `appliedLoginDefaultRef`).
    expect(find.byType(LiveGamesTab), findsOneWidget);
  });

  testWidgets(
      'ARKADAŞINLA rozeti: bekleyen iş YOKKEN rozet çıkmaz ve sekme otomatik '
      'açılmaz (negatif eşi — kök CLAUDE.md dersi)', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final gw = FakeOnlineGamesGateway();
    await pumpSetup(
        tester,
        liveBadgeServices(
            AuthService.fake(user: fakeUser('me')), OnlineGamesRepo(gw)));

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

  testWidgets(
      'tanıtım paragrafı ve "Nasıl oynanır? · Arkadaşınla paylaş" '
      'satırı ORTALI (web text-center paritesi)', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: SetupScreen(services: services()),
    ));
    await tester.pumpAndSettle();

    final para = find.textContaining('Kelimeler kurarak');
    expect(tester.widget<Text>(para).textAlign, TextAlign.center);

    // Paragraf içerik genişliğinin tamamını kapladığından merkezi = içerik
    // merkezi; link satırı (mainAxisSize.min bir Row) onunla AYNI x'te
    // olmalı — sola yaslıyken bu fark ~90px'e çıkıyordu.
    final links = find
        .ancestor(of: find.text('Nasıl oynanır?'), matching: find.byType(Row))
        .first;
    expect(
      tester.getCenter(links).dx,
      moreOrLessEquals(tester.getCenter(para).dx, epsilon: 1),
    );
  });

  testWidgets(
      'sekme butonları web ile AYNI punto/satır/kutu — ölçülerek eşlendi '
      '(Parça 37: OYUN TİPİ+OYUNCU SAYISI 14px/46px, alt sekmeler 11px/38.5px)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: SetupScreen(services: services()),
    ));
    await tester.pumpAndSettle();

    // Beklenen değerler web'in DERLENMİŞ CSS'i (dist/assets/index-*.css)
    // Chromium'da render edilip `getComputedStyle`/`getBoundingClientRect`
    // ile okunarak alındı — Tailwind sınıflarından zihnen türetilmedi
    // (Parça 33'ün dersi).
    final tipi = tester.widget<Text>(find.text('YAPAY ZEKA İLE'));
    expect(tipi.style!.fontSize, 14);
    expect(tipi.style!.height, moreOrLessEquals(20 / 14, epsilon: 0.001));

    final sayi = tester.widget<Text>(find.text('2 OYUNCULU'));
    expect(sayi.style!.fontSize, 14);

    // Kutu yüksekliği: 12+12 dolgu + 20 satır = 44. Web'de 46 ölçülüyor;
    // aradaki 2px, web'in `border`ının yer kaplaması. Flutter'da çerçeve
    // `foregroundDecoration`da (Parça 4'ün bilinçli kararı — aktif/pasif
    // kalınlık farkı düzeni kaydırmasın diye) ve yer KAPLAMIYOR. Telafi için
    // sahte bir dolgu eklenmedi: bu, çerçeve bir gün decoration'a taşınırsa
    // sessizce iki kez sayılacak bir sihirli sayı olurdu. 2px fark bilinçli.
    expect(
      tester.getSize(find.byType(NeoButton).first).height,
      moreOrLessEquals(44, epsilon: 0.5),
    );
  });

  // Parça 56 — web ile ÖLÇÜLEREK hizalanan Setup metrikleri. Değerlerin
  // hepsi kelimeki.com'un DERLENMİŞ CSS'i Chromium'da render edilerek
  // alındı (Tailwind sınıflarından zihnen türetilmedi — Parça 33 dersi).
  testWidgets('Setup başlık bloğu ve hukuki alt satır web ile aynı',
      (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await pumpSetup(tester, services());

    // Web ölçümü: logo alt → paragraf üst 20px, paragraf alt → link üst
    // 16px (blok `gap-1` + paragrafın `mt-4`/linklerin `mt-3`ü ÜST ÜSTE
    // biniyor — port ikisinde de yalnızca margin'i taşımıştı).
    final logo = tester.getRect(find.byType(LogoMark).first);
    final para = tester.getRect(find.textContaining('Kelimeler kurarak'));
    final link = tester.getRect(find.text('Nasıl oynanır?'));
    expect(para.top - logo.bottom, closeTo(20, 1.5));
    expect(link.top - para.bottom, closeTo(16, 1.5));

    // Web `text-xs` = 12px/16px satır → 4 satırlık paragraf 64px.
    final paraText = tester.widget<Text>(find.textContaining('Kelimeler kurarak'));
    expect(paraText.style!.fontSize, 12);
    expect(paraText.style!.height! * 12, closeTo(16, 0.01));

    // Web Setup'ın en altındaki hukuki linkler — port hiç taşımamıştı.
    await tester.scrollUntilVisible(find.text('Kullanım Koşulları'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Kullanım Koşulları'), findsOneWidget);
    expect(find.text('Gizlilik Politikası'), findsOneWidget);
  });
}
