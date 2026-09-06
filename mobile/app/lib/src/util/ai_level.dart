// Kelimeki — YZ zorluk seviyesinin ÜRÜN yüzü (web `src/utils/aiLevel.ts`
// portu, ROADMAP #23 Faz 4).
//
// Motor tarafı (`AiLevel` enum'u, `aiLevelTopN`) `kelimeki_core`da; burası
// yalnızca ekranların ortak kullandığı etiket/seçenek/rozet sözlüğü.
// Terminoloji tek: **Zorluk: Kolay · Normal · Zor** (ROADMAP 23.4 — "kolay
// mod", "seviye" gibi üçüncü bir ifade ÜRETME; web Setup/HelpModal ↔ port
// aynı sözcükleri taşır). `ai_level_parity_test.dart` bu dosyayı web
// kaynağıyla karşılaştırıyor: etiketler, seçilebilir liste, Kolay açıklaması.
import 'package:kelimeki_core/kelimeki_core.dart';

/// Kullanıcıya görünen etiket — rozetler, seçici, kart satırları
/// (web `AI_LEVEL_LABEL`). Setup butonu bunu `trUpper` ile büyütür (web'de
/// CSS `uppercase`), rozet olduğu gibi (web `normal-case`) yazar.
const Map<AiLevel, String> aiLevelLabel = {
  AiLevel.kolay: 'Kolay',
  AiLevel.normal: 'Normal',
  AiLevel.zor: 'Zor',
};

/// Setup'ta SEÇİLEBİLİR seviyeler, ekran sırasıyla (web
/// `SELECTABLE_AI_LEVELS`). `zor` bilerek YOK: Zor motoru Faz 5'te geliyor
/// ve o güne kadar Normal'le aynı oynardı — seçici "Zor" sunup Normal'i
/// oynatmak (üstelik +4 k-lig vererek) ürün yalanı olurdu. Faz 5 kapanınca
/// web ile AYNI PR'da buraya `AiLevel.zor` eklenir, başka bir şey değişmez.
const List<AiLevel> selectableAiLevels = [AiLevel.kolay, AiLevel.normal];

/// Kolay seçilince seçicinin altında çıkan tek cümlelik açıklama — web
/// `Setup.tsx` ile BİREBİR aynı metin (parite testi karşılaştırıyor).
const String kolayAciklamasi =
    "Kolay'da Yapay Zeka en iyi hamleyi değil, en iyi birkaç hamleden "
    'birini oynar. k-lig puanı da yarıya iner: birinci +1, 4 kişilikte '
    'ikinci 0.';

/// Kartlarda rozet metni — Normal'de (ve null'da) `null`: rozet YOK, bugüne
/// kadarki her kart aynen kalır, seviye yalnızca bugünkünden SAPINCA
/// görünür (web `aiLevelBadgeLabel`). null = seviyesiz eski kayıt / Canlı
/// oyun / Normal — üçü de sunucunun `coalesce(ai_level, 'normal')`
/// sözleşmesiyle Normal.
String? aiLevelBadgeLabel(AiLevel? level) =>
    level == null || level == AiLevel.normal ? null : aiLevelLabel[level];
