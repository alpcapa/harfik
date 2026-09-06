// Oynanabilir oyun ekranı — App.tsx'in oyun görünümünün çekirdeği: skor
// satırı + tahta (canlı geçerlilik çerçevesiyle) + mesaj + raf/OYNA + web
// buton düzeni (Pas Geç/Değiştir/Karıştır/Geri Al/Torba; swap modunda
// Değiştir (N)/Vazgeç) + GameOver modalı + sürükle-bırak (raftan tahtaya,
// tahtada taşıma, rafa geri — web beginDrag/endDrag portu). Kalıcılık bu
// ekranın DIŞINDA: SetupScreen oyunu GameSession'la sarar (autosave/çıkış
// kuralları, local_game_repo.dart) — ekran yalnızca oynatır. Parça parça
// Tahtadaki onaylanmış bir taşa dokunmak, o hücreden geçen kelimelerin
// anlamını gösterir (meanings deposu verilmişse).
import 'dart:async' show unawaited;
import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../data/auth_service.dart';
import '../../util/ai_level.dart';
import '../../storage/app_storage.dart';
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
import 'board_zoom.dart';
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
import '../loading_note.dart';
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

  /// Yerel bayraklar (zoom tanıtım balonu) — verilmezse balon hiç çıkmaz;
  /// testlerin ve önizlemelerin yolu bu. `OnlineGameScreen` aynı prop'u
  /// zaten taşıyordu.
  final Future<AppStorage>? storage;

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
    this.storage,
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

  /// Zoom tanıtım balonu (1 Eylül 2026) — açılışta bir kez karar verilir;
  /// zoom denenirse ANINDA kapanır ve bir daha hiç gösterilmez.
  bool _zoomHint = false;

  /// GameOver modalı bu isGameOver geçişi için zaten gösterildi mi
  /// (web gameOverDismissed'in eşleniği — kapatınca tahta görünür kalır).
  bool _gameOverShown = false;

  // ── Sürükle-bırak (web App.tsx beginDrag/moveDrag/endDrag portu) ──────
  static const double _dragLift = 30; // web DRAG_LIFT
  // Sürükleme eşiği — web'deki DRAG_THRESHOLD_MOUSE/DRAG_THRESHOLD_TOUCH ile
  // BİREBİR aynı (gerekçe: `src/App.tsx`). Fare ile parmak aynı değeri
  // kullanamaz; 6px'lik tek eşik altında hafif titreyen bir dokunuş
  // "sürükleme" sayılıp sessizce hiçbir şey yapmıyordu.
  static const double _dragThresholdMouse = 6; // web DRAG_THRESHOLD_MOUSE
  static const double _dragThresholdTouch = 10; // web DRAG_THRESHOLD_TOUCH

  /// BIRAKMA anındaki karar eşiği — hayalet eşiğinden (yukarıdaki 10 px)
  /// AYRI. Jest bu mesafeden az gittiyse bırakma değil dokunuş sayılır.
  /// 24, tahta hücresinin (26 px) hemen altında: bir hücreden az giden bir
  /// jest zaten bir hedef ifade edemiyor. Gerekçe ve ölçümler
  /// `_endTileDrag`in içinde.
  static const double _tapSlopOnRelease = 24;
  static double _dragThresholdFor(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse ? _dragThresholdMouse : _dragThresholdTouch;
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _rackKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

  // ── Tahta yakınlaştırması (1.0.5) — tasarımın tamamı: board_zoom.dart ──
  final BoardZoomController _zoom = BoardZoomController();

  /// Izgaranın GÖRÜNÜR karesi (BoardWidget'ın ClipRect'i). Zoom'luyken
  /// sanal ızgara bu karenin dışına taşar — bırakma noktaları hücreye
  /// çevrilmeden önce bu kutuyla KAPILANIR (bkz. `_cellAtGlobal`).
  final GlobalKey _viewportKey = GlobalKey();

  BoardPanRef? _panRef;

  /// Tahta dokunuş ADAYI: `_dragRef` yokken inen parmağın konumu. Eşik
  /// aşılırsa (pan/scroll/sürükleme) düşer; kalkışta hücre kutusu DIŞINA
  /// düşen dokunuşlar zoom'un çift dokunuş jestine sayılır.
  Offset? _boardTapDown;

  /// Pan jestinin ARTIĞI olan hücre dokunuşunu yutma penceresi: 10-18 px
  /// arası bir pan, GestureDetector'ın tap slop'unun (18) altında
  /// kaldığından ayrıca bir onTapUp üretir. Bayrak yerine ZAMAN — 18 px
  /// üstü panlarda tap hiç gelmez ve bir bayrak asılı kalıp SONRAKİ gerçek
  /// dokunuşu yerdi (web'in ghost-click dersi: yutmanın kapsamı davranış
  /// varsayımına bağlanmaz).
  DateTime _swallowTapsUntil = DateTime.fromMillisecondsSinceEpoch(0);
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

  /// Route geçiş animasyonu bitene kadar ekran YALNIZCA "Yükleniyor…"
  /// gösterir — **Canlı oyun ekranıyla birebir aynı deneyim**.
  ///
  /// Kullanıcı Android'de bildirdi: *"YZ ile oyun açtığında board'un ekrana
  /// gelmesi takılarak oluyor"* (girişli açılışta da; Canlı bekleyen oyunda
  /// OLMUYOR). Sebep tahtanın TEK SEFERLİK ilk çizimi: 169 hücrenin ikişer
  /// `MaskFilter.blur`lu iç gölgesi + kartın blur 20/14/60'lık üçlüsü —
  /// ~340 bulanıklaştırma, hepsi geçişin ortasındaki karede. Canlı oyunda
  /// yaşanmamasının sebebi de buydu: `OnlineGameScreen` geçiş sırasında
  /// "Yükleniyor…" gösterip tahtayı SONRA çiziyor.
  ///
  /// İlk çözüm gölgeleri ERTELEMEKTİ (`BoardWidget.cheapPaint`); kullanıcı
  /// bunun yerine tutarlılığı seçti: *"Neden bekleyen oyunlar gibi kısa bir
  /// yükleniyor çıkartmıyoruz? Her yerde aynı deneyim en azından."* Bu hem
  /// daha basit (tek mekanizma) hem daha garantili — geçiş boyunca ekranda
  /// tek bir metin var, tahta HİÇ çizilmiyor.
  ///
  /// Maliyet ortadan kalkmıyor, hareketli karelerin dışına taşınıyor. Kök
  /// çözüm hücre çiziminin önbelleğe alınması (mağaza sonrasına bırakıldı,
  /// `docs/decisions/product-backlog.md`).
  bool _ready = false;
  Animation<double>? _routeAnim;

  void _onRouteAnim(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _routeAnim?.removeStatusListener(_onRouteAnim);
    _routeAnim = null;
    if (mounted) setState(() => _ready = true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_zoomHintKarariVer());
    // `ModalRoute` yalnızca ilk kare SONRASI okunabilir (initState'te
    // context henüz ağaca bağlı değil).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anim = ModalRoute.of(context)?.animation;
      // Route yoksa ya da animasyon zaten bittiyse (testlerde ve ilk
      // route'ta böyle) bekleyecek bir şey yok.
      if (anim == null || anim.status == AnimationStatus.completed) {
        setState(() => _ready = true);
        return;
      }
      _routeAnim = anim..addStatusListener(_onRouteAnim);
    });
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
    // Geçiş yarıda kesilirse (kullanıcı hemen geri döndü) dinleyici asılı
    // kalmasın — route animasyonu bu State'ten uzun yaşıyor.
    _routeAnim?.removeStatusListener(_onRouteAnim);
    _dragNotifier.dispose();
    _zoom.dispose();
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
    // Taşa dokunuş çift BAŞLATAMAZ (yalnızca bir çiftin İKİNCİSİ olarak
    // yutulabilir — o kapı çağıranlarda): zinciri kır. Joker penceresinin
    // zoom'la İLİŞKİSİ YOK (kullanıcı kararı, 1 Eylül 2026): eskisi gibi
    // ANINDA açılır.
    _zoom.markUnpairableTap();
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


  /// **Iskalanan dokunuşu kurtarır** — taslak sürerken oynanmış bir taşa
  /// dokunulduğunda, komşusundaki taslak taşını hedef sayar.
  ///
  /// NEDEN (24 Ağustos 2026, kullanıcı Android'de bildirdi): tahta hücresi
  /// ~24 px ve parmağın bildirdiği temas MERKEZİ nişan alınan noktanın
  /// altında kalıyor, yani taslak taşını geri almak için dokunan kullanıcı
  /// sık sık komşu (oynanmış) taşa isabet ediyor. Hücreyi büyütmek mümkün
  /// değil — ama taslak sürerken oynanmış taşlar ZATEN ölü (anlam penceresi
  /// o sırada açılmıyor), yani onların alanını taslak taşına devretmek
  /// bedava.
  ///
  /// ⚠ YALNIZCA OYNANMIŞ hücrelerden çağrılır; BOŞ hücrelere hiç
  /// dokunulmaz — yoksa kelimeyi dizerken bir sonraki harfi yan hücreye
  /// koymak zorlaşırdı.
  ///
  /// Belirsizlikte TAHMİN ETMEZ: bir oynanmış taşın İKİ yanında birden
  /// taslak olabilir (tam da "iki kelimenin birleştiği yer" durumu —
  /// mevcut bir taşın altına ve üstüne harf koymak). O zaman dokunuş
  /// noktasına en yakın olan seçilir; mesafeler eşitse ya da ızgara
  /// ölçülemiyorsa hiçbir şey yapılmaz.
  (int, int)? _nearbyDraftCell(int r, int c, Offset global) {
    final adaylar = <(int, int)>[];
    void ekle(int rr, int cc) {
      if (rr < 0 || rr >= boardSize || cc < 0 || cc >= boardSize) return;
      if (state.placed[cellKey(rr, cc)] != null) adaylar.add((rr, cc));
    }
    ekle(r - 1, c);
    ekle(r + 1, c);
    ekle(r, c - 1);
    ekle(r, c + 1);
    if (adaylar.isEmpty) return null;
    if (adaylar.length == 1) return adaylar.first;

    final grid = _boxOf(_gridKey);
    if (grid == null) return null;
    final local = grid.globalToLocal(global);
    const gap = 3.0;
    final strideX = (grid.size.width + gap) / boardSize;
    final strideY = (grid.size.height + gap) / boardSize;
    double uzaklik((int, int) a) {
      final cx = a.$2 * strideX + (strideX - gap) / 2;
      final cy = a.$1 * strideY + (strideY - gap) / 2;
      return (local - Offset(cx, cy)).distanceSquared;
    }

    adaylar.sort((a, b) => uzaklik(a).compareTo(uzaklik(b)));
    // ⚠ PAY ŞART, çıplak `<` DEĞİL — CI yakaladı (24 Ağustos 2026): hücrenin
    // TAM ORTASINA dokunulduğunda iki mesafe matematiksel olarak eşit ama
    // kayan noktada ~1e-13 farkla biri "daha yakın" çıkıyor ve tahmin
    // etmeme kuralı sessizce deliniyordu. 0.8 (kare mesafede) ≈ 1.5 px'lik
    // gerçek bir kayma demek: gürültü altta kalır, kasıtlı bir kayma geçer.
    return uzaklik(adaylar[0]) < uzaklik(adaylar[1]) * 0.8 ? adaylar[0] : null;
  }

  Future<void> _handleCellTap(int r, int c, Offset global) async {
    final k = cellKey(r, c);
    // ── Çift dokunuşla zoom (1.0.5, board_zoom.dart) ────────────────────
    // Dokunuşun işleminden ÖNCE sorulur: bir çiftin İKİNCİSİYSE işlem
    // yutulur ve zoom değişir — ilk dokunuşun yaptığı iş (koyulan taş
    // dahil) OLDUĞU GİBİ KALIR (kullanıcı kararı, 1 Eylül 2026: "taşı geri
    // almadan, koyduğu yerde bırakarak zoomlamak lazım"). Çift yalnızca
    // BOŞ kareye dokunuşla başlar; taşa dokunuşlar zinciri kırar (taslak
    // taşınki `_tapPlacedTile`ın kendi içinde, onaylınınki burada).
    if (state.board[r][c] == null) {
      if (_registerZoomTap(global)) return;
      if (state.placed[k] == null) _zoom.registerPairableTap(global);
    } else {
      _zoom.markUnpairableTap();
    }
    if (state.board[r][c] != null) {
      // Tahtada duran (onaylanmış) bir taş: o hücreden geçen yatay ve dikey
      // kelimelerin anlamı gösterilir (web handleCellClick'in ilk dalı).
      // ⚠ TASLAK HAMLE VARKEN ANLAM AÇILMAZ (24 Ağustos 2026, kullanıcı
      // cihazda bildirdi): *"2 kelimenin birleştiği yere bir taş koyup
      // deneme yaparken (oynaya basmadan) koyduğum taşın üstüne basıp geri
      // almaya çalıştığımda oradaki daha önce bulunan kelimelerin anlamları
      // açıldı... Bu zaten yanlış, kelime anlamı deneme yapılırken hiç
      // açılmamalı."*
      //
      // Tahta hücresi ~24 px — parmağın temas MERKEZİ nişan alınan noktanın
      // altına düştüğünden, taslak taşını geri almak için dokunan kullanıcı
      // sık sık KOMŞU (oynanmış) taşa isabet ediyor. Hücreyi büyütmek
      // mümkün değil (ızgara ölçüsü kuralın kendisi), ama ıskalamayı
      // ZARARSIZ yapmak mümkün: taslak sürerken dokunuş sessizce yutulur,
      // kullanıcı yeniden dener. Taslak boşken davranış DEĞİŞMEDİ.
      if (state.placed.isNotEmpty) {
        // Iskalama kurtarma (bkz. `_nearbyDraftCell`): komşuda taslak varsa
        // dokunuş ona sayılır, yoksa SESSİZCE yutulur.
        final hedef = _nearbyDraftCell(r, c, global);
        if (hedef != null) {
          await _tapPlacedTile(hedef.$1, hedef.$2,
              state.placed[cellKey(hedef.$1, hedef.$2)]!);
        }
        return;
      }
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

    // BOŞ hücreye ıskalayan dokunuş — 27 Ağustos 2026, kullanıcı bildirdi:
    // *"tahtaya konan taşı kaldırmak için ilk tıklama yakalamıyor, ikincide
    // ya da üçüncüde yakalanıyor."*
    //
    // ÖLÇÜLDÜ (420×900): tahta hücresi 26,2 px ve parmağın temas MERKEZİ
    // nişan alınan noktanın ALTINDA kalıyor, yani taslak taşını geri almak
    // için dokunan kullanıcı sık sık BİR ALT hücreye düşüyor. O hücre boşsa
    // eskiden hiçbir şey olmuyordu — dahası ekrana *"Önce bir harf seç."*
    // yazıyordu, yani geri almaya çalışan kullanıcı alakasız bir uyarı
    // görüyordu.
    //
    // 24 Ağustos'ta eklenen kurtarma yalnızca OYNANMIŞ hücrelerden
    // çağrılıyordu ve o kısıtın gerekçesi şuydu: *"boş hücrelere hiç
    // dokunulmaz — yoksa kelimeyi dizerken bir sonraki harfi yan hücreye
    // koymak zorlaşırdı."* Gerekçe DOĞRU ama YALNIZCA bir raf taşı
    // SEÇİLİYKEN geçerli; seçim yokken boş hücreye dokunmak zaten hiçbir iş
    // yapmıyor (`_placeTile` yalnızca o mesajı üretip aynı durumu döner).
    // Yani seçim yokken kurtarmanın bedeli SIFIR.
    //
    // Bu yüzden koşul dar tutuldu: seçili taş varsa davranış DEĞİŞMEDİ.
    if (state.selectedTile == null && state.placed.isNotEmpty) {
      final hedef = _nearbyDraftCell(r, c, global);
      if (hedef != null) {
        await _tapPlacedTile(
            hedef.$1, hedef.$2, state.placed[cellKey(hedef.$1, hedef.$2)]!);
        return;
      }
    }

    final selIdx = state.selectedTile;
    final sel = (selIdx != null &&
            selIdx >= 0 &&
            selIdx < state.players[state.current].rack.length)
        ? state.players[state.current].rack[selIdx]
        : null;
    if (sel != null && sel.letter == '?') {
      // Joker: harf seçilene kadar taş konmaz (web pendingWild akışı).
      // Zoom'la İLİŞKİSİ YOK (kullanıcı kararı, 1 Eylül 2026): pencere
      // eskisi gibi ANINDA açılır — pencere açıkken gelen ikinci dokunuş
      // tahtaya değil pencereye/perdeye düşer. Modal açıldı → zincir kır.
      _zoom.markUnpairableTap();
      final choice = await showWildLetterSheet(context);
      if (choice?.letter == null) return;
      controller
          .dispatch(PlaceTileAction(r: r, c: c, wildLetter: choice!.letter));
      return;
    }
    controller.dispatch(PlaceTileAction(r: r, c: c));
  }

  /// Çift dokunuş kontrolü — `true` dönerse dokunuşun kendi işlemi
  /// YUTULMALI: ya pan artığıydı ya da bir çiftin ikincisi (zoom değişti;
  /// ilk dokunuşun yaptığı iş — koyulan taş dahil — OLDUĞU GİBİ KALIR).
  bool _registerZoomTap(Offset global) {
    if (clock.now().isBefore(_swallowTapsUntil)) return true;
    if (!_zoom.tryCompletePair(global)) return false;
    _toggleZoomAt(global);
    return true;
  }


  /// Balon gösterilsin mi — kararı `FlagsStore` veriyor (tek kaynak, web
  /// `onboarding.ts` ile aynı kural: denenmişse asla, denenmemişse en çok
  /// iki oyun açılışında). Gösterime KARAR VERİLDİĞİ anda sayaç artıyor:
  /// "gösterim" balonun ekrana gelmesidir, kapanma biçimi değil.
  Future<void> _zoomHintKarariVer() async {
    final storageFuture = widget.storage;
    if (storageFuture == null) return;
    final storage = await storageFuture;
    final flags = storage.flags;
    if (!mounted || !flags.shouldShowZoomHint) return;
    await flags.bumpZoomHintShown();
    if (!mounted) return;
    setState(() => _zoomHint = true);
  }

  /// Kullanıcı zoom'u DENEDİ — balon kapanır ve kalıcı olarak susar.
  void _zoomDenendiIsaretle() {
    if (_zoomHint) setState(() => _zoomHint = false);
    final storageFuture = widget.storage;
    if (storageFuture == null) return;
    unawaited(storageFuture.then((s) => s.flags.markZoomTried()));
  }

  void _toggleZoomAt(Offset global) {
    _zoomDenendiIsaretle();
    final grid = _boxOf(_gridKey);
    if (grid == null) return;
    // Zoom KAPALIYKEN transform birim matristir → `globalToLocal` ölçeksiz
    // yerel noktayı verir (toggleAt'in beklediği uzay). Açıkken odak zaten
    // kullanılmaz — kapanış offset'i sıfırlar.
    //
    // ⚠ ÖLÇEKLENEN KUTU IZGARA DEĞİL, TAHTANIN KENDİSİ (2 Eylül 2026):
    // `board_widget.dart` → `_zoomWrap` artık web'le aynı sırada
    // (`ClipPath(kart) → Transform → Padding(10) → ızgara`), yani zoom
    // matematiğinin kutusu görünür kare (web `boxOf` ile aynı) ve odak
    // ızgara uzayından tahta uzayına `kBoardPad` eklenerek çevriliyor.
    // Izgara boyutu verilseydi izinli öteleme 20 px kısa kalırdı.
    final vp = _boxOf(_viewportKey);
    _zoom.toggleAt(
      grid.globalToLocal(global) + const Offset(kBoardPad, kBoardPad),
      vp?.size ?? grid.size,
    );
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
    final playerCount = state.players.length;
    controller.dispatch(StartAction(
      [
        for (final p in state.players)
          PlayerSetup(name: p.name, isAI: p.isAI),
      ],
      // Aynı ZORLUK da (ROADMAP #23 Faz 4, web `App.tsx` rövanşıyla aynı):
      // rövanş biten oyunun seviyesini taşır, Setup'a dönmeden Kolay'dan
      // Normal'e geçilemez. Normal'de alan zaten null, yine yazılmaz.
      aiLevel: state.aiLevel,
    ));
    setState(() => _gameOverShown = false);
    _zoom.reset();
    // Anonim başlangıç sayacı — Setup'taki "Oyunu Başlat" ile AYNI olay
    // (web'de ikisi de tek bir `startLocalGame` yardımcısından geçiyor).
    unawaited(_logGameStart(playerCount));
  }

  /// `game_starts` sayaç satırı — `setup_screen.dart`taki eşiyle aynı
  /// sözleşme: fire-and-forget ve HİÇBİR koşulda fırlatmaz. `logStart` zaten
  /// gateway hatasını yutuyor; buradaki try/catch `widget.games` FUTURE'ının
  /// reddedilme ihtimali için (`unawaited` hatayı yutmaz).
  Future<void> _logGameStart(int playerCount) async {
    try {
      final games = await widget.games;
      await games?.logStart(playerCount: playerCount);
    } catch (_) {
      // Telemetri hiçbir koşulda oyunu etkilemez.
    }
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
    // Görünür kare varsa ONUN üstüne kırp: zoom'luyken sanal ızgaranın üstü
    // (grid.localToGlobal) görünür alanın DIŞINA çıkabilir.
    final box = _boxOf(_viewportKey) ?? _boxOf(_gridKey);
    final lifted = y - _dragLift;
    if (box == null) return lifted;
    final top = box.localToGlobal(Offset.zero).dy;
    return lifted < top + 1 ? top + 1 : lifted;
  }

  /// Global noktayı hücreye çevirir — web elementFromPoint'in geometri
  /// tabanlı eşleniği (ızgara: 13 hücre + 12×3px boşluk; boşluğa düşen
  /// nokta soldaki/üstteki hücreye sayılır).
  (int, int)? _cellAtGlobal(Offset global) {
    final grid = _boxOf(_gridKey);
    if (grid == null) return null;
    // ZOOM KAPISI: zoom'luyken SANAL ızgara görünür karenin (ClipRect)
    // dışına taşar. Kapı olmasa rafın üstüne bırakılan taş, ters transform
    // yüzünden "görünmez bir hücreye" inerdi — `_endTileDrag` hücre
    // kontrolünü raftan ÖNCE yaptığından taş rafa dönemezdi
    // (board_zoom_test kilitliyor).
    final vp = _boxOf(_viewportKey);
    if (vp != null) {
      final vLocal = vp.globalToLocal(global);
      if (vLocal.dx < 0 ||
          vLocal.dy < 0 ||
          vLocal.dx >= vp.size.width ||
          vLocal.dy >= vp.size.height) {
        return null;
      }
    }
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

  // ── Tahta pan'i (yalnızca zoom açıkken) ────────────────────────────────
  //
  // Ham Listener, jest arenası YOK (taş sürüklemeyle aynı dil). Hit-test
  // sırası çocuk → ata olduğundan taslak taşın Listener'ı `_dragRef`i BU
  // çağrıdan ÖNCE doldurur — doluysa pan hiç başlamaz.
  void _boardPointerDown(PointerDownEvent e) {
    if (_dragRef != null) return; // taş jesti sahiplendi (çocuk Listener önce)
    // Dokunuş ADAYI: hücre kutusuna DÜŞMEYEN dokunuşlar (3 px'lik hücre
    // araları + 10 px'lik çerçeve dolgusu) da zoom'un çift dokunuş jestine
    // sayılsın (1 Eylül 2026, kullanıcı APK'da bildirdi: "zoom sadece
    // karelerde çalışıyor, kenarlar da dahil olmalı"). Hücrelerin üstüne
    // düşenleri hücrenin kendi GestureDetector'ı işler — `_boardPointerUp`
    // geometriyle ayıklar, çift işleme olmaz.
    _boardTapDown = e.position;
    if (!_zoom.zoomed || _panRef != null) return;
    // setState şart: scroll kilidi `_panRef`e bağlı (taş sürüklemedeki
    // physics deseninin aynısı).
    setState(() => _panRef = BoardPanRef(e.position));
  }

  void _boardPointerMove(PointerMoveEvent e) {
    final down = _boardTapDown;
    if (down != null &&
        (e.position - down).distance >= _dragThresholdFor(e.kind)) {
      _boardTapDown = null; // hareket etti: dokunuş adayı düştü
    }
    final p = _panRef;
    if (p == null) return;
    if (!p.moved) {
      if ((e.position - p.start).distance < _dragThresholdFor(e.kind)) return;
      p.moved = true;
    }
    final grid = _boxOf(_gridKey);
    if (grid == null) return;
    // Kutu LAYOUT boyutudur (transform boyutu değiştirmez) — clamp
    // matematiği ölçeksiz kare üzerinden. Görünür kare (= ölçeklenen
    // kutu, kartın tamamı) varsa O kullanılır; gerekçe `_toggleZoomAt`.
    _zoom.panBy(e.delta, _boxOf(_viewportKey)?.size ?? grid.size);
  }

  void _boardPointerUp(PointerUpEvent e) {
    final down = _boardTapDown;
    _boardTapDown = null;
    _endBoardPan();
    if (down == null) return;
    // Hücre kutusuna düşen dokunuş hücrenin GestureDetector'ının işi —
    // burada da sayılsaydı algılayıcıya İKİ kez yazılır, tek dokunuş "çift"
    // sanılırdı. Karar İNİŞ noktasına göre: tap tanıyıcısı jestin sahibi
    // olup olmadığına inişte karar verir; parmak hücrede inip boşlukta
    // kalkarsa hücre tanıyıcısı YİNE ateşler — kalkışa bakmak aynı çift
    // saymayı geri getirirdi. Boşluğa/çerçeveye inen ise tahta dokunuşudur.
    if (_pointHitsCellBox(down)) return;
    if (_registerZoomTap(down)) return;
    _zoom.registerPairableTap(down);
  }

  void _endBoardPan() {
    _boardTapDown = null;
    final p = _panRef;
    if (p == null) return;
    setState(() => _panRef = null);
    if (p.moved) {
      // 10-18 px arası bir pan GestureDetector'ın tap'ini de üretir —
      // artığı zaman penceresiyle yut (bkz. `_swallowTapsUntil` gerekçesi).
      _swallowTapsUntil =
          clock.now().add(const Duration(milliseconds: 120));
      _zoom.markUnpairableTap();
    }
  }

  /// Nokta bir HÜCRE kutusunun içinde mi (hücre araları ve çerçeve HARİÇ)?
  /// `_cellAtGlobal`dan farkı tam bu: o, boşluğa düşen noktayı komşu
  /// hücreye SAYAR (bırakma toleransı); burada ise hücrenin gerçek dokunma
  /// kutusu ölçülüyor. Sınırda tereddüt = HÜCRE say (çift işlemektense hiç
  /// işlememek: hücre detector'ı zaten çalışacak).
  bool _pointHitsCellBox(Offset global) {
    final grid = _boxOf(_gridKey);
    if (grid == null) return true;
    final local = grid.globalToLocal(global);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= grid.size.width ||
        local.dy >= grid.size.height) {
      return false; // çerçeve/dolgu
    }
    const gap = 3.0;
    final strideX = (grid.size.width + gap) / boardSize;
    final strideY = (grid.size.height + gap) / boardSize;
    const eps = 0.5;
    return (local.dx % strideX) < strideX - gap + eps &&
        (local.dy % strideY) < strideY - gap + eps;
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
      if ((e.position - d.start).distance < _dragThresholdFor(e.kind)) return;
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

  /// Sürükleme değil DOKUNUŞ olarak işle — hem "hiç kıpırdamadı" dalı hem
  /// titreşimli dokunuş dalı buradan geçer, davranışları AYRIŞMASIN diye.
  Future<void> _dokunusOlarakIsle(_DragSource s, Offset globalPos) async {
    if (s is _RackSource) {
      // Raf dokunuşu tahta çifti oluşturamaz (zoom kapsamı yalnızca tahta).
      _zoom.markUnpairableTap();
      if (!_canAct) return;
      controller.dispatch(state.swapMode
          ? ToggleSwapTileAction(s.index)
          : SelectTileAction(s.index));
    } else if (s is _PlacedSource) {
      // Bu dokunuş bir çiftin İKİNCİSİYSE geri alma YUTULUR ve zoom
      // değişir — ilk dokunuş taşı KOYDUYSA parmağın altındaki hücre artık
      // boş değildir; ikinci vuruş o taşı geri almasın (kullanıcı kararı:
      // taş koyduğu yerde kalır). Çift değilse normal geri alma.
      if (_registerZoomTap(globalPos)) return;
      await _tapPlacedTile(s.r, s.c, s.tile);
    }
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
      await _dokunusOlarakIsle(d.source, e.position);
      return;
    }

    // TİTREŞİMLİ DOKUNUŞ — 27 Ağustos 2026, kullanıcı İKİNCİ kez bildirdi:
    // *"Hâlâ tahtaya koyulan taşı her zaman alamıyorum. 1-2 denemeden sonra
    // alabiliyorum."* Bir gün önceki kurtarma YALNIZCA yukarıdaki
    // "hiç kıpırdamadı" dalında çalışıyordu; parmak 10 px'i aşınca jest
    // SÜRÜKLEME sayılıp bambaşka bir yola giriyordu.
    //
    // ÖLÇÜLDÜ (420×900, taslak taşa dokunup bırakma):
    //   6 px kayma  → taş geri alındı
    //   12 px kayma → HİÇBİR ŞEY olmadı
    //   20 px kayma → HİÇBİR ŞEY olmadı
    // Raf tarafı da aynı: 12/20 px kayan dokunuşta `selectedTile` null
    // kalıyor, yani taş seçilemiyor bile.
    //
    // Sebep iki eşiğin TEK eşik sanılması: 10 px (Android touch slop)
    // hayaleti GÖSTERMEK için doğru bir sınır, ama BIRAKMA kararı için
    // fazla dar — parmak o kadarını istemeden aşıyor. Artık iki ayrı karar
    // var: hayalet 10 px'te belirir, bırakma ise jest gerçekten bir yere
    // GİTTİYSE "bırakma" sayılır.
    //
    // ⚠ Taslak taş için eşik kaçınılmaz olarak bir belirsizliği çözüyor:
    // bırakma noktası 30 px KALDIRILMIŞ olduğundan (`_liftedY`), "taşı bir
    // üst hücreye taşı" jesti de parmağın neredeyse HİÇ kıpırdamaması
    // demek — yani "geri al" ile aynı jest. Belirsizlik, açık ara daha sık
    // olan niyet lehine çözülüyor: kısa jest = GERİ AL. Taşı taşımak hâlâ
    // mümkün (daha uzun bir jestle, ya da geri alıp yeniden koyarak).
    final s = d.source;
    final gittigiMesafe = (e.position - d.start).distance;
    final rafinUstunde = s is _RackSource && _rackContains(e.position);
    if (rafinUstunde || gittigiMesafe < _tapSlopOnRelease) {
      await _dokunusOlarakIsle(s, e.position);
      return;
    }

    // Gerçek bir sürükleme tamamlandı — önceki dokunuş kaydı bayatladı,
    // sonraki dokunuş onunla çift oluşturmasın.
    _zoom.markUnpairableTap();
    if (!d.enabled) return;

    final lifted = Offset(e.position.dx, _liftedY(e.position.dy));
    final cell = _cellAtGlobal(lifted);
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
    // Hücrenin İKİ köşesi ızgaranın YEREL uzayında hesaplanıp
    // `localToGlobal` ile geçirilir — zoom transformu ne olursa olsun doğru
    // (eski "origin + c·stride" biçimi origin'i transform'dan geçirip
    // stride'ı ölçeksiz bırakıyordu; zoom'da çerçeve yanlış hücreye/boyuta
    // düşerdi).
    final tl = stack.globalToLocal(
        grid.localToGlobal(Offset(c * strideX, r * strideY)));
    final br = stack.globalToLocal(grid.localToGlobal(Offset(
        c * strideX + (strideX - gap), r * strideY + (strideY - gap))));
    return Positioned(
      left: tl.dx,
      top: tl.dy,
      width: br.dx - tl.dx,
      height: br.dy - tl.dy,
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
        // Geçiş animasyonu sürerken TAHTA HİÇ ÇİZİLMEZ (bkz. `_ready`) —
        // Canlı oyun ekranının yükleme durumuyla aynı görünüm.
        if (!_ready) {
          return const Scaffold(
            backgroundColor: Colors.white, // web sayfa zemini (colors.bg)
            body: SafeArea(child: Center(child: KLoadingNote())),
          );
        }
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
                onFeedback: auth == null ? null : openFeedback,
                // Yerel oyun = YZ oyunu → rozet her seviyede; Canlı ekran
                // bu parametreyi hiç geçirmez.
                aiLevel: aiLevelForBadge(state.aiLevel, isAiGame: true));
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
                // ⚡ REPAINT SINIRI (26 Ağustos 2026 — kapalı testin ilk
                // gerçek kullanıcıları bildirdi: *"taşları sürerken ağır
                // çekim, akıcı değil, takılmalar oluyor. Web'de çok hızlı"*).
                //
                // Parça 23 sürüklemede REBUILD'i durdurmuştu (hayalet taş
                // `_dragNotifier` üzerinden kendi küçük alt ağacını
                // güncelliyor, `BoardWidget.build()` tetiklenmiyor) — ve o
                // testle kilitli. Ama REPAINT durmuyordu: hayalet, tahtayla
                // AYNI katmanda duran bir kardeş; hareket ettiği her karede
                // Flutter bu `Stack`in tamamını yeniden BOYUYOR.
                //
                // Bu tahtada boyamanın bedeli olağanüstü: 169 hücrenin
                // ikişer `MaskFilter.blur`lu iç gölgesi + kartın 20/14/60'lık
                // üçlüsü ≈ **340 bulanıklaştırma**. Bu sayı zaten bu dosyada
                // yazılıydı (`_ready` notu) ama yalnızca AÇILIŞ karesi için
                // çözülmüştü ("Yükleniyor…" ile hareketli karelerin dışına
                // taşınarak); sürükleme sırasında aynı bedel HER KARE
                // ödeniyordu.
                //
                // `RepaintBoundary` tahtayı kendi katmanına alıyor: sürükleme
                // boyunca içerik değişmediğinden bir kez boyanıp doku olarak
                // yeniden kullanılıyor, hayalet üstünde süzülüyor.
                //
                // ⚠ Mevcut `BoardWidget.build()` sayacı bunu GÖREMEZ —
                // `build` ile `paint` ayrı şeyler; sayaç 1 derken cihaz
                // saniyede 340 blur çiziyordu. Yeni test paint sayıyor.
                RepaintBoundary(
                  child: Column(
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
                          physics: ((_dragRef?.enabled ?? false) ||
                                  _panRef != null)
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
                                        // "Buradan başla" balonu, taş
                                        // KALDIRILDIĞI anda kaybolsun diye
                                        // sürükleme sinyalini alıyor. Bool
                                        // bir prop olsaydı sürüklemenin
                                        // başında/sonunda tüm ekranı
                                        // setState'lemek gerekirdi; böyle
                                        // yalnızca balon katmanı dinliyor
                                        // (Parça 23'ün kuralı korunuyor).
                                        dragListenable: _dragNotifier,
                                        moveOverlay: moveStatus == null
                                            ? null
                                            : MoveOverlay(
                                                valid: moveStatus.valid,
                                                cells: moveStatus.cells,
                                                score: moveStatus.score,
                                              ),
                                        onCellTap: _handleCellTap,
                                        gridKey: _gridKey,
                                        zoomHint: _zoomHint,
                                        zoom: _zoom,
                                        viewportKey: _viewportKey,
                                        onBoardPointerDown: _boardPointerDown,
                                        onBoardPointerMove: _boardPointerMove,
                                        onBoardPointerUp: _boardPointerUp,
                                        onBoardPointerCancel: _endBoardPan,
                                        onOpenHistory: () =>
                                            showMoveHistoryModal(context, state),
                                        // Zorluk rozeti alt şeritte — yerel
                                        // oyun her zaman YZ oyunu (her seviye).
                                        aiLevel: aiLevelForBadge(state.aiLevel,
                                            isAiGame: true),
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
                                      // ⚠ SABİT YÜKSEKLİK DEĞİL, ASGARİ —
                                      // web ikizi `min-h-[30px]` diyor,
                                      // port `height: 30` diyordu. Sistem
                                      // yazı ölçeğinde iki satır 38 px'e
                                      // çıkıp 30 px kutuda KESİLİYORDU
                                      // (2 Eylül 2026, kullanıcı cihazda:
                                      // "rafın üzerindeki mesaj kutusu
                                      // 2 satırda kesiliyor"). `maxLines`
                                      // de kaldırıldı: web'de sınır yok,
                                      // uzun mesaj satır sayısı kadar yer
                                      // kaplıyor.
                                      child: ConstrainedBox(
                                        key: const ValueKey('message-line'),
                                        constraints:
                                            const BoxConstraints(minHeight: 30),
                                        child: Center(
                                          child: Text(
                                            state.isGameOver
                                                ? 'Oyun bitti.'
                                                : liveMessage,
                                            textAlign: TextAlign.center,
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
                                                        onTilePointerDown: (i, e) {
                                                          // ⚠ SINIR KONTROLÜ — YARIŞ, süs
                                                          // DEĞİL. 26 Ağustos 2026'da sahada
                                                          // çöktü: `RangeError (length):
                                                          // Not in inclusive range 0..5: 6`
                                                          // (`client_errors`, route=game).
                                                          // `RackWidget` dokunma kutularını
                                                          // ÇİZİLDİĞİ ANDAKİ raf uzunluğuna
                                                          // göre kuruyor; parmak indiğinde raf
                                                          // kısalmışsa (taş tahtaya geçmiş)
                                                          // `rack[i]` sınır dışına düşüyor.
                                                          final rack = state
                                                              .players[_rackIndex].rack;
                                                          if (i < 0 || i >= rack.length) {
                                                            return;
                                                          }
                                                          _beginTileDrag(
                                                              _RackSource(i, rack[i]), e);
                                                        },
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
