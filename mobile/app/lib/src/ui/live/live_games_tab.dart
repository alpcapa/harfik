// "Arkadaşınla" sekmesi — src/components/LiveGamesTab.tsx portu: üç alt
// sekme (Devam Edenler / Oyun Davetleri / Son Oynananlar) rozetli, davet
// kartları (Kabul/Reddet + katılımcı listesi), "Kabul Ettin — Diğerleri
// Bekleniyor"/"Bekleyen Oyunlar" detay kartları, kalan süre etiketleri,
// "hafif süpürme" (OnlineGamesRepo.load içinde) ve Realtime + foreground
// tazelenmesi.
//
// Web'den taşınan kararlar:
// - Varsayılan alt sekme: bekleyen davet varsa "Oyun Davetleri" — yalnızca
//   SUNUCUDAN taze veriyle ve bir kez (hasFreshGames dersi); elle seçim
//   kararı kalıcı devre dışı bırakır. Sekme sonradan OTOMATİK değişmez.
// - Modül seviyesinde önbellek: sekmeler arası geçişte widget unmount
//   olduğundan (web'in aynı yapısı) son bilinen liste anında çizilir,
//   taze veri arkada gelir.
// - Hesap değişimi kararı user.id ile; önbellek anahtarı da user.id.
// - Kalan süre yalnızca sırası ÇAĞIRANDA olan oyunlarda (web 3 Ağustos
//   dersi: rakibin süresi kullanıcının kendi süresi sanılıyordu).
//
// Bilinçli eksik (bu parça): aktif oyuna dokununca gerçek Canlı oyun
// TAHTASI henüz açılmıyor — dürüst "sonraki parçada" diyaloğu (oynanış
// ekranı bir sonraki parça; davet/kabul akışı ondan bağımsız çalışıyor).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trUpper;

import '../../bootstrap.dart';
import '../../data/online_games_api.dart';
import '../auth/auth_modal.dart';
import '../auth/k_avatar.dart';
import '../game/count_badge.dart';
import '../game/neo_button.dart';
import '../game/player_avatar_row.dart';
import '../setup/recent_games_section.dart';
import 'friend_suggest_modal.dart';
import 'live_game_create_form.dart';
import 'online_game_screen.dart';
import '../tokens.dart';
import '../game/neo_box.dart';

const Color _text = kText;
const Color _muted = kMuted;
const Color _accent = kAccent;
const Color _border = kBorder;
const Color _panel = kPanel;
const Color _red = kRed;
const Color _green = kGreen;

enum LiveSubTab { active, invites, recent }

/// user.id → son bilinen liste (web liveGamesCache — sekme geçişinde
/// unmount olan widget'ın spinner'sız yeniden çizimi için).
final Map<String, OnlineGamesSnapshot> _liveGamesCache = {};

class LiveGamesTab extends StatefulWidget {
  final AppServices services;
  const LiveGamesTab({super.key, required this.services});

  @override
  State<LiveGamesTab> createState() => _LiveGamesTabState();
}

class _LiveGamesTabState extends State<LiveGamesTab>
    with WidgetsBindingObserver {
  OnlineGamesSnapshot? _snapshot;
  LiveSubTab _subTab = LiveSubTab.active;
  bool _appliedDefaultTab = false;
  bool _creating = false;
  String? _busyInviteId;
  String? _lastUserId;
  Timer? _reloadDebounce;
  void Function()? _unsubscribe;
  int _loadSeq = 0;

  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    final user = services.auth.user;
    _lastUserId = user?.id;
    if (user != null) _snapshot = _liveGamesCache[user.id];
    services.auth.addListener(_onAuthEvent);
    // Öne dönüş tazelenmesi — web visibilitychange/focus/online eşleniği:
    // arka planda websocket askıya alınıp olay kaçmış olabilir.
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _unsubscribe = services.onlineGames?.gateway.subscribe(_scheduleReload);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleReload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    services.auth.removeListener(_onAuthEvent);
    _reloadDebounce?.cancel();
    _unsubscribe?.call();
    super.dispose();
  }

  void _onAuthEvent() {
    final id = services.auth.user?.id;
    if (id == _lastUserId) return; // TOKEN_REFRESHED ≠ hesap değişimi
    _lastUserId = id;
    if (mounted) {
      setState(() {
        _snapshot = id != null ? _liveGamesCache[id] : null;
        _appliedDefaultTab = false;
        _creating = false;
      });
    }
    _reload();
  }

  /// Realtime olayları (kendi hamlen dahil her değişiklik) 300ms debounce
  /// ile tek reload'a iner — web kuralı: üç tabloya abone her tüketici
  /// debounce etmeli.
  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  Future<void> _reload() async {
    final repo = services.onlineGames;
    final user = services.auth.user;
    if (repo == null || user == null) return;
    final seq = ++_loadSeq;
    final snap = await repo.load();
    // Hesap bu arada değiştiyse ya da daha yeni bir yükleme başladıysa
    // sonucu yazma (web'in iptal jetonu deseninin sayaç karşılığı).
    if (!mounted || seq != _loadSeq || services.auth.user?.id != user.id) {
      return;
    }
    if (snap == null) return; // ağ hatası — eski liste korunur
    _liveGamesCache[user.id] = snap;
    setState(() {
      _snapshot = snap;
      // Varsayılan alt sekme — yalnızca taze veriyle (bu setState'e YALNIZCA
      // sunucudan dönen sonuç girer; önbellek hidrasyonu initState'te ve bu
      // karara hiç dokunmuyor — web hasFreshGames dersinin yapısal hâli),
      // bir kez.
      if (!_appliedDefaultTab) {
        _appliedDefaultTab = true;
        if (inviteBucket(snap.games).isNotEmpty) {
          _subTab = LiveSubTab.invites;
        }
      }
    });
  }

  Future<void> _handleRespond(OnlineGame game, bool accept) async {
    final repo = services.onlineGames;
    final friends = services.friends;
    final inviteId = game.myInviteId;
    if (repo == null || inviteId == null) return;
    setState(() => _busyInviteId = inviteId);
    try {
      await repo.respondInvite(inviteId, accept: accept);
      if (accept && friends != null && mounted) {
        // Henüz arkadaş olunmayan katılımcılara toplu istek önerisi (web).
        final candidates = [
          for (final s in game.slots)
            if (!s.isAi &&
                s.relation != 'self' &&
                s.relation != 'accepted' &&
                s.userId != null)
              SuggestCandidate(
                  userId: s.userId!, name: s.name, avatarUrl: s.avatarUrl),
        ];
        if (candidates.isNotEmpty) {
          await showFriendSuggestModal(context,
              friends: friends, candidates: candidates);
        }
      }
      await _reload(); // web: busy göstergesi liste tazelenene dek kalır
    } catch (e) {
      debugPrint('[Kelimeki] respondInvite hatası: $e');
    } finally {
      if (mounted) setState(() => _busyInviteId = null);
    }
  }

  /// Aktif bir oyuna dokunulunca Canlı tahtayı açar; dönüşte liste
  /// tazelenir (oyunda oynanan hamle "Devam Edenler"deki sıra etiketini
  /// değiştirmiş olabilir — Realtime da tetikler ama dönüş anı garanti).
  Future<void> _openGame(OnlineGame game) async {
    final repo = services.onlineGames;
    final user = services.auth.user;
    if (repo == null || user == null) return;
    final words = await services.dictionary;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OnlineGameScreen(
        game: game,
        myUserId: user.id,
        onlineGames: repo,
        words: words,
        meanings: services.meanings,
        auth: services.auth,
        stats: services.stats,
        games: services.games,
        feedback: services.feedback,
        friends: services.friends,
        chat: services.chat,
        storage: services.storage,
        leagueRewards: services.leagueRewards,
      ),
    ));
    if (mounted) unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final auth = services.auth;
    final user = auth.user;
    final repo = services.onlineGames;

    if (user == null || repo == null || services.friends == null) {
      // Web: "Canlı oyun oynamak için giriş yapmalısın." + Giriş Yap.
      return Column(children: [
        const SizedBox(height: 16),
        const Text('Canlı oyun oynamak için giriş yapmalısın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted)),
        const SizedBox(height: 12),
        if (auth.configured)
          NeoButton(
            label: 'GİRİŞ YAP',
            variant: NeoButtonVariant.accent,
            fontSize: 12,
            letterSpacing: 1,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            onPressed: () => showLoginModal(context, auth,
                feedback: services.feedback),
          ),
      ]);
    }

    if (_creating) {
      return LiveGameCreateForm(
        auth: auth,
        friends: services.friends!,
        onlineGames: repo,
        stats: services.stats,
        games: services.games,
        feedback: services.feedback,
        onCancel: () => setState(() => _creating = false),
        onCreated: () {
          setState(() => _creating = false);
          _reload();
        },
      );
    }

    final snap = _snapshot;
    final games = snap?.games ?? const <OnlineGame>[];
    final turns = snap?.turns ?? const <String, int>{};
    final deadlines = snap?.deadlines ?? const <String, String?>{};
    final invites = inviteBucket(games);
    final active = activeBucket(games, turns);
    final waiting = waitingBucket(games);
    final acceptedWaiting = acceptedWaitingBucket(games);
    final myTurns = myTurnCount(games, turns);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NeoButton(
          label: '+ YENİ CANLI OYUN AÇ',
          variant: NeoButtonVariant.orange,
          fontSize: 13,
          letterSpacing: 1.5,
          padding: const EdgeInsets.symmetric(vertical: 12),
          onPressed: () => setState(() => _creating = true),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _subTabBtn(LiveSubTab.active, 'Devam Edenler', badge: myTurns),
          const SizedBox(width: 6),
          _subTabBtn(LiveSubTab.invites, 'Oyun Davetleri',
              badge: invites.length),
          const SizedBox(width: 6),
          _subTabBtn(LiveSubTab.recent, 'Son Oynananlar'),
        ]),
        const SizedBox(height: 12),
        if (snap == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Yükleniyor…',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
          )
        else
          switch (_subTab) {
            LiveSubTab.active => active.isEmpty
                ? _empty('Devam eden bir Canlı oyunun yok.')
                : _section('Devam Eden Oyunlar', [
                    for (final g in active)
                      _GameRow(
                        key: ValueKey('game-${g.id}'),
                        game: g,
                        isMyTurn: turns[g.id] == g.mySlotIndex,
                        deadline: deadlines[g.id],
                        onOpen: () => _openGame(g),
                      ),
                  ]),
            LiveSubTab.invites => (invites.isEmpty &&
                    acceptedWaiting.isEmpty &&
                    waiting.isEmpty)
                ? _empty('Bekleyen bir davet ya da oyunun yok.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (invites.isNotEmpty)
                        _section('Davet Bekliyor', [
                          for (final g in invites)
                            _PendingGameCard(
                              key: ValueKey('invite-${g.id}'),
                              game: g,
                              title:
                                  '${g.creatorSlot?.name ?? 'Bir arkadaşın'} seni ${g.playerCount} kişilik oyuna davet etti',
                              busy: _busyInviteId == g.myInviteId,
                              onRespond: (a) => _handleRespond(g, a),
                            ),
                        ]),
                      if (acceptedWaiting.isNotEmpty)
                        _section('Kabul Ettin — Diğerleri Bekleniyor', [
                          for (final g in acceptedWaiting)
                            _PendingGameCard(
                                key: ValueKey('aw-${g.id}'),
                                game: g,
                                title: '${g.playerCount} Kişilik Oyun'),
                        ]),
                      if (waiting.isNotEmpty)
                        _section('Bekleyen Oyunlar', [
                          for (final g in waiting)
                            _PendingGameCard(
                                key: ValueKey('w-${g.id}'),
                                game: g,
                                title: '${g.playerCount} Kişilik Oyun'),
                        ]),
                    ],
                  ),
            LiveSubTab.recent => services.games != null
                ? FutureBuilder(
                    future: services.games,
                    builder: (context, snapGames) {
                      final gamesRepo = snapGames.data;
                      if (gamesRepo == null) return const SizedBox.shrink();
                      return RecentGamesSection(
                        games: gamesRepo,
                        userId: user.id,
                        currentName: auth.accountName,
                        onlineOnly: true,
                        stats: services.stats,
                        emptyMessage: 'Henüz bitmiş bir Canlı oyunun yok.',
                      );
                    },
                  )
                : _empty('Henüz bitmiş bir Canlı oyunun yok.'),
          },
      ],
    );
  }

  Widget _subTabBtn(LiveSubTab t, String label, {int badge = 0}) {
    final active = _subTab == t;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _appliedDefaultTab = true; // elle seçim varsayılanı devre dışı bırakır
          setState(() => _subTab = t);
        },
        // Rozet web'deki gibi SEKME KUTUSUNUN sağ üst köşesinde (`absolute
        // -top-1 -right-1` = -4px) — Stack metni değil kutuyu sarmalı, yoksa
        // rozet metnin yanına düşer (kullanıcı bildirdi).
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: ShapeDecorationWithCssShadows(
                color: active ? _accent : _panel,
                borderColor: active ? _accent : _border,
                radius: 6,
                // Web: seçili `btn-raised`, seçili değil `btn-raised-neutral`.
                shadows: active ? kRaisedAccentShadows : kRaisedShadows,
              ),
              alignment: Alignment.center,
              child: Text(
                trUpper(label),
                textAlign: TextAlign.center,
                style: TextStyle(
                  // Web `text-[11px] ... tracking-[0.5px] py-2.5` — ölçüldü:
                  // 11px punto, 16.5px satır, 38.5px kutu (Parça 37).
                  // Setup'taki `_localSubTabBtn` ikizi ile birlikte değişir.
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: active ? Colors.white : _text,
                ),
              ),
            ),
            if (badge > 0)
              Positioned(top: -4, right: -4, child: CountBadge(count: badge)),
          ],
        ),
      ),
    );
  }

  Widget _empty(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(s,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Text(trUpper(title),
                style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: _muted)),
          ),
          ...children,
        ],
      );
}

/// Web GameRow'un aktif oyun hâli — avatar şeridi + "X açtı" + durum +
/// (yalnız sıra çağırandaysa) kalan süre.
class _GameRow extends StatelessWidget {
  final OnlineGame game;
  final bool isMyTurn;
  final String? deadline;
  final VoidCallback onOpen;
  const _GameRow({
    super.key,
    required this.game,
    required this.isMyTurn,
    required this.deadline,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = isMyTurn
        ? remainingTimeLabel(deadline, DateTime.now().millisecondsSinceEpoch)
        : null;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const ShapeDecorationWithCssShadows(
          color: _panel, borderColor: _border, radius: 6,
          shadows: kRaisedShadows, // web shadow-raised
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PlayerAvatarRow(players: [
                  for (final s in game.slots)
                    s.isAi
                        ? const AvatarRowPlayer(name: 'Yapay Zeka', isAi: true)
                        : AvatarRowPlayer(
                            name: s.name ?? 'Oyuncu', avatarUrl: s.avatarUrl),
                ]),
                const SizedBox(height: 2),
                Text('${game.creatorSlot?.name ?? 'Bir arkadaşın'} açtı',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'SpaceMono', fontSize: 9, color: _muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trUpper(onlineStatusLabel(game, isMyTurn: isMyTurn)),
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11, // web text-[11px]
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                  color: isMyTurn ? _green : _red,
                ),
              ),
              if (remaining != null)
                Text(
                  trUpper(remaining.text),
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 8,
                    letterSpacing: 0.5,
                    color: remaining.urgent ? _red : _muted,
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Web PendingGameCard — davet/bekleme kartı: başlık + kalan süre +
/// katılımcı listesi (+ Kabul/Reddet).
class _PendingGameCard extends StatelessWidget {
  final OnlineGame game;
  final String title;
  final bool busy;
  final void Function(bool accept)? onRespond;
  const _PendingGameCard({
    super.key,
    required this.game,
    required this.title,
    this.busy = false,
    this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final humanSlots = [
      for (final s in game.slots)
        if (!s.isAi) s
    ];
    final hasAi = game.slots.any((s) => s.isAi);
    final remaining = remainingInviteLabel(
        game.createdAt, DateTime.now().millisecondsSinceEpoch);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: const ShapeDecorationWithCssShadows(
        color: _panel, borderColor: _border, radius: 6,
        shadows: kRaisedShadows, // web shadow-raised
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                        color: _text)),
              ),
              const SizedBox(width: 8),
              Text(
                trUpper(remaining.text),
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9, // web text-[9px] — aktif satırdaki 8px'lik
                  letterSpacing: 0.5, // kardeşiyle KARIŞTIRMA, web'de de farklı
                  fontWeight:
                      remaining.urgent ? FontWeight.bold : FontWeight.normal,
                  color: remaining.urgent ? _red : _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(trUpper('Oyuncular'),
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  letterSpacing: 1,
                  color: _muted)),
          const SizedBox(height: 4),
          for (final s in humanSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                KAvatar(url: s.avatarUrl, name: s.name, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.name ?? 'Oyuncu',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _text)),
                ),
                Text(trUpper(participantLabel(s, game)),
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        letterSpacing: 0.5,
                        color: _muted)),
              ]),
            ),
          if (hasAi)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.smart_toy_outlined,
                      size: 13, color: _muted),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Yapay Zeka',
                      style: TextStyle(fontSize: 12, color: _text)),
                ),
              ]),
            ),
          if (onRespond != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: NeoButton(
                  label: busy ? '…' : 'KABUL ET',
                  variant: NeoButtonVariant.accent,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onPressed: busy ? null : () => onRespond!(true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: NeoButton(
                  label: busy ? '…' : 'REDDET',
                  variant: NeoButtonVariant.neutral,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onPressed: busy ? null : () => onRespond!(false),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
