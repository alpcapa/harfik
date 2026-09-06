// Tüm Oyunlar — web `GameHistoryModal.tsx` portu.
//
// Her kart: tarih + Canlı/Yapay Zeka rozeti + (varsa) sohbet rozeti, kalp
// (beğeni) ve beğeni sayısı, final sıralamasıyla oyuncu satırları (sıra no,
// rozet, ad, TESLİM OLDU etiketi, Puan, k-lig). Karta dokunmak o oyunun
// tahtasını altta açar/kapar — tahta lazy çekilir ve bir kez çekilince
// önbellekte kalır (web'in aynı kararı).
//
// Açık tahta önizlemesine dokunmak "Paylaş / Kapat" aksiyon menüsünü açar;
// paylaşım skor şeridi + tahtayı tek PNG olarak yakalayıp sistem paylaş
// sayfasına verir (web'in aynı akışı).
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import '../text_scale.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../config/env.dart';
import '../../data/game_record.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../../util/share_board.dart';
import '../../data/auth_service.dart';
import '../../data/friends_api.dart' show friendErrorText;
import '../../data/online_games_api.dart' show rematchSlots;
import '../online_games_scope.dart';
import '../game/dialog_shell.dart';
import '../auth/k_avatar.dart';
import '../chat/game_chat_history_modal.dart';
import '../game/action_sheet.dart';
import '../game/board_widget.dart';
import '../game/modal_shell.dart';
import '../game/move_history_modal.dart';
import '../game/player_badge.dart';
import 'player_score_card_modal.dart';
import 'score_box_row.dart';
import '../tokens.dart';
import '../ai_level_badge.dart';
import '../../util/ai_level.dart';
import '../loading_note.dart';
import '../game/neo_box.dart';
import 'icon_tap_rescue.dart';

const _panel = kPanel;
const _border = kBorder;
const _muted = kMuted;
const _text = kText;
const _accent = kAccent;
const _green = kGreen;
const _gold = kGold;
const _red = kRed;

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

  /// "Beğenenler" listesinden bir isme dokununca o kişinin skor kartını
  /// açmak için. null ise isimler tıklanmaz (çalışmayan kontrol koymuyoruz).
  StatsRepo? stats,

  /// Verilirse ("Son Oynadıklarım"dan bir satıra dokununca) modal açılır
  /// açılmaz bu oyunun tahtası genişletilmiş gelir ve kart listenin
  /// ORTASINA kaydırılır — kullanıcı ayrıca aramak zorunda kalmaz.
  String? initialExpandedId,

  /// Testler gerçek paylaş kanalına gitmesin diye enjekte edilebilir.
  ShareBoardFn? share,

  /// Testler için: görsel yakalama (bkz. `CaptureBoardFn`).
  CaptureBoardFn? capture,

  /// Yalnızca "Beğenenler" listesinden açılan skor kartına GEÇİRİLİR —
  /// kafa kafaya oran çubuğu "ben kimim"i oradan okuyor. null geçilirse
  /// çubuk O KARTTA sessizce çizilmez; web'de karşılığı `useAuth()`
  /// bağlamı olduğu için orada böyle bir tuzak yok (3 Eylül 2026,
  /// Parça 185: beş çağrı yerinin dördü `auth` geçiyordu, bu biri
  /// geçmiyordu ve çubuk yalnızca burada kayboluyordu).
  AuthService? auth,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => GameHistoryModal(
      games: games,
      userId: userId,
      playerCount: playerCount,
      currentName: currentName,
      isMe: isMe,
      stats: stats,
      initialExpandedId: initialExpandedId,
      share: share,
      capture: capture,
      auth: auth,
    ),
  );
}

class GameHistoryModal extends StatefulWidget {
  final GamesRepo games;
  final String userId;
  final int? playerCount;
  final String? currentName;
  final bool isMe;
  final StatsRepo? stats;
  final String? initialExpandedId;
  final ShareBoardFn? share;
  final CaptureBoardFn? capture;
  final AuthService? auth;

  const GameHistoryModal({
    super.key,
    required this.games,
    required this.userId,
    required this.playerCount,
    this.currentName,
    this.isMe = true,
    this.stats,
    this.initialExpandedId,
    this.share,
    this.capture,
    this.auth,
  });

  @override
  State<GameHistoryModal> createState() => _GameHistoryModalState();
}

class _GameHistoryModalState extends State<GameHistoryModal> {
  List<GameHistoryEntry>? _entries;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _expandedId;

  /// Tümü / Favoriler. Favoriler, hedefin SAHİP OLDUĞU değil BEĞENDİĞİ
  /// oyunları listeler (web'in aynı ayrımı).
  bool _favoritesOnly = false;

  /// Son yükleme HATA verdi mi — boş listeden AYRI tutuluyor: çevrimdışı
  /// açan kullanıcıya "Henüz kayıtlı bir oyunun yok." demek, oyunlarının
  /// silindiğini düşündürür (13 Ağustos 2026 denetimi, Parça 89).
  bool _loadFailed = false;

  /// gameId → beğenenler (bir kez çekilip önbellekte tutulur; kalbe basmak
  /// bu önbelleği geçersiz kılar ki bir dahaki açılışta güncel liste gelsin).
  final _likers = <String, List<GameLiker>>{};

  /// gameId → tahta (bir kez çekilince önbellekte kalır; null değeri
  /// "çekildi ama kayıt yok" demek — web'in aynı ayrımı).
  final _snapshots = <String, List<BoardSnapshotTile>?>{};
  String? _snapshotLoadingId;

  /// gameId → hamle dökümü. `_snapshots` ile AYNI önbellek deseni: bir kez
  /// çekilir, null değeri "kaydedilmemiş" demek. Ağ hatası önbelleğe
  /// GİRMEZ — bir sonraki dokunuşta yeniden denensin.
  final _moves = <String, List<HistoryEntry>?>{};
  String? _movesLoadingId;

  final _scrollController = ScrollController();

  /// Paylaşım için yakalanacak düğüm — aynı anda yalnızca BİR kart açık
  /// olabildiğinden (tek `_expandedId`) tek anahtar yeterli (web'de de tek
  /// `boardCaptureRef`).
  final _captureKey = GlobalKey();

  /// Hedef karta kaydırmak için: id → o kartın anahtarı.
  final _entryKeys = <String, GlobalKey>{};
  /// Kart içindeki küçük ikonların kutularını ölçmek için (bkz.
  /// `icon_tap_rescue.dart`) — kart anahtarlarıyla aynı ömür.
  final _iconKeys =
      <String, ({GlobalKey like, GlobalKey chat, GlobalKey moves})>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
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

  /// İlk yükleme. `initialExpandedId` verilmişse hedef sayfada BULUNANA ya
  /// da liste tükenene kadar sayfa sayfa çekmeye devam eder — web'in aynı
  /// düzeltmesi: "Son Oynadıklarım" TÜR filtreli bir sıralamadan geliyor,
  /// buradaki liste ise karma; hedef ilk sayfanın çok gerisinde kalabiliyor
  /// ve o zaman kaydırma sessizce hiçbir şey yapmıyordu.
  Future<void> _loadInitial() async {
    final target = widget.initialExpandedId;
    const maxPages = 25; // ~500 oyun — sonsuz döngüye karşı güvenlik ağı
    final acc = <GameHistoryEntry>[];
    var offset = 0;
    var more = true;
    var found = false;
    var pages = 0;
    do {
      final res = await widget.games.history(
        userId: widget.userId,
        playerCount: widget.playerCount,
        offset: offset,
        limit: _pageSize,
        favoritesOnly: _favoritesOnly,
      );
      if (!mounted) return;
      _loadFailed = res.failed;
      acc.addAll(res.games);
      more = res.hasMore;
      offset += res.games.length;
      pages++;
      if (target != null && res.games.any((g) => g.id == target)) found = true;
      if (res.games.isEmpty) break; // sunucu boş döndü: ilerlemiyoruz
    } while (target != null && !found && more && pages < maxPages);

    setState(() {
      _entries = acc;
      _hasMore = more;
      _loadingMore = false;
      if (found) _expandedId = target;
    });
    if (found) unawaited(_revealTarget(target!));
  }

  /// Hedef kartın tahtasını açıp kartı listenin ortasına getirir. Ortalama
  /// İKİ kez yapılır: tahta asenkron geldiğinden kart o sırada "Yükleniyor…"
  /// kadar kısa; gerçek tahta render olunca kart ciddi ölçüde büyüyüp
  /// hizalama bozuluyor (web'de de aynı çift çağrı var).
  Future<void> _revealTarget(String id) async {
    unawaited(_centerOnEntry(id));
    if (_snapshots.containsKey(id)) return;
    setState(() => _snapshotLoadingId = id);
    final snap = await widget.games.boardSnapshot(id);
    if (!mounted) return;
    setState(() {
      _snapshots[id] = snap;
      _snapshotLoadingId = null;
    });
    unawaited(_centerOnEntry(id));
  }

  /// Kartı görünür alanın ORTASINA kaydırır. `Scrollable.ensureVisible`
  /// yalnızca DOM'daki (build edilmiş) bir öğe için çalışır; ListView tembel
  /// olduğundan hedef henüz oluşmamış olabilir — o durumda birer viewport
  /// aşağı atlayıp tekrar bakıyoruz. Web burada iç içe kaydırma alanları
  /// yüzünden elle `scrollTop` hesabı yapmak zorunda kalmıştı; Flutter'ın
  /// `ensureVisible`'ı iç içe Scrollable'ları kendisi çözüyor.
  Future<void> _centerOnEntry(String id) async {
    for (var i = 0; i < 60; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final ctx = _entryKeys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx,
            alignment: 0.5, duration: const Duration(milliseconds: 200));
        return;
      }
      if (!_scrollController.hasClients) continue;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent) return; // liste bitti, kart yok
      _scrollController.jumpTo(
          (pos.pixels + pos.viewportDimension).clamp(0.0, pos.maxScrollExtent));
    }
  }

  Future<void> _loadPage(int offset) async {
    // Sekme değişimi uçuştaki bir sayfayla yarışabilir: dönen sayfa artık
    // geçerli olmayan sekmeye aitse yazma (web'de `cancelled` bayrağının
    // yaptığı iş).
    final forFavorites = _favoritesOnly;
    final res = await widget.games.history(
      userId: widget.userId,
      playerCount: widget.playerCount,
      offset: offset,
      limit: _pageSize,
      favoritesOnly: forFavorites,
    );
    if (!mounted || forFavorites != _favoritesOnly) return;
    setState(() {
      _entries = [...?(offset == 0 ? null : _entries), ...res.games];
      _hasMore = res.hasMore;
      _loadingMore = false;
      // Sekme değişimi de bu yoldan geçiyor (offset 0): orada bir ağ
      // hatası olursa boş liste "favori işaretlediğin oyun yok" diye
      // görünürdü. Sonraki sayfalarda zaten satır var, mesaj çizilmiyor.
      _loadFailed = res.failed;
    });
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore || _entries == null) return;
    setState(() => _loadingMore = true);
    _loadPage(_entries!.length);
  }

  void _selectTab(bool favoritesOnly) {
    if (_favoritesOnly == favoritesOnly) return;
    setState(() {
      _favoritesOnly = favoritesOnly;
      _entries = null;
      _hasMore = true;
      _loadingMore = false;
      _expandedId = null;
      _snapshots.clear();
      _snapshotLoadingId = null;
    });
    _loadPage(0);
  }

  /// Kalp: İYİMSER güncelleme — istek başarısızsa (ör. çevrimdışı) geri
  /// alınır. Web'le aynı: repo `null` dönerse çağıran flip'i tekrar uygular.
  Future<void> _toggleLike(GameHistoryEntry entry) async {
    setState(() {
      _entries = [
        for (final g in _entries ?? const <GameHistoryEntry>[])
          g.id == entry.id ? g.flipLike() : g
      ];
      _likers.remove(entry.id); // bayatladı
    });
    final res = await widget.games.toggleLike(entry.id);
    if (!mounted || res != null) return;
    setState(() {
      _entries = [
        for (final g in _entries ?? const <GameHistoryEntry>[])
          g.id == entry.id ? g.flipLike() : g
      ];
    });
  }

  Future<void> _showLikers(GameHistoryEntry entry) async {
    if (!_likers.containsKey(entry.id)) {
      final rows = await widget.games.likers(entry.id);
      if (!mounted) return;
      _likers[entry.id] = rows;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _LikersModal(
        likers: _likers[entry.id] ?? const [],
        stats: widget.stats,
        games: widget.games,
        auth: widget.auth,
      ),
    );
  }

  /// Hamle dökümü rozetine dokununca — döküm LAZY çekilir (liste sorgusuna
  /// hiç girmez, `board_snapshot`/`messages` ile aynı gerekçe: satır başına
  /// birkaç KB). Web'de olduğu gibi mevcut `MoveHistoryModal` yeniden
  /// kullanılıyor: o yalnızca `moveHistory` ve `players`ı okuduğundan boş
  /// bir tahta anlık görüntüsü yeterli.
  Future<void> _showMoves(GameHistoryEntry entry) async {
    if (!_moves.containsKey(entry.id)) {
      setState(() => _movesLoadingId = entry.id);
      final res = await widget.games.moves(entry.id);
      if (!mounted) return;
      setState(() => _movesLoadingId = null);
      if (!res.ok) {
        await _showMovesNote(
            'Hamleler yüklenemedi. Bağlantını kontrol edip tekrar dene.');
        return;
      }
      _moves[entry.id] = res.moves;
    }
    if (!mounted) return;
    final rows = _moves[entry.id];
    if (rows == null || rows.isEmpty) {
      // Kolon eklenmeden ÖNCE biten yerel oyunlar — veri hiç yazılmamış,
      // kurtarılamaz (tahta önizlemesindeki aynı durum).
      await _showMovesNote('Bu oyun için hamle geçmişi kaydedilmemiş.');
      return;
    }
    await showMoveHistoryModal(
      context,
      buildSnapshotGameState(const [], entry.playerCount, entry.players)
          .copyWith(moveHistory: rows),
    );
  }

  Future<void> _showMovesNote(String text) => showDialog<void>(
        context: context,
        builder: (_) => KModal(
          title: 'Hamleler',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
          ),
        ),
      );

  /// Açık tahta önizlemesine dokununca: Paylaş / (Tekrar Oyna) / Kapat.
  ///
  /// "Tekrar Oyna" 4 Eylül 2026'da eklendi (kullanıcı isteği) ve YALNIZCA
  /// Canlı oyunlarda çıkıyor — YZ kayıtlarında yeni bir yerel oyun
  /// başlatmak, o an kaydedilmiş devam eden oyunu ezme riski taşıyor
  /// (`docs/decisions/local-game-persistence.md`), kapsam bilerek dar.
  /// Kapsam yoksa (çevrimdışı derleme) ya da liste başkasına aitse
  /// gösterilmez — çalışmayan bir kontrol koymuyoruz.
  Future<void> _openBoardSheet(GameHistoryEntry entry) async {
    final canRematch = widget.isMe &&
        entry.onlineGameId != null &&
        widget.games.gateway.currentUserId != null &&
        OnlineGamesScope.maybeOf(context) != null;
    await showActionSheet(context, actions: [
      ActionSheetItem(label: 'Paylaş', onSelect: () => unawaited(_share(entry))),
      if (canRematch)
        ActionSheetItem(
            label: 'Tekrar Oyna',
            onSelect: () => unawaited(_handleRematch(entry))),
      ActionSheetItem(
          label: 'Kapat', onSelect: () => setState(() => _expandedId = null)),
    ]);
  }

  /// Geçmişten rövanş — oyun sonundaki "Tekrar Oyna" ile AYNI iş
  /// (`online_game_screen.dart` → `_handleRematch`); metinler ve buton
  /// etiketleri de bilerek birebir, kullanıcı ikisini aynı şey sanıyor.
  ///
  /// ⚠ Kadro geçmiş kaydından ÇIKMIYOR: `GamePlayerSnapshot` isim/skor/YZ
  /// taşır, **`user_id` YOK** ve `create_online_game` koltuk başına user_id
  /// istiyor. Bu yüzden biten oyunun `online_games.slots` satırı ayrıca
  /// okunuyor; sıralama kuralı `rematchSlots`ta, oyun ekranıyla TEK kaynak.
  Future<void> _handleRematch(GameHistoryEntry entry) async {
    final repo = OnlineGamesScope.maybeOf(context);
    final myId = widget.games.gateway.currentUserId;
    final onlineId = entry.onlineGameId;
    if (repo == null || myId == null || onlineId == null) return;

    final meIndex = _findMeIndex(entry, entry.players);
    final names = <String>[
      for (var i = 0; i < entry.players.length; i++)
        if (!entry.players[i].isAi && i != meIndex) entry.players[i].name,
    ];
    final withAi = entry.players.any((p) => p.isAi);

    // Kabul butonu SOLDA (Parça 25 kuralı) — showKConfirm bunu garanti eder.
    final ok = await showKConfirm(
      context,
      title: 'Tekrar Oyna',
      message: '${names.join(', ')} ile aynı kadroda yeni bir oyun açılacak ve '
          'davet gönderilecek.'
          '${withAi ? ' 4. koltuk yine Yapay Zeka olacak.' : ''} Emin misin?',
      confirmLabel: 'TEKRAR OYNA',
    );
    if (!ok || !mounted) return;

    String? error;
    try {
      final slots = await repo.finishedGameSlots(onlineId);
      if (slots == null) {
        error = 'Bu oyunun kadrosuna ulaşılamadı, rövanş açılamıyor.';
      } else {
        await repo.create(entry.playerCount, rematchSlots(slots, myId));
      }
    } catch (e) {
      // LiveGameCreateForm/oyun ekranıyla AYNI helper: sunucunun Türkçe
      // reddini ham toString() gürültüsü olmadan gösterir.
      error = friendErrorText(e);
    }
    if (!mounted) return;
    await showKInfo(
      context,
      title: 'Tekrar Oyna',
      message: error ??
          'Davetiniz gönderilmiştir.\n\n'
              '${names.join(', ')} yanıt verince oyun başlayacak.'
              '${withAi ? ' 4. koltuk Yapay Zeka.' : ''}',
      buttonLabel: error == null ? 'TAMAM' : 'KAPAT',
    );
  }

  /// Web `handleShare` sırası: önce oyunu paylaşıma aç (link ancak öyle bir
  /// şey gösterir), sonra görseli yakala, sonra sistem paylaş sayfası.
  /// İşaretleme başarısızsa linksiz paylaşılır — hiç paylaşmamaktan iyi.
  Future<void> _share(GameHistoryEntry entry) async {
    final shared = await widget.games.markShared(entry.id);
    final png = await (widget.capture ?? captureBoundaryAsPng)(_captureKey);
    if (!mounted) return;
    // iPad ankrajı: popover paylaşılan TAHTAYI göstersin; tahta o an
    // ağaçta değilse modalın kendi kutusuna düşüyoruz.
    final anchor = shareOriginFrom(_captureKey.currentContext ?? context);
    await (widget.share ?? shareBoard)(
      png: png,
      text: shareMessage,
      url: shared ? '$webOrigin/game/${entry.id}' : null,
      origin: anchor,
    );
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
      title: 'Tüm Oyunlar',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
                child: _FilterTab(
                    label: 'Tümü',
                    selected: !_favoritesOnly,
                    onTap: () => _selectTab(false))),
            const SizedBox(width: 6),
            Expanded(
                child: _FilterTab(
                    label: 'Favoriler',
                    selected: _favoritesOnly,
                    onTap: () => _selectTab(true))),
          ]),
          const SizedBox(height: 12),
          _buildList(entries),
        ],
      ),
    );
  }

  Widget _buildList(List<GameHistoryEntry>? entries) {
    return entries == null
          ? const KLoadingNote()
          : entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                        _loadFailed
                            ? 'Oyun geçmişi yüklenemedi. Bağlantını kontrol '
                                'edip tekrar dene.'
                            : _favoritesOnly
                                ? (widget.isMe
                                    ? 'Henüz favori işaretlediğin bir oyun yok.'
                                    : 'Bu oyuncunun henüz favori işaretlediği bir oyun yok.')
                                : 'Henüz kayıtlı bir oyunun yok.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                        // Kaydırma hedefi olabilmesi için sabit anahtar.
                        key: _entryKeys.putIfAbsent(e.id, GlobalKey.new),
                        // Küçük ikonların kutularını ÇALIŞMA ZAMANINDA
                        // ölçebilmek için kalıcı anahtarlar (bkz.
                        // `icon_tap_rescue.dart`). `_entryKeys` ile aynı
                        // önbellek deseni — her yeniden çizimde yenisini
                        // üretmek GlobalKey sözleşmesini bozardı.
                        iconKeys: _iconKeys.putIfAbsent(
                            e.id,
                            () => (
                                  like: GlobalKey(),
                                  chat: GlobalKey(),
                                  moves: GlobalKey(),
                                )),
                        captureKey: _expandedId == e.id ? _captureKey : null,
                        entry: e,
                        currentName: widget.currentName,
                        // Favoriler listesinde bir satır, görüntüleyenin
                        // SAHİP OLMADIĞI bir oyuna ait olabilir (başkasının
                        // kartından beğenilmiş) — o durumda entry.rank/
                        // player_score o satırın gerçek sahibine ait
                        // olduğundan "ben" hesaplamak yanlış oyuncuyu
                        // vurgulardı (web'in aynı koruması).
                        isMyRow: widget.isMe &&
                            (widget.games.gateway.currentUserId == null ||
                                e.userId == widget.games.gateway.currentUserId),
                        expanded: _expandedId == e.id,
                        snapshotLoading: _snapshotLoadingId == e.id,
                        snapshotFetched: _snapshots.containsKey(e.id),
                        snapshot: _snapshots[e.id],
                        onTap: () => _toggleBoard(e),
                        onToggleLike: () => _toggleLike(e),
                        onShowLikers: () => _showLikers(e),
                        onShowChat: () => showGameChatHistory(
                          context,
                          games: widget.games,
                          gameId: e.id,
                          onlineGameId: e.onlineGameId,
                        ),
                        onShowMoves: () => _showMoves(e),
                        movesLoading: _movesLoadingId == e.id,
                        onTapBoard: () => _openBoardSheet(e),
                      );
                    },
                  ),
                );
  }
}

/// Tümü / Favoriler sekmesi — web'deki iki butonun aynı görsel dili.
class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _accent : _panel,
            border: selected ? null : Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            trUpper(label),
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: selected ? Colors.white : _muted,
            ),
          ),
        ),
      );
}

/// Beğeni sayısına dokununca açılan liste; bir isme dokunmak o kişinin
/// skor kartını açar (web'in "kartına gir → oyununu beğen → kimler
/// beğenmiş → onun kartına gir" zinciri).
class _LikersModal extends StatelessWidget {
  final List<GameLiker> likers;
  final StatsRepo? stats;
  final GamesRepo games;

  /// Açılan skor kartındaki kafa kafaya çubuğu için — `State` alanı DEĞİL,
  /// bu ayrı bir `StatelessWidget` (burada `widget.` yoktur; aynı sınıf
  /// hata 2 Eylül 2026'da `_RecentRow`da da yapılmıştı).
  final AuthService? auth;

  const _LikersModal(
      {required this.likers,
      required this.stats,
      required this.games,
      required this.auth});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return KModal(
      title: 'Beğenenler',
      child: likers.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Bu oyunu henüz kimse beğenmemiş.',
                    style: TextStyle(
                        fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in likers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GestureDetector(
                      // stats yoksa skor kartı açılamaz — o durumda satır
                      // bilerek tıklanmaz (çalışmayan kontrol koymuyoruz).
                      onTap: s == null
                          ? null
                          : () => showPlayerScoreCard(
                                context,
                                stats: s,
                                userId: l.userId,
                                name: l.shortName,
                                avatarUrl: l.avatarUrl,
                                games: Future.value(games),
                                auth: auth,
                              ),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          KAvatar(url: l.avatarUrl, name: l.shortName, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l.shortName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 13,
                                    color: _text)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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

  /// Bu satır GERÇEKTEN görüntüleyene mi ait (web `isMyRow`) — "Sen"
  /// yedeği, kendi satırının vurgusu ve güncel-ad ikamesi buna bağlı.
  final bool isMyRow;
  final bool expanded;
  final bool snapshotLoading;
  final bool snapshotFetched;
  final List<BoardSnapshotTile>? snapshot;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final VoidCallback onShowLikers;
  final VoidCallback onShowChat;
  final VoidCallback onShowMoves;

  /// Hamle dökümü çekiliyor mu (yalnızca bu kart için).
  final bool movesLoading;

  /// Açık tahtaya dokunma — Paylaş/Kapat menüsü.
  final VoidCallback onTapBoard;

  /// Yalnızca AÇIK kartta dolu: paylaşım görselinin yakalanacağı düğüm
  /// (skor şeridi + tahta). Kapalı kartlarda null.
  final GlobalKey? captureKey;

  /// Küçük ikonların (kalp, mesaj balonu, hamle dökümü) kutularını ölçmek
  /// için kalıcı anahtarlar — ıskalanan dokunuşu onlara yönlendirmek
  /// gerekiyor (bkz. `icon_tap_rescue.dart`).
  final ({GlobalKey like, GlobalKey chat, GlobalKey moves}) iconKeys;

  const _EntryCard({
    super.key,
    required this.captureKey,
    required this.iconKeys,
    required this.entry,
    required this.currentName,
    required this.isMyRow,
    required this.expanded,
    required this.snapshotLoading,
    required this.snapshotFetched,
    required this.snapshot,
    required this.onTap,
    required this.onToggleLike,
    required this.onShowLikers,
    required this.onShowChat,
    required this.onShowMoves,
    required this.movesLoading,
    required this.onTapBoard,
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
      // Satır bana ait değilse hiçbir slot "ben" değil (-1) — aksi halde
      // başkasının skoruna kendi güncel adım yapıştırılırdı.
      meIndex = isMyRow ? _findMeIndex(entry, players) : -1;
    } else {
      final fb = _fallbackPlayers(entry, isMyRow, currentName);
      players = fb.known;
      unknownCount = fb.unknownCount;
      meIndex = isMyRow ? fb.meIndex : -1;
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
            // `onTap` DEĞİL `onTapUp`: ıskalanan dokunuşu doğru ikona
            // yönlendirebilmek için NOKTA gerekiyor (bkz.
            // `icon_tap_rescue.dart`). Nokta hiçbir ikonun bölgesine
            // düşmezse davranış eskisiyle aynı — kart açılıp kapanır.
            onTapUp: (d) {
              final hedef = rescuedIconTarget<VoidCallback>(d.globalPosition, [
                (rect: globalRectOf(iconKeys.like), target: onToggleLike),
                (rect: globalRectOf(iconKeys.chat), target: onShowChat),
                (rect: globalRectOf(iconKeys.moves), target: onShowMoves),
              ]);
              (hedef ?? onTap)();
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: ShapeDecorationWithCssShadows(
                // Web: Canlı kayıtlar hafif gri zeminle ayrışır.
                color: isOnline ? _panel : Colors.white,
                borderColor: _border, radius: 6,
                shadows: kRaisedShadows, // web shadow-raised
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Kalp — kartın kendisini AÇMADAN yalnızca beğeniyi
                      // değiştirir (web'in `stopPropagation`'ı).
                      GestureDetector(
                        onTap: onToggleLike,
                        behavior: HitTestBehavior.opaque,
                        child: KeyedSubtree(
                          key: iconKeys.like,
                          child: Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            entry.likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 13,
                            // Web: `entry.liked_by_me ? 'text-red' :
                            // 'text-muted'` — beğenilen kalp KIRMIZI.
                            // Port ikonun DOLU/BOŞ hâlini taşımış ama
                            // rengi koşulsuz `_muted` bırakmıştı, yani
                            // beğeni yapınca kalp doluyor ama gri kalıyordu
                            // (9 Ağustos 2026, cihaz testinde bulundu).
                            color: entry.likedByMe ? _red : _muted,
                          ),
                        ),
                        ),
                      ),
                      if (entry.likeCount > 0)
                        GestureDetector(
                          // Key: rakam PlayerBadge'in koltuk numarasıyla
                          // aynı metni üretebiliyor, testler ayırt edebilsin.
                          key: ValueKey('like-count-${entry.id}'),
                          onTap: onShowLikers,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text('${entry.likeCount}',
                                style: const TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 9,
                                    decoration: TextDecoration.underline,
                                    color: _muted)),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(_formatDate(entry.createdAt),
                          style: const TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 9,
                              letterSpacing: 0.5,
                              color: _muted)),
                      // Web: "Yapay Zeka" rozeti yalnızca gerçekten bir YZ
                      // koltuğu KAYITLIYSA çıkar — eski (players'sız) yerel
                      // kayıtlar rozetsiz kalır. İlk port bunu "Canlı değilse
                      // Yapay Zeka" diye basitleştirmişti, düzeltildi.
                      if (isOnline) ...[
                        const SizedBox(width: 6),
                        const _Badge(text: 'Canlı', color: _green),
                      ] else if (hasSnapshot &&
                          players.any((p) => p.isAi)) ...[
                        const SizedBox(width: 6),
                        const _Badge(text: 'Yapay Zeka', color: _accent),
                      ],
                      // Zorluk rozeti (ROADMAP #23 Faz 4) — "Yapay Zeka"nın
                      // hemen sağında, YZ oyununda her seviyede (Normal
                      // turuncu); Canlı'da YOK. `ai_level` iki kaynaktan da
                      // geliyor (`_listCols` + `list_liked_games`), eski
                      // satırlar null = Normal.
                      if (!isOnline) ...[
                        const SizedBox(width: 6),
                        AiLevelBadge(
                            level: aiLevelForBadge(entry.aiLevel,
                                isAiGame: true)),
                      ],
                      if (entry.messageCount > 0) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          key: ValueKey('chat-count-${entry.id}'),
                          onTap: onShowChat,
                          behavior: HitTestBehavior.opaque,
                          child: KeyedSubtree(
                            key: iconKeys.chat,
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline,
                                  size: 11, color: _muted),
                              const SizedBox(width: 2),
                              Text('${entry.messageCount}',
                                  style: const TextStyle(
                                      fontFamily: 'SpaceMono',
                                      fontSize: 9,
                                      color: _muted)),
                            ],
                          ),
                          ),
                        ),
                      ],
                      // Hamle dökümü — YALNIZCA dökümü olan kartta (12
                      // Ağustos 2026, kullanıcı "YZ oyunlarda içi boş
                      // geliyor" dedi). İlk sürüm KOŞULSUZ çiziyordu ("her
                      // bitmiş oyunun hamlesi var") — bu, `games.moves`
                      // eklenmeden ÖNCE biten oyunları saymıyordu: yerel
                      // oyunların dökümü geri doldurulamıyor, Canlı oyunlar
                      // migration'da dolduruldu. Koşul tür bazlı DEĞİL veri
                      // bazlı — bundan sonra biten YZ oyunlarında ikon
                      // normal çıkacak. Döküm hâlâ lazy.
                      if (entry.hasMoves) ...[
                        // 6 DEĞİL 2: aradaki 4px'i aşağıdaki dokunma dolgusu
                        // tamamlıyor (2 + 4 = 6), yani ikonun GÖRSEL konumu ve
                        // sohbet rozetiyle arasındaki boşluk değişmiyor.
                        const SizedBox(width: 2),
                        GestureDetector(
                          key: ValueKey('moves-${entry.id}'),
                          onTap: onShowMoves,
                          behavior: HitTestBehavior.opaque,
                          child: Semantics(
                            label: 'Hamle geçmişini göster',
                            button: true,
                            // Dokunma dolgusu (12 Ağustos 2026, cihaz testinde
                            // bulundu — kullanıcı: "en az 4-5 kere dokunmam
                            // gerekti, tam basamazsan oyun detayları açılıp
                            // kapanıyor"). Parça 65 bu hedefi bilinçli olarak
                            // 44px'e çıkarmamıştı ve o gerekçe hâlâ geçerli
                            // (44px'lik alan ~13px'lik satırda kardeş
                            // kontrolleri ve kartın kendi dokunuşunu yutar) —
                            // ama ÖLÇÜM iki kontrolün eşit OLMADIĞINI gösterdi:
                            // sohbet 18.8x13.0 = 244px², hamle 11x11 = 121px²,
                            // yani tam yarısı. Fark yapısal: sohbetin kutusuna
                            // sayı ETİKETİ de dahil, burada etiket yok.
                            // Kullanıcı kararı: "mesaj ikonu iyi, onunla aynı
                            // şekilde olabilir" — dolgu tam olarak o kutuya
                            // eşitliyor (19x13). Dikey 1'de kalıyor çünkü
                            // satırın kendi yüksekliği zaten 13 (kalp + sohbet
                            // ikisi de 13); daha fazlası satırı ve dolayısıyla
                            // HER kartı büyütürdü. Eşitlik `game_likes_test`te
                            // ölçüyle korunuyor — ikisi tek bir çift.
                            child: KeyedSubtree(
                              key: iconKeys.moves,
                              child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              child: movesLoading
                                  // Sohbet rozetiyle aynı 11px kutuda kalır ki
                                  // yükleme sırasında satır kaymasın.
                                  ? const SizedBox(
                                      width: 11,
                                      height: 11,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5, color: _muted),
                                    )
                                  : const DocumentIcon(size: 11, color: _muted),
                            ),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      const ScaledCell(
                          width: 40,
                          child: Text('PUAN',
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                  color: _muted))),
                      const SizedBox(width: 8),
                      // "SL" (Sanal Lig) yerine "k-lig" — marka adı düz metin
                      // ve küçük harf (KLigMark wordmark'ı 9px'lik bir tablo
                      // başlığı için okunmaz kalırdı, bkz. CLAUDE.md k-lig
                      // notu: kısa etiketlerde wordmark, ama bu punto onun
                      // altında). Sütun 24→32: 5 karakter 9px SpaceMono +
                      // 0.5 letterSpacing ile 24'e sığmıyordu.
                      const ScaledCell(
                          width: 32,
                          child: Text('k-lig',
                              maxLines: 1,
                              softWrap: false,
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
                          surrendered: players[i].surrendered,
                          aiLevel: entry.aiLevel),
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
              const KLoadingNote(vertical: 12)
            else if (snapshotFetched && snapshot != null)
              GestureDetector(
                onTap: onTapBoard,
                behavior: HitTestBehavior.opaque,
                child: RepaintBoundary(
                  key: captureKey,
                  // Yakalanan görselin zemini: PNG'de saydam kalmasın
                  // (parça 1'in dersi — gölge/zemin yakalama artefaktı).
                  child: ColoredBox(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Paylaşılan görsel yalnızca tahtayı değil kimin kaç
                        // puan aldığını da taşısın diye (web'in kararı).
                        ScoreBoxRow(
                          players: players,
                          seatIndexOf: (p, i) =>
                              _seatIndexFor(p, i, hasSnapshot),
                          meIndex: meIndex,
                          currentName: currentName,
                        ),
                        const SizedBox(height: 6),
                        // Gerçek BoardWidget'ın salt-okunur hâli —
                        // compact/hideFooter zaten vardı (parça 1/8), canlı
                        // oyun tahtasına DOKUNULMADI.
                        BoardWidget(
                          state: buildSnapshotGameState(
                              snapshot!, entry.playerCount, players),
                          compact: true,
                          hideFooter: true,
                        ),
                      ],
                    ),
                  ),
                ),
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
          // 18 px: "1." 12px SpaceMono'da 14 px'e sığmıyordu (ekran
          // görüntüsü yakalamıştı: rakam ve nokta alt alta düşüyordu).
          // `softWrap: false` sarmayı kapatıyordu ama sığmayanı KIRPIYORDU;
          // ScaledCell kutuyu ölçekle büyütüp gerekirse küçültüyor.
          ScaledCell(
            width: 18,
            child: Text('$rank.',
                maxLines: 1,
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
          ScaledCell(
            width: 40,
            child: Text('${player.score}',
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMe ? _gold : _muted)),
          ),
          const SizedBox(width: 8),
          ScaledCell(
            // Başlıkla (k-lig) aynı genişlik — ikisi de sağa hizalı, sağ
            // kenarların çakışması için eşit olmak zorunda.
            width: 32,
            child: Text(
              formatLeaguePoints(points),
              maxLines: 1,
              softWrap: false,
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
