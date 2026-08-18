// Kelimeki — karşılama katmanını `index.html`'e enjekte eden Vite eklentisi.
//
// ⚠ NEDEN ESKLENTİ, "derleme sonrası dist/index.html'i yamalayan bir script"
// DEĞİL: `playwright.config.ts` duman testlerini `npm run dev` (Vite dev
// sunucusu, http://localhost:5173) üzerinde koşturuyor. Yalnızca `dist`'e
// yazan bir çözümde karşılama katmanı dev sunucusunda HİÇ var olmazdı, yani
// (a) `tests/smoke.spec.ts` onu hiçbir zaman göremez, (b) katman tamamen
// bozuk olsa bile mevcut testler yeşil kalmaya devam eder (uygulama modunu
// test ediyorlar), (c) Bölüm 3'te içerik geliştirirken her değişiklikte tam
// derleme gerekirdi. `transformIndexHtml`, Vite'ın HEM `serve` HEM `build`
// modunda çalıştırdığı resmî kanca — doğru yer burası.
//
// Eklenti YALNIZCA EKLEME yapar: PWA manifest'inin `id`/`start_url`/`scope`/
// `display` alanlarına, service worker'ın `navigateFallback`'ine ve
// `vercel.json`'a HİÇ DOKUNMAZ (dolaşımdaki `/game/:id` ve `/davet/:token`
// bağlantıları bunlara bağlı).
//
// Bu dosya bilerek düz JS (`.js`, paket `"type": "module"`): `vite.config.ts`
// `tsconfig.node.json` ile derleniyor ve projede `@types/node` YOK — Node
// API'lerini TypeScript'te kullanmak tip hatası üretirdi. Tip yüzeyi
// `landing-plugin.d.ts`te.
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { build } from 'esbuild';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CACHE_DIR = path.join(ROOT, 'node_modules', '.cache', 'kelimeki');

/**
 * `src/landing/render.tsx`'i esbuild ile Node'da çalışacak şekilde paketleyip
 * import eder. Bileşen `.tsx` ama bu eklenti Node'da çalışıyor — bu kod
 * tabanının kendi kalıbını izliyoruz: `scripts/verify-cloud-save-mirror.ts`
 * ve `scripts/verify-fetch-my-games.ts` de ÜRETİM kodunu esbuild ile
 * paketleyip node'da koşuyor. Yeni bir çatı (Next.js/Astro) EKLENMEDİ.
 *
 * Modül İKİ fonksiyon export ediyor (`renderLandingHtml` + `renderFaqJsonLd`,
 * 18 Ağustos 2026'da eklendi) — ikisi de aynı `SSS` dizisini tükettiğinden
 * TEK build/import yeterli, iki ayrı esbuild çağrısı gerekmiyor.
 *
 * ⚠ ÇAĞRILARI SERİLEŞTİREN sarmalayıcı için aşağıdaki `loadLandingModule`a
 * bak — bu fonksiyon DOĞRUDAN çağrılmamalı.
 */
async function buildAndImportLandingModule() {
  mkdirSync(CACHE_DIR, { recursive: true });
  const outfile = path.join(CACHE_DIR, 'landing-render.mjs');
  await build({
    entryPoints: [path.join(ROOT, 'src', 'landing', 'render.tsx')],
    bundle: true,
    platform: 'node',
    format: 'esm',
    jsx: 'automatic',
    // React'i PAKETE KATMIYORUZ, Node'un kendisi çözsün: `react-dom/server`
    // Node koşulunda `stream`'i `require` ediyor ve ESM'e paketlenince bu
    // "Dynamic require of \"stream\" is not supported" ile patlıyor
    // (denendi, birebir bu hata alındı). Dışarıda bırakılınca Node onu
    // normal şekilde yükleyip sorunsuz çalışıyor.
    external: ['react', 'react-dom', 'react-dom/server'],
    // CSS import'ları bu yolda anlamsız (stil `index.css`ten geliyor) —
    // esbuild'in onlara takılmaması için boş modüle çeviriyoruz.
    loader: { '.css': 'empty' },
    outfile,
    logLevel: 'error',
  });
  // Sorgu parametresi Node'un ESM modül önbelleğini kırar — dosya adı sabit
  // olduğundan (her derlemede yeni bir dosya bırakmıyoruz) `npm run dev`'de
  // katman düzenlenince yeniden okunması buna bağlı.
  return import(/* @vite-ignore */ `file://${outfile}?t=${Date.now()}`);
}

/**
 * Derleme + import'u TEK SIRAYA dizer.
 *
 * ⚠ NEDEN: `transformIndexHtml` dev sunucusunda HER `/` isteğinde çalışıyor ve
 * yukarıdaki fonksiyon her seferinde AYNI `outfile`a yazıp onu import ediyor.
 * İki istek aynı anda gelirse (Playwright duman testleri `fullyParallel` ve CI'da
 * 2 worker ile koşuyor — yani ilk iki test sayfayı neredeyse aynı anda açıyor)
 * derleme B, import A dosyayı okurken onu KESİP baştan yazıyor; yarım okunan
 * modülün export'u olmadığından `mod.renderLandingHtml is not a function`
 * fırlıyor ve Vite 500 dönüyor — sayfanın başlığı "Error" oluyor.
 *
 * Bu, 18 Ağustos 2026'da `main`'de bir kez GERÇEKLEŞTİ (koşu 32196434157, 18
 * testin 1'i düştü; AYNI ağaç PR'da geçmişti — yani bir flake, kod hatası
 * değil). Bu ortamda 120 eşzamanlı istekle yeniden ÜRETİLEMEDİ (disk/önbellek
 * hızlı), yani düzeltme "ölçülen bir hata"nın değil ÖLÇÜLEN BİR YARIŞ
 * PENCERESİNİN kapatılması: aynı dosyaya yazan ve onu okuyan iki iş
 * serileşmedikçe sıra garanti değildir (kök CLAUDE.md'nin `local_game_saves`
 * dersi, portun `TableWriteQueue`'su ve web'in `enqueueSaveWrite`i aynı kural).
 *
 * Maliyet dev sunucusunda ölçüldü: derleme+import ~50 ms, yani eşzamanlı
 * isteklerde tek sıra gecikmesi ihmal edilebilir (ve yalnızca `/` isteklerinde).
 */
let landingChain = Promise.resolve();

function loadLandingModule() {
  // Zincir hata durumunda KIRILMAMALI: bir derleme patlarsa sonraki istek yine
  // denenebilmeli, bu yüzden zincirin kendisi her zaman "başarılı"ya çekiliyor.
  const result = landingChain.then(
    buildAndImportLandingModule,
    buildAndImportLandingModule,
  );
  landingChain = result.then(
    () => undefined,
    () => undefined,
  );
  return result;
}

/**
 * `<head>`'e giren SENKRON kapı script'i (~400 bayt). Gövde ayrıştırılmadan
 * çalıştığından karar İLK BOYAMADAN ÖNCE verilir — katman görünüp kaybolmaz.
 *
 * Kapı NİYETE bakar, görmeye değil: `kelimeki:anon-id` BİLEREK listede YOK.
 * Olsaydı, hiç oynamadan çıkan bir ziyaretçi ikinci gelişinde "dönen
 * kullanıcı" sayılıp katmanı bir daha görmezdi (o kimliği `main.tsx`'in
 * misafir-ziyaret pingi zaten ilk ziyarette üretiyor).
 *
 * Supabase oturum anahtarı proje referansını içeriyor (`sb-<ref>-auth-token`)
 * — ref'i buraya sabit yazmak yerine anahtarlar taranıyor: ortam değişkeni
 * değişirse (ya da yerelde `.env` hiç yoksa) kapı yine doğru çalışır.
 *
 * `localStorage` erişimi `try/catch` içinde OLMAK ZORUNDA: gizli sekmede /
 * depolama kapalıyken fırlarsa sayfa hiç boyanmaz.
 *
 * ⚠ `kelimeki:seen-intro` adı `src/utils/onboarding.ts`'teki `SEEN_INTRO_KEY`
 * ile ELLE senkron — bu script HTML'e gömülü düz JS olduğundan o modülü
 * import edemez.
 *
 * `bootHref` verilirse (yalnızca derlemede — dev sunucusunda parça adı yok)
 * `modulepreload` etiketi BURADA, yalnızca uygulama modunda enjekte edilir.
 * ⚠ Etiketi statik olarak `<head>`'e yazmak ÖLÇÜLDÜ ve YANLIŞTI: karşılama
 * katmanını gören ziyaretçi de `boot-*.js`'i (≈220 KB gzip) indiriyordu, yani
 * "katmanda 0 KB uygulama JS'i" hedefi sessizce delinmişti.
 */
function kapiScript(bootHref) {
  const preload = bootHref
    ? `var e=document.createElement('link');e.rel='modulepreload';e.crossOrigin='anonymous';e.href=${JSON.stringify(bootHref)};document.head.appendChild(e);`
    : '';
  return `(function(){try{` +
    `var d=document.documentElement,l=localStorage,g=function(){d.classList.add('uygulama-modu');${preload}};` +
    // 1) Ana sayfa dışındaki her yol: /game/:id, /davet/:token — katman hiç görünmez.
    `if(location.pathname!=='/')return g();` +
    // 2) `?tanitim=1` — kurulum ekranındaki ev düğmesinin bilinçli geri
    //    dönüşü. Katman DOM'dan silindiği için geri gelmenin tek yolu tam bir
    //    yeniden yükleme; bu parametre de dönen kullanıcı sinyallerini
    //    (seen-intro/oturum/PWA) BİLEREK atlayan tek kapıdır. `gec()` geçişte
    //    URL'yi temizlediğinden bir sonraki açılışta yine uygulamaya düşülür.
    `if(location.search.indexOf('tanitim=1')>=0)return;` +
    // 3) Katmanı zaten geçmiş VEYA yarım kalmış yerel oyunu var.
    `if(l.getItem('kelimeki:seen-intro')||l.getItem('kelimeki:game-state'))return g();` +
    // 4) Supabase oturumu var (giriş yapmış).
    `for(var i=0;i<l.length;i++){var k=l.key(i);` +
    `if(k&&k.indexOf('sb-')===0&&k.slice(-11)==='-auth-token')return g();}` +
    // 5) Ana ekrana eklemiş (PWA standalone).
    `if(navigator.standalone===true||matchMedia('(display-mode: standalone)').matches)return g();` +
    `}catch(e){}}())`;
}

/**
 * Vite eklentisi. `transformIndexHtml` hem dev sunucusunda hem derlemede
 * çalışır; `enforce: 'pre'` YOK — mevcut `kelimeki-build-stamp` eklentisiyle
 * aynı sırada, ondan sonra koşması yeterli (ikisi de `</head>`e ekleme yapıyor
 * ama farklı satırlar).
 */
export function kelimekiLanding() {
  return {
    name: 'kelimeki-landing',
    // `order: 'post'` — dönen kullanıcı için enjekte edeceğimiz
    // `<link rel="modulepreload">` ancak Vite giriş script'ini HTML'e
    // yerleştirdikten SONRA doğru hash'le yazılabilir (aşağı bkz.).
    transformIndexHtml: {
      order: 'post',
      async handler(html, ctx) {
        const mod = await loadLandingModule();
        const landing = mod.renderLandingHtml();

        // Dönen kullanıcı `main.tsx`'ten `boot-*.js`'e DİNAMİK import ile
        // gidiyor; bu, önlem alınmazsa ilk boyamaya fazladan bir ağ turu
        // ekler. Derlemede parça adı (hash dahil) biliniyor — kapı script'i
        // uygulama moduna geçerken `modulepreload` etiketini kendisi
        // ekliyor (karşılama katmanını gören ziyaretçi eklemiyor). Dev
        // sunucusunda modül grafiği zaten hash'siz ve anında, gerekmiyor.
        const bootChunk = ctx?.bundle
          ? Object.keys(ctx.bundle).find((f) => /(^|\/)assets\/boot-[^/]+\.js$/.test(f))
          : null;

        const gate = `    <script>${kapiScript(bootChunk ? `/${bootChunk}` : null)}</script>\n`;

        // `FAQPage` yapılandırılmış verisi (18 Ağustos 2026, SEO denetimi) —
        // mevcut `WebApplication` ld+json bloğunun (index.html'de statik)
        // hemen yanına. Metinler `SSS` (Landing.tsx) dizisinden geliyor,
        // ikinci kez yazılmıyor — bkz. render.tsx'teki `renderFaqJsonLd`.
        const faq = `    <script type="application/ld+json">${mod.renderFaqJsonLd()}</script>\n`;

        return html
          .replace('</head>', `${gate}${faq}  </head>`)
          .replace('<div id="root"></div>', `${landing}\n    <div id="root"></div>`);
      },
    },
  };
}
