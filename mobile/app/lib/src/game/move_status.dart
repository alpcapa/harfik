// Oyna'ya basmadan önceki anlık geçerlilik/puan hesabı — App.tsx'teki
// moveStatus useMemo'sunun portu. Tahtaya konan taşlar için yerel sözlükle
// doğrulama + oluşan tüm kelimelerin hücreleri (Board tek dış çerçeve
// çizer) + potansiyel puan.
import 'package:kelimeki_core/kelimeki_core.dart';

class MoveStatus {
  final bool valid;
  final String? reason;
  final List<Cell> cells;
  final int score;
  const MoveStatus({
    required this.valid,
    this.reason,
    required this.cells,
    required this.score,
  });
}

MoveStatus? computeMoveStatus(GameState state, WordSource words) {
  if (state.placed.isEmpty) return null;
  if (state.current < 0 || state.current >= state.players.length) return null;
  final current = state.players[state.current];

  final result = validatePlacement(
    state.board,
    state.placed,
    state.current,
    current.corners,
    isFirstMove(state),
    words,
  );
  final formed = getFormedWords(state.board, state.placed);
  final cells = formed.isNotEmpty
      ? [for (final f in formed) ...f.coords]
      : [for (final k in state.placed.keys) parseKey(k)];

  return MoveStatus(
    valid: result.valid,
    reason: result.reason,
    cells: cells,
    score: calcScore(state.board, state.placed, state.bonuses),
  );
}
