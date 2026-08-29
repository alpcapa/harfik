// Bildirim kanalı — Kotlin ↔ Edge Function paritesi.
//
// NEDEN VAR (28 Ağustos 2026): Android 8+'ta VAR OLMAYAN bir `channel_id`'ye
// gelen bildirim GÖSTERİLMEZ ve hiçbir hata da vermez. Sunucu 200 döner,
// cihazda hiçbir şey olmaz — bu projenin en sevmediği sessiz arıza sınıfı.
// Kimlik iki ayrı dilde, iki ayrı repo bölümünde, elle yazılı: derleyici de
// `dart analyze` de bunu göremez.
//
// Aynı turda ölçülen İKİNCİ tuzak da burada kilitleniyor: kanal ÖNEMİ.
// `IMPORTANCE_DEFAULT` ile bildirim geliyor ama peek etmiyor (ses ✅,
// gölgelik ✅, rozet ✅, açılır banner ❌ — gerçek cihazda gözlendi).
// Sunucudaki `priority: 'high'` bunu sağlamıyor; o FCM'in TESLİMAT önceliği,
// sunum değil. Önem DEFAULT'a geri çekilirse bu test düşer ve değişikliğin
// bilinçli olması gerekir.
//
// ✅ **29 Ağustos 2026 — NEDEN-SONUÇ DOĞRULANDI.** 28 Ağustos'ta bu teşhis
// ORTAYA ATILDI ama kanıtlanamadı (kullanıcı uygulama ve kategori düzeyindeki
// açılır-pencere ayarlarını açtı, banner yine çıkmadı) ve o gün dürüstçe geri
// çekildi — sebebi şuydu: kanalın önemi YARATILDIKTAN SONRA yükseltilemiyor,
// yani eski kurulumda kanal DEFAULT olarak doğmuştu ve kod düzeltilse bile
// davranış değişmiyordu. Uygulama kaldırılıp yeniden kurulunca kanal ilk kez
// HIGH doğdu ve banner GELDİ (ses + banner, gerçek cihaz). Ders: "ayarlar
// açık ama çalışmıyor" bir çürütme DEĞİL — önce kanalın hangi önemle
// DOĞDUĞUNA bak.
//
// Kaynak TARAMASI yapıyor, davranış çalıştırmıyor — Kotlin bu test
// çatısından koşturulamaz. Aynı desen: `icon_parity_test.dart`,
// `layout_parity_test.dart`, `client_platform_parity_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `mobile/app` (testlerin çalışma dizini) → repo kökü.
File _repo(String rel) => File('../../$rel');

void main() {
  const kotlinYol =
      'mobile/app/android/app/src/main/kotlin/com/kelimeki/kelimeki/MainActivity.kt';
  const sunucuYol = 'supabase/functions/_shared/push.ts';

  late String kotlin;
  late String sunucu;

  setUpAll(() {
    final k = _repo(kotlinYol);
    final s = _repo(sunucuYol);
    expect(k.existsSync(), isTrue, reason: '$kotlinYol bulunamadı');
    expect(s.existsSync(), isTrue, reason: '$sunucuYol bulunamadı');
    kotlin = k.readAsStringSync();
    sunucu = s.readAsStringSync();
  });

  test('kanal kimliği Kotlin ile Edge Function\'da BİREBİR aynı', () {
    // Kotlin: NotificationChannel("<id>", ...)
    final kotlinId = RegExp(r'NotificationChannel\(\s*"([^"]+)"')
        .firstMatch(kotlin)
        ?.group(1);
    // Sunucu: channel_id: '<id>'
    final sunucuId =
        RegExp(r"channel_id:\s*'([^']+)'").firstMatch(sunucu)?.group(1);

    expect(kotlinId, isNotNull,
        reason: 'MainActivity.kt\'de NotificationChannel("…") bulunamadı — '
            'kanal yaratma kodu taşındıysa bu testin deseni de güncellenmeli');
    expect(sunucuId, isNotNull,
        reason: '_shared/push.ts\'te channel_id bulunamadı');

    expect(sunucuId, kotlinId,
        reason: 'Kanal kimlikleri AYRIŞTI (Kotlin: $kotlinId · sunucu: '
            '$sunucuId). Android 8+ tanımadığı kanala gelen bildirimi SESSİZCE '
            'yutar: sunucu 200 döner, cihazda hiçbir şey görünmez.');
  });

  test('kanal önemi HIGH — DEFAULT açılır banner göstermiyor', () {
    expect(kotlin.contains('NotificationManager.IMPORTANCE_HIGH'), isTrue,
        reason: 'Kanal önemi HIGH değil. Gerçek cihazda ölçüldü: DEFAULT ile '
            'ses ve rozet geliyor ama açılır banner ÇIKMIYOR. Sunucudaki '
            'priority:"high" bunu sağlamaz (o teslimat önceliği, sunum değil). '
            'Bilerek düşürüyorsan bu testi gerekçesiyle güncelle.');
  });
}
