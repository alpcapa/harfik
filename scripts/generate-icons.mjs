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

// The logo HTML exactly mirrors Setup.tsx at a scale that fills a square canvas.
// We render at 2× (1024px) then downsample for crisp edges.
const RENDER = 1024;

const html = `<!DOCTYPE html>
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
    width: ${RENDER}px;
    height: ${RENDER}px;
    background: #ffffff;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .logo {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }
  .wordmark {
    font-family: 'Caveat', cursive;
    font-size: 310px;
    font-weight: 700;
    color: #2563EB;
    letter-spacing: 16px;
    line-height: 1;
    /* nudge right to visually compensate for letter-spacing on last char */
    padding-left: 16px;
  }
</style>
</head>
<body>
<div class="logo">
  <div class="wordmark">harfik</div>
  <svg width="720" height="32" viewBox="0 0 720 32" fill="none">
    <path d="M16 16 Q180 4 360 16 Q540 28 704 16"
          stroke="#2563EB" stroke-width="10" stroke-linecap="round" fill="none"/>
  </svg>
</div>
</body>
</html>`;

// Small canvas for favicon — shows just "h" with S-curve underline, same style.
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
  <div class="letter">h</div>
  <svg width="160" height="14" viewBox="0 0 160 14" fill="none">
    <path d="M8 7 Q40 2 80 7 Q120 12 152 7"
          stroke="#2563EB" stroke-width="5" stroke-linecap="round" fill="none"/>
  </svg>
</div>
</body>
</html>`;

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

// ── Full logo → app icons ───────────────────────────────────────────────────
const page = await browser.newPage();
await page.setViewportSize({ width: RENDER, height: RENDER });
await page.setContent(html, { waitUntil: 'networkidle' });
await page.waitForTimeout(200);
const screenshot = await page.screenshot({ type: 'png' });

// ── "h" logo → favicon ─────────────────────────────────────────────────────
const faviconPage = await browser.newPage();
await faviconPage.setViewportSize({ width: FAVICON_RENDER, height: FAVICON_RENDER });
await faviconPage.setContent(faviconHtml, { waitUntil: 'networkidle' });
await faviconPage.waitForTimeout(200);
const faviconScreenshot = await faviconPage.screenshot({ type: 'png' });

await browser.close();

// Trim the white canvas to the exact content bounds, then extend with
// equal padding on all four sides so the logo is perfectly centred.
const ICON_PADDING = 56; // px padding at 512px output

const trimmedPng = await sharp(screenshot)
  .trim({ background: '#ffffff', threshold: 10 })
  .png()
  .toBuffer();

const { width: tw, height: th } = await sharp(trimmedPng).metadata();
const inner = Math.max(tw, th);
const canvas = inner + ICON_PADDING * 2;
const left = Math.round((canvas - tw) / 2);
const top  = Math.round((canvas - th) / 2);

const centred = await sharp(trimmedPng)
  .extend({ top, bottom: canvas - th - top, left, right: canvas - tw - left,
            background: { r: 255, g: 255, b: 255, alpha: 1 } })
  .png()
  .toBuffer();

const targets = [
  { size: 512, name: 'icon-512.png' },
  { size: 192, name: 'icon-192.png' },
  { size: 180, name: 'apple-touch-icon.png' },
];

for (const { size, name } of targets) {
  await sharp(centred)
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

// ── favicon.svg with embedded Caveat font ─────────────────────────────────
// SVG favicon shown in browser tabs. Embedding the font guarantees it renders
// correctly even before the page loads Google Fonts.
const faviconSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
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
  <rect width="100" height="100" fill="#ffffff"/>
  <text
    x="50" y="76"
    font-family="Caveat, cursive"
    font-size="90"
    font-weight="700"
    fill="#2563EB"
    text-anchor="middle">h</text>
  <path
    d="M18 87 Q34 83 50 87 Q66 91 82 87"
    stroke="#2563EB"
    stroke-width="3.5"
    stroke-linecap="round"
    fill="none"/>
</svg>`;

writeFileSync(join(__dirname, '../public/favicon.svg'), faviconSvg);
console.log('✓ favicon.svg (with embedded Caveat font)');

// Also update icon.svg to match (used as the source SVG reference).
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
  <text
    x="256" y="392"
    font-family="Caveat, cursive"
    font-size="360"
    font-weight="700"
    fill="#2563EB"
    text-anchor="middle">h</text>
  <path
    d="M90 430 Q173 420 256 430 Q339 440 422 430"
    stroke="#2563EB"
    stroke-width="14"
    stroke-linecap="round"
    fill="none"/>
</svg>`;

writeFileSync(join(__dirname, '../public/icon.svg'), iconSvg);
console.log('✓ icon.svg (updated S-curve weight and position)');
