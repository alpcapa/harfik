// Analytics kanalının İKİ değişmezi (data/analytics.dart):
// fire-and-forget (asla fırlatmaz) ve yapılandırılmamışken sessiz no-op.

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/analytics.dart';

import 'support/fake_analytics.dart';

class _ThrowingLogger implements AnalyticsLogger {
  @override
  Future<void> log(String name, Map<String, Object>? params) async {
    throw Exception('uç arızası');
  }
}

void main() {
  tearDown(analytics.reset);

  test('yapılandırılmamışken no-op — fırlatmaz', () {
    expect(() => analytics.log('x', {'a': 1}), returnsNormally);
  });

  test('olay ada ve parametreye kadar ulaşır', () async {
    final fake = FakeAnalytics();
    analytics.configure(fake);
    analytics.log('signup_started');
    analytics.log('intro_slide_viewed', {'index': 2});
    await Future<void>.delayed(Duration.zero);
    // Record'lar `==` ile karşılaştırılır ve Map alanını DERİN eşitlemez
    // (iki ayrı Map örneği == değil) — alanlar ayrı ayrı doğrulanıyor.
    expect(fake.names, ['signup_started', 'intro_slide_viewed']);
    expect(fake.events[0].$2, isNull);
    expect(fake.events[1].$2, {'index': 2});
  });

  test('ucun fırlatması YUTULUR — çağıran akış düşmez', () async {
    analytics.configure(_ThrowingLogger());
    expect(() => analytics.log('x'), returnsNormally);
    // Asenkron hata da yüzeye çıkmamalı — mikrotask kuyruğu boşalana kadar
    // bekle; yakalanmamış hata olsaydı test çatısı burada düşürürdü.
    await Future<void>.delayed(Duration.zero);
  });

  test('reset sonrası yeniden no-op (test sızıntısı koruması)', () async {
    final fake = FakeAnalytics();
    analytics.configure(fake);
    analytics.reset();
    analytics.log('x');
    await Future<void>.delayed(Duration.zero);
    expect(fake.events, isEmpty);
  });
}
