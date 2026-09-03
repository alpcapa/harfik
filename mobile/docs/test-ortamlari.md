# Kelimeki Mobil — Test Ortamları ve Derleme Dağıtımı

**Nereden geldi (25 Ağustos 2026):** `mobile/TESTING.md` uyarı bandına
girmişti (160 KB / 200 KB) ve kök `CLAUDE.md`'nin "Doküman Boyutu Bütçesi"
kuralı *"uyarı bandındaki dosyayı bir sonraki dokunuşunda böl"* diyor. Kesme
noktası içeriğin TÜRÜNE göre seçildi: `mobile/TESTING.md` **her sürüm önce
baştan koşulan bir kontrol listesi**, buradakiler ise **"nereden/nasıl
koşulur"** bilgisi — biri her turda okunur, öteki yalnızca ortam kurarken.

Bu dosyada dört bölüm var (hepsi `mobile/TESTING.md`den olduğu gibi taşındı):

- Web derlemesi (ücretsiz tarayıcı test ortamı)
- FAZ B — cihaza özel tur (iOS + Android)
- TestFlight kurulumu (Apple Developer üyeliği geldiğinde)
- Üyelik OLMADAN test (Appetize.io — tarayıcı emülatörü)

---

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
| **iPad paylaş popover ankrajı (Parça 86/181)** | ✅ **3 Eylül 2026'da KOŞULDU ve HATA BULDU** (Appetize'da iPad cihaz tipi SEÇİLEBİLİYOR — bu satır "❌" diyordu, ölçülmemişti) | Maddenin kendisi "iPhone'da test edilse bile KANITLANMAZ" diyor; iPad cihaz tipi şart. ⚠ **WEB derlemesi de KANITLAMAZ** — 2 Eylül 2026'da gerçek bir iPad'de üç yol da denendi ve "çalıştı", ama `kelimeki.com`/Pages derlemesiyle: orada `navigator.share` çalışıyor, iOS kanalına hiç uğranmıyor. Cihazın iPad olması yetmiyor, DERLEMENİN native olması gerekiyor. **Appetize + iPad Air / iOS 16.2'de koşulunca üç yoldan İKİSİ anında kırık çıktı** (Parça 181); düzeltmeden sonra üçü de açıyor (3 Eylül, kullanıcı). Yani bu satırın "❌"i bir yokluk değil, DENENMEMİŞLİKMİŞ |
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

