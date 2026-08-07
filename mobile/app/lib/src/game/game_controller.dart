// GameController — kelimeki_core motorunun ince ChangeNotifier kabuğu.
//
// Karar (mobile/CLAUDE.md #5): ek state-management framework'ü YOK. Motor
// zaten saf bir reducer; UI katmanının tek ihtiyacı "state değişti" sinyali.
// Web'deki useReducer + App.tsx YZ-turu effect'inin eşleniği.
import 'package:flutter/foundation.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

class GameController extends ChangeNotifier {
  final GameEngine _engine;

  /// YZ sırası geldiğinde otomatik AI_PLAY dispatch edilsin mi (web'deki
  /// App.tsx effect'inin eşleniği). Testlerde adım adım sürmek için kapatılır.
  /// **Canlı oyunda her zaman false** — YZ'nin hamlesi sunucuda
  /// (`play-ai-turn`) hesaplanır, istemci hiç oynamaz.
  final bool autoPlayAi;

  /// Canlı oyun için koltuk sabitleme — web `onlineGameReducerRef`'in
  /// eşleniği. Reducer'ın salt-yerel düzenleme action'ları (PLACE_TILE,
  /// RECALL_CELL, RECALL_ALL, SHUFFLE_RACK, SELECT_TILE…) hep
  /// `state.current`'ın (SIRASI GELEN oyuncunun) rafı üzerinden işler; bu
  /// yerel/hotseat oyunda doğru varsayımdır çünkü düzenleme yalnızca sırası
  /// gelene açıktır. Canlı oyunda ise sıra bende olmasa bile taş
  /// yerleştirebiliyorum (rakibi beklerken egzersiz — bkz. OnlineGameScreen
  /// `canEdit`), dolayısıyla bu action'lar BENİM koltuğum üzerinden
  /// işlemeli; aksi halde rakibin (sahte/dolgu) rafından taş düşürülürdü.
  /// Çözüm: `current`'ı geçici olarak bu koltuğa sabitleyip reduce et,
  /// sonucun `current`'ını gerçek sunucu sırasına geri yükle.
  ///
  /// `SyncOnlineStateAction` BİLEREK muaf — `current`'ı gerçekten sunucudan
  /// gelen değere göre belirleyen tek action odur. Sırayı ilerleten
  /// PLAY/PASS/CONFIRM_SWAP ise Canlı ekrandan hiç dispatch edilmez
  /// (`submit_move` RPC'si kullanılır), yani bu sarmalama yalnızca
  /// düzenleme action'ları için anlamlıdır.
  ///
  /// null (varsayılan) → hiçbir sarmalama yok, yerel oyunun davranışı
  /// bitine kadar aynı.
  final int? actingSeat;

  GameState _state = createInitialState();
  bool _aiScheduled = false;
  bool _disposed = false;

  GameController({
    required WordSource words,
    Rng? rng,
    String Function()? nowIso,
    this.autoPlayAi = true,
    this.actingSeat,
  }) : _engine = GameEngine(
          words: words,
          rng: rng ?? SystemRng(),
          // Web startGame'i new Date().toISOString() gömer; buradaki eşlenik.
          nowIso: nowIso ?? () => DateTime.now().toUtc().toIso8601String(),
        );

  GameState get state => _state;

  /// State'i olduğu gibi yükler (kayıttan devam, testte fixture'la başlama).
  /// Web'deki RESUME_SAVED'in eşleniği — dispatch zinciri dışından tek yol.
  void restore(GameState s) {
    _state = s;
    notifyListeners();
    _maybeScheduleAiTurn();
  }

  void dispatch(GameAction action) {
    final next = _reduce(_state, action);
    if (identical(next, _state)) return; // no-op action (guard'lar)
    _state = next;
    notifyListeners();
    _maybeScheduleAiTurn();
  }

  /// `actingSeat` kuralı (yukarıdaki alan yorumuna bkz.) — no-op kısa
  /// devresi korunur: motor state'i değiştirmediyse ORİJİNAL nesne döner,
  /// yoksa `copyWith` her seferinde yeni bir nesne üretip `dispatch`'in
  /// `identical` kontrolünü işlevsiz bırakırdı.
  GameState _reduce(GameState s, GameAction action) {
    final seat = actingSeat;
    if (seat == null ||
        seat < 0 ||
        seat >= s.players.length ||
        s.current == seat ||
        action is SyncOnlineStateAction) {
      return _engine.reduce(s, action);
    }
    final pinned = s.copyWith(current: seat);
    final next = _engine.reduce(pinned, action);
    if (identical(next, pinned)) return s;
    return next.copyWith(current: s.current);
  }

  /// Sıra bir YZ koltuğundaysa bir sonraki event-loop turunda AI_PLAY
  /// dispatch eder — senkron zincir yerine Future(...) ile, her hamle
  /// arasında UI'ın çizim şansı olsun ve dinleyiciler her ara state'i
  /// görsün diye. `_aiScheduled` bayrağı üst üste tetiklenmeyi önler.
  void _maybeScheduleAiTurn() {
    if (!autoPlayAi || _aiScheduled || _disposed) return;
    final s = _state;
    if (s.phase != GamePhase.play || s.isGameOver) return;
    if (!s.players[s.current].isAI) return;
    _aiScheduled = true;
    Future<void>(() {
      _aiScheduled = false;
      if (_disposed) return;
      final cur = _state;
      if (cur.phase == GamePhase.play &&
          !cur.isGameOver &&
          cur.players[cur.current].isAI) {
        dispatch(const AiPlayAction());
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
