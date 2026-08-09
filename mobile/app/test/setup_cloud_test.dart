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
import 'package:kelimeki/src/data/games_api.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/game/logo_mark.dart';
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart' show gameRow;
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

  @override
  Future<Map<String, Object?>?> claimAbandoned(
      String id, String cutoffIso) async {
    final row = rows[id];
    if (row == null) return null;
    if ((row['updated_at'] as String).compareTo(cutoffIso) >= 0) return null;
    rows.remove(id);
    return (row['state'] as Map).cast<String, Object?>();
  }
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

Future<GamesRepo> memGamesRepo(FakeGamesGateway gw) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await AppStorage.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    prefs: await SharedPreferences.getInstance(),
    nowMs: () => DateTime.now().millisecondsSinceEpoch,
  );
  return GamesRepo(gw, storage.queue);
}

AppServices services(MemGateway gw, {Future<GamesRepo>? games}) => AppServices(
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: AuthService.fake(user: fakeUser(), profile: ironman),
      supabase: null,
      versionGate: VersionGateStatus.ok,
      cloudSaves: CloudSaveRepo(gw),
      games: games,
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
  sqfliteFfiInit();

  setUpAll(loadAppFonts);

  Future<void> pumpSetup(WidgetTester tester, MemGateway gw,
      {Future<GamesRepo>? games}) async {
    await setPhoneViewSize(tester, const Size(420, 950));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: SetupScreen(services: services(gw, games: games)),
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

  testWidgets(
      'regresyon (Parça 28): Devam Edenler/Son Oynananlar GERÇEK bir sekme '
      'sistemi — eskiden listenin altına sessizce ekleniyordu', (tester) async {
    final gw = MemGateway();
    await seedSave(gw, 'save-1');
    final gamesGw = FakeGamesGateway(userId: 'u-test')
      ..history = [gameRow(id: 'g1', userId: 'u-test')];
    final gamesRepo = await tester.runAsync(() => memGamesRepo(gamesGw));
    await pumpSetup(tester, gw, games: Future.value(gamesRepo));

    // Varsayılan: "Devam Edenler" seçili, o listenin satırı görünür,
    // "Son Oynananlar"ın içeriği (Son Oynadıklarım başlığı) HENÜZ yok.
    expect(find.text('DEVAM EDENLER'), findsOneWidget);
    expect(find.text('SON OYNANANLAR'), findsOneWidget);
    expect(find.text('SENİN HAMLEN BEKLENİYOR'), findsOneWidget);
    expect(find.text('SON OYNADIKLARIM'), findsNothing);

    // "Son Oynananlar"a geç — biten oyunun kartı gelir, devam eden oyunun
    // satırı artık EKRANDA DEĞİL (eskiden ikisi aynı anda, alt alta duruyordu).
    await tester.tap(find.text('SON OYNANANLAR'));
    await tester.pumpAndSettle();
    expect(find.text('SON OYNADIKLARIM'), findsOneWidget);
    expect(find.text('SENİN HAMLEN BEKLENİYOR'), findsNothing);

    // Geri dön.
    await tester.tap(find.text('DEVAM EDENLER'));
    await tester.pumpAndSettle();
    expect(find.text('SENİN HAMLEN BEKLENİYOR'), findsOneWidget);
    expect(find.text('SON OYNADIKLARIM'), findsNothing);

    // "Arkadaşınla"ya geçip geri dönmek "Devam Edenler"e sıfırlamalı (web
    // `useEffect(() => setLocalSubTab('active'), [mainView])`) — önce
    // "Son Oynananlar"a geçip test ediyoruz.
    await tester.tap(find.text('SON OYNANANLAR'));
    await tester.pumpAndSettle();
    expect(find.text('SON OYNADIKLARIM'), findsOneWidget);
    await tester.tap(find.text('ARKADAŞINLA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YAPAY ZEKA İLE'));
    await tester.pumpAndSettle();
    expect(find.text('SENİN HAMLEN BEKLENİYOR'), findsOneWidget);
    expect(find.text('SON OYNADIKLARIM'), findsNothing);
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

  testWidgets('7 günü dolan bulut kaydı: iddia edilir → -2 cezalı teslim kaydı',
      (tester) async {
    final gw = MemGateway();
    await seedSave(gw, 'stale');
    // Satırı 8 gün geriye al (web'in 7 günlük ABANDON_TIMEOUT eşiği).
    gw.rows['stale']!['updated_at'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 8))
        .toIso8601String();

    final gamesGw = FakeGamesGateway(userId: 'u-test');
    final gamesRepo = await tester.runAsync(() => memGamesRepo(gamesGw));
    await pumpSetup(tester, gw, games: Future.value(gamesRepo));
    await tester.pumpAndSettle();

    // Satır sunucudan silindi ve listede görünmüyor.
    expect(gw.rows, isEmpty);
    expect(find.text('Devam eden bir Yapay Zeka oyunun yok.'), findsOneWidget);
    // -2 cezalı teslim kaydı + terk bildirimi + telemetri üretildi.
    expect(gamesGw.inserted, hasLength(1));
    expect(gamesGw.inserted.single['surrendered'], isTrue);
    expect(gamesGw.inserted.single['result'], 'lose');
    expect(gamesGw.inserted.single['player_score'], 0);
    expect(gamesGw.notified, hasLength(1));
    expect(gamesGw.finishes.single['ended_by_surrender'], isTrue);
  });

  testWidgets('oyun bitince kayıt ANINDA tutulur (ekrandan çıkmadan)',
      (tester) async {
    final gw = MemGateway();
    final gamesGw = FakeGamesGateway(userId: 'u-test');
    final gamesRepo = await tester.runAsync(() => memGamesRepo(gamesGw));
    await pumpSetup(tester, gw, games: Future.value(gamesRepo));

    await tester.tap(find.text('+ YENİ YAPAY ZEKA OYUNU AÇ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();
    expect(gamesGw.inserted, isEmpty);

    // Oyunu bitmiş hâle getir (gerçek bir bitişin reducer sonucu yerine
    // doğrudan state — burada test edilen şey KAYIT tetikleyicisi).
    final controller = tester
        .widget<GameScreen>(find.byType(GameScreen))
        .controller;
    controller.restore(controller.state.copyWith(isGameOver: true));
    await tester.pumpAndSettle();

    // Ekrandan HİÇ çıkmadan kayıt gitti (web'in [isGameOver] effect'i).
    expect(gamesGw.inserted, hasLength(1));
    expect(gamesGw.inserted.single['surrendered'], isFalse);
    expect(gamesGw.notified, isEmpty); // normal bitişte terk maili YOK
    expect(gamesGw.finishes.single['ended_by_surrender'], isFalse);

    // Çıkışta İKİNCİ bir kayıt açılmaz (recorded bayrağı).
    await tester.tap(find.byType(LogoMark));
    await tester.pumpAndSettle();
    expect(gamesGw.inserted, hasLength(1));
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
