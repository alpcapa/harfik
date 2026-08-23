// Hukuki sayfaları (`/gizlilik/`, `/kullanim-kosullari/`, `/hesap-silme/`)
// DERLEME ZAMANINDA statik HTML olarak üreten Vite eklentisi.
//
// NEDEN EKLENTİ, derleme sonrası bir betik DEĞİL: `playwright.config.ts`
// duman testlerini `npm run dev` üzerinde koşturuyor. Yalnızca `dist`e yazan
// bir çözümde sayfalar dev sunucusunda HİÇ var olmaz, yani testler onları
// göremez ve sayfalar tamamen bozukken bile yeşil kalır — karşılama katmanının
// (`scripts/landing-plugin.js`) aynı gerekçesi.
//
// ⚠ Derleme + import TEK SIRAYA dizilmiş: aynı `outfile`a yazıp onu import
// eden iki eşzamanlı istek, yarım okunan bir modül üretebiliyor (landing
// eklentisinde 18 Ağustos 2026'da `main`'de bir kez GERÇEKLEŞTİ).
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build as esbuild } from 'esbuild';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUTFILE = path.join(ROOT, 'node_modules', '.cache', 'kelimeki', 'legal-render.mjs');

async function buildAndImport() {
  mkdirSync(path.dirname(OUTFILE), { recursive: true });
  await esbuild({
    entryPoints: [path.join(ROOT, 'src', 'legal', 'render.tsx')],
    bundle: true,
    platform: 'node',
    format: 'esm',
    jsx: 'automatic',
    external: ['react', 'react-dom', 'react-dom/server'],
    loader: { '.css': 'empty' },
    outfile: OUTFILE,
    logLevel: 'error',
  });
  return import(/* @vite-ignore */ `file://${OUTFILE}?t=${Date.now()}`);
}

let chain = Promise.resolve();
function loadModule() {
  const result = chain.then(buildAndImport, buildAndImport);
  chain = result.then(
    () => undefined,
    () => undefined,
  );
  return result;
}

export function kelimekiLegalPages() {
  return {
    name: 'kelimeki-legal-pages',

    // Dev sunucusu: sayfaları anında üretip servis eder. Stil, derlenmiş CSS
    // yerine kaynaktan gelir (`?direct` — Vite bu ekle ham CSS döndürüyor,
    // eksiz hâli JS sarmalayıcı döner ve sayfa stilsiz kalırdı).
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const url = (req.url ?? '').split('?')[0];
        const mod = await loadModule().catch(() => null);
        if (!mod) return next();
        const sayfa = mod.LEGAL_PAGES.find(
          (s) => url === s.yol || url === s.yol.slice(0, -1),
        );
        if (!sayfa) return next();
        const html = mod.renderLegalPage(sayfa, '/src/index.css?direct');
        res.setHeader('content-type', 'text/html; charset=utf-8');
        res.end(html);
      });
    },

    // Derleme: sayfaları `dist` içine ayrı dosyalar olarak bırakır.
    async generateBundle(_options, bundle) {
      const cssFile = Object.keys(bundle).find(
        (f) => f.startsWith('assets/index-') && f.endsWith('.css'),
      );
      if (!cssFile) {
        this.error('assets/index-*.css bulunamadı — hukuki sayfalar stilsiz kalırdı.');
      }
      const mod = await loadModule();
      for (const sayfa of mod.LEGAL_PAGES) {
        this.emitFile({
          type: 'asset',
          fileName: sayfa.dosya,
          source: mod.renderLegalPage(sayfa, `/${cssFile}`),
        });
      }
    },
  };
}
