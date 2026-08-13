// Auth fazı parça 1 — AuthService kimlik kuralları (web useAuth/Setup/
// UserMenu paritesi), friendlyAuthMessage eşlemesi ve Setup/giriş penceresi
// widget akışları. Gerçek ağ YOK: AuthService.fake ile durumlar kurulur;
// gerçek Supabase el sıkışması cihazda kullanıcı tarafından doğrulanacak
// (play-ai-turn'deki aynı "doğrulama sınırı" notu).
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
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

User fakeUser({String email = 'alp.capa@hotmail.com'}) => User(
      id: 'u-test',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: email,
    );

const ironman = KProfile(
  id: 'u-test',
  displayName: 'Ironman',
  firstName: 'Alp',
  lastName: 'Çapa',
);

AppServices services(AuthService auth) => AppServices(
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: auth,
      supabase: null,
      versionGate: VersionGateStatus.ok,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  group('friendlyAuthMessage (web eşlemesiyle birebir)', () {
    test('kod eşleşmesi', () {
      expect(
          friendlyAuthMessage(
              const AuthException('x', code: 'invalid_credentials')),
          'E-posta ya da şifre hatalı.');
      expect(friendlyAuthMessage(const AuthException('x', code: 'user_banned')),
          contains('donduruldu'));
      expect(
          friendlyAuthMessage(
              const AuthException('x', code: 'email_not_confirmed')),
          contains('doğrulamadın'));
    });

    test('kod yoksa mesaj metnine düşer', () {
      expect(
          friendlyAuthMessage(const AuthException('Invalid login credentials')),
          'E-posta ya da şifre hatalı.');
      expect(friendlyAuthMessage(const AuthException('User is banned')),
          contains('donduruldu'));
    });

    test('bilinmeyen hata null döner (orijinal mesaj gösterilsin)', () {
      expect(friendlyAuthMessage(const AuthException('garip bir şey oldu')),
          isNull);
      expect(friendlyAuthMessage(Exception('network down')), isNull);
    });
  });

  group('kimlik kuralları (web accountName/menuName)', () {
    test('profil takma adı > ad > e-posta öneki', () {
      expect(AuthService.fake(user: fakeUser(), profile: ironman).accountName,
          'Ironman');
      expect(
          AuthService.fake(
            user: fakeUser(),
            profile: const KProfile(id: 'u', firstName: 'Alp'),
          ).accountName,
          'Alp');
      // Profil yok ama yükleme BİTTİ → e-posta öneki.
      expect(AuthService.fake(user: fakeUser()).accountName, 'alp.capa');
    });

    test('profil beklenirken accountPending (e-postaya düşülmez)', () {
      final a = AuthService.fake(user: fakeUser(), profileLoading: true);
      expect(a.accountName, isNull); // web: bir anlık yanlış isim yok
      expect(a.accountPending, isTrue);
      expect(a.identityLoading, isTrue);
    });

    test('çıkışta misafir durumu', () {
      final a = AuthService.fake();
      expect(a.user, isNull);
      expect(a.accountName, isNull);
      expect(a.accountPending, isFalse);
    });

    test('AuthService(null): yapılandırılmamış → hesap UI kapalı', () {
      final a = AuthService(null);
      expect(a.configured, isFalse);
      expect(a.loading, isFalse); // UI kilitlenmez
    });
  });

  testWidgets('Setup girişli: sağ üstte avatar, 1. koltuk hesap sahibi',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final auth = AuthService.fake(user: fakeUser(), profile: ironman);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: RepaintBoundary(
          key: key, child: SetupScreen(services: services(auth))),
    ));
    await tester.pump();
    await tester.pump();

    // 1. koltuk: takma ad + SEN etiketi; GİRİŞ butonu YOK (avatar var).
    expect(find.text('Ironman'), findsOneWidget);
    expect(find.text('Misafir'), findsNothing);
    expect(find.text('SEN'), findsOneWidget);
    expect(find.text('GİRİŞ'), findsNothing);
    // Avatar baş harfleri: hesap satırı (20px) + sağ üst köşe (32px).
    // "Ironman" BÜYÜK I ile başlar → trUpper 'IR' üretir (İ değil — noktasız
    // I zaten büyük, Türkçe kural yalnızca küçük i'yi İ yapar).
    expect(find.text('IR'), findsNWidgets(2));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/setup_logged_in.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    // Başlatılan oyunda 1. oyuncunun adı hesap sahibi (web doStart kuralı).
    await tester.tap(find.text('OYUNU BAŞLAT'));
    await tester.pumpAndSettle();
    expect(find.text('IRONMAN'), findsOneWidget); // GameHeader (trUpper)

    // Hesap menüsü oyun ekranında da: avatara dokun → menü.
    await tester.tap(find.text('IR').last);
    await tester.pumpAndSettle();
    // Menü maddeleri emoji önekli tek Text ('🚪  Çıkış Yap') — textContaining.
    expect(find.textContaining('Çıkış Yap'), findsOneWidget);
    expect(find.textContaining('Nasıl Oynanır?'), findsOneWidget);
  });

  testWidgets('Setup çıkışlı (configured): GİRİŞ → giriş penceresi + doğrulama',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final auth = AuthService.fake();
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: SetupScreen(services: services(auth)),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Misafir'), findsOneWidget); // 1. koltuk hâlâ misafir
    await tester.tap(find.text('GİRİŞ'));
    await tester.pumpAndSettle();
    expect(find.text('E-POSTA'), findsOneWidget);
    expect(find.text('ŞİFRE'), findsOneWidget);

    // Boş gönderim istemci tarafında yakalanır (ağa hiç çıkılmaz).
    await tester.tap(find.text('GİRİŞ YAP'));
    await tester.pump();
    expect(find.text('E-posta ve şifre zorunludur.'), findsOneWidget);

    // "Şifremi unuttum" artık gerçek forgot moduna geçer (eski "kelimeki.com
    // üzerinden" yönlendirme diyaloğu şifre sıfırlama parçasıyla kalktı) —
    // akışın kendisi reset_password_test.dart'ta.
    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();
    expect(find.text('ŞİFREMİ UNUTTUM'), findsOneWidget);
  });

  testWidgets(
      'profil beklenirken 1. koltuk nötr "Yükleniyor…" (kimlik sıçraması yok)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final auth = AuthService.fake(user: fakeUser(), profileLoading: true);
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: SetupScreen(services: services(auth)),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Yükleniyor…'), findsOneWidget);
    expect(find.text('Misafir'), findsNothing); // web: geçici kimlik yok
    expect(find.text('alp.capa'), findsNothing); // e-posta önekine düşülmez
  });
}
