// Kelimeki — sistem bildirim panelini temizleme (ROADMAP #15).
//
// **NEDEN VAR (31 Ağustos 2026, kullanıcı bildirdi):** uygulama simgesindeki
// rozet **9**'da takılı kalıyordu; bildirime dokunup uygulamaya girmek onu
// sıfırlamıyordu. Teşhis iki parçalıydı ve ikisi de ayrı iş:
//
//   1. Rozet uygulamanın kendi sayacı DEĞİL — Samsung One UI onu, panelde
//      HÂLÂ DURAN bildirimlerden türetiyor. Dokunmak yalnızca O bildirimi
//      kapatıyor (9 → 8), kalanlar duruyordu. **Bu dosya bunu çözüyor.**
//   2. Aynı oyunun her "sıra sende"si panelde YENİ bir satır açıyordu
//      (FCM yükünde çakıştırma etiketi yoktu). Sunucu tarafında çözüldü —
//      `supabase/functions/_shared/push.ts` → `PushMessage.tag`.
//
// ── NEDEN EKLENTİ DEĞİL, MethodChannel ───────────────────────────────────
// `firebase_messaging` bir "hepsini temizle" API'si SUNMUYOR; standart yol
// `flutter_local_notifications`. Ama tek ihtiyacımız `cancelAll()`: o paket
// karşılığında kendi başlatma çağrısını, bildirim ikonu yapılandırmasını ve
// bir bağımlılığı daha getirirdi. Bu depo zaten Kotlin'e iniyor
// (`MainActivity.kt` bildirim KANALINI elle yaratıyor) ve o deseni bir
// parite testiyle koruyor — aynı yolu ikinci kez kullanmak, kullanılmayan
// bir eklentinin yüzeyini taşımaktan ucuz.
//
// ── iOS BUGÜN YOK ve bu bilinçli ─────────────────────────────────────────
// iOS'ta karşılığı `removeAllDeliveredNotifications()` + rozet sıfırlama,
// ama iOS henüz CANLI DEĞİL (APNs anahtarı Firebase'e yüklenmedi) ve iOS
// rozeti `aps.badge`den geliyor — sunucu onu HİÇ göndermiyor, yani orada
// sıfırlanacak bir rozet de yok. Kanal iOS'ta kayıtlı olmadığından çağrı
// `MissingPluginException` fırlatır ve aşağıda yutulur: davranış, bugünkü
// doğru davranış. APNs günü geldiğinde `AppDelegate.swift`e aynı kanal adıyla
// bir işleyici eklemek yeterli — Dart tarafı DEĞİŞMEZ.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bildirim panelini temizleyen dikiş. Testte sahtesi verilebilir.
abstract class NotificationShade {
  /// Bu uygulamanın panelde duran TÜM bildirimlerini kaldırır.
  ///
  /// ⚠ **HİÇBİR KOŞULDA FIRLATMAZ.** Çağrıldığı yer uygulamanın öne dönüş
  /// yolu; bir kanal hatası ekran geçişini ya da push hizalamasını
  /// düşüremez (`_shared/push.ts`teki aynı kural).
  Future<void> temizle();
}

/// Gerçek uç — Kotlin tarafındaki `MainActivity` işleyicisi.
class PlatformNotificationShade implements NotificationShade {
  /// ⚠ Bu ad Kotlin tarafıyla BİREBİR aynı olmak zorunda; derleyici bunu
  /// göremez ve uyuşmazlık SESSİZ bir arızadır (çağrı
  /// `MissingPluginException` fırlatır, biz de onu yutarız — yani rozet
  /// temizlenmez ve hiçbir hata görünmez). `notification_shade_parity_test`
  /// bu yüzden var.
  static const kanal = MethodChannel('kelimeki/bildirimler');

  /// Kotlin'deki `when (call.method)` dalıyla BİREBİR aynı.
  static const metot = 'hepsiniTemizle';

  const PlatformNotificationShade();

  @override
  Future<void> temizle() async {
    try {
      await kanal.invokeMethod<void>(metot);
    } catch (e) {
      // MissingPluginException (iOS/web/test) dahil her şey buraya düşer.
      debugPrint('[Kelimeki] bildirim paneli temizlenemedi: $e');
    }
  }
}
