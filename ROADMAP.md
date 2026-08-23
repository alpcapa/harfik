# Kelimeki — Sıradaki İşler (22 Ağustos 2026)

**Bu dosya bir FİKİR LİSTESİ DEĞİL, sıralı bir yürütme planı.** Kök
`CLAUDE.md`'deki "Sonraya Bırakılan Ürün Fikirleri" bölümü *ne* yapılacağını
ve *neden* ertelendiğini anlatır; burası *hangi sırayla*, *hangi modelle* ve
*hangi tuzaklara dikkat ederek* yapılacağını anlatır.

Bir madde bitince buradan SİLİNİR ve kaydı ilgili bölümün kendi tarihli
notuna taşınır (projenin genel "değişiklik = tarihli not" disiplini).

**Durum (22 Ağustos 2026):** `main` yeşil. FAZ A1 cihaz turu Bölüm 6
(Paylaşma, iPad popover) hariç kapalı. Web + port paritesi güncel.
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
| 0.A4 | 🟨 **YARISI BİTTİ** (23 Ağu 2026) | `marketing/play-store/` | İkon (512) + öne çıkan görsel (1024×500) + başlık/kısa/tam açıklama üretildi (`npm run generate-play-assets`). **Kalan: telefon ekran görüntüleri** — gerçek cihazdan alınacak, çekim listesi `marketing/play-store/metin.md`'de |
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

**İlk yüklemede OKUNACAK, hâlâ ölçülmedi:** `targetSdk` (stable kanalın
varsayılanı; Play'in asgarisinin altındaysa pinle) ve `image_picker`'ın
birleşmiş manifeste eklediği izinler (Data safety beyanını etkiler).
İkisini de Play Console yükleme ekranı gösteriyor.

Sıradaki: **0.A4** (vitrin) → ilk `.aab` yüklemesi → 12 tester.

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

**Tuzaklar — 0.A2/0.A3:**
- `targetSdk` bugün `flutter.targetSdkVersion`'dan geliyor
  (`build.gradle.kts:23`), yani stable kanalın varsayılanı — **ölçülmedi.**
  İlk AAB üretilince gerçek değeri oku; Play'in yeni uygulamalar için
  dayattığı asgari seviyenin altındaysa açıkça pinle.
- `image_picker`'ın birleşmiş (merged) manifeste eklediği izinleri ilk
  AAB'de **oku** — beklenmeyen bir medya izni Data safety beyanını da
  değiştirir.
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

### 0.B — 14 gün işlerken paralelde

Sırası önemli olan tek bağ: **#4, #2'den SONRA** (hesap silme kaskadı
çıkmadan test hesaplarını silmek aynı analizi iki kez yaptırır).

1. **Madde 2 — uygulama içinden hesap silme.** Play'in hesap açtıran
   uygulamalardan istediği İKİ şey var: uygulama içi yol **ve** Data
   safety formuna girilecek bir **web silme talep URL'i** (ölçüldü, ikisi
   de politika metninde açık). **Web yarısı 0.A5'in sayfasına bir bölüm
   olarak bedavaya geliyor; asıl iş uygulama içi yol ve silme kaskadı.**
   Bu, production erişimi için ZORUNLU — 14 günün içinde bitmeli.
3. **Madde 1 — deep link + `assetlinks.json`.** Play blokeri değil ama
   kayıt onayı maili uygulamayı değil web'i açıyor; inceleme "kırık akış"
   diye dönebilir. iOS yarısı Apple hesabı istediğinden bekler.
4. **0.C — App content formları** (aşağı).
5. **Madde 4 — test hesaplarının silinmesi.** ⚠ **App access formuna
   verilecek inceleme hesabını silme** — hangi hesabın incelemeciye
   verildiğini silmeden önce kontrol et.

### 0.C — Play Console'da doldurulacak formlar (kod işi değil, zorunlu)

- **Data safety — en dikkatli iş.** Beyan ile gerçek ayrışırsa askıya alma
  sebebi. Toplananlar: e-posta, ad/soyad, takma isim, cinsiyet, doğum
  tarihi, profil fotoğrafı, **oyun içi mesajlar**, anonim cihaz kodu
  (`anon_id`), hata telemetrisi (`client_errors`), ziyaret/oyun başlangıç
  olayları. **Kaynak metin hazır:** `PrivacyModal`'ın "Toplanan Veriler"
  bölümü satır satır forma eşlenmeli. Üçüncü taraflar: Supabase, Brevo,
  Vercel (19 Ağustos'ta politikaya eklendi).
- **Content rating (IARC):** kullanıcılar arası **sohbet var**, beyan
  edilmek zorunda (yaş derecesini yükseltir).
- **UGC / moderasyon:** sohbet olduğu için gerekiyor. Karşılayacak
  mekanizma ZATEN var — sessize alma, şikayet, hesap dondurma, admin
  paneli; yalnızca beyan edilecek.
- **App access:** Canlı oyun/arkadaş özellikleri giriş istiyor →
  incelemeciye **çalışan bir test hesabı** verilmeli (bkz. 0.B/5).
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
- ⬜ **En az 2 telefon ekran görüntüsü** (pratikte 4-6) — **gerçek
  cihazdan**; çekim listesi + gizlilik uyarıları aynı `metin.md`'de.
  Tablet desteği iddia edilecekse tablet görselleri de.
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
- Android: intent filter + `assetlinks.json` (Pages'ta barındırılacak).
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

## 10. Onaylanmamış hesap: hatırlat, sonra sil — **TASARIM KESİNLEŞTİ, YAZILACAK**

**Model: Opus 5, efor `high`.** Otomatik hesap silme geri alınamaz — Sonnet'e verme.

**Neden — 23 Ağustos 2026'da gerçek bir kullanıcıda gözlendi.** "Sel Sezer" kayıt
olurken e-postasını yanlış yazdı (`sel_eb@` yerine `sel_en@`), **47 saniye sonra**
doğru adresle tekrar kayıt oldu — ama takma adı `Sweetpain` az önce KENDİ ölü
hesabı tarafından kapılmıştı, `Sweetpain.` yazmak zorunda kaldı. (Aynı gün elle
çözüldü: boş hesap silindi, ad düzeltildi, üye 38 → 37.)

**Aynı e-posta ile iki hesap MÜMKÜN DEĞİL** (`users_email_partial_key`); mesele
takma ad rezervasyonu.

**Ölçüldü (23 Ağustos):** 37 üyenin **3'ü** hiç onaylanmamış, ikisi **26/28
gündür** öyle — bir daha asla onaylanmayacaklar ama adları (`H56`, `Cacan`)
süresiz rezerve. Onaylanmamış hesabı süpüren HİÇBİR mekanizma yok (iki cron
job'un ikisi de bildirim gönderiyor).

### Kesinleşen akış

| Zaman | Ne olur |
|---|---|
| 0. saat | Kayıt, onay maili gider (link **24 saat** geçerli) |
| ~20. saat | **Tek seferlik hatırlatma** — TAZE link + *"24 saat içinde tamamlamazsan hesabın silinecek"* |
| 48. saat | Hâlâ onaysızsa **hesap silinir**; e-posta ve takma ad serbest kalır |

**İlke: hatırlatma aralığı = linkin ömrü.** Böylece kutuda HER AN geçerli bir link
bulunur (0-24 ilk mail, 24-48 hatırlatma). İlk taslak 3 gün/7 gündü ve 24-72.
saatler arasında **ölü bölge** bırakıyordu — kullanıcı yakaladı.

**⚠ CRON SAATLİK OLMAK ZORUNDA.** Günlük bir iş ölü bölgeyi geri getirir: 12:00'de
kayıt olanı ertesi gün 11:00'de kontrol edersen henüz 23 saatlik olur, atlanır ve
hatırlatma 47. saatte gider — oysa ilk link 24. saatte ölmüştür. Hatırlatma ayrıca
erişkinlik eşiğinden (24s) BİRAZ ÖNCE (~20s) atılır ki iki linkin geçerlilik
aralığı üst üste binsin.

### ⚠⚠ OTP SÜRESİ 86400 — GERİ ALMA

`Email OTP expiration` 23 Ağustos 2026'da **3600 → 86400** (24 saat) yapıldı
(Dashboard → Authentication → Sign In / Providers → Email). **Bu şemaNİN
TEMELİ** — 1 saatte kalırsa hatırlatma maili neredeyse hep ölü link taşır.

Supabase bunu güvenlik denetiminde **`auth_otp_long_expiry` (WARN)** olarak
işaretliyor ve bu uyarı BİLİNÇLİ OLARAK kabul edildi. Ölçüldü: değişiklikten
önce denetimde bu uyarı YOKTU, sonra ÇIKTI. **Bir sonraki oturum `get_advisors`
çıktısını temizlemek için 3600'e geri çekmesin** — hatırlatma sessizce işlevsiz
kalır.

Bedeli dürüstçe: ayar paylaşımlı, **şifre sıfırlama linki de** 24 saat yaşıyor.
7 gün BU YÜZDEN reddedildi — "Require current password when updating" KAPALI
olduğundan (ölçüldü) link = tam hesap devralma yolu.

### Ölçülen teknik zemin (23 Ağustos, gerçek üretimde, geçici bir Edge Function ile)

Onaylanmamış bir hesap için yönetici `generateLink({type:'signup'})` çağrısı:
- taze `action_link` + `hashed_token` DÖNDÜRÜYOR (`verification_type: signup`);
- o jetonla doğrulama **oturum açıyor** (`oturumAcildi: true`) ve
  `email_confirmed_at`ı dolduruyor → **tek mail, tek tık, direkt içeri**;
- **kendi başına mail ATMIYOR** (çağrı **42 ms**, auth loglarında gönderim kaydı yok).
  Kesin kanıt gelen kutusu; test adresine giden "Hoş Geldiniz" maili BİZİM
  tetikleyicimizden geldi, onunla karıştırma.

**Yan bulgu:** o akış `notify-welcome` zincirini de tetikledi ve
`{"ok":true,"sent":true}` döndü — `TESTING.md` bölüm 12'de "gerçek gönderim test
edilmedi" diye duran madde böylece üretimde kanıtlandı.

**Yakalanan tuzak:** `admin.createUser` metadata'sız çağrılırsa
`profiles_first_name_not_blank` kısıtına takılıp `Database error creating new
user` verir — sunucudan hesap yaratan her kod ad/soyad göndermek zorunda.

### Yapılacaklar

1. `profiles`e damga kolonu (`confirm_reminder_sent_at`) — mükerrer hatırlatmayı
   engeller. Emsal: `welcome_email_sent_at` + `reminder_sent_at` deseni.
2. Tek Edge Function + **saatlik** cron: ~20 saatlikleri hatırlat, 48 saatlikleri sil.
   `verify_jwt: false` (cron çağırıyor) — **`deploy_edge_function`e bu değeri
   AÇIKÇA geç** (geçilmezse sessizce `true`ya döner, kayıtlı tuzak).
3. **Önce PROVA:** hiçbir şey silmeyen/göndermeyen, yalnızca "şunları yapacaktım"
   diye raporlayan sürüm. Liste birlikte görülüp açılır.
4. Silme guard'ı: onaysız + hiç giriş yapmamış + verisiz. (Teoride verisi olamaz —
   her yazma yolu oturum ister — ama otomatik silme geri alınamaz.)
5. `PrivacyModal`e saklama cümlesi + **portun `legal_modals.dart`ı AYNI PR'da**
   (`legal_text_test.dart` tarihleri karşılaştırıyor, bayat kalırsa mobil CI düşer).
6. Admin Üyeler tablosuna "onaylanmamış" filtresi (kullanıcı onayladı).

### Yazarken ölçülecek

Onaysız hesap dururken aynı e-postayla **yeniden kayıt** denenirse ne oluyor?
Supabase'in onay mailini yeniden göndermesi beklenir — öyleyse tamamen kendi
kendine işleyen ÜÇÜNCÜ bir kurtarma yolu var demektir. Varsayma, ölç.

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
