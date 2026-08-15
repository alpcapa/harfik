// Kelimeki app — derleme zamanı yapılandırma.
//
// Supabase anahtarları --dart-define ile verilir:
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
// Verilmezse uygulama web'deki gibi TAMAMEN OFFLINE çalışır (hesap/Canlı oyun
// özellikleri gizli, yerel YZ oyunu tam işlevli) — src/lib/supabase.ts'teki
// `configured` bayrağının eşleniği.

const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get supabaseConfigured =>
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

/// Paylaşılan oyun linklerinin kökü (`https://kelimeki.com/game/:id`).
/// Web bunu `window.location.origin`'den türetiyor (preview/localhost'ta da
/// doğru çalışsın diye); uygulamanın böyle bir "origin"i olmadığından sabit.
/// Hedef sayfa girişsiz de açılabilen `SharedGamePage`.
const String webOrigin = 'https://kelimeki.com';

/// Şifre sıfırlama e-postasındaki bağlantının uygulamaya dönüş adresi.
/// Web `sendPasswordReset` `window.location.origin`'e döndürür; uygulamada
/// karşılık custom şema (AndroidManifest intent-filter'ı + Info.plist
/// CFBundleURLTypes bu şemayı kaydeder). Supabase Dashboard → Authentication →
/// URL Configuration → Redirect URLs listesinde BİREBİR bu değer olmalı —
/// yoksa GoTrue linki Site URL'e (web'e) düşürür (mobile/TESTING.md).
const String resetRedirectUri = 'kelimeki://reset';

/// Uygulama sürümü — pubspec.yaml'daki `version` ile BİRLİKTE artırılır
/// (release disiplini, bkz. mobile/CLAUDE.md "Sürüm disiplini").
/// `app_config.mobile_min_supported_version` eşiğiyle karşılaştırılır;
/// package_info_plus eklentisine bilinçli olarak bağımlılık alınmadı
/// (tek sabit için platform eklentisi gereksiz).
const String appVersion = '0.1.0';

/// Bu derlemenin GİT COMMIT'i (kısa sha) — CI `--dart-define=BUILD_SHA=...`
/// ile veriyor, yerelde boş kalır ve arayüzde `yerel` yazar.
///
/// **NEDEN VAR (15 Ağustos 2026, kullanıcı isteği):** "Düzelttim" ile
/// "cihazda görünüyor" arasındaki boşluk bu projede iki kez gerçek zaman
/// yaktı — kullanıcı BAYAT bir derlemeyi test edip "düzelmemiş" diye
/// bildirdi, çünkü ekranda hangi kodun çalıştığını söyleyen HİÇBİR ŞEY
/// yoktu. GitHub Pages yalnızca `main`'e push'ta yayınlanıyor; feature
/// dalındaki bir commit sitede ASLA görünmez.
///
/// Bu sabit o soruyu ekranın kendisinde yanıtlıyor: kullanıcının paylaştığı
/// HER ekran görüntüsü artık hangi commit'i test ettiğini taşıyor. Bir
/// doküman kuralı bunu sağlayamazdı — kural zaten vardı (Parça 19: "deploy
/// oldu mu kontrolü teşhisin parçasıdır") ve yine atlandı.
const String buildSha = String.fromEnvironment('BUILD_SHA');

/// Derleme tarihi (`YYYY-AA-GG SS:DD` UTC) — CI veriyor.
const String buildTime = String.fromEnvironment('BUILD_TIME');

/// Teşhis satırında gösterilen derleme etiketi: `a1b2c3d · 15.08 11:42`.
/// CI'dan gelmediyse (yerel `flutter run`) tek kelime: `yerel`.
String get buildLabel => formatBuildLabel(buildSha, buildTime);

/// `buildLabel`'ın saf hâli — `String.fromEnvironment` derleme zamanı sabiti
/// olduğundan testte değiştirilemiyor; biçim kuralı bu yüzden ayrı bir
/// fonksiyonda yaşıyor ve GERÇEKTEN test edilebiliyor (projenin "karar
/// mantığı saf fonksiyonda" disiplini).
String formatBuildLabel(String sha, String time) {
  if (sha.isEmpty) return 'yerel';
  return time.isEmpty ? sha : '$sha · $time';
}
