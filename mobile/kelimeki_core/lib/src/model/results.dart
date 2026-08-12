// Kelimeki core — doğrulama/YZ sonuç tipleri (src/game/types.ts portu).
import 'tile.dart';
import 'types.dart';

class ValidationResult {
  final bool valid;
  final String? reason;
  final List<String>? words;
  const ValidationResult({required this.valid, this.reason, this.words});
}

class Placement {
  final int r;
  final int c;
  final Tile tile;
  const Placement({required this.r, required this.c, required this.tile});
}

/// YZ'nin bulduğu hamle.
class AIMove {
  final String word;
  final int score;
  final List<Placement> placements;
  const AIMove({required this.word, required this.score, required this.placements});
}

class FormedWord {
  final String word;
  final List<Cell> coords;
  const FormedWord({required this.word, required this.coords});
}

class InvasionShare {
  final int index;
  final int amount;
  const InvasionShare({required this.index, required this.amount});
}

class InvasionSplit {
  final int pts;
  final List<InvasionShare> shares;
  const InvasionSplit({required this.pts, required this.shares});
}
