// Kelimeki — Google Play "feature graphic" (öne çıkan görsel), 1024×500.
//
// Play bu görseli mağaza sayfasının EN ÜSTÜNDE, bazı yüzeylerde de kırpılmış
// olarak gösteriyor; tanıtım videosu eklenirse ORTASINA bir oynat düğmesi
// bindiriyor. Bu yüzden kapak görselinin (scripts/kapak/) ilkesi aynen
// geçerli: okunması gereken her şey ortadaki güvenli kutuda, dekor kenardan
// taşıyor. **Tanıtım videosu eklenirse bu tasarım gözden geçirilmeli** —
// oynat düğmesi tam da logonun üstüne gelir.
//
// Tahtalar üretimdeki `GameBoardPreview`→`Board`, logo `LandingLogo`:
// ikinci bir tanıtım çizimi bu kod tabanının en sık hatasını (sessiz
// ayrışma) büyütürdü. Tailwind SINIFI YOK — bu dosya `scripts/` altında ve
// tailwind content'i burayı taramıyor, yalnızca inline `style` uygulanır.
import { renderToStaticMarkup } from 'react-dom/server';
import { LandingLogo, LandingLogoDefs } from '../../src/landing/LandingLogo';
import { GameBoardPreview } from '../../src/components/GameBoardPreview';
import { DEMO_TILES_2, DEMO_TILES_4 } from '../../src/landing/demoBoard';

const W = 1024;
const H = 500;
/** `Board`un kendi `max-w` değeri — ölçek hesabının paydası. */
const BOARD_BASE_W = 680;
const OLCEK = 0.86;
const TAHTA = BOARD_BASE_W * OLCEK;

const MONO = '"Space Mono", monospace';
const SANS = '"Space Grotesk", sans-serif';
const ACCENT = '#2563EB';

function Tahta({ tiles, sayi, stil }: { tiles: typeof DEMO_TILES_2; sayi: number; stil: React.CSSProperties }) {
  return (
    <div style={{ position: 'absolute', width: TAHTA, height: TAHTA, overflow: 'hidden', opacity: 0.4, ...stil }}>
      <div style={{ width: BOARD_BASE_W, transform: `scale(${OLCEK})`, transformOrigin: 'top left' }}>
        <GameBoardPreview
          snapshot={tiles}
          playerCount={sayi}
          compact={false}
          players={Array.from({ length: sayi }, (_, i) => ({
            name: '', score: 0, is_ai: false, colorIndex: i,
          }))}
        />
      </div>
    </div>
  );
}

function FeatureGraphic() {
  return (
    <div
      style={{
        width: W,
        height: H,
        position: 'relative',
        overflow: 'hidden',
        background: '#FFFFFF',
        fontFamily: SANS,
        color: '#1B2430',
      }}
    >
      <LandingLogoDefs />

      <Tahta tiles={DEMO_TILES_2} sayi={2} stil={{ left: -60, top: -60 }} />
      <Tahta tiles={DEMO_TILES_4} sayi={4} stil={{ right: -60, top: -60 }} />

      {/* Tahtalar metnin altında kalmasın diye yumuşak beyaz perde —
          opaklık tek başına yetmiyor (kapak görselinde ölçülmüştü). */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'radial-gradient(ellipse 380px 260px at 50% 50%, rgba(255,255,255,0.98) 55%, rgba(255,255,255,0) 100%)',
        }}
      />

      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          textAlign: 'center',
        }}
      >
        {/* Güvenli kutu — kenar kırpmalarına karşı pay bırakıyor. */}
        <div
          data-guvenli-kutu=""
          style={{ width: 600, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20 }}
        >
          <LandingLogo height={96} />
          <p style={{ margin: 0, fontSize: 34, lineHeight: 1.22, fontWeight: 700, letterSpacing: -0.4 }}>
            Kelime bul, bölgeni büyüt,
            <br />
            tahtayı ele geçir.
          </p>
          <span style={{ fontFamily: MONO, fontSize: 16, fontWeight: 700, color: ACCENT, letterSpacing: 0.4 }}>
            Yapay zekaya ve arkadaşlarına karşı
          </span>
          <span style={{ fontFamily: MONO, fontSize: 13, color: '#5A6673' }}>
            Ücretsiz · Reklamsız · TDK sözlüğüne dayalı
          </span>
        </div>
      </div>
    </div>
  );
}

export function renderFeatureGraphicHtml(cssHref: string): string {
  return `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><title>Kelimeki feature graphic</title>
<link rel="stylesheet" href="${cssHref}">
<style>html,body{margin:0;padding:0;background:#fff}</style>
</head><body>${renderToStaticMarkup(<FeatureGraphic />)}</body></html>`;
}
