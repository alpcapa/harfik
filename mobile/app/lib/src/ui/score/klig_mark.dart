// "k-lig" wordmark — web KLigMark.tsx'in Flutter karşılığı. Path verisi AYNI
// üreticiden gelir (scripts/generate-klig-paths.mjs artık klig_mark_data.dart'ı
// da yazar), yani marka değişirse tek komut iki tarafı birden günceller.
//
// `LogoMark`'ın aksine altında swash/underline yok; `parseSvgPath` oradan
// paylaşılır (aynı üreticinin MUTLAK M/L/Q/C/Z komutları).
import 'package:flutter/material.dart';

import '../game/logo_mark.dart' show parseSvgPath;
import 'klig_mark_data.dart';
import '../tokens.dart';

class KLigMark extends StatelessWidget {
  final double height;

  /// Web'de `color` prop'u `currentColor` ile çevresindeki metnin rengini
  /// miras alabiliyor; burada da çağıran (muted/accent) geçebilir.
  final Color? color;
  const KLigMark({super.key, required this.height, this.color});

  @override
  Widget build(BuildContext context) {
    final vb = kligViewBox.split(' ').map(double.parse).toList();
    return SizedBox(
      height: height,
      width: height * vb[2] / vb[3],
      child: CustomPaint(
        painter: _KLigPainter(color ?? const Color(kligColorValue)),
      ),
    );
  }
}

class _KLigPainter extends CustomPainter {
  final Color color;
  const _KLigPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final vb = kligViewBox.split(' ').map(double.parse).toList();
    canvas.save();
    canvas.scale(size.height / vb[3]);
    canvas.translate(-vb[0], -vb[1]);
    canvas.drawPath(parseSvgPath(kligTextPath), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KLigPainter old) => old.color != color;
}

/// Web `ScoreCard.tsx`/`PlayerScoreCard.tsx`'in KLigMark'ın hemen yanında
/// çizdiği küçük "?" bilgi rozeti (`w-3.5 h-3.5 rounded-full border
/// border-muted`) — yalnızca kendi kartı/başkasının kartındaki k-lig
/// düğmesinde var, `UserMenu`/`Leaderboard` başlığında YOK (web kaynağı
/// bilerek üç ayrı yerde kontrol edildi, hiçbiri "hepsine ekle" varsayımıyla
/// genelleştirilmedi — 9 Ağustos 2026, kullanıcı ekran görüntüsüyle bildirdi).
class KLigInfoBadge extends StatelessWidget {
  const KLigInfoBadge({super.key});

  static const _muted = kMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _muted, width: 1),
      ),
      child: const Text(
        '?',
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1,
          color: _muted,
        ),
      ),
    );
  }
}
