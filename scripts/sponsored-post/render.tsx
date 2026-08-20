// Kelimeki — sponsorlu carousel görsellerinin statik HTML'e çevrildiği nokta.
// YALNIZCA Node'da çalışır (bkz. `scripts/sponsored-post/build.mjs`);
// tarayıcı paketine hiç girmez. `src/landing/render.tsx` ile aynı kalıp.
import { renderToStaticMarkup } from 'react-dom/server';
import { SponsoredPost } from './SponsoredPost';

/**
 * @param cssHref Derlenmiş uygulama CSS'inin yolu. Görsellerdeki tahta/rütbe/
 *   font stilleri ORADAN geliyor — poster kendi Tailwind'ini üretmiyor
 *   (bkz. `SponsoredPost.tsx` başlığındaki `content` tuzağı).
 */
export function renderPostHtml(cssHref: string): string {
  const body = renderToStaticMarkup(<SponsoredPost />);
  return `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<title>Kelimeki — sponsorlu gönderi görselleri</title>
<link rel="stylesheet" href="${cssHref}">
<style>
  html, body { margin: 0; padding: 0; background: #E8EBEF; }
  /* Ekran görüntüsü alınırken her kare tek başına kırpılıyor; aradaki boşluk
     yalnızca HTML'i gözle denetlerken işe yarıyor. */
  #kelimeki-post { display: flex; flex-direction: column; align-items: center; gap: 24px; padding: 24px 0; }
</style>
</head>
<body>${body}</body>
</html>`;
}
