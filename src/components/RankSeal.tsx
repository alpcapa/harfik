// Kelimeki — k-lig rütbe mührü ("Mühür" konsepti): nömorfik yuvarlak damga,
// hafif -6° eğik (gerçek bir mühür vuruşu gibi), içte kesikli halka, ortada
// kademe harfi. k-lig listesi satırlarında, Skor Kartı başlığında ve ödül
// banner'ında (RewardBanner, glyph override'ıyla) kullanılır. Yeni bir
// kullanım yeri path/daireleri KOPYALAMASIN — RelationIcons ile aynı ilke.
import type { RankTier } from '../utils/leagueRank';

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
      <circle cx="22" cy="22" r="20.5" fill="#F5F7FA" stroke="currentColor" strokeWidth="2.5" />
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
