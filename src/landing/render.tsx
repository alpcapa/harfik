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
import { Landing } from './Landing';

export function renderLandingHtml(): string {
  return renderToStaticMarkup(<Landing />);
}
