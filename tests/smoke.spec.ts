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
    await page.getByRole('button', { name: /SIRA SENDE/i }).click();
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

    // ⏱ 1 Eylül 2026'dan beri gerçek jest ritmi ŞART: taş konduktan sonra
    // 300 ms İÇİNDE aynı bölgeye (40 px) yapılan ikinci dokunuş artık tanım
    // gereği ÇİFT DOKUNUŞTUR (tahta zoom'u — `src/utils/boardZoom.ts`) ve
    // hücre işlemi bilerek yutulur. Testler Playwright hızında koştuğundan
    // araya insan ritmi konuyor; ölçülen davranış DEĞİŞMEDİ.
    await page.waitForTimeout(350);
    // ISKALAMA: bir alt hücre (1,0) — BOŞ. Seçim de yok (taş konunca düşer).
    await page.locator('[data-cell="1,0"]').click();
    expect(
      await dolu('[data-cell="0,0"]'),
      'taslak taş geri alınmadı — ıskalama sessizce yutuldu',
    ).toBe(false);
  });

  // 28 Ağustos 2026 — bir kullanıcı bildirdi: *"tahtaya konan taşı geri almak
  // için tıkladığında 2 harf birden geri geliyor."* Kök sebep jokerde ya da
  // reducer'da DEĞİL, YUTMANIN KAPSAMINDA: `tapPlacedTile` compat click'i
  // yalnızca JOKER dalında yutuyordu. Sıradan taş dalında o click boşalmış
  // hücreye düşüp HİÇBİR ŞEY yapmadığı için zararsız sanılıyordu — ta ki
  // yukarıdaki boş-hücre kurtarması (27 Ağustos) onu İŞ YAPAR hâle getirene
  // kadar: kurtarma komşudaki taslak taşı bulup ONU da geri alıyor.
  //
  // ÖLÇÜLDÜ (390×844, hasTouch): raf 5 → 7; doğrusu 5 → 6. Olay zinciri
  // `tapPlacedTile 0,1` → `handleCellClick 0,1` → kurtarma `0,0` →
  // `tapPlacedTile 0,0`.
  //
  // ⚠ MASAÜSTÜ PROFİLİNDE GÖRÜNMEZ ve bu testin dokunmatik blokta olmasının
  // sebebi bu: fareyle click'in hedefi az önce SÖKÜLEN taş düğümü oluyor,
  // React onu hiçbir fiber'a eşleyemiyor ve olay sessizce düşüyor. Compat
  // click ise hit-test'i O ANDAKİ DOM üzerinde yapıyor, yani hâlâ bağlı olan
  // HÜCREYE düşüyor. Aynı sınıfın üçüncü örneği (bkz. `ghostClick.ts`).
  test('taslak taşa dokunmak YALNIZCA o taşı geri alır (komşusunu değil)',
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

    const rafSayisi = () => page.locator('[data-rack-tile]').count();
    const dolu = async (sel: string) =>
      (await page.locator(sel).innerText()).trim().length > 0;

    // KOMŞU iki taslak taş: ev karesi (0,0) ve yanı (0,1). Komşuluk şart —
    // kurtarma yalnızca ortogonal komşulara bakıyor, hatanın doğduğu yer de
    // tam orası.
    await page.locator(await jokersizRafTasi(page)).tap();
    await page.locator('[data-cell="0,0"]').tap();
    await page.locator(await jokersizRafTasi(page)).tap();
    await page.locator('[data-cell="0,1"]').tap();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    expect(await dolu('[data-cell="0,0"]')).toBe(true);
    expect(await dolu('[data-cell="0,1"]')).toBe(true);

    const oncesi = await rafSayisi();

    // ⏱ 1 Eylül 2026'dan beri gerçek jest ritmi ŞART: taş konduktan sonra
    // 300 ms İÇİNDE aynı bölgeye (40 px) yapılan ikinci dokunuş artık tanım
    // gereği ÇİFT DOKUNUŞTUR (tahta zoom'u — `src/utils/boardZoom.ts`) ve
    // hücre işlemi bilerek yutulur. Testler Playwright hızında koştuğundan
    // araya insan ritmi konuyor; ölçülen davranış DEĞİŞMEDİ.
    await page.waitForTimeout(350);
    // >>> Bildirilen jest: taslak taşa TEK DOKUNUŞ.
    await page.locator('[data-cell="0,1"]').tap();

    expect(
      await rafSayisi(),
      'rafa BİRDEN FAZLA taş döndü — hayalet click komşu taslağı da geri aldı',
    ).toBe(oncesi + 1);
    expect(
      await dolu('[data-cell="0,0"]'),
      'komşu taslak taş da geri alınmış',
    ).toBe(true);
    expect(await dolu('[data-cell="0,1"]')).toBe(false);
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

  // 27 Ağustos 2026 — kullanıcı uygulamada İKİNCİ kez bildirdi: *"Hâlâ
  // tahtaya koyulan taşı her zaman alamıyorum. 1-2 denemeden sonra
  // alabiliyorum."* Yukarıdaki 8 px'lik test geçiyordu çünkü 8, hayalet
  // eşiğinin (10) ALTINDA. Portta ölçüldü: **12 ve 20 px kayan dokunuşlar
  // hiçbir şey yapmıyordu** — eşik aşılınca jest "sürükleme" sayılıp 30 px
  // KALDIRILMIŞ bir noktaya bırakılıyordu, üstelik raf taşı bile
  // seçilemiyordu.
  //
  // Artık iki AYRI karar var: hayalet 10 px'te belirir, bırakma ise jest
  // gerçekten bir yere gittiyse (`TAP_SLOP_ON_RELEASE` = 24) bırakma sayılır.
  for (const JITTER of [14, 22]) {
    test(`Titreşimli dokunuş (${JITTER}px, eşiğin ÜSTÜNDE) kaybolmaz`, async ({
      page,
    }) => {
      await oyunEkrani(page);
      const cell = page.locator('[data-cell="0,0"]');
      const harfi = async (loc: Locator) =>
        (await loc.innerText()).trim().split('\n')[0];

      // 1) Raf taşı seçimi — titreşimli dokunuşta da seçilmeli.
      const rackTile = page.locator('[data-rack]').getByText('M', { exact: true }).first();
      await sloppyTap(page, rackTile, JITTER);
      await expect(page.locator('[data-rack] .\\!-translate-y-\\[7px\\]')).toHaveCount(1);
      // Ve İSTEMEDEN tahtaya konmamalı: kaldırılmış nokta rafın 30 px
      // üstünü, yani tahtanın alt satırını hedefliyordu.
      expect(await harfi(cell)).toBe('');

      await cell.tap();
      expect(await harfi(cell)).toBe('M');

      // 2) Konmuş taşa titreşimli dokunuş → geri alınmalı. Düzeltmeden önce
      //    burada HİÇBİR ŞEY olmuyordu.
      // ⏱ Araya insan ritmi: 300 ms içindeki ikinci dokunuş artık çift
      //    dokunuştur (zoom, bkz. `src/utils/boardZoom.ts`).
      await page.waitForTimeout(350);
      await sloppyTap(page, cell, JITTER);
      expect(
        await harfi(cell),
        `${JITTER}px kayan dokunuş sessizce kayboldu`,
      ).toBe('');
    });
  }

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
    // ⏱ Araya insan ritmi: 300 ms içindeki ikinci dokunuş artık çift
    //    dokunuştur (zoom, bkz. `src/utils/boardZoom.ts`).
    await page.waitForTimeout(350);
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

// ── /nasil-oynanir/ — taranabilir kurallar sayfası (31 Ağustos 2026) ───────
// NEDEN VAR (ROADMAP #6): Google AI Mode 17 Ağustos 2026'da Kelimeki'yi
// "kelime bulucu ve sözlük platformu" diye TAMAMEN UYDURDU. Sebep ölçülmüştü:
// oyunu anlatan tek zengin içerik `HelpModal` ve o YALNIZCA pencere açılınca
// render oluyordu — taranabilir HTML'de hiç yoktu.
//
// ⚠ Bu testlerin konusu "sayfa açılıyor mu" DEĞİL, **JS'siz okunabiliyor mu**.
// Client-render bu işi görmezdi: Googlebot JS çalıştırıyor ama AI/LLM
// crawler'ları çalıştırmıyor, yani sorunu DOĞURAN tarafı ıskalardı.
test('/nasil-oynanir/ JS OLMADAN okunabilir ve kendi meta\'sını taşır', async ({ page }) => {
  await page.goto('/nasil-oynanir/');

  await expect(page.getByRole('heading', { level: 1, name: 'Nasıl Oynanır' })).toBeVisible();
  // Statik olmanın kanıtı: uygulama kabuğu HİÇ yok.
  await expect(page.locator('#root')).toHaveCount(0);
  await expect(page.locator('#karsilama')).toHaveCount(0);

  // Kendi meta'sı — yoksa SPA'nın genel meta'sını miras alır ve kazancın
  // yarısı giderdi (ROADMAP #6'nın üçüncü "gizli bağ"ı).
  await expect(page).toHaveTitle(/Nasıl Oynanır/);
  await expect(page.locator('meta[name="description"]')).toHaveAttribute(
    'content',
    /nasıl oynanır/i,
  );
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    'href',
    'https://kelimeki.com/nasil-oynanir/',
  );
});

// Paylaşım kartı. `/nasil-oynanir/` paylaşılabilir bir sayfa (karşılama
// katmanı ona link veriyor) ve 31 Ağustos 2026'da Bing Webmaster Tools'un
// markup raporu `/` için "JSON-LD + OpenGraph" derken bu sayfa için HİÇBİR
// şey demiyordu — çünkü statik üretici `<head>`e OG etiketi hiç yazmıyordu.
//
// ⚠ İKİ sayfa birden okunuyor: tek sayfa test edilse sabit (hardcode) bir
// başlık/URL de testi geçerdi. Değerlerin sayfaya GÖRE değiştiği kanıtlanmalı.
for (const [yol, baslikParcasi] of [
  ['/nasil-oynanir/', 'Nasıl Oynanır'],
  ['/gizlilik/', 'Gizlilik Politikası'],
] as const) {
  test(`${yol} paylaşım kartı etiketlerini taşıyor`, async ({ page }) => {
    await page.goto(yol);

    await expect(page.locator('meta[property="og:url"]')).toHaveAttribute(
      'content',
      `https://kelimeki.com${yol}`,
    );
    await expect(page.locator('meta[property="og:title"]')).toHaveAttribute(
      'content',
      new RegExp(baslikParcasi),
    );
    // Açıklama sayfanın KENDİ description'ıyla aynı olmalı — kartta genel bir
    // site açıklaması çıkarsa link paylaşan kişi yanlış sayfayı tarif eder.
    const aciklama = await page
      .locator('meta[name="description"]')
      .getAttribute('content');
    expect(aciklama && aciklama.length > 40).toBe(true);
    await expect(page.locator('meta[property="og:description"]')).toHaveAttribute(
      'content',
      aciklama!,
    );
    await expect(page.locator('meta[property="og:image"]')).toHaveAttribute(
      'content',
      'https://kelimeki.com/og-image.png',
    );
    await expect(page.locator('meta[name="twitter:card"]')).toHaveAttribute(
      'content',
      'summary_large_image',
    );
  });
}

test('/nasil-oynanir/ kurallar metnini GERÇEKTEN taşıyor (boş kabuk değil)', async ({ page }) => {
  await page.goto('/nasil-oynanir/');
  const metin = (await page.locator('main').innerText()).replace(/\s+/g, ' ');

  // Sayfanın var olma sebebi bu kelimeler: oyunu ne yapan şeyler bunlar.
  // Biri kaybolursa sayfa açılıyor ama İŞİNİ görmüyor demektir.
  for (const anahtar of ['bölge vergisi', 'Bingo', 'Joker', 'TDK']) {
    expect(metin.toLowerCase()).toContain(anahtar.toLowerCase());
  }
  // Kabaca bir hacim eşiği — "başlık var, gövde boş" hâlini yakalar.
  expect(metin.length).toBeGreaterThan(3000);
});

test('/nasil-oynanir/ içeriği HelpModal.tsx ile AYNI KAYNAKTAN — kopya değil', async ({
  page,
}) => {
  // İki kopya bu projenin en sık tekrarlayan hata sınıfı; burada üçüncü bir
  // taraf daha var: `mobile/app/test/help_text_parity_test.dart` DA
  // `HelpModal.tsx`i tarıyor. İçerik oradan çıkarsa hem bu sayfa hem o mobil
  // test sessizce ayrışır.
  //
  // ⚠ Karşılaştırma pencereyle DEĞİL KAYNAK DOSYAYLA yapılıyor. Pencereye
  // ulaşmak giriş ya da başlamış bir oyun ister (link `UserMenu`de ve tahtanın
  // alt şeridinde); o kurulum bu testin konusunu — "sayfa metni HelpModal'dan
  // mı geliyor" — daha zayıf değil daha kırılgan kanıtlardı. Dart tarafındaki
  // parite testi de aynı sebeple kaynak taraması yapıyor.
  const kaynak = readFileSync('src/components/HelpModal.tsx', 'utf8');
  const basliklar = [...kaynak.matchAll(/<Section title="([^"]+)"/g)].map((m) => m[1]);
  expect(basliklar.length).toBeGreaterThan(3);

  await page.goto('/nasil-oynanir/');
  // ⚠ Başlıklar ekranda `uppercase` ile çiziliyor ve `innerText` DÖNÜŞMÜŞ
  // metni veriyor — kaynaktaki "Bölge Vergisi" ile ekrandaki "BÖLGE VERGİSİ"
  // ham hâlde eşleşmez. Karşılaştırma bu yüzden normalleştirilmiş:
  // Türkçe locale ile büyütülüp (i→İ, ı→I) boşluklar teklenmiş.
  const norm = (t: string) => t.replace(/\s+/g, ' ').trim().toLocaleUpperCase('tr');
  const sayfaBasliklari = (await page.locator('main h3').allInnerTexts()).map(norm);
  for (const b of basliklar) {
    expect(sayfaBasliklari).toContain(norm(b));
  }

  // "Hızlı Başlangıç" maddeleri de sayfada olmalı — `QuickStart` ithal
  // edilmezse başlıklar yine tutar ama özet kaybolurdu.
  const metin = await page.locator('main').innerText();
  const ilkMadde = /<QuickItem icon="[^"]+">\s*([^<{]{10,40})/.exec(kaynak)?.[1]?.trim();
  expect(ilkMadde, 'HelpModal.tsx\'te <QuickItem> bulunamadı').toBeTruthy();
  expect(metin.replace(/\s+/g, ' ')).toContain(ilkMadde!.replace(/\s+/g, ' '));
});

test('katmandaki "Kuralların tamamı" GERÇEK bir bağlantı — robot izleyebilsin', async ({
  page,
}) => {
  // Öksüz sayfa sorunu: yalnızca sitemap'te duran bir URL zayıf keşfedilir.
  // Footer'daki hukuki bağlantılar `<button>` (SPA penceresi açıyorlar), bu
  // ise gerçek bir `<a href>` olmak ZORUNDA.
  await page.goto('/');
  const link = page.locator('a[href="/nasil-oynanir/"]');
  await expect(link).toBeVisible();

  // Yeni sekmede açılmalı: katman ilk ziyaretçinin DÖNÜŞÜM sayfası, onu
  // buradan çıkarmıyoruz (31 Ağustos 2026 kullanıcı kararı). `href` yerinde
  // durduğu için robot tarafı bundan etkilenmiyor — yukarıdaki iddia geçerli.
  await expect(link).toHaveAttribute('target', '_blank');
  await expect(link).toHaveAttribute('rel', /noopener/);

  // Gerçekten yeni bir sekme açılıyor mu — attribute'a değil DAVRANIŞA bak.
  const [yeniSekme] = await Promise.all([
    page.context().waitForEvent('page'),
    link.click(),
  ]);
  await yeniSekme.waitForLoadState();
  expect(new URL(yeniSekme.url()).pathname).toBe('/nasil-oynanir/');
  await expect(yeniSekme.getByRole('heading', { level: 1, name: 'Nasıl Oynanır' })).toBeVisible();
  // Katman AÇIK kalmalı — asıl gerekçe bu.
  expect(new URL(page.url()).pathname).toBe('/');
  await yeniSekme.close();
});

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

test('hiç başlamamış oyun İZ BIRAKMAZ, başlamış oyun kaydedilir', async ({ page }) => {
  // NEDEN VAR (31 Ağustos 2026, bir kullanıcı bildirdi: *"oyundayken hiç
  // hamle yapmadan giriş yaparsan YZ oyunlar 1 gösteriyor ve oyun orada
  // bekliyor"*): autosave, henüz BAŞLAMAMIŞ bir oyunu (turnCount<2) da
  // yazıyordu ve onu silmek TEK bir çıkış yoluna (`handleLogoClick`)
  // bırakılmıştı. Başka her çıkış — yeniden yükleme, sekme/uygulama
  // kapatma, giriş yapıp farklı gezinme — hayalet bir "Devam Eden Oyun"
  // bırakıyordu. Üretim verisinde ölçüldü: 83 `local_game_saves` kaydının
  // 5'i turnCount<2, 5 ayrı kullanıcıda, en eskisi 31 Temmuz.
  //
  // ⚠ İKİ İDDİA BİRLİKTE: yalnızca "iz bırakmaz" iddiası olsaydı, kaydı
  // tamamen kapatan bir "düzeltme" de testi geçerdi — ikinci yarı gerçek
  // bir oyunun HÂLÂ kaydedildiğini kilitliyor.
  //
  // Bulut yolu (girişli kullanıcı, `local_game_saves`) burada test
  // EDİLEMİYOR (Supabase yok), ama koruma iki dalın da ÖNÜNDEKİ tek bir
  // `turnCount < 2` kapısı — misafir yolu onu birebir aynı şekilde geçiyor.
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

  const kayit = () =>
    page.evaluate(() => {
      const raw = localStorage.getItem('kelimeki:game-state');
      return raw ? (JSON.parse(raw).state?.turnCount ?? null) : null;
    });

  // ── 1) Hiç hamle yokken HİÇBİR ŞEY yazılmamalı ──────────────────────────
  expect(await kayit()).toBeNull();

  // Çıkış butonuna BASMADAN sayfayı yenile (sekme kapatmanın eşdeğeri) —
  // hatanın ortaya çıktığı yol tam olarak buydu.
  await page.reload();
  await expect(page.getByText('OYUNU BAŞLAT')).toBeVisible();
  expect(await kayit()).toBeNull();
  await expect(page.getByText(/Devam Eden/i)).toHaveCount(0);

  // ── 2) Gerçekten başlamış oyun HÂLÂ kaydedilir ──────────────────────────
  await page.getByText('OYUNU BAŞLAT').click();
  const devam2 = page.getByLabel('Giriş uyarısı').getByRole('button', { name: 'Oyna', exact: true });
  if (await devam2.isVisible().catch(() => false)) await devam2.click();
  await expect(page.getByRole('main').getByRole('button', { name: 'Pas Geç' })).toBeEnabled();
  await page.getByRole('main').getByRole('button', { name: 'Pas Geç' }).click();
  await page.getByLabel('Pas geçme onayı').getByRole('button', { name: 'Pas Geç' }).click();
  // Pas + YZ'nin cevabı = turnCount 2 ("gerçekten başladı" eşiği).
  await expect.poll(kayit, { timeout: 20_000 }).toBeGreaterThanOrEqual(2);

  await page.reload();
  await expect(page.getByText(/Devam Eden/i).first()).toBeVisible();
});

test('`.tap-expand` konumu utility ile ÇAKIŞMIYOR — modal ✕ sağ üst köşede kalıyor', async ({
  page,
}) => {
  // NEDEN VAR (31 Ağustos 2026, bir kullanıcı "Giriş uyarısı"nda bildirdi:
  // *"Girişsiz oyun açılış uyarısı X kaymış"*): `.tap-expand` `position:
  // relative` tanımlıyordu ve KATMANSIZ yazıldığı için Tailwind'in
  // `.absolute` utility'siyle AYNI specificity'de (0,1,0) olup derlenmiş
  // CSS'te ondan SONRA geliyordu — yani onu EZİYORDU. `absolute top-3
  // right-3 ... tap-expand` taşıyan ✕'ler `relative` olup akışa giriyor ve
  // kartın SOL ÜSTÜNE düşüyordu (ölçüldü: sağ kenardan 317 px, olması
  // gereken ~13 px). Aynı sınıf dizesini taşıyan ALTI yer birden bozuktu:
  // Setup (bu test), RankInfoModal, FriendsModal, PlayerScoreCard,
  // RewardBanner, OnlineGameScreen — beşi Supabase gerektirdiğinden burada
  // yalnızca Setup'takine bakılıyor, ama sebep TEK ve ortak: index.css'teki
  // kural artık `@layer components` içinde (utilities'ten ÖNCE yayınlanır).
  //
  // ⚠ İDDİA HEM KONUM HEM HEDEF: sınıf tamamen kaldırılarak "düzeltilirse"
  // konum testi geçer ama dokunma hedefi 28×28'e düşer — ikisi birlikte
  // ölçülüyor.
  await donenKullanici(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.getByText('OYUNU BAŞLAT').click();
  const kart = page.getByLabel('Giriş uyarısı');
  await expect(kart).toBeVisible();

  const olcum = await kart.evaluate((k) => {
    const x = k.querySelector('[aria-label="Kapat"]') as HTMLElement;
    const rk = k.getBoundingClientRect();
    const rx = x.getBoundingClientRect();
    const after = getComputedStyle(x, '::after');
    return {
      pozisyon: getComputedStyle(x).position,
      sagdan: rk.right - rx.right,
      ustten: rx.top - rk.top,
      gorselW: rx.width,
      gorselH: rx.height,
      hedefW: parseFloat(after.width),
      hedefH: parseFloat(after.height),
    };
  });

  // Konum: `absolute` kazanmalı ve ✕ SAĞ üst köşede olmalı.
  expect(olcum.pozisyon).toBe('absolute');
  expect(olcum.sagdan).toBeLessThan(20);
  expect(olcum.ustten).toBeLessThan(20);
  // Görsel kutu küçük KALDI, dokunma hedefi 48×48.
  expect(olcum.gorselW).toBeCloseTo(28, 1);
  expect(olcum.gorselH).toBeCloseTo(28, 1);
  expect(olcum.hedefW).toBe(48);
  expect(olcum.hedefH).toBe(48);
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

// ═══════════════════════════════════════════════════════════════════════
// TAHTA YAKINLAŞTIRMASI (1 Eylül 2026) — kullanıcı kararı: *"web'e de
// uygulama kararı aldım. Her yerde aynı deneyim olsun."* Davranış portla
// birebir; kararlar `src/utils/boardZoom.ts` başlığında.
//
// Dokunmatik bağlam ŞART: jest CDP dokunuş olaylarıyla üretiliyor (fare
// çift tıklaması farklı bir olay zinciri).
// ═══════════════════════════════════════════════════════════════════════
test.describe('tahta zoom', () => {
  test.use({ hasTouch: true, isMobile: true, viewport: { width: 390, height: 844 } });

  /** Yarım kalmış bir yerel oyun (rafı sabit) — zoom testleri taş koyup
   *  geri alabilsin diye. `dokunmatik jestler` bloğundaki fikstürün aynısı,
   *  orada `describe`a kapalı olduğundan burada tekrar kuruluyor. */
  async function kayit(): Promise<string> {
    const { gameReducer, createInitialState } = await import('../src/game/gameReducer');
    const { TILE_DATA } = await import('../src/data/tiles');
    let s = gameReducer(createInitialState(), {
      type: 'START',
      players: [
        { name: 'Misafir', isAI: false },
        { name: 'Yapay Zeka', isAI: true },
      ],
    });
    const rack = ['K', 'E', 'L', 'İ', 'M', 'E', '?'].map((letter) =>
      letter === '?'
        ? { letter: '?', pts: 0, wild: true }
        : { letter, pts: TILE_DATA[letter].pts },
    );
    s = { ...s, current: 0, players: s.players.map((p, i) => (i === 0 ? { ...p, rack } : p)) };
    return JSON.stringify({ version: 1, state: s, savedAt: Date.now() });
  }

  async function oyunEkrani(page: Page): Promise<void> {
    await donenKullanici(page);
    await page.addInitScript((payload) => {
      localStorage.setItem('kelimeki:game-state', payload as string);
    }, await kayit());
    await page.goto('/');
    await page.getByRole('button', { name: /SIRA SENDE/i }).click();
    const quickstartHeading = page.getByRole('heading', { name: /hızlı başlangıç/i });
    if (await quickstartHeading.isVisible().catch(() => false)) {
      await page.locator('button[aria-label="Kapat"]').last().click();
    }
    await expect(page.locator('[data-board-grid]')).toBeVisible();
  }

  /** Tek dokunuş — ham CDP (Playwright `tap()` locator ister, biz KOORDİNAT
   *  dokunuşu yapıyoruz: hücreler arası boşluk ve çerçeve de test ediliyor). */
  async function dokun(page: Page, x: number, y: number): Promise<void> {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await cdp.detach();
  }

  /** Çift dokunuş: pencere (300 ms) İÇİNDE aynı noktaya iki dokunuş. */
  async function ciftDokun(page: Page, x: number, y: number): Promise<void> {
    await dokun(page, x, y);
    await page.waitForTimeout(60);
    await dokun(page, x, y);
    // Aç/kapa animasyonu (180 ms) + pay.
    await page.waitForTimeout(280);
  }

  /** Izgaranın uygulanmış ölçeği (transform matrisinden). */
  async function olcek(page: Page): Promise<number> {
    return page.locator('[data-board-grid]').evaluate((el) => {
      const t = getComputedStyle(el).transform;
      if (!t || t === 'none') return 1;
      return new DOMMatrixReadOnly(t).a;
    });
  }

  /** Hücrede taş var mı — mevcut testlerin `dolu` deseni (innerText). */
  async function doluMu(page: Page, cell: string): Promise<boolean> {
    return (await page.locator(`[data-cell="${cell}"]`).innerText()).trim().length > 0;
  }

  async function hucreKutusu(page: Page, r: number, c: number) {
    return (await page.locator(`[data-cell="${r},${c}"]`).boundingBox())!;
  }

  // ── Tanıtım balonu (1 Eylül 2026, kullanıcı isteği) ─────────────────
  // Kural İKİ değere birden bakıyor: gösterim sayacı (tavan 2) VE "denedi
  // mi". Port ikizi: `mobile/app/test/zoom_hint_test.dart` — metin ikisinde
  // de BİREBİR aynı olmalı.
  const HINT = 'Boş kareye veya çerçevesine çift tıklama tahtayı büyütür. Hemen dene!';

  /** Balon bayraklarını oyun açılmadan ÖNCE tohumlar. */
  async function tohumla(page: Page, v: { shown?: number; tried?: boolean }) {
    await page.addInitScript((val) => {
      const o = val as { shown?: number; tried?: boolean };
      try {
        if (o.shown !== undefined) {
          localStorage.setItem('kelimeki:zoom-hint-shown', String(o.shown));
        }
        if (o.tried) localStorage.setItem('kelimeki:zoom-tried', '1');
      } catch {
        // depolama kapalıysa test zaten balonu beklemiyor
      }
    }, v);
  }

  async function sayac(page: Page): Promise<number> {
    return page.evaluate(
      () => Number(localStorage.getItem('kelimeki:zoom-hint-shown') ?? '0'),
    );
  }

  test('ilk oyun açılışında balon ÇIKAR, sayaç 1 olur', async ({ page }) => {
    await oyunEkrani(page);
    await expect(page.getByText(HINT)).toBeVisible();
    expect(await sayac(page)).toBe(1);
  });

  test('hiç denemeyene İKİNCİ açılışta bir kez daha çıkar, üçüncüde çıkmaz',
      async ({ page }) => {
    await tohumla(page, { shown: 1 });
    await oyunEkrani(page);
    await expect(page.getByText(HINT)).toBeVisible();
    expect(await sayac(page)).toBe(2);
  });

  test('tavana ulaşınca (2) balon çıkmaz', async ({ page }) => {
    await tohumla(page, { shown: 2 });
    await oyunEkrani(page);
    await expect(page.getByText(HINT)).toHaveCount(0);
    expect(await sayac(page)).toBe(2);
  });

  test('zoom DENEYENE bir daha çıkmaz (sayaç 0 olsa bile)', async ({ page }) => {
    await tohumla(page, { tried: true });
    await oyunEkrani(page);
    await expect(page.getByText(HINT)).toHaveCount(0);
    expect(await sayac(page)).toBe(0);
  });

  test('zoom denenince balon anında kapanır ve bayrak kalıcı yazılır',
      async ({ page }) => {
    await oyunEkrani(page);
    await expect(page.getByText(HINT)).toBeVisible();

    const b = await hucreKutusu(page, 6, 6);
    await ciftDokun(page, b.x + b.width / 2, b.y + b.height / 2);
    expect(await olcek(page)).toBeCloseTo(2, 1);
    await expect(page.getByText(HINT)).toHaveCount(0);
    expect(await page.evaluate(() => localStorage.getItem('kelimeki:zoom-tried')))
      .toBe('1');
  });

  test('balon tahtadan TAŞMAZ (dar telefonda metin sarılır)', async ({ page }) => {
    await oyunEkrani(page);
    const balon = (await page.locator('[data-zoom-hint]').boundingBox())!;
    const vp = (await page.locator('[data-board-viewport]').boundingBox())!;
    expect(balon.x).toBeGreaterThanOrEqual(vp.x - 1);
    expect(balon.x + balon.width).toBeLessThanOrEqual(vp.x + vp.width + 1);
    // Ve gerçekten sarılmış olmalı: tek satır olsaydı bu metin taşardı.
    expect(balon.height).toBeGreaterThan(24);
  });

  test('boş kareye çift dokunuş zoom açar, tekrarı kapatır', async ({ page }) => {
    await oyunEkrani(page);
    expect(await olcek(page)).toBeCloseTo(1, 2);

    const b = await hucreKutusu(page, 6, 6);
    await ciftDokun(page, b.x + b.width / 2, b.y + b.height / 2);
    expect(await olcek(page)).toBeCloseTo(2, 1);

    await ciftDokun(page, b.x + b.width / 2, b.y + b.height / 2);
    expect(await olcek(page)).toBeCloseTo(1, 2);
  });

  test('TEK dokunuş anında taş koyar — gecikme YOK', async ({ page }) => {
    await oyunEkrani(page);
    await page.locator('[data-rack-tile="0"]').tap();
    const b = await hucreKutusu(page, 0, 0);
    await dokun(page, b.x + b.width / 2, b.y + b.height / 2);
    // Ek bekleme YOK: taş çift dokunuş penceresi kadar geciktirilemez.
    expect(await doluMu(page, '0,0')).toBe(true);
    expect(await olcek(page)).toBeCloseTo(1, 2);
  });

  test('harf seçiliyken çift dokunuş: taş KONUR ve KALIR, zoom açılır', async ({ page }) => {
    await oyunEkrani(page);
    await page.locator('[data-rack-tile="0"]').tap();
    const b = await hucreKutusu(page, 0, 0);
    await ciftDokun(page, b.x + b.width / 2, b.y + b.height / 2);

    expect(await olcek(page)).toBeCloseTo(2, 1);
    // Kullanıcı kararı: "taşı geri almadan, koyduğu yerde bırakarak".
    expect(await doluMu(page, '0,0')).toBe(true);
  });

  test('KENARDAN (kareler dışı) çift dokunuş da zoom açar', async ({ page }) => {
    await oyunEkrani(page);
    const vp = (await page.locator('[data-board-viewport]').boundingBox())!;
    const ilk = await hucreKutusu(page, 0, 0);
    // Görünür karenin İÇİ ama hücrelerin DIŞI: 10 px'lik çerçeve dolgusu.
    const x = vp.x + (ilk.x - vp.x) / 2;
    const y = ilk.y + ilk.height / 2;
    expect(x).toBeLessThan(ilk.x); // gerçekten hücre dışında
    await ciftDokun(page, x, y);
    expect(await olcek(page)).toBeCloseTo(2, 1);
  });

  test('ZOOM AÇIKKEN sürükle-bırak nişan alınan kareye iner', async ({ page }) => {
    await oyunEkrani(page);
    // Sol üst köşeye odaklı zoom (hedef hücre görünür kalsın).
    const k00 = await hucreKutusu(page, 0, 0);
    await ciftDokun(page, k00.x + 2, k00.y + 2);
    expect(await olcek(page)).toBeCloseTo(2, 1);

    // Zoom SONRASI konumlar — `boundingBox` transform'u yansıtır.
    const raf = (await page.locator('[data-rack-tile="0"]').boundingBox())!;
    const hedef = await hucreKutusu(page, 1, 1);
    const cdp = await page.context().newCDPSession(page);
    const nokta = (x: number, y: number) => [{ x, y }];
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchStart',
      touchPoints: nokta(raf.x + raf.width / 2, raf.y + raf.height / 2),
    });
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: nokta(raf.x + raf.width / 2, raf.y - 40),
    });
    // Bırakma noktası 30 px KALDIRILIYOR (DRAG_LIFT) — parmak hedefin altına.
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: nokta(hedef.x + hedef.width / 2, hedef.y + hedef.height / 2 + 30),
    });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await cdp.detach();

    // Asıl iddia: `elementFromPoint` transform'u kendisi çözdüğünden taş
    // NİŞAN ALINAN hücreye iner (portta bunun için ayrı geometri gerekmişti).
    expect(await doluMu(page, '1,1')).toBe(true);
  });

  test('hamle puanı rozeti kırpma katmanının DIŞINDA', async ({ page }) => {
    await oyunEkrani(page);
    await page.locator('[data-rack-tile="0"]').tap();
    const b = await hucreKutusu(page, 0, 0);
    await dokun(page, b.x + b.width / 2, b.y + b.height / 2);
    await expect(page.locator('[data-board-badge-layer]')).toHaveCount(1);

    // YAPISAL kanıt: rozet katmanı, kırpan görünür karenin İÇİNDE olmamalı
    // (portta bu hata cihazda görüldü: kenardaki rozetin bir yanı kesiliyor).
    const icerde = await page.evaluate(() => {
      const vp = document.querySelector('[data-board-viewport]');
      const badge = document.querySelector('[data-board-badge-layer]');
      return !!(vp && badge && vp.contains(badge));
    });
    expect(icerde).toBe(false);

    // Ve rozet gerçekten hücre alanının dışına taşıyor olmalı — aksi hâlde
    // bu test hiçbir şey kanıtlamazdı.
    const rozet = (await page.locator('[data-board-badge-layer] > div > div').boundingBox())!;
    expect(rozet.x).toBeLessThan(b.x);
  });
});
