// "Son Oynadıklarım" — web `RecentGamesSection.tsx` portu.
//
// Sekmenin türüne uygun (yerel/Canlı) son 5 BİTEN oyunu kompakt satırlar
// hâlinde gösterir. Bir satıra dokunmak Tüm Oyunlarım'ı (`GameHistoryModal`)
// doğrudan o oyunun tahtası açık hâlde açar — ayrı bir mini tahta/paylaşım
// gösterimi yazmak yerine mevcut modalın tüm davranışını (beğen/paylaş/
// sohbet arşivi) olduğu gibi devralır.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../game/player_avatar_row.dart';
import '../score/game_history_modal.dart';
import '../tokens.dart';
import '../game/neo_box.dart';

const _panel = kPanel;
const _border = kBorder;
const _muted = kMuted;
const _text = kText;
const _accent = kAccent;
const _green = kGreen;
const _red = kRed;

/// `userId:onlineOnly` → son çekilen liste. Bileşen sekme değişiminde
/// unmount/mount olduğundan (web'de de öyle) her dönüşte "Yükleniyor…"
/// göstermemek için modül seviyesinde tutuluyor; effect yine de her
/// mount'ta taze veriyi arka planda çekip hem state'i hem bunu günceller.
final _recentCache = <String, List<GameHistoryEntry>>{};

@visibleForTesting
void clearRecentGamesCache() => _recentCache.clear();

/// Web `rankFor`: rank hiç yazılmamış eski kayıtlarda puan karşılaştırması.
int _rankFor(GameHistoryEntry e) =>
    e.rank ?? (e.playerScore >= e.aiScore ? 1 : 2);

/// Web `titleFor` — yalnızca snapshot'ı OLMAYAN eski kayıtlar için yedek
/// başlık (snapshot varsa avatar şeridi geçer).
String _titleFor(GameHistoryEntry e) {
  if (e.players.length < 2) return '${e.playerCount} Kişilik Oyun';
  final meIdx = _rankFor(e) - 1;
  final others = [
    for (var i = 0; i < e.players.length; i++)
      if (i != meIdx) e.players[i]
  ];
  if (e.playerCount == 2 && others.length == 1) {
    return others.first.isAi ? 'Yapay Zeka' : others.first.name;
  }
  if (e.onlineGameId != null && others.isNotEmpty) {
    return [for (final p in others) p.isAi ? 'Yapay Zeka' : p.name].join(', ');
  }
  return '${e.playerCount} Kişilik Oyun';
}

String _formatDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

class RecentGamesSection extends StatefulWidget {
  final GamesRepo games;
  final String userId;

  /// Görüntüleyenin güncel adı — açılan geçmiş modalında kendi satırında
  /// dondurulmuş ad yerine bu gösterilir.
  final String? currentName;

  /// true: yalnızca Canlı, false: yalnızca Yapay Zeka oyunları.
  final bool onlineOnly;

  /// "Beğenenler" zincirini açabilmek için geçilir (null ise isimler
  /// tıklanmaz).
  final StatsRepo? stats;

  /// Web `emptyMessage` (RecentGamesSection.tsx) — verilirse yükleme
  /// sırasında "Yükleniyor…", liste boşken bu metin gösterilir; null ise
  /// (varsayılan davranış DEĞİŞMEDİ) ikisinde de bölüm SESSİZCE gizlenir.
  /// Kendi başına bir sekmenin İÇERİĞİ olarak kullanıldığında (Setup'ın
  /// "Son Oynananlar"ı, LiveGamesTab'ın "Son Oynananlar"ı — Parça 28)
  /// verilmesi ZORUNLU, aksi halde boş bir sekme hiçbir geri bildirim
  /// vermeden tamamen boş kalır; başka bir listenin ALTINA sessizce
  /// eklenen eski kullanım biçiminde (artık yok) hâlâ null bırakılabilir.
  final String? emptyMessage;

  const RecentGamesSection({
    super.key,
    required this.games,
    required this.userId,
    required this.onlineOnly,
    this.currentName,
    this.stats,
    this.emptyMessage,
  });

  @override
  State<RecentGamesSection> createState() => _RecentGamesSectionState();
}

class _RecentGamesSectionState extends State<RecentGamesSection> {
  static const _limit = 5;

  late final String _cacheKey = '${widget.userId}:${widget.onlineOnly}';
  late List<GameHistoryEntry>? _games = _recentCache[_cacheKey];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.games.history(
      userId: widget.userId,
      playerCount: null,
      offset: 0,
      limit: _limit,
      onlineOnly: widget.onlineOnly,
    );
    if (!mounted) return;
    _recentCache[_cacheKey] = res.games;
    setState(() => _games = res.games);
  }

  Future<void> _openHistory({String? focusId}) => showGameHistory(
        context,
        games: widget.games,
        userId: widget.userId,
        playerCount: null,
        currentName: widget.currentName,
        stats: widget.stats,
        initialExpandedId: focusId,
      );

  Widget _emptyOrHidden(String text) {
    final msg = widget.emptyMessage;
    if (msg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    // Web: `emptyMessage` verilmemişse (başka bir listenin altına sessizce
    // eklenen eski kullanım biçimi) bölüm SESSİZCE gizlenir; verilmişse
    // (kendi başına bir sekme içeriği — Parça 28) "Yükleniyor…"/mesaj
    // gösterilir.
    if (games == null) return _emptyOrHidden('Yükleniyor…');
    if (games.isEmpty) return _emptyOrHidden(widget.emptyMessage ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('SON OYNADIKLARIM',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: _muted)),
            ),
            GestureDetector(
              onTap: () => _openHistory(),
              behavior: HitTestBehavior.opaque,
              child: const Text('TÜM OYUNLARIM',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: _accent)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final g in games)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecentRow(
              entry: g,
              onTap: () => _openHistory(focusId: g.id),
            ),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final GameHistoryEntry entry;
  final VoidCallback onTap;

  const _RecentRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final points = leaguePoints(_rankFor(entry), entry.playerCount,
        surrendered: entry.surrendered);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const ShapeDecorationWithCssShadows(
          color: _panel, borderColor: _border, radius: 6,
          shadows: kRaisedShadows, // web shadow-raised
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.players.isNotEmpty)
                    PlayerAvatarRow(players: [
                      for (final p in entry.players)
                        AvatarRowPlayer(
                          name: p.name,
                          isAi: p.isAi,
                          // Misafirken oynanıp bitirilen, sonra üye olunca
                          // hesaba taşınan yerel oyunlarda snapshot'taki ad
                          // kalıcı olarak "Misafir" kalıyor → baş harf "MI"
                          // çıkıp misafiri gerçek bir üye gibi gösterirdi.
                          // `onlineGameId` kontrolü yanlış pozitifi
                          // daraltıyor: Canlı'da misafir koltuk YOK.
                          isGuest: !p.isAi &&
                              entry.onlineGameId == null &&
                              p.name == guestPlayerName,
                        ),
                    ])
                  else
                    Text(_titleFor(entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _text)),
                  const SizedBox(height: 2),
                  Text(_formatDate(entry.createdAt),
                      style: const TextStyle(
                          fontFamily: 'SpaceMono', fontSize: 9, color: _muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${entry.playerScore}',
                style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _text)),
            const SizedBox(width: 8),
            Text(formatLeaguePoints(points),
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                        points > 0 ? _green : (points < 0 ? _red : _muted))),
          ],
        ),
      ),
    );
  }
}
