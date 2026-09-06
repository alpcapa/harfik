// Kelimeki — oyun kartlarındaki YZ zorluk rozeti (web
// `src/components/AiLevelBadge.tsx` portu, ROADMAP #23 Faz 4).
//
// Normal'de (ve null'da) HİÇ çizilmez: bugüne kadarki her kart bugünkü
// görünümünü aynen korur, rozet yalnızca seviye bugünkünden sapınca
// (Kolay/Zor) çıkar. Üç kart + Setup'ın "devam eden oyun" satırı aynı
// widget'ı kullanır: GameOverModal · GameHistoryModal · RecentGamesSection ·
// _SavedGameRow. Görsel dil `game_history_modal.dart`ın `_Badge`iyle aynı
// (kenarlıklı, %10 zemin, 7px kalın) — yan yana duruyorlar; renk altın.
//
// ⚠ Çağıran, rozetin önündeki boşluğu `aiLevelBadgeLabel(level) != null`
// koşuluyla eklesin — web'de `null` dönen bileşen flex `gap`i de açmıyor,
// Normal kartın ölçüleri bayt bayt aynı kalmalı. Widget'ın kendisi görünmez
// hâlde `SizedBox.shrink()` döner ki koşulsuz da kullanılabilsin.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../util/ai_level.dart';
import 'tokens.dart';

enum AiLevelBadgeSize {
  /// 7px — kart başlık satırı (varsayılan; web `xs`).
  xs,

  /// 9px — GameOver başlığının altı (web `sm`).
  sm,
}

class AiLevelBadge extends StatelessWidget {
  /// `GameState.aiLevel` / `GameHistoryEntry.aiLevel` — null = Normal.
  final AiLevel? level;
  final AiLevelBadgeSize size;

  const AiLevelBadge({super.key, required this.level, this.size = AiLevelBadgeSize.xs});

  @override
  Widget build(BuildContext context) {
    final label = aiLevelBadgeLabel(level);
    if (label == null) return const SizedBox.shrink();
    final sm = size == AiLevelBadgeSize.sm;
    return Container(
      // web: `px-[3px] py-0` (xs) · `px-1.5` (sm); dikey 1px `_Badge` ile
      // aynı, yoksa 7px metin kenarlığa yapışıyor.
      padding: EdgeInsets.symmetric(horizontal: sm ? 6 : 3, vertical: 1),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.1),
        border: Border.all(color: kGold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: sm ? 9 : 7,
          fontWeight: FontWeight.bold,
          color: kGold,
        ),
      ),
    );
  }
}
