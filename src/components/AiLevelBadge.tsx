// Kelimeki — oyun kartlarındaki YZ zorluk rozeti (ROADMAP #23, Faz 3).
//
// Normal'de HİÇ render edilmez (`null`): bugüne kadarki her kart bugünkü
// görünümünü aynen korur, rozet yalnızca seviye bugünkünden sapınca
// (Kolay/Zor) çıkar. Dört kart aynı bileşeni kullanır: GameOver ·
// GameHistoryModal · RecentGamesSection · SharedGamePage; Setup'ın "devam
// eden oyun" satırı da. Görsel dil `GameHistoryModal`ın "Yapay Zeka"
// rozetiyle aynı (kenarlıklı, %10 zemin, 7px mono) — yan yana duruyorlar.
// Port ikizi `mobile/app/lib/src/ui/ai_level_badge.dart` (Faz 4); metin
// `AI_LEVEL_LABEL`den, iki tarafta aynı (`ai_level_parity_test.dart`).
import { aiLevelBadgeLabel } from '../utils/aiLevel';

interface AiLevelBadgeProps {
  /** Ham değer: `GameState.aiLevel`, `games.ai_level` (null olabilir). */
  level: unknown;
  /** `xs` (7px, kart başlık satırı — varsayılan) · `sm` (9px, GameOver başlığı). */
  size?: 'xs' | 'sm';
}

export function AiLevelBadge({ level, size = 'xs' }: AiLevelBadgeProps) {
  const label = aiLevelBadgeLabel(level);
  if (!label) return null;
  const punto = size === 'sm' ? 'text-[9px] leading-[13px] px-1.5' : 'text-[7px] leading-[10px] px-[3px]';
  return (
    <span
      data-ai-level-badge={label}
      className={`text-gold font-bold normal-case border border-gold/40 bg-gold/10 rounded py-0 whitespace-nowrap shrink-0 ${punto}`}
    >
      {label}
    </span>
  );
}
