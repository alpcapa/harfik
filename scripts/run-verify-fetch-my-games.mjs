// `verify-fetch-my-games.ts`i bundle'layıp koşan sürücü.
//
// esbuild'in CLI `--alias`'ı GÖRELİ yol kabul etmiyor ("Invalid alias name"),
// bu yüzden JS API'si + bir `onResolve` eklentisi kullanılıyor: `src/lib/api`in
// `./supabase` importu sahte istemciye yönlendiriliyor. Ölçülen şey yine
// ÜRETİM `fetchMyGames`inin kendisi — yalnızca istemci sahte.
import { build } from 'esbuild';
import { pathToFileURL } from 'node:url';
import { mkdirSync } from 'node:fs';
import path from 'node:path';

const out = path.resolve('node_modules/.cache/kelimeki/verify-fetch-my-games.mjs');
mkdirSync(path.dirname(out), { recursive: true });

await build({
  entryPoints: ['scripts/verify-fetch-my-games.ts'],
  bundle: true,
  platform: 'node',
  format: 'esm',
  outfile: out,
  logLevel: 'error',
  plugins: [
    {
      name: 'fake-supabase',
      setup(b) {
        // `src/lib/api.ts` içindeki `./supabase` (ve varsa başka bir
        // `lib/supabase` importu) sahteye gitsin.
        b.onResolve({ filter: /(^|\/)supabase$/ }, (args) => {
          if (!args.importer.includes(`${path.sep}src${path.sep}lib${path.sep}`)) return null;
          return { path: path.resolve('scripts/support/fake-supabase.ts') };
        });
      },
    },
  ],
});

await import(pathToFileURL(out).href);
