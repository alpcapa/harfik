// Kelimeki core — Player (src/game/types.ts portu).
import 'tile.dart';

class Player {
  final String name;

  /// Atanmış köşe bölgesi indeksleri (0..3). `cornersFor` her oyuncuya tek
  /// köşe atar; liste tipi gelecekteki çoklu-köşe varyantı için genel.
  final List<int> corners;

  /// Renk paleti indeksi (renklerin kendisi UI katmanında).
  final int colorIndex;
  final bool isAI;

  /// Teslim olup oyundan çıktı mı — artık sırası gelmez.
  final bool surrendered;
  final List<Tile> rack;
  final int score;

  /// En yüksek tek hamle puanı (çok kelime + bonus dahil, vergi öncesi brüt).
  final int bestMoveScore;

  /// En yüksek puanlı TEK kelimenin (X2/X3 dahil) nihai puanı.
  final int bestWordScore;
  final String longestWord;
  final int moveCount;
  final int moveScoreSum;

  const Player({
    required this.name,
    required this.corners,
    required this.colorIndex,
    required this.isAI,
    required this.surrendered,
    required this.rack,
    required this.score,
    required this.bestMoveScore,
    required this.bestWordScore,
    required this.longestWord,
    required this.moveCount,
    required this.moveScoreSum,
  });

  Player copyWith({
    String? name,
    List<int>? corners,
    int? colorIndex,
    bool? isAI,
    bool? surrendered,
    List<Tile>? rack,
    int? score,
    int? bestMoveScore,
    int? bestWordScore,
    String? longestWord,
    int? moveCount,
    int? moveScoreSum,
  }) =>
      Player(
        name: name ?? this.name,
        corners: corners ?? this.corners,
        colorIndex: colorIndex ?? this.colorIndex,
        isAI: isAI ?? this.isAI,
        surrendered: surrendered ?? this.surrendered,
        rack: rack ?? this.rack,
        score: score ?? this.score,
        bestMoveScore: bestMoveScore ?? this.bestMoveScore,
        bestWordScore: bestWordScore ?? this.bestWordScore,
        longestWord: longestWord ?? this.longestWord,
        moveCount: moveCount ?? this.moveCount,
        moveScoreSum: moveScoreSum ?? this.moveScoreSum,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'corners': corners,
        'colorIndex': colorIndex,
        'isAI': isAI,
        'surrendered': surrendered,
        'rack': [for (final t in rack) t.toJson()],
        'score': score,
        'bestMoveScore': bestMoveScore,
        'bestWordScore': bestWordScore,
        'longestWord': longestWord,
        'moveCount': moveCount,
        'moveScoreSum': moveScoreSum,
      };

  factory Player.fromJson(Map<String, Object?> j) => Player(
        name: j['name'] as String,
        corners: [for (final c in j['corners'] as List) c as int],
        colorIndex: j['colorIndex'] as int,
        isAI: j['isAI'] as bool,
        surrendered: j['surrendered'] as bool,
        rack: [
          for (final t in j['rack'] as List)
            Tile.fromJson((t as Map).cast<String, Object?>())
        ],
        score: j['score'] as int,
        bestMoveScore: j['bestMoveScore'] as int,
        bestWordScore: j['bestWordScore'] as int,
        longestWord: j['longestWord'] as String,
        moveCount: j['moveCount'] as int,
        moveScoreSum: j['moveScoreSum'] as int,
      );
}
