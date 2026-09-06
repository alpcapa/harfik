// Kelimeki — YZ zorluk seviyesinin ÜRÜN yüzü (ROADMAP #23, Faz 3).
//
// Motor tarafı (`AiLevel` tipi, `AI_LEVEL_TOP_N`) `src/game/`de; burası
// yalnızca ekranların ortak kullandığı etiket/seçenek/ayrıştırma sözlüğü.
// Terminoloji tek: **Zorluk: Kolay · Normal · Zor** (23.4 — "kolay mod",
// "seviye" gibi üçüncü bir ifade ÜRETME; HelpModal ↔ Landing ↔ portun
// yardım ekranı aynı sözcükleri taşır).
import type { AiLevel } from '../game/types';

/** Kullanıcıya görünen etiket — rozetler, seçici, kart satırları. */
export const AI_LEVEL_LABEL: Record<AiLevel, string> = {
  kolay: 'Kolay',
  normal: 'Normal',
  zor: 'Zor',
};

/**
 * Setup'ta SEÇİLEBİLİR seviyeler, ekran sırasıyla. `zor` bilerek YOK: Zor
 * motoru Faz 5'te geliyor ve o güne kadar Normal'le aynı oynardı — seçici
 * "Zor" sunup Normal'i oynatmak (üstelik +4 k-lig vererek) ürün yalanı
 * olurdu. Faz 5 kapanınca buraya `'zor'` eklenir, başka bir şey değişmez.
 */
export const SELECTABLE_AI_LEVELS: readonly AiLevel[] = ['kolay', 'normal'];

/**
 * Sunucudan/JSON'dan gelen ham değeri seviyeye çevirir: `null`/`undefined`/
 * bilinmeyen → Normal. Sunucudaki `league_points_for`ın `coalesce(p_ai_level,
 * 'normal')` sözleşmesinin ve Dart `AiLevelJson.parse`ın istemci eşi.
 */
export function aiLevelOf(raw: unknown): AiLevel {
  return raw === 'kolay' || raw === 'zor' ? raw : 'normal';
}

/**
 * Kartlarda rozet metni — Normal'de `null` (rozet YOK: bugüne kadarki her
 * kart aynen kalır, seviye yalnızca bugünkünden SAPINCA görünür — 23.3).
 */
export function aiLevelBadgeLabel(raw: unknown): string | null {
  const level = aiLevelOf(raw);
  return level === 'normal' ? null : AI_LEVEL_LABEL[level];
}
