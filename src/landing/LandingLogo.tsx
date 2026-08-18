// Kelimeki — karşılama katmanında logoyu ÜÇ kez çizmek için SVG sprite'ı.
//
// NEDEN VAR (ÖLÇÜM): `LogoMark` her çağrıda "kelimeki" glyph'lerinin tam
// path verisini (11.760 bayt) HTML'e yazar. Karşılama sayfasında logo üç
// yerde geçiyor (kilitli başlıktaki park yuvası, kahraman, sayfa sonu) ve
// gzip bu kopyaları BİRLEŞTİREMİYOR — aralarındaki mesafe deflate'in 32 KB
// penceresini aşıyor. Ölçüldü: üç kopya `dist/index.html`in gzip boyutunun
// **10.377 baytını** (yani neredeyse yarısını) tek başına yiyordu.
//
// Çözüm, vektörü ikinci kez tanımlamak DEĞİL: path verisi hâlâ TEK KAYNAKTAN,
// `LogoMark.tsx`in dışa açtığı sabitlerden geliyor (o dosya
// `scripts/generate-logo-paths.mjs` tarafından üretiliyor — logo değişirse
// burası kendiliğinden takip eder). Burada yapılan tek şey path'i sayfada
// bir kez `<defs>`e koyup diğer kullanımları `<use>` ile ona bağlamak.
//
// ⚠ `LandingLogoDefs` sayfada TAM BİR KEZ ve `LandingLogo`lardan ÖNCE
// render edilmeli. Uygulama tarafı (`GameHeader`, `Setup`, `RewardBanner`…)
// bu dosyayı KULLANMAZ — orada logo tek kez çiziliyor ve `LogoMark` doğrudan
// kullanılmaya devam ediyor.
import {
  LOGO_COLOR,
  LOGO_TEXT_PATH,
  LOGO_UNDERLINE_PATH,
  LOGO_UNDERLINE_STROKE_WIDTH,
  LOGO_VIEW_BOX,
} from '../components/LogoMark';

const SPRITE_ID = 'kelimeki-logo-sprite';
const [, , VB_WIDTH, VB_HEIGHT] = LOGO_VIEW_BOX.split(' ').map(Number);

/** Sayfada bir kez: görünmez tanım bloğu. */
export function LandingLogoDefs() {
  return (
    <svg width="0" height="0" aria-hidden="true" style={{ position: 'absolute' }}>
      <defs>
        <g id={SPRITE_ID}>
          {/* `currentColor` — her kullanım yeri rengi CSS'ten verebilir;
              varsayılan `LogoMark`ın kendi rengiyle aynı. */}
          <path d={LOGO_TEXT_PATH} fill="currentColor" />
          <path
            d={LOGO_UNDERLINE_PATH}
            stroke="currentColor"
            strokeWidth={LOGO_UNDERLINE_STROKE_WIDTH}
            strokeLinecap="round"
            fill="none"
          />
        </g>
      </defs>
    </svg>
  );
}

interface LandingLogoProps {
  /** `LogoMark` ile aynı sözleşme: sabit piksel ya da akıcı bir CSS boyutu. */
  height: number | string;
  className?: string;
}

export function LandingLogo({ height, className }: LandingLogoProps) {
  const isFluid = typeof height === 'string';
  const width = isFluid ? undefined : (height * VB_WIDTH) / VB_HEIGHT;
  return (
    <svg
      width={isFluid ? undefined : width}
      height={isFluid ? undefined : height}
      viewBox={LOGO_VIEW_BOX}
      fill="none"
      aria-hidden="true"
      className={className}
      style={
        isFluid
          ? { height, width: 'auto', aspectRatio: `${VB_WIDTH} / ${VB_HEIGHT}`, color: LOGO_COLOR }
          : { color: LOGO_COLOR }
      }
    >
      <use href={`#${SPRITE_ID}`} />
    </svg>
  );
}
