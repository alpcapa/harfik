# Kelimeki — Sıradaki İşler (22 Ağustos 2026)

**Bu dosya bir FİKİR LİSTESİ DEĞİL, sıralı bir yürütme planı.** Kök
`CLAUDE.md`'deki "Sonraya Bırakılan Ürün Fikirleri" bölümü *ne* yapılacağını
ve *neden* ertelendiğini anlatır; burası *hangi sırayla*, *hangi modelle* ve
*hangi tuzaklara dikkat ederek* yapılacağını anlatır.

Bir madde bitince buradan SİLİNİR ve kaydı ilgili bölümün kendi tarihli
notuna taşınır (projenin genel "değişiklik = tarihli not" disiplini).

**Durum (25 Ağustos 2026):** `main` yeşil. FAZ A1 cihaz turu Bölüm 6
(Paylaşma, iPad popover) hariç kapalı. Web + port paritesi güncel.
**24-25 Ağustos Android cihaz turu TEMİZ geldi** (dokunma hedefleri, "← Geri",
Paylaş, tahta açılışı, k-lig/Skor Kartı yükleme — yani #324 ve #325'in
cihazdaki karşılığı doğrulandı). **Madde 8 bundan ETKİLENMEDİ:** oradaki iş
iPad'in popover ankrajı, bu tur Android'de koşuldu.
**Google Play Console hesabı açıldı** (22 Ağustos) — bu, listenin sırasını
değiştirdi: artık omurga aşağıdaki **madde 0 (FAZ B)**, çünkü kişisel
hesaplarda production'a çıkmanın önünde **daha başlamamış 14 günlük bir
tester sayacı** var. Maddeler 1, 2 ve 4 o fazın içinde yaşıyor.

**21 Ağustos'ta kapanan ÜÇ madde** (kalan maddelerin numaraları DEĞİŞMEDİ):
- eski **#3** (istemci hata telemetrisi) — `client_errors` tablosu + web/port
  raporlayıcıları + admin panelinde "Hatalar" sekmesi. Kaydı kök
  `CLAUDE.md` → "İstemci Hata Telemetrisi" bölümünde.
  **Ders (bu turda çıktı):** dördüncü admin sekmesi tek sıraya SIĞMIYORDU —
  320px'te kabı 77px aşıp `overflow-hidden` tarafından sessizce kırpılıyordu.
  Bir sekme/buton eklemek "tek satır" değil bir DÜZEN değişikliğidir; ölç.

Aşağıdaki ikisinin kaydı kök `CLAUDE.md` → Kaynak Hunisi bölümünde:
- eski **#9** ("Oyun başladı" olayı) — `game_starts` tablosu + huniye
  "Başlayan" sütunu, web + port. Bir sonraki reklam harcaması artık
  ölçülebilir.
- eski **#7** (davet linkine `?ref=arkadas`) — "tek satır" sanılıyordu,
  ÖLÇÜNCE tek başına no-op olacağı çıktı: `/davet/:token` ve `/game/:id`
  `?ref=` etiketini HİÇ yakalamıyordu (`captureUtmSource` `App.tsx`'teydi,
  o iki route `App`'i mount etmiyor). Yakalama `boot.tsx`e taşındı.
  **Ders:** bu dosyadaki efor tahminleri (`low`/`medium`) bir SÖZ değil —
  işin gerçekten tek satır olduğunu ölçmeden varsayma.

---

## Modeller — hangi iş için hangisi

Ölçüt maliyet değil **hata bedeli** ve **ufuk uzunluğu**:

| Model | Ne zaman |
|---|---|
| **Fable 5** (`claude-fable-5`) | Geri dönüşü OLMAYAN ya da çok uzun ufuklu iş: veri silme kaskadı, çok platformlu yapılandırma zincirleri. En yetenekli model; pahalı, o yüzden yalnızca bu iki sınıf için. |
| **Opus 5** (`claude-opus-5`) | Varsayılan. Tasarım kararı gerektiren, çok dosyaya yayılan, ama geri alınabilir işler. |
| **Sonnet 5** (`claude-sonnet-5`) | Spesifikasyonu bu dosyada NET yazılmış, mekanik iş. Takılırsa Opus 5'e yükselt — inatla devam ettirme. |

**Efor:** uzun/agentic işlerde `high`–`xhigh`; mekanik işlerde `low`–`medium`.

---

## Bu projede bir oturumun gerçek maliyeti

19 Ağustos turunda ölçüldü — planlarken bunu hesaba kat:

- **`mobile/**` altına dokunan her PR** şu boru hattını tetikliyor: Analiz +
  testler (~3 dk) → Android APK (~5 dk) → iOS (~5 dk) → `main`'e merge
  sonrası Pages yayını. Tur başına **15-20 dk** ve birkaç mesaj.
- **Yalnızca web** (`src/**` vb.) → yalnız `web-ci.yml`, ~2 dk.
- **Yalnızca doküman** (`*.md`) → **hiç CI koşmaz.** Ücretsiz.
- **Taslak PR deseni işe yarıyor:** Flutter SDK bu ortamda YOK, yani Dart
  testleri yalnızca CI'da koşuyor. Emin olmadığın bir Dart değişikliğini
  önce `draft: true` PR ile CI'a sor, yeşilse merge et. 19 Ağustos'ta bu,
  iki bozuk testin `main`'e girmesini önledi.

---

## 0. FAZ B — Google Play yayını — **SIRA OMURGASI**

**Durum (22 Ağustos 2026):** Play Console hesabı açıldı ve kayıt işlemleri
bitti (*Personal account*, Account ID `5939732949280610022`), henüz **sıfır**
uygulama var. Aşağıdaki 1, 2 ve 4 numaralı maddeler bu fazın parçaları —
bu bölüm onların **hangi sırayla** yapılacağını söyler.

**TAKVİMİ BELİRLEYEN TEK ŞEY:** Kasım 2023'ten sonra açılan **kişisel**
hesaplarda Play, production'a başvurmadan önce kapalı testte **en az 12
tester'ın 14 gün boyunca kesintisiz kayıtlı** kalmasını istiyor. Yani
"her şey bitince yayınlarım" MÜMKÜN DEĞİL — ortada daha başlamamış 14
günlük bir sayaç var. Sol menüdeki **Android developer verification**
(kimlik doğrulama) da tamamlanmalı.

**Bu yüzden sıra "kolaydan zora" değil: ÖNCE SAYACI BAŞLAT.** Ağır işler
(hesap silme, deep link) o 14 gün içinde paralel yürür.

### 0.A — Sayacı başlatan minimum (bunlar olmadan dosya YÜKLENEMEZ)

**Model: Opus 5, efor `high`.** Tasarım kararı az, ama 0.A1'in kaybı
telafi edilemez (aşağı bkz.) — Sonnet'e verme.

Dördü de **ölçülmüş** eksikler, tahmin değil:

| | Eksik | Kanıt | Yapılacak |
|---|---|---|---|
| 0.A1 | ✅ **BİTTİ** (22 Ağu 2026) — release DEBUG anahtarıyla imzalanıyordu | `build.gradle.kts:31` → `signingConfigs.getByName("debug")` + `// TODO` | Upload keystore üretildi (RSA 4096, 2054'e kadar); `key.properties` varsa release, yoksa **bilerek** debug'a düşüyor |
| 0.A2 | ✅ **BİTTİ** (22 Ağu 2026) — CI yalnızca `.apk` üretiyordu | `mobile-build.yml:157` → `flutter build apk --release` | `android` işine `.aab` adımı eklendi; secret yoksa sessizce atlar, varsa paketin imzasını **geri okuyup** doğrular |
| 0.A3 | ✅ **BİTTİ** (22 Ağu 2026) — sürüm `0.1.0+1`di | `pubspec.yaml` + `env.dart` (`appVersion`) | İkisi de **`1.0.0`**; senkron artık `test/app_version_parity_test.dart` ile ZORLANIYOR. `versionCode`'u CI `--build-number=run_number` ile veriyor |
| 0.A4 | ✅ **BİTTİ** (23 Ağu 2026) | `marketing/play-store/` | İkon (512) + öne çıkan görsel (1024×500) + başlık/kısa/tam açıklama üretildi (`npm run generate-play-assets`). Telefon ekran görüntüleri **gerçek cihazdan alındı** (7 kare, 1080×2400) ve Play'in 2:1 oran tavanına sokmak için **1080×2072'ye kırpıldı**; dosyalar kullanıcıda. Kırpmanın neden zorunlu olduğu `marketing/play-store/metin.md` → "Teknik gereksinim" |
| 0.A5 | ✅ **BİTTİ** (23 Ağu 2026) — politika YALNIZCA SPA modalıydı | `?gizlilik=1` | `/gizlilik/` · `/kullanim-kosullari/` · `/hesap-silme/` derleme zamanı statik sayfa; metin tek kaynakta. Sonuncusu Data safety formunun istediği **web silme adresi** |

**0.A1 + 0.A2 + 0.A3 BİTTİ (22 Ağustos 2026).** GitHub secret'ları
(`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`) kullanıcı
tarafından girildi. Ayrıntı, ölçümler ve negatif eşler: `mobile/CLAUDE.md`
→ "Play Store İmzalama ve `.aab`".

**CI'DA DOĞRULANDI (23 Ağustos 2026, koşu 32644482976, sha `a22cea6`):**
`.aab` gerçekten üretildi (60.9 MB, artefakt `kelimeki-aab`) ve log'daki
`beklenen:` / `paket   :` parmak izleri hem birbirine hem üretilen upload
anahtarına eşit — yani secret'lar okundu, Gradle `key.properties`i gördü,
paket debug değil upload anahtarıyla imzalandı. `.apk` artefaktı da
yerinde (Appetize akışı bozulmadı).

**ÖLÇÜLDÜ (24 Ağustos 2026) — ikisi de temiz, aksiyon GEREKMİYOR.** Kaynağa
değil YAYINLANMIŞ pakete bakıldı: `mobile-latest`teki `kelimeki.apk`
(sha `18689eb`) indirilip derlenmiş `AndroidManifest.xml`i çözüldü.

| | Ölçülen | Sonuç |
|---|---|---|
| `minSdkVersion` | **24** (Android 7.0) | — |
| `targetSdkVersion` | **36** | Android'in en yeni API seviyesi; Play'in asgarisinin ALTINDA olması mümkün değil → **pinlemeye gerek yok** |
| İzinler | **3 adet** (aşağı) — Play'in `.aab`'de gösterdiği **4** (bkz. not) | Data safety beyanı etkilenmiyor |

İzinlerin tamamı: `INTERNET` (Parça 131 düzeltmesi — pakette olduğu böylece
ikinci bir yoldan da doğrulandı), `ACCESS_NETWORK_STATE` (connectivity_plus)
ve `com.kelimeki.kelimeki.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
(AndroidX'in kendi ürettiği iç izin — kullanıcıya görünmez, beyan edilmez).

**DÜZELTME (25 Ağustos 2026):** yukarıdaki "3 izin" YAYINLANMIŞ `.apk`'dan
ölçülmüştü; Play Console'un paket ayrıntısı `.aab` için **4** gösteriyor.
Fark `com.android.vending.CHECK_LICENSE` — beyanı değiştirmiyor (çalışma
zamanı izni değil, veri toplamıyor). Ders: `.apk` ölçümü `.aab`'yi
kanıtlamıyor, Play bundle'ı işlerken manifeste ekleme yapabiliyor. Ayrıntı:
`marketing/play-store/console-formlari.md` § 6.

**`image_picker` HİÇBİR izin eklememiş** — bu dosyanın beklediği risk
gerçekleşmedi. Modern Android'de Photo Picker/SAF üzerinden çalıştığı için
depolama/medya izni istemiyor. Yani Data safety formunda medya erişimi
beyan edilmeyecek.

**0.A bölümünün TAMAMI bitti.** Sıradaki: ilk `.aab` yüklemesi → kapalı test
kanalı → 12 tester → 14 günlük sayaç başlar.

**Console'a girilecek her formun cevabı yazıldı (24 Ağustos 2026):**
`marketing/play-store/console-formlari.md` — adım sırası, Data safety veri
türü eşlemesi (her satırın kodda karşılığıyla), IARC anketi, App access test
hesabı, kapalı test kanalı ve tester metni. Vitrin METİNLERİ hâlâ
`metin.md`'de.

**ÖLÇÜLDÜ (24 Ağustos 2026) — `.aab` indirilebilir DEĞİLDİ, düzeltildi:**
0.A2 paketi yalnızca `actions/upload-artifact` ile bırakıyordu; artefakt
bağlantısı oturum istiyor ve dosyayı ZIP'liyor — yani iPad'den yükleyecek
kişi için `.apk`nın 7 Ağustos'ta çözülen probleminin aynısı hâlâ açıktı
(`build-and-distribution-log.md` → Appetize). `mobile-build.yml`'in release
adımı artık `kelimeki.aab`'yi de `mobile-latest`e koyuyor:
`https://github.com/alpcapa/kelimeki/releases/download/mobile-latest/kelimeki.aab`.
Artefakt DURUYOR. **DOĞRULANDI (25 Ağustos 2026, koşu 349, sha `5eddf3d`):**
dosya release'te, 60.929.323 bayt. Kanıt PR'da alınamazdı — release adımı
PR'da bilerek atlanıyor (workflow başlığındaki "YAYINLAMA" notu) — bu yüzden
merge sonrası ilk `main` koşusunda okundu.
**Yüklenmeye hazır paketin `versionCode`'u: 349.**

**Tuzaklar — 0.A1:**
- **Keystore repoya GİRMEZ.** `*.jks`/`key.properties` gitignore'a; CI'a
  base64 GitHub secret olarak. Bu dosyayı **kullanıcı kendi tarafında da
  yedeklemeli** — Claude'un ürettiği bir dosyanın tek kopyası CI'da kalırsa
  iş kaybedilebilir.
- **Play App Signing'e kaydol.** Kaydolursan upload anahtarı kaybedilse
  bile sıfırlanabilir; kaydolmazsan anahtarın kaybı = uygulamanın bir daha
  asla güncellenememesi.
- **`assetlinks.json`'a hangi parmak izinin gireceği bu kararla değişiyor:**
  Play App Signing kullanılıyorsa oraya **Play'in ürettiği** SHA-256 girer,
  senin upload anahtarınınki DEĞİL. Yanlışını koymak App Links'i sessizce
  kırar (madde 1 ile aynı iş).
  **YAPILDI (25 Ağustos 2026):** dosya `public/.well-known/assetlinks.json`
  olarak yazıldı, içinde Play'in ürettiği (Classical) parmak izi var —
  upload anahtarı (`B6:CD:FB:A9…`) DEĞİL. Ayrıntı ve ölçümler:
  `marketing/play-store/console-formlari.md` → §6.6.

**Tuzaklar — 0.A2/0.A3:**
- `targetSdk` hâlâ `flutter.targetSdkVersion`'dan geliyor
  (`build.gradle.kts:47`), yani pinli DEĞİL — ama ölçüldüğünde **36** çıktı
  (yukarı), o yüzden bugün pinlemeye gerek yok. Flutter kanalı geri giderse
  bu sessizce düşebilir; sürüm yükseltmelerinde yeniden ölç.
- `image_picker`'ın izin eklemediği **ölçüldü** (yukarı) — paket yalnızca 3
  izin taşıyor ve hiçbiri medya/depolama değil.
- **Paket adı `com.kelimeki.kelimeki` ilk yüklemeden sonra KALICI**
  (`mobile/CLAUDE.md`). Değişecekse bu adımdan ÖNCE.

**0.A5 NEDEN 0.B'DEN BURAYA TAŞINDI (23 Ağustos 2026, ölçüldü):** Play'in
kendi dokümanı, **Data safety formunun kapalı/açık test kanallarındaki
uygulamalar için de zorunlu** olduğunu ve **formu tamamlamak için gizlilik
politikası URL'inin gerektiğini** söylüyor. Yani politika sayfası "14 gün
işlerken paralelde" yapılacak bir iş DEĞİL — onsuz ilk kapalı test
yayınlanamaz, dolayısıyla sayaç hiç başlamaz. Bu dosya 22 Ağustos'ta onu
0.B'ye koymuştu; o sıralama YANLIŞTI.

**Çıkış kriteri:** imzalı AAB kapalı test kanalına yüklendi, 12 tester
kaydoldu, **sayaç işlemeye başladı.**

**DURUM (25 Ağustos 2026):** Console'daki her form dolduruldu, kapalı test
sürümü incelemeye gönderildi ve **YAYINLANDI** — Submission 1 durumu
`Published`, opt-in linki oluştu. Adım adım ne girildiği ve neden:
`marketing/play-store/console-formlari.md` § 6.5.

**Kriter HENÜZ karşılanmadı:** sayaç 12 kişi opt-in olduğunda başlıyor,
listede 9 adres var. Kalan tek iş kod değil — tester toplamak.

### 0.B — 14 gün işlerken paralelde

Sırası önemli olan tek bağ: **#4, #2'den SONRA** (hesap silme kaskadı
çıkmadan test hesaplarını silmek aynı analizi iki kez yaptırır).

1. **Madde 2 — uygulama içinden hesap silme.** Play'in hesap açtıran
   uygulamalardan istediği İKİ şey var: uygulama içi yol **ve** Data
   safety formuna girilecek bir **web silme talep URL'i** (ölçüldü, ikisi
   de politika metninde açık). **Web yarısı 0.A5'in sayfasına bir bölüm
   olarak bedavaya geliyor; asıl iş uygulama içi yol ve silme kaskadı.**
   Bu, production erişimi için ZORUNLU — 14 günün içinde bitmeli.
3. **Madde 1 — deep link.** Play blokeri değil ama
   kayıt onayı maili uygulamayı değil web'i açıyor; inceleme "kırık akış"
   diye dönebilir. iOS yarısı Apple hesabı istediğinden bekler.
   **`assetlinks.json` bu maddeden AYRILDI ve bitti** (25 Ağustos 2026,
   §6.6) — parmak izi Console'dan ancak `.aab` yüklendikten sonra
   okunabildiğinden dosya o anda yazıldı; maddenin geri kalanı (intent
   filter, Supabase redirect allow-list, e-posta şablonları, Flutter
   yönlendirme) duruyor.
4. **0.C — App content formları** (aşağı).
5. **Madde 4 — test hesaplarının silinmesi.** ⚠ **`T2` SİLİNMEYECEK** —
   App access formunda incelemeciye verilen hesap o (yukarı, 0.C).

### 0.C — Play Console'da doldurulacak formlar (kod işi değil, zorunlu)

**Cevapların TAMAMI `marketing/play-store/console-formlari.md`'de** (24
Ağustos 2026). Aşağısı yalnızca hangi formun neden riskli olduğunun özeti.

- **Data safety — en dikkatli iş.** Beyan ile gerçek ayrışırsa askıya alma
  sebebi. Toplananlar: e-posta, ad/soyad, takma isim, cinsiyet, doğum
  tarihi, profil fotoğrafı, **oyun içi mesajlar**, anonim cihaz kodu
  (`anon_id`), hata telemetrisi (`client_errors`), ziyaret/oyun başlangıç
  olayları. **Kaynak metin hazır:** `PrivacyModal`'ın "Toplanan Veriler"
  bölümü satır satır forma eşlenmeli. Üçüncü taraflar: Supabase, Brevo,
  Vercel (19 Ağustos'ta politikaya eklendi). **"Paylaşılıyor" her satırda
  HAYIR** — hizmet sağlayıcı ve kullanıcının başlattığı görünürlük
  istisnalarıyla; 24 Ağustos 2026'da kullanıcı onayladı, gerekçe
  `console-formlari.md` §3.8'de.
- **Content rating (IARC):** ✅ **BİTTİ (25 Ağustos 2026).** Sohbet beyan
  edildi. Bu satır "yaş derecesini yükseltir" diyordu — **ölçüm bunu
  doğrulamadı:** sonuç en düşük bant (PEGI 3, USK 0, ESRB Everyone,
  IARC 3+). Sebebi, sohbete yalnızca kabul edilen arkadaşın girebilmesi ve
  sessize alma/şikayetin var olması.
- **UGC / moderasyon:** sohbet olduğu için gerekiyor. Karşılayacak
  mekanizma ZATEN var — sessize alma, şikayet, hesap dondurma, admin
  paneli; yalnızca beyan edilecek.
- **App access:** Canlı oyun/arkadaş özellikleri giriş istiyor →
  incelemeciye **çalışan bir test hesabı** verilmeli (bkz. 0.B/5).
  **Hesap seçildi: `T2` (`kelimekitest2`), 24 Ağustos 2026.** `T1`
  kullanılmıyor — e-postası geliştiricinin kişisel adresi. T2'nin durumu
  üretim veritabanından ölçüldü: doğrulanmış, dondurulmamış, 3 arkadaş,
  1 aktif Canlı oyun, 11 bitmiş oyun — yani incelemecinin göreceği dört
  ekran da boş değil.
- **Ads:** yok · **Advertising ID:** kullanılmıyor · **Government /
  Financial / Health:** hayır.
- **Target audience:** **13+ öner** — 13 yaş altı hedeflenirse "Families"
  politikası devreye girer, çok daha ağır bir rejim.

### 0.D — Vitrin varlıkları

**23 Ağustos 2026'da üretildi** (`npm run generate-play-assets`,
`marketing/play-store/`) — bu bölüm artık yalnızca kalanı listeliyor:

- İkon **512×512** ✓ — cihazdaki başlatıcı ikonun KAYNAĞINDAN küçültüldü
- **Feature graphic 1024×500** ✓ — üretim bileşenlerinden render edildi
- Başlık (29/30) · kısa açıklama (79/80) · tam açıklama (1906/4000) ✓ —
  `marketing/play-store/metin.md`
- ✅ **Telefon ekran görüntüleri** — 7 kare, gerçek cihazdan, 1080×2072'ye
  kırpıldı (23 Ağu 2026, dosyalar kullanıcıda). Çekim listesi + gizlilik
  uyarıları + oran kuralı `metin.md`'de. Tablet desteği iddia edilecekse
  tablet görselleri ayrıca gerekir.
- ⬜ Kategori **Oyunlar → Kelime**, iletişim e-postası, web sitesi
  (Console'a elle girilir)

**Görseller elle çizilmez:** reklam kareleri (`scripts/sponsored-post/`) ve
reel (`scripts/reel/`) zaten ÜRETİM bileşenlerini sunucuda render eden bir
desen kurdu — mağaza görselleri de aynı yoldan üretilmeli, yoksa vitrin ile
ürün sessizce ayrışır. **Tuzak:** o betiklerde Tailwind sınıfı çalışmaz
(`content` yalnızca `index.html` + `src/**` tarar), yalnızca inline `style`.


## 1. `kelimeki://` deep link kanalı — **MAĞAZA BLOKERİ**

*FAZ B'nin parçası — sıradaki yeri: madde 0 → 0.B/3.*

**Model: Fable 5, efor `xhigh`.** Üç platform yapılandırması + Supabase Auth
+ Flutter yönlendirme aynı anda; hiçbiri bu ortamdan uçtan uca test
edilemiyor, yani her adım "kör" yazılıp cihazda doğrulanacak.

**Neden FAZ B'nin erken bir maddesi:** 17 Ağustos'ta cihazda bizzat gözlendi — kayıt onayı
e-postasındaki bağlantı uygulamayı değil `kelimeki.com`'u açtı, üstelik o
sekmede BAŞKA bir hesap açıktı. `mobile/CLAUDE.md` bunu *"mağazaya çıkışta
kabul edilemez"* diye kaydetmiş. Diğer iki bloker (2 ve 3) bundan daha az
acil.

**Kapsam — üç akış:** kayıt onayı, şifre sıfırlama, arkadaş daveti
(`/davet/:token`).

**Dokunulacaklar:**
- Supabase Dashboard → Auth → URL Configuration (redirect allow-list) ve üç
  e-posta şablonu (`supabase/email-templates/*.html` — bunlar Dashboard'a
  ELLE yapıştırılıyor, repo otomatik okunmuyor; bkz. kök `CLAUDE.md`).
- iOS: `Info.plist` URL scheme + Associated Domains.
- Android: intent filter. **`assetlinks.json` ARTIK BEKLEMİYOR** — 25
  Ağustos 2026'da `public/.well-known/assetlinks.json` olarak yazıldı ve
  Vercel'den (`kelimeki.com`) servis ediliyor; "Pages'ta barındırılacak"
  planı geçersiz, çünkü uygulamanın açacağı adresler zaten `kelimeki.com`
  altında.
- Flutter: gelen linki karşılayan yönlendirme + `friendInvite` kuyruğuyla
  (web'deki `kelimeki:pending-invite` deseninin portu) birleştirme.

**Tuzaklar:**
- Universal Links yalnızca App Store'dan kurulan uygulamalarda çalışıyor —
  "Ana Ekrana Ekle" PWA'sı bu mekanizmaya HİÇ giremiyor (kök `CLAUDE.md`,
  `AddToHomeScreen` notu). Yani bu iş FAZ B'yi (gerçek imzalı derleme)
  fiilen zorunlu kılıyor.
- Auth şablonları değişirse `_shared/email.ts`'in marka sarmalayıcısıyla
  ayrışmasınlar (kök `CLAUDE.md`, "Marka şablonu").

**Ön koşul:** Apple Developer üyeliği + imzalama anahtarı. Bunlar yoksa iş
yarıda kalır — **başlamadan önce teyit et.**

---

## 2. Uygulama içinden hesap silme — **MAĞAZA BLOKERİ**

*FAZ B'nin parçası — sıradaki yeri: madde 0 → 0.B/2. Play ayrıca Data
safety formuna girilecek bir **web silme talep URL'i** de istiyor; o,
0.B3'ün statik sayfasına bir bölüm olarak eklenir.*

**Model: Fable 5, efor `xhigh`.** Bu listedeki tek GERİ DÖNÜŞSÜZ iş.

**Neden:** Apple 5.1.1(v) ve Google'ın veri silme şartı, hesap açtıran
uygulamalarda uygulama İÇİNDEN başlatılabilen bir silme yolu istiyor. Bugün
hiç yok. **Hukuken zorunlu değil** (KVKK m.7/m.11 ve GDPR m.17 hakkı verir,
buton şart koşmaz) — Gizlilik Politikası 19 Ağustos'ta bunu "Görüş
Bildir'den talep edin, 30 gün" olarak doğru anlatacak şekilde düzeltildi.
Yani bu madde **mağaza kapısı** için var; web'de gerekmez (kullanıcı kararı,
19 Ağustos).

**İşin ağırlığı UI'da değil kaskad zincirinde.** Silinecek/anonimleştirilecek
yerler en az: `auth.users`, `profiles`, `games`, `game_likes`,
`friend_requests`, `friend_invite_links`, `local_game_saves`,
`online_game_*` (state/secrets/moves/messages/mutes/reports/clients),
`feedback`, `league_rewards`, `admin_ban_log`, `avatars` storage kovası.
Bir kısmı cascade, bir kısmı değil.

**Kritik karar:** silinen kişi BAŞKALARININ bitmiş oyun kayıtlarında
(`games.players` snapshot'ı) isimle duruyor. O satırlar başka kullanıcıların
kendi verisi — silinemez, en fazla anonimleştirilebilir. Bu kararı
kullanıcıya sor.

**Yöntem:** service-role bir Edge Function (`delete-my-account`) +
çağıranın kendi JWT'si ile kimlik doğrulama. Önce **kuru çalıştırma**:
silinecek satır sayılarını döndüren bir rapor, kullanıcıya göster, sonra
uygula.

**Zorunlu ekler:** `PrivacyModal` + portun `legal_modals.dart`'ı (tarihler
`legal_text_test.dart` ile karşılaştırılıyor, biri bayat kalırsa mobil CI
düşer).

---

## 4. Test hesaplarının silinmesi — **TEMİZLİK, GERİ DÖNÜŞSÜZ**

*FAZ B'nin parçası — sıradaki yeri: madde 0 → 0.B/5. ⚠ App access formuna
incelemeciye verilen hesabı silme.*

**Model: Opus 5, efor `high`.** Küçük ama geri alınamaz; Sonnet'e verme.

23 üyenin 5'i test hesabı ve tüm büyüme metriklerini kirletiyor:
`T1` (alp.capa@hotmail.com — **kullanıcının KENDİ kişisel e-postası**),
`T2`, `T3`, `T4`, `T5` (tek kullanımlık testinator adresleri).

**`Ironman` (alprcapa@gmail.com) HİÇBİR KOŞULDA SİLİNMEZ** — hesap
sahibinin gerçek ana/admin hesabı (kullanıcı kararı, 14 Ağustos).

**Sıra önemli:** madde 2 (hesap silme) BİTTİKTEN SONRA yap — o iş zaten
kaskad zincirini çıkarmış olur ve bu silme onun ilk gerçek kullanımı olur.
Öncesinde yapılırsa aynı analiz iki kez yapılır.

Silmeden önce kaskad zincirini çıkarıp kullanıcıya göster: geri dönüşü yok.

---

## 5. k-lig puan grafiği — **İSTEĞE BAĞLI**

**Model: Sonnet 5, efor `medium`.** Spesifikasyon kök `CLAUDE.md`'de eksiksiz
yazılı (seri nasıl kurulur, hangi oyunlar atlanır, hangi etiketler). Takılırsa
Opus 5'e yükselt.

**Ertelemenin maliyeti SIFIR** — `games.created_at` durduğu sürece seri her
zaman geriye dönük kurulabilir. Bugün 15 kullanıcının yalnızca 4'ünde dolu
bir grafik çıkıyor ve `league_rewards`'ta toplam 6 satır var, yani etiketler
neredeyse boş. Ironman 100 puanı geçtiğinde anlam kazanmaya başlar.

**Değişmez:** son nokta `player_stats_overall.total_score` ile BİREBİR
eşleşmeli (14 Ağustos'ta canlıda 15/15 kullanıcıda doğrulandı). Web + port
AYNI PR'da.

---

## 6. Taranabilir `/nasil-oynanir` sayfası — **İSTEĞE BAĞLI**

*Aşağıdaki üç gizli bağ ve statik üretim deseni 0.B3'teki (zorunlu)
gizlilik sayfası için de birebir geçerli — hangisi önce yapılırsa
diğerinin yolunu açar.*

**Model: Opus 5, efor `high`.** Basit görünüyor ama üç gizli bağı var.

**Neden:** Google AI Mode Kelimeki'yi "kelime bulucu ve sözlük platformu"
diye tamamen uydurdu (17 Ağustos, üç ekran görüntüsüyle). Sitenin en zengin
açıklayıcı içeriği (`HelpModal`) yalnızca modal açılınca render oluyor,
taranabilir HTML'de hiç yok.

**Gizli bağlar — yapmadan ÖNCE oku:**
1. `mobile/app/test/help_text_parity_test.dart` **doğrudan
   `src/components/HelpModal.tsx`'i okuyor** ve `<Section title="…">` /
   `<QuickItem icon="…">` regex'leriyle tarıyor. İçeriği başka dosyaya
   çıkarmak o testi düşürür — üstelik web'e dokunduğun için bakmayacağın
   mobil tarafta.
2. İçerik TEK KAYNAKTA kalmalı; modal ve sayfa AYNI bileşeni tüketmeli.
   İki kopya bu projenin en sık tekrarlayan hata sınıfı.
3. Sayfanın KENDİ `title`/`description`'ı olmalı, yoksa SPA'nın genel
   meta'sını miras alır ve kazancın yarısı gider.

**Client-render YETMEZ:** Googlebot JS çalıştırıyor ama AI/LLM crawler'ları
çalıştırmıyor — sorunu doğuran şeyi tam olarak ıskalar. Derleme-zamanı
statik üretim gerekiyor (`generate-og-image` deseni →
`dist/nasil-oynanir/index.html`). Vercel'in statik dosyayı rewrite'tan ÖNCE
servis ettiği DOĞRULANMALI.

**Ayrıca:** `sitemap.xml` (şu an tek URL) ve PWA precache listesi.

---

## 8. FAZ A1 Bölüm 6 (Paylaşma) — cihazda kapatılacak

Kod işi yok; iPad popover ankrajı (Parça 86) gerçek cihaz istiyor. FAZ B
turunda kapanır.

---

## 9. Admin Üyeler tablosuna "onaylanmamış" filtresi — **İSTEĞE BAĞLI**

**Model: Sonnet 5, efor `medium`.** Salt-okunur bir liste filtresi.

Kullanıcı 23 Ağustos 2026'da onayladı ("Filtre kalsın") ama o günkü "hemen
canlıya alalım" kapsamının DIŞINDA bırakıldı — asıl sorun (onaylanmamış
hesabın takma adı süresiz kilitlemesi) artık saatlik süpürmeyle çözülü
(bkz. kök `CLAUDE.md` → "Onaylanmamış hesap süpürmesi"), yani bu filtre bir
arıza değil bir görünürlük kolaylığı.

**Ne:** Üyeler tablosunda "yalnızca onaylanmamışları göster" seçeneği. Bugün
`admin_list_members` bu alanı HİÇ döndürmüyor — `auth.users.email_confirmed_at`
istemciye kapalı, yani RPC'ye bir kolon eklemek gerekiyor (dönüş tipi
değişince `create or replace` YETMEZ, drop+create + grant'leri elle geri kur;
kayıtlı tuzak: `fix_withdraw_report_wrong_overload`).

**Kapsam kararı:** yeni kolon Üyeler tablosunda gösterilecekse CSV'ye de
eklenmeli — "CSV ekranda görüneni indirir" sözü ancak öyle doğru kalır.
Sıralama anahtarı EKLEME (mevcut yedi anahtar korunuyor, gerekçesi
`CLAUDE.md` → "Kayıt alanlarının tamamı tabloda").

---

## 10. Hata raporlama hız sınırı süreç ömrüne değil ZAMANA bağlansın — **İSTEĞE BAĞLI**

**Model: Sonnet 5, efor `low`.** Spesifikasyon burada net; iki istemcide
aynı sayı.

**Nereden çıktı:** 23 Ağustos 2026'daki "app tarafı geldiğinde ne eksik?"
denetimi. Aynı turda bulunan üç boşluğun üçü de kapatıldı (bkz. kök
`CLAUDE.md` → "Mağaza öncesi üç ekleme"); bu dördüncüsü **bilinçli olarak
ertelendi** — Play yüklemesinin önünde duran bir şey değil.

**Sorun:** `MAX_PER_SESSION = 10` (web `errorReporting.ts`, port
`error_reporter.dart`) + hiç temizlenmeyen imza kümesi. Web'de bir sayfa
yenilemesi ikisini de sıfırlıyor, **app süreci ise günlerce yaşıyor** —
10 FARKLI hatadan sonra o cihaz kalıcı olarak kör kalıyor ve tekrar eden
bir hata süreç başına yalnızca BİR kez sayılıyor.

**Neden bloker DEĞİL (ölçüldü/akıl yürütüldü, 23 Ağustos):** sınır
*tespiti* değil *hacmi* kısıyor — hatayı yine görürsün, "kaç kez" sayısı
eksik kalır. Panelin asıl ölçütü olan **"kaç cihaz"** bozulmuyor (o zaten
cihaz başına tekil sayıyor). 12 tester'lık kapalı testte pratik etkisi yok.

**Ne:** sayaç ve imza kümesi zaman pencereli olsun (ör. son 1 saatte en
fazla 10; pencere kayınca imzalar da düşsün). Çökme döngüsü koruması
KORUNMALI — bu maddenin var oluş sebebi o korumayı gevşetmek değil,
penceresini doğru yere koymak.

**Tuzaklar:**
- İKİ istemci birden — biri değişip öteki kalırsa web ile app farklı
  davranır. Sayı çifti olacağı için `layout_parity_test.dart`in desenine
  uygun bir parite testi düşünülebilir.
- `verify-error-reporting`in "oturum başına en fazla 10 kayıt" kontrolü ve
  Dart'taki eşleniği bu değişiklikle YENİDEN YAZILMALI; ikisi de bugün
  süreç-ömrü varsayımına dayanıyor.

---

## 11. Hata panelinde platform filtresi — **İSTEĞE BAĞLI, app çıkınca**

**Model: Sonnet 5, efor `low`.**

`admin_client_errors(p_days)` yalnızca gün alıyor; platformlar gruplanmış
satırda tek bir birleşik dizede (`platforms`). Bugün tek platform (web)
olduğu için gereksiz — **üç platform (web/ios/android) birden veri
göndermeye başlayınca** "yalnızca iOS'ta olan hata" görünümü gerekecek.

**Ne:** RPC'ye opsiyonel bir `p_platform` (ya da panelde istemci tarafı
filtre — satır sayısı düşükken o da yeterli). Dönüş tipi değişmezse
`create or replace` yeterli; değişirse drop+create + grant'ler elle
(kayıtlı tuzak: `fix_withdraw_report_wrong_overload`).

**Karar tetikleyicisi:** panelde ilk kez ios/android satırları görünüp
web ile karışmaya başladığı gün.

---

## 12. Sürüm dağılımının KAPSAMI — ölç, gerekirse genişlet — **İZLEME**

Kod işi değil, bir **karar noktası.** 23 Ağustos 2026'da eklenen
`admin_app_version_breakdown` (Büyüme > Kullanıcı → "Sürüm Dağılımı")
kaynağını `game_starts`tan alıyor, yani **yalnızca YEREL (YZ) oyun
açılışlarını** sayıyor. Sonucu: yalnız Canlı oynayan bir kullanıcı tabloda
HİÇ görünmez.

Bu sınır bilinçli ve bugün doğru: `game_starts` girişten bağımsız
(misafir dahil) yazılan en geniş kapsamlı istemci olayı ve tablonun tek
işi "`mobile_min_supported_version` eşiğini yükseltmek güvenli mi"
sorusuna cevap vermek.

**Ne zaman yeniden düşünülmeli:** kapalı test sırasında tablodaki toplam,
gerçek tester sayısının belirgin altında kalırsa — yani testerların kayda
değer bir kısmı YZ oyunu hiç açmıyorsa. O gün seçenekler:
- `online_game_clients`e `app_version` eklemek (Canlı tarafı kapsar), ya da
- açılış başına günde bir satır yazan bir "heartbeat" olayı — **bu YENİ bir
  kişisel veri sayılır**, yani `PrivacyModal` + portun `legal_modals.dart`'ı
  birlikte güncellenmeli (tarihler `legal_text_test.dart` ile karşılaştırılıyor).

**⚠ Eşiği yükseltmeden önce bu tabloya bak** — eski sürümden hâlâ oyun
açılıyorsa yükseltmek o kullanıcıları uygulamadan kilitler
(`version_gate.dart`). Bugün `app_config.mobile_min_supported_version`
`{ios: 0.0.0, android: 0.0.0}`, yani kapı fiilen kapalı ve kimse
kilitlenmiyor (23 Ağustos 2026'da canlıdan okundu).

---

## Her iş için değişmeyen kurallar

1. **Önce etki analizi** (kök `CLAUDE.md` → "Çalışma İlkesi"): bu kodun
   ikinci okuyucusu/yazarı var mı? bir zincirin halkası mı? derleyicinin
   göremeyeceği hangi değişmeze dokunuyorum?
2. **Bitince `git status` oku** ve dokunduğun her alanın eşini güncelle —
   `CLAUDE.md`/`README.md`/`TESTING.md`/`mobile/*`.
3. **Migration varsa** MCP ile canlıya uygula, `list_migrations` ile dosya
   adını gerçek versiyonla eşleştir, ve **fonksiyonu GERÇEKTEN çağır** —
   "uygulandı" yetmez (bu projede geçerli SQL iki kez ilk çağrıda patladı).
4. **Ölçmeden "ölçüldü" yazma.** Flutter SDK bu ortamda yok; Dart tarafında
   bir sayıyı ancak CI ya da cihaz kanıtlar.
5. **Geometri ölçen bir teste `setUpAll(loadAppFonts)` şart** — yoksa
   Ahem'in düzenini ölçersin, ürünün değil (19 Ağustos'ta iki testi birden
   düşürdü).
6. **Düzen testinin boyu** ürünün göründüğü EN DAR/EN KISA yüzeyi temsil
   etmeli — etmiyorsa yeşil olması hiçbir şey garanti etmez.
