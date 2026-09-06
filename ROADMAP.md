# Kelimeki — Sıradaki İşler (22 Ağustos 2026)

**Bu dosya bir FİKİR LİSTESİ DEĞİL, sıralı bir yürütme planı.** Kök
`CLAUDE.md`'deki "Sonraya Bırakılan Ürün Fikirleri" bölümü *ne* yapılacağını
ve *neden* ertelendiğini anlatır; burası *hangi sırayla*, *hangi modelle* ve
*hangi tuzaklara dikkat ederek* yapılacağını anlatır.

**Burada YALNIZCA AÇIK maddeler yaşar.** Bir madde kapandığında (✅ /
YAPILDI / KAPANDI / CANLIDA / SAHADA) **aynı PR'da**
`docs/decisions/roadmap-arsiv.md`'ye taşınır — başlığı, madde numarası ve
tek tek satırları değiştirilmeden, böylece ona yapılan atıflar kırılmaz.
Kalıcı bir ders üretmişse dersin kendisi ayrıca ilgili bölümün tarihli
notuna geçer (projenin genel "değişiklik = tarihli not" disiplini).

⚠ **Aşağıda bir bölüme atıf görüp bulamıyorsan arşive bak** — "Faz 1-7",
"1.0.3/1.0.4 sürüm turu", "madde 1/6/10/11/12/13/16" ve "Sürüm A" 2 Eylül
2026'da oraya taşındı. O gün ölçüldü: dosyanın **%45'i** kapanmış işti ve
118 KB'a bu yüzden çıkmıştı — eşik düşük olduğu için değil, bu kural
uygulanmadığı için.

**Durum (25 Ağustos 2026):** `main` yeşil. FAZ A1 cihaz turu Bölüm 6
(Paylaşma, iPad popover) hariç kapalı. Web + port paritesi güncel.
**24-25 Ağustos Android cihaz turu TEMİZ geldi** (dokunma hedefleri, "← Geri",
Paylaş, tahta açılışı, k-lig/Skor Kartı yükleme — yani #324 ve #325'in
cihazdaki karşılığı doğrulandı). **Madde 8 bundan ETKİLENMEDİ:** oradaki iş
iPad'in popover ankrajı, bu tur Android'de koşuldu.
**Google Play Console hesabı açıldı** (22 Ağustos) — bu, listenin sırasını
değiştirdi: artık omurga aşağıdaki **madde 0 (FAZ B)**, çünkü kişisel
hesaplarda production'a çıkmanın önünde **daha başlamamış 14 günlük bir
tester sayacı** var. Maddeler 1, 2 ve 4 o fazın içinde yaşıyor.

**Durum eki (27 Ağustos 2026):** Sürüm A merge edildi (`f9c3846`, paket
`1.0.0 (403)`) ve cihaz testinde. Dal Sürüm B için yeniden birikmeye
başladı; ayrıntı aşağıdaki "Yalnızca sohbette kalmış üç karar" bölümünde.

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

## Faz planı — kalan işlerin YAYIN sırası (29 Ağustos 2026)

Kullanıcı isteği: *"Tüm işleri fazlandırıp plan yapalım. Uygun gördüğün
maddeleri ona göre birleştirip sırayla yayına alalım."*

Bu bölüm aşağıdaki maddelerin YERİNE geçmez — onların **hangi paketle
çıkacağını** söyler. Madde 0 (FAZ B) omurga olmaya devam ediyor.

**Fazları belirleyen tek kısıt, bir tercih değil bir ölçüm:**

| Değişiklik türü | Bedeli | Ne zaman canlıda |
|---|---|---|
| İstemci (Flutter) | paket + Play incelemesi + cihaz turu | sürüm turu |
| Sunucu (migration / Edge Function) | yok | **anında**, merge'den bağımsız |
| Web (`src/`) | yok | `main`'e merge → Vercel |

Yani maddeleri "konu"ya göre değil **paketlenebilirliğe** göre grupladım.
Sonuç: kalan HER ŞEY **iki sürüm turuna** sığıyor — bildirim işinin yarısı
sunucu tarafında olduğu için sürüm beklemiyor.

### Kalan işlerin tamamı — tek bakışta (2 Eylül 2026'da güncellendi)

⚠ **Asıl bloker kod DEĞİL.** Play production'a başvurmak için kişisel
hesaplarda **12 tester'ın 14 gün kesintisiz kayıtlı** kalması gerekiyor;
sayaç kapalı testle işliyor ve o bitene kadar yayın açılamıyor. Aşağıdaki
her şey o pencerenin içinde ya da yanında duruyor.

| Kova | Ne | Durum |
|---|---|---|
| **Sayaç** | 12 tester × 14 gün | ⏳ işliyor, aksiyon yok · ⚠ karttaki **12**'nin gerçek adet mi şartın tavanı mı olduğu ÖLÇÜLMEDİ (2 Eylül, kullanıcı itirazı — aşağıda) · *Android developer verification* ✅ **BİTTİ** (Console'dan doğrulandı 31 Ağustos: `com.kelimeki.kelimeki` Registered, 3 anahtar, Identity dolu) |
| **Console (elle)** | — | ✅ **KAPANDI** (bu satır 31 Ağustos'a kadar bayat kaldı; ayrıntı aşağıda) |
| **1.0.4'e binecek kod** | Faz 6 istemci yarısı (rozet sıfırlama + sürüm damgası) · Faz 7 (iki çökme) · **+ #10 hata hız sınırı** (1 Eylül'de eklendi) | ✅ **1.0.4 (467) Play'e YÜKLENDİ, incelemede** (1 Eylül 2026) |
| **1.0.5'e binen kod** | Tahta zoom'u (+2 APK turu) · zoom tanıtım balonu · yazı ölçeği (sınıf 3+2) · mesaj kutusu etiketi · **cihaz turu düzeltmeleri (rozet kırpması · alt şerit · çevrimdışı şerit · zoom çerçevesi · filigranlar)** | ✅ **TUR KAPANDI** — `1.0.5 (501) — 4a0a29b` kapalı testte yayında (~15:03) ve üç işin cihaz doğrulaması da alındı (2 Eylül, kullanıcı). Ayrıntı: arşiv → "1.0.5 SÜRÜM TURU" |
| **1.0.6'ya binen kod** | Biten Canlı oyunun haberi (`OYUN BİTTİ`/`TESLİM OLDUN` + `YENİ` rozeti + sekme sayacı) · skor kartında kafa kafaya oran çubuğu · `Tüm Oyunlar` etiketinin tekleşmesi · **oyun geçmişine "Tekrar Oyna" (rövanş)** | ⏳ **`1.0.6 (525) — 711eaaa` kapalı testte YAYINDA** (4 Eylül, Submission 12; inceleme ≤29 dk). Kullanıcı kuralı sağlandı: APK önce cihazda koşuldu (§0-§4'ün koşulabilir maddeleri geçti). **TUR HENÜZ KAPANMADI.** Play imzalı paket 4 Eylül'de cihaza kuruldu ve §7'nin "güncelleme yokken pencere çıkmamalı" dalı geçti. §4.5 (davet linki uygulamayı açıyor) da geçti ve App Links doğrulamasını kanıtladı. Kalanlar: §4.1 (kayıt onayı) + kabul akışının uygulama içi maddeleri — ikisi de **YENİ bir hesap** ister (Ironman ↔ T3 zaten arkadaş, T2 Play'in test hesabı) · §1.4 ("ŞİMDİ DEĞİL") de KAPANDI (4 Eylül, kullanıcı gözlemi) · §7'nin "güncelleme VARKEN" dalı — ancak 1.0.6 kuruluyken 1.0.7 yayınlanınca koşulabilir. Kanonik paket kütüğü: `mobile/docs/surumler.md` |
| **Cihazda denenmemiş** | §3c'nin davete özgü dalları · GA4 DebugView | ⏳ bildirim→tahta DOĞRULANDI (sıcak+soğuk, 31 Ağustos); **1.0.5'in tamamı 2 Eylül'de onaylandı** (zoom turu, çevrimdışı şerit, filigranlar, balon, yazı ölçeği, mesaj etiketi) — kalan iki kalem bu ikisi |
| **Karar verilmiş, yapılmamış** | — | ✅ Kova BOŞ: **#3** hatırlatma, **#8** iPad paylaşımı (3 Eylül cihazda doğrulandı) ve **#16** kart düzeni kapandı; üçü de arşivde |
| **Ertelendi** | #2 zorunlu güncelleme | ✅ **KAPANDI/ARŞİVDE** (2 Eylül 2026, kullanıcı: *"Artık app'de güncelleme çıkıyor, bunu görünce zaten yapar"*). ⚠ Sürüm kapısı DURUYOR ve artık KULLANILABİLİR — acil fren olarak `app_config.mobile_min_supported_version` |
| **Seviyeli YZ** | **#23** Kolay/Normal/Zor + seviyeye göre k-lig puanı — 5 faz (sunucu → motor → web → port → Zor motoru) | ⬜ **Faz 0 ✅ · Faz 1 ✅ (6 Eylül 2026, migration canlıda, sıfır puan değişikliği ölçüldü), Faz 2 sırada**: karar verildi — Normal bugünkü motor, Kolay YZ ~%30, Zor YZ ~%70 (#23.0). Faz 0 ölçtü: **Kolay = N=4** (200 oyun/N; N=3 %36, N=4 %33, N=5 %22 — backlog notu) |
| **İsteğe bağlı** | #5 k-lig grafiği · #9 admin filtre · #14 tembel liste | ⬜ hiçbiri yolu tıkamıyor · **#10 hata hız sınırı ✅** ve **#11 platform filtresi ✅ YAPILDI** (31 Ağustos 2026) |
| **Yapıldı** | #6 taranabilir `/nasil-oynanir/` sayfası | ✅ 31 Ağustos 2026 |
| **Play Store'a girdikten sonra** | **#17 Google ile giriş** — sunucu → web → mobil; migration BLOKER (OAuth bugün `handle_new_user`'da patlar) | ⏳ ERTELENDİ — acelesi yok, çalışan kimlik akışına şimdi dokunulmuyor (2 Eylül, kullanıcı). ⚠ Sayaçla İLİŞKİSİ YOK; o bağ aynı gün koptu, gerekçe #17'de |
| **iOS/APNs** | Apple Developer üyeliğine bloke; iş "APNs anahtarını yükle + Push capability" kadar | 🔒 |

⚠ **"Console (elle)" satırı 31 Ağustos'a kadar BAYAT kaldı** — dört maddesi
de aslında 25-26 Ağustos'ta bitmişti ve bu tablo onları hâlâ "kullanıcıda"
gösteriyordu. Kullanıcı akşam "formları şimdi güncelleyelim" dediğinde
yapılacak iş olmadığı anlaşıldı. Tek tek:

| Satırın dediği | Gerçek |
|---|---|
| Data deletion → "uygulama içi yol VAR" seçimi | **Böyle bir form alanı YOK.** Silme sorusunun cevabı `Evet → kelimeki.com/hesap-silme/` ve öyle kalıyor; Play'in uygulama içi şartı bir form alanı değil, uygulamanın KENDİSİNDE aranan politika şartı — 372'de karşılandı. `marketing/play-store/console-formlari.md` §3.8 bunu 26 Ağustos'ta "ENGEL KALKTI, beyanda değişen bir şey YOK" diye kapatmıştı |
| Kategori (Oyunlar → Kelime) | ✅ Games → Word, 25 Ağustos |
| İletişim e-postası | ✅ `destek@kelimeki.com` |
| Web sitesi | ✅ `https://kelimeki.com` |

**Ders:** bir işin kaydı İKİ yerde durursa (burada özet tablo, orada cevap
kâğıdı) biri kapanırken öteki kapanmıyor. Bu tablo bir İNDEKS — bir kova
kapandığında kaynağı `console-formlari.md`'dir, karar oradan okunur.

### Sonra / bloke

Açık madde KALMADI. **#8** (FAZ A1 Bölüm 6 — Paylaşma, iPad popover)
✅ **KAPANDI** 3 Eylül 2026 — hata bulunup düzeltildi ve Appetize/iPad'de
doğrulandı; arşivde.
**#11** (hata panelinde platform filtresi) ✅ **KAPANDI** 31 Ağustos 2026
— bu satır 2 Eylül'e kadar onu hâlâ bekleyen iş gibi gösteriyordu, oysa
aynı gün yukarıdaki özet tablo ✅ diyordu (kaydın iki yerde durması).
**#12** (sürüm dağılımı kapsamı) ✅ **KAPANDI** 31 Ağustos 2026 — bkz.
arşivde "Faz 6".
**#15 — uygulama öne gelince bildirim panelini temizle** → ✅ **KOD TAMAM**
(31 Ağustos 2026), sıradaki mobil sürümle çıkar. Ayrıntı arşivde: "Faz 6".
**iOS/APNs** Apple Developer üyeliğine takılı; tasarım bilerek FCM üzerinden
yazıldığı için iOS günü gelince kalan iş "APNs anahtarını Firebase'e yükle +
Push capability ekle" — ikinci bir gönderici YAZILMAYACAK.

## Sürüm sıralaması, force update ve davetliler (27 Ağustos 2026)

Bu bölümde artık TEK konu var: açık test penceresinin İŞLETİM bilgisi.
Koda yazılamadığı için buraya yazıldı; oturum kapanınca kaybolmasın.

⚠ Başlıktaki öteki iki konu 2 Eylül 2026'da KAPANDI ve arşive taşındı:
"force update" (#2 — kullanıcı kararı, Play'in kendi güncelleme bildirimi
yeterli) ve "davetliler" (#3 — zaten yürüyen bir alışkanlık). Başlık,
atıflar kırılmasın diye değiştirilmedi.

⚠ **Sürüm kapısı silinmedi ve artık KULLANILABİLİR durumda** (#2 kapansa
bile): `config/version_gate.dart` her açılışta `app_config`teki
`mobile_min_supported_version`ı okuyor, düşükse `UpdateRequiredScreen`e
düşürüyor, ulaşılamazsa FAIL-OPEN. #2'nin engel saydığı iki eksik de
bugün YOK (kod okundu): `appVersion` artık sürümü takip ediyor (`1.0.5`,
parite testiyle zorlanıyor) ve ekranda `market://` + web yedeği var. Yani
acil bir fren gerekirse eşiği yükseltmek YETER.

### Sayaç — nerede okunur, 14. gün ne zaman

⚠ Bu bir MADDE değil, açık pencerenin işletim bilgisi. *"Davetlilere
hatırlatma"* maddesi 2 Eylül 2026'da KAPANDI (kullanıcı: *"Hep ben
hatırlatıyorum zaten, burada madde olarak durmasına gerek yok"*) — arşivde:
`docs/decisions/roadmap-arsiv.md` → *"3. Davetlilere hatırlatma"*. Aşağısı
o maddeyle birlikte kaybolmasın diye burada kaldı.

**Sayacın yeri:** Dashboard → (aşağı kaydır) Production → `Apply for access
to production` kartı. Test menüsünde DEĞİL; track sayfasında da yok
(ölçüldü). **14. gün ~10 Eylül 2026** (sayaç 27/28 Ağustos'ta başladı;
Console'un günü nasıl saydığı ölçülmedi, ±1 gün kabul et ve tarihi kartın
kendi metninden takip et).

**Katılan/indiren sayısı:** Test → Closed testing → (track) → **Testers**
sekmesi — ⚠ oradaki sayı opt-in DEĞİL, **izin listesi**; indirme adedi için
**Statistics**.

**14 gün dolmadan yapılabilecek iki iş** (ikisi de hâlâ açık): karttaki
**`Preview questions`**'dan başvuru sorularını okuyup cevapları hazırlamak,
ve tester'lardan **yazılı geri bildirim** toplamak (başvuru "testi nasıl
yürüttün" diye soruyor).

#### ✅ "12" TAVAN — kapandı (6 Eylül 2026, kullanıcı tespiti)

Kullanıcı, Console'a bakarak kapattı: *"12 kişi Tavan, google daha fazla
olsa bile gerçek sayıyı göstermiyor."* Yani kart `min(gerçek, 12)`
gösteriyor; 2 Eylül'deki sezgisi (*"12'den fazla katılım olduğunu
düşünüyorum"*) doğruymuş.

Eski kayıt iki tezi yan yana tutuyordu ve ayırt edici gözlem olarak
*"sayının 12'nin ÜSTÜNE çıktığının bir kez görülmesi"*ni işaret ediyordu.
**O gözlem hiçbir zaman gerçekleşemezdi** — tavan tam da onu engelliyor.
Ayırt etme yöntemi olarak yanlış seçilmişti; doğru kaynak baştan beri
Console'un kendisiydi ve ona yalnızca kullanıcı bakabiliyor (bu oturumların
Play Console erişimi YOK).

**Pratik sonucu — kartın sayısı bir kapasite ölçüsü DEĞİL:**

| Soru | Kart cevaplıyor mu |
|---|---|
| Şart sağlanıyor mu (≥12)? | ✅ evet, 12 yazıyorsa sağlanıyor |
| Kaç kişi var, payımız ne kadar? | ❌ hayır, 12'de sabitleniyor |
| Biri düşerse eşiğin altına iner miyiz? | ❌ karttan ANLAŞILMAZ |

Son satır önemli: *"biri düşerse sayaç sıfırlanır"* endişesi kartla
yanıtlanamaz, çünkü kart payı gizliyor. Gerçek katılım için **Test →
Closed testing → (track) → Testers** (izin listesi) ve **Statistics**
(indirme) sekmelerine bakılmalı — ikisi de yukarıda tarif edildi.

Kaynak kayıt: `marketing/play-store/console-formlari.md` §7.

## Sıradaki sürüme binecekler — `main`'de var, MAĞAZADA yok

**Kapalı testteki paket:** 1.0.7 (545) = commit `78383eb` (#461),
6 Eylül 2026'da yayınlandı.

**O paketten beri porta dokunan işler:** _(şu an YOK — liste boş)_

`main` ile mağazadaki paket bilerek ayrışabilir; bu bölüm o farkı görünür
tutuyor, çünkü fark tam da unutulmaya müsait yerde duruyor — `main` yeşil,
web canlı, CI derlemesi hazır, ama Play'e giden hiçbir otomatik yol YOK
(gönderim elle).

⚠ **Listeye GÜVENME, komutu koş.** Bu tablo iki kez eksik yakalandı: bir kez
bölümü yazan PR kendi diff'ini saymamıştı (4 Eylül), bir kez de porta dokunan
iki commit hiç eklenmemişti (5 Eylül — `#452` ve `#457`). İkincisinin bedeli
ölçüldü: eksik liste yüzünden sürüm bir gün gecikti, üstelik eksiklerden biri
gerçek bir hata düzeltmesiydi. Refleks:

```
git log --oneline <mağazadaki-paketin-commiti>..origin/main -- mobile/app mobile/kelimeki_core
```

⚠ **Kendi PR'ını da say** — kapanan işi arşive taşırken tabloyu da güncelle.

⚠ **Play Console hakkında bir şey yazmadan ÖNCE SOR.** Bu oturumların Play
Console erişimi YOK. 6 Eylül 2026'da iki yanlış hüküm kuruldu (uydurma bir
"14 gün sayacı sıfırlanır mı" gönderim kapısı ve "12 tavan mı" sorusu için
gerçekleşmesi imkânsız bir ayırt etme yöntemi). Kayıt:
`docs/decisions/roadmap-arsiv.md` → "1.0.7 sürüm turu".

**Test penceresi:** 6 Eylül itibarıyla **11. gün**, 14. gün ≈ 10 Eylül.

**Kalan günler için kullanıcının niyeti (KARAR DEĞİL, tartışma açık):**
seviyeli YZ oyununu kalan günlere koymak. Ajanın çekincesi: madde
`docs/decisions/product-backlog.md`'de duruyor ve dördü de oradan çıkıyor —
(1) zorluk algoritmasının kendisi kullanıcı kararıyla BİLEREK ertelenmiş
(*"Zorluk algoritmasını yaptığımız zaman değerlendiririz"*), (2) migration
ŞART (puan `leaderboard`/`player_stats` view'larında hesaplandığından
`games`e seviye alanı gerekiyor), (3) YZ motorun ÜÇ kopyasında yaşıyor
(`src/utils/ai.ts` · `_game/ai.ts` · `kelimeki_core/find_move.dart`) +
golden vector'lar, (4) kaydın kendi uyarısı: yerel oyun skorları k-lig'e
aktığından YZ'nin gücü değişince lider tablosunda eski/yeni dönem karışır ve
bu *"bir sürüm sınırına denk getirilmeli"*. Ajanın önerisi: üretime çıkıştan
sonraki İLK özellik yapmak, kalan günleri başvuruyu bekleyen iki işe ayırmak
(`Preview questions` + tester'lardan YAZILI geri bildirim). **Kullanıcı bu
öneriye henüz yanıt vermedi.**

**Göndermeden önce, sırayla:**

1. **Sürüm adını elle artır — İKİ dosya birden:** `mobile/app/pubspec.yaml`
   (`version:`) **ve** `mobile/app/lib/src/config/env.dart` (`appVersion`).
   İkisi parite testiyle zorunlu tutuluyor, biri unutulursa CI düşer.
   Derleme numarası (`versionCode`) ELLE VERİLMEZ — CI `--build-number` ile
   `github.run_number`ı basıyor, yani her koşu Play için yeni ve artan.
2. **Cihaz turu:** `mobile/TESTING.md` bölüm 17'deki away-return maddeleri —
   özellikle ÜÇ NEGATİF EŞ (kısa alt-tab sekmeyi değiştirmemeli, bekleyen
   iş yokken dönüş yerinden etmemeli, açık oyun ekranında dönüş sekme
   değiştirmemeli). Asıl risk pozitif dalda değil bunlarda: eşik yanlış
   tarafa düşerse kullanıcı bilerek oturduğu sekmeden koparılır.
   Ayrıca #443'ün yüzeyi: **Yardım → Hızlı Başlangıç** kartının 🏁 maddesi.
   Metin web'le BİREBİR aynı olmalı (`HelpModal.tsx` ↔ `help_modal.dart`);
   `help_modal_test.dart` cümlenin tamamını değil yalnızca "Yüksek puanı
   olan kazanır" ibaresini görüyor, yani sapmayı CI yakalamaz.
   Bir de #447'nin yüzeyi: **başkasının skor kartındaki** kafa kafaya
   çubuğu — yüzdeler ve "N oyun" bara komşu mu, iki avatar hâlâ barla
   aynı hizada mı, ve "TÜM OYUNLAR" butonu barla aynı yükseklikte mi
   (satır artık `items-center` ↔ `CrossAxisAlignment.center`; hiza,
   bloğun dikey SİMETRİSİNDEN geliyor — blok simetrisi bozulursa hiza da
   bozulur).
3. **Test ettiğin paketin TAZE olduğunu doğrula:** Setup'taki
   `Derleme <sha>` satırı `main`'in başıyla aynı olmalı. Appetize'da
   Android ve iOS AYRI zamanlarda tazeleniyor (bkz.
   `mobile/docs/test-ortamlari.md`), yani iOS'ta eski derlemeyi test etmek
   kolay bir hata.

## Güvenlik geçişi — açık kalan maddeler (5 Eylül 2026)

Play Store öncesi kapsamlı incelemenin ilk geçişi. **Kapatılan madde
(oturumsuz kimlik sızıntısı) burada DEĞİL** — uygulandı ve
`docs/decisions/supabase-ops.md` → "Play Store öncesi güvenlik geçişi"ne
yazıldı. Aşağıdakiler hâlâ açık.

**İncelemenin dört geçişi de BİTTİ** (kullanıcı isteği,
5 Eylül 2026: *"Play Store öncesi kapsamlı bir code review... Buglar,
temizlik, güvenlik, performans"*). Sıra ve gerekçe:

| # | Geçiş | Durum |
|---|---|---|
| 1 | **Güvenlik** — RLS, grant'ler, RPC yetkileri, Edge Function kapıları | ✅ **BİTTİ** (5 Eylül 2026) |
| 2 | **Hata avı** — reducer/validator değişmezleri, web↔port paritesi, eşzamanlı yazım yarışları, hook sırası | ✅ **BİTTİ** (5 Eylül 2026) |
| 3 | **Performans** — bundle, sıcak sorguların index kapsamı (advisor'ın kendi listesi var), liste render'ı, N+1 RPC | ✅ **BİTTİ** (5 Eylül 2026) |
| 4 | **Temizlik** — ölü kod, erişilemez şubeler, kullanılmayan bağımlılıklar, bayat doküman atıfları | ✅ **BİTTİ** (5 Eylül 2026) |

⚠ **Her geçiş KENDİ oturumunda koşulmalı.** Ölçüldü: web `src/` 38.6K +
port 68.3K + Edge Function 4.1K satır, yani 111 bin satır uygulama kodu tek
bağlam penceresine sığmıyor. Tek turda "hepsini tara" denirse — hangi model
olursa olsun — yüzeysel bir liste ve yanlış pozitif çıkar.

⚠ **Model: Opus 5, efor `high`–`xhigh`.** Fable'a verme: `ROADMAP`in kendi
ölçütü Fable'ı "geri dönüşü OLMAYAN" iş için ayırıyor, inceleme ise rapor
üretir — yanlışsa bedeli bir turu yeniden koşmak. Fable'ın hak ettiği yer
bulguların DÜZELTMESİ: veri kaskadına ya da web+port+DB'yi birlikte
değiştirmeye çıkan bir düzeltme o sınıfa girer.

⚠ **Güvenlik geçişinin en büyük dersi:** dört bulgunun biri ölçünce BÜYÜDÜ
(anon sızıntısı), üçü ölçünce KÜÇÜLDÜ (#19/#20 kabul edildi, #21
sömürülebilir değildi). İlk rapordaki öncelik sırasını ölçümler tersine
çevirdi. Sonraki geçişlerde de bulguyu ciddiyetiyle birlikte YAZMADAN önce
ölç.

Zeminin sağlam olduğunu da kayda geçir, çünkü bir sonraki tur bunu yeniden
ölçmesin: 28 tablonun 28'inde RLS açık, 71 `SECURITY DEFINER` fonksiyonun
71'inde `search_path` sabitlenmiş, yazma politikalarında istisnasız
`auth.uid() = user_id` var, Edge Function `verify_jwt` envanteri kök
`CLAUDE.md`'deki 8'lik listeyle birebir tutuyor, repoda gömülü sır yok.
`notify-turn-timeout-surrender` / `notify-welcome` / `notify-your-turn`
herkese açık POST hedefi olmalarına rağmen doğru yazılmış (atomik iddia,
taze pencere, hedefi gövdeden değil canlı durumdan alma) — bulgu değiller.

### 18. `submit_move` puana değil yalnızca taşa hakem — **GÖLGE FAZINDA**

**Durum (5 Eylül 2026):** ayna yazıldı, canlıya uygulandı, gölge fazı AÇIK.
Karar hâlâ istemcinin değerleriyle veriliyor; sunucu paralelde kendi hesabını
yapıp sapmayı `move_shadow_diffs`e yazıyor. **Zorlama fazına ancak o tablo
gerçek oyunlarda boş kaldıktan sonra geçilecek.**

⚠ **"Tablo boş" TEK BAŞINA KANIT DEĞİL — kapı payda olmadan okunamıyor
(5 Eylül 2026 akşamı ölçüldü).** Boş bir tablonun iki zıt anlamı var: (a)
sunucu istemciyle birebir uyuştu, (b) o koddan hiç hamle geçmedi ya da sensör
öldü. Gölge fazı canlıya alındıktan ~1 saat sonra gerçek durum (b)'ye çok
yakındı: **0 sapma, ama payda yalnızca 10 hamle** (7 oyun, 6 oyuncu) — ve
ROADMAP'in "cihazda ayrıca sına" dediği riskli yolların TAMAMI sıfır
kapsamlıydı (0 vergili hamle, 0 joker bitişi, 0 bingo). Kapı nominal olarak
açıktı, kanıt olarak boştu.

İki şey eklendi:
1. **Sensörün canlı olduğu kanıtlandı** (negatif eş): `_km_shadow_check`e
   kasten yanlış bir istemci base'i verildi → `base_points` sapması YAZILDI;
   geçerli bir hamlede ise sıfır satır. Yani boşluk sensör ölümünden değil.
2. **`move_shadow_coverage` tablosu** (payda) — her gölge kontrolü bir gün
   satırını artırır ve riskli yolları AYRI sayar: `hamle`, `cok_oyunculu`,
   `vergi`, `joker`, `teslim_var`, `blokta_rakip` (sonuncusu 24 Ağustos
   "iletken hücre" kuralının ÖN KOŞULU — kuralın yükte olduğunu kanıtlamaz,
   ama sıfırsa hiç denenmediğini kesinleştirir). Sayaç yapısal erken-return'den
   ÖNCE ve KENDİ exception bloğunda artıyor; ikisi de
   `verify-sql-engine-parity`de kilitli ve negatif eşle sınandı.

**Madde ölçünce BÜYÜDÜ.** İlk yazımda üç eksik sayılıyordu (sözlük yok, harf
puanı yeniden hesaplanmıyor, tavan yok). Fonksiyonun tamamı okununca iki şey
daha çıktı:

- **Yerleştirme MEŞRUİYETİ de denetlenmiyordu.** Bitişiklik, süreklilik,
  "aynı satır/sütun", ilk hamlede ev karesi, kelime oluşması — hiçbiri yoktu.
  Katılımcı 7 taşı tahtaya dağınık serpebiliyordu.
- **`p_lost_shares` bir TRANSFER kanalıydı:** tutar yalnızca `p_base_points`i
  aşmamakla sınırlı, o da sınırsız — yani suç ortağının puanı da istendiği
  kadar yükseltilebiliyordu (iki hesaplı danışıklı senaryo).

**Sömürülmüş mü? Hayır** — 2.641 `play` hamlesi tarandı: max 56 puan, p99 38.

**Çözüm SQL'de, Edge Function'da DEĞİL.** Motorun Deno kopyası zaten vardı
(`_game/`, `play-ai-turn` kullanıyor) ama ölçüm tersini söyledi: Edge yolu her
hamleye bir ağ adımı ekler ve her soğuk isolate'te 63.905 kelimeyi yükler
(~1 MB) — bu maliyet YZ turunda kabul edilmişti, insan hamlesinin kritik
yoluna girmemeli. SQL'de sözlük zaten `public.words` (`word` PRIMARY KEY): bir
hamlenin oluşturabileceği EN FAZLA 8 kelimenin tamamı **1,1 ms**. Üstelik RPC
imzası değişmediğinden **kurulu mobil sürümler kırılmıyor**, EXECUTE revoke
penceresi beklemek gerekmiyor.

**Maliyet ölçüldü:** +7,5-8,6 ms/hamle (bölge hesabı %56'sı). `submit_move`
bugün zaten ortalama 23-42 ms; kullanıcının hissettiği süre ağ gidiş-dönüşü
olduğundan fark %5'in altında.

**Parite kanıtı** (kör test değil, negatif eşleriyle): 2.641 gerçek üretim
hamlesi boş tahtadan yeniden oynatıldı — skorda 0 sapma, yapısal+sözlükte 0
yanlış red. Vergide ham 10 sapmanın 7'si harness'ın kendi varsayımı (teslim
bayrağını oyun sonu snapshot'ından okuyordum), 3'ü 24 Ağustos "iletken hücre"
kural değişikliğinden önceki hamleler — üçünde de ESKİ kural kayıtlı değeri
birebir üretiyor. Açıklanamayan sapma: **0**. Ayrıntı:
`docs/decisions/roadmap-arsiv.md` → "Temizlik geçişi"nin ardındaki bölüm.

**AÇIK KALAN İŞ — zorlama fazı:**
1. `move_shadow_diffs`i **`move_shadow_coverage` ile BİRLİKTE** oku. Boş
   değilse zorlamaya GEÇME, önce sapmayı çöz (tablo `girdi` sütununda
   board+placed+players var, vaka tekrar üretilir). Boşsa da paydaya bak:
   ```sql
   select * from public.move_shadow_coverage order by gun desc;
   ```
   **Sayısal kapı (öneri, kullanıcı onayına tabi):** `hamle` birkaç yüze
   ulaşmadan ve `vergi` · `joker` · `blokta_rakip` sütunlarının her biri
   sıfırdan çıkmadan zorlamaya geçme — bunlar tam da 2. maddedeki riskli
   yollar, ve az geçtikleri için gerçek trafikte kendiliğinden birikmeleri
   zaman alır. `cok_oyunculu` ile `teslim_var` gerçek trafikte hiç
   birikmeyebilir; onlar için 2. maddedeki cihaz turu tek kanıt.
2. Cihazda dört yolu ayrıca sına (mevcut veride az geçiyor): 4 kişilik oyunda
   bölge etkileşimi, joker bitiş bonusu, oyun ortasında teslim, ve iletken
   hücre kuralının kendisi (bu dal golden vector'lara ilk girdiğinde sıfır
   kapsama vermişti — en riskli yer orası).
3. Zorlama migration'ı: `submit_move` `p_base_points`/`p_words`/
   `p_word_scores`/`p_lost_shares`i YOK SAYIP `_km_*` çıktısını kullansın,
   yapısal/sözlük hatasında `raise exception` etsin.
4. ⚠ Zorlamaya geçince istemci ile sunucu arasındaki HER kural farkı
   kullanıcıya hata olarak görünür. `verify-sql-engine-parity` sabitleri ve
   hata metinlerini kilitliyor ama davranışı kilitleyemiyor — o yüzden 1. adım
   atlanamaz.

### 19. `anon` için sınırsız telemetri yazımı — **ÖLÇÜLDÜ: KABUL EDİLDİ**

`client_errors`, `device_visits`, `guest_visits`, `game_starts` — dördünde
de INSERT politikası `with_check: true`, yani oturumsuz sınırsız satır
eklenebiliyor. **İlk yazımda "feedback_rate_limit desenini kopyala" deniyordu;
o tavsiye ÖLÇÜMDEN ÖNCEYDİ ve GERİ ALINDI.** Ölçünce üç şey çıktı:

**1. İddia edilen zarar büyük ölçüde YOK — tüketici zaten dayanıklı.**
Dokuz admin RPC'sinin sekizi `count(distinct ...)` kullanıyor.
`admin_source_funnel`ın "Ziyaretçi" adımı YALNIZCA
`count(distinct gv.anon_id)`; `game_starts`/`game_finishes` adımları ham `n`
ile `uniq`i YAN YANA döndürüyor (ham sayı meşru olarak ham: "toplam
başlangıç"). `admin_activation_stats` bu tabloların hiçbirine dokunmuyor.
Yani bir sel `uniq` sütunlarını oynatamaz.

**2. Bugün kötüye kullanım yok ve hacim küçük** (5 Eylül 2026):

| Tablo | Toplam | Farklı cihaz | Son 7 gün |
|---|---|---|---|
| `client_errors` | 40 | 27 | 12 |
| `device_visits` | 877 | 731 | 184 |
| `guest_visits` | 2.316 | 2.032 | 128 |
| `game_starts` | 931 | 181 | 346 |

**3. IP'ye anahtarlanan bir limitin İKİ yan etkisi, faydasından büyük:**
- **CGNAT.** Türk mobil operatörleri operatör düzeyinde NAT kullanıyor;
  gerçek kullanıcılar tek çıkış IP'sini paylaşıyor. Ziyaret/oyun başına
  yazan bir tabloda IP limiti gerçek satırları SESSİZCE düşürür (istemci
  hatayı yutuyor — ölçüldü, iki tarafta da fire-and-forget) ve huni EKSİK
  sayar. Bu, önlemeye çalıştığımız zararın aynı sınıfı, ters yönü.
- **`client_errors`'ta olayı gizler.** Tek cihazdan gelen hata seli tam da
  görmek istediğin şeydir; limit gerçek bir çökme olayında kanıtı kısar.
  Üstelik #10 ile istemci tarafında zaten hız sınırı var.

**Karar: bugün bir şey yapma.** Yeniden açılma tetikleyicisi: telemetri
tablolarından birinde `count(*)` ile `count(distinct anon_id)` arasında
açıklanamayan bir uçurum görülmesi, ya da satır sayısının maliyet yaratacak
mertebeye çıkması.

⚠ Limit ileride gerekirse **IP'ye DEĞİL `anon_id`'ye anahtarla** — CGNAT
komşularını vurmaz. Saldırgan `anon_id`yi de döndürebilir (yani naif seli
durdurur, kararlıyı durdurmaz), ama dürüst kullanıcıya maliyeti sıfırdır.

### 20. `CRON_SECRET` fail-open — **ÖLÇÜLDÜ: DÜŞÜK, kabul edilebilir**

**Durum (5 Eylül 2026): `CRON_SECRET` Dashboard'da TANIMLI DEĞİL** (kullanıcı
ekran görüntüsüyle doğruladı — Custom secrets'ta yalnızca `BREVO_API_KEY` ve
`FCM_SERVICE_ACCOUNT` var). Yani `if (CRON_SECRET && ...)` kapısı fiilen
açık ve **üç** fonksiyon (beş değil — ilk sayım yanlıştı) internetten
çağrılabiliyor: `notify-deadline-warnings`,
`notify-friend-request-reminders`, `sweep-unconfirmed-accounts`.

**Ama etkisi ölçüldü ve düşük** — üçünde de atomik "iddia" koruması var
(`.is(alan, null)` filtreli UPDATE), yani `notify-turn-timeout-surrender`
ile aynı desen:

| Fonksiyon | Dışarıdan tekrar çağrılırsa |
|---|---|
| `notify-deadline-warnings` | `deadline_warning_sent_at` → satır başına tek mail |
| `notify-friend-request-reminders` | `reminder_sent_at` → aynısı |
| `sweep-unconfirmed-accounts` | Yaş ölçütünü kendi uyguluyor → erken silme YOK |

Saldırgan zaten gönderilmeyecek tek bir mail bile göndertemiyor; kalan etki
yalnızca boşa çağrı maliyeti. **Bu yüzden acil değil.**

⚠ **Düzeltmenin bedeli faydasından büyük olabilir — üç parça aynı anda
değişmek zorunda.** Ölçüldü: `cron.job`taki üç komut da **hiçbir
`Authorization` başlığı göndermiyor** (`headers` yalnızca `Content-Type`).
Yani secret'ı tek başına tanımlamak üç özelliği birden 401'e düşürür ve
arıza SESSİZ olur (mailler durur, hata veren bir yüzey yok). Sıra şu
olmalı: secret + cron komutları + kodun fail-closed'a çevrilmesi, hepsi
tek turda.

**İki seçenek:**

- **(a) Vault ile, Dashboard adımı OLMADAN:** sır `supabase_vault`'ta
  (0.3.1 kurulu), cron komutu onu okuyup `Authorization` başlığına koyar,
  Edge Function beklenen değeri kendi `service_role` istemcisiyle DB'den
  okur. Depoda ve sohbette sır geçmez, tamamen ajandan doğrulanabilir.
  Bedeli: çağrı başına bir DB okuması (15 dk/saatlik/günlük iş için
  önemsiz) ve koddaki `Deno.env.get('CRON_SECRET')` deseninden sapma.
- **(b) Kabul et ve YAZ:** bugünkü fiili durum bu; ölçüm yukarıda. Bu
  seçilirse koddaki `if (CRON_SECRET && ...)` satırlarına "secret bilerek
  tanımlı değil, koruma iddia sütunlarından geliyor" notu düşülmeli —
  aksi halde bir sonraki okuyan onu çalışan bir kapı sanır.

⚠ **`inbound-email` bu maddeye DAHİL DEĞİL.** O fail-closed yazılmış
(`INBOUND_EMAIL_SECRET` yoksa 503) ve sırrının tanımsız olması BİLİNÇLİ:
Brevo Inbound webhook'u ücretli plana bloke, bkz.
`docs/decisions/support-email.md` → "GELEN ZİNCİRİ DURDURULDU". Boş
`support_inbox` (0 satır) beklenen durum, arıza değil.

### 21. Advisor gürültüsü + Auth ayarları — **KISMEN YAPILDI**

**✅ Trigger fonksiyonlarının REST erişimi KAPATILDI** (5 Eylül 2026,
migration `20260905055111_revoke_trigger_function_execute`, canlıya
uygulandı). Dört fonksiyon (`trg_award_league_rewards`,
`handle_friend_request_insert`, `keep_signup_utm_source`,
`_game_finishes_strip_anon_id`) `anon`+`authenticated`e açıktı; ötekiler
zaten yalnızca `service_role`'du, yani sekizin dördü kuruluştaki örtük
grant'i temizlemeyi atlamıştı. Sonra sondalandı: sekiz trigger
fonksiyonunun sekizinde de `anon`/`authenticated` kapalı, `service_role`
açık, her biri bir trigger'a bağlı. Advisor'ın dört uyarısı kapandı.

⚠ Sömürülebilir oldukları GÖSTERİLMEDİ (Postgres trigger fonksiyonunun
doğrudan çağrılmasını reddeder); bu derinlemesine savunmaydı. Trigger'ların
bozulmayacağı ise ölçüldü: aynı işlem `feedback_rate_limit_check` için
22 Temmuz 2026'da yapılmış ve o tarihten sonra `feedback`e 18 satır girmiş
— her biri o BEFORE INSERT trigger'ından geçerek. **EXECUTE izni
`create trigger` anında kontrol edilir, trigger ateşlenirken değil.**

**⬜ Kalan iki kalem — ikisi de Dashboard, kod işi değil:**

- **Authentication → OTP süresi uzun** ve **sızmış-parola koruması kapalı**
  (advisor WARN). İkisi de tek tık.
- **`pg_net` public şemada** (advisor WARN). ⚠ **YAPILMASI ÖNERİLMİYOR:**
  şema taşımak çalışan cron zincirine (`net.http_post` çağıran üç iş)
  dokunur ve kazancı bir uyarı satırını silmekten ibaret. Advisor'ın
  kırmızısını temizlemek için çalışan bir zinciri riske atma.

### 22. `feedback` hız sınırı XFF ile atlanabilir — **AÇIK, ölçülmedi**

#19'u incelerken çıktı ve ondan bağımsız: bu, CANLIDA çalışan bir kontrol.
`feedback_rate_limit_check` kimliği şöyle alıyor:

```sql
split_part(current_setting('request.headers')::json ->> 'x-forwarded-for', ',', 1)
```

Yani `X-Forwarded-For`un **en soldaki** değeri. Vekiller gerçek IP'yi zincirin
**sağına ekler**; en soldaki değer istemcinin kendi gönderdiğidir. Doğruysa
sonuç ters: saldırgan her istekte sahte bir ilk XFF yazıp limiti tamamen
atlar, kendi XFF'i olmayan gerçek kullanıcı ise gerçek IP'siyle sayılıp
limite takılır — yani kontrol yalnızca DÜRÜST trafiği kısıtlıyor olur.

⚠ **ÖLÇÜLMEDİ.** Bu ortam `supabase.co`ya POST atamıyor (ajan vekili
engelliyor), yani Supabase ağ geçidinin XFF'i nasıl birleştirdiği
doğrulanamadı. **İlk iş bunu ölçmek:** `inbound-email` ya da herhangi bir
uçtan `request.headers`ı bir yere yazdırıp, kendi XFF'ini gönderen bir
istekle göndermeyen bir isteğin ne ürettiğini karşılaştır. Ağ geçidi
istemcinin XFF'ini TAMAMEN yok sayıyorsa bulgu düşer.

Doğrulanırsa düzeltme: en soldaki değil **sağdan** sayılan (vekil sayısı
kadar içeriden) değeri al, ya da Supabase'in kendi güvenilir istemci-IP
başlığını kullan. `feedback` limiti dışında bu deseni kopyalayan başka yer
YOK (arandı) — yani düzeltme tek noktada.

## İncelemenin KAPANMIŞ geçişleri → arşivde

2. geçişin (**hata avı**), 3. geçişin (**performans**) ve 4. geçişin
(**temizlik**) tam anlatıları — bulgular, ölçümler, "zemin sağlam"
listeleri ve dersleri — `docs/decisions/roadmap-arsiv.md`'ye taşındı;
başlıklar ("Hata avı geçişi — KAPANDI", "Performans geçişi — KAPANDI",
"Temizlik geçişi — KAPANDI") değiştirilmedi. Yukarıdaki geçiş tablosu canlı
indeks olarak burada kaldı. **Dört geçiş de kapandı**; incelemeden açık
kalan tek şey güvenlik geçişinin yukarıda duran maddeleri (18-21).

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
| 0.A4 | ✅ **BİTTİ** (23 Ağu 2026) | `marketing/play-store/` | İkon (512) + öne çıkan görsel (1024×500) + başlık/kısa/tam açıklama üretildi (`npm run generate-play-assets`). Telefon ekran görüntüleri **gerçek cihazdan alındı** (7 kare, 1080×2400) ve Play'in 2:1 oran tavanına sokmak için **1080×2072'ye kırpıldı**; dosyalar kullanıcıda. Kırpmanın neden zorunlu olduğu `marketing/play-store/metin.md` → "Teknik gereksinim" |
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

**ÖLÇÜLDÜ (24 Ağustos 2026) — ikisi de temiz, aksiyon GEREKMİYOR.** Kaynağa
değil YAYINLANMIŞ pakete bakıldı: `mobile-latest`teki `kelimeki.apk`
(sha `18689eb`) indirilip derlenmiş `AndroidManifest.xml`i çözüldü.

| | Ölçülen | Sonuç |
|---|---|---|
| `minSdkVersion` | **24** (Android 7.0) | — |
| `targetSdkVersion` | **36** | Android'in en yeni API seviyesi; Play'in asgarisinin ALTINDA olması mümkün değil → **pinlemeye gerek yok** |
| İzinler | **3 adet** (aşağı) — Play'in `.aab`'de gösterdiği **4** (bkz. not) | Data safety beyanı etkilenmiyor |

İzinlerin tamamı: `INTERNET` (Parça 131 düzeltmesi — pakette olduğu böylece
ikinci bir yoldan da doğrulandı), `ACCESS_NETWORK_STATE` (connectivity_plus)
ve `com.kelimeki.kelimeki.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
(AndroidX'in kendi ürettiği iç izin — kullanıcıya görünmez, beyan edilmez).

**DÜZELTME (25 Ağustos 2026):** yukarıdaki "3 izin" YAYINLANMIŞ `.apk`'dan
ölçülmüştü; Play Console'un paket ayrıntısı `.aab` için **4** gösteriyor.
Fark `com.android.vending.CHECK_LICENSE` — beyanı değiştirmiyor (çalışma
zamanı izni değil, veri toplamıyor). Ders: `.apk` ölçümü `.aab`'yi
kanıtlamıyor, Play bundle'ı işlerken manifeste ekleme yapabiliyor. Ayrıntı:
`marketing/play-store/console-formlari.md` § 6.

**`image_picker` HİÇBİR izin eklememiş** — bu dosyanın beklediği risk
gerçekleşmedi. Modern Android'de Photo Picker/SAF üzerinden çalıştığı için
depolama/medya izni istemiyor. Yani Data safety formunda medya erişimi
beyan edilmeyecek.

**0.A bölümünün TAMAMI bitti.** Sıradaki: ilk `.aab` yüklemesi → kapalı test
kanalı → 12 tester → 14 günlük sayaç başlar.

**Console'a girilecek her formun cevabı yazıldı (24 Ağustos 2026):**
`marketing/play-store/console-formlari.md` — adım sırası, Data safety veri
türü eşlemesi (her satırın kodda karşılığıyla), IARC anketi, App access test
hesabı, kapalı test kanalı ve tester metni. Vitrin METİNLERİ hâlâ
`metin.md`'de.

**ÖLÇÜLDÜ (24 Ağustos 2026) — `.aab` indirilebilir DEĞİLDİ, düzeltildi:**
0.A2 paketi yalnızca `actions/upload-artifact` ile bırakıyordu; artefakt
bağlantısı oturum istiyor ve dosyayı ZIP'liyor — yani iPad'den yükleyecek
kişi için `.apk`nın 7 Ağustos'ta çözülen probleminin aynısı hâlâ açıktı
(`build-and-distribution-log.md` → Appetize). `mobile-build.yml`'in release
adımı artık `kelimeki.aab`'yi de `mobile-latest`e koyuyor:
`https://github.com/alpcapa/kelimeki/releases/download/mobile-latest/kelimeki.aab`.
Artefakt DURUYOR. **DOĞRULANDI (25 Ağustos 2026, koşu 349, sha `5eddf3d`):**
dosya release'te, 60.929.323 bayt. Kanıt PR'da alınamazdı — release adımı
PR'da bilerek atlanıyor (workflow başlığındaki "YAYINLAMA" notu) — bu yüzden
merge sonrası ilk `main` koşusunda okundu.
**Play'e YÜKLENEN: 372** (26 Ağustos 2026 sabahı, kapalı test — Release name
`372 (1.0.0)`). Uygulama içi hesap silmeyi İÇEREN ilk paket bu.
Console'un paket ayrıntısından ölçüldü: `targetSdk` **36**, `minSdk` **24+**,
**4 izin**, ABI 3, ekran düzeni 4, gerekli özellik 2 — yani 349'un satırıyla
her sütunda aynı.

**Yüklenmeye hazır EN YENİ paket: 374** (koşu 374, sha `42a1f67`, `.aab`
26 Ağustos 05:42'de `mobile-latest`e yüklendi — 60.972.640 bayt). 372'den
tek farkı silme onayındaki uyarı cümlesinin kırmızı/kalın olması (#341) —
**kozmetik**, bu yüzden 372 için ayrı bir yükleme turu harcanmadı. Bir
sonraki mobil sürüm bu tabandan gider.

**370 neden atlandı:** aynı akşam Kullanım Koşulları §2'ye hesabı kendin
silme cümlesi eklendi (#338) ve hukuki metnin tarihi portu da zorunlu kıldı
(`legal_text_test.dart`) — yani 370 daha yüklenmeden bayatladı.
**Kalıcı ders: hukuki metne dokunmak her zaman bir paket turudur**, "tek
cümle" diye ucuz sayma. **İkinci ders — koşu numarası ardışık DEĞİL:** sayaç
PR koşularında da ilerliyor, 371'i #338'in kendi koşusu yedi. Bir sonraki
paketin numarasını önceden yazma, merge sonrası `main` koşusundan OKU.

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
  **YAPILDI (25 Ağustos 2026):** dosya `public/.well-known/assetlinks.json`
  olarak yazıldı, içinde Play'in ürettiği parmak izi var (`2B:7D:26:11…`) —
  upload anahtarı (`B6:CD:FB:A9…`) DEĞİL. ⚠ Değer, App signing sayfasının
  anahtar TABLOSUNDAN değil, aynı sayfanın **"Digital Asset Links JSON"**
  panelinden okunur; ilk tur tablodan okunup yanlış parmak iziyle canlıya
  çıktı ve aynı gün düzeltildi. Ayrıntı ve ölçümler:
  `marketing/play-store/console-formlari.md` → §6.6.

**Tuzaklar — 0.A2/0.A3:**
- `targetSdk` hâlâ `flutter.targetSdkVersion`'dan geliyor
  (`build.gradle.kts:47`), yani pinli DEĞİL — ama ölçüldüğünde **36** çıktı
  (yukarı), o yüzden bugün pinlemeye gerek yok. Flutter kanalı geri giderse
  bu sessizce düşebilir; sürüm yükseltmelerinde yeniden ölç.
- `image_picker`'ın izin eklemediği **ölçüldü** (yukarı) — paket yalnızca 3
  izin taşıyor ve hiçbiri medya/depolama değil.
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

**DURUM (25 Ağustos 2026):** Console'daki her form dolduruldu, kapalı test
sürümü incelemeye gönderildi ve **YAYINLANDI** — Submission 1 durumu
`Published`. Adım adım ne girildiği ve neden:
`marketing/play-store/console-formlari.md` § 6.5.
26 Ağustos'ta uygulama içi hesap silmeyi içeren **372** yüklendi.

**Kriter HENÜZ karşılanmadı:** Dashboard **`0 testers currently opted-in`**
diyor — listede olmak opt-in sayılmıyor, kişinin linke tıklayıp testi kabul
etmesi gerekiyor ve bugüne kadar kimseye link gönderilmemişti.

**26 Ağustos 09:03'te opt-in linkleri Console'da BELİRDİ** (Join on Android
+ Join on the web), liste 11 kişiyken. Bir gün önce yoklardı; kapısının ne
olduğu ölçülmedi (bkz. `console-formlari.md` §6.5 — o tabloda yalnızca
GÖRÜLEN kaydedildi, sebep uydurulmadı).

**26 Ağustos (öğleden sonra) — liste 11 → 54 KİŞİ.** Kullanıcı bildirdi;
Console'dan okunan sayı. §7'nin "15-20 kişi topla, biri çıkarsa sayaç
kırılır" tavsiyesinin çok üstünde, yani yedek payı bol.

⚠ **Listede olmak ≠ opt-in — ve aradaki fark ÖLÇÜLDÜ (26 Ağustos 2026):**
liste **54 kişi**, gerçekten opt-in olan **10 kişi**. Yani davetlilerin
%80'i linke tıklamamış. Sayaç için kişilerin linke tıklayıp testi KABUL
etmesi gerekiyor; `testers currently opted-in` bunu sayıyor.

**Eşik 12 ise 2 kişi eksik.** Buradan çıkan iki pratik sonuç:
- Yapılacak iş yeni adres toplamak DEĞİL (54 zaten fazlasıyla yeter),
  mevcut davetlilere *"linke tıklayıp 'Testçi ol' demen gerekiyor"* diye
  hatırlatmak.
- **Geliştiricinin kendi cihazından uygulamayı kaldırması artık RİSKLİ:**
  10 sayısı eşiğin altındayken tek bir düşüş oransal olarak büyük. Native
  `.apk` ile performans testi yapılacaksa opt-in OLMAYAN bir cihaz
  kullanılmalı. (Kaldırmanın opt-in'i gerçekten düşürüp düşürmediği
  ÖLÇÜLMEDİ — Play davranışı çıkarımla yazılmıyor.)

⚠ **Ve bugün ölçülen asıl darboğaz opt-in değil:** davetliler uygulamayı
kurup açsalar bile **tanıtım ekranında takılıyorlardı** (kaydırmayı
anlamıyorlar, atlama da yok → çıkmaz). 3 günde yalnızca 2 kayıt olmasının
sebebi buydu. Düzeltildi (Parça 143, "DEVAM ›" düğmesi) ama **uygulamaya
ancak yeni bir paket yüklenince ulaşır** — 54 kişi bekliyorsa bu yükleme
sıradaki en öncelikli iş.

### 0.B — 14 gün işlerken paralelde

Sırası önemli olan tek bağ: **#4, #2'den SONRA** (hesap silme kaskadı
çıkmadan test hesaplarını silmek aynı analizi iki kez yaptırır).

1. ✅ **BİTTİ (25 Ağustos 2026) — Madde 2, uygulama içinden hesap silme.**
   Play'in hesap açtıran uygulamalardan istediği İKİ şeyin ikisi de yerinde:
   web silme talep URL'i (`/hesap-silme/`, 0.A5) **ve** uygulama içi yol
   (Hesap Ayarları › Hesabımı Sil, web + port). Kaskad service-role bir Edge
   Function'da (`delete-my-account`) + `delete_account_cascade` RPC'sinde;
   `dryRun` bayrağıyla hiçbir şey silmeden sayan bir kuru çalıştırma modu
   var ve onay penceresi bunu gösteriyor. Karar/ölçüm/tuzaklar:
   `docs/decisions/account-deletion.md`.
   ✅ **Console'da yapılacak iş de YOK** (2 Eylül 2026'da düzeltildi).
   Burada *"App content › Data deletion formunda artık 'uygulama içi silme
   yolu VAR' seçilmeli"* yazıyordu; **böyle bir form alanı YOK.** Silme
   sorusunun cevabı `Evet → kelimeki.com/hesap-silme/` ve öyle kalıyor —
   Play'in uygulama içi şartı bir form alanı değil, **uygulamanın
   kendisinde** aranan bir politika şartı ve 372'de karşılandı.
   `console-formlari.md` §3.8 bunu 26 Ağustos'ta *"ENGEL KALKTI, beyanda
   değişen bir şey YOK"* diye kapatmıştı; bu satır o güne kadar geriye
   dönük olarak bayat kaldı.
3. ✅ **Madde 1 — deep link: KAPANDI** (30 Ağustos 2026, Faz 3'te ölçüldü;
   SAHADA 1.0.3 ile). Madde arşivde: `docs/decisions/roadmap-arsiv.md` →
   *"1. `kelimeki://` deep link kanalı"*. **Numara bilerek duruyor** —
   arşivdeki madde buraya (`0.B/3`) atıf yapıyor.
   ⚠ Bu satır 2 Eylül 2026'ya kadar bayat kaldı: hâlâ *"kayıt onayı maili
   uygulamayı değil web'i açıyor"* ve *"intent filter, Supabase redirect
   allow-list, e-posta şablonları, Flutter yönlendirme duruyor"* diyordu.
   Dördü de bitmişti — kayıt onayı 28 Ağustos'ta https'e geçti, intent
   filtreleri Parça 87/158'de zaten yazılmıştı, yönlendirmeyi Faz 3 ekledi.
   Açık kalan TEK parça **iOS Associated Domains**, o da bu maddenin değil
   aşağıdaki **iOS/APNs** bloğunun (Apple Developer üyeliği).
4. **0.C — App content formları** (aşağı).
5. ~~Test hesaplarının silinmesi~~ — **madde KALDIRILDI** (26 Ağustos 2026,
   kullanıcı kararı: *"gerekirse daha sonra hesabımı silden ben yaparım,
   önemli bir konu değil"*). Kalan test hesapları duruyor; büyüme
   metriklerini bir miktar kirletmeleri kabul edildi. ⚠ **`T2` ve
   `Ironman` hiçbir koşulda silinmez** — gerekçeleri
   `docs/decisions/account-deletion.md` → "ASLA SİLİNMEYECEK İKİ HESAP".

### 0.C — Play Console'da doldurulacak formlar (kod işi değil, zorunlu)

**Cevapların TAMAMI `marketing/play-store/console-formlari.md`'de** (24
Ağustos 2026). Aşağısı yalnızca hangi formun neden riskli olduğunun özeti.

- **Data safety — en dikkatli iş.** Beyan ile gerçek ayrışırsa askıya alma
  sebebi. Toplananlar: e-posta, ad/soyad, takma isim, cinsiyet, doğum
  tarihi, profil fotoğrafı, **oyun içi mesajlar**, anonim cihaz kodu
  (`anon_id`), hata telemetrisi (`client_errors`), ziyaret/oyun başlangıç
  olayları. **Kaynak metin hazır:** `PrivacyModal`'ın "Toplanan Veriler"
  bölümü satır satır forma eşlenmeli. Üçüncü taraflar: Supabase, Brevo,
  Vercel (19 Ağustos'ta politikaya eklendi). **"Paylaşılıyor" her satırda
  HAYIR** — hizmet sağlayıcı ve kullanıcının başlattığı görünürlük
  istisnalarıyla; 24 Ağustos 2026'da kullanıcı onayladı, gerekçe
  `console-formlari.md` §3.8'de.
- **Content rating (IARC):** ✅ **BİTTİ (25 Ağustos 2026).** Sohbet beyan
  edildi. Bu satır "yaş derecesini yükseltir" diyordu — **ölçüm bunu
  doğrulamadı:** sonuç en düşük bant (PEGI 3, USK 0, ESRB Everyone,
  IARC 3+). Sebebi, sohbete yalnızca kabul edilen arkadaşın girebilmesi ve
  sessize alma/şikayetin var olması.
- **UGC / moderasyon:** sohbet olduğu için gerekiyor. Karşılayacak
  mekanizma ZATEN var — sessize alma, şikayet, hesap dondurma, admin
  paneli; yalnızca beyan edilecek.
- **App access:** Canlı oyun/arkadaş özellikleri giriş istiyor →
  incelemeciye **çalışan bir test hesabı** verilmeli (bkz. 0.B/5).
  **Hesap seçildi: `T2` (`kelimekitest2`), 24 Ağustos 2026.** `T1`
  kullanılmıyor — e-postası geliştiricinin kişisel adresi. T2'nin durumu
  üretim veritabanından ölçüldü: doğrulanmış, dondurulmamış, 3 arkadaş,
  1 aktif Canlı oyun, 11 bitmiş oyun — yani incelemecinin göreceği dört
  ekran da boş değil.
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
- ✅ **Telefon ekran görüntüleri** — 7 kare, gerçek cihazdan, 1080×2072'ye
  kırpıldı (23 Ağu 2026, dosyalar kullanıcıda). Çekim listesi + gizlilik
  uyarıları + oran kuralı `metin.md`'de. Tablet desteği iddia edilecekse
  tablet görselleri ayrıca gerekir.
- ✅ Kategori **Games → Word** (25 Ağustos), iletişim e-postası
  `destek@kelimeki.com`, web sitesi `https://kelimeki.com` — üçü de
  Console'a girildi.
  ⚠ Bu satır 2 Eylül'e kadar ⬜ duruyordu ve BAYATTI; aynı üç madde
  yukarıdaki "Console (elle)" düzeltme tablosunda 31 Ağustos'ta zaten
  kapatılmıştı. Kaydın iki yerde durmasının bu dosyadaki dördüncü örneği.

**Görseller elle çizilmez:** reklam kareleri (`scripts/sponsored-post/`) ve
reel (`scripts/reel/`) zaten ÜRETİM bileşenlerini sunucuda render eden bir
desen kurdu — mağaza görselleri de aynı yoldan üretilmeli, yoksa vitrin ile
ürün sessizce ayrışır. **Tuzak:** o betiklerde Tailwind sınıfı çalışmaz
(`content` yalnızca `index.html` + `src/**` tarar), yalnızca inline `style`.


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

## 9. Admin Üyeler tablosuna "onaylanmamış" filtresi — **İSTEĞE BAĞLI**

**Model: Sonnet 5, efor `medium`.** Salt-okunur bir liste filtresi.

Kullanıcı 23 Ağustos 2026'da onayladı ("Filtre kalsın") ama o günkü "hemen
canlıya alalım" kapsamının DIŞINDA bırakıldı — asıl sorun (onaylanmamış
hesabın takma adı süresiz kilitlemesi) artık saatlik süpürmeyle çözülü
(bkz. kök `CLAUDE.md` → "Onaylanmamış hesap süpürmesi"), yani bu filtre bir
arıza değil bir görünürlük kolaylığı.

**Ne:** Üyeler tablosunda "yalnızca onaylanmamışları göster" seçeneği. Bugün
`admin_list_members` bu alanı HİÇ döndürmüyor — `auth.users.email_confirmed_at`
istemciye kapalı, yani RPC'ye bir kolon eklemek gerekiyor (dönüş tipi
değişince `create or replace` YETMEZ, drop+create + grant'leri elle geri kur;
kayıtlı tuzak: `fix_withdraw_report_wrong_overload`).

**Kapsam kararı:** yeni kolon Üyeler tablosunda gösterilecekse CSV'ye de
eklenmeli — "CSV ekranda görüneni indirir" sözü ancak öyle doğru kalır.
Sıralama anahtarı EKLEME (mevcut yedi anahtar korunuyor, gerekçesi
`CLAUDE.md` → "Kayıt alanlarının tamamı tabloda").

---

## 14. Uzun modal listeleri tembel inşa edilsin — **İZLEME, eşiğe bağlı**

27 Ağustos 2026, kullanıcı sordu: *"Arkadaşlar ara&ekle lazy yükleniyor
değil mi?"* İki ayrı "lazy" var ve cevap ikisinde farklı:

- **Veri yüklemesi: EVET, lazy.** 20'şerlik sayfalar
  (`kAllUsersPageSize` → `list_users_for_friend(offset, limit)`), gövdenin
  sonuna 80 px kala sonraki sayfa isteniyor; liste kaydırılamayacak kadar
  kısaysa `_autoLoadIfNotScrollable` elle tetikliyor. Bu değişmedi.
- **Widget inşası: HAYIR, artık değil.** Aynı gün kaydırma hatası
  düzeltilirken (Parça 146) iç içe `ListView` kaldırıldı ve yerine düz bir
  `Column` kondu — yani yüklenmiş TÜM satırlar inşa ediliyor. Tembelliğin
  kaybı o kararın bilinçli ama İKİNCİL bir bedeliydi; amaç iç içe
  kaydırılabiliri kaldırmaktı (Flutter zincirlemiyor, listenin alt 128 px'i
  erişilemiyordu).

**Bugün bedeli YOK ve sayı bu:** canlıda 47 profil var, yani en fazla ~46
satır. Ayrıca aynı modaldeki öteki iki sekme ("Arkadaşlarım", "İstekler")
BAŞTAN BERİ düz `Column`, ve web de tüm satırları DOM'a basıyor
(sanallaştırma yok) — yani parite de bozulmadı.

**Karar tetikleyicisi:** üye sayısı ~300'ü geçtiğinde, ya da liste gözle
görülür yavaşladığında. Muhtemelen ondan ÖNCE bir tasarım sorunu gelir
("kullanıcı 15 sayfa kaydırıyor") — o zaman doğru cevap sanallaştırma değil
arama/filtre olabilir; ikisini birlikte değerlendir.

⚠ **Çözüm iç içe `ListView`'a DÖNMEK DEĞİL** — düzeltilen hata aynen geri
gelir (bkz. `mobile/CLAUDE.md` → "`KModal`'ın gövdesi ZATEN
kaydırılabilir"). Doğru yol `KModal`'ın gövdesini `SingleChildScrollView`
yerine `CustomScrollView` + `SliverList` yapmak: kaydırılabilir yine TEK
kalır (zincirleme sorunu doğmaz) ama satırlar tembel inşa edilir.
`KModal`'a `bodyController`'ın yanına bir `slivers` yolu eklenir.

**Etki alanı geniş:** `KModal`'ı 15 modal kullanıyor, yani bu değişiklik
hepsine dokunur — küçük bir iş değil, kendi test turunu ister. Aynı
gerekçeyle 27 Ağustos'ta Sürüm A'ya alınmadı.

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

---

## 17. Google ile giriş/kayıt — **ERTELENDİ** (2 Eylül 2026) · Play Store'a girdikten SONRA

Kullanıcı sordu: *"Google ve Apple signup/signin özelliği eklemek zor mu?
Belki şimdilik sadece Google ile başlanabilir"* ve *"test sürecinde yapmak
mantıklı mı?"*. Cevap: Google tek başına makul, **ama sıraya girdi.**

### Neden ertelendi — kullanıcı kararı, 2 Eylül 2026

> *"Google signin olayını erteledik çünkü bu dönemde bu işi yapmanın
> acelesi yok. Çalışan düzene çomak sokmak olur boşuna. O nedenle önce
> Play Store'a girelim, sonra yaparız dedik. O kadar."*

Gerekçe bu: **öncelik sıralaması.** Yeni bir giriş yolu bugün hiçbir şeyi
açmıyor — kimse "Google ile giremiyorum" diye şikayet etmedi — ve çalışan
bir kimlik akışına dokunmanın karşılığı yok. Play Store'a girildikten
sonra yapılır.

⚠ **BU MADDE SAYAÇLA İLİŞKİLİ DEĞİL — 2 Eylül 2026'da AYRILDI.** Burada
*"kapalı test sayacı bitmeden BAŞLAMA"* diye dört maddelik bir risk
analizi vardı: özü, bozuk bir girişin tester'ı kaybettirip 12/14 sayacını
sıfırlayabileceğiydi. Kullanıcı sordu (*"17 Google sign-in işi değil mi?
Test süreciyle ne alakası var?"*) ve zincir açılınca ÜÇ yerden koptu:

- **Uygulamayı silmek testerlıktan çıkmak değil** — deponun kendi tester
  mesajı bunu söylüyor (*"uygulamayı silsen bile testerlıktan çıkma"*) ve
  kaldırmanın opt-in'i düşürüp düşürmediği zaten ÖLÇÜLMEMİŞ.
- **Mevcut tester'lar çoktan kayıtlı.** Google girişi EK bir yol; e-posta/
  şifreyle girenler yeni bir butondan etkilenmez. "Giriş yapamıyorum"
  asıl olarak YENİ kayıt olanı vurur.
- **Sayacın "tam 12" olduğu da artık kesin değil** (yukarıdaki açık soru).

**Ders:** bir erteleme kararının gerekçesi, kararın KENDİSİNDEN daha
karmaşık yazılmışsa muhtemelen sonradan uydurulmuştur. Gerçek sebep bir
öncelik tercihiydi; yerine bir risk zinciri yazılınca hem yanlış hem de
sahte bir takvim bağı ("~10 Eylül") doğdu.

### İşin KENDİ riski — takvimden bağımsız, ne zaman yapılırsa yapılsın

Yukarıdaki zincir düştü ama şu ikisi düşmedi; ikisi de "ne zaman"la değil
"nasıl"la ilgili:

1. **`handle_new_user` web ile portun ORTAK trigger'ı.** "Yalnızca web'de
   yaparım" diye bir kaçış YOK — hatalı bir migration mobil tarafta da yeni
   kayıt açılmasını bozar. Migration adımı (aşağıda "0.") bu yüzden BLOKER.
2. **Hesap birleştirme ölçülmedi** — aynı e-postayla önce şifreyle kayıt
   olup sonra Google ile girmek. Bu, MEVCUT bir kullanıcıyı da vurabilir
   (bkz. aşağıda "Ölçülmesi gereken, varsayılmayacak iki şey").

### Sıra: sunucu → web → mobil

Web'de oturmuş bir profil-tamamlama akışını porta taşımak, tersinden yapmaktan
belirgin biçimde ucuz.

**0. Migration — BLOKER, ilk iş.** Bugün Google girişi açılsa ilk denemede
patlar (ölçülmedi ama kaynak kesin): OAuth'ta `sharedxp_pending_profile`
metadata'sı HİÇ gelmez → `handle_new_user` ad/soyadı `coalesce(..., '')` ile
boşa düşürür → `profiles_first_name_not_blank` (`20260717164244`) ihlal edilir
→ trigger patlar, `auth.users` insert'i geri alınır, kullanıcı *"Database error
saving new user"* görür. Yapılacaklar:
- Ad/soyadı Google'ın `raw_user_meta_data`'sından türet (`full_name` /
  `given_name` / `family_name`), yoksa kısıtı sağlayan geçici bir değer.
- `display_name` **not null + `profiles_display_name_tr_lower_key` (Türkçe
  duyarsız UNIQUE)** — `split_part(email,'@',1)` fallback'i iki Gmail
  kullanıcısında çakışır; benzersiz geçici bir ad üret.
- **"Profili tamamla" bayrağı** (yeni kolon); `agreed_to_terms` OAuth'ta false
  doğar, modalda yazılır. `signup_channel`/`signup_utm_source` damgalanmaya
  devam etmeli.
- ⚠ **Aynı migration'da `sharedxp_pending_profile` borcunu da kapat** — trigger
  İKİ anahtarı birden okusun (`docs/decisions/product-backlog.md` → "Miras
  isimler"). Bu iş zaten trigger'a dokunuyor; ayrı PR bedeli ikiye katlar.
- Proje kuralı: uygula → `execute_sql` ile DOĞRULA → `list_migrations` ile
  dosya adını eşleştir.

**1. Konsol (kod değil, panelden).**
- Google Cloud: OAuth consent screen — yalnızca `email` + `profile` kapsamı
  (Google doğrulaması gerekmez); gizlilik + kullanım koşulları URL'leri zaten
  yayında (`/gizlilik/`, `/kullanim-kosullari/`).
- Web client ID + secret → Supabase → Authentication → Providers → Google.
- Supabase → URL Configuration → Redirect URLs (`kelimeki.com`, preview
  adresleri, `harfik.vercel.app` durduğu sürece o da — bkz. backlog'daki
  Vercel rename planı, ikisi çakışıyor).
- Android: **upload anahtarının VE Play App Signing anahtarının SHA-1'i**
  Firebase'e girilecek (Firebase Android OAuth istemcisini kendisi üretir).
  SHA-256 zaten `assetlinks.json` için çıkarılmıştı — `console-formlari.md` §6.6,
  aynı sayfa.

**2. Web (`src/`).** `signInWithGoogle()` (`api.ts`) · `AuthModal`'a buton ·
işin AĞIRLIĞI olan **profil tamamlama modalı** (takma isim — mevcut
`useNicknameAvailability`/`check_nickname_available` yeniden kullanılır —,
ad/soyad, şartlar, isteğe bağlı pazarlama izni) · OAuth-only hesapta şifre
yollarının gizlenmesi (`ResetPasswordModal`, `AccountSettingsModal`) ·
`useAuth`'un "profil eksik" durumunu yayması.

**3. Mobil (`mobile/app`).** `google_sign_in` + `signInWithIdToken` (web'in
redirect akışı DEĞİL, native akış; `supabase_flutter ^2.10.2` destekliyor) ·
aynı modalın portu · sürüm artışı (`pubspec.yaml` + `env.dart`, ikisi birlikte) ·
yeni `.aab` + Play incelemesi.

**4. Beyan ve doküman.** `TermsModal`/`PrivacyModal` + statik `/gizlilik/`
(Google'a giden veri) · Play **Data safety** formunun yeniden okunması ·
`TESTING.md` + `mobile/TESTING.md` — **gerçek bir Google hesabı gerektirdiği
için otomatik test EDİLEMEZ**, elle koşulan listeye girer · `CLAUDE.md`/`README`.

### Ölçülmesi gereken, varsayılmayacak iki şey

- **Hesap birleştirme:** aynı e-postayla önce şifreyle kayıt olup sonra Google
  ile girmek. Supabase'in kimlik birleştirme davranışı ayara bağlı; iki hesap
  mı bir hesap mı olduğu kullanıcının puanını ve k-lig geçmişini etkiler.
- **Hoş geldiniz e-postası:** `on_auth_user_welcome` `after insert or update of
  email_confirmed_at` — OAuth kullanıcısı DOĞRULANMIŞ doğduğundan bugüne kadar
  "ulaşılamaz" sayılan INSERT dalı devreye girer. Beklenen davranış doğru (mail
  gider), ama migration'ın yorumundaki "bugün ulaşılamaz" cümlesi o PR'da
  güncellenmeli.

### Apple neden bu maddede YOK

Apple Developer üyeliği alınmadı ve iOS yayında değil. Ayrıca **App Store 4.8:**
iOS uygulaması üçüncü taraf girişi (Google) sunuyorsa eşdeğer bir gizlilik
odaklı seçenek de sunmak zorunda — yani **iOS'a Google girişi koyulan gün Apple
girişi de zorunlu olur**; ikisi orada birlikte gider. Web ve Android'de böyle bir
kural YOK. Günü gelince iki tuzak: kullanıcı e-postasını gizleyebilir
(`@privaterelay.appleid.com`) ve **ad/soyad yalnızca ilk yetkilendirmede bir kez**
döner — o an kaydedilmezse bir daha alınamaz.


---

## 23. Seviyeli YZ (Kolay / Normal / Zor) + seviyeye göre k-lig puanı — **Faz 0-1 ✅ · Faz 2 sırada** (6 Eylül 2026)

Kaynak: `docs/decisions/product-backlog.md` → "YZ zorluk seviyesi" (5 Eylül
2026; kadran ölçümü, kapsam ve KESİN puan tablosu orada — burada
TEKRARLANMIYOR, yalnızca plana giren kısımları özetleniyor). Kullanıcı isteği
(6 Eylül): *"Analizini yapıp fazlı planı çıkart."* Bu bölüm o analiz. **Kod
yazılmadı.** Aşağıdaki her satır kaynak okunarak çıkarıldı (dosya:satır
verilen yerler ölçüm, "tahmin" yazanlar tahmin).

### 23.0 Neyin sabit olduğu (backlog'dan, değişmez)

| Oyun | 1. sıra | 2. sıra | Teslim |
|---|---|---|---|
| Canlı 4 kişilik (YZ'li) — seviye YOK, Normal sayılır | +2 | +1 | -2 |
| Yerel 2 kişilik — Kolay / Normal / Zor | 1 / **2** / 4 | yok | -2 |
| Yerel 4 kişilik — Kolay / Normal / Zor | 1 / **2** / 4 | 0 / **1** / 2 | -2 |

- **Normal = bugünkü değer, her hücrede.** Seviyesiz kayıt (bugüne kadarki
  her şey + tüm Canlı oyunlar) `null` → Normal dalı; **veri taşıma YOK.**
- Teslim her seviyede -2 (backlog: "varsayılan böyle kalsın; ölçeklenmesi
  istenirse ayrıca sorulur").
- Seviye seçimi yalnızca yerel YZ oyununda (2 ve 4 kişilik), 4 kişilikte
  ÜÇ YZ'ye birden uygulanır. Canlı'ya dokunulmaz.
- **HEDEF ORANLAR (6 Eylül 2026, kullanıcı kararı — 23.2'yi kapattı):**
  *"Normal bugünkü gibi kalacak. Kolay daha kolay olacak (%30 gibi), zor
  daha zor olacak (%70 gibi)."* Sayılar **YZ'nin insana karşı kazanma
  oranı** olarak okundu — Normal bugün ~%51 (insan %48,7), yani ölçek
  tutarlı:

  | Seviye | Motor | YZ kazanma hedefi (insana karşı) | Nasıl ölçülür |
  |---|---|---|---|
  | Kolay | bugünkü motor, en iyi N'den rastgele — **N=4** (Faz 0 ölçtü, kullanıcı onayladı, 6 Eylül) | **~%30** | `admin_ai_balance` seviye kırılımı (Faz 1'de geliyor) |
  | Normal | bugünkü motor, N=1 — DEĞİŞMEZ | ~%51 (bugünkü, 429 oyun) | aynı — sıfır çizgisi |
  | Zor | YENİ, daha güçlü motor (Faz 5) | **~%70** | aynı |

  Hedef bir SAHA ölçümü; YZ↔YZ koşumu yalnızca ön eleme (aşağı, Faz 0).
- **Bu planın eklediği kural:** seviye oyun BAŞINDA kilitlenir, oyun içinde
  değiştirilemez (aksi hâlde Kolay'da başlayıp son hamlede Zor'a geçmek +4
  eder — puan oyunu). `GameState`'e bir kez yazılır, değiştiren action YOK.

### 23.1 Etki haritası — kim etkileniyor

Kök `CLAUDE.md` "Çalışma İlkesi"nin üç sorusu bu iş için: (1) ikinci
okuyucu/yazar VAR — web ↔ port aynı `local_game_saves.state` jsonb'sini ve
aynı `games` satırını yazıyor; (2) ZİNCİR halkası — k-lig puanı formülü
**dokuz kopya** hâlinde yaşıyor (aşağıda); (3) derleyicinin göremeyeceği
değişmezler — golden vector determinizmi, Edge kopyası, SQL view'ları,
port `fromJson` sözleşmesi.

| Katman | Dosya / nesne | Ne değişir |
|---|---|---|
| **Motor — web** | `src/utils/ai.ts` `findAIMove` | `bestSafe`/`bestAny` tek-en-iyi yerine **en iyi N'lik liste** tutar; N>1'de listeden TEK `randomSource()` çağrısıyla seçer. `level` parametresi eklenir |
| **Motor — port** | `mobile/kelimeki_core/lib/src/ai/find_move.dart` | Aynı liste + `Rng` parametresi (reducer'ın zaten enjekte ettiği `rng`, `game_controller.dart:59-66`); `consider`'ın "eşitte ilk bulunan" sırası (`>` kesin) listede de korunmalı, yoksa parite sessizce kırılır |
| **Motor — Edge** | `supabase/functions/_game/ai.ts` (+ `play-ai-turn/index.ts:180`) | Kopya imza olarak güncellenir; `play-ai-turn` her zaman Normal verir. Seçenek B'de (aşağı) davranış DEĞİŞMEZ ve yeniden deploy yalnızca kopyayı eşitlemek için |
| **Rastgelelik** | `src/utils/random.ts` / `rng.dart` | Zaten enjekte edilebilir; YENİ kural: **N=1'de hiç rastgele değer tüketilmez** ki bugünkü `reducer_ai2/ai4` golden'ları bayt-eş kalsın |
| **Durum** | `src/game/types.ts` `GameState` + `gameReducer.ts` `START`/`PlayerSetup` | `aiLevel: 'kolay' \| 'normal' \| 'zor'` alanı; `AI_PLAY` bunu `findAIMove`'a geçirir |
| **Yerel kayıt** | `src/utils/gameStorage.ts` | `STORAGE_VERSION` **BUMP EDİLMEZ** (eski devam eden oyunlar sessizce silinirdi); eksik alan = `'normal'` |
| **Bulut kaydı (SÖZLEŞME)** | `local_game_saves.state` jsonb ↔ port `codec.dart:45` | Port `fromJson` KATI (`as bool`/`as String`); yeni alan `as String? ?? 'normal'` olmak ZORUNDA — web'in yazdığı eski kayıt / eski portun yazdığı kayıt için |
| **Oyun kaydı** | `buildGameRecord` (`gameRecord.ts`) → `NewGame` (`database.types.ts:459`) → `games` | Yeni kolon `games.ai_level` (nullable, check). `platform` kolonu (`20260814204059`) ŞABLON — ama ondan farklı: **SELECT de gerekli** (geçmiş kartları puanı bununla hesaplıyor) |
| **Puan — TS** | `src/utils/leaguePoints.ts` + 4 çağıran: `GameOver.tsx:116`, `GameHistoryModal.tsx:785`, `RecentGamesSection.tsx:192`, `SharedGamePage.tsx:64` | İmzaya `level` eklenir; dört çağıran seviyeyi bilmek zorunda → `GameHistoryEntry` + `fetchMyGames`'in `cols` dizesi (`api.ts:803`) + `get_shared_game` RPC dönüşü |
| **Puan — Dart** | `rules/league_points.dart` + `game_over_modal.dart`, `game_history_modal.dart`, `recent_games_section.dart:319`, `games_api.dart:404` `_listCols` | Aynı |
| **Puan — SQL (DÖRT canlı nesne, formül kopya)** | `player_stats` (`20260801081924`), `player_stats_overall` (`20260811235340`), `leaderboard` (`20260812131123`), `_award_league_rewards` (`20260812125039:44`) | Dördü aynı `case` bloğunu taşıyor; `k_lig_siralama` ve `my_leaderboard_rank` `leaderboard`'dan okuduğundan kendiliğinden düzelir. **Öneri: formülü TEK `immutable` SQL fonksiyonuna indir** (`league_points_for(rank, player_count, surrendered, ai_level)`), dördü onu çağırsın — bugünkü dört kopya zaten "aynı metriğin iki yerde ayrışması" hata sınıfının adayı. **→ Faz 1 YAPTI (6 Eylül 2026): kopya DÖRT değil BEŞti** — `trg_award_league_rewards` (`rank_down_notice`, delta hesabı) yalnızca canlıdan `pg_get_functiondef` ile göründü; beşi de `league_points_for`u çağırıyor, `verify-league-points` altıncısını yakalar |
| **Parite kapıları** | `npm run generate-golden-vectors` (`reducer_ai2/ai4` + YENİ `reducer_ai2_kolay`), `verify-edge-engine-parity` (imza), Dart `run_all.dart` | `verify-sql-engine-parity` k-lig formülünü KAPSAMIYOR (yalnızca `_km_*`) → yeni `verify-league-points` (şablon: `verify-league-tiers.mjs`, migration SQL ↔ `leaguePoints.ts` ↔ `league_points.dart` tablosunu kilitler) |
| **Yüzey — web** | `Setup.tsx` kurulum formu (oyuncu sayısı seçicisinin altına "ZORLUK"), `GameOver`/`GameHistoryModal`/`RecentGamesSection` kartlarında seviye rozeti (Normal'de rozet YOK — bugünkü görünüm korunur), Setup "devam eden oyun" kartı, `HelpModal.tsx:313-319` k-lig paragrafı (→ `/nasil-oynanir/` aynı kaynaktan, kendiliğinden) | |
| **Yüzey — port** | `setup_screen.dart:1705` `_buildNewGameForm` (`OYUNCU SAYISI` bloğunun ikizi), aynı üç kart, `devam_eden_govde.dart` | Web ile BİREBİR metin/sıra |
| **Admin / ölçüm** | `admin_ai_balance()` (`20260817051510`) | Seviye kolonu → dönüş tipi değişir → **drop + create + grant**. Bu, kadranın sahada doğrulanacağı TEK alet — Faz 1'e giriyor |
| **Testler / doküman** | `tests/smoke.spec.ts` (Kolay seçip başlatma), `TESTING.md` §10 k-lig, `mobile/TESTING.md` §13, `README.md`, kök `CLAUDE.md` (Oyun Mekaniği + Klasör Yapısı), `mobile/CLAUDE.md` golden envanteri | |
| **DOKUNULMAYAN** | `TermsModal`/`PrivacyModal` (yeni kişisel veri yok — seviye bir oyun ayarı), `submit_move` + SQL motor aynası (`_km_*` hamle DOĞRULAR, YZ seçmez), `create_online_game`, `online_games`, bildirim zinciri | |

⚠ **`players` jsonb SIRALAMAYA göre** (backlog'daki sorgu tuzağı) —
seviye kolonu oyun düzeyinde (`games.ai_level`) tutulacak, oyuncu satırına
DEĞİL; hem tuzağı baştan eler hem "4 kişilikte üç YZ'ye birden uygulanır"
kuralıyla örtüşür.

### 23.2 KARAR NOKTASI — hangi seviye hangi motor? → **KAPANDI: B** (6 Eylül 2026)

**Kullanıcı B'yi seçti:** Normal = bugünkü motor, dokunulmuyor. Kolay ve
Zor'un hedefleri 23.0'daki tabloda. Aşağıdaki A/B karşılaştırması kararın
gerekçesi olarak duruyor, yeniden tartışılmasın.

Backlog'un ölçüm tablosu (YZ↔YZ, N = "en iyi N'den biri") bir başlangıç
eşlemesi öneriyor: *Zor=1, Normal=3, Kolay=10*. Kadranı okurken şu iki
sayıyı yan yana koy: **N=3, N=1'e karşı oyunların %75'ini kaybediyor** ve
**insan bugünkü motora (N=1) karşı %48,7 kazanıyor** (429 oyun). İki eşleme
mümkün ve bedelleri çok farklı:

| | **A — backlog önerisi:** Zor=N1 (bugünkü), Normal=N3, Kolay=N10 | **B — öneri:** Normal=N1 (bugünkü), Kolay=N3–5, Zor=**yeni, daha güçlü motor** |
|---|---|---|
| "Normal" ne demek | Bugünkünden ZAYIF bir rakip | Bugünkü rakip — insan %48,7 kazanıyor, yani başa baş; "Normal"in ders kitabı tanımı |
| Geçmiş kayıtlar | Hepsi bugünkü (=Zor) motora karşı oynandı ama Normal (+2) sayılıyor — eski galibiyetler yeni Zor galibiyetlerinden (+4) daha az eder, **lider tablosunda dönem karışır** (backlog'un "ürün kırılması" uyarısı AYNEN gerçekleşir) | Geçmiş = Normal, doğru etiket; kırılma yok |
| Canlı 4 kişilik YZ | "Normal" = N3 ise `play-ai-turn` da N3 olmalı → Edge kopyasına rastgelelik kaynağı + `verify-edge-engine-parity`'ye tohum enjeksiyonu; ya da Edge N1'de kalır ve Canlı'nın "Normal"i yerel Normal'den güçlü olur (tutarsız) | Edge'e DOKUNULMAZ (imza eşitleme dışında); Canlı YZ gerçekten Normal |
| Yeni motor işi | YOK — yalnızca zayıflatma | **VAR** — Zor için bugünkünden güçlü bir motor gerekir; bugün "en yüksek puanlı hamle" zaten tavan, üstü yeni sezgisel ister (Faz 5) |
| Zor'un anlamı | İnsanın %49 yendiği rakip "zor" mu? Tartışılır | +4'ün gerekçesi ("zoru yenmek orantısız ödül") gerçekten zor bir rakibe denk gelir |

**Öneri: B.** Gerekçe tek cümle: bugünkü motor SAHADA ölçülmüş başa-baş bir
rakip, onu "Zor" diye etiketleyip Normal'i zayıflatmak hem geçmiş kayıtları
hem Canlı'yı tutarsızlaştırıyor; B'nin tek bedeli Zor'un ayrı bir faz olması
ve o faz kendi başına ertelenebilir (Kolay/Normal önce çıkar, Zor seçici
gelene kadar gösterilmez).

B'de "Zor" için adaylar — hepsi ÖLÇÜLMEDEN seçilmez, hepsi aynı YZ↔YZ
koşumuyla ve sonra sahada `admin_ai_balance` kırılımıyla ölçülür:

1. **Havuz 8+ harf** — `getWordPool` 2-7 ile sınırlı (`ai.ts:26`), çapa +
   raf 7 = 8 harf kurala uygun ama hiç denenmiyor. Arama maliyeti artar;
   ölç.
2. **Joker tasarrufu** — `consumeRack` jokeri İLK eksik harfte harcıyor
   (`ai.ts:36-52`); joker 0 puan ama bingo (+25) ve uzun kelime anahtarı.
   "Jokerli hamle, jokersiz en iyiden X puan fazla değilse jokeri sakla" gibi
   bir eşik.
3. **Raf-kalıntı değeri** — hamle sonrası rafta kalan harflerin
   oynanabilirliği (sesli/sessiz dengesi, `Ğ`/`J` gibi ölü harfler).
4. **Bölge savunması** — bugün YZ vergiden kaçınıyor ama rakibin bölgesini
   BÜYÜTECEK hücreleri bloke etmiyor; `computeAllTerritories` zaten
   önbellekte, fark hesaplanabilir.

**Kolay için N — hedef YZ ~%30:** insan bugünkü motorla (N=1) başa baş
olduğuna göre YZ↔YZ tablosu kaba bir vekil olarak kullanılabilir: N=3, N=1'e
karşı **%25** kazanıyor → insana karşı **tahmin ~%25-30**, yani hedefin
tam üstünde. **Başlangıç adayı N=3;** sahada %30'un belirgin altına düşerse
N=2 (ölçülmedi, Faz 0 koşumu tabloya eklesin), üstüne çıkarsa N=5 (%21).
N=10 (%8) hedefin çok altında — aday DEĞİL.
**→ Faz 0 ÖLÇTÜ (6 Eylül 2026, 200 oyun/N, koltuk değişimli): yukarıdaki
%25 24 oyunun gürültüsüydü; N=3 aslında %36, N=4 %33, N=5 %22. Kolay'ın
başlangıcı N=3 DEĞİL N=4** — tablo ve gerekçe backlog notunda; Faz 2
`AI_LEVEL_TOP_N.kolay = 4` yazar. Saha ayarı: belirgin üstündeyse N=5,
altındaysa N=3.

**Zor için hedef YZ ~%70 — planın en zor yarısı:** bugünkü motor "en yüksek
puanlı hamle" tavanında ve insan onu %49 yeniyor; %70'e çıkmak için motor
GERÇEKTEN güçlenmeli, zayıflatmanın tersi tek bir kadran değil. Yukarıdaki
dört aday tek tek YZ↔YZ'de ölçülür; Normal'i (N=1) **≥%70** yenen bir
bileşim bulunana kadar Zor seçici AÇILMAZ. Sahada %70 tutmazsa kadran
yeniden ayarlanır — hedef bir sürüm değil, bir ölçüm döngüsü.

### 23.3 Fazlar — paketlenebilirliğe göre (bu dosyanın kendi kuralı)

Sunucu anında, web merge'de, port sürüm turunda canlıya çıkıyor; fazlar buna
göre kesildi. **Her faz tek başına geriye uyumlu** — Faz 1'den sonra hiçbir
kullanıcı için tek bir puan değişmez, Faz 2'den sonra hiçbir YZ farklı
oynamaz (seviye seçilemediği için hep Normal), görünür değişiklik Faz 3'te.

**Faz 0 — Ölçüm aleti · ✅ YAPILDI (6 Eylül 2026).** Alet
`scripts/simulate-ai-levels.ts` (`npm run simulate-ai-levels`), koşum 200
oyun/N, sonuç **Kolay = N=4**. Faz metni ve ölçüm ayrıntısı arşivde:
`docs/decisions/roadmap-arsiv.md` → "23 · Faz 0"; tablo backlog notunda.
⚠ Faz 2'ye iki miras: (1) alet motorun arama döngüsünün KOPYASINI taşıyor
ve CI her PR'da kopyayı üretimle karşılaştırıyor (`web-ci.yml`, 2 oyun) —
Faz 2 `findAIMove`'a `level` ekleyince alet o parametreyi çağırmalı, kopya
ve CI adımı silinmeli; (2) Faz 5 Zor motorunu AYNI aletle ölçer.

**Faz 1 — Sunucu · ✅ YAPILDI (6 Eylül 2026).** Migration
`20260906114252_ai_level_and_league_points_for` CANLIDA; faz metni ve
öncesi/sonrası kanıtı arşivde: `docs/decisions/roadmap-arsiv.md` → "23 ·
Faz 1". Sonraki fazlara üç miras: (1) k-lig formülü sunucuda artık TEK
fonksiyon (`league_points_for`) — 23.1'in "dört kopya"sı aslında BEŞti
(`trg_award_league_rewards` delta hesabı canlıdan bulundu), beşi de
fonksiyonu çağırıyor; `npm run verify-league-points` (CI'da) SQL ↔ TS ↔
Dart tablosunu kilitliyor ve Faz 3 `leaguePoints`e `level` ekleyince
ariteyi okuyup üç seviyeyi kendiliğinden sınıyor. (2) `GameHistoryEntry.
ai_level` OPSİYONEL: `fetchMyGames` seçiyor ama `list_liked_games` RPC'si
döndürmüyor — **Faz 3 o RPC'ye de kolonu eklemeli** (dönüş tipi değişir →
drop+create+grant). (3) `admin_ai_balance` satırları artık `(players,
ai_level)`; panel Normal'de bugünkü gibi, Kolay/Zor satırı Faz 3 yazmaya
başlayınca kendi kutusunu açar.

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

**Faz 3 — Web ürün yüzeyi (merge → Vercel).** Model: Sonnet 5, efor
`medium`; Opus'a yükselt: `Setup.tsx` 1137 satır ve iki sekmeli.
- `GameState.aiLevel` + `PlayerSetup`/`START` payload'ı; `gameStorage`
  eksik alan → `'normal'` (VERSION sabit); `cloudSaveMirror`/`gameSync`
  jsonb'yi olduğu gibi taşıdığından ek iş yok — ama `verify-cloud-save-mirror`
  fixture'ına alan eklenir.
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

**Faz 5 — Zor motoru (kendi PR'ı; Kolay/Normal'den bağımsız çıkar).**
Model: Opus 5, efor `high`.
- 23.2'deki dört aday Faz 0'ın aletiyle TEK TEK, sonra bileşim hâlinde
  YZ↔YZ ölçülür; **kapı: Normal'i (N=1) ≥%70 yenen bir bileşim.** Hiçbiri
  yetmiyorsa bir sonraki kademe tek katlı ileri bakış (rakibin en iyi cevabını
  düşerek puanlama) — maliyeti "düşünme süresi", ölçülmeden vaat edilmez.
- Sonra Faz 2'nin parite zinciri aynen: üç kopya (web, port, Edge kopyası —
  Canlı YZ Normal kaldığından Edge yalnızca kopyayı eşitler), golden'lara
  `reducer_ai2_zor` fixture'ı, `verify-edge-engine-parity`.
- Zor seçici web + portta aynı sürüm haftasında açılır.
- Saha ölçümü: `admin_ai_balance` seviye kırılımı 2 hafta, hedef 23.0
  tablosu (Kolay YZ ~%30, Normal ~%51, Zor ~%70). Sapma varsa kadran
  (Kolay: N; Zor: sezgisel ağırlıkları) ayarlanır, motor yeniden yazılmaz.

### 23.4 Tuzaklar — bu depoya özgü, planı uygulayan okusun

- `STORAGE_VERSION`'ı bump ETME; eksik alan = Normal (23.1).
- Yeni kolona SELECT vermeyi unutma; `platform` şablonu bilerek VERMİYOR,
  buradaki ihtiyaç ters.
- Dönüş tipi değişen her fonksiyon (`get_shared_game`, `admin_ai_balance`)
  drop+create+grant; `create or replace` sessizce "cannot change return
  type" verir.
- Golden'larda ÖNCE sıfır fark kanıtı, SONRA yeni fixture — sıra tersine
  dönerse "N=1 bayt-eş" iddiası kanıtsız kalır.
- Dart `consider` sırası: listeye ekleme "puan eşitse ilk bulunan önde"
  kuralını korumalı; `sort` KULLANMA (kararlılık garantisi yok), sıralı
  ekleme yap.
- `verify-league-points` yoksa dokuz kopya (4 SQL + TS + Dart + 3 kart
  metni) bir sonraki dokunuşta ayrışır — Faz 1'in parçası, "sonra" değil.
- Zor=4 eşik ödüllerini (`leagueRank.ts` kademeleri, `_award_league_rewards`)
  hızlandırır — bilinçli, değiştirme; ama #5 k-lig grafiği yapılırsa seriyi
  `league_points_for` ile kurmalı.
- Kural metni üçlüsü: `HelpModal` ↔ `Landing.tsx` ("Neler var"/"Nasıl
  oynanır") ↔ portun yardım ekranı — "bölge vergisi" terminoloji dersinin
  aynısı, üçüncü bir ifade üretme ("kolay mod" / "zorluk seviyesi" /
  "seviye" — TEK sözcük seç, öneri: **Zorluk: Kolay · Normal · Zor**).
- `admin_ai_balance` bugün `not g.surrendered` filtreliyor; seviye kırılımı
  aynı filtreyi korumalı, yoksa eski/yeni satır karşılaştırılamaz.

### 23.5 Kapanış ölçütü

| Faz | "Bitti" kanıtı |
|---|---|
| 0 | ✅ `simulate-ai-levels` repoda, 200 oyunluk koşum tablosu backlog notunda, Kolay **N=4** seçildi (6 Eylül 2026) |
| 1 | ✅ migration canlıda (`20260906114252`), altı view/tablo karması öncesi/sonrası bayt-eş (953 oyun), `verify-league-points` CI'da yeşil (6 Eylül 2026) |
| 2 | golden sıfır fark (N=1) + `reducer_ai2_kolay` Dart'ta yeşil + `verify-edge-engine-parity` yeşil + `play-ai-turn` deploy edildi (verify_jwt korunarak) |
| 3 | `curl kelimeki.com \| grep kelimeki-build` = `main` başı; Kolay'da biten oyunun kartı +1 gösteriyor ve `k_lig_siralama` aynı sayıyı veriyor |
| 4 | cihazda: portta Kolay seçilip bitirilen oyun web'de aynı puanla görünüyor ve tersi (aynı hesap, iki cihaz) |
| 5 | Zor motoru YZ↔YZ'de Normal'i ≥%70 yeniyor + sahada iki hafta: Kolay ~%30 / Zor ~%70 YZ kazanma bandında |
