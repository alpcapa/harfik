// Onay/uyarı kartı sözleşmesi — `color_tokens_test.dart` (renk) ve
// `theme_test.dart` (tipografi) ile aynı sınıf: kaynak tarayan + ölçen bir
// test, çünkü web↔port sapmasını hiçbir derleyici yakalamıyor.
//
// **Neden var (15 Ağustos 2026, kullanıcı cihaz testinde bildirdi):** portun
// SEKİZ diyaloğu düz `AlertDialog` idi — Material varsayılanı (beyaz kart,
// Material tipografisi, mavi metin butonları), site diliyle hiç alakasız:
// *"çıkan popup bizim site genelinde kullandığımız tasarımlarla alakası
// yok"*. `friends_modal.dart` kartı elle çizmişti ama o da sapmıştı.
//
// Ölçülen web değerleri için bkz. `dialog_shell.dart`ın başlığı (derlenmiş
// `dist/assets/*.css` gerçek DOM'a uygulanıp Chromium'da okundu).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/dialog_shell.dart';
import 'package:kelimeki/src/ui/auth/k_avatar.dart';
import 'package:kelimeki/src/ui/game/neo_box.dart';
import 'package:kelimeki/src/ui/game/neo_button.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/tokens.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
      'kart web ile aynı: 384 genişlik, 24 dolgu, 16 yarıçap, '
      'panel zemin, #B8C2D1 çerçeve, düşen gölge', (tester) async {
    // Web'de kart `max-w-sm` — GENİŞ bir ekranda da 384'te durmalı
    // (Flutter'ın `Dialog`ı varsayılan olarak ÜST sınır taşımıyor).
    await setPhoneViewSize(tester, const Size(1000, 900));
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showKConfirm(
              context,
              title: 'Pas Geçiyorsun!',
              message: 'Pas geçmek istediğinden emin misin? '
                  'Sıran diğer oyuncuya geçer.',
              confirmLabel: 'PAS GEÇ',
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    final card = find.byType(KDialogCard);
    expect(card, findsOneWidget);
    // DİKKAT (Parça 32'nin belgelenmiş tuzağı): `KDialogCard`ın KENDİ render
    // kutusu `Dialog`ın `Align`ı, yani TÜM EKRAN — kartı iç kutudan ölç.
    final box =
        find.descendant(of: card, matching: find.byType(Container)).first;
    expect(tester.getSize(box).width, 384,
        reason: 'web `max-w-sm` = 384; Dialog\'un varsayılan üst sınırı YOK, '
            'geniş ekranda tüm alana yayılırdı (Parça 32\'nin aynı dersi)');

    final deco = tester.widget<Container>(box).decoration!
        as ShapeDecorationWithCssShadows;
    expect(deco.color, kPanel);
    expect(deco.radius, 16);
    expect(deco.borderColor, kDialogBorderColor);
    expect(deco.shadows, kFloatingCardShadows,
        reason: 'web `shadow-[0_20px_45px_rgba(15,23,42,0.5)]` — Material '
            'elevation DEĞİL (CSS gölge semantiği, bkz. neo_box.dart)');

    // Kartın İÇ dolgusu — `Dialog`ın kendi `insetPadding`i ile karıştırma.
    expect(tester.widget<Container>(box).padding, const EdgeInsets.all(24),
        reason: 'web `p-6`');
  });

  testWidgets('tipografi ve boşluklar ölçülen web değerleri', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showKConfirm(
              context,
              title: 'Başlık',
              message: 'Gövde metni',
              confirmLabel: 'TAMAM',
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    final title =
        tester.renderObject<RenderParagraph>(find.text('Başlık')).text.style!;
    expect(title.fontSize, 16, reason: 'web `text-base`');
    expect(title.fontWeight, FontWeight.bold);

    final body = tester
        .renderObject<RenderParagraph>(find.text('Gövde metni'))
        .text
        .style!;
    expect(body.fontSize, 14, reason: 'web `text-sm`');
    expect(body.height, 1.625, reason: 'web `leading-relaxed`');

    // Başlık→gövde 16 (`gap-4`), gövde→butonlar 20 (`gap-4` + `mt-1`).
    final titleBox = tester.getRect(find.text('Başlık'));
    final bodyBox = tester.getRect(find.text('Gövde metni'));
    final btnBox = tester.getRect(find.byType(NeoButton).first);
    expect(bodyBox.top - titleBox.bottom, closeTo(16, 1.5));
    expect(btnBox.top - bodyBox.bottom, closeTo(20, 1.5));

    final btn = tester.widget<NeoButton>(find.byType(NeoButton).first);
    expect(btn.fontSize, 12, reason: 'web `text-xs`');
    expect(btn.letterSpacing, 1, reason: 'web `tracking-[1px]`');
  });

  testWidgets(
      'kabul butonu SOLDA ve accent, vazgeç sağda ve neutral '
      '(Parça 25 kuralı kabuğa gömüldü)', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showKConfirm(
              context,
              title: 'T',
              message: 'M',
              confirmLabel: 'ONAYLA',
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    final ok = find.widgetWithText(NeoButton, 'ONAYLA');
    final cancel = find.widgetWithText(NeoButton, 'VAZGEÇ');
    expect(tester.getTopLeft(ok).dx, lessThan(tester.getTopLeft(cancel).dx));
    expect(tester.widget<NeoButton>(ok).variant, NeoButtonVariant.accent);
    expect(tester.widget<NeoButton>(cancel).variant, NeoButtonVariant.neutral);
    // Web'de satır `align-items: stretch` — kenarlıklı neutral kardeşi
    // yüzünden İKİSİ de aynı yükseklikte çiziliyor.
    expect(tester.getSize(ok).height, tester.getSize(cancel).height);
  });

  testWidgets('tek butonlu bilgi kartında buton TAM GENİŞLİK (web: satır yok)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showKInfo(context, message: 'Bilgi'),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    // 384 kart − 2×24 dolgu − 2×1 çerçeve = 334.
    expect(tester.getSize(find.byType(NeoButton)).width, closeTo(334, 1));
  });

  testWidgets('ekran görüntüsü — yeni mesaj popup\'ı (avatarlı başlık)',
      (tester) async {
    final shotKey = GlobalKey();
    await setPhoneViewSize(tester, const Size(420, 700));
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: RepaintBoundary(
            key: shotKey,
            child: KDialogCard(
              title: Row(children: [
                const KAvatar(url: null, name: 'T2', size: 28),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('T2',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kText))),
              ]),
              content: const Text('Deneme', style: kDialogBodyStyle),
              actions: [
                kDialogButton(
                    label: 'CEVAP VER',
                    variant: NeoButtonVariant.accent,
                    onPressed: () {}),
                kDialogButton(label: 'KAPAT', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Projenin deseni: golden KARŞILAŞTIRMASI değil (font render'ı ortamlar
    // arası oynayabildiğinden kırılgan olurdu) — PNG'yi yazıp gözle incele.
    // `toImage` SAHTE zamanda çözülmez, `runAsync` şart (Parça 5c dersi).
    await tester.runAsync(() async {
      final boundary =
          shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/dialog_message_popup.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  test('lib/ altında ham AlertDialog KALMADI', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.readAsStringSync().contains('AlertDialog(')) offenders.add(f.path);
    }
    expect(offenders, isEmpty,
        reason: 'Onay/uyarı penceresi Material varsayılanıyla değil '
            '`dialog_shell.dart` (KDialogCard/showKConfirm/showKInfo) ile '
            'çizilmeli — web\'in kartıyla birebir. Bu tarama olmadan yeni '
            'bir AlertDialog sessizce girer ve site dilinden sapar: '
            '${offenders.join(', ')}');
  });
}
