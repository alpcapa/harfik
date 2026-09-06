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
import 'package:kelimeki/src/config/env.dart';
import 'package:kelimeki/src/ui/route_observer.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/game/local_game_repo.dart';
import 'package:kelimeki/src/ui/game/neo_button.dart';
import 'package:kelimeki/src/ui/game/dialog_shell.dart';
import 'package:kelimeki/src/ui/game/modal_shell.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/auth/auth_modal.dart';
import 'package:kelimeki/src/ui/game/count_badge.dart';
import 'package:kelimeki/src/ui/auth/account_button.dart';
import 'package:kelimeki/src/ui/game/logo_mark.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/intro/intro_screen.dart';
import 'package:kelimeki/src/ui/live/live_games_tab.dart';
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki/src/ui/devam_eden_govde.dart';
import 'package:kelimeki/src/ui/game/player_avatar_row.dart';
import 'package:kelimeki/src/ui/text_scale.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_online_gateway.dart';
import 'support/test_fonts.dart';
import 'package:kelimeki/src/data/analytics.dart';
import 'support/fake_analytics.dart';
import 'support/test_view.dart';
import 'package:kelimeki/src/util/online_status.dart';

late SetWordSource words;

Future<AppStorage> openTestStorage() async {
  SharedPreferences.setMockInitialValues({});
  return AppStorage.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    prefs: await SharedPreferences.getInstance(),
  );
}

AppServices services({Future<AppStorage>? storage, AuthService? auth}) =>
    AppServices(
      onlineStatus: OnlineStatus.fake(),
      dictionary: Future.value(words),
      meanings: MeaningStore(bundle: rootBundle),
      auth: auth ?? AuthService(null),
      supabase: null,
      versionGate: VersionGateStatus.ok,
      storage: storage,
    );

/// "Arkadaşınla (N)" rozeti/girişte otomatik sekme testleri için — girişli,
/// depolamasız (bu davranış `local_game_saves`e hiç dokunmuyor).
AppServices liveBadgeServices(AuthService auth, OnlineGamesRepo onlineGames,
        {OnlineStatus? onlineStatus, FriendsRepo? friends}) =>
    AppServices(
      onlineStatus: onlineStatus ?? OnlineStatus.fake(),
      dictionary: Future.value(words),
      meanings: MeaningStore(bundle: rootBundle),
      auth: auth,
      supabase: null,
      versionGate: VersionGateStatus.ok,
      onlineGames: onlineGames,
      // `LiveGamesTab` listeyi ancak `friends` varken çiziyor; rozet
      // testlerinin çoğu listeye bakmadığından bu alan isteğe bağlı.
      friends: friends,
    );


/// "ARKADAŞINLA" sekmesinin KENDİ rozeti. `find.byType(CountBadge)` tek
/// başına yetmiyor: sekme açıldığında `LiveGamesTab`in alt sekmeleri de
/// rozet taşıyabiliyor, yani genel arama yanlış rozeti bulabilir.
/// ⚠ `.first` KULLANMA: rozet yokken zincirin ucu boşalıyor ve `findsNothing`
/// eşleştiricisi mismatch'i tarif ederken patlıyor ("No results have been
/// found yet") — hata mesajı testin GERÇEK sonucunu gizliyor.
Finder arkadaslaRozeti() => find.descendant(
      of: find.ancestor(
          of: find.text('ARKADAŞINLA'), matching: find.byType(Stack)),
      matching: find.byType(CountBadge),
    );

Future<void> pumpSetup(WidgetTester tester, AppServices s) async {
  await tester.pumpWidget(MaterialApp(
    theme: kelimekiTheme(),
    // ÜRETİMLE AYNI olmak ZORUNDA (app.dart `navigatorObservers`): Setup'ın
    // "bir ekrandan dönüldü" tazelemesi `RouteAware.didPopNext`ten geliyor ve
    // o yalnızca rotayı gözleyen observer ile ABONE observer aynı nesneyse
    // çalışır. Harness bunu vermezse `didPopNext` HİÇ koşmaz ve dönüş
    // testi — bir hata olmadığı hâlde — düşer.
    navigatorObservers: [kRouteObserver],
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
      theme: kelimekiTheme(),
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
      'ZORLUK (ROADMAP #23 Faz 4): OYUNCU SAYISI\'nın altında Kolay/Normal, '
      'varsayılan Normal, Zor YOK, seçili seviyenin açıklaması ve puanı',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 950));
    await pumpSetup(tester, services());

    expect(find.text('ZORLUK'), findsOneWidget);
    expect(find.text('KOLAY'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
    // Zor Faz 5'e kadar seçici DIŞINDA (web `SELECTABLE_AI_LEVELS`).
    expect(find.text('ZOR'), findsNothing);
    // Sıra web ile aynı: başlıklar OYUNCU SAYISI → ZORLUK → OYUNCULAR.
    final ySayi = tester.getTopLeft(find.text('OYUNCU SAYISI')).dy;
    final yZorluk = tester.getTopLeft(find.text('ZORLUK')).dy;
    final yOyuncular = tester.getTopLeft(find.text('OYUNCULAR')).dy;
    expect(yZorluk, greaterThan(ySayi));
    expect(yOyuncular, greaterThan(yZorluk));

    // Her seviyenin altında açıklama var; varsayılan Normal, 2 kişilik →
    // yalnızca birincilik puanı. Tam metinler `ai_level_parity_test`te.
    expect(find.textContaining('Orta-iyi seviye'), findsOneWidget);
    expect(find.textContaining('birincilik 2 puan kazandırır.'), findsOneWidget);
    expect(find.textContaining('ikincilik'), findsNothing);
    await tester.tap(find.text('KOLAY'));
    await tester.pump();
    expect(find.textContaining('Çok iyi değilim'), findsOneWidget);
    expect(find.textContaining('birincilik 1 puan kazandırır.'), findsOneWidget);
    expect(find.textContaining('Orta-iyi seviye'), findsNothing);
    // 4 kişilik → ikincilik de yazılır (Kolay'da 0 → "puan kazandırmaz").
    await tester.tap(find.text('4 OYUNCULU'));
    await tester.pump();
    expect(find.textContaining('ikincilik puan kazandırmaz'), findsOneWidget);
    await tester.tap(find.text('NORMAL'));
    await tester.pump();
    expect(find.textContaining('birincilik 2, ikincilik 1 puan kazandırır.'),
        findsOneWidget);
    expect(find.textContaining('Çok iyi değilim'), findsNothing);
  });

  testWidgets(
      'ZORLUK: Kolay seçilip OYUNU BAŞLAT → state.aiLevel = kolay ve JSON\'da '
      'yazılı (bulut kaydı/web okuyacak)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 950));
    await pumpSetup(tester, services(auth: AuthService.fake(user: fakeUser('me'))));

    await tester.tap(find.text('KOLAY'));
    await tester.pump();
    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.controller.state.aiLevel, AiLevel.kolay);
    // JSON'da da yazılı — bulut kaydı/web bunu okuyacak.
    expect(gameStateToJson(screen.controller.state)['aiLevel'], 'kolay');

  });

  // Negatif eş — AYRI test: aynı testte ikinci bir pumpSetup, ilk oyunun
  // "devam eden oyun" kartını gösterip formu gizliyor (OYUNU BAŞLAT yok).
  testWidgets(
      'ZORLUK: Normal (varsayılan) ile başlayan oyunda aiLevel alanı HİÇ '
      'yazılmaz — `normal` değeri de değil', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 950));
    await pumpSetup(tester, services());
    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OYNA')); // misafir uyarısı
    await tester.pumpAndSettle();
    final screen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(screen.controller.state.aiLevel, isNull);
    expect(gameStateToJson(screen.controller.state).containsKey('aiLevel'),
        isFalse);
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
    // Misafir artık önce giriş uyarısından geçiyor (web `handleStart`
    // paritesi, 14 Ağustos 2026) — "OYNA" misafir olarak başlatır
    // (18 Ağustos 2026'ya kadar "DEVAM"dı; web ile birlikte değişti).
    expect(find.textContaining('lütfen giriş yapın'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('DEVAM'), findsNothing);
    await tester.tap(find.text('OYNA'));
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

  // Negatif eş: uyarı KOŞULSUZ gösterilseydi yukarıdaki test de geçerdi.
  // Girişli kullanıcı uyarıyı HİÇ görmemeli (web `!loading && !user`).
  testWidgets('girişli kullanıcıda giriş uyarısı ÇIKMAZ — oyun doğrudan açılır',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(
        tester, services(auth: AuthService.fake(user: fakeUser('me'))));

    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();
    expect(find.textContaining('lütfen giriş yapın'), findsNothing);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  // 17 Ağustos 2026, cihaz testi — kullanıcı: *"çıkan popup başlıksız"*.
  // Web'de bu uyarı ortak `Modal.tsx`'i KULLANMIYOR; `Setup.tsx` içinde elle
  // kurulmuş 384px'lik onay kartı (`max-w-sm`/`rounded-2xl`/`p-6`, ✕ köşede
  // `absolute`). Port `KModal`a `title: ''` geçmişti — niyet doğruydu ama
  // kabuk başlık bandını yine de çizdiğinden üstte boş bir alan + ayraç
  // kalıyordu. Bu test yanlış kabuğa dönüşü yakalar.
  testWidgets('misafir uyarısı KModal DEĞİL web onay kartını kullanır',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(tester, services());

    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();

    expect(find.byType(KDialogCard), findsOneWidget);
    expect(find.byType(KModal), findsNothing,
        reason: 'başlıklı/ayraçlı kabuk bu kartta üstte boş bir bant bırakır');
    // ✕ kartın kendi köşesinde durmalı (web `absolute top-3 right-3`), yani
    // gövde metniyle AYNI hizada değil onun ÜSTÜNDE ve SAĞINDA.
    final kapat = tester.getCenter(find.byTooltip('Kapat'));
    final govde = tester.getTopLeft(find.textContaining('lütfen giriş yapın'));
    expect(kapat.dx, greaterThan(govde.dx),
        reason: '✕ gövdenin sağında olmalı');
  });

  testWidgets('misafir uyarısında ✕ ne oyunu başlatır ne giriş açar',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(tester, services());

    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();

    // Web'de de Escape/✕ üçüncü bir sonuç: kullanıcı kurulum ekranında kalır.
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('OYUNU BAŞLAT'), findsOneWidget);
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

    // Zorluk açıklaması her seviyede göründüğünden (6 Eylül 2026) kutu 900
    // px'lik ekranın altına taşıyor; görünmeyen düğmeye dokunuş ulaşmaz.
    await tester.ensureVisible(find.text('GİRİŞ YAP / KAYIT OL'));
    await tester.pumpAndSettle();
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
    expect(find.textContaining('SIRA SENDE'), findsOneWidget);
    expect(find.textContaining('SONRA SİLİNECEK'), findsOneWidget);
    // Anti-kaçış: yeni oyun formu hiç yok.
    expect(find.text('OYUNU BAŞLAT'), findsNothing);
    expect(find.text('OYUNCU SAYISI'), findsNothing);
    // Web: bu görünümde de (form yerine) kutu çıkıyor — className="mt-2" ile.
    expect(find.text('Neden Ücretsiz Üye Olmalıyım?'), findsOneWidget);

    // Devam: satıra dokun → GameScreen aynı turdan açılır. Dokunuş
    // loadSave (gerçek I/O) tetiklediğinden yine runAsync köprüsü gerekir.
    await tester.tap(find.textContaining('SIRA SENDE'));
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

  testWidgets('GİRİŞ satırının üstü/altı web ile aynı (12/0)', (tester) async {
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
    // 17 Ağustos 2026: kullanıcı Blok 6 görsel turunda 4'ü de kaldırdı
    // (*"az boşluk bize alt kısımda daha fazla yer kazandırır"*). İKİ taraf
    // birlikte indi — web `-mt-5` → `-mt-6`, portta `SizedBox` silindi.
    expect(logo.top - giris.bottom, 0,
        reason: 'GİRİŞ ile logo arası web py-6 (24) + -mt-6 (−24) = 0');
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

  // 19 Ağustos 2026: logo altındaki satırın ikinci linki "Arkadaşınla
  // paylaş" DEĞİL "Tanıtım" (paylaşım footer'a taşındı, bkz. aşağıdaki
  // footer testleri). Link `seenIntro` bayrağına DOKUNMAZ — bu, kapının
  // "ilk açılış" kararından bağımsız, kullanıcının kendi isteğiyle
  // açtığı bir tekrar gösterim.
  testWidgets('"Tanıtım" linki IntroScreen\'i açar', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(tester, services());

    expect(find.byType(IntroScreen), findsNothing);
    await tester.tap(find.text('Tanıtım'));
    await tester.pumpAndSettle();
    expect(find.byType(IntroScreen), findsOneWidget,
        reason: 'link bağlanmamış — kablo kopuk');
  });

  testWidgets(
      'tanıtım paragrafı ve "Nasıl oynanır? · Tanıtım" '
      'satırı ORTALI (web text-center paritesi)', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
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
      theme: kelimekiTheme(),
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
    //
    // ⚠ 24 AĞUSTOS 2026 — İKİNCİ sayı 16 → 33: link satırı artık 48px'lik
    // bir dokunma hedefi (`TapTarget`; web `min-h-[48px]`) ve METİN o
    // kutunun ortasında duruyor, yani boşluğun üstüne kutunun üst yarısı
    // (17px) ekleniyor. Aradaki 16px'lik AYIRICI değişmedi — değişen,
    // metnin kendi kutusu içindeki yeri. İki platform BİRLİKTE büyüdü.
    final logo = tester.getRect(find.byType(LogoMark).first);
    final para = tester.getRect(find.textContaining('Kelimeler kurarak'));
    final link = tester.getRect(find.text('Nasıl oynanır?'));
    expect(para.top - logo.bottom, closeTo(20, 1.5));
    expect(link.top - para.bottom, closeTo(33, 1.5));

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

  testWidgets('logo altındaki yazı bloğu web ile aynı: tracking YOK, '
      'paragraf 4 satır', (tester) async {
    // 13 Ağustos 2026, kullanıcı iki ekran görüntüsünü yan yana koyup
    // bildirdi: app'te paragraf 5 satıra düşüyor, web'de 4.
    //
    // Kök sebep Material 3'ün `bodyMedium` varsayılanı: `letterSpacing:
    // 0.25`, ve `letterSpacing` YAZMAYAN her metne miras kalıyor (widget'ın
    // kendi style'ı `null` bıraktığında `Text` DefaultTextStyle ile MERGE
    // ediyor). Web'de bu metinlerde tracking yok. 0.25 × ~57 karakter =
    // ~14px → "Ama" alt satıra düşüyor.
    //
    // Ölçüm iki tarafta da GERÇEK fontlarla yapıldı (web: derlenmiş CSS +
    // Space Mono woff2, HTTP üzerinden — `file://`de tarayıcı fontu CORS
    // ile engelleyip sessizce yedeğe düşüyor ve ölçüm YANILTICI oluyor;
    // ayrıca 400 ağırlığını yükleyip 700'ü unutmak linkleri yedek fontla
    // ölçtürüyordu). Sonuç, 428px içerik genişliğinde:
    //   paragraf 64px (4 satır) · "Nasıl oynanır?" 94.25 — port
    //   düzeltmeden sonra ikisini de birebir veriyor. (İkinci link
    //   19 Ağustos 2026'da "Arkadaşınla paylaş"tan "Tanıtım"a döndü.)
    //
    // Bu test SONUCU ölçüyor (satır sayısı), yalnızca girdiyi (fontSize/
    // height) değil — Parça 72'nin dersi: bir kısıtın VARLIĞINI doğrulayan
    // test, o kısıtın SONUCUNU doğrulamaz. Mevcut başlık bloğu testi
    // fontSize/height'ı kontrol ettiği hâlde bu sapmayı göremiyordu.
    await setPhoneViewSize(tester, const Size(1000, 900));
    await pumpSetup(tester, services());

    final paraFinder = find.textContaining('Kelimeler kurarak');
    final para = tester.getRect(paraFinder);
    expect(para.width, 428, reason: 'içerik genişliği web ile aynı olmalı');
    expect(para.height, 64,
        reason: '4 satır × 16px — 80 çıkıyorsa M3 tracking\'i sızmış demektir');

    // Efektif stil (DefaultTextStyle ile birleşmiş hâli) — asıl değişmez.
    double? trackingOf(Finder f) =>
        tester.renderObject<RenderParagraph>(f).text.style?.letterSpacing;
    expect(trackingOf(paraFinder), 0);
    expect(trackingOf(find.text('Nasıl oynanır?')), 0);
    expect(trackingOf(find.text('Tanıtım')), 0);
  });

  // 17 Ağustos 2026 — girişli/misafir Setup ekranı ikiye ayrıldı: logonun
  // altındaki tanıtım paragrafı + "Nasıl oynanır? · Tanıtım"
  // satırı yalnızca MİSAFİRDE görünüyor; girişli kullanıcı doğrudan "OYUN
  // TİPİ" başlığını görüyor ve logo→"OYUN TİPİ" arası TAM 20px (web'de
  // Chromium'da ölçüldü — kapsayıcının kendi `gap-5`i, telafi edici marj
  // eklenmedi).
  testWidgets(
      'girişli kullanıcıda logo altındaki paragraf/link satırı YOK, '
      'logo→"OYUN TİPİ" arası tam 20px', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(
        tester, services(auth: AuthService.fake(user: fakeUser('me'))));

    expect(find.textContaining('Kelimeler kurarak'), findsNothing);
    expect(find.text('Nasıl oynanır?'), findsNothing);
    expect(find.text('Tanıtım'), findsNothing);

    final logo = tester.getRect(find.byType(LogoMark).first);
    final oyunTipi = tester.getRect(find.text('OYUN TİPİ'));
    expect(oyunTipi.top - logo.bottom, closeTo(20, 1.5));
  });

  // Negatif eş: misafirde bu blok KOŞULSUZ gösterilseydi yukarıdaki test de
  // geçerdi — misafirin görünümü BİREBİR eskisi gibi kalmalı (mevcut
  // "logo altındaki yazı bloğu"/"tanıtım paragrafı … ORTALI" testleri zaten
  // bunu doğruluyor, burada yalnızca "OYUN TİPİ" doğrudan logonun altına
  // sızmadığını ekliyoruz).
  testWidgets('misafirde logo altındaki paragraf/link satırı HÂLÂ görünür',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(tester, services());

    expect(find.textContaining('Kelimeler kurarak'), findsOneWidget);
    expect(find.text('Nasıl oynanır?'), findsOneWidget);
    expect(find.text('Tanıtım'), findsOneWidget);
  });

  // 19 Ağustos 2026 (kullanıcı isteği): "Paylaş" artık GİRİŞTEN BAĞIMSIZ —
  // web `Setup.tsx` de onu `user &&` koşuluna bağlamıyor. Yani misafir de
  // girişli de AYNI üç maddeli footer'ı görüyor.
  testWidgets('footer: "Paylaş" misafirde de görünür (giriş şartı YOK) ve '
      'altında "© Kelimeki" satırı var', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 950));
    await pumpSetup(tester, services());

    await tester.scrollUntilVisible(find.text('Kullanım Koşulları'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Kullanım Koşulları'), findsOneWidget);
    expect(find.text('Gizlilik Politikası'), findsOneWidget);
    expect(find.text('Paylaş'), findsOneWidget);
    expect(find.text('© Kelimeki'), findsOneWidget);

    // Ayraç SAYISI da ölçülüyor: metnin VARLIĞINI doğrulayan bir test,
    // aradaki tutkalın (ayraç/boşluk) web'den sapmasını göremez — nitekim
    // 17 Ağustos'taki ilk sürümde girişli footer'da ayraç EKSİKTİ ve dört
    // test birden yeşil kalmıştı. Üç maddede tam İKİ ayraç var.
    // Not: logo altındaki misafir link satırı BOŞLUKLU ' · ' kullanıyor,
    // yani bu finder'a takılmıyor (ölçüldü).
    expect(find.text('·'), findsNWidgets(2));

    // Telif satırı hukuki satırın ALTINDA (web'in "Son çağrı" footer'ı).
    final legal = tester.getRect(find.text('Kullanım Koşulları'));
    final copy = tester.getRect(find.text('© Kelimeki'));
    expect(copy.top, greaterThan(legal.bottom));

    // ...ve ORTALI. 19 Ağustos 2026'da kullanıcı cihazda sola yapışmış
    // gördü: kapsayıcı Column `CrossAxisAlignment.stretch` olduğundan bu
    // Text tam genişliği kaplıyor ve `textAlign` verilmezse varsayılan
    // `start`, yani SOLA hizalanıyor.
    //
    // ⚠ BURADA GEOMETRİK BİR ORTALAMA KONTROLÜ İŞE YARAMAZ — tam da bu
    // yüzden hata satır eklendiği günden beri testten kaçtı: `stretch`
    // altında Text'in RenderBox'ı zaten tam genişlikte, yani `getRect(...).center.dx` iki
    // durumda da ekran merkezini verir; sola kaçan şey KUTU değil kutunun
    // İÇİNDEKİ glyph'ler. Bu yüzden boyamayı belirleyen özelliğin kendisi
    // ölçülüyor. Aynı sebeple yukarıdaki `copy.top > legal.bottom` kontrolü
    // de bu sapmayı göremiyordu — dikey sıra doğruydu.
    expect(tester.widget<Text>(find.text('© Kelimeki')).textAlign,
        TextAlign.center,
        reason: 'Telif satırı web\'de ortalı; `stretch` Column altında bunu '
            'sağlayan tek şey textAlign.center.');
  });

  testWidgets(
      'footer: "Paylaş" mevcut handleShare\'i (?ref=arkadas) ÇAĞIRIR — '
      'yeni bir paylaşım yolu yazılmadı', (tester) async {
    // GA4 `invite_link_shared` {source: setup_footer} — Faz 3.
    final fakeAnalytics = FakeAnalytics();
    analytics.configure(fakeAnalytics);
    addTearDown(analytics.reset);
    await setPhoneViewSize(tester, const Size(420, 950));
    String? sharedText;
    String? sharedUrl;
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: SetupScreen(
        services: services(auth: AuthService.fake(user: fakeUser('me'))),
        share: ({
          required png,
          required text,
          required url,
          required origin,
        }) async {
          sharedText = text;
          sharedUrl = url;
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Kullanım Koşulları'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Paylaş'), findsOneWidget);

    // Üç madde → İKİ ayraç (Koşullar · Gizlilik · Paylaş).
    expect(find.text('·'), findsNWidgets(2));
    expect(find.text('© Kelimeki'), findsOneWidget);

    await tester.tap(find.text('Paylaş'));
    await tester.pump();

    expect(sharedText, 'Hemen ücretsiz dene!');
    expect(sharedUrl, 'https://kelimeki.com/?ref=arkadas');
    expect(fakeAnalytics.names, ['invite_link_shared']);
    expect(fakeAnalytics.events.single.$2, {'source': 'setup_footer'});
  });

  testWidgets(
      'teşhis satırı DERLEME kimliğini gösterir (bayat derlemeyi ekran '
      'görüntüsünden ayırt edebilmek için)', (tester) async {
    // 15 Ağustos 2026: kullanıcı iki kez BAYAT bir derlemeyi test edip
    // "düzelmemiş" diye bildirdi — ekranda hangi kodun çalıştığını söyleyen
    // hiçbir şey yoktu. Etiket CI'da `--dart-define=BUILD_SHA=...` ile
    // dolar; testte tanım olmadığından `yerel` yazmalı.
    await setPhoneViewSize(tester, const Size(420, 950));
    await pumpSetup(tester, services());
    expect(find.textContaining('Derleme yerel'), findsOneWidget);
  });

  test('formatBuildLabel — CI damgası, yalnız sha, ve yerel derleme', () {
    expect(formatBuildLabel('', ''), 'yerel');
    expect(formatBuildLabel('', '15.08 11:42'), 'yerel',
        reason: 'sha yoksa saat tek başına bir kimlik DEĞİL');
    expect(formatBuildLabel('a1b2c3d', ''), 'a1b2c3d');
    expect(formatBuildLabel('a1b2c3d', '15.08 11:42'), 'a1b2c3d · 15.08 11:42');
  });

  testWidgets(
      'ARKADAŞINLA rozeti KENDİNİ TOPARLAR: kanal yeniden bağlanınca ve '
      'bağlantı geri gelince tazelenir (27 Ağustos 2026 saha hatası)',
      (tester) async {
    // Kullanıcı bildirdi: zayıf bağlantıda bekleyen 8 oyunu oynadı, rozet
    // 8'de TAKILI kaldı; listedeki her satır "Rakibin hamlesi bekleniyor"
    // diyordu — yani rozet ile liste birbiriyle ÇELİŞİYORDU.
    //
    // Sebep: Realtime kanalı kopunca kendi hamlelerinin yayınladığı olaylar
    // kayboluyor, `pendingCounts()` de ağ hatasında `null` döndüğünden
    // (bilinçli) SON BİLİNEN rozet korunuyor. `LiveGamesTab` bu iki
    // kancayı (onResubscribe + bağlantı dönüşü) baştan beri taşıyordu,
    // rozet taşımıyordu.
    await setPhoneViewSize(tester, const Size(420, 900));
    final net = OnlineStatus.fake();
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
            AuthService.fake(user: fakeUser('me')), OnlineGamesRepo(gw),
            onlineStatus: net));
    expect(tester.widget<CountBadge>(find.byType(CountBadge)).count, 1);

    // Sunucuda iş bitti ama HİÇBİR olay gelmedi (kanal kopuktu).
    gw.rows = [];

    // ARACIN CANLI OLDUĞUNU ÖNCE KANITLA: kanca olmadan rozet BAYAT kalır.
    // Bu satır düşerse aşağıdaki iddialar boşuna geçerdi.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<CountBadge>(arkadaslaRozeti()).count, 1,
        reason: 'olay gelmeden rozet zaten tazelenmiş — test bir şey '
            'kanıtlamıyor demektir');

    // (1) Kanal KOPUP yeniden bağlandı.
    // `fireAllOnResubscribe`: sekme açıkken hem rozet hem liste abone —
    // `lastOnResubscribe` yalnızca SONUNCUYU (listeyi) tutuyor.
    gw.fireAllOnResubscribe();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(arkadaslaRozeti(), findsNothing,
        reason: 'yeniden bağlanma bir tazeleme sinyalidir');

    // (2) Bağlantı gidip geri geldi — rozeti yeniden bayatlatıp ölçüyoruz.
    gw.rows = [
      gameRow(
          id: 'inv2',
          myId: 'me',
          status: 'pending',
          myRole: 'invitee',
          myInviteStatus: 'pending',
          myInviteId: 'i2'),
    ];
    net.debugSetOnline(false);
    await tester.pump();
    net.debugSetOnline(true);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<CountBadge>(arkadaslaRozeti()).count, 1,
        reason: 'bağlantı dönünce rozet tazelenmeli (web Setup.tsx '
            "window.addEventListener('online', …) karşılığı)");
  });

  testWidgets(
      'ARKADAŞINLA rozeti oyundan DÖNÜŞTE tazelenir — listeyle AYNI ANDA '
      '(28 Ağustos 2026 saha hatası)', (tester) async {
    // Kullanıcı bildirdi: *"Hiç bekleyen oyunum kalmamış olmasına rağmen
    // tab'da 1 uzun süre durdu. Sonra ekran kapandı, açınca gitti."*
    //
    // Kök sebep bir web↔port YAPI farkı: web'de oyuna girince Setup unmount
    // olup dönüşte remount oluyor, yani rozet effect'i baştan koşuyor.
    // Flutter'da Setup `MaterialApp.home` ve oyun ÜSTÜNE push ediliyor —
    // Setup hiç unmount olmuyor, rozetin tek dayanağı Realtime olayı ve
    // öne dönüş kalıyordu. `LiveGamesTab` dönüş anını LİSTE için baştan beri
    // garanti ediyordu (`_openGame` → `_reload`); rozet etmiyordu.
    await setPhoneViewSize(tester, const Size(420, 900));
    final gw = FakeOnlineGamesGateway()
      ..rows = [gameRow(id: 'g1', myId: 'me', status: 'active')]
      // `current: 1` = 'me' ikinci koltukta, yani SIRA BENDE → rozet 1.
      ..turnRows = [
        {'online_game_id': 'g1', 'current': 1},
      ];
    await pumpSetup(
        tester,
        liveBadgeServices(
            AuthService.fake(user: fakeUser('me')), OnlineGamesRepo(gw),
            friends: FriendsRepo(FakeFriendsGateway())));
    expect(tester.widget<CountBadge>(arkadaslaRozeti()).count, 1);

    // "Esiner açtı" satırı 6 Eylül 2026'da kalktı (yerine puan satırı);
    // kart artık anahtarıyla bulunuyor.
    await tester.tap(find.byKey(const ValueKey('game-g1')));
    await tester.pumpAndSettle();
    // `skipOffstage: false` ZORUNLU: push edilen rota üsttekini sahne dışına
    // alır ama SÖKMEZ — hatanın kaynağı zaten tam olarak bu (Setup mount'ta
    // kaldığı için remount tazelemesi hiç olmuyor).
    expect(find.byType(SetupScreen, skipOffstage: false), findsOneWidget,
        reason: 'Setup push altında MOUNT kalıyor — hatanın kaynağı bu');

    // Hamle oynandı: sunucuda bekleyen iş kalmadı ama HİÇBİR Realtime olayı
    // gelmedi (kanal kopuktu / olay kaçtı) ve uygulama öne de dönmedi.
    gw.rows = [];
    gw.turnRows = [];

    // `pageBack()` bir AppBar geri butonu arıyor; Canlı tahtanın kendi
    // çıkış düzeni var, o yüzden rota doğrudan pop ediliyor — testin konusu
    // dönüşün KENDİSİ, kullanıcının onu nasıl tetiklediği değil.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(arkadaslaRozeti(), findsNothing,
        reason: 'oyundan dönüş, listeninki gibi, rozet için de KESİN bir an');
  });

  // ─────────────────────────────────────────────────────────────────────
  // SINIF 2 (sessiz sıkışma) — "Devam Eden Oyun" satırı.
  //
  // İLK DÜZELTME YANLIŞ ŞEYİ SUÇLADI: sağ sütunun tamamı eşikte alta
  // alınmıştı ("SIRA SENDE etiketi yer yiyor" gerekçesiyle). Kullanıcı
  // cihazda gördü — etiket kartın ortasında duruyordu — ve ölçüm onu haklı
  // çıkardı (320 px): "SIRA SENDE" 89,6 → 113,4 px, SÜRE satırı 194,3 →
  // 246,9 px. Sağ sütunun enini süre belirliyordu, ölçek 1,0'da bile.
  //
  // Test üç şeyi kilitliyor, çünkü üçü ayrı ayrı bozulabilir:
  //   1. durum etiketi oyuncu satırıyla AYNI satırda (alta kaymıyor),
  //   2. süre satırı ONLARIN ALTINDA,
  //   3. isim alanı ölçek tavanında DARALMIYOR — sıkışmanın kendisi.
  testWidgets(
      'DEVAM EDEN OYUN: durum satırda kalır, süre alta iner, isim alanı sıkışmaz',
      (tester) async {
    late AppStorage storage;
    await tester.runAsync(() async {
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
      await session.end();
    });

    Future<(double, double, bool, bool)> olc(double olcek) async {
      // En dar desteklenen telefon: sıkışma burada en sert.
      await setPhoneViewSize(tester, const Size(320, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        navigatorObservers: [kRouteObserver],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(olcek)),
            child:
                SetupScreen(services: services(storage: Future.value(storage))),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (var i = 0;
          i < 50 && tester.any(find.text('KAYITLAR KONTROL EDİLİYOR…'));
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.text('DEVAM EDEN OYUN'), findsOneWidget);
      // PUAN SATIRI (6 Eylül 2026): avatarların altında, koltuk sırasıyla
      // ("0 - N" — insan pas geçti, YZ oynadı), sol alanın İÇİNDE.
      final puan = find.descendant(
          of: find.byKey(kDevamEdenSolKey),
          matching: find.textContaining(RegExp(r'^0 - \d+$')));
      expect(puan, findsOneWidget, reason: 'puan satırı avatarların altında');
      // Ölçülen şey avatar dizisi DEĞİL, onu barındıran sol ALANIN eni:
      // `Expanded` düzeninde sağdakinden artakalan alan bu.
      //
      // ⚠ Bulucu 2 Eylül 2026'da anahtara çevrildi. Öncesi
      // `find.ancestor(of: PlayerAvatarRow, matching: Column).first`di ve
      // sol taraf "avatar + Sıra: X" olduğu sürece doğru sütunu buluyordu;
      // o alt satır KALKINCA sol taraf tek bir `PlayerAvatarRow`a indi
      // (kendi eni sabit 36 px) ve bulucu DIŞ sütuna sıçrayıp kartın
      // tamamını ölçmeye başlardı — test düşmez, SESSİZCE anlamsızlaşırdı.
      final isim = tester.getRect(find.byKey(kDevamEdenSolKey));
      // Sıkışmanın GERÇEK kurbanı: avatar şeridi sol alana SIĞIYOR mu.
      // Oran iddiası (aşağıda) soyut; bu somut — daralma bir şeyi
      // taşırıyorsa hata BURADA görünür.
      // ⚠ Bulucu `byType` DEĞİL, anahtarlı sol alanın ALTINDA aranıyor:
      // aynı ekranda ("Son Oynadıklarım" vb.) ikinci bir `PlayerAvatarRow`
      // belirirse `byType` "Found N widgets" ile patlar ya da yanlış olanı
      // ölçer. Bu daldaki sessiz-bulucu dersinin aynısı.
      final avatar = tester.getRect(find.descendant(
          of: find.byKey(kDevamEdenSolKey),
          matching: find.byType(PlayerAvatarRow)));
      final durum = tester.getRect(find.textContaining('SIRA SENDE'));
      final sure = tester.getRect(find.textContaining('SONRA'));
      final puanRect = tester.getRect(puan);
      expect(puanRect.top, greaterThanOrEqualTo(avatar.bottom),
          reason: 'puan satırı avatar şeridinin ALTINDA olmalı');
      expect(sure.top, greaterThanOrEqualTo(puanRect.bottom),
          reason: 'kalan süre puan satırının ALTINDA olmalı');
      return (
        isim.width,
        avatar.width,
        // durum oyuncu satırıyla DİKEYDE örtüşüyor mu (aynı satır mı)
        durum.top < isim.bottom && durum.bottom > isim.top,
        sure.top >= durum.bottom, // süre durumun ALTINDA mı
      );
    }

    final (enNormal, avatarNormal, satirdaNormal, altaNormal) = await olc(1.0);
    final (enTavan, avatarTavan, satirdaTavan, altaTavan) =
        await olc(kMaxTextScale);

    // Düzen ölçekten BAĞIMSIZ — iki ölçekte de aynı şekil (bu, kalkan
    // `buyukOlcek` dalının negatif eşi: dal geri gelirse biri düşer).
    expect(satirdaNormal, isTrue, reason: 'ölçek 1,0da durum satırda olmalı');
    expect(satirdaTavan, isTrue,
        reason: 'ölçek ${kMaxTextScale}te de durum satırda KALMALI');
    expect(altaNormal, isTrue, reason: 'süre satırı altta olmalı');
    expect(altaTavan, isTrue, reason: 'süre satırı tavanda da altta olmalı');

    // ── Sıkışma ────────────────────────────────────────────────────────
    // ÖNCE SOMUT OLAN: avatar şeridi sol alana sığmalı. Daralmanın
    // ölçülebilir bir ZARARI varsa burada görünür — oran iddiası (aşağıda)
    // bunun yalnızca VEKİLİ.
    expect(avatarNormal, lessThanOrEqualTo(enNormal),
        reason: 'avatar şeridi (${avatarNormal.toStringAsFixed(1)} px) sol '
            'alana (${enNormal.toStringAsFixed(1)} px) sığmalı');
    expect(avatarTavan, lessThanOrEqualTo(enTavan),
        reason: 'ölçek tavanında avatar şeridi '
            '(${avatarTavan.toStringAsFixed(1)} px) sol alana '
            '(${enTavan.toStringAsFixed(1)} px) sığmalı');

    // Oran iddiası: mutlak px'e DEĞİL orana bağlı, çünkü px font
    // metriklerinden türüyor ve ortama göre oynuyor (bu depoda bir kez CI'ı
    // düşürdü).
    //
    // ⚠ EŞİK 0,75 → 0,70 (2 Eylül 2026) ve bu bir "testi susturma" DEĞİL,
    // ölçülmüş bir yeniden ayar. Üç gerçek:
    //
    // 1. **0,75 tasarlanmış bir sınır değildi, bir CIRCIR'dı** — o günkü
    //    ölçüm 0,765'ti ve eşik onun hemen altına kondu. Ölçüldü ki eşik
    //    HERHANGİ bir punto artışını bloke ediyor: 15 px → 0,710 (gerçek),
    //    14 px → 0,739 (türetildi). Yani kullanıcı "fontu biraz büyüt"
    //    dediği anda bu iddia hangi puntoda olursa olsun düşüyordu.
    // 2. **Sol sütunda artık METİN YOK.** Daralmanın kurbanı "Sıra: X"
    //    satırıydı; 2 Eylül'de kaldırıldı. Geriye kalan `PlayerAvatarRow`
    //    SABİT genişlikte (20 px avatar, 4 px bindirme) ve ölçekle
    //    BÜYÜMÜYOR — yukarıdaki iki somut iddia tam da bunu kilitliyor.
    // 3. **Daralmanın kaynağı meşru:** durum etiketi ölçekle büyüyor ve
    //    `Expanded` olmayan taraftan yer alıyor. Durdurmanın tek yolu ekran
    //    başına ölçek kısıtı olurdu — `mobile/CLAUDE.md` kural 1 bunu
    //    YASAKLIYOR (tavan TEK yerde).
    //
    // Yani 0,70 "ne kadar kötüye izin veriyoruz" değil, "beklenmedik bir
    // ikinci daralma kaynağı belirirse haber ver" eşiği. ÖLÇÜLEN: 130,2 →
    // 92,5 px = 0,710.
    expect(enTavan / enNormal, greaterThanOrEqualTo(0.70),
        reason: 'isim alanı ${enNormal.toStringAsFixed(1)} → '
            '${enTavan.toStringAsFixed(1)} px, yani beklenenden çok daraldı');

    await tester.runAsync(() => storage.close());
  });
}
