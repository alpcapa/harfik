// Arkadaşlık sistemi veri katmanı — web `src/lib/api.ts`'in arkadaşlık
// bölümünün portu (searchUsersForFriend/listUsersForFriend/sendFriendRequest/
// respondFriendRequest/removeFriend/fetchFriends/fetchFriendRelation/
// fetchIncomingFriendRequests/createFriendInviteLink/fetchFriendInviteInfo/
// acceptFriendInvite), GamesRepo'daki aynı gateway/repo bölünmesiyle.
//
// Web'den taşınan sözleşmeler:
// - RPC'ler security definer; e-posta HİÇBİR uçtan dönmez.
// - `sendFriendRequest` doğrudan tablo insert'i (RLS insert_self); karşı
//   taraftan bekleyen istek varsa sunucu trigger'ı anında 'accepted'a
//   çevirir — dönüş değeri UI'a taşınır. Yalnızca hâlâ 'pending' ise
//   `notify-friend-request` Edge Function'ı fire-and-forget çağrılır
//   (karşılıklı anında kabulde habersiz kalınan bir şey yok).
// - `removeFriend` durumdan bağımsız siler — hem arkadaşlıktan çıkma hem
//   gönderilmiş isteği iptal aynı fonksiyon (web'deki aynı not).
// - Listeler `trCompare` ile CLIENT tarafında sıralanır (backend collation
//   Türkçe değil); sayfalı tüm-üyeler listesinde her sayfadan sonra TÜM
//   birikmiş liste yeniden sıralanır (sayfa sınırı hatası — web dersi).
//
// Tek bilinçli sapma: liste uçları ağ hatasında web gibi `[]` değil `null`
// döner — `[]` UI'da yanlış "hiç arkadaşın yok" gösterirdi (StatsRepo/
// CloudSaveRepo'daki aynı mobil karar; UI null'da eski veriyi/yükleniyor
// durumunu korur).
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kelimeki_core/kelimeki_core.dart' show trCompare;
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, PostgrestException;

import '../config/env.dart' show webOrigin;
import '../util/deep_link.dart' show KFriendInviteLink, parseDeepLink;
import '../util/offline_notice.dart' show isNetworkError;

/// Web `FriendRelation` — iki kullanıcı arasındaki mevcut ilişki.
enum FriendRelation { accepted, pendingOutgoing, pendingIncoming }

class FriendRow {
  final String friendId;
  final String name;
  final String? avatarUrl;
  const FriendRow(
      {required this.friendId, required this.name, this.avatarUrl});
}

class IncomingFriendRequest {
  final String requesterId;
  final String name;
  final String? avatarUrl;
  const IncomingFriendRequest(
      {required this.requesterId, required this.name, this.avatarUrl});
}

/// Web `FriendSearchResult` — `relation` null ise hiçbir ilişki yok
/// ("Ekle" gösterilir); 'self' sunucudan gelebilir ama arama kendi
/// hesabını zaten döndürmez, UI'da ayrıca ele alınmaz.
class FriendCandidate {
  final String id;
  final String name;
  final String? avatarUrl;
  final FriendRelation? relation;
  const FriendCandidate(
      {required this.id, required this.name, this.avatarUrl, this.relation});

  FriendCandidate withRelation(FriendRelation? r) =>
      FriendCandidate(id: id, name: name, avatarUrl: avatarUrl, relation: r);
}

FriendRelation? relationFromDb(String? v) => switch (v) {
      'accepted' => FriendRelation.accepted,
      'pending_outgoing' => FriendRelation.pendingOutgoing,
      'pending_incoming' => FriendRelation.pendingIncoming,
      _ => null,
    };

/// Web `buildInviteUrl` — uygulamanın origin'i olmadığından sabit
/// `webOrigin`. Link BİLEREK https (kelimeki:// değil): alıcı üye
/// olmayabilir, link her cihazda/webde açılıp kayıt akışını sunabilmeli
/// (uygulama kuruluysa Android App Links ileride onu uygulamaya düşürür).
///
/// `?ref=arkadas` ZORUNLU (21 Ağustos 2026, ROADMAP #7) — web'in aynı
/// fonksiyonuyla BİREBİR: etiket olmadan davetle gelip üye olan herkes admin
/// panelindeki Kaynak Hunisi'nde `direkt` satırına düşüyor ve gerçek doğrudan
/// trafiği şişiriyordu. Portta damgayı YAKALAYAN bir kod yok (web'in
/// `visitTracking.ts`i porta hiç girmedi) ama bu link WEB'de açılıyor, yani
/// yakalamayı web tarafı yapıyor.
///
/// `parseInviteToken` bundan ETKİLENMEZ: `uri.pathSegments` sorgu dizesini
/// içermez (ölçüldü/okundu) — gelen link uygulamaya düşerse token yine
/// doğru çözülür.
String buildInviteUrl(String token) => '$webOrigin/davet/$token?ref=arkadas';

/// Web `INVITE_SHARE_TEXT`.
const String inviteShareText = "Kelimeki'de birlikte kelime oyunu oynayalım!";

/// Bir URI'nin arkadaş daveti olup olmadığını çözer — iki biçim:
/// `kelimeki://davet/<token>` (custom şema; host='davet') ve
/// `https://kelimeki.com/davet/<token>` (web linki, App Links ile düşerse).
/// Davet değilse null (auth callback'leri vb. buradan sessizce geçer).
///
/// 28 Ağustos 2026'dan beri ayrıştırmayı KENDİSİ yapmıyor: biçim bilgisi
/// `util/deep_link.dart`'ta tek noktada duruyor (gerekçe orada). Bu sarmalayıcı
/// duruyor çünkü `FriendInviteInbox`ın tek ihtiyacı token — ona bir sealed
/// tip döndürüp her çağrı yerinde `switch` yazdırmanın kazancı yok.
String? parseInviteToken(Uri uri) {
  final link = parseDeepLink(uri);
  return link is KFriendInviteLink ? link.token : null;
}

abstract class FriendsGateway {
  String? get currentUserId;
  Future<List<Map<String, Object?>>> searchUsers(String query);
  Future<List<Map<String, Object?>>> listUsers(int offset, int limit);

  /// Dönüş: insert sonrası satırın durumu ('pending' | 'accepted').
  Future<String> sendRequest(String targetId);
  Future<void> notifyFriendRequest(String friendId);
  Future<void> acceptRequest(String requesterId);
  Future<void> deleteRelation(String otherId);
  Future<List<Map<String, Object?>>> listFriends();
  Future<List<Map<String, Object?>>> listIncomingRequests();
  Future<Map<String, Object?>?> relationRow(String targetId);
  Future<String?> createInviteToken();
  Future<String?> inviteInfo(String token);
  Future<String?> acceptInvite(String token);
}

class SupabaseFriendsGateway implements FriendsGateway {
  final SupabaseClient client;
  SupabaseFriendsGateway(this.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  List<Map<String, Object?>> _rows(dynamic data) =>
      [for (final r in (data as List? ?? const [])) (r as Map).cast<String, Object?>()];

  @override
  Future<List<Map<String, Object?>>> searchUsers(String query) async =>
      _rows(await client
          .rpc('search_users_for_friend', params: {'p_query': query}));

  @override
  Future<List<Map<String, Object?>>> listUsers(int offset, int limit) async =>
      _rows(await client.rpc('list_users_for_friend',
          params: {'p_offset': offset, 'p_limit': limit}));

  @override
  Future<String> sendRequest(String targetId) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Oturum açık değil.');
    final row = await client
        .from('friend_requests')
        .insert({'user_id': user.id, 'friend_id': targetId})
        .select('status')
        .single();
    return row['status'] == 'accepted' ? 'accepted' : 'pending';
  }

  @override
  Future<void> notifyFriendRequest(String friendId) async {
    await client.functions
        .invoke('notify-friend-request', body: {'friend_id': friendId});
  }

  @override
  Future<void> acceptRequest(String requesterId) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Oturum açık değil.');
    await client
        .from('friend_requests')
        .update({
          'status': 'accepted',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', requesterId)
        .eq('friend_id', user.id);
  }

  @override
  Future<void> deleteRelation(String otherId) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Oturum açık değil.');
    await client.from('friend_requests').delete().or(
        'and(user_id.eq.${user.id},friend_id.eq.$otherId),'
        'and(user_id.eq.$otherId,friend_id.eq.${user.id})');
  }

  @override
  Future<List<Map<String, Object?>>> listFriends() async =>
      _rows(await client.rpc('list_friends'));

  @override
  Future<List<Map<String, Object?>>> listIncomingRequests() async =>
      _rows(await client.rpc('list_incoming_friend_requests'));

  @override
  Future<Map<String, Object?>?> relationRow(String targetId) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('friend_requests')
        .select('user_id, status')
        .or('and(user_id.eq.${user.id},friend_id.eq.$targetId),'
            'and(user_id.eq.$targetId,friend_id.eq.${user.id})')
        .maybeSingle();
    return row;
  }

  @override
  Future<String?> createInviteToken() async =>
      await client.rpc('create_friend_invite_link') as String?;

  @override
  Future<String?> inviteInfo(String token) async {
    final data = await client
        .rpc('get_friend_invite_info', params: {'p_token': token});
    final row = (data is List && data.isNotEmpty) ? data.first as Map : null;
    return row?['inviter_name'] as String?;
  }

  @override
  Future<String?> acceptInvite(String token) async {
    final data =
        await client.rpc('accept_friend_invite', params: {'p_token': token});
    final row = (data is List && data.isNotEmpty) ? data.first as Map : null;
    return row?['inviter_name'] as String?;
  }
}

class FriendsRepo {
  final FriendsGateway gateway;
  FriendsRepo(this.gateway);

  FriendCandidate _candidate(Map<String, Object?> r) => FriendCandidate(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? 'Anonim',
        avatarUrl: r['avatar_url'] as String?,
        relation: relationFromDb(r['relation'] as String?),
      );

  /// En az 2 karakter — daha kısası web'de hiç RPC'ye gitmiyor.
  Future<List<FriendCandidate>?> search(String query) async {
    try {
      final rows = await gateway.searchUsers(query);
      return [for (final r in rows) _candidate(r)]
        ..sort((a, b) => trCompare(a.name, b.name));
    } catch (e) {
      debugPrint('[Kelimeki] arkadaş araması başarısız: $e');
      return null;
    }
  }

  Future<List<FriendCandidate>?> listUsers(int offset, int limit) async {
    try {
      final rows = await gateway.listUsers(offset, limit);
      // Sıralama ÇAĞIRANDA tamamlanır: sayfalar birikince TÜM liste yeniden
      // sıralanmalı (web dersi) — burada yalnız sayfa içi sıralamak yanıltır,
      // o yüzden ham sayfa dönülür.
      return [for (final r in rows) _candidate(r)];
    } catch (e) {
      debugPrint('[Kelimeki] üye listesi alınamadı: $e');
      return null;
    }
  }

  Future<List<FriendRow>?> friends() async {
    try {
      final rows = await gateway.listFriends();
      return [
        for (final r in rows)
          FriendRow(
            friendId: r['friend_id'] as String,
            name: (r['name'] as String?) ?? 'Anonim',
            avatarUrl: r['avatar_url'] as String?,
          ),
      ]..sort((a, b) => trCompare(a.name, b.name));
    } catch (e) {
      debugPrint('[Kelimeki] arkadaş listesi alınamadı: $e');
      return null;
    }
  }

  /// Bana gelen bekleyen istekler — sıralama RPC'nin kendi sırası
  /// (created_at desc, en yeni önce): bir SEÇİM listesi değil, web'de de
  /// bilinçli olarak trCompare'e çekilMEmişti.
  Future<List<IncomingFriendRequest>?> incomingRequests() async {
    try {
      final rows = await gateway.listIncomingRequests();
      return [
        for (final r in rows)
          IncomingFriendRequest(
            requesterId: r['requester_id'] as String,
            name: (r['name'] as String?) ?? 'Anonim',
            avatarUrl: r['avatar_url'] as String?,
          ),
      ];
    } catch (e) {
      debugPrint('[Kelimeki] gelen istekler alınamadı: $e');
      return null;
    }
  }

  /// Dönüş: sunucunun kararı — karşılıklı istek anında 'accepted' olur;
  /// yalnızca hâlâ pending ise e-posta bildirimi tetiklenir (web parity).
  /// Hatalar FIRLATILIR (web handleSend'in catch'i UI'da).
  Future<FriendRelation> sendRequest(String targetId) async {
    final status = await gateway.sendRequest(targetId);
    if (status == 'accepted') return FriendRelation.accepted;
    unawaitedNotify(targetId);
    return FriendRelation.pendingOutgoing;
  }

  void unawaitedNotify(String targetId) {
    gateway.notifyFriendRequest(targetId).catchError((Object e) {
      debugPrint('[Kelimeki] notifyFriendRequest hatası: $e');
    });
  }

  Future<void> respond(String requesterId, {required bool accept}) =>
      accept
          ? gateway.acceptRequest(requesterId)
          : gateway.deleteRelation(requesterId);

  /// Arkadaşlıktan çıkma VE gönderilmiş isteği iptal — aynı silme.
  Future<void> removeOrCancel(String otherId) =>
      gateway.deleteRelation(otherId);

  /// Web `fetchFriendRelation` — kendi kartında/girişsizken null.
  Future<FriendRelation?> relationWith(String targetId) async {
    final me = gateway.currentUserId;
    if (me == null || me == targetId) return null;
    try {
      final row = await gateway.relationRow(targetId);
      if (row == null) return null;
      if (row['status'] == 'accepted') return FriendRelation.accepted;
      return row['user_id'] == me
          ? FriendRelation.pendingOutgoing
          : FriendRelation.pendingIncoming;
    } catch (e) {
      debugPrint('[Kelimeki] arkadaşlık ilişkisi okunamadı: $e');
      return null;
    }
  }

  /// Kalıcı davet linkinin tam URL'i — token ilk çağrıda oluşur,
  /// sonrakilerde aynı döner (RPC idempotent). Hata → null.
  Future<String?> inviteUrl() async {
    try {
      final token = await gateway.createInviteToken();
      return token == null ? null : buildInviteUrl(token);
    } catch (e) {
      debugPrint('[Kelimeki] davet linki oluşturulamadı: $e');
      return null;
    }
  }

  /// "X seni davet ediyor" önizlemesi — geçersiz/kullanılamaz token → null.
  Future<String?> inviteInfo(String token) async {
    try {
      return await gateway.inviteInfo(token);
    } catch (e) {
      debugPrint('[Kelimeki] davet bilgisi alınamadı: $e');
      return null;
    }
  }

  /// Daveti kabul eder, davet edenin adını döner. Hata FIRLATIR (çağıran
  /// token'ı kuyruğa geri koymaya karar verebilsin diye) — yalnızca
  /// "geçersiz token" sınıfı sunucu retleri değil ağ hataları da.
  Future<String?> acceptInvite(String token) => gateway.acceptInvite(token);
}

/// Davet kabulü düştüğünde kullanıcıya NE denir — web `FriendInvitePage`'in
/// aynı kararının portu (25 Ağustos 2026, `acceptFriendInvite`).
///
/// Üç durum BİLEREK ayrı, çünkü kullanıcının yapabileceği şey farklı:
///
/// 1. **Sunucunun KALICI reddi (SQLSTATE `P0001`).** `accept_friend_invite`
///    üç durumu bilerek `raise exception` ile reddediyor (kendi linkin,
///    geçersiz token, oturum yok) ve o metinleri KULLANICIYA GÖSTERİLMEK
///    üzere yazıyor. Olduğu gibi göster — tekrar denemek sonucu değiştirmez.
///    Koda bakılıyor, METNE değil: metin değişebilir (aynı gerekçe web'de de
///    yazılı).
/// 2. **Ağ hatası.** Link geçerli olabilir; söylenecek şey "bağlantı".
/// 3. **Geri kalan her şey.** Jenerik mesaj — bilinmeyen bir hatayı
///    "geçersiz link" diye maskelemek yanlış teşhis olurdu.
///
/// ⚠ 26 Ağustos 2026'ya kadar bu dalların HİÇBİRİ kullanıcıya ulaşmıyordu:
/// `setup_screen.dart`'ın `catch`i yalnızca `debugPrint` yapıyordu, yani
/// kişi kendi linkine dokunduğunda EKRANDA HİÇBİR ŞEY olmuyordu
/// (ROADMAP madde 1 → "portta davet kabulü SESSİZCE düşüyor").
String inviteAcceptErrorText(Object e) {
  if (e is PostgrestException && e.code == 'P0001') return e.message;
  if (isNetworkError(e)) {
    return 'Davet kabul edilemedi — bağlantını kontrol edip tekrar dene.';
  }
  return 'Davet kabul edilemedi. Biraz sonra tekrar dene.';
}

/// Kalıcı ret mi (tekrar denemek anlamsız) yoksa geçici bir arıza mı?
/// Telemetri kararı buna bakıyor: beklenen retleri `client_errors`'a
/// yazmak sinyali boğar.
bool inviteAcceptKaliciRet(Object e) =>
    e is PostgrestException && e.code == 'P0001';

/// PostgrestException'ı kullanıcıya gösterilebilir kısa metne indirger —
/// arkadaşlık uçları için web'in console.error+jenerik davranışının
/// mobil karşılığı.
String friendErrorText(Object e) {
  if (e is PostgrestException) return e.message;
  return 'Bir hata oluştu.';
}
