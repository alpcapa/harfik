// Hesap menüsü (AccountButton) — web UserMenu.tsx paritesi (Parça 28).
// Kapsam: isim başlığının altındaki tıklanabilir k-lig satırı (AYRI bir
// "Sıralama" listesi maddesi DEĞİL), madde sırası (Arkadaşlar → Skor Kartı
// → Nasıl Oynanır? → Hesap Ayarları → Çıkış Yap) ve Çıkış Yap'ın kendi
// üstündeki çizgi. Gerçek Supabase ağı YOK — StatsGateway/FriendsGateway
// sahte.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/stats_api.dart';
import 'package:kelimeki/src/ui/auth/account_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

User _fakeUser() => User(
      id: 'u-test',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: 'alp.capa@hotmail.com',
    );

const _ironman = KProfile(id: 'u-test', displayName: 'Ironman');

class _FakeStatsGateway implements StatsGateway {
  @override
  Future<Map<String, Object?>?> playerStats(String userId, int? playerCount) async =>
      null;

  @override
  Future<List<Map<String, Object?>>> leaderboard(int limit, int offset) async =>
      const [];

  @override
  Future<Map<String, Object?>?> myLeaderboardRank(String userId) async =>
      {'rank': 3, 'total_score': 47};
}

class _FakeFriendsGateway implements FriendsGateway {
  @override
  String? get currentUserId => 'u-test';
  @override
  Future<List<Map<String, Object?>>> searchUsers(String query) async => const [];
  @override
  Future<List<Map<String, Object?>>> listUsers(int offset, int limit) async =>
      const [];
  @override
  Future<String> sendRequest(String targetId) async => 'pending';
  @override
  Future<void> notifyFriendRequest(String friendId) async {}
  @override
  Future<void> acceptRequest(String requesterId) async {}
  @override
  Future<void> deleteRelation(String otherId) async {}
  @override
  Future<List<Map<String, Object?>>> listFriends() async => const [];
  @override
  Future<List<Map<String, Object?>>> listIncomingRequests() async => const [];
  @override
  Future<Map<String, Object?>?> relationRow(String targetId) async => null;
  @override
  Future<String?> createInviteToken() async => 't';
  @override
  Future<String?> inviteInfo(String token) async => null;
  @override
  Future<String?> acceptInvite(String token) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Future<void> pumpMenu(WidgetTester tester,
      {StatsRepo? stats, FriendsRepo? friends}) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final auth = AuthService.fake(user: _fakeUser(), profile: _ironman);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: AccountButton(auth: auth, stats: stats, friends: friends),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('Hesap menüsü'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'regresyon (Parça 28): k-lig ayrı bir "Sıralama" maddesi DEĞİL — '
      'isim başlığının altında tıklanabilir #sıra · puan satırı',
      (tester) async {
    final stats = StatsRepo(_FakeStatsGateway());
    await pumpMenu(tester, stats: stats);

    // Web'de ayrı bir liste maddesi hiç yok — "Sıralama" metni hiçbir
    // yerde görünmemeli.
    expect(find.text('Sıralama'), findsNothing);
    // Bunun yerine isim başlığının hemen altında "#3 · 47 puan" gösterilir
    // (rank/puan sahte StatsGateway'den geliyor).
    expect(find.textContaining('#3'), findsOneWidget);
    expect(find.textContaining('47'), findsOneWidget);

    // Bu satıra dokunmak Leaderboard'u (k-lig) açmalı.
    await tester.tap(find.textContaining('#3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('k-lig, senin gibi'), findsOneWidget);
  });

  testWidgets(
      'regresyon (Parça 28): madde sırası web ile aynı — Arkadaşlar → '
      'Skor Kartı → Nasıl Oynanır? → Hesap Ayarları → (çizgi) → Çıkış Yap',
      (tester) async {
    final stats = StatsRepo(_FakeStatsGateway());
    final friends = FriendsRepo(_FakeFriendsGateway());
    await pumpMenu(tester, stats: stats, friends: friends);

    double topOf(Finder f) => tester.getTopLeft(f).dy;
    final friendsY = topOf(find.textContaining('Arkadaşlar'));
    final scoreY = topOf(find.textContaining('Skor Kartı'));
    final helpY = topOf(find.textContaining('Nasıl Oynanır?'));
    final settingsY = topOf(find.textContaining('Hesap Ayarları'));
    final dividerY = topOf(find.byType(PopupMenuDivider));
    final signOutY = topOf(find.textContaining('Çıkış Yap'));

    expect(friendsY, lessThan(scoreY),
        reason: 'Arkadaşlar, Skor Kartı\'ndan ÖNCE gelmeli (web sırası)');
    expect(scoreY, lessThan(helpY));
    expect(helpY, lessThan(settingsY));
    // Çıkış Yap'ın kendi üstünde tek bir çizgi olmalı — isim başlığının
    // altında DEĞİL (eski davranış), Hesap Ayarları ile Çıkış Yap arasında.
    expect(find.byType(PopupMenuDivider), findsOneWidget);
    expect(dividerY, greaterThan(settingsY));
    expect(dividerY, lessThan(signOutY));
  });
}
