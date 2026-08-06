// GameHeader + LogoMark testleri — logo path verisi çözülür (üretici farklı
// bir SVG komutu üretirse burada patlar), başlık etiketleri web kuralıyla
// (insan: trUpper(ad), YZ: "YZ N", teslim: TESLİM) doğrulanır; ekran
// görüntüsü build/screenshots/game_header.png'ye yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/game_header.dart';
import 'package:kelimeki/src/ui/game/logo_mark.dart';
import 'package:kelimeki/src/ui/game/logo_mark_data.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

Player player(String name,
        {required bool isAI,
        required int index,
        bool surrendered = false,
        int score = 0}) =>
    Player(
      name: name,
      corners: cornersFor(4)[index],
      colorIndex: index,
      isAI: isAI,
      surrendered: surrendered,
      rack: const [],
      score: score,
      bestMoveScore: 0,
      bestWordScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    );

GameState headerState() => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: const [],
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        player('İbrahim', isAI: false, index: 0, score: 123),
        player('Yapay Zeka 2', isAI: true, index: 1, score: 88),
        player('Deniz', isAI: false, index: 2, surrendered: true),
        player('Yapay Zeka 4', isAI: true, index: 3, score: 105),
      ],
      current: 1,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 5,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoIfAvailable);

  test('logo path verisi eksiksiz çözülür (M/L/Q/C/Z dışına çıkmaz)', () {
    final text = parseSvgPath(logoTextPath);
    final underline = parseSvgPath(logoUnderlinePath);
    expect(text.getBounds().isEmpty, isFalse);
    expect(underline.getBounds().isEmpty, isFalse);
    // viewBox ile tutarlılık: yazı kutusu viewBox'ın içinde kalmalı.
    final vb = logoViewBox.split(' ').map(double.parse).toList();
    final b = text.getBounds();
    expect(b.left, greaterThanOrEqualTo(vb[0]));
    expect(b.top, greaterThanOrEqualTo(vb[1]));
    expect(b.right, lessThanOrEqualTo(vb[0] + vb[2]));
    expect(b.bottom, lessThanOrEqualTo(vb[1] + vb[3]));
  });

  test('parseSvgPath bilinmeyen girdide fırlatır', () {
    expect(() => parseSvgPath('10 20 L5 5'), throwsFormatException);
  });

  testWidgets(
      '4 kutu + GİRİŞ 375-465 aralığında kaydırmasız sığar (web garantisi)',
      (tester) async {
    // Web'in akıcı clamp sistemi tam bunun için ayarlandı ("4 oyunculu +
    // Giriş neredeyse hiçbir zaman kaydırmaya ihtiyaç duymaz",
    // GameHeader.tsx) — aynı garanti app'te ölçülerek doğrulanır. "Neredeyse"
    // web'de de gerçek: 4 İNSAN koltuğu + misafir GİRİŞ butonu (avatardan
    // geniş) aralığın üst ucunda (~430px+) webde de birkaç px görünmez
    // kaydırmaya düşer (insan kutusu eğimi 4×25.56vw > 100vw — aynı
    // formüller aynı sonucu verir); telefon genişliklerinde (375-390) ve
    // yerel oyunun gerçek kadrolarında (YZ'li karışım) her yerde sığar.
    Future<double> overflowAt(double width, GameState s) async {
      await setPhoneViewSize(tester, Size(width, 200));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            fontFamily: 'SpaceGrotesk',
            scaffoldBackgroundColor: Colors.white),
        home: Scaffold(
          body: GameHeader(state: s, onLogoTap: () {}),
        ),
      ));
      await tester.pump();
      return tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent;
    }

    final state = headerState();
    final allHuman = state.copyWith(players: [
      for (final p in state.players) p.copyWith(isAI: false),
    ]);
    // 4 insan + GİRİŞ: yaygın telefon genişliklerinde kaydırmasız.
    for (final width in [375.0, 390.0]) {
      expect(await overflowAt(width, allHuman), 0,
          reason: '$width px: 4 insan koltuğu + GİRİŞ sığmalı');
    }
    // 2 insan + 2 YZ (headerState) tüm aralıkta kaydırmasız.
    for (final width in [375.0, 390.0, 420.0, 465.0]) {
      expect(await overflowAt(width, state), 0,
          reason: '$width px: karışık kadro sığmalı');
    }

    // Sağa yaslılık (web justify-between paritesi): son kutu GİRİŞ'e
    // bitişik (8px), artan boşluk logo ile İLK kutunun arasında kalır.
    await overflowAt(465, state);
    final lastBoxRight =
        tester.getTopRight(find.byKey(const ValueKey('player-box-3'))).dx;
    final girisLeft = tester
        .getTopLeft(find.ancestor(
            of: find.text('GİRİŞ'), matching: find.byType(Container)))
        .dx;
    expect(girisLeft - lastBoxRight, moreOrLessEquals(8, epsilon: 0.5));
    final girisRight = tester
        .getTopRight(find.ancestor(
            of: find.text('GİRİŞ'), matching: find.byType(Container)))
        .dx;
    expect(girisRight, moreOrLessEquals(465 - 12, epsilon: 0.5)); // sağ dolgu
  });

  testWidgets(
      'başlık etiketleri: trUpper(ad) / YZ N / TESLİM; logo tıklanabilir',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 200));
    var logoTapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: RepaintBoundary(
          key: const Key('header-boundary'),
          child: ColoredBox(
            color: Colors.white,
            child: GameHeader(
              state: headerState(),
              onLogoTap: () => logoTapped = true,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Türkçe büyük harf: İbrahim → İBRAHİM (I değil İ — trUpper).
    expect(find.text('İBRAHİM'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
    expect(find.text('YZ 2'), findsOneWidget);
    expect(find.text('YZ 4'), findsOneWidget);
    // Teslim olan koltuk skor yerine TESLİM gösterir, adı da görünür.
    expect(find.text('DENİZ'), findsOneWidget);
    expect(find.text('TESLİM'), findsOneWidget);
    // Kullanıcı kararı (web'le birlikte netleştirildi): teslim kutusu
    // diğerleriyle AYNI boy/tasarımda, üstüne %45 soluklaştırma — yalnızca
    // teslim kutusu soluk, boyu normal insan kutusuyla birebir aynı.
    final dims = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
    expect(dims, hasLength(1));
    expect(dims.single.opacity, 0.45);
    final normalBox =
        tester.getSize(find.byKey(const ValueKey('player-box-0')));
    final surrenderedBox =
        tester.getSize(find.byKey(const ValueKey('player-box-2')));
    expect(surrenderedBox.height, normalBox.height);
    expect(surrenderedBox.width, normalBox.width);

    await tester.tap(find.byType(LogoMark));
    expect(logoTapped, isTrue);

    // Web UserMenu'nün misafir durumu: GİRİŞ düğmesi görünür, dokununca
    // "yakında" açıklaması çıkar.
    expect(find.text('GİRİŞ'), findsOneWidget);
    await tester.tap(find.text('GİRİŞ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sonraki sürümünde gelecek'), findsOneWidget);
    await tester.tap(find.text('TAMAM'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = tester.renderObject(find.byKey(
          const Key('header-boundary'))) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_header.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
