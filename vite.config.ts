import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'prompt',
      injectRegister: false,
      includeAssets: [
        'favicon.svg',
        'favicon.ico',
        'apple-touch-icon.png',
        'fonts/space-mono-400-normal-latin.woff2',
        'fonts/space-mono-400-normal-latin-ext.woff2',
        'fonts/space-grotesk-700-normal-latin.woff2',
        'fonts/space-grotesk-700-normal-latin-ext.woff2',
      ],
      manifest: {
        id: '/',
        lang: 'tr',
        name: 'Kelimeki — Ücretsiz Online Türkçe Kelime Oyunu',
        short_name: 'Kelimeki',
        description: 'Kelimeki, TDK sözlüğüne dayalı ücretsiz online Türkçe kelime oyunu. 2 ya da 4 kişilik, köşelerden başlayan stratejik Scrabble benzeri oyun.',
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
