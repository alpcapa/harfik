import { defineConfig, devices } from '@playwright/test';

// Kelimeki — smoke test config. Dev sunucusunu otomatik başlatır (webServer),
// zaten çalışıyorsa (reuseExistingServer) yeniden başlatmaz.
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:5173',
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
