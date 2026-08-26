// Nömorfik "içe gömülü" kutu — CSS `inset box-shadow`ın Flutter karşılığı.
// Flutter'da yerleşik inset gölge yok; RRect'e kırpılmış alanda, gölge
// yönüne kaydırılmış RRect'in DIŞI blur'lanarak çizilir (web Board.tsx'teki
// hücre stillerinin birebir taşınabilmesi için — kullanıcı 6 Ağustos 2026'da
// iç gölgelerin eksikliğini web/app karşılaştırmasıyla bildirdi).
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';

/// ÖLÇÜM ARACI (26 Ağustos 2026) — kaç kez GERÇEK bir `MaskFilter.blur`
/// çizimi yapıldığını sayar. Yalnızca `kDebugMode`de artar, üretimde ölü.
///
/// NEDEN VAR: sürükleme "ağır çekim" bildirimi iki kez teşhis edildi ve
/// ikisinde de dolaylı göstergelere bakıldı (önce `build` sayısı, sonra
/// `RepaintBoundary`in simetrik boyama sayacı). İkisi de "iyi" derken cihaz
/// hâlâ yavaştı. Bu sayaç dolaylı DEĞİL: tahtanın pahalı işi tam olarak bu
/// çağrılar, yani sürükleme sırasında artıp artmadığı doğrudan cevaptır.
@visibleForTesting
int debugBlurPaintCountForTests = 0;

class InsetShadow {
  final Color color;
  final Offset offset;

  /// CSS blur-radius değeri (sigma değil) — web değerleri aynen taşınır.
  final double blur;
  const InsetShadow(
      {required this.color, required this.offset, required this.blur});
}

/// CSS box-shadow tanımı (blur = CSS blur-radius; sigma DEĞİL).
class CssShadow {
  final Color color;
  final Offset offset;
  final double blur;
  const CssShadow(
      {required this.color, required this.offset, required this.blur});
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

class _CssShadowBoxPainter extends BoxPainter {
  final ShapeDecorationWithCssShadows d;
  _CssShadowBoxPainter(this.d);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
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
    var reach = 0.0;
    for (final s in d.shadows) {
      final r = s.blur * 2 + s.offset.distance;
      if (r > reach) reach = r;
    }
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(reach + 4))
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: outerShadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CustomPaint(
          painter: _InsetShadowPainter(insetShadows, borderRadius),
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
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
