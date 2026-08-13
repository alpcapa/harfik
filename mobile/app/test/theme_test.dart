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
import 'package:kelimeki/src/ui/form_input.dart';
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

  testWidgets('form alanı web ile aynı yükseklikte (38) ve 16 punto',
      (tester) async {
    // Web ölçümü (derlenmiş CSS + Chromium, gerçek fontla): yükseklik 38 =
    // 20 (satır) + 8 + 8 (py-2) + 2 (çerçeve); punto 16 — `text-sm`in 14'ü
    // DEĞİL, çünkü index.css'teki iOS zoom kuralı
    // (`input,textarea,select{font-size:16px!important}`) sınıfı eziyor.
    // Port sekiz kopyada 10 dolgu + karışık punto kullanıyordu.
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 296, // web'in ölçülen içerik genişliği
            child: TextField(
              style: kInputTextStyle,
              decoration: kInputDecoration(hint: 'E-posta'),
            ),
          ),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(TextField)).height, kInputHeight);
    expect(kInputTextStyle.fontSize, 16);
    expect(kInputTextStyle.height! * kInputTextStyle.fontSize!, 20);
  });

  test('form alanları kendi InputDecoration\'ını kurmaz', () {
    final sapanlar = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('form_input.dart')) continue;
      // `kInputDecoration(` çağrılarını YAKALAMAZ — aranan şey ham
      // `InputDecoration(` kurucusu.
      if (RegExp(r'(?<![A-Za-z])InputDecoration\(')
          .hasMatch(f.readAsStringSync())) {
        sapanlar.add(f.path);
      }
    }
    expect(sapanlar, isEmpty,
        reason: 'Bu dosyalar kendi giriş dekorasyonunu kuruyor; '
            '`kInputDecoration()` kullanmalılar — sekiz kopya sessizce '
            'ayrışmıştı (dolgu 8 ya da 10, punto 16 ya da tema '
            'varsayılanı): $sapanlar');
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
