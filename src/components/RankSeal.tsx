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
  const fontSize = text.length <= 1 ? (compact ? 27 : 19) : text.length <= 3 ? 14 : 11;
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
      {/* Küçük boyda tırtık alt-piksel gürültüsüne döner (18px'te diş
          derinliği <1px) — kompakt mühür DÜZ çemberde kalır. */}
      {compact ? (
        <circle cx="22" cy="22" r="20.5" fill="#F5F7FA" stroke="currentColor" strokeWidth="2.5" />
      ) : (
        <polygon
          points={SCALLOP_POINTS}
          fill="#F5F7FA"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinejoin="round"
        />
      )}
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
        y="22.5"
        textAnchor="middle"
        dominantBaseline="central"
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
