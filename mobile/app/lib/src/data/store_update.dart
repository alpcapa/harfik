// Play In-App Update — "app açıldığında daha yeni sürüm varsa uyar ve yaptır".
//
// ── NEDEN BU, `app_config.mobile_min_supported_version` YERİNE ────────────
// Kullanıcı kararı (30 Ağustos 2026, sözleri): *"Kimde hangi versiyon
// olursa olsun, app'i açtığında daha yeni bir sürüm varsa uyarsın ve
// yapsın. Bu kadar basit."*
//
// Eldeki mekanizma bunu YAPMIYORDU: `version_gate.dart` bir insanın
// Supabase'de bir satırı elle yükseltmesini bekleyen, ikili (ya tamamen
// engelle ya hiçbir şey yapma) bir kapı. **Ölçüldü ve çalışmadığı
// görüldü:** 1.0.1 iki gün yayında kaldıktan sonra son 14 günün oyun
// başlangıçlarında Android tarafı `1.0.0 → 93`, `1.0.1 → 2` idi; yani
// neredeyse kimse güncellememişti ve eşiği yükseltecek kimse de yoktu.
//
// Play In-App Update'te güncelleme olup olmadığını **Play'in kendisi**
// biliyor: sunucuda satır YOK, kimsenin bir şeyi hatırlaması GEREKMİYOR,
// ve güncelleme uygulamanın İÇİNDE tamamlanıyor (Immediate akışı — tam
// ekran, Play çiziyor, kullanıcı hiçbir yere gitmiyor).
//
// `mobile_min_supported_version` SİLİNMEDİ ama günlük akıştan çıktı:
// artık yalnızca "eski istemciyi sunucu değişikliği kırdı" durumunda
// çekilecek acil fren.
//
// ── SINIRLAR (ikisi de yapısal, gizlenmesin) ──────────────────────────────
// 1. **Yalnızca ANDROID.** iOS'ta karşılığı olan bir API yok; `in_app_update`
//    da Android eklentisi. iOS günü gelince ayrı bir yol gerekir (App Store
//    lookup + kullanıcıyı mağazaya yollama) — bugün YAZILMADI, çünkü iOS
//    henüz yayında değil ve yazılsa test edilemezdi.
// 2. **Yalnızca Play'den KURULMUŞ pakette çalışır.** CI'ın debug `.apk`'sı
//    yan yüklendiğinde Play bu uygulamayı tanımaz ve kontrol sessizce
//    "bilinmiyor" döner. Yani bu özelliğin cihaz doğrulaması ancak kapalı
//    test kanalından kurulan derlemede yapılabilir (`mobile/TESTING.md`).
//    Bunu bilmeyen biri `.apk`da "çalışmıyor" diye saatlerce arar.
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Play'e sorulan tek soru.
enum StoreUpdateDurumu {
  /// Daha yeni bir sürüm var VE Immediate akışına izin veriliyor.
  hemenGuncellenebilir,

  /// Güncelleme yok, ya da var ama Immediate akışı kapalı.
  gerekYok,

  /// Sorulamadı (Play yok, ağ yok, yan yüklenmiş paket, iOS/web…).
  /// **`gerekYok`tan AYRI tutuluyor**: açılışta ağ yokken "güncel" sanıp
  /// bir daha hiç sormamak, tam da bu özelliğin çözmeye çalıştığı hatanın
  /// aynısı olurdu. Çağıran bu durumda öne dönüşte TEKRAR sorar.
  bilinmiyor,
}

/// Play ile konuşan dikiş — testler sahtesini geçer.
abstract class StoreUpdateGateway {
  Future<StoreUpdateDurumu> kontrolEt();

  /// Immediate akışını başlatır. Başarıyı DÖNMEZ diye bir garanti yok:
  /// akış başarılıysa Play uygulamayı zaten yeniden başlatmış olur, yani
  /// bu Future çoğu zaman hiç tamamlanmaz. `false` = kullanıcı vazgeçti
  /// ya da akış düştü.
  Future<bool> hemenGuncelle();
}

/// Gerçek uç. **Hiçbir metodu FIRLATMAZ** — bir güncelleme kontrolü
/// uygulamanın açılışını düşüremez (`push_init.dart`'ın aynı ilkesi).
class PlayStoreUpdateGateway implements StoreUpdateGateway {
  const PlayStoreUpdateGateway();

  bool get _destekli =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<StoreUpdateDurumu> kontrolEt() async {
    if (!_destekli) return StoreUpdateDurumu.bilinmiyor;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        // `developerTriggeredUpdateInProgress` de buraya düşer: akış zaten
        // sürüyor, ikinci kez başlatmak Play tarafında hata verir.
        return info.updateAvailability == UpdateAvailability.unknown
            ? StoreUpdateDurumu.bilinmiyor
            : StoreUpdateDurumu.gerekYok;
      }
      // Immediate'e izin verilmiyorsa (Play Console'daki öncelik/eskilik
      // kuralları) ZORLAMA — `flexible`a sessizce düşmek kullanıcının
      // istediği "uyar ve yaptır" davranışı olmazdı, yarısı olurdu.
      return info.immediateUpdateAllowed
          ? StoreUpdateDurumu.hemenGuncellenebilir
          : StoreUpdateDurumu.gerekYok;
    } catch (e) {
      debugPrint('[Kelimeki] güncelleme kontrolü yapılamadı: $e');
      return StoreUpdateDurumu.bilinmiyor;
    }
  }

  @override
  Future<bool> hemenGuncelle() async {
    if (!_destekli) return false;
    try {
      // ⚠ `performImmediateUpdate` BİLİNMEYEN PlatformException'ları
      // yeniden FIRLATIYOR (paketin kaynağında okundu, 5.0.0) — yalnızca
      // USER_DENIED_UPDATE ve IN_APP_UPDATE_FAILED sonuca çevriliyor.
      // Bu yüzden try/catch şart.
      final res = await InAppUpdate.performImmediateUpdate();
      return res == AppUpdateResult.success;
    } catch (e) {
      debugPrint('[Kelimeki] güncelleme akışı başlatılamadı: $e');
      return false;
    }
  }
}

/// Açılışta koşan karar — saf, test edilebilir, UI'sız.
///
/// Dönen değer "bir sonuca varıldı mı": `false` ise çağıran öne dönüşte
/// TEKRAR denemeli (ağ yoktu, Play cevap vermedi…). `true` ise bu açılış
/// için soru kapanmıştır — güncelleme ya yoktu ya da akış başlatıldı.
///
/// Kullanıcı akışı reddederse de `true` döner: her öne dönüşte tam ekran
/// bir güncelleme penceresi açmak düşmanca olurdu. Bir sonraki AÇILIŞTA
/// yine sorulur.
Future<bool> magazaGuncellemesiniCalistir(StoreUpdateGateway gateway) async {
  final durum = await gateway.kontrolEt();
  switch (durum) {
    case StoreUpdateDurumu.bilinmiyor:
      return false;
    case StoreUpdateDurumu.gerekYok:
      return true;
    case StoreUpdateDurumu.hemenGuncellenebilir:
      await gateway.hemenGuncelle();
      return true;
  }
}
