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
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/ui/live/live_game_create_form.dart';
import 'package:kelimeki/src/ui/live/live_games_tab.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show SetWordSource;
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

// ── Sahte uçlar ─────────────────────────────────────────────────────────────

class FakeOnlineGamesGateway implements OnlineGamesGateway {
  List<Map<String, Object?>> rows = [];
  List<Map<String, Object?>> turnRows = [];
  List<Map<String, Object?>> deadlineRows = [];

  final createdCounts = <int>[];
  final createdSlots = <List<Map<String, Object?>>>[];
  final notified = <String>[];
  final responded = <(String, bool)>[];
  final turnTimeoutChecks = <String>[];
  final inviteExpiryChecks = <String>[];

  Object? failWith;
  Object? notifyFailWith;
  int listCalls = 0;
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  /// Süpürme RPC'lerinin sunucu etkisini taklit etmek için (test satırları
  /// mutasyona uğratır — ikinci fetch farkı görsün).
  void Function(String gameId)? onCheckInviteExpiry;
  void Function(String gameId)? onCheckTurnTimeout;

  void _maybeFail() {
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<List<Map<String, Object?>>> listMine() async {
    _maybeFail();
    listCalls++;
    return [for (final r in rows) Map<String, Object?>.of(r)];
  }

  @override
  Future<String> create(
      int playerCount, List<Map<String, Object?>> slots) async {
    _maybeFail();
    createdCounts.add(playerCount);
    createdSlots.add(slots);
    return 'new-game';
  }

  @override
  Future<void> notifyGameInvite(String gameId) async {
    final f = notifyFailWith;
    if (f != null) throw f;
    notified.add(gameId);
  }

  @override
  Future<void> respondInvite(String inviteId, bool accept) async {
    _maybeFail();
    responded.add((inviteId, accept));
  }

  @override
  Future<List<Map<String, Object?>>> turns(List<String> gameIds) async =>
      [for (final r in turnRows) if (gameIds.contains(r['online_game_id'])) r];

  @override
  Future<List<Map<String, Object?>>> deadlines(List<String> gameIds) async => [
        for (final r in deadlineRows)
          if (gameIds.contains(r['online_game_id'])) r
      ];

  @override
  Future<void> checkTurnTimeout(String gameId) async {
    turnTimeoutChecks.add(gameId);
    onCheckTurnTimeout?.call(gameId);
  }

  @override
  Future<void> checkInviteExpiry(String gameId) async {
    inviteExpiryChecks.add(gameId);
    onCheckInviteExpiry?.call(gameId);
  }

  @override
  void Function() subscribe(void Function() onChange) {
    subscribeCount++;
    return () => unsubscribeCount++;
  }
}

class FakeFriendsGateway implements FriendsGateway {
  @override
  String? currentUserId;
  FakeFriendsGateway({this.currentUserId = 'me'});

  List<Map<String, Object?>> friendsRows = [];
  final sentRequests = <String>[];

  @override
  Future<List<Map<String, Object?>>> listFriends() async => friendsRows;

  @override
  Future<String> sendRequest(String targetId) async {
    sentRequests.add(targetId);
    return 'pending';
  }

  @override
  Future<void> notifyFriendRequest(String friendId) async {}

  @override
  Future<List<Map<String, Object?>>> searchUsers(String query) async => [];
  @override
  Future<List<Map<String, Object?>>> listUsers(int offset, int limit) async =>
      [];
  @override
  Future<void> acceptRequest(String requesterId) async {}
  @override
  Future<void> deleteRelation(String otherId) async {}
  @override
  Future<List<Map<String, Object?>>> listIncomingRequests() async => [];
  @override
  Future<Map<String, Object?>?> relationRow(String targetId) async => null;
  @override
  Future<String?> createInviteToken() async => null;
  @override
  Future<String?> inviteInfo(String token) async => null;
  @override
  Future<String?> acceptInvite(String token) async => null;
}

User fakeUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: '$id@ornek.com',
    );

// ── Satır kurucuları ────────────────────────────────────────────────────────

Map<String, Object?> slotHuman(String userId,
        {String? name, String? relation, String? inviteStatus}) =>
    {
      'type': 'human',
      'user_id': userId,
      'name': name ?? userId,
      'avatar_url': null,
      'relation': relation,
      'invite_status': inviteStatus,
    };

const Map<String, Object?> slotAi = {'type': 'ai'};

Map<String, Object?> gameRow({
  required String id,
  required String myId,
  String createdBy = 'esiner',
  int playerCount = 2,
  String status = 'active',
  String myRole = 'invitee',
  String? myInviteStatus,
  String? myInviteId,
  String? createdAt,
  List<Map<String, Object?>>? slots,
}) =>
    {
      'id': id,
      'created_by': createdBy,
      'player_count': playerCount,
      'status': status,
      'slots': slots ??
          [
            slotHuman(createdBy, name: 'Esiner', relation: 'accepted'),
            slotHuman(myId, name: 'Ironman', relation: 'self',
                inviteStatus: myInviteStatus),
          ],
      'created_at': createdAt ?? DateTime.now().toUtc().toIso8601String(),
      'my_role': myRole,
      'my_invite_status': myInviteStatus,
      'my_invite_id': myInviteId,
    };

OnlineGame game(Map<String, Object?> row) => OnlineGame.fromJson(row);

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
      expect(l.text, '30 saat 0 dakika sonra teslim sayılacak');
      expect(l.urgent, isFalse);

      final in90m = iso(DateTime.utc(2026, 8, 7, 13, 30));
      l = remainingTimeLabel(in90m, nowMs)!;
      expect(l.text, '1 saat 30 dakika sonra teslim sayılacak');
      expect(l.urgent, isTrue);

      final in5m = iso(DateTime.utc(2026, 8, 7, 12, 5));
      l = remainingTimeLabel(in5m, nowMs)!;
      expect(l.text, '5 dakika sonra teslim sayılacak');

      l = remainingTimeLabel(iso(DateTime.utc(2026, 8, 7, 11)), nowMs)!;
      expect(l.text, 'Süresi doldu - teslim oldu');
      expect(l.urgent, isTrue);
    });

    test('remainingInviteLabel: gün/saat, acil eşiği, süresi dolmuş', () {
      // 3 gün önce açıldı → 4 gün 0 saat kaldı.
      var l = remainingInviteLabel(iso(DateTime.utc(2026, 8, 4, 12)), nowMs);
      expect(l.text, '4 gün 0 saat sonra iptal edilecek');
      expect(l.urgent, isFalse);

      // 6 gün 22 saat önce → 2 saat 0 dakika kaldı, acil.
      l = remainingInviteLabel(iso(DateTime.utc(2026, 7, 31, 14)), nowMs);
      expect(l.text, '2 saat 0 dakika sonra iptal edilecek');
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
  });

  // ── Widget testleri ───────────────────────────────────────────────────────

  AppServices liveServices({
    required String userId,
    required FakeOnlineGamesGateway gateway,
    FakeFriendsGateway? friendsGateway,
  }) =>
      AppServices(
        dictionary: Future.value(SetWordSource(const [])),
        meanings: MeaningStore(bundle: rootBundle),
        auth: AuthService.fake(user: fakeUser(userId)),
        supabase: null,
        versionGate: VersionGateStatus.ok,
        onlineGames: OnlineGamesRepo(gateway),
        friends: FriendsRepo(friendsGateway ?? FakeFriendsGateway()),
      );

  Future<void> pumpTab(WidgetTester tester, AppServices s,
      {GlobalKey? boundaryKey}) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    Widget body = SingleChildScrollView(
        padding: const EdgeInsets.all(12), child: LiveGamesTab(services: s));
    if (boundaryKey != null) {
      body = RepaintBoundary(
          key: boundaryKey, child: ColoredBox(color: Colors.white, child: body));
    }
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(body: body),
    ));
    await tester.pump();
    await tester.pump();
  }

  group('LiveGamesTab', () {
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

      expect(find.text('SENİN HAMLEN BEKLENİYOR'), findsOneWidget);
      expect(find.text('RAKİBİN HAMLESİ BEKLENİYOR'), findsOneWidget);
      // Kalan süre YALNIZCA sırası bende olan satırda (web 3 Ağustos dersi).
      expect(find.textContaining('TESLİM SAYILACAK'), findsOneWidget);
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
        theme: ThemeData(
            fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
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
      final h = await pumpForm(tester);

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
}
