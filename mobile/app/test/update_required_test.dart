// Zorunlu güncelleme ekranı ÇIKIŞSIZ olmamalı.
//
// NEDEN VAR (29 Ağustos 2026): bu ekran uzun süre yalnızca metinden
// ibaretti ve dosyanın başlığı "mağaza linkleri uygulama yayınlanınca
// eklenecek" diyordu. Sorun şu ki eşiği yükselttiğimiz AN kullanıcı bu
// ekranda kilitleniyor: "güncelleyin" diyoruz ama güncellemenin yolunu
// göstermiyoruz. Kapıyı ilk kez gerçekten kullanmaya hazırlanırken fark
// edildi — çıkışı, kapıyı açmadan önce yapmak gerekiyordu.
//
// ⚠ Bu testin ölçemediği şey: butonun Play'i GERÇEKTEN açması. `launchUrl`
// platform kanalına gidiyor, testte kanal yok. Ölçülen şey butonun VAR
// olması — regresyon bu ekranın sessizce metne dönmesi olurdu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/update_required_screen.dart';

void main() {
  testWidgets('ekranda mağazaya götüren bir buton VAR', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: const UpdateRequiredScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Güncelleme Gerekli'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-store-button')), findsOneWidget,
        reason: 'Zorunlu güncelleme ekranında mağaza butonu yok — eşik '
            'yükseltildiğinde kullanıcı çıkışsız bir ekranda kalır.');

    // Butona basmak ÇÖKMEMELİ: platform kanalı testte yok, `launchUrl`
    // fırlatır ve o hata yutuluyor olmalı (ekran zaten son çare).
    await tester.tap(find.byKey(const ValueKey('update-store-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'Mağaza açılamadığında ekran çökmemeli — kullanıcının '
            'elinde başka hiçbir yol yok.');
  });
}
