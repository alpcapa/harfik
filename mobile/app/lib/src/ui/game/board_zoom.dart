// Kelimeki app — tahta yakınlaştırma (çift dokunuş + pan), ROADMAP 1.0.5.
//
// Testçi isteği (26 Ağustos 2026, product-backlog kaydı): *"Kelimelik'te
// board'a çift tıklama zoom yapıyor, tekrar çift tık geri zoom yapıyor."*
// Kullanıcı kararı (1 Eylül 2026): yalnızca tahtanın İÇİ büyür, diğer tüm
// alanlar sabit kalır; zoom'luyken tahta parmakla kaydırılır; taş koyma/
// geri alma/sürükleme zoom'luyken kusursuz çalışmalı.
//
// ── TASARIMIN ÜÇ DİREĞİ ──────────────────────────────────────────────────
//
// 1. **Zoom bir LAYOUT değişikliği DEĞİL, bir çizim matrisi** (`Transform`).
//    Bu sayede `RenderBox.globalToLocal` transformu kendiliğinden tersine
//    çevirdiğinden ekranlardaki stride/hücre matematiği (`_cellAtGlobal`,
//    `_nearbyDraftCell`) DEĞİŞMEDEN doğru kalıyor — `board_zoom_test.dart`
//    bunu kanıtlıyor. Tahtanın dış çerçevesi/kartı sabit; taşan içerik
//    `ClipRect` ile kırpılır.
//
// 2. **Tek dokunuşlar ANINDA ve AYNEN çalışır; ilk dokunuşun yaptığı iş
//    KALIR.** Flutter'ın `onDoubleTap`'i kullanılMIYOR: aynı hedefe
//    takılınca her tek dokunuşa ~300 ms bekleme ekler — bu projenin en çok
//    savaştığı şey tam da dokunuş hissi. Bunun yerine ilk dokunuş normal
//    işini yapar (harf seçiliyse taş KONUR ve KONDUĞU YERDE KALIR —
//    kullanıcı kararı, 1 Eylül 2026: *"taşı geri almadan, koyduğu yerde
//    bırakarak zoomlamak lazım"*); pencere içinde ikincisi gelirse YALNIZCA
//    ikincisinin hücre işlemi yutulur ve zoom açılır/kapanır. İlk sürümdeki
//    "ilkini geri sar" (ZoomTapEffect) mekanizması bu kararla SİLİNDİ —
//    geri sarma hem gereksizdi hem de kullanıcının koyduğu taşı yutuyordu.
//    Çift, yalnızca BOŞ KAREYE yapılan bir dokunuşla başlar (aşağıdaki
//    registerPairableTap çağrı yerleri); taslak taşa dokunuş (geri alma)
//    ve onaylı taşa dokunuş (anlam penceresi) çift BAŞLATMAZ ama İKİNCİ
//    dokunuş olarak yutulabilir — ilk dokunuş taşı koyduysa parmağın
//    altındaki hücre artık boş değildir, ikinci vuruş o taşı GERİ ALMASIN.
//    Joker akışının zoom'la HİÇBİR İLİŞKİSİ YOK (kullanıcı, aynı gün):
//    harf seçim penceresi eskisi gibi ANINDA açılır; pencere açıkken
//    gelen ikinci dokunuş zaten tahtaya değil pencereye/perdeye düşer.
//
// 3. **Pan, jest arenasına GİRMEZ.** Taş sürükleme ham `Listener` +
//    elle eşik deseniyle çalışıyor (web setPointerCapture eşleniği) ve pan
//    da aynı dile uyar: tahta sarmalayıcısındaki Listener, çocuk taş
//    Listener'ı aynı pointer-down'da `_dragRef`i doldurmuşsa (hit-test
//    sırası çocuk → ata) pan'e hiç başlamaz. `InteractiveViewer` YOK.
//
// İki oyun ekranı (game_screen ↔ online_game_screen) bu dosyayı paylaşır —
// ikizlerin sessiz ayrışması bu projenin kayıtlı hata sınıfı.
//
// Web'de karşılığı YOK — bilinçli port farkı (IntroScreen gibi; karar
// 1 Eylül 2026, kayıt: docs/decisions/product-backlog.md).
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

/// Zoom ölçeği. 2.0 bilinçli: 420 px ekranda hücre ~24 px → ~48 px, yani
/// projenin kendi 48 dp dokunma hedefi kuralı (24 Ağustos 2026 turu) ve
/// hayalet taşın 46 px'iyle hizalı — hayalet ekran katmanında (transform
/// DIŞINDA) kaldığından zoom'lu hücreyle birebir örtüşür.
const double kBoardZoomScale = 2.0;

/// Çift dokunuş penceresi/yarıçapı. 300 ms Flutter'ın kDoubleTapTimeout'una,
/// 40 px hücre boyutunun üstünde bir parmak toleransına denk geliyor —
/// yarıçap özellikle "ilk dokunuş taşı koydu, ikinci vuruş parmak
/// titremesiyle bir hücre yana düştü" durumunu da aynı çiftin parçası sayar.
const Duration kDoubleTapWindow = Duration(milliseconds: 300);
const double kDoubleTapRadius = 40.0;

/// Zoom aç/kapa animasyonu. Pan SIRASINDA animasyon YOK (`animate=false`) —
/// parmak gecikmesiz takip edilmeli.
const Duration kZoomAnimDuration = Duration(milliseconds: 180);

/// Aktif tahta kaydırması (pan) — yalnızca zoom açıkken kurulur. Ekranlar
/// scroll kilidini buna bağladığından atamalar setState içinde yapılır
/// (`_DragRef` ile aynı sözleşme).
class BoardPanRef {
  final Offset start;
  bool moved = false;
  BoardPanRef(this.start);
}

/// Tahta yakınlaştırma durumu + çift dokunuş algılayıcısı.
///
/// `ChangeNotifier`: pan her karede yalnızca `BoardWidget`'ın Transform
/// sarmalayıcısını yeniden kurar (`AnimatedBuilder` + önceden inşa edilmiş
/// `child`) — 169 hücre pan sırasında HİÇ yeniden inşa edilmez
/// (`_dragNotifier` performans kuralının aynısı).
class BoardZoomController extends ChangeNotifier {
  bool _zoomed = false;
  Offset _offset = Offset.zero;
  bool _animate = true;

  bool get zoomed => _zoomed;
  Offset get offset => _offset;

  /// Aç/kapa geçişi animasyonlu, pan animasyonsuz.
  bool get animate => _animate;

  /// T(offset)·S(scale): yerel p → scale·p + offset. Offset, tahtanın
  /// SABİT çerçeve uzayında (ölçeksiz) — pan delta'sı doğrudan eklenir.
  Matrix4 get matrix => _zoomed
      ? (Matrix4.translationValues(_offset.dx, _offset.dy, 0)
        ..scaleByDouble(kBoardZoomScale, kBoardZoomScale, 1, 1))
      : Matrix4.identity();

  /// Çift dokunuş: [focalLocal] (ızgaranın ÖLÇEKSİZ yerel uzayında, yani
  /// `grid.globalToLocal` çıktısı) noktasına doğru yakınlaş; zaten
  /// yakınsa sıfırla.
  void toggleAt(Offset focalLocal, Size gridSize) {
    if (_zoomed) {
      _zoomed = false;
      _offset = Offset.zero;
    } else {
      _zoomed = true;
      // Odak noktası yerinde kalsın: p → s·p + o = p ⇒ o = p·(1−s).
      _offset = _clamp(focalLocal * (1 - kBoardZoomScale), gridSize);
    }
    _animate = true;
    _resetTapTracking();
    notifyListeners();
  }

  /// Parmak kaydırması (ekran uzayı delta'sı). Sınırlar: ölçekli içerik
  /// görünür kareyi her zaman tamamen kaplar.
  void panBy(Offset delta, Size gridSize) {
    if (!_zoomed) return;
    final next = _clamp(_offset + delta, gridSize);
    if (next == _offset) return;
    _offset = next;
    _animate = false;
    notifyListeners();
  }

  Offset _clamp(Offset o, Size grid) => Offset(
        o.dx.clamp(grid.width * (1 - kBoardZoomScale), 0.0),
        o.dy.clamp(grid.height * (1 - kBoardZoomScale), 0.0),
      );

  /// Yeni oyun / ekran sıfırlaması.
  void reset() {
    _zoomed = false;
    _offset = Offset.zero;
    _animate = true;
    _resetTapTracking();
    notifyListeners();
  }

  // ── Çift dokunuş algılayıcısı ──────────────────────────────────────────
  //
  // Sözleşme (çağıranlar: iki oyun ekranının hücre/taslak dokunuş yolları):
  //
  //   1. Her tahta dokunuşunun BAŞINDA `tryCompletePair(global)` sorulur.
  //      `true` → bu dokunuş bir çiftin İKİNCİSİ: hücre işlemi YUTULUR,
  //      zoom aç/kapa yapılır, başka hiçbir şey olmaz. İlk dokunuşun
  //      yaptığı iş (koyulan taş dahil) OLDUĞU GİBİ KALIR.
  //   2. `false` ise dokunuş normal işini yapar; ardından:
  //      - BOŞ kareye düşen dokunuş (bir taş koymuş olsa da) →
  //        `registerPairableTap(global)`: sonraki dokunuş bununla çift
  //        oluşturabilir.
  //      - Diğer her şey (taslak/onaylı taşa dokunuş, raf, gerçek
  //        sürükleme, pan) → `markUnpairableTap()`: çift zinciri kırılır.
  //
  // Saat `clock.now()` — `DateTime.now()` DEĞİL: flutter test'in sahte
  // saati (`tester.pump`) DateTime.now'u İLERLETMEZ; ilk sürüm bunu gerçek
  // bir test düşüşüyle öğrendi (pubspec'teki `clock` gerekçesi).

  DateTime? _lastTapAt;
  Offset? _lastTapPos;

  /// Bu dokunuş bekleyen bir çift-başlangıcını tamamlıyor mu? `true` ise
  /// çift TÜKETİLİR (üçüncü dokunuş yeni bir zincir başlatır).
  bool tryCompletePair(Offset globalPos) {
    final last = _lastTapAt;
    final pos = _lastTapPos;
    final pair = last != null &&
        pos != null &&
        clock.now().difference(last) <= kDoubleTapWindow &&
        (globalPos - pos).distance <= kDoubleTapRadius;
    if (pair) _resetTapTracking();
    return pair;
  }

  /// Boş kareye düşen dokunuş — sonraki dokunuş bununla çift oluşturabilir.
  void registerPairableTap(Offset globalPos) {
    _lastTapAt = clock.now();
    _lastTapPos = globalPos;
  }

  /// Çift oluşturamayan etkileşim (taşa dokunuş, raf, sürükleme, pan) —
  /// zinciri kırar.
  void markUnpairableTap() {
    _resetTapTracking();
  }

  void _resetTapTracking() {
    _lastTapAt = null;
    _lastTapPos = null;
  }
}
