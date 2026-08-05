// Kelimeki core — YZ rakip mantığı (src/utils/ai.ts portu).
//
// Determinizm notu: eşit puanlı adaylar arasında "ilk bulunan kazanır"
// (yalnızca kesin büyükse güncelleme) — TS ile aynı. Bu yüzden kelime
// havuzunun SIRASI (WordSource.pool ekleme sırası) davranışın parçasıdır.
import '../constants.dart';
import '../data/tiles.dart';
import '../dictionary/word_source.dart';
import '../model/game_state.dart' show Board;
import '../model/player.dart';
import '../model/results.dart';
import '../model/tile.dart';
import '../model/types.dart';
import '../rules/board.dart';
import '../rules/validator.dart';
import '../text/turkish.dart';

// WordSource başına bir kez hesaplanan 2-7 harfli büyük-harf havuzu
// (TS'teki modül-seviyesi wordPool önbelleğinin eşleniği).
final Expando<List<String>> _poolCache = Expando<List<String>>();

List<String> _getWordPool(WordSource words) {
  var pool = _poolCache[words];
  if (pool == null) {
    pool = [
      for (final w in words.pool)
        if (w.length >= 2 && w.length <= 7) trUpper(w),
    ];
    _poolCache[words] = pool;
  }
  return pool;
}

/// Pozisyon/harf listesi için rafı tüketerek taşları üretir; tam harf yoksa
/// joker kullanılır. Raf yetmezse null.
List<Tile>? _consumeRack(List<String> letters, List<String> rackLetters, int owner) {
  final avail = [...rackLetters];
  final tiles = <Tile>[];
  for (final L in letters) {
    final i = avail.indexOf(L);
    if (i >= 0) {
      avail.removeAt(i);
      tiles.add(Tile(letter: L, pts: letterPoints(L), owner: owner));
    } else {
      final wi = avail.indexOf('?');
      if (wi < 0) return null;
      avail.removeAt(wi);
      tiles.add(Tile(letter: '?', pts: 0, wild: true, wildLetter: L, owner: owner));
    }
  }
  return tiles;
}

/// Sırası gelen YZ oyuncusu için en iyi hamle (yoksa null → pas/değişim).
AIMove? findAIMove(
  Board board,
  List<Tile> rack,
  Map<String, BonusType> bonuses,
  int owner,
  List<int> corners,
  bool isFirstMove,
  List<Player> players,
  WordSource words,
) {
  final rackLetters = [for (final t in rack) t.letter];
  final pool = _getWordPool(words);

  List<String>? candidatesCache;
  List<String> candidates() {
    candidatesCache ??= [
      for (final w in pool)
        if (canSpell(w, rackLetters)) w,
    ];
    return candidatesCache!;
  }

  final anchoredCandidatesCache = <String, List<String>>{};
  List<String> candidatesForAnchor(String letter) {
    var cached = anchoredCandidatesCache[letter];
    if (cached == null) {
      cached = [
        for (final w in pool)
          if (w.contains(letter) && canSpell(w, [...rackLetters, letter])) w,
      ];
      anchoredCandidatesCache[letter] = cached;
    }
    return cached;
  }

  AIMove? bestSafe;
  AIMove? bestAny;
  num bestAnyEffective = double.negativeInfinity;

  final territories = computeAllTerritories(board, players);

  void consider(List<Placement> placements, String word) {
    final placed = <String, Tile>{};
    for (final p in placements) {
      placed[cellKey(p.r, p.c)] = p.tile;
    }
    // Oluşan tüm kelimeler (çapraz dahil) sözlükte olmalı.
    for (final fw in getFormedWords(board, placed)) {
      if (!words.contains(trLower(fw.word))) return;
    }
    final touchedIdx = <int>{};
    void addIfForeign(int r, int c) {
      final k = cellKey(r, c);
      for (var i = 0; i < territories.length; i++) {
        if (i != owner && territories[i].contains(k)) touchedIdx.add(i);
      }
    }

    for (final p in placements) {
      addIfForeign(p.r, p.c);
      final neighbors = [
        (p.r - 1, p.c),
        (p.r + 1, p.c),
        (p.r, p.c - 1),
        (p.r, p.c + 1),
      ];
      for (final n in neighbors) {
        if (n.$1 < 0 || n.$1 >= boardSize || n.$2 < 0 || n.$2 >= boardSize) {
          continue;
        }
        addIfForeign(n.$1, n.$2);
      }
    }
    final score = calcScore(board, placed, bonuses);
    if (touchedIdx.isEmpty) {
      if (bestSafe == null || score > bestSafe!.score) {
        bestSafe = AIMove(word: word, score: score, placements: placements);
      }
      if (score > bestAnyEffective) {
        bestAnyEffective = score;
        bestAny = AIMove(word: word, score: score, placements: placements);
      }
      return;
    }
    // Paylaşım sonrası YZ'ye kalacak puan — computeInvasionSplit ile aynı
    // formül; territories önbelleğinden yararlanmak için split fonksiyonunun
    // kendisi çağrılmaz (TS'teki aynı gerekçe), pay hesabı ortak
    // `invasionShare`den gelir.
    final n = touchedIdx.length;
    final share = invasionShare(score, n);
    final effective = score - share * n;
    if (effective > bestAnyEffective) {
      bestAnyEffective = effective;
      bestAny = AIMove(word: word, score: score, placements: placements);
    }
  }

  // Verilen köşeden, mevcut taşlardan bağımsız yeni kelimeyle başlayan tüm
  // yerleşimler (ilk hamle).
  void tryCornerStart(int homeCorner) {
    final b = cornerBounds(homeCorner);
    final home = cornerCell(homeCorner);
    for (var sr = b.r0; sr <= b.r1; sr++) {
      for (var sc = b.c0; sc <= b.c1; sc++) {
        for (final W in candidates()) {
          for (final horiz in [true, false]) {
            final er = horiz ? sr : sr + W.length - 1;
            final ec = horiz ? sc + W.length - 1 : sc;
            if (er >= boardSize || ec >= boardSize) continue;
            var ok = true;
            var touchesCorner = false;
            final positions = <Cell>[];
            for (var i = 0; i < W.length; i++) {
              final rr = horiz ? sr : sr + i;
              final cc = horiz ? sc + i : sc;
              if (board[rr][cc] != null) {
                ok = false;
                break;
              }
              if (rr == home.$1 && cc == home.$2) touchesCorner = true;
              positions.add((rr, cc));
            }
            if (!ok || !touchesCorner) continue;
            final tiles = _consumeRack(W.split(''), rackLetters, owner);
            if (tiles == null) continue;
            consider(
              [
                for (var i = 0; i < positions.length; i++)
                  Placement(r: positions[i].$1, c: positions[i].$2, tile: tiles[i]),
              ],
              W,
            );
          }
        }
      }
    }
  }

  // ── İlk hamle: kendi köşelerinden birinden başla ─────────────────────────
  if (isFirstMove) {
    for (final homeCorner in corners) {
      tryCornerStart(homeCorner);
    }
    return bestSafe;
  }

  // ── Çapalı hamleler: tahtadaki her taşı eksen alarak dene ────────────────
  void tryPlace(String W, int r, int c, int idx, bool horiz) {
    final sr = horiz ? r : r - idx;
    final sc = horiz ? c - idx : c;
    if (horiz) {
      if (sc < 0 || sc + W.length > boardSize) return;
      if (!((sc == 0 || board[r][sc - 1] == null) &&
          (sc + W.length == boardSize || board[r][sc + W.length] == null))) {
        return;
      }
    } else {
      if (sr < 0 || sr + W.length > boardSize) return;
      if (!((sr == 0 || board[sr - 1][c] == null) &&
          (sr + W.length == boardSize || board[sr + W.length][c] == null))) {
        return;
      }
    }

    final newLetters = <String>[];
    final newPositions = <Cell>[];
    for (var i = 0; i < W.length; i++) {
      final rr = horiz ? r : sr + i;
      final cc = horiz ? sc + i : c;
      final existing = board[rr][cc];
      if (existing != null) {
        if (tileLetter(existing) != W[i]) return; // mevcut taşla uyuşmuyor
      } else {
        newLetters.add(W[i]);
        newPositions.add((rr, cc));
      }
    }
    if (newLetters.isEmpty) return; // en az bir yeni taş konmalı
    if (newLetters.length > rackLetters.length) return;
    final tiles = _consumeRack(newLetters, rackLetters, owner);
    if (tiles == null) return;
    consider(
      [
        for (var i = 0; i < newPositions.length; i++)
          Placement(r: newPositions[i].$1, c: newPositions[i].$2, tile: tiles[i]),
      ],
      W,
    );
  }

  for (var r = 0; r < boardSize; r++) {
    for (var c = 0; c < boardSize; c++) {
      final anchorTile = board[r][c];
      if (anchorTile == null) continue;
      final anchor = tileLetter(anchorTile);
      for (final W in candidatesForAnchor(anchor)) {
        var idx = W.indexOf(anchor);
        while (idx >= 0) {
          tryPlace(W, r, c, idx, true);
          tryPlace(W, r, c, idx, false);
          idx = W.indexOf(anchor, idx + 1);
        }
      }
    }
  }

  // Oyuncu başına tek köşe olduğundan pratikte tetiklenmez (TS'teki not).
  for (final homeCorner in freshCorners(board, corners, owner)) {
    tryCornerStart(homeCorner);
  }

  return bestSafe ?? bestAny;
}
