// Kelimeki core — kelime doğrulama, bölge kuralları ve puanlama
// (src/utils/validator.ts portu). Türkçe hata mesajları web ile birebir aynı
// tutulmalı — golden vector karşılaştırması mesaj metnini de kapsar.
import '../constants.dart';
import '../dictionary/word_source.dart';
import '../model/game_state.dart' show Board, Placed;
import '../model/history_entry.dart' show WordScore;
import '../model/player.dart';
import '../model/results.dart';
import '../model/types.dart';
import '../text/turkish.dart';
import 'board.dart';

/// Verilen harf havuzuyla kelime hecelenebilir mi? Joker ('?') jokeri sayar.
bool canSpell(String word, List<String> rack) {
  final avail = [...rack];
  for (var ci = 0; ci < word.length; ci++) {
    final ch = word[ci];
    final i = avail.indexOf(ch);
    if (i >= 0) {
      avail.removeAt(i);
    } else {
      final wi = avail.indexOf('?');
      if (wi >= 0) {
        avail.removeAt(wi);
      } else {
        return false;
      }
    }
  }
  return true;
}

/// Oyuncunun henüz hiç kendi taşının bulunmadığı ("taze") köşeleri.
List<int> freshCorners(Board board, List<int> ownCorners, int owner) {
  return ownCorners.where((corner) {
    final b = cornerBounds(corner);
    for (var r = b.r0; r <= b.r1; r++) {
      for (var c = b.c0; c <= b.c1; c++) {
        if (board[r][c]?.owner == owner) return false;
      }
    }
    return true;
  }).toList();
}

/// Yapısal doğrulama — hizalama, süreklilik, köşe/bağlantı kuralları, kelime
/// varlığı; sözlük kontrolü YAPILMAZ.
ValidationResult validatePlacementStructural(
  Board board,
  Placed placed,
  int owner,
  List<int> ownCorners,
  bool isFirstMove,
) {
  final keys = placed.keys.toList();
  if (keys.isEmpty) {
    return const ValidationResult(valid: false, reason: 'Harf yerleştirilmedi.');
  }

  final coords = [for (final k in keys) parseKey(k)];
  final rows = {for (final p in coords) p.$1}.toList();
  final cols = {for (final p in coords) p.$2}.toList();
  final horiz = rows.length == 1;
  final vert = cols.length == 1;
  if (!horiz && !vert) {
    return const ValidationResult(
        valid: false, reason: 'Harfler aynı satır ya da sütunda olmalı.');
  }

  // Süreklilik: aradaki her hücre ya bu turda konmuş ya önceden tahtada olmalı.
  if (horiz) {
    final r = rows[0];
    final minC = cols.reduce((a, b) => a < b ? a : b);
    final maxC = cols.reduce((a, b) => a > b ? a : b);
    for (var c = minC; c <= maxC; c++) {
      if (placed[cellKey(r, c)] == null && board[r][c] == null) {
        return const ValidationResult(
            valid: false, reason: 'Harfler arasında boşluk bırakılamaz.');
      }
    }
  } else {
    final c = cols[0];
    final minR = rows.reduce((a, b) => a < b ? a : b);
    final maxR = rows.reduce((a, b) => a > b ? a : b);
    for (var r = minR; r <= maxR; r++) {
      if (placed[cellKey(r, c)] == null && board[r][c] == null) {
        return const ValidationResult(
            valid: false, reason: 'Harfler arasında boşluk bırakılamaz.');
      }
    }
  }

  final fresh = freshCorners(board, ownCorners, owner);
  final startsFreshCorner = coords.any((p) => fresh.any((corner) {
        final cc = cornerCell(corner);
        return p.$1 == cc.$1 && p.$2 == cc.$2;
      }));

  if (isFirstMove) {
    if (!startsFreshCorner) {
      return const ValidationResult(
          valid: false, reason: 'İlk kelimen kendi köşe karesine değmeli.');
    }
  } else {
    final connects = coords.any((p) {
      final neighbors = [
        (p.$1 - 1, p.$2),
        (p.$1 + 1, p.$2),
        (p.$1, p.$2 - 1),
        (p.$1, p.$2 + 1),
      ];
      return neighbors.any((n) =>
          n.$1 >= 0 &&
          n.$1 < boardSize &&
          n.$2 >= 0 &&
          n.$2 < boardSize &&
          board[n.$1][n.$2] != null);
    });
    // Bağlanmıyorsa taze köşeden bağımsız başlangıç da geçerli.
    if (!connects && !startsFreshCorner) {
      return const ValidationResult(
          valid: false, reason: 'Kelime mevcut harflere bağlanmalı.');
    }
  }

  final formed = getFormedWords(board, placed);
  if (formed.isEmpty) {
    return const ValidationResult(valid: false, reason: 'Geçerli kelime oluşmadı.');
  }

  return ValidationResult(valid: true, words: [for (final f in formed) f.word]);
}

/// Geçersiz kelimeleri tek Türkçe hata mesajında birleştirir.
String formatInvalidWordsReason(List<String> words) {
  final quoted = [for (final w in words) '"$w"'];
  final list = quoted.length <= 1
      ? quoted.join('')
      : '${quoted.sublist(0, quoted.length - 1).join(', ')} ve ${quoted.last}';
  return quoted.length > 1
      ? '$list geçerli kelimeler değil.'
      : '$list geçerli bir kelime değil.';
}

/// Yapısal doğrulama + sözlük kontrolü.
ValidationResult validatePlacement(
  Board board,
  Placed placed,
  int owner,
  List<int> ownCorners,
  bool isFirstMove,
  WordSource words,
) {
  final structural =
      validatePlacementStructural(board, placed, owner, ownCorners, isFirstMove);
  if (!structural.valid) return structural;

  // Sıra korunarak tekilleştir (TS: Array.from(new Set(...)) — ekleme sırası).
  final invalidWords = <String>[];
  final seen = <String>{};
  for (final word in structural.words ?? const <String>[]) {
    if (!words.contains(trLower(word)) && seen.add(word)) {
      invalidWords.add(word);
    }
  }
  if (invalidWords.isNotEmpty) {
    return ValidationResult(
        valid: false, reason: formatInvalidWordsReason(invalidWords));
  }
  return structural;
}

/// Bir oyuncunun köşesinden kendi taşları üzerinden ortogonal bağlı "fetih"
/// zinciri. Seed: köşe sınırları içindeki, başka oyuncuya ait taş TAŞIMAYAN
/// tüm hücreler (boş köşe hücreleri "geçit" sayılır — bkz. TS yorumları).
Set<String> _computeConqueredChain(Board board, List<int> ownCorners, int owner) {
  final chain = <String>{};
  final stack = <Cell>[];
  for (final corner in ownCorners) {
    final b = cornerBounds(corner);
    for (var r = b.r0; r <= b.r1; r++) {
      for (var c = b.c0; c <= b.c1; c++) {
        final cell = board[r][c];
        if (cell != null && cell.owner != owner) continue;
        final k = cellKey(r, c);
        if (!chain.contains(k)) {
          chain.add(k);
          stack.add((r, c));
        }
      }
    }
  }
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final neighbors = [
      (p.$1 - 1, p.$2),
      (p.$1 + 1, p.$2),
      (p.$1, p.$2 - 1),
      (p.$1, p.$2 + 1),
    ];
    for (final n in neighbors) {
      if (n.$1 < 0 || n.$1 >= boardSize || n.$2 < 0 || n.$2 >= boardSize) {
        continue;
      }
      final k = cellKey(n.$1, n.$2);
      if (chain.contains(k)) continue;
      if (board[n.$1][n.$2]?.owner == owner) {
        chain.add(k);
        stack.add(n);
      }
    }
  }
  return chain;
}

/// Tüm oyuncuların bölgeleri. Teslim olmuş oyuncunun bölgesi boş küme —
/// hücreleri doğal/sahipsiz alana döner (TS yorumlarındaki tüm kurallar).
List<Set<String>> computeAllTerritories(Board board, List<Player> players) {
  final chains = [
    for (var i = 0; i < players.length; i++)
      players[i].surrendered
          ? <String>{}
          : _computeConqueredChain(board, players[i].corners, i),
  ];
  return [
    for (var i = 0; i < players.length; i++)
      _territoryFor(players[i], i, chains),
  ];
}

Set<String> _territoryFor(Player p, int i, List<Set<String>> chains) {
  if (p.surrendered) return <String>{};
  final territory = <String>{...chains[i]};
  for (final corner in p.corners) {
    final b = cornerBounds(corner);
    for (var r = b.r0; r <= b.r1; r++) {
      for (var c = b.c0; c <= b.c1; c++) {
        final k = cellKey(r, c);
        if (territory.contains(k)) continue;
        var capturedByOther = false;
        for (var j = 0; j < chains.length; j++) {
          if (j != i && chains[j].contains(k)) {
            capturedByOther = true;
            break;
          }
        }
        if (!capturedByOther) territory.add(k);
      }
    }
  }
  return territory;
}

/// Bölge sahibi başına vergi payı: round(basePts*(n+1)/(6n)). TS'te bu ifade
/// hem computeInvasionSplit'te hem ai.ts'te inline tekrarlanır — Dart'ta tek
/// fonksiyon, iki çağrı yeri de bunu kullanır. JS Math.round pozitiflerde
/// Dart .round() ile aynı (yarım → yukarı); kapsamlı tarama vektörü
/// (invasion_formula.json, basePts 0..1500 × n 1..3) bunu kanıtlar.
int invasionShare(int basePts, int n) => ((basePts * (n + 1)) / (6 * n)).round();

/// Rakip bölge(ler)ine ödenecek bölge vergisi: her bölge sahibinin payı
/// round(basePts*(n+1)/(6n)); yuvarlama farkı oynayanda kalır.
/// `shares` sırası dokunulan bölgelerin KEŞİF sırasıdır (TS Set insertion
/// order) — moveHistory satır sırası buna bağlı.
InvasionSplit computeInvasionSplit(
  List<Cell> coords,
  int ownerIndex,
  List<Player> players,
  int basePts,
  Board board,
) {
  final territories = computeAllTerritories(board, players);
  final touchedIdx = <int>{}; // LinkedHashSet — ekleme sırası korunur.
  void addIfForeign(int r, int c) {
    final k = cellKey(r, c);
    for (var i = 0; i < territories.length; i++) {
      if (i != ownerIndex && territories[i].contains(k)) touchedIdx.add(i);
    }
  }

  for (final p in coords) {
    addIfForeign(p.$1, p.$2);
    final neighbors = [
      (p.$1 - 1, p.$2),
      (p.$1 + 1, p.$2),
      (p.$1, p.$2 - 1),
      (p.$1, p.$2 + 1),
    ];
    for (final n in neighbors) {
      if (n.$1 < 0 || n.$1 >= boardSize || n.$2 < 0 || n.$2 >= boardSize) {
        continue;
      }
      addIfForeign(n.$1, n.$2);
    }
  }
  if (touchedIdx.isEmpty) {
    return InvasionSplit(pts: basePts, shares: const []);
  }
  final n = touchedIdx.length;
  final share = invasionShare(basePts, n);
  final shares = [
    for (final index in touchedIdx) InvasionShare(index: index, amount: share)
  ];
  return InvasionSplit(pts: basePts - share * n, shares: shares);
}

/// Bir kelimenin harf puanları toplamı — X2/X3 çarpanı uygulanmadan.
int _wordRawPoints(List<Cell> coords, Board board, Placed placed) {
  var sum = 0;
  for (final p in coords) {
    final k = cellKey(p.$1, p.$2);
    final pts = placed[k]?.pts ?? board[p.$1][p.$2]?.pts ?? 0;
    sum += pts;
  }
  return sum;
}

({bool x2, bool x3}) _wordBonusFlags(
  List<Cell> coords,
  Placed placed,
  Map<String, BonusType> bonuses,
) {
  var hasTw = false;
  var touchesZone = false;
  for (final p in coords) {
    final k = cellKey(p.$1, p.$2);
    final newTile = placed[k];
    if (newTile != null && bonuses[k] == BonusType.tw) hasTw = true;
    if (newTile != null && inBonusZone(p.$1, p.$2)) touchesZone = true;
  }
  return (x2: !hasTw && touchesZone, x3: hasTw);
}

int _wordPoints(
  List<Cell> coords,
  Board board,
  Placed placed,
  Map<String, BonusType> bonuses,
) {
  final flags = _wordBonusFlags(coords, placed, bonuses);
  final wordMult = flags.x3 ? 3 : (flags.x2 ? 2 : 1);
  return _wordRawPoints(coords, board, placed) * wordMult;
}

/// Bu turda oluşan tüm kelimelerin toplam puanı (+ bingo bonusu).
int calcScore(Board board, Placed placed, Map<String, BonusType> bonuses) {
  var total = 0;
  for (final fw in getFormedWords(board, placed)) {
    total += _wordPoints(fw.coords, board, placed, bonuses);
  }
  if (placed.length >= rackSize) total += bingoBonus;
  return total;
}

/// Her kelimenin çarpansız harf toplamı + değdiği bonus rozetleri.
List<WordScore> calcWordRawScores(
  Board board,
  Placed placed,
  Map<String, BonusType> bonuses,
) {
  return [
    for (final fw in getFormedWords(board, placed))
      () {
        final flags = _wordBonusFlags(fw.coords, placed, bonuses);
        return WordScore(
          word: fw.word,
          score: _wordRawPoints(fw.coords, board, placed),
          x2: flags.x2,
          x3: flags.x3,
        );
      }(),
  ];
}
