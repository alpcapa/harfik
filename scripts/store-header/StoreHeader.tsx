// Kelimeki — mağaza başlık (header) görseli: 2048×1152 CSS px, 2× ile
// 4096×2304. Google Play Games "header/landscape image" yuvası için
// (JPEG ya da 24-bit PNG, şeffaflık YOK, en fazla 1 MB).
//
// ⚠ BAŞLIK GÖRSELİ KIRPILIR: mağaza yüzeyleri bu 16:9 kareyi kendi
// düzenlerine göre (daha geniş/daha dar şeritlere, hatta kareye) kesiyor ve
// üstüne kendi arayüzünü bindirebiliyor. Bu yüzden tasarım `kapak.tsx`
// ile AYNI ilkeye göre kuruldu: "ortada güvenli kutu + kenarlarda taşan
// dekor" — okunması gereken her şey (logo, slogan) ortadaki 1024 px'lik
// kutuda, iki yandaki tahtalar bilerek kadraj dışına taşıyor.
//
// Poster/kapak setiyle aynı ilkeler: tahtalar üretimdeki
// `GameBoardPreview`→`Board`, logo `LandingLogo`; Tailwind SINIFI YOK (bu
// dosya `scripts/` altında, tailwind content'i burayı taramıyor), yalnızca
// inline `style`.
import { renderToStaticMarkup } from 'react-dom/server';
import { LandingLogo, LandingLogoDefs } from '../../src/landing/LandingLogo';
import { GameBoardPreview } from '../../src/components/GameBoardPreview';
import { DEMO_TILES_2, DEMO_TILES_4 } from '../../src/landing/demoBoard';

const W = 2048;
const H = 1152;
/** `Board`un kendi `max-w` değeri — ölçek hesabının paydası. */
const BOARD_BASE_W = 680;
const OLCEK = 1.9;
const TAHTA = BOARD_BASE_W * OLCEK;

/** Ortadaki güvenli kutu — en dar (kare) kırpmada bile tamamen içeride. */
const GUVENLI_KUTU = 1024;

const SANS = '"Space Grotesk", sans-serif';

/**
 * Dekor tahtası. Kap (`stil`) tuvalin YARISINI kaplar, tahta o kabın içinde
 * `ic` ile kaydırılır: tahtanın KENDİ kart kenarları (yuvarlatılmış köşe +
 * gölge) dört yandan da kırpılıp kadraj dışında kalır, yani görünür hiçbir
 * kenar çizgisi yok. İki yarı tam ortada (x = W/2) uç uca birleşiyor —
 * birleşme yeri perdenin en opak noktası, dolayısıyla görünmüyor.
 *
 * ⚠ İki tahtayı ÜST ÜSTE BİNDİRME: ikisi de yarı saydam olduğundan
 * bindirme bölgesinde harfler birbirinin içinden geçip "hayalet" ikinci bir
 * satır üretiyor (denendi, alt orta bölgede gözle görülüyordu).
 */
function Tahta({
  tiles, sayi, stil, ic,
}: {
  tiles: typeof DEMO_TILES_2;
  sayi: number;
  stil: React.CSSProperties;
  ic: React.CSSProperties;
}) {
  return (
    <div style={{ position: 'absolute', top: 0, height: H, width: W / 2, overflow: 'hidden', opacity: 0.42, ...stil }}>
      <div
        style={{
          position: 'absolute',
          width: BOARD_BASE_W,
          transform: `scale(${OLCEK})`,
          transformOrigin: 'top left',
          ...ic,
        }}
      >
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

function StoreHeader() {
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

      {/* Dekor: tuvalin iki yarısı, iki ayrı tahta; kenarları kadraj dışında. */}
      <Tahta tiles={DEMO_TILES_2} sayi={2} stil={{ left: 0 }} ic={{ left: -160, top: -70 }} />
      <Tahta tiles={DEMO_TILES_4} sayi={4} stil={{ left: W / 2 }} ic={{ left: -108, top: -70 }} />

      {/* Ortadaki güvenli kutunun arkasına yumuşak beyaz perde — tahtalar
          metnin altında kalmasın diye (opaklık tek başına yetmiyor). */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'radial-gradient(ellipse 820px 700px at 50% 50%, rgba(255,255,255,0.98) 52%, rgba(255,255,255,0) 100%)',
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
        <div
          data-guvenli-kutu=""
          style={{ width: GUVENLI_KUTU, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 42 }}
        >
          <LandingLogo height={196} />
          <p style={{ margin: 0, fontSize: 68, lineHeight: 1.22, fontWeight: 700, letterSpacing: -1 }}>
            Kelime bul, bölgeni büyüt,
            <br />
            tahtayı ele geçir.
          </p>
        </div>
      </div>
    </div>
  );
}

export function renderStoreHeaderHtml(cssHref: string): string {
  return `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><title>Kelimeki mağaza başlığı</title>
<link rel="stylesheet" href="${cssHref}">
<style>html,body{margin:0;padding:0;background:#fff}</style>
</head><body>${renderToStaticMarkup(<StoreHeader />)}</body></html>`;
}
