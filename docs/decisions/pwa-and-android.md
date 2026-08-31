# PWA — Servis Çalışanı ve Android Uyumluluğu — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026).

## PWA — Servis Çalışanı Güncellemesi ve Android Uyumluluğu (31 Temmuz 2026)

Kullanıcının Android kullanan bir tanıdığı iki ayrı sorun bildirdi (ekran görüntüsüyle): (1) `color-scheme: light` düzeltmesine (23 Temmuz 2026, bkz. `LogoMark` notundaki FOUT anlatımının hemen öncesi) rağmen sayfa hâlâ siyah zeminle açılıyordu; (2) "Ana Ekrana Ekle" denenince Google Play Protect "Güvenli olmayan uygulama engellendi — bu uygulama Android'in daha eski bir sürümü için geliştirilmiş" uyarısıyla kurulumu tamamen engelliyordu.

- **Siyah zemin — kök sebep gerçek bir güncelleme-engelleme hatasıydı (`src/lib/pwa.ts`):** `registerType: 'prompt'` olduğundan yeni bir sürüm hazır olduğunda sayfa kendiliğinden yenilenmiyor, `tryApplyUpdate()` bunu ne zaman uygulayacağına karar veriyor. Düzeltmeden ÖNCE bu karar `loadGameState() !== null` (yani localStorage'da HERHANGİ bir yarım kalmış Yapay Zeka oyunu var mı) koşuluna bağlıydı — niyeti "oyun sırasında habersizce kesintiye uğratma" idi, ama gerçekte "şu an bu oyunu OYNUYOR muyum" sorusunun çok kaba bir vekiliydi: kullanıcı Setup ekranında dursa, hatta uygulamayı hiç açmasa bile, yarım bıraktığı bir oyun "Devam eden oyunun kalıcılığı" tasarımı gereği günlerce/haftalarca localStorage'da kalabiliyordu — o süre boyunca güncelleme SONSUZA DEK erteleniyordu. Sonuç: sürekli yarım bir oyunu olan gerçek kullanıcılar (bu tanıdık dahil) haftalar sonra bile 23 Temmuz'daki `color-scheme` gibi kritik düzeltmeleri hiç almıyordu. **Düzeltme:** `pwa.ts`'e `setActivelyPlaying(v: boolean)` adında dışa açık bir bayrak eklendi; `App.tsx`'teki yeni bir `useEffect` bunu yalnızca kullanıcı GERÇEKTEN o an bir oyun ekranındayken (`state.phase==='play' && !state.isGameOver` YA DA açık bir Canlı `onlineGame` ekranı) `true` yapıyor — `tryApplyUpdate` artık `loadGameState()` yerine bu canlı bayrağı kontrol ediyor. Yarım kalmış ama o an görüntülenmeyen bir kayıt artık güncellemeyi bloklamıyor.
  **Bu düzeltme geriye dönük olarak "şu an zaten takılı kalmış" kullanıcıları anında kurtarmaz** — onların tarayıcısında hâlâ ESKİ service worker/JS çalıştığından, güncelleme uygulama kararını hâlâ ESKİ (hatalı) mantık veriyor; yeni düzeltme ancak bir kez uygulandıktan SONRA devreye girebilir (tavuk-yumurta). Böyle sıkışmış biri için pratik çözüm: yarım kalan oyunu bitirmek/terk etmek (en geç 7 gün içinde `ABANDON_TIMEOUT_MS` kendiliğinden temizler, bir sonraki visibilitychange/focus/saatlik kontrolde güncelleme uygulanır) ya da tarayıcıda site verisini/önbelleği elle temizlemek.
- **Play Protect "Anladım" engeli — WebAPK'nin hedef Android SDK sürümüyle ilgili, bizim tarafımızdan düzeltilemez:** Chrome'un "Ana Ekrana Ekle"si, kurulabilir bir PWA için gerçek (küçük) bir APK sarmalayıcı (**WebAPK**) üretir — bunu Google'ın kendi WebAPK Minter servisi, CİHAZDAKİ Chrome/Android System WebView sürümüne göre oluşturur. Google Play Protect'in "daha eski bir Android sürümü için geliştirilmiş" uyarısı APK'nın hedef SDK sürümüne bakıyor — bu değer bizim `manifest.webmanifest`'imizden DEĞİL, o cihazdaki WebAPK üretim şablonundan geliyor; site tarafında kontrol edilemez. `vite.config.ts`'teki PWA manifest'i (name/short_name/description/icons 192+512+maskable/display/scope/start_url) baştan sona kontrol edildi, eksik/bozuk bir şey bulunmadı — kurulabilirlik kriterleri zaten sağlanıyordu. Yine de iki küçük, doğru ama muhtemelen bu uyarıyı düzeltmeyecek iyileştirme yapıldı: `id: '/'` eklendi (modern manifest spesifikasyonunun önerdiği, Chrome'un kurulu uygulamayı sürümler arasında doğru tanımasını sağlayan alan) ve `lang: 'tr'` eklendi (öncesinde vite-plugin-pwa'nın varsayılanı olan `"en"` sızıyordu — Türkçe bir uygulama için yanlıştı, `<html lang="tr">` ile tutarsızdı). Bu iki alan zaten olması gereken düzeltmelerdi ama kullanıcıya AÇIKÇA belirtilen sınır şu: **gerçek çözüm o cihazda Chrome/Android System WebView'i Play Store'dan güncellemek** — bu, aynı uyarının başka sitelerde de yaşandığı, yaygın raporlanan bir Chrome/WebAPK altyapı davranışı, Kelimeki'ye özgü değil.


## 31 Ağustos 2026 — Yeni statik sayfa eklendi, denylist güncellenmedi

Kullanıcı `/nasil-oynanir/` yayına girdikten sonra bildirdi: *"Önce setup
sayfası geliyor, birkaç saniye (3-4 belki 5 sn) sonra [kurallar sayfası]
geliyor."*

**Ne olduğu — zincir:** tarayıcısında ESKİ service worker kuruluydu (sayfa
daha var olmadan kurulmuş). O SW'nin precache manifest'inde
`nasil-oynanir/index.html` YOK ve `navigateFallbackDenylist`inde de yok →
gezinme `navigateFallback: index.html`e düşüyor, yani **uygulama kabuğu →
Setup ekranı**. Ardından `setupPwaUpdates()` (`src/lib/pwa.ts`,
`immediate: true`) yeni SW'yi buluyor; kullanıcı o an oyunda olmadığı için
`updateSW(true)` çalışıp sayfayı yeniliyor; yeni SW artık sayfayı precache
ediyor ve doğru içerik geliyor. **3-5 saniye tam olarak SW kurulum +
etkinleşme + reload süresi.** Yani gördüğü şey mevcut kullanıcılar için
TEK SEFERLİK bir geçiş; ikinci ziyarette doğru sayfa anında geliyor.

**Asıl hata ise kalıcıydı ve benimdi:** `vite.config.ts`teki denylist ELLE
yazılmış üç girdi taşıyordu ve dördüncü sayfa eklenirken güncellenmedi.
Bunun sonucu, denylist'in var oluş sebebi olan hatanın aynısı: eğik
çizgisiz `/nasil-oynanir` precache rotasına takılmaz (`directoryIndex`
yalnızca `/` ile biten adresi `index.html`e çevirir), NavigationRoute'a
düşer ve SW kurulu her tarayıcıda SÜREKLİ uygulama kabuğu döner. Aynı şey
`/gizlilik` için 2026'nın başında zaten ÖLÇÜLMÜŞTÜ — o ölçüm dosyanın
yorumunda yazılıydı ve yine de tekrarlandı.

**Ölçüm — sunucu tarafı SUÇLU DEĞİL.** Canlıdan `WebFetch` ile
`https://kelimeki.com/nasil-oynanir` (eğik çizgisiz) ve
`https://kelimeki.com/gizlilik` çekildi: ikisi de DOĞRU statik sayfayı
döndürüyor. `WebFetch` service worker çalıştırmadığından bu, sorunun
tamamen istemci tarafındaki SW'de olduğunu gösteriyor. `vite preview`
üzerinden yapılan ilk deneme yanıltıcıydı: orada `controller: null` çıktı
(SW `registerType: 'prompt'` ile `clientsClaim` YAPMIYOR, ilk yüklemede
sayfayı kontrol etmiyor), yani ölçülen şey preview sunucusunun kendi SPA
fallback'iydi — SW davranışı değil. **Ders: bir SW ölçümünde önce
`navigator.serviceWorker.controller`ı doğrula; null ise ölçtüğün şey SW
değildir.**

**Düzeltme — kural değil MEKANİZMA.** Liste artık elle tutulmuyor:
`src/legal/paths.ts` tek kaynak. `STATIC_PAGE_PATHS` hem `Sayfa.yol`un
birleşim tipini (`render.tsx`) hem `staticPageDenylist()`i (`vite.config.ts`)
besliyor. Yeni bir sayfa listeye girmeden `render.tsx` DERLENMİYOR ve
denylist kendiliğinden büyüyor. Negatif eş koşuldu: beşinci bir sayfa
`paths.ts`e eklenmeden tanımlanınca `tsc` TS2322 ile düşüyor
(`Type '"/sahte/"' is not assignable to ...`). Üretilen `dist/sw.js`te
denylist artık dört desen taşıyor.

⚠ `tsconfig.node.json`un `include`ına `src/legal/paths.ts` eklendi —
`vite.config.ts` ayrı bir composite proje ve o dosyayı aksi halde import
edemiyor (TS6307). Bu yüzden `paths.ts` React/JSX ya da başka bir
bağımlılık TAŞIMAMALI.

**Bunun beklenmedik bir yan etkisi oldu ve ilk commit'e sızdı:** proje
`composite`, yani `tsc` `.js`/`.d.ts` ÜRETİYOR ve `outDir` yoktu — çıktı
kaynağın yanına düşüyor. Kökte bu zaten böyleydi (`vite.config.js` ve
`vite.config.d.ts` .gitignore'a TEK TEK yazılmış), ama `paths.ts` projeye
katılınca emit `src/`in İÇİNE de düştü ve `git add -A` onları aldı.
Projeye dosya eklendikçe .gitignore'a satır eklemek sürdürülebilir değil:
`outDir: "node_modules/.cache/tsc-node"` verildi, artık hiçbir emit kaynak
ağacına düşmüyor. Eski iki .gitignore satırı bayat derlemelerden kalanlar
için bırakıldı.
