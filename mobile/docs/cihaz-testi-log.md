# FAZ A1 — Cihaz Testi Tur Günlüğü

> mobile/docs/'e taşındı (context split, 24 Ağustos 2026). Kaynak: 'FAZ A1 — Cihaz Testi Tur Durumu' bölümü.

## FAZ A1 — Cihaz Testi Tur Durumu (son güncelleme: 17 Ağustos 2026)

**Bu bölüm iki `TESTING.md`'nin BİLİNÇLİ olarak tutmadığı tek şeyi tutar:**
o dosyalar "bir ilerleme kaydı değildir, her sürüm öncesi baştan
koşulabilir" diyor ve bu doğru — ama o yüzden "bu turda nereye kadar
geldik?" sorusunun cevabı hiçbir yerde yazılı değildi ve yalnızca
konuşma bağlamında yaşıyordu. Bir oturum kapandığında kayboluyor, sonraki
oturum ya baştan çıkarım yapıyor ya da yapması gerektiğini hiç bilmiyor.

**Bu bir kalıcı "tik listesi" DEĞİL, TURA ÖZGÜ bir anlık görüntü.** Yeni
bir tam tur başladığında (yeni sürüm, büyük bir refactor) sıfırlanır.
Buradaki "✅", "bu turda koşuldu" demektir — "bir daha koşulmasın" değil.

### Bölüm bölüm (FAZ A1 = GitHub Pages web derlemesi, iPad Safari)

| Bölüm | Durum | Not |
|---|---|---|
| 0 · Derleme / ilk açılış | ✅ | FAZ A0 |
| 0.5 · Web ile yan yana görsel | ✅ | **17 Ağu'da (Blok 6) KAPANDI — bölümün TAMAMI koşuldu, sıfır bulgu.** Öncesi: birçok tur (Parça 29/33/37/56/72-80). **17 Ağu:** k-lig nokta boşluğu, avatar↔logo (kapatıldı), tahta filigranlarının puntosu/fontu + header avatar hizası (Parça 106), filigranların taşların altında kalması (Parça 107), Setup'taki parantezli puanın kaldırılması ve tahta↔raf boşluğu (ikisi web-only, port kanonik alındı) — **17 Ağu'daki bu kümenin TAMAMI aynı gün cihazda koşuldu ve geçti, sıfır bulgu.** Turdan iki YENİ web işi çıktı (Hesap Ayarları fotoğraf butonu: tam genişlik + kalın; raf başlığındaki swap aksiyon metninin kaldırılması) — **17 Ağu'da PR #282 ile `main`'e merge edildi**, deploy sonrası tek bir bakışla teyit edilecek |
| 1 · Oyun (offline çekirdek) | ✅ | Parça 15/20/21/22 buradan çıktı |
| 2 · Hesap (auth) | ✅ | **9-12 (deep link) FAZ B'ye ertelendi** |
| 3 · Bulut kayıtları | ✅ | 6/6 — Parça 29 |
| 4 · Biten oyun kayıtları / istatistik | ✅ | Parça 33; OHP çapraz kontrolü Parça 63 |
| 5 · Oyun geçmişi | ✅ | Parça 35, sonra 67/68 ek turlar; **17 Ağu: ağ hatası maddesi (Parça 90) de koşuldu** |
| 6 · Paylaşma | 🟡 | görsel düzeltmesi koşuldu (Parça 84); **iPad ankrajı (Parça 86) gerçek iPad ister → FAZ B** |
| 7 · Son Oynadıklarım | ✅ | 16 Ağu (Blok 7) |
| 8 · Dayanıklılık (uçak modu) | ✅ | 8.2/8.3/8.5/8.6 — Parça 43-46; 16 Ağu: uçak modunda ÇIK–GİR hamleyi siliyordu (Parça 105) → düzeltme **aynı gün cihazda doğrulandı** |
| 9 · Görüş Bildir | ✅ | **17 Ağu: bölümün TAMAMI koşuldu, sıfır bulgu** (Parça 48'in "kapatmak da formu açar" düzeltmesi dahil). "Üyelik teklifi → kayıt" ikinci turda gerçekten tamamlandı: `T4` açıldı, `signup_channel='form'`, ve misafirken oynanan oyun kuyruktan hesaba doğru işlendi (oyun 10:08, hesap 10:10 — `created_at` gerçek bitiş anını taşıdığından kayıt kronolojik doğru yere oturdu, `platform='app-web'`) |
| 10 · Arkadaşlar | ✅ | tamamı (11 Ağu) + moderasyon geri alma, iki yol (14 Ağu, Parça 91) |
| 11 · Canlı oyun | ✅ | 14 Ağu: davet/kabul + tahta koşuldu (Parça 95, 5 bulgu). **16 Ağu: mesajlaşma alt bölümünün 14 maddesi de koşuldu — hepsi geçti, sıfır bulgu** (Parça 11/100/102/104'ün doğrulama sınırları kapandı). **17 Ağu: ret + hesap değişimi de koşuldu — sıfır bulgu.** **17 Ağu akşamı: SQL isteyen son iki madde de koşuldu (süresi dolmuş davet + 48 saat sıra aşımı, iki dalıyla) — bölüm TAMAMEN kapandı, sıfır bulgu** |
| 12 · Hesap Ayarları | ✅ | avatar RLS + küçültme uçtan uca (Parça 82/83) |
| 13 · k-lig ödül & rütbe | ✅ | 12 Ağu (Parça 66) |

**FAZ B (gerçek native iOS/Android): HİÇ BAŞLAMADI** — ön koşulları bile
yapılmadı
> ⚠ **AŞILDI (4 Eylül 2026):** Android tarafı başladı ve büyük kısmı
> koşuldu — bu dosyanın sonundaki *"FAZ B — İLK GERÇEK CİHAZ TURU"*
> bölümüne bak. Aşağıdaki paragraf 17 Ağustos'un durumudur, tarihsel
> kayıt olarak bırakıldı.
 (imzalama anahtarı, Apple Developer üyeliği, `assetlinks.json`).
Oraya ertelenmiş bilinen maddeler: `kelimeki://` deep link'leri (davet +
şifre sıfırlama + kayıt onayı kanalı), paylaş sayfasının iPad popover
ankrajı (Parça 86), HEIC seçimi ve galeri izni reddi (Parça 87).

> **17 Ağustos 2026 — kayıt onayı deep link'inin YOKLUĞU cihazda bizzat
> gözlendi (bulgu değil, ertelemenin somut bedeli):** portta misafirken
> Görüş Bildir'den e-posta verilip üye olununca, onay e-postasındaki bağlantı
> doğal olarak `kelimeki.com`'u açtı — uygulamayı değil. Üstelik o sekmede
> BAŞKA bir hesap (T2) açık olduğundan kullanıcı önce onun oturumunu gördü.
> Elle app sekmesine geçip yeni hesapla giriş yapmak sorunu çözdü ve
> misafir kuyruğu bozulmadan hesaba işlendi. **Mağazaya çıkışta bu akış
> kabul edilemez** — FAZ B'de `kelimeki://` kanalı kurulunca yeniden
> koşulmalı.


> **17 Ağustos 2026 — Blok 5'in ilk bulgusu: misafir uyarısı YANLIŞ kabukla
> çiziliyordu.** Kullanıcı ekran görüntüsüyle bildirdi: *"çıkan popup
> başlıksız"* — kartın üstünde boş bir bant ve bir ayraç duruyordu.
> **Kök sebep kabuk seçimi:** web'de İKİ ayrı kabuk var (bkz.
> `dialog_shell.dart` başlığı) ve bu uyarı ortak `Modal.tsx`'i KULLANMIYOR;
> `Setup.tsx` içinde elle kurulmuş 384px'lik onay kartı
> (`max-w-sm`/`rounded-2xl`/`p-6`, ✕ köşede `absolute`). Port `KModal`a
> `title: ''` geçmişti — yorumunda niyet doğru yazılıydı ("web'de bu popup
> başlıksız") ama `KModal` başlık bandını boş başlıkla da çiziyor.
> **Düzeltme:** uyarı `KDialogCard`a taşındı; kabuğa opsiyonel bir `onClose`
> eklendi (✕ 28×28, kart kenarından 12px — web `top-3 right-3`; gövdeye
> web'in `pr-6`sı). `onClose` verilmeyen 8 kullanım yeri BİREBİR aynı kaldı
> (dolgu Container'dan çocuğa taşındı, görsel sonuç aynı). Regresyon testi:
> `setup_screen_test.dart` → *"misafir uyarısı KModal DEĞİL web onay kartını
> kullanır"*.
> **Ders:** bir modalı porta taşırken "web'de başlık var mı?" yetmez, önce
> **"web hangi kabuğu kullanıyor?"** sorulmalı — bu projede web'in iki
> kabuğu var ve biri ortak bileşen değil, ekranın kendi içinde.

### Cihaz turu GÖRMEMİŞ, biriken maddeler

Son iki günde düzeltme yapıldıkça listeye madde eklendi ama o maddeler
hiç koşulmadı. Bir sonraki tur bunlarla başlamalı:

- ~~**16 Ağustos (Parça 105) — veri kaybı:** uçak modunda var olan bir
  oyunu aç → hamle yap → çık → **listeyi beklemeden** tekrar gir~~ →
  **16 Ağustos'ta AYNI GÜN cihazda koşuldu ve GEÇTİ** (*"Kaydetti bu
  sefer. Çalışıyor."*), **17 Ağustos'ta regresyon olarak bir kez daha
  koşuldu ve teşhis satırındaki `bekleyen ?` ↔ `bekleyen 0` ayrımı da
  gözle doğrulandı.** Madde `TESTING.md` bölüm 8'de duruyor — **hızlı**
  koşulmalı, beklenirse liste tazelenir ve senaryo hiç oluşmaz.
- ~~**15 Ağustos (Parça 101):** "YAPAY ZEKA İLE" sekme rozeti = "Devam
  Edenler" alt sekmesinin rozetiyle aynı sayı~~ → **16 Ağustos'ta Blok 7
  turunda koşuldu.**
- ~~**15 Ağustos (Parça 100):** susturulmuş gönderende rozet ÇIKMALI (popup
  çıkmamalı)~~ → **16 Ağustos'ta iki platformda da koşuldu** (Parça 103
  turuyla birlikte); **4 kişilik "susturulmamış gönderende ikisi de
  çıkmalı" kontrolü de 16 Ağustos'ta mesajlaşma turunda koşuldu.**
- ~~**16 Ağustos (Parça 102/104):** sekiz diyaloğun web kartına çekilmesi
  (kabul butonu solda, mavi dolgu) + popup'ın zemin dokunuşuyla
  kapanmaması~~ → **16 Ağustos'ta mesajlaşma turunda koşuldu.**
- ~~**14 Ağustos (Parça 96):** çevrimdışı Canlı oyun — açılışta panel +
  hamlede açıklayıcı uyarı (iki platform)~~ → **16 Ağustos'ta Blok 7
  turunda koşuldu** (uçak modu adımlarıyla birlikte).
- ~~**16-17 Ağustos — kök `TESTING.md`'nin İKİ yeni admin bölümü hiç
  koşulmadı:** 9.10 + 9.11~~ → **17 Ağustos'ta koşuldu, ikisi de tamamen
  GEÇTİ** (PR #276 preview'ında, admin hesabıyla). Sıfır bulgu; tek çıktı
  bir ürün isteği oldu: 4 kişiliğe "İkincilik" kutusu (aynı gün eklendi).
  **9.10 bu yüzden yeniden koşulmalı** — YZ Dengesi artık 2 değil 3 kutu ve
  etiketler `Kazanma` → `Birincilik` oldu; bölümün YZ Dengesi maddeleri
  buna göre yeniden yazıldı.
- ~~**14 Ağustos (Parça 95) — Canlı turunun BEŞ düzeltmesi, hiçbiri cihazda
  teyit edilmedi:** boş taslakta OYNA (web Canlı) · gönderim hatasının
  görünmesi (iki platform, uçak modu) · sohbetin ön plana dönüşte
  tazelenmesi (iki platform) · oyun sonu → Oyun Geçmişi (port) ·
  "Çevrimdışı" rozetinin puntosu (web)~~ → **17 Ağustos'ta BEŞİ DE tek
  turda koşuldu, hepsi geçti, sıfır bulgu.** Sohbet tazelemesi bilerek İKİ
  YÖNDE denendi (web→port ve port→web) — kullanıcının ilk raporu tam da
  asimetrikti (bir yön çalışıyor, öteki çalışmıyordu), tek yön koşmak o
  hatayı bir kez daha kaçırırdı.
- ~~**14 Ağustos (Parça 90/92):** girişsiz başlatma uyarısı (bölüm 1) ·
  tahta altındaki "Nasıl Oynanır?" (bölüm 1, İKİ oyun ekranında da) ·
  OHP hizası + başlık ortalama (bölüm 4 ve kök bölüm 10) · ağ hatasında
  "yüklenemedi" mesajı (bölüm 5 ve kök 9.6)~~ → **17 Ağustos'ta DÖRDÜ DE
  koşuldu** (ağ hatası Blok 3'te, kalan üçü Blok 5'te). Tek bulgu misafir
  uyarısının yanlış modal kabuğuydu (yukarıdaki nota bkz.); OHP hizası ve
  başlık ortalama iki platformda yan yana doğrulandı. Kök **9.10** da yeni
  üç kutulu YZ Dengesi hâliyle yeniden koşuldu.
- ~~**17 Ağustos (Parça 106-107 + aynı bloğun web işi)**~~ → **KÜMENİN
  TAMAMI 17 Ağustos'ta iPad'de koşuldu ve GEÇTİ, sıfır bulgu:** tahta
  filigranlarının puntosu/fontu + katman sırası (port, Parça 106/107 —
  köşe rakamları ve X2 aynı boy/font, X3 hücreyi doldurmuyor, filigranlar
  taşların altında) · header avatarının dikey hizası (web, FOTOĞRAFLI
  hesapla) · Setup'ta parantezli puanın olmaması (web) · tahta↔raf
  boşluğu 40px (web porta uyduruldu) · raf başlığı üçlüsü ("7 harf" yok,
  ad BÜYÜK HARF değil, başlık↔taş 13px) · rafın altındaki aksiyon satırı
  (port, Parça 108 — TORBA dahil eşit yükseklik, 6px boşluklar).
  **106/107 için bu tur tek gerçek kanıttı** (Flutter SDK'sız yazıldılar,
  negatif eşleri kurulamamıştı). Aynı turda çıkan İKİ yeni web işi
  (Hesap Ayarları'ndaki fotoğraf butonu: tam genişlik + kalın; raf
  başlığındaki swap aksiyon metninin kaldırılması) **17 Ağustos'ta PR #282
  ile `main`'e merge edildi** — Vercel deploy'undan sonra tek bir bakışla
  teyit edilecek (`mobile/TESTING.md` 0.5).
- ~~**13 Ağustos (Parça 72-89):** içerik sütunu genişliği · GİRİŞ satırı
  konumu · logo altı yazı bloğu · harf aralığı · "+ Yeni …" butonu ve alt
  sekmeler · form alanları · avatarın YUVARLAK vurgusu · "Yükleniyor…"
  takılı kalmama · ActionSheet'te "Vazgeç" yokluğu · ağ hatasında sahte
  başarı yokluğu · "Sıra: X" bandının rengi/gölgesi~~ → **17 Ağustos'ta
  ON BİRİ DE koşuldu ve GEÇTİ, sıfır bulgu.** Bunlar dört gün boyunca
  birikmişti ve hepsi ölçülerek yazılmış (derlenmiş CSS + Chromium)
  düzeltmelerdi — cihaz turu hiçbirinde bir sapma bulmadı.

- **17 Ağustos (Parça 109) — YZ'nin sağ-alt köşe handikabı:** 2 kişilik
  bir oyunda YZ'nin İLK hamlesi artık evden sola/yukarı da uzayabilmeli
  (bkz. `mobile/TESTING.md` bölüm 1). Ölçüm boş tahtada yapıldı, gerçek
  oyun akışında gözle teyit edilmedi; ayrıca bu parçanın Dart yarısı
  Flutter SDK'sız bir oturumda yazıldığından `dart run test/run_all.dart`
  hiç koşulmadı — CI dışında kanıtı yok.

- **18 Ağustos (Parça 113-114) — yeni rütbe rozeti + içindeki yeni font
  (M PLUS Rounded 1c 800; harf TOFU olmamalı, iki platformda aynı
  görünmeli — özellikle Ç/Ş ve banner'ın `+1000`'i):** k-lig listesi (18px),
  Skor Kartı/oyuncu kartı başlığı (34px) ve kutlama/düşüş banner'ı (76px)
  artık dalgalı disk + kurdele; eski tırtıklı mühür hiçbir yerde kalmamalı,
  küçük rozette halka YOK, banner'ın rakamlı glyph'lerinde de yok. Web ile
  yan yana bak (iki dosya elle senkron). Parça yazılırken Flutter SDK
  olmadığından Dart yarısı yalnızca CI ile doğrulandı.

- **18 Ağustos (Parça 115) — mühür artık İSİMLERİN yanında, yedi yüzey:**
  hesap menüsü başlığı (18px) · Skor Kartı (20px) · oyuncu kartı (20px) ·
  Setup'taki hesap koltuğu (18px) · Arkadaşlar'ın ÜÇ sekmesi (18px) ·
  "+ Yeni Canlı Oyun" arkadaş seçici (18px) · oyun daveti katılımcıları
  (16px). Skor kartlarında artık İKİ mühür var (34px başlık + 20px isim),
  ikisi aynı kademeyi göstermeli. Ayrıca "puan bilinmiyor" ile "0 puan"
  ayrımı: liste açılırken bir an için herkesin yanında Çaylak BELİRMEMELİ,
  YZ/misafir koltuğunda mühür HİÇ olmamalı. Bu parça da Flutter SDK'sız
  bir oturumda yazıldı — Dart yarısının tek kanıtı CI.

- **19 Ağustos (kozmetik metin turu) — "Nasıl Oynanır?"ın Hızlı Başlangıç'ında
  üç madde web'de yeniden yazıldı, port AYNI PR'da birebir güncellendi:**
  bağlanma maddesinin parantezi sona alındı ("… bağlanmalıdır. (Senin veya
  rakibinin)"), bonus maddesi "ikiye, üçe" → **"ikiye veya üçe"**, TDK
  maddesine **"(Birkaç istisna dışında)"** eklendi. **`help_text_parity_test`
  bunu YAKALAMAZ** — o yalnızca bölüm başlıklarını ve madde ikonlarını
  karşılaştırıyor (kendi dosya başlığında "var olan bir paragrafın İÇİNDEKİ
  cümle değişimi" açıkça sınır olarak yazılı), yani cümle senkronu ELLE
  yapılmak zorunda. Aynı turda `kelimeki_core`'un `validator.dart`'ındaki
  yorum "sınır vergisi" → "bölge vergisi" olarak web'le hizalandı (kök
  `CLAUDE.md` → "Bölge vergisi" maddesindeki terminoloji notu: `sınır ihlali`
  EYLEM, `bölge vergisi` BEDEL — üçüncü bir terim üretme). Kod davranışı
  değişmedi. Bu parça da Flutter SDK'sız bir oturumda yazıldı — Dart
  yarısının tek kanıtı CI.
  Aynı turda Detaylı Kurallar'ın "Genel Bakış" paragrafındaki son cümle de
  iki tarafta birden netleştirildi: rakibin KELİMESİNE değmek tek başına
  vergi doğurmuyor, karar yalnızca BÖLGE temasına bakıyor (`validator`ın
  `computeInvasionSplit`i taşa değil `computeAllTerritories` kümelerine
  bakar) — yani hiçbir bölgeye ait olmayan izole bir rakip taşına bitişik
  oynamak ücretsiz.

- **19 Ağustos — isim yanındaki mühürler isme yaklaştı (kullanıcı isteği,
  web + port aynı PR):** sekiz yüzeyde de `SizedBox(width: 6)` → **4**
  (web `gap-1.5` → `gap-1`). Mühür BOYLARI (16/18/20) değişmedi. Yan fayda:
  `player_score_card_modal.dart` zaten 6px kullanıyordu ama web'in aynı
  yeri 8px'ti (ad+mühür+arkadaşlık ikonu tek `gap-2` kabındaydı) — web o
  turda ad+mühür için ayrı bir sarmalayıcı aldı, yani sessiz bir ayrışma
  kapandı. Mevcut testler mührün yalnızca ismin SAĞINDA olduğunu sınıyor
  (birebir piksel değil), o yüzden düşen bir test yok; ölçüm web tarafında
  yapıldı, Dart yarısının kanıtı yine CI.

- **19 Ağustos — hukuki metin denetimi, port AYNI PR'da:** web'in Kullanım
  Koşulları ve Gizlilik Politikası beş yerde koddan kopmuştu (takma ismin
  artık zorunlu olması; Brevo/Vercel'in aktarım bölümünde hiç anılmaması;
  var olmayan bir self-servis hesap silme vaadi; "Görüş Bildir" formunun
  toplanan veriler listesinde olmaması; Terms'in kapsam cümlesinde Canlı
  oyun + mesajlaşmanın eksikliği). Beşi de `legal_modals.dart`a birebir
  taşındı ve İKİ tarih de **19 Ağustos 2026** oldu — `legal_text_test.dart`
  yalnızca TARİH eşitliğini koruduğundan, portu güncellemeden web'i
  değiştirmek testi düşürürdü ama metni güncelleyip tarihi unutmak da
  ayrışmayı gizlerdi; ikisi birlikte değişmeli. **Hesap silme özelliği
  portta da YOK ve web için YAPILMAYACAK (kullanıcı kararı, aynı gün):**
  KVKK/GDPR uygulama içi silme butonu şart koşmuyor, talep üzerine silme
  yeterli. AMA Apple 5.1.1(v) ve Google Play'in veri silme şartı bunu
  hesap açtıran uygulamalarda ZORUNLU tutuyor — yani madde artık hukuki
  değil, **mağaza çıkışına bağlı bir port işi**; kaskad zinciri ve
  gerekçenin tamamı kök `CLAUDE.md` → "Sonraya Bırakılan Ürün Fikirleri".

- **19 Ağustos (Parça 116 + 117 + 118) — portun kendi ilk açılış tanıtımı
  (`IntroScreen`):** temiz kurulumda (uygulamayı sil/yeniden kur ya da
  site verisini temizle) Setup'tan ÖNCE dört sayfalık tanıtım çıkmalı;
  HİÇBİR sayfada atlama düğmesi OLMAMALI, tek çıkış son sayfadaki
  **"HEMEN OYNA"** ve ondan sonra tanıtım bir daha ASLA çıkmamalı
  (uygulamayı kapat-aç ile de). Setup'ın logo altındaki **"Tanıtım"**
  linki (yalnız MİSAFİRDE) her zaman açmalı ve o yol bayrağı
  DEĞİŞTİRMEMELİ (oradan açıp kapattıktan sonra uygulamayı yeniden
  başlat — tanıtım yine çıkmamalı). Footer'da üç madde (Kullanım
  Koşulları · Gizlilik Politikası · Paylaş — "Paylaş" MİSAFİRDE DE) ve
  altında "© Kelimeki" olmalı. Görsel: 2./3. sayfadaki 5×5 mini ızgaraların renkleri, son
  sayfadaki DOKUZ rütbe mührünün harfleri TOFU (boş kare) OLMAMALI (mühür
  fontu M PLUS alt kümesi — Parça 114'ün riski) ve dar bir ekranda dört
  rakam kutusu alt satıra sarmalı, "RenderFlex overflowed" çubuğu
  ÇIKMAMALI. **Parça 118 ile içerik BAŞTAN yazıldı, o yüzden bu madde
  eskisinden geniş:** 1. slaytta "Tahtaya bir bak" tahtası (gerçek oyun
  ekranıyla AYNI harf/hücre oranında, filigranlar taşların ALTINDA),
  2. slaytta DÖRT adım, 3. slaytta ALTI özellik kutusu (hepsi ikonlu,
  boş kare YOK), 4. slaytta DOKUZ rütbe. Dar ekranda yatay taşma da
  olmamalı. Üç parça da Flutter SDK'sız oturumlarda yazıldı — Dart
  yarısının CI dışında kanıtı yok.

- **20 Ağustos (Parça 119) — k-lig sırası artık SUNUCUDAN (`k_lig_siralama`):**
  k-lig listesindeki sıra numarası ile o oyuncunun Skor Kartı başlığındaki
  "#sıra" AYNI sayı olmalı — özellikle EŞİT PUANLI oyuncularda (kullanıcı
  webde bildirdi: aynı kişi listede 13., kendi kartında #10). Port artık
  sırayı listedeki indeksten türetmiyor, `LeaderboardRow.sira`yı okuyor;
  gerekçenin tamamı kök `CLAUDE.md` → `Leaderboard` bölümü. Cihazda
  kontrol: eşit puanlı iki oyuncunun sırası OHP'ye göre ayrışmalı (yüksek
  OHP üstte), listede görülen sıra o kişinin kartını açınca başlıkta AYNI
  çıkmalı, ve k-lig açıklamasında "Puanlar eşitse OHP yüksek olan üstte."
  satırı görünmeli. Skor Kartı'ndaki metrik etiketi de **"Ortalama Hamle
  Puanı (OHP)"** olmalı (dar ekranda kutuyu taşırmadan sarmalı). Flutter
  SDK'sız bir oturumda yazıldı — Dart yarısının CI dışında kanıtı yok.

- **20 Ağustos (Parça 120) — oyun sonu kartı:** bir oyunu sonuna kadar
  bitir; kartta en sağda **k-lig** sütunu olmalı (kazanan `+2`, 2 kişilikte
  ikinci `-`), teslim olan satırda **-2** k-lig sütununda durmalı (soldaki
  "Kalan" sütununda DEĞİL — kullanıcının karıştırdığı tam olarak buydu),
  ve uzun bir ad ("Yapay Zeka 1", 4 kişilikte) satırı sarmadan `…` ile
  kırpılmalı, hiçbir genişlikte kart taşmamalı. Alt satırdaki hamle sayısı
  etiketin yanında/ortalı olmalı. Flutter SDK'sız bir oturumda yazıldı —
  Dart yarısının CI dışında kanıtı yok.

Liste bir gün BOŞALIRSA öyle kalmasını bekleme: yeni bir düzeltme
yazıldığında buraya yine madde eklenmeli (kural değişmedi: yazıldığı gün
cihazda görülmemiş her düzeltme burada birikir).

~~**Özel uyarı — kök `TESTING.md` 9.6 ilk koşuşunda DÜŞTÜ**~~ →
**17 Ağustos'ta baştan koşuldu ve GEÇTİ** (negatif eşi dahil: admin →
Üyeler → sıfır oyunlu bir üyenin kartı → çevrimİÇİ boş liste normal mesaj
veriyor). Tur, kodda değil **belgede** bir hata çıkardı: 3. madde
çevrimdışı + boş önbellekte "yüklenemedi" bekliyordu, oysa aynı gün
eklenen çevrimdışı öneri (`offlineNode`) araya giriyor ve "Hemen oyun aç."
çıkıyor; ayrıca "Arkadaşınla → Son Oynananlar" çevrimdışı HİÇ
çizilmiyor (`LiveGamesTab`'ın `!online` dalı üç alt sekmeyi birden kısa
devre yapıyor), yani orada "eski liste kalmalı" beklentisi anlamsızdı.
Madde düzeltildi. **Bu, "koşulmamış madde bir şey kanıtlamaz"ın somut
örneği** — 14 Ağustos'tan 17 Ağustos'a kadar belge yanlıştı ve kimse
görmedi.

### Sıradaki tur için öneri

**Bölüm 11 KAPANDI** (17 Ağustos): üç turda bitti — davet/kabul + tahta
(14 Ağu, beş bulgu → Parça 95), mesajlaşma (16 Ağu, sıfır bulgu), ret +
hesap değişimi (17 Ağu, sıfır bulgu). Aynı turda Parça 95'in beş
düzeltmesinin hepsi de cihazda teyit edildi, yani **14 Ağustos'tan beri
biriken Canlı borcu tamamen kapandı.**

**17 Ağustos'ta DÖRT küme birden kapandı:** ağ hatası/offline (kök 9.6 +
mobil bölüm 5 + bölüm 8), Canlı (bölüm 11), Görüş Bildir (bölüm 9) ve —
akşam, Blok 5 + Blok 6 ile — Parça 90/92'nin kalanları ve **görsel yan
yana karşılaştırmanın TAMAMI (bölüm 0.5)**.

### FAZ A1'İN CİHAZ TURLARI BİTTİ (17 Ağustos 2026)

Koşulacak cihaz maddesi KALMADI ve **ortak SQL turu da aynı gün koşuldu**
(aşağıya bkz.). Geriye tek bir şey kaldı ve o da bir cihaz turu değil:

1. ~~Merge bekleyen iki web işi~~ → PR #282 ile `main`'de; ~~ortak SQL
   turu~~ → koşuldu (aşağı).
2. **FAZ B** (gerçek native iOS/Android) — ön koşulları hâlâ yapılmadı
   (imzalama anahtarı, Apple Developer üyeliği, `assetlinks.json`).
   Bölüm 6'nın 🟡'si de oraya bağlı (iPad paylaş ankrajı, Parça 86).
   **17 Ağustos 2026 — üçü de kapalı olduğu için gerçek tur ERTELENDİ**
   (kullanıcı kararı: Android cihaz yok, Apple üyeliği şimdilik
   aktifleştirilmeyecek). O gün yalnızca bir TRİYAJ yapıldı:
   `mobile/TESTING.md` → "Appetize triyajı" — hangi maddenin emülatörde
   gerçekten kanıtlanabildiği, hangisinin yalnızca yanlış güven vereceği
   madde madde ayrıldı. **Android imzalama anahtarı bilerek ÜRETİLMEDİ:**
   üretim anahtarı kaybedilirse uygulama Play Store'da bir daha asla
   güncellenemez, yani üretimi/yedeklenmesi hesap sahibinin kararı —
   `assetlinks.json` de onun SHA-256'sına bağlı olduğundan sırayla
   beklemede.

Şu an bilinen bir veri kaybı yolu YOK (Parça 105 aynı gün doğrulandı).

### Ortak SQL turu — koşuldu ve GEÇTİ (17 Ağustos 2026)

Bölüm 11'in kalan iki maddesi, satırların Supabase MCP ile geriye
tarihlenmesini gerektiriyordu; üç senaryo kurulup süpürme GERÇEK
uygulamadan (T1 → "Arkadaşınla") tetiklendi. Üçü de tahminlerle birebir
uyuştu:

| Senaryo | Ölçülen sonuç |
|---|---|
| Süresi dolmuş davet (`create_online_game` ile kurulan tek kullanımlık T1→T2, `created_at` −8 gün) | `online_games.status` → `abandoned`; `game_invites` satırı tasarım gereği `pending` kaldı, davet hiçbir kovada görünmedi |
| 2 kişilik sıra aşımı (T1↔T2, sıra T1'de) | Oyun `finished`/`end_reason='surrender'`; T1 skor 0 + raf torbaya (**70 → 77**, `bag_count` 77); T2 22 → 10 (kendi raf puanı düşüldü); `games` satırları T2 rank 1 win / T1 rank 2 lose+surrendered; T1 k-lig **10 → 8**, oyun sayısı 12 → 13; `net._http_response` **`{"ok":true,"sent":1}`** ve mail T1'in gerçek kutusuna ulaştı |
| 4 kişilik sıra aşımı (T1+T2+T3+YZ, sıra T3'te) | Oyun `active` KALDI; T3 teslim/skor 0/raf 0; sıra 2 → **3** (YZ koltuğu), tur 2 → 3, `turn_deadline` +48s; torba **65 → 72** ve `bag_count` **72**; **mail GİTMEDİ** |

**Bu tur İKİ eski doğrulama sınırını birden kapattı** (ayrıntı kök
`CLAUDE.md`): `notify-turn-timeout-surrender`ın pg_net → Edge Function →
Brevo zinciri bugüne dek yalnızca rollback'li bir simülasyonla
gösterilmişti; `check_turn_timeout_bag_count` düzeltmesinin kanıtı da
yalnızca migration'ın kendi backfill'iydi.

**Kurulum disiplini — bir daha koşulursa aynısı geçerli:** (a) test daveti
`create_online_game` RPC'siyle kuruldu, istemciden DEĞİL — davet e-postası
istemciden gönderildiğinden bu yol kimseye mail atmıyor; (b) **gerçek bir
kullanıcının bekleyen daveti ASLA kullanılmaz** (o turda üretimde tam da
öyle bir davet vardı ve süpürme onu da iptal ederdi) — kurulumdan sonra
"süresi geçmiş görünen satırların HEPSİ benim mi?" diye ayrı bir tarama
koşuldu; (c) tek kullanımlık davet doğrulamadan sonra silindi, iki gerçek
test oyunu ise (artık meşru birer oyun kaydı olduklarından) bırakıldı.

**İki dalı da koşmak ŞART, biri ötekini kanıtlamaz:** `bag_count` hatası
İKİ dalda da vardı ama yalnızca 4 kişilikte kullanıcıya görünüyordu; mail
ise yalnızca 2 kişilik dalda üretiliyor — tek dal koşmak, fonksiyonun maili
KOŞULSUZ gönderip göndermediğini de ayırt edemezdi.


---

## FAZ B — İLK GERÇEK CİHAZ TURU (4 Eylül 2026, Android)

Yukarıdaki bölüm 17 Ağustos'ta "FAZ B: HİÇ BAŞLAMADI" diyerek donmuştu.
Bu turla başladı ve büyük kısmı aynı gün koşuldu.

**Derleme:** `mobile-latest` prerelease'indeki `kelimeki.apk`, sha
`d07c06d`, sürüm 1.0.6. ⚠ Bu APK **debug anahtarıyla** imzalı: workflow
`key.properties`'i APK adımından SONRA yazıyor (yalnızca `.aab` için),
Gradle release'i `debug` imzasına düşürüyor. Sonucu: `assetlinks.json`'daki
parmak izi tutmaz, `https://kelimeki.com/...` bağlantıları tarayıcıda
açılır. **Bu bir arıza değil**; Play'e giden `.aab` başka bir anahtarla
imzalı olduğundan o davranış mağaza sürümünde değişecek.

### Koşulanlar

| Bölüm | Sonuç |
|---|---|
| §0 kimlik (`Derleme d07c06d` · `depo ok` · giriş girişi görünür) | ✅ |
| Geri tuşu / geri jesti — sekiz vaka | ✅ sıfır bulgu |
| §1.1/1.2 (bağlam yokken pencere çıkmamalı, T3 ile) · §1.3 · §1.5 · §1.6 | ✅ |
| §2.1–§2.5 token yaşam döngüsü | ✅ |
| §3.2 · §3.4 · §3b · §3d · §3e · §3f | ✅ |
| §3.1 + §3.1b (süre uyarısı bildirimi VE e-postası) | ✅ gün içinde, ayrıca |
| §3.3 soğuk başlangıç (bildirimden) | ✅ |
| Oturum kalıcılığı (öldür → simgeden aç) | ✅ |
| §2.6 hesap silme (T5) | ✅ *(kanıtın sınırı için aşağı bkz.)* |
| §4.4 `kelimeki://reset` şifre sıfırlama derin bağlantısı | ✅ 4 Eylül, sunucudan uçtan uca ölçüldü |
| Galeri izni reddi + HEIC avatarı | ✅ geçen hafta, gerçek cihaz |
| Sözlük yükleme SÜRESİ | ✅ geçen hafta, gerçek cihaz |
| Uçak modunda kelime anlamı | ✅ geçen hafta, gerçek cihaz |
| Paylaşma (gerçek hedef uygulamalarla) | ✅ 4 Eylül, yeniden koşuldu |
| Sürükle-bırak hissi (zoom açık/kapalı) | ✅ 4 Eylül, yeniden koşuldu |
| Geçmişten "Tekrar Oyna" (aynı gün eklendi) | ✅ 4 Eylül, sha `711eaaa` |

**Geri tuşu ilk kez sınandı.** `PopScope`/`WillPopScope` depoda HÂLÂ yok,
yani her şey Flutter'ın varsayılanına düşüyor; sekiz vaka da (Setup kökü,
yerel oyun, canlı oyun, modal, joker modalı, yeni mesaj popup'ı, ilk açılış
tanıtımı, kenar jesti ↔ taş sürükleme) doğru davrandı. ⚠ Kod okunarak
"yeni mesaj popup'ı `barrierDismissible: false` olduğu halde geri tuşuyla
kapanır" öngörülmüştü; **cihazda kapanmadı.** Öngörü ölçümü yenmedi.

**§2.5 — "cihazda doğrulama bekliyor" maddesi kapandı.** Doğru kurulum
tarif edildiği gibi değildi: 2.4'teki çıkış satırı zaten sildiğinden,
ardından gelen giriş UPDATE dalına değil temiz bir INSERT'e düşüyor ve
42501'in yaşandığı yol hiç sınanmıyor. Gerçek kurulum, satırın BAŞKA bir
kullanıcıya bağlı kalması: **uçak modunda çıkış yapıldı** (`signOut`
temizliği `try/catch` içinde yutuluyor — kodun kendi yorumu bunu zaten
bekliyor), sonra ağ açılıp ikinci hesapla girildi. Ölçüm: toplam satır
7'de kaldı, T3 0 · Ironman 1, ve `created_at` 08:16:15 ↔ `updated_at`
08:19:26 — **aradaki 3 dk 11 sn satırın silinip yeniden yaratılmadığını,
GÜNCELLENDİĞİNİ kanıtlıyor.** Delete+insert olsaydı sonuç yine "7 satır,
doğru sahip" görünecekti; bu ayrım olmadan madde yine kapanmış sanılırdı.

**Push ölçümü göz kararıyla değil sunucudan yapıldı.** `_notify_your_turn`
trigger'ı pg_net ile çağırdığından yanıt gövdesi `net._http_response
.content`te duruyor: `{"ok":true,"pushed":N}`. Turda üç kez ayırt edici
oldu — bir "gelmedi" vakasında `pushed: 1` çıkıp sorunun sunucuda
olmadığını gösterdi; §3.4'te bayrak kapatılınca 1 → 0 düştü; 10 dakikalık
bastırmanın kendisi de (hedefin O OYUNDAKİ son hamlesi ölçüt, genel değil)
çağrının hiç yapılmamasıyla doğrulandı.

**Gözlem (bulgu değil): uygulama ön plandayken bildirim tamamen sessiz.**
Kodda `FirebaseMessaging.onMessage` dinleyicisi YOK — yalnızca
`onMessageOpenedApp` ve `getInitialMessage`, yani *dokunma* yolları.
Android ön plandaki bildirim mesajını kendiliğinden göstermediğinden ekranda
hiçbir iz kalmıyor. `testing-bildirimler.md` §3d maddeyi zaten *"sen
uygulamada DEĞİLKEN"* diye tanımlıyor, yani kapsam dışı; ama bir turda
"bildirim gelmedi" diye yanlış teşhise yol açtı. Ön planda bir iz bırakmak
gerekip gerekmediği ÜRÜN kararı, açık bırakıldı.

**§3.3 geçti ve beklenmedik bir yoldan daha güçlü bir kanıt verdi.**
Uygulama tamamen kapalıyken bildirim düştü, dokunuldu — ama uygulama
GİRİŞSİZ açıldı ve Setup'ta kaldı. Giriş yapılınca **doğru oyun doğrudan
açıldı**, yani dokunuşun taşıdığı derin bağlantı araya bir giriş ekranı
girmesine rağmen KAYBOLMADI, auth bitene kadar kuyrukta tutulup sonra
tüketildi. Bu, düz bir soğuk başlangıçtan daha zor bir senaryo.

⚠ **Girişsiz açılış BULGU DEĞİL — ama teşhisi ölçmeden verilemezdi.**
Sunucu kaydı: 09:30:57'de `refresh_token_not_found` (400), 09:31:50'de
parola girişi, 09:31:53'te push token yeniden yazıldı. Kritik ayrım
`push_tokens.created_at`'in 08:16:15'te KALMASI: uygulama çıkışta bu satırı
siliyor (§2.4'te ölçüldü), silinmediğine göre kullanıcı çıkış YAPMAMIŞ —
yani oturum kendiliğinden düşmüştü. Bu noktada "oturum süreç ölümünden sağ
çıkmıyor" gibi görünüyordu, ki öyle olsaydı mağazaya çıkışı bloke ederdi.
**Doğrudan sınandı:** uygulama öldürülüp SİMGEDEN açıldı → girişli geldi.
Yani kalıcılık sağlam; 09:30'daki olay tek seferlik bir token
geçersizleşmesi, muhtemelen aynı hesabın (Ironman) test boyunca hem web'de
hem telefonda açık tutulmasından. **Bir sonraki tur bunu görürse önce
hesabın başka bir yerde açık olup olmadığına baksın**, oturum koduna değil.

**§2.6 geçti ama ölçüm sırası kaçtı — bu bir usul dersi.** T5 silindi;
`profiles`/`auth.users`/`push_tokens`/kendi 8 oyun kaydı sıfırlandı ve
sahipsiz token kalmadı. Ancak giriş ile silme TEK adımda yapıldığı için
silme öncesi token satırının var olduğu ölçülemedi — T5'in zaten baştan
token'ı yoktu, yani sonradan "satır yok" görmek tek başına hiçbir şey
kanıtlamıyor. Dolaylı kanıt güçlü (T5 09:40:55'te telefondan girdi, giriş
her seferinde token yazıyor, silme 09:41:55) ve kod koşulsuz, ama ölçüm
değil. Madde geçmiş sayıldı; ikinci bir test hesabını yakmak bedele
değmedi (kullanıcı kararı). **Genel kural: bir silme testinde ÖNCE var
olduğu ölçülür, SONRA silinir.** Silme fonksiyonu sildiği sayıları
döndürüyor ama hiçbir yere yazmıyor — sonradan bakılacak denetim izi yok.

**Emülatörün kanıtlayamadığı beş madde de kapandı — üçü geçen haftaki
gerçek cihaz turundan, ikisi bugün YENİDEN koşularak.** Triyaj tablosu
sürükleme akıcılığını, HEIC avatarını ve sözlük yükleme süresini
"emülatörde ölçülemez" diye işaretliyordu; hepsi gerçek telefonda koşuldu.

⚠ İkisi bilerek tekrarlandı, çünkü kullanıcının testinden SONRA kodları
değişmişti — kapatmadan önce dosya bazında bakıldı:
- `share_board.dart` 2 Eylül'de değişti (#422, "iPad'de asılı kalan
  paylaşım"), yani geçen haftaki paylaşma turu düzeltme ÖNCESİNİ ölçmüştü.
- Tahtanın dokunuş yüzeyi zoom'la sekiz commit'te yeniden yazıldı
  (#395/396/397/399/410/411/413/414) — sürükleme hissi tam o yüzeyde
  yargılanıyor.
`avatar_picker.dart` ve sözlük yükleme yolunda ise 27 Ağustos'tan beri
değişiklik YOK, o üçü tekrar koşulmadan kapatıldı.

**Kural olarak yazılıyor:** "daha önce koşmuştuk" bir maddeyi tek başına
kapatmaz — o maddenin DOKUNDUĞU dosyalar o tarihten beri değişti mi, önce
ona bakılır. Bu turda beş maddenin ikisi tam bu kontrolle yakalandı.

**Turun ortasında eklenen özellik AYNI TURDA cihazda doğrulandı.** Kullanıcı
oyun geçmişindeki aksiyon menüsüne "Tekrar Oyna" istedi (o sırada yalnızca
Paylaş/Kapat vardı); özellik yazıldı, `711eaaa` ile merge edildi, APK
tazelendi ve aynı oturumda telefonda koşuldu: menü üç maddeli geldi, davet
gönderildi ve sunucuda `pending` bir 2 kişilik oyun oluştuğu ölçüldü
(11:47:05). Yani bu madde hiç "bir sonraki tura" devredilmedi — bugünün
dersinin (kayıt bayatlarsa turu KULLANICI tekrar koşar) doğrudan uygulaması.

⚠ Not: rövanş gerçek bir kullanıcıya (test hesabına değil) davet gönderdi.
Bu maddeyi bir daha koşarken karşı tarafı T2/T3 gibi bir test hesabı seç —
aksi halde gerçek bir oyuncuya bildirim ve e-posta gidiyor.

⚠ **§3.1 önce ERKEN ✅ yazılmıştı, sonra gerçekten kapandı — ayrım önemli.**
Turun ortasında "bildirim geliyor" maddesi geçmiş sayılmıştı, oysa o gün
ölçülen şey **§3d**'nin "Sıra sende!" push'uydu (`notify-your-turn`). §3.1
ise 24 saate yaklaşan sıra için `notify-deadline-warnings`'ün gönderdiği
AYRI bir uyarı. İkisi farklı kanal; biri çalışıyor diye öteki kanıtlanmış
olmuyor. Madde gün içinde gerçek uyarı düşünce kapandı ve **§3.1b** (aynı
uyarının e-postasında "takdirde" yazımı) de aynı anda doğrulandı — o zaten
yalnızca bu e-posta geldiğinde koşulabilen bir maddeydi.

⚠ **`testing-bildirimler.md`'nin KUTULARI ile bu günlüğün TABLOSU ayrışmıştı.**
Gün içinde geçen maddeler buradaki tabloya yazıldı ama asıl kontrol
listesinde işaretlenmedi; kullanıcı fark etti. Bir sonraki tur o listeyi
açık görüp maddeleri yeniden koşacaktı — yani bu, günün dersinin ta
kendisinin ikinci kez tekrarlanması olurdu. İkisi aynı turda eşitlendi.
**Kural: bir madde geçtiğinde işareti KONTROL LİSTESİNE düşülür; bu günlük
turun anlatısıdır, kaydın kendisi değil.**

### Koşulmayanlar ve sebebi

- **§1.4** ("ŞİMDİ DEĞİL" dalı) — 1.5 ile birbirini tüketiyor ve bu turda
  1.5 seçildi. **§1.5 ise gün içinde KOŞULDU ve geçti:** §2.2'de bildirimler
  sistem ayarlarından kapatıldığı için izin durumu sıfırlanmış, pencere
  yeniden çıkmış ve "BİLDİRİMLERİ AÇ" Android'in kendi diyaloğunu açmıştı.
  Kullanıcı bunu önce fazlalık sandı (*"ayrıca Android izin ver/verme
  dialogu çıkıyor"*) — iki adım TASARIM GEREĞİ: sistem diyaloğu ikinci
  retten sonra kalıcı olarak kaybolduğundan uygulama önce kendi yumuşak
  penceresiyle soruyor. §1.4 Play kapalı testinin temiz kurulumunda
  koşulacak; o kurulum §4.1'i de karşılıyor.
- **§3.1b** (uyarı e-postasında "takdirde") — 24 saate yaklaşan bir sıra
  penceresi gerektiriyor, planlanamıyor.

### DERS: tur tekrarlandı, çünkü KAYIT bayattı

Kullanıcı turun sonunda söyledi: *"bu testlerin çoğunu zaten yapmıştık.
Muhtemelen senin dosyalar güncel değildi ama yine de bilerek bir tur daha
katlandım emin olmak için."*

Doğrusu buydu. Bu dosya 17 Ağustos'ta donmuştu ve FAZ B'yi "HİÇ BAŞLAMADI"
gösteriyordu; `testing-bildirimler.md` §2.5 hâlâ "cihazda doğrulama
bekliyor" diyordu. Kayıt bayat olduğunda maliyeti bir sonraki oturum
ödemiyor — **kullanıcı ödüyor**, bir turu ikinci kez koşarak.

Kök `CLAUDE.md`'nin "her tamamladığın işten sonra ilgili dosyaları
güncelle" kuralının bu dosyadaki karşılığı şu: **bir cihaz maddesi
geçtiğinde kaydı AYNI oturumda düşülür.** Turun sonuna bırakılırsa oturum
sıkıştırma yer ve ölçümler özete iner; "sonra toplarım" bu dosyada iki kez
denendi, ikisinde de tutmadı.
