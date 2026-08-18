// Kelimeki — k-lig rütbe rozeti: dolu roset (dalgalı kenar) + içte açık halka
// + iki kurdele kuyruğu. k-lig listesi satırlarında, Skor Kartı başlığında,
// tanıtım sayfasında ve ödül banner'ında (RewardBanner, glyph override'ıyla)
// kullanılır. Yeni bir kullanım yeri path/daireleri KOPYALAMASIN —
// RelationIcons ile aynı ilke.
//
// 18 Ağustos 2026 — TIRTIKLI MÜHÜR TASARIMI TAMAMEN BIRAKILDI (kullanıcı:
// "Bizim rütbe badge'leri beğenmiyorum. Özellikle ince tırtıklar çok kötü.").
// Önceki tasarım açık zeminli, ince çizgili, 24 dişli, −6° eğik bir noter
// mührüydü; kullanıcı üç alternatif arasından hiçbirini değil, gönderdiği bir
// referans görselini (klasik ödül roseti: dolu madalyon + kurdele) seçip
// "birebir kopyala ve ona giydir" dedi. Buradaki bütün ölçüler o referansın
// oranlarından türetildi. Renk kademeden (`RankTier.color`) gelir.
//
// Öncekinden korunan TEK şey harf/glyph API'si (tier + opsiyonel glyph) —
// çağrı yerlerinin hiçbiri değişmedi.
//
// ⚠ Flutter portu (`mobile/app/lib/src/ui/rank/rank_seal.dart`) AYNI
// sabitlerle bir `Path` çiziyor — ikisi BİRLİKTE değişmeli.
import type { RankTier } from '../utils/leagueRank';

// ── Roset geometrisi (viewBox 44×44) ──────────────────────────────────────
// Madalyon merkezi yukarıda: alt üçte bir kurdeleye ayrıldı. Uç yarıçapı 15 +
// yuvarlatma stroke'unun yarısı (1) = 16, yani madalyon 0.6 ile 32.6 arasında
// kalıyor, kurdele 43.4'e iniyor — 44'lük kutuya kırpılmadan sığar.
const CY = 16.6;
const TIP_R = 15;
const VALLEY_R = 12.675; // 0.845 × uç — referanstaki dalga derinliği
const LOBES = 14;
const EDGE_W = 2; // yuvarlatma: `strokeLinejoin="round"` ile lobların ucu yumuşar

const LOBE_POINTS = Array.from({ length: LOBES * 2 }, (_, i) => {
  const r = i % 2 === 0 ? TIP_R : VALLEY_R;
  const a = (i * Math.PI) / LOBES - Math.PI / 2;
  return `${(22 + r * Math.cos(a)).toFixed(2)},${(CY + r * Math.sin(a)).toFixed(2)}`;
}).join(' ');

// İç halka — referanstaki açık renkli ince çember. Dış kenarı vadi
// yarıçapının 1 birim içinde kalıyor (dalgayla çakışmasın diye).
const RING_R = 11;
const RING_W = 1.3;

// Kurdele: üstü madalyonun ARKASINDA başlar (y=25), aşağı inerken dışa açılır
// (`SPLAY`), alt ucu V kesiktir. Referansın kuyruk genişliği/uzunluğu
// oranlarından ölçeklendi.
const TAIL_TOP = 25;
const TAIL_BOTTOM = 43.4;
const TAIL_W = 8.8;
const TAIL_SPLAY = 5.4;
const TAIL_NOTCH = 5.2;
const TAIL_INNER_X = 22.7;
const TAIL_OUTER_X = TAIL_INNER_X - TAIL_W;
const TAIL_LEFT = [
  [TAIL_INNER_X, TAIL_TOP],
  [TAIL_OUTER_X, TAIL_TOP],
  [TAIL_OUTER_X - TAIL_SPLAY, TAIL_BOTTOM],
  [TAIL_OUTER_X - TAIL_SPLAY / 2 + TAIL_W / 2, TAIL_BOTTOM - TAIL_NOTCH],
  [TAIL_INNER_X - TAIL_SPLAY, TAIL_BOTTOM - 1.5],
] as const;
const pts = (p: readonly (readonly [number, number])[]) =>
  p.map(([x, y]) => `${x.toFixed(2)},${y.toFixed(2)}`).join(' ');
const TAIL_LEFT_POINTS = pts(TAIL_LEFT);
const TAIL_RIGHT_POINTS = pts(TAIL_LEFT.map(([x, y]) => [44 - x, y] as const));

/** Kurdele, madalyondan ayrışsın diye kademe renginin bir tık koyusu. */
function darken(hex: string, f = 0.86) {
  const n = parseInt(hex.slice(1), 16);
  const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) =>
    Math.max(0, Math.min(255, Math.round(v * f))),
  );
  return `#${ch.map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

// ── Metin ─────────────────────────────────────────────────────────────────
// Yazı tipi M PLUS Rounded 1c ExtraBold (18 Ağustos 2026, kullanıcı seçimi:
// "daha basık ve yuvarlak hatlı bir font"). Altı aday GERÇEK rozetin içinde
// render edilip gösterildi; seçilen bu. Font bu proje için YENİ ve alt
// kümelenmiş olarak taşınıyor (6.3 KB) — bkz. src/fonts/mplus-rounded-seal.css
// ve kök CLAUDE.md → "Rütbe Rozeti Fontu".
//
// ⚠ Flutter portu AYNI fontu `assets/fonts/`ten yüklüyor; iki taraf da
// aşağıdaki sabitleri ELLE paylaşıyor.
//
// Ölçüler ÖLÇÜLDÜ, tahmin değil (Chromium, gerçek font, `canvas.measureText`in
// `actualBoundingBox*` alanları, em cinsinden): kademe harflerinin mürekkep
// tepesi .740–.750, sedillanın (Ç/Ş) taban altına inmesi .220. Aralık bu fontta
// çok dar olduğundan tek sabit çift yeterli — basılabilen HER glyph (dokuz
// kademe harfi + tüm banner rakamları) için azami merkezleme sapması
// 0.0075 em, yani 76px'lik banner mühründe 0.23 px (eski Space Grotesk'te
// 0.03 em idi).
const INK_ASC_EM = 0.745;
const DESCENDER_EM = 0.22;
const DESCENDER_CHARS = /[ÇŞ]/;
const baselineY = (text: string, fontSize: number) =>
  CY + ((INK_ASC_EM - (DESCENDER_CHARS.test(text) ? DESCENDER_EM : 0)) / 2) * fontSize;

// Punto merdiveni de ÖLÇÜLMÜŞ bir tavan — ve bu sefer hesapla DEĞİL, gerçek
// rozet 20× büyütülüp SİYAH zeminde render edilip beyaz harfin HER pikseli
// madalyon poligonuna karşı taranarak ölçüldü. Bu ayrım önemli: `textAnchor
// ="middle"` mürekkebi değil ADVANCE kutusunu ortalar, yani yan boşlukları
// asimetrik bir glyph ("+1000" gibi) hesaptan birkaç onda birim daha dışarı
// taşar — yalnızca `measureText` ile hesaplanan bir tavan bunu göremiyordu.
//
// Ölçülen paylar (viewBox birimi): tek harf halkanın iç kenarına (11 − 1.3/2)
// en kötü Ç'de +1.28; banner glyph'lerinin en kötüsü "+1000" poligonun 0.28
// DIŞINDA ama madalyonun 2 birimlik kenar stroke'unun (aynı renk, dolguyla
// birlikte tek bir disk) 0.72 İÇİNDE — geri kalan hepsi poligonun içinde.
//
// M PLUS'ın rakamları Space Grotesk'ten belirgin geniş olduğundan çok
// karakterli basamaklar küçüldü (13 → 12, 10.5 → 9.5, 8.5 → 8); tek harf
// AYNI kaldı (18 / kompakt 20.5 — ölçülen tavanlar hâlâ rahat tutuyor).
function fontSizeFor(text: string, compact: boolean) {
  const n = text.length;
  if (n <= 1) return compact ? 20.5 : 18;
  if (n <= 3) return 12;
  if (n <= 4) return 9.5;
  return 8;
}

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
  // Küçük boylarda (k-lig satırları) iç halka çizilmez ve harf büyütülür —
  // 18px'lik bir rozette halka ~0.5 px'e düşüp harfi de küçültüyordu.
  const compact = size < 24;
  const fontSize = fontSizeFor(text, compact);
  // Halka yalnızca TEK harfte: rakamlı glyph'ler ("1000", "+1000") halkanın
  // içine sığmıyor, sığdırmak için küçültmek de onları okunmaz yapıyordu.
  const showRing = !compact && text.length <= 1;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 44 44"
      role="img"
      aria-label={glyph ? undefined : `Rütbe: ${tier.name}`}
      aria-hidden={glyph ? true : undefined}
      className={className}
    >
      {/* Kurdeleler madalyonun ARKASINDA — üst uçları rozetin altında kalır. */}
      <polygon points={TAIL_LEFT_POINTS} fill={darken(tier.color)} />
      <polygon points={TAIL_RIGHT_POINTS} fill={darken(tier.color)} />
      <polygon
        points={LOBE_POINTS}
        fill={tier.color}
        stroke={tier.color}
        strokeWidth={EDGE_W}
        strokeLinejoin="round"
      />
      {showRing && (
        <circle
          cx="22"
          cy={CY}
          r={RING_R}
          fill="none"
          stroke="#F5F7FA"
          strokeOpacity="0.92"
          strokeWidth={RING_W}
        />
      )}
      <text
        x="22"
        y={baselineY(text, fontSize)}
        textAnchor="middle"
        fontFamily="'M PLUS Rounded 1c', sans-serif"
        fontWeight="800"
        fontSize={fontSize}
        fill="#fff"
      >
        {text}
      </text>
    </svg>
  );
}
