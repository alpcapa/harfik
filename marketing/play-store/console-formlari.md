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
| Free or paid | **Free** — bir daha ücretliye çevrilemez (aşağı bkz.) |
| Declarations | Developer Program Policies ✓ · US export laws ✓ |

**Uyarı:** `App name` burada girilen değer mağaza vitrinindekiyle aynı olmak
zorunda değil ama karışıklık çıkarmasın — ikisine de aynı 29 karakterli adı
gir.

**"Free" seçimi para kazanmayı KİLİTLEMİYOR** (25 Ağustos 2026'da soruldu,
cevabı buraya yazılıyor çünkü tekrar sorulacak). Play'deki `Free/Paid`
ayrımı yalnızca **indirmenin kendisi ücretli mi** demek. Uygulama içi satın
alma ve abonelik bundan bağımsız: reklam göstermek, reklamsız abonelik
satmak, tek seferlik satın alma — üçü de "Free" uygulamada mümkün.
Kilitlenen tek şey önden indirme ücreti almak, ki bir Türkçe kelime oyunu
için edinimi öldüren model zaten o.

⚠ **Ama reklam eklenirse BEYAN ZİNCİRİ değişir** — ve beyan ile gerçeğin
ayrışması askıya alma sebebi. Aynı anda güncellenecekler: App content →
**Ads** ve **Advertising ID**; **Data safety** (reklam SDK'ları cihaz
kimliği topluyor ve çoğu üçüncü tarafa aktarıyor → birkaç satır
"Paylaşılıyor: EVET"e döner); `LegalContent.tsx` + portun
`legal_modals.dart`'ı; ve `metin.md`'nin harfiyen *"Reklam yok, uygulama
içi satın alma yok"* diyen tam açıklaması. Abonelik ayrıca Play Billing +
merchant kurulumu ister.

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

Sol menü → **Test and release** → **App content**. Sırayla:

⚠ **YOL DÜZELTİLDİ (26 Ağustos 2026 — menüde ölçüldü):** burada uzun süre
*"Sol menü → Policy → App content"* yazıyordu; **`Policy` diye bir grup
YOK.** Sol menünün tamamı sekiz gruptan ibaret (Dashboard · Statistics ·
Publishing overview · Protected with Play · Test and release · Monitor and
improve · Grow users · Monetize with Play) ve App content, **Test and
release**'in içinde — Testing kanallarının ALTINDA, `App integrity` ve
`Setup` ile aynı yerde. §6.6 bunu zaten doğru yazmıştı ("Test and release →
App integrity"), bu satır onunla çelişiyordu. **Tuzak:** "Test and
release"i açtığında "Testing" alt grubu da açık geliyor ve altındakileri
ekrandan itiyor — Testing'i kapatınca App content görünüyor.

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
`com.google.android.gms.permission.AD_ID` **yok**, toplam 4 izin var (§6).

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

**Ek sorular (25 Ağustos 2026'da Console'da çıktı, cevaplarıyla):**

| Soru | Cevap | Gerekçe |
|---|---|---|
| Kullanıcı engelleme / içerik gizleme var mı | **Yes** | Canlı oyunda sessize alma — o kişinin mesajları sana görünmüyor |
| Şikayet etme var mı | **Yes** | Şikayet nedeniyle birlikte yönetici ekibine gidiyor |
| **Chat moderation var mı** | **NO** | ⚠ Bilinçli. Kullanım Koşulları harfiyen *"mesajlar önceden denetlenmez (moderasyona tabi değildir)"* diyor: ön filtre yok, küfür süzgeci yok, moderatör kadrosu yok — yalnızca TEPKİSEL inceleme. "Evet" demek kendi yayınlanmış koşullarımızla çelişirdi |
| Etkileşimler davet edilen arkadaşlarla sınırlanabiliyor mu | **Yes** | Ölçüldü: `LiveGameCreateForm` rakibi arkadaş listesinden seçtiriyor; rastgele eşleşme/halka açık oyun YOK, ne web'de ne portta |
| Konum diğer kullanıcılarla paylaşılıyor mu | **No** | Konum hiç toplanmıyor |
| Nazi sembolleri | **No** | — |

**SONUÇ (25 Ağustos 2026): en düşük yaş bandı — PEGI 3, USK 0, ESRB
Everyone, IARC 3+.** `ROADMAP.md` "sohbet yaş derecesini yükseltir" diye
öngörmüştü; **ölçüm bunu doğrulamadı.** Sohbet dürüstçe beyan edildi ve
derece yine de düşük kaldı — çünkü sohbete ancak kabul edilen arkadaş
girebiliyor ve kullanıcı sessize alıp şikayet edebiliyor. İlk üç sorunun
cevabı burada işe yaradı. Sohbetin beyan edilmemesi ise askıya alma sebebi
olurdu — `chat-moderation.md`'deki mekanizma bu beyanın karşılığı.

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
saklanıyor. ⚠ Bu bir KUTUCUK değil, radyo çifti: "No, this collected data
is not processed ephemerally" açıkça SEÇİLMELİ, boş bırakılamaz.

**Formun sorduğu iki ek soru (25 Ağustos 2026):**

- **"Hangi hesap oluşturma yöntemlerini destekliyorsun?"** → yalnızca
  **`Username and password`**. Koddan doğrulandı (`auth_service.dart`):
  `signUp(email, password)` / `signInWithPassword`; OAuth yok, sosyal giriş
  yok, 2FA yok. Play'in kendi açıklaması e-postayı "username" sayıyor.
- **"Hesabı silmeden verinin bir kısmının silinmesini talep etme yolu
  sunuyor musun?" (Optional)** → **`No`**. `/hesap-silme/` yalnızca TAM
  hesap silmeyi anlatıyor; kısmi silme için ayrı bir mekanizma yok.
  Politikanın KVKK m.11 bölümü hakkı veriyor ve talep gelse yapardık, ama
  Play burada bir HAK değil sunulan bir YOL soruyor — "Yes" deyip
  incelemecinin karşısına genel bir geri bildirim formu çıkarmak beyanı
  abartmak olurdu. Alan zaten opsiyonel, bedeli sıfır.
  **İleride ucuza "Yes"e çevrilebilir:** `/hesap-silme/`'ye "yalnızca
  belirli verilerimin silinmesini istiyorum" bölümü eklemek yeterli — ve
  ROADMAP madde 2 (uygulama içi hesap silme) zaten o sayfaya dokunacak.

**Beyan EDİLMEYENLER (ve neden):**
- Konum — hiç toplanmıyor.
- Finansal bilgi, sağlık, kişi listesi, takvim, dosya, ses — yok.
- Web gezinme geçmişi — yok.
- Medya/depolama erişimi — `image_picker` Photo Picker/SAF üzerinden
  çalışıyor, **hiçbir izin eklemiyor** (§6'da ölçüldü).
- Reklam kimliği — kullanılmıyor.

✅ **ENGEL KALKTI (26 Ağustos 2026).** Bu paragraf *"uygulama içi silme
bugün yok … production başvurusu edilemez"* diyordu. Uygulama içi hesap
silme (ROADMAP madde 2) **372**'de yayında: Hesap Ayarları › Hesabımı Sil.
İki gerçek hesapla (T4, T1) uçtan uca doğrulandı —
`docs/decisions/account-deletion.md` → "Gerçek kullanım".

**Beyanda değişen bir şey YOK:** formun silme sorusunun cevabı hâlâ
**Evet → `https://kelimeki.com/hesap-silme/`**, ve o sayfanın 1. bölümü
artık uygulama içi yolu anlatıyor — yani beyan ettiğimiz adres, beyan
ettiğimiz şeyi doğru anlatıyor. Play'in uygulama içi şartı bir form alanı
değil, **uygulamanın kendisinde** aranan bir politika şartı.
"Hesabı silmeden verinin bir kısmının silinmesini talep etme yolu" sorusu
da **`No`** kalıyor — kısmi silme eklenmedi.

---

## 4. Mağaza vitrini ve ayarları

**Store listing** (metinler `metin.md`'de, oradan kopyala):
uygulama adı (29/30) · kısa açıklama (79/80) · tam açıklama (1906/4000) ·
ikon `store-icon-512.png` · öne çıkan görsel `feature-graphic.png` ·
**telefon ekran görüntüleri** (7 kare, 1080×2072, sende).

**AI asset declaration → `Don't label assets`** (25 Ağustos 2026'da soruldu).
Alan, mağaza görsellerinin ÜRETKEN yapay zeka ile oluşturulup
oluşturulmadığını soruyor. Bizde hiçbiri öyle değil: ikon ve öne çıkan
görsel `npm run generate-play-assets` ile üretiliyor — betik uygulamanın
KENDİ üretim React bileşenlerini sunucuda render edip PNG'ye çeviriyor,
yani deterministik kod çıktısı; logo statik SVG path; ekran görüntüleri
gerçek cihazdan. **Yeni bir mağaza görseli üretken bir modelle
yapılırsa bu cevap değişmeli.**

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
izinler **4 adet** (§6). Farklı bir şey görürsen Data safety beyanı
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
| İzinler | **4 adet** — `INTERNET` · `ACCESS_NETWORK_STATE` · `com.android.vending.CHECK_LICENSE` · `com.kelimeki.kelimeki.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` |

`image_picker` **hiçbir izin eklemiyor** → Data safety'de medya/depolama
beyanı yok, "Photo and video permissions" bildirimi de gerekmiyor.

⚠ **DÜZELTME (25 Ağustos 2026, Play Console'un paket ayrıntısından okundu):**
bu bölüm önce **3 izin** diyordu; Play **4** gösteriyor. Fark
`com.android.vending.CHECK_LICENSE` — yayınlanmış `.apk`'da (sha `18689eb`)
yoktu, Play'in işlediği `.aab`'de (349 / `5eddf3d`) var. **Beyanı
DEĞİŞTİRMİYOR:** çalışma zamanı izni değil (kullanıcıya sorulmaz), kendi
başına veri toplamaz, medya/depolama/konum/kamera sınıfından değil —
uygulamanın Play'e "bu kopya meşru mu" diye sormasını sağlayan lisans
doğrulama kanalı. Kaynağı kesin belirlenmedi; iki makul aday, yükleme
ekranındaki **"Automatic protection"** eklentisi (lisans kontrolü kullanıyor,
`.apk`'da olmayıp `.aab`'de olmasını en iyi bu açıklıyor) ve Flutter'ın
Android gömme katmanındaki Play Core. Ayırt etmenin pratik faydası yok.

**Ders:** paket gerçeklerini yayınlanmış `.apk`'dan ölçmek `.aab`'nin
tamamını kanıtlamıyor — Play, bundle'ı işlerken manifeste ekleme yapabiliyor.
Bir sonraki sürümde de izin listesini **Console'un paket ayrıntısından**
oku.

✅ **YENİDEN ÖLÇÜLDÜ — 372 (26 Ağustos 2026, Console'un paket ayrıntısı).**
Yukarıdaki kural uygulandı ve liste DEĞİŞMEDİ: `ACCESS_NETWORK_STATE`,
`INTERNET`, `com.android.vending.CHECK_LICENSE`,
`com.kelimeki.kelimeki.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` — 4 adet.
Aynı ekranda `targetSdk` **36**, `minSdk` **24+**, ABI **3**, ekran düzeni
**4**, gerekli özellik **2**; yani 372'nin satırı 349'unkiyle **her sütunda
birebir aynı**. Uygulama içinden hesap silme (madde 2) paketin platform
yüzeyine hiç dokunmadı → **Data safety beyanında izin kaynaklı bir
değişiklik YOK.**

⚠ Aynı turda §3.4 ve §5'te kalmış iki bayat "3 izin" atfı da 4'e çekildi —
§6 25 Ağustos'ta düzeltilmiş ama o iki yer güncellenmemişti. Bir sayıyı
düzeltirken **aynı sayının öteki geçtiği yerleri de tara**; bu dosyada
sayı üç yerde yaşıyor.

---

## 6.5 — Console'da BİTENLER (25 Ağustos 2026)

| Adım | Durum |
|---|---|
| Android developer verification | ✅ (kayıt sırasında tamamlanmış) |
| Uygulama oluşturuldu | ✅ Game · Free · tr-TR |
| `.aab` yüklendi | ✅ 349 (1.0.0) · Play App Signing'e KAYDOLUNDU |
| Store listing (metin + ikon + feature graphic + 7 ekran görüntüsü) | ✅ |
| App content: privacy policy, ads, advertising ID, news, COVID, government, financial, health | ✅ hepsi |
| App access | ✅ T2, "tam erişim" kutusu işaretli |
| Content ratings (IARC) | ✅ en düşük bant |
| Target audience | ✅ 13-15 / 16-17 / 18+ |
| Data safety | ✅ 11 veri türü |
| Store settings (kategori + iletişim) | ✅ Games→Word · `destek@kelimeki.com` |
| Countries/regions | ✅ tümü |
| Tester listesi | ✅ `Kelimeki Testers` |
| Feedback URL | ✅ `destek@kelimeki.com` |
| **Preview and confirm → Send for review** | ✅ **GÖNDERİLDİ — 25 Ağustos 2026, "Your changes are in review"** |

**Son engel `Advertising ID` beyanıydı** — sekiz kısa beyandan biri atlanmıştı
ve "send for review"u bloklamıştı (*"All developers targeting Android 13 or
later are required to let us know if their app uses advertising ID"*).
Cevap `No`; paketin izin listesinde `AD_ID` olmadığı Console'un kendi paket
ayrıntısından zaten okunmuştu.

---

## 6.6 — Play App Signing SHA-256 → `assetlinks.json` (25 Ağustos 2026)

**Console'da nerede:** Test and release → **App integrity** → *Play app
signing* sekmesi. (Menüde "App integrity" bir süredir *Release* başlığının
altına taşındı; eski "Setup → App integrity" yolu artık yok — kullanıcı bu
yüzden ilk aramada bulamadı.)

### ⚠ DEĞERİ ANAHTAR TABLOSUNDAN OKUMA — sayfanın kendi ürettiği JSON'u kopyala

Bu ilk turda YANLIŞ yapıldı ve canlıya yanlış parmak iziyle çıktı (aynı gün
düzeltildi). Ders şu: App signing sayfası birkaç parmak izi gösteriyor
(*Upload key certificate* altında MD5/SHA-1/SHA-256; imza anahtarı için
**Classical** ve **Post-quantum** ayrı ayrı) — ve **App Links'in istediği
değer bu tablolardan okunmaz.** Aynı sayfanın altında Google'ın kendi
ürettiği bir **"Digital Asset Links JSON"** paneli var; metni birebir
`assetlinks.json` olsun diye üretiliyor ("copy and paste this snippet into
your Digital Asset Links JSON file"). **Kanonik kaynak odur; kopyala
düğmesine bas ve dosyaya OLDUĞU GİBİ koy.**

İlk turda parmak izi imza anahtarı tablosundan okundu (`B4:88:80:09…`) ve
dosyaya o girdi; Google'ın paneli ise `2B:7D:26:11…` diyordu. İkisi neden
farklı, Console'dan anlaşılmadı — ama tartışmaya gerek yok: doğrulamayı
yapan taraf bu snippet'i üretiyor. **Hatanın sinsiliği kayda değer:** yanlış
parmak izi hata VERMEZ, dosya 200 döner, testler geçer — linkler yalnızca
sessizce tarayıcıda açılmaya devam eder. Kullanıcı Console'daki paneli
görüp "bunlara ihtiyacım var mı?" diye sormasa fark edilmeyecekti.

| Ekrandaki değer | SHA-256 başı | Nerede kullanılır |
|---|---|---|
| **Digital Asset Links JSON paneli** | `2B:7D:26:11…` | ✅ `assetlinks.json` — TEK doğru kaynak |
| App signing key tablosu (Classical) | `B4:88:80:09…` | ❌ Buradan okuma (ilk turdaki hata) |
| **Upload key** (bizim keystore) | `B6:CD:FB:A9…` | ❌ Yalnızca karşılaştırma; dosyaya ASLA girmez |

`sha256_cert_fingerprints` bir DİZİ; ileride Google snippet'e ikinci bir
parmak izi eklerse o da aynı yerden kopyalanır.

**Dosya:** `public/.well-known/assetlinks.json`. `package_name`
`com.kelimeki.kelimeki` — `mobile/app/android/app/build.gradle.kts`'teki
`applicationId`'nin AYNISI olmak zorunda.

### ⚠ Ölçülen tuzak: yakalayıcı rewrite statik yolu yutabilirdi

`vercel.json`'da `{"source": "/(.*)", "destination": "/index.html"}` var —
`/gizlilik/`'te tam bu sınıf hata yaşanmıştı (bkz.
`docs/decisions/legal-pages.md`). Bu yüzden dosya yazıldıktan sonra
servis edilme yolu **ölçüldü, varsayılmadı**:

1. `npm run build` → `dist/.well-known/assetlinks.json` gerçekten üretiliyor
   (Vite nokta ile başlayan `public/` klasörünü de kopyalıyor — bu
   doğrulanmadan bilinmiyordu).
2. `vite preview` → `Content-Type: application/json`, 200, gövde doğru
   (SPA kabuğu DEĞİL). Vercel de `rewrites`'ı dosya sistemi kontrolünden
   SONRA uyguluyor; `/gizlilik/` üretimde zaten bu şekilde çalışıyor.
3. Service worker'a dokunmak GEREKMEDİ: `navigateFallback` yalnızca
   *navigation* isteklerini yakalıyor, bu bir JSON `fetch`'i — üstelik
   doğrulamayı yapan Android platformunun kendisi, tarayıcı değil.
   Precache listesinde de yok (`dist/sw.js`'te arandı, sıfır sonuç).

### Regresyon

`tests/smoke.spec.ts` 30 → **31 test**: dosya 200 + `application/json`
dönüyor, `package_name` `build.gradle.kts`'ten OKUNARAK karşılaştırılıyor
(elle senkron bırakılmadı), Play parmak izi mevcut ve **upload anahtarıyla
başlayan hiçbir parmak izi yok**. **Negatif eş ikisi de ölçüldü:** parmak
izi upload anahtarıyla değiştirilince test düşüyor; dosya silinince gelen
yanıt `text/html` (yani yakalayıcı rewrite gerçekten SPA kabuğunu
döndürüyor) ve test yine düşüyor.

**Anahtar değişirse** (Play'de key rotation ya da yeni bir uygulama):
Console'daki **Digital Asset Links JSON panelini** yeniden kopyala (anahtar
tablosunu DEĞİL), dosyayı değiştir, testteki sabiti de aynı PR'da güncelle —
test bilerek sabiti içeriyor ki sessiz bir sapma mümkün olmasın.

**YAYINLANDI — 25 Ağustos 2026.** Submission 1 (*Closed testing - Alpha,
Store Listing, App Content, Advanced distribution, Store settings*) durumu
**Published**. Kapalı test kanalı canlıda.

**Opt-in linki — ölçülen zaman çizelgesi (tahmin YOK):**

| Ne zaman | Kanalın durumu | Liste | "How testers join your test" |
|---|---|---|---|
| 25 Ağu | 349 `Published` | 9-11 adres | **link YOK** |
| 26 Ağu 09:03 | 372 *in review* | **11 adres** | **iki link de VAR** (Join on Android · Join on the web) |

**Sebebi BİLİNMİYOR ve uydurulmayacak.** Aynı gün önce "12 kişi olmadan
link verilmiyor" diye bir kural yazıldı — ertesi ekran görüntüsü onu
**çürüttü**: liste 11'ken linkler geldi. Tetikleyici muhtemelen kanalda bir
sürümün gönderilmiş/işlenmiş olması, ama bu **ölçülmedi**; öyleyse öyle
yazılmayacak.

⚠ **Bu dosyanın kalıcı kuralı: Play Console davranışını ÇIKARIMLA yazma.**
Bu turda üç kez ezberden/çıkarımla Console kuralı yazıldı ve üçü de yanlış
çıktı (App content'in menü yeri iki kez, opt-in linkinin kapısı bir kez).
Yalnızca **görülen** şey, **tarihiyle ve o anki durumla** kaydedilir.

**App access'teki "tam erişim" kutusu ÖLÇÜLEREK işaretlendi:** ücretli/
premium içerik yok, ve **Android uygulamasında yönetici paneli YOK** —
`isAdmin` portta yalnızca `auth_service.dart`'ta ayrıştırılıyor,
`lib/src/ui/` altında hiçbir ekranı kilitlemiyor. Panel web'de yaşıyor,
Play'e giden pakette değil.

## 7. 12 tester + 14 gün

**Şart:** kapalı testte **en az 12 tester**, **kesintisiz 14 gün** kayıtlı.
Sayaç "yükledim" ile değil, **12 kişi opt-in olduğunda** işlemeye başlıyor.

| Tuzak | Ne yapmalı |
|---|---|
| Listeye eklemek YETMEZ | Her tester **opt-in bağlantısına tıklayıp kabul etmeli** |
| **Google tester'lara MAİL ATMIYOR** | Listeye eklemek yalnızca yetkilendiriyor; daveti geliştirici kendi kanalından gönderir |
| **Linke tıklayan otomatik katılmaz** | Liste bir izin listesi. Listede olmayan biri linkte "bu test sana açık değil" görür. |
| Link her zaman orada DEĞİL | 25 Ağustos'ta yoktu, 26 Ağustos'ta (liste 11 kişiyken, 372 incelemedeyken) vardı — §6.5'teki tablo. Kapısının ne olduğu ölçülmedi; görmüyorsan kanalda işlenmiş bir sürüm olduğundan emin ol |
| **İki ayrı link var** | *Join on Android* (Play uygulaması üzerinden) ve *Join on the web*. Kişiye telefonundaki Play hesabıyla açacağı için Android linkini vermek daha az aksaklık çıkarır |
| ⚠ **Linki DOĞRU KANALDAN kopyala** | *Internal testing* ve *Closed testing → Alpha* sayfalarının İKİSİNDE de aynı başlıklı "How testers join your test" bölümü var. Internal'dan kopyalanan link Play'de **"App not available — your account hasn't yet been invited to participate in this app's _internal testing_ program"** veriyor. **İpucu mesajın içinde: "internal" yazıyorsa yanlış sayfadasın.** 26 Ağustos 2026'da ölçüldü, doğru sayfadan kopyalanınca çalıştı |
| ⚠ **Mağaza adresini ELLE yazma** | `play.google.com/store/apps/details?id=com.kelimeki.kelimeki` herkese açık vitrin adresi; production sürümü olmadığı sürece (Dashboard: *Production: Inactive*) **404** veriyor — "istenen URL bu sunucuda bulunamadı". Bu bir yetki/tester sorunu DEĞİL, sayfanın hiç var olmaması. Her zaman **Copy link** kullan |
| Adres, kişinin TELEFONUNDAKİ Play hesabı olmalı | En sık aksaklık: iş adresi verilir, telefonda başka Gmail açıktır. Sorulacak soru "hangi adresi istersin" değil, "telefonunda hangi hesap açık" |
| Biri çıkarsa sayaç kırılır | **15-20 kişi topla**, 12 tabandır |
| Adresler Google hesabı olmalı | Gmail ya da Google'a bağlı bir adres; şirket/okul adresi olabilir ama Play hesabı olmalı |
| Cihazdaki eski CI `.apk` | **Tester'lar için sorun değil** — kimseye `.apk` gönderilmedi (§5). Yalnızca geliştirme cihazında var |
| Production başvurusu geri bildirim soruyor | Tester'lardan **yazılı geri bildirim topla** — başvuruda "nasıl test ettirdin" sorusu var |
| **Play'den kuran testerda `kelimeki.com` linkleri UYGULAMAYI açar** | 25 Ağustos 2026'dan beri beklenen davranış (`assetlinks.json` yayında, §6.6). Tarayıcıda açmak isteyen Ayarlar → Uygulamalar → Kelimeki → *Varsayılan olarak aç*'tan kapatabilir. CI `.apk`'sında GEÇERSİZ — o derleme farklı anahtarla imzalı |

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

### DNS'in ÖLÇÜLEN hâli (25 Ağustos 2026, GoDaddy panelinden okundu)

**14 kaydın tamamı sayıldı. İki beklenen kayıt YOK: `SPF` ve `MX`.**

| Ne | Durum | Kayıt |
|---|---|---|
| DKIM (Brevo) | ✅ | `brevo1._domainkey` / `brevo2._domainkey` → `b1/b2.kelimeki-com.dkim.brevo.com` (CNAME) |
| DMARC | ✅ | `_dmarc` TXT → `v=DMARC1; p=none; rua=mailto:rua@dmarc.brevo.com` |
| Brevo domain doğrulaması | ✅ | `@` TXT → `brevo-code:8d3dc…` |
| Brevo izleme/return-path | ✅ | `mail`, `r.mail`, `img.mail` CNAME → `*.brevosend.com` |
| Search Console | ✅ | `@` TXT → `google-site-verification=…` |
| Vercel | ✅ | `A @ 216.198.79.1`, `www` CNAME → `*.vercel-dns-017.com` |
| **SPF** | ❌ **YOK** | — |
| **MX** | ❌ **YOK** | — |

⚠ **Kök `CLAUDE.md` bu konuda YANILTICIYDI** ve düzeltildi: 20 Temmuz 2026
notu *"verilen SPF/DKIM/DMARC DNS kayıtları domain'in DNS'ine girildi"*
diyor; DNS'in kendisi SPF'in hiç girilmediğini söylüyor. Bu cümleye
dayanarak bu dosya üç tur boyunca var olmayan bir kaydı "birleştirmek"
üzerine uyarı yazdı — **kaydı okumadan kayda güvenmenin bedeli.**

**Brevo neden yine de çalışıyor:** DMARC, SPF **veya** DKIM'den biri
hizalanırsa geçer. DKIM kurulu ve `kelimeki.com` adına imzalıyor → geçiyor.
Brevo'nun zarf adresi (Return-Path) kendi domaininde olduğundan kök SPF'e
zaten bakılmıyor — `mail`/`r.mail` CNAME'lerinin `brevosend.com`'a gitmesinin
sebebi bu.

### Kuruluma etkisi

1. **MX boş** → Zoho'ya çevirirken yerinden edilecek bir şey yok. Aynı
   zamanda `destek@kelimeki.com`'un bugün gerçekten hiçbir şey almadığının
   (mailin bounce ettiğinin) kanıtı.
2. **SPF birleştirilmeyecek, İLK KEZ oluşturulacak.** Brevo'yu da içine
   koy — bugün gerekmiyor ama return-path yapılandırması değişirse ya da
   biri Brevo SMTP'sinden `@kelimeki.com` zarfıyla gönderirse bedava
   sigorta:
   ```
   v=spf1 include:spf.brevo.com include:<zoho'nun verdiği> ~all
   ```
   `~all`, `-all` DEĞİL — bilinmeyen bir gönderici sert reddedilmesin.
   **Kural yine de geçerli: TEK bir SPF kaydı.** İkinci bir TXT açılırsa
   `PermError` olur ve o noktadan sonra hiçbir SPF kontrolü geçmez.
3. **DKIM çakışmaz** — Zoho kendi selector'ını ekler, `brevo1/2` yerinde
   kalır.
4. **DMARC'a dokunulmaz.** `p=none` (izleme modu) olduğu için geçiş
   sırasında bir şey kırılsa bile mailler reddedilmez — rahat bir zemin.
5. ⚠ **`mail` adlı bir CNAME ZATEN VAR** (Brevo'nun). Zoho kurulumu `mail`
   adlı bir kayıt isterse çakışır; o durumda Zoho'nun alternatif adı
   kullanılacak.

### KURULDU — as-built (25 Ağustos 2026)

**Sağlayıcı: Zoho Mail, AVRUPA veri merkezi** (`mailadmin.zoho.eu`). Veri
merkezi seçimi MX ve SPF değerlerini belirliyor — `.com` sürümünün değerleri
BU KURULUMDA GEÇERSİZ.

**Hesap:** tek kullanıcı = `destek@kelimeki.com` (Super Administrator).
Koltuk sayısı 1 olduğundan başka bir adres kullanıcı olarak açılmadı.

**GoDaddy'ye eklenen kayıtlar:**

| Tip | Ad | Değer | Öncelik |
|---|---|---|---|
| TXT | `@` | `zoho-verification=zb36282039.zmverify.zoho.eu` | — |
| MX | `@` | `mx.zoho.eu` | 10 |
| MX | `@` | `mx2.zoho.eu` | 20 |
| MX | `@` | `mx3.zoho.eu` | 50 |
| TXT | `@` | `v=spf1 include:zohomail.eu include:spf.brevo.com ~all` | — |
| TXT | `zmail._domainkey` | Zoho'nun ürettiği DKIM anahtarı | — |

⚠ **SPF satırı Zoho'nun önerdiğinden FARKLI.** Zoho `v=spf1
include:zohomail.eu ~all` diyordu; Brevo'nun include'u elle eklendi. Sebebi
§ başındaki ölçüm: domainde SPF hiç yoktu, yani bu kayıt ilk kez
oluşturuluyordu ve **tek** olabileceğinden Brevo baştan içine alınmalıydı.
Bu satırı bir daha düzenleyen olursa `include:spf.brevo.com`'u silmesin.

**`noreply@kelimeki.com` — alias DEĞİL, GRUP.** Zoho'nun alias ekranı
bulunamadı; aynı sonucu veren Group özelliği kullanıldı: `noreply@` adında
bir grup, tek üyesi `destek@`. ⚠ **"Who can send emails to the group?" =
`Everyone`** — varsayılan `Organization Members` bizim yakalamak istediğimiz
maillerin TAMAMINI (dış adreslerden gelen kullanıcı cevapları) reddederdi.
Streams kapalı, moderatör yok. Gruplar kullanıcı koltuğu harcamıyor.

**Gönderen adı — ÖLÇÜLDÜ, ilk deneme işe yaramadı.**
`accounts.zoho.eu` → Profile → **Display Name** alanı `Kelimeki Destek`
yapıldı ama giden mailin `From` başlığına YANSIMADI (Gmail'de ham başlıkla
doğrulandı: hâlâ tam ad görünüyordu). Çözüm: yönetim konsolundaki kullanıcı
**First/Last Name** alanları değiştirildi. Zoho'nun hesap kurtarması
e-posta/telefon/MFA üzerinden çalıştığından isim alanını markaya çevirmenin
maliyeti yok.

**Ölçüm tuzağı (bir tur kaybettirdi):** ilk test maili iPad'in Mail
uygulamasına atıldı ve gönderen adı yanlış göründü — ama Apple Mail,
adresi Kişiler'de bulursa `From` başlığındaki adı DEĞİL kişi kartındaki adı
gösteriyor. **Gönderen adı/kimlik doğrulaması yalnızca ham başlıktan
okunur:** Gmail → "Orijinali göster".

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

### Testler

| | Ne | Sonuç |
|---|---|---|
| A | Dış adresten `destek@`'a mail | ✅ geldi |
| B | Dış adresten `noreply@`'a mail (grup) | ✅ aynı kutuya düştü |
| C | `destek@`'tan dışarı mail + gönderen adı | ✅ gidiyor; ad düzeltildikten sonra `Kelimeki Destek` |
| D | **Brevo regresyon** — kayıt onayı/şifre sıfırlama maili hâlâ PASS alıyor mu | ✅ **SPF PASS · DKIM PASS (`kelimeki.com`) · DMARC PASS** |

**D neden önemli:** domaine bugün **ilk kez** bir SPF kaydı yazıldı.
Öncesinde kayıt yokken Brevo'nun mailleri SPF kontrolünden nötr geçiyordu;
artık bir kayıt var ve alıcılar ona bakacak. `include:spf.brevo.com` tam bu
yüzden eklendi ama **ölçülmeden "doğru yaptık" denemez** — bu proje 20
Temmuz 2026'da tam olarak bu zincir bozulduğu için bir teslimat sorunu
yaşadı.

**D nasıl okundu (25 Ağustos 2026):** `kelimeki.com`'dan bir Gmail adresine
şifre sıfırlama istendi → Gmail → "Orijinali göster". Sonuç:

```
From:  Kelimeki <noreply@kelimeki.com>
SPF:   PASS with IP 77.32.148.26
DKIM:  'PASS' with domain kelimeki.com
DMARC: 'PASS'
```

Üçü de geçti — yani yeni SPF kaydı Brevo'nun zincirini KIRMADI ve
`include:spf.brevo.com`'u eklemek doğru karardı. (Gmail'in özetinden SPF'in
hangi domain üzerinde koştuğu okunamıyor; sonucu değiştirmediği için
önemsiz.) Sorun sayılacak tek şey DKIM ya da DMARC'ın FAIL olmasıydı.

### ⚠ Bu iş 14 günlük sayacı BEKLETMEMELİ

Mağaza iletişim e-postası **sonradan değiştirilebilir**. DNS/mail kurulumu
bir güne yayılırsa, kapalı testi başlatmak için oraya geçici olarak
alabildiğin bir adres yaz ve `destek@` hazır olunca değiştir. Kritik yolda
duran tek şey **12 tester**, bu değil.
