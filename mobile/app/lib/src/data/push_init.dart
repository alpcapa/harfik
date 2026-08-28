// Firebase'in AÇILIŞTA kurulması — ve kurulMAMASI gereken yerler.
//
// ⚠ **PORTUN WEB DERLEMESİ BU KODUN İLK KURBANI OLABİLİRDİ.**
// `mobile-build.yml` Flutter'ın WEB hedefini de derleyip GitHub Pages'a
// yayınlıyor (cihaz testi ortamı). Orada `google-services.json` diye bir şey
// yok ve web için Firebase seçenekleri hiç verilmedi — koşulsuz bir
// `Firebase.initializeApp()` o yüzeyde AÇILIŞTA fırlatır ve uygulamanın
// TAMAMI açılmaz. Yani bir push özelliği, push'un hiç çalışmadığı bir test
// ortamını komple düşürürdü.
//
// Bu yüzden iki katmanlı koruma: (1) yalnızca Android/iOS'ta denenir,
// (2) yine de try/catch — Firebase'in yokluğu uygulamanın açılışını
// engelleyemez. Kurulamazsa push kanalı kapalı kalır, geri kalan her şey
// çalışır (`supabase_client.dart`ın "anahtar yoksa tam offline" deseniyle
// aynı ilke).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase kuruldu mu — `PushRepo` yalnızca `true` iken anlamlı.
///
/// Android'de yapılandırma `google-services.json`dan Gradle eklentisi
/// aracılığıyla geliyor, yani `initializeApp`e seçenek vermeye gerek yok.
/// iOS günü gelince `GoogleService-Info.plist` eklenecek — o zamana kadar
/// iOS'ta da sessizce başarısız olup kapalı kalır.
Future<bool> initFirebase() async {
  if (kIsWeb) return false;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return false;
  }
  try {
    await Firebase.initializeApp();
    return true;
  } catch (e) {
    debugPrint('[Kelimeki] Firebase kurulamadı, push kapalı: $e');
    return false;
  }
}
