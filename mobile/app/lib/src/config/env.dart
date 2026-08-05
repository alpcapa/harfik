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

/// Uygulama sürümü — pubspec.yaml'daki `version` ile BİRLİKTE artırılır
/// (release disiplini, bkz. mobile/CLAUDE.md "Sürüm disiplini").
/// `app_config.mobile_min_supported_version` eşiğiyle karşılaştırılır;
/// package_info_plus eklentisine bilinçli olarak bağımlılık alınmadı
/// (tek sabit için platform eklentisi gereksiz).
const String appVersion = '0.1.0';
