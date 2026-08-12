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
///
/// Tam boyda 19 → 23 (12 Ağustos 2026, kullanıcı isteği: "rozet içindeki
/// harfleri büyüt"). 23 ÖLÇÜLMÜŞ tavan, tahmin değil: kademe harflerinin
/// (Ç M O U Ş D) sınırlayıcı kutusu gerçek Space Mono 700 ile Chromium'da
/// okundu, merkeze en uzak köşe Ç'de 23'te 15.48 / 24'te 16.20 — iç kesikli
/// halka r=16 olduğundan 24'te Ç/Ş'nin sedillası halkayı taşıyor.
///
/// Kompakt 27'DE KALDI. Tırtık her boya yayılınca kompaktın iç sınırı
/// daraldı (düz çemberin iç kenarı 19.25 → vadi iç kenarı 18.8 − 2/2 =
/// 17.8) ve harfin sınırlayıcı KUTUSU 27'de 18.17, yani kutu taşıyor —
/// ama kutunun köşesi boş: aynı harfler 20× ölçekte render edilip PİKSEL
/// taranınca (Chromium, gerçek Space Mono 700) en uzak MÜREKKEP 27'de
/// 16.56 (Ç; Ş 16.47, M 13.16, D 12.79, U 11.13, O 11.11) — sınıra 1.24
/// birim var. Yuvarlak harflerde bbox köşesini sınır sanmak yanlış pozitif
/// üretir; ölçüm mürekkeple yapılmalı.
double sealFontSize(String text, {required bool compact}) {
  final n = text.characters.length;
  if (n <= 1) return compact ? 27 : 23;
  return n <= 3 ? 14 : 11;
}

/// Büyük harflerin mürekkep tepesi, em cinsinden — ÖLÇÜLDÜ (Space Mono 700,
/// Chromium `canvas.measureText`): M/U/D .70, yuvarlaklar .72 (standart
/// taşma). Tek sabit olarak ortalama alındı; altı kademe harfinin hepsinde
/// sapmayı ±0.15 viewBox biriminin altında tutuyor, harf başına tablo
/// gerekmiyor.
const double kSealInkAscEm = 0.71;

/// Sedillanın taban çizgisi ALTINA inmesi, em cinsinden (aynı ölçüm).
const double kSealDescenderEm = 0.21;

/// Bu mühürde basılabilen TEK kuyruklu karakterler. Kademe harfleri kapalı
/// bir küme (Ç M O U Ş D — `league_rank.dart`), banner glyph'leri ise rakam
/// ve "+". Yeni bir kademe harfi eklenirse burası da gözden geçirilmeli.
const String kSealDescenderChars = 'ÇŞ';

/// Taban çizgisinin daire merkezine olan uzaklığı (em, aşağı pozitif) —
/// mürekkep kutusunun dikey ortası merkeze gelsin diye.
///
/// Web `RankSeal.tsx`'in `baselineY`'siyle AYNI formül, ikisi ELLE senkron.
/// Eski hâl `dominant-baseline: central`di; o, mürekkebi değil FONT
/// metriklerini (ascent/descent) ortalıyor — kullanıcı 12 Ağustos 2026'da
/// Ç/Ş'nin alta kaydığını bildirdi. Ölçüm iki ayrı sapma gösterdi: TÜM
/// harfler ~1.2 birim aşağıdaydı, Ç/Ş sedilla yüzünden ~2.5 birim DAHA
/// aşağıdaydı. Düzeltmeden sonra azami sapma 0.32'ye indi (ölçüldü).
double sealBaselineEm(String text) {
  final hasTail = text.split('').any(kSealDescenderChars.contains);
  return (kSealInkAscEm - (hasTail ? kSealDescenderEm : 0)) / 2;
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

    // Tırtıklı (noter mührü) dış kenar — 12 Ağustos 2026, kullanıcı isteği
    // (referans görsel: testere dişli sertifika damgası). 24 diş; uç 21.0 /
    // vadi 18.8 (stroke 2.0'ın yarısı taşınca 22'lik viewBox sınırında
    // kırpılmadan kalır — eski düz çemberin 20.5+1.25 hesabıyla aynı bütçe).
    // Web RankSeal.tsx aynı üç sabitle polygon üretir — ikisi birlikte
    // değişmeli.
    //
    // HER BOYDA çizilir (aynı gün ikinci karar, kullanıcı: "leaderboard'daki
    // küçük rozetlerde tırtık olamıyor mu?"). İlk sürümde kompakt mühür düz
    // çemberdi, gerekçesi "18px'te diş derinliği <1px, alt-piksel gürültüsüne
    // döner" idi — bu ÖLÇÜLMEDEN yazılmış ve YANLIŞTI: hesap DPR 1
    // varsayıyordu, retinada (DPR 3) 0.9 CSS px = 2.7 cihaz pikseli, dişler
    // net çıkıyor (web tarafında 18px/DPR3 render edilip büyütülerek
    // doğrulandı). Diş sayısı da bilerek aynı: tek siluet, tek sabit seti.
    final path = Path();
    const teeth = 24;
    for (var i = 0; i < teeth * 2; i++) {
      final r = (i.isEven ? 21.0 : 18.8) * s;
      final a = i * math.pi / teeth - math.pi / 2;
      final p =
          Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
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
        // Miter olsaydı sivri uçlarda uzun diken çıkardı (web
        // strokeLinejoin="round" ile aynı karar).
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

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

    // Ortadaki harf/sayı — taban çizgisi MÜREKKEP kutusunun dikey ortası
    // daire merkezine gelecek şekilde konumlanır (bkz. sealBaselineEm).
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
    // Taban çizgisinin gitmesi gereken yer; TextPainter satır kutusunun
    // TEPESİNDEN boyadığından `baseline` kadar geri alınır.
    final baselineY = center.dy + sealBaselineEm(text) * fontSize * s;
    final dy = metrics.isEmpty
        ? center.dy - tp.height / 2
        : baselineY - metrics.first.baseline;
    tp.paint(canvas, Offset(center.dx - tp.width / 2, dy));
  }

  @override
  bool shouldRepaint(_RankSealPainter old) =>
      old.color != color ||
      old.text != text ||
      old.fontSize != fontSize ||
      old.compact != compact;
}
