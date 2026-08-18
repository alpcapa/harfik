// Hesap menüsü (AccountButton) — web UserMenu.tsx paritesi (Parça 28).
// Kapsam: isim başlığının altındaki tıklanabilir k-lig satırı (AYRI bir
// "Sıralama" listesi maddesi DEĞİL), madde sırası (Arkadaşlar → Skor Kartı
// → Nasıl Oynanır? → Hesap Ayarları → Çıkış Yap) ve Çıkış Yap'ın kendi
// üstündeki çizgi. Gerçek Supabase ağı YOK — StatsGateway/FriendsGateway
// sahte.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/rank/rank_seal.dart';
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

  @override
  Future<List<Map<String, Object?>>> rankScores(List<String> userIds) async =>
      [for (final id in userIds) {'user_id': id, 'total_score': 47}];
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
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: AccountButton(auth: auth, stats: stats, friends: friends),
        ),
      ),
    ));
    await tester.pump();
    // Tooltip kaldırıldığından (9 Ağustos 2026) artık byTooltip ile
    // bulunamıyor — widget tipiyle bulmak zaten daha sağlam.
    await tester.tap(find.byType(PopupMenuButton<String>));
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
    final signOutY = topOf(find.textContaining('Çıkış Yap'));

    expect(friendsY, lessThan(scoreY),
        reason: 'Arkadaşlar, Skor Kartı\'ndan ÖNCE gelmeli (web sırası)');
    expect(scoreY, lessThan(helpY));
    expect(helpY, lessThan(settingsY));
    expect(settingsY, lessThan(signOutY));
    // Çıkış Yap'ın kendi üstünde tek bir çizgi olmalı — isim başlığının
    // altında DEĞİL (eski davranış), Hesap Ayarları ile Çıkış Yap arasında.
    // Çizgi artık bir `PopupMenuDivider` DEĞİL (bkz. Parça 30 testleri) —
    // burada yalnızca sıra doğrulanıyor.
  });

  testWidgets(
      'regresyon (Parça 29): satır boyu web (py-2.5) gibi kompakt — '
      'Flutter\'ın 48px minimum dokunma yüksekliği kullanılmıyor, menü '
      'genişliği web\'in w-56 (224px) sabitine yakınsıyor', (tester) async {
    final stats = StatsRepo(_FakeStatsGateway());
    final friends = FriendsRepo(_FakeFriendsGateway());
    await pumpMenu(tester, stats: stats, friends: friends);

    double topOf(Finder f) => tester.getTopLeft(f).dy;
    final rowSpacing =
        topOf(find.textContaining('Skor Kartı')) -
            topOf(find.textContaining('Arkadaşlar'));
    // Web satırı ~py-2.5 (20px dolgu) + 12px punto ≈ 35-40px — Flutter'ın
    // varsayılan `kMinInteractiveDimension`ı (48px) kullanılıyorsa bu her
    // zaman >=48 olurdu.
    expect(rowSpacing, lessThan(44),
        reason: 'Satır aralığı hâlâ Flutter\'ın 48px varsayılanına yakın — '
            'ölçülen=$rowSpacing');

    final itemBox = tester.getSize(find
        .ancestor(
            of: find.textContaining('Arkadaşlar'), matching: find.byType(SizedBox))
        .first);
    expect(itemBox.width, closeTo(200, 1),
        reason: 'Satır içerik genişliği sabitlenmemiş — menü web\'in '
            'w-56 sabitinden belirgin genişleyebilir');
  });

  testWidgets(
      'regresyon (Parça 30): TÜM satırlar tek satıra sığıyor — emoji '
      'yedek fontu "Nasıl Oynanır?"/"Hesap Ayarları"yı ikinci satıra '
      'sarmıyor (kök sebep, Parça 29\'un ardından hâlâ fazla boşluk '
      'kalmasının asıl sebebiydi)', (tester) async {
    final stats = StatsRepo(_FakeStatsGateway());
    final friends = FriendsRepo(_FakeFriendsGateway());
    await pumpMenu(tester, stats: stats, friends: friends);

    double topOf(Finder f) => tester.getTopLeft(f).dy;
    final gaps = [
      topOf(find.textContaining('Skor Kartı')) -
          topOf(find.textContaining('Arkadaşlar')),
      topOf(find.textContaining('Nasıl Oynanır?')) -
          topOf(find.textContaining('Skor Kartı')),
      topOf(find.textContaining('Hesap Ayarları')) -
          topOf(find.textContaining('Nasıl Oynanır?')),
    ];
    // İki satıra sarmış bir madde bu farkı ~17px daha büyük yapardı
    // (ölçülen: sarmadan 38-39px, sararsa 54-72px) — tüm satırlar AYNI
    // (tek satırlık) yükseklikte olmalı.
    for (final g in gaps) {
      expect(g, closeTo(gaps.first, 2),
          reason: 'Satırlardan biri ikiye sarmış görünüyor — ölçülen '
              'aralıklar: $gaps');
    }
  });

  testWidgets(
      'regresyon (Parça 30): isim başlığının ALTINDA ince bir çizgi var '
      '("Arkadaşlar"ın üstünde) — web `border-b border-border`, Parça '
      '28\'de kaybolmuştu; Çıkış Yap\'ın üstündeki çizgi hâlâ tek bir '
      'satır KAPLAMIYOR (PopupMenuDivider DEĞİL, ince kenar çizgisi)',
      (tester) async {
    final stats = StatsRepo(_FakeStatsGateway());
    final friends = FriendsRepo(_FakeFriendsGateway());
    await pumpMenu(tester, stats: stats, friends: friends);

    // Artık ayrı bir PopupMenuDivider() yok — ikisi de Container border'ı.
    expect(find.byType(PopupMenuDivider), findsNothing);

    // Başlığın altındaki Container'ın decoration'ı bottom border taşımalı.
    final headerContainer = tester.widget<Container>(find
        .ancestor(
            of: find.text('Ironman'), matching: find.byType(Container))
        .first);
    final headerDecoration = headerContainer.decoration as BoxDecoration;
    expect(headerDecoration.border?.bottom.width, 1);

    // Çıkış Yap satırının kendi üst kenarı da aynı şekilde çizgili olmalı,
    // ama bu bir PopupMenuDivider'ın 16px'lik AYRI satırı değil —
    // Hesap Ayarları ile Çıkış Yap arasındaki boşluk normal satır
    // aralığına (< 44px) yakın kalmalı.
    final signOutContainer = tester.widget<Container>(find
        .ancestor(
            of: find.textContaining('Çıkış Yap'), matching: find.byType(Container))
        .first);
    final signOutDecoration = signOutContainer.decoration as BoxDecoration;
    expect(signOutDecoration.border?.top.width, 1);

    double topOf(Finder f) => tester.getTopLeft(f).dy;
    final gap = topOf(find.textContaining('Çıkış Yap')) -
        topOf(find.textContaining('Hesap Ayarları'));
    expect(gap, lessThan(44),
        reason: 'Çıkış Yap\'ın üstündeki çizgi hâlâ 16px\'lik ayrı bir '
            'PopupMenuDivider satırı gibi davranıyor — ölçülen=$gap');
  });

  testWidgets(
      'regresyon (Parça 30): menü kartının kendi üst/alt dolgusu (varsayılan '
      '`menuPadding`, 8px) sıfırlandı — web\'in kartı hiç ekstra dolgu '
      'taşımıyor, içerik doğrudan başlığın kendi py-3\'üyle başlıyor',
      (tester) async {
    final stats = StatsRepo(_FakeStatsGateway());
    final friends = FriendsRepo(_FakeFriendsGateway());
    await pumpMenu(tester, stats: stats, friends: friends);

    final cardFinder = find.byWidgetPredicate(
        (w) => w is Material && w.type == MaterialType.card);
    final cardTop = tester.getTopLeft(cardFinder).dy;
    final cardBottom = tester.getRect(cardFinder).bottom;
    final headerTop = tester.getTopLeft(find.text('Ironman')).dy;
    final signOutBottom = tester.getBottomLeft(find.textContaining('Çıkış Yap')).dy;

    // Varsayılan `menuPadding` (8px) hâlâ devredeyse bu farklar sırasıyla
    // ~20 (8+12 başlık dolgusu) ve ~18 (8+10 satır dolgusu) olurdu.
    expect(headerTop - cardTop, closeTo(12, 2),
        reason: 'Kartın üstünde hâlâ fazladan ~8px boşluk var — '
            'ölçülen=${headerTop - cardTop}');
    expect(cardBottom - signOutBottom, closeTo(10, 2),
        reason: 'Kartın altında hâlâ fazladan ~8px boşluk var — '
            'ölçülen=${cardBottom - signOutBottom}');
  });

  testWidgets(
      'regresyon (Parça 81): yuvarlak avatarın ink vurgusu da DAİRESEL — '
      'hover/basılı durumda kare köşeler görünmemeli', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final auth = AuthService.fake(user: _fakeUser(), profile: _ironman);
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: AccountButton(auth: auth),
        ),
      ),
    ));
    await tester.pump();

    // `PopupMenuButton`, `child` verildiğinde onu
    // `InkWell(borderRadius: widget.borderRadius, …)` ile sarar
    // (`popup_menu.dart:1712`) ve bu parametrenin VARSAYILANI YOKTUR.
    // Null bırakılırsa ink dikdörtgen boyanır ve yuvarlak avatarın dışında
    // kalan köşeler görünür olur — kullanıcının bildirdiği hata buydu.
    //
    // Bu test YAPISAL, çünkü basılı durumu piksel piksel yakalayan bir
    // test bu binding'de sonlanmıyor (menü açılış animasyonu + M3
    // InkSparkle `pumpAndSettle`'ı asıyor). Piksel ölçümü bir kez geçici
    // bir probe ile yapıldı ve düzeltmeyi kanıtladı: basılıyken dairenin
    // DIŞINDA boyanmış piksel 120 → 0 (dokunulmamış durumda zaten 0).
    // Parça 34'ün deseni: bir kez ölç, kalıcı testte sözleşmeyi sabitle.
    final button =
        tester.widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>));
    final size = tester.getSize(find.byType(PopupMenuButton<String>));
    expect(button.borderRadius, isNotNull,
        reason: 'borderRadius null — ink dikdörtgen boyanır, avatarın '
            'köşeleri görünür');
    expect(button.borderRadius, BorderRadius.circular(size.width / 2),
        reason: 'Yarıçap kutunun yarısı olmalı ki kare kutu tam daireye '
            'kırpılsın — kutu=$size');

    // Aynı yarıçap gerçekten InkWell'e iniyor mu (asıl boyayan o).
    final ink = tester.widget<InkWell>(find.descendant(
      of: find.byType(PopupMenuButton<String>),
      matching: find.byType(InkWell),
    ));
    expect(ink.borderRadius, BorderRadius.circular(size.width / 2));
  });
  testWidgets(
      'hesap menüsünde ismin YANINDA rütbe mührü var (18 Ağustos 2026) — '
      '18px, k-lig satırındaki 34px başlık mührüyle KARIŞTIRMA',
      (tester) async {
    final stats = StatsRepo(_FakeStatsGateway());
    await pumpMenu(tester, stats: stats);

    // Sahte uç 47 puan döndürüyor → Çaylak. Puan ZATEN `myRank`ta olduğundan
    // ekstra bir sorgu yok; mühür ismin hemen sağında.
    final seals = tester.widgetList<RankSeal>(find.byType(RankSeal)).toList();
    expect(seals, isNotEmpty, reason: 'isim yanında mühür çizilmemiş');
    expect(seals.first.size, 18,
        reason: 'boy satırın 14px puntosuna göre ölçüldü (web ile aynı)');

    // Mühür ismin SAĞINDA olmalı, solunda değil.
    final nameX = tester.getTopRight(find.text('Ironman')).dx;
    final sealX = tester.getTopLeft(find.byType(RankSeal).first).dx;
    expect(sealX, greaterThanOrEqualTo(nameX));
  });
}
