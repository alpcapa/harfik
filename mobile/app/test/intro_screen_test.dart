// İlk açılış tanıtımı (`IntroScreen`) + kapısı (`app.dart`'taki _HomeGate).
//
// Ölçülen sözleşme üç parça:
//  1) ekranın kendisi — dört sayfa, DEVAM ilerletir, son sayfada BAŞLA;
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
import 'package:kelimeki/src/ui/intro/intro_screen.dart';
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
    testWidgets('dört sayfa: DEVAM ilerletir, son sayfada BAŞLA çıkar ve '
        'onDone çağrılır', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      var done = 0;
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: IntroScreen(onDone: () => done++),
      ));

      // İlk sayfa: kahraman cümlesi + "Atla" + DEVAM.
      // Kahraman cümlesinin TAMAMI aranıyor (`textContaining` DEĞİL):
      // 2. sayfadaki "Bölgeni büyüt" adımı da aynı alt dizeyi taşıyor,
      // PageView komşu sayfayı da inşa ederse eşleşme ikiye çıkardı.
      expect(find.text('Kelime bul, bölgeni büyüt, tahtayı ele geçir.'),
          findsOneWidget);
      expect(find.text('Atla'), findsOneWidget);
      expect(find.text('DEVAM'), findsOneWidget);
      expect(find.text('BAŞLA'), findsNothing);

      for (var i = 0; i < kIntroPageCount - 1; i++) {
        await tester.tap(find.text('DEVAM'));
        await tester.pumpAndSettle();
      }

      // Son sayfa: BAŞLA, "Atla" YOK (aynı işi yapan iki kontrol olmasın).
      expect(find.text('BAŞLA'), findsOneWidget);
      expect(find.text('DEVAM'), findsNothing);
      expect(find.text('Atla'), findsNothing);
      expect(done, 0);

      await tester.tap(find.text('BAŞLA'));
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    testWidgets('"Atla" ilk sayfadan da bitirir', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      var done = 0;
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: IntroScreen(onDone: () => done++),
      ));
      await tester.tap(find.text('Atla'));
      await tester.pumpAndSettle();
      expect(done, 1);
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

      await tester.tap(find.text('Atla'));
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
