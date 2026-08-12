// Kelimeki — k-lig rütbe mührü ("Mühür" konsepti): nömorfik yuvarlak damga,
// hafif -6° eğik (gerçek bir mühür vuruşu gibi), içte kesikli halka, ortada
// kademe harfi. k-lig listesi satırlarında, Skor Kartı başlığında ve ödül
// banner'ında (RewardBanner, glyph override'ıyla) kullanılır. Yeni bir
// kullanım yeri path/daireleri KOPYALAMASIN — RelationIcons ile aynı ilke.
import type { RankTier } from '../utils/leagueRank';

// Tırtıklı (noter mührü) dış kenar — 12 Ağustos 2026, kullanıcı isteği
// (referans görsel: testere dişli sertifika damgası). 24 diş; uç 21.0 /
// vadi 18.8 — stroke 2.0'ın yarısı taşınca 22'lik viewBox sınırında
// kırpılmadan kalır (eski düz çemberin 20.5 + 1.25 bütçesiyle aynı).
// Flutter portu (mobile/app/lib/src/ui/rank/rank_seal.dart) AYNI üç
// sabitle bir Path üretir — ikisi BİRLİKTE değişmeli.
const TEETH = 24;
const TIP_R = 21;
const VALLEY_R = 18.8;
const SCALLOP_POINTS = Array.from({ length: TEETH * 2 }, (_, i) => {
  const r = i % 2 === 0 ? TIP_R : VALLEY_R;
  const a = (i * Math.PI) / TEETH - Math.PI / 2;
  return `${(22 + r * Math.cos(a)).toFixed(2)},${(22 + r * Math.sin(a)).toFixed(2)}`;
}).join(' ');

// Ortadaki harfin taban çizgisi — MÜREKKEP kutusunun dikey ortası dairenin
// merkezine gelecek şekilde (12 Ağustos 2026, kullanıcı bildirdi: "Ç, Ş gibi
// altında kuyruk olan karakterler ortalı durmuyor, alta daha yakın duruyor").
//
// Eski hâli `dominantBaseline="central"` idi; o, mürekkebi değil FONT
// metriklerini (ascent/descent) ortalar. Chromium'da gerçek Space Mono 700
// ile ölçüldü (20× render + piksel tarama, daire merkezi 22): TÜM harfler
// ~1.2 birim aşağıdaydı, Ç/Ş ise sedilla yüzünden ~2.5 birim DAHA aşağıda —
// gözle görülen buydu.
//
// İki sabit de em cinsinden ÖLÇÜLDÜ (`canvas.measureText`, 100px): büyük
// harflerin mürekkep tepesi .70 (M/U/D) – .72 (yuvarlaklar; standart taşma),
// sedillanın taban çizgisi altına inmesi .21. Ortalamayı (.71) tek sabit
// olarak kullanmak altı harfin hepsinde sapmayı ±0.15'in altında tutuyor —
// harf başına tablo tutmaya gerek yok.
const INK_ASC_EM = 0.71;
const DESCENDER_EM = 0.21;
// Bu mühürde basılabilen TEK kuyruklu karakterler. Kademe harfleri kapalı bir
// küme (Ç M O U Ş D — `leagueRank.ts`), banner glyph'leri ise rakam ve "+".
// Yeni bir kademe harfi eklenirse burası da gözden geçirilmeli.
const DESCENDER_CHARS = /[ÇŞ]/;
const baselineY = (text: string, fontSize: number) =>
  22 + ((INK_ASC_EM - (DESCENDER_CHARS.test(text) ? DESCENDER_EM : 0)) / 2) * fontSize;

interface RankSealProps {
  tier: RankTier;
  size?: number;
  /** Ortadaki metin — verilmezse kademenin harfi. Banner "50" gibi bir
   * kilometre taşı sayısını ya da "+5" gibi bir ödülü basmak için kullanır. */
  glyph?: string;
  className?: string;
}

export function RankSeal({ tier, size = 20, glyph, className }: RankSealProps) {
  const text = glyph ?? tier.letter;
  // Küçük rozet boylarında (k-lig satırları gibi) iç kesikli halka çizilmez
  // ve harf büyütülür — 17-18px'lik bir mühürde 19'luk glyph ~7px'e düşüp
  // okunmaz kalıyordu (kullanıcı bildirdi); halkasız + 27'lik glyph ~10px
  // veriyor. Büyük boylarda (banner/başlık) tam detaylı mühür çizilir.
  const compact = size < 24;
  // Tek harf büyük, 2-3 karakter orta, daha uzunu küçük punto.
  //
  // Tam boyda 19 → 23 (12 Ağustos 2026, kullanıcı isteği: "rozet içindeki
  // harfleri büyüt"). 23 ÖLÇÜLMÜŞ tavan, tahmin değil: kademe harflerinin
  // (Ç M O U Ş D) `getBBox`'ı gerçek Space Mono 700 ile Chromium'da okundu,
  // merkeze en uzak köşe Ç'de 23'te 15.48 / 24'te 16.20 — iç kesikli halka
  // r=16 olduğundan 24'te Ç/Ş'nin sedillası halkayı taşıyor.
  //
  // Kompakt 27'DE KALDI. Tırtık her boya yayılınca kompaktın iç sınırı
  // daraldı (düz çemberin iç kenarı 19.25 → vadi iç kenarı 18.8 − 2/2 =
  // 17.8), ve harfin `getBBox` köşesi 27'de 18.17 çıkıyor — yani KUTU
  // taşıyor. Ama kutunun köşesi boş: aynı harfler 20× ölçekte render edilip
  // PİKSEL taranınca (Chromium, gerçek Space Mono 700) en uzak MÜREKKEP
  // 27'de 16.56 (Ç; Ş 16.47, M 13.16, D 12.79, U 11.13, O 11.11) — sınıra
  // 1.24 birim var. Yuvarlak harflerde bbox köşesini sınır sanmak yanlış
  // pozitif üretir; ölçüm mürekkeple yapılmalı.
  const fontSize = text.length <= 1 ? (compact ? 27 : 23) : text.length <= 3 ? 14 : 11;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 44 44"
      role="img"
      aria-label={glyph ? undefined : `Rütbe: ${tier.name}`}
      aria-hidden={glyph ? true : undefined}
      className={className}
      style={{ color: tier.color, transform: 'rotate(-6deg)' }}
    >
      {/* Tırtık HER BOYDA — 12 Ağustos 2026, kullanıcı isteği ("leaderboard'daki
          küçük rozetlerde tırtık olamıyor mu?"). İlk sürümde kompakt mühür düz
          çemberdi, gerekçesi "18px'te diş derinliği <1px, alt-piksel
          gürültüsüne döner" idi — bu ÖLÇÜLMEDEN yazılmış ve YANLIŞTI: hesap
          DPR 1 varsayıyordu, retina bir ekranda (DPR 3) 0.9 CSS px = 2.7 cihaz
          pikseli, yani dişler net çıkıyor (Chromium'da 18px/DPR3 render edilip
          büyütülerek doğrulandı). Diş sayısı da BİLEREK aynı (24): tek bir
          siluet, tek bir sabit seti. */}
      <polygon
        points={SCALLOP_POINTS}
        fill="#F5F7FA"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinejoin="round"
      />
      {!compact && (
        <circle
          cx="22"
          cy="22"
          r="16"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.2"
          strokeDasharray="2.5 3.5"
          opacity="0.55"
        />
      )}
      <text
        x="22"
        y={baselineY(text, fontSize)}
        textAnchor="middle"
        fontFamily="'Space Mono', monospace"
        fontWeight="700"
        fontSize={fontSize}
        fill="currentColor"
      >
        {text}
      </text>
    </svg>
  );
}
