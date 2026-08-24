# Parça Günlüğü — ARŞİV

> **DONDURULMUŞ — yeni giriş buraya YAZILMAZ.** Bu cilt **Parça 49-109**.
>
> **Hangi cilt?** Parça 1-48 → `parca-log-1-48.md` · Parça 49-109 →
> `parca-log-49-109.md` · Parça 110+ → `parca-log.md` (aktif).
> Kod yorumlarındaki "bkz. mobile/CLAUDE.md, Parça N" atıfları bu üçünden
> birine düşer.
>
> ⚠ **Bir cildi BAŞTAN SONA OKUMA — `grep` ile ara.** Ciltler tam da bu
> yüzden var: tek bir atıf için yüz binlerce bayt okumak bağlamı yakar.

## Web ↔ Uygulama Arasındaki Kabul Edilmiş Farklar

Port sırasında fark edilen, uygulamada ÇÖZÜLMÜŞ ama web'de bilinçli olarak
BIRAKILAN farklar. **Kullanıcı kararı (6 Ağustos 2026): "Web'de şimdiye
kadar bir sorun yaşamadım, o taraf düzgün çalışıyor. Değişiklik yapıp riske
sokmanın anlamı yok — ek bir faydası yoksa o tarafa dokunmayalım."**

Yani bu liste bir "yapılacaklar" listesi DEĞİL, bir karar kaydı: aşağıdaki
maddeler web'de ölçülerek KUSURSUZ çalıştığı doğrulandı, uygulamadaki
farklılık platform kısıtından doğuyor. **Bir sonraki oturum bunları "eksik"
sanıp web'e dokunmasın.** Yalnızca ölçülebilir yeni bir fayda (gerçek bir
kullanıcı şikâyeti, ölçülen bir hata) çıkarsa yeniden değerlendirilir.

- ~~**Raf başlığındaki swap aksiyon metni**~~ → **ARTIK FARK YOK
  (17 Ağustos 2026):** kullanıcı Blok 6 görsel turunda iki ekranı yan yana
  koyup metni web'den de kaldırttı (*"ismin yanında ayrıca mesaj yazmamalı,
  mesaj satırında zaten yazıyor"*) — yani 6 Ağustos'ta port için verilen
  karar on bir gün sonra web'e de uygulandı. `Rack.tsx` artık koşulsuz
  yalnızca adı basıyor. Bilgi kaybı yok, ölçüldü: swap modu adın altın
  rengi (`#D97706`), sağdaki "N seçili" sayacı, mesaj satırındaki talimat
  ve DEĞİŞTİR/VAZGEÇ butonlarıyla belli. Portta bu davranışı koruyan bir
  test zaten var (`game_screen_test.dart` → `findsNothing`).
- **Anlam metnindeki `►`** — uygulama bunu `→` ile değiştiriyor (bkz.
  Parça 9). Web'de aynı karakter duruyor ve DÜZGÜN çiziliyor: tarayıcılar
  karakter bazında sistem yedeğine düşer (Chromium'da ekran görüntüsüyle
  doğrulandı). ÖLÇÜLDÜ: web'in subset woff2'lerinde (225-333 glyph) ne `►`
  ne `→` var — yani web'de ikisi de yedek fonttan basılır, `→`ye geçmek
  tipografik bir kazanç SAĞLAMAZ, yalnızca iki platformun metnini aynı
  yapardı. Flutter'da ise fark gerçek (tam TTF'lerde `→` var, `►` yok).

Eski (silinmiş) başlık: "Web'de Bekleyen Küçük Düzeltmeler" — o hâliyle
liste bir iş kuyruğu gibi okunuyordu; kullanıcı kararıyla anlamı değişti.

- ~~**Raf başlığındaki swap aksiyon metni**~~ → kapandı, yukarıdaki
  (17 Ağustos 2026) nota bkz. — metin web'den de kaldırıldı.
- **Anlam metnindeki `►` (opsiyonel, web BOZUK DEĞİL)** — uygulama bunu
  `→` ile değiştiriyor (bkz. Parça 9). Web'de aynı karakter duruyor ve
  DÜZGÜN çiziliyor: tarayıcılar karakter bazında sistem yedeğine düşer
  (Chromium'da ekran görüntüsüyle doğrulandı). ÖLÇÜLDÜ: web'in subset
  woff2'lerinde (225-333 glyph) ne `►` ne `→` var — yani web'de ikisi de
  yedek fonttan basılır, `→`ye geçmek tipografik bir kazanç SAĞLAMAZ,
  yalnızca iki platformun metnini aynı yapar. Tek satırlık değişiklik
  (`MeaningModal.tsx`), aciliyeti yok.

   - ✅ **Parça 49 — geri bildirim kuyruğunun flush'ı YALNIZCA uygulama
     açılışında koşuyordu; "Setup'a her geliş" notu yanlıştı (10 Ağustos
     2026, `setup_screen.dart`):** TESTING.md 9.5 (offline kuyruk) cihazda
     GEÇTİ — ama testten önce verdiğim tahmin ("Setup'a dönüş yetmeyecek")
     kodun gerçeğiyle uyuşuyordu, o yüzden geçişin sebebi kontrol edildi.
     - **Bayat varsayım:** `flushPending()` yalnızca `initState`'te
       çağrılıyordu ve yanındaki yorum bunu "mobil karşılığı Setup'a her
       geliş" diye anlatıyordu. Doğru DEĞİL: `SetupScreen`
       `MaterialApp.home`, oyunlar `Navigator.push` ile açılıyor, yani ekran
       hiç unmount OLMUYOR — `initState` uygulama başına BİR KEZ koşuyor.
       Yani Setup'ta otururken ağ dönerse kuyruk, uygulama yeniden
       başlatılana kadar bekliyordu.
     - **Cihaz testinin geçmesi bu boşluğu çürütmez:** web derlemesinde
       Safari sekmeyi (özellikle uçak modundan sonra) yeniden yükleyebiliyor
       ve her yeniden yükleme TAZE bir `initState` demek — bölüm 8'de aynı
       davranış zaten gözlenmişti. Native'de böyle bir yeniden yükleme yok.
       **Ders: "test geçti" ile "kod doğru" farklı şeyler; testin hangi
       MEKANİZMAYLA geçtiği doğrulanmadan bir gap kapanmış sayılmaz.**
     - **Düzeltme, Parça 44'ün simetriği:** `didChangeAppLifecycleState`'in
       `resumed` dalı artık `_scheduleCloudSync()`in yanında
       `feedback?.flushPending()` de çağırıyor. Debounce YOK ve gerekmiyor —
       kuyruk boşken `flushPending` ağa hiç dokunmadan erken dönüyor
       (`readAll` boşsa 0), yani her öne dönüşte çağırmak bedelsiz.
       Yanıltıcı `initState` yorumu da düzeltildi.
     - **Test — negatif eş doğrulamasıyla:** `setup_cloud_test.dart`'a yeni
       bir test; gerçek `FeedbackRepo` sqflite'a bağlı olduğundan (ve onun
       gerçek I/O'su testWidgets'ın sahte zaman bölgesinde çözülmediğinden —
       Parça 6 dersi) `flushPending`i override eden bir `SpyFeedbackRepo`
       kullanılıyor: ölçülen şey deponun kendisi değil KABLO. Mount'ta 1,
       paused→resumed sonrası 2 çağrı. `setup_screen.dart` `git stash` ile
       geri alınınca test GERÇEKTEN `+0 -1` ile düştü, geri konunca yeşile
       döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 301/301
       yeşil** (300'den +1). `kelimeki_core`'a hiç dokunulmadı.
     - **Kalan sınır (Parça 44'ün aynısı):** uygulama ÖNDEYKEN ağ geri
       gelirse (öne dönüş olayı hiç oluşmadan) kuyruk yine bekler — web'in
       `online` olayının tam karşılığı Flutter'da paketsiz yok. Veri kaybı
       riski yok (kuyruk kalıcı, 7 gün TTL), yalnızca gecikme.

   - ✅ **Parça 50 — "Kalan Taşlar" ham `Dialog`taydı (Parça 26/47'nin ÜÇÜNCÜ
     örneği) + oyun sonu butonu web'de büyürken portta küçük kalıyordu
     (10 Ağustos 2026, `remaining_tiles_modal.dart`, `game_screen.dart`,
     `online_game_screen.dart`):** Kullanıcı bölüm 10'a başlamadan iki
     bulgu bildirdi; ikisi de web kaynağı okunarak teşhis edildi.
     - **(a) Torba dökümü iPad'de devasa açılıyordu.** Web
       `RemainingTilesModal.tsx` paylaşılan `Modal`'ı (360px kart)
       kullanıyor ve hücreleri `h-12` ile **sabit 48px** yüksekliğe
       bağlıyor. Port kendi `Dialog`'unu kuruyor (üst sınır YOK — geniş
       ekranda kart yayılıyor) ve `childAspectRatio: 1.05` ile KARE hücre
       üretiyordu, yani kart genişledikçe taşlar da büyüyordu.
       **`KModal` + `GridView.builder(mainAxisExtent: 48)`'e taşındı** —
       Parça 47'de joker seçicide öğrenilen aynı iki ders (`GridView.count`
       sabit yükseklik veremiyor; ham `Dialog` üst sınır taşımıyor).
       Yan kazanç, yine Parça 47'deki gibi: başlık artık `KModal`
       üzerinden `trUpper`dan geçiyor ("KALAN TAŞLAR") — web'in
       `uppercase` CSS'iyle hizalandı, port düz "Kalan Taşlar" yazıyordu.
     - **ÜÇÜNCÜ kez aynı sınıf:** GameOver (Parça 26), joker seçici (47),
       şimdi bu. `modal_shell.dart`'ın kendi başlığındaki "diğer ikisi de
       buna taşındı" notu bu parçaya kadar GERÇEK DEĞİLDİ. **Yeni bir
       modal eklerken ilk soru "web hangi bileşeni kullanıyor?" olmalı;
       ham `Dialog` kurmak neredeyse her zaman bir sapma.**
     - **(b) Oyun sonu butonu.** Web'de raf satırındaki buton oyun bitince
       "Yeni Oyun Aç"a dönüşüyor ve `text-[15px]` + `px-5` ile OYNA'dan
       (`text-[12px]`) belirgin BÜYÜK oluyor; raf `flex-1 min-w-0`
       olduğundan daralıyor — kullanıcının tarif ettiği "1-2 taş kalınca
       buton büyüyor, Yeni Oyun Aç dikkat çekiyor" etkisi bu. Port
       etiketi `'YENİ\nOYUN'` diye ELLE iki satıra bölüp 13px'te
       bırakmıştı, yani buton hiç büyümüyordu. Tek satır + 15px yapıldı;
       OYNA da 13→12px'e (web değeri) çekildi. Canlı ekranın karşılığı
       (`'CANLI\nLİSTESİ'`, 12px, `horizontal: 16`) aynı şekilde tek satır
       15px + 20 padding oldu — iki ekran "bilinçli kod tekrarı" çifti
       olduğundan AYNI PR'da (bkz. "Etki Analizi").
     - **Rafın daralması ek bir iş gerektirmedi:** portun rafı zaten
       `Expanded` ve taşları `Expanded` (web'in `repeat(N, 1fr)`
       karşılığı), yani buton büyüyünce taşlar web'deki gibi kendiliğinden
       inceliyor.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** (1) GENİŞ bir
       yüzeyde (1200×900 — hatanın gerçekten göründüğü iPad koşulu) kartın
       360px `ConstrainedBox`'ı ve hücre yüksekliğinin tam 48 olduğu;
       (2) OYNA'nın 12, oyun bitince "YENİ OYUN AÇ"ın 15 punto olduğu.
       İki lib dosyası AYRI AYRI `git stash`lenip her iki test de GERÇEKTEN
       `+0 -1` ile düştü, geri konunca yeşile döndü. Mevcut TORBA testi de
       yeni büyük harfli başlığa güncellendi.
     - **Test tuzağı (yeni):** 1200×900'de dikey içerik viewport'u aştığından
       "TORBA" düğmesi ekran dışında kalıyor ve `tap` sessizce ıskalıyordu —
       modal hiç açılmadan test "0 widget" diye düşüyor, sebep yanıltıcı
       görünüyor. `tester.ensureVisible` şart; ayrıca modalın gerçekten
       açıldığını doğrulayan bir ara `expect` eklendi ki bir daha aynı hata
       yanlış yeri işaret etmesin.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 303/303
       yeşil** (301'den +2). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor —
       `mobile/TESTING.md` bölüm 1'e iki yeni madde eklendi.

   - ✅ **Parça 51 — GİZLİLİK: bitmiş Canlı oyunun sohbet arşivi GİRİŞLİ
     HERKESE açıktı (10 Ağustos 2026, `game_chat_archive_participants_only`
     migration'ı + web `api.ts`/`GameChatHistoryModal.tsx`/`PrivacyModal.tsx`
     + mobil `games_api.dart`/`game_chat_history_modal.dart`):** Kullanıcı
     sordu: "k-lig'den kişiye tıklayıp skor kartına, oradan tüm oyunlarına
     erişiliyor — sohbet geçmişleri de ulaşılabilir oluyor, değil mi?"
     Haklıydı.
     - **Önce ÖLÇÜLDÜ, tahmin edilmedi:** `games`in tek SELECT politikası
       `games_select_authenticated` = `auth.uid() IS NOT NULL` — satır
       sahipliğine hiç bakmıyor. Canlıda gerçek bir oyunla, o oyuna hiç
       katılmamış bir hesabın kimliğiyle (`set local role authenticated` +
       `request.jwt.claims`) sorgulandı: **5 mesajın tamamı gönderen
       adlarıyla geldi.**
     - **Arayüzde ikon gizlemek çözüm DEĞİL:** `anon` anahtarı JS paketinde
       herkese açık, yani hesabı olan herkes doğrudan `select=messages`
       çekebilirdi. Düzeltmenin veritabanında olması şarttı.
     - **Postgres tuzağı (bu iş sırasında öğrenildi):** tablo düzeyinde
       SELECT verilmişken `revoke select (messages)` ETKİSİZ. Tablo yetkisi
       kaldırılıp kalan 21 kolon tek tek verilmek zorunda — **`games`e yeni
       bir kolon eklenirse bu listeye de eklenmeli**, yoksa istemci onu hiç
       okuyamaz (sessiz bir "kolon yok" hatası olarak görünür).
     - **Yeni `game_chat_archive(p_game_id)` RPC'si** (security definer):
       `is_online_game_participant` ya da `is_admin()` ise
       `{allowed:true, messages:[…]}`, değilse `{allowed:false,
       messages:[]}`. Var olmayan oyunda da yetkisizle AYNI cevap (varlık
       sızdırmamak için). Yerel/YZ oyunlarda (`online_game_id is null`)
       sohbet kavramı yok, `allowed:true` + boş dönüyor.
     - **`allowed` içerikten AYRI taşınıyor** — "hiç mesaj yok" ile "görme
       yetkin yok" iki farklı durum; yetkisiz kullanıcı artık boş bir
       arşiv değil **"Yazışmaları görmeye yetkiniz yok."** görüyor
       (kullanıcı isteği). Ağ/parse hatasında `allowed:true` dönülüyor —
       geçici bir hata yüzünden kullanıcıya yanlışlıkla "yetkin yok"
       dememek için.
     - **`message_count` de AYNI GÜN kapatıldı (ikinci yarı,
       `chat_count_participants_only` migration'ı):** İlk sürümde sayaç
       bilerek okunabilir bırakılmıştı ("rozet fazladan istek atmadan
       çizilsin; sızan bilgi yalnızca N, içerik değil"). Kullanıcı bunu
       yeniden değerlendirip *"sadece yetkisi olanlara gözüksün"* dedi —
       haklı: "X ile Y şu oyunda N kez mesajlaştı" da bir üstveri ve rozet
       zaten AÇILAMAYAN bir kontroldü (dokununca "yetkiniz yok").
       - **Maliyet sıfıra yakın, çünkü liste zaten sayfa başına TEK toplu
         RPC çağırıyor:** `game_like_stats(p_game_ids)`. Sayaç oraya
         eklendi — EK BİR GİDİŞ-DÖNÜŞ YOK. Kolon grant listesinden düştü
         (21 → 20), `fetchMyGames`/`GamesRepo.history` artık sayacı
         satırdan DEĞİL bu RPC'den okuyor.
       - **Fonksiyon SECURITY DEFINER olmak ZORUNDA kaldı:** kolon istemci
         rollerinden kalkınca INVOKER bir fonksiyon onu okuyamaz. Definer'da
         RLS bypass edildiğinden misafirin (uid null) hiçbir satır alamaması
         davranışı `auth.uid() is not null` ile ELLE korundu. Sayaç
         `is_admin() OR is_online_game_participant(...)` değilse 0; yerel
         oyunlarda (`online_game_id is null`) zaten 0.
       - **`list_liked_games` dönüşünden `message_count` çıkarıldı** —
         sayaç iki sekmede de tek kaynaktan geliyor.
       - **Ad BİLEREK değişmedi:** `game_like_stats` artık kartın tüm
         rozetlerini besliyor, adı dar kalıyor; ama canlıdaki web bu adı
         çağırıyor — yeniden adlandırmak deploy'a kadar beğenileri de
         kırardı. Yeni kolon eklemek eski istemciyi etkilemiyor (fazladan
         alanı yok sayıyor).
       - **Test:** yetkisiz oyunun kartında rozetin HİÇ çizilmediğini,
         yetkilide sayının göründüğünü doğrulayan ikinci bir test;
         `FakeGamesGateway.likeStats` artık `unauthorizedChats` kapısını da
         taklit ediyor (sahte uç gerçek ucun HER kararını taklit etmeli —
         Parça 46'nın dersi). Kapı sahteden kaldırılınca test GERÇEKTEN
         düştü, geri konunca yeşile döndü.
     - **Etki taraması yapıldı, kırılan yok:** iki istemcide de `games`
       üzerinde hiç `select('*')` yok (hepsi açık kolon listesi); `games`i
       okuyan 13 fonksiyonun hiçbiri `messages` döndürmüyor; SECURITY
       INVOKER olan üçü (`list_liked_games`, `game_like_stats`,
       `toggle_game_like`) gövdelerinde bu kolona hiç dokunmuyor. Canlıda
       doğrulandı: liste sorgusu, `board_snapshot`, `message_count` ve
       `list_liked_games` düzeltmeden sonra da çalışıyor; katılımcı RPC ile
       5 mesajı görüyor, katılımcı olmayan hem doğrudan okumada
       `insufficient_privilege` alıyor hem RPC'den `allowed:false`.
     - **Doküman senkronu (kuralın gereği):** kök `CLAUDE.md`'nin Faz 1
       sohbet bölümündeki *"bu yeni alan aynı görünürlük seviyesinde
       kalıyor, yeni bir gizlilik sorunu yaratmıyor"* cümlesi YANLIŞTI —
       düzeltildi ve dersi yazıldı. `PrivacyModal`'ın "tüm kayıtlı
       kullanıcılara açık" ifadesi de artık gerçeğe uymuyordu; "yalnızca o
       oyunun katılımcılarına ve yönetici ekibine açıktır" olarak
       değiştirildi, "Son güncelleme" 10 Ağustos 2026'ya çekildi.
     - **Test — negatif eş doğrulamasıyla:** `game_likes_test.dart`'a
       yetkisiz durumun mesajı GÖSTERMEDİĞİNİ ve "yetkiniz yok" metnini
       gösterdiğini doğrulayan yeni bir test; `FakeGamesGateway`'e gerçek
       uçtaki katılımcı kapısının karşılığı olan `unauthorizedChats`
       eklendi. `_allowed = res.allowed` satırı `true`ya sabitlenince test
       GERÇEKTEN düştü, geri konunca yeşile döndü.
     - Doğrulama: web `npm run lint` + `npm run build` temiz; mobil
       `flutter analyze` temiz, **tam takım 305/305 yeşil** (303'ten +2 —
       biri içerik kapısı, biri rozet kapısı).
     - **CANLIDA, İKİ YÖNLÜ doğrulandı (10 Ağustos 2026 akşamı, gerçek
       hesapla):** yetkisiz kullanıcı başkasının oyununda rozeti HİÇ
       görmüyor, kendi katıldığı oyunda rozet görünüp sohbet açılıyor.
       İkinci yön şart: "yabancıda ikon yok" tek başına, rozet HERKES için
       bozulsaydı da doğru çıkardı — iki durum dışarıdan aynı görünür.
       (Kök CLAUDE.md'nin "aradığın davranışın YOKLUĞUNDA da geçen bir
       kontrol bir şey kanıtlamaz" dersinin canlı örneği.) Ayrıca
       production bundle'ı (`index-6EThUgtN.js`) doğrudan indirilip
       `game_chat_archive`/`game_like_stats`/"Yazışmaları görmeye yetkiniz
       yok." dizelerinin ve liste sorgusundan `message_count`'un
       ÇIKARILDIĞININ orada olduğu teyit edildi.
     - **Ders: "bu satır zaten herkese açık, o hâlde yeni kolon da sorun
       değil" akıl yürütmesi KOLON bazında yeniden sorulmalı** — aynı
       satırda kamuya açık (skor, tahta) ve mahrem (yazışma) veri bir arada
       olabilir.

   - ✅ **Parça 52 — arkadaşlık satırlarında metin butonları ikonlara indi
     (11 Ağustos 2026, `friends_modal.dart`, `player_score_card_modal.dart`
     + web `RelationIcons.tsx`/`FriendsModal.tsx`/`PlayerScoreCard.tsx`):**
     Kullanıcı isteği — "Ara & Ekle ve Arkadaşlar sekmesinde yazı yerine
     ikonlar; ekle/çıkar butonları kalkacak". Parça 42'de (dün) yalnızca
     `PlayerScoreCard`'ın simgesi iki platformda aynı vektöre çekilmişti; bu
     onun listelere yayılmış hâli.
     - **Kural — ikon, DOKUNUŞUN NE YAPACAĞINI söyler, ilişkinin adını
       değil.** Bu yüzden "arkadaşsınız" durumu yeşil `check_circle` DEĞİL
       kırmızı `person_remove`: dokunulunca yapılan şey çıkarmak. Yeşil onay
       durumu anlatıyordu, eylemi değil — Parça 42'de "keşfedilebilirlik
       zayıf" diye not düşülen zaaf tam buydu ve kullanıcının "adam-" fikri
       onu kapattı. `check_circle` artık HİÇBİR yerde kullanılmıyor.
     - **Dört durum, dört glyph** (iki platformda aynı): `person_add_alt_1`
       (mavi, ekle) · `hourglass_top` (gri, istek gönderildi → iptal) ·
       `how_to_reg` (mavi, gelen isteği kabul) · `person_remove` (kırmızı,
       çıkar). "İstekler" sekmesindeki Kabul Et/Reddet butonlarına
       DOKUNULMADI — orası bir durum değil iki ayrı karar.
     - **Kum saatini kullanıcı seçti** (saat/kum saati/üç nokta üçlüsü
       gerçek fontla çizilip gösterildi). Karar öncesi ölçüm: `flutter build`
       gerekmeden, glyph'ler fonttan çıkarılıp bir HTML mock'una konup
       Chromium'da render edildi — tasarım tercihi tarif edilerek değil
       GÖRÜLEREK verildi.
     - **Bulunan tuzak — codepoint'i hafızadan yazma:** ilk denemede
       `schedule`/`person_remove` vb. kodlarını hafızadan yazdım ve tamamen
       başka glyph'ler çıktı (saat yerine hamburger çizgi, person_remove
       yerine `<>`). `cmap`'te "o kodda bir glyph VAR" demek aradığın ikon
       olduğu anlamına GELMİYOR. Tek doğru kaynak Flutter'ın kendi
       `packages/flutter/lib/src/material/icons.dart`'ı; ayrıca font olarak
       `bin/cache/artifacts/material_fonts/` kopyası kullanılmalı (devtools
       altındaki ayrı bir sürüm). Hata yalnızca ÖNİZLEMEYİ render ettiğim
       için yakalandı — kod yazılsaydı sessizce yanlış ikon girecekti.
     - **Web'de path'ler tek dosyada:** `src/components/RelationIcons.tsx`
       (4 ikon). `PlayerScoreCard`'ın inline `PersonAddIcon`/`CheckCircleIcon`
       tanımları oraya taşındı — `FriendsModal` da aynı path'i kullandığından
       ikinci kopya açılmadı. Flutter tarafı fontu gömülü taşıdığından
       `Icons.*` doğrudan; yani iki platform BENZER değil AYNI vektör.
     - **44px dokunma hedefi + erişilebilirlik:** ikon 20px, etrafındaki
       görünmez alan 44px (iOS asgarisi; metin butonu bunu doğal olarak
       sağlıyordu). Metin kalktığı için `aria-label`/`Semantics.label` artık
       ekran okuyucunun TEK bilgi kaynağı — boş bırakılamaz.
     - **Yeni yol: "Ara & Ekle"den çıkarma.** `accepted` satırı eskiden
       tıklanamaz bir "Arkadaşsınız" metniydi; ikona dönünce çıkarma oradan
       da mümkün oldu (`_confirmThenRemoveCandidate` / web'de aynı onay
       state'i yapısal tiple paylaşıldı — ikinci bir diyalog açılmadı) ve
       sonrasında `patchRelation` ile ikon anında `person_add`'e dönüyor.
     - **Test — negatif eş doğrulamasıyla:** `friends_test.dart`'ın üç
       assertion'ı yeni ikonlara çevrildi (onay diyaloğundaki "ÇIKAR"
       METNİ kaldı — yalnızca satır ikonlaştı). İki lib dosyası `git stash`
       ile geri alınınca 3 test GERÇEKTEN düştü, geri konunca 15/15.
     - Doğrulama: `flutter analyze` temiz, **tam takım 305/305**; web
       `npm run lint` + `npm run build` temiz. Gerçek widget görüntüsü
       `build/screenshots/friends_modal.png`'de (kırmızı adam- ikonları).
     - **Doğrulama sınırı:** cihazda görsel/dokunma teyidi kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 10 buna göre güncellendi.
     - **AYNI GÜN, kullanıcının üç düzeltmesi (ikisi yukarıdaki kararları
       kısmen geri alıyor — kayda geçsin):**
       1. **"Ara & Ekle" artık arkadaşları HİÇ göstermiyor** — "onlar
          Arkadaşlarım altında var". Yani yukarıda "yan fayda" diye
          yazdığım *"Ara & Ekle'den çıkarma yolu açıldı"* pratikte ortadan
          kalktı; `accepted` dalı savunma amaçlı duruyor ama ulaşılamaz.
          **Eleme fetch'te DEĞİL render'da:** `_allUsers.length` sayfalama
          offset'i olduğundan diziden atmak sayfaları kaydırıp üye
          atlatırdı. İkinci incelik, Parça 31'in tekrarı: eleme sonrası
          liste kaydırılamayacak kadar kısa kalırsa `ScrollController`
          dinleyicisi HİÇ ateşlenmez ve sonraki sayfa gelmez —
          `_autoLoadIfNotScrollable` (post-frame `maxScrollExtent<=0`
          kontrolü) bunu kapatıyor, testi de var.
       2. **`PlayerScoreCard`'da arkadaş durumu yeşil `how_to_reg`** —
          kırmızı `person_remove` "ismin yanında iyi durmuyor". Bu, bu
          parçanın kendi kuralına ("ikon eylemi söyler") bilinçli bir
          istisna: listede ikon bir AKSİYON sütununda, kartta ismin
          yanında durup durum rozeti gibi okunuyor; dokunuş yine çıkarma
          onayını açtığından kural onay diyaloğuyla korunuyor. **Aynı
          glyph artık iki şey anlatıyor** (listede mavi = "gelen isteği
          kabul et", kartta yeşil = "arkadaşsınız") — renk ayrımı bu
          yüzden zorunlu, ikisini aynı renge çekme.
       3. **Denetim: "bütün ikon dokunuşları onay soruyor mu?"** — HAYIR
          soruyordu. `FriendsModal`'da "ekle" ve "kabul et" ANINDA iş
          yapıyordu; `PlayerScoreCard` ise dört dalın hepsinde onay
          soruyordu. Asimetri `_confirmThenAdd` ile kapatıldı (metin
          ilişkiden türetiliyor) + sonrasında sonuç mesajı. Denetim
          sırasında ikinci bir sapma da bulundu: skor kartının
          `pendingIncoming`/`null` onay metinleri web'in
          `friendDialogCopy`sinden sessizce ayrışmıştı ("İsteği Kabul
          Et"/"Gönder") — web'e hizalandı, artık uygulama içinde de tek
          dil. **Bilinçli kapsam dışı:** "İstekler" sekmesindeki metin
          butonlu "Kabul Et" (orası etiketli iki ayrı karar, kazara
          dokunma riski ikon kadar yüksek değil; "Reddet"in onayı zaten
          var).
       - Doğrulama: `flutter analyze` temiz, **tam takım 307/307** (+2
         yeni test: kabul de onaydan geçiyor + satır listeden düşüyor;
         bir sayfanın tamamı arkadaş çıkınca sonraki sayfa yine geliyor).
         Negatif eş: iki lib dosyası `git stash`lenince 4 test GERÇEKTEN
         düştü, geri konunca yeşile döndü. Web yarısı ayrı PR (#232).

   - ✅ **Parça 53 — kişiye dokunmak skor kartını açıyor: yalnızca
     "Arkadaşlarım"da vardı, üç listeye birden yayıldı (11 Ağustos 2026,
     `friends_modal.dart` + web `FriendsModal.tsx`):** Kullanıcı bildirdi —
     *"Arkadaşlarımda kişilere tıklayınca skor kartına gidiyorum ama Ara &
     Ekle'de bu yok. Bence orada da olmalı."*
     - **Web kaynağı önce okundu (kuralın ilk adımı) ve kullanıcıyı
       doğruladı:** `FriendsModal.tsx`'te yalnızca "Arkadaşlarım" satırı
       `setSelectedFriend(friendToPlayerSummary(f))` ile tıklanabilir;
       "İstekler" ve `renderFriendRow` (Ara & Ekle'nin hem arama hem "Tüm
       Üyeler" listesini besleyen ortak satırı) düz `<Avatar>`+`<span>`
       çiziyordu. Yani bu bir port sapması DEĞİL, iki platformda da olan
       bir eksikti — düzeltme İKİ tarafa birden yazıldı.
     - **"İstekler" de dahil edildi (kullanıcı yalnızca Ara & Ekle'yi
       söylemişti):** kapsamı KENDİ genişletmek de daraltmak kadar riskli
       (bkz. Parça 36'nın dersi), bu yüzden gerekçe açıkça yazılıyor ve
       kullanıcıya bildirildi: bir arkadaşlık isteğini yanıtlamadan önce
       gönderenin kartına bakmak, üç listenin İÇİNDE bu davranışın en
       faydalı olduğu yer. İstenmezse tek satırlık geri alma.
     - **Ortak `_personButton(id, name, avatarUrl)` (web'de aynı işi yapan
       `personButton`)** — üç liste de bunu kullanıyor; "Arkadaşlarım"ın
       kendi satır-içi kopyası silindi, ikinci bir tıklama yolu açılmadı.
       Web'de `friendToPlayerSummary(f: FriendRow)` yerini genel bir
       `toPlayerSummary(id, name, avatarUrl)`e bıraktı — üç listenin veri
       tipi farklı (`FriendRow` / `IncomingRequest` / `FriendSearchResult`),
       ortak olan yalnızca bu üç alan.
     - **Kart kapanınca ilişki TAZELENİYOR** (`closeSelectedFriend`):
       `PlayerScoreCard`'ın kendi arkadaşlık simgesinden ekleme/çıkarma
       yapılabildiğinden, kapanışta `fetchFriendRelation` +
       `patchRelation` ile satırın ikonu güncelleniyor, ayrıca iki liste
       yeniden çekiliyor. Bu olmadan kartta "çıkar"a basıp kapatan
       kullanıcı, satırda hâlâ eski ikonu görürdü — Parça 52'nin
       "aksiyondan sonra ikon anında değişmeli" davranışının kardeşi.
     - **Dokunma alanı ile aksiyon ikonu AYRIŞIK:** kişi butonu
       `Expanded`/`flex-1` ile satırın metin+avatar kısmını kaplıyor,
       ikon kendi 44px hedefinde kalıyor — yani "karta git" ile "ekle/
       çıkar" birbirini yutmuyor (Parça 52'nin 44px kuralı korunuyor).
     - **Test — negatif eş doğrulamasıyla:** `friends_test.dart`'a üç
       listede de dokunuşun `PlayerScoreCardModal`'ı açtığını doğrulayan
       yeni bir test; `pumpModal`'ın `withStats` bayrağı bunun için var
       (kart `StatsRepo` olmadan hiç açılmaz). `friends_modal.dart`
       `git stash` ile geri alınınca test GERÇEKTEN düştü (`Expected:
       exactly one matching candidate / Actual: Found 0 widgets with type
       "PlayerScoreCardModal"`), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       308/308 yeşil** (307'den +1). Web `npm run lint` + `npm run build`
       temiz. `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda dokunma teyidi kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 10'a madde eklendi.

   - ✅ **Parça 54 — renk denetimi: "iki ayrı yeşil" bir yeşil sorunu
     DEĞİLDİ, palet sürüklenmesiydi; `ui/tokens.dart` ile yapısal olarak
     kapatıldı (11 Ağustos 2026, 30 dosya + yeni `test/color_tokens_test.dart`):**
     Parça 42'nin açık bıraktığı iş ("11 `_green` kullanım yeri site site
     denetlenmedi") kullanıcı isteğiyle koşuldu. Denetim, aranan hatanın
     çok ötesini buldu.
     - **Web'in gerçeği önce sabitlendi (kuralın ilk adımı):**
       `tailwind.config.js`'te `green: #16A34A` / `red: #DC2626` /
       `gold: #B7791F` / `muted: #5A6673`. Bunların DIŞINDA yalnızca İKİ
       sabit-yazılmış renk var ve ikisi de **tek bir dosyada**,
       `Board.tsx`: `#1FA05C`/`#E0483A` (hamle dış hattı + puan rozeti +
       sürükleme hedefi çerçevesi). Üçüncü bir istisna `Rack.tsx`'in swap
       başlığındaki `#D97706`. Hepsi grep'le doğrulandı, hafızadan
       yazılmadı.
     - **Bulgu — sapma yeşille sınırlı DEĞİLDİ:** portun her dosyası kendi
       `const Color _x = ...` kopyasını taşıyordu ve kopyalar ayrışmıştı.
       `_red` **13 dosyada iki değere** bölünmüştü (8 dosya `#E0483A`, 5
       dosya `#DC2626`) — yani aynı hata kırmızıda yeşilden DAHA yaygındı.
       Üstelik `count_badge.dart`'ın satırında `// web bg-red` yorumu VARDI
       ve yine yanlış değeri taşıyordu: yorum niyeti doğru yazıyor, değer
       yanlış. Ek olarak `chat_settings_modal`'ın `_void`'i `#EDF1F7`
       (portun ESKİ sayfa zemini) — web'in `#E8EBEF`'i değil.
     - **İki oyun ekranının mesaj rengi haritası DÖRT dalıyla birden
       yanlıştı:** web `MESSAGE_COLORS` dördü de token
       (`text-red/green/gold/muted`); port `#E0483A`/`#1FA05C`/`#D97706`/
       `#5B6472` kullanıyordu. Sonuncusu hiçbir yerde karşılığı olmayan,
       uydurulmuş bir değerdi; `#D97706` ise `Rack.tsx`'ten yanlış yere
       taşınmıştı (orada doğru, burada değil).
     - **Düzeltme yapısal:** yeni `lib/src/ui/tokens.dart`
       (`kText/kMuted/kAccent/kBorder/kRed/kGreen/kGold/kPanel/kVoid/
       kOrange/kBg`) tailwind paletinin TEK Dart karşılığı; tahtaya özel
       ikili ayrı ve AÇIKÇA token-olmayan adlarla (`kMoveValid`/
       `kMoveInvalid`) duruyor ki bir daha karıştırılmasın. 30 dosyadaki
       yerel kopyalar migrasyonla tokenlara bağlandı. Beyaz (`#FFFFFF`)
       bilinçli olarak KAPSAM DIŞI: `bg` ve `tile-bg` aynı değere sahip,
       bir literalden hangisi olduğu anlaşılamaz.
     - **Regresyon koruması — 3 test, ikisi kaynak tarayıcı:** (1)
       `tokens.dart` gerçekten `tailwind.config.js`'i mi taşıyor (test
       web'in dosyasını OKUYUP karşılaştırıyor — web bir rengi değiştirir
       ve port takip etmezse düşer); (2) `lib/` altında token değerini
       tekrar yazan bir literal kaldı mı (yeni yerel kopyayı yakalar); (3)
       `kMoveValid/kMoveInvalid` yalnızca o üç dosyada mı kullanılıyor.
       **Negatif eş, ikisi de ayrı ayrı:** `kRed` eski yanlış değere
       çekilince test 1 GERÇEKTEN düştü (`"red" web ile ayrışmış`),
       `chat_modal`'a yerel kopya geri konunca test 2 GERÇEKTEN düştü
       (dosya adını ve doğru token'ı işaret ederek).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       311/311 yeşil** (308'den +3). `kelimeki_core`'a hiç dokunulmadı
       (motor renk tutmuyor). Ekran görüntüleri gözle kontrol edildi.
     - **Ders — "denetle" istenen şeyin sınırında durma:** görev "11
       `_green` kullanım yerini kontrol et"ti; aynı taramayı kırmızıya
       uygulamak sıfır ek maliyetti ve iki katı hata çıkardı. Bir hatayı
       ÜRETEN mekanizma (her dosyada yerel palet kopyası) bulunduğunda,
       o mekanizmanın ürettiği DİĞER örnekleri de ara — tek renk düzeltmek
       `isMyTurn ? _green : _red` gibi satırları yarı-doğru bırakırdı.
     - **Denetimde bulunan ama bu parçada bilinçli olarak ERTELENEN iki
       şey** (renk değil, ayrı sınıf): `live_games_tab`'ın durum etiketi
       puntosu ve "Sınır İhlali!" diyaloğunun vurguları — kullanıcı isteğiyle
       AYNI GÜN Parça 55'te kapatıldı, aşağı bkz.

   - ✅ **Parça 55 — Parça 54'ün ertelediği iki madde (11 Ağustos 2026,
     `live_games_tab.dart`, yeni `ui/game/invasion_confirm.dart`):**
     - **(a) Durum etiketi 10px'ti, web'de `text-[11px]`.** Düzeltirken
       KARDEŞİNE de bakıldı ve ikinci bir sapma çıktı: `PendingGameCard`'ın
       kalan-süre etiketi 8px, web'de `text-[9px]`. **İkisi karıştırılmamalı**
       — aktif satırdaki kalan-süre GERÇEKTEN 8px (web'de de öyle), yani
       "hepsini eşitle" yanlış olurdu; üç etiketin üçü de ayrı ayrı web
       kaynağından okundu.
     - **(b) "Sınır İhlali!" onayı düz metindi**, web'de kazanılacak puan
       yeşil + kalın, her bölge sahibine giden pay kırmızı + kalın, sahibin
       adı yalnızca kalın (`<strong>` rengi yok — gövde rengini miras alıyor,
       bu ayrım testte de sabitlendi).
     - **Diyalog PAYLAŞILAN bir dosyaya çıkarıldı** (`showInvasionConfirm`).
       `game_screen` ↔ `online_game_screen` çifti sürükleme/joker/mesaj
       desenini bilinçli olarak ayrı taşıyor, ama bu diyalog o desenlerden
       biri değil: iki ekranda BİREBİR aynı metin + aynı vurgu kuralı, ve
       düz-metin hâli de iki kopya olarak duruyordu. `invasionShare`
       formülünün core'da tek kopya tutulmasıyla aynı gerekçe. Yan fayda:
       tek bir izole test iki ekranı birden kapsıyor.
     - **Test — negatif eş, ikisi için ayrı ayrı:** punto 10'a geri
       çekilince `Expected: <11> Actual: <10.0>` ile, span stilleri
       kaldırılınca ilgili test GERÇEKTEN düştü; ikisi de geri konunca
       yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       312/312 yeşil** (311'den +1; punto kontrolü mevcut teste eklendi,
       ayrı test SAYILMIYOR). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor —
       `mobile/TESTING.md` bölüm 11'e madde eklendi.

   - ✅ **Parça 56 — genel tasarım denetimi: EN BÜYÜK fark gölgelerdi, punto
     değil (11 Ağustos 2026, 8 dosya):** Kullanıcı aynı Setup ekranının app
     ve web ekran görüntüsünü yan yana koyup *"küçük font size, type, kutu
     ölçüleri vb tüm tasarımsal farklılıkları analiz et… her şeyin web ile
     uyumlu olup olmadığını kontrol et"* dedi.
     - **Yöntem — Tailwind sınıfından zihnen türetme YOK (Parça 33 dersi):**
       `npm run build` ile derlenen GERÇEK CSS, Chromium'da (Playwright)
       render edilip `getComputedStyle`/`getBoundingClientRect` ile okundu.
       Bu, ilk hipotezimi bir kez çürüttü: alt sekmelerin `py-2` (8px)
       olduğunu sanıp "port 10 kullanıyor, fark var" diye not almıştım —
       ölçüm web'in `py-2.5` (10px) olduğunu, yani portun DOĞRU olduğunu
       gösterdi. Ölçmeden düzeltseydim çalışan bir değeri bozacaktım.
     - **Asıl bulgu, tek tek farklardan büyük: web'in `shadow-raised`/
       `btn-raised*` gölgeleri kartlarda ve sekmelerde HİÇ port edilmemişti.**
       Port yalnızca BUTONLARA (NeoButton) gölge veriyordu; kart/panel/
       istatistik kutusu/alt sekme düz `BoxDecoration` idi. Kullanıcının
       "app daha düz duruyor" izlenimi tam olarak buydu. **10 site**
       düzeltildi: Canlı oyun kartı, davet kartı, iki alt sekme çubuğu
       (Setup + Canlı), "Son Oynadıklarım" satırı, skor kartı sekmesi +
       istatistik kutusu, oyun geçmişi kartı, Setup oyuncu satırı, Devam
       Eden Oyun satırı.
       - `shadow-raised` ile `btn-raised-neutral` index.css'te BİREBİR AYNI
         iki katman — `kRaisedShadows`; seçili/accent yüzeyler üç katmanlı
         `kRaisedAccentShadows` (ikisi de `neo_box.dart`).
       - `ShapeDecorationWithCssShadows`'a `borderColor`/`borderWidth`
         eklendi. **`padding` override'ı kritik:** `Decoration.padding`
         çocuğu çerçeve kadar içeri iter, yani BoxDecoration'dan geçen bir
         kutunun DIŞ ölçüsü birebir korunuyor — gölge eklerken düzen kaymadı.
     - **Ölçülen ve düzeltilen metrik farkları:**
       | Yer | Web (ölçüldü) | Port (öncesi) |
       |---|---|---|
       | Setup: logo → paragraf | 20px | 16 |
       | Setup: paragraf → link satırı | 16px | 12 |
       | Setup: paragraf satır yüksekliği | 12/16px (`text-xs`) | 1.5 (=18) |
       | Arkadaşlar: sekme puntosu | 11px | 10 |
       | Arkadaşlar: küçük buton dolgusu | 6/12px (`py-1.5 px-3`) | 7/10 |
       | Sohbet balonu satır yüksekliği | 1.375 (`leading-snug`) | 1.35 |
       İlk ikisinin kök sebebi ortak ve öğreticiydi: web'de blok `gap-1`
       taşıyor VE çocuklar `mt-4`/`mt-3` — flexbox'ta **gap ile margin
       TOPLANIR**, port yalnızca margin'i taşımıştı.
     - **Setup'ın en altındaki "Kullanım Koşulları · Gizlilik Politikası"
       satırı porta hiç girmemişti** — modaller vardı ama yalnızca kayıt
       formundan ulaşılabiliyordu. Eklendi (web'le aynı 10px mono/muted).
       Teşhis satırı (`Sürüm … · depo ok`) BİLİNÇLİ olarak duruyor: web'de
       karşılığı yok ama cihaz testinde aktif olarak kullanılıyor (Parça
       45'te tam bu yüzden eklendi), hukuki satırın ALTINA alındı.
     - **Doğrulanan ve DEĞİŞTİRİLMEYENLER** (ölçüldü, zaten doğru): modal
       kabuğu (360px/12px radius/#B8C2D1/başlık 14px-1.5ls/gövde dolguları),
       oyun kartı dolgusu 8/10, skor istatistik kutusu 12/4, k-lig satırı
       6/8, oyun geçmişi filtre sekmesi 11px/6px, sohbet balonu 10/6 + 12px
       radius, Setup bölüm etiketi ve OYUN TİPİ butonu.
     - **Test — negatif eş, iki ayrı kanıt:** Setup geometrisi (20/16px +
       12/16 satır + hukuki satır) ve gölgelerin varlığı ayrı testlerde
       sabitlendi. Eski boşluklar geri konunca `Expected: a numeric value
       within <1.5> of <16> / Actual: <12.0>`, gölgeler geri alınınca
       "oyun kartı/pasif sekme gölgesiz kalmamalı" ile GERÇEKTEN düştüler.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       313/313 yeşil** (312'den +1). İlk koşuda 1 test düştü ama iki temiz
       koşu daha yapıldı ve tekrarlamadı — bu, Parça 13/21'de belgelenen
       sqflite yazma-kilidi timer flake'i, bu parçayla ilgisiz.
       `kelimeki_core`'a hiç dokunulmadı.
     - **Denetimde bulunan ama BU PARÇADA düzeltilmeyen iki şey** (ikisi de
       ayrı bir tur istiyor, aşağıdaki "Sonraya Bırakılan İşler"e eklendi):
       metin girişi dolgusu (port v10, web `py-2`=8) ve `InputDecoration`ın
       8 dosyada kopyalanmış olması — ikincisi Parça 54'teki renk
       sürüklenmesiyle AYNI sınıf bir risk.

   - ✅ **Parça 57 — tahta ile mesaj arasındaki boşluk: Parça 39'da YANLIŞ
     ölçmüşüm (11 Ağustos 2026, `game_screen.dart`, `online_game_screen.dart`):**
     Kullanıcı app ve web'i yan yana koyup *"app'te tahta ile mesaj ve mesaj
     ile harfler arasında web'deki boşluk yok"* dedi.
     - **Kök sebep benim kendi hatam:** Parça 39'da 56px'lik yamayı
       kaldırırken web'in gerçek boşluğunu "mesaj kabının `pt-1`i, yani
       4px" diye yazmıştım — ama `Board.tsx`'in KENDİ dış sarmalayıcısı da
       `px-3 pt-1.5 **pb-3**` taşıyor. Yani web'de tahta kartının altı ile
       mesaj arası 12 + 4 = **16px**; port yalnızca 4px bırakmıştı.
       Chromium'da gerçek DOM'la ölçüldü.
     - **Aynı turda iki sapma daha çıktı:** mesaj ile raf satırı arası
       web'de `gap-1.5` = 6px (port 4), ve mesaj bloğunun yatay dolgusu
       web'de `px-3` = 12 (port 16). Üçü de düzeltildi; buton satırı
       (`12, 6, 12, 12`) zaten doğruydu.
     - **Ders — bir sarmalayıcının boşluğunu ölçerken YALNIZCA o elemanın
       kendi sınıflarına bakma:** komşusunun `pb-*`i de aradaki mesafeye
       giriyor. Parça 39 tam bu yüzden yanlış çıktı ve bir yamayı
       kaldırırken yerine yanlış değeri koydu. Doğru refleks: iki düğümün
       GERÇEK `getBoundingClientRect` farkını ölç (Parça 56'da kullanılan
       yöntem), sınıf okuyarak toplama yapma.
     - **Test — negatif eş:** boşluklar `ValueKey('message-line')` ile
       ölçülüp sabitlendi (16 ± 0.5 ve 6 ± 0.5). Tahtanın alt dolgusu eski
       hâline çevrilince test GERÇEKTEN `Expected: within <0.5> of <16> /
       Actual: <4.0>` ile düştü — 4.0 tam olarak kullanıcının "boşluk yok"
       dediği değer.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       314/314 yeşil** (313'ten +1). İki ekranda da AYNI değişiklik
       (bilinçli kod tekrarı çifti). `kelimeki_core`'a dokunulmadı.

   - ✅ **Parça 58 — sürükleme ortasında rakip oynayınca taş havada asılı
     kalıp EKRAN KİLİTLENİYORDU; web'in `clearStuckDrag` neti porta hiç
     girmemişti (11 Ağustos 2026, `game_screen.dart`,
     `online_game_screen.dart`):** Kullanıcı gerçek bir iki kişilik Canlı
     oyundan sonra bildirdi: *"sürüklerken aynı anda karşı taraf da hamle
     yapınca oldu galiba. Harf takıldı kaldı. Hiçbir şey çalışmaz oldu.
     Kapatıp açınca … herşey normaldi."* Ekran görüntüsünde iz görünüyordu:
     tahtanın üstünde asılı kalmış büyük bir taş ve rafta ondan boşalan yer.
     - **İlk teşhisim YANLIŞTI ve testle çürütüldü.** `_refresh()`in
       `SyncOnlineStateAction`'ı sürükleme state'ine hiç dokunmadığından,
       rakibin hamlesi `placed`i temizleyip kaynak taşın `Listener`'ını
       söküyor → `PointerUpEvent` hiç ulaşmıyor diye düşünmüştüm. Repro
       testi (hem raf hem tahta kaynağı için) yazıldı ve **mevcut kodda
       GEÇTİ**: Flutter olayı pointer-down anında kaydedilen hit-test
       yoluna gönderdiğinden, yaprak `Listener` ağaçtan kalksa bile up
       yerine ulaşıyor. Yani "kaybolan pointer-up" hipotezi ölçülerek
       elendi — kod yazmadan önce.
     - **Sonra web okundu (kuralın ilk adımı) ve gerçek boşluk çıktı:**
       `App.tsx` ve `OnlineGameScreen.tsx`'in İKİSİNDE de adı doğrudan
       `clearStuckDrag` olan bir effect var — `visibilitychange` + `blur`
       dinleyip `dragRef`i ve ghost'u temizliyor. Yani web bu hata sınıfını
       (sürükleme ortasında kaybolan pointer) TANIYOR ve kurtuluş yolu
       sunuyor; port bu neti hiç taşımamış, bu yüzden tek kurtuluş yolu
       uygulamayı kapatıp açmaktı — kullanıcının yaptığı tam buydu.
     - **İki düzeltme, ikisi de testli:**
       1. **Lifecycle neti (web parity, İKİ ekranda birden):**
          `didChangeAppLifecycleState` `resumed` DIŞINDA bir duruma
          geçerken bekleyen sürüklemeyi iptal ediyor. `game_screen.dart`'ta
          `WidgetsBindingObserver` hiç yoktu, eklendi (`initState`'te
          `addObserver`, `dispose`'ta `removeObserver`).
       2. **Sync tur ilerletince sürükleme biter (`online_game_screen.dart`):**
          `_refresh()` dispatch'ten ÖNCE `turnCount`u okuyup ilerlediyse
          `_cancelTileDrag()` çağırıyor. Gerekçe semptom bastırma değil
          tutarlılık: reducer'ın `turnAdvanced` dalı taslak taşları zaten
          rafa geri döndürüyor ve rafı sunucudakiyle değiştiriyor — hayalet
          taş bundan sonra SİLİNMİŞ bir kaynağı gösteriyor.
     - **Neden kilitlenme "hiçbir şey çalışmıyor" gibi hissettiriyor:**
       `_dragRef` asılı kalınca `SingleChildScrollView`
       `NeverScrollableScrollPhysics`te kilitli kalıyor (Parça 15'in
       düzeltmesi) — dikeyde içerik ekranı aştığında OYNA/PAS GEÇ satırına
       kaydırılamıyor, yani butonlara fiziksel olarak ulaşılamıyor.
     - **Test — negatif eş doğrulamasıyla, ÜÇ test:** raf ve tahta kaynağı
       için ayrı ayrı "rakip hamle yaparsa ekran DONMUYOR" (parmak hâlâ
       ekranDAYKEN hayalet taş ve kaydırma kilidi gitmeli) + iki ekranda
       birer "arka plana alınırsa drag İPTAL olur". İki lib dosyası AYRI
       AYRI `git stash`lendi: `game_screen.dart` geri alınınca 1 test
       (`Expected: null / Actual: NeverScrollableScrollPhysics`),
       `online_game_screen.dart` geri alınınca 3 test GERÇEKTEN düştü;
       ikisi de geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       318/318 yeşil** (314'ten +4). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama SINIRI — dürüst kayıt:** cihazdaki ASIL tetikleyici
       (up'ın gerçekten kaybolduğu an) bu ortamda YENİDEN ÜRETİLEMEDİ;
       yukarıdaki iki düzeltme "rakip aynı anda oynadı" senaryosunu
       kapatıyor ve hangi sebeple olursa olsun **kurtuluş yolu açıyor**
       (uygulamayı arka plana alıp geri getirmek yetiyor, kapatıp açmak
       gerekmiyor). Aynı belirti tekrar bildirilirse tetikleyici hâlâ
       aranmalı. `mobile/TESTING.md` bölüm 11'e iki madde eklendi.
     - **Ayrıca araştırıldı, HATA DEĞİL:** kullanıcı oyun bitince OYNA'nın
       yerinde "yeni oyun aç" yerine "canlı izle gibi bir şey" yazdığını ve
       basınca Setup'a döndüğünü bildirdi. Web `OnlineGameScreen.tsx` oyun
       bitince TAM OLARAK bunu yapıyor: `<button onClick={onBack}>Canlı
       Listesi</button>` — port birebir aynı (Parça 50'de puntosu da web'e
       hizalanmıştı). Canlı bir oyun tek başına başlatılamadığından (davet
       + kabul gerekiyor) doğru hedef listenin kendisi; "+ Yeni Canlı Oyun"
       butonu orada. Değiştirmek İKİ platformu birden ilgilendiren bir ürün
       kararı olur, tek taraflı portta yapılmadı. **Kullanıcı aynı gün bu
       kararı verdi ve buton "Tekrar Oyna"ya çevrildi — bkz. Parça 59.**

   - ✅ **Parça 59 — oyun bitince "TEKRAR OYNA": aynı kadroyla yeni bir Canlı
     oyun (11 Ağustos 2026, `online_games_api.dart`, `online_game_screen.dart`
     + web `OnlineGameScreen.tsx`):** Parça 58'de "hata değil, web ile birebir"
     diye kapattığım buton hakkında kullanıcı ürün kararını verdi: *"canlı
     oyunda ideali 'Tekrar Oyna' çıkmalı. Basınca da aynı kişiyle oyun açsın …
     arkadaşıyla oynamışsa, o kişiye oyun daveti göndersin. Emin misin
     olmalı."* İki platforma AYNI GÜN uygulandı (web yarısı ayrı bir `main`
     tabanlı PR).
     - **Tek akış, iki dal değil:** "YZ ile" ve "arkadaşıyla" ayrı kodlar
       değil — biten oyunun KADROSU aynen taşınıyor; insan koltuklarına davet
       gidiyor, YZ koltuğu YZ kalıyor. Canlı'da zaten 2 kişilikte YZ olamıyor,
       4 kişilikte yalnız son koltuk YZ olabiliyor, yani "kadroyu kopyala"
       ikisini de karşılıyor.
     - **`rematchSlots` (saf fonksiyon) sırayı `create_online_game`'in üç
       kısıtından TÜRETİYOR, biten oyundan kopyalamıyor:** (1) ilk koltuk
       ÇAĞIRAN olmak zorunda — biten oyunu ben kurmamış olabilirim (`my_role
       == 'invitee'`), kendimi başa alıyorum; (2) 4 kişilikte YZ yalnız son
       koltukta olabilir — insanları kendi aralarındaki sırayla koruyup
       YZ'leri sona yazmak bunu kendiliğinden sağlıyor; (3) 2 kişilikte YZ
       zaten olamaz. **Kısıtlar RPC kaynağından okundu, hatırlanmadı**
       (`online_games_invites.sql` + `online_game_ai_slot_rule.sql`) — sırayı
       "olduğu gibi gönder" demek, kurucu ben değilsem her seferinde
       `'İlk koltuk oyunu kuran kişi olmalı.'` ile reddedilirdi.
     - **Zenginleştirme alanları RPC'ye gitmiyor:** `list_my_online_games`
       koltuklara `name`/`avatar_url`/`relation`/`invite_status` ekliyor;
       `NewGameSlot` yalnız `type`+`user_id` yazdığından bu alanlar
       `online_games.slots` jsonb'sine sızmıyor.
     - **Sunucu reddi olduğu gibi gösteriliyor:** aradan arkadaşlıktan
       çıkılmışsa RPC `'Yalnızca arkadaşlarını davet edebilirsin.'` fırlatıyor.
       Mesaj `friendErrorText` ile (LiveGameCreateForm'un AYNI RPC için
       kullandığı helper — `_errorText`in ham `toString()` gürültüsü değil)
       gösteriliyor ve hata dalında listeye DÖNÜLMÜYOR. İstemci tarafına
       ikinci bir arkadaşlık kontrolü eklenmedi: tek doğruluk kaynağı RPC.
     - **Metinler mevcut kalıplardan alındı, yenisi icat edilmedi:**
       "Davetiniz gönderilmiştir." + "{isimler} yanıt verince oyun
       başlayacak." + " 4. koltuk Yapay Zeka." — `LiveGameCreateForm`'un
       gönderim ekranıyla birebir. Onay diyaloğunda kabul butonu SOLDA
       (Parça 25 kuralı).
     - **Test — negatif eş doğrulamasıyla, 4 test:** `rematchSlots` için iki
       birim testi (kurucu olmasam da başa geçiyorum; 4 kişilikte YZ sonda
       kalıp insan sırası korunuyor) + iki widget testi (VAZGEÇ hiçbir şey
       göndermiyor → onay → `create` doğru sayı/koltuklarla çağrılıyor →
       "Davetiniz gönderilmiştir." → TAMAM listeye dönüyor; sunucu reddi
       dalında mesaj görünüyor ve ekran ayakta kalıyor). Ekran dosyası
       `git stash`lenince (saf helper yerinde bırakılarak) iki widget testi
       de GERÇEKTEN düştü (`Found 0 widgets with text "TEKRAR OYNA"`), geri
       konunca yeşile döndü.
     - **Sahte uca `createError` eklendi** — genel `failWith`ten ayrı, çünkü
       ekran o sırada yüklü ve öteki uçların çalışmaya devam etmesi gerekiyor
       (Parça 46'nın dersi: sahte uç gerçek ucun HER hata yolunu taklit
       etmeli).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 322/322
       yeşil** (318'den +4). Web `npm run lint` + `npm run build` temiz.
       `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** gerçek `create_online_game` çağrısı (davetin
       karşı hesapta belirmesi, `notify-game-invite` e-postası, artık arkadaş
       olmayan biriyle gelen ret) iki hesapla cihazda doğrulanmalı —
       `mobile/TESTING.md` bölüm 11'e madde eklendi.
     - **Yerel/YZ oyun ekranına DOKUNULMADI:** orada buton hâlâ "YENİ OYUN AÇ"
       ve Setup'a dönüyor — istek açıkça "canlı oyunda" diyordu ve Setup'ta
       zaten tek dokunuşluk bir YZ kurulum formu var. İstenirse ayrı bir
       parça.

   - ✅ **Parça 60 — "TEKRAR OYNA" yerel/YZ ekranına da geldi; sessiz bir
     k-lig kaybı BU ÇALIŞMA SIRASINDA yakalandı (11 Ağustos 2026,
     `game_screen.dart`, `setup_screen.dart` + web `App.tsx`):** Kullanıcı
     Parça 59'dan sonra "yerel/YZ ekranına da uygulasak mı?" diye sordu.
     Kayıt oturumu (`activeSaveIdRef` / `CloudGameSession._saveId`) oyun
     bitince id'yi zaten sıfırlıyor, yani yeni oyun kendiliğinden yeni bir
     satır alıyor — uygulama iki tarafta da temiz oturdu.
     - **Onay Canlı'dakiyle AYNI, gerekçesi FARKLI:** Canlı'da onay dışa
       dönük bir eylemi (davet göndermek) koruyor; yerelde öyle bir sonuç
       yok (oyun anında ve iz bırakmadan terk edilebilir, `turnCount<2`).
       Yine de kondu: AYNI konumdaki buton oyun bitince parmağın altında
       OYNA'dan TEKRAR OYNA'ya dönüşüyor — kazara dokunuş tam da bu yüzden
       olası, ve iki kardeş ekranın aynı davranması bu projede bir kural.
     - **Kadro yeniden hesaplanmıyor:** biten oyunun `players` adları/YZ
       bayrakları Setup'ın `doStart`/`_startNewGame`'inin ürettiğinin
       AYNISI — `StartAction`/`{type:'START'}` doğrudan onlarla çağrılıyor.
     - **BULUNAN GERÇEK HATA — `recorded` bayrağı ekran oturumu başına tek
       seferlikti:** `setup_screen.dart`'ın `_openGame`'i oyun bitince
       `games` satırını yazan dinleyiciyi `var recorded = false` ile
       koruyordu. Bu, ekran YALNIZCA Setup'a dönerek terk edilebildiği
       sürece doğruydu (dönüş closure'ı bitiriyordu). "TEKRAR OYNA" aynı
       ekranda ikinci bir oyun başlatabildiğinden bayrak sıfırlanmazsa o
       oyun HİÇ kaydedilmezdi — ne `games` satırı, ne k-lig puanı, ne oyun
       geçmişi; üstelik SESSİZCE. Dinleyici artık `isGameOver` false'a
       düştüğünde bayrağı sıfırlıyor.
     - **Web'de bu hata YOK ve sebebi öğretici:** oradaki kayıt bir
       `useEffect(..., [state.isGameOver])` — bağımlılık false→true'ya
       yeniden geçtiğinde effect kendiliğinden yeniden çalışıyor. Portun
       elle yazılmış dinleyicisi bu "yeniden tetiklenme"yi taklit etmiyordu.
       **Ders: bir React effect'ini elle bir `addListener`'a çevirirken
       "bağımlılık DEĞİŞTİĞİNDE yeniden çalışır" garantisini de taşı** —
       tek seferlik bir bool o garantiyi sessizce düşürür.
     - **Test — negatif eş doğrulamasıyla, 2 yeni test:** (1)
       `game_screen_test.dart` — oyun bitince buton "TEKRAR OYNA"
       ("YENİ OYUN AÇ" DEĞİL), VAZGEÇ yeni oyun başlatmıyor, onay TAZE bir
       oyun açıyor (turnCount 0, aynı kadro, buton yine OYNA); ekran dosyası
       `git stash`lenince GERÇEKTEN düştü. (2) `setup_cloud_test.dart` —
       aynı ekranda ikinci oyun da kaydediliyor; bayrak sıfırlaması geri
       alınınca GERÇEKTEN `Expected: an object with length of <2>` ile
       düştü. Ayrıca iki MEVCUT test eski etikete bağlıydı, beklentileri
       güncellendi (Parça 50'nin ASIL sözleşmesi — tek satır, 15px — aynen
       korunuyor, yalnızca metin değişti).
     - **Test tuzağı:** GameOver'ı kapatmak Parça 48'den beri "Görüş
       Bildir" formunu açıyor; formu da kapatmazsan modal bariyeri sonraki
       dokunuşları yutuyor ve hata "buton yok" gibi görünüyor.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 324/324
       yeşil** (322'den +2). Web `npm run lint` + `npm run build` temiz.
       `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda teyit kullanıcıdan bekleniyor —
       `mobile/TESTING.md` bölüm 1'e madde eklendi. En kritik maddesi
       "aynı ekranda ART ARDA iki oyun bitir, İKİSİ de Skor Kartı'nda
       görünsün" — yukarıdaki sessiz kaybın gerçek uçla kontrolü.

   - ✅ **Parça 61 — k-lig Ödül & Rütbe Sistemi'nin UI katmanı (12 Ağustos
     2026, 9 yeni dosya [8'i `ui/rank/` + `data/league_rewards_api.dart`] +
     14 değişen; web `leagueRank.ts`/`RankSeal`/`RewardBanner`/
     `RankInfoModal`/`LeagueRewardsHost` + `Modal.headerCenter` portu):**
     Sunucu tarafı (league_rewards tablosu, `games` trigger'ı, view
     kolonları) web PR'ıyla ZATEN canlıda — yani mobilde bitirilen bir oyun
     ödülü bugün de kazanıyordu, yalnızca kullanıcıya gösterecek katman
     yoktu. Bu parça o katmanı ekliyor; SUNUCUYA HİÇ DOKUNULMADI.
     - **Dosya yerleşimi kararları:** (a) rütbe/ödül UI'ı `ui/score/`'a
       serpiştirilmedi, kendi `ui/rank/` klasörüne alındı — banner ve host
       "skor kartı" değil, uygulama seviyesinde bir katman; (b) veri katmanı
       `stats_api.dart`'a EKLENMEDİ, ayrı `data/league_rewards_api.dart`
       oldu: stats_api bilinçli olarak üç SALT OKUNUR view/RPC taşıyor,
       buradaysa bir YAZMA yolu (`mark_league_rewards_seen`) + kendi modeli
       var; proje deseni zaten alan başına bir dosya (chat/friends/feedback).
     - **Host mimarisi — web'in "aynı anda tek host" garantisi Flutter'da
       KENDİLİĞİNDEN GEÇERLİ DEĞİL:** Web'de App.tsx erken return'lerle
       dallandığından üç mount birbirini dışlıyor. Portta `SetupScreen`
       `MaterialApp.home`'dur ve oyun ekranları onun ÜZERİNE push edilir —
       Setup'ın host'u oyun sırasında MOUNT KALIR. Çözüm: host'lar modül
       seviyesinde bir yığına kaydolur, YALNIZCA EN ÜSTTEKİ çalışır (yığın
       Navigator'la aynı sırayı izler; oyun pop edilince Setup'ınki
       kendiliğinden yeniden etkinleşip kontrol koşar). `MaterialApp.builder`
       içinde TEK global host + ayrı bir "suppress sinyali" alternatifi
       değerlendirildi ve elendi: web'in `suppress` prop'unu iki ekrana
       taşımak zaten gerekiyordu, yığın çözümü ise web'in kod şeklini
       (`LeagueRewardsHost(suppress: ...)`) birebir koruyor.
     - **Mount noktaları:** `setup_screen` (suppress YOK — giriş/backfill
       kutlaması burada), `game_screen` ve `online_game_screen`
       (`suppress: !state.isGameOver`). Yerel oyunda ayrıca
       `_recordFinishedGame` kayıt sunucuya düşer düşmez
       `requestLeagueRewardCheck()` çağırıyor (web'in
       `saveGameDurable(...).then(requestLeagueRewardCheck)` deseni);
       Canlı'da buna gerek yok, `suppress`in düşmesi yetiyor. Misafirde
       host tamamen no-op (tek ağ isteği bile atılmıyor, testle sabit).
     - **BULUNAN İKİ GÖRSEL HATA — ikisini de ÖLÇÜM yakaladı, kod okuması
       DEĞİL** (ekran görüntüsü + Chromium'da gerçek fontla karşılaştırma):
       1. **`✓` karakteri Space Mono'da YOK.** Web'de düz bir `✓` basılıyor
          ve tarayıcı sessizce yedek fonta düşüyor (Chromium'da doğrulandı:
          computed font "Space Mono, monospace", glyph monospace
          yedeğinden geliyor). Flutter yedek fonta düşmediğinden TOFU (boş
          kutu) çiziyordu. Rozet artık Material `Icons.check` kullanıyor —
          her platformda ve testlerde garanti. **Ders: web'de çalışan bir
          Unicode glyph portta çalışacak demek DEĞİL; fontun içerdiğini
          varsayma, render edip bak.**
       2. **Material 3'ün varsayılan `letterSpacing: 0.25`'i sessizce
          miras alınıyordu.** "Sıradaki rütbe: Oyuncu · 100 puan" 33
          karakterde tam 8.25px (33×0.25) şişip 230px'lik karta sığmıyor ve
          İKİ SATIRA düşüyordu. Aynı metin Chromium'da gerçek Space Mono ile
          222.16px, tek satır — yani geometri (280 kart / 1px çerçeve / 24px
          dolgu / 11px punto) web ile BİREBİRDİ, fark yalnızca bu tracking'ti.
          `ui/rank/` metinleri artık `letterSpacing: kNoTracking` (0) taşıyor.
          **Bu bulgu bu parçanın DIŞINDA da geçerli olabilir** — portun
          `ThemeData(useMaterial3: true)` kullanan diğer ekranlarında
          `letterSpacing` yazmayan her metin 0.25 miras alıyor; ayrı bir
          denetim işi (aşağıdaki "Sonraya Bırakılan İşler"e eklendi).
     - **`RankSeal` CanvasKit-güvenli:** kesikli iç halka `Path.combine`/
       PathOps ile DEĞİL, tek tek `drawArc`'larla çiziliyor (Parça 18 dersi).
       Ortadaki harf SVG'nin `dominant-baseline: central`ı gibi FONT
       METRİKLERİNE göre (ascent/descent ortası) yerleştiriliyor — `Center`
       satır kutusuna göre hizalayıp glyph'i hafif yukarı kaçırırdı.
       Kompakt kural (`size < 24` → halkasız + harf 19→27) saf fonksiyona
       (`sealIsCompact`/`sealFontSize`) çıkarıldı ki testlenebilsin.
     - **`KModal`'a `headerCenter` yuvası** (web `Modal.headerCenter`) —
       `headerAction`'a DOKUNULMADI (ChatModal'ın dişlisi onu kullanıyor).
       Verilmezse başlık eskisi gibi tüm boşluğu alır (`Expanded`), verilirse
       başlık kendi genişliğinde durur (`Flexible`) ve yuva ortalanır.
     - **`tokens.dart`'a `kTilePts`** (tailwind `tile-pts`, `#8A93A2`) —
       Çaylak kademesinin rengi. `color_tokens_test`in TAİLWİND PARİTE
       testine eklendi, "yerel kopya" taramasına BİLEREK eklenmedi: `lib/`
       altında bu değerde 8 literal var ve hepsi `tile-pts` DEĞİL (beşi form
       placeholder'ı — web oraya hiç renk yazmıyor, tarayıcı varsayılanı).
       Beyazın dışlanmasıyla aynı gerekçe; ayrım gerektiren bu migrasyon
       ayrı bir denetim işi.
     - **`PlayerStats`'a `bonusPoints` + `rankTier`** (yalnızca
       `player_stats_overall`'da dolu). `rankTier`'ı UI OKUMUYOR — rütbe
       güncel puandan türetiliyor ("düşmeli" sürüm); kolon yalnızca "hangi
       eşikler kutlandı" kaydı, web `PlayerStats.rank_tier` ile aynı gerekçe.
     - **`RankProgressBar` PAYLAŞILAN:** web ilerleme çubuğunu iki yerde
       (bilgi popup'ı + düşüş banner'ı) ayrı ayrı yazmış; port
       `showInvasionConfirm` ile aynı gerekçeyle tek dosyaya aldı (aynı
       görsel + aynı rozet kuralı, iki kopya sessizce ayrışır).
     - **Test — 26 yeni test (`test/league_rewards_test.dart`), ikisi
       negatif eşle doğrulandı:** `hasPositive` guard'ı kaldırılınca öncelik
       testi GERÇEKTEN düştü (`Expected: null / Actual: RankDownInfo`);
       rozet `claimed ? kGreen : kMuted` sabitlenince renk testi GERÇEKTEN
       düştü. Kapsam: eşik sınırları/negatif puan/renk tokenları, ödül
       tablosunun SQL ile aynılığı, `rewardAlreadyClaimed` prefix çıkarımı,
       `buildRewardSummary` birleştirme + öncelik + bilinmeyen tür,
       repo/gateway (unseen→markSeen, ağ hatası), host akışı (banner,
       DEVAM=markSeen, suppress, misafir no-op, düşüş çubuğu, puan
       çekilemezse çubuk gizli), bilgi popup'ı rozet kuralı + en üst kademe,
       mühür kompakt eşiği. Ayrıca üç ekran görüntüsü
       (`build/screenshots/reward_banner*.png`, `rank_info_modal.png`) —
       yukarıdaki iki hata tam da bunlara bakarak bulundu.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 350/350
       yeşil** (324'ten +26; ilk tam koşuda `setup_cloud_test`'in "TEKRAR
       OYNA … İKİNCİ oyun" testi bir kez düştü ama tek başına ve ikinci tam
       koşuda geçti — yük altındaki bir zamanlama flake'i, bu parçanın
       eklediği kod o testin insert yolunu geciktirmiyor).
       `kelimeki_core`'a hiç dokunulmadı (motor ödül/rütbe bilmiyor).
     - **Doğrulama sınırı:** gerçek `league_rewards` tablosu/RPC'si ve
       "cihazdan bağımsız bir kez göster" garantisi bu ortamdan
       doğrulanamadı (gerçek oturum + gerçek oyun bitişi gerekiyor) —
       `mobile/TESTING.md` bölüm 13 eklendi (web'in kök `TESTING.md` bölüm
       10'unun mobil eşleniği, artı "web'de görülen kutlama mobilde
       ÇIKMAMALI" çapraz maddesi).
     - **AYNI GÜN, kullanıcının üç görsel düzeltmesi (ekran görüntüsüyle
       geldi — üçü de İKİ platforma birden uygulandı, bkz. kök
       `CLAUDE.md`):**
       1. **Mührün dış kenarı TIRTIKLI** (referans: testere dişli
          sertifika damgası) — 24 diş, uç 21.0 / vadi 18.8 viewBox
          birimi, stroke 2.0. Üç sabit web `RankSeal.tsx` ile ELLE
          senkron: web aynı üçlüyle bir `<polygon>` üretiyor, port
          `Path`. **İlk sürümde kompakt mühür (k-lig satırları, <24px)
          düz çember bırakılmıştı** — gerekçe "18px'te diş derinliği
          <1px'e düşüp alt-piksel gürültüsüne dönüyor" idi; AYNI GÜN
          ölçülüp ÇÜRÜTÜLDÜ, bkz. aşağıdaki 5. madde.
       2. **İlerleme çubuğunun sağ etiketi yalnızca SAYI.** İlk sürüm
          "100 puan" yazıyordu; "puan" kelimesi hemen ÜSTTEKİ "Sıradaki
          rütbe: Oyuncu · 100 puan" satırında zaten geçtiğinden alt alta
          tekrar oluyordu. **Sayının kendisi KALDI** — ilk denemede tüm
          etiketi kaldırıp kullanıcıya düzelttirdim; istek "sonundaki
          puan yazısını kaldır"dı, çubuğun eşiğini gizlemek değil.
       3. **Düşüş banner'ının başlığına ünlem:** "Rütben geriledi!"
       4. **Mühürdeki harf büyüdü — tam boyda 19 → 23.** Sayı ÖLÇÜLEREK
          seçildi: kademe harflerinin (Ç M O U Ş D) `getBBox`'ı gerçek
          Space Mono 700 ile Chromium'da okundu, merkeze en uzak köşe Ç'de
          23'te **15.48**, 24'te **16.20** — iç kesikli halka r=16
          olduğundan 24'te Ç/Ş'nin sedillası halkayı taşıyor (zoom'lu
          render'da da görüldü). **Kompakt 27'DE KALDI:** oradaki sınır
          dış çemberin iç kenarı (20.5 − 2.5/2 = 19.25) ve 27 zaten 18.17
          ile tavana yakın (azami ~28.6) — bir punto artış görünmez, taşma
          riski gerçek; o boy bir tur önce tam bu yüzden 19'dan 27'ye
          çıkarılmıştı. Web `RankSeal.tsx` ile aynı gün aynı değere çekildi.
       5. **Tırtık HER BOYA yayıldı** (kullanıcı: "leaderboard'daki küçük
          rozetlerde tırtık olamıyor mu?") — 1. maddedeki "kompakt düz
          çember kalsın" gerekçesi ÖLÇÜLMEDEN yazılmış ve YANLIŞTI: hesap
          DPR 1 varsayıyordu, retinada (DPR 3) 0.9 CSS px = 2.7 cihaz
          pikseli. Web tarafında 18px/DPR3 render edilip büyütülerek
          doğrulandı, dişler net. Diş sayısı bilerek aynı (24) — tek
          siluet, tek sabit seti. **Kompakt harf 27'de KALDI ve bu sefer
          MÜREKKEPLE ölçüldü:** tırtık yayılınca iç sınır daraldı (düz
          çemberin iç kenarı 19.25 → vadi iç kenarı 17.8) ve harfin bbox
          köşesi 18.17, yani KUTU taşıyor — ama kutunun köşesi boş; 20×
          ölçekte piksel taranınca en uzak mürekkep 16.56 (Ç), sınıra
          1.24 birim var. **Yuvarlak harflerde bbox köşesini sınır sanmak
          yanlış pozitif üretir.**
       6. **Kart gölgesi düz düşen gölgeye çevrildi** (kullanıcı: "üst ve
          sol tarafındaki beyaz gölge iyi durmuyor") — `kRaisedShadows`in
          sol-üst beyaz parıltısı nömorfik YÜZEYLER için tasarlandı,
          `bg-black/40` üstünde yüzen bir kartta hale gibi okunuyordu.
          Yeni `kFloatingCardShadows` (`neo_box.dart`, web `Modal.tsx`'in
          `0 20px 45px rgba(15,23,42,.5)`'i) hem `RankInfoModal` hem
          `RewardBanner` kartında — İKİSİ AYNI KART, biri değişirse öteki
          de. Mührün kendi 88px'lik dairesi `kRaisedShadows` TAŞIMAYA
          DEVAM ediyor (web'de de `shadow-raised`).
       7. **Bilgi popup'ında kocaman "KAPAT" butonu kalktı, sağ üste ✕
          geldi** — salt bilgi veren bir popup'ın altına tam genişlikte
          aksiyon butonu konmaz; stil `KModal`ın ✕'inden birebir alındı.
          ~~**Banner'ın "DEVAM"ı KALDI:** o gerçek bir aksiyon (ödülleri
          görüldü işaretler).~~ — **AYNI GÜN geri alındı, bkz. Parça 69:**
          kullanıcı kuralı banner'lara da genişletti ("bu banner'larda
          kapat, devam vb olmamalı, sadece X"); işaretleme kaybolmadı, ✕
          aynı `onClose`'a bağlandı.
       8. **Kuyruklu harfler (Ç/Ş) mühürde alta kaçıyordu — taban çizgisi
          artık MÜREKKEPTEN hesaplanıyor** (kullanıcı: "Ç, Ş gibi altında
          kuyruk olan karakterler ortalı durmuyor, alta daha yakın
          duruyor"). Eski hâl web'de `dominant-baseline="central"`, portta
          `TextPainter`ın satır kutusu ortalaması — İKİSİ DE mürekkebi
          değil FONT METRİKLERİNİ (ascent/descent) ortalıyor. Ölçüm iki
          ayrı sapma gösterdi: TÜM harfler ~1.2 birim aşağıdaydı (Space
          Mono'nun descent'i ink descent'inden büyük), Ç/Ş sedilla yüzünden
          ~2.5 birim DAHA aşağıdaydı — 27 puntoda toplam 2.85 birim, yani
          kullanıcının gördüğü fark. **Düzeltme harf başına tablo DEĞİL,
          iki ölçülmüş sabit:** `kSealInkAscEm` (.71 — M/U/D .70,
          yuvarlaklar .72'nin ortalaması) ve `kSealDescenderEm` (.21);
          taban çizgisi `(inkAsc − varsa descender)/2` kadar merkezin
          ALTINA konuyor (`sealBaselineEm`). Painter `computeLineMetrics()`
          ile satır kutusunun tepesinden `baseline` kadar geri alıyor —
          `Center`/`tp.height/2` ile hizalamak tam da düzeltilen hatayı
          geri getirirdi. Düzeltmeden sonra azami sapma 27'de **0.32**,
          23'te **0.27** (ölçüldü). Web `RankSeal.tsx`'in `baselineY`'siyle
          AYNI formül, ikisi ELLE senkron — biri değişirse öteki de.
          **Yan bulgu (bilinçli KULLANILMADI):** mürekkep yukarı kayınca
          Ç'nin merkeze en uzak mürekkebi 16.56 → **12.61**'e (fs=27),
          tam boyda 10.74'e düştü — yani 4. maddedeki punto tavanları
          artık çok daha gevşek; kullanıcı mevcut görünümü onayladığından
          punto DEĞİŞTİRİLMEDİ, yalnızca kayda geçti.
     - **Doğrulama (düzeltmeler sonrası):** `flutter analyze` "No issues
       found!"; **tam takım 351/351 yeşil** (350'den +1). 1-4. maddeler
       için yeni test eklenmedi, mevcut üç assertion güncellendi
       (`find.text('Rütben geriledi!')`, `find.text('100')` +
       `find.text('100 puan')` findsNothing, ve "çubuk gizli" testi artık
       `find.byType(RankProgressBar)` yokluğunu ölçüyor — eşik metnine
       bağlı olmadığından etiket bir daha değişirse yanlış yeri işaret
       etmez). 5-7 için: mühür testi artık painter'ı sahte bir `Canvas`'a
       çizdirip ilkelleri SAYIYOR (iki boyda da `drawCircle` YOK, iki
       `drawPath` var; `drawArc` yalnızca tam boyda) — "tırtık mı düz
       çember mi" sorusu ekran görüntüsüne bakmadan yanıtlanıyor; ayrıca
       yeni bir test ✕'in varlığını + "KAPAT"ın yokluğunu + kart
       gölgesini doğruluyor, banner'ın kendi testine de aynı gölge
       assertion'ı eklendi. **Negatif eş, üçü ayrı ayrı:** `rank_seal.dart`
       stash'lenince `Expected: <0> Actual: <2>` (çemberler geri geldi),
       iki modal dosyası stash'lenince hem gölge testi (`Actual: [Instance
       of 'CssShadow', Instance of 'CssShadow']`) hem ✕ testi (`Found 1
       widget with text "KAPAT"`) GERÇEKTEN düştü. Ekran görüntüsü
       `build/screenshots/rank_info_modal.png` yeniden üretilip gözle
       kontrol edildi (tırtıklı mavi mühür, sağ üstte ✕, beyaz halesiz
       kart, `50` / `83` / `100` etiketleri, solda yeşil `(+5)✓`, sağda
       gri `(+10)`). **8. madde (ölçüldü, ayrı test):** `RankSeal(size:440)`
       gerçek fontlarla render edilip `RepaintBoundary.toImage` ile PNG'ye
       çekiliyor, iç halkanın içindeki (r<15 viewBox birimi) mürekkep
       piksel piksel taranıp altı kademe harfinin (Ç Ş M O U D) dikey
       merkezi ölçülüyor — her birinin sapması <0.6 VE Ç ile M'nin farkı
       <0.6 olmalı. **Negatif eş:** `rank_seal.dart` stash'lenince test
       GERÇEKTEN `Ç dikeyde ortalı değil: 2.85` ile düştü, geri konunca
       yeşile döndü. **Tam takım 352/352 yeşil** (351'den +1); ilk koşuda
       ilgisiz bir test bir kez düşüp sonraki iki temiz koşuda hiç
       tekrarlamadı (Parça 13/21'de belgelenen sqflite yazma-kilidi
       flake'i — bu parçanın kodu o testin yoluna hiç değmiyor).

   - ✅ **Parça 62 — rütbe merdiveni 6'dan 9 kademeye çıktı: Usta 250,
     üstüne Efsane/Uzaylı/Tanrı (12 Ağustos 2026, `league_rank.dart`,
     `tokens.dart`, `tailwind.config.js` + web `leagueRank.ts` +
     `rank_tiers_efsane_uzayli_tanri` migration'ı):** Kullanıcı isteği —
     *"Usta 200'ü 250 yapalım. Destan'dan sonra 2500 Efsane. 5000 Uzaylı.
     10000 Tanrı olsun. Ödül puanları da aynı mantığa göre ayarla.
     Tanrı'dan sonra hep tanrı olarak kalsın."* Yeni bir mekanizma YOK;
     üç kopyalı tablo (SQL ↔ TS ↔ Dart) genişletildi.
     - ⚠ **En üst kademenin ADI 19 Ağustos 2026'da "Kozmik" oldu** (harfi
       de T → K). Yukarıdaki alıntı ve bu parçanın geri kalanı o günkü
       gerçeği yansıtan TARİHSEL kayıt, bilerek değiştirilmedi — güncel
       tablo için `league_rank.dart`/`leagueRank.ts`'e bak. Eşik/ödül/renk
       değişmediğinden migration gerekmedi; gerekçe ve elenen alternatifler
       kök `CLAUDE.md`'nin "k-lig Ödül & Rütbe Sistemi" bölümünde.
     - **Ödül = eşik/10 kuralı bu değişiklikle tabloya TAM oturdu.**
       Kural zaten 5 kademede geçerliydi, TEK kırık üye Usta'ydı (200
       eşik / 25 ödül). Kullanıcının eşiği 250'ye çekmesi onu farkında
       olmadan onardı — yeni üçlü de aynı orandan türetildi (250/500/
       1000). Tanrı'nın 1000'i `league_rewards_points_check`in tavanına
       (`points <= 1000`) TAM oturuyor: bir üst kademe eklenecekse o
       kısıt da büyütülmeli, bu üç dosyaya not düşüldü.
     - **Kümülatif toplamlar PAİRWİSE FARKLI olmak ZORUNDA** —
       `rewardAlreadyClaimed` ödenen eşik kümesini yalnızca TOPLAM ödül
       puanından türetiyor. Yeni dizi 0/5/15/40/90/190/440/940/1940;
       farklılık artık bir yorum değil TEST (aşağı bkz.).
     - **Uzaylı'nın harfi "Z", "U" DEĞİL** — U zaten Usta'da ve mühür tek
       glyph gösterdiğinden iki kademe yalnızca renkleriyle ayrışırdı.
       Kullanıcı önce *"Mühür harfleri yerine uygun imojiler mi
       yaratsak?"* diye sordu; üç ÖLÇÜLMÜŞ itirazla emoji elendi ve
       kullanıcı harfleri seçti: (a) emoji kendi renkleriyle çizilir,
       `fill`/`color` yok sayılır — kademe rengi (mührün tek kimlik
       taşıyıcısı) kaybolurdu; (b) k-lig satırındaki mühür 18px, o boyda
       emoji detayı okunmaz (harf okunuyor); (c) CanvasKit renkli emojiyi
       çalışma anında `fonts.gstatic.com`'dan çekiyor (Parça 29'da
       ölçüldü, `pubspec.yaml`'da gömülü emoji fontu YOK) — ağ engelliyse
       boş daire çıkar, harfte böyle bir bağımlılık yok.
     - **Üç yeni palet token'ı** (`kIndigo`/`kCyan`/`kGoldBright`) —
       "her kademe rengi bir palet token'ıdır" değişmezi kırılmasın diye
       `tailwind.config.js`'e de eklendiler (kanonik kaynak orası) ve
       `color_tokens_test`in HEM tailwind parite HEM "yerel kopya"
       taramasına girdiler; `kTilePts` gibi bir istisna gerekmedi, bu üç
       değerin `lib/` altında başka anlamı yok. **`tailwind.config.js`
       `mobile/` DIŞINDA** — port dalında mahsur kalmasın diye web yarısı
       (leagueRank.ts + migration + tailwind) AYNI GÜN `main` tabanlı ayrı
       bir dalda teslim edildi (Parça Bitirme Kontrol Listesi madde 1).
     - **Canlıda GERÇEK fonksiyonla doğrulandı (geri alınan transaction):**
       disposable bir hesaba 4900 sahte galibiyet yazılıp gerçek
       `_award_league_rewards` çağrıldı — 8 eşiğin TAMAMI (Tanrı dahil)
       tetiklendi. Bu aynı zamanda ödül geri besleme döngüsünü de
       kanıtladı: 9800 taban puan tek başına 10000'i geçmiyor, biriken
       940 ödül puanıyla geçiyor. `rollback` sonrası iz kalmadığı ayrıca
       sorgulandı. Migration'dan ÖNCE de kontrol edildi: eşik 200'de hiç
       `league_rewards` satırı yoktu, yani Usta değişikliği hiçbir kaydı
       öksüz bırakmadı.
     - **Test — negatif eş doğrulamasıyla:** `league_rewards_test.dart`'ın
       sınırları (249/250 … 999999→Tanrı), renkleri ve ödül tablosu
       genişletildi; ödül testi artık sabit listeyi karşılaştırmakla
       kalmayıp `reward == threshold ~/ 10` kuralını da her kademede
       zorluyor. Yeni bir test kümülatif toplamların farklılığını
       sabitliyor. "En üst kademede çubuk yok" testi 1200/Destan'dan
       12000/Tanrı'ya taşındı ve kardeşi eklendi ("Destan artık en üst
       DEĞİL — Efsane hedefiyle çubuk çizilir"); bu eşleşme bilinçli, tek
       başına ilki merdiven yanlış kısaltılsa da geçerdi. `league_rank.dart`
       + `tokens.dart` + `tailwind.config.js` birlikte `git stash`lenince
       takım GERÇEKTEN `+0 -2` (derleme hatası — belirsizliksiz) ile
       düştü, geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       354/354 yeşil** (352'den +2). `kelimeki_core`'a hiç dokunulmadı
       (motor rütbe/ödül bilmiyor), golden vector turu gerekmedi.
     - **Doğrulama sınırı:** cihazda görsel teyit (yeni üç rengin mühürde
       ve ilerleme çubuğunda nasıl durduğu, "Z" harfinin okunabilirliği)
       kullanıcıdan bekleniyor — `mobile/TESTING.md` bölüm 13 güncellendi.

   - ✅ **Parça 63 — k-lig tablosuna OHP (ortalama hamle puanı) kolonu
     (12 Ağustos 2026, `stats_api.dart`, `leaderboard_modal.dart` + web
     `leaderboard`/`my_leaderboard_rank` + `Leaderboard.tsx`):** Kullanıcı
     isteği — *"Hem web hem de app'te leaderboard tablosunda Puan kolonunun
     soluna OHP kolonu ekle (mouseover/hover ya da tıklanınca/değince hint
     olarak ne olduğu gösterilsin) rakamlar düz gri olsun."* Web yarısı
     `main` tabanlı ayrı bir dalda teslim edildi (Parça Bitirme Kontrol
     Listesi madde 1).
     - **Sunucu — sayı ELLE hesaplanmadı, `player_stats_overall`'ın
       İFADESİ birebir kopyalandı:** `avg_move_score` bir AĞIRLIKLI
       ortalama (`sum(move_points_sum)/nullif(sum(move_count),0)`, 2
       basamak), oyun başına ortalamaların ortalaması DEĞİL. `leaderboard`
       view'ına aynı ifade eklendi ki bir oyuncunun k-lig satırındaki OHP
       ile Skor Kartı'ndaki "Ortalama Hamle Puanı" HİÇBİR ZAMAN
       ayrışamasın. Migration'dan ÖNCE canlıda doğrulandı: 15 kullanıcının
       TAMAMINDA iki ifade birebir eşleşti (0 sapma, 0 null, aralık
       6.70-15.54).
     - **`create or replace view`, drop/create DEĞİL** — kolon SONA
       eklendiğinde grant'ler ve `security_invoker = false` (owner hakları;
       view'ın `profiles`/`games` üzerindeki kilitli RLS'i bypass etmesini
       sağlayan şey) korunuyor. Uygulandıktan sonra canlıda `set local role
       authenticated` + gerçek bir JWT iddiasıyla teyit edildi: sıradan bir
       hesap hâlâ 15 satırın hepsini OHP dolu görüyor.
     - **`my_leaderboard_rank` de genişletildi** ("senin sıran" kısayolu):
       dönüş TİPİ değiştiğinden `drop function` + `create` şart, grant'ler
       elle geri kuruldu. Kısayol AYNI tabloda AYNI kolonları çizdiğinden
       alan eklenmeseydi o tek satırda OHP boş kalır, tablo hizasız
       görünürdü.
     - **`parseNullableDouble` — ölçülemeyen bir varsayımın dürüst
       kaydı:** `PlayerStats` `numeric` alanları düz `as num?` ile okuyor
       ve bu cihazda çalıştığı kanıtlanmış (yani PostgREST numeric'i JSON
       SAYISI döndürüyor); ama bu ortamdan REST ucuna erişilemediğinden
       (proxy 403) OHP alanları için AYNI varsayım ÖLÇÜLEMEDİ. Bir dize
       gelseydi `as num?` tüm k-lig listesini bir TypeError ile düşürürdü —
       iki olasılığı da kabul etmek iki satır, yeni bir bağımlılık yok.
     - **Hint iki yoldan da açılıyor, çünkü tek yol yetmez:** `Tooltip`
       (masaüstü hover — web `title`) VE başlığa dokununca açılan bir
       satır (`_showOhpHint`). Dokunmatikte hover DİYE BİR ŞEY olmadığından
       tooltip tek başına keşfedilemez; web'de de aynı ikili var (`title`
       + tıklanınca açılan paragraf).
     - **Renk kararı ölçülerek değil KURALDAN geldi:** "düz gri" =
       `kMuted`, yani `tailwind muted` token'ı (`color_tokens_test` bunu
       zaten web'e karşı doğruluyor) — yeni bir gri icat edilmedi. Puan
       kolonunun mavi/kalın kalması testte AYRICA sabitlendi, aksi halde
       "gri yaptım" iddiası Puan'ı da griye çekseydi geçerdi.
     - **Test — negatif eş doğrulamasıyla, İKİ TURDA:** ilk tur iki lib
       dosyasını birden `git stash`ledi ve DERLEME hatası verdi (güçlü ama
       UI iddialarını sınamıyor); ikinci turda yalnızca
       `leaderboard_modal.dart` geri alınıp `stats_api.dart` yerinde
       bırakıldı — widget testi GERÇEKTEN `Found 0 widgets with text
       "OHP"` ile düştü, `parseNullableDouble` testi (doğru şekilde) geçti.
       **Bunu mümkün kılmak için test, hint metnini `ohpHint` SABİTİ
       yerine düz dizeyle yazıyor:** sabite bağlanan bir assertion, widget
       hint'i hiç göstermese bile derlenir ve negatif eş kanıtlanamazdı.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       356/356 yeşil** (354'ten +2). `kelimeki_core`'a hiç dokunulmadı
       (motor istatistik bilmiyor), golden vector turu gerekmedi.
     - **Doğrulama sınırı:** gerçek `leaderboard`/`my_leaderboard_rank`
       uçlarından gelen OHP'nin cihazda göründüğü ve Skor Kartı'ndaki
       sayıyla eşleştiği kullanıcıdan bekleniyor — `mobile/TESTING.md`
       bölüm 4'e çapraz kontrol maddesi eklendi.
     - **AYNI GÜN, kullanıcının iki düzeltmesi + bir sorusu (iki platforma
       birden uygulandı, bkz. kök `CLAUDE.md`):**
       1. **Rakamlar 14 → 11px** (satırın kendi puntosundan küçük). Puan
          14/kalın/mavi kaldı ve bu testte AYRICA sabitlendi — aksi halde
          "küçülttüm" iddiası Puan'ı da küçültseydi geçerdi.
       2. **Açıklama artık başlığın ALTINA açılan bir kutu DEĞİL, TAM
          ÜSTÜNDE aşağı bakan kuyruklu bir balon.** `Tooltip` kaldırıldı:
          Flutter'ın kendi balonu kendi metnini kendi konumunda gösterip
          İKİNCİ bir balon üretirdi. Yeni yapı `OverlayPortal` +
          `CompositedTransformFollower` (`targetAnchor: topRight` /
          `followerAnchor: bottomRight`) — başlık satırı modalın kaydırma
          kabında yaşadığından normal bir `Stack` çocuğu hem kırpılır hem
          satır yüksekliğini değiştirirdi.
          - **İki ayrı bayrak, çünkü kapanma kuralları farklı:**
            `_ohpHintHover` (masaüstü `MouseRegion` — fare çekilince
            kapanır) ve `_ohpHintPinned` (dokunuş; mobilde hover DİYE BİR
            ŞEY YOK). Görünürlük ikisinin BİRLEŞİMİ (`_syncOhpHint`).
          - **Tam ekran bariyer YALNIZCA pinned iken var** — hover'da da
            olsaydı fare başlığın üstündeyken tüm modal tıklanamaz olurdu.
            Bariyer başlığı da kapladığından "tekrar dokununca kapanır"
            kuralı ondan geliyor (ayrı bir toggle yolu gerekmedi).
          - Kuyruk `Path.combine`/PathOps KULLANMIYOR (Parça 18 dersi):
            düz bir üçgen `drawPath` + yalnızca İKİ EĞİK kenarın stroke'u
            (üst kenar kutunun kendi çerçevesiyle çakışıyor, 1px yukarı
            kaydırılarak dikiş kapatılıyor).
          - Metin `letterSpacing: 0` taşıyor — Material 3'ün varsayılan
            0.25 tracking'i ("Sonraya Bırakılan İşler"deki açık madde) bu
            yeni metne sızmasın diye.
       3. **Kullanıcının sorusu — "OHP şu anda o şekilde hesaplanmıyor
          mu?" — canlı veriyle DOĞRULANDI, kod değişmedi.** View'ın değeri
          15 kullanıcının TAMAMINDA `sum(move_points_sum)/sum(move_count)`
          ile birebir eşleşiyor; ayrım kanıtlı: oyun başına ortalamaların
          ortalaması T5'te 9.86 verirken gerçek değer 12.59 — yani yeni
          metin ("tüm oyunlarda yapılan TÜM HAMLELERİN ortalaması") mevcut
          hesabı doğru tarif ediyor ve öteki yöntem için YANLIŞ olurdu.
     - **Doğrulama (düzeltmeler sonrası):** `flutter analyze` "No issues
       found!"; **tam takım 356/356 yeşil** (yeni test eklenmedi, mevcut
       OHP testi genişletildi: punto + balonun başlığın ÜSTÜNDE olduğu +
       üç kapanma yolu — dışarı dokunuş, tekrar dokunuş). **Negatif eş:**
       `leaderboard_modal.dart` `git stash`lenince test GERÇEKTEN
       `Expected: <11> Actual: <14.0>` ile düştü, geri konunca yeşile
       döndü. Balon gerçek fontlarla render edilip (geçici bir
       `RepaintBoundary` harness'i, sonra silindi) gözle kontrol edildi:
       başlığın üstünde, kuyruk OHP'yi gösteriyor, metin büyük harfe
       dönmemiş, kırpılma yok.

   - ✅ **Parça 64 — CI'da tekrarlayan sqflite timer flake'i:
     `setup_cloud_test.dart` yük altında düşüyordu (12 Ağustos 2026,
     `setup_cloud_test.dart`):** Port dalı `main`'e merge edilirken CI'ın
     `Analiz + testler` işi düştü; log'da tek hata `A Timer is still
     pending even after the widget tree was disposed.` (`!timersPending`,
     `binding.dart:2542`) ve yığın izi doğrudan sqflite'ın
     `txnWriteSynchronized`ına iniyordu: `_SetupScreenState._syncCloud` →
     `GamesRepo.flushPending` → `PendingQueueStore.readAll` → gerçek bir
     sqflite yazması (TTL süpürmesi).
     - **Sınıf zaten belgeliydi ama BU dosyada uygulanmamıştı:** Parça 11
       aynı hatayı `online_game_chat_test.dart`'ta yaşayıp çözmüştü
       (`tester.runAsync` + gerçek zaman payı; Parça 13'te 50ms yük
       altında yetmeyip 200ms'ye çıkarılmıştı). `setup_cloud_test.dart`'ın
       GERÇEK depoyu (`memGamesRepo`) kullanan testleri aynı yolu
       tetikliyordu ama hiç pay tanımıyordu — sahte zamanda yazma
       ilerlemediğinden sqflite'ın ~10 saniyelik kilit-uyarı `Timer`'ı
       iptal edilmeden kalıyordu.
     - **`tearDown`'da depoyu kapatmak ÇÖZMEZ** (denemeden önce SDK
       kaynağından doğrulandı): `!timersPending` kontrolü test GÖVDESİ
       biter bitmez, kullanıcı `tearDown`'undan ÖNCE çalışıyor. Gerçek
       zamanı gövdenin İÇİNDE tanımak tek yol.
     - **Düzeltme:** dosyaya ortak bir `drainRealIo(tester)` yardımcısı
       (200ms `runAsync` + `pump`) eklendi ve `memGamesRepo` kullanan DÖRT
       testin sonuna çağrıldı.
     - **Dürüst doğrulama sınırı — negatif eş KURULAMADI:** flake yerelde
       ÜÇ temiz tam koşuda (merge öncesi 356/356 ×2, düzeltme sonrası
       356/356) hiç tekrarlamadı; yalnızca CI'ın paylaşımlı runner'ında,
       dört ayrı koşuda (#91/#92/#93/#96 — üçü bu dosyada, biri
       kardeşinde) görüldü. Yani "geri alınca düşüyor" gösterilemez;
       gerçek kanıt CI'ın yeşile dönmesi. **Parça 13'ün dersinin bir üst
       basamağı:** tek dosya koşusu yanlış güven verir → tam paket koşusu
       da yanlış güven verebilir, bazı flake'leri YALNIZCA yüklü bir
       runner yakalıyor.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       356/356 yeşil** (yeni test yok — dört mevcut testin gövdesine
       gerçek-zaman payı eklendi). `kelimeki_core`'a hiç dokunulmadı.

   - ✅ **Parça 65 — "Tüm Oyunlarım"daki her karta hamle geçmişi ikonu:
     `games.moves` (12 Ağustos 2026, `game_record.dart`, `games_api.dart`,
     `game_history_modal.dart`, `board_widget.dart`, `history_entry.dart` +
     web `gameRecord.ts`/`api.ts`/`GameHistoryModal.tsx` +
     `games_moves_snapshot` migration'ı):** "Sonraya Bırakılan İşler"deki
     madde kapandı — kullanıcı isteği: *"mesaj balonunun yanına aynı boyda
     bir file ikonu koyup tüm hamleleri getirmek", "Lazy yükleme olarak.
     Hamleler dialogunda nasılsa aynısı gelsin, tüm detaylarıyla"*.
     - **Yeni UI maliyeti ~sıfır:** `MoveHistoryModal` (Parça 8) zaten
       hazır ve `GameState` alıyor; `buildSnapshotGameState([], playerCount,
       players)` üstüne `moveHistory` konarak açılıyor. Yeni modal, yeni
       bağımlılık, yeni asset YOK.
     - **İkon KOPYALANMADI, paylaşıldı:** `board_widget.dart`'ın alt
       şeridindeki `_DocumentIcon` public `DocumentIcon`a çevrildi (boyut +
       renk parametreli). Aynı şeyi açan iki kontrol aynı görünmeli
       (`RelationIcons` ilkesi). **Web tarafında da aynı hizalama
       yapıldı** — `GameHistoryModal.tsx`'in yeni `MovesIcon`'u
       `Board.tsx`'in path'leriyle birebir (ilk yazımda satır çizgileri
       `M8 13h8M8 17h5` diye sapmıştı, `M9 13h6M9 17h6` oldu).
     - **Dokunma hedefi BİLİNÇLİ olarak 44px'e çıkarılMADI:** Parça 52'nin
       "ikon-only kontrol 44px görünmez alan taşır" kuralı burada
       uygulanmadı — istek açıkça "aynı boyda" diyordu ve hemen yanındaki
       sohbet rozeti de 11px; 44px'lik bir alan ~20px'lik satırda kardeş
       kontrolleri ve kartın kendi dokunuşunu (tahtayı aç/kapa) yutardı.
       Iskalanan dokunuş yıkıcı değil (kart açılır). Cihazda rahatsız
       ederse İKİ rozet BİRLİKTE büyütülmeli.
     - **Ağ hatası ile "kaydedilmemiş" AYRI taşınıyor:** `GamesRepo.moves`
       artık `({bool ok, List<HistoryEntry>? moves})` dönüyor —
       `boardSnapshot`'ın ikisini de `null`a çeken davranışından BİLİNÇLİ
       sapma (web de ayırıyor). Çevrimdışı kullanıcıya "kaydedilmemiş"
       demek yanlış olurdu: veri sunucuda duruyor. Hata ÖNBELLEĞE GİRMEZ,
       tekrar dokunuş yeniden dener.
     - **SQL'de bulunan gerçek hata (kök `CLAUDE.md`'de ayrıntısı):**
       `_online_moves_snapshot`ın iki UNION dalı AYRI `row_number()`
       üretiyordu, vergi satırları yanlış sıraya düşüyordu — ortak bir
       `ordered` CTE'siyle düzeltildi. **İfadeyi gerçek veriye karşı
       KOŞTURDUĞUM için bulundu, okumakla değil.**
     - **Yan bulgu — `HistoryEntry.toJson`'ın anahtar SIRASI web'den
       sapmıştı:** port TS'in ARAYÜZ bildirim sırasını izliyordu, oysa
       `JSON.stringify` ÇALIŞMA ANINDAKİ ekleme sırasını yazıyor
       (`pushHistory`: turn, player, words, points, sonra wordScores…).
       Golden vector karşılaştırması YAPISAL olduğundan bugüne kadar
       görünmedi; `games.moves` iki istemcinin de aynı satırı yazmasını
       gerektirdiği an `web_game_record.json` fikstürü bunu bayt bayt
       yakaladı. Dart çalışma anı sırasına hizalandı. **Ders: "kanonik
       JSON" sözleşmesi TİP BİLDİRİMİNE değil, TS'in çalışma anındaki
       nesne literaline bakar.**
     - **Fikstür CERRAHİ yeniden üretildi:** web'in ÜRETİM
       `buildGameRecord`'u fikstürün KENDİ state'leriyle koşturulup
       yalnızca `record` yarısı yeniden yazıldı (girinti korunarak).
       Anlamsal diff: TEK değişiklik iki senaryoya eklenen `moves` (46 ve
       12 satır) — id/saat/tahta/skorlar bit düzeyinde aynı kaldı.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:**
       `game_likes_test.dart`'a iki test (rozet HER kartta + sohbet rozeti
       yokken de var + döküm gerçekten LAZY + modal içeriği; ağ hatası ile
       "kaydedilmemiş"in AYRI mesajlar olduğu + hatanın önbelleğe
       girmediği). `game_history_modal.dart` `git stash`lenince ikisi de
       GERÇEKTEN düştü (`+15 -2`); `history_entry.dart` ayrıca
       stash'lenince fikstür testleri GERÇEKTEN düştü (anahtar sırası —
       `Differ at offset 3296`), ikisi de geri konunca yeşile döndü.
       `FakeGamesGateway`e `movesCalls` eklendi (lazy iddiasının kanıtı).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       358/358 yeşil** (356'dan +2). `kelimeki_core` DEĞİŞTİ
       (`history_entry.dart`) — kural gereği Dart çekirdek testleri
       koşuldu: **6746 kontrol, 0 hata**; golden vector fixture'ları TS
       tarafı hiç değişmediğinden yeniden üretilmedi. Web `npm run lint` +
       `npm run build` temiz.
     - **Doğrulama sınırı:** gerçek `games.moves` okuması (kolon grant'i,
       gerçek satırlar) cihazda doğrulanmalı — `mobile/TESTING.md` bölüm
       5'e madde eklendi. Migration canlıya uygulandı ve altı değişmezle
       doğrulandı (bkz. kök `CLAUDE.md`).

   - ✅ **Parça 66 — "Nasıl Oynanır?"a rütbe/ödül bölümü + bölüm
     başlıklarının `uppercase`ı Parça 10'dan beri eksikmiş (12 Ağustos
     2026, `help_modal.dart` + web `HelpModal.tsx`):** Kullanıcı bir
     doküman-tazelik denetimi isterken *"mesela rank olayını nasıl oynanır
     alt kısma ekleyebiliriz"* dedi. Denetim onu doğruladı: k-lig bölümü
     yalnızca puanın nasıl KAZANILDIĞINI anlatıyordu — -2 cezası, ödül
     eşikleri ve dokuz rütbe hiçbir yerde yazmıyordu.
     - **Tablo ELLE YAZILMIYOR, `kRankTiers`ten çiziliyor** (web'de
       `RANK_TIERS`ten) — eşik/ödül değişirse iki ekran da kendiliğinden
       takip eder. Bu bilinçli: kademe tablosu zaten ÜÇ KOPYA elle senkron
       (SQL ↔ `leagueRank.ts` ↔ `league_rank.dart`); "Nasıl Oynanır?"a
       elle bir tablo yazmak DÖRDÜNCÜ kopyayı açardı ve sessizce
       ayrışacak ilk yer orası olurdu.
     - **Metin web'den BİREBİR kopyalandı** (Parça 10'un kuralı: kural
       metinleri özetlenmez) — `**kalın**` işaretlemesi `_runs()` ile
       TextSpan'e çevriliyor. Yeni `_RankRow` widget'ı `_TileRow`un hemen
       öncesinde: 26px'lik ortalanmış harf (kademe renginde) + kalın ad +
       " — N puan" + yeşil "(ödül +N)".
     - **YAN BULGU, kod okumasıyla DEĞİL yan yana render'la bulundu:**
       web'in `<h3 ... uppercase>`ı porta hiç geçmemiş — on bölüm başlığı
       da ("Puan Tablosu", "Bölge Vergisi"…) küçük harfle çiziliyordu.
       Parça 10 "web'in yardımcıları birebir taşındı (Section/P/Pill/…)"
       diyordu, yani niyet buydu, yalnızca `text-transform` atlanmıştı.
       `trUpper` eklendi — native `toUpperCase` DEĞİL (Türkçe kural:
       "Nasıl" → "NASIL", noktalı I üretmemeli). **Bu, istenen işin
       KAPSAMI DIŞINDAYDI ve bilerek yapıldı:** aynı dosyada, tek satır,
       ve tam da bu projenin en sık tekrarlayan hata sınıfı (sessiz
       web↔port ayrışması); istenmezse tek satırlık geri alma.
     - **Ölçüm — iki ekran GERÇEKTEN yan yana render edildi:** mobil
       tarafta `HelpModal` 420×1400'de pump edilip bölüme kaydırılarak
       PNG'ye çekildi (geçici harness, sonra silindi); web tarafında
       `npm run build` çıktısı yerel bir sunucudan Playwright/Chromium'la
       açılıp aynı bölüme kaydırıldı. Uppercase farkı TAM BURADA görüldü —
       ekran görüntüsü olmadan iki tarafın kodunu okumak bunu vermezdi
       (`uppercase` bir CSS sınıfı, Dart'ta karşılığı yok, yani "eksik
       olan" görünmez bir şeydi).
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** yeni bir
       test dokuz kademenin `kRankTiers`ten çizildiğini (harf/ad/eşik/
       ödül; Çaylak'ta "(ödül +0)" YOK) ve -2 paragrafını doğruluyor;
       mevcut bölüm-başlığı testi büyük harfli beklentilere çevrildi
       (metinler ELLE büyük yazıldı ki `trUpper`ı kendisiyle
       karşılaştıran bir totoloji kurulmasın). `help_modal.dart`
       `git stash`lenince 2 test GERÇEKTEN düştü (`Found 0 widgets with
       text "Rütbeler ve Ödüller"`, `Found 0 widgets with text "Ç"`);
       ayrı bir turda yalnızca `trUpper(title!)` → `title!` çevrilince
       başlık testi GERÇEKTEN `bölüm yok: NASIL OYNANIR?` ile düştü.
       İkisi de geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       359/359 yeşil** (358'den +1). Web `npm run lint` + `npm run build`
       temiz. `kelimeki_core`'a hiç dokunulmadı (yalnızca `trUpper`
       import edildi) — golden vector turu gerekmedi.
     - ~~**Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor~~
       — **12 Ağustos 2026'da cihazda KOŞULDU ve GEÇTİ** (dokuz kademe,
       eşik/ödül değerleri ve büyük harf başlıklar; web'le yan yana
       ayrışma yok). Kontrol maddeleri `mobile/TESTING.md` bölüm 13'te
       (web'in eşi kök `TESTING.md` bölüm 10'da).

   - ✅ **Parça 67 — hamle ikonu artık yalnızca dökümü OLAN kartta; kullanıcının
     teşhisi ölçülerek çürütüldü (12 Ağustos 2026, `games_api.dart`,
     `game_history_modal.dart` + web `api.ts`/`GameHistoryModal.tsx` +
     `game_like_stats_has_moves` migration'ı):** Kullanıcı bildirdi: *"Tüm
     oyunlarda ikon var ama YZ oyunlarda içi boş geliyor, canlı oyunlarda
     dolu geliyor. YZ hiç olmayacaksa onlarda ikonu göstermesek daha iyi."*
     - **Önerilen düzeltmeyi UYGULAMADIM, çünkü dayandığı varsayım ölçümle
       çürüdü.** Canlıda: 245 yerel oyunun tamamı `moves is null`, 66 Canlı
       oyunun tamamı dolu — kullanıcının gözlemi doğru. Ama sebep TÜR değil
       ZAMANLAMA: en yeni yerel oyun 12:09 UTC'de bitmiş, kolon 15:27'de
       açılmış (`games_moves_snapshot`), yazan kod 16:04'te deploy edilmiş
       (#241). Yani kolon var olduğundan beri HİÇ yerel oyun bitmemiş;
       `buildGameRecord` `moves`u yazıyor ve `saveGame` kaydı
       `insert({...game})` ile olduğu gibi gönderiyor (ikisi de kaynaktan
       doğrulandı), dolayısıyla bundan sonra bitenler DOLU olacak.
       "YZ'de hiç gösterme" kuralı o oyunları kalıcı olarak sakatlardı.
     - **Kullanıcının NİYETİ yine de doğruydu ve uygulandı:** boş bir
       diyalog açan ikon kötü bir kontrol. Doğru kural tür bazlı değil veri
       bazlı — **"dökümü olmayan kartta gösterme"**.
     - **Karar bilgisi `moves` çekilmeden gerekiyor** (satır başına ~6.8 KB;
       lazy yükleme tam bu yüzden var), o yüzden kartın öteki rozetlerini
       zaten besleyen `game_like_stats` RPC'sine `has_moves` eklendi —
       sayfa başına TEK toplu çağrı, EK GİDİŞ-DÖNÜŞ YOK. `message_count`in
       Parça 51'de aynı RPC'ye taşınmasıyla birebir aynı desen.
     - **Sahte uç de gerçek ucun bu kararını taklit ediyor:**
       `FakeGamesGateway.likeStats` artık `has_moves`u `movesByGame`den
       türetiyor — Parça 46'nın dersi (sahtenin eksik bir dalı, o dal
       hakkındaki testleri sessizce anlamsız kılar). Bu olmadan yeni kural
       testlerde hiç sınanamazdı.
     - **Ulaşılamaz hale gelen bir test dalı düzeltildi:** eski test "kolon
       null → 'kaydedilmemiş'" mesajını doğruluyordu; ikon artık o kartta
       hiç çizilmediğinden o modal UI'dan AÇILAMIYOR. Test, yeni ve gerçek
       kullanıcı davranışını ölçecek şekilde yeniden yazıldı (dökümü olan
       kart ikonu gösterir, olmayan göstermez); "kaydedilmemiş" dalı kodda
       savunma amaçlı duruyor. Ağ hatası dalı KORUNDU — o hâlâ ulaşılabilir
       (sunucuda döküm var, istek düşüyor), yalnızca kurgusu `movesByGame`
       dolu olacak şekilde düzeltildi.
     - **Test — negatif eş doğrulamasıyla:** yeni test aynı listede dökümü
       OLAN ve OLMAYAN iki kart kuruyor — tek başına "YZ'de gösterme" gibi
       yanlış bir kural da geçerdi, o yüzden ikisi bir arada.
       `game_history_modal.dart` `git stash`lenince test GERÇEKTEN
       kullanıcının bildirdiği semptomu üretti (`Found 1 widget with key
       [<'moves-g-eski'>]`), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 360/360
       yeşil** (359'dan +1). Web `npm run lint` temiz. Migration canlıya
       uygulandı ve gerçek JWT'yle üç kontrolle doğrulandı (Canlı hepsi
       true, güncel yerel hepsi false, ve **en kritiği** bir YEREL satıra
       `moves` yazılınca bayrak true'ya döndü — geri alındı).
       `kelimeki_core`'a hiç dokunulmadı.
     - ~~**Doğrulama sınırı:** "yeni biten bir YZ oyununda ikon GERÇEKTEN
       çıkıyor mu" bu ortamdan doğrulanamaz~~ — **12 Ağustos 2026'da
       cihazda KOŞULDU ve GEÇTİ:** yeni bitirilen bir YZ oyununun kartında
       ikon çıktı, döküm doluydu. Kolon açılalı beri hiç yerel oyun
       bitmemişti, yani bu, "bundan sonra bitenler DOLU olacak"
       çıkarımının ilk gerçek uçtan uca kanıtı — Parça 67'nin kullanıcının
       teşhisini ("YZ'de hiç olmayacak") çürüten ölçümü doğrulandı.
       Kontrol maddeleri `mobile/TESTING.md` bölüm 5 ve kök `TESTING.md`
       bölüm 3'te. **Aynı turda dokunma alanı sorunu bildirildi → Parça
       68.**

   - ✅ **Parça 68 — hamle rozetinin dokunma alanı sohbet rozetinin YARISIYMIŞ
     (12 Ağustos 2026, `game_history_modal.dart` + web `GameHistoryModal.tsx`):**
     Parça 67'nin doğrulama sınırı cihazda koşuldu ve **geçti** (yeni bitirilen
     bir YZ oyununda ikon çıktı, döküm doluydu) — ama aynı turda kullanıcı yeni
     bir sorun bildirdi: *"hamleler ikonuna elle dokunmakta zorlandım, en az 4-5
     kere dokunmam gerekti. Tam basamazsan oyun detayları açılıp kapanıyor
     sürekli. Mesaj ikonu iyi bence, onunla aynı şekilde olabilir."*
     - **Parça 65 bu şikâyeti ÖNCEDEN yazmıştı** ("cihazda rahatsız ederse İKİ
       rozet BİRLİKTE büyütülmeli") — yani karar bilinçliydi, yalnızca ölçüsü
       yanlıştı. O not "aynı boyda" istendiği için hedefleri EŞİT sanıyordu.
     - **Ölçüm bunu çürüttü, üstelik İKİ platformda birden:** gerçek widget +
       gerçek fontlarla sohbet **18.8×13.0 = 244px²**, hamle **11×11 = 121px²**
       — tam yarısı. Web'de aynı yapı, aynı sonuç (derlenmiş CSS + Chromium):
       sohbet 18.9×13.5 = 255px², hamle 12×12 = 144px². **Fark tesadüf değil
       yapısal:** sohbet kontrolünün dokunma kutusuna sayı ETİKETİ de dahil
       (`Row(icon, gap, Text('N'))`), hamle ikonunda etiket yok. İki istemcinin
       6px'lik boşluğu bile birebir aynı çıktı — kusur ortak, düzeltme de ortak.
     - **Düzeltme ikonu YERİNDEN OYNATMIYOR:** dolgu eklenip önündeki boşluk
       aynı kadar kısılıyor (mobil `SizedBox` 6→2 + `horizontal: 4`; web
       `px-1 py-px` + `-mx-1` negatif margin, yani layout ayak izi hiç
       değişmiyor). Sonuç: mobil 121→**247px²**, web 144→**280px²**, ikonun
       görsel konumu ve 6px boşluk BİREBİR aynı (ölçüldü: mobilde kutu sol
       kenarı 225.6→221.6, +4px dolgu ile ikon yine 225.6'da).
     - **Dikey neden 13'te kaldı:** satırın kendi yüksekliği zaten 13 (kalp ve
       sohbet ikisi de 13); daha fazlası satırı, dolayısıyla HER kartı büyütür.
       44px'lik iOS asgarisi yine UYGULANMADI — Parça 65'in gerekçesi
       (~13px'lik satırda 44px'lik alan kardeş kontrolleri ve kartın kendi
       dokunuşunu yutar) hâlâ geçerli, ve kullanıcı çıtayı zaten "mesaj ikonu
       kadar" diye koydu.
     - **Test bir SABİTİ değil ORANI kilitliyor:** yeni test iki kutuyu ölçüp
       `hamle >= sohbet` diyor (+ ikonun görsel konumunun kaymadığını). Sohbet
       rozeti ileride değişirse hamle rozeti onunla taşınmak ZORUNDA kalır —
       Parça 65'in "iki rozet birlikte" notunun çalıştırılabilir hâli; yorum
       satırı bunu sağlamıyordu, nitekim sağlayamadı.
     - **Negatif eş:** `game_history_modal.dart` `git stash`lenince test
       GERÇEKTEN kullanıcının semptomunu üretti (`Expected: >= 18.758, Actual:
       11.0`), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 361/361
       yeşil** (360'tan +1). Web `npm run lint` + `npm run build` temiz.
       `kelimeki_core`'a hiç dokunulmadı — golden vector turu gerekmedi.
     - **Doğrulama sınırı:** "artık rahat dokunuluyor" ancak gerçek parmakla
       ölçülür — `mobile/TESTING.md` bölüm 5'e madde eklendi.

   - ✅ **Parça 69 — kutlama/düşüş banner'ında "DEVAM" kalktı, yerine ✕
     (12 Ağustos 2026, `reward_banner.dart` + web `RewardBanner.tsx`):**
     Kullanıcı, bölüm 13'ün cihaz turunda: *"bence bu banner'larda kapat,
     devam vb olmamalı, sadece X."* Bu, AYNI GÜN `RankInfoModal`'a verilen
     kararın (ilk sürümde bilinçli olarak yalnızca popup'a uygulanmıştı)
     banner'lara genişletilmesi — o notta *"Banner'ın DEVAM'ı KALIR: o
     gerçek bir aksiyon"* yazıyordu; gerekçe teknik olarak doğruydu ama
     kullanıcı görsel tutarlılığı tercih etti. Eski karar dört yerde birden
     yazılıydı (kök + mobil `CLAUDE.md`, kök + mobil `TESTING.md`,
     `rank_info_modal.dart` yorumu) ve hepsi düzeltildi — bayat kalan bir
     "KALIR" cümlesi bir sonraki oturumu geri aldırırdı.
     - **Asıl risk kozmetik DEĞİL:** "DEVAM" yalnızca kapatmıyordu,
       `onClose` → `LeagueRewardsHost._close` → `markSeen()` zincirini
       tetikleyen TEK yoldu (`mark_league_rewards_seen`). Butonu silip ✕'i
       farklı bir yola bağlamak, banner'ı **her açılışta yeniden gösteren**
       bir hataya yol açardı. ✕ bilerek AYNI `widget.onClose`'a bağlandı;
       web'de de aynı (`useModalA11y` üzerinden Escape zaten oraya bağlı).
     - **✕ kopyalanmadı, `RankInfoModal`'dan birebir alındı** (mobilde
       `IconButton` + `Icons.close` 18px/`kMuted`/`tooltip: 'Kapat'`,
       webde `Modal.tsx`'in class'ları) — iki kart aynı kart, ikisi
       birlikte değişir.
     - **Kapsam sınırı (bilinçli):** "DEVAM" metni başka iki yerde daha
       var — `FriendSuggestModal` ve sohbet hoşgeldin popup'ı. İkisi de
       birer ONAY adımı (istek gönder / karşılandı), kapatma butonu değil;
       kullanıcının cümlesi "bu banner'lar" diyordu. Dokunulmadı.
     - **Test — negatif eş doğrulamasıyla:** mevcut banner testi ✕'e
       çevrildi ve iki şeyi birden ölçüyor: tam genişlikte bir aksiyon
       butonu OLMADIĞI + ✕'in `markSeen`'i HÂLÂ çağırdığı (`markSeenCalls`
       0 → 1). `reward_banner.dart` `git stash`lenince test GERÇEKTEN düştü
       (`Found 0 widgets` — ✕ yok), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; tam takım
       **361/361** yeşil. Web `npm run lint` + `npm run build` temiz.
       `kelimeki_core`'a dokunulmadı.
     - **Doğrulama sınırı:** cihazda görsel teyit + "kapattıktan sonra bir
       daha çıkmıyor" kontrolü kullanıcıdan bekleniyor — kök ve mobil
       `TESTING.md`'deki ilgili madde bu iki şeyi birlikte soracak şekilde
       yeniden yazıldı.

   - ✅ **Parça 70 — banner başlıklarına emoji + KARTIN GENİŞLİĞİ web'den
     sapmış çıktı (12 Ağustos 2026, `reward_banner.dart` + web
     `RewardBanner.tsx`):** Kullanıcı iki turda istedi: önce *"Rütben
     Geriledi!'nin yanına üzgün emoji"*, ardından *"👏 bunu rütbe
     yükseltmeye, 🎉 bunu da 100'lerde koyabiliriz"*. Üç başlık:
     `'Rütben geriledi! 😔'` (pensive — "Üzgünüz…" alt satırının nazik
     tonuyla eşleşiyor; 😢 fazla dramatik kalırdı),
     `'Yeni rütben: X! 👏'`, `'N k-lig puanına ulaştın! 🎉'`. Dördüncü
     varyant (`'Eşik ödülü kazandın!'`) BİLEREK emojisiz kaldı — kullanıcı
     onu saymadı ve pratikte neredeyse hiç görünmüyor (rütbe/kilometre
     taşı olmadan tek başına ödül).
     - **Aynı turda "100'lerde de X olmalı" isteği zaten karşılanmıştı:**
       DEVAM butonu ortak düzendeydi, Parça 69'da kaldırılınca dört
       varyanttan birden kalkmıştı.
     - **GERÇEK BULGU — kartın genişliği web'den sapmış, ✕ dışarı
       taşıyordu:** kutlama ekran görüntüsüne bakınca ✕'in kartın DIŞINDA,
       gri zeminde durduğu görüldü. Ölçüm sebebi verdi: web'de kart
       `w-[280px]` ile HER ZAMAN 280, portta ise Stack'in
       konumlandırılmamış çocuğu GEVŞEK kısıt aldığından **içeriğe göre
       büzülüyordu** (kutlama 238.5, düşüş 280 — düşüş kartı ilerleme
       çubuğu sayesinde 280'e ulaştığından orada görünmüyordu).
       `Positioned(right: 8)` Stack'e göre konumlandığı için dar kartta ✕
       dışarı düşüyordu. **Bu sapma ✕'ten ÖNCE de vardı**, yalnızca
       ölçülecek bir kenar olmadığından görünmüyordu. Düzeltme yamayla
       (✕'i kaydırmak) değil web'e hizalayarak: `width: double.infinity`.
     - **Ders:** bir ekran görüntüsünü "emoji çıktı mı" diye açıp
       geçmeyin — Parça 69'un ✕'ini DÜŞÜŞ görüntüsünde doğrulamıştım ve
       "tamam" demiştim; aynı ✕ KUTLAMA varyantında bozuktu. Bir bileşenin
       tek varyantını görmek onu doğrulamaz.
     - **Regresyon testi:** kart genişliğinin 280 olduğu ve ✕'in kart
       sınırları İÇİNDE kaldığı artık ölçülerek doğrulanıyor (kutlama
       varyantında — bozuk olan oydu).
     - **Tek satırlık iş DEĞİL — bu projenin ÜÇ KEZ düştüğü tuzağa
       değiyor:** Flutter, tarayıcının aksine **otomatik font fallback
       YAPMAZ**; gömülü SpaceGrotesk'te bu glyph olmadığından fallback'siz
       **tofu (boş kare)** çizilir. Aynı hata daha önce `_StatusLine`'ın
       ✓'sinde, `help_modal`'ın 🎯'sinde ve ★'da yaşandı. Başlığın
       `TextStyle`'ına projedeki kurulu liste eklendi:
       `fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji']`
       (altı kullanım yeriyle aynı). Fallback yalnızca birincil fontta
       OLMAYAN glyph'ler için devreye girdiğinden kutlama başlıkları hiç
       etkilenmiyor. Web tarafında gerek yok — tarayıcı kendi fallback'ini
       yapıyor.
     - **Tofu OLMADIĞI okunarak değil GÖRÜLEREK doğrulandı:** ekran
       görüntüsü testi koşulup PNG açıldı — emoji renkli ve doğru glyph
       olarak çizilmiş (aynı görüntü Parça 69'un ✕'ini de kanıtladı:
       sağ üstte ✕, altta DEVAM yok).
     - **Cihaz uyarısı (Parça 29'un bulgusu, hâlâ geçerli):** Flutter
       Web/CanvasKit renkli emoji için çalışma anında
       `fonts.gstatic.com`'dan Noto Color Emoji ÇEKİYOR. GitHub Pages test
       derlemesi CanvasKit kullandığından, ağın Google Fonts'a erişimi
       kısıtlıysa emoji BOŞ görünebilir — bu bir kod hatası değil, web
       test ortamının yapısal sınırı. **Native (iOS/Android) derlemede bu
       risk YOK** (Skia/Impeller doğrudan işletim sisteminin emoji
       fontunu kullanır).
     - Doğrulama: `flutter analyze` temiz; tam takım **361/361** yeşil
       (iki başlık assertion'ı yeni metne çevrildi); web `npm run lint` +
       `npm run build` temiz.

   - ✅ **Parça 71 — Skor Kartı başlığında ✕ sola kaymıştı: `Flexible`ın
     görünmez `flex: 1`'i (12 Ağustos 2026, `modal_shell.dart`):** Kullanıcı
     mobil ve web Skor Kartı'nın ekran görüntülerini yan yana koyup
     *"mobilde X kaymış, ayrıca webdeki skor kartla ölçüleri farklı"* dedi.
     İKİ ayrı iddia vardı; ölçüm birini doğruladı, ötekini çürüttü.
     - **✕ — GERÇEK port hatası.** Web'de başlık `shrink-0` (doğal
       genişlik, hiç esnemez). Port bunu `Flexible(child: label)` diye
       taşımıştı — ama **`Flexible`ın varsayılanı `flex: 1`**: başlık boş
       alanın YARISINI pay olarak alıyor, `fit: loose` olduğundan doğal
       genişliğinde kalıyor ve **artan pay yeniden dağıtılmadığından**
       Row'un sonunda ölü boşluk olarak birikiyordu. Ölçüldü (360px kart):
       ✕'in merkezi sağ kenardan **75.3px** içerideydi; web'de (derlenmiş
       CSS + Chromium ile aynı düzen kurulup ölçüldü) **35.0**. Aynı hata
       mührü de kartın ortasına itiyordu (+12.7; web +35.6 — mühür kartın
       değil "başlık ile ✕ arasının" ortasında durmalı, kök CLAUDE.md'nin
       `headerCenter` kararı). Düzeltme: `headerCenter` varken başlık
       ÇIPLAK widget döner. Sonra: ✕ **32.0**, mühür **+34.3** — web ile
       ~1-3px içinde. (Kalan 3px, portun ✕ butonunun daha büyük dokunma
       hedefi taşımasından: 40px buton + 12 sağ dolgu ≈ web'in 28px buton +
       20 dolgusu. Bilinçli.)
     - **Yükseklik — port hatası DEĞİL, ölçülerek elendi.** Kullanıcı
       web'de "TÜM GEÇMİŞ OYUNLAR" linkinin göründüğünü, mobilde kesilip
       kaydırma gerektiğini bildirdi. Ölçüm: içerik İKİ tarafta da aynı
       (556px); fark yalnızca SINIRDA. iOS Safari'de CSS `vh` **büyük
       viewport**'u (tarayıcı çubuklarının altını da) sayar, yani web'in
       `max-h-[85vh]`'si görünür alanın %85'inden BÜYÜK olabiliyor;
       Flutter'ın `MediaQuery.sizeOf(context).height`'i ise görünür alan.
       Aynı iPad'de: Safari görünür yükseklik 683 → modal 580.5 (%85) →
       **52.5px kesiliyor**. Native'de kesilme YOK: iPad yatay (834),
       iPad dikey (1194), iPhone dikey (852) — üçünde de modal 633'te
       (içerik boyu) kalıyor, sınıra hiç dayanmıyor. Yani sorun ASIL
       ÜRÜNDE yaşanmıyor, yalnızca web test derlemesinde görünüyor.
       Sabit DEĞİŞTİRİLMEDİ — %85 web'in yazılı kararı ve native'de zaten
       yetiyor; bir Safari tuhaflığı için iki platformun da davranışını
       değiştirmek yanlış olurdu. (`score_card_test.dart`de bu zaten
       "gerçek cihaz boyutlarında kaydırmasız sığar" testiyle korunuyordu.)
     - **Ders:** web'in `shrink-0`/`flex-1` gibi sınıflarını porta
       çevirirken Flutter'ın VARSAYILANLARINI oku — `Flexible` "esneme"
       değil "esneme payı al" demek. Bu, sınıfın adına bakıp doğru
       göründüğü için gözden kaçan bir sınıf hata.
     - **Test:** yeni bir regresyon testi ✕'in sağ kenardan uzaklığını ve
       mührün merkezden sapmasını gerçek `ScoreCardModal` üzerinde
       ölçüyor (ikisi de web'in ölçülen değerlerine bağlı).
     - Doğrulama: `flutter analyze` temiz; tam takım **362/362** yeşil
       (361'den +1). Web'e hiç dokunulmadı (yalnızca ölçüm için kullanıldı).

   - ✅ **Parça 72 — Setup web'den %7.5 GENİŞ'ti: `max-w-[N] px-*` bir
     BORDER-BOX'tır (13 Ağustos 2026, `setup_screen.dart`,
     `friends_modal.dart`):** Kullanıcı aynı şikâyeti **ikinci kez**
     bildirdi: *"tablardan ikisi arasında geçiş yaptığımda butonların,
     kutuların ölçülerinin farklı olduğunu net görebiliyorum. Daha önce de
     belirtmiştim ama hala düzelmedi. Tüm app ölçülerini web ile
     karşılaştır."*
     - **Parça 29 bunu YARIM düzeltmişti.** O turda sabit 480→460'a
       çekilmişti; doğru sayı buydu ama **dolgunun yeri yanlıştı.**
       Tailwind `box-sizing: border-box` altında `max-w-[460px] px-4`
       demek "dış kutu ≤460, **içerik 460−32 = 428**" demek. Port ise
       yatay dolguyu `ConstrainedBox`'ın **DIŞINA** (`SingleChildScroll
       View.padding`) koymuştu → içerik 460, yani web'den **32px (%7.5)
       geniş**. Kullanıcının ekran görüntülerinden ölçülen oran
       (780/725 = **1.076**) bu 32px'le birebir örtüştü.
     - **Testin YEŞİL kalması bu hatanın hayatta kalma sebebiydi:** Parça
       29'un regresyon testi yalnızca "460'lık bir `ConstrainedBox` var mı"
       ve "eski 480 kalmamış mı" diye bakıyordu — ikisi de doğruydu, içerik
       yine de yanlıştı. Test artık GERÇEK genişliği ölçüyor (tam genişlik
       buton = **428**); negatif eşle doğrulandı (düzeltme geri alınınca
       `Actual: 460.0`). **Ders: bir kısıtın VARLIĞINI doğrulayan test, o
       kısıtın SONUCUNU doğrulamaz.**
     - **Denetim — web'deki `max-w-[…]` kullanan HER yer tek tek
       karşılaştırıldı:**

       | Web | kutu + dolgu | içerik | Port | Durum |
       |---|---|---|---|---|
       | `Setup.tsx:536` | 460 + `px-4` | 428 | dolgu DIŞARIDA | **düzeltildi** |
       | `Board.tsx:416` | 680 + `px-3` | 656 | 680 + iç 12 | ✓ |
       | `GameHeader.tsx:89` | 680 + `px-3 py-2.5` | 656 | 680 + 12/10 | ✓ |
       | `App.tsx:1393` | 680 + `px-3` | 656 | ✓ | ✓ |
       | `OnlineGameScreen:1013` | 680 + `px-3` | 656 | ✓ | ✓ |
       | `Modal.tsx:38` | 360 | 360 | 360 | ✓ |
       | `ActionSheet:43` | 360 | 360 | 360 | ✓ |
       | Confirm/InfoDialog | `max-w-sm` 384 + `p-6` | 336 | 384 + **20** | **düzeltildi** (24) |

       Yani 680'lik oyun ekranı zinciri (Parça 40'ta düzeltilmişti) baştan
       DOĞRUYDU — dolgu orada zaten kutunun içinde. Yanlış olan iki yer
       Setup ve arkadaş diyaloglarıydı.
     - **Bilinçli bırakılan 2px:** web'de GİRİŞ satırı ayrı bir kutu
       (`App.tsx:1074`, 460 + `px-3.5`) olduğundan sağ kenarı içerik
       sütunundan 2px dışarıda; portta AccountButton aynı 16'lık dolgunun
       içinde, yani içerikle HİZALI. 2px için negatif margin/Transform
       hilesi yapmaya değmez ve hizalı olması daha doğru görünüyor.
     - Doğrulama: `flutter analyze` temiz; tam takım **362/362** yeşil.
       Web'e hiç dokunulmadı (yalnızca kaynak olarak okundu).

   - ✅ **Parça 73 — GİRİŞ satırı 12px aşağıdaydı: web'in `-mt-3`'ü gözden
     kaçmış (13 Ağustos 2026, `setup_screen.dart`):** Parça 72'nin genişlik
     düzeltmesi cihazda onaylandıktan hemen sonra kullanıcı: *"sağ üstteki
     giriş butonunun üstündeki boşluk app'de daha fazla, biraz aşağıda
     duruyor."*
     - **Web'de bu ekran İKİ ayrı kutu** (`App.tsx`, kurulum dalı): üstte
       `px-3.5 pt-3` ile GİRİŞ/avatar satırı, altında `main` içinde
       `px-4 py-6` ile Setup içeriği. Port tek sütun kullandığından dikey
       dolguyu `symmetric(vertical: 24)` ile simetrik vermişti → GİRİŞ'in
       üstü 24 (olması gereken 12).
     - **Asıl tuzak `py-6`nın 24'ünde DEĞİL:** Setup'ın logo bloğu
       `-mt-3` (**−12px**) negatif margin taşıyor, yani GİRİŞ ile logo
       arası 24 değil **12**. Bu görülmezse "arada 24 olmalı" diye yanlış
       düzeltilirdi. Derlenmiş CSS + Chromium'da iki viewport'ta (1000 ve
       420) ölçüldü: **12.0 / 12.0** — ikisi de viewport'tan bağımsız.
     - Düzeltme: kaydırma dolgusu asimetrik (`top: 12, bottom: 24`) ve
       AccountButton'ın `bottom: 4`'ü yerine KOŞULSUZ bir 12px boşluk
       (`auth.configured` false iken web'de de satır boş bir kutu olarak
       render edildiğinden logonun üstü yine 12+12 = 24 kalır).
     - **Ölçüm neden canlı siteden yapılamadı:** Chromium bu ortamdan
       `kelimeki.com`a çıkamıyor (`ERR_CONNECTION_RESET`, proxy) — bunun
       yerine `dist/assets/*.css` ile birebir DOM harness'i kurulup
       ölçüldü. Yerel `dist`i olduğu gibi servis etmek işe YARAMAZDI:
       Supabase env'i olmadan `UserMenu` hiç render edilmiyor.
     - **Test:** yeni bir regresyon testi iki boşluğu da ölçüyor
       (12/12); düzeltmeden önce GERÇEKTEN düştü (`Expected: <12>,
       Actual: <24.0>`).
     - Doğrulama: `flutter analyze` temiz; tam takım **363/363** yeşil
       (362'den +1). Web'e dokunulmadı.
     - **CI bu PR'da KIRMIZI döndü ama sebebi bu değişiklik DEĞİLDİ** —
       aşağıdaki flake; aynı commit'te düzeltildi.

   - ✅ **Parça 74 — sqflite timer flake'i geri döndü, bu kez YANLIŞ YERE
     pay tanındığı için (13 Ağustos 2026, `online_game_chat_test.dart`):**
     Parça 73'ün PR'ında (#245) CI'ın `Analiz + testler` işi düştü:
     `361 tests passed, 2 failed`. Düşen ikisi de
     `online_game_chat_test.dart`'ın "gerçek depo" grubundaydı ve hata
     Parça 11/13/64'ten tanıdık: *"A Timer is still pending even after the
     widget tree was disposed."*
     - **Benim diff'imle ilgisi yoktu** (yalnızca `setup_screen*`
       dosyalarına dokunulmuştu) ve bir önceki koşuda (#109) aynı testler
       geçmişti — yani flake.
     - **Ama kör bir "yeniden koş" doğru cevap değildi:** CI'ın yığın izi
       payın YANLIŞ YERDE olduğunu gösterdi. Testlerin sonundaki 200ms'lik
       `runAsync` payı, testteki yoruma göre modal açılışındaki
       `_markChatReadTo` yazması için konmuştu; oysa iz
       `_loadChat` → `_seedInitialUnread` → `ChatReadStore.markRead`'i
       işaret ediyordu — **EKRAN AÇILIŞINDA** başlayan başka bir yazma.
       Yüklü bir runner'da o yazma `pumpScreen`den sonra sarkıyor ve
       sondaki tek pay ona yetmiyor.
     - **Düzeltme sayıyı şişirmek değil, payı doğru noktaya koymak:**
       dosyaya ortak bir `drainRealIo(tester)` yardımcısı eklendi
       (`setup_cloud_test.dart`'takiyle aynı ad/desen), elle yazılmış iki
       bekleyiş ona çevrildi ve **`pumpScreen`den hemen sonra da**
       çağrıldı. Yani pay artık her İKİ yazma noktasının ardında.
     - **Doğrulama sınırı (Parça 64'ün aynısı):** flake yerelde hiç
       tekrarlamıyor (tam takım 363/363 yeşil), yalnızca CI'ın paylaşımlı
       runner'ında görülüyor — negatif eş kurulamaz, gerçek kanıt CI'ın
       yeşile dönmesi.

   - ✅ **Parça 75 — "Yükleniyor…" TERMİNAL bir duruma dönebiliyordu:
     senkronun herhangi bir adımı fırlarsa liste hiç çizilmiyordu
     (13 Ağustos 2026, `setup_screen.dart`):** Kullanıcı cihazda bildirdi:
     *"Ironman YZ tabına geçince 'yükleniyor' takılı kaldı."*
     - **Önce veri kontrol edildi, koda dalınmadı:** canlıda Ironman'ın
       `local_game_saves` satırı SIFIR — yani başarılı bir liste boş liste
       dönmeliydi ve ekranda "Devam eden bir Yapay Zeka oyunun yok."
       yazmalıydı. `CloudSaveRepo.list()` boş sonuçta null DÖNMÜYOR ve
       `TableWriteQueue` kilitlenmiyor (ikisi de kaynaktan doğrulandı), yani
       "sunucu boş döndü, ekran bunu gösteremedi" tek başına bir açıklama
       değildi.
     - **Kök sebep YAPISAL, web ile karşılaştırınca çıktı:** web'de misafir
       migrasyonu, `flushPendingGames` ve `refreshCloudSaves` ÜÇ AYRI
       effect — biri patlarsa ötekiler yine koşar. Port hepsini tek bir
       `_syncCloud` içinde ARDIŞIK `await`lerle koşturuyor; liste adımından
       ÖNCEKİ korumasız bir `await` fırlarsa fonksiyon oracıkta kesiliyor,
       `_cloudSaves` sonsuza dek `null` kalıyor ve `null` tam olarak
       "Yükleniyor…" demek. Üstelik çağrı `unawaited` olduğundan hata
       hiçbir yere düşmüyordu — ekranda tek iz kalıcı spinner.
     - **Düzeltme — izolasyon, yeni bir mekanizma değil:** senkronun dört
       riskli adımı (misafir migrasyonu, `services.games` Future'ı,
       liste+ceza, `pendingMirrorCount`) artık kendi `try`ında; her biri
       loglanıp AKIŞ DEVAM EDİYOR. Yani hangi adım patlarsa patlasın liste
       çiziliyor — web'in "ayrı effect" garantisinin tek fonksiyondaki
       karşılığı. Sıra/semantik değişmedi.
     - **Test — negatif eş doğrulamasıyla:** `setup_cloud_test.dart`'a
       `pendingMirrorCount`u fırlatan bir sahte repo (`ThrowingMirrorCountRepo`)
       + boş bir gateway ile yeni bir test: "Yükleniyor…" YOK, "Devam eden
       bir Yapay Zeka oyunun yok." VAR. Adımın `try`ı kaldırılınca test
       GERÇEKTEN kullanıcının semptomunu üretti (`Found 1 widget with text
       "Yükleniyor…"`), geri konunca yeşile döndü. Test yardımcısına
       (`services`/`pumpSetup`) opsiyonel bir `cloud` parametresi eklendi —
       verilmezse mevcut 10 çağrı yeri BİREBİR aynı.
     - **Bilinçli sınır:** hangi adımın gerçekten patladığı cihazda
       BİLİNMİYOR (log toplanamadı) — düzeltme bir adımı onarmıyor,
       "herhangi bir adımın patlaması ekranı kilitlemesin" sınıfını
       kapatıyor. Aynı belirti tekrarlarsa Setup'ın teşhis satırı (Parça 45)
       ve `debugPrint` çıktısı ilk bakılacak yer.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 364/364
       yeşil** (363'ten +1). `kelimeki_core`'a hiç dokunulmadı.

   - ✅ **Parça 76 — logo ile GİRİŞ/avatar satırı arası: bu sefer WEB porta
     uyduruldu (13 Ağustos 2026, `Setup.tsx` + `setup_screen.dart`):**
     Kullanıcı: *"App'de kelimeki logosuyla avatar satırı arası ideal şu
     anda. Ama web'de ekstra bir boşluk var. Web'i app gibi yap."*
     - **Ölçüm (derlenmiş CSS + Chromium, 420/1000):** web'de GİRİŞ
       butonunun altı ile logonun üstü arası **12**; portta (o an canlıda
       olan `main` derlemesi) **4**. Fark 8px.
     - **Parça 73 ile ÇAKIŞIYORDU ve fark edilmeseydi sessiz bir sapma
       doğuracaktı:** dün bu boşluğu portta 4'ten 12'ye çıkarıp web'e
       uydurmuştum (o PR henüz merge edilmediği için kullanıcının cihazda
       gördüğü hâlâ 4'tü). Yalnızca web'i 4'e çekseydim, #245 merge olunca
       port 12'ye çıkıp ayrışma TERS yönde geri gelecekti. Bu yüzden
       ikisi birden 4'e sabitlendi: portun `SizedBox(height: 12)`i 4'e
       geri alındı, web `-mt-3` → **`-mt-5`** (kabın `py-6`sından 20
       yiyor). **Parça 73'ün ASIL konusu olan ÜST boşluk (24 → 12)
       aynen duruyor** — o web'e uyum, bu ondan ayrı bir sayı.
     - **Yön istisnası bilinçli** (Parça 42'nin emsali): kural "web
       kanonik" ama kullanıcı açıkça portun görünümünü seçtiğinde web
       değişir — amaç estetik dayatma değil, sessiz ayrışmayı önlemek.
     - **Test — negatif eş doğrulamasıyla:** Parça 73'ün testi (`GİRİŞ
       satırının üstü/altı web ile aynı`) 12/4'e güncellendi; port 12'ye
       geri çevrilince GERÇEKTEN `Expected: <4> Actual: <12.0>` ile
       düştü, 4'e alınınca yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 364/364 yeşil**;
       web `npm run lint` + `npm run build` temiz. `kelimeki_core`'a hiç
       dokunulmadı.
     - **Doğrulama sınırı:** iki tarafın yan yana görsel teyidi
       kullanıcıdan bekleniyor (web canlıya, port GitHub Pages'e deploy
       olduktan SONRA — ikisi farklı zamanlarda yayına girdiğinden ara
       dönemde fark görünebilir).

   - ✅ **Parça 77 — logo altındaki paragraf 5 satır, web'de 4: Material 3'ün
     0.25 tracking'i (13 Ağustos 2026, `setup_screen.dart`):** Kullanıcı iki
     ekran görüntüsünü yan yana koydu — app'te "Ama" alt satıra düşüyordu.
     - **Kök sebep, "Sonraya Bırakılan İşler"de zaten yazılı olan borç:**
       `ThemeData(useMaterial3: true)` → `bodyMedium.letterSpacing = 0.25`,
       ve `letterSpacing` YAZMAYAN her `Text` bunu miras alıyor (widget'ın
       kendi style'ı o alanı `null` bıraktığında `Text` DefaultTextStyle
       ile MERGE ediyor). Web'de `text-xs font-mono` hiçbir letter-spacing
       kurmuyor (hesaplanan değer `normal`). 0.25 × ~57 karakter ≈ 14px →
       satır taşıyor. Ölçüldü: app 80px/5 satır, web 64px/4 satır.
     - **Düzeltme cerrahi:** paragraf + iki link + ayraç `letterSpacing: 0`.
       Global çözüm (temanın `textTheme`'ini 0'a çekmek) hâlâ doğru yol ama
       TÜM ekranların metin genişliğini değiştireceğinden ayrı bir ölçüm/
       ekran görüntüsü turu istiyor — o madde listede kaldı.
     - **Ayraç DEĞİŞTİRİLMEDİ, ölçülüp bırakıldı:** web `gap-2` (8+8) ile
       ayrılmış bir `·` kullanıyor (19.67), portun boşluklu `' · '`i 20.20 —
       0.5px fark; yeniden yapılandırmak kazanç değil risk olurdu.
     - **ÖLÇÜM TUZAĞI (bu turda iki kez düşüldü, ikisi de yakalandı):**
       (1) harness `file://` üzerinden açılınca Chromium woff2'yi CORS ile
       engelleyip SESSİZCE yedek monospace'e düşüyor — `getComputedStyle`
       hâlâ "Space Mono" diyor, ama ölçülen advance 0.602 (DejaVu), gerçek
       Space Mono 0.612. Çözüm: `python3 -m http.server` ile servis et ve
       canvas `measureText` ile advance'i DOĞRULA. (2) Yalnızca 400
       ağırlığını `@font-face` edip 700'ü unutunca linkler yedek fontla
       ölçülüyordu; 700 eklenince web değerleri portunkilerle birebir
       oturdu (94.25 / 121.19). İlk (hatalı) ölçüm "port %1.6 geniş" gibi
       görünen sahte bir fark üretmişti — düzeltmeye kalksam gerçek bir
       hatayı ÜRETECEKTİM.
     - **Mevcut test bu sapmayı NEDEN göremedi:** "Setup başlık bloğu"
       testi `fontSize`/`height` DEĞERLERİNİ kontrol ediyordu, ikisi de
       doğruydu; kırılan şey SONUÇTU (satır sayısı). Parça 72'nin dersinin
       birebir tekrarı. Yeni test render edilmiş yüksekliği (64 = 4×16) ve
       üç metnin EFEKTİF `letterSpacing`'ini ölçüyor; eski test de yerinde
       kaldı (o 390px'lik dar ekranı kapsıyor, yenisi 428px içerik için
       geniş ekran).
     - **Negatif eş:** `setup_screen.dart` `git stash`lenince test GERÇEKTEN
       `Expected: <64> Actual: <80.0>` ile düştü — yani kullanıcının
       bildirdiği semptomun ta kendisi.
     - Doğrulama: `flutter analyze` temiz, **tam takım 365/365 yeşil**
       (364'ten +1). Web'e HİÇ dokunulmadı (yalnızca ölçüm kaynağı olarak
       kullanıldı); `kelimeki_core`'a dokunulmadı.

   - ✅ **Parça 78 — M3 tracking'i tek kaynaktan kapatıldı; testler artık
     ÜRÜN temasıyla render ediyor (13 Ağustos 2026, yeni `ui/theme.dart` +
     `app.dart` + 25 test dosyası):** Parça 77'de Setup'ın bloğu tek tek
     yamanmıştı; kullanıcı "global letterSpacing düzeltmesini de yap"
     deyince "Sonraya Bırakılan İşler"deki borç kapatıldı.
     - **`kelimekiTheme()` (yeni `lib/src/ui/theme.dart`)** ürünün temasını
       tek yerde tanımlıyor; `zeroTrackingTextTheme` 15 metin stilinin
       (+`primaryTextTheme`) `letterSpacing`'ini 0'a çekiyor. YALNIZCA
       tracking sıfırlanıyor — punto/kalınlık/renk Material'ın kendi
       değerinde kalıyor (onlar zaten ekran ekran açıkça veriliyor).
     - **Asıl mesele tema DEĞİL, testlerin temayı TAKLİT ETMESİYDİ:** 25
       test dosyası kendi `ThemeData(fontFamily: 'SpaceGrotesk', …)`ını
       kuruyordu, yani `app.dart`'ı düzeltmek testlerde HİÇBİR ŞEY
       değiştirmezdi. 66 çağrı yeri `kelimekiTheme()`e çevrildi; bu aynı
       zamanda gerçek `colorScheme`i de testlere getirdi (Parça 71'in
       dersi: gerçek ekranı ölç, taklidini değil).
     - **Yeni `test/theme_test.dart` üç şeyi kilitliyor** (`color_tokens_test`
       deseninin tipografi karşılığı): `letterSpacing` yazmayan bir `Text`
       gerçekten 0 alıyor mu; temanın 15 stili de sıfır mı; ve **hiçbir
       test dosyası kendi `ThemeData`sını kurmuyor mu** — üçüncüsü olmadan
       bir sonraki oturum sessizce eski desene döner.
     - **Negatif eş:** `kelimekiTheme()`in `copyWith`i kaldırılınca ilk iki
       test GERÇEKTEN düştü (`Expected: <0> Actual: <0.25>` ve
       `displayLarge tracking taşıyor`), geri konunca yeşile döndü.
     - **Parça 77'nin yerel `letterSpacing: 0`ları BİLEREK duruyor** —
       artık gereksizler ama niyeti yerelde okunur kılıyorlar.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 368/368
       yeşil** (365'ten +3). Ekran görüntüleri yeniden üretilip gözle
       incelendi (Setup formu, Skor Kartı, Arkadaşlar modalı) — tema
       değişiminin bozduğu bir yer yok. `kelimeki_core`'a ve web'e hiç
       dokunulmadı.
     - **Doğrulama sınırı:** tracking kalkınca metinler ~%1-2 daralıyor;
       testler geometriyi (428 içerik, 44px sekme, 64px paragraf…) hâlâ
       doğruluyor ama TÜM ekranların cihazda gözle kontrolü kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 0.5'e madde eklendi.

   - ✅ **Parça 79 — giriş alanlarının 8 kopyası tek kaynağa indi; web'in
     GERÇEK puntosu 14 değil 16'ymış (13 Ağustos 2026, yeni
     `ui/form_input.dart` + 8 dosya):** Borç listesinin ikinci (ve son
     mobil) maddesi kapandı.
     - **Web'de bu stil TEK bir sınıf dizisi** ve dokuz bileşende BİREBİR
       aynı: `w-full bg-bg border border-border rounded-md px-3 py-2
       text-sm text-text outline-none focus:border-accent`. Port onu sekiz
       dosyaya kopyalamış ve kopyalar ayrışmıştı: dolgu **8 ya da 10**,
       punto **16 ya da tema varsayılanı**, dolgu rengi **beyaz ya da
       `_bg`**. Parça 54'teki renk sürüklenmesiyle aynı sınıf.
     - **ÖLÇÜM bir varsayımı düzeltti:** Parça 56 bu maddeyi yazarken
       puntoyu `text-sm` = 14 sanıyordu. Gerçekte `index.css`teki iOS zoom
       kuralı (`input, textarea, select { font-size: 16px !important }`)
       sınıfı EZİYOR — web'de görünen punto **16**. Ölçülen web değerleri:
       yükseklik **38** · punto **16** · satır **20** · dolgu **8/12** ·
       çerçeve 1px `#DCE2EA` (odakta `#2563EB`) · yarıçap 6 · zemin beyaz.
     - **Dikey dolgu 9, 8 DEĞİL — ve bu bir sihirli sayı değil:** CSS'te
       çerçeve kutunun DIŞINA eklenir (20+16+2 = 38); Flutter'da
       `OutlineInputBorder` çerçeveyi kutunun İÇİNE boyar, yani 8 dolguyla
       dış ölçü 36 kalıyordu. 1px çerçeve payı eklenince dış kutu 38 VE
       çerçevenin içindeki boşluk web'deki gibi 8 oluyor (ölçüldü;
       `kInputHeight` sabiti bunu adlandırıyor).
     - **`test/theme_test.dart` iki yeni kontrol aldı:** alanın gerçekten
       38 yüksekliğinde ve 16/20 puntoda render edildiği + **`lib/` altında
       ham `InputDecoration(` kurucusu kalmadığı** (regex `kInputDecoration(`
       çağrılarını yakalamıyor). İkincisi olmadan bir sonraki oturum yeni
       bir kopya açar ve kimse fark etmez.
     - **Negatif eş:** dolgu 8'e çekilince yükseklik testi GERÇEKTEN
       `Expected: <38.0> Actual: <36.0>` ile düştü; tarama regex'i
       gevşetilince (ham `contains`) sekiz dosya listelenip düştü.
     - **Temizlik:** kopyalarla birlikte ölü kalan yerel `_border`/`_accent`/
       `_text`/`_bg` sabitleri ve `reset_password_modal`ın yerel `border()`
       yardımcısı da silindi (analyze temiz).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 370/370
       yeşil** (368'den +2). Ekran görüntüleri yeniden üretilip gözle
       incelendi (kayıt formu, sohbet kutusu) — alanlar tek tip.
       `kelimeki_core`'a ve web'e hiç dokunulmadı.
     - **Doğrulama sınırı:** klavye açıkken gerçek cihazda alanların
       görünümü (özellikle çok satırlı sohbet/şikayet kutuları) gözle
       kontrol edilmeli — `mobile/TESTING.md` bölüm 0.5'e madde eklendi.

   - ✅ **Parça 80 — "+ Yeni …" butonu ve alt sekme satırı: üç boşluk da
     web'den dardı (13 Ağustos 2026, `setup_screen.dart`,
     `live_games_tab.dart`):** Kullanıcı bildirdi — *"yeni oyun aç butonu
     ile altındaki devam edenler butonları arasındaki fark web'den daha
     dar"*.
     - **Web'de bu boşlukların HİÇBİRİ elle yazılmıyor:** kapsayıcının
       `gap-5`i (20) butonla sekme satırı ve sekme satırıyla içerik
       arasını, sekme satırının `gap-2`si (8) de sekmelerin kendi arasını
       veriyor. Port üçünü de kendi sayılarıyla yazmıştı: **12 / 6 / 12**.
     - **Aynı turda ikinci bir sapma:** butonun kendisi. Web `text-sm`
       (14/20) + `py-2.5` → tam **40**; Setup onu 44'lük bir `SizedBox`'a
       sarıyordu, `LiveGamesTab` ise 13 punto + 12 dolguyla ~39.6 veriyordu
       — yani iki kardeş ekran birbirinden DE ayrışmıştı. İkisi de web'in
       değerlerine çekildi (`fontSize: 14`, `lineHeight: 20/14`,
       `padding: vertical 10`).
     - Ölçüm derlenmiş CSS + Chromium'da: buton **40** · buton→sekme **20**
       · sekmeler arası **8** · sekme→içerik **20** · sekme kutusu **38.5**.
     - **Test tuzağı — sekme METNİNDEN boşluk ölçme:** sekmeler `flex-1`
       ve metin ortalı olduğundan iki METİN arasındaki mesafe (101.6) kutu
       aralığıyla (8) hiç ilgili değil. Test kutuyu buluyor
       (`find.ancestor(... Stack).first`), metni değil.
     - **Negatif eş:** `setup_screen.dart` `git stash`lenince test
       GERÇEKTEN `Expected: <40> Actual: <44.0>` ile düştü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       371/371 yeşil** (370'ten +1). `kelimeki_core`'a ve web'e
       dokunulmadı.

   - ✅ **Parça 81 — yuvarlak avatarın ink vurgusu KAREYDİ: `PopupMenuButton`
     `borderRadius`unun varsayılanı yok (13 Ağustos 2026,
     `account_button.dart`):** Kullanıcı bildirdi — *"avatarın üzerine mouse
     ile gelince ve basınca yuvarlak avatar etrafında karenin köşelerini
     görebiliyorum. Web'de böyle bir şey olmuyor."*
     - **Web kaynağı önce okundu (kuralın ilk adımı) ve farkı verdi:**
       `UserMenu.tsx`'in avatar butonu `rounded-full active:scale-95
       transition-transform ring-offset-2 focus:outline-none` — yani
       **hiçbir zemin vurgusu YOK**, tek geri bildirim basınca küçülme.
     - **Kök sebep SDK kaynağından doğrulandı, tahmin edilmedi:**
       `PopupMenuButton`, `child` verildiğinde onu
       `InkWell(borderRadius: widget.borderRadius, …)` ile sarıyor
       (`popup_menu.dart:1712`) ve `borderRadius` alanının **varsayılan
       değeri yok** (satır 1350) → `null` → ink DİKDÖRTGEN. Hover/focus/
       basılı katmanı 32×32 kutuyu boyayıp dairenin dışındaki dört köşeyi
       görünür kılıyordu.
     - **ÖLÇÜLDÜ (geçici probe, sonra silindi):** `RepaintBoundary` ile
       yakalanan karede, avatarın kutusunda dairenin BELİRGİN dışında
       (yarıçap + 1.5px anti-alias payı) kalan beyaz olmayan piksel sayısı —
       dokunulmamış **0**, basılı **120** (`#efefef`, tam köşeden başlıyor:
       `(0,0)`, `(1,0)`…). Düzeltmeden sonra basılı **0**.
     - **İlk probe YANLIŞ "0" verdi ve bu kendi başına bir ders:** ink
       efektleri en yakın `Material` ATA'sının render nesnesi tarafından
       çizilir; `RepaintBoundary` o Material'ın ALTINDAysa yakalanan karede
       ink HİÇ görünmez. Boundary'nin İÇİNE kendi `Material`'ını koyunca
       ölçüm gerçeği gösterdi. **Bir "temiz" piksel ölçümü, ölçtüğün
       katmanın gerçekten o pikselleri boyayan katman olduğunu
       kanıtlamadan bir şey kanıtlamaz.**
     - **Düzeltme:** `borderRadius: BorderRadius.circular(avatarSize / 2)`
       — kutu kare (KAvatar `size × size`; `dot: true` iken bile `Stack`
       konumlandırılmamış çocuğuna göre boyutlandığından kutu büyümüyor),
       dolayısıyla yarıçap = yarım kenar tam daire veriyor.
     - **Kapsam taraması (Parça 54'ün dersi — mekanizmanın DİĞER
       örneklerini ara):** `PopupMenuButton` kod tabanında TEK yerde
       (`account_button.dart`). Öteki yuvarlak dokunma hedefleri risksiz —
       `IconButton` (✕, dişli, şifre göster) Material'da zaten
       `highlightShape: BoxShape.circle`, `_relationIconButton`
       (`friends_modal.dart`) hiç ink'siz `GestureDetector`, `InkWell`'in
       tek doğrudan kullanımı da dikdörtgen olması gereken `ActionSheet`
       satırı.
     - **Kalan bilinçli fark:** web'de HİÇ overlay yok (yalnızca
       `active:scale-95`); portta artık DAİRESEL bir Material overlay'i
       var. Kaldırmak yerine daireye çekmek seçildi — bildirilen hata
       "köşeler görünüyor"du ve dokunmatikte hiçbir geri bildirim
       bırakmamak web'in scale-95'ini de port etmeyi gerektirirdi (ayrı
       bir iş). Ayrışma burada kayıtlı.
     - **Test YAPISAL, gerekçesiyle birlikte:** basılı durumu piksel piksel
       yakalayan bir test bu binding'de SONLANMIYOR (menü açılış animasyonu
       + M3 `InkSparkle` `pumpAndSettle`'ı asıyor; `Timeout` ile
       doğrulandı). Bu yüzden kalıcı test `PopupMenuButton.borderRadius`'u
       VE aynı yarıçapın gerçekten `InkWell`'e indiğini sabitliyor —
       Parça 34'ün deseninin aynısı (bir kez piksel ölç, kalıcı testte
       sözleşmeyi pinle).
     - **Negatif eş:** `account_button.dart` `git stash`lenince test
       GERÇEKTEN `Expected: not null / Actual: <null>` ile düştü, geri
       konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       372/372 yeşil** (371'den +1). `kelimeki_core`'a ve web'e
       dokunulmadı.
     - **Doğrulama sınırı:** cihazda (gerçek trackpad hover + dokunuş)
       görsel teyit kullanıcıdan bekleniyor — `mobile/TESTING.md` bölüm
       2'ye madde eklendi.

   - ✅ **Parça 82 — avatar DEĞİŞTİRME 20 Temmuz'dan beri kırıkmış; port
     hatası DEĞİL, sunucu politikası (13 Ağustos 2026,
     `avatars_owner_read_for_upsert` migration'ı):** Kullanıcı bölüm 12'yi
     koşarken fotoğraf güncellemede `StorageException(message: new row
     violates row-level security policy, statusCode: 403)` aldı.
     - **Parça 14'ün doğrulama sınırı KAPANDI** ("gerçek Storage upload'ı
       cihazda doğrulanmalı") — ve kapanır kapanmaz gerçek bir hata buldu.
     - **Önce web kaynağı okundu, sonra kod karşılaştırıldı:** portun
       `AuthService.uploadAvatar`'ı web `uploadAvatar` ile birebir (aynı
       yol `<uid>/avatar.<ext>`, aynı `upsert: true`, aynı MIME/boyut
       kontrolü). Yani kodda fark yoktu — sorun sunucudaydı.
     - **Kök sebep ve tam zincir kök `CLAUDE.md`'de** ("Profil fotoğrafı
       yükleme" maddesi): `security_hardening` (20 Temmuz) `avatars_public_read`
       SELECT politikasını "kova zaten public, gereksiz" diye düşürmüş;
       gerekçe okuma için doğru, ama `upsert` = `INSERT ... ON CONFLICT DO
       UPDATE` ve bu, çakışan satırın GÖRÜNÜR olmasını gerektiriyor.
     - **Ölçüldü, tahmin edilmedi:** üretimde geri alınan transaction'larla
       (a) sahibi olan kullanıcı kendi satırını göremiyor (`count = 0`),
       (b) hata BİREBİR yeniden üretildi (`ERROR: 42501: new row violates
       row-level security policy for table "objects"`), (c) düzeltmeyle
       hem üzerine yazma hem yeni uzantıyla ilk yükleme geçti, başkasının
       klasörü hâlâ 0 satır.
     - **Teşhis sırasında YAPTIĞIM HATA, kayda geçsin:** ilk denemede RLS'i
       simüle etmek için yazdığım `DO $$ ... $$` bloğunda `set local role
       authenticated` YOKTU — blok yükseltilmiş rolle koştu, RLS hiç
       uygulanmadı ve üretime GERÇEK bir sahte satır (`avatar.png`) yazdı.
       Fark edilip silindi (`storage.allow_delete_query` ile; storage
       tabloları doğrudan silmeye karşı trigger'la korumalı), ama
       `avatar.jpg`'nin `updated_at`'i bugüne kaydı (kozmetik, uygulama o
       alanı okumuyor). **Ders: RLS'i "simüle eden" bir sorgu, rolü
       gerçekten değiştirmiyorsa hiçbir şey simüle etmez — üstelik
       transaction'sız çalışırsa üretime yazar. `begin; set local role
       authenticated; set local request.jwt.claims = …; … rollback;`
       kalıbından şaşma.**
     - **`mobile/` DIŞINDA dosya değişti** (`supabase/migrations/`,
       `CLAUDE.md`) → kök `CLAUDE.md` aynı commit'te güncellendi (Parça
       Bitirme Kontrol Listesi madde 1).
     - ~~**Doğrulama sınırı:** düzeltme SQL seviyesinde kanıtlandı; gerçek
       istemciyle uçtan uca teyit bekleniyor~~ — **13 Ağustos 2026'da
       KAPANDI: kullanıcı hem uygulamada hem web'de fotoğrafı birkaç kez
       değiştirdi, 403 bir daha görülmedi.** Yani düzeltme yalnızca SQL'de
       değil gerçek storage-api yolunda da çalışıyor.

   - ✅ **Parça 83 — avatar giriş sınırı 10 MB, ama SAKLANAN küçültülüyor
     (13 Ağustos 2026, yeni `util/avatar_image.dart`, `avatar_picker.dart`,
     `auth_service.dart`, `account_settings_modal.dart` + web
     `api.ts`/`AccountSettingsModal.tsx`):** Kullanıcı Parça 82'nin
     düzeltmesinden hemen sonra *"2 Mb biraz az kalıyor, 2'nin altında
     resim bulamadım"* dedi. Ölçülen gerçek: iPhone HEIC 1.5-3 MB, iPhone
     JPEG 2-4 MB, Android 50-200MP 3-12 MB — 2 MB gerçekten dardı.
     - **Sınırı yükseltmek TEK BAŞINA yanlış çözüm:** 10 MB'lık bir
       orijinali, hiçbir zaman 96 px'den büyük gösterilmeyen bir avatar
       için depolamak ve her açılışta indirmek israf. 10 MB artık yalnızca
       "ne SEÇEBİLİRSİN" sınırı; saklanan her zaman küçültülmüş hâli
       (~50-150 KB). Kullanıcının sorusuna ("storage problemi olmayacak
       değil mi?") cevap: hayır — yükleme küçültmeden SONRA yapılıyor.
     - **Bellek tuzağı — "önce çöz, sonra küçült" YANLIŞ:** 48MP'lik bir
       görselin ham RGBA'sı ~190 MB. `ui.instantiateImageCodec`'in
       `targetWidth`'i çözmeyi ZATEN hedef boyutta yapıyor, tepe bellek
       küçük kalıyor. Ölçekleme bu yüzden kodek seviyesinde.
     - **İKİ KATMAN, çünkü `image_picker` her yerde aynı davranmıyor
       (kaynaktan doğrulandı, tahmin değil):** native'de
       `pickImage(maxWidth/maxHeight/imageQuality)` yeniden boyutlandırmayı
       platforma yaptırıp küçük bir JPEG döndürüyor; **Flutter web'de bu üç
       parametre sessizce yok sayılıyor** — `image_picker_for_web`
       kaynağında birebir yazılı ("not supported on the web ... silently
       ignored"). GitHub Pages test ortamı tam olarak o dal olduğundan
       ikinci katman (`shrinkAvatarIfNeeded`) şart. İkinci katman yalnızca
       400 KB eşiği aşılınca çalışıyor — native'de çalışsaydı küçücük bir
       JPEG'i PNG'ye çevirip BÜYÜTÜRDÜ (`dart:ui` yalnızca PNG/rawRgba
       yazabiliyor).
     - **Kare kırpma BİLİNÇLİ olarak yok:** avatar iki platformda da
       dairesel `cover` ile gösteriliyor, kırpma görüntüleme anında oluyor;
       web'in `uploadAvatar`'ı da hiç kırpmıyor.
     - **Bozuk/çözülemeyen görselde orijinal döner** — küçültme bir
       iyileştirme, yükleme yolunu kırmamalı; gerçek MIME/boyut doğrulaması
       zaten `AuthService.uploadAvatar`'da.
     - **Test — 4 birim + 1 kablo testi:** eşik altı AYNEN geçer (kodek hiç
       çağrılmaz), eşik üstü küçülür ve hedef kenar kodeke iletilir, kodek
       patlarsa orijinal döner, yeniden kodlama büyütürse orijinal korunur;
       ayrıca modal testi seçilen görselin YÜKLEMEDEN ÖNCE küçültme
       katmanından geçtiğini doğruluyor. Negatif eş: modaldeki çağrı geri
       alınınca test derleme hatasıyla düştü (parametre yok — kaba ama
       kesin: kablo yük taşıyor).
     - **`mobile/` DIŞINDA dosya değişti** (`src/lib/api.ts`,
       `src/components/AccountSettingsModal.tsx`, `CLAUDE.md`) → kök
       `CLAUDE.md` aynı commit'te güncellendi; web `npm run lint` temiz.
     - ~~**Doğrulama sınırı:** gerçek galeriden fotoğraf seçip saklanan
       boyutun küçüldüğünü görmek cihazda doğrulanmalı~~ — **13 Ağustos
       2026'da KAPANDI: kullanıcı iki platformda da birkaç kez yükleme
       yaptı, sorun çıkmadı.** Kontrol maddeleri (özellikle "saklanan
       dosya ~50-150 KB olmalı") `mobile/TESTING.md` bölüm 12 ve kök
       `TESTING.md` bölüm 9.5'te duruyor — ilerideki bir regresyon için.
       **Aynı gün kovadan ÖLÇÜLDÜ:** 82 KB ve 123 KB, ikisi de
       `image/jpeg` — bant tuttu ve mimetype küçültmenin gerçekten
       koştuğunu kanıtlıyor (koşmasaydı orijinal PNG/HEIC türü kalırdı).
       Ayrıntı + Parça 82'nin RLS düzeltmesini de doğrulayan zaman
       damgaları: kök `CLAUDE.md`, "Profil fotoğrafı yükleme".

   - ✅ **Parça 84 — paylaşımda tahta görseli HİÇ gitmiyordu: görselli dal
     web'de her seferinde patlıyor, WhatsApp da linkten sitenin GENEL
     og:image kartını üretiyordu (13 Ağustos 2026, `share_board.dart`):**
     Kullanıcı bölüm 6'yı koşarken iki paylaşımı yan yana koydu —
     *"App'te paylaş board yerine jenerik Kelimeki gösterimini gönderiyor,
     web'de oyunun görselini. App'de web gibi paylaşmalı."*
     - **Web kaynağı önce okundu (kuralın ilk adımı):**
       `GameHistoryModal.tsx` `handleShare` PNG'yi `new File([blob],
       'kelimeki.png')` ile kurup `navigator.canShare({files})` dalından
       paylaşıyor. Yani web GERÇEKTEN dosya paylaşıyor; app'in gönderdiği
       jenerik kart, metin+link yedeğinin (Parça 35) doğal sonucu —
       WhatsApp linke bakıp `index.html`'in site geneli `og:image`'ini
       çiziyor. Yani belirti "yanlış görsel" değil, **görselin HİÇ
       gitmemesi**.
     - **Kök sebep:** portun görselli dalı `path_provider`'ın
       `getTemporaryDirectory()`si + `dart:io` `File` ile geçici dosya
       yazıyordu; ikisi de Flutter web'de çalışmıyor → dal her seferinde
       fırlıyor, `catch` metin yedeğine düşüyordu. Parça 35'te eklenen o
       yedek burada hatayı GİZLEDİ: paylaş sayfası açıldığı için akış
       "çalışıyor" görünüyordu.
     - **Düzeltme:** dosya yazımı bizden kütüphaneye taşındı —
       `XFile.fromData(png, mimeType: 'image/png', name: 'kelimeki.png')`
       + `fileNameOverrides: const ['kelimeki.png']`. Web'de share_plus
       baytları `readAsBytes()` ile alıp `navigator.share({files})`e
       veriyor (web'in AYNI dalı); native'de path boş kaldığından
       share_plus'ın kendisi geçici dizine yazıyor
       (`method_channel_share.dart`, `_getFile` — kaynaktan doğrulandı).
       `fileNameOverrides` ŞART: `cross_file`'ın io uygulaması `name`i YOK
       SAYIYOR (paket belgesinde yazılı), onsuz native'de ad kayboluyor.
       Bu kod yolu artık `path_provider`a hiç dokunmuyor (`dart:io` importu
       da düştü).
     - **`downloadFallbackEnabled: false` (yalnızca web'de anlamlı):**
       varsayılan `true` iken `canShare({files})` false dönerse share_plus
       paylaşmak yerine PNG'yi sessizce İNDİRİYOR; web'in kendi yedeği ise
       metin+link. `false` ile o durumda fırlayıp bizim yedeğimize
       düşüyoruz — zincir web `handleShare` ile hizalandı.
     - **GERÇEK CanvasKit derlemesinde ÖLÇÜLDÜ (Parça 18/27'nin yöntemi;
       tahminle kapatılmadı):** minik bir web harness'i derlenip
       Playwright/Chromium'da koşuldu —
       `getTemporaryDirectory()` **FIRLATTI**, `File(...).writeAsBytes()`
       **"Unsupported operation: _Namespace"** ile fırlattı,
       `XFile.fromData(...)` **ÇALIŞTI** (11 bayt, mime/name korunuyor) ve
       share_plus web eklentisinin `prepareData`'sı **files DOLU** bir
       `ShareData` üretti — yani `navigator.share({files})` dalı artık
       gerçekten besleniyor. Harness ve `build/webprobe` iş bitince
       silindi.
     - **Test — negatif eş doğrulamasıyla:** `share_recent_test.dart`'a
       yeni bir test; path_provider kanalı gerçek bir geçici dizine
       mock'lanıp kanala giden `paths`/`mimeTypes`/`text` ve DİSKTEKİ
       baytlar doğrulanıyor (`.../kelimeki.png`, `image/png`, birebir PNG).
       `fileNameOverrides` kaldırılınca test GERÇEKTEN düştü, geri konunca
       yeşile döndü. Parça 35'in yedek-zincir testi de hâlâ geçiyor
       (artık `MissingPluginException` bizim kodumuzdan değil share_plus'ın
       `_getFile`'ından geliyor — sonuç aynı, zincir sağlam).
     - **`flutter test` bu hatayı YAPISAL OLARAK göremez** (native VM'de
       `dart:io` çalışır, eski kod da testi geçerdi) — bu yüzden kanıt
       tarayıcı ölçümü, testin işi sözleşmeyi (veri destekli XFile + doğru
       ad/tip/bayt) kalıcı olarak pinlemek. Parça 18'in dersinin tekrarı.
     - **`path_provider` pubspec'te KALDI, bilinçli:** artık `lib/` altında
       hiçbir import yok, ama native'de geçici dosyayı yazan share_plus
       onu kullanıyor — yani bağımlılık kayboldu değil, bir katman aşağı
       indi. Sahip olduğumuz bir özelliğin gereksinimini örtük bırakmamak
       için bildirimde tutuldu.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       378/378 yeşil** (377'den +1). `kelimeki_core`'a ve web'e hiç
       dokunulmadı — `mobile/` DIŞINDA dosya değişmedi.
     - **Doğrulama sınırı:** gerçek paylaş sayfasında görselin gerçekten
       eklendiği (ve WhatsApp'ın jenerik kart yerine tahtayı gösterdiği)
       cihazda teyit edilmeli — `mobile/TESTING.md` bölüm 6 güncellendi.

   - ✅ **Parça 85 — aksiyon menüsünden ayrı "Vazgeç" paneli kaldırıldı
     (13 Ağustos 2026, `action_sheet.dart` + web `ActionSheet.tsx`):**
     Kullanıcı kararı — *"Bence kapat ve vazgeç aynı şey. Paylaş ve Kapat
     olsun sadece."*
     - **Önce web kaynağı okundu (kuralın ilk adımı) ve kapsam ölçüldü:**
       "Vazgeç" bir aksiyon DEĞİL, `ActionSheet` bileşeninin kendi ikinci
       paneliydi (iOS aksiyon menüsü geleneği) — çağıranlar yalnızca
       `Paylaş`/`Kapat` geçiyor. İki platformda da **tek kullanım yeri**
       var (`GameHistoryModal`ın tahta önizlemesi), yani paneli bileşenden
       düşürmek başka hiçbir ekranı etkilemiyor.
     - **Kullanıcının önermesi teknik olarak tam doğru değildi ama karar
       yine de sağlam:** "Kapat" tahta önizlemesini de kapatıyor, "Vazgeç"
       yalnızca menüyü kapatıp tahtayı açık bırakıyordu. Bu ayrım
       kullanıcıya hiç görünmüyordu (aynı boy/konumda iki nötr buton),
       nitekim aynı kullanıcı bir tur önce ikisinin de aynı şeyi yaptığını
       bildirmişti — ayrımı korumak için ikinci bir buton taşımak, kazandan
       çok karışıklık üretiyordu.
     - **Aksiyonsuz çıkış yolu KAYBOLMADI** (bu, kaldırmanın ön koşuluydu):
       mobilde `showModalBottomSheet`'in varsayılan `isDismissible`/
       `enableDrag`'i, web'de dış katmanın `onClick={onClose}`'u +
       `useModalA11y`'nin Escape'i. İkisi de `null` döndürdüğünden hiçbir
       `onSelect` çalışmıyor — yani "Vazgeç"in DAVRANIŞI duruyor, yalnızca
       butonu kalktı.
     - **İki platform AYNI PR'da** (dal `main` tabanlı, stranding riski
       yok — bkz. Parça Bitirme Kontrol Listesi madde 1). Tek taraflı
       kaldırmak, bu projenin en sık tekrarlayan hata sınıfını (sessiz
       web↔port ayrışması) yeniden üretirdi.
     - **Layout tuzağı:** kalan tek paneli saran `Column`
       (`crossAxisAlignment: stretch`) SİLİNMEMELİ — `ConstrainedBox`
       gevşek kısıt verdiğinden panel tek başına bırakılsa metin
       genişliğine büzülürdü. Yorumla sabitlendi.
     - **Test — negatif eş doğrulamasıyla:** mevcut menü testinde
       `find.text('Vazgeç')` artık `findsNothing`; ayrıca YENİ bir test
       zemine dokunmanın menüyü aksiyonsuz kapattığını (tahta AÇIK kalıyor,
       `share` çağrılmıyor, `set_game_shared` yazılmıyor) doğruluyor —
       "kullanıcı kapana kısılmadı" iddiasının kanıtı. `isDismissible:
       false` geçici olarak eklenince test GERÇEKTEN düştü
       (`Expected: no matching candidates / Actual: ... "Paylaş"`), geri
       alınınca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       379/379 yeşil** (378'den +1). Web `npm run lint` + `npm run build`
       temiz. `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (`src/components/ActionSheet.tsx`,
       `CLAUDE.md`) → kök `CLAUDE.md` aynı commit'te güncellendi.
     - **Doğrulama sınırı:** cihazda görsel teyit (menünün iki butonlu
       göründüğü + dışarı dokununca aksiyonsuz kapandığı) kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 6 güncellendi.

   - ✅ **Parça 86 — paylaşım iPad'de HİÇ çalışmayacaktı: `sharePositionOrigin`
     üç çağrı yerinin hiçbirinde verilmiyordu (13 Ağustos 2026,
     `share_board.dart`, `game_history_modal.dart`, `setup_screen.dart`,
     `friends_modal.dart`):** Kullanıcının "tüm app geliştirmeleri hem
     Android hem iOS için geçerli değil mi, her şeyi baştan test etmemiz
     gerekmeyecek?" sorusunu cevaplarken bulundu — cevabın canlı örneği
     çıktı.
     - **Kaynaktan doğrulandı, tahmin değil** (`FPPSharePlusPlugin.m`,
       satır 418-443): iPad'de paylaş sayfası bir POPOVER ve iOS ankraj
       istiyor. Eklenti bunu SERT bir koşul olarak uyguluyor —
       `isIpad && (origin kök view'ın dışında || CGRectIsEmpty(origin))`
       ise paylaşmak yerine **`FlutterError` DÖNDÜRÜYOR**. Dart tarafında
       bu `PlatformException`; bizim `catch`imiz onu yutuyor, metin
       yedeğine düşüyor, o da AYNI sebeple patlıyor → ikinci `catch` →
       kullanıcıya **hiçbir şey olmuyor**. iPhone ve Android'de parametre
       yok sayılıyor (`Parameter ignored on other platforms`).
     - **Neden bugüne kadar görünmedi — ve dersin özeti bu:** kullanıcı
       cihaz testini GitHub Pages web derlemesinde yapıyor; orada
       share_plus'ın WEB eklentisi çalışıyor (`navigator.share`), iOS
       kanalına hiç uğranmıyor. FAZ B (gerçek cihaz) henüz koşulmadı.
       Yani bu, "aynı Dart kodu iki platformda da aynı çalışır"
       varsayımının kırıldığı yer: kod TAMAMEN paylaşımlı, kıran şey
       platform kanalının kendi sözleşmesi.
     - **ÜÇ çağrı yerinin ÜÇÜ de kırıktı** (yalnızca bugün eklenen görsel
       paylaşımı değil): `game_history_modal` (tahta paylaşımı),
       `setup_screen` ("Arkadaşınla paylaş"), `friends_modal` (davet
       linki — orası `SharePlus.instance`'ı doğrudan çağırıyor). Bir
       hatayı bulduğunda ÜRETEN mekanizmanın diğer örneklerini de ara
       (Parça 54'ün dersi) — tek çağrı yerini düzeltmek ötekileri sessizce
       kırık bırakırdı.
     - **Ortak `shareOriginFrom(BuildContext)`** (`share_board.dart`):
       widget'ın kendi `RenderBox`'ından global dikdörtgeni alıp EKRANLA
       KESİŞTİRİYOR — iOS ankrajın kök view'ın İÇİNDE olmasını da şart
       koşuyor, kaydırma yüzünden kısmen dışarı taşan bir kutu yine hataya
       düşerdi. Kutu yoksa/boşsa ekran ortasında 1×1'lik bir yedek (boş
       OLMAMASI şart, `CGRectIsEmpty`).
     - **`origin` parametresi BİLEREK ZORUNLU** (`ShareBoardFn` typedef'inde
       `required Rect?`): opsiyonel olsaydı yeni bir çağrı yeri onu sessizce
       atlar ve paylaşım yalnızca iPad'de, yalnızca gerçek cihazda ölürdü.
       Nitekim `flutter analyze` değişiklikten hemen sonra 4 hatayla üç
       çağrı yerini + iki test sahtesini işaret etti — derleyicinin
       yakalayabileceği bir şeyi çalışma anına bırakmamak tam olarak bu.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI katman:** (a) çağıran
       katman — `_ShareCall` artık `origin`i de kaydediyor, ankrajın boş
       OLMADIĞI ve ekranın İÇİNDE kaldığı doğrulanıyor; (b) kanal katmanı —
       mock'lanan `dev.fluttercommunity.plus/share` çağrısında
       `originX/Y/Width/Height` alanları bekleniyor. **İlk denemede
       yalnızca (a) yazılmıştı ve YETERSİZDİ:** o test enjekte edilen sahte
       `share`i ölçtüğünden `shareBoard`ın `ShareParams`e iletip
       iletmediğini göremiyordu — `sharePositionOrigin` satırı silinince
       test GEÇMEYE devam etti. (b) eklenince aynı silme GERÇEKTEN düştü
       (`Expected: <10.0> / Actual: <null>`). **Ders: bir sözleşmeyi
       enjekte edilebilir bir sınırın ÜSTÜNDE test etmek, o sınırın
       ALTINDAKİ iletimi kanıtlamaz** — hangi katmanı ölçtüğünü sor.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       379/379 yeşil** (yeni test yok, mevcut ikisine assertion eklendi).
       `kelimeki_core`'a ve web'e hiç dokunulmadı.
     - **Doğrulama sınırı — bu ortamda KANITLANAMAZ:** gerçek bir iPad
       gerekiyor. Kanıt zinciri kaynak okuması + kanal seviyesinde test;
       gerçek popover FAZ B'de doğrulanmalı. `mobile/TESTING.md` bölüm 6
       ve FAZ B'ye maddeler eklendi.

   - ✅ **Parça 87 — üç sessiz hata: HEIC avatar reddi, yutulan galeri
     izni hatası, kaybolan soğuk-başlangıç davet linki (13 Ağustos 2026,
     `avatar_picker.dart`, `auth_service.dart`, `account_settings_modal.dart`,
     `friend_invite_inbox.dart`, `setup_screen.dart`):** Üçü de "hiçbir şey
     olmuyor" sınıfından — kullanıcıya hata bile göstermeden başarısız
     oluyorlardı. Üçü de kaynak koddan ölçülerek doğrulandı.
     - **(a) HEIC seçen Android kullanıcısı avatarını YÜKLEYEMİYORDU — ve
       sebep "HEIC" DEĞİLDİ.** İlk teşhis "Android'de HEIC baytları
       geliyor, MIME haritasında yok" idi; `image_picker`ın Android
       kaynağı okununca ÇÜRÜDÜ: `ImageResizer.java`'nın `shouldScale`ı
       `maxWidth != null || maxHeight != null || imageQuality < 100` —
       bizim 512/512/85 parametrelerimizle HER ZAMAN true, yani görsel
       JPEG'e yeniden kodlanıyor (`saveAsPNG = bitmap.hasAlpha()`, aksi
       hâlde JPEG). **Ama çıktı `createImageOnExternalDirectory("/scaled_"
       + outputImageName, ...)` ile yazılıyor — UZANTI KORUNUYOR.** Yani
       dosya `scaled_IMG_x.heic`, içi JPEG; `XFile.mimeType` de o
       platformda null. Uzantıya bakan eski kod `application/octet-stream`
       üretip `uploadAvatar`ın `image/*` kontrolüne takılıyordu: **geçerli
       bir JPEG, yalan söyleyen bir uzantı yüzünden reddediliyordu.**
       - **Düzeltme uzantı haritasını genişletmek DEĞİL, baytları okumak:**
         yeni `sniffImageMime` (JPEG/PNG/GIF/WebP/BMP + ISO-BMFF `ftyp`
         markası) ve öncelik sırasını sabitleyen `resolveAvatarMime`
         (baytlar → platformun bildirdiği tip → uzantı). Baytlar asla yalan
         söylemez ve sunucuya giden şey de zaten onlar.
       - **HEIC düz bir imzayla YAKALANAMAZ** — ilk baytı `0x00`; `ftyp`
         offset 4'te, marka 8-12'de. Bu yüzden sniff'te ayrı bir dal var.
       - **iOS'ta sorun yoktu ve bu da ölçüldü:**
         `FLTImagePickerMetaDataUtil.getImageMIMETypeFromImageData`
         yalnızca İLK baytı kokluyor (JPEG/PNG/GIF); HEIC `0x00` ile
         başladığından `MIMETypeOther` → suffix nil → `kFLTImagePickerDefaultSuffix
         = @".jpg"`. Flutter web'de ise `maxWidth/maxHeight/imageQuality`
         sessizce yok sayılıyor (Parça 83'te belgeliydi), yani baytlar
         GERÇEKTEN HEIC olabiliyor — sniff üç platformda da doğru cevabı
         verdiği için ayrı dal gerekmedi.
       - `auth_service.dart`'ın `_extByMime`ine heic/heif/bmp eklendi ki
         storage yolu (`<uid>/avatar.<ext>`) yanlış adlandırılmasın.
       - **`resolveAvatarMime` AYRI ve saf bir fonksiyon, çünkü test
         edilecek sözleşme SIRA:** `pickAvatarImage` platform kanalına
         bağlı, widget testinde çalışmaz — Parça 86'nın dersi (bir
         sözleşmeyi enjekte edilebilir sınırın ÜSTÜNDE test etmek, altındaki
         iletimi kanıtlamaz) burada baştan uygulandı.
     - **(b) Galeri izni reddedilince EKRANDA HİÇBİR ŞEY olmuyordu.**
       `pickAvatar`/`shrinkAvatar` çağrıları `try`ın DIŞINDAYDI; izin
       reddinde `image_picker`ın fırlattığı `PlatformException` en yakın
       `catch`e hiç uğramadan akışı kesiyor, `_uploadingAvatar` bile
       kurulmadığından tek bir piksel değişmiyordu. İkisi de `try` içine
       alındı; Türkçe, eyleme dönük bir hata gösteriliyor ("Fotoğraf
       seçilemedi. Galeri izni verildiğinden emin ol.") — Parça 45'in
       "sessiz yutma yok" dersinin aynı sınıfı.
     - **(c) Uygulama KAPALIYKEN dokunulan davet linki SESSİZCE
       kayboluyordu.** `friend_invite_inbox.dart`'ın eski başlığı "cold
       start'ta ilk URI da bu akışa dahil" diyordu — YANLIŞTI ve mekanizma
       kaynaktan okunarak doğrulandı: `AppLinks` Dart tarafında bir
       SINGLETON ve tek bir `StreamController.broadcast()` üzerinden
       çoğullama yapıyor; native taraf (`AppLinksIosPlugin.swift:107`,
       `AppLinksPlugin.java:133`) soğuk başlangıç linkini `initialLinkSent`
       bayrağıyla YALNIZCA İLK `onListen`da bir kez akışa basıyor.
       **Broadcast akışları geç abone olana geçmiş olayları TEKRARLAMAZ.**
       `bootstrap()`ta bu inbox `await initSupabase()` VE
       `await checkVersionGate(supabase)` (gerçek bir ağ çağrısı, 5 sn'ye
       kadar) tamamlandıktan SONRA kuruluyor; supabase_flutter ise
       `Supabase.initialize` içinde (`detectSessionInUri` varsayılan true)
       `uriLinkStream`e ondan ÖNCE abone oluyor — yani ilk dinleyici o,
       bayrağı o tüketiyor.
       - **Kurtarma yolu `getInitialLink()`:** native tarafta düz bir
         method-channel okuması (`case "getInitialLink": result(initialLink)`),
         `initialLinkSent` bayrağını TÜKETMİYOR — supabase'in auth akışını
         bozmadan aynı URI'yi bir kez daha okuyabiliyoruz. Hata yutuluyor
         ve loglanıyor: bir davet linki uygulamanın açılışını bloke edemez.
       - **Mükerrer kayıt riski gerçek ve kapatıldı:** aynı link hem sıcak
         akıştan hem kurtarmadan düşebiliyor ve `PendingEventStore.add`
         düz bir insert — dedup'ı YOK. Yeni saf `inviteTokensFromEvents`
         bir `takeAll` PARTİSİNDEKİ mükerrerleri (ve bozuk kayıtları)
         eliyor. Dedup **parti bazında**: kalıcı bir "görüldü" listesi
         TUTULMUYOR, yani bir sonraki oturumda aynı davet linkine yeniden
         dokunmak hâlâ çalışıyor.
       - **Widget testi DENENDİ ve TERK EDİLDİ:** `SetupScreen`
         `pumpAndSettle`ı asıyor (canlı rozet/senkron zamanlayıcıları —
         Parça 8'in aynı tuzağı); sınırlı `pump` döngüleri de kurtarmadı,
         test 400 sn zaman aşımına düştü. Bu yüzden karar saf bir fonksiyona
         çıkarılıp ORADA test edildi — gerekçe fonksiyonun kendi doc
         yorumunda da yazılı.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** (a) için
       `account_settings_test.dart`'a 5 test (bayt önceliği, HEIC `ftyp`
       markası, yedek zinciri, picker fırlatması, shrink fırlatması);
       `resolveAvatarMime`den sniff çağrısı çıkarılınca 2 test GERÇEKTEN
       düştü (`Expected: 'image/heic' / Actual: 'application/octet-stream'`).
       (b) için modaldeki `try/catch` geri alınınca iki test de GERÇEKTEN
       düştü (`Found 0 widgets with text containing Fotoğraf seçilemedi`).
       (c) için `friends_test.dart`'a saf bir dedup testi.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       385/385 yeşil** (379'dan +6). `kelimeki_core`'a ve web'e hiç
       dokunulmadı — `mobile/` DIŞINDA dosya değişmedi.
     - **Doğrulama sınırı:** üçü de gerçek cihaz istiyor — Android'de
       HEIC seçimi, izin reddi diyaloğu ve `kelimeki://davet/<token>`
       soğuk başlangıcı (custom şema yalnızca KURULU bir uygulamada
       yakalanır, web derlemesinde test EDİLEMEZ — Parça 28'in aynı
       sınırı). `mobile/TESTING.md` bölüm 10/12 ve FAZ B'ye maddeler
       eklendi.
     - **Ders — "web'de de böyle" bir savunma DEĞİL, ama "web'de yok" da
       bir gerekçe değil:** (a) ve (b) web'de yaşanmıyor (tarayıcının
       dosya seçicisi MIME'i doğru bildiriyor, izin diyaloğu yok), (c)
       ise web'de kavram olarak yok (deep link yerine gerçek bir sayfa
       var). Üçü de porta ÖZGÜ, platform kanallarının kendi
       sözleşmelerinden doğuyor — Parça 86'nın `sharePositionOrigin`
       bulgusuyla aynı aile. **Kaynak koda inmeden hiçbiri bulunamazdı;**
       üçünde de belirti aynıydı: "hiçbir şey olmuyor".

   - ✅ **Parça 88 — kardeş-ekran denetimi: üç sapma, biri motorun kendi
     mesajını ulaşılamaz kılıyordu (13 Ağustos 2026, `game_screen.dart`,
     `online_game_screen.dart`):** `game_screen.dart` ↔ `online_game_screen.dart`
     çifti "Etki Analizi"nin değişmezi gereği elle senkron tutuluyor ve
     hiçbir derleyici/test bunu yakalamıyor — planlı bir denetimle üç fark
     bulundu. **Üçü de web kaynağından TEK TEK doğrulandı**, denetim
     raporuna güvenilmedi.
     - **(a) Boş taslakta OYNA/GERİ AL devre dışıydı; web'de değil.**
       Web: `disabled={!canAct || validating || !wordsReady}` (App.tsx:1450)
       ve `disabled={!canAct}` (1501) — `placed.isEmpty` koşulu YOK. Port
       DÖRT yerde birden (iki ekran × iki buton) bu koşulu taşıyordu, artı
       `online_game_screen.dart:700`'de mesajı yutan bir iç guard.
       - **Asıl mesele kozmetik değil:** motor bu durum için ÖZEL bir
         mesaj taşıyor — `validator.dart:57` / `validator.ts:62`,
         **"Harf yerleştirilmedi."** Butonu kapatmak o mesajı ULAŞILAMAZ
         kılıyordu; kullanıcı gri bir butonla kalıyor ve sebebini hiçbir
         yerde okuyamıyordu. Bu, Parça 87'de düzeltilen üç hatanın aynı
         sınıfı: sessiz ret.
       - **Web'in KENDİ yazılı gerekçesi de bu yönde:** `OnlineGameScreen.tsx:705-714`
         (3 Ağustos 2026) *"kullanıcıyı PASİF bir butona basmaya çağıran,
         sebebi hiçbir yerde yazmayan çelişkili bir ekrandı — özelliği
         yazan kişiyi bile yanılttı"* diyor. Karar bu yüzden "web'e
         hizala" oldu; portun davranışını bilinçli bir sapma olarak
         kaydetmek, motorun taşıdığı mesajı kalıcı olarak ölü kod
         yapardı.
     - **(b) Canlı "Sıra: X" bandı YANLIŞ kırmızıyı kullanıyordu ve kendi
       içinde tutarsızdı.** Zemin/çerçeve `#E0483A` (`kMoveInvalid` —
       TAHTAYA özel kırmızı) üzerine kuruluydu, **ama yorumu doğru şekilde
       "web bg-red/10" diyordu**; aynı bandın nabız noktası ve metni ise
       ZATEN `kRed` (`#DC2626`) kullanıyordu. Yani tek bir bantta iki
       kırmızı vardı. Parça 54'ün ("her dosyada yerel palet kopyası")
       taraması bunu göremiyor, çünkü değerler alfa türevi
       (`0x1A…`/`0x66…`), `Color(0xFF…)` değil. Ayrıca `shadow-raised`
       hiç yoktu ve dolgu 12/10 idi (web `px-4 py-3` = 16/12). Üçü de
       düzeltildi; renkler artık `_red.withValues(alpha: 0.1/0.4)` —
       `move_history_modal.dart:319`'un zaten kullandığı deyim, yani
       token ilişkisi kodda görünür.
     - **(c) "Tekrar Oyna" hata dalının butonu "TAMAM" diyordu, web
       "Kapat".** Web'de bunlar İKİ AYRI dal (`sent` → "Tamam", `error` →
       "Kapat"); port ikisini tek diyalogda birleştirdiğinden etiket artık
       içeriğe göre seçiliyor.
     - **Test — negatif eş doğrulamasıyla, DÖRT ayrı kanıt:** iki lib
       dosyası birlikte `git stash`lenip testler koşuldu; dördü de
       GERÇEKTEN düştü — yerel A2 ve Canlı A2 `Expected: not null /
       Actual: <null>` (buton kapalı), A3 `Found 1 widget with text
       "TAMAM"`, A1 dekorasyon tipi tutmadığından. Geri konunca yeşile
       döndü.
     - **Test yazarken düşülen tuzak (kayda geçsin):** yeni testin
       `expect(controller.state.turnCount, 0)` iddiası düştü — `craftedState()`
       sıfırdan başlamıyor (turnCount 2). Kodda değil TESTTE hata vardı;
       "hamle işlenmemeli" iddiası mutlak bir sayıya değil ÖNCEKİ değere
       bağlanmalıydı. Bir fikstürün başlangıç durumunu varsaymadan önce
       oku.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       388/388 yeşil** (385'ten +3; A3 mevcut testin güncellenmesi olduğu
       için ayrı test SAYILMIYOR). `kelimeki_core`'a ve web'e hiç
       dokunulmadı — `mobile/` DIŞINDA dosya değişmedi.
     - **Doğrulama sınırı:** bandın görsel teyidi (yeni kırmızı + gölge +
       dolgu) cihazda bekleniyor — `mobile/TESTING.md` bölüm 11'e madde
       eklendi.
     - **Denetimin "belirsiz" bulguları BİLİNÇLİ olarak kapsam dışı:**
       30px sabit mesaj satırı, "Kalan Taşlar"ın `myIndex`i, yeni-mesaj
       popup'ının biçimi ve rematch'in "Gönderiliyor…" durumu — dördü de
       web'e karşı ölçülmeden "sapma" sayılamaz, ayrı bir tur istiyorlar.
       Bir bulguyu doğrulamadan düzeltmek bu projede daha önce iki kez
       geri alındı (Parça 16→17, 39→40).

   - ✅ **Parça 89 — beş paralel denetimin bulguları: bir VERİ KAYBI yolu, üç
     SAHTE BAŞARI mesajı (13 Ağustos 2026, `setup_screen.dart`,
     `friends_modal.dart`):** Kullanıcı isteğiyle beş salt-analiz denetimi
     koşuldu (Türkçe metin paritesi, elle senkron kopyalar, sessiz hata
     yutma, test kalitesi, sunucu yetkileri). **Raporlar körlemesine
     UYGULANMADI** — her bulgu kaynaktan tek tek doğrulandı; aşağıdakiler
     doğrulananlar.
     - **(a) VERİ KAYBI — `_resumeSavedGame` terk olaylarını tüketip
       çöpe atıyordu.** `drainAbandonedGames()` `PendingEventStore.takeAll`
       kullanıyor = **atomik SELECT+DELETE**, yani dönüş değerini atmak
       olayları KALICI olarak siler. `_resumeSavedGame`'in `state == null`
       dalı ("tam bu anda süresi doldu") bunu çıplak çağırıp sonucu hiç
       okumuyordu; oysa olayları -2 cezalı `games` kaydına çeviren tek
       tüketici `_sweepLocalAbandoned`.
       - **Tetikleyici somut:** misafir Setup'ta "Devam Eden Oyun" satırı
         dururken 7 günlük süre dolar, "Devam Et"e dokunur → kayıt olaya
         çevrilir → bu dal olayı yutar. Terk edilen oyunun tam `GameState`'i
         ve -2 cezası bir daha üretilemez (bir sonraki açılışta süpürme
         hiçbir şey bulamaz).
       - Düzeltme tek satır: `_sweepLocalAbandoned()` çağır.
       - **Aynı fonksiyonda ikinci, daha dar bir sıralama hatası:**
         `_sweepLocalAbandoned` ÖNCE drain edip SONRA `games == null` diye
         dönüyordu — o dalda da olaylar kaybolurdu. `games` artık drain'den
         ÖNCE çözülüyor. **Kural: yıkıcı bir okuma (`takeAll`) yapmadan
         önce sonucu tüketecek her şeyin hazır olduğundan emin ol.**
     - **(b) SAHTE BAŞARI — `FriendsModal` ağ hatasında gerçekleşmemiş
       sonuçlar bildiriyordu.** Üç akış: `_handleRespond` hatayı tamamen
       yutup `void` döndüğünden "Arkadaş oldunuz." ve "İstek reddedildi."
       KOŞULSUZ gösteriliyordu; `_handleSend` hatada `null` dönüyor ve
       `null != accepted` olduğundan "Arkadaşlık isteğiniz iletilmiştir."
       çıkıyordu — istek hiç gitmemişken.
       - **Sessiz retten DAHA KÖTÜ:** kullanıcı yanlış bilgilendiriliyor,
         üstelik liste tazelenmediğinden ekran mesajla çelişiyor (reddedilen
         istek yerinde duruyor).
       - `_handleRespond` artık `bool` dönüyor; üç çağrı yeri de sonucu
         kontrol ediyor. Hata metni İCAT EDİLMEDİ — `chat_settings_modal`'ın
         zaten kullandığı `'İşlem başarısız oldu.'` paylaşıldı.
       - **Aynı dosyadaki `_confirmThenRemoveCandidate`/`_confirmThenCancel`
         baştan DOĞRUYDU** (başarı diyaloğunu `try` İÇİNDE gösteriyorlar) —
         yani bu bir desen hatası değil, iki akışın o desenden sapmasıydı.
     - **Test — negatif eş doğrulamasıyla:** `friends_test.dart`'a ağ
       hatasında reddetmenin "İstek reddedildi." DEĞİL "İşlem başarısız
       oldu." dediğini doğrulayan test. `friends_modal.dart` `git stash`
       lenince GERÇEKTEN düştü (`Found 1 widget with text "İstek
       reddedildi."` — kullanıcının göreceği sahte başarının ta kendisi).
     - **Test tuzağı (kayda geçsin):** satır butonu ve onay diyaloğunun
       kabul butonu ikisi de `trUpper`dan geçiyor → finder `'Reddet'` değil
       **`'REDDET'`** olmalı. Ayrıca `pumpModal` `FriendsModal` GRUBUNUN
       içinde tanımlı; testi başka bir gruba eklemek "Method not found"
       verir.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       389/389 yeşil** (388'den +1). `kelimeki_core`'a dokunulmadı.
     - **AÇIK BOŞLUK — (a) için test YOK:** düzeltme kaynaktan kanıtlandı
       (takeAll yıkıcı + tek meşru tüketici `_sweepLocalAbandoned`) ama
       widget seviyesinde tekrarlanabilir bir kurulum (loadSave null DÖNERKEN
       kuyrukta olay olması) yazılmadı. `mobile/TESTING.md` bölüm 1'e elle
       kontrol maddesi eklendi; kalıcı test hâlâ borç.
     - **Denetimlerin diğer bulguları — durum:**
       - **Elle senkron kopyalar: TEMİZ.** Rütbe/ödül üç kopya (SQL↔TS↔Dart)
         birebir, ödül=eşik/10 dokuz kademede de tutuyor, kümülatif toplamlar
         pairwise farklı; üretilmiş dosyalar bayat değil (motor dosyaları
         golden'lardan sonra DEĞİŞMEMİŞ); RankSeal geometrisi ve renk paleti
         senkron. Çıkan üç bayat YORUM ayrı bir commit'te düzeltildi.
         **Denetimin "kör nokta" dediği `tile-border` (#C7D0DC) DÜZELTİLDİ:**
         token `src/`'de de hiç kullanılmıyor, yani iki tarafta da ölü —
         izlenmemesi bir eksiklik değil.
       - **Sunucu: bir uykuda hata bulundu** (`withdraw_online_game_chat_reports`
         overload'ı) — Parça 90'da düzeltildi.
       - **Test kalitesi:** en güçlü bulgu `OnlineApi.submitMove`'un
         retry/idempotency döngüsünün SIFIR test kapsamı olması — Parça
         90'da kapatıldı.
       - **Türkçe metin paritesi:** denetim İKİ kez oturum limitine takıldı,
         sonuç ALINAMADI — Parça 90'da elle koşuldu ve gerçek bir bulgu
         çıkardı (Gizlilik Politikası bayattı).

   - ✅ **Parça 90 — Parça 89'un üç açık maddesi kapandı; hukuki metin
     denetimi bir GİZLİLİK YALANI buldu (14 Ağustos 2026,
     `fix_withdraw_report_wrong_overload` migration'ı, `online_api.dart`,
     `legal_modals.dart`, `live_games_tab.dart`, `games_api.dart`,
     `game_history_modal.dart`, `recent_games_section.dart`):** Parça 89
     üç işi "sonraya" bırakmıştı (uykudaki sunucu hatası, `OnlineApi`'nin
     sıfır testi, tamamlanamayan Türkçe metin denetimi); üçü de bu parçada
     kapandı ve sonuncusu beklenenden ağır bir bulgu çıkardı.
     - **(a) Sunucu — `withdraw_online_game_chat_reports`'un YANLIŞ
       overload'ı düzeltilmişti (uygulandı, kanıtlandı).** 4 Ağustos'taki
       "geri çekme `handled`'a dokunmasın" düzeltmesi, bir gün önce DROP
       edilmiş 2-arg imzayı `create or replace` ile yeniden yaratıp ona
       uygulanmıştı; istemcilerin çağırdığı 1-arg sürüm hâlâ
       `handled = true` yapıyordu. **Bozulmuş veri YOKTU** (son geri çekme
       04.08 10:49, migration 10:54 — o tarihten beri hiç geri çekme
       olmamış), yani hata gerçekti ama uykudaydı. Migration 1-arg sürümü
       düzeltip hortlak overload'ı düşürdü (o overload ayrıca
       `SECURITY DEFINER` + EXECUTE'u PUBLIC'te — "yeni fonksiyonda önce
       revoke all" kuralına aykırı bir kalıntı).
       **Canlıda geri alınan bir transaction'la DAVRANIŞ testi yapıldı**
       (varlık kontrolü değil): gerçek bir satır (`83535bba…`)
       `handled=false`a çekilip RPC gerçek raporlayanın kimliğiyle
       çağrıldı → `withdrawn_at` doldu, `handled` **`false` KALDI**;
       `rollback` sonrası satırın eski hâline (`handled=true`,
       `withdrawn_at=null`) döndüğü ayrıca sorgulandı.
     - **(b) `OnlineApi.submitMove` artık testli** — mobilin ASIL
       güvenilirlik özelliği (aynı `p_move_id` ile retry) sıfır kapsamdaydı.
       `OnlineApi.withRpc` test dikişi (`SubmitMoveRpc` typedef'i) +
       `test/online_api_test.dart` (4 test): aynı id ile yeniden deneme,
       `PostgrestException`'da tek çağrı + rethrow, `maxAttempts` tükenince
       hatanın yüzeye çıkması, açık `moveId`. **Negatif eş, İKİ AYRI
       kanıt:** `final id = moveId ?? uuidV4()` döngünün İÇİNE taşınınca
       idempotensi testi GERÇEKTEN düştü (`Expected: '31769d3e…' Actual:
       '43a67f74…'`); `PostgrestException` rethrow'u kaldırılınca çağrı
       sayısı testi düştü (`Expected: <1> Actual: <3>`). Parça 86'nın
       dersinin doğrudan uygulaması: ekranın 15 testi `FakeOnlineGamesGateway`
       sınırının ÜSTÜNDE ölçüyor, döngü o sınırın ALTINDA.
     - **(c) Türkçe metin denetimi — port, kullanıcıya kendi verisi
       hakkında GERÇEK OLMAYAN bir şey söylüyordu.** `legal_modals.dart`ın
       başlığı "METİNLER WEB'DEN BİREBİR KOPYALANMIŞTIR … web metni
       değişirse buraya da aynen taşınmalı" diyordu ama bunu ZORLAYAN
       hiçbir şey yoktu ve gerçekten kaçtı: 10 Ağustos'ta
       `game_chat_archive_participants_only` (Parça 51) sohbet arşivini
       katılımcı+admin'e kilitledi, web'in Gizlilik Politikası düzeltildi,
       port ESKİ cümleyi ("mevcut skor/tahta görünürlüğüyle aynı şekilde
       tüm kayıtlı kullanıcılara açıktır") taşımaya devam etti. Metin
       web'in bugünkü hâline çekildi, "Son güncelleme" 2 → 10 Ağustos.
       - **`test/legal_text_test.dart` bunu KALICI olarak zorluyor** —
         `color_tokens_test.dart`ın tailwind'i okuyan deseninin hukuki
         metin karşılığı: web'in kaynak dosyasını OKUYUP kendi
         "Son güncelleme" tarihlerini portunkiyle
         karşılaştırıyor (tam metin karşılaştırması satır kaydırma/kaçış
         farklarıyla kırılgan olurdu; tarih, projenin yerleşik disiplini
         gereği her metin değişikliğinde güncelleniyor, yani "port bayat
         mı?" sorusunun güvenilir vekili). Üçüncü test, tarihten bağımsız
         olarak eski/yanlış cümlenin geri gelmediğini de sabitliyor.
         **Negatif eş:** metin eski hâline döndürülünce 3 testin 2'si
         GERÇEKTEN düştü.
     - **(d) Aynı denetimde bulunan iki SESSİZ HATA daha (Parça 89'un
       "sahte başarı" sınıfının kardeşleri):**
       1. **Canlı davet yanıtı ağ hatasında hiçbir şey söylemiyordu**
          (`live_games_tab.dart`) — `_handleRespond`'ın `catch`i yalnızca
          logluyordu; kullanıcı Kabul Et/Reddet'e basıyor, kart yerinde
          duruyor, ekranda hiçbir açıklama yok. Parça 89'un
          `FriendsModal` için açtığı `kFriendActionFailed` sabiti
          paylaşıldı (yeni metin icat edilmedi).
       2. **Oyun geçmişi ağ hatasını "hiç oyunun yok" diye gösteriyordu**
          — `GamesRepo.history` boş liste dönüp hatayı yutuyordu, iki
          tüketici de (`GameHistoryModal`, `RecentGamesSection`) bunu
          "Henüz kayıtlı bir oyunun yok." / "Henüz bitmiş bir Yapay Zeka
          oyunun yok." diye çiziyordu. **Çevrimdışı bir kullanıcıya bu,
          oyunlarının silindiğini düşündürür.** Dönüş kaydına `failed`
          eklendi (`moves`un `ok`/`boardSnapshot`un null ayrımıyla aynı
          gerekçe — "veri yok" ile "ulaşamadım" AYRI şeyler) ve iki ekran
          da artık "Oyun geçmişi yüklenemedi. Bağlantını kontrol edip
          tekrar dene." diyor. `RecentGamesSection` ayrıca başarısız
          çekimle önbelleği EZMİYOR — önceki mount'un listesi çevrimdışı
          gösterilmeye devam edebilsin.
       - **`GameHistoryModal`'da bayrak İKİ yükleme yolunda da set
         ediliyor** (`_loadInitial` + `_loadPage`): ikincisi sekme
         değişiminin de (offset 0) yolu, orada bir hata "favori
         işaretlediğin oyun yok" diye görünürdü.
       - **`FakeGamesGateway`e `failList` eklendi** — Parça 46'nın dersi:
         sahtenin taklit etmediği bir hata yolu, o yol hakkındaki testleri
         sessizce anlamsız kılar; bu hata tam da bu yüzden 398 test
         yeşilken görünmezdi. **Negatif eş:** iki ekranın dalları
         kapatılınca yeni iki test de GERÇEKTEN düştü (`Found 0 widgets
         with text containing yüklenemedi`).
       - **AYNI GÜN web'e de taşındı (aynı PR):** `fetchMyGames` de artık
         `failed` döndürüyor, `GameHistoryModal`/`RecentGamesSection` aynı
         mesajı gösteriyor. İlk sürümde yalnızca mobil düzeltilip web kök
         `CLAUDE.md`'nin bekleme listesine yazılmıştı; kullanıcı "onu da
         kapat" deyince aynı dalda bitirildi (dal `main` tabanlı ve zaten
         web dosyaları içeriyor — ikinci bir dal açmak Kontrol Listesi
         madde 1'in "teslim et" amacına hizmet etmezdi). Web'de birim test
         çatısı olmadığından oradaki kanıt farklı: `tsc` sözleşmeyi
         GERÇEKTEN zorluyor (bir return sitesinden `failed` düşürülünce
         `TS2741` ile kırıldı — negatif eş), mesaj üretim paketinde iki
         çağrı yerinde de var, duman testleri geçiyor; davranışın gözle
         teyidi `TESTING.md` bölüm 9.6'da.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       398/398 yeşil** (389'dan +9). `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (`supabase/migrations/`) → kök
       `CLAUDE.md` aynı commit'te güncellendi (Kontrol Listesi madde 1).
     - **Doğrulama sınırı:** ~~(a) gerçek istemciyle uçtan uca (bir şikayeti
       geri çekip admin panelinde hâlâ "Yeni" göründüğünü doğrulamak)
       cihazda/web'de teyit edilmeli~~ — **14 Ağustos 2026'da KAPANDI:**
       kullanıcı gerçek hesapla geri çekti, `handled` `false` kaldı, kart
       admin panelinde "Yeni" görünüp sayaca dahil oldu, sonra elle okundu
       işaretlendi. Ayrıntı + çıkarımın nasıl elemeyle yapıldığı: kök
       `CLAUDE.md`, aynı maddenin sonu. (b) `OnlineApi` testleri sahte bir
       RPC ile ölçüyor, gerçek PostgREST retry'ı hâlâ Faz 6'nın (çok
       kullanıcılı harness) işi; (d.2) gerçek ağ kesintisiyle "yüklenemedi"
       mesajının göründüğü cihazda doğrulanmalı — `mobile/TESTING.md`
       bölüm 5/11'e maddeler eklendi.
     - **Ders — bir dosyanın BAŞLIĞINDAKİ "birebir kopyalanmıştır" notu bir
       garanti DEĞİL, bir niyet beyanıdır.** Bu proje aynı sınıfı renkler
       (Parça 54 → `color_tokens_test`) ve tipografi (Parça 78 →
       `theme_test`) için zaten testle bağlamıştı; hukuki metin en uzun
       süre bağlanmadan kalan ve yanlış olduğunda BEDELİ EN AĞIR olan
       kopyaydı — kullanıcıya kendi verisinin görünürlüğü hakkında yanlış
       bilgi veriyordu. Yeni bir "elle senkron" kopya açarken sor: bunu
       hangi test zorluyor?
       - **23 Ağustos 2026 — okunan dosya DEĞİŞTİ:** web metni
         `TermsModal.tsx`/`PrivacyModal.tsx`ten `src/legal/LegalContent.tsx`e
         taşındı (aynı metni artık `/gizlilik/` ve `/kullanim-kosullari/`
         statik sayfaları da tüketiyor; Play'in Data safety formu doğrudan
         açılan bir URL istiyor). Test eski yolu okumaya devam etseydi
         "Son güncelleme bulunamadı" diye DÜŞERDİ — merge öncesi yakalandı.
         **Yeni tuzak:** tek dosyada artık İKİ tarih var ve sıraları portun
         TERSİ (web: Gizlilik → Koşullar, port: Koşullar → Gizlilik), o
         yüzden test "ilk eşleşmeyi al" demiyor, metni `TermsBody`
         sınırından bölüyor.

   - ✅ **Parça 91 — şikayeti geri çekmenin TEK yolu, raporladığın kişiyle
     YENİ bir oyun açmaktı (14 Ağustos 2026, yeni
     `ui/friends/friend_moderation_sheet.dart`, `chat_api.dart`,
     `friends_modal.dart` + web `FriendModerationModal.tsx`):** Kullanıcı
     bölüm 10'u koşarken duvara çarptı ve çözümü kendisi tarif etti:
     *"arkadaşlar listesinde o kişinin satırında arkadaşlıktan çıkart
     işaretinin soluna bayrak/Sessiz ikonu koymak ve tıklandığında
     settings'i açmak."*
     - **Kök sebep bir kod hatası DEĞİL, bir erişim boşluğu:** sessize
       alma/şikayet 3 Ağustos'tan beri KİŞİ bazlı (oyunlar arası taşınıyor)
       ama geri almanın giriş noktası hâlâ **AKTİF** bir oyunun sohbet
       ayarlarıydı (`ChatSettingsModal`, dişli). Oyun bitince
       `LiveGamesTab` onu listelemiyor, arşiv (`GameChatHistoryModal`)
       bilerek salt-görsel — yani durum kalıcı, kontrolü ulaşılamaz.
       **Kalıcı bir durumu geri almanın yolu, o durumun oluştuğu geçici
       bağlama bağlıysa er ya da geç kapanır** — kişi bazlı yapılırken
       kontrol de kişi bazlı bir yere taşınmalıydı.
     - **KAPSAM bilinçli olarak yalnızca GERİ ALMA.** Yeni şikayet burada
       YOK: bir şikayet hakkında olduğu KONUŞMAYA bağlı
       (`online_game_chat_reports.online_game_id`) ve admin panelindeki
       "Sohbeti Görüntüle" o dökümü açıyor — arkadaş listesinden açılan
       bir şikayet zorunlu olarak ESKİ bir oyuna iliştirilir ve admin
       ilgisiz bir yazışma okurdu. Bu yüzden ikon da yalnızca durum
       VARKEN çiziliyor: bu bir kısayol, moderasyon menüsü değil.
     - **Sunucuda DEĞİŞİKLİK YOK — ama sessizden çıkarma OYUN İD'Sİ
       İSTİYOR ve bu kaynaktan okunarak bulundu:**
       `mute_online_game_participant` katılımcılık kontrolünü `p_muted`
       dalından ÖNCE yapıyor, yani MUTE'u KALDIRMAK bile geçerli bir ortak
       oyun id'si gerektiriyor. Provenance olarak mute/rapor satırının
       KENDİ `online_game_id`'si kullanılıyor (o satır ancak ikisi de
       katılımcıyken yazılabildiğinden geçerliliği garantili) — yeni
       `ChatRepo.myModeration()` iki tablodan `userId → gameId` haritası
       döndürüyor. `withdrawReports` zaten kişi bazlı, id İSTEMİYOR.
     - **Canlıda rol simülasyonuyla doğrulandı (hepsi rollback):** iki
       tablodan da `online_game_id` okunabiliyor; **BİTMİŞ** bir oyunun
       id'siyle sessizden çıkarma GEÇİYOR (1 satır → 0) —
       `is_online_game_participant` oyunun `status`üne bakmıyor, yani
       kısayol tam da en çok gerektiği yerde çalışıyor. Bu, "eski oyun
       id'si hâlâ geçerli mi?" sorusunun tahminle değil ölçümle
       cevaplanması gereken kısmıydı.
     - **`ChatRepo` zinciri dört yeni durakla threadlendi** (services →
       Setup/GameScreen/OnlineGameScreen → GameHeader → AccountButton →
       FriendsModal) ve **`LiveGameCreateForm` da dahil edildi**: o ekran
       da `showFriendsModal` açıyor ve atlanırsa AYNI satır bir girişte
       ikonlu, öbüründe ikonsuz görünürdü — bu projenin en sık tekrarlayan
       hata sınıfı (sessiz ayrışma), burada baştan kapatıldı.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** dört yeni
       test (yalnızca durumu OLAN satırda ikon + konumu "çıkar"ın solunda;
       panel → onay → geri çekme → ikon KAYBOLUYOR; sessizden çıkarmanın
       kaydın geldiği oyun id'siyle çağrıldığı; `chat` yokken ikon HİÇ
       çizilmediği). (1) İkon render koşulu kapatılınca ÜÇÜ GERÇEKTEN
       düştü — dördüncüsü (yokluk iddiası) doğru şekilde geçmeye devam
       etti. (2) `if (changed) await _reloadModeration();` kapatılınca
       kullanıcının göreceği bayat-bayrak semptomu BİREBİR üretildi
       (`Expected: no matching candidates / Actual: Found 1 widget with
       text "🚩"`). İkisi de geri konunca yeşile döndü.
     - **Sahte uç gerçek ucun sözleşmesini taklit ediyor** (Parça 46'nın
       dersi): `FakeChatGateway.myModeration` yalnızca kimlikleri değil
       oyun id'sini de döndürüyor — aksi halde "sessizden çıkarma doğru
       id'yle çağrılıyor mu" sorusu testlerde sorulaMAZDI.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       402/402 yeşil** (398'den +4). `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (web yarısı aynı gün, aynı
       dalda) → kök `CLAUDE.md` + `TESTING.md` aynı commit'te güncellendi
       (Parça Bitirme Kontrol Listesi madde 1).
     - ~~**Doğrulama sınırı:** gerçek `myModeration` sorgusu + gerçek
       `setMute`/`withdrawReports` RPC'leri mobilde iki hesapla
       doğrulanmalı~~ — **AYNI GÜN İKİ PLATFORMDA DA KAPANDI.** Web:
       ikon doğru satırda çıktı, temiz satırda çıkmadı, geri çekme
       çalıştı ve `handled`'a dokunmadı. Mobil: 🚫 arkadaş satırında
       çıktı, panelden sessizden çıkarıldı, ikon ANINDA kalktı.
     - **Mobil turun ürettiği kanıt, "çalıştı" beyanından güçlü:**
       üretimde `online_game_message_mutes` **0 satıra** düştü ve
       provenance oyununun (`866eb714…`) durumu **`finished`** — yani
       sessizden çıkarma BİTMİŞ bir oyunun id'siyle gerçek istemciden
       geçti. Bu tam olarak özelliğin varlık sebebi: `mute_online_game_participant`
       katılımcılık kontrolünü `p_muted` dalından ÖNCE yaptığından
       sessizden ÇIKARMAK bile geçerli bir oyun id'si istiyor, ve o id'nin
       bitmiş bir oyuna ait olması sorun ETMİYOR. Daha önce yalnızca
       rollback'li simülasyonla gösterilmişti; artık gerçek uçtan uca.
       Ayrıca `ChatRepo` kablolaması ve emoji fallback'i (🚫 tofu değil)
       de bu turda kapandı.
     - **İkinci yol (şikayet → geri çekme) de AYNI GÜN mobilde koşuldu ve
       tasarımın DÖRT durumunu birden gösterdi:** aktif oyunun sohbetinden
       şikayet (08:19:14) → satırda 🚩 → panelden geri çekme (08:20:11) →
       ikon **kaybolmadı, 🚫'ye döndü** → sessizden çıkarma → ikon kalktı.
       Ortadaki adım kullanıcıya önceden söylenmeseydi "geri çektim ama
       ikon duruyor" diye YANLIŞ bir hata bildirimi üretebilirdi: şikayet
       otomatik sessize alıyor ve geri çekme mute'a bilinçli olarak
       dokunmuyor. **Üretimden asıl kanıt `handled` = `false` KALDI** —
       4 Ağustos'ta yazılıp 10 gün ölü bir overload'da mahsur kalan
       düzeltmenin mobil istemciden ilk doğrulaması (bkz. Parça 90 (a)).
     - **Web ↔ mobil metin paritesi VARSAYILMADI, ölçüldü:** kullanıcı
       paneli mobilde ilk kez görünce "web'e de uyguladık mı?" diye
       sordu; `FriendModerationModal.tsx` ile `friend_moderation_sheet.dart`
       13 dize üzerinden karşılaştırıldı (durum cümlesinin üç varyantı,
       iki buton, onay adımı, iki sonuç mesajı, hata metni, alttaki
       "şikayet sohbetten yapılır" notu) — **13/13 birebir**. Bu dosya
       çiftinin `legal_modals.dart` gibi otomatik bir parite testi YOK;
       biri değişirse öteki elle güncellenmeli.

   - ✅ **Parça 92 — üç kullanıcı isteği, üçü de İKİ platformda birden
     (14 Ağustos 2026, `setup_screen.dart`, `leaderboard_modal.dart`,
     `board_widget.dart`, `game_screen.dart`, `online_game_screen.dart` +
     web `Board.tsx`/`App.tsx`/`OnlineGameScreen.tsx`/`Leaderboard.tsx`):**
     Kullanıcı: *"1. Mobilde girişsiz YZ oyun başlatınca web'deki uyarı
     çıkmıyor. 2. Leaderboard OHP kolonunu az daha puan kolonuna
     yaklaştır. 3. Board altındaki X2/X3 legendları kaldır. Onun yerine
     board'un sağ alt köşesine Hamleler, Mesajlaşma ile aynı stil, 'Nasıl
     Oynanır?' ekle."*
     - **(1) Misafir uyarısı — web'de VARDI, porta hiç girmemişti.** Web
       `Setup.tsx`'in `handleStart`i giriş yapılmamışsa oyunu BAŞLATMADAN
       önce bir uyarı açıyor ("Oyunların istatistikleri, k-lig ve
       arkadaşınla canlı oyun için lütfen giriş yapın." + GİRİŞ YAP /
       DEVAM); port doğrudan `_startNewGame`e gidiyordu. Kaynak okunup
       aynı metin/butonlar `KModal(title: '')` ile taşındı (`GameOverModal`
       emsali — ham `Dialog` kurmak bu projede üç kez geri alındı, bkz.
       Parça 26/47/50).
       - **Sonuç ÜÇ DEĞERLİ olmak ZORUNDA:** ilk taslağım "GİRİŞ YAP" ile
         ✕'i aynı `false`a düşürüyordu, yani ayırt edilemiyorlardı ve
         yanına gereksiz bir yan-etki bayrağı koymuştum. `_GuestChoice
         {login, proceed, dismiss}` ile üçü ayrıldı: DEVAM → oyun başlar,
         GİRİŞ YAP → giriş penceresi açılır ve oyun BAŞLAMAZ (web'de de
         öyle), ✕/zemin → hiçbir şey olmaz. **Bir diyaloğun dönüşü
         `bool` ise "iptal" ile "başka bir yola saptı"yı ayıramazsın** —
         `showDialog<T>` zaten jenerik, enum kullanmanın maliyeti yok.
       - `auth.loading` iken uyarı GÖSTERİLMEZ (kimlik henüz bilinmiyorken
         girişli kullanıcıyı yanlışlıkla durdurmamak için) — web'in
         `profileLoading` beklemesiyle aynı refleks.
     - **(2) OHP ↔ Puan — sağa hizalı bir sütunu SOLA çekmenin tek yolu
       SAĞINDAKİNİ daraltmak.** OHP'nin kendi genişliğini büyütmek/
       küçültmek onu yerinden oynatmaz (metin sağa yaslı; kutu büyüyünce
       yalnızca sol kenarı büyür). Puan 52 → **44** (web `w-12`→`w-10`);
       ölçüldü: iki sütunun sağ kenarları arası **44.0 px**, web'de de
       aynı. Web'de ÜÇ çağrı yeri birden değişmek zorunda (başlık, satır,
       "senin sıran") — biri atlanırsa hiza bozulur.
       - **AYNI GÜN ikinci tur — "OHP başlığı ortalı değil" (kullanıcı):**
         doğruydu ve ÖLÇÜLDÜ: başlığın ink merkezi değerlerin **7.07 px
         sağındaydı**; kıyas için "Puan"ın kendi sapması yalnızca 1.67 px,
         yani sorun OHP'ye özgüydü. **Sebep alignment değil GENİŞLİK:**
         iki dize de sağa yaslıyken merkezleri, genişlik farkının YARISI
         kadar ayrışır — "OHP" 3 karakter/9px (19.53 px ink), değer 5
         karakter/11px (33.67); (33.67−19.53)/2 = 7.07. "Puan"da fark
         tesadüfen küçük (26.05 vs 29.39), o yüzden orada göze batmıyor.
       - **Çözüm sihirli bir kaydırma DEĞİL, kutuyu içeriğe eşitlemek:**
         sütun 52 → **`_kOhpColumnWidth = 34`** (değerin ink genişliği) ve
         başlık `TextAlign.right` → **`center`**. Kutu daralınca SAĞ kenar
         yerinde kalır (boşluk `Expanded` "Oyuncu"ya gider), yani 44 px'lik
         OHP↔Puan hizası ve değerlerin konumu HİÇ değişmez. **Değerler
         sağa yaslı KALMALI** — başlığı ortalamak için değerleri de
         ortalamak, 1 basamaklı bir ortalamada (`9.50`) ondalık hizasını
         bozardı. Web'de aynı sayı `w-[34px]`; ölçülen kalan sapma 0.16 px.
       - **Test SIHIRLI SAYIYI değil SÖZLEŞMEYİ pinliyor** (Parça 81'in
         deseni): üç parça birden — başlık ve değer kutuları AYNI
         genişlikte + başlık `center` + değer `right` + **kutu genişliği
         gerçekten değerin ink genişliği mi** (`TextPainter` ile aynı
         stille ÖLÇÜLEREK, `closeTo(34, 1)` sabitiyle değil). Üçü birden
         gerekli: yalnızca genişlik eşitliğine bakan bir test eski hâlde de
         geçerdi (ikisi de 52'ydi) — nitekim negatif eşte önce o geçti,
         hatayı `TextAlign` yakaladı (`Expected: TextAlign.center /
         Actual: TextAlign.right`).
     - **(3) Tahta alt şeridi.** `- kelime X2 · - kelime X3` legend'ı
       silinip yerine Hamleler/Mesajlaşma ile AYNI stilde (SpaceMono 12
       bold, `letterSpacing 0.5`, `kAccent`) bir "Nasıl Oynanır?" butonu
       kondu; soru-işareti ikonu `_HelpIconPainter` ile web'in SVG
       path'lerinden birebir çizildi (`RelationIcons` ilkesi — glyph
       kopyalanmaz, aynı vektör kullanılır). Yeni opsiyonel `onOpenHelp`
       prop'u; verilmezse buton hiç çizilmez. İKİ oyun ekranı da
       `showHelpModal(context)` bağladı (bilinçli kod tekrarı çifti).
       **Bilgi kaybı yok:** X2/X3 zaten tahtanın kendi filigranlarında ve
       kurallar ekranında yazılı.
     - **Test — negatif eş doğrulamasıyla, ÜÇÜ AYRI AYRI:** (a)
       `setup_screen_test.dart` — mevcut "oyun başlar" testi artık uyarıyı
       görüp DEVAM'a basıyor, artı iki YENİ test (girişli kullanıcıda
       uyarı HİÇ çıkmamalı; ✕ ne oyun başlatmalı ne giriş penceresi
       açmalı); (b) `score_card_test.dart`'ın OHP testine iki sütunun
       sağ kenar farkını 44'e sabitleyen bir assertion; (c)
       `game_screen_test.dart` — legend metinlerinin YOK, "Nasıl
       Oynanır?"ın VAR olduğu ve dokununca kuralların açıldığı. Üç lib
       değişikliği ayrı ayrı geri alınınca üçü de GERÇEKTEN düştü
       (`Found 0 widgets with text containing lütfen giriş yapın`;
       `Expected: a numeric value within <0.5> of <44> Actual: <52.0>`;
       `Found 0 widgets with text "Nasıl Oynanır?"`), geri konunca yeşile
       döndü.
     - **Test yazarken düşülen iki tuzak (kayda geçsin):** (1) kurallar
       penceresinin varsayılan adımı "NASIL OYNANIR?" DEĞİL **"HIZLI
       BAŞLANGIÇ"** — başlığı tahminle yazan assertion 0 widget buldu;
       (2) `auth_test.dart`'ın hesap menüsü testi `find.textContaining
       ('Nasıl Oynanır?')` kullanıyordu ve artık İKİ eşleşme buluyor
       (menü maddesi + tahta şeridi) — emoji önekiyle TAM eşleşmeye
       (`'❓  Nasıl Oynanır?'`) çevrildi. **Yeni bir yere var olan bir
       metni eklerken, o metni arayan MEVCUT testleri de tara.**
     - **Web duman testi de bu değişiklikle İKİ KEZ kırıldı** (ayrıntı ve
       kalıcı ders kök `CLAUDE.md`'de): Playwright'ın `getByRole(name:)`
       eşleşmesi varsayılan olarak büyük/küçük harf DUYARSIZ ALT DİZE
       arıyor → "Nasıl **Oyna**nır?" `OYNA` butonuyla çakıştı; `exact:
       true` eklenince bu sefer 0 sonuç, çünkü `exact` aynı zamanda
       harf DUYARLI ve DOM metni `Oyna` (büyük harf yalnızca CSS
       `uppercase`). Doğrusu `{ name: 'Oyna', exact: true }`.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       405/405 yeşil** (402'den +3). Web `npm run lint` + `npm run build`
       + `npm run test` (Playwright, 2 passed) temiz. `kelimeki_core`'a
       hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (web yarısı aynı gün, aynı
       dalda) → kök `CLAUDE.md` + `TESTING.md` aynı commit'te güncellendi
       (Parça Bitirme Kontrol Listesi madde 1).
     - **Doğrulama sınırı:** cihazda görsel/dokunma teyidi kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 1/4'e maddeler eklendi.

   - ✅ **Parça 93 — `HelpModal` metin paritesi: denetlendi (TEMİZ çıktı) ve
     artık bir testle bağlı (14 Ağustos 2026, yeni
     `test/help_text_parity_test.dart`):** "Sonraya Bırakılan İşler"in ilk
     maddesi kapandı. Parça 90 hukuki metinleri bağlamıştı; `HelpModal`'ın
     aynı "birebir kopya" sözleşmesi hâlâ yalnızca bir YORUM satırıyla
     korunuyordu — ve o sözleşme bu projede bir kez zaten kırılmıştı
     (Gizlilik metni dört gün bayat kalıp kullanıcıya kendi verisi hakkında
     yanlış bilgi verdi).
     - **Denetim sonucu TEMİZ:** 11/11 bölüm başlığı, 9/9 Hızlı Başlangıç
       maddesi portta var; paragrafların 30/40'ı normalize edilmiş hâliyle
       BİREBİR, kalan 10'un hepsi açıklanabilir (9'u uzunluk filtresine
       takılan bölüm başlığı, 1'i iki tarafın da KENDİ motorundan okuduğu
       `BINGO_BONUS`/`$bingoBonus`). Yani düzeltilecek bir sapma YOKTU —
       değerli olan bulgu değil, bundan sonrasını koruyan test.
     - **Vekil olarak "Son güncelleme" KULLANILAMADI** (hukuki metinlerdeki
       çözüm): `HelpModal.tsx`te öyle bir damga yok. Onun yerine metnin
       YAPISI vekil alındı — web'de makine-okunur duran `<Section title="…">`
       ve `<QuickItem icon="…">` listeleri porta karşı doğrulanıyor. Bu, asıl
       korkulan hata sınıfını tam olarak yakalıyor: **web'e yeni bir bölüm
       eklenip porta eklenmemesi.** Parça 66'nın "Rütbeler ve Ödüller"i tam
       böyle kaçabilirdi.
     - **Test kendi regex'ine karşı da korunuyor:** başlık/ikon sayısına bir
       ALT SINIR (≥11 / ≥9) konuldu — web JSX'i yeniden düzenlenirse regex
       sessizce 0 eşleşme bulup "geçemez". Bu, `legal_text_test`in
       `isNotNull` kontrolüyle aynı refleks.
     - **İki ek değişmez de pinlendi:** rütbe tablosunun İKİ tarafta da elle
       yazılmadığı (`RANK_TIERS`/`kRankTiers` — dördüncü bir elle senkron
       kopya açılırsa eşik değişiminde ilk sessizce ayrışacak yer orası) ve
       bingo bonusunun motordan okunduğu.
     - **DÜRÜST SINIR (teste de yazıldı):** bu test var olan bir paragrafın
       İÇİNDEKİ cümle değişikliğini YAKALAMAZ. Tam metin karşılaştırması
       JSX ↔ Dart arasında kırılgan olurdu (web cümleyi `<strong>`larla
       parçalıyor, port `**` ile işaretliyor; biri `{BINGO_BONUS}` diğeri
       `$bingoBonus` gömüyor) — o ayrışma elle denetim istiyor, bugünkü tur
       onu yaptı.
     - **Denetim aracının kendisi İKİ KEZ yanlış cevap verdi, ikisi de
       ölçümle yakalandı — kayda değer:** (1) ilk çıkarıcı web'i
       `export function HelpModal`ten dilimliyordu, ama o fonksiyon dosyanın
       SONUNDA (satır 415), içerik ondan önceki const'larda → "web paragraf:
       0" ile TÜM metin elenmişti; (2) Dart tarafında bitişik dize
       birleştirmesi (`'a'\n'b'`) hesaba katılmayınca her paragraf parçalara
       bölünüp 137 sahte "eksik" üretti. **Ders: bir parite denetimi
       "fark bulundu" derse önce ARACI şüphelen** — bu iki artefakt
       düzeltilmeden önce rapor, gerçekte var olmayan onlarca eksik
       gösteriyordu; körlemesine "düzeltmeye" kalksaydım çalışan metni
       bozardım.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 409/409
       yeşil** (405'ten +4). **Negatif eş:** web'e sahte bir
       `<Section title="Yepyeni Bölüm">` eklenince test GERÇEKTEN korkulan
       hata mesajıyla düştü (`Web'de "Yepyeni Bölüm" bölümü var, portta
       YOK`), web dosyası geri alınınca yeşile döndü. `kelimeki_core`'a ve
       üretim koduna hiç dokunulmadı — yalnızca yeni bir test.

   - ✅ **Parça 94 — rütbe tablosunun TS ↔ Dart yarısı da testle bağlandı
     (14 Ağustos 2026, yeni `test/rank_tiers_parity_test.dart`):** Parça
     93'ün açtığı soruyu ("bu 'elle senkron' kopyayı hangi test zorluyor?")
     projedeki EN ÇOK uyarılan kopyaya sordum ve cevap "hiçbiri" çıktı.
     - **Mevcut testler bu ayrışmayı yapısal olarak GÖREMİYORDU:**
       `league_rewards_test.dart` yalnızca İÇ tutarlılığı ölçüyor (ödül =
       eşik/10, kümülatif toplamların farklılığı, sınır davranışı). Web'de
       bir eşik değişip portta değişmese o testlerin HEPSİ geçmeye devam
       ederdi — kural kendi içinde tutarlı kalır, yalnızca iki platform
       ayrışırdı. Üç dosyanın da başlığındaki "hiçbir derleyici/test bunu
       yakalamaz" cümlesi kelimesi kelimesine doğruydu.
     - **Test `color_tokens_test`in desenini izliyor:** web'in
       `src/utils/leagueRank.ts`'ini OKUYUP `RANK_TIERS` satırlarını
       ayrıştırıyor ve `kRankTiers` ile alan alan karşılaştırıyor
       (ad/harf/eşik/ödül/renk). **Renk karşılaştırması çözülmüş değer
       üzerinden** — web hex literal yazıyor, port palet token'ı
       (`kAccent` gibi) kullanıyor; yanlış token seçilirse yakalanır.
     - **Ayrıştırıcı kendi sessiz başarısızlığına karşı korunuyor** (Parça
       93'ün aynı refleksi): satır sayısına ≥9 alt sınırı var, yani TS
       dosyası yeniden düzenlenip regex 0 eşleşme bulursa test "geçemez".
     - **SQL yarısı o gün BİLİNÇLİ kapsam dışıydı — ve gerekçesi 22 Ağustos
       2026'da ÖLÇÜLÜP ÇÜRÜTÜLDÜ.** Buraya "`_award_league_rewards`ın güncel
       tanımı tek bir migration dosyasında DURMUYOR, yani bir birim testi
       bunu yapamaz" diye yazılmıştı. Sayıldı: fonksiyonu tanımlayan BEŞ
       migration var, ama SONUNCUSU (`20260812125039`) tam gövdeyi taşıyor —
       yani geçerli tanım TEK dosyada ve ayrıştırılabilir. `verify-league-tiers`
       o dosyayı ADA GÖRE bulup üç `(values ...)` listesini `leagueRank.ts`
       ile karşılaştırıyor; web CI'da koşuyor ve `paths` listesine
       `supabase/migrations/**` eklendi (yoksa yalnızca migration değişen bir
       PR'da sessiz kalırdı — kilidin tam gerektiği yer). **Ders: "bir test
       bunu yapamaz" cümlesini yazmadan önce SAY** — burada dayanak beş
       dosyaydı, ama belirleyici olan yalnızca sonuncusuydu.
     - **Bayat iddialar aynı commit'te düzeltildi:** üç dosya (`leagueRank.ts`,
       `league_rank.dart`, kök `CLAUDE.md`) hâlâ "hiçbir derleyici/test bunu
       yakalamaz" diyordu — artık yarısı yanlış. Üçü de "TS ↔ Dart testli,
       SQL korumasız" olarak güncellendi. **Bir korumayı eklerken onun
       yokluğunu anlatan cümleleri de ara** — aksi halde bir sonraki oturum
       var olan testi bilmeden çalışır.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 411/411
       yeşil** (409'dan +2) — tablo şu an GERÇEKTEN senkron. **Negatif eş:**
       TS'te Usta'nın eşiği 250→300 yapılınca test GERÇEKTEN
       `4. kademe (web: "Usta") — EŞİK ayrışmış / Expected: <300> Actual:
       <250>` ile düştü, web dosyası geri alınınca yeşile döndü.

   - ✅ **Parça 95 — Canlı oyun cihaz turu (TESTING.md bölüm 11): beş bulgu,
     ÜÇÜ web'de (14 Ağustos 2026):** Bölüm 11 ilk kez iki gerçek hesapla
     baştan koşuldu. Çıkan beş bulgunun yalnızca ikisi porta özgüydü; üçü
     web'in kendi hatasıydı ve port ya doğru davranıyordu ya da aynı hatayı
     web'den miras almıştı. **Bu turun en genel dersi:** paylaşılan bir
     kuralı "her zaman türet" diye sağlamlaştırırken, o kanalı kullanan
     MEŞRU/TAZE mesajların da yutulup yutulmadığını sor.
     - **(1) Boş taslakta OYNA — web'in Canlı ekranı sessizdi (web
       düzeltmesi).** `OnlineGameScreen.tsx:760`'ta `if
       (placedCoords.length === 0) return;` vardı: hiç taş koymadan OYNA'ya
       basınca hiçbir şey olmuyor, mesaj satırında bir önceki metin
       ("Taşlar rafa geri alındı") duruyordu. **Port BU KONUDA ZATEN
       DOĞRUYDU** — Parça 88'de bu guard bilerek kaldırılmış ve
       `_handlePlay`e gerekçesi yazılmıştı; web'in Canlı ekranı geride
       kalmıştı (yerel ekran `App.tsx` de doğruydu: PLAY'i reducer'a
       dispatch ediyor, reducer aynı validator'dan "Harf yerleştirilmedi."
       üretiyor). Guard kaldırıldı; `validatePlacementStructural` zaten boş
       taslakta doğru mesajı döndürüyor ve `moveStatus` boş taslakta `null`
       olduğundan mesaj görünür oluyor.
     - **(2) Gönderim hatası mesaj satırında HİÇ görünmüyordu (İKİ
       platformda birden — en ciddi bulgu).** Uçak modunda kelime koyup
       OYNA'ya basınca web'de hiçbir şey olmuyor, portta "GÖNDERİLİYOR"
       ~5sn sonra sessizce eski hâline dönüyordu. Kök sebep 6 Ağustos'taki
       `myTurnValidNote`/`myTurnNote` kuralı: "geçerli taslak + sıra sende"
       iken mesaj satırı KOŞULSUZ türetiliyor. O kural bayat mesajlara
       karşı doğruydu ama **gönderim hatası bayat değil** — kullanıcının az
       önce bastığı butonun sonucu; hamle reddedilince taşlar tahtada
       kaldığından taslak hâlâ geçerli oluyor ve hata sonsuza dek
       görünmüyordu. Çözüm iki tarafta da aynı: hatalar reducer'ın
       `state.message`ına DEĞİL ayrı bir `submitError`/`_submitError`
       kanalına yazılıyor ve türetilen notlardan ÖNCE geliyor; taslağın
       imzası (hücre+harf+jokerin harfi) değiştiği an sıfırlanıyor.
       Reducer'a hiç dokunulmadı (motor dosyası — golden vector paritesi).
       **`App.tsx`e de uygulandı** çünkü orada ulaşılabilir bir dal var:
       sunucu sözlüğü kelimeyi reddederse (`moveStatus` YEREL sözlükle
       hesaplandığından taslak geçerli görünür) mesaj yutuluyordu. **Portun
       yerel ekranı bilerek DEĞİŞMEDİ** — orada sözlük tamamen pakette,
       sunucuya hiç sorulmuyor, yani ulaşılabilir bir gönderim hatası YOK;
       eklemek ölü kod olurdu.
     - **(3) Sohbet ön plana dönüşte tazelenmiyordu (İKİ platformda
       birden).** Kullanıcı "app'den web'e mesajlar anında gidiyor ama
       web'den app'e gelmiyor, setup'a çıkıp girince geliyor" dedi.
       Asimetrinin sebebi kanal değil KURTARMA yolları: oyun state'i ÜÇ
       yoldan tazeleniyor (Realtime + periyodik + ön plana dönüş) ama
       sohbet YALNIZCA Realtime'a bağlıydı — oysa "arka planda websocket
       askıya alınır, kaçırılan olay bir daha oynatılmaz" gerekçesi (web
       `OnlineGameScreen.tsx`'te 340-345'te yazılı) iki tablo için de
       aynen geçerli. iPad'de iki Safari sekmesi arasında gidip gelmek tam
       da bu durumu üretiyor: web sekmesine yazarken app sekmesi arka
       planda. Aynı üçlü dinleyici + aynı 1sn debounce sohbete de kuruldu
       (portta `didChangeAppLifecycleState`'in resume dalına `_fetchChat()`).
       **Popup bilerek tetiklenmiyor** — arka planda biriken beş mesaj için
       beş popup değil, tek okunmamış rozeti; abonelik de yeniden
       kurulmuyor (`_loadChat` = veri + abonelik, `_fetchChat` = yalnız veri).
     - **(4) Oyun sonu modalının hamle geçmişi Canlı'da BOŞ (port
       düzeltmesi).** "Oyun Geçmişi" linki "Henüz kazanılmış bir puan yok."
       diyordu, ama AYNI ekranın tahta altındaki "Hamleler" linki dolu
       listeyi gösteriyordu. Yapısal sapma: web'in `GameOver`u
       `onOpenHistory`i bir **callback** olarak alıp HANGİ state'in
       gösterileceğini ebeveyne bırakıyor (`App.tsx` kendi state'ini,
       `OnlineGameScreen.tsx` sunucu satırlarından türettiği `historyState`i
       geçiyor); port bu kararı widget'ın İÇİNE gömüp `state`i doğrudan
       kullanıyordu — Canlı'da reducer'ın `moveHistory`si boş olduğundan
       sonuç boş liste. `onOpenHistory` artık ZORUNLU parametre (iki çağrı
       yeri de kararı vermek zorunda) ve iki yer de tek bir `_historyState`
       getter'ından besleniyor.
     - **(5) "Çevrimdışı" rozeti okunmuyordu (web, kullanıcı isteği).**
       Board alt şeridindeki gösterge `text-[8px]`ti; kardeşleri
       (Hamleler · Mesajlaşma · Nasıl Oynanır?) `text-[12px] font-mono
       font-bold tracking-[0.5px]`. Tam da çevrimdışıyken okunması gereken
       tek gösterge şeridin en küçük yazısıydı — kardeşlerle birebir aynı
       sınıflara çekildi (yalnız rengi farklı). **Portta bu göstergenin
       KARŞILIĞI HİÇ YOK** (`useOnlineStatus` porta hiç girmemiş); bulgu
       (2)'nin düzeltmesi "app hiçbir şey söylemiyor" kısmını kapattığından
       ayrı bir bağlantı göstergesi eklemek bu turun kapsamına alınmadı —
       "Sonraya Bırakılan İşler"e yazıldı.
     - **Doğrulama:** `flutter analyze` temiz; **tam takım 414/414 yeşil**
       (411'den +3 — üçü de yeni). `npm run lint` + `npm run build` temiz,
       Playwright duman testleri 2/2. **Üç negatif eş ayrı ayrı koşuldu:**
       (a) GameOver'a `_historyState` yerine `state` geçilince yeni test
       düştü; (b) `submitError` türetilen notlardan SONRAYA alınınca
       "Bağlantı yok." bulunamadı (kullanıcının gördüğü semptomun birebir
       kendisi); (c) resume dalından `_fetchChat()` çıkarılınca sohbet
       tazeleme testi düştü. **Mevcut "sunucu reddi mesaj satırına düşer"
       testinin bu hatayı neden göremediği kayda değer:** o test PAS GEÇ
       kullanıyor, pas'ta tahta boş, dolayısıyla `myTurnNote` hiç devreye
       girmiyor — yeni test taşları TAHTADA bırakarak reddettiriyor.
     - **Cihazda doğrulanacak:** beş düzeltmenin hiçbiri gerçek iki-hesap
       akışında henüz koşulmadı; maddeler `mobile/TESTING.md` bölüm 11 ve
       kök `TESTING.md` bölüm 2'ye eklendi.

   - ✅ **Parça 96 — Canlı oyun çevrimdışıyken ne diyor? İki sessiz yol
     kapatıldı (14 Ağustos 2026, kullanıcı YAYINDAKİ webde bildirdi):**
     Kullanıcı ana ekrana eklediği webde uçak modunu denedi: (a) listeden
     hamle bekleyen bir Canlı oyuna dokununca ekran beyaz "Yükleniyor…"da
     asılı kaldı ve ancak çevrimiçi olunca yüklendi, (b) tahta açıkken
     hamle yapınca hiçbir şey olmadı. Ardından doğru soruyu sordu:
     *"Offline sadece YZ oyunlar için mi geçerli? Eğer öyleyse ... bir
     uyarı gerekir (hem web hem de app için)"*.
     - **Cevap evet ve bu bir tasarım kararı:** Canlı oyunda tahta/raf/torba
       sunucuda otoriter (`online_game_states`/`online_game_secrets`);
       offline dayanıklılık yalnızca yerel/YZ için var (localStorage +
       `cloudSaveMirror`). Sorun kuralın kendisi değil, kullanıcının bunu
       yalnızca SESSİZLİKTEN çıkarmak zorunda kalmasıydı.
     - **(a) Sonsuz "Yükleniyor…" — "ekranı koru" davranışının kapsam
       hatası.** İki platformda da yükleme başarısız olunca sessizce
       dönülüyordu (`if (!publicState) return` / `if (snap == null)
       return; // ağ hatası — ekran korunur`). Bu TAZELEMEDE doğru (bayat
       veri hiç veriden iyidir) ama İLK yüklemede korunacak bir şey yok:
       `_loaded` hiç true olmuyor, ekran sonsuza dek yükleniyor kalıyor.
       Artık ilk yükleme başarısızsa `loadFailed`/`_loadFailed` işaretlenip
       ne olduğunu anlatan bir panel + **TEKRAR DENE** + **← CANLI LİSTESİ**
       gösteriliyor; tazeleme davranışı DEĞİŞMEDİ.
     - **(b) Hamle hatası artık ham ağ metni değil.** Parça 95'in
       `submitError`i hatayı görünür yapmıştı ama içerik
       "ClientException: Failed to fetch…" gibi bir şeydi. Artık ağ katmanı
       hataları kısa bir uyarıya çevriliyor; **sunucunun KENDİ reddi
       ("Sıra sende değil.") olduğu gibi kalıyor** — bilinmeyen bir hatayı
       "bağlantı yok" diye maskelemek hata ayıklamayı imkânsız kılardı
       (aynı ilke: `friendlyAuthMessage`).
     - **Metinler TEK KAYNAKTA ve testli:** `src/utils/offlineNotice.ts` ↔
       `mobile/app/lib/src/util/offline_notice.dart`. Yeni
       `test/offline_notice_test.dart` web dosyasını OKUYUP üç metni de
       karşılaştırıyor (`color_tokens_test`/`rank_tiers_parity_test`
       deseni) — biri değişip öteki kalırsa test düşer.
     - **Metin bilerek "çevrimdışısın" DEMİYOR, "sunucuya ulaşılamıyor"
       diyor.** Kullanıcının önerdiği cümle "Şu anda çevrimdışısınız"dı ama
       aynı metin sunucu erişilemez olduğunda da DOĞRU olmak zorunda ve
       Flutter tarafında gerçek bir bağlantı API'si yok (`useOnlineStatus`
       portu hâlâ eksik — bkz. "Sonraya Bırakılan İşler"). İçeriğin üç
       parçası korundu: sorun ne, ne yapmalı, alternatif ne (YZ).
     - **`isNetworkError` `dart:io` KULLANMIYOR** (web derlemesini kırardı)
       — tip yerine metin eşlemesi; kalıplar arasında **Safari'nin "Load
       failed"i** de var, port iPad Safari'de test edildiğinden şart.
     - **Doğrulama:** `flutter analyze` temiz, **tam takım 420/420** (414'ten
       +6). `npm run lint`/`build` temiz, Playwright 2/2. **Üç negatif eş:**
       `_loadFailed` ataması kaldırılınca panel testi "Yükleniyor…" bulup
       düştü; `isNetworkError` dalı kaldırılınca kısa uyarı bulunamadı;
       web'deki metin tek kelime değiştirilince parite testi "mesaj satırı
       metni ayrışmış" dedi.
     - **(a)'nın WEB yarısı ilk sürümde İŞE YARAMADI (aynı gün, cihazda
       bildirildi):** yalnızca "null döndü" dalı ele alınmıştı, oysa web'de
       `getMyOnlineRack` hatada `throw` ediyor → `Promise.all` reddediliyor →
       `setLoadFailed` satırına hiç ulaşılmıyordu. Üç çağrı tek try/catch'e
       alındı. **Portta bu delik yoktu** (`loadGame` zaten üçünü de sarıyor)
       ve Flutter testi tam bu yüzden geçmişti — test doğruydu, web'in
       FARKLI hata sözleşmesini temsil etmiyordu. Ders: aynı düzeltmeyi iki
       platforma uygularken "hata nasıl yüzeye çıkıyor?" sorusunu her
       platform için ayrı sor.
     - **Sekmelerin kendisi de konuşuyor (aynı gün, ikinci tur):** panelden
       dönen kullanıcı Canlı sekmelerinde "davetiniz yok"/"Yükleniyor…"
       görüyordu. Panelin geri butonu hedef adı taşımayan **"Geri Dön"e**
       çevrildi; `live_games_tab`'ın üç alt sekmesi çevrimdışıyken tek bir
       **"İnternet bağlantısı yok"** gösteriyor; **YZ sekmesi bilinçli
       olarak farklı konuşuyor** — orada oynanabilir bir şey var, o yüzden
       linkli bir öneri ("Hemen oyun aç." → `_creatingLocal = true`, "+ YENİ
       YAPAY ZEKA OYUNU AÇ" ile aynı). Öneri yalnızca gösterilecek KAYIT
       YOKKEN çıkar: devam eden YZ oyunları çevrimdışı da oynanabiliyor.
       **Mekanizma web'den farklı, metin aynı:** web `useOnlineStatus`
       kullanıyor, portta bağlantı API'si olmadığından sinyal `_loadFailed`
       ("son yükleme sunucuya ulaşamadı").
     - **Aynı turun iki küçük düzeltmesi:** "Hemen oyun aç." metin-içi link
       DEĞİL gerçek `NeoButton` (turuncu, "+ YENİ YAPAY ZEKA OYUNU AÇ" ile
       aynı varyant); ve öneri artık `saves == null` iken GÖSTERİLMİYOR —
       liste bilinmiyorken "hiç oyunun yok" demek erken yargı, çevrimdışıyken
       ağ denemesi bitince aynadan gerçek liste geliyor.
     - **Kelime anlamı porta DOKUNMADI:** web'de çevrimdışı "anlamı
       bulunamadı" çıkıyordu (6.3 MB `meanings.json` precache'te yok) ve
       oraya web'e ÖZEL bir mesaj eklendi; portta anlamlar
       `assets/dictionary/meanings.db` ile pakette olduğundan çevrimdışı
       zaten çalışıyor — eklenecek bir şey yok.
     - **App turunda çıkan İKİ düzeltme (aynı gün):**
       - **Panel BOZUK çiziliyordu** (kullanıcı ekran görüntüsüyle bildirdi):
         kart ekran boyu beyaz bir dikdörtgene dönüşüyordu. Sebep `NeoBox` —
         çocuğunu `SizedBox.expand` ile sarıyor, yani gelen kısıtları
         DOLDURUYOR; boyutu dışarıdan belli olan yerler için tasarlanmış,
         `Center` altında shrink-wrap ETMİYOR. Düz bir `DecoratedBox`a
         çevrildi. **Ölçüldü:** kart 420x900 ekranda 900 → **251** px;
         negatif eş NeoBox geri konunca 900'e dönüyor ve yeni test düşüyor.
       - **Kelime anlamı çevrimdışı "bulunamadı" diyordu** — ve bu, bir
         önceki turda YAZDIĞIM iddiayı çürüttü. "Portta sözlük pakette,
         çevrimdışı çalışır" NATIVE için doğru ama portun test ortamı olan
         **Flutter web derlemesi** için YANLIŞ: orada asset de HTTP ile
         çekiliyor (`MeaningStore._openWeb` ilk açılışta 6 MB'ı IndexedDB'ye
         kopyalar) ve uçak modunda o çekim düşüyor. `MeaningStore` artık
         açılış hatasını `unavailable` bayrağında tutuyor, modal o durumda
         web'le AYNI metni gösteriyor (parite testine de eklendi).
         **Ders: "asset pakette" demek her derleme hedefi için aynı şeyi
         ifade etmiyor.**
     - **Bağlantı sinyali porta geldi (`connectivity_plus`, kullanıcı
       onayıyla):** Çevrimdışı mesajı Setup'ta uzunca "Yükleniyor…"dan sonra
       çıkıyordu — kullanıcı *"hemen çıkmalı bence"* dedi. Kök sebep
       yapısaldı: port çevrimdışı kararını bir ağ çağrısının BAŞARISIZ
       olmasını bekleyerek veriyordu (`_loadFailed`) ve uçak modunda Supabase
       auth'un token yenileme tekrarları bunu saniyelere çıkarıyordu; web ise
       `navigator.onLine` ile ANINDA karar veriyordu. `util/online_status.dart`
       (web `useOnlineStatus` portu) `AppServices.onlineStatus` olarak
       eklendi; `LiveGamesTab`, `SetupScreen` ve `RecentGamesSection` bunu
       dinliyor. **`_loadFailed` yolları KALDIRILMADI** — ikisi birlikte
       çalışıyor: bağlantı sinyali HIZLI ama iyimser ("arayüz var" ≠
       "internet var": captive portal, bozuk DNS), başarısız yükleme YAVAŞ
       ama kesin; mesaj ikisinden biri doğruysa çıkıyor.
       - **Testi ağ cevabını beklemediğini KANITLIYOR:** sahte uç asılı bir
         future dönüyor (`listHangs`), yani test ancak karar bağlantı
         sinyalinden geliyorsa geçiyor. Negatif eş: koşul kaldırılınca
         "İnternet bağlantısı yok" bulunamıyor.
       - **Doğrulama sınırı:** `pubspec.lock` bu ortamda yenilendi (yalnızca
         yeni paketler + Dart kısıtı; başka sürüm oynaması yok) ama
         **Android/iOS derlemesi burada koşulamıyor** — plugin'in native
         tarafı yalnızca CI'daki `mobile-build.yml` ile doğrulanabilir.
     - **Yan etki, 15 Ağustos 2026'da cihaz turunda ölçüldü — bu değişiklik
       AYNI GÜN yazılmış BAŞKA bir test maddesini geçersiz kıldı:** Parça
       90, "uçak modunda bir Canlı davete Kabul Et/Reddet'e bas → 'İşlem
       başarısız oldu.' çıkmalı" maddesini eklemişti; birkaç saat sonra bu
       parça `LiveGamesTab`'ın ÜÇ alt sekmesini de çevrimdışı kapısının
       arkasına aldığından davet kartı artık hiç çizilmiyor — basılacak bir
       buton yok. Kullanıcı doğru olanın bu olduğunu belirtti ("bu şekilde
       iyi bence"): hata sonrası açıklama yerine en baştan "burada
       yapılacak bir şey yok" demek. **`kFriendActionFailed` ölü kod
       DEĞİL** — bağlantı sinyali "online" derken isteğin düştüğü durumlar
       (captive portal, sunucu/RLS hatası, sekme çizildikten sonra kopan
       bağlantı) hâlâ o dala düşüyor; ayrıca `FriendsModal`'ın kendi yanıt
       akışında çevrimdışı kapısı HİÇ YOK (grep ile doğrulandı), yani Parça
       89'un maddesi orada aynen geçerli. Kod değişmedi, `mobile/TESTING.md`
       bölüm 11'deki madde gerçeğe çekildi.
       **Ders:** bir ekranı çevrimdışı kapısının arkasına alırken, o ekranın
       İÇİNDEKİ kontroller hakkında yazılmış test maddelerini de tara — kapı
       onları sessizce ulaşılamaz kılıyor ve madde bir sonraki turda "hata"
       gibi görünüyor.
     - **Cihazda doğrulanacak:** iki senaryo da `mobile/TESTING.md` bölüm 11
       ve kök `TESTING.md` bölüm 2'ye eklendi.

   - ✅ **Parça 97 — tahta alt şeridindeki "Çevrimdışı" uyarısı porta hiç
     girmemişti (14 Ağustos 2026, `board_widget.dart`, `game_screen.dart`,
     `online_game_screen.dart`, `setup_screen.dart`, `live_games_tab.dart`):**
     Kullanıcı Parça 96'nın deploy'undan sonra bildirdi: *"Bir de tahta altında
     çevrimdışı (kırmızı) uyarıyı da göremedim."*
     - **Web önce okundu (kuralın ilk adımı) ve orada SORUN YOKTU:**
       `Board.tsx` `useOnlineStatus()`ü KENDİ İÇİNDE çağırıyor ve `!online`
       iken şeridin sağ grubunda (`gap-2` = 8px, "Nasıl Oynanır?"ın solunda)
       kırmızı bir "Çevrimdışı" basıyor — bu turda (#256) puntosu da
       kardeşleriyle eşitlenmişti. Yani bildirilen şey bir REGRESYON değil,
       portun hiç sahip olmadığı bir gösterge: iki `CLAUDE.md` de bunu
       "Flutter portunda karşılığı HİÇ YOK" diye zaten yazıyordu.
     - **Bu parçayı MÜMKÜN KILAN şey Parça 96:** gösterge bir bağlantı sinyali
       ister ve o sinyal porta dün geldi (`OnlineStatus`). Ondan önce
       eklenebilecek tek şey `_loadFailed` gibi dolaylı bir vekildi — yerel/YZ
       oyununda hiç ağ çağrısı olmadığından orada HİÇBİR ZAMAN tetiklenmezdi,
       yani rozet tam da en çok gerektiği ekranda ölü kalırdı.
     - **Enjeksiyon, hook değil:** web'de her `Board` göstergeyi kendiliğinden
       alıyor; Flutter'da `BoardWidget` saf bir widget olduğundan
       `OnlineStatus? onlineStatus` prop'u eklendi ve İKİ oyun ekranı da
       (`game_screen.dart` + `online_game_screen.dart` — bilinçli kod tekrarı
       çifti) geçiyor. Verilmezse uyarı hiç çizilmez: salt-okunur önizlemeler
       (`hideFooter`) ve mevcut testler etkilenmedi.
     - **Yalnızca sağ grup `ListenableBuilder` içinde** — gerçek senaryo
       kullanıcının oyun AÇIKKEN uçak moduna geçmesi; doğrudan okuma o anda
       hiçbir şey değiştirmezdi (ekran yeniden inşa edilmiyor). Kapsam bilerek
       dar: Parça 23'ün dersi gereği bağlantı değişimi 169 hücrelik tahtayı
       yeniden çizmemeli.
     - **Punto/renk tahminle DEĞİL, web'in sınıflarından birebir:**
       `text-[12px] font-mono font-bold tracking-[0.5px] text-red` →
       12/SpaceMono/bold/0.5/`kRed`. Test bunları SABİT SAYIYLA değil
       KARDEŞİYLE ("Nasıl Oynanır?") karşılaştırıyor — biri değişirse öteki de
       değişmek zorunda kalıyor (Parça 68'in "sabiti değil oranı kilitle"
       deseni).
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** (1)
       `game_screen_test.dart` — çevrimiçiyken uyarı YOK, ekranı YENİDEN PUMP
       ETMEDEN bağlantı düşünce ANINDA çıkıyor, stil kardeşiyle aynı, bağlantı
       dönünce kalkıyor. `ListenableBuilder` düz bir `Builder`a çevrilince test
       GERÇEKTEN düştü — yani reaktiflik iddiası kanıtlı, "prop var" değil.
       (2) `online_game_screen_test.dart` — yalnızca KABLOYU ölçen kısa bir
       test; `onlineStatus: widget.onlineStatus` satırı silinince GERÇEKTEN
       düştü. İkincisi şart, çünkü iki ekranın ayrışması derleyicinin
       göremediği klasik hata sınıfı.
     - **Testte üretim koduna debug setter EKLENMEDİ:** bağlantıyı açıp
       kapatmak için test-yerel bir `_ToggleOnlineStatus extends OnlineStatus`
       alt sınıfı (`super.fake()`, platform kanalına hiç dokunmuyor) —
       `AuthService.debugSetUser` emsali varken üretim yüzeyi büyütülmedi.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 424/424
       yeşil** (422'den +2). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** gerçek uçak modunda görsel teyit cihazda
       yapılmalı — `mobile/TESTING.md` bölüm 11'e madde eklendi. Web'in
       göstergesi de aynı turda (#256) düzeltilip henüz cihazda
       görülmediğinden ikisi BİRLİKTE kontrol edilmeli.

   - ✅ **Parça 98 — asıl kök sebep rozette DEĞİL bağlantı durumundaydı: kaçırılan
     `offline` olayı kalıcı kayıptı (14 Ağustos 2026, `useOnlineStatus.ts`,
     `online_status.dart`):** Kullanıcı AYNI bulguyu ikinci kez bildirdi
     (*"tahta altında çevrimdışı (kırmızı) uyarıyı da göremedim"*) — Parça
     97'de portun eksik göstergesini eklemiştim ama o turda web için
     *"sorun yok"* demiştim ve bunu KODU OKUYARAK söylemiştim.
     - **Bu sefer ÖLÇÜLDÜ:** `npm run build` + gerçek uygulama Chromium'da
       açılıp bir YZ oyunu başlatıldı, `context.setOffline(true)` ile uçak
       modu simüle edildi — rozet çıktı (12px, `rgb(220,38,38)`, Space Mono,
       kardeşinden 8px). Yani web'in RENDER'ı gerçekten doğruydu.
     - **Ama hook'ta gerçek bir boşluk vardı:** `useOnlineStatus` YALNIZCA
       `online`/`offline` olaylarını dinliyordu. Kullanıcı ana ekrana eklenmiş
       PWA'da test ediyor ve uçak modunu açmak için Kontrol Merkezi'ne
       çıkıyor — sayfa o anda askıya alınıyor, olay JS'e hiç ulaşmıyor, durum
       bayat `true` kalıyor ve rozet BİR DAHA çıkmıyor.
     - **Senaryo gerçek tarayıcıda BİREBİR üretildi:** `navigator.onLine`
       `addInitScript` ile kontrol edilebilir yapılıp OLAY ATEŞLENMEDEN false
       çekildi → rozet yok; `visibilitychange` gönderildi → rozet çıktı.
       **Negatif eş:** düzeltme `git stash`lenip yeniden derlenince öne
       dönüşten sonra da rozet ÇIKMADI (0) — kullanıcının gördüğü semptomun
       ta kendisi.
     - **Bu, kaçırılan olayın bu projede kalıcı kayba dönüştüğü ÜÇÜNCÜ yer:**
       sohbet Realtime'ı (Parça 95) ve bulut senkronu (Parça 44) aynı çareyi
       almıştı — "öne dönüşte gerçeği yeniden oku". Gerekçe iki kez yazılmış
       ama bu hook'a hiç uygulanmamıştı.
     - **Port da aynı kancayı aldı** (`OnlineStatus` artık
       `WidgetsBindingObserver`, `resumed`'da `refresh()`): `connectivity_plus`
       akışı da askıdaki uygulamada olay kaçırabilir. **Bu yarısı TESTSİZ
       KALDI:** üretim kurucusu platform kanalı istediğinden ve `fake()`
       bilerek observer kaydetmediğinden davranış widget testinde sınanamadı —
       ve tam bu yüzden CİHAZ turu onun tek kanıtı oldu (aşağı bkz.).
     - **Ders — "web'de sorun yok" da bir TEŞHİSTİR ve ölçüm ister.** Parça
       34'ün dersi ("ölçmeden YOK SAYMA") burada bir üst basamağa çıktı:
       render'ı doğru olan bir bileşen, onu BESLEYEN durum bayatladığı için
       hiç görünmeyebilir. Kullanıcı aynı şeyi ikinci kez bildiriyorsa
       kapatmadan önce zinciri UÇTAN UCA koştur.
     - Doğrulama: `npm run lint` + `npm run build` temiz, Playwright **3/3**
       (yeni kalıcı regresyon testiyle); `flutter analyze` temiz, tam takım
       **424/424**.
     - **CİHAZDA DOĞRULANDI (14 Ağustos 2026, kullanıcı): "her şey normal".**
       Kontrol maddesi uçak modunun Kontrol Merkezi'nden — yani uygulamadan
       ÇIKARAK — açılmasını istiyor, ki kök sebep tam oydu. **Bu tur, Parça
       97'nin göstergesini ve Parça 98'in öne-dönüş kancasını AYNI ANDA
       kapatıyor; portun resume kancası için de tek kanıt bu** (yukarıdaki
       "testsiz kaldı" notunun karşılığı: test yoksa cihaz turu opsiyonel
       değildir).

   - ✅ **Parça 99 — port artık hangi istemci olduğunu SÖYLÜYOR: platform
     telemetrisi (14 Ağustos 2026, yeni `util/platform.dart`,
     `game_record.dart`, `online_games_api.dart`, `online_game_screen.dart`):**
     Kullanıcı isteği ("Platform column'u da ekle"). Sunucu tarafı ve web
     yarısı aynı gün eklendi (bkz. kök `CLAUDE.md`); bu parça portun yarısı.
     - **Neden ŞİMDİ:** `games` satırında istemciyi söyleyen hiçbir alan
       yoktu ve bu alan geriye dönük DOLDURULAMAZ — port yayına çıktıktan
       sonra eklenirse lansmanın ilk günleri sonsuza dek ölçülemez kalırdı.
       Port yazmazsa satırlar boş platformla gider, yani bu değişikliğin
       varlık sebebi tam olarak portun kendisi.
     - **`dart:io`'nun `Platform.isIOS`'ü KULLANILMADI** — `dart:io` web
       derlemesinde yok, import etmek `flutter build web`i kırardı (portun
       test ortamı `mobile-build.yml`de gerçekten derleniyor). `kIsWeb` +
       `defaultTargetPlatform` her hedefte çalışıyor.
     - **Bilinmeyen hedefte `null`, uydurma değer DEĞİL:** masaüstü
       (macOS/Windows/Linux) yayınlanmıyor ama sunucudaki check kısıtında
       olmayan bir değer yollamak `games` insert'ini DÜŞÜRÜR — yani bir
       telemetri alanı yüzünden oyun KAYDI (skor, k-lig, hamle dökümü)
       kaybolur. Sütun nullable, `null` satırı sorunsuz kaydediyor.
     - **Yerel taraf `NewGameRecord`ta bir ALAN, `toJson`da hesaplanan bir
       değer DEĞİL:** kayıt çevrimdışı kuyruğa serileşip günler sonra
       gönderilebiliyor ve satır oyunun GERÇEKTEN oynandığı istemciyi
       anlatmalı (web de kuyruğa aynı şekilde yazıyor). Alan eklenmeden
       önce kuyruğa girmiş kayıtlarda `null` — `fromJson` bunu tolere
       ediyor, kayıt yine gönderiliyor.
     - **Canlı taraf AYRI bir tabloya yazıyor** (`online_game_clients`):
       Canlı'da `games` satırını SUNUCU yazdığından istemcinin kim olduğu
       oraya hiç ulaşmıyor. `reportPlatform` oyun ekranının `initState`inde
       BİR KEZ, `_refresh()` döngüsünün DIŞINDA kendi satırında çağrılıyor
       — telemetri, oyun durumu senkronuyla aynı kod yolunu paylaşmamalı
       (hatası oyunu etkilemesin) ve her Realtime olayında tekrar yazmanın
       anlamı yok (upsert olduğundan mükerrer çağrı zararsız, sadece
       gereksiz). Hata TAMAMEN yutuluyor; sunucu da yetkisiz/geçersiz
       girdide sessizce no-op dönüyor (canlıda doğrulandı).
     - **`submit_move`'a parametre EKLENMEDİ** — projenin en kritik RPC'si,
       lansman öncesi imza değişikliğinin riski kazancından büyük; gerekçe
       ve ölçüm kök `CLAUDE.md`'de.
     - **Değer kümesi testle bağlandı:** `test/client_platform_parity_test.dart`
       migration SQL'ini OKUYUP `kClientPlatforms` ile karşılaştırıyor
       (`color_tokens_test`/`rank_tiers_parity_test` deseni) — kısıt üç
       yerde geçtiğinden üçü de ayrı ayrı sayılıyor, ve `currentPlatform`ın
       her hedefte kümede (ya da null) kaldığı ayrıca doğrulanıyor.
     - **Fikstür `platform` HARİÇ karşılaştırılıyor:** `web_game_record.json`
       iki istemcinin AYNI satırı ürettiğini kanıtlar, ama bu alan tanımı
       gereği farklı olmak ZORUNDA. Test onu ayırıp kalan 20 sütunu bayt
       bayt karşılaştırıyor ve ayrıca "iki taraf da yazıyor + değerler
       kümede + BİRBİRİNDEN farklı" diyor — sonuncusu olmadan port web'in
       sabitini kopyalasa test geçerdi. Fikstürün `record` yarısı web'in
       ÜRETİM kodu koşturularak yeniden üretildi (Parça 65'in cerrahi
       yöntemi; anlamsal diff yalnızca iki `"platform": "web"` satırı).
     - **Negatif eş, İKİ AYRI kanıt:** `kClientPlatforms`e sahte bir değer
       eklenince parite testi GERÇEKTEN düştü (`does not contain 'desktop'`);
       `NewGameRecord.toJson`dan `platform` çıkarılınca iki fikstür testi de
       GERÇEKTEN düştü (`port platformu yazmıyor — lansman ölçülemez kalır`).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 427/427
       yeşil** (424'ten +3). `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (web yarısı + migration + admin
       paneli + Gizlilik Politikası) → kök `CLAUDE.md`/`README.md`/
       `TESTING.md` aynı commit'te güncellendi (Kontrol Listesi madde 1).
     - **Gizlilik metni İKİ tarafta birden güncellendi** — yeni bir kişisel
       veri toplandığında `PrivacyModal`/`legal_modals.dart` güncellenmek
       ZORUNDA (proje kuralı) ve `legal_text_test.dart` "Son güncelleme"
       tarihlerini karşılaştırdığından port bayat kalsa test düşerdi.
     - **Doğrulama sınırı:** gerçek bir cihazdan oynanan oyunun `ios`/
       `android` satırına düştüğü ancak cihazda görülebilir —
       `mobile/TESTING.md` bölüm 5'e ve kök `TESTING.md` 9.8'e maddeler
       eklendi.

   - ✅ **Parça 100 — kırmızı nokta artık mute'tan BAĞIMSIZ: susturulan
     kişinin mesajı da rozeti artırır, yalnızca popup bastırılır (15 Ağustos
     2026, `online_game_screen.dart`, `board_widget.dart` + web
     `OnlineGameScreen.tsx`):** Bölüm 11'in mesajlaşma turunda kullanıcı önce
     "T2 sessizdeymiş, o yüzden mesaj çıkmadı" dedi, sonra doğru soruyu
     sordu ("mute etmiş kişide, mute edilmiş kişiden gelen mesaj kırmızı
     nokta çıkarmıyor ama diğerlerinden gelirse çıkıyor mu?") ve ardından
     ürün kararını kendisi verdi.
     - **Bu bir hata düzeltmesi DEĞİL, bilinçli bir davranış değişikliği.**
       Eski davranış (mute ikisini birden bastırır) web'de de portta da
       tutarlıydı ve gerekçesi yazılıydı. Kullanıcının gerekçesi daha
       güçlü çıktı: taciz vektörü POPUP; nokta rahatsız etmiyor, üstelik
       susturulan kişinin ne yazdığını görmek şikayet etmenin ön koşulu
       olabilir. Tam alıntı ve üç ayaklı gerekçe kök `CLAUDE.md`'de
       ("Oyun İçi Mesajlaşma — Faz 2", ilk madde).
     - **İKİ yerde birden değişti, tek yer YETMEZDİ:** ilk yüklemedeki
       tohumlama (`_seedInitialUnread`) ve Realtime dalı (`_onChatMessage`).
       Yalnızca birini değiştirmek, uygulama KAPALIYKEN gelen mesajlarla
       AÇIKKEN gelenler arasında sessiz bir tutarsızlık üretirdi — aynı
       kullanıcı aynı mesaj için bir gelişte nokta görür, ötekinde görmezdi.
     - **`mutes` parametresi `_seedInitialUnread`'den KALDIRILDI**, imzada
       ölü bir argüman olarak bırakılmadı; çağıran onu zaten `_chatState`e
       (rozetler + popup kapısı) yüklemeye devam ediyor.
     - **Mevcut testler bu değişikliği YAKALAYAMAZDI ve bu kayda değer:**
       iki mute testi de yalnızca popup'ın açılMAdığını ölçüyordu; rozete
       hiç bakmıyorlardı. Yani filtre yanlışlıkla "sohbet geneli sessize
       alma"ya dönüşse bile takım yeşil kalırdı. Rozet için üretim koduna
       bir `ValueKey('chat-unread-dot')` eklendi (projedeki `like-count-*`/
       `moves-*` deseni) ve iki test de artık noktayı ölçüyor: susturulan
       gönderende **popup YOK + nokta VAR**, susturulmamışta **ikisi de
       VAR** (ikincisi olmadan "hiç nokta çıkmıyor" gibi ters bir regresyon
       da geçerdi).
     - **Negatif eş:** `online_game_screen.dart` `git stash`lenince mute
       testi GERÇEKTEN düştü (`chat-unread-dot` bulunamadı), geri konunca
       yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 427/427
       yeşil** (yeni test yok — mevcut iki teste assertion eklendi). Web
       `npm run lint` + `npm run build` + `npm run test` (Playwright 3/3)
       temiz. `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (web yarısı aynı gün, aynı
       dalda) → kök `CLAUDE.md` + iki `TESTING.md` aynı commit'te
       güncellendi (Parça Bitirme Kontrol Listesi madde 1).
     - ~~**Doğrulama sınırı:** iki gerçek hesapla cihazda teyit bekleniyor —
       özellikle 4 kişilik bir oyunda "susturulmamış gönderen hâlâ popup
       açıyor" kontrolü~~ → **16 Ağustos 2026'da cihazda KOŞULDU ve GEÇTİ**,
       4 kişilik kontrol dahil. Yani kararın iki yarısı da gerçek uçla
       kanıtlandı: susturulanda popup YOK/rozet VAR, susturulmayanda İKİSİ
       de var — filtrenin yanlışlıkla "sohbet geneli sessize alma"ya
       dönüşmediğinin tek gerçek kanıtı bu ikinci yarı (2 kişilikte
       görünmez). Maddeler `mobile/TESTING.md` bölüm 11 ve kök
       `TESTING.md` bölüm 3'te.

   - ✅ **Parça 101 — "Yapay Zeka ile" sekme rozeti porta hiç girmemişti
     (15 Ağustos 2026, `setup_screen.dart`):** Kullanıcı bölüm 11 turunda
     ekran görüntüsüyle bildirdi: *"YZ bekleyen 2 oyun olmasına ve devam
     edenlerde 2 yazmasına rağmen ana tabda sayı yok."*
     - **Web kaynağı önce okundu (kuralın ilk adımı) ve kullanıcıyı
       doğruladı:** `Setup.tsx`'in OYUN TİPİ satırı İKİ sekmeye de rozet
       veriyor — `{label:'Yapay Zeka ile', badge: localSaveCount}` ve
       `{label:'Arkadaşınla', badge: liveActionCount}`. Port yalnızca
       ikincisini taşımıştı; `YAPAY ZEKA İLE` butonuna `badge` hiç
       geçilmiyordu, `_ChoiceButton` de `badge<=0` iken Stack'i hiç
       kurmadığından rozet TAMAMEN yoktu (soluk/sıfır değil, yok).
     - **Formül web'den birebir:** `_localSaveCount` = girişliyse
       `_cloudSaves?.length ?? 0`, misafirse `_savedState != null ? 1 : 0`
       (web `user ? (cloudSaves?.length ?? 0) : savedGame ? 1 : 0`).
     - **Bu, `CountBadge`'in "toplama kuralı"nın somut örneği** (kök
       `CLAUDE.md`): kapsayan sekmenin rozeti kapsananların toplamı olmak
       zorunda. Burada "Devam Edenler" alt sekmesi 2 gösterirken onu
       KAPSAYAN "Yapay Zeka ile" hiçbir şey göstermiyordu — kullanıcının
       gördüğü tutarsızlık tam olarak zincirin kopmasıydı.
     - **Test İKİ rozeti birden ölçüyor**, yalnızca yenisini değil:
       `badgeOf('DEVAM EDENLER') == badgeOf('YAPAY ZEKA İLE') == 2`.
       Yalnızca üsttekine bakan bir test, ikisi ayrışsa da geçerdi — asıl
       korunması gereken değişmez sayının kendisi değil EŞİTLİĞİ.
     - **Negatif eş:** `setup_screen.dart` `git stash`lenince test
       GERÇEKTEN kullanıcının semptomunu üretti (`Expected: <2> / Actual:
       <null>` — yani rozet hiç yok), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       428/428 yeşil** (427'den +1). Web'e hiç dokunulmadı (orada rozet
       zaten doğru); `kelimeki_core`'a dokunulmadı.
     - **Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor —
       `mobile/TESTING.md` bölüm 11'e madde eklendi.

   - ✅ **Parça 102 — SEKİZ diyalog düz `AlertDialog`'du: site diliyle hiç
     alakası yoktu (15 Ağustos 2026, yeni `ui/game/dialog_shell.dart` +
     `ui/game/{game_screen,invasion_confirm}.dart`,
     `ui/live/online_game_screen.dart`, `ui/friends/friends_modal.dart`):**
     Kullanıcı bölüm 11'in mesajlaşma turunda yeni-mesaj popup'ının ekran
     görüntüsünü gönderip *"çıkan popup bizim site genelinde kullandığımız
     tasarımlarla alakası yok. Başka uyarı pencerelerinde de benzer durumu
     gördüm. App'deki tüm uyarı pencerelerini tarayıp web ile uyumlu hale
     getir"* dedi.
     - **Aynı turda bildirilen İKİNCİ şey bir hata DEĞİLDİ ve kaynaktan
       doğrulandı:** *"popup çıktığı için kırmızı nokta çıkmıyor, okumuş
       kabul ediyor."* Gözlem doğru, davranış bilinçli ve web'de de aynı —
       `closeMessagePopup` (web) ve `_showNewMessagePopup`'ın dönüşü (port)
       popup kapanınca mesajı okundu işaretliyor; web'de gerekçesi yorumda
       yazılı (*"popup'taki mesaj zaten doğrudan ekranda gösterildiğinden…
       aksi halde kırmızı nokta popup kapatıldıktan sonra da kalıcı
       kalıyordu"*). Nokta mesaj geldiği an çıkıyor, yalnızca popup'ın
       altında kalıyor. Düzeltilecek bir şey yok.
     - **Web'de İKİ ayrı kabuk var ve port yalnızca birini taşımıştı:**
       `Modal.tsx` (başlıklı, ✕'li, ayraçlı 360px pencere → `KModal`) ve
       `App.tsx`/`OnlineGameScreen.tsx`/`FriendsModal.tsx`'in satır içi
       `fixed inset-0 z-[200]` onay popup'ları (384px kart). **Üç web
       dosyası da BİREBİR AYNI sınıfları taşıyor**, yani tek bir kanonik
       kart var — port onu hiç port etmemiş, sekiz yerde ham `AlertDialog`
       kullanmıştı (Material varsayılanı: beyaz kart, Material tipografisi,
       mavi metin butonları).
     - **Değerler ölçüldü, tahmin edilmedi** (Parça 33'ün dersi): derlenmiş
       `dist/assets/*.css` gerçek DOM'a uygulanıp Chromium'da okundu — kart
       384/24/16 + `#B8C2D1` + `0 20px 45px rgba(15,23,42,.5)`, başlık
       16/700, gövde 14/1.625, boşluklar 16 ve 20, buton 12/tracking 1/
       dikey 10/yükseklik 38. **İlk harness sessizce yedeğe düştü** (CSS
       yolu `file://`de çözülmedi, her şey tarayıcı varsayılanı çıktı) —
       Parça 77'nin aynı tuzağı; HTTP'den servis edilince düzeldi.
     - **`friends_modal.dart` kartı elle çizmişti ve O DA sapmıştı**
       (başlık 15, gövde 13/1.5, buton 11, kart gölgesi yok) — yani desen
       kod tabanında vardı ama tek kaynak değildi. Şimdi on çağrı yerinin
       (8 AlertDialog + bu 2) hepsi `dialog_shell.dart`tan geçiyor.
     - **İki YAPISAL bulgu, ikisi de yeni testin ÖLÇÜMÜYLE çıktı:**
       1. **`Dialog`ın varsayılan `insetPadding`i yanlardan 40**, web'in
          kaplaması `px-4` = 16. Dar ekranda fark gerçek: 420px'lik bir
          telefonda web kartı 384 çizerken port 340'a sıkışıyordu.
       2. **`DecoratedBox`, `Decoration.padding`i ONURLANDIRMIYOR** —
          yalnızca `Container` ediyor. Çerçeve içeriğin üstüne binip içerik
          334 yerine 336 oluyordu; web `border-box` olduğundan 334 doğru.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** yeni
       `dialog_shell_test.dart` (5 test + 1 ekran görüntüsü) kart
       geometrisini/tipografisini/buton sırasını ölçüyor VE `lib/` altında
       ham `AlertDialog` kalmadığını tarıyor (`color_tokens_test`/
       `theme_test`in kaynak tarayan deseni — bu olmadan yeni bir
       AlertDialog sessizce girer). `invasion_confirm.dart`'ta `KDialogCard`
       geçici olarak `AlertDialog`a çevrilince tarama GERÇEKTEN dosyayı adıyla
       işaret ederek düştü; `insetPadding` satırı kaldırılınca buton
       genişliği GERÇEKTEN 334 → 290 düştü. İkisi de geri konunca yeşile
       döndü.
     - **Mevcut testlerde çıkan tuzak:** diyalog butonları artık Material
       değil `NeoButton`, ve alt şeritte de AYNI etiketli NeoButton'lar var
       (PAS GEÇ / TEKRAR OYNA) — `find.widgetWithText(NeoButton, 'PAS GEÇ')`
       iki eşleşme veriyor. Diyalog dokunuşları artık
       `find.descendant(of: find.byType(KDialogCard), …)` ile kapsamlı;
       alt şerit butonlarını da saran ilk (fazla geniş) regex düzeltildi.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 436/436
       yeşil** (428'den +8). `kelimeki_core`'a hiç dokunulmadı; web'e hiç
       dokunulmadı (yalnızca ölçüm kaynağı olarak okundu).
     - ~~**Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor.~~
       Ekran görüntüsü `build/screenshots/dialog_message_popup.png` olarak
       üretilip gözle incelendi (panel zemin, düşen gölge, accent CEVAP VER
       + nötr KAPAT) → **16 Ağustos 2026'da cihazda KOŞULDU ve GEÇTİ**
       (`mobile/TESTING.md` bölüm 11, "Uyarı pencerelerinin tasarımı" —
       yeni mesaj popup'ı, sohbet tanıtımı, "Pas Geçiyorsun!", "Tekrar
       Oyna", "Sınır İhlali!" ve arkadaşlık onaylarının HEPSİ tek turda
       kontrol edildi). Sekiz ham `AlertDialog`ın hiçbiri geride kalmamış.

   - ✅ **Parça 103 — sayısız kırmızı noktalar `CountBadge`e çevrildi
     (16 Ağustos 2026, `board_widget.dart` + `k_avatar.dart` + web
     `Board.tsx`/`Avatar.tsx`):** Kullanıcı *"insanlar mesajlarda çıkan
     kırmızı noktayı farketmiyorlar. Onu da her yerde kullandığımız sayılı
     olana döndürmek nasıl olur? Bir de avatardakini"* dedi.
     - **Bilinçli bir kararın tersine çevrilmesi, hata düzeltmesi DEĞİL.**
       İki gösterge de kök `CLAUDE.md`'de "var/yok bilgisi taşıyor, adet
       değil" gerekçesiyle açıkça `CountBadge` DIŞINDA tutulmuştu ve o
       gerekçe hâlâ tutarlı — ama fark edilmeyen bir gösterge, doğru
       sınıflandırılmış olsa da işe yaramıyor. Eski gerekçe silinmedi,
       tarihiyle birlikte "tersine çevrildi" olarak duruyor.
     - **Sayı zaten vardı, boolean'a indiriliyordu:** `_chatState.unreadCount`
       ve `_incomingRequests`. Prop'lar `BoardWidget.unreadMessageCount` ve
       `KAvatar.badgeCount` oldu (`hasUnreadMessage`/`dot` kalktı).
     - **Web ile kasıtlı fark:** web avatar rozeti arkadaşlık isteği +
       admin bekleyen işinin TOPLAMI; portta admin paneli olmadığından
       (bilinçli, "Üst Düzey Kararlar" #3) tek kaynak arkadaşlık isteği.
     - **Konum web'de ÖLÇÜLEREK seçildi, ikisine birden uygulandı:** rozet
       satır içi OLAMAZ — şeride ~20px eklerdi ve 360px'lik bir telefonda
       "Mesajlaşma" ile "Nasıl Oynanır?" arasında yalnızca 7.8px boşluk var.
       `top/right: -4` ile rozetin sağ kenarı en dar durumda 3.8px pay
       bırakıyor (iki haneli sayıda da — rozet sağdan sabitli). Beyaz halka
       (web `ring-2 ring-panel`) rozeti altındaki mavi etiketten ayırıyor.
     - **Test anahtarı yeniden adlandırıldı** (`chat-unread-dot` →
       `chat-unread-badge`) ve iki mute testinden biri artık SAYIYI ölçüyor:
       ikinci bir mesaj gelince rozet `1`→`2` olmalı. Parça 100'de eklenen
       "var/yok" kontrolü tek başına, sayacın hiç artmadığı bir regresyonu
       yakalayamazdı.
     - **Doğrulama sınırı ve SONUCU — bu sınır AYNI GÜN gerçekleşti:** bu
       oturumun konteynerinde Flutter SDK YOK (`flutter: command not
       found`), yani `flutter analyze`/`flutter test` KOŞULAMADI. Web yarısı
       tam doğrulandı (`npm run lint`, `npm run build`, Playwright 3/3,
       derlenmiş CSS + Chromium ölçümü) ama **Dart yarısı `main`'e merge
       edilince CI'da DÜŞTÜ**: `mobile-build.yml`, `b2ca8fa`ta 434 geçti
       **2 düştü**. `flutter analyze` temizdi, `kelimeki_core`/Android/iOS
       job'ları geçti — düşen yalnızca iki widget testiydi ve ikisi de
       üretim kodu hatası DEĞİL, bu değişikliğin test beklentilerine
       yansıtılmamış olmasıydı:
       - `friends_test`: avatar da artık sayı gösterdiğinden `"2"` İKİ yerde
         (menü satırı + avatar) → `findsOneWidget` düştü. Düzeltme
         `findsNWidgets(2)` ile geçiştirilMEdi; avatar rozeti `KAvatar` alt
         ağacında AYRICA ölçülüyor, böylece hangi "2"nin hangisi olduğu
         testten okunuyor ve rozet yanlış yere düşerse test yine yakalar.
       - `online_game_chat_test`: sayacın `1→2` arttığını ölçmek için aynı
         susturulmuş gönderenden ikinci mesaj eklenmişti, dolayısıyla
         thread'de iki 🚫 rozeti var → `findsNWidgets(2)`.
       **Ders:** bir görsel göstergeyi "var/yok"tan "sayı"ya çevirmek, o
       göstergeyi ölçen HER testin beklentisini de değiştirir — aynı sayı
       artık birden fazla yerde yazıyor olabilir. Flutter koşulamayan bir
       oturumda bu ancak CI'da görülür; PR'ı merge etmeden CI'ı beklemek
       (ya da en azından merge sonrası run'ı KONTROL ETMEK) şart.
       Düzeltme `60d2113` ile merge edildi, dört job da yeşil.
     - **16 Ağustos 2026 — İKİ PLATFORM DA gerçek cihazda teyit edildi.**
       Web: avatar rozetinin toplamı, oyun ekranında kırpılmaması, sohbet
       rozetinin sayması ve "Nasıl Oynanır?" ile çakışmaması. Mobil
       (`mobile/TESTING.md` bölüm 10 + 11): arkadaşlık isteğinde avatarda
       nokta değil SAYI, menüdeki "Arkadaşlar" rozetiyle aynı sayı; sohbet
       kapalıyken gelen mesajda sayaç, ikinci mesajda **2**; sohbet açılınca
       sıfırlanması ve uygulama kapat/aç sonrası geri gelmemesi; susturulmuş
       gönderende popup YOK ama rozet ARTIYOR.

   - ✅ **Parça 104 — yeni mesaj popup'ı ZEMİNE dokununca kapanıyordu; web'de
     zemin tıklanamaz (16 Ağustos 2026, `online_game_screen.dart`):**
     **Bildirilen bir hata DEĞİL — bir yanlış anlamanın yan ürünü, kayda
     öyle geçsin.** Kullanıcı iki cihazlı mesajlaşma turunu koşup *"Popup
     geldi ve gitti"* dedi; ben bunu "kendiliğinden kayboldu" diye okudum,
     oysa "iki taraf da mesaj attı ve göründü" demekti — yani madde
     GEÇMİŞTİ. Araştırma yine de gerçek bir web↔port sapması buldu ve
     düzeltildi; ama bu bölümü bir kullanıcı şikayeti sanan bir sonraki
     oturum yanlış bir izin peşine düşer.
     - **Önce "otomatik kapanma" arandı ve KOD ÜZERİNDEN ELENDİ:**
       `_showNewMessagePopup` içinde ne `Timer` ne `Future.delayed` var;
       `_fetchChat`/`_seedInitialUnread` `newMessagePopup`a HİÇ dokunmuyor
       (yalnızca `messages`/`unreadCount`), yani ön plana dönüşteki
       tazeleme (Parça 95) dialog route'unu kapatamaz; `Navigator.pop`
       çağıran altı yerin hiçbiri bu popup'ın yolunda değil. Yani mesaj
       "kendiliğinden" gitmiyor.
     - **Geriye kalan TEK buton-dışı çıkış yolu barrier'dı ve o gerçek bir
       web sapması:** web'de popup `fixed inset-0 z-[200]` bir kapta ve o
       kabın **hiç `onClick`i yok** (`OnlineGameScreen.tsx:1482`) — kapatma
       yalnızca ✕ / CEVAP VER / KAPAT. Flutter'ın `showDialog`ı ise
       VARSAYILAN olarak `barrierDismissible: true`, yani ekranın herhangi
       bir yerine (tahtaya, başlığa) dokunmak popup'ı kapatıyordu. Kullanıcı
       için bu, mesajın kendiliğinden kaybolması gibi görünür — üstelik
       kapanış `unreadCount: 0` + `markChatRead` de yaptığından geriye
       rozet bile kalmıyor, yani mesaj hiç görünmemiş gibi oluyor.
       `barrierDismissible: false` eklendi.
     - **Parça 85'in "kapana kısılma" gerekçesi burada GEÇERSİZ ve bu
       bilinçli:** orada (ActionSheet) zemin dokunuşu aksiyonsuz çıkışın
       TEK yoluydu, o yüzden bilerek açık bırakılmıştı; burada iki görünür
       buton var ve KAPAT web'in ✕'iyle aynı işi yapıyor. Web'deki ✕ porta
       EKLENMEDİ — `KDialogCard`'ın kapatma ikonu yok ve KAPAT onunla
       fonksiyonel olarak özdeş.
     - **Test — mevcut popup testine eklendi:** zemine (`tapAt(Offset(5,5))`)
       dokunulunca popup'ın DURDUĞU doğrulanıyor. Düzeltme olmadan bu
       assertion kullanıcının tarif ettiği semptomu birebir üretir (popup ve
       mesaj ekrandan kaybolur).
     - **Doğrulama sınırı — Parça 103'ün dersi HÂLÂ geçerli:** bu oturumun
       konteynerinde Flutter SDK YOK (`flutter: command not found`), yani
       `flutter analyze`/`flutter test` KOŞULAMADI; kanıt CI'ın
       (`mobile-build.yml`) yeşile dönmesi. **Cihazda 16 Ağustos 2026'da
       KOŞULDU ve GEÇTİ** — popup ne kendiliğinden kapandı ne de zemine
       (tahta/başlık) dokununca; tek kapanma yolu CEVAP VER / KAPAT.
       Bildirilen bir hata değildi, kod incelemesinde bulunmuştu; yine de
       gerçek bir sapmaydı ve artık uçtan uca doğrulandı.
     - **Kapsam dışı (bilinçli):** `showKConfirm`/`showKInfo` hâlâ
       varsayılan `barrierDismissible: true` — onlar kullanıcının KENDİ
       başlattığı onay/bilgi kartları ve zemin dokunuşu orada "vazgeç"e
       eşdeğer; zararsız. Zararlı olan, kullanıcının istemediği bir anda
       ÜSTÜNE gelen bir bildirimin kazara kapanmasıydı.
     - **Ders — bir test turu raporunu "hata bildirimi" diye okumadan önce
       maddenin BEKLENEN sonucunu oku.** `mobile/TESTING.md` bölüm 11'in
       ilgili maddesi zaten "iki taraf da mesaj atabilmeli" diyordu; kısa
       bir "geldi ve gitti" cevabını o maddeye göre yorumlamak yerine
       kendi hipotezime göre yorumladım ve kullanıcıya "bu hata" dedim.
       Bu, Parça 36'nın dersinin (bir isteğin kapsamını KENDİN daraltma)
       simetriği: **kullanıcının cevabına kendin bir şikayet EKLEME.**
       Bedeli burada küçüktü (tek satırlık, gerçek bir sapmayı kapatan bir
       değişiklik) ama aynı refleks bir sonraki turda çalışan bir şeyi
       "düzeltmeye" kalkabilir.

   - ✅ **Parça 105 — BAYAT bir liste satırından devam etmek offline oynanan
     hamleleri KALICI olarak siliyordu (16 Ağustos 2026,
     `cloud_save_repo.dart`, `setup_screen.dart`):** Kullanıcı Blok 7
     turunda bildirdi: *"uçak modunda devam eden 4 kişilik yz oyunda
     yaptığım hamleyi geri çıkıp girince hatırlamadı. 2 kişilik yeni oyun
     açtım, oynadım, geri çıkıp tekrar girdiğimde sorun yoktu onda. Ama 4
     kişilik oyunda … aynı sonuç. İlk haline geri dönüyor."*
     - **Kalıcılık katmanı SAĞLAMDI ve bunu doğrulamak teşhisin yarısıydı:**
       `origin/main` = kullanıcının test ettiği derleme (`1c0bd39`) ve
       kalıcılık dosyalarında fark yok; `_offlineList`in "ayna KOŞULSUZ
       kazanır" kuralı ve aynı id'nin hem önbellekte hem aynada olduğu
       senaryo `cloud_save_test.dart`ta ZATEN testli ve geçiyordu. Yani
       hata repo katmanında değil, onu ÇAĞIRAN akıştaydı.
     - **Kök sebep — Setup listesi bir ANLIK GÖRÜNTÜ, ama `_resumeCloudSave`
       ona sorgusuz güveniyordu.** Oyundan çıkışta liste `_syncCloud` ile
       tazeleniyor; o zincir `flushMirrored` + `list()` yani İKİ ağ
       çağrısı, ve uçak modunda bunlar hemen düşmüyor, zaman aşımına
       oynuyor. O pencerede kullanıcı aynı satıra tekrar dokunursa oyun
       PRE-GAME state'le açılıyor — üstelik `CloudGameSession` kurulur
       kurulmaz mevcut state'i yazdığından (kurucudaki `_onChange()`) o
       bayat state 600 ms sonra AYNAYI EZİYOR ve offline hamleler
       kurtarılamaz biçimde siliniyordu. Belirti bire bir "ilk haline
       geri dönüyor".
     - **Asimetriyi de tam olarak bu açıklıyor** (ve teşhisi doğrulayan
       şey buydu): YENİ açılan 2 kişilik oyunun satırı çıkıştan ÖNCEKİ
       listede YOKTU, yani kullanıcı satır belirene kadar — yani
       `_syncCloud` bitene kadar — beklemek ZORUNDAYDI ve o noktada liste
       tazeydi. Devam eden oyunun satırı ise zaten ekrandaydı; hemen
       dokunmak mümkündü. Yani hata "4 kişilik"e değil "listede ZATEN
       duran satıra" bağlı.
     - **Düzeltme — `CloudSaveRepo.newerPendingState(id, userId,
       knownUpdatedAtMs)`:** `_resumeCloudSave` açmadan hemen önce "bu id
       için aynada daha yeni bir state var mı?" diye soruyor ve varsa onu
       restore ediyor. Karşılaştırma `list()`in online dalındaki kuralın
       AYNISI (`savedAtMs > updatedAtMs`) — bilerek: taze bir listede
       satır zaten aynadan geldiğinden damgalar eşit olur ve null döner
       (gereksiz yeniden yükleme yok), başka bir cihazın yazdığı DAHA YENİ
       sunucu satırı da eski bir aynayla ezilmez. Depo okunamazsa
       elimizdekiyle devam edilir — oyunu açmayı engellemiyor.
     - **`CloudGameSession`'ın kurucudaki ilk yazması BİLEREK DURUYOR.**
       Onu "resumeSaveId varsa atla" diye kapatmak da hasarı azaltırdı ama
       yanlış katman olurdu: web'in autosave effect'i de RESUME_SAVED
       sonrası yazıyor (satırın `updated_at`i tazelenip 7 günlük terk
       süresi geri itiliyor). Doğru düzeltme, yazılan state'in TAZE
       olmasını garanti etmek.
     - **Teşhis satırının belirsizliği de kapatıldı** — bu tur onun
       yüzünden bir el kaybetti: kullanıcı `depo ok, bekleyen 0` bildirdi
       ama `pendingMirrorCount` depo erişilemediğinde de **0** dönüyordu,
       yani o "0" hiçbir şey kanıtlamıyordu. Artık ulaşılamazsa **-1**
       dönüyor ve teşhis satırı `bekleyen ?` yazıyor.
     - **Test — negatif eş MEKANİZMAYI KANITLAYAN ayrı bir test olarak:**
       `cloud_save_test.dart`a üç test (bayat satırdan devam hamleleri
       silmiyor; **MEKANİZMA testi** — bayat state ile devam edilirse ayna
       GERÇEKTEN eziliyor, yani guard cargo-cult değil; taze listede
       `newerPendingState` null dönüyor) ve `setup_cloud_test.dart`a bir
       KABLO testi (`FresherStateRepo` — Setup gerçekten soruyor mu ve
       dönen state'i kullanıyor mu; Parça 86'nın dersi: sözleşmeyi
       enjekte edilebilir sınırın ÜSTÜNDE test etmek altındaki iletimi
       kanıtlamaz). `pendingMirrorCount`ın -1'i ile gerçek sayıyı dönen
       yolu karşıt eş olarak aynı dosyada duruyor.
     - **Doğrulama — bu oturumda Flutter YOK** (`flutter: command not
       found`, Parça 103/104'ün aynı sınırı): `flutter analyze`/
       `flutter test` KOŞULAMADI, kanıt CI oldu — PR #274'te dördü de
       yeşil (analiz + **440 test**, 436'dan +4; Android APK; iOS
       imzasız; web derlemesi). Merge sha `6b71eaa`.
     - **CİHAZDA DOĞRULANDI (16 Ağustos 2026, kullanıcı):** uçak modunda
       var olan bir oyuna girip hamle yapıp çıkıp hemen tekrar girildiğinde
       hamle DURDU — *"Kaydetti bu sefer. Çalışıyor."* Yani düzeltme
       yalnızca repo katmanında değil gerçek akışta da çalışıyor;
       `mobile/TESTING.md` bölüm 8'deki madde ilerideki bir regresyon için
       duruyor (**hızlı** koşulmalı — bekleyerek koşulursa liste tazelenir
       ve senaryo hiç oluşmaz).
     - **Ders — "repo katmanı testli ve geçiyor" bir SONUÇ değil bir
       ELEME:** doğru soru "bu veriyi kim ne zaman OKUYOR ve okuduğu şey ne
       kadar taze?" idi. Bu projenin kalıcılık katmanı bir yıl boyunca
       "yazma yolu" üzerinden düşünüldü (ayna, önbellek, silme kuyruğu);
       kaybın gerçekleştiği yer ise OKUMA yoluydu — ekranda duran bir
       anlık görüntü. Bir ekran, elindeki veriyle YAZMA başlatıyorsa o
       verinin tazeliği bir varsayım değil, kontrol edilmesi gereken bir
       ön koşuldur.

   - ✅ **Parça 106 — tahta filigranları KUTUYA sığdırılıyordu (web'de punto
     ekran genişliğine bağlı) + fontu da yanlıştı; ayrıca web'in avatar
     hizası bozuktu (17 Ağustos 2026, `board_widget.dart` + web
     `UserMenu.tsx`):** Blok 6'nın (görsel yan yana) kalan iki maddesi.
     Kullanıcı iki ekranı yan yana koyup köşe rakamlarının ve X2/X3
     filigranlarının "farklı boyut/tasarımda" olduğunu, ayrıca web'de
     avatarın skor kutularının merkezine göre yukarıda durduğunu bildirdi.
     - **(a) Filigranlar — üç ayrı sapma, ikisi gözle görünmeyen türden.**
       Web (`Board.tsx`) puntoyu kutuya SIĞDIRMIYOR, `clamp` ile ekran
       genişliğine bağlıyor: köşe `clamp(80px,32vw,220px)`, X2
       `clamp(60px,24vw,165px)`, X3 `clamp(7px,1.9vw,12px)`; ilk ikisi
       `font-mono` + `leading-none`. Port ise `FittedBox` kullanıyordu
       (punto kutunun oranından çıkıyor) ve **köşe/X2 için `fontFamily` hiç
       vermiyordu** — yani yazı tipi temanın SpaceGrotesk'ine düşüyordu.
       Kullanıcının "tasarım da farklı" demesinin sebebi buydu; punto farkı
       ise yön yön değişiyordu: köşe rakamı web'den KÜÇÜK (kutu 4/13 ×
       satır yüksekliği), X2 ve özellikle X3 ise BÜYÜK — X3 48px'lik bir
       hücreyi doldurduğundan ~37px, web'in azami 12px'inin üç katı.
     - **Düzeltme sihirli sayı içermiyor:** üç `clamp` de `fluidSize` ile
       birebir taşındı (Parça 24'ün `tile_widget.dart`'ta kullandığı aynı
       desen — `vw` girdisi `MediaQuery.sizeOf(context).width`), `fontFamily:
       'SpaceMono'` ve `height: 1` (=`leading-none`) eklendi.
     - **`Center` + `OverflowBox` ŞART:** köşe rakamının satır kutusu
       (220) kendi 4/13'lük alanından (680px'lik tahtada ~203) BÜYÜK ve
       web'de de taşıyor; `FractionallySizedBox` çocuğuna TIGHT kısıt
       verdiğinden araya konmazsa yazı ortalanmak yerine kutunun üstünden
       çizilirdi. Rakamın MÜREKKEBİ (~0.7em = 154) kutuya sığdığından
       görünür bir kırpma yok.
     - **(b) Avatar hizası — bu sefer WEB yanlıştı, port doğruydu.**
       `<button>` varsayılan `inline-block` ve fotoğraflı hesapta `Avatar`
       bir `<img>` (inline-level) döndürüyor → satır kutusu → resmin ALTINA
       7px taban çizgisi payı → buton 39px ve resim üste yaslı → header'ın
       `items-center`'ı 39px'lik kabı ortalayınca fotoğraf skor kutusu
       merkezinin **3.5px üstünde** kalıyor. Butona `flex` eklendi.
       Ayrıntı + ölçüm: kök `CLAUDE.md`, `UserMenu` maddesi.
     - **ÖLÇÜM, iki madde için de tahminin yerini aldı** (derlenmiş
       `dist/assets/*.css` + Chromium, 390/834/1194): filigran puntoları
       124.8/93.6/7.41 ve 220/165/12 olarak okundu; avatar merkezi
       düzeltmeden önce 26 (kutu 29.5), sonra üç genişlikte de birebir eşit.
       Ölçüm ayrıca hatanın KAPSAMINI daralttı: avatar sapması yalnızca
       profil FOTOĞRAFI olan hesaplarda var (baş harf yedeği `display:flex`,
       rozetli sarmalayıcı `inline-flex` — ikisi de 32px kalıyor).
     - **Test:** `board_render_test.dart`'a iki test (geniş ekranda clamp
       tavanı 220/165/12 + `fontFamily`/`height`; dar ekranda clamp ortası
       124.8/93.6/7.41). Filigranlar yalnızca BOŞ hücrelerde çizildiğinden
       bitmiş bir golden fixture kullanılamaz — testler boş tahtalı bir
       `emptyBoardState()` ile ve tahtayı gerçek genişliğinde (680/374)
       çizen ayrı bir `pumpBoardSized` ile koşuyor (`pumpBoard`ın sabit 560
       kutusu ve 90px payı burada yanıltıcı olurdu).
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde
       Flutter SDK YOK (`flutter: command not found`, Parça 103/104/105'in
       aynı sınırı), yani `flutter analyze`/`flutter test` KOŞULAMADI ve
       **negatif eş kurulamadı**; testler eski kodda zorunlu olarak düşerdi
       (eski `Text`lerin `style.fontSize`'ı `null`), ama bu gösterilmedi —
       tek kanıt CI (`mobile-build.yml`). Web yarısı tam doğrulandı
       (`npm run lint`, `npm run build`, Playwright 3/3, Chromium ölçümü).
     - ~~**Cihazda doğrulanacak:** iki `TESTING.md`'ye maddeler eklendi.~~
       → **17 Ağustos 2026'da iPad'de KOŞULDU ve GEÇTİ:** köşe rakamları
       iki tarafta aynı boy/font, merkez **X2** aynı boy ve **X3 hücreyi
       DOLDURMUYOR** (web'in 12px tavanına oturuyor). Yani `FittedBox`tan
       `fluidSize`a geçiş gerçek CanvasKit'te de web'le aynı sonucu
       veriyor — negatif eşin kurulamadığı (Flutter SDK'sız oturum) bu
       parçada tek gerçek kanıt buydu. **Header avatarının dikey hizası
       AYNI turda koşulmadı** (o web-only ve FOTOĞRAFLI hesap ister).
     - **CI'ın YAKALADIĞI hata bu parçadan DEĞİL, bir önceki dalda merge
       bekleyen commit'lerden çıktı (kayda değer):** PR #277'nin ilk
       koşusunda **442 geçti, 1 düştü** — `score_card_test.dart`'ın
       `find.text('#3 · 8 puan')` beklentisi (`Found 0 widgets`). Sebep
       Parça 106 değil, 17 Ağustos sabahındaki "k-lig satırındaki nokta
       boşluğu" commit'i: satır düz `Text`ten `Text.rich`e çevrilip
       ayırıcının iki yanına 2px'lik `WidgetSpan` konmuştu (web `mx-0.5`),
       yani düz metin artık `'#3·8 puan'` — ama testi güncellenmemişti.
       **O üç commit hiç CI görmemişti**: PR #276 merge edildikten SONRA
       aynı dala push edildiklerinden `pull_request` tetikleyicisi bir daha
       çalışmamıştı (workflow yalnızca `main`'e push ve PR'da koşuyor).
       Test artık literal dize yerine SÖZLEŞMEYİ ölçüyor — düz metin
       `'#3·8 puan'` VE ayırıcının iki yanındaki boşlukların 2px'lik
       `WidgetSpan` olduğu (boşluk karakteri DEĞİL), yani o commit'in asıl
       iddiasını da koruyor.
     - **Ders:** merge edilmiş bir PR'ın dalına eklenen commit'ler sessizce
       CI'sız kalıyor. Bir dala "merge sonrası" commit atıldıysa, o dal
       yeni bir PR'a girene kadar hiçbir şey doğrulanmamıştır — bu, bu
       oturumda Flutter SDK'sının olmamasıyla birleşince (yerelde
       `flutter test` de koşulamıyor) tek doğrulama yolunu PR'a bağlıyor.

   - ✅ **Parça 107 — filigranlar TAŞLARIN ÜSTÜNE biniyordu: web'in z-index
     sırası porta hiç geçmemişti (17 Ağustos 2026, `board_widget.dart`):**
     Kullanıcı Parça 106'nın deploy'undan sonra iki ekranı yan yana koyup
     bildirdi: *"Web'de watermark'lar taşların üstünden görünmeyecek şekilde
     ayarlamıştık, app'de hâlâ görünüyorlar."* Ekran görüntüsünde X2
     filigranı `E Ğ E` taşlarının üzerinden geçiyordu.
     - **Web önce okundu (kuralın ilk adımı) ve TAM katman sırasını verdi:**
       `Board.tsx`'te taş içeren hücreler `relative z-[5]` alıyor ve o
       satırın kendi yorumu gerekçeyi yazıyor ("köşe/bonus filigranları
       (z-index:auto) taşın ÜZERİNDE boyanmasın diye"); dış hat SVG'si ve
       puan rozeti ise `z-10`. Yani sıra: **arka planlar → filigran →
       taşlar → dış hatlar**. Filigran DOM'da en sonda olduğu hâlde taşın
       altında kalıyor, çünkü tek belirleyici z-index.
     - **Portta bu sıra otomatik değil:** Flutter'da z-index yok, `Stack`
       çocuk sırası = boyama sırası. Port ızgara → dış hatlar → filigran
       diye diziyordu, yani filigran HER ŞEYİN üstünde. İki sapma birden:
       taşların üstüne biniyordu (bildirilen) ve dış hatların üstüne
       biniyordu (bildirilmedi, çok daha silik).
     - **Çözüm — taşları ayrı katmana taşımak DEĞİL, filigranı kesmek:**
       filigran katmanı ızgaradan sonra ama dış hatlardan ÖNCE çiziliyor ve
       bir `ClipPath` ile taş bulunan hücreler kesiliyor
       (`_WatermarkClipper`). Sonuç "taşın altında" ile görsel olarak aynı;
       alternatif (ızgarayı biri arka planlar biri taşlar için iki kez
       inşa etmek) 169 hücreyi iki katına çıkarırdı — Parça 23'te sürükleme
       sırasındaki tek fazladan ızgara inşasının bile ölçülebilir bir
       maliyeti olduğu görülmüştü.
     - **Delik `PathFillType.evenOdd` ile, `Path.combine`/PathOps ile
       DEĞİL** — Parça 18'in dersi: PathOps CanvasKit'te deliği sessizce
       kaybediyor, native Skia'da çalışıyor, yani `flutter test` o hata
       sınıfını GÖREMEZ. `neo_box.dart` zaten aynı deyimi kullanıyor.
     - **`dragHiddenKey` bilerek kesilmiyor:** o hücre boş çiziliyor (bkz.
       `_buildCell`), dolayısıyla filigran orada GÖRÜNMELİ. Kural
       `_buildCell`in koşuluyla birebir aynı: bayrak yalnızca `placed`
       taşını gizler, `board` taşını DEĞİL — testi yazarken önce bunu
       ters kurup düzelttim.
     - **Kesme kutusu ızgara geometrisinden türetiliyor** (13 hücre, 3px
       boşluk); `_gap` sabiti `GridView`in `mainAxisSpacing`/
       `crossAxisSpacing` değeriyle ELLE senkron — biri değişirse kesilen
       kutular hücrelerden kayar, bu yüzden sabitin yanına yazıldı.
     - **Test:** `board_render_test.dart`'a yeni bir test — clipper'ın
       ürettiği path'te onaylanmış taşın ve taslak taşın merkezi
       `contains == false`, sürüklenen taslağın kaynağı ile boş köşe/bonus
       hücreleri `contains == true`. Yani "filigran nerede çizilir"
       sorusunu ekran görüntüsüne bakmadan yanıtlıyor.
     - **Doğrulama sınırı — Parça 106'nın aynısı:** bu oturumun
       konteynerinde Flutter SDK YOK (`flutter: command not found`), yani
       `flutter analyze`/`flutter test` KOŞULAMADI ve **negatif eş
       kurulamadı**; tek kanıt CI. ~~Cihazda görsel teyit de bekleniyor~~
       → **17 Ağustos 2026'da iPad'de KOŞULDU ve GEÇTİ:** filigranlar
       taşların ALTINDA kalıyor, dış hatlar üstünde. Bu, `ClipPath` +
       `PathFillType.evenOdd` çözümünün gerçek CanvasKit'te de çalıştığının
       tek kanıtı — Parça 18'in dersi gereği PathOps kullanılmamıştı ve
       `flutter test` (native Skia) bu farkı yapısal olarak göremezdi.

   - ✅ **Parça 108 — rafın ALTINDAKİ aksiyon satırı web'den dört noktada
     sapmıştı (17 Ağustos 2026, `game_screen.dart`,
     `online_game_screen.dart`):** Kullanıcı Blok 6 turunda bildirdi:
     *"Rafın altındaki butonlar da farklı. Web'in aynısı olmalı."* Bu sefer
     yön normal (web kanonik) — port düzeltildi, web'e HİÇ dokunulmadı.
     - **Web ÖLÇÜLDÜ (derlenmiş CSS + Chromium), sınıflardan zihnen
       türetilmedi** (Parça 33'ün dersi): `font-sans` (Space Grotesk) ·
       11px · 700 · **tracking 1.2px** · **line-height 16.5px (=1.5)** ·
       dolgu 10/6 · radius 6 · **gap 6** · buton yüksekliği **41.5**.
     - **Dört sapma:**
       | | web | port (öncesi) |
       |---|---|---|
       | tracking | **1.2** | 1.0 (NeoButton varsayılanı) |
       | satır yüksekliği | **1.5** | 1.2 (varsayılan) |
       | swap satırı boşluğu | **6** (`gap-1.5`) | 8 |
       | buton yükseklikleri | flex `stretch` → **hepsi eşit** | `Row` varsayılanı `center` → TORBA ötekilerden uzun |
     - **Sonuncusu tek başına en sinsi olanı ve tam da düzeltmenin YAN
       ETKİSİYDİ:** TORBA'nın 13px'lik sayacı satır yüksekliğini belirliyor
       (web'de 19.5px). Yalnızca tracking/satır düzeltilseydi fark 2.4 →
       **3px**e çıkıp YENİ bir görünür tutarsızlık üretecekti. Web'de bunu
       flex'in `align-items: stretch` varsayılanı kapatıyor; Flutter `Row`
       varsayılanı `center` olduğundan `IntrinsicHeight` +
       `CrossAxisAlignment.stretch` şart (çıplak `stretch` sınırsız
       yükseklikte patlar — raf satırında öğrenilen aynı ders).
     - **NeoButton'ın VARSAYILANLARINA dokunulmadı** (Parça 37'nin deseni):
       değerler yalnızca ölçülen 14 çağrı yerine geçiliyor. Tarandı —
       varsayılana güvenen başka 4 çağrı yeri var
       (`friend_moderation_sheet` ×3, `setup_screen` ×1) ve onların web
       karşılığı ölçülmedi; varsayılanı değiştirmek onları da sessizce
       kaydırırdı.
     - **Kapsam BİLİNÇLİ olarak 2px genişletildi:** raf ↔ OYNA arası da 8'di,
       web `flex gap-1.5 items-stretch` = **6**. Aynı satır ailesi, tek
       karakterlik ölçülmüş bir düzeltme — gerekçesi burada yazılı olduğu
       için yapıldı (Parça 53'ün kuralı: kapsamı kendi genişletmek de
       daraltmak kadar riskli, ama gerekçe yazılırsa meşru).
     - **Kalan 2px BİLİNÇLİ (Parça 37'nin emsali):** web 41.5, port 39.5 —
       fark tam olarak web'in `border`ının yer kaplaması; portta çerçeve
       `foregroundDecoration`da ve layout'a değmiyor. Telafi için 1px dolgu
       EKLENMEDİ (çerçeve bir gün decoration'a taşınırsa iki kez sayılacak
       bir sihirli sayı olurdu).
     - **Test:** `game_screen_test.dart`'a yeni bir test — dört butonun
       punto/tracking/satır yüksekliği, 6px boşluk, ve **TORBA'nın ötekilerle
       AYNI yükseklikte** olduğu. Sonuncusu olmadan tracking düzeltmesi
       yukarıdaki 3px'lik regresyonu üretip yine geçerdi.
     - **Doğrulama sınırı — Parça 106/107'nin aynısı:** bu oturumun
       konteynerinde Flutter SDK YOK, `dart analyze`/`flutter test`
       KOŞULAMADI ve **negatif eş kurulamadı**; parantez dengesi elle
       taranıp doğrulandı, tek gerçek kanıt CI. Cihazda görsel teyit
       bekleniyor (`mobile/TESTING.md` 0.5).

   - ✅ **Parça 109 — sağ-alt köşedeki YZ her oyuna 29 puan geride
     başlıyordu: `tryCornerStart` kelimeyi yalnızca evden İLERİ uzatıyordu
     (17 Ağustos 2026, `find_move.dart` + web `ai.ts`):** Kullanıcı
     *"sağ alttaki YZ genelde hep sonuncu oluyor. Benim de dikkatimi
     çekmişti. Bunu düzelt acil."* dedi.
     - **Kural okundu, sonra ölçüldü (bu sırayla).** `validatePlacement`
       ilk hamlede YALNIZCA "konan hücrelerden biri ev karesi olsun" diyor
       — yön ya da "4×4 blokta başla" şartı YOK. Yani kısıt oyunun değil
       `tryCornerStart`'ın kendi döngüsünündü; üstelik tutarsızlık YZ'nin
       İÇİNDEYDİ: `tryPlace` (çapalı hamleler) baştan beri `idx` döngüsüyle
       kelimeyi iki yöne de uzatıyordu.
     - **Ölçüm (üretim `findAIMove`, raf `A B A R T M A`, boş tahta):**
       köşe 0/1/2 → `7 taş "ABARTMA" 35 puan`; **köşe 3 → `4 taş "ABAT"
       6 puan`.** 2 kişilikte YZ HER ZAMAN köşe 3'te (`cornersFor`), yani
       bu her oyunda tekrarlanan 29 puanlık bir açılış handikabıydı.
       Düzeltmeden sonra dört köşe de 7 taş / 35 puan (köşe 3: `12,6 …
       12,12`, merkeze doğru).
     - **Düzeltme:** kelimenin HANGİ harfinin eve denk geleceği (`idx`)
       tek tek deneniyor; kelime evden geriye ve ileriye uzayabiliyor.
     - **Döngü SIRASI sözleşmedir, iki motorda da aynı yazıldı**
       (`for W → for idx → for horiz in [true,false]`): `consider` eşit
       puanda İLK bulunanı tutuyor (strict `>`), sıra ayrışırsa iki motor
       farklı hamle seçer ve parite SESSİZCE kırılır — golden vector
       karşılaştırması bunu ancak o senaryo tetiklenirse yakalar.
     - **Golden vector'lar yeniden üretildi; DÖRT fixture değişti ve
       dördü de açıklandı** (üçü besbelli, dördüncüsü değildi):
       `reducer_ai2`/`reducer_ai4`/`reducer_sync` — ilk fark 5. adımdaki
       `AI_PLAY`, yani köşe 3'ün ilk hamlesi. **`reducer_human2` ise SIFIR
       `AI_PLAY` içeriyor ve yine de değişti** — sebebi `humanScenario`'nun
       "geçerli hamleler"i `playBestMove` ile, yani üretim `findAIMove`'unu
       İNSAN adına çağırarak oynatması; 2 kişilikte 2. oyuncu köşe 3'te
       olduğundan o çağrı da `tryCornerStart`'a düşüyor. `JE` (11 puan)
       evden hem dikey (`11,12→12,12`) hem yatay (`12,11→12,12`)
       kurulabiliyor, ikisi de AYNI puan → "ilk bulunan kazanır" artık
       yatayı seçiyor. Tahta değişince senaryonun DİNAMİK koordinatları
       (`findEmptyCell` ve sağ-komşu taraması) kayıyor. Finaller aynı.
       **Ders: bir fixture'da `AI_PLAY` olmaması, o senaryonun YZ'ye
       dokunmadığı anlamına GELMEZ** — üretici kelime aramasını insan
       hamlelerini üretmek için de kullanıyor.
     - **Kapsam dışı, kullanıcıya bildirildi:** `getWordPool` havuzu 2-7
       harfle sınırlı, yani YZ 8+ harfli bir kelimeyi çapaya ekleyerek
       bile kurmuyor (kurallara uygun olurdu). Bu ayrı bir karar; bu
       parçada DEĞİŞMEDİ.
     - **Doğrulama sınırı — Parça 106/107/108'in aynısı:** bu oturumun
       konteynerinde Flutter/Dart SDK YOK (`flutter: command not found`),
       yani `dart run test/run_all.dart` KOŞULAMADI — **motor değişikliği
       olduğu hâlde Dart yarısının tek kanıtı CI.** Web yarısı tam
       doğrulandı (`npm run lint`, `npm run build`, Playwright 3/3, ölçüm
       betiği). Dart portu satır satır web'e karşı okundu; `cornerBounds`
       artık kullanılmıyor (Dart'ta kütüphane importu olduğundan
       kullanılmayan-import hatası doğurmuyor, web'de import satırından
       çıkarıldı).
