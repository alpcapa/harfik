// Kelimeki — Facebook sayfa kapak görseli (820×312 CSS px, 2× ile 1640×624).
//
// ⚠ FACEBOOK KAPAĞI İKİ FARKLI KIRPILIYOR: masaüstünde geniş-alçak
// (~820×312), telefonda dar-yüksek (~640×360) bir alan gösteriliyor; ayrıca
// masaüstünde profil fotoğrafı SOL ALT köşeyi örtüyor. Bu yüzden tasarım
// "ortada güvenli kutu + kenarlarda taşan dekor" ilkesine göre kuruldu:
// okunması gereken her şey (logo, slogan, adres) ortadaki ~480 px'lik
// şeritte; iki yandaki tahtalar bilerek kadraj dışına taşıyor, kırpılmaları
// hiçbir bilgi kaybettirmiyor.
//
// Poster setiyle aynı ilkeler: tahtalar üretimdeki `GameBoardPreview`→`Board`,
// logo `LandingLogo`; Tailwind SINIFI YOK (bu dosya `scripts/` altında,
// tailwind content'i burayı taramıyor), yalnızca inline `style`.
import { renderToStaticMarkup } from 'react-dom/server';
import { LandingLogo, LandingLogoDefs } from '../../src/landing/LandingLogo';
import { GameBoardPreview } from '../../src/components/GameBoardPreview';
import { DEMO_TILES_2, DEMO_TILES_4 } from '../../src/landing/demoBoard';

const W = 820;
const H = 312;
/** `Board`un kendi `max-w` değeri — ölçek hesabının paydası. */
const BOARD_BASE_W = 680;
const OLCEK = 0.62;
const TAHTA = BOARD_BASE_W * OLCEK;

const MONO = '"Space Mono", monospace';
const SANS = '"Space Grotesk", sans-serif';
const ACCENT = '#2563EB';

function Tahta({ tiles, sayi, stil }: { tiles: typeof DEMO_TILES_2; sayi: number; stil: React.CSSProperties }) {
  return (
    <div style={{ position: 'absolute', width: TAHTA, height: TAHTA, overflow: 'hidden', opacity: 0.42, ...stil }}>
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

function Kapak() {
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

      {/* Dekor: iki tahta, iki kenardan taşıyor. Sol alt köşe masaüstünde
          profil fotoğrafının altında kaldığı için sol tahta yukarı kaydırıldı. */}
      <Tahta tiles={DEMO_TILES_2} sayi={2} stil={{ left: -96, top: -74 }} />
      <Tahta tiles={DEMO_TILES_4} sayi={4} stil={{ right: -96, top: -74 }} />

      {/* Ortadaki güvenli kutunun arkasına yumuşak beyaz perde — tahtalar
          metnin altında kalmasın diye (opaklık tek başına yetmiyor). */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'radial-gradient(ellipse 300px 190px at 50% 50%, rgba(255,255,255,0.98) 55%, rgba(255,255,255,0) 100%)',
        }}
      />

      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 14,
          textAlign: 'center',
        }}
      >
        {/* Güvenli kutu: 480 px — telefonun dar kırpmasında da tamamen içeride. */}
        <div data-guvenli-kutu="" style={{ width: 480, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 13 }}>
          <LandingLogo height={62} />
          <p style={{ margin: 0, fontSize: 23, lineHeight: 1.25, fontWeight: 700, letterSpacing: -0.3 }}>
            Kelime bul, bölgeni büyüt,
            <br />
            tahtayı ele geçir.
          </p>
          <span style={{ fontFamily: MONO, fontSize: 15, fontWeight: 700, color: ACCENT, letterSpacing: 0.5 }}>
            kelimeki.com
          </span>
          <span style={{ fontFamily: MONO, fontSize: 12, color: '#5A6673' }}>
            Ücretsiz · Kurulum yok · Üyelik gerekmez
          </span>
        </div>
      </div>
    </div>
  );
}

export function renderKapakHtml(cssHref: string): string {
  return `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><title>Kelimeki kapak</title>
<link rel="stylesheet" href="${cssHref}">
<style>html,body{margin:0;padding:0;background:#fff}</style>
</head><body>${renderToStaticMarkup(<Kapak />)}</body></html>`;
}
