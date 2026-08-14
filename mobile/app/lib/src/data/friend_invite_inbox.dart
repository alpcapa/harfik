// Gelen arkadaş daveti linkleri — web'in /davet/:token sayfası +
// `friendInvite.ts` kuyruğunun mobil karşılığı.
//
// Kaynak: app_links'in URI akışı (supabase_flutter aynı akışı auth
// callback'leri için zaten dinliyor; broadcast olduğundan ikinci dinleyici
// serbest — auth URI'ları `parseInviteToken`'a uymaz, davet URI'ları da
// auth parametresi taşımadığından supabase tarafından yok sayılır; iki
// dinleyici kesişmez).
//
// **COLD START ayrı bir yol gerektiriyor — bu dosyanın eski yorumu
// ("cold start'ta ilk URI da bu akışa dahil") YANLIŞTI (13 Ağustos 2026,
// bkz. Parça 87):** `AppLinks` Dart tarafında bir SINGLETON ve tek bir
// `StreamController.broadcast()` üzerinden çoğullama yapıyor; native taraf
// (`AppLinksIosPlugin.swift:107`, `AppLinksPlugin.java:133`) soğuk
// başlangıç linkini `initialLinkSent` bayrağıyla YALNIZCA İLK `onListen`da
// bir kez akışa basıyor. **Broadcast akışları geç abone olana geçmiş
// olayları TEKRARLAMAZ.** `bootstrap()`ta bu inbox `await initSupabase()`
// VE `await checkVersionGate(supabase)` (gerçek bir ağ çağrısı, 5 sn'ye
// kadar) tamamlandıktan SONRA kuruluyor; supabase_flutter ise
// `Supabase.initialize` içinde (`detectSessionInUri` varsayılan true)
// `uriLinkStream`e ondan ÖNCE abone oluyor. Yani uygulama KAPALIYKEN bir
// davet linkine dokunulduğunda token sessizce kayboluyordu — sıcak
// (uygulama açıkken) linkler çalıştığı için de görünmüyordu.
//
// Kurtarma yolu `getInitialLink()`: native tarafta düz bir method-channel
// okuması (`case "getInitialLink": result(initialLink)`), `initialLinkSent`
// bayrağını TÜKETMİYOR — yani supabase'in auth akışını bozmadan aynı
// URI'yi bir kez daha okuyabiliyoruz. Mükerrer kuyruk kaydı riski
// `SetupScreen._processInvites`'taki toplu-tüketim dedup'ı ile kapalı
// (orada ayrıntılı gerekçe).
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

/// Bir `takeAll` partisindeki geçerli, MÜKERRERSİZ token'ları sıra korunarak
/// döner.
///
/// Dedup neden GEREKLİ (13 Ağustos 2026, Parça 87): `PendingEventStore.add`
/// düz bir insert — dedup'ı YOK; ve soğuk başlangıçta aynı link hem
/// `uriLinkStream`den hem `getInitialLink()` kurtarmasından düşebiliyor
/// (gerekçe bu dosyanın başlığında). Dedup olmadan kullanıcı üst üste iki
/// "artık arkadaşsınız" diyaloğu görür ve ikinci bir gereksiz RPC atılır.
///
/// Dedup **parti bazında**: kalıcı bir "görüldü" listesi TUTULMUYOR, yani
/// bir sonraki oturumda aynı davet linkine yeniden dokunmak hâlâ çalışır.
///
/// Ayrı ve saf bir fonksiyon, çünkü tek tüketicisi `SetupScreen._processInvites`
/// ve o ekran testte canlı rozet/senkron zamanlayıcıları kurduğundan widget
/// seviyesinde güvenilir şekilde sınanamıyor (`pumpAndSettle` asılıyor —
/// Parça 8'in aynı tuzağı).
List<String> inviteTokensFromEvents(List<Map<String, Object?>> events) {
  final out = <String>[];
  final seen = <String>{};
  for (final e in events) {
    final token = e['token'];
    if (token is! String || token.isEmpty) continue;
    if (!seen.add(token)) continue;
    out.add(token);
  }
  return out;
}

/// Bootstrap'ın gerçek kaynağı — ayrı fonksiyon: testler AppLinks'e hiç
/// dokunmadan inbox kurabilsin.
FriendInviteInbox createFriendInviteInbox(Future<AppStorage> storage) {
  final inbox = FriendInviteInbox(storage);
  final links = AppLinks();
  inbox.attach(links.uriLinkStream);
  // Soğuk başlangıç kurtarması — gerekçe dosyanın başlığında.
  // Hata yutuluyor: link okunamazsa sıcak akış zaten çalışmaya devam eder,
  // uygulamanın açılışını bir davet linki bloke edemez.
  unawaited(links.getInitialLink().then((uri) {
    if (uri != null) return inbox.handleUri(uri);
  }).catchError((Object e) {
    debugPrint('[Kelimeki] ilk davet linki okunamadı: $e');
  }));
  return inbox;
}
