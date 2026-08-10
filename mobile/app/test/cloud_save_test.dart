// Bulut kayıt senkronu (CloudSaveRepo/CloudGameSession/misafir migrasyonu)
// testleri — sahte bir CloudSaveGateway ile TÜM politika katmanı gerçek
// akışla sınanır; gerçek Supabase ucu (SupabaseCloudSaveGateway) cihazda
// doğrulanır. Web davranış paritesi: debounce'lu autosave aynı satırı
// günceller, oyun bitince satır silinir, turnCount<2 çıkışı iz bırakmaz,
// bitmiş/play-dışı satırlar fırsatçı temizlenir, süresi dolmuş satır
// atomik olarak iddia edilip silinir (cezaya çevirme GamesRepo'nun işi),
// yazma-okuma yarışı TableWriteQueue ile kapalı, misafir kaydı isim
// düzeltmesiyle hesaba taşınır.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/cloud_save_repo.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/game/local_game_repo.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late SetWordSource words;
late int clock;

class FakeGateway implements CloudSaveGateway {
  final rows = <String, Map<String, Object?>>{};
  int upsertCalls = 0;
  bool failNextUpsert = false;

  /// Kalıcı ağ kesintisi (uçak modu) — upsert VE list boyunca fırlatır.
  bool offline = false;

  /// Yavaş silme — yazma-okuma yarışını görünür kılmak için (kuyruk yoksa
  /// liste, silme sunucuda işlenmeden dönebilirdi).
  bool slowDelete = false;

  @override
  Future<List<Map<String, Object?>>> list() async {
    if (offline) throw Exception('ağ yok');
    final list = rows.entries
        .map((e) => <String, Object?>{
              'id': e.key,
              'state': e.value['state'],
              'updated_at': e.value['updated_at'],
            })
        .toList()
      ..sort((a, b) =>
          (b['updated_at'] as String).compareTo(a['updated_at'] as String));
    return list;
  }

  @override
  Future<void> upsert(String id, String userId,
      Map<String, Object?> stateJson, int playerCount) async {
    upsertCalls++;
    if (offline) throw Exception('ağ yok');
    if (failNextUpsert) {
      failNextUpsert = false;
      throw Exception('ağ hatası');
    }
    rows[id] = {
      'state': stateJson,
      'user_id': userId,
      'player_count': playerCount,
      'updated_at':
          DateTime.fromMillisecondsSinceEpoch(clock, isUtc: true).toIso8601String(),
    };
  }

  @override
  Future<void> delete(String id) async {
    if (slowDelete) await Future<void>.delayed(const Duration(milliseconds: 20));
    rows.remove(id);
  }

  /// Gerçek uçtaki atomik `delete().lt(updated_at, cutoff).select('state')`
  /// taklidi: satır hâlâ eskiyse siler ve state'ini döner, aksi halde null.
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

Future<AppStorage> openTestStorage() async {
  SharedPreferences.setMockInitialValues({});
  return AppStorage.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    prefs: await SharedPreferences.getInstance(),
    nowMs: () => clock,
  );
}

GameController newController() =>
    GameController(words: words, autoPlayAi: false, nowIso: () => '');

GameState newPlayState({String name = 'Misafir'}) {
  final c = newController();
  c.dispatch(StartAction([
    PlayerSetup(name: name, isAI: false),
    const PlayerSetup(name: 'Yapay Zeka 2', isAI: true),
  ]));
  return c.state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    final f = File('assets/dictionary/words_tr.txt');
    words = SetWordSource(const LineSplitter()
        .convert(f.readAsStringSync())
        .where((w) => w.isNotEmpty));
  });

  setUp(() {
    clock = DateTime.utc(2026, 8, 6).millisecondsSinceEpoch;
  });

  (CloudSaveRepo, FakeGateway) newRepo() {
    final gw = FakeGateway();
    return (CloudSaveRepo(gw, nowMs: () => clock), gw);
  }

  test('upsert → list gidiş-dönüşü: state kanonik JSON ile korunur', () async {
    final (repo, gw) = newRepo();
    final state = newPlayState();
    expect(await repo.upsert('id-1', 'user-1', state), isTrue);
    final list = await repo.list();
    expect(list, isNotNull);
    expect(list!.saves.single.id, 'id-1');
    // Kanonik codec üzerinden birebir aynı state (golden disipliniyle aynı
    // karşılaştırma biçimi).
    expect(jsonEncode(gameStateToJson(list.saves.single.state)),
        jsonEncode(gameStateToJson(state)));
    expect(gw.rows['id-1']!['player_count'], 2);
    expect(gw.rows['id-1']!['user_id'], 'user-1');
  });

  test('yazma-okuma yarışı: silme kuyruktayken liste silinmişi göstermez',
      () async {
    final (repo, gw) = newRepo();
    await repo.upsert('id-1', 'user-1', newPlayState());
    gw.slowDelete = true;
    // ignore: unawaited_futures — kasıtlı: silme uçuştayken hemen listele.
    repo.delete('id-1');
    final list = await repo.list(); // kuyruk boşalana kadar beklemeli
    expect(list!.saves, isEmpty);
  });

  test('bitmiş/play-dışı satır fırsatçı temizlenir', () async {
    final (repo, gw) = newRepo();
    final finished = newPlayState().copyWith(isGameOver: true);
    await repo.upsert('done', 'user-1', finished);
    final list = await repo.list();
    expect(list!.saves, isEmpty);
    await repo.idle;
    expect(gw.rows, isEmpty); // satır gerçekten silindi
  });

  test('süresi dolmuş satır iddia edilip silinir, abandoned listesine düşer',
      () async {
    final (repo, gw) = newRepo();
    final state = newPlayState();
    await repo.upsert('stale', 'user-1', state);
    clock += const Duration(days: 8).inMilliseconds;
    final list = await repo.list();
    expect(list!.saves, isEmpty); // devam eden listede YOK
    expect(list.abandoned, hasLength(1));
    expect(jsonEncode(gameStateToJson(list.abandoned.single.state)),
        jsonEncode(gameStateToJson(state)));
    await repo.idle;
    expect(gw.rows, isEmpty); // satır iddia edilip silindi

    // İkinci tarama (ör. başka bir cihaz aynı anda süpürdü) hiçbir şey
    // üretmez — ceza İKİ KEZ uygulanamaz.
    final again = await repo.list();
    expect(again!.abandoned, isEmpty);
  });

  test('çözülemeyen satır atlanır, sunucudan silinmez', () async {
    final (repo, gw) = newRepo();
    gw.rows['bad'] = {
      'state': {'garbage': 1},
      'updated_at':
          DateTime.fromMillisecondsSinceEpoch(clock, isUtc: true).toIso8601String(),
    };
    await repo.upsert('good', 'user-1', newPlayState());
    final list = await repo.list();
    expect(list!.saves.single.id, 'good');
    await repo.idle;
    expect(gw.rows.containsKey('bad'), isTrue); // web istemcisi için geçerli olabilir
  });

  test('upsert hatası yutulur (false), kuyruk kilitlenmez', () async {
    final (repo, gw) = newRepo();
    gw.failNextUpsert = true;
    expect(await repo.upsert('a', 'u', newPlayState()), isFalse);
    expect(await repo.upsert('a', 'u', newPlayState()), isTrue);
  });

  test('CloudGameSession: autosave tek satırı günceller, debounce birleştirir',
      () async {
    final (repo, gw) = newRepo();
    final controller = newController();
    final session = CloudGameSession(controller, repo, 'user-1',
        debounce: const Duration(milliseconds: 30));
    controller.dispatch(const StartAction([
      PlayerSetup(name: 'Ironman', isAI: false),
      PlayerSetup(name: 'Yapay Zeka 2', isAI: true),
    ]));
    // Art arda iki değişiklik — debounce dolmadan TEK upsert'e birleşmeli.
    controller.dispatch(const SelectTileAction(0));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await repo.idle;
    expect(gw.upsertCalls, 1);
    expect(gw.rows.length, 1);
    final id = session.saveId!;
    // Yeni değişiklik AYNI satırı günceller (web activeSaveIdRef).
    controller.dispatch(const SelectTileAction(1));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await repo.idle;
    expect(gw.rows.length, 1);
    expect(session.saveId, id);
    session.detach();
  });

  test('CloudGameSession: oyun bitince satır silinir', () async {
    final (repo, gw) = newRepo();
    final controller = newController();
    final session = CloudGameSession(controller, repo, 'user-1',
        debounce: Duration.zero);
    controller.dispatch(const StartAction([
      PlayerSetup(name: 'Ironman', isAI: false),
      PlayerSetup(name: 'Yapay Zeka 2', isAI: true),
    ]));
    await Future<void>.delayed(Duration.zero);
    await repo.idle;
    expect(gw.rows.length, 1);
    // Bitmiş hâle geçiş (kayıttan dönmüş gibi) — satır silinmeli.
    controller.restore(controller.state.copyWith(isGameOver: true));
    await session.end();
    expect(gw.rows, isEmpty);
    expect(session.saveId, isNull);
  });

  test('end(): turnCount<2 iz bırakmaz — bekleyen upsert de iptal', () async {
    final (repo, gw) = newRepo();
    final controller = newController();
    final session = CloudGameSession(controller, repo, 'user-1',
        debounce: Duration.zero);
    controller.dispatch(const StartAction([
      PlayerSetup(name: 'Ironman', isAI: false),
      PlayerSetup(name: 'Yapay Zeka 2', isAI: true),
    ]));
    await Future<void>.delayed(Duration.zero);
    await repo.idle;
    expect(gw.rows.length, 1); // autosave yazdı
    await session.end(); // turnCount 0 — web handleLogoClick kuralı
    expect(gw.rows, isEmpty);
  });

  test('end(): turnCount>=2 satırı bırakır ve bekleyen yazmayı flush eder',
      () async {
    final (repo, gw) = newRepo();
    final controller = newController();
    // Uzun debounce — end() anında hâlâ bekleyen bir yazma olsun.
    final session = CloudGameSession(controller, repo, 'user-1',
        debounce: const Duration(seconds: 30));
    controller.dispatch(const StartAction([
      PlayerSetup(name: 'Ironman', isAI: false),
      PlayerSetup(name: 'Yapay Zeka 2', isAI: true),
    ]));
    controller.dispatch(const PassAction());
    controller.dispatch(const AiPlayAction());
    expect(controller.state.turnCount, greaterThanOrEqualTo(2));
    await session.end();
    expect(gw.rows.length, 1);
    final saved = gameStateFromJson(
        (gw.rows.values.single['state'] as Map).cast<String, Object?>());
    expect(saved.turnCount, controller.state.turnCount); // EN GÜNCEL state
  });

  test('resumeSaveId: sunucudan devam aynı satırı günceller, yenisini açmaz',
      () async {
    final (repo, gw) = newRepo();
    final state = newPlayState(name: 'Ironman');
    await repo.upsert('existing', 'user-1', state);
    final controller = newController();
    final session = CloudGameSession(controller, repo, 'user-1',
        resumeSaveId: 'existing', debounce: Duration.zero);
    controller.restore(state);
    await Future<void>.delayed(Duration.zero);
    await repo.idle;
    expect(gw.rows.length, 1);
    expect(gw.rows.containsKey('existing'), isTrue);
    expect(session.saveId, 'existing');
    session.detach();
  });

  test('misafir migrasyonu: isim düzeltilir, slot yalnız başarıda temizlenir',
      () async {
    final (repo, gw) = newRepo();
    final storage = await openTestStorage();
    final guestRepo = LocalGameRepo(storage);
    final controller = newController();
    final guestSession = guestRepo.attach(controller);
    controller.dispatch(const StartAction([
      PlayerSetup(name: 'Misafir', isAI: false),
      PlayerSetup(name: 'Yapay Zeka 2', isAI: true),
    ]));
    controller.dispatch(const PassAction());
    controller.dispatch(const AiPlayAction());
    await guestSession.end();
    expect(await guestRepo.hasSave(), isTrue);

    // Ağ hatası: slot DOKUNULMADAN kalır, sonraki denemede tekrar taşınır.
    gw.failNextUpsert = true;
    expect(
        await repo.migrateGuestSave(
            guestRepo: guestRepo, userId: 'user-1', accountName: 'Ironman'),
        isFalse);
    expect(await guestRepo.hasSave(), isTrue);
    expect(gw.rows, isEmpty);

    // Başarılı taşıma: 1. oyuncu hesap adını alır ("Sıra: Misafir" kalıcı
    // kalmasın — web 1 Ağustos 2026 düzeltmesi), slot temizlenir.
    expect(
        await repo.migrateGuestSave(
            guestRepo: guestRepo, userId: 'user-1', accountName: 'Ironman'),
        isTrue);
    expect(await guestRepo.hasSave(), isFalse);
    final uploaded = gameStateFromJson(
        (gw.rows.values.single['state'] as Map).cast<String, Object?>());
    expect(uploaded.players[0].name, 'Ironman');
    expect(uploaded.players[1].name, 'Yapay Zeka 2'); // YZ adı dokunulmaz

    // Slot boşken tekrar çağrı no-op.
    expect(
        await repo.migrateGuestSave(
            guestRepo: guestRepo, userId: 'user-1', accountName: 'Ironman'),
        isFalse);
    expect(gw.rows.length, 1);
  });

  // ——— Parça 38: offline dayanıklılık (kullanıcı 9 Ağustos 2026 cihaz
  // testinde buldu — girişliyken uçak modunda oynanan hamleler sessizce
  // kayboluyor, ağ dönünce sunucudaki son senkron state'e geri düşülüyordu).

  Future<(CloudSaveRepo, FakeGateway, AppStorage)> newMirroredRepo() async {
    final gw = FakeGateway();
    final storage = await openTestStorage();
    return (
      CloudSaveRepo(gw,
          nowMs: () => clock,
          mirrorStore: Future.value(storage.cloudMirror),
          cacheStore: Future.value(storage.cloudCache)),
      gw,
      storage
    );
  }

  test('offline oynanan hamleler KAYBOLMAZ: ayna sunucudakini bindirir',
      () async {
    final (repo, gw, storage) = await newMirroredRepo();
    final online = newPlayState();
    expect(await repo.upsert('id-1', 'user-1', online), isTrue);

    // Uçak modu: sonraki hamleler sunucuya gidemiyor.
    gw.offline = true;
    clock += 60000;
    final offlineState = online.copyWith(turnCount: online.turnCount + 3);
    expect(await repo.upsert('id-1', 'user-1', offlineState), isFalse);

    // Ağ döndü ama henüz flush edilmedi: liste AYNAYI göstermeli.
    gw.offline = false;
    final list = await repo.list(userId: 'user-1');
    expect(list!.saves.single.state.turnCount, offlineState.turnCount,
        reason: 'offline hamleler listede görünmeli');
    await storage.db.close();
  });

  test('ağ dönünce ayna sunucuya itilir ve temizlenir', () async {
    final (repo, gw, storage) = await newMirroredRepo();
    gw.offline = true;
    final state = newPlayState();
    expect(await repo.upsert('id-1', 'user-1', state), isFalse);
    expect(gw.rows, isEmpty);
    expect((await storage.cloudMirror.pending('user-1')).length, 1);

    gw.offline = false;
    expect(await repo.flushMirrored('user-1'), 1);
    expect(gw.rows.containsKey('id-1'), isTrue);
    expect(await storage.cloudMirror.pending('user-1'), isEmpty,
        reason: 'sunucuya yazılan ayna silinmeli');
    await storage.db.close();
  });

  test('tamamen offline açılan oyun listede görünür (sunucu onu hiç görmedi)',
      () async {
    final (repo, gw, storage) = await newMirroredRepo();
    gw.offline = true;
    await repo.upsert('id-yeni', 'user-1', newPlayState());
    // Parça 43'e kadar burada `null` dönüyordu (kullanıcı uçak modunda
    // Setup'a dönünce oyunu listede GÖREMİYORDU) — artık ayna listeye
    // biniyor, oyun offline'da da görünüyor.
    final list = await repo.list(userId: 'user-1');
    expect(list!.saves.single.id, 'id-yeni',
        reason: 'offline: yalnızca aynada olan oyun da listelenmeli');
    expect(list.abandoned, isEmpty);

    gw.offline = false; // liste alınabiliyor ama satır yok
    final list2 = await repo.list(userId: 'user-1');
    expect(list2!.saves.single.id, 'id-yeni');
    await storage.db.close();
  });

  test(
      'taze ayna, sunucudaki eski satırın HAKSIZ yere terk sayılmasını '
      'engeller (mükerrer/yanlış -2 önlemi)', () async {
    final (repo, gw, storage) = await newMirroredRepo();
    final state = newPlayState();
    await repo.upsert('id-1', 'user-1', state);

    // Sunucu satırı 8 gün eskiyor…
    clock += const Duration(days: 8).inMilliseconds;
    // …ama kullanıcı DÜN offline oynadı: ayna taze.
    gw.offline = true;
    await repo.upsert('id-1', 'user-1', state.copyWith(turnCount: 9));
    gw.offline = false;

    final list = await repo.list(userId: 'user-1');
    expect(list!.abandoned, isEmpty,
        reason: 'taze aynası olan oyun terk sayılmamalı');
    expect(list.saves.single.state.turnCount, 9);
    await storage.db.close();
  });

  test(
      '10 gün sonra dönüş: bekleyen ayna 7 gün cezasını ATLATMAZ '
      '(kullanıcı senaryosu — oyunu aç, interneti kapat, 10 gün sonra gel)',
      () async {
    final (repo, gw, storage) = await newMirroredRepo();
    final state = newPlayState();
    await repo.upsert('id-1', 'user-1', state); // online: sunucuda satır var

    // İnternet kapandı, birkaç hamle daha yapıldı, uygulama kapandı.
    gw.offline = true;
    await repo.upsert('id-1', 'user-1', state.copyWith(turnCount: 5));
    gw.offline = false;

    // 10 gün sonra internetle açılış: önce flush, sonra liste (Setup sırası).
    clock += const Duration(days: 10).inMilliseconds;
    await repo.flushMirrored('user-1');
    final list = await repo.list(userId: 'user-1');

    expect(list!.abandoned, hasLength(1),
        reason: '10 gün dönülmedi — ceza uygulanmalı');
    expect(list.saves, isEmpty);
    // Ayna temizlenmeli: aksi halde sonraki açılışta oyun DİRİLİRDİ.
    expect(await storage.cloudMirror.pending('user-1'), isEmpty);
    final again = await repo.list(userId: 'user-1');
    expect(again!.saves, isEmpty, reason: 'cezalandırılan oyun geri gelmemeli');
    expect(again.abandoned, isEmpty, reason: 'ceza İKİ KEZ uygulanmamalı');
    await storage.db.close();
  });

  test('sunucunun hiç görmediği (tamamen offline) oyun da 7 günde cezalanır',
      () async {
    final (repo, gw, storage) = await newMirroredRepo();
    gw.offline = true;
    await repo.upsert('id-yalniz-ayna', 'user-1', newPlayState());
    gw.offline = false;

    clock += const Duration(days: 10).inMilliseconds;
    await repo.flushMirrored('user-1');
    final list = await repo.list(userId: 'user-1');
    expect(list!.abandoned, hasLength(1));
    expect(list.saves, isEmpty);
    expect(gw.rows, isEmpty, reason: 'süresi dolmuş ayna sunucuya İTİLMEMELİ');
    expect(await storage.cloudMirror.pending('user-1'), isEmpty);
    await storage.db.close();
  });

  // ——— Parça 43: offline'da liste boş görünüyordu (kullanıcı 10 Ağustos
  // 2026 cihaz testinde buldu — veri güvendeydi ama uçak modunda Setup'a
  // dönünce oyun "Devam Eden Oyunlar"da yoktu, kaybolmuş gibi duruyordu).

  test('offline liste ÖNBELLEKTEN çizilir: offline oynanmamış oyunlar da kalır',
      () async {
    final (repo, gw, storage) = await newMirroredRepo();
    final a = newPlayState();
    expect(await repo.upsert('id-a', 'user-1', a), isTrue);
    expect(await repo.upsert('id-b', 'user-1', newPlayState()), isTrue);
    // Başarılı listeleme önbelleği doldurur.
    expect((await repo.list(userId: 'user-1'))!.saves, hasLength(2));

    gw.offline = true;
    final offlineState = a.copyWith(turnCount: a.turnCount + 3);
    expect(await repo.upsert('id-a', 'user-1', offlineState), isFalse);

    final list = await repo.list(userId: 'user-1');
    expect(list, isNotNull, reason: 'offline: önbellek+ayna ile çizilmeli');
    expect(list!.saves.map((s) => s.id).toSet(), {'id-a', 'id-b'},
        reason: 'yalnızca aynayı göstermek id-b\'yi listeden düşürürdü');
    expect(list.saves.firstWhere((s) => s.id == 'id-a').state.turnCount,
        offlineState.turnCount,
        reason: 'ayna önbellekten YENİ: offline hamleler görünmeli');
    expect(list.abandoned, isEmpty);
    await storage.db.close();
  });

  test('offline listede CEZA uygulanmaz; süresi geçmiş satır da gösterilmez',
      () async {
    final (repo, gw, storage) = await newMirroredRepo();
    expect(await repo.upsert('id-eski', 'user-1', newPlayState()), isTrue);
    expect((await repo.list(userId: 'user-1'))!.saves, hasLength(1));

    clock += const Duration(days: 10).inMilliseconds;
    gw.offline = true;
    final list = await repo.list(userId: 'user-1');
    expect(list!.abandoned, isEmpty,
        reason: 'sunucuyla doğrulanmadan -2 yazılamaz (claim yarışı yok)');
    expect(list.saves, isEmpty,
        reason: 'bir sonraki çevrimiçi listelemede silinecek oyuna devam '
            'ettirmeyelim');

    // Ağ dönünce ceza normal yoldan uygulanmalı — offline dal onu YUTMAMALI.
    gw.offline = false;
    final online = await repo.list(userId: 'user-1');
    expect(online!.abandoned, hasLength(1));
    await storage.db.close();
  });

  test('silme önbelleği de temizler (offline silinen oyun listede kalmaz)',
      () async {
    final (repo, gw, storage) = await newMirroredRepo();
    expect(await repo.upsert('id-1', 'user-1', newPlayState()), isTrue);
    expect((await repo.list(userId: 'user-1'))!.saves, hasLength(1));

    gw.offline = true;
    await repo.delete('id-1');
    expect((await repo.list(userId: 'user-1'))!.saves, isEmpty);
    await storage.db.close();
  });
}
