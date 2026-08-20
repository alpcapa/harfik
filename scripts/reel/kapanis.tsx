// Kelimeki — reel'in kapanış karesi (540×960 CSS px, 2× ile 1080×1920).
// Poster setiyle aynı ilke: logo `LandingLogo`, renkler/gölge derlenmiş
// uygulama CSS'inden. Tailwind SINIFI KULLANILMIYOR (bu dosya `scripts/`
// altında, tailwind content'i burayı taramıyor) — tek istisna, `src/`te
// zaten geçtiği için derlenmiş CSS'te bulunan `btn-raised`.
import { renderToStaticMarkup } from 'react-dom/server';
import { LandingLogo, LandingLogoDefs } from '../../src/landing/LandingLogo';

const MONO = '"Space Mono", monospace';
const SANS = '"Space Grotesk", sans-serif';

function Kapanis() {
  return (
    <div
      style={{
        // Kaydın viewport'u değişebiliyor (bant hesabı yüzünden 832) — sabit
        // 960 yazmak kartı alttan kırpardı.
        width: '100vw',
        height: '100vh',
        boxSizing: 'border-box',
        background: '#FFFFFF',
        color: '#1B2430',
        fontFamily: SANS,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 26,
        padding: '0 44px',
        textAlign: 'center',
      }}
    >
      <LandingLogoDefs />
      <LandingLogo height={104} />
      <p style={{ margin: 0, fontSize: 30, lineHeight: 1.25, fontWeight: 700, letterSpacing: -0.5 }}>
        Kelime bul, bölgeni büyüt,
        <br />
        tahtayı ele geçir.
      </p>
      <div
        className="btn-raised"
        style={{
          marginTop: 8,
          width: '100%',
          background: '#2563EB',
          border: '1px solid #2563EB',
          borderRadius: 18,
          color: '#FFFFFF',
          fontFamily: MONO,
          fontWeight: 700,
          fontSize: 24,
          letterSpacing: 1,
          padding: '20px 12px',
        }}
      >
        kelimeki.com
      </div>
      <span style={{ fontFamily: MONO, fontSize: 15, color: '#5A6673' }}>
        Ücretsiz · Kurulum yok · Üyelik gerekmez
      </span>
    </div>
  );
}

/**
 * Alt bant — kaydın 9:16'ya doldurulurken altta kalan şeride oturur.
 * Uygulama içeriği 540 px genişlikte 819 px sürüyor, kare ise 960; artan yeri
 * boş beyaz bırakmak yerine kalıcı bir adres şeridi yapıyoruz (reel'in amacı
 * trafik; izleyici videoyu sonuna kadar izlemese de adresi görüyor).
 */
function Bant() {
  return (
    <div
      style={{
        width: 540,
        height: 108,
        boxSizing: 'border-box',
        background: '#FFFFFF',
        borderTop: '2px solid #DCE2EA',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 18,
        fontFamily: SANS,
      }}
    >
      <LandingLogoDefs />
      <LandingLogo height={34} />
      <span style={{ fontFamily: MONO, fontSize: 26, fontWeight: 700, color: '#2563EB' }}>
        kelimeki.com
      </span>
    </div>
  );
}

export function renderBantHtml(cssHref: string): string {
  return `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><title>Kelimeki</title>
<link rel="stylesheet" href="${cssHref}">
<style>html,body{margin:0;padding:0;background:#fff}</style>
</head><body>${renderToStaticMarkup(<Bant />)}</body></html>`;
}

export function renderKapanisHtml(cssHref: string): string {
  return `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><title>Kelimeki</title>
<link rel="stylesheet" href="${cssHref}">
<style>html,body{margin:0;padding:0;background:#fff}</style>
</head><body>${renderToStaticMarkup(<Kapanis />)}</body></html>`;
}
