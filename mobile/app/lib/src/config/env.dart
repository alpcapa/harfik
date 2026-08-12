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
