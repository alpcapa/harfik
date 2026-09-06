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
import '../rng.dart';
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

/// Sınırlı en-iyi listesinin bir satırı (TS: Ranked).
class _Ranked {
  final AIMove move;

  /// Sıralama anahtarı: güvenli listede ham puan, vergili listede YZ'ye kalan.
  final int rank;
  const _Ranked(this.move, this.rank);
}

/// Azalan `rank` sırasıyla, eşitte SONA (ilk bulunan önde) ekler; boyutu n'de
/// tutar. Eski tek-en-iyi `>` karşılaştırmasının liste karşılığı — `sort`
/// bilerek YOK (kararlılık garantisi yok; ROADMAP 23.4). TS `insertBounded`
/// ile adım adım aynı.
void _insertBounded(List<_Ranked> list, _Ranked item, int n) {
  var i = 0;
  while (i < list.length && list[i].rank >= item.rank) {
    i++;
  }
  if (i >= n) return;
  list.insert(i, item);
  if (list.length > n) list.removeRange(n, list.length);
}

/// Sırası gelen YZ oyuncusu için en iyi [n] hamle, iyiden kötüye sıralı (boş
/// liste → pas/değişim). Vergisiz hamle varsa liste YALNIZCA onlardan oluşur;
/// yoksa vergili hamlelerden, YZ'ye kalacak puana göre. Rastgele değer
/// TÜKETMEZ — seçim [pickTopMove]/[findAIMove]'un işi. (TS: findAIMoves)
List<AIMove> findAIMoves(
  Board board,
  List<Tile> rack,
  Map<String, BonusType> bonuses,
  int owner,
  List<int> corners,
  bool isFirstMove,
  List<Player> players,
  WordSource words,
  int n,
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

  // İki sınırlı liste: `safe` vergisiz hamleler, `any` (YZ'ye kalacak puana
  // göre) tüm hamleler — TS'teki aynı adlar. Faz 2'ye kadar iki TEK en-iyi
  // tutuluyordu; n=1'de liste başı eskisiyle birebir aynı hamle.
  final safe = <_Ranked>[];
  final any = <_Ranked>[];

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
      for (final nb in neighbors) {
        if (nb.$1 < 0 || nb.$1 >= boardSize || nb.$2 < 0 || nb.$2 >= boardSize) {
          continue;
        }
        addIfForeign(nb.$1, nb.$2);
      }
    }
    final score = calcScore(board, placed, bonuses);
    final move = AIMove(word: word, score: score, placements: placements);
    if (touchedIdx.isEmpty) {
      _insertBounded(safe, _Ranked(move, score), n);
      _insertBounded(any, _Ranked(move, score), n);
      return;
    }
    // Paylaşım sonrası YZ'ye kalacak puan — computeInvasionSplit ile aynı
    // formül; territories önbelleğinden yararlanmak için split fonksiyonunun
    // kendisi çağrılmaz (TS'teki aynı gerekçe), pay hesabı ortak
    // `invasionShare`den gelir.
    final k = touchedIdx.length;
    final share = invasionShare(score, k);
    _insertBounded(any, _Ranked(move, score - share * k), n);
  }

  // Verilen köşeden, mevcut taşlardan bağımsız yeni kelimeyle başlayan tüm
  // yerleşimler (ilk hamle).
  //
  // İlk hamlenin TEK şartı, konan hücrelerden birinin ev karesi olması — yön
  // ya da "4x4 blokta başla" şartı yok (bkz. validatePlacement). Bu yüzden
  // kelimenin HANGİ harfinin (`idx`) eve denk geleceği tek tek denenir; kelime
  // evden her iki yöne de uzayabilir. Döngü sırası web `tryCornerStart` ile
  // BİREBİR aynı olmak zorunda: `consider` eşit puanda İLK bulunanı tuttuğundan
  // sıra değişirse iki motor farklı hamle seçer ve parite sessizce kırılır.
  void tryCornerStart(int homeCorner) {
    final home = cornerCell(homeCorner);
    for (final W in candidates()) {
      for (var idx = 0; idx < W.length; idx++) {
        for (final horiz in [true, false]) {
          final sr = horiz ? home.$1 : home.$1 - idx;
          final sc = horiz ? home.$2 - idx : home.$2;
          if (sr < 0 || sc < 0) continue;
          final er = horiz ? sr : sr + W.length - 1;
          final ec = horiz ? sc + W.length - 1 : sc;
          if (er >= boardSize || ec >= boardSize) continue;
          var ok = true;
          final positions = <Cell>[];
          for (var i = 0; i < W.length; i++) {
            final rr = horiz ? sr : sr + i;
            final cc = horiz ? sc + i : sc;
            if (board[rr][cc] != null) {
              ok = false;
              break;
            }
            positions.add((rr, cc));
          }
          if (!ok) continue;
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

  // ── İlk hamle: kendi köşelerinden birinden başla ─────────────────────────
  if (isFirstMove) {
    for (final homeCorner in corners) {
      tryCornerStart(homeCorner);
    }
    return [for (final x in safe) x.move];
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

  return [for (final x in (safe.isNotEmpty ? safe : any)) x.move];
}

/// Sıralı listeden oynanacak hamle — RASTGELELİK SÖZLEŞMESİ (TS pickTopMove
/// ile birebir; golden'lar buna dayanır): boş → null; tek eleman → o eleman,
/// [rng] ÇAĞRILMAZ; birden fazla → TEK `nextDouble()`, `floor(r * length)`.
AIMove? pickTopMove(List<AIMove> list, Rng rng) {
  if (list.isEmpty) return null;
  if (list.length == 1) return list[0];
  return list[(rng.nextDouble() * list.length).floor()];
}

/// Sırası gelen YZ oyuncusu için oynanacak hamle (yoksa null → pas/değişim).
/// [level] `aiLevelTopN` üzerinden N'e çevrilir; Normal (N=1) hiç rastgele
/// değer tüketmez (TS: findAIMove).
AIMove? findAIMove(
  Board board,
  List<Tile> rack,
  Map<String, BonusType> bonuses,
  int owner,
  List<int> corners,
  bool isFirstMove,
  List<Player> players,
  WordSource words, {
  AiLevel level = AiLevel.normal,
  required Rng rng,
}) =>
    pickTopMove(
      findAIMoves(board, rack, bonuses, owner, corners, isFirstMove, players,
          words, aiLevelTopN[level]!),
      rng,
    );
