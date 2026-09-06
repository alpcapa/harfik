// Kelimeki — YZ zorluk rozeti (web `src/components/AiLevelBadge.tsx` portu,
// ROADMAP #23 Faz 4; renkler 6 Eylül 2026).
//
// Üç seviye üç renk (kullanıcı kararı): Kolay YEŞİL · Normal TURUNCU · Zor
// KIRMIZI (`kGreen`/`kOrange`/`kRed` — web `AI_LEVEL_BADGE_CLASS` ikizi).
// Normal da çizilir; yalnızca CANLI oyunda rozet yok — karar çağıranda
// (`aiLevelForBadge(raw, isAiGame:)` null dönerse widget `SizedBox.shrink()`
// döner; önündeki boşluğu çağıran `level != null` koşuluyla eklesin, web'de
// `null` dönen bileşen flex `gap`i de açmıyor). Yüzeyler: GameOverModal ·
// GameHistoryModal · RecentGamesSection · _SavedGameRow · BoardWidget alt
// şeridi. Görsel dil `game_history_modal.dart`ın `_Badge`iyle aynı
// (kenarlıklı, %10 zemin, 7px kalın).
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../util/ai_level.dart';
import 'tokens.dart';

enum AiLevelBadgeSize {
  /// 7px — kart başlık satırı (varsayılan; web `xs`).
  xs,

  /// 9px — GameOver başlığının altı ve tahta alt şeridi (web `sm`).
  sm,
}

/// Seviye → rozet rengi. Web `AI_LEVEL_BADGE_CLASS` ile aynı üçlü.
Color aiLevelBadgeColor(AiLevel level) => switch (level) {
      AiLevel.kolay => kGreen,
      AiLevel.normal => kOrange,
      AiLevel.zor => kRed,
    };

class AiLevelBadge extends StatelessWidget {
  /// `aiLevelForBadge(...)` sonucu — null = rozet yok (Canlı oyun).
  final AiLevel? level;
  final AiLevelBadgeSize size;

  const AiLevelBadge({super.key, required this.level, this.size = AiLevelBadgeSize.xs});

  @override
  Widget build(BuildContext context) {
    final lv = level;
    final label = aiLevelBadgeLabel(lv);
    if (lv == null || label == null) return const SizedBox.shrink();
    final sm = size == AiLevelBadgeSize.sm;
    final color = aiLevelBadgeColor(lv);
    return Container(
      // web: `px-[3px] py-0` (xs) · `px-1.5` (sm); dikey 1px `_Badge` ile
      // aynı, yoksa 7px metin kenarlığa yapışıyor.
      padding: EdgeInsets.symmetric(horizontal: sm ? 6 : 3, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: sm ? 9 : 7,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
