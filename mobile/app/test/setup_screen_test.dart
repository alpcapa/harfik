// Setup ekranı testleri — web Setup.tsx misafir akışının paritesi: oyuncu
// sayısı seçimi, Misafir+YZ kadrosuyla oyun başlatma, Arkadaşınla "sonraki
// sürümde" diyaloğu, tekil kayıt varken anti-kaçış (form yok, Devam Eden
// Oyun satırı) ve kayıttan devam. Gerçek SQLite (ffi) + gerçek sözlük.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/game/local_game_repo.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
      supabase: null,
      versionGate: VersionGateStatus.ok,
      storage: storage,
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

  testWidgets('ARKADAŞINLA sekmesi dürüst "sonraki sürümde" diyaloğu açar',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpSetup(tester, services());

    await tester.tap(find.text('ARKADAŞINLA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sonraki sürümünde gelecek'), findsOneWidget);
    await tester.tap(find.text('TAMAM'));
    await tester.pumpAndSettle();
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
}
