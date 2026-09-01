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


### Bu listeden çıkanlar (yeniden açılmasın)

- **Hesap silme (KVKK "unutulma hakkı")** — ✅ yapıldı 25 Ağustos 2026.
  Hesap Ayarları › "Hesabımı Sil" + `delete-my-account`, web ve port.
  Kaydı: `docs/decisions/account-deletion.md`. Bir sonraki oturum bunu
  "hukuki eksik" ya da "mağaza blokeri" diye YENİDEN AÇMASIN — hukuken
  zaten zorunlu değildi, mağaza şartı da karşılandı.
- **Taranabilir `/nasil-oynanir` sayfası** — ✅ yapıldı 31 Ağustos 2026
  (#386), build-time statik üretim; içerik `HelpModal`'dan İTHAL ediliyor,
  kopyalanmıyor. Kaydı: `ROADMAP.md` madde 6.
- **`game_finishes.anon_id`** — ✅ yapıldı 31 Ağustos 2026. Huniye "Bitiren
  Cihaz" (`finishers`) eklendi; `anon_id` YALNIZCA `user_id` null iken
  yazılıyor (trigger + CHECK), yani gizlilik taahhüdü ayakta. Kaydı:
  `docs/decisions/admin-panel.md` → "Bitiren Cihaz".
  ⚠ Geriye dönük doldurulamayan kolonların listesi hâlâ geçerli: bir sonraki
  ölçüm boşluğu da reklam harcamasından ÖNCE kapatılmalı.


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

## ✅ YAPILDI — Tahtada çift dokunuşla yakınlaştırma (26 Ağustos 2026, testçi isteği → 1 Eylül 2026'da yapıldı)

1 Eylül 2026'da önce PORTA uygulandı (1.0.5, `ui/game/board_zoom.dart`),
AYNI GÜN kullanıcı kararıyla WEB'e de taşındı (*"web'e de uygulama kararı
aldım. Her yerde aynı deneyim olsun."*) — yani buradaki "web'de mi, yoksa
bilinçli port farkı mı" sorusunun cevabı: **iki yüzeyde de var.**
Web kaynağı `src/utils/boardZoom.ts` + `src/hooks/useBoardZoom.ts`;
"dikkat edilecekler" listesinin tek tek nasıl karşılandığı ve portun
ölçümleri: `mobile/docs/parca-log.md` → Parça 175. Cihaz kontrol listesi:
`mobile/TESTING.md` § 24; web tarafının kapıları `tests/smoke.spec.ts` →
"tahta zoom" (6 test).

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
