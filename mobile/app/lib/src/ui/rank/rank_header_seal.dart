// Skor Kartı / oyuncu kartı BAŞLIĞINDAKİ rütbe mührü — `KModal.headerCenter`
// yuvasına konur (web'de `Modal.headerCenter`, 12 Ağustos 2026 kullanıcı
// kararı: ilk sürüm ismin yanındaydı, sonra başlıkla ✕ arasına ortalandı).
//
// İKİ skor kartı da bunu kullanır (web'de iki dosyada birebir kopya duruyor;
// port tek kaynağa aldı — kural: bir görsel öğenin tüm kullanım yerleri tek
// kaynaktan, bkz. `CountBadge`/`RelationIcons`).
library;

import 'package:flutter/material.dart';

import '../../data/stats_api.dart';
import 'league_rank.dart';
import 'rank_info_modal.dart';
import 'rank_seal.dart';

/// [overall] "Genel" sekmesinin (`player_stats_overall`) satırı. Henüz
/// yüklenmediyse ([loaded] false) mühür GİZLİ — yanlış kademeyle bir an
/// bile çizmemek için (web'in `statsByTab.all !== undefined` koşulu).
/// Kademe GÜNCEL puandan türetilir (düşmeli sürüm).
Widget? rankHeaderSeal(
  BuildContext context, {
  required PlayerStats? overall,
  required bool loaded,
}) {
  if (!loaded) return null;
  final tier = tierFor(overall?.totalScore ?? 0);
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => showRankInfo(
      context,
      tier: tier,
      totalScore: overall?.totalScore ?? 0,
      bonusPoints: overall?.bonusPoints ?? 0,
    ),
    child: Semantics(
      button: true,
      label: 'Rütbe: ${tier.name} — bilgi için dokun',
      excludeSemantics: true,
      child: RankSeal(tier: tier, size: 34),
    ),
  );
}
