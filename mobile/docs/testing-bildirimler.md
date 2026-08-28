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

## 1. Bildirim izni akışı

Tetikleyici bilerek açılış/giriş DEĞİL: **Canlı sekmesi açıldı VE en az bir
aktif oyun ya da bekleyen davet var.** Gerekçe: Android 13+'ta ikinci
reddin ardından sistem diyaloğu bir daha HİÇ gösterilmiyor.

- [ ] **1.1 Bağlamsız açılış.** Uygulamayı ilk kez aç, Canlı sekmesine
      GİRME → hiçbir izin penceresi çıkmamalı (ne bizimki ne sistemin).
- [ ] **1.2 Boş Canlı sekmesi.** Canlı sekmesini aç, hiç oyunun/davetin
      YOKKEN → yine hiçbir pencere çıkmamalı.
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
- [ ] **1.7 Android 12 ve altı** (varsa bir eski cihaz): sistem diyaloğu
      diye bir şey yok; bizim penceremiz çıksa bile "Aç" sessizce başarılı
      sayılmalı, çökme/uyarı OLMAMALI.

## 2. Token yaşam döngüsü (`push_tokens`)

DEĞİŞMEZ: **tabloda satır varsa o cihaz bildirim GÖSTEREBİLİR.** Her
açılışta kendini onarır — ayrı bir dinleyici yok.

Her adımdan sonra Supabase'de:
`select token, platform, user_id, updated_at from push_tokens;`

- [ ] **2.1 İzin verildikten sonra** satır oluşmalı, `platform` = `android`.
- [ ] **2.2 Sistem ayarlarından bildirimi KAPAT**, uygulamayı tamamen
      kapatıp yeniden aç → satır **SİLİNMELİ**. (Bu tam olarak bir kez
      kırıktı: temizlik bellekteki token'a güveniyordu, taze süreçte `null`
      olduğundan satır sonsuza kadar kalıyordu.)
- [ ] **2.3 Ayarlardan tekrar AÇ**, uygulamayı aç → satır geri gelmeli.
- [ ] **2.4 Çıkış yap** → satır silinmeli.
- [ ] **2.5 BAŞKA bir hesapla gir (aynı cihaz)** → satır sayısı ARTMAMALI;
      var olan satırın `user_id`'si değişmeli (anahtar token, kullanıcı
      değil).
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

## 5. Regresyon — push HİÇBİR ŞEYİ düşürmemeli

- [ ] **5.1 Firebase'siz yüzey:** GitHub Pages'teki Flutter **web**
      derlemesi hâlâ açılmalı (`initFirebase()` orada `false` dönüyor).
- [ ] **5.2 İzin hiç verilmemiş cihazda** oyun/Canlı oyun/sohbet akışlarının
      tamamı normal çalışmalı — push isteğe bağlı bir katman.
- [ ] **5.3 Uçak modunda** açılış: push kurulumu takılmamalı, Setup normal
      sürede gelmeli.
