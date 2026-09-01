// Canlı oyun tahtası — src/components/OnlineGameScreen.tsx portu. Yerel
// (GameScreen) ekranın AYNI bileşenlerini (BoardWidget/RackWidget/GameHeader)
// ve AYNI doğrulama/puanlama fonksiyonlarını (kelimeki_core validator)
// kullanır; fark, OYNA/PAS GEÇ/DEĞİŞTİR'in artık reducer'ın PLAY/PASS/
// CONFIRM_SWAP'ını değil `submit_move` RPC'sini çağırması ve tahtanın/
// skorların yerelden değil `online_game_states`'ten (Realtime abonelikle)
// gelmesi.
//
// **Bilinçli kod tekrarı (web'in kendi yapısıyla aynı):** sürükle-bırak
// katmanı ve tahta/raf/buton düzeni `game_screen.dart` ile neredeyse
// birebir aynı — web de App.tsx ↔ OnlineGameScreen.tsx olarak iki ayrı
// dosyada taşıyor ve kök CLAUDE.md bunu "ikisi deseni paylaşıyor, biri
// değişirse diğeri de güncellenmeli" diye kayda geçmiş. Port bu ayrımı
// KORUYOR ki web dosyaları ile mobil dosyalar bire bir eşleşsin; ortak bir
// kabuğa çıkarmak eşlemeyi dolaylı hale getirirdi. Kural: bu ikisinden
// birindeki sürükleme/joker/mesaj deseni değişirse ÖTEKİ de güncellenmeli
// (mobile/CLAUDE.md doküman-senkron tablosunda ayrı satır).
//
// Teslim olma manuel DEĞİL, zaman aşımlı: logo yalnızca Canlı listesine
// döner, oyunu bitirmez — sırası gelen 48 saat içinde oynamazsa
// `check_turn_timeout` onu otomatik teslim eder (kök CLAUDE.md "Canlı Oyun
// — Faz 3.6"); bu tarama aşağıdaki `_refresh()` döngüsünden çağrılır.
//
// **Web'den bilinçli SAPMA — kelime doğrulaması yerel:** web `handlePlay`'de
// her kelimeyi `is_valid_word` RPC'siyle sunucuya sorar (kelime başına bir
// gidiş-dönüş) ve hata durumunda yerel sözlüğe düşer. Mobil uygulamada TÜM
// sözlük zaten pakette (`words_tr.txt`, `public.words` ile aynı kaynaktan
// üretilir) ve tahtadaki canlı yeşil/kırmızı çerçeve de onu kullanıyor —
// mobil ağda N sıralı RPC hem yavaş hem de "çerçeve yeşil ama OYNA hata
// veriyor" gibi çelişkili bir ekran riski. Bu yüzden tek yerel
// `validatePlacement` çağrısı yeterli; sunucu zaten kelime doğrulamıyor
// (mimari karar, kök CLAUDE.md "Faz 3"), dolayısıyla güvenlik kaybı yok.
// Tek gerçek fark: `public.words`a uygulama sürümü çıkmadan eklenen bir
// kelimeyi web oynayabilir, mobil oynayamaz.
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../data/auth_service.dart';
import '../../data/chat_api.dart';
import '../../data/feedback_api.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/meaning_store.dart';
import '../../data/online_games_api.dart';
import '../../data/stats_api.dart';
import '../../game/game_controller.dart';
import '../../game/move_status.dart';
import '../../storage/app_storage.dart';
import '../auth/k_avatar.dart';
import '../chat/chat_modal.dart';
import '../chat/chat_settings_modal.dart';
import '../feedback/feedback_modal.dart';
import '../game/board_widget.dart';
import '../game/board_zoom.dart';
import '../game/dialog_shell.dart';
import '../game/game_header.dart';
import '../game/game_over_modal.dart';
import '../game/help_modal.dart';
import '../game/meaning_modal.dart';
import '../game/move_history_modal.dart';
import '../game/neo_box.dart';
import '../game/neo_button.dart';
import '../game/player_colors.dart';
import '../game/rack_widget.dart';
import '../game/remaining_tiles_modal.dart';
import '../game/tile_widget.dart';
import '../game/wild_letter_sheet.dart';
import '../score/player_score_card_modal.dart';
import '../../data/league_rewards_api.dart';
import '../rank/league_rewards_host.dart';
import '../loading_note.dart';
import '../tokens.dart';
import '../game/invasion_confirm.dart';
import '../../util/offline_notice.dart';
import '../../util/online_status.dart';
import '../../data/error_reporter.dart';

const Color _muted = kMuted;
const Color _red = kRed;

/// Sohbet durumu — `_OnlineGameScreenState` sahibi, hem Board footer'ının
/// rozeti (kırmızı nokta) hem AÇIK duran ChatModal/ChatSettingsModal
/// dialoglarının canlı güncellenmesi için (web'de bu, React state'inin
/// tüm ağacı yeniden render etmesiyle bedavaya geliyordu — Flutter'da
/// `showDialog` ile açılan bir route ebeveyn rebuild'inden otomatik
/// haberdar olmadığından, açık dialog içeriği `ListenableBuilder` ile bu
/// nesneyi dinleyerek taze kalıyor).
class _ChatState extends ChangeNotifier {
  List<ChatMessage> messages = const [];
  Set<String> mutedUserIds = const {};
  Set<String> reportedUserIds = const {};
  int unreadCount = 0;
  ChatMessage? newMessagePopup;

  void update({
    List<ChatMessage>? messages,
    Set<String>? mutedUserIds,
    Set<String>? reportedUserIds,
    int? unreadCount,
    Object? newMessagePopup = _unset,
  }) {
    if (messages != null) this.messages = messages;
    if (mutedUserIds != null) this.mutedUserIds = mutedUserIds;
    if (reportedUserIds != null) this.reportedUserIds = reportedUserIds;
    if (unreadCount != null) this.unreadCount = unreadCount;
    if (!identical(newMessagePopup, _unset)) {
      this.newMessagePopup = newMessagePopup as ChatMessage?;
    }
    notifyListeners();
  }
}

const _unset = Object();

/// Web'in `refresh()` döngüsündeki periyodik taraması — ekran açık kalıp
/// hiçbir hamle/foreground olayı olmazsa zaman aşımı hiç taranmaz.
const Duration _periodicRefresh = Duration(minutes: 10);

/// Masaüstü/mobil ön plana dönüşte birden fazla olay (resume + online)
/// neredeyse aynı anda gelebilir — tek refresh'e indirger (web 1sn penceresi).
const Duration _foregroundDebounce = Duration(seconds: 1);

class OnlineGameScreen extends StatefulWidget {
  final OnlineGame game;
  final String myUserId;
  final OnlineGamesRepo onlineGames;
  final WordSource words;
  final MeaningStore? meanings;
  final AuthService? auth;
  final StatsRepo? stats;
  final Future<GamesRepo>? games;
  final FeedbackRepo? feedback;
  final FriendsRepo? friends;

  /// Oyun içi mesajlaşma — null iken Board footer'ında "Mesajlaşma" hiç
  /// çizilmez (Supabase yapılandırılmamış — teorik olarak bu ekrana hiç
  /// gelinemez, ama testler/önizlemeler için güvenlik ağı).
  final ChatRepo? chat;

  /// "Son görülen mesaj" damgası + "sohbet tanıtımını gördü mü" bayrağı
  /// için — null ise (test ortamı) ikisi de kalıcı olmadan çalışır
  /// (her açılışta tanıtım gösterilir, okunmamış sayacı hep 0'dan başlar).
  final Future<AppStorage>? storage;

  /// k-lig kutlama banner'ı — oyun SÜRERKEN bastırılır; oyun bitince
  /// (sunucu `games` satırlarını bitişle aynı transaction'da yazdığından)
  /// host kendiliğinden kontrol edip bekleyen kutlamayı gösterir. Web'in
  /// `<LeagueRewardsHost suppress={!state.isGameOver} />` mount'u.
  final LeagueRewardsRepo? leagueRewards;

  /// Bağlantı durumu — Board alt şeridindeki "Çevrimdışı" uyarısı için
  /// (web'de `Board.tsx` bunu `useOnlineStatus()` ile kendi içinde okuyor).
  final OnlineStatus? onlineStatus;

  const OnlineGameScreen({
    super.key,
    required this.game,
    required this.myUserId,
    required this.onlineGames,
    required this.words,
    this.meanings,
    this.auth,
    this.stats,
    this.games,
    this.feedback,
    this.friends,
    this.chat,
    this.storage,
    this.leagueRewards,
    this.onlineStatus,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

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
  final bool enabled;
  bool moved = false;
  _DragRef({required this.source, required this.start, required this.enabled});
}

class _Ghost {
  final Offset global;
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

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with WidgetsBindingObserver {
  /// Koltuk indeksi POZİSYONELDİR: `slots` dizisindeki sıra = oyuncunun
  /// koltuğu. Bu yüzden dizinin uzunluğu `playerCount` ile birebir olmak
  /// ZORUNDA — aşağıdaki nöbetçi bunu kontrol ediyor.
  late final int _mySlot = widget.game.slots
      .indexWhere((s) => !s.isAi && s.userId == widget.myUserId);
  late final GameController _controller = GameController(
    words: widget.words,
    // YZ'nin hamlesi SUNUCUDA hesaplanır (play-ai-turn) — istemci asla
    // yerel bir AI_PLAY dispatch etmemeli, yoksa iki taraf ayrışır.
    autoPlayAi: false,
    // Sıra bende olmasa da düzenleme yapabildiğimden (canEdit) reducer'ın
    // yerel action'ları BENİM koltuğum üzerinden işlemeli.
    actingSeat: _mySlot,
  );

  GameState get state => _controller.state;

  /// Hamle geçmişi ekranlarına verilecek state — web `OnlineGameScreen.tsx`'in
  /// `historyState`inin birebir karşılığı.
  ///
  /// Canlı oyunda reducer'ın `moveHistory`si BOŞTUR (hamleler sunucudan
  /// `online_game_moves` ile geliyor, `SyncOnlineStateAction` geçmişi
  /// taşımıyor) — geçmişi gösteren HER çağrı yeri bu getter'ı kullanmalı,
  /// ham `state`i DEĞİL. Tahta altındaki "Hamleler" linki bunu baştan doğru
  /// yapıyordu, oyun sonu modalı yapmıyordu (14 Ağustos 2026, cihaz testi).
  GameState get _historyState =>
      state.copyWith(moveHistory: buildMoveHistory(_moves));

  bool _loaded = false;

  /// İlk yükleme sunucuya ulaşamadı — "Yükleniyor…" yerine ne olduğunu
  /// anlatan panel gösterilir (bkz. `_refresh`).
  bool _loadFailed = false;
  bool _busy = false;

  /// SON gönderim denememin sonucu — reducer'ın `state.message`'ından AYRI
  /// (web `OnlineGameScreen.tsx` `submitError`; oradaki uzun gerekçe geçerli).
  ///
  /// Özet: `myTurnNote` "geçerli taslak + sıra sende" iken mesaj satırını
  /// koşulsuz türetiyor. Hamle reddedilince taşlar tahtada kaldığından taslak
  /// hâlâ geçerli oluyor ve `_setMessage` ile yazılan hata hiçbir zaman
  /// görünmüyordu — uçak modunda OYNA "GÖNDERİLİYOR" deyip sessizce eski
  /// hâline dönüyordu (14 Ağustos 2026, cihaz testi). Hata bayat değil,
  /// kullanıcının az önce bastığı butonun sonucu.
  String? _submitError;

  /// Taslağın imzası — değiştiği an [_submitError] geçmişe aittir.
  String get _placedSignature {
    final parts = [
      for (final e in state.placed.entries)
        '${e.key}:${e.value.letter}${e.value.wildLetter ?? ''}'
    ]..sort();
    return parts.join('|');
  }

  String? _lastPlacedSignature;
  List<OnlineMoveRow> _moves = const [];
  bool _gameOverShown = false;

  // Web aiTriggeringRef/timeoutCheckingRef: aynı sekmenin ardışık
  // refresh'lerinin henüz sonuçlanmamış aynı isteği tekrar tetiklemesini
  // önler (repo çağrıları 20sn tavanlı, bayrak sonsuza dek asılı kalamaz).
  bool _aiTriggering = false;
  bool _timeoutChecking = false;

  void Function()? _unsubscribe;
  Timer? _periodic;
  DateTime? _lastForeground;

  // ── Sürükle-bırak (game_screen.dart ile bilinçli aynı; bkz. dosya başı —
  // performans düzeltmesi de dahil, 8 Ağustos 2026, mobile/CLAUDE.md Parça 23)
  static const double _dragLift = 30;
  // Sürükleme eşiği — web'deki DRAG_THRESHOLD_MOUSE/DRAG_THRESHOLD_TOUCH ile
  // BİREBİR aynı (gerekçe: `src/App.tsx`). Fare ile parmak aynı değeri
  // kullanamaz; 6px'lik tek eşik altında hafif titreyen bir dokunuş
  // "sürükleme" sayılıp sessizce hiçbir şey yapmıyordu.
  static const double _dragThresholdMouse = 6; // web DRAG_THRESHOLD_MOUSE
  static const double _dragThresholdTouch = 10; // web DRAG_THRESHOLD_TOUCH

  /// Bırakma anındaki karar eşiği — `game_screen.dart` ile aynı sayı ve
  /// aynı gerekçe (orada yazılı).
  static const double _tapSlopOnRelease = 24;
  static double _dragThresholdFor(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse ? _dragThresholdMouse : _dragThresholdTouch;
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _rackKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

  // ── Tahta yakınlaştırması (1.0.5) — game_screen.dart ile bilinçli aynı;
  // tasarımın tamamı board_zoom.dart'ta. ────────────────────────────────
  final BoardZoomController _zoom = BoardZoomController();
  final GlobalKey _viewportKey = GlobalKey();
  BoardPanRef? _panRef;

  /// Tahta dokunuş ADAYI: `_dragRef` yokken inen parmağın konumu. Eşik
  /// aşılırsa (pan/scroll/sürükleme) düşer; kalkışta hücre kutusu DIŞINA
  /// düşen dokunuşlar zoom'un çift dokunuş jestine sayılır.
  Offset? _boardTapDown;
  DateTime _swallowTapsUntil = DateTime.fromMillisecondsSinceEpoch(0);
  _DragRef? _dragRef;

  /// Sürüklenen kaynak — YALNIZCA eşik aşıldığında/bittiğinde değişir
  /// (game_screen.dart'taki `_hiddenSource` ile aynı gerekçe — kaynağı
  /// pointer-down anında değil, gerçek sürükleme başladığında gizle).
  _DragSource? _hiddenSource;

  /// Hover hedefi (`_Ghost.overKey`/`overValid`) HER pointer hareketinde
  /// değişir — `setState`'e değil bağımsız bir `ValueNotifier`'a yazılıyor,
  /// yalnızca küçük bir `ValueListenableBuilder` overlay'i bunu dinliyor
  /// (game_screen.dart'taki `_dragNotifier` ile birebir aynı düzeltme).
  final ValueNotifier<_Ghost?> _dragNotifier = ValueNotifier(null);

  // ── Oyun İçi Mesajlaşma (Faz 1 + 2) ─────────────────────────────────────
  final _chatState = _ChatState();
  void Function()? _unsubscribeChat;
  bool _chatOpen = false;
  bool _popupDialogActive = false;

  List<ChatParticipant> get _chatParticipants => [
        for (var i = 0; i < widget.game.slots.length; i++)
          if (!widget.game.slots[i].isAi && widget.game.slots[i].userId != null)
            ChatParticipant(
              userId: widget.game.slots[i].userId!,
              name: widget.game.slots[i].name ?? 'Oyuncu',
              avatarUrl: widget.game.slots[i].avatarUrl,
              // Renk sunucudaki güncel `state.players`'tan — koltuk indeksi
              // `game.slots` ile `state.players` arasında AYNIDIR (web notu).
              colorIndex:
                  i < state.players.length ? state.players[i].colorIndex : i,
            ),
      ];

  @override
  void initState() {
    super.initState();
    // NÖBETÇİ (27 Ağustos 2026) — 27 Ağustos'ta `list_my_online_games` bir
    // slotu ÇOĞALTIYORDU (`friend_requests` karşılıklı çift → `jsonb_agg`
    // aynı slotu iki kez yazıyordu) ve sonraki TÜM koltuk indeksleri
    // kayıyordu: oyuncu KENDİ köşesine taş koyamıyor, BAŞKASININ köşesine
    // koyunca "geçerli" görüyor ama OYNA pasif kalıyordu (sunucu ham
    // `og.slots`'u okuduğundan doğru koltuğu biliyor — pasif kalması DOĞRU
    // yarısıydı). Hata SESSİZDİ: hiçbir yerde iz bırakmadı, teşhis elle SQL
    // koşularak yapıldı. RPC düzeltildi; bu kontrol tekrarını GÖRÜNÜR kılar.
    if (widget.game.slots.length != widget.game.playerCount) {
      errorReporter.report(
        StateError('online_game slots uzunluğu playerCount ile uyuşmuyor: '
            '${widget.game.slots.length} != ${widget.game.playerCount} '
            '(oyun ${widget.game.id})'),
        context: 'online_game.slot_count_mismatch',
      );
    }
    if (_mySlot < 0) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _unsubscribe =
        widget.onlineGames.subscribeGame(widget.game.id, () => _refresh());
    _periodic = Timer.periodic(_periodicRefresh, (_) => _refresh());
    unawaited(_loadChat());
    // Platform telemetrisi — bu oyunda BU kullanıcının hangi istemciden
    // (ios/android/app-web) oynadığını oyun başına bir kez yazar. Yerelde bu
    // bilgi `games.platform` ile gidiyor ama Canlı'da o satırı sunucu
    // yazdığından istemci oraya hiç ulaşamıyor; mobil lansmanı ölçülebilsin
    // diye ayrı bir tablo kullanılıyor (web `setOnlineGamePlatform` ile aynı).
    // BİLEREK `_refresh()` döngüsünün DIŞINDA: telemetri, oyun durumu
    // senkronuyla aynı kod yolunu paylaşmamalı (hatası oyunu etkilemesin) ve
    // her Realtime olayında tekrar yazmanın anlamı yok — upsert olduğundan
    // mükerrer çağrı zararsız, sadece gereksiz.
    unawaited(widget.onlineGames.reportPlatform(widget.game.id));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Web'in `clearStuckDrag`i (OnlineGameScreen.tsx — `visibilitychange`/
    // `blur`) porta hiç girmemişti: sürükleme ORTASINDA arka plana alınırsa
    // `PointerUpEvent` bir daha hiç gelmeyebiliyor ve `_dragRef` asılı
    // kalıyor — sayfa `NeverScrollableScrollPhysics`te kilitli kalıyor
    // (bkz. mobile/CLAUDE.md, Parça 58).
    if (lifecycle != AppLifecycleState.resumed && _dragRef != null) {
      _cancelTileDrag();
    }
    // Arka planda websocket askıya alınabildiğinden (özellikle iOS) o sırada
    // gelen bir hamle olayı sessizce kaçırılır — Realtime canlı bir akış,
    // kaçırılan olayı tekrar oynatmaz. Ön plana dönüşte emniyet senkronu.
    if (lifecycle != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    final last = _lastForeground;
    if (last != null && now.difference(last) < _foregroundDebounce) return;
    _lastForeground = now;
    unawaited(_refresh());
    unawaited(_fetchChat());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodic?.cancel();
    _unsubscribe?.call();
    _unsubscribeChat?.call();
    _controller.dispose();
    _chatState.dispose();
    _dragNotifier.dispose();
    _zoom.dispose();
    super.dispose();
  }

  // ── Oyun İçi Mesajlaşma — veri yükleme + Realtime ────────────────────────

  /// `online_game_states`'in aboneliğinden BAĞIMSIZ ayrı bir kanal (farklı
  /// tablo) — ilk yükte tüm sohbeti + mute/rapor setlerini çeker, sonrasında
  /// yeni mesajları INSERT olayıyla dinler (web'in aynı ayrımı).
  Future<void> _loadChat() async {
    await _fetchChat();
    final chat = widget.chat;
    if (chat == null || _mySlot < 0 || !mounted) return;
    _unsubscribeChat = chat.subscribe(widget.game.id, _onChatMessage);
  }

  /// Yalnızca VERİYİ tazeler — aboneliğe dokunmaz, bu yüzden ön plana
  /// dönüşte tekrar tekrar çağrılabilir.
  ///
  /// Oyun state'i üç yoldan kurtarılıyordu (Realtime + periyodik + resume,
  /// bkz. `didChangeAppLifecycleState`) ama sohbet YALNIZCA Realtime'a
  /// bağlıydı; oysa kaçırılan olayın kalıcı kaybolması iki tablo için de
  /// geçerli. Arka planda websocket askıya alınınca gelen mesaj hiç
  /// görünmüyor, tek çare ekrandan çıkıp girmekti — kullanıcı bunu iki
  /// cihazla yazışırken bildirdi (14 Ağustos 2026). Popup BİLEREK
  /// tetiklenmiyor (yalnızca `_onChatMessage` açar): arka planda biriken beş
  /// mesaj için beş popup değil, tek bir okunmamış rozeti.
  Future<void> _fetchChat() async {
    final chat = widget.chat;
    if (chat == null || _mySlot < 0) return;
    final results = await Future.wait([
      chat.myMutes(),
      chat.myActiveReports(),
      chat.messages(widget.game.id),
    ]);
    if (!mounted) return;
    final mutes = results[0] as Set<String>;
    final reported = results[1] as Set<String>;
    final rows = results[2] as List<OnlineGameMessageRow>?;
    final msgs = [
      for (final r in rows ?? const <OnlineGameMessageRow>[])
        ChatMessage(
            id: r.id,
            senderUserId: r.senderUserId,
            message: r.message,
            createdAt: r.createdAt),
    ];
    _chatState.update(
        messages: msgs, mutedUserIds: mutes, reportedUserIds: reported);
    await _seedInitialUnread(msgs);
  }

  /// Bu cihazda bu oyun için "en son okunan mesaj" damgası hiç yoksa (özellik
  /// yeni devreye girdi ya da bu cihazda ilk kez açılıyor), mevcut TÜM
  /// geçmişi "okunmamış" saymak yanlış pozitif üretir — damga mevcut son
  /// mesaja (yoksa şimdiye) oturtulup okunmamış sayaç 0'da kalır; kırmızı
  /// nokta yalnızca BUNDAN SONRA gelecek gerçek yeni mesajlar için çıkar
  /// (web `getChatLastReadAt`/`markChatRead` ilk-ziyaret düzeltmesi).
  Future<void> _seedInitialUnread(List<ChatMessage> msgs) async {
    final storageFuture = widget.storage;
    final store = storageFuture == null ? null : (await storageFuture).chatRead;
    final lastReadMs =
        store == null ? null : await store.lastReadAt(widget.game.id);
    if (lastReadMs == null) {
      final seedMs = msgs.isEmpty
          ? DateTime.now().millisecondsSinceEpoch
          : msgs
              .map((m) => DateTime.parse(m.createdAt).millisecondsSinceEpoch)
              .reduce((a, b) => a > b ? a : b);
      await store?.markRead(widget.game.id, seedMs);
      if (mounted) _chatState.update(unreadCount: 0);
      return;
    }
    // Sessize alma kırmızı noktayı ETKİLEMEZ (15 Ağustos 2026, kullanıcı
    // kararı) — mute yalnızca POPUP'ı bastırır. Gerekçe: oyunu bölen ve taciz
    // vektörü olan şey popup; alttaki nokta rahatsız etmiyor ve kullanıcı
    // susturduğu kişinin ne yazdığını görmek isteyebilir (şikayet için bile).
    // Mute seti bu yüzden buraya artık hiç geçmiyor; çağıran onu yalnızca
    // rozetler (🚫/🚩) ve popup kapısı için yüklemeye devam ediyor.
    final unread = msgs
        .where((m) =>
            m.senderUserId != widget.myUserId &&
            DateTime.parse(m.createdAt).millisecondsSinceEpoch > lastReadMs)
        .length;
    if (mounted) _chatState.update(unreadCount: unread);
  }

  void _onChatMessage(OnlineGameMessageRow row) {
    if (!mounted) return;
    if (_chatState.messages.any((m) => m.id == row.id)) return;
    final msg = ChatMessage(
        id: row.id,
        senderUserId: row.senderUserId,
        message: row.message,
        createdAt: row.createdAt);
    _chatState.update(messages: [..._chatState.messages, msg]);

    if (_chatOpen) {
      unawaited(_markChatReadTo(row.createdAt));
      return;
    }
    // Nokta HER gönderen için artar; popup yalnızca susturulmamış kişiler
    // için açılır (bkz. _seedInitialUnread'deki gerekçe).
    _chatState.update(unreadCount: _chatState.unreadCount + 1);
    if (_chatState.mutedUserIds.contains(row.senderUserId)) return;
    _chatState.update(newMessagePopup: msg);
    if (!_popupDialogActive) unawaited(_showNewMessagePopup());
  }

  Future<void> _markChatReadTo(String iso) async {
    final storageFuture = widget.storage;
    if (storageFuture == null) return;
    final store = (await storageFuture).chatRead;
    await store.markRead(
        widget.game.id, DateTime.parse(iso).millisecondsSinceEpoch);
  }

  /// Sohbet penceresini açar — web `handleOpenMessaging`: tanıtımı hiç
  /// görmediyse önce kısa bir hoşgeldin diyaloğu (web `showChatIntro`).
  Future<void> _openMessaging() async {
    final storageFuture = widget.storage;
    final flags = storageFuture == null ? null : (await storageFuture).flags;
    if (!mounted) return;
    if (flags != null && !flags.seenChatIntro) {
      // Tek butonlu kart — web'de de buton TAM GENİŞLİK (showKInfo).
      await showKInfo(
        context,
        title: 'Oyun içi mesajlaşmaya hoşgeldiniz!',
        message: 'Buradan gruba mesaj atabilirsiniz. Mesaj herkesin ekranında '
            'popup şeklinde gözükür. Haydi, ilk mesajını gönder!',
        buttonLabel: 'DEVAM',
      );
      if (!mounted) return;
      await flags.markChatIntroSeen();
    }
    _openChatModal();
  }

  void _openChatModal() {
    setState(() => _chatOpen = true);
    _chatState.update(unreadCount: 0);
    final latest = _chatState.messages.isEmpty
        ? DateTime.now().toUtc().toIso8601String()
        : _chatState.messages
            .reduce((a, b) => a.createdAt.compareTo(b.createdAt) > 0 ? a : b)
            .createdAt;
    unawaited(_markChatReadTo(latest));
    showDialog<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: _chatState,
        builder: (context, _) => ChatModal(
          messages: _chatState.messages,
          participants: _chatParticipants,
          myUserId: widget.myUserId,
          onSend: (text) => widget.chat!.send(widget.game.id, text),
          onOpenSettings: () => _openChatSettings(null),
          mutedUserIds: _chatState.mutedUserIds,
          reportedUserIds: _chatState.reportedUserIds,
          onOpenParticipantSettings: (id) => _openChatSettings(id),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _chatOpen = false);
    });
  }

  void _openChatSettings(String? initialParticipantId) {
    showDialog<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: _chatState,
        builder: (context, _) => ChatSettingsModal(
          gameId: widget.game.id,
          chat: widget.chat!,
          participants: [
            for (final p in _chatParticipants)
              if (p.userId != widget.myUserId) p
          ],
          mutedUserIds: _chatState.mutedUserIds,
          reportedUserIds: _chatState.reportedUserIds,
          initialParticipantId: initialParticipantId,
          onMuteChange: (targetUserId, muted) {
            final next = Set<String>.of(_chatState.mutedUserIds);
            muted ? next.add(targetUserId) : next.remove(targetUserId);
            _chatState.update(mutedUserIds: next);
          },
          onReported: (targetUserId) {
            // Rapor otomatik olarak hedefi de sessize alır (sunucu tarafı).
            final nextReported = Set<String>.of(_chatState.reportedUserIds)
              ..add(targetUserId);
            final nextMuted = Set<String>.of(_chatState.mutedUserIds)
              ..add(targetUserId);
            _chatState.update(
                reportedUserIds: nextReported, mutedUserIds: nextMuted);
          },
          onWithdrawn: (targetUserId) {
            final next = Set<String>.of(_chatState.reportedUserIds)
              ..remove(targetUserId);
            _chatState.update(reportedUserIds: next);
          },
        ),
      ),
    );
  }

  /// Yeni mesaj popup'ı — kapalıyken gelen bir mesajı gösterir. Popup
  /// AÇIKKEN bir mesaj daha gelirse yeni bir dialog route AÇILMAZ, aynı
  /// (Listenable ile canlı) dialog içeriği güncellenir (web'in tek
  /// `newMessagePopup` state alanının davranışı).
  Future<void> _showNewMessagePopup() async {
    _popupDialogActive = true;
    final result = await showDialog<String>(
      context: context,
      // Web'de bu popup'ın zemini TIKLANAMAZ (`fixed inset-0` kabında hiç
      // `onClick` yok) — kapatmanın tek yolu ✕ / CEVAP VER / KAPAT.
      // Flutter'ın varsayılanı ise `barrierDismissible: true`, yani ekranın
      // herhangi bir yerine dokunmak popup'ı kapatıyordu: kullanıcı için
      // bu, mesajın "kendiliğinden gidiyor" gibi görünmesi demek. İki
      // görünür buton olduğundan kapana kısılma riski YOK (bkz. Parça 85 —
      // ActionSheet'te zemin dokunuşu bilerek AÇIK bırakılmıştı, orada
      // aksiyonsuz çıkış için başka yol kalmıyordu).
      barrierDismissible: false,
      builder: (_) => ListenableBuilder(
        listenable: _chatState,
        builder: (context, _) {
          final popup = _chatState.newMessagePopup;
          final sender = popup == null
              ? null
              : _chatParticipants
                  .where((p) => p.userId == popup.senderUserId)
                  .firstOrNull;
          // Web'de başlık avatar + isim satırı (28px avatar, 14px kalın
          // isim), gövde düz mesaj metni, altta CEVAP VER (accent) + KAPAT.
          return KDialogCard(
            title: Row(children: [
              KAvatar(
                  url: sender?.avatarUrl,
                  name: sender?.name ?? 'Oyuncu',
                  size: 28),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(sender?.name ?? 'Oyuncu',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: kText))),
            ]),
            content: Text(popup?.message ?? '', style: kDialogBodyStyle),
            actions: [
              kDialogButton(
                label: 'CEVAP VER',
                variant: NeoButtonVariant.accent,
                onPressed: () => Navigator.of(context).pop('reply'),
              ),
              kDialogButton(
                label: 'KAPAT',
                onPressed: () => Navigator.of(context).pop('close'),
              ),
            ],
          );
        },
      ),
    );
    _popupDialogActive = false;
    final closedPopup = _chatState.newMessagePopup;
    _chatState.update(unreadCount: 0, newMessagePopup: null);
    if (closedPopup != null) {
      unawaited(_markChatReadTo(closedPopup.createdAt));
    }
    if (result == 'reply' && mounted) _openChatModal();
  }

  Future<void> _refresh() async {
    if (_mySlot < 0) return;
    final snap = await widget.onlineGames.loadGame(widget.game.id);
    if (!mounted) return;
    if (snap == null) {
      // Sunucuya ulaşılamadı. Zaten yüklenmiş bir ekran varsa ona
      // DOKUNMUYORUZ (bayat veri, hiç veriden iyidir) — ama ilk yüklemede
      // korunacak bir şey YOK ve ekran sonsuz "Yükleniyor…"da asılı
      // kalıyordu (14 Ağustos 2026, cihaz testi: uçak modunda listeden
      // Canlı bir oyuna dokunmak).
      if (!_loaded) setState(() => _loadFailed = true);
      return;
    }
    final turnAdvanced = snap.state.turnCount > state.turnCount;
    _controller.dispatch(SyncOnlineStateAction(
      publicState: snap.state,
      myRack: snap.myRack,
      mySlotIndex: _mySlot,
    ));
    // Rakip AYNI ANDA oynadıysa reducer'ın `turnAdvanced` dalı deneme
    // taşlarını rafa geri döndürüp rafı sunucudakiyle değiştiriyor — yani
    // sürüklenen kaynak (tahtadaki taslak taş ya da rafın o slotu) artık
    // ilk seçildiği şey olmayabilir. Sürüklemeyi burada bitirmezsek hayalet
    // taş silinmiş bir taslağı göstermeye devam eder. Kullanıcı gerçek bir
    // oyunda tam bunu bildirdi (bkz. mobile/CLAUDE.md, Parça 58).
    if (turnAdvanced && _dragRef != null) _cancelTileDrag();
    setState(() {
      _moves = snap.moves;
      _loaded = true;
      _loadFailed = false;
    });

    if (snap.state.isGameOver) return;

    // YZ turunu tetiklemenin TEK yolu burası (web kararı): sıra bir YZ
    // koltuğuna geçtiği an, o değişikliği yapan oyuncunun ekranı zaten
    // abone olduğundan kendi hamlesinin Realtime yankısı bunu hemen
    // çalıştırır. Birden fazla istemci tetiklese de submit_move'un satır
    // kilidi çifte oynamayı engelliyor.
    final cur = snap.state.current;
    final currentSlot = (cur >= 0 && cur < widget.game.slots.length)
        ? widget.game.slots[cur]
        : null;
    if (currentSlot != null && currentSlot.isAi && !_aiTriggering) {
      _aiTriggering = true;
      widget.onlineGames
          .triggerAiTurn(widget.game.id)
          .catchError((Object e) => debugPrint('[Kelimeki] YZ turu: $e'))
          .whenComplete(() => _aiTriggering = false);
    }

    // Sırası gelenin 48 saatlik süresi dolduysa otomatik teslim (dolmadıysa
    // no-op) — herhangi bir katılımcının ekranı açıkken taraması, oyunun
    // kalıcı asılı kalmasını önler.
    if (!_timeoutChecking) {
      _timeoutChecking = true;
      widget.onlineGames
          .sweepTurnTimeout(widget.game.id)
          .catchError((Object e) => debugPrint('[Kelimeki] süre taraması: $e'))
          .whenComplete(() => _timeoutChecking = false);
    }
  }

  // ── Politika ────────────────────────────────────────────────────────────

  Player? get _me => (_mySlot >= 0 && _mySlot < state.players.length)
      ? state.players[_mySlot]
      : null;

  /// Sunucuya GÖNDERİM yapan eylemler (OYNA/PAS GEÇ/DEĞİŞTİR) — gerçekten
  /// sıra bende mi.
  bool get _canAct =>
      _loaded && !state.isGameOver && state.current == _mySlot && _me != null;

  /// Salt YEREL düzenleme (taş koy/geri al/karıştır) — sıra bende olmasa da
  /// serbest: rakibi/YZ'yi beklerken kelime denemek (web "egzersiz" kararı).
  /// Rakip oynayınca SYNC_ONLINE_STATE'in turnAdvanced dalı deneme taşlarını
  /// rafa geri döndürür.
  bool get _canEdit => _loaded && !state.isGameOver && _me != null;

  bool get _isAiTurn {
    if (_canAct || state.isGameOver) return false;
    final cur = state.current;
    if (cur < 0 || cur >= widget.game.slots.length) return false;
    return widget.game.slots[cur].isAi;
  }

  String get _currentName {
    final cur = state.current;
    if (cur < 0 || cur >= state.players.length) {
      return _isAiTurn ? 'Yapay Zeka' : 'Rakip';
    }
    return state.players[cur].name;
  }

  PlayerColor _colorOf(int i) =>
      playerColors[state.players[i].colorIndex % playerColors.length];

  /// Web `moveStatus` — köşe/ilk-hamle kontrolleri HER ZAMAN benim koltuğuma
  /// göre (sıra bende olmasa da doğru geri bildirim), bu yüzden `current`
  /// geçici olarak sabitlenmiş bir kopya üzerinden hesaplanır.
  MoveStatus? get _moveStatus => _mySlot < 0
      ? null
      : computeMoveStatus(state.copyWith(current: _mySlot), widget.words);

  /// `online_game_states` mesaj taşımaz (SYNC her senkronda siler) — yerel
  /// oyundaki gibi anlamlı bir satır göstermek için son hamle
  /// `online_game_moves`'tan reducer'ın AYNI şablonlarıyla metne çevrilir.
  ({String text, MessageKind kind}) get _lastMoveMessage {
    if (_moves.isEmpty) {
      final starter = state.players.isEmpty ? '' : state.players[0].name;
      return (
        text: '$starter, kendi köşenden bir kelime kur.',
        kind: MessageKind.none
      );
    }
    final row = _moves.last;
    final mover =
        (row.playerIndex >= 0 && row.playerIndex < state.players.length)
            ? state.players[row.playerIndex].name
            : 'Oyuncu';
    switch (row.action) {
      case 'pass':
        return (text: '$mover pas geçti.', kind: MessageKind.warn);
      case 'exchange':
        return (
          text: '$mover ${row.tileCount} taş değiştirdi ve sırasını kullandı.',
          kind: MessageKind.warn
        );
      case 'surrender':
        return (text: '$mover teslim oldu.', kind: MessageKind.warn);
    }
    final finishBonus = jokerFinishBonus(row.finishJokerCount);
    final finishNote =
        finishBonus > 0 ? ' (jokerli bitiş bonusu +$finishBonus)' : '';
    // Bingo notu — reducer'ın PLAY şablonuyla BİREBİR aynı olmak zorunda
    // (bkz. kelimeki_core/lib/src/engine/reducer.dart). Bayrak zaten satırda
    // geliyor; `bingoBonus` puanı `row.points`'in içinde, not onu açıklıyor.
    final bingoNote = row.bingo ? ' (Bingo bonusu +$bingoBonus)' : '';
    final shares = row.lostShares;
    final bonusNote = shares.isEmpty
        ? ''
        : ' (${shares.map((s) => '${s.amount} puanı ${s.to >= 0 && s.to < state.players.length ? state.players[s.to].name : 'Oyuncu'} kaptı').join(', ')})';
    final pts = row.points - finishBonus;
    return (
      text:
          '$mover: +$pts puan$bonusNote$bingoNote$finishNote Kelimeler: ${row.words.join(', ')}',
      kind: MessageKind.ok
    );
  }

  // ── Eylemler ────────────────────────────────────────────────────────────

  // `_setMessage` kaldırıldı (14 Ağustos 2026): bu ekranın YAZDIĞI her mesaj
  // bir gönderim/doğrulama sonucuydu ve hepsi artık `_submitError`e gidiyor.
  // `state.message` yalnızca reducer'ın kendi anlatımını taşıyor.

  Future<void> _handlePlay() async {
    final me = _me;
    // `state.placed.isEmpty` BİLEREK burada YOK: boş taslakta sessizce
    // dönmek, bir alttaki `validatePlacement`ın ürettiği "Harf
    // yerleştirilmedi." mesajını ulaşılamaz kılardı (web'de o mesaj
    // görünüyor). Yerel ekranın karşılığı reducer'ın PLAY dalı.
    if (!_canAct || _busy || me == null) return;

    // Tek yerel doğrulama — web'in structural+remote iki adımının mobil
    // karşılığı (bkz. dosya başındaki "bilinçli sapma" notu).
    final pinned = state.copyWith(current: _mySlot);
    final result = validatePlacement(state.board, state.placed, _mySlot,
        me.corners, isFirstMove(pinned), widget.words);
    if (!result.valid) {
      setState(() => _submitError = result.reason ?? 'Geçersiz hamle.');
      return;
    }

    final basePts = calcScore(state.board, state.placed, state.bonuses);
    final placedCoords = [for (final k in state.placed.keys) parseKey(k)];
    final split = computeInvasionSplit(
        placedCoords, _mySlot, state.players, basePts, state.board);

    if (split.shares.isNotEmpty) {
      final ok = await showInvasionConfirm(context,
          score: basePts, shares: split.shares, players: state.players);
      if (!ok || !mounted) return;
    }

    final wordScores =
        calcWordRawScores(state.board, state.placed, state.bonuses);
    final placements = [
      for (final e in state.placed.entries)
        () {
          final (r, c) = parseKey(e.key);
          return <String, Object?>{
            'r': r,
            'c': c,
            'letter': e.value.letter,
            if (e.value.wild) 'wild': true,
            if (e.value.wildLetter != null) 'wildLetter': e.value.wildLetter,
          };
        }(),
    ];

    setState(() => _busy = true);
    try {
      await widget.onlineGames.submitMove(
        gameId: widget.game.id,
        action: 'play',
        placements: placements,
        words: result.words ?? const [],
        wordScores: [for (final w in wordScores) w.toJson()],
        basePoints: basePts,
        lostShares: [
          for (final s in split.shares) {'to': s.index, 'amount': s.amount}
        ],
      );
    } catch (e) {
      if (mounted) setState(() => _submitError = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePass() async {
    if (!_canAct || _busy) return;
    final ok = await showKConfirm(
      context,
      title: 'Pas Geçiyorsun!',
      message: 'Pas geçmek istediğinden emin misin? Sıran diğer oyuncuya geçer.',
      confirmLabel: 'PAS GEÇ',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onlineGames
          .submitMove(gameId: widget.game.id, action: 'pass');
    } catch (e) {
      if (mounted) setState(() => _submitError = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Oyun bitince OYNA'nın yerini alan "TEKRAR OYNA": onay → biten oyunun
  /// kadrosuyla (bkz. `rematchSlots`) yeni bir Canlı oyun → insan koltuklarına
  /// davet gider (`create_online_game` + `notify-game-invite`). Sunucu reddi
  /// (ör. artık arkadaş değilsiniz) olduğu gibi gösterilir.
  Future<void> _handleRematch() async {
    if (_busy) return;
    final names = [
      for (final s in widget.game.slots)
        if (!s.isAi && s.userId != widget.myUserId)
          s.name ?? 'Bir arkadaşın'
    ];
    final withAi = widget.game.slots.any((s) => s.isAi);
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
    setState(() => _busy = true);
    String? error;
    try {
      await widget.onlineGames.create(
        widget.game.playerCount,
        rematchSlots(widget.game, widget.myUserId),
      );
    } catch (e) {
      // LiveGameCreateForm ile AYNI helper: `create_online_game`in Türkçe
      // reddini (PostgrestException.message) ham `toString()` gürültüsü
      // olmadan gösterir.
      error = friendErrorText(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await showKInfo(
      context,
      title: 'Tekrar Oyna',
      message: error ??
          'Davetiniz gönderilmiştir.\n\n'
              '${names.join(', ')} yanıt verince oyun başlayacak.'
              '${withAi ? ' 4. koltuk Yapay Zeka.' : ''}',
      // web'de bu iki durum AYRI dallar: gönderim başarılıysa "Tamam",
      // sunucu reddettiyse "Kapat" (OnlineGameScreen.tsx, `sent` vs `error`
      // fazı). Port ikisini tek diyalogda birleştirdiğinden etiket içeriğe
      // göre seçiliyor.
      buttonLabel: error == null ? 'TAMAM' : 'KAPAT',
    );
    // Başarıda listeye dön — yeni oyun "Rakip Bekleniyor" kovasında görünür.
    if (error == null && mounted) Navigator.of(context).pop();
  }

  Future<void> _handleConfirmSwap() async {
    final me = _me;
    if (!_canAct || _busy || me == null || state.swapSelection.isEmpty) return;
    // ⚠ Aynı sınıf yarış: `swapSelection` seçildiği andaki rafın
    // indeksleri. Aradan sunucudan bir durum güncellemesi geçtiyse (ör.
    // zaman aşımı teslimi) indeks sınır dışına düşebilir. Eksik harfle
    // göndermek YANLIŞ olurdu — o yüzden filtrelemiyoruz, gönderimi
    // İPTAL ediyoruz; kullanıcı güncel rafta yeniden seçer.
    if (state.swapSelection.any((i) => i < 0 || i >= me.rack.length)) return;
    final letters = [for (final i in state.swapSelection) me.rack[i].letter];
    setState(() => _busy = true);
    try {
      await widget.onlineGames.submitMove(
        gameId: widget.game.id,
        action: 'exchange',
        exchangeLetters: letters,
      );
      // Başarılı gönderimde swap modundan çık — sunucu senkronu zaten
      // rafı yenileyecek (web aynı sırayı izliyor).
      if (mounted) _controller.dispatch(const ToggleSwapModeAction());
    } catch (e) {
      if (mounted) setState(() => _submitError = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ağ katmanı hatası → ne olduğunu anlatan metin; sunucunun KENDİ reddi
  /// ("Sıra sende değil." gibi) olduğu gibi gösterilir (bkz.
  /// `util/offline_notice.dart`, web ile aynı ayrım).
  String _errorText(Object e) {
    if (isNetworkError(e)) return kOfflineMoveNotice;
    final msg = e.toString();
    return msg.isEmpty ? 'Hamle gönderilemedi.' : msg;
  }

  void _openPlayerCard(int index) {
    final stats = widget.stats;
    if (stats == null) return;
    if (index < 0 || index >= widget.game.slots.length) return;
    final slot = widget.game.slots[index];
    if (slot.isAi || slot.userId == null) return;
    unawaited(showPlayerScoreCard(
      context,
      stats: stats,
      userId: slot.userId!,
      name: slot.name ??
          (index < state.players.length ? state.players[index].name : 'Oyuncu'),
      avatarUrl: slot.avatarUrl,
      games: widget.games,
      friends: widget.friends,
      auth: widget.auth,
    ));
  }

  // ── Dokunuş/sürükleme (game_screen.dart ile bilinçli aynı) ──────────────

  Future<void> _tapPlacedTile(int r, int c, Tile placedTile) async {
    if (!_canEdit) return;
    // Taşa dokunuş çift BAŞLATAMAZ; joker penceresi ANINDA açılır —
    // gerekçe game_screen.dart'ın aynı dalında.
    _zoom.markUnpairableTap();
    if (placedTile.wild) {
      final choice = await showWildLetterSheet(context, editing: true);
      if (choice == null) return;
      if (choice.recallRequested) {
        _controller.dispatch(RecallCellAction(r: r, c: c));
      } else if (choice.letter != null) {
        _controller.dispatch(
            SetWildLetterAction(r: r, c: c, wildLetter: choice.letter!));
      }
    } else {
      _controller.dispatch(RecallCellAction(r: r, c: c));
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
    // Çift dokunuşla zoom — kapsam/gerekçe game_screen.dart'ın aynı
    // dalında: çiftin İKİNCİSİ yutulur, İLKİNİN yaptığı iş kalır; çift
    // yalnızca boş kareye dokunuşla başlar.
    if (state.board[r][c] == null) {
      if (_registerZoomTap(global)) return;
      if (state.placed[k] == null) _zoom.registerPairableTap(global);
    } else {
      _zoom.markUnpairableTap();
    }
    if (state.board[r][c] != null) {
      // Taslak hamle sürerken anlam penceresi AÇILMAZ, onun yerine
      // ıskalama kurtarma çalışır — gerekçe ve kullanıcının bildirimi
      // `game_screen.dart`'ın aynı dalında (iki ekran deseni paylaşıyor).
      if (state.placed.isNotEmpty) {
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
      await _tapPlacedTile(r, c, placedTile);
      return;
    }
    if (!_canEdit || state.swapMode) return;

    // BOŞ hücreye ıskalayan dokunuş da kurtarılır — YALNIZCA seçim yokken
    // (`game_screen.dart`'taki aynı gerekçe ve aynı dar koşul; 27 Ağustos
    // 2026, kullanıcı: *"tahtaya konan taşı kaldırmak için ilk tıklama
    // yakalamıyor"*). Seçili taş varken davranış DEĞİŞMEZ, yoksa kelimeyi
    // dizerken komşu hücreye harf koymak zorlaşırdı.
    if (state.selectedTile == null && state.placed.isNotEmpty) {
      final hedef = _nearbyDraftCell(r, c, global);
      if (hedef != null) {
        await _tapPlacedTile(
            hedef.$1, hedef.$2, state.placed[cellKey(hedef.$1, hedef.$2)]!);
        return;
      }
    }

    final me = _me!;
    final selIdx = state.selectedTile;
    final sel = (selIdx != null && selIdx >= 0 && selIdx < me.rack.length)
        ? me.rack[selIdx]
        : null;
    if (sel != null && sel.letter == '?') {
      // Joker penceresi ANINDA açılır, zoom'la ilişkisi yok — gerekçe
      // game_screen.dart'ın aynı dalında. Modal açıldı → zincir kır.
      _zoom.markUnpairableTap();
      final choice = await showWildLetterSheet(context);
      if (choice?.letter == null) return;
      _controller
          .dispatch(PlaceTileAction(r: r, c: c, wildLetter: choice!.letter));
      return;
    }
    _controller.dispatch(PlaceTileAction(r: r, c: c));
  }

  /// Çift dokunuş kontrolü — game_screen.dart'taki eşinin aynısı.
  bool _registerZoomTap(Offset global) {
    if (clock.now().isBefore(_swallowTapsUntil)) return true;
    if (!_zoom.tryCompletePair(global)) return false;
    _toggleZoomAt(global);
    return true;
  }

  void _toggleZoomAt(Offset global) {
    final grid = _boxOf(_gridKey);
    if (grid == null) return;
    _zoom.toggleAt(grid.globalToLocal(global), grid.size);
  }

  RenderBox? _boxOf(GlobalKey key) =>
      key.currentContext?.findRenderObject() as RenderBox?;

  double _liftedY(double y) {
    // Görünür kare varsa ONUN üstüne kırp (zoom — bkz. game_screen.dart).
    final box = _boxOf(_viewportKey) ?? _boxOf(_gridKey);
    final lifted = y - _dragLift;
    if (box == null) return lifted;
    final top = box.localToGlobal(Offset.zero).dy;
    return lifted < top + 1 ? top + 1 : lifted;
  }

  (int, int)? _cellAtGlobal(Offset global) {
    final grid = _boxOf(_gridKey);
    if (grid == null) return null;
    // ZOOM KAPISI — gerekçe game_screen.dart'ın aynı dalında: görünür kare
    // dışına düşen nokta hücre DEĞİLDİR (raf-üstü bırakma tuzağı).
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
    if (source is _PlacedSource && source.r == r && source.c == c) return false;
    return state.board[r][c] == null && state.placed[cellKey(r, c)] == null;
  }

  // ── Tahta pan'i + kenar/boşluk dokunuşları — game_screen.dart ile aynı ─
  void _boardPointerDown(PointerDownEvent e) {
    if (_dragRef != null) return;
    // Dokunuş adayı: hücre dışına (boşluk/çerçeve) düşen dokunuşlar da
    // zoom jestine sayılır — gerekçe game_screen.dart'ın aynı dalında.
    _boardTapDown = e.position;
    if (!_zoom.zoomed || _panRef != null) return;
    setState(() => _panRef = BoardPanRef(e.position));
  }

  void _boardPointerMove(PointerMoveEvent e) {
    final down = _boardTapDown;
    if (down != null &&
        (e.position - down).distance >= _dragThresholdFor(e.kind)) {
      _boardTapDown = null;
    }
    final p = _panRef;
    if (p == null) return;
    if (!p.moved) {
      if ((e.position - p.start).distance < _dragThresholdFor(e.kind)) return;
      p.moved = true;
    }
    final grid = _boxOf(_gridKey);
    if (grid == null) return;
    _zoom.panBy(e.delta, grid.size);
  }

  void _boardPointerUp(PointerUpEvent e) {
    final down = _boardTapDown;
    _boardTapDown = null;
    _endBoardPan();
    if (down == null) return;
    // Karar İNİŞ noktasına göre: hücrenin tap tanıyıcısı jestin sahibi
    // olup olmadığına inişte karar verir — parmak hücrede inip boşlukta
    // kalkarsa hücre tanıyıcısı YİNE ateşler; burada kalkış noktasına
    // bakılsaydı aynı dokunuş iki kez sayılır, tek dokunuş "çift" olurdu.
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
      _swallowTapsUntil = clock.now().add(const Duration(milliseconds: 120));
      _zoom.markUnpairableTap();
    }
  }

  /// Hücrenin gerçek dokunma kutusu mu (boşluk/çerçeve hariç)? —
  /// game_screen.dart'taki eşinin aynısı, gerekçesi orada.
  bool _pointHitsCellBox(Offset global) {
    final grid = _boxOf(_gridKey);
    if (grid == null) return true;
    final local = grid.globalToLocal(global);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= grid.size.width ||
        local.dy >= grid.size.height) {
      return false;
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
    // (bkz. build() — sürükleme sırasında sayfa kaymasın diye, game_screen.dart
    // ile aynı düzeltme — bkz. mobile/CLAUDE.md).
    setState(() {
      _dragRef = _DragRef(
        source: source,
        start: e.position,
        // Yerel ekranın `canAct`i yerine `canEdit`: sıra bende olmasa da
        // sürükleyip deneyebilirim (swap modunda kapalı, web ile aynı).
        enabled: _canEdit && !state.swapMode,
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
      // gizlenir (game_screen.dart ile aynı düzeltme — bkz. orada).
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
    // BİLEREK setState DEĞİL (game_screen.dart ile aynı düzeltme — bkz.
    // orada, `_dragNotifier` notu).
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
      await _dokunusOlarakIsle(d.source, e.position);
      return;
    }

    // TİTREŞİMLİ DOKUNUŞ — `game_screen.dart`'taki AYNI düzeltme, gerekçe ve
    // ölçümler orada. Özet: 10 px hayaleti göstermek için doğru eşik ama
    // bırakma kararı için fazla dar; parmak o kadarını istemeden aşıyor ve
    // dokunuş sessizce kayboluyordu.
    final s = d.source;
    final rafinUstunde = s is _RackSource && _rackContains(e.position);
    if (rafinUstunde ||
        (e.position - d.start).distance < _tapSlopOnRelease) {
      await _dokunusOlarakIsle(s, e.position);
      return;
    }

    // Gerçek sürükleme tamamlandı — önceki dokunuş kaydı bayat.
    _zoom.markUnpairableTap();
    if (!d.enabled) return;

    final lifted = Offset(e.position.dx, _liftedY(e.position.dy));
    final cell = _cellAtGlobal(lifted);
    if (cell != null) {
      final (r, c) = cell;
      if (!_isCellFreeFor(s, r, c)) return;
      if (s is _RackSource) {
        if (s.tile.letter == '?') {
          final choice = await showWildLetterSheet(context);
          if (choice?.letter == null) return;
          _controller.dispatch(PlaceTileAction(
              r: r, c: c, wildLetter: choice!.letter, rackIndex: s.index));
        } else {
          _controller.dispatch(PlaceTileAction(r: r, c: c, rackIndex: s.index));
        }
      } else if (s is _PlacedSource) {
        _controller.dispatch(
            MovePlacedTileAction(fromR: s.r, fromC: s.c, toR: r, toC: c));
      }
    } else if (s is _PlacedSource && _rackContains(lifted)) {
      _controller.dispatch(RecallCellAction(r: s.r, c: s.c));
    }
  }

  /// Sürükleme değil DOKUNUŞ olarak işle — iki dal da buradan geçer
  /// (`game_screen.dart`'taki aynı ortaklaştırma).
  Future<void> _dokunusOlarakIsle(_DragSource s, Offset globalPos) async {
    if (s is _RackSource) {
      // Raf dokunuşu tahta çifti oluşturamaz (zoom kapsamı yalnızca tahta).
      _zoom.markUnpairableTap();
      if (state.swapMode) {
        // Taş değiştirme gerçekten sıra gerektirir (sunucuya gider).
        if (!_canAct) return;
        _controller.dispatch(ToggleSwapTileAction(s.index));
      } else {
        if (!_canEdit) return;
        _controller.dispatch(SelectTileAction(s.index));
      }
    } else if (s is _PlacedSource) {
      // Çiftin İKİNCİSİYSE geri alma yutulur (ilk dokunuşun koyduğu taş
      // kalır) — game_screen.dart'taki aynı kural.
      if (_registerZoomTap(globalPos)) return;
      await _tapPlacedTile(s.r, s.c, s.tile);
    }
  }

  void _cancelTileDrag() {
    setState(() {
      _dragRef = null;
      _hiddenSource = null;
    });
    _dragNotifier.value = null;
  }

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
          child: SizedBox(
            width: 46,
            height: 46,
            child: TileWidget(
              tile: g.source.tile,
              variant: isRack ? TileVariant.rack : TileVariant.placed,
              color: isRack ? null : _colorOf(_mySlot),
            ),
          ),
        ),
      ),
    );
  }

  /// Bırakma hedefinin kesikli çerçevesi — game_screen.dart'taki
  /// `_hoverHighlight` ile birebir aynı (bkz. orada, geometri VE
  /// "erken dönüşler de Positioned olmalı" kırpma notu — Parça 27).
  Widget _hoverHighlight(_Ghost g) {
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
    // Köşeler ızgaranın YEREL uzayından `localToGlobal` ile — zoom
    // transformu ne olursa olsun doğru (game_screen.dart'taki aynı düzeltme).
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

  // Web `OnlineGameScreen.tsx`'teki MESSAGE_COLORS — `game_screen.dart`
  // ile BİREBİR aynı olmalı (bilinçli kod tekrarı çifti).
  Color _messageColor(MessageKind kind) => switch (kind) {
        MessageKind.err => kRed,
        MessageKind.ok => kGreen,
        MessageKind.warn => kGold,
        MessageKind.none => kMuted,
      };

  // ── Render ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_mySlot < 0) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bu oyunun katılımcısı değilsin.',
                    style: TextStyle(
                        fontFamily: 'SpaceMono', fontSize: 13, color: _muted)),
                const SizedBox(height: 16),
                NeoButton(
                  label: 'GERİ DÖN',
                  variant: NeoButtonVariant.accent,
                  fontSize: 12,
                  letterSpacing: 1,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      // `_chatState` de dinleniyor: Board footer'ının okunmamış-mesaj rozeti
      // (`unreadMessageCount`) sohbet kapalıyken gelen bir mesajla tetiklenir,
      // bu tetiklemenin ekrana yansıması için tahta oyun motorundan bağımsız
      // da yeniden çizilebilmeli.
      listenable: Listenable.merge([_controller, _chatState]),
      builder: (context, _) {
        // Taslak değiştiyse son gönderimin hatası artık geçmişe ait (web'in
        // `placedSignature` effect'inin karşılığı). `setState` YOK: değer bu
        // build'in kendi çıktısında kullanılıyor, ayrıca bir kare gerekmiyor
        // — bu builder zaten taslağı değiştiren dispatch yüzünden çalışıyor.
        final signature = _placedSignature;
        if (_lastPlacedSignature != null && _lastPlacedSignature != signature) {
          _submitError = null;
        }
        _lastPlacedSignature = signature;

        final me = _me;
        if (!_loaded || me == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Center(
                child: _loadFailed
                    ? _OfflinePanel(
                        onRetry: () {
                          setState(() => _loadFailed = false);
                          unawaited(_refresh());
                        },
                        onBack: () => Navigator.of(context).pop(),
                      )
                    // Yerel oyun ekranı (`game_screen.dart`) geçiş
                    // sırasında AYNI göstergeyi kullanıyor — kullanıcı
                    // isteği: "her yerde aynı deneyim".
                    : const KLoadingNote(),
              ),
            ),
          );
        }

        if (state.isGameOver && !_gameOverShown) {
          _gameOverShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final auth = widget.auth;
            // Web OnlineGameScreen.tsx (~1306-1316) — game_screen.dart ile
            // BİREBİR aynı kural: modalı kapatmak da "Görüş Bildir" formunu
            // açıyor. İkisi bilinçli kod tekrarı çifti, biri değişirse
            // öteki de (bkz. mobile/CLAUDE.md "Etki Analizi").
            void openFeedback() => showFeedbackModal(context,
                auth: auth!,
                feedback: widget.feedback,
                source: FeedbackSource.gameEnd);
            await showGameOverModal(context, state,
                onOpenHistory: () =>
                    showMoveHistoryModal(context, _historyState),
                onFeedback: auth == null ? null : openFeedback);
            if (!mounted || auth == null) return;
            openFeedback();
          });
        }

        final moveStatus = _moveStatus;
        final invalid = moveStatus != null &&
            !moveStatus.valid &&
            moveStatus.reason != null;
        final valid = moveStatus?.valid ?? false;

        // Sıra bende DEĞİLKEN geçerli kelime: "Oyna" pasif olduğundan
        // kullanıcıyı pasif bir butona çağırmak yerine sebebi yazılır.
        final offTurnNote = valid && !_canAct && !state.isGameOver
            ? (_isAiTurn
                ? 'Kelime geçerli — $_currentName hamlesini hesaplıyor…'
                : 'Kelime geçerli — Sıra: $_currentName')
            : null;
        // Sıra BENDEYKEN geçerli taslak: metin state.message'tan okunmaz,
        // TÜRETİLİR (bayat "Önce bir harf seç." / senkron sonrası rakibin son
        // hamlesi aynı tahta için farklı şeyler söyleyebiliyordu).
        final myTurnNote = valid && _canAct && !state.isGameOver
            ? 'Oyna tuşuyla kelimeyi onayla.'
            : null;
        final last = _lastMoveMessage;
        // `_submitError` türetilmiş notlardan ÖNCE gelir (bkz. alanın
        // tanımındaki gerekçe) — taslak geçerli kalsa bile son gönderimin
        // hatası görünmek zorunda. Web'deki sıralamanın birebir aynısı.
        final submitError = _submitError;
        final liveMessage = invalid
            ? moveStatus.reason!
            : state.isGameOver
                ? 'Oyun bitti.'
                : submitError ??
                    offTurnNote ??
                    myTurnNote ??
                    (state.message.isNotEmpty ? state.message : last.text);
        final liveKind = invalid
            ? MessageKind.err
            : state.isGameOver
                ? MessageKind.none
                : submitError != null
                    ? MessageKind.err
                    : offTurnNote != null
                        ? MessageKind.warn
                        : valid
                            ? MessageKind.ok
                            : state.message.isNotEmpty
                                ? state.messageType
                                : last.kind;

        return LeagueRewardsHost(
          rewards: widget.leagueRewards,
          auth: widget.auth,
          stats: widget.stats,
          suppress: !state.isGameOver,
          child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Stack(
              key: _stackKey,
              children: [
                // game_screen.dart'taki aynı 680px kart sınırı (bkz. orada,
                // "web'in tamamı max-w-[680px]" notu) — geniş/yatay ekranda
                // tahtanın/rafın gölgesi kenardan kırpılmasın diye.
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
                            // Logo yalnızca listeye döner — oyunu BİTİRMEZ.
                            onLogoTap: () => Navigator.of(context).pop(),
                            onPlayerTap:
                                widget.stats == null ? null : _openPlayerCard,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          // Aktif bir taş sürüklemesi varken kaydırma kilitleniyor
                          // — game_screen.dart'taki aynı düzeltme (bkz. orada,
                          // "Listener jest arenasına katılmıyor" notu).
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
                                        zoom: _zoom,
                                        viewportKey: _viewportKey,
                                        onBoardPointerDown: _boardPointerDown,
                                        onBoardPointerMove: _boardPointerMove,
                                        onBoardPointerUp: _boardPointerUp,
                                        onBoardPointerCancel: _endBoardPan,
                                        onOpenHistory: () => showMoveHistoryModal(
                                            context, _historyState),
                                        onOpenHelp: () => showHelpModal(context),
                                        onOpenMessaging: widget.chat == null
                                            ? null
                                            : _openMessaging,
                                        unreadMessageCount:
                                            _chatState.unreadCount,
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
                                    // Sıra bende değil VE henüz taş koymadıysam
                                    // banner (kimin sırası olduğu net kalsın); taş
                                    // koyunca yerini normal mesaj satırına bırakır.
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(12, 4, 12, 0),

                                      child: (!_canAct &&
                                              !state.isGameOver &&
                                              moveStatus == null)
                                          ? _TurnBanner(
                                              isAiTurn: _isAiTurn,
                                              name: _currentName)
                                          : SizedBox(
                                              key: const ValueKey('message-line'),
                                              height: 30,
                                              child: Center(
                                                child: Text(
                                                  liveMessage,
                                                  maxLines: 2,
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'SpaceMono',
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        _messageColor(liveKind),
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(12, 6, 12, 0),
                                      child: IntrinsicHeight(
                                        child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(
                                                  child: KeyedSubtree(
                                                    key: _rackKey,
                                                    child: RackWidget(
                                                      tiles: me.rack,
                                                      selectedTile:
                                                          state.selectedTile,
                                                      onSelect: (i) {
                                                        if (state.swapMode) {
                                                          if (!_canAct) return;
                                                          _controller.dispatch(
                                                              ToggleSwapTileAction(
                                                                  i));
                                                        } else {
                                                          if (!_canEdit) return;
                                                          _controller.dispatch(
                                                              SelectTileAction(i));
                                                        }
                                                      },
                                                      title: me.name,
                                                      color: _colorOf(_mySlot),
                                                      swapMode: state.swapMode,
                                                      swapSelection:
                                                          state.swapSelection,
                                                      dragHiddenIndex:
                                                          _hiddenSource is _RackSource
                                                              ? (_hiddenSource
                                                                      as _RackSource)
                                                                  .index
                                                              : null,
                                                      onTilePointerDown: (i, e) {
                                                        // ⚠ game_screen.dart'takiyle AYNI
                                                        // yarış ve aynı gerekçe (26 Ağustos
                                                        // 2026 saha çökmesi). Burada risk
                                                        // DAHA YÜKSEK: yerel oyunda rafı
                                                        // yalnızca sen kısaltırsın, Canlı
                                                        // oyunda sunucudan gelen realtime
                                                        // güncelleme parmağın altında
                                                        // kısaltabilir.
                                                        if (i < 0 ||
                                                            i >= me.rack.length) {
                                                          return;
                                                        }
                                                        _beginTileDrag(
                                                            _RackSource(i, me.rack[i]), e);
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
                                                      // Web (OnlineGameScreen.tsx
                                                      // ~1018): tek satır,
                                                      // `text-[15px]` + `px-5` —
                                                      // OYNA'dan (12px) belirgin
                                                      // BÜYÜK olması bilinçli, raf
                                                      // (`flex-1 min-w-0`) buna
                                                      // göre daralıyor. Port
                                                      // `\n` ile iki satıra bölüp
                                                      // 12px'te bırakmıştı.
                                                      ? NeoButton(
                                                          label: 'TEKRAR OYNA',
                                                          variant:
                                                              NeoButtonVariant.accent,
                                                          fontSize: 15,
                                                          letterSpacing: 1.2,
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 20),
                                                          onPressed: _handleRematch,
                                                        )
                                                      : NeoButton(
                                                          label: _busy
                                                              ? 'GÖNDERİLİYOR…'
                                                              : 'OYNA',
                                                          variant:
                                                              NeoButtonVariant.accent,
                                                          fontSize:
                                                              12, // web text-[12px]
                                                          letterSpacing: 1.2,
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 20),
                                                          // Boş taslakta da aktif —
                                                          // gerekçe game_screen.dart'ın
                                                          // aynı satırında (kardeş
                                                          // ekran çifti).
                                                          onPressed: _canAct && !_busy
                                                              ? _handlePlay
                                                              : null,
                                                        ),
                                                ],
                                              ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      // Üst boşluk 8→24: raf kartının kendi gölgesi
                                      // game_screen.dart ile AYNI sebeple (bkz. orada).
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 6, 12, 12),
                                      child: state.swapMode
                                          ? Row(children: [
                                              Expanded(
                                                child: NeoButton(
                                                  letterSpacing: 1.2,
                                                  lineHeight: 1.5,
                                                  label: state.swapSelection
                                                          .isNotEmpty
                                                      ? 'DEĞİŞTİR (${state.swapSelection.length})'
                                                      : 'DEĞİŞTİR',
                                                  variant: NeoButtonVariant.gold,
                                                  onPressed: _canAct &&
                                                          !_busy &&
                                                          state.swapSelection
                                                              .isNotEmpty
                                                      ? _handleConfirmSwap
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
                                                      ? () => _controller.dispatch(
                                                          const ToggleSwapModeAction())
                                                      : null,
                                                ),
                                              ),
                                            ])
                                          // IntrinsicHeight + stretch: game_screen.dart ile AYNI sebep — web'in
                                          // flex satırı butonları EN UZUNA (TORBA'nın 13px sayacı) eşitliyor,
                                          // Flutter Row varsayılanı `center` bunu yapmıyor (bkz. orada).
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
                                                  onPressed: _canAct && !_busy
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
                                                      ? () => _controller.dispatch(
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
                                                  onPressed: _canEdit
                                                      ? () => _controller.dispatch(
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
                                                  // Boş taslakta da aktif (web
                                                  // `disabled={!canAct}`).
                                                  onPressed: _canEdit
                                                      ? () => _controller.dispatch(
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
                                                  // Web App.tsx ~1360 (bkz.
                                                  // game_screen.dart'taki aynı
                                                  // NeoButton çağrısı — ikisi de
                                                  // AYNI PR'da güncellenmeli).
                                                  richLabel: [
                                                    const TextSpan(
                                                        text: 'TORBA '),
                                                    TextSpan(
                                                      text: '${state.bag.length}',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: kAccent,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                  onPressed: () =>
                                                      showRemainingTilesModal(
                                                          context,
                                                          state,
                                                          _mySlot),
                                                ),
                                              ),
                                            ])),
                                    ),
                                  ],
                                )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // game_screen.dart ile birebir aynı overlay deseni (bkz.
                // orada) — `_dragNotifier`'ı dinleyen tek, koşulsuz duran
                // ValueListenableBuilder.
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

/// "Sıra: X — oynaması bekleniyor" bandı; sıra bir YZ koltuğundaysa hamle
/// sunucuda hesaplandığından (birkaç saniye sürebilir) nabız atan bir nokta
/// ile insan beklemesinden ayrışır (web aynı ayrım).
class _TurnBanner extends StatefulWidget {
  final bool isAiTurn;
  final String name;
  const _TurnBanner({required this.isAiTurn, required this.name});

  @override
  State<_TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends State<_TurnBanner>
    with SingleTickerProviderStateMixin {
  // DİKKAT: `late final _pulse = AnimationController(...)` YAZMA — `late`
  // TEMBEL değerlendirilir; isAiTurn false iken alan hiç okunmaz ve ilk
  // erişim dispose()'ta olur, orada `createTicker` sökülmüş bir elemanın
  // ata aramasına düşüp "Looking up a deactivated widget's ancestor is
  // unsafe" ile patlar (feedback_modal'daki `late final _openedAt` dersinin
  // kardeşi — kurulum initState'te yapılmalı).
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isAiTurn) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_TurnBanner old) {
    super.didUpdateWidget(old);
    if (widget.isAiTurn && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isAiTurn && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // web: `shadow-raised … border border-red/40 bg-red/10 px-4 py-3`
      // Renkler `_red` (= tailwind token `#DC2626`) TÜREVİ olmak zorunda:
      // 13 Ağustos 2026'ya kadar burada `#E0483A` (kMoveInvalid — TAHTAYA
      // özel kırmızı) sabit yazılıydı, yorumu ise doğru şekilde "bg-red/10"
      // diyordu. Sonuç, kendi içinde tutarsız bir bant: zemin/çerçeve bir
      // kırmızı, nabız noktası ve metin (ikisi de `_red`) BAŞKA bir kırmızı.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: ShapeDecorationWithCssShadows(
        color: _red.withValues(alpha: 0.1), // web bg-red/10
        radius: 6,
        borderColor: _red.withValues(alpha: 0.4), // border-red/40
        shadows: kRaisedShadows,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isAiTurn) ...[
            FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0.25).animate(_pulse),
              child: Container(
                width: 8,
                height: 8,
                decoration:
                    const BoxDecoration(color: _red, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.isAiTurn
                  ? trUpper('${widget.name} hamlesini hesaplıyor…')
                  : trUpper('Sıra: ${widget.name} — oynaması bekleniyor'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: _red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Canlı oyun hiç yüklenemediğinde gösterilen panel — web
/// `OnlineGameScreen.tsx`'in `loadFailed` dalının karşılığı.
///
/// Metinler `util/offline_notice.dart`'tan; iki platformda AYNI olmak
/// zorunda (bkz. o dosyanın başlığı).
class _OfflinePanel extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _OfflinePanel({required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        // NeoBox KULLANILMIYOR: çocuğunu `SizedBox.expand` ile sarıyor, yani
        // gelen kısıtları DOLDURUYOR — boyutu dışarıdan belli olan yerler
        // için tasarlanmış. `Center` altında bu, kartı ekran boyu bir beyaz
        // dikdörtgene çeviriyordu (14 Ağustos 2026, kullanıcı cihazda
        // "bozuk" diye bildirdi). Burada kart İÇERİĞİNE göre küçülmeli.
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x8015233F),
                  blurRadius: 45,
                  offset: Offset(0, 20)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  kOfflineLiveTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: kText),
                ),
                const SizedBox(height: 12),
                const Text(
                  kOfflineLiveBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5, color: kText),
                ),
                const SizedBox(height: 16),
                NeoButton(
                  label: 'TEKRAR DENE',
                  variant: NeoButtonVariant.accent,
                  onPressed: onRetry,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: onBack,
                    child: Text(
                      '← ${trUpper(kOfflineBackLabel)}',
                      style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: kMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
