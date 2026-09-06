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

- **YZ zorluk seviyesi (Kolay/Normal/Zor) + seviyeye göre k-lig puanı
  (5 Eylül 2026, kullanıcı fikri — ÖLÇÜLDÜ, bilinçli ertelendi):**
  Kullanıcı: *"İleride belki seviye seçtirebiliriz. Kolay, Normal, Zor gibi.
  Kazandığı puanları da ona göre veririz. Kolay 1, Normal 2, Zor 3 puan
  gibi."* Aynı turda "şimdilik böyle kalsın" denildi.

  **Kadran zaten ölçüldü — uygulayan yeniden ölçmesin.** Mekanizma:
  `findAIMove` en iyi hamle yerine **en iyi N hamleden birini** rastgele
  seçsin (tüm hamleler arasından düzgün rastgele DEĞİL — o YZ'yi rakip
  olmaktan çıkarıyor). 24'er oyun, oyuncu 0 mevcut YZ (N=1), oyuncu 1 top-N:

  | N | P1 kazanma | Ort. P0 | Ort. P1 | P1 ort. hamle puanı |
  |---|---|---|---|---|
  | 1 (bugünkü) | %54 | 221 | 223 | 12,3 |
  | 3 | %25 | 247 | 194 | 10,5 |
  | 5 | %21 | 249 | 182 | 9,7 |
  | 10 | %8 | 252 | 168 | 8,9 |
  | 25 | %0 | 275 | 130 | 7,0 |
  | hepsi | %0 | 295 | 116 | 6,1 |

  ⚠ **Bu tablo YZ↔YZ'dir, insan oranı DEĞİL.** N=1 satırındaki %54 iki AYNI
  motorun birbirine karşı oynaması, yani yapısı gereği ~%50 — bilgi taşımaz,
  yalnızca sıfır çizgisi. Gerçek insan oranı ayrı ölçüldü: yerel 2 kişilik
  oyunlarda **%48,7** (17 Ağustos sonrası, 429 oyun; Eylül'de %41,4).
  Erteleme kararı bu ikinci sayıya dayanıyor — YZ kabaca başa baş.

  Kadranın en verimli adımı N=1→3 (kazanma %54→%25); sonrası azalan getiri.
  Seviye eşlemesi için makul başlangıç: Zor=1, Normal=3, Kolay=10.

  **Bedeli küçük değil, üç kalem:**
  1. **Determinizm.** `findAIMove` bugün deterministik ve golden vector'lar
     "aynı girdi → aynı hamle" varsayımına dayanıyor. Rastgelelik girdinin
     PARÇASI olmalı: web ile port AYNI sırada AYNI sayıda rastgele değer
     tüketmeli (torba/karıştırma için depo bunu zaten yapıyor, desen var).
     `npm run verify-edge-engine-parity` de rastgeleliği enjekte edilebilir
     hâle getirmeden çalışamaz.
  2. **Motorun ÜÇ kopyası** (`src/utils/ai.ts`, portun `find_move.dart`'ı,
     `supabase/functions/_game/ai.ts`) + golden vector'lar + parite kapısı
     birlikte değişir. Edge kopyası ayrıca `play-ai-turn` yeniden deploy
     ister.
  3. **k-lig puanı ÜÇ yerde yaşıyor:** `src/utils/leaguePoints.ts`
     (rank 1 → +2, rank 2 → +1 yalnızca 2 kişilik değilse, teslim → -2),
     portun karşılığı, VE `leaderboard`/`player_stats` SQL view'ları — o
     yorumun kendisi "view'larla aynı formül" diyor. Seviyeye göre puan
     vermek üçünü birden değiştirmek demek, yani bir migration da gerekir.

  **KAPSAM (5 Eylül 2026, kullanıcı kararı — aynı turda bir kez düzeltildi):**

  | Oyun türü | Seviye seçimi | Puan |
  |---|---|---|
  | **Yerel YZ oyunu, 2 kişilik** | VAR | seviyeye göre |
  | **Yerel YZ oyunu, 4 kişilik** | VAR | seviyeye göre |
  | **Canlı oyun, 4 kişilik (4. koltuk YZ)** | YOK — her zaman Normal | bugünkü formül |
  | **Canlı oyun, 2 kişilik** | — (masaya YZ konamıyor) | bugünkü formül |

  ⚠ İlk ifade *"sadece 2 kişilik"* idi; kullanıcı düzeltti: *"4 kişilik
  oyunda default normal olacak dedim ama CANLI oyunları kastettim. YZ oyun
  açmada 2 veya 4 farketmez seviye seçimi olacak ve aynı puan mantığı
  geçerli olacak."* Yani ayrım oyuncu sayısında DEĞİL, **yerel ↔ Canlı**
  ayrımında. Sebebi de doğal: Canlı oyundaki YZ hamlesi sunucuda
  (`play-ai-turn`) hesaplanıyor, orada oyuncunun seçtiği bir seviye kavramı
  yok.

  Ölçüldü, kapsam tutarlı: yerel oyunların **758'inin 758'inde** YZ var ve
  kadro istisnasız — 2 kişilikte 1 insan + **1 YZ** (649 oyun), 4 kişilikte
  1 insan + **3 YZ** (109 oyun); saf-insan yerel oyun SIFIR. Yani 4
  kişilikte seçilen seviye ÜÇ YZ'ye birden uygulanır.

  **PUAN TABLOSU (5 Eylül 2026, kullanıcı revizyonu — KESİN):**

  | Oyun | 1. sıra | 2. sıra |
  |---|---|---|
  | Canlı 4 kişilik (YZ'li), seviye YOK → Normal | **+2** | **+1** |
  | Yerel YZ 2 kişilik — Kolay / Normal / Zor | **1 / 2 / 4** | yok (bugün de yok) |
  | Yerel YZ 4 kişilik — Kolay / Normal / Zor | **1 / 2 / 4** | **0 / 1 / 2** |

  ⚠ **Zor = 4, 3 değil.** Bilinçli: zoru yenmek orantısız ödüllendiriliyor.
  Sonradan "1/2/3 daha simetrik" diye düzeltilmesin.

  ✅ **Normal, HER hücrede bugünkü değere eşit** (2 kişilik galibiyet +2;
  4 kişilik +2/+1; Canlı +2/+1). Bunun büyük bir pratik sonucu var:
  **geçmiş satırlar için veri taşıma GEREKMİYOR** — seviyesiz kayıtlar
  (bugüne kadarki her şey + tüm Canlı oyunlar) doğal olarak Normal dalına
  düşer ve puanları değişmez. Yani migration "kolon ekle + `case` yaz"dan
  ibaret, geriye dönük yeniden hesaplama yok.

  ⚠ Yine de migration ŞART: puan `leaderboard`/`player_stats` SQL
  view'larında hesaplanıyor, yani view o oyunun seviyesini görmek zorunda →
  `games`e bir seviye alanı gerekiyor.

  ⚠ **Tabloda karşılığı olmayan tek hücre: TESLİM OLMA.** Bugün her koşulda
  -2 ve revizyonda konuşulmadı. Varsayılan davranış "-2 olarak kalsın"
  olmalı; seviyeye göre ölçeklenmesi istenirse ayrıca sorulmalı.

  **➜ Fazlı uygulama planı ve etki haritası: `ROADMAP.md` → madde 23 (6 Eylül
  2026).** Karar verildi (aynı gün, kullanıcı): **Normal = bugünkü motor,
  dokunulmuyor; Kolay'da YZ ~%30, Zor'da YZ ~%70 kazanacak** (YZ'nin insana
  karşı oranı — bugünkü ~%51 sıfır çizgisi). Yani yukarıdaki "Zor=1,
  Normal=3, Kolay=10" başlangıç eşlemesi GEÇERSİZ: bugünkü motor Zor değil
  Normal; Zor için daha güçlü bir motor gerekiyor (plan Faz 5). Bu madde
  plan kapanana kadar burada kalır.

  **Zorluk algoritmasının kendisi (hangi seviye = hangi N) BİLEREK
  ertelendi** — kullanıcı: *"Zorluk algoritmasını yaptığımız zaman
  değerlendiririz."* Yukarıdaki ölçüm tablosu o değerlendirmenin girdisi.

  **✅ FAZ 0 KOŞUMU (6 Eylül 2026) — alet repoda, yukarıdaki 24 oyunluk
  tablo ARTIK GEÇERSİZ, bunu oku.** `npm run simulate-ai-levels` (ROADMAP
  23.3 → Faz 0). N başına **200 oyun**, tohum 1-200 (her N aynı tohumlarla,
  yani eşli karşılaştırma), **koltuk değişimli** (çift oyunlarda top-N 2.
  koltukta/köşe 3, teklerde 1. koltukta/köşe 0). Üretim tarafı reducer'ın
  kendi `AI_PLAY`'iyle oynadı; top-N tarafı betikteki kopya (her N'in ilk 5
  oyununun HER hamlesinde liste başı ↔ üretim `findAIMove` birebir doğrulandı).

  | N | Top-N kazanma | %95 GA | Ort. Normal | Ort. Top-N | Top-N ort. hamle puanı |
  |---|---|---|---|---|---|
  | 1 (bugünkü) | %52 | %45–%59 | 224 | 216 | 12,1 |
  | 2 | %44 | %37–%51 | 229 | 207 | 11,3 |
  | 3 | %36 | %29–%42 | 233 | 196 | 10,8 |
  | **4** | **%33** | %27–%40 | 233 | 190 | 10,4 |
  | 5 | %22 | %17–%28 | 244 | 178 | 9,7 |
  | 6 | %22 | %16–%28 | 247 | 178 | 9,6 |
  | 8 | %20 | %15–%26 | 250 | 167 | 8,9 |

  (N=1'de 2 berabere, kazanma oranı beraberlik dışı.) **N=6 ve N=8
  satırları 6 Eylül 2026 gecesi eklendi** — kullanıcı Preview'da iki Kolay
  oyun oynayıp *"bana pek kolay gelmedi"* dedi (skorlar 237-210 ve 50-47);
  eğri 5-8 arasında %20-22'de düzleşiyor, N=10'da %8'e düşüyor. Kullanıcı
  kararı: **N=4 kalsın**, saha ölçümü (`admin_ai_balance`) konuşsun; N=8
  bir kademe aşağısı olarak hazır. İki bulgu:

  1. **24 oyunluk eski tablo N=3'ü fazla zayıf göstermişti:** %25 değil
     **%36** (GA %29-42). 24 oyunun güven aralığı ±%17'ydi, yani fark
     gürültü — ama "N=3 hedefin tam üstünde" hükmü buna dayanıyordu ve
     YANLIŞTI. Hedef YZ ~%30 için (bugünkü motor sahada ~%51 → YZ↔YZ
     sıfır çizgisi %52 ile ÇAKIŞIYOR, vekil doğrudan okunabilir) tabloda en
     yakın değer **N=4 (%33)**; N=3 (%36) üstünde, N=5 (%22) altında.
     **Kolay için başlangıç N=4** (kullanıcı 6 Eylül 2026, önce *"36 ok"*
     deyip N=3'e döndü, sonra *"Senin önerin 4 daha mantıklı"* — nihai
     karar N=4). N=3 ile N=4'ün aralıkları örtüşüyor —
     son sözü saha (`admin_ai_balance` seviye kırılımı) söyler: Kolay'da YZ
     %30'un belirgin üstünde kalırsa N=5, altına düşerse N=3.
  2. **İlk koltuk avantajı ÖLÇÜLDÜ ve büyük:** N=1'de (iki aynı motor) ilk
     koltuk **64/100**, ikinci koltuk **39/100** kazandı — ~12 puanlık fark,
     dört N'in hepsinde aynı yönde. Yerel 2 kişilik oyunda insan HER ZAMAN
     1. koltuktadır (köşe 0), YZ 2. (köşe 3); yani sahadaki %48,7 insan
     oranı bu avantajı zaten İÇERİYOR. Bu yüzden Kolay'ın N'i seçilirken
     koltuk-ortalamalı sütun okundu (delta oradan), yalnızca 2. koltuk
     sütunu değil. Eski tabloda top-N hep 2. koltuktaydı — %25'in bir
     bölümü koltuktan geliyordu, N'den değil.

  ⚠ **Sorgu tuzağı — bu maddeyi uygulayan mutlaka okusun:** `games.players`
  jsonb'si KOLTUK sırasına değil **SIRALAMAYA (rank) göre** saklanıyor.
  "Rakip YZ mi?" diye 2. elemana bakan bir analiz sorgusu yanlış sonuç
  verir (5 Eylül 2026'da tam olarak bu oldu: yerel oyunların yarısı
  "insan rakip" gibi göründü). Doğrusu dizinin TAMAMINA bakmak:
  `players @> '[{"is_ai": true}]'`.

  ⚠ **Ürün tarafında bir kırılma:** yerel oyun skorları k-lig puanına
  akıyor. YZ zayıflarsa bundan sonraki skorlar geçmişle kıyaslanabilir
  olmaktan çıkar — lider tablosunda eski/yeni dönem karışır. Ya bilerek
  kabul edilmeli ya da bir sürüm sınırına denk getirilmeli. Seviyeye göre
  puan vermek (Kolay 1 / Normal 2 / Zor 3) bu sorunu ZATEN hafifletiyor;
  ikisi bu yüzden birlikte düşünülmeli, ayrı ayrı değil.

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


- **Miras isimler: `sharedxp_pending_profile` ve kalan `harfik` izleri (2
  Eylül 2026, ölçüldü — ertelendi):** Projenin soyağacı **SharedXP →
  Harfik → Kelimeki** ve iki ad hâlâ canlı kodda duruyor. Kullanıcı
  kayıt akışını okurken bunu bizzat yakaladı (*"biz sharedXP değil Kelimeki
  projesinde çalışıyoruz"*) — yani bu bir kozmetik borç değil, okuyanı
  yanlış projeye götüren bir işaret.
  - **`sharedxp_pending_profile`** — kayıt metadata'sının anahtar adı.
    Nereden geldiği yazılı: `20260629000300_profile_name_fields.sql`
    başlığı *"Harfik signUp, meta_data içinde `sharedxp_pending_profile`"*
    diyor. Bugün **üç yerde birden** sözleşme: `src/lib/api.ts` (`signUp`),
    `mobile/app/lib/src/data/auth_service.dart` (`signUp`) ve
    `handle_new_user`'ın DÖRT sürümü (`20260629000300`, `20260729113942`,
    `20260816073403`, `20260821094121`).
  - **Neden tek satırlık bir rename DEĞİL:** anahtar, istemci ile trigger
    arasındaki sözleşme. Play'de yayında olan eski istemci (1.0.5) eski
    anahtarla yazmaya devam eder; trigger tek anahtara çevrilirse o
    kayıtlarda ad/soyad boşalır. Doğru sıra: (1) trigger **iki anahtarı
    birden** okusun (`coalesce(yeni, eski)`), (2) web + port yeni anahtara
    geçsin, (3) eski istemciler tükendiğinde eski dal silinsin. 3. adım
    ancak `mobile_min_supported_version` eski sürümü kestikten sonra.
  - **Ne zaman:** `handle_new_user`'a zaten dokunulacak ilk PR'da — en
    güçlü aday **Google ile giriş** (o iş trigger'ı değiştirmek zorunda,
    bkz. `ROADMAP.md` → madde 17). Ayrı bir PR açmak bedelini iki
    katına çıkarır.
  - **`harfik` izlerinin ÖLÇÜLEN durumu (2 Eylül 2026):**
    - **Canlı veritabanı TEMİZ.** `pg_proc`/`information_schema`/
      `storage.buckets` taraması `harfik` içeren tek bir ad döndürmedi —
      son kalan `harfik_points` fonksiyonu `20260721203236` ile
      `kelimeki_points`e çevrilmişti.
    - **Eski migration dosyaları `public.harfik_points(...)` çağırıyor**
      (`20260628090300_seed_dictionary.sql` içinde 92 bin kez, tarihsel
      sözlük tohumlaması). Bunlar **DEĞİŞTİRİLMEMELİ**: uygulanmış geçmişi
      yeniden yazmak, tekrar oynatıldığında bugün var olmayan bir isme
      dayanmaya çalışmak demek. Tarama yapan bir sonraki oturum bu 92 bin
      eşleşmeyi "yapılacak iş" sanmasın.
    - **Kodda tek canlı iz:** `src/utils/gameSync.ts` → `LEGACY_PENDING_KEY
      = 'harfik:pending-games'` — 20 Temmuz rebrand'inde mahsur kalan
      kuyruğu kurtaran `migrateLegacyQueue`. **Bilerek kalmalı**: adı eski
      OLDUĞU İÇİN işe yarıyor.
    - **`harfik.vercel.app` HÂLÂ YAYINDA ve canlı uygulamayı sunuyor** —
      `curl` ile ölçüldü: `kelimeki.com` ile **aynı derleme sha'sını**
      (`62610f7`) döndürüyor, yani Vercel projesinin adı hâlâ `harfik` ve
      bu onun otomatik `<proje>.vercel.app` alan adı. `kelimeki.vercel.app`
      ise **boşta** (`404 DEPLOYMENT_NOT_FOUND`), yani ad alınabilir.
      SEO tarafı zaten korunuyor: sayfa `canonical`/`og:url` olarak
      `https://kelimeki.com/` veriyor.
    - ⚠ **Bu oturumun erişemediği yer:** Vercel MCP'siyle görünen hesapta
      (`alpcapa's projects`, hobby) TEK proje var ve adı **`sharedxp`**
      (repo `alpcapa/SharedXP`) — Kelimeki'yi yayınlayan proje bu hesapta
      görünmüyor. Yani yeniden adlandırma **panelden elle** yapılacak;
      ajanla yapılamaz.
  - **Vercel projesini yeniden adlandırma planı** (yapılmadı, kullanıcı
    kararı bekliyor): Settings → General → Project Name `harfik` →
    `kelimeki`. Sonrası ölçülmeli, varsayılmamalı: (1) `kelimeki.com` özel
    alan adı olduğundan üretim adresi DEĞİŞMEZ; (2) `harfik.vercel.app`
    yayından kalkar — kırılacak bir yer var mı diye **Supabase Auth →
    URL Configuration**'daki Site URL / Redirect URLs listesi ve varsa
    kayıtlı Google/Firebase OAuth redirect'leri ÖNCE okunmalı; (3)
    `main`'e bir sonraki merge'den sonra `curl -s https://kelimeki.com/ |
    grep kelimeki-build` ile deploy zincirinin sağlam kaldığı doğrulanmalı.

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
