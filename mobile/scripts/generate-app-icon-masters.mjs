// Uygulama ikonu / splash ana görselleri — mobile/CLAUDE.md, "Uygulama İkonu
// / Splash" (bkz. bu betiğin yazıldığı iş). Kaynak TEK bir yerden geliyor:
// public/icon.svg — kök `scripts/generate-icons.mjs`'in ürettiği, web PWA
// ikonunu/favicon'u besleyen aynı SVG. Yeni bir marka görseli İCAT EDİLMEDİ;
// mobil uygulama ikonu web'deki ile PİKSEL AÇISINDAN aynı kompozisyondan
// (tahta filigranı + "kelimeki" el yazısı) türetiliyor.
//
// Üretir (mobile/app/assets/icon/):
//   icon-source.png      — 1024×1024, opak beyaz zemin. iOS AppIcon +
//                           Android LEGACY (mipmap-*) ikonu için — tam kanama,
//                           web'deki icon-512.png ile birebir aynı kompozisyon.
//   icon-adaptive-fg.png — 1024×1024, ŞEFFAF zemin, içerik ortalanmış ve
//                           %66'lık güvenli bölgeye (Android adaptive icon
//                           dairesel/squircle maskeleri hiçbir zaman bu
//                           bölgeyi kesmez) küçültülmüş. Android ADAPTIVE
//                           ikonun ön katmanı VE splash görseli olarak İKİ
//                           amaçla kullanılıyor — tek dosya, tek kaynak.
//
// Bu betik yalnızca ARA görsel üretir; asıl platform dosyalarını
// (AppIcon.appiconset/mipmap-*/LaunchScreen) `flutter_launcher_icons` ve
// `flutter_native_splash` (mobile/app'te `dart run ...`) üretir — bkz.
// mobile/CLAUDE.md.
import { chromium } from 'playwright';
import sharp from 'sharp';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '../..');
const OUT_DIR = join(__dirname, '../app/assets/icon');
mkdirSync(OUT_DIR, { recursive: true });

const RENDER = 1024;
const iconSvgRaw = readFileSync(join(ROOT, 'public/icon.svg'), 'utf8');

let _browser;
async function renderSvg(svg, size) {
  const html = `<!DOCTYPE html><html><head><meta charset="UTF-8"/>
    <style>*{margin:0;padding:0} body{width:${size}px;height:${size}px}
    svg{width:${size}px;height:${size}px;display:block}</style></head>
    <body>${svg}</body></html>`;
  _browser ??= await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium',
  });
  const page = await _browser.newPage();
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(html, { waitUntil: 'networkidle' });
  await page.waitForTimeout(150);
  const png = await page.screenshot({ type: 'png', omitBackground: true });
  await page.close();
  return png;
}

// 1) Tam-kanama, opak beyaz — iOS/Android LEGACY ikon kaynağı.
const sourcePng = await renderSvg(iconSvgRaw, RENDER);
writeFileSync(join(OUT_DIR, 'icon-source.png'), sourcePng);
console.log('✓ icon-source.png (1024×1024, opak, tam kanama)');

// 2) Şeffaf zemin — icon.svg'deki `<rect ... fill="#ffffff"/>` beyaz zemin
// dikdörtgenini kaldırıp aynı SVG'yi tekrar render ediyoruz (içerik/oranlar
// BİREBİR aynı, yalnızca zemin şeffaf).
const transparentSvg = iconSvgRaw.replace(
  /<rect width="512" height="512" fill="#ffffff"\/>/,
  '',
);
if (transparentSvg === iconSvgRaw) {
  throw new Error(
    'icon.svg beklenen beyaz zemin <rect>ini içermiyor — public/icon.svg değişmiş olabilir, bu betiği güncelle.',
  );
}
const transparentPng = await renderSvg(transparentSvg, RENDER);

// %66'lık güvenli bölgeye küçült + 1024×1024 şeffaf tuvalin ortasına yerleştir.
// Android adaptive ikon maskeleri (dairesel/squircle/yuvarlatılmış kare) en
// kötü ihtimalle merkezi %66'lık bir daireyi asla kesmiyor — içerik bunun
// dışına taşarsa launcher'a göre "kelimeki" kelimesinin kenarları kırpılabilir.
const SAFE_ZONE = 0.66;
const inner = Math.round(RENDER * SAFE_ZONE);
const offset = Math.round((RENDER - inner) / 2);
const adaptiveFg = await sharp({
  create: {
    width: RENDER,
    height: RENDER,
    channels: 4,
    background: { r: 0, g: 0, b: 0, alpha: 0 },
  },
})
  .composite([
    {
      input: await sharp(transparentPng).resize(inner, inner).toBuffer(),
      left: offset,
      top: offset,
    },
  ])
  .png()
  .toBuffer();
writeFileSync(join(OUT_DIR, 'icon-adaptive-fg.png'), adaptiveFg);
console.log('✓ icon-adaptive-fg.png (1024×1024, şeffaf, %66 güvenli bölge)');

await _browser?.close();
