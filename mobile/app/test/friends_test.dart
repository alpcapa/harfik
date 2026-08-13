// Arkadaşlık sistemi parçası — FriendsRepo (sahte gateway), davet linki
// çözümleme/kuyruklama (FriendInviteInbox + gerçek SQLite ffi), FriendsModal
// sekmeleri/varsayılan-sekme kuralı/ilişki yamaları, AccountButton rozeti ve
// PlayerScoreCard arkadaşlık simgesi. Gerçek RPC'ler/RLS cihazda
// doğrulanacak (mobile/TESTING.md, "Arkadaşlar").
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/data/friend_invite_inbox.dart';
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/stats_api.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/storage/pending_event_store.dart';
import 'package:kelimeki/src/ui/auth/account_button.dart';
import 'package:kelimeki/src/ui/friends/friends_modal.dart';
import 'package:kelimeki/src/ui/score/player_score_card_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

int _dbSeq = 0;

/// feedback_test'teki aynı izolasyon kararı: benzersiz temp dosya yolu —
/// inMemoryDatabasePath açık kaldıkça testler arasında paylaşılır.
Future<AppStorage> openTestStorage() async {
  SharedPreferences.setMockInitialValues({});
  final dir = Directory.systemTemp.createTempSync('kelimeki-fr-test');
  return AppStorage.open(
    factory: databaseFactoryFfi,
    path: '${dir.path}/t${_dbSeq++}.db',
    prefs: await SharedPreferences.getInstance(),
    nowMs: () => DateTime.now().millisecondsSinceEpoch,
  );
}

class FakeFriendsGateway implements FriendsGateway {
  @override
  String? currentUserId = 'me';

  List<Map<String, Object?>> friendsRows = [];
  List<Map<String, Object?>> requestRows = [];
  List<Map<String, Object?>> userRows = [];
  Map<String, Object?>? relation;
  String sendResult = 'pending';
  final notified = <String>[];
  final accepted = <String>[];
  final deleted = <String>[];
  final acceptedInvites = <String>[];
  Object? failWith;

  void _maybeFail() {
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<List<Map<String, Object?>>> searchUsers(String query) async {
    _maybeFail();
    return userRows;
  }

  @override
  Future<List<Map<String, Object?>>> listUsers(int offset, int limit) async {
    _maybeFail();
    return userRows.skip(offset).take(limit).toList();
  }

  @override
  Future<String> sendRequest(String targetId) async {
    _maybeFail();
    return sendResult;
  }

  @override
  Future<void> notifyFriendRequest(String friendId) async {
    notified.add(friendId);
  }

  @override
  Future<void> acceptRequest(String requesterId) async {
    _maybeFail();
    accepted.add(requesterId);
  }

  @override
  Future<void> deleteRelation(String otherId) async {
    _maybeFail();
    deleted.add(otherId);
  }

  @override
  Future<List<Map<String, Object?>>> listFriends() async {
    _maybeFail();
    return friendsRows;
  }

  @override
  Future<List<Map<String, Object?>>> listIncomingRequests() async {
    _maybeFail();
    return requestRows;
  }

  @override
  Future<Map<String, Object?>?> relationRow(String targetId) async {
    _maybeFail();
    return relation;
  }

  @override
  Future<String?> createInviteToken() async {
    _maybeFail();
    return 'tok-123';
  }

  @override
  Future<String?> inviteInfo(String token) async {
    _maybeFail();
    return 'Ironman';
  }

  @override
  Future<String?> acceptInvite(String token) async {
    _maybeFail();
    acceptedInvites.add(token);
    return 'Ironman';
  }
}

User fakeUser() => User(
      id: 'me',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: 'alp.capa@hotmail.com',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(loadAppFonts);

  group('parseInviteToken', () {
    test('iki geçerli biçim + negatifler', () {
      expect(parseInviteToken(Uri.parse('kelimeki://davet/abc123')), 'abc123');
      expect(parseInviteToken(Uri.parse('https://kelimeki.com/davet/abc123')),
          'abc123');
      expect(parseInviteToken(Uri.parse('http://kelimeki.com/davet/t')), 't');
      // Auth callback'leri ve alakasız yollar davet DEĞİL.
      expect(parseInviteToken(Uri.parse('kelimeki://reset?code=xyz')), isNull);
      expect(parseInviteToken(Uri.parse('https://kelimeki.com/game/abc')),
          isNull);
      expect(parseInviteToken(Uri.parse('https://ornek.com/davet/abc')),
          isNull);
      expect(parseInviteToken(Uri.parse('kelimeki://davet/')), isNull);
      expect(parseInviteToken(Uri.parse('kelimeki://davet/a/b')), isNull);
    });

    test('buildInviteUrl web biçimiyle birebir', () {
      expect(buildInviteUrl('tok'), 'https://kelimeki.com/davet/tok');
    });
  });

  group('FriendInviteInbox', () {
    test('davet URI kuyruklanır + haber verilir; alakasız URI yok sayılır',
        () async {
      final storage = openTestStorage();
      final inbox = FriendInviteInbox(storage);
      var notified = 0;
      inbox.addListener(() => notified++);

      // handleUri doğrudan await edilir (stream dinleyicisi aynı metoda
      // delege ediyor; gerçek dosya IO'lu storage açılışını sabit bir
      // gecikmeyle beklemek uçucu çıkmıştı).
      await inbox.handleUri(Uri.parse('kelimeki://reset?code=x')); // auth
      await inbox.handleUri(Uri.parse('kelimeki://davet/tok-1'));

      expect(notified, 1);
      expect(inbox.lastToken, 'tok-1');
      final s = await storage;
      final events = await s.events.takeAll(friendInviteTokenKind);
      expect(events, hasLength(1));
      expect(events.single['token'], 'tok-1');
      inbox.dispose();
    });
  });

  group('FriendsRepo', () {
    test('listeler trCompare ile sıralanır; hata null döner', () async {
      final gw = FakeFriendsGateway()
        ..friendsRows = [
          {'friend_id': 'a', 'name': 'çiğdem', 'avatar_url': null},
          {'friend_id': 'b', 'name': 'Ali', 'avatar_url': null},
          {'friend_id': 'c', 'name': 'ümit', 'avatar_url': null},
        ];
      final repo = FriendsRepo(gw);
      final friends = await repo.friends();
      expect([for (final f in friends!) f.name], ['Ali', 'çiğdem', 'ümit']);

      gw.failWith = Exception('ağ');
      expect(await repo.friends(), isNull);
      expect(await repo.search('ab'), isNull);
      expect(await repo.incomingRequests(), isNull);
    });

    test('sendRequest: pending → bildirim; accepted → bildirim YOK', () async {
      final gw = FakeFriendsGateway()..sendResult = 'pending';
      final repo = FriendsRepo(gw);
      expect(await repo.sendRequest('u1'), FriendRelation.pendingOutgoing);
      await Future<void>.delayed(Duration.zero);
      expect(gw.notified, ['u1']);

      gw.sendResult = 'accepted';
      expect(await repo.sendRequest('u2'), FriendRelation.accepted);
      await Future<void>.delayed(Duration.zero);
      expect(gw.notified, ['u1']); // u2 için bildirim gitmedi
    });

    test('relationWith: yön doğru çözülür; kendi kartında null', () async {
      final gw = FakeFriendsGateway();
      final repo = FriendsRepo(gw);
      expect(await repo.relationWith('me'), isNull); // kendisi

      gw.relation = {'user_id': 'me', 'status': 'pending'};
      expect(await repo.relationWith('u1'), FriendRelation.pendingOutgoing);
      gw.relation = {'user_id': 'u1', 'status': 'pending'};
      expect(await repo.relationWith('u1'), FriendRelation.pendingIncoming);
      gw.relation = {'user_id': 'u1', 'status': 'accepted'};
      expect(await repo.relationWith('u1'), FriendRelation.accepted);
      gw.relation = null;
      expect(await repo.relationWith('u1'), isNull);
    });
  });

  group('FriendsModal', () {
    Future<FakeFriendsGateway> pumpModal(
      WidgetTester tester, {
      FakeFriendsGateway? gateway,
      FriendsTab? initialTab,
      Future<void> Function(String)? sharer,
      bool withStats = false,
    }) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final gw = gateway ?? FakeFriendsGateway();
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: FriendsModal(
            friends: FriendsRepo(gw),
            auth: AuthService.fake(user: fakeUser()),
            // stats yoksa isim/avatara dokunuş pasif kalır (offline dalı) —
            // skor kartı testleri açıkça withStats: true geçiyor.
            stats: withStats ? StatsRepo(_NullStatsGateway()) : null,
            initialTab: initialTab,
            sharer: sharer,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      return gw;
    }

    testWidgets(
        'varsayılan sekme: bekleyen istek varsa İstekler + rozet; kabul akışı',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..requestRows = [
          {'requester_id': 'r1', 'name': 'Esiner', 'avatar_url': null},
        ];
      await pumpModal(tester, gateway: gw);

      // Bekleyen istek → İstekler sekmesi açık gelir (web deseni).
      expect(find.text('Esiner'), findsOneWidget);
      expect(find.text('KABUL ET'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // CountBadge

      await tester.tap(find.text('KABUL ET'));
      await tester.pumpAndSettle();
      expect(gw.accepted, ['r1']);
    });

    testWidgets('initialTab açıkça verilirse varsayılan kural ezmez',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..requestRows = [
          {'requester_id': 'r1', 'name': 'Esiner', 'avatar_url': null},
        ];
      await pumpModal(tester, gateway: gw, initialTab: FriendsTab.friends);
      // İstek beklese de "Arkadaşlarım" açık (boş durum metni görünür).
      expect(find.textContaining('Henüz arkadaşın yok'), findsOneWidget);
    });

    testWidgets(
        'Ara & Ekle: tüm üyeler listesi + ekle ikonu → bekliyor ikonu yaması',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..userRows = [
          {'id': 'u1', 'name': 'Bobola', 'avatar_url': null, 'relation': null},
          {
            'id': 'u2',
            'name': 'Ali',
            'avatar_url': null,
            'relation': 'accepted'
          },
        ];
      await pumpModal(tester, gateway: gw);
      await tester.tap(find.text('ARA & EKLE'));
      await tester.pump();
      await tester.pump();

      expect(find.text('TÜM ÜYELER'), findsOneWidget);
      // 11 Ağustos 2026: satır aksiyonları metin değil ikon (bkz.
      // RelationIcons.tsx / _relationIconButton). Aynı gün ikinci karar:
      // zaten arkadaş olanlar ("Ali") bu listede HİÇ görünmez — onlar
      // "Arkadaşlarım" sekmesinde.
      expect(find.text('Ali'), findsNothing);
      expect(find.byIcon(Icons.person_remove), findsNothing);
      expect(find.text('Bobola'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_add_alt_1));
      // pumpAndSettle DEĞİL: odaklı arama alanının imleç animasyonu hiç
      // durmadığından settle asılır (feedback formunda görünmedi çünkü
      // orada gönderim alanı söküyor) — sınırlı pump yeterli.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Ekle artık ANINDA iş yapmıyor: önce onay, sonra sonuç diyaloğu.
      expect(find.text('Arkadaş Ekle'), findsOneWidget);
      expect(gw.notified, isEmpty);
      await tester.tap(find.text('EKLE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Arkadaşlık isteğiniz iletilmiştir.'), findsOneWidget);
      await tester.tap(find.text('TAMAM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.hourglass_top), findsOneWidget); // patchRelation
      // DİKKAT: testWidgets içinde `await Future.delayed(...)` fake-async
      // bölgesinde ASILIR (timer pump'sız çözülmez) — bildirim fake'te
      // senkron kaydedildiğinden doğrudan kontrol yeterli.
      expect(gw.notified, ['u1']);
    });

    testWidgets(
        'Ara & Ekle: gelen isteği kabul de onaydan geçer + satır listeden düşer',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..userRows = [
          {
            'id': 'u3',
            'name': 'Esiner',
            'avatar_url': null,
            'relation': 'pending_incoming'
          },
        ];
      await pumpModal(tester, gateway: gw);
      await tester.tap(find.text('ARA & EKLE'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.how_to_reg));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Onay ekranı — henüz sunucuya HİÇBİR şey gitmedi.
      expect(find.textContaining('Kabul etmek istiyor musun'), findsOneWidget);
      expect(gw.accepted, isEmpty);

      await tester.tap(find.text('KABUL ET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(gw.accepted, ['u3']);
      expect(find.text('Arkadaş oldunuz.'), findsOneWidget);
      await tester.tap(find.text('TAMAM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Artık arkadaş → "Ara & Ekle" listesinden düşer (Arkadaşlarım'da).
      expect(find.text('Esiner'), findsNothing);
    });

    testWidgets(
        'Ara & Ekle: bir sayfanın tamamı arkadaş çıkarsa sonraki sayfa yine gelir',
        (tester) async {
      // Kaydırılamayan bir listede ScrollController dinleyicisi HİÇ
      // ateşlenmez (Parça 31'deki k-lig hatası) — eleme bu durumu artık
      // kendiliğinden üretebildiğinden `_autoLoadIfNotScrollable` şart.
      final gw = FakeFriendsGateway()
        ..userRows = [
          for (var i = 0; i < kAllUsersPageSize; i++)
            {
              'id': 'f\$i',
              'name': 'Arkadas \$i',
              'avatar_url': null,
              'relation': 'accepted'
            },
          {'id': 'yeni', 'name': 'Zeynep', 'avatar_url': null, 'relation': null},
        ];
      await pumpModal(tester, gateway: gw);
      await tester.tap(find.text('ARA & EKLE'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('Zeynep'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });

    testWidgets(
        'isim/avatara dokunmak ÜÇ listede de skor kartını açar (Ara & Ekle dahil)',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..friendsRows = [
          {'friend_id': 'a', 'name': 'Bobola', 'avatar_url': null},
        ]
        ..requestRows = [
          {'requester_id': 'r1', 'name': 'Esiner', 'avatar_url': null},
        ]
        ..userRows = [
          {'id': 'u1', 'name': 'Zeynep', 'avatar_url': null, 'relation': null},
        ];
      await pumpModal(tester,
          gateway: gw, initialTab: FriendsTab.friends, withStats: true);

      // 1) Arkadaşlarım (baştan beri vardı — regresyon güvencesi)
      await tester.tap(find.text('Bobola'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerScoreCardModal), findsOneWidget);
      await tester.tap(find.byTooltip('Kapat').last);
      await tester.pumpAndSettle();

      // 2) İstekler — isteği yanıtlamadan önce kime bakıyoruz?
      await tester.tap(find.text('İSTEKLER'));
      await tester.pump();
      await tester.tap(find.text('Esiner'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerScoreCardModal), findsOneWidget);
      await tester.tap(find.byTooltip('Kapat').last);
      await tester.pumpAndSettle();

      // 3) Ara & Ekle — kullanıcının istediği asıl yer.
      await tester.tap(find.text('ARA & EKLE'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Zeynep'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PlayerScoreCardModal), findsOneWidget);
    });

    testWidgets('davet butonu: link + metin paylaş ucuna gider + görüntü',
        (tester) async {
      final shared = <String>[];
      final gw = await pumpModal(tester, sharer: (t) async => shared.add(t));
      expect(gw, isNotNull);

      final key = GlobalKey();
      // Ekran görüntüsü için yeniden pump (RepaintBoundary ile).
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            body: FriendsModal(
              friends: FriendsRepo(FakeFriendsGateway()
                ..friendsRows = [
                  {'friend_id': 'a', 'name': 'Bobola', 'avatar_url': null},
                  {'friend_id': 'b', 'name': 'Esiner', 'avatar_url': null},
                ]),
              auth: AuthService.fake(user: fakeUser()),
              sharer: (t) async => shared.add(t),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('ARKADAŞINI DAVET ET'));
      await tester.pumpAndSettle();
      expect(shared.single,
          '$inviteShareText\nhttps://kelimeki.com/davet/tok-123');

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/screenshots/friends_modal.png');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });

    testWidgets('Arkadaşlarım: çıkar ikonu → onay → silme + sonuç diyaloğu',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..friendsRows = [
          {'friend_id': 'f1', 'name': 'Bobola', 'avatar_url': null},
        ];
      await pumpModal(tester, gateway: gw);
      expect(find.text('Bobola'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_remove));
      await tester.pumpAndSettle();
      expect(find.textContaining('Arkadaşlıktan çıkmak mı'), findsOneWidget);
      await tester.tap(find.text('VAZGEÇ'));
      await tester.pumpAndSettle();
      expect(gw.deleted, isEmpty); // vazgeçildi

      await tester.tap(find.byIcon(Icons.person_remove));
      await tester.pumpAndSettle();
      // Onay diyaloğunun butonu hâlâ METİN — yalnızca satır ikonlaştı.
      await tester.tap(find.text('ÇIKAR').last);
      await tester.pumpAndSettle();
      expect(gw.deleted, ['f1']);
      expect(find.text('Arkadaşlıktan çıkarıldı.'), findsOneWidget);
    });
  });

  group('AccountButton + PlayerScoreCard', () {
    testWidgets('menüde Arkadaşlar satırı + rozet + avatar noktası',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final gw = FakeFriendsGateway()
        ..requestRows = [
          {'requester_id': 'r1', 'name': 'Esiner', 'avatar_url': null},
          {'requester_id': 'r2', 'name': 'Bobola', 'avatar_url': null},
        ];
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: Center(
            child: AccountButton(
              auth: AuthService.fake(
                  user: fakeUser(),
                  profile: const KProfile(id: 'me', displayName: 'Ironman')),
              friends: FriendsRepo(gw),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(AccountButton));
      await tester.pumpAndSettle();
      expect(find.textContaining('Arkadaşlar'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // rozet
    });

    testWidgets(
        'PlayerScoreCard: arkadaşsa yeşil how_to_reg → çıkar onayı; değilse person_add',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final gw = FakeFriendsGateway()
        ..relation = {'user_id': 'me', 'status': 'accepted'};
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: PlayerScoreCardModal(
            stats: StatsRepo(_NullStatsGateway()),
            userId: 'u9',
            name: 'Bobola',
            friends: FriendsRepo(gw),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      // Skor kartında arkadaş durumu BİLİNÇLİ olarak listelerin kırmızı
      // person_remove'u değil yeşil how_to_reg (kullanıcı kararı, 11 Ağustos
      // 2026) — dokunuş yine de çıkarma onayını açıyor.
      expect(find.byIcon(Icons.person_remove), findsNothing);
      final relIcon = tester.widget<Icon>(find.byIcon(Icons.how_to_reg));
      expect(relIcon.color, const Color(0xFF16A34A));

      await tester.tap(find.byIcon(Icons.how_to_reg));
      await tester.pumpAndSettle();
      expect(find.textContaining('Arkadaşlıktan çıkmak mı'), findsOneWidget);
      await tester.tap(find.text('ÇIKAR'));
      await tester.pumpAndSettle();
      expect(gw.deleted, ['u9']);
      // regresyon (9 Ağustos 2026): web'in `resultMsg`i — işlem sonrası bir
      // "Tamam" sonuç diyaloğu çıkmalıydı, önceden HİÇBİRİ çıkmıyordu.
      expect(find.text('Arkadaşlıktan çıkarıldı.'), findsOneWidget);
      await tester.tap(find.text('TAMAM'));
      await tester.pumpAndSettle();
      // Simge artık "ekle"ye döner.
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });

    testWidgets(
        'regresyon (9 Ağustos 2026): PlayerScoreCard\'ta arkadaş isteği '
        'gönderince "iletilmiştir" sonuç diyaloğu çıkar + onay diyaloğu '
        'geniş ekranda taşmaz (web max-w-sm paritesi)', (tester) async {
      await setPhoneViewSize(tester, const Size(1200, 900));
      final gw = FakeFriendsGateway()..sendResult = 'pending';
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: PlayerScoreCardModal(
            stats: StatsRepo(_NullStatsGateway()),
            userId: 'u9',
            name: 'Bobola',
            friends: FriendsRepo(gw),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_add_alt_1));
      await tester.pumpAndSettle();
      expect(find.text('Arkadaş Ekle'), findsOneWidget);
      // Onay diyaloğunun kendi `constraints.maxWidth`i web'in max-w-sm'ine
      // (384px) yakın kalmalı — önceden Flutter Dialog'un varsayılan üst
      // sınırsızlığı (`BoxConstraints(minWidth: 280)`, üst sınır YOK)
      // yüzünden geniş ekranlarda neredeyse tam genişliğe yayılıyordu.
      // (`tester.getSize(Dialog)` yerine widget'ın kendi `constraints`
      // alanı okunuyor — `Dialog`'un RENDER boyutu `Align`in kapladığı
      // TÜM alan, iç `Material` kartının değil; piksel ölçümü yanıltıcı.)
      final confirmDialog = tester
          .widgetList<Dialog>(find.byType(Dialog))
          .firstWhere((d) => d.constraints?.maxWidth == 384);
      expect(confirmDialog.constraints?.maxWidth, 384);
      // Gerçek render boyutu da (Dialog'un içindeki ConstrainedBox) genişlik
      // sınırını GERÇEKTEN uyguladığını kanıtlıyor.
      final renderedWidth = tester
          .getSize(find
              .byWidgetPredicate((w) =>
                  w is ConstrainedBox && w.constraints.maxWidth == 384)
              .first)
          .width;
      expect(renderedWidth, lessThanOrEqualTo(384));

      // 11 Ağustos 2026: onay metni web `friendDialogCopy` ile hizalandı —
      // "Gönder" değil "Ekle" (FriendsModal'ın aynı diyaloğuyla da tek dil).
      await tester.tap(find.text('EKLE'));
      await tester.pumpAndSettle();
      // regresyon: gönderince web'in "Arkadaşlık isteğiniz iletilmiştir."
      // sonucu görünmeliydi, önceden HİÇBİR ŞEY çıkmıyordu.
      expect(find.text('Arkadaşlık isteğiniz iletilmiştir.'), findsOneWidget);
    });
  });

  group('Setup davet kuyruğu işleme', () {
    test('girişliyken takeAll → acceptInvite; hata token düşürür', () async {
      // Setup'ın _processInvites'inin veri katmanı sözleşmesi burada repo +
      // store seviyesinde sınanır (widget akışı: kuyruk → kabul → boşalır).
      final storage = await openTestStorage();
      await storage.events.add(friendInviteTokenKind, {'token': 't1'});
      await storage.events.add(friendInviteTokenKind, {'token': 't2'});
      final gw = FakeFriendsGateway();
      final repo = FriendsRepo(gw);

      final events = await storage.events.takeAll(friendInviteTokenKind);
      expect(events, hasLength(2));
      for (final e in events) {
        await repo.acceptInvite(e['token'] as String);
      }
      expect(gw.acceptedInvites, ['t1', 't2']);
      // takeAll atomik tüketti — ikinci okuma boş.
      expect(await storage.events.takeAll(friendInviteTokenKind), isEmpty);
    });

    // Parça 87 — soğuk başlangıçta AYNI token iki kez kuyruğa girebiliyor:
    // `pending_events`in dedup'ı yok (`PendingEventStore.add` düz insert) ve
    // link hem `uriLinkStream`den hem `getInitialLink()` kurtarmasından
    // düşebiliyor. Dedup olmadan kullanıcı üst üste iki "artık arkadaşsınız"
    // diyaloğu görür ve ikinci bir gereksiz RPC atılır.
    test('parti içinde mükerrer token bir kez işlenir, bozuk kayıt elenir',
        () {
      expect(
        inviteTokensFromEvents([
          {'token': 'tok-1'},
          {'token': 'tok-1'}, // soğuk başlangıç: akış + getInitialLink
          {'token': 'tok-2'},
          {'token': ''}, // bozuk
          {'token': 42}, // bozuk
          <String, Object?>{}, // bozuk
        ]),
        ['tok-1', 'tok-2'],
      );
      // Dedup PARTİ bazında: kalıcı bir "görüldü" listesi TUTULMUYOR, yani
      // bir sonraki oturumda aynı linke yeniden dokunmak hâlâ çalışır.
      expect(inviteTokensFromEvents([
        {'token': 'tok-1'}
      ]), ['tok-1']);
    });

  });
}

class _NullStatsGateway implements StatsGateway {
  @override
  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset) async =>
      [];

  @override
  Future<Map<String, Object?>?> myLeaderboardRank(String userId) async => null;

  @override
  Future<Map<String, Object?>?> playerStats(
          String userId, int? playerCount) async =>
      null;
}
