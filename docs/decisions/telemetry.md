# İstemci Hata Telemetrisi — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026). client_errors tablosu, admin panelindeki 'Hatalar' sekmesi.

## İstemci Hata Telemetrisi (21 Ağustos 2026, ROADMAP #3)

**NEDEN VAR:** o güne kadar istemcide doğan HER hata kullanıcının cihazında
ölüyordu — web'de 81 `console.error`, portta 74 `debugPrint`, artı
`ErrorBoundary.componentDidCatch` (yalnızca konsola yazıyordu). Kimse
görmüyor, aranamıyor, "kaç kişide oldu?" sorusu sorulamıyordu. Bedeli bu
projede ÖLÇÜLMÜŞTÜ: avatar yükleme 20 Temmuz'dan 13 Ağustos'a kadar 403
veriyordu ve kimse fotoğrafını değiştirmediği için ÜÇ HAFTA görünmedi;
Parça 45'teki "depo açılamadı → offline hamleler sessizce kayboldu" teşhisi
TAHMİNLE yapılmak zorunda kaldı. **Supabase'in sunucu loglarıyla
KARIŞTIRMA** — Postgres/Edge Function hataları zaten orada; eksik olan, hiç
sunucuya ulaşmayan istemci hataları.

**Mağaza çıkışından ÖNCE yapıldı ve bu bilinçli:** geriye dönük
doldurulamaz (`games.platform` ile aynı sınıf). Mağazaya çıkıldığında
konuşulamayacak kullanıcılar, elde olmayan cihazlarda hata alacak.

### Tablo — `client_errors` (`20260821084652_client_errors` migration'ı)

`guest_visits`/`game_starts` deseninin aynısı: **anonim**, `user_id` YOK
(`PrivacyModal` §6'nın "bu kod hesabınızla ASLA eşleştirilmez" taahhüdü),
insert `anon` + `authenticated` rollerine açık, **SELECT politikası HİÇ YOK**
— okuma yalnızca `admin_client_errors(p_days)` RPC'sinden (SECURITY DEFINER,
`is_admin()` kapılı).

Sunucu tarafında İKİ savunma daha var ve ikisi de istemciye güvenmiyor:
- `_client_errors_mask` (BEFORE INSERT) — `route`taki 12+ karakterlik
  hex/uuid dizilerini `:id`ye çevirir, `message`ı 500, `stack`i 4000
  karaktere kırpar. **İstemci de aynısını yapıyor** (`normalizeRoute`),
  ama tek savunma hattı OLMAMALI: `/davet/<token>` bir YETENEK, hata
  tablosuna düşmesi onu sızdırır.
- `admin_client_errors` satırları **GRUPLAYARAK** döner —
  `(kind, left(message,160))` imzası başına tek satır: `occurrences`,
  `devices` (benzersiz `anon_id`), `platforms`, `builds`, `routes`,
  `first_seen`/`last_seen`, `sample_stack`.

### NE KAYDEDİLMEZ — bu, işin en önemli kararı

Bir kayıt **"birinin bakması gereken bir şey"** demek olmalı; gürültü
sinyali boğarsa panel bir daha açılmaz. Bu yüzden BEKLENEN durumlar
bilerek dışarıda: çevrimdışılık ve `isNetworkError`'a düşen her şey,
sunucunun KENDİ reddi ("Sıra sende değil." — o bir kural, hata değil).

**⚠ Ağ filtresi YALNIZCA otomatik yakalamalara uygulanır (`kind !== 'manual'`)
ve bu, tasarım turunda YAKALANAN bir hatanın düzeltmesi.** İlk sürüm filtreyi
koşulsuz uyguluyordu; o hâliyle ROADMAP'in ADIYLA andığı vakayı — portun
`cloud_save_repo` "KAYIP" noktasını — tam da sessizce düşürüyordu: oradaki
hata çoğu zaman bir AĞ hatasıdır, ama raporlanmaya değer kılan şey
**aynanın DA yazılamamış olmasıdır**, yani sinyal hatanın kendisinde değil
ÇAĞIRANIN bildiği bağlamda. Manuel bildirimler bu yüzden filtreyi atlar.

### İlk gerçek veri filtreyi İKİ kez genişletti (23 Ağustos 2026)

Panel canlıya çıktıktan iki gün sonra ilk kayıtlara bakıldı: **yedi kaydın
yedisi de gürültüydü.** Yani kural doğru yazılmıştı ama kapsamı eksikti —
filtre olmadan panel ilk haftasında kullanılamaz hâle gelirdi. İki yeni
eleme kuralı:

**1) BİZE AİT OLMAYAN koddan doğan hatalar (`isThirdPartyError`).** Yedi
kaydın **beşi** tek bir kaynaktı: Instagram/Facebook'un Android'deki
uygulama-içi tarayıcısı sayfaya bir ölçüm script'i enjekte ediyor
(`iabjs://navigation_performance_logger_android`) ve sekme kapanırken
`postMessage`ta patlıyor — *"Error invoking postMessage: Java exception was
raised during method invocation"*, `window._handleBrowserPreparingToClose`
karesiyle. **Yığında bizim kodumuz HİÇ geçmiyor**; düzeltemeyiz ve
Instagram reklamı sürdükçe katlanarak artar. Altıncı kayıt aynı sınıfın
öteki yüzü: **`Script error.`** — çapraz kaynaklı bir script'ten gelen
hatada tarayıcı mesajı/yığını/satırı SİLER, geriye teşhis değeri sıfır olan
o dize kalır. Üç sinyal: `Script error.` + yığınsız; `ErrorEvent.filename`
bizim origin'imizden değil; ya da yığındaki HİÇBİR kare bizim origin'imizden
değil. **Şüphede kal ve raporla:** göreli/satır içi/URL'siz kare "bizim"
sayılır — bu filtrenin yanlış pozitifi GERÇEK bir hatayı sessizce düşürmek
demek. Üçüncü kural ancak sayfada dış script OLMADIĞI için güvenli (yalnız
kendi paketimiz); bir gün analytics/SDK eklenirse yeniden düşünülmeli.
`filename` YALNIZCA `ErrorEvent`te var, `Error`da yok — o yüzden karar hem
`reportClientError` içinde (yığından) hem global `error` dinleyicisinde
(dosya adından) veriliyor.

**2) Oturumu düşmüş istemcide "permission denied" (`reportLiveListError`,
`api.ts`).** Yedinci kayıt: `[list_my_online_games] permission denied for
function list_my_online_games`. **Grant DOĞRU** (canlıdan okundu:
`EXECUTE:authenticated`), yani rol `anon` kalmış — geçerli bir JWT
gönderilmemiş. Başka açıklaması yok: oturum düşmüş, süresi geçmiş ya da
yenileme henüz tamamlanmamış. Üç çağrı yeri de (`list_my_online_games`,
`fetch_online_game_turns`, `fetch_online_game_deadlines`) zaten `user`
varken tetikleniyor, yani bu bir yarış — bug değil.
**⚠ AMA mesaja bakıp körlemesine filtrelemek YANLIŞ olurdu:** aynı mesaj
gerçek bir dağıtım hatasının da yüzü — bir fonksiyon `drop`+`create`
edildikten sonra `grant` unutulursa oturumu olan HERKES aynı mesajı alır ve
bu projede bir kez yaşandı (bkz. `fix_withdraw_report_wrong_overload`).
İkisini ayıran TEK şey **oturumun varlığı**: oturum VARKEN gelen bir
"permission denied" raporlanır, oturumsuz gelen elenir. Kontrol
`getSession()` ile — yerel depodan okur, AĞA GİTMEZ (`fetchMyGames`'in
14 Ağustos düzeltmesinin aynı ayrımı).

**Doğrulama:** `npm run verify-error-reporting` 20 → **30 kontrol**
(gerçek IAB yığını, `Script error.`, kendi yığınımızın pozitif kontrolü),
`npm run verify-live-games-load` **28 kontrole** çıktı — dördü yeni
(oturumsuz elenir / oturumlu raporlanır / yetkiyle ilgisiz hata her
hâlükârda raporlanır / dönüş davranışı değişmedi).
**Negatif eş, ikisi de ayrı ayrı:** üçüncü taraf filtresi kaldırılınca ve
auth-durumu guard'ı kaldırılınca ilgili kontroller GERÇEKTEN düşüyor.
**Flutter portu ETKİLENMEDİ ve bu bilinçli:** orada sayfaya script enjekte
eden bir uygulama-içi tarayıcı YOK (`Script error.` diye bir kavram da yok)
ve port bu üç RPC'nin hatasını hiç raporlamıyor (`ErrorReporter`ın tek
manuel çağrı yeri `cloud_save_repo`).

**Kayıtlar SİLİNMEDİ** — panelin penceresi (7/30/90 gün) onları zaten
kendiliğinden dışarıda bırakacak, ve bu yedi satır filtrenin neden
gerektiğinin kanıtı.

### Mağaza öncesi üç ekleme — sürüm, rota (23 Ağustos 2026)

Kullanıcı *"özellikle ileride app tarafı geldiğinde eksik ne var?"* diye
sorunca yapılan denetimden çıktı. Üçü de **geriye dönük doldurulamaz**
(`games.platform` ile aynı sınıf), o yüzden mağazadan ÖNCE:

- **`client_errors.app_version` + `game_starts.app_version`/`platform`**
  (`telemetry_app_version` migration'ı). Web'de AYNI ANDA tek canlı derleme
  var; app'te aynı anda beş sürüm olur. **Web bu alanı NULL bırakır ve bu
  bir eksiklik DEĞİL, anlamın kendisi:** web'in sürümü `build` (sha) ile
  zaten tekil; uydurma bir değer dağılımı kirletirdi. `game_starts`ta
  `platform` da YOKTU (ölçüldü) — `app_version` tek başına ios ile android'i
  ayıramaz.
- **`admin_client_errors` artık `versions` döndürüyor** (dönüş tipi
  değiştiğinden drop+create, grant'ler elle). Sürümü olmayan istemciler
  `filter` ile ELENİYOR, `'?'` ile doldurulMUYOR — yalnız web'den gelen bir
  grupta alan `null` kalır ve panel "Sürüm:" satırını hiç çizmez.
- **`admin_app_version_breakdown(p_days)` → Büyüme > Kullanıcı'da "Sürüm
  Dağılımı" tablosu.** Var olma sebebi tek bir soru:
  `app_config.mobile_min_supported_version` eşiğini yükseltmek güvenli mi?
  Eşiği erken yükseltmek eski sürümdeki kullanıcıları uygulamadan kilitler
  (`version_gate.dart`), geç yükseltmek düzeltilmiş bir hatayı sahada
  yaşatır. **⚠ OYUN AÇILIŞI sayar, KULLANICI değil** — port `anon_id`
  göndermiyor, dolayısıyla app satırlarında cihaz sayılamıyor; kapsam da
  yalnızca YEREL (YZ) oyunlar (`game_starts`ın kendi kapsamı), yani yalnız
  Canlı oynayan biri tabloda hiç görünmez. Tablo `GuestBreakdownTable`'ı
  yeniden kullanıyor; bileşene `valueLabel` prop'u eklendi — sayı sütununun
  başlığını "Ziyaretçi" bırakmak sayının ne olduğu konusunda yalan söylerdi.
- **Portun `route` alanı SABİT `'app'`ti, artık gerçek ekran adı**
  (`ErrorReporterRouteObserver`). Web'de o kolon '/'/'/game/:id' diye
  ayrışıyor; app trafiği baskın hâle gelince kolon tamamen ölürdü. Adlar
  push yerlerinde veriliyor (`intro`/`game`/`online-game`), **adsız rota KÖK
  sayılıyor** — yeni bir ekranın adı unutulursa kayıt yanlış olmaz, yalnızca
  ayrıntısını kaybeder.
- **Portta `appVersion` ↔ `pubspec.yaml` paritesi TESTLİ**
  (`app_version_parity_test.dart`). Bu denetim onu bağımsız olarak bulup
  testini yazdı, ama `main`'e alınırken Play yayını turunun (22 Ağustos)
  AYNI testi aynı gerekçeyle çoktan eklediği görüldü — kopya düşürüldü,
  kanonik olan `main`'inki. Kilitlenme senaryosu: `mobile/CLAUDE.md`,
  Parça 130.

**ÖLÇÜLDÜ** (derlenmiş CSS + Chromium, DPR 2, gerçek modal kromu,
320/360/390/834/1194; sınıf dizeleri `AdminDashboard.tsx`'ten OKUNARAK):
sayfa taşması her genişlikte **0**; tablo **276–279 px**, 360 px'ten itibaren
kabına sığıyor, 320'de kendi `overflow-x-auto` kabında **30 px** kayıyor;
başlıklar üç genişlikte de tek satır (29 px); hata kartı sürüm satırıyla
86.5 → **107.5** px. Sürüm satırı YALNIZCA `versions` doluyken çiziliyor
(negatif eş aynı harnesste ölçüldü).

**Canlıda doğrulandı** (gerçek admin JWT'siyle, sahte app satırlarıyla, hepsi
rollback): `[ios 0.1.0 starts=2 devices=2]`, `[android 0.2.0 starts=1
devices=0]`, hata satırında `versions=0.1.0 platforms=ios`; admin olmayan
çağrı `Yetkisiz erişim.` aldı. Mevcut web satırları `bilinmiyor/bilinmiyor`
görünüyor — `game_starts.platform` de bugün eklendi, yani geçmiş
doldurulamaz; panel `bilinmiyor` sürümü **—** olarak çiziyor (web'in sürümü
yok, bu eksik veri değil).

### Üç değişmez (biri bozulursa telemetri ürünü bozar)

1. **Fire-and-forget** — asla `await` edilmez, ASLA fırlatmaz.
2. **Tekrar bastırma + hız sınırı** — imza `${kind}|mesajın ilk 120
   karakteri`, oturum başına en fazla **10** kayıt. Bir çökme döngüsü aksi
   halde binlerce satır yazar (`ErrorBoundary`'nin kendi yorumunda o döngü
   zaten tanımlı: bozuk kayıt → her reload'da aynı hata).
3. **Derleme kimliği** her kayda eklenir (`window.__KELIMEKI_BUILD__` /
   `buildSha`) — "Deploy Doğrulaması" bölümünün tamamı zaten bu soruyu
   çözmek için var; telemetri onu bedavaya alır. Panelde bu, "düzeltme
   işe yaradı mı?"nın tek cevabı: hata yalnızca ESKİ derlemede kalıyorsa
   düzelmiştir.

### İki istemci, aynı kurallar

| | web | port |
|---|---|---|
| Modül | `src/utils/errorReporting.ts` | `mobile/app/lib/src/data/error_reporter.dart` |
| Otomatik yakalama | `window.onerror` + `unhandledrejection` (`boot.tsx`) | `FlutterError.onError` + `runZonedGuarded` (`main.dart`) |
| Render/çökme | `ErrorBoundary.componentDidCatch` → `kind:'boundary'` | `FlutterError.onError` → aynı `kind` |
| Yol (`route`) | `normalizeRoute(location.pathname)` | sabit `'app'` — portta pathname yok, ekran adı taşımak yerine yığına bakılır |
| Sınama | `npm run verify-error-reporting` (20 kontrol, CI'da) | `test/error_reporter_test.dart` (8 test) |

**Portta İKİ yakalayıcı da şart ve farklı şeyleri görüyor:**
`FlutterError.onError` widget ağacındaki (build/layout/paint) hataları,
`runZonedGuarded` zone dışına kaçan async hataları. Yalnızca birini kurmak
ötekinin gördüğü sınıfı sessizce kaçırır. `FlutterError.onError`'ın ÖNCEKİ
değeri de çağrılmaya devam ediyor — aksi halde yerel geliştirmede kırmızı
ekran/log kaybolurdu.

**Karar mantığı ağdan bağımsız sınanabilsin diye iki tarafta da bir
"sink" var** (`ClientErrorSink` / `__setClientErrorSinkForTests`). Web'de
duman testi bu modülü SINAYAMAZ — üretimde yalnızca Supabase
yapılandırılmışken çalışıyor, dev sunucusunda yapılandırılmamış; bu yüzden
`verify-*` betiği deseni (esbuild + node) kullanıldı. **Negatif eş
ölçüldü:** tekrar bastırma, ağ filtresinin `manual` istisnası, hız sınırı
ve yol maskeleme tek tek kaldırıldığında sırasıyla 1/1/1/2 kontrol GERÇEKTEN
düştü.

### Admin paneli — "Hatalar" sekmesi

Dördüncü sekme (`AdminDashboard.tsx`). **Rozet YOK ve bu bilinçli:**
`CountBadge` bu projede "bekleyen İŞ" demek (bkz. o bölüm); bir hata kaydı
admin'in yapması gereken bir kuyruk maddesi değil, bir gözlem.

Kartlar gruplanmış satırları çiziyor; **"Kez" ile "Cihaz" yan yana ve eşit
vurguda** — ayrılmadan bir hatanın yaygın mı yoksa tek kişinin döngüsü mü
olduğu okunamıyor (40 kez / 1 cihaz ≠ 3 kez / 3 cihaz). Karta dokunmak yol,
ilk görülme ve örnek yığını açıyor. CSV `sample_stack` dahil dışa aktarıyor.
Pencere seçici (24 saat / 7 / 30 / 90 gün) Büyüme'nin periyot
kontrollerinden BİLEREK bağımsız: orada soru "zaman içinde nasıl gidiyor",
burada "şu an bakılması gereken ne var".

**ÖLÇÜLEN DÜZEN HATASI — dördüncü sekme tek sıraya SIĞMIYORDU.** Sekme
şeridi `flex gap-1.5` + `flex-1` idi; `flex-1` bir öğeyi `min-width:auto`
yüzünden en uzun kelimesinin ("BİLDİRİM") altına indiremiyor, dolayısıyla
dört sekmenin min-content toplamı 320px'te kabı **77px**, 390px'te **7px**
AŞIYOR ve panelin `overflow-hidden`'ı bunu SESSİZCE kırpıyordu (negatif eş:
dördüncü buton kaldırılınca üç genişlikte de taşma 0). Şerit
`grid grid-cols-2 min-[580px]:grid-cols-4` oldu — dar ekranda 2×2, tek
sıraya ancak dört etiketin de TEK SATIRDA sığdığı genişlikten sonra geçiyor
(eşik "GERİ BİLDİRİM"in max-content'i ≈120px'ten türetildi). **Ölçüldü**
(derlenmiş CSS + Chromium, gerçek `AdminDashboard` sunucuda render edilip):
320/390/579/580/640/834/1194'te yatay taşma **0** ve etiketlerin hepsi tek
satır (38.5px) — bu, değişiklikten ÖNCEKİ hâlden de iyi (orada 320/390'da
sekmeler iki satıra sarıyordu).

**Ders:** bir sekme/buton eklemek "tek satır" değil bir DÜZEN
değişikliğidir. `flex-1` "her koşulda sığar" demek DEĞİL.

### Gizlilik metni

`PrivacyModal` §6 (+ portun `legal_modals.dart`'ı, AYNI PR'da — tarihler
`legal_text_test.dart` ile kilitli) artık anonim kodun ÜÇÜNCÜ bir durumda
da gönderildiğini söylüyor. Metin bir şeyi açıkça kabul ediyor: **teknik
hata açıklamaları çok nadiren kullanıcının yazdığı bir metin parçasını
içerebilir** — bunu yazmamak, "hiçbir kişisel veri yok" iddiasını sessizce
yanlış kılardı.

### Bilinen sınırlar

- **Açılışın ilk milisaniyeleri:** rapor gönderimi Supabase bağlanana kadar
  sessizce düşer (portta `ErrorReporter.configure`'dan önce, web'de
  `supabase` null iken). Kuyruklamak için ayrı bir depo açmak, telemetrinin
  KENDİSİNİ bir açılış riski hâline getirirdi. Yakalayıcılar yine de en
  başta kuruluyor.
- **Yığın sembolleri çözülmüyor** — minify edilmiş web yığını ve release
  Dart yığını okunması zor. Source map yüklemek ayrı bir iş; bugün
  `message` + `route` + `build` üçlüsü teşhis için yeterli kabul edildi.

