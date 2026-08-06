// Başka bir oyuncunun (salt-okunur) skor kartı — web `PlayerScoreCard.tsx`
// portu. k-lig satırına dokununca açılır; istatistik bölümü kendi kartınla
// AYNI bileşendir (web'de de öyle — iki kopya bir kez açılmış, kod
// incelemesiyle tek kaynağa çekilmişti).
//
// Web'deki arkadaşlık simgesi (ekle/çıkar), "Tüm Oyunları Gör" ve oyun
// geçmişi BİLİNÇLİ eksik: arkadaşlık sistemi ve oyun geçmişi henüz port
// edilmedi — çalışmayan bir kontrol koymak yerine hiç göstermiyoruz.
import 'package:flutter/material.dart';

import '../../data/stats_api.dart';
import '../auth/k_avatar.dart';
import '../game/modal_shell.dart';
import 'score_stats_section.dart';

const _text = Color(0xFF1B2430);

Future<void> showPlayerScoreCard(
  BuildContext context, {
  required StatsRepo stats,
  required String userId,
  required String name,
  String? avatarUrl,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => PlayerScoreCardModal(
      stats: stats,
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
    ),
  );
}

class PlayerScoreCardModal extends StatefulWidget {
  final StatsRepo stats;
  final String userId;
  final String name;
  final String? avatarUrl;

  const PlayerScoreCardModal({
    super.key,
    required this.stats,
    required this.userId,
    required this.name,
    this.avatarUrl,
  });

  @override
  State<PlayerScoreCardModal> createState() => _PlayerScoreCardModalState();
}

class _PlayerScoreCardModalState extends State<PlayerScoreCardModal> {
  StatsTab _tab = StatsTab.all;
  final _statsByTab = <StatsTab, PlayerStats?>{};
  final _loaded = <StatsTab>{};

  @override
  void initState() {
    super.initState();
    for (final t in StatsTab.values) {
      widget.stats.playerStats(widget.userId, t).then((s) {
        if (!mounted) return;
        setState(() {
          _statsByTab[t] = s;
          _loaded.add(t);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return KModal(
      title: 'Skor Kartı',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KAvatar(url: widget.avatarUrl, name: widget.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _text)),
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
                ? 'Bu oyuncunun henüz oyun kaydı yok.'
                : 'Bu oyuncunun ${_tab.playerCount} oyunculu oyun kaydı yok.',
          ),
        ],
      ),
    );
  }
}
