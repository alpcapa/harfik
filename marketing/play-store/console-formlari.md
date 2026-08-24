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
- Actions → koşu → `kelimeki-aab` artefaktı (zip, oturum ister) — CI içi kanıt.

**versionCode = GitHub koşu numarası.** Play aynı `versionCode`'u iki kez
kabul etmiyor; her yeni `main` derlemesi yeni bir numara alıyor, yani
yükleme reddedilirse "aynı sürüm" değil başka bir sebep aranmalı.
`versionName` = `1.0.0` (`pubspec.yaml` + `env.dart`, parite testiyle
zorlanıyor).

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

| Alan | Değer |
|---|---|
| Instructions name | `Canlı oyun / arkadaşlık / k-lig` |
| Username | *(test hesabının e-postası — sen gireceksin)* |
| Password | *(test hesabının şifresi)* |
| Any other instructions | `Uygulama girişsiz de oynanır: "Yapay Zeka ile" sekmesinden oyun başlatılabilir. Canlı oyun, arkadaş listesi, k-lig sıralaması ve skor kartı için sağ üstteki avatar simgesinden bu hesapla giriş yapın.` |

⚠ **Bu hesap SİLİNMEYECEK.** ROADMAP 0.B/5 (test hesaplarının temizliği)
bu satırı kontrol etmeden çalıştırılamaz.

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
anlattığı bir görünürlük (k-lig, oyun daveti). ⚠ Bu iki yorum senin onayını
istiyor — Play'in "sharing" tanımı bu istisnaları tanıyor ama beyanı yapan
sensin.

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
| E-posta | ⚠ **HERKESE AÇIK** — mağaza sayfasında görünür. Kişisel adresini yazma; `noreply@` de olmaz (gelen kutusu yok). Karar senin: yeni bir `destek@kelimeki.com` mı, mevcut bir adres mi? |
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
3. Release name: `1.0.0 (<koşu numarası>)` · Release notes: kısa bir
   "ilk kapalı test" notu.
4. **Ülkeler: TÜMÜ.** Türkçe bir oyun için Türkiye yeter gibi görünüyor ama
   Play hesabının ülkesi Türkiye olmayan bir tester **kuramaz** ve sayıya
   girmez; kısıtlamanın kazancı yok, riski var.

**Yükleme ekranından OKUNACAK iki şey** (`build-and-distribution-log.md`
bunları "hâlâ ölçülmedi" diye bırakmıştı; 24 Ağustos'ta pakete bakılarak
ölçüldüler, Console'daki değer de aynı çıkmalı): `targetSdk` **36**,
izinler **3 adet** (§6). Farklı bir şey görürsen Data safety beyanı
yeniden gözden geçirilmeli.

**⚠ Cihazdaki CI `.apk`'sı önce SİLİNMELİ.** O paket debug anahtarıyla
imzalı; Play'den gelen paket upload/Play anahtarıyla imzalı ve imzalar
uyuşmadığı için üstüne kurulmuyor (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`).
Bu, tester'lara gönderilecek metne de girmeli.

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
| Cihazdaki eski CI `.apk` | Kurulumdan önce sildir (§5) |
| Production başvurusu geri bildirim soruyor | Tester'lardan **yazılı geri bildirim topla** — başvuruda "nasıl test ettirdin" sorusu var |

**Tester'a gönderilecek metin (taslak):**

> Kelimeki'nin kapalı testine davetlisin. Üç adım:
> 1. Telefonunda daha önce Kelimeki'nin test `.apk`'sı kuruluysa **önce onu
>    kaldır** (imzası farklı, üstüne kurulmuyor).
> 2. Şu bağlantıyı Android telefonundan aç ve "Become a tester" de:
>    *(Play Console'un verdiği opt-in linki)*
> 3. Aynı sayfadaki Play Store bağlantısından uygulamayı kur.
>
> Testin sayması için **14 gün boyunca listede kalman** yeterli — uygulamayı
> silsen bile testerlıktan çıkma. Takıldığın ya da tuhaf gelen bir şey olursa
> yaz, iyi olur.
