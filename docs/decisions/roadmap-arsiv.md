# ROADMAP Arşivi — kapanmış maddeler ve sürüm turları

> **Bu dosya `ROADMAP.md`'nin geçmişi.** Orası yalnızca AÇIK maddeleri tutar;
> bir madde kapandığında (✅ / YAPILDI / KAPANDI / CANLIDA / SAHADA) **aynı
> PR'da** buraya taşınır. Kural kök `CLAUDE.md` → "İŞ BİTTİĞİNDE" tablosunda.
>
> **Sınıfı `reference`:** baştan sona okunmaz, GREP'lenir. Bir bölümü ararken
> başlığıyla ara — başlıklar taşınırken hiç değiştirilmedi, madde numaraları
> korundu, tek bir satır bile yeniden yazılmadı. Böylece koddaki ve öteki
> dokümanlardaki "ROADMAP → Faz 6", "madde 10" gibi atıflar bu dosyada
> karşılığını bulur.
>
> **İlk taşıma: 2 Eylül 2026.** Kullanıcı isteği: *"Kapanmışları arşive taşı,
> bundan sonra da kapanmışları düzenli kontrol edip taşı. ROADMAP'te sadece
> açık maddeler kalsın."* O gün ölçüldü: `ROADMAP.md`'nin **%45'i** kapanmış
> işti (109.329 → 58.054 karakter). Dosya 118 KB'a "eşik düşük olduğu için"
> değil, kendi 8. satırındaki kuralı (*"bir madde bitince buradan SİLİNİR"*)
> uygulamadığı için gelmişti.

## İçindekiler

| Ne | Kapanış |
|---|---|
| Madde 1 — `kelimeki://` deep link kanalı | 30 Ağustos 2026 (Faz 3'te ölçüldü) |
| Madde 6 — taranabilir `/nasil-oynanir/` sayfası | 31 Ağustos 2026 |
| Madde 10 — hata raporlama hız sınırı zamana bağlandı | 31 Ağustos 2026 |
| Madde 11 — hata panelinde platform filtresi | 31 Ağustos 2026 |
| Madde 2 — zorunlu güncelleme (Play'in kendi bildirimi yeterli) | 2 Eylül 2026 |
| Madde 8 — FAZ A1 Bölüm 6, iPad paylaş popover'ı (hata bulundu, düzeltildi, doğrulandı) | 3 Eylül 2026 |
| Madde 3 — davetlilere hatırlatma (kullanıcı: zaten yürüyen alışkanlık) | 2 Eylül 2026 |
| Madde 12 — sürüm dağılımının kapsamı | 31 Ağustos 2026 |
| Madde 13 — push bildirimleri + Firebase Analytics (spesifikasyon; gövdesi Faz 1-7'de) | 2 Eylül 2026 |
| Madde 16 — devam eden oyun kartlarının düzen ayrışması | 2 Eylül 2026 |
| Faz 1-7 + Faz dışı (push bildirimleri, madde 13'ün gövdesi) | 30-31 Ağustos, 1 Eylül 2026 |
| 1.0.3, 1.0.4 ve 1.0.5 sürüm turları | 31 Ağustos, 1 ve 2 Eylül 2026 |
| Sürüm A çıkışı + Sürüm B sözlük eklemeleri | 27 ve 31 Ağustos 2026 |

**1.0.5 sürüm turu da burada** (2 Eylül 2026 akşamı eklendi): ilk taşımada
ROADMAP'te bırakılmıştı çünkü üç işin cihaz doğrulaması ⬜'dü; kullanıcı aynı
gün *"1.0.5 turu testi tamam. Herşey düzgün çalışıyor."* deyince tur kapandı
ve kural gereği aynı gün taşındı.

---

### 🚀 1.0.4 SÜRÜM TURU — 31 Ağustos 2026

`appVersion` (`config/env.dart`) ve `pubspec.yaml` **birlikte** 1.0.3 → 1.0.4
yapıldı (`app_version_parity_test` ayrışmayı yakalıyor). `+N` build numarası
bağlayıcı değil — CI onu `--build-number=${{ github.run_number }}` ile eziyor.

Gün içinde "acil bir durum yok, toplu çıkarırız" denmişti; aynı gün akşam
toplu çıkarma kararı verildi. Sürüm İKİ PR ile tanımlandı; **1 Eylül'de
ÜÇÜNCÜSÜ eklendi — aşağıdaki nota bak.** İlk ikisi zaten `main`'deydi ve
yalnızca sürüm numarası bekliyordu:

| PR | Ne | Neden sürüm gerekiyordu |
|---|---|---|
| **#382** | Bildirim panelini temizleme (rozet gerçekten sıfırlansın, ROADMAP #15) + push token'a `app_version` damgası (#12) | Panel temizliği bir MethodChannel (`kelimeki/bildirimler` → `cancelAll()`); sürüm damgasını da İSTEMCİ yolluyor — kolon 31 Ağustos'ta canlıya alınmıştı ama 1.0.4'e kadar boş kalıyordu |
| **#383** | Telemetriden çıkan iki çökme: derin bağlantı rotası (11 cihaz) + rafta sınır dışı erişim | İkisi de saf istemci kodu |

Toplam 14 dosya, +572/−20 (`mobile/app/` altında).

⚠ **1 Eylül 2026 — SÜRÜM YÜKLENMEDEN ÖNCE İÇERİĞİ BÜYÜDÜ (#393 merge'i).**
1.0.4 paketi 31 Ağustos 20:17'de derlendi (**versionCode 461**) ama Play'e
yüklenmedi; kullanıcı "her gün update tester'da 'çok hata var' algısı
yaratır" diye ertesi güne bıraktı. O arada #393 merge edildi, `mobile-build`
`main`'de koştu ve **`mobile-latest`'teki `.aab`'yi üzerine yazdı**:

| | 461 | **467** |
|---|---|---|
| versionName | 1.0.4 | 1.0.4 (aynı) |
| Derleme kimliği | `72278c3` | **`cec6cbc`** |
| İçerik | #382 + #383 | #382 + #383 **+ ROADMAP #10** |

Yani yüklenecek paket **`467 (1.0.4)`** ve hız sınırı düzeltmesi de içinde.
Paketten doğrulandı (manifest + gömülü `BUILD_SHA` + o sha'nın ağacındaki
`_maxPerWindow`), tahmin edilmedi. 461 paketi artık release'te YOK.

**Ders:** `mobile-latest` her mobil derlemede üzerine yazıldığından, **henüz
Play'e yüklenmemiş bir sürüm numarası, merge edilen her yeni işi kendine
toplar.** "Bu iş şu sürüme biner" cümlesi ancak o sürüm SAHAYA ÇIKTIKTAN
sonra sabitlenir. Yükleme öncesi versionCode kontrolü (aşağıdaki uyarı) tam
da bu yüzden var — ve 1 Eylül'de gerçekten işe yaradı.

⚠ **Çakıştırma etiketi (#381) bu sürümde DEĞİL** — o sunucu tarafıydı ve
uygulandığı gün canlıya girdi. Bildirimlerin panelde BİRİKMESİNİ o durdurdu;
duran sayıyı SIFIRLAYAN yarı ise bu sürümde. İkisini karıştırma.

⚠ **Sahaya çıkış Play'in kendi takvimine bağlı** — merge + CI derlemesi
paketi üretir, mağazaya yüklemek ve incelemeden geçmek ayrı adım.

---

### 🚀 1.0.3 SÜRÜM TURU — ✅ **TAMAMLANDI** (31 Ağustos 2026)

`appVersion` (`config/env.dart`) ve `pubspec.yaml` **birlikte** 1.0.2 → 1.0.3
yapıldı (`app_version_parity_test` ayrışmayı yakalıyor). `+N` build numarası
bağlayıcı değil — CI onu `--build-number=${{ github.run_number }}` ile eziyor.

**Bu sürümün taşıdıkları** (hepsi `main`'de):

| Konu | Kayıt |
|---|---|
| Faz 3 — bildirime dokununca tahtayı açma + Firebase Analytics | ROADMAP Faz 3 · `mobile/docs/testing-bildirimler.md` §3c |
| Kart/ikon cilası (SIRA SENDE üçgeni, kırmızı nokta, süre metni) + `PersonPendingIcon` | ROADMAP "Faz dışı" |
| Sözlük: `lapis`, `mö`, `banu`, `banü` (madde 1.5) + `çilav`, `kanola`, `refil`, `sü`, `tarot` | `docs/decisions/dictionary.md` |
| Skor kutusu çerçevesi: kırpılan sağ kenar (`outlineOffset` = −genişlik) | `docs/decisions/components.md` → `GameHeader` |
| Pasif çerçeve kalınlığı 0.5 → 1 (web ile hizalı) | aynı madde |
| Bekleyen oyun sıralaması: sıra sende → son oynanan | `docs/decisions/live-game.md` |

**Sözlük hazır:** `words_tr.txt` 63.905 kelime, dokuz yeni maddenin hepsi
asset'te doğrulandı; `meanings.db` de yeniden üretilmişti.

**SIRA KURALI** (`mobile/CLAUDE.md` → "Güncelleme"), atlanamaz:

1. ✅ `appVersion` + `pubspec` birlikte artırıldı.
2. ✅ Derlendi (koşu #449, sha `c1c0437`, versionCode 449) ve Play kapalı
   teste yüklendi.
3. ✅ **İndirilebilirlik doğrulandı** — kullanıcı cihazında Kurulum
   ekranındaki teşhis satırı `Derleme c1c0437` gösterdi.
4. ✅ Eşiğe DOKUNULMADI (bilinçli — aşağıdaki uyarı).

⚠ Kapı **fail-open**, yani asıl risk ağ değil SIRA: 4'ü 3'ten önce yapmak
herkesi indirilemeyen bir güncellemeye yönlendirmek demek.

⚠ **Eşiği bu turda RUTİN olarak yükseltme.** In-App Update 1.0.2'den beri
devrede; `app_config.mobile_min_supported_version` yalnızca "eski istemciyi
bir sunucu değişikliği kırdı" durumunda çekilir. (1.0.0 kitlesini süpürmek
için bir kereye mahsus 1.0.2'ye çekme kararı ayrı — bkz. aşağıdaki 7. madde.)

**Sürüm çıktıktan sonra cihazda koşulacaklar:** `mobile/docs/testing-bildirimler.md`
§3c (bildirime dokunma → tahta), §3d (sıra sende — sunucu tarafı zaten
doğrulandı), GA4 DebugView olayları, ve **ilk gerçek In-App Update testi**
(yalnızca Play'den kurulmuş pakette çalışır, yan yüklenmiş `.apk`da sessizce
`bilinmiyor` döner).

✅ **TUR KAPANDI (31 Ağustos 2026).** `.aab` Play'e yüklendi, duyuru
gönderildi, testçiler indirdi.

⚠ **In-App Update'in İLK SAHA KANITI GELDİ** — kullanıcı bildirdi:
*"Kelimeki'yi tekrar açınca uyarı geldi ve oradan güncelledim."* Yani
Immediate akışı Play'den kurulmuş gerçek pakette uçtan uca çalışıyor; bu
madde artık "yazıldı ama denenmedi" değil.

✅ **§3c'nin çekirdeği 31 Ağustos akşamı cihazda doğrulandı** (1.0.3):
bir oyun bildirimine hem uygulama arka plandayken hem de TAMAMEN KAPALIYKEN
dokunuldu, ikisinde de Canlı tahta doğrudan açıldı. Soğuk başlangıç ayrı bir
API yolu (`getInitialMessage`) olduğu için asıl kıymetli olan o. Davete özgü
dallar (davet beklemedeyken → Arkadaşınla sekmesi), girişsiz derin bağlantı
ve GA4 DebugView hâlâ açık — kayıt: `mobile/docs/testing-bildirimler.md` §3c.

⚠ **`mobile-latest` prerelease'i hangi sürümü taşıyor — HER SÜRÜM TURUNDA
YENİDEN SOR.** O release her mobil derlemede üzerine yazılıyor. 1.0.3
döneminde bu bir TUZAKTI: sonraki merge'ler versionName'i 1.0.3'te bırakıp
versionCode'u artırdığı için oradan Play'e yükleme yapmak herkese gereksiz
güncelleme uyarısı gönderecekti (1.0.3 için yüklenen tek paket koşu
#449'unki). **1.0.4'te durum tersine döndü:** sürüm numarası bu turda
artırıldığından, 1.0.4 merge'inden SONRA üretilen paket Play'e yüklenecek
olandır. Kural şu: paketi yüklemeden önce versionName'in beklediğin sürüm
olduğunu doğrula; "mobile-latest her zaman güvenli/güvensiz" diye sabit bir
cevap YOK.

---

### Faz 1 — bekleyen paket · ✅ **SAHADA** (1.0.3 ile, 31 Ağustos 2026)

Altı maddenin altısı da `claude/kelimeki-phase-1-remaining-*` dalında bitti;
kalan tek iş **merge + sürüm turu** (kullanıcı "şimdi gönder" diyene kadar
PR açılmıyor). Kayıtları taşındı, burada yalnızca paketin envanteri kaldı:

| # | İş | Kullanıcıya görünür mü | Kaydı |
|---|---|---|---|
| 1 | Hamle rozeti dolgusu `3/6` → `1.5/3` (1,22 → 0,98 hücre) | ✅ kapalı testte BİLDİRİLDİ | Parça 167 · `docs/decisions/components.md` → `Board` |
| 2 | Rozet puntosu: **web porta getirildi** (sabit 11px + sans) | ✅ (web'de) | Parça 169 · aynı `Board` maddesi |
| 3 | Alt şerit Android'de ortaya kümeleniyordu (`Wrap` genişliği doldurmuyor) | ✅ kapalı testte BİLDİRİLDİ | Parça 170 |
| 4 | Yaş/cinsiyet satırı geri geldi (#370'in revert'ü) | ✅ istenen özellik | Parça 166 |
| 5 | `drainRealIo` flake'i: üç kopya tek kaynağa, tek `pump()` → dilimli | ✖ yalnız CI | Parça 168 |
| 6 | Doküman borcu: bayat "bekleyen deploy" uyarısı silindi + Play kapalı test notu | ✖ | Parça 168 · `mobile/docs/build-and-distribution-log.md` |
| 7 | **Play In-App Update** — açılışta yeni sürüm varsa uyar ve yaptır | ✅ **bundan sonraki HER sürümü etkiler** | Parça 171 · `mobile/CLAUDE.md` → "Güncelleme" |

**Üçü kapalı testten gelen gerçek şikayet** (1, 3 ve 4'ün isteği) — paketin
bekletilmesinin bedeli doğrudan bu üç kişinin beklemesi.

⚠ **7. madde bu paketi özel kılıyor:** In-App Update kodu 1.0.2'nin İÇİNDE,
yani sahadaki 1.0.0 kitlesi (ölçüldü: 93'e 2) onu ancak 1.0.2'ye geçtikten
sonra görür. 1.0.2 yayınlanıp **indirilebilir olduğu doğrulandıktan sonra**
eşik bir KEZ 1.0.2'ye çekilip o kitle süpürülür; ondan sonra eşik bir daha
yükseltilmez. Ayrıntı: `mobile/CLAUDE.md` → "Güncelleme — Play SORAR".

**Sunucuda yapılacak iş YOK:** `get_profile_age_gender` canlıda ve
migration dosyası `main`'de duruyor (29 Ağustos'ta `pg_proc`'tan doğrulandı:
`security definer`, `TABLE(age integer, gender text)`).

⚠ **Sürüm turunda:** `appVersion` + `pubspec` birlikte artırılmalı
(`app_version_parity_test` ayrışmayı yakalar) ve zorunlu güncelleme eşiği
sırası korunmalı — `mobile/CLAUDE.md` → "Zorunlu Güncelleme".

---

### Faz 2 — davet bildirimleri · ✅ **CANLIDA** (30 Ağustos 2026)

Üç fonksiyona push kanalı eklendi ve deploy edildi — sürüm gerekmedi, sahadaki
paket token'ı zaten kaydediyordu:

| Fonksiyon | Sürüm | `verify_jwt` | Bildirim |
|---|---|---|---|
| `notify-game-invite` | 9 | true | *Canlı oyun daveti* — `kelimeki://oyun/<id>` link'iyle |
| `notify-friend-request` | 9 | true | *Yeni arkadaşlık isteği* |
| `notify-friend-request-reminders` | 9 | false | *Bekleyen arkadaşlık isteğin var* |
| `notify-deadline-warnings` | 12 | false | (aşağıdaki hata düzeltmesi) |

**Üç kopya yerine ortak yardımcı:** `_shared/push.ts` → `sendPushToUser()`.
Hiçbir koşulda fırlatmıyor, yalnızca `push_notifications_enabled`e bakıyor,
bayat token'ı siliyor, kaç cihaza gittiğini döndürüyor (teşhis).

⚠ **YOLDA BULUNAN CANLI HATA — düzeltildi.** `notify-deadline-warnings`
(o güne dek push taşıyan TEK fonksiyon) `email_notifications_enabled`
kapalıysa `continue` ediyor, push çağrısı ise ondan sonra geliyordu: yani
e-posta bildirimini kapatan kullanıcı **push da alamıyordu.** Dosyanın kendi
yorumu iki tercihin BAĞIMSIZ olduğunu söylüyordu, kodu tutmuyordu. Dördünde
de e-posta tercihi artık YALNIZCA e-postayı kapatıyor.
**Bugün kimseyi etkilemiyordu** (ölçüldü: 48 profilin hiçbirinde e-posta
kapalı değil) — gizli bir hataydı, üç yeni fonksiyona kopyalanmadan yakalandı.

**Deep link bilinçli olarak ŞİMDİ gönderiliyor:** oyun daveti push'u
`kelimeki://oyun/<id>` taşıyor. İstemci bugün okumuyor (Faz 3), ama sunucu
tarafı zaten bunun için tasarlanmıştı; Faz 3 gelince bu bildirimler geriye
dönük çalışır hâle gelecek.

**Doğrulama sınırı:** bu ortamda Deno YOK (`_shared/push_test.ts` koşmadı) ve
`*.supabase.co`ya çıkılamıyor (fonksiyonlar tetiklenemedi). TypeScript
derleyicisiyle dördü de temiz ayrıştı; deploy sonrası `list_edge_functions`
ile dört sürüm ve dört `verify_jwt` değeri tek tek doğrulandı. **Gerçek
kanıt sahadan gelecek:** üç yanıt da artık `pushed` sayacı döndürüyor.

---

### Faz dışı — kart/ikon cilası + bir hata (30 Ağustos 2026) · web ANINDA, port ✅ 1.0.3'le SAHADA

Faz 2'yle aynı dalda gitti ama fazın parçası DEĞİL: Canlı/Setup oyun
kartlarının metin-punto-işaret düzeni (`SIRA SENDE` + yeşil üçgen ↔
`SIRA RAKİPTE` + kırmızı nokta, sayaç `… sonra teslim (-2 puan)`) ve ilişki
ikonu ailesinin tamamlanması. **Yanında GERÇEK bir hata:** skor kartı
ilişki simgesini dört durum yerine ikiye indirdiğinden, bekleyen arkadaşlık
isteği olan kişide "arkadaş ekle" ikonu çıkıyor, dokununca "İsteği İptal Et"
diyordu. Gerekçeler/ölçümler: `docs/decisions/live-game.md`,
`docs/decisions/components-account.md`, `mobile/docs/parca-log.md` Parça
172-173.

---

### Faz 3 — deep link + bildirime dokunma + Analytics · ✅ **SAHADA** (1.0.3 ile, 31 Ağustos 2026)

İstemci tarafının tamamı yazıldı ve 652 testle yeşil; kullanıcıya ancak bir
SONRAKİ sürümle ulaşır (Faz 1'in "kod hangi sürümdeyse o sürümden itibaren"
kuralı). Sunucuda değişiklik YOK — `data.link` Faz 2'den beri zaten
gidiyordu, bu faz onu okuyan yarıyı ekledi.

- **Deep link kanalı:** işe başlarken ÖLÇÜLDÜ ki madde 1'in platform yarısı
  zaten bitmişti — manifest'in iki intent filtresi, Info.plist URL şeması,
  `parseDeepLink`teki `KOnlineGameLink` dalı yerindeydi. Eksik olan yalnızca
  YÖNLENDİRMEYDİ; ROADMAP'in "üç platform yapılandırması aynı anda" korkusu
  bayattı (o iş Parça 87/158'de parça parça yapılmış).
- **Bildirime dokununca doğru yere gitme — YAZILDI:** `FirebasePushTapSource`
  (`onMessageOpenedApp` + `getInitialMessage` → `data.link`) +
  `GameLinkInbox` (app_links URI'ları da aynı kapıya düşer) + `_HomeGate`
  yönlendirmesi. Üç dal: oyun AKTİFSE Canlı tahta doğrudan açılır
  (`open_online_game.dart` — LiveGamesTab'ın 14 parametrelik kurulumuyla
  ORTAK, iki kapı tek fonksiyon); davet beklemedeyse/oyun listede yoksa
  Arkadaşınla sekmesi (`liveTabRequests` sayacı); girişsizken link
  BEKLETİLİR, giriş gelince işlenir. Üçü de widget-testli, dinleyici
  kablosunun negatif eşi doğrulandı.
- **Firebase Analytics — YAZILDI:** global `analytics` (errorReporter
  deseni; fire-and-forget, yapılandırılmamışken no-op) + ilk altı olay:
  `intro_slide_viewed{index}` · `signup_started` · `signup_completed` ·
  `live_game_form_opened` · `live_game_created{player_count,with_ai}` ·
  `invite_link_shared{source: friends_modal|setup_footer}`. Altı yer de
  mevcut widget testlerine bağlandı. ⚠ `invite_link_shared` paylaşım
  SAYFASININ açılmasını sayar — "gerçekten gönderildi" bilgisi share_plus'ta
  güvenilir değil ve öyleymiş gibi adlandırılmadı.
- **Doğrulama sınırı:** FCM dokunuşu ve GA4 olay akışı bu ortamda uçtan uca
  koşulamaz (Firebase cihaz ister) — cihaz kontrolleri
  `mobile/docs/testing-bildirimler.md` §3c'de; Play imzalı 1.0.3 derlemesi
  gerektirir. `notify-game-invite`'ın "link bugün istemci tarafından
  okunmuyor" yorumu artık bayat ama dosyaya BİLEREK dokunulmadı: yorum
  düzeltmesi için Edge Function deploy'u (canlıya anında etki) yapılmaz;
  ilk gerçek değişiklikte güncellenecek.

---

### Faz 4 — "sıra sende" · ✅ **CANLIDA** (30 Ağustos 2026) · sunucu, sürüm gerektirmedi

İki adımda deploy edildi ve canlıdan doğrulandı: `notify-your-turn` Edge
Function v1 (verify_jwt FALSE — sayım yedi → SEKİZ, kök CLAUDE.md listesi
güncellendi) + trigger migration'ı
(`20260830194913_notify_your_turn_trigger.sql` — dosya adı canlı versiyonla
`git mv` ile eşitlendi). Doğrulama: trigger `online_game_states`te kayıtlı,
bastırma fonksiyon gövdesinde, client rollerine grant yok. Deploy anından
itibaren SAHADAKİ HER İSTEMCİNİN (1.0.1/1.0.2 dahil) hamlesi bildirim
üretir; dokunuşun tahtaya götürmesi 1.0.3'ü bekler (Faz 3). Cihaz kontrol
listesi: `mobile/docs/testing-bildirimler.md` §3d.

✅ **SAHA KANITI GELDİ (30 Ağustos 2026, aynı gün).** Kullanıcı bildirdi:
*"bana ilk sıra sende bildirimi geldi, tıkladım app'e gitti"* — yani
zincirin tamamı (trigger → pg_net → Edge Function → FCM → cihaz) uçtan uca
çalışıyor. Sunucudan doğrulandı: `function_edge_logs`'ta ilk üç saatte
**dokuz çağrı, hepsi 200** (273–2743 ms). Çağrılar dört ayrı testçinin
(Ironman · Fb1907 · Minka · Zesiner) yedi ayrı oyununa dağılıyor; aynı
hedefe aynı oyunda 10 dk içinde İKİNCİ çağrı YOK, yani bastırma da sahada
çalışıyor.

⚠ **Ölçüm bir ürün sorusu doğurdu (henüz karar YOK):** bastırma
`online_game_id` başına — 20:02:54 ve 20:03:23'te aynı hedefe 29 saniye
arayla iki çağrı gitti, çünkü İKİ FARKLI oyunda sırası geldi. Tasarım gereği
doğru (ikisi de gerçek bir "sıra sende"), ama beş eşzamanlı oyunu olan bir
kullanıcı bir dakikada beş bildirim alabilir. Şikayet gelirse çare kişi
başına bir pencere (ör. "aynı kullanıcıya 2 dk içinde en çok bir bildirim,
gövdede 'N oyunda sıran geldi'") — bugünkü tek satırlık oyun-içi bastırmadan
farklı bir mekanizma olur.

**Dokunuşun tahtaya götürmesi HÂLÂ 1.0.3'ü bekliyor** — kullanıcının
"app'e gitti" gözlemi bugünkü doğru davranış, hata değil (§3c).

**Tetikleyici istemci DEĞİL, sunucu:** `online_game_states.current`
ilerleyince koşan trigger (`_notify_your_turn`) — `submit_move`u (insan VE
YZ hamleleri) ve `check_turn_timeout`un devir dalını TEK yerden yakalar;
"SÜRÜM GEREKTİRMEZ" vaadi ancak böyle tutar (istemciden çağrılsaydı
sahadaki 1.0.2 hamleleri bildirim üretmezdi). Desen `_notify_welcome_email`
emsali (trigger → koşullar → `net.http_post`).

**İki tuzağın çözümü:** hamleyi yapana gönderme YAPISAL olarak imkânsız
(hedef, hamle SONRASI current koltuğu); spam bastırması hedef oyuncunun son
10 dk içindeki kendi hamlesine bakıyor — zaten oyunun başındaysa http_post
HİÇ yapılmıyor (`online_game_moves.created_at`, ek kolon yok).
`deadline_warning_sent_at` benzeri atomik-iddia kolonu GEREKMEDİ: olay
hamle başına doğal olarak tekil.

**Güvenlik:** fonksiyon hedefi gövdeden ALMAZ — `online_game_id`yi alır,
current'ı/`is_game_over`ı service-role ile kendisi okur; verify_jwt kapalı
bir uca keyfi `target_user_id` geçirtmek herkese push tetikletmek olurdu.

E-posta kanalı BİLEREK yok (#13 tablosu: bu olayın e-posta geçmişi hiç
olmadı; teslim uyarısı e-posta tarafını karşılıyor). Metin kullanıcı onaylı
(30 Ağustos): *"Sıra sende!"* / *"{isim} hamlesini yaptı — {n} kişilik
oyunda sıra sende."* + `kelimeki://oyun/<id>` — 1.0.3+ istemcide dokunuş
tahtayı doğrudan açar, eskisinde yalnızca uygulamayı açar (Faz 2'deki davet
linkiyle aynı geriye-dönük kazanım).

**Neden Faz 3'ten SONRAYDI:** bildirime dokunma yönlendirmesi olmadan "sıra
sende" kullanıcıyı oyuna götüremezdi; Faz 3 kodu artık main'de.

---

### Faz 5 — bildirim çakıştırma (etiket) · ✅ **CANLIDA** (31 Ağustos 2026) · sunucu, sürüm gerektirmedi

Kullanıcı bildirdi: uygulama simgesindeki rozet **9**'da takılı kalıyor,
bildirime dokunup uygulamaya girmek onu sıfırlamıyor. Teşhis iki parçalı ve
ikisi de koddan doğrulandı:

1. **Rozet uygulamanın sayacı DEĞİL.** Samsung One UI onu, uygulamanın
   panelde HÂLÂ DURAN bildirimlerinden türetiyor. Dokunmak yalnızca O
   bildirimi kapatıyor (9 → 8); kalanları temizleyen bir kod yok —
   `mobile/app/pubspec.yaml`'da `flutter_local_notifications` yok ve
   `firebase_messaging` `cancelAll()` sunmuyor.
2. **Neden 9'a tırmandı:** FCM yükünde `android.notification.tag` yoktu,
   yani aynı oyunun her "sıra sende"si panelde YENİ bir satır açıyordu.

Bu faz 2'yi çözüyor: `_shared/push.ts` artık `PushMessage.tag` taşıyor →
`android.notification.tag` + iOS `apns-collapse-id` (iOS henüz canlı değil,
başlık o gün için hazır duruyor). **Tür öneki ZORUNLU**, çünkü etiket alanı
düz bir isim alanı — `sira:` · `davet:` · `sure:` · `sure-yerel:` ·
`arkadas:`. Son önek bilinçli olarak PAYLAŞILIYOR: arkadaşlık isteği ile 3
gün sonraki hatırlatıcısı aynı işi anlattığından hatırlatma eskisinin yerine
geçiyor.

**Deploy:** beş fonksiyon (`notify-your-turn`, `notify-game-invite`,
`notify-friend-request`, `notify-friend-request-reminders`,
`notify-deadline-warnings`) — `verify_jwt` değerleri deploy ÖNCESİ okundu ve
SONRASI doğrulandı, hiçbiri değişmedi. Sürümden bağımsız: sahadaki 1.0.0
dahil herkeste çalışır.

**Testi:** `npm run verify-push-payload` (22 kontrol) — yükün ŞEKLİNİ
doğruluyor, çünkü `tag` yanlış seviyeye yazılırsa FCM 400 DÖNDÜRMEZ, alanı
sessizce yok sayar; hata ancak "rozet hâlâ birikiyor" olarak haftalar sonra
görünürdü. İki negatif eş koşuldu: etiketi kaldırınca 2 kontrol, yanlış
seviyeye yazınca 1 kontrol GERÇEKTEN düşüyor. (`_shared/push_test.ts`
Deno istiyor ve bu ortamdan Deno indirilemiyor — proxy 403; bu betik onun
Node'da koşabilen tamamlayıcısı.)

⚠ **1'i ÇÖZMÜYOR — rozet hâlâ kendiliğinden sıfırlanmıyor.** Bu iş 1.0.4'e
kaldı: uygulama öne gelince paneli temizlemek. Gerekli olan yeni bir
bağımlılık (`flutter_local_notifications` → `cancelAll()`) ya da küçük bir
MethodChannel; yani DERLEME ister, 1.0.3'ün `.aab`'si yüklenirken
yakalanamazdı. Cihaz listesi: `mobile/docs/testing-bildirimler.md` §3e —
orada "rozet 0 oldu" ARANMIYOR, aranan şey rozetin bekleyen AYRI İŞ
sayısını göstermesi.

---

### Faz 6 — rozet sıfırlama (#15) + "kaç kişi hangi sürümde" (#12) · sunucu ✅ CANLIDA, istemci ✅ **1.0.4 (467) İLE ÇIKTI** (1 Eylül 2026)

⚠ Bu başlık 2 Eylül'e kadar *"istemci 1.0.4 BEKLİYOR"* diyordu ve BAYATTI:
1.0.4 (467) 1 Eylül'de Play'e yüklendi, yani bekleyen bir iş kalmamıştı.
Aynı sınıf hata bu dosyada üçüncü kez (bkz. "Console (elle)" satırı) —
sebep hep aynı: kaydın İKİ yerde durması. **Yayının kanonik kaydı
`mobile/docs/build-and-distribution-log.md` → "Yayınlanan sürümlerin
kütüğü"**; buradaki faz notları neyin YAPILDIĞINI anlatır, neyin
yayında olduğunu değil.

Tarihçe (o günkü karar): kullanıcı 31 Ağustos'ta *"Yap ama henüz yeni
versiyon çıkarmıyoruz. Tüm işlerle (bundan sonraki) toplu çıkartırız."*
demişti; `pubspec.yaml`/`env.dart` bilerek 1.0.3'te bırakıldı ve toplu
sürüm ertesi gün 1.0.4 oldu. Sunucu yarısı ise merge'den bağımsız CANLIydı
(migration + RPC anında uygulandı).

**#15 — rozet gerçekten sıfırlansın.** Faz 5 birikmeyi durdurdu ama
sıfırlamayı değil: panelde duran bildirimler orada kalıyordu. Artık uygulama
öne geldiğinde (`_HomeGate.didChangeAppLifecycleState`) **ve soğuk
başlangıçta** (`initState` — bildirime dokunup açmak bu yoldan gelir ve
yaşam döngüsü orada HİÇ tetiklenmez) panel temizleniyor.

*Eklenti DEĞİL, MethodChannel:* `firebase_messaging` "hepsini temizle"
sunmuyor; standart yol `flutter_local_notifications` olurdu ama tek
ihtiyacımız `cancelAll()` ve o paket karşılığında kendi başlatma çağrısını +
bildirim ikonu yapılandırmasını + bir bağımlılığı getirirdi. Depo zaten
Kotlin'e iniyor (`MainActivity` bildirim KANALINI elle yaratıyor) ve o
deseni bir parite testiyle koruyor. iOS bilerek YOK: rozet orada
`aps.badge`den gelir, sunucu onu hiç göndermiyor — yani sıfırlanacak rozet
de yok; APNs günü `AppDelegate.swift`e aynı kanal adıyla bir işleyici
eklemek yeterli, Dart tarafı değişmez.

**#12 — "kaç kişi yenide?"** Kullanıcı 1.0.3 duyurusundan sonra sordu ve
cevaplanamadı; sebep ölçüldü: `app_version` damgası yalnızca `game_starts`
ve `client_errors`ta vardı. Yani sürüm ancak biri YZ'li YEREL oyun açınca ya
da HATA alınca görünüyordu — yalnız Canlı oynayan hiç görünmüyordu — ve port
`anon_id` göndermediğinden orada KİŞİ de sayılamıyordu (eldeki tek şey "kaç
OYUN açıldı"). Çözüm `push_tokens.app_version`: satır `user_id` ile anahtarlı
ve token her açılışta hizalanıyor, yani oyun oynanması gerekmiyor.

| Yüzey | Durum |
|---|---|
| `push_tokens.app_version` + `register_push_token`ın 3. parametresi | ✅ CANLI |
| `admin_push_version_breakdown` RPC'si | ✅ CANLI |
| Admin paneli → Büyüme > Kullanıcı → **"Kurulu Sürümler — Kişi"** | ✅ web'e merge ile |
| Dart: `PushRepo.appVersion` → RPC | kod tamam, DERLEME bekliyor |

⚠ **Eski 2 parametreli `register_push_token` DÜŞÜRÜLDÜ, üstüne yazılmadı.**
`p_app_version`in varsayılanı olsa bile iki fonksiyon yan yana dursaydı 2
argümanlı bir çağrı ikisine birden uyup **"function is not unique" (42725)**
verirdi — yani "geriye dönük uyumluluk için eskisini bırakalım" refleksi
burada TAM TERSİ sonuç verirdi. Sahadaki 1.0.0–1.0.3'ün hâlâ çözüldüğü
canlıda kanıtlandı: 2 argümanlı çağrı 42883/42725 değil, fonksiyonun kendi
`P0001 / Oturum gerekli.` hatasını veriyor.

⚠ **Damga GERİYE DÖNÜK DOLDURULAMAZ** (`games.platform`/`game_starts.app_version`
ile aynı sınıf): bir cihaz yeni sürümle açılana kadar `bilinmiyor` kalır.
Yani panelde ilk günlerde "—" ÇOĞUNLUK olacak; bu kolonun doğum tarihi,
arıza değil.

**Kapsam farkı bilinçli — iki tablo YAN YANA duruyor, biri diğerinin
kopyası değil:** "Sürüm Dağılımı" (`game_starts`) misafir dahil herkesi
görür ama yalnızca YZ oyunlarını ve OYUN AÇILIŞI sayar; "Kurulu Sürümler"
(`push_tokens`) KİŞİ sayar ve oyun beklemez ama yalnızca giriş yapmış +
bildirim izni vermiş kişileri görür.

---

### Faz 7 — telemetriden çıkan iki çökme · ✅ **1.0.4 (467) İLE ÇIKTI** (1 Eylül 2026)

Kullanıcı isteği: *"Admin Hatalar bölümündeki loglara bakıp önemli bir
şeyler var mı kontrol et."* 30 günde 31 kayıt vardı; ikisi gerçek hataydı.
⚠ İkisi de İSTEMCİ değişikliğiydi ve sıradaki toplu sürümle çıktı:
**1.0.4 (467), 1 Eylül 2026.** (Bu satır 2 Eylül'e kadar "sıradaki toplu
sürümle çıkar; sürüm yine yükseltilmedi" diyordu — bayattı.)

**1. Derin bağlantı çökmesi — 11 CİHAZ.** `boundary /
Null check operator used on a null value`, 26–29 Ağustos, dört ayrı
derleme. Yığın izi mekanizmayı tek başına söylüyordu:
`_onUnknownRoute ← pushNamed ← didPushRouteInformation`. Bir linke
dokunulunca platform uygulamaya ROTA gönderiyor, Flutter onu `pushNamed`le
açmaya çalışıyor, tanımadığı için `widget.onUnknownRoute!` diyor — o alan
BOŞTU.

⚠ **"Düzelmişti" DEĞİLDİ.** Kayıtların hepsi `1.0.0` etiketliydi ve son
olay 29 Ağustos'taydı, ama bu bir düzeltmenin sonucu değil: `onUnknownRoute`
kodda HİÇ olmadı (`git log -S` boş döndü) ve 29 Ağustos'ta konuyla ilgili
bir commit yok. 26–29 Ağustos, cihaz testinin derin bağlantı turuydu; olay
görülmeyi bıraktı, yol açık kaldı. **Ve risk şimdi ARTIYOR:** App Link
doğrulaması yalnızca Play'den kurulan derlemede geçiyor (manifest'in kendi
notu) ve Play dağıtımı 30 Ağustos'ta başladı — yani
`https://kelimeki.com/davet/...` linkine dokunup uygulamayı açabilecek
kitle yeni oluştu. Şifre sıfırlama (`kelimeki://reset`) de aynı kapıdan
geçiyor.

İKİ KATMAN, biri diğerinin yerini tutmuyor:
`AndroidManifest.xml → flutter_deeplinking_enabled=false` (motor rotayı HİÇ
göndermez — asıl kapatma, testle kilitli) + `ui/app.dart → onUnknownRoute`
(bir şey yine de gönderirse çökme yerine sessizlik; iOS'u ve gelecekteki
intent-filter'ları da kapsıyor). Rotayı "açmak" bilinçli olarak
YAPILMADI: linkleri `app_links` yakalıyor, ikinci bir yönlendirme kaynağı
onunla yarışırdı.

**2. Rafta sınır dışı erişim.** `RangeError (length): Not in inclusive
range 0..5: 6`, 26 Ağustos, route=game. `RackWidget` dokunma kutularını
ÇİZİLDİĞİ ANDAKİ raf uzunluğuna göre kuruyor; parmak indiğinde raf
kısalmışsa `rack[i]` sınır dışına düşüyor.

⚠ **Aynı desen `online_game_screen.dart`ta da vardı** (CLAUDE.md'nin ikiz
dosya kuralı) ve orada risk DAHA YÜKSEK: yerel oyunda rafı yalnızca sen
kısaltırsın, Canlı oyunda sunucudan gelen realtime güncelleme parmağın
altında kısaltabilir. Üçüncü bir örnek `_handleConfirmSwap`taydı
(`swapSelection` indeksleri) — orada eksik harfle göndermek yanlış olurdu,
o yüzden filtrelemek yerine gönderim İPTAL ediliyor.

**Testler negatif eşleriyle:** `unknown_route_test` gerçek
`flutter/navigation` kanalından besliyor (düzeltme kaldırılınca Flutter'ın
kendi *"Unfortunately, onUnknownRoute was not set"* mesajıyla düşüyor);
`rack_index_race_test` sahada çöken GERÇEK closure'ı ağaçtan alıp sınır
dışı indeksle çağırıyor (kaldırılınca `RangeError` ile düşüyor); manifest
bayrağı `true` yapılınca da ayrı bir kontrol düşüyor. Yarışı zamanlamayla
üretmek BİLEREK denenmedi — widget testinde raf kısaldıktan sonra o kutu
zaten çizilmiyor, taklit kırılgan ve yalancı bir test olurdu.

**Aksiyon alınmayanlar (kayıt için):** oturum/JWT ailesi (10 olay — `JWT
issued at future` ×6 cihaz saati ileri, `permission denied for function
list_my_online_games` ×2, `JWT expired`, `Refresh Token Not Found`). Grant
canlıdan kontrol edildi ve DOĞRU (`authenticated` var, `anon` yok) — yani
eksik yetki değil, geçersiz oturumla çağrı. Hata değil, kötü mesaj; bir gün
"oturumun düşmüş" metnine çevrilebilir. `Error invoking postMessage` (7
olay) Instagram'ın uygulama içi tarayıcısından, bizim kodumuz değil.

---

### 1. Sürüm A ÇIKTI · Sürüm B kuyruğu açıldı (27 Ağustos 2026)

Kuyruk bir kez boşaldı. Sıra şuydu ve bir daha aynen izlenmeli:

**Sürüm A — merge edildi (`f9c3846`, PR #355), paket `1.0.0 (403)`.**
Kapalı testten gelen dört düzeltme: dokunma hedefleri (✕'ler 28/40 → 48,
raf taşı 46×46 → 49×65), "Ara & Ekle"de yutulan kaydırma, "Arkadaşınla"
rozetinin kendini toparlaması, `slots.length` telemetri koruması. Sunucu
tarafı (`20260827121628`, `20260827153857`) zaten canlıydı, merge'i
beklemedi.

⚠ **Test edilen artefakt ile mağazaya giden artefakt AYNI olmalı.** İlk
planım "dalda APK üret, test et, sonra merge et, mağazaya main'in `.aab`'sini
yükle" idi; kusuru şu ki o ikisi FARKLI derlemeler olurdu (ayrı sha, ayrı
paket numarası) — bu projenin en pahalı dersi ("düzelttim ≠ canlıda")
tam olarak budur. Doğru sıra: **PR CI yeşil → merge → `main` koşusunun
`.apk`'sıyla cihazda test → AYNI koşunun `.aab`'si mağazaya.** Dalda ayrı
bir test derlemesi üretmek ayrıca `mobile-latest`'i merge edilmemiş kodla
ezerdi (PR kapısının var olma sebebi).

**Sürüm A2 — dokunma isabeti paketi (27 Ağustos 2026, kullanıcı kararı:
*"Bence deep link ve push'u B'de bırakalım. Diğer hepsini A'ya koy"*):**

A'nın cihaz testi sırasında beş düzeltme daha birikti ve hepsi AYNI
sınıftan — dokunma isabeti, hepsi kapalı testte gerçek kullanıcıların
takıldığı yerler. Kuyrukta bekletmek yerine ikinci bir A sürümüyle
çıkıyorlar:

| Düzeltme | Nerede | Kullanıcıya etkisi |
|---|---|---|
| Taslak taşı geri alma: ilk dokunuş yakalamıyordu | `game_screen.dart` + `online_game_screen.dart` + web ikizi | Iskalama artık boş komşu hücreden de kurtarılıyor (yalnızca seçim yokken) |
| Joker harf ızgarası (48×44 → 48×50) | `wild_letter_sheet.dart` + `WildcardModal.tsx` | Yanlış harf seçtiren ıskalamalar |
| Oyun kartı ikonları (13 → 41 px etkin hedef) | `icon_tap_rescue.dart` + `.tap-expand-y` | Kalp/mesaj/hamle: uygulamanın en küçük üç hedefi |
| Tanıtım "DEVAM ›" | `intro_screen.dart` | Tam genişlik + ekranın dibi + ortalı değildi |
| Tanıtım son slaydındaki nokta şeridi | `intro_screen.dart` | Gereksiz ve yanıltıcıydı ("daha var" diyor ama yok) |
| **Titreşimli dokunuş kayboluyordu** | `game_screen.dart` + `online_game_screen.dart` + web ikizi | Aşağı bkz. — asıl şikayeti çözen düzeltme buydu |

**A2 İKİ derlemede çıktı ve ikincisi asıl önemlisi.** İlk paket
(`1.0.0 (405)`, `24c5b0c`) cihazda denenince kullanıcı aynı şikayeti
TEKRARLADI: *"Hâlâ tahtaya koyulan taşı her zaman alamıyorum."* Üstteki beş
düzeltme yetmemişti çünkü hepsi hedefin ALANIYLA ilgiliydi; sorun ise
JESTTEYDİ.

**Ölçüldü (420×900, taslak taşa dokunup bırakma):** 6 px kayan parmak taşı
geri alıyor, **12 ve 20 px kayanlar HİÇBİR ŞEY yapmıyordu** — raf tarafında
taş seçilemiyordu bile. Sebep iki ayrı kararın tek eşikle verilmesiydi:
10 px (Android touch slop) hayaleti GÖSTERMEK için doğru ama BIRAKMA kararı
için fazla dar. Ayrı bir bırakma eşiği eklendi (24, hücrenin ~26 px'inin
hemen altında) → paket **`1.0.0 (407)`** (`0651e5e`), kullanıcı onayladı:
*"Daha iyi şimdi. Yayına alıyorum."* — ve 28 Ağustos 2026'da kapalı test
kanalında **yayına alındı** (bkz. aşağıda madde 3).

> **Ders:** bir eşik İKİ farklı soruyu cevaplıyorsa muhtemelen iki eşik
> olmalı. "Sürükleme başladı mı?" ile "kullanıcı bırakmak mı istedi?" aynı
> soru değil; ilkinin cevabı erken, ikincisinin geç verilmeli.
>
> **İkinci ders:** "dokunma isabeti" şikayetlerinde önce hedefin ALANINA
> bakmak refleks oldu (48 dp turu, kurtarma, `.tap-expand`) — ama alan
> yeterliyken JEST yolu kaybediyor olabilir. A2'nin ilk beş düzeltmesi
> gerçekti ve yine de kullanıcının asıl şikayetini çözmedi.

**Sürüm B'nin iki kalanı da KAPANDI (30 Ağustos 2026):** madde 13'ün dört
bildirimi canlıda (Faz 2 + 4), "bildirime dokununca doğru oyunu aç" kodu
main'de (Faz 3 — 1.0.3'le sahaya çıkar). Burada duran *"'taktirde' düzeltmesi
deploy edilmedi"* notu da bayattı ve silindi: düzeltme 29 Ağustos'ta v11'de
canlıdan doğrulanmıştı (bkz. #13'teki ✅ satırı), bugün canlıda v12 var.

---

### 1.5 Sürüm B'ye binecek sözlük eklemeleri · ✅ **KAPANDI** (31 Ağustos 2026)

**Dördü de eklendi ve 1.0.3'e biniyor** (`lapis`, `mö`, `banu`, `banü`);
`words_tr.txt`'de varlıkları doğrulandı. 31 Ağustos'ta beş madde daha
eklendi: `çilav`, `kanola`, `refil`, `sü`, `tarot` — toplam 63.905 kelime.
Aşağıdaki inceleme kaydı olduğu gibi duruyor.

Kullanıcı üç kelime verdi (*"acil değil, yeni sürüm işlerine dahil et"*).
Sözlük app paketinin içinde olduğundan bunlar **bir sonraki mobil sürüme
binmeli** — sunucu+web'i erken güncellemek serbest ama app'te ancak yeni
sürümle geçerli olur (bkz. `docs/decisions/dictionary.md` → "Yayılma
gecikmesi").

**Varlık kontrolü YAPILDI (28 Ağustos 2026) — repo ve canlı AYRIŞMIYOR,
üçü de her iki tarafta da YOK:**

| Kelime | `words.ts` / `meanings.json` | `public.words` / `is_valid_word` | Komşusu (ölçüldü) |
|---|---|---|---|
| `lapis` | yok | yok | **`lapislazuli` VAR** (bitişik tek madde), `lacivert` var |
| `mö` | yok | yok | İki harfli tek "m" maddeleri: `ma`, `me`, `mi` |
| `banu` (+`banü`) | ikisi de yok | ikisi de yok | `bani` var — **farklı kelime**, i/ı dersiyle aynı sınıf |

**Hedef liste: üçü de `scripts/extra-words.mjs`.** (`proper-nouns` ülke/
şehir/dil içindir; `extra-meanings` var olan maddeye ek anlam içindir —
hiçbiri bu üçüne uymuyor.)

Anlamlar (kullanıcının verdiği):
- **lapis** — (lapis lazuli) değerli taş; dilimizde daha çok tam hâliyle ya
  da *laciverttaşı / lacivert taşı* olarak bilinir. Latince `lapis` "taş",
  `lazuli` lacivert rengi.
- **mö** — inek sesi (ünlem).
- **banu** — (Banü) Farsça kökenli; "hanımefendi, soylu kadın, gelin, ve
  bağ/bahçe".
- **banü** — (Banu) Farsça kökenli; "kadın, hanım, hanımefendi, soylu
  kadın".
  **`banu` ve `banü` İKİSİ DE eklenecek — karar verildi (28 Ağustos 2026);
  anlamları 28 Ağustos'ta kullanıcı tarafından AYRIŞTIRILDI, yani iki ayrı
  madde, birbirinin yazım varyantı değil** (`extra-meanings` değil,
  `extra-words`; her biri kendi anlam listesiyle).
  İkisinin de yokluğu ayrıca doğrulandı: `words.ts`, `meanings.json`, üç
  `scripts/*.mjs` listesi, canlı `public.words` ve NFC normalizasyonu —
  hepsinde yok. `ban…` komşuluğunun tamamı: `ban · bana · banak · banal ·
  banaz · bandaj · bando · bangui · bani · banjo · banjul · bank · banka ·
  banker · banket · bankiz · banko · banma · banmak · bant · banyo`.

⚠ **`mö` iki harfli.** Bu projede iki harfli maddeler yerleştirmede
orantısız iş görür (çapa kurma, dar boşluk doldurma) — golden vector'lar
yeniden üretildiğinde fark çıkarsa sebebi büyük olasılıkla budur; bu bir
hata değil, beklenen etki.

**Uygulanınca koşulacak zincir** (`docs/decisions/dictionary.md`'deki tablo,
hiçbir halka atlanamaz): `npm run augment-dictionary` → migration'ı canlıya
uygula + `list_migrations` ile dosya adını eşleştir → `npm run
generate-golden-vectors` + `dart run test/run_all.dart` → `npm run
generate-meanings-db` → `README.md`'deki kelime sayısı.

---

## 1. `kelimeki://` deep link kanalı — **MAĞAZA BLOKERİ**

*⚠ BU MADDE FİİLEN KAPANDI (30 Ağustos 2026, Faz 3'te ölçüldü) — aşağısı
tarihçe.* Üç akış da çalışıyor (kayıt onayı 28 Ağustos'ta https'e geçti,
şifre sıfırlama `kelimeki://reset`, arkadaş daveti App Links + inbox) ve
Faz 3 dördüncüyü ekledi (bildirim → oyun). Açık kalan TEK parça iOS
Associated Domains — o, iOS'un kendi bloğunda (Apple Developer üyeliği)
bekliyor, bu maddenin değil.

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
- Android: intent filter. **`assetlinks.json` ARTIK BEKLEMİYOR** — 25
  Ağustos 2026'da `public/.well-known/assetlinks.json` olarak yazıldı ve
  Vercel'den (`kelimeki.com`) servis ediliyor; "Pages'ta barındırılacak"
  planı geçersiz, çünkü uygulamanın açacağı adresler zaten `kelimeki.com`
  altında.
- Flutter: gelen linki karşılayan yönlendirme + `friendInvite` kuyruğuyla
  (web'deki `kelimeki:pending-invite` deseninin portu) birleştirme.
  ~~**AYNI TURDA DÜZELTİLECEK — portta davet kabulü SESSİZCE düşüyor.**~~
  **✅ BİTTİ (26 Ağustos 2026, bu maddeden AYRI olarak yapıldı** — tamamen
  istemci tarafı, cihaz doğrulaması gerektirmiyordu). `_processInvites`'in
  `catch`i yalnızca `debugPrint` yapıyordu; artık web `FriendInvitePage`'in
  kuralını okuyor: sunucunun KALICI reddi (SQLSTATE `P0001`) olduğu gibi
  gösteriliyor, ağ hatası ayrı konuşuyor, geri kalan jenerik. Karar mantığı
  `inviteAcceptErrorText`/`inviteAcceptKaliciRet` (`friends_api.dart`) —
  iki taraf aynı kuralı okusun diye saf fonksiyona çıkarıldı. Misafir dalı
  da sessizdi (geçersiz linkte hiçbir şey görünmüyordu), o da konuşuyor.
  Beklenmeyen hatalar telemetriye düşüyor; beklenen retler ve ağ hataları
  BİLEREK düşmüyor. Ayrıntı: `mobile/docs/parca-log.md` → Parça 142.
  **`events.takeAll`ın yıkıcılığı da AYNI TURDA kapatıldı** (kullanıcı
  kararı): ağ hatasında token kuyruğa geri konuyor ve öne dönüşte yeniden
  deneniyor. Kalıcı ret (P0001) ve bilinmeyen hatalar BİLEREK geri
  konmuyor — ölümsüz kayıt üretirdi.

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

---

## 6. Taranabilir `/nasil-oynanir` sayfası — ✅ **YAPILDI** (31 Ağustos 2026)

Sayfa canlı: **`/nasil-oynanir/`**, derleme zamanında üretilen statik HTML
(35 KB, **sıfır `<script>`**, ~7,9 KB okunabilir metin). Kendi
`title`/`description`/`canonical`'ı var, `sitemap.xml`e girdi.

**İçerik KOPYALANMADI, İTHAL EDİLDİ.** `HelpModal.tsx` artık `QuickStart` ve
`DetailedRules`'ü dışa açıyor; sayfa onları tüketiyor. Böylece üç taraf
(pencere · statik sayfa · Dart parite testi) tek kaynaktan besleniyor.
`QuickStart`ın `onDetailedClick`'i opsiyonel oldu: pencerede adım değiştiren
bir buton, statik sayfada aynı sayfadaki bölüme giden bir çapa — JS'siz bir
sayfada buton ölü bir öğe olurdu.

**Öksüz sayfa sorunu çözüldü:** karşılama katmanındaki "Nasıl oynanır?"
bölümünün sonuna GERÇEK bir `<a href="/nasil-oynanir/">` kondu. Footer'daki
hukuki bağlantılar `<button>` (SPA penceresi açıyorlar), yani sitemap dışında
bir keşif yolu yoktu; bu bağlantı onu kapatıyor.

**Mekanizma paylaşıldı, kopyalanmadı:** `src/legal/render.tsx`in dizisi
`LEGAL_PAGES` → **`STATIC_PAGES`** oldu ve yeni sayfa oraya girdi. Dizin ve
eklenti adları (`src/legal/`, `scripts/legal-plugin.js`) KASTEN yeniden
adlandırılmadı — `vite.config.ts`, `.d.ts` ve duman testlerindeki atıflar
kırılırdı; dizi adı gerçeği söylüyor.

⚠ **BİR HATA YAPILDI VE YAKALANDI — kayda değer.** `HelpModal.tsx`e eklenen
uyarı yorumunda parite testinin regex'i ÖRNEK OLARAK yazıldı; tarama yorum/kod
ayrımı yapmadığından o örnek GERÇEK bir başlık gibi sayıldı ve
`help_text_parity_test.dart` düştü (beklenen `…`, gelen dosyanın ilk satırı).
Yani dosyaya "bu kalıbı taşıma" diye yazılan uyarının kendisi kalıbı taşıdı.
Yorum yeniden yazıldı ve dosyaya bu ders de eklendi.

**Testler (44, önce 40) ve negatif eşleri:** sayfa `DetailedRules` yerine
kopya metin taşısa 2 test düşüyor; katmandaki bağlantı çapaya çevrilse 1 test
düşüyor. Kaynak karşılaştırması pencereyle DEĞİL `HelpModal.tsx` ile yapılıyor
(pencereye ulaşmak giriş ya da başlamış oyun ister — kırılgan olurdu; Dart
tarafı da aynı sebeple kaynak tarıyor). Başlıklar ekranda `uppercase`
çizildiğinden karşılaştırma `toLocaleUpperCase('tr')` ile normalleştirildi.

---

### Aşağısı yapılmadan önceki hâli (tarihçe)

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

---

## 10. Hata raporlama hız sınırı süreç ömrüne değil ZAMANA bağlansın — ✅ **YAPILDI** (31 Ağustos 2026)

**Yapılan:** tavan (10) KORUNDU, penceresi süreç ömründen **son 1 saate**
taşındı. Sayaç artık bir `int` değil zaman damgası listesi, imza kümesi de
`Set` değil imza→zaman haritası; her raporda pencerenin dışına düşenler
unutuluyor (`pencereyiKaydir` / `_pencereyiKaydir`). İki istemcide aynı
sayı: `MAX_PER_WINDOW = 10`, `WINDOW_MS = 60 * 60 * 1000`.

**Karar edilen bir ayrıntı — GERİYE ALINAN SAAT.** Kaynak duvar saati
(`Date.now` / `DateTime.now`), çünkü uygulama askıya alınıp saatler sonra
devam edebiliyor ve tek dertli olduğumuz şey "cihaz kalıcı susmasın".
Eskime koşulu yalnızca `simdi - t < PENCERE` olsaydı, cihazın saati geriye
alındığında (elle ayar, NTP düzeltmesi) damgalar "gelecekte" kalıp HİÇ
eskimezdi — yani düzeltmenin bedeli tam da kapatmaya çalıştığı körlük
olurdu. Koşula `t <= simdi` eklendi; testi var ve o satır kaldırılınca test
GERÇEKTEN düşüyor (ölçüldü).

**Zamanlama — bu satır 1 Eylül'de DEĞİŞTİ, sebebi kayda değer.** Yazıldığında
"saf istemci kodu, bir sürüm turu bekliyor, 1.0.5'e biner" diyordu; doğruydu
ama **merge onu geçersiz kıldı.** #393 `main`'e girince `mobile-build`
`main`'de koştu ve `mobile-latest` release'indeki `.aab`'yi ÜZERİNE YAZDI —
`pubspec` hâlâ 1.0.4 dediğinden yeni paket de **1.0.4**, yalnızca
versionCode 461 → **467** oldu ve #10 içine girdi. Yani #10 bir sürüm turu
BEKLEMEDİ, henüz yüklenmemiş olan 1.0.4'e bindi.

**1.0.5 diye bir paket hiç var olmadı** — yalnızca bu cümlede bir plandı.
Numara boş; bundan sonraki ilk iş ona biner.

⚠ **Genel ders: "şu sürüme biner" cümlesi, o sürüm YÜKLENMEDİYSE merge ile
değişir.** `mobile-latest` her mobil derlemede üzerine yazıldığından, henüz
Play'e çıkmamış bir sürüm numarası merge edilen her yeni işi kendine
toplar. Sürüm planı yazarken sorulacak soru "hangi numara sırada" değil,
**"o numaralı paket sahaya ÇIKTI mı"**.

Sunucu tarafında değişen bir şey YOK (bu madde tamamen istemci).

**Doğrulama:** `npm run verify-error-reporting` 30 → **35 kontrol** (yeni
beşi: imza pencere geçince yeniden gönderilir · pencere başına 10 · pencere
dolmadan tavan açılmaz · pencere kayınca sayaç düşer · saat geriye alınınca
kalıcı körlük olmaz). Dart eşleniği `error_reporter_test.dart`'ta aynı
vakalar aynı sırayla; ROADMAP'in kendi tuzak listesinin istediği parite
testi de yazıldı: **`error_rate_limit_parity_test.dart`** iki üretim
kaynağını VE iki testteki pencere kopyasını (dört yer) karşılaştırıyor.
Negatif eş ölçüldü: `pencereyiKaydir` çağrısı kaldırılınca üç kontrol,
`t <= simdi` kaldırılınca bir kontrol düşüyor.

⚠ **Dart tarafı BU OTURUMDA KOŞULAMADI** — geliştirme ortamında Flutter/Dart
yok. `dart analyze` + `flutter test` PR'da CI'da koşacak (mobile-build.yml).
Parite testinin regex'leri node'da (V8 semantiği, Dart'a yakın olan) tek tek
prototiplendi ve altısı da kaynakta BİRER kez eşleşiyor.

### Aşağısı yapılmadan önceki hâli (tarihçe)


**Model: Sonnet 5, efor `low`.** Spesifikasyon burada net; iki istemcide
aynı sayı.

**Nereden çıktı:** 23 Ağustos 2026'daki "app tarafı geldiğinde ne eksik?"
denetimi. Aynı turda bulunan üç boşluğun üçü de kapatıldı (bkz. kök
`CLAUDE.md` → "Mağaza öncesi üç ekleme"); bu dördüncüsü **bilinçli olarak
ertelendi** — Play yüklemesinin önünde duran bir şey değil.

**Sorun:** `MAX_PER_SESSION = 10` (web `errorReporting.ts`, port
`error_reporter.dart`) + hiç temizlenmeyen imza kümesi. Web'de bir sayfa
yenilemesi ikisini de sıfırlıyor, **app süreci ise günlerce yaşıyor** —
10 FARKLI hatadan sonra o cihaz kalıcı olarak kör kalıyor ve tekrar eden
bir hata süreç başına yalnızca BİR kez sayılıyor.

**Neden bloker DEĞİL (ölçüldü/akıl yürütüldü, 23 Ağustos):** sınır
*tespiti* değil *hacmi* kısıyor — hatayı yine görürsün, "kaç kez" sayısı
eksik kalır. Panelin asıl ölçütü olan **"kaç cihaz"** bozulmuyor (o zaten
cihaz başına tekil sayıyor). 12 tester'lık kapalı testte pratik etkisi yok.

**Ne:** sayaç ve imza kümesi zaman pencereli olsun (ör. son 1 saatte en
fazla 10; pencere kayınca imzalar da düşsün). Çökme döngüsü koruması
KORUNMALI — bu maddenin var oluş sebebi o korumayı gevşetmek değil,
penceresini doğru yere koymak.

**Tuzaklar:**
- İKİ istemci birden — biri değişip öteki kalırsa web ile app farklı
  davranır. Sayı çifti olacağı için `layout_parity_test.dart`in desenine
  uygun bir parite testi düşünülebilir.
- `verify-error-reporting`in "oturum başına en fazla 10 kayıt" kontrolü ve
  Dart'taki eşleniği bu değişiklikle YENİDEN YAZILMALI; ikisi de bugün
  süreç-ömrü varsayımına dayanıyor.

---

---

## 11. Hata panelinde platform filtresi — ✅ **YAPILDI** (31 Ağustos 2026)

**Tetikleyici geldi ve ÖLÇÜLDÜ.** Maddenin karar kuralı *"panelde ilk kez
ios/android satırları görünüp web ile karışmaya başladığı gün"*du. Canlı
`client_errors` sayımı: **web 17 · android 16 · app-web 1** kayıt. Karışma
başlamış.

**Sunucu tarafı seçildi (`p_platform`), istemci tarafı filtre DEĞİL** —
madde ikisini de seçenek bırakmıştı, ama fonksiyonun şekli seçimi
belirliyor: satırlar `(kind, message)` ile gruplanıyor ve `platforms` bir
`string_agg`, yani iki platformda da görülen bir hata TEK satır ve
`occurrences`/`devices` İKİSİNİN TOPLAMI. İstemcide "platforms 'android'
içeriyor mu" diye elemek o satırı gösterir ama sayıları web'i de içerdiği
hâlde bırakırdı — panelin bütün değeri o iki sayı olduğundan bu SESSİZ bir
yanlış olurdu. **Varsayım değil, ölçüm:** canlıda böyle bir satır gerçekten
var (`[online_games_repo.load] AuthApiException…` — android+app-web'de
2 kez/2 cihaz, yalnız android'de **1/1**).

**Migration:** `20260831213500_admin_client_errors_platform_filter`. Kayıtlı
tuzak uygulandı — parametre eklemek `create or replace` ile OLMAZ: eski
`(integer)` imzası yerinde kalır, tek argümanlı çağrı iki imzaya birden uyup
`function is not unique` (42725) verir (`fix_withdraw_report_wrong_overload`).
Önce drop, sonra create, grant'ler elle. **Canlıda doğrulandı:**
`pg_proc`ta TEK imza (`admin_client_errors(integer,text)`), yetkiler
`authenticated`+`service_role`, `public`/`anon` YOK; admin kapısı da çalışıyor
(admin olmayan çağrı `Yetkisiz erişim.` veriyor). Fonksiyonel ölçüm (admin
kimliğiyle, 90 gün): Tümü 10 satır · android 5 · web 5 · ios 0.

**Kapsam sınırı (bilinçli):** `p_platform` yalnızca EŞİTLİK eliyor, yani
platformu NULL olan satırlar bir platform seçiliyken görünmez — "Tüm
Platformlar"da `?` olarak duruyor. `client_errors.platform` üzerinde kısıt
BİLEREK yok (öngörülmemiş bir değer yüzünden bir hata raporunu kör etmemek
için), o yüzden listede olmayan bir platform da yalnızca "Tümü" görünümünde
okunur. Filtre bir kolaylık, tek görüntüleme yolu değil.

**CSV kendiliğinden uyumlu:** dışa aktarma `clientErrors` state'ini
okuduğundan filtre uygulanmış hâli iniyor ("CSV ekranda görüneni indirir").

**#10'un kaçırdığı iki bayat metin de bu turda düzeltildi:** `?` popup'ı ve
`docs/testing-admin.md` hâlâ "oturum başına en fazla 10 kayıt" diyordu.

### Aşağısı yapılmadan önceki hâli (tarihçe)


**Model: Sonnet 5, efor `low`.**

`admin_client_errors(p_days)` yalnızca gün alıyor; platformlar gruplanmış
satırda tek bir birleşik dizede (`platforms`). Bugün tek platform (web)
olduğu için gereksiz — **üç platform (web/ios/android) birden veri
göndermeye başlayınca** "yalnızca iOS'ta olan hata" görünümü gerekecek.

**Ne:** RPC'ye opsiyonel bir `p_platform` (ya da panelde istemci tarafı
filtre — satır sayısı düşükken o da yeterli). Dönüş tipi değişmezse
`create or replace` yeterli; değişirse drop+create + grant'ler elle
(kayıtlı tuzak: `fix_withdraw_report_wrong_overload`).

**Karar tetikleyicisi:** panelde ilk kez ios/android satırları görünüp
web ile karışmaya başladığı gün.

---

---

## 12. Sürüm dağılımının KAPSAMI — ✅ **KAPANDI** (31 Ağustos 2026)

✅ **Kapanış:** kullanıcı 1.0.3 duyurusundan sonra *"kaç kişi yenide
görebiliyor musun?"* diye sordu ve cevaplanamadı — aşağıdaki sınır tam da
o gün canlı bir soruya çarptı. Çözüm **`push_tokens.app_version`**: satır
`user_id` ile anahtarlı ve token her uygulama açılışında hizalandığından
oyun oynanması gerekmiyor. Admin panelinde ayrı bir tablo:
Büyüme > Kullanıcı → **"Kurulu Sürümler — Kişi"**. Ayrıntı: ROADMAP Faz 6.

⚠ **Aşağıdaki iki seçeneğin İKİSİ DE seçilmedi ve bu bilinçli.**
`online_game_clients`e kolon eklemek yalnızca Canlı tarafı kapsardı;
heartbeat olayı ise **yeni bir kişisel veri** sayılıp `PrivacyModal` +
portun `legal_modals.dart`'ını gerektirirdi. `push_tokens` üçüncü bir yol:
zaten var olan bir satıra bir kolon, yeni veri toplama YOK.

⚠ **Yerine geçmiyor, YANINA geliyor.** Eski "Sürüm Dağılımı" tablosu
(`game_starts`) duruyor ve hâlâ gerekli — o misafir dahil herkesi görür ama
oyun açılışı sayar; yenisi kişi sayar ama bildirim izni ister. İkisi farklı
soru cevaplıyor.

⚠ **Damga geriye dönük doldurulamaz:** bir cihaz 1.0.4+ ile açılana kadar
"—" kalır. Yani ilk günlerde "—" çoğunluk olacak — bu kolonun doğum tarihi,
arıza değil. Yan fayda: o satır aynı zamanda "kaç kişi eski sürümde kaldı"
sorusunu da cevaplıyor.

---

### Aşağısı kapanmadan önceki hâli (tarihçe)

Kod işi değil, bir **karar noktası.** 23 Ağustos 2026'da eklenen
`admin_app_version_breakdown` (Büyüme > Kullanıcı → "Sürüm Dağılımı")
kaynağını `game_starts`tan alıyor, yani **yalnızca YEREL (YZ) oyun
açılışlarını** sayıyor. Sonucu: yalnız Canlı oynayan bir kullanıcı tabloda
HİÇ görünmez.

Bu sınır bilinçli ve bugün doğru: `game_starts` girişten bağımsız
(misafir dahil) yazılan en geniş kapsamlı istemci olayı ve tablonun tek
işi "`mobile_min_supported_version` eşiğini yükseltmek güvenli mi"
sorusuna cevap vermek.

**Ne zaman yeniden düşünülmeli:** kapalı test sırasında tablodaki toplam,
gerçek tester sayısının belirgin altında kalırsa — yani testerların kayda
değer bir kısmı YZ oyunu hiç açmıyorsa. O gün seçenekler:
- `online_game_clients`e `app_version` eklemek (Canlı tarafı kapsar), ya da
- açılış başına günde bir satır yazan bir "heartbeat" olayı — **bu YENİ bir
  kişisel veri sayılır**, yani `PrivacyModal` + portun `legal_modals.dart`'ı
  birlikte güncellenmeli (tarihler `legal_text_test.dart` ile karşılaştırılıyor).

**⚠ Eşiği yükseltmeden önce bu tabloya bak** — eski sürümden hâlâ oyun
açılıyorsa yükseltmek o kullanıcıları uygulamadan kilitler
(`version_gate.dart`). Bugün `app_config.mobile_min_supported_version`
`{ios: 0.0.0, android: 0.0.0}`, yani kapı fiilen kapalı ve kimse
kilitlenmiyor (23 Ağustos 2026'da canlıdan okundu).

---

---

### 🚀 1.0.5 SÜRÜM TURU — ✅ **TAMAMLANDI** (2 Eylül 2026)

**KAPANIŞ:** paket kapalı testte yayında (`1.0.5 (501) — 4a0a29b`, ~15:03) ve
aşağıdaki tabloda ⬜ kalan üç iş de **kullanıcı tarafından cihazda doğrulandı**
(2 Eylül 2026: *"1.0.5 turu testi tamam. Herşey düzgün çalışıyor."*). Tur
kapandı; bölüm bu yüzden arşivde.

⚠ Bu bölüm iki kez bayatladı: 1 Eylül'de *"dalda hazır, KAPILI · tek
içerik: tahta zoom'u"*, 2 Eylül sabahı *"`.aab` hazır, Play'e
yüklenmedi"*. Tur `main`'e girdi, zoom'un yanına üç iş bindi, ardından
cihaz turundan **beş düzeltme daha** çıktı.

**İçerik — `main`'e giren SIRAYLA:**

| PR | Ne | Cihazda denendi mi |
|---|---|---|
| #395 | Tahta zoom'u: çift dokunuşla 2×, parmakla pan (yalnızca tahtanın içi) | ✅ kullanıcı: *"App ok 👍"* |
| #396 | APK turu 2: bölge çizgisi kenarda incelmesin · kenarlar/boşluklar da çift dokunuş yüzeyi | ✅ aynı turda |
| #397 | APK turu 3: hamle puanı rozeti kenarda kırpılmasın | ✅ aynı turda |
| #399 | Zoom **tanıtım balonu** — merkez kareyi işaret eden tek seferlik ipucu | ✅ cihazda doğrulandı (2 Eylül, kullanıcı) |
| #400 | Yazı ölçeği: sınıf 3 (sarma — bitirme modalı puanları bölüyordu) + sınıf 2 (Setup'ta devam eden oyun kartı) | ✅ cihazda doğrulandı (2 Eylül, kullanıcı) |
| #402 | Mesaj kutusunun üstüne "Oyunculara buradan mesaj gönder" | ✅ cihazda doğrulandı (2 Eylül, kullanıcı) |
| #408 | Cihaz turu: k-lig sütunları · devam eden oyun kartı · alt şerit | ✅ şerit onaylandı |
| #410 · #411 | Hamle rozeti zoom'da tahtanın DIŞINA çiziliyordu (web; ilk klip transform'lu katmandaydı ve işe yaramıyordu) | ✅ web'de onaylandı |
| #413 | Portta da rozet taşıyordu (piksel ölçümü: 268 px → 0) · çevrimdışıyken alt şerit tek satır · "Nasıl Oynanır?" → "Yardım", punto 11 | ✅ **2 Eylül**: *"sonunda web ile aynı olmuş"* |
| #414 | Zoom'da kalıcı 10 px çerçeve (kırpan kutu kart−10 → kartın tamamı) · filigranlar yazı ölçeğinden muaf | ✅ **TAMAMEN ONAYLANDI** — çerçeve + çevrimdışı + filigranlar (2 Eylül, kullanıcı: *"Filigranlar düzgün (en büyük fontta)"*) |

`appVersion` + `pubspec` 1.0.4 → **1.0.5** (#395'te birlikte). Tam takım
681 → **702** test yeşil.

**Kapılar, SIRAYLA — kullanıcı kararı:** *"Bunu apk ile test edip sorunsuz
olduğundan emin olmadan aab yapılmayacak."*

1. ✅ **467 (1.0.4) Play'e yüklendi** (1 Eylül 2026).
2. ✅ **AÇILDI** (2 Eylül 2026, 14:0x). CI `.apk` + imzalı `.aab` üretti
   (`mobile-latest`, **`4a0a29b`**'den, 13:56). Kullanıcı APK'yı kurup
   denedi: *"sonunda web ile aynı olmuş. Çevrimiçi de uçak modunda düzgün
   çalışıyor."* — yani **zoom kenarı (çerçeve yok)** ve **Canlı oyunda
   çevrimdışı alt şerit** doğrulandı.
   ⚠ **Hâlâ denenmemiş:** balon · yazı ölçeği (bitirme modalı) · mesaj
   etiketi · **filigranlar** (#414'ün ikinci yarısı). Listeler:
   `mobile/TESTING.md` § 8 (çevrimdışı şerit + zoom kenarı + filigranlar),
   § 24 (zoom), § 25 (yazı boyutu),
   `mobile/docs/testing-arkadaslar-canli.md` → Mesajlaşma.
3. ✅ **YAYINLANDI** — `1.0.5 (501) — 4a0a29b`, kapalı test kanalı,
   2 Eylül ~14:40 gönderim → ~15:03 Published (≈23 dk). Kanonik kayıt:
   `mobile/docs/build-and-distribution-log.md` → "Yayınlanan sürümlerin
   kütüğü". ⚠ "Published" rozeti kanala GİRDİĞİNİ söyler, cihaza indiğini
   DEĞİL — ölçülmüş çare aynı dosyada ("testçi opt-in linkine TEKRAR gir").

**Turun WEB yarısı — ayrı ve ZATEN CANLIDA** (`kelimeki.com`, `b053779`),
çünkü web merge'de anında deploy oluyor: #398 (zoom + balon, portla aynı
deneyim — kullanıcı kararı *"her yerde aynı deneyim olsun"*), #401 (yazı
boyutu sütunları), #402'nin web yarısı.

**Turdan çıkan iki SÜREÇ düzeltmesi** (ürün değil, altyapı):
- **#403 + #404 — `main` bir kez KIRMIZI oldu.** #401 `GameOver.tsx`teki
  `w-[29px]` sınıflarını sildi; o sınıfları bir MOBİL test okuyordu
  (`layout_parity_test.dart` ↔ `_ColHeader(width: 29)`). İki PR ayrı ayrı
  yeşildi, kopma yalnızca birleşimde göründü. #403 belirtiyi (`min-w-*`
  tabanı geri kondu), #404 SEBEBİ kapattı: `web-ci.yml` artık mobil test
  paketini de koşuyor. Ders `docs/decisions/components-account.md`'de.
- **#405 + #406 — doküman borcu ve CI maliyeti:** README ağaçlarındaki üç
  eksik dosya + bayat "`curl` çıkamıyor" tespiti düzeltildi; yalnızca
  doküman değiştiren bir PR'ın macOS derlemesi başlatması engellendi
  (`!mobile/**.md`).

**1 Eylül 2026, ikinci tur — spec kullanıcı düzeltmesiyle SADELEŞTİ:**
ilk sürümün "çift dokunuş ilk dokunuşun etkisini geri sarar" ve "joker
penceresi ertelenir" mekanizmaları kullanıcı tarafından reddedildi
(*"taşı geri almadan, koyduğu yerde bırakarak zoomlamak lazım"* / *"joker
tablosunun zoom olayıyla ne ilgisi var"*) ve silindi — artık çiftin
İKİNCİSİ yutulur, İLKİNİN işi kalır; joker ANINDA açılır ve
`game_screen_test.dart` origin/main ile bayt bayt aynı. Ayrıntı: Parça 175.

---

## 16. Devam eden oyun kartlarının düzen AYRIŞMASI — ✅ **YAPILDI** (2 Eylül 2026)

Kullanıcı iki ekran görüntüsüyle bildirdi (1.0.5 kapalı test paketi,
`Derleme 4a0a29b`): Setup'ın "DEVAM EDEN OYUNLAR" listesi **Arkadaşınla**
ve **Yapay Zeka** sekmelerinde farklı diziliyor.

| | Yapay Zeka | Arkadaşınla |
|---|---|---|
| Satır 1 | `Sıra: Ironman` + **SIRA SENDE ▶** | `Ironman açtı` + **SIRA SENDE ▶** |
| Kalan süre | ALT satırda, kendi başına | **AYNI satırda — "Ironman açtı" yazısına biniyor** |

**Kullanıcının istediği düzen (ikisi de aynı olacak):**

1. **YZ'deki `Sıra: X` KALDIRILSIN** — gereksiz: yanında zaten kocaman
   `SIRA SENDE` yazıyor, ikisi aynı şeyi söylüyor.
   ⚠ `Ironman açtı` (Arkadaşınla) buna benzemez ve KALIR — o kimin
   açtığını söylüyor, sıra bilgisi değil.
2. **Kalan süre ile durum arasında bir satır boşluk** olsun (YZ'de zaten
   alt satırda, oraya nefes payı gelecek).
3. **Arkadaşınla'da kalan süre bir satır aşağı insin** — böylece iki
   sekme aynı düzene gelir.

**Yarısı ZATEN YAPILMIŞ ve desen orada:** #408'de (2 Eylül) Setup'ın YZ
kartı tam bu şekle sokulmuştu — `_DevamEdenGovde` (`setup_screen.dart`),
regresyonu `setup_screen_test.dart` → *"DEVAM EDEN OYUN: durum satırda
kalır, süre alta iner, isim alanı sıkışmaz"*. Canlı oyun listesi
(`live/live_games_tab.dart`, "X açtı" satırı) o turda dokunulmadan
kalmış — ayrışma buradan doğuyor. Yani iş **yeni bir düzen icat etmek
değil, var olanı ikinci yere taşımak**.

⚠ **Web ikizleri aynı PR'da:** kartların web karşılıkları da var
(`Setup.tsx` ve Canlı oyun listesi). Kural: ikizler birlikte değişir;
web'de sorun yoksa bile "aynı sonuç" korunmalı — önce web'e bakılır
(`mobile/CLAUDE.md` → "Sorun Bildirildiğinde İLK ADIM").

**Kapsam dışı:** bu bir düzen işi, veri/mantık değişmiyor.

---

**KAPANIŞ (2 Eylül 2026):** üçü de yapıldı. Gövde artık iki kartın
PAYLAŞTIĞI tek kaynakta (`mobile/app/lib/src/ui/devam_eden_govde.dart`) —
ayrışmanın sebebi düzenin yanlış olması değil, doğrusunun `setup_screen`
içinde PRIVATE kalmasıydı. Web ikizleri (`Setup.tsx`, `LiveGamesTab.tsx`)
aynı PR'da. Kullanıcı ayrıca durum etiketinin puntosunu büyüttü
(13 → 15; üçgen/nokta ölçüsü ona çapalı olduğundan onlar da 9×10/10×10).
Ölçümler, testteki sessiz tuzak (`kDevamEdenSolKey`) ve gerekçenin tamamı:
`docs/decisions/components.md` → *"Devam eden oyun" kartı — İKİ SEKME
AYRIŞMIŞTI*.

⚠ **Cihazda henüz DENENMEDİ** — bir sonraki mobil sürüm turuyla çıkar.

---

## 13. Push bildirimleri + Firebase Analytics — ✅ **KAPANDI** (26 Ağustos → 1 Eylül 2026)

**KAPANIŞ (2 Eylül 2026):** aşağıdaki "ölçülen durum" tablosunun DOKUZ
satırının dokuzu da ✅. Maddenin gövdesi zaten arşivdeydi (Faz 1-7); bu
bölüm ROADMAP'te bir SPESİFİKASYON olarak kalmış ve sıfırdan bir iş gibi
okunuyordu. Kalan tek şey iki CİHAZ DOĞRULAMASI — §3c'nin davete özgü
dalları ve GA4 DebugView — onlar da ROADMAP'in özet tablosunda kendi
kovasında ("Cihazda denenmemiş") duruyor, yani bu bölüm kapanınca
kaybolmuyorlar.

⚠ Aşağısı 26 Ağustos'ta yazılmış PLAN metnidir: "yapılacaklar", "sıra" ve
"iOS bekliyor olacak" kısımları o günün diliyle konuşuyor. Neyin GERÇEKTEN
yapıldığı için önce ölçülen durum tablosuna, sonra Faz 1-7 bölümlerine bak.

### #13'ün ölçülen durumu (29 Ağustos 2026) — yarısı BİTTİ

⚠ **Başlık 29 Ağustos'un hâlini anlatıyor, tablo ise sonradan güncellendi**
— satırlar 30-31 Ağustos'a kadar dolduruldu ve bugün DOKUZU DA ✅. Başlık
bilerek değiştirilmedi (tarihli bir kayıt, üstelik ona atıf yapılabilir);
aynı dosyanın kendi hastalığının bir örneği daha: tablo kapandı, başlığı
kapatan olmadı.

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

### 26 Ağustos 2026 tarihli PLAN metni (tarihçe)

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

### 3. Davetlilere hatırlatma — ✅ **KAPANDI** (2 Eylül 2026, kullanıcı kararı)

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

**KAPANIŞ (2 Eylül 2026), kullanıcı kararı:** *"Hep ben hatırlatıyorum
zaten. Burada madde olarak durmasına gerek yok."* Yani iş bir "yapılacak"
değil, zaten yürüyen bir alışkanlık — ROADMAP'te madde olarak durması onu
her turda tekrar bir eksik gibi gösteriyordu.

⚠ **Bu maddenin içindeki işletim bilgileri ROADMAP'te KALDI** (sayacın
Console'daki yeri, 14. gün, opt-in ↔ izin listesi ayrımı, 14 gün dolmadan
yapılacak iki iş) — bkz. ROADMAP → *"Sayaç — nerede okunur, 14. gün ne
zaman"*. Bir madde kapanırken içine park edilmiş CANLI bilgiyi de
götürmemeli.

⚠ **Aşağıdaki *"Sayı tam 12 — pay yok"* satırı ARTIK KESİN DEĞİL** — 2
Eylül'de kullanıcı sayının bir TAVAN olabileceğini söyledi; iki tez de
mevcut kanıta uyuyor. Tartışma ROADMAP'in yukarıdaki bölümünde ve
`console-formlari.md` §7'de.

---

### 2. Zorunlu güncelleme (force update) — ✅ **KAPANDI** (2 Eylül 2026, kullanıcı kararı)

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

**KAPANIŞ (2 Eylül 2026), kullanıcı kararı:** *"Artık app'de güncelleme
çıkıyor. Bunu görünce zaten yapar. Başka bir şey yapmaya gerek yok."*
Yani Play'in kendi güncelleme bildirimi işi görüyor; ayrı bir zorunlu
güncelleme altyapısı yazılmayacak.

⚠ **Aşağıdaki metin İKİ NOKTADA BAYAT — 2 Eylül'de KODDAN ölçüldü.**
Maddeyi bloke eden iki ön koşul olarak yazılan şeyler artık YOK:

| Metnin dediği | Bugünkü gerçek |
|---|---|
| *"Her derleme `1.0.0`, eşiği yükseltmek EN YENİSİNİ de kilitler"* | `env.dart` → `appVersion = '1.0.5'`, `pubspec` `1.0.5+1`; senkron `app_version_parity_test.dart` ile ZORLANIYOR |
| *"`UpdateRequiredScreen`de mağaza butonu YOK, ekran bir ÇIKMAZ"* | `update_required_screen.dart` → `market://details?id=…` + `https://play.google.com/…` yedeği, `launchUrl` ile |

**Yani sürüm kapısı bugün ÇALIŞIR durumda ve silinmedi.** Madde kapandı
ama mekanizma duruyor: acil bir fren gerekirse `app_config`teki
`mobile_min_supported_version` yükseltilir, o kadar. Kapının kendisi
ROADMAP'te "Sürüm sıralaması…" bölümünde not edildi.

⚠ Metnin GEÇERLİ kalan uyarısı: yanlış kurulmuş bir zorunlu güncelleme
uygulamayı açılmaz hâle getirebilir ve düzeltmesi ancak yeni bir sürüm
yayınlamakla mümkündür. Eşiği yükseltmek geri alınabilir bir işlem
DEĞİLDİR — sahadaki istemciler için anlık ve serttir.

---

## 8. FAZ A1 Bölüm 6 (Paylaşma) — iPad popover ankrajı · ✅ **KAPANDI** (3 Eylül 2026, cihazda doğrulandı)

**Kod işi YOK, bekleyen tek şey bir DOĞRULAMA.** Parça 86 (13 Ağustos
2026): `share_plus`ın iOS eklentisi iPad'de paylaş sayfasını popover
açıyor ve ankraj (`sharePositionOrigin`) istiyor; verilmezse paylaşmak
yerine `FlutterError` döndürüyor, iki `catch` onu yutuyor ve kullanıcıya
**hiçbir şey olmuyor**. Düzeltme yazıldı (ortak `shareOriginFrom`, `origin`
typedef'te zorunlu, iki katmanlı test) — kalan tek soru gerçek iPad'de
popover'ın çıkıp çıkmadığı. Üç yol da denenmeli: (a) oyun geçmişinde tahta
paylaşımı, (b) Setup'ta "Arkadaşınla paylaş", (c) Arkadaşlar'da davet linki.

### ✅ 2 Eylül 2026 — DOĞRU ORTAMDA KOŞULDU ve İKİ YOL KIRIK ÇIKTI

Appetize → **iPad Air / iOS 16.2** (yani native iOS kanalı, doğru cihaz
tipi). Sonuç:

| Yol | Ankraj nereden geliyordu | Sonuç |
|---|---|---|
| Oyun geçmişi → tahta paylaşımı | `_captureKey.currentContext` — tahtanın `RepaintBoundary`si, **küçük ve gerçek** kutu | ✅ popover açıldı |
| Setup → "Arkadaşınla paylaş" | `_SetupScreenState.context` — **ekranın TAMAMI** | ❌ "hiç tepki vermiyor" |
| Arkadaşlar → davet linki | `_FriendsModalState.context` — **ekranın TAMAMI** | ❌ buton `…` (meşgul) durumunda kilitli |

**KÖK SEBEP:** Parça 86 ankraj vermemeyi düzeltmişti; ankrajın KENDİSİNİN
geçerli olması gerektiğini kimse kontrol etmemişti. Ekranı kaplayan bir
dikdörtgen "boş değil" ve "kök view'ın içinde"dir — yani her iki eski
kontrolden de geçer — ama iPad'de popover görünmüyor ve
`SharePlus.share` **hiç dönmüyor**.

**Fırlatma DEĞİL, ASILMA — kanıt ekran görüntüsünde:** `_handleInvite`in
`finally`si `_inviteBusy`i sıfırlıyor; buton yine de `…`ta kaldı. Yani
future dönmedi. Setup'ta meşgul durumu olmadığı için aynı asılma "hiçbir
şey olmuyor" gibi görünüyor.

**TESTLER NEDEN YEŞİLDİ:** `share_recent_test`in ankraj iddiası yalnızca
"boş değil" + "ekranın içinde" diyordu; ekran boyutunda bir kutu ikisini de
sağlıyor. Üstelik test yalnızca ÇALIŞAN yolu (oyun geçmişi) kapsıyordu.

**DÜZELTME (aynı gün, dalda):**
- `shareOriginFrom` artık ekranı iki eksende birden (≥%95) kaplayan bir
  kutuyu ankraj SAYMIYOR, 1×1 merkez yedeğine düşüyor — popover ekranın
  ortasında görünür oluyor. ⚠ Eşik bilerek "büyük" değil "ekranın tamamı":
  ilk yazılan %50 ALAN eşiği ÇALIŞAN yolu kırardı (tahtanın ankrajı
  telefonda alanın ~%46'sı).
- İki kırık çağrı yeri artık kendi düğmesinin kutusuna bağlanıyor
  (`_shareLinkKey`, `_inviteButtonKey`) — oyun geçmişindeki
  `_captureKey.currentContext ?? context` deseninin aynısı.
- `shareOriginFrom` için doğrudan sözleşme testi + akış testine üçüncü
  iddia. Negatif eş: eşik kaldırılırsa test düşüyor.

⏳ **KALAN: aynı üç yolun Appetize/iPad'de YENİDEN denenmesi.** Üçünde de
paylaş kutusu açılmalı ve buton `…`ta kalmamalı.

⚠ **BU MADDEYİ NE KAPATMAZ — ölçüldü, 2 Eylül 2026.** Kullanıcı üç yolu da
GERÇEK bir iPad'de denedi ve *"sorun yok"* dedi, ama derleme
`kelimeki.com`/Pages idi, yani **web** derlemesi. Orada `share_plus`ın WEB
eklentisi (`navigator.share`) çalışıyor ve iOS platform kanalına HİÇ
uğranmıyor — ankrajı kontrol eden kod (`FPPSharePlusPlugin.m`) native iOS
eklentisinin içinde. **Cihazın iPad olması yetmiyor, DERLEMENİN native
olması gerekiyor.** Parça 86'nın 3 ay görünmeden kalmasının sebebi de tam
olarak buydu; aynı deneme tekrarlanmasın diye buraya yazıldı.
(Denemenin kanıtladığı ayrı bir şey var ve o gerçek: iPad Safari'de web
paylaşımı çalışıyor — `kelimeki.com`'a iPad'den girenlerin yüzeyi.)

**Kanıtlayan tek ortam:** Appetize → iOS simülatörü → **iPad cihaz tipi**.
CI zaten imzasız bir simülatör derlemesi üretip Appetize'a yüklüyor, yani
**Apple üyeliği GEREKMİYOR**. iPad tipinin panelde seçilebilir olup
olmadığı doğrulanmadı — `mobile/docs/test-ortamlari.md` bunu "panelden
bakılmalı" diye bırakmış; seçilemiyorsa madde gerçek bir native iPad
derlemesine (Apple üyeliği) kalır.

⚠ Bu bölüm önceden *"FAZ B turunda kapanır"* diyordu; yanlıştı. FAZ B
Android/Play turu ve 24-25 Ağustos Android turu temiz geldi — ROADMAP'in
kendisi *"Madde 8 bundan ETKİLENMEDİ"* diyor. Maddenin gerçek ön koşulu
Android turu değil, yukarıdaki iki ortamdan biri.

**KAPANIŞ (3 Eylül 2026):** kullanıcı Appetize'da **iPad**'de üç paylaşım
yolunu da yeniden denedi — *"üçü de açtı"*. Madde kapandı.

**Kanıtı güçlü kılan şey tek bir yeşil değil, DAVRANIŞIN DEĞİŞMESİ:** aynı
ortamda (Appetize, iPad Air / iOS 16.2) düzeltmeden ÖNCE üç yoldan ikisi
kırıktı — Setup'ta "hiç tepki yok", Arkadaşlar'da buton `…`ta kilitli.
Düzeltmeden sonra üçü de popover açıyor. Yani ölçüm, düzeltmenin kendisine
bağlı; "bir kez denedik, çalıştı" değil.

⚠ **Bu maddenin asıl dersi kodda değil, DOĞRULAMA ORTAMINDA:** iki gün
boyunca "cihazda denenecek" diye beklerken, arada bir kez GERÇEK bir
iPad'de denendi ve *"sorun yok"* çıktı — ama o deneme `kelimeki.com`/Pages
**web derlemesiyle** yapılmıştı, yani `share_plus`ın iOS kanalına hiç
uğramamıştı. Cihazın iPad olması yetmiyor, DERLEMENİN native olması
gerekiyor. Doğru ortamda ilk denemede hata anında çıktı.
