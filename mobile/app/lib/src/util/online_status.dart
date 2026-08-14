// Bağlantı durumu — web `src/hooks/useOnlineStatus.ts` portu.
//
// NEDEN (14 Ağustos 2026, cihaz testi): port, "çevrimdışıyız" kararını bir
// ağ çağrısının BAŞARISIZ olmasını bekleyerek veriyordu (`_loadFailed`).
// Uçak modunda bu saniyeler sürüyor — Supabase auth token yenilemeyi geri
// çekilmeli tekrarlarla deniyor — ve kullanıcı Setup'ta uzunca "Yükleniyor…"
// görüyordu: *"Ama hemen çıkmalı bence."* Web'de karar `navigator.onLine`
// ile ANINDA veriliyordu; bu sınıf portu aynı hizaya getiriyor.
//
// `connectivity_plus` web'de zaten `navigator.onLine`'a bakıyor (yani port
// ile web AYNI sinyali kullanıyor), native'de ise arayüz durumunu okuyor.
//
// **Sinyalin sınırı, bilerek:** "arayüz var" ≠ "internet var" (captive
// portal, DNS'i çalışmayan wifi…). Bu yüzden `_loadFailed` yolları
// KALDIRILMADI — ikisi birlikte kullanılıyor: bu sinyal HIZLI ama iyimser,
// başarısız yükleme YAVAŞ ama kesin. "Çevrimdışı" mesajı ikisinden biri
// bile doğruysa gösteriliyor.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

class OnlineStatus extends ChangeNotifier with WidgetsBindingObserver {
  bool _online;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final Connectivity _connectivity = Connectivity();
  bool _observing = false;

  /// Gerçek bağlantıyı dinler. Başlangıçta iyimser (`true`): ilk ölçüm
  /// gelene kadar "çevrimdışı" demek, çevrimiçi kullanıcıya bir kare
  /// yanlış mesaj göstermek olurdu.
  OnlineStatus() : _online = true {
    // Öne dönüşte durumu YENİDEN OKU — akış tabanlı durumun bilinen zaafı:
    // uygulama askıdayken (uçak modunu açmak için Ayarlar'a çıkmak tam bu)
    // olay kaçırılırsa bir daha oynatılmaz ve durum bayat kalır. Web'in
    // `useOnlineStatus`'u aynı gün aynı sebeple aynı kancayı aldı; bu
    // projede kaçırılan olay iki kez daha kalıcı kayıp üretmişti (sohbet
    // Realtime'ı, bulut senkronu).
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
    unawaited(_start());
  }

  /// Testler/önizlemeler için — hiçbir platform kanalına dokunmaz.
  OnlineStatus.fake({bool online = true}) : _online = online;

  bool get online => _online;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// Bağlantı durumunu platformdan yeniden okur (öne dönüş kancası).
  Future<void> refresh() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (_) {
      // Platform kanalı yoksa mevcut durumu koru.
    }
  }

  Future<void> _start() async {
    await refresh();
    _sub = _connectivity.onConnectivityChanged.listen(_apply, onError: (_) {});
  }

  void _apply(List<ConnectivityResult> results) {
    // Boş liste bazı platformlarda "bilinmiyor" anlamına geliyor — iyimser
    // yorumlanır (yanlış "çevrimdışı" göstermektense yavaş yol devreye
    // girsin).
    final next =
        results.isEmpty || results.any((r) => r != ConnectivityResult.none);
    if (next == _online) return;
    _online = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
