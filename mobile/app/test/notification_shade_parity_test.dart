// Bildirim paneli kanalı — Dart ↔ Kotlin paritesi (ROADMAP #15).
//
// NEDEN VAR: kanal adı ve metot adı iki ayrı dilde, iki ayrı repo bölümünde
// ELLE yazılı. Uyuşmazlık SESSİZ bir arıza üretir ve bu, bu depoda en pahalı
// hata sınıfı: Dart tarafı `MissingPluginException`ı BİLEREK yutuyor (iOS ve
// test ortamında kanal yok, orada yutmak doğru davranış), dolayısıyla yanlış
// bir ad hiçbir hata göstermez — yalnızca rozet temizlenmez ve kimse fark
// etmez. Tam olarak `notification_channel_parity_test.dart`in koruduğu
// `kelimeki_oyun` kimliğiyle aynı ders.
//
// Kaynak TARAMASI yapıyor, davranış çalıştırmıyor — Kotlin bu test
// çatısından koşturulamaz. Aynı desen: `notification_channel_parity_test`,
// `icon_parity_test`, `layout_parity_test`, `client_platform_parity_test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `mobile/app` (testlerin çalışma dizini) → repo kökü.
File _repo(String rel) => File('../../$rel');

/// Yorumları söker — KODA bakan bir kontrol yorumdan besleniyorsa yalan söyler.
///
/// ⚠ **Bu fonksiyon bir HATADAN doğdu (31 Ağustos 2026).** İlk sürüm dosyanın
/// tamamında `cancelAll()` arıyordu ve negatif eş koşulduğunda ÇAĞRI silinmiş
/// olmasına rağmen test GEÇTİ: dize, `MainActivity`nin kendi doküman
/// yorumunda da geçiyordu. Yani kontrol, korumayı vaat ettiği şeyi hiç
/// korumuyordu — bu depoda en pahalı test kusuru sınıfı, çünkü yeşil bir test
/// "bakılmış" izlenimi verir.
String _yorumsuz(String kaynak) => kaynak
    // Önce blok yorumlar (`/** ... */` ve `/* ... */`), sonra satır yorumları.
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  const kotlinYol =
      'mobile/app/android/app/src/main/kotlin/com/kelimeki/kelimeki/MainActivity.kt';
  const dartYol = 'mobile/app/lib/src/data/notification_shade.dart';

  late String kotlin;
  late String dart;

  setUpAll(() {
    final k = _repo(kotlinYol);
    final d = _repo(dartYol);
    expect(k.existsSync(), isTrue, reason: '$kotlinYol bulunamadı');
    expect(d.existsSync(), isTrue, reason: '$dartYol bulunamadı');
    kotlin = _yorumsuz(k.readAsStringSync());
    dart = _yorumsuz(d.readAsStringSync());
  });

  test('kanal adı Dart ile Kotlin\'de BİREBİR aynı', () {
    final dartAd =
        RegExp(r"MethodChannel\('([^']+)'\)").firstMatch(dart)?.group(1);
    final kotlinAd = RegExp(r'MethodChannel\(\s*flutterEngine[\s\S]*?,\s*"([^"]+)"\s*\)')
        .firstMatch(kotlin)
        ?.group(1);

    expect(dartAd, isNotNull, reason: 'Dart tarafında MethodChannel(...) bulunamadı');
    expect(kotlinAd, isNotNull, reason: 'Kotlin tarafında MethodChannel(...) bulunamadı');
    expect(dartAd, kotlinAd,
        reason: 'Kanal adı uyuşmuyor — çağrı sessizce düşer, rozet temizlenmez');
  });

  test('metot adı Dart ile Kotlin\'de BİREBİR aynı', () {
    final dartMetot =
        RegExp(r"metot\s*=\s*'([^']+)'").firstMatch(dart)?.group(1);
    expect(dartMetot, isNotNull, reason: 'Dart tarafında metot sabiti bulunamadı');
    // Kotlin: when (call.method) { "<metot>" -> ... }
    expect(kotlin, contains('"$dartMetot" ->'),
        reason:
            'Kotlin `when` dalı "$dartMetot" adını tanımıyor — çağrı notImplemented\'e düşer');
  });

  test('Kotlin gerçekten cancelAll() çağırıyor', () {
    // Ada değil İŞE bakan tek kontrol: kanal doğru kurulup gövde yanlış
    // şeyi yapsaydı (ör. yalnızca `result.success`) testlerin hepsi geçer,
    // rozet yine temizlenmezdi.
    expect(kotlin, contains('cancelAll()'),
        reason: 'MainActivity bildirimleri kaldırmıyor');
  });
}
