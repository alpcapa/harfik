# Cihaz Testi — Push Bildirimleri, Derin Bağlantılar ve Güncelleme

> (Parça 158; 30 Ağustos 2026'da Parça 171 ile "Güncelleme" bölümü eklendi.)

> `mobile/TESTING.md`'den AYRI bir dosya, çünkü buradaki maddelerin
> ÇOĞU **Play kanalından kurulmuş, imzalı bir derleme** istiyor — CI'nın
> debug-imzalı `.apk`'sı bu bölümün yarısını yapısal olarak doğrulayamaz.
> Kesme noktası boyut değil kurulum TÜRÜ (kök `CLAUDE.md` → "Doküman
> Boyutu Bütçesi" kuralı).

## Hangi derlemede ne test edilebilir

| Madde | CI `.apk` (debug imza) | Play kapalı test (`.aab`) |
|---|---|---|
| Bildirim izni penceresi / sistem diyaloğu | ✅ | ✅ |
| Bildirimin GERÇEKTEN düşmesi (FCM) | ✅ | ✅ |
| `kelimeki://…` derin bağlantıları | ✅ | ✅ |
| `https://kelimeki.com/…` App Links | ❌ tarayıcıda açılır | ✅ |
| Kayıt onayı → doğrudan girişli kalma | ❌ | ✅ |
| **Play In-App Update (açılışta güncelleme)** | ❌ Play tanımaz | ✅ |

⚠ `.apk`'da App Links'in tarayıcıda açılması **bir hata değil**:
`assetlinks.json` Play'in imza parmak izini taşıyor, debug derlemesi başka
bir anahtarla imzalı. Doğrulanması gereken şey o durumda "çirkin bir hata
ekranı ÇIKMAMASI" (bkz. 3.2).

## 0. Kurulum — atlanırsa geri kalan her şey şüpheli

Yanlış derlemeyi test etmek bu projede iki kez gerçek zaman yaktı; derleme
kimliğinin ürüne gömülme sebebi bu (kök `CLAUDE.md` → "Deploy Doğrulaması").

- [ ] **0.1 Play'den kurulu sürümü kaldır.** İmza farklı olduğu için `.apk`
      üstüne kurulmaz. Kaldırma yerel kayıtları ve push token'ını da siler —
      bu zaten §1'in istediği el değmemiş durum.
- [ ] **0.2 `kelimeki.apk`'yı `mobile-latest` prerelease'inden indir ve kur.**
- [ ] **0.3 Setup'ın teşhis satırındaki sha'yı, test ettiğini sandığın
      derlemeyle KARŞILAŞTIR** (`Derleme a1b2c3d · GG.AA SS:DD`).
      Tutmuyorsa teste devam etme — bayat derlemedesin.

## 1. Bildirim izni akışı

Tetikleyici bilerek açılış/giriş DEĞİL: **Canlı sekmesi açıldı VE en az bir
aktif oyun ya da bekleyen davet var.** Gerekçe: Android 13+'ta ikinci
reddin ardından sistem diyaloğu bir daha HİÇ gösterilmiyor.

⚠ **1.1 ve 1.2 GİRİŞLİ yapılır** (29 Ağustos 2026'da netleşti; iki kez
boşa denendi — önce oyunu ÇOK olan bir hesapla, sonra misafirken).
Tetikleyici `_reload()`'un içinde ve `user.id` istiyor
(`live_games_tab.dart:245`), yani **misafirken o koda hiç ulaşılmıyor**:
girişsiz bir tur "pencere çıkmadı" der ama sınamak istediğimiz dalı
(`aktifOyunVar == false`) hiç çalıştırmaz. Hesap seçimi de şart — hiç aktif
oyunu/daveti OLMAYAN bir test hesabı gerekiyor (SQL ile bak:
`online_games` içinde `slots`ta o kullanıcı geçen `active`/`pending` satır
var mı).

- [ ] **1.1 Bağlamsız açılış.** GİRİŞ YAP, Canlı sekmesine GİRME → hiçbir
      izin penceresi çıkmamalı (ne bizimki ne sistemin).
- [ ] **1.2 Boş Canlı sekmesi.** Aynı (oyunsuz) hesapla Canlı sekmesini aç →
      yine hiçbir pencere çıkmamalı.
- [x] **1.2-misafir** (29 Ağustos 2026): girişsiz Canlı sekmesi → pencere
      YOK. Geçti, ama yukarıdaki nedenle 1.2'nin YERİNE geçmez.
- [ ] **1.3 Gerçek tetikleyici.** Bir Canlı oyun başlat (ya da bir davet
      al), Canlı sekmesini aç → **"Bildirimleri açalım mı?"** penceremiz
      çıkmalı; "BİLDİRİMLERİ AÇ" / "ŞİMDİ DEĞİL".
- [ ] **1.4 "ŞİMDİ DEĞİL" sistem denemesi HARCAMAMALI.** Bas → sistem
      diyaloğu ÇIKMAMALI. Uygulamayı kapat-aç, Canlı sekmesini yeniden aç →
      pencere **hemen tekrar çıkmamalı** (7 gün aralık).
- [ ] **1.5 "BİLDİRİMLERİ AÇ".** Bas → **Android'in kendi** izin diyaloğu
      çıkmalı. İzin ver.
- [ ] **1.6 İzin verildikten sonra bir daha sorulmamalı.** Canlı sekmesine
      birkaç kez gir-çık → pencere çıkmamalı.
⚠ **1.4 ile 1.5 AYNI KURULUMDA İKİSİ BİRDEN YAPILAMAZ** (29 Ağustos 2026'da
fark edildi, sıra planlanırken): pencere tek seferlik bir karar soruyor —
"ŞİMDİ DEĞİL" dersen 7 günlük aralık başlar ve pencere geri gelmez (kural:
en çok 3 kez, 7 gün arayla — `push_rules.dart`), "BİLDİRİMLERİ AÇ" dersen
izin verilir ve pencere zaten bir daha çıkmaz (1.6). Yani ikisi birbirini
tüketiyor.
**Pratik sıra:** bu turda **1.5**'i seç (izin ver) — 2. ve 3. bölümlerin
TAMAMI izin verilmiş olmayı gerektiriyor. **1.4** ayrı bir kurulumda test
edilir: uygulamayı kaldırıp kurmak bizim 7 günlük bayrağımızı sıfırlar
(SharedPreferences gider). ⚠ Android'in KENDİ ret sayacı kaldırmayla
sıfırlanmayabilir — 1.4'ü ayrı turda yaparken sistem diyaloğunun hiç
çıkmaması bu yüzden olabilir, bunu bir hata sanma.

- [ ] **1.7 Android 12 ve altı** (varsa bir eski cihaz): sistem diyaloğu
      diye bir şey yok; bizim penceremiz çıksa bile "Aç" sessizce başarılı
      sayılmalı, çökme/uyarı OLMAMALI.

## 2. Token yaşam döngüsü (`push_tokens`)

DEĞİŞMEZ: **tabloda satır varsa o cihaz bildirim GÖSTEREBİLİR.**

⚠ Bu cümlenin İKİNCİ yarısı 28 Ağustos 2026'ya kadar *"her açılışta kendini
onarır — ayrı bir dinleyici yok"* diyordu ve **YANLIŞTI**: hizalama yalnızca
Canlı sekmesinin `_reload()`'una bağlıydı, o da liste yüklemesi düşerse erken
dönüyordu (Parça 159, ilk gerçek cihaz testinde bulundu). Artık üç yerden
tetikleniyor — **açılış · öne dönüş (`resumed`) · oturum değişimi**
(`_HomeGate`, `app.dart`). Aşağıdaki 2.2-2.5 tam olarak bu üç yolu sınıyor;
"nasılsa kendini onarır" diye atlanırsa hatanın kendisi geri gelir.

Her adımdan sonra Supabase'de:
`select token, platform, user_id, updated_at from push_tokens;`

- [ ] **2.1 İzin verildikten sonra** satır oluşmalı, `platform` = `android`.
- [ ] **2.2 Sistem ayarlarından bildirimi KAPAT**, uygulamayı tamamen
      kapatıp yeniden aç → satır **SİLİNMELİ**. (Bu tam olarak bir kez
      kırıktı: temizlik bellekteki token'a güveniyordu, taze süreçte `null`
      olduğundan satır sonsuza kadar kalıyordu.)
- [ ] **2.3 Ayarlardan tekrar AÇ**, uygulamayı aç → satır geri gelmeli.
- [ ] **2.4 Çıkış yap** → satır silinmeli.
      ⚠ 29 Ağustos 2026'da KIRIK bulundu: temizlik oturum kapandıktan SONRA
      koşuyordu, `auth.uid()` null olduğu için DELETE RLS'e takılıp sessizce
      hiçbir şey silmiyordu. Düzeltildi (`registerBeforeSignOut`) ama
      **cihazda doğrulama bekliyor** — yeni derleme gerekiyor.
- [ ] **2.5 BAŞKA bir hesapla gir (aynı cihaz)** → satır sayısı ARTMAMALI;
      var olan satırın `user_id`'si değişmeli (anahtar token, kullanıcı
      değil).
      ⚠ 29 Ağustos 2026'da KIRIK bulundu ve sebebi 2.4'ünkinden BAŞKA: birincil
      anahtar `token` olduğundan ikinci kullanıcının upsert'ü UPDATE dalına
      düşüyor, `push_tokens_update_own` politikası mevcut satıra bakıp reddediyor
      (`42501`). Devir artık `register_push_token` RPC'siyle (SECURITY DEFINER).
      **Cihazda doğrulama bekliyor** — yeni derleme gerekiyor.

⚠ **BU İKİSİNİ BİRİM TESTİ YAKALAYAMAZ.** `FakeStore` yazılanı bir listeye
ekliyor; RLS diye bir şey yok. Yani "testler yeşil" burada yalnızca çağrının
yapıldığını söyler, yazmanın TUTTUĞUNU değil — 2.4/2.5 cihazda koşulmak
ZORUNDA ve sonucu TABLODAN okunmalı, uygulamanın ekranından değil.

⚠ **2.2/2.3'ü OYUNU OLAN bir hesapla yapmak, açılış tetikleyicisini
KANITLAMAZ** (29 Ağustos 2026'da fark edildi, tur ortasında): bekleyen oyun
varsa uygulama açılışta kendiliğinden **Canlı sekmesine geçiyor**, yani eski
(kırık) koddaki tetikleyici — sekmenin `_reload()`'u — zaten koşuyor. O turda
satırın silinmesi doğrudur ama Parça 159'un düzelttiği yolu sınamaz; dünkü
kırık kod da o senaryoyu geçerdi.
**İzole etmek için** hiç aktif oyunu/daveti OLMAYAN bir hesapla yap: uygulama
Canlı'ya kendiliğinden gitmez, dolayısıyla satırın silinmesi/geri gelmesi
YALNIZCA `_HomeGate`'in açılış çağrısıyla açıklanabilir.
- [ ] **2.6 Hesabı sil** (Hesap Ayarları → Hesabımı Sil) → o kullanıcının
      satırı da gitmeli (`delete_account_cascade`).

## 3. Bildirimin düşmesi ve dokunma

`notify-deadline-warnings` cron'u süresi dolmak üzere olan sıraları
uyarıyor; push e-postanın YANINDA gidiyor, yerine değil.

- [ ] **3.1 Bildirim geliyor.** İki hesapla bir Canlı oyun kur, sıranın son
      tarihini uyarı penceresine sokacak şekilde bekle (ya da fonksiyonu
      elle tetikle) → cihaza bildirim düşmeli, başlık/gövde Türkçe ve
      okunur olmalı.
      - ⚠ **Kanal kimliği:** Android 8+ bilinmeyen bir `channel_id`'ye
        gelen bildirimi **sessizce yutuyor**. Bildirim hiç gelmiyorsa ilk
        bakılacak yer `MainActivity.kt`'deki `kelimeki_oyun` kanalı ile
        `_shared/push.ts`'in yazdığı değerin AYNI olup olmadığı.
      - ✅ **29 Ağustos 2026: geçti** (ses + açılır banner, gerçek cihaz).
      - ⚠ **AÇILIR BANNER İÇİN KANALIN YENİ DOĞMASI ŞART.** Kanal önemi
        yaratıldıktan SONRA yükseltilemiyor: 28 Ağustos'ta kod
        `IMPORTANCE_HIGH`e çekildi ama mevcut kurulumda kanal DEFAULT olarak
        doğmuş olduğundan banner çıkmadı ve teşhis yanlış sanıldı. Uygulama
        KALDIRILIP yeniden kurulunca banner geldi. Kanal önemiyle ilgili bir
        şey test ederken önce uygulamayı kaldır — yoksa doğru kodu yanlış
        sanırsın.
- [ ] **3.1b Aynı uyarının E-POSTASINDA "takdirde" yazmalı** — "taktirde"
      değil. Düzeltme repoda duruyordu ama hiç canlıya çıkmamıştı; push
      dağıtımıyla birlikte gitti.
- [ ] **3.2 Bildirime dokun** → uygulama açılmalı ve **doğru Canlı oyun**
      gelmeli (yanlış oyun ya da yalnızca Setup değil).
- [ ] **3.3 Uygulama TAMAMEN kapalıyken** (soğuk başlangıç) aynı test.
- [ ] **3.4 Bildirimi kapatmış bir kullanıcıya push GİTMEMELİ**
      (`profiles.push_notifications_enabled = false`) — ama **e-posta yine
      gitmeli**. İkisi ayrı kanal.
      ⚠ **Bu tercihin ARAYÜZÜ YOK ve bu bilinçli** (29 Ağustos 2026, kullanıcı
      kararı): *"Bildirim ayarlarını app'den yönetemiyor, ayarlara
      gönderiyorsa yapmanın bir anlamı yok. Kullanıcı ayarlara gider yapar."*
      Sunucu tercihi uyguluyor ama ne web'de ne uygulamada bir anahtarı var —
      bu adım yalnızca SQL ile kurulabilir. Gerekçe: Android'de bildirimi
      kapatmanın gerçek yolu zaten sistem ayarı (uygulama onu programatik
      değiştiremez, yalnızca o ekrana yönlendirebilir) ve sistem anahtarı
      kapatıldığında e-posta ZATEN gelmeye devam ediyor — yani kendi
      anahtarımız bugün hiçbir yeni yetenek katmıyor. Kolon,
      ikinci bir push tipi geldiğinde anlam kazanacak diye duruyor.
      **Eksik sanıp eklemeye kalkma.**
- [x] **3.5 Uygulamayı silip yeniden kur** → eski token artık geçersiz;
      sunucu `UNREGISTERED` alıp satırı silmeli (bir sonraki cron'dan sonra
      `push_tokens`ta ölü satır kalmamalı).
      ✅ **29 Ağustos 2026: geçti, İKİ kez.** (a) 28 Ağustos'tan kalan ölü bir
      satır gün içindeki gönderimlerden birinde kendiliğinden temizlendi;
      (b) uygulama silindikten sonra tetiklenen uyarıda tablo **sıfır satıra**
      indi. İkisinde de e-posta gitmeye devam etti (`sentLocal:1`) — push
      arızası e-posta yolunu düşürmüyor.
      **Bu adım CİHAZ GEREKTİRMİYOR:** uygulama silindikten sonra fonksiyonu
      elle tetikleyip `push_tokens`a bakmak yeterli; temizlik sunucuda oluyor.

## 3b. Davet bildirimleri (Faz 2, 30 Ağustos 2026 — SUNUCU tarafı canlı)

Üç yeni push kanalı deploy edildi. **Sürüm gerekmedi**, sahadaki paket
token'ı zaten kaydediyordu — yani 1.0.1'i olan bir testçi de bunları alır.

- [ ] **Oyun daveti:** başka bir hesaptan sana Canlı oyun daveti gönderilsin.
      Bildirim: **"Canlı oyun daveti"** / *"{isim} seni {n} kişilik bir oyuna
      davet etti."*
- [ ] **Arkadaşlık isteği:** başka bir hesap sana arkadaşlık isteği
      göndersin. **"Yeni arkadaşlık isteği"** / *"{isim} seni Kelimeki'de
      arkadaş olarak eklemek istiyor."*
- [ ] **Hatırlatma (cron):** 3 gün cevapsız kalan bir istek için günlük cron
      gönderiyor — elle tetiklenemez, beklemek gerekiyor.
      **"Bekleyen arkadaşlık isteğin var"**.
- [ ] ⚠ **Bildirime dokunmak 1.0.2 ve ÖNCESİNDE bir yere götürmez** —
      yönlendirme 1.0.3'ün kodu (§3c). Eski derlemede dokununca yalnızca
      uygulama açılır; bu hata DEĞİL. Hangi derlemede olduğunu Setup'ın
      teşhis satırından oku (deploy doğrulama kuralı).
- [ ] **E-posta tercihi push'u kapatmamalı.** Hesap Ayarları'ndan e-posta
      bildirimlerini KAPAT, push'u açık bırak → davet geldiğinde e-posta
      gelmemeli ama **push gelmeli**. (30 Ağustos 2026'ya kadar
      `notify-deadline-warnings`'te tam tersi oluyordu; dördü de düzeltildi.)

## 3c. Bildirime dokunma yönlendirmesi + Analytics (Faz 3, 30 Ağustos 2026 — 1.0.3 İSTER)

Kod 30 Ağustos'ta yazıldı; sahaya 1.0.3'le çıkar. ⚠ **Play imzalı derleme
şart olmayan tek kontrol Analytics değil** — FCM dokunuşu yan yüklenmiş
`.apk`'da da çalışır, ama gerçek senaryo (bildirim → dokun) kapalı test
derlemesiyle koşulmalı ki üretimdekiyle aynı imza/kanal zinciri sınansın.

- [ ] **Davet bildirimi → dokun (uygulama ARKA PLANDA).** Başka hesaptan
      Canlı oyun daveti gönderilsin, bildirime dokun: uygulama öne gelmeli
      ve **Arkadaşınla sekmesi** açılmalı (davet beklemede olduğundan tahta
      DEĞİL; "Oyun Davetleri" alt sekmesi kendiliğinden seçili).
- [ ] **Aynı bildirim → dokun (uygulama KAPALI, görev yöneticisinden
      atılmış).** Soğuk başlangıç AYRI bir API yolu (`getInitialMessage`) —
      sıcak akış çalışıyor diye bu adım ATLANMAZ (Parça 87'nin AppLinks
      dersi aynen geçerli).
- [ ] **Davet kabul edildikten sonra aynı linke dokunmak** (bildirim
      tepside durmuş olabilir): oyun artık `active` → **Canlı tahta
      DOĞRUDAN açılmalı**, sekme değil.
- [ ] **Başka bir ekranda/oyundayken dokun:** açık modal/tahta ne olursa
      olsun köke dönüp bildirimdeki oyuna gitmeli — yığının üstüne İKİNCİ
      bir tahta binmemeli.
- [ ] **Girişsizken** (çıkış yapıp `kelimeki://oyun/<id>` linkini elle aç):
      hiçbir şey açılmamalı; giriş yapınca oyun kendiliğinden açılmalı.
- [ ] **Teslim uyarısı bildirimi ESKİSİ GİBİ:** link taşımıyor, dokununca
      yalnızca uygulama açılır — bu hata değil (Faz 4'te "sıra sende"
      linklenecek).
- [ ] **GA4 olayları (DebugView):** `adb shell setprop
      debug.firebase.analytics.app com.kelimeki.kelimeki` sonra Firebase
      Console → DebugView. Sırayla tetikle ve düştüğünü gör:
      tanıtımı gez (`intro_slide_viewed` index 0..4), kayıt formunu aç
      (`signup_started`), Canlı oyun formunu aç/gönder
      (`live_game_form_opened`/`live_game_created`), davet linki paylaş
      (`invite_link_shared`, source parametresiyle). İş bitince:
      `adb shell setprop debug.firebase.analytics.app .none.`
- [ ] **Analytics uygulamayı YAVAŞLATMAMALI/DÜŞÜRMEMELİ:** uçak modunda
      aynı akışları gez — hiçbir ekran takılmamalı (fire-and-forget
      sözleşmesi; olaylar Firebase'in kendi kuyruğunda bekler).

## 3d. "Sıra sende" bildirimi (Faz 4 — SUNUCU; deploy edildiyse her sürümde çalışır)

Tetikleyici sunucuda (trigger + `notify-your-turn`), yani 1.0.1/1.0.2 dahil
her istemcinin hamlesi bildirim üretir; yalnızca DOKUNUNCA tahtaya gitme
1.0.3 ister (§3c).

- [ ] **Rakip hamle yapınca** (sen uygulamada DEĞİLKEN): **"Sıra sende!"** /
      *"{isim} hamlesini yaptı — {n} kişilik oyunda sıra sende."*
- [ ] **YZ'li Canlı oyunda YZ oynayınca da** gelmeli (isim "Yapay Zeka") —
      tetikleyici `submit_move`un YZ dalını da görüyor. ⚠ **YALNIZCA 4
      KİŞİLİKTE denenebilir:** `create_online_game` 2 kişilik Canlı oyunda
      YZ'ye HİÇ izin vermiyor ve 4 kişilikte YZ'yi yalnızca son koltuğa
      koyuyor (`20260727122207_online_game_ai_slot_rule.sql`). Yani YZ
      oynayınca sıra HER ZAMAN 1. koltuğa geçer — az önce hamle yapan kişiye
      değil. Bildirimi o kişi bekleyecek, sen değil.
      ⚠ **YZ "anında" oynamıyor — bir istemcinin oyunu AÇIK tutması
      gerekiyor** (`play-ai-turn`ü tetikleyen bir katılımcının oturumu;
      `20260728172716_ai_turn_trigger.sql`). Ölçüldü (üretim verisi): biri
      bakarken gecikme 20–90 sn, kimse bakmazken **9,5 saat · 26 saat ·
      2 gün**. Bu testi koşarken YZ'nin sırası geldiğinde oyunu bir cihazda
      açık tut, yoksa "bildirim gelmedi" sanırsın.
- [ ] **Bastırma:** hızlı gidip gelen oyunda (ikiniz de başındayken art arda
      hamle) bildirim GELMEMELİ — hedefin son 10 dk içinde hamlesi varsa
      sunucu http çağrısını hiç yapmıyor. 10+ dk bekleyip rakip oynayınca
      yine gelmeli.
- [ ] **Hamleyi YAPANA asla gelmez** — kendi hamlenden sonra kendine
      bildirim düşüyorsa bu ciddi bir regresyon, hemen bildir.
- [ ] Oyun BİTİREN hamlede kimseye "sıra sende" gitmez (GameOver ayrı iş).

## 4. Kayıt onayı ve şifre sıfırlama (derin bağlantı kanalı)

`authRedirectUri` = `https://kelimeki.com/auth` (App Link),
`resetRedirectUri` = `kelimeki://reset` (custom şema). İkisinin farkı
BİLİNÇLİ — gerekçe `config/env.dart` başlığında.

- [ ] **4.1 Play derlemesinde kayıt ol** → onay e-postasındaki linke
      **telefondan** dokun → **uygulama açılmalı** ve kullanıcı **doğrudan
      girişli** gelmeli ("dönüp elle giriş yap" adımı OLMAMALI).
- [ ] **4.2 Aynı linki MASAÜSTÜ tarayıcıdan aç** → kelimeki.com açılmalı;
      **`ERR_UNKNOWN_URL_SCHEME` benzeri bir hata ekranı ÇIKMAMALI.** (Bu
      maddenin var olma sebebi: custom şemada tam bu ekran çıkıyordu.)
      E-posta yine de doğrulanmış olmalı — uygulamadan giriş yapılabilmeli.
- [ ] **4.3 CI `.apk`'sında 4.1'i tekrarla** → link **tarayıcıda** açılır
      (App Links doğrulaması debug imzada geçmez). Bu BEKLENEN sonuç; hata
      ekranı olmadığı sürece geçer sayılır.
- [ ] **4.4 Şifremi unuttum** → `kelimeki://reset` linki uygulamayı açmalı
      ve şifre değiştirme penceresi gelmeli (custom şema, imzadan bağımsız).
- [ ] **4.5 Arkadaş davet linki** (`https://kelimeki.com/davet/<token>`) —
      Play derlemesinde uygulamayı, `.apk`da tarayıcıyı açar; ikisi de
      geçerli.
      ⚠ **LİNKE UYGULAMANIN KURULU OLDUĞU CİHAZDAN dokun** (29 Ağustos
      2026'da yarım kaldı): link iPad'den açıldı, sayfa doğru geldi ama
      Android'deki davranış HİÇ sınanmadı — Kelimeki'nin kurulu olmadığı bir
      cihazda tarayıcıda açılması zaten tek olasılık. Bu, turun üçüncü
      "kurulum seçimi testi sessizce geçersiz kıldı" vakası (bkz. 1.1/1.2'de
      misafir, 2.2'de otomatik Canlı sekmesi).

## 5. Bu sürümün görsel ve sözlük değişiklikleri

Push'la ilgisiz ama AYNI pakette gitti (Parça 156-158). Üçü de web ve portta
birden değişti ve testli — burada aranan şey cihazda gerçekten öyle
göründüğü.

- [ ] **5.1 Tahtaya konmuş jokerin `0` puanı KIRMIZI.** Raftaki joker
      DEĞİŞMEDİ — orada ★ zaten ayırt ediyor.
- [ ] **5.2 Tahta üstündeki skor kutularında sayılar SİYAH.** Oyuncu adı ve
      kutu rengi aynı; teslim olmuş oyuncunun sayısı hâlâ kendi renginde.
- [ ] **5.3 Merkezdeki X3 etiketi büyüdü** ve hücreden taşmıyor.
- [ ] **5.4 Dört yeni kelime oynanabiliyor** — `lapis`, `mö`, `banu`,
      `banü` — ve dördünün de anlamı geliyor. (`banu` ile `banü` yazım
      varyantı değil, ayrı maddeler.)
- [ ] **5.5 Oyundan Setup'a dönünce Canlı rozeti taze** (Parça 153): Canlı
      bir oyunda hamle yapıp geri dön, rozetteki sayı güncellenmiş olmalı.

## 6. Regresyon — push HİÇBİR ŞEYİ düşürmemeli

- [ ] **6.1 Firebase'siz yüzey:** GitHub Pages'teki Flutter **web**
      derlemesi hâlâ açılmalı (`initFirebase()` orada `false` dönüyor).
- [ ] **6.2 İzin hiç verilmemiş cihazda** oyun/Canlı oyun/sohbet akışlarının
      tamamı normal çalışmalı — push isteğe bağlı bir katman.
- [ ] **6.3 Uçak modunda** açılış: push kurulumu takılmamalı, Setup normal
      sürede gelmeli.

## 7. Güncelleme kendiliğinden geliyor mu (Parça 171)

Kullanıcı kararı (30 Ağustos 2026): *"Kimde hangi versiyon olursa olsun,
app'i açtığında daha yeni bir sürüm varsa uyarsın ve yapsın."* Mekanizma
Play In-App Update (Immediate akışı); sunucuda sürüm satırı tutulmuyor.

⚠ **CI'ın debug `.apk`'sında BU BÖLÜMÜ HİÇ DENEME.** Yan yüklenmiş pakette
Play uygulamayı tanımaz ve kontrol sessizce "bilinmiyor" döner — orada
"çalışmıyor" görmek bir hata DEĞİL, beklenen davranış. Bölümün tamamı
kapalı test kanalından kurulmuş derleme ister.

**Kurulum:** mağazada DAHA YENİ bir sürüm yayınlıyken cihazdaki ESKİ sürümü
aç (yani sürüm N kuruluyken N+1 kanala düşmüş olmalı).

- [ ] **Güncelleme varken:** uygulama açılır açılmaz Play'in tam ekran
      güncelleme penceresi KENDİLİĞİNDEN açılmalı; güncelleme uygulamadan
      ÇIKMADAN tamamlanmalı ve uygulama yeni sürümle geri gelmeli.
      Doğrula: Setup'ın teşhis satırındaki `Derleme <sha>` değişmiş olmalı.
- [ ] **Güncelleme yokken:** hiçbir pencere açılmamalı, uygulama normal
      açılmalı.
- [ ] **Uçak modunda:** uygulama ÇÖKMEMELİ, akış sessizce atlanmalı. Sonra
      ağı aç ve uygulamayı öne al → kontrol TEKRAR denenmeli (pencere
      açılmalı). ⚠ Bu dal özellikle önemli: "soramadım"ı "güncel" saymak,
      açılışta ağı olmayan kullanıcıyı sonsuza dek eski sürümde bırakırdı.
- [ ] **Vazgeçme:** pencerede geri/iptal → uygulama normal açılmalı ve öne
      her dönüşte pencere TEKRAR AÇILMAMALI. Bir sonraki AÇILIŞTA yeniden
      açılması doğru davranış.
- [ ] **Acil fren yolu (yalnızca eşik yükseltilmişse):** "Güncelleme
      Gerekli" ekranındaki buton önce uygulama içindeki akışı denemeli;
      Play cevap vermezse mağazayı dışarıda açmalı — hiçbir koşulda
      butonsuz/çıkışsız bir ekran kalmamalı.
