// k-lig rütbe rozeti — web `src/components/RankSeal.tsx` portu.
//
// Dolu roset (dalgalı kenar) + içte açık halka + iki kurdele kuyruğu. k-lig
// listesi satırlarında, Skor Kartı başlığında ve ödül banner'ında (glyph
// override'ıyla) kullanılır. **Yeni bir kullanım yeri şekilleri/metni
// KOPYALAMASIN** — `RelationIcons` ile aynı ilke (bkz. kök CLAUDE.md).
//
// 18 Ağustos 2026 — TIRTIKLI MÜHÜR TAMAMEN BIRAKILDI (kullanıcı: "Bizim
// rütbe badge'leri beğenmiyorum. Özellikle ince tırtıklar çok kötü."), yerine
// kullanıcının gönderdiği referans görselinden (klasik ödül roseti) birebir
// çıkarılan bu rozet geldi. Aşağıdaki bütün sabitler web dosyasındakilerle
// AYNI ve ikisi ELLE senkron — biri değişirse öteki de değişmeli.
//
// CanvasKit notu (mobile/CLAUDE.md, Parça 18): `Path.combine`/PathOps
// KULLANILMIYOR; her şey düz `drawPath`/`drawCircle` — native Skia ile
// CanvasKit arasında ayrışma riski yok. (Eski sürümdeki kesikli halka da
// bu yüzden yay yay çiziliyordu; yeni halka düz bir çember, o karmaşa
// tamamen kalktı.)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'league_rank.dart';

/// Web SVG'sinin viewBox'ı — tüm ölçüler bu birimde yazılıp [size]'a
/// ölçeklenir (web ile birebir kalsın diye).
const double _kViewBox = 44;

// ── Roset geometrisi (web RankSeal.tsx ile birebir) ───────────────────────
/// Madalyon merkezi yukarıda: alt üçte bir kurdeleye ayrıldı.
const double kSealCy = 16.6;
const double kSealTipR = 15;
const double kSealValleyR = 12.675; // 0.845 × uç — referanstaki dalga derinliği
const int kSealLobes = 14;
const double kSealEdgeW = 2; // yuvarlatma: StrokeJoin.round ile lob uçları yumuşar
const double kSealRingR = 11;
const double kSealRingW = 1.3;

const double _kTailTop = 25;
const double _kTailBottom = 43.4;
const double _kTailW = 8.8;
const double _kTailSplay = 5.4;
const double _kTailNotch = 5.2;
const double _kTailInnerX = 22.7;

/// Sol kurdele — üstü madalyonun ARKASINDA başlar, aşağı inerken dışa açılır,
/// alt ucu V kesiktir. Sağdaki bunun x eksenindeki aynası.
const List<Offset> kSealTailLeft = [
  Offset(_kTailInnerX, _kTailTop),
  Offset(_kTailInnerX - _kTailW, _kTailTop),
  Offset(_kTailInnerX - _kTailW - _kTailSplay, _kTailBottom),
  Offset(_kTailInnerX - _kTailW - _kTailSplay / 2 + _kTailW / 2,
      _kTailBottom - _kTailNotch),
  Offset(_kTailInnerX - _kTailSplay, _kTailBottom - 1.5),
];

/// Kurdele, madalyondan ayrışsın diye kademe renginin bir tık koyusu (web
/// `darken()` ile aynı katsayı).
Color sealRibbonColor(Color base) => Color.fromARGB(
      (base.a * 255).round(),
      (base.r * 255 * 0.86).round(),
      (base.g * 255 * 0.86).round(),
      (base.b * 255 * 0.86).round(),
    );

/// Kompakt çizim eşiği — k-lig satırlarındaki 18px rozette iç halka
/// çizilmez ve harf büyütülür. Saf fonksiyon: kural testte doğrudan
/// sınanabilsin diye.
bool sealIsCompact(double size) => size < 24;

/// İç halka yalnızca TAM BOYDA ve TEK harfte çizilir — rakamlı glyph'ler
/// ("1000", "+1000") halkanın içine sığmıyor, sığdırmak için küçültmek de
/// onları okunmaz yapıyordu.
/// (Uzunluk `String.length` ile ölçülür — web `RankSeal.tsx` de
/// `text.length` kullanıyor ve basılabilen tüm glyph'ler — Ç M O U Ş D E Z T,
/// rakamlar, '+' — tek UTF-16 kod birimi; parite birebir.)
bool sealShowsRing(String text, {required bool compact}) =>
    !compact && text.length <= 1;

/// Ortadaki metnin viewBox birimindeki puntosu (web `fontSizeFor` ile aynı
/// merdiven).
///
/// ÖLÇÜLMÜŞ tavanlar, tahmin değil: web tarafında gerçek rozet 20× büyütülüp
/// siyah zeminde render edildi ve beyaz harfin HER pikseli madalyon
/// poligonuna karşı tarandı. Ölçülen paylar (viewBox birimi): tek harf
/// halkanın iç kenarına en kötü Ç'de +1.28; banner glyph'lerinin en kötüsü
/// "+1000" poligonun 0.28 dışında ama 2 birimlik kenar stroke'unun 0.72
/// içinde. M PLUS'ın rakamları eski fonttan geniş olduğundan çok karakterli
/// basamaklar küçüldü (13 → 12, 10.5 → 9.5, 8.5 → 8); tek harf AYNI kaldı.
double sealFontSize(String text, {required bool compact}) {
  final n = text.length;
  if (n <= 1) return compact ? 20.5 : 18;
  if (n <= 3) return 12;
  if (n <= 4) return 9.5;
  return 8;
}

/// Büyük harflerin mürekkep tepesi, em cinsinden — ÖLÇÜLDÜ (M PLUS Rounded 1c
/// ExtraBold, Chromium `canvas.measureText`in `actualBoundingBox*` alanları):
/// kademe harflerinde .740–.750. Aralık bu fontta çok dar olduğundan tek sabit
/// yeterli; basılabilen HER glyph için azami merkezleme sapması 0.0075 em.
const double kSealInkAscEm = 0.745;

/// Sedillanın taban çizgisi ALTINA inmesi, em cinsinden (aynı ölçüm: Ç/Ş .220).
const double kSealDescenderEm = 0.22;

/// Bu rozette basılabilen TEK kuyruklu karakterler. Kademe harfleri kapalı
/// bir küme (Ç M O U Ş D E Z T — `league_rank.dart`), banner glyph'leri ise
/// rakam ve "+". Yeni bir kademe harfi eklenirse burası da gözden geçirilmeli.
const String kSealDescenderChars = 'ÇŞ';

/// Taban çizgisinin madalyon merkezine olan uzaklığı (em, aşağı pozitif) —
/// mürekkep kutusunun dikey ortası merkeze gelsin diye.
///
/// Web `RankSeal.tsx`'in `baselineY`'siyle AYNI formül, ikisi ELLE senkron.
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
    final compact = sealIsCompact(size);
    return Semantics(
      label: glyph == null ? 'Rütbe: ${tier.name}' : null,
      excludeSemantics: glyph != null,
      child: CustomPaint(
        size: Size(size, size),
        painter: _RankSealPainter(
          color: tier.color,
          text: text,
          fontSize: sealFontSize(text, compact: compact),
          showRing: sealShowsRing(text, compact: compact),
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
  final bool showRing;

  _RankSealPainter({
    required this.color,
    required this.text,
    required this.fontSize,
    required this.showRing,
  });

  Path _polygon(List<Offset> points, double s) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (i == 0) {
        path.moveTo(p.dx * s, p.dy * s);
      } else {
        path.lineTo(p.dx * s, p.dy * s);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _kViewBox;
    final center = Offset(22 * s, kSealCy * s);

    // Kurdeleler madalyonun ARKASINDA — üst uçları rozetin altında kalır.
    final ribbon = Paint()..color = sealRibbonColor(color);
    canvas.drawPath(_polygon(kSealTailLeft, s), ribbon);
    canvas.drawPath(
      _polygon(
        kSealTailLeft.map((p) => Offset(_kViewBox - p.dx, p.dy)).toList(),
        s,
      ),
      ribbon,
    );

    // Dalgalı madalyon: dolgu + aynı renkte yuvarlatılmış kenar (web'de
    // `strokeLinejoin="round"`, lob uçlarını yumuşatır).
    final lobes = <Offset>[];
    for (var i = 0; i < kSealLobes * 2; i++) {
      final r = i.isEven ? kSealTipR : kSealValleyR;
      final a = i * math.pi / kSealLobes - math.pi / 2;
      lobes.add(Offset(22 + r * math.cos(a), kSealCy + r * math.sin(a)));
    }
    final medallion = _polygon(lobes, s);
    canvas.drawPath(medallion, Paint()..color = color);
    canvas.drawPath(
      medallion,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kSealEdgeW * s
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // İç halka — referanstaki açık renkli ince çember.
    if (showRing) {
      canvas.drawCircle(
        center,
        kSealRingR * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = kSealRingW * s
          ..color = kPanel.withValues(alpha: 0.92),
      );
    }

    // Ortadaki harf/sayı — taban çizgisi MÜREKKEP kutusunun dikey ortası
    // madalyon merkezine gelecek şekilde konumlanır (bkz. sealBaselineEm).
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          // Yalnızca bu rozete özgü, alt kümelenmiş font (bkz. pubspec.yaml).
          fontFamily: 'MPlusRounded1c',
          fontWeight: FontWeight.w800,
          fontSize: fontSize * s,
          color: Colors.white,
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
      old.showRing != showRing;
}
