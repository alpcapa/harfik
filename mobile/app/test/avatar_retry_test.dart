// Bağlantı geri gelince yüklenememiş avatar YENİDEN DENENİR.
//
// NEDEN VAR (29 Ağustos 2026, kullanıcı cihazda bildirdi: *"app açıkken
// internet gelince avatar güncellenmedi, sadece aç kapa yapınca
// düzeliyor"*): `_broken` bayrağı yalnızca URL değişince sıfırlanıyordu,
// yani bağlantı kesikken bir kez düşen görsel o widget yaşadığı sürece baş
// harflerde kalıyordu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/auth/k_avatar.dart';
import 'package:kelimeki/src/ui/online_scope.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/util/online_status.dart';

import 'support/test_fonts.dart';

/// `Image.network` testte gerçekten ağa çıkamaz; hata dalı KENDİLİĞİNDEN
/// tetiklenir, yani "yüklenemedi" durumunu ayrıca taklit etmeye gerek yok.
Widget _kur(OnlineStatus status) => OnlineScope(
      status: status,
      child: MaterialApp(
        theme: kelimekiTheme(),
        home: const Scaffold(
          body: Center(
            child: KAvatar(
                url: 'https://ornek.invalid/a.jpg', name: 'Ironman', size: 40),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadAppFonts);

  testWidgets('çevrimiçine dönünce görsel yeniden denenir', (tester) async {
    final status = OnlineStatus.fake(online: false);
    await tester.pumpWidget(_kur(status));
    await tester.pumpAndSettle();

    // Yüklenemedi → baş harfler.
    expect(find.text('IR'), findsOneWidget,
        reason: 'görsel düşünce baş harflere inilmeli (web <img onError>)');

    // Bağlantı geri geldi.
    status.debugSetOnline(true);
    await tester.pump();

    // `Image` yeniden inşa edilmiş olmalı — yani yeniden denendi.
    expect(find.byType(Image), findsOneWidget,
        reason: 'Çevrimiçine dönüldü ama görsel yeniden denenmedi: _broken '
            'takılı kalmış. Kullanıcı ancak uygulamayı kapatıp açarak '
            'avatarını geri görebilir.');
  });

  testWidgets('KAPSAM YOKKEN davranış eskisiyle aynı (izole widget)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: KAvatar(
              url: 'https://ornek.invalid/a.jpg', name: 'Ironman', size: 40),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('IR'), findsOneWidget);
  });
}
