// Rafın üstündeki mesaj satırı yazı ölçeğinde KESİLMEZ.
//
// 2 Eylül 2026, kullanıcı cihazda (en büyük punto): *"Rafın üzerindeki
// mesaj kutusu 2 satırda kesiliyor."* Port `SizedBox(height: 30)` ile SABİT
// yükseklik veriyordu; web ikizi ise `min-h-[30px]`, yani ASGARİ. Ölçekte
// iki satır 30 px'e sığmayınca metin kesiliyordu.
//
// Test yapıyı değil DAVRANIŞI ölçüyor: kutu, içindeki metni tamamen
// barındırıyor mu?
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/text_scale.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'game_screen_test.dart' show craftedState;
import 'support/test_view.dart';

const _uzunMesaj =
    'Asnmzr: +9 puan (5 puanı Ironman kaptı) Kelimeler: İTİ, İP';

void main() {
  Future<double> yukseklikFarki(WidgetTester tester, double olcek) async {
    await setPhoneViewSize(tester, const Size(360, 900));
    final words = SetWordSource(const ['ab', 'aba', 'kelime']);
    final c = GameController(words: words, autoPlayAi: false, nowIso: () => '');
    c.dispatch(ResumeSavedAction(craftedState().copyWith(message: _uzunMesaj)));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(olcek)),
          child: GameScreen(
              controller: c, words: words, auth: AuthService.fake()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final kutu = tester.getRect(find.byKey(const ValueKey('message-line')));
    // ⚠ `getRect(find.text(...))` KESİLMEYİ GÖRMEZ: sabit kutuda metin de
    // 30 px'e sıkıştırılıyor ve fark 0 çıkıyor (ölçüldü — ilk sürümün
    // negatif eşi bu yüzden yanlışlıkla geçti). Metnin GERÇEKTEN ihtiyaç
    // duyduğu yükseklik ayrıca hesaplanıyor.
    final tp = TextPainter(
      text: TextSpan(
        text: _uzunMesaj,
        style: const TextStyle(
            fontSize: 11, fontFamily: 'SpaceMono', fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: TextScaler.linear(olcek),
    )..layout(maxWidth: kutu.width);
    return tp.height - kutu.height;
  }

  testWidgets('mesaj satırı ölçekte kesilmez (kutu metni barındırır)',
      (tester) async {
    // Normal ölçek: kutu zaten 30 px asgarisinde ve metin sığıyor.
    expect(await yukseklikFarki(tester, 1.0), lessThanOrEqualTo(0.5),
        reason: 'ölçek 1,0da metin kutuya sığmalı');
    // Tavan: kutu metinle birlikte BÜYÜMELİ. Sabit yükseklikte bu düşer —
    // negatif eşi koşuldu (30 px kutuda 38 px metin).
    expect(await yukseklikFarki(tester, kMaxTextScale), lessThanOrEqualTo(0.5),
        reason: 'ölçek tavanında metin kutudan taşıyor — KESİLİR');
  });
}
