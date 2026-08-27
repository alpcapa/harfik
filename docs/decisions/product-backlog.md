# Sonraya Bırakılan Ürün Fikirleri — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026). Sıralı yürütme planı ayrı: ROADMAP.md.

## Sonraya Bırakılan Ürün Fikirleri (karar verildi, henüz yapılmadı)

> **Sıralı yürütme planı ayrı bir dosyada: `ROADMAP.md`.** Burası *ne* ve
> *neden ertelendi*; orası *hangi sırayla, hangi modelle, hangi tuzaklarla*.
> Yeni bir oturum işe başlarken önce onu okusun — bir madde bitince oradan
> silinip kaydı buraya/ilgili bölüme taşınır.

Bir alt bölümden farkı: orası mobil porttan gelen "web geride kaldı"
maddeleri, burası İKİ platformu birden ilgilendiren ve bilinçli olarak
ertelenmiş ürün fikirleri. Bir madde yapılınca buradan silinip ilgili
bölümün kendi tarihli notuna taşınır.

- **Hayalet taş tahtayla birlikte küçülmeli (24 Ağustos 2026, ölçüldü —
  ertelendi):** Sürüklenen taşın hayaleti SABİT 46 px (`App.tsx`'te
  `width/height: 46` + `scale(1.1)` = 50,6 px; portta `_buildGhost`'ta aynı
  sayı). Masaüstünde tahta hücresi de 46,2 px olduğundan tam oturuyor —
  sayı oradan geliyor. **Telefonda hücre 23,9 px'e iniyor ama hayalet 46'da
  kalıyor**, yani hedefin İKİ KATI (390 px'te ölçüldü: 50,6 / 23,9 = 2,13×).
  İki sonucu var: (1) bırakma hedefinin kesikli yeşil/kırmızı çerçevesi
  hayaletin ALTINDA kalıp hiç görünmüyor — kullanıcı bunu bizzat bildirdi
  (*"genellikle o pek gözükmüyor"*); (2) sürüklenen taş komşu hücreleri de
  örttüğünden nereye düşeceği gözle kestirilemiyor.
  - **Denenip ELENEN iki ucuz çözüm (ikisi de ekranda üretilip bakıldı,
    ikisi de mevcut hâlden KÖTÜ):** çerçeveyi hayaletin üstüne almak →
    kesikli kutu harfin üstüne binip taşı okunmaz yapıyor; hayaleti yarı
    saydam yapmak (`opacity: .72`) → harf soluyor, çerçeve yine zar zor
    seçiliyor. Kayıt bu yüzden burada: **"çerçeveyi görünür yap" yanlış
    çerçeveleme**, sorun çerçevede değil hayaletin ÖLÇÜSÜNDE.
  - **Doğru düzeltme:** hayaletin ölçüsünü tahta hücresine bağlamak (sabit
    46 yerine ölçülen hücre boyu). Masaüstünde davranış pratikte
    değişmez (46 ≈ 46,2), telefonda hayalet hedefiyle aynı boya iner ve
    çerçeve kendiliğinden görünür olur. İKİ platformda birden yapılmalı.
  - **Neden ertelendi:** gerçek bir tasarım değişikliği ve "parmağın
    altındaki taş ne kadar küçük olabilir" sorusu cihazda bakılmadan
    yanıtlanamaz; Play Store yükleme akışını bölmemek için sonraya bırakıldı.

- **Web'de sürükleme hedefi hâlâ `<Board>`'un PROP'u (24 Ağustos 2026,
  portun 8 Ağustos düzeltmesi geri taşınmadı):** `App.tsx` her pointer
  hareketinde `setGhost({... overKey, overValid})` çağırıyor ve bu ikisi
  `<Board>`'a prop olarak geçiyor (`App.tsx:1546-1547`), yani **169 hücre +
  territory hesabı her harekette yeniden render ediliyor**. Port bunu
  8 Ağustos'ta bırakmıştı (Parça 23): orada gösterge artık `BoardWidget`'ın
  DEĞİL, ekran katmanının kendi küçük overlay'inin işi
  (`game_screen.dart` → `_hoverHighlight`), `BoardWidget` sürükleme
  sırasında hiç yeniden inşa edilmiyor. Aynı deseni web'e taşımak gerekiyor.
  - **Maliyeti ÖLÇÜLEMEDİ, iddia edilmiyor:** bu oturumdaki harness'te
    sürükleme başlatılamadığı için kare süresi karşılaştırması yapılamadı
    (engel sonradan bulundu — ilk oyunda `HelpModal` kendiliğinden açılıp
    dokunuşu yutuyor; `smoke.spec.ts`'teki gibi ✕ ile kapatmak gerekiyor).
    Yani bu madde "kanıtlanmış yavaşlık" değil, **kanıtlanmış yapısal borç**.

- **k-lig puan grafiği (14 Ağustos 2026, kullanıcı fikri — "sonra yaparız"):**
  Skor Kartı'nda "Oyuncu İstatistikleri" başlığının EN SAĞINA bir link;
  basınca kişinin k-lig puanının zaman içindeki seyrini gösteren bir grafik
  açılır. Ödül/rütbe olayları grafiğin üstünde etiket olarak işaretlenir.
  - **YALNIZCA AKTİF HAREKETLER ÇİZİLİR (kullanıcı kararı):** puan
    getirmeyen oyunlar (2 kişilikte ikincilik = 0) grafiğe HİÇ girmez.
    Gerekçe ölçümle sabit: aktif oyuncularda oyunların **~%40'ı 0 puan**,
    yani ham "oyun sırası" ekseni uzun düz platolar üretiyordu. Eksen bu
    yüzden "kaçıncı oyun" DEĞİL, olay bazlı olmalı. **Atmak güvenli, çünkü
    o oyunlar toplama sıfır katkı veriyor** — grafiğin son noktası yine
    `total_score` ile birebir kalır.
  - **Veri ZATEN var, yeni yazma/kişisel veri YOK** (Terms/Privacy'ye
    dokunmaz): seri `games`ten `player_stats`ın ifadesiyle
    (`surrendered → -2`, `rank=1 → 2`, `rank=2 && player_count<>2 → 1`,
    diğer → 0) kümülatif olarak kurulur, üstüne `league_rewards`'ın
    `points_reward` satırları binlenir. **14 Ağustos 2026'da canlıda
    doğrulandı: bu yeniden hesap 15/15 kullanıcıda
    `player_stats_overall.total_score` ile TAM eşleşti** — yani grafik
    Skor Kartı'ndaki sayıyla çelişemez. Etiketlerin kaynağı da hazır:
    `league_rewards`'ın `rank_up`/`rank_down`/`points_milestone` satırları.
  - **NEDEN ERTELENDİ — ve ertelemenin maliyeti SIFIR:** `games.created_at`
    durduğu sürece seri her zaman GERİYE DÖNÜK, tam geçmişle kurulabilir
    (platform kolonunun tam tersi — o doldurulamadığı için lansman öncesi
    yapılmak zorundaydı). Bugün fikri zayıflatan iki şey de kendiliğinden
    düzeliyor: (a) 15 kullanıcının yalnızca 4'ünde dolu bir grafik çıkacak
    kadar oyun var (101/63/55/47; kalan 11'inin 11 ya da daha az oyunu var,
    6'sında ≤3); (b) etiketler bugün neredeyse boş — `league_rewards`'ta
    TOPLAM 6 satır var (3 kişide birer Meraklı/50 `rank_up` + ödülü),
    **sıfır** kilometre taşı (kimse 100'e ulaşmadı) ve **sıfır** rütbe
    düşüşü. Ironman 91'de; 100 geçilir geçilmez ilk kilometre taşı + Oyuncu
    rütbesi doğacak ve etiketler anlam kazanmaya başlayacak.
  - **Yapılırken iki not:** (1) web + port AYNI PR'da — ikisi de aynı Skor
    Kartı'nı taşıyor, tek taraflı yapmak bu projenin en sık hatasını
    (sessiz ayrışma) üretir; (2) `PlayerScoreCard` aynı bölümü kullandığından
    grafik BAŞKASININ kartında da görünür — yeni bir sızıntı değil (o veri
    girişli herkese zaten açık) ama bilerek karar verilmeli.

- **Hesap silme (KVKK "unutulma hakkı") — self-servis yol YOK (19 Ağustos
  2026'da hukuki metin denetiminde tekrar gündeme geldi):** Bugün kullanıcının
  hesabını kendi silebileceği hiçbir arayüz yok; var olan tek şey admin
  tarafındaki "hesabı dondurma" (`admin_set_user_banned`). Gizlilik
  Politikası'nın 5. bölümü bu yüzden 19 Ağustos'ta düzeltildi: silme artık
  "Görüş Bildir" kanalından TALEP edilen, 30 gün içinde elle yerine getirilen
  bir işlem olarak anlatılıyor — yani metin bugün DOĞRU, ama özelliğin
  kendisi hâlâ eksik. **Yapılacağı zaman asıl iş UI değil kaskad zinciri:**
  `auth.users` + `profiles` + `games` + `game_likes` + `friend_requests` +
  `friend_invite_links` + `local_game_saves` + `online_game_*` (devam eden
  oyunlar, sohbet, mute/şikayet) + `feedback` + `league_rewards` +
  `admin_ban_log`; bir kısmı cascade, bir kısmı değil, ve silinen kişi
  BAŞKALARININ bitmiş oyun kayıtlarında (`games.players` snapshot'ı) isimle
  duruyor — o satırlar başka kullanıcıların kendi verisi olduğundan
  silinemez, en fazla anonimleştirilebilir.
  **KULLANICI KARARI (19 Ağustos 2026): web için geliştirme YAPILMAYACAK** —
  sözleriyle: *"Legal olarak silme hakkı zorunluluğu yoksa bildirim üzerine
  aksiyon yeterlidir ve geliştirme gerekmez."* Bu HUKUKEN doğru: KVKK m.7/m.11
  (ve GDPR m.17) silme HAKKI veriyor ama uygulama içi bir silme BUTONU şart
  koşmuyor; talebin 30 gün içinde karşılanması yeterli, politikanın 5. bölümü
  de tam olarak bunu anlatıyor. **Maddenin listede kalma sebebi hukuk değil
  MAĞAZA KURALI:** Apple App Store Review Guideline 5.1.1(v) (Haziran
  2022'den beri) ve Google Play'in veri silme şartı (2024'ten beri), hesap
  açtıran uygulamalarda uygulama İÇİNDEN başlatılabilen bir silme yolu
  istiyor — yasa değil yayın kapısı, karşılanmazsa inceleme reddediliyor.
  Yani: web'de gerekmez, **mobil mağaza çıkışında gerekir**; o gün iki
  mağazanın güncel politikası bir kez daha teyit edilmeli (bu satır 19 Ağustos
  2026'daki bilgiye dayanıyor, mağaza kuralları değişebiliyor). Bir sonraki
  oturum bunu "hukuki eksik" diye yeniden açmasın.

- **Taranabilir `/nasil-oynanir` sayfası (17 Ağustos 2026, kullanıcı
  kararı: "ileride yapılacak işlere ekle, o zaman değerlendiririz"):**
  Sitenin EN ZENGİN açıklayıcı içeriği (`HelpModal.tsx` — kurallar, bölge
  mekaniği, puanlama, rütbeler) yalnızca kullanıcı modalı AÇINCA render
  oluyor, yani taranabilir HTML'de hiç yok. Fikir o içeriği kendi
  URL'inde de yayınlamak.
  - **Tetikleyen somut gözlem (aynı gün, kullanıcının üç ekran
    görüntüsü):** Google'ın organik sonucu ve AI Overview'ı Kelimeki'yi
    DOĞRU anlatıyordu, ama **AI Mode** tamamen uydurdu — "kelime bulucu
    ve sözlük platformu", Scrabble/Kelimelik yardımcısı, jokerli arama,
    puan hesaplama... hiçbiri bizde yok. Kullanıcı "yanlış" geri bildirimi
    verdi. Üç ölçülebilir sebep: (1) Google "kelimeki"yi hâlâ marka olarak
    tanımıyor — arama sonucunda *"Including results for kelimeler"*
    yazıyor; (2) o isim alanında Türkçe kelime-bulucu/sözlük siteleri
    baskın, model boşluğu onlarla doldurmuş; (3) sitede grounding yapacak
    metin çok az — tek sayfa, kısa bir paragraf.
  - **ASIL KARAR NOKTASI — client-render mi statik HTML mi:** Mimari
    değişiklik GEREKMİYOR, `main.tsx` zaten router'sız path eşlemesi
    yapıyor (`/game/:id`, `/davet/:token`) ve `vercel.json` rewrite'ı her
    path'i `index.html`'e yolluyor; üçüncü bir dal birkaç satır. AMA
    client-side render Googlebot'u memnun eder (JS render ettiği kanıtlı —
    SERP snippet'i `Setup.tsx`'in sayfa içi metninden geliyor, meta
    description'dan DEĞİL), **JS çalıştırmayan AI/LLM crawler'ları için
    boş sayfa demektir** — yani sorunu doğuran şeyi tam olarak ıskalar.
    Gerçek çözüm build-time statik üretim (og-image script'iyle aynı
    kalıp, `dist/nasil-oynanir/index.html`). Vercel'in statik dosyayı
    rewrite'tan ÖNCE servis ettiği DOĞRULANMALI (dokümanda öyle yazıyor,
    bu ortamdan test edilemedi).
  - **Etki analizi — derleyicinin göremeyeceği üç bağ (yapmadan önce
    oku):** (1) **`mobile/app/test/help_text_parity_test.dart:31` doğrudan
    `src/components/HelpModal.tsx`'i OKUYOR** ve `<Section title="…">` /
    `<QuickItem icon="…">` regex'leriyle tarıyor — içeriği başka bir
    dosyaya çıkarmak o testi düşürür, üstelik web'e dokunduğun için hiç
    bakmayacağın mobil tarafta; (2) içerik TEK KAYNAKTA kalmalı, modal ve
    sayfa AYNI bileşeni tüketmeli — iki kopya bu projenin en sık
    tekrarlayan hata sınıfı (renk paleti/rütbe tablosu/hukuki metin üçü de
    böyle ayrışmıştı); (3) yeni sayfanın KENDİ title/description'ı olmalı,
    yoksa SPA'nın genel meta'sını miras alır ve SEO kazancının yarısı
    gider. Ayrıca `sitemap.xml` (şu an tek URL) ve PWA precache listesi
    (`vite.config.ts`) kontrol edilmeli; Flutter portunun `help_modal.dart`
    metinleri de aynı kaynağa bağlı.
  - **Bu bir REINDEX işi DEĞİL:** aynı bölümün (SEO) "marka karışıklığı
    reindex ile çözülmez, organik arama/backlink ile zamanla düzelir"
    notu hâlâ geçerli — bu sayfa o süreci hızlandıran bir içerik işi.



## ✅ KAPANDI — Tahta çiziminin önbelleğe alınması (26 Ağustos 2026)

Bu madde **yapıldı** ve tam da burada tarif edilen çözümle: her ayırt edici
hücre deseni bir kez rasterleştirilip `drawImageRect` ile basılıyor.
Ölçülen sonuç: ekranın bir boyaması **~340 blur → 26**, ikinci boyaması
**3** (yalnızca önbelleğe alınmayan tahta kartı, o da analitik hızlı yolda),
30 adımlık sürüklemede **0**.

Madde "mağaza turundan sonraya" bırakılmıştı; kapalı testin ilk
kullanıcıları *"ekran donuyor / taşları sürerken ağır çekim"* deyince
öne alındı — yani erteleme kararı sahada çürüdü. Kaydı:
`mobile/docs/parca-log.md` → **Parça 144**.

Buradaki "riski görsel, piksel golden'ı yok" endişesi de çözüldü: görsel
regresyon riski bir testle DEĞİL, yapıyla kapatıldı — rasterleştirmede eski
çizim kodunun ta kendisi koşuyor, yani "eski yol / yeni yol" diye iki çizim
kodu yok.

---

## Tahtada çift dokunuşla yakınlaştırma (26 Ağustos 2026, testçi isteği)

Kapalı testteki bir kullanıcı bildirdi (kullanıcının aktardığı sözlerle):
*"ekran küçük olduğu için kareleri tutturmakta zorlandığını söyledi.
Kelimelik'te board'a çift tıklama zoom yapıyor, tekrar çift tık geri zoom
yapıyor. Bu özelliğin iyi olacağını söyledi."*

**Ertelendi, sebebi net:** o gün asıl sorun sürüklemenin akıcılığıydı
(Parça 144) ve kullanıcı ikisini ayırdı — *"bu iş için ayrıca bakmamız
lazım. Şimdi asıl sorun taşların akıcı hareketini çözmek."* Akıcılık
düzeldiğine göre "tutturamama" şikâyetinin ne kadarının hızdan, ne
kadarının gerçekten hücre boyutundan geldiği ARTIK BİLİNMİYOR — önce
yeni paketle tekrar sorulmalı, sonra yapılmalı.

**Yapılırsa dikkat edilecekler (bu projede ölçülmüş tuzaklar):**
- Yakınlaştırma sürükle-bırakın koordinat çevrimini bozar: `game_screen`
  global noktayı hücreye `stride = (en + gap)/13` ile çeviriyor; ölçek
  devreye girerse o formül ve `_nearbyDraftCell` birlikte güncellenmeli.
- Çift dokunuş, mevcut jest ayrımıyla (dokunuş ↔ sürükleme eşiği, fare 6 /
  parmak 10) çakışmamalı.
- İki oyun ekranı bu deseni paylaşıyor (`game_screen` ↔
  `online_game_screen`) — biri değişirse öteki de.
- Web'de karşılığı YOK; önce web'de mi yapılacak, yoksa bilinçli bir port
  farkı mı olacak — karar verilmeli (kural: kaynak web'dir).

## (arşiv) Tahta çiziminin önbelleğe alınması — özgün kayıt (24 Ağustos 2026)

Kullanıcı Android'de bildirdi: *"YZ ile oyun açtığında board'un ekrana
gelmesi takılarak oluyor"* — girişli açılışta da, ama Canlı bekleyen oyunda
olmuyor (orada ekran geçiş sırasında "Yükleniyor…" gösterip tahtayı SONRA
çiziyor).

**Ölçülen sebep (koddan):** tahtanın tek seferlik ilk çizimi pahalı — 169
hücrenin her biri `MaskFilter.blur`lu **iki** iç gölge + bir kırpma katmanı
(`NeoBox` → `_InsetShadowPainter`), kartın kendisi de blur **20/14/60**'lık
üç gölge boyuyor. Toplam ~340 bulanıklaştırma, hepsi route geçiş
animasyonunun ortasında.

**Bugün yapılan (yeterli ama kök çözüm DEĞİL):** geçiş animasyonu sürerken
`GameScreen` yalnızca "Yükleniyor…" gösteriyor (Canlı oyun ekranıyla aynı
görünüm — kullanıcı isteği: *"her yerde aynı deneyim"*), tahta animasyon
bitince çiziliyor. Maliyet ortadan kalkmıyor, hareketli karelerin dışına
taşınıyor.

**Kök çözüm:** hücre çizimi ÖNBELLEĞE alınmalı. Boş hücrenin görünümü
yalnızca ~7 çeşit (tarafsız, dört oyuncu bölgesi, altın bölge, merkez) ve
hepsi aynı boyutta — her çeşidi bir kez `ui.Image`'a çizip 169 kez
`drawImageRect` ile basmak, 340 blur'u 7'ye indirir. Riski görsel (parite
testlerinde piksel golden'ı YOK, yani regresyonu yalnızca göz yakalar), o
yüzden mağaza turundan sonraya bırakıldı.
