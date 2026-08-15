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
      ve "N gün M saat sonra iptal edilecek" satırı olmalı (süre + sonunda ne
      olacağı — 5 Ağustos 2026'da "Bugün iptal edilir" gibi yanlış/süresiz
      ifadelerden bu kalıba geçildi).
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
- [ ] **Kalan süre yalnızca sende.** "Devam Edenler" listesinde "N saat sonra
      teslim sayılacak" **yalnızca sırası sende olan** satırlarda görünmeli.
      "Rakibin hamlesi bekleniyor" satırında görünmemeli — o süre rakibe ait.
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
      girmek gerekmemeli). Popup çıkmamalı, yalnız okunmamış kırmızı nokta.
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
      kırmızı nokta belirmeli. Sohbeti açınca nokta sıfırlanmalı.
- [ ] **Geç giriş.** Uygulama kapalıyken mesaj gelsin; tekrar girince kırmızı
      nokta çıkmalı. Hiç yeni mesaj yokken **çıkmamalı** (ilk sürümde yanlış
      pozitif veriyordu).
- [ ] **Sessize alma.** Sohbet başlığındaki dişli → kişi → "Kişiyi Sessize Al"
      → onay. Artık o kişiden **popup ÇIKMAMALI**, ama **kırmızı nokta
      ÇIKMALI** (15 Ağustos 2026 kararı: mute yalnızca popup'ı bastırır) ve
      mesajları sohbette görünmeye devam etmeli. İsminin yanında 🚫 çıkmalı.
      Aynı oyunda susturulMAMIŞ başka biri yazarsa hem nokta hem popup
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
- [ ] **Sayı değil, nokta olması gerekenler.** Board footer'ındaki
      "Mesajlaşma" (okunmamış mesaj) ve `UserMenu` avatarı — bunlar
      boolean gösterge, sayı taşımaz, bu doğru davranış.
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
      Skor kartında (k-lig → bir satır) arkadaş durumu **yeşil kişi-onay**
      — listedeki kırmızı adam- DEĞİL (bilinçli), dokununca yine çıkarma
      onayı açmalı.
- [ ] **Kişiye tıklamak skor kartını açar — ÜÇ sekmede de (11 Ağustos
      2026).** "Arkadaşlarım", "İstekler" ve "Ara & Ekle" (arama + Tüm
      Üyeler) satırlarında **avatara/isme** tıkla → o kişinin skor kartı
      açılmalı. Aksiyon ikonu bundan ayrışık: ikona tıklamak kartı DEĞİL
      onay diyaloğunu açmalı. Kartın kendi arkadaşlık simgesinden bir işlem
      yapıp (ör. çıkar) kartı kapatınca satırdaki ikon ANINDA yeni duruma
      dönmeli.
- [ ] **Dokunmatikte yapışkan hover (11 Ağustos 2026).** Telefon/tablette
      Setup'ın altındaki "Kullanım Koşulları"na dokun, modalı kapat: linkin
      altında **kalıcı bir çizgi kalmamalı**. Aynısı "Nasıl oynanır?",
      "Arkadaşınla paylaş" ve menü satırları için de geçerli. Masaüstünde
      fareyle üzerine gelince alt çizgi HÂLÂ çıkmalı (o davranış korunuyor).
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
- [ ] **"Son Oynadıklarım" (Setup) — İKİ dalı da, BU SIRAYLA.** Koşul
      (`setGames(cur => (!failed || cur === null ? rows : cur))`) iki dallı,
      ve yalnızca ikincisini test etmek yarım kalır:
      1. **Önce önbelleksiz:** o oturumda "Son Oynananlar"a HİÇ girmeden
         çevrimdışı ol ve gir → **"yüklenemedi"** çıkmalı (`cur === null`).
      2. **Sonra önbellekli:** çevrimiçi ol, sekmeye gir (liste dolsun),
         tekrar çevrimdışı ol ve gir → **ESKİ liste kalmalı**, hata mesajı
         DEĞİL (`cur !== null` — başarısız çekim ekrandaki listeyi ezmiyor).
      (14 Ağustos 2026'da kullanıcı tam bu sırayla koştu; ilk yazdığım
      sıralama yalnızca 2. dalı kapsıyordu.)
- [ ] **NEGATİF EŞİ ŞART.** ÇevrimİÇİ, gerçekten hiç oyunu olmayan bir
      hesapla aynı ekranları aç: orada NORMAL boş mesajlar çıkmalı. Bu
      olmadan yukarıdaki üç madde hiçbir şey kanıtlamaz — "her durumda
      yüklenemedi yazan" bir hata da onları geçerdi.

## 9.7. Admin — Aktif Oyuncu / Aktivasyon / Retention (14 Ağustos 2026)

Üç panel Büyüme > Kullanıcı'ya eklendi. Üç RPC de canlıda gerçek admin
JWT'siyle koşuldu (yetki matrisi dahil); aşağıdakiler yalnızca gerçek
tarayıcıda görülebilecek olanlar. **Admin hesabı gerekiyor.**

- [ ] **Üçü de yükleniyor.** Admin Paneli → Büyüme → Kullanıcı: "Yeni Üye /
      Ziyaret"in altında sırasıyla **Aktif Oyuncu** grafiği, **Aktivasyon**
      (4 kutu), **Retention** tablosu görünmeli. Hiçbiri "Yükleniyor…"da
      asılı kalmamalı.
- [ ] **Aktif Oyuncu grafiği iki seri gösteriyor** ("Aktif Oyuncu (28 gün)"
      mavi, "Dönem İçi Aktif" amber) ve legend'dan tek tek açılıp
      kapanabiliyor. Altındaki açıklama satırı "…bu sayı bilerek MAU değil"
      cümlesini içermeli — tanımın ekranda olması bilinçli.
- [ ] **Periyot/granülerlik kontrolü grafiği GERÇEKTEN değiştiriyor.**
      Üstteki periyot kombosunu değiştir: Aktif Oyuncu grafiği de yeniden
      çekilmeli (Yeni Üye/Ziyaret ile aynı kontrolleri paylaşıyor).
      **Aktivasyon ve Retention DEĞİŞMEMELİ** — ikisi bilerek periyoda bağlı
      değil (kohortun ekseni kayıt haftası, aktivasyon tüm zamanların oranı).
- [ ] **Retention tablosu üçgen görünmeli.** En yeni kohort ÜSTTE; sağ üst
      köşe boş (penceresi tamamlanmamış haftalar hiç çizilmiyor). Bir hücrenin
      üstüne gel → "3/10 üye aktif" gibi bir ipucu çıkmalı.
- [ ] **Hücre yazısı HER tonda okunabilir olmalı** — en koyu hücrede bile
      (%100'e yakın oran) rakam net görünmeli. Ton yalnızca ikincil işaret;
      oran zaten sayıyla yazıyor.
- [ ] **CSV'ler ham sayı veriyor.** Retention'da "CSV İndir" → dosyada yüzde
      DEĞİL aktif üye SAYILARI ve bir "Üye" (payda) sütunu olmalı.
- [ ] **NEGATİF EŞİ ŞART — admin olmayan hesap.** Sıradan bir hesapla giriş
      yap: "Admin Paneli" menü satırı HİÇ görünmemeli. (RPC'ler sunucuda
      ayrıca `Yetkisiz erişim.` fırlatıyor, ama UI'ın da sızdırmadığı
      görülmeli.)

> **Sayıları okurken:** 23 hesabın 4'ü test hesabı ve 325 oyunun 27'si
> onlara ait — bunları eleyen bir bayrak YOK (kullanıcı kararı: test verisi
> sonradan silinecek). Bu ölçekte kohort eğrileri gürültüdür; buradaki amaç
> enstrümantasyonun ÇALIŞTIĞINI doğrulamak, eğrileri yorumlamak değil.

## 9.8. Admin — Platform dökümü (14 Ağustos 2026)

Girişli bir kullanıcının oyunu APP'ten mi WEB'den mi oynadığını ölçen yeni
kolon. Sunucu tarafı canlıda rollback'li senaryolarla doğrulandı (iki kaynak,
yetki matrisi, geçersiz değer); aşağıdakiler yalnızca gerçek istemcide
görülebilecek olanlar.

- [ ] **Tablo yükleniyor.** Admin Paneli → Büyüme → Kullanıcı: "Cihaz"ın
      hemen altında **Platform** tablosu (Platform / Oyun / Oyuncu / %).
      Altındaki açıklama satırı "Cihaz"dan farkını anlatmalı.
- [ ] **Web'den oynanan yeni bir oyun `Web` satırına düşüyor.** kelimeki.com'da
      girişliyken bir YZ oyunu BİTİR (yarıda bırakma — satır ancak oyun
      bitince yazılıyor), sonra paneli aç: `Web` satırının "Oyun" sayısı 1
      artmalı. Toplam da artmalı, `Bilinmiyor` DEĞİŞMEMELİ.
- [ ] **Uygulamadan oynanan oyun `iOS`/`Android` satırına düşüyor.** Aynı
      şeyi mobil uygulamada yap (GitHub Pages web derlemesinde `App (Tarayıcı)`
      satırına düşer — o da doğru davranış, uygulamanın tarayıcıdaki hâli).
- [ ] **Canlı oyun da sayılıyor.** İki hesapla bir Canlı oyunu SONUNA kadar
      bitir; her katılımcı KENDİ oynadığı istemcinin satırına düşmeli (biri
      web'den biri app'ten oynadıysa iki farklı satır).
- [ ] **"Bilinmiyor" satırı GİZLENMEMELİ.** Kolon 14 Ağustos 2026'da eklendi;
      öncesinde biten ~300 oyun orada toplanıyor. Satırı görmüyorsan tablo
      yanlış filtreliyor demektir — yüzdeler de yalancı olur.
- [ ] **CSV İndir** çalışmalı; dosyada Platform/Oyun/Oyuncu/% sütunları ve bir
      TOPLAM satırı olmalı.
- [ ] **Gizlilik metni güncel.** Gizlilik Politikası → "Toplanan Veriler"de
      "Bir oyunu hangi istemciden oynadığınız…" maddesi olmalı, "Son
      güncelleme: 14 Ağustos 2026" yazmalı (mobil uygulamadaki metin de AYNI).

## 10. k-lig ödül & rütbe sistemi

Ödül/rütbe kayıtları sunucuda, `games` tablosuna satır ekleyen bir trigger'la
(`games_award_league_rewards`) açılır; kutlama banner'ının "bir kez göster"
garantisi `league_rewards.seen_at` ile cihazdan bağımsızdır. Bu zincirin
büyük kısmı otomatik test edilemiyor (gerçek oturum + gerçek oyun bitişi
gerekiyor).

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
      OHP dolu olmalı (boş/hizasız DEĞİL).
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
- [ ] **Küçük rozetler de tırtıklı.** k-lig listesi/Skor Kartı satırlarındaki
      18-20px'lik mühürlerin dış kenarı da testere dişli olmalı (büyük
      mühürle aynı siluet, 24 diş) — düz çember GÖRÜNMEMELİ. Dişler
      telefonda net ayrışmalı, harf (özellikle Ç/Ş sedillası) tırtığa
      DEĞMEMELİ. Fark: küçük mühürde iç kesikli halka yok, harf daha büyük.
- [ ] **Harf dikeyde ortalı — kuyruklu olanlar dahil.** Ç ve Ş (sedillalı)
      dairede M/O/U/D ile AYNI ölçüde ortalı durmalı; alta yakın/aşağı
      kaymış görünmemeli. Kolay kontrol: k-lig listesinde Çaylak ve
      Şampiyon satırlarını Oyuncu/Ustaca ile yan yana karşılaştır.
- [ ] **Dokuz kademe ve eşikleri.** Çaylak 0 (Ç) · Meraklı 50 (M) · Oyuncu
      100 (O) · Usta **250** (U) · Şampiyon 500 (Ş) · Destan 1000 (D) ·
      Efsane **2500** (E) · Uzaylı **5000** (Z) · Tanrı **10000** (T).
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
      düşebileceği ve Tanrı'nın en üst kademe olduğu yazmalı; "Skor Kartı
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
