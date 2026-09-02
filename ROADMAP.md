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
"1.0.3/1.0.4 sürüm turu", "madde 1/6/10/11/12" ve "Sürüm A" 2 Eylül
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
| **Sayaç** | 12 tester × 14 gün | ⏳ işliyor, aksiyon yok · *Android developer verification* ✅ **BİTTİ** (Console'dan doğrulandı 31 Ağustos: `com.kelimeki.kelimeki` Registered, 3 anahtar, Identity dolu) |
| **Console (elle)** | — | ✅ **KAPANDI** (bu satır 31 Ağustos'a kadar bayat kaldı; ayrıntı aşağıda) |
| **1.0.4'e binecek kod** | Faz 6 istemci yarısı (rozet sıfırlama + sürüm damgası) · Faz 7 (iki çökme) · **+ #10 hata hız sınırı** (1 Eylül'de eklendi) | ✅ **1.0.4 (467) Play'e YÜKLENDİ, incelemede** (1 Eylül 2026) |
| **1.0.5'e binen kod** | Tahta zoom'u (+2 APK turu) · zoom tanıtım balonu · yazı ölçeği (sınıf 3+2) · mesaj kutusu etiketi · **cihaz turu düzeltmeleri (rozet kırpması · alt şerit · çevrimdışı şerit · zoom çerçevesi · filigranlar)** | ✅ **TUR KAPANDI** — `1.0.5 (501) — 4a0a29b` kapalı testte yayında (~15:03) ve üç işin cihaz doğrulaması da alındı (2 Eylül, kullanıcı). Ayrıntı: arşiv → "1.0.5 SÜRÜM TURU" |
| **Cihazda denenmemiş** | §3c'nin davete özgü dalları · GA4 DebugView | ⏳ bildirim→tahta DOĞRULANDI (sıcak+soğuk, 31 Ağustos); **1.0.5'in tamamı 2 Eylül'de onaylandı** (zoom turu, çevrimdışı şerit, filigranlar, balon, yazı ölçeği, mesaj etiketi) — kalan iki kalem bu ikisi |
| **Karar verilmiş, yapılmamış** | #3 davetlilere hatırlatma (gönderilebilir) · #8 Paylaşma (iPad popover) | ⬜ · **#16 devam eden oyun kartlarının düzen ayrışması ✅ YAPILDI** (2 Eylül 2026, arşivde) |
| **Ertelendi** | #2 zorunlu güncelleme — In-App Update yerini aldı, eşik yalnızca acil fren | — |
| **İsteğe bağlı** | #5 k-lig grafiği · #9 admin filtre · #14 tembel liste | ⬜ hiçbiri yolu tıkamıyor · **#10 hata hız sınırı ✅** ve **#11 platform filtresi ✅ YAPILDI** (31 Ağustos 2026) |
| **Yapıldı** | #6 taranabilir `/nasil-oynanir/` sayfası | ✅ 31 Ağustos 2026 |
| **Sayaç bitince (~10 Eylül)** | **#17 Google ile giriş** — sunucu → web → mobil; migration BLOKER (OAuth bugün `handle_new_user`'da patlar) | ⏳ bilerek bekletiliyor, gerekçe #17'de |
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

**#8** (FAZ A1 Bölüm 6 — Paylaşma, iPad popover), **#11** (hata panelinde
platform filtresi). **#12** (sürüm dağılımı kapsamı) ✅ **KAPANDI**
31 Ağustos 2026 — bkz. arşivde "Faz 6".
**#15 — uygulama öne gelince bildirim panelini temizle** → ✅ **KOD TAMAM**
(31 Ağustos 2026), sıradaki mobil sürümle çıkar. Ayrıntı arşivde: "Faz 6".
**iOS/APNs** Apple Developer üyeliğine takılı; tasarım bilerek FCM üzerinden
yazıldığı için iOS günü gelince kalan iş "APNs anahtarını Firebase'e yükle +
Push capability ekle" — ikinci bir gönderici YAZILMAYACAK.

### #13'ün ölçülen durumu (29 Ağustos 2026) — yarısı BİTTİ

Aşağıdaki #13 sıfırdan bir iş gibi okunuyor; artık değil. Canlıdan ve
koddan ölçülen hâl:

| Parça | Durum |
|---|---|
| Altyapı (`push_tokens`, `register_push_token`, hesap silmede temizlik) | ✅ |
| `POST_NOTIFICATIONS` izni · `kelimeki_oyun` kanalı (IMPORTANCE_HIGH) | ✅ |
| `push_notifications_enabled` tercihi (e-postadan bağımsız) | ✅ |
| **Teslim uyarısı push'u** | ✅ canlıda (`notify-deadline-warnings` v12) |
| Oyun daveti · arkadaş daveti push kanalı | ✅ canlıda (30 Ağustos) |
| Bildirime dokununca yönlendirme | ✅ **1.0.3'le SAHADA** (31 Ağustos) — cihaz testi §3c bekliyor |
| Firebase Analytics olayları | ✅ **1.0.3'le SAHADA** (31 Ağustos) — GA4 DebugView bekliyor |
| "Sıra sende" olayı | ✅ canlıda (30 Ağustos) |
| Play Data safety formu | ✅ (29 Ağustos) |

---

## Sürüm sıralaması, force update ve davetliler (27 Ağustos 2026)

Bu üçü bir "madde" değil — biri bir SIRALAMA kuralı, biri ERTELENMİŞ bir
karar, biri bir HATIRLATMA. Hiçbiri koda yazılamadığı için buraya yazıldı;
oturum kapanınca kaybolmasınlar.

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

### 3. Davetlilere hatırlatma — ARTIK GÖNDERİLEBİLİR (Sürüm A çıktıktan sonra)

Kapalı test listesi 54 kişiye çıktı ama büyük bölümü uygulamayı hâlâ
**yüklememiş**. Bu bir hata değil bir pazarlama işi, ama sıralaması vardı:
Sürüm A'nın dört düzeltmesi (taş yakalama, ✕ ıskalama, arkadaş listesinin
sonuna inememe, bayat rozet) tam da **ilk deneyimi** vuruyordu — hatırlatma
o yüzden A'dan SONRAYA bırakılmıştı.

**ENGEL KALKTI — `1.0.0 (407)` KAPALI TESTTE YAYINDA (28 Ağustos 2026,
kullanıcı Play Console'dan doğruladı: yayın durumu "Update live").** A
(`403`) ve A2 (`405` → `407`) çıktı, cihaz testi onaylandı, paket kanalda.
**Hatırlatma artık gönderilebilir — bekleyen tek adım bu.**

⚠ **Play Console'da sürümün ADI ile version code AYNI şey değil** (28
Ağustos 2026, kullanıcı haklı olarak sordu: *"Son release 1.0.0 (405)
gözüküyor"*). "Latest releases and bundles" satırı `1.0.0 (405)` yazıyordu
ama yanındaki version code sütunu `407`di. Sürüm adı taslak açılırken bir
kez doldurulan **serbest metin bir etikettir ve paket değişince kendini
güncellemez**; kimliği belirleyen tek şey `.aab`'nin içinden gelen version
code. Aynı ekranın "Latest app bundles" tablosu kanıt: **407 → Active**,
401/378/372/349 → Inactive ve **405 listede hiç yok** (o paket Play'e hiç
yüklenmedi, yalnızca cihazda `.apk` olarak denendi). Zincir: koşu **#407**
→ sha **`0651e5e`** → `mobile-latest` `.aab` (27 Ağu 21:07) → Play paketi
(21:42). **Şüphe halinde ada değil, cihazdaki teşhis satırına bak:
`Derleme 0651e5e`.**

**14 GÜNLÜK SAYAÇ BAŞLADI — 28 Ağustos 2026, 1. gün.** Yeri:
**Dashboard → (aşağı kaydır) Production → `Apply for access to production`
kartı** (Test menüsünde DEĞİL; track sayfasında da yok — ölçüldü). Kartın
yazdığı: *"12 testers have currently been opted in for 1 day"*, ilk iki
şart ✅. **14. gün ~10 Eylül 2026.**

⚠ **Sayı tam 12 — pay yok.** İzin listesi 56 kişi ama opt-in olan 12; biri
çıkarsa sayaç SIFIRLANIR ve 13 gün kaybedilir. Hatırlatmanın hedefi artık
"12'ye ulaşmak" değil **12'nin üstünde tampon** (15-20). Ayrıntı ve tuzaklar:
`marketing/play-store/console-formlari.md` §7.

14 gün beklerken yapılacak iki iş: karttaki **`Preview questions`**'dan
başvuru sorularını okuyup cevapları hazırlamak, ve tester'lardan **yazılı
geri bildirim** toplamak (başvuru "testi nasıl yürüttün" diye soruyor).

Katılan/indiren sayısı Play Console'da: **Test → Closed testing → (track) →
Testers sekmesi** (⚠ oradaki sayı opt-in DEĞİL, izin listesi), ve indirme
adedi için **Statistics**. (Kullanıcı bunu iki kez sordu — yeri burada
yazılı.)
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
   ⚠ **Console'da yapılacak tek iş kaldı:** App content › **Data deletion**
   formunda artık "uygulama içi silme yolu VAR" seçilmeli (form bugüne kadar
   yalnızca web URL'ini taşıyordu).
3. **Madde 1 — deep link.** Play blokeri değil ama
   kayıt onayı maili uygulamayı değil web'i açıyor; inceleme "kırık akış"
   diye dönebilir. iOS yarısı Apple hesabı istediğinden bekler.
   **`assetlinks.json` bu maddeden AYRILDI ve bitti** (25 Ağustos 2026,
   §6.6) — parmak izi Console'dan ancak `.aab` yüklendikten sonra
   okunabildiğinden dosya o anda yazıldı; maddenin geri kalanı (intent
   filter, Supabase redirect allow-list, e-posta şablonları, Flutter
   yönlendirme) duruyor.
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

## 13. Push bildirimleri + Firebase Analytics — **YENİ, 26 Ağustos 2026**

Dört olay: **teslim uyarısı** · oyun daveti · arkadaş daveti · hamle sırası.

Kullanıcı isteği: *"App'de notification özelliği açanlara hamle sırası, oyun
daveti, arkadaş daveti geldiğinde uyarıları çıkmalı."*

**Ölçülen başlangıç noktası — hiç push altyapısı YOK:** `pubspec.yaml`'da
Firebase/messaging paketi yok, `AndroidManifest`'te `POST_NOTIFICATIONS`
izni yok, token tutan bir tablo yok. Yani bu sıfırdan bir altyapı işi.

**Ama olayların İKİSİ zaten sunucuda var** (e-posta kanalı olarak):

| Olay | Sunucu tarafı | Push için ek iş |
|---|---|---|
| **Teslim uyarısı** ("24 saat içinde hamle yapmazsan…") | `notify-deadline-warnings` — tetikleyici, metin ve `deadline_warning_sent_at` tekrar koruması **HAZIR** | **en ucuz**: aynı noktada ikinci kanal |
| Oyun daveti | `notify-game-invite` | ucuz — kanal eklemek |
| Arkadaş daveti | `notify-friend-request` | ucuz — kanal eklemek |
| **Hamle sırası** ("sıra sende") | **YOK** | **en pahalı** — anlık olay sıfırdan |

**SIRALAMA (26 Ağustos 2026'da DÜZELTİLDİ):** teslim uyarısı → davetler →
sıra sende. İlk taslakta "önce sıra sende" yazıyordu; yanlıştı. Ölçünce
çıktı ki teslim uyarısı hem **en ucuz** (üç parçası da hazır) hem **en
değerli**: ötekiler bir fırsatı kaçırtır, bu bir KAYBI önler — oyun teslim
sayılıyor ve k-lig puanından 2 düşüyor. E-postayı görmeyen için push tam
da bunun içindir.

Mevcut e-posta metni kullanıcının istediği cümlenin ta kendisi ve İKİ
durumu birden kapsıyor: Canlı oyunlarda 48 saatlik `turn_deadline`, YZ
oyunlarında 7 günlük terk penceresi — ikisinde de son 24 saate girince.

✅ **Bu satır KAPANDI (29 Ağustos 2026, canlıdan okundu):**
`notify-deadline-warnings` **v11** yayında — *"takdirde"* yazımı doğru,
push kanalı (`sendDeadlinePush`) İÇİNDE ve `verify_jwt: false`. Yani teslim
uyarısı bugün hem e-posta hem push gönderiyor; bu satırda yapılacak iş yok.
Buraya 26 Ağustos'tan kalma bir *"bekleyen deploy"* uyarısı yazılıydı ve
**bayattı** — kaldırıldı. Faz 2'de öteki üç fonksiyona dokunulurken
`verify_jwt` tuzağı yine geçerli: `deploy_edge_function`'a parametre
geçilmezse araç `true` varsayar ve kapıyı sessizce kapatır, o yüzden önce
`list_edge_functions` ile mevcut değeri oku, AYNI değeri açıkça geçir
(kök `CLAUDE.md` → "Edge Function deploy").

Yani "sıra sende" bildiriminin bir sunucu olayı hiç yok; hamle
gönderiminde tetiklenen yeni bir kanca gerekiyor.

### iOS: bugün çıkamaz, ama tasarım onu BEKLİYOR olacak

APNs anahtarı **Apple Developer üyeliği** istiyor; üyelik süreci Apple'dan
dönüş beklediği için ilerlemiyor (TestFlight'ı bloklayan aynı şey — madde 8
ön koşulu). Kullanıcı kararı (26 Ağustos 2026): *"orada da bu fonksiyon
ileride olacakmış gibi plan yapmak lazım."*

**Bunun somut karşılığı — iOS sonradan EKLENMELİ, YENİDEN YAZILMAMALI:**

- **Tek gönderici: FCM.** FCM iOS'a da teslim ediyor (arka planda APNs'i
  kendisi kullanıyor). Sunucu tarafı FCM üzerinden yazılırsa iOS günü
  gelince yapılacak iş "ikinci bir gönderici yazmak" DEĞİL, yalnızca
  **APNs anahtarını Firebase'e yüklemek + uygulamaya Push capability
  eklemek**. APNs'e doğrudan konuşan bir yol seçilirse bu kazanç kaybolur.
- **İstemci: `firebase_messaging`** iki platformu birden karşılıyor; ayrı
  bir iOS yolu yazma.
- **`push_tokens.platform` baştan var** (`android`/`ios`) — sonradan kolon
  eklemek, var olan satırların platformunu tahmin etmek demek olurdu.
  `util/platform.dart` zaten bu değer kümesini üretiyor, onu kullan.
- **İzin akışı ortak yazılsın:** iOS da açık izin istiyor (üstelik
  "provisional" seçeneği var). İzni isteyen kod platforma DALLANMAMALI,
  eklentinin ortak API'sini kullanmalı.
- **Bildirime dokununca gitme** (deep link, madde 1) zaten platform
  bağımsız — orada iOS'a özgü tek iş Associated Domains.

Yani madde iOS'u BEKLEMEZ: Android'le çıkar, iOS bir anahtar yüklemesiyle
açılır.

### Yapılacaklar

1. **Altyapı:** FCM (Android), cihaz token tablosu (`push_tokens`:
   `user_id`, `token`, `platform`, `updated_at`; aynı kullanıcı birden
   çok cihaz), token yenilenmesi ve **çıkışta/hesap silmede temizlenmesi**
   (`delete_account_cascade`'e satır!).
2. **İzin:** Android 13+ `POST_NOTIFICATIONS` runtime izni. İzin İSTEME
   ANI önemli — açılışta sormak reddi artırır; ilk Canlı oyun ya da ilk
   davet anında sor.
3. **Tercih — KARAR VERİLDİ (26 Ağustos 2026): e-posta KALIR, iki BAĞIMSIZ
   anahtar, otomatik bastırma YOK.** Kullanıcı önce *"app kullananlara
   email gitmesine gerek yok"* dedi, ama kontrolün zorluğu sorulunca
   *"zor ise kalabilir, isteyen ayarlardan kapatabilir"* diye bıraktı.
   Ölçülen durum: kontrol teknik olarak KOLAY (push tablosu zaten
   gerekiyor, e-posta fonksiyonlarına tek bir `exists` kontrolü yeterdi) —
   ama **yanlış olurdu**:
   - Token bayatlarsa (uygulama silinmiş, bildirim sistem ayarından
     kapatılmış, token yenilenmemiş) push GİTMEZ; e-postayı da bastırmışsak
     kullanıcı **hiçbir şey** almaz. Bu, iki bildirim almaktan çok daha kötü
     ve **SESSİZ** bir arıza: kimse şikayet etmez, yalnızca oyunlar ölür.
   - Uygulama telefonda olsa bile bazı kullanıcılar bildirimi mailde görmeyi
     tercih ediyor (masaüstünde çalışırken).

   Bu yüzden: `profiles.email_notifications_enabled` (VAR) + yeni
   `push_notifications_enabled`, ikisi de AÇIK gelir, Hesap Ayarları'nda
   ayrı ayrı görünür. İleride "çok mail geliyor" diye GERÇEK bir şikayet
   gelirse tek güvenli bastırma biçimi şudur: e-postayı yalnızca push'un
   GERÇEKTEN teslim edildiği olayda bastırmak (FCM `UNREGISTERED` dönerse
   token'ı silip e-postaya düşmek). Bu ek iştir ve şikayet gelmeden
   yapılmaz.
4. **"Sıra sende" olayı:** hamle gönderiminde tetiklenen kanca.
   ⚠ İki tuzak: (a) hamleyi YAPANA gönderme; (b) hızlı gidip gelen bir
   oyunda her hamlede bildirim spam olur — e-posta tarafındaki
   `deadline_warning_sent_at` deseninin karşılığı bir bastırma gerekir.
5. **Tıklayınca doğru yere git:** bildirime dokunmak ilgili oyunu/daveti
   AÇMALI. Deep link altyapısı madde 1'le kesişiyor — ikisi birlikte
   planlanmalı.
6. **Play Data safety formu:** FCM token bir cihaz tanımlayıcısıdır;
   `marketing/play-store/console-formlari.md`'deki eşleme güncellenmeli.
   Bu form yanlışsa mağaza reddi gelir.

### Firebase Analytics — aynı pakette (26 Ağustos 2026, kullanıcı kararı)

Kullanıcı: *"Bence hepsini bir kerede halletmek iyi olur."* FCM için
Firebase zaten kurulacağından Analytics'i o anda açmak neredeyse bedava.

**Neden gerekli — ÖLÇÜLDÜ:** bugünkü şema sonuçları görüyor, davranışı
görmüyor. `guest_visits`/`device_visits` → `profiles` → `game_starts` →
`game_finishes` zinciri "ne oldu"yu veriyor; ekran görüntülenmesi, sekme
geçişi, akış içi terk noktası, oturum uzunluğu YOK. **Bedeli bu proje
zaten ödedi:** insanlar tanıtım ekranında takılıyordu (3 günde 2 kayıt) ve
sebebi veriden GÖRÜLMEDİ — kullanıcı insanlarla konuşunca öğrenildi.
`game_starts` bunu gösteremezdi, çünkü o insanlar oyuna hiç ulaşamamıştı.

İlk olay kümesi (değeri en yüksek altı): `intro_slide_viewed`,
`signup_started`, `signup_completed`, `live_game_form_opened`,
`live_game_created`, `invite_link_shared`.

⚠ **Admin panelinden metrik KALDIRMA — kanıta bağlı.** Kullanıcı
*"admin'de olup FB tarafında daha iyisi olan dataları admin'den
kaldırabiliriz bile"* dedi. Doğru, ama **kaldırmalar paralel koşu
sonrasına**: GA4 şunların yerini ALAMAZ — (a) kaynak hunisi web'de
başlıyor (`utm_source` karşılama katmanında; uygulamadaki GA4 o yarıyı
görmez), (b) retention/aktivasyon hesap+oyun kayıtlarından hesaplanıyor,
GA4'ünki cihaz kapsamlı ve web+app'i aynı kişide birleştirmez, (c) join
edilebilirlik ("k-lig'de yükselenler daha çok davet mi gönderiyor?" senin
şemanda tek sorgu), (d) GA4 örnekleme yapar ve olayı 2-14 ay tutar,
`games` sonsuza kadar sende. Kaldırılmaya net aday: cihaz/OS kırılımı
(`device_visits`). Gerisi ancak GA4'ün daha iyi verdiği ÖLÇÜLDÜKTEN sonra.
Gerekçe bu projeye özgü: ölçümü, yerine geçecek şeye güvenmeden kaldırmak
"sessiz kayıp" sınıfından bir hatadır ve fark edilmesi en zor olanıdır.

### Sıra

1. **Teslim uyarısı push'u** (en ucuz + en değerli, yukarıdaki tabloya bak)
2. Oyun daveti · arkadaş daveti kanalları
3. **"Sıra sende"** — sunucu olayı sıfırdan
4. Analytics olayları

Not: oyun daveti ve arkadaş daveti için e-posta ZATEN gidiyor, yani o
ikisinin push katkısı en düşük olan.


---

## 17. Google ile giriş/kayıt — **YENİ, 2 Eylül 2026** · ⏳ sayaç bitene kadar BEKLİYOR

Kullanıcı sordu: *"Google ve Apple signup/signin özelliği eklemek zor mu?
Belki şimdilik sadece Google ile başlanabilir"* ve *"test sürecinde yapmak
mantıklı mı?"*. Cevap: Google tek başına makul; **ama kapalı test sayacı
bitmeden BAŞLAMA.**

### Neden şimdi değil (~10 Eylül'den sonra)

**Sürüm çıkarmak sorun DEĞİL, bu ölçüldü:** sayaç 27/28 Ağustos'ta başladı
ve o gün bugündür `1.0.4 (467)` (1 Eylül) ile `1.0.5 (501)` (2 Eylül)
yüklendi; 14. gün hâlâ ~10 Eylül. Yani kapalı teste paket göndermek sayacı
kırmıyor. Risk **hangi kodun** değiştiğinde:

1. **Sayaçta pay YOK** — `console-formlari.md` §7: izin listesinde 56 adres,
   opt-in olan **tam 12**. Biri düşerse sayı 11'e iner ve **sayaç sıfırlanır**.
2. **Giriş, bir tester'ı kaybettiren tek hata sınıfı.** Tahtadaki bir aksaklığı
   tolere eden kullanıcı, "giriş yapamıyorum"da uygulamayı siler. Kazanç birkaç
   gün erken çıkmak, kayıp 8 günün tamamı — asimetrik.
3. **"Yalnızca web'de yaparım" kaçışı tam çalışmıyor:** `handle_new_user` web
   ile portun ORTAK trigger'ı; hatalı bir migration mobil tarafta yeni kayıt
   açılmasını da bozar.
4. Production başvurusu penceresi açılırken stabil bir derleme isteniyor
   (başvuru "nasıl test ettirdin, ne geri bildirim aldın" diye soruyor).

Acele bir sebep çıkarsa tek makul ara yol: **yalnızca adım 0**'ı (katı biçimde
EKLEMELİ migration, hiçbir mevcut alanın davranışını değiştirmeyen) yapıp
`execute_sql` ile doğrulamak, kullanıcıya görünen hiçbir şeyi açmamak.

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

