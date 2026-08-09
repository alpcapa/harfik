// GameScreen etkileşim testleri — dokunarak taş yerleştirme, canlı
// geçerlilik çerçevesi, joker akışı, geri alma ve OYNA. Kontrollü raf için
// state ResumeSavedAction ile kurulur (golden üreticisindeki aynı desen);
// sözlük gerçek asset dosyasından yüklenir.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart'
    show BoardWidget, DashedBorderPainter, debugBoardBuildCountForTests;
import 'package:kelimeki/src/ui/game/game_over_modal.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/game/rack_widget.dart';
import 'package:kelimeki/src/ui/game/tile_widget.dart';
import 'package:kelimeki/src/ui/game/wild_letter_sheet.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

late SetWordSource words;

Tile t(String letter) => Tile(letter: letter, pts: letterPoints(letter));

Player player(String name,
        {required bool isAI, required int index, required List<Tile> rack}) =>
    Player(
      name: name,
      corners: cornersFor(2)[index],
      colorIndex: index,
      isAI: isAI,
      surrendered: false,
      rack: rack,
      score: 0,
      bestMoveScore: 0,
      bestWordScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    );

GameState craftedState() => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: [t('A'), t('T'), t('R'), t('N'), t('E'), t('K')],
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        player('Ironman', isAI: false, index: 0, rack: [
          t('K'),
          t('E'),
          t('L'),
          t('İ'),
          t('M'),
          t('E'),
          const Tile(letter: '?', pts: 0)
        ]),
        player('Yapay Zeka',
            isAI: true,
            index: 1,
            rack: [t('A'), t('A'), t('A'), t('A'), t('A'), t('A'), t('A')]),
      ],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 2, // her iki taraf da "ilk hamle" durumunda değilmiş gibi
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

// Hücre/raf taşları artık ValueKey taşıyor — sürükleme parçasıyla raf
// taşları ve yerleştirilmiş hücreler GestureDetector'dan Listener'a geçti,
// tip tabanlı indeksleme iki widget türü arasında kayardı.
Finder rackTile(int i) => find.byKey(ValueKey('rack-$i'));

Finder boardCell(int r, int c) => find.byKey(ValueKey('cell-$r-$c'));

Future<GameController> pumpGame(WidgetTester tester, GlobalKey key) async {
  final controller =
      GameController(words: words, autoPlayAi: false, nowIso: () => '');
  controller.dispatch(ResumeSavedAction(craftedState()));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
        fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
    home: RepaintBoundary(
      key: key,
      child: GameScreen(
          controller: controller, words: words, auth: AuthService.fake()),
    ),
  ));
  await tester.pump();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadRobotoIfAvailable();
    final f = File('assets/dictionary/words_tr.txt');
    words = SetWordSource(const LineSplitter()
        .convert(f.readAsStringSync())
        .where((w) => w.isNotEmpty));
    expect(words.contains('kelime'), isTrue); // test kelimesi sözlükte olmalı
  });

  testWidgets('dokunarak KELİME dizilir: yeşil çerçeve + doğru puan + OYNA',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    final controller = await pumpGame(tester, key);

    // Raf K,E,L,İ,M,E,? — hep 0. taşı seçip sırayla (0,0)..(0,5)'e koymak
    // KELİME'yi dizer (yerleşen taş raftan düştüğünden 0. indeks kayar).
    for (var c = 0; c < 6; c++) {
      await tester.tap(rackTile(0));
      await tester.pump();
      await tester.tap(boardCell(0, c));
      await tester.pump();
    }
    expect(controller.state.placed.length, 6);
    // KELİME = 1+1+1+1+2+1 = 7; 0. satır bonus bölgesi dışında → çarpan yok.
    expect(find.text('+7'), findsOneWidget);
    expect(find.text('Oyna tuşuyla kelimeyi onayla.'), findsOneWidget);

    // Bayat mesaj türetilmiş metni EZEMEZ (web'de kullanıcı buldu): taş
    // seçmeden boş hücreye dokunmak reducer'a "Önce bir harf seç." yazar ama
    // taslak geçerliyken satır yine "Oyna tuşuyla kelimeyi onayla." demeli.
    await tester.tap(boardCell(5, 5));
    await tester.pump();
    expect(controller.state.message, 'Önce bir harf seç.');
    expect(find.text('Oyna tuşuyla kelimeyi onayla.'), findsOneWidget);
    expect(find.text('Önce bir harf seç.'), findsNothing);
    // Ekran görüntüsü: yeşil çerçeveli taslak hamle + raf + butonlar.
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_screen_kelime.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    await tester.tap(find.text('OYNA'));
    await tester.pumpAndSettle();
    expect(controller.state.players[0].score, 7);
    expect(controller.state.players[0].longestWord, 'KELİME');
    expect(controller.state.placed, isEmpty);
    expect(controller.state.current, 1); // sıra YZ'de (autoPlayAi kapalı)
  });

  testWidgets('geçersiz dizilim: kırmızı sebep mesajı + geri alma',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(rackTile(0)); // K
    await tester.pump();
    await tester.tap(boardCell(0, 0));
    await tester.pump();
    await tester.tap(rackTile(3)); // M (K düşünce raf E,L,İ,M,...)
    await tester.pump();
    await tester.tap(boardCell(0, 1));
    await tester.pump();

    expect(words.contains('km'), isFalse);
    expect(find.text('"KM" geçerli bir kelime değil.'), findsOneWidget);

    // Joker olmayan yerleştirilmiş taşa dokunmak geri alır (web davranışı).
    await tester.tap(boardCell(0, 1));
    await tester.pump();
    expect(controller.state.placed.length, 1);
    expect(controller.state.players[0].rack.length, 6);

    await tester.tap(find.text('GERİ AL'));
    await tester.pump();
    expect(controller.state.placed, isEmpty);
    expect(controller.state.players[0].rack.length, 7);
  });

  testWidgets('joker akışı: harf seçici → yerleştir → düzenle → geri al',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(rackTile(6)); // '?' (rafta ★)
    await tester.pump();
    await tester.tap(boardCell(1, 0));
    await tester.pumpAndSettle();
    expect(find.text('Joker Hangi Harf Olsun?'), findsOneWidget);
    // Kontur katmanı her taş harfini iki Text yapar (stroke+dolgu, aynı taş)
    // — .first ikisinden birine dokunmak için yeterli.
    await tester.tap(find.text('B').first);
    await tester.pumpAndSettle();
    final placed = controller.state.placed['1,0'];
    expect(placed, isNotNull);
    expect(placed!.wild, isTrue);
    expect(placed.wildLetter, 'B');

    // Yerleştirilmiş jokere dokunmak taşı GERİ ALMAZ — seçici yeniden açılır.
    await tester.tap(boardCell(1, 0));
    await tester.pumpAndSettle();
    expect(find.text('Jokeri Hangi Harfe Çevir?'), findsOneWidget);
    await tester.tap(find.text('Ç').first);
    await tester.pumpAndSettle();
    expect(controller.state.placed['1,0']!.wildLetter, 'Ç');

    // Düzenleme modundaki "Geri Al" butonu taşı rafa döndürür.
    await tester.tap(boardCell(1, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wild-recall')));
    await tester.pumpAndSettle();
    expect(controller.state.placed, isEmpty);
    expect(
        controller.state.players[0].rack.any((t) => t.letter == '?'), isTrue);
  });

  testWidgets(
      'joker seçici dar (yatay mod benzeri) yükseklikte taşmıyor '
      '(showModalBottomSheet varsayılanı sheet\'i ekranın %56\'sına '
      'sabitliyordu, kullanıcı iPad yatay modda ekran görüntüsüyle buldu)',
      (tester) async {
    // Oyun ekranının KENDİ sorumluluğundaki (Parça 15-17) kaydırma/genişlik
    // davranışından bilerek izole — yalnızca showWildLetterSheet'in kendi
    // yükseklik/kaydırma sözleşmesini sınıyor. Geniş/kısa yüzey (iPad yatay
    // moddaki dar kullanılabilir yükseklikle aynı sınıf): 26 harflik 6
    // sütunlu ızgara + başlık, eski %56 sınırını dar bir yükseklikte aşar.
    await setPhoneViewSize(tester, const Size(800, 420));
    WildLetterChoice? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showWildLetterSheet(context);
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Joker Hangi Harf Olsun?'), findsOneWidget);

    // `isScrollControlled:true` + `SingleChildScrollView` olmadan bu, dar
    // yükseklikte klasik "RenderFlex overflowed" hatasını (sheet'in kendi
    // ConstrainedBox'ı içindeki Column'un taşması) fırlatırdı — kesilen
    // içerik görsel olarak sessiz kırpma gibi görünse de kök sebep budur.
    expect(tester.takeException(), isNull);
    // Sheet artık kendi kaydırma alanına sahip; ızgaranın son harfi (Z)
    // ağaçta gerçekten bulunabilir VE kaydırma katmanının içinde.
    expect(find.byType(SingleChildScrollView), findsWidgets);
    // Kontur katmanı her taş harfini iki Text yapar (stroke+dolgu) — .first
    // ikisinden birinin var olduğunu doğrulamak için yeterli (bkz. joker
    // akışı testindeki aynı desen).
    expect(find.text('Z').first, findsOneWidget);

    // Sheet'i normal kullanıcı akışıyla (bir harf seçerek) kapat.
    await tester.tap(find.text('A').first);
    await tester.pumpAndSettle();
    expect(result?.letter, 'A');
  });

  testWidgets('taş değiştirme akışı: DEĞİŞTİR → seç (N) → onayla → sıra YZ\'de',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    final controller = await pumpGame(tester, key);

    await tester.tap(find.text('DEĞİŞTİR'));
    await tester.pump();
    expect(controller.state.swapMode, isTrue);
    // Swap modunda OYNA gizli, satır DEĞİŞTİR/VAZGEÇ'e döner (web düzeni).
    expect(find.text('OYNA'), findsNothing);
    expect(find.text('VAZGEÇ'), findsOneWidget);
    // Raf başlığı swap modunda da yalnızca oyuncunun adı — aksiyon metni
    // mesaj satırında (kullanıcı kararı, bkz. rack_widget.dart).
    expect(find.textContaining('değiştirilecek taşları seç'), findsNothing);
    expect(find.text('Ironman'), findsOneWidget);

    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(rackTile(2));
    await tester.pump();
    expect(controller.state.swapSelection, [0, 2]);
    expect(find.text('DEĞİŞTİR (2)'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_screen_swap.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    final bagBefore = controller.state.bag.length;
    await tester.tap(find.text('DEĞİŞTİR (2)'));
    await tester.pump();
    expect(controller.state.swapMode, isFalse);
    expect(controller.state.players[0].rack.length, 7);
    expect(controller.state.bag.length, bagBefore); // 2 çek + 2 iade
    expect(controller.state.current, 1); // değişim sırayı devreder
    expect(controller.state.consecutivePasses, 1); // puansız tur sayacı
  });

  testWidgets('VAZGEÇ swap modundan işlemsiz çıkar', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(find.text('DEĞİŞTİR'));
    await tester.pump();
    await tester.tap(rackTile(1));
    await tester.pump();
    await tester.tap(find.text('VAZGEÇ'));
    await tester.pump();
    expect(controller.state.swapMode, isFalse);
    expect(controller.state.swapSelection, isEmpty);
    expect(controller.state.current, 0); // sıra devretmedi
  });

  testWidgets(
      'Pas Geç onayı: web metni birebir + kabul butonu VAZGEÇ\'in solunda',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(find.text('PAS GEÇ'));
    await tester.pumpAndSettle();

    // Web (src/App.tsx showPassConfirm) ile birebir aynı başlık/gövde —
    // online_game_screen.dart'ın ZATEN doğru olan sürümüyle de aynı.
    expect(find.text('Pas Geçiyorsun!'), findsOneWidget);
    expect(
      find.text(
          'Pas geçmek istediğinden emin misin? Sıran diğer oyuncuya geçer.'),
      findsOneWidget,
    );

    // Buton sırası web'le aynı: kabul (PAS GEÇ) solda, VAZGEÇ sağda —
    // AlertDialog.actions liste sırasıyla soldan sağa dizilir.
    final acceptBtn = find.widgetWithText(FilledButton, 'PAS GEÇ');
    final cancelBtn = find.widgetWithText(TextButton, 'VAZGEÇ');
    expect(acceptBtn, findsOneWidget);
    expect(cancelBtn, findsOneWidget);
    expect(
      tester.getTopLeft(acceptBtn).dx,
      lessThan(tester.getTopLeft(cancelBtn).dx),
      reason: 'PAS GEÇ (kabul) VAZGEÇ\'in solunda olmalı — web düzeni',
    );

    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();
    expect(controller.state.current, 0); // pas geçilmedi
  });

  testWidgets('TORBA butonu Kalan Taşlar dökümünü açar', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());

    await tester.tap(find.text('TORBA 6'));
    await tester.pumpAndSettle();
    expect(find.text('Kalan Taşlar'), findsOneWidget);
    // Dağılım 100 − tahta 0 − benim rafım 7 = 93 taş dışarıda.
    expect(find.textContaining('93'), findsOneWidget);
  });

  testWidgets(
      'TORBA sayacı ayrı stilli — web App.tsx: <span text-[13px] '
      'text-accent>{count}</span>', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());

    final torbaText = tester.widget<Text>(find.text('TORBA 6'));
    final richLabel = torbaText.textSpan as TextSpan;
    final countSpan = richLabel.children!
        .whereType<TextSpan>()
        .firstWhere((s) => s.text == '6');
    expect(countSpan.style!.fontSize, 13);
    expect(countSpan.style!.color, const Color(0xFF2563EB));
    // Taban span ("TORBA ") sayaçtan FARKLI — yalnızca punto/renk ezilmiş,
    // geri kalanı (bold/tracking) NeoButton'ın temel stilinden miras.
    final baseSpan = richLabel.children!
        .whereType<TextSpan>()
        .firstWhere((s) => s.text == 'TORBA ');
    expect(baseSpan.style, isNull,
        reason: 'taban span kendi stilini taşımamalı — TextSpan(style: '
            'baseStyle) üstündeki miras yeterli');
  });

  testWidgets('oyun bitince GameOver modalı: kazanan + Teslim + YENİ OYUN',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final golden = jsonDecode(
      File('../kelimeki_core/test/goldens/reducer_ai4.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final steps = golden['steps'] as List;
    final finished = gameStateFromJson(
        ((steps.last as Map)['state'] as Map).cast<String, Object?>());
    expect(finished.isGameOver, isTrue);

    final controller =
        GameController(words: words, autoPlayAi: false, nowIso: () => '');
    controller.restore(finished);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: GameScreen(
          controller: controller, words: words, auth: AuthService.fake()),
    ));
    await tester.pumpAndSettle();

    // Fixture: Yapay Zeka 2 kazanır (162), Yapay Zeka 3 teslim olmuştur.
    expect(find.text('YAPAY ZEKA 2 KAZANDI'), findsOneWidget);
    expect(find.text('(TESLİM)'), findsOneWidget);
    expect(find.text('Toplam hamle'), findsOneWidget);

    // Web `<Modal title="" onClose={onClose}>` — bottom "KAPAT" düğmesi
    // yok, tek kapatma yolu KModal'ın sağ üstteki ✕'i (bkz. mobile/CLAUDE.md
    // Parça 26).
    expect(find.text('KAPAT'), findsNothing);
    expect(find.byTooltip('Kapat'), findsOneWidget);
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('YAPAY ZEKA 2 KAZANDI'), findsNothing);
    // Modal kapanınca tahta görünür kalır, raf satırında YENİ OYUN çıkar.
    expect(find.textContaining('YENİ'), findsOneWidget);
  });

  testWidgets('GameOver modalı KModal kabuğunu kullanır — 360px sınırı, ham '
      'Dialog DEĞİL', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final golden = jsonDecode(
      File('../kelimeki_core/test/goldens/reducer_ai4.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final steps = golden['steps'] as List;
    final finished = gameStateFromJson(
        ((steps.last as Map)['state'] as Map).cast<String, Object?>());

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
      home: Scaffold(
        body: Center(child: GameOverModal(state: finished)),
      ),
    ));
    await tester.pumpAndSettle();

    // KModal'ın kendi Dialog'u tek Dialog olmalı — GameOverModal artık ham
    // bir ikinci Dialog kurmuyor.
    expect(find.byType(Dialog), findsOneWidget);
    final constrained = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .where((c) => c.constraints.maxWidth == 360);
    expect(constrained, isNotEmpty,
        reason: 'KModal'
            "'ın 360px maxWidth kısıtı uygulanmalı");
  });

  testWidgets('sürükle-bırak: raftan tahtaya + tahtada taşıma + rafa geri alma',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final key = GlobalKey();
    final controller = await pumpGame(tester, key);

    // 1) Raftan (0,0)'a sürükle. DRAG_LIFT telafisi: hayalet/bırakma hedefi
    // parmağın 30px ÜZERİNDE hesaplanır — hedef hücre merkezinin +30
    // altına bırakılır (web Playwright testindeki aynı ders,
    // mobile/CLAUDE.md "Test notu").
    final start = tester.getCenter(rackTile(0)); // K
    final target = tester.getCenter(boardCell(0, 0)) + const Offset(0, 30);
    // GameHeader'ın kendi (yatay) skor kutusu şeridi de bir
    // SingleChildScrollView taşıyor — dikey (ana gövde) olanı `scrollDirection`
    // ile ayırt ediyoruz.
    ScrollPhysics? scrollPhysics() => tester
        .widget<SingleChildScrollView>(find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.vertical))
        .physics;
    expect(scrollPhysics(), isNull); // sürükleme yokken varsayılan
    final g = await tester.startGesture(start);
    await g.moveTo(start + const Offset(0, -40)); // eşik aşılır
    await tester.pump();
    // Kullanıcının web derlemesinde bulduğu hata: aktif sürükleme sırasında
    // sayfa da kayıyordu — Listener jest arenasına katılmadığından
    // Scrollable'ın kendi dikey sürükleme algılayıcısı aynı hareketi
    // "kaydırma" sanıp kazanıyordu. Artık aktif sürüklemede physics kilitli.
    expect(scrollPhysics(), isA<NeverScrollableScrollPhysics>());
    await g.moveTo(target);
    await tester.pump();
    // Sürükleme sırasında: kaynak raf taşı gizli (opacity 0), taş henüz
    // yerleşmedi.
    expect(controller.state.placed, isEmpty);
    final hidden = tester
        .widgetList<Opacity>(find.descendant(
            of: find.byType(RackWidget), matching: find.byType(Opacity)))
        .where((o) => o.opacity == 0);
    expect(hidden, hasLength(1));
    // Hover çerçevesinin GERÇEK geometrisi — ekran görüntüsünde hayalet taş
    // (46px, cell'den büyük) hedef hücrenin tam üstüne düştüğünden kesikli
    // çerçeveyi görsel olarak tamamen örtüyor (BİLEREK — web'in de tasarımı,
    // DRAG_LIFT telafisi ikisini aynı noktaya oturtuyor); bu yüzden konumu
    // gözle DEĞİL, `_hoverHighlight`'ın çizdiği `DashedBorderPainter`
    // CustomPaint'inin gerçek render rect'ini `boardCell(0, 0)`'ın rect'iyle
    // karşılaştırarak doğruluyoruz (8 Ağustos 2026 performans düzeltmesi —
    // hover artık ayrı bir overlay, elle hesaplanan bir geometri).
    final hoverFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DashedBorderPainter);
    expect(hoverFinder, findsOneWidget);
    final hoverRect = tester.getRect(hoverFinder);
    final targetCellRect = tester.getRect(boardCell(0, 0));
    expect((hoverRect.center - targetCellRect.center).distance, lessThan(1),
        reason: 'Hover çerçevesi (0,0) hücresinin merkezinde değil — '
            'geometri hatası: hover=$hoverRect hücre=$targetCellRect');
    expect((hoverRect.width - targetCellRect.width).abs(), lessThan(1));
    expect((hoverRect.height - targetCellRect.height).abs(), lessThan(1));
    // Ekran görüntüsü: hayalet taş + kesikli hedef çerçevesi.
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_drag.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await g.up();
    await tester.pump();
    expect(controller.state.placed['0,0']?.letter, 'K');
    expect(controller.state.players[0].rack.length, 6);
    expect(scrollPhysics(), isNull); // sürükleme bitince kilit kalkar

    // 2) Tahtada taşı: (0,0) → (2,2).
    final from = tester.getCenter(boardCell(0, 0));
    final to = tester.getCenter(boardCell(2, 2)) + const Offset(0, 30);
    final g2 = await tester.startGesture(from);
    await g2.moveTo(from + const Offset(0, 40));
    await tester.pump();
    await g2.moveTo(to);
    await tester.pump();
    await g2.up();
    await tester.pump();
    expect(controller.state.placed['0,0'], isNull);
    expect(controller.state.placed['2,2']?.letter, 'K');

    // 3) Tahtadan rafa sürükleyerek geri al.
    final from2 = tester.getCenter(boardCell(2, 2));
    final rackTarget =
        tester.getCenter(find.byType(RackWidget)) + const Offset(0, 30);
    final g3 = await tester.startGesture(from2);
    await g3.moveTo(from2 + const Offset(0, 40));
    await tester.pump();
    await g3.moveTo(rackTarget);
    await tester.pump();
    await g3.up();
    await tester.pump();
    expect(controller.state.placed, isEmpty);
    expect(controller.state.players[0].rack.length, 7);

    // 4) Dolu hücreye bırakma reddedilir: iki taş koy, birini diğerinin
    // üstüne sürükle — hiçbir şey değişmemeli.
    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(0, 0));
    await tester.pump();
    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(0, 1));
    await tester.pump();
    expect(controller.state.placed.length, 2);
    final a = tester.getCenter(boardCell(0, 0));
    final b = tester.getCenter(boardCell(0, 1)) + const Offset(0, 30);
    final g4 = await tester.startGesture(a);
    await g4.moveTo(a + const Offset(0, 40));
    await tester.pump();
    await g4.moveTo(b);
    await tester.pump();
    await g4.up();
    await tester.pump();
    expect(controller.state.placed['0,0'], isNotNull);
    expect(controller.state.placed['0,1'], isNotNull);
  });

  testWidgets(
      'regresyon (Parça 27): tahtanın dışına sürüklerken hayalet taş '
      'KIRPILMIYOR — hover çerçevesi boşken _hoverHighlight artık '
      'Positioned SizedBox.shrink dönüyor, çıplak SizedBox.shrink DEĞİL',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());

    // Rafta bir taşı sürüklemeye başla, tahtanın DIŞINDA bir noktaya taşı
    // (ör. mesaj satırının hizası) — hover hedefi burada `null` olur ve
    // `_hoverHighlight` erken dönüş yolunu tetikler. Kullanıcının gerçek
    // hatası bu erken dönüşün çıplak (Positioned OLMAYAN) bir
    // `SizedBox.shrink()` döndürmesiydi — bu, üst overlay Stack'in TEK
    // non-positioned çocuğu hâline gelip Stack'i 0×0'a küçültüyor ve
    // varsayılan `clipBehavior: Clip.hardEdge` sürüklenen hayalet taşı
    // (Stack'in DİĞER çocuğu, hâlâ Positioned) tamamen kırpıyordu.
    final start = tester.getCenter(rackTile(0));
    final offBoard = tester.getCenter(find.byType(RackWidget));
    final g = await tester.startGesture(start);
    await g.moveTo(start + const Offset(0, -40)); // eşik aşılır
    await tester.pump();
    await g.moveTo(offBoard);
    await tester.pump();

    // Hayalet taş widget'ı hâlâ ağaçta olmalı (Board/Rack'in dışında) —
    // bunu üretim kodu zaten sağlıyordu (yalnızca PAINT kırpılıyordu, ağaç
    // hiç değişmiyordu — bu yüzden bu satır tek başına hatayı YAKALAMAZ).
    Finder outsideGhost() => find.byWidgetPredicate((w) {
          if (w is! TileWidget) return false;
          final e = find.byWidget(w).evaluate().first;
          var underBoardOrRack = false;
          e.visitAncestorElements((a) {
            if (a.widget.runtimeType == BoardWidget ||
                a.widget.runtimeType == RackWidget) {
              underBoardOrRack = true;
              return false;
            }
            return true;
          });
          return !underBoardOrRack;
        });
    expect(outsideGhost(), findsOneWidget);

    // ASIL kanıt: hayalet taşın EN YAKIN Stack atası — `_hoverHighlight`
    // ile `_buildGhost`'u saran overlay Stack'i — asla (0,0)'a KÜÇÜLMEMELİ.
    // Bu hata giderilmeden ÖNCE bu boyut tam olarak Size.zero'ya düşüyordu
    // (tahtanın dışına ilk çıkışta) — bkz. mobile/CLAUDE.md Parça 27.
    final ghostElement = outsideGhost().evaluate().first;
    Element? stackElement;
    ghostElement.visitAncestorElements((a) {
      if (a.widget is Stack) {
        stackElement = a;
        return false;
      }
      return true;
    });
    expect(stackElement, isNotNull,
        reason: 'Hayalet taşın bir Stack atası olmalı');
    final stackSize = (stackElement!.renderObject as RenderBox).size;
    expect(stackSize, isNot(Size.zero),
        reason: 'Overlay Stack (0,0)\'a küçülmüş — hayalet taş tamamen '
            'kırpılıyor demektir. stackSize=$stackSize');

    await g.up();
    await tester.pump();
  });

  testWidgets(
      'performans regresyonu: sürükleme sırasında BoardWidget PER-MOVE '
      'yeniden inşa EDİLMİYOR (8 Ağustos 2026, kullanıcı iPad Safari\'de '
      'titreme/takılma bildirdi — bkz. mobile/CLAUDE.md Parça 23)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());

    final start = tester.getCenter(rackTile(0));
    final g = await tester.startGesture(start);
    await g
        .moveTo(start + const Offset(0, -40)); // eşik aşılır, sürükleme başlar
    await tester.pump();

    // Eşik-aşımı anındaki build'ler referans — asıl iddia BUNDAN SONRAKİ N
    // pointer-move'un `BoardWidget`'ı (169 hücre + territory hesabı) HİÇ
    // yeniden inşa ETMEDİĞİ (dragHiddenKey/hover overlay artık bağımsız bir
    // ValueNotifier'dan besleniyor — bkz. GameScreen._dragNotifier).
    final buildsBeforeMoves = debugBoardBuildCountForTests;

    const steps = 30;
    for (var i = 0; i < steps; i++) {
      final r = i % boardSize;
      final c = (i * 7) % boardSize; // farklı hücrelere dağılsın
      final target = tester.getCenter(boardCell(r, c)) + const Offset(0, 30);
      await g.moveTo(target);
      await tester.pump();
    }

    final extraBuilds = debugBoardBuildCountForTests - buildsBeforeMoves;
    // Brief'in izin verdiği tolerans "0-1 kez" — burada sürükleme zaten
    // başlamış olduğundan (eşik önceden aşıldı) pratikte tam 0 bekleniyor.
    expect(extraBuilds, lessThanOrEqualTo(1),
        reason: '$steps pointer-move adımı sırasında BoardWidget $extraBuilds '
            'kez yeniden inşa edildi (per-move rebuild REGRESYONU — düzeltme '
            'geri alınmış/bozulmuş olabilir).');

    await g.up();
    await tester.pump();
  });

  testWidgets('GameOver modalı ekran görüntüsü (beraberlik varyantı yok)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(520, 700));
    final golden = jsonDecode(
      File('../kelimeki_core/test/goldens/reducer_ai4.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final steps = golden['steps'] as List;
    final finished = gameStateFromJson(
        ((steps.last as Map)['state'] as Map).cast<String, Object?>());

    final key = GlobalKey();
    // Dialog overlay'i Navigator'da yaşadığından ekran görüntüsü için modal
    // doğrudan bir widget olarak (showDialog'suz) çizilir.
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'SpaceGrotesk'),
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: Colors.white,
          child: Center(child: GameOverModal(state: finished)),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/screenshots/game_over.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  testWidgets(
      'kaydırma görünümü TAM GENİŞLİK, 680 sınırı İÇERİDE — web deseni '
      '(Parça 40: 680 kabı kaydırmayı sarınca tahtanın taşan gölgesi '
      'kırpılıyordu)', (tester) async {
    // İçerik sığmasın (kaydırılabilir olsun) ve viewport 680'den GENİŞ olsun.
    await setPhoneViewSize(tester, const Size(900, 620));
    final c =
        GameController(words: words, autoPlayAi: false, nowIso: () => '');
    c.dispatch(ResumeSavedAction(craftedState()));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'SpaceGrotesk'),
      home: GameScreen(controller: c, words: words),
    ));
    await tester.pumpAndSettle();

    // Ana (dikey) kaydırma görünümü — GameHeader'ın kendi YATAY şeridi de
    // aynı widget'ı kullandığından eksenle ayırt ediliyor (Parça 15 dersi).
    final scroll = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.vertical);
    expect(tester.getSize(scroll).width, 900,
        reason: 'kaydırma görünümü tam genişlik olmalı — 680 olursa tahtanın '
            'gölgesi kırpılır');

    // İçerik yine de 680'e sınırlı (Parça 17: aksi halde tahta kenardan '
    // kenara gerilir).
    final inner = find.descendant(
        of: scroll,
        matching: find.byWidgetPredicate((w) =>
            w is ConstrainedBox && w.constraints.maxWidth == 680));
    expect(inner, findsWidgets, reason: 'içerik sütunu 680e sınırlı olmalı');
  });
}
