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
  final bool autoPlayAi;

  GameState _state = createInitialState();
  bool _aiScheduled = false;
  bool _disposed = false;

  GameController({
    required WordSource words,
    Rng? rng,
    String Function()? nowIso,
    this.autoPlayAi = true,
  }) : _engine = GameEngine(
          words: words,
          rng: rng ?? SystemRng(),
          // Web startGame'i new Date().toISOString() gömer; buradaki eşlenik.
          nowIso: nowIso ?? () => DateTime.now().toUtc().toIso8601String(),
        );

  GameState get state => _state;

  void dispatch(GameAction action) {
    final next = _engine.reduce(_state, action);
    if (identical(next, _state)) return; // no-op action (guard'lar)
    _state = next;
    notifyListeners();
    _maybeScheduleAiTurn();
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
