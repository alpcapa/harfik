# SEO — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026).

## SEO

**Google Search Console** kurulu (mülk doğrulanmış, kullanıcı hesabında) — bu, Supabase Dashboard/Brevo ayarları gibi repoda hiçbir iz bırakmıyor, bu yüzden bu not burada duruyor. `public/sitemap.xml` (tek URL, `https://kelimeki.com/`) ve `public/robots.txt` (`Sitemap: https://kelimeki.com/sitemap.xml` satırıyla ona işaret ediyor) GSC'ye gönderilmiş durumda. **Bing Webmaster Tools** da aynı gün kuruldu, aynı `sitemap.xml`/`robots.txt` orada da gönderildi — GSC ile ilgili aşağıdaki tüm notlar (statik `lastmod`, Claude'un erişimi olmaması, PR deploy olmadan tetiklemenin işe yaramaması) Bing için de birebir geçerli; tek fark Bing'in kendi paneli (bing.com/webmasters) — "URL Denetleme"nin karşılığı orada **"URL Gönder" (Submit URL)**.

**`sitemap.xml`'in `lastmod`'u statik/elle — deploy'larla OTOMATİK güncellenmiyor.** İlk fark edildiği an (1 Ağustos 2026): kullanıcı `index.html`'in meta description'ını rakip bir oyunun adına yapılan atıftan arındırmıştı ama Google'ın SERP'te gösterdiği snippet hâlâ eskiydi. Kök sebep incelenirken iki ayrı boşluk bulundu — (1) `vite.config.ts`'teki PWA manifest `description`'ı (`dist/manifest.webmanifest`'e işleniyor, gerçekten kullanıcıya/crawler'a servis ediliyor) o güncellemede atlanmış, hâlâ aynı atfı taşıyordu; (2) `sitemap.xml`'in `lastmod`'u 12 gündür aynıydı — Google'a "bu sayfa değişti, yeniden tara" sinyali hiç gitmemişti. Anlamlı bir meta/açıklama/başlık değişikliği yapıldığında **ÜÇÜ de** (`vite.config.ts`'teki manifest `description`'ı, `public/og-image.png`'in İÇİNDEKİ metin — `npm run generate-og-image` — VE `sitemap.xml`'in `lastmod`'u, o günün tarihine) kontrol edilip güncellenmeli — `CLAUDE.md`/`README.md` senkron kontrolüyle aynı refleks. (Marka/telif hassasiyeti nedeniyle bu notta da rakip oyunun adı bilerek kullanılmıyor — bkz. 2 Ağustos 2026'daki genel temizlik.)

**17 Ağustos 2026 — ÜÇÜNCÜ yer (og-image) tam da bu listede olmadığı için bayat kaldı, kullanıcı fark etti:** `index.html` ve PWA manifest'i bir noktada "yapay zekaya **ve arkadaşlarına** karşı" olarak güncellenmişti (Canlı oyun eklendiğinden beri doğrusu bu), ama `public/og-image.png` hâlâ "yapay zekaya karşı oynanan" diyordu — yani WhatsApp/X/LinkedIn'de paylaşılan HER linkin görselinde ürün eksik tarif ediliyordu. **Kök sebep bir doküman hatasıydı:** yukarıdaki komut tablosu `npm run generate-icons`in og-image'ı da ürettiğini söylüyordu, oysa `generate-icons.mjs` ona HİÇ dokunmuyor (`grep -n "toFile" scripts/generate-icons.mjs` ile doğrulandı) — og-image'ın kendi script'i var ve o gün `package.json`'da bir npm girdisi bile YOKTU, yani açıklamayı güncelleyen biri dokümana uyup `generate-icons` koşuyor ve og-image'a hiç değmiyordu. Aynı düzeltmede `npm run generate-og-image` girdisi eklendi ve tablo düzeltildi. **Ders: "şu komut şunu da üretir" diyen bir doküman satırı, komutu koşmadan/kaynağını okumadan doğru sayılamaz** — bu proje aynı sınıf hatayı `mobile/CLAUDE.md`'de bir kez daha yaşamıştı (var olmayan bir `npm run generate-klig-paths` komutu yazılmıştı).

**Yeniden indekslemeyi hızlandırma — Claude'un GSC'ye erişimi YOK, bu adımlar kullanıcı tarafından yapılmalı:**
1. Meta/sitemap değişikliği içeren PR merge edilip **deploy olduktan SONRA** (sırası önemli — deploy olmadan tetiklemek eski içeriği yeniden tazeler).
2. GSC → **URL Denetleme (URL Inspection)** → `https://kelimeki.com/` → **"Dizine Eklenmesini İste"** — en etkili tekil adım, öncelikli yeniden tarama kuyruğuna alır (saatler-birkaç gün, garantisi yok).
3. GSC → **Sitemaps** raporunda mevcut `sitemap.xml` girdisini yeniden gönder (resubmit) — dosyanın kendisi zaten sabit URL'de olduğundan ayrıca "yüklemek" gerekmez, Google onu zaten periyodik çekiyor; resubmit yalnızca bu çekimi hemen tetikler.
4. Marka karışıklığı (ör. Google AI Overview'ın "kelimeki"yi başka bir uygulamayla — "Kelimelik" gibi — karıştırması) reindex ile alakasız, ayrı ve daha yavaş çözülen bir marka-tanınırlık sorunu (daha fazla organik arama/backlink zamanla düzeltir) — "Dizine Eklenmesini İste" bunu çözmez.

## `/nasil-oynanir/` — taranabilir kurallar sayfası (31 Ağustos 2026)

**Tetikleyici somut bir olaydı, genel bir "SEO iyileştirmesi" değil.** 17
Ağustos 2026'da Google AI Mode, Kelimeki'yi *"kelime bulucu ve sözlük
platformu"* diye TAMAMEN uydurdu (üç ekran görüntüsüyle kaydedildi). Sebep:
oyunu gerçekten anlatan tek zengin içerik `HelpModal`'daydı ve o YALNIZCA
pencere açılınca render oluyordu — taranabilir HTML'de hiç yoktu. Makineler
boşluğu kendileri doldurdu.

⚠ **CLIENT-RENDER BU İŞİ GÖRMEZDİ ve bu maddenin can alıcı noktası bu.**
Googlebot JS çalıştırıyor, ama **AI/LLM crawler'ları çalıştırmıyor** — yani
sorunu DOĞURAN tarafı tam olarak ıskalardı. Sayfa bu yüzden derleme
zamanında üretiliyor (`scripts/legal-plugin.js` → `STATIC_PAGES`), tıpkı
`/gizlilik/` ailesi gibi: 35 KB HTML, **sıfır `<script>`**, ~7,9 KB metin.

**İçerik tek kaynakta.** `HelpModal.tsx` `QuickStart` ve `DetailedRules`'ü
dışa açıyor; sayfa onları ithal ediyor. Kopya yazmak iki şeyi birden
bozardı: (a) bu projenin en sık hata sınıfı olan "iki kopya sessizce
ayrışır", (b) `mobile/app/test/help_text_parity_test.dart` O DOSYAYI
tarıyor, yani mobil parite de yalanlanırdı.

**Öksüz sayfa sorunu.** Yalnızca `sitemap.xml`de duran bir URL zayıf
keşfedilir. Karşılama katmanındaki "Nasıl oynanır?" bölümünün sonuna GERÇEK
bir `<a href="/nasil-oynanir/">` kondu — footer'daki hukuki bağlantıların
`<button>` olması (SPA penceresi açıyorlar) tam da bu boşluğu yaratıyordu.
Duman testi o bağlantının `<a>` kalmasını zorluyor.

⚠ **Yapılırken bir hata yapıldı ve testler yakaladı — tekrarlanmasın.**
`HelpModal.tsx`e eklenen uyarı yorumunda parite testinin regex'i ÖRNEK
OLARAK yazıldı. Tarama yorum/kod ayrımı yapmıyor: örnek, GERÇEK bir başlık
gibi sayıldı ve Dart parite testi düştü. Yani "bu kalıbı taşıma" diyen
uyarının kendisi kalıbı taşıdı. **Kaynak taraması yapan bir testin
konusunda, o test neyi arıyorsa onu yorumda örneklemekten kaçın.**

**Kalan SEO borcu:** footer'daki hukuki bağlantılar hâlâ `<button>` — o üç
sayfa yalnızca sitemap üzerinden keşfediliyor. Bu maddede bilerek
dokunulmadı (SPA penceresini açma davranışı ayrı bir karar).

## 31 Ağustos 2026 — Statik sayfaların paylaşım kartı (OG) yoktu

Sayfa canlıya çıkıp GSC/Bing'e gönderildikten sonra Bing Webmaster Tools'un
markup raporu okundu. `/` için **"2 Markup types found: JSON-LD,
OpenGraph"** yazıyordu — bu bir uyarı değil, bilgi satırı; ikisinin de
bulunması istenen durum (`index.html`'de schema.org `WebApplication` bloğu
+ `og:*` etiketleri). **Asıl bulgu raporun DEMEDİĞİ şeydi:** aynı rapor
`/nasil-oynanir/` için hiçbir markup göstermiyordu, çünkü
`renderLegalPage` (`src/legal/render.tsx`) `<head>`e yalnızca
charset/viewport/title/description/canonical/robots yazıyordu.

Hukuki sayfalar için bu boşluk zararsızdı — kimse gizlilik politikasını
paylaşmıyor. Ama `/nasil-oynanir/` **paylaşılmak için var**: karşılama
katmanı ona link veriyor ve tanıtım yaparken doğrudan atılacak adres o.
OG'siz hâlde WhatsApp/X'te çıplak URL olarak çıkıyordu. Dört statik sayfaya
birden `og:*` + `twitter:*` eklendi; görsel kök sayfayla ORTAK
(`/og-image.png`), başlık/açıklama zaten sayfaya özel.

**JSON-LD bilerek EKLENMEDİ.** Doğal aday `HowTo` şemasıydı, ama Google
2023'te `HowTo` zengin sonuçlarını tamamen kaldırdı; `FAQPage` de artık
yalnızca resmi/sağlık sitelerinde gösteriliyor. Yani bakım maliyeti
karşılığında görünür bir kazanç beklenmiyor. Beklenti değişirse burası
yeniden değerlendirilsin.

**`sitemap.xml`'in `lastmod` kuralı GENİŞLEDİ.** Bu dosyanın yukarısındaki
kural "anlamlı bir meta/açıklama/başlık değişikliği" diyordu. Yeni sayfayı
ekleyen PR `/`'ın `lastmod`'una dokunmamıştı — oysa `/` DEĞİŞMİŞTİ (yeni
sayfaya giden bağlantı oraya eklendi). Sonuç çelişkili bir sinyaldi:
panelden "şu sayfayı yeniden tara" derken sitemap "o sayfa değişmedi"
diyordu. Kural artık şu: **bir sayfanın ÇIKAN BAĞLANTILARI değiştiyse o
sayfanın da `lastmod`'u güncellenir** — özellikle yeni bir sayfanın tek
keşif yolu o bağlantıysa.

**Bir hata daha, aynı sınıftan (açıklama yorumu kodu bozdu).** OG bloğunu
anlatan yorum HTML yorumu olarak **template literal'in İÇİNE** yazıldı ve
içindeki backtick'ler dizeyi erken kapattı → `TS1005`, derleme düştü.
Üstelik yorum üretilen dört sayfanın da HTML'ine giriyordu. Açıklama
fonksiyonun üstündeki TS yorumuna taşındı. Bu, bir gün önceki parite-testi
olayının kardeşi: **açıklama metni, açıkladığı mekanizmanın içine
yazılmaz.**

**Regresyon:** duman testi 44 → **46**. Yeni test İKİ sayfayı birden
okuyor (`/nasil-oynanir/` + `/gizlilik/`) — tek sayfa yeterli olsaydı
sabit yazılmış bir başlık/URL de testi geçerdi; değerlerin sayfaya GÖRE
değiştiği kanıtlanmalı. Ayrıca `og:description` sayfanın kendi
`description`'ıyla KARŞILAŞTIRILIYOR, sabitle değil. Negatif eşler: `og:url`
satırı silinince 2 test düşüyor, `og:description` genel bir metne
çevrilince 2 test düşüyor.
