// Kelimeki — 5 kare sponsorlu gönderi görselini üretir.
//
//   node scripts/sponsored-post/build.mjs
//
// ⚠ ÖNCE `npm run build` KOŞULMUŞ OLMALI: görsellerdeki tahta/rütbe/font
// stilleri `dist/assets/index-*.css`ten geliyor (poster kendi CSS'ini
// üretmiyor — bkz. `SponsoredPost.tsx` başlığı).
//
// ⚠ SAYFA `http://` ÜZERİNDEN AÇILIYOR, `file://` DEĞİL. CLAUDE.md'de ölçülmüş
// bir tuzak: `file://` mutlak asset yollarını (fontlar dahil) çözemiyor ve
// TÜM puntolar sessizce 16px okunuyor — bir ölçüm turu tam bu yüzden çöpe
// gitmişti.
import { mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
import { chromium } from 'playwright';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const DIST = path.join(ROOT, 'dist');
const OUT_DIR = path.join(ROOT, 'marketing', 'sponsored-2026-08');
const CACHE_DIR = path.join(ROOT, 'node_modules', '.cache', 'kelimeki');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript',
  '.woff2': 'font/woff2',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
};

async function main() {
  // 1 · Derlenmiş CSS'i bul (dosya adı içerik hash'i taşıyor).
  const cssFile = readdirSync(path.join(DIST, 'assets')).find(
    (f) => f.startsWith('index-') && f.endsWith('.css'),
  );
  if (!cssFile) throw new Error('dist/assets/index-*.css yok — önce `npm run build` koş.');

  // 2 · Poster bileşenini Node'da çalışacak şekilde paketle ve import et.
  //     `src/landing/render.tsx` ile AYNI esbuild ayarları — gerekçeleri
  //     `scripts/landing-plugin.js`te yazılı (react'i dışarıda bırakmak,
  //     CSS import'larını boşa çevirmek).
  mkdirSync(CACHE_DIR, { recursive: true });
  const outfile = path.join(CACHE_DIR, 'sponsored-post.mjs');
  await build({
    entryPoints: [path.join(ROOT, 'scripts', 'sponsored-post', 'render.tsx')],
    bundle: true,
    platform: 'node',
    format: 'esm',
    jsx: 'automatic',
    external: ['react', 'react-dom', 'react-dom/server'],
    loader: { '.css': 'empty' },
    outfile,
    logLevel: 'error',
  });
  const { renderPostHtml } = await import(`file://${outfile}?t=${Date.now()}`);

  const htmlPath = path.join(DIST, 'kelimeki-post.html');
  writeFileSync(htmlPath, renderPostHtml(`/assets/${cssFile}`), 'utf8');

  // 3 · `dist`i statik servis et.
  const server = createServer(async (req, res) => {
    const rel = decodeURIComponent((req.url ?? '/').split('?')[0]);
    const file = path.join(DIST, rel === '/' ? 'index.html' : rel);
    try {
      const s = await stat(file);
      if (!s.isFile()) throw new Error('dir');
      res.writeHead(200, { 'content-type': MIME[path.extname(file)] ?? 'application/octet-stream' });
      createReadStream(file).pipe(res);
    } catch {
      res.writeHead(404).end('yok');
    }
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;

  // 4 · Kareleri tek tek yakala.
  const browser = await chromium.launch({
    executablePath: process.env.CI ? undefined : '/opt/pw-browsers/chromium',
  });
  // ⚠ viewport 1080 GENİŞ olmak zorunda: `Tile.tsx`in harf puntosu `vw`
  // tabanlı bir clamp — dar bir viewport'ta harfler tavana ulaşmaz ve
  // tahta gerçek oyundaki oranını kaybeder.
  const page = await browser.newPage({ viewport: { width: 1080, height: 1080 }, deviceScaleFactor: 2 });
  await page.goto(`http://127.0.0.1:${port}/kelimeki-post.html`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);

  mkdirSync(OUT_DIR, { recursive: true });
  const slides = await page.locator('.kelimeki-slide').all();
  if (slides.length !== 5) throw new Error(`5 kare bekleniyordu, ${slides.length} bulundu.`);

  for (const [i, slide] of slides.entries()) {
    const file = path.join(OUT_DIR, `kelimeki-${String(i + 1).padStart(2, '0')}.png`);
    await slide.screenshot({ path: file });
    const box = await slide.boundingBox();
    console.log(`  ${path.relative(ROOT, file)}  ${box.width}×${box.height} CSS px`);
  }

  await browser.close();
  server.close();
  console.log(`\n✓ 5 kare → ${path.relative(ROOT, OUT_DIR)} (2× ölçek, 2160×2160 px)`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
