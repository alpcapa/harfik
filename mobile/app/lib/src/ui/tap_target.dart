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

  /// Çocuğun büyütülmüş kutu içindeki yeri. Varsayılan ORTA; ama bir kenara
  /// HİZALI duran metinlerde ortalamak hizayı bozar — "← Geri" tahtanın sol
  /// kenarıyla (12 px) hizalı olmak zorunda ve metni 48 px'lik kutuda
  /// ortalamak onu 4 px sağa kaydırıyordu (CI yakaladı, 24 Ağustos 2026).
  final Alignment alignment;

  const TapTarget({
    super.key,
    required this.child,
    this.onTap,
    this.min = kMinTapTarget,
    this.minWidth,
    this.minHeight,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    // `Align(widthFactor: 1, heightFactor: 1)`: kutu çocuğun doğal
    // boyutunda BAŞLAR, sonra ConstrainedBox'ın asgarisine göre büyür
    // (RenderPositionedBox boyutunu `constraints.constrain(...)`tan
    // geçirir). Faktörsüz olsaydı gelen sınırların TAMAMINI kaplardı —
    // bir `Row` içinde bu genişliği sonsuza götürür.
    final box = ConstrainedBox(
      constraints: BoxConstraints(
          minWidth: minWidth ?? min, minHeight: minHeight ?? min),
      child: Align(
          alignment: alignment,
          widthFactor: 1,
          heightFactor: 1,
          child: child),
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

/// Başlıktaki/köşedeki ikon butonu (✕, dişli) — **48×48 dokunma kutusu**,
/// ikon ortada.
///
/// NEDEN VAR (27 Ağustos 2026, kullanıcı bildirdi: *"bazı tıklamalar yine
/// biraz üstte gibi. Mesela skor kartı x'de dikkatimi çekti"*): 24 Ağustos'un
/// 48 dp turu bu butonları HİÇ ölçmemişti. Sebebi kaynak taramasının kendi
/// kuralıydı — `IconButton` "kutusuna ölçü veren" işaretlerden biri sayılıyor,
/// yani `IconButton` gören tarama o dokunulabiliri güvende varsayıp geçiyordu.
/// Oysa Material'ın `IconButton`'ı `visualDensity: compact` ile **40×40**'a,
/// `padding: EdgeInsets.zero` ile daha da aşağı iner. Ölçüldü (390×844):
///
///   KModal ✕        40.0 × 40.0
///   KDialogCard ✕   28.0 × 28.0   ← web'in `w-7 h-7`'si birebir taşınmıştı
///
/// ⚠ **Görsel DEĞİŞMEZ.** Büyüyen yalnızca dokunma kutusu; çağıran, kutunun
/// büyüdüğü kadar kendi dolgusunu/konumunu kısar (KModal başlığında
/// `20/16` → `16/12`, köşe butonlarında `Positioned` 8 → 4). Bu, projenin
/// hamle rozetinde uyguladığı aynı takas (13 Ağustos 2026): dokunma alanı
/// büyürken ikonun ekrandaki yeri birebir aynı kalır.
class KIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;
  final Color color;

  const KIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        padding: EdgeInsets.zero,
        // `visualDensity` VERİLMEZ — `compact` tam olarak kutuyu 48'den
        // 40'a indiren şeydi.
        constraints: const BoxConstraints(
            minWidth: kMinTapTarget, minHeight: kMinTapTarget),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize, color: color),
      );
}
