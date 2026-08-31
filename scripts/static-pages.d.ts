// Bkz. static-pages.js — tek kaynak orada, bu dosya yalnızca tipini veriyor.
// `as const` tuple tipi kritik: `StaticPagePath` bundan türüyor ve
// `src/legal/render.tsx`teki `Sayfa.yol`u bağlıyor.
export declare const STATIC_PAGE_PATHS: readonly [
  '/gizlilik/',
  '/kullanim-kosullari/',
  '/hesap-silme/',
  '/nasil-oynanir/',
];

export type StaticPagePath = (typeof STATIC_PAGE_PATHS)[number];

export declare function staticPageDenylist(): RegExp[];
