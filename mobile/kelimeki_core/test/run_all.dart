// Kelimeki core — golden vector parite testleri.
//
// Fixture'lar web'in ÜRETİM motorundan üretilir
// (scripts/generate-golden-vectors.ts, repo kökünde); bu dosya aynı
// action'ları Dart motorunda aynı tohumla yeniden oynatıp state'leri derin
// karşılaştırır. Koşturma: `dart run test/run_all.dart` (kelimeki_core
// dizininden; önce `dart pub get`).
import 'dart:convert';
import 'dart:io';

import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/action_codec.dart';
import 'support/mini_test.dart';

late final SetWordSource words;

Map<String, Object?> loadGolden(String name) {
  final f = File('test/goldens/$name.json');
  return (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
}

void testTurkish() {
  final g = loadGolden('turkish');
  for (final row in g['lower'] as List) {
    final input = (row as List)[0] as String;
    final expected = row[1] as String;
    check(trLower(input) == expected,
        () => 'turkish.lower("$input"): "${trLower(input)}" != "$expected"');
  }
  for (final row in g['upper'] as List) {
    final input = (row as List)[0] as String;
    final expected = row[1] as String;
    check(trUpper(input) == expected,
        () => 'turkish.upper("$input"): "${trUpper(input)}" != "$expected"');
  }
  for (final row in g['compare'] as List) {
    final a = (row as List)[0] as String;
    final b = row[1] as String;
    final expected = row[2] as int;
    final got = trCompare(a, b);
    final sign = got > 0 ? 1 : (got < 0 ? -1 : 0);
    check(sign == expected, () => 'turkish.compare("$a","$b"): $sign != $expected');
  }
}

void testInvasionFormula() {
  final g = loadGolden('invasion_formula');
  final maxBase = g['maxBase'] as int;
  final shares = (g['shares'] as Map).cast<String, Object?>();
  for (final n in [1, 2, 3]) {
    final expected = (shares['$n'] as List).cast<int>();
    for (var base = 0; base <= maxBase; base++) {
      final got = invasionShare(base, n);
      check(got == expected[base],
          () => 'invasionShare($base, $n): $got != ${expected[base]}');
    }
  }
}

Player _stubPlayer(int score, bool surrendered) => Player(
      name: '',
      corners: const [0],
      colorIndex: 0,
      isAI: false,
      surrendered: surrendered,
      rack: const [],
      score: score,
      bestMoveScore: 0,
      bestWordScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    );

void testRanking() {
  final g = loadGolden('ranking');
  var ci = 0;
  for (final c in g['cases'] as List) {
    final m = (c as Map).cast<String, Object?>();
    final specs = [
      for (final p in m['players'] as List)
        (
          score: (p as Map)['score'] as int,
          surrendered: p['surrendered'] as bool,
        ),
    ];
    final players = [for (final s in specs) _stubPlayer(s.score, s.surrendered)];

    final ranked = rankPlayers(players);
    final expectedRanked = [
      for (final r in m['ranked'] as List)
        (index: (r as Map)['index'] as int, rank: r['rank'] as int),
    ];
    check(ranked.length == expectedRanked.length,
        () => 'ranking[$ci]: uzunluk ${ranked.length}');
    for (var i = 0; i < ranked.length && i < expectedRanked.length; i++) {
      check(
          ranked[i].index == expectedRanked[i].index &&
              ranked[i].rank == expectedRanked[i].rank,
          () =>
              'ranking[$ci][$i]: (${ranked[i].index},${ranked[i].rank}) != (${expectedRanked[i].index},${expectedRanked[i].rank})');
    }

    final snapshots = [
      for (final s in specs)
        PlayerSnapshot(score: s.score, surrendered: s.surrendered),
    ];
    final ranks = computeRanks(snapshots);
    final expectedRanks = (m['ranks'] as List).cast<int>();
    check(jsonDiff(expectedRanks, ranks) == null,
        () => 'ranking[$ci].computeRanks: $ranks != $expectedRanks');

    final expectedLeague = (m['league'] as List).cast<int>();
    for (var i = 0; i < specs.length; i++) {
      final got = leaguePoints(ranks[i], specs.length,
          surrendered: specs[i].surrendered);
      check(got == expectedLeague[i],
          () => 'ranking[$ci].league[$i]: $got != ${expectedLeague[i]}');
    }
    ci++;
  }
}

void testScoring() {
  final g = loadGolden('scoring');
  var ci = 0;
  for (final c in g['cases'] as List) {
    final m = (c as Map).cast<String, Object?>();
    final board = createEmptyBoard();
    for (final bc in m['board'] as List) {
      final b = (bc as Map).cast<String, Object?>();
      board[b['r'] as int][b['c'] as int] =
          Tile.fromJson((b['tile'] as Map).cast<String, Object?>());
    }
    final placed = <String, Tile>{
      for (final e in (m['placed'] as Map).entries)
        e.key as String: Tile.fromJson((e.value as Map).cast<String, Object?>()),
    };
    final bonuses = {'6,6': BonusType.tw};
    final total = calcScore(board, placed, bonuses);
    check(total == m['total'] as int,
        () => 'scoring[$ci].total: $total != ${m['total']}');
    final wordsGot = [for (final w in calcWordRawScores(board, placed, bonuses)) w.toJson()];
    final d = jsonDiff(m['words'], wordsGot);
    check(d == null, () => 'scoring[$ci].words: fark $d');
    ci++;
  }
}

void testReducerScenario(String name) {
  final g = loadGolden(name);
  final seed = g['seed'] as int;
  final engine = GameEngine(
    words: words,
    rng: Mulberry32(seed),
    nowIso: () => '',
  );
  var state = createInitialState();
  var si = 0;
  for (final step in g['steps'] as List) {
    final m = (step as Map).cast<String, Object?>();
    final action = decodeAction((m['action'] as Map).cast<String, Object?>());
    state = engine.reduce(state, action);
    final expected = m['state'];
    if (expected != null) {
      final actual = gameStateToJson(state);
      final d = jsonDiff(expected, actual);
      check(d == null,
          () => '$name adım $si (${(m['action'] as Map)['type']}): fark $d');
      if (d != null) return; // ayrışan state'ten sonrası anlamsız — kes
    }
    si++;
  }
}

void main() {
  final wordsFile = File('../app/assets/dictionary/words_tr.txt');
  if (!wordsFile.existsSync()) {
    stderr.writeln('words_tr.txt yok — önce `npm run generate-golden-vectors` koş.');
    exit(2);
  }
  words = SetWordSource(
    const LineSplitter().convert(wordsFile.readAsStringSync()).where((w) => w.isNotEmpty),
  );
  stdout.writeln('sözlük: ${words.length} kelime');

  testTurkish();
  testInvasionFormula();
  testRanking();
  testScoring();
  for (final name in [
    'reducer_ai2',
    'reducer_ai4',
    'reducer_human2',
    'reducer_crafted_finish',
    'reducer_crafted_ai_exchange',
    'reducer_sync',
  ]) {
    testReducerScenario(name);
  }
  summarizeAndExit();
}
