// Push cihaz token'ının yaşam döngüsü: al → `push_tokens`e yaz → yenilenince
// güncelle → çıkışta sil.
//
// **İKİ AYRI DİKİŞ, bilinçli:** `PushMessaging` platform eklentisini (FCM),
// `PushTokenStore` tabloyu temsil ediyor. Tek bir arayüzde birleştirmek daha
// az kod olurdu ama testlerde ikisini ayrı ayrı zorlayamazdım — oysa asıl
// riskli davranışlar tam da aralarındaki KARARLAR: hangi platformda hiç
// kaydetmemeli, kullanıcı yokken ne yapmalı, hesap değişince eski satır ne
// olmalı.
//
// ⚠ **Hiçbir yolu fırlatmaz.** Push bir EK kanal; bir arızası uygulamanın
// açılışını, girişini ya da Canlı sekmesini düşüremez. Her genel metot kendi
// hatasını yutup `debugPrint`e yazar — `feedbackSync`/`cloudSaveMirror` ile
// aynı ilke.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../util/platform.dart';
import '../util/push_rules.dart';

/// Sistem izninin durumu.
///
/// ⚠ `denied` ile `permanentlyDenied` AYRI ve ayrım kritik — eklentinin
/// kendi dokümanı (firebase_messaging_platform_interface 4.10.0,
/// `AuthorizationStatus`) şöyle diyor:
///   denied            → "Android 13+'ta kullanıcı en az bir kez reddetti
///                        ama OS bir kez daha sorabilir."
///   deniedPermanently → "OS bir daha sormayacak; kullanıcı sistem
///                        ayarlarından açmak zorunda."
/// İkincisinde bizim sayfamızı göstermek kullanıcıya BOZUK bir buton
/// göstermek olurdu: "Aç"a basar, hiçbir şey açılmaz.
///
/// ⚠ Apple'da `deniedPermanently` KULLANILMIYOR (kalıcı ret de `denied`
/// olarak geliyor) — iOS günü geldiğinde bu ayrımın orada çalışmadığı
/// hatırlanmalı. Bugün etkisi yok: yayınlanan tek platform Android.
enum PushPermission { granted, denied, permanentlyDenied, notDetermined }

/// FCM tarafı (platform eklentisi).
abstract class PushMessaging {
  Future<String?> token();
  Stream<String> onTokenRefresh();
  Future<PushPermission> permission();

  /// Sistem diyaloğunu AÇAR. Yalnızca kullanıcı kendi sayfamızda "Aç"
  /// dedikten sonra çağrılmalı — gerekçe `util/push_rules.dart`.
  Future<PushPermission> requestPermission();
}

/// `push_tokens` tablosu.
abstract class PushTokenStore {
  Future<void> upsert({
    required String token,
    required String userId,
    required String platform,
  });
  Future<void> remove(String token);
}

class PushRepo {
  final PushMessaging messaging;
  final PushTokenStore store;

  /// Test edilebilirlik: gerçek platform yerine sabit bir değer verilebilir.
  final String? Function() platformKaynagi;

  StreamSubscription<String>? _refreshSub;

  /// En son yazılan token — çıkışta silmek için. Çıkış anında FCM'den tekrar
  /// sormak yerine bunu kullanıyoruz: `token()` ağa çıkabilir ve çıkış
  /// akışını bekletmemeli.
  String? _sonToken;

  PushRepo({
    required this.messaging,
    required this.store,
    String? Function()? platformKaynagi,
  }) : platformKaynagi = platformKaynagi ?? (() => currentPlatform);

  /// Bu cihaz token kaydedebilir mi (Android/iOS mü)?
  String? get _platform => pushPlatform(platformKaynagi());

  /// Girişli kullanıcının token'ını kaydeder/tazeler.
  ///
  /// Çağrılma anları: giriş, uygulama açılışı (girişliyse), hesap değişimi.
  /// Tekrar tekrar çağrılması zararsız — `upsert` aynı satırı günceller.
  ///
  /// İzin YOKKEN de çağrılabilir: FCM Android'de izin verilmeden de token
  /// üretir, yalnızca bildirim GÖSTERMEZ. Token'ı erken kaydetmek, kullanıcı
  /// izni sonradan ayarlardan açtığında hiçbir şey yapmadan çalışması demek.
  Future<void> kaydet(String userId) async {
    try {
      final platform = _platform;
      if (platform == null) return; // web/masaüstü: kaydedilecek bir şey yok
      final token = await messaging.token();
      if (token == null || token.isEmpty) return;
      await store.upsert(token: token, userId: userId, platform: platform);
      _sonToken = token;
      _refreshSub ??= messaging.onTokenRefresh().listen(
        (yeni) async {
          // Token dönebiliyor (uygulama verisi temizlenmesi, yedekten geri
          // yükleme, FCM'in kendi kararı). Yakalanmazsa satır ESKİ token'la
          // kalır ve bildirimler sessizce gitmez.
          try {
            await store.upsert(token: yeni, userId: userId, platform: platform);
            _sonToken = yeni;
          } catch (e) {
            debugPrint('[Kelimeki] push token yenilemesi yazılamadı: $e');
          }
        },
        onError: (Object e) =>
            debugPrint('[Kelimeki] push token akış hatası: $e'),
      );
    } catch (e) {
      debugPrint('[Kelimeki] push token kaydedilemedi: $e');
    }
  }

  /// Çıkışta / hesap değişiminde bu cihazın satırını siler.
  ///
  /// ⚠ ŞART: token satırı KULLANICIYA bağlı. Silinmezse A çıkıp B girene
  /// kadar geçen sürede A'ya gönderilen bildirim B'nin telefonunda çıkar.
  /// (B giriş yapınca `kaydet` aynı token'ı devralıyor — birincil anahtar
  /// token olduğu için satır çoğalmıyor, sahibi değişiyor.)
  Future<void> temizle() async {
    _refreshSub?.cancel();
    _refreshSub = null;
    final token = _sonToken;
    _sonToken = null;
    if (token == null) return;
    try {
      await store.remove(token);
    } catch (e) {
      debugPrint('[Kelimeki] push token silinemedi: $e');
    }
  }

  void dispose() {
    _refreshSub?.cancel();
    _refreshSub = null;
  }
}
