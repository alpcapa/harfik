// Kelimeki — tanıtım ekranının "Neler var" bölümündeki altı özellik ikonu.
//
// Web karşılığı: `src/landing/OzellikIkonlari.tsx`. O dosyanın başlığı bir
// dönem "bu altı ikonun portta karşılığı YOK ve olamaz" diyordu — 19 Ağustos
// 2026'da kullanıcı tanıtım ekranının "webin aynısı (6 kutu)" olmasını
// isteyince o karar geçersizleşti ve ikonlar buraya taşındı. İki dosya artık
// ELLE SENKRON: biri değişirse öteki de değişmeli (bunu zorlayan bir test
// YOK — `RelationIcons`'un aksine bunlar Material glyph'i değil, ikisi de
// elle çizilmiş ilkel şekiller).
//
// NEDEN `Icons.*` DEĞİL: web tarafı bu altısını bilerek ilkel şekillerden
// (daire/dikdörtgen/çizgi/yay) kurdu — bu ortamda çıkarılacak bir Material
// font dosyası yoktu ve codepoint'i hafızadan yazmak bu kod tabanında bir kez
// yanlış glyph üretmişti (bkz. `RelationIcons.tsx` başlığı). Portta `Icons.*`
// kullanmak İKİ platformda FARKLI vektör demek olurdu; aynı şekiller
// `CustomPainter` ile birebir çiziliyor.
//
// Ortak kurallar (web ile aynı): 24'lük koordinat sistemi, yalnızca kontur
// (dolgu yok — iki küçük nokta ve tahta taşı hariç), çizgi kalınlığı 2,
// yuvarlak uç/köşe, renk çağırandan (`kAccent`).
import 'package:flutter/material.dart';

/// Web'deki `size = 13` varsayılanı — yanındaki başlık 12px, yani "yazı
/// kadar" (kullanıcı isteği, 18 Ağustos 2026).
const double kOzellikIkonBoyu = 13;

/// Altı ikonun kimliği — çağıran taraf ikonu `const` bir veri listesinde
/// tutabilsin diye (fabrikalar `const` olamaz). `turden` bunu doğru çizime
/// bağlar; yeni bir ikon eklenirse İKİSİ de güncellenmeli.
enum OzellikIkonTuru { robot, ikiKisi, sohbet, cevrimdisi, tahta, madalya }

typedef _Cizim = void Function(Canvas canvas, Paint stroke, Paint fill);

class _IkonPainter extends CustomPainter {
  final Color renk;
  final _Cizim ciz;
  const _IkonPainter(this.renk, this.ciz);

  @override
  void paint(Canvas canvas, Size size) {
    // 24'lük viewBox → istenen boy. Çizgi kalınlığı da ölçekleniyor, yani
    // 13px'te ~1.1 px (web'deki değerin aynısı).
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = renk
      ..style = PaintingStyle.fill;
    ciz(canvas, stroke, fill);
  }

  @override
  bool shouldRepaint(_IkonPainter old) => old.renk != renk || old.ciz != ciz;
}

class OzellikIkon extends StatelessWidget {
  final _Cizim _ciz;
  final double size;
  final Color color;
  const OzellikIkon._(this._ciz,
      {required this.size, required this.color, super.key});

  /// Robot kafası — "Yapay zekaya karşı oyna".
  factory OzellikIkon.robot(
          {Key? key, double size = kOzellikIkonBoyu, required Color color}) =>
      OzellikIkon._(_robot, size: size, color: color, key: key);

  /// İki oyuncu — "Arkadaşınla canlı oyna".
  factory OzellikIkon.ikiKisi(
          {Key? key, double size = kOzellikIkonBoyu, required Color color}) =>
      OzellikIkon._(_ikiKisi, size: size, color: color, key: key);

  /// Konuşma balonu — "Oyun içi sohbet".
  factory OzellikIkon.sohbet(
          {Key? key, double size = kOzellikIkonBoyu, required Color color}) =>
      OzellikIkon._(_sohbet, size: size, color: color, key: key);

  /// Üstü çizili wifi — "Çevrimdışı da oynar".
  factory OzellikIkon.cevrimdisi(
          {Key? key, double size = kOzellikIkonBoyu, required Color color}) =>
      OzellikIkon._(_cevrimdisi, size: size, color: color, key: key);

  /// Tahta + konmuş taş — "Kelime denemesi".
  factory OzellikIkon.tahta(
          {Key? key, double size = kOzellikIkonBoyu, required Color color}) =>
      OzellikIkon._(_tahta, size: size, color: color, key: key);

  /// Kurdeleli madalya — "k-lig ve rütbeler".
  factory OzellikIkon.madalya(
          {Key? key, double size = kOzellikIkonBoyu, required Color color}) =>
      OzellikIkon._(_madalya, size: size, color: color, key: key);

  /// Enum'dan üretir — `const` bir listede taşınan ikon kimliğini çizime
  /// bağlayan tek yer.
  factory OzellikIkon.turden(OzellikIkonTuru tur,
      {Key? key, double size = kOzellikIkonBoyu, required Color color}) {
    switch (tur) {
      case OzellikIkonTuru.robot:
        return OzellikIkon.robot(key: key, size: size, color: color);
      case OzellikIkonTuru.ikiKisi:
        return OzellikIkon.ikiKisi(key: key, size: size, color: color);
      case OzellikIkonTuru.sohbet:
        return OzellikIkon.sohbet(key: key, size: size, color: color);
      case OzellikIkonTuru.cevrimdisi:
        return OzellikIkon.cevrimdisi(key: key, size: size, color: color);
      case OzellikIkonTuru.tahta:
        return OzellikIkon.tahta(key: key, size: size, color: color);
      case OzellikIkonTuru.madalya:
        return OzellikIkon.madalya(key: key, size: size, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _IkonPainter(color, _ciz)),
    );
  }
}

/* ── Çizimler — web SVG'lerinin birebir karşılığı ────────────────────────── */

void _robot(Canvas canvas, Paint stroke, Paint fill) {
  canvas.drawLine(const Offset(12, 2.5), const Offset(12, 6), stroke);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(3.5, 6, 17, 13), const Radius.circular(3.5)),
    stroke,
  );
  canvas.drawCircle(const Offset(9, 12.5), 0.9, fill);
  canvas.drawCircle(const Offset(15, 12.5), 0.9, fill);
}

void _ikiKisi(Canvas canvas, Paint stroke, Paint fill) {
  canvas.drawCircle(const Offset(8.5, 8), 3.2, stroke);
  // Öndeki kişinin omuzları (web: `M2.5 20c0-3.1 2.7-5.2 6-5.2s6 2.1 6 5.2`).
  final omuz = Path()
    ..moveTo(2.5, 20)
    ..cubicTo(2.5, 16.9, 5.2, 14.8, 8.5, 14.8)
    ..cubicTo(11.8, 14.8, 14.5, 16.9, 14.5, 20);
  canvas.drawPath(omuz, stroke);
  // Arkadaki kişinin yarım başı ve omzu.
  canvas.drawPath(
    Path()
      ..moveTo(17, 5.2)
      ..arcToPoint(const Offset(17, 11.1),
          radius: const Radius.circular(3), clockwise: true),
    stroke,
  );
  canvas.drawPath(
    Path()
      ..moveTo(17.5, 15.2)
      ..cubicTo(19.9, 15.7, 21.5, 17.5, 21.5, 20),
    stroke,
  );
}

void _sohbet(Canvas canvas, Paint stroke, Paint fill) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 4, 18, 13), const Radius.circular(3.5)),
    stroke,
  );
  canvas.drawPath(
    Path()
      ..moveTo(8.5, 17)
      ..lineTo(8.5, 21)
      ..lineTo(13, 17),
    stroke,
  );
}

void _cevrimdisi(Canvas canvas, Paint stroke, Paint fill) {
  // İki temiz yay + nokta: ilk sürümde yaylar parçalıydı ve 13px'te
  // okunmuyordu (web tarafında ölçüldü, tek merkezli iki yaya çevrildi).
  canvas.drawPath(
    Path()
      ..moveTo(2, 14.4)
      ..arcToPoint(const Offset(22, 14.4),
          radius: const Radius.circular(11), clockwise: true),
    stroke,
  );
  canvas.drawPath(
    Path()
      ..moveTo(6.1, 16.3)
      ..arcToPoint(const Offset(17.9, 16.3),
          radius: const Radius.circular(6.5), clockwise: true),
    stroke,
  );
  canvas.drawCircle(const Offset(12, 19.5), 0.9, fill);
  canvas.drawLine(const Offset(3.5, 3.5), const Offset(20.5, 20.5), stroke);
}

void _tahta(Canvas canvas, Paint stroke, Paint fill) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 3, 18, 18), const Radius.circular(3)),
    stroke,
  );
  canvas.drawLine(const Offset(12, 3), const Offset(12, 21), stroke);
  canvas.drawLine(const Offset(3, 12), const Offset(21, 12), stroke);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        const Rect.fromLTWH(13.6, 13.6, 5.8, 5.8), const Radius.circular(1)),
    fill,
  );
}

void _madalya(Canvas canvas, Paint stroke, Paint fill) {
  canvas.drawCircle(const Offset(12, 8.5), 5.5, stroke);
  canvas.drawPath(
    Path()
      ..moveTo(8.4, 12.7)
      ..lineTo(6.5, 21)
      ..lineTo(12, 18.2)
      ..lineTo(17.5, 21)
      ..lineTo(15.6, 12.7),
    stroke,
  );
}
