// Rütbe bilgi popup'ı — web `src/components/RankInfoModal.tsx` portu.
//
// Skor Kartı / oyuncu kartı BAŞLIĞINDAKİ mühre dokununca açılır. Kutlama
// banner'ının kart düzenini ve damga animasyonunu PAYLAŞIR (mühür her
// açılışta yeniden "damgalanır"); farkı: `seen_at`'e hiç dokunmaz (salt
// bilgi, sınırsız açılabilir) ve konfeti yok.
//
// "Toplam puana +N eşik ödülü dahildir" bilgisi de burada yaşıyor — web'de
// ScoreStatsSection'daki dipnottan buraya taşındı, portta o dipnot hiç
// olmadı.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/neo_box.dart';
import '../tokens.dart';
import 'league_rank.dart';
import 'rank_progress_bar.dart';
import 'rank_seal.dart';

Future<void> showRankInfo(
  BuildContext context, {
  required RankTier tier,
  required int totalScore,
  required int bonusPoints,
}) {
  return showDialog<void>(
    context: context,
    // Web: `bg-black/40` + dışarı tıklayınca kapanır.
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => RankInfoModal(
        tier: tier, totalScore: totalScore, bonusPoints: bonusPoints),
  );
}

class RankInfoModal extends StatefulWidget {
  final RankTier tier;
  final int totalScore;

  /// total_score'a dahil edilen eşik ödülü puanı
  /// (`player_stats_overall.bonus_points`).
  final int bonusPoints;

  const RankInfoModal({
    super.key,
    required this.tier,
    required this.totalScore,
    required this.bonusPoints,
  });

  @override
  State<RankInfoModal> createState() => _RankInfoModalState();
}

class _RankInfoModalState extends State<RankInfoModal>
    with SingleTickerProviderStateMixin {
  // Banner'ın kart+damga animasyonunun aynısı (konfeti/ödül satırı yok, o
  // yüzden toplam süre damganın bitişi = 1000ms).
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));

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

  double _phase(int startMs, int endMs, Curve curve) =>
      Interval(startMs / 1000, endMs / 1000, curve: curve).transform(_c.value);

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final next = nextTierAfter(tier);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final rise = _phase(100, 650, const Cubic(0.2, 0.9, 0.3, 1.2));
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Opacity(
            opacity: rise.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 26 * (1 - rise)),
              child: Transform.scale(
                scale: 0.96 + 0.04 * rise,
                child: SizedBox(
                  width: 280,
                  child: Container(
                    decoration: ShapeDecorationWithCssShadows(
                      color: kBg,
                      radius: 16,
                      // Nömorfik `kRaisedShadows` DEĞİL — karartılmış zeminde
                      // yüzen kart (bkz. kFloatingCardShadows'un gerekçesi).
                      shadows: kFloatingCardShadows,
                      borderColor: kBorder,
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _body(tier, next),
                          ),
                        ),
                        // Kapatma: kocaman bir "KAPAT" butonu yerine sağ
                        // üstte ✕ (12 Ağustos 2026, kullanıcı isteği) —
                        // projedeki TÜM modallerin (KModal) deseni bu, stil
                        // oradan birebir alındı. Banner'ın "DEVAM"ı KALIR:
                        // o gerçek bir aksiyon (ödülleri görüldü işaretler).
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Kapat',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close,
                                size: 18, color: kMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(RankTier tier, RankTier? next) {
    final stamp = _phase(500, 1000, const Cubic(0.25, 1.4, 0.4, 1));
    return [
      Center(child: _seal(tier, stamp)),
      const SizedBox(height: 10),
      Text(
        tier.name,
        textAlign: TextAlign.center,
        style: TextStyle(
            letterSpacing: kNoTracking,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: tier.color),
      ),
      const SizedBox(height: 6), // web mt-1.5
      Text(
        '${widget.totalScore} k-lig puanı',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontFamily: 'SpaceMono',
            letterSpacing: kNoTracking,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: kText),
      ),
      if (widget.bonusPoints > 0) ...[
        const SizedBox(height: 4),
        Text(
          '+${widget.bonusPoints} eşik ödülü dahil',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'SpaceMono',
              letterSpacing: kNoTracking,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: kGreen),
        ),
      ],
      const SizedBox(height: 8), // web mt-2
      Text(
        next != null
            ? 'Sıradaki rütbe: ${next.name} · ${next.threshold} puan'
            : 'En yüksek rütbedesin!',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontFamily: 'SpaceMono',
            letterSpacing: kNoTracking,
            fontSize: 11,
            color: kMuted),
      ),
      if (next != null) ...[
        const SizedBox(height: 6), // web mt-1.5
        RankProgressBar(
          fromThreshold: tier.threshold,
          toThreshold: next.threshold,
          current: widget.totalScore,
          // Dolgu SIRADAKİ kademenin rengi — hedefe doğru dolduğu için.
          fillColor: next.color,
          semanticsLabel: '${next.name} rütbesine ilerleme',
          fromReward: tier.reward,
          fromClaimed: rewardAlreadyClaimed(tier, widget.bonusPoints),
          toReward: next.reward,
          toClaimed: rewardAlreadyClaimed(next, widget.bonusPoints),
        ),
      ],
    ];
  }

  Widget _seal(RankTier tier, double t) {
    final double scale, rotation, opacity;
    if (t <= 0.7) {
      final k = t / 0.7;
      scale = 2.1 + (0.94 - 2.1) * k;
      rotation = -8 + 9 * k;
      opacity = k;
    } else {
      final k = (t - 0.7) / 0.3;
      scale = 0.94 + 0.06 * k;
      rotation = 1 - k;
      opacity = 1;
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: rotation * math.pi / 180,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: ShapeDecorationWithCssShadows(
              color: kPanel,
              radius: 44,
              shadows: kRaisedShadows,
            ),
            child: RankSeal(tier: tier, size: 76),
          ),
        ),
      ),
    );
  }
}
