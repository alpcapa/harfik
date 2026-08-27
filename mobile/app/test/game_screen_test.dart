// GameScreen etkileşim testleri — dokunarak taş yerleştirme, canlı
// geçerlilik çerçevesi, joker akışı, geri alma ve OYNA. Kontrollü raf için
// state ResumeSavedAction ile kurulur (golden üreticisindeki aynı desen);
// sözlük gerçek asset dosyasından yüklenir.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart'
    show BoardWidget, DashedBorderPainter, debugBoardBuildCountForTests;
import 'package:kelimeki/src/ui/game/game_over_modal.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/game/invasion_confirm.dart';
import 'package:kelimeki/src/ui/tokens.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'package:kelimeki/src/ui/game/rack_widget.dart';
import 'package:kelimeki/src/ui/game/remaining_tiles_modal.dart';
import 'package:kelimeki/src/ui/game/tile_widget.dart';
import 'package:kelimeki/src/ui/game/wild_letter_sheet.dart';
import 'package:kelimeki/src/ui/game/dialog_shell.dart' show KDialogCard;
import 'package:kelimeki/src/ui/game/neo_box.dart'
    show
        debugBlurPaintCountForTests,
        debugCachedBlitCountForTests,
        debugResetNeoBoxCacheForTests;
import 'package:kelimeki/src/ui/game/neo_button.dart'
    show NeoButton, NeoButtonVariant;
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

/// Bağlantıyı test içinde açıp kapatabilmek için — üretim `OnlineStatus`'una
/// bir debug setter'ı eklemek yerine alt sınıf; platform kanalına hiç
/// dokunmaz (`super.fake()`).
class _ToggleOnlineStatus extends OnlineStatus {
  _ToggleOnlineStatus() : super.fake();

  bool _v = true;

  @override
  bool get online => _v;

  void set(bool v) {
    _v = v;
    notifyListeners();
  }
}

Future<GameController> pumpGame(WidgetTester tester, GlobalKey key) async {
  final controller =
      GameController(words: words, autoPlayAi: false, nowIso: () => '');
  controller.dispatch(ResumeSavedAction(craftedState()));
  await tester.pumpWidget(MaterialApp(
    theme: kelimekiTheme(),
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

  // 27 Ağustos 2026 — kullanıcı bildirdi: *"tahtaya konan taşı kaldırmak
  // için ilk tıklama yakalamıyor. İkincide ya da üçüncüde yakalanıyor."*
  //
  // ÖLÇÜLDÜ (420×900): tahta hücresi 26,2 px ve parmağın temas MERKEZİ nişan
  // alınan noktanın ALTINDA kalıyor — taslak taşını geri almak için dokunan
  // kullanıcı sık sık BİR ALT hücreye düşüyor. O hücre boşsa eskiden hiçbir
  // şey olmuyor, dahası ekrana "Önce bir harf seç." yazıyordu (yani geri
  // almaya çalışana alakasız bir uyarı).
  //
  // 24 Ağustos'un kurtarması yalnızca OYNANMIŞ hücrelerden çağrılıyordu;
  // boş hücre kısıtının gerekçesi "kelimeyi dizerken yan hücreye harf koymak
  // zorlaşmasın"dı — ki bu YALNIZCA seçili taş varken geçerli. Aşağıdaki
  // ikinci test o gerekçeyi koruyor.
  testWidgets('taslak taşın ALTINDAKİ boş hücreye dokunmak taşı GERİ ALIR',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(0, 0));
    await tester.pump();
    expect(controller.state.placed.keys, ['0,0']);
    // Taş konunca seçim düşer — ıskalamanın kurtarılabildiği durum TAM
    // OLARAK bu (seçim varken davranış değişmiyor, aşağı bkz.).
    expect(controller.state.selectedTile, isNull);

    // Hata sınıfı hâlâ burada mı: hücre gerçekten küçük mü?
    final hucre = tester.getRect(boardCell(0, 0));
    expect(hucre.height, lessThan(30),
        reason: 'hücre büyüdüyse bu kurtarmanın gerekçesini gözden geçir');

    // ISKALAMA: bir alt hücrenin (BOŞ) merkezine dokun.
    await tester.tapAt(tester.getRect(boardCell(1, 0)).center);
    await tester.pumpAndSettle();

    expect(controller.state.placed, isEmpty,
        reason: 'taslak taş geri alınmadı — ıskalama sessizce yutuldu');
  });

  testWidgets('SEÇİLİ taş varken aynı dokunuş HARFİ KOYAR (kurtarma yok)',
      (tester) async {
    // Negatif eş: kurtarma yalnızca seçim YOKKEN devreye girmeli. Aksi halde
    // kelimeyi dizerken bir sonraki harfi komşu hücreye koymak imkânsızlaşır
    // — 24 Ağustos'ta boş hücrelerin bilerek dışarıda bırakılma sebebi buydu.
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(0, 0));
    await tester.pump();
    expect(controller.state.placed.keys, ['0,0']);

    // Şimdi İKİNCİ bir taş seç ve komşu hücreye koy.
    await tester.tap(rackTile(0));
    await tester.pump();
    expect(controller.state.selectedTile, isNotNull);
    await tester.tapAt(tester.getRect(boardCell(1, 0)).center);
    await tester.pumpAndSettle();

    expect(controller.state.placed.keys.toSet(), {'0,0', '1,0'},
        reason: 'seçili taş varken komşu hücreye koyma bozulmuş — kurtarma '
            'bu duruma HİÇ karışmamalı');
  });

  // 27 Ağustos 2026, kullanıcı İKİNCİ kez bildirdi: *"Hâlâ tahtaya koyulan
  // taşı her zaman alamıyorum. 1-2 denemeden sonra alabiliyorum."*
  //
  // Bir gün önceki kurtarma YALNIZCA "hiç kıpırdamadı" dalını kapsıyordu.
  // ÖLÇÜLDÜ (420×900): 6 px kayan dokunuş taşı geri alıyor, ama **12 ve
  // 20 px kayanlar HİÇBİR ŞEY yapmıyordu** — parmak 10 px'lik eşiği aşınca
  // jest "sürükleme" sayılıp 30 px KALDIRILMIŞ bir noktaya bırakılıyordu.
  // Raf tarafı da aynı: titreşimli dokunuşta taş seçilemiyordu bile.
  //
  // Artık iki AYRI karar var: hayalet 10 px'te belirir, bırakma ise jest
  // gerçekten bir yere gittiyse "bırakma" sayılır.
  for (final kayma in const [6.0, 12.0, 20.0]) {
    testWidgets('titreşimli dokunuş (${kayma.toInt()} px) taslak taşı GERİ ALIR',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final controller = await pumpGame(tester, GlobalKey());

      await tester.tap(rackTile(0));
      await tester.pump();
      await tester.tap(boardCell(0, 0));
      await tester.pump();
      expect(controller.state.placed.keys, ['0,0']);

      final h = tester.getRect(boardCell(0, 0));
      final g = await tester.startGesture(h.center);
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveBy(Offset(0, kayma));
      await tester.pump(const Duration(milliseconds: 20));
      await g.up();
      await tester.pumpAndSettle();

      expect(controller.state.placed, isEmpty,
          reason: '$kayma px kayan dokunuş sessizce kayboldu — bırakma '
              'eşiği (`_tapSlopOnRelease`) düşmüş olabilir');
    });

    testWidgets('titreşimli dokunuş (${kayma.toInt()} px) RAF taşını SEÇER',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final controller = await pumpGame(tester, GlobalKey());
      expect(controller.state.selectedTile, isNull);

      final rt = tester.getRect(rackTile(0));
      final g = await tester.startGesture(rt.center);
      await tester.pump(const Duration(milliseconds: 20));
      await g.moveBy(Offset(0, -kayma));
      await tester.pump(const Duration(milliseconds: 20));
      await g.up();
      await tester.pumpAndSettle();

      expect(controller.state.selectedTile, 0,
          reason: '$kayma px kayan dokunuşta raf taşı seçilmedi');
      // Ve tahtaya İSTEMEDEN konmamış olmalı: kaldırılmış nokta rafın
      // 30 px üstünü, yani tahtanın alt satırını hedefliyordu.
      expect(controller.state.placed, isEmpty,
          reason: 'raf taşı istemeden tahtaya kondu');
    });
  }

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
    expect(find.text('JOKER HANGİ HARF OLSUN?'), findsOneWidget);
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
    expect(find.text('JOKERİ HANGİ HARFE ÇEVİR?'), findsOneWidget);
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
      '(Parça 20\'de bottom sheet\'in %56 sınırı kırpıyordu; Parça 47\'de '
      'yapı KModal\'a geçti — bu kontrat İKİSİNDE de geçerli)',
      (tester) async {
    // Oyun ekranının KENDİ sorumluluğundaki (Parça 15-17) kaydırma/genişlik
    // davranışından bilerek izole — yalnızca showWildLetterSheet'in kendi
    // yükseklik/kaydırma sözleşmesini sınıyor. Geniş/kısa yüzey (iPad yatay
    // moddaki dar kullanılabilir yükseklikle aynı sınıf): 29 harflik 6
    // sütunlu ızgara + başlık kısa bir yükseklikte kabına sığmaz.
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
    expect(find.text('JOKER HANGİ HARF OLSUN?'), findsOneWidget);

    // Kabın (eskiden sheet, şimdi KModal) kendi kaydırma alanı olmasaydı
    // dar yükseklikte klasik "RenderFlex overflowed" fırlardı — kesilen
    // içerik görsel olarak sessiz kırpma gibi görünse de kök sebep budur.
    expect(tester.takeException(), isNull);
    // KModal'ın gövdesi kaydırılabilir; ızgaranın son harfi (Z) ağaçta
    // gerçekten bulunabilir VE kaydırma katmanının içinde.
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

    // Raf başlığında taş sayısı YOK (17 Ağustos 2026, iki platformdan da
    // kaldırıldı) — ama swap modundaki seçim sayacı KALMALI; ikisi bir arada
    // olmazsa "hepsini sildim" gibi bir regresyon da bu testi geçerdi.
    expect(find.text('7 harf'), findsNothing);

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
    expect(find.text('2 seçili'), findsOneWidget);

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
    // KDialogCard actions'ı liste sırasıyla soldan sağa diziyor. Butonlar
    // artık Material değil NeoButton (web `btn-raised`/`btn-raised-neutral`,
    // 15 Ağustos 2026 diyalog kabuğu) ve kabul olanın accent varyantı
    // taşıması da sözleşmenin parçası.
    final acceptBtn = find.descendant(of: find.byType(KDialogCard), matching: find.widgetWithText(NeoButton, 'PAS GEÇ'));
    final cancelBtn = find.descendant(of: find.byType(KDialogCard), matching: find.widgetWithText(NeoButton, 'VAZGEÇ'));
    expect(acceptBtn, findsOneWidget);
    expect(cancelBtn, findsOneWidget);
    expect(tester.widget<NeoButton>(acceptBtn).variant,
        NeoButtonVariant.accent);
    expect(tester.widget<NeoButton>(cancelBtn).variant,
        NeoButtonVariant.neutral);
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
    // KModal başlığı trUpper'dan geçer (web'in `uppercase` CSS'i) — modal
    // Parça 50'de ham Dialog'dan ortak kabuğa taşındı.
    expect(find.text('KALAN TAŞLAR'), findsOneWidget);
    // Dağılım 100 − tahta 0 − benim rafım 7 = 93 taş dışarıda.
    expect(find.textContaining('93'), findsOneWidget);
  });

  testWidgets(
      'Kalan Taşlar: tahtaya konmuş ama ONAYLANMAMIŞ taş rakibin elinde '
      'sayılmaz (18 Ağu 2026 hatası — kullanıcı son hamlesinden önce 10 puan '
      'sayıp bitişte -7 gördü)', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());

    await tester.tap(rackTile(0)); // K
    await tester.pump();
    await tester.tap(boardCell(0, 0)); // 0. oyuncunun ev karesi
    await tester.pump();
    expect(controller.state.placed.length, 1, reason: 'taş bekliyor olmalı');

    await tester.tap(find.text('TORBA 6')); // torba değişmedi
    await tester.pumpAndSettle();
    // Taş raftan çıktı ama HÂLÂ bende: 100 − tahta 0 − raf 6 − bekleyen 1 = 93.
    // Düzeltmeden önce 94 çıkıyor, yani bekleyen taş rakibe yazılıyordu.
    expect(find.textContaining('93'), findsOneWidget);
    expect(find.textContaining('94'), findsNothing);
  });

  testWidgets(
      'Kalan Taşlar KModal kabuğunda: 360px kart + web h-12 (48px) hücre '
      '(Parça 50: ham Dialog iPad\'de kartı ekrana yayıp taşları '
      'devleştiriyordu)', (tester) async {
    // GENİŞ ekran — hatanın gerçekten göründüğü yer (iPad).
    await setPhoneViewSize(tester, const Size(1200, 900));
    await pumpGame(tester, GlobalKey());

    await tester.ensureVisible(find.text('TORBA 6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TORBA 6'));
    await tester.pumpAndSettle();
    expect(find.byType(RemainingTilesModal), findsOneWidget);

    final card = find.descendant(
      of: find.byType(RemainingTilesModal),
      matching: find.byWidgetPredicate((w) =>
          w is ConstrainedBox && w.constraints.maxWidth == 360),
    );
    expect(card, findsOneWidget, reason: 'web Modal 360px kartı');

    final cell = find
        .descendant(
            of: find.byType(RemainingTilesModal),
            matching: find.byType(TileWidget))
        .first;
    expect(tester.getSize(cell).height, 48, reason: 'web hücre h-12');
  });

  testWidgets(
      'raf satırı buton puntoları web ile aynı: OYNA 12px, oyun bitince '
      'TEKRAR OYNA tek satır 15px (Parça 50)', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());

    expect(tester.widget<Text>(find.text('OYNA')).style!.fontSize, 12);

    // Oyun bitişini fixture'dan kur (GameOver testindeki aynı yol).
    final golden = jsonDecode(
      File('../kelimeki_core/test/goldens/reducer_ai4.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final steps = golden['steps'] as List<dynamic>;
    final finalState = gameStateFromJson(
        (steps.last as Map<String, dynamic>)['state'] as Map<String, dynamic>);
    final c = GameController(
        words: SetWordSource(const ['ab']), autoPlayAi: false, nowIso: () => '');
    c.restore(finalState);
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: GameScreen(controller: c, words: SetWordSource(const ['ab'])),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kapat')); // GameOver modalını kapat
    await tester.pumpAndSettle();

    // Etiket Parça 60'ta 'YENİ OYUN AÇ' → 'TEKRAR OYNA' oldu; Parça 50'nin
    // ASIL sözleşmesi (tek satır, 15px) aynen geçerli.
    final newGame = tester.widget<Text>(find.text('TEKRAR OYNA'));
    expect(newGame.style!.fontSize, 15,
        reason: 'web text-[15px] — OYNA\'dan belirgin büyük');
  });

  testWidgets(
      'rafın ALTINDAKİ aksiyon satırı web ile aynı: 11px/1.2 tracking/1.5 '
      'satır, 6px boşluk ve EŞİT yükseklik (TORBA dahil)', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());

    // Web (ölçüldü — derlenmiş CSS + Chromium): `text-[11px] font-bold
    // tracking-[1.2px]` + gövdeden miras `line-height: 1.5` (=16.5px).
    for (final label in const ['PAS GEÇ', 'DEĞİŞTİR', 'KARIŞTIR', 'GERİ AL']) {
      final st = tester.widget<Text>(find.text(label)).style!;
      expect(st.fontSize, 11, reason: '$label puntosu');
      expect(st.letterSpacing, 1.2, reason: '$label tracking (web 1.2px)');
      expect(st.height, 1.5, reason: '$label satır yüksekliği (web 1.5)');
    }

    // Boşluk web `gap-1.5` = 6px.
    final pas = tester.getRect(find.widgetWithText(NeoButton, 'PAS GEÇ'));
    final degis = tester.getRect(find.widgetWithText(NeoButton, 'DEĞİŞTİR'));
    expect(degis.left - pas.right, closeTo(6, 0.01), reason: 'web gap-1.5');

    // TORBA'nın 13px'lik sayacı satırı yükseltiyor; web'de flex `stretch`
    // hepsini EN UZUNA eşitliyor. Bu assertion olmadan tracking/satır
    // düzeltmesi TORBA'yı 3px uzun bırakan bir regresyon üretirdi.
    final torba = tester.getRect(find.byWidgetPredicate(
        (w) => w is NeoButton && w.label.startsWith('TORBA')));
    expect(torba.height, pas.height,
        reason: 'web flex stretch — TORBA ötekilerle aynı boyda');
    expect(pas.height, greaterThan(30),
        reason: '1.5 satır + 10px dolgu; 1.2 satırda ~33px kalıyordu');
  });

  testWidgets(
      'tahta alt şeridinde "Çevrimdışı" uyarısı: bağlantı gidince ANINDA '
      'çıkar, gelince kalkar; puntosu kardeş kontrollerle aynı', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final status = _ToggleOnlineStatus();
    final controller =
        GameController(words: words, autoPlayAi: false, nowIso: () => '');
    controller.dispatch(ResumeSavedAction(craftedState()));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: GameScreen(
        controller: controller,
        words: words,
        auth: AuthService.fake(),
        onlineStatus: status,
      ),
    ));
    await tester.pump();

    expect(find.text('Çevrimdışı'), findsNothing,
        reason: 'çevrimiçiyken uyarı hiç çizilmemeli');

    // Ekranı YENİDEN PUMP ETMEDEN bağlantıyı düşür — gerçek senaryo bu
    // (kullanıcı oyun açıkken uçak moduna geçiyor). Yalnızca ListenableBuilder
    // varsa uyarı görünür; doğrudan okuma bu adımda hiçbir şey değiştirmezdi.
    status.set(false);
    await tester.pump();

    expect(find.text('Çevrimdışı'), findsOneWidget);
    final offline = tester.widget<Text>(find.text('Çevrimdışı')).style!;
    final sibling = tester.widget<Text>(find.text('Nasıl Oynanır?')).style!;
    expect(offline.fontSize, sibling.fontSize,
        reason: 'kardeş kontrollerle aynı punto (web: ikisi de text-[12px])');
    expect(offline.fontFamily, sibling.fontFamily);
    expect(offline.fontWeight, sibling.fontWeight);
    expect(offline.letterSpacing, sibling.letterSpacing);
    expect(offline.color, kRed, reason: 'web text-red');

    status.set(true);
    await tester.pump();
    expect(find.text('Çevrimdışı'), findsNothing);
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

  testWidgets('oyun bitince GameOver modalı: kazanan + Teslim + TEKRAR OYNA',
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
      theme: kelimekiTheme(),
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
    // Modal kapanınca tahta görünür kalır, raf satırında TEKRAR OYNA çıkar.
    expect(find.text('TEKRAR OYNA'), findsOneWidget);

    // Web App.tsx (~1514-1517): GameOver'ı KAPATMAK "Görüş Bildir" formunu
    // AÇAR (`onClose` hem gameOverDismissed hem showFeedback set ediyor).
    // Port yalnızca modalın içindeki linki taşımıştı; kullanıcı 10 Ağustos
    // 2026'da bölüm 9'u koşarken fark etti (bkz. Parça 48).
    expect(find.text(trUpper('Görüşleriniz Bizim İçin Önemli')),
        findsOneWidget);
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
      theme: kelimekiTheme(),
      home: Scaffold(
        body: Center(child: GameOverModal(state: finished, onOpenHistory: () {})),
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
      'oyun bitince TEKRAR OYNA: onay → aynı kadroyla TAZE oyun (Parça 60)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller = await pumpGame(tester, GlobalKey());
    controller.restore(controller.state.copyWith(isGameOver: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kapat')); // GameOver modalı
    await tester.pumpAndSettle();
    // Parça 48: GameOver'ı kapatmak "Görüş Bildir" formunu açıyor — o da
    // kapatılmazsa modal bariyeri aşağıdaki dokunuşları yutar.
    if (find.byTooltip('Kapat').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
    }

    expect(find.text('TEKRAR OYNA'), findsOneWidget);
    expect(find.text('YENİ OYUN AÇ'), findsNothing);
    final names = [for (final p in controller.state.players) p.name];

    // VAZGEÇ yeni oyun BAŞLATMAMALI.
    await tester.tap(find.text('TEKRAR OYNA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Emin misin?'), findsOneWidget);
    await tester.tap(find.text('VAZGEÇ'));
    await tester.pumpAndSettle();
    expect(controller.state.isGameOver, isTrue);

    await tester.tap(find.text('TEKRAR OYNA'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(KDialogCard), matching: find.widgetWithText(NeoButton, 'TEKRAR OYNA')));
    await tester.pumpAndSettle();

    expect(controller.state.isGameOver, isFalse);
    expect(controller.state.turnCount, 0);
    expect([for (final p in controller.state.players) p.name], names,
        reason: 'Kadro korunmalı — Setup\'a dönmeden aynı setle başlıyoruz.');
    expect(find.text('OYNA'), findsOneWidget);
  });

  testWidgets(
      'sürükleme ortasında arka plana alınırsa drag İPTAL olur '
      '(web clearStuckDrag portu — bkz. mobile/CLAUDE.md Parça 58)',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());
    ScrollPhysics? scrollPhysics() => tester
        .widget<SingleChildScrollView>(find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.vertical))
        .physics;

    final start = tester.getCenter(rackTile(0));
    final g = await tester.startGesture(start);
    await g.moveTo(start + const Offset(0, -40)); // eşik aşılır
    await tester.pump();
    expect(scrollPhysics(), isA<NeverScrollableScrollPhysics>());

    // Cihazda bu anda PointerUp bir daha hiç gelmeyebiliyor; web'in
    // visibilitychange/blur neti sürüklemeyi temizler, port bunu hiç
    // taşımamıştı — kurtuluş yalnızca uygulamayı kapatıp açmaktı.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(scrollPhysics(), isNull,
        reason: 'Arka plana alınınca sürükleme temizlenmedi — sayfa kilitli '
            'kaldığından alt butonlara ulaşılamaz.');

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

    // ── DOĞRUDAN ÖLÇÜM: sürükleme sırasında kaç blur çiziliyor? ────────
    //
    // 26 Ağustos 2026, İKİNCİ tur. İlk düzeltme (RepaintBoundary) cihazda
    // İŞE YARAMADI — kullanıcı: *"parmak gidiyor, taş arkadan sonra
    // geliyor"*. İki teşhis de DOLAYLI göstergeye bakmıştı (önce `build`
    // sayısı, sonra simetrik boyama sayacı) ve ikisi de "iyi" derken cihaz
    // yavaştı.
    //
    // Bu iddia dolaylı DEĞİL: tahtanın pahalı işi tam olarak
    // `MaskFilter.blur` çizimleri (169 hücre × 2 + kartın 3'ü). Sürükleme
    // sırasında bu sayının artıp artmadığı, tahtanın yeniden boyanıp
    // boyanmadığının DOĞRUDAN cevabı.
    //
    // Ölçülen sayı loga yazılıyor: 0 ise tahta gerçekten boyanmıyor ve
    // yavaşlığın sebebi BAŞKA yerde (bu ortamda görünmeyen rasterleştirme
    // maliyeti ya da bambaşka bir şey). Yüksekse fikir doğru, uygulama eksik.
    final blurBefore = debugBlurPaintCountForTests;
    // ── PAINT (26 Ağustos 2026) ────────────────────────────────────────
    //
    // Yukarıdaki iddia BUILD sayıyor ve BU YETMİYORDU: kapalı testin ilk
    // gerçek kullanıcıları *"taşları sürerken ağır çekim, akıcı değil"*
    // dedi — sayaç 0 rebuild derken cihaz her karede tahtayı yeniden
    // BOYUYORDU. Hayalet taş, tahtayla aynı katmanda duran bir kardeşti;
    // hareket ettiği her karede `Stack`in tamamı yeniden boyanıyordu ve bu
    // tahtada boyamanın bedeli ~340 `MaskFilter.blur` (169 hücre × 2 + kart).
    //
    // Düzeltme: tahtayı saran `RepaintBoundary`. Bu iddia onun GERÇEKTEN
    // işe yaradığını ölçüyor — Flutter'ın kendi teşhis sayaçlarıyla:
    // `debugSymmetricPaintCount` sınır ile ebeveyni BİRLİKTE boyandığında
    // artar (yani sınır işe yaramıyor), `debugAsymmetricPaintCount` yalnız
    // biri boyandığında (sınır işini yapıyor).
    //
    // Negatif eş: `RepaintBoundary` kaldırılırsa sürükleme boyunca her kare
    // simetrik boyama sayılır ve bu expect düşer.
    // ignore: avoid_print
    print('[ÖLÇÜM] $steps sürükleme adımında blur çizimi: '
        '${debugBlurPaintCountForTests - blurBefore}');
    expect(debugBlurPaintCountForTests - blurBefore, lessThanOrEqualTo(10),
        reason: 'sürükleme sırasında tahta yeniden boyanıyor — '
            '${debugBlurPaintCountForTests - blurBefore} blur çizildi '
            '(tahta tek boyamada ~340 blur eder).');

    final sinir = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(
        of: find.byType(BoardWidget),
        matching: find.byType(RepaintBoundary),
      ).first,
    );
    // ÖNCE ARACIN CANLI OLDUĞUNU KANITLA. Bu sayaçlar yalnızca debug'da,
    // framework sınırı boyarken artıyor; hiç artmıyorlarsa aşağıdaki iddia
    // BOŞUNA geçer ve hiçbir şey kanıtlamaz. Tahta sürükleme başlamadan
    // önce en az bir kez boyandığından toplam >= 1 olmak ZORUNDA.
    expect(
        sinir.debugSymmetricPaintCount + sinir.debugAsymmetricPaintCount,
        greaterThanOrEqualTo(1),
        reason: 'boyama sayaçları hiç artmamış — bu testin ölçtüğü şey '
            'çalışmıyor demektir (aşağıdaki iddia boşuna geçerdi).');

    expect(sinir.debugSymmetricPaintCount, lessThanOrEqualTo(1),
        reason: 'tahta sürükleme boyunca ebeveyniyle BİRLİKTE '
            '${sinir.debugSymmetricPaintCount} kez boyandı — RepaintBoundary '
            'işe yaramıyor demektir (her kare ~340 blur).');

    await g.up();
    await tester.pump();
  });

  // 24 Ağustos 2026 — kullanıcı Android'de bildirdi: *"YZ ile oyun açtığında
  // board'un ekrana gelmesi takılarak oluyor"* (girişli açılışta da; Canlı
  // bekleyen oyunda olmuyor). Sebep tahtanın TEK SEFERLİK ilk çizimi: 169
  // hücrenin ikişer `MaskFilter.blur`lu iç gölgesi + kartın blur 20/14/60'lık
  // üçlüsü, hepsi route geçişinin ortasında. Kullanıcının seçtiği çözüm
  // tutarlılık: *"Neden bekleyen oyunlar gibi kısa bir yükleniyor
  // çıkartmıyoruz? Her yerde aynı deneyim en azından."*
  // ⚠ IŞKALAMA KURTARMA (24 Ağustos 2026, kullanıcı Android'de bildirdi:
  // taslak taşını geri almaya çalışırken komşu -oynanmış- taşa isabet
  // ediyor). Tahta hücresi ~24 px ve büyütülemez; ama taslak sürerken
  // oynanmış taşlar zaten ölü, o yüzden alanları taslak taşına devredildi.
  group('taslak sürerken oynanmış taşa dokunma', () {
    /// (5,5)'te ONAYLANMIŞ bir taş olan tahta — komşularına taslak konacak.
    GameState oynanmisTasliDurum() {
      final board = createEmptyBoard();
      board[5][5] = const Tile(letter: 'A', pts: 1, owner: 1);
      return craftedState().copyWith(board: board);
    }

    Future<GameController> pump(WidgetTester tester, GameState st) async {
      final controller =
          GameController(words: words, autoPlayAi: false, nowIso: () => '');
      controller.dispatch(ResumeSavedAction(st));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: GameScreen(
            controller: controller, words: words, auth: AuthService.fake()),
      ));
      await tester.pump();
      return controller;
    }

    testWidgets('TEK komşu taslak varsa o geri alınır', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final c = await pump(tester, oynanmisTasliDurum());
      c.dispatch(const SelectTileAction(0));
      c.dispatch(const PlaceTileAction(r: 4, c: 5)); // oynanmışın ÜSTÜ
      await tester.pump();
      expect(c.state.placed.length, 1, reason: 'taslak kurulmalıydı');

      // Kullanıcının ıskaladığı yer: taslağın ALTINDAKİ oynanmış taş.
      await tester.tap(boardCell(5, 5));
      await tester.pumpAndSettle();

      expect(c.state.placed, isEmpty,
          reason: 'komşudaki taslak taşı geri alınmalıydı — ıskalama '
              'kurtarma tam olarak bunun için var');
    });

    testWidgets('İKİ komşu taslak varsa TAHMİN ETMEZ', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final c = await pump(tester, oynanmisTasliDurum());
      c.dispatch(const SelectTileAction(0));
      c.dispatch(const PlaceTileAction(r: 4, c: 5)); // üst
      c.dispatch(const SelectTileAction(1));
      c.dispatch(const PlaceTileAction(r: 6, c: 5)); // alt
      await tester.pump();
      expect(c.state.placed.length, 2);

      // Hücrenin TAM ORTASINA dokunuş: iki aday da eşit uzaklıkta.
      await tester.tap(boardCell(5, 5));
      await tester.pumpAndSettle();

      expect(c.state.placed.length, 2,
          reason: 'belirsizlikte hiçbir taş geri alınmamalı — yanlış taşı '
              'geri almak, hiç tepki vermemekten DAHA kötü');
    });

    testWidgets('BOŞ hücreye dokunmak hâlâ taş koyar (kurtarma bulaşmaz)',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final c = await pump(tester, oynanmisTasliDurum());
      c.dispatch(const SelectTileAction(0));
      c.dispatch(const PlaceTileAction(r: 4, c: 5));
      await tester.pump();

      c.dispatch(const SelectTileAction(0));
      await tester.tap(boardCell(4, 6)); // taslağın YANINDAKİ boş hücre
      await tester.pumpAndSettle();

      expect(c.state.placed.length, 2,
          reason: 'boş hücreler dokunulmadan kalmalı — kelimeyi dizerken bir '
              'sonraki harfi koymak zorlaşmamalı');
    });
  });

  testWidgets('geçiş animasyonu sürerken ekran "Yükleniyor…" gösterir',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final controller =
        GameController(words: words, autoPlayAi: false, nowIso: () => '');
    controller.dispatch(ResumeSavedAction(craftedState()));
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      navigatorKey: nav,
      home: const Scaffold(body: SizedBox.shrink()),
    ));

    unawaited(nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => GameScreen(
          controller: controller, words: words, auth: AuthService.fake()),
    )));
    await tester.pump(); // route eklendi
    await tester.pump(const Duration(milliseconds: 50)); // animasyon ORTASI

    expect(find.text('Yükleniyor…'), findsOneWidget,
        reason: 'geçiş sürerken Canlı oyun ekranıyla aynı yükleme durumu '
            'gösterilmeli');
    expect(find.byType(BoardWidget), findsNothing,
        reason: 'tahta geçiş sırasında HİÇ çizilmemeli — kullanıcının '
            '"takılarak geliyor" dediği kareler tam burada düşüyordu');

    await tester.pumpAndSettle();
    expect(find.byType(BoardWidget), findsOneWidget,
        reason: 'animasyon bitince tahta çizilmeli — yükleme durumu takılı '
            'kalırsa oyun hiç açılmaz');
    expect(find.text('Yükleniyor…'), findsNothing);
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
      theme: kelimekiTheme(),
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: Colors.white,
          child: Center(child: GameOverModal(state: finished, onOpenHistory: () {})),
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
      theme: kelimekiTheme(),
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

  testWidgets(
      'joker seçici web gibi ORTALANMIŞ KModal — 360px kart + 44px taş '
      '(Parça 47: alttan açılan sayfa iPad\'de taşları ~128px\'e şişiriyordu)',
      (tester) async {
    // Geniş yüzey, farkın görünür olduğu yer: bottom sheet ekran genişliğini
    // kaplayıp kare hücreleri devleştiriyordu; web'in kartı 360px sabit.
    await setPhoneViewSize(tester, const Size(1000, 900));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showWildLetterSheet(context),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing,
        reason: 'web ortalanmış Modal kullanıyor, alttan sayfa DEĞİL');
    final card = find.descendant(
      of: find.byType(Dialog),
      matching: find.byWidgetPredicate((w) =>
          w is ConstrainedBox && w.constraints.maxWidth == 360),
    );
    expect(card, findsWidgets, reason: 'web Modal 360px kart');

    // Web `h-11` = 44px sabit yükseklik (kare bir ızgara DEĞİL).
    final tile = tester.getSize(find.byType(TileWidget).first);
    expect(tile.height, 44.0);
    expect(tile.width, lessThan(80),
        reason: '360px kart 6 sütuna bölününce taş ~50px olmalı');
  });

  // Parça 55 — bölge vergisi onayı web'deki gibi VURGULU: kazanılacak puan
  // yeşil, her bölge sahibine giden pay kırmızı, sahibin adı yalnızca kalın
  // (web'de <strong> rengi yok). Port bugüne kadar düz metin basıyordu.
  // Diyalog `game_screen`/`online_game_screen` çiftinin PAYLAŞTIĞI tek
  // fonksiyon olduğundan izole test ikisini birden kapsıyor.
  testWidgets('Sınır İhlali onayı: puan yeşil, vergi payı kırmızı, ad kalın',
      (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    final players = [
      player('Ironman', isAI: false, index: 0, rack: const []),
      player('Esiner', isAI: false, index: 1, rack: const []),
    ];
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showInvasionConfirm(context,
                    score: 24,
                    shares: const [InvasionShare(index: 1, amount: 8)],
                    players: players);
              },
              child: const Text('AÇ'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('AÇ'));
    await tester.pumpAndSettle();

    final rich = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null));
    final spans = <TextSpan>[];
    rich.textSpan!.visitChildren((s) {
      if (s is TextSpan && s.text != null) spans.add(s);
      return true;
    });
    String plain = spans.map((s) => s.text).join();
    expect(plain,
        'Bu hamleden kazanacağın 24 puanın 8 puanı Esiner kullanıcısına vergi olarak gidecek.');

    TextSpan spanOf(String text) => spans.firstWhere((s) => s.text == text);
    expect(spanOf('24').style!.color, kGreen);
    expect(spanOf('24').style!.fontWeight, FontWeight.bold);
    expect(spanOf('8').style!.color, kRed);
    expect(spanOf('8').style!.fontWeight, FontWeight.bold);
    // Ad KALIN ama renksiz — web'de <strong> class taşımıyor.
    expect(spanOf('Esiner').style!.fontWeight, FontWeight.bold);
    expect(spanOf('Esiner').style!.color, isNull);

    await tester.tap(find.text('VAZGEÇ'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  // Parça 57 — tahta ↔ mesaj ↔ raf dikey boşlukları. Web'de ölçüldü
  // (derlenmiş CSS + Chromium): tahta kartının ALTI ile mesaj arası 16px
  // (Board.tsx sarmalayıcısının `pb-3`ü + mesaj kabının `pt-1`i), mesaj ile
  // raf satırı arası 6px (`gap-1.5`). Parça 39'da yalnızca `pt-1`i görüp
  // "tek boşluk 4px" demiştim — Board'un kendi `pb-3`ü gözden kaçmıştı, o
  // yüzden app'te tahta mesaja yapışık duruyordu (kullanıcı bildirdi).
  testWidgets('tahta ↔ mesaj ↔ raf boşlukları web ile aynı', (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    final c = GameController(words: words, autoPlayAi: false)
      ..restore(craftedState());
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(controller: c, words: words),
    ));
    await tester.pumpAndSettle();

    // Tahta KARTI (BoardWidget'ın kendi Container'ı) — sarmalayıcı Padding
    // değil, kartın kendisi ölçülüyor.
    final board = tester.getRect(find.byType(BoardWidget));
    final msg = tester.getRect(find.byKey(const ValueKey('message-line')));
    final rack = tester.getRect(find.byType(RackWidget));

    expect(msg.top - board.bottom, closeTo(16, 0.5),
        reason: 'web: Board pb-3 (12) + mesaj kabının pt-1i (4)');
    expect(rack.top - msg.bottom, closeTo(6, 0.5),
        reason: 'web: kabın gap-1.5i');
  });

  testWidgets(
      'boş taslakta OYNA/GERİ AL AKTİF ve OYNA "Harf yerleştirilmedi." der '
      '(web: disabled={!canAct} — placed.isEmpty koşulu YOK)', (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    final controller = await pumpGame(tester, GlobalKey());

    // Hiç taş yerleştirilmemişken ikisi de tıklanabilir olmalı. Butonu
    // kapatmak, motorun TAM BU DURUM için taşıdığı "Harf yerleştirilmedi."
    // mesajını (validator.dart:57) ulaşılamaz kılıyordu — sebebi hiçbir
    // yerde yazmayan sessiz bir ret.
    expect(controller.state.placed, isEmpty);
    final turnBefore = controller.state.turnCount;
    expect(
      tester.widget<NeoButton>(find.widgetWithText(NeoButton, 'OYNA')).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<NeoButton>(find.widgetWithText(NeoButton, 'GERİ AL'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('OYNA'));
    await tester.pumpAndSettle();
    expect(find.text('Harf yerleştirilmedi.'), findsOneWidget);
    // Hamle işlenmemeli — sıra hâlâ bende.
    expect(controller.state.turnCount, turnBefore);
  });

  // 14 Ağustos 2026 (kullanıcı isteği): tahtanın alt şeridindeki X2/X3
  // legend'ı kalktı, yerine "Hamleler"/"Mesajlaşma" ile AYNI stilde bir
  // "Nasıl Oynanır?" linki geldi. Legend'ın taşıdığı bilgi kaybolmuyor —
  // bonus renkleri tahtada zaten büyük filigranlarla yazılı.
  testWidgets('board alt şeridi: X2/X3 legend YOK, "Nasıl Oynanır?" VAR ve '
      'kurallar modalını açıyor', (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());

    // Legend metinleri tamamen kalkmalı. Çıplak 'X2' aranmıyor: tahtanın
    // KENDİSİ bonus bölgesinin arkasına büyük bir "X2" filigranı yazıyor
    // ve o DURUYOR — aranan şey legend satırının açıklama metni.
    expect(find.text('- kelime X2'), findsNothing);
    expect(find.text('- kelime X3'), findsNothing);

    expect(find.text('Nasıl Oynanır?'), findsOneWidget);
    await tester.tap(find.text('Nasıl Oynanır?'));
    await tester.pumpAndSettle();
    // HelpModal açıldı mı — varsayılan adımı "Hızlı Başlangıç"
    // (başlık KModal'dan geçtiği için trUpper).
    expect(find.text('HIZLI BAŞLANGIÇ'), findsOneWidget);
  });

  testWidgets(
      'tahtanın BİR boyaması ~340 blur DEĞİL — nömorfik dekor raster '
      'önbelleğinden basılıyor (bkz. neo_box.dart "PERFORMANS SÖZLEŞMESİ")',
      (tester) async {
    // 26 Ağustos 2026, ÜÇÜNCÜ tur. İlk iki teşhis DOLAYLI göstergeye baktı
    // (önce `build` sayısı, sonra `RepaintBoundary`in simetrik boyama
    // sayacı); ikisi de "iyi" derken cihaz ağır çekimdi ve kullanıcı
    // *"Board alanında her şey ağır"* dedi — yalnız sürükleme değil, geri
    // tuşu ve modal açılışı da. Yani sorun tahtanın NE KADAR SIK
    // boyandığı değil, BİR boyamanın ne kadar pahalı olduğuydu.
    //
    // Bu test tam onu ölçüyor: tahta bir kez boyandığında kaç GERÇEK
    // `MaskFilter.blur` çiziliyor. Önbellekten ÖNCE bu sayı ~340'tı
    // (169 hücre × 2 iç gölge + kartların dış gölgeleri); önbellekten
    // sonra yalnızca AYIRT EDİCİ desen sayısı kadar olmalı (boş kare,
    // altın bölge, merkez, oyuncu tonları, raf taşı, butonlar…).
    debugResetNeoBoxCacheForTests();
    final blurBefore = debugBlurPaintCountForTests;
    final blitBefore = debugCachedBlitCountForTests;
    await setPhoneViewSize(tester, const Size(420, 900));
    await pumpGame(tester, GlobalKey());
    await tester.pump();
    final blurIlkBoyama = debugBlurPaintCountForTests - blurBefore;
    final blitIlkBoyama = debugCachedBlitCountForTests - blitBefore;
    // ignore: avoid_print
    print('[ÖLÇÜM] ilk boyama — blur: $blurIlkBoyama, '
        'önbellekten blit: $blitIlkBoyama');

    // ARACIN CANLI OLDUĞUNU ÖNCE KANITLA. `toImageSync` bu ortamda
    // desteklenmiyorsa `neo_box` bilinçli olarak DOĞRUDAN çizime düşer
    // (görüntü asla bozulmaz) — o durumda aşağıdaki iddia bir şey
    // kanıtlamaz, o yüzden testi sessizce geçirmek yerine burada dururuz.
    expect(blitIlkBoyama, greaterThan(100),
        reason: 'tahtanın 169 hücresi önbellekten basılmadı ($blitIlkBoyama '
            'blit) — raster önbelleği bu ortamda devrede değil, dolayısıyla '
            'aşağıdaki ölçüm hiçbir şey kanıtlamaz.');

    expect(blurIlkBoyama, lessThan(80),
        reason: 'ekranın tek boyaması $blurIlkBoyama blur çizdi — önbellek '
            'delinmiş demektir (anahtar her hücrede farklı olabilir). '
            'Düzeltmeden ÖNCEKİ değer ~340 idi; şimdiki sayı yalnızca '
            'AYIRT EDİCİ desenlerin bir kerelik rasterleştirmesi + '
            'önbelleğe alınmayan BÜYÜK yüzeyler olmalı.');

    // İKİNCİ boyama SIFIR blur etmeli: desenler artık önbellekte.
    final blurIkinciOncesi = debugBlurPaintCountForTests;
    tester.renderObject(find.byType(BoardWidget)).markNeedsPaint();
    await tester.pump();
    // ignore: avoid_print
    print('[ÖLÇÜM] ikinci boyama — blur: '
        '${debugBlurPaintCountForTests - blurIkinciOncesi}');
    // SIFIR değil, KÜÇÜK bekleniyor: tahta KARTININ kendisi (≈690×730 dp,
    // blur 60) tek bir girdi için piksel sınırını aştığından bilinçli olarak
    // önbelleğe ALINMIYOR — ama onun gölgeleri basit bir RRect üzerinde,
    // yani Impeller'ın analitik hızlı yolunda; pahalı olan, keyfi bir PATH
    // üzerine uygulanan iç gölgelerdi (hücreler). Bu iddia onların geri
    // gelmediğini bekliyor.
    expect(debugBlurPaintCountForTests - blurIkinciOncesi, lessThan(20),
        reason: 'tahta yeniden boyandığında '
            '${debugBlurPaintCountForTests - blurIkinciOncesi} blur çizildi — '
            'önbellek ıskalanıyor (boyut/anahtar her karede değişiyor '
            'olabilir).');
  });
}
