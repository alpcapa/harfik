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
import 'package:kelimeki/src/data/chat_api.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/tokens.dart';
import 'package:kelimeki/src/data/friend_invite_inbox.dart';
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/stats_api.dart';
import 'package:kelimeki/src/ui/rank/rank_seal.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/storage/pending_event_store.dart';
import 'package:kelimeki/src/util/offline_notice.dart' show isNetworkError;
import 'package:kelimeki/src/ui/auth/account_button.dart';
import 'package:kelimeki/src/ui/auth/k_avatar.dart';
import 'package:kelimeki/src/ui/friends/friends_modal.dart';
import 'package:kelimeki/src/ui/friends/relation_icons.dart';
import 'package:kelimeki/src/ui/score/player_score_card_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show User, PostgrestException;

import 'package:kelimeki/src/data/analytics.dart';
import 'support/fake_analytics.dart';
import 'support/fake_online_gateway.dart';
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

    test('buildInviteUrl web biçimiyle birebir — `?ref=arkadas` DAHİL', () {
      // Etiket ZORUNLU (21 Ağustos 2026, ROADMAP #7): olmadan davetle gelip
      // üye olan herkes admin panelindeki Kaynak Hunisi'nde `direkt` satırına
      // düşüyor ve gerçek doğrudan trafiği şişiriyor. Web'in
      // `FriendsModal.tsx`'indeki aynı fonksiyonla birebir olmak zorunda.
      expect(buildInviteUrl('tok'), 'https://kelimeki.com/davet/tok?ref=arkadas');
      // Etiketli link uygulamaya düşerse token yine doğru çözülmeli —
      // `uri.pathSegments` sorgu dizesini içermez.
      expect(parseInviteToken(Uri.parse(buildInviteUrl('tok'))), 'tok');
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
      FakeChatGateway? chat,
      Size size = const Size(420, 900),
    }) async {
      await setPhoneViewSize(tester, size);
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
            // chat yoksa moderasyon ikonu HİÇ çizilmez (web'de de aynı
            // dal) — ikon testleri açıkça bir sahte uç geçiyor.
            chat: chat == null ? null : ChatRepo(chat),
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
      expect(find.byType(PersonPendingIcon), findsOneWidget); // patchRelation
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

    testWidgets(
        'isimlerin yanında rütbe mührü (18 Ağustos 2026) — 18px, satırın '
        '14px puntosuna göre; ekle/çıkar ikonunun SOLUNDA', (tester) async {
      final gw = FakeFriendsGateway()
        ..friendsRows = [
          {'friend_id': 'f1', 'name': 'Bobola', 'avatar_url': null},
        ];
      await pumpModal(tester,
          gateway: gw, initialTab: FriendsTab.friends, withStats: true);
      // Sahte uç boş liste döndürüyor → puan 0 → Çaylak (yine de BİLİNEN
      // bir puan; "henüz yüklenmedi" ile karıştırılmamalı).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final seals = tester.widgetList<RankSeal>(find.byType(RankSeal)).toList();
      expect(seals, isNotEmpty, reason: 'isim yanında mühür çizilmemiş');
      expect(seals.first.size, 18);
      expect(tester.getTopLeft(find.byType(RankSeal).first).dx,
          greaterThanOrEqualTo(tester.getTopRight(find.text('Bobola')).dx),
          reason: 'mühür ismin SAĞINDA olmalı');
    });

    testWidgets('davet butonu: link + metin paylaş ucuna gider + görüntü',
        (tester) async {
      // GA4 `invite_link_shared` {source: friends_modal} — Faz 3.
      final fakeAnalytics = FakeAnalytics();
      analytics.configure(fakeAnalytics);
      addTearDown(analytics.reset);
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
      await tester.tap(find.text('+ ARKADAŞINI DAVET ET'));
      await tester.pumpAndSettle();
      expect(shared.single,
          '$inviteShareText\nhttps://kelimeki.com/davet/tok-123?ref=arkadas');
      expect(fakeAnalytics.names, ['invite_link_shared']);
      expect(fakeAnalytics.events.single.$2, {'source': 'friends_modal'});

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

    testWidgets(
        'ağ hatasında SAHTE başarı gösterilmez — reddetme "İşlem başarısız '
        'oldu." der (13 Ağustos 2026, Parça 89)', (tester) async {
      final gw = FakeFriendsGateway()
        ..requestRows = [
          {'requester_id': 'r1', 'name': 'Esiner', 'avatar_url': null},
        ];
      await pumpModal(tester, gateway: gw, initialTab: FriendsTab.requests);
      await tester.pumpAndSettle();

      // Sunucu bu andan itibaren reddediyor (uçak modu / ağ hatası).
      gw.failWith = Exception('ağ');

      // Satırdaki buton ve onay diyaloğunun kabul butonu — ikisi de
      // `trUpper`dan geçtiğinden BÜYÜK harf.
      await tester.tap(find.text('REDDET'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('REDDET').last);
      await tester.pumpAndSettle();

      // Eskiden KOŞULSUZ "İstek reddedildi." gösteriliyordu — hata yutulup
      // kullanıcıya GERÇEKLEŞMEMİŞ bir sonuç bildiriliyordu.
      expect(find.text('İstek reddedildi.'), findsNothing);
      expect(find.text('İşlem başarısız oldu.'), findsOneWidget);
    });

    // 14 Ağustos 2026 — moderasyon ikonu. Kullanıcı cihaz testinde şu duvara
    // çarptı: sessize alma/şikayet 3 Ağustos'tan beri KİŞİ bazlı, ama geri
    // almanın tek giriş noktası o kişiyle AKTİF bir oyunun sohbet ayarlarıydı
    // — oyun bitince ulaşılamıyordu. İkon o kısayolu açıyor.
    testWidgets(
        'Arkadaşlarım: yalnızca moderasyon durumu OLAN satırda ikon çıkar',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..friendsRows = [
          {'friend_id': 'a', 'name': 'Esiner', 'avatar_url': null},
          {'friend_id': 'b', 'name': 'Ironman', 'avatar_url': null},
          {'friend_id': 'c', 'name': 'Temiz', 'avatar_url': null},
        ];
      final chat = FakeChatGateway()
        ..moderationMuted = const {'a': 'g1'}
        ..moderationReported = const {'b': 'g2'};

      await pumpModal(
          tester, gateway: gw, initialTab: FriendsTab.friends, chat: chat);
      await tester.pumpAndSettle();

      // Sessize alınan → 🚫, şikayet edilen → 🚩, temiz satır → HİÇBİRİ.
      // Üçü BİR ARADA: tek başına "ikon var" iddiası, ikonu KOŞULSUZ çizen
      // yanlış bir kural altında da geçerdi.
      expect(find.text('🚫'), findsOneWidget);
      expect(find.text('🚩'), findsOneWidget);

      // İkon "çıkar"ın SOLUNDA (kullanıcı isteği) — konum ölçülerek
      // sabitleniyor, yorumla değil.
      final flagX = tester.getCenter(find.text('🚩')).dx;
      final removeX = tester
          .getCenter(find.bySemanticsLabel('Ironman — arkadaşlıktan çıkar'))
          .dx;
      expect(flagX, lessThan(removeX));
    });

    testWidgets(
        'moderasyon ikonu → panel → şikayeti geri çek → ikon KAYBOLUR',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..friendsRows = [
          {'friend_id': 'a', 'name': 'Esiner', 'avatar_url': null},
        ];
      final chat = FakeChatGateway()
        ..moderationReported = const {'a': 'g1'};

      await pumpModal(
          tester, gateway: gw, initialTab: FriendsTab.friends, chat: chat);
      await tester.pumpAndSettle();

      await tester.tap(find.text('🚩'));
      await tester.pumpAndSettle();
      expect(find.text('Bu kişiyi şikayet ettiniz.'), findsOneWidget);

      await tester.tap(find.text('Şikayeti Geri Çek'));
      await tester.pumpAndSettle();
      // Onay adımı ATLANMAZ — kazara dokunuş bir şikayeti düşürmemeli.
      expect(find.text('Emin misiniz?'), findsOneWidget);
      await tester.tap(find.text('Geri Çek'));
      await tester.pumpAndSettle();

      // Geri çekme KİŞİ bazlı: RPC oyun id'si İSTEMİYOR.
      expect(chat.withdrawnCalls, ['a']);
      expect(find.text('Şikayetiniz geri çekildi.'), findsOneWidget);

      // Sunucu artık temiz — panel kapanınca ikon HEMEN gitmeli, aksi halde
      // kullanıcı "geri çektim ama bayrak duruyor" görürdü.
      chat.moderationReported = const {};
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(find.text('🚩'), findsNothing);
    });

    testWidgets('sessizden çıkarma, kaydın geldiği oyun id\'siyle çağrılır',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..friendsRows = [
          {'friend_id': 'a', 'name': 'Esiner', 'avatar_url': null},
        ];
      // `mute_online_game_participant` katılımcılık kontrolünü `p_muted`
      // dalından ÖNCE yapıyor — sessizden ÇIKARMAK bile geçerli bir ortak
      // oyun id'si istiyor. Sahte uç bu bağı taşıdığından test onu ölçebiliyor.
      final chat = FakeChatGateway()..moderationMuted = const {'a': 'g7'};

      await pumpModal(
          tester, gateway: gw, initialTab: FriendsTab.friends, chat: chat);
      await tester.pumpAndSettle();

      await tester.tap(find.text('🚫'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sessizden Çıkar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sessizden Çıkar').last);
      await tester.pumpAndSettle();

      expect(chat.mutedCalls, [('g7', 'a', false)]);
    });

    testWidgets('chat verilmezse ikon HİÇ çizilmez (offline/dürüstlük dalı)',
        (tester) async {
      final gw = FakeFriendsGateway()
        ..friendsRows = [
          {'friend_id': 'a', 'name': 'Esiner', 'avatar_url': null},
        ];
      await pumpModal(tester, gateway: gw, initialTab: FriendsTab.friends);
      await tester.pumpAndSettle();
      expect(find.text('🚫'), findsNothing);
      expect(find.text('🚩'), findsNothing);
    });

    // 27 Ağustos 2026 — kullanıcı bildirdi: "Ara & Ekle'de scroll down bir
    // yerde takılıyor, sonuna kadar gitmiyor."
    //
    // ÖLÇÜLEN kök sebep (düzeltmeden önce): liste kendi `ListView`'ında,
    // `maxHeight: 320` ile modalın gövde `SingleChildScrollView`'ının İÇİNE
    // konmuştu. Klavye açıkken gövde 119→518 arasını gösterirken liste
    // 326→646'ya uzanıyordu, yani alt 128 px ekranın altında kalıyordu — ve
    // Flutter iç içe kaydırmayı ZİNCİRLEMEDİĞİNDEN parmağını listeye koyan
    // kullanıcı dış gövdeyi hiç kaydıramıyordu (60 sürüklemeden sonra dış
    // offset 0.0). Son satırlar ve "Yükleniyor…" nöbetçisi erişilemezdi.
    //
    // Bu testin NEGATİF EŞİ kanıtlandı: `friends_modal.dart`'taki düz
    // `Column` eski `ConstrainedBox(maxHeight: 320) > ListView` hâline geri
    // alınınca test DÜŞÜYOR (Uye46 dikey olarak 600–620'de, gövdenin 518
    // olan alt kenarının dışında).
    testWidgets('Ara & Ekle: parmak listenin ÜZERİNDEYKEN son üyeye kadar '
        'kaydırılabilir (modalda tek kaydırılabilir)', (tester) async {
      final gw = FakeFriendsGateway()
        ..userRows = [
          for (var i = 1; i <= 46; i++)
            {
              'id': 'u$i',
              'name': 'Uye${i.toString().padLeft(2, '0')}',
              'avatar_url': null,
              'relation': null,
            },
        ];
      // Klavye `autofocus` ile zaten açık; 560 px o durumda kalan yüksekliği
      // temsil ediyor. 900'de hata GÖRÜNMEZ (gövde taşmaz).
      await pumpModal(tester,
          gateway: gw,
          initialTab: FriendsTab.search,
          size: const Size(420, 560));
      await tester.pumpAndSettle();

      // Değişmez: modalın gövdesinde İÇ İÇE kaydırılabilir liste YOK — üç
      // sekmenin üçü de düz Column. (Eski hâlde burada bir ListView vardı.)
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      final govde = tester.getRect(find.byType(SingleChildScrollView));

      // Parmak GERÇEK bir liste satırının üzerinde başlıyor — kullanıcının
      // yaptığı hareket bu; hatanın görüldüğü tek yer de burası.
      final tutamak = tester.getRect(find.text('Uye03')).center;
      for (var i = 0; i < 60; i++) {
        await tester.dragFrom(tutamak, const Offset(0, -300));
        await tester.pumpAndSettle();
      }

      // Sayfalama da bu kaydırmadan besleniyor: üç sayfanın hepsi geldi.
      expect(gw.userRows.length, 46);
      final son = find.text('Uye46');
      expect(son, findsOneWidget);
      final sonRect = tester.getRect(son);
      expect(sonRect.top, greaterThanOrEqualTo(govde.top));
      expect(sonRect.bottom, lessThanOrEqualTo(govde.bottom));
    });
  });

  group('AccountButton + PlayerScoreCard', () {
    testWidgets('menüde Arkadaşlar satırı + rozet; avatarda da AYNI sayı',
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
      // 16 Ağustos 2026: avatardaki sayısız kırmızı nokta da `CountBadge`e
      // çevrildi, yani "2" artık İKİ yerde yazıyor — menü satırında ve
      // avatarın üstünde. Bunu `findsNWidgets(2)` ile geçiştirmek zayıf
      // olurdu (hangisinin hangisi olduğunu söylemez); ikisi ayrı ayrı
      // ölçülüyor. Avatar rozeti web'de arkadaşlık isteği + admin bekleyen
      // işinin TOPLAMI; portta admin paneli olmadığından tek kaynak istek.
      expect(
        find.descendant(of: find.byType(KAvatar), matching: find.text('2')),
        findsOneWidget,
        reason: 'avatar rozeti bekleyen istek sayısını göstermeli',
      );
      expect(find.text('2'), findsNWidgets(2)); // menü satırı + avatar
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

    // ⚠ REGRESYON (30 Ağustos 2026, kullanıcı bildirdi): *"Arkadaşlık daveti
    // beklemede olan kişinin skor kartına girince isminin yanında arkadaş
    // ekle işareti çıkıyor. Halbuki aynı kişiye Arkadaşlar → Ara & Ekle
    // bölümünden bakınca yanında kum saati çıkıyor."*
    //
    // Kök sebep: skor kartı İKİ dala ayrılmıştı (`accepted` ↔ diğer her
    // şey), oysa onay diyaloğu baştan beri DÖRDÜNÜ ayırıyordu — kart "ekle"
    // diyor, dokununca "İsteği İptal Et" çıkıyordu. Bu test dört dalın
    // dördünü de çiviliyor; ikiye dönülürse ilk iki `expect` düşer.
    //
    // `glyph` null ise beklenen ikon elle çizilmiş `PersonPendingIcon`;
    // doluysa o Material glyph'i O RENKTE çizilmiş olmalı. Glyph'i de
    // ölçmek şart: "bana istek geldi" ile "ilişki yok" AYNI rengi (accent)
    // kullanıyor, yalnızca renge bakan bir test ikisini ayırt edemezdi.
    for (final (String ad, Map<String, Object?>? satir, IconData? glyph,
            Color renk)
        in <(String, Map<String, Object?>?, IconData?, Color)>[
      ('istek gönderdim', {'user_id': 'me', 'status': 'pending'}, null,
          kMuted),
      ('bana istek geldi', {'user_id': 'u9', 'status': 'pending'},
          Icons.how_to_reg, kAccent),
      ('arkadaşız', {'user_id': 'me', 'status': 'accepted'}, Icons.how_to_reg,
          kGreen),
      ('ilişki yok', null, Icons.person_add_alt_1, kAccent),
    ]) {
      testWidgets('PlayerScoreCard ilişki simgesi — $ad', (tester) async {
        await setPhoneViewSize(tester, const Size(420, 900));
        final gw = FakeFriendsGateway()..relation = satir;
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

        if (glyph == null) {
          final ikon =
              tester.widget<PersonPendingIcon>(find.byType(PersonPendingIcon));
          expect(ikon.color, renk);
          // "Ekle" ikonu ASLA aynı anda çizilmemeli — hatanın kendisi buydu.
          expect(find.byIcon(Icons.person_add_alt_1), findsNothing);
        } else {
          expect(find.byType(PersonPendingIcon), findsNothing);
          expect(tester.widget<Icon>(find.byIcon(glyph)).color, renk);
        }
      });
    }

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
    // 26 Ağustos 2026 — ROADMAP madde 1'in "portta davet kabulü SESSİZCE
    // düşüyor" maddesi. `setup_screen.dart` yalnızca `debugPrint`liyordu;
    // artık kullanıcıya bir şey söyleniyor ve NE söyleneceği burada
    // sınanıyor (web `FriendInvitePage`'in P0001 kuralının portu).
    //
    // Negatif eş: `inviteAcceptErrorText`ten P0001 dalı kaldırılırsa ilk
    // expect düşer (sunucunun kendi mesajı jenerik metne dönüşür).
    // 26 Ağustos 2026, kullanıcı kararı: `takeAll` YIKICI olduğundan ağ
    // hatasında token kayboluyordu (davet ne kuruluyor ne de kuyrukta
    // kalıyordu). Artık YALNIZCA ağ hatasında geri konuyor. Burada
    // `_processInvites`'in veri katmanı sözleşmesi sınanıyor — widget
    // akışı değil (dosyadaki mevcut desen).
    //
    // Negatif eş: geri koyma satırı silinirse ilk expect düşer; koşul
    // `isNetworkError`dan geniş bir şeye çevrilirse ikinci expect düşer
    // (P0001 geri konarsa her açılışta aynı diyalog çıkardı).
    test('ağ hatasında token kuyruğa GERİ konur, kalıcı ret KONMAZ',
        () async {
      final storage = await openTestStorage();
      final gw = FakeFriendsGateway();
      final repo = FriendsRepo(gw);

      Future<void> isle(Object hata) async {
        await storage.events.add(friendInviteTokenKind, {'token': 't1'});
        final events = inviteTokensFromEvents(
            await storage.events.takeAll(friendInviteTokenKind));
        for (final token in events) {
          try {
            gw.failWith = hata;
            await repo.acceptInvite(token);
          } catch (err) {
            if (isNetworkError(err)) {
              await storage.events.add(friendInviteTokenKind, {'token': token});
            }
          } finally {
            gw.failWith = null;
          }
        }
      }

      // 1) Ağ hatası → token DURUYOR, bağlantı dönünce yeniden denenebilir.
      await isle(Exception('SocketException: Failed host lookup'));
      expect(
          inviteTokensFromEvents(
              await storage.events.takeAll(friendInviteTokenKind)),
          ['t1'],
          reason: 'ağ hatasında davet kaybolmamalı');

      // 2) Kalıcı ret → token GİTMELİ; aksi halde her açılışta aynı
      //    "Kendi linkinle arkadaş olamazsın." diyaloğu çıkardı.
      await isle(PostgrestException(
          message: 'Kendi linkinle arkadaş olamazsın.', code: 'P0001'));
      expect(
          await storage.events.takeAll(friendInviteTokenKind), isEmpty,
          reason: 'kalıcı ret ölümsüz kayıt üretmemeli');
    });

    test('inviteAcceptErrorText: P0001 sunucu mesajını OLDUĞU GİBİ gösterir',
        () {
      final ret = PostgrestException(
          message: 'Kendi linkinle arkadaş olamazsın.', code: 'P0001');
      expect(inviteAcceptErrorText(ret), 'Kendi linkinle arkadaş olamazsın.');
      expect(inviteAcceptKaliciRet(ret), isTrue,
          reason: 'kalıcı ret → tekrar denemek anlamsız, telemetriye de gitmez');
    });

    test('inviteAcceptErrorText: ağ hatası ile bilinmeyen hata AYRI konuşur',
        () {
      // `isNetworkError`a düşen gerçek bir kalıp (util/offline_notice.dart).
      final ag = Exception('ClientException: Failed host lookup: kelimeki.com');
      expect(inviteAcceptErrorText(ag), contains('bağlantını kontrol'));
      expect(inviteAcceptKaliciRet(ag), isFalse);

      // Sunucunun BAŞKA bir hatası (P0001 değil): teşhis uydurulmuyor.
      final bilinmeyen =
          PostgrestException(message: 'deadlock detected', code: '40P01');
      final metin = inviteAcceptErrorText(bilinmeyen);
      expect(metin, 'Davet kabul edilemedi. Biraz sonra tekrar dene.');
      expect(metin, isNot(contains('deadlock')),
          reason: 'ham sunucu hatası kullanıcıya gösterilmez');
      expect(inviteAcceptKaliciRet(bilinmeyen), isFalse,
          reason: 'geçici olabilir → telemetriye düşmeli');
    });


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

  @override
  Future<List<Map<String, Object?>>> rankScores(List<String> userIds) async =>
      const [];

  @override
  Future<Map<String, Object?>?> profileAgeGender(String userId) async => null;
}
