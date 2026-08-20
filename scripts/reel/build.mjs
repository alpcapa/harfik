// Kelimeki — Instagram reel'i (1080×1920, MP4) ÜRETİM UYGULAMASINI sürerek üretir.
//
//   npm run build && node scripts/reel/build.mjs
//
// NEDEN KARE KARE (stop-motion), Playwright'ın `recordVideo`'su DEĞİL:
// `recordVideo` videoyu viewport ölçüsünde kaydediyor ve büyütmek için
// upscale ediyor — 540 px'lik bir telefon düzenini 1080'e çıkarınca taş
// harfleri bulanıklaşırdı. `page.screenshot` ise `deviceScaleFactor: 2` ile
// GERÇEK 1080×1920 piksel üretiyor. Kareler sonra ffmpeg'in concat
// demuxer'ıyla, her karenin kendi süresiyle birleştiriliyor: bekleme anları
// tek bir dosya + uzun süre, sürükleme anları 1/30 sn'lik kareler.
//
// ⚠ SÜRÜKLEME HEDEFİ +30 px AŞAĞIDA: uygulama hayalet taşı işaretçinin 30 px
// ÜSTÜNDE çiziyor ve bırakma hedefini de o kaldırılmış noktaya göre buluyor
// (DRAG_LIFT). İmleci doğrudan hücrenin üstüne götüren bir betik taşı bir
// satır yukarı bırakır — bu tuzak CLAUDE.md'de kayıtlı, burada +30 ile
// telafi ediliyor.
import { createReadStream, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { stat } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { build as esbuild } from 'esbuild';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const DIST = path.join(ROOT, 'dist');
const FRAMES = path.join(ROOT, 'node_modules', '.cache', 'kelimeki', 'reel-frames');
const OUT = path.join(ROOT, 'marketing', 'sponsored-2026-08', 'kelimeki-reel.mp4');
const STATE = path.join(ROOT, 'node_modules', '.cache', 'kelimeki', 'reel-state.json');

const W = 540;
/** Uygulama içeriği 540 px genişlikte 819 px sürüyor (ölçüldü) — viewport'u
 *  960 bırakmak karenin altında ~150 px ölü beyaz alan üretiyordu. 832 =
 *  içerik + küçük nefes; kalan yer 9:16'ya doldurulurken alt banda gidiyor. */
const H = 832;
/** Kaydın üstünde bırakılan pay ve altındaki adres şeridinin yüksekliği (çıktı px). */
const UST_PAY = 40;
const BANT_H = 1920 - UST_PAY - H * 2;
const FPS = 30;
const DRAG_LIFT = 30;

const MIME = { '.html':'text/html; charset=utf-8', '.css':'text/css', '.js':'text/javascript',
  '.woff2':'font/woff2', '.png':'image/png', '.svg':'image/svg+xml', '.json':'application/json',
  '.webmanifest':'application/manifest+json', '.ico':'image/x-icon' };

const kareler = []; // { dosya, sure }
let sayac = 0;

async function kare(page, sure = 1 / FPS) {
  const dosya = path.join(FRAMES, `f${String(++sayac).padStart(4, '0')}.png`);
  await page.screenshot({ path: dosya });
  kareler.push({ dosya, sure });
}

/** Aynı görüntüyü `sn` saniye tutar — tek dosya, uzun süre (kare israfı yok). */
async function bekle(page, sn) {
  await kare(page, sn);
}

async function main() {
  rmSync(FRAMES, { recursive: true, force: true });
  mkdirSync(FRAMES, { recursive: true });
  const { payload, HAMLE } = JSON.parse(readFileSync(STATE, 'utf8'));

  // Kapanış kartını `dist`e üret (poster boru hattının aynı esbuild kalıbı).
  const cssFile = (await import('node:fs')).readdirSync(path.join(DIST, 'assets'))
    .find((f) => f.startsWith('index-') && f.endsWith('.css'));
  if (!cssFile) throw new Error('dist/assets/index-*.css yok — önce `npm run build` koş.');
  const kapanisMjs = path.join(ROOT, 'node_modules', '.cache', 'kelimeki', 'reel-kapanis.mjs');
  await esbuild({
    entryPoints: [path.join(ROOT, 'scripts', 'reel', 'kapanis.tsx')],
    bundle: true, platform: 'node', format: 'esm', jsx: 'automatic',
    external: ['react', 'react-dom', 'react-dom/server'],
    loader: { '.css': 'empty' }, outfile: kapanisMjs, logLevel: 'error',
  });
  const { renderKapanisHtml, renderBantHtml } = await import(`file://${kapanisMjs}?t=${Date.now()}`);
  writeFileSync(path.join(DIST, 'reel-kapanis.html'), renderKapanisHtml(`/assets/${cssFile}`), 'utf8');
  writeFileSync(path.join(DIST, 'reel-bant.html'), renderBantHtml(`/assets/${cssFile}`), 'utf8');

  const server = createServer(async (req, res) => {
    const rel = decodeURIComponent((req.url ?? '/').split('?')[0]);
    let f = path.join(DIST, rel === '/' ? 'index.html' : rel);
    try {
      const s = await stat(f);
      if (!s.isFile()) throw new Error('dir');
    } catch {
      f = path.join(DIST, 'index.html'); // SPA fallback
    }
    res.writeHead(200, { 'content-type': MIME[path.extname(f)] ?? 'application/octet-stream' });
    createReadStream(f).pipe(res);
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;

  const browser = await chromium.launch({
    executablePath: process.env.CI ? undefined : '/opt/pw-browsers/chromium',
  });
  const ctx = await browser.newContext({
    viewport: { width: W, height: H },
    deviceScaleFactor: 2,
    isMobile: false,
  });
  // Karşılama katmanını atla + Hızlı Başlangıç popup'ını bastır + sahneyi kur.
  await ctx.addInitScript(
    ([payloadStr]) => {
      try {
        localStorage.setItem('kelimeki:seen-intro', '1');
        localStorage.setItem('kelimeki:seen-quickstart', '1');
        localStorage.setItem('kelimeki:game-state', payloadStr);
      } catch {
        /* gizli sekme — sahne kurulamazsa betik zaten aşağıda patlar */
      }
    },
    [JSON.stringify(payload)],
  );

  const page = await ctx.newPage();
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);

  // ── 1 · Setup: "Devam Eden Oyun" ────────────────────────────────────────
  // ⚠ "Devam Eden Oyun" BÖLÜM BAŞLIĞI, tıklanabilir satır DEĞİL (ilk deneme
  // başlığa tıklayıp hiçbir şey olmamasıyla sonuçlandı). Tıklanacak olan
  // `SavedGameRow`; onu durum etiketinden buluyoruz. Büyük harf CSS'ten
  // geldiği için eşleşme büyük/küçük harfe duyarsız bir regex.
  const satir = page.getByText(/senin hamlen bekleniyor/i);
  await satir.waitFor({ timeout: 15000 });

  // ── 2 · Oyuna gir — KAYIT BURADAN BAŞLIYOR ──────────────────────────────
  // Setup ekranı bilerek kaydedilmiyor: reel'in ilk karesi kancadır ve
  // renkli, dolu bir tahta duran bir kurulum formundan çok daha güçlü.
  await satir.click();
  await page.locator('[data-cell="0,0"]').waitFor({ timeout: 15000 });
  await page.waitForTimeout(400);
  await bekle(page, 1.0);

  // ── 3 · Taşları sürükle ─────────────────────────────────────────────────
  for (const { rafHarfi, r, c } of HAMLE) {
    const kaynak = await page.evaluate((harf) => {
      const raf = document.querySelector('[data-rack]');
      const kutu = raf.lastElementChild;
      for (const el of kutu.children) {
        if ((el.textContent ?? '').trim().startsWith(harf) && !el.dataset.reelKullanildi) {
          el.dataset.reelKullanildi = '1';
          const b = el.getBoundingClientRect();
          return { x: b.left + b.width / 2, y: b.top + b.height / 2 };
        }
      }
      return null;
    }, rafHarfi);
    if (!kaynak) throw new Error(`Rafta '${rafHarfi}' bulunamadı`);

    const hucre = await page.locator(`[data-cell="${r},${c}"]`).boundingBox();
    const hedef = { x: hucre.x + hucre.width / 2, y: hucre.y + hucre.height / 2 + DRAG_LIFT };

    await page.mouse.move(kaynak.x, kaynak.y);
    await page.mouse.down();
    const ADIM = 7;
    for (let i = 1; i <= ADIM; i++) {
      await page.mouse.move(
        kaynak.x + ((hedef.x - kaynak.x) * i) / ADIM,
        kaynak.y + ((hedef.y - kaynak.y) * i) / ADIM,
      );
      await kare(page);
    }
    await page.mouse.up();
    await kare(page, 0.1);
  }

  // Tahta yeşile döndü + puan rozeti göründü — reel'in en anlatıcı karesi.
  await bekle(page, 1.3);

  // ── 4 · OYNA ────────────────────────────────────────────────────────────
  await page.getByRole('button', { name: 'Oyna', exact: true }).click();
  for (let i = 0; i < 4; i++) {
    await page.waitForTimeout(150);
    await kare(page, 0.16);
  }
  await bekle(page, 0.7);

  // ── 5 · YZ'nin cevabı ───────────────────────────────────────────────────
  // İlk sürümde burada 10 kare + 1.3 sn bekleme vardı; YZ ~1 sn içinde
  // oynadığını bitirdiğinden video son ~5 saniye boyunca DONUK kalıyordu.
  for (let i = 0; i < 4; i++) {
    await page.waitForTimeout(220);
    await kare(page, 0.18);
  }
  await bekle(page, 0.8);

  // ── 6 · Kapanış kartı ───────────────────────────────────────────────────
  // ⚠ AYRI CONTEXT: uygulamayı açan bağlamda PWA service worker'ı kayıtlı ve
  // `navigateFallback` her bilinmeyen navigasyona `index.html` döndürüyor —
  // ilk denemede kapanış kartı yerine Setup ekranı kaydedildi (videonun son
  // 2 saniyesi uygulamayı gösteriyordu). Temiz bir context'te SW yok.
  const temiz = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
  const kapanis = await temiz.newPage();
  await kapanis.goto(`http://127.0.0.1:${port}/reel-kapanis.html`, { waitUntil: 'networkidle' });
  await kapanis.evaluate(() => document.fonts.ready);
  await bekle(kapanis, 2.2);

  // Alt bant (tek kare, videoya ffmpeg ile bindiriliyor).
  const bantSayfa = await temiz.newPage();
  await bantSayfa.setViewportSize({ width: W, height: BANT_H / 2 });
  await bantSayfa.goto(`http://127.0.0.1:${port}/reel-bant.html`, { waitUntil: 'networkidle' });
  await bantSayfa.evaluate(() => document.fonts.ready);
  const bantPng = path.join(FRAMES, 'bant.png');
  await bantSayfa.screenshot({ path: bantPng });

  await browser.close();
  server.close();

  // ── 7 · ffmpeg ──────────────────────────────────────────────────────────
  const liste = kareler
    .map((k) => `file '${k.dosya}'\nduration ${k.sure.toFixed(4)}`)
    .join('\n');
  const listeDosya = path.join(FRAMES, 'liste.txt');
  // concat demuxer son karenin süresini yok sayar — bu yüzden tekrar yazılıyor.
  writeFileSync(listeDosya, `${liste}\nfile '${kareler[kareler.length - 1].dosya}'\n`, 'utf8');

  mkdirSync(path.dirname(OUT), { recursive: true });
  execFileSync('ffmpeg', [
    '-y', '-f', 'concat', '-safe', '0', '-i', listeDosya, '-i', bantPng,
    // Sessiz ses izi: video tamamen sessiz (müziği Instagram'ın kendi
    // düzenleyicisinde eklemek gerekiyor), ama ses izi HİÇ olmayan bir MP4'ü
    // bazı yükleme akışları reddedebiliyor — boş bir AAC izi maliyetsiz sigorta.
    '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
    '-filter_complex',
    `[0:v]fps=${FPS},pad=1080:1920:0:${UST_PAY}:white[bg];` +
      `[bg][1:v]overlay=0:${1920 - BANT_H}:format=auto,format=yuv420p[v]`,
    '-map', '[v]', '-map', '2:a', '-shortest',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '19',
    '-c:a', 'aac', '-b:a', '96k',
    '-movflags', '+faststart',
    OUT,
  ], { stdio: ['ignore', 'ignore', 'pipe'] });

  const sure = kareler.reduce((a, k) => a + k.sure, 0);
  console.log(`✓ ${path.relative(ROOT, OUT)}  ${kareler.length} kare  ~${sure.toFixed(1)} sn`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
