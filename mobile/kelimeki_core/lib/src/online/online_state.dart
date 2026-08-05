// Kelimeki core — Canlı oyunun herkese açık sunucu state'i
// (src/lib/database.types.ts içindeki OnlineGameStatePublic'in core'a bakan
// yüzü). JSON alan adları sunucudaki snake_case ile eşleşir.
import '../model/game_state.dart' show Board;
import '../model/tile.dart';
import '../model/types.dart';

class OnlinePlayerPublic {
  final String name;
  final List<int> corners;
  final int colorIndex;
  final bool isAI;
  final bool surrendered;
  final int rackCount;
  final int score;
  final int bestMoveScore;
  final int bestWordScore;
  final String longestWord;
  final int moveCount;
  final int moveScoreSum;

  const OnlinePlayerPublic({
    required this.name,
    required this.corners,
    required this.colorIndex,
    required this.isAI,
    required this.surrendered,
    required this.rackCount,
    required this.score,
    required this.bestMoveScore,
    required this.bestWordScore,
    required this.longestWord,
    required this.moveCount,
    required this.moveScoreSum,
  });

  factory OnlinePlayerPublic.fromJson(Map<String, Object?> j) =>
      OnlinePlayerPublic(
        name: j['name'] as String,
        corners: [for (final c in j['corners'] as List) c as int],
        colorIndex: j['colorIndex'] as int,
        isAI: j['isAI'] as bool,
        surrendered: j['surrendered'] as bool,
        rackCount: j['rackCount'] as int,
        score: j['score'] as int,
        bestMoveScore: j['bestMoveScore'] as int,
        bestWordScore: j['bestWordScore'] as int,
        longestWord: j['longestWord'] as String,
        moveCount: j['moveCount'] as int,
        moveScoreSum: j['moveScoreSum'] as int,
      );
}

class OnlineGameStatePublic {
  final Board board;
  final Map<String, BonusType> bonuses;
  final List<OnlinePlayerPublic> players;
  final int current;
  final int turnCount;
  final int consecutivePasses;
  final bool isGameOver;

  /// 'normal' | 'surrender' | null.
  final String? endReason;
  final List<Cell> lastMoveCells;
  final int bagCount;
  final String startedAt;

  const OnlineGameStatePublic({
    required this.board,
    required this.bonuses,
    required this.players,
    required this.current,
    required this.turnCount,
    required this.consecutivePasses,
    required this.isGameOver,
    required this.endReason,
    required this.lastMoveCells,
    required this.bagCount,
    required this.startedAt,
  });

  factory OnlineGameStatePublic.fromJson(Map<String, Object?> j) =>
      OnlineGameStatePublic(
        board: [
          for (final row in j['board'] as List)
            [
              for (final cell in row as List)
                cell == null
                    ? null
                    : Tile.fromJson((cell as Map).cast<String, Object?>()),
            ],
        ],
        bonuses: {
          for (final e in (j['bonuses'] as Map).entries)
            e.key as String: BonusType.tw, // tek bonus türü var
        },
        players: [
          for (final p in j['players'] as List)
            OnlinePlayerPublic.fromJson((p as Map).cast<String, Object?>()),
        ],
        current: j['current'] as int,
        turnCount: j['turn_count'] as int,
        consecutivePasses: j['consecutive_passes'] as int,
        isGameOver: j['is_game_over'] as bool,
        endReason: j['end_reason'] as String?,
        lastMoveCells: [
          for (final c in j['last_move_cells'] as List)
            ((c as List)[0] as int, c[1] as int),
        ],
        bagCount: j['bag_count'] as int,
        startedAt: j['started_at'] as String,
      );
}
