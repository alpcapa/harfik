// Zoom tanıtım balonu (1 Eylül 2026, kullanıcı isteği).
//
// KURAL (birebir): *"Sadece İlk oyun açılışında, açan kişide ve karşıdaki
// kişilerde 1 kereye mahsus bir balon çıksın... Deneyip büyütenlere bir daha
// gösterme. Hiç denememişse bir daha sefer tekrar göster. Deneme gösterimi
// bitirir."*
//
// Kural iki değere birden bakıyor (`FlagsStore.shouldShowZoomHint`) ve
// hiçbir derleyici bunu doğrulayamaz — dolayısıyla test ŞART. Web ikizi:
// `tests/smoke.spec.ts` → "zoom tanıtım balonu".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'board_zoom_test.dart' show doubleTapAt, isZoomedIn;
import 'game_screen_test.dart' show craftedState, boardCell;
import 'support/real_io.dart';
import 'support/test_view.dart';

const _metin =
    'Boş kareye veya çerçevesine çift tıklama tahtayı büyütür. Hemen dene!';

Future<AppStorage> _storage(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AppStorage.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    prefs: await SharedPreferences.getInstance(),
  );
}

Future<(GameController, AppStorage)> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  await setPhoneViewSize(tester, const Size(420, 900));
  // ⚠ `testWidgets` İÇİNDE gerçek I/O `runAsync` ister — sahte zonda
  // beklenen bir sqflite açılışı hiç tamamlanmaz ve test asılır (bu
  // projenin kayıtlı tuzağı: mobile/CLAUDE.md → "await newRepo(" taraması).
  final storage = (await tester.runAsync(() => _storage(prefs)))!;
  final words = SetWordSource(const ['ab', 'aba']);
  final controller =
      GameController(words: words, autoPlayAi: false, nowIso: () => '');
  controller.dispatch(ResumeSavedAction(craftedState()));
  await tester.pumpWidget(MaterialApp(
    theme: kelimekiTheme(),
    home: GameScreen(
      controller: controller,
      words: words,
      auth: AuthService.fake(),
      storage: Future.value(storage),
    ),
  ));
  await drainRealIo(tester);
  return (controller, storage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  testWidgets('ilk oyun açılışında balon ÇIKAR ve sayaç 1 olur',
      (tester) async {
    final (_, storage) = await _pump(tester);
    expect(find.text(_metin), findsOneWidget);
    expect(storage.flags.zoomHintShown, 1);
    expect(storage.flags.zoomTried, isFalse);
  });

  testWidgets('HİÇ DENEMEYEN kullanıcıya İKİNCİ açılışta bir kez daha çıkar',
      (tester) async {
    final (_, storage) = await _pump(tester, prefs: {'zoom_hint_shown': 1});
    expect(find.text(_metin), findsOneWidget,
        reason: 'kullanıcı isteği: "hiç denememişse bir daha sefer göster"');
    expect(storage.flags.zoomHintShown, 2);
  });

  testWidgets('ÜÇÜNCÜ açılışta artık çıkmaz (tavan 2)', (tester) async {
    final (_, storage) = await _pump(tester, prefs: {'zoom_hint_shown': 2});
    expect(find.text(_metin), findsNothing);
    expect(storage.flags.zoomHintShown, 2, reason: 'sayaç boşuna artmamalı');
  });

  testWidgets('DENEYEN kullanıcıya bir daha ASLA çıkmaz (sayaç 0 olsa bile)',
      (tester) async {
    final (_, storage) = await _pump(tester, prefs: {'zoom_tried': true});
    expect(find.text(_metin), findsNothing);
    expect(storage.flags.zoomHintShown, 0);
  });

  testWidgets('zoom DENENİNCE balon anında kapanır ve bayrak kalıcı yazılır',
      (tester) async {
    final (_, storage) = await _pump(tester);
    expect(find.text(_metin), findsOneWidget);

    await doubleTapAt(tester, tester.getCenter(boardCell(6, 6)));
    expect(isZoomedIn(tester), isTrue);
    expect(find.text(_metin), findsNothing,
        reason: 'kullanıcı isteği: "Deneme gösterimi bitirir"');

    await drainRealIo(tester);
    expect(storage.flags.zoomTried, isTrue);
  });

  testWidgets('storage verilmezse balon HİÇ çıkmaz (testler/önizlemeler)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final words = SetWordSource(const ['ab', 'aba']);
    final controller =
        GameController(words: words, autoPlayAi: false, nowIso: () => '');
    controller.dispatch(ResumeSavedAction(craftedState()));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: GameScreen(
          controller: controller, words: words, auth: AuthService.fake()),
    ));
    await tester.pump();
    expect(find.text(_metin), findsNothing);
  });
}
