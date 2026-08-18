// Kelimeki — karşılama katmanının statik HTML'e çevrildiği tek nokta.
//
// Bu modül YALNIZCA Node'da (Vite eklentisi içinde, derleme/servis zamanında)
// çalışır; tarayıcı paketine HİÇ girmez. `react-dom/server` zaten kurulu
// (react-dom 18.3.1) — yeni bir bağımlılık ya da Next.js/Astro gibi bir çatı
// EKLENMEDİ.
//
// Bölüm 3 gerçek tahta demosunu buraya ekleyecek: ölçüldü, `Board.tsx` ve
// `Tile.tsx` sıfır tarayıcı globali ve sıfır `useEffect` içeriyor, yani
// hiçbir uyarlama olmadan sunucuda render edilebiliyorlar.
import { renderToStaticMarkup } from 'react-dom/server';
import { Landing, SSS } from './Landing';

export function renderLandingHtml(): string {
  return renderToStaticMarkup(<Landing />);
}

/**
 * `FAQPage` yapılandırılmış verisi (18 Ağustos 2026, SEO denetimi) —
 * `<head>`'e `scripts/landing-plugin.js` tarafından, mevcut `WebApplication`
 * ld+json bloğunun yanına enjekte edilir.
 *
 * NEDEN `src/` içinde `dangerouslySetInnerHTML` DEĞİL: CLAUDE.md'de mutlak
 * bir değişmez var — "`src/` altında `dangerouslySetInnerHTML` HİÇ
 * kullanılmıyor". JSON-LD'yi `Landing.tsx` içinden basmak (veri bizim
 * sabitlerimiz olsa bile) bu değişmezi ihlal ederdi. Bunun yerine bu
 * fonksiyon düz bir JSON STRING üretiyor, eklenti onu kendi ürettiği
 * `<script>` etiketinin İÇİNE koyuyor — React'in render ağacı hiç
 * `dangerouslySetInnerHTML` görmüyor.
 *
 * Metinler `SSS` (`Landing.tsx`) dizisinden OKUNUYOR — ikinci kez
 * yazılmıyor; ekrandaki altı soru ile burasının ayrışması bu projenin en
 * sık tekrarlayan hata sınıfı olurdu.
 *
 * `<` karakterleri `<`'ye kaçırılıyor: `JSON.stringify` çıktısı
 * olduğu gibi bir `<script>` etiketinin içine konursa, bir cevap
 * metnindeki (bugün yok ama ileride gelebilecek) bir `<` karakteri
 * `</script>`i erkenden kapatabilirdi.
 */
export function renderFaqJsonLd(): string {
  const data = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: SSS.map((s) => ({
      '@type': 'Question',
      name: s.soru,
      acceptedAnswer: {
        '@type': 'Answer',
        text: s.cevap,
      },
    })),
  };
  return JSON.stringify(data).replace(/</g, '\\u003c');
}
