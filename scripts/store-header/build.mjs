// Kelimeki — mağaza başlık görselini üretir (Google Play Games header yuvası).
//
//   npm run build && node scripts/store-header/build.mjs
//
// ⚠ `npm run build` ÖNCE koşmuş olmalı (stiller dist CSS'inden gelir) ve
// sayfa `http://` üzerinden açılır — `file://` mutlak asset yollarını
// çözemediğinden tüm puntoları sessizce 16px okur.
//
// Yuvanın şartları: JPEG ya da 24-bit PNG, ŞEFFAF DEĞİL, 4096×2304, ≤1 MB.
// 9,4 megapiksele karşı 1 MB tavanı dar; bu yüzden betik önce KAYIPSIZ
// 24-bit PNG deniyor, sığmazsa tavanın altına giren EN YÜKSEK kaliteli
// JPEG'e düşüyor (ikisi de yuvanın kabul ettiği biçim). Hangisinin
// yazıldığı çıktıda yazıyor — "sığdı" varsayılmıyor, ÖLÇÜLÜYOR.
import { createReadStream, mkdirSync, readdirSync, writeFileSync, statSync, rmSync, existsSync } from 'node:fs';
import { createServer } from 'node:http';
import { stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build as esbuild } from 'esbuild';
import { chromium } from 'playwright';
import sharp from 'sharp';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const DIST = path.join(ROOT, 'dist');
const OUT_DIR = path.join(ROOT, 'marketing', 'store');
const OUT_BASE = path.join(OUT_DIR, 'kelimeki-play-header-4096x2304');

/** CSS px tuval; ekran görüntüsü 2× alındığından çıktı 4096×2304. */
const W = 2048;
const H = 1152;
const SCALE = 2;
const HEDEF_W = W * SCALE;
const HEDEF_H = H * SCALE;
const BOYUT_TAVANI = 1024 * 1024; // 1 MB

const MIME = { '.html':'text/html; charset=utf-8', '.css':'text/css', '.js':'text/javascript',
  '.woff2':'font/woff2', '.png':'image/png', '.svg':'image/svg+xml', '.json':'application/json' };

async function main() {
  const cssFile = readdirSync(path.join(DIST, 'assets')).find(
    (f) => f.startsWith('index-') && f.endsWith('.css'),
  );
  if (!cssFile) throw new Error('dist/assets/index-*.css yok — önce `npm run build` koş.');

  const outMjs = path.join(ROOT, 'node_modules', '.cache', 'kelimeki', 'store-header.mjs');
  await esbuild({
    entryPoints: [path.join(ROOT, 'scripts', 'store-header', 'StoreHeader.tsx')],
    bundle: true, platform: 'node', format: 'esm', jsx: 'automatic',
    external: ['react', 'react-dom', 'react-dom/server'],
    loader: { '.css': 'empty' }, outfile: outMjs, logLevel: 'error',
  });
  const { renderStoreHeaderHtml } = await import(`file://${outMjs}?t=${Date.now()}`);
  writeFileSync(path.join(DIST, 'store-header.html'), renderStoreHeaderHtml(`/assets/${cssFile}`), 'utf8');

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
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: SCALE });
  await page.goto(`http://127.0.0.1:${server.address().port}/store-header.html`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);

  const ham = await page.screenshot({ type: 'png' });

  // Güvenli kutu gerçekten en dar (KARE) kırpmanın içinde mi? Ölçmeden
  // "sığdı" denemez — 16:9 bir kareden alınabilecek en dar merkez kırpma
  // yüksekliğe eşit genişlikte (H px) bir kare.
  const olcum = await page.evaluate(() => {
    const kutu = document.querySelector('[data-guvenli-kutu]');
    const b = kutu.getBoundingClientRect();
    return { sol: Math.round(b.left), sag: Math.round(b.right), ust: Math.round(b.top), alt: Math.round(b.bottom) };
  });
  const kareSol = (W - H) / 2;
  const kareSag = W - kareSol;
  const kareIcinde = olcum.sol >= kareSol && olcum.sag <= kareSag && olcum.ust >= 0 && olcum.alt <= H;
  console.log(`  güvenli kutu: x ${olcum.sol}–${olcum.sag}, y ${olcum.ust}–${olcum.alt}`);
  console.log(`  kare kırpma:  x ${kareSol}–${kareSag}  →  ${kareIcinde ? 'İÇERİDE ✓' : 'TAŞIYOR ✗'}`);

  await browser.close();
  server.close();

  mkdirSync(OUT_DIR, { recursive: true });

  // 1) Kayıpsız 24-bit PNG (alfa kanalı YOK — `flatten` beyaz zemine düzler).
  const png = await sharp(ham)
    .flatten({ background: '#ffffff' })
    .png({ compressionLevel: 9, palette: false })
    .toBuffer();
  console.log(`  24-bit PNG: ${(png.length / 1024 / 1024).toFixed(2)} MB`);

  let out, bicim;
  if (png.length <= BOYUT_TAVANI) {
    out = OUT_BASE + '.png';
    writeFileSync(out, png);
    bicim = '24-bit PNG (kayıpsız)';
    if (existsSync(OUT_BASE + '.jpg')) rmSync(OUT_BASE + '.jpg');
  } else {
    // Tavanın altına giren en yüksek kalite — kaba tarama, yüksekten aşağı.
    let secilen = null;
    for (const q of [95, 92, 90, 88, 85, 82, 80, 75, 70]) {
      const jpg = await sharp(ham)
        .flatten({ background: '#ffffff' })
        .jpeg({ quality: q, chromaSubsampling: '4:4:4', mozjpeg: true })
        .toBuffer();
      console.log(`  JPEG q${q}: ${(jpg.length / 1024).toFixed(0)} KB${jpg.length <= BOYUT_TAVANI ? '  ✓' : ''}`);
      if (jpg.length <= BOYUT_TAVANI) { secilen = { q, jpg }; break; }
    }
    if (!secilen) throw new Error('1 MB tavanının altına inen bir JPEG üretilemedi.');
    out = OUT_BASE + '.jpg';
    writeFileSync(out, secilen.jpg);
    bicim = `JPEG q${secilen.q} (4:4:4, alt örnekleme yok)`;
    if (existsSync(OUT_BASE + '.png')) rmSync(OUT_BASE + '.png');
  }

  // Yazılan dosyayı KENDİ baytlarından doğrula.
  const meta = await sharp(out).metadata();
  const bayt = statSync(out).size;
  console.log(`\n✓ ${path.relative(ROOT, out)}`);
  console.log(`  ${meta.width}×${meta.height} · ${bicim} · kanal=${meta.channels} · alfa=${meta.hasAlpha}`);
  console.log(`  ${bayt} bayt (${(bayt / 1024 / 1024).toFixed(3)} MB) — tavan 1 MB`);

  const sorunlar = [];
  if (meta.width !== HEDEF_W || meta.height !== HEDEF_H) sorunlar.push(`boyut ${meta.width}×${meta.height}, beklenen ${HEDEF_W}×${HEDEF_H}`);
  if (meta.hasAlpha) sorunlar.push('alfa kanalı var (şeffaflık yasak)');
  if (meta.channels !== 3) sorunlar.push(`kanal ${meta.channels}, beklenen 3`);
  if (bayt > BOYUT_TAVANI) sorunlar.push('1 MB tavanı aşıldı');
  if (!kareIcinde) sorunlar.push('güvenli kutu kare kırpmanın dışına taşıyor');
  if (sorunlar.length) { console.error('\n✗ ' + sorunlar.join('\n✗ ')); process.exit(1); }
  console.log('  şartların hepsi sağlandı ✓');
}

main().catch((e) => { console.error(e); process.exit(1); });
