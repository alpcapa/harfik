// Skor Kartı — web `ScoreCard.tsx` portu: üstte avatar/isim/yaş-cinsiyet +
// k-lig sırası, altında üç sekme (Genel/2/4), iki istatistik ızgarası ve
// "Tüm Geçmiş Oyunlar" linki (aktif sekmenin oyuncu sayısıyla açılır —
// "Genel"de filtresiz).
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../auth/k_avatar.dart';
import '../game/modal_shell.dart';
import '../rank/rank_header_seal.dart';
import 'game_history_modal.dart';
import 'klig_mark.dart';
import 'leaderboard_modal.dart';
import 'score_stats_section.dart';
import '../tokens.dart';

const _muted = kMuted;
const _text = kText;
const _accent = kAccent;

Future<void> showScoreCard(
  BuildContext context, {
  required AuthService auth,
  required StatsRepo stats,
  Future<GamesRepo>? games,
  FriendsRepo? friends,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        ScoreCardModal(auth: auth, stats: stats, games: games, friends: friends),
  );
}

class ScoreCardModal extends StatefulWidget {
  final AuthService auth;
  final StatsRepo stats;

  /// null ise "Tüm Geçmiş Oyunlar" linki çizilmez (offline mod) — çalışmayan
  /// link koymuyoruz.
  final Future<GamesRepo>? games;
  final FriendsRepo? friends;
  const ScoreCardModal({
    super.key,
    required this.auth,
    required this.stats,
    this.games,
    this.friends,
  });

  @override
  State<ScoreCardModal> createState() => _ScoreCardModalState();
}

class _ScoreCardModalState extends State<ScoreCardModal> {
  StatsTab _tab = StatsTab.all;
  final _statsByTab = <StatsTab, PlayerStats?>{};
  final _loaded = <StatsTab>{};
  MyLeaderboardRank? _myRank;

  @override
  void initState() {
    super.initState();
    final user = widget.auth.user;
    if (user == null) return;
    // Web: üç sekme de AÇILIŞTA paralel çekilir — sekme çubuğu her sekmenin
    // lig puanını gösterdiğinden (tıklanmadan önce de) hepsi gerekli.
    for (final t in StatsTab.values) {
      widget.stats.playerStats(user.id, t).then((s) {
        if (!mounted) return;
        setState(() {
          _statsByTab[t] = s;
          _loaded.add(t);
        });
      });
    }
    widget.stats.myRank(user.id).then((r) {
      if (mounted) setState(() => _myRank = r);
    });
  }

  /// Web `calculateAge` — doğum günü bu yıl geçmediyse bir eksik.
  static int? _age(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    final born = DateTime.tryParse(birthDate);
    if (born == null) return null;
    final now = DateTime.now();
    var age = now.year - born.year;
    if (now.month < born.month ||
        (now.month == born.month && now.day < born.day)) {
      age--;
    }
    return age;
  }

  /// Web `formatAgeGender` — "Y:59/C:E"; ikisi de yoksa boş.
  static String _ageGender(int? age, String? gender) {
    final letter = gender == 'male' ? 'E' : (gender == 'female' ? 'K' : null);
    return [
      if (age != null) 'Y:$age',
      if (letter != null) 'C:$letter',
    ].join('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final profile = auth.profile;
    // Skor kartı herkese açık olabildiğinden (k-lig üzerinden) tam ad/soyad
    // DEĞİL, oyun içindeki kısa kimlik gösterilir (web ile aynı zincir).
    final name = profile?.displayName?.isNotEmpty == true
        ? profile!.displayName!
        : profile?.firstName?.isNotEmpty == true
            ? profile!.firstName!
            : (auth.user?.email ?? 'Oyuncu');
    final ageGender = _ageGender(_age(profile?.birthDate), profile?.gender);
    final totalScore = _statsByTab[StatsTab.all]?.totalScore ?? 0;

    return KModal(
      title: 'Skor Kartı',
      // Rütbe mührü — GÜNCEL puandan türetilir (düşmeli sürüm); başlıkla ✕
      // arasında ortalı, yazısız; dokununca RankInfoModal.
      headerCenter: rankHeaderSeal(context,
          overall: _statsByTab[StatsTab.all],
          loaded: _loaded.contains(StatsTab.all)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KAvatar(url: profile?.avatarUrl, name: name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _text)),
                    if (ageGender.isNotEmpty)
                      Text(ageGender,
                          style: const TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 12,
                              color: _muted)),
                  ],
                ),
              ),
              // k-lig sırası — dokununca sıralama açılır (web'deki aynı buton).
              GestureDetector(
                onTap: () => showLeaderboard(context,
                    auth: widget.auth,
                    stats: widget.stats,
                    games: widget.games,
                    friends: widget.friends),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Web `KLigMark`'ın `color` prop'u `KLIG_COLOR` (mavi)
                    // varsayılanı taşıyor — kapsayan `text-muted` div'i
                    // yalnızca "?" rozetini ve puan metnini etkiliyor, SVG
                    // fill'ini DEĞİL (CSS `currentColor` değil, doğrudan
                    // React prop'u). Önceki sürüm burada `_muted` geçip
                    // logoyu grileştiriyordu — 9 Ağustos 2026'da kullanıcı
                    // "k-lig yazısı mavi olmalı" diye bildirdi, kaynak
                    // koddan doğrulanıp düzeltildi.
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KLigMark(height: 16),
                        SizedBox(width: 4),
                        KLigInfoBadge(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        if (_myRank != null) ...[
                          TextSpan(text: '#${_myRank!.rank}'),
                          // Web `mx-0.5` = 2px. Boşluk KARAKTERİ DEĞİL: Space Mono'da
                          // bir boşluk ~0.6em (13px'te ~7.8) eder ve iki yanda ~6px
                          // fazla açar — 17 Ağustos 2026 görsel turunda kullanıcı
                          // "nokta sağı ve solu web'e göre daha açık" diye bildirdi.
                          const WidgetSpan(child: SizedBox(width: 2)),
                          const TextSpan(text: '·'),
                          const WidgetSpan(child: SizedBox(width: 2)),
                        ],
                        TextSpan(text: '$totalScore puan'),
                      ]),
                      style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ScoreTabsBar(
            tab: _tab,
            onChanged: (t) => setState(() => _tab = t),
            statsByTab: _statsByTab,
          ),
          const SizedBox(height: 12),
          ScoreStatsSection(
            stats: _statsByTab[_tab],
            loaded: _loaded.contains(_tab),
            emptyText: _tab == StatsTab.all
                ? 'Henüz hiç oyun kaydın yok.'
                : 'Henüz ${_tab.playerCount} oyunculu oyun kaydın yok.',
          ),
          if (widget.games != null && auth.user != null) ...[
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: () async {
                  final games = await widget.games!;
                  if (!context.mounted) return;
                  await showGameHistory(
                    context,
                    games: games,
                    userId: auth.user!.id,
                    playerCount: _tab.playerCount,
                    currentName: name,
                    // "Beğenenler" listesinden bir isme dokununca o kişinin
                    // skor kartı açılabilsin diye.
                    stats: widget.stats,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'TÜM GEÇMİŞ OYUNLAR',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: _accent),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
