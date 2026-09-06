// Kelimeki — YZ zorluk rozeti (ROADMAP #23, Faz 3; renkler 6 Eylül 2026).
//
// Üç seviye üç renk (kullanıcı kararı): Kolay YEŞİL · Normal TURUNCU · Zor
// KIRMIZI. Normal artık da çizilir — rozet YZ oyununun her kartında var;
// yalnızca CANLI oyunlarda yok (orada seviye kavramı yok). "YZ oyunu mu"
// kararı çağıranda: `aiLevelForBadge(raw, isAiGame)` `null` dönerse bileşen
// hiç render edilmez (`gap` de açılmaz). Yüzeyler: GameOver · GameHistoryModal
// · RecentGamesSection · SharedGamePage · Setup'ın "devam eden oyun" satırı ·
// Board'un alt şeridi ("Hamleler"in yanı). Görsel dil `GameHistoryModal`ın
// "Yapay Zeka" rozetiyle aynı (kenarlıklı, %10 zemin, 7px mono).
// Port ikizi `mobile/app/lib/src/ui/ai_level_badge.dart`; metin
// `AI_LEVEL_LABEL`den, iki tarafta aynı (`ai_level_parity_test.dart`).
import type { AiLevel } from '../game/types';
import { AI_LEVEL_BADGE_CLASS, aiLevelBadgeLabel } from '../utils/aiLevel';

interface AiLevelBadgeProps {
  /** `aiLevelForBadge(...)` sonucu — `null`/`undefined` = rozet yok (Canlı oyun). */
  level: AiLevel | null | undefined;
  /** `xs` (7px, kart başlık satırı — varsayılan) · `sm` (9px, GameOver başlığı, tahta şeridi). */
  size?: 'xs' | 'sm';
}

export function AiLevelBadge({ level, size = 'xs' }: AiLevelBadgeProps) {
  const label = aiLevelBadgeLabel(level);
  if (!label || !level) return null;
  const punto = size === 'sm' ? 'text-[9px] leading-[13px] px-1.5' : 'text-[7px] leading-[10px] px-[3px]';
  return (
    <span
      data-ai-level-badge={label}
      className={`${AI_LEVEL_BADGE_CLASS[level]} font-bold normal-case border rounded py-0 whitespace-nowrap shrink-0 ${punto}`}
    >
      {label}
    </span>
  );
}
