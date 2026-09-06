// Bitmiş/terk edilmiş oyun kayıtları (parça 3b).
//
// EN ÖNEMLİ TEST: `web_game_record.json` fikstürü, web'in ÜRETİM
// `buildGameRecord`/`serializeBoardSnapshot` kodu tohumlu bir oyunla
// koşturularak üretildi (id/saat sabitlenmiş). Dart portu AYNI girdi
// state'inden AYNI `games` satırını üretmek zorunda — golden vector
// disiplininin bu katmandaki karşılığı.
//
// Kalan testler dayanıklılık politikasını sınar: 23505 idempotency'si,
// misafir kuyruğu → giriş sonrası flush, terk bildiriminin YALNIZCA
// gerçek ilk insert'te gitmesi, turnCount<2 eşiği.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/game_record.dart';
import 'package:kelimeki/src/data/games_api.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/storage/local_save_store.dart' show abandonTimeout;
import 'package:kelimeki/src/storage/pending_queue_store.dart';
import 'package:kelimeki/src/util/platform.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_games_gateway.dart';

late int clock;

Future<PendingQueueStore> openQueue() async {
  SharedPreferences.setMockInitialValues({});
  final storage = await AppStorage.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    prefs: await SharedPreferences.getInstance(),
    nowMs: () => clock,
  );
  return storage.queue;
}

const fixedId = '11111111-2222-3333-4444-555555555555';
final fixedNow = DateTime.utc(2026, 8, 6, 12);

Future<GamesRepo> newRepo(FakeGamesGateway gw) async => GamesRepo(
      gw,
      await openQueue(),
      newId: () => fixedId,
      now: () => fixedNow,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() => clock = fixedNow.millisecondsSinceEpoch);

  late Map<String, Object?> fixture;
  setUpAll(() {
    fixture = (jsonDecode(
            File('test/fixtures/web_game_record.json').readAsStringSync())
        as Map)
        .cast<String, Object?>();
  });

  /// Fikstürdeki bir senaryonun state'ini + beklenen satırını çıkarır.
  (GameState, Map<String, Object?>) scenario(String name) {
    final s = (fixture[name] as Map).cast<String, Object?>();
    return (
      gameStateFromJson((s['state'] as Map).cast<String, Object?>()),
      (s['record'] as Map).cast<String, Object?>(),
    );
  }

  /// `platform` HARİÇ karşılaştırma — o alan, satırdaki TEK bilinçli
  /// istemci farkı (web `'web'`, port ios/android/app-web) ve zaten
  /// varlık sebebi bu. Kalan 20 sütun hâlâ bayt bayt eşleşmek zorunda;
  /// alanın kendisi aşağıda AYRICA doğrulanıyor (iki taraf da yazmalı,
  /// değerler kısıtın izin verdiği kümede olmalı ve BİRBİRİNDEN farklı
  /// olmalı — aksi halde port web'in sabitini kopyalamış olurdu).
  void expectSameRowExceptPlatform(
      NewGameRecord record, Map<String, Object?> expected) {
    final actual = record.toJson();
    expect(actual.containsKey('platform'), isTrue,
        reason: 'port platformu yazmıyor — lansman ölçülemez kalır');
    expect(expected.containsKey('platform'), isTrue,
        reason: 'fikstür bayat: web artık platform yazıyor, yeniden üret');
    expect(kClientPlatforms, contains(actual['platform']));
    expect(kClientPlatforms, contains(expected['platform']));
    expect(actual['platform'], isNot(expected['platform']));
    expect(jsonEncode({...actual}..remove('platform')),
        jsonEncode({...expected}..remove('platform')));
  }

  group('buildGameRecord ↔ web üretim kodu (fikstür karşılaştırması)', () {
    test('normal biten oyun: satır BİREBİR aynı', () {
      final (state, expected) = scenario('finishedNormal');
      final record = buildGameRecord(state,
          surrendered: false, newId: () => fixedId, now: () => fixedNow);
      expect(record, isNotNull);
      expectSameRowExceptPlatform(record!, expected);
      // Fikstürün gerçekten zengin olduğunun kanıtı (boş bir tahta
      // karşılaştırması bir şey ispatlamazdı).
      expect(record.boardSnapshot.length, greaterThan(90));
      expect(record.boardSnapshot.where((t) => t.w).isNotEmpty, isTrue);
      expect(record.result, GameResult.win);
    });

    test('terk edilme (surrenderingIndex: 0): satır BİREBİR aynı', () {
      final (state, expected) = scenario('abandonedSurrender');
      final record = buildGameRecord(state,
          surrendered: true,
          surrenderingIndex: 0,
          newId: () => fixedId,
          now: () => fixedNow);
      expect(record, isNotNull);
      expectSameRowExceptPlatform(record!, expected);
      // Teslim olan oyuncu 0 puanla EN SONA düşer (rankPlayers kuralı) ve
      // sonuç her zaman 'lose' (rank'tan bağımsız).
      expect(record.result, GameResult.lose);
      expect(record.playerScore, 0);
      expect(record.players.last.surrendered, isTrue);
      expect(record.players.last.colorIndex, 0);
      expect(record.rank, 4);
    });

    test('ai_level (ROADMAP #23 Faz 4): Kolay state → satırda `kolay`; '
        'Normal/eski state → anahtar HİÇ yok (web gameRecord.ts sözleşmesi)',
        () {
      final (state, expected) = scenario('finishedNormal');
      // Fikstür seviyesiz — web de Normal'de alanı yazmıyor; yukarıdaki
      // bayt-bayt karşılaştırma bunu zaten kilitliyor, burada açıkça:
      expect(expected.containsKey('ai_level'), isFalse);
      final normal = buildGameRecord(state,
          surrendered: false, newId: () => fixedId, now: () => fixedNow)!;
      expect(normal.toJson().containsKey('ai_level'), isFalse);

      final kolay = buildGameRecord(state.copyWith(aiLevel: AiLevel.kolay),
          surrendered: false, newId: () => fixedId, now: () => fixedNow)!;
      final json = kolay.toJson();
      expect(json['ai_level'], 'kolay');
      // Kuyruk gidiş-dönüşü (misafir → giriş sonrası flush) seviyeyi korur.
      expect(NewGameRecord.fromJson(json).aiLevel, AiLevel.kolay);
      expect(NewGameRecord.fromJson(normal.toJson()).aiLevel, isNull);
      // Seviye dışında satır AYNI — seviye puanı sunucuda/kartta hesaplanır,
      // kayda başka hiçbir şey eklemez.
      expect(jsonEncode({...json}..remove('ai_level')),
          jsonEncode(normal.toJson()));
    });

    test('1. koltuk YZ ise kayıt üretilmez (motor testi/geçersiz kadro)', () {
      final (state, _) = scenario('finishedNormal');
      final aiFirst = state.copyWith(players: [
        state.players[0].copyWith(isAI: true),
        ...state.players.sublist(1),
      ]);
      expect(
          buildGameRecord(aiFirst,
              surrendered: false, newId: () => fixedId, now: () => fixedNow),
          isNull);
    });
  });

  group('GamesRepo dayanıklılığı', () {
    test('girişli: kayıt anında gider, kuyruğa girmez', () async {
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      final (state, _) = scenario('finishedNormal');
      await repo.recordFinished(state);
      expect(gw.inserted, hasLength(1));
      expect(gw.inserted.single['user_id'], 'u-1');
      expect(await repo.queue.count(finishedGameKind), 0);
      // Anonim telemetri de gitti (web logGameFinish).
      expect(gw.finishes.single['player_count'], 2);
      expect(gw.finishes.single['ended_by_surrender'], false);
    });

    test('misafir: kayıt kuyrukta bekler, giriş sonrası flush hesaba işler',
        () async {
      final gw = FakeGamesGateway(); // userId null → misafir
      final repo = await newRepo(gw);
      final (state, _) = scenario('finishedNormal');
      await repo.recordFinished(state);
      expect(gw.inserted, isEmpty);
      expect(await repo.queue.count(finishedGameKind), 1);

      // Hâlâ misafir: flush ağa HİÇ dokunmaz.
      expect(await repo.flushPending(), 0);
      expect(await repo.queue.count(finishedGameKind), 1);

      // Giriş yapıldı → kuyruk boşalır.
      gw.userId = 'u-1';
      expect(await repo.flushPending(), 1);
      expect(gw.inserted, hasLength(1));
      expect(await repo.queue.count(finishedGameKind), 0);
    });

    test('ağ hatası kuyrukta bırakır; tekrar denemede 23505 başarı sayılır',
        () async {
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      final (state, _) = scenario('finishedNormal');

      gw.failNextInsert = true;
      await repo.recordFinished(state);
      expect(gw.inserted, isEmpty);
      expect(await repo.queue.count(finishedGameKind), 1);

      // Aslında sunucuya ULAŞMIŞ ama yanıtı kaybolmuş bir kayıt senaryosu:
      // satırı elle ekleyip flush'ı çalıştır — 23505 dalı başarı sayılmalı,
      // ikinci satır AÇILMAMALI, kayıt kuyruktan düşmeli.
      gw.inserted.add(const {'id': fixedId});
      expect(await repo.flushPending(), 1);
      expect(gw.inserted, hasLength(1));
      expect(await repo.queue.count(finishedGameKind), 0);
    });

    test('terk bildirimi YALNIZCA gerçek ilk insert\'te gider', () async {
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      final (state, _) = scenario('abandonedSurrender');

      await repo.recordAbandoned(state, endedAtMs: clock);
      expect(gw.inserted, hasLength(1));
      expect(gw.notified, hasLength(1));
      expect(gw.notified.single.playerCount, 4);
      expect(gw.finishes.single['ended_by_surrender'], true);

      // Aynı kaydı tekrar göndermek (kuyruktan retry) İKİNCİ mail göndermez.
      final record = NewGameRecord.fromJson(
          (fixture['abandonedSurrender'] as Map)['record'] as Map<String, Object?>);
      await repo.saveDurable(record);
      expect(gw.inserted, hasLength(1));
      expect(gw.notified, hasLength(1)); // hâlâ tek
    });

    // ⚠ 4 Eylül 2026, sahada görüldü: terk kaydı SÜPÜRMENİN koştuğu ana
    // damgalanıyordu, sürenin dolduğu ana değil. Kullanıcı uygulamayı bir
    // hafta sonra açtığında bir haftalık terkler hep "bugün"e düşüyordu —
    // bir hesapta 19 kayıt tek bir saniyeye indi ve panelde "dün 38 teslim"
    // diye göründü. Doğru an: son etkinlik + abandonTimeout (7 gün).
    test('terk kaydı SÜPÜRME anına değil, sürenin DOLDUĞU ana yazılır',
        () async {
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      final (state, _) = scenario('abandonedSurrender');

      // Oyuna son dokunuş 30 gün önce; yani süre 23 gün önce doldu.
      // Süpürme ise ŞİMDİ (fixedNow) koşuyor.
      final sonEtkinlik =
          fixedNow.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      final beklenen = sonEtkinlik + abandonTimeout.inMilliseconds;

      await repo.recordAbandoned(state, endedAtMs: sonEtkinlik);

      // (a) Telemetri satırı
      expect(gw.finishes.single['finished_at_ms'], beklenen,
          reason: 'game_finishes süpürme anına yazılıyor');
      // (b) `games` satırı — ikisi AYNI anı taşımalı, yoksa iki tablo farklı
      //     güne düşer ve panel ile oyun geçmişi birbirini tutmaz.
      expect(gw.inserted.single['created_at'],
          DateTime.fromMillisecondsSinceEpoch(beklenen).toUtc().toIso8601String(),
          reason: 'games satırı süpürme anına yazılıyor');
      // (c) Ve bu an GERÇEKTEN geçmişte: 23 gün önce.
      expect(DateTime.parse(gw.inserted.single['created_at'] as String)
          .isBefore(fixedNow), isTrue);
    });

    test('normal bitişte terk bildirimi GİTMEZ', () async {
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      final (state, _) = scenario('finishedNormal');
      await repo.recordFinished(state);
      expect(gw.notified, isEmpty);
    });

    test('turnCount<2 terk: ne ceza ne telemetri (web eşiği)', () async {
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      final (state, _) = scenario('abandonedSurrender');
      await repo.recordAbandoned(state.copyWith(turnCount: 1),
          endedAtMs: clock);
      expect(gw.inserted, isEmpty);
      expect(gw.finishes, isEmpty);
      expect(await repo.queue.count(finishedGameKind), 0);
    });

    test('1. koltuk zaten teslim olmuşsa normal bitiş TEKRAR kaydetmez',
        () async {
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      final (state, _) = scenario('finishedNormal');
      final surrendered = state.copyWith(players: [
        state.players[0].copyWith(surrendered: true),
        ...state.players.sublist(1),
      ]);
      await repo.recordFinished(surrendered);
      expect(gw.inserted, isEmpty);
      expect(gw.finishes, isEmpty);
    });

    test('oyun süresi startedAt ile bitiş anından hesaplanır', () async {
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      final (state, _) = scenario('abandonedSurrender');
      final started = DateTime.utc(2026, 8, 1, 12);
      await repo.recordAbandoned(
        state.copyWith(startedAt: started.toIso8601String()),
        endedAtMs:
            started.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      );
      expect(gw.finishes.single['duration_seconds'], 7200);
    });

    test('logStart: başlangıç sayacı gider ve HATA OYUNU ETKİLEMEZ', () async {
      // ROADMAP #9 — `game_starts`. Web `logGameStart` paritesi.
      final gw = FakeGamesGateway(userId: 'u-1');
      final repo = await newRepo(gw);
      await repo.logStart(playerCount: 4);
      expect(gw.starts.single['player_count'], 4);

      // Best-effort duruş: gateway fırlatsa bile `logStart` fırlatmamalı —
      // telemetri hiçbir koşulda oyun başlatmayı düşüremez.
      final patlak = _ThrowingStartGateway();
      final repo2 = GamesRepo(patlak, await openQueue(),
          newId: () => fixedId, now: () => fixedNow);
      await expectLater(repo2.logStart(playerCount: 2), completes);
    });
  });
}

/// `logGameStart` fırlatan sahte uç — yalnızca yukarıdaki dayanıklılık
/// kontrolü için.
class _ThrowingStartGateway extends FakeGamesGateway {
  @override
  Future<void> logGameStart({required int playerCount}) async =>
      throw Exception('ağ hatası');
}
