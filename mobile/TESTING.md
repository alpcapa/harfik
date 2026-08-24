# Kelimeki Mobil — Cihaz Test Kontrol Listesi

Bu dosya, `flutter test`'in **yapısı gereği** kapsayamadığı her şey içindir:
gerçek Supabase (auth/RLS/RPC), gerçek platform kanalları (paylaş sayfası,
dosya sistemi), gerçek derleme ve gerçek cihaz davranışı. Otomatik testler
(409 test) veri katmanını **sahte uçlarla** sınıyor — yani "testler yeşil"
demek "sunucuyla gerçekten konuşuyor" demek DEĞİL. Bir sütun adı ya da RPC
parametresi yanlışsa liste sessizce boş döner ve bunu yalnızca burada
görürsün.

Kök dizindeki `TESTING.md` (web) ile aynı disipline tabidir: **bir ilerleme
kaydı değildir**, her sürüm öncesi baştan koşulabilir.

**"Bu turda nereye kadar geldik?" sorusunun cevabı burada DEĞİL** — o,
tura özgü bir anlık görüntü olduğundan `mobile/CLAUDE.md`'nin **"FAZ A1 —
Cihaz Testi Tur Durumu"** bölümünde duruyor: hangi bölümler koşuldu,
hangileri yarım kaldı, hangi maddeler son düzeltmelerden sonra hiç
koşulmadı. Yeni bir tura başlamadan önce oraya bak.

**Buradan bir bulgu çıktığında düzeltmeye başlamadan önce:** o davranışın
web'deki karşılığını (`src/`) OKU — bu port web'in birebir kopyası, bulgu
neredeyse her zaman "web'de nasıl yapıldığına bakılmadan yazılmış bir
parça" demek. Ayrıntı ve bu kuralın atlanmasının bedeli: `mobile/CLAUDE.md`,
"Sorun Bildirildiğinde İLK ADIM".

**Ön koşullar:**
- Uygulama gerçek anahtarlarla derlenmiş olmalı:
  `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
  Anahtar verilmezse uygulama tamamen offline moda düşer (hesap özellikleri
  gizlenir) — bu listenin çoğu koşulamaz. CI bunları depo sırlarından
  (`SUPABASE_URL`/`SUPABASE_ANON_KEY`) okuyor; sırlar boşken üretilen APK
  yalnızca 0. ve 1. bölümler için kullanılabilir.
- **Anahtarın gerçekten gömüldüğünü ilk açılışta doğrula:** kurulum
  ekranında hesap/giriş girişi görünüyorsa gömülmüştür; görünmüyorsa APK
  offline modda derlenmiş demektir (sırlar eksik ya da yanlış adla
  girilmiş).
- İki test hesabı (ör. T1/T2) ve **aynı hesapla açılmış bir web oturumu**:
  bu listenin en değerli maddeleri web ↔ mobil aynı veriyi görüyor mu diye
  soruyor.
- Web'de zaten oynanmış birkaç biten oyun (geçmiş/istatistik ekranlarının
  boş kalmaması için).

**Neden bu kadar çok "web'den kontrol et" var:** mobil ve web AYNI tabloları
paylaşıyor (`games`, `local_game_saves`, `profiles`, `player_stats`).
Mobilin yazdığını web'in doğru okuması (ve tersi) bu portun temel
sözleşmesi — tek taraflı bakmak bir hatayı gizleyebilir.

---

## 0. Derleme ve ilk açılış

- [ ] **Derleme geçiyor.** GitHub Actions → "Mobil derleme" → en son
      çalıştırma yeşil olmalı (analiz+testler, Android APK, iOS imzasız).
      Port dalına `mobile/**` altında her push otomatik tetikliyor; elle
      çalıştırma (Run workflow) yalnızca dosya main'e girdikten sonra
      Actions sekmesinde belirir.
      Bu, bu ortamda HİÇ koşulmamış olan `pod install`/gradle adımlarının
      ilk gerçek kanıtı — özellikle beş platform eklentisi
      (sqflite, shared_preferences, supabase_flutter, share_plus,
      path_provider) için.
- [ ] **Uygulama ikonu.** Ana ekranda/Appetize'ın uygulama listesinde
      "kelimeki" el yazısı ikonu görünmeli — Flutter'ın varsayılan mavi kuş
      DEĞİL (7 Ağustos 2026'ya kadar bu hiç üretilmemişti, ilk Appetize
      denemesinde fark edildi).
- [ ] **Splash ekranı.** Uygulama açılırken kısa bir an beyaz zemin
      üzerinde "kelimeki" logosu görünmeli — siyah ekran ya da mavi kuş
      GÖRÜNMEMELİ. Android'de sistem karanlık modda olsa bile splash beyaz
      kalmalı (uygulamanın kendisi karanlık tema desteklemiyor, bkz.
      mobile/CLAUDE.md "Uygulama İkonu / Splash").
- [ ] **İlk açılış.** Uygulama açılıyor, portre kilitli (yatay tutulan bir
      cihazda bile splash ANINDA dikey kalmalı — `screenOrientation="portrait"`
      native kilidi, bkz. CLAUDE.md), splash sonrası kurulum ekranı geliyor.
      Logo ve yazı tipleri (Space Grotesk/Mono, taşlarda Nunito) doğru —
      sistem yazı tipine düşmüş görünmemeli.
- [ ] **Sözlük yükleniyor.** "Oyunu Başlat" başlangıçta "HAZIRLANIYOR…"
      gösterip birkaç saniye içinde etkinleşmeli (63.890 kelime asset'ten
      bir isolate'te okunuyor).
- [ ] **Sürüm kapısı.** Uygulama açılıyorsa `app_config
      .mobile_min_supported_version` kontrolü geçmiş demektir. (Kapıyı
      test etmek istersen o satırı geçici olarak `99.0.0` yapıp uygulamayı
      yeniden aç: "güncelleme gerekli" ekranı çıkmalı — sonra geri al.)

## 0.4 İlk açılış tanıtımı — `IntroScreen` (Parça 116 + 117 + 118)

Web'in karşılama katmanının porttaki karşılığı. **Temiz bir kurulum
gerekiyor:** uygulamayı silip yeniden kur (ya da web test derlemesinde
site verisini temizle) — bayrak (`seen_intro`, SharedPreferences) bir kez
yazıldıktan sonra tanıtım bir daha ÇIKMAZ.

- [ ] **İlk açılışta Setup'tan ÖNCE tanıtım çıkıyor.** BEŞ sayfa
      (19 Ağustos 2026'da yeniden düzenlendi — Parça 118 + 119):
      (1) "Kelime bul, bölgeni büyüt, tahtayı ele geçir." + tanım
      paragrafı + **"TAHTAYA BİR BAK"** bölümü (2 kişilik tahta, X2/X3
      legend'ı ve altındaki açıklama),
      (2) **dört rakam kutusu** (63.000+ / 13×13 / 2–4 / Ücretsiz) +
      **4 kişilik tahta** + altındaki açıklama (X2/X3 legend'ı burada
      TEKRARLANMAZ), (3) "Nasıl oynanır?" DÖRT adım birden, (4) "Neler
      var" ALTI özellik kutusu, (5) dokuz k-lig rütbesi.
      **Rakam kutuları 19 Ağustos 2026'da 1. slayttan 2.'ye TAŞINDI**
      (Parça 119) — 1. slayt tek ekrana sığmayıp kayıyordu, 2. slayt ise
      yalnızca tahtadan ibaret olduğu için boş duruyordu.
- [ ] **1. slayttaki X2/X3 legend'i YAN YANA** (web'de de öyle; port
      19 Ağustos 2026'ya kadar bunu alt alta çiziyordu — `Wrap` değil elle
      dikey `Column` kodlanmıştı). Çok dar bir telefonda (≈375px ve altı)
      alta sarması DOĞRU davranış; web de 320px'te sarıyor.
- [ ] **1. ve 2. slayt KAYDIRMADAN tamamen sığıyor** — parmakla aşağı
      çekince slayt İÇİNDE dikey bir kayma OLMAMALI (yatay geçiş elbette
      var), açıklamanın son satırı alt kenarda kesilmemeli. Bu maddeyi
      birden fazla ekran boyunda dene (küçük telefon + büyük telefon) ve
      **GitHub Pages web derlemesini iOS Safari'de de** aç: orada durum
      çubuğu + alt adres çubuğu görünür yüksekliği ~150px kısaltıyor ve
      1. slayt 19 Ağustos 2026'da tam bu yüzden bir satır taşıyordu
      (widget testi o gün 420×900'de yeşildi). Test artık 420×900 VE
      430×740 boylarında koşuyor; bunlardan da dar/kısa bir yüzeyde
      kaydırma fallback'i bilerek duruyor.
- [ ] **Logo BEŞ sayfada da var** ve BEŞİNDE de içerikle BİRLİKTE
      dikeyde ortalanıyor (logo ile başlık arası her sayfada aynı; logo
      yukarıda asılı kalıp aralarında boşluk açılmamalı). 1. sayfa Parça
      119'a kadar bunun DIŞINDAYDI (orası ekranı dolduruyordu); rakam
      kutuları 2. slayda taşınınca o istisna kalktı.
- [ ] **Alt şeritte ara sayfalarda YALNIZCA nokta göstergesi var** (BEŞ
      nokta), hiçbir düğme yok; **HEMEN OYNA yalnızca 5. sayfada** çıkıyor
      (19 Ağustos 2026 kullanıcı kararı: "alttaki kocaman Devam butonu çok
      gereksiz"). İlerleme parmakla kaydırarak.
- [ ] **Masaüstü tarayıcıda da (GitHub Pages test ortamı) FARE ile
      sürüklenebiliyor** — beş sayfa da gezilip son sayfaya
      ulaşılabilmeli. Flutter'ın varsayılan davranışı fareyi kaydırma
      cihazı SAYMAZ; bu olmazsa DEVAM düğmesi de kalktığı için tanıtımda
      kilitli kalınır.
- [ ] **1. slayttaki tahta gerçek oyun tahtasıyla AYNI görünüyor** —
      web'in "Tahtaya bir bak" bölümüyle yan yana koy: harfler ve hücreler
      aynı oranda, köşe rakamı/X2 filigranı ve X3 hücresi görünür, taşlar
      taşların ALTINDA kalan filigranlarla doğru katmanda. **Harfler
      belirgin şekilde küçük/büyük görünüyorsa sebep font değil KABIN
      GENİŞLİĞİDİR** (tahta 680'lik kendi kabında olmalı, 460'lık metin
      sütununda değil — web bu tuzağa iki kez düştü).
- [ ] **2. slayttaki 4 kişilik tahtada DÖRT köşe de dolu** ve dört ayrı
      oyuncu rengi görünüyor (bölge dış hatları dahil) — web'in aynı
      görseliyle yan yana koy.
- [ ] **4. slaytta altı kutunun ALTISI da ikonlu** (robot, iki kişi,
      konuşma balonu, üstü çizili wifi, tahta, madalya) ve ikon başlığın
      SOLUNDA, başlıkla aynı boyda. Boş kare/eksik ikon OLMAMALI.
- [ ] **5. slaytta dokuz rütbe kutusu var** ve her birinde mühür + ad +
      eşik puanı okunuyor.
- [ ] **Üst başlıklar TÜRKÇE büyük harfle:** `KELİME` · `FİYAT` ·
      `TAHTAYA BİR BAK` · `K-LİG` — noktasız `I` görürsen (`KELIME`,
      `K-LIG`) `trUpper` yerine `toUpperCase()` sızmış demektir (web CSS
      + `lang="tr"` ile doğrusunu basıyor, yan yana koyunca ayrışır).
- [ ] **ATLAMA YOK.** Beş sayfanın HİÇBİRİNDE "Atla" (ya da başka bir
      geçme/kapatma) düğmesi olmamalı — tanıtımın tek çıkışı son
      sayfadaki **HEMEN OYNA**. (19 Ağustos 2026 kullanıcı kararı.)
- [ ] **"HEMEN OYNA" Setup'a düşürüyor** ve tanıtım **bir daha ASLA
      çıkmıyor** — uygulamayı tamamen kapatıp yeniden aç, doğrudan Setup
      gelmeli. (Bayrak yazılmıyorsa tanıtım her açılışta çıkar; bu
      maddenin asıl ölçtüğü şey o.)
- [ ] **Setup'ın logo altındaki "Tanıtım" linki her zaman açıyor**
      ("Nasıl oynanır? · Tanıtım" satırı). Açıp kapattıktan SONRA
      uygulamayı yeniden başlat — tanıtım yine ÇIKMAMALI (bu yol bayrağa
      dokunmaz).
- [ ] **O satır YALNIZCA MİSAFİRDE var** — giriş yaptıktan sonra logo
      altındaki paragraf ve link satırı hiç çizilmiyor, yani girişli
      kullanıcının tanıtıma dönüş yolu YOK. Bu bilinçli ve web ile
      PARİTE (orada `<` düğmesi de yalnızca girişsizde çiziliyor).
- [ ] **Hesap menüsünde "Tanıtım" maddesi YOK** — 19 Ağustos 2026'da
      oradan kaldırılıp Setup'ın link satırına taşındı.
- [ ] **Footer üç madde + telif:** `Kullanım Koşulları · Gizlilik
      Politikası · Paylaş` (aralarında iki `·`) ve HEMEN ALTINDA
      "© Kelimeki" — telif satırı ORTALI olmalı, sola yapışmamalı
      (19 Ağustos 2026'da öyleydi: `textAlign` unutulmuştu).
      **"Paylaş" MİSAFİRDE DE görünmeli** (web'de de
      girişten bağımsız) ve dokununca sistem paylaş sayfasını
      `?ref=arkadas` linkiyle açmalı.
- [ ] **Setup başlığında ok/geri düğmesi YOK** — bu bilinçli bir ayrışma
      (web'de `<` var). Bkz. mobile/CLAUDE.md "Karşılama Katmanı".
- [ ] **Görsel:** 2. ve 3. sayfadaki 5×5 mini ızgaralar renkli çiziliyor
      (boş/bonus/merkez + iki oyuncu rengi); son sayfadaki dokuz mührün
      harfleri (Ç M O U Ş D E Z T) TOFU (boş kare) DEĞİL — mühür fontu
      ayrı bir alt küme, eksik glyph riski gerçek (bkz. Parça 114).
- [ ] **Dar ekran (320-360 px):** 2. slayttaki dört rakam kutusunun
      metinleri küçülerek sığmalı ("Ücretsiz" dahil; kutular Parça 119'da
      1. slayttan buraya taşındı), altı özellik kutusu ve dokuz
      rütbe kutusu kırpılmamalı; sarı-siyah "RenderFlex overflowed"
      çubuğu HİÇBİR slaytta GÖRÜNMEMELİ.
- [ ] **Yatay taşma yok:** beş slaydın hiçbirinde sağa/sola kaydırma
      oluşmamalı (tahta slaydı dahil — o 680'lik kabıyla ekrandan geniş
      OLMAMALI, dar ekranda küçülmeli).

## 0.5 Web ile yan yana görsel karşılaştırma (Parça 56)

- [ ] **Setup'ta oyuncu satırında PUAN olmamalı (17 Ağustos 2026) — bu
      madde WEB'i sınıyor, portu değil.** GİRİŞLİ bir hesapla "Yapay Zeka
      ile" → "+ Yeni Yapay Zeka Oyunu" formunu aç: 1. koltuk satırında
      yalnızca ad görünmeli, yanında `Ironman (92)` gibi parantezli bir
      sayı OLMAMALI. **Portta bu gösterim zaten hiç yoktu**, yani madde
      aynı zamanda "iki taraf artık aynı" kontrolü. Sayı geri gelirse
      `Setup.tsx`'e `accountTotalScore` benzeri bir hesap geri konmuş
      demektir — o toplam k-lig ödüllerini (`bonus_points`) İÇERMEDİĞİNDEN
      gerçek puandan sapar (ölçülen fark 92 ↔ 97); doğru sayı hesap
      menüsündeki k-lig satırında (ayrıntı: kök `CLAUDE.md`, `Setup`).
- [ ] **Tahta ile raf arasındaki boşluk (17 Ağustos 2026) — bu madde
      WEB'i sınıyor, portu değil.** Bir oyunu iki platformda yan yana aç:
      tahta kartının ALTI ile raf kartının ÜSTÜ arasındaki mesafe aynı
      olmalı (ölçülen hedef **40px** = 4 + 30px'lik mesaj kutusu + 6).
      Web'de dar görünüyorsa mesaj satırının `min-h-[30px]`i düşmüş
      demektir — eski `min-h-[15px]` bağlayıcı değildi ve gerçek yükseklik
      20.5px'e düşüyordu. **İki satıra taşan uzun bir mesajda** (ör. çok
      kelimeli, vergi paylı bir hamle) web kutusu büyür, port `maxLines: 2`
      ile keser — o durumda küçük bir fark olması BEKLENEN.
- [ ] **Raf başlığı (17 Ağustos 2026) — üç şey birden.** İki platformu yan
      yana aç: (a) sağda **"7 harf" YAZMAMALI** (ikisinde de kaldırıldı);
      (b) oyuncunun adı **büyük harfe çevrilmemiş** olmalı (`Ironman`,
      `IRONMAN` değil) ve iki tarafta da aynı kalınlıkta görünmeli — ikisi
      de 700, fark yalnızca büyük harften geliyordu; (c) **ad ile taşların
      arası iki tarafta da aynı** (13px). **DEĞİŞTİR'e basıp iki taş seç:**
      sağda **"2 seçili" ÇIKMALI** — bu sayaç bilerek KALDI, çıkmıyorsa
      "7 harf"i kaldırırken fazlası silinmiş demektir. Seçili taş yukarı
      kalkarken **adın üstüne binmemeli** (web'e portun 7px'lik rezervi
      eklendi).
- [ ] **Rafın ALTINDAKİ buton satırı (17 Ağustos 2026, Parça 108) — bu madde
      PORTU sınıyor.** İki platformu yan yana aç: PAS GEÇ / DEĞİŞTİR /
      KARIŞTIR / GERİ AL / TORBA butonlarının **yazı boyu, harf aralığı ve
      YÜKSEKLİĞİ** aynı görünmeli; özellikle **TORBA ötekilerden uzun
      OLMAMALI** (13px'lik mavi sayaç satırı yükseltiyor, web flex ile
      hepsini eşitliyor). Butonlar arası boşluk ve **raf ↔ OYNA arası** da
      6px. **DEĞİŞTİR'e bas:** swap satırındaki DEĞİŞTİR ↔ VAZGEÇ boşluğu da
      6px olmalı (portta 8'di). Port butonları web'den **2px kısa kalabilir**
      — bu BİLİNÇLİ (web'in çerçevesi yer kaplıyor, portunki kaplamıyor).
- [ ] **Hesap Ayarları: "FOTOĞRAF DEĞİŞTİR" butonu (17 Ağustos 2026) — bu
      madde WEB'i sınıyor, portu değil.** Hesap menüsü → Hesap Ayarları'nı
      iki platformda yan yana aç: buton avatarın sağındaki BOŞLUĞUN
      TAMAMINI doldurmalı (sağ kenarı, altındaki "JPG/PNG, en fazla 10 MB"
      satırının hizaladığı sağ kenarla aynı), yazısı ortada **ve KALIN**
      (iki tarafta da 700). Web'de içeriğine göre daralıyorsa
      `w-full`/`flex-1`, ince görünüyorsa `font-bold` düşmüş demektir.
- [ ] **Filigranlar taşların ÜSTÜNE binmemeli (17 Ağustos 2026, Parça
      107).** Köşe bölgesine ve merkezdeki X2 bölgesine taş konmuş bir oyun
      aç: soluk köşe rakamı ve **X2** yalnızca BOŞ hücrelerde görünmeli,
      taşların üzerinden GEÇMEMELİ (web'de taşlar `z-[5]` ile filigranın
      üstünde). Bölge/hamle dış hatları ise filigranın ÜSTÜNDE kalmalı
      (web `z-10`). **Sürüklerken de bak:** bir taslak taşı parmakla
      kaldırdığında kaynak hücre boş çizilir, o hücrede filigran GÖRÜNMELİ.
- [ ] **Tahta filigranları (17 Ağustos 2026, Parça 106).** Bir oyun aç ve
      tahtayı iki platformda yan yana koy: (a) köşelerdeki soluk oyuncu
      RAKAMLARI aynı büyüklükte ve aynı yazı tipinde (Space Mono) olmalı —
      app'te belirgin KÜÇÜK görünüyorsa punto yine kutuya sığdırılıyor
      demektir; (b) merkezdeki büyük **X2** filigranı aynı büyüklükte
      olmalı (eskiden app'te BÜYÜKTÜ); (c) tam ortadaki turuncu hücrenin
      **X3** etiketi hücreyi DOLDURMAMALI, web'deki gibi küçük kalmalı
      (azami 12px — app'te eskiden ~37px, üç katıydı). Fark yalnızca
      punto/font; renk ve saydamlık zaten aynıydı. **Geniş bir ekranda
      (iPad) bak** — üç formül de `clamp` tavanına orada oturuyor.
- [ ] **Header'da avatarın dikey hizası (17 Ağustos 2026, Parça 106) —
      bu madde WEB'i sınıyor, portu değil.** Profil FOTOĞRAFI olan bir
      hesapla oyun ekranını iki platformda aç: sağ üstteki avatarın dikey
      merkezi, yanındaki skor kutularının merkeziyle aynı hizada olmalı.
      Web'de 3.5px yukarıda duruyorsa `UserMenu`'deki butondan `flex`
      düşmüş demektir. **Baş harfli (fotoğrafsız) bir hesapla test etmek
      bu hatayı GÖSTERMEZ** — sapma yalnızca `<img>` avatarda oluşuyor.
- [ ] **İçerik sütunu genişliği (13 Ağustos 2026, Parça 72).** GENİŞ bir
      ekranda (iPad yatay) Setup'ı iki platformda yan yana aç: "YAPAY ZEKA
      İLE"/"ARKADAŞINLA" butonlarının ve "OYUNU BAŞLAT"ın genişliği
      BİREBİR aynı olmalı. Web `max-w-[460px] px-4` bir border-box, yani
      içerik **428** — app daha geniş görünüyorsa dolgu yine kutunun
      dışına kaçmıştır. (Dar ekranda ikisi zaten aynı; fark yalnızca
      460+32'den geniş ekranlarda ortaya çıkar, o yüzden telefonda test
      etmek bu hatayı GÖSTERMEZ.)
- [ ] **GİRİŞ satırının konumu (13 Ağustos 2026, Parça 73 + 76).** Sağ
      üstteki GİRİŞ/avatar butonunun ÜSTÜNDEKİ boşluk web'le aynı olmalı
      (**12**); butonla logo ARASI ise **4**. App'te buton web'dekinden
      aşağıda duruyorsa dikey dolgu yine simetrik verilmiş demektir —
      web'de bu satır Setup içeriğinden AYRI bir kutu (üst 12), logo
      bloğu da `-mt-5` ile kabın `py-6`sının 20'sini geri alıyor. Aradaki
      4, kullanıcının portu tercih ettiği tek yer: **web porta uyduruldu**,
      yani burada web 12 görünüyorsa `-mt-5` geri alınmış demektir.
- [ ] **Logo altındaki yazı bloğu (13 Ağustos 2026, Parça 77).** Geniş bir
      ekranda iki platformu yan yana aç: tanıtım paragrafı İKİSİNDE de
      **4 satır** olmalı ve satır sonları aynı yerde kırılmalı (ilk satır
      "… kuşat. Ama" ile bitiyor). App'te 5 satıra düşüyorsa Material 3'ün
      0.25 harf aralığı yine sızmış demektir — aynı kontrol "Nasıl
      oynanır? · Arkadaşınla paylaş" satırının genişliği için de geçerli.
- [ ] **Harf aralığı: hiçbir metin web'den geniş DEĞİL (13 Ağustos 2026,
      Parça 78).** Material 3'ün 0.25 tracking'i tema seviyesinde
      kapatıldı; bu TÜM ekranların metin genişliğini ~%1-2 daraltıyor.
      Bölüm 0.5'i koşarken her ekrana bir kez bak: bir yerde satır sonu
      web'den farklı kırılıyor ya da bir etiket kutusuna sığmıyorsa not al
      (testler geometriyi doğruluyor ama her ekranı gözle kontrol
      edemiyor).
- [ ] **"+ Yeni …" butonu ve alt sekmeler (13 Ağustos 2026, Parça 80).**
      Her iki sekmede de (Yapay Zeka ile / Arkadaşınla) turuncu butonun
      yüksekliği ve altındaki sekme satırıyla arasındaki boşluk web ile
      aynı olmalı; sekmelerin kendi arası da web'deki kadar. Port
      12/6/12 kullanıyordu, web 20/8/20.
- [ ] **Form alanları (13 Ağustos 2026, Parça 79).** Giriş/kayıt, Hesap
      Ayarları, Görüş Bildir, arkadaş arama, sohbet ve şikayet kutuları —
      hepsi AYNI görünmeli: 38px yükseklik, 16 punto, 12px yatay dolgu,
      odakta mavi çerçeve. Çok satırlı olanlarda (sohbet/şikayet) da aynı
      dolgu/çerçeve geçerli. Klavye açıkken metnin kutuya dikey ortalı
      durduğunu da kontrol et.
- [ ] **Arkadaş onay/bilgi diyalogları.** "Arkadaşlıktan çıkar" gibi bir
      onay diyaloğu aç: kart genişliği ve iç dolgusu web ile aynı olmalı
      (384 kutu, 24 dolgu → içerik 336).
- [ ] **Modal başlığı: ✕ sağa dayalı (12 Ağustos 2026, Parça 71).** Skor
      Kartı'nı iki platformda yan yana aç: ✕ kartın sağ kenarına aynı
      uzaklıkta olmalı ve rütbe mührü kartın ORTASINDA değil, **başlık ile
      ✕ arasının** ortasında durmalı. (Portta ✕ 40px'lik bir dokunma
      hedefi taşıdığından buton kutusu web'inkinden büyük — bakılacak şey
      GLYPH'in konumu.)
- [ ] **Modal yüksekliği farkı web test derlemesinde NORMAL.** Skor
      Kartı'nın altındaki "TÜM GEÇMİŞ OYUNLAR" linki web'de görünüp
      mobilde kesiliyorsa bu bir hata DEĞİL: iOS Safari'de CSS `vh`
      tarayıcı çubuklarının altını da sayar, Flutter ise yalnızca görünür
      alanı görür. **Native'de kesilme olmamalı** — FAZ B'de doğrula:
      iPad yatay/dikey ve iPhone dikeyde modal, içeriğin tamamını
      kaydırmasız göstermeli.

Bu bölümü bir kez, iki sekmeyi (kelimeki.com ve alpcapa.github.io) AYNI
hesapla açıp yan yana koyarak koş.

- [ ] **Kartlar ve sekmeler "kabarık" görünmeli, düz DEĞİL.** Canlı oyun
      kartları, davet kartları, "Son Oynadıklarım" satırları, Setup'taki
      Devam Eden Oyun ve oyuncu satırları, skor kartındaki istatistik
      kutuları, oyun geçmişi kartları ve TÜM alt sekme çubukları (Devam
      Edenler/Oyun Davetleri/Son Oynananlar; Genel/2/4) web'deki gibi
      yumuşak gölge taşımalı. Düz/kağıt gibi duruyorsa regresyon.
- [ ] **Tahta ↔ mesaj ↔ raf boşlukları (Parça 57).** Oyun ekranında
      tahtanın alt kenarı ile mesaj satırı arasında, ve mesaj ile raf
      arasında web'dekiyle aynı nefes payı olmalı. Tahta mesaja YAPIŞIK
      duruyorsa regresyon (11 Ağustos 2026'ya kadar tam olarak öyleydi).
      Hem YZ hem Canlı oyun ekranında kontrol et — ikisi ayrı dosya.
- [ ] **Setup başlık bloğu.** Logo ile paragraf arası ve paragraf ile
      "Nasıl oynanır? · Arkadaşınla paylaş" satırı arası web'le aynı
      olmalı; paragraf 4 satır sürüyorsa satır aralığı da aynı görünmeli
      (portta daha ferah duruyorsa regresyon).
- [ ] **Setup'ın en altı.** "Kullanım Koşulları · Gizlilik Politikası"
      görünmeli ve ikisi de ilgili modalı açmalı. (Altındaki `Sürüm … ·
      depo ok` teşhis satırı BİLİNÇLİ olarak yalnızca app'te var.)
- [ ] **Arkadaşlar modalı.** Üç sekmenin (Arkadaşlarım/İstekler/Ara &
      Ekle) puntosu ve "Arkadaşını Davet Et"in altındaki küçük butonların
      boyu web'le aynı olmalı.

## 1. Oyun (offline çekirdek)

Bu bölüm anahtarsız da koşulabilir; sunucuyla ilgisi yok.

- [ ] **2 kişilik oyun.** Kurulum → Oyunu Başlat → köşeden kelime kur →
      OYNA. Puan artmalı, YZ kendi turunu oynamalı. **Kendi hamlenin mesaj
      satırı ("Misafir: +N puan Kelimeler: …") YZ oynamadan ÖNCE en az ~1
      saniye görünür kalmalı** — YZ'nin kendi mesajıyla ANINDA üstüne
      yazması bir regresyon (8 Ağustos 2026'da bulundu: web'in `AI_THINK_MS`
      gecikmesi ilk portta hiç taşınmamıştı, YZ bir sonraki event-loop
      turunda [≈0 ms] oynuyordu — kullanıcı kendi hamlesinin mesajını hiç
      göremiyordu; düzeltme + enjekte edilebilir `aiThinkDelay`, bkz.
      mobile/CLAUDE.md Parça 21).
- [ ] **"Kalan Taşlar" (TORBA) bekleyen taşları rakibe yazmamalı
      (18 Ağustos 2026, Parça 112).** TORBA'ya dokun ve "toplam N taş
      dışarıda" sayısını not al; sonra tahtaya birkaç taş koy ama OYNA'ya
      **basma**, TORBA'yı tekrar aç — sayı **DEĞİŞMEMELİ** (her bekleyen taş
      için 1 artıyorsa hata geri gelmiş). Joker eşi: jokeri bir harfe çevirip
      masaya koy → o harfin sayısı artmamalı. **Asıl değişmez oyun sonunda:**
      torba boşken son hamleni onaylamadan dökümün toplam PUANINI hesapla,
      OYNA'ya bas → bitiş kartında rakibin negatif sayısı birebir aynı olmalı.
      Web'de de aynı oyunu koş — iki taraf aynı sayıyı vermeli.
- [ ] **Bingo bonusu mesajda yazıyor (17 Ağustos 2026).** Rafın 7 taşını
      birden koyup OYNA → mesaj satırında `(Bingo bonusu +25)`. **YZ'nin
      bingo'sunda da yazmalı** (`Yapay Zeka 2 "…" oynadı. +N puan.
      (Bingo bonusu +25)`) — ayrı bir şablon. Canlı oyundaki karşılığı
      bölüm 11'de, orası ÜÇÜNCÜ bir kod yolu (mesaj `online_game_moves`
      satırlarından yeniden üretiliyor). Negatif eş: sıradan bir hamlede
      bu parantez görünmemeli. Web'de AYNI hamleyi yap — metin birebir
      aynı olmalı.
- [ ] **Sağ-alttaki YZ artık ilk hamlede kısıtlı değil (17 Ağustos 2026,
      Parça 109).** 2 kişilik bir oyun aç (YZ her zaman sağ-alt köşededir)
      ve YZ'nin İLK hamlesine bak: kelime, ev karesinden (12,12) SOLA
      ve/veya YUKARI, yani merkeze doğru uzayabilmeli. Eskiden YZ orada
      en fazla 4 taş koyabiliyordu ve neredeyse hep sonuncu bitiriyordu.
      **Bu tek bir oyunda kanıtlanmaz** (rafa bağlı) — birkaç oyun oyna ve
      YZ'nin açılış puanlarının 2 kişilikte (köşe 3) ile 4 kişilikte
      (köşe 0/1/2 de var) belirgin şekilde ayrışMADIĞINA bak. Negatif eş:
      YZ'nin ilk kelimesi HER ZAMAN evden sağa/aşağı gidiyorsa düzeltme
      deploy olmamış demektir (derleme sha'sını kontrol et).
- [ ] **Girişsiz başlatınca uyarı (14 Ağustos 2026, Parça 92).** ÇIKIŞ
      yapmış hâlde "Oyunu Başlat"a bas: web'dekiyle aynı uyarı çıkmalı
      ("Oyunların istatistikleri, k-lig ve arkadaşınla canlı oyun için
      lütfen giriş yapın." + GİRİŞ YAP / **OYNA**). **Üç yolu da dene:**
      OYNA → oyun başlar; GİRİŞ YAP → giriş penceresi açılır ve oyun
      BAŞLAMAZ; ✕ (ya da zemine dokunma) → hiçbir şey olmaz. Girişliyken
      bu uyarı HİÇ çıkmamalı. **Butonun metni 18 Ağustos 2026'da "DEVAM"dan
      "OYNA"ya çevrildi** (kullanıcı: uyarı metni üyeliği anlattığından
      "Devam" üyeliğe götürecekmiş gibi okunuyordu) — ekranda "DEVAM"
      görüyorsan derleme bayat demektir, sha'yı kontrol et. Web'de de aynı
      etiket; ikisi birlikte değişmeli.
- [ ] **Tahta alt şeridi — "Nasıl Oynanır?" (aynı parça).** Tahtanın
      altında SAĞDA "Nasıl Oynanır?" olmalı; eski `- kelime X2 · -
      kelime X3` açıklaması HİÇBİR yerde görünmemeli. Dokununca kurallar
      açılmalı — hem yerel/YZ hem Canlı oyun ekranında ayrı ayrı dene.
      Yazı stili solundaki "Hamleler" ile birebir aynı olmalı (punto/
      renk/kalınlık) ve soru-işareti ikonu boş kare DEĞİL gerçek bir
      daire+soru işareti olarak çizilmeli.
- [ ] **Sürükle-bırak.** Raftan tahtaya, tahtada taşıma, tahtadan rafa geri
      alma. Hayalet taş parmağın ÜSTÜNDE görünmeli (30px kaldırma).
      **Sürükleme AKICI olmalı — hafif titreme/takılma bir REGRESYONDUR**
      (8 Ağustos 2026'da kullanıcı iPad Safari'de bunu bizzat bildirdi; kök
      sebep `BoardWidget`'ın (169 hücre + territory hesabı) HER pointer
      hareketinde sıfırdan yeniden inşa edilmesiydi — ölçüm: 30 pointer-move
      → 30/30 rebuild, adım başı ~38-40ms; düzeltme sonrası (bu ortamda
      native VM/Skia'da doğrulandı) 0 rebuild — bkz. mobile/CLAUDE.md
      Parça 23). Bu ortamda gerçek cihaz/CanvasKit performansı ÖLÇÜLEMEDİ,
      yalnızca burada cihazda teyit edilebilir — sürüklerken parmağı yavaşça
      tahtanın bir ucundan diğerine gezdir, hayalet taş + kesikli hedef
      çerçevesi pürüzsüz takip etmeli.
- [ ] **Tahtadan rafa sürüklerken hayalet taş board sınırını geçerken
      KAYBOLMAMALI.** Bir taşı tahtaya koy, sonra sürükleyerek rafa geri al
      — parmağını board'un alt kenarından mesaj satırı/rafa doğru
      GEZDİRİRKEN hayalet taş yolun HİÇBİR noktasında görünmez olmamalı,
      rafa varana kadar sürekli görünür kalmalı (8 Ağustos 2026'da
      kullanıcı bunu bizzat bildirdi: "board sınırını geçerken kayboluyor,
      taş rafa dönüyor ama görünmüyor" — kök sebep `_hoverHighlight`'ın
      board dışında çıplak `SizedBox.shrink()` döndürmesiydi, bu da onu
      saran overlay Stack'i 0×0'a küçültüp hayalet taşı kırpıyordu; hem
      native Skia hem gerçek CanvasKit'te (Playwright/Chromium web
      harness) ölçülerek doğrulandı, düzeltildi — bkz. mobile/CLAUDE.md
      Parça 27). Aynı kontrol Canlı oyun ekranında da geçerli
      (`OnlineGameScreen`, birebir aynı düzeltme).
- [ ] **Joker.** Jokeri tahtaya koy → harf seçici açılmalı; konmuş jokere
      tekrar dokun → seçici "Geri Al" seçenekli açılmalı, taş geri
      ALINMAMALI (dokunma ile sürükleme farklı davranır). **Seçici hiçbir
      zaman ekranın altından taşmamalı/kesilmemeli** — tüm harfler (A'dan
      Z'ye) görünür ya da kaydırılarak erişilebilir olmalı; özellikle
      YATAY modda ya da kısa yüksekliğe sahip ekranlarda kontrol et (8
      Ağustos 2026'da bir kullanıcı bunu iPad yatay modda kesik gördü —
      `showModalBottomSheet`'in eksik `isScrollControlled` parametresi
      yüzünden, bkz. mobile/CLAUDE.md Parça 20).
- [ ] **Tahta taşı harf/puan puntosu ekran genişliğine göre değişmeli.**
      Web'deki gibi geniş bir ekranda (tablet/iPad — dikey ya da yatay
      fark etmez, viewport genişliği >631px olduğu sürece) harfler daha
      BÜYÜK, dar bir telefon ekranında daha KÜÇÜK görünmeli — sabit bir
      boyutta KALMAMALI. Aynı cihazı döndürüp (dikey↔yatay) harflerin
      boyutunun da değiştiğini gözle doğrula (8 Ağustos 2026'da kullanıcı
      web/app ekran görüntüsü karşılaştırmasıyla bulundu — iPad'de web
      24px'e kilitlenirken port sabit 20px kullanıyordu; düzeltme + kaynak
      kodun `vw`-tabanlı `clamp()` formülüne bağlanması, bkz.
      mobile/CLAUDE.md Parça 24). Raf taşlarının harfi bundan ETKİLENMEMELİ
      — orada web'de de sabit boyut var.
- [ ] **Taş değiştirme / pas.** İkisi de sırayı ilerletmeli; pas onay
      sorusu çıkmalı — başlık "Pas Geçiyorsun!", gövde "Pas geçmek
      istediğinden emin misin? Sıran diğer oyuncuya geçer." (web ile
      birebir), kabul butonu (PAS GEÇ/OYNA) SOLDA, VAZGEÇ SAĞDA — 8 Ağustos
      2026'da `game_screen.dart`'ta bu metin bayat, buton sırası da (bu
      ekranla Canlı oyun ekranının İKİSİNDE) ters çıkmıştı, bkz.
      mobile/CLAUDE.md Parça 25.
- [ ] **Bölge vergisi.** Rakip bölgesine değen bir hamlede "Sınır İhlali!"
      onayı çıkmalı (kabul butonu solda, VAZGEÇ sağda), kabul edilince
      puan bölünmeli. **Metin VURGULU olmalı (Parça 55):** kazanacağın
      puan yeşil+kalın, her rakibe giden pay kırmızı+kalın, rakibin adı
      yalnızca kalın (renksiz) — düz tek renk metinse regresyon.
- [ ] **Kelime anlamı.** Tahtadaki ONAYLANMIŞ (Oyna ile kesinleşmiş) bir
      taşa dokun → o hücreden geçen yatay/dikey kelimelerin anlam modalı
      (yerel SQLite asset'ten) açılmalı — tetikleyici Hamle Geçmişi
      DEĞİL, doğrudan tahta (`game_screen.dart` `_handleCellTap`'in ilk
      dalı; web'de de aynı — `MoveHistoryModal.tsx`'te hiçbir anlam
      tetikleyicisi yok, tetikleyici `App.tsx`'in `handleCellClick`'i).
- [ ] **Oyun bitince "TEKRAR OYNA" (Parça 60).** Bir YZ oyununu sonuna
      kadar bitir: buton "TEKRAR OYNA" olmalı ("YENİ OYUN AÇ" DEĞİL). Dokun →
      onay ("… kişilik, Yapay Zeka'ya karşı yeni bir oyun başlatılacak. Emin
      misin?"). VAZGEÇ hiçbir şey yapmamalı; onayla → Setup'a UĞRAMADAN aynı
      kadroyla taze bir oyun açılmalı (skorlar 0, buton yine OYNA).
- [ ] **İki oyun ART ARDA — kayıt kaybı regresyonu (Parça 60).** Yukarıdaki
      akışla aynı ekranda İKİ oyunu üst üste bitir (aradan Setup'a çıkma).
      Skor Kartı → "Tüm Oyunlarım"da **İKİSİ de** görünmeli ve k-lig puanı
      ikisini de saymalı. Yalnızca ilki görünüyorsa kayıt bayrağı yeni
      oyunda sıfırlanmıyor demektir.
- [ ] **Oyun sonu.** Torba+raf bitince sonuç ekranı; sıralama ve kalan taş
      düşümü doğru. **GameOver modalı web'deki gibi küçük/kare bir kart
      olmalı** — sabit ~360px genişlik, hiçbir bottom "KAPAT" düğmesi
      YOK, tek kapatma yolu sağ üstteki ✕ (8 Ağustos 2026'da bir kullanıcı
      cihazda bunun geniş bir Dialog olarak ve altta metin bir "KAPAT"
      düğmesiyle render olduğunu bildirdi — modal ortak `KModal` kabuğuna
      taşınmadan kendi ham `Dialog`'unu kuruyordu, bkz. mobile/CLAUDE.md
      Parça 26).
- [ ] **Oyun sonu kartında k-lig sütunu + kırpılan ad (Parça 120).**
      Başlıklar soldan sağa **KALAN · TOPLAM · k-lig**; kazananın k-lig
      hücresi **+2**, 2 kişilikte ikinci **-**. Teslim olan satırda **-2**
      k-lig sütununda olmalı (KALAN'da DEĞİL). 4 kişilik bir oyunda
      "Yapay Zeka 1" gibi uzun adlar satırı sarmadan `…` ile kırpılmalı,
      kart hiçbir genişlikte taşmamalı; alttaki hamle sayısı etiketin
      yanında/ortalı olmalı. Ayrıca **üç sütunun sayısı da kolonun SAĞINA
      yapışık** olmalı: k-lig'in `-` gösterdiği ve skorun 2 haneli olduğu bir
      satırda skor ORTALI durmamalı (21 Ağustos düzeltmesi). **Web ile yan
      yana bak** — sayılar iki tarafta ELLE senkron; başlıkların harf aralığı
      da (0.225) aynı olmalı, port eskiden 0.5 kullanıp daha genişti.
- [ ] **Oyun sonu butonu BÜYÜR (Parça 50).** Oyun bitince raf satırındaki
      mavi buton "YENİ OYUN AÇ" olmalı: **tek satır** ve OYNA'dan belirgin
      **daha büyük punto** (web `text-[15px]` ↔ OYNA `text-[12px]`); raf
      buna göre daralır, özellikle rafta 1-2 taş kalınca buton dikkat
      çekici olur. İki satıra bölünmüş küçük bir "YENİ / OYUN" görüyorsan
      parite bozulmuş demektir. Canlı oyunda karşılığı "CANLI LİSTESİ",
      aynı kural.
- [ ] **Kalan Taşlar dökümü küçük kalmalı (Parça 50).** TORBA'ya dokun →
      açılan kart web'deki gibi **~360px** olmalı, taşlar küçük ve 5
      sütun; iPad'de kart ekrana yayılıp taşlar devleşiyorsa parite
      bozulmuş demektir. Başlık **"KALAN TAŞLAR"** (büyük harf).
- [ ] **TORBA sayacı ayrı stilli.** Alt buton satırındaki "TORBA N"
      etiketinde YALNIZCA sayı (N) daha büyük punto + mavi (`#2563EB`)
      olmalı, "TORBA" kelimesi düğmenin normal (siyah/beyaz, duruma göre)
      rengini korumalı — ikisi aynı renk/puntoda görünüyorsa web
      paritesi bozulmuş demektir (8 Ağustos 2026'da kullanıcı bildirdi,
      bkz. mobile/CLAUDE.md Parça 26). Hem yerel/YZ oyun ekranında hem
      Canlı oyun ekranında kontrol et — ikisi de aynı düğmeyi kullanıyor.
- [ ] **Kalıcılık.** Oyun ortasında uygulamayı TAMAMEN kapat, yeniden aç →
      "Devam Eden Oyun" satırı görünmeli, dokununca aynı tahta/raf/tur ile
      devam etmeli. **Avatar şeridi web ile aynı görünmeli** — misafirin
      "?" avatarı ve YZ koltuklarının robot avatarı ikisi de MAVİ zeminde
      olmalı (gri/nötr DEĞİL), YZ robotu gerçek 🤖 emoji olmalı (kutu/farklı
      bir ikon DEĞİL) — kelimeki.com'daki aynı satırla yan yana karşılaştır
      (8 Ağustos 2026'da bir kullanıcı iki ekran görüntüsünü kıyaslayınca
      bulundu, bkz. mobile/CLAUDE.md Parça 22). **GitHub Pages web test
      derlemesinde robot emoji BOŞ/soluk bir daire olarak görünürse bu
      muhtemelen bir kod hatası DEĞİL** — Flutter Web/CanvasKit renkli
      emoji'yi çalışma anında `fonts.gstatic.com`'dan çekiyor, bu istek
      yavaş/kesintili olursa emoji hiç çizilmiyor (9 Ağustos 2026'da
      ölçülerek doğrulandı, bkz. mobile/CLAUDE.md Parça 29) — gerçek
      native build (TestFlight/Appetize) bu ağ bağımlılığını hiç
      taşımaz, kesin doğrulama orada yapılmalı.

## 2. Hesap (auth)

- [ ] **Hesap menüsünün görünümü web'le birebir (9 Ağustos 2026, Parça 30).**
      Girişliyken avatara dokun: isim/k-lig başlığının HEMEN ALTINDA (yani
      "Arkadaşlar"ın ÜSTÜNDE) ince bir yatay çizgi olmalı — web'in
      `border-b`si. Satırlar (Arkadaşlar/Skor Kartı/Nasıl Oynanır?/Hesap
      Ayarları) web kadar sık/kompakt görünmeli, hiçbiri iki satıra
      sarmamalı ("Nasıl Oynanır?"/"Hesap Ayarları" özellikle kontrol et —
      emoji glyph'i satırı taşırıp ikiye bölebiliyordu). Çıkış Yap'ın
      üstündeki çizgi de ince bir kenar çizgisi olmalı, 16px'lik AYRI bir
      boş satır DEĞİL. Menünün en üstünde (başlığın üstünde)/en altında
      (Çıkış Yap'ın altında) görünmez bir boşluk OLMAMALI — kelimeki.com'da
      aynı hesabın menüsüyle yan yana karşılaştır. **Avatara UZUN BASINCA
      hiçbir ipucu balonu çıkmamalı (9 Ağustos 2026, Parça 41 — kullanıcı
      isteğiyle kaldırıldı):** ne Türkçe "Hesap menüsü" ne İngilizce
      "Show menu"; İngilizcesi çıkıyorsa `tooltip: ''` yerine parametre
      tamamen silinmiş demektir (Flutter o durumda kendi varsayılanına
      düşüyor).
- [ ] **Avatarın vurgusu YUVARLAK (13 Ağustos 2026, Parça 81).** Avatarın
      üzerine trackpad/fare ile gel ve ayrıca bas: beliren gri vurgu
      avatarın dairesini izlemeli — yuvarlak avatarın DIŞINDA kare köşeler
      GÖRÜNMEMELİ. (Kök sebep: `PopupMenuButton`'ın `borderRadius`
      varsayılanı yok, null bırakılınca ink dikdörtgen boyanıyordu;
      ölçülen fark basılıyken daire dışında 120 → 0 piksel.) Web'de bu
      butonun hiç zemin vurgusu yok, yalnızca basınca hafif küçülüyor —
      portta dairesel bir vurgu OLMASI bilinçli bir fark, kare köşe ise
      hata.
- [ ] **Misafir üyelik kutusu.** Setup ekranını misafir (girişsiz) olarak
      aç — hem boş kurulum formunun altında hem (bir oyun yarıda bırakılıp
      "Devam Eden Oyun" görünümüne düşünce) o görünümün altında "Neden
      Ücretsiz Üye Olmalıyım?" kutusu görünmeli: 6 madde (yeşil ✓ ikonlu,
      web'le birebir aynı sıra/metin) + "GİRİŞ YAP / KAYIT OL" butonu.
      Butona dokununca giriş/kayıt modalı açılmalı. Giriş yapılmışken bu
      kutu hiçbir yerde görünmemeli.
- [ ] **Kayıt.** Yeni bir e-postayla kayıt ol. Takma isim alanı boşluk
      kabul etmemeli; kullanılan bir takma isim yazınca "Bu takma isim
      kullanımda." uyarısı çıkmalı ("✓ Kullanılabilir" satırının yanında
      onay ikonu görünmeli — ✓ karakteri gömülü yazı tiplerinde yok, ikon
      kullanılıyor).
- [ ] **Profil gerçekten kuruldu.** Kayıt sonrası web'e AYNI hesapla gir:
      Hesap Ayarları'nda ad/soyad/takma isim/cinsiyet/doğum tarihi dolu
      olmalı. (Bunları `handle_new_user` trigger'ı yazıyor — mobilin
      metadata'yı doğru gönderdiğinin tek kanıtı bu.)
- [ ] **Pazarlama onayı.** Kayıtta işaretlediysen web'de Hesap
      Ayarları'ndaki kutu işaretli ve altında kabul tarihi görünmeli.
- [ ] **Giriş/çıkış.** Çıkış yapınca hesap özellikleri gizlenmeli; tekrar
      giriş yapınca geri gelmeli.
- [ ] **Oturum kalıcılığı.** Uygulamayı tamamen kapatıp aç — hâlâ girişli
      olmalı (token yenileme `supabase_flutter`'ın kendi deposunda).
- [ ] **Yanlış şifre.** Türkçe hata mesajı gelmeli, ham İngilizce
      ("Invalid login credentials") DEĞİL.
- [ ] **Kullanım Koşulları / Gizlilik.** Kayıt formundaki linkler açılmalı,
      metin web'dekiyle aynı olmalı.
- [ ] **Şifre sıfırlama — ÖN KOŞUL (tek seferlik el işi):** Supabase
      Dashboard → Authentication → URL Configuration → Redirect URLs
      listesine `kelimeki://reset` eklenmiş olmalı. Eklenmeden test etme:
      GoTrue izinsiz redirect'i sessizce Site URL'e (web'e) düşürür,
      bağlantı uygulamayı hiç açmaz — bu bir uygulama hatası DEĞİLDİR.
      **Aşağıdaki üç madde (sıcak/soğuk başlangıç, süresi geçmiş bağlantı)
      GitHub Pages web test ortamından (`alpcapa.github.io`) TEST
      EDİLEMEZ** (9 Ağustos 2026'da denenip doğrulandı) — `kelimeki://`
      özel URL şeması yalnızca GERÇEK kurulu bir native uygulama varken
      (TestFlight ya da Appetize.io'ya yüklenmiş bir `.ipa`/`.apk`)
      işletim sistemi tarafından yakalanabilir; düz bir web sayfası bunu
      hiçbir zaman intercept edemez. Web test ortamında bağlantıya
      dokununca "Safari cannot open the page because the address is
      invalid" görülür (sıcak/soğuk başlangıç için beklenen, bir hata
      DEĞİL) — süresi geçmiş bağlantıda ise Supabase sessizce web'in
      kendi (kelimeki.com) fallback'ine düşer, bu da web'in KENDİ
      davranışıdır, mobil uygulamanın değil. Bu üçü FAZ B'de (TestFlight/
      Appetize) gerçek bir kurulu uygulamayla koşulmalı — bkz.
      mobile/CLAUDE.md Parça 28.
- [ ] **Şifre sıfırlama — sıcak başlangıç.** Giriş penceresi → "Şifremi
      unuttum" → e-posta gir → "BAĞLANTI GÖNDER" → altın renkli "Şifre
      sıfırlama bağlantısı e-postana gönderildi." çıkmalı. Uygulama AÇIKKEN
      e-postadaki bağlantıya dokun: uygulama öne gelmeli ve her şeyin
      önünde "Yeni Şifre Belirle" penceresi açılmalı. Yeni şifreyi belirle
      → "Şifren başarıyla değiştirildi." → KAPAT → girişli olarak devam
      (recovery oturumu zaten açık). Eski şifreyle giriş artık reddedilmeli,
      yenisiyle çalışmalı.
- [ ] **Şifre sıfırlama — soğuk başlangıç.** Uygulamayı tamamen kapat,
      bağlantıya e-postadan dokun: uygulama açılıp aynı pencere gelmeli
      (PKCE code takası ilk URI'de de çalışıyor olmalı). ÖNEMLİ: bağlantıya
      sıfırlamayı İSTEYEN CİHAZDA dokunulmalı — PKCE verifier o cihazda
      saklı; başka cihazda açılırsa takas başarısız olur, bu beklenen
      davranıştır.
- [ ] **Süresi geçmiş bağlantı.** Eski bir sıfırlama e-postasındaki
      bağlantıya dokun: uygulama normal açılmalı ve KİLİTLENMEMELİ —
      sıfırlama penceresi ÇIKMAZ, görünür bir hata da yok (dönüş linki
      `error` parametresi taşır, supabase_flutter bunu akışa hata olarak
      verir, dinleyici yalnızca loglar; web de aynı durumda sessizce ana
      sayfaya düşüyor — bilinçli parite, ayrı bir hata ekranı eklenmedi).
      Kullanıcı yeni bir bağlantı isteyerek devam eder.
- [ ] **Web etkilenmedi.** Web'deki "Şifremi unuttum" akışı aynen çalışmalı
      (web `redirectTo` olarak kendi origin'ini göndermeye devam ediyor —
      mobil değişikliği yalnızca mobilin kendi isteğini etkiler).

## 3. Bulut kayıtları (web ↔ mobil aynı oyun)

Bu bölüm portun en kritik sözleşmesi: **aynı `local_game_saves` tablosu**.

- [ ] **Mobilde başla → webde sürdür.** Girişliyken mobilde bir YZ oyunu
      başlat, birkaç hamle yap, logoya basıp Setup'a dön. Web'de "Yapay
      Zeka ile" sekmesinde AYNI oyun "Devam Eden Oyunlar"da görünmeli ve
      aynı tahtayla açılmalı.
- [ ] **Webde başla → mobilde sürdür.** Tersi de çalışmalı.
- [ ] **Çoklu oyun.** Girişli kullanıcı aynı anda birden fazla YZ oyunu
      açabilmeli; liste hepsini göstermeli.
- [ ] **Hiç oynanmamış oyun iz bırakmamalı.** Yeni oyun aç, HİÇ hamle
      yapmadan logoya bas → listede kalmamalı (web'in `turnCount<2`
      kuralı). Sekme değiştirip geri dönünce de görünmemeli.
- [ ] **Misafir kaydının taşınması.** Çıkış yap, misafirken bir oyun
      başlat, birkaç hamle yap, Setup'a dön. Sonra giriş yap → oyun
      "Devam Eden Oyunlar"a taşınmalı ve **1. oyuncunun adı hesap adın**
      olmalı ("Misafir" DEĞİL).
- [ ] **Avatar şeridi.** Devam eden oyun satırında insan koltuğu senin
      avatarın/baş harflerin (fotoğraf yoksa MAVİ zeminde), YZ koltukları
      gerçek 🤖 emoji olmalı (Material ikonu/kutu DEĞİL); misafirken insan
      koltuğu MAVİ zeminde "?" olmalı (bkz. Bölüm 1'deki aynı kontrol).
- [ ] **Fotoğraflı avatarın çerçevesi HER YÖNDE eşit (9 Ağustos 2026,
      Parça 34).** Profil fotoğrafı olan bir avatara (hesap menüsü, Skor
      Kartı, oyun geçmişi…) yakından bak: ince gri çerçeve çepeçevre
      KESİNTİSİZ olmalı. Çerçevenin yalnızca üst/alt/sağ/sol'da görünüp
      köşegenlerde kaybolması (avatarın "dört kenarı düz" görünmesine yol
      açan eski hata) TEKRARLAMAMALI.
- [ ] **"Yükleniyor…" hiçbir koşulda TAKILI KALMAMALI (13 Ağustos 2026,
      Parça 75).** Girişliyken "Yapay Zeka ile" sekmesine geç: liste ya
      oyunlarını ya da "Devam eden bir Yapay Zeka oyunun yok." göstermeli.
      Kalıcı spinner bir yükleme yavaşlığı DEĞİL, senkronun bir adımının
      sessizce patladığı anlamına gelir — o durumda Setup'ın en altındaki
      teşhis satırını (`depo ok` / `DEPO YOK` / `bekleyen N`) not et.
      **`bekleyen ?` ile `bekleyen 0` AYNI ŞEY DEĞİL:** ilki "sayacı
      okuyamadım" (depo erişilemedi), ikincisi "gerçekten bekleyen yok" —
      hiç yazmaması da 0 demektir (16 Ağustos 2026'ya kadar ikisi de 0
      görünüyordu ve bir teşhis turu bu yüzden sonuçsuz kaldı).
      Hesabın hiç kaydı olmaması da geçerli bir test durumu (boş liste
      metni çıkmalı).

## 4. Biten oyun kayıtları ve istatistikler

- [ ] **"Oyun başladı" sayacı (Parça 121, 21 Ağustos 2026).** Mobilde bir
      YZ oyunu BAŞLAT, bitirmeden çık. Web'de admin panelinde Büyüme →
      Kullanıcı → Kaynak Hunisi'nde **`bilinmiyor`** satırının "Başlayan"
      değeri 1 artmalı — `direkt` DEĞİL. Port `?ref=`/anon kod damgası
      taşımadığından bu doğru davranış; `direkt`e düşüyorsa web'in gerçek
      doğrudan trafiği şişiyor demektir. "Oyun" sütunu (bitmiş oyun)
      DEĞİŞMEMELİ. Oyun sonu "Tekrar Oyna" da aynı şekilde 1 artırmalı.
- [ ] **Oyun bitir → webde gör.** Mobilde bir oyunu sonuna kadar oyna.
      Web'deki Skor Kartı'nda oyun sayısı artmalı, k-lig puanı doğru
      değişmeli (2 kişilikte 1.=+2, 2.=0).
- [ ] **Skor Kartı (mobil).** Üç sekme (Genel / 2 Oyunculu / 4 Oyunculu),
      "Oyuncu İstatistikleri" ve "Oyun İstatistikleri" blokları dolu
      gelmeli. Etiketler Türkçe büyük harfle doğru ("BİRİNCİLİK",
      "BIRINCILIK" değil).
- [ ] **Yüzdeler PARANTEZ içinde (9 Ağustos 2026, Parça 33).** Kutulardaki
      oran satırı web'deki gibi **"(%83)"** olmalı — parantezsiz "%83"
      DEĞİL.
- [ ] **Sekme çubuğu web ile aynı boyda (aynı parça).** "GENEL /
      2 OYUNCULU / 4 OYUNCULU" butonları web'dekiyle aynı yükseklikte
      (44px) ve aynı punto (14px) olmalı; mobilde daha uzun/şişkin
      DURMAMALI. **Not:** kartın tamamının sığmayıp kaydırma gerektirmesi
      web TEST DERLEMESİNDE normaldir (tarayıcı kromu Flutter canvas'ını
      kısaltıyor, CSS `vh` ise kromu saymıyor) — bu kontrol yalnızca
      native (TestFlight/Appetize) derlemede anlamlı: orada kart
      kaydırmadan tam açılmalı.
- [ ] **Genel = 2 + 4.** Genel sekmesindeki Toplam Oyun/Birincilik/
      İkincilik, iki sekmenin toplamına eşit olmalı.
- [ ] **k-lig sıralaması (9 Ağustos 2026, Parça 31).** Liste açılmalı,
      kaydırınca sayfa sayfa yüklenmeli; kendi satırın listede değilse
      altta kısayol çıkmalı. **Liste az sayıda kullanıcıdan oluşuyorsa
      (ilk 10'un altına sığacak kadar kısaysa) sonraki sayfa hiç kaydırma
      gerekmeden KENDİLİĞİNDEN yüklenip kendi satırın GERÇEK adınla listede
      görünmeli — "SENİN SIRAN" kısayolu/"Sen" yer tutucusu bu durumda hiç
      çıkmamalı** (web/mobil ekran görüntüsü karşılaştırmasıyla bulundu —
      önceden mobil kısa listede takılı kalıyordu). Bir isme dokununca o
      oyuncunun kartı açılmalı. Skor Kartı ve bir başkasının kartında,
      mavi "k-lig" yazısının yanında küçük dairesel bir "?" rozeti
      olmalı; dokununca (ya da rozetin kendisine dokununca) k-lig
      sıralaması açılmalı.
- [ ] **OHP kolonu (12 Ağustos 2026, Parça 63).** k-lig tablosunda PUAN'ın
      SOLUNDA bir **OHP** kolonu olmalı: iki basamaklı (`12.78`), **düz
      gri ve kalın DEĞİL** (Puan mavi/kalın kalır), hiç hamle verisi
      olmayan eski kayıtlarda `—`; rakamlar satırın kendi puntosundan
      (14px) küçük görünmeli. **Açıklama balonu:** başlığa dokununca balon
      başlığın TAM ÜSTÜNDE, aşağı bakan bir kuyrukla açılmalı ("Ortalama
      Hamle Puanı tüm oyunlarda yapılan tüm hamlelerin ortalamasıdır.");
      tekrar dokununca VE ekranda başka bir yere dokununca kapanmalı.
      Metin BÜYÜK HARFE dönmemeli ve modalın üst kenarında kırpılmamalı.
      (Masaüstü/web derlemesinde fareyle üzerine gelince de açılıp
      çekilince kapanmalı; bu sırada ikinci bir Flutter `Tooltip` balonu
      ÇIKMAMALI.) **Çapraz
      kontrol — asıl mesele bu:** bir oyuncunun k-lig satırındaki OHP ile
      o oyuncunun kartını açıp "Ortalama Hamle Puanı" kutusunda yazan sayı
      BİREBİR AYNI olmalı; ikisi sunucuda aynı ifadeden geliyor, ayrışırsa
      view'lardan biri bozulmuş demektir. Aynı sayı web'de de aynı
      görünmeli (`kelimeki.com` ile yan yana).
      **Hiza (14 Ağustos 2026, Parça 92):** OHP Puan'a yakın durmalı,
      aralarında geniş bir boşluk kalmamalı; başlık satırı, liste
      satırları ve "senin sıran" kısayolu ÜÇÜ DE aynı hizada olmalı.
      Web ile yan yana koy — iki platformda da aynı (sağ kenarlar arası
      44px) görünmeli. **"OHP" başlığı, altındaki rakamların TAM ÜSTÜNDE
      (ortalı) durmalı** — sağa kaymış görünmemeli; 1 basamaklı bir
      ortalama (`9.50`) 2 basamaklılarla ondalık noktasında hizalı kalmalı
      (değerler sağa yaslı, yalnızca başlık ortalı). Açıklama balonunun
      kuyruğu da başlığın merkezini göstermeli.
- [ ] **Misafir kuyruğu.** Çıkış yap, misafirken bir oyunu BİTİR, sonra
      giriş yap → o oyun hesabına işlenmeli (web'deki Skor Kartı'ndan
      doğrula).
- [ ] **Terk cezası.** (Uzun test — 7 gün.) Bir oyunu yarıda bırak ve 7 gün
      dokunma; sonra Setup'ı aç → oyun silinmeli, k-lig puanından -2
      düşmeli ve "-2 puan" bildirim e-postası gelmeli. Sabırsızsan
      `local_game_saves.updated_at`'i SQL ile 8 gün geriye çekip test et.

## 5. Oyun geçmişi

- [ ] **Liste.** Skor Kartı → "Tüm Oyunları Gör". Kartlarda tarih,
      Canlı/Yapay Zeka rozeti, sıralama, Puan ve **k-lig** sütunları.
      Kaydırınca sayfa sayfa yüklenmeli.
- [ ] **Tahta önizlemesi.** Bir karta dokun → o oyunun bitişteki tahtası
      açılmalı (bölge tonları, köşe filigranları, X2/X3 dahil). Tekrar
      dokunmak kapatmalı.
- [ ] **Web'de oynanan oyunlar da görünmeli** — geçmiş ortak tablodan
      geliyor, mobilde oynanmış olmasına gerek yok.
- [ ] **Beğeni.** Kalbe dokun → dolmalı, **KIRMIZI olmalı** (gri/siyah değil
      — 9 Ağustos 2026'da gri kaldığı bulundu, bkz. Parça 35) ve sayı
      artmalı. Web'de AYNI oyunu aç: kalp orada da dolu olmalı.
- [ ] **Beğenenler.** Sayıya dokun → liste açılmalı; bir isme dokununca o
      kişinin skor kartı açılmalı.
- [ ] **Favoriler sekmesi.** Yalnızca beğendiğin oyunları göstermeli —
      başkasının oyununu beğendiysen o da listede olmalı ve satırda
      **senin adın hiçbir yere yapışmamalı** (o satır onun).
- [ ] **Hamle geçmişi ikonu (12 Ağustos 2026, Parça 65).** Dökümü OLAN
      kartlarda küçük bir döküman ikonu olmalı; dokununca "OYUN GEÇMİŞİ"
      dökümü tüm detayıyla açılmalı (kelime + ham puan + ×2/×3,
      Bingo/Sınır İhlali rozetleri, toplam). Web'de AYNI oyunu aç — iki
      istemci aynı `games.moves` kolonunu okuyor, döküm birebir aynı
      olmalı. **Uçak modunda** dokununca "kaydedilmemiş" DEĞİL "Bağlantını
      kontrol edip tekrar dene." demeli (ikisi bilinçli olarak ayrı).
- [ ] **İkon YALNIZCA dökümü olan kartta (Parça 67).** Kolon 12 Ağustos
      2026 15:27 UTC'de açıldı; ondan ÖNCE biten YEREL oyunların dökümü
      kurtarılamıyor. Yani **eski YZ kartlarında ikon HİÇ çıkmamalı** (ilk
      sürüm çıkarıyor ve boş bir diyalog açıyordu — kullanıcı bunu
      bildirdi), Canlı kartlarda çıkmalı. **EN KRİTİK KONTROL — kural tür
      bazlı DEĞİL:** uygulamada yeni bir YZ oyunu sonuna kadar bitir; O
      kartta ikon ÇIKMALI ve döküm dolu gelmeli. Web'de de aynı kart aynı
      şekilde davranmalı (tek kaynak: `game_like_stats.has_moves`).
- [ ] **Hamle ikonuna dokunmak KOLAY olmalı (12 Ağustos 2026, Parça 68).**
      İkona parmakla bir kerede dokunulabilmeli — "tam basamazsan kart
      açılıp kapanıyor" olmamalı. Ölçüt: **yanındaki sohbet rozetiyle aynı
      kolaylıkta** (dokunma kutuları artık eşit: 19×13 vs 18.8×13; ölçülen
      ve testle korunan bir eşitlik). İkonun GÖRSEL konumu ve sohbet
      rozetiyle arasındaki 6px boşluk değişMEmeli — kayma varsa dolgunun
      karşılığında kısılan boşluk yanlış hesaplanmış demektir. Web'de aynı
      karta bak: iki platform aynı hissi vermeli.
- [ ] **Sohbet arşivi.** Web'de oynanmış, mesajlaşılmış bir Canlı oyunun
      kartında konuşma balonu rozeti + mesaj sayısı olmalı; dokununca
      dondurulmuş sohbet açılmalı. Sessize aldığın biri varsa isminin
      yanında 🚫 görünmeli.
      **Sıralama: en yeni mesaj EN ÜSTTE** (9 Ağustos 2026 — arşiv o güne
      kadar ters duruyordu, bkz. Parça 36). Kural her yerde aynı: canlı
      sohbet penceresi, bu arşiv ve web'in admin dökümü — üçü de en
      yeniden eskiye.
- [ ] **Sohbet gizliliği (10 Ağustos 2026, Parça 51).** k-lig → sana ait
      OLMAYAN bir oyuncuya dokun → skor kartı → "Tüm Oyunlar". Onun
      **katılmadığın** bir Canlı oyununun kartında konuşma balonu rozeti
      **HİÇ ÇIKMAMALI** (sayaç da içerik de yalnızca katılımcıya/admin'e
      açık). Kendi katıldığın Canlı oyunlarda rozet + sayı normal
      görünmeli. Aynı hesapla web'de de kontrol et — iki istemci aynı
      RPC'yi (`game_like_stats`) çağırıyor, ayrışmamalı.
- [ ] **Ağ hatası "oyunun yok" DEMEMELİ (14 Ağustos 2026, Parça 90).**
      Uçak modunda "Tüm Oyunlarım"ı aç → **"Oyun geçmişi yüklenemedi.
      Bağlantını kontrol edip tekrar dene."** görünmeli, "Henüz kayıtlı bir
      oyunun yok." DEĞİL. Aynısını Setup'taki "Son Oynananlar" sekmesinde
      de kontrol et (aynı bayrağı ayrı okuyan ikinci tüketici).
      **Negatif eşi ŞART:** çevrimiçiyken gerçekten hiç oyunu olmayan bir
      hesapla aç — orada normal "hiç oyunun yok" metni çıkmalı, aksi halde
      bu madde hiçbir şey kanıtlamaz.
- [ ] **Hukuki metin tazeliği (Parça 90).** Hesap Ayarları/kayıt formundan
      **Gizlilik Politikası**'nı aç → "Veri Paylaşımı" bölümü sohbet
      arşivinin **yalnızca o oyunun katılımcılarına ve yönetici ekibine**
      açık olduğunu söylemeli ("tüm kayıtlı kullanıcılara açıktır" DEĞİL —
      o cümle 10 Ağustos'tan beri gerçek dışıydı). Alttaki "Son güncelleme"
      tarihi web'deki `PrivacyModal` ile AYNI olmalı; `flutter test` bunu
      artık otomatik zorluyor (`test/legal_text_test.dart`), bu madde
      yalnızca metnin ekranda gerçekten doğru göründüğünün teyidi.

- [ ] **Platform telemetrisi (14 Ağustos 2026).** Uygulamada bir YZ oyunu
      SONUNA kadar bitir (yarıda bırakma — satır ancak bitince yazılıyor).
      Sonra kelimeki.com'da admin hesabıyla Admin Paneli → Büyüme →
      Kullanıcı → **Platform** tablosuna bak: native derlemede `iOS`/
      `Android`, GitHub Pages web derlemesinde `App (Tarayıcı)` satırının
      "Oyun" sayısı 1 artmalı — `Web` satırı DEĞİL (o, kelimeki.com'dan
      oynananlar). Bu, portun kendi platformunu gerçekten yazdığının tek
      uçtan uca kanıtı; kolon geriye dönük doldurulamıyor.
- [ ] **Canlı oyunda da yazılıyor.** Bir Canlı oyunu aç (bitirmeye gerek
      YOK — satır oyun açılırken yazılıyor) ve bitiminde aynı tabloda kendi
      istemcinin satırında görün. Rakip web'den oynadıysa iki AYRI satır
      artmalı.

## 6. Paylaşma

- [ ] **Paylaş menüsü.** Açık tahta önizlemesine dokun → alttan
      **"Paylaş / Kapat"** menüsü, arka plan kararmış olmalı. Ayrı bir
      "Vazgeç" paneli OLMAMALI (13 Ağustos 2026'da iki platformdan da
      kaldırıldı, bkz. Parça 85) — web ile yan yana koyunca ikisi de iki
      butonlu görünmeli.
- [ ] **Sistem paylaş sayfası.** "Paylaş" → iOS/Android paylaş sayfası
      açılmalı; görsel önizlemesi **skor kutuları + tahta** olmalı.
      **Hiçbir tepki vermemesi bir hatadır** (9 Ağustos 2026'da web
      derlemesinde tam bu yaşandı — dosyalı paylaşım patlayınca tek
      `catch` her şeyi yutuyordu, bkz. Parça 35). Görselli paylaşım o
      platformda mümkün değilse en azından **metin + link** paylaşım
      sayfası açılmalı.
- [ ] **GÖRSEL GERÇEKTEN GİDİYOR MU? (Parça 84 — 13 Ağustos 2026'da
      kırıktı).** Paylaşımı WhatsApp/Notlar ile kendine gönder ve GELEN
      mesaja bak: **tahtanın kendisi** görünmeli. Yalnızca metin+link
      gelip altında Kelimeki'nin jenerik önizleme kartı çıkıyorsa görselli
      dal sessizce patlıyor demektir — belirti "yanlış görsel" gibi
      görünür, gerçekte görsel HİÇ gitmemiştir. (Kök sebep: dosya yazımı
      `path_provider`/`dart:io` ile yapılıyordu, ikisi de web'de çalışmıyor;
      artık `XFile.fromData` + `fileNameOverrides` ile share_plus'ın
      kendisi yazıyor.) Web ile yan yana koy — ikisi AYNI görseli
      göndermeli.
- [ ] **İptal ikinci sayfa açmamalı.** Paylaş sayfasını kapat/iptal et →
      arkasından ikinci bir paylaş sayfası AÇILMAMALI (`share_plus`
      iptalde fırlatmaz, yedek zincire düşmemeli).
- [ ] **FAZ B (gerçek cihaz) — paylaş sayfasını kapatınca NEREYE dönüyor?**
      Paylaş sayfasını dışarı dokunarak kapat: **oyun listesinde kalmalı**,
      Skor Kartı'na geri DÜŞMEMELİ. (9 Ağustos 2026, web derlemesinde iPad
      Safari'de: Escape ile kapatınca listede kalıyor ama dışarı dokununca
      Skor Kartı'na dönüyordu. Mekanizma koddan doğrulandı — Safari,
      paylaş sayfasını kapatan dokunuşu altındaki sayfaya da iletiyor,
      dokunuş `showDialog`'un barrier'ına düşüp `GameHistoryModal`'ı
      kapatıyor; `barrierDismissible` varsayılan `true` ve web'in
      `Modal.tsx`'i de aynı kuralı uyguluyor, yani bir port sapması DEĞİL.
      Native'de paylaş sayfası işletim sistemi katmanında olduğundan bu
      dokunuşun uygulamaya iletilMEmesi bekleniyor — **bu, doğrulanmamış
      bir çıkarım**, cihazda tekrarlarsa düzeltilmeli.)
- [ ] **Link çalışıyor.** Paylaşımı kendine gönder (Notlar/WhatsApp),
      linke tıkla: `kelimeki.com/game/<id>` sayfası **girişsiz** açılmalı
      ve aynı tahtayı göstermeli. (Bu, `set_game_shared` RPC'sinin
      gerçekten çalıştığının kanıtı — bayrak yazılmazsa sayfa boş gelir.)
- [ ] **Setup footer'ındaki "Paylaş" (18 Ağustos 2026, Parça 110) —
      YALNIZCA GİRİŞLİ hesapta.** Girişli aç: kurulum ekranının en
      altındaki satır "Kullanım Koşulları · Gizlilik Politikası · Paylaş"
      olmalı — **ayraçlar dahil üç madde** (ilk sürümde `·` unutulmuştu,
      "web ile birebir" isteğinin ihlaliydi). Dokun → native paylaş
      sayfası açılmalı; paylaşılan link `https://kelimeki.com/?ref=arkadas`
      OLMALI (kendine gönderip metni oku). **Negatif eş:** çıkış yap →
      aynı satırda "Paylaş" ve ondan önceki `·` HİÇ olmamalı, yalnızca iki
      hukuki link kalmalı. **Web'deki ikon porta BİLEREK taşınmadı** — app
      footer'ında "Paylaş"ın önünde paylaşım ikonu YOK, bu bir eksik
      değil kayıtlı bir ayrışma (bkz. kök `CLAUDE.md`, Setup footer notu).

- [ ] **Kapat.** Menüden "Kapat" tahta önizlemesini kapatmalı.
      (13 Ağustos 2026'da kullanıcı bunun çalışmadığını bildirdi; native
      testte ÖLÇÜLDÜ — "Kapat" tahtayı gerçekten kapatıyor (ScoreBoxRow
      1 → 0) ve ilgili test geçiyor. Cihazda hâlâ kapanmıyorsa tarayıcıya
      özgü bir dokunuş yayılımı olabilir, ayrı bir tur gerekir.)
- [ ] **Menüden aksiyonsuz çıkış (eski "Vazgeç"in yerine).** Menü açıkken
      DIŞINA dokun (ya da aşağı sürükle): menü kapanmalı, tahta önizlemesi
      AÇIK kalmalı, paylaşım tetiklenMEmeli. Bu, "Vazgeç" butonunun
      kaldırılmasının kullanıcıyı kapana kıstırmadığının kontrolü.
- [ ] **Ekranda başka yere dokunmak tüm oyunlar penceresini kapatır** ve
      Skor Kartı'na döner — bu bir port sapması DEĞİL, web `Modal.tsx`'in
      zemin dokunuşu da `onClose` çağırıyor (bkz. bu bölümün 4. maddesi).

## 7. Son Oynadıklarım

- [ ] **Liste.** Setup → "Yapay Zeka ile" → **"Son Oynananlar"** alt
      sekmesi (Parça 28'den beri ayrı bir sekme, artık devam eden
      oyunların ALTINDA değil): son 5 biten YZ oyunu — avatar şeridi,
      tarih, puan, k-lig. Başlık satırı "SON OYNADIKLARIM" + sağda
      "TÜM OYUNLARIM" linki.
- [ ] **Canlı tarafı aynı bileşen.** "Arkadaşınla" → "Son Oynananlar":
      yalnızca biten CANLI oyunlar (YZ oyunları burada görünmemeli).
- [ ] **Hedefe gitme.** Bir satıra dokun → Tüm Oyunlarım açılmalı ve **o
      oyunun tahtası zaten açık** olmalı, kart ekranın ortasında. (Hedef
      listenin gerisindeyse sayfalama otomatik ilerler — bunu test etmek
      için epeyce bitmiş oyunun olması gerekir.)
- [ ] **Tüm Oyunlarım linki.** Sağ üstteki link listeyi odaklanmadan
      açmalı.
- [ ] **Hiç bitmiş oyun yoksa BOŞ MESAJ gösterilmeli** — "Henüz bitmiş
      bir Yapay Zeka oyunun yok." (Canlı sekmesinde "…bir Canlı oyunun
      yok."). Parça 28'e kadar bölüm sessizce gizleniyordu; kendi başına
      bir sekme içeriği olunca bu, bomboş bir sekme demek olurdu.

## 8. Dayanıklılık (uçak modu)

- [ ] **Offline oyun.** Uçak moduna al, YZ oyunu oynanmaya devam etmeli
      (motor ve sözlük tamamen yerel).
- [ ] **GİRİŞLİYKEN offline oynanan hamleler KAYBOLMAMALI (Parça 38).**
      Girişli ol, bir YZ oyunu aç, birkaç hamle yap. Uçak moduna al ve
      **birkaç hamle daha yap**. Ağı geri aç, uygulamayı yeniden başlat →
      "Devam Eden Oyunlar"daki oyun **offline yaptığın hamlelerle**
      açılmalı, eski hâline geri düşMEmeli. (9 Ağustos 2026'ya kadar
      girişli kullanıcı yalnızca sunucuya yazıyordu, offline hamleler
      sessizce düşüyordu.)
- [ ] **Offline'da liste BOŞ görünmemeli (10 Ağustos 2026, Parça 43).**
      Yukarıdaki adımın ortasında, **hâlâ uçak modundayken** logoya basıp
      Setup'a dön: oyun "Devam Eden Oyunlar"da GÖRÜNMELİ (offline hamleleriyle
      birlikte), ve daha önce açtığın diğer YZ oyunları da listede kalmalı —
      yalnızca offline oynadığın oyun görünüyorsa önbellek devreye girmemiş
      demektir. Süresi dolmuş bir kayıt bu ekranda listelenMEmeli ve
      offline'dayken **-2 cezası uygulanMAmalı** (ceza ancak ağ dönünce
      yazılır).
- [ ] **Uçak modunda ÇIK–GİR: hamle kaybolmamalı (16 Ağustos 2026, Parça
      105).** Bu, hatanın bulunduğu senaryonun birebir kendisi — **hızlı**
      koş, bekleme: uçak modundayken "Devam Edenler"den var olan bir oyunu
      aç (4 kişilik olması şart değil), **bir hamle yap**, hemen logoya
      basıp Setup'a dön ve **listeyi beklemeden AYNI satıra tekrar dokun**.
      Oyun az önceki hamlenle açılmalı, "ilk hâline" dönMEmeli. Sonra ağı
      aç → web'de aynı oyunda o hamle görünmeli. (Liste bir anlık
      görüntüdür; uçak modunda tazelenmesi ağ zaman aşımını bekler ve o
      pencerede bayat satırla açılan oyun, aynadaki taze state'i geri
      yazarak SİLİYORDU.)
- [ ] **Tamamen offline açılan oyun da kaybolmamalı.** Uçak modundayken
      YENİ bir YZ oyunu aç, birkaç hamle yap. Ağı aç + yeniden başlat →
      oyun listede olmalı (sunucu onu hiç görmemişti).
- [ ] **Ama uzun süre DÖNÜLMEZSE ceza yine işlemeli.** Oyunu aç, interneti
      kapat, uygulamayı kapat; 7 günden sonra internetle geri dön → oyun
      teslim sayılıp **-2** uygulanmalı ve listede kalmamalı. Bekleyen bir
      yerel ayna bu cezayı ATLATMAMALI (9 Ağustos 2026'da tam bu açık
      bulundu). Sonraki açılışta oyun geri DİRİLMEMELİ ve ceza ikinci kez
      uygulanmamalı.
- [ ] **Offline oynanan oyun HAKSIZ yere teslim sayılmamalı.** Uzun süre
      (7 gün+) sunucuya yazılamamış ama offline oynanmaya devam eden bir
      oyunda -2 cezası UYGULANMAMALI; oyun listede normal görünmeli.
- [ ] **Offline bitiş kuyruğa girmeli.** Uçak modundayken bir oyunu bitir,
      sonra ağı aç ve uygulamayı yeniden başlat → kayıt sunucuya işlenmeli
      (web'deki Skor Kartı'ndan doğrula). Kayıt kaybolmamalı.
- [ ] **Biten oyun listeye GERİ GELMEMELİ (10 Ağustos 2026, Parça 46).**
      Yukarıdaki adımdan sonra "Devam Edenler"e bak: offline bitirdiğin
      oyun orada OLMAMALI. Ağ döndüğü an kısa bir süre (≈1 sn) görünüp
      kaybolması normal — eşzamanlı iki senkrondan biri listeyi silme
      tamamlanmadan çekmiş olabilir; kalıcı olarak duruyorsa hata.
- [ ] **Mükerrer kayıt olmamalı.** Yukarıdaki kayıt Skor Kartı'nda **bir
      kez** görünmeli (aynı id ile ikinci gönderim 23505 alır ve başarı
      sayılır).
- [ ] **Offline listeler çökmemeli.** Uçak modunda geçmiş/k-lig ekranlarını
      aç: boş liste ya da "Yükleniyor…" ile kalmalı, hata ekranı/çökme
      OLMAMALI.
- [ ] **Ağ dönünce senkron beklememeli (10 Ağustos 2026, Parça 44).**
      Offline oynadıktan sonra ağı aç ve uygulamayı arka plana alıp öne
      getir (uygulamayı kapatmadan, oyuna girip çıkmadan). Birkaç saniye
      içinde kayıt sunucuya gitmeli — web'de (kelimeki.com) aynı hesapla
      bakınca oyun görünmeli. **Bilinen sınır:** uygulama hiç arka plana
      alınmadan, ÖNDEYKEN ağ geri gelirse senkron yine beklemez (web'in
      `online` olayının Flutter'da paketsiz karşılığı yok); veri kaybı
      yok, yalnızca gecikme.
- [ ] **Uçak modunda kelime anlamı — bu bir HATA DEĞİL (web derlemesinde).**
      Tahtadaki bir kelimeye dokununca "Bu kelimenin anlamı bulunamadı."
      çıkması `alpcapa.github.io` derlemesinde BEKLENEN: asset'ler
      uygulamaya gömülü değil HTTP ile iniyor, 5.26 MB'lık `meanings.db`
      uçak modunda çekilemiyor. Online'ken aynı kelimenin anlamı GELMELİ.
      Native (TestFlight/Appetize) derlemede asset pakette olduğundan
      offline de çalışmalı — FAZ B'de ayrıca doğrula.

## 9. Görüş Bildir

- [ ] **Misafir gönderim.** Girişsizken bir oyun bitir → GameOver'daki
      "GÖRÜŞ BİLDİR" → mesaj + e-posta yaz → GÖNDER → "Teşekkürler" +
      "{e-posta} ile üyeliğine devam etmek ister misin?" teklifi çıkmalı.
      Web admin panelinde (Geri Bildirim sekmesi) mesaj o e-postayla,
      kaynağı oyun-sonu olarak görünmeli.
- [ ] **Kapatmak da formu açar.** Aynı GameOver ekranında "GÖRÜŞ BİLDİR"e
      DOKUNMADAN ✕ ile (ya da Android'de geri tuşuyla / dışarı dokunarak)
      kapat → "Görüş Bildir" formu KENDİLİĞİNDEN açılmalı. Web'de kapatmanın
      her yolu bunu yapıyor (`onClose` hem modalı kapatıyor hem formu
      açıyor); portta 10 Ağustos 2026'ya kadar hiç yoktu (bkz. Parça 48).
      Yerel/YZ oyununda ve Canlı oyunda AYRI AYRI dene.
- [ ] **Üyelik teklifi → kayıt.** Teklifte EVET → kayıt formu doğrudan
      açılmalı, e-posta önceden dolu; kayıt tamamlanınca admin panelinde
      Üyeler tablosunda kanal "Form" görünmeli (`signup_channel='form'`).
- [ ] **Girişli gönderim.** Girişliyken formda e-posta alanı OLMAMALI
      ("Yanıt e-postan: …" satırı var); gönderilen mesaj admin panelinde
      hesabına bağlı görünmeli.
- [ ] **Terms/Privacy içi link.** Kayıt formundaki Kullanım Koşulları →
      "Görüş Bildir formu" linki formu açmalı (kaynak: genel).
- [ ] **Offline kuyruk.** Uçak modunda mesaj gönder → "Teşekkürler"
      görünmeli (mesaj kuyruğa girdi); ağı açıp Setup'a dönünce mesaj
      sunucuya işlenmeli (admin panelinden doğrula). Kuyruk girişsiz de
      boşalır — oyun kayıtlarının aksine oturum beklemez.
- [ ] **Rate limit.** 10 dakika içinde 4. mesajda "Çok fazla mesaj
      gönderdin…" hatası çıkmalı, mesaj gönderilmemeli.

## 10. Arkadaşlar

- [ ] **Davet linki `?ref=arkadas` taşıyor (Parça 122).** Arkadaşlar →
      "Arkadaşını Davet Et" ile link üret ve paylaş penceresinde/panoda
      URL'e bak: `https://kelimeki.com/davet/<token>**?ref=arkadas**`
      OLMALI. Etiket yoksa davetle gelip üye olan herkes admin panelindeki
      Kaynak Hunisi'nde `direkt` satırına düşer. Linki temiz bir tarayıcıda
      açtığında davet sayfası normal açılmalı (sorgu parametresi token
      çözümünü BOZMAZ).

- [ ] **Modal + rozet.** Girişliyken hesap menüsünde "Arkadaşlar" satırı
      görünmeli; başka bir hesaptan sana istek gönderilince (web'den
      gönderilebilir) satırda kırmızı sayı rozeti + **avatarda aynı sayıyı
      gösteren rozet** (16 Ağustos 2026'ya kadar sayısız bir noktaydı)
      çıkmalı (tazelenme: uygulamayı yeniden açınca ya da modalı açıp
      kapatınca — Realtime bilinçli yok, web'de de yok).
- [ ] **Varsayılan sekme.** Bekleyen istek varken modal "İstekler"
      sekmesiyle açılmalı; Kabul Et → kişi "Arkadaşlarım"a düşmeli,
      web tarafında da arkadaş görünmeli.
- [ ] **Ara & Ekle.** Boş kutuda "Tüm Üyeler" listesi kaydırdıkça
      20'şer büyümeli; 2+ karakterle arama çalışmalı; **kişi-ekle ikonuna**
      dokun → onay ("… arkadaş olarak eklemek istiyor musun?") → "Arkadaşlık
      isteğiniz iletilmiştir." → satırdaki ikon **kum saatine** dönmeli
      (karşı hesapta istek görünmeli); karşılıklı istek senaryosu: karşı
      taraf sana zaten istek göndermişse mesaj "Arkadaş oldunuz." olmalı
      (sunucu trigger'ı) ve e-posta GİTMEMELİ.
      **Satır aksiyonları 11 Ağustos 2026'da metin butonlarından ikonlara
      indirildi.** Üç ikon: kişi-ekle (mavi) · kum saati (gri, dokun →
      iptal) · kişi-onay (mavi, gelen isteği kabul). Kural: ikon, dokunuşun
      NE YAPACAĞINI söyler; **hiçbiri anında iş yapmaz, hepsi önce onay
      sorar** (dokunup "Vazgeç" dediğinde karşı hesapta hiçbir şey
      OLMAMALI — bunu da kontrol et).
- [ ] **Ara & Ekle arkadaşları GÖSTERMEZ (aynı gün, kullanıcı isteği).**
      Zaten arkadaş olduğun biri ne aramada ne "Tüm Üyeler" listesinde
      çıkmalı — kırmızı "adam-" ikonu bu iki listede HİÇ görünmemeli
      (arkadaş çıkarma yalnızca "Arkadaşlarım" sekmesinde ve skor kartında).
      Bir gelen isteği buradan kabul edince satır listeden düşmeli ("Arkadaş
      oldunuz." mesajından sonra "Arkadaşlarım"da görünmeli). Aramada
      bulunanların HEPSİ arkadaşsa "Bulunanların hepsi zaten arkadaşın"
      metni çıkmalı; "Tüm Üyeler"de bir sayfanın tamamı arkadaş çıksa bile
      liste boş kalmamalı, sonraki sayfa kendiliğinden gelmeli.
- [ ] **Davet linki.** "Arkadaşını Davet Et" sistem paylaş sayfasını
      açmalı; link `https://kelimeki.com/davet/…` biçiminde olmalı ve
      webde açılıp çalışmalı (üye olmayan kayıt akışına düşmeli).
- [ ] **Davet linki uygulamada — uygulama AÇIKKEN (sıcak).** Uygulama
      arka planda AÇIK dururken `kelimeki://davet/<token>` linkine dokun
      (test için token'ı web linkinden alıp şemayı elle kur, ör. notlara
      yapıştırıp aç): girişliysen "X ile artık arkadaşsınız" diyaloğu;
      girişsizsen "giriş yaptığında ekleneceksiniz" önizlemesi, giriş
      sonrası Setup'ta otomatik kabul.
- [ ] **Davet linki uygulamada — uygulama KAPALIYKEN (soğuk başlangıç,
      13 Ağustos 2026, Parça 87).** Uygulamayı görev yöneticisinden
      TAMAMEN kapat, sonra aynı linke dokun: uygulama açılmalı VE davet
      işlenmeli. Öncesinde token sessizce kayboluyordu (`AppLinks`in
      soğuk-başlangıç linkini yalnızca İLK dinleyiciye bir kez basması;
      o dinleyici supabase_flutter oluyordu) — sıcak akış çalıştığı için
      görünmüyordu, bu yüzden İKİ maddeyi de ayrı ayrı koş. **Mükerrer
      kontrolü:** "artık arkadaşsınız" diyaloğu YALNIZCA BİR KEZ
      çıkmalı, üst üste iki kez DEĞİL.
- [ ] **PlayerScoreCard simgesi.** k-lig/arkadaş listesinden birinin
      kartını aç: arkadaşsan ismin yanında **yeşil "kişi-onay"** (adam +
      tik) görünmeli — listelerdeki kırmızı "adam-" DEĞİL; bu bilinçli bir
      istisna (kullanıcı kararı: aksiyon sütununda değil, ismin yanında
      duruyor). Dokununca yine **çıkarma onayı** açılmalı. Arkadaş değilsen
      kişi-ekle ikonu (dokun → istek onayı) görünmeli; kendi kartında simge
      OLMAMALI. **Dikkat:** aynı yeşil-adam-tik glyph'i "Ara & Ekle"de MAVİ
      olarak "gelen isteği kabul et" demek — renkler karışmamalı.
- [ ] **Onay/sonuç diyalogları (9 Ağustos 2026, Parça 32).** Aynı ekrandaki
      arkadaş-ekle/çıkar/kabul-et/iptal-et onay diyaloğu (yatay/geniş
      ekranda bile — özellikle iPad'de kontrol et) küçük/kompakt kalmalı,
      ekranın TAMAMINA yayılmamalı. Her işlemin (Gönder/Çıkar/Kabul Et/
      İptal Et) SONRASINDA bir "Tamam" sonuç mesajı çıkmalı: "Arkadaşlık
      isteğiniz iletilmiştir." / "Arkadaşlıktan çıkarıldı." / "Arkadaş
      oldunuz." / "Arkadaşlık isteği iptal edildi." (karşılıklı anlık kabul
      durumunda "{isim} ile artık arkadaşsınız." — bu mobile özgü, web'de
      karşılığı yok, bilinçli).
- [ ] **Ağ hatasında SAHTE başarı YOK (13 Ağustos 2026, Parça 89).**
      Uçak modunu aç, sonra Arkadaşlar'da bir isteği **Reddet** / **Kabul
      Et** ve birine **arkadaşlık isteği gönder**: üçünde de
      **"İşlem başarısız oldu."** çıkmalı. Öncesinde sırasıyla "İstek
      reddedildi." / "Arkadaş oldunuz." / "Arkadaşlık isteğiniz
      iletilmiştir." gösteriliyordu — hiçbiri gerçekleşmemişken. Uçak
      modunu kapatıp tekrar dene: normal sonuç mesajları dönmeli.
- [ ] **Kişiye dokunmak skor kartını açar — ÜÇ sekmede de (11 Ağustos
      2026, Parça 53).** "Arkadaşlarım", "İstekler" ve "Ara & Ekle"
      (hem arama sonucu hem "Tüm Üyeler") satırlarında **avatara/isme**
      dokun → o kişinin skor kartı açılmalı. Aksiyon ikonu bundan
      AYRIŞIK olmalı: ikona dokunmak kartı DEĞİL onay diyaloğunu
      açmalı (ikisi birbirini yutmamalı). Kartın kendi arkadaşlık
      simgesinden bir işlem yapıp (ör. çıkar) kartı kapatınca satırdaki
      ikon ANINDA yeni duruma dönmeli — eski ikon kalmamalı.
- [ ] **Moderasyonu arkadaş satırından geri alma (14 Ağustos 2026, Parça
      91).** Ön koşul: bir Canlı oyunda karşı tarafı sessize al ya da
      şikayet et (bölüm 11), sonra o oyun **bitsin** (ya da listeden
      düşsün). Arkadaşlar → "Arkadaşlarım": o kişinin satırında,
      "arkadaşlıktan çıkar" ikonunun **SOLUNDA** 🚩 (yalnızca sessize
      aldıysan 🚫) çıkmalı. Dokun → "Kişi Ayarları" paneli; oradan
      "Şikayeti Geri Çek" / "Sessizden Çıkar" → **onay adımı** → sonuç
      mesajı. Panel kapanınca ikon **HEMEN** kaybolmalı.
      **Asıl kanıt burada:** oyun bittikten sonra sohbet penceresine
      artık girilemediğinden, bu panel olmadan şikayeti geri çekmenin
      TEK yolu o kişiyle yeni bir oyun açmaktı.
      **Negatif eş — atlama:** hiçbir moderasyon durumu OLMAYAN bir
      arkadaşın satırında bu ikon **hiç görünmemeli**. Yalnızca "ikon
      var" kontrolü, ikonu koşulsuz çizen yanlış bir kural altında da
      geçerdi.
      **Kapsam:** panelden YENİ şikayet açılamaz (bilinçli — şikayet
      hakkında olduğu konuşmaya bağlı); panel bunu söyleyen bir not
      göstermeli. Emoji fallback'i de burada kontrol edilmiş oluyor —
      🚫/🚩 boş kare (tofu) çıkmamalı.
      **14 Ağustos 2026'da HER İKİ YOL da koşuldu ve GEÇTİ:**
      - *Sessizden çıkarma:* ikon çıktı, panelden çıkarıldı, ANINDA
        kalktı. Üretimden teyit — mute tablosu 0 satıra düştü ve
        provenance oyunu **`finished`**'dı, yani kısayol tam da
        tasarlandığı yerde (oyun bittikten sonra) çalıştı.
      - *Şikayet → geri çekme:* aktif bir oyunun sohbetinden şikayet
        edildi (08:19:14), arkadaş satırında 🚩 çıktı, panelden geri
        çekildi (08:20:11) → ikon **kaybolmadı, 🚫'ye döndü** (şikayet
        otomatik sessize aldığından ve geri çekme mute'a dokunmadığından
        — beklenen davranış), sonra sessizden de çıkarılınca tamamen
        kalktı. Yani tasarımın DÖRT durumu da tek turda görüldü.
      **Üretimden okunan asıl kanıt: `handled` = `false` KALDI.** Bu,
      4 Ağustos'ta yazılıp 10 gün ölü bir SQL overload'ında mahsur kalan
      düzeltmenin (`fix_withdraw_report_wrong_overload`) **mobil
      istemciden** ilk doğrulaması — web'de aynı gün, mobilde burada.

## 11. Canlı oyun — davet/kabul + tahta

İki gerçek hesap gerekir (biri web'de olabilir).

- [ ] **Davet gönderme.** ARKADAŞINLA → "+ Yeni Canlı Oyun Aç" → 2
      oyunculu, bir arkadaş seç → Davet Gönder: "Davetiniz gönderilmiştir."
      ekranı; karşı hesapta (web LiveGamesTab ya da mobil) davet
      görünmeli ve davetliye e-posta gitmeli (`notify-game-invite`,
      alıcının `email_notifications_enabled` açıksa).
- [ ] **4 kişilik YZ kuralı.** 4 oyunculu + 2 arkadaşla gönderimde
      "4. koltuk Yapay Zeka…" onayı çıkmalı; HAYIR → listede kalıcı
      "Yapay Zeka" satırı; 3 arkadaş seçiliyken YZ satırı pasif olmalı.
      Sunucu tarafı: oluşan oyunda 4. koltuk `{"type":"ai"}` olmalı.
- [ ] **Davet alma + varsayılan sekme.** Sana davet gönderilmişken
      ARKADAŞINLA'yı aç: "Oyun Davetleri" alt sekmesi kendiliğinden
      seçili gelmeli (rozetle), kartta katılımcılar doğru durum
      etiketleriyle (Davet gönderen/Kabul etti/Bekliyor) listelenmeli.
- [ ] **Kabul → öneri → aktif.** Kabul Et: henüz arkadaş olmadığın
      katılımcı varsa arkadaşlık önerisi modalı çıkmalı (Devam → istek
      web'de görünmeli); tüm davetler kabul olunca oyun iki tarafta da
      "Devam Edenler"e düşmeli, sıra kimdeyse onda "Senin Hamlen
      Bekleniyor" + kalan süre (yalnız sırası olanda) görünmeli.
- [ ] **Ret.** Reddet: oyun HER İKİ tarafın listesinden de anında
      kalkmalı (web `decline_game_invite_abandons_game` — oyun
      `abandoned`).
- [ ] **Realtime.** İki cihaz açıkken web'den yeni davet gönder: mobil
      ARKADAŞINLA açıkken liste ~1sn içinde kendiliğinden güncellenmeli
      (arka plandan dönüşte de — lifecycle resumed tazelemesi).
- [ ] **Süresi dolmuş davet süpürmesi.** 7 günden eski pending bir
      davet varsa (test için `created_at` SQL ile geriye çekilebilir)
      liste açılınca kendiliğinden kaybolmalı (`check_invite_expiry`) —
      davetLİnin listesinde de (hayalet davet regresyonu).
      **Test davetini `create_online_game` RPC'siyle kur** (istemciden
      DEĞİL): davet e-postasını istemci gönderdiğinden RPC doğrudan
      çağrıldığında kimseye mail gitmez. **Gerçek bir kullanıcının
      bekleyen davetini ASLA kullanma** — süpürme onu da iptal eder.
      **17 Ağustos 2026'da koşuldu ve GEÇTİ** (tek kullanımlık T1→T2
      daveti `abandoned`'a döndü, sonra tamamen silindi; `game_invites`
      satırı tasarım gereği `pending` kalıyor — kovaların hepsi
      `online_games.status`'e de baktığından davet hiçbir listede
      görünmüyor).
- [ ] **Setup'taki "Yapay Zeka ile (N)" rozeti (15 Ağustos 2026, Parça
      101).** Girişliyken devam eden N adet YZ oyunun varken kurulum
      ekranını aç: "YAPAY ZEKA İLE" sekme butonunun sağ üstünde N rozeti
      olmalı ve bu sayı hemen altındaki **"DEVAM EDENLER" alt sekmesinin
      rozetiyle AYNI** olmalı (kapsayan sekme = kapsananların toplamı).
      Regresyon belirtisi: alt sekmede sayı var, üstteki sekmede hiç yok.
      Misafirken tek slot olduğundan rozet 0 ya da 1 olur.
- [ ] **Setup'taki "Arkadaşınla (N)" rozeti.** Bekleyen bir davetin/sırası
      sende olan bir oyunun varken uygulamayı aç: kurulum ekranındaki
      "ARKADAŞINLA" sekme butonunun sağ üst köşesinde kırmızı bir sayı
      rozeti görünmeli VE sekme kendiliğinden "Arkadaşınla" ile açılmalı
      (elle "Yapay Zeka ile"ye dokunmana gerek kalmadan). Bekleyen işi
      giderdikten (hamleni oyna/daveti yanıtla) sonra Setup'a dönünce
      rozet kaybolmalı.
- [ ] **Otomatik geçiş yalnızca girişte, bir kez.** Yukarıdaki sekmeden
      elle "Yapay Zeka ile"ye dön — uygulama tekrar Canlı'ya ZORLA
      GERİ ÇEKMEMELİ (rozet sayısı değişse bile).
- [ ] **Hesap değişimi.** Bekleyen işi olan bir hesapla "Arkadaşınla"
      sekmesindeyken çıkış yap → "Yapay Zeka ile"ye dönmeli (bomboş bir
      "Arkadaşınla" ekranında kalmamalı). Farklı bir hesapla giriş yap —
      o hesabın kendi bekleyen işi varsa yine otomatik "Arkadaşınla"ya
      geçmeli (ilk hesaptan kalan bir kilitlenme olmamalı).
- [ ] **"Arkadaşınla paylaş".** Logonun altındaki "Nasıl oynanır? ·
      Arkadaşınla paylaş" satırındaki linke dokun: sistem paylaş sayfası
      açılmalı, paylaşılan metin "Hemen ücretsiz dene!" + linkte
      `?ref=arkadas` olmalı. Web admin panelinde (Büyüme > Kullanıcı >
      Ziyaretçi Kaynağı) bu linkten gelen bir ziyaret "arkadas" kaynağıyla
      görünmeli (misafirken açılırsa).

- [ ] **Etiket puntoları (Parça 55).** "Devam Edenler"deki durum etiketi
      ("SENİN HAMLEN BEKLENİYOR"/"RAKİBİN HAMLESİ BEKLENİYOR") web'le aynı
      boyda olmalı; hemen altındaki kalan-süre satırı ondan belirgin KÜÇÜK
      (web'de de öyle — ikisi eşit görünüyorsa regresyon). Davet
      kartlarının sağ üstündeki süre etiketi ise bu ikisinin arasında bir
      boyda.

### Tahta (oynanış)

- [ ] **Açılış.** "Devam Edenler"de bir oyuna dokun: tahta, KENDİ rafın
      (rakibin taşları HİÇBİR yerde görünmemeli), skorlar ve doğru sıra
      gelmeli. Rakibin rafı ağ trafiğinde de olmamalı (yalnızca
      `get_my_online_rack` çağrılır).
- [ ] **Hamle.** Sıra sendeyken kelime kur → OYNA: hamle web tarafında
      anında görünmeli, skor/torba/raf iki tarafta da tutmalı. Bölge
      vergisi varsa önce "Sınır İhlali!" onayı çıkmalı (kabul butonu
      solda, VAZGEÇ sağda — bkz. mobile/CLAUDE.md Parça 25; metin bölüm
      1'deki gibi renkli vurgulu) ve kabul edilen pay rakibin skoruna
      geçmeli.
- [ ] **Bingo bonusu Canlı'da da yazıyor (17 Ağustos 2026).** 7 taşı birden
      koyup OYNA → mesaj satırında `(Bingo bonusu +25)`. **Rakibin bingo'su
      geldiğinde de yazmalı** — Canlı ekranı mesajı reducer'dan DEĞİL
      `online_game_moves` satırlarından yeniden üretiyor (`row.bingo`), yani
      yerel oyundan TAMAMEN ayrı bir kod yolu; bölüm 1'de geçmesi burayı
      kanıtlamaz. Web'de aynı oyunu açıp metnin birebir aynı olduğunu
      doğrula (dört kopya: iki reducer + iki Canlı ekran).
- [ ] **Sıra sende değilken egzersiz.** Rakibi beklerken taş yerleştir:
      yeşil/kırmızı çerçeve + puan rozeti çalışmalı, mesaj "Kelime geçerli
      — Sıra: X" demeli, OYNA PASİF olmalı. Rakip oynayınca deneme taşları
      kendiliğinden rafa dönmeli ve OYNA aktifleşmeli.
- [ ] **Terk edilen oyunun -2 cezası "Devam Et"e basınca da yazılmalı
      (13 Ağustos 2026, Parça 89 — kalıcı testi YOK, elle kontrol şart).**
      Misafirken bir YZ oyununu `turnCount>=2` olacak kadar oynayıp Setup'a
      dön; cihaz saatini 7 gün ileri al (ya da 7 gün bekle) ve satır hâlâ
      görünürken **"Devam Et"e dokun**. Beklenen: satır kaybolur VE terk
      kaydı üretilir (bu cihazda giriş yapınca Skor Kartı'nda -2'li teslim
      kaydı görünmeli). Öncesinde bu dal olayı ATOMİK olarak silip çöpe
      atıyordu — ceza kalıcı olarak kayboluyordu. Karşılaştırma: aynı
      senaryoyu "Devam Et"e BASMADAN (yalnız Setup'ı açıp kapatarak)
      koşmak zaten çalışıyordu.
- [ ] **"Sıra: X" bandının rengi (13 Ağustos 2026, Parça 88).** Sıra
      rakipteyken çıkan kırmızı bant, ekrandaki DİĞER kırmızılarla (bandın
      kendi nabız noktası, hata mesajları) AYNI tonda olmalı — öncesinde
      zemin/çerçeve tahtaya özel bir kırmızıdan (`#E0483A`) geliyordu, metin
      ve nokta ise token kırmızısından (`#DC2626`): tek bantta iki ton.
      Bandın artık kabarık bir gölgesi (`shadow-raised`) ve web'le aynı
      dolgusu olmalı — web'le yan yana koyup karşılaştır.
- [ ] **Çevrimdışı Canlı oyun AÇILIŞI (14 Ağustos 2026, Parça 96).** Uçak
      modunda "Devam Edenler"den bir Canlı oyuna dokun: ekran
      "Yükleniyor…"da ASILI KALMAMALI; "Canlı oyun için internet gerekiyor"
      başlıklı panel + **TEKRAR DENE** + **← CANLI LİSTESİ** çıkmalı.
      Uçak modunu kapatıp TEKRAR DENE'ye bas → oyun normal açılmalı.
      Aynısını web'de de dene (iki platform aynı metni gösteriyor).
- [ ] **Çevrimdışı panel DÜZGÜN çiziliyor (Parça 96).** Uçak modunda bir
      Canlı oyuna gir: kart İÇERİĞİNE göre küçülmeli — ekran boyu beyaz bir
      dikdörtgen OLMAMALI (`NeoBox` shrink-wrap etmiyor, o yüzden düz
      `DecoratedBox` kullanılıyor).
- [ ] **Çevrimdışı kelime anlamı (Parça 96).** Uçak modunda bir YZ oyununda
      oynanan kelimeye dokun: "Kelime anlamları için internet bağlantısı
      gerekiyor." çıkmalı — "Bu kelimenin anlamı bulunamadı." DEĞİL.
      **NATIVE derlemede (gerçek iOS/Android) bu mesaj HİÇ çıkmamalı:**
      orada sözlük uygulama paketinde, gerçek anlam gelmeli. Web
      derlemesinde ise sözlük HTTP ile çekildiğinden mesaj beklenen davranış.
- [ ] **Çevrimdışı sekme metinleri (Parça 96).** Uçak modunda Setup'a dön:
      ARKADAŞINLA'nın üç alt sekmesi de "İnternet bağlantısı yok" demeli.
      YAPAY ZEKA İLE sekmesinde devam eden oyunun yoksa linkli öneri
      ("Hemen oyun aç.") çıkmalı ve link yeni oyun formunu açmalı; devam
      eden oyunun VARSA liste normal görünüp oynanabilmeli.
- [ ] **Tahta alt şeridinde "Çevrimdışı" uyarısı (14 Ağustos 2026, Parça
      97).** Bir oyun (YZ ya da Canlı — İKİSİNİ DE dene, ayrı ekranlar)
      AÇIKKEN uçak modunu aç: şeridin sağında, "Nasıl Oynanır?"ın hemen
      solunda kırmızı **"Çevrimdışı"** belirmeli — ekrandan çıkıp girmeye
      GEREK KALMADAN. Puntosu kardeşleriyle (Hamleler · Mesajlaşma · Nasıl
      Oynanır?) aynı görünmeli, daha küçük değil. Uçak modunu kapat: uyarı
      kendiliğinden kalkmalı. **Uçak modunu Kontrol Merkezi'nden aç (yani
      uygulamadan ÇIKARAK) — Parça 98'in kök sebebi tam buydu:** uygulama
      askıdayken bağlantı olayı kaçırılıyor, öne dönüşte durum yeniden
      okunmazsa uyarı hiç çıkmıyor. **Aynısını web'de de kontrol et** — oradaki
      punto düzeltmesi (#256) de henüz cihazda görülmedi, ikisi birlikte
      bakılmalı.
- [ ] **Çevrimdışı hamlede METİN (Parça 96).** Uçak modunda OYNA/PAS GEÇ:
      mesaj satırında **"Bağlantı yok — Canlı oyun için internet
      gerekiyor."** çıkmalı — ham "ClientException/Failed to fetch" DEĞİL.
      Karşılaştırma: sunucunun kendi reddi (ör. sıra sende değilken bir
      şekilde gönderim) hâlâ kendi metniyle görünmeli.
- [ ] **Gönderim hatası taşlar TAHTADAYKEN de görünür (14 Ağustos 2026,
      Parça 95).** Sıra sendeyken geçerli bir kelime kur, uçak modunu aç ve
      OYNA'ya bas: mesaj satırında bir HATA görünmeli ("Bağlantı yok."
      benzeri bir ağ hatası) — "Oyna tuşuyla kelimeyi onayla." DEĞİL ve
      sessizlik hiç değil. Taşlar tahtada kalmaya devam eder. Sonra bir
      taşa dokunup taslağı değiştir: hata kaybolmalı (geçmişe ait).
      Aynısını web'de de kontrol et (iki ekran bu davranışı paylaşıyor).
      Öncesinde port "GÖNDERİLİYOR" deyip ~5sn sonra sessizce eski hâline
      dönüyordu, web hiçbir şey yapmıyordu.
- [ ] **Oyun sonu → "Oyun Geçmişi" DOLU gelir (14 Ağustos 2026, Parça 95).**
      Canlı bir oyunu bitir, GameOver modalındaki "OYUN GEÇMİŞİ"ne dokun:
      oyunun tüm hamleleri listelenmeli. "Henüz kazanılmış bir puan yok."
      görüyorsan regresyon — kıyas için tahta altındaki "Hamleler" linki
      (aynı listeyi göstermeli) ve YZ oyununun oyun sonu modalı.
- [ ] **Sohbet ön plana dönüşte tazelenir (14 Ağustos 2026, Parça 95).**
      İki cihaz/sekmeyle: app'i arka plana al (ana ekrana çık ya da başka
      bir sekmeye geç), karşı taraftan web'den mesaj gönder, sonra app'e
      DÖN. Mesaj kendiliğinden gelmeli — oyundan çıkıp tekrar girmeye
      GEREK KALMADAN. Popup ÇIKMAMALI (arka planda birikenler için tek bir
      okunmamış rozeti); sohbeti açınca mesaj listede olmalı. Bu, iPad'de
      iki Safari sekmesi arasında gidip gelerek de üretilebilir.
- [ ] **Boş taslakta OYNA/GERİ AL (13 Ağustos 2026, Parça 88).** Sıra
      SENDEYKEN, hiç taş yerleştirmeden OYNA'ya bas: buton **aktif** olmalı
      ve mesaj satırında **"Harf yerleştirilmedi."** çıkmalı — gri/tepkisiz
      bir buton DEĞİL. Sunucuya hiçbir şey gitmemeli (sıra sende kalmalı).
      GERİ AL de boş taslakta aktif olmalı (basınca hiçbir şey olmaz,
      zararsız). Aynısını yerel/YZ oyununda da kontrol et — iki ekran bu
      davranışı paylaşıyor.
- [ ] **Sürüklerken rakip oynarsa (Parça 58).** Bir taşı PARMAĞINI
      KALDIRMADAN sürüklerken karşı taraftan hamle gelsin: sürükleme o an
      bitmeli — hayalet taş kaybolmalı, rafta boş slot kalmamalı ve sayfa
      yeniden KAYDIRILABİLİR olmalı (alt butonlara ulaşılabilmeli).
      Regresyon belirtisi: taş havada asılı kalır ve ekran tamamen
      tepkisiz görünür.
- [ ] **Oyun bitince "TEKRAR OYNA" (Parça 59).** Bir Canlı oyunu sonuna
      kadar bitir: raf satırındaki buton "TEKRAR OYNA" olmalı ("CANLI
      LİSTESİ" DEĞİL). Dokun → onay ("… ile aynı kadroda yeni bir oyun
      açılacak … Emin misin?", kabul butonu SOLDA). VAZGEÇ hiçbir şey
      göndermemeli. Onayla → "Davetiniz gönderilmiştir." → TAMAM listeye
      dönmeli ve yeni oyun "Rakip Bekleniyor"da görünmeli; KARŞI hesapta
      yeni bir davet + `notify-game-invite` e-postası olmalı.
- [ ] **Tekrar Oyna — 4 kişilik + YZ.** 4 kişilik ve son koltuğu YZ olan
      bitmiş bir oyunda aynı akış: onay metninde "4. koltuk yine Yapay Zeka
      olacak." çıkmalı ve yeni oyunda 4. koltuk gerçekten `{"type":"ai"}`
      olmalı (sunucudan doğrula). Biten oyunu SEN kurmamışsan da çalışmalı —
      kurucu artık sen olursun.
- [ ] **Tekrar Oyna — artık arkadaş değilseniz.** Rakibi arkadaşlıktan
      çıkarıp dene: "Yalnızca arkadaşlarını davet edebilirsin." mesajı
      görünmeli ve TAMAM'a basınca LİSTEYE DÖNÜLMEMELİ (oyun ekranı ayakta
      kalmalı).
- [ ] **Takılı sürüklemeden kurtuluş (web `clearStuckDrag` portu).** Bir
      taşı sürüklerken uygulamayı arka plana al (ana ekrana çık) ve geri
      dön: sürükleme temizlenmiş olmalı — uygulamayı KAPATIP AÇMAK
      gerekmemeli. Aynı kontrol YZ oyununda (Yapay Zeka ile) da geçerli.
- [ ] **Realtime.** İki cihaz açıkken rakip hamle yapsın: tahtan ~1sn
      içinde güncellenmeli. Uygulamayı arka plana alıp (ya da ekranı
      kilitleyip) rakip oynadıktan sonra geri dön — ön plana dönüşte
      tahta kendiliğinden senkronlanmalı (websocket askıya alınmışsa bile).
- [ ] **PAS GEÇ / DEĞİŞTİR.** İkisi de onay/akış sonrası sunucuya gitmeli;
      taş değiştirmede raf yenilenmeli, torba sayısı DEĞİŞMEMELİ.
- [ ] **YZ koltuğu (4 kişilik).** Sıra YZ'ye gelince nabız atan
      "… hamlesini hesaplıyor" bandı çıkmalı ve YZ birkaç saniye içinde
      kendiliğinden oynamalı (`play-ai-turn`). Uygulamayı kapatıp açmaya
      GEREK KALMAMALI.
- [ ] **Mobil ağ dayanıklılığı (p_move_id).** Hamleyi gönderirken uçak
      moduna al/aç ya da zayıf şebekede dene: aynı hamle İKİ KEZ
      işlenmemeli (skor bir kez artmalı), "Sıra sende değil." gibi sahte
      bir hata çıkmamalı.
- [ ] **Süre aşımı — İKİ DALI DA koş, biri ötekini kanıtlamaz.** Sırası
      gelenin 48 saati dolmuşsa (SQL ile `turn_deadline` geriye çekilerek)
      "Arkadaşınla" sekmesini açmak süpürmeyi tetiklemeli. **2 kişilik:**
      oyun BİTER (`status='finished'`, `end_reason='surrender'`), teslim
      olanın skoru 0 + rafı torbaya döner, kalanın skorundan kendi raf
      puanı düşülür, `games` satırları yazılır (teslim eden rank 2 / lose),
      k-lig **−2**, ve teslim olana **uyarı e-postası** gider. **4 kişilik:**
      oyun BİTMEZ — sıra bir sonraki teslim olmamış koltuğa geçer,
      `turn_count` +1, `turn_deadline` yeniden 48 saate kurulur ve **mail
      GİTMEZ** (mail yalnızca oyun gerçekten bittiğinde). Her iki dalda da
      `online_game_states.bag_count` gerçek torbaya EŞİT olmalı (4 Ağustos
      `check_turn_timeout_bag_count` regresyonu — hata iki dalda da vardı,
      yalnızca 4 kişilikte görünüyordu).
      **17 Ağustos 2026'da koşuldu ve GEÇTİ** (2 kişilik: torba 70→77,
      k-lig 10→8, `net._http_response` `{"ok":true,"sent":1}` ve mail
      ulaştı; 4 kişilik: torba 65→72, oyun `active` kaldı, mail yok).
- [ ] **Logo çıkışı teslim DEĞİL.** Oyun içinde logoya bas: yalnızca Canlı
      listesine dönmeli, oyun bitmemeli, sıra/skor değişmemeli.
- [ ] **Oyun sonu.** Oyun bitince GameOver modalı + kapatınca "CANLI
      LİSTESİ" butonu çıkmalı; skor kartı/k-lig puanları web ile
      tutmalı (`games` satırı her insan katılımcı için ayrı yazılır).

### Mesajlaşma (Faz 1 sohbet + Faz 2 sessize alma/raporlama)

- [ ] **Buton görünürlüğü.** Board altındaki "Mesajlaşma" butonu YALNIZCA
      Canlı oyun ekranında görünmeli; yerel/YZ oyun ekranında hiç
      çizilmemeli.
- [ ] **İlk açılış tanıtımı.** Bir hesapla o oyunda İLK kez "Mesajlaşma"ya
      dokun: "Oyun içi mesajlaşmaya hoşgeldiniz!" penceresi çıkmalı,
      "DEVAM" → sohbet penceresi açılmalı. Aynı hesapla tekrar aç (başka
      bir Canlı oyunda da olabilir) — tanıtım BİR DAHA çıkmamalı (bayrak
      hesaba özel, oyuna özel değil).
- [ ] **Gönder/al gerçek zamanlı.** İki hesapla (biri web olabilir) aynı
      Canlı oyunu aç, mobilden mesaj gönder → web'de ~1sn içinde görünmeli
      (ve tersi). Mesajlar en YENİ üstte sıralanmalı.
- [ ] **Uyarı pencerelerinin tasarımı (Parça 102).** Yeni mesaj popup'ı,
      sohbet tanıtımı, "Pas Geçiyorsun!", "Tekrar Oyna", "Sınır İhlali!" ve
      arkadaşlık onayları — HEPSİ web'in kartıyla aynı görünmeli: panel
      zemini, yumuşak düşen gölge, yuvarlatılmış köşe, altta MAVİ dolgulu
      kabul + gri nötr vazgeç butonu (Material'ın beyaz kartı ve mavi METİN
      butonları DEĞİL). Kabul butonu her zaman SOLDA. Dar bir telefonda kart
      ekranın iki yanında yalnızca 16px boşluk bırakmalı (eskiden 40'tı).
      Referans görüntü: `mobile/app/build/screenshots/dialog_message_popup.png`.
- [ ] **Popup kapanınca rozet temizlenir (HATA DEĞİL).** Popup çıktıysa
      kapatmak (CEVAP VER / KAPAT — ikisi de) o mesajı okundu sayar, yani
      rozet kalmaz. Bu bilinçli ve web'de de aynı; rozetin kalıcı olduğu tek
      durum susturulmuş göndericidir (popup hiç çıkmaz).
- [ ] **Popup + rozet.** Sohbet KAPALIYKEN karşı taraf mesaj gönderirse
      Board'daki "Mesajlaşma" butonunda **sayı rozeti** + bir popup
      ("CEVAP VER"/"KAPAT") çıkmalı; CEVAP VER sohbeti açmalı. İKİ mesaj
      gelirse rozet **2** göstermeli. Rozet etiketin son harflerini kapatır
      (kabul edilen bedel) ama sağdaki "Nasıl Oynanır?" ile ÇAKIŞMAMALI.
      Sohbet AÇIKKEN gelen mesaj popup AÇMADAN doğrudan listeye eklenmeli.
- [ ] **Popup kendiliğinden KAPANMAZ; zemine dokunmak da kapatmaz
      (Parça 104).** Popup çıktıktan sonra hiçbir şeye dokunmadan bekle —
      kapanmamalı (otomatik kapanma YOK, web'de de yok). Sonra popup'ın
      DIŞINDA bir yere (tahta/başlık) dokun — yine kapanmamalı; kapanmanın
      tek yolu CEVAP VER / KAPAT. **Bu madde 16 Ağustos 2026'da eklendi:**
      Flutter'ın `showDialog` varsayılanı zemin dokunuşuyla kapanmaktı,
      web'de ise popup'ın zemini tıklanamaz. Bildirilen bir hata değil,
      kod incelemesinde bulundu (bkz. `mobile/CLAUDE.md`, Parça 104).
- [ ] **Rozet kalıcılığı (uygulama yeniden başlatma).** Karşı taraf mesaj
      gönderdikten SONRA uygulamayı tamamen kapat, aç, aynı oyuna gir —
      rozet hâlâ görünmeli (okundu damgası `chat_last_read` tablosunda,
      cihaza özel). Sohbeti aç → rozet kaybolmalı; uygulamayı tekrar kapat/aç
      → rozet bir daha ÇIKMAMALI (aynı mesajlar için).
- [ ] **Sessize alma.** Dişli ikonundan bir katılımcıyı seç → "Kişiyi
      Sessize Al" → onay → 🚫 rozeti hem ayarlar listesinde hem o kişinin
      mesaj balonlarının yanında görünmeli. O kişiden yeni bir mesaj
      gelirse **popup AÇILMAMALI** ama **rozet ARTMALI**
      (15 Ağustos 2026 kararı: mute yalnızca popup'ı bastırır) ve mesaj
      sohbet geçmişinde görünmeye devam etmeli. Aynı oyunda
      susturulMAMIŞ başka biri yazarsa hem rozet hem popup çıkmalı
      (4 kişilik bir oyunda kontrol edilebilir). Aynı kişiyle BAŞKA bir
      Canlı oyun aç — sessize alma hâlâ geçerli olmalı (durum kişiye
      bağlı, oyuna değil).
- [ ] **Raporlama.** Bir katılımcıyı raporla (neden yaz → onayla) →
      "Şikayetiniz iletildi." ekranı; kişi otomatik sessize de alınmalı
      (🚩 rozeti). Web admin panelinde Geri Bildirim → Şikayetler
      sekmesinde rapor "Yeni" olarak görünmeli. Raporlanan hesapta
      HİÇBİR iz/bildirim OLMAMALI (bilinçli tasarım).
- [ ] **Rapor geri çekme.** Raporu geri çek → 🚩 kalkmalı, 🚫 (sessize
      alma) AYRI bir durum olduğundan kalmaya devam etmeli (kaldırmak
      istersen ayrıca kapatman gerekir).
      **Geri çekilen rapor admin'in bekleyen işinden DÜŞMEMELİ (14 Ağustos
      2026, Parça 90).** Web admin panelinde Geri Bildirim → Şikayetler:
      kart "Geri Çekildi" rozetiyle görünmeli ama SOLUKLAŞMAMALI, ve hesap
      menüsündeki "Admin Paneli" satırının kırmızı sayacı azalmamalı — geri
      çekme raporlayanın kararı, admin'in incelemesi değil. (Bu davranış 4
      Ağustos'ta yazıldı ama yanlış bir SQL overload'ına uygulandığı için 10
      gün üretimde hiç çalışmadı; bu madde onun ilk gerçek uçtan uca
      kontrolü.)
- [ ] **Çevrimdışıyken davete BASILAMAZ (15 Ağustos 2026'da ölçüldü —
      madde bu yönde DÜZELTİLDİ).** Uçak modunda "Oyun Davetleri" alt
      sekmesi tek bir **"İnternet bağlantısı yok"** ekranı göstermeli;
      davet kartı (dolayısıyla Kabul Et/Reddet) hiç çizilmemeli. Çevrimiçi
      olunca kart geri gelmeli.
      **Bu madde bir dönem "uçak modunda davete bas → 'İşlem başarısız
      oldu.' çıkmalı" diyordu ve YANLIŞTI:** o metin Parça 90'da yazıldı,
      AYNI GÜN Parça 96 sekmeyi çevrimdışı kapısının arkasına aldı ve
      senaryo ulaşılamaz hâle geldi. `kFriendActionFailed` yine de ölü kod
      DEĞİL — bağlantı sinyali "online" derken isteğin düştüğü durumlar
      (captive portal, sunucu/RLS hatası, sekme çizildikten sonra kopan
      bağlantı) hâlâ o dala düşüyor; orada mesaj görünmeli.
      **Arkadaşlık isteklerinin (FriendsModal) yanıtı bu kapının DIŞINDA**
      — orada çevrimdışı gate YOK, bkz. bölüm 10'daki kendi maddesi.
- [ ] **Mesaj balonuna dokunma.** Karşı tarafın bir mesaj balonuna
      doğrudan dokun (rozet olmasa bile) → o kişinin ayarlar detayı
      açılmalı. Kendi mesajına dokununca hiçbir şey olmamalı.
- [ ] **Sohbet arşivi ile tutarlılık.** Oyun bitince (bkz. bölüm 5 "Sohbet
      arşivi") dondurulmuş sohbette de aynı mute/rapor rozetleri (bugünkü
      GÜNCEL duruma göre, o oyundaki değil) görünmeli.

## 12. Hesap Ayarları

- [ ] **Açılış + hidrasyon.** Hesap menüsü → "⚙️ Hesap Ayarları": Ad/
      Soyad/Takma İsim/E-posta/Cinsiyet/Doğum Tarihi alanları profildeki
      GERÇEK değerlerle dolu gelmeli — boş/varsayılan DEĞİL. Pazarlama
      onayı işaretliyse altında "Kabul tarihi: GG.AA.YYYY SS:DD" satırı
      görünmeli.
- [ ] **Ad/Soyad/Takma isim değiştir → Kaydet.** "Profil güncellendi."
      notu çıkmalı; uygulamayı kapatıp aç (ya da webde aynı hesaba gir) —
      yeni değerler kalıcı olmalı, Setup'taki hesap satırı/avatar menüsü
      de yeni ismi göstermeli.
- [ ] **Takma isim benzersizliği.** Başka bir hesabın kullandığı bir isim
      yaz: "Bu takma isim kullanımda." çıkmalı, KAYDET devre dışı kalmalı.
      Kendi mevcut ismini AYNEN yeniden yazarsan kontrol hiç tetiklenmemeli
      ("Kontrol ediliyor…" görünmemeli).
- [ ] **E-posta değişikliği.** Yeni bir e-posta yaz → Kaydet: "E-posta
      değişikliği için onay bağlantısı gönderildi." notu çıkmalı, hesap
      e-postası HENÜZ değişmemiş olmalı (GoTrue onay linkine kadar).
      Yeni adrese gelen onay linkine tıklayınca değişiklik tamamlanmalı.
- [ ] **Profil + e-posta aynı anda değiştirilirse.** İkisini birden
      değiştirip Kaydet'e bas: PROFİL kısmı e-posta adımından önce zaten
      başarıyla tamamlanmışsa, e-posta adımı bir hata verse bile "Profil
      güncellendi." notu KAYBOLMAMALI (ikisi birden görünmeli).
- [ ] **Pazarlama onayı aç/kapa.** Checkbox'ı işaretle → Kaydet → tekrar
      aç (Setup'a dönüp geri gel): işaretli kalmalı, "Kabul tarihi" o anki
      zamanla dolmalı. Kapat → Kaydet → tekrar aç: kabul tarihi satırı
      kaybolmalı (web'in sunucu-taraflı `marketing_consent_at` trigger'ı
      ile aynı davranış — istemci bu alanı hiç göndermiyor).
- [ ] **E-posta bildirimi tercihi.** Kapat → Kaydet → başka bir hesaptan
      kendine bir arkadaşlık isteği/Canlı davet gönder: bildirim maili
      GİTMEMELİ. Şifre sıfırlama gibi zorunlu maillerin hâlâ geldiğini
      doğrula (bu tercihten etkilenmemeli).
- [ ] **Doğum tarihi doğrulaması.** Geçersiz bir tarih (ör. 31/13/1990)
      yaz → Kaydet: Türkçe hata mesajı ("Doğum ayı geçersiz." vb.) çıkmalı,
      hiçbir şey kaydedilmemeli.
- [ ] **Profil fotoğrafı — seçim + izin.** "FOTOĞRAF DEĞİŞTİR"e bas:
      iOS'ta ilk kez galeri izni istenmeli (`NSPhotoLibraryUsageDescription`
      metni Türkçe görünmeli), Android'de doğrudan galeri açılmalı. Galeriyi
      İPTAL edersen hiçbir şey olmamalı (hata/not/YÜKLENİYOR çıkmamalı).
- [ ] **Profil fotoğrafı — başarılı yükleme.** Bir görsel seç: buton kısa
      süreliğine "YÜKLENİYOR…" gösterip devre dışı kalmalı, ardından
      "Profil fotoğrafı güncellendi." notu + YENİ fotoğraf hem bu modalde
      hem Setup/hesap menüsündeki avatarda görünmeli. Uygulamayı kapatıp
      aç (ya da webde aynı hesaba gir) — fotoğraf kalıcı olmalı.
- [ ] **Profil fotoğrafı — DEĞİŞTİRME (13 Ağustos 2026, Parça 82).**
      Zaten avatarı olan bir hesapta fotoğrafı DEĞİŞTİR: 403 /
      "new row violates row-level security policy" ÇIKMAMALI. (20 Temmuz
      2026'da `security_hardening` SELECT politikasını düşürünce bu iki
      platformda da kırılmıştı; `avatars_owner_read` ile düzeltildi —
      `upsert` var olan satırı görmeyi gerektiriyor.)
- [ ] **Profil fotoğrafı — RLS.** Yüklenen dosyanın gerçekten `avatars`
      kovasında `<kendi-uid>/avatar.<ext>` yoluna gittiğini (Supabase
      Dashboard → Storage) doğrula; başka bir kullanıcının klasörüne
      yazma denemesi (varsa bir test aracıyla) RLS tarafından reddedilmeli.
- [ ] **Profil fotoğrafı — önbellek kırma.** Yeni bir fotoğrafla üzerine
      yaz (aynı hesap, ikinci kez "FOTOĞRAF DEĞİŞTİR"): eski fotoğraf
      önbellekte takılı kalmadan YENİ görsel hemen görünmeli (URL'deki
      `?v=` zaman damgası sayesinde).
- [ ] **Profil fotoğrafı — sınır ve küçültme (13 Ağustos 2026, Parça 83).**
      Galeriden GERÇEK bir telefon fotoğrafı seç (2-10 MB — eskiden bunlar
      reddediliyordu): yükleme BAŞARILI olmalı. Ardından Supabase Dashboard
      → Storage → `avatars` → `<uid>/avatar.*` boyutuna bak: **saklanan
      dosya ~50-150 KB olmalı**, seçtiğin megabaytlar DEĞİL (10 MB yalnızca
      giriş sınırı, yükleme küçültmeden sonra yapılıyor). Avatar ekranda
      bulanık/bozuk görünmemeli. 10 MB'ı aşan bir görselde ise "Görsel
      10 MB'den küçük olmalı." hatası çıkmalı, hiçbir şey yüklenmemeli. Bir resim-DIŞI dosya (galeri buna izin veriyorsa)
      seçilirse "Lütfen bir görsel dosyası seç." hatası çıkmalı.
- [ ] **Profil fotoğrafı — HEIC (Android'de KRİTİK, 13 Ağustos 2026,
      Parça 87).** Android'de galeriden bir **HEIC/HEIF** fotoğraf seç
      (iPhone'dan aktarılmış bir görsel ya da kamerası HEIC'e ayarlı bir
      cihazın kendi çekimi): yükleme BAŞARILI olmalı. Öncesinde
      "Lütfen bir görsel dosyası seç." hatası veriyordu — `image_picker`
      görseli JPEG'e yeniden kodlarken uzantıyı `.heic` bırakıyor, eski kod
      uzantıya bakıp dosyayı resim SAYMIYORDU. iOS'ta bu sorun hiç yoktu
      (çıktı her zaman `.jpg`), yine de bir HEIC seçimiyle regresyon
      kontrolü yap. Kovadaki dosyanın `image/jpeg` olduğunu da doğrula.
- [ ] **Profil fotoğrafı — izin REDDİ (13 Ağustos 2026, Parça 87).**
      Ayarlardan uygulamanın galeri/fotoğraf iznini KAPAT, sonra
      "FOTOĞRAF DEĞİŞTİR"e bas: ekranda **"Fotoğraf seçilemedi. Galeri
      izni verildiğinden emin ol."** hatası çıkmalı. Öncesinde HİÇBİR ŞEY
      olmuyordu (ne hata ne yükleniyor göstergesi) — kullanıcı için
      uygulamanın donduğundan ayırt edilemezdi. İzni geri açıp tekrar
      dene: normal akış çalışmalı.

## 13. k-lig ödül & rütbe sistemi (Parça 61-62)

Ödül/rütbe kayıtları SUNUCUDA, `games`e satır ekleyen bir trigger'la
(`games_award_league_rewards`) açılır — yani mobilde bitirilen bir oyun da
ödülü kendiliğinden kazanır. Kutlamanın "bir kez göster" garantisi
`league_rewards.seen_at` ile CİHAZDAN BAĞIMSIZ: webde görülen bir kutlama
mobilde tekrar ÇIKMAMALI (ve tersi). Bu zincirin büyük kısmı otomatik test
edilemiyor (gerçek oturum + gerçek oyun bitişi gerekiyor); web'in aynı
listesi kök `TESTING.md` bölüm 10.

- [ ] **Dokuz kademe, doğru eşik/ödül/renk (Parça 62).** Bilgi popup'ında
      ve mühürde gösterilen kademe şu tabloyla BİREBİR uyuşmalı — üç kopya
      (SQL / `leagueRank.ts` / `league_rank.dart`) elle senkron olduğundan
      biri sapmışsa burada görünür:

      | Kademe | Harf | Eşik | Ödül | Renk |
      |---|---|---|---|---|
      | Çaylak | Ç | 0 | — | gri |
      | Meraklı | M | 50 | +5 | mavi |
      | Oyuncu | O | 100 | +10 | yeşil |
      | Usta | U | **250** | +25 | altın |
      | Şampiyon | Ş | 500 | +50 | turuncu |
      | Destan | D | 1000 | +100 | kırmızı |
      | Efsane | E | 2500 | +250 | çivit |
      | Uzaylı | **Z** | 5000 | +500 | camgöbeği |
      | Kozmik | K | 10000 | +1000 | parlak altın |

      Üç şeye ayrıca bak: (a) Uzaylı'nın harfi **Z** (U DEĞİL — o Usta'da);
      (b) üç yeni rengin (çivit/camgöbeği/parlak altın) mühürde ve ilerleme
      çubuğunda birbirinden ayırt edilebildiği; (c) **Kozmik EN ÜST** —
      o kademede ilerleme çubuğu HİÇ çizilmemeli, Destan'da ise Efsane
      (2500) hedefiyle çizilmeli.
- [ ] **"Nasıl Oynanır?" ekranında rütbe bölümü (Parça 66).** Detaylı
      Kurallar'da, "Skor Kartı ve Puanlama"nın hemen altında **"Rütbeler ve
      Ödüller"** başlıklı bir bölüm olmalı: dokuz kademe alt alta, her
      satırda kademe renginde harf + ad + eşik + (Çaylak hariç) yeşil
      "(ödül +N)". Tablo `league_rank.dart`'tan ÜRETİLİYOR, elle
      yazılmıyor — yukarıdaki tabloyla BİREBİR aynı olmalı; ayrışırsa
      biri elle yazılmış demektir. Bölümde ödülün hayatta bir kez
      verildiği, rütbenin düşebileceği ve Kozmik'in en üst kademe olduğu
      yazmalı; "Skor Kartı ve Puanlama"nın sonunda da -2 cezasının iki
      kaynağı (Canlı 48 saat, yerel 7 gün) geçmeli. **Web'de birebir aynı
      bölüm var** (kök `TESTING.md` bölüm 10) — iki ekran ayrışmamalı.
- [ ] **Bölüm başlıkları BÜYÜK HARF (aynı turda düzeltildi).** Detaylı
      Kurallar'daki ON bölüm başlığı da ("PUAN TABLOSU", "BÖLGE VERGİSİ",
      "RÜTBELER VE ÖDÜLLER"…) web gibi büyük harfli olmalı — port bunu
      Parça 10'dan beri küçük harf çiziyordu. Türkçe kurala dikkat:
      "NASIL OYNANIR?" (noktalı İ DEĞİL) ve "BÖLGE VERGİSİ" (sondaki İ
      noktalı) — biri ters çıkarsa `trUpper` yerine native `toUpperCase`
      kullanılmış demektir.
- [ ] **Başlık emojileri (12 Ağustos 2026, Parça 70).** Rütbe
      yükselince **👏** ("Yeni rütben: X! 👏"), 100'lük kilometre
      taşında **🎉**, düşüşte **😔**. Üçü de GERÇEK emoji olmalı, boş
      kare (tofu) DEĞİL. (Yalnızca "Eşik ödülü kazandın!" varyantı
      emojisiz — bilinçli.)
- [ ] **Kart HER varyantta aynı genişlikte (280) ve ✕ kartın İÇİNDE.**
      Kutlama, kilometre taşı ve düşüş banner'larını yan yana koy:
      kart genişliği değişmemeli ve ✕ hiçbirinde kartın dışına
      taşmamalı. (İlk sürümde kutlama kartı içeriğe göre 238px'e
      büzülüyor ve ✕ dışarıda kalıyordu — web'de kart her zaman 280.)
- [ ] **Kutlama banner'ı bir kez çıkar.** Görülmemiş bir ödülün varken
      (test için bir satırın `seen_at`'i SQL'le null'a çekilebilir)
      uygulamayı aç: mühür damgalı, konfetili banner ekranın ORTASINDA,
      karartılmış arka planla çıkmalı. "DEVAM"dan sonra uygulama yeniden
      başlatılsa da, **web'den girilse de** bir daha çıkmamalı.
- [ ] **Banner oyun ortasında çıkmaz.** Devam eden bir YZ/Canlı oyunun
      tahtasındayken banner asla belirmemeli. Oyun bitince (GameOver
      modalı + Görüş Bildir formu kapatıldıktan sonra — banner onların
      ALTINDA duruyor, web'de de öyle) kendiliğinden görünmeli.
- [ ] **Setup'a dönünce de görünür.** Oyunu bitirmeden logoya basıp
      Setup'a dön: orada bekleyen kutlama varsa çıkmalı (Setup'ın host'u
      oyun ekranı pop edilince yeniden etkinleşir).
- [ ] **Birleşik özet.** Aynı anda birden fazla görülmemiş kayıt varken
      TEK banner çıkmalı: rütbe varsa başlık rütbe, ödül puanı yeşil
      satırda TOPLAM olarak.
- [ ] **Mühür üç yerde ve aynı kademede.** k-lig listesi satırları (18px),
      Skor Kartı ve başka bir oyuncunun kartı (34px, başlık ile ✕ ARASINDA
      ortalı, yazısız). Üçü de GÜNCEL toplam puandan türetildiğinden aynı
      kademeyi göstermeli.
- [ ] **Mühür artık İSİMLERİN yanında da — yedi yüzey (18 Ağustos 2026,
      Parça 115).** Hepsinde ismin SAĞINDA, isimle aynı dikey merkezde ve
      satırın puntosuna göre boyutlanmış olmalı: hesap menüsünün başlığı
      (18px) · Skor Kartı'ndaki kendi ismin (20px) · başka bir oyuncunun
      kartı (20px) · Setup'ta 1. koltuktaki hesap adı (18px) · Arkadaşlar
      modalının ÜÇ sekmesi de (18px — "Arkadaşlarım", "İstekler",
      "Ara & Ekle") · "+ Yeni Canlı Oyun" arkadaş seçici (18px) · Oyun
      davetleri kartındaki katılımcı isimleri (16px). **Skor kartlarında
      artık İKİ mühür var** — başlıktaki 34px'lik tıklanabilir mühür VE
      ismin yanındaki 20px'lik; ikisi AYNI kademeyi göstermeli.
- [ ] **"Puan bilinmiyor" ile "0 puan" AYRI (aynı parça).** Hiç oyun
      bitirmemiş bir kullanıcının yanında **Çaylak (Ç)** mührü çıkmalı
      (o gerçekten 0 puan). Ama liste ilk açılırken, puanlar gelmeden bir
      an için HERKESİN yanında Çaylak mührü BELİRMEMELİ — mühür yalnızca
      puan bilindikten sonra çizilir. YZ koltuklarında ve misafirde mühür
      HİÇ olmamalı.
- [ ] **Rozet: dalgalı disk + iki kurdele kuyruğu (18 Ağustos 2026 — eski
      tırtıklı/noter mührü TAMAMEN bırakıldı).** Her boyda AYNI siluet:
      dolu, dalgalı kenarlı bir disk + altında V kesikli iki kurdele;
      kurdele diskten bir tık KOYU. Testere dişli eski mühür HİÇBİR yerde
      kalmamalı. Fark yalnızca iç halkada: 34/76px'te harfin etrafında
      açık renkli ince bir halka VAR, 18px'lik k-lig satırında YOK (harf
      orada daha büyük). Banner'ın rakamlı glyph'lerinde ("+1000") halka
      hiçbir boyda çizilmez. **Web'deki rozetle yan yana bak — ikisi
      BİREBİR aynı olmalı** (aynı sabitler iki dosyada elle senkron).
- [ ] **Harfin yazı tipi: M PLUS Rounded 1c 800 (18 Ağustos 2026 — öncesi
      Space Grotesk).** Harf yuvarlak hatlı ve basık görünmeli. **Portta
      asıl risk TOFU:** Flutter otomatik font fallback YAPMAZ, yani alt
      kümede olmayan bir glyph BOŞ KARE olarak çizilir — özellikle Ç ve Ş
      mühürlerine bak. Rakamlı banner glyph'i ("+1000") madalyonun dışına
      TAŞMAMALI. Web'deki rozetle yan yana bak: aynı font, aynı punto.
- [ ] **Harf dikeyde ortalı — kuyruklu olanlar dahil.** Ç ve Ş (sedillalı)
      mühürlerde harf, dairenin dikey ORTASINDA durmalı — alta kaçmış
      GÖRÜNMEMELİ. Ç ile M/O/U/D aynı hizada olmalı. Üç boyu da kontrol et
      (18px k-lig satırı, 34px kart başlığı, 88px banner). Web'deki aynı
      mühürle yan yana bak: iki platform BİREBİR aynı hizada olmalı
      (`sealBaselineEm` ↔ web `baselineY`, ikisi elle senkron).
- [ ] **Mühür popup'ı.** Skor Kartı başlığındaki mühre dokun: damga
      animasyonuyla bilgi popup'ı açılmalı (kademe adı + puan + "+N eşik
      ödülü dahil" + sıradaki rütbe hedefi + hedefe AKAN ilerleme çubuğu;
      en üst kademede çubuk yok). İstendiği kadar tekrar açılabilmeli —
      kutlamanın aksine "bir kez göster" kuralı YOK.
- [ ] **✕ var, "KAPAT"/"DEVAM" butonu YOK — popup'ta DA banner'da DA.**
      (12 Ağustos 2026, kullanıcı: "bu banner'larda kapat, devam vb
      olmamalı, sadece X". Önce yalnızca popup'a uygulanmıştı, aynı gün
      kutlama/düşüş banner'ına da genişletildi.) Kapatma yalnızca sağ
      üstteki ✕ ile; kartın altında tam genişlikte bir buton OLMAMALI.
      **KRİTİK — ✕ yalnızca kapatmıyor:** banner'da ödülleri "görüldü"
      işaretleyen tek yol o. Kapattıktan sonra uygulamayı yeniden başlat:
      banner **BİR DAHA ÇIKMAMALI**. Çıkıyorsa ✕ `markSeen`'e bağlanmamış
      demektir (bilgi popup'ında ise tam tersi doğru: o hiçbir şeye
      dokunmaz, istendiği kadar açılır).
- [ ] **Kart gölgesinde beyaz hale yok.** Hem bilgi popup'ının hem
      kutlama/düşüş banner'ının kartı karartılmış zeminde yalnızca
      yumuşak, koyu bir düşen gölge taşımalı — sol/üst kenarda beyaz bir
      parıltı GÖRÜNMEMELİ. Mührün kendi 88px'lik dairesi nömorfik
      kalmaya devam eder (o doğru). İkisi aynı kart: biri değişirse öteki
      de kontrol edilmeli.
- [ ] **Rozet renk kuralı.** İlerleme çubuğunun altında: ALINMIŞ ödül
      YEŞİL "(+5)" + onay işareti, henüz alınmamış hedef ödülü GRİ "(+10)"
      ve onay işareti YOK. Onay işareti gerçekten bir tik olarak
      görünmeli — boş kutu (tofu) DEĞİL (Space Mono bu glyph'i içermiyor,
      port Material ikonunu kullanıyor).
- [ ] **Rütbe düşmeli.** -2 ceza alıp eşiğin altına inen hesabın mührü üç
      yerde de bir alt kademeye İNMELİ. Puan tekrar eşiği aşarsa damga
      geri gelir ama kutlama İKİNCİ kez ÇIKMAMALI, ödül İKİNCİ kez
      VERİLMEMELİ.
- [ ] **Rütbe düşüş banner'ı.** Konfetisiz, üzgün banner ("Rütben
      geriledi! 😔 … Kazandıkça geri yükselirsin!") — **başlıktaki üzgün
      emoji GERÇEK emoji olmalı, boş kare (tofu) DEĞİL.** Boş kare
      görürsen `fontFamilyFallback` düşmüş demektir. Not: web test
      derlemesinde (CanvasKit) emoji ağdan çekilir; ağ kısıtlıysa boş
      görünebilir — bu native'de YAŞANMAZ, FAZ B'de kesin doğrula.
      Banner'da ayrıca kaybedilen eşiğe geri
      dönüş çubuğu; hedef etiketi YALNIZCA SAYI ("100" — "puan" kelimesi
      yok, o zaten bir üstteki "Sıradaki rütbe" satırında geçiyor) ve
      altında yeşil "(+10)"+tik (ödül zaten alındı). Görülmemiş OLUMLU
      bir kutlamayla çakışırsa yalnızca olumlu olan gösterilmeli.
      **Test satırını uygulama KAPALIYKEN ekle** — açıkken eklersen host
      bir sonraki öne-dönüş/kontrolünde banner'ı beklenmedik bir anda
      gösterir, refleksle kapatılır ve kayıt "görüldü" işaretlenir
      (12 Ağustos 2026'da tam bu oldu: satır 20:50'de eklendi, 20:51'de
      kapatıldı, sonra "banner çıkmadı" diye raporlandı — kayıt çoktan
      harcanmıştı). Kod tarafında SESSİZ bir işaretleme yolu yok:
      `markSeen` yalnızca gösterilen bir banner kapatılınca çağrılıyor.
- [ ] **Misafirde hiç çıkmaz.** Girişsizken oyun bitir: banner
      görünmemeli, hiçbir ağ isteği atılmamalı. Sonradan giriş yapınca
      (kuyruk sunucuya işlendikten sonraki ilk kontrolde) kutlama
      çıkabilir.
- [ ] **Uçak modu.** Ağ yokken banner çıkmamalı ve uygulama hiç
      takılmamalı; ağ dönüp uygulama öne alınınca (arka plandan dönüş)
      bekleyen kutlama kendiliğinden gösterilmeli.
- [ ] **Web ↔ mobil aynı toplam.** Aynı hesabın "Genel" lig puanı iki
      platformda BİREBİR aynı olmalı ("Genel = 2 kişilik + 4 kişilik +
      eşik ödülü" — mod bazlı sekmelerin toplamı ödül kadar EKSİK olur,
      bu doğru; fark popup'taki "+N eşik ödülü dahil" satırıdır).

---

## 14. Hata telemetrisi (Parça 123)

Uygulamada doğan hatalar anonim olarak `client_errors` tablosuna yazılıyor
(hesap kimliği YOK). Portta okuma yüzeyi HİÇ YOK — kontrol web'deki Admin
Paneli → **Hatalar** sekmesinden yapılır (kök `TESTING.md` bölüm 9.12).

Bu bölümün tamamı **telemetrinin ÜRÜNÜ BOZMADIĞINI** doğrulamak içindir;
kayıtların panelde görünmesi ikincil.

- [ ] **Uçak modunda uygulama normal çalışıyor.** Çevrimdışıyken yerel/YZ
      oyunu oyna, Setup'a çık, gir — hiçbir yavaşlama/donma/ek uyarı
      olmamalı. Telemetri ağ hatasında sessizce vazgeçmek zorunda.
- [ ] **Çevrimdışı hamleler panelde İZ BIRAKMIYOR.** Uçak modunda bir Canlı
      oyunda hamle dene (ekranda "sunucuya ulaşılamıyor" uyarısı çıkar) →
      web panelinde bu yüzden YENİ bir hata satırı ÇIKMAMALI. Bu BEKLENEN
      bir durum; çıkıyorsa filtre bozulmuştur ve panel kısa sürede
      okunamaz hâle gelir.
- [ ] **Sunucunun kendi reddi de iz bırakmıyor.** Sırası sende değilken bir
      hamle göndermeye çalış ("Sıra sende değil.") → yeni satır olmamalı.
- [ ] **Panelde görünen kayıtların platformu doğru.** Gerçek bir hata
      düştüyse `ios`/`android` (Flutter web'de `app-web`) olmalı, `web`
      DEĞİL — `web` React uygulamasına ait.
- [ ] **Derleme kimliği dolu.** CI'dan kurulan bir derlemede kayıttaki
      `build`, Setup teşhis satırındaki sha ile AYNI olmalı. Boşsa
      "hangi sürümde?" sorusu cevapsız kalır — telemetrinin yarısı gider.
- [ ] **Yol her kayıtta `app`.** Portta ekran adı/token taşınmıyor.
- [ ] **Kırmızı ekran hâlâ çalışıyor** (debug derlemede): `FlutterError`
      yakalayıcısı raporu gönderirken ÖNCEKİ davranışı da çağırmalı, yani
      konsol logu/kırmızı ekran kaybolmamalı.

---

## 15. Canlı liste — düşen istek (21 Ağustos 2026)

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

## 16. Oyundan Setup'a dönüş — "← Geri" (21 Ağustos 2026)

- [ ] **Görünür:** Oyun ekranında logonun hemen altında ince, koyu bir
      "← Geri" yazıyor ve tahtanın sol kenarıyla hizalı duruyor.
- [ ] **Dokunuş:** Logoya dokunmak Setup'a döndürüyor. (Uygulamada etiketin
      KENDİSİ dokunuş almaz — webden bilinçli sapma, kod yorumunda gerekçesi
      yazılı; etiket logoyu gösteren bir ipucu.)
- [ ] **Header bozulmadı:** Skor kutuları logoyla aynı hizada; tahta
      eskisine göre gözle görülür şekilde aşağı kaymadı.
- [ ] **4 kişilik + girişli hesap:** Avatar/GİRİŞ ile etiket çakışmıyor,
      skor kutuları kırpılmıyor (dar telefonda da).
- [ ] **Canlı oyunda da var:** Aynı etiket Canlı oyun ekranında da
      görünüyor ve oradan Canlı listesine döndürüyor.

## 17. Giriş varsayılanı — hangi sekme açılıyor (21 Ağustos 2026)

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

## 18. Telemetri — sürüm ve ekran adı (23 Ağustos 2026, Parça 130)

Cihazda koşulur; karşılığı admin panelinin "Hatalar" sekmesi ve
Büyüme > Kullanıcı > "Sürüm Dağılımı" tablosu.

- [ ] **Sürüm satırı doğru:** Setup'ın altındaki `Sürüm 1.0.0` metni
      `pubspec.yaml`taki sürümle aynı olmalı. (Ayrışırsa CI zaten düşer —
      `app_version_parity_test.dart` — ama cihazda bir kez gözle bak.)
- [ ] **Bir YZ oyunu aç** → panelde Sürüm Dağılımı tablosunda `ios · 1.0.0`
      (ya da `android · …`) satırı belirmeli. Satır `bilinmiyor` çıkıyorsa
      `logGameStart` platform/sürüm göndermiyor demektir.
- [ ] **Ekran adı:** oyun ekranındayken bir hata oluştur (ör. uçak modunda
      Canlı bir oyuna gir) → hata kaydının "Yol" alanı `game` /
      `online-game` / `intro` olmalı, `app` DEĞİL. `app` görünüyorsa ya
      gözlemci takılı değil ya push'ta `RouteSettings(name: …)` unutulmuş.
- [ ] **Zorunlu güncelleme kapısı hâlâ çalışıyor:** `app_config`taki eşiği
      geçici olarak uygulamanın sürümünün ÜSTÜNE çek → güncelleme ekranı
      çıkmalı; geri al → normal açılmalı. (Sürüm sabiti bu kapının girdisi;
      parite testi tam bunu koruyor.)

## Web derlemesi (ücretsiz tarayıcı test ortamı)

**Adres:** `https://alpcapa.github.io/kelimeki/` — `main`e giren her mobil
değişiklikte kendiliğinden güncellenir (`.github/workflows/mobile-build.yml`,
`web` işi). PR'lardan deploy EDİLMEZ: burada gördüğün şey her zaman merge
edilmiş koddur.
Süre limiti yok, kurulum yok, iPad Safari'de doğrudan açılır.

**Neden var:** geliştiricinin elinde ne Mac ne Android cihaz var; Apple
Developer üyeliği askıda (TestFlight yok) ve Appetize'ın ücretsiz katmanı
3 dakikayla sınırlı. Flutter'ın web hedefi **aynı Dart kodunu aynı çizim
motoruyla** (CanvasKit) koşturuyor — yani yukarıdaki listenin büyük
bölümü burada gerçekten koşulabilir.

**Burada koşulabilen bölümler:** 1 (oyun çekirdeği), 2 (auth), 3 (bulut
kayıtları), 4 (biten oyun kayıtları), 5 (oyun geçmişi), 7 (Son
Oynadıklarım), 12 (Hesap Ayarları — profil fotoğrafı hariç, o zaten
salt-okunur/platform bağımsız). Hepsi saf Dart + ağ; platform kanalı
gerektirmiyorlar.

### Web derlemesiyle neyi test EDEMEZSİN

Bunları "geçti" saymak bir hatayı gizler — hepsi hâlâ gerçek cihaz ister.
Cihaza geçince koşulacak liste aşağıda ayrı bir bölüm: **"FAZ B — cihaza
özel tur"** (orada ayrıca iOS/Android arasında FARKLI olabilecek maddeler
ve platform başına tek seferlik ön koşullar var).

- **Android izinleri — sunucuya dokunan HER madde (24 Ağustos 2026'da
  ölçüldü).** Web derlemesinde Android izin modeli hiç yok, debug APK ise
  `INTERNET`i debug manifestinden otomatik alıyor; yani "web'de giriş
  yapabiliyorum" release APK hakkında HİÇBİR ŞEY kanıtlamıyor. Gerçekten
  yaşandı: izin `main/` manifestinde yoktu ve release APK'da giriş
  `Failed host lookup: … (No address associated with hostname, errno = 7)`
  veriyordu (Parça 131). Mesaj DNS hatasına benziyor — o yüzden bu hatayı
  görürsen önce izni, sonra ağı şüphelen. Artık CI birleşmiş manifesti
  okuyup zorluyor, ama kural aynı: **auth/Canlı oyun/k-lig/sohbet
  maddelerinin hepsi ilk kez gerçek cihazda koşulmalı.**
- **Bölüm 6 (Paylaşma).** `share_plus` web'de tarayıcının Web Share
  API'sine düşer; iOS/Android'in native paylaş sayfası DEĞİL. Görsel
  yakalama + dosya eki davranışı farklı.
- **Bölüm 8 (Uçak modu / dayanıklılık).** Tarayıcının ağ/önbellek
  semantiği native'inkiyle aynı değil; işletim sisteminin uygulamayı
  arka planda öldürmesi de burada yok.
- **Bölüm 0'ın "ilk açılış"ı.** Splash, portre kilidi (`SystemChrome`),
  uygulama ikonu — hiçbiri web'de geçerli değil.
- **Oturum kalıcılığı.** `supabase_flutter` web'de token'ı farklı bir
  depoda tutuyor; "uygulamayı tamamen kapat, hâlâ girişli ol" maddesi
  native davranışı kanıtlamaz.
- **Depolama arka ucu.** Web'de native SQLite yok; `sqflite_common_ffi_web`
  (WASM sqlite3 + IndexedDB) devrede (bkz. `lib/src/storage/web_db.dart`).
  Şema/sorgu/store kodu aynı, ama "gerçek cihazda SQLite dosyası çökme
  anında tutarlı mı" sorusu burada yanıtlanmaz.
- **Gerçek dokunmatik jestler.** Sürükle-bırağın parmak altındaki hissi,
  30px kaldırma, jest çakışmaları — fare/trackpad ile ölçülemez.
- **Performans.** Farklı derleyici (dart2js), farklı GPU yolu.
- **Yükseklik oranına bağlı her ölçü (`vh` ↔ `MediaQuery.height`).**
  17 Ağustos 2026'da k-lig modali web ile yan yana konunca web 10 satır
  gösterirken port 8,5 gösteriyordu. Kabuk değerlerinin HEPSİ eşleşiyor
  (360 · %85 · yarıçap 12 · gövde dolgusu · liste sınırı %50) — fark, aynı
  "%50"nin iki tarafta FARKLI bir yüksekliğe uygulanmasından: Safari `vh`'yi
  tarayıcı çubukları DAHİL düzen viewport'una göre çözüyor, Flutter ise
  `MediaQuery.sizeOf(context).height` ile görünen tuvali alıyor. Ölçüldü
  (kartın 360px'i ölçek referansı): web 558 / port 510 CSS px.
  **Bunu bulgu olarak açma ve portu Safari'ye uydurma** — native derlemede
  tarayıcı çubuğu olmadığından iki taraf zaten aynı yüksekliğe çözülür;
  uydurmak native'i BOZAR. Gerçek karşılaştırma FAZ B'de, cihazda yapılmalı.

### İlk açılışta doğrula

- [ ] Sağ üstte **GİRİŞ** butonu ve altbilgide **"sunucu bağlı"** — ikisi
      de varsa Supabase sırları derlemeye gömülmüş demektir.
- [ ] Altbilgide **"Sözlük: 63890 kelime"** (yükleniyor'da takılı kalmamalı).
- [ ] **OYUNU BAŞLAT** çalışıyor ve tahta çiziliyor — depolama katmanı
      (IndexedDB) kurulmuş demektir. "KAYITLAR KONTROL EDİLİYOR…" takılı
      kalırsa web depolama arka ucu bozulmuştur.
- [ ] **Tahtadaki boş hücreler "gömük" görünüyor** (her karenin sol-üstü hafif
      koyu, sağ-altı hafif parlak — nömorfik oyuk); hücreler DÜZ/tek renk
      görünüyorsa CanvasKit özel çizimi bozulmuş demektir. Bu, `flutter test`'in
      YAPISAL OLARAK göremediği bir hata sınıfı (testler native Skia ile render
      eder, tarayıcı CanvasKit ile) — bir kez gerçekten yaşandı, bkz.
      `mobile/CLAUDE.md` Parça 18. Aynı kontrol altın X2 bölgesi ve köşe
      bölgeleri için de geçerli: soluk/yıkanmış görünmemeliler.

---

## FAZ B — cihaza özel tur (iOS + Android)

**Bu bölüm FAZ A1'i TEKRARLAMAZ.** Yukarıdaki bölümlerin büyük kısmı web
derlemesinde koşuldu ve geçti; kod tek bir Dart tabanında olduğundan o
düzeltmeler (Parça 15-47) İKİ platformda da zaten geçerli. Burada yalnızca
**web derlemesinin yapısı gereği kanıtlayamadığı** ve/veya **iki platformda
FARKLI davranabilecek** şeyler var.

**Neyi tekrar koşmayacaksın:** oyun kuralları/motor (golden vector'larla
kanıtlı), yerleşim/gölge/punto paritesi (ölçülerek kapatıldı), veri
katmanı mantığı (299 test + gerçek Supabase ile 8.1-8.8), auth akışları.
Bunlarda cihaza özgü bir risk yok — bir fark görürsen o zaten YENİ bir
bulgudur, tekrar değil.

### Ön koşullar (platform başına, TEK SEFERLİK — henüz hiçbiri yapılmadı)

| | Android | iOS |
|---|---|---|
| İmzalama | anahtar üret + `key.properties` | Apple Developer üyeliği + sertifika |
| Dağıtım | APK/Play Internal Testing | TestFlight (bkz. bir alttaki bölüm) |
| Universal/App Links | sitede `/.well-known/assetlinks.json` yayınla (imza SHA-256 gerekir) | `associated domains` entitlement + sitede `apple-app-site-association` |

`kelimeki://` özel şeması İKİSİNDE de HAZIR (manifest + Info.plist) ve
imza/site dosyası GEREKTİRMEZ — yani şifre sıfırlama derin bağlantısı
(madde 9-12) yukarıdaki üç satır beklemeden, uygulama cihaza kurulur
kurulmaz test edilebilir. `https://kelimeki.com/davet/...` biçimindeki
davet linkleri ise ancak assetlinks/AASA yayınlandıktan sonra uygulamayı
açar; o zamana kadar tarayıcıda açılırlar (bozuk değil, yalnızca eksik).

### Appetize triyajı — ne KANITLAR, ne kanıtlaMAZ (17 Ağustos 2026)

Ön koşulların üçü de (Apple üyeliği, Android cihaz, imzalama anahtarı)
henüz açık değil; gerçek tur ertelendi. Bu arada Appetize'da neyin
koşulabileceği aşağıda ayıklandı. **Bir maddenin "gerçek cihaz ister"
olması Appetize'ın değil MADDENİN kendi özelliği** — bu yüzden liste
kaynaktan çıkarılabildi, emülatöre girmeden.

**İki taraf aynı şey DEĞİL** (`.github/workflows/mobile-build.yml`):
Android'e gerçek bir `.apk` yükleniyor (emülatör), iOS'a ise
`flutter build ios --simulator --debug` çıktısı — yani **iOS tarafı DEBUG
bir simülatör derlemesi.** Performansla ilgili hiçbir şey orada
ölçülemez; Android emülatörü de gerçek GPU değil.

**3 dakikalık sınır bir kısıt değil bir PLANLAMA gereği:** her oturum TEK
bir kümeyi hedeflemeli, adımlar önceden yazılmalı. "Girip bakarım" 3
dakikada hiçbir şey bitirmiyor.

| Madde | Appetize | Not |
|---|---|---|
| İkon / splash / portre kilidi | ✅ | Android adaptive maske launcher'a göre değişir; emülatörü yatay çevirip aç |
| 🤖 robot avatarı + ❓⚙️👥📊🚪 + 🏆 | ✅ **değerli** | Parça 29'un CanvasKit ağ bağımlılığı native'de YOK; iOS ile Android'in emoji görüntüsü farklıdır ve bu hata DEĞİL |
| Setup teşhis satırı `depo ok` | ✅ **değerli** | Tek bakışta Parça 45'in native sqflite kanalını kanıtlıyor (web'de WASM ağdan geliyordu) |
| Uçak modunda kelime anlamı | ✅ | `meanings.db` pakette; Android emülatöründe uçak modu ayarlardan açılabilir |
| Android geri tuşu / geri jesti | ✅ | Kodda `PopScope` HİÇ yok, hiç denenmedi — emülatör bunu tam karşılıyor |
| Galeri izni REDDİ (Türkçe hata) | ✅ | İzin diyaloğu emülatörde gerçek |
| iOS güvenli alan (çentik / Dynamic Island) | 🟡 | Simülatörde cihaz tipi seçilebiliyorsa; panelden bak |
| Paylaş sayfası açılıyor mu | 🟡 | Sayfa açılır ama hedef uygulama yok — "eki taşıyor mu" kısmen görülür |
| Oturum kalıcılığı | 🟡 | Uygulamayı öldürüp açmak emülatörde olur, ama Appetize OTURUMU bitince her şey sıfırlanır — ikisini karıştırma |
| Klavye / Türkçe karakterler | 🟡 | Emülatör klavyesi gerçek IME değil |
| Soğuk başlangıç `kelimeki://davet/<token>` | ❓ | Appetize'ın "launch URL" parametresi varsa koşulabilir — **doğrulanmadı**, panelden bakılmalı |
| **iPad paylaş popover ankrajı (Parça 86)** | ❌ | Maddenin kendisi "iPhone'da test edilse bile KANITLANMAZ" diyor; iPad cihaz tipi şart |
| **Sürükle-bırak hissi / performans** | ❌ | Emülatör GPU + iOS DEBUG derlemesi; ölçüm anlamsız, yanlış güven verir |
| **HEIC avatarı** | ❌ | Emülatör galerisinde HEIC dosyası yok; gerçek fotoğraf gerekiyor |
| **Sözlük yükleme SÜRESİ** | ❌ | "Yükleniyor mu" sorusu ✅, "ne kadar sürüyor" ❌ |
| assetlinks / AASA sonrası davet linki | ⛔ | Ön koşula bloke (imzalama anahtarı / Apple üyeliği) |

**Cihaz beklemeden yapılabilecek tek gerçek hazırlık, bilerek YAPILMADI:**
Android imzalama anahtarı. Sebebi teknik değil: bu ÜRETİM imzalama
anahtarı ve kaybedilirse uygulama Play Store'da **bir daha asla
güncellenemez**. Üretilmesi, yedeklenmesi ve GitHub secret'larına
konması hesap sahibinin kendi kararı olmalı; bir oturum bunu kendiliğinden
üretmemeli. `assetlinks.json` de onun SHA-256'sına bağlı olduğundan
sırayla o beklemede.

### Appetize koşu planları — 3 dakikaya göre YAZILMIŞ (17 Ağustos 2026)

Ücretsiz katman oturumu **3 dakikada** kesiyor ve her oturum SIFIRDAN
açılıyor: oturum kapanınca giriş de gidiyor. Bu yüzden "girip bakarım"
hiçbir şey bitirmiyor — aşağıdaki koşular önceden yazıldı ve **girişsiz
olanlar önce**, çünkü e-posta/şifre yazmak 3 dakikanın büyük kısmını
yiyor.

**Koşu 1 — açılış kimliği (girişsiz, Android):**
1. Launcher'da **ikon** (adaptive maske launcher'a göre değişir), sonra
   **splash**.
2. Emülatörü **yatay** çevirip aç → portre kilidi tutmalı.
3. Setup'ın en alt satırı: `Derleme <sha> · … · **depo ok**` — tek
   bakışta Parça 45'in native sqflite kanalını kanıtlar (`DEPO YOK`
   yazıyorsa dur, kalan maddeler anlamsız). Sha'yı da not al: hangi
   derlemeye baktığın buradan okunur.
4. **Android geri tuşu + geri jesti** — kodda `PopScope` HİÇ yok, hiç
   denenmedi: Setup'ta uygulamadan çıkıyor mu, modal açıkken modalı mı
   kapatıyor?

**Koşu 2 — oyun + emoji + anlam (girişsiz, Android):**
1. Setup → "Nasıl oynanır?" → Hızlı Başlangıç: **🎯 🏠 🔗** tofu (boş
   kare) DEĞİL. Native'de Parça 29'un CanvasKit ağ bağımlılığı YOK — bu
   koşunun asıl kanıtı bu.
2. Yeni YZ oyunu (2 kişilik) → birkaç hamle → **joker** koy: seçici
   ortalanmış kart (alttan sayfa DEĞİL), hücreler makul boyda.
3. Onaylanmış bir taşa dokun → **kelime anlamı** gelmeli. Sonra uçak
   modunu açıp tekrar dene: yine gelmeli (`meanings.db` pakette — web
   derlemesinde gelmiyordu, fark tam burada görünür).
4. Logoya bas → Setup'ta "Devam Eden Oyun" satırında **🤖** robot
   avatarları.

**Koşu 3 — hesap (girişli, Android):** giriş bilgilerini panoya önceden
kopyala; oturumun ilk 30 saniyesi giriş yapmaya gider.
1. Hesap menüsü: **👥 📊 ❓ ⚙️ 🚪** — beşi de tofu değil, satırlar tek
   satırda (Parça 30).
2. Hesap Ayarları → "Fotoğraf Değiştir" → izin diyaloğunu **REDDET** →
   Türkçe hata çıkmalı ("Fotoğraf seçilemedi. Galeri izni verildiğinden
   emin ol.", Parça 87). İzni verip HEIC bir dosya seçmek ayrı bir
   koşu — emülatör galerisinde HEIC yoksa bu madde **atlanır** (gerçek
   cihaz işi).

**Koşu 4 — iOS (simülatör):** burada **hiçbir performans/akıcılık
maddesi koşulmaz** — derleme `--simulator --debug`.
1. Güvenli alan: çentik/Dynamic Island header'ı kırpıyor mu (panelde
   cihaz tipi seçilebiliyorsa iPhone 15 Pro).
2. Paylaş: oyun geçmişinde bir kartı aç → Paylaş → **sayfa açılıyor mu**
   (hedef uygulama yok, "eki taşıyor mu" ancak kısmen görülür).
3. **iPad seçilebiliyorsa** Parça 86'nın popover ankrajı — seçilemiyorsa
   bu madde FAZ B'de kalır, iPhone'da koşmak KANITLAMAZ.

**Panelden bakılacak tek şey:** Appetize'ın "launch URL" parametresi
varsa `kelimeki://davet/<token>` soğuk başlangıcı koşulabilir
(doğrulanmadı). Yoksa deep link maddelerinin tamamı FAZ B'ye kalır.

### Her iki cihazda da koşulacak (aynı madde, iki kez)

- [ ] **Bölüm 0 — ilk açılış:** uygulama ikonu (adaptive maske Android'de
      launcher'a göre değişir), splash, portre kilidi (cihazı yatay tutup
      aç — native kilit ekranı döndürmemeli), sözlük yükleme süresi.
- [ ] **Bölüm 6 — paylaşma:** native paylaş sayfası GERÇEKTEN açılmalı ve
      görsel eki taşımalı. Web derlemesinde dosyalı yol hiç çalışmıyordu
      (yalnızca metin+link yedeği), yani bu madde ilk kez GERÇEK olarak
      test ediliyor (bkz. Parça 35).
- [ ] **iPAD'DE ÜÇ PAYLAŞIM YOLU DA (Parça 86) — bu, iPhone'da test edilse
      bile KANITLANMAZ.** iPad'de paylaş sayfası popover olarak açılıyor ve
      iOS ankraj (`sharePositionOrigin`) istiyor; verilmezse share_plus
      paylaşmak yerine hata döndürüyor ve akış sessizce ölüyor. Üçünü de
      GERÇEK bir iPad'de dene: (a) oyun geçmişinde tahta paylaşımı,
      (b) Setup'ta "Arkadaşınla paylaş", (c) Arkadaşlar'da davet linki.
      Popover ekranda görünmeli (ve makul bir yerden çıkmalı), "hiçbir şey
      olmadı" bir hatadır.
- [ ] **Bölüm 10 — davet linkinin SOĞUK başlangıcı (Parça 87).** Uygulamayı
      tamamen kapatıp `kelimeki://davet/<token>` linkine dokun; davet
      işlenmeli ve diyalog YALNIZCA BİR KEZ çıkmalı. Bu, web derlemesinde
      test EDİLEMEZ (custom şemayı yalnızca kurulu bir uygulama yakalar),
      yani ilk kez burada gerçek olarak sınanıyor.
- [ ] **Bölüm 12 — HEIC avatarı ve galeri izni reddi (Parça 87).**
      Android'de HEIC bir fotoğrafla yükleme (eskiden reddediliyordu) ve
      izin kapalıyken görünen Türkçe hata — ikisi de gerçek bir galeri/izin
      diyaloğu gerektirdiğinden yalnızca cihazda doğrulanabilir.
- [ ] **Bölüm 8 — uçak modu:** burada native'in web'den DAHA İYİ olması
      bekleniyor, iki şey ayrıca doğrulanmalı:
      (a) uçak modunda **kelime anlamı GELMELİ** (`meanings.db` pakette —
      web'de HTTP'den indiği için gelmiyordu, Parça 44);
      (b) Setup'ın alt teşhis satırı **`depo ok`** göstermeli ve hiç
      `DEPO YOK` olmamalı (web'de sqflite WASM dosyaları ağdan geldiğinden
      bu risk vardı, Parça 45 — native'de sqflite platform kanalı).
- [ ] **Bölüm 12 — profil fotoğrafı:** galeri seçici + izin diyaloğu.
      iOS'ta `NSPhotoLibraryUsageDescription` metni görünmeli; Android'de
      izin akışı sürüme göre değişir (13+ farklı davranır).
- [ ] **Oturum kalıcılığı:** uygulamayı TAMAMEN kapat (arka plandan da at)
      → yeniden aç → hâlâ girişli olmalı. Web'de token farklı bir depoda
      tutulduğundan orada geçmesi bunu kanıtlamıyordu.
- [ ] **Sürükle-bırak hissi + performans:** parmakla taş sürüklerken
      takılma/titreme olmamalı. Parça 23'ün ölçümü native VM'de yapıldı,
      gerçek cihaz GPU'sunda (Impeller/Skia) hiç ölçülmedi.
- [ ] **🤖 robot avatarı gerçekten çizilmeli.** Web derlemesinde CanvasKit
      emoji fontunu ağdan çektiğinden boş daire çıkabiliyordu (Parça 29).
      **iOS ile Android'in emoji GÖRÜNTÜSÜ farklıdır ve bu bir hata
      DEĞİLDİR** — Apple Color Emoji vs Noto Color Emoji; ikisi de doğru.
      Aynı şey ❓⚙️👥📊🚪 (hesap menüsü) ve 🏆 (k-lig) için de geçerli.
- [ ] **Klavye:** Türkçe karakterler (ı/İ/ğ/ş) tüm formlarda doğru
      girilebilmeli; klavye açılınca form alanı klavyenin altında
      kalmamalı (kayıt formu en uzun form).

### Yalnızca Android

- [ ] **Geri tuşu / geri jesti.** Kodda `PopScope`/`WillPopScope` HİÇ YOK —
      yani geri tuşu düz bir `Navigator.pop`. Yapısal olarak güvenli
      görünüyor (oyundan çıkış `await Navigator.push(...)` → `session.end()`
      zincirinden geçiyor, geri tuşu da aynı yoldan döner) ama **hiç
      denenmedi.** Kontrol: oyun içindeyken geri → Setup'a dönmeli VE
      oyun "Devam Edenler"de kayıtlı kalmalı (turnCount ≥ 2 ise). Ayrıca
      açık bir modalda geri → yalnızca modal kapanmalı, ekran değil.
- [ ] Setup'ta geri → uygulamadan çıkmalı (standart davranış, onay yok).
- [ ] `assetlinks.json` yayınlandıktan SONRA: `https://kelimeki.com/davet/<token>`
      linki tarayıcı yerine uygulamayı açmalı.

### Yalnızca iOS

- [ ] **Kenardan kaydırarak geri (swipe-back).** Tahtanın sol kenarı ekranın
      soluna yakınsa, taş sürüklemeyle çakışabilir — sol sütundaki bir taşı
      sürüklemeyi dene, sistem geri jesti devreye girip oyundan çıkarmamalı.
- [ ] **Güvenli alan:** çentik/Dynamic Island altında header kesilmemeli,
      alttaki buton satırı home indicator'ın altında kalmamalı.
- [ ] AASA yayınlandıktan SONRA: davet linki uygulamayı açmalı.

### Bulgu çıkarsa

Aynı disiplin geçerli: önce `src/`'deki karşılığını oku, sonra portta
farkı bul, düzeltmeyi negatif eşle kanıtla (bkz. bu dosyanın başı ve
`mobile/CLAUDE.md`, "Sorun Bildirildiğinde İLK ADIM"). **Bir bulgunun
platforma özgü olup olmadığını, öteki cihazda da bakmadan söyleme** —
platform-özgü sandığın şey çoğu zaman iki tarafta da var.

---

## TestFlight kurulumu (Apple Developer üyeliği geldiğinde)

Bu bölüm bir kontrol listesi değil, **tek seferlik kurulum** notu.

1. **App Store Connect'te uygulama kaydı.** appstoreconnect.apple.com →
   Uygulamalar → yeni. Bundle ID: `com.kelimeki.kelimeki` (Xcode
   projesinde zaten bu; Android `applicationId` de aynı).
2. **App Store Connect API anahtarı.** Kullanıcılar ve Erişim →
   Entegrasyonlar → App Store Connect API → anahtar üret ("App Manager"
   rolü). `.p8` dosyası **yalnızca bir kez** indirilir. Üç değer gerekli:
   Key ID, Issuer ID, `.p8` içeriği.
3. **GitHub deposu sırları** (Settings → Secrets → Actions):
   `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
   `APP_STORE_CONNECT_KEY_P8`, ayrıca imzalama için `MATCH_PASSWORD` ve
   sertifika deposu erişimi (aşağı bkz.).
4. **İmzalama.** Mac'in olmadığından sertifikayı elle üretemezsin;
   `fastlane match` sertifika + profili CI'da üretip **ayrı bir özel
   depoda** şifreli saklar (ilk çalıştırma üretir, sonrakiler tekrar
   kullanır). Apple hesap başına dağıtım sertifikası sayısı sınırlı
   olduğundan her çalıştırmada yenisini üretmek ÇALIŞMAZ — kalıcı depo
   şart.
5. **Workflow'a yükleme işi eklenir** (`.github/workflows/mobile-build.yml`
   içindeki `ios` işinin devamı): imzalı `.ipa` derle → TestFlight'a
   yükle.
6. **iPad'de test.** TestFlight uygulamasını App Store'dan kur, davet
   maili gelince "Kabul Et" → Kelimeki gerçek bir uygulama olarak açılır.
   Yukarıdaki bölümler bundan sonra koşulabilir.

## Üyelik OLMADAN test (Appetize.io — tarayıcı emülatörü)

**Sabit linkler — bunlara dokun, "Start"a bas, hepsi bu.** Her
Android/iOS derlemesi bittiğinde CI aynı iki Appetize uygulamasını
otomatik günceller; linkler bir daha değişmez, hiçbir yükleme/dosya
seçme adımı gerekmez:

- **Android** → https://appetize.io/app/oexlhcjxdl6onjr4dewaarnvwa
- **iOS** → https://appetize.io/app/onpdavcakhztlouyedivwrcrdi

**Bunlar nasıl kalıcı kalıyor (`.github/workflows/mobile-build.yml`,
"Appetize'a otomatik yükleme"):** derleme bitip GitHub Release'e
yüklendikten hemen sonra, o dosyanın herkese açık indirme URL'i
Appetize'ın REST API'sine (`POST /v1/apps/<public-key>`, gövde
`{"url": ...}`) gönderiliyor — Appetize dosyayı SUNUCU SUNUCUYA kendisi
çekiyor, tarayıcı hiç devreye girmiyor. Bu, `APPETIZE_API_TOKEN` adlı bir
GitHub Actions secret'ı gerektiriyor (Appetize → Organization Settings →
API Token → Developer rolü); secret yoksa adım sessizce atlanır, derleme
etkilenmez.

**Neden bu yola geçildi (7 Ağustos 2026):** iPad Safari'nin dosya
seçicisi/sürükle-bırak'ı `.apk` için günlerce çözülemeyen iki ayrı
belirtiye takıldı — dosya seçicide SOLUK/tıklanamaz kalıyordu (iOS
`.apk` uzantısını tanımıyor, hangi Appetize sekmesi seçili olursa olsun)
ve sürükle-bırak dosyayı "aktif" gösterse de yükleme **400 Bad
Request**'le reddediliyordu. İkisi de tarayıcı/iOS kaynaklı, elle
düzeltilebilecek bir ayar değildi — kökten çözüm dosya seçiciyi
DEVREDEN ÇIKARMAK oldu.

iOS'un neden üyelik gerektirmediği: Appetize iOS uygulamasını cihaz
`.ipa`'sı olarak değil **simülatör `.app`'i** olarak istiyor ve simülatör
derlemeleri imzasız. Bu derleme DEBUG modda (Flutter simülatör için
release desteklemiyor) — JIT ile çalıştığından biraz yavaş, animasyonlar
takılabilir; görsel/işlevsel doğrulama için sorun değil ama PERFORMANS bu
derlemeden ölçülmez.

Artefaktlar (`kelimeki-apk`, `kelimeki-ios-simulator`) hâlâ üretiliyor —
gerçek bir Android cihaza kurmak istersen APK'yı oradan da indirebilirsin.

Üyelik yalnızca gerçek cihaza kurulum (TestFlight) ve App Store yayını
için gerekli.

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
