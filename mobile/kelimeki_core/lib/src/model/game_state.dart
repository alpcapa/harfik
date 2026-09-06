// Kelimeki core — GameState (src/game/types.ts portu).
import 'history_entry.dart';
import 'player.dart';
import 'tile.dart';
import 'types.dart';

/// 13×13 tahta; boş hücreler null.
typedef Board = List<List<Tile?>>;

/// Bu turda geçici yerleştirilen taşlar: "r,c" → Tile. Ekleme sırası TS'teki
/// JS nesne anahtar sırasıyla aynı öneme sahiptir (kelime çıkarımı ve vergi
/// payı sırası buna bağlı) — her zaman LinkedHashMap (Dart varsayılanı) kullan.
typedef Placed = Map<String, Tile>;

class GameState {
  final GamePhase phase;

  /// Oyunun başladığı an (ISO) — setup fazında boş dize. Motor bunu kendisi
  /// üretmez; `GameEngine.nowIso` enjekte edilir (determinizm sözleşmesi).
  final String startedAt;
  final bool multiSession;
  final EndReason endReason;
  final Board board;
  final List<Tile> bag;
  final Map<String, BonusType> bonuses;
  final Placed placed;
  final List<Player> players;
  final int current;
  final int? selectedTile;
  final bool swapMode;
  final List<int> swapSelection;
  final int turnCount;
  final int consecutivePasses;
  final bool isGameOver;
  final String message;
  final MessageKind messageType;
  final List<Cell> lastMoveCells;
  final List<HistoryEntry> moveHistory;

  /// YZ zorluk seviyesi — `StartAction` ile bir kez yazılır, değiştiren action
  /// YOK. null = Normal: eski kayıtlar, web'in Normal'de yazmadığı alan ve
  /// Canlı oyunlar (TS: `GameState.aiLevel?`).
  final AiLevel? aiLevel;

  const GameState({
    required this.phase,
    required this.startedAt,
    required this.multiSession,
    required this.endReason,
    required this.board,
    required this.bag,
    required this.bonuses,
    required this.placed,
    required this.players,
    required this.current,
    required this.selectedTile,
    required this.swapMode,
    required this.swapSelection,
    required this.turnCount,
    required this.consecutivePasses,
    required this.isGameOver,
    required this.message,
    required this.messageType,
    required this.lastMoveCells,
    required this.moveHistory,
    this.aiLevel,
  });

  static const Object _unset = Object();

  GameState copyWith({
    GamePhase? phase,
    String? startedAt,
    bool? multiSession,
    EndReason? endReason,
    Board? board,
    List<Tile>? bag,
    Map<String, BonusType>? bonuses,
    Placed? placed,
    List<Player>? players,
    int? current,
    Object? selectedTile = _unset,
    bool? swapMode,
    List<int>? swapSelection,
    int? turnCount,
    int? consecutivePasses,
    bool? isGameOver,
    String? message,
    MessageKind? messageType,
    List<Cell>? lastMoveCells,
    List<HistoryEntry>? moveHistory,
    AiLevel? aiLevel,
  }) =>
      GameState(
        phase: phase ?? this.phase,
        startedAt: startedAt ?? this.startedAt,
        multiSession: multiSession ?? this.multiSession,
        endReason: endReason ?? this.endReason,
        board: board ?? this.board,
        bag: bag ?? this.bag,
        bonuses: bonuses ?? this.bonuses,
        placed: placed ?? this.placed,
        players: players ?? this.players,
        current: current ?? this.current,
        selectedTile:
            identical(selectedTile, _unset) ? this.selectedTile : selectedTile as int?,
        swapMode: swapMode ?? this.swapMode,
        swapSelection: swapSelection ?? this.swapSelection,
        turnCount: turnCount ?? this.turnCount,
        consecutivePasses: consecutivePasses ?? this.consecutivePasses,
        isGameOver: isGameOver ?? this.isGameOver,
        message: message ?? this.message,
        messageType: messageType ?? this.messageType,
        lastMoveCells: lastMoveCells ?? this.lastMoveCells,
        moveHistory: moveHistory ?? this.moveHistory,
        aiLevel: aiLevel ?? this.aiLevel,
      );
}
