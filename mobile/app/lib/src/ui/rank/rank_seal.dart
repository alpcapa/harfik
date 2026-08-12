// k-lig rütbe mührü — web `src/components/RankSeal.tsx` portu.
//
// Nömorfik yuvarlak damga, hafif -6° eğik (gerçek bir mühür vuruşu gibi),
// içte kesikli halka, ortada kademe harfi. k-lig listesi satırlarında, Skor
// Kartı başlığında ve ödül banner'ında (glyph override'ıyla) kullanılır.
// **Yeni bir kullanım yeri daireleri/metni KOPYALAMASIN** — `RelationIcons`
// ile aynı ilke (bkz. kök CLAUDE.md).
//
// CanvasKit uyarısı (mobile/CLAUDE.md, Parça 18): kesikli halka için
// `Path.combine`/PathOps KULLANILMADI — dash'ler tek tek yay (`drawArc`)
// olarak çiziliyor, native Skia ile CanvasKit arasında ayrışma riski yok.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'league_rank.dart';

/// Web SVG'sinin viewBox'ı — tüm ölçüler bu birimde yazılıp [size]'a
/// ölçeklenir (web ile birebir kalsın diye).
const double _kViewBox = 44;

/// Kompakt çizim eşiği — k-lig satırlarındaki 17-18px mühürde iç kesikli
/// halka çizilmez ve harf büyütülür (web'de kullanıcı "harf okunmuyor" diye
/// bildirdi). Saf fonksiyon: kural testte doğrudan sınanabilsin diye.
bool sealIsCompact(double size) => size < 24;

/// Ortadaki metnin viewBox birimindeki puntosu — tek harf büyük, 2-3
/// karakter orta, daha uzunu küçük (web `RankSeal`'deki aynı merdiven).
double sealFontSize(String text, {required bool compact}) {
  final n = text.characters.length;
  if (n <= 1) return compact ? 27 : 19;
  return n <= 3 ? 14 : 11;
}

class RankSeal extends StatelessWidget {
  final RankTier tier;
  final double size;

  /// Ortadaki metin — verilmezse kademenin harfi. Banner "50" gibi bir
  /// kilometre taşı sayısını ya da "+5" gibi bir ödülü basmak için kullanır.
  final String? glyph;

  const RankSeal({
    super.key,
    required this.tier,
    this.size = 20,
    this.glyph,
  });

  @override
  Widget build(BuildContext context) {
    final text = glyph ?? tier.letter;
    // Küçük rozet boylarında (k-lig satırları gibi) iç kesikli halka
    // çizilmez ve harf büyütülür — 17-18px'lik bir mühürde 19'luk glyph
    // ~7px'e düşüp okunmaz kalıyordu (web'de kullanıcı bildirdi); halkasız
    // + 27'lik glyph ~10px veriyor.
    final compact = sealIsCompact(size);
    final fontSize = sealFontSize(text, compact: compact);
    return Semantics(
      label: glyph == null ? 'Rütbe: ${tier.name}' : null,
      excludeSemantics: glyph != null,
      child: Transform.rotate(
        angle: -6 * math.pi / 180,
        child: CustomPaint(
          size: Size(size, size),
          painter: _RankSealPainter(
            color: tier.color,
            text: text,
            fontSize: fontSize,
            compact: compact,
          ),
        ),
      ),
    );
  }
}

class _RankSealPainter extends CustomPainter {
  final Color color;
  final String text;

  /// viewBox birimindeki punto (ölçekleme painter içinde).
  final double fontSize;
  final bool compact;

  _RankSealPainter({
    required this.color,
    required this.text,
    required this.fontSize,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _kViewBox;
    final center = Offset(22 * s, 22 * s);

    if (compact) {
      // Küçük boyda tırtık alt-piksel gürültüsüne döner (18px'te diş derinliği
      // <1px) — kompakt mühür DÜZ çemberde kalır, web ile aynı karar.
      canvas.drawCircle(center, 20.5 * s, Paint()..color = kPanel);
      canvas.drawCircle(
        center,
        20.5 * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * s
          ..color = color,
      );
    } else {
      // Tırtıklı (noter mührü) dış kenar — 12 Ağustos 2026, kullanıcı isteği
      // (referans görsel: testere dişli sertifika damgası). 24 diş; uç 21.0 /
      // vadi 18.8 (stroke 2.0'ın yarısı taşınca 22'lik viewBox sınırında
      // kırpılmadan kalır — eski düz çemberin 20.5+1.25 hesabıyla aynı bütçe).
      // Web RankSeal.tsx aynı üç sabitle polygon üretir — ikisi birlikte
      // değişmeli.
      final path = Path();
      const teeth = 24;
      for (var i = 0; i < teeth * 2; i++) {
        final r = (i.isEven ? 21.0 : 18.8) * s;
        final a = i * math.pi / teeth - math.pi / 2;
        final p = Offset(
            center.dx + r * math.cos(a), center.dy + r * math.sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = kPanel);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * s
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }

    // İç kesikli halka — web `strokeDasharray="2.5 3.5"`, opacity .55, r16.
    if (!compact) {
      final r = 16 * s;
      final dash = 2.5 * s;
      final gap = 3.5 * s;
      final circumference = 2 * math.pi * r;
      // Dash sayısı tam sayıya yuvarlanır ki halka kapansın (SVG'de tarayıcı
      // deseni kırpıyor; burada eşit dağıtmak görsel olarak daha temiz).
      final count = math.max(1, (circumference / (dash + gap)).round());
      final step = 2 * math.pi / count;
      final dashAngle = step * dash / (dash + gap);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * s
        ..color = color.withValues(alpha: 0.55);
      final rect = Rect.fromCircle(center: center, radius: r);
      for (var i = 0; i < count; i++) {
        canvas.drawArc(rect, i * step, dashAngle, false, paint);
      }
    }

    // Ortadaki harf/sayı. Web `dominant-baseline: central`: taban çizgisi,
    // font metriklerinin (ascent/descent) ortasına gelecek şekilde kaydırılır
    // — ink kutusuna göre DEĞİL. Aynı hesabı burada da yapıyoruz, yoksa
    // `Center` satır kutusuna göre hizalayıp glyph'i hafif yukarı kaçırırdı.
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontWeight: FontWeight.bold,
          fontSize: fontSize * s,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final metrics = tp.computeLineMetrics();
    final dy = metrics.isEmpty
        ? center.dy - tp.height / 2
        : center.dy +
            (metrics.first.ascent - metrics.first.descent) / 2 -
            metrics.first.baseline;
    tp.paint(canvas, Offset(center.dx - tp.width / 2, dy));
  }

  @override
  bool shouldRepaint(_RankSealPainter old) =>
      old.color != color ||
      old.text != text ||
      old.fontSize != fontSize ||
      old.compact != compact;
}
