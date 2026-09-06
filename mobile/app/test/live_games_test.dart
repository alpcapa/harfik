// Canlı oyun davet/kabul parçası — kova filtreleri (inviteBucket'ın
// `status == pending` şartı dahil — web 4 Ağustos 2026 hayalet-davet dersi),
// süre etiketleri (enjekte nowMs), OnlineGamesRepo'nun "hafif süpürme" +
// null-hata sözleşmeleri (sahte gateway), LiveGamesTab widget akışları
// (varsayılan alt sekme, Kabul → FriendSuggestModal, durum/kalan süre
// etiketleri) ve LiveGameCreateForm kuralları (2/4, YZ onayı, sentTo).
// Gerçek RPC'ler/Realtime cihazda doğrulanacak (mobile/TESTING.md).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/neo_box.dart';
import 'package:kelimeki/src/ui/text_scale.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/tokens.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/error_reporter.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/ui/live/live_game_create_form.dart';
import 'package:kelimeki/src/ui/devam_eden_govde.dart';
import 'package:kelimeki/src/ui/live/live_games_tab.dart';
import 'package:kelimeki/src/ui/game/player_avatar_row.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show SetWordSource, trUpper;

import 'package:kelimeki/src/data/push_repo.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'push_repo_test.dart' show FakeMessaging, FakeStore;
import 'package:kelimeki/src/data/analytics.dart';
import 'support/fake_analytics.dart';
import 'support/fake_online_gateway.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'package:kelimeki/src/util/offline_notice.dart';

class _FakeErrorSink implements ClientErrorSink {
  final List<Map<String, Object?>> sent = [];
  @override
  Future<void> send(Map<String, Object?> record) async => sent.add(record);
}

/// `isNetworkError`'a düşen gerçek bir kalıp (bkz. util/offline_notice.dart).
class _FakeNetworkError implements Exception {
  @override
  String toString() => 'ClientException: Failed host lookup: kelimeki.com';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  // Sabit "şimdi" — 2026-08-07 12:00 UTC.
  final nowMs = DateTime.utc(2026, 8, 7, 12).millisecondsSinceEpoch;
  String iso(DateTime d) => d.toUtc().toIso8601String();

  group('kova filtreleri', () {
    test('inviteBucket: status==pending ŞART (hayalet davet dersi)', () {
      final games = [
        game(gameRow(
            id: 'g1',
            myId: 'me',
            status: 'pending',
            myInviteStatus: 'pending',
            myInviteId: 'i1')),
        // check_invite_expiry oyunu abandoned'a çekti ama game_invites satırı
        // hâlâ pending — bu şart olmadan davet listede sonsuza dek kalırdı.
        game(gameRow(
            id: 'g2',
            myId: 'me',
            status: 'abandoned',
            myInviteStatus: 'pending',
            myInviteId: 'i2')),
        // Kurucunun kendi oyunu davet kovasına girmez.
        game(gameRow(
            id: 'g3', myId: 'me', status: 'pending', myRole: 'creator')),
      ];
      expect([for (final g in inviteBucket(games)) g.id], ['g1']);
      expect([for (final g in waitingBucket(games)) g.id], ['g3']);
    });

    test('activeBucket: sıra bende olanlar üstte, indeks tie-break kararlı',
        () {
      final games = [
        for (final id in ['a', 'b', 'c', 'd'])
          game(gameRow(id: id, myId: 'me', status: 'active')),
      ];
      // Kendi koltuğum indeks 1 (slots[1].relation == 'self').
      final turns = {'a': 0, 'b': 1, 'c': 1, 'd': 0};
      expect([for (final g in activeBucket(games, turns)) g.id],
          ['b', 'c', 'a', 'd']);
      expect(myTurnCount(games, turns), 2);
    });

    test('activeBucket: gruplar TERS yönde sıralanır (turn_deadline)', () {
      // ⚠ ASİMETRİ BİLİNÇLİ ve bu test onun tek bekçisi. İki ayrı kullanıcı
      // isteğinin kesişimi:
      //   31 Ağustos: "son oynanan her zaman en üstte olacak"
      //    3 Eylül  : "sıra sende bekleyenlerde bitmeye en yakın üstte"
      // Çözüm: sıra BENDE artan (en yakın teslim üstte — yapacak iş var),
      // sıra RAKİPTE azalan (son oynanan üstte — yapabileceğim yok).
      // Kural `util/game_list_order.dart`ta, web ikizi `gameListOrder.ts`;
      // vakaların tamamı `game_list_order_test.dart` + o dosyanın web
      // doğrulama betiğinde.
      //
      // `turn_deadline` her hamlede `now() + 48 saat` olur → geç deadline =
      // son oynanan, erken deadline = teslime en yakın.
      final games = [
        for (final id in ['a', 'b', 'c', 'd'])
          game(gameRow(id: id, myId: 'me', status: 'active')),
      ];
      final turns = {'a': 0, 'b': 1, 'c': 1, 'd': 0};
      final deadlines = <String, String?>{
        'a': '2026-09-01T10:00:00Z', // sıra rakipte, EN YENİ
        'b': '2026-09-01T08:00:00Z', // sıra bende, EN YAKIN teslim
        'c': '2026-09-01T09:00:00Z', // sıra bende, daha uzak
        'd': '2026-09-01T07:00:00Z', // sıra rakipte, en eski
      };
      expect(
          [for (final g in activeBucket(games, turns, deadlines: deadlines)) g.id],
          ['b', 'c', 'a', 'd'],
          reason: 'sıra bende: b(08:00) → c(09:00) ARTAN · '
              'sıra rakipte: a(10:00) → d(07:00) AZALAN. '
              'İki grubu aynı yöne çevirmek isteklerden BİRİNİ bozar.');
      // Deadline verilmezse geliş sırası korunur (hepsi null → tie-break).
      expect([for (final g in activeBucket(games, turns)) g.id],
          ['b', 'c', 'a', 'd']);
    });

    test('activeBucket: deadline BİLİNMEYEN oyun grubunun EN SONUNA düşer',
        () {
      // ⚠ Sessiz tuzağın negatif eşi: null eskiden 0 sayılıyordu ve bu
      // yalnızca AZALAN sıralamada zararsızdı. "Sıra bende" grubu 3 Eylül'de
      // ARTANA çevrilince 0, "en yakın teslim" sanılıp EN ÜSTE çıkardı.
      final games = [
        for (final id in ['bilinmiyor', 'yakin'])
          game(gameRow(id: id, myId: 'me', status: 'active')),
      ];
      final turns = {'bilinmiyor': 1, 'yakin': 1}; // ikisi de sıra bende
      final deadlines = <String, String?>{
        'bilinmiyor': null,
        'yakin': '2026-09-01T08:00:00Z',
      };
      expect(
          [for (final g in activeBucket(games, turns, deadlines: deadlines)) g.id],
          ['yakin', 'bilinmiyor']);
    });

    test('acceptedWaitingBucket: kabul ettim ama oyun hâlâ pending', () {
      final games = [
        game(gameRow(
            id: 'g1',
            myId: 'me',
            playerCount: 4,
            status: 'pending',
            myInviteStatus: 'accepted')),
        game(gameRow(
            id: 'g2', myId: 'me', status: 'active',
            myInviteStatus: 'accepted')),
      ];
      expect([for (final g in acceptedWaitingBucket(games)) g.id], ['g1']);
    });
  });

  group('süre etiketleri (enjekte nowMs)', () {
    test('remainingTimeLabel: saat/dakika, acil eşiği, süresi dolmuş', () {
      expect(remainingTimeLabel(null, nowMs), isNull);

      final in30h = iso(DateTime.utc(2026, 8, 8, 18)); // 30 saat sonra
      var l = remainingTimeLabel(in30h, nowMs)!;
      expect(l.text, '30 saat 0 dk sonra teslim (-2 puan)');
      expect(l.urgent, isFalse);

      final in90m = iso(DateTime.utc(2026, 8, 7, 13, 30));
      l = remainingTimeLabel(in90m, nowMs)!;
      expect(l.text, '1 saat 30 dk sonra teslim (-2 puan)');
      expect(l.urgent, isTrue);

      final in5m = iso(DateTime.utc(2026, 8, 7, 12, 5));
      l = remainingTimeLabel(in5m, nowMs)!;
      expect(l.text, '5 dk sonra teslim (-2 puan)');

      l = remainingTimeLabel(iso(DateTime.utc(2026, 8, 7, 11)), nowMs)!;
      expect(l.text, 'Süresi doldu - teslim oldu');
      expect(l.urgent, isTrue);
    });

    test('remainingInviteLabel: gün/saat, acil eşiği, süresi dolmuş', () {
      // 3 gün önce açıldı → 4 gün 0 saat kaldı.
      var l = remainingInviteLabel(iso(DateTime.utc(2026, 8, 4, 12)), nowMs);
      expect(l.text, '4 gün 0 saat kaldı');
      expect(l.urgent, isFalse);

      // 6 gün 22 saat önce → 2 saat 0 dakika kaldı, acil.
      l = remainingInviteLabel(iso(DateTime.utc(2026, 7, 31, 14)), nowMs);
      expect(l.text, '2 saat 0 dakika kaldı');
      expect(l.urgent, isTrue);

      // 8 gün önce → süresi dolmuş.
      l = remainingInviteLabel(iso(DateTime.utc(2026, 7, 30, 12)), nowMs);
      expect(l.text, 'Süresi doldu');
      expect(l.urgent, isTrue);
    });
  });

  group('OnlineGamesRepo', () {
    test('load: liste + aktif oyunların sıra/son-tarih eşlemesi', () async {
      final gw = FakeOnlineGamesGateway()
        ..rows = [
          gameRow(id: 'g1', myId: 'me', status: 'active'),
          gameRow(
              id: 'g2',
              myId: 'me',
              status: 'pending',
              myRole: 'creator',
              createdAt: iso(DateTime.utc(2026, 8, 6))),
        ]
        ..turnRows = [
          {'online_game_id': 'g1', 'current': 1},
        ]
        ..deadlineRows = [
          {
            'online_game_id': 'g1',
            'turn_deadline': iso(DateTime.utc(2026, 8, 9)),
          },
        ];
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs);
      final snap = (await repo.load())!;
      expect(snap.games, hasLength(2));
      expect(snap.turns, {'g1': 1});
      expect(snap.deadlines['g1'], iso(DateTime.utc(2026, 8, 9)));
      expect(gw.listCalls, 1); // süresi dolan yok — ikinci fetch yok
      expect(gw.turnTimeoutChecks, isEmpty);
      expect(gw.inviteExpiryChecks, isEmpty);
    });

    test('load: süresi dolmuş davet/sıra süpürülür + liste yeniden çekilir',
        () async {
      final gw = FakeOnlineGamesGateway();
      gw
        ..rows = [
          // 8 gün önce açılmış, hâlâ pending davet → check_invite_expiry.
          gameRow(
              id: 'inv',
              myId: 'me',
              status: 'pending',
              myInviteStatus: 'pending',
              myInviteId: 'i1',
              createdAt: iso(DateTime.utc(2026, 7, 30))),
          // Süresi geçmiş sıra → check_turn_timeout.
          gameRow(id: 'act', myId: 'me', status: 'active'),
        ]
        ..deadlineRows = [
          {
            'online_game_id': 'act',
            'turn_deadline': iso(DateTime.utc(2026, 8, 7, 11)),
          },
        ]
        ..turnRows = [
          {'online_game_id': 'act', 'current': 0},
        ]
        // Sunucu etkisi: süpürme oyunları kapatır.
        ..onCheckInviteExpiry = (id) {
          gw.rows = [
            for (final r in gw.rows)
              if (r['id'] == id) {...r, 'status': 'abandoned'} else r
          ];
        }
        ..onCheckTurnTimeout = (id) {
          gw.rows = [
            for (final r in gw.rows)
              if (r['id'] == id) {...r, 'status': 'finished'} else r
          ];
        };
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs);
      final snap = (await repo.load())!;
      expect(gw.inviteExpiryChecks, ['inv']);
      expect(gw.turnTimeoutChecks, ['act']);
      expect(gw.listCalls, 2); // süpürme sonrası ikinci fetch
      expect(inviteBucket(snap.games), isEmpty);
      expect(activeBucket(snap.games, snap.turns), isEmpty);
    });

    test('load: ağ hatasında null (UI eski listeyi korur)', () async {
      final gw = FakeOnlineGamesGateway()..failWith = Exception('ağ');
      expect(await OnlineGamesRepo(gw, nowMs: () => nowMs).load(), isNull);
    });

    // 21 Ağustos 2026 vakası: ağ değişiminde (WiFi↔hücresel) yarıda kalan
    // istek boş liste gibi okunuyor, kullanıcıya sırası kendisindeyken
    // "Devam eden bir Canlı oyunun yok." deniyordu. Gecikme enjekte
    // ediliyor — testler gerçek zamanlayıcı beklemesin (bekleyen-timer
    // flake sınıfı).
    Future<void> noDelay(Duration _) async {}

    test('load: yarıda kalan İLK istek sessizce tekrarlanır', () async {
      final gw = FakeOnlineGamesGateway()
        ..netFailFirst = 1
        ..rows = [gameRow(id: 'g1', myId: 'me', status: 'active')]
        ..turnRows = [
          {'online_game_id': 'g1', 'current': 0},
        ];
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs, delay: noDelay);
      final snap = await repo.load();
      expect(snap, isNotNull, reason: 'düşen istek boş liste gibi okunmamalı');
      expect(snap!.games, hasLength(1));
      expect(gw.listCalls, 2, reason: 'bir kez tekrar denendi');
    });

    test('load: iki ardışık ağ hatası da tekrarlanır', () async {
      final gw = FakeOnlineGamesGateway()
        ..netFailFirst = 2
        ..rows = [gameRow(id: 'g1', myId: 'me', status: 'active')]
        ..turnRows = [
          {'online_game_id': 'g1', 'current': 0},
        ];
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs, delay: noDelay);
      expect((await repo.load())!.games, hasLength(1));
      expect(gw.listCalls, 3);
    });

    test('load: üç deneme de düşerse null — uydurma boş liste YOK', () async {
      final gw = FakeOnlineGamesGateway()..netFailFirst = 99;
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs, delay: noDelay);
      expect(await repo.load(), isNull);
      expect(gw.listCalls, 3, reason: 'merdiven 2 gecikme + son deneme');
    });

    test('load: sunucunun KENDİ reddi tekrarlanMAZ', () async {
      // Kapsam bilerek dar: yetki/kural reddini tekrarlamak yalnızca
      // gecikme üretir, sonucu değiştirmez.
      final gw = FakeOnlineGamesGateway()
        ..failWith = Exception('Yalnızca arkadaşlarını davet edebilirsin.');
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs, delay: noDelay);
      expect(await repo.load(), isNull);
      expect(gw.listCalls, 1);
    });

    test('subscribe: kanal kopup yeniden bağlanınca tazeleme sinyali gelir',
        () async {
      // Kopuk kanal olay YAYINLAMAZ ve kopukken olanları sonradan
      // oynatMAZ — yeniden bağlanmanın kendisi tek kurtarma sinyali.
      final gw = FakeOnlineGamesGateway();
      var yenidenBaglandi = 0;
      gw.subscribe(() {}, onResubscribe: () => yenidenBaglandi++);
      expect(gw.lastOnResubscribe, isNotNull,
          reason: 'tüketici kancayı GERÇEKTEN geçmeli');
      gw.lastOnResubscribe!();
      expect(yenidenBaglandi, 1);
    });

    test('create: RPC + notify fire-and-forget (bildirim hatası yutulur)',
        () async {
      final gw = FakeOnlineGamesGateway()..notifyFailWith = Exception('brevo');
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs);
      final id = await repo.create(2, const [
        NewGameSlot.human('me'),
        NewGameSlot.human('f1'),
      ]);
      expect(id, 'new-game');
      expect(gw.createdCounts, [2]);
      expect(gw.createdSlots.single, [
        {'type': 'human', 'user_id': 'me'},
        {'type': 'human', 'user_id': 'f1'},
      ]);
      // Bildirim hatası create'i düşürmedi (davet zaten sunucuda açıldı).
      await Future<void>.delayed(Duration.zero);
      expect(gw.notified, isEmpty);
    });

    test(
        'pendingCounts: bekleyen davet + sırası bende olan aktif oyun toplamı '
        '(web fetchPendingLiveGameCounts) — Setup rozetinin kaynağı',
        () async {
      final gw = FakeOnlineGamesGateway()
        ..rows = [
          gameRow(
              id: 'inv',
              myId: 'me',
              status: 'pending',
              myRole: 'invitee',
              myInviteStatus: 'pending',
              myInviteId: 'i1'),
          gameRow(id: 'mine', myId: 'me', status: 'active'),
          gameRow(id: 'theirs', myId: 'me', status: 'active'),
        ]
        ..turnRows = [
          {'online_game_id': 'mine', 'current': 1}, // 'me' 2. koltukta
          {'online_game_id': 'theirs', 'current': 0}, // rakibin sırası
        ];
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs);
      final counts = (await repo.pendingCounts())!;
      expect(counts.inviteCount, 1);
      expect(counts.myTurnCount, 1);
    });

    // 21 Ağustos 2026: 0/0 DEĞİL null. 0/0 dönmek yalnızca rozeti silmiyor,
    // çağıranın TEK SEFERLİK giriş kararını da tüketiyordu.
    test('pendingCounts: ağ hatasında null (giriş kararı tüketilmez)',
        () async {
      final gw = FakeOnlineGamesGateway()..failWith = Exception('ağ');
      final repo = OnlineGamesRepo(gw, nowMs: () => nowMs);
      expect(await repo.pendingCounts(), isNull);
    });

    // Giriş varsayılanı — web `decideInitialMainView` ile ELLE SENKRON.
    // Kullanıcının bildirdiği vaka (21 Ağustos 2026): hesapta 0 YZ oyunu ve
    // 6 aktif Canlı oyun, hiçbirinde sıra kendisinde değil → uygulama her
    // açılışta BOŞ "Yapay Zeka ile" sekmesiyle karşılıyordu.
    test('decideInitialMainView: kurallar + "henüz karar verme" hâli', () {
      PendingLiveGameCounts say(int davet, int sira, int aktif) =>
          PendingLiveGameCounts(davet, sira, aktif);

      expect(decideInitialMainView(say(0, 1, 3), const []),
          InitialMainView.live);
      expect(decideInitialMainView(say(1, 0, 0), const [1, 2]),
          InitialMainView.live,
          reason: 'bekleyen davet, YZ oyunu olsa bile');
      expect(decideInitialMainView(say(0, 0, 6), const []),
          InitialMainView.live,
          reason: 'YZ boş + Canlı oyun var → sıra bende olmasa bile');
      expect(decideInitialMainView(say(0, 0, 6), const [1]),
          InitialMainView.local,
          reason: 'YZ oyunu VAR → sekme kaçırılmaz');
      expect(decideInitialMainView(say(0, 0, 0), const []),
          InitialMainView.local);

      // Eksik veri: karar ERTELENİR (local DEĞİL) — aksi halde tek seferlik
      // karar yanıp kullanıcı kalıcı olarak yanlış sekmede kalırdı.
      expect(decideInitialMainView(null, const []), isNull);
      expect(decideInitialMainView(say(0, 0, 6), null), isNull);
      // ⚠ Ama kural (1) YZ listesini BEKLEMEZ — beklemek gerçek bir
      // regresyon üretti (setup_screen_test'teki iki test yakaladı).
      expect(decideInitialMainView(say(0, 1, 3), null), InitialMainView.live);
      expect(decideInitialMainView(say(2, 0, 0), null), InitialMainView.live);
    });

    // Aynı vakanın ikinci dersi: hata SESSİZ kaldı. `load()` yalnızca
    // `debugPrint`liyordu, bu yüzden teşhis `client_errors`ta değil elle
    // SQL koşarak yapıldı. Ağ hatası hâlâ elenmeli (çevrimdışı kullanıcı
    // her açılışta buraya düşer) — iki dal da burada.
    // Negatif eş: `errorReporter.report` satırı silinirse ilk expect,
    // `isNetworkError` koşulu silinirse ikincisi düşer.
    test('load: ayrıştırma hatası TELEMETRİYE düşer, ağ hatası DÜŞMEZ',
        () async {
      final sink = _FakeErrorSink();
      errorReporter.resetForTests();
      errorReporter.configure(sink: sink, anonId: Future.value('anon-1'));
      addTearDown(errorReporter.resetForTests);

      final gw = FakeOnlineGamesGateway()
        // Sözleşme bozulması: `player_count` hiç yok → fromJson fırlatır.
        ..rows = [
          {...gameRow(id: 'g1', myId: 'me')}..remove('player_count'),
        ];
      expect(await OnlineGamesRepo(gw, nowMs: () => nowMs).load(), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sink.sent, hasLength(1));
      expect(sink.sent.single['message'],
          contains('online_games_repo.load'));

      sink.sent.clear();
      final agGw = FakeOnlineGamesGateway()
        ..failWith = _FakeNetworkError();
      expect(
          await OnlineGamesRepo(agGw,
                  nowMs: () => nowMs, delay: (_) async {})
              .load(),
          isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sink.sent, isEmpty, reason: 'çevrimdışılık gürültü olur');
    });

    // 26 Ağustos 2026 — GERÇEK CİHAZDA yaşandı, kayda değer: hesap silme
    // kaskadı `online_games.created_by`i `on delete set null` yaptı, yani
    // kurucusu hesabını silmiş bir oyun NULL `created_by` ile dönüyor.
    // `OnlineGame.fromJson` o alanı `as String` ile okuduğu için satır
    // FIRLATIYOR, `load()` de hatayı yutup null döndürdüğünden ÜÇ alt sekme
    // birden "Oyunların şu an yüklenemedi." gösteriyordu — 43 oyunun 41'i
    // sapasağlamken. Tekrar denemek de çare değildi: hata deterministik.
    // Negatif eş: `createdBy` tipi `String`e geri çevrilirse bu test düşer.
    test('load: kurucusu silinmiş oyun (created_by NULL) listeyi DÜŞÜRMEZ',
        () async {
      final gw = FakeOnlineGamesGateway()
        ..rows = [
          gameRow(id: 'g1', myId: 'me', status: 'active'),
          gameRow(id: 'g2', myId: 'me', status: 'finished', createdBy: null),
        ];
      final snap = await OnlineGamesRepo(gw, nowMs: () => nowMs).load();
      expect(snap, isNotNull, reason: 'tek satır yüzünden liste düşmemeli');
      expect(snap!.games, hasLength(2));

      final silinmis = snap.games.firstWhere((g) => g.id == 'g2');
      expect(silinmis.createdBy, isNull);
      // Kurucu koltuğu bulunamaz — ama koltuğun kendisi (uuid'siyle) duruyor.
      expect(silinmis.creatorSlot, isNull);
      expect(silinmis.slots, hasLength(2));
      // Null == null tuzağı: adı/uuid'si olmayan bir koltuk "Davet gönderen"
      // etiketi ALMAMALI.
      expect(participantLabel(silinmis.slots.first, silinmis), 'Bekliyor');
    });

  });

  // ── Widget testleri ───────────────────────────────────────────────────────

  AppServices liveServices({
    required String userId,
    required FakeOnlineGamesGateway gateway,
    FakeFriendsGateway? friendsGateway,
    bool online = true,
    PushMessaging? pushMessaging,
    PushRepo? push,
    Future<AppStorage>? storage,
  }) =>
      AppServices(
        onlineStatus: OnlineStatus.fake(online: online),
        dictionary: Future.value(SetWordSource(const [])),
        meanings: MeaningStore(bundle: rootBundle),
        auth: AuthService.fake(user: fakeUser(userId)),
        supabase: null,
        versionGate: VersionGateStatus.ok,
        onlineGames: OnlineGamesRepo(gateway),
        friends: FriendsRepo(friendsGateway ?? FakeFriendsGateway()),
        pushMessaging: pushMessaging,
        push: push,
        storage: storage,
      );

  Future<void> pumpTab(WidgetTester tester, AppServices s,
      {GlobalKey? boundaryKey,
      List<String> newlyFinishedIds = const [],
      VoidCallback? onFinishesSeen}) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    Widget body = SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: LiveGamesTab(
          services: s,
          newlyFinishedIds: newlyFinishedIds,
          onFinishesSeen: onFinishesSeen ?? () {},
        ));
    if (boundaryKey != null) {
      body = RepaintBoundary(
          key: boundaryKey, child: ColoredBox(color: Colors.white, child: body));
    }
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(body: body),
    ));
    await tester.pump();
    await tester.pump();
  }

  group('LiveGamesTab', () {
    // Çevrimdışı mesajı ANINDA çıkmalı — bir ağ çağrısının düşmesini
    // BEKLEMEDEN. Portta karar önce `_loadFailed`e bağlıydı ve uçak modunda
    // (Supabase auth'un token yenileme tekrarları yüzünden) saniyeler
    // sürüyordu; kullanıcı "hemen çıkmalı" dedi (14 Ağustos 2026).
    // Burada sahte uç HİÇ CEVAP VERMİYOR (asılı future) — yani test ancak
    // karar bağlantı sinyalinden geliyorsa geçer.
    // Negatif eş: `!services.onlineStatus.online` koşulu kaldırılırsa düşer.
    testWidgets('çevrimdışıyken mesaj ağ cevabı BEKLENMEDEN çıkar',
        (tester) async {
      final gw = FakeOnlineGamesGateway()..listHangs = true;
      final s = liveServices(userId: 'me', gateway: gw, online: false);
      await pumpTab(tester, s);
      expect(find.text(kOfflineNoConnection), findsOneWidget);
      expect(find.text('Yükleniyor…'), findsNothing);
    });

    // 21 Ağustos 2026: bağlantı ÇALIŞIRKEN yükleme düşerse "İnternet
    // bağlantısı yok" demek YANLIŞ bilgi (kullanıcı kararı) — başka bir
    // sayfaya girip çalıştığını gören kişi uygulamaya güvenmez.
    // Negatif eş: `_loadFailed` dalı yine `kOfflineNoConnection` gösterirse
    // ilk iki expect birden düşer.
    testWidgets('bağlantı varken yükleme düşerse "internet yok" DEMEZ',
        (tester) async {
      final gw = FakeOnlineGamesGateway()..failWith = Exception('sunucu');
      final s = liveServices(userId: 'me', gateway: gw, online: true);
      await pumpTab(tester, s);
      await tester.pump();
      expect(find.text(kOfflineNoConnection), findsNothing);
      expect(find.text(kLoadFailedNotice), findsOneWidget);
      expect(find.text(trUpper(kRetryLabel)), findsOneWidget);
      // Bekleyen otomatik denemeyi bırakma (bekleyen-timer flake sınıfı).
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // Yukarıdaki repo testinin KULLANICIYA GÖRÜNEN yüzü: liste gerçekten
    // çiziliyor mu, yoksa "yüklenemedi" mi? (26 Ağustos 2026 vakasında
    // kullanıcının gördüğü tek şey buydu.) Ad yerine `?? 'Bir arkadaşın'`
    // düşmesi de burada kanıtlanıyor.
    testWidgets('kurucusu silinmiş oyun listede ÇİZİLİR ("yüklenemedi" değil)',
        (tester) async {
      final gw = FakeOnlineGamesGateway()
        ..rows = [
          gameRow(
              id: 'g1',
              myId: 'me',
              status: 'pending',
              createdBy: null,
              myInviteStatus: 'pending',
              myInviteId: 'i1'),
        ];
      final s = liveServices(userId: 'me', gateway: gw, online: true);
      await pumpTab(tester, s);
      await tester.pump();
      expect(find.text(kLoadFailedNotice), findsNothing);
      expect(find.textContaining('Bir arkadaşın'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('elde liste varken tazeleme düşerse liste KALIR + bayat notu',
        (tester) async {
      final gw = FakeOnlineGamesGateway()
        ..rows = [gameRow(id: 'g1', myId: 'me', status: 'active')]
        ..turnRows = [
          {'online_game_id': 'g1', 'current': 1},
        ];
      final s = liveServices(userId: 'me', gateway: gw, online: true);
      await pumpTab(tester, s);
      await tester.pump();
      expect(find.text('Devam eden bir Canlı oyunun yok.'), findsNothing);
      expect(find.text(trUpper(kStaleDataNotice)), findsNothing);

      // Şimdi tazeleme düşsün — liste ekranda KALMALI. Tetikleyici gerçek
      // yol: Realtime olayı → 300ms debounce → _reload.
      gw.failWith = Exception('sunucu');
      gw.lastOnChange!();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text(trUpper(kStaleDataNotice)), findsOneWidget);
      expect(find.text(kLoadFailedNotice), findsNothing);
      expect(find.text(kOfflineNoConnection), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'varsayılan alt sekme: bekleyen davet varsa Oyun Davetleri + rozet + '
        'ekran görüntüsü', (tester) async {
      final gw = FakeOnlineGamesGateway()
        ..rows = [
          gameRow(
              id: 'g1',
              myId: 'u-tab1',
              playerCount: 4,
              status: 'pending',
              myInviteStatus: 'pending',
              myInviteId: 'i1',
              createdAt: iso(DateTime.now().toUtc()),
              slots: [
                slotHuman('esiner', name: 'Esiner', relation: 'accepted'),
                slotHuman('u-tab1', name: 'Ironman', relation: 'self',
                    inviteStatus: 'pending'),
                slotHuman('bobola', name: 'Bobola', inviteStatus: 'accepted'),
                slotAi,
              ]),
        ];
      final key = GlobalKey();
      await pumpTab(tester, liveServices(userId: 'u-tab1', gateway: gw),
          boundaryKey: key);

      // Davet kovası dolu → "Oyun Davetleri" sekmesi kendiliğinden açık.
      expect(
          find.text('Esiner seni 4 kişilik oyuna davet etti'), findsOneWidget);
      expect(find.text('KABUL ET'), findsOneWidget);
      expect(find.text('REDDET'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // sekme rozeti (CountBadge)
      // Katılımcı listesi: durum etiketleri + YZ satırı.
      expect(find.text('DAVET GÖNDEREN'), findsOneWidget);
      expect(find.text('KABUL ETTİ'), findsOneWidget);
      expect(find.text('BEKLİYOR'), findsOneWidget);
      expect(find.text('Yapay Zeka'), findsOneWidget);

      // Etiketin RENGİ (kullanıcı isteği, 30 Ağustos 2026): cevap veren
      // yeşil, cevap bekleyen kırmızı, kurucu nötr. Web ikizi
      // `participantLabelClass` (LiveGamesTab.tsx) ile aynı dal sırası.
      // Negatif eş: `_participantLabelColor` kaldırılıp `_muted` sabitine
      // dönülürse ilk iki satır düşer.
      Color etiketRengi(String etiket) =>
          tester.widget<Text>(find.text(etiket)).style!.color!;
      expect(etiketRengi('KABUL ETTİ'), kGreen);
      expect(etiketRengi('BEKLİYOR'), kRed);
      expect(etiketRengi('DAVET GÖNDEREN'), kMuted);

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/screenshots/live_games.png');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });

    testWidgets(
        'Kabul → respondInvite + FriendSuggestModal (yalnız arkadaş olmayanlar)',
        (tester) async {
      final fgw = FakeFriendsGateway(currentUserId: 'u-tab2');
      final gw = FakeOnlineGamesGateway();
      gw.rows = [
        gameRow(
            id: 'g1',
            myId: 'u-tab2',
            playerCount: 4,
            status: 'pending',
            myInviteStatus: 'pending',
            myInviteId: 'i1',
            createdAt: iso(DateTime.now().toUtc()),
            slots: [
              slotHuman('esiner', name: 'Esiner', relation: 'accepted'),
              slotHuman('u-tab2', name: 'Ironman', relation: 'self',
                  inviteStatus: 'pending'),
              // Henüz arkadaş değil → öneri adayı.
              slotHuman('bobola', name: 'Bobola', inviteStatus: 'accepted'),
              slotAi,
            ]),
      ];
      await pumpTab(tester,
          liveServices(userId: 'u-tab2', gateway: gw, friendsGateway: fgw));

      await tester.tap(find.text('KABUL ET'));
      await tester.pumpAndSettle();
      expect(gw.responded, [('i1', true)]);
      // Öneri modalı: Esiner (accepted) DEĞİL, yalnız Bobola. Arkadaki davet
      // kartı da aynı isimleri çizdiğinden finder Dialog'a daraltılır.
      Finder inDialog(String s) =>
          find.descendant(of: find.byType(Dialog), matching: find.text(s));
      expect(find.text('Bu kişileri arkadaşın olarak eklemek ister misin?'),
          findsOneWidget);
      expect(inDialog('Bobola'), findsOneWidget);
      expect(inDialog('Esiner'), findsNothing);

      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();
      expect(fgw.sentRequests, ['bobola']);
      expect(find.text('Arkadaşlık davetiniz iletilmiştir.'), findsOneWidget);
      await tester.tap(find.text('TAMAM'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Devam Edenler: sıra bende → yeşil etiket + kalan süre; rakipte → süre yok',
        (tester) async {
      final deadline =
          DateTime.now().toUtc().add(const Duration(hours: 30, minutes: 5));
      final gw = FakeOnlineGamesGateway()
        ..rows = [
          gameRow(id: 'mine', myId: 'u-tab3', status: 'active'),
          gameRow(id: 'theirs', myId: 'u-tab3', status: 'active'),
        ]
        ..turnRows = [
          {'online_game_id': 'mine', 'current': 1}, // self indeksi 1
          {'online_game_id': 'theirs', 'current': 0},
        ]
        ..deadlineRows = [
          {'online_game_id': 'mine', 'turn_deadline': iso(deadline)},
          {'online_game_id': 'theirs', 'turn_deadline': iso(deadline)},
        ];
      await pumpTab(tester, liveServices(userId: 'u-tab3', gateway: gw));

      expect(find.textContaining('SIRA SENDE'), findsOneWidget);
      expect(find.textContaining('SIRA RAKİPTE'), findsOneWidget);
      // Ok ve nokta BİRBİRİNİN yerine geçiyor, ikisi bir arada değil:
      // yeşil ok "git oyna" (yalnız sırası bende), kırmızı nokta "bekle"
      // (yalnız rakipte). Anahtarlı finder, noktayı avatar çemberlerinden
      // ayırt edebilmek için (30 Ağustos 2026).
      expect(find.byKey(const Key('turn-triangle')), findsOneWidget);
      expect(find.byKey(const Key('turn-dot')), findsOneWidget);
      // Kalan süre YALNIZCA sırası bende olan satırda (web 3 Ağustos dersi).
      // Metin 30 Ağustos 2026'da yalnızca "… KALDI"ya indi (fiil düştü).
      expect(find.textContaining('SONRA TESLİM'), findsOneWidget);

      // Punto web ile aynı (Parça 55): durum etiketi text-[15px], alttaki
      // kalan-süre text-[8px]. Bu İKİSİ web'de de farklı — biri ötekine
      // uydurulmamalı. (30 Ağustos 2026'da 11 → 13; 2 Eylül 2026'da 13 → 15,
      // kullanıcı isteği: *"Sıra Sende ve Sıra Rakipte fontu biraz daha
      // büyüt"*.) Sabitin kendisi ortak gövdede — iki kart aynı puntoyu iki
      // ayrı yerde tekrar ettiği için 30 Ağustos'taki değişiklik ELLE
      // taşınmıştı; bu iddia artık o tek kaynağa bakıyor.
      final status = tester.widget<Text>(find.textContaining('SIRA SENDE'));
      expect(status.style!.fontSize, kDevamEdenDurumPunto);
      expect(kDevamEdenDurumPunto, 15,
          reason: 'punto sessizce değişmesin — web `text-[15px]` ile eş');
      final left =
          tester.widget<Text>(find.textContaining('SONRA TESLİM').first);
      expect(left.style!.fontSize, 8);

      // Parça 56: web'de bu kartlar ve alt sekmeler `shadow-raised` /
      // `btn-raised*` taşıyor; port hepsini düz BoxDecoration ile çiziyordu
      // (kullanıcı iki ekran görüntüsünü yan yana koyunca fark etti).
      final raised = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<ShapeDecorationWithCssShadows>()
          .toList();
      expect(raised.where((d) => d.shadows == kRaisedShadows), isNotEmpty,
          reason: 'oyun kartı/pasif sekme gölgesiz kalmamalı');
      expect(raised.where((d) => d.shadows == kRaisedAccentShadows), isNotEmpty,
          reason: 'seçili alt sekme btn-raised gölgesini almalı');
    });

    // BİLDİRİLEN HATANIN NEGATİF EŞİ (2 Eylül 2026, kullanıcı iki ekran
    // görüntüsüyle, 1.0.5 kapalı test paketi `Derleme 4a0a29b`): bu kartta
    // kalan süre durum etiketiyle AYNI sağ sütundaydı, dolayısıyla sütunun
    // enini süre belirliyor ve süre satırı "X açtı" yazısına BİNİYORDU.
    // Setup'ın YZ kartı aynı gün doğru şekle sokulmuştu (#408) ama gövde
    // orada private kalınca burası dokunulmadan kalmıştı.
    //
    // İki iddia AYRI AYRI bozulabilir, bu yüzden ikisi de var:
    //   1. durum etiketi oyuncu satırıyla AYNI satırda (alta kaymıyor),
    //   2. süre "X açtı" satırının ALTINDA — bildirilen "biniyor" tam bu.
    //
    // ⚠ Sıkışma ORANI bilerek BURADA ölçülmüyor: onu ölçen iddia
    // `setup_screen_test.dart` → *"DEVAM EDEN OYUN: … isim alanı sıkışmaz"*
    // ve ölçtüğü şey artık iki kartın PAYLAŞTIĞI `DevamEdenGovde`nin
    // geometrisi. Buraya ikinci bir eşik yazmak, kimsenin ölçmediği bir
    // sayıyı depoya sokmak olurdu (kök `CLAUDE.md`, kural 4).
    testWidgets(
        'Devam Edenler kartı: durum satırda kalır, puan satırı avatarların '
        'altında, süre onun ALTINA iner ("X açtı" yok)',
        (tester) async {
      final deadline =
          DateTime.now().toUtc().add(const Duration(hours: 30, minutes: 5));
      final gw = FakeOnlineGamesGateway()
        ..rows = [gameRow(id: 'mine', myId: 'u-duzen', status: 'active')]
        ..turnRows = [
          {'online_game_id': 'mine', 'current': 1}, // self indeksi 1
        ]
        ..deadlineRows = [
          {
            'online_game_id': 'mine',
            'turn_deadline': iso(deadline),
            // Puan satırı (6 Eylül 2026): koltuk sırasıyla — Esiner 45,
            // Ironman (ben) 38.
            'players': [
              {'score': 45},
              {'score': 38},
            ],
          },
        ];

      // En dar desteklenen telefon: sıkışma burada en sert, üstelik
      // kullanıcının bildirdiği "biniyor" hâli de dar ekranda doğmuştu.
      // Yazı ölçeği tavanı da denenir — düzen ölçekten BAĞIMSIZ tek şekil
      // olmalı (setup kartında `buyukOlcek` dalı tam bu yüzden kalkmıştı).
      Future<(bool, bool)> olc(double olcek) async {
        await setPhoneViewSize(tester, const Size(320, 900));
        await tester.pumpWidget(MaterialApp(
          theme: kelimekiTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(olcek)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: LiveGamesTab(
                      services: liveServices(userId: 'u-duzen', gateway: gw),
                      onFinishesSeen: () {}),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        await tester.pump();

        // Ortak gövdenin anahtarladığı sol alan (bkz. kDevamEdenSolKey) —
        // iki kart da aynı anahtarı taşır, bulucu kartın yapısına bağlı
        // değil.
        final sol = tester.getRect(find.byKey(kDevamEdenSolKey));
        final durum = tester.getRect(find.textContaining('SIRA SENDE'));
        final sure = tester.getRect(find.textContaining('SONRA TESLİM'));
        // "X açtı" KALKTI (6 Eylül 2026), yerine puan satırı — avatarların
        // altında, sürenin üstünde, sol alanın içinde.
        expect(find.textContaining('açtı'), findsNothing);
        final puan = tester.getRect(find.text('45 - 38'));
        final avatar = tester.getRect(find.descendant(
            of: find.byKey(kDevamEdenSolKey),
            matching: find.byType(PlayerAvatarRow)));
        expect(puan.top, greaterThanOrEqualTo(avatar.bottom),
            reason: 'puan satırı avatar şeridinin ALTINDA olmalı');
        expect(sure.top, greaterThanOrEqualTo(puan.bottom),
            reason: 'süre puan satırının ALTINDA olmalı');
        return (
          // durum oyuncu satırıyla DİKEYDE örtüşüyor mu (aynı satır mı)
          durum.top < sol.bottom && durum.bottom > sol.top,
          sure.top >= sol.bottom, // süre sol alanın (avatar+puan) ALTINDA mı
        );
      }

      final (satirdaNormal, altaNormal) = await olc(1.0);
      final (satirdaTavan, altaTavan) = await olc(kMaxTextScale);

      expect(satirdaNormal, isTrue, reason: 'ölçek 1,0da durum satırda olmalı');
      expect(satirdaTavan, isTrue,
          reason: 'ölçek ${kMaxTextScale}te de durum satırda KALMALI');
      expect(altaNormal, isTrue,
          reason: 'süre sol alana (avatar + puan) biniyor — bildirilen hata bu');
      expect(altaTavan, isTrue,
          reason: 'süre tavanda da sol alanın altında olmalı');

      // Bu dosyadaki kalıp: iki kez pump edilen testler ağacı boşaltarak
      // bitiyor (asılı zamanlayıcı/istek kalmasın).
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('LiveGameCreateForm', () {
    Future<
        ({
          FakeOnlineGamesGateway gw,
          List<bool> created,
          List<bool> cancelled
        })> pumpForm(WidgetTester tester,
        {List<Map<String, Object?>>? friendsRows}) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final gw = FakeOnlineGamesGateway();
      final fgw = FakeFriendsGateway(currentUserId: 'me')
        ..friendsRows = friendsRows ??
            [
              {'friend_id': 'f1', 'name': 'Bobola', 'avatar_url': null},
              {'friend_id': 'f2', 'name': 'Esiner', 'avatar_url': null},
              {'friend_id': 'f3', 'name': 'Tuna', 'avatar_url': null},
            ];
      final created = <bool>[];
      final cancelled = <bool>[];
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: LiveGameCreateForm(
              auth: AuthService.fake(user: fakeUser('me')),
              friends: FriendsRepo(fgw),
              onlineGames: OnlineGamesRepo(gw),
              onCancel: () => cancelled.add(true),
              onCreated: () => created.add(true),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      return (gw: gw, created: created, cancelled: cancelled);
    }

    testWidgets('2 oyunculu: tekli seçim + doğrudan gönderim + sentTo ekranı',
        (tester) async {
      // GA4 hunisi (Faz 3): form açılışı → oyun kuruluşu. Terk noktası
      // ölçümünün iki ucu; parametreler oyunun ŞEKLİNİ taşır.
      final fakeAnalytics = FakeAnalytics();
      analytics.configure(fakeAnalytics);
      addTearDown(analytics.reset);
      final h = await pumpForm(tester);
      expect(fakeAnalytics.names, ['live_game_form_opened']);

      // Seçimsiz gönderim pasif — hiçbir şey olmaz.
      await tester.tap(find.text('DAVET GÖNDER'));
      await tester.pump();
      expect(h.gw.createdCounts, isEmpty);

      // Tekli seçim: ikinci arkadaşa dokunmak ilkini bırakır (radio).
      await tester.tap(find.byKey(const ValueKey('friend-f1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('friend-f2')));
      await tester.pump();

      await tester.tap(find.text('DAVET GÖNDER'));
      await tester.pumpAndSettle();
      expect(h.gw.createdCounts, [2]);
      expect(h.gw.createdSlots.single, [
        {'type': 'human', 'user_id': 'me'},
        {'type': 'human', 'user_id': 'f2'},
      ]);
      expect(fakeAnalytics.names,
          ['live_game_form_opened', 'live_game_created']);
      expect(fakeAnalytics.events.last.$2,
          {'player_count': 2, 'with_ai': 0});
      expect(find.text('Davetiniz gönderilmiştir.'), findsOneWidget);
      expect(find.textContaining('Esiner yanıt verince'), findsOneWidget);
      await tester.tap(find.text('TAMAM'));
      await tester.pump();
      expect(h.created, [true]);
    });

    testWidgets(
        '4 oyunculu + 2 arkadaş: YZ onayı; HAYIR → kalıcı YZ satırı; '
        'işaretle → YZ koltuklu gönderim', (tester) async {
      final h = await pumpForm(tester);
      await tester.tap(find.text('4 OYUNCULU'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('friend-f1')));
      await tester.tap(find.byKey(const ValueKey('friend-f2')));
      await tester.pump();

      await tester.tap(find.text('DAVET GÖNDER'));
      await tester.pumpAndSettle();
      expect(find.text('4. koltuk Yapay Zeka ile doldurulacak, tamam mı?'),
          findsOneWidget);
      await tester.tap(find.text('HAYIR'));
      await tester.pumpAndSettle();
      // Hayır: gönderim YOK, YZ artık kalıcı bir liste satırı.
      expect(h.gw.createdCounts, isEmpty);
      expect(find.byKey(const ValueKey('ai-row')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ai-row')));
      await tester.pump();
      await tester.tap(find.text('DAVET GÖNDER'));
      await tester.pumpAndSettle();
      // YZ işaretliyken onay bir daha sorulmaz, 4. koltuk YZ gider.
      expect(h.gw.createdCounts, [4]);
      expect(h.gw.createdSlots.single.last, {'type': 'ai'});
      expect(find.textContaining('4. koltuk Yapay Zeka.'), findsOneWidget);
    });

    testWidgets('4 oyunculu + 3 arkadaş: onay yok, tam insan kadrosu',
        (tester) async {
      final h = await pumpForm(tester);
      await tester.tap(find.text('4 OYUNCULU'));
      await tester.pump();
      for (final k in const ['friend-f1', 'friend-f2', 'friend-f3']) {
        await tester.tap(find.byKey(ValueKey(k)));
      }
      await tester.pump();
      await tester.tap(find.text('DAVET GÖNDER'));
      await tester.pumpAndSettle();
      expect(find.text('4. koltuk Yapay Zeka ile doldurulacak, tamam mı?'),
          findsNothing);
      expect(h.gw.createdCounts, [4]);
      expect(h.gw.createdSlots.single, hasLength(4));
      expect(h.gw.createdSlots.single.last, {'type': 'human', 'user_id': 'f3'});
    });

    testWidgets('VAZGEÇ onCancel çağırır; arkadaş yoksa ekle çağrısı',
        (tester) async {
      final h = await pumpForm(tester, friendsRows: const []);
      expect(find.text('Henüz hiç arkadaşın yok.'), findsOneWidget);
      expect(find.text('ARKADAŞ EKLE / DAVET ET'), findsOneWidget);
      await tester.tap(find.text('VAZGEÇ'));
      await tester.pump();
      expect(h.cancelled, [true]);
    });
  });

  // ── Bildirim izni tetikleyicisi ────────────────────────────────────────
  //
  // Ürün kararı (28 Ağustos 2026): koşul KONUM değil DURUM. "Canlı sekmesi
  // açıldı" tek başına yetmiyor; en az bir aktif oyun ya da bekleyen davet de
  // olmalı. Bu iki test o kararın kendisini kilitliyor — kod yerini
  // değiştirebilir, koşul değişemez.
  /// ⚠ `tester.runAsync` ŞART ve bu projenin yazılı tuzağı
  /// (mobile/CLAUDE.md → "await newRepo(... testWidgets İÇİNDE çıkarsa"):
  /// `testWidgets` sahte bir saatle koşuyor, gerçek SQLite I/O'su o saatte
  /// HİÇ ilerlemiyor. Depoyu doğrudan `storage:` alanına vermek Future'ı
  /// sonsuza kadar bekletiyor ve izin akışı `await storage` satırında asılı
  /// kalıyordu — kart hiç çıkmıyordu, üstelik hiçbir hata da yoktu.
  Future<AppStorage> testDeposu(WidgetTester tester) async {
    late AppStorage depo;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      depo = await AppStorage.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
        prefs: await SharedPreferences.getInstance(),
      );
    });
    return depo;
  }

  testWidgets('aktif oyun VARKEN bildirim izni kartı çıkar', (tester) async {
    sqfliteFfiInit();
    final gw = FakeOnlineGamesGateway()
      ..rows = [gameRow(id: 'g1', myId: 'me', status: 'active')]
      ..turnRows = [
        {'online_game_id': 'g1', 'current': 1},
      ];
    final m = FakeMessaging();
    final depo = Future.value(await testDeposu(tester));
    await pumpTab(
      tester,
      liveServices(
        userId: 'me',
        gateway: gw,
        pushMessaging: m,
        push: PushRepo(
            messaging: m, store: FakeStore(), platformKaynagi: () => 'android'),
        storage: depo,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bildirimleri açalım mı?'), findsOneWidget);
  });

  testWidgets('aktif oyun YOKKEN kart ÇIKMAZ', (tester) async {
    // Oyunu olmayan birine, olmayan oyunlar için bildirim sorulmaz — ve bu
    // sadece nezaket değil: Android 13+'ta boşa harcanan bir sistem denemesi
    // kalıcı olarak geri alınamaz.
    sqfliteFfiInit();
    final gw = FakeOnlineGamesGateway()..rows = [];
    final m = FakeMessaging();
    await pumpTab(
      tester,
      liveServices(
        userId: 'me',
        gateway: gw,
        pushMessaging: m,
        push: PushRepo(
            messaging: m, store: FakeStore(), platformKaynagi: () => 'android'),
        storage: Future.value(await testDeposu(tester)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bildirimleri açalım mı?'), findsNothing);
  });

  // ────────────────────────────────────────────────────────────────────────
  // "Oyun Bitti (Yeni)" — 3 Eylül 2026, kullanıcı isteği.
  //
  // Sorun: hamleni yapıp uygulamayı kapatıyorsun, sen yokken oyun bitiyor ve
  // bitiş modalını HİÇ görmüyorsun. Push bilerek elenmişti; çözüm uygulama
  // içi: "Son Oynananlar"da kırmızı sayı + satırda "YENİ".
  // ────────────────────────────────────────────────────────────────────────
  group('biten oyun haberi', () {
    testWidgets('görülmemiş oyun varsa "Son Oynananlar" rozeti çıkar',
        (tester) async {
      final gw = FakeOnlineGamesGateway()..rows = [];
      await pumpTab(
        tester,
        liveServices(userId: 'me', gateway: gw),
        newlyFinishedIds: const ['g1', 'g2'],
      );
      await tester.pumpAndSettle();
      // Rozet SEKMENİN kutusunda; sayıyı metinden okuyoruz.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('görülmemiş oyun YOKSA rozet çıkmaz', (tester) async {
      final gw = FakeOnlineGamesGateway()..rows = [];
      await pumpTab(tester, liveServices(userId: 'me', gateway: gw));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsNothing);
    });

    testWidgets(
        'sekmeye girmek TOPLU işaretler ve sayacı sıfırlatır '
        '(kullanıcı: "girip gördüğünde tab numarası sıfırlanır")',
        (tester) async {
      final gw = FakeOnlineGamesGateway()..rows = [];
      var sifirlandi = false;
      await pumpTab(
        tester,
        liveServices(userId: 'me', gateway: gw),
        newlyFinishedIds: const ['g1'],
        onFinishesSeen: () => sifirlandi = true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(trUpper('Son Oynananlar')));
      await tester.pumpAndSettle();

      // ⚠ `null` = TOPLU. Tek oyunluk yol yalnızca bitiş modalına ait;
      // burada toplu olmalı, yoksa sekme ziyareti sayacı sıfırlamaz.
      expect(gw.finishesSeenCalls, [null]);
      expect(sifirlandi, isTrue);
    });

    testWidgets(
        'işaretleme DÜŞERSE sayaç sıfırlanmaz (negatif eş — yalnızca sunucu '
        'onaylarsa sıfırla)', (tester) async {
      final gw = FakeOnlineGamesGateway()
        ..rows = []
        ..failMarkFinishesSeen = true;
      var sifirlandi = false;
      await pumpTab(
        tester,
        liveServices(userId: 'me', gateway: gw),
        newlyFinishedIds: const ['g1'],
        onFinishesSeen: () => sifirlandi = true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(trUpper('Son Oynananlar')));
      await tester.pumpAndSettle();

      expect(gw.finishesSeenCalls, isEmpty);
      // Çevrimdışıyken yerelde sıfırlamak rozeti kaybettirir ama sunucuda
      // görülmemiş bırakır — bir sonraki tazelemede geri gelip "kayboldu
      // sonra döndü" diye tuhaf görünürdü.
      expect(sifirlandi, isFalse);
    });
  });

  group('biten oyun haberi — repo', () {
    test('pendingCounts görülmemiş listeyi TAŞIR', () async {
      final gw = FakeOnlineGamesGateway()
        ..rows = []
        ..unseenFinished = ['g1', 'g2'];
      final counts = await OnlineGamesRepo(gw).pendingCounts();
      expect(counts?.finishedUnseenIds, ['g1', 'g2']);
      // ⚠ "Bekleyen iş" toplamına KATILMAZ: o toplam girişte hangi sekmenin
      // açılacağını besliyor ve "yapacak işin var" demek; biten oyun haber.
      expect(counts?.inviteCount, 0);
      expect(counts?.myTurnCount, 0);
    });

    test('görülmemiş çekimi düşerse sayılar YİNE gelir (liste null OLMAZ)',
        () async {
      final gw = FakeOnlineGamesGateway()
        ..rows = []
        ..unseenFinishedThrows = true;
      final counts = await OnlineGamesRepo(gw).pendingCounts();
      // Sayılar sağlam; yalnızca haber "bilinmiyor".
      expect(counts, isNotNull);
      expect(counts?.finishedUnseenIds, isNull);
    });

    test('markFinishesSeen ağ hatasında false döner', () async {
      final gw = FakeOnlineGamesGateway()..failMarkFinishesSeen = true;
      expect(await OnlineGamesRepo(gw).markFinishesSeen(), isFalse);
    });
  });
}
