// k-lig kutlama banner'ının sürücüsü — web `src/components/
// LeagueRewardsHost.tsx` portu (Parça 61).
//
// Görülmemiş `league_rewards` satırlarını çekip TEK birleşik [RewardBanner]
// gösterir, "Devam"da hepsini `mark_league_rewards_seen` ile işaretler
// (sunucu tarafı `seen_at` = cihazdan bağımsız "bir kez göster" garantisi).
//
// ## Mimari: web'de üç mount, portta da üç — ama Flutter'da dallar
// birbirini DIŞLAMIYOR
//
// Web'de App.tsx erken return'lerle dallandığından aynı anda hep en fazla
// bir host yaşıyor; modül seviyesindeki `requestCheck` kaydı bu yüzden
// güvenli. Flutter'da `SetupScreen` `MaterialApp.home`'dur ve oyun ekranları
// onun ÜZERİNE `Navigator.push` edilir — yani Setup'ın host'u oyun sırasında
// da MOUNT KALIR. İki host aynı anda çekip iki banner göstermesin diye
// host'lar modül seviyesinde bir yığına kaydolur ve YALNIZCA EN ÜSTTEKİ
// (en son mount olan) çalışır. Yığın Navigator'ın kendisiyle aynı sırayı
// izler; bir oyun ekranı pop edilince Setup'ın host'u yeniden etkinleşir ve
// kendiliğinden bir kontrol koşar.
//
// `suppress` semantiği web ile birebir: oyun ortasında (bitmemişken)
// banner'ın odak çalmasını önler — bayrak düşünce (oyun bitince) otomatik
// bir kontrol tetiklenir.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/league_rewards_api.dart';
import '../../data/stats_api.dart';
import 'league_rank.dart';
import 'reward_banner.dart';

/// Mount sırasına göre host yığını — yalnızca sonuncusu (en üstteki ekran)
/// etkin.
final List<_LeagueRewardsHostState> _hosts = <_LeagueRewardsHostState>[];

/// Bir `games` kaydının sunucuya GERÇEKTEN düştüğü an çağrılır (yerel oyunun
/// bitiş kaydı). Trigger ödülü aynı transaction'da açtığından hemen ardından
/// çekmek güvenli. Etkin host yoksa sessiz no-op — bir sonraki mount/öne
/// dönüş kontrolü zaten yakalar.
void requestLeagueRewardCheck() {
  if (_hosts.isNotEmpty) _hosts.last.check();
}

/// Testler arası sızıntıyı önlemek için (her testWidgets kendi ağacını
/// kurar; unmount edilmeyen bir host yığında kalırsa sonraki testi bozar).
@visibleForTesting
void debugResetLeagueRewardHosts() => _hosts.clear();

/// Görülmemiş satırlardan TEK birleşik özet — web `buildSummary` birebir.
///
/// Öncelik kuralı: görülmemiş OLUMLU bir olay (ödül/kutlama/rütbe) varsa
/// üzgün banner BASTIRILIR — ikisi aynı anda bekliyorsa net mesaj olumlu
/// olandır; `rank_down` satırı "Devam"la birlikte sessizce görüldü sayılır.
RewardSummary buildRewardSummary(List<LeagueReward> rows) {
  var rewardPoints = 0;
  int? rewardThreshold;
  int? rankUpThreshold;
  int? milestone;
  int? rankDownThreshold;
  for (final r in rows) {
    switch (r.kind) {
      case LeagueRewardKind.pointsReward:
        rewardPoints += r.points;
        if (rewardThreshold == null || r.threshold > rewardThreshold) {
          rewardThreshold = r.threshold;
        }
      case LeagueRewardKind.rankUp:
        if (rankUpThreshold == null || r.threshold > rankUpThreshold) {
          rankUpThreshold = r.threshold;
        }
      case LeagueRewardKind.pointsMilestone:
        if (milestone == null || r.threshold > milestone) {
          milestone = r.threshold;
        }
      case LeagueRewardKind.rankDown:
        // En DÜŞÜK eşiği al — art arda düşüşlerde güncel duruma en yakın.
        if (rankDownThreshold == null || r.threshold < rankDownThreshold) {
          rankDownThreshold = r.threshold;
        }
      case LeagueRewardKind.unknown:
        break; // ileride eklenen bir tür — eski istemci banner UYDURMAZ
    }
  }
  final hasPositive =
      rankUpThreshold != null || milestone != null || rewardPoints > 0;
  return RewardSummary(
    rankUpTier: rankUpThreshold == null ? null : tierFor(rankUpThreshold),
    milestone: milestone,
    rewardPoints: rewardPoints,
    rewardThreshold: rewardThreshold,
    rankDown: !hasPositive && rankDownThreshold != null
        ? RankDownInfo(
            fromThreshold: rankDownThreshold,
            newTier: tierFor(rankDownThreshold - 1),
          )
        : null,
  );
}

class LeagueRewardsHost extends StatefulWidget {
  /// Misafirde / Supabase yokken null → host tamamen no-op.
  final LeagueRewardsRepo? rewards;
  final AuthService? auth;

  /// Düşüş banner'ının ilerleme çubuğu güncel toplamı ister — tek RPC;
  /// null ya da çekilemezse çubuk gizli kalır, banner yine gösterilir.
  final StatsRepo? stats;

  /// Oyun SÜRERKEN true — banner odak çalmaz; bayrak düşünce kontrol edilir.
  final bool suppress;

  final Widget child;

  const LeagueRewardsHost({
    super.key,
    required this.child,
    this.rewards,
    this.auth,
    this.stats,
    this.suppress = false,
  });

  @override
  State<LeagueRewardsHost> createState() => _LeagueRewardsHostState();
}

class _LeagueRewardsHostState extends State<LeagueRewardsHost>
    with WidgetsBindingObserver {
  RewardSummary? _summary;
  bool _inFlight = false;
  Timer? _wakeDebounce;
  String? _lastUserId;

  bool get _isActive => _hosts.isNotEmpty && identical(_hosts.last, this);

  @override
  void initState() {
    super.initState();
    _hosts.add(this);
    WidgetsBinding.instance.addObserver(this);
    _lastUserId = widget.auth?.user?.id;
    widget.auth?.addListener(_onAuth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) check();
    });
  }

  @override
  void dispose() {
    _wakeDebounce?.cancel();
    widget.auth?.removeListener(_onAuth);
    WidgetsBinding.instance.removeObserver(this);
    _hosts.remove(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(LeagueRewardsHost old) {
    super.didUpdateWidget(old);
    if (old.auth != widget.auth) {
      old.auth?.removeListener(_onAuth);
      widget.auth?.addListener(_onAuth);
    }
    // suppress DÜŞTÜ (oyun bitti) → bekleyen kutlamayı hemen göster.
    if (old.suppress && !widget.suppress) check();
  }

  /// Hesap DEĞİŞİMİ — `user` referansı değil `user.id` karşılaştırılır:
  /// `onAuthStateChange` `tokenRefreshed`'i saatte bir TAZE bir User
  /// nesnesiyle yayınlıyor (bkz. `AccountScope` / kök CLAUDE.md dersi),
  /// referansa bakan bir sıfırlama açık banner'ı saatlik olarak düşürürdü.
  void _onAuth() {
    final id = widget.auth?.user?.id;
    if (id == _lastUserId) return;
    _lastUserId = id;
    if (mounted) setState(() => _summary = null); // başka hesabın kutlaması
    check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Projedeki standart 300ms debounce (öne dönüşte birden çok sinyal).
    _wakeDebounce?.cancel();
    _wakeDebounce = Timer(const Duration(milliseconds: 300), check);
  }

  Future<void> check() async {
    final repo = widget.rewards;
    final userId = widget.auth?.user?.id;
    if (repo == null ||
        userId == null ||
        widget.suppress ||
        _inFlight ||
        _summary != null ||
        !_isActive) {
      return;
    }
    _inFlight = true;
    try {
      final rows = await repo.unseen(userId);
      if (!mounted || rows.isEmpty || widget.suppress || _summary != null) {
        return;
      }
      var summary = buildRewardSummary(rows);
      if (summary.isEmpty) return; // yalnızca bilinmeyen türler geldi
      final down = summary.rankDown;
      if (down != null && widget.stats != null) {
        final rank = await widget.stats!.myRank(userId);
        if (!mounted) return;
        if (rank != null) {
          summary = summary.withRankDown(down.withPoints(rank.totalScore));
        }
      }
      if (!mounted || widget.suppress || _summary != null) return;
      setState(() => _summary = summary);
    } finally {
      _inFlight = false;
    }
  }

  void _close() {
    // İşaretleme "Devam"da — uygulama banner görünürken kapanırsa satırlar
    // görülmemiş kalır ve bir sonraki girişte tekrar gösterilir (web ile
    // aynı bilinçli tercih).
    unawaited(widget.rewards?.markSeen());
    setState(() => _summary = null);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: RewardBanner(summary: summary, onClose: _close),
        ),
      ],
    );
  }
}
