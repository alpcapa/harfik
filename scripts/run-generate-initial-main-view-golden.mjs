// `generate-initial-main-view-golden.ts`i bundle'layıp koşan sürücü.
//
// `run-verify-live-games-load.mjs` ile BİREBİR aynı gerekçe: `pendingLiveGames`
// dolaylı olarak `src/lib/supabase`i çekiyor ve o, modül gövdesinde
// `import.meta.env`e bakıp node'da çöküyor. Ölçülen/koşturulan şey yine
// ÜRETİM `decideInitialMainView`in kendisi — yalnızca istemci sahte.
import { build } from 'esbuild';
import { pathToFileURL } from 'node:url';
import { mkdirSync } from 'node:fs';
import path from 'node:path';

const out = path.resolve(
  'node_modules/.cache/kelimeki/initial-main-view-golden.mjs',
);
mkdirSync(path.dirname(out), { recursive: true });

await build({
  entryPoints: ['scripts/generate-initial-main-view-golden.ts'],
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
  location: { pathname: '/' },
  __KELIMEKI_BUILD__: 'golden',
  addEventListener: () => {},
};

await import(pathToFileURL(out).href);
