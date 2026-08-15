/// <reference types="vite/client" />
/// <reference types="vite-plugin-pwa/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL?: string;
  readonly VITE_SUPABASE_ANON_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

/**
 * Bu derlemenin git commit'i (kısa sha) — `vite.config.ts` `define` ile
 * gömüyor, Vercel'de `VERCEL_GIT_COMMIT_SHA`'dan gelir, yerelde `'yerel'`.
 * `main.tsx` bunu `window.__KELIMEKI_BUILD__` olarak da yayınlıyor ki
 * "sekmede hangi commit çalışıyor?" sorusu devtools'tan yanıtlanabilsin.
 */
declare const __KELIMEKI_BUILD__: string;

interface Window {
  __KELIMEKI_BUILD__?: string;
}
