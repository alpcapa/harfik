// Başka bir oyuncunun (salt-okunur) skor kartı — web `PlayerScoreCard.tsx`
// portu. k-lig satırına dokununca açılır; istatistik bölümü kendi kartınla
// AYNI bileşendir (web'de de öyle — iki kopya bir kez açılmış, kod
// incelemesiyle tek kaynağa çekilmişti).
//
// Web'deki arkadaşlık simgesi (ekle/çıkar) BİLİNÇLİ eksik: arkadaşlık
// sistemi henüz port edilmedi — çalışmayan bir kontrol koymuyoruz.
// "Tüm Oyunları Gör" bağlı: o oyuncunun geçmişini açar (görüntülenen kişi
// SEN DEĞİLSİN, bu yüzden isMe=false — eski kayıtlardaki yedek satır "Sen"
// yerine o kişinin adını taşır, web'in aynı ayrımı).
import 'package:flutter/material.dart';

import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../auth/k_avatar.dart';
import '../game/modal_shell.dart';
import 'game_history_modal.dart';
import 'score_stats_section.dart';

const _text = Color(0xFF1B2430);

Future<void> showPlayerScoreCard(
  BuildContext context, {
  required StatsRepo stats,
  required String userId,
  required String name,
  String? avatarUrl,
  Future<GamesRepo>? games,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => PlayerScoreCardModal(
      stats: stats,
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
      games: games,
    ),
  );
}

class PlayerScoreCardModal extends StatefulWidget {
  final StatsRepo stats;
  final String userId;
  final String name;
  final String? avatarUrl;

  /// null ise "Tüm Oyunları Gör" çizilmez (offline mod).
  final Future<GamesRepo>? games;

  const PlayerScoreCardModal({
    super.key,
    required this.stats,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.games,
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
          if (widget.games != null) ...[
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: () async {
                  final games = await widget.games!;
                  if (!context.mounted) return;
                  await showGameHistory(
                    context,
                    games: games,
                    userId: widget.userId,
                    playerCount: _tab.playerCount,
                    currentName: widget.name,
                    isMe: false,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'TÜM OYUNLARI GÖR',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Color(0xFF2563EB)),
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
