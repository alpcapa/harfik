import { test, expect, type Locator, type Page } from '@playwright/test';
import { readFileSync } from 'node:fs';

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

  // 25 Ağustos 2026 — sayfa artık davet cümlesinin yanında oyunu ANLATIYOR
  // (tanıtım tahtası + özellikler). Bu blok token'ın geçerliliğinden BAĞIMSIZ,
  // yalnızca "girişsiz ziyaretçi" koşuluna bağlı: geçersiz linkle gelen kişi
  // de eskiden tek satırlık bir çıkmaza düşüyordu. Tahta karşılama katmanıyla
  // AYNI kaynaktan (`landing/demoBoard.ts`) geliyor — import zinciri kopar ya
  // da bölüm sessizce düşerse burada yakalanır.
  await expect(page.getByRole('heading', { name: 'Kelimeki nedir?' })).toBeVisible();
  await expect(page.getByRole('img', { name: /Kelimeki tahtası örneği/ })).toBeVisible();
});

/**
 * 25 Ağustos 2026'da ÖLÇÜLDÜ: `/davet/:token` 2026 KB indiriyordu ve bunun
 * 789 KB'ı ~63 bin kelimelik sözlük, 787 KB'ı da oyunun tamamıydı — davet
 * sayfası ikisini de kullanmıyor. `preloadWordSet()` route kararının ardına
 * alındı, `App` dinamik import'a çevrildi; sonuç 885 KB.
 *
 * Bu test o düzeltmenin NEGATİF EŞİ: biri `preloadWordSet()`i tekrar
 * `mount()`ın başına taşırsa ya da `App`i statik import'a döndürürse burada
 * düşer. İkisi de sessiz regresyonlar — kullanıcı yalnızca "ağır açılıyor"
 * der ve sebebi görünmez.
 */
test('/davet/:token sözlüğü ve oyun paketini İNDİRMEZ', async ({ page }) => {
  const istekler: string[] = [];
  page.on('request', (r) => istekler.push(r.url()));

  await page.goto('/davet/abcdef1234567890');
  await expect(page.getByText(/Bu davet linki geçersiz|Yükleniyor/)).toBeVisible();
  await page.waitForTimeout(1500);

  // Aranan şey SÖZLÜK VERİSİ (`src/data/words.ts`, 880 KB) — birkaç satırlık
  // `wordSetLoader.ts` DEĞİL; o `boot.tsx`te statik import olduğundan her
  // zaman gelir ve zaten maliyeti yok. Dev sunucusunda kaynak yoluyla
  // (`/src/data/words.ts`), üretim derlemesinde hash'li chunk adıyla
  // (`words-*.js`) istenir — ikisi de yakalanmalı.
  expect(istekler.filter((u) => /\/(src\/data\/)?words(\.ts|-[A-Za-z0-9_]+\.js)/.test(u))).toEqual([]);
  expect(istekler.filter((u) => /\/(src\/)?App(\.tsx|-[A-Za-z0-9_]+\.js)/.test(u))).toEqual([]);
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

// 22 Ağustos 2026 — bir kullanıcı (Android) tahtaya koyduğu jokere harfini
// değiştirmek için tekrar dokunduğunda pencerenin açılmadığını, üstelik
// harfin kendiliğinden değiştiğini ("A, C oldu") bildirdi.
//
// Kök sebep ÖLÇÜLDÜ: dokunmatik tarayıcılar pointer olaylarından SONRA
// uyumluluk (compat) mousedown/mouseup/click üretiyor ve bu üçü hit-test'i
// O ANDAKİ DOM üzerinde yapıyor. Pencere `pointerup` içinde açıldığından
// (`endDrag`in joker dalı) compat click artık hücrenin değil YENİ RENDER
// EDİLMİŞ modalın üstüne düşüyor: parmağın konumuna göre ya harf
// ızgarasındaki bir taşa basıp jokeri sessizce başka harfe çeviriyor ya da
// zemine düşüp pencereyi anında kapatıyor.
//
// Bu test dokunmatik bir bağlam ister — `hasTouch` olmadan `tap()` çalışmaz
// ve compat olay zinciri hiç doğmaz, yani hata masaüstü profilinde GÖRÜNMEZ.
test.describe('dokunmatik jestler', () => {
  test.use({ hasTouch: true, isMobile: true, viewport: { width: 390, height: 844 } });

  // Rafında JOKER olan, yarım kalmış bir yerel oyun — üretim reducer'ıyla
  // kuruluyor (elle yazılmış bir fikstür sessizce şemadan kopardı).
  async function jokerliKayit(): Promise<string> {
    const { gameReducer, createInitialState } = await import('../src/game/gameReducer');
    let s = gameReducer(createInitialState(), {
      type: 'START',
      players: [
        { name: 'Misafir', isAI: false },
        { name: 'Yapay Zeka', isAI: true },
      ],
    });
    // Raf SABİTLENİYOR: `startGame` torbadan rastgele çekiyor, yani testin
    // aradığı harf (M) bazı koşularda hiç gelmiyordu — ölçüldü, gerçek bir
    // flake. Puanlar üretim dağılımından (`TILE_DATA`) okunuyor.
    const { TILE_DATA } = await import('../src/data/tiles');
    const rack = ['?', 'M', 'A', 'R', 'T', 'I', 'K'].map((letter) =>
      letter === '?'
        ? { letter: '?', pts: 0, wild: true }
        : { letter, pts: TILE_DATA[letter].pts },
    );
    s = { ...s, current: 0, players: s.players.map((p, i) => (i === 0 ? { ...p, rack } : p)) };
    return JSON.stringify({ version: 1, state: s, savedAt: Date.now() });
  }

  /** Parmak titremesi olan bir dokunuş: bas → `jitter` px kay → aynı yerde bırak.
   *  Playwright'ın `tap()`i hiç hareket üretmediğinden eşik davranışı ancak
   *  ham CDP dokunuş olaylarıyla ölçülebiliyor. */
  async function sloppyTap(page: Page, target: Locator, jitter: number): Promise<void> {
    const box = (await target.boundingBox())!;
    const x = box.x + box.width / 2;
    const y = box.y + box.height / 2;
    const cdp = await page.context().newCDPSession(page);
    const send = (type: string, px: number, py: number) =>
      cdp.send('Input.dispatchTouchEvent', {
        type,
        touchPoints: type === 'touchEnd' ? [] : [{ x: px, y: py }],
      });
    await send('touchStart', x, y);
    if (jitter > 0) {
      await send('touchMove', x + jitter, y);
      await send('touchMove', x, y);
    }
    await send('touchEnd', x, y);
    await cdp.detach();
  }

  /** Jokerli kayıttan devam edip oyun ekranını açar. */
  async function oyunEkrani(page: Page): Promise<void> {
    await donenKullanici(page);
    await page.addInitScript((payload) => {
      localStorage.setItem('kelimeki:game-state', payload as string);
    }, await jokerliKayit());
    await page.goto('/');
    await page.getByRole('button', { name: /Senin Hamlen Bekleniyor/i }).click();
    const quickstartHeading = page.getByRole('heading', { name: /hızlı başlangıç/i });
    if (await quickstartHeading.isVisible().catch(() => false)) {
      await page.locator('button[aria-label="Kapat"]').last().click();
    }
  }

  test('Konmuş jokere dokunmak pencereyi açar, harfi KENDİLİĞİNDEN değiştirmez', async ({
    page,
  }) => {
    // Hücre keyfi seçilmedi: 390×844'te tahtanın bu hücresinin merkezi,
    // açılan pencerenin harf ızgarasındaki bir taşın ÜSTÜNE düşüyor —
    // hatanın en zararlı biçimi (harfin sessizce değişmesi) ancak öyle
    // görünür. Düzen değişip örtüşme kaybolursa aşağıdaki kurulum kontrolü
    // testi SESSİZCE geçirmek yerine düşürür.
    const CELL = '10,5';

    await oyunEkrani(page);

    const cell = page.locator(`[data-cell="${CELL}"]`);
    const harf = async () => (await cell.innerText()).trim().split('\n')[0];

    // Jokeri (rafta ★) seçip hücreye koy — harf seçme penceresi açılır.
    await page.locator('[data-rack]').getByText('★').first().tap();
    await cell.tap();
    await expect(page.getByRole('dialog')).toBeVisible();

    // KURULUM KONTROLÜ: hücrenin merkezi gerçekten harf ızgarasının üstünde mi?
    const ortusuyor = await page.evaluate((c) => {
      const el = document.querySelector(`[data-cell="${c}"]`)!.getBoundingClientRect();
      const x = el.x + el.width / 2;
      const y = el.y + el.height / 2;
      const grid = document.querySelector('[role="dialog"] .grid')!;
      return [...grid.children].some((d) => {
        const b = d.getBoundingClientRect();
        return x >= b.x && x <= b.x + b.width && y >= b.y && y <= b.y + b.height;
      });
    }, CELL);
    expect(
      ortusuyor,
      `Hücre ${CELL} artık harf ızgarasıyla örtüşmüyor — başka bir hücre seç, yoksa test hatayı göremez`,
    ).toBe(true);

    // 27 Ağustos 2026 — dokunma hedefi turunun devamı. Harf hücresi 48×44'tü
    // (yükseklik Material asgarisinin altında) ve satırlar arasında 6 px ölü
    // bant vardı; buradaki ıskalama YANLIŞ HARF seçtirir. Hücre artık 48×50
    // ve satırlar dikeyde aralıksız — taşın çizildiği yer değişmedi (satır
    // adımı hâlâ 50). Portla birebir aynı sayılar (`wild_letter_sheet.dart`).
    const hucreler = page.locator('[role="dialog"] .grid > div');
    const h0 = (await hucreler.nth(0).boundingBox())!;
    const h1 = (await hucreler.nth(1).boundingBox())!;
    const h6 = (await hucreler.nth(6).boundingBox())!;
    expect(h0.height).toBeCloseTo(50, 1);
    // Genişlik zaten yeterliydi ve GÖRÜNÜM GENİŞLİĞİNE bağlı (portta 390'da
    // tam 48, burada ~47.7) — sabit bir sayıya bağlamak kırılgan olurdu.
    // Zayıf eksen dikeydi; iddia orada.
    expect(h0.width).toBeGreaterThan(44);
    // Satırlar arası ölü bant SIFIR; satır adımı hâlâ 50.
    expect(h6.y - (h0.y + h0.height)).toBeCloseTo(0, 1);
    expect(h6.y - h0.y).toBeCloseTo(50, 1);
    // Yatay 6 px BİLEREK duruyor (genişlik zaten 48).
    expect(h1.x - (h0.x + h0.width)).toBeCloseTo(6, 1);
    // Taşın kendisi hâlâ 44 yüksek — büyüyen yalnızca hedef.
    const tas0 = (await hucreler.nth(0).locator('> div').boundingBox())!;
    expect(tas0.height).toBeCloseTo(44, 1);

    await page.getByRole('dialog').getByText('A', { exact: true }).first().click();
    await expect(page.getByRole('dialog')).toBeHidden();
    expect(await harf()).toBe('A');

    // >>> Bildirilen jest: konmuş jokere TEK DOKUNUŞ.
    await cell.tap();
    await expect(page.getByRole('dialog')).toBeVisible();
    expect(await harf()).toBe('A');

    // Yutulan hayalet click, GERÇEK bir seçimi engellememeli.
    await page.getByRole('dialog').getByText('B', { exact: true }).first().tap();
    await expect(page.getByRole('dialog')).toBeHidden();
    expect(await harf()).toBe('B');
  });

  // 22 Ağustos 2026 — aynı denetimin ikinci bulgusu. Sürükleme eşiği tek bir
  // sayıydı (6px) ve parmak için FAZLA DARDI: hafif titreyen bir dokunuş
  // "sürükleme" sayılıp aynı hücrede bittiğinden HİÇBİR ŞEY yapmıyordu — raf
  // taşı seçilmiyor, konmuş taş geri alınmıyor, joker penceresi açılmıyordu.
  // Kullanıcıya "dokunuşum işlemedi" olarak görünen sessiz bir kayıp.
  // Platform normları 6'nın üstünde (Android touch slop 8px), eşik artık
  // parmakta 10.
  //
  // Bu test SAYIYI değil DAVRANIŞI kilitliyor (sabitleri
  // `mobile/app/test/layout_parity_test.dart` karşılaştırıyor): 8px titreşimli
  // bir dokunuş üç jestte de işlemeli, ve gerçek bir sürükleme hâlâ çalışmalı.
  // Negatif eş: eşik 6'ya döndürülünce üç kontrol de düşüyor.
  /// JOKER OLMAYAN ilk raf taşının indeksi.
  ///
  /// ⚠ NEDEN VAR (27 Ağustos 2026, CI'da düştü): raf RASTGELE dağıtılıyor ve
  /// torbada 2 joker var. `[data-rack-tile="0"]` bir jokerse tahtaya
  /// konulduğunda "Joker Hangi Harf Olsun?" penceresi açılıyor ve o pencere
  /// (`Modal`, `z-[150]`, tam ekran) sonraki HER tıklamayı yutuyor —
  /// Playwright'ın hatası birebir buydu: *"subtree intercepts pointer
  /// events"*. Testler PR'da geçti, `main`'de düştü; yani bu bir uygulama
  /// hatası değil, testin kendi kırılganlığıydı.
  ///
  /// İndeks HER SEÇİMDEN ÖNCE yeniden hesaplanmalı: taş konunca raftan
  /// DÜŞÜYOR ve kalan taşların indeksleri kayıyor.
  const jokersizRafTasi = async (page: Page): Promise<string> => {
    const adet = await page.locator('[data-rack-tile]').count();
    for (let i = 0; i < adet; i++) {
      const sec = `[data-rack-tile="${i}"]`;
      const metin = (await page.locator(sec).innerText()).trim();
      if (!metin.includes('★')) return sec;
    }
    throw new Error('rafta jokerden başka taş yok — testi gözden geçir');
  };

  // 27 Ağustos 2026 — kullanıcı uygulamada bildirdi: *"tahtaya konan taşı
  // kaldırmak için ilk tıklama yakalamıyor. İkincide ya da üçüncüde
  // yakalanıyor."* Portta ölçüldü: hücre 26 px ve parmağın temas MERKEZİ
  // nişan noktasının altında kaldığından ıskalama BİR ALT hücreye düşüyor;
  // o hücre BOŞSA eskiden hiçbir şey olmuyordu (dahası "Önce bir harf seç."
  // yazıyordu). Kurtarma artık boş hücreleri de kapsıyor — ama YALNIZCA
  // hiçbir raf taşı seçili değilken; ikinci iddia tam olarak onu koruyor.
  test('taslak taşın ALTINDAKİ boş hücreye dokunmak taşı GERİ ALIR',
      async ({ page }) => {
    page.on('dialog', (dialog) => dialog.accept());
    await donenKullanici(page);
    await page.goto('/');
    await page.getByText('OYUNU BAŞLAT').click();
    const devam = page.getByLabel('Giriş uyarısı').getByRole('button', { name: 'Oyna', exact: true });
    if (await devam.isVisible().catch(() => false)) await devam.click();
    const qs = page.getByRole('heading', { name: /hızlı başlangıç/i });
    if (await qs.isVisible().catch(() => false)) {
      await page.locator('button[aria-label="Kapat"]').last().click();
    }
    await expect(page.getByRole('main').getByRole('button', { name: 'Pas Geç' })).toBeEnabled();

    const dolu = async (sel: string) =>
      (await page.locator(sel).innerText()).trim().length > 0;

    // Raftan JOKER OLMAYAN bir taş seç, ev karesine (0,0) koy.
    await page.locator(await jokersizRafTasi(page)).click();
    await page.locator('[data-cell="0,0"]').click();
    expect(await dolu('[data-cell="0,0"]')).toBe(true);

    // ISKALAMA: bir alt hücre (1,0) — BOŞ. Seçim de yok (taş konunca düşer).
    await page.locator('[data-cell="1,0"]').click();
    expect(
      await dolu('[data-cell="0,0"]'),
      'taslak taş geri alınmadı — ıskalama sessizce yutuldu',
    ).toBe(false);
  });

  test('SEÇİLİ taş varken aynı tıklama HARFİ KOYAR (kurtarma karışmaz)',
      async ({ page }) => {
    page.on('dialog', (dialog) => dialog.accept());
    await donenKullanici(page);
    await page.goto('/');
    await page.getByText('OYUNU BAŞLAT').click();
    const devam = page.getByLabel('Giriş uyarısı').getByRole('button', { name: 'Oyna', exact: true });
    if (await devam.isVisible().catch(() => false)) await devam.click();
    const qs = page.getByRole('heading', { name: /hızlı başlangıç/i });
    if (await qs.isVisible().catch(() => false)) {
      await page.locator('button[aria-label="Kapat"]').last().click();
    }
    await expect(page.getByRole('main').getByRole('button', { name: 'Pas Geç' })).toBeEnabled();

    const dolu = async (sel: string) =>
      (await page.locator(sel).innerText()).trim().length > 0;

    await page.locator(await jokersizRafTasi(page)).click();
    await page.locator('[data-cell="0,0"]').click();
    // Hiçbir pencere AÇIK OLMAMALI — CI'da düşen tam olarak buydu: joker
    // konunca açılan harf penceresi (tam ekran `Modal`) sonraki tıklamayı
    // yutuyordu. İddia, seçimin gerçekten jokersiz olduğunun kanıtı.
    await expect(page.getByRole('dialog')).toHaveCount(0);

    // İKİNCİ taşı seç ve komşu hücreye koy — kurtarma buna HİÇ karışmamalı.
    // İndeks YENİDEN hesaplanıyor: ilk taş raftan düştü, indeksler kaydı.
    await page.locator(await jokersizRafTasi(page)).click();
    await page.locator('[data-cell="1,0"]').click();

    expect(await dolu('[data-cell="0,0"]')).toBe(true);
    expect(
      await dolu('[data-cell="1,0"]'),
      'seçili taş varken komşu hücreye koyma bozulmuş',
    ).toBe(true);
  });

  test('Titreşimli dokunuş (8px) jest olarak KAYBOLMAZ', async ({ page }) => {
    await oyunEkrani(page);
    const JITTER = 8;
    const rackTile = page.locator('[data-rack]').getByText('M', { exact: true }).first();
    const cell = page.locator('[data-cell="0,0"]');
    // ⚠ `toBeEmpty()` KULLANILAMAZ: (0,0) oyuncunun ev karesi ve boşken bile
    // içinde `HomeMark` SVG'si var — doluluk METİNDEN okunmalı.
    const harfi = async (loc: Locator) => (await loc.innerText()).trim().split('\n')[0];

    // 1) Raf taşı seçimi — seçili taş 7px yukarı kalkar.
    await sloppyTap(page, rackTile, JITTER);
    await expect(page.locator('[data-rack] .\\!-translate-y-\\[7px\\]')).toHaveCount(1);

    // 2) Yerleştirme — bu adım `onClick` yolundan gider, eşikten etkilenmez;
    //    tam da bu yüzden asimetri kullanıcıya "koyabiliyorum ama geri
    //    alamıyorum" olarak görünüyordu.
    await cell.tap();
    expect(await harfi(cell)).toBe('M');

    // 3) Konmuş taşa titreşimli dokunuş → rafa geri alınmalı.
    await sloppyTap(page, cell, JITTER);
    expect(await harfi(cell)).toBe('');

    // 4) Gerçek bir sürükleme, eşik büyüdü diye kaybolmamalı.
    const src = (await rackTile.boundingBox())!;
    const dst = (await page.locator('[data-cell="6,6"]').boundingBox())!;
    const cdp = await page.context().newCDPSession(page);
    const send = (type: string, x: number, y: number) =>
      cdp.send('Input.dispatchTouchEvent', {
        type,
        touchPoints: type === 'touchEnd' ? [] : [{ x, y }],
      });
    const sx = src.x + src.width / 2;
    const sy = src.y + src.height / 2;
    const tx = dst.x + dst.width / 2;
    // Sürüklenen taş parmağın DRAG_LIFT (30px) ÜZERİNDE çizilir ve bırakma
    // hedefi de o kaldırılmış noktadan hesaplanır — bu kod tabanında kayıtlı
    // bir otomasyon tuzağı.
    const ty = dst.y + dst.height / 2 + 30;
    await send('touchStart', sx, sy);
    for (let i = 1; i <= 8; i++) {
      await send('touchMove', sx + ((tx - sx) * i) / 8, sy + ((ty - sy) * i) / 8);
    }
    await send('touchEnd', tx, ty);
    await cdp.detach();
    expect(await harfi(page.locator('[data-cell="6,6"]'))).toBe('M');
  });
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
  // Play, hesap açtıran uygulamalarda WEB talep adresinin YANINDA uygulama
  // İÇİNDEN başlatılabilen bir yol da istiyor (ROADMAP madde 2). Sayfa 25
  // Ağustos 2026'ya kadar "uygulama içinde kendi kendine hesap silme özelliği
  // şu anda bulunmuyor" diyordu; o cümle artık YANLIŞ ve geri gelirse
  // inceleme reddi anlamına gelir.
  await expect(page.getByRole('heading', { name: /Uygulama İçinden Silme/ })).toBeVisible();
  await expect(page.getByText(/Hesabımı Sil/)).toBeVisible();
  expect(await page.locator('main').innerText()).not.toContain('kendi kendine hesap silme');
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

test('/.well-known/assetlinks.json Play imza parmak iziyle statik servis ediliyor', async ({
  page,
}) => {
  // Android App Links doğrulaması bu dosyayı JSON olarak okur. İki bilinen
  // tuzak var: (1) `vercel.json`'daki yakalayıcı rewrite statik yolu yutup
  // SPA kabuğunu döndürebilir (aynı sınıf hata `/gizlilik/`'te yaşandı,
  // bkz. docs/decisions/legal-pages.md); (2) parmak izi YÜKLEME anahtarının
  // değil, Play'in ÜRETTİĞİ imza anahtarının olmalı — ve o değer App
  // signing sayfasındaki anahtar tablosundan DEĞİL, aynı sayfanın
  // "Digital Asset Links JSON" panelinden okunur (bir kez yanlış tablodan
  // okundu, bkz. marketing/play-store/console-formlari.md §6.6).
  const yanit = await page.request.get('/.well-known/assetlinks.json');
  expect(yanit.status()).toBe(200);
  expect(yanit.headers()['content-type']).toContain('json');

  const kayitlar = await yanit.json();
  expect(Array.isArray(kayitlar)).toBe(true);
  const hedef = kayitlar[0].target;

  // Paket adı `mobile/app/android/app/build.gradle.kts`'teki applicationId ile
  // BİREBİR aynı olmalı — sapması hâlinde doğrulama sessizce başarısız olur.
  const gradle = readFileSync(
    new URL('../mobile/app/android/app/build.gradle.kts', import.meta.url),
    'utf8',
  );
  const applicationId = gradle.match(/applicationId\s*=\s*"([^"]+)"/)?.[1];
  expect(hedef.package_name).toBe(applicationId);

  // Yükleme anahtarı (`B6:CD:FB:A9…`) buraya ASLA girmemeli.
  expect(hedef.sha256_cert_fingerprints).toContain(
    '2B:7D:26:11:BB:F3:E2:BC:9F:F2:41:B3:D7:11:AF:AD:35:F4:2D:5E:F5:2E:D5:35:CB:F9:8D:9A:52:66:CE:CB',
  );
  for (const parmakIzi of hedef.sha256_cert_fingerprints) {
    expect(parmakIzi.startsWith('B6:CD:FB:A9')).toBe(false);
  }
});

test('"Buradan başla" balonu boş tahtada ev karesinin yanında; taş KALDIRILINCA kaybolur', async ({
  page,
}) => {
  // NEDEN VAR: kapalı testte insanların İLK HAMLEYİ nereye yapacaklarını
  // bulamadıkları görüldü (kullanıcı isteği, 26 Ağustos 2026). Balon mutlak
  // konumlu bir katman — ızgara geometrisi değişirse SESSİZCE kayar ya da
  // tahtadan taşar, hiçbir derleyici bunu görmez.
  //
  // İddia kendi matematiğime DEĞİL, gerçek hücrenin kutusuna karşı: balonun
  // sol kenarı ev karesinin sağ kenarından tam bir ızgara boşluğu (3px)
  // sonra başlamalı ve dikeyde o kareyle aynı merkezde olmalı. Yüzde
  // yaklaşımı kullanılsaydı bu iddia düşerdi (ölçüldü: ~9px kayma).
  page.on('dialog', (dialog) => dialog.accept());
  await donenKullanici(page);
  await page.goto('/');
  await page.getByText('OYUNU BAŞLAT').click();
  const devam = page.getByLabel('Giriş uyarısı').getByRole('button', { name: 'Oyna' });
  if (await devam.isVisible().catch(() => false)) await devam.click();
  const quickstart = page.getByRole('heading', { name: /hızlı başlangıç/i });
  if (await quickstart.isVisible().catch(() => false)) {
    await page.locator('button[aria-label="Kapat"]').last().click();
  }

  const balon = page.locator('[data-start-hint]');
  await expect(balon).toBeVisible();
  await expect(balon).toContainText('Buradan başla');

  // 2 kişilik oyunda insan oyuncu sol-üst köşede (cornersFor) → ev karesi 0,0.
  const ev = page.locator('[data-cell="0,0"]');
  const e = (await ev.boundingBox())!;
  const b = (await balon.boundingBox())!;
  expect(b.x - (e.x + e.width)).toBeGreaterThan(1);
  expect(b.x - (e.x + e.width)).toBeLessThan(6); // ızgara boşluğu = 3px
  // TOLERANS SIKI (0.75px) ve bu bilinçli: yüzde yaklaşımıyla `calc`
  // arasındaki fark bu tahta boyutunda ve 0. SATIRDA yalnızca ~1.4px —
  // 1.5px'lik bir tolerans yanlış sürümü de geçiriyordu (ölçüldü, negatif
  // eş kurulurken yakalandı). Gevşek bir iddia, hiç iddia olmamasından
  // daha kötü: yeşil yanar ama hiçbir şey kanıtlamaz.
  expect(Math.abs(b.y + b.height / 2 - (e.y + e.height / 2))).toBeLessThan(0.75);

  // Tahtadan taşmamalı.
  const izgara = page.locator('div.grid').first();
  const g = (await izgara.boundingBox())!;
  expect(b.x + b.width).toBeLessThanOrEqual(g.x + g.width + 1);

  // Balon taş KONUNCA değil, taş KALDIRILDIĞI anda gitmeli (kullanıcı
  // isteği, 26 Ağustos 2026). Raftan bir taş seçmek "kaldırmak"tır —
  // bırakma hedefinin yanında duran bir ipucu dikkat dağıtır.
  await page.locator('[data-rack-tile="0"]').click();
  await expect(balon).toHaveCount(0);

  // Konduktan sonra da geri gelmemeli (tahta artık boş değil).
  await ev.click();
  await expect(balon).toHaveCount(0);
});

test('dokunma hedefleri: modal ✕ görsel kutusunun dışından da kapanır, raf taşı hedefi taşın kendisinden büyük', async ({
  page,
}) => {
  // NEDEN VAR (27 Ağustos 2026, kullanıcı uygulamada bildirdi ve web'de de
  // aynısı ölçüldü): *"bazı tıklamalar yine biraz üstte gibi. Mesela skor
  // kartı x'de dikkatimi çekti"* + *"harfi yakalamak bazen zor oluyor"*.
  //
  // Modal ✕'leri `w-7 h-7` = 28×28'di (Material asgarisinin yarısından az),
  // raf taşının hedefi ise taşın kendisi kadardı (34.6×46) ve çevresi ölü
  // alandı. İkisi de büyütüldü, GÖRSEL HİÇ DEĞİŞMEDEN: ✕'te düzeni
  // etkilemeyen bir `::after` (`.tap-expand`, index.css), rafta ölü dolgunun
  // hedefe devredilmesi (`Rack.tsx`).
  //
  // ⚠ İDDİA GÖRÜNTÜYE DEĞİL DAVRANIŞA: ✕'in GÖRSEL kutusunun 8 px ALTINA
  // tıklanıyor — düzeltmeden önce bu tıklama boşa giderdi.
  page.on('dialog', (dialog) => dialog.accept());
  await donenKullanici(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.getByText('OYUNU BAŞLAT').click();
  const devam = page.getByLabel('Giriş uyarısı').getByRole('button', { name: 'Oyna', exact: true });
  if (await devam.isVisible().catch(() => false)) await devam.click();
  const quickstart = page.getByRole('heading', { name: /hızlı başlangıç/i });
  if (await quickstart.isVisible().catch(() => false)) {
    await page.locator('button[aria-label="Kapat"]').last().click();
  }
  await expect(page.getByRole('main').getByRole('button', { name: 'Pas Geç' })).toBeEnabled();

  // ── Raf taşı ────────────────────────────────────────────────────────────
  const kutular: { hedef: DOMRect; gorsel: DOMRect }[] = [];
  for (let i = 0; i < 7; i++) {
    const hedef = (await page.locator(`[data-rack-tile="${i}"]`).boundingBox())!;
    const gorsel = (await page
      .locator(`[data-rack-tile="${i}"] > div`)
      .first()
      .boundingBox())!;
    kutular.push({ hedef: hedef as DOMRect, gorsel: gorsel as DOMRect });
    // Taşın kendisi 46 yüksek; hedef 65 (7 kalkma payı + 46 + 12 alt dolgu).
    expect(gorsel.height).toBeCloseTo(46, 1);
    expect(hedef.height).toBeCloseTo(65, 1);
    // Hedef her yönde taşı KAPSIYOR ve altında 12 px fazladan yer var —
    // parmağın temas merkezi nişan noktasının ALTINDA kaldığından
    // ıskalamalar tam oraya düşüyor (bkz. docs/decisions/touch-ux-bugs.md).
    expect(hedef.y).toBeLessThanOrEqual(gorsel.y);
    expect(hedef.y + hedef.height - (gorsel.y + gorsel.height)).toBeCloseTo(12, 1);
  }
  // Komşu hedefler ARALIKSIZ: aradaki 3 px'lik ölü boşluk kalmadı.
  for (let i = 1; i < 7; i++) {
    const bosluk = kutular[i].hedef.x - (kutular[i - 1].hedef.x + kutular[i - 1].hedef.width);
    expect(Math.abs(bosluk)).toBeLessThan(0.05);
    // Taşların ÇİZİLDİĞİ aralık ise hâlâ 3 px — görsel değişmedi.
    const gorselBosluk =
      kutular[i].gorsel.x - (kutular[i - 1].gorsel.x + kutular[i - 1].gorsel.width);
    expect(gorselBosluk).toBeCloseTo(3, 1);
  }

  // ── Modal ✕ ─────────────────────────────────────────────────────────────
  await page.getByRole('button', { name: 'Nasıl Oynanır?' }).click();
  const baslik = page.getByRole('heading', { name: /hızlı başlangıç/i });
  await expect(baslik).toBeVisible();

  const kapat = page.locator('button[aria-label="Kapat"]').last();
  const k = (await kapat.boundingBox())!;
  // Görsel kutu KÜÇÜK KALDI — büyüyen yalnızca hedef.
  expect(k.width).toBeCloseTo(28, 1);
  expect(k.height).toBeCloseTo(28, 1);
  const genisletici = await kapat.evaluate((el) => {
    const s = getComputedStyle(el, '::after');
    return { w: s.width, h: s.height };
  });
  expect(genisletici).toEqual({ w: '48px', h: '48px' });

  // Ve asıl iddia: görsel kutunun 8 px ALTINA tıklamak modalı kapatır.
  await page.mouse.click(k.x + k.width / 2, k.y + k.height + 8);
  await expect(baslik).toHaveCount(0);
});
