// Bulut kayıt senkronu (CloudSaveRepo/CloudGameSession/misafir migrasyonu)
// testleri — sahte bir CloudSaveGateway ile TÜM politika katmanı gerçek
// akışla sınanır; gerçek Supabase ucu (SupabaseCloudSaveGateway) cihazda
// doğrulanır. Web davranış paritesi: debounce'lu autosave aynı satırı
// günceller, oyun bitince satır silinir, turnCount<2 çıkışı iz bırakmaz,
// bitmiş/play-dışı satırlar fırsatçı temizlenir, süresi dolmuş satır
// listeye girmez ama SİLİNMEZ (ceza üretimi 3b'nin işi), yazma-okuma
// yarışı TableWriteQueue ile kapalı, misafir kaydı isim düzeltmesiyle
// hesaba taşınır.
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

  /// Yavaş silme — yazma-okuma yarışını görünür kılmak için (kuyruk yoksa
  /// liste, silme sunucuda işlenmeden dönebilirdi).
  bool slowDelete = false;

  @override
  Future<List<Map<String, Object?>>> list() async {
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
    expect(list!.single.id, 'id-1');
    // Kanonik codec üzerinden birebir aynı state (golden disipliniyle aynı
    // karşılaştırma biçimi).
    expect(jsonEncode(gameStateToJson(list.single.state)),
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
    expect(list, isEmpty);
  });

  test('bitmiş/play-dışı satır fırsatçı temizlenir', () async {
    final (repo, gw) = newRepo();
    final finished = newPlayState().copyWith(isGameOver: true);
    await repo.upsert('done', 'user-1', finished);
    final list = await repo.list();
    expect(list, isEmpty);
    await repo.idle;
    expect(gw.rows, isEmpty); // satır gerçekten silindi
  });

  test('süresi dolmuş satır listeye girmez ama SİLİNMEZ (süpürme 3b)',
      () async {
    final (repo, gw) = newRepo();
    await repo.upsert('stale', 'user-1', newPlayState());
    clock += const Duration(days: 8).inMilliseconds;
    final list = await repo.list();
    expect(list, isEmpty);
    await repo.idle;
    expect(gw.rows.containsKey('stale'), isTrue); // ceza kanıtı sunucuda durur
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
    expect(list!.single.id, 'good');
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
}
