// İstatistik kutularının ETİKETİ — web gibi SARMALI, küçültülmemeli.
//
// NEDEN VAR (28 Ağustos 2026, kullanıcı cihazda bildirdi, ekran görüntüsüyle:
// *"app'de oyun istatistikleri başlıkları tek satır ve çok küçük font. Web'le
// aynı olmalı."*): etiket `FittedBox(fit: scaleDown)` içindeydi. `FittedBox`
// çocuğuna SINIRSIZ genişlik verir — yani `Text` sarmaya hiç çalışmaz, tek
// satır olarak yerleşir ve sonra kutuya sığsın diye KÜÇÜLTÜLÜR. Uzun etiketler
// ("EN YÜKSEK PUANLI KELİME", "ORTALAMA HAMLE PUANI (OHP)") bu yüzden 8 px'in
// çok altına düşüp okunamaz hâle geliyordu.
//
// Web (`ScoreStatsSection.tsx`) böyle yapmıyor: etiket düz bir `div`
// (`text-[8px] uppercase tracking-[1px]`), yani punto SABİT ve metin iki-üç
// satıra SARIYOR. Kaynak web olduğundan port da öyle olmalı.
//
// Bu testin ölçtüğü şey: etiketin kendi kutusu, hücrenin İÇ genişliğini
// AŞMIYOR. `FittedBox` altında `Text`in kendi kutusu doğal (tek satırlık)
// genişliğidir — yani hata geri gelirse bu ölçüm patlar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/score/score_stats_section.dart';
import 'package:kelimeki/src/ui/theme.dart';

import 'support/test_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  // KModal: maxWidth 360, gövde dolgusu LTRB(20,16,20,20) → içerik 320.
  // Izgara: 3 sütun, 8 px boşluk → birim (320-16)/3 = 101.33.
  // Hücre dolgusu yatayda 4+4 → etiketin kullanabileceği genişlik 93.33.
  const icerik = 320.0;
  const birim = (icerik - 16) / 3;
  const etiketAlani = birim - 8;

  Future<void> ac(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: icerik,
            child: ScoreStatsSection(
              stats: null,
              loaded: true,
              emptyText: 'Henüz oyun yok.',
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('uzun etiketler SARIYOR — tek satıra sıkışıp küçülmüyor',
      (tester) async {
    await ac(tester);

    // Izgaranın en uzun iki etiketi; ikisi de tek sütunluk (span2 DEĞİL)
    // hücrede duruyor, yani web'de de sarmak zorundalar.
    for (final etiket in const [
      'EN YÜKSEK PUANLI KELİME',
      'ORTALAMA HAMLE PUANI (OHP)',
    ]) {
      final f = find.text(etiket);
      expect(f, findsOneWidget, reason: '$etiket kutusu bulunamadı');

      final boyut = tester.getSize(f);
      expect(boyut.width, lessThanOrEqualTo(etiketAlani + 0.5),
          reason: '"$etiket" hücreye sığmıyor: ${boyut.width.toStringAsFixed(1)} '
              '> $etiketAlani. FittedBox geri gelmiş olabilir — o, çocuğuna '
              'sınırsız genişlik verip metni tek satıra dizer ve sonra '
              'küçültür; web ise punto sabit tutup SARDIRIR.');

      // Sarmanın gerçekten olduğu: 8 px punto tek satırda ~11 px yüksekliktir.
      expect(boyut.height, greaterThan(16),
          reason: '"$etiket" tek satırda kalmış (yükseklik '
              '${boyut.height.toStringAsFixed(1)}) — sarmıyor demektir.');
    }
  });

  testWidgets('etiket puntosu web ile aynı: 8 px, tracking 1', (tester) async {
    await ac(tester);
    final t = tester.widget<Text>(find.text('TOPLAM OYUN'));
    expect(t.style?.fontSize, 8, reason: 'web: text-[8px]');
    expect(t.style?.letterSpacing, 1, reason: 'web: tracking-[1px]');
    expect(t.textAlign, TextAlign.center);
  });
}
