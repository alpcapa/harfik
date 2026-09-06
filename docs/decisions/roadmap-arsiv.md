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
| Madde 23 · Faz 2 — motor: `findAIMoves`/`pickTopMove`/`AI_LEVEL_TOP_N` üç kopyada, `GameState.aiLevel`, golden sıfır fark + `reducer_ai2_kolay` | 6 Eylül 2026 |
| Madde 23 · Faz 1 — sunucu: `games.ai_level` + k-lig formülü TEK SQL fonksiyonu (`league_points_for`), `verify-league-points` | 6 Eylül 2026 |
| Madde 23 · Faz 0 — YZ seviye kadranının ölçüm aleti (`simulate-ai-levels`), Kolay N=4 | 6 Eylül 2026 |
| Hata avı geçişi (incelemenin 2. geçişi) | 5 Eylül 2026 |
| Performans geçişi (incelemenin 3. geçişi) | 5 Eylül 2026 |
| Temizlik geçişi (incelemenin 4. geçişi) | 5 Eylül 2026 |
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
| Hata avı geçişi #24 — `CONFIRM_SWAP` taslak taşları yok ediyordu | 5 Eylül 2026 |
| Hata avı geçişi #25 — taş değiştirme seçimi indekse bağlıydı | 5 Eylül 2026 |
| Hata avı geçişi #23 — Edge Function'daki motor kopyası bayattı (CANLIDA) | 5 Eylül 2026 |
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

## 1.0.7 sürüm turu — ✅ **SAHADA** (6 Eylül 2026)

Kapalı test (Alpha) kanalına gönderildi ve yayınlandı. **Kapalı testteki
paket artık `1.0.7 (545)` = commit `78383eb`** (`versionCode` = CI koşu
numarası; AAB sha256 `4df3928c…28837`, 6 Eylül 07:08:49 UTC).

**Paketin içeriği** — 1.0.6 (`711eaaa`) paketinden beri porta dokunan işler:

| Commit | Ne |
|---|---|
| `f75a12c` (#441) | arka plandan dönüş artık "ekrana giriş" sayılıyor — `away_return.dart` yeni, `setup_screen.dart` + `live_games_tab.dart` bağlandı |
| `19e17fe` (#443) | Hızlı Başlangıç'ın oyun sonu cümlesi tek cümleye indi ve kazananı söylüyor — `help_modal.dart` + `help_modal_test.dart` |
| `7312eb8` (#447) | Skor kartındaki kafa kafaya çubuğunun yazıları bara yaklaştı (10 → 2 px) ve "TÜM OYUNLAR" butonu barın hizasına oturdu — `player_score_card_modal.dart` |
| `b1b9daf` (#452) | Taş değiştirmede taslak taşlar yok olmuyor + senkron rafı yeniden sıralarsa seçim düşüyor — `kelimeki_core/engine/reducer.dart` (motor düzeltmesi, iki yeni golden) |
| `91325d5` (#457) | Temizlik: erişilemez `INIT` action'ı kaldırıldı (davranış değişmedi) |
| `028a805` · `8796c6b` (#460) | Hesap menüsündeki k-lig puanı oturum boyunca donuyordu — `account_button.dart`; `Navigator.push` Setup'ı canlı tuttuğundan `initState` bir daha koşmuyor, o yüzden portta web'den ÇOK daha görünürdü |

### Karar iki kez çevrildi ve sebebi BAYAT BİR LİSTEYDİ

Bekletme kararı 4 Eylül'de verilmişti (*"sürüme gönderme, daha üzerine yeni
işler gelecek"*) ve 5 Eylül akşamı tekrarlandı: *"sürümü çıkartmaya değecek
önemde değil bence, sürümü bekletelim."* **O an tablo üç satır
görünüyordu.** Tablo ölçülüp eksik iki satır (#452, #457) eklenince
kullanıcı kararı çevirdi: *"Aslında bayağı dolmuş. O zaman bunu yarın yeni
sürüm ile gönderelim."*

Yani gecikmenin sebebi bir öncelik tercihi değil, **listenin kendisinin
bayat olmasıydı** — ve eksik satırlardan biri (#452) gerçek bir veri kaybı
hatasıydı. Bölümün "listeye bakma, komutu koş" uyarısının ölçülmüş bedeli
bu turdur.

### İki yanlış hüküm düzeltildi (ikisi de Console hakkında)

Aynı turda ajan, Play Console'a erişimi olmadığı hâlde Console hakkında iki
hüküm kurdu ve ikisi de yanlıştı:

1. **"Yeni sürüm 14 gün sayacını sıfırlar mı?"** diye bir gönderim kapısı
   uydurdu. Kullanıcı itiraz etti: *"14 gün sayacının yeni sürümle alakası
   ne. Her gün neredeyse sürüm çıktık daha önce, bunu hiç sormadın?"* Cevap
   zaten repodaydı — sayaç 27/28 Ağustos'ta başladı ve pencerenin içinde
   ALTI sürüm çıktı (1.0.1 → 1.0.6, 29 Ağustos – 3 Eylül) ve kart saymaya
   devam etti. Console'un **Submission activity** ekranı bunu bağımsız
   olarak doğruladı: pencerede beş gönderim, hepsi `Published`.
2. **"12 gerçek sayı mı, tavan mı"** açık sorusunda ayırt edici gözlem
   olarak *"sayının 12'nin üstüne çıkması"* önerilmişti — o gözlem hiçbir
   zaman gerçekleşemezdi. Kullanıcı kapattı: *"12 kişi Tavan, google daha
   fazla olsa bile gerçek sayıyı göstermiyor."*

**Kural (bu turdan çıktı):** Play Console hakkında bir şeyi kayda geçirmeden
önce SOR. Erişimi olmayan taraf "bilinmiyor" ilan edemez — ya deponun kendi
geçmişine bakar (`git log -p -- mobile/app/pubspec.yaml`), ya kullanıcıya
sorar. İkisi de yapılmadığında biri gereksiz bir kapı, öteki kusurlu bir
ölçüm yöntemi üretti.


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


## Hata avı geçişi — kapanan maddeler (5 Eylül 2026)

İncelemenin 2. geçişinin (bkz. `ROADMAP.md` → "Hata avı geçişi") üç
bulgusundan İKİSİ aynı gün düzeltildi; #23 (Edge Function'daki bayat motor
kopyası) hâlâ AÇIK ve `ROADMAP.md`'de duruyor — o bir sunucu değişikliği,
kendi turunda gidiyor.

**Ortak ders:** ikisi de golden vector'lar yemyeşilken yanlıştı, çünkü
fixture'lar web ile Dart'ı KARŞILAŞTIRIYOR — ikisinde de aynı olan bir
hatayı yapısal olarak göremezler. Düzeltmeler bu yüzden İKİ kanıtla birden
geldi: yeni fixture'lar (parite) **ve** `npm run verify-swap-invariants`
(doğruluk). Yeni bir değişmez eklerken bu ikiliği koru — "parite yeşil"
tek başına "doğru" demek değil.

**Fixture'ların kurala duyarlı olduğu kanıtlandı** (deponun kendi ölçütü:
kural geri alınıp yeniden üretildi): `reducer_crafted_swap_draft` son
adımda 100 → **98** taşa düşüyor, `reducer_sync`in 2b adımında
`swapSelection` **[0, 2]** olarak hayatta kalıyor. `verify-swap-invariants`
de aynı geri almada 2 kontrolle düşüyor.

### 24. `CONFIRM_SWAP` tahtadaki taslak taşları YOK EDİYOR — **GİZİL, ölçüldü**

Rastgele eylem koşumu 100 taşlık torbanın **93'e düştüğü** bir dizi buldu.
Sebep tek satır: `CONFIRM_SWAP` (`gameReducer.ts`) `placed: {}` yazıyor ama
o taşları rafa GERİ ALMIYOR. `TOGGLE_SWAP_MODE` girişte `recallAll` çağırıyor,
`CONFIRM_SWAP` çıkışta çağırmıyor — asimetri burada.

```
adım 33 CONFIRM_SWAP: 100 → 93 taş
  önce:  swapMode=true  swapSelection=[0]  placed=7  raf=0
```

**Bugün UI'dan ERİŞİLEMEZ, ölçüldü** — dört ekranın dördü de taş koymayı
`swapMode`'da engelliyor (`App.tsx:1371,1626` · `OnlineGameScreen.tsx:715,937`
· `game_screen.dart:464` · `online_game_screen.dart:1165`) ve swap modunda
"Karıştır"/raf sürüklemesi hiç gösterilmiyor. Yani bulgu bir arıza değil,
**bir borç**: taş korunumu gibi bir değişmez, reducer'ın kendisinde değil,
dört ayrı ekrandaki dört ayrı `if`te tutuluyor. Beşinci bir yüzey (ya da bu
dördünden birinde bir gerileme) onu sessizce düşürür.

⚠ **Port da BİREBİR aynı** (`reducer.dart` `_confirmSwap` → `placed: {}`) —
yani parite KORUNMUŞ durumda ve golden vector'lar bu yüzden bunu asla
göremez. Bu, "parite yeşil = doğru" varsayımının bu geçişteki en net
karşı örneği.

Düzeltme tek satır ve İKİ tarafta birden: `CONFIRM_SWAP`, `TOGGLE_SWAP_MODE`
gibi önce `recallAll` çağırsın (ya da `placed` doluyken hiç çalışmasın).
Motor dosyası değiştiğinden golden vector'lar yeniden üretilmeli.

### 25. Taş değiştirme seçimi İNDEKSE bağlı, senkron rafı yeniden sıralıyor — **CANLIDA, dar**

`swapSelection` raf İNDEKSLERİ tutuyor. `SYNC_ONLINE_STATE`, turn ilerlemediyse
`swapMode`/`swapSelection`'ı bilerek koruyor (doğru karar — arka plandan dönen
sekme seçimi silmesin) **ama rafı sunucudaki sıraya geri yazıyor.** Kullanıcı o
turda "Karıştır"a bastıysa iki sıra farklıdır. Ölçüldü:

```
sunucu rafı  : L E L V N K S
karıştırılan : N L K V S E L     ← kullanıcı "Karıştır"a bastı
seçim: indeks 0 → "N"
senkron sonrası: L E L V N K S   ← swapMode=true, swapSelection=[0] korundu
indeks 0 artık → "L"             ⚠ "N" seçilmişti, "L" değişecek
```

Tetikleyici zinciri dar: aynı turda Karıştır → Değiştir → taş seç → araya bir
senkron girmesi (10 dakikalık periyodik yenileme ya da uygulamaya geri dönüş).
Seçim vurgusu gözle görülür biçimde başka taşa atlar, yani dikkatli kullanıcı
fark eder — ama vurguya baktıktan SONRA gelen senkron sessizdir. Web ve port
aynı davranışta.

⚠ **Yan kalem — portta olan bir koruma web'de YOK.** `online_game_screen.dart`
göndermeden önce `swapSelection.any((i) => i < 0 || i >= me.rack.length)` ile
sınır dışı indekste gönderimi İPTAL ediyor; web'in `handleConfirmSwap`'i
(`OnlineGameScreen.tsx:1254`) doğrudan `me.rack[i].letter` okuyor ve bu satır
`try` bloğunun DIŞINDA — sınır dışı bir indeks `TypeError` fırlatır.
**Bugün erişilemez, ölçüldü:** rafı turn ilerlemeden kısaltan tek sunucu yolu
zaman aşımı teslimi ve o yol `is_game_over=true` yazıyor, `canAct` de bunu
eliyor. Yine de web bu korumayı portla eşitlemeli — sınır kontrolü, kuralın
kendisinden bağımsız olarak doğru olan taraf.

Kalıcı düzeltme ikisini birden kapatır: seçimi indeksle değil taş KİMLİĞİYLE
tut, ya da `SYNC_ONLINE_STATE` gelen raf mevcut raftan farklıysa
`swapSelection`'ı temizlesin.


### #23 — KAPANIŞ (5 Eylül 2026)

**Düzeltme:** iki fonksiyon `src/`den taşındı (`computeConqueredChain` +
`computeAllTerritories` → `_game/validator.ts`; `tryCornerStart` →
`_game/ai.ts`, artık kullanılmayan `cornerBounds` importu da çıkarıldı) ve
`play-ai-turn` yeniden deploy edildi — **sürüm 7**, `verify_jwt: true`
(canlıdan OKUNUP aynı değer açıkça geçildi, bkz. kök `CLAUDE.md`'deki tuzak).

**Kapı: `npm run verify-edge-engine-parity`.** Metin diffi DEĞİL davranış
karşılaştırması — `_game/` kopyası bilerek KISMİ (validatePlacement* orada
yok, yorumlar kırpılmış, importlar farklı), düz bir diff gürültüden ibaret
olurdu. Ölçülenler: bölge fixture'ının tamamı, puanlama fixture'ının tamamı,
1690 hücre×puan vergi kombinasyonu, dört köşenin ilk hamlesi, ve web
motoruyla oynanan gerçek bir oyunun 30 ara pozisyonu. Kapı Edge kopyasının
sözlüğünü sahte bir Supabase istemcisiyle besliyor, böylece iki motor AYNI
kelime havuzuyla karşılaştırılıyor ve fark yalnızca algoritmadan geliyor.

⚠ **CI `paths` listesine `supabase/functions/**` eklendi** — yoksa yalnızca
Edge kopyası değişen bir PR'da iş hiç koşmazdı, yani kapı tam da onu koruması
gereken değişiklikte sessiz kalırdı.

**Kapıyı YAZARKEN yeni bir etki ölçüldü:** ayrışma yalnızca ilk hamlede ve
vergide değil, oyun ORTASINDA da hamle seçimini değiştiriyordu (web
"CANİCE" 11 puan ↔ edge "CİCİ" 9 puan). İlk raporda bu yoktu — bulgu ölçünce
BÜYÜDÜ, tıpkı güvenlik geçişindeki anon sızıntısı gibi.

**Deploy doğrulaması — kaynak düzeyinde kesin:** `get_edge_function` ile
canlıdaki içerik çekilip depodaki dosyalarla programatik olarak
karşılaştırıldı; **9 çalışma-zamanı dosyasının 9'u birebir aynı**.
`_game/types.ts` canlıda YOK ve bu beklenen: dosya yalnızca `type`/`interface`
ihraç ediyor, transpile'da tamamen siliniyor (v6'da da yoktu).

**SAHADA DOĞRULANDI (5 Eylül 2026, aynı gün):** gerçek bir 4 kişilik Canlı
oyunda (iki test hesabı + 4. koltuk YZ) YZ `KAKTÜS` oynadı — 6 taş,
**(12,7) → (12,12)**. Köşe 3'ün ev karesi (12,12) ve kelime oradan SOLA
uzuyor; eski kod başlangıcı yalnızca 9-12 bloğundan seçip sağa/aşağı
uzattığından bu hamle yapısal olarak imkânsızdı (tavan 4 taştı). Aynı hamle
paketin açıldığını da kanıtladı. Aşağıdaki uyarı bu ölçümle KAPANDI, tarihsel
kayıt olarak duruyor.

⚠ **O ana kadar ÖLÇÜLEMEYEN tek şey çalışma zamanı açılışıydı.** Bu ortam `supabase.co`ya
POST atamıyor (ajan vekili engelliyor — aynı sınır #22'de de kayıtlı), ve
YZ'li aktif oyun olmadığından fonksiyon deploy'dan sonra hiç çağrılmadı
(`function_edge_logs`'ta kayıt yok). Paketin esbuild ile temiz bundle olduğu
ve deploy'un kendisinin hatasız tamamlandığı doğrulandı, ama ilk gerçek YZ
turuna kadar "açılıyor" kanıtı YOK. **Bu önemli, çünkü arıza SESSİZ olurdu:**
`play-ai-turn`ün `catch`i son çare olarak "pas geç"e düşüyor — bozuk bir
motor hata vermez, YZ yalnızca sürekli pas geçer.

**Zamanlama bilinçliydi:** deploy anında YZ koltuklu AKTİF Canlı oyun YOKTU
(ölçüldü: 16 aktif oyunun 0'ı, YZ'li dört oyunun dördü de `finished`), yani
hiçbir devam eden oyun ortasından değişmedi. Ayrıca `submit_move`
düzeltilmiş (daha yüksek) vergiyi reddetmiyor — tek kontrolleri hedefin
geçerliliği, tutarın negatif olmaması ve toplamın `p_base_points`ı aşmaması.

**Geri alma:** eski kod git'te; `_game/`'in önceki hâlini geri koyup yeniden
deploy etmek yeterli. Panelden sürüm geri alma ajana kapalı.

### 23. Edge Function'daki motor kopyası BAYAT — **CANLIDA, ölçüldü**

`supabase/functions/_game/` (`ai.ts`, `validator.ts`, …) `src/`'nin elle
tutulan kopyası ve `play-ai-turn` onu kullanıyor — yani **Canlı oyunlardaki
YZ koltuğu bu kodla oynuyor.** İki ayrı motor değişikliği bu kopyaya hiç
işlenmemiş. `list_edge_functions`: `play-ai-turn` ACTIVE, sürüm 6, son
güncelleme **1 Ağustos 2026** — iki değişiklikten de ÖNCE.

**23a — YZ'nin köşe açılışı (17 Ağustos 2026 düzeltmesi eksik).** Edge
kopyasındaki `tryCornerStart` hâlâ eski hâlinde: başlangıç hücresini
yalnızca 4×4 blok içinde arıyor ve kelimeyi yalnızca sağa/aşağı uzatıyor.
Aynı sözlükle, aynı rafla (`A B A R T M A`), boş tahtada ölçüldü:

| Köşe | web / port | Edge (canlıdaki YZ) |
|---|---|---|
| 0, 1, 2 | 7 taş "ABARTMA" 35 puan | aynı |
| **3 (sağ-alt)** | 7 taş "ABARTMA" **35 puan** | 4 taş "ABAT" **6 puan** |

Yani kök `CLAUDE.md`'de yazılı 29 puanlık açılış handikabı web'de ve portta
kapatıldı, **sunucuda duruyor**. 2 kişilik oyunda YZ HER ZAMAN köşe 3'te
(`cornersFor`), yani YZ'li her 2 kişilik Canlı oyunda tekrarlanıyor.

**23b — Bölge kuralı (24 Ağustos 2026 "iletken hücre" değişikliği eksik).**
Edge kopyasındaki `computeConqueredChain` tek geçişli eski sürüm; `supported`
parametresi ve iletken-hücre dalı hiç yok. Portun kendi parite fixture'ı
(`territory.json`) Edge kopyasına da soruldu — 5 vakanın 1'i ayrışıyor,
ve ayrışan tam da kuralın POZİTİF dalı:

| Vaka | fixture | web | Edge |
|---|---|---|---|
| `desteksiz_rakip_tasi_iletken` | [16, 18] | [16, 18] ✓ | **[16, 16]** ⚠ |
| öteki 4 vaka | — | ✓ | = |

**Fark PUANA dönüşüyor.** `computeInvasionSplit` fonksiyonunun kendisi iki
kopyada birebir aynı, ama `computeAllTerritories`'i çağırdığından sonuç
ayrışıyor. Aynı tahtada, (7,12) hücresine 30 ham puanlık bir hamle:

| | oynayana kalan | bölge sahibine giden |
|---|---|---|
| web / port | 20 | **10** |
| Edge (canlıdaki YZ) | **30** | **0** |

Yani YZ bazı hamlelerde bölge vergisini EKSİK ödüyor ve o skor
`submit_move` ile veritabanına, oradan k-lig puanına yazılıyor. (`submit_move`
bölgeyi SQL'de yeniden hesaplamıyor — bkz. #18 — dolayısıyla reddetmiyor.)

**Kök sebep bir kural boşluğu.** "`src/` değişirse `_game/` da elle
güncellenmeli" kuralı YAZILI ama yalnızca
`docs/decisions/online-game-screen.md`'de; kök `CLAUDE.md`'nin "İş
bittiğinde" senkron tablosunda satırı YOKTU (`src/game/`+`src/utils/`
satırı yalnızca golden vector + Dart testlerini söylüyor). Bu geçişte o
satır eklendi. Derleyici de göremez: iki kopya ayrı `tsconfig`/deploy
paketinde.

**Düzeltmenin şekli (yapılmadı — bilerek):** iki dosyayı `src/`'den yeniden
kopyala, `play-ai-turn`'ü yeniden deploy et (⚠ `verify_jwt: true` — deploy
öncesi `list_edge_functions` ile OKU ve AYNI değeri açıkça geçir, bkz.
`## Supabase`), ve aynı PR'da bir `npm run verify-edge-engine-parity`
kapısı ekle — deponun öteki 15 `verify-*` betiğiyle aynı desen; kural
ancak ölçülürse tutuyor. Betiği düzeltmeden ÖNCE eklemek anlamsız
(ilk koşuşta kırmızı). **Bu bir SUNUCU değişikliği: `main`'e merge
beklemez, kapalı testteki paketi de anında etkiler.**

## Hata avı geçişi — KAPANDI (5 Eylül 2026)

İncelemenin 2. geçişi (yukarıdaki tabloda ⬜ idi). Kapsam ROADMAP'in kendi
tarifi: reducer/validator değişmezleri, web↔port paritesi, eşzamanlı yazım
yarışları, hook sırası.

**Yöntem — parite testlerinin GÖREMEDİĞİ yer.** Golden vector'lar web ile
Dart'ı karşılaştırır; İKİSİNDE DE olan bir hatayı hiçbir zaman göremezler.
Bu yüzden geçiş iki ayaklı koşuldu: (1) rastgele tam oyunlar + rastgele
EYLEM dizileriyle motorun değişmezlerini doğrudan sınayan bir koşum,
(2) aynı kaynaktan kopyalanmış dosyaların birbirinden ayrışıp ayrışmadığının
ölçülmesi. Üç bulgunun üçünü de bu iki ayak buldu; mevcut testlerin hiçbiri
kırmızıya dönmüyordu.

**Üçü de KAPANDI** (5 Eylül 2026, aynı gün). #24 (`CONFIRM_SWAP` taslak
taşları yok ediyordu) ve #25 (taş değiştirme seçimi indekse bağlıydı) web+port
birlikte düzeltilip iki yeni golden fixture + `npm run verify-swap-invariants`
kapısıyla; #23 (Edge Function'daki bayat motor kopyası) `src/`den taşınıp
`play-ai-turn` yeniden deploy edilerek ve `npm run verify-edge-engine-parity`
kapısı eklenerek. Üçünün de anlatısı `docs/decisions/roadmap-arsiv.md`'de.

✅ **SAHADA DOĞRULANDI (5 Eylül 2026).** Deploy'un tek açık kalemi
"çalışma zamanı açılışı ölçülemedi" idi; kullanıcı gerçek bir 4 kişilik
Canlı oyun kurup (iki test hesabı + 4. koltuk YZ) YZ'nin oynamasını
bekledi. Ölçüm `online_game_moves`tan:

| | |
|---|---|
| Hamle | `KAKTÜS` — 6 taş, 7 puan |
| Hücreler | **(12,7) → (12,12)** |

**Bu tek satır düzeltmeyi kanıtlıyor.** Köşe 3'ün ev karesi (12,12);
kelimenin SON harfi onun üstünde, yani kelime evden SOLA uzuyor ve 7.
sütundan başlıyor. `cornerBounds(3)` = satır/sütun 9-12, ve eski kod
başlangıç hücresini yalnızca o bloğun içinden seçip sağa/aşağı uzatıyordu —
7. sütundan başlamayı hiç DENEMİYORDU, blok içinden başlayan 6 harflik bir
kelime de 14. sütuna taşıp eleniyordu. Yani bu hamle eski kodla yapısal
olarak imkânsızdı (o köşeden tavan 4 taştı). Aynı hamle paketin AÇILDIĞINI
da kanıtlıyor: sözlük yüklendi, `findAIMove` koştu, `submit_move`a gitti.

⚠ **Beklenen bir log satırı — hata DEĞİL:** aynı saniyede
`[play-ai-turn] submit_move hatası: Sıra sende değil.` göründü. Sebebi
tasarım: oyun ekranı açık olan HER katılımcının istemcisi `triggerAiTurn`
çağırıyor (`OnlineGameScreen.tsx`), üç kişi ekrandayken iki istemci yarıştı,
ikincisi 158 ms geç kalıp sıra kontrolüne takıldı. `online_game_moves`ta o
tur için TEK satır var — çifte hamle yok, hakem çalıştı. Ama bu satır
YZ'li her turda tekrarlanacak ve `function_edge_logs`ta gerçek hataları
gölgeliyor; istenirse ayrı bir temizlik konusu (göndermeden önce sırayı
yeniden oku, ya da bu reddi `error` yerine bilgi olarak logla).

⚠ **`supabase.co` bu ortamdan TAMAMEN erişilemez** — #22'de "POST atamıyor"
yazıyordu, ölçüldü: GET/OPTIONS/POST üçü de `000` dönüyor. Yani Edge
Function'ları ajan tetikleyemez; bu sınıf doğrulama her zaman gerçek bir
istemciden gelmek zorunda.

⚠ **Geçişin en büyük dersi:** bu kod tabanında motorun ÜÇ kopyası var
(web `src/`, port `mobile/kelimeki_core/`, Edge Function
`supabase/functions/_game/`) ama otomatik parite kanıtı yalnızca İLK
İKİSİ arasında. Üçüncüsü iki kez sessizce geriye kaldı ve ikisi de
CANLIDA. Bir sonraki tur "üç kopya" cümlesini varsayım olarak alsın.

### Zemin sağlam — bir sonraki tur bunları YENİDEN ölçmesin

Aşağıdakiler bu geçişte ölçüldü ve temiz çıktı:

- **Motor değişmezleri.** 60 rastgele tam YZ oyunu (2 ve 4 kişilik) + 80
  rastgele EYLEM dizisi oyunu boyunca her adımda sınandı: taş korunumu
  (bag+raf+tahta+placed = 100), negatif skor yok, raf hiç 7'yi aşmıyor,
  **iki oyuncunun bölgesi hiç çakışmıyor** (`CLAUDE.md`'de yazılı değişmez),
  sıra hiçbir zaman teslim olmuş oyuncuya düşmüyor, `moveHistory`'de negatif
  puan yok. Tek ihlal #24 idi (düzeltildi; koşum artık UI kısıtı taklit
  edilmeden de temiz).
- **Türkçe dil kuralı.** `src/`'de Türkçe metne uygulanmış tek bir native
  `toUpperCase`/`toLowerCase` YOK (bulunan kullanımlar e-posta başlığı, UTM,
  ISO tarih gibi ASCII); isme göre sıralayan altı yerin altısı da `trCompare`.
- **`JSON.parse`.** Yedi çağrı yerinin yedisi de `try/catch` içinde ve bozuk
  localStorage'da "boş" sayıyor — bozuk kayıt açılışta çökertmiyor.
- **Hook sırası.** `npm run verify-hook-order` temiz; ayrıca betiğin bilerek
  görmediği sınıf da arandı — `src/` altında koşullu ya da döngü içinde
  çağrılan hook YOK.
- **`submit_move` eşzamanlılığı.** `online_games` satırında `for update`
  kilidi + `p_move_id` ile idempotent yeniden deneme var. Web'in `p_move_id`
  göndermemesi bir bulgu DEĞİL: portun kendi yorumunda (`online_api.dart:42`)
  bilinçli bir mobil dayanıklılık kararı olarak yazılı. (Yine de ucuz bir
  kalem: web telefonda da koşuyor ve tek satırlık bir UUID, yanıtı kaybolan
  bir hamlenin ikinci denemesinde sahte "Sıra sende değil."i yapısal olarak
  imkânsız kılardı.)
- **Mevcut kapıların tamamı yeşil:** `tsc --noEmit`, 15 `verify-*` betiği,
  `check-doc-size`, golden vector'lar TAZE (yeniden üretildi, sıfır fark),
  6842 Dart parite kontrolü, 774 Flutter testi.

## Performans geçişi — KAPANDI (5 Eylül 2026)

İncelemenin 3. geçişi (yukarıdaki tabloda ⬜ idi). Kapsam ROADMAP'in kendi
tarifi: bundle, sıcak sorguların index kapsamı, liste render'ı, N+1 RPC.

**Yöntem — tahmin değil, iki ölçüm kaynağı.** (1) `pg_stat_statements`'ın
69 günlük penceresi (2026-06-28'den beri hiç sıfırlanmamış), yani "hangi
sorgu gerçekten pahalı" sorusunun cevabı canlı veriden okundu; (2) `npm run
build` çıktısı ve `explain (analyze, buffers)`. Kod okuyarak "burası yavaş
olabilir" denmedi.

⚠ **Bu geçişin en büyük dersi — ÖLÇÜMÜN KENDİSİ yanlış kurulabilir.**
`list_my_online_games`i iyileştirirken ilk karşılaştırma eski gövdeyi
`authenticated` rolüyle (RLS uygulanarak), yenisini `postgres` ile (RLS'siz)
ölçtü ve "12,1 → 6,0 ms, %50 hızlanma" gibi göründü. Oysa fonksiyonun sahibi
`postgres` ve BYPASSRLS taşıyor — yani `security definer` gövdesinde RLS
zaten hiç uygulanmıyordu, iki ölçüm farklı dünyalardaydı. Aynı koşulda
tekrarlandığında gerçek sonuç **süre değişmedi** (4,75 → 4,84 ms) çıktı.
İkinci tuzak aynı turda: eski gövde `select count(*) from (...)` ile
ölçüldüğünde 0,23 ms verdi, çünkü planlayıcı `count(*)`ın okumadığı skaler
alt sorguların TAMAMINI eliyor. **Kural: bir "önce/sonra" ölçümünde rol,
RLS ve çıktının gerçekten tüketilip tüketilmediği ÜÇÜ de eşitlenmeden sayı
yazma.** (Güvenlik geçişinin dersi "bulguyu ölçmeden yazma"ydı; bunun
devamı: ölçümün kendisini de doğrula.)

### Bulgular — dördü düzeltildi

| # | Bulgu | Ölçüm | Durum |
|---|---|---|---|
| 26 | Admin paneli (3.227 satır) + `html-to-image` HER kullanıcıya iniyordu | App paketi 359 → **266 KB** (gzip 99,4 → **72,9**, %27 az) | ✅ |
| 27 | `subscribeMyOnlineGames` çağıran başına AYRI kanal → kullanıcı başına 9 Realtime aboneliği | Realtime `apply_rls` DB yürütme süresinin **%75,8'i** (3,38 M çağrı / 18.327 s) — abonelik doğrudan çarpan; 9 → **3** | ✅ |
| 28 | Canlı oyunda kelime doğrulaması SIRALI RPC (`for…await`) | `is_valid_word` 21.106 çağrı ↔ `submit_move` 1.558 → hamle başına **~13 ardışık gidiş-dönüş**; paralelleştirildi (1 tur) | ✅ |
| 29 | `list_my_online_games` slot başına aynı satırı iki kez okuyor (N+1) | tampon 1.240 → **706** (%43 az); **süre değişmedi** | ✅ |

**#26 — paket.** `UserMenu` `AdminDashboard`ı statik import ediyordu, yani
yalnızca adminlerin açabildiği 80 KB'lık panel herkesin App paketindeydi;
`shareBoardImage` de `html-to-image`i (13,7 KB) aynı şekilde taşıyordu.
İkisi de `lazy`/dinamik import'a çevrildi. ⚠ Servis çalışanının PRECACHE
toplamı DEĞİŞMEDİ (2018 → 2019 KiB) — kod yer değiştirdi, silinmedi; kazanç
ilk boyamada ayrıştırılan/çalıştırılan JS'te ve PWA kurulmadan önceki ilk
ziyarette.

**#27 — kanal çoğaltması.** Üç çağıran (`Setup` rozeti, `LiveGamesTab`
listesi, `useAppIconBadge`) aynı anda canlı olabiliyor ve her biri kendi
kanalını açıyordu (3 kanal × 3 tablo). Sunucuda WAL'daki her satır
değişikliği HER abonelik için ayrı RLS'ten geçtiğinden abonelik sayısı
doğrudan maliyeti çarpıyor. `api.ts` içinde referans sayımlı tek kanala
indirildi — **çağıranların hiçbiri değişmedi**, imza ve iptal fonksiyonu
aynı. `onResubscribe` semantiği korundu ve kanal başına işliyor: kanal
zaten bağlıyken katılan bir dinleyici sinyal ALMAZ (kendi ilk yüklemesini
mount'ta zaten yaptı), soket gerçekten kopup döndüğünde O ANDAKİ tüm
dinleyiciler alır. Yeni kapı: **`npm run verify-shared-realtime`** (CI'da
koşuyor) — negatif eşle sınandı, paylaşım kaldırılınca gerçekten düşüyor.

**#28 — sıralı doğrulama.** `OnlineGameScreen.handlePlay` kurulan her
kelimeyi sırayla soruyordu; `App.tsx`'in aynı yeri `Promise.all` ile
ZATEN paraleldi ve gerekçesi de orada yazılıydı — yani iki ekranın
paylaştığı desenlerden biri sessizce ayrışmıştı (kök `CLAUDE.md`'nin
"App.tsx ↔ OnlineGameScreen" satırının tam olarak uyardığı sınıf).
Paralelleştirmeyle birlikte `App.tsx`'teki `catch` de taşındı: eski kodda
beklenmedik bir `throw` (tam ağ kopukluğu) yakalanmıyor, hamle hiçbir
mesaj/dispatch olmadan askıda kalıyordu.

**#29 — N+1.** `name` ve `avatar_url` slot başına İKİ ayrı `profiles`
araması, `my_invite_status` ve `my_invite_id` ise BİREBİR aynı sorgu, iki
kez. LATERAL birleştirmeye çevrildi. **Çıktının bit bit aynı kaldığı
kanıtlandı:** 51 kullanıcının hepsi için eski/yeni gövde yan yana koşulup
karşılaştırıldı, sıfır fark; karşılaştırmanın kör olmadığı üç negatif eşle
gösterildi (`name`, slot `invite_status`, `my_invite_id` tek tek
bozulduğunda 21/21/20 kullanıcıda fark). ⚠ **Bir dal ölçülemedi:**
`pending_outgoing`/`pending_incoming` mevcut veride HİÇ oluşmuyor (o dalı
bilerek ters çevirdiğimizde karşılaştırma sıfır fark verdi), eşdeğerlik
orada gövdeden kanıtlandı — gerekçe migration dosyasının başında.

### Ölçüldü, DÜZELTİLMEDİ — bilinçli

- **Aynı Realtime olayında `list_my_online_games` ÜÇ KEZ çekiliyor**
  (Setup, LiveGamesTab, useAppIconBadge; üçü de 300 ms debounce'la aynı
  anda). Uçuştaki isteği paylaştırmak (in-flight coalescing) ilk akla gelen
  çözüm ama **RİSKLİ**: `LiveGamesTab`'ın `loadGames` fonksiyonu
  `check_turn_timeout`/`check_invite_expiry` YAZDIKTAN sonra bilerek taze
  bir okuma yapıyor (`rows2`); o çağrı, yazmadan ÖNCE başlamış bir isteğe
  yapışırsa bayat veri alır. Doğru çözüm tüketicilerin veriyi paylaşması
  (tek kaynak + fan-out), yani bir bileşen ameliyatı — performans geçişinin
  değil kendi turunun işi. Bugünkü bedeli: bu RPC DB yürütme süresinin
  %3,8'i, yani 69 günde 914 s.
- **`list_my_online_games` SAYFALAMASIZ.** En aktif kullanıcıda 69 oyun ve
  liste sonsuza dek büyüyor; her Realtime olayında TAMAMI çekiliyor. Bugün
  sorun değil (12 ms), ama bu maliyet kullanıcı başına oyun sayısıyla
  doğrusal artıyor ve "eski bitmiş oyunlar" hiç düşmüyor. Eşik: kullanıcı
  başına birkaç yüz oyun.
- **`fetchIncomingFriendRequests` yalnızca `.length` için tüm satırları
  çekiyor** (`UserMenu` ve `useAppIconBadge`; 27.541 çağrı / 148 s). Bir
  sayı RPC'si yeterdi. Küçük kalem, ama ikisi de rozet besliyor.
- **`local_game_saves` upsert'i 106.305 çağrı / 267 s** — her otomatik
  kayıt bir yazma. Tasarım gereği (bkz. `docs/decisions/local-game-persistence.md`);
  bugün en pahalı YAZMA yolu, ama davranışı değiştirmeden kısılamaz.
- **PostgREST şema önbelleği 2.915 kez yeniden yüklenmiş** — tek başına
  `pg_timezone_names` 1.770 s (%7,3) ve yanındaki katalog sorgularıyla
  birlikte toplam ~%8,5. Uygulama kodu DEĞİL (migration/`NOTIFY pgrst` ya da
  yeniden başlatma kaynaklı); Supabase tarafında bir ayar konusu.
- **Advisor INFO kalemleri:** iki indekssiz FK (`online_game_clients.user_id`,
  `support_inbox.seen_by`) ve 8 hiç kullanılmamış indeks. İkisi de küçük
  tablolar; indeks eklemek/silmek ölçülebilir bir kazanç vermez, bu yüzden
  dokunulmadı. ✅ Tek **WARN** kalemi (`league_rewards` RLS initplan)
  kapatıldı — kazanç ölçülemez (26 satırlık tablo), gerekçe advisor
  listesini temiz tutmak.

### Zemin sağlam — bir sonraki tur bunları YENİDEN ölçmesin

- **`Board.tsx` zaten doğru memoize edilmiş:** bölge hesabı, bölge sahibi
  haritası, dış hatlar ve hamle rozeti `useMemo` arkasında ve bağımlılıkları
  dar. Liste render'ında bulunacak bir şey çıkmadı.
- **`meanings.json` (6,5 MB) bilinçli olarak precache DIŞINDA** ve tembel
  yükleniyor; `words` (747 KB) ayrı chunk ve tembel. İkisi de kayıtlı karar,
  bulgu değil.
- **Edge Function'ın sözlük yükleyicisi (`_game/wordSet.ts`) zaten
  optimize:** sayfalar `Promise.all` ile paralel ve isolate başına
  önbellekli. 69 günde 2.626 sayfa isteği ≈ 41 soğuk başlangıç.
- **Bağımlılıklar yalın:** üretim bağımlılığı 7 paket (React, supabase-js,
  fontsource, html-to-image). Kaldırılacak ölü bağımlılık yok.
- **Mobil portta aynı kanal çoğaltması VAR ama daha küçük** (iki tüketici:
  `setup_screen` rozeti + `live_games_tab`). Aynı düzeltme oraya
  taşınabilir; sunucu maliyetini düşürür, kullanıcıya görünen davranışı
  değiştirmez. Port turuna bırakıldı — bu geçiş web'i kapsıyordu.

## Temizlik geçişi — KAPANDI (5 Eylül 2026)

İncelemenin 4. ve son geçişi (yukarıdaki tabloda ⬜ idi). Kapsam ROADMAP'in
kendi tarifi: ölü kod, erişilemez şubeler, kullanılmayan bağımlılıklar,
bayat doküman atıfları.

**Yöntem — tarama otomatik, karar elle.** Üç makine taraması koşuldu:
(1) her `export`'un `src/` + `scripts/` + `tests/` + `supabase/` + `mobile/`
içinde metinsel bir tüketicisi var mı; (2) her `src/` modülünün bir import
edeni var mı; (3) her `.md`'de geçen dosya yolu ve `npm run` adı gerçekten
var mı. Sonra her aday ELLE okundu — çünkü bu depoda ölü görünen kodun
çoğu **bilerek** duruyor ve gerekçesi dosyanın kendi başlığında yazılı.

⚠ **Bu geçişin en büyük dersi — "kullanılmıyor" bir bulgu DEĞİL, bir soru.**
Tarama 80 aday çıkardı; elle okunduğunda çoğu üç meşru sınıftan birine
düştü: (a) **kayıtlı bilinçli karar** (`fetchAdminGuestDeviceBreakdown` ve
`fetchAdminGuestStandaloneBreakdown` — ikisinin de JSDoc'unda neden
çağrılmadığı ve neden silinmediği yazılı; dokunulmadı), (b) **portun/Edge
kopyasının tükettiği** (`TileInfo`, `FormedWord`, `BOARD_CENTER`,
`AvatarSlot`… — web'de "kullanılmıyor" görünüyorlar çünkü tüketici Dart ya
da Deno), (c) **golden vector'ların tükettiği** (`setRandomSource`,
`SET_MESSAGE` — üretimden çağrılmıyorlar ama parite kanıtı onlara dayanıyor).
Gerçekten kaldırılan yalnızca hiçbir sınıfa girmeyen ikisi oldu.

### Kaldırılanlar

1. **`spectating` dalı (`App.tsx` + `GameHeader`'ın `exitDisabled` prop'u)**
   — ROADMAP'in bilinen örneği. Ölçüm: `SURRENDER` `src/` içinde HİÇBİR
   yerden dispatch edilmiyor (29 Temmuz 2026'da logo onaysız Setup'a dönmeye
   başlayınca tek tetikleyici kalkmıştı), ve **Flutter portu bu bandı hiç
   portlamamış** — yani kod ölü olmakla kalmıyor, web↔port paritesini de
   bozuyordu. Reducer'ın `SURRENDER` case'i DURUYOR (port taşıyor,
   `buildGameRecord`'un `surrendered` yolu terk-edilme akışında canlı).
   Ayrıntı: kök `CLAUDE.md` → "Teslim sonrası izleme".
2. **`INIT` action'ı (web + port)** — `ABANDON`'un birebir kopyasıydı
   (ikisi de `createInitialState()` döner), hiçbir yerden dispatch
   edilmiyordu ve golden vector üreticisi bile onu hiç kullanmıyordu.
   Dört dosyadan birlikte kaldırıldı: `gameReducer.ts` (tip + case),
   `actions.dart`, `reducer.dart`, `action_codec.dart`. **Golden vector'lar
   yeniden üretildi ve SIFIR fark çıktı** — davranışın değişmediğinin kanıtı.

### Onarılanlar

3. **`npm run generate-reel` KIRIKTI** (ölü kod değil, kopmuş zincir).
   `scripts/reel/build.mjs` sahneyi `node_modules/.cache/kelimeki/reel-state.json`'dan
   okuyordu ama o dosyayı üreten adım (`scripts/reel/emit-state.ts`) hiçbir
   yerden — ne `package.json`'dan, ne CI'dan, ne başka bir script'ten —
   çağrılmıyordu; komut taze bir klonda ENOENT ile düşerdi. Ara JSON tamamen
   kaldırıldı: `build.mjs` artık `state.ts`'i, kapanış kartı için ZATEN
   kullandığı esbuild + dinamik import kalıbıyla kendisi koşuyor
   (`emit-state.ts` silindi). Doğrulandı: sahne kuruluyor (torba 34, 2
   oyuncu, 6 sürükleme adımı, raf ARKADAŞ).
4. **`package.json` bağımlılık sınıfları** — iki yönde de yanlıştı. Üç
   `@fontsource/*` paketi `dependencies`'teydi ama `src/` içinde hiç import
   edilmiyor (fontlar `src/fonts/files/` ve `public/fonts/` altında repoda;
   paketlere yalnızca `generate-og-image.mjs`/`generate-icons.mjs`/
   `generate-logo*.mjs` `node_modules/@fontsource/...` yolundan erişiyor) →
   `devDependencies`. Ters yönde: **`esbuild` 14 npm script'in çağırdığı bir
   CLI olmasına rağmen hiç bildirilmemişti**, yalnızca `vite`'ın transitif
   bağımlılığı olarak vardı. Açıkça eklendi (0.21.5 — lock dosyasında yeni
   paket İNMEDİ, yalnızca `dev` bayrakları değişti). Kural kök `CLAUDE.md` →
   "Bağımlılık Sınıfı".
   ⚠ **Bu, 3. geçişin (performans) bir tespitini düzeltiyor:** orada
   *"Bağımlılıklar yalın: üretim bağımlılığı 7 paket… Kaldırılacak ölü
   bağımlılık yok"* yazılmıştı. Sayı doğruydu, SINIF yanlıştı — o yedinin
   üçü hiçbir zaman tarayıcıya gitmiyordu. Ders: "ölü mü" sorusu
   "doğru yerde mi" sorusunu kapsamıyor.
5. **`flutter analyze` tek uyarısı** (`tap_target_test.dart:206`,
   `curly_braces_in_flow_control_structures`) temizlendi — port artık
   `flutter analyze` ve `dart analyze`de sıfır uyarı veriyor.

### Zemin sağlam — bir sonraki tur bunları YENİDEN ölçmesin

- **`noUnusedLocals` + `noUnusedParameters` ZATEN açık** (`tsconfig.json`),
  yani `src/` altında kullanılmayan import/yerel değişken DERLEME HATASI.
  Bu sınıfı aramaya gerek yok; derleyici kapıyı zaten tutuyor.
- **Yetim modül yok:** `src/` altındaki 123 `.ts`/`.tsx` dosyasının hepsinin
  bir import edeni var (font CSS'leri `main.tsx`'ten geliyor).
- **Doküman atıfları temiz:** her `.md`'de geçen dosya yolu ve `npm run`
  adı tarandı; kırık atıf ÇIKMADI. `docs/decisions/live-game-and-friends.md`
  gibi görünen tek "eksik dosya" bölünmenin kendisini anlatan tarihsel bir
  cümle, bayat bir atıf değil. `docs/decisions/` indeks tablosu da
  gerçek dosya listesiyle birebir tutuyor.
- **Edge Function envanteri kapalı — ve bir tanesi SİLİNDİ.** Repodaki 17
  fonksiyondan 16'sının çağıranı vardı (`src/`, `mobile/`, migration
  cron'ları); tek istisna `push-selftest`, kök `CLAUDE.md`'de zaten
  "silinebilir" diye kayıtlı bir FCM teşhis fonksiyonuydu ve `verify_jwt:
  false` ile herkese açık bir POST ucuydu.
  **Sıra ÖNEMLİYDİ, ikisi aynı anda yapılamazdı:** ajanın Supabase MCP'sinde
  Edge Function SİLEN bir araç YOK (`list`/`deploy`/`get` var, `delete`
  yok), yani yalnız repo kopyasını silmek canlıda kaynaksız bir uç
  bırakırdı — ölü kodu temizlemek yerine onu görünmez yapardı. Bu yüzden
  önce kullanıcı panelden sildi (5 Eylül 2026), sonra `list_edge_functions`
  ile 17 → **16** doğrulandı, ve ancak o zaman
  `supabase/functions/push-selftest/` repodan kaldırıldı.
  **Ders:** canlı bir kaynağın repo kopyasını silmeden önce canlıdaki
  karşılığının gittiğini ÖLÇ; ajanın yetmediği yerde adımı kullanıcıya ver
  ve dönüşünü doğrula — "silinebilir" notu silinmiş demek değil (bu notun
  kendisi 30 Ağustos'tan beri duruyordu).
  ⚠ Yan etki: kök `CLAUDE.md`'deki `verify_jwt: false` envanteri SEKİZDEN
  YEDİYE indi. O liste her deploy öncesi okunan tek kaynak olduğundan aynı
  PR'da güncellendi — güncellenmeseydi bir sonraki deploy silinmiş bir
  fonksiyonu arardı.
- **`scripts/generate-klig-logo.mjs`** hiçbir npm script'ten ya da dokümandan
  çağrılmıyor ama ÖLÜ DEĞİL — `generate-logo.mjs` gibi elle koşulan bir
  pazarlama üreticisi. Silmek yerine `docs/decisions/marketing-assets.md`'nin
  komut listesine yazıldı.

---

## 23 · Faz 0 — Ölçüm aleti · ✅ YAPILDI (6 Eylül 2026)

`ROADMAP.md` madde 23'ün (Seviyeli YZ) sıfırıncı fazı; madde AÇIK, yalnızca
bu faz kapandı. Faz metni buraya `ROADMAP.md` 23.3'ten taşındı, sonuç ve
tablo `docs/decisions/product-backlog.md` → "YZ zorluk seviyesi" notunda.

**Faz 0 — Ölçüm aleti (kod ürüne girmez).** Model: Opus 5, efor `medium`.
Karar verildi (23.2: B); bu faz artık yalnızca alet + ön eleme.
- Backlog'daki YZ↔YZ koşumu **repoya girer**: `scripts/simulate-ai-levels.ts`
  (oyun sayısı ve N kümesi parametre; tohumlu, `setRandomSource` ile;
  çıktı: kazanma oranı, ortalama skor, ortalama hamle puanı — backlog
  tablosuyla aynı kolonlar ki eski ölçümle kıyaslanabilsin). "Uygulayan
  yeniden ölçmesin" doğru, ama Faz 5'te YENİ motor için aynı alet
  gerekecek ve bugün repoda YOK (`scripts/` tarandı).
- İlk koşum: N ∈ {1, 2, 3, 5} — N=2 backlog tablosunda yok, Kolay'ın olası
  ikinci adayı. Oyun sayısı 24 yerine ≥100 (24 oyunda %25 ile %30 ayrılamaz;
  ±%9 güven aralığı — tahmin, koşum kesinleştirdi).
- Çıktı: Kolay için N (başlangıç N=3, 23.2). Not backlog maddesine eklenir.

**Nasıl yapıldı (6 Eylül 2026):**
- `npm run simulate-ai-levels` — `-- --oyun 200 --n 1,2,3,4,5 --tohum 1
  --dogrula 5`. Üretim tarafı reducer'ın kendi `AI_PLAY`'iyle oynuyor (yani
  GERÇEKTEN üretim kodu); top-N tarafı `PLACE_TILE`+`PLAY` ile sürülüyor,
  hamle yoksa YZ'yle aynı davranış (torba doluysa tüm raf değişir, boşsa
  pas). Koltuk değişimli: çift oyunlarda top-N 2. koltukta, teklerde 1.
- **`src/utils/ai.ts`e DOKUNULMADI.** Alet arama döngüsünün bir kopyasını
  taşıyor; tek fark "iki en-iyi" yerine "iki sınırlı liste" (Faz 2
  tasarımının prototipi — sıralı ekleme, `sort` yok, eşitte ilk bulunan
  önde). Kopya ayrışmasın diye `--dogrula` her hamlede liste başını üretim
  `findAIMove`'la karşılaştırıyor; **`web-ci.yml` bu kontrolü her PR'da 2
  oyunla koşuyor.** Faz 2 motora `level` ekleyince alet onu çağırmalı,
  kopya ve CI adımı SİLİNMELİ.
- N=1'de rastgele ÇAĞRI YOK, N>1'de tek `rng()` çağrısı — Faz 2'nin "N=1
  yolu bayt-eş kalır" sözleşmesi burada da aynen uygulandı.
- Süre: 200 oyun ≈ 3 dk (tek çekirdek). Beş N paralel koşuldu.

**Sonuç:** Kolay için **N=4** (%33; hedef ~%30; kullanıcı aynı gün bir kez
N=3'e dönüp N=4'te karar kıldı). Planın N=3 tahmini 24
oyunluk eski tablonun gürültüsüne dayanıyordu (%25 sanılan değer 200
oyunda %36 çıktı). Ayrıca ilk koltuk avantajı ölçüldü (~12 puan; iki aynı
motor: 1. koltuk 64/100, 2. koltuk 39/100) — insanın yerel 2 kişilik oyunda
her zaman 1. koltukta olduğu düşünülürse sahadaki %48,7 bu avantajı zaten
içeriyor. Tablo ve gerekçe backlog notunda.

---

## 23 · Faz 1 — Sunucu · ✅ YAPILDI (6 Eylül 2026)

`ROADMAP.md` madde 23'ün (Seviyeli YZ) birinci fazı; madde AÇIK, yalnızca
bu faz kapandı. Faz metni buraya `ROADMAP.md` 23.3'ten taşındı.

**Faz 1 — Sunucu (migration; anında canlı, sıfır davranış değişikliği).**
Model: Opus 5, efor `medium`. Tek migration:
- `games.ai_level text check (ai_level is null or ai_level in ('kolay','normal','zor'))` +
  `comment` + **`grant insert (ai_level), select (ai_level)`** — `games`'in
  tablo düzeyi grant'i YOK (10 Ağustos gizlilik düzeltmesi), kolon tek tek
  verilir; `platform`'dan farkı SELECT'in de şart olması.
- `public.league_points_for(p_rank int, p_player_count int, p_surrendered bool, p_ai_level text) returns int immutable` —
  tablo 23.0. Dört nesne (`player_stats`, `player_stats_overall`,
  `leaderboard`, `_award_league_rewards`) `case` bloğu yerine bunu çağırır.
  `create or replace view` yeter (kolon listesi değişmiyor);
  `_award_league_rewards` gövde değişikliği, imza aynı.
- `get_shared_game`: dönüş tablosuna `ai_level` → **dönüş tipi değişir →
  `drop function` + `create` + `revoke/grant` elle** (`20260812131123`
  dersi). `SharedGamePage` bunu okuyacak.
- `admin_ai_balance()`: `group by player_count, coalesce(ai_level,'normal')`
  → aynı drop+create+grant.
- **Kanıt (uygulamadan önce ve sonra):** `select user_id, total_score from
  player_stats_overall` çıktısı bayt-eş olmalı (tüm satırlar `null` →
  Normal); `k_lig_siralama` sırası değişmemeli. Bu sorgu migration'ın
  yorumuna yazılır.
- `list_migrations` ile dosya adı eşleştirilir; fonksiyonlar GERÇEKTEN
  çağrılır (kural 3).
- `database.types.ts`: `Game.ai_level`, `NewGame.ai_level?`,
  `GameHistoryEntry` + `SharedGameData`'ya alan.
- `scripts/verify-league-points.mjs` + `package.json` + CI'da koşum
  (`verify-league-tiers` nasıl bağlıysa öyle).

**Nasıl yapıldı (6 Eylül 2026):** tek migration
`20260906114252_ai_level_and_league_points_for.sql`, MCP ile canlıya
uygulandı, `list_migrations` ile dosya adı eşleştirildi.
- **Kopya sayısı DÖRT değil BEŞ çıktı.** Plan `player_stats`,
  `player_stats_overall`, `leaderboard`, `_award_league_rewards` diyordu;
  canlıdan `pg_get_functiondef`/`pg_get_viewdef` ile `player_count <> 2`
  aranınca `trg_award_league_rewards` de göründü — `rank_down_notice`
  migration'ı trigger'ın içine delta hesabı için formülün bir kopyasını
  daha koymuştu. Beşi de artık `league_points_for`u çağırıyor; canlıda
  inline formül KALMADI (aynı arama uygulamadan sonra boş döndü).
  `my_leaderboard_rank` ise planın dediği gibi `k_lig_siralama` →
  `leaderboard` üzerinden okuyor, dokunulmadı.
- **Fonksiyon önce `pg_temp`'te sınandı:** 953 canlı satırda yeni
  fonksiyon ↔ eski `case` sıfır fark; Normal ızgarası (4 sıra × 2 mod ×
  teslim × null/normal) sıfır fark; Kolay/Zor ızgarası 23.0 tablosunu
  birebir verdi (Kolay 1/0, Zor 4/2, 2 kişilikte 2. sıra 0, teslim -2).
- **Öncesi/sonrası bayt-eş:** `player_stats_overall` (30 satır,
  `6a1c0f01…`), `player_stats` (48, `8adaa454…`), `leaderboard` (30,
  `b0344e3d…`), `k_lig_siralama` (30, `a8a74692…`), `league_rewards` (27,
  `0cf352bb…`) — beş karma da uygulamadan sonra aynı. `admin_ai_balance`
  eski çıktısı (2 kişilik 620: 321G/3B/296M · 4 kişilik 115: 35G/1B/79M/24
  ikincilik) `ai_level='normal'` etiketiyle aynen döndü.
- **Grant ölçümü planı düzeltti:** `games`te tablo düzeyinde INSERT/UPDATE
  zaten VAR (10 Ağustos yalnızca SELECT'i kolon kolon yapmış), yani yeni
  kolon otomatik yazılabilir; SELECT kolon kolon ve bu kolon için ŞART
  (`platform`ın tersi). İkisi de açıkça verildi.
- **Tablo `(values …)` listesi olarak yazıldı**, `case` değil — böylece
  `scripts/verify-league-points.ts` (`verify-league-tiers` deseni) onu
  mekanik ayrıştırıyor: kanonik 23.0 tablosu ↔ SQL ↔ `leaguePoints.ts`in
  GERÇEK çıktısı ↔ `league_points.dart`ın sabit dizisi; ayrıca beş sunucu
  nesnesinin en yeni tanımının fonksiyonu çağırdığını doğruluyor (altıncı
  kopya kapısı). Üç negatif dene (SQL tablosu bozuk · Dart sabiti bozuk ·
  trigger'a inline formül eklenmiş) → üçü de düşüyor. CI `web-ci.yml`'de
  `verify-league-tiers`in hemen altında.
- **İstemci tarafı (davranış değişmedi):** `database.types.ts`e `AiLevel`
  + `Game.ai_level`/`NewGame.ai_level?`/`SharedGameData.ai_level`/
  `AdminAiBalanceRow.ai_level`; `GameHistoryEntry.ai_level` OPSİYONEL
  çünkü `fetchMyGames` seçiyor ama `list_liked_games` döndürmüyor (Faz 3).
  `AdminDashboard` kutuları artık `(players, ai_level)` anahtarlı — Normal'de
  etiket bugünkü gibi, Kolay/Zor gelince " · Kolay"/" · Zor" eklenir.
- Port ETKİLENMEDİ: `get_shared_game`/`admin_ai_balance` portta
  çağrılmıyor; view kolon listeleri değişmedi.

---

## 23 · Faz 2 — Motor · ✅ YAPILDI (6 Eylül 2026)

`ROADMAP.md` madde 23'ün (Seviyeli YZ) ikinci fazı; madde AÇIK, yalnızca
bu faz kapandı. Faz metni buraya `ROADMAP.md` 23.3'ten taşındı.

**Faz 2 — Motor (web + port + Edge kopyası AYNI PR).** Model: Opus 5,
efor `high` — parite işi.
- `findAIMove(..., level: AiLevel = 'normal')`: `consider` iki en-iyi yerine
  iki **sınırlı liste** tutar (güvenli / vergili, boyut N, sıralama: puan
  azalan, eşitte ilk bulunan önde — bugünkü `>` kuralının liste karşılığı).
  Dönüş: güvenli liste boş değilse ondan, değilse vergili listeden;
  **N=1 → `list[0]`, rastgele ÇAĞRI YOK; N>1 → tek `randomSource()`
  çağrısı, `floor(r * list.length)`.** Rastgele tüketim sayısı sözleşmenin
  parçası (torba/karıştırma deseninin aynısı).
- `AiLevel → N` eşlemesi tek yerde: `src/game/constants.ts`
  (`AI_LEVEL_TOP_N`), Dart `constants.dart`, Edge `_game/constants.ts` —
  `verify-edge-engine-parity` ve `verify-sql-engine-parity`'nin sabit
  kilitleme deseniyle üçü kilitlenir.
- Dart `findAIMove(..., {AiLevel level = AiLevel.normal, required Rng rng})`;
  reducer kendi `rng`'sini geçer.
- Edge `_game/ai.ts` + `constants.ts` kopyalanır; `play-ai-turn` seviye
  vermez (Normal). Deploy öncesi `list_edge_functions` ile `verify_jwt`
  okunur (`play-ai-turn` "false" listesinde DEĞİL → `true`).
- **Kanıt sırası:** (1) `generate-golden-vectors` → **sıfır fark** (N=1 yolu
  bayt-eş); (2) sonra `reducer_ai2_kolay.json` (tohumlu, `aiLevel:'kolay'`)
  eklenir, Dart `run_all.dart` yeşil; (3) `verify-edge-engine-parity` yeşil
  (Normal'de değişmedi; ayrıca Kolay için aynı tohumla iki motoru
  karşılaştıran bir adım eklenir — Edge'e `random.ts` kopyası girer, çünkü
  B'de bile kopyanın DAVRANIŞI eşit olmalı, sadece çağrılmıyor).
- Ürün yüzeyi YOK; kullanıcı hiçbir fark görmez.

**Nasıl yapıldı (6 Eylül 2026):**
- **Web (`src/utils/ai.ts`):** eski `bestSafe`/`bestAny` çifti iki sınırlı
  listeye (`safe`/`any`, `insertBounded`: azalan `rank`, eşitte ilk bulunan
  önde, `sort` YOK) çevrildi; `findAIMoves(..., n)` listeyi döndürür,
  `pickTopMove(list)` rastgelelik sözleşmesini uygular (boş → null; tek
  eleman → o, `nextRandom()` ÇAĞRILMAZ; birden fazla → TEK çağrı,
  `floor(r·len)`), `findAIMove(..., level = 'normal')` ikisini
  `AI_LEVEL_TOP_N[level]` ile bağlar. `random.ts`e `nextRandom()` eklendi
  (torbayla AYNI enjekte edilebilir kaynak). `AiLevel` tipi
  `database.types.ts`ten `src/game/types.ts`e taşındı (motor `lib/`
  import edemez; `database.types.ts` yeniden dışa aktarıyor).
- **Plandan sapma — `GameState.aiLevel` Faz 3'ten Faz 2'ye çekildi:**
  reducer düzeyinde bir Kolay golden'ı (`reducer_ai2_kolay`) seviyeyi ancak
  state'ten alabilir; action'a taşımak Faz 3'te tekrar değişecek bir şekil
  yaratırdı. Alan OPSİYONEL ve **Normal'de yazılmaz** (web `JSON.stringify`
  `undefined`ı atar; golden `serState` ve Dart `gameStateToJson` aynı
  sözleşmeyi uygular, `codec.dart` `as String?` ile toleranslı okur) — bu
  seçim sayesinde "sıfır fark" kanıtı state alanına rağmen ayakta kaldı ve
  `STORAGE_VERSION` bump edilmedi. `START` payload'ı `aiLevel?` alır;
  `AI_PLAY` `state.aiLevel ?? 'normal'` geçirir.
- **Kanıt sırası plandaki gibi:** (1) üretici DEĞİŞMEDEN
  `generate-golden-vectors` koşuldu → `git status` goldens'ta BOŞ (N=1 yolu
  bayt-eş). (2) Üreticiye `aiScenario(..., level)` + `aiLevelVectors()`
  eklendi → `reducer_ai2_kolay.json` (tohum 2026, 44 adım) +
  `ai_level.json`; `dart run test/run_all.dart` **6871 kontrol, 0 hata**.
  (3) `verify-edge-engine-parity`: `AI_LEVEL_TOP_N` web ↔ edge eşitliği ve
  her adımda aynı tohumlu LCG takılarak Kolay seçimi karşılaştırması (32
  pozisyon, sıfır fark) + duyarlılık kontrolü (Kolay 32 adımın 24'ünde
  Normal'den farklı hamle seçti — seviye parametresi bir yerde kaybolursa
  bu satır düşer).
- **Dart (`mobile/kelimeki_core`):** `AiLevel` enum + `AiLevelJson`
  (`parse` bilinmeyeni Normal'e, `parseOrNull` codec için),
  `aiLevelTopN`, `_Ranked`/`_insertBounded`, `findAIMoves`,
  `pickTopMove(list, rng)`, `findAIMove(..., {level, required rng})`;
  reducer kendi `rng`'sini geçer, `StartAction(players, {aiLevel})`,
  `GameState.aiLevel` (ctor'da opsiyonel — uygulamadaki `GameState(` çağrı
  yerleri değişmedi). `flutter analyze` (app) temiz.
- **Edge (`supabase/functions/_game/`):** `ai.ts` src'den import yolları
  çevrilerek yeniden kopyalandı (yorumlar artık kırpılmıyor — kopya
  src'yle satır satır aynı, fark yalnızca import'lar); `types.ts`e
  `AiLevel`, `constants.ts`e `AI_LEVEL_TOP_N`, yeni `random.ts`.
  `play-ai-turn/index.ts` DEĞİŞMEDİ (seviye vermez → Normal); yalnızca
  kopyayı eşitlemek için yeniden deploy edildi, `list_edge_functions`
  önce okundu (`verify_jwt: true`) ve aynı değer geçildi.
- **Ölçüm aleti (`scripts/simulate-ai-levels.ts`):** motor kopyası ve
  `--dogrula` silindi; top-N tarafı üretimin `findAIMoves`+`pickTopMove`
  çiftiyle oynuyor (Kolay = N=4 satırı artık üretim yolunun ta kendisi).
  `web-ci.yml`deki "kopya ayrışmadı mı" adımı kaldırıldı — kanıt artık
  golden'lar + Edge paritesi.
- **Ürün yüzeyi YOK:** hiçbir ekran `aiLevel` geçirmiyor, her oyun Normal;
  `npm run build` + 65 Playwright testi yeşil, `npm run lint` temiz.

## 23 · Faz 3 — Web ürün yüzeyi · ✅ YAPILDI (6 Eylül 2026)

`ROADMAP.md` madde 23'ün (Seviyeli YZ) üçüncü fazı; madde AÇIK (Faz 4 port,
Faz 5 Zor motoru), yalnızca bu faz kapandı. Faz metni buraya `ROADMAP.md`
23.3'ten taşındı. Yayın kanıtı (23.5: `curl kelimeki.com | grep
kelimeki-build` = `main` başı; Kolay'da biten oyunun kartı +1) merge
SONRASI okunur — kod tarafı burada.

**Faz 3 — Web ürün yüzeyi (merge → Vercel).** Model: Sonnet 5, efor
`medium`; Opus'a yükselt: `Setup.tsx` 1137 satır ve iki sekmeli.
- ~~`GameState.aiLevel` + `START` payload'ı~~ → **Faz 2 yaptı** (opsiyonel
  alan, yoksa Normal; `gameStorage` eski kaydı olduğu gibi okur, VERSION
  sabit). Kalan: Setup seçiminin payload'a geçmesi; `cloudSaveMirror`/
  `gameSync` jsonb'yi olduğu gibi taşıdığından ek iş yok — ama
  `verify-cloud-save-mirror` fixture'ına alan eklenir.
- `Setup.tsx` "+ Yeni Yapay Zeka Oyunu" formu: `OYUNCU SAYISI`'nın altına
  `ZORLUK` — üç seçenek, varsayılan Normal, misafirde de var (misafir de
  YZ'ye karşı oynuyor; kaydı yok, puanı yok, seçim yine anlamlı). Zor, Faz
  5 bitene kadar **gösterilmez**.
- `list_liked_games` RPC'sine `ai_level` (Faz 1 eklemedi — dönüş tipi
  değişir, drop+create+grant; `GameHistoryEntry.ai_level` o güne kadar
  opsiyonel).
- `buildGameRecord` → `ai_level`; `leaguePoints(rank, count, surrendered, level)`
  + dört çağıran; kartlarda rozet (`KOLAY`/`ZOR`, Normal'de yok — bugünkü
  kart aynen); Setup "devam eden oyun" kartına küçük etiket (aynı düzeni
  paylaşan `LiveGamesTab` kartı ETKİLENMEZ — o Canlı).
- `HelpModal` k-lig paragrafı: tabloyu anlat; `/nasil-oynanir/` ve
  `hukuki metin tek kaynak` testleri kendiliğinden kapsar.
- `tests/smoke.spec.ts`: "Kolay seçilip 2 kişilik oyun başlar, YZ hamle
  yapar" (mevcut ilk testin kopyası + seçici).
- `TESTING.md` §10'a "seviyeye göre puan" kontrol satırları; `README.md`
  + kök `CLAUDE.md` (Oyun Mekaniği'ne "YZ seviyesi" maddesi, Klasör
  Yapısı'na yeni script/fixture).
- ⚠ **Sıra tuzağı:** Faz 3 canlıya çıkınca web `kolay`/`zor` satırı
  yazmaya başlar; **eski port sürümü** o satırı okur ve puanı Normal
  formülüyle GÖSTERİR (sunucu doğru sayar, yalnızca gösterim yanlış), bulut
  kaydındaki `aiLevel`'i de yok sayıp YZ'yi N=1 oynatır. Pencere Faz 4
  sürümüne kadar; kabul edilebilir ama Faz 3 ve 4'ü aynı sürüm haftasına
  denk getirmek daha temiz.

**Nasıl yapıldı (6 Eylül 2026):**
- **Ürün sözlüğü tek dosyada — `src/utils/aiLevel.ts`:** `AI_LEVEL_LABEL`
  (Kolay/Normal/Zor), `SELECTABLE_AI_LEVELS` (`['kolay','normal']` — Zor
  Faz 5'e kadar listede YOK; o gün tek satır eklenir), `aiLevelOf` (null/
  bilinmeyen → Normal, sunucunun `coalesce`inin istemci eşi),
  `aiLevelBadgeLabel` (Normal → `null`). Terminoloji 23.4'ün önerisi:
  **Zorluk: Kolay · Normal · Zor**, üçüncü ifade yok.
- **Setup (`Setup.tsx`):** "Oyuncu sayısı" bloğunun ikizi bir `Zorluk`
  radyogrubu (`role="radiogroup"`/`radio` + `aria-checked` — smoke testi
  bununla seçiyor), Kolay seçilince tek cümlelik açıklama. `onStart(players,
  showTutorial, aiLevel)`; `SavedGameRow`a `aiLevel` prop'u, rozet
  avatarların altında (misafir localStorage kartı + girişli `cloudSaves`
  satırları). `LiveGamesTab` kartına dokunulmadı.
- **`App.startLocalGame(players, aiLevel?)`:** payload'a yalnızca
  Kolay/Zor girer — **Normal `'normal'` olarak YAZILMAZ** (Faz 2 sözleşmesi
  "alan yok = Normal"; iki biçim üretmemek için). Rövanş `state.aiLevel`i
  taşır. `GameOver`a `aiLevel` prop'u.
- **Kayıt/puan:** `buildGameRecord` `state.aiLevel` varsa `ai_level`
  gönderir (Normal → alansız → null). `leaguePoints(rank, playerCount,
  surrendered?, level?)` — `level`e **JS varsayılanı bilerek verilmedi**:
  `verify-league-points` ariteyi `leaguePoints.length` ile okuyor ve
  varsayılanlı parametre sayılmaz, betik sessizce "Faz 3 öncesi"ne
  dönerdi (ölçüldü). Dart `leaguePoints(..., {surrendered, AiLevel?
  aiLevel})` aynı PR'da, gövde satır satır aynı dallanma. Betik güncellendi:
  sayı dizisi artık her `return` ifadesindeki TÜM tamsayılar (ternary
  sabitleri dahil) ve dizi kanonik tabloyla da karşılaştırılıyor; ayrıca
  "eksik seviye (undefined/null) Normal" kontrolü. Çıktı: "3 seviye", tümü
  yeşil.
- **Dört kart:** `GameOver` (başlık altında `sm` rozet), `GameHistoryModal`
  ("Yapay Zeka" rozetinin sağında), `RecentGamesSection` (tarihin yanında),
  `SharedGamePage` ("N Oyunculu"nun yanında) — hepsi `AiLevelBadge`
  (`src/components/AiLevelBadge.tsx`; altın, `GameHistoryModal`ın 7px
  rozet diliyle aynı; Normal'de `null` döner, `gap` bile açılmaz).
- **Sunucu:** `20260906130756_list_liked_games_ai_level` — dönüş tipine
  `ai_level text` (`coalesce(mine.ai_level, g.ai_level)`), drop + create +
  revoke/grant, INVOKER korundu. Canlıya MCP ile uygulandı; doğrulama:
  `prosecdef=false`, sonuç tipinin son kolonu `ai_level`, ve `set_config
  ('request.jwt.claims', …)` + `set local role authenticated` ile gerçek
  bir kullanıcının 6 beğenisi kolonla döndü (hepsi null = Normal).
  `list_migrations` versiyonu `130756` ↔ dosya adı `130703` idi → dosya
  yeniden adlandırıldı (CLAUDE.md adım 5). `GameHistoryEntry.ai_level`
  artık `Pick`in içinde (zorunlu, `AiLevel | null`).
- **Kanıtlar:** `npm run verify-league-points` (3 seviye) ·
  `verify-cloud-save-mirror` (+2 kontrol: Kolay `aiLevel` aynadan dönerken
  korunur, Normal'de anahtar yok) · `generate-golden-vectors` → **sıfır
  fark** (`leaguePoints` motor listesinde; `ranking.json` üç parametreli
  çağrıdan üretiliyor) · Dart `run_all.dart` 6871 kontrol 0 hata, `dart
  analyze` + `flutter analyze` temiz · `tests/smoke.spec.ts` +2 test
  (Kolay: radyogrup varsayılanı Normal, Zor yok, seçim sonrası
  `localStorage`'daki `kelimeki:game-state` payload'ında `aiLevel:'kolay'`,
  YZ hamle yapar, seviye sabit kalır; Normal: kayıtta anahtar YOK) ·
  `tsc` temiz.
- **Dokunulmayan:** `TermsModal`/`PrivacyModal` (seviye kişisel veri
  değil), `submit_move`/SQL motor aynası, `create_online_game`, bildirim
  zinciri, `logGameStart` telemetrisi (seviye kırılımı `admin_ai_balance`ta
  zaten var), `Landing.tsx` (k-lig bölümü sayı vermiyor, yeni terim
  gerekmedi).

## 23 · Faz 4 — Port · ✅ YAPILDI (6 Eylül 2026)

`ROADMAP.md` madde 23'ün (Seviyeli YZ) dördüncü fazı; madde AÇIK (Faz 5 Zor
motoru), yalnızca bu faz kapandı. Faz metni buraya `ROADMAP.md` 23.3'ten
taşındı. Cihaz kanıtı (23.5: aynı hesap iki cihaz, portta Kolay biten oyun
web'de aynı puanla) kod bir Play sürümüne binince okunur — kod tarafı burada.

**Faz 4 — Port (sürüm turu).** Model: Opus 5, efor `medium`; cihaz turu
kullanıcıda.
- `codec.dart` (`aiLevel` toleranslı parse), `game_controller`/reducer
  `START` payload'ı, `setup_screen.dart` `_buildNewGameForm` seçici (web ile
  aynı etiketler), `game_record.dart` `ai_level`, `games_api.dart`
  `_listCols`, üç kart + `devam_eden_govde.dart`, `league_points.dart`
  imzası + `text_wrap_test`/`layout_parity_test` etkisi (rozet genişliği
  ölçülüyor mu, bak).
- `mobile/TESTING.md` §13'e madde; `mobile/docs/surumler.md` paket kütüğü.
- Parite testleri: kart metinleri web ile aynı (`icon_parity`/`layout_parity`
  deseni).

**Nasıl yapıldı (6 Eylül 2026):**
- **Faz 2/3 zaten yarısını yapmıştı:** `codec.dart`ın toleranslı `aiLevel`
  parse'ı, `StartAction(aiLevel:)`, reducer'ın `_startGame`i ve
  `league_points.dart` imzası Faz 2/3 PR'larında gelmişti; Faz 4 yalnızca
  ÜRÜN yüzeyini ve kayıt/liste yollarını bağladı. `devam_eden_govde.dart`a
  DOKUNULMADI — rozet kartın SOL sütununa (`_SavedGameRow._solBlok`) girdi,
  ortak gövde ve Canlı kartı aynen.
- **Ürün sözlüğü tek dosyada — `util/ai_level.dart`** (web `aiLevel.ts`
  ikizi): `aiLevelLabel`, `selectableAiLevels` (Zor YOK), `kolayAciklamasi`,
  `aiLevelBadgeLabel` (Normal/null → null). **`ui/ai_level_badge.dart`**
  (web `AiLevelBadge.tsx`): `game_history_modal`ın `_Badge` diliyle aynı,
  altın, `xs`/`sm`; görünmezken `SizedBox.shrink()` döner ama çağıranlar
  önündeki boşluğu `aiLevelBadgeLabel(...) != null` koşuluyla ekliyor —
  Normal kartın ölçüleri bayt bayt aynı (web'de `null` dönen bileşen flex
  `gap`i de açmıyor).
- **Setup:** `OYUNCU SAYISI`nın altına `ZORLUK` (`_SectionLabel` +
  `_ChoiceButton` ikizi, etiket `trUpper` ile `KOLAY`/`NORMAL`), Kolay
  seçilince web ile birebir açıklama; `_startNewGame` →
  `StartAction(..., aiLevel: _level == normal ? null : _level)` — **Normal
  YAZILMAZ** (web `startLocalGame` sözleşmesi). `game_screen._handleRematch`
  `state.aiLevel`i taşır. Devam eden kartı: avatarların altında rozet
  (yalnızca Kolay/Zor'da `Column`a sarılır).
- **Kayıt/liste:** `NewGameRecord.aiLevel` — `toJson` alanı YALNIZCA
  doluysa yazar (`web_game_record.json` fikstürü seviyesiz, bayt-bayt
  karşılaştırma bu sayede aynen geçiyor), `fromJson` toleranslı (eski kuyruk
  satırı → null). `GameHistoryEntry.aiLevel` + `_listCols`a `ai_level`
  (`list_liked_games` zaten döndürüyor, `fromJson` ortak). Üç kart
  `leaguePoints(..., aiLevel:)` + rozet: GameOver (başlık altında `sm`),
  Tüm Oyunlarım ("Yapay Zeka"nın sağında), Son Oynadıklarım (tarihin
  yanında). `help_modal.dart`a zorluk paragrafı web ile birebir.
- **Kapılar:** `test/ai_level_parity_test.dart` — web `aiLevel.ts`
  etiketleri + `SELECTABLE_AI_LEVELS` ↔ Dart (Zor açılırken iki liste AYNI
  PR'da), `Setup.tsx` Kolay açıklaması ↔ `kolayAciklamasi`, `HelpModal.tsx`
  zorluk paragrafı ↔ `help_modal.dart` (işaretler atılıp düz metin
  karşılaştırılıyor — `help_text_parity_test`in yakalamadığı "paragraf içi
  cümle" sınıfı burada kapalı). `test/ai_level_test.dart` — üç kartta Kolay
  golden'ıyla rozet + +1, Normal'de rozet yok + +2. `setup_screen_test` +3
  (ZORLUK bloğu sırası/varsayılan/Zor yok/açıklama; Kolay → `state.aiLevel`
  ve JSON'da `kolay`; Normal → anahtar YOK — ayrı test, aynı testte ikinci
  `pumpSetup` ilk oyunun devam-eden kartını gösterip formu gizliyor). `game_record_test` +1 (Kolay
  → `ai_level: kolay`, Normal → alan yok, kuyruk gidiş-dönüşü).
  ⚠ `ai_level_parity_test` `mobile/` DIŞINDAN üç dosya okuyor (`src/utils/
  aiLevel.ts`, `Setup.tsx`, `HelpModal.tsx`) — `web-ci.yml`in `paths`
  listesinde `src/**` zaten var, ek satır gerekmedi.
- **Dokunulmayan:** `kelimeki_core` (motor Faz 2'de bitti, golden'lar
  aynen), `online_game_screen.dart`/`live_games_tab.dart` (Canlı'da seviye
  yok), `cloud_save_repo.dart` (jsonb'yi codec olduğu gibi taşıyor),
  `surumler.md` (paket yüklenmedi — kütük paketi tutar, tur ROADMAP'ta).

**Aynı gece, cihaz turundan çıkan üç istek (6 Eylül 2026, web + port aynı
PR):** (1) rozet renkleri **Kolay yeşil · Normal turuncu · Zor kırmızı** —
yani Normal artık da çizilir; "rozet yalnızca sapınca" kuralı kalktı, yerine
"YZ oyununda her seviyede, Canlı'da hiç" geldi (`aiLevelForBadge(raw,
isAiGame)` iki tarafta; Canlı kartlar `online_game_id`, GameOver'da Canlı
ekran seviyeyi hiç geçirmiyor). (2) Rozet tahtanın alt şeridinde de,
"Hamleler"in yanında — Canlı'daki "· Mesajlaşma"nın yerinde; dokunulamaz,
şeridin 48px/`TapTarget` sayımına girmez. (3) Zorluk seçici butonları
Arkadaşınla sekmesinin alt-sekme pilleriyle aynı (11px, `py-2.5`), büyük
"Oyuncu sayısı" butonu gibi değil. Port: Parça 191.
