import { test, expect, type Page } from '@playwright/test';

// Kelimeki — kritik yol duman testleri. Amaç kapsamlı bir test paketi değil,
// "uygulama açılıyor, bir oyun başlatılabiliyor, YZ hamle yapabiliyor"
// düzeyinde bir güven: launch öncesi/deploy sonrası hızlı bir sağlık kontrolü.

// 18 Ağustos 2026 — karşılama katmanı eklendikten sonra `/` artık TEMİZ bir
// tarayıcıda uygulamayı DEĞİL katmanı gösteriyor (bkz. scripts/landing-plugin.js
// içindeki kapı script'i). Uygulamayı test eden aşağıdaki senaryolar bu yüzden
// kendilerini "dönen kullanıcı" olarak işaretliyor — kapının okuduğu anahtarın
// AYNISI (`src/utils/onboarding.ts` → SEEN_INTRO_KEY).
const SEEN_INTRO_KEY = 'kelimeki:seen-intro';

async function donenKullanici(page: Page): Promise<void> {
  await page.addInitScript((key) => {
    try {
      localStorage.setItem(key as string, '1');
    } catch {
      // depolama kapalıysa kapı zaten katmanı gösterir; test o durumu ölçmüyor
    }
  }, SEEN_INTRO_KEY);
}

test('Setup ekranı açılır, 2 kişilik oyun başlar, YZ hamle yapar', async ({ page }) => {
  // Pas geçme onayı artık native window.confirm() DEĞİL, uygulama içi bir
  // modal (`aria-label="Pas geçme onayı"`, App.tsx `showPassConfirm`) — bu
  // dinleyici yalnızca beklenmedik bir native dialog testi kilitlemesin diye
  // güvenlik ağı olarak duruyor.
  page.on('dialog', (dialog) => dialog.accept());

  await donenKullanici(page);
  await page.goto('/');
  await expect(page).toHaveTitle(/Kelimeki/);

  await page.getByText('OYUNU BAŞLAT').click();

  // Misafir girişi onay modalı — her zaman çıkmayabilir. Butonun metni
  // 18 Ağustos 2026'da "Devam"dan "Oyna"ya çevrildi (kullanıcı: "Devam"
  // üyeliğe götürecekmiş gibi okunuyordu); oyun ekranındaki OYNA da aynı
  // erişilebilir adı taşıdığından locator modalın kendi `aria-label`ıyla
  // DARALTILMAK ZORUNDA — aksi halde ikisi bir arada olmasa bile niyet
  // belirsiz kalır ve ileride biri strict-mode ihlaline dönüşür.
  const devamButton = page
    .getByLabel('Giriş uyarısı')
    .getByRole('button', { name: 'Oyna', exact: true });
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

  await donenKullanici(page);
  await page.goto('/');
  await page.getByText('OYUNU BAŞLAT').click();
  const devamButton = page
    .getByLabel('Giriş uyarısı')
    .getByRole('button', { name: 'Oyna', exact: true });
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

// Ağ DEĞİŞİMİ (WiFi ↔ hücresel) yanlış alarm üretmemeli — 21 Ağustos 2026.
//
// O geçişte hiçbir arayüzün ayakta olmadığı birkaç yüz milisaniyelik bir
// pencere var ve `navigator.onLine` orada gerçekten `false` oluyor: yalan
// değil, ama ANLIK. Debounce olmadan ekran "Çevrimdışı"ya atlayıp geri
// dönüyordu; kullanıcı internetinin çalıştığını bildiğinden bu yanlış alarm
// olarak okunur (kullanıcının kendi itirazı: "başka yerlere girince bunun
// doğru olmadığını görecekler"). Asimetri bilinçli: `false` doğrulanır,
// `true` ANINDA uygulanır.
test('Kısa bağlantı kesintisi (ağ değişimi) çevrimdışı uyarısı ÜRETMEZ', async ({ page }) => {
  page.on('dialog', (dialog) => dialog.accept());

  await page.addInitScript(() => {
    (window as unknown as { __online: boolean }).__online = true;
    Object.defineProperty(Navigator.prototype, 'onLine', {
      get: () => (window as unknown as { __online: boolean }).__online,
      configurable: true,
    });
  });

  await donenKullanici(page);
  await page.goto('/');
  await page.getByText('OYUNU BAŞLAT').click();
  const devamButton = page
    .getByLabel('Giriş uyarısı')
    .getByRole('button', { name: 'Oyna', exact: true });
  if (await devamButton.isVisible().catch(() => false)) await devamButton.click();
  const quickstartHeading = page.getByRole('heading', { name: /hızlı başlangıç/i });
  if (await quickstartHeading.isVisible().catch(() => false)) {
    await page.locator('button[aria-label="Kapat"]').last().click();
  }
  await expect(page.getByRole('button', { name: 'Oyna', exact: true })).toBeVisible();

  const offlineLabel = page.getByText('Çevrimdışı', { exact: true });
  await expect(offlineLabel).toHaveCount(0);

  // Ağ geçişi: bağlantı kısa süre gider (olay da ateşlenir) ve hemen döner.
  await page.evaluate(() => {
    (window as unknown as { __online: boolean }).__online = false;
    window.dispatchEvent(new Event('offline'));
  });
  await page.waitForTimeout(800); // doğrulama penceresinin (1500ms) İÇİ
  await expect(offlineLabel).toHaveCount(0);

  await page.evaluate(() => {
    (window as unknown as { __online: boolean }).__online = true;
    window.dispatchEvent(new Event('online'));
  });
  // Pencere dolduğunda `navigator.onLine` yine true; uyarı HİÇ çıkmamalı.
  await page.waitForTimeout(1200);
  await expect(offlineLabel).toHaveCount(0);

  // Ama GERÇEK bir kesinti hâlâ bildirilmeli — debounce, susturma değil.
  await page.evaluate(() => {
    (window as unknown as { __online: boolean }).__online = false;
    window.dispatchEvent(new Event('offline'));
  });
  await expect(offlineLabel).toBeVisible();
});

// ─────────────────────────────────────────────────────────────────────────────
// Karşılama katmanı (18 Ağustos 2026) — Bölüm 2'nin ASIL işi bu regresyon
// paketi: katmanın kendisi bir yer tutucu, ama önüne geçtiği yollar (dolaşımda
// olan `/game/:id` ve `/davet/:token` linkleri, kurulu PWA, yarım kalmış yerel
// oyunu olan kullanıcı) kırılırsa bunu HİÇBİR mevcut test yakalamıyordu.
// Kapı script'i: scripts/landing-plugin.js.
// ─────────────────────────────────────────────────────────────────────────────

test('Temiz localStorage ile / → karşılama katmanı görünür, uygulama yüklenmez', async ({
  page,
}) => {
  await page.goto('/');

  await expect(page.locator('#karsilama')).toBeVisible();
  await expect(page.locator('#karsilama-giris')).toBeVisible();
  // Şeritte OYNA YOK — sayfanın tepesindeki büyük "HEMEN OYNA" dururken
  // başlıkta ikinci bir kopya gereksizdi (18 Ağustos 2026, kullanıcı isteği).
  await expect(page.locator('#karsilama-oyna')).toHaveCount(0);

  // `#root` hem gizli hem BOŞ olmalı: gizli olması kapının CSS'ini, boş
  // olması React ağacının hiç mount edilmediğini (yani uygulama paketinin
  // indirilmediğini) kanıtlıyor — ikisi ayrı iddia.
  await expect(page.locator('#root')).toBeHidden();
  expect(await page.locator('#root').innerHTML()).toBe('');
  await expect(page.getByText('OYUNU BAŞLAT')).toHaveCount(0);
});

test('OYNA → Setup açılır, seen-intro yazılır, sayfa YENİDEN YÜKLENMEZ', async ({ page }) => {
  await page.goto('/');

  // Sayfa yeniden yüklenirse bu değişken kaybolur — geçişin `location.href`
  // ile değil dinamik import ile yapıldığının kanıtı.
  await page.evaluate(() => {
    (window as unknown as { __gecisSondasi?: boolean }).__gecisSondasi = true;
  });

  await page.locator('[data-kelimeki-oyna]').first().click();

  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();
  await expect(page.locator('#karsilama')).toHaveCount(0);
  expect(await page.evaluate((k) => localStorage.getItem(k as string), SEEN_INTRO_KEY)).toBe('1');
  expect(
    await page.evaluate(() => (window as unknown as { __gecisSondasi?: boolean }).__gecisSondasi),
  ).toBe(true);
});

test('GİRİŞ → giriş penceresi açılır, URL\'de ?giris=1 KALMAZ', async ({ page }) => {
  await page.goto('/');
  await page.locator('#karsilama-giris').click();

  const dialog = page.getByRole('dialog');
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('heading', { name: 'Giriş', exact: true })).toBeVisible();

  // App.tsx parametreyi `history.replaceState` ile temizliyor (`?contact=1`
  // ile aynı kalıp) — yenilemede pencere tekrar açılmasın diye.
  await expect.poll(() => new URL(page.url()).search).toBe('');
});

test('İkinci ziyaret (aynı localStorage) → katman HİÇ görünmez', async ({ page }) => {
  await page.goto('/');
  await page.locator('[data-kelimeki-oyna]').first().click();
  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();

  await page.goto('/');

  await expect(page.locator('#karsilama')).toHaveCount(0);
  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();
});

// Kayıtlı bir kullanıcı Supabase oturumunu `localStorage`'da taşır
// (`sb-<proje-ref>-auth-token`) ve tarayıcı onu otomatik geri yükler — yani
// "otomatik giriş yapan" kullanıcı katmanı HİÇ görmemeli, deneyimi
// bugünküyle birebir aynı kalmalı (kullanıcı sorusu, 18 Ağustos 2026).
// Kapı proje ref'ini sabit yazmıyor, `sb-` öneki + `-auth-token` sonekiyle
// tarıyor; test ikisini de kapsıyor ki ref değişse bile kural bozulmasın.
test('Supabase oturumu olan (otomatik giriş) kullanıcı katmanı görmez', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => {
    localStorage.setItem(
      'sb-xvqlizifakkkoqahaxsg-auth-token',
      JSON.stringify({ access_token: 'sahte' }),
    );
  });

  await page.goto('/');

  await expect(page.locator('#karsilama')).toHaveCount(0);
  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();
});

test('/game/:id paylaşılan oyun sayfası açılır, katman görünmez', async ({ page }) => {
  await page.goto('/game/00000000-0000-0000-0000-000000000000');

  await expect(page.locator('#karsilama')).toHaveCount(0);
  await expect(page.getByLabel('Kelimeki anasayfa')).toBeVisible();
  // Supabase bu test ortamında yapılandırılmadığından sayfa "bulunamadı"
  // dalına düşüyor — önemli olan SharedGamePage'in render OLMASI.
  await expect(page.getByText(/Bu oyun bulunamadı|Yükleniyor/)).toBeVisible();
  await expect(page.getByText('OYUNU BAŞLAT')).toHaveCount(0);
});

test('/davet/:token arkadaşlık davet sayfası açılır, katman görünmez', async ({ page }) => {
  await page.goto('/davet/abcdef1234567890');

  await expect(page.locator('#karsilama')).toHaveCount(0);
  await expect(page.getByLabel('Kelimeki anasayfa')).toBeVisible();
  await expect(page.getByText(/Bu davet linki geçersiz|Yükleniyor/)).toBeVisible();
  await expect(page.getByText('OYUNU BAŞLAT')).toHaveCount(0);
});

/**
 * ROADMAP #7 (21 Ağustos 2026). Davet linki artık `?ref=arkadas` taşıyor —
 * ama asıl hata etiketin KONMAMASI değil, YAKALANMAMASIYDI: `captureUtmSource`
 * `App.tsx`'in bir effect'indeydi ve bu route `App`'i hiç mount etmiyor
 * (`FriendInvitePage` render ediliyor). Ölçüldü: düzeltmeden önce
 * `/davet/:token?ref=arkadas` ve `/game/:id?ref=tiktok` etiketi `null`
 * bırakıyordu, yani dolaşımdaki her davet/paylaşım linki kaynağını sessizce
 * kaybediyordu. Çağrı `boot.tsx`e, route AYRIMINDAN ÖNCEYE taşındı.
 */
test('/davet/:token ve /game/:id `?ref=` etiketini YAKALAR (first-touch)', async ({ page }) => {
  await page.goto('/davet/abcdef1234567890?ref=arkadas');
  await expect(page.getByLabel('Kelimeki anasayfa')).toBeVisible();
  expect(await page.evaluate(() => localStorage.getItem('kelimeki:utm-source'))).toBe('arkadas');

  // Aynı bağlamda ikinci bir kaynakla gelmek ilk teması EZMEZ.
  await page.goto('/game/3f2504e0-4f89-11d3-9a0c-0305e82c3301?ref=tiktok');
  expect(await page.evaluate(() => localStorage.getItem('kelimeki:utm-source'))).toBe('arkadas');
});

test('/game/:id `?ref=` etiketini yakalar (temiz cihaz)', async ({ page }) => {
  await page.goto('/game/3f2504e0-4f89-11d3-9a0c-0305e82c3301?ref=tiktok');
  // `boot.tsx` DİNAMİK import ediliyor (bkz. main.tsx) — `goto` dönerken
  // henüz çalışmamış olabilir, o yüzden sayfanın gerçekten mount olmasını
  // bekle. Beklemeden okumak testi ürüne değil zamanlamaya bağlar.
  await expect(page.getByText(/Bu oyun bulunamadı|Yükleniyor/)).toBeVisible();
  expect(await page.evaluate(() => localStorage.getItem('kelimeki:utm-source'))).toBe('tiktok');
});

test('Yarım kalmış yerel oyun (kelimeki:game-state) varsa katman görünmez', async ({ page }) => {
  await page.addInitScript(() => {
    try {
      // İçeriğin geçerli bir GameState olması gerekmiyor: kapı yalnızca
      // anahtarın VARLIĞINA bakıyor (bozuk kaydı `loadGameState` zaten eliyor).
      localStorage.setItem('kelimeki:game-state', '{"version":1}');
    } catch {
      // yoksay
    }
  });

  await page.goto('/');

  await expect(page.locator('#karsilama')).toHaveCount(0);
  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();
});

// ── Bölüm 3: içerik + logo park efekti ────────────────────────────────────
// Yukarıdaki testler BORUYU (kapı → geçiş → yönlendirme) kanıtlıyor; bu ikisi
// Bölüm 3'te eklenen İÇERİĞİN ve efektin gerçekten çalıştığını kanıtlıyor.

test('Sayfa sonundaki OYNA da uygulamaya geçirir (öznitelikle bağlama)', async ({ page }) => {
  await page.goto('/');

  // Kahraman ve sayfa sonundaki düğmelerin id'si YOK — `main.tsx` onları
  // `[data-kelimeki-oyna]` ile topluca bağlıyor. Bu test o sözleşmeyi
  // koruyor: yeni bir düğme id ile eklenirse (öznitelik unutulursa) sessizce
  // ölü kalırdı.
  const oynaDugmeleri = page.locator('[data-kelimeki-oyna]');
  await expect(oynaDugmeleri).toHaveCount(2); // kahraman + sayfa sonu
  await oynaDugmeleri.last().click();

  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();
  await expect(page.locator('#karsilama')).toHaveCount(0);
});

test('Kaydırınca logo kilitli başlığa park eder, tepede park etmez', async ({ page }) => {
  await page.goto('/');

  const katman = page.locator('#karsilama');
  const parkYuvasi = page.locator('#karsilama-logo-yuvasi svg');

  // Tepedeyken kahraman logo görünür — park eden kopya gizli.
  await expect(katman).not.toHaveClass(/logo-parkli/);
  await expect(parkYuvasi).toHaveCSS('opacity', '0');

  // Gerçek kaydırma kabı `#karsilama` (belge değil — bkz. index.css).
  await page.evaluate(() => {
    document.getElementById('karsilama')!.scrollTop = 900;
  });

  await expect(katman).toHaveClass(/logo-parkli/);
  await expect(parkYuvasi).toHaveCSS('opacity', '1');

  // Geri dönünce efekt geri alınır (tek yönlü bir bayrak değil).
  await page.evaluate(() => {
    document.getElementById('karsilama')!.scrollTop = 0;
  });
  await expect(katman).not.toHaveClass(/logo-parkli/);
});

test('Ev düğmesi karşılama katmanına geri döndürür (?tanitim=1)', async ({ page }) => {
  await page.goto('/');
  await page.locator('[data-kelimeki-oyna]').first().click();
  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();

  // Katman DOM'dan siliniyor, yani geri dönüş tam bir yeniden yükleme —
  // `?tanitim=1` kapıya "bu sefer katmanı göster" diyen TEK sinyal, çünkü
  // `seen-intro` bu noktada yazılmış durumda.
  await page.getByLabel('Tanıtım sayfası').click();
  await expect(page.locator('#karsilama')).toBeVisible();
  expect(await page.evaluate((k) => localStorage.getItem(k as string), SEEN_INTRO_KEY)).toBe('1');

  // ⚠ Bu bekleme ŞART (18 Ağustos 2026'da gerçek bir flake olarak görüldü):
  // yukarıdaki "Tanıtım sayfası" tıklaması TAM BİR YENİDEN YÜKLEME başlatıyor
  // ve OYNA düğmesi katmanın PRERENDER EDİLMİŞ statik HTML'inde zaten var —
  // yani Playwright'ın görünürlük/tıklanabilirlik kontrolleri, `main.tsx`
  // henüz çalışıp `[data-kelimeki-oyna]`ya dinleyiciyi BAĞLAMADAN önce
  // geçiyor. O anda atılan tık sessizce hiçbir şey yapmıyor ve test bir
  // sonraki satırda düşüyor. `load`, modül script'i ve bağımlılıkları
  // çalıştıktan sonra tetiklendiğinden dinleyicinin varlığını garanti eder.
  await page.waitForLoadState('load');

  // Geçişte URL temizleniyor — yenilemede kullanıcı katmana geri düşmemeli.
  await page.locator('[data-kelimeki-oyna]').first().click();
  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();
  await expect.poll(() => new URL(page.url()).search).toBe('');
});

test('Katmanın hukuki bağlantıları uygulamada ilgili pencereyi açar', async ({ page }) => {
  await page.goto('/');
  await page.locator('[data-kelimeki-gizlilik]').click();

  const dialog = page.getByRole('dialog');
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('heading', { name: /Gizlilik/ })).toBeVisible();
  await expect.poll(() => new URL(page.url()).search).toBe('');
});

test('Tanıtım tahtası şeridi iki görsel ve iki nokta taşır', async ({ page }) => {
  await page.goto('/');

  const serit = page.locator('#karsilama-tahta-serit');
  await expect(serit.locator('> div')).toHaveCount(2);
  await expect(page.locator('#karsilama-tahta-noktalar > span')).toHaveCount(2);

  // Kaydırma CSS ile; JS yalnızca noktayı güncelliyor.
  await serit.evaluate((el) => {
    el.scrollLeft = el.clientWidth + 16;
  });
  await expect(page.locator('#karsilama-tahta-noktalar > span').nth(1)).toHaveClass(/bg-accent/);
  await expect(page.locator('#karsilama-tahta-noktalar > span').first()).toHaveClass(/bg-border/);
});

test('FAQPage JSON-LD, ekrandaki yedi soruyla birebir eşleşir', async ({ page }) => {
  await page.goto('/');

  // Metinler `SSS` dizisinden (src/landing/Landing.tsx) TEK KAYNAKTAN
  // üretiliyor (bkz. render.tsx → renderFaqJsonLd) — bu test o senkronun
  // gerçekten tuttuğunu, sayfanın kendi HTML'inden okuyarak kanıtlıyor.
  const faq = await page.evaluate(() => {
    const scripts = Array.from(document.querySelectorAll('script[type="application/ld+json"]'));
    for (const s of scripts) {
      const data = JSON.parse(s.textContent ?? '{}');
      if (data['@type'] === 'FAQPage') return data;
    }
    return null;
  });
  expect(faq).not.toBeNull();
  const jsonSorular = faq.mainEntity.map((q: { name: string }) => q.name);

  const ekranSorular = await page.locator('#karsilama summary').allTextContents();

  expect(jsonSorular).toEqual(ekranSorular);
  expect(jsonSorular.length).toBe(7);
});

test('Sayfada tek bir h1 var, tahta demoları role="img" taşıyor', async ({ page }) => {
  await page.goto('/');

  await expect(page.locator('h1')).toHaveCount(1);
  await expect(page.locator('[role="img"][aria-label*="oyun tahtası"]')).toHaveCount(2);
});

// Kullanıcı isteği (21 Ağustos 2026): *"Bazı kullanıcılar oyundan setup'a
// dönüşü bulamıyor."* Logo BAŞTAN BERİ Setup'a dönüyordu — eksik olan
// davranış değil GÖRÜNÜRLÜKTÜ. Bu test ikisini birden koruyor: etiket
// GÖRÜNÜR ve etikete dokunmak GERÇEKTEN Setup'a döndürür.
//
// Negatif eş: `GameHeader`taki `<span>` kaldırılırsa ilk expect, etiket
// logo butonunun DIŞINA taşınırsa ikinci expect düşer.
test('Oyun ekranında logonun altında "← Geri" var ve Setup\'a döndürür', async ({ page }) => {
  page.on('dialog', (dialog) => dialog.accept());
  await donenKullanici(page);
  await page.goto('/');
  await page.getByText('OYUNU BAŞLAT').click();

  const devamButton = page
    .getByLabel('Giriş uyarısı')
    .getByRole('button', { name: 'Oyna', exact: true });
  if (await devamButton.isVisible().catch(() => false)) {
    await devamButton.click();
  }
  const quickstartHeading = page.getByRole('heading', { name: /hızlı başlangıç/i });
  if (await quickstartHeading.isVisible().catch(() => false)) {
    await page.locator('button[aria-label="Kapat"]').last().click();
  }

  // Oyun ekranındayız: tahta çizildi.
  await expect(page.getByRole('button', { name: 'Oyna', exact: true })).toBeVisible();

  const geri = page.locator('header').getByText('← Geri');
  await expect(geri).toBeVisible();

  // Etiket logoyla AYNI butonun içinde olmalı — dokunma alanı ikisini
  // birden kapsıyor (kullanıcı: "Logo alanı da dahil basıldığında").
  await expect(
    page.locator('header button[aria-label="Oyundan çık"]').getByText('← Geri'),
  ).toBeVisible();

  await geri.click();
  // ⚠ DOM metni "Oyun Tipi" — ekranda büyük harf görünmesi CSS
  // `uppercase`inden geliyor ve `getByText` onu görmez (bu kod tabanında
  // kayıtlı tuzak, "Oyna"/"Nasıl Oynanır?" vakasının kardeşi).
  await expect(page.getByText('Oyun Tipi')).toBeVisible();
});

// ── Hukuki statik sayfalar (23 Ağustos 2026) ────────────────────────────────
// Play'in Data safety formu doğrudan açılan bir gizlilik politikası URL'i
// istiyor ve o form kapalı test kanalı için de zorunlu. Sayfalar SPA DEĞİL,
// derleme zamanında üretilen statik HTML (scripts/legal-plugin.js) — bu
// testler tam olarak o ayrımı koruyor: `#root` YOKSA sayfa gerçekten
// statiktir, VARSA uygulama kabuğuna düşmüşüz demektir.
const HUKUKI_SAYFALAR = [
  { yol: '/gizlilik/', baslik: 'Gizlilik Politikası' },
  { yol: '/kullanim-kosullari/', baslik: 'Kullanım Koşulları' },
  { yol: '/hesap-silme/', baslik: 'Hesap ve Veri Silme' },
];

for (const { yol, baslik } of HUKUKI_SAYFALAR) {
  test(`${yol} statik sayfa olarak açılır (SPA kabuğu değil)`, async ({ page }) => {
    await page.goto(yol);
    await expect(page.getByRole('heading', { level: 1, name: baslik })).toBeVisible();
    // Uygulama HİÇ yüklenmemeli — bu sayfalar JS'siz okunabilmeli.
    await expect(page.locator('#root')).toHaveCount(0);
    await expect(page.locator('#karsilama')).toHaveCount(0);
    // Ana sayfaya ve diğer iki hukuki sayfaya dönüş yolu var.
    for (const oteki of HUKUKI_SAYFALAR.filter((s) => s.yol !== yol)) {
      await expect(page.locator(`footer a[href="${oteki.yol}"]`)).toBeVisible();
    }
    await expect(page.locator('footer a[href="/"]')).toBeVisible();
  });
}

test('hukuki metin TEK KAYNAKTAN geliyor — sayfa ile pencere aynı bölümleri taşıyor', async ({
  page,
}) => {
  // `src/legal/LegalContent.tsx` hem `PrivacyModal`'ı hem `/gizlilik/`
  // sayfasını besliyor. Metin ikiye kopyalanırsa bu test düşer.
  await page.goto('/gizlilik/');
  const sayfaBolumleri = await page.locator('main h3').allInnerTexts();
  expect(sayfaBolumleri.length).toBeGreaterThan(5);

  await donenKullanici(page);
  await page.goto('/?gizlilik=1');
  const pencere = page.getByRole('dialog');
  await expect(pencere.getByRole('heading', { name: 'Gizlilik Politikası' })).toBeVisible();
  const pencereBolumleri = await pencere.locator('h3').allInnerTexts();
  expect(pencereBolumleri).toEqual(sayfaBolumleri);
});

test('/hesap-silme/ Play için gereken silme talebi yolunu anlatıyor', async ({ page }) => {
  await page.goto('/hesap-silme/');
  // Talebin iletileceği kanal çalışır durumda olmalı — Play "geçersiz silme
  // bağlantısı" gerekçesiyle reddedebiliyor.
  await expect(page.locator('main a[href="/?contact=1"]')).toBeVisible();
  // Süre TEK KAYNAKTAN (`SILME_SURESI_GUN`) geliyor; gizlilik politikasıyla
  // aynı sayıyı göstermek zorunda. Politikada İKİ yerde geçiyor (5. ve 8.
  // bölüm) — bu test yazılırken 8. bölümdekinin hâlâ elle yazılmış olduğu
  // ortaya çıktı ve o da sabite bağlandı.
  await expect(page.getByText(/en geç 30 gün/).first()).toBeVisible();
  await page.goto('/gizlilik/');
  const politikadaki = page.getByText(/en geç 30 gün/);
  await expect(politikadaki.first()).toBeVisible();
  expect(await politikadaki.count()).toBe(2);
});
