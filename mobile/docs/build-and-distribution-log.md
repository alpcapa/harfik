# Web Derlemesi / Appetize / Play Store İmzalama / Web Ayrışması — Karar Kaydı

> mobile/docs/'e taşındı (context split, 24 Ağustos 2026). Kaynak: 'Web Derlemesi — ÜRÜN DEĞİL, TEST ORTAMI', 'Appetize — Otomatik Yükleme', 'Play Store İmzalama ve .aab', 'Karşılama Katmanı (web) — bilinçli ayrışma' bölümleri.

## Web Derlemesi — ÜRÜN DEĞİL, TEST ORTAMI (7 Ağustos 2026)

Flutter'ın web hedefi bu porta üçüncü bir platform olarak EKLENMEDİ; ürün
hedefi hâlâ yalnızca iOS + Android. Web derlemesi tek bir sorunu çözüyor:
**geliştiricinin çalıştırabileceği hiçbir cihazı yok.** iPad'den çalışıyor,
Mac yok, Android telefon yok, Apple Developer üyeliği askıda (TestFlight
yok), tarayıcı emülatörü (Appetize) ücretsiz katmanda 3 dakikayla sınırlı.
Aynı Dart kodu aynı çizim motoruyla (CanvasKit) koştuğundan yerleşim/font/
gölge/oyun akışı doğrulaması burada ücretsiz ve süresiz yapılabiliyor.

Adres `https://alpcapa.github.io/kelimeki/`; `main`e giren her mobil
değişiklikte `.github/workflows/mobile-build.yml`'in `web` işi GitHub
Pages'e deploy ediyor. **PR'larda deploy YOK** (site paylaşılan bir test
ortamı, merge edilmemiş kodla değiştirilemez) — PR'da bunun yerine `test`
işi web'i deploy etmeden DERLİYOR, yani web'e özgü kırılmalar yine
yakalanıyor. NE KANITLAR / NE KANITLAMAZ ayrımı `mobile/TESTING.md`'de ("Web
derlemesi") — kısaca: platform kanalı gerektiren her şey (paylaş sayfası,
dosya sistemi, oturum kalıcılığı, ikon/splash, gerçek dokunmatik jestler,
performans) hâlâ gerçek cihaz ister.

**KURAL — web dalı mobil kod yolunu DEĞİŞTİREMEZ.** Üç kırık noktanın
üçünde de mobil taraf bire bir korundu; yeni bir platform-bağımlı API
kullanırken aynı deseni izle:

| Kırılan | Sebep | Çözüm |
|---|---|---|
| Sözlük hiç yüklenmiyordu | `Isolate.run` web'de yok ("Unsupported operation: new RawReceivePort") | `kIsWeb` dalı (`dictionary_loader.dart`) — derleme zamanı sabiti olduğundan mobil derlemede web dalı tamamen elenir |
| Depolamaya bağlı her ekran asılı kalıyordu | `sqflite`'ın native platform kanalı tarayıcıda yok | `sqflite_common_ffi_web` (WASM sqlite3 + IndexedDB) aynı `DatabaseFactory` arayüzünü verir → şema/sorgu/store kodu HİÇ değişmedi |
| Kelime anlamları açılamıyordu | asset kopyası `dart:io` ile dosyaya yazılıyor | web dalı kopyayı IndexedDB'ye yazar; "güncel mi" sorusu ayrı damga dosyası yerine ADA gömülü sha256 ile yanıtlanır |

**Koşullu import deseni (`lib/src/storage/web_db.dart`).** `sqflite_common_ffi_web`
yalnızca web'de derlenebilen js_interop içeriyor — doğrudan import edilirse
iOS/Android derlemesini KIRAR. Üçlü dosya: `web_db.dart` (`export ... if
(dart.library.js_interop) ...`), `web_db_stub.dart` (mobil, her zaman
`null`), `web_db_web.dart` (web). Tek kullanım yeri `openAppDatabase` +
`MeaningStore._open`; ikisi de "çağıran kendi fabrikasını geçtiyse hiç
devreye girme" kuralını uyguluyor, bu yüzden **testlerin hiçbiri
etkilenmedi** (142/142 aynen geçiyor).

**`web/` klasörü depoda tutuluyor** — içindeki `sqflite_sw.js` ve
`sqlite3.wasm` `dart run sqflite_common_ffi_web:setup` ile ÜRETİLİR ama
derleme anında ağdan indirilmemesi için repoya konmuştur. `sqflite_common_ffi_web`
sürümü yükseltilirse bu iki dosya da yeniden üretilmeli.

**Yeni bir platform API'si eklerken sor:** web'de var mı? Yoksa (a) `kIsWeb`
ile dallan, (b) koşullu import'un arkasına al, ya da (c) sessizce
işlevsizleş (anlam modalı asset açılamazsa "anlam bulunamadı" der, oyun
akışı bozulmaz). Ne yaparsan yap, web derlemesinin ASILI KALMAMASI şart —
asılı bir ekran bütün test ortamını kullanılmaz yapıyor.

## Appetize — Otomatik Yükleme (7 Ağustos 2026)

**Sabit linkler** (bir daha değişmez, her derlemede otomatik güncellenir):
- Android → https://appetize.io/app/oexlhcjxdl6onjr4dewaarnvwa
- iOS → https://appetize.io/app/onpdavcakhztlouyedivwrcrdi

**Sorun:** geliştirici iPad'den çalışıyor, Appetize'a manuel yükleme
iOS Safari'nin dosya seçicisinde günlerce iki ayrı belirtiyle tıkanıyordu:
(1) dosya seçicide `.apk` SOLUK/tıklanamaz kalıyordu — sebep iOS'un
`.apk`'ya karşılık gelen bir UTI (Uniform Type Identifier) tanımlaması,
Appetize'ın hangi platform sekmesi seçili olursa olsun bu değişmiyordu
(ilk teşhis "platform sekmesi yanlış" idi, ikinci denemede aynı sekmeyle
tekrar başarısız olunca bu teşhis de çürüdü); (2) dosya seçici yerine
sürükle-bırak denendiğinde dosya "aktif" görünüyordu ama yükleme
**400 Bad Request**'le reddediliyordu — muhtemelen iPad Safari'nin
uygulamalar-arası (Files → Safari) büyük dosya sürüklemesinin XHR/fetch
multipart isteğine tam veri aktarmaması. İkisi de tarayıcı/iOS kaynaklı,
Appetize tarafında elle düzeltilebilecek bir ayar değildi.

**Çözüm — dosya seçiciyi tamamen devreden çıkarmak:** Appetize'ın REST
API'si (`https://api.appetize.io/v1/apps/`) `{"url": ...}` gövdesiyle
POST edilirse dosyayı **sunucu sunucuya** kendisi çekiyor — iPad'in
tarayıcısı hiç işin içine girmiyor. Bu, web arayüzünde görünmeyen ama
API'de baştan beri var olan bir yol (`maxep/appetize-upload-action`
GitHub Action'ının kaynağından bulundu — `POST /v1/apps/[public-key]`,
gövde `{url, platform, note, timeout}`, HTTP Basic Auth `username=<API
token>`). `.github/workflows/mobile-build.yml`'deki `android`/`ios`
işlerinin sonuna, GitHub Release'e yükleme adımından hemen sonra birer
`curl` adımı eklendi — o dosyanın az önce yüklendiği herkese açık
`mobile-latest` release URL'ini Appetize'a gönderiyor.

**İki aşamalı kuruluş — NEDEN `public-key` sabit bir değer:** İlk koşuda
`public-key` verilmeden POST edilirse Appetize YENİ bir app oluşturuyor
(her koşuda ayrı bir tane, hesabı dolduracak kadar). Bunun yerine bir
KEŞİF koşusu yapıldı (`public-key` yok) → dönen `publicKey` job log'undan
okunup (`echo "$resp" | jq '{publicKey, appURL}'`) İKİNCİ bir commit'le
workflow'a sabit parametre olarak gömüldü (`/v1/apps/oexlh.../` gibi) —
artık her koşu AYNI app'i günceller, `appURL` (yukarıdaki linkler) bir
daha değişmiyor. `manageURL` alanı bilerek log'a hiç yazdırılmıyor —
action'ın kendisi bunu `core.setSecret` ile maskeliyor, aynı ihtiyat
burada da uygulandı (`publicKey`/`appURL` Appetize'ın kendi tasarımı
gereği zaten paylaşılabilir — session linkleri herkese açık).

**Gereken tek kurulum: `APPETIZE_API_TOKEN` secret'ı.** Appetize →
Organization Settings → API Token → **Developer** rolüyle üretilip
GitHub'a repo secret'ı olarak eklendi
(`https://github.com/alpcapa/kelimeki/settings/secrets/actions`). Adım
bu secret olmadan da KIRILMAZ — `if [ -z "$APPETIZE_API_TOKEN" ]; then
exit 0; fi` ile sessizce atlanır, derleme etkilenmez.

**Bu ortamdan (Claude Code oturumu) doğrudan denenemedi:**
`api.appetize.io`/`appetize.io`'ya bu oturumun ağ proxy'si 403 ile engel
koyuyor (`CONNECT tunnel failed`) — API'nin var olduğu ve çalıştığı GitHub
Actions runner'ından (proxy'siz, gerçek internet erişimi olan ortam)
gerçek bir keşif koşusuyla kanıtlandı, kör kod yazılmadı.

**Doğrulama:** Keşif koşusu (commit `1fc8522`) gerçek `APPETIZE_API_TOKEN`
ile hem Android hem iOS için gerçekten yeni birer Appetize app'i açtı —
job log'larında dönen `publicKey`/`appURL` doğrudan okunup ikinci
commit'e (bu bölümdeki sabit değerler) aynen taşındı. Uçtan uca (linke
tıklayıp Start'a basma) doğrulaması kullanıcının kendi cihazından
bekleniyor — bu ortamdan `appetize.io` erişilemediğinden ben açıp
göremiyorum.

## Play Store İmzalama ve `.aab` (22 Ağustos 2026)

Google Play hesabı açıldıktan sonra ölçülen ilk iki somut engel kapatıldı
(`ROADMAP.md` → FAZ B, 0.A1 + 0.A2). Öncesinde **uygulama bugün YÜKLENEMEZDİ**
ve bu tahmin değil ölçümdü: `android/app/build.gradle.kts`'in release'i
Flutter şablonundan kalma `TODO` yorumuyla **debug anahtarına** düşüyordu ve
CI yalnızca `.apk` üretiyordu — Play `.apk` KABUL ETMİYOR.

### İmzalama — `key.properties` VARSA release, YOKSA debug

`build.gradle.kts` `rootProject.file("key.properties")`ı okuyor; dosya yoksa
release **bilerek** debug anahtarına düşüyor. Bu bir gevşeklik değil: aksi
halde anahtarı olmayan herkeste (yerelde `flutter run --release`, CI'ın
Appetize test `.apk`'sı) derleme kırılırdı. **Bedeli:** debug anahtarıyla
imzalanmış bir `.aab` SESSİZCE üretilebilir ve ancak Play yüklemesinde
reddedilir — o sessizliği kapatan şey aşağıdaki imza kontrolü.

`key.properties` ve `*.jks` **REPOYA GİRMEZ**; `android/.gitignore` (Flutter
şablonundan) üçünü de (`key.properties`, `**/*.jks`, `**/*.keystore`) zaten
tutuyor. Şablon: `android/key.properties.example`. **`storeFile` MUTLAK yol
olmalı** — göreli verilirse `rootProject`e (yani `android/`) değil `app/`
modülüne göre çözülür.

### CI adımı — secret yoksa sessizce atlar, varsa İMZAYI GERİ OKUR

`mobile-build.yml`'in `android` işine `.apk` artefaktından hemen sonra
eklendi. Üç karar kayda değer:

- **`secrets` bağlamı adım düzeyinde `if:`te KULLANILAMAZ** (GitHub'ın bağlam
  tablosunda `steps.<id>.if` için `secrets` yok). Kontrol bu yüzden `run:`
  script'inin İÇİNDE, `env:` ile enjekte edilip; sonuç `$GITHUB_OUTPUT`'a
  `built=true/false` olarak yazılıp artefakt adımına taşınıyor. Bu, deponun
  KENDİ kalıbı — Appetize adımı da token'ı script içinde kontrol edip
  `exit 0` yapıyor.
- **`--build-number=${{ github.run_number }}`**: Play aynı `versionCode`'u
  İKİ KEZ kabul etmiyor, `pubspec.yaml`'daki `+N` ise her derlemede aynı
  kalırdı.
- **İmza doğrulaması SABİT parmak izi YAZMIYOR:** paketin sertifikası
  (`keytool -printcert -jarfile`) az önce çözülen keystore'unkiyle
  (`keytool -list -v`) karşılaştırılıyor. Anahtar değişirse kontrol
  kendiliğinden takip eder; debug anahtarıyla imzalanmış bir paket geçemez.

**ÖLÇÜLDÜ (bu ortamda, gerçek `keytool`/`jarsigner` ile):** aynı anahtarla
imzalanan bir JAR'da iki `keytool` çıktısının SHA-256'sı BİREBİR aynı çıkıyor
(pozitif eş). **Negatif eş iki ayrı yönden kanıtlandı:** başka bir anahtarla
(debug'ı taklit eden `CN=Android Debug`) imzalanan pakette parmak izleri
ayrışıyor ve kontrol düşüyor; hiç imzalanmamış pakette `-printcert` boş
dönüyor ve `-z "$ACTUAL"` dalı düşürüyor. Whitespace `tr -d '[:space:]'` ile
siliniyor — `-list -v` ile `-printcert`in girinti karakteri farklı olabilir.
Base64 gidiş-dönüşü de ölçüldü (`base64 -w0` → `tr -d` → `base64 -d`, dosya
birebir aynı).

**CI'da UÇTAN UCA DOĞRULANDI (23 Ağustos 2026, koşu 32644482976, dal
`claude/google-play-launch-checklist-4bp7yk`, sha `a22cea6`).** Bu ortamda
Flutter SDK olmadığından `flutter build appbundle` yerelde hiç
koşturulamamıştı — YAML'ın geçerliliği (`yaml.safe_load`) ve üretilen KABUK
SATIRININ geçerliliği (`bash -n`) ayrı ayrı ölçülmüştü, ama Gradle'ın
`key.properties`i gerçekten okuduğunun kanıtı CI'a bırakılmıştı. Log:

```
✓ Built build/app/outputs/bundle/release/app-release.aab (60.9MB)
beklenen: SHA256:B6:CD:FB:A9:...:0E:89:A1:52
paket   : SHA256:B6:CD:FB:A9:...:0E:89:A1:52
```

Bu üç satır zincirin TAMAMINI kapatıyor: secret'lar okundu (yoksa adım
"secret yok" deyip çıkardı), Gradle `key.properties`i gördü ve `.aab`
DEBUG değil upload anahtarıyla imzalandı — üstelik basılan parmak izi
üretilen anahtarın kendisi, yani yüklenen keystore da doğru. Artefakt
`kelimeki-aab` (60.597.531 bayt) gerçekten üretildi; `.apk` artefaktı da
yerinde kaldı (Appetize akışı bozulmadı).

**`.aab` artık `mobile-latest` release'inde de (24 Ağustos 2026).** İlk
yükleme hazırlığında ölçüldü: paket YALNIZCA `actions/upload-artifact` ile
bırakılıyordu, yani indirmek için GitHub oturumu gerekiyor ve dosya ZIP
olarak geliyordu — Appetize bölümünde anlatılan iPad dosya-seçici dansının
birebir aynısı, bu kez Play Console'a yükleyecek kişi için. Release adımı
artık `kelimeki.aab`'yi de `--clobber` ile yüklüyor (düz, oturumsuz URL);
artefakt DURUYOR. Yayınlanan `.aab` bir sır taşımıyor: aynı koddan derlenen
`.apk` zaten herkese açık ve upload anahtarı pakete girmiyor — yalnızca imza
girer. Adım PR'da bilerek atlandığından (bkz. "YAYINLAMA") kanıt merge
sonrası ilk `main` koşusunda okundu: **25 Ağustos 2026, koşu 349, sha
`5eddf3d` — `kelimeki.aab` release'te, 60.929.323 bayt, `versionCode` 349.**

**İlk `.aab` yüklemesinde OKUNACAK iki şey — 24 Ağustos 2026'da PAKETTEN
ölçüldü, ikisi de temiz:** `targetSdk` **36**, izinler **3 adet**
(`INTERNET`, `ACCESS_NETWORK_STATE`, AndroidX'in iç izni); `image_picker`
hiçbir izin eklemiyor. Console'un yükleme ekranı da aynı değerleri
göstermeli — göstermiyorsa Data safety beyanı yeniden gözden geçirilmeli.
Aşağıdaki paragraf, ölçümden önceki hâli: derlemenin
`targetSdk`'sı (bugün `flutter.targetSdkVersion`'dan geliyor, yani stable
kanalın varsayılanı — Play'in yeni uygulamalar için dayattığı asgari
seviyenin altındaysa açıkça pinlenmeli) ve `image_picker`'ın birleşmiş
manifeste eklediği izinler (beklenmeyen bir medya izni Data safety
beyanını değiştirir). İkisini de Play Console yükleme ekranı gösteriyor.

### Anahtar — üretildi, repoda DEĞİL

RSA 4096, alias `upload`, geçerlilik **07.01.2054** (Play'in "2033'ten sonra"
şartı sağlanıyor), SHA-256
`B6:CD:FB:A9:81:A6:6B:E3:6B:60:A0:67:15:F4:9E:FF:E6:26:B1:5A:E0:CE:D5:55:00:5B:B0:95:0E:89:A1:52`.
Dosya + base64 + şifre kullanıcıya doğrudan teslim edildi; GitHub secret'larını
(`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`) **kullanıcı elle
girmek zorunda** — bu ortamdan GitHub ayarlarına yazma yolu yok.

**İKİ TUZAK, ikisi de geri dönüşü olmayan sınıftan:**
1. **Play App Signing'e KAYDOL** (ilk yüklemede, varsayılan açık). Kaydolmazsan
   bu `.jks`'i kaybettiğin an uygulama SONSUZA DEK güncellenemez.
2. **`assetlinks.json`'a bu SHA-256 YAZILMAZ.** Play App Signing açıkken
   kullanıcıya giden paketi GOOGLE kendi anahtarıyla imzalıyor; deep link
   doğrulaması Play Console → App integrity'deki "app signing key"
   parmak izini ister. Yanlışını yazmak hata VERMEZ — linkler sessizce
   tarayıcıda açılır (bkz. `ROADMAP.md` 1. madde).

## Karşılama Katmanı (web) — bilinçli ayrışma (18 Ağustos 2026, 19'unda güncellendi)

Web'e 18 Ağustos 2026'da girişsiz ilk ziyaretçiye gösterilen bir karşılama/
tanıtım katmanı eklendi (kök `CLAUDE.md` → "Karşılama Katmanı" bölümleri —
kapı script'i, statik HTML prerender, tanıtım tahtaları, k-lig mühürleri,
SSS). Bu bölüm önceki "Web ↔ Uygulama Arasındaki Kabul Edilmiş Farklar"
listesinin TERSİ bir durum: burada web'in ÇÖZDÜĞÜ bir şeyi app'in eskisi
gibi bırakması değil, web'de YENİ bir özellik var ve app'te hiç YOK — üç
madde:

1. **Kurulum ekranındaki `<` (tanıtım sayfasına dönüş) düğmesi web'e
   özgüdür, BİLİNÇLİ ayrışmadır — porta EKLENMEYECEK.** Uygulamada
   karşılama katmanı hiç olmadığından bu düğmenin gideceği bir yer de yok;
   bir sonraki denetimde biri "port geride kalmış" deyip düğmeyi porta
   eklemeye kalkışmasın diye
   bu not burada duruyor.
2. ~~**Uygulamanın kendi ilk açılış/tanıtım ekranı AYRI ve planlı bir
   iş**~~ → **19 Ağustos 2026'da YAPILDI (Parça 116, `ui/intro/`).**
   Ana port spesifikasyonu (PORT_BRIEF) bunu *"Setup'ın ÖNÜNE eklenen yeni
   bir ekran, kalıcı bir 'bir daha gösterme' bayrağıyla; mevcut ekranlar
   değişmez; mağaza çıkışından önce bitmeli"* diye tarif ediyordu — üçü de
   aynen uygulandı. Web'in karşılama katmanından yalnızca METİN taşındı;
   katmanın kendisi (statik HTML prerender, kapı script'i, SEO/paylaşım
   yüzeyleri, iki tahta demosu) porta taşınMADI ve taşınmayacak.
3. **O ekran geldi ve Setup başlığına yine de bir ok/düğme KONMADI.**
   Native bir uygulamada kök ekranın sol üstündeki geri oku navigasyon
   yığınını POP etmek demektir; Setup zaten kök ekran ve iOS'ta bu,
   sistemin kendi geri hareketiyle (edge-swipe) çakışırdı. Tanıtıma dönüş
   **Setup'ın logo altındaki link satırında** ("Nasıl oynanır? · Tanıtım")
   — 19 Ağustos 2026'da kullanıcı isteğiyle hesap menüsünden oraya taşındı;
   boşalan yere geçen "Arkadaşınla paylaş" ise footer'a indi (bkz. Parça
   117). Başlık geometrisine hâlâ dokunulmuyor.
   **Yan sonuç, bilerek:** o satır YALNIZCA MİSAFİRDE görünüyor (17 Ağustos
   kararı), yani girişli kullanıcının tanıtıma dönüş yolu YOK. Web'deki
   `<` düğmesi de aynı şekilde yalnızca girişsizde çiziliyor (kök
   `CLAUDE.md` → "Setup'taki `<` düğmesi artık YALNIZCA girişsiz
   kullanıcıda görünüyor"), yani bu bir sapma değil parite.

