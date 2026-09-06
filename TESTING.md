# Kelimeki — Elle Test Kontrol Listesi

Bu dosya, `npm run test`'in (Playwright, `tests/smoke.spec.ts`) **yapısı gereği**
kapsayamadığı akışlar içindir: iki ayrı gerçek oturum, gerçek bir gelen kutusu
ve gerçek Supabase Auth gerektiren her şey. Otomatik testin kapsamı bilinçli
olarak dar (uygulama açılıyor mu, oyun başlıyor mu, YZ oynuyor mu) — aşağıdakiler
onun ulaşamadığı yer.

**Bu liste bir ilerleme kaydı değildir.** "Şu an nerede kaldık" bilgisi bilerek
yok: o bilgi her testten sonra yanlışa döner. Liste her sürüm öncesi (ya da
ilgili alana dokunan bir değişiklikten sonra) baştan koşulabilecek şekilde
yazıldı. Bir bölümü koşarken sonuçları not almak istersen bu dosyayı değil,
oturumun kendisini kullan.

**Mobil tarafın "bu turda nereye kadar geldik?" durumu** (hangi bölümler
koşuldu, hangi maddeler son düzeltmelerden sonra hiç koşulmadı)
`mobile/CLAUDE.md`'nin **"FAZ A1 — Cihaz Testi Tur Durumu"** bölümünde;
oradaki liste web'i ilgilendiren birkaç maddeye (9.6 gibi) de işaret
ediyor.

**Ön koşul:** iki ayrı test hesabı (ör. T1/T2) ve ikisine de erişebildiğin
gerçek e-posta adresleri. Mailinator gibi geçici kutular font/logo render'ı
için güvenilir DEĞİL (gelen HTML'i sanitize edip uzak görselleri düşürüyorlar) —
e-posta görünümünü gerçek bir gelen kutusunda doğrula.

**Deploy sonrası:** test etmeden önce sayfayı bir kez yenile. PWA servis
çalışanı yeni sürümü arka planda alıp uyguluyor, ilk açılışta hâlâ eski JS
çalışıyor olabilir (bkz. `CLAUDE.md` → "PWA — Servis Çalışanı Güncellemesi").

---

## 1. Canlı oyun — davet akışı

- [ ] **Davet gönderme.** "Arkadaşınla" → "+ Yeni Canlı Oyun" → 2 kişilik, bir
      arkadaş seç → "Davet Gönder". **"Davetiniz gönderilmiştir."** ekranı
      çıkmalı, kime gittiğini yazmalı. "Tamam"a basınca listeye dönmeli.
- [ ] **Tek davet = tek oyun.** Gönderimden sonra `online_games`'te o çift için
      TEK satır olmalı. (Onay ekranı eklenmeden önce, geri bildirim olmadığı
      için insanlar butona tekrar basıp 25-35 saniye arayla ikinci bir oyun
      açıyordu — iki farklı kullanıcıda görüldü.)
- [ ] **4 kişilik + YZ.** 2 arkadaş seçip gönderince "4. koltuk Yapay Zeka ile
      doldurulacak, tamam mı?" onayı çıkmalı; "Hayır" denince listede kalıcı
      bir "🤖 Yapay Zeka" satırı belirmeli ve bir daha sorulmamalı.
- [ ] **Davetlinin görünümü.** Karşı hesapta "Oyun Davetleri" sekmesinde kart
      görünmeli, katılımcıların yanında "Davet gönderen"/"Bekliyor" etiketleri
      ve "N gün M saat kaldı" satırı olmalı. (Metin iki kez değişti: 5 Ağustos
      2026'da "Bugün iptal edilir" gibi yanlış/süresiz ifadelerden "… sonra
      iptal edilecek"e, 30 Ağustos 2026'da kullanıcı isteğiyle yalnızca
      "… kaldı"ya — üç sayaç da artık aynı kalıpta.)
- [ ] **Kabul.** Oyun `active` olmalı, tahta/torba kurulmalı, iki tarafta da
      "Devam Edenler"e geçmeli. Kabul sonrası arkadaş önerisi modalı çıkmalı
      (henüz arkadaş olunmayan katılımcılar varsa).
- [ ] **Ret.** Kart, daveti GÖNDERENİN listesinden de **anında** kalkmalı
      (oyun `abandoned` olur). Hiçbir yerde "bekliyor" olarak durmamalı.
- [ ] **Login varsayılanı.** Bekleyen bir davet varken çıkış yapıp tekrar gir:
      "Arkadaşınla" sekmesi otomatik açılmalı ve "Oyun Davetleri" alt sekmesi
      seçili gelmeli (davetler devam eden oyunlardan öncelikli). **Testi
      "Yapay Zeka ile" sekmesindeyken çıkarak koş** — Canlı sekmesindeyken
      çıkarsan seçim yeni oturuma taşındığından test, varsayılan hiç
      çalışmasa bile geçer (5 Ağustos 2026'ya kadar tam olarak bu oluyordu,
      bkz. bölüm 8'in son iki maddesi).
- [ ] **Arka plandan dönüş de "giriş" sayılır (21 Ağustos 2026).** Girişli
      kullanıcıyla Setup'ta **"Yapay Zeka ile"** sekmesinde dur. Uygulamayı
      (masaüstü PWA penceresi ya da tarayıcı sekmesi) arka plana al —
      **başka bir pencereye geçmek yeterli, minimize etmeye gerek yok**; bu
      ayrım önemli, çünkü masaüstünde o durumda `visibilitychange` hiç
      tetiklenmiyor. **5 dakikadan uzun** bekle (bu arada karşı taraf hamle
      yapsın ya da davet göndersin), sonra pencereyi öne getir:
      **"Arkadaşınla" sekmesi kendiliğinden açılmalı** (davet varsa "Oyun
      Davetleri" alt sekmesiyle).
- [ ] **Negatif eş — kısa dönüş kullanıcıyı yerinden ETMEZ.** Aynı senaryoyu
      bu kez ~30 saniyelik bir alt-tab ile koş: sekme DEĞİŞMEMELİ (yalnızca
      rozet güncellenir). Beş dakikayı beklemek istemiyorsan bu maddeyi
      atlama — asıl risk burada, yanlış tarafa düşen bir eşik kullanıcıyı
      bilerek oturduğu sekmeden koparır.
- [ ] **Bekleyen iş yokken dönüş de yerinden ETMEZ.** Canlı'da hiçbir
      bekleyen davet/hamle yokken 5+ dakika uzaklaşıp dön: "Yapay Zeka ile"
      sekmesinde kalmalısın.
- [ ] **Kurma formunun arkadaş listesi hesap değişiminde tazelenmeli.** Bir
      hesapla "+ Yeni Canlı Oyun"u aç (arkadaş listesi yüklensin), kapatmadan
      çıkış yapıp BAŞKA bir hesapla gir, tekrar "+ Yeni Canlı Oyun"a bas.
      Yeni hesabın KENDİ arkadaş listesi görünmeli — önceki hesabınki (hatta
      kendi adının listede belirmesi) DEĞİL. (5 Ağustos 2026: `LiveGameCreateForm`
      arkadaşları yalnızca mount'ta çekiyordu, bu form modal değil tam görünüm
      olduğundan çıkış→giriş döngüsünü mount'ta kalarak atlatabiliyordu.)

## 2. Canlı oyun — oynanış

- [ ] **Sıra netliği.** Sırası sende değilken "Sıra: {isim}" bandı görünmeli;
      YZ koltuğunda ise nabız gibi atan "hamlesini hesaplıyor…" hâli.
- [ ] **Kalan süre yalnızca sende.** "Devam Edenler" listesinde "N saat M
      dk sonra teslim (-2 puan)" **yalnızca sırası sende olan** satırlarda
      görünmeli. "SIRA RAKİPTE" satırında görünmemeli — o süre rakibe ait.
      Sırası sende olan satırın ("SIRA SENDE") yanında yeşil bir ÜÇGEN (oynat
      tuşu), rakipteki satırda ise kırmızı bir YUVARLAK olmalı; ikisi asla
      aynı anda görünmez.
- [ ] **Off-turn deneme.** Sıra sende değilken de taş yerleştirebilmeli,
      Board'da geçerlilik dış hattı/puan rozeti çalışmalı, "Oyna" pasif
      kalmalı. Rakip oynayınca deneme taşları rafa dönüp "Oyna" aktifleşmeli.
- [ ] **Geçerli taslakta mesaj kararlı.** Sıra sende + tahtada geçerli
      (yeşil çerçeveli) bir taslak varken alttaki mesaj HER ZAMAN "Oyna
      tuşuyla kelimeyi onayla." olmalı — taş seçmeden boş hücreye dokunmak
      ("Önce bir harf seç."i yazsa bile), uygulamayı arka plana alıp geri
      dönmek (senkron) ya da başka ekrana geçip dönmek metni DEĞİŞTİRMEMELİ;
      özellikle rakibin son hamle özeti ("X: +N puan …") görünmemeli
      (6 Ağustos 2026'da bulunan üç-farklı-mesaj hatası).
- [ ] **"Kalan Taşlar" (TORBA) dökümü bekleyen taşları rakibe yazmamalı
      (18 Ağustos 2026'da bulunan hata).** Tahtaya birkaç taş koy ama OYNA'ya
      **basma**, sonra `TORBA` düğmesine dokun: "toplam N taş dışarıda"
      sayısı, taşları koymadan ÖNCEKİ sayıyla **aynı** kalmalı (her bekleyen
      taş için 1 artıyorsa hata geri gelmiş demektir). Taşları rafa geri
      alınca da aynı sayı. **Joker eşi:** bir jokeri bir harfe (ör. `A`)
      çevirip masaya koy — dökümdeki `A` sayısı artmamalı, dışarıdaki joker
      sayısı 1 azalmalı.
      **Asıl değişmez oyun sonunda ölçülür:** torba boşken, son hamleni
      onaylamadan hemen önce dökümdeki toplam PUANI hesapla (adet × puan),
      sonra OYNA'ya bas — bitiş kartının **"Kalan" sütununda** rakibin yanında
      yazan negatif sayı o puanla **birebir aynı** olmalı (en sağdaki
      **k-lig** sütunundaki sayıyla KARIŞTIRMA — o oyunun lig katkısı). Kullanıcı bu hatayı tam böyle
      yakaladı (10 saydı, kartta -7 gördü).
      **İKİ ekranda da koş:** yerel/YZ oyunu VE Canlı oyun (Canlı'da ayrıca
      sıra sende DEĞİLKEN yapılan "egzersiz" yerleştirmeleriyle).
- [ ] **Oyun sonu kartında k-lig sütunu (20 Ağustos 2026).** Bir oyunu
      sonuna kadar bitir. Kartta soldan sağa **Kalan · Toplam · k-lig**
      başlıkları olmalı; kazananın k-lig hücresi **+2**, 2 kişilikte ikincinin
      **-** (puan yok, ceza da yok). **Teslim olan varsa** (4 kişilik, süre
      aşımı) onun satırında **-2** k-lig sütununda durmalı — "Kalan"da DEĞİL;
      kullanıcının "kaybeden -2 aldı, kazanan puan almadı" diye bildirdiği
      karışıklık tam olarak buydu ve kart o gün DOĞRUYDU, yalnızca lig
      katkısını göstermiyordu.
- [ ] **Üç sütunun sayısı da kolonun SAĞINA yapışık (21 Ağustos 2026).**
      Özellikle k-lig'in `-` gösterdiği ve skorun 2 haneli olduğu bir satıra
      bak (ör. 4 kişilikte 3./4. sıra): skor ORTALI durmamalı, sağ komşusuna
      belirgin biçimde daha yakın olmalı. Sütunlar daha önce de sağa yaslıydı
      — şikâyet hizalamadan değil, kutuların içerikten geniş olmasından
      geliyordu (skorun solunda 19.5, sağında 20.0 px boşluk kalıyordu).
- [ ] **Uzun ad kartı TAŞIRMAZ.** 4 kişilik bir YZ oyunu bitir: "Yapay Zeka 1"
      gibi uzun adlar satırı ikiye sarmadan `…` ile kırpılmalı ve skor kartın
      sağ kenarından ASLA taşmamalı (dar bir telefonda/dar pencerede bak —
      hata tam olarak 320px'te görünüyordu). Alt satırdaki hamle sayısı
      etiketin YANINDA ve ortalı olmalı, satırın iki ucunda değil.
- [ ] **Bingo bonusu mesajda yazıyor (17 Ağustos 2026).** Rafın 7 taşını
      birden koyup OYNA'ya bas → mesaj satırında `(Bingo bonusu +25)`
      görünmeli. **DÖRT yerde ayrı ayrı koş, biri ötekini kanıtlamaz:**
      (a) yerel oyunda KENDİ hamlende, (b) yerel oyunda **YZ** bingo
      yapınca (`Yapay Zeka 2 "…" oynadı. +N puan. (Bingo bonusu +25)`),
      (c) Canlı oyunda kendi hamlende, (d) Canlı oyunda **rakibin** bingo'su
      geldiğinde — Canlı ekran mesajı reducer'dan DEĞİL `online_game_moves`
      satırlarından yeniden üretiyor, yani ayrı bir kod yolu.
      Negatif eş: bingo OLMAYAN sıradan bir hamlede bu parantez
      görünmemeli. Jokerli bitiş bonusu ile ASLA aynı mesajda olamaz
      (7 joker gerekirdi, torbada 2 var).
- [ ] **Tahta alt şeridi — "Nasıl Oynanır?" (14 Ağustos 2026).** Tahtanın
      altında SOLDA "Hamleler" (Canlı'da yanında "· Mesajlaşma"), SAĞDA
      **"Nasıl Oynanır?"** olmalı; eski `- kelime X2 · - kelime X3`
      açıklaması HİÇBİR yerde görünmemeli. Dokununca kurallar açılmalı —
      hem yerel/YZ hem Canlı oyun ekranında ayrı ayrı dene (ikisi farklı
      kod yolundan açıyor). Yerel ekranda kapatınca oyun normal devam
      etmeli (kurallar penceresi oyunu etkilemez).
- [ ] **Boş taslakta OYNA (14 Ağustos 2026).** Sıra sendeyken hiç taş
      koymadan OYNA'ya bas: mesaj satırında **"Harf yerleştirilmedi."**
      çıkmalı. Önceden Canlı ekranda hiçbir şey olmuyor, bir önceki metin
      ("Taşlar rafa geri alındı") duruyordu — YZ oyunu bunu baştan doğru
      yapıyordu, iki ekranı yan yana karşılaştır.
- [ ] **Çevrimdışı Canlı oyun AÇILIŞI (14 Ağustos 2026).** Uçak modunda
      Setup'tan bir Canlı oyuna dokun: beyaz "Yükleniyor…" ekranında ASILI
      KALMAMALI — "Canlı oyun için internet gerekiyor" paneli + "Tekrar
      Dene" + "← Canlı Listesi" çıkmalı. Bağlantı gelince "Tekrar Dene"
      oyunu açmalı. (Canlı oyun yapısı gereği çevrimiçidir; offline
      dayanıklılık yalnızca Yapay Zeka oyunları için vardır.)
- [ ] **Çevrimdışı sekme metinleri (14 Ağustos 2026).** Uçak modundayken
      Setup'a dön: **Arkadaşınla**'nın üç alt sekmesi de "İnternet bağlantısı
      yok" demeli ("davetiniz yok"/"Yükleniyor…" DEĞİL). **Yapay Zeka ile**
      sekmesinde ise, devam eden bir oyunun YOKSA, "…yapay zeka ile çevrimdışı
      da oynayabilirsin. **Hemen oyun aç.**" çıkmalı; linke dokunmak
      "+ Yeni Yapay Zeka Oyunu" ile aynı formu açmalı. Devam eden bir YZ
      oyunun VARSA liste normal görünmeli (çevrimdışı oynanabiliyor).
- [ ] **Çevrimdışı kelime anlamı (14 Ağustos 2026, WEB'e özel).** Uçak
      modunda bir YZ oyununda oynanan kelimeye dokun: "Kelime anlamları için
      internet bağlantısı gerekiyor." çıkmalı — "Bu kelimenin anlamı
      bulunamadı." DEĞİL (kelime sözlükte olabilir, veri indirilemiyor:
      `meanings.json` 6.3 MB, precache'e bilerek alınmıyor). Çevrimiçiyken
      gerçekten sözlükte olmayan bir kelimede hâlâ "bulunamadı" demeli.
      **Uygulamada (Flutter) bu mesaj HİÇ çıkmamalı** — orada sözlük pakette.
- [ ] **Gönderim hatası GÖRÜNÜR (14 Ağustos 2026).** Geçerli bir kelime
      kurup uçak modunda OYNA'ya bas: mesaj satırında bir ağ hatası
      görünmeli — "Oyna tuşuyla kelimeyi onayla." DEĞİL. Alttaki
      **"Çevrimdışı"** yazısı da alt şeritteki öteki linklerle (Hamleler ·
      Mesajlaşma · Nasıl Oynanır?) AYNI puntoda olmalı; belirgin şekilde
      küçükse regresyon. Sonra bir taşı oynat: hata kaybolmalı. Aynı
      kontrol PAS GEÇ/DEĞİŞTİR için de geçerli.
- [ ] **Sohbet ön plana dönüşte tazelenir (14 Ağustos 2026).** Oyun ekranı
      AÇIKKEN sekmeyi/uygulamayı arka plana al, karşı taraftan mesaj
      gönder, sonra geri dön: mesaj kendiliğinden gelmeli (oyundan çıkıp
      girmek gerekmemeli). Popup çıkmamalı, yalnız okunmamış sayacı artmalı.
- [ ] **Sürükle-bırak.** Raftan tahtaya, tahtada taşıma, tahtadan rafa geri
      alma — üçü de çalışmalı (yerel oyundakiyle aynı davranış).
- [ ] **Realtime.** Karşı taraf oynadığında ekran kendiliğinden güncellenmeli.
      Sekmeyi arka plana alıp geri dönünce de senkron olmalı (mobil tarayıcılar
      arka plandaki websocket'i askıya alıyor, ön plana dönüşte elle yenileniyor).
- [ ] **4 kişilikte YZ turu.** 3. insan oynadıktan sonra YZ kendiliğinden
      oynamalı — uygulamayı kapatıp açmaya gerek kalmadan.
- [ ] **Skor kutusu → skor kartı.** Header'daki bir insan oyuncunun kutusuna
      dokununca `PlayerScoreCard` açılmalı; YZ kutusu tıklanabilir olmamalı.
- [ ] **Oyun bitince "Tekrar Oyna" (11 Ağustos 2026).** Oyun bitince "Oyna"nın
      yerini **"Tekrar Oyna"** almalı ("Canlı Listesi" DEĞİL). Tıkla → onay
      ("… ile aynı kadroda yeni bir oyun açılacak … Emin misin?"). Vazgeç
      hiçbir şey göndermemeli; onayla → "Davetiniz gönderilmiştir." → Tamam
      listeye dönmeli, yeni oyun "Rakip Bekleniyor"da görünmeli ve karşı
      hesaba davet + `notify-game-invite` e-postası gitmeli. **Biten oyunu
      SEN kurmamışsan da çalışmalı** (kurucu artık sen olursun) ve 4 kişilik
      + YZ'li bir oyunda YZ yine 4. koltukta kalmalı. Rakibi arkadaşlıktan
      çıkarıp denersen "Yalnızca arkadaşlarını davet edebilirsin." görünmeli
      ve ekranda kalınmalı.
- [ ] **Oyun GEÇMİŞİNDEN "Tekrar Oyna" (4 Eylül 2026).** "Tüm Oyunlarım"da
      bitmiş bir **Canlı** oyunun kartını aç, tahta önizlemesine tıkla:
      menüde **Paylaş · Tekrar Oyna · Kapat** olmalı. Tekrar Oyna → oyun
      sonundakiyle AYNI onay metni → onayla → "Davetiniz gönderilmiştir."
      ve yeni oyun "Rakip Bekleniyor"da görünmeli. **Biten oyunu SEN
      kurmamışsan da çalışmalı** (davet edilen taraf da rövanş açabilir).
      ⚠ **Bir YZ oyununun kartında "Tekrar Oyna" ÇIKMAMALI** — kapsam
      bilerek yalnızca Canlı oyunlar (yerel yeni oyun, kaydedilmiş devam
      eden oyunu ezebilirdi). ⚠ Admin panelinden BAŞKA bir üyenin geçmişine
      bakarken de çıkmamalı (o oyunun tarafı değilsin).
- [ ] **Yerel/YZ oyununda da "Tekrar Oyna" (11 Ağustos 2026).** Bir YZ oyununu
      bitir: buton "Yeni Oyun Aç" DEĞİL "Tekrar Oyna" olmalı; onaydan sonra
      Setup'a uğramadan aynı kadroyla taze bir oyun açılmalı. **Aynı ekranda
      iki oyunu üst üste bitir** — Skor Kartı → "Tüm Oyunlarım"da İKİSİ de
      görünmeli (Flutter portunda burada sessiz bir kayıt kaybı bulunmuştu).
- [ ] **Biten oyunun "Hamleler" dökümü SON hamleyi içermeli (15 Ağustos 2026).**
      Bir Canlı oyunu gerçekten sonuna kadar oyna (rafını torba boşken bitiren
      taraf ol ya da rakibin bitirmesini bekle), sonra Skor Kartı → "Tüm
      Oyunlarım" → o kartın hamle ikonu. **Dökümdeki en son satır, oyunu
      BİTİREN hamle olmalı** — kendi son hamlen değil. Aynı kontrolü teslimle
      biten bir oyunda da yap (48 saatlik süre aşımı, bkz. bölüm 4): son satır
      "Teslim" olmalı. Arşiv `online_game_moves`'tan üretildiğinden buradaki
      bir eksik, oyunun kendisini değil yalnızca kaydı bozar — yani oyun doğru
      bitmiş görünse bile bu maddeyi ayrıca koş.

## 3. Oyun içi mesajlaşma

- [ ] **İlk açılış.** Tahtanın altındaki "Mesajlaşma" → hoşgeldin popup'ı
      ("Devam") → sohbet penceresi. Buton yalnızca Canlı oyunlarda görünmeli,
      YZ oyununda hiç olmamalı.
- [ ] **Gönderme.** 200 karakter sınırı ve canlı "x/200" sayacı çalışmalı.
      Kendi mesajın sağda/kendi renginde, karşınınki solda.
- [ ] **Yönlendirme etiketi (2 Eylül 2026, kullanıcı isteği).** Mesaj
      kutusunun HEMEN ÜSTÜNDE "Oyunculara buradan mesaj gönder" yazmalı;
      yazmaya başlayınca kaybolan `Mesajınızı girin` yer tutucusu da
      YERİNDE kalmalı (etiket onun yerine geçmedi, ona EK). Aynı satır
      portta da var — ikisi birlikte kontrol edilmeli.
- [ ] **Sıralama — en yeni EN ÜSTTE, ÜÇ ekranda birden.** Sohbet penceresi
      (`ChatModal`), biten oyunun sohbet arşivi (Tüm Oyunlarım → konuşma
      balonu rozeti) ve admin sohbet dökümü (Şikayetler → "Sohbeti
      Görüntüle"). Üçü de aynı `ChatThread`'i besliyor ama yön kararı her
      birinin KENDİ çağrısında — biri değişirse üçü de kontrol edilmeli.
      (9 Ağustos 2026'ya kadar yalnızca sohbet penceresi doğru yöndeydi;
      iki arşiv ekranı ters duruyordu. Admin dökümü ise 10 Ağustos akşamına
      kadar canlıda hâlâ ters kaldı — düzeltme port dalında mahsur
      kalmıştı, bkz. `CLAUDE.md` → "Port dalında mahsur kalan web
      düzeltmeleri".)
- [ ] **Yazışma gizliliği (10 Ağustos 2026).** k-lig'den başka bir oyuncunun
      kartına gir → "Tüm Oyunlar". Onun **katılmadığın** bir Canlı oyununun
      kartında konuşma balonu rozeti **HİÇ ÇIKMAMALI** — ne sayı ne içerik.
      Kendi katıldığın oyunlarda normal görünmeli; admin hepsini görebilmeli.
      (O tarihe kadar `games.messages` girişli HERKESE açıktı — skor/tahta
      herkese görünür olsa da yazışma değil.)
- [ ] **Kafa kafaya oran çubuğu (3 Eylül 2026) — İKİ HESAP GEREKİR.**
      A hesabıyla gir, k-lig listesinden B'nin kartını aç. Alt satırda solda
      `Tüm Oyunlar` butonu (SOLA yaslı; kendi Skor Kartı'ndaki buton da artık
      aynı adı taşıyor ve sola yaslı — ikisini yan yana karşılaştır), sağda
      ÜÇ satır: en üstte yüzdeler, ortada **B'nin avatarı · üç renkli çubuk ·
      A'nın (senin) avatarı**, en altta oyun sayısı ORTALI. İsim YAZMAMALI.
      - **Yüzdeler kendi renklerinde ve kendi alanlarının üzerinde:** sol
        kırmızı, sağ yeşil. Çok tek taraflı bir skorda (ör. 1–19) dar
        dilimin etiketi çubuğun dışına TAŞMAMALI ve iki etiket
        ÇAKIŞMAMALI.
      - **Beraberliğin yüzdesi HİÇ yazmamalı** — ortadaki gri bant görünür,
        ama üstünde sayı yok.
      - Bir uç %0 ise o etiket yazılmamalı, ama kalan etiket ortaya
        KAYMAMALI (sağdaysa sağda, soldaysa solda kalmalı).
      - Renkler soldan sağa: **B'nin kazandıkları (kırmızı) · beraberlik
        (gri) · senin kazandıkların (yeşil)** — yani her avatar kendi
        tarafındaki dilime bakıyor.
      - **AYNA KONTROLÜ (asıl kontrol bu):** B hesabıyla gir ve A'nın
        kartını aç. Oyun sayısı AYNI olmalı, kazanma/kaybetme rakamları
        TERSİNE dönmeli (A'da 5-9 ise B'de 9-5). Tutmuyorsa sunucudaki
        eşleme yanlış.
      - **Kendi kartında ÇUBUK HİÇ ÇIKMAMALI** (hesap menüsü → Skor Kartı).
      - Hiç oynamadığın birinin kartında da çıkmamalı — çubuk yerine
        yalnızca `Tüm Oyunlar` butonu görünür.
      - **YALNIZCA 2 kişilik Canlı oyunlar sayılır** (kullanıcı kararı): 4
        kişilik ortak bir oyununuz varsa sayıya girmemeli. YZ oyunları da
        girmemeli.
      - Teslim olarak biten bir oyununuz varsa teslim olan taraf KAYBETMİŞ
        sayılmalı — iki taraf da 0 puanla bitmiş olsa bile beraberlik
        görünmemeli.
- [ ] **"Oyun Bitti (Yeni)" — biten oyunun haberi (3 Eylül 2026) — İKİ HESAP
      GEREKİR.**
      - **Kurulum:** A ile bir Canlı oyunda hamleni yap ve uygulamayı KAPAT.
        B ile oyunu bitir (rafını bitir ya da teslim ol). A'ya dön.
      - **Beklenen:** "Arkadaşınla" ÜST sekmesinde kırmızı sayı ARTMIŞ olmalı
        (bekleyen davet/sıra sayısının ÜSTÜNE eklenir), "Son Oynananlar" ALT
        sekmesinde de aynı sayı. İçeri girince o oyunun satırında ortada
        `OYUN BİTTİ` ve altında kırmızı `YENİ`.
      - **Sayı GİRİNCE sıfırlanır, rozet ÇIKINCA kalkar:** sekmedeyken
        `YENİ` durmaya devam etmeli (gözünün önünde kaybolMAMALI); başka bir
        sekmeye geçip geri geldiğinde `YENİ` gitmiş, `OYUN BİTTİ` kalmış
        olmalı.
      - **Oyuna TIKLAMADAN çıkmak da sıfırlar:** sekmeye gir, hiçbir oyuna
        dokunma, başka sekmeye geç → sayı sıfır, dönünce `YENİ` yok.
      - **Oyunu BİTİREN kişide rozet ÇIKMAMALI:** B tarafında (bitiş modalını
        gören) o oyun için `YENİ` görünmemeli — sayı da artmamalı.
      - **`OYUN BİTTİ` etiketi YALNIZCA Canlı tarafta** — Canlı'da her
        satırda (eski oyunlarda da), **YZ tarafındaki "Son Oynananlar"da HİÇ
        çıkmamalı** (kullanıcı kararı: YZ oyunu senin cihazında bitiyor,
        orada etiket bilgi taşımaz). YZ sekmesinde kırmızı sayı da olmamalı.
      - **Süre aşımı teslimi:** bir oyunun 48 saatlik süresi dolup teslim
        sayıldığında da rozet ÇIKMALI (o senaryoda bitiş modalını görmen
        mümkün değil — asıl işe yaradığı yer burası). O satırın etiketi
        `OYUN BİTTİ` değil **`TESLİM OLDUN`** olmalı ve sağda kırmızı `-2`
        durmalı. **Rakip tarafında** ise aynı oyun `OYUN BİTTİ` görünmeli
        (o kazandı) — `TESLİM OLDUN` yalnızca teslim EDENİN satırında.
      - **Etiket ORTADA, rozet YANINDA:** etiket sol sütun ile skorun
        arasındaki boşlukta ortalanmış olmalı (sağa yaslı DEĞİL), `YENİ`
        rozeti etiketin hemen SAĞINDA (altında değil).
      - **`YENİ` rozetinde İ'nin NOKTASI görünmeli** — "YENI" gibi
        okunuyorsa punto küçülmüş demektir (Space Mono'da nokta 9 px'te
        gövdeye yapışıyor; etiket ve rozet 11 px olmalı).
      - **Küçük ekran + en büyük yazı boyutu:** 320 px genişlikte, sistem
        yazı boyutu en büyükte, 4 kişilik + `YENİ` rozetli bir `TESLİM
        OLDUN` satırında etiket `…` ile KIRPILMAMALI. Rozetin bu durumda
        etiketin ALTINA inmesi NORMAL (kabul edilen davranış) — 360 px ve
        normal yazı boyutunda ise YANINDA olmak zorunda.
      - ⚠ **Uygulama ikonundaki rozete KARIŞMAMALI** (kullanıcı kararı):
        biten oyun ikon rozetini artırMAMALI ve girişte hangi sekmenin
        açıldığını DEĞİŞTİRMEMELİ.
      - **Çevrimdışı:** uçak modunda sekmeye gir → sayı sıfırlanMAMALI
        (sunucu onaylamadı). Ağ gelince tazelenince hâlâ orada olmalı.
- [ ] **Hamle geçmişi ikonu (12 Ağustos 2026).** Tüm Oyunlarım'da, dökümü
      OLAN kartlarda küçük bir döküman ikonu olmalı; dokununca o oyunun TAM
      hamle dökümü açılmalı (kelime + ham puan + ×2/×3 rozetleri,
      Bingo/Sınır İhlali etiketleri, toplam puan).
      Çevrimdışıyken dokunulunca "kaydedilmemiş" DEĞİL "Bağlantını kontrol
      edip tekrar dene." demeli — ikisi ayrı durum.
- [ ] **İkon YALNIZCA dökümü olan kartta (aynı gün düzeltildi).** Kolon
      12 Ağustos 2026 15:27 UTC'de açıldı; ondan ÖNCE biten YEREL oyunların
      dökümü kurtarılamıyor, Canlı oyunlar geriye dönük dolduruldu. Yani
      **eski YZ kartlarında ikon HİÇ çıkmamalı** (ilk sürüm çıkarıyor ve
      boş bir diyalog açıyordu), Canlı kartlarda çıkmalı.
      **EN KRİTİK KONTROL — kural tür bazlı DEĞİL:** yeni bir YZ oyunu
      sonuna kadar bitir; O kartta ikon ÇIKMALI ve döküm dolu gelmeli.
      Çıkmıyorsa `buildGameRecord`/`saveGame` zinciri `moves`u yazmıyor
      demektir (yani "YZ'de hiç gösterme" gibi yanlış bir kural kalmış).
- [ ] **Dokunmatikte ikona tek dokunuşta basılabilmeli (aynı gün, mobil
      cihaz testinden geldi).** iPad/telefonda parmakla dene: "tam
      basamazsan kart açılıp kapanıyor" olmamalı. Ölçüt yanındaki **sohbet
      rozetiyle aynı kolaylık** — dokunma kutuları ölçülerek eşitlendi
      (280px² vs 255px²). İkonun GÖRSEL konumu ve sohbet rozetiyle
      arasındaki 6px boşluk değişMEmeli (`-mx-1` negatif margin tam bunun
      için); kayma varsa dolgu/margin dengesi bozulmuş demektir. Mobil
      uygulamada aynı kartı aç — iki platform aynı hissi vermeli.
- [ ] **Karşı tarafta.** Sohbet kapalıyken gelen mesaj için popup (gönderenin
      avatarı + adı + metin) çıkmalı ve **yalnızca elle** kapanmalı; butonda
      **sayı rozeti** belirmeli (16 Ağustos 2026'ya kadar sayısız bir
      noktaydı). İKİ mesaj gelirse rozet **2** göstermeli; sohbeti açınca
      sıfırlanıp kaybolmalı. Rozet "Mesajlaşma" etiketinin son harflerini
      kapatır — bilinen ve kabul edilen bedel, kırpılma DEĞİL; ama sağdaki
      "Nasıl Oynanır?" ile ÇAKIŞMAMALI (dar bir telefonda kontrol et).
- [ ] **Geç giriş.** Uygulama kapalıyken mesaj gelsin; tekrar girince rozet
      doğru sayıyla çıkmalı. Hiç yeni mesaj yokken **çıkmamalı** (ilk sürümde
      yanlış pozitif veriyordu).
- [ ] **Sessize alma.** Sohbet başlığındaki dişli → kişi → "Kişiyi Sessize Al"
      → onay. Artık o kişiden **popup ÇIKMAMALI**, ama **rozet ARTMALI**
      (15 Ağustos 2026 kararı: mute yalnızca popup'ı bastırır) ve mesajları
      sohbette görünmeye devam etmeli. İsminin yanında 🚫 çıkmalı.
      Aynı oyunda susturulMAMIŞ başka biri yazarsa hem rozet hem popup
      çıkmalı (4 kişilik bir oyunda kontrol edilebilir).
- [ ] **Rapor etme.** Aynı panelden neden yazıp gönder → onay → **"Şikayetiniz
      iletildi."** ekranı. Rozet 🚩'a dönmeli (rapor otomatik olarak sessize
      de alır). Raporlanan kişide **hiçbir değişiklik olmamalı** (bilinçli:
      endüstri standardı, misilleme riski).
- [ ] **Mesaja dokunma.** Karşı tarafın mesaj balonuna dokununca da aynı ayar
      paneli o kişiyle açılmalı.
- [ ] **Kişi bazlı kalıcılık.** Aynı kişiyle YENİ bir Canlı oyun aç: 🚫/🚩
      rozetleri orada da görünmeli (durum oyuna değil kişiye bağlı).
- [ ] **Geri çekme.** "Raporu Geri Çek" → onay. Bayrak kalkmalı; sessize alma
      bundan etkilenmemeli (bağımsız). Aynı kişi tekrar raporlanabilmeli.
- [ ] **Oyun BİTTİKTEN sonra geri alma (14 Ağustos 2026).** Şikayet ettiğin
      kişiyle oyun bitsin (ya da listeden düşsün). Hesap menüsü → Arkadaşlar →
      "Arkadaşlarım": o kişinin satırında, "arkadaşlıktan çıkar" ikonunun
      **SOLUNDA** 🚩 (yalnızca sessize aldıysan 🚫) çıkmalı; dokununca
      "Kişi Ayarları" paneli açılmalı ve oradan şikayet geri çekilip/sessizden
      çıkılabilmeli. Panel kapanınca ikon **HEMEN** kaybolmalı.
      **Negatif eş:** hiçbir moderasyon durumu OLMAYAN bir arkadaşın satırında
      bu ikon **hiç görünmemeli** — ikisini birlikte kontrol et, yoksa
      "koşulsuz çizen" bir hata da geçer gibi görünür.
      Bu, o güne kadar kapalı olan tek yolun açılması: geri almanın tek girişi
      AKTİF bir oyunun sohbet ayarlarıydı, yani şikayeti geri çekmek için
      raporladığın kişiyle yeni bir oyun açman gerekiyordu.
      **Yeni şikayet buradan açılAMAZ** (bilinçli — şikayet konuşmaya bağlı);
      panel bunu söyleyen bir not göstermeli.
- [ ] **Geri çekilen rapor admin'de hâlâ "okunmamış".** Kart "Geri Çekildi"
      rozetini alır ama soluklaşMAmalı ve bekleyen sayaçlarından düşMEmeli —
      admin ne yaşandığını görüp okundu işaretlemeyi kendisi seçmeli. (Bir
      dönem geri çekme otomatik `handled=true` yapıyordu; rapor admin hiç
      bakmadan "incelenmiş" görünüyordu.)
      **Bu madde 14 Ağustos 2026'ya kadar hiç GEÇMİYORDU ve kimse fark
      etmedi:** 4 Ağustos'taki düzeltme yanlış bir SQL overload'ına
      uygulanmış, istemcinin çağırdığı sürüm 10 gün boyunca `handled=true`
      yapmaya devam etmişti (`fix_withdraw_report_wrong_overload`). Bu
      pencerede hiç geri çekme yapılmadığı için bozulan veri olmadı —
      yani liste "yeşil" görünüyordu çünkü kimse maddeyi koşmamıştı.
      Koşarken **hesap menüsündeki "Admin Paneli" kırmızı sayacına da bak**,
      yalnızca kartın rengine değil: asıl kırılan şey oydu.
      **14 Ağustos 2026'da GERÇEK hesapla koşuldu ve GEÇTİ** — geri çekme
      `handled`'a dokunmadı, kart "Yeni" kaldı, sayaç düşmedi; admin okundu
      işaretleyince `handled` true'ya döndü. Yani madde artık yalnızca
      "yeşil görünmüyor", gerçekten kanıtlanmış durumda.
- [ ] **Admin.** Admin Paneli → Geri Bildirim → Şikayetler: kart "Yeni"
      rozetiyle görünmeli, "Sohbeti Görüntüle" (yalnızca BİTMİŞ oyunlarda)
      dökümü açmalı, "Kişiye Git →" Üyeler tablosunda o satırı vurgulamalı.

## 4. Süre aşımı ve cezalar

Bunlar gerçek zamanda 24-48 saat/7 gün bekler; acele ediyorsan veritabanından
`turn_deadline`/`updated_at`/`created_at` geçmişe çekilerek tetiklenebilir.

**Süreyi geçmişe çekerken:** yalnızca test hesaplarının satırlarına dokun,
`id` ile hedefleyerek. Bu tablolarda gerçek kullanıcıların oyunları da duruyor
ve buradaki her akış gerçek bir e-posta gönderip gerçek bir k-lig cezası
uyguluyor. Değişiklikten sonra, tetiklemeden önce, cron'un/süpürmenin gerçekte
neyi kapsayacağını bir kez sorgulayıp doğrula.

**Mail hangi hesaba gidiyor:** uyarılan/teslim olan taraf hangi hesapsa mail
ona gider. Görsel doğrulama yapacaksan testi, o taraf **gerçek gelen kutusu
olan** hesap olacak şekilde kur (bkz. yukarıdaki Mailinator notu) — gerekirse
önce bir hamle oynayıp sırayı o tarafa geçir.

- [ ] **24 saat uyarısı.** Sırası gelen oyuncuya "Oyun Süresi Doluyor!" maili.
      Fonksiyonun **iki ayrı dalı** var (Canlı oyun + devam eden YZ oyunu) —
      ikisini aynı anda pencereye sokup **iki mail** geldiğini doğrula, tek
      dal çalışıyor olabilir. Metin isme iyelik eki eklememeli: "X **tarafından
      açılan** oyun" (takma isimlerde ünlü uyumu garanti edilemez).
- [ ] **48 saat aşımı (Canlı).** Sırası gelen otomatik teslim: puanı 0, rafı
      torbaya karışır. 2 kişilikte oyun anında biter. Teslim olana -2, karşı
      tarafa galibiyet +2. Teslim olana "Süre Aşımından Sona Erdi" maili.
- [ ] **Teslim sonrası torba sayacı.** `online_game_states.bag_count`, teslim
      olanın rafı geri karıştıktan sonra gerçek torbaya (`online_game_secrets.
      bag`) eşit olmalı. **4 kişilikte** asıl görünür: teslim oyunu bitirmediği
      için kalan oyuncular tahtada torbayı doğru görmeli, bir sonraki hamleyi
      beklemeden.
- [ ] **7 gün (YZ oyunu).** Devam eden YZ oyunu terk edilmiş sayılır, -2 ve
      bilgilendirme maili. Misafirde yalnızca yerel kayıt silinir (ceza yok).
- [ ] **Hiç oynanmamış YZ oyunu iz bırakmamalı.** Girişliyken bir YZ oyunu aç,
      **hiç hamle yapmadan** logoya bas. Setup'ta "Devam Edenler" listesinde
      hiçbir satır kalmamalı ve "Yapay Zeka ile" rozeti artmamalı — sekme
      değiştirip dönmeye gerek kalmadan, **ilk görünüşte**. (Satır zaten
      siliniyordu; listeyi çeken sorgu silme sunucuda commit edilmeden yola
      çıktığından kaydı bir kez daha gösteriyordu — 5 Ağustos 2026. Bu yüzden
      "sekme değiştirince düzeliyor" bir geçiş sayılmaz.) Oyunu 2+ hamle
      oynayıp terk edince ise satır listede KALMALI, bu doğru davranış.
- [ ] **Süpürme öne dönüşte de çalışıyor.** Uygulamayı Setup'ta açık bırakıp
      arka plana al, süreyi geçmişe çek, sonra öne getir — tam yeniden
      yüklemeden süpürülmeli. (Eskiden yalnızca mount'ta çalışıyordu, ceza
      kullanıcı uygulamayı baştan açana kadar gecikiyordu.)
- [ ] **7 gün (davet).** Yanıtlanmamış davet kendiliğinden iptal olur —
      **iki tarafta da**. Kuranın "Rakip Bekleniyor" listesinden ve
      **davetlinin "Davet Bekliyor" listesinden** kalkmalı; davetli tarafı
      ayrıca kontrol et, iptal yalnızca `online_games.status`'ü değiştirip
      `game_invites` satırını `pending` bıraktığından bu kova bir dönem
      filtrelemeyi atlamıştı. Rozetlerin de düşmesi lazım (Setup'taki
      "Arkadaşınla", "Oyun Davetleri" alt sekmesi, PWA ikonu).

### 4.x Girişli kullanıcının offline dayanıklılığı (12 Ağustos 2026)

Bu bölüm **kurulabilir PWA'da** (ana ekrana eklenmiş) koşulmalı — normal bir
tarayıcı sekmesinde uçak modunda sayfa yenilenirse Safari/Chrome kendi
"internet yok" sayfasını gösterir ve uygulama zaten açılmaz; asıl senaryo
service worker'ın precache'iyle açılan kurulu uygulama.

Hepsi GİRİŞLİ hesapla. Ayna/önbellek anahtarları: `kelimeki:cloud-save-mirror`,
`kelimeki:cloud-save-cache`, `kelimeki:cloud-save-deletes` (DevTools →
Application → Local Storage'dan izlenebilir; online akışta ilk ikisi boş kalmalı).

- [ ] **Offline hamleler kaybolmuyor.** Bir YZ oyunu aç, birkaç hamle oyna,
      uçak moduna geç, birkaç hamle daha oyna. Ağı geri aç, Setup'a dön ve
      oyuna devam et — offline oynanan hamleler DURUYOR olmalı (skor/tur
      sayısı geri gitmemeli). Ağ kapalıyken `cloud-save-mirror` dolmalı,
      geri açılıp senkron olunca boşalmalı.
- [ ] **Offline'da liste görünüyor.** Uçak modundayken Setup'a dön —
      "Devam Eden Oyunlar" boş DEĞİL, oyunlar (offline oynanmamış olanlar
      dahil) listede olmalı ve tıklanınca devam edilebilmeli.
- [ ] **Offline biten oyun geri gelmiyor.** Uçak modundayken bir oyunu
      SONUNA kadar bitir, sonra ağı aç ve Setup'a dön — oyun "Devam Eden
      Oyunlar"da GÖRÜNMEMELİ (silme kuyruğu onu temizlemeli) ve Skor
      Kartı'nda bir kez görünmeli.
- [ ] **7 gün kuralı offline'da atlatılamıyor.** Bir oyunu aç, uçak moduna
      geç, satırın `updated_at`'ini 8 gün geriye çek (ağ açıkken, sonra
      tekrar kapat), sonra ağı aç ve Setup'a dön — oyun terk sayılıp -2
      uygulanmalı; ağa çıkar çıkmaz "taze" sayılıp cezadan KURTULMAMALI.
- [ ] **Taze offline hamle haksız ceza almıyor** (yukarıdakinin tersi):
      satırı 8 gün geriye çek, sonra uçak modunda BİR HAMLE oyna, ağı aç —
      oyun listede DURMALI, ceza uygulanMAMALI.

## 5. E-posta bildirimleri

Onbir Edge Function var; hepsi `noreply@kelimeki.com`'dan, Brevo üzerinden.
**Gerçek bir gelen kutusunda** kontrol et (bkz. yukarıdaki Mailinator notu).
Her birinde: marka kartı + logo görünüyor mu, Türkçe karakterler doğru mu,
buton doğru yere gidiyor mu.

- [ ] Arkadaşlık isteği (`notify-friend-request`)
- [ ] Arkadaşlık isteği hatırlatması — 3 gün sonra, tek sefer
- [ ] Canlı oyun daveti (`notify-game-invite`)
- [ ] Süre uyarısı (`notify-deadline-warnings`, cron)
- [ ] Canlı süre aşımı teslimi (`notify-turn-timeout-surrender`)
- [ ] Yerel oyun terk edilmesi (`notify-local-game-abandoned`)
- [ ] Hesap dondurma / dondurmayı kaldırma
- [ ] Geri bildirim yanıtı ve admin mesajı — "cevap için tıklayın" linki
      siteyi `?contact=1` ile açıp formu otomatik açmalı
- [ ] **Opt-out.** Hesap Ayarları'ndan e-posta bildirimlerini kapat; tercih
      edilebilir olanlar (yukarıdaki ilk altı) gitmemeli, hesap güvenliği ve
      admin yazışması gitmeye devam etmeli.

## 6. Auth e-postaları (Supabase şablonları)

Bunlar Edge Function değil, Supabase Auth'un kendi mailleri. Şablonlar
`supabase/email-templates/*.html`'de duruyor ama **repodan otomatik
okunmuyor** — Dashboard → Authentication → Emails → Templates'e elle
yapıştırılmaları gerekiyor. Şablon dosyaları değiştiyse Dashboard'daki
kopyanın da güncellendiğini doğrula.

- [ ] Kayıt onayı, şifre sıfırlama, e-posta değişikliği — üçü de marka kartıyla
      gelmeli, gönderen "Kelimeki &lt;noreply@kelimeki.com&gt;" olmalı.

## 7. Bildirim rozetleri (site geneli)

Kırmızı yuvarlak sayı rozeti tek bir bileşenden gelir (`CountBadge`) ve her
zaman **bekleyen iş sayısını** gösterir. Bu, bölüm bölüm test edilirken
gözden kaçıyor: bir sekmeye rozet eklenip onu kapsayan üst sekmenin toplamı
güncellenmeyince sayılar sessizce ayrışıyor (iki ayrı kez oldu). Aşağıdakileri
tek turda, gerçekten bekleyen bir iş varken kontrol et.

- [ ] **Toplama zinciri.** Bekleyen bir geri bildirim VE bekleyen bir şikayet
      aynı anda varken: Admin Paneli'ndeki "Gelen Kutusu" ve "Şikayetler" alt
      sekmeleri kendi sayılarını, üstteki "Geri Bildirim" tab'ı ikisinin
      TOPLAMINI, `UserMenu`'deki "Admin Paneli" satırı da aynı toplamı
      göstermeli — üçü asla ayrışmamalı.
- [ ] **Diğer rozetler.** `UserMenu` → "Arkadaşlar" (bekleyen istek), Setup →
      "Yapay Zeka ile"/"Arkadaşınla" ve bunların alt sekmeleri, `FriendsModal`
      → "İstekler". Hepsi sağ üst köşede yuvarlak rozet olmalı; başlığa
      gömülü " (N)" biçiminde bir sayı **hiçbir yerde kalmamalı**.
- [ ] **Eski noktalar da artık sayı gösteriyor (16 Ağustos 2026).** Board
      footer'ındaki "Mesajlaşma" ve `UserMenu` avatarı — ikisi de sayısız
      kırmızı noktaydı, kullanıcı fark edilmediklerini bildirince `CountBadge`e
      çevrildi. **Avatar rozeti TOPLAMDIR:** bekleyen arkadaşlık isteği +
      (admin isen) bekleyen geri bildirim/şikayet; menüyü aç, içerideki
      "Arkadaşlar" ve "Admin Paneli" rozetlerinin toplamı avatardakine eşit
      olmalı. Rozet avatarın sağ üst köşesinden taşar (bu doğru); GameHeader'ın
      yatay kaydırılan şeridinde **kırpılmamalı** — oyun ekranında da kontrol et.
- [ ] **Rozet olMAması gerekenler.** "Değiştir (N)" (seçili taş sayısı) ve
      "Arkadaşlarını Seç (N/3)" (seçim ilerlemesi) — bunlar bekleyen iş değil,
      metin içinde kalmalı.

## 8. "Bekleyen iş öne çıksın" — varsayılan sekmeler

Rozet bekleyen işi gösterir; bu kural kullanıcıyı oraya götürür. Dört ekran
aynı deseni paylaşıyor, dolayısıyla biri bozulduğunda diğerleri de şüpheli.
Her birinde gerçekten bekleyen bir iş varken ekranı **kapatıp yeniden aç**.

- [ ] **Canlı sekmesi.** Bekleyen davet varsa "Oyun Davetleri", yoksa
      "Devam Edenler" açık gelmeli.
- [ ] **Davet SONRADAN gelmişken.** Yukarıdakinin asıl kırıldığı hâl, ayrıca
      koş: önce "Arkadaşınla"ya bir kez gir (davet YOKKEN — liste önbelleğe
      girsin), çık; **sonra** sana bir davet gönderilsin; tekrar gir.
      "Oyun Davetleri" açılmalı. (Önbellekten hidrate edilen bayat liste
      varsayılanı bir kez yanlış uygulayıp kalıcılaştırıyordu — 5 Ağustos
      2026. Aynısı hesap değiştirmeden, sadece "Yapay Zeka ile"ye gidip
      dönerek de üretilebilir.)
- [ ] **Arkadaşlar penceresi.** Bekleyen istek varsa "İstekler" açık gelmeli.
      Ama "+ Yeni Canlı Oyun" içindeki "arkadaş eklemek için tıkla"
      bağlantısından açılınca **"Ara & Ekle"de kalmalı** — o açık bir niyet,
      ezilmemeli.
- [ ] **Arkadaşlık ikonları (11 Ağustos 2026).** Satır aksiyonları metin
      değil ikon: kişi-ekle (mavi) · kum saati (gri, dokun → iptal) ·
      kişi-onay (mavi, gelen isteği kabul) · adam- (kırmızı, çıkar —
      yalnızca "Arkadaşlarım"da). **Dördü de önce onay sorar**, hiçbiri
      dokunulduğu an iş yapmaz; onayı iptal edince karşı hesapta hiçbir şey
      olmamalı. "Ara & Ekle" (arama + Tüm Üyeler) **zaten arkadaş olunanları
      HİÇ göstermez** — orada kırmızı adam- görünmemeli; bir gelen isteği
      oradan kabul edince satır listeden düşmeli. Bir sayfanın tamamı
      arkadaş çıksa bile "Tüm Üyeler" boş kalmamalı (sonraki sayfa gelir).
      **Aynı üye İKİ KEZ çıkmamalı (27 Ağustos 2026, `20260827153857`):**
      karşılıklı istek göndermiş bir çift varsa o üye tek satır olmalı —
      `list_users_for_friend`/`search_users_for_friend` `friend_requests`'e
      karşılıklı `OR` ile `left join` yaptığından iki yön de satırsa aynı
      profil çoğalıyordu (bkz. `docs/decisions/friends.md`).
      Skor kartında (k-lig → bir satır) arkadaş durumu **yeşil kişi-onay**
      — listedeki kırmızı adam- DEĞİL (bilinçli), dokununca yine çıkarma
      onayı açmalı.
- [ ] **Modal ✕'leri mobil tarayıcıda ıskalamıyor (27 Ağustos 2026).**
      Telefonda (ya da DevTools cihaz kipinde) bir modal aç ve ✕'in tam
      ortasına değil biraz ALTINA/yanına dokun — kapanmalı. Görsel olarak ✕
      aynı boyutta ve aynı yerde durmalı; büyüyen yalnızca tıklama alanı
      (`.tap-expand`, `src/index.css`). Aynısını Setup, Skor Kartı,
      Arkadaşlar, Sohbet, k-lig bilgi ve kutlama banner'ında da dene.
- [ ] **Raf taşını yakalamak kolaylaştı (aynı gün, portla birebir).**
      Taşın biraz ALTINDAN (rafın alt dolgusundan) ya da iki taşın
      ARASINDAN tutmayı dene — sürükleme başlamalı. Taşların boyutu,
      aralarındaki 3 px boşluk ve rafın dış kutusu DEĞİŞMEMELİ.
- [ ] **Titreşimli dokunuş (aynı gün, portla birebir).** Dokunurken
      parmağı biraz kaydır: taslak taş geri alınmalı, raf taşı seçilmeli ve
      istemeden tahtaya konmamalı. Gerçek sürükleme hâlâ çalışmalı.
- [ ] **Taslak taşı geri alma — ilk tıklamada (aynı gün, portla birebir).**
      Tahtaya taş koy, geri almak için üzerine tıkla; biraz altına/yanına
      denk gelse ve o hücre boş olsa bile taş geri gelmeli. Negatif kontrol:
      raftan taş SEÇİLİYKEN komşu boş hücreye tıklayınca harf konmalı.
- [ ] **Oyun kartındaki kalp / mesaj / hamle ikonları (aynı gün).**
      "Tüm Oyunlarım"da bu ikonların biraz altına/üstüne tıkla — ikonun
      eylemi çalışmalı, kart açılıp kapanmamalı. İkonlardan uzak bir yere
      tıklayınca kart eskisi gibi açılmalı. Görsel hiç değişmemeli.
- [ ] **Joker harf ızgarası (aynı gün, portla birebir).** Bir joker oyna →
      harflerin biraz altına/üstüne tıkla: istediğin harf gelmeli, komşu
      satırdaki değil. Harflerin boyutu ve aralığı değişmemeli; konmuş bir
      jokeri düzenlerken "Geri Al" butonu tam eski yerinde olmalı.
- [ ] **Kişiye tıklamak skor kartını açar — ÜÇ sekmede de (11 Ağustos
      2026).** "Arkadaşlarım", "İstekler" ve "Ara & Ekle" (arama + Tüm
      Üyeler) satırlarında **avatara/isme** tıkla → o kişinin skor kartı
      açılmalı. Aksiyon ikonu bundan ayrışık: ikona tıklamak kartı DEĞİL
      onay diyaloğunu açmalı. Kartın kendi arkadaşlık simgesinden bir işlem
      yapıp (ör. çıkar) kartı kapatınca satırdaki ikon ANINDA yeni duruma
      dönmeli.
- [ ] **Dokunmatikte yapışkan hover (11 Ağustos 2026).** Telefon/tablette
      Setup'ın altındaki "Kullanım Koşulları"na dokun, modalı kapat: linkin
      altında **kalıcı bir çizgi kalmamalı**. Aynısı "Nasıl oynanır?" ve menü
      satırları için de geçerli. Masaüstünde fareyle üzerine gelince alt
      çizgi HÂLÂ çıkmalı (o davranış korunuyor).
- [ ] **Admin paneli.** Bekleyen geri bildirim/şikayet varsa "Geri Bildirim"
      açık gelmeli (yoksa "Büyüme"). Gelen kutusunda bekleyen yokken yalnızca
      şikayet varsa doğrudan **"Şikayetler"** alt sekmesi açılmalı — aksi
      halde rozette sayı görünüp boş bir "Gelen Kutusu" karşılar.
- [ ] **YZ sekmesi.** "Son Oynananlar"a geç, "Arkadaşınla"ya gidip dön —
      "Devam Edenler" açılmalı. (İki taraf da sıfırlanır; bu bilinçli, akıllı
      varsayılan ancak sıfırlanan bir sekmede çalışabiliyor.)
- [ ] **Elle seçim ezilmemeli.** Bir ekranı açıp veri yüklenmeden HEMEN bir
      sekmeye dokun — liste gelince seçimin değişmemeli.
- [ ] **Sekme kendiliğinden DEĞİŞMEMELİ.** Bir sekmede otururken yeni bir
      davet/istek gelsin: yalnızca rozet artmalı, sekme zıplamamalı.
- [ ] **Seçim bir sonraki oturuma TAŞINMAMALI.** "Arkadaşınla" sekmesindeyken
      çıkış yap, sonra Canlı'da **hiçbir bekleyen işi olmayan** bir hesapla
      gir (rozet 0, aktif oyunda sıra rakipte olsun): "Yapay Zeka ile" ile
      açılmalı. Bu, bölüm 1'deki "Login varsayılanı"nın negatif eşi — orada
      sekmenin doğru açılması varsayılanın çalıştığını KANITLAMIYOR, çünkü
      taşınan seçim de aynı sonucu veriyordu. (`Setup`/`LiveGamesTab` çıkışta
      unmount olmuyor, `mainView` hiçbir yerde sıfırlanmıyordu — 5 Ağustos
      2026.)
- [ ] **Varsayılan İKİNCİ hesaba da uygulanmalı.** Bekleyen işi OLMAYAN bir
      hesapla gir (sekme "Yapay Zeka ile"de kalsın), çıkış yap, sonra bekleyen
      daveti/sırası OLAN başka bir hesapla gir: "Arkadaşınla" açılmalı. Aynı
      sekmede ikinci giriş olduğundan, "bir kez uygula" bayrağı hesap başına
      sıfırlanmazsa bu adım sessizce çalışmaz — yukarıdaki maddeyle birlikte
      koş, ikisi birbirinin kör noktasını kapatıyor.

## 9. Auth hata mesajları

Hepsi Türkçe olmalı — ham İngilizce ("User is banned", "Invalid login
credentials") görünmemeli. Bilinmeyen bir hata olduğu gibi geçer, bu doğru:
uydurma bir Türkçe cümleyle gizlemek hata ayıklamayı imkânsız kılardı.

- [ ] **Hatalı giriş.** Yanlış şifre → "E-posta ya da şifre hatalı."
- [ ] **Dondurulmuş hesap.** → "Hesabınız donduruldu. Gerekçesi ve itiraz yolu
      e-posta adresinize gönderildi." Şifre doğru da yanlış da olsa aynı mesaj
      çıkar (GoTrue şifreyi doğrulamadan ban'a bakıyor, ölçüldü).
- [ ] **Zaten kayıtlı e-posta.** Kayıt formunda mevcut bir adresle dene.
- [ ] **Form doğrulamaları bozulmamış.** Boş ad/soyad, alınmış takma isim →
      kendi Türkçe mesajları çıkmalı (bunlar aynı `catch`'ten geçiyor,
      çeviri katmanı onları ezmemeli).
- [ ] **E-posta linkinden gelen geri bildirim.** Bir bildirim mailindeki
      "cevap için tıklayın" ile gel, mesaj gönder: gönderim sonrası
      **üyelik teklifi çıkmamalı**, yalnızca teşekkür + "Kapat". (Uygulama
      içinden — oyun sonu, Terms/Privacy — açılan formda teklif hâlâ çıkar.)

## 9.5. Profil fotoğrafı (Hesap Ayarları)

13 Ağustos 2026'da iki şey birden değişti; ikisi de web'de elle
doğrulanmalı (mobil eşi `mobile/TESTING.md` bölüm 12'de).

- [ ] **Fotoğrafı DEĞİŞTİRME.** Zaten avatarı olan bir hesapta yeni bir
      fotoğraf yükle: hata ÇIKMAMALI. 20 Temmuz 2026'da `security_hardening`
      `avatars_public_read` SELECT politikasını düşürünce bu **web'de de**
      kırılmıştı (`upsert` var olan satırı görmeyi gerektiriyor) ve 13
      Ağustos'a kadar fark edilmemişti — yalnızca İLK yükleme çalışıyordu.
      `avatars_owner_read` ile düzeltildi.
- [ ] **10 MB giriş sınırı + küçültme.** Gerçek bir telefon fotoğrafı
      (2-10 MB) seç: yükleme başarılı olmalı. Sonra Supabase Dashboard →
      Storage → `avatars` → `<uid>/avatar.*` boyutuna bak: **saklanan dosya
      ~50-150 KB olmalı**, seçtiğin megabaytlar DEĞİL — 10 MB yalnızca
      giriş sınırı, `shrinkAvatar` yüklemeden önce 512 px kenara indirip
      JPEG'e çeviriyor. Avatar bulanık/bozuk görünmemeli. 10 MB üstünde
      "Görsel 10 MB'den küçük olmalı." çıkmalı.
- [ ] **Oyun ekranında avatarın dikey hizası (17 Ağustos 2026).** Profil
      FOTOĞRAFI olan bir hesapla bir oyuna gir: sağ üstteki avatarın dikey
      merkezi, solundaki skor kutularının merkeziyle aynı hizada olmalı.
      3.5px yukarıda duruyorsa `UserMenu`'deki avatar butonundan `flex`
      düşmüş demektir (`<img>` inline-level olduğundan butona taban çizgisi
      payı ekleniyor — ayrıntı `CLAUDE.md`, `UserMenu`). **Baş harfli
      (fotoğrafsız) bir hesap bu hatayı GÖSTERMEZ.**

## 9.6. Oyun geçmişi — ağ hatası (14 Ağustos 2026)

`fetchMyGames` artık boş listeden AYRI bir `failed` bayrağı taşıyor.
`npm run verify-fetch-my-games` sekiz senaryoyu (çevrimdışı, Favoriler'in
ayrı RPC yolu, misafir, tazelenemeyen token…) sahte bir Supabase ucuyla
otomatik doğruluyor; aşağıdaki liste bunun GERÇEK tarayıcıdaki teyidi.
Mobil eşi `mobile/TESTING.md` bölüm 5'te.

**iPad/mobil Safari'de DevTools yok — uçak modu kullan, ama SAYFAYI
YENİLEME.** Uygulama bir PWA; çevrimdışıyken yenilersen Safari kendi
"internet yok" sayfasını gösterebilir ve test ettiğin şey uygulama olmaz.
Gerek de yok: `fetchMyGames` modal açılınca / sekme değişince koşuyor.

> Bu bölümün ilk sürümü CİHAZDA DÜŞTÜ (14 Ağustos 2026): çevrimdışı hâlâ
> "Bu kategoride henüz kayıtlı oyun yok." çıkıyordu. Sebep `getUser()`in
> ağa gitmesi, `viewer`ın null dönmesi ve akışın `failed` bayrağı devreye
> girmeden erken dönmesiydi (`getSession()`e geçilerek düzeltildi). Yani
> bu maddeler teorik değil — bir kez gerçek bir hata yakaladılar.

- [ ] **Çevrimdışı liste.** DevTools → Network → Offline (ya da uçak modu),
      sonra Skor Kartı → "Tüm Oyunları Gör": **"Oyun geçmişi yüklenemedi.
      Bağlantını kontrol edip tekrar dene."** çıkmalı — "Bu kategoride henüz
      kayıtlı oyun yok." DEĞİL.
- [ ] **Favoriler sekmesi de aynı.** Aynı çevrimdışı durumda "Favoriler"e
      geç: orada da "yüklenemedi" çıkmalı ("Henüz favori işaretlediğin bir
      oyun yok." DEĞİL — o ayrı bir kod yolu, `list_liked_games` RPC'si).

> **Beklenen (hata DEĞİL): "Tümü"de mesaj ~5 sn gecikiyor, "Favoriler"de
> anında çıkıyor.** 17 Ağustos 2026 cihaz turunda gözlendi ve kabul edildi.
> Muhtemel sebep iki yolun HTTP metodunun farklı olması — "Tümü"
> `from('games').select()` ile **GET**, "Favoriler" `list_liked_games`
> RPC'siyle **POST** gönderiyor; tarayıcılar bağlantı hatasında idempotent
> istekleri (GET) yeniden deniyor, POST'u denemiyor. Bekleme her "Tümü"
> dönüşünde tekrarlıyor (tek seferlik bir önbellek etkisi değil). Ölçülerek
> KANITLANMADI; düzeltmek istenirse yol açık: `GameHistoryModal` çevrimdışı
> olduğunu `useOnlineStatus` ile baştan bilip çekimi hiç denemez, mesajı
> anında gösterir ve bağlantı dönünce kendiliğinden tazeler.
- [ ] **"Son Oynananlar" — YALNIZCA "Yapay Zeka ile" sekmesinde, İKİ dalı
      da, BU SIRAYLA.** `RecentGamesSection` çevrimdışıyken SADECE orada
      render ediliyor (aşağıdaki Canlı maddesine bkz.), ve koşulu
      (`setGames(cur => (!failed || cur === null ? rows : cur))`) iki
      dallı — yalnızca ikincisini test etmek yarım kalır:
      1. **Önce önbelleksiz:** o oturumda "Son Oynananlar"a HİÇ girmeden
         çevrimdışı ol ve gir → **"İnternet bağlantısı yok ama sorun değil,
         yapay zeka ile çevrimdışı da oynayabilirsin." + "Hemen oyun aç."**
         çıkmalı. **"yüklenemedi" DEĞİL** — `RecentGamesSection`
         `nothingToShow && !online && offlineNode` iken çağıranın verdiği
         düğümü gösteriyor, çünkü çevrimdışıyken "yüklenemedi" demek doğru
         ama kullanıcıya ne yapacağını söylemiyor.
      2. **Sonra önbellekli:** çevrimiçi ol, sekmeye gir (liste dolsun),
         tekrar çevrimdışı ol ve gir → **ESKİ liste kalmalı** (`cur !== null`
         — başarısız çekim ekrandaki listeyi ezmiyor); öneri de çıkmamalı,
         çünkü gösterilecek bir şey VAR.
      (Bu maddenin ilk sürümü 1. dalda "yüklenemedi" bekliyordu ve YANLIŞTI:
      madde 14 Ağustos 2026'da `failed` bayrağıyla birlikte yazıldı, AYNI
      GÜN daha sonra eklenen çevrimdışı öneri [`offlineNode`] onu geçersiz
      kıldı ve bölüm o günden beri hiç koşulmadığı için 17 Ağustos'a kadar
      fark edilmedi. `RecentGamesSection`'da "yüklenemedi" artık yalnızca
      çevrimİÇİ ama çekim başarısızken görünebilir.)
- [ ] **Canlı sekmesinde "Son Oynananlar" ÇEVRİMDIŞI HİÇ ÇİZİLMEZ — bu
      doğru davranış.** "Arkadaşınla"da uçak modu: üç alt sekme de (Devam
      Edenler / Oyun Davetleri / Son Oynananlar) tek bir **"İnternet
      bağlantısı yok"** gösterir; `LiveGamesTab`'ın `!online` dalı hepsini
      birden kısa devre yapıyor, yani orada "eski liste kalmalı" diye bir
      beklenti YOK. Önceden dolu olan liste kaybolur — bilinçli: Canlı
      tarafın her parçası sunucudan geliyor ve o listeden bir oyuna dokunmak
      zaten "bağlantı yok" paneline çıkıyor.
- [ ] **NEGATİF EŞİ ŞART.** ÇevrimİÇİ, gerçekten hiç oyunu olmayan bir
      hesapla aynı ekranları aç: orada NORMAL boş mesajlar çıkmalı. Bu
      olmadan yukarıdaki üç madde hiçbir şey kanıtlamaz — "her durumda
      yüklenemedi yazan" bir hata da onları geçerdi.

## 9.7-9.15. Admin paneli kontrolleri → `docs/testing-admin.md`

Admin panelinin **dokuz** kontrol bölümü (Aktif Oyuncu/Aktivasyon/Retention,
Platform dökümü, Kaynak Hunisi, Oyun Süresi + YZ Dengesi, metrik `?`
rozetleri, Üyeler tablosu alanları, "Hatalar" sekmesi, Sürüm Dağılımı,
kart başlıklarındaki gönderen adı) **ayrı bir dosyaya taşındı** (26 Ağustos
2026, doküman bütçesi: bu dosya 124 KB ile uyarı bandındaydı).

Kesme noktası içeriğin TÜRÜ: hepsi YALNIZCA admin hesabıyla ve çoğu zaman
canlı veriyle koşulan kontroller; buradaki geri kalan liste normal bir
kullanıcı hesabıyla koşuluyor. Hiçbir madde değişmedi, numaralar korundu.
Kararların kendisi (neden bu metrik, neden bu tanım) hâlâ
`docs/decisions/admin-panel.md`'de.



## 10. k-lig ödül & rütbe sistemi

Ödül/rütbe kayıtları sunucuda, `games` tablosuna satır ekleyen bir trigger'la
(`games_award_league_rewards`) açılır; kutlama banner'ının "bir kez göster"
garantisi `league_rewards.seen_at` ile cihazdan bağımsızdır. Bu zincirin
büyük kısmı otomatik test edilemiyor (gerçek oturum + gerçek oyun bitişi
gerekiyor).

- [ ] **Seviyeye göre puan — Kolay (6 Eylül 2026, ROADMAP #23 Faz 3).**
      Girişli hesapla Yapay Zeka sekmesi → "+ Yeni Yapay Zeka Oyunu Aç" →
      "Oyuncu sayısı"nın ALTINDA **Zorluk** satırı: `Kolay` · `Normal`,
      Normal seçili; `Zor` GÖRÜNMEMELİ (Faz 5'e kadar). Seçicinin altında
      seçili seviyenin açıklaması: Normal'de "Orta-iyi seviye bir
      oyuncuyum… birincilik 2 puan kazandırır.", Kolay'ı seçince "Çok iyi
      değilim… birincilik 1 puan kazandırır."; 4 Oyunculu'ya geçince cümleye
      ikincilik eklenir (Kolay: "ikincilik puan kazandırmaz", Normal:
      "birincilik 2, ikincilik 1 puan kazandırır"). Oyunu başlat, Setup'a
      dönüp "Devam Edenler"e bak: kartta avatarların hemen SAĞINDA küçük YEŞİL
      `Kolay` rozeti (Normal oyun kartında TURUNCU `Normal`; 6 Eylül gece
      kuralı: Kolay yeşil · Normal turuncu · Zor kırmızı, YZ oyununda her
      seviyede; Canlı kartında HİÇ rozet yok). Zorluk butonları Arkadaşınla
      sekmesinin Devam Edenler / Oyun Davetleri / Son Oynananlar pilleriyle
      AYNI boy ve puntoda (küçük), "Oyuncu sayısı"nın büyük butonu gibi
      DEĞİL. Oyun içinde tahtanın altındaki şeritte "Hamleler · Kolay"
      (Canlı oyunda burada "· Mesajlaşma" var, rozet yok). Oyunu birinci
      bitir: oyun sonu ekranında başlığın altında `Kolay` rozeti ve k-lig
      sütununda **+1** (Normal'de turuncu rozet, +2). "Son Oynadıklarım"da tarihin
      yanında rozet ve +1; "Tüm Oyunlarım"da "Yapay Zeka" rozetinin sağında
      `Kolay` ve +1; aynı kartı beğenip **Favoriler** sekmesinde de aç —
      orada da +1 (bu sekme ayrı bir RPC'den okuyor, `list_liked_games`).
      Skor Kartı/k-lig listesindeki toplam da +1 artmış olmalı (sunucu
      `league_points_for` ile aynı sayıyı verir — kart +1 gösterirken liste
      +2 artıyorsa iki kopya ayrışmış demektir). Oyun sonu "Tekrar Oyna" →
      yeni oyun da Kolay (devam eden kartında rozet). 4 kişilik Kolay oyunda
      ikinci bitir: **0** (Normal'de +1). Teslim/7 gün terk: her seviyede
      -2. Canlı oyun kartlarında rozet HİÇBİR koşulda çıkmaz.

- [ ] **k-lig'de OHP kolonu (12 Ağustos 2026).** Sıralamada "Puan"ın
      SOLUNDA bir OHP kolonu olmalı: rakamlar DÜZ GRİ ve kalın değil (Puan
      mavi/kalın kalır), biçim iki basamak ("12.78"), veri yoksa "—";
      rakamlar satırın kendi puntosundan (14px) küçük görünmeli.
      **Açıklama balonu:** başlıktaki "OHP"ye tıklayınca balon başlığın
      TAM ÜSTÜNDE, aşağı bakan bir kuyrukla açılmalı ("Ortalama Hamle
      Puanı tüm oyunlarda yapılan tüm hamlelerin ortalamasıdır."); tekrar
      tıklayınca VE ekranda başka bir yere dokununca kapanmalı. Metin
      BÜYÜK HARFE dönmemeli (başlık satırı `uppercase` taşıyor) ve
      modalın üst kenarında kırpılmamalı. Masaüstünde fareyle üzerine
      gelince açılıp çekilince kapanmalı — bu sırada tarayıcının kendi
      sarı `title` balonu ÇIKMAMALI (ikinci bir balon = regresyon).
      **En kritik kontrol:** bir oyuncunun k-lig satırındaki OHP,
      o oyuncunun kartındaki (Skor Kartı → "Genel" sekmesi) "Ortalama
      Hamle Puanı" ile BİREBİR aynı olmalı — ikisi aynı SQL ifadesinden
      geliyor, ayrışırlarsa biri bozulmuş demektir. Listede kendi satırın
      görünmeyecek kadar aşağıdaysan alttaki "senin sıran" kısayolunda da
      OHP dolu olmalı (boş/hizasız DEĞİL). Balon metninin sonunda artık
      "Puanlar eşitse OHP yüksek olan üstte sıralanır." cümlesi de olmalı
      (20 Ağustos 2026).
- [ ] **Yaş/cinsiyet satırı BAŞKASININ kartında (29 Ağustos 2026).**
      İki hesap gerekir (ya da profilinde doğum tarihi/cinsiyet girmiş
      mevcut bir üye). k-lig listesinde o kişinin satırına dokun: kartta
      ismin ALTINDA `Y:59/C:E` biçiminde satır olmalı — kendi Skor
      Kartı'ndaki satırla birebir aynı biçim (mono, gri, küçük).
      **Değişmez:** aynı kişi için kendi kartında gördüğü yaş ile
      başkasının onun kartında gördüğü yaş AYNI olmalı — biri istemcide
      (`calculateAge`), öteki sunucuda (`get_profile_age_gender`)
      hesaplanıyor. Doğum tarihi de cinsiyeti de girmemiş bir oyuncuda
      satır HİÇ çıkmamalı. **Misafirken de (çıkış yapıp) k-lig'den bir
      kart aç — satır yine görünmeli** (RPC `anon`a da açık). Ayrıca
      DevTools ağ sekmesinde `get_profile_age_gender` yanıtında ham
      `birth_date` OLMAMALI, yalnızca `age` sayısı dönmeli.
- [ ] **Sıra numarası liste ile Skor Kartı'nda AYNI (20 Ağustos 2026).**
      Bu, bildirilen hatanın kendisi: eşit puanlı oyuncular vardı ve aynı
      kişi listede 13., kendi kartında "#10" görünüyordu. Kontrol: k-lig
      listesinde **aynı puana sahip** iki oyuncu bul (bugün canlıda 2 puanlı
      dört kişi var), sıralarının OHP'ye göre ayrıştığını doğrula (yüksek
      OHP ÜSTTE), sonra alttakinin satırına dokunup kartını aç — başlıktaki
      "#sıra" listede gördüğün sayının AYNISI olmalı. Kendi hesabınla da
      yap: listede kaçıncıysan hesap menüsündeki/Skor Kartı'ndaki sayı o
      olmalı. **İkinci kontrol (sayfalama):** listeyi sonuna kadar kaydır —
      hiçbir oyuncu İKİ KEZ görünmemeli ve kimse atlanmamalı (eski sıralama
      eşitlikte kararsızdı, `.range()` ile sayfalanınca bu mümkündü).
      Açıklama satırında "Puanlar eşitse OHP yüksek olan üstte." yazmalı.
      Skor Kartı'ndaki metrik etiketi de "Ortalama Hamle Puanı (OHP)"
      olmalı — dar bir telefonda kutuyu taşırmadan sarmalı.
- [ ] **Kutlama banner'ı bir kez çıkar.** Görülmemiş bir ödülün varken
      (test için bir satırın `seen_at`'i SQL'le null'a çekilebilir) siteye
      gir: mühür damgalı, konfetili banner ekranın ORTASINDA, karartılmış
      arka planla çıkmalı. "Devam"dan sonra sayfa yenilense de, BAŞKA bir
      cihazdan girilse de bir daha çıkmamalı.
- [ ] **Banner oyun ortasında çıkmaz.** Devam eden bir YZ/Canlı oyunun
      ekranındayken banner asla belirmemeli; oyun bitince (ya da Setup'a
      dönünce) bekleyen kutlama kendiliğinden gösterilmeli.
- [ ] **Birleşik özet.** Aynı anda birden fazla görülmemiş kayıt varken
      (ör. geçmişe dönük backfill) TEK banner çıkmalı: rütbe varsa başlık
      rütbe, ödül puanı yeşil satırda toplam olarak.
- [ ] **Ödül toplama doğru.** 50 k-lig puanına İLK ulaşmada +5 eklenmeli
      (toplam 55 olur); puan -2 cezalarıyla eşiğin altına inse de verilmiş
      ödül GERİ ALINMAMALI. "Genel = 2 kişilik + 4 kişilik + ödül" toplamı
      tutmalı.
- [ ] **Mühür popup'ı.** Skor Kartı başlığı ile ✕ arasında ortalanmış büyük
      mühre (dış kenarı TIRTIKLI — noter mührü gibi) dokun: damga
      animasyonuyla bilgi popup'ı açılmalı (kademe adı +
      puan + "+N eşik ödülü dahil" + sıradaki rütbe hedefi + hedefe akan
      ilerleme çubuğu; en üst kademede çubuk yok). Çubuk etiketleri: sol
      eşiğin ödülü YEŞİL "(+5)✓" (alınmış), hedef eşiğin ödülü GRİ "(+10)"
      (henüz alınmamış) — yeşil+✓ yalnızca alınmış ödülde. Popup İSTENDİĞİ
      KADAR
      tekrar açılabilmeli (kutlamanın aksine "bir kez göster" kuralı yok).
      Başkasının kartında da (PlayerScoreCard) aynı mühür/popup çalışmalı.
- [ ] **Mühür artık İSİMLERİN yanında da — yedi yüzey (18 Ağustos 2026).**
      Hepsinde ismin SAĞINDA, isimle aynı dikey merkezde ve satırın
      puntosuna göre boyutlanmış olmalı: hesap (avatar) menüsünün başlığı
      (18px) · Skor Kartı'ndaki kendi ismin (20px) · başka bir oyuncunun
      kartı (20px) · Setup'ta 1. koltuktaki hesap adı (18px) · Arkadaşlar
      penceresinin ÜÇ sekmesi de (18px — "Arkadaşlarım", "İstekler",
      "Ara & Ekle") · "+ Yeni Canlı Oyun"daki arkadaş seçici (18px) · Oyun
      davetleri kartındaki katılımcı isimleri (16px). **Skor kartlarında
      artık İKİ mühür var** — başlıktaki 34px'lik tıklanabilir mühür VE
      ismin yanındaki 20px'lik; ikisi AYNI kademeyi göstermeli.
- [ ] **"Puan bilinmiyor" ile "0 puan" AYRI.** Hiç oyun bitirmemiş bir
      kullanıcının yanında **Çaylak (Ç)** mührü çıkmalı (o gerçekten 0
      puan — `leaderboard` view'ında satırı YOK, 0 sayılıyor). Ama liste
      ilk açılırken, puanlar gelmeden bir an için HERKESİN yanında Çaylak
      mührü BELİRMEMELİ. YZ koltuklarında ve misafirde mühür HİÇ olmamalı.
- [ ] **✕ var, "KAPAT"/"DEVAM" butonu YOK — popup'ta DA banner'da DA.**
      (12 Ağustos 2026, kullanıcı isteği; önce yalnızca popup'a
      uygulanmıştı, aynı gün kutlama/düşüş banner'ına da genişletildi.)
      Kapatma yalnızca sağ üstteki ✕ (ve Escape) ile; kartın altında tam
      genişlikte bir buton OLMAMALI. **KRİTİK — banner'da ✕ yalnızca
      kapatmıyor:** ödülleri "görüldü" işaretleyen tek yol o. Kapattıktan
      sonra sayfayı yenile: banner **BİR DAHA ÇIKMAMALI**. Çıkıyorsa ✕
      `mark_league_rewards_seen`'e bağlanmamış demektir (bilgi popup'ında
      tam tersi doğru: hiçbir şeye dokunmaz, istendiği kadar açılır).
- [ ] **Kart gölgesinde beyaz hale yok.** Hem bilgi popup'ının hem kutlama/
      düşüş banner'ının kartı karartılmış zeminde yalnızca yumuşak, koyu
      bir düşen gölge taşımalı — sol/üst kenarda beyaz bir parıltı (nömorfik
      `shadow-raised`) GÖRÜNMEMELİ. İkisi aynı kart, biri değişirse öteki de.
- [ ] **Rozet: dalgalı disk + iki kurdele kuyruğu (18 Ağustos 2026 — eski
      tırtıklı/noter mührü TAMAMEN bırakıldı, kullanıcı referans görsel
      verdi).** Her boyda AYNI siluet: dolu, dalgalı kenarlı bir disk +
      altında V kesikli iki kurdele; kurdele diskten bir tık KOYU.
      Testere dişli/ince tırtıklı eski mühür HİÇBİR yerde kalmamalı.
      Fark yalnızca iç halkada: 34/76px'lik rozetlerde harfin etrafında
      açık renkli ince bir halka VAR, 18px'lik k-lig satırlarında YOK
      (harf orada daha büyük). Banner'ın rakamlı glyph'lerinde ("+1000")
      halka HİÇBİR boyda çizilmez — rakamlar halkaya sığmıyor.
- [ ] **Harfin yazı tipi: yuvarlak hatlı (M PLUS Rounded 1c 800, 18 Ağustos
      2026 — öncesi Space Grotesk).** Harf basık ve yuvarlak köşeli
      görünmeli; kutu/tofu ya da düz bir yedek fonta düşmüş ince bir glyph
      GÖRÜNMEMELİ. En kolay kontrolü rakamlarda yapılır: banner'ın
      "+1000"/"10000" glyph'i madalyonun dışına TAŞMAMALI. (Font
      `font-display: swap` ile geliyor; ilk boyamada bir kare yedek fontla
      çizilmesi normal, kalıcı olması değil.)
- [ ] **Harf dikeyde ortalı — kuyruklu olanlar dahil.** Ç ve Ş (sedillalı)
      dairede M/O/U/D ile AYNI ölçüde ortalı durmalı; alta yakın/aşağı
      kaymış görünmemeli. Kolay kontrol: k-lig listesinde Çaylak ve
      Şampiyon satırlarını Oyuncu/Ustaca ile yan yana karşılaştır.
- [ ] **Dokuz kademe ve eşikleri.** Çaylak 0 (Ç) · Meraklı 50 (M) · Oyuncu
      100 (O) · Usta **250** (U) · Şampiyon 500 (Ş) · Destan 1000 (D) ·
      Efsane **2500** (E) · Uzaylı **5000** (Z) · Kozmik **10000** (K).
      Ödül her eşikte eşik/10 (+5/+10/+25/+50/+100/+250/+500/+1000).
      Usta 12 Ağustos 2026'da 200'den 250'ye çekildi — eski 200 eşiği
      HİÇBİR yerde görünmemeli. Uzaylı'nın harfi **Z** (Usta'nın U'suyla
      karışmasın); üç yeni renk çivit/camgöbeği/parlak altın.
- [ ] **"Nasıl oynanır?" ekranında rütbe bölümü (12 Ağustos 2026).**
      Detaylı Kurallar'ın sonunda, "Skor Kartı ve Puanlama"nın hemen
      altında **"Rütbeler ve Ödüller"** başlıklı bir bölüm olmalı: dokuz
      kademe alt alta, her satırda kademe renginde harf + ad + eşik +
      (Çaylak hariç) yeşil "(ödül +N)". Tablo `leagueRank.ts`'ten
      ÜRETİLİYOR, elle yazılmıyor — yani yukarıdaki maddede doğruladığın
      eşik/ödüllerle BİREBİR aynı olmalı; ayrışırsa biri elle yazılmış
      demektir. Aynı bölümde ödülün hayatta bir kez verildiği, rütbenin
      düşebileceği ve Kozmik'in en üst kademe olduğu yazmalı; "Skor Kartı
      ve Puanlama"nın sonunda da -2 cezasının üç kaynağı (Canlı 48 saat,
      yerel 7 gün) geçmeli. **Mobil portta da birebir aynı bölüm var**
      (`mobile/TESTING.md` bölüm 13) — iki ekran ayrışmamalı.
- [ ] **Ödül bir sonraki eşiği tetikleyebilir.** Ödül puanı toplamın
      İÇİNE sayıldığından, eşiğe çok yaklaşmış biri ödülü alınca aynı
      anda bir üst eşiği de geçebilir; iki banner değil TEK birleşik
      banner çıkmalı ve iki ödül de verilmiş olmalı.
- [ ] **Rütbe düşmeli.** -2 ceza alıp eşiğin altına inen bir hesabın mührü
      (k-lig listesi, Skor Kartı, PlayerScoreCard) bir alt kademeye İNMELİ —
      üç yer de aynı kademeyi göstermeli (hepsi güncel `total_score`'dan
      türetiliyor). Puan tekrar eşiği aşarsa damga geri gelir ama rütbe
      banner'ı İKİNCİ kez ÇIKMAMALI ve ödül İKİNCİ kez VERİLMEMELİ (her
      eşik hayatta bir kez).
- [ ] **Başlık emojileri (12 Ağustos 2026).** Rütbe yükselince 👏, 100'lük
      kilometre taşında 🎉, düşüşte 😔 — üçü de görünmeli. Kart HER
      varyantta 280px ve ✕ kartın İÇİNDE olmalı (mobil portta kutlama
      kartı içeriğe göre büzülüp ✕'i dışarı taşırıyordu; web'de kart
      zaten sabit genişlikte, orada aynı hata YOK).
- [ ] **Rütbe düşüş banner'ı.** Eşiğin altına inince konfetisiz, üzgün bir
      banner çıkmalı ("Rütben geriledi! 😔 … Kazandıkça geri yükselirsin!" —
      başlıktaki üzgün emoji görünmeli, boş kare DEĞİL) ve
      bir kez gösterilmeli; aynı eşikten İKİNCİ kez düşülürse yeniden
      çıkmalı (diğer banner'ların aksine tekrarlanabilir). Görülmemiş
      olumlu bir kutlama ile çakışırsa yalnızca olumlu olan gösterilmeli.
      Banner'da kaybedilen eşiğe geri dönüş çubuğu olmalı; hedef etiketi
      YALNIZCA SAYI ("50" — "puan" kelimesi YOK) ve altında yeşil "(+5)✓"
      (ödül + onay işareti =
      zaten alındı — kişi geri düşse bile yeşil ✓ kalır). Aynı kural bilgi
      popup'ında: düşmüş biri mühre dokununca hedef rozeti yeşil "(+N)✓"
      olmalı — hiç düşmemişte hedef GRİ "(+N)", ✓ yok.
- [ ] **k-lig sırası tutarlı.** Listedeki sıra/puan (leaderboard view) ile
      "senin sıran" satırı (my_leaderboard_rank RPC) aynı toplamı (ödül
      dahil) göstermeli.
- [ ] **OHP ↔ Puan hizası (14 Ağustos 2026).** k-lig tablosunda OHP sütunu
      Puan'a yakın durmalı (aralarında geniş bir boşluk kalmamalı) ve
      başlık satırı / liste satırları / "senin sıran" kısayolu ÜÇÜ DE aynı
      hizada olmalı — üçü ayrı kod yerinde çizildiğinden biri atlanmışsa
      sütunlar kayar. **"OHP" başlığı, altındaki rakamların TAM ÜSTÜNDE
      (ortalı) durmalı** — sağa kaymış görünmemeli. Mobil uygulamayla yan
      yana koy: iki platformda da aynı görünmeli.
      **Negatif eş:** 1 basamaklı bir ortalaması olan bir oyuncu varsa
      (`9.50` gibi) onun rakamları da 2 basamaklılarla ondalık noktasında
      hizalı kalmalı — değerler SAĞA yaslı, yalnızca başlık ortalı.

## 11. Karşılama katmanı (18 Ağustos 2026)

Otomatik testler (`npm run test`, `tests/smoke.spec.ts`, **18 test**) katmanın
tüm yollarını kapsıyor (kapı dalları + geçiş + öznitelikle bağlama + logo
park efekti + `<` düğmesiyle geri dönüş + hukuki pencereler + tahta
şeridi + `FAQPage` JSON-LD/`h1` tekilliği + oturum anahtarı varken katmanın
HİÇ görünmemesi) ve `.github/workflows/web-ci.yml`
ile her PR'da/`main`e push'ta otomatik koşuyor — burada YALNIZCA bu ortamdan
doğrulanamayan ya da gözle bakılması gereken maddeler var (bkz. `CLAUDE.md`
→ "Karşılama Katmanı").

- [ ] **Kurulu PWA doğrudan uygulamaya açılıyor — üç adım, sırayla.**
      Kapının bu dalı (`display-mode: standalone` / iOS
      `navigator.standalone`) yalnızca GERÇEK kurulu bir PWA'da tetiklenir;
      masaüstü Chromium'da CDP ile emüle edilemedi (kapı, `matchMedia`/
      `navigator.standalone`i sahteleyen bir init script'iyle doğrulandı —
      bkz. `CLAUDE.md`, "Doğrulama sınırı" — ama gerçek cihaz teyidi hiç
      yapılmadı).
      1. Ana ekrandaki kurulu PWA'yı aç → karşılama katmanı HİÇ
         görünmemeli, doğrudan Setup gelmeli.
      2. **Negatif eş — aynı cihazda:** tarayıcı sekmesinden (ana ekran
         ikonundan DEĞİL, temiz bir `localStorage`la) `kelimeki.com`a git →
         katman GÖRÜNMELİ. (1) ile aynı cihazda art arda denenirse
         `display-mode` sinyalinin gerçekten ayrımı yaptığı, tesadüf
         olmadığı kanıtlanmış olur.
      3. Setup'taki `<` düğmesine dokun → katman geri gelmeli;
         oradan "Hemen Oyna"ya bas → tekrar Setup'a dönmeli.

- [ ] **Başlık kilitli kalıyor + logo park efekti gerçek parmakla akıcı.**
      Katmanı gördüğün bir cihazda sayfayı yavaşça aşağı kaydır: GİRİŞ
      düğmesini taşıyan şerit ekranın EN ÜSTÜNDE sabit kalmalı (sayfa
      geri kalanı onun altından akmalı, `position: sticky`) — kaydırma
      boyunca hiç kaybolmamalı ya da titrememeli. Aynı kaydırmada kelimeki
      logosu şeridin altına girdiği anda şeridin ORTASINDA küçülmüş hâli
      belirmeli, yukarı dönünce kaybolmalı. Düğmeler bu sırada YERİNDEN
      OYNAMAMALI. Otomatik test sınıfın eklendiğini/kalktığını ve
      `opacity`yi ölçüyor ama gerçek dokunmatik kaydırmanın akıcılığını
      ölçemez.

- [ ] **Şeritte YALNIZCA GİRİŞ var, logo TAM ORTADA.** Başlıktaki OYNA
      düğmesi 18 Ağustos 2026'da kaldırıldı (kahramandaki "HEMEN OYNA"
      dururken ikincisi gereksizdi) — şeridin sağında GİRİŞ, ortasında
      (park ettiğinde) logo olmalı. Logonun yatay merkezi sayfanın gerçek
      ortasında durmalı, GİRİŞ'ten arta kalan alanın ortasında DEĞİL; park
      hâlindeki logo GİRİŞ ile aynı yükseklikte görünmeli.

- [ ] **Tanıtım tahtası GERÇEK oyunla birebir aynı görünüyor.** "Oyun tam
      olarak böyle görünüyor" bölümündeki tahtada KELİME/IRMAK/ZAMAN/
      BALKON/NEDEN/KOLAY gibi kelimeler okunabilmeli; iki bölgenin dış
      hattı, ortadaki altın X2 alanı ve tam merkezdeki turuncu X3 karesi
      görünmeli. Kelimelerin sözlükte olduğu `npm run verify-demo-board`
      ile ölçülüyor, ama tahtanın dar ekranda KIRPILMADIĞI gözle
      bakılmalı. İki tahtada da BAŞKA renkte, tek başına duran taşlar
      olmalı (izole hamleler) — o taşın ALTINDAKİ kare hâlâ bölge
      sahibinin tonunda görünmeli; taşın rengi bölgeyi ele geçirmiş gibi
      GÖRÜNMEMELİ.

- [ ] **Filigranlar VE harf puanları görünüyor, harfler oyundakiyle aynı
      boyda (18 Ağustos 2026'da üç turda düzeltildi — en sık tekrarlayan
      hata burası).** Gerçek bir oyun ekranıyla yan yana koy: (a) köşelerde
      büyük "1/2/3/4" oyuncu numarası filigranı, (b) merkezde büyük "X2"
      ve tam ortadaki hücrede "X3" etiketi, (c) HER taşın sağ üstünde
      küçük puan rakamı, (d) harf puntosu oyundakiyle AYNI — ne büyük ne
      küçük. Dördü de aynı `compact={false}` bayrağına bağlı ama (d) ayrıca
      tahtanın KABINA bağlı: kap gerçek oyunla aynı `max-w-[680px] px-3`
      olmazsa harf `vw` tabanlı `clamp()` yüzünden orantısız çıkar (bkz.
      `CLAUDE.md`, "AYNI GÜN İKİ KEZ YANLIŞ FONT"). Ekran görüntüsü alıp
      karşılaştırmak en hızlı yol.

- [ ] **Tahta GENİŞ ama METİN öteki bölümlerle hizalı (yatay tablet /
      geniş tarayıcı — mobilde görünmez).** Sayfayı 834px ve üstü bir
      genişlikte aç: tahta bilerek öteki bölümlerden GENİŞ (gerçek oyunla
      aynı kutu = aynı harf oranı, daraltma yasak), ama "TAHTAYA BİR BAK /
      Oyun tam olarak böyle görünüyor" başlığı ile tahta altı açıklamalar
      "Nasıl oynanır?" ve "Merak edilenler" başlıklarıyla AYNI sol kenardan
      başlamalı. 18 Ağustos 2026'da başlık 114px sola taşıyordu; ölçülen
      düzeltilmiş değerler 834'te 203, 1194'te 383 (üç bölüm de aynı).

- [ ] **Tahta altı açıklamalar ve renk legend'ı ORTALI.** İki tahtanın
      altındaki paragraflar sola yapışık DEĞİL ortalı olmalı; renk
      legend'ı geniş ekranda da ortalanmalı (sabit iki sütun değil, akan
      satır) ve dar ekranda kırılmadan sarmalı.

- [ ] **Sayfadaki tüm çağrı düğmeleri çalışıyor.** Kahraman "HEMEN OYNA"
      ve sayfa sonundaki "OYUNA BAŞLA" uygulamaya geçirmeli; şeritteki
      "GİRİŞ" giriş penceresini açmalı. **Sayfa sonunda ARTIK ikinci bir
      GİRİŞ düğmesi YOK** (18 Ağustos 2026, kullanıcı isteği) — orada
      yalnızca "OYUNA BAŞLA" olmalı. Yeni bir düğme eklendiyse
      `data-kelimeki-oyna` / `data-kelimeki-giris` özniteliğini
      taşıdığından emin ol — id ile eklenen bir düğme SESSİZCE ölü kalır.

- [ ] **SSS kutuları açılıp kapanıyor.** Native `<details>` kullanılıyor,
      JS yok; soruya dokununca cevap açılmalı.

- [ ] **Tahta şeridi PARMAKLA kayıyor.** "Oyun tam olarak böyle görünüyor"
      bölümündeki tahtayı sola çek → 4 kişilik tahta gelmeli, alttaki iki
      noktadan ikincisi maviye dönmeli; geri çekince ilki. Kaydırma CSS
      `scroll-snap` ile yapılıyor, yani her görsel TAM ortalanmış durmalı
      (yarım kalmamalı). Otomatik test `scrollLeft`i JS ile ayarlıyor —
      gerçek dokunmatik jestin akıcılığını ve snap'i ölçemez.

- [ ] **Kurulum ekranındaki `<` düğmesi geri döndürüyor — YALNIZCA
      GİRİŞSİZ (misafir) hesapta.** "Hemen Oyna" ile uygulamaya geç, sol
      üstteki `<` düğmesine dokun → karşılama katmanı geri gelmeli (sayfa
      yeniden yükleniyor, bu normal). Sonra tekrar "Hemen Oyna"ya bas ve
      SAYFAYI YENİLE → uygulamada kalmalısın, katman geri GELMEMELİ
      (`?tanitim=1` URL'den temizleniyor). **18 Ağustos 2026'da ikon →
      `← Tanıtım` metne, sonra AYNI GÜN çıplak `←`'ye, sonra AYNI GÜN
      girişli hesapta TAMAMEN GİZLENDİ, sonra AYNI GÜN büyütülüp `←`
      glyph'i düz `<`'ye çevrildi** (bkz. `CLAUDE.md`, "Setup'taki `<`
      düğmesi artık YALNIZCA girişsiz kullanıcıda görünüyor").
      **Girişli hesapla dene — düğme HİÇ GÖRÜNMEMELİ:** Setup ekranını
      girişli aç, sol üstte `<` OLMAMALI, sağda yalnızca avatar menüsü
      olmalı (satır ortalanmadan sağa yaslı kalmalı — kutunun tek çocuğu
      avatar). Girişsiz hesaba geç (Çıkış Yap) → aynı ekranda düğme GERİ
      GELMELİ.

- [ ] **Katmanın alt satırındaki hukuki bağlantılar.** "Kullanım Koşulları"
      ve "Gizlilik Politikası" → uygulamaya geçip DOĞRU pencereyi açmalı,
      pencere kapanınca URL'de `?kosullar=1`/`?gizlilik=1` KALMAMALI.

- [ ] **Setup footer'ında üçüncü madde: ikonlu "Paylaş" (18 Ağustos 2026).**
      Footer'ın hukuki linkler satırı artık "Kullanım Koşulları · Gizlilik
      Politikası · 🔗 Paylaş" — üçü de AYNI küçük metin-linki görünümünde
      (BÜYÜK/tam genişlikte bir buton DEĞİL — bir önceki denemede öyle
      yapılmıştı, kullanıcı "buton istemedim, tanıtım footerındakinin
      aynısını istedim" diyerek düzeltti), yalnızca "Paylaş"ın önünde küçük
      bir paylaşım ikonu var (kullanıcı: "İki tarafa da ikonlu şekilde koy").
      Hem GİRİŞSİZ hem GİRİŞLİ hesapta görünmeli (öncekinin aksine artık iki
      ayrı küçük metin linki YOK: misafirde logonun altındaki "Nasıl
      oynanır? · Arkadaşınla paylaş" satırından "Arkadaşınla paylaş" kalktı
      — yalnızca "Nasıl oynanır?" kaldı; girişlide footer'da AYRICA duran
      eski koşullu "· Paylaş" de tek, koşulsuz maddeye indirgendi). Dokununca
      native paylaşım sayfası açılmalı (mobil) ya da link panoya kopyalanıp
      buton metni 2 saniyeliğine "Link kopyalandı!" olmalı (masaüstü) —
      kopyalanan linkte `?ref=arkadas` OLMALI.
- [ ] **Karşılama katmanının (tanıtım/Landing) footer'ında AYNI ikonlu
      "Paylaş" (18 Ağustos 2026).** Katman görünürken (girişsiz, temiz
      `localStorage`) sayfayı en alta kaydır → footer "Kullanım Koşulları ·
      Gizlilik Politikası · 🔗 Paylaş" göstermeli, Setup'takiyle BİREBİR AYNI
      ikon/stil. Landing.tsx React state/olay handler'ı barındırmadığından
      (statik HTML) bu düğme `main.tsx`'teki `paylasiKur()` ile bağlanıyor —
      dokununca uygulamaya HİÇ GEÇMEMELİ (`?giris=1`/`?kosullar=1` gibi bir
      geçiş YOK), doğrudan katman modundayken native paylaşım/panoya
      kopyalama açılmalı; kopyalamada buton metni 2 saniyeliğine "Link
      kopyalandı!" olmalı ve ikon KAYBOLMAMALI (yalnızca metin span'i
      değişiyor).

## 12. Hoş geldiniz e-postası (21 Ağustos 2026)

Yeni üyeye tek seferlik karşılama maili. **Kayıt anında DEĞİL, e-posta
adresi DOĞRULANDIĞINDA** gönderilir — bu ayrım testin tamamını belirliyor.

- [ ] **Onay linkine tıklamadan mail GELMEMELİ.** Tek kullanımlık bir
      adresle kayıt ol, onay mailini AÇMA: hoş geldiniz maili gelmemeli.
      (Gelirse tetikleyici yanlış yere bağlanmış demektir.)
- [ ] **Onay linkine tıklayınca GELMELİ.** Aynı hesapta onayı tamamla →
      "Kelimeki — Hoş Geldiniz" konulu mail gelmeli.
- [ ] **Metin ve marka.** Logo + beyaz kart (diğer maillerle aynı), hitap
      baştan sona SİZ, "hoş geldiniz" AYRI yazılmış, "Görüş Bildir" adı
      geçiyor, tek düğme: **Hemen Oyna**.
- [ ] **Düğme çalışıyor** → kelimeki.com açılmalı.
- [ ] **İKİNCİ bir mail GELMEMELİ.** Aynı hesapla çıkış yapıp tekrar giriş
      yap, birkaç saat sonra tekrar kontrol et — karşılama maili hayatta
      bir kez gider.
- [ ] **Mevcut üyelere GİTMEMELİ.** Özellik canlıya çıktıktan sonra eski
      üyelerin hiçbiri karşılama maili almamalı (geriye dönük doldurma bunu
      garantiliyor; biri alırsa doldurma atlanmış demektir).
- [ ] **Admin panelinde iz.** Üyeler tablosunda yeni üyenin satırı normal
      görünmeli; hata olursa Supabase Edge Function loglarında
      `[notify-welcome]` satırlarına bak.
- [ ] **Bildirimleri kapatan almamalı** (uç durum): Hesap Ayarları'ndan
      "e-posta bildirimleri"ni kapatmış bir hesap yeni bir adresi
      doğrularsa mail gitmemeli.

## 13. Canlı liste — düşen istek (21 Ağustos 2026)

> Gerçek vaka: sırası KENDİSİNDE olan bir oyuncu "Devam eden bir Canlı
> oyunun yok." gördü. Ölçüt: **kullanıcı hiçbir zaman gerçek olmayan bir
> şey görmemeli ve iyileşmek için hiçbir şey yapmak zorunda kalmamalı.**

- [ ] **Ağ değişimi listeyi BOZMAMALI:** Canlı sekmesi açıkken WiFi'yi
      kapat (hücresel devrede kalsın). Liste ekranda KALMALI; "Devam eden
      bir Canlı oyunun yok." **ASLA** çıkmamalı.
- [ ] **Kısa kesinti uyarı ÜRETMEZ:** aynı geçiş sırasında "İnternet
      bağlantısı yok" çıkıp kaybolmamalı (1.5 sn'lik doğrulama penceresi).
- [ ] **Gerçek çevrimdışı HÂLÂ çıkar:** uçak modunu aç, birkaç saniye
      bekle → "İnternet bağlantısı yok". Kapat → uyarı kendiliğinden
      kalkmalı ve liste TAZELENMELİ (elle bir şey yapmadan).
- [ ] **"Yüklenemedi" ≠ "internet yok":** sunucu erişilemezken (ör. uçak
      modu değil, bağlantı var ama istek düşüyor) elde hiç liste yoksa
      *"Oyunların şu an yüklenemedi."* + **Tekrar Dene** çıkmalı — "internet
      yok" da "hiç oyunun yok" da ÇIKMAMALI.
- [ ] **Bayat liste notu:** liste bir kez yüklendikten sonra tazeleme
      düşerse liste EKRANDA KALIR ve üstünde küçük **GÜNCELLENEMEDİ** notu
      belirir; bağlantı dönünce not kendiliğinden kalkar.
- [ ] **Kendi kendine iyileşme:** kesinti sırasında ekranı AÇIK bırak,
      hiçbir şeye dokunma; bağlantı dönünce liste **kendiliğinden** gelmeli
      (en geç ~30 sn). Sekme değiştirmek/uygulamayı kapatıp açmak GEREKMEZ.
- [ ] **Girişte doğru sekme:** sırası kendisinde olan bir oyunu varken,
      açılışta ağ bir an kesilse bile "Arkadaşınla" sekmesi açılmalı (düşen
      yükleme bu kararı bir daha TÜKETMEMELİ).

## 14. Oyundan Setup'a dönüş — "← Geri" (21 Ağustos 2026)

- [ ] **Görünür:** Oyun ekranında logonun hemen altında ince, koyu bir
      "← Geri" yazıyor ve tahtanın sol kenarıyla hizalı duruyor.
- [ ] **Dokunuş:** Hem etikete hem logoya dokunmak Setup'a döndürüyor.
- [ ] **Header bozulmadı:** Skor kutuları logoyla aynı hizada; tahta
      eskisine göre gözle görülür şekilde aşağı kaymadı.
- [ ] **4 kişilik + girişli hesap:** Avatar/GİRİŞ ile etiket çakışmıyor,
      skor kutuları kırpılmıyor (dar telefonda da).
- [ ] **Canlı oyunda da var:** Aynı etiket Canlı oyun ekranında da
      görünüyor ve oradan Canlı listesine döndürüyor.

## 15. Giriş varsayılanı — hangi sekme açılıyor (21 Ağustos 2026)

- [ ] **YZ boş + Canlı oyun var:** Devam eden YZ oyunu OLMAYAN, ama devam
      eden Canlı oyunu OLAN bir hesapla gir → "Arkadaşınla" açık gelmeli,
      sıra kendisinde olmasa bile.
- [ ] **YZ oyunu varsa kaçırılmaz:** Devam eden bir YZ oyunu VARKEN ve
      Canlı'da bekleyen iş YOKKEN gir → "Yapay Zeka ile" açık gelmeli.
- [ ] **Bekleyen iş her şeyin önünde:** Sırası kendisinde bir Canlı oyun ya
      da bekleyen davet varsa, YZ oyunu olsa bile "Arkadaşınla" açılmalı.
- [ ] **Elle seçim ezilmiyor:** Açılıştan sonra elle "Yapay Zeka ile"ye geç,
      birkaç dakika bekle (Realtime/öne dönüş tazelemeleri) → sekme
      kendiliğinden Canlı'ya ATLAMAMALI.
- [ ] **Ağ kesintisi kararı yakmıyor:** Uçak modunda aç, sonra bağlantıyı
      geri ver → doğru sekme yine de açılmalı (karar düşen istekte
      tüketilmez).

## 16. Joker düzenleme — GERÇEK dokunmatik cihazda (22 Ağustos 2026)

Bir kullanıcı (Android) tahtaya koyduğu jokere tekrar dokunduğunda pencerenin
açılmadığını ve harfin kendiliğinden değiştiğini bildirdi (A → C). Kök sebep
dokunmatik tarayıcıların `pointerup`tan SONRA ürettiği uyumluluk (compat)
click'iydi; ayrıntı ve ölçümler `CLAUDE.md` → "Joker (`?`)". Otomatik
regresyon `tests/smoke.spec.ts`te var (emüle dokunmatik) — burası **gerçek
cihaz** teyidi, çünkü compat olay sırası tarayıcı/cihaz farkı taşıyor.

Her satırı **hem Android Chrome hem iOS Safari** ile, hem de **hem yerel (YZ)
hem Canlı** oyun ekranında koş — ikisi bu deseni paylaşıyor.

- [ ] **Tahtanın ÜST satırlarındaki joker:** Jokeri koy, harfini seç, sonra
      taşa bir kez dokun → "Jokeri Hangi Harfe Çevir?" penceresi AÇIK
      KALMALI (açılıp anında kapanmamalı).
- [ ] **Tahtanın ALT satırlarındaki joker (asıl vaka):** Aynısını tahtanın
      alt üçte birindeki bir hücrede yap → harf KENDİLİĞİNDEN değişmemeli.
- [ ] **Gerçek seçim çalışıyor:** Açılan pencereden yeni bir harf seç →
      taş o harfe dönmeli, pencere kapanmalı (hayalet click yutulurken
      gerçek dokunuş yutulmamalı).
- [ ] **"Geri Al" çalışıyor:** Aynı pencereden "Geri Al" → taş rafa dönmeli.
- [ ] **Sıradan taş değişmedi:** Joker OLMAYAN, bu turda konmuş bir taşa
      dokun → doğrudan rafa geri alınmalı (pencere açılmamalı).
- [ ] **Sürükleyerek koyma:** Raftaki jokeri sürükleyip bir hücreye bırak →
      harf seçme penceresi açılmalı ve açık kalmalı.
- [ ] **Titreşimli dokunuş kaybolmuyor (22 Ağustos 2026):** Parmağını hafifçe
      kaydırarak (tam sabit tutmadan) raftaki bir taşa dokun → seçilmeli;
      tahtaya koyduğun bir taşa aynı şekilde dokun → rafa geri alınmalı.
      Eşik parmakta 10px (farede 6) — eskiden 6px'lik titreşim jesti sessizce
      yutuyordu.
- [ ] **Gerçek sürükleme bozulmadı:** Raftaki taşı tahtaya sürükleyip bırak,
      tahtadaki taşı başka bir hücreye taşı, tahtadaki taşı rafa sürükle.
- [ ] **k-lig balonu (OHP) kapanışı:** k-lig listesini aç, "OHP" başlığına
      dokunup balonu aç, sonra bir OYUNCU SATIRINA dokun → balon kapanmalı ve
      o oyuncunun kartı AÇILMAMALI. İkinci dokunuş kartı açmalı.
- [ ] **Hesap menüsü kapanışı (oyun ekranında):** Oyun sırasında sağ üstteki
      avatara dokunup menüyü aç, sonra TAHTAYA dokun → menü kapanmalı ve
      tahtaya taş KONMAMALI/hücre seçilmemeli. İkinci dokunuş normal çalışmalı.

## 17. Hukuki statik sayfalar — YALNIZCA CANLIDA ölçülebilir (23 Ağustos 2026)

`/gizlilik/`, `/kullanim-kosullari/` ve `/hesap-silme/` derleme zamanında
üretilen statik sayfalar (kök `CLAUDE.md` → "Hukuki Statik Sayfalar").
Otomatik duman testleri sayfaların doğru üretildiğini, SPA kabuğuna
düşmediğini ve metnin pencerelerle aynı kaynaktan geldiğini zaten kanıtlıyor
— **bu listedeki maddeler otomatikleştirilemeyenler:** ikisi de Vercel'in
kendi yönlendirme sırasına bağlı ve bu ortamdan test EDİLEMİYOR.

Deploy sonrası, Play formuna adres girmeden ÖNCE:

- [ ] `https://kelimeki.com/gizlilik/` → politika açılıyor (uygulama değil).
- [ ] `https://kelimeki.com/kullanim-kosullari/` ve `.../hesap-silme/` aynı.
- [ ] **Eğik çizgisiz** `https://kelimeki.com/gizlilik` → `/gizlilik/`'e
      yönleniyor (`vercel.json` `redirects`). Yönlenmiyor ve uygulama
      açılıyorsa **Play formuna eğik çizgili adresi yaz** — ölçülmüş ve
      çalıştığı bilinen hâl o; yönlendirme bir kolaylık, bağımlılık değil.
- [ ] **Kurulu PWA'da (ana ekrana eklenmiş) dene.** Service worker'ın
      `navigateFallback`i bu yolları uygulama kabuğuna çeviriyordu;
      `navigateFallbackDenylist` eklendi ama gerçek kurulu bir PWA'da teyit
      cihazda yapılmalı. Uygulamayı bir kez aç (yeni SW etkinleşsin), sonra
      tarayıcıdan adrese git.
- [ ] Sayfalar JS kapalıyken de okunabiliyor (tamamen statik olmalı).
- [ ] `/hesap-silme/` içindeki "Görüş Bildir formu" bağlantısı formu açıyor.

---

## 18. Onaylanmamış hesap süpürmesi — hatırlat, sonra sil (23 Ağustos 2026)

Saatlik cron (`sweep-unconfirmed-accounts`, `25 * * * *`) e-postasını hiç
doğrulamamış hesapları ~20. saatte TAZE bir onay linkiyle hatırlatıyor, 48.
saatte siliyor. **Otomatik silme geri alınamaz** — bu bölüm bu yüzden var;
maddeler otomatik testle kapatılamıyor, çünkü gerçek bir gelen kutusu ve
gerçek bir Supabase Auth hesabı gerekiyor.

**Test hesabı kullan, kendi hesabınla koşma.** Tek kullanımlık bir adres
(`…@sharedxpteam.testinator.email`) yeterli.

### 18.1 Hatırlatma maili — tek tık, direkt içeri

- [ ] Test adresiyle kayıt ol, gelen onay mailine **DOKUNMA**.
- [ ] Damgayı geriye çek (SQL): kaydı ~21 saatlik göster
      (`update auth.users set created_at = now() - interval '21 hours' where email = '…'`).
- [ ] Cron'u bekleme, fonksiyonu elle tetikle (Edge Function → Invoke, gövde `{}`).
- [ ] Gelen kutusunda **Kelimeki markalı** "Hesabını tamamla" maili var
      (Supabase'in stok İngilizce şablonu DEĞİL).
- [ ] Metin 24 saat içinde tamamlanmazsa hesabın silineceğini SÖYLÜYOR.
- [ ] **"Hesabımı Tamamla"ya tek dokunuş → doğrudan uygulamanın içindesin.**
      Ara bir sayfa, "linki yeniden gönder" adımı, ikinci bir mail YOK.
- [ ] SQL'de `email_confirmed_at` ile `last_sign_in_at` **aynı ana** yazılmış
      (tek tıkla hem onay hem oturum).

### 18.2 Mükerrer hatırlatma gitmiyor

- [ ] Fonksiyonu ikinci kez tetikle → aynı kişiye ikinci mail **GİTMEZ**
      (`confirm_reminder_sent_at` dolu, atomik iddia).

### 18.3 Silme — üç koşul birden

Bir hesap ancak şunların HEPSİ doğruyken siliniyor: onaysız · hatırlatma
gönderilmiş · hatırlatmadan bu yana 24 saat geçmiş. **Uyarılmadan kimse
silinmez.**

- [ ] Hatırlatma damgası taze bir hesapta prova (`{"dryRun":true}`) çıktısında
      `silinecek` listesi **BOŞ**.
- [ ] Damgayı 25 saat geriye çek → prova artık o hesabı `silinecek` diyor.
- [ ] Gerçek koşudan sonra `auth.users`ta satır yok, admin Üyeler sayısı 1 azaldı.
- [ ] **Takma ad serbest kaldı:** aynı takma adla yeniden kayıt olunabiliyor.
- [ ] **E-posta serbest kaldı:** aynı adresle yeniden kayıt olunabiliyor.

### 18.4 Verisi olan hesap SİLİNMEZ

- [ ] Prova çıktısındaki `verisiOlduguIcinAtlanan` listesini oku. Kendi
      oluşturduğu kaydı (oyun, bulut kaydı, gönderdiği arkadaşlık isteği) olan
      hesap silinmez, yalnızca raporlanır.
- [ ] **Bir hesabın GELEN referansı silmeyi engellemez** — biri ona arkadaşlık
      isteği göndermişse o satır cascade ile gider (`cascadeOlacakGelenKayit`
      alanında raporlanıyor). Bunu "veri var" sanıp korkma.

### 18.5 ⚠ OTP süresi — geri çekilirse özellik SESSİZCE ölür

- [ ] Supabase Dashboard → Authentication → Sign In / Providers → Email →
      **Email OTP expiration = 86400** (24 saat). 3600'e dönmüşse hatırlatma
      maili ölü link taşır ve kimse fark etmez.
- [ ] Güvenlik denetiminde (`get_advisors`) `auth_otp_long_expiry` **WARN**
      görünüyor — bu BİLİNÇLİ, temizlemek için ayarı düşürme.

### 18.6 Hukuki metin ile davranış uyuşuyor

- [ ] Gizlilik Politikası (web modal + `/gizlilik/` sayfası + mobil port) 5.
      bölümde ~20 saat hatırlatma / 48 saat silme cümlesini taşıyor ve üç
      yüzeyde de aynı.
- [ ] **6. bölüm anonim kodun DÖRT durumunu sayıyor** (31 Ağustos 2026'da
      dördüncüsü eklendi: YZ oyununu BİTİRME, yalnızca girişsizken). Üç
      yüzeyde de aynı ve "Son güncelleme" tarihi ÜÇÜNDE de **31 Ağustos
      2026** olmalı — portun tarihi web'inkinden geri kalırsa
      `legal_text_test.dart` zaten düşer, ama statik sayfa derlemeden
      geliyor: `/gizlilik/` sayfasını da elle aç ve tarihi gör.
- [ ] **Girişliyken bitirdiğin bir YZ oyununda anonim kod GİTMEMELİ.** Metin
      bunu açıkça söylüyor ("Girişliyken … anonim kod ORAYA HİÇ YAZILMAZ").
      Sunucu iki katmanda zorluyor (trigger + CHECK), yani bu kontrol
      metnin doğruluğunu değil, davranışın metinle uyuştuğunu sınıyor:
      girişli bir oyunu bitir → `game_finishes` satırında `user_id` dolu,
      `anon_id` NULL olmalı.

## 19. Alt şerit dokunma hedefleri (24 Ağustos 2026)

Bir kullanıcı cihazda bildirdi: *"board altındaki hamleler, mesajlar ve nasıl
oynanır linkleri tıklayınca hemen açılmıyorlar. Kaç defa basmam gerekti."*
Hedefler 18 → 32 px'e çıkarıldı (dolgu KAPTAN her ÖĞEYE taşındı; şeridin dış
ölçüsü değişmedi). Ayrıntı/ölçümler: `docs/decisions/touch-ux-bugs.md` →
"Alt şerit dokunma hedefleri". `layout_parity_test.dart` düzeni kilitliyor
ama **gerçek parmakla ıskalamayı hiçbir test ölçemez** — burası o teyit.

**GERÇEK dokunmatik cihazda**, hem yerel (YZ) hem Canlı oyun ekranında koş.

- [ ] **Hamleler:** Tahtanın altındaki "Hamleler"e BİR kez dokun → hamle
      penceresi ilk dokunuşta açılmalı.
- [ ] **Mesajlaşma (yalnızca Canlı):** "Mesajlaşma"ya bir kez dokun →
      sohbet ilk dokunuşta açılmalı.
- [ ] **Nasıl Oynanır?:** Şeridin sağındaki linke bir kez dokun → kurallar
      ilk dokunuşta açılmalı.
- [ ] **Etiketin ÜSTÜNE/ALTINA dokunma da çalışıyor:** Yazının tam üstüne
      değil, hemen üstündeki/altındaki birkaç piksele dokun → yine açılmalı
      (hedef artık yazının kendisinden yüksek).
- [ ] **Şerit büyümedi:** Tahta kartının alt kenarı ile raf arasındaki
      boşluk gözle ESKİSİYLE aynı görünmeli — bu düzeltme şeridi
      büyütmemeliydi.
- [ ] **Okunmamış mesaj rozeti yerinde:** Okunmamış mesajı olan bir Canlı
      oyunda kırmızı sayı rozeti "Mesajlaşma" etiketinin sağ ÜST köşesinde
      durmalı, aşağı kaymamalı.
- [ ] **Çevrimdışı göstergesi:** Uçak modunu aç → "Çevrimdışı" şeridin
      sağında görünmeli ve "Nasıl Oynanır?" ile ÇAKIŞMAMALI (dar telefonda
      alt satıra sarabilir, bu beklenen).
## 19b. Dokunma hedefleri 48 px — İKİNCİ tur (24 Ağustos 2026)

Bölüm 19'daki düzeltme yetmedi (ölçüm: 31 px, asgari 48). Web tarafında da
aynı kusur vardı; `Board.tsx`, `HelpModal.tsx`, `Setup.tsx` ve
`UserMenu.tsx` `min-h-[48px]` aldı. Avatarda negatif marj kullanıldığından
**webde düzen bir piksel bile oynamamalı** — bu bölümün asıl amacı onu
doğrulamak.

- [ ] **Header aynı yükseklikte:** Oyun ekranında logo, skor kutuları ve
      avatar eskisiyle AYNI hizada; header büyümemiş görünüyor.
- [ ] **Avatar** tıklanınca menü açılıyor; avatarın etrafındaki 8 px'lik
      görünmez alan da tıklanabiliyor (hemen kenarına tıkla).
- [ ] **Alt şerit** üç linki de tek tıkta açılıyor; şerit biraz daha uzun
      görünecek (beklenen).
- [ ] **"Nasıl Oynanır?" penceresi:** "Detaylı Kurallar →" linki tıkla
      geçiyor; link ile başlık arası makul, üst üste binmiyor.
- [ ] **Setup'ın alt linkleri** (Kullanım Koşulları · Gizlilik Politikası ·
      Paylaş) tıklanıyor ve aradaki `·` ayraçlar dikeyde ORTALI.
- [ ] **"Yükleniyor…" okunur:** k-lig ve Skor Kartı açılırken ortada
      belirgin mavi/kalın bir "Yükleniyor…" görünüyor (soluk gri değil).

## 19c. Modaller tek boyda açılıyor mu (24 Ağustos 2026)

Mobil portta bildirilen "önce küçük pencere, sonra büyük pencere"
davranışının webdeki eşi de düzeltildi: yükleme sırasında yer baştan
ayrılıyor.

- [ ] **k-lig** açılınca pencere tek boyda açılmalı; içerik alanının
      ortasında "Yükleniyor…" görünmeli ve veri gelince pencere BÜYÜMEMELİ.
- [ ] **Skor Kartı** açılınca istatistik kutuları `—` ile baştan çizili
      olmalı; sayılar yerinde dolmalı.
- [ ] Oyun geçmişi / arkadaşlar gibi öteki pencerelerde de "Yükleniyor…"
      belirgin (mavi/kalın) görünmeli.

## 19d. Taslak sürerken kelime anlamı açılmamalı (24 Ağustos 2026)

Mobil portta bildirilen davranışın webdeki eşi de değişti.

- [ ] Tahtaya bir taş koy (OYNA'ya BASMA) → oynanmış bir taşa tıkla →
      anlam penceresi AÇILMAMALI, imleç de "tıklanır" göstermemeli.
- [ ] Taslağı geri al → oynanmış taşa tıkla → anlam penceresi AÇILMALI.
- [ ] Aynı ikisini Canlı oyun ekranında da dene.

### Iskalama kurtarma (mobil tarayıcıda dene — asıl hedef orası)

- [ ] Taslak taşını geri almak için **kasten biraz aşağısına** (altındaki
      oynanmış taşa) dokun → taslak taşı GERİ ALINMALI.
- [ ] **Yan yana üç taslak harf**, ortadakine dokun → yalnızca ortadaki.
- [ ] **Mevcut bir taşın hem üstüne hem altına** harf koy, ortadaki
      oynanmış taşa tam ortasından dokun → hiçbir şey olmamalı; biraz
      yukarı/aşağı kayarsan yakın olan geri alınmalı.
- [ ] Boş hücrelere taş koymak eskisi gibi kolay olmalı.

## 20. Bölge kuralı — bloktaki desteksiz rakip taşı (24 Ağustos 2026)

Kural değişti: kendi 4×4 köşe bloğunun içindeki bir hücre, üzerinde rakip taşı
olsa bile, o taş **rakibin kendi zincirine bağlı değilse** senin zincirini
kesmez (iletken). Gerekçe ve ölçümler: `CLAUDE.md` → "İstisna — kendi 4×4 köşe
bloğu". `territory.json` golden vector'ı iki motoru da kilitliyor, ama **canlı
bir oyunda gözle teyit** ayrı bir şey — bölge dış hattı ve vergi onayı bu
hesaba bağlı.

- [ ] **İletken durum:** Rakip senin bloğunun içine, kendi bölgesine BAĞLI
      OLMAYAN bir taş koysun. O taşa asarak blok dışına bir kelime kur →
      bölgenin dış hattı yeni taşlarını içine alacak şekilde büyümeli.
- [ ] **Negatif dal:** Rakip kendi bölgesini kesintisiz kendi taşlarıyla senin
      bloğuna kadar getirmişse, onun taşına asarak kurduğun kelime bölgene
      dahil OLMAMALI (ve o hücreler onun bölgesinde görünmeli).
- [ ] **Vergi tutarlı:** Yukarıdaki iletken durumda büyüyen bölgenin sınırına
      rakip oynadığında "Sınır İhlali!" onayı çıkmalı ve vergi sana gelmeli.
- [ ] **Çakışma yok:** Hiçbir hücre aynı anda iki oyuncunun renkli dış hattı
      içinde görünmemeli.
- [ ] **Devam eden oyunlar:** Deploy sonrası açık bir oyunda bölge sınırları
      yeniden hesaplanır — tahtanın dış hattı bir anda değişebilir, bu
      beklenen.

## 21. Davet sayfası (`/davet/:token`) — zenginleştirilmiş ekran (25 Ağustos 2026)

Sayfa artık davet cümlesinin yanında oyunu da ANLATIYOR (davet edenin baş harf
avatarı, tek bir "Daveti Kabul Et" düğmesi, gerçek tanıtım tahtası + X2/X3
rozetleri, dört özellik kutusu, hukuki alt şerit). Gerekçe:
`docs/decisions/friends.md`. Duman testi yalnızca "bölüm render oluyor mu"yu
kilitliyor (`tests/smoke.spec.ts`); aşağıdakiler GERÇEK bir token + gerçek bir
kayıt gerektirdiğinden elle koşulur.

- [ ] **Girişsiz, geçerli link.** Arkadaşlar → "Arkadaşını Davet Et" ile link
      üret, **gizli sekmede** aç: davet edenin adı başlıkta görünmeli, avatar o
      adın baş harflerini taşımalı. Kartta düğmenin ALTINDA hiçbir açıklama
      metni OLMAMALI (25 Ağustos 2026'da bilerek kaldırıldı).
- [ ] **Kayıt akışı bozulmadı.** "Daveti Kabul Et" (üstteki VEYA sayfanın
      altındaki aynı etiketli düğme) → AuthModal **kayıt** modunda açılmalı;
      kayıt + e-posta onayı sonrası uygulamaya dönüldüğünde arkadaşlık KURULMUŞ
      olmalı (token kuyruğu, `App.tsx`).
- [ ] **Zaten üye olan da tek düğmeden geçebiliyor.** Aynı düğme →
      AuthModal'daki "Zaten hesabın var mı? Giriş yap" ile giriş → davet
      otomatik işlenmeli ("artık arkadaşsınız").
- [ ] **Girişli kullanıcı tanıtımı GÖRMEZ.** Aynı linki girişli bir hesapla aç:
      yalnızca davet kartı + "İşleniyor…" → "artık arkadaşsınız" görünmeli,
      "Kelimeki nedir?" bölümü HİÇ çıkmamalı.
- [ ] **Geçersiz/kullanılmış token çıkmaz değil.** Uydurma bir token ile aç:
      açıklama + "Kelimeki'ye Git" düğmesi ve altında tanıtım bölümü olmalı.
- [ ] **KENDİ davet linkine tıkla** (25 Ağustos 2026'da kullanıcı bunu bildirdi;
      o gün arayüz *"bir hata oluştu, lütfen tekrar dene"* + **Tekrar Dene**
      gösteriyordu — tekrar denemek hiçbir zaman çalışmayacaktı). Girişliyken
      kendi linkini aç: sunucunun kendi cümlesi görünmeli — **"Kendi linkinle
      arkadaş olamazsın."** — ve düğme **"Kelimeki'ye Git"** olmalı,
      "Tekrar Dene" ÇIKMAMALI. Kural: sunucu `raise exception` ile reddettiyse
      (SQLSTATE `P0001`) mesajı OLDUĞU GİBİ göster, tekrar denemeyi önerme;
      "Tekrar Dene" yalnızca kodsuz (ağ/beklenmeyen) hatalarda çıkar.
- [ ] **Tahta gerçek tahtaymış gibi görünüyor.** Bölge dış hatları, ev
      işaretleri, sarı X2 alanı ve turuncu X3 hücresi seçilebilmeli; altındaki
      iki rozetin rengi tahtadaki karelerle AYNI olmalı (zeminler
      `Board.tsx`'ten geliyor — ayrışmışsa biri elle yazılmış demektir).
- [ ] **Dar ekran.** 320 px genişlikte yatay kaydırma OLMAMALI, düğmeler tek
      satırda kalmalı.
- [ ] **Hukuki şerit.** "Kullanım Koşulları" / "Gizlilik Politikası" pencereleri
      açılıp Esc ile kapanmalı (sayfa uygulama paketinde, statik `/gizlilik/`
      sayfasına GİTMEZ).

## 22. Uygulama içinden hesap silme (25 Ağustos 2026, ROADMAP madde 2)

**GERİ DÖNÜŞSÜZ.** Bu bölümü YALNIZCA feda edilebilir bir test hesabıyla
koş — `Ironman` ve App access formunda incelemeciye verilen `T2` HARİÇ
(ROADMAP #4). Karar/kaskad: `docs/decisions/account-deletion.md`.

Duman testi yalnızca `/hesap-silme/` sayfasının metnini kilitliyor; aşağısı
gerçek bir oturum ve gerçek veri gerektirdiğinden elle koşulur.

- [ ] **Giriş görünür.** Hesap menüsü → Hesap Ayarları → en altta, KAYDET'in
      altındaki ayracın arkasında kırmızı **"Hesabımı Sil"** ve altında
      "Kalıcıdır, geri alınamaz." olmalı.
- [ ] **Kuru çalıştırma GERÇEK sayı gösteriyor.** Pencere açılınca
      "Silinecekler" listesi belirmeli ve sayılar hesabın gerçek verisiyle
      uyuşmalı (ör. oyun geçmişindeki kayıt sayısı ile "Bitmiş oyun kaydın").
      Sıfır olan satırlar HİÇ görünmemeli.
- [ ] **"Kalacaklar" bölümü.** Birlikte oynadığın biri varsa, o kişinin
      kaç bitmiş oyun kaydının KORUNACAĞI ve adının "Silinmiş oyuncu"
      olacağı yazmalı. Hiç ortak oyunu olmayan bir hesapta bu bölüm
      çıkmamalı.
- [ ] **Onay olmadan silinmiyor.** `SİL` yazmadan buton devre dışı olmalı;
      `sil` (küçük harf) de kabul edilmeli (`trUpper`), `SIL` (noktasız I)
      de — ama `SL`/boş kabul EDİLMEMELİ.
- [ ] **Silme sonrası.** Onaydan sonra sayfa `/`'e dönmeli, oturum kapanmış
      olmalı ve aynı e-posta/takma adla **yeniden kayıt** olunabilmeli
      (takma ad serbest kalmış olmalı).
- [ ] **Rakibin kaydı KORUNDU ve ANONİMLEŞTİ.** Silinen kişiyle oynamış
      BAŞKA bir hesapla gir: Oyun Geçmişi'ndeki o oyun hâlâ listede olmalı,
      puanlar DEĞİŞMEMELİ, ama oyuncu adı **"Silinmiş oyuncu"** olmalı.
      Sohbet arşivi (balon ikonu) açıldığında o kişinin mesajları da aynı
      adla görünmeli.
- [ ] **k-lig bozulmadı.** Aynı hesabın Skor Kartı'ndaki toplam puanı silme
      ÖNCESİYLE aynı olmalı (`games` oyuncu başına satır tutuyor; kimsenin
      puanı silinen kişiden gelmiyor).
- [ ] **Devam eden Canlı oyun.** Silinen kişiyle YARIM kalmış bir oyun varsa
      rakibin "Canlı" listesinden düşmüş olmalı (oynanamaz bir oyun ortada
      asılı kalmamalı).
- [ ] **Yönetici silinemiyor.** Admin bir hesapla pencereyi aç: kuru
      çalıştırma **"Yönetici hesabı uygulama içinden silinemez."** demeli ve
      silme butonu HİÇ etkinleşmemeli.
- [ ] **`/hesap-silme/` sayfası tutarlı.** Sayfanın 1. bölümü uygulama içi
      yolu anlatmalı (eski "kendi kendine hesap silme özelliği şu anda
      bulunmuyor" cümlesi KALMAMALI) ve 2. bölümdeki "Görüş Bildir"
      bağlantısı hâlâ çalışmalı — Play bu URL'i Data safety formundan
      açıyor.

---

## 23. `destek@` gönderen ayrımı + "Zoho" rozeti (25 Ağustos 2026)

Kod canlıda ama zincirin yarısı Brevo/Zoho/GoDaddy panellerinde. Kurulum
adımları ve sırası: `docs/decisions/support-email.md` → "Kurulum". Bu liste
o adımlar bittikten SONRA koşulur.

**Otomatik test YOK ve olamaz:** gerçek bir Brevo hesabı, gerçek bir MX
kaydı ve gerçek bir gelen kutusu gerekiyor.

### 23.1 Transactional mail gerçekten cevaplanamıyor mu

1. Kendine bir bildirim mailini tetikle (en kolayı: yeni bir hesap açıp
   doğrula → "Hoş Geldiniz" maili).
2. Gelen mailin **altında** şu not olmalı: *"Bu otomatik bir bildirimdir; bu
   adrese gönderilen yanıtlar okunmaz. Bize ulaşmak için destek@kelimeki.com"*
   — `destek@` tıklanabilir bir `mailto:` linki olmalı.
3. Gönderen `Kelimeki <noreply@kelimeki.com>` olmalı (ham başlıktan oku —
   Gmail → "Orijinali göster"; Apple Mail kişi kartındaki adı gösterip
   yanıltır, bkz. `console-formlari.md`'deki ölçüm tuzağı).
4. **Bu maile "Yanıtla" de ve gönder.** Beklenen: mail GERİ DÖNER (bounce).
   ⚠ Geri dönmüyor ve `destek@` kutusuna düşüyorsa, Zoho'daki `noreply@`
   GRUBU hâlâ silinmemiş demektir (kurulum adım 2).

### 23.2 Görüş bildirim yanıtı destek@'ten gidiyor mu

1. Uygulamadan (misafir ya da üye) bir görüş bildir, e-posta alanını doldur.
2. Admin panel → Geri Bildirim → Gelen Kutusu → mesajı aç → **Yanıtla** → gönder.
3. ⚠ **502 + "destek@kelimeki.com Brevo'da doğrulanmış gönderen değil"**
   hatası alırsan bu bir kod hatası DEĞİL: kurulum adım 1 yapılmamış.
   Brevo → Settings → Senders'a adresi ekle, doğrula, tekrar dene.
4. Gelen mailde gönderen `Kelimeki Destek <destek@kelimeki.com>` olmalı ve
   notta *"Bu e-postayı doğrudan yanıtlayabilirsin"* yazmalı.
5. **Maile doğrudan "Yanıtla" de.** Cevap `destek@` Zoho kutusuna düşmeli.

### 23.3 Rozet — cevap gelince admin haber alıyor mu

⛔ **BU BÖLÜM ŞU AN KOŞULAMAZ (26 Ağustos 2026).** Rozeti besleyen gelen
zinciri kurulmadı: Brevo'nun **Inbound webhook**'u ücretli plana bağlı ve
plan yükseltilmedi (gerekçe: `docs/decisions/support-email.md` → "GELEN
ZİNCİRİ DURDURULDU"). `support_inbox` boş kalır, rozet hiç belirmez —
**bu bir hata değil, beklenen hâl.** Panel içindeki "Zoho" düğmesi yine de
çalışır (kutuyu açan kısayol). Zincir bir gün kurulursa aşağıdaki adımlar
olduğu gibi geçerli.



1. 23.2'nin 5. adımından sonra Zoho kutusunu kontrol et: mail **kutuda
   kalmalı** (yönlendirme bir KOPYA olmalı, taşıma değil).
2. Admin paneli → Geri Bildirim sekmesi. Alt sekme satırında **Zoho** düğmesi
   ve üstünde kırmızı **1** rozeti görünmeli.
   ⚠ Rozet gelmiyorsa sırayla bak: Zoho filtresi çalıştı mı → Brevo Inbound
   "logs" ekranı maili gördü mü → Supabase Edge Function logları
   (`inbound-email`) ne diyor. 401 = webhook URL'indeki `?key=` yanlış,
   503 = `INBOUND_EMAIL_SECRET` secret'ı eklenmemiş.
3. **Zoho düğmesine tıkla.** Beklenen: yeni sekmede Zoho gelen kutusu açılır
   (`mail.zoho.eu`) VE rozet anında kaybolur.
4. Paneli yenile — rozet geri gelmemeli (`seen_at` damgalandı).
5. İkinci bir cevap gönder → rozet tekrar **1** olmalı.

- [ ] **Dıştaki "Admin Paneli" rozeti de arttı mı.** Paneli AÇMADAN, hesap
      menüsünü aç: "Admin Paneli" satırının yanındaki kırmızı sayı bu cevabı
      da içermeli (`fetchAdminPendingCount` üç kaynağı toplar). İlk sürümde
      yalnızca panelin İÇİNDEKİ rozet sayıyordu — dışarıdaki saymayınca
      bildirim işe yaramıyor.

### 23.4 Admin'in üyeye yazdığı mesaj

1. Admin panel → Üyeler → bir üyenin satırında **Mesaj Gönder** → konu+mesaj.
2. Mail `destek@`'ten gitmeli; Geri Bildirim sekmesinde "Gönderilen" rozetiyle
   görünmeli.
3. Üye "Yanıtla" derse: cevap Zoho'ya + rozet artmalı (23.3 ile aynı).
4. Üye maildeki **"siteden de yazabilirsin"** linkine tıklayıp formu
   doldurursa: cevap ZOHO'ya DEĞİL, doğrudan admin paneline düşmeli ve
   "↳ Cevaben" rozetiyle orijinal mesaja bağlanmalı. (İki yolun farklı yere
   gitmesi bilinçli — bkz. karar kaydı.)

### 23.5 Gürültü elenmesi

- `destek@`'e bir "tatil/otomatik yanıt" maili düşerse rozet ARTMAMALI
  (`Auto-Submitted`/`X-Autoreply`/`Precedence: bulk` eleniyor).
- `destek@` ya da `noreply@` adresinden gelen kopyalar da elenmelidir
  (döngü koruması).


## 24. Tarayıcı yazı boyutu ayarı — hiçbir sütun bölünmüyor (2 Eylül 2026)

Mobil portta 1 Eylül 2026'da bulunan hata sınıfının web eşleniği (kullanıcı:
*"fontlarını büyüten kişilerde bitirme modalı puanları bölüyor… Her koşulda
modallar, butonlar, vb genel olarak hiç bir şey patlamamalı"*).

⚠ **Tarayıcı ZOOM'u bu hatayı ÜRETMEZ** — zoom kutuları da büyütür. Doğru
ayar **asgari yazı boyutu**: Chrome → Ayarlar → Görünüm → *Yazı tipi boyutunu
özelleştir* → **Minimum yazı tipi boyutu = 16** (Safari: Tercihler →
Gelişmiş → "Yazı tipi boyutu asla şundan küçük olmasın"). Yalnızca eşiğin
altındaki puntoları yukarı çeker, px genişlikli kutular yerinde kalır.

Bitirme modalı **otomatik ölçülüyor** (`npm run test` →
`tests/text-scale.spec.ts`, `--blink-settings=minimumFontSize=16`); aşağıdaki
üçü ise gerçek bir Supabase oturumu gerektirdiğinden ELLE:

- [ ] **Skor Kartı → k-lig lider tablosu** → `Sıra`/`OHP`/`Puan` sütunları
      tek satır; sayılar rakam rakam bölünmemeli, komşusunun üstüne
      binmemeli.
- [ ] **Tüm Oyunlarım → bir oyun kartı** → `Puan` ve `k-lig` başlıkları ve
      altlarındaki sayılar tek satır.
- [ ] **Nasıl Oynanır → Rütbeler ve Ödüller** → rütbe harfi tek satır.
- [ ] Ayarı normale al → üç yüzeyde de görünüm ESKİSİYLE AYNI olmalı
      (sütun genişlikleri ve aralıklar değişmemeli).
- [ ] **LİSTE SIRALAMASI** (3 Eylül 2026): (a) Yapay Zeka "DEVAM EDEN
      OYUNLAR" → silinmeye en yakın kayıt EN ÜSTTE; (b) Canlı "Devam
      Edenler" → sırası SENDE olanlar üstte ve KENDİ İÇİNDE en yakın teslim
      en üstte; (c) "Oyun Davetleri" → süresi bitmeye en yakın davet en
      üstte. ⚠ Sırası RAKİPTE olan oyunlarda yön TERSİ ve bu bilinçli:
      orada "son oynanan üstte" (31 Ağustos kararı) — o grubu en-yakın-bitiş
      sanıp hata bildirme.
- [ ] **Son Oynananlar / Son Oynadıklarım → AVATARLAR** (2 Eylül 2026'da
      eklendi; öncesinde bu listede hiç fotoğraf çıkmıyordu): bitmiş bir
      Canlı oyunda rakiplerin fotoğrafı görünmeli; Yapay Zeka sekmesinde
      kendi fotoğrafın görünmeli. ⚠ Fotoğrafı olmayan üye ve YZ/misafir
      koltukları baş harf/robot/"?" olarak KALIR — eksik değil, kural.
      ⚠ Oyundan SONRA takma adını değiştiren biri baş harfe düşer (bilinçli:
      yanlış yüz göstermektense baş harf).
- [ ] **Setup → devam eden oyun kartı** → `SIRA SENDE` oyuncu satırının
      sağında, kalan süre altta tam genişlik satırda (2 Eylül 2026'da
      portla birlikte değişti). Avatarların altında `Sıra: X` YAZMAMALI.
- [ ] **İki sekmeyi yan yana karşılaştır** ("Yapay Zeka" ↔ "Arkadaşınla"):
      Canlı oyun kartında da kalan süre **puan satırının ALTINDAKİ**
      kendi satırında olmalı, o satıra binmemeli (2 Eylül 2026'da bu iki
      kart AYRIŞMIŞTI). `SIRA SENDE`/`SIRA RAKİPTE` puntosu 15 px — iki
      kartta da aynı.
- [ ] **Kart altı PUAN SATIRI** (6 Eylül 2026, kullanıcı isteği): iki
      sekmedeki devam eden oyun kartlarında avatarların hemen altında
      koltuk sırasıyla anlık puanlar (`45 - 38`; 4 kişilikte dört sayı) —
      N'inci sayı N'inci yüzün altında, punto/harf aralığı kalan-süre
      satırıyla AYNI (8 px mono). ⚠ Canlı kartında **"X açtı" satırı
      ARTIK YOK** (kurucu zaten ilk avatar). Rakip hamle yapınca puanlar
      oyuna girmeden tazelenmeli (Realtime → liste yeniden çekilir).
      "Son Oynananlar"da (iki sekme): **tarih (+ zorluk rozeti) avatarların
      ÜSTÜNDE**, bitiş puanları altında — snapshot sırasıyla; sağdaki kendi
      puanın/k-lig sütunları yerinde. Port ile birebir.
- [ ] **Board altındaki şerit** (Hamleler · Mesajlaşma · **Yardım**) →
      punto 11 ve TEK SATIR; portla AYNI olmak zorunda. Etiket 2 Eylül
      2026'da `Nasıl Oynanır?`dan kısaltıldı (şerit tavanda iki satıra
      düşüyordu).

**Neden ikisi farklı düzeltildi:** bitirme modalı ızgaraya çevrildi (sütunlar
`auto`, yani genişliğini içeriğinden alıyor — elle yazılmış 29/37/20 px'in
türetildiği kuralın kendisi; normal ölçekte AYNI sayıları verdiği ölçüldü).
Ötekilerde `w-*` → `min-w-* whitespace-nowrap` yapıldı: normal ölçekte
kanıtlanabilir biçimde etkisiz (kutular zaten içerikten geniş), büyüyünce
kutu içeriğe göre açılıyor. Izgaraya çevirmek oralarda görünümü kaydırırdı,
çünkü o genişlikler içeriğe tıpatıp oturmuyor (ör. `k-lig` için `w-8`).

## 25. Sunucu-otoriter hamle — gölge fazı (5 Eylül 2026, ROADMAP #18)

**Neden elle:** `submit_move` artık her hamleyi kendi motoruyla da hesaplayıp
istemcinin gönderdiğiyle karşılaştırıyor. Bu fazda karar DEĞİŞMİYOR (hâlâ
istemcinin değeri kullanılıyor), yalnızca sapma `move_shadow_diffs` tablosuna
yazılıyor. Amaç: zorlama fazına geçmeden önce aynanın sahada gerçekten
istemciyle aynı sonucu verdiğini ölçmek. **Tablo boş kalmazsa zorlamaya
GEÇİLMEZ.**

Otomatik kanıt zaten var (2.641 gerçek hamle yeniden oynatıldı, 0
açıklanamayan sapma) ama o kanıt yalnızca GERÇEKLEŞMİŞ yolları kapsıyor.
Aşağıdaki dördü mevcut veride az geçtiği için elle koşulmalı.

Her turdan sonra kontrol (Supabase → SQL Editor):
```sql
select alan, count(*), max(created_at)
from public.move_shadow_diffs group by alan order by 2 desc;
```
Beklenen: **sıfır satır.** Satır varsa `girdi` sütununda board + placed +
players duruyor, vaka birebir tekrar üretilebilir.

- [ ] **25.1 — Normal Canlı oyun (2 kişilik).** Birkaç hamle oyna: kelime
      kur, çapraz kelime oluştur, pas geç, taş değiştir. Sorgu boş kalmalı.
- [ ] **25.2 — 4 kişilik oyunda bölge etkileşimi.** Rakibin bölgesine gir
      ve/veya sınırına değ; vergi onay modalı çıksın, hamleyi onayla.
      Ekranda görünen vergi ile skorlara yansıyan pay tutmalı; sorgu boş
      kalmalı. **En riskli yol burası** — bölge hesabı maliyetin %56'sı ve
      SQL aynasının en karmaşık parçası.
- [ ] **25.3 — İletken hücre kuralı (24 Ağustos 2026).** Rakip senin 4×4
      köşe bloğuna kendi zincirine BAĞLI OLMAYAN bir taş koysun; sen o taşın
      ötesine oynayıp bölgeni büyüt. Bölge dış hattı büyümeli ve sorgu boş
      kalmalı. (Bu dal golden vector'lara ilk girdiğinde SIFIR kapsama
      vermişti — otomatik kanıtın en zayıf olduğu yer.)
- [ ] **25.4 — Joker bitiş bonusu.** Torba boşken rafını YALNIZCA jokerle
      bitir (1 joker +25, 2 joker +50). Bonus skora yansımalı, sorgu boş
      kalmalı.
- [ ] **25.5 — Oyun ortasında teslim (48 saat zaman aşımı).** Teslim olan
      oyuncunun bölgesi doğal alana dönmeli; sonraki hamlelerde ona vergi
      ödenmemeli. Sorgu boş kalmalı.
- [ ] **25.6 — Eski istemci.** Mağazadan/Appetize'dan ESKİ bir sürümle bir
      hamle oyna. RPC imzası değişmediği için çalışmalı ve sapma yazmamalı —
      bu, "kurulu sürümler kırılmıyor" iddiasının sahadaki kanıtı.

⚠ **Hız kontrolü:** hamle gönderimi gözle fark edilir şekilde yavaşlamamalı.
Ölçülen ek maliyet +7,5-8,6 ms (ağ gidiş-dönüşünün %5'inden az); hissedilir
bir yavaşlama varsa sebep başka yerdedir, önce `move_shadow_diffs`in
'hata' satırlarına bak.
