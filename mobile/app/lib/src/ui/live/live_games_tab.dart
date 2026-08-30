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
import '../push/push_permission_flow.dart';
import '../auth/auth_modal.dart';
import '../auth/k_avatar.dart';
import '../game/count_badge.dart';
import '../game/neo_button.dart';
import '../game/player_avatar_row.dart';
import '../rank/league_rank.dart';
import '../rank/rank_scores.dart';
import '../rank/rank_seal.dart';
import '../setup/recent_games_section.dart';
import '../friends/friends_modal.dart' show showFriendInfoDialog, kFriendActionFailed;
import 'friend_suggest_modal.dart';
import 'live_game_create_form.dart';
import 'online_game_screen.dart';
import '../tokens.dart';
import '../loading_note.dart';
import '../game/neo_box.dart';
import '../../util/offline_notice.dart';

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

  /// Son yükleme sunucuya ulaşamadı. Bu, "çevrimdışısın" DEMEK DEĞİLDİR:
  /// tek bir düşen isteğe bakıp öyle demek, başka yerde bağlantısı çalışan
  /// kullanıcıya yalan söylemek olurdu (21 Ağustos 2026 kullanıcı kararı).
  bool _loadFailed = false;

  /// Sessiz otomatik yeniden deneme merdiveni — web `AUTO_RETRY_STEPS_MS`
  /// ile AYNI. `_reload`ın kendi retry'ı (repo katmanı, ~1.6 sn) ANLIK bir
  /// kesintiyi kapatır; bu merdiven ise kesinti sürerse kullanıcı HİÇBİR
  /// ŞEY yapmadan iyileşmeyi sürdürür. Son basamak tekrarlanır.
  static const List<Duration> autoRetrySteps = [
    Duration(seconds: 3),
    Duration(seconds: 8),
    Duration(seconds: 20),
    Duration(seconds: 30),
  ];
  int _autoRetryStep = 0;
  Timer? _autoRetryTimer;
  bool _creating = false;
  String? _busyInviteId;
  String? _lastUserId;
  Timer? _reloadDebounce;
  void Function()? _unsubscribe;
  int _loadSeq = 0;

  AppServices get services => widget.services;

  /// Davet/bekleme kartlarındaki isimlerin yanındaki rütbe mührü
  /// (18 Ağustos 2026). Kartlar StatelessWidget olduğundan lookup bir
  /// fonksiyon olarak aşağı geçiliyor.
  late final RankScores _rankScores;

  void _onRankScores() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _rankScores = RankScores(services.stats)..addListener(_onRankScores);
    final user = services.auth.user;
    _lastUserId = user?.id;
    if (user != null) _snapshot = _liveGamesCache[user.id];
    services.auth.addListener(_onAuthEvent);
    // Bağlantı durumu değişince mesaj ANINDA görünsün/kalksın (web
    // `useOnlineStatus`un yeniden render'ı).
    services.onlineStatus.addListener(_onConnectivity);
    // Öne dönüş tazelenmesi — web visibilitychange/focus/online eşleniği:
    // arka planda websocket askıya alınıp olay kaçmış olabilir.
    WidgetsBinding.instance.addObserver(this);
    _reload();
    // İkinci geçiş, kanalın KOPUP yeniden bağlanması: kopukken yayınlanan
    // olaylar kayıptır, o yüzden yeniden bağlanmanın kendisi bir tazeleme
    // sinyalidir (web `subscribeMyOnlineGames`in aynı kancası).
    _unsubscribe = services.onlineGames?.gateway
        .subscribe(_scheduleReload, onResubscribe: _scheduleReload);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleReload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    services.auth.removeListener(_onAuthEvent);
    services.onlineStatus.removeListener(_onConnectivity);
    _reloadDebounce?.cancel();
    _autoRetryTimer?.cancel();
    _unsubscribe?.call();
    _rankScores.removeListener(_onRankScores);
    _rankScores.dispose();
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

  void _clearAutoRetry() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = null;
    _autoRetryStep = 0;
  }

  void _scheduleAutoRetry() {
    _autoRetryTimer?.cancel();
    final i = _autoRetryStep < autoRetrySteps.length
        ? _autoRetryStep
        : autoRetrySteps.length - 1;
    if (_autoRetryStep < autoRetrySteps.length) _autoRetryStep++;
    _autoRetryTimer = Timer(autoRetrySteps[i], () {
      _autoRetryTimer = null;
      if (mounted) unawaited(_reload());
    });
  }

  /// "Tekrar Dene" — merdiveni başa sarar (kullanıcı beklemeyi seçmedi).
  void _handleManualRetry() {
    _clearAutoRetry();
    unawaited(_reload());
  }

  void _onConnectivity() {
    if (!mounted) return;
    setState(() {});
    // Bağlantı geri geldiyse listeyi hemen tazele.
    if (services.onlineStatus.online) unawaited(_reload());
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
    if (snap == null) {
      // Yükleme düştü. Eski liste KORUNUR ve ekranda kalır — üstüne yalnızca
      // "Güncellenemedi" şeridi biner (14 Ağustos'ta burada `kOffline...`
      // gösteriliyordu; 21 Ağustos'ta kaldırıldı: bağlantısı çalışan
      // kullanıcıya "internet yok" demek YANLIŞ bilgiydi). Elde hiç liste
      // yoksa ayrı bir panel + "Tekrar Dene" çıkar; her iki durumda da
      // merdiven kullanıcı hiçbir şey yapmadan denemeyi sürdürür.
      if (mounted) {
        setState(() => _loadFailed = true);
        _scheduleAutoRetry();
      }
      return;
    }
    _liveGamesCache[user.id] = snap;
    _clearAutoRetry();
    setState(() {
      _loadFailed = false;
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
    unawaited(_pushIzniniSorMaybe(snap, user.id));
  }

  /// Bildirim izni akışının TEK tetikleyicisi.
  ///
  /// **Koşul konum değil DURUM (28 Ağustos 2026, ürün kararı):** "Canlı
  /// sekmesi açıldı" tek başına yetmiyor — en az bir aktif oyun ya da
  /// bekleyen davet de olmalı. Oyunu olmayan birine, olmayan oyunlar için
  /// bildirim sorulmaz.
  ///
  /// Neden burası, oyun KURMA anı değil: en değerli bildirim (teslim uyarısı)
  /// ZATEN VAR OLAN oyunlar için. Yalnızca kurma anında sorulsaydı, sekiz
  /// açık oyunu olup yeni oyun kurmayan bir kullanıcının token'ı hiç
  /// toplanmaz ve k-lig puanı kaybını önleyecek bildirim tam da onu ıskalardı.
  ///
  /// Sekmeye bakan kişi ekranda zaten "Sıra sende" / "Rakibin hamlesi
  /// bekleniyor" etiketlerine bakıyor; soru tam da o etiketlerin karşılığı.
  ///
  /// Kaç kez sorulacağı ve sistem diyaloğunun ne zaman açılacağı BURADA
  /// değil `util/push_rules.dart`ta — burada yalnızca "durum uygun mu".
  Future<void> _pushIzniniSorMaybe(OnlineGamesSnapshot snap, String userId) async {
    final push = services.push;
    final messaging = services.pushMessaging;
    final storage = services.storage;
    if (push == null || messaging == null || storage == null) return;
    final aktifOyunVar = inviteBucket(snap.games).isNotEmpty ||
        activeBucket(snap.games, snap.turns).isNotEmpty;
    final flags = (await storage).flags;
    if (!mounted) return;
    await pushIzniAkisi(
      context,
      messaging: messaging,
      repo: push,
      flags: flags,
      userId: userId,
      aktifOyunVar: aktifOyunVar,
    );
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
      // Kullanıcı bir davete KABUL ET/REDDET dedi; hata yalnızca loglanırsa
      // spinner söner, kart aynen durur ve ekranda hiçbir açıklama olmaz —
      // "bastım, olmadı" (13 Ağustos 2026 denetimi, Parça 89).
      debugPrint('[Kelimeki] respondInvite hatası: $e');
      if (mounted) await showFriendInfoDialog(context, kFriendActionFailed);
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
      settings: const RouteSettings(name: 'online-game'),
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
        onlineStatus: services.onlineStatus,
      ),
    ));
    if (mounted) unawaited(_reload());
    // ⚠ ROZET burada TAZELENMİYOR ve bu bilinçli. 28 Ağustos 2026'da rozet
    // bir `onGameClosed` callback'iyle tam bu noktaya bağlanmıştı; Sürüm B
    // Canlı tahtayı açan İKİNCİ bir kapı (bildirime dokun → doğru oyunu aç)
    // eklediğinden o çare aynı gün öngörüldüğü gibi yetersiz kaldı: yeni
    // kapının callback'i çağırmayı unutması, düzeltilen hatanın aynısını
    // geri getirirdi ve derleyici bunu YAKALAMAZDI.
    //
    // Rozeti artık Setup'ın `didPopNext`i tazeliyor (`ui/route_observer.dart`)
    // — hangi kapıdan girilirse girilsin dönüş oradan geçer. Aşağıdaki
    // `_reload()` ise KALIYOR: o bu sekmenin KENDİ listesi, rozet değil.
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
        chat: services.chat,
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
    // Kartlarda gösterilecek katılımcıların rütbe puanı — `ensure` yalnızca
    // EKSİK id'ler için ağa gider ve bildirimini bir sonraki microtask'a
    // ertelediğinden build içinden çağrılması güvenli.
    _rankScores.ensure([
      for (final g in [...invites, ...waiting, ...acceptedWaiting])
        for (final sl in g.slots)
          if (!sl.isAi) sl.userId,
    ]);
    final myTurns = myTurnCount(games, turns);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Web: `text-sm` (14) + `py-2.5` (10) + satır 20 → kutu tam 40;
        // aradaki boşluklar kapsayıcının `gap-5`inden (20) geliyor,
        // sekmelerin kendi arası `gap-2` (8). Üçü de ölçüldü (Parça 80).
        NeoButton(
          label: '+ YENİ CANLI OYUN AÇ',
          variant: NeoButtonVariant.orange,
          fontSize: 14,
          lineHeight: 20 / 14,
          letterSpacing: 1.5,
          padding: const EdgeInsets.symmetric(vertical: 10),
          onPressed: () => setState(() => _creating = true),
        ),
        const SizedBox(height: 20),
        Row(children: [
          _subTabBtn(LiveSubTab.active, 'Devam Edenler', badge: myTurns),
          const SizedBox(width: 8),
          _subTabBtn(LiveSubTab.invites, 'Oyun Davetleri',
              badge: invites.length),
          const SizedBox(width: 8),
          _subTabBtn(LiveSubTab.recent, 'Son Oynananlar'),
        ]),
        const SizedBox(height: 20),
        // Liste ekranda ama tazelenemedi: veri BAYAT, yanlış değil. Şerit
        // bunu söyler ve elle deneme yolunu açık tutar; merdiven zaten
        // arka planda denemeye devam ediyor.
        if (_loadFailed && snap != null && services.onlineStatus.online) ...[
          // Web `text-[10px] uppercase tracking-[0.5px]` ile aynı — ekranı
          // kaplamayan ince bir not, dokunma hedefi DEĞİL: kullanıcının
          // yapması gereken bir şey yok, merdiven arka planda deniyor ve
          // başarınca şerit kendiliğinden kalkar.
          Text(
            trUpper(kStaleDataNotice),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 10,
                letterSpacing: 0.5,
                color: _muted),
          ),
          const SizedBox(height: 12),
        ],
        if (!services.onlineStatus.online)
          // Canlı oyunun HER parçası (liste, davet, geçmiş) sunucudan
          // geliyor — çevrimdışıyken üç alt sekme de aynı şeyi söyler.
          // Yapay Zeka sekmesi BİLİNÇLİ olarak farklı konuşur (setup_screen).
          _empty(kOfflineNoConnection)
        else if (_loadFailed && snap == null)
          // Elde gösterilecek HİÇBİR liste yok: tek dürüst cümle "yüklenemedi"
          // — "hiç oyunun yok" da "internet yok" da yanlış olurdu.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _empty(kLoadFailedNotice),
              NeoButton(
                label: trUpper(kRetryLabel),
                variant: NeoButtonVariant.accent,
                fontSize: 14,
                lineHeight: 20 / 14,
                letterSpacing: 1.5,
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: _handleManualRetry,
              ),
            ],
          )
        else if (snap == null)
          const KLoadingNote()
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
                              tierOf: _rankScores.tierOf,
                            ),
                        ]),
                      if (acceptedWaiting.isNotEmpty)
                        _section('Kabul Ettin — Diğerleri Bekleniyor', [
                          for (final g in acceptedWaiting)
                            _PendingGameCard(
                                key: ValueKey('aw-${g.id}'),
                                game: g,
                                tierOf: _rankScores.tierOf,
                                title: '${g.playerCount} Kişilik Oyun'),
                        ]),
                      if (waiting.isNotEmpty)
                        _section('Bekleyen Oyunlar', [
                          for (final g in waiting)
                            _PendingGameCard(
                                key: ValueKey('w-${g.id}'),
                                game: g,
                                tierOf: _rankScores.tierOf,
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

/// Web `participantLabelClass` (LiveGamesTab.tsx) — `participantLabel`in
/// RENGİ. Dallar etiketin dallarıyla BİREBİR aynı sırada: ikisi tek bir
/// karar, ayrı yerlerde ayrışmasınlar.
///
/// Kullanıcı isteği (30 Ağustos 2026): "Kabul etti" yeşil, "Bekliyor"
/// kırmızı. "Reddetti"/"Davet gönderen" bilinçli olarak nötr — kırmızı
/// burada "hâlâ cevap bekleniyor" uyarısı, "olumsuz sonuç" değil.
///
/// "Reddetti" zaten bu listede GÖRÜNMÜYOR: ret oyunu anında `abandoned`
/// yapıyor, kovalar da yalnızca `pending`/`active` eşliyor (ölçüm: web
/// ikizinin yorumu).
Color _participantLabelColor(OnlineSlot slot, OnlineGame game) {
  if (game.createdBy != null && slot.userId == game.createdBy) return _muted;
  if (slot.inviteStatus == 'accepted') return _green;
  if (slot.inviteStatus == 'declined') return _muted;
  return _red;
}

/// Web PendingGameCard — davet/bekleme kartı: başlık + kalan süre +
/// katılımcı listesi (+ Kabul/Reddet).
class _PendingGameCard extends StatelessWidget {
  final OnlineGame game;
  final String title;
  final bool busy;
  final void Function(bool accept)? onRespond;

  /// Katılımcının rütbesi — puan bilinmiyorsa null (mühür çizilmez).
  final RankTier? Function(String? userId) tierOf;
  const _PendingGameCard({
    super.key,
    required this.game,
    required this.title,
    required this.tierOf,
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
                  child: Row(children: [
                    Flexible(
                      child: Text(s.name ?? 'Oyuncu',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _text)),
                    ),
                    // 16px — satırın 12px'lik puntosuna göre (web ile aynı).
                    if (tierOf(s.userId) case final t?) ...[
                      const SizedBox(width: 4),
                      RankSeal(tier: t, size: 16),
                    ],
                  ]),
                ),
                Text(trUpper(participantLabel(s, game)),
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        letterSpacing: 0.5,
                        color: _participantLabelColor(s, game))),
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
