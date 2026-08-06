// Nömorfik "içe gömülü" kutu — CSS `inset box-shadow`ın Flutter karşılığı.
// Flutter'da yerleşik inset gölge yok; RRect'e kırpılmış alanda, gölge
// yönüne kaydırılmış RRect'in DIŞI blur'lanarak çizilir (web Board.tsx'teki
// hücre stillerinin birebir taşınabilmesi için — kullanıcı 6 Ağustos 2026'da
// iç gölgelerin eksikliğini web/app karşılaştırmasıyla bildirdi).
import 'package:flutter/material.dart';

class InsetShadow {
  final Color color;
  final Offset offset;

  /// CSS blur-radius değeri (sigma değil) — web değerleri aynen taşınır.
  final double blur;
  const InsetShadow({required this.color, required this.offset, required this.blur});
}

/// CSS box-shadow tanımı (blur = CSS blur-radius; sigma DEĞİL).
class CssShadow {
  final Color color;
  final Offset offset;
  final double blur;
  const CssShadow({required this.color, required this.offset, required this.blur});
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
  const ShapeDecorationWithCssShadows({
    this.color,
    this.gradient,
    required this.radius,
    required this.shadows,
  }) : assert(color != null || gradient != null,
            'color ya da gradient verilmeli');

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _CssShadowBoxPainter(this);
}

class _CssShadowBoxPainter extends BoxPainter {
  final ShapeDecorationWithCssShadows d;
  _CssShadowBoxPainter(this.d);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(d.radius));
    // CSS: listedeki ilk gölge en üstte → ters sırayla çiz.
    for (final s in d.shadows.reversed) {
      final paint = Paint()
        ..color = s.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      canvas.drawRRect(rrect.shift(s.offset), paint);
    }
    final fill = Paint();
    if (d.gradient != null) {
      fill.shader = d.gradient!.createShader(rect);
    } else {
      fill.color = d.color!;
    }
    canvas.drawRRect(rrect, fill);
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
      final paint = Paint()
        ..color = s.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      final pad = s.blur * 2 + s.offset.distance + 4;
      final outer = Path()..addRect(rect.inflate(pad));
      final inner = Path()..addRRect(rrect.shift(s.offset));
      canvas.drawPath(
        Path.combine(PathOperation.difference, outer, inner),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_InsetShadowPainter old) =>
      old.shadows != shadows || old.borderRadius != borderRadius;
}
