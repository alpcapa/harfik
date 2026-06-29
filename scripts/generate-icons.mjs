import { chromium } from 'playwright';
import sharp from 'sharp';
import { readFileSync } from 'fs';
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
const PADDING = 64; // px of white breathing room on each side

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

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const page = await browser.newPage();
await page.setViewportSize({ width: RENDER, height: RENDER });
await page.setContent(html, { waitUntil: 'networkidle' });
// Give the font an extra tick to paint
await page.waitForTimeout(200);

const screenshot = await page.screenshot({ type: 'png' });
await browser.close();

// Trim the white canvas to the exact content bounds, then extend with
// equal padding on all four sides so the logo is perfectly centred.
const ICON_PADDING = 56; // px padding at 512px output

const trimmedPng = await sharp(screenshot)
  .trim({ background: '#ffffff', threshold: 10 })
  .png()
  .toBuffer();

const { width: tw, height: th } = await sharp(trimmedPng).metadata();
// Make the padded canvas square based on the longer dimension.
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
