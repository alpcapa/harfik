// Kelimeki — YZ zorluk seviyesinin ÜRÜN yüzü (ROADMAP #23, Faz 3).
//
// Motor tarafı (`AiLevel` tipi, `AI_LEVEL_TOP_N`) `src/game/`de; burası
// yalnızca ekranların ortak kullandığı etiket/seçenek/ayrıştırma sözlüğü.
// Terminoloji tek: **Zorluk: Kolay · Normal · Zor** (23.4 — "kolay mod",
// "seviye" gibi üçüncü bir ifade ÜRETME; HelpModal ↔ Landing ↔ portun
// yardım ekranı aynı sözcükleri taşır).
import type { AiLevel } from '../game/types';
import { leaguePoints } from './leaguePoints';

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
 * Seçicinin altındaki açıklamanın İLK cümlesi — seviye kime göre, kullanıcıya
 * hitapla (kullanıcı kararı, 6 Eylül 2026: *"bilimsel iş yapmıyoruz"* — YZ'nin
 * nasıl zayıflatıldığı ürün metnine GİRMEZ). Portun `aiLevelPitch`i ile
 * birebir (`ai_level_parity_test.dart`). Zor'un metni Faz 5 açılana kadar
 * hiç gösterilmez ama burada hazır durur.
 */
export const AI_LEVEL_PITCH: Record<AiLevel, string> = {
  kolay:
    'Çok iyi değilim, daha yeni yeni alışıyorum, karşımda o kadar zor bir rakip istemiyorum diyorsanız doğru yerdesiniz.',
  normal:
    'Orta-iyi seviye bir oyuncuyum, sıradan oyunculardan biraz daha iyiyim diyorsanız burası size göre.',
  zor: 'Çok iyi oyuncuyum, genelde %80+ kazanırım diyorsanız bunu denemelisiniz.',
};

/** Puan cümlesinin fiili — kullanıcının verdiği metinde Zor'unki farklı. */
const AI_LEVEL_VERB: Record<AiLevel, string> = {
  kolay: 'kazandırır',
  normal: 'kazandırır',
  zor: 'kazandırıyor',
};

/**
 * Setup'ta seçili seviyenin altında çıkan açıklama: hitap cümlesi + o
 * seviyenin k-lig puanı. Sayılar `leaguePoints`ten türetilir (tablo TEK
 * kaynak — 23.0; metin tabloyla ayrışamaz). 2 kişilikte yalnızca birincilik,
 * 4 kişilikte ikincilik de yazılır (ikincilik 0 ise "puan kazandırmaz").
 * Portun `aiLevelDescription`ı aynı şablon; parite testi altı bileşimi de
 * tam metinle kilitler.
 */
export function aiLevelDescription(level: AiLevel, playerCount: number): string {
  const birinci = leaguePoints(1, playerCount, false, level);
  const ikinci = leaguePoints(2, playerCount, false, level);
  const fiil = AI_LEVEL_VERB[level];
  const puan =
    playerCount === 2
      ? `birincilik ${birinci} puan ${fiil}`
      : ikinci === 0
        ? `birincilik ${birinci} puan ${fiil}, ikincilik puan kazandırmaz`
        : `birincilik ${birinci}, ikincilik ${ikinci} puan ${fiil}`;
  return `${AI_LEVEL_PITCH[level]} Bu seviyede ${puan}.${level === 'zor' ? ' Bol şans!' : ''}`;
}

/**
 * Sunucudan/JSON'dan gelen ham değeri seviyeye çevirir: `null`/`undefined`/
 * bilinmeyen → Normal. Sunucudaki `league_points_for`ın `coalesce(p_ai_level,
 * 'normal')` sözleşmesinin ve Dart `AiLevelJson.parse`ın istemci eşi.
 */
export function aiLevelOf(raw: unknown): AiLevel {
  return raw === 'kolay' || raw === 'zor' ? raw : 'normal';
}

/**
 * Rozette gösterilecek seviye (6 Eylül 2026, kullanıcı kararı — "Kolay
 * yeşil, Normal turuncu, Zor kırmızı"): YZ oyunuysa ham değer, `null` =
 * Normal (seviyesiz eski kayıtlar dahil); Canlı oyunsa `null` → rozet YOK
 * (Canlı'da seviye kavramı yok). Çağıran "YZ oyunu mu" kararını verir:
 * kartlarda `online_game_id` boşluğu, paylaşım sayfasında kadroda YZ olması,
 * oyun ekranında App.tsx (OnlineGameScreen hiç geçirmez).
 */
export function aiLevelForBadge(raw: unknown, isAiGame: boolean): AiLevel | null {
  return isAiGame ? aiLevelOf(raw) : null;
}

/** Rozet metni — `null`/`undefined` seviye (Canlı oyun) → rozet yok. */
export function aiLevelBadgeLabel(level: AiLevel | null | undefined): string | null {
  return level ? AI_LEVEL_LABEL[level] : null;
}

/**
 * Rozet renk sınıfları — Tailwind JIT tam dizeleri görsün diye burada
 * birleştirilmeden yazılı (`tailwind.config.js` renkleri: green/orange/red).
 * Port ikizi `ai_level_badge.dart` → `_aiLevelBadgeColor` (kGreen/kOrange/kRed).
 */
export const AI_LEVEL_BADGE_CLASS: Record<AiLevel, string> = {
  kolay: 'text-green border-green/40 bg-green/10',
  normal: 'text-orange border-orange/40 bg-orange/10',
  zor: 'text-red border-red/40 bg-red/10',
};
