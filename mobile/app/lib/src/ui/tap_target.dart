// Dokunma hedefi asgarisi — TEK kaynak.
//
// NEDEN VAR (24 Ağustos 2026): kullanıcı cihazda arka arkaya BEŞ kontrol
// bildirdi ve hepsini aynı cümleyle tarif etti — *"biraz üstüne basınca
// çalışıyor"*: alt şeridin üç linki, "Detaylı Kurallar", "← Geri" ve
// avatar. Küresel bir koordinat kayması DEĞİL (öyle olsa 24 px'lik tahta
// hücrelerine taş sürüklemek de bozulurdu; kullanıcı sorunsuz oynuyor) —
// hedeflerin tek tek KÜÇÜKLÜĞÜ.
//
// Ölçüldü (`test/tap_target_test.dart`, 390×844): alt şerit 31.0,
// "← Geri" 29.3, "Detaylı Kurallar" 14.0 px yüksekliğinde. Material'ın
// asgarisi (`kMinInteractiveDimension`) 48.
//
// Web'de bu sınıf hata YOK ve sebebi öğreticidir: DOM'da tıklama en
// içteki elemandan ATAYA doğru kabarır, yani küçük bir `<span>` bile
// kapsayıcı `<button>`ı tetikler. Flutter'da isabet testi kutuya bakar
// (`RenderBox.hitTest` önce `size.contains`) — kutunun DIŞINA taşan
// çocuk (bir `Stack`'te `Positioned` gibi) hiç dokunuş almaz. Web'den
// port ederken "aynı görünüyor" yetmez; kutunun kendisi taşınmalı.
import 'package:flutter/material.dart';

/// Material `kMinInteractiveDimension` — 48 dp. Bilinçli bir istisna
/// gerekirse gerekçesi hem koda hem `test/tap_target_test.dart`e yazılır.
const double kMinTapTarget = 48.0;

/// Çocuğu ortalayan, en az [min]×[min] boyutunda bir dokunma hedefi.
///
/// GÖRSELİ değiştirmez (çocuk kendi doğal boyutunda kalır, yalnızca
/// ortalanır); yalnızca dokunulabilir kutuyu büyütür. [onTap] verilmezse
/// salt bir boşluk ayırıcıdır — aynı satırdaki tıklanamaz öğeler (ayraç,
/// "Çevrimdışı" rozeti) hizada kalsın diye.
class TapTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double min;

  /// Yalnızca bir eksende istisna gerektiğinde ([min]'in yerini alır).
  /// Bugünkü tek örnek "← Geri": 48'lik bir YÜKSEKLİK header ile tahta
  /// arasına 20 px'lik boş bir bant açardı, oysa hemen üstündeki logo aynı
  /// eylem için zaten tam boy bir hedef (bkz. `game_header.dart`).
  final double? minWidth;
  final double? minHeight;

  const TapTarget({
    super.key,
    required this.child,
    this.onTap,
    this.min = kMinTapTarget,
    this.minWidth,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    // `Center(widthFactor: 1, heightFactor: 1)`: kutu çocuğun doğal
    // boyutunda BAŞLAR, sonra ConstrainedBox'ın asgarisine göre büyür
    // (RenderPositionedBox boyutunu `constraints.constrain(...)`tan
    // geçirir). Faktörsüz `Center` gelen sınırların TAMAMINI kaplardı —
    // bir `Row` içinde bu genişliği sonsuza götürür.
    final box = ConstrainedBox(
      constraints: BoxConstraints(
          minWidth: minWidth ?? min, minHeight: minHeight ?? min),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
    if (onTap == null) return box;
    return GestureDetector(
      onTap: onTap,
      // Şeffaf boşluk da dokunuş almalı — asıl mesele zaten bu.
      behavior: HitTestBehavior.opaque,
      child: box,
    );
  }
}
