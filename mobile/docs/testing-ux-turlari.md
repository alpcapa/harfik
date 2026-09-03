# Cihaz Testi — Etkileşim ve Görünüm Turları (tarihli)

> **`mobile/TESTING.md`'nin ikinci yarısı.** 3 Eylül 2026'da dosya 121 KB'a
> çıkıp uyarı bandına girdiği için bölündü (kök `CLAUDE.md` → "Doküman
> Boyutu Bütçesi" kuralı: uyarı bandındaki dosyayı bir sonraki dokunuşunda
> böl). **Hiçbir satır değiştirilmedi, yalnızca taşındı** — bölüm
> numaraları da olduğu gibi korundu.
>
> **Kesme noktası boyut değil İÇERİĞİN TÜRÜ:** `mobile/TESTING.md` her
> sürüm önce baştan koşulan ÖZELLİK kontrol listesi (oyun · hesap · bulut
> kayıtları · geçmiş · paylaşma · dayanıklılık · k-lig · telemetri);
> burası ise belirli bir Parça'da yapılmış bir ETKİLEŞİM/GÖRÜNÜM
> düzeltmesinin gerilemediğini doğrulayan tarihli turlar (dokunma
> hedefleri · sürükleme eşiği · yazı boyutu · akıcılık · zoom).
> Dosyanın bölüm numaralarının 14'ten yeniden başlaması bu ayrımın
> zaten var olduğunun kanıtıydı: birinci yarıda da 14-18 vardı.
>
> ⚠ **Bu liste OPSİYONEL DEĞİL, seyrek.** Özellik listesi her sürümde
> koşulur; buradaki turlar ilgili alana dokunan bir PR'da koşulur (hangi
> alan olduğu her bölümün başlığındaki Parça numarasından okunur).
>
> **Kardeş dosyalar:** `mobile/TESTING.md` (özellik listesi) ·
> `testing-arkadaslar-canli.md` (iki oturum isteyenler) ·
> `testing-bildirimler.md` (push + derin bağlantı + güncelleme) ·
> `testing-gorsel-karsilastirma.md` (web ile yan yana) ·
> `test-ortamlari.md` (nereden/nasıl koşulur)

## 14. Sürükleme eşiği — titreşimli dokunuş (22 Ağustos 2026, Parça 129)

Eşik pointer türüne bağlandı (fare 6, parmak 10 logical px); öncesinde tek
sayı 6'ydı ve hafif titreyen bir dokunuş sessizce hiçbir şey yapmıyordu.
Web tarafında ölçüldü, portta ölçüm KOŞULAMADI (Flutter SDK yok) — gerçek
cihazda teyit gerekiyor. Hem yerel (YZ) hem Canlı oyun ekranında koş.

- [ ] **Titreşimli dokunuş işliyor:** Parmağını tam sabit tutmadan raftaki
      bir taşa dokun → seçilmeli.
- [ ] **Konmuş taş geri alınıyor:** Tahtaya koyduğun bir taşa aynı şekilde
      (hafif kayarak) dokun → rafa dönmeli.
- [ ] **Joker seçici açılıyor:** Konmuş bir jokere hafif kayarak dokun →
      harf seçici açılmalı.
- [ ] **Gerçek sürükleme bozulmadı:** Raftan tahtaya sürükle, tahtada taşı
      başka hücreye taşı, tahtadan rafa sürükleyerek geri al.
- [ ] **Kaydırma çakışmıyor:** Tahtayı/sayfayı parmakla kaydırmaya çalış →
      taş sürüklenmeye başlamamalı.

## 15. Alt şerit dokunma hedefleri (24 Ağustos 2026, Parça 132)

Kullanıcı cihazda bildirdi: *"board altındaki hamleler, mesajlar ve nasıl
oynanır linkleri tıklayınca hemen açılmıyorlar. Kaç defa basmam gerekti."*
Dolgu KAPTAN her ÖĞEYE taşındı; hedefler 18 → 32 px, şeridin dış ölçüsü
(32) DEĞİŞMEDİ. Web tarafında ölçüldü, portta ölçüm KOŞULAMADI (Flutter SDK
yok) — gerçek cihazda teyit gerekiyor. Hem yerel (YZ) hem Canlı oyun
ekranında koş.

- [ ] **Hamleler ilk dokunuşta açılıyor** (üst üste basmak gerekmemeli).
- [ ] **Mesajlaşma ilk dokunuşta açılıyor** (yalnızca Canlı oyunda).
- [ ] **Nasıl Oynanır? ilk dokunuşta açılıyor.**
- [ ] **Yazının hemen üstü/altı da çalışıyor:** Etiketin tam üstüne değil,
      birkaç piksel yukarısına/aşağısına dokun → yine açılmalı.
- [ ] **Şerit büyümedi:** Tahta kartının alt kenarı ile raf arasındaki
      boşluk gözle ESKİSİYLE aynı olmalı.
- [ ] **Okunmamış rozeti kaymadı:** Okunmamış mesajı olan Canlı bir oyunda
      kırmızı sayı "Mesajlaşma"nın sağ ÜST köşesinde durmalı.
- [ ] **Çevrimdışı göstergesi:** Uçak modunda "Çevrimdışı" görünmeli ve
      "Nasıl Oynanır?" ile çakışmamalı.

## 16b. Dokunma hedefleri — ÜÇÜNCÜ tur: ✕ ve raf taşı (27 Ağustos 2026, Parça 147)

Kullanıcı: *"bazı tıklamalar yine biraz üstte gibi. Mesela skor kartı x'de
dikkatimi çekti"* + *"harfi yakalamak bazen zor oluyor hala"*. Bölüm 16'nın
turu bu ikisini HİÇ ölçmemişti (kaynak taraması `IconButton`ı "ölçülü"
sayıyordu). Ölçülen: `KDialogCard` ✕ **28×28**, öteki ✕'ler ve dişli
**40×40**, raf taşı **46.3×46** (çevresi ölü alan). Hepsi 48'e / 49.3×65'e
çıkarıldı, **görsel kıpırdamadan**.

Testler kutuyu ölçüyor ama **gerçek parmakla ıskalamayı hiçbir test
ölçemez** — burası o teyit. Önce Setup'taki `Derleme <sha>` satırının bu
düzeltmeyi içeren derlemeyle eşleştiğini doğrula.

- [ ] **Skor kartının ✕'i ilk dokunuşta kapatıyor** — bildirilen hatanın
      birebir teyidi. ✕'in tam ortasına değil, biraz ALTINA/yanına
      dokunmayı da dene: artık çalışmalı.
- [ ] **✕ görsel olarak YERİNDE** — büyümüş/kaymış görünmemeli (büyüyen
      yalnızca dokunma kutusu). Aynısını onay diyaloglarının (`KDialogCard`)
      ✕'inde, k-lig bilgi penceresinde ve kutlama banner'ında da kontrol et.
- [ ] **Sohbet penceresinin dişlisi ile ✕'i karışmıyor** — ikisi de 48
      olduğundan yan yana duruyorlar; dişliye basınca ayarlar, ✕'e basınca
      kapanma gelmeli (ıskalayan dokunuş yanlış butona düşmemeli).
- [ ] **Raf taşını yakalamak kolaylaştı** — taşın biraz ALTINDAN (rafın alt
      dolgusundan) tutmayı dene; sürükleme başlamalı. İki taşın ARASINA
      denk gelen dokunuş da artık bir taşa düşmeli, boşa gitmemeli.
- [ ] **Taşlar görsel olarak YERİNDE ve aynı boyutta** — raf kutusu
      büyümemiş, isim satırı kaymamış, taşlar arası boşluk hâlâ görünüyor.
- [ ] **Seçili taşın yukarı kalkması bozulmamış** (bir taşa dokun: 7 px
      yukarı kalkmalı, üstteki isim satırına girmemeli).
- [ ] **Titreşimli dokunuş — parmağı KAYDIRARAK dokun (27 Ağustos 2026,
      ikinci tur).** Taslak taşa dokunurken parmağını bilerek ~1-2 mm
      kaydır ve bırak: taş geri alınmalı. Aynısını RAF taşında da yap: taş
      seçilmeli (7 px yukarı kalkmalı) ve **istemeden tahtaya konmamalı**.
      Eskiden 10 px'i aşan her kayma jesti "sürükleme" sayıp sessizce
      yutuyordu. **Negatif kontrol:** gerçek bir sürükleme (raftan tahtaya,
      tahtada bir hücreden diğerine) hâlâ çalışmalı.
- [ ] **Taslak taşı geri alma — İLK dokunuşta (27 Ağustos 2026, Sürüm A
      cihaz testinde bulundu).** Tahtaya bir taş koy, sonra taşı geri almak
      için üzerine dokun — **ilk dokunuşta** geri gelmeli. Bilerek biraz
      ALTINA/üstüne de dokun: komşu hücre BOŞ olsa bile taş geri alınmalı,
      "Önce bir harf seç." yazmamalı. **Negatif kontrol:** raftan bir taş
      SEÇİLİYKEN komşu boş hücreye dokun — orada harf KONMALI (kurtarma
      karışmamalı). Canlı oyunda da aynısını dene.
- [ ] **Tanıtımdaki "DEVAM ›" (27 Ağustos 2026).** Uygulamayı ilk kez açan
      bir cihazda (ya da bayrağı silerek) tanıtımı aç: düğme **normal
      boyda** olmalı (ekranı kaplamamalı), **yatayda ortalı** durmalı ve
      ekranın alt kenarına **yapışmamalı**. **Telefonu YATAY çevirip de
      bak** — kullanıcı kusuru orada fark etmişti. Sayfa noktaları solda,
      düğme ortada; **son slaytta noktalar da düğme de KAYBOLMALI**, yalnızca
      "HEMEN OYNA" kalmalı.
- [ ] **Oyun kartındaki kalp / mesaj / hamle ikonları (27 Ağustos 2026).**
      "Tüm Oyunlarım"da bir kartta bu ikonların biraz ALTINA/üstüne dokun —
      ikonun kendi eylemi çalışmalı (beğeni / sohbet / hamle dökümü), kart
      açılıp kapanmamalı. **Aynı satırda ikonlardan UZAK bir yere** dokun:
      kart eskisi gibi açılıp kapanmalı (yönlendirme kartın kendi
      dokunuşunu yutmamalı). İkonların boyutu ve yeri DEĞİŞMEMİŞ olmalı.
- [ ] **Joker harf ızgarası (27 Ağustos 2026, ikinci tarama).** Bir joker
      oyna → harf penceresi açılır. Harflerin biraz ALTINA/üstüne dokunmayı
      dene: **istediğin harf gelmeli**, komşu satırdaki harf değil (satırlar
      arası ölü bant kalktı). Harflerin boyutu ve aralarındaki boşluk
      DEĞİŞMEMİŞ görünmeli. Konmuş bir jokeri düzenlerken de aç: **"GERİ AL"
      butonu tam eski yerinde** olmalı.

## 16. Dokunma hedefleri 48 dp — İKİNCİ tur (24 Ağustos 2026, Parça 134)

Bölüm 15'teki düzeltme **yetmedi**: kullanıcı aynı şikayeti beş kontrol için
tekrarladı — *"biraz üstüne basınca çalışıyor"*. Ölçüm (CI, 390×844) alt
şeridi **31.0**, "← Geri"yi **29.3**, "Detaylı Kurallar"ı **14.0** px
gösterdi; asgari 48 oldu. **"← Geri" ayrıca TAMAMEN ölüydü** (kutusunun
dışına taşırılmış bir `Positioned` hiç dokunuş almıyor).

`tap_target_test.dart` artık her hedefin kutusunu ölçüp iddia ediyor, ama
**gerçek parmakla ıskalamayı hiçbir test ölçemez** — burası o teyit. Önce
Setup'taki `Derleme <sha>` satırının bu düzeltmeyi içeren derlemeyle
eşleştiğini doğrula.

- [ ] **"← Geri" ETİKETİNE dokunmak Setup'a döndürüyor** (logoya değil,
      YAZININ kendisine dokun) — bu, bildirilen hatanın birebir teyidi.
- [ ] **Logo hâlâ Setup'a döndürüyor** ve **skor kutularıyla hizası
      bozulmamış** görünüyor (logo ile puan kutuları aynı yükseklikte).
- [ ] **Avatar** ilk dokunuşta menüyü açıyor; yuvarlak basılı vurgusunun
      köşeleri GÖRÜNMÜYOR (kare gri leke olmamalı).
- [ ] **Misafirken GİRİŞ** butonu ilk dokunuşta açılıyor.
- [ ] **"Nasıl Oynanır?" → "Detaylı Kurallar →"** linki ilk dokunuşta
      geçiş yapıyor; **başlık düzeni bozulmamış** (link üstte, başlık
      altında, ✕ sağda).
- [ ] **Alt şeridin üç linki** ilk dokunuşta açılıyor; okunmamış mesaj
      rozeti hâlâ "Mesajlaşma"nın sağ ÜST köşesinde.
- [ ] **Setup'ın alt linkleri:** "Nasıl oynanır? · Tanıtım" ve "Kullanım
      Koşulları · Gizlilik Politikası · Paylaş" ilk dokunuşta açılıyor;
      aradaki `·` ayraçları satırda ORTALI duruyor (üste yapışmamalı).
- [ ] **"Son Oynadıklarım" → "TÜM OYUNLARIM"** ilk dokunuşta açılıyor.
- [ ] **Header/şerit büyüdü ama düzen bozulmadı:** başlık öncekinden bir
      miktar yüksek olacak (beklenen); tahta, raf ve butonlar hâlâ
      kaydırmayla erişilebilir ve hiçbir yerde sarı/siyah taşma çubuğu
      YOK.

## 17. "Yükleniyor…" okunur mu (24 Ağustos 2026, Parça 134)

Kullanıcı: *"Leaderboard tıklamasında önce 1-2 saniye bir popup görüyorum,
sonra sıralama üstüne geliyor. Aynı durum skor kartta."* Yükleme durumu
zaten vardı, okunmuyordu. **Gecikmenin kendisi düzelmedi ve düzelemez** —
veritabanı Mumbai'de (bkz. `docs/decisions/product-backlog.md`).

- [ ] **k-lig (lider tablosu)** açılınca pencere BOŞ görünmüyor: ortada
      belirgin, mavi, kalın **"Yükleniyor…"** yazısı var.
- [ ] **Skor Kartı** açılınca istatistik alanında aynı yazı var.
- [ ] **Oyun Geçmişi / Sohbet Geçmişi / Canlı oyun listesi** de aynı yazıyı
      gösteriyor (tek bileşen — biri farklı görünüyorsa kaçmış demektir).
- [ ] Veri gelince yazı kayboluyor, hiçbir yerde **takılı kalmıyor**.


## 18. "← Geri" yeni yeri + tek pencere yükleme (24 Ağustos 2026, Parça 135)

Bölüm 16'nın devamı. Kullanıcı ilk turda *"tam üstüne basarsan ok ama biraz
altına gelirse çalışmıyor"* dedi; etiket artık header satırının ALTINDA,
tahtanın üstündeki boşlukta ve o boşluk tıklanabilir.

- [ ] **"← Geri" yazısının BİRAZ ALTINA** dokun (yazının kendisine değil,
      hemen altındaki birkaç piksele) → Setup'a dönmeli.
- [ ] **Yazının kendisi** de hâlâ çalışıyor; **logo** da çalışıyor.
- [ ] **Header küçüldü:** logo + skor kutuları bandı gözle öncekinden
      belirgin şekilde daha alçak; logo ile skor kutuları hâlâ aynı hizada.
- [ ] **"← Geri" logodan kopmadı:** logonun hemen altında duruyor (arası
      öncekinden bir miktar açık, bu beklenen), sol kenarı tahtanın sol
      kenarıyla hizalı.
- [ ] **Tahta yukarı kaymadı/taşmadı:** hiçbir yerde sarı-siyah taşma
      çubuğu yok, raf ve butonlar erişilebilir.

### Tek pencere yükleme

- [ ] **k-lig** açılınca pencere **tek boyda** açılmalı: içerik alanı boş
      değil, ortasında "Yükleniyor…" — ve veri gelince pencere BÜYÜMEMELİ,
      liste yerinde dolmalı.
- [ ] **Skor Kartı** açılınca istatistik kutuları `—` ile baştan çizili
      olmalı; sayılar yerinde dolmalı, pencere büyümemeli.

## 19. Tahta açılışı pürüzsüz mü (24 Ağustos 2026, Parça 137)

Kullanıcı: *"YZ ile oyun açtığında board'un ekrana gelmesi takılarak
oluyor"* (girişli açılışta da). Artık geçiş boyunca Canlı oyundakiyle AYNI
"Yükleniyor…" gösteriliyor, tahta geçişten sonra çiziliyor.

- [ ] **Yapay Zeka oyunu aç** (hem misafirken hem girişliyken) → kısa bir
      "Yükleniyor…" görünmeli, geçiş **pürüzsüz** olmalı, kareler
      düşmemeli.
- [ ] **Tahta geliyor:** yükleme metni takılı KALMAMALI; tahta tam
      gölgeleriyle (hücrelerin içe gömülü gölgesi, kartın dış gölgesi)
      çizilmeli.
- [ ] **Canlı oyun** açılışı da aynı görünmeli — iki yerde de aynı yazı,
      aynı stil.
- [ ] **Oyun içinden GameOver → TEKRAR OYNA** akışı hâlâ çalışıyor (aynı
      ekranda ikinci oyun; yükleme kapısı yalnızca geçişte devrede).

## 20. Taslak sürerken kelime anlamı (24 Ağustos 2026, Parça 138)

Kullanıcı: *"koyduğum taşın üstüne basıp geri almaya çalıştığımda oradaki
daha önce bulunan kelimelerin anlamları açıldı."* Artık taslak hamle
varken oynanmış taşa dokunmak hiçbir şey yapmıyor.

- [ ] **İki kelimenin birleştiği yere** bir taş koy (OYNA'ya BASMA) →
      taşın üstüne dokunup geri almayı dene. Iskalasan bile **anlam
      penceresi AÇILMAMALI**; tekrar deneyince taş rafa dönmeli.
- [ ] **Taslak boşken** (henüz taş koymadan ya da rakibin sırasındayken)
      oynanmış bir taşa dokun → anlam penceresi eskisi gibi AÇILMALI.
- [ ] Aynı ikisini **Canlı oyunda** da dene (iki ekran deseni paylaşıyor).
- [ ] Taşı **rafa sürükleyerek** geri alma yolu hâlâ çalışıyor.

### Iskalama kurtarma (aynı tur)

- [ ] Taslak taşını geri almak için **kasten biraz aşağısına** (altındaki
      oynanmış taşa) dokun → taslak taşı GERİ ALINMALI.
- [ ] **Yan yana üç taslak harf** koy, ortadakine dokun → yalnızca ORTADAKİ
      geri alınmalı, yandakiler yerinde kalmalı.
- [ ] **Mevcut bir taşın hem üstüne hem altına** harf koy, sonra ortadaki
      (oynanmış) taşa tam ortasından dokun → hiçbir taş geri alınmamalı
      (belirsizlikte tahmin yok); biraz üstüne/altına kayarsan yakın olan
      geri alınmalı.
- [ ] Kelimeyi dizerken **boş hücrelere taş koymak** eskisi gibi kolay
      olmalı — kurtarma boş hücrelere bulaşmamalı.

## 21. Uygulama içinden hesap silme (25 Ağustos 2026, ROADMAP madde 2)

**GERİ DÖNÜŞSÜZ.** YALNIZCA feda edilebilir bir test hesabıyla koş —
`Ironman` ve App access formunda incelemeciye verilen `T2` HARİÇ (ROADMAP
#4). Kaskad, verilmiş karar ve ölçümler: `docs/decisions/account-deletion.md`.

`account_settings_test.dart` yalnızca "giriş açılıyor + kuru çalıştırma
düşerse buton etkinleşmiyor" sözleşmesini kilitliyor (`AuthService.fake`
gerçek bir Supabase client taşımıyor). Gerçek silme YALNIZCA burada
görülebilir.

- [ ] **Giriş görünür.** Hesap → Hesap Ayarları → en altta, KAYDET'in
      altındaki ayracın arkasında kırmızı **"HESABIMI SİL"** ve altında
      "Kalıcıdır, geri alınamaz." Dokunma hedefi 48 dp (metnin biraz
      üstüne/altına basınca da açılmalı — Parça 132/134'ün sınıfı).
- [ ] **Kuru çalıştırma GERÇEK sayı gösteriyor.** Pencere açılınca
      "SİLİNECEKLER" listesi belirmeli, sayılar hesabın gerçek verisiyle
      uyuşmalı; sıfır olan satırlar HİÇ görünmemeli.
- [ ] **Web ile AYNI sayılar.** Aynı hesapla `kelimeki.com`da Hesap
      Ayarları → Hesabımı Sil: liste ve sayılar birebir aynı olmalı (tek
      kaynak aynı RPC — ayrışıyorsa bir taraf kendi sorgusunu yazmış
      demektir).
- [ ] **Onay kelimesi.** `SİL` yazmadan buton devre dışı; `sil` de kabul
      edilmeli (`trUpper` — native `toUpperCase()` "SIL" üretir ve eşleşme
      SESSİZCE tutmazdı).
- [ ] **Silme sonrası.** Pencere kapanmalı, Hesap Ayarları da kapanmalı ve
      Setup'ın **girişsiz** hâli görünmeli (oturum kapandı). Uygulamayı
      öldürüp yeniden aç: hâlâ girişsiz olmalı (SharedPreferences'ta ölü
      oturum kalmamalı).
- [ ] **Yeniden kayıt.** Aynı e-posta ve aynı takma adla yeniden kayıt
      olunabilmeli.
- [ ] **Rakibin kaydı KORUNDU ve ANONİMLEŞTİ.** Silinen kişiyle oynamış
      BAŞKA bir hesapla (mobil VE web'den) gir: o oyun geçmişte durmalı,
      puanlar değişmemeli, oyuncu adı **"Silinmiş oyuncu"** olmalı; sohbet
      arşivinde de aynı ad görünmeli.
- [ ] **Devam eden Canlı oyun düştü.** Silinen kişiyle YARIM kalmış bir
      oyun varsa rakibin "Canlı" listesinde artık olmamalı.
- [ ] **Rakibin Canlı LİSTESİ hâlâ yükleniyor** (26 Ağustos 2026'da bu
      GERÇEKTEN kırıldı — bkz. `docs/decisions/account-deletion.md` → "SET
      NULL'ın bedeli"). Silinen kişinin AÇTIĞI bitmiş bir oyun varsa
      (`online_games.created_by` artık NULL) rakibin Canlı sekmesindeki üç
      alt sekme de normal açılmalı: "Oyunların şu an yüklenemedi." ÇIKMAMALI.
      "Son oynananlar"daki o kartın başlığı **"Bir arkadaşın açtı"** olur —
      bu doğru davranış, kurucunun profili artık yok.
- [ ] **Yönetici silinemiyor.** Admin bir hesapla pencereyi aç: kuru
      çalıştırma **"Yönetici hesabı uygulama içinden silinemez."** demeli,
      silme butonu HİÇ etkinleşmemeli.
- [ ] **Uçak modunda.** Bağlantı kapalıyken pencereyi aç: hata görünmeli ve
      silme butonu ETKİNLEŞMEMELİ (sessizce "silindi" demesin).
- [ ] **Gizlilik metni senkron.** Hesap → Gizlilik Politikası → 5. bölüm
      "Hesap Ayarları › Hesabımı Sil" adımını anlatmalı ve "Son güncelleme"
      web ile aynı tarihi taşımalı (`legal_text_test.dart` bunu zaten
      zorluyor; buradaki kontrol metnin GÖRÜNDÜĞÜNÜ doğruluyor).

## 22. Oyun ekranı akıcılığı — nömorfik dekor önbelleği (26 Ağustos 2026, Parça 144)

Kapalı testin ilk kullanıcılarından 3-4 kişi "ekran donuyor" bildirdi.
Kullanıcı yanında oynayarak doğruladı: *"taşları sürerken ağır çekim…
Her yerde gecikme var. rafta taşlar da ağır, geri tuşu da ağır cevap
veriyor, skor kutusuna basınca skor kart da yavaş açılıyor. Board alanında
her şey ağır."*

Tahtanın 169 hücresi kare başına ~340 gerçek `MaskFilter.blur` çiziyordu.
Artık her gölge deseni bir kez rasterleştirilip önbellekten basılıyor.
**Bu bölüm hem HIZI hem GÖRÜNTÜNÜN AYNI KALDIĞINI kontrol ediyor** — ikisi
ayrı ayrı sorulmalı, çünkü hızlanma görsel bir bozulmayla gelirse düzeltme
değil takas olur.

Ölçüm cihazı: **gerçek Android telefon** (Appetize/web derlemesi bu soruyu
CEVAPLAMAZ — rasterleştirme motoru farklı). Önce Setup'ın teşhis satırından
`Derleme <sha>` oku ve doğru pakette olduğunu doğrula.

### Hız

- [ ] **Taş sürükleme.** Raftan bir taşı al ve tahtada gezdir: hayalet taş
      **parmağa yapışık** hareket etmeli. "Parmak gidiyor, taş arkadan
      geliyor" belirtisi KALMAMALI.
- [ ] **Raf içinde sürükleme.** Taşları raf içinde yer değiştir — aynı
      akıcılık.
- [ ] **"← Geri".** Dokunuşa **anında** cevap vermeli, gecikmeli değil.
- [ ] **Skor kutusu → skor kartı.** Üstteki skor kutusuna dokun: pencere
      takılmadan açılmalı, açılış animasyonu kare düşürmemeli.
- [ ] **Canlı oyun ekranı** (iki ekran deseni paylaşıyor): aynı dört
      kontrol orada da geçmeli.

### Görüntü (değişmemiş olmalı)

- [ ] **Boş kareler.** Hücrelerin içe gömülü gölgesi duruyor mu — sol-üst
      beyaz, sağ-alt gri. Düz/gölgesiz görünüyorsa önbellek yanlış
      rasterleştiriyor.
- [ ] **Altın bölge ve merkez X3 karesi.** Kendi gölgeleri + dış gölgeleri
      duruyor; kenarları keskin, bulanık DEĞİL.
- [ ] **Oyuncu bölgeleri.** Bölge tonlaması ve dış hat çizgisi doğru; bir
      hamle sonrası bölge büyüyünce yeni hücreler doğru tonda çiziliyor.
- [ ] **Raf taşları ve butonlar.** Altın taşın parlaması ve butonların
      kabarık gölgesi web'deki gibi; kenarlarda basamak/karelenme YOK.
- [ ] **Ekranı döndür / iki farklı cihaz.** Farklı piksel yoğunluğunda
      gölgeler hâlâ net (önbellek anahtarı dpr'yi taşıyor; taşımasaydı bir
      cihazda bulanık çıkardı).

## 23. "Buradan başla" balonu (26 Ağustos 2026, Parça 145)

Kapalı testte insanlar ilk hamleyi nereye yapacaklarını bulamıyordu. Balon
sırası gelen İNSAN oyuncunun ev karesinin yanında çıkar.

- [ ] **Yeni YZ oyunu aç** → tahta bomboşken ev karesinin (sol-üst) hemen
      sağında **"Buradan başla"** balonu, kuyruğu kareye bakar hâlde
      görünmeli. Balon tahtadan TAŞMAMALI.
- [ ] **Raftan bir taşı KALDIR** (parmağını basılı tutup sürüklemeye başla,
      henüz bırakma) → balon **o anda** kaybolmalı. Koyunca değil,
      **kaldırınca**.
- [ ] **Sürüklemeyi iptal et** (taşı rafa geri bırak) → balon geri gelmeli.
- [ ] **Rafta bir taşa DOKUN** (seç, sürükleme yok) → balon yine kaybolmalı.
- [ ] **Taşı tahtaya koy, sonra geri al** → tahta yine boş olduğundan balon
      geri gelir.
- [ ] **YZ'nin sırasında** balon görünmemeli.
- [ ] **İlk hamle oynandıktan sonra** balon bir daha çıkmamalı — oyunun
      geri kalanında hiç.
- [ ] **4 kişilik oyun:** balon yine SENİN ev karenin yanında ve tahtanın
      içine doğru uzanmalı (sağ köşedeysen sola doğru), kenardan taşmamalı.
- [ ] **Canlı oyun** ekranında da aynı davranış (iki ekran `BoardWidget`'ı
      paylaşıyor).

## 25. Sistem yazı boyutu — sayılar bölünmüyor (1 Eylül 2026)

Ayarlar → Ekran → Yazı tipi boyutunu **en büyüğe** al (uygulama 1,3'te
kırpar), sonra:

- [ ] **Bir oyunu bitir** → bitirme modalında `KALAN`/`TOPLAM`/`k-lig`
      başlıkları ve skorlar TEK SATIR olmalı; `241` gibi bir sayı
      `24`/`1` diye bölünmemeli.
- [ ] **Skor Kartı → k-lig lider tablosu** → `SIRA`/`OHP`/`PUAN`
      BAŞLIKLARI ve altlarındaki değerler tek satır. Özellikle **OHP
      değeri** (`13.17`) ve **`SIRA` başlığı**: 2 Eylül 2026'da cihazda
      ikisi de bölünüyordu (`13.`/`17` ve `SIR`/`A`) — 1 Eylül turunda bu
      satırın yalnızca sıra/skor hücreleri çevrilmiş, başlıklar ve aradaki
      OHP atlanmıştı.
- [ ] **Oyun geçmişi (Tüm Oyunlarım → bir oyun)** → `PUAN`/`k-lig`
      başlıkları, sıra ve skorlar tek satır.
- [ ] **Tahtada onaylı bir taşa dokun (kelime anlamı)** → madde numaraları
      (`1.`, `2.` …) tek satır.
- [ ] **Yardım → k-lig kademe tablosu** → kademe harfleri tek satır.
- [ ] **LİSTE SIRALAMASI** (3 Eylül 2026): (a) Yapay Zeka "DEVAM EDEN
      OYUNLAR" → silinmeye en yakın kayıt EN ÜSTTE; (b) Canlı "Devam
      Edenler" → sırası SENDE olanlar üstte ve KENDİ İÇİNDE en yakın teslim
      en üstte; (c) "Oyun Davetleri" → süresi bitmeye en yakın davet en
      üstte. ⚠ Sırası RAKİPTE olan oyunlarda yön TERSİ ve bu bilinçli:
      orada "son oynanan üstte" (31 Ağustos kararı) — o grubu en-yakın-bitiş
      sanıp hata bildirme.
- [ ] **Son Oynananlar / Son Oynadıklarım → AVATARLAR** (2 Eylül 2026):
      bitmiş bir Canlı oyunda rakiplerin fotoğrafı, Yapay Zeka sekmesinde
      kendi fotoğrafın görünmeli. ⚠ Fotoğrafı olmayan üye baş harfte,
      YZ robotta, misafir "?"te KALIR — eksik değil, kural. ⚠ Oyundan SONRA
      takma adını değiştiren biri baş harfe düşer (yanlış yüz göstermemek
      için bilinçli).
- [ ] **Setup → DEVAM EDEN OYUN kartı** (yarım bir yerel oyun bırakıp
      Setup'a dön) → `SIRA SENDE` oyuncu satırının SAĞINDA, kalan süre
      ALTTA tam genişlik satırda (Canlı oyundaki `SIRA RAKİPTE` kartıyla
      aynı şekil). Etiket kartın ORTASINDA durmamalı. Oyuncu adları
      kırpılmamalı. **Avatarların ALTINDA `Sıra: X` YAZMAMALI** (2 Eylül
      2026'da kaldırıldı — yanındaki `SIRA SENDE` ile aynı şeyi söylüyordu).
- [ ] **İKİ SEKMEYİ YAN YANA KARŞILAŞTIR** (2 Eylül 2026 — bildirilen hata
      buydu): "Yapay Zeka" ve "Arkadaşınla" sekmelerindeki devam eden oyun
      kartları AYNI düzende olmalı. Canlı karttaki **kalan süre, "X açtı"
      yazısının ALTINDAKİ kendi satırında** olmalı — o yazıya BİNMEMELİ.
      ⚠ "X açtı" satırının KENDİSİ kalır (YZ'deki `Sıra: X`'e benzemez).
      `SIRA SENDE`/`SIRA RAKİPTE` puntosu 15 px'e çıktı — iki kartta da
      aynı büyüklükte görünmeli, yanındaki üçgen/nokta harflerle aynı
      bantta durmalı (küçük kalmamalı).
- [ ] **Rafın üstündeki mesaj satırı** → uzun bir mesaj (ör. "+9 puan
      (5 puanı X kaptı)") KESİLMEMELİ; kutu metinle birlikte büyümeli.
      (2 Eylül 2026: port sabit 30 px kullanıyordu, web ikizi `min-h`.)
- [ ] **Board altındaki şerit** (Hamleler · Mesajlaşma · **Yardım**) →
      ölçek tavanında da TEK SATIR (48 px) kalmalı, iki satıra düşmemeli.
      Etiket 2 Eylül 2026'da `Nasıl Oynanır?` → `Yardım` oldu (kullanıcı
      fikri) ve ÖLÇÜLDÜ: 14 karakterlik etiketle tavanda şerit 48 → 96 px'e
      çıkıyordu, tek satırda kalabilen en yüksek ölçek 360 px'te 1,10 idi;
      `Yardım` ile 320/360/390 px'in üçünde de tavanda tek satır.
      ⚠ Yalnızca ŞERİT etiketi değişti — HelpModal başlığı, hesap menüsü
      maddesi ve `/nasil-oynanir/` sayfası `Nasıl Oynanır?` olarak kaldı.
- [ ] Yazı boyutunu normale al → hiçbir yerde görünüm değişmemeli; DEVAM
      EDEN OYUN kartının şekli AYNI kalmalı (düzen artık ölçekten bağımsız
      — ölçeğe göre şekil değiştiren dal 2 Eylül'de kaldırıldı).

## 24. Tahta zoom'u — çift dokunuş + pan (1 Eylül 2026, Parça 175)

Sadece tahtanın İÇİ büyür (2×); raf, başlık, butonlar sabit kalır. Kapsam:
boş hücreler + taslak taşlar. Onaylı taş kapsam DIŞI (tek dokunuş anlam
penceresini anında açmaya devam eder). İki ekranda da (YZ oyunu + Canlı).

### Aç/kapa

- [ ] **Boş bir hücreye çift dokun** → tahta dokunulan noktaya odaklı
      büyür (animasyonlu); raf/başlık/butonlar YERİNDEN OYNAMAZ.
- [ ] **KENARDAN çift dokun** (karelerin dışı ama tahtanın içi — çerçeve
      şeridi ya da iki kare arasındaki boşluk) → zoom yine açılır/kapanır
      (1 Eylül'de APK'da bulunan eksik: yalnızca karelerde çalışıyordu).
- [ ] **Hamle puanı rozeti (`+7`) KESİLMEMELİ** — tahtanın SOL/ÜST
      kenarındaki bir hücreye taş koy: rozet ızgaranın dışına taşar ve tam
      görünmeli (yuvarlak kenarı kesik olmamalı). Zoom açıkken de aynı.
- [ ] **Bölge çizgisi kenarlarda İNCELMEMELİ** — hem zoom kapalıyken hem
      zoom açık tahta duvara dayalıyken, tahta kenarındaki bölge çizgisi
      ortadakilerle aynı kalınlıkta (1 Eylül'de APK'da bulunan kırpma
      hatası: kenarda yarıya iniyordu).
- [ ] **Tekrar çift dokun** → eski hâline döner.
- [ ] **Kenara yakın çift dokunuş** → tahta kenardan "boşluk gösterecek"
      şekilde kaymaz (offset sınırda durur).
- [ ] **Rövanş / yeni oyun** → zoom sıfırlanmış açılır.

### Tanıtım balonu (1 Eylül 2026)

Kural: balon **en çok iki oyun açılışında** çıkar ve zoom bir kez
denenirse bir daha ASLA çıkmaz. Bayraklar cihaz-yerel, yani Canlı oyunda
hem açan hem karşı taraf kendi ilk açılışında görür.

- [ ] **Uygulamayı ilk kez kurup oyun aç** → tahtanın ortasında, merkez
      kareyi işaret eden mavi balon: **"Boş kareye veya çerçevesine çift
      tıklama tahtayı büyütür. Hemen dene!"** Balon tahtadan taşmamalı,
      metin sığmalı (dar telefonda 2-3 satır).
- [ ] **Çift dokunup zoom yap** → balon ANINDA kaybolmalı.
- [ ] **Oyundan çık, yeni oyun aç** → balon bir daha ÇIKMAMALI (denendi).
- [ ] **(Temiz kurulumla)** balonu görüp zoom yapMADAN çık, yeni oyun aç →
      balon İKİNCİ kez çıkar; üçüncü açılışta artık çıkmaz.
- [ ] **Raftan taş kaldır (sürükle)** → balon kaybolur, bırakınca döner
      ("Buradan başla" ile aynı davranış).
- [ ] **Canlı oyun** ekranında da aynı balon aynı kurallarla.

### Tek dokunuşlar DEĞİŞMEDİ (en kritik grup)

- [ ] **Harf seç + boş hücreye TEK dokun** → taş ANINDA konur, gecikme
      hissedilmez (çift dokunuş beklemesi YOK).
- [ ] **Taslak taşa TEK dokun** → anında geri alınır.
- [ ] **Onaylı taşa TEK dokun** → kelime anlamı ANINDA açılır; onaylı taşa
      çift dokunuş zoom AÇMAZ.
- [ ] **Joker seç + hücreye dokun** → harf seçim penceresi ANINDA açılır
      (zoom'la hiçbir ilişkisi yok); harf seçimi normal çalışır.
- [ ] **Harf SEÇİLİYKEN boş hücreye çift dokun** → ilk dokunuş taşı KOYAR
      ve taş KONDUĞU YERDE KALIR; ikinci dokunuş yalnızca zoom'u açar
      (taşı GERİ ALMAMALI).
- [ ] **Taş koy, sonra BAŞKA boş bir kareye çift dokun** → taş yerinde
      kalır, zoom açılır (kullanıcının birebir senaryosu).
- [ ] **Taslak taşa çift dokun** → ilk dokunuş taşı geri alır (normal tek
      dokunuş davranışı), zoom AÇILMAZ — çift dokunuş yalnızca boş kare
      jesti.

### Zoom AÇIKKEN oyun

- [ ] **Raftan taşı sürükleyip bırak** → taş NİŞAN ALINAN hücreye iner
      (kayma/ıskalarsa bu sürümün en kritik hatasıdır — bildir).
- [ ] **Taslak taşı rafa sürükle** → geri alınır (tahtada "görünmeyen bir
      hücreye" İNMEMELİ).
- [ ] **Tek dokunuşla koy/geri al** → zoom'suzken nasılsa öyle.
- [ ] **Joker akışı** (sürükleyerek ve dokunarak) → pencere açılır, harf
      seçilir, taş doğru hücrede.
- [ ] **Boş alandan parmakla sürükle** → tahta pan olur; kenarda durur;
      SAYFA kaymaz. Parmağı kaldırınca hiçbir taş konmaz/geri alınmaz.
- [ ] **Pan biter bitmez hemen dokun** → yanlışlıkla taş konmaz (kısa bir
      yutma penceresi var).
- [ ] **"Oyna" ile kelime onayla** → skor/sıra akışı normal; YZ hamlesi
      gelince tahta güncellenir, zoom açık kalır.

### Zoom KAPALIYKEN

- [ ] **Tahtada parmak sürüklemek** tahtayı OYNATMAZ (sayfa kaydırma
      çalışır), taş sürükleme normal.
