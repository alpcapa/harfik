// Kelimeki core — HistoryEntry (src/game/types.ts portu).

/// Bir kelimenin çarpansız harf toplamı ve değdiği bonus rozetleri.
class WordScore {
  final String word;

  /// X2/X3 kelime çarpanı UYGULANMADAN harf puanları toplamı.
  final int score;
  final bool x2;
  final bool x3;

  const WordScore({
    required this.word,
    required this.score,
    required this.x2,
    required this.x3,
  });

  Map<String, Object?> toJson() =>
      {'word': word, 'score': score, 'x2': x2, 'x3': x3};

  factory WordScore.fromJson(Map<String, Object?> j) => WordScore(
        word: j['word'] as String,
        score: j['score'] as int,
        x2: j['x2'] as bool,
        x3: j['x3'] as bool,
      );
}

class LostShare {
  final int to;
  final int amount;
  const LostShare({required this.to, required this.amount});

  Map<String, Object?> toJson() => {'to': to, 'amount': amount};

  factory LostShare.fromJson(Map<String, Object?> j) =>
      LostShare(to: j['to'] as int, amount: j['amount'] as int);
}

/// Hamle geçmişinde tek satır. Opsiyonel alanlar TS'teki gibi JSON'da yalnızca
/// doluyken görünür (kanonik serileştirme — golden vector sözleşmesi).
class HistoryEntry {
  final int turn;
  final int player;
  final List<String> words;
  final List<WordScore>? wordScores;
  final int points;
  final int? invasionFrom;
  final List<LostShare>? lostShares;

  /// 'pass' | 'exchange' | 'surrender' — null ise kelime hamlesi.
  final String? action;
  final int? tileCount;
  final int? finishJokerCount;
  final bool bingo;

  const HistoryEntry({
    required this.turn,
    required this.player,
    required this.words,
    this.wordScores,
    required this.points,
    this.invasionFrom,
    this.lostShares,
    this.action,
    this.tileCount,
    this.finishJokerCount,
    this.bingo = false,
  });

  Map<String, Object?> toJson() => {
        'turn': turn,
        'player': player,
        'words': words,
        if (wordScores != null)
          'wordScores': [for (final w in wordScores!) w.toJson()],
        'points': points,
        if (invasionFrom != null) 'invasionFrom': invasionFrom,
        if (lostShares != null)
          'lostShares': [for (final s in lostShares!) s.toJson()],
        if (action != null) 'action': action,
        if (tileCount != null) 'tileCount': tileCount,
        if (finishJokerCount != null) 'finishJokerCount': finishJokerCount,
        if (bingo) 'bingo': true,
      };

  factory HistoryEntry.fromJson(Map<String, Object?> j) => HistoryEntry(
        turn: j['turn'] as int,
        player: j['player'] as int,
        words: [for (final w in j['words'] as List) w as String],
        wordScores: j['wordScores'] == null
            ? null
            : [
                for (final w in j['wordScores'] as List)
                  WordScore.fromJson((w as Map).cast<String, Object?>())
              ],
        points: j['points'] as int,
        invasionFrom: j['invasionFrom'] as int?,
        lostShares: j['lostShares'] == null
            ? null
            : [
                for (final s in j['lostShares'] as List)
                  LostShare.fromJson((s as Map).cast<String, Object?>())
              ],
        action: j['action'] as String?,
        tileCount: j['tileCount'] as int?,
        finishJokerCount: j['finishJokerCount'] as int?,
        bingo: j['bingo'] == true,
      );
}
