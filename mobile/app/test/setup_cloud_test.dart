// Setup'ın GİRİŞLİ dalı — web'in `user && !creatingLocal` görünümü: bulut
// kayıt listesi varsayılan, kurulum formu "+ Yeni Yapay Zeka Oyunu Aç" ile
// açılır, VAZGEÇ listeye döner; satırdan devam AYNI sunucu satırını
// güncellemeye devam eder. Gateway sahte (bellek içi) — gerçek Supabase ucu
// cihazda doğrulanır.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/cloud_save_repo.dart';
import 'package:kelimeki/src/data/feedback_api.dart';
import 'package:kelimeki/src/data/games_api.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/game/logo_mark.dart';
import 'package:kelimeki/src/ui/game/dialog_shell.dart' show KDialogCard;
import 'package:kelimeki/src/ui/game/neo_button.dart';
import 'package:kelimeki/src/ui/game/count_badge.dart';
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart' show gameRow;
import 'support/real_io.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';
import 'package:kelimeki/src/util/online_status.dart';

class MemGateway implements CloudSaveGateway {
  final rows = <String, Map<String, Object?>>{};

  /// Kaç kez listelendi — öne dönüşte senkronun tetiklendiğini ölçmek için
  /// (Parça 44).
  int listCalls = 0;

  @override
  Future<List<Map<String, Object?>>> list() async {
    listCalls++;
    return [
        for (final e in rows.entries)
          {
            'id': e.key,
            'state': e.value['state'],
            'updated_at': e.value['updated_at'],
          }
    ];
  }

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

/// `flushPending`i sayan casus — GERÇEK `FeedbackRepo` sqflite'a bağlı ve
/// onun gerçek I/O'su testWidgets'ın sahte zaman bölgesinde çözülmez (bu
/// dosyanın diğer testleri bu yüzden depoyu hiç kurmuyor). Burada ölçülen
/// şey deponun kendisi değil KABLO: öne dönüşte flush ÇAĞRILIYOR mu.
class SpyFeedbackRepo extends FeedbackRepo {
  SpyFeedbackRepo() : super(null, Completer<AppStorage>().future);

  int flushCalls = 0;

  @override
  Future<int> flushPending() async {
    flushCalls++;
    return 0;
  }
}

/// `_syncCloud`'un liste ADIMINDAN sonra gelen bir çağrısı fırlarsa ekranın
/// kalıcı "Yükleniyor…"da kalmadığını kanıtlamak için (13 Ağustos 2026).
class ThrowingMirrorCountRepo extends CloudSaveRepo {
  ThrowingMirrorCountRepo(super.gateway);

  @override
  Future<int> pendingMirrorCount(String userId) async =>
      throw Exception('ayna sayacı patladı');
}

/// `_resumeCloudSave`ın oyunu açmadan ÖNCE aynayı sorup sormadığını ölçer
/// (Parça 105). Kararın kendisi `cloud_save_test.dart`ta repo katmanında
/// kanıtlanıyor; buradaki soru KABLO: Setup gerçekten soruyor mu ve dönen
/// state'i KULLANIYOR mu (Parça 86'nın dersi — bir sözleşmeyi enjekte
/// edilebilir sınırın ÜSTÜNDE test etmek, altındaki iletimi kanıtlamaz).
class FresherStateRepo extends CloudSaveRepo {
  FresherStateRepo(super.gateway, this.fresher);

  final GameState fresher;
  int calls = 0;

  @override
  Future<GameState?> newerPendingState(
      String id, String userId, int knownUpdatedAtMs) async {
    calls++;
    return fresher;
  }
}

AppServices services(MemGateway gw,
        {Future<GamesRepo>? games,
        FeedbackRepo? feedback,
        CloudSaveRepo? cloud}) =>
    AppServices(
      onlineStatus: OnlineStatus.fake(),
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: AuthService.fake(user: fakeUser(), profile: ironman),
      supabase: null,
      versionGate: VersionGateStatus.ok,
      cloudSaves: cloud ?? CloudSaveRepo(gw),
      games: games,
      feedback: feedback,
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
      {Future<GamesRepo>? games,
      FeedbackRepo? feedback,
      CloudSaveRepo? cloud}) async {
    await setPhoneViewSize(tester, const Size(420, 950));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: SetupScreen(
          services:
              services(gw, games: games, feedback: feedback, cloud: cloud)),
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
      theme: kelimekiTheme(),
      home: RepaintBoundary(key: key, child: SetupScreen(services: services(gw))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('+ YENİ YAPAY ZEKA OYUNU AÇ'), findsOneWidget);
    expect(find.text('DEVAM EDEN OYUNLAR'), findsOneWidget);
    expect(find.text('SIRA SENDE!'), findsOneWidget);
    expect(find.text('Sıra: Ironman'), findsOneWidget);
    // 30 Ağustos 2026: geri sayarken fiil ("teslim sayılacak"/"silinecek")
    // artık YOK, yalnızca "… KALDI" — üç sayaç da aynı kalıpta. Fiil yalnız
    // süre DOLDUĞUNDA ("Bugün …") geri geliyor.
    expect(find.textContaining('KALDI'), findsOneWidget);
    expect(find.textContaining('TESLİM SAYILACAK'), findsNothing);
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

  testWidgets(
      '"+ Yeni …" butonu ve alt sekme satırı web ölçüleriyle aynı (40/20/8/20)',
      (tester) async {
    // 13 Ağustos 2026, kullanıcı bildirdi: "yeni oyun aç butonu ile
    // altındaki devam edenler butonları arasındaki fark web'den daha dar".
    //
    // Web'de bu üç boşluğun HİÇBİRİ elle yazılmıyor — kapsayıcının
    // `gap-5`i (20) ve sekme satırının `gap-2`si (8) veriyor; butonun
    // yüksekliği de `text-sm` (14/20) + `py-2.5` (10+10) = 40. Port üçünü
    // de kendi sayılarıyla (12/6/12) yazmış ve butonu 44'lük bir
    // SizedBox'a sarmıştı. Derlenmiş CSS + Chromium'da ölçüldü:
    //   buton 40 · buton→sekme 20 · sekmeler arası 8 · sekme→içerik 20
    //
    // `LiveGamesTab`'daki ikizi AYNI değerleri kullanıyor (bilinçli kod
    // tekrarı çifti) — biri değişirse öteki de değişmeli.
    final gw = MemGateway();
    await pumpSetup(tester, gw);

    final buton = tester.getRect(
        find.widgetWithText(NeoButton, '+ YENİ YAPAY ZEKA OYUNU AÇ'));
    // Sekme KUTUSU (metin, kutunun 10px dolgusunun içinde ortalı — metin
    // kenarından boşluk ölçmek yanıltıcı olurdu).
    Rect kutu(String etiket) => tester.getRect(find
        .ancestor(of: find.text(etiket), matching: find.byType(Stack))
        .first);
    final sekme1 = kutu('DEVAM EDENLER');
    final sekme2 = kutu('SON OYNANANLAR');

    expect(buton.height, 40, reason: 'web text-sm (14/20) + py-2.5 = 40');
    expect(sekme1.top - buton.bottom, 20, reason: 'web gap-5 = 20');
    expect(sekme2.left - sekme1.right, 8, reason: 'web gap-2 = 8');
    expect(sekme1.height, closeTo(38.5, 1),
        reason: 'web py-2.5 (20) + satır 16.5 + çerçeve = 38.5');
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
      '"YAPAY ZEKA İLE" sekmesinin rozeti "Devam Edenler" ile AYNI sayı '
      '(kapsayan sekme = kapsananların toplamı)', (tester) async {
    final gw = MemGateway();
    await seedSave(gw, 'save-1');
    await seedSave(gw, 'save-2');
    await pumpSetup(tester, gw);

    // Rozet bir sekme butonunun KENDİ Stack'inde yaşıyor (yalnızca metnin
    // değil tüm kutunun üzerinde) — en yakın Stack atası o. `_ChoiceButton`
    // rozetsizken Stack'i hiç kurmuyor, yani "rozet yok" = Stack yok.
    int? badgeOf(String label) {
      final stack =
          find.ancestor(of: find.text(label), matching: find.byType(Stack));
      if (stack.evaluate().isEmpty) return null;
      final badge = find.descendant(
          of: stack.first, matching: find.byType(CountBadge));
      if (badge.evaluate().isEmpty) return null;
      return tester.widget<CountBadge>(badge.first).count;
    }

    // İkisi de 2 olmalı; alt sekmeninkini de ölçüyoruz ki "üstteki rozeti
    // ekledim" iddiası, ikisi ayrışsa da geçmesin.
    expect(badgeOf('DEVAM EDENLER'), 2);
    expect(badgeOf('YAPAY ZEKA İLE'), 2);
    await drainRealIo(tester);
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
    expect(find.text('SIRA SENDE!'), findsOneWidget);
    expect(find.text('SON OYNADIKLARIM'), findsNothing);

    // "Son Oynananlar"a geç — biten oyunun kartı gelir, devam eden oyunun
    // satırı artık EKRANDA DEĞİL (eskiden ikisi aynı anda, alt alta duruyordu).
    await tester.tap(find.text('SON OYNANANLAR'));
    await tester.pumpAndSettle();
    expect(find.text('SON OYNADIKLARIM'), findsOneWidget);
    expect(find.text('SIRA SENDE!'), findsNothing);

    // Geri dön.
    await tester.tap(find.text('DEVAM EDENLER'));
    await tester.pumpAndSettle();
    expect(find.text('SIRA SENDE!'), findsOneWidget);
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
    expect(find.text('SIRA SENDE!'), findsOneWidget);
    expect(find.text('SON OYNADIKLARIM'), findsNothing);
    await drainRealIo(tester);
  });

  testWidgets('satırdan devam: oyun açılır, autosave AYNI satırı günceller',
      (tester) async {
    final gw = MemGateway();
    final seeded = await seedSave(gw, 'save-1');
    await pumpSetup(tester, gw);

    await tester.tap(find.text('SIRA SENDE!'));
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
    expect(find.text('SIRA SENDE!'), findsOneWidget);
  });

  testWidgets('satırdan devam: aynada DAHA YENİ state varsa oyun ONUNLA '
      'açılır (bayat satır offline hamleleri silmez)', (tester) async {
    final gw = MemGateway();
    final seeded = await seedSave(gw, 'save-1');
    // Uçak modunda oynanmış, sunucuya yazılamamış hâl — listedeki satır
    // hâlâ eski (kullanıcı 16 Ağustos 2026 cihaz testinde bunu buldu).
    final fresher = seeded.copyWith(turnCount: seeded.turnCount + 3);
    final cloud = FresherStateRepo(gw, fresher);
    await pumpSetup(tester, gw, cloud: cloud);

    await tester.tap(find.text('SIRA SENDE!'));
    await tester.pumpAndSettle();
    expect(find.text('OYNA'), findsOneWidget);
    expect(cloud.calls, 1, reason: 'oyun açılmadan ÖNCE ayna sorulmalı');

    // CloudGameSession kurulur kurulmaz mevcut state'i yazar — satırda TAZE
    // tur sayısı olmalı; bayat state açılsaydı sunucu/ayna ezilirdi.
    await tester.pump(const Duration(milliseconds: 700));
    final saved = gameStateFromJson(
        (gw.rows['save-1']!['state'] as Map).cast<String, Object?>());
    expect(saved.turnCount, fresher.turnCount);
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
    await drainRealIo(tester);
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
    await drainRealIo(tester);
  });

  // Parça 60: "TEKRAR OYNA" aynı ekranda ikinci bir oyun başlatabiliyor —
  // `recorded` bayrağı ekran oturumu başına TEK SEFERLİK kalsaydı o oyun
  // hiç kaydedilmez, k-lig puanı sessizce kaybolurdu.
  testWidgets('TEKRAR OYNA: aynı ekranda İKİNCİ oyun da kaydedilir',
      (tester) async {
    final gw = MemGateway();
    final gamesGw = FakeGamesGateway(userId: 'u-test');
    final gamesRepo = await tester.runAsync(() => memGamesRepo(gamesGw));
    await pumpSetup(tester, gw, games: Future.value(gamesRepo));

    await tester.tap(find.text('+ YENİ YAPAY ZEKA OYUNU AÇ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();

    final controller =
        tester.widget<GameScreen>(find.byType(GameScreen)).controller;
    final names = [for (final p in controller.state.players) p.name];

    controller.restore(controller.state.copyWith(isGameOver: true));
    await tester.pumpAndSettle();
    expect(gamesGw.inserted, hasLength(1));

    // GameOver modalı + Görüş Bildir formu kapat, sonra TEKRAR OYNA.
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    if (find.byTooltip('Kapat').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('TEKRAR OYNA'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(KDialogCard), matching: find.widgetWithText(NeoButton, 'TEKRAR OYNA')));
    await tester.pumpAndSettle();

    // Aynı kadroyla TAZE bir oyun.
    expect(controller.state.isGameOver, isFalse);
    expect(controller.state.turnCount, 0);
    expect([for (final p in controller.state.players) p.name], names);

    controller.restore(controller.state.copyWith(isGameOver: true));
    await tester.pumpAndSettle();
    expect(gamesGw.inserted, hasLength(2),
        reason: 'İkinci oyun kaydedilmedi — `recorded` bayrağı yeni oyunda '
            'sıfırlanmıyor demektir (k-lig puanı sessizce kaybolur).');
    await drainRealIo(tester);
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

  testWidgets(
      'öne dönüşte bulut senkronu tazelenir — offline biriken ayna ağ '
      'gelince beklemez (Parça 44: web visibilitychange/focus/online '
      'dinleyicilerinin karşılığı hiç port edilmemişti)', (tester) async {
    final gw = MemGateway();
    await seedSave(gw, 'save-1');
    await pumpSetup(tester, gw);
    final before = gw.listCalls;
    expect(before, greaterThan(0), reason: 'mount senkronu zaten koşmalı');

    // Uygulama arka plana alınıp öne dönüyor (ağın geri gelmesiyle aynı an).
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    await tester.pumpAndSettle();

    expect(gw.listCalls, greaterThan(before),
        reason: 'resumed → _syncCloud (flush + liste) yeniden koşmalı');
  });

  testWidgets(
      'öne dönüşte geri bildirim kuyruğu da tazelenir (Parça 49: flush '
      'YALNIZCA initState\'teydi, Setup hiç unmount olmadığından uygulama '
      'yeniden başlatılana kadar bekliyordu)', (tester) async {
    final gw = MemGateway();
    final spy = SpyFeedbackRepo();
    await pumpSetup(tester, gw, feedback: spy);
    expect(spy.flushCalls, 1, reason: 'mount flush\'ı zaten koşuyordu');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(spy.flushCalls, 2,
        reason: 'resumed → flushPending yeniden çağrılmalı');
  });
  testWidgets(
      'senkronun bir adımı fırlasa da liste ÇİZİLİR — "Yükleniyor…" terminal '
      'durum DEĞİL', (tester) async {
    // 13 Ağustos 2026, cihazda bildirildi: "Ironman YZ tabına geçince
    // Yükleniyor takılı kaldı." Hesabın SIFIR bulut kaydı vardı, yani
    // başarılı bir liste boş liste dönmeliydi ve ekranda "Devam eden bir
    // Yapay Zeka oyunun yok." yazmalıydı.
    //
    // Kök sebep yapısal: web'de misafir migrasyonu / kuyruk flush'ı /
    // liste ÜÇ AYRI effect; port hepsini `_syncCloud`ta ardışık koşturuyor
    // ve aradaki korumasız bir `await` fırlarsa fonksiyon yarıda kesilip
    // `_cloudSaves` sonsuza dek null kalıyordu (üstelik çağrı `unawaited`
    // olduğundan hata da görünmüyordu).
    final gw = MemGateway(); // hiç satır yok — boş liste beklenir
    await pumpSetup(tester, gw, cloud: ThrowingMirrorCountRepo(gw));

    expect(find.text('Yükleniyor…'), findsNothing,
        reason: 'bir adım fırlasa da liste çizilmeli');
    expect(find.text('Devam eden bir Yapay Zeka oyunun yok.'), findsOneWidget);
  });

}
