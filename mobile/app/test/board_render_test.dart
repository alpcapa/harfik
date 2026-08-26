// BoardWidget render testi — golden fixture'daki GERÇEK bir bitmiş oyun
// (reducer_ai4: teslim olmuş oyuncu, bölge dış hatları, dolu tahta) çizilir;
// hata fırlamadığı ve taş sayısının state'le eşleştiği doğrulanır. Ayrıca
// PNG ekran görüntüleri build/screenshots/ altına yazılır (görsel inceleme
// için — commit edilmez, build/ gitignore'da).
//
// Not: flutter_test varsayılan fontu metinleri blok (Ahem) çizer — ekran
// görüntüsü okunur olsun diye Flutter SDK'nın kendi Roboto'su FontLoader'la
// yüklenir; bulunamazsa görüntü yine üretilir (bloklu), test geçer.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/neo_box.dart' show NeoBox;
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/game/tile_widget.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

GameState loadFixtureState(String name) {
  final golden = jsonDecode(
    File('../kelimeki_core/test/goldens/$name.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final steps = golden['steps'] as List;
  final last = (steps.last as Map)['state'] as Map;
  return gameStateFromJson(last.cast<String, Object?>());
}

Future<void> capturePng(
    WidgetTester tester, GlobalKey key, String outPath) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File(outPath);
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> pumpBoard(WidgetTester tester, GlobalKey key, GameState state,
    {MoveOverlay? overlay}) async {
  await tester.pumpWidget(MaterialApp(
    theme: kelimekiTheme(),
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: RepaintBoundary(
          key: key,
          // Beyaz zemin boundary'nin İÇİNDE olmalı ve pay gölgelerin tam
          // sönümlenmesine yetmeli — aksi halde PNG'de gölgeler saydam zemin
          // üzerine ham yarı-şeffaf gri kaydedilip kesiliyor ve "kalın gri
          // levha" gibi görünüyordu (kullanıcı bildirimi, 6 Ağustos 2026).
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(90),
              child: SizedBox(
                width: 560,
                height: 560,
                // Bu testler yalnızca IZGARA render'ını ölçer; kartın alt
                // bilgi şeridi (Hamleler/X2-X3) sabit 560×560 kutuya
                // sığmayacağından kapatılır — şeridin kendi testi
                // move_history_test.dart'ta.
                child: BoardWidget(
                    state: state, moveOverlay: overlay, hideFooter: true),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}


/// Boş tahtalı, 2 kişilik bir oyun — filigranlar (köşe numarası / X2 / X3)
/// yalnızca BOŞ hücrelerde çizildiğinden bitmiş bir fixture bunun için
/// kullanılamaz (merkez hücre dolu olabilir).
GameState emptyBoardState() {
  Player p(String name, int index) => Player(
        name: name,
        corners: cornersFor(2)[index],
        colorIndex: index,
        isAI: index != 0,
        surrendered: false,
        rack: const [],
        score: 0,
        bestMoveScore: 0,
        bestWordScore: 0,
        longestWord: '',
        moveCount: 0,
        moveScoreSum: 0,
      );
  return GameState(
    phase: GamePhase.play,
    startedAt: '',
    multiSession: false,
    endReason: EndReason.normal,
    board: createEmptyBoard(),
    bag: const [],
    bonuses: buildInitialBonuses(),
    placed: const {},
    players: [p('Ironman', 0), p('Yapay Zeka 2', 1)],
    current: 0,
    turnCount: 0,
    consecutivePasses: 0,
    isGameOver: false,
    message: '',
    messageType: MessageKind.none,
    selectedTile: null,
    swapMode: false,
    swapSelection: const [],
    lastMoveCells: const [],
    moveHistory: const [],
  );
}

/// Filigran testleri için: tahtayı gerçek genişliğinde (web'in
/// `max-w-[680px]` kartı gibi) çizer — `pumpBoard`ın sabit 560'ı ve 90px
/// payı burada yanıltıcı olurdu.
Future<void> pumpBoardSized(
    WidgetTester tester, GameState state, double side) async {
  await tester.pumpWidget(MaterialApp(
    theme: kelimekiTheme(),
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: side,
          height: side,
          child: BoardWidget(state: state, hideFooter: true),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRobotoIfAvailable);

  testWidgets('reducer_ai4 final tahtası hatasız çizilir, taş sayısı tutar',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 760));
    final state = loadFixtureState('reducer_ai4');
    var tileCount = 0;
    for (final row in state.board) {
      for (final t in row) {
        if (t != null) tileCount++;
      }
    }
    expect(tileCount, greaterThan(30)); // gerçekten dolu bir tahta

    final key = GlobalKey();
    await pumpBoard(tester, key, state);
    expect(tester.takeException(), isNull);
    expect(find.byType(TileWidget), findsNWidgets(tileCount));

    await capturePng(tester, key, 'build/screenshots/board_ai4.png');
  });

  testWidgets('hamle çerçevesi + puan rozeti çizilir (geçerli/yeşil)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 760));
    final state = loadFixtureState('reducer_ai2');
    final overlay = MoveOverlay(
      valid: true,
      cells: state.lastMoveCells,
      score: 23,
    );
    final key = GlobalKey();
    await pumpBoard(tester, key, state, overlay: overlay);
    expect(tester.takeException(), isNull);
    expect(find.text('+23'), findsOneWidget);

    await capturePng(tester, key, 'build/screenshots/board_ai2_overlay.png');
  });

  // Web'de filigran puntosu kutuya SIĞDIRILMIYOR, ekran genişliğine bağlı bir
  // `clamp` (Board.tsx): köşe `clamp(80px,32vw,220px)`, X2
  // `clamp(60px,24vw,165px)`, X3 `clamp(7px,1.9vw,12px)`. Aşağıdaki sayılar
  // ELLE HESAPLANMADI — derlenmiş CSS + Chromium ile ölçüldü (17 Ağustos
  // 2026). Port 17 Ağustos'a kadar `FittedBox` kullanıyordu (punto kutunun
  // oranından çıkıyordu) ve köşe/X2 için `fontFamily` hiç vermiyordu (tema
  // SpaceGrotesk'ine düşüyordu) — kullanıcı iki ekranı yan yana koyup
  // bildirdi.
  testWidgets('filigran puntoları web ile aynı — geniş ekran (clamp tavanı)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(834, 1100));
    await pumpBoardSized(tester, emptyBoardState(), 680);
    expect(tester.takeException(), isNull);

    TextStyle styleOf(String s) => tester.widget<Text>(find.text(s)).style!;

    expect(styleOf('1').fontSize, closeTo(220, 0.01));
    expect(styleOf('1').fontFamily, 'SpaceMono');
    expect(styleOf('1').height, 1); // web: leading-none
    expect(styleOf('X2').fontSize, closeTo(165, 0.01));
    expect(styleOf('X2').fontFamily, 'SpaceMono');
    expect(styleOf('X2').height, 1);
    expect(styleOf('X3').fontSize, closeTo(12, 0.01));
    expect(styleOf('X3').fontFamily, 'SpaceMono');
  });

  testWidgets('filigran puntoları web ile aynı — dar ekran (clamp ortası)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await pumpBoardSized(tester, emptyBoardState(), 374);
    expect(tester.takeException(), isNull);

    TextStyle styleOf(String s) => tester.widget<Text>(find.text(s)).style!;

    // 390px'te ölçülen web değerleri: 124.8 / 93.6 / 7.41.
    expect(styleOf('1').fontSize, closeTo(124.8, 0.01));
    expect(styleOf('X2').fontSize, closeTo(93.6, 0.01));
    expect(styleOf('X3').fontSize, closeTo(7.41, 0.01));
  });

  // Web'de taşlar `relative z-[5]` ile filigranın ÜSTÜNDE boyanır; portta
  // filigran ızgaradan sonra çizildiğinden taşların üstüne biniyordu
  // (17 Ağustos 2026, kullanıcı iki ekranı yan yana koyup bildirdi).
  testWidgets('filigran taşların üstüne binmez, boş hücrelerde görünür',
      (tester) async {
    await setPhoneViewSize(tester, const Size(834, 1100));

    // Köşe filigranının ("1") alanına üç taş: biri onaylanmış (board), biri
    // taslak (placed), biri de o an SÜRÜKLENEN taslağın kaynağı. Sonuncusu
    // boş çizildiğinden (bkz. `_buildCell`) filigran orada görünmeli.
    final board = createEmptyBoard();
    board[0][0] = const Tile(letter: 'K', pts: 1);
    final state = emptyBoardState().copyWith(
      board: board,
      placed: {
        cellKey(2, 2): const Tile(letter: 'E', pts: 1),
        cellKey(1, 1): const Tile(letter: 'R', pts: 1),
      },
    );

    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 680,
            height: 680,
            child: BoardWidget(
              state: state,
              hideFooter: true,
              dragHiddenKey: cellKey(1, 1),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final clip = tester
        .widget<ClipPath>(find.byKey(const ValueKey('board-watermarks')));
    final size = tester.getSize(find.byKey(const ValueKey('board-watermarks')));
    final path = clip.clipper!.getClip(size);

    // Hücre merkezini ızgara geometrisinden hesapla (13 hücre, 3px boşluk).
    Offset centerOf(int r, int c) {
      final cell = (size.width - 3 * 12) / 13;
      return Offset(c * (cell + 3) + cell / 2, r * (cell + 3) + cell / 2);
    }

    // Taşın olduğu hücreler kesiliyor → filigran orada ÇİZİLMEZ.
    expect(path.contains(centerOf(0, 0)), isFalse); // onaylanmış taş
    expect(path.contains(centerOf(2, 2)), isFalse); // taslak taş
    // Sürüklenen taslağın kaynağı boş çizildiğinden kesilmemeli.
    expect(path.contains(centerOf(1, 1)), isTrue);
    // Boş köşe hücresi ve bonus bölgesi hücresi: filigran görünür.
    expect(path.contains(centerOf(0, 3)), isTrue);
    expect(path.contains(centerOf(6, 6)), isTrue);
  });

  group('"Buradan başla" balonu (Parça 145)', () {
    // Web `Board.tsx`'in `startHint`inin eşleniği. Konum mutlak katmanda
    // hesaplandığından ızgara geometrisi değişirse SESSİZCE kayar; iddia bu
    // yüzden kendi formülüme değil GERÇEK ev karesinin kutusuna karşı
    // (web'deki kardeş testle aynı desen, `tests/smoke.spec.ts`).
    Future<void> pump(WidgetTester tester, GameState state,
        {ValueListenable<Object?>? drag}) async {
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              height: 390,
              child: BoardWidget(
                  state: state, hideFooter: true, dragListenable: drag),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('boş tahtada ev karesinin YANINDA çıkar', (tester) async {
      await setPhoneViewSize(tester, const Size(390, 844));
      await pump(tester, emptyBoardState());

      final balon = find.text('Buradan başla');
      expect(balon, findsOneWidget);

      // KURULUM KONTROLÜ: ızgaranın ilk `NeoBox`ı gerçekten (0,0) hücresi mi?
      // Değilse aşağıdaki iddia yanlış bir kutuyla karşılaştırır ve sessizce
      // geçebilirdi.
      final evKare = tester.getRect(find.byType(NeoBox).first);
      final izgara = tester.getRect(find.byType(GridView));
      expect((evKare.left - izgara.left).abs(), lessThan(1),
          reason: 'ilk NeoBox (0,0) hücresi değil — iddia yanlış kutuya bakıyor');
      expect((evKare.top - izgara.top).abs(), lessThan(1));

      final b = tester.getRect(balon);
      // Balon ev karesinin SAĞINDA, tam bir ızgara boşluğu (3px) kadar
      // sonra — ve dikeyde o kareyle AYNI merkezde. Tolerans sıkı: yüzde
      // tabanlı bir hesap buradan geçemez (web'de ölçüldü).
      expect(b.left - evKare.right, greaterThan(1));
      expect(b.center.dy - evKare.center.dy, closeTo(0, 0.75));
      expect(b.right, lessThanOrEqualTo(izgara.right + 1),
          reason: 'balon tahtadan taşıyor');
    });

    testWidgets('tahtada taş varsa ÇIKMAZ', (tester) async {
      await setPhoneViewSize(tester, const Size(390, 844));
      final s = emptyBoardState();
      final board = [for (final row in s.board) [...row]];
      board[6][6] = const Tile(letter: 'A', pts: 1);
      await pump(tester, s.copyWith(board: board));
      expect(find.text('Buradan başla'), findsNothing);
    });

    testWidgets('bu turda konmuş TASLAK taş varsa ÇIKMAZ', (tester) async {
      // Balon taslağın üstünü kapatmasın: oyuncu oynamaya başladıysa ipucu
      // görevini bitirmiştir.
      await setPhoneViewSize(tester, const Size(390, 844));
      final s = emptyBoardState();
      await pump(
          tester,
          s.copyWith(placed: const {'0,0': Tile(letter: 'A', pts: 1)}));
      expect(find.text('Buradan başla'), findsNothing);
    });

    testWidgets('rafta taş SEÇİLİYSE ÇIKMAZ', (tester) async {
      // "Taşı kaldırdığı anda yok olsun" — dokunup seçmek de kaldırmaktır.
      await setPhoneViewSize(tester, const Size(390, 844));
      await pump(tester, emptyBoardState().copyWith(selectedTile: 0));
      expect(find.text('Buradan başla'), findsNothing);
    });

    testWidgets('SÜRÜKLEME başlayınca kaybolur, bitince geri gelir',
        (tester) async {
      // Sürükleme `selectedTile`ı SET ETMİYOR (yalnızca hareketsiz dokunuş
      // seçiyor), o yüzden ayrı bir sinyal gerekiyor. Bu iddia aynı zamanda
      // Parça 23'ün kuralını da koruyor: sinyal bir prop değil dinlenebilir,
      // yani tahta sürükleme boyunca yeniden İNŞA edilmiyor.
      await setPhoneViewSize(tester, const Size(390, 844));
      final drag = ValueNotifier<Object?>(null);
      addTearDown(drag.dispose);
      await pump(tester, emptyBoardState(), drag: drag);
      expect(find.text('Buradan başla'), findsOneWidget);

      drag.value = 'sürükleniyor';
      await tester.pump();
      expect(find.text('Buradan başla'), findsNothing);

      drag.value = null;
      await tester.pump();
      expect(find.text('Buradan başla'), findsOneWidget,
          reason: 'sürükleme iptal edilince ipucu geri gelmeli');
    });

    testWidgets("sıra YZ'deyken ÇIKMAZ", (tester) async {
      await setPhoneViewSize(tester, const Size(390, 844));
      await pump(tester, emptyBoardState().copyWith(current: 1));
      expect(find.text('Buradan başla'), findsNothing);
    });
  });
}
