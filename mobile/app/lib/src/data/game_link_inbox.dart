// Gelen Canlı oyun linkleri (`kelimeki://oyun/<id>`) — Faz 3.
//
// `FriendInviteInbox`un kardeşi ama BİLİNÇLİ olarak daha basit: davet
// token'ı kalıcı kuyruğa (`pending_events`) yazılıyor çünkü girişsiz
// kullanıcı token'ı alıp GÜNLER sonra üye olabiliyor. Oyun linki ise bir
// bildirime DOKUNMANIN anlık niyeti — üç gün sonra açılan uygulamada bayat
// bir tahtayı kullanıcının önüne itmek yanlış olurdu. Bu yüzden kalıcılık
// YOK: yalnızca bellekte "en son dokunulan oyun" tutulur; uygulama bu
// oturumda işleyemezse (ör. girişsiz) kayıt bir sonraki açılışa TAŞINMAZ.
//
// İKİ kaynak besliyor, ikisi de aynı `handleUri`den geçer:
//   1. app_links URI akışı — OS'ten gelen `kelimeki://oyun/...` (intent
//      filtresi host kısıtsız; FriendInviteInbox'la aynı broadcast akışın
//      üçüncü dinleyicisi olmak serbest, URI türleri kesişmez).
//   2. FCM bildirim dokunuşları (`PushTapSource`) — `data.link`.
//
// Sınıflandırma `parseDeepLink`te (TEK ayrıştırma noktası kuralı); burası
// yalnızca `KOnlineGameLink` dalını tüketir, davet/auth URI'larına dokunmaz.
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../util/deep_link.dart';
import 'push_taps.dart';

class GameLinkInbox extends ChangeNotifier {
  final List<StreamSubscription<Uri>> _subs = [];

  /// En son dokunulan/istenen oyun — `take` ile tüketilir. Üst üste iki
  /// dokunuşta SONUNCUSU kazanır (kullanıcının son niyeti).
  String? _pendingGameId;

  String? get pendingGameId => _pendingGameId;

  /// Bekleyen id'yi tüketir — iki kez işlenmesin diye oku-ve-temizle
  /// (PendingEventStore.takeAll'un tek-değerli karşılığı).
  String? take() {
    final v = _pendingGameId;
    _pendingGameId = null;
    return v;
  }

  /// Birden çok kaynak bağlanabilir (URI akışı + push dokunuşları).
  void attach(Stream<Uri> uris) {
    _subs.add(uris.listen(handleUri,
        onError: (Object e) =>
            debugPrint('[Kelimeki] oyun linki akış hatası: $e')));
  }

  @visibleForTesting
  void handleUri(Uri uri) {
    final link = parseDeepLink(uri);
    if (link is! KOnlineGameLink) return;
    _pendingGameId = link.gameId;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Oyun linki gelen kutusunu iki kaynağa bağlar — `createFriendInviteInbox`
/// ile aynı ayrım: gerçek akışlara dokunan kablolama burada, sınıfın
/// kendisi testlerde kendi stream'iyle kurulur.
GameLinkInbox createGameLinkInbox({PushTapSource? pushTaps}) {
  final inbox = GameLinkInbox();
  final links = AppLinks();
  inbox.attach(links.uriLinkStream);
  // Soğuk başlangıç — `getInitialLink` tüketmeyen okuma (gerekçe:
  // friend_invite_inbox.dart başlığı; aynı URI'yi üçüncü okuyan da biziz,
  // oyun URI'ları davet/auth dinleyicilerine uymadığından kesişme yok).
  unawaited(links.getInitialLink().then((uri) {
    if (uri != null) inbox.handleUri(uri);
  }).catchError((Object e) {
    debugPrint('[Kelimeki] ilk oyun linki okunamadı: $e');
  }));
  if (pushTaps != null) {
    inbox.attach(pushTaps.taps);
    // Bildirimden soğuk başlangıç — dokunuş uygulamayı başlattıysa.
    unawaited(pushTaps.initialTap().then((uri) {
      if (uri != null) inbox.handleUri(uri);
    }).catchError((Object e) {
      debugPrint('[Kelimeki] ilk bildirim dokunuşu okunamadı: $e');
    }));
  }
  return inbox;
}
