// "kelimeki" wordmark — web LogoMark.tsx'in Flutter karşılığı. Path verisi
// AYNI üreticiden gelir (scripts/generate-logo-paths.mjs artık
// logo_mark_data.dart'ı da yazar) — Caveat fontu uygulamaya hiç gömülmez,
// web'le birebir aynı glyph outline'ları çizilir.
import 'package:flutter/material.dart';

import 'logo_mark_data.dart';

class LogoMark extends StatelessWidget {
  final double height;
  final Color? color;
  const LogoMark({super.key, required this.height, this.color});

  @override
  Widget build(BuildContext context) {
    final vb = logoViewBox.split(' ').map(double.parse).toList();
    final aspect = vb[2] / vb[3];
    return SizedBox(
      height: height,
      width: height * aspect,
      child: CustomPaint(
        painter: _LogoPainter(color ?? const Color(logoColorValue)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;
  const _LogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final vb = logoViewBox.split(' ').map(double.parse).toList();
    final scale = size.height / vb[3];
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-vb[0], -vb[1]);

    canvas.drawPath(
      parseSvgPath(logoTextPath),
      Paint()..color = color,
    );
    canvas.drawPath(
      parseSvgPath(logoUnderlinePath),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = logoUnderlineStrokeWidth
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}

/// Üreticinin çıktısındaki MUTLAK komutlu (M/L/Q/C/Z) SVG path verisini
/// çözer — opentype.js `toPathData` yalnızca bunları üretir, genel bir SVG
/// parser'a (yeni bağımlılığa) gerek yok. Bilinmeyen komutta fırlatır ki
/// üretici bir gün farklı komut üretirse sessizce bozuk çizim yerine test
/// anında yakalansın.
Path parseSvgPath(String data) {
  final path = Path();
  final re = RegExp(r'([MLQCZ])|(-?\d*\.?\d+)');
  final tokens = re.allMatches(data).toList();
  var i = 0;
  double num() => double.parse(tokens[i++].group(2)!);
  while (i < tokens.length) {
    final cmd = tokens[i].group(1);
    if (cmd == null) {
      throw FormatException('Komut beklenirken sayı bulundu: konum $i');
    }
    i++;
    switch (cmd) {
      case 'M':
        path.moveTo(num(), num());
      case 'L':
        path.lineTo(num(), num());
      case 'Q':
        path.quadraticBezierTo(num(), num(), num(), num());
      case 'C':
        path.cubicTo(num(), num(), num(), num(), num(), num());
      case 'Z':
        path.close();
    }
  }
  return path;
}
