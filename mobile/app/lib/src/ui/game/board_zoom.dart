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
// 2. **Tek dokunuşlar ANINDA çalışır, çift dokunuş İLKİNİ GERİ SARAR.**
//    Flutter'ın `onDoubleTap`'i kullanılMIYOR: aynı hedefe takılınca her tek
//    dokunuşa ~300 ms bekleme ekler — bu projenin en çok savaştığı şey tam
//    da dokunuş hissi. Bunun yerine ilk dokunuş normal işini yapar (taş
//    konur, kullanıcı görür); pencere içinde ikincisi gelirse ikincisinin
//    hücre işlemi YUTULUR, ilkinin yaptığı iş GERİ ALINIR (`ZoomTapEffect`)
//    ve zoom açılır/kapanır. Net garanti: çift dokunuş tahta durumunu
//    DEĞİŞTİRMEZ. Görünür bedel: harf seçiliyken çift dokunuşta taş ~250
//    ms'liğine görünüp kaybolur — veri kaybı değil, kabul edilmiş titreme.
//    İstisna: MODAL açan dokunuşlar (joker harf seçimi) geri sarılamaz —
//    onlar pencere süresi kadar ERTELENİR (`deferModal`); bir modalın ~300
//    ms geç açılması algılanamaz, taş koymanın aksine.
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
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

/// Zoom ölçeği. 2.0 bilinçli: 420 px ekranda hücre ~24 px → ~48 px, yani
/// projenin kendi 48 dp dokunma hedefi kuralı (24 Ağustos 2026 turu) ve
/// hayalet taşın 46 px'iyle hizalı — hayalet ekran katmanında (transform
/// DIŞINDA) kaldığından zoom'lu hücreyle birebir örtüşür.
const double kBoardZoomScale = 2.0;

/// Çift dokunuş penceresi/yarıçapı. 300 ms Flutter'ın kDoubleTapTimeout'una,
/// 40 px hücre boyutunun üstünde bir parmak toleransına denk geliyor.
const Duration kDoubleTapWindow = Duration(milliseconds: 300);
const double kDoubleTapRadius = 40.0;

/// Zoom aç/kapa animasyonu. Pan SIRASINDA animasyon YOK (`animate=false`) —
/// parmak gecikmesiz takip edilmeli.
const Duration kZoomAnimDuration = Duration(milliseconds: 180);

/// Bir tahta dokunuşunun GERİ SARILABİLİR kaydı — çift dokunuş algılanınca
/// ilk dokunuşun etkisi bununla geri alınır (`applyZoomTapUndo`).
sealed class ZoomTapEffect {
  const ZoomTapEffect();
}

/// Dokunuş hiçbir iş yapmadı (boş kareye seçimsiz dokunuş vb.).
class ZoomTapNone extends ZoomTapEffect {
  const ZoomTapNone();
}

/// Dokunuş rafın [priorSelection] indeksindeki taşı (r,c)'ye KOYDU.
/// Geri sarma: RecallCell (taş rafın SONUNA döner — reducer davranışı,
/// `engine/reducer.dart` RecallCellAction) + seçimi geri kur.
class ZoomTapPlaced extends ZoomTapEffect {
  final int r, c;
  final int priorSelection;
  const ZoomTapPlaced(this.r, this.c, {required this.priorSelection});
}

/// Dokunuş (r,c)'deki taslak taşı GERİ ALDI (doğrudan ya da ıskalama
/// kurtarmasıyla). Geri sarma: taş şu an rafın sonunda → aynı hücreye
/// aynı [wildLetter] ile yeniden konur; önceki seçim varsa geri kurulur.
class ZoomTapRecalled extends ZoomTapEffect {
  final int r, c;
  final String? wildLetter;
  final int? priorSelection;
  const ZoomTapRecalled(this.r, this.c,
      {required this.wildLetter, required this.priorSelection});
}

/// Dokunuşun işi bir MODALDİ ve modal ertelendi (`deferModal`) — geri
/// sarılacak bir şey yok; çift dokunuş gelirse modal hiç açılmaz.
class ZoomTapDeferredModal extends ZoomTapEffect {
  const ZoomTapDeferredModal();
}

/// Çift dokunuşla EŞLEŞEMEZ dokunuş (onaylı taş, raf, buton) — bir sonraki
/// dokunuş bununla çift oluşturamaz. Kapsam kararı (1 Eylül 2026): onaylı
/// taşlar zoom dışında, çünkü anlam penceresi ANINDA kalmalı.
class ZoomTapUnpairable extends ZoomTapEffect {
  const ZoomTapUnpairable();
}

/// Geri sarma eylemlerini üretir ve [dispatch] ile uygular. İki ekran da
/// bunu kullanır — eylem mantığı TEK yerde dursun diye.
///
/// [rack]: dispatch SONRASI güncel rafı okumalı (RecallCell taşı rafın
/// sonuna eklediğinden geri gelen taşın indeksi `rack().length - 1`).
void applyZoomTapUndo(
  ZoomTapEffect effect, {
  required void Function(GameAction action) dispatch,
  required List<Tile> Function() rack,
}) {
  switch (effect) {
    case ZoomTapPlaced(:final r, :final c, :final priorSelection):
      dispatch(RecallCellAction(r: r, c: c));
      // Geri gelen taş rafın sonunda; seçim geri kurulur ki kullanıcı
      // zoom'lu tahtada kaldığı yerden devam edebilsin. (Yan etki: raf
      // sırası değişir — kozmetik; rafta zaten Karıştır var.)
      dispatch(SelectTileAction(rack().length - 1));
      // priorSelection bilerek KULLANILMIYOR: taş artık sondadır, eski
      // indeks başka bir taşı gösterir. Alan, kaydın eksiksizliği için
      // duruyor (testler "seçim vardı" bilgisine bakıyor).
      assert(priorSelection >= 0);
    case ZoomTapRecalled(:final r, :final c, :final wildLetter, :final priorSelection):
      dispatch(PlaceTileAction(
          r: r, c: c, rackIndex: rack().length - 1, wildLetter: wildLetter));
      if (priorSelection != null) dispatch(SelectTileAction(priorSelection));
    case ZoomTapNone():
    case ZoomTapDeferredModal():
    case ZoomTapUnpairable():
      break;
  }
}

/// Aktif tahta kaydırması (pan) — yalnızca zoom açıkken kurulur. Ekranlar
/// scroll kilidini buna bağladığından atamalar setState içinde yapılır
/// (`_DragRef` ile aynı sözleşme).
class BoardPanRef {
  final Offset start;
  bool moved = false;
  BoardPanRef(this.start);
}

/// Tahta yakınlaştırma durumu + çift dokunuş algılayıcısı + modal ertelemesi.
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
    cancelDeferredModal();
    notifyListeners();
  }

  // ── Çift dokunuş algılayıcısı ──────────────────────────────────────────

  DateTime? _lastTapAt;
  Offset? _lastTapPos;
  ZoomTapEffect _lastEffect = const ZoomTapUnpairable();
  ZoomTapEffect? _pendingUndo;

  /// Her TAHTA dokunuşunda, dokunuşun işi YAPILMADAN önce çağrılır.
  /// `true` → bu dokunuş bir çiftin İKİNCİSİ: çağıran kendi hücre işlemini
  /// YUTMALI, [takePendingUndo] ile ilkinin etkisini geri sarmalı ve zoom'u
  /// değiştirmelidir. Bekleyen ertelenmiş modal her yeni dokunuşta iptal
  /// olur (niyet değişti).
  bool registerTap(Offset globalPos) {
    final now = clock.now();
    cancelDeferredModal();
    final last = _lastTapAt;
    final pos = _lastTapPos;
    final pair = last != null &&
        pos != null &&
        _lastEffect is! ZoomTapUnpairable &&
        now.difference(last) <= kDoubleTapWindow &&
        (globalPos - pos).distance <= kDoubleTapRadius;
    if (pair) {
      _pendingUndo = _lastEffect;
      _resetTapTracking();
      return true;
    }
    _lastTapAt = now;
    _lastTapPos = globalPos;
    // Etki, iş yapıldıktan sonra `recordTapEffect` ile yazılır; o âna kadar
    // muhafazakâr davran — bilinmeyen dokunuş çift oluşturmasın.
    _lastEffect = const ZoomTapUnpairable();
    return false;
  }

  /// Dokunuşun işi yapıldıktan sonra etkisi kaydedilir (geri sarma verisi).
  void recordTapEffect(ZoomTapEffect effect) {
    _lastEffect = effect;
  }

  /// Çift algılandığında ilk dokunuşun etkisi (bir kez okunur).
  ZoomTapEffect? takePendingUndo() {
    final u = _pendingUndo;
    _pendingUndo = null;
    return u;
  }

  /// Tahta DIŞI bir etkileşim (raf, buton, onaylı taş) — sonraki dokunuş
  /// bununla çift oluşturamaz.
  void markUnpairableTap() {
    _lastTapAt = clock.now();
    _lastTapPos = null;
    _lastEffect = const ZoomTapUnpairable();
    cancelDeferredModal();
  }

  void _resetTapTracking() {
    _lastTapAt = null;
    _lastTapPos = null;
    _lastEffect = const ZoomTapUnpairable();
  }

  // ── Modal ertelemesi (joker harf seçimi) ──────────────────────────────

  Timer? _modalTimer;

  /// Modal açan dokunuş geri sarılamaz — pencere süresi kadar ertelenir.
  /// Çift dokunuş (ya da HERHANGİ yeni tahta dokunuşu) gelirse modal hiç
  /// açılmaz. Bir modalın ~300 ms geç açılması algılanamaz.
  void deferModal(VoidCallback open) {
    _modalTimer?.cancel();
    _modalTimer = Timer(
      kDoubleTapWindow + const Duration(milliseconds: 30),
      () {
        _modalTimer = null;
        open();
      },
    );
  }

  void cancelDeferredModal() {
    _modalTimer?.cancel();
    _modalTimer = null;
  }

  @override
  void dispose() {
    cancelDeferredModal();
    super.dispose();
  }
}
