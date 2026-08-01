import sharp from 'sharp';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Standalone "k-lig" wordmark export (vector SVG + rasterized PNG/JPG) —
// unlike generate-logo.mjs (which re-renders live Caveat text through a
// headless browser), this reads the ALREADY-TRACED, NaN-free path data
// straight out of src/components/KLigMark.tsx (produced by
// generate-klig-paths.mjs) and rasterizes it directly with sharp — no
// font/browser dependency needed since the outline is already static.

const klig = readFileSync(join(__dirname, '../src/components/KLigMark.tsx'), 'utf8');
const KLIG_VIEW_BOX = klig.match(/KLIG_VIEW_BOX = '([^']+)'/)[1];
const KLIG_TEXT_PATH = klig.match(/KLIG_TEXT_PATH = '([^']+)'/)[1];
const KLIG_COLOR = klig.match(/KLIG_COLOR = '([^']+)'/)[1];

const [, , vbWidth, vbHeight] = KLIG_VIEW_BOX.split(' ').map(Number);

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${KLIG_VIEW_BOX}">
  <path d="${KLIG_TEXT_PATH}" fill="${KLIG_COLOR}"/>
</svg>`;

const outDir = join(__dirname, '../public/klig-export');
mkdirSync(outDir, { recursive: true });

writeFileSync(join(outDir, 'klig-logo.svg'), svg);
console.log('✓ klig-logo.svg (vector)');

const RENDER_WIDTH = 1200;
const renderHeight = Math.round((RENDER_WIDTH / vbWidth) * vbHeight);

const png = await sharp(Buffer.from(svg), { density: 300 })
  .resize(RENDER_WIDTH, renderHeight)
  .png()
  .toBuffer();
writeFileSync(join(outDir, 'klig-logo.png'), png);
console.log(`✓ klig-logo.png (transparent, ${RENDER_WIDTH}×${renderHeight})`);

await sharp(png)
  .flatten({ background: '#ffffff' })
  .jpeg({ quality: 95 })
  .toFile(join(outDir, 'klig-logo.jpg'));
console.log(`✓ klig-logo.jpg (white background, ${RENDER_WIDTH}×${renderHeight})`);
