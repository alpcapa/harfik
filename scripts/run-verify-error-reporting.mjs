// `verify-error-reporting.ts`i bundle'layıp koşan sürücü.
//
// İki şeyi bundle'ın DIŞINDA yapmak zorunda:
//  1. `src/lib/supabase`i sahteye yönlendirmek — o modül gövdesinde
//     `import.meta.env` okuyor ve node'da düşerdi (`run-verify-fetch-my-games`
//     ile aynı `onResolve` eklentisi; CLI `--alias`ı göreli yol kabul etmiyor).
//  2. `window`u kurmak — ESM import'ları hoisted olduğundan betiğin kendi
//     içinde yazılan bir atama modül gövdelerinden sonra çalışırdı.
import { build } from 'esbuild';
import { pathToFileURL } from 'node:url';
import { mkdirSync } from 'node:fs';
import path from 'node:path';

const out = path.resolve('node_modules/.cache/kelimeki/verify-error-reporting.mjs');
mkdirSync(path.dirname(out), { recursive: true });

await build({
  entryPoints: ['scripts/verify-error-reporting.ts'],
  bundle: true,
  platform: 'node',
  format: 'esm',
  outfile: out,
  logLevel: 'error',
  plugins: [
    {
      name: 'fake-supabase',
      setup(b) {
        b.onResolve({ filter: /(^|\/)supabase$/ }, (args) => {
          if (!args.importer.includes(`${path.sep}src${path.sep}`)) return null;
          return { path: path.resolve('scripts/support/fake-supabase.ts') };
        });
      },
    },
  ],
});

globalThis.window = {
  location: { pathname: '/game/9c1f5d2e-0000-4000-8000-000000000000' },
  __KELIMEKI_BUILD__: 'a1b2c3d',
  addEventListener: () => {},
};

await import(pathToFileURL(out).href);
