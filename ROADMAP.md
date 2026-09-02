# Kelimeki — Sıradaki İşler (22 Ağustos 2026)

**Bu dosya bir FİKİR LİSTESİ DEĞİL, sıralı bir yürütme planı.** Kök
`CLAUDE.md`'deki "Sonraya Bırakılan Ürün Fikirleri" bölümü *ne* yapılacağını
ve *neden* ertelendiğini anlatır; burası *hangi sırayla*, *hangi modelle* ve
*hangi tuzaklara dikkat ederek* yapılacağını anlatır.

**Burada YALNIZCA AÇIK maddeler yaşar.** Bir madde kapandığında (✅ /
YAPILDI / KAPANDI / CANLIDA / SAHADA) **aynı PR'da**
`docs/decisions/roadmap-arsiv.md`'ye taşınır — başlığı, madde numarası ve
tek tek satırları değiştirilmeden, böylece ona yapılan atıflar kırılmaz.
Kalıcı bir ders üretmişse dersin kendisi ayrıca ilgili bölümün tarihli
notuna geçer (projenin genel "değişiklik = tarihli not" disiplini).

⚠ **Aşağıda bir bölüme atıf görüp bulamıyorsan arşive bak** — "Faz 1-7",
"1.0.3/1.0.4 sürüm turu", "madde 1/6/10/11/12/13/16" ve "Sürüm A" 2 Eylül
2026'da oraya taşındı. O gün ölçüldü: dosyanın **%45'i** kapanmış işti ve
118 KB'a bu yüzden çıkmıştı — eşik düşük olduğu için değil, bu kural
uygulanmadığı için.

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

**Durum eki (27 Ağustos 2026):** Sürüm A merge edildi (`f9c3846`, paket
`1.0.0 (403)`) ve cihaz testinde. Dal Sürüm B için yeniden birikmeye
başladı; ayrıntı aşağıdaki "Yalnızca sohbette kalmış üç karar" bölümünde.

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

## Faz planı — kalan işlerin YAYIN sırası (29 Ağustos 2026)

Kullanıcı isteği: *"Tüm işleri fazlandırıp plan yapalım. Uygun gördüğün
maddeleri ona göre birleştirip sırayla yayına alalım."*

Bu bölüm aşağıdaki maddelerin YERİNE geçmez — onların **hangi paketle
çıkacağını** söyler. Madde 0 (FAZ B) omurga olmaya devam ediyor.

**Fazları belirleyen tek kısıt, bir tercih değil bir ölçüm:**

| Değişiklik türü | Bedeli | Ne zaman canlıda |
|---|---|---|
| İstemci (Flutter) | paket + Play incelemesi + cihaz turu | sürüm turu |
| Sunucu (migration / Edge Function) | yok | **anında**, merge'den bağımsız |
| Web (`src/`) | yok | `main`'e merge → Vercel |

Yani maddeleri "konu"ya göre değil **paketlenebilirliğe** göre grupladım.
Sonuç: kalan HER ŞEY **iki sürüm turuna** sığıyor — bildirim işinin yarısı
sunucu tarafında olduğu için sürüm beklemiyor.

### Kalan işlerin tamamı — tek bakışta (2 Eylül 2026'da güncellendi)

⚠ **Asıl bloker kod DEĞİL.** Play production'a başvurmak için kişisel
hesaplarda **12 tester'ın 14 gün kesintisiz kayıtlı** kalması gerekiyor;
sayaç kapalı testle işliyor ve o bitene kadar yayın açılamıyor. Aşağıdaki
her şey o pencerenin içinde ya da yanında duruyor.

| Kova | Ne | Durum |
|---|---|---|
| **Sayaç** | 12 tester × 14 gün | ⏳ işliyor, aksiyon yok · ⚠ karttaki **12**'nin gerçek adet mi şartın tavanı mı olduğu ÖLÇÜLMEDİ (2 Eylül, kullanıcı itirazı — aşağıda) · *Android developer verification* ✅ **BİTTİ** (Console'dan doğrulandı 31 Ağustos: `com.kelimeki.kelimeki` Registered, 3 anahtar, Identity dolu) |
| **Console (elle)** | — | ✅ **KAPANDI** (bu satır 31 Ağustos'a kadar bayat kaldı; ayrıntı aşağıda) |
| **1.0.4'e binecek kod** | Faz 6 istemci yarısı (rozet sıfırlama + sürüm damgası) · Faz 7 (iki çökme) · **+ #10 hata hız sınırı** (1 Eylül'de eklendi) | ✅ **1.0.4 (467) Play'e YÜKLENDİ, incelemede** (1 Eylül 2026) |
| **1.0.5'e binen kod** | Tahta zoom'u (+2 APK turu) · zoom tanıtım balonu · yazı ölçeği (sınıf 3+2) · mesaj kutusu etiketi · **cihaz turu düzeltmeleri (rozet kırpması · alt şerit · çevrimdışı şerit · zoom çerçevesi · filigranlar)** | ✅ **TUR KAPANDI** — `1.0.5 (501) — 4a0a29b` kapalı testte yayında (~15:03) ve üç işin cihaz doğrulaması da alındı (2 Eylül, kullanıcı). Ayrıntı: arşiv → "1.0.5 SÜRÜM TURU" |
| **Cihazda denenmemiş** | §3c'nin davete özgü dalları · GA4 DebugView | ⏳ bildirim→tahta DOĞRULANDI (sıcak+soğuk, 31 Ağustos); **1.0.5'in tamamı 2 Eylül'de onaylandı** (zoom turu, çevrimdışı şerit, filigranlar, balon, yazı ölçeği, mesaj etiketi) — kalan iki kalem bu ikisi |
| **Karar verilmiş, yapılmamış** | #8 Paylaşma (iPad popover) — cihaz istiyor | ⬜ · **#3 hatırlatma** ✅ KAPANDI (2 Eylül, zaten yürüyen alışkanlık) ve **#16 kart düzeni** ✅ YAPILDI — ikisi de arşivde |
| **Ertelendi** | #2 zorunlu güncelleme — In-App Update yerini aldı, eşik yalnızca acil fren | — |
| **İsteğe bağlı** | #5 k-lig grafiği · #9 admin filtre · #14 tembel liste | ⬜ hiçbiri yolu tıkamıyor · **#10 hata hız sınırı ✅** ve **#11 platform filtresi ✅ YAPILDI** (31 Ağustos 2026) |
| **Yapıldı** | #6 taranabilir `/nasil-oynanir/` sayfası | ✅ 31 Ağustos 2026 |
| **Play Store'a girdikten sonra** | **#17 Google ile giriş** — sunucu → web → mobil; migration BLOKER (OAuth bugün `handle_new_user`'da patlar) | ⏳ ERTELENDİ — acelesi yok, çalışan kimlik akışına şimdi dokunulmuyor (2 Eylül, kullanıcı). ⚠ Sayaçla İLİŞKİSİ YOK; o bağ aynı gün koptu, gerekçe #17'de |
| **iOS/APNs** | Apple Developer üyeliğine bloke; iş "APNs anahtarını yükle + Push capability" kadar | 🔒 |

⚠ **"Console (elle)" satırı 31 Ağustos'a kadar BAYAT kaldı** — dört maddesi
de aslında 25-26 Ağustos'ta bitmişti ve bu tablo onları hâlâ "kullanıcıda"
gösteriyordu. Kullanıcı akşam "formları şimdi güncelleyelim" dediğinde
yapılacak iş olmadığı anlaşıldı. Tek tek:

| Satırın dediği | Gerçek |
|---|---|
| Data deletion → "uygulama içi yol VAR" seçimi | **Böyle bir form alanı YOK.** Silme sorusunun cevabı `Evet → kelimeki.com/hesap-silme/` ve öyle kalıyor; Play'in uygulama içi şartı bir form alanı değil, uygulamanın KENDİSİNDE aranan politika şartı — 372'de karşılandı. `marketing/play-store/console-formlari.md` §3.8 bunu 26 Ağustos'ta "ENGEL KALKTI, beyanda değişen bir şey YOK" diye kapatmıştı |
| Kategori (Oyunlar → Kelime) | ✅ Games → Word, 25 Ağustos |
| İletişim e-postası | ✅ `destek@kelimeki.com` |
| Web sitesi | ✅ `https://kelimeki.com` |

**Ders:** bir işin kaydı İKİ yerde durursa (burada özet tablo, orada cevap
kâğıdı) biri kapanırken öteki kapanmıyor. Bu tablo bir İNDEKS — bir kova
kapandığında kaynağı `console-formlari.md`'dir, karar oradan okunur.

### Sonra / bloke

Açık olan TEK madde: **#8** (FAZ A1 Bölüm 6 — Paylaşma, iPad popover).
**#11** (hata panelinde platform filtresi) ✅ **KAPANDI** 31 Ağustos 2026
— bu satır 2 Eylül'e kadar onu hâlâ bekleyen iş gibi gösteriyordu, oysa
aynı gün yukarıdaki özet tablo ✅ diyordu (kaydın iki yerde durması).
**#12** (sürüm dağılımı kapsamı) ✅ **KAPANDI** 31 Ağustos 2026 — bkz.
arşivde "Faz 6".
**#15 — uygulama öne gelince bildirim panelini temizle** → ✅ **KOD TAMAM**
(31 Ağustos 2026), sıradaki mobil sürümle çıkar. Ayrıntı arşivde: "Faz 6".
**iOS/APNs** Apple Developer üyeliğine takılı; tasarım bilerek FCM üzerinden
yazıldığı için iOS günü gelince kalan iş "APNs anahtarını Firebase'e yükle +
Push capability ekle" — ikinci bir gönderici YAZILMAYACAK.

## Sürüm sıralaması, force update ve davetliler (27 Ağustos 2026)

Bunlar bir "madde" değil — biri bir SIRALAMA kuralı, biri ERTELENMİŞ bir
karar, biri de açık pencerenin İŞLETİM bilgisi. Hiçbiri koda yazılamadığı
için buraya yazıldı; oturum kapanınca kaybolmasınlar.

⚠ Başlıktaki üçüncü konu ("davetliler") 2 Eylül 2026'da bir HATIRLATMA
maddesiydi ve kapandı; yerinde yalnızca sayacın işletim bilgisi kaldı.
Başlık, atıflar kırılmasın diye değiştirilmedi.

### 2. Zorunlu güncelleme (force update) — ERTELENDİ

Kullanıcı isteği (26 Ağustos 2026): *"Ben normal yayına alıyorum. Riske
girmeyelim. Sorun çoğu insan güncellemez diye yorum geldi. Google tarafında
böyle opsiyon olsaydı onu açıp mecburi update yaptırırdım. Ama yoksa
etrafından dönmeye gerek yok."*

Ölçülen gerçek: **Play Console'da "zorunlu güncelleme" diye bir ayar YOK.**
Google'ın sunduğu tek yol In-App Updates API (`immediate` akış) ve
önceliği (`inAppUpdatePriority`) yalnızca **Publishing API** üzerinden
verilebiliyor — Console arayüzünde alanı bile yok. Yani "etrafından dönmek"
gerçekten ek bir altyapı işi.

İleride yapılacaksa **iki ön koşul ÖLÇÜLDÜ ve ikisi de bugün eksik:**

1. **Her derleme `1.0.0`.** `mobile/app/pubspec.yaml` sürümü sabit; CI
   yalnızca `versionCode`'u artırıyor. Bir istemci "daha yeni sürüm var mı"
   sorusunu kendi başına soramaz — önce sürüm adı derlemeye bağlanmalı.
2. **`UpdateRequiredScreen`'in mağaza butonu YOK.** Ekran var ama kullanıcıyı
   Play'e götüren bir eylem taşımıyor; zorunlu güncelleme onu kilitlenme
   ekranına çevirir.

**28 AĞUSTOS 2026 — KULLANICI YENİDEN İSTEDİ** (*"Firebase firestore'e
versiyon ekleyelim, cihaz her açıldığında kontrol etsin, eğer değilse markete
göndersin"*). İstenen davranış aynen bu maddedir; iki düzeltme gerekiyor:

⚠ **FIRESTORE'A GEREK YOK — kapı ZATEN VAR ve Supabase'de.** Ölçüldü:
`config/version_gate.dart` her açılışta (`bootstrap`) `app_config`
tablosundaki `mobile_min_supported_version`ı okuyor, `compareSemver` ile
karşılaştırıyor ve düşükse `UpdateRequiredScreen`e düşürüyor; ulaşılamazsa
FAIL-OPEN (offline YZ oyunu rehin alınmıyor). Yani "cihaz her açıldığında
kontrol etsin" kısmı ÇALIŞIYOR.

Firestore eklemek aynı gerçeğin İKİNCİ bir doğruluk kaynağını yaratırdı — bu
kod tabanının en sık tekrarlayan hata sınıfı tam olarak bu (bkz. `_red`in 13
dosyada ikiye bölünmesi, k-lig kademe tablosunun ÜÇ kopyası). Üstelik ikinci
kaynak, sürüm eşiğini değiştirmek için iki ayrı panele girmek demek olurdu.
**Eşik Supabase'de kalmalı.**

**GERÇEK EKSİK İKİ ŞEY (yukarıdaki ön koşulların aynısı):**
1. **`appVersion` sabit `1.0.0`.** Eşiği `1.0.1` yapmak BÜTÜN derlemeleri —
   en yenisi dahil — kilitler. Kapı bugün kullanılamaz durumda; önce sürüm
   adı derlemeye bağlanmalı (CI yalnızca `versionCode`u artırıyor).
2. **`UpdateRequiredScreen`de mağaza butonu YOK** (ölçüldü: dosyada tek bir
   `launchUrl`/`market://` yok). Bugünkü hâliyle ekran bir ÇIKMAZ — "güncelle"
   diyor ama güncellemenin yolunu göstermiyor. `url_launcher` zaten bağımlılık
   olarak var; `market://details?id=com.kelimeki.kelimeki` (Play yoksa
   `https://play.google.com/store/apps/details?id=…` yedeği) yeterli.

Sıra: bu ikisi → sonra eşiği kullanmaya başla. Sürüm B'nin kapsamında DEĞİL
(kapsam: deep link + push + sözlük); B çıktıktan sonraki ilk iş adayı.

⚠ **Risk (kullanıcı sordu: "Bu oyunun hiç açılmamasına sebep olabilir mi?"):**
EVET — yanlış kurulmuş bir zorunlu güncelleme, güncellemeyi alamayan
(cihazı eski, Play'i olmayan, ağı kısıtlı) kullanıcı için uygulamayı
tamamen açılmaz hâle getirir ve düzeltmesi ancak YENİ bir sürüm yayınlamakla
mümkündür. Bu yüzden erteleme doğru karar; yapılacaksa önce yukarıdaki iki
ön koşul, sonra kademeli (`flexible`) akış.

### Sayaç — nerede okunur, 14. gün ne zaman

⚠ Bu bir MADDE değil, açık pencerenin işletim bilgisi. *"Davetlilere
hatırlatma"* maddesi 2 Eylül 2026'da KAPANDI (kullanıcı: *"Hep ben
hatırlatıyorum zaten, burada madde olarak durmasına gerek yok"*) — arşivde:
`docs/decisions/roadmap-arsiv.md` → *"3. Davetlilere hatırlatma"*. Aşağısı
o maddeyle birlikte kaybolmasın diye burada kaldı.

**Sayacın yeri:** Dashboard → (aşağı kaydır) Production → `Apply for access
to production` kartı. Test menüsünde DEĞİL; track sayfasında da yok
(ölçüldü). **14. gün ~10 Eylül 2026** (sayaç 27/28 Ağustos'ta başladı;
Console'un günü nasıl saydığı ölçülmedi, ±1 gün kabul et ve tarihi kartın
kendi metninden takip et).

**Katılan/indiren sayısı:** Test → Closed testing → (track) → **Testers**
sekmesi — ⚠ oradaki sayı opt-in DEĞİL, **izin listesi**; indirme adedi için
**Statistics**.

**14 gün dolmadan yapılabilecek iki iş** (ikisi de hâlâ açık): karttaki
**`Preview questions`**'dan başvuru sorularını okuyup cevapları hazırlamak,
ve tester'lardan **yazılı geri bildirim** toplamak (başvuru "testi nasıl
yürüttün" diye soruyor).

#### ⚠ "12" gerçek sayı mı, tavan mı — AÇIK SORU (2 Eylül 2026)

Burada *"Sayı tam 12 — pay yok"* yazıyordu ve bu bir ÖLÇÜM gibi
okunuyordu. Kullanıcı 2 Eylül'de itiraz etti: *"12'den fazla katılım
olduğunu düşünüyorum, çünkü dashboard'da sadece limit olan 12 kişi opt-in
oldu diyormuş."* Kayıt bugün şunu söylüyor ve fazlasını söylemiyor:

| Kanıt | Hangi tezi destekliyor |
|---|---|
| Kart 26 Ağustos'ta **10** yazdı (eşiğin ALTINDA gerçek sayıyı gösterdi) | sayı GERÇEK |
| Kart 28 Ağustos'tan beri **12** yazıyor ve şart tam 12 | `min(gerçek, 12)` bir tavan da aynı görünürdü |

İkisi de aynı verilere uyuyor; **bu oturumdan ölçülemez** (Play Console
erişimi yok). Ayırt eden tek gözlem: sayının 12'nin ÜSTÜNE çıktığının bir
kez görülmesi — o an tez biter. Görülene kadar planlama **12'yi taban**
kabul etsin, ama *"biri düşerse sayaç sıfırlanır"* iddiası KESİN
yazılmasın. Kaynak kayıt: `marketing/play-store/console-formlari.md` §7.

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
**Play'e YÜKLENEN: 372** (26 Ağustos 2026 sabahı, kapalı test — Release name
`372 (1.0.0)`). Uygulama içi hesap silmeyi İÇEREN ilk paket bu.
Console'un paket ayrıntısından ölçüldü: `targetSdk` **36**, `minSdk` **24+**,
**4 izin**, ABI 3, ekran düzeni 4, gerekli özellik 2 — yani 349'un satırıyla
her sütunda aynı.

**Yüklenmeye hazır EN YENİ paket: 374** (koşu 374, sha `42a1f67`, `.aab`
26 Ağustos 05:42'de `mobile-latest`e yüklendi — 60.972.640 bayt). 372'den
tek farkı silme onayındaki uyarı cümlesinin kırmızı/kalın olması (#341) —
**kozmetik**, bu yüzden 372 için ayrı bir yükleme turu harcanmadı. Bir
sonraki mobil sürüm bu tabandan gider.

**370 neden atlandı:** aynı akşam Kullanım Koşulları §2'ye hesabı kendin
silme cümlesi eklendi (#338) ve hukuki metnin tarihi portu da zorunlu kıldı
(`legal_text_test.dart`) — yani 370 daha yüklenmeden bayatladı.
**Kalıcı ders: hukuki metne dokunmak her zaman bir paket turudur**, "tek
cümle" diye ucuz sayma. **İkinci ders — koşu numarası ardışık DEĞİL:** sayaç
PR koşularında da ilerliyor, 371'i #338'in kendi koşusu yedi. Bir sonraki
paketin numarasını önceden yazma, merge sonrası `main` koşusundan OKU.

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
  olarak yazıldı, içinde Play'in ürettiği parmak izi var (`2B:7D:26:11…`) —
  upload anahtarı (`B6:CD:FB:A9…`) DEĞİL. ⚠ Değer, App signing sayfasının
  anahtar TABLOSUNDAN değil, aynı sayfanın **"Digital Asset Links JSON"**
  panelinden okunur; ilk tur tablodan okunup yanlış parmak iziyle canlıya
  çıktı ve aynı gün düzeltildi. Ayrıntı ve ölçümler:
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
`Published`. Adım adım ne girildiği ve neden:
`marketing/play-store/console-formlari.md` § 6.5.
26 Ağustos'ta uygulama içi hesap silmeyi içeren **372** yüklendi.

**Kriter HENÜZ karşılanmadı:** Dashboard **`0 testers currently opted-in`**
diyor — listede olmak opt-in sayılmıyor, kişinin linke tıklayıp testi kabul
etmesi gerekiyor ve bugüne kadar kimseye link gönderilmemişti.

**26 Ağustos 09:03'te opt-in linkleri Console'da BELİRDİ** (Join on Android
+ Join on the web), liste 11 kişiyken. Bir gün önce yoklardı; kapısının ne
olduğu ölçülmedi (bkz. `console-formlari.md` §6.5 — o tabloda yalnızca
GÖRÜLEN kaydedildi, sebep uydurulmadı).

**26 Ağustos (öğleden sonra) — liste 11 → 54 KİŞİ.** Kullanıcı bildirdi;
Console'dan okunan sayı. §7'nin "15-20 kişi topla, biri çıkarsa sayaç
kırılır" tavsiyesinin çok üstünde, yani yedek payı bol.

⚠ **Listede olmak ≠ opt-in — ve aradaki fark ÖLÇÜLDÜ (26 Ağustos 2026):**
liste **54 kişi**, gerçekten opt-in olan **10 kişi**. Yani davetlilerin
%80'i linke tıklamamış. Sayaç için kişilerin linke tıklayıp testi KABUL
etmesi gerekiyor; `testers currently opted-in` bunu sayıyor.

**Eşik 12 ise 2 kişi eksik.** Buradan çıkan iki pratik sonuç:
- Yapılacak iş yeni adres toplamak DEĞİL (54 zaten fazlasıyla yeter),
  mevcut davetlilere *"linke tıklayıp 'Testçi ol' demen gerekiyor"* diye
  hatırlatmak.
- **Geliştiricinin kendi cihazından uygulamayı kaldırması artık RİSKLİ:**
  10 sayısı eşiğin altındayken tek bir düşüş oransal olarak büyük. Native
  `.apk` ile performans testi yapılacaksa opt-in OLMAYAN bir cihaz
  kullanılmalı. (Kaldırmanın opt-in'i gerçekten düşürüp düşürmediği
  ÖLÇÜLMEDİ — Play davranışı çıkarımla yazılmıyor.)

⚠ **Ve bugün ölçülen asıl darboğaz opt-in değil:** davetliler uygulamayı
kurup açsalar bile **tanıtım ekranında takılıyorlardı** (kaydırmayı
anlamıyorlar, atlama da yok → çıkmaz). 3 günde yalnızca 2 kayıt olmasının
sebebi buydu. Düzeltildi (Parça 143, "DEVAM ›" düğmesi) ama **uygulamaya
ancak yeni bir paket yüklenince ulaşır** — 54 kişi bekliyorsa bu yükleme
sıradaki en öncelikli iş.

### 0.B — 14 gün işlerken paralelde

Sırası önemli olan tek bağ: **#4, #2'den SONRA** (hesap silme kaskadı
çıkmadan test hesaplarını silmek aynı analizi iki kez yaptırır).

1. ✅ **BİTTİ (25 Ağustos 2026) — Madde 2, uygulama içinden hesap silme.**
   Play'in hesap açtıran uygulamalardan istediği İKİ şeyin ikisi de yerinde:
   web silme talep URL'i (`/hesap-silme/`, 0.A5) **ve** uygulama içi yol
   (Hesap Ayarları › Hesabımı Sil, web + port). Kaskad service-role bir Edge
   Function'da (`delete-my-account`) + `delete_account_cascade` RPC'sinde;
   `dryRun` bayrağıyla hiçbir şey silmeden sayan bir kuru çalıştırma modu
   var ve onay penceresi bunu gösteriyor. Karar/ölçüm/tuzaklar:
   `docs/decisions/account-deletion.md`.
   ✅ **Console'da yapılacak iş de YOK** (2 Eylül 2026'da düzeltildi).
   Burada *"App content › Data deletion formunda artık 'uygulama içi silme
   yolu VAR' seçilmeli"* yazıyordu; **böyle bir form alanı YOK.** Silme
   sorusunun cevabı `Evet → kelimeki.com/hesap-silme/` ve öyle kalıyor —
   Play'in uygulama içi şartı bir form alanı değil, **uygulamanın
   kendisinde** aranan bir politika şartı ve 372'de karşılandı.
   `console-formlari.md` §3.8 bunu 26 Ağustos'ta *"ENGEL KALKTI, beyanda
   değişen bir şey YOK"* diye kapatmıştı; bu satır o güne kadar geriye
   dönük olarak bayat kaldı.
3. ✅ **Madde 1 — deep link: KAPANDI** (30 Ağustos 2026, Faz 3'te ölçüldü;
   SAHADA 1.0.3 ile). Madde arşivde: `docs/decisions/roadmap-arsiv.md` →
   *"1. `kelimeki://` deep link kanalı"*. **Numara bilerek duruyor** —
   arşivdeki madde buraya (`0.B/3`) atıf yapıyor.
   ⚠ Bu satır 2 Eylül 2026'ya kadar bayat kaldı: hâlâ *"kayıt onayı maili
   uygulamayı değil web'i açıyor"* ve *"intent filter, Supabase redirect
   allow-list, e-posta şablonları, Flutter yönlendirme duruyor"* diyordu.
   Dördü de bitmişti — kayıt onayı 28 Ağustos'ta https'e geçti, intent
   filtreleri Parça 87/158'de zaten yazılmıştı, yönlendirmeyi Faz 3 ekledi.
   Açık kalan TEK parça **iOS Associated Domains**, o da bu maddenin değil
   aşağıdaki **iOS/APNs** bloğunun (Apple Developer üyeliği).
4. **0.C — App content formları** (aşağı).
5. ~~Test hesaplarının silinmesi~~ — **madde KALDIRILDI** (26 Ağustos 2026,
   kullanıcı kararı: *"gerekirse daha sonra hesabımı silden ben yaparım,
   önemli bir konu değil"*). Kalan test hesapları duruyor; büyüme
   metriklerini bir miktar kirletmeleri kabul edildi. ⚠ **`T2` ve
   `Ironman` hiçbir koşulda silinmez** — gerekçeleri
   `docs/decisions/account-deletion.md` → "ASLA SİLİNMEYECEK İKİ HESAP".

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
- ✅ Kategori **Games → Word** (25 Ağustos), iletişim e-postası
  `destek@kelimeki.com`, web sitesi `https://kelimeki.com` — üçü de
  Console'a girildi.
  ⚠ Bu satır 2 Eylül'e kadar ⬜ duruyordu ve BAYATTI; aynı üç madde
  yukarıdaki "Console (elle)" düzeltme tablosunda 31 Ağustos'ta zaten
  kapatılmıştı. Kaydın iki yerde durmasının bu dosyadaki dördüncü örneği.

**Görseller elle çizilmez:** reklam kareleri (`scripts/sponsored-post/`) ve
reel (`scripts/reel/`) zaten ÜRETİM bileşenlerini sunucuda render eden bir
desen kurdu — mağaza görselleri de aynı yoldan üretilmeli, yoksa vitrin ile
ürün sessizce ayrışır. **Tuzak:** o betiklerde Tailwind sınıfı çalışmaz
(`content` yalnızca `index.html` + `src/**` tarar), yalnızca inline `style`.


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

## 8. FAZ A1 Bölüm 6 (Paylaşma) — iPad popover ankrajı · **HATA BULUNDU, düzeltme yazıldı, yeniden test bekliyor**

**Kod işi YOK, bekleyen tek şey bir DOĞRULAMA.** Parça 86 (13 Ağustos
2026): `share_plus`ın iOS eklentisi iPad'de paylaş sayfasını popover
açıyor ve ankraj (`sharePositionOrigin`) istiyor; verilmezse paylaşmak
yerine `FlutterError` döndürüyor, iki `catch` onu yutuyor ve kullanıcıya
**hiçbir şey olmuyor**. Düzeltme yazıldı (ortak `shareOriginFrom`, `origin`
typedef'te zorunlu, iki katmanlı test) — kalan tek soru gerçek iPad'de
popover'ın çıkıp çıkmadığı. Üç yol da denenmeli: (a) oyun geçmişinde tahta
paylaşımı, (b) Setup'ta "Arkadaşınla paylaş", (c) Arkadaşlar'da davet linki.

### ✅ 2 Eylül 2026 — DOĞRU ORTAMDA KOŞULDU ve İKİ YOL KIRIK ÇIKTI

Appetize → **iPad Air / iOS 16.2** (yani native iOS kanalı, doğru cihaz
tipi). Sonuç:

| Yol | Ankraj nereden geliyordu | Sonuç |
|---|---|---|
| Oyun geçmişi → tahta paylaşımı | `_captureKey.currentContext` — tahtanın `RepaintBoundary`si, **küçük ve gerçek** kutu | ✅ popover açıldı |
| Setup → "Arkadaşınla paylaş" | `_SetupScreenState.context` — **ekranın TAMAMI** | ❌ "hiç tepki vermiyor" |
| Arkadaşlar → davet linki | `_FriendsModalState.context` — **ekranın TAMAMI** | ❌ buton `…` (meşgul) durumunda kilitli |

**KÖK SEBEP:** Parça 86 ankraj vermemeyi düzeltmişti; ankrajın KENDİSİNİN
geçerli olması gerektiğini kimse kontrol etmemişti. Ekranı kaplayan bir
dikdörtgen "boş değil" ve "kök view'ın içinde"dir — yani her iki eski
kontrolden de geçer — ama iPad'de popover görünmüyor ve
`SharePlus.share` **hiç dönmüyor**.

**Fırlatma DEĞİL, ASILMA — kanıt ekran görüntüsünde:** `_handleInvite`in
`finally`si `_inviteBusy`i sıfırlıyor; buton yine de `…`ta kaldı. Yani
future dönmedi. Setup'ta meşgul durumu olmadığı için aynı asılma "hiçbir
şey olmuyor" gibi görünüyor.

**TESTLER NEDEN YEŞİLDİ:** `share_recent_test`in ankraj iddiası yalnızca
"boş değil" + "ekranın içinde" diyordu; ekran boyutunda bir kutu ikisini de
sağlıyor. Üstelik test yalnızca ÇALIŞAN yolu (oyun geçmişi) kapsıyordu.

**DÜZELTME (aynı gün, dalda):**
- `shareOriginFrom` artık ekranı iki eksende birden (≥%95) kaplayan bir
  kutuyu ankraj SAYMIYOR, 1×1 merkez yedeğine düşüyor — popover ekranın
  ortasında görünür oluyor. ⚠ Eşik bilerek "büyük" değil "ekranın tamamı":
  ilk yazılan %50 ALAN eşiği ÇALIŞAN yolu kırardı (tahtanın ankrajı
  telefonda alanın ~%46'sı).
- İki kırık çağrı yeri artık kendi düğmesinin kutusuna bağlanıyor
  (`_shareLinkKey`, `_inviteButtonKey`) — oyun geçmişindeki
  `_captureKey.currentContext ?? context` deseninin aynısı.
- `shareOriginFrom` için doğrudan sözleşme testi + akış testine üçüncü
  iddia. Negatif eş: eşik kaldırılırsa test düşüyor.

⏳ **KALAN: aynı üç yolun Appetize/iPad'de YENİDEN denenmesi.** Üçünde de
paylaş kutusu açılmalı ve buton `…`ta kalmamalı.

⚠ **BU MADDEYİ NE KAPATMAZ — ölçüldü, 2 Eylül 2026.** Kullanıcı üç yolu da
GERÇEK bir iPad'de denedi ve *"sorun yok"* dedi, ama derleme
`kelimeki.com`/Pages idi, yani **web** derlemesi. Orada `share_plus`ın WEB
eklentisi (`navigator.share`) çalışıyor ve iOS platform kanalına HİÇ
uğranmıyor — ankrajı kontrol eden kod (`FPPSharePlusPlugin.m`) native iOS
eklentisinin içinde. **Cihazın iPad olması yetmiyor, DERLEMENİN native
olması gerekiyor.** Parça 86'nın 3 ay görünmeden kalmasının sebebi de tam
olarak buydu; aynı deneme tekrarlanmasın diye buraya yazıldı.
(Denemenin kanıtladığı ayrı bir şey var ve o gerçek: iPad Safari'de web
paylaşımı çalışıyor — `kelimeki.com`'a iPad'den girenlerin yüzeyi.)

**Kanıtlayan tek ortam:** Appetize → iOS simülatörü → **iPad cihaz tipi**.
CI zaten imzasız bir simülatör derlemesi üretip Appetize'a yüklüyor, yani
**Apple üyeliği GEREKMİYOR**. iPad tipinin panelde seçilebilir olup
olmadığı doğrulanmadı — `mobile/docs/test-ortamlari.md` bunu "panelden
bakılmalı" diye bırakmış; seçilemiyorsa madde gerçek bir native iPad
derlemesine (Apple üyeliği) kalır.

⚠ Bu bölüm önceden *"FAZ B turunda kapanır"* diyordu; yanlıştı. FAZ B
Android/Play turu ve 24-25 Ağustos Android turu temiz geldi — ROADMAP'in
kendisi *"Madde 8 bundan ETKİLENMEDİ"* diyor. Maddenin gerçek ön koşulu
Android turu değil, yukarıdaki iki ortamdan biri.

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

## 14. Uzun modal listeleri tembel inşa edilsin — **İZLEME, eşiğe bağlı**

27 Ağustos 2026, kullanıcı sordu: *"Arkadaşlar ara&ekle lazy yükleniyor
değil mi?"* İki ayrı "lazy" var ve cevap ikisinde farklı:

- **Veri yüklemesi: EVET, lazy.** 20'şerlik sayfalar
  (`kAllUsersPageSize` → `list_users_for_friend(offset, limit)`), gövdenin
  sonuna 80 px kala sonraki sayfa isteniyor; liste kaydırılamayacak kadar
  kısaysa `_autoLoadIfNotScrollable` elle tetikliyor. Bu değişmedi.
- **Widget inşası: HAYIR, artık değil.** Aynı gün kaydırma hatası
  düzeltilirken (Parça 146) iç içe `ListView` kaldırıldı ve yerine düz bir
  `Column` kondu — yani yüklenmiş TÜM satırlar inşa ediliyor. Tembelliğin
  kaybı o kararın bilinçli ama İKİNCİL bir bedeliydi; amaç iç içe
  kaydırılabiliri kaldırmaktı (Flutter zincirlemiyor, listenin alt 128 px'i
  erişilemiyordu).

**Bugün bedeli YOK ve sayı bu:** canlıda 47 profil var, yani en fazla ~46
satır. Ayrıca aynı modaldeki öteki iki sekme ("Arkadaşlarım", "İstekler")
BAŞTAN BERİ düz `Column`, ve web de tüm satırları DOM'a basıyor
(sanallaştırma yok) — yani parite de bozulmadı.

**Karar tetikleyicisi:** üye sayısı ~300'ü geçtiğinde, ya da liste gözle
görülür yavaşladığında. Muhtemelen ondan ÖNCE bir tasarım sorunu gelir
("kullanıcı 15 sayfa kaydırıyor") — o zaman doğru cevap sanallaştırma değil
arama/filtre olabilir; ikisini birlikte değerlendir.

⚠ **Çözüm iç içe `ListView`'a DÖNMEK DEĞİL** — düzeltilen hata aynen geri
gelir (bkz. `mobile/CLAUDE.md` → "`KModal`'ın gövdesi ZATEN
kaydırılabilir"). Doğru yol `KModal`'ın gövdesini `SingleChildScrollView`
yerine `CustomScrollView` + `SliverList` yapmak: kaydırılabilir yine TEK
kalır (zincirleme sorunu doğmaz) ama satırlar tembel inşa edilir.
`KModal`'a `bodyController`'ın yanına bir `slivers` yolu eklenir.

**Etki alanı geniş:** `KModal`'ı 15 modal kullanıyor, yani bu değişiklik
hepsine dokunur — küçük bir iş değil, kendi test turunu ister. Aynı
gerekçeyle 27 Ağustos'ta Sürüm A'ya alınmadı.

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

---

## 17. Google ile giriş/kayıt — **ERTELENDİ** (2 Eylül 2026) · Play Store'a girdikten SONRA

Kullanıcı sordu: *"Google ve Apple signup/signin özelliği eklemek zor mu?
Belki şimdilik sadece Google ile başlanabilir"* ve *"test sürecinde yapmak
mantıklı mı?"*. Cevap: Google tek başına makul, **ama sıraya girdi.**

### Neden ertelendi — kullanıcı kararı, 2 Eylül 2026

> *"Google signin olayını erteledik çünkü bu dönemde bu işi yapmanın
> acelesi yok. Çalışan düzene çomak sokmak olur boşuna. O nedenle önce
> Play Store'a girelim, sonra yaparız dedik. O kadar."*

Gerekçe bu: **öncelik sıralaması.** Yeni bir giriş yolu bugün hiçbir şeyi
açmıyor — kimse "Google ile giremiyorum" diye şikayet etmedi — ve çalışan
bir kimlik akışına dokunmanın karşılığı yok. Play Store'a girildikten
sonra yapılır.

⚠ **BU MADDE SAYAÇLA İLİŞKİLİ DEĞİL — 2 Eylül 2026'da AYRILDI.** Burada
*"kapalı test sayacı bitmeden BAŞLAMA"* diye dört maddelik bir risk
analizi vardı: özü, bozuk bir girişin tester'ı kaybettirip 12/14 sayacını
sıfırlayabileceğiydi. Kullanıcı sordu (*"17 Google sign-in işi değil mi?
Test süreciyle ne alakası var?"*) ve zincir açılınca ÜÇ yerden koptu:

- **Uygulamayı silmek testerlıktan çıkmak değil** — deponun kendi tester
  mesajı bunu söylüyor (*"uygulamayı silsen bile testerlıktan çıkma"*) ve
  kaldırmanın opt-in'i düşürüp düşürmediği zaten ÖLÇÜLMEMİŞ.
- **Mevcut tester'lar çoktan kayıtlı.** Google girişi EK bir yol; e-posta/
  şifreyle girenler yeni bir butondan etkilenmez. "Giriş yapamıyorum"
  asıl olarak YENİ kayıt olanı vurur.
- **Sayacın "tam 12" olduğu da artık kesin değil** (yukarıdaki açık soru).

**Ders:** bir erteleme kararının gerekçesi, kararın KENDİSİNDEN daha
karmaşık yazılmışsa muhtemelen sonradan uydurulmuştur. Gerçek sebep bir
öncelik tercihiydi; yerine bir risk zinciri yazılınca hem yanlış hem de
sahte bir takvim bağı ("~10 Eylül") doğdu.

### İşin KENDİ riski — takvimden bağımsız, ne zaman yapılırsa yapılsın

Yukarıdaki zincir düştü ama şu ikisi düşmedi; ikisi de "ne zaman"la değil
"nasıl"la ilgili:

1. **`handle_new_user` web ile portun ORTAK trigger'ı.** "Yalnızca web'de
   yaparım" diye bir kaçış YOK — hatalı bir migration mobil tarafta da yeni
   kayıt açılmasını bozar. Migration adımı (aşağıda "0.") bu yüzden BLOKER.
2. **Hesap birleştirme ölçülmedi** — aynı e-postayla önce şifreyle kayıt
   olup sonra Google ile girmek. Bu, MEVCUT bir kullanıcıyı da vurabilir
   (bkz. aşağıda "Ölçülmesi gereken, varsayılmayacak iki şey").

### Sıra: sunucu → web → mobil

Web'de oturmuş bir profil-tamamlama akışını porta taşımak, tersinden yapmaktan
belirgin biçimde ucuz.

**0. Migration — BLOKER, ilk iş.** Bugün Google girişi açılsa ilk denemede
patlar (ölçülmedi ama kaynak kesin): OAuth'ta `sharedxp_pending_profile`
metadata'sı HİÇ gelmez → `handle_new_user` ad/soyadı `coalesce(..., '')` ile
boşa düşürür → `profiles_first_name_not_blank` (`20260717164244`) ihlal edilir
→ trigger patlar, `auth.users` insert'i geri alınır, kullanıcı *"Database error
saving new user"* görür. Yapılacaklar:
- Ad/soyadı Google'ın `raw_user_meta_data`'sından türet (`full_name` /
  `given_name` / `family_name`), yoksa kısıtı sağlayan geçici bir değer.
- `display_name` **not null + `profiles_display_name_tr_lower_key` (Türkçe
  duyarsız UNIQUE)** — `split_part(email,'@',1)` fallback'i iki Gmail
  kullanıcısında çakışır; benzersiz geçici bir ad üret.
- **"Profili tamamla" bayrağı** (yeni kolon); `agreed_to_terms` OAuth'ta false
  doğar, modalda yazılır. `signup_channel`/`signup_utm_source` damgalanmaya
  devam etmeli.
- ⚠ **Aynı migration'da `sharedxp_pending_profile` borcunu da kapat** — trigger
  İKİ anahtarı birden okusun (`docs/decisions/product-backlog.md` → "Miras
  isimler"). Bu iş zaten trigger'a dokunuyor; ayrı PR bedeli ikiye katlar.
- Proje kuralı: uygula → `execute_sql` ile DOĞRULA → `list_migrations` ile
  dosya adını eşleştir.

**1. Konsol (kod değil, panelden).**
- Google Cloud: OAuth consent screen — yalnızca `email` + `profile` kapsamı
  (Google doğrulaması gerekmez); gizlilik + kullanım koşulları URL'leri zaten
  yayında (`/gizlilik/`, `/kullanim-kosullari/`).
- Web client ID + secret → Supabase → Authentication → Providers → Google.
- Supabase → URL Configuration → Redirect URLs (`kelimeki.com`, preview
  adresleri, `harfik.vercel.app` durduğu sürece o da — bkz. backlog'daki
  Vercel rename planı, ikisi çakışıyor).
- Android: **upload anahtarının VE Play App Signing anahtarının SHA-1'i**
  Firebase'e girilecek (Firebase Android OAuth istemcisini kendisi üretir).
  SHA-256 zaten `assetlinks.json` için çıkarılmıştı — `console-formlari.md` §6.6,
  aynı sayfa.

**2. Web (`src/`).** `signInWithGoogle()` (`api.ts`) · `AuthModal`'a buton ·
işin AĞIRLIĞI olan **profil tamamlama modalı** (takma isim — mevcut
`useNicknameAvailability`/`check_nickname_available` yeniden kullanılır —,
ad/soyad, şartlar, isteğe bağlı pazarlama izni) · OAuth-only hesapta şifre
yollarının gizlenmesi (`ResetPasswordModal`, `AccountSettingsModal`) ·
`useAuth`'un "profil eksik" durumunu yayması.

**3. Mobil (`mobile/app`).** `google_sign_in` + `signInWithIdToken` (web'in
redirect akışı DEĞİL, native akış; `supabase_flutter ^2.10.2` destekliyor) ·
aynı modalın portu · sürüm artışı (`pubspec.yaml` + `env.dart`, ikisi birlikte) ·
yeni `.aab` + Play incelemesi.

**4. Beyan ve doküman.** `TermsModal`/`PrivacyModal` + statik `/gizlilik/`
(Google'a giden veri) · Play **Data safety** formunun yeniden okunması ·
`TESTING.md` + `mobile/TESTING.md` — **gerçek bir Google hesabı gerektirdiği
için otomatik test EDİLEMEZ**, elle koşulan listeye girer · `CLAUDE.md`/`README`.

### Ölçülmesi gereken, varsayılmayacak iki şey

- **Hesap birleştirme:** aynı e-postayla önce şifreyle kayıt olup sonra Google
  ile girmek. Supabase'in kimlik birleştirme davranışı ayara bağlı; iki hesap
  mı bir hesap mı olduğu kullanıcının puanını ve k-lig geçmişini etkiler.
- **Hoş geldiniz e-postası:** `on_auth_user_welcome` `after insert or update of
  email_confirmed_at` — OAuth kullanıcısı DOĞRULANMIŞ doğduğundan bugüne kadar
  "ulaşılamaz" sayılan INSERT dalı devreye girer. Beklenen davranış doğru (mail
  gider), ama migration'ın yorumundaki "bugün ulaşılamaz" cümlesi o PR'da
  güncellenmeli.

### Apple neden bu maddede YOK

Apple Developer üyeliği alınmadı ve iOS yayında değil. Ayrıca **App Store 4.8:**
iOS uygulaması üçüncü taraf girişi (Google) sunuyorsa eşdeğer bir gizlilik
odaklı seçenek de sunmak zorunda — yani **iOS'a Google girişi koyulan gün Apple
girişi de zorunlu olur**; ikisi orada birlikte gider. Web ve Android'de böyle bir
kural YOK. Günü gelince iki tuzak: kullanıcı e-postasını gizleyebilir
(`@privaterelay.appleid.com`) ve **ad/soyad yalnızca ilk yetkilendirmede bir kez**
döner — o an kaydedilmezse bir daha alınamaz.

