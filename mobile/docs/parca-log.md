# Parça Günlüğü — AKTİF

> **Yeni girişler BURAYA**, en yeni en başta. Bu cilt **Parça 139'dan itibaren**.
>
> **Hangi cilt?** Parça 1-48 → `parca-log-1-48.md` · 49-109 →
> `parca-log-49-109.md` · 110-138 → `parca-log-110-138.md` · **139+ →
> `parca-log.md` (aktif, bu dosya)**. Kod yorumlarındaki "bkz.
> mobile/CLAUDE.md, Parça N" atıfları bu DÖRT dosyadan birine düşer.
>
> **26 Ağustos 2026:** aktif cilt 151 KB'a çıkıp uyarı bandına girdiği için
> 110-138 donduruldu; bu dosya 12 KB'a indi.
>
> ⚠ **Bir cildi BAŞTAN SONA OKUMA — `grep` ile ara.** Ciltler tam da bu
> yüzden var: tek bir atıf için yüz binlerce bayt okumak bağlamı yakar.
>
> **Neden ciltlere ayrıldı (24 Ağustos 2026):** tek dosya 714 KB'a (9.800
> satır) çıkmıştı — 24 Ağustos'taki context split'in ÇÖZDÜĞÜ sorun yer
> değiştirip burada birikmişti. Kesimler bölüm/parça sınırlarından yapıldı,
> hiçbir satır değişmedi. Tekrarını önleyen kontrol:
> `npm run check-doc-size` (bkz. kök `CLAUDE.md` → "Doküman Boyutu
> Bütçesi") — bu cilt de sınıra gelince yenisi açılır.

   - ✅ **Parça 145 — "Buradan başla" balonu: ilk hamlenin nereye yapılacağı
     (26 Ağustos 2026, kullanıcı isteği: *"ilk boş tabloda evin yanına doğru
     bir balon koyabilir miyiz? Buradan başla yazsın"*):** Kapalı testte
     insanların kuralı değil **ilk hamleyi nereye yapacaklarını**
     bulamadıkları görüldü. `HomeMark` zaten duruyor ama ne olduğunu söyleyen
     bir şey yok — tanıtımda okunan cümle, tahtaya bakarken hatırlanmıyor.
     Parça 143'ün (tanıtımda DEVAM düğmesi) aynı huninin bir sonraki
     tıkacı.

     **Web ÖNCE yazıldı, port ona göre taşındı** — `mobile/CLAUDE.md`'nin
     "Sorun bildirildiğinde İLK ADIM: web'de bu nasıl yapılmış?" kuralı yeni
     özellik için de geçerli: kaynak web'de olmayınca kaynağı önce web'de
     ÜRETMEK gerekiyor, yoksa port kanonik hâle gelir ve iki taraf ayrışır.

     **Ölçülen tuzak — hücre konumu YÜZDEYLE ifade edilemez:** ızgarada 12
     adet 3px boşluk var, yani bir hücre `100%/13` DEĞİL `(100% - 36px)/13`.
     İlk sürüm yüzde kullanıyordu ve balonu dikeyde **~9px** kaydırıyordu
     (Chromium, 656px ızgara, tarayıcıda ölçüldü). Konum artık tam
     geometriden: web'de `calc`, portta `stride = (en + gap)/13` — ki bu
     `game_screen.dart`'ın dokunuş→hücre çevrimiyle **aynı formül**.
     Köşe numarası/X2 filigranları bu farkı görmezden gelebiliyor çünkü
     4×4/5×5 blokları kabaca kaplıyorlar; tek bir HÜCREYE hizalanan her yeni
     katman bu formülü kullanmalı.

     **Görünme koşulu — ilk sürüm YETERSİZDİ, kullanıcı aynı turda düzeltti**
     (*"taşı koyarken değil taşı kaldırdığı anda balon gitmeli"*). İlk hâli
     yalnızca taş KONUNCA gizliyordu; oysa balon, oyuncu taşı havaya
     kaldırdığı andan itibaren bırakma hedefinin yanında dikkat dağıtıyor.
     Dört parça: (1) tahtada tek taş yok, (2) bu turda konmuş TASLAK taş da
     yok, (3) **taş kaldırılmadı** — rafta seçili DEĞİL ve sürüklenmiyor,
     (4) sıra bir İNSANDA. Kalıcı "görüldü" bayrağı YOK: koşul kendi kendini
     sınırlıyor ve bir bayrak cihaz değiştiren oyuncuyu ipuçsuz bırakırdı.

     **"Kaldırma" İKİ sinyal istiyor ve bu bir tuzak:** sürükleme
     `selectedTile`ı SET ETMİYOR — reducer'a `SelectTileAction` yalnızca
     HAREKETSİZ dokunuşta gidiyor (`endDrag`in `!moved` dalı, iki tarafta da).
     Yani tek başına `selectedTile`a bakmak dokunup seçmeyi kapsar,
     sürüklemeyi kapsamaz.

     **Portta sinyal bool bir prop DEĞİL, `ValueListenable`:** Parça 23
     sürükleme boyunca `BoardWidget`ın (169 hücre + bölge hesabı) yeniden
     inşasını bilerek durduruyor; bool bir prop, sürüklemenin başında ve
     sonunda ekranın `setState`'ini gerektirirdi. Dinlenebilir geçilince
     yalnızca balon katmanı dinliyor, tahta hiç yeniden inşa edilmiyor.
     Tipi `Object?` çünkü ekranın `_Ghost`u private — Dart jenerikleri
     kovaryant olduğundan `ValueNotifier<_Ghost?>` doğrudan geçiyor.
     Web'de aynı iş düz bir `tileLifted` prop'u, çünkü `Board` zaten
     hayaletten türeyen propları (`dragOverKey`) her harekette alıyor.

     **Regresyon — ve testin kendisi bir ders:** iki tarafta da iddia kendi
     formülüne değil **gerçek ev karesinin kutusuna** karşı (web'de
     `[data-cell="0,0"]`, portta ızgaranın ilk `NeoBox`ı + o kutunun
     gerçekten (0,0) olduğunu doğrulayan bir kurulum kontrolü). İlk yazılan
     dikey tolerans **1.5px**'ti ve **yanlış (yüzde tabanlı) sürümü de
     geçiriyordu** — negatif eş kurulurken yakalandı, 0.75px'e çekildi.
     *Gevşek bir iddia hiç iddia olmamasından daha kötü: yeşil yanar ama
     hiçbir şey kanıtlamaz.* Portta ayrıca üç negatif dal (tahtada taş var /
     taslak taş var / sıra YZ'de).

     **Yan değişiklik:** `Rack.tsx`'in taş sarmalayıcısına `data-rack-tile`
     eklendi — rafın ilk çocuğu taş DEĞİL etiket satırı olduğundan test
     sessizce yanlış öğeye tıklıyordu (`data-cell`/`data-rack` ile aynı
     amaç).

     **Doğrulama sınırı:** web tarafı Chromium'da GERÇEKTEN ölçüldü (konum +
     negatif eş); portun testleri bu ortamda koşturulamıyor (Flutter SDK
     yok), kanıt CI. Cihaz kontrolü: `mobile/TESTING.md` 23.

   - ✅ **Parça 144 — "Board alanında her şey ağır": bir boyamanın MALİYETİ
     (26 Ağustos 2026, kapalı testte 3-4 kişiden ekran donması bildirimi;
     kullanıcı yanında oynayarak doğruladı):** Kullanıcının sözleri:
     *"taşları sürerken ağır çekim hareket ediyor, akıcı değil, takılmalar
     oluyor. Web'de çok hızlı ve kesintisiz oynanıyor"* ve teşhisi kesen
     ikinci cümle: *"Her yerde gecikme var. rafta taşlar da ağır hareket
     ediyor. Geri tuşu da ağır cevap veriyor, skor kutusuna basınca skor
     kart da yavaş açılıyor. Board alanında her şey ağır."*

     **Bu, aynı sorunun ÜÇÜNCÜ teşhisi ve ilk İKİSİ YANLIŞTI — ders bu
     dosyaya bu yüzden yazılıyor:**

     | Tur | Bakılan gösterge | Verdiği cevap | Gerçek |
     |---|---|---|---|
     | 1 | `BoardWidget` **build** sayısı | "sürüklemede yeniden inşa YOK" | doğru ama İLGİSİZ |
     | 2 | `RepaintBoundary` **simetrik boyama** sayacı | "sınır işe yarıyor" | doğru ama İLGİSİZ |
     | 3 | **`MaskFilter.blur` çağrı sayısı** | ~340 / boyama | asıl sebep |

     İlk ikisi *"tahta ne kadar SIK boyanıyor?"* sorusunu ölçüyordu.
     Kullanıcının ikinci cümlesi soruyu değiştirdi: geri tuşu ve modal
     açılışı da ağırsa, sorun sıklık değil **bir boyamanın kendi
     maliyeti**. Rota animasyonunun her karesi zaten tam bir boyamadır —
     `RepaintBoundary` oraya hiç yardım edemez.

     **Kök sebep:** `neo_box.dart`'ın iç gölgeleri, kaydırılmış bir RRect'in
     dışını ifade eden **evenOdd bir PATH** üzerine `MaskFilter.blur`
     uyguluyor. Bunun analitik bir hızlı yolu YOK: Impeller/Skia her biri
     için offscreen doku ayırıp gerçek bir gauss geçişi koşuyor. Tahtanın
     169 boş hücresi × 2 iç gölge = **kare başına ~340 gerçek blur** (üstüne
     169 antialias `ClipRRect`). Web'de aynı görüntü bedava, çünkü CSS
     `inset box-shadow`u tarayıcı bir kez rasterleştirip yeniden kullanıyor.

     Karşılaştırma için: tahta KARTININ kendi gölgeleri (blur 60 dahil) bu
     listede DEĞİL — onlar `drawRRect` üzerinde, yani Impeller'ın analitik
     hızlı yolunda. Pahalı olan büyük blur değil, **keyfi path üzerine
     blur**.

     **Düzeltme — raster önbelleği (`neo_box.dart`):** aynı gölge deseni +
     aynı boyut + aynı piksel yoğunluğu → aynı görüntü. Bir kez
     `Picture.toImageSync` ile rasterleştirilip tutuluyor, sonraki her
     boyamada tek `drawImageRect`. Tahtanın ~7 ayırt edici hücre deseni var,
     yani 338 blur → **~14 blur (bir kez) + 169 blit**. `ClipRRect`ler de
     gitti (kırpma zaten görüntünün içinde).

     **Görsel BİREBİR aynı kalmak zorunda değil — YAPISAL olarak öyle:**
     rasterleştirmede ESKİ çizim kodunun ta kendisi koşuyor (dış gölge +
     dolgu için aynı `BoxDecoration`, iç gölge için aynı
     `_InsetShadowPainter`). "Eski yol / yeni yol" diye iki çizim kodu YOK,
     dolayısıyla sessizce ayrışamazlar.

     **Güvenlik ağı:** `toImageSync` bu platformda desteklenmiyorsa ya da
     yüzey tek girdi için fazla büyükse (`_kMaxEntryPx`) önbellek `null`
     döner ve doğrudan çizime düşülür — önbellek hiçbir koşulda görüntüyü
     bozamaz, yalnızca hızlandırır. Büyük yüzeyler (modal kartları, tahta
     kartı) bilinçli olarak önbellek DIŞI: onlar zaten ekranda bir-iki tane
     ve gölgeleri hızlı yolda.

     **Regresyon:** `test/game_screen_test.dart`'a yeni bir iddia —
     ekranın BİR boyamasında kaç blur çizildiğini sayıyor (`< 80`), sonra
     tahtayı `markNeedsPaint` ile yeniden boyatıp sayının artmadığını
     (`< 20`) ölçüyor. **Araç canlılığı önce kanıtlanıyor:** önbellekten
     yapılan blit sayısı > 100 değilse test DÜŞER — yoksa `toImageSync`
     desteklenmeyen bir ortamda iddia boşuna geçer ve hiçbir şey
     kanıtlamazdı (bu dosyada aynı tuzağa iki kez düşüldü).

     **Doğrulama sınırı:** bu ortamda Flutter SDK YOK; `dart analyze` ve
     testler yalnızca CI'da koştu. Asıl kanıt CİHAZDA — ölçülen sayı
     `[ÖLÇÜM]` satırlarıyla CI log'una yazılıyor, ama "akıcı mı" sorusunun
     cevabı yalnızca gerçek telefonda alınır.

   - ✅ **Parça 143 — tanıtımda "DEVAM ›" GERİ KONDU: sahadaki ilk
     kullanıcılar kaydırmayı anlamadı (26 Ağustos 2026, kullanıcı
     bildirdi: *"insanlar tanıtımı kaydırmayı anlayamıyorlar"*):**
     Bu, projedeki en pahalı hata sınıfının örneği — **makul bir varsayım,
     sahada çürüdü.** 19 Ağustos'ta düğme kullanıcı isteğiyle kaldırılmıştı
     (*"Alttaki kocaman Devam butonu çok gereksiz. Altta sadece ince bir
     nokta alanı bıraksak HERKES PARMAKLA İLERLEYECEĞİNİ BİLİR"*) ve o gün
     için gerekçe sağlamdı: düğme alttan ~60px yiyordu.
     - **Bedeli ölçüldü ve büyüktü:** tanıtımda ATLAMA da olmadığı için bu
       bir ÇIKMAZDI. Kapalı testin davetlileri uygulamanın kendisine hiç
       ulaşamadı — 3 günde yalnızca 2 kayıt vardı ve "mail gelmiyor" diye
       bildirilen sorunun gerçek sebebi buydu: kimse kayıt ekranına
       varamıyordu. Yani bu bir "kozmetik" mesele değil, huninin en
       başındaki tıkaçtı.
     - **Geri konan düğme ESKİSİ DEĞİL:** tam genişlikte değil, metin
       genişliğinde ve kısa; `accent` (son sayfadaki HEMEN OYNA ile aynı
       renk — ikisi hiç aynı anda ekranda olmuyor, aynı renk "buraya bas"
       sinyalini güçlendiriyor). Görsel küçük ama dokunma hedefi
       `TapTarget` ile 48 dp'de (Parça 134'ün kuralı: görseli küçültmek
       hedefi küçültmez).
     - **Kaydırma KALDIRILMADI** — düğme onun yanına eklendi, yerine
       geçmedi. Masaüstü fare sürükleme desteği de olduğu gibi duruyor.
     - **Dürüst takas:** 19 Ağustos'un asıl şikayeti (dikey alan) kısmen
       geri veriliyor. Birkaç piksel slayt yüksekliği ile uygulamaya hiç
       ulaşamamak arasında seçim yapıldı.
     - **Regresyon:** mevcut test bu davranışın TERSİNİ kilitliyordu
       (*"ara sayfalarda düğme YOK"*) — güncellendi ve bir dal eklendi:
       düğmeye basınca gerçekten sonraki slayta geçiliyor, kalan sayfalar
       PARMAKLA geziliyor (ikisinin de çalıştığı aynı testte kanıtlanıyor),
       son sayfada DEVAM yerini HEMEN OYNA'ya bırakıyor.

   - ✅ **Parça 142 — davet linki artık SESSİZ düşmüyor (26 Ağustos 2026,
     ROADMAP madde 1'in alt maddesi; web DEĞİŞMEDİ):** Kural işledi — önce
     web'e bakıldı. `FriendInvitePage` 25 Ağustos'ta çözmüştü: sunucunun
     KALICI reddi (SQLSTATE `P0001`) olduğu gibi gösteriliyor, geçici arıza
     jenerik mesaj alıyor. Portun `_processInvites`'i ise her hatayı
     `debugPrint`e yazıyordu — kişi **kendi** davet linkine dokunduğunda
     ekranda hiçbir şey olmuyordu.
     - **Karar mantığı saf fonksiyona çıkarıldı:** `inviteAcceptErrorText` /
       `inviteAcceptKaliciRet` (`data/friends_api.dart`). Üç dal BİLEREK
       ayrı, çünkü kullanıcının yapabileceği şey farklı: P0001 → sunucu
       metni olduğu gibi (tekrar denemek sonucu değiştirmez); ağ hatası →
       "bağlantını kontrol et"; geri kalan → jenerik. Ham sunucu hatası
       ("deadlock detected") kullanıcıya GÖSTERİLMEZ, ama teşhis de
       uydurulmaz.
     - **Koda bakılıyor, METNE değil** — web'de de yazılı gerekçe: sunucu
       mesajı değişebilir, SQLSTATE değişmez.
     - **Misafir dalı da sessizdi:** girişsiz biri geçersiz/süresi dolmuş
       bir linke dokunduğunda hiçbir şey görmüyordu. Artık konuşuyor. Ama
       `FriendsRepo.inviteInfo` her hatayı null'a çevirdiğinden SEBEP
       bilinmiyor — teşhis uydurmak yerine bilinen tek sinyale
       (`onlineStatus`) bakılıyor; `offline_notice.dart`'ın "çevrimdışı
       DEĞİL, yükleyemedik" ayrımıyla aynı disiplin. Çevrimdışı dalında
       `_previewedInviteToken` damgası GERİ ALINIYOR, yoksa bağlantı dönse
       bile aynı linke bir daha bakılmaz ve kullanıcı çıkışsız kalırdı.
     - **Telemetri:** beklenmeyen hatalar `errorReporter`a düşüyor; beklenen
       retler (P0001) ve ağ hataları BİLEREK düşmüyor — bugünün ÜÇÜNCÜ
       "yutulan hata" düzeltmesi (bkz. Parça 140, 141).
     - **Regresyon:** 2 test (`friends_test.dart`) — P0001 metni birebir
       geçer + kalıcı ret işaretlenir; ağ hatası ile bilinmeyen sunucu
       hatası AYRI konuşur ve ham mesaj sızmaz. Negatif eşleri yazılı.
     - **`takeAll`ın yıkıcılığı da AYNI TURDA kapatıldı (kullanıcı kararı:
       "B").** Kuyruktan okuma silerek okuyor (tek transaction'da SELECT +
       DELETE), yani istek tam o anda düşerse davet hem kurulmuyor hem token
       kayboluyordu; kullanıcının tek çaresi linke yeniden dokunmaktı, link
       elinde yoksa davet tamamen kayıptı. Artık **yalnızca ağ hatasında**
       token kuyruğa geri konuyor.
       - **Neden yalnızca ağ hatası:** kalıcı reddi (P0001) geri koymak,
         her açılışta aynı "Kendi linkinle arkadaş olamazsın." diyaloğunu
         gösteren ÖLÜMSÜZ bir kayıt üretirdi. Bilinmeyen hatalar da geri
         konmuyor — sebebini bilmediğimiz bir şeyi sonsuza dek tekrarlatmak
         yanlış taraf; onlar telemetriye düşüyor.
       - **Yeniden deneyen bir şey de eklendi:** `didChangeAppLifecycleState`
         öne dönüşte `_processInvites`i çağırıyor (aynı yerdeki
         `flushPending`/`_scheduleCloudSync` deseni). Bu olmadan geri konan
         token uygulama yeniden başlatılana kadar beklerdi. Kuyruk boşken
         `takeAll` hiçbir şey döndürmeden çıkıyor, yani çağrı bedelsiz.
       - **Regresyon:** üçüncü test — ağ hatasında token DURUYOR, kalıcı
         rette GİTMİŞ oluyor. İkisinin de negatif eşi yazılı.

   - ✅ **Parça 141 — açık menü DONUYORDU: k-lig satırı puan geç gelince
     hiç belirmiyordu (26 Ağustos 2026, kullanıcı cihaz testinde bildirdi:
     *"avatar menüdeki isim altındaki k-lig çıkmadı önce, sayfayı refresh
     edince geldi"*):** Kural işledi — önce web'e bakıldı, fark YAPISALDI.
     - **Web'de menü bileşenin İÇİNDE satır içi render ediliyor**
       (`{open && (…)}`, `UserMenu.tsx:229`), yani `setMyRank` geldiğinde
       React AÇIK menüyü yeniden çiziyor. **Portta `PopupMenuButton`'ın
       `itemBuilder`ı menü AÇILDIĞI AN bir kez koşuyor** ve sonuç AYRI bir
       route'a gömülüyor; `AccountButton.setState` o route'u yeniden
       çizmiyor. Puan menü açıldıktan sonra gelirse satır o menüde bir daha
       ASLA belirmiyordu.
     - **CİHAZDA DOĞRULANDI (26 Ağustos, paket 378, gerçek Android):**
       hesap menüsündeki k-lig satırı ilk açılışta göründü.
     - **Düzeltme:** `_myRank` artık `ValueNotifier` ve menü başlığının iki
       parçası (isim yanındaki `RankSeal` + altındaki `#sıra · puan` satırı)
       `ValueListenableBuilder` ile sarılı — açık menü web'deki gibi canlı.
     - **İkinci dal — tek atış, tek şans:** `_refreshMyRank` yalnızca
       `initState`te ve hesap DEĞİŞİMİNDE koşuyordu; açılıştaki tek istek
       düşerse (`StatsRepo.myRank` her istisnayı null'a çeviriyor) satır
       sayfa yenilenene kadar yok oluyordu. Artık `onOpened` puan hâlâ
       yokken yeniden deniyor — normal durumda menü açmak ağa çıkmıyor.
     - **Üçüncü dal — teşhis edilemezlik:** `myRank`ın `catch`i yalnızca
       `debugPrint`ti, yani Parça 140'ın aynı sınıfı. Artık
       `errorReporter.report`a düşüyor (ağ hatası elenerek).
     - **Ölçüm — bir hipotez ELENDİ:** "istek JWT hazır olmadan gidiyor,
       sunucu boş dönüyor" teorisi canlıda test edildi ve YANLIŞ çıktı;
       `my_leaderboard_rank` SECURITY DEFINER değil, `anon` rolüne de
       EXECUTE verilmiş ve `anon` olarak koşturulduğunda Ironman için
       `rank 2 · 135 puan` döndürüyor. Yani sebep kimlik değil, istemci
       tarafı.
     - **Regresyon (2 test, `account_button_test.dart`):** puan menü
       AÇIKKEN gelince satır canlı beliriyor (menü kapanmadan, sayfa
       yenilenmeden); açılıştaki istek düşerse menü yeniden açılınca
       YENİDEN deneniyor. İkisinin de negatif eşi yazıldı.
     - **Web DEĞİŞMEDİ** — orada davranış zaten doğruydu.

   - ✅ **Parça 140 — kurucusu silinmiş oyun Canlı listesini DÜŞÜRDÜ
     (26 Ağustos 2026, Parça 139'un yan etkisi; web + port aynı PR):**
     Kullanıcı gerçek cihazda (derleme `53e401c` = 372) bildirdi: *"Devam
     edenler, oyun davetleri (2 tane vardı) ve son oynadıklarım gelmiyor"*
     — üç alt sekme birden "Oyunların şu an yüklenemedi.", TEKRAR DENE
     boşuna. **Kök sebep hesap silme kaskadında:** `online_games.created_by`
     `on delete cascade`'ten `set null`'a çevrilmişti (bitmiş oyunlar
     ötekinin arşivi için korunsun diye), T1 silinince 5 satırda kolon
     NULL'a düştü — ama `OnlineGame.fromJson` hâlâ `m['created_by'] as
     String` yapıyordu. Tek satır fırlatınca ayrıştırma tek geçişte
     olduğundan 43 oyunun tamamı gitti.
     - **CİHAZDA DOĞRULANDI (26 Ağustos, paket 378, gerçek Android):**
       Play güncellemesinden sonra Canlı sekmesinin üç alt sekmesi de
       yüklendi. Bu davranış aynı zamanda sürümün kanıtı — 372'de liste
       DETERMİNİSTİK düşüyordu, yani yüklenmesi 378'in kurulu olduğunu
       sha'ya bakmadan gösteriyor.
     - **`createdBy` → `String?`**; `creatorSlot` ve `participantLabel`
       null güvenli hâle getirildi. Null==null tuzağı gerçek: `userId` de
       nullable, çıplak eşitlik kurucusu silinmiş bir oyunda rastgele bir
       koltuğu "Davet gönderen" ilan ederdi.
     - **`load()` artık TELEMETRİYE yazıyor.** İkinci ders bu: hata
       yalnızca `debugPrint`e gidiyordu, bu yüzden `client_errors`'ta tek
       satır yok ve teşhis elle SQL koşularak yapıldı — telemetri (Parça
       ROADMAP #3) tam bunun için kurulmuştu. Ağ hatası BİLEREK eleniyor
       (`isNetworkError`): `report` varsayılan `manual` türünde o filtreyi
       kendisi uygulamıyor, çevrimdışı kullanıcı ise bu satıra her açılışta
       düşer.
     - **Web tarafı:** `database.types.ts`'te `created_by: string | null`.
       Kod değişmedi — `LiveGamesTab`'in üç tüketicisi de
       `?.name ?? 'Bir arkadaşın'` kalıbında ve `HumanSlot.user_id` NOT
       NULL olduğundan karşılaştırma null'da hiçbir koltuğu seçmiyor.
       **Yanlış olan yalnızca tipti — ve port o yanlış tipi kopyalamıştı.**
     - **Sunucu denetlendi, değişiklik gerekmedi:** `created_by`'ye bakan
       her fonksiyon/RLS politikası yalnızca eşitlik karşılaştırıyor,
       NULL'da eşleşmiyor; hayatta kalan oyuncu oyuna `game_invites`
       dalından erişmeye devam ediyor.
     - **Regresyon (3 test):** `created_by: null` satırının listeyi
       düşürmediği + `creatorSlot` null + "Davet gönderen" etiketinin
       yanlışlıkla verilmediği; sekmede kartın GERÇEKTEN çizildiği ("Bir
       arkadaşın" yedeğiyle); ayrıştırma hatasının telemetriye düştüğü ama
       ağ hatasının DÜŞMEDİĞİ. Sahte gateway'e `slotDeletedHuman` eklendi
       (uuid kalır, `name` NULL olur — üretimdeki satırın birebir şekli).
     - **Ders (kök `CLAUDE.md`'nin etki analizi tablosuna eklendi):** bir FK
       eylemini değiştirmek bir SÖZLEŞME değişikliğidir; `cascade` → `set
       null`, "silinen satır" sorusunu "NULL kolon" sorusuna çevirir ve o
       NULL'ı okuyan her istemcinin tipi aynı PR'da genişlemelidir.
     - Ayrıntı/ölçümler: `docs/decisions/account-deletion.md` → "SET NULL'ın
       bedeli".

   - ✅ **Parça 139 — uygulama içinden hesap silme (25 Ağustos 2026,
     ROADMAP madde 2, MAĞAZA BLOKERİ; web + port + migration + Edge
     Function AYNI PR'da):** Apple 5.1.1(v) ve Google'ın veri silme şartı,
     hesap açtıran uygulamalarda uygulama İÇİNDEN başlatılabilen bir silme
     yolu istiyor. `kelimeki.com/hesap-silme/` yalnızca Data safety
     formuna verilen TALEP adresiydi; işi yapan taraf yoktu.
     **Kaskadın tamamı, verilmiş karar (anonimleştirme) ve canlıda ölçülen
     tuzaklar: `docs/decisions/account-deletion.md`** — burada yalnızca
     portu ilgilendiren kısım.
     - **Yeni dosya `ui/auth/delete_account_modal.dart`** — web
       `src/components/DeleteAccountModal.tsx` portu. AÇILIŞTA KURU
       ÇALIŞTIRMA (`previewAccountDeletion`): silinecekler gerçek sayılarla
       listelenir, sıfır satırlar gizlenir, "Kalacaklar" bölümü
       başkalarının korunacak kayıt sayısını söyler. **Kuru çalıştırma
       düşerse silme butonu ETKİNLEŞMEZ** — sunucuya ulaşılamıyorsa (ya da
       hesap silinemez bir hesapsa) butonu açmak yanlış bir söz verir.
     - **`AuthService.previewAccountDeletion`/`deleteMyAccount` +
       `AccountDeletionReport`** (`data/auth_service.dart`). `FunctionException`
       yakalanıp `details['error']` OKUNUYOR: sunucunun Türkçe mesajını
       (ör. *"Yönetici hesabı uygulama içinden silinemez."*) yutup genel bir
       metin göstermek teşhisi imkânsız kılardı — Parça 124'ün ("düşen istek
       'hiç oyunun yok' DEMEZ") aynı sınıfı.
     - **`NeoButtonVariant.red` eklendi** (`ui/game/neo_button.dart`).
       Gölge değerleri accent/gold/orange ile BİREBİR aynı; web'de de tek
       `.btn-raised` sınıfı + `bg-*` deseni var, yani port yeni bir görsel
       dil uydurmuyor. Renk `kRed` — `tokens.dart` dışında renk yazılmıyor
       (`color_tokens_test.dart` bunu zaten tarıyor).
     - **`account_settings_modal.dart`e giriş:** KAYDET'in ALTINDA, bir
       ayracın arkasında, formun akışının DIŞINDA — web'in yerleşimiyle
       birebir ("ayarlarımı kaydediyorum" akışının parçası gibi
       görünmesin). `TapTarget(alignment: Alignment.centerLeft)` — 11 px'lik
       bir metin çıplak bir `GestureDetector` ile Parça 132/134'ün dokunma
       hedefi kuralını çiğnerdi; `centerLeft` çünkü ortalamak hizayı bozar
       ("← Geri" vakası).
     - **Türkçe kuralı yine devrede:** onay kelimesi `SİL` ve karşılaştırma
       `trUpper` ile. Native `toUpperCase()` "sil"i "SIL" (noktasız I)
       yapar ve eşleşme SESSİZCE tutmazdı — kullanıcı doğru kelimeyi yazıp
       butonun açılmadığını görürdü.
     - **`legal_modals.dart` AYNI PR'da güncellendi** (Gizlilik 5. bölüm +
       "Son güncelleme: 25 Ağustos 2026"). Atlansa `legal_text_test.dart`
       düşerdi — ama mobil CI'ın web metnine bağlı tek kapısı O DEĞİLMİŞ:
       **`signup_test.dart` de politikanın 5. bölümünden bir CÜMLE arıyordu**
       (`'30 gün içinde kalıcı olarak silinir'`) ve ilk koşuda 508/509 ile
       düştü. Bulan CI oldu, tarama değil — bu ortamda Flutter SDK yok.
       **Ders:** hukuki metnin bağımlıları `legal_text_test.dart` ile sınırlı
       değil; metni değiştirirken `grep -rn "<değişen cümle>" mobile/app/test/`
       de koşulmalı. İddia yeni gerçeklere bağlandı (uygulama içi yol VAR +
       talep yolu hâlâ 30 gün), silinmedi.
     - **Regresyon:** `account_settings_test.dart`e bir test —
       "HESABIMI SİL" dokunulunca pencere açılıyor, `AuthService.fake` bir
       Supabase client taşımadığından kuru çalıştırma düşüyor, SEBEP
       görünür oluyor ve `KALICI OLARAK SİL` butonunun `onPressed`i `null`
       kalıyor. Yani testin sınadığı şey görünüm değil, yukarıdaki
       "kuru çalıştırma düşerse buton açılmaz" SÖZLEŞMESİ.
     - **Doğrulama sınırı:** gerçek (kuru olmayan) silme bu oturumda HİÇ
       çalıştırılmadı — geri dönüşü yok. Cihaz kontrolleri
       `mobile/TESTING.md` bölüm 21'de; ilk gerçek kullanım ROADMAP madde 4
       (test hesaplarının silinmesi) olacak.
     - **`mobile/` DIŞINDA da dosya değişti** (kök `CLAUDE.md`'nin kuralı):
       `src/lib/api.ts`, `src/components/DeleteAccountModal.tsx`,
       `src/components/AccountSettingsModal.tsx`, `src/legal/*`,
       `supabase/migrations/*`, `supabase/functions/delete-my-account/`,
       `tests/smoke.spec.ts`, `ROADMAP.md`, `README.md`, `TESTING.md`,
       `docs/decisions/account-deletion.md` — hepsi AYNI PR'da.
     - **EK (aynı gün, ikinci tur — kullanıcı istedi):** Kullanım Koşulları
       §2'ye de bir cümle eklendi (*"Hesabınızı dilediğiniz zaman Hesap
       Ayarları'ndan kendiniz silebilirsiniz…"*) ve Koşullar'ın tarihi
       19 → 25 Ağustos oldu; port da AYNI PR'da. İlk turda bilerek
       atlanmıştı — taramada Koşullar'da yanlış hâle gelen bir cümle
       çıkmamıştı (§4'ün "askıya alınabilir veya silinebilir"i BİZİM
       hakkımız, kullanıcının kendi silmesi değil). **Ölçülen bedel:**
       Koşullar'ın tarihini oynatmak `legal_text_test.dart` üzerinden portu
       zorunlu kılıyor, yani yeni bir CI turu ve YENİ BİR `.aab`. Hukuki
       metne dokunmak her zaman bir paket turudur — planlarken hesaba kat.
     - **Yan iş (doküman bütçesi):** `mobile/TESTING.md` uyarı bandındaydı
       (160 KB) ve kural *"bir sonraki dokunuşta böl"* diyor. Test
       ORTAMLARI (web derlemesi, FAZ B cihaz turu, TestFlight, Appetize)
       `mobile/docs/test-ortamlari.md`ye taşındı — kesme noktası içeriğin
       TÜRÜ: burası her sürüm önce baştan koşulan kontrol listesi, orası
       "nereden/nasıl koşulur". Dosya 160 → 141 KB. Hâlâ uyarı bandında;
       bir sonraki dokunuşta sıradaki aday Arkadaşlar + Canlı oyun
       bölümleri (~32 KB).
