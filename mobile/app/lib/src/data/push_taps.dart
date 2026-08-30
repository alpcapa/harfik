// Bildirime DOKUNMA kanalı — Faz 3 (30 Ağustos 2026).
//
// Sunucu her push'a `data.link` koyabiliyor (`_shared/push.ts`; bugün tek
// üretici oyun daveti: `kelimeki://oyun/<id>`). Faz 2'de bilinçli olarak
// yalnızca gönderildi, okunmadı — ROADMAP Faz 3: "istemci okumuyor,
// `onMessageOpenedApp`/`getInitialMessage` HİÇ YOK". Bu dosya o boşluğun
// dikişi: gerçek uç `push_gateways.dart`'ta (`FirebasePushTapSource`),
// testler sahtesini verir (PushMessaging/PushTokenStore ayrımının aynısı).
//
// ⚠ `PushMessaging`E EKLENMEDİ, AYRI ARAYÜZ: o dikiş token yaşam döngüsünün
// (izin + token) sözleşmesi ve `push_repo_test`teki sahteleri onu
// `implements` ediyor — oraya üye eklemek her sahteyi kırardı. Dokunma
// akışının tüketicisi de bambaşka (_HomeGate yönlendirmesi ↔ PushRepo).
import 'dart:async';

/// Bildirime dokunulduğunda taşınan derin bağlantılar.
abstract class PushTapSource {
  /// Uygulama ARKA PLANDAYKEN dokunuldu → öne geldi. (`onMessageOpenedApp`)
  Stream<Uri> get taps;

  /// Uygulama KAPALIYKEN dokunuldu → bu dokunuş uygulamayı başlattı.
  /// (`getInitialMessage`) — bir kez okunur; dokunuşla açılmadıysa null.
  Future<Uri?> initialTap();
}

/// FCM `data` yükünden derin bağlantıyı çıkarır — saf, birim testli.
///
/// Sunucu `link`i her mesaja KOYMUYOR (teslim uyarısında yok); yokluk ve
/// bozukluk sessizce null: bildirime dokunmak en kötü ihtimalle uygulamayı
/// açar, asla düşürmez (`_shared/push.ts` başlığındaki sözleşmenin istemci
/// yarısı: "hedef yoksa/uygulama linki tanımazsa sessizce yok sayar").
Uri? pushMessageLink(Map<String, Object?> data) {
  final link = data['link'];
  if (link is! String || link.isEmpty) return null;
  return Uri.tryParse(link);
}
