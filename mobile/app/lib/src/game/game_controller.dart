// GameController — kelimeki_core motorunun ince ChangeNotifier kabuğu.
//
// Karar (mobile/CLAUDE.md #5): ek state-management framework'ü YOK. Motor
// zaten saf bir reducer; UI katmanının tek ihtiyacı "state değişti" sinyali.
// Web'deki useReducer + App.tsx YZ-turu effect'inin eşleniği.
import 'dart:async';

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

  /// YZ'nin sırası geldikten sonra hamlesini dispatch etmeden önce beklenen
  /// süre — web `src/App.tsx`'teki `const AI_THINK_MS = 1100;` sabitinin
  /// birebir portu (bkz. mobile/CLAUDE.md Parça 20). Web'de YZ HER ZAMAN bu
  /// kadar "düşünür" görünür; port ilk sürümde bunu hiç taşımamış, YZ bir
  /// sonraki event-loop turunda (≈0 ms) oynuyordu — sonuç: kullanıcı kendi
  /// hamlesinin mesaj satırını hiç göremeden YZ'nin mesajı üstüne yazıyordu.
  /// Enjekte edilebilir tutulur (bu projenin "saat/rastgelelik enjekte
  /// edilir" sözleşmesinin devamı, bkz. `rng`/`nowIso`) — testler
  /// `Duration.zero` geçip gerçek zaman kaybetmeden sürebilir.
  final Duration aiThinkDelay;

  GameState _state = createInitialState();
  Timer? _aiTimer;
  bool _disposed = false;

  GameController({
    required WordSource words,
    Rng? rng,
    String Function()? nowIso,
    this.autoPlayAi = true,
    this.actingSeat,
    this.aiThinkDelay = const Duration(milliseconds: 1100),
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

  /// Sıra bir YZ koltuğundaysa `aiThinkDelay` sonra AI_PLAY dispatch eder —
  /// web'in `setTimeout(..., AI_THINK_MS)` effect'inin birebir eşleniği.
  /// Bekleyen bir timer varsa (`_aiTimer?.isActive`) üst üste tetiklenmeyi
  /// önlemek için yeni bir tane kurulmaz — eski `_aiScheduled` bayrağının
  /// işlevi artık timer'ın kendi durumundan okunuyor.
  void _maybeScheduleAiTurn() {
    if (!autoPlayAi || (_aiTimer?.isActive ?? false) || _disposed) return;
    final s = _state;
    if (s.phase != GamePhase.play || s.isGameOver) return;
    if (!s.players[s.current].isAI) return;
    _aiTimer = Timer(aiThinkDelay, () {
      if (_disposed) return;
      // Web effect cleanup'ının eşleniği: gecikme boyunca state değiştiyse
      // (ör. restore/dispose/insan araya girdi) eski karar uygulanmaz.
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
    // Gecikme gerçek bir Timer olduğundan, iptal edilmezse widget testlerinde
    // "A Timer is still pending even after the widget tree was disposed"
    // flake'ine yol açar (bkz. mobile/CLAUDE.md Parça 11/13) — dispose'ta
    // iptal etmek bunu yapısal olarak önler.
    _aiTimer?.cancel();
    super.dispose();
  }
}
