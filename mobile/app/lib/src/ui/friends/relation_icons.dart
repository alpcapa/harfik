// Kelimeki — web `src/components/RelationIcons.tsx`in ELLE SENKRON ikizi.
//
// Bu dosyada YALNIZCA bir ikon var, çünkü ilişki ikonlarının dördünden üçü
// gerçek Material glyph'i (`Icons.person_add_alt_1` / `Icons.how_to_reg` /
// `Icons.person_remove`) ve port onları doğrudan `Icons.*` ile çiziyor —
// font gömülü olduğundan iki platform BENZER değil AYNI vektörü gösteriyor.
//
// Dördüncüsünün ("istek gönderildi, bekliyor") Material'da karşılığı YOK:
// kişi + küçük kum saati diye bir glyph yok. Öncesinde düz
// `Icons.hourglass_top` çiziliyordu — kişisiz, tek başına duran büyük bir kum
// saati; üçü kişi+rozetken bu biri aileden kopuktu (kullanıcı 30 Ağustos
// 2026'da bildirdi). `hourglass_top`u rozet kutusuna küçültmek çare değil:
// glyph'in çizgileri ~1 birim, yarıya inince 20 px'lik ikonda 0,42 px kalıyor.
//
// ⚠ **WEB İKİZİYLE ELLE SENKRON — ama senkronu ZORLAYAN bir test var:**
// `test/relation_icon_parity_test.dart` iki dosyayı da okuyup geometriyi
// birebir karşılaştırıyor (`OzellikIkonlari` ↔ `ozellik_ikonlari.dart`
// çiftindeki aynı yöntem, ortak ayrıştırıcı `test/support/vector_parity.dart`).
// Buradaki bir koordinatı değiştirirsen o test düşer — web kopyasını da
// güncelle.
import 'package:flutter/widgets.dart';

/// Web `PersonPendingIcon` — kişi + küçük kum saati, 24'lük viewBox.
class PersonPendingIcon extends StatelessWidget {
  const PersonPendingIcon({super.key, this.size = 20, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _PersonPendingPainter(color)),
      );
}

class _PersonPendingPainter extends CustomPainter {
  const _PersonPendingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(_kisi(), fill);
    canvas.drawPath(_kumSaati(), fill);
    canvas.restore();
  }

  /// `Icons.person_add_alt_1` glyph'inin kişi kısmı — artı işareti ÇIKARILMIŞ,
  /// tek bir koordinat oynatılmadan. Web'deki ilk `<path>`in aynısı.
  Path _kisi() => Path()
    // Baş.
    ..moveTo(12.984375, 8.015625)
    ..cubicTo(12.984375, 5.8125, 11.203125, 3.984375, 9.0, 3.984375)
    ..cubicTo(6.796875, 3.984375, 5.015625, 5.8125, 5.015625, 8.015625)
    ..cubicTo(5.015625, 10.21875, 6.796875, 12.0, 9.0, 12.0)
    ..cubicTo(11.203125, 12.0, 12.984375, 10.21875, 12.984375, 8.015625)
    ..close()
    // Omuzlar.
    ..moveTo(0.984375, 18.0)
    ..lineTo(0.984375, 20.015625)
    ..lineTo(17.015625, 20.015625)
    ..lineTo(17.015625, 18.0)
    ..cubicTo(17.015625, 15.328125, 11.671875, 14.015625, 9.0, 14.015625)
    ..cubicTo(6.328125, 14.015625, 0.984375, 15.328125, 0.984375, 18.0)
    ..close();

  /// Rozet — `person_add`in ARTI işaretinin durduğu kutuda (x 15→23,
  /// y 6,98→15). Tek kapalı silüet: iki kapak + ortada (19, 11) noktasında
  /// birleşen iki üçgen. Dolu çizildiğinden 20 px'te de okunuyor.
  Path _kumSaati() => Path()
    ..moveTo(15.5, 6.5)
    ..lineTo(22.5, 6.5)
    ..lineTo(22.5, 8.5)
    ..lineTo(21.6, 8.5)
    ..lineTo(19.0, 11.0)
    ..lineTo(21.6, 13.5)
    ..lineTo(22.5, 13.5)
    ..lineTo(22.5, 15.5)
    ..lineTo(15.5, 15.5)
    ..lineTo(15.5, 13.5)
    ..lineTo(16.4, 13.5)
    ..lineTo(19.0, 11.0)
    ..lineTo(16.4, 8.5)
    ..lineTo(15.5, 8.5)
    ..close();

  @override
  bool shouldRepaint(_PersonPendingPainter old) => old.color != color;
}
