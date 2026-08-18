// Kelimeki — isimlerin yanındaki k-lig rütbe mührünün (RankSeal) puan
// kaynağı; web `src/hooks/useRankScores.tsx` portu.
//
// Kural: mühür HER ZAMAN GÜNCEL puandan türetilir (düşmeli sürüm, bkz.
// `league_rank.dart`) — sunucudaki `rank_tier` kolonu yalnızca "bu eşik
// kutlandı mı" kaydıdır, gösterimi sürmez.
//
// "Henüz bilinmiyor" ile "0 puan" AYRI durumlar: bir id için puan gelene
// kadar [tierOf] `null` döner ve çağıran mührü HİÇ çizmez — aksi halde liste
// bir an herkesi Çaylak gösterirdi. Puan geldikten sonra `leaderboard`
// view'ında bulunmayan id (hiç oyun bitirmemiş kullanıcı) 0 sayılır, yani
// gerçekten Çaylak.
library;

import 'package:flutter/foundation.dart';

import '../../data/stats_api.dart';
import 'league_rank.dart';

class RankScores extends ChangeNotifier {
  /// null = Supabase yapılandırılmamış (tam offline mod) → mühür hiç çizilmez.
  final StatsRepo? stats;

  RankScores(this.stats);

  final Map<String, int> _scores = {};
  final Set<String> _inFlight = {};
  bool _disposed = false;

  /// Bilinmiyorsa null (mühür çizilmez), biliniyorsa güncel puanın kademesi.
  RankTier? tierOf(String? userId) {
    if (userId == null) return null;
    final points = _scores[userId];
    return points == null ? null : tierFor(points);
  }

  /// Eksik id'ler için TEK toplu çekim başlatır. `build` içinden çağrılabilir:
  /// `notifyListeners` bilerek bir sonraki mikro göreve ertelenir (aksi halde
  /// "setState during build" hatası doğar).
  void ensure(Iterable<String?> userIds) {
    final repo = stats;
    if (repo == null) return;
    final missing = <String>{
      for (final id in userIds)
        if (id != null &&
            id.isNotEmpty &&
            !_scores.containsKey(id) &&
            !_inFlight.contains(id))
          id,
    };
    if (missing.isEmpty) return;
    _inFlight.addAll(missing);
    Future<void>(() async {
      final map = await repo.rankScores(missing.toList());
      _inFlight.removeAll(missing);
      // Hata (null) durumunda BİLİNEN puanlar korunur, eksikler bir sonraki
      // `ensure`da yeniden denenir.
      if (_disposed || map == null) return;
      for (final id in missing) {
        _scores[id] = map[id] ?? 0;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
