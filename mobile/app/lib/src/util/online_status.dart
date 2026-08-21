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

/// Çevrimdışıya geçişin doğrulanma süresi — web `OFFLINE_CONFIRM_MS`.
const kOfflineConfirmDelay = Duration(milliseconds: 1500);

class OnlineStatus extends ChangeNotifier with WidgetsBindingObserver {
  bool _online;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final Connectivity _connectivity = Connectivity();
  bool _observing = false;
  Timer? _offlineTimer;
  final Duration _confirmDelay;
  /// İlk ölçüm yapıldı mı — debounce yalnızca GEÇİŞLERE uygulanır.
  bool _measured = false;

  /// Gerçek bağlantıyı dinler. Başlangıçta iyimser (`true`): ilk ölçüm
  /// gelene kadar "çevrimdışı" demek, çevrimiçi kullanıcıya bir kare
  /// yanlış mesaj göstermek olurdu.
  OnlineStatus({Duration confirmDelay = kOfflineConfirmDelay})
      : _online = true,
        _confirmDelay = confirmDelay {
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
  OnlineStatus.fake({bool online = true, Duration? confirmDelay})
      : _online = online,
        _confirmDelay = confirmDelay ?? kOfflineConfirmDelay;

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

  /// **ASİMETRİK (21 Ağustos 2026):** `false`e geçiş [_confirmDelay] kadar
  /// DOĞRULANIR, `true`ya dönüş ANINDA uygulanır. Sebep: WiFi ↔ hücresel
  /// geçişinde hiçbir arayüzün ayakta olmadığı birkaç yüz milisaniyelik bir
  /// pencere var ve sinyal orada gerçekten "yok" diyor — yalan değil, ama
  /// ANLIK. Debounce olmadan Canlı sekmesi o anda üç alt sekmeyi birden
  /// "İnternet bağlantısı yok"a çevirip geri dönüyordu; kullanıcı internetinin
  /// çalıştığını bildiğinden bu yanlış alarm olarak okunuyor. Yanlış alarmın
  /// bedeli ("oyunlarım kayboldu" korkusu) gecikmeli alarmın bedelinden
  /// (gerçekten uçak moduna geçen biri 1.5 sn geç öğrenir) çok daha büyük.
  ///
  /// Web eşleniği: `src/hooks/useOnlineStatus.ts` — biri değişirse öteki de.
  void _apply(List<ConnectivityResult> results) {
    // Boş liste bazı platformlarda "bilinmiyor" anlamına geliyor — iyimser
    // yorumlanır (yanlış "çevrimdışı" göstermektense yavaş yol devreye
    // girsin).
    final next =
        results.isEmpty || results.any((r) => r != ConnectivityResult.none);
    if (next) {
      _measured = true;
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (_online) return;
      _online = true;
      notifyListeners();
      return;
    }
    // Soğuk açılıştaki İLK ölçüm bekletilmez: bu sınıfın var olma sebebi
    // uçak modunda kullanıcıyı uzun "Yükleniyor…"da bırakmamaktı
    // (*"Ama hemen çıkmalı bence."*). Debounce yalnızca çalışırken olan
    // GEÇİŞLER için — web'de de ilk değer bilerek debounce edilmiyor.
    if (!_measured) {
      _measured = true;
      if (_online) {
        _online = false;
        notifyListeners();
      }
      return;
    }
    if (!_online || _offlineTimer != null) return;
    _offlineTimer = Timer(_confirmDelay, () async {
      _offlineTimer = null;
      // Pencere dolunca gerçeği YENİDEN oku: bu arada bağlantı dönmüş
      // olabilir ve o dönüşün olayı kaçmış olabilir.
      try {
        final now = await _connectivity.checkConnectivity();
        if (now.isNotEmpty && now.every((r) => r == ConnectivityResult.none)) {
          _online = false;
          notifyListeners();
        }
      } catch (_) {
        // Platform kanalı yoksa (test/önizleme) elde olan sinyale güven.
        _online = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _offlineTimer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
