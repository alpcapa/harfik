// Kelimeki — bu istemcinin platformu (telemetri). Web `src/utils/platform.ts`
// karşılığı.
//
// Mobil lansmanı ölçülebilsin diye 14 Ağustos 2026'da eklendi: girişli tarafta
// bir kullanıcının app'ten mi web'den mi oynadığını söyleyen hiçbir alan yoktu
// (`guest_visits.device_type` yalnızca oturum KAPALIYKEN yazılıyor ve
// "tarayıcı mobil mi masaüstü mü" sorusunu yanıtlıyor — "app mi web mi"
// DEĞİL). Port yazmazsa satırlar boş platformla gider ve lansman ölçülemez
// kalır; bu dosyanın varlık sebebi tam olarak bu.
//
// `dart:io`'nun `Platform.isIOS`'ü BİLEREK kullanılMIYOR: `dart:io` web
// derlemesinde yok, import edilmesi `flutter build web`i kırar (portun web
// test ortamı `mobile-build.yml`de gerçekten derleniyor). `kIsWeb` +
// `defaultTargetPlatform` her hedefte çalışır.
import 'package:flutter/foundation.dart';

/// Sunucunun kabul ettiği platform değerleri — `games.platform` ve
/// `online_game_clients.platform` sütunlarındaki check kısıtıyla BİREBİR aynı
/// olmak zorunda (kısıt dışında bir değer yollamak `games` insert'ini
/// düşürür, yani bir telemetri alanı yüzünden oyun kaydı kaybolur).
///
/// `test/client_platform_parity_test.dart` bu kümeyi migration SQL'inden
/// okuyup karşılaştırıyor — biri değişip öteki unutulursa test düşer.
const Set<String> kClientPlatforms = {'web', 'ios', 'android', 'app-web'};

/// Bu istemcinin platformu; bilinmeyen bir hedefte `null`.
///
/// - iOS/Android → `'ios'`/`'android'`
/// - Flutter web (portun tarayıcıda çalışan hâli) → `'app-web'`; React web
///   uygulaması ise `'web'` yazıyor, ikisi bilerek ayrı.
/// - Masaüstü (macOS/Windows/Linux) → `null`. Bu hedefler yayınlanmıyor ama
///   uydurma bir değer yollamak yerine null dönmek ŞART: sütun nullable
///   olduğundan satır sorunsuz kaydedilir, yalnızca ölçülmemiş kalır.
String? get currentPlatform {
  if (kIsWeb) return 'app-web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    default:
      return null;
  }
}
