// Dışarıdan gelen bir ROTA uygulamayı ÇÖKERTMEMELİ (31 Ağustos 2026).
//
// SAHA KAYDI: `client_errors`ta 26–29 Ağustos arasında **11 ayrı cihazda**
// `boundary / Null check operator used on a null value` çöktü. Yığın izi
// mekanizmayı tek başına anlatıyor:
//
//   _WidgetsAppState._onUnknownRoute      ← burada patlıyor
//   NavigatorState.pushNamed
//   _WidgetsAppState.didPushRouteInformation
//   WidgetsBinding._handlePushRouteInformation
//
// İşletim sistemi bir derin bağlantıya dokunulunca uygulamaya rota bilgisi
// gönderiyor; Flutter bunu `pushNamed` ile açmaya çalışıyor, tanımadığı için
// `widget.onUnknownRoute!` diyor — ve bizde o alan YOKTU, yani `null!`.
//
// ⚠ Bu, uygulamanın derin bağlantı yolu DEĞİL: linkleri `app_links` yakalıyor
// (`game_link_inbox` / `friend_invite_inbox`). Flutter'ın Navigator yolu bizde
// hiç kullanılmıyor — o yüzden burada doğru davranış rotayı AÇMAK değil,
// SESSİZCE YOK SAYMAK.
//
// Test bunu gerçek kanaldan besliyor (`flutter/navigation` →
// `pushRouteInformation`), yani `didPushRouteInformation` gerçekten koşuyor.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

AppServices _services() => AppServices(
      onlineStatus: OnlineStatus.fake(),
      dictionary: Future.value(SetWordSource(const ['ab'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: AuthService(null),
      supabase: null,
      versionGate: VersionGateStatus.ok,
    );

/// Platformun rota gönderişini birebir taklit eder.
Future<void> _rotaGonder(WidgetTester tester, String yol) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', <String, dynamic>{'location': yol}),
      ),
      (_) {},
    );

void main() {
  test('Android manifest: Flutter\'ın kendi derin bağlantı yolu KAPALI', () {
    // Asıl kapatma bu — Dart tarafındaki `onUnknownRoute` yalnızca ikinci
    // katman. Bayrak sessizce kaybolursa (ör. manifest yeniden üretilir)
    // motor rota göndermeye başlar ve çökme sınıfı geri gelir; o yüzden
    // testle kilitli. Linkleri `app_links` yakalıyor, kaybedilen yol YOK.
    final manifest = File(
        '../../mobile/app/android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);
    final xml = manifest.readAsStringSync().replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    final deger = RegExp(
            r'android:name="flutter_deeplinking_enabled"[\s\S]*?android:value="([^"]+)"')
        .firstMatch(xml)
        ?.group(1);
    expect(deger, 'false',
        reason: 'flutter_deeplinking_enabled false DEĞİL — çökme sınıfı geri gelir');
  });

  testWidgets('bilinmeyen rota ÇÖKERTMEZ ve ekranı değiştirmez',
      (tester) async {
    await tester.pumpWidget(KelimekiApp(services: _services()));
    await tester.pump();
    expect(find.text('OYUN TİPİ'), findsOneWidget);

    // `kelimeki://oyun/<id>` ya da `https://kelimeki.com/davet/<token>`
    // dokunuşunun platform tarafındaki karşılığı.
    await _rotaGonder(tester, '/oyun/11111111-2222-3333-4444-555555555555');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'Dışarıdan gelen rota uygulamayı çökertti');
    // Kullanıcı olduğu yerde kalmalı — boş/yabancı bir ekrana düşmemeli.
    expect(find.text('OYUN TİPİ'), findsOneWidget);
  });

  testWidgets('davet biçimindeki rota da aynı şekilde yok sayılır',
      (tester) async {
    await tester.pumpWidget(KelimekiApp(services: _services()));
    await tester.pump();

    await _rotaGonder(tester, '/davet/abc123');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('OYUN TİPİ'), findsOneWidget);
  });
}
