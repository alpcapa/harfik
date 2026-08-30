// Kelimeki app — Firebase Analytics olay kanalı (ROADMAP #13 / Faz 3,
// 30 Ağustos 2026).
//
// NEDEN VAR (ROADMAP'ten, ölçülmüş gerekçe): bugünkü şema SONUÇLARI
// görüyor, DAVRANIŞI görmüyor. `guest_visits` → `profiles` → `game_starts`
// zinciri "ne oldu"yu veriyor; ekran görüntülenmesi, akış içi terk noktası
// YOK. Bedeli ödendi: insanlar tanıtım ekranında takılıyordu (3 günde 2
// kayıt) ve sebep veriden GÖRÜLMEDİ — kullanıcı insanlarla konuşunca
// öğrenildi. `game_starts` bunu gösteremezdi; o insanlar oyuna hiç
// ulaşamamıştı.
//
// DESEN `errorReporter`İN AYNISI (global tek örnek + `configure`):
// olayların düştüğü altı yer (intro, kayıt formu, Canlı oyun formu, davet
// paylaşımı…) birbirinden bağımsız widget'lar; her birine parametre zinciri
// açmak, tek satırlık bir log için üç imza değiştirmek demekti. errorReporter
// aynı gerekçeyle globaldi ve desen kendini kanıtladı.
//
// İKİ DEĞİŞMEZ:
//   1. FIRE-AND-FORGET — asla `await` edilmez, ASLA fırlatmaz. Bir analitik
//      olayı hiçbir kullanıcı akışını geciktiremez/düşüremez (push.ts'in
//      "push, e-posta yolunu asla düşüremez" kuralının buradaki karşılığı).
//   2. YAPILANDIRILMAMIŞSA SESSİZ NO-OP — testler, web derlemesi ve
//      Firebase'siz açılış hiçbir şey yapmaz. Testte olay ölçmek isteyen
//      `configure` ile sahte logger takar, `reset` ile bırakır.
//
// ⚠ OLAY ADLARI SÖZLEŞMEDİR: GA4 raporları bu dizelerle kurulacak; ad
// değişirse eski veri yeni raporda görünmez. İlk altı olay ROADMAP #13'te
// seçildi: `intro_slide_viewed` · `signup_started` · `signup_completed` ·
// `live_game_form_opened` · `live_game_created` · `invite_link_shared`.
// GA4 kuralları: ad ≤40 karakter, [a-z0-9_], harfle başlar; parametre
// değerleri String/num.
import 'package:flutter/foundation.dart';

/// Gerçek uç ya da testin sahtesi. Gerçek uç `analytics_gateway.dart`'ta
/// (`FirebaseAnalyticsLogger`) — ayrı dosya, çünkü orası Firebase'e bağlı
/// ve birim testine girmiyor (push_repo ↔ push_gateways ayrımının aynısı).
abstract class AnalyticsLogger {
  Future<void> log(String name, Map<String, Object>? params);
}

/// Tek örnek — `bootstrap()` yapılandırır, olay yerleri doğrudan kullanır.
final Analytics analytics = Analytics();

class Analytics {
  AnalyticsLogger? _logger;

  void configure(AnalyticsLogger? logger) {
    _logger = logger;
  }

  /// Testler için: global durumu bırak (tearDown'da çağır — global tek
  /// örnek, sahte logger sonraki teste sızmasın).
  @visibleForTesting
  void reset() => _logger = null;

  /// Olay kaydeder. Fire-and-forget: beklenmez, fırlatmaz.
  void log(String name, [Map<String, Object>? params]) {
    final logger = _logger;
    if (logger == null) return;
    logger.log(name, params).catchError((Object e) {
      // Yutuluyor ve telemetriye de DÜŞMÜYOR: analitik ucun arızası bir
      // "hata" değil (çevrimdışılıkta rutin) ve errorReporter'a yazmak
      // gürültüyle sinyali boğardı — offline_notice'in aynı gerekçesi.
      debugPrint('[Kelimeki] analytics olayı gönderilemedi ($name): $e');
    });
  }
}
