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
    String? appVersion,
  });
  Future<void> remove(String token);
}

class PushRepo {
  final PushMessaging messaging;
  final PushTokenStore store;

  /// Test edilebilirlik: gerçek platform yerine sabit bir değer verilebilir.
  final String? Function() platformKaynagi;

  /// Bu derlemenin sürümü — `push_tokens.app_version`e yazılır.
  ///
  /// **NEDEN VAR (ROADMAP #12, 31 Ağustos 2026):** kullanıcı 1.0.3
  /// duyurusundan sonra "kaç kişi yenide?" diye sordu ve cevaplanamadı.
  /// Sürüm damgası yalnızca `game_starts` ve `client_errors`ta vardı, yani
  /// sürümü ancak biri YZ'li YEREL oyun açtığında ya da HATA aldığında
  /// görüyorduk — üstelik port `anon_id` göndermediğinden orada KİŞİ de
  /// sayılamıyordu. Token satırı `user_id` ile anahtarlı ve
  /// `pushTokenlariHizala` her açılışta koştuğundan burası "kaç KİŞİ hangi
  /// sürümde" sorusunu, oyun oynanmasını beklemeden cevaplayabiliyor.
  ///
  /// Enjekte edilebilir, çünkü testte `env.dart`ın sabitine bağlanmak sürüm
  /// her yükseldiğinde testi kırardı.
  final String? appVersion;

  StreamSubscription<String>? _refreshSub;

  /// En son yazılan token — çıkışta silmek için. Çıkış anında FCM'den tekrar
  /// sormak yerine bunu kullanıyoruz: `token()` ağa çıkabilir ve çıkış
  /// akışını bekletmemeli.
  String? _sonToken;

  PushRepo({
    required this.messaging,
    required this.store,
    String? Function()? platformKaynagi,
    this.appVersion,
  }) : platformKaynagi = platformKaynagi ?? (() => currentPlatform);

  /// Bu cihaz token kaydedebilir mi (Android/iOS mü)?
  String? get _platform => pushPlatform(platformKaynagi());

  /// İzin durumuna göre token'ı KAYDEDER ya da SİLER.
  ///
  /// Çağrılma anları: giriş, uygulama açılışı (girişliyse), öne dönüş, izin
  /// akışı sonrası. Tekrar tekrar çağrılması zararsız.
  ///
  /// **DEĞİŞMEZ: `push_tokens`teki bir satır "bu cihaz bildirimi GERÇEKTEN
  /// gösterebilir" demektir.** İlk yazımda token izinden bağımsız
  /// kaydediliyordu ("nasılsa FCM izin olmadan da token üretiyor") — bu
  /// yanlıştı: izin yokken gönderilen bildirimi Android sessizce atar, ama
  /// FCM 200 döner. Sonuç, `sentOnline` sayacının yalan söylemesi ve her
  /// turda boşuna kota yakılması olurdu.
  ///
  /// Kendi kendini onaran taraf: izin sistem ayarlarından sonradan açılırsa
  /// bir sonraki açılışta token yazılır; kapatılırsa bir sonraki açılışta
  /// silinir. Bunun için bir dinleyici gerekmiyor — kapı zaten her açılışta
  /// bir kez geçiliyor.
  ///
  /// `notDetermined`da HİÇBİR ŞEY yapılmaz: henüz sorulmamış demektir,
  /// silinecek bir satır da yoktur.
  Future<void> senkronize({
    required String userId,
    required PushPermission izin,
  }) async {
    switch (izin) {
      case PushPermission.granted:
        await kaydet(userId);
      case PushPermission.denied:
      case PushPermission.permanentlyDenied:
        // ⚠ Yalnızca AÇIK bir ret satırı siler. `permission()` fırlatırsa
        // buraya hiç gelinmez (çağıran yakalar) — bir ağ/eklenti hatasının
        // çalışan bir token'ı silmesi kabul edilemez.
        await temizle();
      case PushPermission.notDetermined:
        break;
    }
  }

  /// Token'ı alıp `push_tokens`e yazar ve yenilemelerini dinlemeye başlar.
  ///
  /// Doğrudan çağrılabilir ama normal yol `senkronize` — izin kontrolü orada.
  Future<void> kaydet(String userId) async {
    try {
      final platform = _platform;
      if (platform == null) return; // web/masaüstü: kaydedilecek bir şey yok
      final token = await messaging.token();
      if (token == null || token.isEmpty) return;
      await store.upsert(
          token: token,
          userId: userId,
          platform: platform,
          appVersion: appVersion);
      _sonToken = token;
      _refreshSub ??= messaging.onTokenRefresh().listen(
        (yeni) async {
          // Token dönebiliyor (uygulama verisi temizlenmesi, yedekten geri
          // yükleme, FCM'in kendi kararı). Yakalanmazsa satır ESKİ token'la
          // kalır ve bildirimler sessizce gitmez.
          try {
            await store.upsert(
                token: yeni,
                userId: userId,
                platform: platform,
                appVersion: appVersion);
            // ⚠ ESKİ satır da silinmeli. Birincil anahtar TOKEN olduğundan
            // yeni token YENİ bir satır açar; eskisi kalırsa aynı cihaz
            // tabloda iki kez görünür ve her bildirim iki kez gönderilmeye
            // çalışılır. Sunucu tarafı bunu eninde sonunda temizliyor
            // (FCM `UNREGISTERED` → satır silinir) ama o "eninde sonunda"
            // bir sonraki gönderim denemesi demek — yani en az bir mükerrer
            // deneme. Burada kapatmak bedavaya.
            final eski = _sonToken;
            _sonToken = yeni;
            if (eski != null && eski != yeni) await store.remove(eski);
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
    final bellektekiToken = _sonToken;
    _sonToken = null;
    try {
      // ⚠ BELLEKTEKİ token TEK BAŞINA YETMEZ ve bu bir testle bulundu.
      // `_sonToken` yalnızca bu oturumda bir kayıt yapıldıysa dolu. Senaryo:
      // kullanıcı izin verir (token yazılır), bildirimleri sistem
      // ayarlarından kapatır, uygulamayı KAPATIP açar. Yeni süreçte
      // `_sonToken` null olduğundan silme sessizce atlanır ve bayat satır
      // tabloda SONSUZA KADAR kalır — "token varlığı izni takip eder"
      // değişmezi tam da yeniden başlatmada kırılırdı.
      //
      // Bu yüzden önce FCM'den CANLI token isteniyor; bellekteki yalnızca
      // yedek (FCM'e ulaşılamazsa ya da null dönerse).
      String? canli;
      try {
        canli = await messaging.token();
      } catch (e) {
        debugPrint('[Kelimeki] silinecek token okunamadı: $e');
      }
      final token = canli ?? bellektekiToken;
      if (token == null || token.isEmpty) return;
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
