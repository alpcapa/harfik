// `verify-shared-realtime.ts`i bundle'layıp koşan sürücü — `run-verify-live-games-load.mjs`in
// birebir aynı deseni (aynı sahte Supabase eklentisi, aynı `window` kabuğu).
//
// esbuild'in CLI `--alias`'ı GÖRELİ yol kabul etmiyor ("Invalid alias name"),
// bu yüzden JS API'si + bir `onResolve` eklentisi kullanılıyor: `src/lib/api`in
// `./supabase` importu sahte istemciye yönlendiriliyor. Ölçülen şey yine
// ÜRETİM `fetchMyGames`inin kendisi — yalnızca istemci sahte.
import { build } from 'esbuild';
import { pathToFileURL } from 'node:url';
import { mkdirSync } from 'node:fs';
import path from 'node:path';

const out = path.resolve('node_modules/.cache/kelimeki/verify-shared-realtime.mjs');
mkdirSync(path.dirname(out), { recursive: true });

await build({
  entryPoints: ['scripts/verify-shared-realtime.ts'],
  bundle: true,
  platform: 'node',
  format: 'esm',
  outfile: out,
  logLevel: 'error',
  plugins: [
    {
      name: 'fake-supabase',
      setup(b) {
        // `src/` altındaki HERHANGİ bir dosyanın `supabase` importu sahteye
        // gitsin. Filtre bir dönem yalnızca `src/lib/` idi; `api.ts`
        // `utils/errorReporting`i (o da `../lib/supabase`i) import edince
        // gerçek istemci pakete girip node'da `import.meta.env` üzerinden
        // çöküyordu. `run-verify-error-reporting.mjs` baştan geniş filtre
        // kullanıyordu — ikisi artık aynı.
        b.onResolve({ filter: /(^|\/)supabase$/ }, (args) => {
          if (!args.importer.includes(`${path.sep}src${path.sep}`)) return null;
          return { path: path.resolve('scripts/support/fake-supabase.ts') };
        });
      },
    },
  ],
});

// `reportClientError` (api.ts artık onu çağırıyor) modül gövdesinde değil
// çağrıldığında `window.location`a bakıyor — node'da bir kabuk şart.
globalThis.window = {
  location: { pathname: '/', origin: 'https://kelimeki.com' },
  __KELIMEKI_BUILD__: 'verify',
  addEventListener: () => {},
};

await import(pathToFileURL(out).href);
