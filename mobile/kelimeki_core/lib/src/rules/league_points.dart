// Kelimeki core — k-lig puanı (src/utils/leaguePoints.ts portu).
import '../model/types.dart';

/// Bir oyuncunun bu oyundan kazandığı k-lig puanı — web `leaguePoints.ts`
/// ve sunucu `league_points_for()` ile AYNI tablo (ROADMAP 23.0):
/// teslim -2; 1. sıra Kolay 1 / Normal 2 / Zor 4; 2. sıra yalnız 4
/// kişilikte Kolay 0 / Normal 1 / Zor 2; diğer 0. `aiLevel` null = Normal
/// (seviyesiz eski kayıtlar, tüm Canlı oyunlar).
/// ⚠ Gövde TS eşiyle satır satır aynı dallanma — `npm run
/// verify-league-points` iki dosyanın sayı dizisini karşılaştırıyor.
int leaguePoints(int rank, int playerCount,
    {bool surrendered = false, AiLevel? aiLevel}) {
  if (surrendered) return -2;
  final kolay = aiLevel == AiLevel.kolay;
  final zor = aiLevel == AiLevel.zor;
  if (rank == 1) return kolay ? 1 : zor ? 4 : 2;
  if (rank == 2 && playerCount != 2) return kolay ? 0 : zor ? 2 : 1;
  return 0;
}

String formatLeaguePoints(int points) =>
    points > 0 ? '+$points' : (points < 0 ? '$points' : '-');

/// `computeRanks` girdisi — sunucudaki `games.players` jsonb satırının
/// (GamePlayerSnapshot) core'a bakan yüzü.
class PlayerSnapshot {
  final int score;
  final bool surrendered;
  const PlayerSnapshot({required this.score, this.surrendered = false});
}

/// Girdinin sırasından bağımsız, `rankPlayers` ile aynı kural: aktifler puana
/// göre azalan, teslim olanlar hep sonda. Dönüş girdiyle aynı indekslemede.
List<int> computeRanks(List<PlayerSnapshot> players) {
  final withIndex = [
    for (var i = 0; i < players.length; i++) (p: players[i], index: i)
  ];
  final active = withIndex.where((x) => !x.p.surrendered).toList()
    ..sort((a, b) {
      final d = b.p.score - a.p.score;
      return d != 0 ? d : a.index - b.index; // stable-sort eşleniği
    });
  final surrendered = withIndex.where((x) => x.p.surrendered).toList()
    ..sort((a, b) {
      final d = b.p.score - a.p.score;
      return d != 0 ? d : a.index - b.index;
    });
  final ordered = [...active, ...surrendered];

  final ranks = List<int>.filled(players.length, 1);
  var rank = 1;
  int? prevScore;
  var prevSurrendered = false;
  for (var pos = 0; pos < ordered.length; pos++) {
    final x = ordered[pos];
    if (prevScore == null ||
        x.p.score != prevScore ||
        x.p.surrendered != prevSurrendered) {
      rank = pos + 1;
    }
    prevScore = x.p.score;
    prevSurrendered = x.p.surrendered;
    ranks[x.index] = rank;
  }
  return ranks;
}
