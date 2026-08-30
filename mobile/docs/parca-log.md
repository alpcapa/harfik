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

   - ✅ **Parça 173 — devam eden oyun kartlarının metinleri sadeleşti
     (30 Ağustos 2026, kullanıcı isteği; kozmetik, davranış AYNI):**
     `SENİN HAMLEN BEKLENİYOR` → **`SIRA SENDE!`**, `RAKİBİN HAMLESİ
     BEKLENİYOR` → **`SIRA RAKİPTE`**; punto 11 → 13, altındaki kalan-süre
     8 → 10.
     - **Kutu BÜYÜMEDİ** (kullanıcı "kutu biraz büyüyebilir" demişti):
       `SIRA RAKİPTE` 12 karakter, eskisi 11 px'te bile daha genişti.
     - **Etiketler artık KAYNAKTA büyük harfle.** Çağıran `trUpper`dan
       geçiriyor, yani idempotent; web tarafında CSS `uppercase`in Türkçe
       i→İ duyarlılığına güvenilmesin diye iki taraf aynı dizeyi taşıyor.
     - **ÜÇ sayaç da tek kalıba indi: yalnızca "N gün M saat kaldı".**
       Öncesi: `sonra teslim sayılacak` (48 sa) · `sonra iptal edilecek`
       (davet, 7 gün) · `sonra silinecek`/`sonra teslim sayılacak`
       (Setup'ın yerel YZ kaydı, 7 gün). **Üçüncüsünü kullanıcı
       listelememişti** ("başka yerde varsa söyle") — ayrıca bildirildi ve
       aynı hizaya çekildi, çünkü ikisi de "devam eden oyun" satırı ve
       kullanıcı ikisini yan yana görüyor. Setup'ın hardcoded etiketi de
       `SIRA SENDE!` oldu.
     - **Kabul edilen bilgi kaybı, açıkça bildirildi:** fiil sürenin
       sonunda NE olacağını söylüyordu; Setup'taki `teslim sayılacak`
       hesaba gelecek -2 cezanın tek uyarısıydı. Fiil süre DOLDUĞUNDA geri
       geliyor (`Bugün teslim sayılacak` / `Bugün silinecek`) — "Bugün" tek
       başına hiçbir şey anlatmazdı ve bilgi değeri tam orada en yüksek.
     - **Ekran görüntüsü ÖNCE gösterildi** (kullanıcı istedi): mock değil,
       gerçek widget'lardan — `live_games_test` + `setup_cloud_test`in
       `RepaintBoundary` yakalamaları. Aktif oyun kartı için geçici bir
       yakalama eklenip koşuldu ve geri alındı.
     - **Doğrulama:** 638/638 test yeşil, `dart analyze` temiz (tek `info`
       önceden vardı), `tsc --noEmit` temiz, web derlemesi geçti. Eski
       dizeleri bekleyen 11 assertion güncellendi (`live_games_test`,
       `setup_screen_test`, `setup_cloud_test`, `tests/smoke.spec.ts`) —
       yani metin değişikliğinin kapısı ZATEN vardı ve çalıştı.
     - **Elle koşulan listeler de güncellendi:** `TESTING.md` (iki madde),
       `mobile/docs/testing-arkadaslar-canli.md` (punto maddesi) — orada
       eski dizeler kontrol ölçütü olarak yazılıydı.

   - ✅ **Parça 172 — ilişki ikonu ailesi tamamlandı + skor kartındaki
     dört-dal hatası (30 Ağustos 2026, kullanıcı bildirdi; YENİ dosyalar
     `ui/friends/relation_icons.dart`, `test/relation_icon_parity_test.dart`,
     `test/support/vector_parity.dart`):** iki ayrı iş, ikisi de aynı
     bildirimden çıktı.
     - **(a) GERÇEK HATA — aynı durum iki yüzeyde farklı görünüyordu.**
       Kullanıcının sözleri: *"Arkadaşlık daveti beklemede olan kişinin
       skor kartına girince isminin yanında arkadaş ekle işareti çıkıyor.
       Halbuki aynı kişiye Arkadaşlar → Ara & Ekle bölümünden bakınca
       yanında kum saati çıkıyor. Bu hata."* Skor kartı (web'de de portta
       da) ikonu İKİ dala ayırıyordu — `accepted` ↔ "diğer her şey" — oysa
       AYNI dosyadaki onay diyaloğu baştan beri dördünü ayırıyordu: kart
       "ekle" diyor, dokununca "İsteği İptal Et" çıkıyordu. Artık
       `_relationGlyph` (port) / `friendIconFor` (web) dört dalı da
       karşılıyor. **Ders:** bir DURUM birden çok yüzeyde gösteriliyorsa
       yüzeylerin dal SAYILARI da eşit olmalı; dört dallı bir metinle iki
       dallı bir ikon aynı ekranda yan yana durabiliyorsa eşleşmeyi
       zorlayan bir şey yok demektir.
     - **(b) İkon ailesi.** Kullanıcı isteği: *"Kum saatini de diğer
       ikonlar gibi adamın yanında (+, - ve check gibi) küçük kum saati
       veya saat yapsak diğerleriyle bütünlük olacak."* Dördün üçü
       kişi+rozetken (`+`/`−`/`✓`) dördüncüsü kişisiz, tek başına duran
       büyük bir `Icons.hourglass_top`tu.
     - **Material'da karşılığı YOK, yani bu dosyanın kuralı burada
       uygulanamıyor.** Öteki üç ikon gerçek glyph olduğundan port onları
       `Icons.*` ile çiziyor ve iki platform AYNI vektörü gösteriyor;
       "kişi + kum saati" diye bir glyph olmadığı için bu ilk ELLE çizilen
       ilişki ikonu oldu. `hourglass_top`u rozet kutusuna küçültmek çare
       DEĞİLDİ: glyph'in çizgileri ~1 birim, yarıya inince 20 px'lik ikonda
       0,42 px kalıyor. Saat de denendi ve elendi (halka + iki ibre o
       boyutta çok inceliyor; kum saatinin dolu üçgenleri okunuyor) —
       kullanıcıya iki seçenek render edilip gösterildi, kum saatini seçti.
     - **Sapma bilinçli olarak minimum:** kişi gövdesi
       `person_add_alt_1`in AYNISI (artı çıkarılmış, tek koordinat
       oynatılmadan), elle çizilen tek şey rozet ve o da artının durduğu
       kutuda (x 15→23, y 6,98→15).
     - **Elle senkron bir kopya, senkronu zorlayan bir şey olmadan
       bayatlar** — `OzellikIkonlari` çiftindeki mekanizma ikinci kez
       kuruldu. Ayrıştırıcılar KOPYALANMADI, `icon_parity_test.dart`ten
       `test/support/vector_parity.dart`e çıkarıldı ve iki test de oradan
       tüketiyor (eski test taşımadan sonra yeşil kaldı). Üçüncü bir
       elle-senkron vektör çifti eklenirse aynı yerden beslenmeli.
     - **Doğrulama:** 638/638 test yeşil, `dart analyze` temiz (tek `info`
       önceden vardı, `tap_target_test.dart:206`), `tsc --noEmit` temiz,
       web derlemesi geçti. **İki negatif eş de ölçüldü:** (1) portta tek
       bir koordinat 16,4 → 16,5 yapılınca parite testi düşüyor; (2) skor
       kartı iki dala döndürülünce `ilişki simgesi` testlerinden İKİSİ
       birden düşüyor (ikisi de kontrol edildi — ilk sürüm yalnızca renge
       baktığı için `pending_incoming`i kaçırıyordu, glyph de ölçülecek
       şekilde sıkılaştırıldı).
     - **Doğrulama sınırı:** web tarafında Canlı/arkadaşlık akışları iki
       gerçek oturum gerektirdiğinden otomatik test edilemiyor; ikonun
       web'de göründüğü `main`'e merge sonrası gözle doğrulanacak.

   - ✅ **Parça 171 — güncelleme artık Play'in işi: In-App Update
     (30 Ağustos 2026, kullanıcı kararı; YENİ dosya
     `data/store_update.dart`):** *"Kimde hangi versiyon olursa olsun,
     app'i açtığında daha yeni bir sürüm varsa uyarsın ve yapsın. Bu kadar
     basit."*
     - **Eski mekanizmanın çalışmadığı ÖLÇÜLDÜ, tartışılmadı.** Tek yol
       `app_config.mobile_min_supported_version` idi: bir insanın elle
       yükseltmesini bekleyen ikili bir kapı. 1.0.1 iki gün yayında
       kaldıktan sonra son 14 günün `game_starts` dökümü **android 1.0.0 =
       93, 1.0.1 = 2** idi; canlıdaki eşik ise 5 Ağustos'tan beri `0.0.0`,
       yani HİÇ yükseltilmemişti. Mekanizma vardı ama kimseyi
       güncellemiyordu.
     - **Çözüm sunucuya bir alan daha eklemek DEĞİL, alanı akıştan
       çıkarmak oldu:** Play In-App Update'te güncelleme olup olmadığını
       Play'in kendisi biliyor. `in_app_update` 5.0.0 + Immediate akışı;
       kontrol `_HomeGate`te (push hizalamasıyla aynı kanca: açılış +
       `resumed`). `mobile_min_supported_version` silinmedi ama artık
       yalnızca ACİL FREN.
     - **API hafızadan değil KAYNAKTAN okundu** ve bir tuzak çıktı:
       `performImmediateUpdate` yalnızca `USER_DENIED_UPDATE` ve
       `IN_APP_UPDATE_FAILED`'i sonuca çeviriyor, **bilinmeyen
       `PlatformException`'ları YENİDEN FIRLATIYOR** — sarmalayıcıda
       try/catch şart, yoksa bir güncelleme kontrolü uygulamanın açılışını
       düşürebilirdi (`push_init.dart`'ın aynı ilkesi).
     - **`bilinmiyor` ≠ `gerekYok` ve bu ayrım özelliğin kalbi:** ağ
       yokken/Play cevap vermezken "güncel" saymak, açılışta ağı olmayan
       kullanıcıyı sonsuza dek eski sürümde bırakırdı — yani tam da 93
       kişiyle yaşanan hatanın aynısı. Soru kapanmazsa öne dönüşte TEKRAR
       soruluyor. Kullanıcı akışı reddederse soru KAPANIR (her öne dönüşte
       tam ekran pencere açmak düşmanca olurdu); bir sonraki AÇILIŞTA
       yeniden sorulur.
     - **`UpdateRequiredScreen`'in butonu da bağlandı** — kapı fırladıysa
       güncellemek en çok orada gerekiyor. Mağaza yedeği KORUNDU: o ekranı
       görenler tanım gereği eski sürümde ve In-App Update yan yüklenmiş
       pakette hiç çalışmıyor; yedeksiz kalsa 1.0.0'ın "çıkışsız ekran"
       hatası aynen tekrarlanırdı.
     - **ÜÇ SINIR, üçü de yapısal:** yalnız Android (iOS'ta karşılığı olan
       API yok) · yalnız Play'den KURULMUŞ pakette (yan yüklenen `.apk`da
       sessizce `bilinmiyor`) · ve kod 1.0.2'nin içinde olduğundan sahadaki
       1.0.0 kitlesi onu ancak 1.0.2'ye geçtikten SONRA görür. Sonuncusu bir
       seferlik: 1.0.2 indirilebilir olduğu doğrulandıktan sonra eşik bir
       kez 1.0.2'ye çekilip o kitle süpürülecek, sonra bir daha
       yükseltilmeyecek.
     - **Regresyon: 11 test** (`test/store_update_test.dart`) — karar
       tablosunun dört dalı, `UpdateRequiredScreen`in üç dalı ve
       **KABLOLAMA**: kancanın gerçekten açılışta koştuğu, kapanmış sorunun
       öne dönüşte tekrar SORULMADIĞI, kapanmamış sorunun tekrar
       SORULDUĞU. Kablolama testi bilinçli: bu projede "her açılışta
       koşuyor" sanılan bir çağrının aslında tek bir sekmede olduğu bir kez
       yaşandı (Parça 159).
     - **İKİ negatif eş kuruldu:** (a) açılış kancası silinince kablolama
       testleri düşüyor; (b) `bilinmiyor` "kapandı" sayılınca tekrar-deneme
       testi düşüyor.
     - **Doğrulama:** `dart analyze` temiz · **633 widget testi** yeşil
       (622 → 633) · `flutter build web --release` GEÇTİ (bu projede web
       derlemesinin sessizce kırılması bilinen bir sınıf; `in_app_update`
       Android eklentisi olduğu için özellikle bakıldı).
     - **Sürüm 1.0.2'ye çıkarıldı** (`env.dart` + `pubspec` birlikte —
       `app_version_parity_test` ayrışmayı yakalar). In-App Update'in
       anlamlı olabilmesi için mağazadaki paketin sahadakinden YENİ olması
       gerekiyor; `versionCode`u zaten Actions koşu numarası veriyor.
     - **`.apk`/`.aab` derlemesi bu ortamda doğrulanamadı** (Android SDK
       yok) — **CI cevapladı (PR #371, hepsi yeşil):** `bundleRelease`
       geçti, imzalı `.aab` üretildi (62,9 MB) ve parmak izi beklenen
       upload anahtarıyla eşleşti. **KGP uyarı listesi BEŞTE KALDI**
       (`firebase_analytics, firebase_core, image_picker_android,
       share_plus, shared_preferences_android`) — `in_app_update` KGP
       uygulamıyor, borç büyümedi.
     - ✅ **CİHAZDA DOĞRULANDI (30 Ağustos 2026, `d3d4702` / versionCode
       435, koşu #435'in `.apk`'sı):** açılış temiz — çökme/donma yok,
       arka plandan öne dönüş temiz, **uçak modunda açılış da temiz.**
       Bu, kodun HİÇBİR yerde koşmamış tek parçasını kapatıyordu: gerçek
       Play Core `MethodChannel` çağrısı. Widget testleri sahtesini
       kullanıyor, bu ortamda `.apk` derlenemiyor; yani "açılış yoluna
       ağa çıkan bir çağrı koydum" riski ancak burada ölçülebilirdi.
       Yan yüklenmiş pakette güncelleme penceresi BEKLENDİĞİ GİBİ
       çıkmadı. Aynı turda alt şerit, hamle rozeti ve yaş/cinsiyet
       satırı da temiz geldi.

   - ✅ **Parça 170 — alt şerit Android'de ortaya kümeleniyordu: `Wrap`
     genişliği DOLDURMUYOR (30 Ağustos 2026, kullanıcı cihazda bildirdi):**
     *"Hamleler, Mesajlaşma satırı Android'de ortaya kümelenmiş, iPhone'da
     kenarlara yaslı."* İki ekran görüntüsü AYNI oyunun iki istemcisiydi —
     Android = Flutter paketi, iPhone = web; yani doğrudan bir parite farkı.
     - **Web doğru taraftı** (`Board.tsx`: `flex justify-between w-full`),
       port ayrışmıştı — "önce web'de bu nasıl yapılmış?" kuralı ilk adımda
       cevabı verdi.
     - **Kök sebep Parça 161'in `Row` → `Wrap` dönüşümü.** `Row`
       (varsayılan `mainAxisSize.max`) gelen genişliği DOLDURUR; `Wrap`
       gevşek kısıt altında içeriğine KÜÇÜLÜR
       (`constraints.constrain(...)` doğal genişliği döndürür). Küçülen
       kutuda dağıtılacak boşluk kalmadığından `spaceBetween` sessizce
       no-op olur ve saran `Column`un varsayılan `center` hizası kümeyi
       ortaya alır.
     - **ÖLÇÜLDÜ** (gerçek `BoardWidget`, bu ortama indirilen Flutter
       3.47.1 ile): şerit 360/390/430 px'te hep **313,3 px**'te donuyordu —
       390'da `38,4..351,6` (kenar boşluğu 10 yerine 38,4). Düzeltmeden
       sonra `10,0..380,0`, yani tam dolu.
     - **Düzeltme:** `_footer`ın `Padding`i `Container(width:
       double.infinity, padding: …)` oldu. `Container` ikisini birden
       yaptığından fazladan sarmalayıcı katman YOK — `SizedBox` ile
       denendi, tüm `Wrap` bloğunu bir seviye içeri kaydırıp 160 satırlık
       biçimlendirme gürültüsü üretiyordu.
     - **Parça 161'in taşma düzeltmesi KORUNDU:** 320 px'te şerit hâlâ iki
       satıra iniyor (ölçüldü: sol grup y=335,5, sağ grup y=383,5 — düzeltme
       öncesiyle aynı).
     - ⚠ **İLK YAZDIĞIM TEST YANLIŞ İDDİA TAŞIYORDU ve ölçüm düzeltti:**
       "kümelenince iki grup birbirine yapışır" varsaymıştım; oysa gruplar
       arası boşluk kümelenmiş hâlde de 124,7 px. Test bu yüzden GEÇİYORDU —
       yani negatif eş kurulmasaydı hiçbir şey korumayan bir test commit
       edilecekti. Kümelenmenin gerçek imzası boşluğun küçük olması değil
       **genişlikten BAĞIMSIZ** olması: 360/390/430'da hep 124,7; düzeltmeden
       sonra 151,4 / 181,4 / 221,4. Test artık İKİ genişlikte ölçüyor.
     - **Regresyon:** `test/text_scale_test.dart` → *"tahta alt şeridi
       ŞERİDİ DOLDURUR (kümelenmez)"*. **Negatif eş kuruldu:** düzeltme
       geri alınınca test gerçekten düşüyor (*"sağ kenara yaslı değil
       (23,4 px içeride)"*).
     - **Neden hiçbir mevcut test yakalamadı:** `text_scale_test`'in taşma
       testi yalnızca taşma/görünürlük soruyor (kümelenme ikisini de
       ihlal etmiyor), `tap_target_test` ise kutu BOYUTU ölçüyor, KONUM
       değil. Parça 161'de *"golden dikdörtgenler kıpırdamadı"* denip
       sessizlik kanıt sayılmıştı — o cümle bugün düzeltildi (`mobile/
       CLAUDE.md` → "Sistem Yazı Boyutu" kural 4 + o parçanın notu).
     - **Doğrulama bu kez CI'a bırakılmadı** (Flutter SDK indirildi,
       `mobile/CLAUDE.md` → "Flutter SDK bu ortama İNDİRİLEBİLİR"):
       `dart analyze` temiz, **622 widget testi** + `kelimeki_core`
       **6.841 kontrol** yeşil.
     - Web DEĞİŞMEDİ (zaten doğru) — bu tek taraflı bir port düzeltmesi.

   - ✅ **Parça 169 — hamle rozetinin punto ayrışması kapandı: WEB porta
     geldi (29 Ağustos 2026, kullanıcı kararı; web + port aynı PR):**
     - **Karar yönü önemliydi.** Parça 167'de kullanıcı puntoyu KÜÇÜLTEN
       seçeneği zaten reddetmişti ("hamle puanı 'Oyna'ya basmadan önce
       bakılan tek sayı"), yani ayrışmayı portu web'e çekerek kapatmak o
       kararı geri alırdı. Bu yüzden yön tersine seçildi: `Board.tsx`
       `clamp(8px,2vw,11px)` + `font-mono` → **sabit `11px` + `font-sans`**
       (Space Grotesk = portun tema sans'ı). Port DEĞİŞMEDİ.
     - **Ayrışma pratikte SABİT %19'du, akışkan değil:** clamp'in `2vw`si
       ancak 550px'te 11px'e ulaşıyor, yani her telefonda 8px'e kırpılıyordu.
       "Akışkan" tarafın hiç akmadığı bu tür değerler Parça 24'ün sınıfı.
     - **ÖLÇÜLDÜ** (gerçek oyun + Chromium, taslak taş konup rozetin metni
       değiştirilerek; hücre = tahta/13). `"+35"` ile:
       384px'te (hücre 27,7px) `20,7px = 0,75 hücre` → **`26,1px = 0,94`**;
       320px'te (hücre 22,8px) `20,7 = 0,91` → **`26,1 = 1,15`**.
     - ⚠ **320px'te iki haneli puan tek hücreyi AŞIYOR ve bu bilerek kabul
       edildi:** port zaten sabit 11 çizdiğinden 320px'lik bir telefonda AYNI
       taşmayı bugün de yaşıyor — değişiklik web'i portun davranışına
       getiriyor, yeni bir sorun üretmiyor. Şikayet gelirse çözüm İKİ tarafta
       birden uygulanmalı (tek taraflı bir düzeltme ayrışmayı geri getirir).
     - Web `npm run lint` + `npm run build` yeşil; motor dosyası değişmediği
       için golden vector üretimi gerekmedi. Port tarafında yalnızca yorum
       değişti (davranış aynı), bu yüzden Dart testleri etkilenmiyor.

   - ✅ **Parça 168 — `drainRealIo` flake'i: bütçe değil DESEN yanlıştı
     (29 Ağustos 2026, CI'da düştü; yeni dosya
     `test/support/real_io.dart`):**
     - **Belirti:** `online_game_chat_test.dart` → *"tanıtımı görmüş
       kullanıcı bir daha görmez"* CI'da `A Timer is still pending` ile
       düştü; AYNI anda `main` yeşildi → flake.
     - **Kök sebep bir zamanlama yarışı DEĞİL, eksik bir `pump()`:** sqflite
       her işlemde ~10 sn'lik kilit-uyarı `Timer`'ı kurar; widget'ın
       başlattığı yazma SAHTE zonda olduğundan o timer da sahtedir ve ancak
       gerçek I/O bitip devamı `pump()`la akıtılınca iptal olur. Yardımcı
       `runAsync(200ms)` + **TEK** `pump()` idi — oysa I/O'lar ZİNCİRLİ:
       `_seedInitialUnread` önce `lastReadAt()` OKUR, sonucuna göre
       `markRead()` YAZAR, yani ikinci I/O ancak birinci `pump()`landıktan
       SONRA başlıyor. Tek pump zincirin yalnızca ilk halkasını kapatıyordu.
     - **Düzeltme:** gerçek zaman payı dilimlere bölündü (10 × 50 ms, her
       dilimden sonra `pump()`) — her tur bir sonraki halkayı başlatabiliyor,
       toplam bütçe de 200 → 500 ms. Sabit uykuyu BÜYÜTMEK çözüm değildi:
       yarışı gizler, zinciri kapatmaz.
     - **Üç kopya tek kaynağa indi.** Aynı yardımcı `online_game_chat_test`,
       `setup_cloud_test` ve `intro_screen_test`'te ayrı ayrı yazılıydı —
       yani düzeltmenin üç yerde tekrarlanması gerekirdi. `ghostClick.ts`'in
       web tarafında yaptığının aynısı: ortak dosya + tek doküman.
     - ⚠ **Denenmeyen (ve denenmemesi gereken) yol kayda geçsin:** "bitti mi"
       diye aynı `Database`e `runAsync` içinden bir sorgu sormak daha kesin
       DURUR ama KİLİTLENİR — sqflite işlemleri seri işler, sorgu sahte
       zondaki bekleyen yazmayı bekler, o yazmanın devamı ise `pump()`
       ister; `runAsync` sırasında sahte zon pompalanmadığından ikisi
       birbirini bekler. Gerekçe yardımcının başlığında.
     - **Bu oturumda Dart SDK YOK** — `flutter analyze`/`flutter test`
       koşulamadı, doğrulama CI'ın "Uygulama analiz + testleri" işinde.
     - Aynı PR'da doküman borcu da kapandı: `ROADMAP.md`'deki bayat
       *"Bekleyen deploy"* uyarısı silindi (canlıdan ölçüldü:
       `notify-deadline-warnings` **v11**, *"takdirde"* doğru, push kanalı
       içinde, `verify_jwt: false`) ve Play kapalı testinin *"Published ≠
       testçinin telefonunda"* tuzağı yazıldı
       (`mobile/docs/build-and-distribution-log.md` + `mobile/CLAUDE.md`
       → "Deploy Doğrulaması"na üçüncü tuzak olarak).

   - ✅ **Parça 167 — hamle puanı rozeti taşları kapatıyordu (29 Ağustos
     2026, kapalı testteki kullanıcılar bildirdi; web + port aynı PR):**
     - **Ölçüm** (384px genişlik, hücre 25.2px; gerçek `Board` çıktısı
       `dist/index.html`'den çıkarılıp Chromium'da ölçüldü): rozet
       **30.7px = 1.22 HÜCRE**, yani kelimenin ilk taşının harfini örtüyordu.
       Dolgu `3/6` → **`1.5/3`**: **24.7px = 0.98 hücre**, tek hücrenin
       içinde kalıyor.
     - **Rakamın puntosu bilerek AYNI kaldı** (kullanıcı kararı): üç seçenek
       AYNI tahta üzerinde yan yana çizilip karşılaştırıldı; puntoyu
       küçülten seçenek (web paritesi + dar dolgu → 0.89 hücre) reddedildi —
       hamle puanı "Oyna"ya basmadan önce bakılan tek sayı.
     - **⚠ AÇIK KALAN AYRIŞMA — bir tur sonra kapandı (Parça 169):** rozetin
       puntosu/fontu web'de `clamp(8px,2vw,11px)` + mono, portta sabit `11` +
       tema sans'ıydı; yani port dar telefonda %19 daha geniş çiziyordu ve
       şikayetin asıl kaynağı buydu. **Parça 24'teki "web'de fluid olan değer
       portta sabit kalmış" sınıfının aynısı.** Bu PR'da KAPATILMAMIŞTI.
     - `board_render_test.dart` rozetin yalnızca METNİNİ kontrol ediyor
       (dolgusunu değil), bu yüzden düşmedi.

   - ✅ **Parça 166 — yaş/cinsiyet satırı BAŞKASININ kartında da (29
     Ağustos 2026, kullanıcı isteği; web + port aynı PR):** *"Yaş ve
     cinsiyet tüm kişi skor kartlarında ismin altında olmalı. Kendi
     profilimde görmemin hiç bir mantığı ve faydası yok."*
     - **Neden eksikti:** `Y:59/C:E` verisi `profiles`ten geliyor ve o
       tablonun SELECT RLS'i yalnızca KENDİ satırını okutuyor — başkasının
       kartını besleyen hiçbir kaynak (k-lig view'ı, `list_friends`,
       `game_likers`, çevrimiçi oyuncular, `admin_list_members`) bu iki
       alanı taşımıyordu. Yani eksik bir `if` değil, eksik bir VERİ YOLU.
     - **Sunucu:** `get_profile_age_gender` (security definer,
       `profile_age_gender_rpc` migration'ı, canlıya uygulandı). **Ham
       `birth_date` DEĞİL türetilmiş `age` dönüyor** — kart zaten yalnızca
       yaşı gösteriyor; `security definer` bir fonksiyonda "satırı olduğu
       gibi döndür" refleksi bilinçli kırıldı. Yetki `anon`a da verildi
       (kart misafire açık).
     - **Port:** `StatsGateway.profileAgeGender` + `StatsRepo.ageGenderLabel`
       (hata/veri yok → boş dizge, satır hiç çizilmez — web'in aynı kuralı);
       `PlayerScoreCardModal`'da ismin `Row`'u `Column`'a alındı, yaş satırı
       arkadaşlık simgesinin Row'unun DIŞINDA (içine konsaydı ikon hizası
       bozulurdu). `calculateAge`/`formatAgeGender` iki tarafta da ortak
       dosyaya çıkarıldı (`profileFields.ts` ↔ `profile_fields.dart`).
     - **⚠ Yaşın İKİ tanımı var:** kendi kartında istemci, başkasınınkinde
       sunucu hesaplıyor. İkisi de "tamamlanmış yıl"; ayrışırlarsa aynı
       oyuncu iki kartta farklı yaşta görünür — üç yerdeki (TS/Dart/SQL)
       yorumlar birbirine atıf yapıyor.
     - **Gateway'e metot eklemek `implements` eden BEŞ test sahtesini
       birden bozar** (`friends_test`, `score_card_test` ×2,
       `league_rewards_test`, `account_button_test`) — hepsi aynı PR'da
       tamamlandı. Regresyon: `score_card_test.dart`'a iki test (satır
       başkasının kartında çizilir; veri yoksa HİÇ çizilmez).
     - **Bu oturumda Dart SDK YOK** — `flutter analyze`/`dart test`
       koşulamadı, port derlemesi CI'da doğrulanacak. Web tarafı
       `npm run lint` + `npm run build` ile yeşil.
     - Aynı PR'da: `docs/decisions/components-score.md`, `TESTING.md`,
       `mobile/TESTING.md`.
     - **Yayın sırası yüzünden bir tur geri alındı:** #369 zamanından önce
       `main`'e girmişti, #370 ile revert edildi ve Faz 1 paketiyle birlikte
       (bu PR, a6a1776'nın revert'ü) geri geldi. Değişiklikte kusur yoktu.
       `get_profile_age_gender` bu süre boyunca Supabase'de CANLI kaldı —
       migration dosyaları uygulanmış olanın aynası olmak zorunda, o yüzden
       #370 migration'a dokunmamıştı; dönüşte sunucuda yapılacak iş YOKTU.

   - ✅ **Parça 165 — bağlantı geri gelince avatar kendini toparlamıyordu
     (29 Ağustos 2026, cihazda bildirildi):** *"app açıkken internet gelince
     avatar güncellenmedi, sadece aç kapa yapınca düzeliyor."*
     - **Kök sebep:** `KAvatar`ın `_broken` bayrağı YALNIZCA url değişince
       sıfırlanıyordu (`didUpdateWidget`). Bağlantı kesikken bir kez düşen
       görsel, o widget yaşadığı sürece baş harflerde kalıyordu — kullanıcının
       tarifi birebir doğruydu.
     - ⚠ **Aynı gün bir kez "geçici ağ hatası" diye KAPATILMIŞTI ve o karar
       doğruydu:** ilk raporda avatar aç-kapa ile geldi, yani URL/politika
       sorunu yoktu. Yanlış olan teşhis değil, KAPSAMDI — asıl sorun görselin
       düşmesi değil, düştükten sonra bir daha DENENMEMESİYDİ. İkinci rapor
       farkı gösterdi.
     - **Çözüm — parametre DEĞİL kapsam:** `ui/online_scope.dart`
       (`InheritedNotifier<OnlineStatus>`) kökte bir kez kuruluyor; `KAvatar`
       `didChangeDependencies`'te çevrimdışı→çevrimiçi GEÇİŞİNİ yakalayıp
       `_broken`ı sıfırlıyor. `KAvatar`a `OnlineStatus` parametresi geçirmek
       ELENDİ: 19 çağrı yeri (16 dosya) var ve yeni bir çağrı yerinde birinin
       unutması hatayı sessizce geri getirirdi — bu kod tabanının en sık
       tekrarlayan sınıfı ("zincirin bir halkası güncellenmedi"). Kapsamla
       çağrı yerlerinin HİÇBİRİ değişmedi.
     - **Geçiş yakalanıyor, her bildirim değil:** körlemesine sıfırlamak
       gerçekten bozuk bir URL'de sonsuz yeniden denemeye dönerdi.
     - **Kapsam yoksa davranış eskisiyle aynı** (`maybeOf`) — izole widget
       testleri kırılmadı; bunun kendi testi de var.
     - **Negatif eş kuruldu:** sıfırlama satırı kapatılınca test düşüyor.
     - **Doğrulama:** `dart analyze` temiz, **618 test** yeşil.

     - ✅ **CİHAZDA DOĞRULANDI (30 Ağustos 2026, 1.0.2 / `d3d4702`):** uçak
       modunda avatar baş harflere düştü (BEKLENEN — görsel indirilemez),
       uçak modu kapatılınca **uygulama yeniden başlatılmadan kendiliğinden
       geri geldi.** Düzeltme 29 Ağustos'ta yazılmıştı ama toparlanma yolu o
       güne kadar cihazda hiç ölçülmemişti; bu tur onu kapattı.
     - ⚠ **"Uçak modunda avatar baş harf" bir HATA DEĞİL** — aynı gün bu
       soru tekrar soruldu. Görsel ağdan geliyor; çevrimdışında alternatifi
       boş bir daire olurdu. Diske önbellekleme konuşuldu ve YAPILMADI:
       bağımlılık/depolama maliyeti var, kazanç kozmetik.
   - ✅ **Parça 164 — bağlantısızken hesap adı e-postaya düşüyordu (29 Ağustos
     2026, cihaz testi 6.3'te kullanıcı uçak modunda bildirdi):** *"T2 yerine
     KE yazıyor."*
     - **Kök sebep:** profilin yerel kopyası YOKTU, her açılışta sunucudan
       çekiliyordu. Bağlantı yokken çekim düşüyor, `_profile` null kalıyor ve
       `menuName` zinciri (`display_name` → `username` → ad soyad →
       **e-posta**) en sona iniyor; `KAvatar` da `kelimekitest2@…`'dan "KE"
       türetiyor. Oturum diskte yaşadığından kullanıcı GİRİŞLİ ama kim olduğu
       yanlış görünüyor. Listedeki oyun satırlarının doğru ("T2") olmasının
       sebebi: onlar yerel kayıttan geliyor, ağa ihtiyaçları yok.
     - **Web'de de aynı zincir var** (`UserMenu.tsx:144`) — yine ortak eksik,
       port farkı değil. Bu turda yalnızca port düzeltildi (web'de offline
       kullanım pratikte tarayıcı önbelleğine dayanıyor; ayrı bir iş).
     - **Çözüm:** `storage/profile_cache_store.dart` — profilin HAM satırı
       diske yazılıyor, çekim düşerse oradan devam ediliyor.
       ⚠ **Anahtar `user_id` ve bu bir tercih değil:** tek bir "son profil"
       kaydı tutulsaydı hesap değiştiren kullanıcı offline açılışta ÖNCEKİ
       kişinin adını görürdü — bu projede aynı sınıftan hatalar tekrar tekrar
       çıktı (`AccountScope`'un doğuş sebebi; aynı gün push token'ında İKİ
       kez daha). Kimliğe göre anahtarlamak yanlış kaydı okunamaz kılıyor.
       Çıkışta da siliniyor.
     - ⚠ **Test edilebilirlik için bir dikiş açıldı ve gerekçesi bugünün
       dersi:** `AuthService.fake`in istemcisi olmadığından `_fetchProfile`
       dalına HİÇ girilemiyordu — yani sahte uç, tam da düzeltilen davranışı
       test dışında bırakıyordu. Aynı boşluk aynı gün push token'ında iki
       gerçek hataya yol açmıştı (`FakeStore`'da RLS yok). Artık profil
       çekimi enjekte edilebiliyor (`profileFetcher`) ve testler GERÇEK yolu
       koşuyor: çekim patlatılıp önbellekten devam edildiği ölçülüyor.
     - **Negatif eş kuruldu:** önbellekten okuma satırları çıkarılınca test
       gerçekten düşüyor (`Actual: 'kelimekitest2@example.com'`).
     - **Doğrulama:** `dart analyze` temiz, **616 test** yeşil (609 + 7).
       Cihazda doğrulama yeni derleme bekliyor.

   - ✅ **Parça 163 — şifre kurtarma ekranının arkası bomboştu (29 Ağustos
     2026, cihaz testi 4.4 sırasında kullanıcı bildirdi):** *"Şifre değiştirme
     modalının arkası boş ekran. En azından kelimeki logosu görünmeli."*
     - **Önce web okundu** ve orada da AYNI olduğu görüldü (`App.tsx:1178`,
       `passwordRecovery` dalı: yalnızca ortalanmış modal). Yani bu bir port
       farkı DEĞİL, iki tarafın ORTAK eksiği — düzeltme aynı PR'da ikisine de.
     - **Gerekçe kozmetikten fazlası:** bu ekrana kullanıcı bir E-POSTA
       LİNKİNDEN düşüyor, yani uygulamayı henüz hiç görmemiş olabilir. Beyaz
       bir sayfada şifre isteyen bir kutu, kimlik avı ekranından ayırt
       edilemez. Logo, "doğru yerdesin"in en ucuz kanıtı. Boyut Setup'la aynı
       (52) — farklı bir ölçü iki ekranı yabancılaştırırdı.
     - ⚠ **NEGATİF EŞ İKİ KEZ SESSİZCE GEÇTİ; testin kendisi iki ayrı
       sebepten anlamsızdı ve ikisi de ölçülerek bulundu:**
       1. `find.byType(LogoMark)` — arkadaki Setup ekranı da bir logo
          çiziyor, yani logo hiç olmasa bile eşleşiyordu.
       2. Anahtar `Positioned.fill`e kondu — ölçülen kutu TÜM EKRAN olduğu
          için konum kontrolü her zaman ekran merkezini görüyordu (logo 300,
          modal 300).
       Anahtar `LogoMark`ın kendisine taşındı; şimdi logo kaldırılınca test
       GERÇEKTEN düşüyor. Ders, Parça 162'nin sıra testiyle aynı: **bir
       finder'ın eşleşmesi, ARADIĞIN ŞEYİ bulduğu anlamına gelmiyor** —
       özellikle aynı türden widget ekranda birden fazla varken.
     - **Doğrulama:** `npm run lint` (tsc) temiz, `dart analyze` temiz,
       **609 test** yeşil.

   - ✅ **Parça 162 — push token'ı hesap değişiminde DEVROLMUYOR, çıkışta
     SİLİNMİYOR: iki ayrı RLS/sıra hatası (29 Ağustos 2026, gerçek cihaz
     testi adım 2.4-2.5'te bulundu):** Aynı telefonda Alp Çapa çıkıp T2
     girdi; `push_tokens` satırı ESKİ kullanıcıda kaldı.
     - **Kanıt tahmin DEĞİL:** uygulamanın yaptığı upsert'ün birebir aynısı
       T2 kimliğiyle canlıda koşturuldu (işlem içinde, `rollback`):
       `ERROR 42501: new row violates row-level security policy (USING
       expression) for table "push_tokens"`.
     - **HATA 1 — devir (2.5).** Birincil anahtar `token`. İkinci kullanıcının
       upsert'ü çakışıp UPDATE dalına düşüyor; `push_tokens_update_own`
       politikası `USING (auth.uid() = user_id)` ile MEVCUT satıra bakıyor,
       satır hâlâ eski kullanıcının olduğundan yeni kullanıcı için görünmez.
       **Çözüm:** `register_push_token` (SECURITY DEFINER) —
       `user_id` istemciden ALINMIYOR, `auth.uid()`ten geliyor, yani token
       başkasının üstüne yazılamaz. Politikalar sıkı kaldı.
     - **HATA 2 — çıkış (2.4).** Temizlik `onAuthStateChange` dinleyicisine
       bağlıydı, yani oturum ZATEN kapandıktan SONRA koşuyordu; o anda
       `auth.uid()` null olduğundan DELETE de RLS'e takılıp hiçbir satıra
       dokunmuyor ve hata vermiyordu. Sorun kodda değil SIRADA. **Çözüm:**
       `AuthService.registerBeforeSignOut` — temizlik kimlik hâlâ elimizdeyken
       koşuyor (`bootstrap.dart` bağlıyor).
     - **BEDELİ boşa gönderim DEĞİL, YANLIŞ KİŞİYE gönderim:** eski hesaba
       gidecek bildirim, yeni hesabın girişli olduğu telefona düşer. Parça
       159'un kapattığını sandığımız risk, başka bir mekanizmayla açık kalmış.
     - ⚠ **`push_gateways.dart`taki yorum "satır B'ye DEVREDİLİR" diyordu** —
       kağıt üzerinde doğru, üretimde yanlış bir değişmez DAHA (Parça 159'un
       aynısı, üçüncü kez). Birim testi göremedi çünkü `FakeStore` yazılanı
       listeye ekliyor: test çağrının YAPILDIĞINI kanıtlıyor, yazmanın
       TUTTUĞUNU değil.
     - **NEGATİF EŞ İLK SÜRÜMDE GEÇTİ — testin kendisi hatalıydı.** Sıra
       testi `signOut`u sarmalayıp bitişte işaretliyordu; temizlik içeride
       ister önce ister sonra koşsun sıra aynı görünüyordu. Gerçek çıkış adımı
       `oturumuKapat()` diye ayrılıp işaretlenebilir yapıldı; şimdi yanlış
       sırada `['signOut', 'temizlik']` verip düşüyor (ölçüldü).
     - **Kaynak taraması testi eklendi** (`push_token_rpc_test.dart`): istemci
       RPC kullanıyor mu, tabloya doğrudan upsert geri gelmiş mi, RPC'ye
       `user_id` geçiliyor mu, migration repoda ve SECURITY DEFINER mı. ⚠ Bu
       test de ilk sürümde KENDİ yorumunu yakalayıp düştü — kaynak taraması
       yorumları atmalı, yoksa gerekçeyi yazmak testi bozuyor.
     - **Doğrulama:** migration canlıya uygulandı (`20260829083504`,
       `list_migrations` ile dosya adı eşitlendi), RPC gerçek T2 kimliğiyle
       koşturulup devrin TUTTUĞU ölçüldü (tek satır, sahibi T2; rollback).
       `dart analyze` temiz, **608 test** yeşil.
     - ⚠ **Cihazda doğrulama BEKLİYOR:** sunucu tarafı anında canlı, istemci
       düzeltmesi yeni bir derleme gerektiriyor. 2.4/2.5 ancak o derlemeyle
       tekrar koşulabilir.

   - ✅ **Parça 161 — sistem yazı boyutu büyütülünce düzen patlıyordu; tavan
     + iki yapısal düzeltme (28 Ağustos 2026, kullanıcı cihazda bildirdi):**
     *"Görmediği için telefon fontlarını büyütenlerde ciddi sorunlar
     çıkıyor. Mesela, arkadaşlık davetinde davetin kimden geldiği
     görünmüyor. Bunun dışında başka yerler de patlıyor."*
     - **ÖNCE ENVANTER, sonra kod** — kullanıcı *"başka yerler"* demişti ve
       hangileri olduğu bilinmiyordu. Yöntem: geçici bir
       `test/flutter_test_config.dart` ile TÜM takıma ölçek enjekte edildi
       (`platformDispatcher.textScaleFactorTestValue`), taşma satırları
       ayrıştırıldı. Ölçüm ancak böyle mümkün oldu; iki örnekten genelleme
       yapılsaydı yanlış yere bakılırdı.

       | ölçek | taşma | ayrı nokta |
       |---|---|---|
       | 1,0 | 0 | — |
       | 1,3 | 10 | 1 |
       | 1,6 | 27 | 4 |
       | 2,0 | **73** | 9 (en büyüğü 392 px) |

     - **İKİ AYRI HATA SINIFI olduğu buradan çıktı** ve bu, işin en önemli
       bulgusu: kullanıcının BİLDİRDİĞİ hata (ismin görünmemesi) yukarıdaki
       ölçümlerin HİÇBİRİNDE yok — çünkü taşma üretmiyor. Satırdaki tek
       esnek öğe eziliyor, Flutter hiçbir şey basmıyor, kullanıcı yalnızca
       bilginin kaybolduğunu görüyor.
     - **Karar (kullanıcıya soruldu, iki seçenek de ölçümle sunuldu):**
       tavan **1,3** + kalan noktaları düzelt. *"Hiç kısma, 9 yeri de
       düzelt"* ve 1,6 seçenekleri de sunuldu. Bedeli açıkça yazılı: fontu
       %200'e alan kullanıcı uygulamada %130 görür. 1,0'a kilitlemek
       (ölçeği tamamen yok saymak) erişilebilirlik açısından savunulamazdı.
     - **Üç değişiklik:**
       1. `ui/text_scale.dart` (YENİ) — `kMaxTextScale` (1,3),
          `kWideLayoutScale` (1,15) ve `buyukOlcek(context)`. Tavan TEK
          yerden: `MaterialApp.builder` → `withClampedTextScaling`.
       2. `board_widget.dart` alt şeridi `Row` → **`Wrap`**. Tavandan sonra
          KALAN TEK taşma noktasıydı (8,3-14 px). İki grup da `shrink-0`
          (web'de de öyle), yani `Row` sığmadığı anda taşıyor.
          ⚠ **Buradaki *"`Wrap` tek satıra sığdığı sürece `Row`la birebir
          aynı davranıyor — `tap_target_test`in golden dikdörtgenleri hiç
          kıpırdamadı"* cümlesi YANLIŞTI ve iki gün sonra sahada patladı
          (bkz. Parça 170).** `Wrap` genişliği doldurmaz, küçülür; testin
          sessiz kalması da kanıt değildi (o test kutu BOYUTU ölçüyor,
          KONUM değil).
       3. `friends_modal.dart` "İstekler" satırı büyük ölçekte **ikiye
          bölünüyor** (üstte avatar+isim, altta KABUL ET/REDDET).
          **Yalnızca bu liste:** "Arkadaşlarım"/"Ara & Ekle" satırlarının
          aksiyonu 44 px sabit İKON butonu, metin değil — ölçekle
          büyümediklerinden ismi de ezmiyorlar.
     - **SONUÇ ÖLÇÜLDÜ:** ölçek 1,3'te taşma **10 → 0**. İstek satırındaki
       isim genişliği (360 px ekran): 1,0'da 77,6 px (değişmedi) · 1,3'te
       **53,2 → 121,4** · 2,0'da **0,0 → 187,0**.
     - **Negatif eş kuruldu:** `kWideLayoutScale` geçici olarak 99'a
       çekilince (bölme fiilen kapalı) test GERÇEKTEN düştü — isim 1,3'te
       yine 53,2 px'e indi.
     - **Testin ölçütü MUTLAK genişlik DEĞİL, 1,0'daki kendi genişliği** ve
       bunun sebebi ölçümle bulundu: 360 px'lik dar bir ekranda "Esiner
       Yıldırım" ölçek 1,0'da BİLE tam sığmıyor (77,6 px'te üç noktaya
       iniyor). Mutlak bir eşik ya bugünü hatalı sayardı ya da hiçbir şeyi
       yakalamazdı. Kural: yazı büyüdüğünde isme ayrılan yer KÜÇÜLMESİN.
     - ⚠ **Takımın tamamını 1,3'te koşturmak CI kapısı OLAMAZ** (denendi ve
       ölçüldü): 31 test düşüyor, çoğu gerçek hata değil — bu projede
       birçok test web paritesini piksel piksel ölçüyor ve ölçek değişince
       o ölçümler tanım gereği kayıyor. Kalıcı kapı bu yüzden dar:
       `test/text_scale_test.dart` geometriyi değil "taşma var mı / bilgi
       kayboluyor mu" sorusunu ölçüyor. Envanteri yeniden çıkarmak
       gerekirse yukarıdaki geçici config yöntemi kullanılır.
     - **2,0'da hâlâ 59 taşma var ve bu bilinçli bırakıldı** — tavan
       yüzünden bugün ERİŞİLEMEZ. Tavan ileride yükseltilirse sıra şu:
       `game_history_modal:827` (29) · `account_button:517` (6) ·
       `game_over_modal:140` · `dialog_shell:169` · `live_games_tab:669/758`
       · `move_history_modal:283` · `score_stats_section:190` ·
       `board_widget:549`.
     - **Doğrulama:** `dart analyze` temiz, **604 test** yeşil (601 + 3).

   - ✅ **Parça 160 — istatistik etiketleri `FittedBox` yüzünden 8 px yerine
     ~5,5 px çiziliyordu (28 Ağustos 2026, kullanıcı cihazda bildirdi):**
     *"app'de oyun istatistikleri başlıkları tek satır ve çok küçük font.
     Web'le aynı olmalı."*
     - **Önce web okundu** (kuralın kendisi: "Sorun Bildirildiğinde İLK ADIM").
       `ScoreStatsSection.tsx`'te etiket düz bir `div`:
       `text-[8px] uppercase tracking-[1px]` — punto SABİT, metin hücre
       içinde SARIYOR. Hiçbir küçültme/ölçekleme yok.
     - **Port farkı YAPISALDI, değer değil:** `_CellBox`'ta etiket
       `FittedBox(fit: BoxFit.scaleDown)` içindeydi. `FittedBox` çocuğuna
       SINIRSIZ genişlik verir → `Text` sarmayı hiç denemez, tek satıra
       dizilir, sonra kutuya sığsın diye KÜÇÜLTÜLÜR. Etiket ne kadar uzunsa
       o kadar küçülür, yani kutular arasında punto bile tutmuyordu.
     - **ÖLÇÜLDÜ** (`flutter test`, KModal'ın gerçek genişliğiyle: 360 −
       gövde dolgusu 40 = 320 içerik, birim (320−16)/3 = 101,3, hücre iç
       genişliği 93,3): "EN YÜKSEK PUANLI KELİME" doğal hâlde **135,6 px** →
       ölçek 0,69 → 8 px punto ekranda **~5,5 px**. Kullanıcının gördüğü tam
       olarak buydu.
     - **Düzeltme tek satır:** etiketin `FittedBox`ı kaldırıldı; punto 8'de
       sabit, metin sarıyor. Kutu bir-iki satır uzuyor — `IntrinsicHeight`
       zaten aynı satırdaki kutuları en uzuna hizaladığından ızgara kendini
       topluyor (ekran görüntüsüyle doğrulandı).
     - **DEĞERİN `FittedBox`ı KALDI ve bu bilinçli:** oradaki iş farklı —
       "LÖSEMİT" gibi uzun bir kelime tek satırda kalmalı, sarmamalı; web'de
       de `text-xl` tek satır ve uzun kelimede taşar. Yani aynı sarmalayıcı
       bir yerde hata, öbür yerde çözüm.
     - **Negatif eş yerelde kuruldu:** test ÖNCE yazıldı ve mevcut kodda
       gerçekten düştü (135,6 > 93,3), sonra düzeltmeyle geçti —
       `score_stats_label_test.dart`, iki kontrol: (1) etiketin kendi kutusu
       hücrenin iç genişliğini aşmıyor (FittedBox geri gelirse patlar),
       (2) punto 8 / tracking 1 / ortalı, yani web değerleri.
     - **Doğrulama:** `dart analyze` temiz, **601 test** yeşil (599 + 2),
       skor kartı ekran görüntüsü yeniden üretilip gözle bakıldı.
     - **Aynı sınıfın taraması yapıldı:** `lib/src/ui` altında 8 `FittedBox`
       daha var (neo_button, tile_widget, game_header, intro ×3, bu dosyada
       değer + sekme etiketi). Hepsi TEK SATIRLIK kısa metin ölçekliyor,
       yani bu hatanın koşulu (uzun + sarması beklenen metin) yalnızca
       burada vardı. **Kural: `FittedBox`, SARMASI GEREKEN bir metnin
       üstüne konmaz** — sarma ile ölçekleme birbirini dışlar.
     - ⚠ **Bu, "sistem fontu büyütülünce patlıyor" maddesiyle KARIŞTIRILMASIN**
       (`mobile/CLAUDE.md` → "Sonraya Bırakılan İşler"). O ayrı ve hâlâ açık;
       hatta `FittedBox` orada semptomu GİZLİYORDU (büyüyen metni sessizce
       küçültüp taşmayı saklıyordu). Bu düzeltme o maddeyi kapatmaz.

   - ✅ **Parça 159 — push token'ı Canlı sekmesine bağlıydı; DEĞİŞMEZ
     kâğıt üzerinde kalmış (28 Ağustos 2026, İLK gerçek cihaz testinde
     bulundu):** Parça 158'in dokümana yazdığı değişmez şuydu — *"tabloda
     satır varsa o cihaz bildirim GÖSTEREBİLİR; her açılışta `senkronize`
     ile kendini onarır."* İkinci yarısı **yanlıştı.** `senkronize` tek bir
     yerden çağrılıyordu:
     `push_repo.senkronize ← pushIzniAkisi ← live_games_tab.dart:274`.
     - **Cihazda ölçüldü:** bildirim sistem ayarlarından kapatıldı, uygulama
       tamamen kapatılıp açıldı → satır DURDU, `updated_at` bile değişmedi
       (17:52:52'de donmuş). Canlı sekmesi açılınca AYNI SANİYE silindi.
       Yani `PushRepo`'nun kendisi doğruydu; **tetikleyici yanlış yerdeydi.**
     - **Sonucu sessiz ve kalıcı:** bildirimi kapatan ama Canlı sekmesine
       girmeyen kullanıcının token'ı sonsuza kadar tabloda kalır — sunucu
       göndermeye devam eder, işletim sistemi yutar. Kimse şikayet etmez.
     - **Aynı denetimde İKİNCİ boşluk:** `temizle()` **hiçbir yerden**
       çağrılmıyordu (`grep` sıfır sonuç). Yani ÇIKIŞ da satırı bırakıyordu:
       sunucu, o hesabın oturumu KAPALI bir cihaza göndermeye devam ederdi.
       Kontrol listesindeki 2.4 maddesi henüz sıraya gelmemişti, düşecekti.
     - **Kök kusur tek cümle:** *sistem ayarı uygulamanın DIŞINDA değişiyor.*
       Bunu yakalamanın tek güvenilir anı uygulamanın öne dönüşü; bir
       sekmenin açılmasına bağlamak yapısal olarak yetersiz. `app.dart`'ta
       o güne kadar hiç `WidgetsBindingObserver` yoktu.
     - **Düzeltme:** hizalama `pushIzniAkisi`'nden ayrılıp
       `pushTokenlariHizala` oldu (izni döndürüyor, böylece akış onu tekrar
       okumuyor — çift kaynak yok). `_HomeGate` artık `WidgetsBindingObserver`:
       **açılış + `resumed` + oturum değişimi**. Çıkışta (`user == null`)
       `temizle()`. Canlı sekmesindeki çağrı kalıyor ama artık tek yol değil.
     - **`push_lifecycle_test.dart` (4 test):** açılışta hizalama koşuyor
       (Canlı sekmesi GEREKMEZ), öne dönüşte sistem ayarındaki kapatma
       yakalanıyor, çıkışta token siliniyor, ve push YOKKEN (web/Firebase
       yok) kapı sorunsuz açılıyor. Negatif eş: `_pushHizala` etkisizleştirilince
       ilk üçü GERÇEKTEN düşüyor, dördüncüsü doğru şekilde geçmeye devam ediyor.
     - **DÖRDÜNCÜ belirti, aynı kök sebep (aynı tur, cihazda):** hesap
       değiştirilince token devrolmuyordu. T2 ile girilip satır T2'ye
       yazıldı; Ironman'a geçildi, uygulama Ironman gösteriyordu ama satır
       **T2'de kaldı** (`updated_at` bile değişmedi). Bunun bedeli boşa
       gönderim DEĞİL, **yanlış kişiye gönderim**: T2'ye gidecek bildirim
       Ironman'ın girişli olduğu telefona düşer.
       - Kodu okurken ortaya çıkan asıl sebep daha da geniş: hizalama
         `live_games_tab._reload()`'un İÇİNDE ve o da liste yüklemesi
         düşerse (`snap == null`) erken dönüyor. Yani devir üç ayrı yoldan
         atlanabiliyordu — sekme açılmadı, sekme yeniden kurulmadı, ya da
         liste yüklemesi düştü.
       - ⚠ Bu bulguyu ararken **yanlış bir tahmin yaptım ve düzelttim:**
         "`_reload` hesap değişiminde koşmuyor" dedim; kod tersini söylüyor
         (`_onAuthEvent` → `_reload`). Tahmini kaynağı okumadan söylemek bu
         turda bir tur yaktı.
       - Testi eklendi (`HESAP DEĞİŞİMİNDE token yeni kullanıcıya devrolur`);
         negatif eş: `_HomeGate`'in auth dinleyicisi kaldırılınca hem bu test
         hem "ÇIKIŞTA token silinir" düşüyor.

     - **Ders — bu günlüğün kendisine dair:** "değişmez" diye yazılan bir
       cümle, onu ZORLAYAN bir test yoksa yalnızca bir NİYET. Parça 158
       değişmezi doğru tarif etmişti; eksik olan, tetikleyicinin o tarifi
       gerçekten karşılayıp karşılamadığının hiç sorulmamasıydı. Cihaz
       testinin ilk yarım saatinde çıktı — `flutter test`in sahte uçları bunu
       yapısal olarak göremezdi, çünkü hata KODDA değil KODUN BAĞLANDIĞI
       YERDEYDİ.

   - ✅ **Parça 158 — push bildirimleri + kayıt onayının uygulamaya dönüşü
     (28 Ağustos 2026, ROADMAP madde 1 + 13 — "Sürüm B"nin mağaza blokeri):**
     Tek paket, çünkü madde 13'ün 5. adımı ("bildirime dokun → doğru oyun
     açılsın") madde 1'in derin bağlantı kanalına dayanıyor.
     - **Kanal (madde 1):** `AuthService.signUp` artık `emailRedirectTo`
       geçiyor. Değer önce `kelimeki://auth` yazıldı, **aynı gün
       `https://kelimeki.com/auth`'a çevrildi** (kullanıcı: *"Güvenli
       alternatif olsun"*): custom şema, uygulamanın kurulu OLMADIĞI bir
       tarayıcıda `ERR_UNKNOWN_URL_SCHEME` veriyor — insanlar postalarını
       sıklıkla masaüstünden okuduğu için bu nadir değil, ve onay linki
       BOZUK görünüyor. Oysa e-posta doğrulaması GoTrue'nun `/verify` ucunda
       zaten tamamlanmış oluyor; kaybedilen tek şey oturum. https biçiminde
       en kötü durum bugünkü davranıştır (siteye düşer, elle giriş), en iyi
       durumda App Links URI'yi uygulamaya düşürür ve PKCE takası
       kullanıcıyı DOĞRUDAN girişli bırakır. Manifest `https://kelimeki.com`ın
       tamamını talep ettiğinden ek intent-filter GEREKMEDİ, Redirect URLs'te
       `https://kelimeki.com/**` da zaten vardı — yani Dashboard el işi SIFIR.
       - **supabase_flutter'ın şemaya BAKMADIĞI ölçüldü** (paket kaynağı,
         `_defaultIsAuthCallbackDeeplink`): yalnızca `code`/`access_token`/
         `error*` parametrelerine bakıyor. Yani https bir dönüş custom şema
         kadar sorunsuz işleniyor; bu, kararın dayandığı tek teknik varsayımdı
         ve tahmin edilmedi.
     - **`util/deep_link.dart` — gelen URI'lerin TEK ayrıştırma noktası.**
       Öncesinde üç ayrı yer kendi tanımasını yapıyordu (supabase_flutter,
       `FriendInviteInbox`, ve şimdi dördüncüsü olarak push). Saf fonksiyon,
       Flutter bağımlılığı yok. `kelimeki://oyun/<id>`in https karşılığı
       BİLEREK yok — o linki üreten tek şey bir push bildirimi, o da yalnızca
       uygulamanın kurulu olduğu cihazda var.
     - **Sunucu (FCM HTTP v1, `supabase/functions/_shared/push.ts`):** servis
       hesabı → RS256 JWT → OAuth2 token → gönderim. Hiçbir genel fonksiyon
       FIRLATMIYOR — bildirim, e-postanın yanında ikincil bir kanal; onu
       düşürmesi kabul edilemez. `notify-deadline-warnings` e-postadan SONRA
       push atıyor ve `UNREGISTERED`/`INVALID_ARGUMENT` dönen token'ı siliyor.
       - **Kimlik zinciri CİHAZSIZ kanıtlandı:** `push-selftest` bilerek
         GEÇERSİZ bir token'a gönderiyor; dönen `unregistered: true`
         "Google kimliğimizi kabul etti, yalnızca token'ı tanımadı" demek —
         yani sır/JWT/OAuth zincirinin tamamı sağlam. Sonuç ölçüldü:
         `{"yapilandirildi":true,"kimlikZinciriSaglam":true}`. Teşhis
         fonksiyonu; silinebilir.
       - Yeniden dağıtımda `verify_jwt: false` AÇIKÇA geçildi (araç parametre
         verilmezse `true` varsayıyor ve öncekini KORUMUYOR) — liste kök
         `CLAUDE.md`'de altıdan yediye çıktı. Aynı dağıtım, repoda duran ama
         hiç canlıya çıkmamış "taktirde"→"takdirde" düzeltmesini de taşıdı.
     - **İzin isteme ANI bir ürün kararı:** açılışta ya da girişte
       SORULMUYOR. Tetikleyici *"Canlı sekmesi açıldı VE en az bir aktif
       oyun/bekleyen davet var"*. Gerekçe Android 13+'ın kuralı: İKİNCİ
       reddin ardından sistem diyaloğu bir daha HİÇ gösterilmiyor, yani
       bağlamsız sorulan bir soru KALICI kayıp. Bu yüzden önce kendi
       penceremiz çıkıyor; sistem diyaloğu ancak kullanıcı "Aç" derse
       tetikleniyor — "Şimdi Değil" bir sistem denemesi HARCAMIYOR. Kendi
       penceremiz de en çok 3 kez, 7 gün arayla (`util/push_rules.dart`, saf
       karar). Karar AndroidManifest'e de yorum olarak yazıldı, çünkü izni
       oradan gören biri "neden hiç sorulmuyor?" diye arayacak.
     - **DEĞİŞMEZ: `push_tokens`ta satır varsa o cihaz bildirim
       GÖSTEREBİLİR.** Her açılışta `PushRepo.senkronize` sistem iznini okuyup
       satırı ekliyor/siliyor — yani ayarlardan bildirimi kapatan kullanıcı
       için ayrı bir dinleyici GEREKMİYOR, sistem kendini bir sonraki açılışta
       onarıyor. Tablonun birincil anahtarı TOKEN (kullanıcı değil): cihaz
       hesap değiştirince satır TAŞINIR, çoğalmaz.
     - **BULUNAN HATALAR (üçü de kod yazılırken, kullanıcıdan önce):**
       1. **`temizle()` yeniden başlatmalardan sonra ÇALIŞMIYORDU** — bellekteki
          `_sonToken`e güveniyordu, o da taze bir süreçte `null`. Bildirimi
          kapatıp uygulamayı kapatan kullanıcının token'ı sonsuza kadar kalırdı.
          Artık CANLI token FCM'den okunuyor, bellek yalnızca yedek. **Bir test
          buldu.**
       2. **Token yenilemesi ESKİ satırı sızdırıyordu** — anahtar token olduğu
          için yenileme yeni satır açıp eskisini bırakıyordu; artık yenilemede
          eski token siliniyor.
       3. **Yanlış bir varsayımla gereksiz bir sayaç yazılmıştı:** eklentinin
          "kalıcı red"i bildirmediği sanılıp `FlagsStore`'a ikinci bir doğruluk
          kaynağı kondu. `dart analyze`ın non-exhaustive-switch uyarısı
          `AuthorizationStatus.deniedPermanently`in VAR olduğunu kanıtladı;
          sayaç kaldırıldı ve `flags_store.dart`'a "geri ekleme" notu bırakıldı.
          **Bunu bir test değil DERLEYİCİ yakaladı** — enjekte edilebilir bir
          dikişin arkasındaki kütüphane yüzeyini okumadan sarmalayıcı yazmanın
          bedeli.
     - **`push_init.dart` neden var:** `Firebase.initializeApp()` web'de ve
       Android/iOS dışında yapılandırma bulamayıp FIRLATIYOR — GitHub Pages'teki
       Flutter web test ortamı açılışta ölürdü. `initFirebase()` `false` dönüyor
       ve push tamamen devre dışı kuruluyor; uygulamanın geri kalanı etkilenmiyor.
     - **Doğrulama:** `dart analyze` temiz (tek ön-var olan info hariç),
       **591/591** Flutter testi geçiyor (`deep_link` · `push_rules` ·
       `push_repo` · `push_permission_flow` · `push_permission_mapping`), Deno
       tarafında `_shared/push_test.ts` 4 test (RS256 imzala-doğrula turu
       dahil). Negatif eşler kuruldu: yeni https `/auth` dalı silinince
       `deep_link_test` GERÇEKTEN düşüyor.
     - **DOĞRULAMA SINIRI — cihazda hiçbir şey görülmedi.** Android derlemesi
       Firebase'le (google-services eklentisi + üç paket + Kotlin kanal kodu)
       bir kez bile DERLENMEDİ; bildirimin gerçekten düşmesi, kanal kimliğinin
       tutması ve App Links doğrulaması yalnızca gerçek cihazda görülebilir.
       Kontrol listesi: `mobile/docs/testing-bildirimler.md`.

   - ✅ **Parça 157 — merkez X3 etiketi büyütüldü (28 Ağustos 2026, kullanıcı
     isteği: *"en ortadaki X3 yazısını da biraz büyütelim"*):**
     `clamp(7px,1.9vw,12px)` → `clamp(9px,2.6vw,16px)`, web ve portta birden
     (`Board.tsx` ↔ `board_widget.dart`). 420 px'lik bir telefonda
     **7,98 px → 10,9 px** (~%37); 834 px'te tavan 12 → 16.
     - **Bu ölçünün geçmişi var ve düzeltme BOZULMADI:** 17 Ağustos'ta port
       aynı yazıyı `FittedBox` ile hücreyi doldurarak ~37 px basıyordu ve
       kullanıcı "boyut/tasarım farklı" diye bildirmişti; o gün web'in 12 px
       tavanına çekildi. Bugünkü artış yalnızca TAVANI yükseltiyor — punto
       hâlâ hücreye değil EKRAN genişliğine bağlı, yani iki platform aynı
       hesabı yapmaya devam ediyor.
     - **İKİ ayrı test katmanı yakaladı ve ikisi de güncellendi/kanıtlandı:**
       `layout_parity_test.dart` KAYNAKLARI karşılaştırıyor (Board.tsx'in
       clamp'i ↔ board_widget'ın fluidSize'ı) — negatif eş kuruldu: yalnızca
       web eski değere döndürülünce test GERÇEKTEN düştü, yani tek taraflı
       bir değişiklik sessizce geçemiyor. `board_render_test.dart` ise RENDER
       EDİLEN puntoyu ölçüyor ve beklenen değerleri taşıyordu (12 → 16,
       7,41 → 10,14). İkisi ayrı katman; parite testi "aynı sayı yazılmış
       mı" der, render testi "gerçekten o punto mu çiziliyor" der.
     - **Doğrulama:** `dart analyze` temiz (yalnız önceden var olan 1 info),
       `flutter test` **557/557**, `npm run lint` temiz. Önce/sonra yakın
       plan ekran görüntüsü kullanıcıya gösterildi.
     - **Açık soru (kullanıcıya soruldu):** 16 px tavan yeterli mi, daha
       büyük mü olsun? Tek sayı değişikliği.

   - ✅ **Parça 156 — iki görsel kural: jokerin puanı KIRMIZI, skor kutusundaki
     SAYI siyah (28 Ağustos 2026, kullanıcı isteği — Sürüm B):** İkisi de
     küçük ama ikisi de web+port paritesi taşıyor.
     - **Joker:** tahtaya/taslağa konmuş jokerin `0` puanı artık token
       kırmızısı (`kRed` / tailwind `red`, `#DC2626`). Öncesinde diğer
       taşların puanıyla AYNI renkteydi (`accent`), yani jokerin nereye
       harcandığı tahtada hiç görünmüyordu. **RAF taşı BİLİNÇLİ dışarıda:**
       orada joker zaten ★ ile ayırt ediliyor ve altın zeminde kırmızı
       okunmuyor; istek de birebir "tahtaya konulan joker" diyordu.
       Kullanıcı, oyuncu kırmızısı ile token kırmızısı arasında SEÇİM yaptı
       (token) — sağ-alt köşenin oyuncu rengiyle karıştırılmamalı.
     - **Skor kutusu:** üstteki kutulardaki SAYI siyah (`kText` / tailwind
       `text`). Etiket (`IRONMAN` / `YZ 2`), çerçeve ve zemin oyuncu
       renginde KALDI — istek birebir "sadece sayı" diyordu. `TESLİM` bir
       sayı değil, o da renkte kaldı.
     - **Dosyalar (dördü birden, parite):** `tile_widget.dart`
       (`_boardPtsColor`) ↔ `Tile.tsx`; `game_header.dart` ↔
       `GameHeader.tsx`. Port tarafında tek dosya iki oyun ekranını da
       (yerel + Canlı) kapsıyor, web'de de öyle — ayrıca bir şey gerekmedi.
     - **Testler + NEGATİF EŞLER (ikisi de ölçüldü).** Renk sapmasını
       hiçbir derleyici/analiz yakalamaz, bu yüzden iki test yazıldı ve her
       biri KIYAS iddiası taşıyor: joker testi sıradan taşın `accent`
       kaldığını da doğruluyor (yoksa "tüm puanları kırmızı yaptım" gibi bir
       aşırı-düzeltme testten geçerdi), skor testi etiketin siyaha
       ÇEVRİLMEDİĞİNİ doğruluyor. İki değişiklik tek tek geri alındı, ikisi
       de GERÇEKTEN düştü, sonra geri kondu.
     - **Test kendisi bir kez YANLIŞ yazıldı ve kayda değer:** etiket
       `find.text('Ironman')` ile aranmıştı, oysa `game_header.dart` onu
       `trUpper(player.name)` ile basıyor → `IRONMAN`. Test düştü ve hata
       kodda DEĞİL testteydi. Bu projenin Türkçe harf kuralının test
       tarafına yansıması: bir etiketi ararken de `trUpper`dan geçtiğini
       varsay.
     - **Doğrulama:** `dart analyze` temiz (yalnız önceden var olan 1 info),
       `flutter test` **557/557**, `npm run lint` (tsc) temiz. Ekran
       görüntüsüyle önce/sonra kullanıcıya gösterildi ve onaylandı.
     - **Doğrulama sınırı:** cihazda koşulmadı; ikisi de saf renk değişikliği
       olduğundan CanvasKit/Skia ayrışma riski yok (özel `Canvas` çizimi
       değil, düz `TextStyle.color`).

   - ✅ **Parça 153 — rozet oyundan DÖNÜŞTE tazelenmiyordu: web'in
     BEDAVA aldığı garanti portta yok (28 Ağustos 2026, kullanıcı bildirdi:
     *"Hiç bekleyen oyunum kalmamış olmasına rağmen tab'da 1 uzun süre
     durdu. Sonra ekran kapandı, açınca gitti."*):** "Arkadaşınla (N)"
     rozeti bayat kalıyor, ekran kapanıp açılınca (yani
     `AppLifecycleState.resumed`) düzeliyordu — kullanıcının tarifi bu
     yolun kendisiydi.
     - **Kök sebep bir YAPI farkı, bir unutulmuş kanca değil.** Web'de
       Canlı tahta açılınca `App.tsx` erken `return` ile Setup'ı
       AĞAÇTAN ÇIKARIYOR; dönüşte Setup remount olup rozet effect'ini
       baştan koşturuyor — yani web bu garantiyi bedavaya alıyor.
       Flutter'da Setup `MaterialApp.home` ve oyun ÜSTÜNE push ediliyor,
       **Setup hiç unmount olmuyor**. Aynı tuzak `setup_screen.dart:292`'de
       başka bir özellik için zaten yazılıydı (*"ekran hiç unmount OLMUYOR
       — 'Setup'a her geliş' notu bu yüzden yanıltıcıydı"*); rozet o
       dersten payını almamıştı.
     - **Liste bu garantiyi BAŞTAN BERİ taşıyordu:** `_openGame` dönüşte
       `_reload()` çağırıyor ve yorumu aynen şöyle: *"Realtime da tetikler
       ama dönüş anı garanti."* Rozet aynı satırın hemen yanında eksikti —
       Parça 148'in (27 Ağustos) düzelttiği çelişkinin AYNISI, farklı
       kancadan: kapsayan rozet, kapsanan listeyle çelişiyor.
     - **Düzeltme:** `LiveGamesTab.onGameClosed` callback'i;
       `SetupScreen` ona `_scheduleLiveBadgeRefresh`i veriyor. Yeni bir
       mekanizma değil, listenin zaten sahip olduğu anın rozete de
       verilmesi.
     - ⚠ **Sürüm B uyarısı koda yazıldı:** Canlı tahtayı açan İKİNCİ bir
       kapı eklenince (bildirime dokununca doğru oyunu aç) o kapı da bunu
       çağırmalı; iki kapı olduğunda doğru çare callback değil Setup'a
       takılacak bir `RouteObserver` (`didPopNext`).
     - **Bu, kaçırılan olayın kalıcı kayba dönüştüğü BEŞİNCİ yer** (sohbet
       Realtime'ı, bulut senkronu, `useOnlineStatus`, Parça 148). Olay
       tabanlı her durumun bir de olaydan bağımsız "kesin an"ı olmalı.
     - **Test:** `setup_screen_test.dart` +1 (547 test). Gerçek push/pop
       üzerinden: rozet 1 → oyuna gir → sunucuda iş biter ama HİÇBİR olay
       gelmez → pop → rozet gitmeli. **Negatif ikiz kanıtlandı** (tek satır
       kaldırılınca test düşüyor). İki tuzak ölçüldü: `find.byType` varsayılan
       olarak sahne dışını ATLAR (`skipOffstage: false` şart — hatanın
       kaynağı zaten Setup'ın sahne dışında MOUNT kalması), ve
       `tester.pageBack()` bir AppBar geri butonu arıyor (Canlı tahtanın
       kendi çıkış düzeni var, rota doğrudan pop ediliyor).
     - **Web ETKİLENMEDİ ve `src/` altında değişiklik gerekmedi** —
       `App.tsx:1190` ölçüldü: erken `return <OnlineGameScreen …/>`, yani
       Setup gerçekten unmount oluyor.

   - ✅ **Parça 152 — İKİ eşik tek sanılıyordu: titreşimli dokunuş
     (27 Ağustos 2026, kullanıcı Parça 151'den SONRA aynı şikayeti
     tekrarladı: *"Hâlâ tahtaya koyulan taşı her zaman alamıyorum. 1-2
     denemeden sonra alabiliyorum. Yine alt kısım çok iyi kavramıyor
     sanki."*):** Parça 151'in kurtarması YALNIZCA "parmak hiç kıpırdamadı"
     dalında çalışıyordu. ÖLÇÜLDÜ (420×900): 6 px kayan dokunuş taşı geri
     alıyor ama **12 ve 20 px kayanlar HİÇBİR ŞEY yapmıyordu**. Raf tarafı
     da aynı: titreşimli dokunuşta `selectedTile` null kalıyor, yani taş
     seçilemiyordu bile — daha önce "rafta harfi yakalamak zor" diye
     bildirilen şikayetin ikinci yarısı. **Hedefin ALANINI büyütmek onu
     çözmemişti çünkü sorun alanda değil JESTTE.**
     - **Kök sebep:** iki ayrı karar tek eşikle veriliyordu. "Hayaleti
       göster" için 10 px (Android touch slop) doğru; "bırakma mı dokunuş
       mu" için fazla dar — parmak o kadarını istemeden aşıyor. Artık ayrı
       bir bırakma eşiği var (`_tapSlopOnRelease` = 24, hücrenin ~26 px'inin
       hemen altında).
     - ⚠ **Eşik bir BELİRSİZLİĞİ de çözüyor, bilinçli:** bırakma noktası
       30 px kaldırılmış olduğundan "taşı bir üst hücreye taşı" jesti
       parmağın neredeyse hiç kıpırdamaması demek — "geri al" ile AYNI jest.
       Açık ara daha sık olan niyet seçildi: kısa jest = geri al. Taşıma
       hâlâ mümkün ve mevcut sürükle-bırak testi bunu koruyor.
     - **Raf için ek kısa yol:** jest hâlâ RAFIN ÜSTÜNDE bittiyse mesafeye
       bakmadan dokunuş sayılır (rafa taş bırakılmıyor). Bu, "raf taşına
       dokundum tahtaya kondu" riskini de kapatıyor — kaldırılmış nokta
       rafın 30 px üstünü, yani tahtanın alt satırını hedefliyordu.
     - **Ders:** bir eşik İKİ farklı soruyu cevaplıyorsa muhtemelen iki eşik
       olmalı. "Sürükleme başladı mı?" ile "kullanıcı bırakmak mı istedi?"
       aynı soru değil; ilkinin cevabı erken, ikincisinin geç verilmeli.
     - **`mobile/` DIŞINDA:** web `App.tsx` + `OnlineGameScreen.tsx` (aynı
       sayı, aynı gerekçe), `tests/smoke.spec.ts`,
       `docs/decisions/touch-ux-bugs.md`.
     - **Regresyon + negatif eş:** portta 6/12/20 px, web'de 8/14/22 px için
       ayrı testler; portta ayrıca "raf taşı seçildi VE istemeden tahtaya
       konmadı". Eşik 0'a çekilince iki platformda da düşüyorlar.

   - ✅ **Parça 151 — taslak taşı geri almak: ilk dokunuş yakalamıyordu
     (27 Ağustos 2026, kullanıcı Sürüm A'yı cihazda test ederken bildirdi:
     *"tahtaya konan taşı kaldırmak için ilk tıklama yakalamıyor. İkincide
     ya da üçüncüde yakalanıyor."*):** ÖLÇÜLDÜ (420×900): hücre **26,2 px**;
     taslak (0,0)'a konup hemen ALTINDAKİ boş hücreye dokunulduğunda taş
     geri alınmıyor ve ekrana **"Önce bir harf seç."** yazıyordu — geri
     almaya çalışana alakasız bir uyarı.
     - **Kör nokta 24 Ağustos'un KENDİ kısıtındaydı:** `draftRescue` o gün
       *"boş hücrelere hiç dokunulmaz — yoksa kelimeyi dizerken yan hücreye
       harf koymak zorlaşırdı"* diye sınırlanmıştı. Gerekçe doğru ama
       **yalnızca bir raf taşı SEÇİLİYKEN** geçerli; seçim yokken boş hücreye
       dokunmak zaten hiçbir iş yapmıyor (`_placeTile` sadece o mesajı üretip
       aynı durumu döner). Yani kurtarmanın bedeli o durumda sıfır.
     - **Koşul dar tutuldu:** `selectedTile == null && placed.isNotEmpty`.
       Seçili taş varken davranış HİÇ değişmedi ve bunu bir negatif eş testi
       koruyor (ikinci taş seçilip komşu hücreye konuyor).
     - **Ders:** bir kısıtın gerekçesini yazarken HANGİ DURUMDA geçerli
       olduğunu da yaz. "Boş hücrelere dokunma" tek başına doğru
       görünüyordu; eksik olan "…çünkü orada bir harf konabilir" koşuluydu.
     - **Dört yüzey:** port `game_screen.dart` + `online_game_screen.dart`,
       **`mobile/` DIŞINDA** web `App.tsx` + `OnlineGameScreen.tsx`,
       `tests/smoke.spec.ts`, `docs/decisions/touch-ux-bugs.md`.
     - **Regresyon:** iki platformda da bir pozitif (ıskalama geri alır) ve
       bir negatif (seçiliyken harf koyar) test. Negatif eşleri kanıtlandı —
       koşul `false` yapılınca ikisi de düşüyor.

   - ✅ **Parça 150 — tanıtımdaki "DEVAM ›" tam genişlikte ve ekranın
     dibindeydi (27 Ağustos 2026, kullanıcı bildirdi: *"ekranın altına
     yapışıyor ve ortalı değil. Bu kadar uzun olmasına da gerek yok, normal
     buton gibi olsun"*):** Üç kusurun üçü de ÖLÇÜLDÜ (390×844): buton
     x **0 → 378** (ekranın %97'si), alt kenarı **844** (tam dip), etiketi
     sağdaki 12 px dolgu yüzünden merkezin 6 px solunda. **Portrede de
     bozuktu** — kullanıcı yatayda fark etmiş ama sorun yöne bağlı değildi.
     - **Kök sebep düzende DEĞİL `NeoButton`da:** kökü `alignment` taşıyan
       bir `Container` ve `alignment` verilmiş bir Container kısıtların
       TAMAMINI kaplar. Buton `SizedBox(width: double.infinity)` içinde
       kullanılmak üzere tasarlanmış; tanıtımda öyle bir kap yok ama
       `TapTarget`in `Align`ı gevşetilmiş kısıtları (maxWidth = ekran) aynen
       geçiriyor. Çare `IntrinsicWidth`.
       **Ders:** "buton neden tam genişlikte" sorusunun cevabı çoğu zaman
       butonun KENDİSİNDE — kabına bakmadan önce kökünün `alignment` alıp
       almadığına bak.
     - **Noktalar sola alındı, buton ortaya — bu bir zevk kararı DEĞİL,
       ÖLÇÜM sonucu.** Önce "noktalar üstte, buton altında ortalanmış"
       denendi; `intro_screen_test`in taşma testi tam bu iş için var ve
       rakamı verdi: **1. slayt 430×710'da 25 px, 414×720'de 24 px taşıyor.**
       İkinci bir satırın dikey maliyeti bütçeyi aşıyor (Parça 143'te
       ölçülen pay ~10 px'ti; bu turda gerçek payın 6 px olduğu ölçüldü).
       Tek şeritte kalınca artış yalnızca alt boşluk kadar.
     - **Dolgu takası:** üst 4 → 0, alt 0 → 8 (net +4). Üstteki 4 px görünmez
       (slayt ile noktalar arası), alttaki 8 px kullanıcının bildirdiği
       kusurun ta kendisi. Gerçek cihazda `SafeArea` bunun ÜSTÜNE sistem
       çubuğu payını ekliyor.
     - **Sonuç (ölçüldü):** 390×844'te buton 83 px geniş, merkezi tam 195
       (= ekran merkezi), alt kenarı 836 → 8 px pay. 844×390 ve 740×360'ta
       da aynı: merkez tam ortada, alt pay 8.
     - **Web ETKİLENMEDİ:** karşılama katmanı bir slayt gösterisi değil,
       statik bir sayfa ("OYUNU BAŞLAT"); web'de "DEVAM ›" diye bir düğme
       yok. Bu parça yalnızca portu ilgilendiriyor.
     - **Regresyon + negatif eş:** yeni test üç iddiayı AYRI AYRI kilitliyor
       (normal boy · yatayda ortalı · alt kenara yapışmıyor), iki boyda
       (portre + yatay). `IntrinsicWidth` kaldırılınca test düşüyor
       (`Actual: <390.0>` vs beklenen `< 156.0`).
     - **EK (aynı gün, kullanıcı: *"Son slayt hemen oyna butonu üstündeki
       noktalara da gerek yok"*):** son slaytta nokta şeridi artık HİÇ
       çizilmiyor. Haklı bir istek — noktalar "daha var" göstergesi, oysa
       son slaytta daha yok ve hemen altında "HEMEN OYNA" duruyor; gösterge
       hem yanıltıcı hem gereksiz. Yan fayda: son slayt eskiden hem şeridi
       hem düğmeyi taşıyordu, artık şerit kadar dikey alan geri kazanıyor
       (`_RutbeSayfasi` en uzun slayt). Şeridi ölçebilmek için `_Noktalar`a
       `Key('intro-noktalar')` verildi — widget sınıfı özel olduğundan
       testin başka tutamağı yoktu. Negatif eş: koşul `if (true)` yapılınca
       test düşüyor.

   - ✅ **Parça 149 — oyun kartındaki üç ikon: üçüncü alet "YÖNLENDİR"
     (27 Ağustos 2026, kullanıcı sordu: *"oyun kartlarında yer alan mesaj
     balonu ve hamleler ikonu tıklaması nasıl? Orada da sorun var mı?"*):**
     Vardı — ve bunlar uygulamadaki EN KÜÇÜK hedeflerdi. Ölçüldü (390×844):
     kalp **15×13**, mesaj balonu **18.5×13**, hamle ikonu **19×13**, yani
     ~240 px²; 48×48 standardının (2304 px²) **onda biri**.
     - **Şikayet yeni değildi:** 12 Ağustos 2026'da kullanıcı *"en az 4-5
       kere dokunmam gerekti, tam basamazsan oyun detayları açılıp
       kapanıyor"* demişti. O günkü düzeltme hedefi BÜYÜTMEDİ, yalnızca
       hamle ikonunu mesaj balonuyla EŞİTLEDİ (121 → 247 px²).
     - **Neden büyütülemiyor (ölçüldü):** satır 14 px, kart 74 px. 44'lük
       bir kutu kartı ~104'e çıkarır, yani listenin tamamı %40 uzardı.
     - **Yani tahta hücresiyle aynı sınıf.** Artık üç alet var ve seçim
       hedefin büyütülüp büyütülemediğine bağlı: BÜYÜT (✕, joker, raf) ·
       YÖNLENDİR (`draftRescue`, artık oyun kartı ikonları) · ZARARSIZLAŞTIR
       (taslak sürerken anlam penceresinin açılmaması).
     - **Uygulama (`icon_tap_rescue.dart`):** kartın kendi yakalayıcısı zaten
       satırın tamamını kapsıyor ve ıskalama oraya düşüyor. `onTap` →
       `onTapUp`; nokta bir ikonun dikeyde ±14 px genişletilmiş kutusuna
       düşüyorsa o ikonun eylemi çalışıyor, düşmüyorsa davranış **birebir
       eskisi gibi**. Hedef 13 → 41 px, alan ~240 → ~760 px² (3,2 katı),
       **düzen hiç değişmiyor**. Kutuları ölçmek için kalıcı `GlobalKey`'ler
       gerekti; `_entryKeys` ile aynı önbellek deseni (her çizimde yenisini
       üretmek GlobalKey sözleşmesini bozardı).
     - ⚠ **Yalnızca DİKEY, bilinçli:** yatayda ikonlar 18.5–19 px ve
       aralarında 2 px var; yatayda da genişletmek bölgeleri bindirir ve
       "hangisi" sorusunu doğururdu. x aralıkları ayrık kaldığından aday HER
       ZAMAN en fazla bir tanedir — `draftRescue`'daki eşitlik kuralına hiç
       gerek kalmıyor.
     - **`mobile/` DIŞINDA:** web'de mekanizma FARKLI ama sonuç aynı —
       düğmeler zaten `stopPropagation` taşıdığından yönlendirmeye gerek yok,
       `.tap-expand-y` (yalnızca dikey, 41 px = portun payıyla birebir)
       `src/index.css`'e eklenip üç düğmeye uygulandı.
     - **Regresyon + negatif eş:** ikonun 12 px ALTINA dokunmak sohbeti/hamle
       dökümünü açmalı; ikonlardan uzak bir ıskalama kartı ESKİSİ GİBİ
       açmalı (kurtarmanın kartın dokunuşunu yutmadığının kanıtı). Test
       ayrıca kutunun hâlâ küçük olduğunu ölçüyor — büyütülürse sessizce
       anlamsızlaşmasın diye. `onTapUp` geri alınınca iki test de düşüyor.

   - ✅ **Parça 148 — "benzer tüm yerlere uygulandı mı?": tarama + joker
     ızgarası (27 Ağustos 2026, kullanıcı sordu):** Parça 147'nin ✕'leri bir
     kaynak taramasıyla kilitlenmişti ama o tarama yalnızca **ham
     `IconButton`** arıyor — aynı hata sınıfı `IconButton` KULLANMAYAN bir
     yerde de olabilir. `lib/src/ui` altındaki tüm dokunulabilirler,
     çevrelerinde 48'in altında AÇIK bir ölçü olup olmadığına göre tarandı;
     adaylar ekranda tek tek ölçüldü.
     - **Tek gerçek bulgu: joker harf ızgarası — 48 × 44**, üstelik dört
       yanında 6 px ölü boşluk. Buradaki ıskalamanın bedeli farklı ve
       gerçek: **yanlış HARF seçilir** (22 Ağustos'ta bildirilen "A harfi
       C'ye döndü" hatasının aynı sonucu, başka sebeple).
     - **Düzeltme rafla aynı desen ama yalnızca ZAYIF EKSENDE:**
       `mainAxisSpacing: 0` + `mainAxisExtent: 50` + hücrede `bottom: 6` →
       48 × 50, satırlar dikeyde aralıksız, **satır adımı hâlâ 50** (her
       satırdaki taş ızgara içinde tam eski yerinde). Yatay 6 px BİLEREK
       duruyor: genişlik zaten 48 ve boşluğu hücreye almak taşları 1 px
       daraltırdı (6 hücre × 6 ≠ 5 boşluk × 6) — rafta bu telafi mümkündü,
       burada değil.
     - **Yükseklik:** düzenleme dalında SIFIR değişiklik (ızgara +6, üstteki
       boşluk 12 → 6; "GERİ AL" ölçülen rect'iyle birebir aynı). Düzenleme
       olmayan dalda kart 6 px uzuyor, ortalandığı için içerik 3 px yukarı
       kayıyor; ızgaranın içinde hiçbir şey oynamıyor.
     - **`mobile/` DIŞINDA:** `src/components/WildcardModal.tsx` birebir aynı
       sayılarla (`gap-y-0`, hücre `h-[50px] pb-1.5`, `mt-3` → `mt-1.5`;
       tıklama taştan HÜCREYE taşındı), `tests/smoke.spec.ts`,
       `docs/decisions/touch-ux-bugs.md`, `TESTING.md`.
     - **48'in altında BİLEREK kalanlar** gerekçeleriyle tabloya yazıldı
       (`docs/decisions/touch-ux-bugs.md`): friends 44×44 ikonları (dört dal
       da önce onay soruyor), hamle ikonu 44 (Parça 65), sohbet rozeti,
       şifre göster/gizle, paragraf içi link, "← Geri", tahta hücresi.
     - **Negatif eş İKİ platformda da kanıtlandı:** portta hücre 44'e
       döndürülünce test düşüyor (`Actual: <44.0>`), web'de `h-11`/`gap-1.5`
       geri gelince smoke düşüyor (`Received: 44` vs `50`).
     - **Ders:** "hepsine uygulandı mı?" sorusunun cevabı bir liste değil bir
       TARAMA olmalı, ve tarama ŞEKLE göre yapılmalı (kutuya ölçü veren bir
       şey var mı), TÜRE göre değil. 24 Ağustos'ta aynı ders bir kez
       alınmıştı; `IconButton`'ın "güvende" sayılması onun ikinci biçimi.

   - ✅ **Parça 147 — dokunma hedefi İKİNCİ tur: ✕ butonları ve raf taşı
     (27 Ağustos 2026, kullanıcı bildirdi: *"bazı tıklamalar yine biraz
     üstte gibi. Mesela skor kartı x'de dikkatimi çekti. Tüm bu tip
     tıklamaları kontrol etmek lazım"* + *"harfi yakalamak bazen zor
     oluyor hala"*):** "Yine" doğru — 24 Ağustos'un 48 dp turuyla AYNI hata
     sınıfı. Asıl soru o turun bunları neden kaçırdığıydı.
     - **Kaçış yolu taramanın KENDİ kuralıydı:** `tap_target_test.dart`'ın
       kaynak taraması "kutuya ölçü veren" işaretler arasında `IconButton`ı
       da sayıyor, yani `IconButton` gören tarama o dokunulabiliri güvende
       varsayıp geçiyordu. Oysa `visualDensity: compact` kutuyu 48 → **40**,
       üstüne `padding: EdgeInsets.zero` daha da aşağı indiriyor.
       **Ders:** bir taramanın "güvende" listesine bir tür eklerken "bu tür
       gerçekten bir asgari GARANTİ ediyor mu?" diye sor.
     - **Ölçüldü (390×844):** `KDialogCard` ✕ **28×28** (projedeki en küçük
       hedef), `KModal`/`RankInfoModal`/`RewardBanner` ✕ ve `ChatModal`
       dişlisi **40×40**, raf taşı **46.3×46**. Web'de dokuz ✕ de
       `w-7 h-7` = **28×28**.
     - **Çözüm: kutuyu büyüt, dolgusunu AYNI kadar kıs** (hamle rozetindeki
       13 Ağustos takasının aynısı). Portta yeni bir `KIconButton`
       (`tap_target.dart`, 48×48); çağıranlar telafi ediyor — `KModal`
       başlık dolgusu 20/12/16 → 16/8/12, köşe butonlarında `Positioned`
       8 → 4, `KDialogCard`'da 12 → 2. **Ölçüldü: ✕ ikonunun rect'i önce
       ve sonra birebir aynı** (`333.0, 386.5, 351.0, 404.5`).
     - **Raf taşı bir PARİTE EKSİĞİ DEĞİLDİ — web'de de aynıydı.**
       Kullanıcının hatırladığı web düzenlemesi `draftRescue`; o zaten
       PORTTA doğmuştu ve `DRAG_LIFT` ile birlikte iki tarafta da var.
       Gerçek sorun: taşın hedefi tam taş kadardı ve çevresi ölü alandı
       (altta rafın 12 px dolgusu, üstte 7 px kalkma payı, arada 3 px
       boşluk) — parmağın temas merkezi nişan noktasının ALTINDA kaldığından
       ıskalamalar tam o alt banda düşüyordu. Tahta hücresinin aksine burada
       ölü alan DEVREDİLEBİLİR: hedef **46.3×46 → 49.3×65** (alan 2,1×),
       taşın çizildiği yer ve rafın dış kutusu **birebir aynı**, komşu
       hedefler arasındaki 3 px ölü boşluk **sıfır**.
     - **`mobile/` DIŞINDA da dosya değişti** (kök `CLAUDE.md`'nin kuralı):
       `src/index.css` (`.tap-expand` — DOM'da sözde-eleman düzeni hiç
       etkilemediğinden web'de telafi gerekmiyor), dokuz bileşen,
       `src/components/Rack.tsx` (portla birebir aynı sayılar),
       `tests/smoke.spec.ts`, `docs/decisions/touch-ux-bugs.md`.
     - **Regresyon iddiası "büyüdü mü" DEĞİL, "görsel KIPIRDADI mı":** asıl
       risk hedefi büyütürken düzeni sessizce kaydırmak. Testler düzeltmeden
       ÖNCEKİ ölçümleri golden tutuyor. **Negatif eşleri kanıtlandı** —
       dolgu telafisi kaldırılınca ✕ 4 px sola kayıp test düşüyor
       (`Actual: 329.0`), yuva alt dolgusu kaldırılınca taş 12 px aşağı
       inip test düşüyor, web'de hücre yüksekliği geri alınınca smoke
       düşüyor (`Received: 46` vs `65`). Ayrıca yeni bir kaynak taraması:
       **`lib/src/ui` altında ham `IconButton` kalmadı** (tek istisna
       `auth_modal`'ın 38 px'lik alanına gömülü şifre göster/gizle düğmesi,
       gerekçesi testte yazılı).

   - ✅ **Parça 146 — "Ara & Ekle"de kaydırma yutuluyordu: modalın içine
     ikinci bir kaydırılabilir (27 Ağustos 2026, kullanıcı bildirdi:
     *"Arkadaşlar - Ara&Ekle'de scroll down bir yerde takılıyor, sonuna
     kadar gitmiyor"*):** Üye listesi `ConstrainedBox(maxHeight: 320) >
     ListView(shrinkWrap: true)` içindeydi — yani `KModal`'ın gövde
     `SingleChildScrollView`'ının İÇİNE ikinci bir kaydırılabilir. Aynı
     modaldeki öteki iki sekme ("Arkadaşlarım", "İstekler") düz `Column`;
     tutarsızlık yalnızca burada.
     - **ÖLÇÜLDÜ, tahmin edilmedi** (widget testi, 420×560 — klavye
       `autofocus` ile açık olduğundan cihazda kalan yükseklik bu civarda):
       modal gövdesi y **119→518** arasını gösterirken iç liste y
       **326→646**'ya uzanıyordu. Yani alt **128 px** — son ~2,5 satır ve
       "Yükleniyor…" nöbetçisi — ekranın altındaydı. Liste satırının
       üzerinden 60 kez sürüklendikten sonra dış kaydırma offset'i hâlâ
       **0.0**'dı; son üye (46.) y 600–620'de, hiç görünmeden kalıyordu.
     - **Kök sebep bir kural farkı: Flutter iç içe kaydırmayı
       ZİNCİRLEMEZ.** Tarayıcı iç kutu ucuna gelince dıştakine devreder —
       web'in `max-h-[50vh] overflow-y-auto`'su bu yüzden `FriendsModal.tsx`'te
       sorun çıkarmıyor, **web tarafı etkilenmedi ve dokunulmadı**.
       Flutter'da iç `ListView` jesti tümüyle sahiplenir.
     - **Düzeltme iç kaydırılabiliri EKLEMEK değil KALDIRMAK:** liste artık
       düz bir `Column`, modalda tek kaydırılabilir var. Sayfalama
       dinleyicisi listenin denetleyicisinden modalın gövdesine taşındı —
       `KModal`'a isteğe bağlı `bodyController` eklendi (varsayılan `null`,
       öteki ~15 modal etkilenmedi). Dinleyici üç sekmede de ateşlendiğinden
       `_loadMoreAllUsers` iki koruma kazandı (sekme `search` değilse ve
       aramada 2+ karakter varsa sayfa istemez).
     - ⚠ **Kalıcı kural:** `KModal`'ın gövdesi ZATEN kaydırılabilir; içine
       ikinci bir `ListView`/`SingleChildScrollView` koyma. Uzun liste
       gerekiyorsa `Column` + `bodyController`. Sabit bir `maxHeight` bunu
       kurtarmaz, **hatayı görünmez kılar**: 900 px'lik test penceresinde
       gövde taşmadığı için hata HİÇ görünmüyordu — yalnızca klavye açıkken
       çıkıyordu. Yeni testin 560 px'i bu yüzden seçildi.
     - **Regresyon + negatif eş:** `friends_test.dart`'a parmağı gerçek bir
       liste satırında başlatan bir sürükleme testi eklendi; düz `Column`
       eski hâline geri alınınca test DÜŞÜYOR (`Actual: <620.0>` vs beklenen
       `<= 518.0`).
     - **Aynı ekranda İKİNCİ, bağımsız bir hata çıktı (sunucuda):**
       `list_users_for_friend`/`search_users_for_friend` `friend_requests`'e
       karşılıklı `OR` koşuluyla `left join` yaptığından, iki yön de satır
       olarak varsa aynı üye listede İKİ KEZ çıkıyordu — bir gün önceki
       `list_my_online_games`/`list_friends` hatasının (Parça: `live-game.md`,
       migration `20260827121628`) AYNI sınıfı. Canlıda ölçüldü: 47 profilin
       46'sını gören iki üyede join 47 satır dönüyordu.
       `20260827153857_dedupe_friend_candidate_lists` ile `distinct on (p.id)`
       + `order by name, id` eşitlik-bozucusu eklendi; canlıya uygulandı ve
       doğrulandı (47 → 46). Dönüş şekli değişmediğinden **uygulama
       güncellemesi beklemiyor**. Ayrıntı: `docs/decisions/friends.md`.
     - **`mobile/` DIŞINDA da dosya değişti:** `supabase/migrations/`,
       `docs/decisions/friends.md`, `ROADMAP.md` — kök `CLAUDE.md`'nin
       kuralı gereği aynı PR'da.

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
