# Cihaz Testi — Push Bildirimleri ve Derin Bağlantılar (Parça 158)

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
- [ ] **3.1b Aynı uyarının E-POSTASINDA "takdirde" yazmalı** — "taktirde"
      değil. Düzeltme repoda duruyordu ama hiç canlıya çıkmamıştı; push
      dağıtımıyla birlikte gitti.
- [ ] **3.2 Bildirime dokun** → uygulama açılmalı ve **doğru Canlı oyun**
      gelmeli (yanlış oyun ya da yalnızca Setup değil).
- [ ] **3.3 Uygulama TAMAMEN kapalıyken** (soğuk başlangıç) aynı test.
- [ ] **3.4 Bildirimi kapatmış bir kullanıcıya push GİTMEMELİ**
      (`profiles.push_notifications_enabled = false`) — ama **e-posta yine
      gitmeli**. İkisi ayrı kanal.
- [ ] **3.5 Uygulamayı silip yeniden kur** → eski token artık geçersiz;
      sunucu `UNREGISTERED` alıp satırı silmeli (bir sonraki cron'dan sonra
      `push_tokens`ta ölü satır kalmamalı).

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
