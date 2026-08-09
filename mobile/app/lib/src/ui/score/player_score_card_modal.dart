// Başka bir oyuncunun (salt-okunur) skor kartı — web `PlayerScoreCard.tsx`
// portu. k-lig satırına dokununca açılır; istatistik bölümü kendi kartınla
// AYNI bileşendir (web'de de öyle — iki kopya bir kez açılmış, kod
// incelemesiyle tek kaynağa çekilmişti).
//
// Web'deki arkadaşlık simgesi (7 Ağustos 2026'dan beri) BURADA DA VAR:
// [friends] verilirse isim yanında ilişkiye göre yeşil ✓ (dokun →
// arkadaşlıktan çık onayı) ya da + (dokun → duruma göre ekle / kabul et /
// isteği iptal onayı) — web `fetchFriendRelation` akışının eşleniği.
// [friends] null ise simge hiç çizilmez (offline/testler — önceki davranış).
// "Tüm Oyunları Gör" bağlı: o oyuncunun geçmişini açar (görüntülenen kişi
// SEN DEĞİLSİN, bu yüzden isMe=false — eski kayıtlardaki yedek satır "Sen"
// yerine o kişinin adını taşır, web'in aynı ayrımı).
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../auth/k_avatar.dart';
import '../friends/friends_modal.dart'
    show confirmFriendAction, showFriendInfoDialog;
import '../game/modal_shell.dart';
import 'game_history_modal.dart';
import 'klig_mark.dart';
import 'leaderboard_modal.dart';
import 'score_stats_section.dart';

const _text = Color(0xFF1B2430);
const _muted = Color(0xFF5A6673);
const _accent = Color(0xFF2563EB);

Future<void> showPlayerScoreCard(
  BuildContext context, {
  required StatsRepo stats,
  required String userId,
  required String name,
  String? avatarUrl,
  Future<GamesRepo>? games,
  FriendsRepo? friends,
  AuthService? auth,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => PlayerScoreCardModal(
      stats: stats,
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
      games: games,
      friends: friends,
      auth: auth,
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

  /// null ise arkadaşlık simgesi çizilmez (offline/test).
  final FriendsRepo? friends;

  /// null ise k-lig satırı tıklanamaz (Leaderboard açmak için gerekiyor) —
  /// web'de bu satır koşulsuz görünür (`fetchMyLeaderboardRank` yalnızca
  /// `stats` istiyor), ama `showLeaderboard`'ı çağırmak `AuthService`
  /// gerektirdiğinden [auth] verilmemiş çağrı yerlerinde satır YİNE
  /// görünür (rank/puan bilgisi hâlâ faydalı) ama dokunuşu no-op kalır.
  final AuthService? auth;

  const PlayerScoreCardModal({
    super.key,
    required this.stats,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.games,
    this.friends,
    this.auth,
  });

  @override
  State<PlayerScoreCardModal> createState() => _PlayerScoreCardModalState();
}

class _PlayerScoreCardModalState extends State<PlayerScoreCardModal> {
  StatsTab _tab = StatsTab.all;
  final _statsByTab = <StatsTab, PlayerStats?>{};
  final _loaded = <StatsTab>{};

  // Arkadaşlık ilişkisi: null = ilişki yok ya da henüz yüklenmedi/kendi
  // kartın — `_relationLoaded` ikisini ayırır (yüklenmeden simge çizilmez).
  FriendRelation? _relation;
  bool _relationLoaded = false;

  // k-lig satırındaki "#sıra ·" öneki — web `rank` state'iyle aynı
  // (`fetchMyLeaderboardRank(member.id)`, burada `stats.myRank(userId)`).
  MyLeaderboardRank? _rank;

  @override
  void initState() {
    super.initState();
    _loadRelation();
    widget.stats.myRank(widget.userId).then((r) {
      if (mounted) setState(() => _rank = r);
    });
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

  void _loadRelation() {
    final friends = widget.friends;
    if (friends == null) return;
    friends.relationWith(widget.userId).then((r) {
      if (!mounted) return;
      setState(() {
        _relation = r;
        _relationLoaded = true;
      });
    });
  }

  /// Web PlayerScoreCard simge davranışı: ✓ = arkadaşsınız (dokun →
  /// çıkar onayı); + = değilsiniz (duruma göre ekle / kabul et / iptal).
  Future<void> _onRelationTap() async {
    final friends = widget.friends;
    if (friends == null) return;
    final name = widget.name;
    try {
      switch (_relation) {
        case FriendRelation.accepted:
          final ok = await confirmFriendAction(context,
              title: 'Arkadaşlıktan Çıkar',
              message:
                  '$name ile arkadaşsınız. Arkadaşlıktan çıkmak mı istiyorsunuz?',
              confirmLabel: 'Çıkar');
          if (!ok || !mounted) return;
          await friends.removeOrCancel(widget.userId);
          if (mounted) setState(() => _relation = null);
        case FriendRelation.pendingOutgoing:
          final ok = await confirmFriendAction(context,
              title: 'İsteği İptal Et',
              message: '$name oyuncusuna gönderdiğin arkadaşlık isteğini '
                  'iptal etmek istiyor musun?',
              confirmLabel: 'İptal Et');
          if (!ok || !mounted) return;
          await friends.removeOrCancel(widget.userId);
          if (mounted) setState(() => _relation = null);
        case FriendRelation.pendingIncoming:
          final ok = await confirmFriendAction(context,
              title: 'İsteği Kabul Et',
              message:
                  '$name sana arkadaşlık isteği göndermiş. Kabul ediyor musun?',
              confirmLabel: 'Kabul Et');
          if (!ok || !mounted) return;
          await friends.respond(widget.userId, accept: true);
          if (mounted) setState(() => _relation = FriendRelation.accepted);
        case null:
          final ok = await confirmFriendAction(context,
              title: 'Arkadaş Ekle',
              message: '$name oyuncusuna arkadaşlık isteği gönderilsin mi?',
              confirmLabel: 'Gönder');
          if (!ok || !mounted) return;
          final r = await friends.sendRequest(widget.userId);
          if (mounted) {
            setState(() => _relation = r);
            if (r == FriendRelation.accepted) {
              await showFriendInfoDialog(
                  context, '$name ile artık arkadaşsınız.');
            }
          }
      }
    } catch (e) {
      debugPrint('[Kelimeki] arkadaşlık işlemi hatası: $e');
    }
  }

  Widget? _relationIcon() {
    if (widget.friends == null || !_relationLoaded) return null;
    final accepted = _relation == FriendRelation.accepted;
    return GestureDetector(
      onTap: _onRelationTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(
          accepted ? Icons.check_circle : Icons.person_add_alt_1,
          size: 20,
          color: accepted
              ? const Color(0xFF1FA05C) // web yeşil ✓
              : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  // k-lig satırı — web `PlayerScoreCard.tsx`nin koşulsuz görünen butonu
  // (bkz. dosya başı yorumu): KLigMark + "?" bilgi rozeti + "#sıra · puan
  // puan". `auth` verilmemiş çağrı yerlerinde (bkz. showPlayerScoreCard'ın
  // AYRI çağrıldığı game_history_modal.dart) satır yine görünür ama dokunuş
  // no-op kalır — bilgi kaybı yok, yalnızca Leaderboard'u açan aksiyon yok.
  Widget _kligButton() {
    final totalScore = _statsByTab[StatsTab.all]?.totalScore ?? 0;
    final auth = widget.auth;
    return GestureDetector(
      onTap: auth == null
          ? null
          : () => showLeaderboard(context,
              auth: auth,
              stats: widget.stats,
              games: widget.games,
              friends: widget.friends),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Web `KLigMark`'ın `color` prop varsayılanı mavi (`KLIG_COLOR`) —
          // kapsayan `text-muted` div'i yalnızca "?" rozetini/puan metnini
          // etkiliyor, SVG fill'ini değil (bkz. score_card_modal.dart'taki
          // aynı düzeltmenin gerekçesi).
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
              if (_rank != null) ...[
                TextSpan(text: '#${_rank!.rank}'),
                const TextSpan(text: ' · '),
              ],
              TextSpan(text: '$totalScore'),
              const TextSpan(
                text: ' puan',
                style: TextStyle(
                    fontWeight: FontWeight.normal, color: _muted),
              ),
            ]),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _accent,
            ),
          ),
        ],
      ),
    );
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
                child: Row(
                  children: [
                    Flexible(
                      child: Text(widget.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _text)),
                    ),
                    if (_relationIcon() case final icon?) icon,
                  ],
                ),
              ),
              _kligButton(),
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
                    stats: widget.stats,
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
