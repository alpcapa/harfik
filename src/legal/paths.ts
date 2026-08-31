// SPA'nın DIŞINDA, derleme zamanında statik HTML olarak üretilen sayfaların
// yolları. **TEK KAYNAK** — iki ayrı tüketici buradan besleniyor:
//
//   1. `render.tsx` → `STATIC_PAGES` (sayfanın kendisi üretilir)
//   2. `vite.config.ts` → service worker'ın `navigateFallbackDenylist`i
//
// ⚠ NEDEN AYRI BİR DOSYA: bu liste 31 Ağustos 2026'da elle tutuluyordu ve
// `/nasil-oynanir/` eklenirken (2) GÜNCELLENMEDİ. Sonuç: service worker
// kurulu bir tarayıcıda eğik çizgisiz `/nasil-oynanir` uygulama kabuğuna
// düşüyordu — tam olarak denylist'in var oluş sebebi olan, `/gizlilik` için
// daha önce ÖLÇÜLMÜŞ hata. Artık bağ derleyicide: `Sayfa.yol` bu listenin
// birleşim tipi, yani yeni bir sayfa buraya eklenmeden `render.tsx`
// derlenmez ve denylist otomatik büyür.
//
// `vite.config.ts` bu dosyayı doğrudan import ediyor — bu yüzden burada
// React/JSX ya da başka bir bağımlılık OLMAMALI.
export const STATIC_PAGE_PATHS = [
  '/gizlilik/',
  '/kullanim-kosullari/',
  '/hesap-silme/',
  '/nasil-oynanir/',
] as const;

export type StaticPagePath = (typeof STATIC_PAGE_PATHS)[number];

/**
 * Service worker'ın gezinme fallback'inden muaf tutulacak desenler.
 *
 * Sondaki eğik çizgi BİLEREK atılıyor: `/gizlilik/` precache rotasına
 * (`directoryIndex`) takılıp zaten doğru geliyordu, kabuğa düşen eğik
 * çizgisiz biçimdi. Desen ikisini de kapsamalı.
 */
export function staticPageDenylist(): RegExp[] {
  return STATIC_PAGE_PATHS.map(
    (yol) => new RegExp('^' + yol.replace(/\/$/, '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&')),
  );
}
