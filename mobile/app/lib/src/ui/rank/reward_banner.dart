// k-lig kutlama banner'ı — web `src/components/RewardBanner.tsx` +
// `index.css`'teki `reward-*` keyframe'lerinin portu (Parça 61).
//
// Kart alttan yaylanarak gelir, mühür 2.1× boyuttan küçülerek damgalanır,
// konfeti patlar, ödül satırı en son belirir. Görülmemiş `league_rewards`
// satırlarından `LeagueRewardsHost`un ürettiği TEK birleşik özeti gösterir
// (satır başına ayrı popup yok — geçmişe dönük backfill'de bile tek banner).
//
// ActionSheet dersi (kök CLAUDE.md): alt/kenar yerine EKRAN ORTASINDA açılır
// ve arka planı karartır — web'de animasyon `visible` bir rAF sonrası true
// olduğunda başlıyor; Flutter'da karşılığı ilk kareden sonra ileri sarılan
// tek bir `AnimationController`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/neo_box.dart';
import '../tokens.dart';
import 'league_rank.dart';
import 'rank_progress_bar.dart';
import 'rank_seal.dart';

/// Rütbe düşüş bildirimi — YALNIZCA hiçbir olumlu olay yokken doldurulur
/// (host öncelik kuralı: olumlu varsa üzgün banner bastırılır).
class RankDownInfo {
  /// Altına inilen eşik.
  final int fromThreshold;

  /// Yeni (alt) kademe.
  final RankTier newTier;

  /// Banner anındaki güncel toplam — ilerleme çubuğu için; host ayrıca
  /// çeker, çekilemezse çubuk gizlenir.
  final int? currentPoints;

  const RankDownInfo({
    required this.fromThreshold,
    required this.newTier,
    this.currentPoints,
  });

  RankDownInfo withPoints(int? points) => RankDownInfo(
      fromThreshold: fromThreshold, newTier: newTier, currentPoints: points);
}

/// Host'un görülmemiş satırlardan damıttığı birleşik özet (web
/// `RewardSummary`).
class RewardSummary {
  /// Yeni ulaşılan en yüksek rütbe (varsa) — banner'ın ana konusu olur.
  final RankTier? rankUpTier;

  /// Ulaşılan en yüksek puan kilometre taşı (100/200/300…).
  final int? milestone;

  /// Kazanılan toplam eşik ödülü puanı (0 = yok).
  final int rewardPoints;

  /// Ödülü tetikleyen en yüksek PUAN eşiği (50/100/200/500/1000).
  final int? rewardThreshold;

  final RankDownInfo? rankDown;

  const RewardSummary({
    this.rankUpTier,
    this.milestone,
    this.rewardPoints = 0,
    this.rewardThreshold,
    this.rankDown,
  });

  bool get isEmpty =>
      rankUpTier == null &&
      milestone == null &&
      rewardPoints == 0 &&
      rankDown == null;

  RewardSummary withRankDown(RankDownInfo? d) => RewardSummary(
        rankUpTier: rankUpTier,
        milestone: milestone,
        rewardPoints: rewardPoints,
        rewardThreshold: rewardThreshold,
        rankDown: d,
      );
}

// Konfeti parçacıkları — merkezden dışa savrulan 8 nokta (web CONFETTI
// dizisi, dx/dy px cinsinden birebir).
const _confetti = <({double dx, double dy, Color color})>[
  (dx: -90, dy: -70, color: kAccent),
  (dx: 80, dy: -90, color: kGold),
  (dx: -110, dy: 10, color: kGreen),
  (dx: 110, dy: -10, color: kOrange),
  (dx: -60, dy: -110, color: kRed),
  (dx: 55, dy: -120, color: kAccent),
  (dx: -95, dy: -30, color: kOrange),
  (dx: 95, dy: 40, color: kGreen),
];

/// Toplam süre — en geç biten animasyon konfeti (650ms gecikme + 900ms).
const _kTotalMs = 1550;

double _at(int ms) => ms / _kTotalMs;

class RewardBanner extends StatefulWidget {
  final RewardSummary summary;
  final VoidCallback onClose;

  const RewardBanner({
    super.key,
    required this.summary,
    required this.onClose,
  });

  @override
  State<RewardBanner> createState() => _RewardBannerState();
}

class _RewardBannerState extends State<RewardBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _kTotalMs));

  /// `prefers-reduced-motion` karşılığı — konfeti hiç çizilmez, diğerleri
  /// son durumlarında belirir (web'in aynı media query bloğu).
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (_reduced) {
        _c.value = 1;
      } else {
        _c.forward();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _phase(int startMs, int endMs, Curve curve) =>
      Interval(_at(startMs), _at(endMs), curve: curve).transform(_c.value);

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final rankDown = s.rankDown;
    // Öncelik: rütbe atlama > kilometre taşı > yalnızca eşik ödülü.
    final tier = rankDown != null
        ? rankDown.newTier
        : (s.rankUpTier ?? tierFor(s.milestone ?? s.rewardThreshold ?? 0));
    final glyph = rankDown != null
        ? rankDown.newTier.letter
        : s.rankUpTier != null
            ? s.rankUpTier!.letter
            : s.milestone != null
                ? '${s.milestone}'
                : '+${s.rewardPoints}';
    final title = rankDown != null
        ? 'Rütben geriledi!'
        : s.rankUpTier != null
            ? 'Yeni rütben: ${s.rankUpTier!.name}!'
            : s.milestone != null
                ? '${s.milestone} k-lig puanına ulaştın!'
                : 'Eşik ödülü kazandın!';
    // "X k-lig puanına ulaştın" alt satırı — ulaşılan en yüksek eşik.
    // Başlık aynı bilgiyi zaten veren milestone-only durumda tekrarlanmaz.
    final reached = [
      s.rankUpTier?.threshold ?? 0,
      s.milestone ?? 0,
      s.rewardThreshold ?? 0,
    ].reduce(math.max);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final barrier = Interval(0, _at(300)).transform(_c.value);
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  // web bg-black/40
                  color: Colors.black.withValues(alpha: 0.4 * barrier),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _card(context, tier, glyph, title, reached, rankDown),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, RankTier tier, String glyph, String title,
      int reached, RankDownInfo? rankDown) {
    final s = widget.summary;
    // web: reward-rise — translateY 26→0, scale .96→1, opacity 0→1.
    final rise = _phase(100, 650, const Cubic(0.2, 0.9, 0.3, 1.2));
    final content = Opacity(
      opacity: rise.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 26 * (1 - rise)),
        child: Transform.scale(
          scale: 0.96 + 0.04 * rise,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _seal(tier, glyph),
              const SizedBox(height: 10), // web mb-2.5
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    letterSpacing: kNoTracking,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kText),
              ),
              if (rankDown != null)
                ..._rankDownBody(rankDown)
              else
                ..._celebrationBody(s, reached),
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      width: 280,
      child: Stack(
        // Konfeti kartın DIŞINA savruluyor (web overflow-visible).
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: ShapeDecorationWithCssShadows(
              color: kBg,
              radius: 16, // web rounded-2xl
              // Nömorfik `kRaisedShadows` DEĞİL (12 Ağustos 2026) — bkz.
              // kFloatingCardShadows. RankInfoModal'ın kartı da aynı gün
              // aynı gölgeye çekildi; ikisi AYNI kart, biri değişirse öteki
              // de değişmeli.
              shadows: kFloatingCardShadows,
              borderColor: kBorder,
            ),
            child: content,
          ),
          // Kapatma: tam genişlikte bir "DEVAM" butonu yerine sağ üstte ✕
          // (12 Ağustos 2026, kullanıcı isteği — RankInfoModal'a uygulanan
          // aynı kararın banner'lara da genişletilmesi: "bu banner'larda
          // kapat, devam vb olmamalı, sadece X"). Stil KModal/
          // RankInfoModal ile birebir; iki kart aynı, biri değişirse öteki
          // de.
          //
          // DİKKAT — bu buton yalnızca kapatmıyor: `onClose`
          // `mark_league_rewards_seen`'i çağıran TEK yol (bkz.
          // `LeagueRewardsHost._close`). "DEVAM" buraya çevrilirken aynı
          // callback'e bağlı kaldı; başka bir kapatma yolu eklenirse (ör.
          // zemine dokunma) o da `onClose`'tan geçmeli, aksi halde banner
          // her açılışta yeniden çıkar.
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Kapat',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, size: 18, color: kMuted),
            ),
          ),
          if (rankDown == null && !_reduced)
            Positioned.fill(child: IgnorePointer(child: _confettiLayer())),
        ],
      ),
    );
  }

  /// Mühür — 88px nömorfik daire içinde 76px damga; web `reward-stamp`
  /// keyframe'i (2.1× → 0.94× → 1, -8° → 1° → 0).
  Widget _seal(RankTier tier, String glyph) {
    final t = _phase(500, 1000, const Cubic(0.25, 1.4, 0.4, 1));
    // Keyframe kırılımı %70'te.
    final double scale, rotation, opacity;
    if (t <= 0.7) {
      final k = t / 0.7;
      scale = 2.1 + (0.94 - 2.1) * k;
      rotation = -8 + (1 - (-8)) * k;
      opacity = k;
    } else {
      final k = (t - 0.7) / 0.3;
      scale = 0.94 + (1 - 0.94) * k;
      rotation = 1 + (0 - 1) * k;
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
            child: RankSeal(tier: tier, glyph: glyph, size: 76),
          ),
        ),
      ),
    );
  }

  List<Widget> _celebrationBody(RewardSummary s, int reached) => [
        if ((s.rankUpTier != null ||
                (s.milestone == null && s.rewardThreshold != null)) &&
            reached > 0) ...[
          const SizedBox(height: 4), // web mt-1
          Text(
            '$reached k-lig puanına ulaştın',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'SpaceMono',
                letterSpacing: kNoTracking,
                fontSize: 11,
                color: kMuted),
          ),
        ],
        if (s.rewardPoints > 0) ...[
          const SizedBox(height: 6), // web mt-1.5
          _line(Text(
            '+${s.rewardPoints} ödül puanı eklendi',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'SpaceMono',
                letterSpacing: kNoTracking,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kGreen),
          )),
        ],
      ];

  List<Widget> _rankDownBody(RankDownInfo d) => [
        const SizedBox(height: 4),
        // Sayıya iyelik eki YOK ("50'nin/100'ün" ünlü uyumu isme göre
        // değişirdi) — "X eşiğinin altına" kalıbı her eşikte çalışır
        // (kök CLAUDE.md "Sıra: {isim}" dersi).
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: 'Üzgünüz — puanın ${d.fromThreshold} eşiğinin altına '
                    'indi. Yeni rütben: '),
            TextSpan(
              text: d.newTier.name,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: d.newTier.color),
            ),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'SpaceMono',
              letterSpacing: kNoTracking,
              fontSize: 11,
              color: kMuted),
        ),
        const SizedBox(height: 6),
        _line(const Text(
          'Kazandıkça geri yükselirsin!',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'SpaceMono',
              letterSpacing: kNoTracking,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: kAccent),
        )),
        if (d.currentPoints != null) ...[
          const SizedBox(height: 8), // web mt-2
          RankProgressBar(
            fromThreshold: d.newTier.threshold,
            toThreshold: d.fromThreshold,
            current: d.currentPoints!,
            fillColor: tierFor(d.fromThreshold).color,
            semanticsLabel: 'Kaybedilen rütbeye geri dönüş ilerlemesi',
            fromReward: d.newTier.reward,
            // Alt kademenin ödülü de alınmış durumda (Çaylak'ta ödül yok,
            // rozet hiç çizilmez).
            fromClaimed: true,
            toReward: tierFor(d.fromThreshold).reward,
            // Düşülen eşiğin ödülü ZATEN alındı — geri düşmek yeşil ✓'yı
            // götürmez, yeniden aşmak ikinci kez VERMEZ.
            toClaimed: true,
          ),
        ],
      ];

  /// web `reward-fadeup` — 1s gecikmeli, 6px aşağıdan.
  Widget _line(Widget child) {
    final t = _phase(1000, 1400, Curves.ease);
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: child),
    );
  }

  Widget _confettiLayer() {
    // web `reward-burst` — 650ms gecikme, 900ms; merkezden savrulup söner.
    final t = _phase(650, 1550, const Cubic(0.15, 0.8, 0.4, 1));
    if (t <= 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (final c in _confetti)
            Positioned(
              // web: left-1/2 top-[38%]
              left: constraints.maxWidth / 2,
              top: constraints.maxHeight * 0.38,
              child: Transform.translate(
                offset: Offset(c.dx * t, c.dy * t),
                child: Transform.rotate(
                  angle: 240 * t * math.pi / 180,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: c.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
