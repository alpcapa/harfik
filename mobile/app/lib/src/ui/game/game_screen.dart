// Oynanabilir oyun ekranı — App.tsx'in oyun görünümünün çekirdeği: skor
// satırı + tahta (canlı geçerlilik çerçevesiyle) + mesaj + raf/OYNA + web
// buton düzeni (Pas Geç/Değiştir/Karıştır/Geri Al/Torba; swap modunda
// Değiştir (N)/Vazgeç) + GameOver modalı + sürükle-bırak (raftan tahtaya,
// tahtada taşıma, rafa geri — web beginDrag/endDrag portu). Kalıcılık bu
// ekranın DIŞINDA: SetupScreen oyunu GameSession'la sarar (autosave/çıkış
// kuralları, local_game_repo.dart) — ekran yalnızca oynatır. Parça parça
// Tahtadaki onaylanmış bir taşa dokunmak, o hücreden geçen kelimelerin
// anlamını gösterir (meanings deposu verilmişse).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../data/auth_service.dart';
import '../../data/chat_api.dart';
import '../../data/feedback_api.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../../data/meaning_store.dart';
import '../feedback/feedback_modal.dart';
import '../../game/game_controller.dart';
import '../../game/move_status.dart';
import 'board_widget.dart';
import 'dialog_shell.dart';
import 'game_header.dart';
import 'game_over_modal.dart';
import 'help_modal.dart';
import 'meaning_modal.dart';
import 'move_history_modal.dart';
import 'neo_button.dart';
import 'player_colors.dart';
import 'rack_widget.dart';
import 'remaining_tiles_modal.dart';
import 'tile_widget.dart';
import 'wild_letter_sheet.dart';
import '../rank/league_rewards_host.dart';
import '../../data/league_rewards_api.dart';
import '../tokens.dart';
import 'invasion_confirm.dart';
import '../../util/online_status.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  final WordSource words;

  /// Tahtadaki bir taşa dokunulunca açılan anlam modalının veri kaynağı.
  /// Verilmezse (testlerin bir kısmı, ileride önizlemeler) dokunuş sessizce
  /// yok sayılır — web'de de anlam gösterimi oyunun çalışmasına bağlı değil.
  final MeaningStore? meanings;

  /// Hesap durumu — GameHeader'daki GİRİŞ/avatar kontrolü için; verilmezse
  /// (testler) hesap kontrolü çizilmez (web offline davranışı).
  final AuthService? auth;

  /// Hesap menüsündeki k-lig/Skor Kartı için (GameHeader'a iletilir).
  final StatsRepo? stats;

  /// Skor kartındaki geçmiş linki için (GameHeader'a iletilir).
  final Future<GamesRepo>? games;

  /// GameOver'daki "Görüş Bildir" linki + hesap zincirindeki Terms/Privacy
  /// içi form linki için; verilmezse (testler) link hiç çizilmez.
  final FeedbackRepo? feedback;

  /// Hesap menüsündeki "Arkadaşlar" satırı için (GameHeader'a iletilir).
  final FriendsRepo? friends;
  final ChatRepo? chat;

  /// k-lig kutlama banner'ı — oyun SÜRERKEN bastırılır, bittiğinde
  /// bekleyen kutlama burada gösterilir (web'in oyun dalındaki
  /// `<LeagueRewardsHost suppress=... />` mount'u). null ise host no-op.
  final LeagueRewardsRepo? leagueRewards;

  /// Bağlantı durumu — Board alt şeridindeki "Çevrimdışı" uyarısı için
  /// (web'de `Board.tsx` bunu `useOnlineStatus()` ile kendi içinde okuyor).
  final OnlineStatus? onlineStatus;

  const GameScreen({
    super.key,
    required this.controller,
    required this.words,
    this.meanings,
    this.auth,
    this.stats,
    this.games,
    this.feedback,
    this.friends,
    this.chat,
    this.leagueRewards,
    this.onlineStatus,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Sürükleme kaynağı — raftaki bir taş ya da bu tur tahtaya konmuş bir taş
/// (web DragSource union'ı).
sealed class _DragSource {
  Tile get tile;
}

class _RackSource implements _DragSource {
  final int index;
  @override
  final Tile tile;
  const _RackSource(this.index, this.tile);
}

class _PlacedSource implements _DragSource {
  final int r, c;
  @override
  final Tile tile;
  const _PlacedSource(this.r, this.c, this.tile);
}

class _DragRef {
  final _DragSource source;
  final Offset start;

  /// Sürükleme gerçekten serbest mi (canAct && !swapMode) — değilse hareket
  /// yok sayılır, hareketsiz bırakış yine dokunuş sayılır (web beginDrag'in
  /// erken dönüşünde click'in normal çalışması gibi).
  final bool enabled;
  bool moved = false;
  _DragRef({required this.source, required this.start, required this.enabled});
}

class _Ghost {
  final Offset global; // kaldırılmış (lifted) nokta, global koordinat
  final _DragSource source;
  final String? overKey;
  final bool overValid;
  const _Ghost({
    required this.global,
    required this.source,
    required this.overKey,
    required this.overValid,
  });
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameController get controller => widget.controller;
  GameState get state => controller.state;

  /// GameOver modalı bu isGameOver geçişi için zaten gösterildi mi
  /// (web gameOverDismissed'in eşleniği — kapatınca tahta görünür kalır).
  bool _gameOverShown = false;

  // ── Sürükle-bırak (web App.tsx beginDrag/moveDrag/endDrag portu) ──────
  static const double _dragLift = 30; // web DRAG_LIFT
  static const double _dragThreshold = 6; // web DRAG_THRESHOLD
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _rackKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  // `_dragRef`in kendisi web dragRef gibi salt veri taşır, ama artık
  // SingleChildScrollView'ın `physics`i buna bağlı olduğundan (bkz. build())
  // her değişiklik setState içinde yapılmak ZORUNDA.
  _DragRef? _dragRef;

  /// Sürüklenen kaynak — YALNIZCA sürükleme GERÇEKTEN başladığında (eşik
  /// aşıldığında, `_moveTileDrag`'in `d.moved` geçişinde — sürükleme başına
  /// TEK sefer) ve bittiğinde/iptal olduğunda değişir; `BoardWidget`'ın
  /// `dragHiddenKey`'i ve `RackWidget`'ın `dragHiddenIndex`'i buradan
  /// türetiliyor. Kaynağı POINTER DOWN anında (eşik aşılmadan) gizlemek
  /// web/eski davranıştan sapardı — sıradan bir dokunuşta (sürüklenmeden
  /// bırakılan) taş bir an için görünmezdi, üstelik yerine henüz hiçbir
  /// hayalet taş da çizilmemiş olurdu (ghost yalnızca eşik aşılınca
  /// belirir). Eşik-aşımı anına bağlamak hem bu görsel deliği önlüyor hem
  /// de performans hedefini aynen koruyor — sürükleme başına yalnızca BİR
  /// ekstra `setState`, per-move DEĞİL.
  _DragSource? _hiddenSource;

  /// Hover hedefi (`_Ghost.overKey`/`overValid`) HER pointer hareketinde
  /// değişir — bunu `setState`'e (dolayısıyla `GameScreen`'in TÜM build'ine,
  /// yani `BoardWidget`'ın 169 hücre + territory hesabının sıfırdan
  /// yeniden çizilmesine) bağlamak yerine bağımsız bir `ValueNotifier`'a
  /// yazıyoruz — yalnızca aşağıdaki küçük `ValueListenableBuilder` overlay'i
  /// bunu dinliyor (8 Ağustos 2026 performans düzeltmesi, kullanıcı iPad
  /// Safari'de sürüklerken titreme/takılma bildirdi; ölçüm: 30 pointer-move
  /// → 30/30 BoardWidget rebuild, adım başı ~38-40ms — bkz. mobile/CLAUDE.md
  /// Parça 23).
  final ValueNotifier<_Ghost?> _dragNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Web'in `clearStuckDrag`i (App.tsx — `visibilitychange`/`blur`
  /// dinleyicileri) porta hiç girmemişti: uygulama sürükleme ORTASINDA arka
  /// plana alınırsa `PointerUpEvent` bir daha hiç gelmeyebiliyor ve
  /// `_dragRef` asılı kalıyor — hayalet taş havada duruyor, kaynak taş gizli
  /// kalıyor ve `NeverScrollableScrollPhysics` sayfayı kilitliyor, yani alt
  /// butonlara ulaşılamıyor. Web'de bu durumdan uygulamaya geri dönmek
  /// yetiyordu; portta kurtuluş yolu YOKTU (uygulamayı kapatıp açmak
  /// gerekiyordu — bkz. mobile/CLAUDE.md, Parça 58).
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed && _dragRef != null) {
      _cancelTileDrag();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dragNotifier.dispose();
    super.dispose();
  }

  PlayerColor _colorOf(int i) =>
      playerColors[state.players[i].colorIndex % playerColors.length];

  bool get _canAct =>
      !state.isGameOver &&
      state.players.isNotEmpty &&
      !state.players[state.current].isAI;

  /// Web rackPlayer kuralı: sıra YZ'deyse raf yine İNSANIN rafını gösterir.
  int get _rackIndex {
    if (state.players.isEmpty) return 0;
    if (!state.players[state.current].isAI) return state.current;
    final human = state.players.indexWhere((p) => !p.isAI);
    return human >= 0 ? human : state.current;
  }

  /// Yerleştirilmiş taşa DOKUNUŞ (hareketsiz bırakış): joker olmayan taş
  /// geri alınır; joker seçiciyi 'editing' modunda yeniden açar (web).
  Future<void> _tapPlacedTile(int r, int c, Tile placedTile) async {
    if (!_canAct) return;
    if (placedTile.wild) {
      final choice = await showWildLetterSheet(context, editing: true);
      if (choice == null) return;
      if (choice.recallRequested) {
        controller.dispatch(RecallCellAction(r: r, c: c));
      } else if (choice.letter != null) {
        controller.dispatch(
            SetWildLetterAction(r: r, c: c, wildLetter: choice.letter!));
      }
    } else {
      controller.dispatch(RecallCellAction(r: r, c: c));
    }
  }

  Future<void> _handleCellTap(int r, int c) async {
    final k = cellKey(r, c);
    if (state.board[r][c] != null) {
      // Tahtada duran (onaylanmış) bir taş: o hücreden geçen yatay ve dikey
      // kelimelerin anlamı gösterilir (web handleCellClick'in ilk dalı).
      final store = widget.meanings;
      if (store == null) return;
      await showMeaningModal(context, store.lookup, isUnavailable: () => store.unavailable, [
        fullWordAt(state.board, const {}, r, c, 0, 1),
        fullWordAt(state.board, const {}, r, c, 1, 0),
      ]);
      return;
    }
    final placedTile = state.placed[k];
    if (placedTile != null) {
      // Normalde erişilmez (yerleştirilmiş hücreler Listener'a gider) —
      // güvenlik ağı olarak aynı dokunuş davranışı.
      await _tapPlacedTile(r, c, placedTile);
      return;
    }
    if (!_canAct || state.swapMode) return;

    final selIdx = state.selectedTile;
    final sel = (selIdx != null &&
            selIdx >= 0 &&
            selIdx < state.players[state.current].rack.length)
        ? state.players[state.current].rack[selIdx]
        : null;
    if (sel != null && sel.letter == '?') {
      // Joker: harf seçilene kadar taş konmaz (web pendingWild akışı).
      final choice = await showWildLetterSheet(context);
      if (choice?.letter == null) return;
      controller
          .dispatch(PlaceTileAction(r: r, c: c, wildLetter: choice!.letter));
      return;
    }
    controller.dispatch(PlaceTileAction(r: r, c: c));
  }

  Future<void> _handlePlay(MoveStatus? moveStatus) async {
    // Bölge vergisi onayı — web invasionConfirm akışı: hamle GEÇERLİYSE ve
    // vergi payı varsa Oyna'dan önce sorulur.
    final score = moveStatus?.score ?? 0;
    if (moveStatus != null && moveStatus.valid) {
      final placedCoords = [for (final k in state.placed.keys) parseKey(k)];
      final split = computeInvasionSplit(
          placedCoords, state.current, state.players, score, state.board);
      if (split.shares.isNotEmpty) {
        final ok = await showInvasionConfirm(context,
            score: score, shares: split.shares, players: state.players);
        if (!ok) return;
      }
    }
    controller.dispatch(const PlayAction());
  }

  /// Oyun bitince OYNA'nın yerini alan "TEKRAR OYNA" — Canlı ekranındaki
  /// aynı butonun yerel karşılığı (bkz. mobile/CLAUDE.md Parça 60). Orada
  /// davet gönderildiğinden onay şart; burada da AYNI konumdaki buton oyun
  /// bitince parmağın altında anlam değiştirdiğinden kazara dokunuşa karşı
  /// aynı koruma uygulanıyor. Kadro yeniden hesaplanmıyor: biten oyunun
  /// oyuncu adları/YZ bayrakları Setup'ın `_startNewGame`'inin ürettiğinin
  /// AYNISI. Kayıt oturumu (`CloudGameSession`) oyun bitince satırı silip
  /// `_saveId`'yi null'ladığından yeni oyun kendiliğinden yeni bir id alır —
  /// burada ek bir şey yapmak gerekmiyor.
  Future<void> _handleRematch() async {
    // Kabul butonu SOLDA (Parça 25 kuralı) — showKConfirm bunu garanti eder.
    final ok = await showKConfirm(
      context,
      title: 'Tekrar Oyna',
      message: '${state.players.length} kişilik, Yapay Zeka\'ya karşı yeni bir '
          'oyun başlatılacak. Emin misin?',
      confirmLabel: 'TEKRAR OYNA',
    );
    if (!ok || !mounted) return;
    controller.dispatch(StartAction([
      for (final p in state.players) PlayerSetup(name: p.name, isAI: p.isAI),
    ]));
    setState(() => _gameOverShown = false);
  }

  Future<void> _handlePass() async {
    final ok = await showKConfirm(
      context,
      title: 'Pas Geçiyorsun!',
      message: 'Pas geçmek istediğinden emin misin? Sıran diğer oyuncuya geçer.',
      confirmLabel: 'PAS GEÇ',
    );
    if (ok) controller.dispatch(const PassAction());
  }

  // ── Sürükleme geometrisi/akışı ────────────────────────────────────────

  RenderBox? _boxOf(GlobalKey key) =>
      key.currentContext?.findRenderObject() as RenderBox?;

  /// Kaldırılmış nokta: parmağın DRAG_LIFT üzeri, ızgaranın üst kenarının
  /// altına kırpılır (web liftedPoint — en üst satır ekrana yakınken köşe
  /// hücresine bırakılamama hatasının önlemi; görsel taş ve bırakma hedefi
  /// hep aynı noktayı kullanır).
  double _liftedY(double y) {
    final grid = _boxOf(_gridKey);
    final lifted = y - _dragLift;
    if (grid == null) return lifted;
    final top = grid.localToGlobal(Offset.zero).dy;
    return lifted < top + 1 ? top + 1 : lifted;
  }

  /// Global noktayı hücreye çevirir — web elementFromPoint'in geometri
  /// tabanlı eşleniği (ızgara: 13 hücre + 12×3px boşluk; boşluğa düşen
  /// nokta soldaki/üstteki hücreye sayılır).
  (int, int)? _cellAtGlobal(Offset global) {
    final grid = _boxOf(_gridKey);
    if (grid == null) return null;
    final local = grid.globalToLocal(global);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= grid.size.width ||
        local.dy >= grid.size.height) {
      return null;
    }
    const gap = 3.0;
    final strideX = (grid.size.width + gap) / boardSize;
    final strideY = (grid.size.height + gap) / boardSize;
    final c = (local.dx / strideX).floor().clamp(0, boardSize - 1);
    final r = (local.dy / strideY).floor().clamp(0, boardSize - 1);
    return (r, c);
  }

  bool _rackContains(Offset global) {
    final box = _boxOf(_rackKey);
    if (box == null) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(global);
  }

  bool _isCellFreeFor(_DragSource source, int r, int c) {
    if (source is _PlacedSource && source.r == r && source.c == c) {
      return false;
    }
    return state.board[r][c] == null && state.placed[cellKey(r, c)] == null;
  }

  void _beginTileDrag(_DragSource source, PointerDownEvent e) {
    // setState şart: aşağıdaki SingleChildScrollView'ın `physics`i buna bağlı
    // (bkz. build() — sürükleme sırasında sayfa kaymasın diye). `_hiddenSource`
    // BURADA sıfırlanmıyor/doldurulmuyor — yalnızca aşağıda `_moveTileDrag`in
    // eşik-aşımı anında (web'in "gerçek hareket başlayınca kaynağı gizle"
    // davranışıyla aynı an) doluyor; sıradan bir dokunuşta hiç dolmadan kalır.
    setState(() {
      _dragRef = _DragRef(
        source: source,
        start: e.position,
        enabled: _canAct && !state.swapMode,
      );
    });
  }

  void _moveTileDrag(PointerMoveEvent e) {
    final d = _dragRef;
    if (d == null) return;
    if (!d.moved) {
      if ((e.position - d.start).distance < _dragThreshold) return;
      d.moved = true;
      // Eşik İLK kez aşıldı — kaynak artık "sürükleniyor" sayılır ve
      // gizlenir (web'in aynı anki davranışı). Sürükleme başına yalnızca BİR
      // kez tetiklenen nadir bir geçiş — per-move DEĞİL, setState burada
      // ucuz/güvenli.
      setState(() => _hiddenSource = d.source);
    }
    if (!d.enabled) return;
    final lifted = Offset(e.position.dx, _liftedY(e.position.dy));
    final cell = _cellAtGlobal(lifted);
    String? overKey;
    var overValid = false;
    if (cell != null) {
      overKey = cellKey(cell.$1, cell.$2);
      overValid = _isCellFreeFor(d.source, cell.$1, cell.$2);
    }
    // BİLEREK setState DEĞİL — bu, GameScreen'in tüm build'ini (dolayısıyla
    // BoardWidget'ın 169 hücre + territory hesabını) HER pointer hareketinde
    // yeniden tetikleyen asıl kaynaktı (bkz. yukarıdaki _dragNotifier notu).
    // Yalnızca aşağıdaki ValueListenableBuilder overlay'i bunu dinliyor.
    _dragNotifier.value = _Ghost(
      global: lifted,
      source: d.source,
      overKey: overKey,
      overValid: overValid,
    );
  }

  Future<void> _endTileDrag(PointerUpEvent e) async {
    final d = _dragRef;
    setState(() {
      _dragRef = null;
      _hiddenSource = null;
    });
    _dragNotifier.value = null;
    if (d == null) return;

    if (!d.moved) {
      // Hareket yok: sıradan dokunuş — eski davranış (web endDrag !moved).
      final s = d.source;
      if (s is _RackSource) {
        if (!_canAct) return;
        controller.dispatch(state.swapMode
            ? ToggleSwapTileAction(s.index)
            : SelectTileAction(s.index));
      } else if (s is _PlacedSource) {
        await _tapPlacedTile(s.r, s.c, s.tile);
      }
      return;
    }
    if (!d.enabled) return;

    final lifted = Offset(e.position.dx, _liftedY(e.position.dy));
    final cell = _cellAtGlobal(lifted);
    final s = d.source;
    if (cell != null) {
      final (r, c) = cell;
      if (!_isCellFreeFor(s, r, c)) return;
      if (s is _RackSource) {
        if (s.tile.letter == '?') {
          // Joker sürüklemeyle bırakıldı: önce harf seçilir (web
          // pendingWild {r,c,rackIndex} akışı).
          final choice = await showWildLetterSheet(context);
          if (choice?.letter == null) return;
          controller.dispatch(PlaceTileAction(
              r: r, c: c, wildLetter: choice!.letter, rackIndex: s.index));
        } else {
          controller.dispatch(PlaceTileAction(r: r, c: c, rackIndex: s.index));
        }
      } else if (s is _PlacedSource) {
        controller.dispatch(
            MovePlacedTileAction(fromR: s.r, fromC: s.c, toR: r, toC: c));
      }
    } else if (s is _PlacedSource && _rackContains(lifted)) {
      controller.dispatch(RecallCellAction(r: s.r, c: s.c));
    }
  }

  void _cancelTileDrag() {
    setState(() {
      _dragRef = null;
      _hiddenSource = null;
    });
    _dragNotifier.value = null;
  }

  /// Parmağın üzerinde süzülen taş — web'in fixed ghost overlay'i (46px,
  /// merkezlenmiş, 1.1 ölçek, gölgeli).
  Widget _buildGhost(_Ghost g) {
    final box = _boxOf(_stackKey);
    final local = box == null ? g.global : box.globalToLocal(g.global);
    final isRack = g.source is _RackSource;
    return Positioned(
      left: local.dx - 23,
      top: local.dy - 23,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1.1,
          // Ek gölge YOK (kullanıcı web karşılaştırması): sürüklenen taş
          // yalnızca kendi taş görünümünü taşır, hedef kesikli çerçeveyle
          // gösterilir.
          child: SizedBox(
            width: 46,
            height: 46,
            child: TileWidget(
              tile: g.source.tile,
              variant: isRack ? TileVariant.rack : TileVariant.placed,
              color: isRack ? null : _colorOf(state.current),
            ),
          ),
        ),
      ),
    );
  }

  /// Bırakma hedefinin kesikli yeşil/kırmızı çerçevesi — eskiden
  /// `BoardWidget`in `dragOverKey`/`dragOverValid` parametreleriydi (o
  /// widget'ı per-move yeniden inşa ettiriyordu); artık ekran katmanının
  /// KENDİ küçük overlay'i olarak, hücrenin ızgaradaki GERÇEK konumu elle
  /// hesaplanıp (`_gridKey`'in boyutundan, `_cellAtGlobal` ile AYNI
  /// stride formülüyle) `_stackKey`'e göre konumlandırılıyor —
  /// `_buildGhost`'un `globalToLocal` deseniyle tutarlı.
  Widget _hoverHighlight(_Ghost g) {
    // BİLİNÇLİ: erken dönüşler DE `Positioned` olmak zorunda. Bu widget
    // `_buildGhost`'un hayalet taşıyla birlikte üst-seviye Stack'in (o Stack
    // ayrıca `_stackKey`'in de İÇİNDE, dış Stack'in non-positioned tek
    // çocuğu olarak durur) İKİ çocuğundan biri — Stack'in KENDİSİ hiç
    // non-positioned çocuk yoksa `constraints.biggest`e (tam ekran) sığar,
    // ama TEK bir non-positioned çocuk (ör. çıplak `SizedBox.shrink()`)
    // varsa Stack o çocuğun boyutuna (0×0) KÜÇÜLÜR ve varsayılan
    // `clipBehavior: Clip.hardEdge` yüzünden diğer Positioned çocuğu
    // (hayalet taş) TAMAMEN KIRPAR. Önceden buradaki iki erken dönüş çıplak
    // `SizedBox.shrink()` idi — pointer tahtanın (`key==null`/`grid==null`)
    // dışına, ör. rafa doğru sürüklenirken çıkınca bu Stack anlık olarak
    // 0×0'a küçülüp hayalet taşı görünmez kılıyordu (kullanıcı "tahtadan
    // rafa sürüklerken board sınırını geçerken kayboluyor" diye bildirdi,
    // 8 Ağustos 2026 — ölçülerek doğrulandı: `flutter test` widget
    // geometrisi hep doğruydu, yalnızca PAINT kırpılıyordu, bu yüzden
    // native Skia'da widget-ağacı/rect kontrolleri hatayı hiç yakalamadı;
    // gerçek CanvasKit render'ında ekran görüntüsüyle doğrulandı). Düzeltme
    // sihirli bir sayı içermiyor — boş içerik de `Positioned` içine
    // sarılınca Stack'in "yalnızca Positioned çocuklar var" değişmezi
    // korunuyor, tam ekran boyutuna geri dönüyor.
    final key = g.overKey;
    if (key == null) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final grid = _boxOf(_gridKey);
    final stack = _boxOf(_stackKey);
    if (grid == null || stack == null) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final (r, c) = parseKey(key);
    const gap = 3.0;
    final strideX = (grid.size.width + gap) / boardSize;
    final strideY = (grid.size.height + gap) / boardSize;
    final gridOrigin = stack.globalToLocal(grid.localToGlobal(Offset.zero));
    return Positioned(
      left: gridOrigin.dx + c * strideX,
      top: gridOrigin.dy + r * strideY,
      width: strideX - gap,
      height: strideY - gap,
      child: IgnorePointer(
        child: CustomPaint(
          painter: DashedBorderPainter(
            g.overValid ? kMoveValid : kMoveInvalid,
          ),
        ),
      ),
    );
  }

  // Web `App.tsx`'teki MESSAGE_COLORS haritası — dördü de TOKEN
  // (text-red/green/gold/muted). Tahtanın hamle renkleriyle (kMoveValid/
  // kMoveInvalid) karıştırma: onlar yalnızca ızgara üstündeki geçerlilik
  // göstergesi, bu satır sıradan bir metin.
  Color _messageColor(MessageKind kind) => switch (kind) {
        MessageKind.err => kRed,
        MessageKind.ok => kGreen,
        MessageKind.warn => kGold,
        MessageKind.none => kMuted,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Oyun bittiği an GameOver modalı bir kez gösterilir; KAPAT ile
        // kapatınca tahta görünür kalır (web gameOverDismissed davranışı).
        if (state.isGameOver && !_gameOverShown) {
          _gameOverShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final auth = widget.auth;
            // Web App.tsx (~1512-1517): GameOver'ın İKİ yolu da AYNI formu
            // açıyor — içindeki "GÖRÜŞ BİLDİR" linki (`onOpenFeedback`) VE
            // modalı KAPATMAK (`onClose`). Web'de kapatmanın her yolu
            // (✕ / dışarı tıklama / Escape) tek `onClose`a gidiyor
            // (Modal.tsx backdrop'ta `onClick={onClose}`); Flutter'da
            // `showDialog`ın Future'ı da ✕/bariyer/geri tuşunun HEPSİNDE
            // tamamlandığı için await etmek birebir aynı kapsamı veriyor.
            void openFeedback() => showFeedbackModal(context,
                auth: auth!,
                feedback: widget.feedback,
                source: FeedbackSource.gameEnd);
            await showGameOverModal(context, state,
                // Yerel oyunda hamle geçmişi reducer'ın kendi state'inde —
                // tahta altındaki "Hamleler" linkiyle AYNI kaynak.
                onOpenHistory: () => showMoveHistoryModal(context, state),
                onFeedback: auth == null ? null : openFeedback);
            if (!mounted || auth == null) return;
            openFeedback();
          });
        } else if (!state.isGameOver && _gameOverShown) {
          _gameOverShown = false;
        }

        final moveStatus = computeMoveStatus(state, widget.words);
        // Web liveMessage kuralı: geçersiz hamlenin sebebi anlık gösterilir;
        // GEÇERLİ taslakta metin state.message'tan okunmaz, TÜRETİLİR —
        // state.message "son yazan kazanır" bir alan, taş seçmeden boş
        // hücreye dokunmak "Önce bir harf seç."i üstüne yazıp yeşil
        // gösterebiliyordu (web'de kullanıcı buldu, 6 Ağustos 2026 — üç
        // istemci de aynı gün aynı kurala çekildi).
        final liveMessage = (moveStatus != null &&
                !moveStatus.valid &&
                moveStatus.reason != null)
            ? moveStatus.reason!
            : (moveStatus?.valid ?? false)
                ? 'Oyna tuşuyla kelimeyi onayla.'
                : state.message;
        final liveKind = (moveStatus != null &&
                !moveStatus.valid &&
                moveStatus.reason != null)
            ? MessageKind.err
            : (moveStatus?.valid ?? false)
                ? MessageKind.ok
                : state.messageType;

        final me = state.players.isEmpty ? null : state.players[state.current];

        return LeagueRewardsHost(
          rewards: widget.leagueRewards,
          auth: widget.auth,
          stats: widget.stats,
          // Oyun ortasında banner odak çalmaz; bayrak düşünce (oyun bitince)
          // host kendiliğinden kontrol eder — web ile birebir.
          suppress: !state.isGameOver,
          child: Scaffold(
          backgroundColor: Colors.white, // web sayfa zemini (colors.bg)
          body: SafeArea(
            // Stack: hayalet taş (ghost) içerik akışının üzerinde süzülür.
            child: Stack(
              key: _stackKey,
              children: [
                // Web'in tamamı: header/board/mesaj/raf/butonlar hepsi ayrı
                // ayrı `max-w-[680px] mx-auto` taşıyor (GameHeader.tsx,
                // Board.tsx, App.tsx'teki alt container) — geniş/yatay
                // ekranlarda içerik ortalanmış dar bir "kart" olarak kalır,
                // dışarıda kalan boşluk tahtanın/rafın nömorfik gölgesinin
                // (blur:60'a kadar) sönümlenmesi için gereken alanı sağlar.
                // Bu sınır eksikken tahta geniş ekranda kenardan kenara
                // gerilip gölge ekran kenarında kırpılıyordu (kullanıcı
                // iPad yatay ekran görüntüsüyle bildirdi, 8 Ağustos 2026).
                Column(
                  children: [
                    // Web'de `min-h-[100dvh] flex flex-col` sayfanın TAMAMI akıyor
                    // ve 680'lik sınır her bölümün KENDİ üzerinde (GameHeader.tsx,
                    // Board.tsx, App.tsx'in alt container'ı) — yani hiçbir yerde
                    // 680 genişliğinde bir KIRPMA kabı yok. Port bir dönem 680'i
                    // her şeyi saran tek bir kaba koymuştu; kaydırma görünümü o
                    // kap kadar (680) dar olduğundan tahtanın ~30px taşan gölgesi
                    // kırpılıyor ve gölge bıçak gibi kesiliyordu (kullanıcı iPad'de
                    // web ile yan yana koyup bildirdi, 9 Ağustos 2026 — Parça 40).
                    // Artık web'in deseni birebir: kaydırma görünümü TAM GENİŞLİK,
                    // 680 sınırı header'ın ve içerik sütununun kendi üzerinde.
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: GameHeader(
                          state: state,
                          auth: widget.auth,
                          stats: widget.stats,
                          games: widget.games,
                          feedback: widget.feedback,
                          friends: widget.friends,
                          chat: widget.chat,
                          onLogoTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        // Aktif bir taş sürüklemesi varken kaydırma kilitleniyor
                        // — sürükleme sistemi ham `Listener` kullandığından
                        // (web setPointerCapture eşdeğeri, jest arenasına hiç
                        // katılmıyor) bu Scrollable'ın kendi dikey sürükleme
                        // algılayıcısı aynı parmak hareketini "sayfa kaydırma"
                        // sanıp kazanıyordu — kullanıcı bunu web derlemesinde
                        // bizzat bulup bildirdi (raf taşını çekerken ekran da
                        // kayıyordu).
                        physics: (_dragRef?.enabled ?? false)
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        // İçerik sütunu web'in her bölümdeki
                        // `max-w-[680px] mx-auto`sı gibi BURADA sınırlanıyor
                        // — kaydırma görünümünün KENDİSİ tam genişlik kalmalı
                        // ki tahtanın taşan gölgesi kırpılmasın (Parça 40).
                        child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: Column(
                                children: [
                                  Padding(
                                    // Web `Board.tsx`'in dış sarmalayıcısı:
                                    // `px-3 pt-1.5 pb-3` — port yalnızca yatayı
                                    // taşımıştı, alttaki 12px hiç yoktu.
                                    padding:
                                        const EdgeInsets.fromLTRB(12, 6, 12, 12),
                                    child: BoardWidget(
                                      state: state,
                                      moveOverlay: moveStatus == null
                                          ? null
                                          : MoveOverlay(
                                              valid: moveStatus.valid,
                                              cells: moveStatus.cells,
                                              score: moveStatus.score,
                                            ),
                                      onCellTap: _handleCellTap,
                                      gridKey: _gridKey,
                                      onOpenHistory: () =>
                                          showMoveHistoryModal(context, state),
                                      onOpenHelp: () => showHelpModal(context),
                                      onlineStatus: widget.onlineStatus,
                                      dragHiddenKey: _hiddenSource
                                              is _PlacedSource
                                          ? cellKey(
                                              (_hiddenSource as _PlacedSource)
                                                  .r,
                                              (_hiddenSource as _PlacedSource)
                                                  .c)
                                          : null,
                                      onTilePointerDown: (r, c, e) {
                                        final t = state.placed[cellKey(r, c)];
                                        if (t != null) {
                                          _beginTileDrag(
                                              _PlacedSource(r, c, t), e);
                                        }
                                      },
                                      onTilePointerMove: _moveTileDrag,
                                      onTilePointerUp: _endTileDrag,
                                      onTilePointerCancel: _cancelTileDrag,
                                    ),
                                  ),
                                  // Web: <main> içinde Board'dan hemen sonra mesaj
                                  // bloğu geliyor ve tek boşluk onun `pt-1`i (4px,
                                  // aşağıdaki Padding'de) — yani BURADA ek boşluk
                                  // YOK. Parça 16'da buraya 56px konmuştu ("tahta
                                  // gölgesi raf kartının opak zemini tarafından
                                  // eziliyor" gerekçesiyle); ama web de aynı
                                  // yapıya sahip ve orada sorun yok — gerçek kök
                                  // sebep Parça 17'de bulundu (max-width 680 hiç
                                  // uygulanmamış, tahta kenardan kenara gerilip
                                  // gölgeye yer kalmıyordu). O düzeltmeden sonra
                                  // bu 56px yalnızca web'den sapan görünür bir
                                  // boşluk olarak kaldı (kullanıcı 9 Ağustos
                                  // 2026'da bildirdi).
                                  // Mesaj satırı web'deki gibi tahtanın ALTINDA, rafın üstünde
                                  // (App.tsx: Board → liveMessage → Rack; font-mono 11px bold).
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(12, 4, 12, 0),
                                    child: SizedBox(
                                      key: const ValueKey('message-line'),
                                      height: 30,
                                      child: Center(
                                        child: Text(
                                          state.isGameOver
                                              ? 'Oyun bitti.'
                                              : liveMessage,
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'SpaceMono',
                                            fontWeight: FontWeight.bold,
                                            color: _messageColor(
                                                state.isGameOver
                                                    ? MessageKind.none
                                                    : liveKind),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (me != null) ...[
                                    // Web düzeni: Raf + (Oyna | Yeni Oyun) yan yana; swap
                                    // modunda sağdaki buton hiç görünmez (App.tsx ~1281).
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 6, 12, 0),
                                      // IntrinsicHeight: buton raf kartıyla aynı boya uzasın
                                      // (stretch, Column içinde sınırsız yükseklikte patlar).
                                      child: IntrinsicHeight(
                                        child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                  child: KeyedSubtree(
                                                    key:
                                                        _rackKey, // rafa-bırak alanı
                                                    child: RackWidget(
                                                      tiles: state
                                                          .players[_rackIndex].rack,
                                                      selectedTile:
                                                          state.selectedTile,
                                                      onSelect: (i) {
                                                        if (!_canAct) return;
                                                        controller.dispatch(state
                                                                .swapMode
                                                            ? ToggleSwapTileAction(
                                                                i)
                                                            : SelectTileAction(i));
                                                      },
                                                      title: state
                                                          .players[_rackIndex].name,
                                                      color: _colorOf(_rackIndex),
                                                      swapMode: state.swapMode,
                                                      swapSelection:
                                                          state.swapSelection,
                                                      // `_hiddenSource` (dragHiddenKey
                                                      // ile aynı kaynak/gerekçe).
                                                      dragHiddenIndex: _hiddenSource
                                                              is _RackSource
                                                          ? (_hiddenSource
                                                                  as _RackSource)
                                                              .index
                                                          : null,
                                                      onTilePointerDown: (i, e) =>
                                                          _beginTileDrag(
                                                              _RackSource(
                                                                  i,
                                                                  state
                                                                      .players[
                                                                          _rackIndex]
                                                                      .rack[i]),
                                                              e),
                                                      onTilePointerMove:
                                                          _moveTileDrag,
                                                      onTilePointerUp: _endTileDrag,
                                                      onTilePointerCancel:
                                                          _cancelTileDrag,
                                                    ),
                                                  ),
                                                ),
                                                if (!state.swapMode) ...[
                                                  const SizedBox(width: 6),
                                                  state.isGameOver
                                                      // Web (App.tsx ~1291): tek
                                                      // satır "Yeni Oyun Aç",
                                                      // `text-[15px]` + `px-5` —
                                                      // OYNA'dan (12px) belirgin
                                                      // BÜYÜK olması bilinçli,
                                                      // raf (`flex-1 min-w-0`)
                                                      // buna göre daralıyor. Port
                                                      // `\n` ile iki satıra bölüp
                                                      // 13px'te bırakmıştı.
                                                      ? NeoButton(
                                                          label: 'TEKRAR OYNA',
                                                          variant: NeoButtonVariant
                                                              .accent,
                                                          fontSize: 15,
                                                          letterSpacing: 1.2,
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 20),
                                                          onPressed: _handleRematch,
                                                        )
                                                      : NeoButton(
                                                          label: 'OYNA',
                                                          variant: NeoButtonVariant
                                                              .accent,
                                                          fontSize:
                                                              12, // web text-[12px]
                                                          letterSpacing: 1.2,
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 20),
                                                          // web: `disabled={!canAct
                                                          // || validating ||
                                                          // !wordsReady}` — taslak
                                                          // BOŞKEN de aktif.
                                                          // Bilerek: reducer boş
                                                          // taslakta "Harf
                                                          // yerleştirilmedi." diye
                                                          // ÖZEL bir mesaj üretiyor
                                                          // (validator.dart:57);
                                                          // butonu kapatmak o
                                                          // mesajı ulaşılamaz
                                                          // kılıp sebebi hiçbir
                                                          // yerde yazmayan sessiz
                                                          // bir ret bırakıyordu.
                                                          onPressed: _canAct
                                                              ? () => _handlePlay(
                                                                  moveStatus)
                                                              : null,
                                                        ),
                                                ],
                                              ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      // Üst boşluk 8→24: raf kartının kendi gölgesi
                                      // (blur:14, aşağı doğru) bu satırın opak
                                      // butonları tarafından ezilmesin diye (aynı
                                      // ders — bkz. yukarıdaki Board→mesaj notu).
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 6, 12, 12),
                                      child: state.swapMode
                                          ? Row(
                                              children: [
                                                Expanded(
                                                  child: NeoButton(
                                                    letterSpacing: 1.2,
                                                    lineHeight: 1.5,
                                                    label: state.swapSelection
                                                            .isNotEmpty
                                                        ? 'DEĞİŞTİR (${state.swapSelection.length})'
                                                        : 'DEĞİŞTİR',
                                                    variant:
                                                        NeoButtonVariant.gold,
                                                    onPressed: _canAct &&
                                                            state.swapSelection
                                                                .isNotEmpty
                                                        ? () => controller.dispatch(
                                                            const ConfirmSwapAction())
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: NeoButton(
                                                    letterSpacing: 1.2,
                                                    lineHeight: 1.5,
                                                    label: 'VAZGEÇ',
                                                    onPressed: _canAct
                                                        ? () => controller.dispatch(
                                                            const ToggleSwapModeAction())
                                                        : null,
                                                  ),
                                                ),
                                              ],
                                            )
                                          // IntrinsicHeight + stretch: web'de bu satır bir flex kutusu ve
                                          // `align-items: stretch` varsayılanı butonları EN UZUNA eşitliyor —
                                          // TORBA'nın 13px'lik sayacı satır yüksekliğini 19.5px'e çektiğinden
                                          // (ölçüldü) ötekiler de onunla aynı boyda. Flutter'da Row varsayılanı
                                          // `center`, yani her buton kendi boyunda kalıp TORBA 3px uzun çıkardı.
                                          // Sınırsız yükseklikte çıplak `stretch` patlar (raf satırındaki aynı
                                          // ders), o yüzden IntrinsicHeight şart.
                                          : IntrinsicHeight(
                                              child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                  child: NeoButton(
                                                    letterSpacing: 1.2,
                                                    lineHeight: 1.5,
                                                    label: 'PAS GEÇ',
                                                    onPressed: _canAct
                                                        ? _handlePass
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: NeoButton(
                                                    letterSpacing: 1.2,
                                                    lineHeight: 1.5,
                                                    label: 'DEĞİŞTİR',
                                                    onPressed: _canAct &&
                                                            state.bag.isNotEmpty
                                                        ? () => controller.dispatch(
                                                            const ToggleSwapModeAction())
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: NeoButton(
                                                    letterSpacing: 1.2,
                                                    lineHeight: 1.5,
                                                    label: 'KARIŞTIR',
                                                    onPressed: _canAct
                                                        ? () => controller.dispatch(
                                                            const ShuffleRackAction())
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: NeoButton(
                                                    letterSpacing: 1.2,
                                                    lineHeight: 1.5,
                                                    label: 'GERİ AL',
                                                    // web: `disabled={!canAct}`
                                                    // — boş taslakta da aktif
                                                    // (RECALL_ALL zararsız bir
                                                    // no-op).
                                                    onPressed: _canAct
                                                        ? () => controller.dispatch(
                                                            const RecallAllAction())
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: NeoButton(
                                                    letterSpacing: 1.2,
                                                    lineHeight: 1.5,
                                                    label:
                                                        'TORBA ${state.bag.length}',
                                                    // Web App.tsx ~1360: <span
                                                    // className="text-[13px]
                                                    // text-accent">{count}</span>
                                                    // — yalnızca puntoyu/rengi
                                                    // ezer, geri kalanı
                                                    // (bold/uppercase/tracking)
                                                    // butondan miras alır.
                                                    richLabel: [
                                                      const TextSpan(
                                                          text: 'TORBA '),
                                                      TextSpan(
                                                        text:
                                                            '${state.bag.length}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              kAccent,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                    // Web'de Torba hiç disable olmaz — YZ'nin
                                                    // sırasında/oyun bitince de açılabilir.
                                                    onPressed: () =>
                                                        showRemainingTilesModal(
                                                            context,
                                                            state,
                                                            _rackIndex),
                                                  ),
                                                ),
                                              ],
                                            )),
                                    ),
                                  ],
                                ],
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
                // Hover çerçevesi + hayalet taş: KOŞULSUZ duran tek bir
                // ValueListenableBuilder — yalnızca `_dragNotifier` değişince
                // (HER pointer hareketinde) kendi küçük alt ağacını günceller,
                // GameScreen'in (dolayısıyla BoardWidget'ın) tam build'ini
                // TETİKLEMEZ (bkz. yukarıdaki _dragNotifier notu).
                ValueListenableBuilder<_Ghost?>(
                  valueListenable: _dragNotifier,
                  builder: (context, ghost, _) {
                    if (ghost == null) return const SizedBox.shrink();
                    return Stack(children: [
                      _hoverHighlight(ghost),
                      _buildGhost(ghost),
                    ]);
                  },
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
