# Play Console — form cevap kağıdı ve adım sırası (24 Ağustos 2026)

Bu dosya **Play Console'a elle girilecek her formun cevabını** taşıyor.
`metin.md` vitrin METİNLERİNİ tutar (başlık/açıklama/görseller); burası
onun dışındaki her şeyi: hangi ekranda ne seçilecek, Data safety'nin veri
türü türü eşlemesi, IARC soruları, kapalı test kanalının kurulumu.

**Neden yazılı:** Data safety beyanı ile ürünün gerçeği ayrışırsa bu bir
askıya alma sebebi. Beyanın her satırının kodda bir karşılığı olmalı ve o
karşılık burada gösterilmeli — böylece bir özellik değiştiğinde beyanın da
değişmesi gerektiği görülebilir.

**Bu dosya bir ANLIK GÖRÜNTÜ değil, yaşayan bir kayıt:** yeni bir veri
toplayan özellik eklendiğinde (kök `CLAUDE.md`'nin "yeni kullanıcı verisi →
`TermsModal`/`PrivacyModal`" kuralının yanına) buradaki tablo da
güncellenmeli.

---

## 0. Sıra — neyin neyi beklediği

Hedef **tek şey**: 14 günlük tester sayacını başlatmak. Sayaç, kapalı testte
**12 tester kesintisiz kayıtlı** olduğu andan itibaren işliyor; o yüzden
sıralama "kolaydan zora" değil, "sayacı en erken başlatan".

| # | Adım | Bloker mi | Not |
|---|---|---|---|
| 1 | **12+ tester'ın Gmail adresini toplamaya BAŞLA** | ⛔ kritik yol | Kod işi değil ama en uzun süren iş. Bugün başla, aşağıdaki adımlarla paralel yürüsün. |
| 2 | Android developer verification (sol menü) | ⛔ | Kimlik doğrulama; tamamlanmadan yayın yapılamıyor |
| 3 | Uygulamayı oluştur (Create app) | ⛔ | Paket adı burada DEĞİL, ilk `.aab` yüklemesinde sabitleniyor |
| 4 | `.aab`'yi kapalı test kanalına **taslak** olarak yükle | ⛔ | Play App Signing'e kaydolma anı (bkz. §5). Taslak, formlar bitmeden de saklanabilir. |
| 5 | App content formları (§3) | ⛔ | Data safety gizlilik politikası URL'i istiyor — hazır |
| 6 | Mağaza vitrini + mağaza ayarları (§4) | ⛔ | Metin/görsel hazır (`metin.md`) |
| 7 | Tester listesi + yayına alma | ⛔ | Sayaç burada başlıyor |
| 8 | 14 gün beklerken: ROADMAP 0.B (hesap silme, deep link) | — | Production başvurusunun ön koşulu |

---

## 1. Uygulamayı oluştur — "Create app"

Play Console → **All apps** → **Create app**.

| Alan | Değer |
|---|---|
| App name | `Kelimeki: Türkçe Kelime Oyunu` |
| Default language | **Türkçe (tr-TR)** |
| App or game | **Game** (Oyun) |
| Free or paid | **Free** — bir daha ücretliye çevrilemez, ama biz zaten ücretsiziz |
| Declarations | Developer Program Policies ✓ · US export laws ✓ |

**Uyarı:** `App name` burada girilen değer mağaza vitrinindekiyle aynı olmak
zorunda değil ama karışıklık çıkarmasın — ikisine de aynı 29 karakterli adı
gir.

---

## 2. `.aab`'yi nereden alacaksın

Her `main` derlemesi imzalı paketi **iki yere** bırakıyor:

- **Doğrudan indirilebilir (bunu kullan):**
  `https://github.com/alpcapa/kelimeki/releases/download/mobile-latest/kelimeki.aab`
  — oturum istemez, zip değildir. (24 Ağustos 2026'da eklendi; öncesinde
  `.aab` YALNIZCA artefakt olarak vardı, yani giriş + zip açma gerekiyordu.)
  **DOĞRULANDI (25 Ağustos 2026):** dosya release'te, 60.929.323 bayt,
  koşu **349** (sha `5eddf3d`) — yani zincir uçtan uca çalışıyor.
- Actions → koşu → `kelimeki-aab` artefaktı (zip, oturum ister) — CI içi kanıt.

**versionCode = GitHub koşu numarası.** Play aynı `versionCode`'u iki kez
kabul etmiyor; her yeni `main` derlemesi yeni bir numara alıyor, yani
yükleme reddedilirse "aynı sürüm" değil başka bir sebep aranmalı.
`versionName` = `1.0.0` (`pubspec.yaml` + `env.dart`, parite testiyle
zorlanıyor).

**Şu an release'te duran paket: `versionCode` 349.** Bu sayı `main`e giren
her mobil derlemede artıyor — yükleme günü tazeyse Actions → son `main`
koşusunun numarasına bak, release notuna onu yaz.

⚠ **iPadOS'ta dosya seçici tuzağı:** Appetize'ın yükleyicisi `.apk`yı iOS
UTI'yi tanımadığı için soluk gösteriyordu (`build-and-distribution-log.md`).
Play Console'un yükleyicisi `.aab` için aynı davranışı gösterirse dosyayı
Files'a indirip oradan seçmeyi dene; olmazsa yükleme bir masaüstü tarayıcı
ister. **Bu ölçülmedi** — ilk yüklemede göreceğiz.

---

## 3. App content (Uygulama içeriği) formları

Sol menü → **Policy** → **App content**. Sırayla:

### 3.1 Privacy policy
```
https://kelimeki.com/gizlilik/
```
Eğik çizgi ZORUNLU (`legal-pages.md` → ölçülmüş tuzak 2: eğik çizgisiz adres
sunucu yönlendirmesine bağlı ve bu ortamdan doğrulanamadı).

### 3.2 App access
**"All or some functionality is restricted"** seç.

Canlı oyun, arkadaşlık, k-lig ve oyun geçmişi giriş istiyor; yapay zekaya
karşı oyun istemiyor. İncelemeciye çalışan bir hesap verilmeli:

**Hesap: `T2` (`kelimekitest2`)** — kullanıcı kararı, 24 Ağustos 2026.
**`T1` BİLEREK KULLANILMIYOR:** o hesabın e-postası geliştiricinin kişisel
Hotmail adresi; Play'e verilen kimlik bilgisi kişisel bir adresi ifşa
etmemeli.

| Alan | Değer |
|---|---|
| Instructions name | `Canlı oyun / arkadaşlık / k-lig` |
| Username | `kelimekitest2@sharedxpteam.testinator.email` |
| Password | *(Console'a sen gireceksin — repoya YAZILMAZ)* |
| Any other instructions | `Uygulama girişsiz de oynanır: "Yapay Zeka ile" sekmesinden oyun başlatılabilir. Canlı oyun, arkadaş listesi, k-lig sıralaması ve skor kartı için sağ üstteki avatar simgesinden bu hesapla giriş yapın.` |

**Hesabın durumu ÖLÇÜLDÜ (24 Ağustos 2026, üretim veritabanı):** e-posta
doğrulanmış ✓ · dondurulmamış ✓ · **3 arkadaş** · **1 aktif Canlı oyun** ·
**11 bitmiş oyun**. Yani incelemeci giriş yaptığında arkadaş listesi, Canlı
oyun ekranı, k-lig sıralaması ve skor kartı BOŞ değil — dördü de gerçek
veriyle açılıyor. Yeni bir hesap açıp vermekten iyi olmasının sebebi bu.

⚠ **İki not:**
- **Bu hesap SİLİNMEYECEK.** ROADMAP 0.B/5 (test hesaplarının temizliği) bu
  satırı kontrol etmeden çalıştırılamaz.
- Adres bir Mailinator alan adında. Gelen kutusu herkese açıksa, adresi
  bilen biri **şifre sıfırlayıp** hesabı ele geçirebilir — ve bu, incelemenin
  bağlı olduğu hesap. Bedeli düşük (bir test hesabı), ama Console'a girmeden
  önce o kutunun gerçekten özel (takım hesabıyla korunan) olduğunu teyit et;
  değilse T2'nin e-postasını özel bir adrese taşı.
- Hesaptaki aktif Canlı oyunun 48 saatlik sayacı işlemeye devam ediyor;
  dolarsa T2 teslim sayılır ve -2 alır. Test hesabı olduğu için zararsız,
  ama incelemeci "oyun bitmiş" görebilir — inceleme yaklaşırken bir hamle
  yapıp sayacı tazelemek işe yarar.

### 3.3 Ads
**"No, my app does not contain ads."** — reklam yok, uygulama içi satın alma
yok, reklam SDK'sı yok.

### 3.4 Advertising ID
**"No"** — uygulama reklam kimliği kullanmıyor. Ölçüldü: yayınlanan pakette
`com.google.android.gms.permission.AD_ID` **yok**, toplam 3 izin var (§6).

### 3.5 Content ratings (IARC anketi)

E-posta: *(iletişim e-postası, §4)* · Kategori: **Game**.

| Soru grubu | Cevap |
|---|---|
| Şiddet (gerçekçi/karikatür) | Hayır |
| Cinsellik / çıplaklık | Hayır |
| Küfür, kaba dil | **Hayır** — sözlük TDK tabanlı, uygulamanın kendi ürettiği bir metin yok. Kullanıcıların yazdığı sohbet ayrı bir soruda beyan ediliyor (aşağı) |
| Kontrollü madde (uyuşturucu/alkol/tütün) | Hayır |
| Kumar / kumar simülasyonu | Hayır |
| Korku / rahatsız edici içerik | Hayır |
| **Kullanıcılar birbiriyle etkileşebiliyor / içerik paylaşabiliyor mu** | **EVET** — Canlı oyunda oyun içi mesajlaşma var |
| Kullanıcının konumu diğer kullanıcılarla paylaşılıyor mu | Hayır |
| Kullanıcılar kişisel bilgilerini paylaşabiliyor mu | **Evet** — serbest metin sohbet; takma isim ve profil fotoğrafı diğer üyelere görünür |
| Dijital ürün satın alma | Hayır |
| Kısıtlanmamış internet erişimi (tarayıcı) | Hayır |

Beklenen sonuç: en düşük yaş bandı + **"Users Interact"** etiketi. Sohbetin
beyan edilmemesi askıya alma sebebi — `chat-moderation.md`'deki sessize alma
/ şikayet / dondurma mekanizması bu beyanın karşılığı.

### 3.6 Target audience and content
- Yaş grupları: **13-15, 16-17, 18+** (yani 13+).
  13 altı seçilirse **Families** politikası devreye girer — çok daha ağır
  bir rejim, gerek yok.
- "Uygulaman çocuklara hitap ediyor mu?" → **Hayır.**
- Store listing'de çocuklara yönelik bir öğe yok.

### 3.7 Diğer beyanlar (hepsi "hayır")
News app · COVID-19 contact tracing/status · Government apps ·
Financial features (**"My app doesn't provide any financial features"**) ·
Health apps.

### 3.8 Data safety — **en dikkatli iş**

Üst düzey üç soru:

| Soru | Cevap |
|---|---|
| Uygulama kullanıcı verisi topluyor ya da paylaşıyor mu? | **Evet** |
| Toplanan tüm veriler aktarım sırasında şifreleniyor mu? | **Evet** (HTTPS; Supabase/Brevo/Vercel uçlarının tamamı TLS) |
| Kullanıcı verilerinin silinmesini talep edebiliyor mu? | **Evet** → `https://kelimeki.com/hesap-silme/` |

**Veri türü eşlemesi.** "Paylaşılıyor" sütunu her satırda **Hayır** — iki
gerekçeyle, ikisi de Play'in kendi istisna listesinde: (a) Supabase/Brevo/
Vercel bizim adımıza işleyen **hizmet sağlayıcı**; (b) takma isim, profil
fotoğrafı ve sohbet **kullanıcının kendi başlattığı** ve uygulamanın açıkça
anlattığı bir görünürlük (k-lig, oyun daveti).

**Bu iki yorum 24 Ağustos 2026'da kullanıcı tarafından ONAYLANDI** — beyan
böyle yapılacak. Kayıt burada duruyor ki ileride "neden paylaşım hayır
denmiş" sorusunun cevabı aranmasın. Gerekçenin dayanağı `PrivacyModal`'ın
4. bölümü: üç sağlayıcı adıyla sayılıyor ve hangi verinin hangi kullanıcıya
görünür olduğu tek tek yazılı — yani beyan ile politika metni birbirini
doğruluyor. **Bu denge bozulursa beyan da değişmeli:** veriyi kendi amacı
için kullanan (hizmet sağlayıcı olmayan) bir üçüncü tarafa — analitik SDK'sı,
reklam ağı, veri satışı — geçilirse "Paylaşılıyor" EVET olur.

| Play veri türü | Ne | Zorunlu mu | Amaç | Kaynak |
|---|---|---|---|---|
| Personal info → **Name** | Ad, soyad | Zorunlu | App functionality · Account management | `AuthModal` (kayıt formu) |
| Personal info → **Email address** | E-posta | Zorunlu | App functionality · Account management · **Developer communications** · *(onay verildiyse)* Advertising or marketing | Supabase Auth; Brevo bildirimleri |
| Personal info → **User IDs** | Takma isim (herkese görünür) | Zorunlu | App functionality · Account management | `profiles.nickname` |
| Personal info → **Other info** | Cinsiyet, doğum tarihi | **İsteğe bağlı** | Analytics | `AuthModal` / Hesap Ayarları |
| Photos and videos → **Photos** | Profil fotoğrafı | **İsteğe bağlı** | App functionality | Supabase Storage; mobilde `image_picker` |
| Messages → **Other in-app messages** | Canlı oyun sohbeti | İsteğe bağlı *(özellik seçmeli)* | App functionality | `chat-moderation.md` |
| App activity → **App interactions** | Oyun istatistikleri, arkadaşlık bağlantıları, ziyaret ve oyun başlangıç olayları | Zorunlu | App functionality · Analytics | `games`, `game_starts`, `visitTracking` |
| App activity → **Other user-generated content** | "Görüş Bildir" mesajları, şikayet nedenleri | İsteğe bağlı | App functionality · Fraud prevention, security and compliance | `feedback`, şikayet akışı |
| App info and performance → **Crash logs** | Hata mesajı + teknik iz | Zorunlu | Analytics | `client_errors` (`telemetry.md`) |
| App info and performance → **Diagnostics** | Sürüm, platform (web/uygulama), işletim sistemi tipi/sürümü, cihaz modeli | Zorunlu | Analytics | `visitTracking`, `client_errors` |
| Device or other IDs → **Device or other IDs** | `anon_id` — cihazda üretilen rastgele kod, hesapla EŞLEŞTİRİLMEZ | Zorunlu | Analytics | `visitTracking` |

**Hiçbir satırda "processed ephemerally" YOK** — hepsi kalıcı olarak
saklanıyor.

**Beyan EDİLMEYENLER (ve neden):**
- Konum — hiç toplanmıyor.
- Finansal bilgi, sağlık, kişi listesi, takvim, dosya, ses — yok.
- Web gezinme geçmişi — yok.
- Medya/depolama erişimi — `image_picker` Photo Picker/SAF üzerinden
  çalışıyor, **hiçbir izin eklemiyor** (§6'da ölçüldü).
- Reklam kimliği — kullanılmıyor.

⚠ **Play politikası hatırlatması:** hesap açtıran uygulamalarda Play, web
silme adresinin YANINDA **uygulama içi** bir hesap silme yolu da istiyor.
Bugün yok (`LegalContent.tsx` bunu açıkça yazıyor) — ROADMAP 0.B/2. Kapalı
test bununla yayınlanabilir, **production başvurusu edilemez.**

---

## 4. Mağaza vitrini ve ayarları

**Store listing** (metinler `metin.md`'de, oradan kopyala):
uygulama adı (29/30) · kısa açıklama (79/80) · tam açıklama (1906/4000) ·
ikon `store-icon-512.png` · öne çıkan görsel `feature-graphic.png` ·
**telefon ekran görüntüleri** (7 kare, 1080×2072, sende).

**Store settings:**

| Alan | Değer |
|---|---|
| App category | **Games → Word** |
| Tags | Word · Puzzle · Board · Casual (en fazla 5) |
| Website | `https://kelimeki.com` |
| E-posta | **`destek@kelimeki.com`** — karar 24 Ağustos 2026, kullanıcı. Adres HENÜZ YOK, kurulumu §8'de. ⚠ Bu alan mağaza sayfasında **herkese açık**: kişisel adres yazılmaz, `noreply@` de olmaz (gelen kutusu yok) |
| Telefon | İsteğe bağlı — boş bırak (o da herkese açık) |
| External marketing | İzin ver |

---

## 5. Kapalı test kanalı — ilk yükleme

Sol menü → **Test and release** → **Testing** → **Closed testing** →
kanalı aç → **Create new release**.

1. **Play App Signing → "Use Google-generated key"** (varsayılan; ilk
   yüklemede çıkıyor). ⛔ **KAYDOL.** Kaydolmazsan upload keystore'unun
   kaybı = uygulamanın bir daha asla güncellenememesi.
2. `kelimeki.aab`'yi yükle (§2).
3. Release name: `1.0.0 (<koşu numarası>)` — bugün **`1.0.0 (349)`** ·
   Release notes: kısa bir "ilk kapalı test" notu.
4. **Ülkeler: TÜMÜ.** Türkçe bir oyun için Türkiye yeter gibi görünüyor ama
   Play hesabının ülkesi Türkiye olmayan bir tester **kuramaz** ve sayıya
   girmez; kısıtlamanın kazancı yok, riski var.

**Yükleme ekranından OKUNACAK iki şey** (`build-and-distribution-log.md`
bunları "hâlâ ölçülmedi" diye bırakmıştı; 24 Ağustos'ta pakete bakılarak
ölçüldüler, Console'daki değer de aynı çıkmalı): `targetSdk` **36**,
izinler **3 adet** (§6). Farklı bir şey görürsen Data safety beyanı
yeniden gözden geçirilmeli.

**⚠ SENİN cihazındaki CI `.apk`'sı önce SİLİNMELİ.** O paket debug
anahtarıyla imzalı; Play'den gelen paket upload/Play anahtarıyla imzalı ve
imzalar uyuşmadığı için üstüne kurulmuyor
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Ekran görüntüleri o `.apk` ile
alındığı için geliştirme cihazında kesinlikle var.

**Tester'lar için GEREKMİYOR (24 Ağustos 2026, kullanıcı):** bugüne kadar
hiç kimseye test `.apk`'sı gönderilmedi, yani tester'ların cihazı temiz.
İleride birine `mobile-latest`ten `.apk` verilirse bu uyarı o kişi için
geri gelir.

---

## 6. Ölçülmüş paket gerçekleri (formlarda bunlara dayan)

24 Ağustos 2026'da **yayınlanmış pakete** bakılarak ölçüldü (kaynağa değil):
`mobile-latest`teki `kelimeki.apk` (sha `18689eb`) indirilip derlenmiş
`AndroidManifest.xml`i çözüldü.

| | Değer |
|---|---|
| `minSdkVersion` | 24 (Android 7.0) |
| `targetSdkVersion` | 36 |
| İzinler | `INTERNET` · `ACCESS_NETWORK_STATE` · `com.kelimeki.kelimeki.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (AndroidX'in iç izni, kullanıcıya görünmez) |

`image_picker` **hiçbir izin eklemiyor** → Data safety'de medya/depolama
beyanı yok, "Photo and video permissions" bildirimi de gerekmiyor.

---

## 7. 12 tester + 14 gün

**Şart:** kapalı testte **en az 12 tester**, **kesintisiz 14 gün** kayıtlı.
Sayaç "yükledim" ile değil, **12 kişi opt-in olduğunda** işlemeye başlıyor.

| Tuzak | Ne yapmalı |
|---|---|
| Listeye eklemek YETMEZ | Her tester **opt-in bağlantısına tıklayıp kabul etmeli** |
| Biri çıkarsa sayaç kırılır | **15-20 kişi topla**, 12 tabandır |
| Adresler Google hesabı olmalı | Gmail ya da Google'a bağlı bir adres; şirket/okul adresi olabilir ama Play hesabı olmalı |
| Cihazdaki eski CI `.apk` | **Tester'lar için sorun değil** — kimseye `.apk` gönderilmedi (§5). Yalnızca geliştirme cihazında var |
| Production başvurusu geri bildirim soruyor | Tester'lardan **yazılı geri bildirim topla** — başvuruda "nasıl test ettirdin" sorusu var |

**Tester'a gönderilecek metin (taslak):**

> Kelimeki'nin kapalı testine davetlisin. İki adım:
> 1. Şu bağlantıyı Android telefonundan aç ve "Become a tester" de:
>    *(Play Console'un verdiği opt-in linki)*
> 2. Aynı sayfadaki Play Store bağlantısından uygulamayı kur.
>
> Testin sayması için **14 gün boyunca listede kalman** yeterli — uygulamayı
> silsen bile testerlıktan çıkma. Takıldığın ya da tuhaf gelen bir şey olursa
> yaz, iyi olur.

---

## 8. `destek@kelimeki.com` — kurulum

**Karar (24 Ağustos 2026, kullanıcı):** mağaza iletişim adresi kendi
domainimizde, gerçek bir destek adresi olacak. Bugün böyle bir adres YOK —
`noreply@kelimeki.com` yalnızca GÖNDERİYOR, gelen kutusu yok.

**Play'in istediği tek şey ALMAK.** Ama yalnızca yönlendirme kurulursa bir
kullanıcıya cevap yazdığında `From` alanında **kişisel adresin** görünür —
proje bugüne kadar tam bundan kaçınmak için `noreply@kelimeki.com` kullandı
(bkz. kök `CLAUDE.md` → Brevo sender kurulumu). Bu yüzden hedef **gerçek
posta kutusu**: hem alan hem `destek@`'dan cevap yazabilen.

### ⛔ Kurulumdan önce — SPF tuzağı

**Bir domainde SPF kaydı YALNIZCA BİR TANE olabilir.** `kelimeki.com`'da 20
Temmuz 2026'da Brevo için girilmiş bir tane var. Kuracağın mail servisi
"şu SPF kaydını ekle" diyecek — **ikinci bir TXT eklersen SPF `PermError`
verir** ve o gün çözülen teslimat sorunu (kayıt onayı mailleri spam'e
düşüyordu) aynen geri gelir. Doğrusu, yeni `include:`i **mevcut kaydın
içine** yazmak:

```
v=spf1 include:spf.brevo.com include:<yeni-servis> ~all    ← TEK kayıt
```

**MX kayıtları yalnızca ALMAYI etkiler** — Brevo gönderirken MX'e bakmaz,
yani `noreply@` akışı (kayıt onayı, şifre sıfırlama, davet/süre bildirimleri,
destek yanıtı) bu kurulumdan etkilenmez. DKIM ayrı selector'larda durur,
çakışmaz. DMARC kaydına dokunulmaz.

### Adımlar (panel adları değişir, kayıtlar aynı)

1. Mail servisinde domaini ekle, verdiği **doğrulama TXT**'ini gir.
2. **MX kayıtlarını** ekle (varsa eskileri kaldır — MX'te birden fazla
   sağlayıcı olmaz).
3. **DKIM** TXT kaydını gir (kendi selector'ında, Brevo'nunkiyle çakışmaz).
4. **SPF'i BİRLEŞTİR** — yukarıdaki uyarı.
5. `destek@` kutusunu aç, kendine bir test maili at, geldiğini gör.
6. Play Console → Store settings → iletişim e-postasına yaz.

### "Brevo zaten var, neden onunla almıyoruz?" (25 Ağustos 2026)

Soruldu, cevabı kayda geçiyor çünkü tekrar sorulacak. **Brevo'nun alma
özelliği VAR** — *Inbound Parsing* — ama verdiği şey posta kutusu değil bir
**webhook**: MX'i Brevo'ya çevirirsin, gelen mail ayrıştırılıp verdiğin
URL'e JSON olarak POST edilir. Açıp okuyacağın kutu, "Yanıtla" düğmesi,
spam filtresi yok.

Brevo bugün bizde **yalnızca gönderiyor** (Auth SMTP + `feedback-reply` /
`admin-send-message` Transactional API). Göndermek MX istemez, almak ister —
eksik parça bu. Karar zaten 26 Temmuz 2026'da alınmıştı (kök `CLAUDE.md`,
"hafif çözüm"): gerçek kutu = Inbound Parsing + subdomain/MX + çok mesajlı
şema, ve bilerek ertelendi.

**Uzun vadede doğru cevap yine bu** — altyapının yarısı duruyor
(`feedback.origin`, `feedback.related_to`, admin paneli, `feedback-reply`),
ve tam olarak `CLAUDE.md`'nin "hâlâ çözülmeyen kısım" dediği şeyi kapatır:
kullanıcı mailde **Yanıtla**'ya basınca cevap bugün `noreply@`'a gidip
kayboluyor. **Ama bugünün işi değil, dört sebeple:**

1. **Sessizce kaybeden boru.** Webhook patlarsa mail buharlaşır; kutuda
   dursa dururdu. Ham gövdeyi önce saklayıp sonra ayrıştırmak gerekir.
2. **Spam.** `destek@` Play vitrininde herkese açık olacak. Kutu sağlayıcısı
   filtreler; Brevo her şeyi verir ve admin paneline düşer.
3. **Güvenlik.** Webhook `verify_jwt:false` olmak zorunda (Brevo JWT
   taşımaz) → paylaşılan bir sır/gizli yol olmadan herkes panele sahte
   "görüş" POST edebilir. Tasarlanması gereken gerçek bir iş.
4. **MX tekil.** `kelimeki.com`'un MX'i tek yere bakar; Brevo alırsa o
   domainde bir daha normal kutu açılamaz.

**Sıra bu yüzden ters kurulmayacak:** önce gerçek kutu (MX → Zoho), sonra
istenirse kutudan bir subdomain'deki Brevo inbound adresine kopya
yönlendirilir — hiçbir şey kaybedilmez. Tersi tek yönlü.

**Kutu açılınca bedava kazanç:** `_shared/email.ts`'teki `KELIMEKI_SENDER`
`noreply@` yerine `destek@` olur (sabit değişikliği + Brevo'da sender
doğrulaması). O anda kullanıcının "Yanıtla"sı gerçek bir kutuya gider ve
`buildNoreplyNoticeHtml`'in "cevap için tıklayın" numarasının varlık sebebi
büyük ölçüde kalkar.

### DNS: **GoDaddy** (25 Ağustos 2026)

Domain GoDaddy'de kayıtlı ve DNS de orada yönetiliyor — Temmuz'daki Brevo
SPF/DKIM/DMARC kayıtları oraya girilmişti. Panel:
**Ürünlerim → `kelimeki.com` → DNS → DNS Kayıtlarını Yönet**
(*My Products → Domains → Manage DNS*).

**Bu bir seçeneği ELEDİ:** Cloudflare Email Routing (ücretsiz, alma
tarafında en temiz çözüm) nameserver'ların Cloudflare'e taşınmasını
gerektiriyor — canlı bir sitenin NS'ini taşımanın riski, kazandırdığından
büyük. Geriye gerçek kutu için **Zoho Mail** (ücretsiz katman), yalnızca
yönlendirme için **ImprovMX** kalıyor. GoDaddy'nin kendi paketine dahil bir
e-posta yönlendirmesi varsa üçüncü tarafa hiç gerek kalmaz — panelde
kontrol edilecek.

**Canlı kayıtlar okunurken GoDaddy panelindeki üç satır:** `@` adlı ve
`v=spf1` ile başlayan `TXT` (birleştirilecek olan), varsa `MX` kayıtları
(iki sağlayıcı bir arada olmaz, mevcut varsa değişecek) ve `_dmarc` `TXT`
(dokunulmayacak, kurulum sonrası yerinde olduğu doğrulanacak). DKIM
kayıtları (`..._domainkey`) sorun değil — her sağlayıcı kendi selector'ında
durur.

### Açık kalan

- Canlı SPF kaydının tam metni (yukarıdaki panelden okunacak) — birleştirme
  onsuz yapılamaz.
- Servis seçimi: ücretsiz katman şartları değişebiliyor, kayıt sırasında
  teyit et. Zoho'da veri merkezi seçimi `include:` ifadesini de değiştirir
  (`zoho.com` / `zoho.eu`) — kurulum sihirbazının verdiği değeri kullan,
  ezberden yazma.

### ⚠ Bu iş 14 günlük sayacı BEKLETMEMELİ

Mağaza iletişim e-postası **sonradan değiştirilebilir**. DNS/mail kurulumu
bir güne yayılırsa, kapalı testi başlatmak için oraya geçici olarak
alabildiğin bir adres yaz ve `destek@` hazır olunca değiştir. Kritik yolda
duran tek şey **12 tester**, bu değil.
