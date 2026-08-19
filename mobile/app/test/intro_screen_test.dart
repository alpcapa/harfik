// İlk açılış tanıtımı (`IntroScreen`) + kapısı (`app.dart`'taki _HomeGate).
//
// Ölçülen sözleşme üç parça:
//  1) ekranın kendisi — dört sayfa, DEVAM ilerletir, son sayfada HEMEN OYNA
//     (ve HİÇBİR yerde atlama yok: tanıtımın TEK çıkışı o düğme);
//  2) kapı — bayrak YOKKEN tanıtım, VARKEN doğrudan Setup;
//  3) bayrak GERÇEKTEN yazılıyor (yoksa tanıtım her açılışta çıkardı).
//
// Kapı testleri GERÇEK `AppStorage` kullanıyor (sqflite ffi): bayrağın
// yazıldığını sahte bir depo üzerinden "kanıtlamak" hiçbir şey kanıtlamaz.
// Gerçek I/O testWidgets'ın sahte zaman bölgesinde ilerlemediğinden her
// testin sonunda `drainRealIo` şart (Parça 11/13/64/74'ün dersi).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/intro/intro_screen.dart';
import 'package:kelimeki/src/ui/rank/league_rank.dart';
import 'package:kelimeki/src/ui/rank/rank_seal.dart';
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_view.dart';

Future<void> drainRealIo(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump();
}

/// Gerçek depo — `AppStorage.open` gerçek I/O olduğundan `runAsync` köprüsü
/// şart (pump'tan ÖNCE açılıyor ki kapının beklediği Future zaten çözülmüş
/// olsun; aksi halde sahte zamanda hiç tamamlanmaz).
Future<AppStorage> newStorage(WidgetTester tester,
    {bool seenIntro = false}) async {
  late AppStorage storage;
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(
        seenIntro ? {'seen_intro': true} : {});
    storage = await AppStorage.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      prefs: await SharedPreferences.getInstance(),
      nowMs: () => DateTime.now().millisecondsSinceEpoch,
    );
  });
  return storage;
}

AppServices services({Future<AppStorage>? storage}) => AppServices(
      onlineStatus: OnlineStatus.fake(),
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: AuthService(null),
      supabase: null,
      versionGate: VersionGateStatus.ok,
      storage: storage,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('IntroScreen', () {
    testWidgets('dört sayfa: DEVAM ilerletir, son sayfada HEMEN OYNA çıkar ve '
        'onDone çağrılır; atlama YOK', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      var done = 0;
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: IntroScreen(onDone: () => done++),
      ));

      // İlk sayfa: kahraman cümlesi + DEVAM. Kahraman cümlesinin TAMAMI
      // aranıyor (`textContaining` DEĞİL): 2. sayfadaki "Bölgeni büyüt"
      // adımı da aynı alt dizeyi taşıyor, PageView komşu sayfayı da inşa
      // ederse eşleşme ikiye çıkardı.
      expect(find.text('Kelime bul, bölgeni büyüt, tahtayı ele geçir.'),
          findsOneWidget);
      expect(find.text('DEVAM'), findsOneWidget);
      expect(find.text('HEMEN OYNA'), findsNothing);
      // Atlama YOK — 19 Ağustos 2026 kullanıcı kararı. Bu iddia her
      // sayfada tekrarlanıyor (aşağı bkz.), çünkü tek bir sayfada
      // yokluğunu görmek başka bir sayfada durduğunu ekarte etmez.
      expect(find.text('Atla'), findsNothing);

      for (var i = 0; i < kIntroPageCount - 1; i++) {
        await tester.tap(find.text('DEVAM'));
        await tester.pumpAndSettle();
        expect(find.text('Atla'), findsNothing);
      }

      // Son sayfa: tanıtımın TEK çıkışı.
      expect(find.text('HEMEN OYNA'), findsOneWidget);
      expect(find.text('DEVAM'), findsNothing);
      expect(done, 0);

      await tester.tap(find.text('HEMEN OYNA'));
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    // 19 Ağustos 2026, kullanıcı spesifikasyonu: dört slaytın İÇERİĞİ
    // (yalnızca sayısı değil) web'in karşılama katmanıyla aynı olmalı —
    // "Bu tanıtım değil kaçırım olmuş… webdeki gibi tahtaya bir bak
    // bölümünü koy… 3. slayt: neler var (6 kutu), 4. slayt: k-lig
    // (9 kutu)". Her slaytta o slayta ÖZGÜ bir işaret aranıyor; PageView
    // komşu sayfayı da inşa edebildiğinden başlıklar bilerek benzersiz.
    testWidgets('dört slaydın içeriği: tahta · dört adım · altı özellik · '
        'dokuz rütbe', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: IntroScreen(onDone: () {}),
      ));

      // 1. slayt: kahraman + dört rakam kutusu + GERÇEK tahta.
      expect(find.text('Oyun tam olarak böyle görünüyor'), findsOneWidget);
      expect(find.byType(BoardWidget), findsOneWidget);
      expect(find.text('13×13'), findsOneWidget);
      expect(find.text('X2 — Kelime puanının 2 katı'), findsOneWidget);

      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();

      // 2. slayt: dört adımın DÖRDÜ de tek sayfada (eski sürümde ikişer
      // ikişer iki sayfaya bölünmüştü).
      expect(find.text('Nasıl oynanır?'), findsOneWidget);
      // "Köşenden başla" BİLEREK aranmıyor: 1. slayttaki tahta açıklaması da
      // aynı cümleyle başlıyor ve PageView komşu sayfayı önbellekte tutabilir.
      expect(find.textContaining('İlk kelimen köşendeki ev karesine'),
          findsOneWidget);
      expect(find.textContaining('Bölgeni büyüt'), findsOneWidget);
      expect(find.textContaining('Merkeze oyna'), findsOneWidget);
      expect(find.textContaining('Bölge vergisine dikkat!'), findsOneWidget);

      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();

      // 3. slayt: altı özellik kutusu.
      expect(find.text("Kelimeki'de neler yapabilirsin?"), findsOneWidget);
      expect(find.text('Yapay zekaya karşı oyna'), findsOneWidget);
      expect(find.text('k-lig ve rütbeler'), findsOneWidget);

      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();

      // 4. slayt: dokuz rütbe — liste `kRankTiers`ten çiziliyor, elle
      // yazılmıyor (eşik/ad değişirse ekran kendiliğinden takip eder).
      expect(find.text("Çaylak'tan Tanrı'ya dokuz rütbe"), findsOneWidget);
      expect(find.byType(RankSeal), findsNWidgets(kRankTiers.length));
      expect(find.text(kRankTiers.first.name), findsOneWidget);
      expect(find.text(kRankTiers.last.name), findsOneWidget);
    });
  });

  group('kapı (_HomeGate)', () {
    testWidgets('ilk açılış: tanıtım çıkar, bitince Setup açılır ve bayrak '
        'GERÇEKTEN yazılır', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 950));
      final storage = await newStorage(tester);
      expect(storage.flags.seenIntro, isFalse);

      await tester.pumpWidget(
          KelimekiApp(services: services(storage: Future.value(storage))));
      await tester.pumpAndSettle();

      expect(find.byType(IntroScreen), findsOneWidget);
      expect(find.byType(SetupScreen), findsNothing);

      // Tanıtımın TEK çıkışı son sayfadaki düğme — kapı testinin de o
      // yoldan geçmesi gerekiyor (atlama kaldırıldı).
      for (var i = 0; i < kIntroPageCount - 1; i++) {
        await tester.tap(find.text('DEVAM'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('HEMEN OYNA'));
      await tester.pumpAndSettle();

      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(SetupScreen), findsOneWidget);

      await drainRealIo(tester);
      expect(storage.flags.seenIntro, isTrue,
          reason: 'bayrak yazılmazsa tanıtım HER açılışta tekrar çıkar');
    });

    testWidgets('ikinci açılış: tanıtım HİÇ çıkmaz', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 950));
      final storage = await newStorage(tester, seenIntro: true);

      await tester.pumpWidget(
          KelimekiApp(services: services(storage: Future.value(storage))));
      await tester.pumpAndSettle();

      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(SetupScreen), findsOneWidget);
      await drainRealIo(tester);
    });

    testWidgets('depo YOKKEN (widget testleri/önizlemeler) kapı devreye '
        'girmez — doğrudan Setup', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 950));
      await tester.pumpWidget(KelimekiApp(services: services()));
      await tester.pump();
      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(SetupScreen), findsOneWidget);
    });
  });
}
