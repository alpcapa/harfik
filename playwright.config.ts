import { defineConfig, devices } from '@playwright/test';

// Kelimeki — smoke test config. Dev sunucusunu otomatik başlatır (webServer),
// zaten çalışıyorsa (reuseExistingServer) yeniden başlatmaz.
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  reporter: 'list',
  // 25 Ağustos 2026 — varsayılan 5 sn'lik bütçe ARTIK YETMİYOR. Karşılama
  // katmanından uygulamaya geçiş İKİ ardışık dinamik import zinciri:
  // `main.tsx` (kapı) → `boot.tsx` → `App.tsx`. İkincisi PR #331'de bilerek
  // eklendi (`/davet` 2026 → 820 KB); bedeli geçişin uzaması. Dev sunucusu
  // her halkayı istek anında derlediğinden ölçüm burada 2,9-5,8 sn çıkıyor
  // — yani 5 sn sınırın TAM üstünde; CI runner'ında "Sayfa sonundaki OYNA"
  // testi bu yüzden düştü (koşu 32882151540).
  // Bu bir "eşiği düşürme" DEĞİL: iddiaların hiçbiri gevşemedi, yalnızca
  // bekleme bütçesi yeni mimariye göre ayarlandı. Zincir kısalırsa
  // (ör. modulepreload) bu sayı da geri çekilebilir.
  expect: { timeout: 15_000 },
  use: {
    baseURL: 'http://localhost:5173',
    actionTimeout: 15_000,
    trace: 'on-first-retry',
    launchOptions: {
      // Bu geliştirme ortamında tarayıcı önceden buraya kurulu —
      // `playwright install` çalıştırmaya gerek yok. GitHub Actions
      // runner'ında bu yol YOK; CI orada `npx playwright install
      // --with-deps chromium` ile kendi tarayıcısını kurup Playwright'ın
      // varsayılan (bundled) yolunu kullanıyor — bu yüzden `CI` ortam
      // değişkeni set'liyken `executablePath` hiç verilmiyor.
      executablePath: process.env.CI ? undefined : '/opt/pw-browsers/chromium',
    },
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
