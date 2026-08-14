// Şifre sıfırlama parçası — forgot modu (AuthModal), ResetPasswordModal
// portu ve kök recovery kapısı (KelimekiApp.builder). Gerçek uç YOK:
// AuthService.fake `_client=null` olduğundan sendPasswordReset/setNewPassword
// 'Supabase yapılandırılmadı.' fırlatır — testler bu hatayı "akış gerçekten
// o çağrıya kadar indi"nin kanıtı olarak kullanır (signup_test'teki aynı
// desen). Gerçek e-posta + deep link + PKCE takası cihazda doğrulanacak
// (mobile/TESTING.md, "Şifre sıfırlama").
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki/src/ui/auth/auth_modal.dart';
import 'package:kelimeki/src/ui/auth/reset_password_modal.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'support/test_fonts.dart';
import 'support/test_view.dart';
import 'package:kelimeki/src/util/online_status.dart';

AppServices services(AuthService auth) => AppServices(
      onlineStatus: OnlineStatus.fake(),
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: auth,
      supabase: null,
      versionGate: VersionGateStatus.ok,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  group('AuthService.passwordRecovery', () {
    test('tetikleme ve temizleme dinleyicilere yansır', () {
      final auth = AuthService.fake();
      var notified = 0;
      auth.addListener(() => notified++);

      expect(auth.passwordRecovery, isFalse);
      auth.debugTriggerPasswordRecovery();
      expect(auth.passwordRecovery, isTrue);
      expect(notified, 1);

      auth.clearPasswordRecovery();
      expect(auth.passwordRecovery, isFalse);
      expect(notified, 2);

      // Zaten temizken tekrar temizlemek gereksiz notify üretmez.
      auth.clearPasswordRecovery();
      expect(notified, 2);
    });
  });

  group('Şifremi unuttum (forgot) modu', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(body: AuthModal(auth: AuthService.fake())),
      ));
      await tester.pump();
    }

    testWidgets('geçiş + boş e-posta + akış sendPasswordReset\'e iniyor',
        (tester) async {
      await pumpLogin(tester);
      expect(find.text('GİRİŞ'), findsOneWidget); // KModal başlığı (trUpper)

      await tester.tap(find.text('Şifremi unuttum'));
      await tester.pump();
      expect(find.text('ŞİFREMİ UNUTTUM'), findsOneWidget);
      expect(
          find.text('E-posta adresini gir, sıfırlama bağlantısı gönderelim.'),
          findsOneWidget);
      expect(find.text('BAĞLANTI GÖNDER'), findsOneWidget);
      // Şifre alanı forgot modunda HİÇ çizilmez (web `mode !== 'forgot'`).
      expect(find.widgetWithText(TextField, 'Şifre'), findsNothing);

      // Boş e-posta: web'de HTML required'ın karşılığı olan açık kontrol.
      await tester.tap(find.text('BAĞLANTI GÖNDER'));
      await tester.pump();
      expect(find.text('E-posta zorunludur.'), findsOneWidget);

      // Dolu e-posta: fake'te istemci olmadığından sendPasswordReset
      // 'Supabase yapılandırılmadı.' fırlatır — akışın oraya kadar indiğinin
      // kanıtı (signup_test'in son-adım deseni).
      await tester.enterText(
          find.widgetWithText(TextField, 'E-posta'), 'alp@ornek.com');
      await tester.tap(find.text('BAĞLANTI GÖNDER'));
      await tester.pump();
      expect(find.text('Supabase yapılandırılmadı.'), findsOneWidget);

      // Giriş ekranına dönüş linki.
      await tester.tap(find.text('Giriş ekranına dön'));
      await tester.pump();
      expect(find.text('GİRİŞ'), findsOneWidget);
      expect(find.text('ŞİFREMİ UNUTTUM'), findsNothing);
    });
  });

  group('ResetPasswordModal', () {
    testWidgets('doğrulamalar + başarı + onDone', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final saved = <String>[];
      var doneCalls = 0;
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: ResetPasswordModal(
            auth: AuthService.fake(),
            onDone: () => doneCalls++,
            passwordSetter: (p) async => saved.add(p),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('YENİ ŞİFRE BELİRLE'), findsOneWidget);

      final pw = find.widgetWithText(TextField, 'Yeni şifre');
      final confirm = find.widgetWithText(TextField, 'Yeni şifre (tekrar)');

      // Web doğrulama sırası/metinleri birebir.
      await tester.enterText(pw, '12345');
      await tester.tap(find.text('ŞİFREYİ KAYDET'));
      await tester.pump();
      expect(find.text('Yeni şifre en az 6 karakter olmalı.'), findsOneWidget);

      await tester.enterText(pw, '123456');
      await tester.enterText(confirm, '123457');
      await tester.tap(find.text('ŞİFREYİ KAYDET'));
      await tester.pump();
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      expect(saved, isEmpty);

      await tester.enterText(confirm, '123456');
      await tester.tap(find.text('ŞİFREYİ KAYDET'));
      await tester.pumpAndSettle();
      expect(saved, ['123456']);
      expect(find.text('Şifren başarıyla değiştirildi.'), findsOneWidget);

      await tester.tap(find.text('KAPAT'));
      await tester.pump();
      expect(doneCalls, 1);
    });

    testWidgets('sunucu hatası friendlyAuthMessage\'tan geçer',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: ResetPasswordModal(
            auth: AuthService.fake(),
            onDone: () {},
            passwordSetter: (_) async =>
                throw const AuthException('x', code: 'same_password'),
          ),
        ),
      ));
      await tester.pump();
      await tester.enterText(
          find.widgetWithText(TextField, 'Yeni şifre'), '123456');
      await tester.enterText(
          find.widgetWithText(TextField, 'Yeni şifre (tekrar)'), '123456');
      await tester.tap(find.text('ŞİFREYİ KAYDET'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni şifre eskisiyle aynı olamaz.'), findsOneWidget);
    });
  });

  group('Kök recovery kapısı (KelimekiApp.builder)', () {
    testWidgets('recovery → modal her şeyin önünde; ✕ → temizlenir',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final auth = AuthService.fake();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: KelimekiApp(services: services(auth))));
      await tester.pump();
      await tester.pump();
      expect(find.text('OYUNU BAŞLAT'), findsOneWidget); // Setup açık
      expect(find.text('YENİ ŞİFRE BELİRLE'), findsNothing);

      // Deep link geldi (supabase_flutter passwordRecovery olayını yayınladı).
      auth.debugTriggerPasswordRecovery();
      await tester.pump();
      expect(find.text('YENİ ŞİFRE BELİRLE'), findsOneWidget);
      // Beyaz bariyer alttaki Setup'ı örter ve dokunuşu yutar — OYUNU BAŞLAT
      // ağaçta durur (state korunur) ama artık dokunulamaz (warnIfMissed
      // false: vuruş bariyere gider, bu beklenen davranış).
      await tester.tap(find.text('OYUNU BAŞLAT'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('YENİ ŞİFRE BELİRLE'), findsOneWidget);

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/screenshots/reset_password.png');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
      });

      // ✕ web'deki onDone gibi yalnızca bayrağı temizler — oturum kalır.
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pump();
      expect(auth.passwordRecovery, isFalse);
      expect(find.text('YENİ ŞİFRE BELİRLE'), findsNothing);
      expect(find.text('OYUNU BAŞLAT'), findsOneWidget);
    });
  });
}
