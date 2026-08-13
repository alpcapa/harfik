// Auth fazı parça 2 — kayıt formu: takma isim debounce durumları (sahte
// denetleyiciyle), doğrulama sırası, koşullar linkleri (Terms/Privacy
// portları), tarih alanı ve profile_fields yardımcıları. Gerçek signUp
// (trigger + e-posta doğrulaması dalları) cihazda doğrulanacak.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/data/profile_fields.dart';
import 'package:kelimeki/src/ui/auth/auth_modal.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  group('profile_fields (web portu birebir)', () {
    test('formatTrDateInput ayırıcıları otomatik ekler', () {
      expect(formatTrDateInput('0'), '0');
      expect(formatTrDateInput('010'), '01/0');
      expect(formatTrDateInput('01011990'), '01/01/1990');
      expect(formatTrDateInput('1.2.x1990'), '12/19/90'); // yalnızca rakamlar
      expect(formatTrDateInput('010119901234'), '01/01/1990'); // 8 hane sınırı
    });

    test('trDateToIso: geçerli/boş/bozuk', () {
      expect(trDateToIso('01/01/1990'), '1990-01-01');
      expect(trDateToIso('9/2/2001'), '2001-02-09');
      expect(trDateToIso(''), isNull);
      expect(() => trDateToIso('abc'), throwsA(isA<FormatException>()));
      expect(
          () => trDateToIso('01/13/1990'),
          throwsA(predicate((e) =>
              e is FormatException && e.message == 'Doğum ayı geçersiz.')));
      expect(
          () => trDateToIso('31/02/1990'),
          throwsA(predicate((e) =>
              e is FormatException && e.message == 'Geçersiz doğum tarihi.')));
      expect(
          () => trDateToIso('01/01/1800'),
          throwsA(predicate((e) =>
              e is FormatException && e.message == 'Doğum yılı geçersiz.')));
    });

    test('isoToTrDate gidiş-dönüş', () {
      expect(isoToTrDate('1990-01-01'), '01/01/1990');
      expect(isoToTrDate(null), '');
    });
  });

  test('friendlyNicknameError: unique violation → Türkçe mesaj', () {
    expect(
        friendlyNicknameError('duplicate key value violates unique constraint '
                '"profiles_display_name_tr_lower_key"')!
            .message,
        contains('takma isim zaten kullanılıyor'));
    expect(friendlyNicknameError('some other error'), isNull);
  });

  Future<void> pumpSignup(
    WidgetTester tester, {
    required Future<bool> Function(String) checker,
  }) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: AuthModal(auth: AuthService.fake(), nicknameChecker: checker),
      ),
    ));
    await tester.pump();
    // login → signup moduna geç.
    await tester.tap(find.textContaining('Kayıt ol', findRichText: true));
    await tester.pump();
    expect(find.text('KAYIT'), findsOneWidget); // KModal başlığı
  }

  Finder fieldByLabel(String label) => find.descendant(
        of: find.ancestor(
            of: find.textContaining(label, findRichText: true),
            matching: find.byType(Column)),
        matching: find.byType(TextField),
      );

  testWidgets('takma isim: boşluk silinir, debounce → müsait/dolu',
      (tester) async {
    final asked = <String>[];
    await pumpSignup(tester, checker: (n) async {
      asked.add(n);
      return n != 'ironman';
    });

    final nick = fieldByLabel('TAKMA İSİM').first;
    await tester.enterText(nick, 'deniz can');
    await tester.pump();
    // Boşluk anında silinir (web display_name_no_whitespace).
    expect(tester.widget<TextField>(nick).controller!.text, 'denizcan');
    expect(find.text('Kontrol ediliyor…'), findsOneWidget);

    // 400ms debounce dolmadan RPC ÇAĞRILMAZ.
    await tester.pump(const Duration(milliseconds: 200));
    expect(asked, isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(asked, ['denizcan']);
    // Web '✓ Kullanılabilir' — ✓ bundled fontlarda yok, ikon+metin (bkz.
    // ★/► kararları).
    expect(find.text('Kullanılabilir'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Dolu isim → kırmızı durum + KAYIT OL devre dışı.
    await tester.enterText(nick, 'ironman');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('Bu takma isim kullanımda.'), findsOneWidget);

    await tester.tap(find.text('KAYIT OL'), warnIfMissed: false);
    await tester.pump();
    // Buton disabled — hiçbir doğrulama hatası üretilmedi (submit çalışmadı).
    expect(find.text('Bu takma isim zaten kullanılıyor.'), findsNothing);
  });

  testWidgets('doğrulama sırası web ile aynı (Ad → ... → koşullar)',
      (tester) async {
    await pumpSignup(tester, checker: (_) async => true);

    Future<void> submitExpect(String msg) async {
      await tester.ensureVisible(find.text('KAYIT OL'));
      await tester.tap(find.text('KAYIT OL'));
      await tester.pump();
      expect(find.text(msg), findsOneWidget, reason: 'beklenen hata: $msg');
    }

    await submitExpect('Ad zorunludur.');
    await tester.enterText(fieldByLabel('AD').first, 'Alp');
    await submitExpect('Soyad zorunludur.');
    await tester.enterText(fieldByLabel('SOYAD').first, 'Çapa');
    await submitExpect('Takma isim zorunludur.');

    await tester.enterText(fieldByLabel('TAKMA İSİM').first, 'alp42');
    // Debounce beklerken submit → "kontrol ediliyor" hatası değil, buton
    // zaten devre dışı; debounce'u bitir.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await submitExpect('E-posta zorunludur.');
    await tester.enterText(fieldByLabel('E-POSTA').first, 'a@b.co');
    await submitExpect('Şifre zorunludur.');
    await tester.enterText(fieldByLabel('ŞİFRE').first, 'sifre123');
    await submitExpect(
        "Kullanım Koşulları ve Gizlilik Politikası'nı kabul etmelisiniz.");

    // Koşulları kabul et + bozuk tarih → trDateToIso Türkçe hatası.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.enterText(fieldByLabel('DOĞUM TARİHİ').first, '31/02/1990');
    await submitExpect('Geçersiz doğum tarihi.');

    // Tarih düzeltilince kalan tek engel ağ (fake'te istemci yok) — akışın
    // signUp'a KADAR geldiğinin kanıtı.
    await tester.enterText(fieldByLabel('DOĞUM TARİHİ').first, '01/01/1990');
    await submitExpect('Supabase yapılandırılmadı.');
  });

  testWidgets('koşullar linkleri Terms/Privacy portlarını açar (metin birebir)',
      (tester) async {
    await pumpSignup(tester, checker: (_) async => true);

    // Linkler TextSpan (recognizer'lı) — düz find.text bulamaz; tapOnText
    // metin aralığına dokunur.
    await tester.ensureVisible(
        find.textContaining('okudum ve kabul ediyorum', findRichText: true));
    await tester.tapOnText(find.textRange.ofSubstring('Kullanım Koşulları'));
    await tester.pumpAndSettle();
    expect(find.text('KULLANIM KOŞULLARI'), findsOneWidget);
    expect(find.textContaining('Sarıyer, İstanbul'), findsOneWidget);
    expect(find.textContaining('Otomatik araçlar veya botlar'), findsOneWidget);
    // Link checkbox'ı TOGGLE ETMEZ (web parity).
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, false);
    await tester.tap(find.byTooltip('Kapat').last); // üstteki modalın ✕'i
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring('Gizlilik Politikası'));
    await tester.pumpAndSettle();
    expect(find.text('GİZLİLİK POLİTİKASI'), findsOneWidget);
    expect(find.textContaining('KVKK m.11 uyarınca'), findsOneWidget);
    expect(find.textContaining('30 gün içinde kalıcı olarak silinir'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Kapat').last);
    await tester.pumpAndSettle();
  });

  testWidgets('doğum tarihi alanı ayırıcıları otomatik ekler + ekran görüntüsü',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 1000));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: AuthModal(
              auth: AuthService.fake(), nicknameChecker: (_) async => true),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.textContaining('Kayıt ol', findRichText: true));
    await tester.pump();

    final f = fieldByLabel('DOĞUM TARİHİ').first;
    await tester.enterText(f, '01011990');
    await tester.pump();
    expect(tester.widget<TextField>(f).controller!.text, '01/01/1990');

    await tester.enterText(fieldByLabel('TAKMA İSİM').first, 'Ironman');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('Kullanılabilir'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/signup_form.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
