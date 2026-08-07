// Gelen arkadaş daveti linkleri — web'in /davet/:token sayfası +
// `friendInvite.ts` kuyruğunun mobil karşılığı.
//
// Kaynak: app_links'in URI akışı (supabase_flutter aynı akışı auth
// callback'leri için zaten dinliyor; broadcast olduğundan ikinci dinleyici
// serbest — auth URI'ları `parseInviteToken`'a uymaz, davet URI'ları da
// auth parametresi taşımadığından supabase tarafından yok sayılır; iki
// dinleyici kesişmez). Cold start'ta ilk URI da bu akışa dahil (app_links
// 6.x, mobil) — şifre sıfırlama parçasındaki aynı tespit.
//
// Akış: URI → token → `pending_events`'e (`friend-invite-token`) yaz +
// dinleyicilere haber ver. İşleme (takeAll → acceptInvite) SetupScreen'in
// işi — girişsizken token kuyrukta bekler, kişi giriş yapınca işlenir
// (web'in "e-posta doğrulaması açıkken oturum sonra açılır" senaryosuyla
// aynı read-then-clear gerekçesi; PendingEventStore.takeAll atomik).
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../storage/app_storage.dart';
import '../storage/pending_event_store.dart';
import 'friends_api.dart' show parseInviteToken;

class FriendInviteInbox extends ChangeNotifier {
  final Future<AppStorage> _storage;
  StreamSubscription<Uri>? _sub;

  /// Son görülen token — girişsiz kullanıcıya "X seni eklemek istiyor,
  /// giriş yapınca eklenecek" önizlemesi için (kuyruktan OKUMADAN; takeAll
  /// tüketici olduğundan önizleme onu harcayamaz).
  String? lastToken;

  FriendInviteInbox(this._storage);

  /// Üretimde `AppLinks().uriLinkStream`; testler kendi stream'ini verir.
  void attach(Stream<Uri> uris) {
    _sub?.cancel();
    _sub = uris.listen(handleUri,
        onError: (Object e) =>
            debugPrint('[Kelimeki] davet linki akış hatası: $e'));
  }

  @visibleForTesting
  Future<void> handleUri(Uri uri) async {
    final token = parseInviteToken(uri);
    if (token == null) return;
    lastToken = token;
    try {
      final storage = await _storage;
      await storage.events.add(friendInviteTokenKind, {'token': token});
    } catch (e) {
      debugPrint('[Kelimeki] davet token kuyruklanamadı: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Bootstrap'ın gerçek kaynağı — ayrı fonksiyon: testler AppLinks'e hiç
/// dokunmadan inbox kurabilsin.
FriendInviteInbox createFriendInviteInbox(Future<AppStorage> storage) {
  final inbox = FriendInviteInbox(storage);
  inbox.attach(AppLinks().uriLinkStream);
  return inbox;
}
