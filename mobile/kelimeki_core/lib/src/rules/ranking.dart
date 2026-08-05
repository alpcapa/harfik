// Kelimeki core — oyun sonu sıralama (src/utils/ranking.ts portu).
//
// DİKKAT: JS Array.sort kararlı (stable); Dart List.sort DEĞİL. Kararlılık
// burada davranışsal sözleşmenin parçası (eşit skorlu oyuncular koltuk
// sırasını korur) — bu yüzden karşılaştırıcı indeks tie-break'iyle kararlı
// hale getirilir.
import '../model/player.dart';

class RankedPlayer {
  final Player player;
  final int index;
  final int rank;
  const RankedPlayer({required this.player, required this.index, required this.rank});
}

/// Teslim olanlar puandan bağımsız her zaman en sonda; aktifler kendi
/// aralarında puana göre azalan; eşit puan aynı sırayı paylaşır.
List<RankedPlayer> rankPlayers(List<Player> players) {
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

  var rank = 0;
  int? prevScore;
  var prevSurrendered = false;
  final result = <RankedPlayer>[];
  for (var pos = 0; pos < ordered.length; pos++) {
    final x = ordered[pos];
    if (prevScore == null ||
        x.p.score != prevScore ||
        x.p.surrendered != prevSurrendered) {
      rank = pos + 1;
    }
    prevScore = x.p.score;
    prevSurrendered = x.p.surrendered;
    result.add(RankedPlayer(player: x.p, index: x.index, rank: rank));
  }
  return result;
}
