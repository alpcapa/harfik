// Nömorfik "içe gömülü" kutu — CSS `inset box-shadow`ın Flutter karşılığı.
// Flutter'da yerleşik inset gölge yok; RRect'e kırpılmış alanda, gölge
// yönüne kaydırılmış RRect'in DIŞI blur'lanarak çizilir (web Board.tsx'teki
// hücre stillerinin birebir taşınabilmesi için — kullanıcı 6 Ağustos 2026'da
// iç gölgelerin eksikliğini web/app karşılaştırmasıyla bildirdi).
//
// ⚠ PERFORMANS SÖZLEŞMESİ (26 Ağustos 2026) — aşağıdaki `_rasterCache`'i
// okumadan bu dosyada gölge çizimine dokunma. Bu dosyadaki her
// `MaskFilter.blur` çağrısı ÇOK pahalı: Impeller/Skia bunu analitik değil
// GERÇEK bir offscreen gauss geçişiyle çiziyor ve buradaki gölgeler basit
// bir RRect değil evenOdd bir PATH üzerine uygulandığından hiçbir hızlı yola
// düşmüyor. Tahtanın 169 boş hücresi × 2 iç gölge = kare başına ~340 blur
// demekti; cihazda oyun ekranının TAMAMI (sürükleme, geri tuşu, modal
// açılışı) ağır çekim oluyordu.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';

/// ÖLÇÜM ARACI (26 Ağustos 2026) — kaç kez GERÇEK bir `MaskFilter.blur`
/// çizimi yapıldığını sayar. Yalnızca `kDebugMode`de artar, üretimde ölü.
///
/// NEDEN VAR: sürükleme "ağır çekim" bildirimi iki kez teşhis edildi ve
/// ikisinde de dolaylı göstergelere bakıldı (önce `build` sayısı, sonra
/// `RepaintBoundary`in simetrik boyama sayacı). İkisi de "iyi" derken cihaz
/// hâlâ yavaştı. Bu sayaç dolaylı DEĞİL: tahtanın pahalı işi tam olarak bu
/// çağrılar.
///
/// BUGÜNKÜ İŞLEVİ: aşağıdaki raster önbelleği sayesinde bir gölge deseni
/// ömrü boyunca YALNIZCA BİR KEZ blur'lanır. Yani bu sayaç artık bir
/// REGRESYON BEKÇİSİ: sürükleme sırasında artmaya başlarsa önbellek
/// delinmiş demektir (ör. anahtar her karede değişiyor).
@visibleForTesting
int debugBlurPaintCountForTests = 0;

/// Önbelleğin GERÇEKTEN kullanıldığını kanıtlar — blur sayacı "0" kalırsa
/// bu, ya önbelleğin çalıştığı ya da hiç çizim olmadığı anlamına gelirdi;
/// bu sayaç ikisini ayırır (her blit'te artar).
@visibleForTesting
int debugCachedBlitCountForTests = 0;

/// Testler arası sızıntıyı önler.
@visibleForTesting
void debugResetNeoBoxCacheForTests() {
  _rasterCache.clear();
}

// ---------------------------------------------------------------------------
// Raster önbelleği
// ---------------------------------------------------------------------------
// Aynı gölge deseni + aynı boyut + aynı piksel yoğunluğu → aynı görüntü.
// Bir kez `Picture.toImageSync` ile rasterleştirilip GPU'da tutulur, sonraki
// her boyamada tek bir `drawImageRect` ile basılır. Görsel BİREBİR aynıdır,
// çünkü rasterleştirmede eski çizim kodunun TA KENDİSİ koşuyor — iki ayrı
// "eski/yeni" çizim yolu YOK, dolayısıyla sessizce ayrışamaz.

/// Tek bir önbellek girdisinin azami piksel alanı. Bunu aşan yüzeyler
/// (büyük modal kartları, tam genişlikte paneller) önbelleğe ALINMAZ,
/// doğrudan çizilir: onlar zaten ekranda bir-iki tane ve birkaç blur'a mal
/// oluyor; önbelleğe alınsalar tek başına megabaytlarca doku tutarlardı.
const int _kMaxEntryPx = 400000; // ~1.6 MB (RGBA)

/// Tüm önbelleğin toplam piksel bütçesi (~24 MB). Aşılınca komple boşaltılır
/// — LRU tutmaya değmez, yeniden üretim birkaç karede tamamlanıyor.
const int _kBudgetPx = 6000000;

final Map<Object, ui.Image> _rasterCacheMap = <Object, ui.Image>{};
int _rasterCachePx = 0;

final _RasterCache _rasterCache = _RasterCache();

class _RasterCache {
  /// `ui.Image.dispose()` BİLEREK ÇAĞRILMIYOR: üretilen görüntü, onu çizmiş
  /// olan `Picture`lar (ve o picture'ları tutan retained layer'lar) tarafından
  /// hâlâ kullanılıyor olabilir. Handle bırakıldığında native taraf zaten
  /// finalizer ile serbest kalıyor; bütçe taşması pratikte hiç yaşanmıyor
  /// (gerçek girdi sayısı ~10), yani burada erken dispose'un kazancı yok,
  /// riski var.
  void clear() {
    _rasterCacheMap.clear();
    _rasterCachePx = 0;
  }

  /// `key` için hazır görüntüyü döndürür; yoksa `draw` ile üretir.
  /// Üretilemiyorsa (boyut sınırı, boş boyut ya da bu platformda
  /// `toImageSync` desteklenmiyorsa) `null` döner — çağıran doğrudan çizime
  /// düşer, yani önbellek HİÇBİR koşulda görüntüyü bozamaz.
  ui.Image? obtain(
    Object key,
    Size size,
    double pad,
    double dpr,
    void Function(Canvas canvas, Size size) draw,
  ) {
    final cached = _rasterCacheMap[key];
    if (cached != null) return cached;
    if (!size.isFinite || size.isEmpty) return null;
    if (!dpr.isFinite || dpr <= 0) return null;
    final wPx = ((size.width + pad * 2) * dpr).ceil();
    final hPx = ((size.height + pad * 2) * dpr).ceil();
    if (wPx <= 0 || hPx <= 0) return null;
    if (wPx * hPx > _kMaxEntryPx) return null;
    ui.Image img;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(dpr);
      canvas.translate(pad, pad);
      draw(canvas, size);
      final picture = recorder.endRecording();
      img = picture.toImageSync(wPx, hPx);
      picture.dispose();
    } catch (_) {
      return null;
    }
    if (_rasterCachePx + wPx * hPx > _kBudgetPx) clear();
    _rasterCacheMap[key] = img;
    _rasterCachePx += wPx * hPx;
    return img;
  }
}

final Paint _blitPaint = Paint()..filterQuality = FilterQuality.low;

/// Hücre konumları kesirli olabildiğinden 1:1 piksel hizası garanti değil —
/// bilineer örnekleme (yumuşak gölgede fark edilmez) nearest'ın basamak
/// artefaktından güvenli.
void _blit(Canvas canvas, ui.Image img, Offset origin, double pad, double dpr) {
  if (kDebugMode) debugCachedBlitCountForTests++;
  canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromLTWH(
        origin.dx - pad, origin.dy - pad, img.width / dpr, img.height / dpr),
    _blitPaint,
  );
}

bool _listEq(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class InsetShadow {
  final Color color;
  final Offset offset;

  /// CSS blur-radius değeri (sigma değil) — web değerleri aynen taşınır.
  final double blur;
  const InsetShadow(
      {required this.color, required this.offset, required this.blur});

  @override
  bool operator ==(Object other) =>
      other is InsetShadow &&
      other.color == color &&
      other.offset == offset &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(color, offset, blur);
}

/// CSS box-shadow tanımı (blur = CSS blur-radius; sigma DEĞİL).
class CssShadow {
  final Color color;
  final Offset offset;
  final double blur;
  const CssShadow(
      {required this.color, required this.offset, required this.blur});

  @override
  bool operator ==(Object other) =>
      other is CssShadow &&
      other.color == color &&
      other.offset == offset &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(color, offset, blur);
}

/// Dış gölgeleri CSS semantiğiyle çizen decoration: sigma = blur/2 ve
/// İLK yazılan gölge EN ÜSTTE (CSS sırası — Flutter BoxShadow listesi tam
/// tersini yapar). BoxDecoration'ın gölge boyaması hem daha yoğun hem sırası
/// ters olduğundan web panelleriyle birebirlik için bu kullanılır.
class ShapeDecorationWithCssShadows extends Decoration {
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final List<CssShadow> shadows;

  /// Opsiyonel 1px'lik çerçeve — web'de gölgeli kartlar `border border-border`
  /// de taşıyor. `BoxDecoration.border` gibi İÇERİ doğru çizilir ve çocuğu
  /// aynı miktarda içeri iter (`padding` override'ı), böylece bu decoration'a
  /// geçen bir kutunun DIŞ ölçüsü BoxDecoration'daki hâliyle birebir aynı
  /// kalır — gölge eklerken düzen kaymaz.
  final Color? borderColor;
  final double borderWidth;

  const ShapeDecorationWithCssShadows({
    this.color,
    this.gradient,
    required this.radius,
    required this.shadows,
    this.borderColor,
    this.borderWidth = 1,
  }) : assert(color != null || gradient != null,
            'color ya da gradient verilmeli');

  @override
  EdgeInsetsGeometry get padding => borderColor == null || borderWidth <= 0
      ? EdgeInsets.zero
      : EdgeInsets.all(borderWidth);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _CssShadowBoxPainter(this);
}

/// Web `.shadow-raised` (index.css) — `.btn-raised-neutral` ile BİREBİR AYNI
/// iki katman. Kart/panel/istatistik kutusu gibi buton OLMAYAN yüzeyler için;
/// butonlar `NeoButton` üzerinden aynı gölgeyi zaten alıyor.
const List<CssShadow> kRaisedShadows = [
  CssShadow(color: Color(0x80A3B1C6), offset: Offset(2, 2), blur: 6),
  CssShadow(color: Color(0xD9FFFFFF), offset: Offset(-2, -2), blur: 5),
];

/// Web `Modal.tsx`'in `shadow-[0_20px_45px_rgba(15,23,42,0.5)]`'i —
/// KARARTILMIŞ zeminde yüzen kartlar için (rütbe popup'ı, ödül banner'ı).
/// `kRaisedShadows` BURADA KULLANILMAZ: onun sol-üst beyaz parıltısı
/// (`-2 -2 5 rgba(255,255,255,.85)`) nömorfik YÜZEYLER için tasarlandı,
/// `bg-black/40` üstünde yüzen bir kartta hale gibi okunuyor (kullanıcı
/// 12 Ağustos 2026'da bildirdi: "üst ve sol tarafındaki beyaz gölge iyi
/// durmuyor").
const List<CssShadow> kFloatingCardShadows = [
  CssShadow(color: Color(0x800F172A), offset: Offset(0, 20), blur: 45),
];

/// Web `.btn-raised` — seçili/vurgulu (accent) yüzeyler. Üç katman.
const List<CssShadow> kRaisedAccentShadows = [
  CssShadow(color: Color(0x8CA3B1C6), offset: Offset(3, 3), blur: 8),
  CssShadow(color: Color(0xB3FFFFFF), offset: Offset(-2, -2), blur: 6),
  CssShadow(color: Color(0x59647489), offset: Offset(0, 6), blur: 14),
];

@immutable
class _CssKey {
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final List<CssShadow> shadows;
  final Color? borderColor;
  final double borderWidth;
  final Size size;
  final double dpr;
  const _CssKey(this.color, this.gradient, this.radius, this.shadows,
      this.borderColor, this.borderWidth, this.size, this.dpr);

  @override
  bool operator ==(Object other) =>
      other is _CssKey &&
      other.color == color &&
      other.gradient == gradient &&
      other.radius == radius &&
      other.borderColor == borderColor &&
      other.borderWidth == borderWidth &&
      other.size == size &&
      other.dpr == dpr &&
      _listEq(other.shadows, shadows);

  @override
  int get hashCode => Object.hash(color, gradient, radius, borderColor,
      borderWidth, size, dpr, Object.hashAll(shadows));
}

class _CssShadowBoxPainter extends BoxPainter {
  final ShapeDecorationWithCssShadows d;
  _CssShadowBoxPainter(this.d);

  double get _pad {
    var reach = 0.0;
    for (final s in d.shadows) {
      final r = s.blur * 2 + s.offset.distance;
      if (r > reach) reach = r;
    }
    return reach + 4;
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    // dpr bilinmiyorsa önbelleğe ALMA: yanlış yoğunlukta rasterleştirmek
    // gölgeyi bulanıklaştırır. `obtain` dpr<=0'ı reddedip null döner.
    final dpr = configuration.devicePixelRatio ?? 0.0;
    final pad = _pad;
    final img = _rasterCache.obtain(
      _CssKey(d.color, d.gradient, d.radius, d.shadows, d.borderColor,
          d.borderWidth, size, dpr),
      size,
      pad,
      dpr,
      _draw,
    );
    if (img != null) {
      _blit(canvas, img, offset, pad, dpr);
      return;
    }
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _draw(canvas, size);
    canvas.restore();
  }

  void _draw(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(d.radius));
    // CSS: DIŞ gölge kutunun İÇİNE hiç boyanmaz (border-box'ın dışına
    // kırpılır) — bu yüzden gölgeler şeklin kendi alanı DIŞLANARAK çizilir.
    // Opak bir dolguda fark görünmez (dolgu altındakini zaten örter), ama
    // SAYDAM dolguda gölge içeriden sızıp kutuyu grileştiriyordu: web'de
    // beyaz zemin + %5 mavi = (244,247,254) iken mobilde araya gri gölge
    // girip (200,210,226) çıkıyordu (kullanıcı "Neden Ücretsiz Üye
    // Olmalıyım?" kutusunda bildirdi, 8 Ağustos 2026 — projedeki TEK
    // saydam dolgulu kullanım yeri o).
    // (`clipRRect` bir ClipOp almıyor; "şekli DIŞLA" kırpması evenOdd bir
    // clipPath ile ifade ediliyor — inset gölgelerdeki aynı teknik, PathOps'a
    // girmediğinden CanvasKit'te de güvenli.)
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(_pad))
      ..addRRect(rrect));
    // CSS: listedeki ilk gölge en üstte → ters sırayla çiz.
    for (final s in d.shadows.reversed) {
      if (kDebugMode) debugBlurPaintCountForTests++;
      final paint = Paint()
        ..color = s.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      canvas.drawRRect(rrect.shift(s.offset), paint);
    }
    canvas.restore();
    final fill = Paint();
    if (d.gradient != null) {
      fill.shader = d.gradient!.createShader(rect);
    } else {
      fill.color = d.color!;
    }
    canvas.drawRRect(rrect, fill);
    if (d.borderColor != null && d.borderWidth > 0) {
      canvas.drawRRect(
          rrect.deflate(d.borderWidth / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = d.borderWidth
            ..color = d.borderColor!);
    }
  }
}

class NeoBox extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color? color;
  final Gradient? gradient;
  final List<InsetShadow> insetShadows;
  final List<BoxShadow> outerShadows;
  final Widget? child;

  const NeoBox({
    super.key,
    required this.borderRadius,
    this.color,
    this.gradient,
    this.insetShadows = const [],
    this.outerShadows = const [],
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // ÖNCEDEN: DecoratedBox(dış gölge) > ClipRRect > CustomPaint(iç gölge).
    // Tahtanın 169 hücresinde bu, kare başına 169 antialias kırpma + 338
    // path blur demekti. Şimdi üçü de TEK bir önbelleklenmiş görüntüye
    // indirgeniyor; çocuk (harf/ev işareti/X3 etiketi) hücrenin dışına
    // taşmadığından kırpmaya gerek kalmıyor.
    return CustomPaint(
      painter: _NeoBoxPainter(
        color: color,
        gradient: gradient,
        borderRadius: borderRadius,
        insetShadows: insetShadows,
        outerShadows: outerShadows,
        dpr: MediaQuery.devicePixelRatioOf(context),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}

@immutable
class _NeoKey {
  final Color? color;
  final Gradient? gradient;
  final BorderRadius borderRadius;
  final List<InsetShadow> insetShadows;
  final List<BoxShadow> outerShadows;
  final Size size;
  final double dpr;
  const _NeoKey(this.color, this.gradient, this.borderRadius, this.insetShadows,
      this.outerShadows, this.size, this.dpr);

  @override
  bool operator ==(Object other) =>
      other is _NeoKey &&
      other.color == color &&
      other.gradient == gradient &&
      other.borderRadius == borderRadius &&
      other.size == size &&
      other.dpr == dpr &&
      _listEq(other.insetShadows, insetShadows) &&
      _listEq(other.outerShadows, outerShadows);

  @override
  int get hashCode => Object.hash(color, gradient, borderRadius, size, dpr,
      Object.hashAll(insetShadows), Object.hashAll(outerShadows));
}

class _NeoBoxPainter extends CustomPainter {
  final Color? color;
  final Gradient? gradient;
  final BorderRadius borderRadius;
  final List<InsetShadow> insetShadows;
  final List<BoxShadow> outerShadows;
  final double dpr;

  const _NeoBoxPainter({
    required this.color,
    required this.gradient,
    required this.borderRadius,
    required this.insetShadows,
    required this.outerShadows,
    required this.dpr,
  });

  double get _pad {
    var reach = 0.0;
    for (final s in outerShadows) {
      // Flutter `BoxShadow` sigma'sı yarıçapın ~0.577 katı; erişim payını
      // cömert tut — eksik pay gölgeyi KESER, fazla pay yalnızca birkaç
      // saydam piksel maliyetindedir.
      final r = s.blurRadius * 3 + s.spreadRadius + s.offset.distance;
      if (r > reach) reach = r;
    }
    return reach + 4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pad = _pad;
    final img = _rasterCache.obtain(
      _NeoKey(color, gradient, borderRadius, insetShadows, outerShadows, size,
          dpr),
      size,
      pad,
      dpr,
      _draw,
    );
    if (img != null) {
      _blit(canvas, img, Offset.zero, pad, dpr);
      return;
    }
    _draw(canvas, size);
  }

  void _draw(Canvas canvas, Size size) {
    // Dış gölge + dolgu: eskiden `DecoratedBox`ın işiydi, birebir aynı
    // decoration kullanılıyor ki gölge yoğunluğu/sırası değişmesin.
    BoxDecoration(
      color: color,
      gradient: gradient,
      borderRadius: borderRadius,
      boxShadow: outerShadows,
    ).createBoxPainter().paint(
        canvas, Offset.zero, ImageConfiguration(size: size));
    if (insetShadows.isEmpty) return;
    canvas.save();
    canvas.clipRRect(borderRadius.toRRect(Offset.zero & size));
    _InsetShadowPainter(insetShadows, borderRadius).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NeoBoxPainter old) =>
      old.color != color ||
      old.gradient != gradient ||
      old.borderRadius != borderRadius ||
      old.dpr != dpr ||
      !_listEq(old.insetShadows, insetShadows) ||
      !_listEq(old.outerShadows, outerShadows);
}

class _InsetShadowPainter extends CustomPainter {
  final List<InsetShadow> shadows;
  final BorderRadius borderRadius;
  _InsetShadowPainter(this.shadows, this.borderRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    for (final s in shadows) {
      // CSS: sigma ≈ blur/2. Kaydırılmış rrect'in dışı, kırpılmış alan
      // içinde gölge bandı olarak kalır.
      final sigma = s.blur / 2;
      if (kDebugMode) debugBlurPaintCountForTests++;
      final paint = Paint()
        ..color = s.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      final pad = s.blur * 2 + s.offset.distance + 4;
      // "Dış dikdörtgen EKSİ kaydırılmış rrect" TEK bir yolla, evenOdd dolgu
      // kuralıyla ifade edilir — `Path.combine(difference, ...)` KULLANILMAZ.
      // Gerekçe (8 Ağustos 2026, ölçülerek bulundu): combine Skia'nın PathOps
      // katmanına iner ve CanvasKit'te MaskFilter.blur ile birlikte deliği
      // KAYBEDİYOR — yol tüm hücreyi düz dolduruyordu (native Skia'da doğru
      // çalıştığından `flutter test` PNG'leri sorunu hiç göstermiyordu; hata
      // yalnızca tarayıcıda görünüyordu). evenOdd saf bir dolgu kuralı,
      // PathOps'a hiç girmiyor ve iki motorda da aynı sonucu veriyor.
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(pad))
        ..addRRect(rrect.shift(s.offset));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_InsetShadowPainter old) =>
      old.shadows != shadows || old.borderRadius != borderRadius;
}
