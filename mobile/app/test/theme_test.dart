// Tema sözleşmesi — `color_tokens_test.dart`ın tipografi karşılığı.
//
// İki şeyi birden kilitliyor: (1) Material 3'ün varsayılan harf aralığı
// (tracking) hiçbir metne SIZMIYOR — web'de karşılığı yok; (2) testler
// kendi `ThemeData`larını kurmuyor, ürünle AYNI temayı kullanıyor (yoksa
// tema üründe değişse bile testler eski temayla render edip sapmayı
// görmez — Parça 78'in yazılma sebebi tam olarak buydu).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/theme.dart';

void main() {
  testWidgets('letterSpacing yazmayan bir Text tracking MİRAS ALMAZ',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: const Scaffold(body: Text('Kelimeki')),
    ));

    final style =
        tester.renderObject<RenderParagraph>(find.text('Kelimeki')).text.style;
    expect(style?.letterSpacing, 0,
        reason: 'M3 `bodyMedium` varsayılanı 0.25 taşıyor ve style\'ında '
            'letterSpacing yazmayan HER metne miras kalıyor; web\'de bu '
            'metinlerde tracking YOK (Parça 61 ve 77 bu yüzden iki kez '
            'ürüne sızdı).');
  });

  test('temanın tüm metin stilleri sıfır tracking taşır', () {
    final t = kelimekiTheme().textTheme;
    final styles = <String, TextStyle?>{
      'displayLarge': t.displayLarge, 'displayMedium': t.displayMedium,
      'displaySmall': t.displaySmall, 'headlineLarge': t.headlineLarge,
      'headlineMedium': t.headlineMedium, 'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge, 'titleMedium': t.titleMedium,
      'titleSmall': t.titleSmall, 'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium, 'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge, 'labelMedium': t.labelMedium,
      'labelSmall': t.labelSmall,
    };
    styles.forEach((ad, s) {
      expect(s?.letterSpacing, 0, reason: '$ad tracking taşıyor');
    });
  });

  test('testler kendi ThemeData\'sını kurmaz — hepsi kelimekiTheme() kullanır',
      () {
    final sapanlar = <String>[];
    for (final f in Directory('test').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('theme_test.dart')) continue;
      if (f.readAsStringSync().contains('ThemeData(')) sapanlar.add(f.path);
    }
    expect(sapanlar, isEmpty,
        reason: 'Bu dosyalar kendi temasını kuruyor; `kelimekiTheme()` '
            'kullanmalılar, aksi halde ürün teması değişince test eski '
            'görünümü doğrulamaya devam eder: $sapanlar');
  });
}
