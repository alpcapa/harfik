// "Uzun aradan sonra öne dönüş = ekrana yeniden giriş" eşiği.
//
// İki iş yapıyor: (1) `AwayTracker`ın kararını sınar, (2) eşiğin web ile AYNI
// olduğunu web dosyasını OKUYARAK zorlar (`offline_notice_test`/
// `rank_tiers_parity_test`in aynı deseni) — biri değişip öteki kalırsa iki
// platform sessizce ayrışır, hiçbir derleyici bunu yakalamaz.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/away_return.dart';

/// Kontrol edilebilir bir saat — testler gerçek zamanı beklemez.
class _Clock {
  DateTime t = DateTime.utc(2026, 8, 21, 12);
  DateTime now() => t;
  void advance(Duration d) => t = t.add(d);
}

void main() {
  test('uzaklaşma görülmediyse karar verilmez', () {
    final c = _Clock();
    final at = AwayTracker(now: c.now);
    expect(at.takeLongAway(), isFalse);
  });

  test('kısa bir kesinti yeniden silahlandırmaz', () {
    // Bu değişikliğin BÜTÜN riski burada: eşik olmasaydı bildirim bandı /
    // Kontrol Merkezi gibi anlık kesintiler bile kullanıcıyı bilerek
    // oturduğu sekmeden koparırdı.
    final c = _Clock();
    final at = AwayTracker(now: c.now);
    at.markAway();
    c.advance(const Duration(seconds: 30));
    expect(at.takeLongAway(), isFalse);
  });

  test('uzun aradan sonra dönüş yeniden silahlandırır', () {
    final c = _Clock();
    final at = AwayTracker(now: c.now);
    at.markAway();
    c.advance(const Duration(minutes: 30));
    expect(at.takeLongAway(), isTrue);
  });

  test('eşiğin tam kendisi sayılır, 1 ms altı sayılmaz', () {
    final c = _Clock();
    final at = AwayTracker(now: c.now);
    at.markAway();
    c.advance(kLongAway);
    expect(at.takeLongAway(), isTrue);

    final c2 = _Clock();
    final at2 = AwayTracker(now: c2.now);
    at2.markAway();
    c2.advance(kLongAway - const Duration(milliseconds: 1));
    expect(at2.takeLongAway(), isFalse);
  });

  test('İLK markAway kazanır (inactive + paused art arda gelir)', () {
    final c = _Clock();
    final at = AwayTracker(now: c.now);
    at.markAway();
    c.advance(const Duration(minutes: 20));
    at.markAway(); // ikinci lifecycle olayı
    expect(at.takeLongAway(), isTrue);
  });

  test('karar bir kez tüketilir, sonraki uzaklaşma yeniden ölçülür', () {
    final c = _Clock();
    final at = AwayTracker(now: c.now);
    at.markAway();
    c.advance(const Duration(minutes: 30));
    expect(at.takeLongAway(), isTrue);
    expect(at.takeLongAway(), isFalse);

    at.markAway();
    c.advance(const Duration(seconds: 10));
    expect(at.takeLongAway(), isFalse);
  });

  group('web paritesi', () {
    final web = File('../../src/utils/awayReturn.ts');

    test('web dosyası bulunabiliyor (yol değişirse test sessizce geçmesin)',
        () {
      expect(web.existsSync(), isTrue,
          reason: 'src/utils/awayReturn.ts bulunamadı — yol mu değişti?');
    });

    test('eşik web ile birebir aynı', () {
      final src = web.readAsStringSync();
      final m = RegExp(r'export const LONG_AWAY_MS = ([\d\s*]+);').firstMatch(src);
      expect(m, isNotNull, reason: 'LONG_AWAY_MS okunamadı');
      final ms = m!
          .group(1)!
          .split('*')
          .map((p) => int.parse(p.trim()))
          .reduce((a, b) => a * b);
      expect(kLongAway.inMilliseconds, ms);
    });
  });
}
