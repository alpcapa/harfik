// Rütbe ilerleme çubuğu — İKİ yerde birebir aynı görünüyor: bilgi
// popup'ındaki "sıradaki rütbeye ilerleme" (`RankInfoModal`) ve düşüş
// banner'ındaki "kaybedilen eşiğe geri dönüş" (`RewardBanner`). Web ikisini
// ayrı ayrı yazdı; port `showInvasionConfirm` ile aynı gerekçeyle (aynı
// metin + aynı vurgu kuralı, iki kopya sessizce ayrışır) tek dosyaya aldı.
//
// Rozet renk kuralı (12 Ağustos 2026, kullanıcı kararı): YEŞİL + ✓ yalnızca
// ALINMIŞ ödülde — kişi sonradan eşiğin altına düşse bile yeşil ✓ kalır
// (ödül geri alınmıyor, yeniden aşmak ikinci kez VERMEZ); henüz alınmamış
// hedef ödülü GRİ, ✓'sız.
library;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Web `text-[9px] font-mono` etiket puntosu.
const double _kLabelSize = 9;

/// ✓ glyph'i fontta em yüksekliğinin ~yarısı kadar mürekkep bıraktığından
/// aynı puntoda küçük görünüyor — web'de 9px metnin yanında 13px'e
/// büyütülüp ölçülerek doğrulandı; port aynı oranı taşıyor.
const double _kCheckSize = 13;

/// Web'de bu metinlerde letter-spacing YOK. Material 3'ün varsayılan
/// `TextTheme.bodyMedium`'u 0.25 taşıyor ve açıkça sıfırlanmazsa MİRAS
/// ALINIYOR — ölçüldü: "Sıradaki rütbe: Oyuncu · 100 puan" 33 karakterde
/// tam 8.25px şişip 230px'lik karta sığmıyor ve iki satıra düşüyordu
/// (Chromium'da gerçek fontla aynı metin 222.16px, tek satır).
const double kNoTracking = 0;

class RankProgressBar extends StatefulWidget {
  /// Sol etiket (mevcut/alt kademenin eşiği).
  final int fromThreshold;

  /// Sağ etiket (hedef eşik) — "N puan" olarak yazılır.
  final int toThreshold;

  /// Ortadaki güncel toplam.
  final int current;

  /// Dolgu rengi — bilgi popup'ında SIRADAKİ kademenin, düşüş banner'ında
  /// DÜŞÜLEN kademenin rengi (ikisi de "hedefin rengi").
  final Color fillColor;

  /// Sol/sağ eşiğin tek seferlik ödülü (0 → rozet çizilmez).
  final int fromReward;
  final int toReward;

  /// Ödül alınmış mı — yeşil + ✓ / gri.
  final bool fromClaimed;
  final bool toClaimed;

  final String semanticsLabel;

  const RankProgressBar({
    super.key,
    required this.fromThreshold,
    required this.toThreshold,
    required this.current,
    required this.fillColor,
    required this.semanticsLabel,
    this.fromReward = 0,
    this.toReward = 0,
    this.fromClaimed = false,
    this.toClaimed = false,
  });

  @override
  State<RankProgressBar> createState() => _RankProgressBarState();
}

class _RankProgressBarState extends State<RankProgressBar>
    with SingleTickerProviderStateMixin {
  // Web: `transition-[width] duration-700 ease-out`, dolgu ilk karede 0'dan
  // gerçek orana akar (kart görünür olduktan SONRA — `visible` bir rAF
  // sonrası true).
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _ratio {
    final span = widget.toThreshold - widget.fromThreshold;
    if (span <= 0) return 1;
    return ((widget.current - widget.fromThreshold) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: widget.semanticsLabel,
          value: '${widget.current}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4), // web rounded-full, h-2
            child: Container(
              height: 8, // web h-2
              decoration: BoxDecoration(
                color: kPanel,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _ratio * Curves.easeOut.transform(_c.value),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.fillColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2), // web mt-0.5
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _EdgeLabel(
              text: '${widget.fromThreshold}',
              reward: widget.fromReward,
              claimed: widget.fromClaimed,
              alignment: CrossAxisAlignment.start,
            ),
            Text(
              '${widget.current}',
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: _kLabelSize,
                fontWeight: FontWeight.bold,
                letterSpacing: kNoTracking,
                color: kText,
              ),
            ),
            _EdgeLabel(
              text: '${widget.toThreshold} puan',
              reward: widget.toReward,
              claimed: widget.toClaimed,
              alignment: CrossAxisAlignment.end,
            ),
          ],
        ),
      ],
    );
  }
}

class _EdgeLabel extends StatelessWidget {
  final String text;
  final int reward;
  final bool claimed;
  final CrossAxisAlignment alignment;

  const _EdgeLabel({
    required this.text,
    required this.reward,
    required this.claimed,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontFamily: 'SpaceMono',
      fontSize: _kLabelSize,
      height: 1.25, // web leading-tight
      letterSpacing: kNoTracking,
      color: kMuted,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(text, style: base),
        if (reward > 0) RewardBadge(reward: reward, claimed: claimed),
      ],
    );
  }
}

/// Bir eşiğin tek seferlik ödül rozeti — "(+5)" ve ALINMIŞSA hemen yanında
/// (boşluksuz) daha büyük bir onay işareti.
///
/// ✓ web'de düz bir `✓` karakteri; portta Material'ın `Icons.check`'i
/// KULLANILIYOR çünkü Space Mono bu glyph'i İÇERMİYOR — tarayıcı sessizce
/// bir yedek fonta düşüyor (Chromium'da doğrulandı), Flutter ise tofu
/// (boş kutu) çiziyordu (ekran görüntüsünde yakalandı). Material ikon fontu
/// her platformda ve testlerde garanti mevcut.
class RewardBadge extends StatelessWidget {
  final int reward;
  final bool claimed;
  const RewardBadge({super.key, required this.reward, required this.claimed});

  @override
  Widget build(BuildContext context) {
    final color = claimed ? kGreen : kMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '(+$reward)',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: _kLabelSize,
            height: 1.25,
            letterSpacing: kNoTracking,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (claimed) Icon(Icons.check, size: _kCheckSize, color: color),
      ],
    );
  }
}
