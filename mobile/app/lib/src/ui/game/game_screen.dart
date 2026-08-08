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
import '../../data/feedback_api.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../../data/meaning_store.dart';
import '../feedback/feedback_modal.dart';
import '../../game/game_controller.dart';
import '../../game/move_status.dart';
import 'board_widget.dart';
import 'game_header.dart';
import 'game_over_modal.dart';
import 'meaning_modal.dart';
import 'move_history_modal.dart';
import 'neo_button.dart';
import 'player_colors.dart';
import 'rack_widget.dart';
import 'remaining_tiles_modal.dart';
import 'tile_widget.dart';
import 'wild_letter_sheet.dart';

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

class _GameScreenState extends State<GameScreen> {
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
  void dispose() {
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
      await showMeaningModal(context, store.lookup, [
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
        final parts = split.shares
            .map((s) =>
                '${s.amount} puanı ${state.players[s.index].name} kullanıcısına')
            .join(', ');
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sınır İhlali!'),
            content: Text(
                'Bu hamleden kazanacağın $score puanın $parts vergi olarak gidecek.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('VAZGEÇ'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('OYNA'),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }
    }
    controller.dispatch(const PlayAction());
  }

  Future<void> _handlePass() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pas Geç'),
        content: const Text('Sıranı pas geçmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('VAZGEÇ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('PAS GEÇ'),
          ),
        ],
      ),
    );
    if (ok == true) controller.dispatch(const PassAction());
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
    final key = g.overKey;
    if (key == null) return const SizedBox.shrink();
    final grid = _boxOf(_gridKey);
    final stack = _boxOf(_stackKey);
    if (grid == null || stack == null) return const SizedBox.shrink();
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
            g.overValid ? const Color(0xFF1FA05C) : const Color(0xFFE0483A),
          ),
        ),
      ),
    );
  }

  Color _messageColor(MessageKind kind) => switch (kind) {
        MessageKind.err => const Color(0xFFE0483A),
        MessageKind.ok => const Color(0xFF1FA05C),
        MessageKind.warn => const Color(0xFFD97706),
        MessageKind.none => const Color(0xFF5B6472),
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final auth = widget.auth;
            showGameOverModal(context, state,
                // Web GameOver onOpenFeedback (source: 'game_end').
                onFeedback: auth == null
                    ? null
                    : () => showFeedbackModal(context,
                        auth: auth,
                        feedback: widget.feedback,
                        source: FeedbackSource.gameEnd));
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

        return Scaffold(
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
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      children: [
                        // Gerçek başlık: logo (dokunuş = oyundan çık) + skor kutuları
                        // (GameHeader.tsx portu, akıcı clamp sistemiyle).
                        GameHeader(
                          state: state,
                          auth: widget.auth,
                          stats: widget.stats,
                          games: widget.games,
                          feedback: widget.feedback,
                          friends: widget.friends,
                          onLogoTap: () => Navigator.of(context).pop(),
                        ),
                        // Web akışıyla aynı: tahta → mesaj → raf → butonlar yukarıdan
                        // aşağı dizilir, artan boşluk EN ALTA düşer (önceden tahta
                        // Expanded'ta tek başınaydı ve boşluk tahta ile mesajın
                        // ARASINA giriyordu); kısa ekranda tamamı kaydırılabilir.
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
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
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
                                    dragHiddenKey: _hiddenSource
                                            is _PlacedSource
                                        ? cellKey(
                                            (_hiddenSource as _PlacedSource).r,
                                            (_hiddenSource as _PlacedSource).c)
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
                                // Tahtanın nömorfik gölgesi (en büyüğü blur:60,
                                // aşağı doğru) sönümlenecek yer bulamadan hemen
                                // altındaki raf kartının OPAK zemini tarafından
                                // "ezilip" görünmez oluyordu — Column'da geç
                                // çizilen kardeş widget'lar erken çizilenin
                                // üzerine boyar (kullanıcı web derlemesinde
                                // bizzat bulup bildirdi; ölçülerek doğrulandı).
                                const SizedBox(height: 56),
                                // Mesaj satırı web'deki gibi tahtanın ALTINDA, rafın üstünde
                                // (App.tsx: Board → liveMessage → Rack; font-mono 11px bold).
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                  child: SizedBox(
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
                                          color: _messageColor(state.isGameOver
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
                                    padding:
                                        const EdgeInsets.fromLTRB(12, 4, 12, 0),
                                    // IntrinsicHeight: buton raf kartıyla aynı boya uzasın
                                    // (stretch, Column içinde sınırsız yükseklikte patlar).
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: KeyedSubtree(
                                              key: _rackKey, // rafa-bırak alanı
                                              child: RackWidget(
                                                tiles: state
                                                    .players[_rackIndex].rack,
                                                selectedTile:
                                                    state.selectedTile,
                                                onSelect: (i) {
                                                  if (!_canAct) return;
                                                  controller.dispatch(state
                                                          .swapMode
                                                      ? ToggleSwapTileAction(i)
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
                                                dragHiddenIndex:
                                                    _hiddenSource is _RackSource
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
                                            const SizedBox(width: 8),
                                            state.isGameOver
                                                ? NeoButton(
                                                    label: 'YENİ\nOYUN',
                                                    variant:
                                                        NeoButtonVariant.accent,
                                                    fontSize: 13,
                                                    letterSpacing: 1.2,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 20),
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(),
                                                  )
                                                : NeoButton(
                                                    label: 'OYNA',
                                                    variant:
                                                        NeoButtonVariant.accent,
                                                    fontSize: 13,
                                                    letterSpacing: 1.2,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 20),
                                                    onPressed: _canAct &&
                                                            state.placed
                                                                .isNotEmpty
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
                                        12, 24, 12, 12),
                                    child: state.swapMode
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: NeoButton(
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
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: NeoButton(
                                                  label: 'VAZGEÇ',
                                                  onPressed: _canAct
                                                      ? () => controller.dispatch(
                                                          const ToggleSwapModeAction())
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              Expanded(
                                                child: NeoButton(
                                                  label: 'PAS GEÇ',
                                                  onPressed: _canAct
                                                      ? _handlePass
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: NeoButton(
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
                                                  label: 'GERİ AL',
                                                  onPressed: _canAct &&
                                                          state
                                                              .placed.isNotEmpty
                                                      ? () => controller.dispatch(
                                                          const RecallAllAction())
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: NeoButton(
                                                  label:
                                                      'TORBA ${state.bag.length}',
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
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
        );
      },
    );
  }
}
