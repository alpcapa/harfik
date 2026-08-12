// Web'de SQLite arka ucu — koşullu import kapısı.
//
// NEDEN: `sqflite` mobilde bir platform kanalı (native SQLite) kullanıyor;
// tarayıcıda böyle bir kanal YOK, çağrılar MissingPluginException fırlatıyor
// ve depolamaya bağlı her ekran ("KAYITLAR KONTROL EDİLİYOR…") asılı kalıyor.
// `sqflite_common_ffi_web` aynı `DatabaseFactory` arayüzünü WASM derlenmiş
// sqlite3 + IndexedDB üzerinden veriyor — yani şema/sorgu/kod yolu değişmiyor,
// yalnızca fabrika değişiyor.
//
// NEDEN KOŞULLU IMPORT: `sqflite_common_ffi_web` yalnızca web'de derlenebilen
// js_interop kodu içeriyor; doğrudan import edilirse iOS/Android derlemesini
// KIRAR. Aşağıdaki `export ... if (...)` sayesinde mobil derlemede yalnızca
// stub görülür (her zaman `null` döner) ve mevcut kod yolu bire bir korunur.
//
// Web derlemesi bir TEST ORTAMIDIR (bkz. mobile/TESTING.md, "Web derlemesi") —
// ürün hedefi hâlâ iOS/Android. Bu dosya o yüzden mümkün olan en dar yüzeyi
// tutuyor: tek fonksiyon, tek kullanım yeri (openAppDatabase).
export 'web_db_stub.dart' if (dart.library.js_interop) 'web_db_web.dart';
