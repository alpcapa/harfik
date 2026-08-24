# Karşılama Katmanı — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026). Kaynak: kök CLAUDE.md 'Karşılama Katmanı' bölümleri. Güncel kural CLAUDE.md'de özetlenir; burası tarihli gerekçe/ölçüm arşivi.

## Karşılama Katmanı — Bölüm 2: iskele (18 Ağustos 2026)

Uygulamanın ÖNÜNE, ilk gelen ziyaretçiye gösterilen bir tanıtım/karşılama
katmanı kondu. **Bu bölümde amaç görsel değil: boruyu kurmak ve hiçbir şeyi
kırmadığını KANITLAMAK** — içerik bilinçli olarak yer tutucu (gerçek hikâye/
SEO metni, tahta demosu, logo park efekti, OG kartı Bölüm 3'ün işi).

**Neden var:** 17 Ağustos'ta ölçülen somut boşluk — Google'ın AI Mode'u
Kelimeki'yi "kelime bulucu ve sözlük platformu" diye tamamen uydurdu (bkz.
"Sonraya Bırakılan Ürün Fikirleri" → `/nasil-oynanir`). Sitenin ham HTML'inde
neredeyse hiç metin yok: `index.html` boş bir `#root` gönderiyor, JS
çalıştırmayan crawler'lar hiçbir şey görmüyordu. Katman, ham HTML'e gerçek
metin koyan ilk yüzey.

**Kullanıcının çizdiği sınır (17 Ağustos 2026, sözleri):** *"Mevcut durum
korunmalı… Onlarda değişiklik istemiyorum. İstediğim sadece mevcut yapının
önüne bir tanıtım/karşılama layer'ı koymak. Hatta giriş yapmış kişi bunu hiç
görmesin bile, direkt setup'la başlasın."* Bu yüzden DOKUNULMAYANLAR:
`vercel.json` rewrite'ları, PWA manifest'inin `id`/`start_url`/`scope`/
`display` alanları, service worker'ın `navigateFallback`'i ve
`registerType:'prompt'`, `App.tsx`/`Setup.tsx`/`gameReducer.ts`/`src/game/`/
`src/utils/`, migration/RLS/Edge Function, ve **`mobile/`** (port bu bölümde
HİÇ değişmedi).

**İki bilinçli istisna:** (1) `src/main.tsx`'in ikiye bölünmesi (zorunlu,
aşağı bkz.); (2) `App.tsx`'e `?giris=1` okuyan bir effect — kullanıcı 18
Ağustos'ta açıkça onayladı ("Anladım ok'dir"), emsali `App.tsx`'in zaten
okuduğu `?contact=1`.

### Kapı (gate) — kararı İLK BOYAMADAN ÖNCE veren senkron script

`<head>`'e gömülü ~400 baytlık düz JS (`scripts/landing-plugin.js` →
`kapiScript`). Gövde ayrıştırılmadan çalışır, `<html>`e `uygulama-modu`
sınıfını ekler; `index.css`teki `.uygulama-modu #karsilama{display:none}` ve
`html:not(.uygulama-modu) #root{display:none}` ile katman görünüp KAYBOLMAZ
(FOUC yok). `localStorage` erişimi `try/catch` içinde OLMAK ZORUNDA — gizli
sekmede fırlarsa sayfa hiç boyanmaz.

| Sinyal | Anlamı |
|---|---|
| `location.pathname !== '/'` | Dolaşımdaki `/game/:id` ve `/davet/:token` linkleri — katman ASLA araya girmez |
| `?tanitim=1` | Kurulum ekranındaki ev düğmesinin bilinçli geri dönüşü — aşağıdaki TÜM sinyalleri atlar (Bölüm 3) |
| `kelimeki:seen-intro` | Katmanı bir kez geçmiş (`src/utils/onboarding.ts` → `SEEN_INTRO_KEY`; adı kapıda ELLE tekrarlanıyor, script o modülü import edemez) |
| `kelimeki:game-state` | Yarım kalmış yerel oyunu var |
| `sb-*-auth-token` taraması | Giriş yapmış (proje ref'i sabit yazılmadı — env değişirse kapı yine doğru çalışır) |
| `navigator.standalone` / `display-mode: standalone` | Ana ekrana eklemiş (kurulu PWA doğrudan uygulamaya açılır) |

**`kelimeki:anon-id` BİLEREK listede YOK:** kapı NİYETE bakar, görmeye değil.
Olsaydı hiç oynamadan çıkan bir ziyaretçi ikinci gelişinde "dönen kullanıcı"
sayılırdı — o kimliği misafir-ziyaret pingi zaten ilk ziyarette üretiyor.

### Enjeksiyon neden bir Vite eklentisi (derleme sonrası script DEĞİL)

`playwright.config.ts` duman testlerini `npm run dev` üzerinde koşturuyor.
Yalnızca `dist`e yazan bir çözümde katman dev sunucusunda HİÇ var olmaz; yani
`tests/smoke.spec.ts` onu göremez ve katman tamamen bozukken bile testler
yeşil kalır. `transformIndexHtml` Vite'ın HEM `serve` HEM `build` modunda
çalıştırdığı kanca — doğru yer orası. Katmanın kendisi `.tsx`
(`src/landing/Landing.tsx`) ve Node'da `renderToStaticMarkup` ile HTML'e
çevriliyor; esbuild-paketle-sonra-node deseni bu kod tabanının kendi kalıbı
(`scripts/verify-cloud-save-mirror.ts`). Yeni bir çatı (Next/Astro) EKLENMEDİ.

### `main.tsx` → `main.tsx` + `boot.tsx` (zorunlu ayrım)

`index.html` `main.tsx`'i `<script type="module">` ile çağırıyor, yani paket
`createRoot`'a hiç gelmeden İNİYOR. Katmanı gören ziyaretçiye 0 KB uygulama
JS'i göndermenin TEK yolu import'un KENDİSİNİN dinamik olması. `boot.tsx`
içeriği satır satır eski `main.tsx`'tir (ağaç, sıra, `StrictMode`,
`ErrorBoundary`, path regex'leri); `main.tsx`'te yalnızca fontlar, derleme
kimliği ve kapı kararı kaldı.

**Uygulama modunda `#karsilama` DOM'dan SİLİNİYOR** (yalnızca CSS ile
gizlenmiyor) — Bölüm 3'te içerik büyüyecek, dönen kullanıcının ağacında ölü
bir kopya taşımanın faydası yok.

**ÖLÇÜLEN BULGU — `modulepreload` etiketi statik yazılınca hedefi deliyordu:**
ilk sürüm `<link rel="modulepreload" href="/assets/boot-*.js">`i doğrudan
`<head>`e koyuyordu; ölçüm katmanı gören ziyaretçinin de o parçayı (≈220 KB
gzip) indirdiğini gösterdi. Etiket artık kapı script'inin `g()` dalında,
yani YALNIZCA uygulama modunda ekleniyor. Ölçüm: katman modunda `boot-*.js`
ve `words-*.js` istekleri **0**, service worker kaydı **0**; uygulama modunda
boot TEK ağ transferiyle (preload + dinamik import aynı isteğe düşüyor,
`performance.getEntriesByType('resource')` ile doğrulandı) ~19 ms'de
başlıyor ve service worker normal şekilde kayıtlı (**1**).

### `guest_visits`in artık İKİ yazarı var

Katman modunda `App.tsx` hiç mount edilmediğinden oradaki `logGuestVisit`
effect'i çalışmaz ve admin panelindeki Büyüme > Kullanıcı "M. Ziyaret" serisi
SESSİZCE düşerdi — üstelik tam da o serinin var olma sebebi olan kitle (kayıt
olmadan gelip bakıp giden ziyaretçi) artık hiç sayılmazdı. `main.tsx` bu
insert'i Supabase SDK'sı (54 KB gzip) yerine düz `fetch` ile atıyor: RLS'te
`guest_visits_insert_anon` zaten `anon` rolüne yetkili, anon anahtarı da
paketde/`preconnect`te açık — yeni bir sır ifşası yok. Günde-bir-kez koruması
`visitTracking.ts`in ortak damgasını kullandığından mükerrer sayım olmuyor.
**⚠ Tabloya kolon eklenirse İKİSİ de (`main.tsx` ve `src/lib/api.ts`'teki
`logGuestVisit`) güncellenmeli.**

### Kaydırma mimarisi — gerçek kaydırma kabı `#root`, `body` DEĞİL

`index.css`te `html, body { height:100%; overflow:hidden }` + `body {
position:fixed; inset:0 }`. Yani `#karsilama` da `#root`u AYNALAMAK zorunda
(`height:100%; overflow-y:auto`), aksi halde `position: sticky` başlık
çalışmaz. `overflow-x: hidden` `#karsilama`nın KENDİSİNDE olmalı — iç bir
sarmalayıcıya konsa `overflow-y` `auto`ya hesaplanıp ikinci bir kaydırma
alanı doğar ve sticky yine kırılır.

### Başlık (kullanıcı spesifikasyonu, 18 Ağustos 2026)

*"İlk gelen header'da sağda giriş butonu solda play (OYNA) butonu görecek.
Hatta header'ı kilitle, sayfa altına girsin. Kelimeki logosu da … kaybolduğu
anda oyna ve giriş butonun arasına küçülmüş olarak yerleşsin."* Bu bölümde
yalnızca YAPI kuruldu: kilitli (sticky) başlık + solda OYNA + sağda GİRİŞ +
ortada BOŞ/rezerve bir yuva (`#karsilama-logo-yuvasi`). Logonun oraya park
etme efekti Bölüm 3'ün işi. Buton ölçüleri `UserMenu.tsx`'in akıcı
`clamp()` sabitlerinden DEĞERCE kopyalandı (aynı 375/465 uç noktalı sistem).

**Ölçüldü** (derlenmiş CSS + Chromium, DPR 2, `document.fonts.ready`):
390px'te başlık yüksekliği **40.98** (hedef 41.0 ± 0.5), başlık altı → logo
üstü **0.00** (360/390/834'te ayrı ayrı), orta yuva 265.59px boş, yatay taşma
yok; kaydırmada başlığın üst kenarı 390 ve 834'te **0**'da sabit kalıyor.
`dist/index.html` gzip **9.27 KB** (< 15 KB).

### Regresyon — asıl iş bu

`tests/smoke.spec.ts`e yedi test eklendi: temiz `localStorage`ta katman
görünür + `#root` BOŞ (React hiç mount olmuyor); OYNA → Setup açılır,
`seen-intro` yazılır ve **sayfa yeniden yüklenmez** (geçiş `location.href`
ile değil dinamik import'la); GİRİŞ → giriş penceresi açılır ve `?giris=1`
URL'de KALMAZ; ikinci ziyaret → katman hiç görünmez; `/game/:id` ve
`/davet/:token` → ilgili sayfa render olur, katman görünmez;
`kelimeki:game-state` doluyken katman görünmez. Mevcut üç test kendini
"dönen kullanıcı" olarak işaretliyor (`donenKullanici` yardımcısı) — aksi
halde artık katmanı görürlerdi.

**Negatif eş kuruldu (iki ayrı tur):** (a) kapının `pathname` ve
`seen-intro||game-state` koşulları kapatılınca **7 test** düştü — dördü yeni,
üçü MEVCUT uygulama testleri (yani onlar artık gerçekten kapıya bağlı);
(b) katman HTML'inin gövdeye enjeksiyonu kaldırılınca **4 test** düştü.
İkisi de geri alınınca 10/10 yeşil.

**Doğrulanan non-regresyonlar (ölçüldü, varsayılmadı):**
`dist/manifest.webmanifest` değişiklik öncesiyle **bayt bayt aynı**;
`navigateFallback` hâlâ `createHandlerBoundToURL("index.html")`; `vercel.json`
diff'i **sıfır**; precache 17 → 18 girdi ve fark yalnızca bilinçli JS parça
bölünmesi (`index-*.js` → `index-*.js` + `boot-*.js`).

**Doğrulama sınırı:** `display-mode: standalone` bu ortamdaki Chromium'da
CDP ile emüle EDİLEMİYOR (denendi, `matchMedia` hep `browser` diyor) — kapının
PWA dalı, kapıdan ÖNCE koşan bir init script'iyle `matchMedia`/
`navigator.standalone` sahtelenerek doğrulandı (üçü de uygulama moduna geçti).
Gerçek kurulu bir PWA'da teyit cihazda yapılmalı; `TESTING.md` bölüm 1'e
madde eklendi.

## Karşılama Katmanı — Bölüm 3: içerik ve efekt (18 Ağustos 2026)

Bölüm 2 boruyu kurmuştu; içerik bilinçli olarak yer tutucuydu. Kullanıcı aynı
gün üç eksik bildirdi (sözleri): *"1. Oyna butonu giriş butonu ile aynı
yükseklikte olmalı. 2. Scroll edince kelimeki logosu küçülüp headera
yerleşmiyor. 3. Tanıtım alanı sadece düz text'den ibaret. Oranın tasarımı
yapılmalı, görsellerle desteklenmeli."* Bölüm 3 bu üçünü kapatıyor.
Bölüm 2'nin DOKUNULMAYANLAR listesi aynen geçerli — bu bölümde de
`vercel.json`, PWA manifest'i, service worker ayarları, `App.tsx`/`Setup.tsx`/
`src/game/`/`src/utils/`, migration/RLS/Edge Function ve **`mobile/`** HİÇ
değişmedi (ölçüldü, aşağı bkz.).

### 1) İki başlık düğmesi — sorun yükseklik DEĞİL gölge ağırlığıydı

ÖLÇÜLDÜ (derlenmiş CSS + Chromium, 320/360/390/834/1194): iki düğmenin kutusu
zaten BİREBİR aynıydı — 27.38 / 27.38 / 28.98 / 37.00 / 37.00 px, ikisi de
`top: 12`, aynı `font-size`/`padding`/`border-width`. Gözle görülen fark
Bölüm 2'de GİRİŞ'e verilen `btn-raised-neutral`ın hafif gölgesi ile OYNA'nın
`btn-raised` ağır gölgesi arasındaydı (piksel taramasıyla görsel ayak izi
39.67 vs 33.67 px çıkmıştı). Düzeltme GİRİŞ'i `btn-raised bg-accent
border-accent text-white`e çekmek — bu aynı zamanda **uygulamayla pariteyi
geri getiriyor**: `UserMenu.tsx:145`'teki gerçek GİRİŞ düğmesi de accent/mavi.
Yani Bölüm 2'deki nötr çizim sessiz bir sapmaydı.

**Ders:** "aynı yükseklikte değil" bir teşhis değil bir SEMPTOM — kutuyu
ölçmeden gölgeye/paletle ilgili bir farkı yükseklik sanmak kolay.

**Aynı gün ikinci tur — başlıktaki OYNA tamamen KALKTI (kullanıcı isteği):**
*"Sayfanın üstünde büyük Hemen Oyna butonu olduğu için header'ın sağındaki
Oyna butonu gereksiz oldu."* Şeritte artık yalnızca GİRİŞ var; logo yuvası
`flex-1` olduğundan logo GİRİŞ'ten arta kalan alanın ortasında duruyor.
Aynı turda şeride ALT boşluk verildi (`pt-3` → `py-3`) — GİRİŞ düğmesi
şeridin alt kenarına değiyordu. **Ölçüldü:** şerit 39.38/40.98/49 →
**51.39/53.00/61.00** px (320/390/834); kaydırmada üst kenar hâlâ 0'da
sabit, "şerit altı → kahraman logo üstü" hâlâ **0.00** (aradaki nefes artık
şeridin KENDİ alt dolgusundan geliyor, bu yüzden değişmez bozulmadı).

### 2) Logo park efekti — eşik SABİT DEĞİL, görünürlük izleniyor

Kullanıcının Bölüm 2'de tarif ettiği efekt (*"logo … kaybolduğu anda oyna ve
giriş butonun arasına küçülmüş olarak yerleşsin"*) artık çalışıyor. Küçük
kopya şeridin ORTA yuvasında **her zaman HTML'de var**; yalnızca görünürlüğü
CSS'te (`#karsilama-logo-yuvasi > svg` → `opacity/transform`,
`.logo-parkli` ile açılıyor, `prefers-reduced-motion` guard'lı).

Tetikleyici `main.tsx`'teki `logoParkiKur()`: bir `IntersectionObserver`
kahraman logoyu (`#karsilama-logo`) izliyor.
- **`root` belge DEĞİL `#karsilama`** — bu sayfada belge hiç kaydırılmıyor
  (`body { position: fixed; overflow: hidden }`), varsayılan viewport köküyle
  gözlemci hiçbir zaman tetiklenmezdi.
- **`rootMargin` çalışma zamanında şeridin `offsetHeight`'inden okunuyor**;
  sabit bir kaydırma eşiği YANLIŞ olurdu, çünkü şerit yüksekliği akışkan
  (39.38 → 49 px arası ölçüldü) ve Bölüm 2'de ölçülen "şerit altı → logo üstü
  = 0.00 px" değişmezi eşiği tamamen şeridin boyuna bağlıyor.
- Pencere yeniden boyutlandırılınca gözlemci baştan kuruluyor (`rootMargin`
  bir kez okunan bir sayı, `vw` tabanlı yükseklikte bayatlar).

**Park eden logo GİRİŞ düğmesiyle TAM AYNI yükseklikte** (kullanıcı isteği,
aynı gün ikinci tur: *"kelimeki logosunu giriş butonuna eşit yüksekliğe
çekebiliriz"*). Sabit piksel YAZILMIYOR — düğmenin kendi akışkan
formülünden türetiliyor: `calc(2 × dikey dolgu + punto + 2px)`. Ölçüldü,
üç genişlikte de düğmeyle birebir: **27.38 / 28.98 / 37.00** px (ölçüm
`getBoundingClientRect` ile yapılırsa park etmemiş hâlin `scale(0.9)`unu
hesaba kat — ham değerler 24.65/26.10/33.30 çıkar). `GIRIS_*` sabitleri
değişirse logo kendiliğinden takip eder.

### 3) İçerik — gerçek `Board.tsx` ile tanıtım tahtası

Sayfa artık kahraman + rakam şeridi + **canlı tahta** + üç adımlık "Nasıl
oynanır" + altı özellik kartı + dokuz k-lig rütbesi + SSS + son çağrıdan
oluşuyor. İki tasarım kararı kayda değer:

- **Tahta bir ekran görüntüsü ya da elle çizim DEĞİL** — üretimdeki
  `GameBoardPreview` → `Board` (`hideFooter`, **`compact={false}`**) sunucuda render ediliyor
  (`src/landing/demoBoard.ts` yalnızca taşları veriyor). Köşe tonlaması, bölge
  dış hattı, X2 bölgesi ve X3 hücresi tek kaynaktan geliyor; ikinci bir tahta
  çizimi bu kod tabanının en sık tekrarlayan hata sınıfını (sessiz ayrışma)
  büyütürdü.

  **`compact` KAPALI (18 Ağustos 2026, kullanıcı bildirdi):** İlk sürüm
  `GameBoardPreview`'ın varsayılanını (`compact`) kullanıyordu ve o mod tam
  olarak filigranları kısıyor — köşelerdeki büyük "1/2/3/4" oyuncu numarası,
  merkezdeki büyük "X2" ve ortadaki hücrenin "X3" etiketi, artı taşların puan
  üst simgesi. Kullanıcının sözleri: *"Tanıtımda 2 veya 4 kişilik oyun
  görsellerinde watermark'lar yok. Oyunun birebir aynı görüntüsü olmalı."*
  Haklıydı: katmanda tahta bir "önizleme" değil oyunun VİTRİNİ, gerçek oyunda
  görünen her şey görünmeli. `GameBoardPreview`'a opsiyonel bir `compact`
  prop'u eklendi — **varsayılanı `true`**, yani iki eski kullanım yeri
  (`GameHistoryModal` kart açılımı, `SharedGamePage`) hiç değişmedi; yalnızca
  `Landing.tsx` `false` geçiyor. `Board.tsx`'e DOKUNULMADI (`compact` orada
  zaten bir prop'tu).

  **AYNI GÜN İKİ KEZ YANLIŞ FONT — ve kök sebep font DEĞİL GENİŞLİKTİ.** Bu,
  bu bölümdeki en pahalı hata; sırayla: (1) `compact`'i kapatınca kullanıcı
  *"harf fontları çok büyük kullanmışsın… Sadece filigranı düzelt dedim"*
  dedi — çünkü `compact` TEK bir bayrakla ÜÇ şeyi birden yönetiyor (taş harf
  puntosu, puan üst simgesi, filigranlar); (2) puntoyu kısınca bu sefer
  *"küçük oldu, normal oyundaki gibi olmalı"* geldi. Doğru teşhis ancak
  ÖLÇÜNCE çıktı: `Tile.tsx` harfi `vw` tabanlı bir `clamp()` ile çiziyor ama
  hücre boyu KABIN genişliğinden türüyor — yani aynı `clamp()` dar bir kapta
  orantısız görünür. Katmanın tahtası o sırada metin sütununun
  (`max-w-[460px] px-4`) içindeydi ve 390px'te **334px**'e düşüyordu, gerçek
  oyun ekranı ise **366px** (`max-w-[680px] px-3`); harf/hücre oranı 0.58 ve
  küçültülmüş sürümde 0.36 iken oyunun kendi oranı 0.53'tü. **Düzeltme
  fontta değil düzende:** tahta bölümü metin sütununun DIŞINA, kendi
  `max-w-[680px] px-3` sarmalayıcısına alındı ve kaydırma şeridine `-mx-3`
  verildi (şerit o dolgudan çıkıp tahtanın kendi kutusunu kullanabilsin
  diye). **Ölçüldü** (derlenmiş CSS + Chromium, DPR 2, `document.fonts.ready`,
  `http://` üzerinden — `file://` mutlak asset yollarını çözemediğinden TÜM
  puntoları 16px okur, ilk ölçüm turu tam bu yüzden çöpe gitti): 390px'te
  tahta **366.00** px / hücre 28.2 / harf **14.82** / puan üst simgesi 6.24;
  834px ve üstünde **656.00** / 24 / 10 — üçü de gerçek oyun ekranıyla
  birebir. Yatay taşma 320/390/834/1194'te **0**. Maliyet: `dist/index.html`
  ham **252.264** bayt / gzip **21.732**.

  **Tahta GENİŞ kalıyor, yalnızca METİN daraltıldı (18 Ağustos 2026,
  kullanıcı sordu: yatay tablette bu bölüm "diğer bölümlerden büyük"
  duruyordu, mobilde normaldi).** Ölçüldü ve sorunun tahta OLMADIĞI çıktı:
  834/1194px'te bölüm başlığı öteki bölüm başlıklarından **114px sola**
  taşıyordu ve tahta altı açıklamalar 680px genişlikteydi (öteki gövde
  metni 428px) — çünkü yukarıdaki düzeltme `<Bolum>`un TAMAMINI 680'lik
  kaba almıştı. Tahtayı daraltmak YANLIŞ olurdu (aynı font hatasını geri
  getirirdi) ve zaten istenen de o değildi: geniş görsel + dar metin
  standart bir karşılama sayfası deseni. Düzeltme yalnızca metinde —
  `Bolum`a opsiyonel `baslikClassName` eklendi ve başlık/açıklama/legend
  `max-w-[428px] mx-auto` aldı (428 = `max-w-[460px]` eksi `px-4`, yani
  öteki bölümlerin metin genişliğinin AYNISI). **Ölçüldü:** 834'te başlığın
  sol kenarı 89 → **203**, 1194'te 269 → **383** — üç bölüm de birebir aynı;
  tahta 366/656 ve harf 14.82/24 DEĞİŞMEDİ. Mobilde fark 4px (tahtanın
  `px-3`ü ile metnin `px-4`ü arasındaki doğal fark) — zaten öyleydi,
  görünmüyor.
  **Yakalanan tuzak:** açıklama `<p>`lerindeki satır içi `style={{margin:0}}`
  `mx-auto` sınıfını EZİYORDU (satır içi stil her zaman kazanır), paragraf
  428'e daralıyor ama SOLA yaslı kalıyordu — `marginTop/marginBottom: 0`a
  çevrildi. Aynı satırdaki legend `<ul>`de satır içi stil olmadığı için
  doğru çalışıyordu, fark tam da bu yüzden ölçümde görüldü.

  **Ders:** iki platform ya da iki ekran arasında "font yanlış görünüyor"
  şikâyetinde önce KABIN genişliğini ölç — `vw` tabanlı bir `clamp()` iki
  farklı genişlikte aynı değeri üretmez, ve punto ile oynamak semptomu
  kovalayıp asıl farkı gizler. Aynı ilkeyle rütbeler gerçek `RankSeal` +
  `RANK_TIERS`, mini şemaların renkleri `PLAYER_COLORS`.

  **Tahta altı açıklamalar ORTALI, legend tek satırda akıyor (aynı gün,
  kullanıcı isteği: *"bu resimlerin altındaki yazılar sola yapışmış. Ortala
  hepsini."*):** iki tahtanın altındaki açıklama paragrafları `text-center`
  aldı; bunların altındaki renk legend'ı `grid grid-cols-2`den
  `flex flex-wrap items-center justify-center` + öğe başına `shrink-0`'a
  geçti — sabit iki sütun geniş ekranda ortada değil solda kalıyordu, sarma
  ise dar ekranda kırılmadan çalışıyor.
- **İKİ tahta, yan yana kaydırmalı (aynı gün ikinci tur, kullanıcı isteği):**
  2 kişilik ve 4 kişilik. **Kaydırma tamamen CSS** — `overflow-x-auto` +
  `snap-x snap-mandatory`, her görsel `w-full`. `main.tsx` YALNIZCA alttaki
  iki noktayı güncelliyor (`tahtaNoktalariKur`); o kod hiç çalışmasa bile
  şerit kaydırılabilir kalır, nokta bir bağımlılık değil göstergedir.
  Şeride `py-2 -my-2` veriliyor: bir eksende `overflow-x: auto` olan bir kap
  dikeyde de kırpar, yani tahtanın gölgesi payı olmadan kesilirdi (dış ölçü
  değişmiyor). 4 kişilik tahta "3 rakibe karşı" mesajını taşıyor ve
  doğrulayıcı her koltuğun GERÇEKTEN dolu olduğunu ayrıca kontrol ediyor —
  boş bir köşe o mesajı sessizce yalanlardı.
- **İki tahta da OYUN ORTALARINDA (üçüncü tur, kullanıcı isteği: "her oyuncu
  orta kareye girmiş ve oyun daha ilerlemiş … 1-2 rakip bölgeye değen hamle
  koy"):** boş bir açılış tahtası ne bölge genişlemesini ne de sınır
  ihlalini gösterebiliyordu. 2 kişilikte 1. oyuncu merkezi geçip `NAİL` ile
  RAKİBİN 4×4 bloğuna giriyor (52 taş); 4 kişilikte DÖRT oyuncu da merkez
  bölgeye uzanıyor ve iki temas noktası var — `ATAMAN` (2. oyuncunun A'sı +
  1. oyuncunun N'si) ve `KIRK` (3. oyuncunun K'si + 4. oyuncunun IRK'ı),
  yani vergiyi doğuran durum tahtada GÖRÜNÜYOR (70 taş).
  **Tahtalar elle çözülmedi:** `node_modules/.cache/…/solver.ts` benzeri bir
  arama betiğiyle, her aday kelime TÜM tahtaya karşı doğrulanarak seçildi —
  kesişmelerin ürettiği kaza kelimeleri (ör. `İS`, `LE`, `AN`) ancak böyle
  görülüyor. Sonuç yine `npm run verify-demo-board` ile kilitli.
- **İZOLE (bağımsız) hamleler — dördüncü tur, kullanıcı isteği: "bölge
  dışında diğer oyuncular tarafından eklenmiş 3-4 bağımsız hamle de
  gösterelim".** Her tahtada, sahibinin KENDİ zincirine bağlı OLMAYAN 4
  hamle var (2 kişilikte 9, 4 kişilikte 8 taş). Bu, kuralın gözle görülmesi
  en zor yüzü: rakip bölgeye konan ama kendi zincirine BAĞLANMAYAN bir taş o
  kareyi ELE GEÇİRMEZ — kendi rengini korur, kare rakibin tonlamasında kalır.
  Tahtada bu, "rakip tonlamasının üstünde duran yabancı renkli taş" olarak
  görünüyor ve `Board.tsx` bunu zaten doğru çiziyor (ayrı bir kod gerekmedi).
  Taşlar `*_BAGIMSIZ` listelerinde AYRI duruyor; doğrulayıcı bağlantısızlığı
  **İKİ YÖNLÜ küme eşitliğiyle** sınıyor — ana zincirden kopan bir taş da,
  yanlışlıkla zincire yapışıp artık izole OLMAYAN bir "bağımsız" taş da hata
  verir. **Negatif eş:** bir izole bildirimini kaldırmak 2, ana zincirdeki
  bir kelimeyi izole diye bildirmek 3 hata üretti.
- **Tahtanın kelimeleri ÖLÇEREK doğrulanıyor:** `npm run verify-demo-board`
  ≥2 uzunluktaki TÜM yatay/dikey dizilimleri `src/data/words.ts`e karşı sınar,
  ayrıca her oyuncunun taşlarının EV karesinden ortogonal bağlı olduğunu
  (yoksa bölge dış hattı sessizce eksik çizilirdi) kontrol eder. Kesişen
  kelimelerin ürettiği "kaza kelimeleri" tam olarak gözle KAÇIRILAN şey.
  Negatif eş: bir harfi bozmak 3, bir kelimeyi kopartmak 2 kontrol düşürüyor.
- **Joker taşı BİLEREK YOK:** `Tile.tsx` jokeri ayrı çizmiyor (yalnızca puanı
  0) ve `compact` modda puanlar hiç gösterilmiyor — denendi, ekran
  görüntüsünde normal taştan ayırt edilemedi, yani hiçbir şey anlatmıyordu.

**"Neler var" altı kutusunun ikonları (`src/landing/OzellikIkonlari.tsx`,
18 Ağustos 2026, kullanıcı isteği: "6 kutuya uygun ikonlar koyalım. Başlığın
hemen yanına minik, yazı kadar."):** Başlığın SOLUNDA, 13px (başlık
`text-[12px]`, yani "yazı kadar"), `text-accent`. Hizalama `items-start` +
1px nudge — `items-center` DEĞİL: 390px'te kart iç genişliği ~151px ve altı
başlıktan beşi iki satıra sarıyor, ortalanan ikon o iki satırın arasına
düşüp ilk satırla bağını koparıyordu.

**İkonlar `RelationIcons.tsx`'e EKLENMEDİ ve bu bilinçli.** Oradaki kural
("path'i kopyalama, buraya ekle") Material glyph'lerinin Flutter portuyla
BİREBİR aynı vektör olmasından doğuyor; bu altı ikon ise Material DEĞİL.
**Bu satır bir dönem "portta karşılığı yok ve olmayacak" diyordu — 19 Ağustos
2026'da GEÇERSİZLEŞTİ:** kullanıcı portun tanıtım ekranının "webin aynısı
(6 kutu)" olmasını isteyince ikonlar `mobile/app/lib/src/ui/intro/
ozellik_ikonlari.dart`'a `CustomPainter` olarak taşındı (yine `Icons.*`
DEĞİL — port `Icons.*` kullansaydı iki platform FARKLI vektör çizerdi).
İki dosya ELLE SENKRON — **21 Ağustos 2026'dan beri `icon_parity_test.dart` ikisini de kanonik bir çizim listesine indirgeyip karşılaştırıyor** (Parça 128), yani sessiz ayrışma artık CI'da düşer. O test yazılırken **gerçek bir sapma buldu:** web noktaları `<circle r="0.6" fill stroke-width="1.6">` ile, yani BOYANAN yarıçap 1.4 ile çiziyordu; port dolu daireyi 0.9 ile çiziyordu (13px ikonda 1.52 px'e karşı 0.98 px). Ölçülerek doğrulandı ve port düzeltildi. Material path'lerini hafızadan
yazmak ise bu kod tabanında bir kez denenip yanlış glyph üretmişti ve bu
ortamda çıkarılacak bir `MaterialIcons-Regular.otf` yok — o yüzden ikonlar
ilkel şekillerden (daire/dikdörtgen/çizgi/yay) kurulup gerçek Chromium
render'ıyla gözle denetlendi (390 ve 834 px, DPR 3). **Ölçüldü:** SVG kutusu
iki genişlikte de 13×13, başlıkla arası 6px, yatay taşma 0; wifi-off ikonu
ilk turda okunmaz çıktı (yaylar parçalıydı), tek merkezli iki temiz yaya
çevrildi. Maliyet ham +2.7 KB / gzip +0.42 KB (yukarıdaki bütçe satırı buna
göre güncellendi).

**Logo sprite'ı (`src/landing/LandingLogo.tsx`) — ÖLÇÜLMÜŞ bir zorunluluk:**
`LogoMark` her çağrıda 11.760 baytlık path verisini yazıyor ve logo sayfada üç
yerde geçiyor; gzip kopyaları BİRLEŞTİREMİYOR (aralarındaki mesafe deflate'in
32 KB penceresini aşıyor). Ölçüldü: üç kopya `dist/index.html`in gzip
boyutunun **10.377 baytını** yiyordu. Path bir kez `<defs>`e konup diğerleri
`<use>` ile bağlanınca sayfa **21.13 → 15.84 KB gzip**e düştü. Vektör hâlâ
TEK KAYNAKTA (`LogoMark.tsx`in dışa açtığı sabitler; o dosya
`generate-logo-paths.mjs` tarafından üretiliyor) — uygulama tarafı bu sprite'ı
KULLANMAZ, orada logo tek kez çiziliyor.

**Sayfa bütçesi — güncel ölçüm (18 Ağustos 2026, metin turu + sayfa sonu
GİRİŞ düğmesinin kaldırılmasından SONRAKİ nihai değer): `dist/index.html`
ham **254.8 KB** / **gzip 22.29 KB**.** (21 Ağustos 2026'da yedinci SSS maddesi +781/+30 bayt ekledi. Bu gzip rakamı 19 Ağustos 2026'da
yeniden ölçüldü: en üst rütbenin adı Tanrı→Kozmik olunca ham 8 bayt DÜŞTÜ ama
gzip 126 bayt ARTTI — iki kelimenin sıkıştırma sözlüğündeki farkı; içerik
olarak değişen tek şey iki metin.) Aynı gün üç ara ölçüm daha yapıldı,
sırasıyla: özellik ikonları eklendikten sonra ham 255.0 KB / gzip 22.15 KB
(tek tahtalı ilk sürüm 130.8 KB / 15.84 KB idi; ikinci tahta
~3.2 KB, iki tahtanın dolulaşması + izole hamleler ~0.6 KB, filigran/puan üst
simgesi ~0.6 KB, altı özellik ikonu 0.42 KB gzip ekledi — sonuncusu
öncesi/sonrası iki ayrı derlemeyle ölçüldü: 252.264/21.730 → 254.958/22.147
bayt); rütbe rozeti roset tasarımına geçince ham 254.1 KB / gzip 22.25 KB
(ham −814 / gzip +103); font M PLUS Rounded 1c'ye çevrilince 254.1 KB /
22.25 KB (değişmedi). **Bu rakam ölçülürken
`dist`i `http://` üzerinden aç** — `file://` mutlak asset yollarını
çözemediğinden ölçüm sessizce yanlış çıkar.
Bölüm 2'nin "< 15 KB" notu yer tutucu içeriğe göre yazılmıştı; gerçek içerikle
kırılım şu — logo 5.2 KB, tahta 3.3 KB, rütbe mühürleri 0.3 KB, kalan metin/
düzen ~7 KB. Karşılaştırma: katmanı gören ziyaretçi bugün toplam ~25 KB gzip
indiriyor (HTML + CSS + minik giriş JS'i), uygulamanın kendisi 410 KB.

### Geri dönüş — kurulum ekranındaki ev düğmesi

Kullanıcı (18 Ağustos 2026): *"Hemen Oynaya basınca geri gelemiyorsun."*
Katman `gec()` içinde DOM'dan SİLİNİYOR (Bölüm 2 kararı), yani geri dönmek
bir React geçişi değil TAM BİR YENİDEN YÜKLEME gerektiriyor — ve o noktada
`seen-intro` yazılmış olduğundan kapı kullanıcıyı doğrudan uygulamaya alırdı.
Bu yüzden kapıya TEK bir kaçış deliği eklendi: **`?tanitim=1`**, öteki tüm
dönen-kullanıcı sinyallerini (seen-intro / yarım oyun / oturum / PWA) bilerek
atlar. `gec()` geçişte URL'yi HER durumda temizlediğinden bir sonraki
açılışta yine uygulamaya düşülür — parametre yapışkan değil.

Düğme `App.tsx`'in kurulum başlığında, sol uçta: gri bir ev ikonu. **Vektör
`Board.tsx`'ten geliyor** (`HOME_MARK_PATH`, oradaki köşe "ev karesi"
işaretinin AYNISI) — path kopyalansaydı iki ev sessizce ayrışırdı
(`RelationIcons` ile aynı ilke). Satırın sağ tarafı DEĞİŞMEDİ: `UserMenu`
girişsizken GİRİŞ, girişliyken avatar menüsünü çiziyor (`justify-end` →
`justify-between`).

### Şeritteki logo TAM ORTADA — `flex-1` yetmiyor

Kullanıcı (18 Ağustos 2026, üçüncü tur): *"Kelimeki logosu header'da tam
ortalı durmuyor."* Doğru: yuva `flex-1` iken logo, şeridin GİRİŞ
düğmesinden ARTA KALAN alanının ortasında duruyor — yani sayfanın gerçek
ortasının (GİRİŞ genişliği + boşluk) ÷ 2 kadar solunda. Yuva
`absolute inset-0 … justify-center pointer-events-none` yapıldı, GİRİŞ
`ml-auto` ile sağda kaldı.

**Ölçüldü** (derlenmiş CSS + Chromium, 320/390/834): logonun yatay merkezi
şeridin merkeziyle ve KAHRAMAN logonun merkeziyle birebir aynı
(160 / 195 / 417); park hâlinde logo yüksekliği GİRİŞ'le birebir
(27.39/27.38 · 29.00/28.98 · 37/37) ve dikey merkezleri de eşit; şerit
yüksekliği DEĞİŞMEDİ (yalnızca düğme belirliyor, logo mutlak konumda).
En dar ekranda logo ile GİRİŞ arası 62.6 px — çakışma yok.

### Buton bağlama sözleşmesi (yeni)

Sayfada İKİ "Oyna" (kahraman + sayfa sonu), TEK "Giriş" (yalnızca şeritte —
sayfa sonundaki ikinci GİRİŞ 18 Ağustos 2026'da kullanıcı isteğiyle
kaldırıldı; `Giris` bileşeni de tek tüketicisi kalmadığı için silindi,
`noUnusedLocals` zaten derlemede yakalardı) ve İKİ hukuki bağlantı var. `main.tsx` hepsini ÖZNİTELİKLE bağlıyor:
`data-kelimeki-oyna` / `-giris` / `-kosullar` / `-gizlilik` — **yeni bir
düğme eklerken id değil bu öznitelik verilmeli**, aksi halde düğme sessizce
ölü kalır. Şeritteki GİRİŞ ayrıca `id="karsilama-giris"` taşıyor
(`tests/smoke.spec.ts` onu id ile buluyor).

**"Paylaş" (`data-kelimeki-paylas`, 18 Ağustos 2026) BAŞKA BİR MEKANİZMA
KULLANIYOR — yukarıdaki dördüyle karıştırma.** O dördü `bagla()` üzerinden
`gec(niyet)`i çağırıp uygulamaya GEÇİYOR (`?kosullar=1` gibi bir parametreyle);
"Paylaş" ise `main.tsx`'teki AYRI `paylasiKur()` fonksiyonuyla bağlanıyor ve
uygulamaya HİÇ geçmiyor — `shareKelimekiLink()`i (`src/utils/shareLink.ts`,
Setup.tsx'in KENDİ "Paylaş" linkiyle AYNI fonksiyon, `?ref=arkadas` etiketinin
tek üreticisi) doğrudan katman modundayken çağırıp native paylaşım/panoya
kopyalamayı orada açıyor. Butonun içindeki metin `<span data-kelimeki-paylas-metin>`
içinde ayrı duruyor — `paylasiKur()` kopyalama sonrası yalnızca o span'in
metnini 2 saniyeliğine "Link kopyalandı!" yapıyor, düğmenin TAMAMINA
`textContent` yazmak yanındaki `ShareIcon` SVG'sini de silerdi.

**Hukuki bağlantılar neden köprüden geçiyor:** Kullanım Koşulları/Gizlilik
pencereleri `Setup.tsx`'in kendi state'inde yaşıyor ve katman React ağacının
DIŞINDA (statik HTML) — dolayısıyla katmandan açılamıyorlar. Düğmeler
`?kosullar=1` / `?gizlilik=1` ile uygulamaya geçiriyor; `App.tsx` bunu
`?giris=1`/`?contact=1` ile BİREBİR aynı kalıpta okuyup pencereyi kendisi
render ediyor ve parametreyi `history.replaceState` ile temizliyor. Üç
parametre TEK effect'te okunuyor — aynı anda yalnızca biri gelebilir ve
hepsi tek bir `replaceState` ile silinmeli.

### Regresyon

`tests/smoke.spec.ts` 10 → **15 test**: (a) sayfa sonundaki OYNA da uygulamaya
geçiriyor ve sayfada tam 2 `[data-kelimeki-oyna]` var (öznitelik sözleşmesini
koruyor); (b) tepede `logo-parkli` YOK ve park kopyası `opacity: 0`,
kaydırınca ikisi de dönüyor, geri çıkınca geri alınıyor (tek yönlü bir bayrak
değil); (c) kurulum ekranındaki ev düğmesi katmana geri döndürüyor ve
sonraki geçişte `?tanitim=1` URL'den siliniyor; (d) hukuki bağlantı doğru
pencereyi açıyor ve parametre temizleniyor; (e) tahta şeridi iki görsel + iki
nokta taşıyor ve kaydırınca aktif nokta değişiyor. **Negatif eş — beşi de
ayrı ayrı düşürüldü:** seçici id'ye çevrilince, `logoParkiKur()` kaldırılınca,
kapının `?tanitim=1` dalı silinince, `setLandingLegal` kaldırılınca ve
`tahtaNoktalariKur()` çağrısı kaldırılınca ilgili testler GERÇEKTEN düştü.

### Doküman denetimi — README/`.md` turu (19 Ağustos 2026)

Kullanıcı sordu: *"Readme ve tüm md'ler güncel mi?"* Altı `.md` dosyası
(kök `CLAUDE.md`, `README.md`, `TESTING.md`, `PORT_BRIEF.md`,
`mobile/CLAUDE.md`, `mobile/TESTING.md`) koda karşı tarandı. **En değerli
bulgu bir eksik değil, bir YANLIŞTI:**

- **`README.md`'deki bölge vergisi payı YANLIŞTI** — *"iki farklı bölgeyle
  birden etkileşirse üç kişi eşit paylaşır: herkese 1/3"* diyordu; motor
  (`computeInvasionSplit`) n=2'de payı `basePts*(n+1)/(6n)` = **1/4** yapıp
  oynayana **1/2** bırakıyor. Yani README yıllardır kuralı yanlış anlatıyordu
  ve bu, `CLAUDE.md`/`HelpModal`'ın ikisiyle de çelişiyordu (ikisi doğruydu).
  Genel formülle birlikte düzeltildi.
- `README.md`'de **üretilmiş dosya komutları hiç yoktu** (`generate-logo-paths`,
  `generate-klig-paths`, `generate-icons`, `generate-og-image`,
  `generate-golden-vectors`, `generate-meanings-db`). Tam bu boşluk 17 Ağustos'ta
  `og-image`'ın haftalarca bayat kalmasına yol açmıştı — artık ikisinde de var.
- `README.md` ağacına `shareLink.ts`, `CLAUDE.md`'nin utils satırına
  `shareLink`/`pendingLiveGames`, komut tablosuna `npm run preview` eklendi;
  `web-ci.yml` adım özeti `verify-remaining-tiles`i atlıyordu.
- **`PORT_BRIEF.md` DONDURULDU.** 5 Ağustos'ta port planlaması için bir kez
  çıkarılmış bir envanter; bugün `src/` altında orada geçmeyen **19 dosya**
  var (karşılama katmanı, k-lig ödül/rütbe katmanı, `cloudSaveMirror`,
  `offlineNotice`, `platform`, `shareLink`…). Güncellemek yerine başına
  "donmuş anlık görüntü, yaşayan doküman değil, güncel yapı için README/
  CLAUDE.md'ye bak" uyarısı kondu — LOC tablosunu her değişiklikte tazelemek
  sürdürülebilir değil, ama sessizce yanlış kalması da kabul edilemezdi.
- **Temiz çıkanlar:** `TESTING.md` (bölüm 11'e kadar güncel — 15 Ağustos'taki
  "mute yalnızca popup'ı bastırır, rozet yine artar" kararı bile maddeye
  yazılmış), `mobile/TESTING.md`, `mobile/CLAUDE.md`, README'nin kelime sayısı
  (**~63 bin**; `words.ts` gerçekte 63.896) ve k-lig rütbe/ödül tablosu.

**Ders:** bir doküman "eksik" olabilir (yeni dosya listeye girmemiş) ya da
"yanlış" olabilir (kuralı hatalı anlatıyor) — ikincisi çok daha pahalı ve
yalnızca metni KODA karşı okuyarak bulunuyor; dosya listesi karşılaştırması
onu asla yakalamaz.

**Doğrulanan non-regresyonlar (ölçüldü):** katman modunda `boot`/`words`
istekleri **0** ve service worker kaydı **0**, uygulama modunda sırasıyla 1/1/1;
`vercel.json` diff'i **sıfır**; `navigateFallback` hâlâ
`createHandlerBoundToURL("index.html")`; manifest `id`/`start_url`/`scope`
aynı; precache 18 girdi; 320 px'te yatay taşma **0**; kaydırmada şeridin üst
kenarı beş genişlikte de **0**'da sabit. `mobile/` altında **sıfır**
değişiklik.

**BİLİNÇLİ OLARAK YAPILMAYAN — SSS'teki "Uygulama indirmem gerekiyor mu?":**
Kullanıcı bu maddenin *"app'lerde çıkmaması"* gerektiğini söyledi. Madde
KALDI, çünkü karşılama katmanı YALNIZCA web'de var — Flutter portunda böyle
bir ekran hiç yok (`mobile/` bu bölümde de hiç değişmedi), yani madde
uygulamalarda zaten görünemez. Porta bir gün benzer bir tanıtım ekranı
eklenirse bu madde oraya TAŞINMAMALI.

**SSS yedinci maddeyi aldı — "Kelimeki'nin mobil uygulaması yok mu?"
(21 Ağustos 2026, kullanıcı isteği):** Mağaza inceleme süreci başlayınca
ziyaretçinin soracağı ilk soru bu oldu. Metin kullanıcının taslağından
düzeltilerek girdi: *"Apple ve Android mağaza işlem sürecindeler"* yerine
mağazaların gerçek adları (**App Store / Google Play**) ve *"inceleme
sürecinde"* — "işlem süreci" ne olduğunu söylemiyor. Son cümle
(*"O zamana kadar tarayıcıdan eksiksiz oynayabilirsin"*) BİLİNÇLİ: madde
tek başına "şu an oynayamazsın" gibi okunabilirdi. Hemen ÜSTÜNDEKİ
"Uygulama indirmem gerekiyor mu?" maddesiyle çelişmiyor, onu tamamlıyor —
sıra bu yüzden bilerek yan yana. **Aynı PR'da `tests/smoke.spec.ts`'in
FAQ testi altı → yedi soruya çekildi** (o test JSON-LD ile ekranı
karşılaştırdığından sayıyı güncellemeden geçmezdi). **Ölçüldü**
(derlenmiş `dist`): FAQ JSON-LD `JSON.parse` ile 7 madde, isimler ekrandaki
yedi `<summary>` ile birebir; `dist/index.html` ham 253.990 → **254.771** /
gzip 22.260 → **22.290** bayt (+781 / +30). Port etkilenmedi — karşılama
katmanı web'e özgü (yukarı bkz.).

## Karşılama Katmanı — Sertleştirme (18 Ağustos 2026)

İçerik/efekt turları bitince (yukarıdaki Bölüm 2/3) bağımsız bir denetim
üç somut açık buldu — bunlar kapatıldı.

### CI'da HİÇBİR web kontrolü koşmuyordu

`.github/workflows/` altında yalnızca `mobile-build.yml` (Flutter) ve
`branch-cleanup.yml` vardı; `npm run lint`/`build`/`test` hiçbir workflow'da
çalışmıyordu. Bu, karşılama katmanı eklendiğinden beri özellikle riskliydi:
dolaşımdaki `/game/:id` ve `/davet/:token` bağlantılarının kırılmadığını
kanıtlayan TEK şey `tests/smoke.spec.ts`, ve onu hiçbir otomatik kontrol
koşturmuyordu — `<head>`'e enjekte edilen kapı script'inde
(`scripts/landing-plugin.js`) tek satırlık bir regresyon sessizce merge
edilebilirdi.

**`.github/workflows/web-ci.yml` eklendi** — `mobile-build.yml` ile aynı
tetikleyici deseni (push+PR → `main`, `paths` filtresi; bu sefer `src/**`,
`scripts/**`, `tests/**`, `public/**`, `index.html`, `vite.config.ts`,
`tailwind.config.js`, `playwright.config.ts`, `package*.json`). Adımlar:
`npm ci` → `lint` → `verify-remaining-tiles` → `verify-error-reporting` →
`build` → Playwright'ı kur
(`--with-deps chromium`) → `test`.

**`playwright.config.ts`'teki `executablePath` bu geliştirme ortamına ÖZGÜ
bir yoldu (`/opt/pw-browsers/chromium`) — GitHub Actions runner'ında bu yol
YOK.** `process.env.CI ? undefined : '/opt/pw-browsers/chromium'` yapıldı:
CI'da Playwright'ın kendi kurduğu (bundled) tarayıcı kullanılıyor, bu
ortamdaki yerel davranış hiç değişmedi (testler hâlâ yerelde yeşil — paket
o gün 17, bugün **18 test**).

**Action sürümleri Node 20 uyarısından çıkarıldı (18 Ağustos 2026, kullanıcı
iki ekran görüntüsüyle bildirdi):** GitHub, Actions çalıştırmalarında
*"Node.js 20 actions are deprecated"* ve `setup-java` için ayrı bir
kullanımdan kaldırma uyarısı basıyordu — bunlar HATA değil UYARI'ydı (iş
akışları yeşil geçiyordu), ama her koşuda gürültü üretiyordu. Dört action
güncellendi: `actions/checkout` v4→**v7**, `actions/setup-java` v4→**v5**,
`actions/upload-artifact` v4→**v7**, `actions/setup-node` v4→**v7** (her
birinin güncel majoru ve kırıcı değişiklik notu okunarak). **Pages üçlüsü
(`configure-pages`/`upload-pages-artifact`/`deploy-pages`) ve
`github-script` BİLEREK dokunulmadı** — o işler PR'da hiç koşmadığından
(yalnızca `main`'e push'ta), yükseltmenin doğrulanabileceği bir yer yoktu ve
yayın yolunu doğrulanmamış bir sürüme taşımak orantısız risk olurdu.
`subosito/flutter-action` v2'de kaldı (kendi majoru zaten güncel).

**Negatif eş — CI'ın gerçekten bir şey kanıtladığı ayrı ayrı doğrulandı:**
kapının `seen-intro`/`game-state` dalını geçici olarak boş bırakınca
(`if(l.getItem(...)) return g();` → boş dize) **4 test GERÇEKTEN düştü**
(ikisi mevcut uygulama testleri — "Setup ekranı açılır…" ve "Öne dönüşte
bağlantı durumu…" — dolayısıyla ONLAR da fiilen kapıya bağımlı olduğunu
kanıtladı). Yalnızca satırın içine zararsız bir yorum eklemek (kodun
davranışını değiştirmeden) hiçbir testi düşürmedi — yani duman testlerinin
gerçekten SEMANTİĞE bağlı olduğu, kozmetik bir diff'e değil, ayrıca
doğrulandı.

### Eklentinin derleme+import'u SERİLEŞTİRİLDİ (19 Ağustos 2026)

**Web CI `main`'de bir kez kırmızıya döndü ve sebebi kod DEĞİL bir yarıştı**
(koşu 32196434157, 18 testin 1'i). Dev sunucusu logunda tek satır:
`[vite] Internal server error: mod.renderLandingHtml is not a function` —
sayfanın başlığı `"Error"` olduğundan `toHaveTitle(/Kelimeki/)` düştü.

**Kök sebep:** `scripts/landing-plugin.js`'in `transformIndexHtml`'i dev
sunucusunda HER `/` isteğinde esbuild ile AYNI dosyaya
(`node_modules/.cache/kelimeki/landing-render.mjs`) yazıp onu import ediyordu.
Playwright `fullyParallel` ve CI'da **2 worker** ile koşuyor, yani ilk iki test
sayfayı neredeyse aynı anda açıyor: derleme B, import A dosyayı okurken onu
kesip baştan yazınca yarım okunan modülde export bulunmuyor. Zaman damgaları
bunu doğruluyor — hata testler başladıktan **2 saniye sonra**, ilk testte.

**Bunun bir flake olduğu ÖLÇÜLEREK kanıtlandı, varsayılmadı:** `main`'e merge
edilen ağaç (`28b93ac`) ile PR başının (`4c3a7be`) diff'i **BOŞ**, ve PR
koşusunda aynı testler geçmişti; ondan önceki 12 web-ci koşusunun hepsi yeşil.

**Düzeltme — yeni bir mekanizma değil, projenin kendi kuralının tekrarı:**
derleme+import artık tek bir promise zincirinden geçiyor (`loadLandingModule`),
yani iki derleme asla üst üste binmiyor. Aynı satıra/dosyaya yazan ve onu okuyan
iki iş serileşmedikçe sıra garanti DEĞİLDİR — `local_game_saves` yarışı
(`enqueueSaveWrite`) ve portun `TableWriteQueue`'su aynı dersin başka
yüzleri.

**Doğrulama:** eklentinin `handler`'ı 12 kez EŞZAMANLI çağrılıp içeriye
konan bir sayaçla ölçüldü — düzeltmeden sonra azami eşzamanlı derleme **1**,
üretilen HTML'lerin hepsi doğru; **negatif eş:** serileştirme kaldırılınca aynı
ölçüm **12** veriyor. Maliyet ölçüldü: derleme+import ~50 ms, yalnızca `/`
isteklerinde ve yalnızca dev sunucusunda (derlemede `transformIndexHtml` tek kez
çalışıyor). `npm run lint` + `npm run build` temiz, Playwright **18/18**.

**Bu ortamda hatanın KENDİSİ yeniden üretilemedi** (120 eşzamanlı istek, sonra
doğrudan 72 eşzamanlı derleme/import — sıfır hata; disk ve sayfa önbelleği
burada CI runner'ından hızlı). Yani kapatılan şey gözlenen bir çökme değil
ÖLÇÜLEN BİR YARIŞ PENCERESİ — bir daha görülürse ilk bakılacak yer bu değil,
`vite.config.ts`'in başka bir `transformIndexHtml` tüketicisidir.

### `index.html` boyut kararı — ölçüldü, içerik KORUNDU

| | değer |
|---|---|
| `dist/index.html` ham | **254.8 KB** (bunun ezici çoğunluğu `#karsilama` bloğu) |
| gzip | **22.29 KB** (21 Ağustos 2026 ölçümü — yedinci SSS maddesi dahil) |
| Bölüm 2'nin ilk hedefi | `< 15 KB` gzip (yer tutucu içeriğe göre yazılmıştı) |
| İki tam tahtanın (Bölüm 3'te eklenen) gzip payı | ~6.9 KB |

**Dönen kullanıcıda gerçek maliyet ÖLÇÜLDÜ (Chromium, 4x CPU kısıtlaması,
`Element.prototype.remove` sarmalanarak `navigationStart → #karsilama.remove()`
zamanı ölçüldü, N=8, medyan alındı):** tam sayfa **144.3 ms**; `#karsilama`
içi boşaltılmış bir kontrol derlemesinde **74.2 ms** — aradaki **~70 ms**
fark, dönen kullanıcının hiç görmeyeceği iki 13×13 tahtayı ayrıştırıp DOM'a
kurup sonra silmenin bedeli. Bu, "önemsiz" sayılamayacak, ama tek seferlik
ve boyanmadan önceki bir maliyet (kapı script'i `uygulama-modu` sınıfını
İLK BOYAMADAN ÖNCE eklediğinden, `#karsilama` dönen kullanıcıya HİÇ
görünmüyor — CSS ile baştan gizli).

**Karar: içerik KORUNDU, hedef gerçekleşen değere güncellendi.** Sebep
performans değil ÜRÜN kararı — iki tam tahta (`demoBoard.ts`) kullanıcının
AYNI oturumda birkaç kez, açıkça ve tekrar tekrar büyütüldü (önce tek tahta,
sonra iki, sonra oyun ortası + sınır ihlali, sonra izole hamleler) —
"Landing'de kaç tahta gerekiyor?" sorusu bu kod tabanında zaten cevaplanmış
durumda ve cevap "ikisi de kalsın, zenginleşsin" oldu. 70 ms'lik tek seferlik
bir maliyeti bu açık kararın üstüne çıkarmak yanlış önceliklendirme olurdu.
**Hedef artık `< 15 KB` DEĞİL** — bu doküman bir daha "hedefi tuttur" diye
tahta silmeye kalkışmasın diye rakam güncellendi: gerçekleşen **~22.1 KB
gzip**, takas hâlâ açıkça lehte (22 KB HTML ↔ 410 KB tam uygulama JS'i).
(Bu satır bir dönem 19.3 KB diyordu; filigranların açılması ve tahtanın
kendi genişliğine taşınması rakamı yukarı çekti — ikisi de kullanıcının
açık isteğiydi, bkz. Bölüm 3'teki tahta notu.)

### Başlıktaki düğme: ev ikonu → `← Tanıtım` metni → çıplak `←` (nihai)

Kurulum ekranının sol üstündeki düğme önce bir ev/ok GLYPH'iydi (Bölüm 2),
sonra denetim turunda **metne** (`← Tanıtım`) çevrildi, sonra AYNI GÜN
kullanıcı isteğiyle tekrar **çıplak `←`**'ye döndü — bu üçüncüsü nihai.

**Metne geçişin gerekçesi (artık geçersiz, tarihsel kayıt):** ev/ok
GLYPH'inin `Board.tsx`'teki `HomeMark` ile AYNI vektörü çizmesi
(`RelationIcons.tsx`'in "aynı glyph iki anlam taşıyorsa ayrım ZORUNLU"
kuralını ihlal ediyordu) ve "ev" kelimesinin olgusal olarak yanlış olması
("/" dönen kullanıcı için zaten uygulamanın kendisi). O turda "çıplak `←`
da native alışkanlıkla 'bir adım geri' der, Setup bir kök ekran, orada geri
gidilecek önceki ekran yok" diye çıplak ok da elenmişti.

**Kullanıcı bu son gerekçeyi kabul etmedi (18 Ağustos 2026, aynı gün ikinci
tur):** *"Setup'daki tanıtım yazan geri butonunu sadece geri ok (<) şeklinde
bırakalım."* — canlı tercih, dokümandaki tasarım kararının önüne geçer.
Düğme artık yalnızca `←` gösteriyor; `aria-label="Tanıtım sayfası"` DURUYOR
(erişilebilir ad hâlâ doğru anlatıyor, yalnızca görünür metin sadeleşti).
`HOME_MARK_PATH` export'u `Board.tsx`'ten GERİ ALINDI (tek tüketicisi
buydu) ve bu revizyonla da geri GELMEDİ — davranış (`<a href="/?tanitim=1">`,
tam yeniden yükleme) hiç değişmedi, `tests/smoke.spec.ts` zaten `getByLabel`
ile buluyor, metin değişikliğinden etkilenmiyor.

**Ders:** bu doküman "çıplak `←` bilerek reddedildi" diye yazıp bir sonraki
oturumu ondan caydırmayı hedeflemişti — ama kullanıcının canlı, açık isteği
her zaman dokümandaki bir tasarım kararının önündedir. Bir sonraki oturum
bu satırı "geri dönüldü" diye tekrar metne çevirmeye kalkışmamalı.

**Boyut (aynı gün, dördüncü tur):** Kullanıcı ilk çıplak-ok sürümünü ("bit
kadar" — `text-[10px]`) çok küçük buldu. Yeni değer icat edilmedi:
`Modal.tsx`'in ✕ kapatma butonuyla AYNI ölçek (`text-xl`/20px glyph,
`w-7 h-7`/28px dokunma kutusu, `flex items-center justify-center` ile
ortalanmış) — projede zaten var olan "köşedeki küçük ikon-metin kontrolü"
dilinin tekrarı. **Ölçüldü** (derlenmiş CSS + Chromium, 360/390/834): kutu
üç genişlikte de birebir 28×28px, font-size 20px, sol kenar `px-3.5`
dolgusuyla hizalı (14px); ekran görüntüsüyle de doğrulandı, logo/açıklama
paragrafıyla çakışma yok.

**Glyph (aynı gün, beşinci tur):** Kullanıcı Unicode ok karakterini
(`←`) sevmedi — *"O oku sevmedim. < kullan yerine"*. Görünen karakter düz
`<` (JSX'te `&lt;` olarak yazılıyor, çıplak `<` metin içinde bir etiket
başlangıcıyla karışırdı) — `aria-label`/boyut/davranış hiçbiri değişmedi,
yalnızca glyph. Bu projede artık "geri" göstergesi olarak İKİ farklı
karakter var ve bu BİLEREK: Canlı oyun ekranındaki (`OnlineGameScreen.tsx`)
kendi "←" göstergesi ayrı bir buton/senaryo, bu değişiklik ona dokunmadı.

### Setup'taki `<` düğmesi artık YALNIZCA girişsiz kullanıcıda görünüyor

Kullanıcı sordu (18 Ağustos 2026): *"girişli olarak setup ekranından geri
yaptığımda giriş butonu çıkıyor tekrar. Bu normal mi?"* — kök sebep açıklandı
(bkz. aşağıdaki tarihsel not), ardından AYNI GÜN üçüncü turda kullanıcı asıl
soruyu sordu: *"O zaman girişli kullanıcı da geri oku da çıkmamalı, öyle
değil mi?"* — **Evet, doğru çıkarım.** `App.tsx`'teki `showTanitimLink`
(`!authLoading && !user`) artık düğmeyi girişli hesapta hiç RENDER ETMİYOR;
satır boşken `UserMenu` sağda kalsın diye kap `justify-between`den
`justify-end`e geçiyor (aksi halde tek çocuklu bir `justify-between` `flex`
kutusu tek öğeyi SOLA iterdi). `authLoading` sırasında da gizli — `UserMenu`
kendi GİRİŞ/avatar kararında zaten aynı "önce bilmeden gösterme" desenini
kullanıyor.

**Neden bu, katmanı auth-farkında yapmaktan (`Landing.tsx`'in statik
başlığına oturum kontrolü eklemekten) daha iyi bir çözüm:** o yol
`Landing.tsx`'in "hiçbir hook/olay/tarayıcı globali YOK, sunucuda statik
render edilir" temel kısıtını ihlal ederdi. Buradaki gerçek soru "bu escape
hatch'in girişli bir kullanıcı için değeri ne?" idi — cevap: hiç. Kapı
zaten girişli kullanıcıyı katmanı HİÇ göstermeden uygulamaya alıyor (bkz.
"Kapı" bölümü); `?tanitim=1` düğmesi tam olarak bu davranışı BİLEREK deldiği
için var oluyordu (misafirin "Hemen Oyna"dan pişman olup geri dönmesi için),
ve girişli bir kullanıcının o davranışı delmesi gereken bir senaryo yok.
Düğmeyi tamamen kaldırmak, statik header'ı yamalamaktan daha az riskli VE
daha doğru bir çözüm.

**Tarihsel not — kök sebep (artık yalnızca `?tanitim=1`e ELLE giden ya da
eski bir sekme/bookmark'tan gelen girişli kullanıcı için geçerli, normal
UI akışında bir daha karşılaşılmaz):** Landing katmanının başlığındaki GİRİŞ
(`#karsilama-giris`) STATİK, derleme zamanında üretilen düz HTML —
`Landing.tsx` sunucuda (Node'da) render ediliyor, hiçbir tarayıcı
globaline/auth durumuna erişimi yok, dolayısıyla oturum açık olsa da olmasa
da HER ZAMAN aynı "GİRİŞ" düğmesini basar; `?tanitim=1` dönen-kullanıcı
sinyallerini (`seen-intro`/yarım oyun/**oturum**/PWA) BİLEREK atladığından
kapı bu durumda araya girmiyordu.

### Kayda geçen yan not — tarayıcının Geri tuşu farklı davranıyor

`gec()` geçişi `history.replaceState` kullanıyor (bkz. yukarıdaki "Buton
bağlama sözleşmesi"), yani OYNA'ya bastıktan sonra **tarayıcının kendi Geri
tuşu karşılama sayfasına DÖNMÜYOR** — siteden çıkıyor. `?tanitim=1` linki
ise `pushState` gerektirmeyen düz bir `<a href>` navigasyonu, yani AYNI
ekranda iki "geri" (tarayıcı Geri tuşu ile `<` düğmesi) farklı
davranıyor. `pushState`e geçmek mümkün ama katman DOM'dan silindiğinden geri
dönüş ayrıca bir `popstate` → yeniden yükleme zinciri gerektirir — nadir
görülecek bir senaryo için orantısız. **BİLİNÇLİ OLARAK olduğu gibi
bırakıldı** — bir sonraki oturum bunu hata sanıp `pushState`e geçirmeye
kalkışmamalı.

### İki platform artık görünür biçimde farklı — bilerek

Uygulamada (Flutter portu) karşılama katmanı yok ve `<` düğmesinin
bir karşılığı da yok/olmayacak. Bu artık gözle görülür bir ayrışma
(`mobile/CLAUDE.md`'ye üç maddelik not düşüldü — bkz. orada "Karşılama
Katmanı — web'e özgü, bilinçli ayrışma"): (1) düğme web'e özgü, porta
eklenMEyecek; (2) uygulamanın kendi ilk açılış/tanıtım ekranı AYRI bir iş
olarak planlanmıştı ve **19 Ağustos 2026'da YAPILDI** — portun kendi
`IntroScreen`'i (4 sayfalık `PageView`: hoş geldin + rakamlar, "Nasıl
oynanır?" dört adım, dokuz k-lig rütbesi; ATLAMA YOK — tek çıkış son
sayfadaki "HEMEN OYNA") ilk açılışta Setup'ın ÖNÜNE giriyor, kalıcı
`seen_intro` bayrağıyla bir kez gösteriliyor (ayrıntı:
`mobile/CLAUDE.md`, Parça 116 + 117). Metinler bu
katmandan BİREBİR taşındı, ama katmanın kendisi (SEO/paylaşım için var
olan statik HTML, kapı script'i, tahta demoları) porta taşınMADI; (3) o
ekran geldiğinde bile Setup başlığına bir ok/düğme KONMADI — native bir
uygulamada kök ekranın sol üstündeki geri oku navigasyon yığınını pop
eder ve Setup zaten kök ekran, iOS'ta sistem geri hareketiyle
çakışırdı; dönüş Setup'ın logo altındaki link satırında ("Nasıl
oynanır? · Tanıtım") — 19 Ağustos 2026'da hesap menüsünden oraya
taşındı, boşalan yeri alan "Arkadaşınla paylaş" da footer'a indi.
**Yan sonuç, bilerek:** o satır yalnızca MİSAFİRDE çizildiğinden
girişli kullanıcının tanıtıma dönüş yolu yok — web'deki `<` düğmesi de
aynı şekilde girişsize özel, yani sapma değil parite.

### SEO cilası — üç küçük, bağımsız eksik

Katmanın asıl amacı (ham HTML'de gerçek metin) zaten tutmuştu — `dist/index.html`
**712 kelime** taranabilir metin taşıyor (öncesi: yalnızca `noscript`teki iki
cümle), Kelimeki'yi tanımlayan cümle ilk 200 karakterde, başlık hiyerarşisi
temiz (5×`h2`, 10×`h3`), kapı script'i crawler'ı engellemiyor (Googlebot'ta
`localStorage` boş çıkar, katman görünür kalır). Kalan üç eksik:

- **İki `<h1>` vardı.** `noscript` bloğunun kendi `<h1>`'i (yalnızca JS
  kapalıyken görünür) ile katmanın kahraman `<h1>`'i (LogoMark'ın sr-only
  başlığı) ham HTML'de AYNI ANDA duruyordu — crawler'a aynı iddianın iki
  farklı ifadesini gösteriyordu. `noscript`teki gerekçe zaten ARTIK
  GEÇERSİZDİ: 1 Ağustos 2026'da "ham HTML'de hiç metin yok, içerik yok
  sanılıyor" korkusuyla eklenmişti, ama aynı gün eklenen karşılama katmanı
  bu boşluğu zaten dolduruyor. `noscript`teki `<h1>` bir `<p>`ye indirildi
  (blok SİLİNMEDİ — JS'i kapalı gerçek bir kullanıcıya "JavaScript
  gerekiyor" demek hâlâ doğru, gerekçesi artık indeksleme değil
  erişilebilirlik). **Ölçüldü:** ham HTML'deki gerçek (yorum İÇİNDE değil)
  `<h1>` sayısı artık **1**.
- **Altı gerçek SSS var ama `FAQPage` yapılandırılmış verisi yoktu.**
  `<head>`'deki ld+json yalnızca `WebApplication` taşıyordu. Google FAQ
  zengin sonuçlarını 2023'te büyük ölçüde kısıtladığından mavi-link kazancı
  beklenmiyor — kazanç varlık anlama ve LLM/AI crawler'ları tarafında
  (bu işin çıkış noktası zaten oydu: AI Mode Kelimeki'yi "kelime
  bulucu/sözlük platformu" sanıyordu). **Metinler İKİNCİ KEZ yazılmadı** —
  altı soru `Landing.tsx`'te `export const SSS` dizisine çıkarıldı, hem
  ekrandaki `<details>` kutuları (`.map`) hem `render.tsx`'in yeni
  `renderFaqJsonLd()`'si aynı diziyi tüketiyor. **`src/` altında
  `dangerouslySetInnerHTML` kuralı BOZULMADI:** JSON-LD, `Landing.tsx`
  içinden değil `scripts/landing-plugin.js`'ten (mevcut `WebApplication`
  bloğunun yanına) düz bir `<script>` string'i olarak enjekte ediliyor —
  React'in render ağacı hiç `dangerouslySetInnerHTML` görmüyor. `<`
  karakterleri `<`'ye kaçırılıyor (bir cevap metnindeki `<` bir gün
  `</script>`i erkenden kapatabilirdi). **Doğrulandı:** üretilen JSON
  `JSON.parse` edilip altı `Question`ın metinleri ekrandaki altı soruyla
  BİREBİR karşılaştırılıyor (`tests/smoke.spec.ts`), negatif eş ile de
  (bir soruya sahte bir sonek eklenince test GERÇEKTEN düştü).
- **İki tahta demosu ekran okuyucuda harf çorbasıydı.** Rütbe mühürlerine
  doğru desen (`role="img"` + `aria-label`, 9 adet) uygulanmıştı ama iki
  tahta demosuna UYGULANMAMIŞTI — 13×13 = 169 hücrenin her biri tek tek
  okunuyor, taranabilir metne `K E L İ M E A R A…` diye giriyordu.
  `Landing.tsx`'teki sarmalayıcı `<div>`lere `role="img"` + açıklayıcı
  `aria-label` eklendi (`role="img"` çocuk düğümlere inmeyi keser).
  **`Board.tsx`'e DOKUNULMADI** — öznitelik yalnızca katmanın kendi
  sarmalayıcısında; `Board` gerçek oyunda etkileşimli bir yüzey, orada bir
  "resim" değil.

**Negatif eş — üçü de ayrı ayrı doğrulandı:** `Landing.tsx`'teki tek
`<h1>`'i geçici olarak `<div>`ye çevirmek ilgili testi GERÇEKTEN düşürdü;
`render.tsx`'te bir soru metnine sahte bir sonek eklemek FAQ eşleşme
testini GERÇEKTEN düşürdü.

**CI'a eklendi, `verify-*` script'i GEREKMEDİ** — üç kontrol de
`tests/smoke.spec.ts`e iki yeni test olarak eklendi (`h1`/`role="img"`
sayımı + FAQ eşleşmesi), `.github/workflows/web-ci.yml` ile her PR'da
otomatik koşuyor.

### Otomatik giriş yapan kullanıcı katmanı GÖRMEZ — ölçüldü, testle kilitli

Kullanıcı sordu (18 Ağustos 2026): *"Daha önce kayıtlı olup otomatik giriş
yapanlar tanıtımı görmeden gene giriş yapıyor olacaklar mı? Olsa iyi olur.
Deneyimin bozulmasını istemem. Çözmek için garip işler yapma."* — Cevap:
evet, ve bunun için hiçbir şey yapmak gerekmedi; kapının `sb-*-auth-token`
taraması bunu zaten karşılıyor (bkz. "Kapı" tablosu). **Dört senaryo gerçek
tarayıcıda ölçüldü:** anahtar hiç yokken → katman; gerçek proje ref'iyle
oturum anahtarı → uygulama; BAŞKA bir proje ref'i → uygulama (tarama ref'i
sabit yazmıyor, `sb-…-auth-token` desenine bakıyor); parçalanmış (`.0`
sonekli) anahtar → katman — **sonuncusu bir açık DEĞİL**: supabase-js
2.108.2 `localStorage`'da oturumu parçalamıyor (yalnızca çerez depolarında
yapıyor), yani üretimde o şekil hiç oluşmuyor.

`tests/smoke.spec.ts`e kalıcı bir regresyon testi eklendi (paket 17 →
**18 test**): `addInitScript` ile gerçek desende bir oturum anahtarı
yazılınca katman HİÇ görünmüyor, `#root` doluyor. **Negatif eş:** kapının
oturum tarama dalı kaldırılınca test GERÇEKTEN düşüyor.

