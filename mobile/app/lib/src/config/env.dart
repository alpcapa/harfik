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

/// Kayıt onayı e-postasındaki bağlantının uygulamaya dönüş adresi.
///
/// **NEDEN VAR (28 Ağustos 2026, ROADMAP madde 1 — mağaza blokeri):**
/// `signUp` hiçbir `emailRedirectTo` geçmediğinden GoTrue onay linkini
/// Supabase'deki TEK Site URL'e (kelimeki.com) atıyordu; uygulamadan kayıt
/// olan kişi tarayıcıya düşüyor, oradan uygulamaya dönüp ELLE giriş yapmak
/// zorunda kalıyordu. 17 Ağustos 2026'da cihazda bizzat gözlendi ve o
/// sekmede BAŞKA bir hesabın oturumu açıktı (bkz. mobile/CLAUDE.md, "Kayıt
/// onayı maili kaydın GELDİĞİ kanala dönmeli").
///
/// **Asıl kazanç yalnızca "doğru uygulama açılıyor" değil:** link uygulamaya
/// dönerse PKCE `code_verifier` ZATEN o cihazın uygulama deposunda
/// olduğundan supabase_flutter takası yapıp kullanıcıyı DOĞRUDAN girişli
/// bırakır — "e-postanı doğrula, sonra dönüp giriş yap" adımı kalkar.
///
/// `resetRedirectUri` ile aynı el işi: Supabase Dashboard → Authentication →
/// URL Configuration → Redirect URLs listesinde BİREBİR bu değer olmalı,
/// yoksa GoTrue sessizce Site URL'e düşürür ve hiçbir şey değişmez.
/// E-posta ŞABLONU değişmez — üç şablon da `{{ .ConfirmationURL }}`
/// kullanıyor ve GoTrue o URL'i `redirect_to` ile kendisi kuruyor (ölçüldü).
///
/// **NEDEN custom şema DEĞİL https (28 Ağustos 2026, kullanıcı kararı:
/// "Güvenli alternatif olsun"):** ilk sürümü `kelimeki://auth` idi ve tek
/// bir senaryoda ÇIKMAZ üretiyordu — kayıt e-postası uygulamanın KURULU
/// OLMADIĞI bir yerde açılırsa (insanlar postalarını sıklıkla masaüstünden
/// okur; ayrıca telefonu değiştiren/uygulamayı silen kişi). Tarayıcı
/// `kelimeki://` şemasını çözemez ve kullanıcı `ERR_UNKNOWN_URL_SCHEME`
/// görür: onay linki BOZUK görünür. Oysa e-postayı doğrulama işlemi
/// GoTrue'nun kendi `/verify` ucunda ZATEN tamamlanmıştır; kaybedilen tek
/// şey oturumdur — yani kullanıcıya "bozuk" diye görünen şey aslında
/// yalnızca son adımdır.
///
/// https biçiminde en kötü durum BUGÜNKÜ davranış: App Links doğrulaması
/// geçmediyse (ya da uygulama kurulu değilse) link kelimeki.com'da açılır,
/// kullanıcı elle giriş yapar — hiçbir hata ekranı yok. Doğrulama
/// geçtiğindeyse (Play imzalı derleme) işletim sistemi URI'yi uygulamaya
/// düşürür ve PKCE takası yapılıp kullanıcı DOĞRUDAN girişli kalır, yani
/// asıl kazanç korunur.
///
/// Üç teknik ön koşul da zaten sağlanmış durumda:
/// 1. AndroidManifest'teki App Links filtresi `https://kelimeki.com`ın
///    TAMAMINI (yol kısıtı YOK) talep ediyor — `/auth` için ek satır yok.
/// 2. `/.well-known/assetlinks.json` 25 Ağustos 2026'da yayınlandı.
/// 3. supabase_flutter gelen URI'yi ŞEMAYA BAKMADAN sınıflandırıyor
///    (`_defaultIsAuthCallbackDeeplink`: yalnızca `code`/`access_token`/
///    `error*` parametrelerine bakar — paketin kaynağında ölçüldü), yani
///    https bir dönüş de custom şema kadar sorunsuz işleniyor.
///
/// ⚠ **CI'nın debug-imzalı `.apk`'sında App Links doğrulaması GEÇMEZ**
/// (farklı imza parmak izi) — orada bu link tarayıcıda açılır. Yani bu
/// akışın "uygulama açılıyor" yarısı YALNIZCA Play'den kurulan derlemede
/// test edilebilir; `.apk`da görülecek olan güvenli yedek yoldur.
const String authRedirectUri = 'https://kelimeki.com/auth';

/// Uygulama sürümü — pubspec.yaml'daki `version` ile BİRLİKTE artırılır
/// (release disiplini, bkz. mobile/CLAUDE.md "Sürüm disiplini").
/// `app_config.mobile_min_supported_version` eşiğiyle karşılaştırılır;
/// package_info_plus eklentisine bilinçli olarak bağımlılık alınmadı
/// (tek sabit için platform eklentisi gereksiz).
const String appVersion = '1.0.6';

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
