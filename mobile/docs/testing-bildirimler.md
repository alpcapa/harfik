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

⚠ **TERS YÖN DE GEÇERLİ ve 4 Eylül 2026'da bir kez daha yaşandı** (kullanıcı:
*"App'i açtım ama güncelleme gelmedi"*). Play'den kurulacak bir tur için
**önce yan yüklenmiş `.apk`'yı kaldır** — Play onun üstüne KURAMAZ. Sebep
0.1'in aynısı (imza farkı) ama sonucu sessiz: Play "güncelle" demez,
uygulama içi güncelleme uyarısı da HİÇ çıkmaz.

⚠ **`.apk`'nın `versionCode`'u 525 DEĞİL, 1'dir.** `--build-number` yalnızca
`.aab` adımına veriliyor (`mobile-build.yml`), APK `pubspec.yaml`'ın `+1`ini
alır. Yani aynı koşudan çıkan iki paketin sürüm ADI aynı (1.0.6), sha'sı
aynı, `versionCode`'u FARKLI. **Sonuç: Setup'ın teşhis satırındaki sha
"hangi paket kurulu" sorusunu AYIRT EDEMEZ** — `.apk` ile `.aab` aynı sha'yı
gösterir. Ayırt etmenin yolu Play Store ürün sayfası: "Yükle" diyorsa
kurulu kopya Play'in değildir.

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

- [x] **1.1 Bağlamsız açılış.** GİRİŞ YAP, Canlı sekmesine GİRME → hiçbir
      izin penceresi çıkmamalı (ne bizimki ne sistemin).
- [x] **1.2 Boş Canlı sekmesi.** Aynı (oyunsuz) hesapla Canlı sekmesini aç →
      yine hiçbir pencere çıkmamalı.
- [x] **1.2-misafir** (29 Ağustos 2026): girişsiz Canlı sekmesi → pencere
      YOK. Geçti, ama yukarıdaki nedenle 1.2'nin YERİNE geçmez.
- [x] **1.3 Gerçek tetikleyici.** Bir Canlı oyun başlat (ya da bir davet
      al), Canlı sekmesini aç → **"Bildirimleri açalım mı?"** penceremiz
      çıkmalı; "BİLDİRİMLERİ AÇ" / "ŞİMDİ DEĞİL".
      ✅ **4 Eylül 2026: geçti** — pencere gerçek tetikleyicide çıktı.
      Not: bu turda pencerenin YENİDEN çıkabilmesinin sebebi §2.2'de
      bildirimlerin sistem ayarlarından kapatılmış olmasıydı; izin durumu
      sıfırlanınca soru yeniden anlamlı hale geliyor.
- [x] **1.4 "ŞİMDİ DEĞİL" sistem denemesi HARCAMAMALI.** Bas → sistem
      diyaloğu ÇIKMAMALI. Uygulamayı kapat-aç, Canlı sekmesini yeniden aç →
      pencere **hemen tekrar çıkmamalı** (7 gün aralık).
      ✅ **4 Eylül 2026: geçti** (1.0.6). Kullanıcı "ŞİMDİ DEĞİL"e bastı ve
      **Android'in diyaloğu çıkmadı** — maddenin sınadığı şey bu.
      ⚠ **Kanıtın türü: kullanıcı gözlemi, ölçüm DEĞİL.** Bu maddenin
      sunucuda izi yok (bayrak cihazda, `SharedPreferences`); doğrulanacak
      başka bir yer de yok. İkinci yarısı (kapat-aç sonrası pencerenin
      hemen geri gelmemesi) ayrıca RAPOR EDİLMEDİ — 7 günlük aralığın
      kendisi `push_rules.dart`'ta testli olduğu için ayrıca koşulması
      istenmedi.
      ⚠ **Bu madde bir kez YANLIŞ KAPALI sanıldı ve bir kez de fazladan
      açık kaldı** — dersi ikisinde de aynı: *"Bunlar ok"* gibi bir onay
      HANGİ maddeyi kapattığını söylemez. Kullanıcı 1.4+1.5'i sorup
      *"Bunlar ok"* dediğinde ben bunu "açıklama tamam" diye okudum, o ise
      "ikisi de geçti" demek istemişti; ayrıca dayanak gösterdiği gözlem
      (*"ok deyince Android dialogu çıkıyor"*) 1.5'in yolu, 1.4'ünkü değil.
      **Kural: grup onayını tiklemeden önce hangi maddeleri kapsadığını
      TEK TEK teyit et** — bu turda §3.1'de de aynı sınıf hata yapılmıştı.
      Öncesinde şöyle yazıyordu: *4 Eylül 2026'da KOŞULMADI ve bu bilinçli:* aynı turda 1.5 seçildi
      (izin verildi), ikisi birbirini tüketiyor. Play kapalı testinden
      yapılacak TEMİZ kurulumda koşulacak — o kurulum aynı zamanda §4.1'i
      (App Links ile kayıt onayı) da karşılıyor, yani ikisi tek turda biter.
      ⚠ **O kurulum 4 Eylül'de YAPILDI** (kullanıcı `.apk`'yı silip kapalı
      test kanalından 1.0.6'yı kurdu; §4.5 ile kanıtlandı). Yani bu madde
      ARTIK ENGELLİ DEĞİL, koşulmayı bekliyor: kaldırma hem bizim 7 günlük
      bayrağımızı hem Android'in izin verisini sildiğinden pencere yeniden
      çıkacak. **Bedeli §1.5 değil** (o zaten geçti, işaretli) — bedeli bu
      kurulumda bildirimlerin kapalı kalması; §2/§3 izin ister ama onlar da
      geçti ve FCM imzadan bağımsız olduğu için Play derlemesinde yeniden
      koşulmaları gerekmiyor.
- [x] **1.5 "BİLDİRİMLERİ AÇ".** Bas → **Android'in kendi** izin diyaloğu
      çıkmalı. İzin ver.
      ✅ **4 Eylül 2026: geçti** (1.0.6, sha `711eaaa`). Kullanıcının tarifi:
      *"App'de bildirim gönderme mesajımız çıkıp ok diyince ayrıca Android
      izin ver/verme dialogu çıkıyor"* — İKİ ADIM TASARIM GEREĞİ böyle ve
      maddenin sınadığı şey tam olarak bu zincir. İkinci diyaloğun ayrıca
      çıkması fazlalık DEĞİL: Android 13+ sistem diyaloğunu ikinci retten
      sonra bir daha hiç göstermediğinden, uygulama önce kendi yumuşak
      penceresiyle soruyor ve o tek atışı ancak kullanıcı "aç" dediğinde
      harcıyor.
- [x] **1.6 İzin verildikten sonra bir daha sorulmamalı.** Canlı sekmesine
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
      ✅ **4 Eylül 2026: CİHAZDA KOŞULDU ve GEÇTİ** (1.0.6, sha `d07c06d`).
      ⚠ **Ama yukarıdaki tarif tek başına bu maddeyi KOŞTURMUYOR:** 2.4'teki
      çıkış satırı zaten sildiğinden, ardından gelen giriş UPDATE dalına
      değil temiz bir INSERT'e düşer ve 42501'in yaşandığı yol hiç
      denenmemiş olur. Satırın BAŞKA bir kullanıcıya bağlı KALMASI gerekiyor;
      kurulum şu: **uçak modunda çıkış yap** (`signOut` temizliği
      `try/catch` içinde yutuluyor, satır sunucuda kalır) → ağı aç → ikinci
      hesapla gir.
      Ölçüm: toplam satır 7'de kaldı, eski sahip 0 · yeni sahip 1, ve
      `created_at` 08:16:15 ↔ `updated_at` 08:19:26 — aradaki fark satırın
      silinip yeniden yaratılmadığını, GÜNCELLENDİĞİNİ kanıtlıyor.
      **Bu ayrımı ölçmeden madde kapatılmaz:** delete+insert de "doğru
      sahip, tek satır" görüntüsü verir.

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
- [x] **2.6 Hesabı sil** (Hesap Ayarları → Hesabımı Sil) → o kullanıcının
      satırı da gitmeli (`delete_account_cascade`).
      ✅ **4 Eylül 2026: geçti** (T5 silindi) — `profiles`, `auth.users`,
      `push_tokens` ve kendi 8 oyun kaydı sıfırlandı, **sahipsiz token
      kalmadı**.
      ⚠ **KANITIN SINIRI YAZILI OLSUN:** silme öncesi satırın VAR OLDUĞU
      ölçülemedi (giriş ile silme tek adımda yapıldı), yani "satır silindi"
      dolaylı kanıta dayanıyor — T5 09:40:55'te telefondan giriş yaptı ve bu
      uygulamada giriş her seferinde token yazıyor (aynı gün §2.3/§2.5 ve
      09:31:53'te üç kez ölçüldü), silme 09:41:55'te oldu. Kod tarafı da
      koşulsuz: `delete from public.push_tokens where user_id = p_uid`
      (migration `20260828114537`, satır 243) bir dala bağlı değil.
      **Bir sonraki turda ÖNCE token satırını doğrula, SONRA sil** — iki
      adımı birleştirmek bu maddeyi ölçülemez hale getiriyor. Silme
      fonksiyonu sildiği sayıları bir özet olarak DÖNDÜRÜYOR ama hiçbir yere
      YAZMIYOR, yani sonradan bakılacak bir denetim izi yok.

## 3. Bildirimin düşmesi ve dokunma

`notify-deadline-warnings` cron'u süresi dolmak üzere olan sıraları
uyarıyor; push e-postanın YANINDA gidiyor, yerine değil.

- [x] **3.1 Bildirim geliyor.** İki hesapla bir Canlı oyun kur, sıranın son
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
- [x] **3.1b Aynı uyarının E-POSTASINDA "takdirde" yazmalı** — "taktirde"
      değil. Düzeltme repoda duruyordu ama hiç canlıya çıkmamıştı; push
      dağıtımıyla birlikte gitti.
      ✅ **4 Eylül 2026: §3.1 ile BİRLİKTE koşuldu ve geçti** (1.0.6, sha
      `711eaaa`) — süre uyarısı cihaza düştü ve aynı uyarının e-postasında
      yazım doğru çıktı. Kaynak da tutuyor:
      `notify-deadline-warnings/index.ts` → *"hamle yapmadığınız takdirde"*.
- [x] **3.2 Bildirime dokun** → uygulama açılmalı ve **doğru Canlı oyun**
      gelmeli (yanlış oyun ya da yalnızca Setup değil).
      ✅ **4 Eylül 2026: geçti** (1.0.6, `711eaaa`) — hem arka plandan
      (`onMessageOpenedApp`) hem soğuk başlangıçtan (§3.3) doğru oyun açıldı.
- [x] **3.3 Uygulama TAMAMEN kapalıyken** (soğuk başlangıç) aynı test.
      ✅ **4 Eylül 2026: geçti** (1.0.6, `d07c06d`) — üstelik zor dalından:
      uygulama girişsiz açıldı, giriş yapılınca doğru oyun DOĞRUDAN açıldı.
      Yani bekleyen derin bağlantı auth bitene kadar tutuluyor.
      ⚠ Girişsiz açılış oturum kalıcılığı hatası SANILDI; ölçüldü ve değil
      (öldür → simgeden aç = girişli). Test boyunca aynı hesap hem web'de
      hem telefonda açıktı, token o yüzden bir kez geçersizleşti.
- [x] **3.4 Bildirimi kapatmış bir kullanıcıya push GİTMEMELİ**
      (`profiles.push_notifications_enabled = false`) — ama **e-posta yine
      gitmeli**. İkisi ayrı kanal.
      ✅ **4 Eylül 2026: push yarısı ÖLÇÜLDÜ ve geçti.** Bayrak SQL ile
      kapatıldı, rakip oynadı, `net._http_response.content` **`pushed: 0`**
      döndü (bayrak açıkken aynı yol `pushed: 1` veriyordu); bayrak hemen
      geri açıldı. 10 dk bastırması elendi — hedefin o oyundaki son hamlesi
      32 dk öncesindeydi.
      ⚠ **E-posta yarısı bu yoldan sınanamaz:** `notify-your-turn`ün e-posta
      kanalı BİLEREK yok (kaynağında yazılı). O yarı `notify-deadline-warnings`
      penceresi çıktığında koşulur.
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

✅ **4 Eylül 2026 — bölüm cihazda koşuldu ve GEÇTİ** (1.0.6, sha `711eaaa`;
kullanıcı: *"3b, e, f ok"*). ⚠ İki alt madde bu turda YAPISAL OLARAK
koşulamadı ve açık sayılmalı: **3 gün cevapsız istek için günlük cron
hatırlatıcısı** (elle tetiklenemez, beklemek gerekiyor) ve **"1.0.2 ve
öncesinde dokunmak bir yere götürmez"** notu (1.0.6'da konusuz — yönlendirme
zaten var).

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

### 31 Ağustos 2026 — sahada doğrulandı (1.0.3, kullanıcı cihazı)

Bir OYUN bildirimi (davet değil) iki yoldan da denendi ve **ikisinde de
Canlı tahta doğrudan açıldı**:

- **Uygulama arka plandayken** dokunuldu → öne geldi, oyuna gitti.
- **Uygulama KAPALIYKEN** (görev yöneticisinden atılmış) dokunuldu →
  uygulama açıldı ve oyuna gitti. Soğuk başlangıç ayrı bir API yolu
  (`getInitialMessage`) olduğundan asıl kıymetli olan bu — listenin
  "sıcak akış çalışıyor diye ATLANMAZ" uyarısı karşılandı.

⚠ **Yukarıdaki kutular yine de işaretlenMEDİ:** onlar DAVET bildirimini ve
"Arkadaşınla sekmesi açılmalı" beklentisini tarif ediyor; burada denenen
bildirim aktif bir oyuna aitti ve hedefi tahtaydı. Yani yönlendirme
zincirinin kendisi (FCM `data.link` → uygulama → doğru ekran) hem sıcak hem
soğuk yolda kanıtlandı, ama davete özgü dallar ve girişsiz/teslim-uyarısı
maddeleri hâlâ açık.

⚠ **Bu, 1.0.4'te bekleyen `onUnknownRoute` korumasını GEREKSİZ KILMAZ** —
o koruma başka bir giriş yolunu (Android App Links / platform route push'u)
hedefliyor; FCM dokunuşu o yoldan geçmiyor. Çökme yaşanmaması beklenen
davranış, çelişki değil.

## 3d. "Sıra sende" bildirimi (Faz 4 — SUNUCU; deploy edildiyse her sürümde çalışır)

✅ **4 Eylül 2026 — bölümün ölçülebilir maddeleri koşuldu ve GEÇTİ**
(1.0.6, sha `711eaaa`). Üçü sunucudan da doğrulandı: bildirimin gelmesi
(`pushed: 1`), **hamleyi yapana gelmemesi**, ve **10 dk bastırması** —
sonuncusu, hedefin o oyundaki son hamlesinden 70 sn sonra tetiklenen
devirde `http_post`un HİÇ yapılmamasıyla ölçüldü. ⚠ **YZ dalı koşulmadı**
(4 kişilik + YZ'li bir Canlı oyun gerekiyor) ve **oyun bitiren hamlede
kimseye gitmemesi** de ayrıca sınanmadı.

⚠ **Bu bölümü koşarken uygulamanın ARKA PLANDA olması şart** (madde zaten
"sen uygulamada DEĞİLKEN" diyor): kodda `FirebaseMessaging.onMessage`
dinleyicisi YOK, yani uygulama ön plandayken bildirim hiç gösterilmez.
4 Eylül'de bu bir turda "bildirim gelmedi" diye yanlış teşhise yol açtı;
sunucu `pushed: 1` döndüğü için ayırt edilebildi.

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
      **YZ pratikte ANINDA oynuyor** — ölçüldü (üretim, 29 gerçek YZ
      hamlesi): en hızlı 3,3 sn, ortalama 91 sn, en yavaş 42 dk; 10 dakikayı
      aşan yalnızca 1, 48 saati aşan 0. Yani bu maddeyi denerken YZ'yi
      beklemek gerekmiyor.
      ⚠ **Ama YZ turu yapısal olarak bir İSTEMCİ tarafından tetikleniyor**
      (`play-ai-turn`, `20260728172716_ai_turn_trigger.sql`) — sunucuda cron
      ya da trigger YOK. Pratikte hızlı olmasının sebebi tetikleyicinin
      hamleyi yapan kişinin kendi oturumu olması; o da zaten o an ekranın
      başında. Tek 42 dakikalık örnek bunun istisnası (hamleyi yapan
      uygulamayı hemen kapatmış olmalı).
      ⚠ **ÖLÇÜT TUZAĞI — "YZ hamlesi" `player_user_id is null` DEĞİLDİR.**
      O alan `auth.uid()`'den geliyor ve sunucu bağlamındaki her hamlede
      (zaman aşımı teslimleri dahil) null oluyor: YZ'si HİÇ olmayan
      oyunlarda 68 tane null hamle ölçüldü. Doğru ölçüt hamlenin
      `player_index`'inin YZ koltuğuna denk gelmesi. 30 Ağustos 2026'da bu
      karıştırıldı ve "YZ günlerce bekliyor" diye yanlış bir sonuca
      varıldı — kullanıcı düzeltti.
- [ ] **Bastırma:** hızlı gidip gelen oyunda (ikiniz de başındayken art arda
      hamle) bildirim GELMEMELİ — hedefin son 10 dk içinde hamlesi varsa
      sunucu http çağrısını hiç yapmıyor. 10+ dk bekleyip rakip oynayınca
      yine gelmeli.
- [ ] **Hamleyi YAPANA asla gelmez** — kendi hamlenden sonra kendine
      bildirim düşüyorsa bu ciddi bir regresyon, hemen bildir.
- [ ] Oyun BİTİREN hamlede kimseye "sıra sende" gitmez (GameOver ayrı iş).

## 3e. Bildirim ÇAKIŞTIRMA + simge rozeti (31 Ağustos 2026 — SUNUCU; her sürümde)

✅ **4 Eylül 2026 — bölüm cihazda koşuldu ve GEÇTİ** (1.0.6, sha `711eaaa`;
kullanıcı: *"3b, e, f ok"*). ⚠ **Arkadaşlık isteği + 3 gün sonraki
hatırlatıcısının aynı satıra çakışması** açık kalmalı — hatırlatıcı cron'u
beklemek gerekiyor.

Bir kullanıcı uygulama simgesinde **9** rozetinin takılı kaldığını bildirdi.
Rozet uygulamanın kendi sayacı DEĞİL: Samsung One UI onu panelde **hâlâ
duran** bildirimlerden türetiyor. Etiket olmadığı için aynı oyunun her "sıra
sende"si panelde ayrı bir satır açıyor ve sayı birikiyordu. Sunucu artık
`android.notification.tag` (+ iOS `apns-collapse-id`) gönderiyor —
`_shared/push.ts` → `PushMessage.tag`, önek şeması orada.

⚠ **BU BÖLÜM SUNUCU TARAFINI ölçüyor — rozeti SIFIRLAMIYOR, birikmesini
durduruyor.** Sıfırlama ayrı bir iş ve DERLEME istiyor; kodu hazır ama
sahaya çıkmadı → §3f. Yani burada "rozet 0 oldu" ARAMA; aranan şey rozetin
**bekleyen ayrı iş sayısını** göstermesi.

- [ ] **Aynı oyunda üst üste iki "sıra sende"** (rakip oynasın, 10+ dk bekle,
      tekrar oynasın — §3d'deki bastırma yüzünden bekleme şart): panelde
      **TEK** satır olmalı, metni sonuncusunun metni. İki ayrı satır
      görüyorsan etiket gitmiyor demektir.
- [ ] **İKİ FARKLI oyunda** sıra sana gelsin: panelde **İKİ** ayrı satır
      olmalı (etiket oyun id'siyle önekli, birbirini silmemeli).
- [ ] **Aynı oyunun "davet"i ile "sıra sende"si birbirini SİLMEMELİ** —
      önekler ayrı (`davet:` ↔ `sira:`). 4 kişilik bir oyun kurup daveti
      kabul ettir, sonra sıranın o kişiye gelmesini sağla: iki satır.
- [ ] **Arkadaşlık isteği + 3 gün sonraki hatırlatıcısı** AYNI satıra
      düşmeli (ikisi de `arkadas:<gönderen>`), yani hatırlatma eskisinin
      yerine geçmeli. (3 gün beklemek gerekiyor — fırsat çıkarsa bak.)
- [ ] **Panelden bildirimleri süpür** → simgedeki rozet kaybolmalı. Bu,
      rozetin gerçekten panelden türediğinin kanıtı; kaybolmuyorsa
      teşhis yanlış demektir, bildir.

## 3f. Rozet SIFIRLAMA + sürüm damgası (31 Ağustos 2026 — SÜRÜM İSTER, henüz çıkmadı)

✅ **4 Eylül 2026 — bölüm KOŞULABİLİR HALE GELDİ ve GEÇTİ** (1.0.6, sha
`711eaaa`; kullanıcı: *"3b, e, f ok"*). Başlıktaki "henüz çıkmadı" ve
"`c1c0437` görüyorsan ATLA" uyarısı ARTIK GEÇERSİZ: kod 1.0.5 ile sahaya
çıktı. Sürüm damgası ayrıca sunucudan doğrulandı — `push_tokens` satırı
`app_version = 1.0.6` yazdı ve token yaşam döngüsü boyunca (§2.2-§2.5) her
yeniden kayıtta güncel kaldı.

⚠ **Bu bölüm 1.0.3'te KOŞULAMAZ.** İkisi de istemci değişikliği ve sürüm
bilerek yükseltilmedi (kullanıcı kararı: işler toplu çıkacak). Buradaki
maddeler yalnızca bu kodu taşıyan ilk derlemede anlamlı — Kurulum ekranındaki
teşhis satırındaki sha'yı ÖNCE kontrol et, `c1c0437` görüyorsan bu bölümü
ATLA.

**Rozet sıfırlama (#15).** Uygulama öne geldiğinde ve soğuk başlangıçta
panel temizleniyor (`MainActivity` → `cancelAll()`, MethodChannel
`kelimeki/bildirimler`).

- [ ] Birkaç bildirim biriktir (panelde 2-3 satır, simgede rozet). Uygulamayı
      **arka plandan öne al** → panel BOŞALMALI, rozet kaybolmalı.
- [ ] Uygulamayı tamamen KAPAT, bildirim gelsin, sonra **simgeden** aç →
      yine boşalmalı. (Bu ayrı bir yol: soğuk başlangıçta yaşam döngüsü
      olayı HİÇ tetiklenmez, kanca `initState`te.)
- [ ] **Bildirime DOKUNARAK aç** → hem panel boşalmalı HEM DE doğru oyunun
      tahtası açılmalı. ⚠ Asıl regresyon riski burada: temizleme, dokunuşun
      taşıdığı derin bağlantıyı bozmamalı (bağlantı açılış intent'inden
      geliyor, panelden değil — ama bunu cihazda görmek gerekiyor).
- [ ] **Başka uygulamaların bildirimleri DURMALI.** `cancelAll()` yalnızca
      kendi bildirimlerimizi kaldırır; WhatsApp/e-posta bildirimleri
      kaybolduysa ciddi bir hata var, hemen bildir.

**Sürüm damgası (#12).** Token her açılışta hizalanırken `app_version`
yazılıyor.

- [ ] Uygulamayı aç (bildirim izni VERİLMİŞ olmalı) → admin panelinde
      **Büyüme > Kullanıcı > "Kurulu Sürümler — Kişi"** tablosunda kendi
      cihazın yeni sürümle görünmeli.
- [ ] Aynı tabloda **"—" satırı** da olacak: damga 31 Ağustos'ta doğdu ve
      geriye dönük doldurulamıyor, yani henüz güncellememiş herkes orada.
      Bu bir arıza DEĞİL.
- [ ] **Regresyon:** bildirim izni VERMEYEN bir hesapla giriş yap → bu
      tabloda hiç görünmemeli (kapsam bilerek dar), ama bildirimlerin
      çalıştığı başka bir hesapta hiçbir şey bozulmamalı.

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
- [x] **4.4 Şifremi unuttum** → `kelimeki://reset` linki uygulamayı açmalı
      ve şifre değiştirme penceresi gelmeli (custom şema, imzadan bağımsız).
      ✅ **4 Eylül 2026: geçti** (1.0.6, sha `711eaaa`, DEBUG imzalı CI
      APK'sı — madde imzadan bağımsız olduğu için bu yeterli kanıt).
      **Sunucu kaydından uçtan uca ölçüldü**, "uygulama açıldı" gözlemine
      bırakılmadı:
      `12:11:59 user_recovery_requested (referer kelimeki://reset)` →
      **`12:13:55 GET /verify → 303, referer kelimeki://reset`** (link
      dokunuldu, sunucu özel şemaya yönlendirdi) →
      `12:13:56 login provider=recovery grant_type=pkce` →
      `12:14:25 user_modified (PUT /user)`.
      Şifre değişince **otomatik giriş** olması bir yan etki değil, `recovery`
      sağlayıcısıyla açılan oturumun tasarlanmış davranışı.
      ⚠ Linke MUTLAKA uygulamanın kurulu olduğu cihazdan dokunulmalı —
      iPad'den açılırsa `kelimeki://` şemasını karşılayan uygulama olmadığı
      için test sessizce geçersiz olur (aynı tuzak madde 4.5'te de yazılı).
- [x] **4.5 Arkadaş davet linki** (`https://kelimeki.com/davet/<token>`) —
      Play derlemesinde uygulamayı, `.apk`da tarayıcıyı açar; ikisi de
      geçerli.
      ✅ **4 Eylül 2026: `.apk` yarısı geçti** (1.0.6, sha `711eaaa`,
      debug imza). Link telefondan açıldı → **tarayıcıda** açıldı, sayfa
      düzgün geldi, hata ekranı yok. Beklenen sonuç buydu: assetlinks
      parmak izi debug imzayla uyuşmuyor.
      Sunucudan iki teyit: token T3 adına oluştu (`create_friend_invite_link`
      idempotent, tek kalıcı link) ve dokunduktan SONRA `use_count` **0'da
      kaldı** — yani linki AÇMAK sayacı artırmıyor, yalnızca başarılı bir
      kabul artırıyor. (Kendi linkine dokunulduğu için sunucu zaten
      reddediyor: *"Kendi linkinle arkadaş olamazsın."*)
      ✅ **Play yarısı da geçti (4 Eylül 2026, aynı gün).** Play kanalından
      kurulmuş 1.0.6 (525) pakette aynı linke telefondan dokunuldu →
      **uygulama açıldı** (tarayıcı DEĞİL) ve uygulama içinde sunucunun
      reddi göründü: *"Kendi linkinle arkadaş olamazsın."*
      **Bu tek gözlem üç şeyi birden kanıtlıyor** ve bu yüzden "uygulama
      açıldı"dan daha güçlü: (1) App Links doğrulaması GEÇTİ — kurulu paket
      release imzalı, `assetlinks.json` parmak izi tutuyor; (2)
      `deep_link.dart` token'ı ayrıştırıp doğru ekrana yönlendirdi; (3)
      kabul RPC'si GERÇEKTEN çağrıldı ve hatası kullanıcıya taşındı — yani
      yalnızca rota değil, zincirin tamamı çalışıyor.
      Sunucudan teyit: T3'ün token'ında (`52370565…`) `use_count` **0'da
      kaldı** — red sayacı artırmıyor, `.apk` turundaki ölçümle aynı.
      ⚠ **Yan fayda — bu madde `.apk` ↔ `.aab` AYIRT EDİCİSİDİR:** `Derleme
      <sha>` satırı ikisini ayıramaz (aynı koşudan, aynı sha). Bu ayırır:
      link uygulamayı açıyorsa paket Play'in, tarayıcıyı açıyorsa yan
      yüklenmiş `.apk`.
      ⏳ **Kabul akışının uygulama içi maddeleri hâlâ açık**
      (`testing-arkadaslar-canli.md`: "artık arkadaşsınız", mükerrer
      kontrolü, ağ hatasında davetin kaybolmaması, geçersiz token mesajı) —
      ama artık gerekçe App Links DEĞİL: linkin uygulamayı açtığı
      kanıtlandı. Tek engel **YENİ bir hesap** (aşağı bkz.).
      ⚠ O tur için YENİ bir hesap gerekecek: elimizdeki hesaplar
      (Ironman ↔ T3) zaten arkadaş, kabul akışı onlarla sınanamaz.
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

⚠ **Pratik sonuç — "güncelleme varken" dalı BİR SÜRÜM TURUNA YAYILIR ve
aynı gün koşulamaz.** Kanaldan en yeniyi kurduğun anda o dalı test etme
imkânını o tur için harcamış olursun. Doğru sıra: N kuruluyken bekle,
N+1'i kanala at, SONRA uygulamayı aç. 4 Eylül 2026'da bu kaçırıldı — 525
kurulup 525 beklendi. Sıradaki fırsat: 1.0.6 kuruluyken 1.0.7 yayınlanınca.

- [ ] **Güncelleme varken:** uygulama açılır açılmaz Play'in tam ekran
      güncelleme penceresi KENDİLİĞİNDEN açılmalı; güncelleme uygulamadan
      ÇIKMADAN tamamlanmalı ve uygulama yeni sürümle geri gelmeli.
      Doğrula: Setup'ın teşhis satırındaki `Derleme <sha>` değişmiş olmalı.
- [x] **Güncelleme yokken:** hiçbir pencere açılmamalı, uygulama normal
      açılmalı.
      ✅ **4 Eylül 2026: geçti.** Kullanıcı `.apk`'yı kaldırıp kapalı test
      kanalından 1.0.6 (525) kurdu ve uygulamayı açtı → pencere ÇIKMADI
      (*"App'i açtım ama güncelleme gelmedi"*). Kanalda 525'ten yenisi
      olmadığı için beklenen sonuç tam olarak buydu.
      ⚠ **Bu bulgu ilk anda hata sanıldı** — çünkü "güncelleme gelmedi"
      cümlesi hem bu maddenin GEÇMESİ hem bir üsttekinin DÜŞMESİ gibi
      okunabiliyor. Ayıran tek soru: *kanalda kurulu olandan daha yüksek
      bir `versionCode` var mı?* Yoksa doğru davranış sessizliktir.
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
