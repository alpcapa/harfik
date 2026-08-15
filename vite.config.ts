import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

/**
 * Bu derlemenin kimliği — Vercel `VERCEL_GIT_COMMIT_SHA`'yı her derlemede
 * veriyor; yerelde boş kalır ve `yerel` yazar.
 *
 * NEDEN VAR (15 Ağustos 2026): "düzelttim" ile "canlıda görünüyor" arasındaki
 * boşluk gerçek zaman yaktı — kullanıcı BAYAT bir derlemeyi test edip
 * "düzelmemiş" diye bildirdi. Bu değer `<meta name="kelimeki-build">` ve
 * `window.__KELIMEKI_BUILD__` olarak yayınlanıyor: bir sekmede hangi
 * commit'in çalıştığı artık kod okumadan, tek bakışta doğrulanabiliyor.
 * Mobil portun görünür karşılığı: Setup teşhis satırındaki "Derleme …"
 * (bkz. `mobile/app/lib/src/config/env.dart`, `buildSha`).
 */
// `@types/node` bu projede yok (istemci tarafı tsconfig'i) — tek bir env
// okuması için bağımlılık eklemek yerine yerel bildirim yeterli.
declare const process: { env: Record<string, string | undefined> };

const BUILD_ID =
  (process.env.VERCEL_GIT_COMMIT_SHA ?? '').slice(0, 7) || 'yerel';

// https://vitejs.dev/config/
export default defineConfig({
  define: {
    __KELIMEKI_BUILD__: JSON.stringify(BUILD_ID),
  },
  plugins: [
    react(),
    {
      // Derleme kimliğini HTML'e gömer — `view-source` ya da devtools'ta
      // görünür, normal kullanıcıya hiçbir şey göstermez.
      name: 'kelimeki-build-stamp',
      transformIndexHtml: (html: string) =>
        html.replace(
          '</head>',
          `  <meta name="kelimeki-build" content="${BUILD_ID}" />\n  </head>`,
        ),
    },
    VitePWA({
      registerType: 'prompt',
      injectRegister: false,
      includeAssets: [
        'favicon.svg',
        'favicon.ico',
        'apple-touch-icon.png',
        'fonts/space-mono-400-normal-latin.woff2',
        'fonts/space-mono-400-normal-latin-ext.woff2',
        'fonts/space-mono-700-normal-latin.woff2',
        'fonts/space-mono-700-normal-latin-ext.woff2',
        'fonts/space-grotesk-700-normal-latin.woff2',
        'fonts/space-grotesk-700-normal-latin-ext.woff2',
      ],
      manifest: {
        id: '/',
        lang: 'tr',
        name: 'Kelimeki — Ücretsiz Online Türkçe Kelime Oyunu',
        short_name: 'Kelimeki',
        description: 'Kelimeki, TDK sözlüğüne dayalı ücretsiz online Türkçe stratejik kelime oyunu. 2 ya da 4 kişi, yapay zekaya ve arkadaşlarına karşı köşelerden başlayan özgün bir mekanikle oynanır.',
        theme_color: '#0F1C26',
        background_color: '#0F1C26',
        display: 'standalone',
        orientation: 'portrait',
        scope: '/',
        start_url: '/',
        icons: [
          {
            src: 'icon-192.png',
            sizes: '192x192',
            type: 'image/png',
          },
          {
            src: 'icon-512.png',
            sizes: '512x512',
            type: 'image/png',
          },
          {
            src: 'icon-512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
        ],
      },
    }),
  ],
});
