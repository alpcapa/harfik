import { chromium } from 'playwright';
import sharp from 'sharp';
import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Embed the local Caveat Bold woff2 as a data URI so the browser
// renders the font identically to the in-app logo, without any CDN.
const fontPath = join(__dirname, '../node_modules/@fontsource/caveat/files/caveat-latin-700-normal.woff2');
const fontB64 = readFileSync(fontPath).toString('base64');
const fontDataUri = `data:font/woff2;base64,${fontB64}`;

// ── App icon: board watermark + "kelimeki" wordmark, as pure SVG ───────────
// icon.svg is the single source of truth for icon-512/192/apple-touch-icon —
// they're all rasterized from it (below) so they can never drift apart the
// way they did before 2026-07-21 (the PNGs carried a watermark, but this
// script still generated an unrelated single-"k" icon.svg with no watermark
// at all — re-running it would have silently wiped the watermark out).
//
// Text/path layout below (x/y/font-size/letter-spacing/path d) is the exact,
// already-verified-centred layout from that session — kept as constants
// instead of re-deriving via screenshot-trim-and-centre.
const ICON_IMAGE_X = 16.0;
const ICON_IMAGE_Y = 18.0;
const ICON_IMAGE_WIDTH = 480;
const ICON_IMAGE_HEIGHT = 476.0;
const ICON_TEXT_X = 256;
const ICON_TEXT_Y = 292;
const ICON_FONT_SIZE = 148.0;
const ICON_LETTER_SPACING = 11.4;
const ICON_PATH_D = 'M125.1 314.0 Q184.8 305.5 256.0 314.0 Q327.1 322.5 386.9 314.0';
const ICON_PATH_STROKE_WIDTH = 7.1;

// scripts/assets/icon-watermark-source.png is the raw per-pixel-alpha board
// tile watermark (same source image as Setup.tsx's background wash), alpha
// un-boosted (max ~8%, tuned for a large background area — at real icon
// sizes that's indistinguishable from a blank white icon). We boost it here
// so it actually reads at 60-180px. 4.5x (tried 2026-07-21) made the bottom
// of the gradient too heavy/dark; 3.2x keeps the top subtle while making the
// bottom clearly legible without competing with the wordmark.
const ICON_WATERMARK_BOOST = 3.2;

const watermarkSourcePath = join(__dirname, 'assets/icon-watermark-source.png');
const watermarkSourceSharp = sharp(watermarkSourcePath).ensureAlpha();
const { data: wmRaw, info: wmInfo } = await watermarkSourceSharp
  .raw()
  .toBuffer({ resolveWithObject: true });
for (let i = 3; i < wmRaw.length; i += 4) {
  wmRaw[i] = Math.min(255, Math.round(wmRaw[i] * ICON_WATERMARK_BOOST));
}
const watermarkBoostedPng = await sharp(wmRaw, {
  raw: { width: wmInfo.width, height: wmInfo.height, channels: 4 },
})
  .png()
  .toBuffer();
const watermarkDataUri = `data:image/png;base64,${watermarkBoostedPng.toString('base64')}`;

const iconSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <style>
      @font-face {
        font-family: 'Caveat';
        font-style: normal;
        font-weight: 700;
        src: url('${fontDataUri}') format('woff2');
      }
    </style>
  </defs>
  <rect width="512" height="512" fill="#ffffff"/>
  <image href="${watermarkDataUri}" x="${ICON_IMAGE_X}" y="${ICON_IMAGE_Y}" width="${ICON_IMAGE_WIDTH}" height="${ICON_IMAGE_HEIGHT}" preserveAspectRatio="xMidYMid slice"/>
  <text
    x="${ICON_TEXT_X}" y="${ICON_TEXT_Y}"
    font-family="Caveat, cursive"
    font-size="${ICON_FONT_SIZE}"
    font-weight="700"
    letter-spacing="${ICON_LETTER_SPACING}"
    fill="#2563EB"
    text-anchor="middle">kelimeki</text>
  <path
    d="${ICON_PATH_D}"
    stroke="#2563EB"
    stroke-width="${ICON_PATH_STROKE_WIDTH}"
    stroke-linecap="round"
    fill="none"/>
</svg>`;

writeFileSync(join(__dirname, '../public/icon.svg'), iconSvg);
console.log('✓ icon.svg (watermark + wordmark, single source for PNG icons)');

// Rasterize icon.svg itself for icon-512/192/apple-touch-icon so they can
// never drift from it — render at 2× (1024px) then downsample for crisp edges.
const RENDER = 1024;
const html = `<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"/><style>* { margin:0; padding:0; } body { width:${RENDER}px; height:${RENDER}px; } svg { width:${RENDER}px; height:${RENDER}px; display:block; }</style></head>
<body>${iconSvg}</body>
</html>`;

// Small canvas for favicon — shows just "k" with S-curve underline, same style.
const FAVICON_RENDER = 256;
const faviconHtml = `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8"/>
<style>
  @font-face {
    font-family: 'Caveat';
    font-style: normal;
    font-weight: 700;
    src: url('${fontDataUri}') format('woff2');
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    width: ${FAVICON_RENDER}px;
    height: ${FAVICON_RENDER}px;
    background: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .logo {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
  }
  .letter {
    font-family: 'Caveat', cursive;
    font-size: 190px;
    font-weight: 700;
    color: #2563EB;
    line-height: 1;
  }
</style>
</head>
<body>
<div class="logo">
  <div class="letter">k</div>
  <svg width="160" height="14" viewBox="0 0 160 14" fill="none">
    <path d="M8 7 Q40 2 80 7 Q120 12 152 7"
          stroke="#2563EB" stroke-width="5" stroke-linecap="round" fill="none"/>
  </svg>
</div>
</body>
</html>`;

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

// ── icon.svg (watermark + wordmark, already laid out/centred) → app icons ──
const page = await browser.newPage();
await page.setViewportSize({ width: RENDER, height: RENDER });
await page.setContent(html, { waitUntil: 'networkidle' });
await page.waitForTimeout(200);
const screenshot = await page.screenshot({ type: 'png' });

// ── "k" logo → favicon ─────────────────────────────────────────────────────
const faviconPage = await browser.newPage();
await faviconPage.setViewportSize({ width: FAVICON_RENDER, height: FAVICON_RENDER });
await faviconPage.setContent(faviconHtml, { waitUntil: 'networkidle' });
await faviconPage.waitForTimeout(200);
const faviconScreenshot = await faviconPage.screenshot({ type: 'png' });

await browser.close();

const targets = [
  { size: 512, name: 'icon-512.png' },
  { size: 192, name: 'icon-192.png' },
  { size: 180, name: 'apple-touch-icon.png' },
];

for (const { size, name } of targets) {
  await sharp(screenshot)
    .resize(size, size, { kernel: 'lanczos3' })
    .png()
    .toFile(join(__dirname, '../public', name));
  console.log(`✓ ${name} (${size}×${size})`);
}

// ── Favicon PNG (32×32) ────────────────────────────────────────────────────
const FAVICON_PADDING = 20;

const faviconTrimmed = await sharp(faviconScreenshot)
  .trim({ background: '#ffffff', threshold: 10 })
  .png()
  .toBuffer();

const { width: fw, height: fh } = await sharp(faviconTrimmed).metadata();
const fInner = Math.max(fw, fh);
const fCanvas = fInner + FAVICON_PADDING * 2;
const fLeft = Math.round((fCanvas - fw) / 2);
const fTop  = Math.round((fCanvas - fh) / 2);

const faviconCentred = await sharp(faviconTrimmed)
  .extend({ top: fTop, bottom: fCanvas - fh - fTop, left: fLeft, right: fCanvas - fw - fLeft,
            background: { r: 255, g: 255, b: 255, alpha: 1 } })
  .png()
  .toBuffer();

await sharp(faviconCentred)
  .resize(32, 32, { kernel: 'lanczos3' })
  .png()
  .toFile(join(__dirname, '../public/favicon-32.png'));
console.log('✓ favicon-32.png (32×32)');

// ── favicon.svg from the traced "k" glyph (NO embedded font) ──────────────
// Tarayıcı sekmesindeki SVG favicon.
//
// 25 Ağustos 2026'ya kadar burada Caveat fontu base64 olarak GÖMÜLÜYDU ve
// dosya **67 KB** ediyordu — bunun 66 KB'ı tek bir "k" harfi çizdirmek için
// taşınan fonttu. Üstelik dosya hem `index.html`den isteniyor hem service
// worker precache'ine giriyor, yani her ziyaretçi ödüyordu (ölçüldü).
//
// Oysa aynı harf `LogoMark.tsx`te ZATEN statik path olarak duruyor:
// `generate-logo-paths.mjs` Caveat Bold'u glif dış hatlarına çeviriyor ve
// logo bu yüzden font indirmiyor (kök CLAUDE.md → "Font Yükleme Stratejisi").
// Favicon o temizliğin dışında kalmıştı; artık aynı kaynağı kullanıyor.
//
// Sonuç: **67 KB → 2.2 KB**. Eski/yeni 16, 32 ve 48 px'te yan yana render
// edilip karşılaştırıldı — ayırt edilebilir fark yok.
const logoSrc = readFileSync(join(__dirname, '../src/components/LogoMark.tsx'), 'utf8');
// `LOGO_TEXT_PATH` tüm "kelimeki" kelimesi; her glif kendi `M`iyle başlıyor,
// ilki "k". Alt path'e bölüp ilkini alıyoruz.
const kGlyph = logoSrc.match(/LOGO_TEXT_PATH = '([^']+)'/)[1].split(/(?=M)/)[0];
const logoColor = logoSrc.match(/LOGO_COLOR = '([^']+)'/)[1];

// Glifin kendi koordinat sistemindeki sınırları — tarayıcıda `getBBox()` ile
// ÖLÇÜLDÜ, göz kararı değil. Path verisi değişirse (logo yeniden üretilirse)
// bu dört sayı da yeniden ölçülmeli.
const K_BOX = { x: 238.82, y: 111.84, w: 106.4, h: 192.27 };
const K_HEIGHT = 62; // 100'lük kutuda hedef yükseklik — altta imzaya yer kalsın
const kScale = K_HEIGHT / K_BOX.h;
const kTx = (100 - K_BOX.w * kScale) / 2 - K_BOX.x * kScale;
const kTy = 14 - K_BOX.y * kScale;

const faviconSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <rect width="100" height="100" fill="#ffffff"/>
  <path transform="translate(${kTx.toFixed(2)} ${kTy.toFixed(2)}) scale(${kScale.toFixed(5)})" d="${kGlyph}" fill="${logoColor}"/>
  <path
    d="M18 87 Q34 83 50 87 Q66 91 82 87"
    stroke="${logoColor}"
    stroke-width="3.5"
    stroke-linecap="round"
    fill="none"/>
</svg>`;

writeFileSync(join(__dirname, '../public/favicon.svg'), faviconSvg);
console.log('✓ favicon.svg (traced glyph, no embedded font)');
