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
