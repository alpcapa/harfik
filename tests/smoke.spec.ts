import { test, expect } from '@playwright/test';

// Kelimeki — kritik yol duman testleri. Amaç kapsamlı bir test paketi değil,
// "uygulama açılıyor, bir oyun başlatılabiliyor, YZ hamle yapabiliyor"
// düzeyinde bir güven: launch öncesi/deploy sonrası hızlı bir sağlık kontrolü.

test('Setup ekranı açılır, 2 kişilik oyun başlar, YZ hamle yapar', async ({ page }) => {
  // Pas geçme onayı artık native window.confirm() DEĞİL, uygulama içi bir
  // modal (`aria-label="Pas geçme onayı"`, App.tsx `showPassConfirm`) — bu
  // dinleyici yalnızca beklenmedik bir native dialog testi kilitlemesin diye
  // güvenlik ağı olarak duruyor.
  page.on('dialog', (dialog) => dialog.accept());

  await page.goto('/');
  await expect(page).toHaveTitle(/Kelimeki/);

  await page.getByText('OYUNU BAŞLAT').click();

  // Misafir girişi onay modalı — her zaman çıkmayabilir.
  const devamButton = page.getByRole('button', { name: 'Devam', exact: true });
  if (await devamButton.isVisible().catch(() => false)) {
    await devamButton.click();
  }

  // İlk ziyarette otomatik açılan "Hızlı Başlangıç" modalı. Sayfada
  // aria-label="Kapat" başka bir yerde de var (AddToHomeScreen banner'ı),
  // o yüzden yalnızca bu modal gerçekten açıksa ve onun içindeki kapat
  // butonunu (son eklenen portal — .last()) hedefleyerek kapatıyoruz.
  const quickstartHeading = page.getByRole('heading', { name: /hızlı başlangıç/i });
  if (await quickstartHeading.isVisible().catch(() => false)) {
    await page.locator('button[aria-label="Kapat"]').last().click();
  }

  // `exact: true` ŞART: Playwright'ın `name` eşleşmesi varsayılan olarak
  // büyük/küçük harf duyarsız ALT DİZE arıyor, ve 14 Ağustos 2026'dan beri
  // tahtanın alt şeridinde "Nasıl Oynanır?" var — "oyna" onun da içinde
  // geçtiğinden locator iki öğeye çözülüp strict mode ihlali veriyordu.
  // Görünen metin `uppercase` CSS'iyle büyük harf; erişilebilir ad ise DOM
  // metni, yani "Oyna". `exact: true` aynı zamanda büyük/küçük harfe DUYARLI
  // olduğundan tam metin yazılmak zorunda.
  const oynaButton = page.getByRole('button', { name: 'Oyna', exact: true });
  await expect(oynaButton).toBeVisible();

  // Onay modalı açılınca sayfada AYNI isimde ikinci bir "Pas Geç" butonu
  // (modalın kendi onay butonu) oluşuyor — bu yüzden oyun ekranındaki buton
  // `main` landmark'ıyla, modaldeki ise kendi aria-label'ıyla hedefleniyor.
  const pasGecButton = page.getByRole('main').getByRole('button', { name: 'Pas Geç' });
  await expect(pasGecButton).toBeEnabled();
  await pasGecButton.click();
  await page.getByLabel('Pas geçme onayı').getByRole('button', { name: 'Pas Geç' }).click();

  // Sıra YZ'ye geçince kontroller devre dışı kalır (App.tsx `canAct`).
  await expect(pasGecButton).toBeDisabled();

  // YZ hamlesini tamamlayıp sırayı geri verince kontroller tekrar aktif olur.
  await expect(pasGecButton).toBeEnabled({ timeout: 20_000 });

  // Bu noktaya ulaşmak, reducer/YZ/skor/bölge hesaplama zincirinin ucuna
  // kadar hatasız çalıştığı anlamına gelir — ErrorBoundary devreye girmedi.
  await expect(page.getByText('Bir şeyler ters gitti')).toHaveCount(0);
});

test('Bilinmeyen bir path da uygulamayı normal açar (SPA fallback)', async ({ page }) => {
  await page.goto('/bu-path-hic-yok');
  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();
});

// 14 Ağustos 2026 — kullanıcı cihazda (ana ekrana eklenmiş PWA, iPad)
// tahtanın altındaki kırmızı "Çevrimdışı" uyarısını göremediğini İKİ KEZ
// bildirdi. Kök sebep rozette değil `useOnlineStatus`'taydı: yalnızca
// `online`/`offline` OLAYLARINI dinliyordu, ve uçak modunu açmak için
// Kontrol Merkezi'ne çıkıldığında sayfa askıya alındığından olay JS'e hiç
// ulaşmıyor, durum sonsuza dek bayat `true` kalıyordu. Bu test tam o
// senaryoyu üretir: navigator.onLine'ı OLAY ATEŞLEMEDEN false yapar, sonra
// kullanıcının uygulamaya dönüşünü (visibilitychange) taklit eder.
test('Öne dönüşte bağlantı durumu yeniden okunur (kaçırılan offline olayı)', async ({
  page,
}) => {
  page.on('dialog', (dialog) => dialog.accept());

  await page.addInitScript(() => {
    (window as unknown as { __online: boolean }).__online = true;
    Object.defineProperty(Navigator.prototype, 'onLine', {
      get: () => (window as unknown as { __online: boolean }).__online,
      configurable: true,
    });
  });

  await page.goto('/');
  await page.getByText('OYUNU BAŞLAT').click();
  const devamButton = page.getByRole('button', { name: 'Devam', exact: true });
  if (await devamButton.isVisible().catch(() => false)) await devamButton.click();
  const quickstartHeading = page.getByRole('heading', { name: /hızlı başlangıç/i });
  if (await quickstartHeading.isVisible().catch(() => false)) {
    await page.locator('button[aria-label="Kapat"]').last().click();
  }
  await expect(page.getByRole('button', { name: 'Oyna', exact: true })).toBeVisible();

  const offlineLabel = page.getByText('Çevrimdışı', { exact: true });
  await expect(offlineLabel).toHaveCount(0);

  // Bağlantı gitti ama olay KAÇIRILDI (sayfa askıdaydı).
  await page.evaluate(() => {
    (window as unknown as { __online: boolean }).__online = false;
  });
  await expect(offlineLabel).toHaveCount(0);

  // Kullanıcı uygulamaya döner → durum yeniden okunmalı.
  await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
  await expect(offlineLabel).toBeVisible();
});
