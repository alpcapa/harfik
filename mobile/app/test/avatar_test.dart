// KAvatar/PlayerAvatarRow'un fotoğrafsız yedek görünümü — web
// `Avatar.tsx`/`PlayerAvatarRow.tsx` paritesi. 8 Ağustos 2026'da kullanıcı
// gerçek cihazda (kelimeki.com vs alpcapa.github.io ekran görüntüsü
// karşılaştırması) iki fark buldu: (1) fotoğrafsız/misafir "?" yedeği
// web'de HER ZAMAN mavi (`bg-accent`/`text-white`) — port bunu gri/nötr
// (`_panel`/`_muted`) çiziyordu; (2) YZ koltuğu web'de gerçek 🤖 emoji
// kullanıyor — port `Icons.smart_toy_outlined` (Material ikonu, tamamen
// farklı bir şekil) çiziyordu. İkisi de CLAUDE.md'de belgeli bir bilinçli
// sapma DEĞİLDİ — port sırasında gözden kaçmış gerçek hatalardı.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/auth/k_avatar.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/game/player_avatar_row.dart';

import 'support/test_fonts.dart';

const _accent = Color(0xFF2563EB);

/// Verilen metnin en yakın `Container` atasını (kendi decoration'ını
/// okumak için) bulur — `KAvatar`'ın `_circle()`'ı metni doğrudan
/// `Container`'ın çocuğu olarak koyduğundan (ara sarmalayıcı yok) bu
/// her zaman doğru düğümü verir.
BoxDecoration decorationBehindText(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  testWidgets(
      'KAvatar isim yokken ("?") mavi (accent) yedek gösterir — web '
      'Avatar.tsx paritesi, önceki port grinin (_panel/_muted) doğrusuydu',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: KAvatar(size: 40))),
    ));
    await tester.pump();

    final deco = decorationBehindText(tester, '?');
    expect(deco.color, _accent);
    expect((deco.border as Border).top.color, _accent);
    expect(tester.widget<Text>(find.text('?')).style?.color, Colors.white);
  });

  testWidgets(
      'KAvatar fotoğrafsız gerçek isimde de ("IR") AYNI mavi yedeği kullanır '
      '— renk yalnızca "?" özel durumu değil, HER fotoğrafsız hâl için geçerli',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: KAvatar(name: 'Ironman', size: 40))),
    ));
    await tester.pump();

    final deco = decorationBehindText(tester, 'IR');
    expect(deco.color, _accent);
    expect(tester.widget<Text>(find.text('IR')).style?.color, Colors.white);
  });

  testWidgets(
      'PlayerAvatarRow: YZ koltuğu gerçek 🤖 emoji gösterir, Material '
      'ikonu (Icons.smart_toy_outlined) DEĞİL', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: PlayerAvatarRow(
            players: [AvatarRowPlayer(name: 'Yapay Zeka', isAi: true)],
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('🤖'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
  });

  testWidgets(
      'PlayerAvatarRow: misafir koltuğu KAvatar\'ın mavi "?" yedeğini '
      'kullanır — ayrı bir gri kopya ARTIK YOK (KAvatar\'a delege edildi)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: PlayerAvatarRow(
            players: [AvatarRowPlayer(name: 'Misafir', isGuest: true)],
          ),
        ),
      ),
    ));
    await tester.pump();

    final deco = decorationBehindText(tester, '?');
    expect(deco.color, _accent);
  });

  testWidgets('ekran görüntüsü: misafir "?" + isimli avatar + YZ robotu yan yana',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KAvatar(size: 40),
                  SizedBox(width: 12),
                  KAvatar(name: 'Ironman', size: 40),
                  SizedBox(width: 12),
                  PlayerAvatarRow(
                    size: 40,
                    players: [AvatarRowPlayer(name: 'Yapay Zeka', isAi: true)],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/avatar.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  // 9 Ağustos 2026 — kullanıcı avatarın "üst, alt, sağ ve sol kenarlarının
  // düz göründüğünü" İKİ KEZ bildirdi (ilk iki turda yanlışlıkla ekran
  // görüntüsü artefaktı / normal 1px çerçeve sanılıp kapatılmıştı).
  // GERÇEK `KAvatar` CanvasKit'te render edilip çerçeve halkası açı açı
  // ölçülünce kanıtlandı: halka 24 açının yalnızca 4'ünde (0/90/180/270°)
  // görünüyordu, çünkü `Container`ın kırpması DIŞ daireye göreyken çocuk
  // kenarlık kadar içeri itilmiş bir KAREYDİ ve köşegenlerde halkanın
  // üzerine taşıyordu. Web'de (CSS `border-radius` + `border`) halka her
  // yönde eşittir. `ClipOval` görüntüyü tam halkanın İÇ dairesine kırpar —
  // bu test o geometriyi sabitliyor (düzeltme sonrası 24/24 ölçüldü).
  testWidgets('fotoğraflı avatar halkanın İÇ dairesine kırpılır', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: KAvatar(url: 'https://example.com/a.png', name: 'Ironman', size: 64),
        ),
      ),
    ));
    await tester.pump();

    // Ağ görseli test ortamında yüklenmediğinden (errorBuilder devreye
    // girer) RENDER boyutu ölçülemez — bunun yerine yükleme durumundan
    // BAĞIMSIZ olan iki değişmez sabitleniyor.
    final imageFinder =
        find.descendant(of: find.byType(KAvatar), matching: find.byType(Image));
    expect(imageFinder, findsOneWidget);

    // (1) Görüntü ClipOval ile daireye kırpılıyor.
    expect(find.ancestor(of: imageFinder, matching: find.byType(ClipOval)),
        findsOneWidget,
        reason: 'görüntü ClipOval ile daireye kırpılmalı');

    // (2) O dairenin çapı halkanın İÇ kenarı: 64 − 2×1px kenarlık = 62.
    //     Eskiden `size` (64) veriliyordu; kare, halkanın üzerine taşıyordu.
    final img = tester.widget<Image>(imageFinder);
    expect(img.width, 62);
    expect(img.height, 62);
  });
}
