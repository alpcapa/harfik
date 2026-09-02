// Tahta yakınlaştırması (1.0.5) — board_zoom.dart + game_screen entegrasyonu.
//
// Kullanıcının şartı: *"Zoom halindeyken taş sürükleme bırakma, tek tıkla
// taş koyma/geri alma, vb mükemmel çalışmalı."* + (1 Eylül 2026 düzeltmesi)
// *"taşı geri almadan, koyduğu yerde bırakarak zoomlamak lazım"* — çiftin
// İKİNCİ dokunuşu yutulur, İLKİNİN yaptığı iş (koyulan taş dahil) KALIR;
// geri sarma mekanizması YOK. Bu dosya o şartın widget testine dökülebilen
// her parçasını kilitliyor; cihazda kalanlar mobile/TESTING.md'de.
//
// EN KRİTİK İDDİA (analizden): zoom bir ÇİZİM MATRİSİ olduğundan
// `RenderBox.globalToLocal` onu kendiliğinden tersine çevirir ve ekranların
// stride/hücre matematiği değişmeden doğru kalır. Bu dosyadaki "zoom'luyken
// sürükle-bırak doğru hücreye iner" testi o iddianın KANITI — iddia doğru
// değilse taş yanlış hücreye iner ve test düşer.
//
// Fikstür `game_screen_test.dart`tan (rack_index_race_test'in kurduğu
// desen): aynı durumun iki kopyası üretilmesin.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/board_zoom.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'game_screen_test.dart' show craftedState, rackTile, boardCell;
import 'support/test_view.dart';

Future<GameController> pumpZoomGame(WidgetTester tester) async {
  await setPhoneViewSize(tester, const Size(420, 900));
  final words = SetWordSource(const ['ab', 'aba', 'kelime']);
  final controller =
      GameController(words: words, autoPlayAi: false, nowIso: () => '');
  controller.dispatch(ResumeSavedAction(craftedState()));
  await tester.pumpWidget(MaterialApp(
    theme: kelimekiTheme(),
    home: GameScreen(
        controller: controller, words: words, auth: AuthService.fake()),
  ));
  await tester.pump();
  return controller;
}

Matrix4 zoomMatrix(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('board-zoom-transform')))
    .transform;

bool isZoomedIn(WidgetTester tester) =>
    zoomMatrix(tester).getMaxScaleOnAxis() > 1.5;

/// Çift dokunuş: aynı noktaya, pencere İÇİNDE iki dokunuş. `tester.pump`
/// sahte saati ilerlettiğinden (board_zoom `clock.now()` kullanıyor — bkz.
/// pubspec'teki `clock` gerekçesi) aradaki süre deterministik.
Future<void> doubleTapAt(WidgetTester tester, Offset pos) async {
  await tester.tapAt(pos);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(pos);
  // Çift dokunuş penceresi + ertelenmiş işler kapansın.
  await tester.pump(kDoubleTapWindow + const Duration(milliseconds: 50));
  // Aç/kapa animasyonu (180 ms) yukarıdaki KAREDE t=0'dan başlar
  // (TweenAnimationBuilder hedefi o karede değişir) — bitmesi için ayrıca
  // ilerletmek şart; tek pump t=100'de kalıyordu (ölçüldü: scale 1.0924).
  await tester.pump(kZoomAnimDuration + const Duration(milliseconds: 20));
  await tester.pump();
}

/// Portun `_badgeClipSlack`i private; test kendi kopyasını taşıyor ve
/// ikisi ayrışırsa yukarıdaki ölçüm iddiası düşer.
const double _badgeClipSlackTest = 14;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Denetleyici birim testleri (saf matematik) ────────────────────────

  test('clamp: ölçekli içerik görünür kareyi her zaman kaplar', () {
    final c = BoardZoomController();
    const grid = Size(300, 300);
    c.toggleAt(const Offset(150, 150), grid);
    // Merkez odak: o = 150·(1−2) = −150 — sınır içinde.
    expect(c.offset, const Offset(-150, -150));
    // Aşırı pan sınırda durur: [-300, 0] aralığı dışına çıkamaz.
    c.panBy(const Offset(-9999, 9999), grid);
    expect(c.offset, const Offset(-300, 0));
    c.panBy(const Offset(9999, -9999), grid);
    expect(c.offset, const Offset(0, -300));
  });

  test('köşe odaklı toggle clamp edilir; kapatma offset sıfırlar', () {
    final c = BoardZoomController();
    const grid = Size(300, 300);
    c.toggleAt(Offset.zero, grid); // sol üst köşe: o = 0 (clamp üstü)
    expect(c.zoomed, isTrue);
    expect(c.offset, Offset.zero);
    c.toggleAt(const Offset(300, 300), grid);
    expect(c.zoomed, isFalse);
    expect(c.offset, Offset.zero);
  });

  test('çift dokunuş algılayıcısı: pencere ve yarıçap sınırları', () {
    final c = BoardZoomController();
    var t = DateTime(2026, 9, 1, 12);
    DateTime now() => t;
    withClock(Clock(now), () {
      // Eşleşebilir bir ilk dokunuş (boş kare).
      expect(c.tryCompletePair(const Offset(100, 100)), isFalse);
      c.registerPairableTap(const Offset(100, 100));
      // Pencere içi + yakın → çift.
      t = t.add(const Duration(milliseconds: 200));
      expect(c.tryCompletePair(const Offset(120, 110)), isTrue);

      // Çift, izi TÜKETİR: hemen üçüncü bir dokunuş yeni bir ilk dokunuştur.
      expect(c.tryCompletePair(const Offset(120, 110)), isFalse);
      c.registerPairableTap(const Offset(120, 110));

      // Pencere DIŞI → çift değil.
      t = t.add(const Duration(milliseconds: 301));
      expect(c.tryCompletePair(const Offset(120, 110)), isFalse);
      c.registerPairableTap(const Offset(120, 110));

      // Yarıçap dışı → çift değil (iz hâlâ duruyor: tüketmedi).
      t = t.add(const Duration(milliseconds: 100));
      expect(c.tryCompletePair(const Offset(200, 110)), isFalse);

      // Eşleşemez etkileşim (taşa dokunuş/raf/sürükleme) zinciri kırar.
      c.registerPairableTap(const Offset(200, 110));
      c.markUnpairableTap();
      t = t.add(const Duration(milliseconds: 100));
      expect(c.tryCompletePair(const Offset(200, 110)), isFalse);
    });
  });

  // ── Ekran entegrasyonu ────────────────────────────────────────────────

  testWidgets('boş kareye çift dokunuş zoom açar, tekrarı kapatır',
      (tester) async {
    await pumpZoomGame(tester);
    expect(isZoomedIn(tester), isFalse);

    final p = tester.getCenter(boardCell(6, 6));
    await doubleTapAt(tester, p);
    expect(isZoomedIn(tester), isTrue,
        reason: 'çift dokunuş ölçek ~2.0 uygulamalı');

    // Kapatma: yine boş bir noktaya çift dokunuş (zoom'lu ekranda da boş
    // kareler var — merkez civarı).
    await doubleTapAt(tester, tester.getCenter(boardCell(6, 6)));
    expect(isZoomedIn(tester), isFalse);
    expect(zoomMatrix(tester), equals(Matrix4.identity()));
  });

  testWidgets('TEK dokunuş anında çalışır — koyma gecikmesiz', (tester) async {
    final controller = await pumpZoomGame(tester);
    await tester.tap(rackTile(0)); // K
    await tester.pump();
    await tester.tap(boardCell(5, 5));
    await tester.pump(); // EK süre YOK — hemen konmuş olmalı
    expect(controller.state.placed['5,5'], isNotNull,
        reason: 'tek dokunuş koyma ertelenemez (kullanıcı şartı)');
  });

  testWidgets(
      'harf seçiliyken çift dokunuş: taş KONUR ve KONDUĞU YERDE KALIR, '
      'zoom açılır — kullanıcı kararı: "taşı geri almadan, koyduğu yerde '
      'bırakarak zoomlamak lazım" (1 Eylül 2026)',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    await tester.tap(rackTile(0)); // K seçili
    await tester.pump();
    expect(controller.state.selectedTile, 0);

    // tap1 taşı koyar (hücre artık taslak); tap2 aynı noktaya düşer ve
    // taşı GERİ ALMAK yerine yutulup zoom'u açar.
    await doubleTapAt(tester, tester.getCenter(boardCell(5, 5)));

    expect(isZoomedIn(tester), isTrue);
    expect(controller.state.placed['5,5'], isNotNull,
        reason: 'tap1\'in koyduğu taş yerinde kalmalı');
    expect(controller.state.placed, hasLength(1));
    expect(controller.state.players[0].rack, hasLength(6));
  });

  testWidgets(
      'kullanıcının birebir senaryosu: BİRDEN FAZLA taş koy, BAŞKA boş bir '
      'kareye çift dokun — taşların HEPSİ yerinde kalır, zoom açılır',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    await tester.tap(rackTile(0)); // K
    await tester.pump();
    await tester.tap(boardCell(5, 5));
    await tester.pump(const Duration(milliseconds: 400)); // ayrı bir jest
    await tester.tap(rackTile(0)); // E (K düşünce raf kaydı)
    await tester.pump();
    await tester.tap(boardCell(5, 6));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.state.placed.keys.toSet(), {'5,5', '5,6'});

    await doubleTapAt(tester, tester.getCenter(boardCell(8, 8)));

    expect(isZoomedIn(tester), isTrue);
    expect(controller.state.placed.keys.toSet(), {'5,5', '5,6'},
        reason: 'çift dokunuş koyulmuş taşların HİÇBİRİNE dokunmaz');
    expect(controller.state.players[0].rack, hasLength(5));

    // Kapatma çift dokunuşu da taşlara dokunmaz.
    await doubleTapAt(tester, tester.getCenter(boardCell(8, 8)));
    expect(isZoomedIn(tester), isFalse);
    expect(controller.state.placed.keys.toSet(), {'5,5', '5,6'});
  });

  testWidgets(
      'taslak taşa çift dokunuş ZOOM AÇMAZ: tap1 normal geri alma, taşa '
      'dokunuş çift BAŞLATAMAZ (çift yalnızca boş kare jesti)',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    await tester.tap(rackTile(0)); // K
    await tester.pump();
    await tester.tap(boardCell(5, 5));
    await tester.pump(const Duration(milliseconds: 400)); // ayrı bir jest
    expect(controller.state.placed['5,5'], isNotNull);

    await doubleTapAt(tester, tester.getCenter(boardCell(5, 5)));
    expect(controller.state.placed, isEmpty,
        reason: 'tap1 tek dokunuş davranışıyla geri aldı');
    expect(controller.state.players[0].rack, hasLength(7));
    expect(isZoomedIn(tester), isFalse,
        reason: 'taşa dokunuş çift başlatamaz; tap2 boş kareye düşen yeni '
            'bir İLK dokunuştur');
  });

  testWidgets(
      'JOKER akışının zoom\'la İLİŞKİSİ YOK: pencere tek dokunuşta ANINDA '
      'açılır, zoom açılmaz (kullanıcı kararı, 1 Eylül 2026)',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    await tester.tap(rackTile(6)); // '?'
    await tester.pump();
    await tester.tap(boardCell(5, 5));
    await tester.pump(); // EK süre YOK — pencere hemen açılmış olmalı
    await tester.pump(); // sheet animasyon karesi
    expect(find.text('JOKER HANGİ HARF OLSUN?'), findsOneWidget,
        reason: 'joker penceresi ertelenemez — eski davranış birebir');
    expect(isZoomedIn(tester), isFalse);
    // Harf seçimi normal tamamlanır.
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').first);
    await tester.pumpAndSettle();
    expect(controller.state.placed['5,5']?.wild, isTrue);
    expect(isZoomedIn(tester), isFalse,
        reason: 'joker akışının hiçbir adımı zoom\'u değiştirmez');
  });

  testWidgets('onaylı taş kapsam DIŞI: çift dokunuş zoom açmaz',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    // (0,0)'a onaylı bir taş koy (tahtada, taslakta değil).
    final st = controller.state;
    final board = [
      for (final row in st.board) [...row],
    ];
    board[0][0] = const Tile(letter: 'A', pts: 1, owner: 1);
    controller.dispatch(ResumeSavedAction(st.copyWith(board: board)));
    await tester.pump();
    // Taslak aktifken onaylı taşa dokunuş sessizce yutulur (anlam penceresi
    // açılmaz) — çift dokunuşun modal'a takılmadan sınanabildiği durum.
    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(5, 5)); // taslak kur
    await tester.pump(const Duration(milliseconds: 400));
    await doubleTapAt(tester, tester.getCenter(boardCell(0, 0)));
    expect(isZoomedIn(tester), isFalse,
        reason: 'onaylı taşlar zoom kapsamı dışında');
  });

  testWidgets(
      'ZOOM AÇIKKEN sürükle-bırak doğru hücreye iner — stride matematiği '
      'transform altında değişmeden doğru (analizin kritik iddiası)',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    // Sol üste odaklı zoom (0,0 civarı görünür kalsın).
    await doubleTapAt(tester, tester.getCenter(boardCell(1, 1)));
    expect(isZoomedIn(tester), isTrue);

    // Raftaki K'yi zoom'lu tahtada (2,2)'ye sürükle. `getCenter` transform
    // SONRASI ekran konumunu verir — parmağın gerçekte gideceği nokta.
    // Bırakma noktası 30 px KALDIRILDIĞINDAN (DRAG_LIFT) parmak hedefin 30
    // px altına gider.
    final from = tester.getCenter(rackTile(0));
    final to = tester.getCenter(boardCell(2, 2)) + const Offset(0, 30);
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 20));
    // Eşik (10 px) aşılıp hayalet belirsin diye ara adım.
    await g.moveTo(from + const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveTo(to);
    await tester.pump(const Duration(milliseconds: 20));
    await g.up();
    await tester.pump();

    expect(controller.state.placed['2,2'], isNotNull,
        reason: 'zoom altında bırakılan taş NİŞAN ALINAN hücreye inmeli');
    expect(controller.state.placed, hasLength(1));
  });

  testWidgets(
      'ZOOM AÇIKKEN taslak taşı RAFA sürüklemek geri alır — görünür kare '
      'kapısı: raf üstündeki nokta "görünmez hücre"ye sayılmaz',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    // Taslak kur (zoom kapalıyken, basitlik).
    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(1, 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.state.placed['1,1'], isNotNull);

    // Sol üst KÖŞE odaklı zoom (0,0): offset ~-14 px → (1,1) görünür
    // KALIR ve rafın üstü ters transformda hâlâ ızgara SINIRLARI İÇİNE
    // düşer — kapı yoksa tuzağın gerçekleştiği durum bu. (3,3) odağı
    // OLMAZ: offset -96 px, (1,1)'in merkezi görünür karenin soluna
    // taşıyor (ölçüldü: LTRB(-13.6, 62.4, ...)), dokunuş taşı tutamıyor.
    await doubleTapAt(tester, tester.getCenter(boardCell(0, 0)));
    expect(isZoomedIn(tester), isTrue);

    final from = tester.getCenter(boardCell(1, 1));
    final to = tester.getCenter(rackTile(3));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveTo(from + const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveTo(to);
    await tester.pump(const Duration(milliseconds: 20));
    await g.up();
    await tester.pump();

    expect(controller.state.placed, isEmpty,
        reason: 'rafa bırakılan taslak GERİ ALINMALI, gizli hücreye inmemeli');
    expect(controller.state.players[0].rack, hasLength(7));
  });

  // ── Kenarlar/boşluklar (1 Eylül 2026, APK'dan gelen iki bulgu) ────────

  testWidgets(
      'ÇERÇEVEDEN (ızgara dışı, dolgu içi) çift dokunuş zoom açar — '
      '"kenarlar da zoom\'a dahil olmalı"', (tester) async {
    final controller = await pumpZoomGame(tester);
    // Hücre (0,0) kutusunun 6 px sol-üstü: ızgaranın DIŞI, 10 px'lik
    // dolgunun İÇİ. Eski yapıda burada hiçbir dinleyici yoktu.
    final p0 = tester.getRect(boardCell(0, 0)).topLeft - const Offset(6, 6);
    await doubleTapAt(tester, p0);
    expect(isZoomedIn(tester), isTrue,
        reason: 'tahtanın çerçevesi de çift dokunuş yüzeyi olmalı');
    // Kapatma da çerçeveden çalışır.
    await doubleTapAt(tester, p0);
    expect(isZoomedIn(tester), isFalse);
    expect(controller.state.placed, isEmpty);
  });

  testWidgets('hücre ARALIĞINA (boşluk) çift dokunuş zoom açar',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    final sol = tester.getRect(boardCell(6, 6));
    final sag = tester.getRect(boardCell(6, 7));
    // İki hücre kutusunun tam arası — 3 px'lik boşluğun ortası.
    final gap = Offset((sol.right + sag.left) / 2, sol.center.dy);
    expect(sag.left - sol.right, closeTo(3.0, 0.6),
        reason: 'boşluk 3 px değilse bu test yanlış noktayı ölçüyor');
    await doubleTapAt(tester, gap);
    expect(isZoomedIn(tester), isTrue,
        reason: 'hücreler arası boşluk da çift dokunuş yüzeyi olmalı');
    expect(controller.state.placed, isEmpty);
  });

  testWidgets(
      'boşluğa/çerçeveye TEK dokunuş hiçbir şey yapmaz — harf seçiliyken '
      'bile (taş konmaz, seçim düşmez)', (tester) async {
    final controller = await pumpZoomGame(tester);
    await tester.tap(rackTile(0)); // K seçili
    await tester.pump();
    final sol = tester.getRect(boardCell(6, 6));
    final sag = tester.getRect(boardCell(6, 7));
    await tester.tapAt(Offset((sol.right + sag.left) / 2, sol.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    await tester
        .tapAt(tester.getRect(boardCell(0, 0)).topLeft - const Offset(6, 6));
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.state.placed, isEmpty);
    expect(controller.state.selectedTile, 0, reason: 'seçim korunmalı');
    expect(isZoomedIn(tester), isFalse);
  });

  testWidgets(
      'hücreye inen dokunuş tahta dinleyicisinde SAYILMAZ (çift kayıt '
      'olsaydı tek dokunuş zoom açardı)', (tester) async {
    final controller = await pumpZoomGame(tester);
    // Boş hücreye TEK dokunuş: hem hücre GestureDetector'ı hem tahta
    // Listener'ı aynı jesti görür — yalnızca BİRİ kaydetmeli, yoksa
    // ikinci kayıt ilkiyle "çift" oluşturup zoom'u anında açar.
    await tester.tap(boardCell(6, 6));
    await tester.pump();
    expect(isZoomedIn(tester), isFalse,
        reason: 'tek dokunuş çift sayılmış: aynı jest iki kez kaydedilmiş');
    expect(controller.state.placed, isEmpty);
  });

  testWidgets(
      'görünür karenin kırpma payı bölge çizgisinin taşmasını kapsar — '
      '"bölge çizgisi kenarlarda inceliyor" düzeltmesi', (tester) async {
    await pumpZoomGame(tester);
    final clip = tester.widget<ClipRect>(find.byWidgetPredicate(
        (w) => w is ClipRect && w.clipper != null));
    final r = clip.clipper!.getClip(const Size(100, 100));
    // Dış hat stroke'u (2.5) yolun merkezinde: kutu dışına yarım kalınlık,
    // zoom'da ×2 → 2.5 px taşar. Pay bunu (+AA) kapsamalı, yoksa kenardaki
    // çizgi yarıya iner (kullanıcı cihazda gördü).
    const beklenenTasma = 2.5;
    expect(r.left, lessThanOrEqualTo(-beklenenTasma));
    expect(r.top, lessThanOrEqualTo(-beklenenTasma));
    expect(r.right, greaterThanOrEqualTo(100 + beklenenTasma));
    expect(r.bottom, greaterThanOrEqualTo(100 + beklenenTasma));
  });

  testWidgets(
      'hamle puanı rozeti KIRPILMAZ — kenardaki rozet kesilmesin '
      '(1 Eylül 2026, kullanıcı APK\'da bildirdi)', (tester) async {
    final controller = await pumpZoomGame(tester);
    // Sol ÜST köşedeki hücreye taş koy: rozet o hücrenin sol üstüne
    // (-0.35,-0.35) taşar, yani ızgara kutusunun DIŞINA çıkar. Kırpılan
    // katmanda kalsaydı sol kenarı kesilirdi.
    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(0, 0));
    await tester.pump();

    final rozet = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('+'));
    expect(rozet, findsOneWidget, reason: 'hamle rozeti hiç çizilmemiş');

    // ⚠ İDDİA 2 Eylül 2026'da DEĞİŞTİ. Önceden "rozetin üstünde kırpıcılı
    // ClipRect OLMAMALI" diyordu; o tasarım rozeti zoom'da tahtanın DIŞINA
    // (rafın üstüne) çizdiriyordu ve web ikizinde kullanıcı bildirdi.
    // Yeni tasarım: rozetin KENDİ, daha geniş payı olan bir klibi var.
    // 1 Eylül'ün derdi (kenardaki rozet kesilmesin) böylece korunuyor —
    // kanıtı aşağıdaki ÖLÇÜM, yapı değil.
    final klip = find.ancestor(
        of: rozet,
        matching:
            find.byWidgetPredicate((w) => w is ClipRect && w.clipper != null));
    expect(klip, findsOneWidget,
        reason: 'rozet katmanının kendi klibi olmalı');

    // Rozet gerçekten ızgaranın dışına taşıyor (fikstür bunu kurmazsa test
    // hiçbir şey kanıtlamaz) AMA klip payının içinde kalıyor, yani
    // KESİLMİYOR.
    final grid = tester.getRect(boardCell(0, 0));
    final rRect = tester.getRect(rozet);
    expect(rRect.left, lessThan(grid.left),
        reason: 'rozet ızgara kutusunun dışına taşmıyorsa kırpma da '
            'sorun olmazdı — fikstür kurulumu bozulmuş');
    final klipKutu = tester.getRect(klip);
    expect(rRect.left, greaterThanOrEqualTo(klipKutu.left - _badgeClipSlackTest),
        reason: 'rozet payın DIŞINA taşmış — dinlenme hâlinde kesilir');
    expect(rRect.top, greaterThanOrEqualTo(klipKutu.top - _badgeClipSlackTest),
        reason: 'rozet payın DIŞINA taşmış — dinlenme hâlinde kesilir');

    // ⚠ ZOOM AÇIKKEN DE KIRPILIR — asıl kazanç bu.
    // Önceden "zoom'da da kırpılmamalı" diyordu ve eski (hatalı) tasarımı
    // kilitliyordu: rozet zoom matrisini izleyip hiç kırpılmayınca, hedef
    // hücre görünür kareden çıktığında rozet tahtanın DIŞINA (rafın üstüne)
    // çiziliyordu. Web ikizinde bir kullanıcı bildirdi ve orada ölçüldü:
    // görünür kare y=55/h=366 iken rozet y=-300.
    // Klip her iki hâlde de var; 1 Eylül'ün "kesilmesin" derdi payın
    // ölçülmüş genişliğiyle korunuyor (yukarıdaki iddia).
    await doubleTapAt(tester, tester.getCenter(boardCell(6, 6)));
    expect(isZoomedIn(tester), isTrue);
    expect(
      find.ancestor(
          of: rozet,
          matching: find.byWidgetPredicate(
              (w) => w is ClipRect && w.clipper != null)),
      findsOneWidget,
      reason: 'zoom açıkken rozet katmanı KENDİ payıyla kırpılmalı — yoksa '
          'hücresi görünür kareden çıkınca tahtanın dışına çizilir',
    );
    expect(controller.state.placed, hasLength(1));
  });

  testWidgets('pan: zoom açıkken parmak tahtayı kaydırır ve sınırda durur',
      (tester) async {
    final controller = await pumpZoomGame(tester);
    await doubleTapAt(tester, tester.getCenter(boardCell(6, 6)));
    expect(isZoomedIn(tester), isTrue);
    final before = zoomMatrix(tester).getTranslation();

    // Boş bir alandan sürükle (taş yok → pan).
    final start = tester.getCenter(boardCell(6, 6));
    final g = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveBy(const Offset(60, 40));
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveBy(const Offset(60, 40));
    await tester.pump(const Duration(milliseconds: 20));
    await g.up();
    await tester.pump(const Duration(milliseconds: 200));

    final after = zoomMatrix(tester).getTranslation();
    expect(after.x, greaterThan(before.x));
    expect(after.y, greaterThan(before.y));
    // Sınır: offset hiçbir eksende 0'ı aşamaz.
    expect(after.x, lessThanOrEqualTo(0.0));
    expect(after.y, lessThanOrEqualTo(0.0));
    // Pan bir hücre işlemi DEĞİL: hiçbir taş konmadı/geri alınmadı.
    expect(controller.state.placed, isEmpty);

    // Pan zoom'u kapatmaz.
    expect(isZoomedIn(tester), isTrue);
  });

  testWidgets('zoom kapalıyken pan YOK — tahta kımıldamaz', (tester) async {
    await pumpZoomGame(tester);
    final start = tester.getCenter(boardCell(6, 6));
    final g = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    await g.moveBy(const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await g.up();
    await tester.pump();
    expect(zoomMatrix(tester), equals(Matrix4.identity()));
  });
}
