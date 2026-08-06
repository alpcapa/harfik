// Tüm Geçmiş Oyunlar — web `GameHistoryModal.tsx` portu (liste + tahta
// önizlemesi kısmı; beğeni/paylaşma/sohbet rozeti 5b'nin işi).
//
// Her kart: tarih + Canlı/Yapay Zeka rozeti, final sıralamasıyla oyuncu
// satırları (sıra no, rozet, ad, TESLİM OLDU etiketi, Puan, SL). Karta
// dokunmak o oyunun tahtasını altta açar/kapar — tahta lazy çekilir ve bir
// kez çekilince önbellekte kalır (web'in aynı kararı).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../data/game_record.dart';
import '../../data/games_api.dart';
import '../game/board_widget.dart';
import '../game/modal_shell.dart';
import '../game/player_badge.dart';

const _panel = Color(0xFFF5F7FA);
const _border = Color(0xFFDCE2EA);
const _muted = Color(0xFF5A6673);
const _text = Color(0xFF1B2430);
const _accent = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _gold = Color(0xFFB7791F);
const _red = Color(0xFFDC2626);

const _pageSize = 20;

Future<void> showGameHistory(
  BuildContext context, {
  required GamesRepo games,
  required String userId,

  /// null: tüm oyunlar ("Genel" sekmesinden açıldığında) — web ile aynı.
  required int? playerCount,

  /// Görüntülenen kişinin GÜNCEL adı; kendi satırında dondurulmuş ad yerine
  /// bu gösterilir (web `myCurrentName`).
  String? currentName,

  /// Liste sahibi görüntüleyenin kendisi mi — "Sen" etiketi ve kendi
  /// satırının vurgusu buna bağlı (web `isMyRow`).
  bool isMe = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => GameHistoryModal(
      games: games,
      userId: userId,
      playerCount: playerCount,
      currentName: currentName,
      isMe: isMe,
    ),
  );
}

class GameHistoryModal extends StatefulWidget {
  final GamesRepo games;
  final String userId;
  final int? playerCount;
  final String? currentName;
  final bool isMe;

  const GameHistoryModal({
    super.key,
    required this.games,
    required this.userId,
    required this.playerCount,
    this.currentName,
    this.isMe = true,
  });

  @override
  State<GameHistoryModal> createState() => _GameHistoryModalState();
}

class _GameHistoryModalState extends State<GameHistoryModal> {
  List<GameHistoryEntry>? _entries;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _expandedId;

  /// gameId → tahta (bir kez çekilince önbellekte kalır; null değeri
  /// "çekildi ama kayıt yok" demek — web'in aynı ayrımı).
  final _snapshots = <String, List<BoardSnapshotTile>?>{};
  String? _snapshotLoadingId;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPage(0);
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 80) _loadMore();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int offset) async {
    final res = await widget.games.history(
      userId: widget.userId,
      playerCount: widget.playerCount,
      offset: offset,
      limit: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _entries = [...?(offset == 0 ? null : _entries), ...res.games];
      _hasMore = res.hasMore;
      _loadingMore = false;
    });
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore || _entries == null) return;
    setState(() => _loadingMore = true);
    _loadPage(_entries!.length);
  }

  Future<void> _toggleBoard(GameHistoryEntry entry) async {
    if (_expandedId == entry.id) {
      setState(() => _expandedId = null);
      return;
    }
    setState(() => _expandedId = entry.id);
    if (_snapshots.containsKey(entry.id)) return; // önbellekte
    setState(() => _snapshotLoadingId = entry.id);
    final snap = await widget.games.boardSnapshot(entry.id);
    if (!mounted) return;
    setState(() {
      _snapshots[entry.id] = snap;
      _snapshotLoadingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return KModal(
      title: 'Tüm Geçmiş Oyunlar',
      child: entries == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Yükleniyor…',
                    style: TextStyle(
                        fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
              ),
            )
          : entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Henüz kayıtlı bir oyunun yok.',
                        style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 12,
                            color: _muted)),
                  ),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                  child: ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    itemCount: entries.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= entries.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(_loadingMore ? 'Yükleniyor…' : '',
                                style: const TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 10,
                                    color: _muted)),
                          ),
                        );
                      }
                      final e = entries[i];
                      return _EntryCard(
                        entry: e,
                        currentName: widget.currentName,
                        isMe: widget.isMe,
                        expanded: _expandedId == e.id,
                        snapshotLoading: _snapshotLoadingId == e.id,
                        snapshotFetched: _snapshots.containsKey(e.id),
                        snapshot: _snapshots[e.id],
                        onTap: () => _toggleBoard(e),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Web `fallbackPlayers`: `players` sütunu eklenmeden önceki kayıtlarda
/// yalnızca kendi puanın ve en iyi rakibin puanı bilinir.
({List<GamePlayerSnapshot> known, int unknownCount, int meIndex})
    _fallbackPlayers(GameHistoryEntry e, bool isMe, String? targetName) {
  final me = GamePlayerSnapshot(
    name: isMe ? 'Sen' : (targetName ?? 'Oyuncu'),
    score: e.playerScore,
    isAi: false,
    surrendered: false,
  );
  final opponent = GamePlayerSnapshot(
    name: 'En iyi rakip',
    score: e.aiScore,
    isAi: false,
    surrendered: false,
  );
  final meFirst = e.playerScore >= e.aiScore;
  return (
    known: meFirst ? [me, opponent] : [opponent, me],
    unknownCount: e.playerCount - 2 > 0 ? e.playerCount - 2 : 0,
    meIndex: meFirst ? 0 : 1,
  );
}

/// Web `findMeIndex`: `rank` doğrudan final sıralamasındaki konumu verir;
/// eski kayıtlarda puana göre eşleşen ilk insan satırına düşülür.
int _findMeIndex(GameHistoryEntry e, List<GamePlayerSnapshot> players) {
  final r = e.rank;
  if (r != null && r >= 1 && r <= players.length) return r - 1;
  final byScore =
      players.indexWhere((p) => !p.isAi && p.score == e.playerScore);
  return byScore >= 0 ? byScore : 0;
}

/// Web `seatIndexFor`: rozet rengi/numarası final sıralamasından BAĞIMSIZ,
/// sabit koltuk kimliğidir. `colorIndex` eski kayıtlarda yok → varsayılan
/// addan ("Yapay Zeka N") tahmin edilir; gerçek snapshot değilse (yedek
/// satırlar) tahmin güvenilmez, listedeki konum kullanılır.
int _seatIndexFor(GamePlayerSnapshot p, int position, bool isSnapshot) {
  // Web'in İLK kontrolü: kayıtta koltuk yazılıysa tahmine hiç girilmez.
  // (İlk portta bu satır düşmüştü — 4 kişilik kartta dört oyuncu da
  //  "1"/turkuaz görünüyordu; ekran görüntüsü yakaladı.)
  final ci = p.colorIndex;
  if (ci != null) return ci;
  if (!isSnapshot) return position;
  if (!p.isAi) return 0;
  final m = RegExp(r'Yapay Zeka (\d+)').firstMatch(p.name);
  if (m == null) return position;
  final n = int.parse(m.group(1)!) - 1;
  return n < 0 ? 0 : n;
}

/// Web `formatDate` — tr-TR kısa tarih (GG.AA.YYYY).
String _formatDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

class _EntryCard extends StatelessWidget {
  final GameHistoryEntry entry;
  final String? currentName;
  final bool isMe;
  final bool expanded;
  final bool snapshotLoading;
  final bool snapshotFetched;
  final List<BoardSnapshotTile>? snapshot;
  final VoidCallback onTap;

  const _EntryCard({
    required this.entry,
    required this.currentName,
    required this.isMe,
    required this.expanded,
    required this.snapshotLoading,
    required this.snapshotFetched,
    required this.snapshot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSnapshot = entry.players.isNotEmpty;
    final List<GamePlayerSnapshot> players;
    final int unknownCount;
    final int meIndex;
    if (hasSnapshot) {
      players = entry.players;
      unknownCount = 0;
      meIndex = _findMeIndex(entry, players);
    } else {
      final fb = _fallbackPlayers(entry, isMe, currentName);
      players = fb.known;
      unknownCount = fb.unknownCount;
      meIndex = fb.meIndex;
    }
    final ranks = computeRanks([
      for (final p in players)
        PlayerSnapshot(score: p.score, surrendered: p.surrendered)
    ]);
    final isOnline = entry.onlineGameId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                // Web: Canlı kayıtlar hafif gri zeminle ayrışır.
                color: isOnline ? _panel : Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(_formatDate(entry.createdAt),
                          style: const TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 9,
                              letterSpacing: 0.5,
                              color: _muted)),
                      const SizedBox(width: 6),
                      _Badge(
                        text: isOnline ? 'Canlı' : 'Yapay Zeka',
                        color: isOnline ? _green : _accent,
                      ),
                      const Spacer(),
                      const SizedBox(
                          width: 40,
                          child: Text('PUAN',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  color: _muted))),
                      const SizedBox(width: 8),
                      const SizedBox(
                          width: 24,
                          child: Text('SL',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  color: _muted))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < players.length; i++)
                    _PlayerRow(
                      player: players[i],
                      rank: ranks[i],
                      seatIndex: _seatIndexFor(players[i], i, hasSnapshot),
                      isMe: i == meIndex,
                      // Kendi satırında dondurulmuş ad yerine GÜNCEL ad
                      // (web myCurrentName) — nickname değişirse geçmiş de
                      // güncel görünür.
                      displayName: i == meIndex && currentName != null
                          ? currentName!
                          : players[i].name,
                      points: leaguePoints(ranks[i], entry.playerCount,
                          surrendered: players[i].surrendered),
                    ),
                  if (unknownCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+$unknownCount diğer oyuncu (bu eski kayıtta bilinmiyor)',
                        style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: _muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 6),
            if (snapshotLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('Yükleniyor…',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 10,
                          color: _muted)),
                ),
              )
            else if (snapshotFetched && snapshot != null)
              // Gerçek BoardWidget'ın salt-okunur hâli — compact/hideFooter
              // zaten vardı (parça 1/8), canlı oyun tahtasına DOKUNULMADI.
              BoardWidget(
                state: buildSnapshotGameState(
                    snapshot!, entry.playerCount, players),
                compact: true,
                hideFooter: true,
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text('Bu oyun için tahta görüntüsü kaydedilmemiş.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 10,
                          color: _muted)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 7, fontWeight: FontWeight.bold, color: color)),
      );
}

class _PlayerRow extends StatelessWidget {
  final GamePlayerSnapshot player;
  final int rank;
  final int seatIndex;
  final bool isMe;
  final String displayName;
  final int points;

  const _PlayerRow({
    required this.player,
    required this.rank,
    required this.seatIndex,
    required this.isMe,
    required this.displayName,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 18, // "1." 12px SpaceMono'da 14px'e sığmıyordu (ekran
            // görüntüsü yakaladı: rakam ve nokta alt alta düşüyordu)
            child: Text('$rank.',
                softWrap: false,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
          ),
          const SizedBox(width: 6),
          PlayerBadge(index: seatIndex, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 12,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                color: isMe ? _text : _muted,
              ),
            ),
          ),
          if (player.surrendered) ...[
            const SizedBox(width: 4),
            const _Badge(text: 'TESLİM OLDU', color: _red),
          ],
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: Text('${player.score}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMe ? _gold : _muted)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              formatLeaguePoints(points),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: points > 0 ? _green : (points < 0 ? _red : _muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
