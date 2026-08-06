// Kelimeki core — tahta yardımcıları (src/utils/board.ts portu).
import '../constants.dart';
import '../model/game_state.dart' show Board, Placed;
import '../model/results.dart';
import '../model/tile.dart';
import '../model/types.dart';

Board createEmptyBoard() =>
    List.generate(boardSize, (_) => List<Tile?>.filled(boardSize, null, growable: false));

String cellKey(int r, int c) => '$r,$c';

/// "r,c" anahtarını (r, c) koordinatına çözer.
Cell parseKey(String k) {
  final i = k.indexOf(',');
  return (int.parse(k.substring(0, i)), int.parse(k.substring(i + 1)));
}

bool _inBounds(int r, int c) => r >= 0 && r < boardSize && c >= 0 && c < boardSize;

/// Bir taşın görünen harfi (joker ise seçilen harf; seçilmemişse boş dize).
String tileLetter(Tile tile) => tile.wild ? (tile.wildLetter ?? '') : tile.letter;

String? _getLetterAt(Board board, Placed placed, int r, int c) {
  final p = placed[cellKey(r, c)];
  if (p != null) return tileLetter(p);
  final b = _inBounds(r, c) ? board[r][c] : null;
  if (b != null) return tileLetter(b);
  return null;
}

/// (r,c)'den (dr,dc) yönünde uzanan tam kelime — koordinatlarıyla.
FormedWord _fullWordWithCoords(
    Board board, Placed placed, int r, int c, int dr, int dc) {
  var sr = r, sc = c;
  while (_inBounds(sr - dr, sc - dc) &&
      _getLetterAt(board, placed, sr - dr, sc - dc) != null) {
    sr -= dr;
    sc -= dc;
  }
  final buf = StringBuffer();
  final coords = <Cell>[];
  var rr = sr, rc = sc;
  while (_inBounds(rr, rc) && _getLetterAt(board, placed, rr, rc) != null) {
    buf.write(_getLetterAt(board, placed, rr, rc));
    coords.add((rr, rc));
    rr += dr;
    rc += dc;
  }
  return FormedWord(word: buf.toString(), coords: coords);
}

/// (r,c) hücresinden (dr,dc) yönünde uzanan tam kelime — web
/// `getFullWordAt` (src/utils/board.ts) eşleniği. Anlam sorgusu için tahtadaki
/// bir taşa dokunulduğunda o hücreden geçen yatay/dikey kelimeyi bulur.
/// Mevcut özel yardımcıyı sarar; davranış değişmez (golden vector paritesi).
String fullWordAt(Board board, Placed placed, int r, int c, int dr, int dc) =>
    _fullWordWithCoords(board, placed, r, c, dr, dc).word;

/// Bu turdaki yerleştirmelerle oluşan tüm kelimeler (ana + çapraz).
/// 2 harften kısa kelimeler atlanır. Sıra TS ile birebir: önce ana kelime,
/// sonra her yerleştirme için çapraz kelime (placed ekleme sırasında).
List<FormedWord> getFormedWords(Board board, Placed placed) {
  final coords = [for (final k in placed.keys) parseKey(k)];
  if (coords.isEmpty) return [];

  final rows = {for (final p in coords) p.$1};
  final horiz = rows.length == 1;

  final seen = <String>{};
  final result = <FormedWord>[];

  void addWord(FormedWord fw) {
    if (fw.word.length < 2) return;
    // Başlangıç + bitiş hücresi imzası: aynı hücreden başlayan yatay/dikey
    // iki kelime ayrı sayılmalı (TS'teki aynı imza).
    final e = fw.coords.last;
    final s = fw.coords.first;
    final sig = '${s.$1},${s.$2}-${e.$1},${e.$2}';
    if (seen.contains(sig)) return;
    seen.add(sig);
    result.add(fw);
  }

  // Ana kelime (yerleştirme yönünde).
  addWord(_fullWordWithCoords(board, placed, coords[0].$1, coords[0].$2,
      horiz ? 0 : 1, horiz ? 1 : 0));

  // Her yerleştirme için çapraz kelime.
  for (final p in coords) {
    final cdr = horiz ? 1 : 0;
    final cdc = horiz ? 0 : 1;
    addWord(_fullWordWithCoords(board, placed, p.$1, p.$2, cdr, cdc));
  }

  return result;
}
