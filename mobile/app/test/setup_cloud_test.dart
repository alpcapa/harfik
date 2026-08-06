// Setup'ın GİRİŞLİ dalı — web'in `user && !creatingLocal` görünümü: bulut
// kayıt listesi varsayılan, kurulum formu "+ Yeni Yapay Zeka Oyunu Aç" ile
// açılır, VAZGEÇ listeye döner; satırdan devam AYNI sunucu satırını
// güncellemeye devam eder. Gateway sahte (bellek içi) — gerçek Supabase ucu
// cihazda doğrulanır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/cloud_save_repo.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/logo_mark.dart';
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

class MemGateway implements CloudSaveGateway {
  final rows = <String, Map<String, Object?>>{};

  @override
  Future<List<Map<String, Object?>>> list() async => [
        for (final e in rows.entries)
          {
            'id': e.key,
            'state': e.value['state'],
            'updated_at': e.value['updated_at'],
          }
      ];

  @override
  Future<void> upsert(String id, String userId,
      Map<String, Object?> stateJson, int playerCount) async {
    rows[id] = {
      'state': stateJson,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<void> delete(String id) async => rows.remove(id);
}

User fakeUser() => User(
      id: 'u-test',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: 'alp.capa@hotmail.com',
    );

const ironman = KProfile(id: 'u-test', displayName: 'Ironman');

AppServices services(MemGateway gw) => AppServices(
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: AuthService.fake(user: fakeUser(), profile: ironman),
      supabase: null,
      versionGate: VersionGateStatus.ok,
      cloudSaves: CloudSaveRepo(gw),
    );

/// turnCount>=2 olan gerçek bir play state'i satır olarak kuyruklar.
Future<GameState> seedSave(MemGateway gw, String id) async {
  final c = GameController(
      words: SetWordSource(const ['ab', 'aba', 'kelime']),
      autoPlayAi: false,
      nowIso: () => '');
  c.dispatch(const StartAction([
    PlayerSetup(name: 'Ironman', isAI: false),
    PlayerSetup(name: 'Yapay Zeka 2', isAI: true),
  ]));
  c.dispatch(const PassAction());
  c.dispatch(const AiPlayAction());
  final state = c.state;
  await gw.upsert(id, 'u-test', gameStateToJson(state), 2);
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  Future<void> pumpSetup(WidgetTester tester, MemGateway gw) async {
    await setPhoneViewSize(tester, const Size(420, 950));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: SetupScreen(services: services(gw)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('girişli: liste varsayılan, satır teslim diliyle + ekran görüntüsü',
      (tester) async {
    final gw = MemGateway();
    await seedSave(gw, 'save-1');

    await setPhoneViewSize(tester, const Size(420, 950));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: RepaintBoundary(key: key, child: SetupScreen(services: services(gw))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('+ YENİ YAPAY ZEKA OYUNU AÇ'), findsOneWidget);
    expect(find.text('DEVAM EDEN OYUNLAR'), findsOneWidget);
    expect(find.text('SENİN HAMLEN BEKLENİYOR'), findsOneWidget);
    expect(find.text('Sıra: Ironman'), findsOneWidget);
    // Girişli + turnCount>=2 → web remainingTime "teslim sayılacak" dili.
    expect(find.textContaining('TESLİM SAYILACAK'), findsOneWidget);
    // Kurulum formu varsayılanda GİZLİ (web creatingLocal=false).
    expect(find.text('OYUNCU SAYISI'), findsNothing);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/setup_cloud_list.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  testWidgets('boş liste metni + form aç/Vazgeç döngüsü', (tester) async {
    final gw = MemGateway();
    await pumpSetup(tester, gw);

    expect(find.text('Devam eden bir Yapay Zeka oyunun yok.'), findsOneWidget);

    await tester.tap(find.text('+ YENİ YAPAY ZEKA OYUNU AÇ'));
    await tester.pumpAndSettle();
    expect(find.text('OYUNCU SAYISI'), findsOneWidget);
    expect(find.text('OYUNU BAŞLAT'), findsOneWidget);
    expect(find.text('VAZGEÇ'), findsOneWidget);
    // Form 1. koltuğu hesapla gösterir (parça 1 davranışı korunuyor).
    expect(find.text('Ironman'), findsOneWidget);

    await tester.tap(find.text('VAZGEÇ'));
    await tester.pumpAndSettle();
    expect(find.text('OYUNCU SAYISI'), findsNothing);
    expect(find.text('Devam eden bir Yapay Zeka oyunun yok.'), findsOneWidget);
  });

  testWidgets('satırdan devam: oyun açılır, autosave AYNI satırı günceller',
      (tester) async {
    final gw = MemGateway();
    final seeded = await seedSave(gw, 'save-1');
    await pumpSetup(tester, gw);

    await tester.tap(find.text('SENİN HAMLEN BEKLENİYOR'));
    await tester.pumpAndSettle();
    // Oyun ekranı açıldı — kaldığı yerden (aynı tur sayısı).
    expect(find.text('OYNA'), findsOneWidget);

    // Bir yerel düzenleme (raf taşı seç) → debounce'lu autosave.
    await tester.tap(find.byKey(const ValueKey('rack-0')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(gw.rows.length, 1); // yeni satır AÇILMADI
    expect(gw.rows.containsKey('save-1'), isTrue);
    final saved = gameStateFromJson(
        (gw.rows['save-1']!['state'] as Map).cast<String, Object?>());
    expect(saved.turnCount, seeded.turnCount);

    // Geri dön (logo dokunuşu → pop) → liste tazelenir, satır hâlâ tek.
    await tester.tap(find.byType(LogoMark));
    await tester.pumpAndSettle();
    expect(find.text('SENİN HAMLEN BEKLENİYOR'), findsOneWidget);
  });

  testWidgets('yeni oyun turnCount<2 iken terk edilirse listede iz bırakmaz',
      (tester) async {
    final gw = MemGateway();
    await pumpSetup(tester, gw);

    await tester.tap(find.text('+ YENİ YAPAY ZEKA OYUNU AÇ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();
    expect(find.text('OYNA'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700)); // autosave yazdı
    expect(gw.rows.length, 1);

    // Hiç hamle yapmadan çık (web handleLogoClick turnCount<2 kuralı).
    await tester.tap(find.byType(LogoMark));
    await tester.pumpAndSettle();
    expect(gw.rows, isEmpty);
    expect(find.text('Devam eden bir Yapay Zeka oyunun yok.'), findsOneWidget);
  });
}
