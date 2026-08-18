// Kelimeki core — taş torbası (src/utils/bag.ts portu).
import '../data/tiles.dart';
import '../model/game_state.dart' show Board;
import '../model/tile.dart';
import '../rng.dart';

/// Karıştırılmış taş torbası. Ekleme sırası tileData sırasıdır; karıştırma
/// enjekte edilen Rng ile yapılır (TS buildBag + shuffle eşleniği).
List<Tile> buildBag(Rng rng) {
  final b = <Tile>[];
  for (final e in tileData.entries) {
    for (var i = 0; i < e.value.cnt; i++) {
      b.add(Tile(letter: e.key, pts: e.value.pts));
    }
  }
  return shuffleList(b, rng);
}

/// Torbadan en fazla n taş çeker — torbayı YERİNDE değiştirir (sondan çeker,
/// TS'teki Array.pop eşleniği).
List<Tile> drawTiles(List<Tile> bag, int n) {
  final d = <Tile>[];
  for (var i = 0; i < n && bag.isNotEmpty; i++) {
    d.add(bag.removeLast());
  }
  return d;
}

class RemainingLetter {
  final String letter;
  final int pts;
  final int count;
  const RemainingLetter({required this.letter, required this.pts, required this.count});
}

String _tileKey(Tile t) => (t.wild || t.letter == '?') ? '?' : t.letter;

/// "Dışarıda" kalan taşlar: dağılımdan tahta + bakanın rafı + bu turda
/// konmuş ama henüz onaylanmamış (`state.placed`) taşlar düşülür.
///
/// `placedTiles` ATLANMAMALI: bekleyen taşlar raftan ÇIKAR ama tahtaya ancak
/// onayla yazılır — sayılmazlarsa "dışarıda" görünüp rakibin elinde sanılırlar
/// (web `src/utils/bag.ts` ile aynı düzeltme).
List<RemainingLetter> remainingTiles(Board board, List<Tile> myRack,
    [List<Tile> placedTiles = const []]) {
  final counts = <String, int>{
    for (final e in tileData.entries) e.key: e.value.cnt
  };
  void dec(Tile t) {
    final k = _tileKey(t);
    if (counts.containsKey(k)) counts[k] = counts[k]! - 1;
  }

  for (final row in board) {
    for (final cell in row) {
      if (cell != null) dec(cell);
    }
  }
  for (final t in myRack) {
    dec(t);
  }
  for (final t in placedTiles) {
    dec(t);
  }

  return [
    for (final e in tileData.entries)
      RemainingLetter(
        letter: e.key,
        pts: e.value.pts,
        count: counts[e.key]! < 0 ? 0 : counts[e.key]!,
      ),
  ];
}
