// Kelimeki — Google Play mağaza görsellerini üretir.
//
//   npm run build && node scripts/play-store/build.mjs
//
// İKİ çıktı:
//   marketing/play-store/store-icon-512.png   — 512×512, mağaza ikonu
//   marketing/play-store/feature-graphic.png  — 1024×500, öne çıkan görsel
//
// Ekran görüntüleri BURADA ÜRETİLMEZ ve üretilemez: Play'e giden telefon
// görüntülerinin uygulamanın GERÇEK görüntüsü olması gerekiyor, yani gerçek
// bir cihazdan alınmalı (bkz. marketing/play-store/metin.md → çekim listesi).
//
// ⚠ `npm run build` ÖNCE koşmuş olmalı (stiller dist CSS'inden gelir) ve
// sayfa `http://` üzerinden açılır — `file://` mutlak asset yollarını
// çözemediğinden tüm puntoları sessizce 16px okur.
import { createReadStream, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build as esbuild } from 'esbuild';
import { chromium } from 'playwright';
import sharp from 'sharp';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const DIST = path.join(ROOT, 'dist');
const OUT_DIR = path.join(ROOT, 'marketing', 'play-store');
const W = 1024;
const H = 500;

// Mağaza ikonunun kaynağı, cihazdaki başlatıcı ikonun KAYNAĞIYLA aynı dosya
// (`flutter_launcher_icons.image_path`) — ayrı bir kaynaktan üretilseydi
// mağazadaki ikon ile telefondaki ikon sessizce ayrışabilirdi.
const ICON_SRC = path.join(ROOT, 'mobile', 'app', 'assets', 'icon', 'icon-source.png');

const MIME = { '.html':'text/html; charset=utf-8', '.css':'text/css', '.js':'text/javascript',
  '.woff2':'font/woff2', '.png':'image/png', '.svg':'image/svg+xml', '.json':'application/json' };

async function main() {
  mkdirSync(OUT_DIR, { recursive: true });

  // ── 1) Mağaza ikonu ─────────────────────────────────────────────────────
  const src = sharp(ICON_SRC);
  const meta = await src.metadata();
  if (meta.width !== 1024 || meta.height !== 1024) {
    throw new Error(`icon-source.png 1024×1024 bekleniyordu, ${meta.width}×${meta.height} geldi.`);
  }
  const iconOut = path.join(OUT_DIR, 'store-icon-512.png');
  // Play ikonu kendi maskesini uyguluyor; şeffaflık İSTENMİYOR — kaynak zaten
  // opak, `flatten` bunu garantiye alıyor.
  await src.flatten({ background: '#ffffff' }).resize(512, 512, { kernel: 'lanczos3' })
    .png({ compressionLevel: 9 }).toFile(iconOut);

  // ── 2) Öne çıkan görsel ─────────────────────────────────────────────────
  const cssFile = readdirSync(path.join(DIST, 'assets')).find(
    (f) => f.startsWith('index-') && f.endsWith('.css'),
  );
  if (!cssFile) throw new Error('dist/assets/index-*.css yok — önce `npm run build` koş.');

  const outMjs = path.join(ROOT, 'node_modules', '.cache', 'kelimeki', 'play-feature.mjs');
  await esbuild({
    entryPoints: [path.join(ROOT, 'scripts', 'play-store', 'feature-graphic.tsx')],
    bundle: true, platform: 'node', format: 'esm', jsx: 'automatic',
    external: ['react', 'react-dom', 'react-dom/server'],
    loader: { '.css': 'empty' }, outfile: outMjs, logLevel: 'error',
  });
  const { renderFeatureGraphicHtml } = await import(`file://${outMjs}?t=${Date.now()}`);
  writeFileSync(path.join(DIST, 'play-feature.html'), renderFeatureGraphicHtml(`/assets/${cssFile}`), 'utf8');

  const server = createServer(async (req, res) => {
    const f = path.join(DIST, decodeURIComponent((req.url ?? '/').split('?')[0]));
    try {
      const s = await stat(f);
      if (!s.isFile()) throw new Error('dir');
      res.writeHead(200, { 'content-type': MIME[path.extname(f)] ?? 'application/octet-stream' });
      createReadStream(f).pipe(res);
    } catch {
      res.writeHead(404).end('yok');
    }
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));

  const browser = await chromium.launch({
    executablePath: process.env.CI ? undefined : '/opt/pw-browsers/chromium',
  });
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
  await page.goto(`http://127.0.0.1:${server.address().port}/play-feature.html`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);

  // 2× çekip 1× indirmek, doğrudan 1× çekmekten daha keskin (süperörnekleme);
  // Play boyutu TAM 1024×500 istiyor, bu yüzden indirme adımı zorunlu.
  const png2x = await page.screenshot();
  const featureOut = path.join(OUT_DIR, 'feature-graphic.png');

  // ── Ölçüm — "sığdı" varsayılmaz ─────────────────────────────────────────
  // Ölçüm YAZMADAN ÖNCE: başarısız bir koşu diske "bitmiş gibi duran" bozuk
  // bir görsel bırakmamalı (bu kod tabanının en sevmediği hata sınıfı).
  const olcum = await page.evaluate(() => {
    const kutu = document.querySelector('[data-guvenli-kutu]');
    const b = kutu.getBoundingClientRect();
    const de = document.documentElement;
    return {
      sol: Math.round(b.left), sag: Math.round(b.right),
      ust: Math.round(b.top), alt: Math.round(b.bottom),
      tasmaX: de.scrollWidth - de.clientWidth, tasmaY: de.scrollHeight - de.clientHeight,
    };
  });
  await browser.close();
  server.close();

  console.log(`  güvenli kutu: x ${olcum.sol}–${olcum.sag}, y ${olcum.ust}–${olcum.alt} (kadraj ${W}×${H})`);
  console.log(`  taşma: x ${olcum.tasmaX}, y ${olcum.tasmaY}`);

  const hatalar = [];
  if (olcum.tasmaX || olcum.tasmaY) hatalar.push('sayfa taşıyor');
  // Kenarlara pay: kırpılan yüzeylerde metin kesilmesin.
  if (olcum.sol < 40 || olcum.sag > W - 40 || olcum.ust < 30 || olcum.alt > H - 30) {
    hatalar.push('güvenli kutu kenara çok yakın');
  }
  if (hatalar.length) { console.error('✗ ' + hatalar.join('; ')); process.exit(1); }

  await sharp(png2x).resize(W, H, { kernel: 'lanczos3' })
    .flatten({ background: '#ffffff' })   // Play alfa istemiyor (24-bit PNG)
    .png({ compressionLevel: 9 }).toFile(featureOut);

  const iconMeta = await sharp(iconOut).metadata();
  const featMeta = await sharp(featureOut).metadata();
  console.log(`  ikon    : ${iconMeta.width}×${iconMeta.height}  ${iconMeta.hasAlpha ? 'ALFA VAR ✗' : 'opak ✓'}`);
  console.log(`  öne çıkan: ${featMeta.width}×${featMeta.height}  ${featMeta.hasAlpha ? 'ALFA VAR ✗' : 'opak ✓'}`);
  if (iconMeta.width !== 512 || iconMeta.height !== 512) { console.error('✗ ikon 512×512 değil'); process.exit(1); }
  if (featMeta.width !== W || featMeta.height !== H) { console.error(`✗ öne çıkan ${W}×${H} değil`); process.exit(1); }
  if (iconMeta.hasAlpha || featMeta.hasAlpha) { console.error('✗ alfa kanalı kalmış'); process.exit(1); }

  console.log(`\n✓ ${path.relative(ROOT, iconOut)}`);
  console.log(`✓ ${path.relative(ROOT, featureOut)}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
