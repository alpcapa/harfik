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
- ⚠ **T2 = Google Play'e verilen test hesabı (4 Eylül 2026).** Play
  incelemesi bu hesapla giriş yapıyor, yani **şifresi DEĞİŞTİRİLEMEZ** ve
  şifre sıfırlama gibi maddelerde kullanılamaz. Bu tür testler için T3 ya da
  `erkantest26` seç. (Hesap silme maddesinde T5 kullanılmış ve silinmiştir;
  elde T2, T3, erkantest26 kaldı.)
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
      gösterip birkaç saniye içinde etkinleşmeli (63.905 kelime asset'ten
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
- [ ] **Alt şeritte BEŞ nokta + ara sayfalarda küçük bir "DEVAM ›"**;
      **HEMEN OYNA yalnızca 5. sayfada** çıkıyor ve orada DEVAM görünmüyor.
      **Düğmeye basınca bir sonraki slayta geçmeli** ve parmakla kaydırma
      da AYNEN çalışmaya devam etmeli (düğme kaydırmanın yerine geçmiyor).
      ⚠ Bu düğme 19 Ağustos 2026'da kullanıcı isteğiyle KALDIRILMIŞTI
      ("alttaki kocaman Devam butonu çok gereksiz… herkes parmakla
      ilerleyeceğini bilir"); 26 Ağustos'ta kapalı testin ilk gerçek
      kullanıcıları o varsayımı çürütünce GERİ KONDU — tanıtımda takılıp
      Setup'a hiç ulaşamıyorlardı. Bu yüzden geri konan düğme eskisi gibi
      tam genişlikte DEĞİL, metin genişliğinde.
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

## 0.5 Web ile yan yana görsel karşılaştırma → `mobile/docs/testing-gorsel-karsilastirma.md`

Görsel parite denetimi (Parça 56 kökenli; çoğu maddesi bir kez ya da görsel
bir değişiklik sonrası koşulur) 1 Eylül 2026'da kendi dosyasına taşındı —
bu dosya uyarı bandına girmişti, kesme noktası içeriğin türü.

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
- [ ] **Güncelleme kendiliğinden geliyor mu (Parça 171)?** → maddeler
      `mobile/docs/testing-bildirimler.md` → bölüm 7'de: Play In-App
      Update YALNIZCA Play'den kurulmuş pakette çalışır, yani buradaki
      (her derlemede koşulan) listeye ait değil.
- [ ] **Şerit KENARLARA yaslı mı (Parça 170)?** "Hamleler · Mesajlaşma"
      şeridin SOL ucunda, "Nasıl Oynanır?" SAĞ ucunda durmalı — ikisi
      ortada kümelenmiş görünüyorsa `Wrap` genişliği doldurmuyor demektir.
      **Web ile yan yana koyarak bak** (aynı oyunu tarayıcıda aç): hata tam
      da böyle bulundu, 30 Ağustos 2026'da bir kullanıcı Android paketiyle
      iPhone'daki web'i karşılaştırıp bildirdi. Widget testi bunu artık
      koruyor, ama gerçek cihazın genişliği testinkinden farklı olabilir.
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
- [ ] **Kafa kafaya oran çubuğu (3 Eylül 2026, Parça 185) — İKİ HESAP
      GEREKİR.** A hesabıyla gir, k-lig'den B'nin kartını aç. Alt satırda
      solda `TÜM OYUNLAR` butonu (SOLA yaslı; kendi Skor Kartı'ndaki buton
      da aynı adı taşımalı ve sola yaslı olmalı — geçmiş penceresinin başlığı
      da `Tüm Oyunlar`), sağda ÜÇ satır: en üstte yüzdeler, ortada **B'nin
      avatarı · üç renkli çubuk · A'nın (senin) avatarı**, en altta oyun
      sayısı ORTALI. İsim YAZMAMALI.
      - **Yüzdeler kendi renklerinde ve kendi alanlarının üzerinde:** sol
        kırmızı, sağ yeşil. Çok tek taraflı bir skorda (ör. 1–19) dar
        dilimin etiketi çubuğun dışına TAŞMAMALI, ikisi ÇAKIŞMAMALI.
      - **Beraberliğin yüzdesi HİÇ yazmamalı** — gri bant görünür, sayı yok.
      - Bir uç %0 ise etiket yazılmamalı ama kalan etiket ortaya KAYMAMALI.
      - **Sistem yazı boyutunu büyüterek de bak** (Ayarlar → Yazı tipi
        boyutu, en büyük): yüzdeler ve "N oyun" satırı BÖLÜNMEMELİ.
      - Renkler soldan sağa: **B'nin kazandıkları (kırmızı) · beraberlik
        (gri) · senin kazandıkların (yeşil)** — her avatar kendi
        tarafındaki dilime bakıyor.
      - **AYNA KONTROLÜ (asıl kontrol bu):** B hesabıyla gir, A'nın kartını
        aç. Oyun sayısı AYNI, kazanma/kaybetme rakamları TERSİNE dönmeli.
      - **Kendi kartında ÇUBUK HİÇ ÇIKMAMALI**; hiç oynamadığın birinin
        kartında da çıkmamalı (yalnız `TÜM OYUNLAR` butonu görünür).
      - **YALNIZCA 2 kişilik Canlı oyunlar sayılır** — 4 kişilik ortak
        oyununuz ve YZ oyunları sayıya girmemeli.
      - **Web ile çapraz kontrol:** aynı iki hesap için web'deki kartta
        görünen rakamlar birebir aynı olmalı (aynı RPC).
      - Çevrimdışıyken kart açılabilmeli, çubuk yalnızca çizilmemeli —
        hata/uyarı ÇIKMAMALI.
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
- [ ] **Yaş/cinsiyet BAŞKASININ kartında (29 Ağustos 2026).** k-lig'de,
      profilinde doğum tarihi ve/veya cinsiyet GİRMİŞ bir başkasının
      satırına dokun: kartta ismin hemen ALTINDA `Y:59/C:E` biçiminde bir
      satır olmalı (mono, gri, küçük) — kendi Skor Kartı'ndaki satırın
      birebir aynısı. **Çapraz kontrol:** aynı kişi için web'de görünen
      yaş ile buradaki yaş AYNI olmalı (biri istemcide, öteki sunucuda
      hesaplanıyor). Arkadaşlık simgesi (✓ / +) yaş satırıyla AYNI
      hizaya kayMAmalı, isim satırında kalmalı. Doğum tarihi de cinsiyeti
      de girmemiş bir oyuncunun kartında satır HİÇ çıkmamalı (boş bir
      satır yer kaplamamalı). Çevrimdışıyken de kart açılabilmeli, satır
      yalnızca çizilmemeli — hata/uyarı ÇIKMAMALI.
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
- [ ] ⚠ **iPad'DE ÜÇ YOLU DA DENE — 2 Eylül 2026'da İKİSİ KIRIKTI
      (Parça 181).** Ankraj geçersizken `SharePlus.share` FIRLATMIYOR,
      ASILI KALIYOR; belirti çağrı yerine göre değişiyor:
      (a) oyun geçmişinde tahta paylaşımı — o gün çalışan tek yol,
      (b) Setup footer "Paylaş" — bozukken *"hiç tepki vermiyor"*,
      (c) Arkadaşlar "+ ARKADAŞINI DAVET ET" — bozukken buton **`…`
      durumunda KİLİTLİ kalıyor** (meşgul göstergesi hiç sıfırlanmıyor).
      Üçünde de paylaş kutusu AÇILMALI ve buton `…`ta kalmamalı.
      ⚠ **Simülatörde hedef uygulama (WhatsApp vb.) OLMAMASI normaldir** —
      ölçülen şey kutunun AÇILIP açılmadığı, içinin dolu olması değil.
      ⚠ **Web derlemesi bu maddeyi KANITLAMAZ** (`kelimeki.com`/Pages):
      orada `navigator.share` çalışıyor, iOS kanalına hiç uğranmıyor.
      Cihazın iPad olması yetmez, DERLEMENİN native olması gerekir —
      Appetize → iOS simülatörü → iPad cihaz tipi.
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
- [ ] **CANLI oyunda bağlantı giderken tahtanın ALT ŞERİDİ tek satır
      kalmalı (Parça 178, 2 Eylül 2026).** Sistem yazı boyutunu EN BÜYÜĞE
      al, bir Canlı oyun aç, uçak moduna geç. Şeritte "Çevrimdışı" belirir
      ve **"Mesajlaşma" yazısı düşer, konuşma balonu ikonu (varsa
      okunmamış sayacıyla) kalır** — şerit 48 px'lik TEK satır olmalı,
      tahtanın altı kalınlaşmamalı. İkona dokunmak sohbeti hâlâ açmalı.
      Ağı geri açınca yazı geri gelmeli.
      ⚠ **320 px genişliğindeki bir cihazda (çok eski/küçük Android) en
      büyük fontta şeridin İKİ satır olması BİLİNEN ve kabul edilen
      sınırdır** — hata olarak bildirme.
      ⚠ Neden elle: `flutter test` bunu ölçüyor (`text_scale_test.dart`)
      ama GERÇEK cihazın yazı ölçeği, font metrikleri ve genişliği
      testtekiyle birebir aynı olmayabilir.
- [ ] **Zoom'da tahta kartın YUVARLAK KENARINA kadar gitmeli (Parça 179).**
      Tahtada boş bir kareye çift dokun (2× zoom), sonra parmakla sağa/aşağı
      sona kadar kaydır. Kenarlarda **sabit duran ince bir çerçeve
      OLMAMALI** — kareler kartın yuvarlatılmış kenarına kadar gitmeli.
      ⚠ Kaydırdığın YÖNÜN ters ucunda tahtanın kendi iç boşluğunun
      ölçeklenmiş hâli (≈20 px) görünür; bu NORMAL ve web'de de öyle —
      çerçeve o değil, dört kenarda birden duran sabit şerittir.
- [x] **En büyük fontta bölge filigranları BÜYÜMEMELİ (Parça 179).**
      ✅ 2 Eylül 2026, `1.0.5 (501) — 4a0a29b` ile cihazda doğrulandı
      (kullanıcı: *"Filigranlar düzgün (en büyük fontta)"*).
      Madde DURUYOR — sonraki sürümlerde yeniden koşulacak.
      Sistem yazı boyutunu en büyüğe al, oyunu aç: köşelerdeki büyük
      oyuncu numarası, ortadaki "X2" ve merkez karedeki "X3" **normal
      fonttakiyle aynı boyutta** kalmalı ve numara 4×4 köşe bloğunun
      dışına taşmamalı. (Küçük ekranlarda — 320/360 px — düzeltmeden önce
      taşıyordu.)
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

## 10-11. Arkadaşlar + Canlı oyun → `mobile/docs/testing-arkadaslar-canli.md`

Bu iki bölüm (Arkadaşlar; Canlı oyun — davet/kabul + tahta) **ayrı bir
dosyaya taşındı** (26 Ağustos 2026, doküman bütçesi: bu dosya 141 KB ile
uyarı bandındaydı ve kural *"bir sonraki dokunuşta böl"* diyor). Kesme
noktası içeriğin TÜRÜ: ikisi de İKİ GERÇEK OTURUM gerektiren, en uzun ve
en seyrek koşulan turlar; buradaki geri kalan liste tek cihazda koşulabiliyor.
Hiçbir madde değişmedi, numaralar korundu.



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
- [ ] **Seviyeye göre puan — Kolay (6 Eylül 2026, ROADMAP #23 Faz 4;
      web'in aynı listesi kök `TESTING.md` §10).** Girişli hesapla Yapay
      Zeka sekmesi → "+ Yeni" → `OYUNCU SAYISI`nın ALTINDA **ZORLUK**
      satırı: `KOLAY` · `NORMAL`, Normal seçili; `ZOR` GÖRÜNMEMELİ (Faz
      5'e kadar). Seçicinin altında seçili seviyenin açıklaması, web ile
      BİREBİR: Normal'de "Orta-iyi seviye bir oyuncuyum… birincilik 2 puan
      kazandırır.", KOLAY'a dokununca "Çok iyi değilim… birincilik 1 puan
      kazandırır."; 4 OYUNCULU'ya geçince cümleye ikincilik eklenir (Kolay:
      "ikincilik puan kazandırmaz", Normal: "birincilik 2, ikincilik 1 puan
      kazandırır"). Oyunu başlat, "← Geri" ile Setup'a dön: "DEVAM
      EDEN OYUNLAR" kartında avatarların hemen SAĞINDA küçük YEŞİL `Kolay` rozeti
      (Normal oyun kartında TURUNCU `Normal`; kural: Kolay yeşil · Normal
      turuncu · Zor kırmızı, YZ oyununda her seviyede; Canlı kartında HİÇ
      rozet yok — web ile aynı). ZORLUK butonları Arkadaşınla sekmesinin
      DEVAM EDENLER / OYUN DAVETLERİ / SON OYNANANLAR pilleriyle AYNI boy ve
      puntoda, OYUNCU SAYISI'nın büyük butonu gibi DEĞİL. Oyun içinde
      tahtanın altındaki şeritte "Hamleler · Kolay" (Canlı oyunda orada
      "· Mesajlaşma" var, rozet yok; şerit tek satırda kalmalı). Oyunu
      birinci bitir: oyun sonu penceresinde başlığın altında `Kolay` rozeti
      ve k-lig sütununda **+1** (Normal'de turuncu rozet, +2). "Son Oynadıklarım"da tarihin yanında
      rozet ve +1; "Tüm Oyunlarım"da "Yapay Zeka" rozetinin sağında `Kolay`
      ve +1; kartı beğenip **Favoriler**'de de aç (ayrı RPC,
      `list_liked_games`) — orada da +1. Skor Kartı/k-lig listesindeki
      toplam da +1 artmalı (sunucu `league_points_for` ile aynı sayı; kart
      +1 gösterirken liste +2 artıyorsa iki kopya ayrışmış demektir). Oyun
      sonu "TEKRAR OYNA" → yeni oyun da Kolay (devam eden kartında rozet).
      **Web ↔ port (ROADMAP 23.5 kapanış ölçütü):** portta Kolay bitirilen
      oyun web'de aynı puan ve rozetle görünmeli, tersi de (aynı hesap, iki
      cihaz); portta Kolay başlatılıp bulut kaydına düşen oyun web'de devam
      ettirilince YZ Kolay oynamalı (Setup kartında rozet) ve tersi. Canlı
      oyun kartlarında rozet HİÇBİR koşulda çıkmaz.
- [ ] **Kart altı PUAN SATIRI** (6 Eylül 2026, kullanıcı isteği; web ile
      birebir): Yapay Zeka ↔ Arkadaşınla sekmelerindeki devam eden oyun
      kartlarında avatarların hemen altında koltuk sırasıyla anlık puanlar
      (`45 - 38`; 4 kişilikte dört sayı), stil kalan-süre satırıyla AYNI
      (`devamEdenSureStil`, 8 px SpaceMono). ⚠ Canlı kartında **"X açtı"
      satırı ARTIK YOK**. Rakip hamle yapınca puan oyuna girmeden
      tazelenmeli (Realtime → `_reload`). "Son Oynadıklarım"da tarih
      (+ zorluk rozeti) avatarların ÜSTÜNDE, bitiş puanları altında; sağdaki
      puan/k-lig sütunları (`ScaledCell`) yerinde. Yazı ölçeği tavanında
      (1,3) puan satırı kırpılmadan tek satır kalmalı (üç nokta ile).
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

**Arka plandan dönüş de bir "giriş" (Parça 124 — 21 Ağustos 2026'da
yazıldı, 4 Eylül 2026'da kurtarıldı).** Varsayılan artık hesap başına DEĞİL,
**ekrana giriş başına** bir kez uygulanıyor; uzun bir aradan sonra öne dönmek
de giriş sayılıyor (eşik 5 dakika). Risk dengede: eşik yanlış tarafa düşerse
kullanıcı bilerek oturduğu sekmeden koparılır, o yüzden negatif eşleri de koş.

- [ ] **Uzun dönüş sekmeyi açar.** Girişli hesapla Setup'ta **"Yapay Zeka
      ile"** sekmesinde dur, uygulamayı arka plana al. Bu arada karşı taraf
      (T2) hamle yapsın ya da davet göndersin. **5 dakikadan uzun** bekleyip
      uygulamaya dön: **"Arkadaşınla" sekmesi kendiliğinden açılmalı**
      (bekleyen davet varsa "Oyun Davetleri" alt sekmesiyle).
- [ ] **Negatif eş — kısa kesinti sekmeyi DEĞİŞTİRMEZ.** Bildirim bandını
      aşağı çekip kapat, ya da uygulamadan çıkıp birkaç saniye sonra dön:
      sekme aynı kalmalı (yalnızca rozet güncellenebilir). iOS'ta bu
      `inactive` üretiyor — süre kısa olduğu için eşiği geçmemeli.
- [ ] **Negatif eş — bekleyen iş yokken dönüş de yerinden etmez.** Canlı'da
      hiçbir davet/hamle beklemiyorken 5+ dakika uzaklaşıp dön: "Yapay Zeka
      ile" sekmesinde kalmalısın.
- [ ] **Alt sekme de aynı kuralı izliyor.** "Arkadaşınla → Son Oynananlar"da
      dururken uygulamayı 5+ dakika arka plana al, bu arada T2 sana DAVET
      göndersin, dön: "Oyun Davetleri" alt sekmesi açılmalı. Davet yokken
      (yalnızca sıra sende) alt sekme DEĞİŞMEMELİ — bu bilinçli.
- [ ] **Oyun ekranı etkilenmiyor.** Açık bir Canlı oyunda uzun süre arka
      planda kalıp dön: tahta/sıra normal tazelenmeli, hiçbir sekme/ekran
      değişimi olmamalı (bu kural yalnızca Setup ve Canlı sekmesinde).

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

## 24. Push bildirimleri + derin bağlantılar → `mobile/docs/testing-bildirimler.md`

Bildirim izni akışı, `push_tokens` yaşam döngüsü, bildirimin düşmesi/dokunma
ve kayıt onayı linkinin uygulamaya dönüşü AYRI bir dosyada (Parça 158):
maddelerin çoğu **Play kanalından kurulmuş imzalı bir derleme** istiyor, yani
CI'nın debug-imzalı `.apk`'sıyla koşulamaz. Hangi maddenin hangi derlemede
test edilebildiği o dosyanın başındaki tabloda.

## Test ortamları ve derleme dağıtımı → `mobile/docs/test-ortamlari.md`

Web derlemesi (tarayıcı test ortamı), **FAZ B — cihaza özel tur (iOS +
Android)**, TestFlight kurulumu ve Appetize.io emülatörü 25 Ağustos
2026'da bu dosyadan **`mobile/docs/test-ortamlari.md`**'ye taşındı (kök
`CLAUDE.md` → "Doküman Boyutu Bütçesi"; bu dosya uyarı bandındaydı).
İçerik AYNEN duruyor — kesme noktası içeriğin türü: burası her sürüm önce
baştan koşulan KONTROL LİSTESİ, orası "nereden/nasıl koşulur" bilgisi.

## 14-25. Etkileşim ve görünüm turları (tarihli) → `mobile/docs/testing-ux-turlari.md`

Sürükleme eşiği · dokunma hedefleri (üç tur) · "Yükleniyor…" · "← Geri"nin
yeni yeri · tahta açılışı · taslak sürerken kelime anlamı · hesap silme ·
nömorfik dekor önbelleği · "Buradan başla" balonu · sistem yazı boyutu ·
tahta zoom'u 3 Eylül 2026'da bu dosyadan **`mobile/docs/testing-ux-turlari.md`**'ye
taşındı (kök `CLAUDE.md` → "Doküman Boyutu Bütçesi"; bu dosya uyarı
bandındaydı). İçerik AYNEN duruyor, bölüm numaraları korundu — kesme
noktası içeriğin türü: burası her sürüm baştan koşulan ÖZELLİK listesi,
orası belirli bir Parça'nın gerilemediğini doğrulayan TARİHLİ turlar.
