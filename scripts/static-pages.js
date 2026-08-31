// SPA'nın DIŞINDA, derleme zamanında statik HTML olarak üretilen sayfaların
// yolları. **TEK KAYNAK** — iki ayrı tüketici buradan besleniyor:
//
//   1. `src/legal/render.tsx` → `STATIC_PAGES` (sayfanın kendisi üretilir);
//      oradaki `Sayfa.yol` bu listenin birleşim TİPİ, yani yeni bir sayfa
//      buraya eklenmeden derleme geçmez.
//   2. `vite.config.ts` → service worker'ın `navigateFallbackDenylist`i.
//
// ⚠ NEDEN VAR: liste 31 Ağustos 2026'ya kadar (2)'de ELLE tutuluyordu ve
// `/nasil-oynanir/` eklenirken güncellenmedi. Sonuç: service worker kurulu
// bir tarayıcıda eğik çizgisiz `/nasil-oynanir` uygulama kabuğuna düşüyordu
// — denylist'in var oluş sebebi olan, `/gizlilik` için daha önce ÖLÇÜLMÜŞ
// hatanın aynısı.
//
// ⚠ NEDEN `scripts/` ALTINDA VE `.js`: ilk deneme dosyayı `src/legal/`e
// koydu ve `tsconfig.node.json`un include'ına ekledi. O zaman dosya İKİ
// composite projeye birden girdi (`tsconfig.json` zaten `src`i kapsıyor) ve
// temiz bir checkout'ta CI düştü:
//   error TS6305: Output file '.../paths.d.ts' has not been built from
//   source file 'src/legal/paths.ts'.
// Yerelde önbellek dolu olduğu için görünmüyordu. Bu dosya artık hiçbir TS
// programının parçası değil; tipini yanındaki `.d.ts` veriyor — `scripts/`
// altındaki Vite eklentilerinin (landing-plugin, legal-plugin) kalıbı.
export const STATIC_PAGE_PATHS = [
  '/gizlilik/',
  '/kullanim-kosullari/',
  '/hesap-silme/',
  '/nasil-oynanir/',
];

// Service worker'ın gezinme fallback'inden muaf tutulacak desenler.
//
// Sondaki eğik çizgi BİLEREK atılıyor: `/gizlilik/` precache rotasına
// (`directoryIndex`) takılıp zaten doğru geliyordu, kabuğa düşen eğik
// çizgisiz biçimdi. Desen ikisini de kapsamalı.
export function staticPageDenylist() {
  return STATIC_PAGE_PATHS.map(
    (yol) => new RegExp('^' + yol.replace(/\/$/, '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&')),
  );
}
