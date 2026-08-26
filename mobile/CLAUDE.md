# Kelimeki Mobil (Flutter) Portu — Claude Code Rehberi

Bu dosya, web uygulamasının (kök `CLAUDE.md`) Flutter/iOS+Android portuna ait
TÜM kararların ve yapının kaydıdır — kök `CLAUDE.md` ile aynı refleks:
**anlamlı her değişiklikte bu dosya da aynı PR'da güncellenir.** Web tarafına
dokunan bir port değişikliği olduğunda (ör. `src/utils/random.ts`'teki test
kancası gibi) kök `CLAUDE.md` de kontrol edilir.

## Parça Bitirme Kontrol Listesi (ZORUNLU — her parçanın son adımı)

Kullanıcı isteği (6 Ağustos 2026): "her tamamladığın işten sonra ilgili
dosyaları kontrol edip güncellemeyi unutma". Kural zaten vardı ama bir kez
YARIM uygulandı — parça 4'te `scripts/generate-klig-paths.mjs` (yani
`mobile/` DIŞINDA bir dosya) değiştiği hâlde yalnızca bu dosya güncellendi;
kök `CLAUDE.md`/`README.md` bayat kaldı ve `mobile/CLAUDE.md`'ye var
olmayan bir `npm run generate-klig-paths` komutu yazıldı. Ders: "dokümanı
güncelledim" yetmez, **hangi dokümanı** sorusu `git status`tan çıkar.

Commit'ten önce, sırayla:

1. **`git status --short` oku ve `mobile/` DIŞINDAKİ her dosyayı işaretle.**
   Bu parça web tarafına dokundu mu? Dokunduysa kök `CLAUDE.md` (+ gerekirse
   `README.md`) AYNI commit'te güncellenmeli — kök dosyanın kuralı bu.
   **VE — 10 Ağustos 2026'da eklendi — doküman senkronu YETMEZ, değişikliği
   `main`'e TESLİM et.** Bu madde uzun süre yalnızca dokümanı istedi; sonuç:
   `src/` altında yapılan iki gerçek web düzeltmesi (SL→k-lig ve admin sohbet
   dökümünün sıralaması) port dalında haftalarca mahsur kaldı, üretime hiç
   çıkmadı, birini kullanıcı fark etti. Port dalı `main`'e merge EDİLMEDİĞİ
   sürece buradaki hiçbir web değişikliği kullanıcıya ulaşmaz. Kullanıcıya
   GÖRÜNEN bir web düzeltmesi yaptıysan aynı gün `main` tabanlı ayrı bir PR aç
   (port altyapısını — `scripts/generate-*`, `random.ts` kancası,
   `mobile-build.yml`, `package.json` girdileri — TAŞIMA, onlar port merge'iyle
   gelmeli; `generate-*-paths.mjs`'in port sürümü Dart'a da yazdığından
   `mobile/` olmayan bir `main`'de hata verir).
   **Denetim komutu (şüphelendiğinde koş):**
   `git diff --name-status origin/main..HEAD -- . ':!mobile'`
   Ayrıntılı vaka kaydı: kök `CLAUDE.md` → "Port dalında mahsur kalan web
   düzeltmeleri".
   **12 Ağustos 2026 — port dalı `main`'e MERGE EDİLDİ ve silindi**, yani bu
   maddedeki "port dalında mahsur kalma" riski artık YOK: mobil de web de
   doğrudan `main` tabanlı dallardan gidiyor. Madde yine de duruyor, çünkü
   dersi (doküman senkronu ≠ teslim) dala özgü değil. Aynı merge'in yan
   etkisi olarak `mobile-build.yml`'in tetikleyicisi de ölü bir dala bakar
   hâle gelmişti — aynı gün `main` + PR'a çevrildi (bkz. o dosyanın başlığı).
2. **`mobile/CLAUDE.md`**: parça günlüğüne giriş (ne yapıldı, hangi web
   dosyasının portu, bilinçli eksikler, bulunan hatalar/dersler, doğrulama
   ve doğrulama SINIRI), "Klasör Yapısı" ağacına yeni dosyalar, "Sıradaki
   parçalar" satırının güncellenmesi.
3. **Yazdığın her komutun GERÇEKTEN var olduğunu doğrula** (`package.json`
   scripts) — parça 4'te bu adım atlandığı için çalışmayan bir komut
   dokümana girdi.
4. **`README.md`**: mobil ağacı/durum cümlesi hâlâ doğru mu? ("iskelet"
   gibi bir niteleme üç faz sonra bayatlamıştı.)
5. Motor dosyası değiştiyse golden vector akışı (aşağıdaki bölüm), asset
   üreticisi değiştiyse ilgili `npm run generate-*` — ikisi de opsiyonel
   değil.

## Deploy Doğrulaması (ZORUNLU — "cihazda göreceksin" demeden önce)

Kullanıcı isteği (15 Ağustos 2026): *"bu yaşanan deploy sorunlarını kalıcı
olarak çözecek bir sistem geliştir"*. O gün aynı hata İKİ KEZ tekrarlandı:
düzeltme yazıldı, testler yeşildi, kullanıcı cihazda **bayat bir derlemeyi**
test edip "düzelmemiş" dedi. Kod doğruydu; sitede yoktu.

**Kural bu projede ZATEN vardı** (Parça 19: *"bir 'deploy oldu mu?' kontrolü
teşhisin parçasıdır"*) ve yine atlandı. Bu yüzden çözüm bir kural DEĞİL, bir
MEKANİZMA: derleme kimliği artık ürünün İÇİNDE.

### Nerede ne yayınlanır

| Yüzey | Nereden yayınlanır | Ne zaman |
|---|---|---|
| `kelimeki.com` (web app) | Vercel | `main`'e her merge |
| `alpcapa.github.io/kelimeki` (Flutter test ortamı) | Actions `mobile-build.yml` → Pages | YALNIZCA `main`'e push **ve** `mobile/**` değiştiyse |
| Supabase (migration/Edge Function) | MCP ile doğrudan | Anında — dal/merge ile İLGİSİZ |

**Feature dalındaki bir commit sitede ASLA görünmez.** Bir PR açmak da
yetmez (workflow PR'da bilerek yayınlamıyor). Üçüncü satır tersine bir tuzak:
sunucu değişikliği anında canlıdır, yani istemci düzeltmesi henüz yokken
sunucu davranışı değişmiş olabilir.

### Derleme kimliği — ekran görüntüsü sorunun cevabını taşır

- **Flutter:** Setup'ın teşhis satırı `Derleme a1b2c3d · 15.08 11:42` ile
  başlıyor (`env.dart` → `buildSha`/`buildTime`, CI `--dart-define` ile
  veriyor; yerel derlemede `Derleme yerel`).
- **Web:** `<meta name="kelimeki-build">` + `window.__KELIMEKI_BUILD__`
  (`vite.config.ts`, Vercel `VERCEL_GIT_COMMIT_SHA`). Görünmez — normal
  kullanıcıya bir sha göstermenin anlamı yok; devtools/`view-source` yeter.

**Kullanıcıya bir düzeltmenin cihazda görüneceğini söylemeden önce o sha'yı
iste ya da ekran görüntüsünden oku.** Eşleşmiyorsa tartışılacak bir hata
yok — deploy bekleniyor demektir.

### Bu ortamın sınırı (kritik — buradaki tek gözlem yolu MCP)

`curl`/`bash` bu oturumdan **ne `api.github.com`'a ne siteye** çıkabiliyor
(proxy 403, token'la bile). Yani:

- Bash tabanlı bir "deploy izleyici" **sessizce ölü kalır** ve sessizlik
  "hâlâ çalışıyor" gibi görünür — 15 Ağustos'ta tam bu kuruldu ve fark
  edilmeseydi 40 dakika boş beklenecekti.
- Koşu durumu YALNIZCA GitHub MCP araçlarıyla **okunabilir**
  (`actions_list` → `list_workflow_runs`, `pull_request_read`).
- **Ama TETİKLENEMEZ (18 Ağustos 2026'da ölçüldü):** bu oturumun tokeni
  Actions'a yazamıyor — `rerun_workflow_run` ve `run_workflow` (dispatch)
  ikisi de **403 "Resource not accessible by integration"** döner. Yani
  iptal edilmiş/eksik kalmış bir koşuyu ben yeniden başlatamam; yeni bir
  koşu ancak dala GERÇEK bir commit push edilerek (`paths` filtresine takılan
  bir dosya değişerek) ya da kullanıcının Actions arayüzünden "Re-run"
  demesiyle doğar. **CI'ı kışkırtmak için boş commit ATMA** — kök
  CLAUDE.md'nin PR kuralı bunu açıkça yasaklıyor.
- **"İptal edildi" ≠ "düştü" ve bu ayrım ekran görüntüsünde GÖRÜNMEZ:**
  aynı gün kullanıcı iOS işini kırmızı ikonla görüp "iOS'da sorun var"
  dedi; koşunun tamamı **Cancelled** idi ve iOS 38 saniyede "Cache Flutter"
  adımında ölmüştü — yani hiç derlemeye başlamamıştı. Bir işin kırmızısını
  "hata" saymadan önce **koşunun `conclusion` alanına** ve o işin hangi
  ADIMDA öldüğüne bak.
- **`cancel-in-progress`i İKİ ayrı şey tetikliyor ve ikincisi sezgiye
  aykırı (18 Ağustos 2026'da ölçüldü):** (a) aynı PR'a atılan bir sonraki
  commit; (b) **ESKİ bir koşunun arayüzden "Re-run"lanması** — yeniden
  deneme AYNI concurrency grubuna (`mobile-build-refs/pull/N/merge`) girdiği
  için o an ÇALIŞAN daha yeni koşuyu iptal ediyor. O gün bu ikisi
  birbirine karıştı: ben yeni bir koşu tetiklerken kullanıcı bir öncekini
  yeniden başlattı, benim koşum saniyesi saniyesine (23:06:52) iptal oldu
  ve dışarıdan "sebepsiz iptal" gibi göründü. Bir iptali açıklarken
  koşunun `run_attempt` alanına da bak: 1'den büyükse birileri yeniden
  başlatmış demektir.
- **DÜZELTME (25 Ağustos 2026, ölçüldü): WEB yüzeyini açıp okuyabiliyorum.**
  Yukarıdaki "`curl`/`bash` siteye çıkamıyor" doğru, ama `WebFetch` ARACI
  `https://kelimeki.com`'a ulaşıyor — o gün `/.well-known/assetlinks.json`
  (henüz yayında değildi → SPA kabuğu) ve `/gizlilik/` (statik sayfa, doğru
  başlıkla) ayrı ayrı okundu, yani araç hangi sayfanın servis edildiğini
  ayırt edebiliyor. **Sınırı:** içerik küçük bir modelle markdown'a
  çevriliyor — "doğru şey mi yayında" sorusunu cevaplar, `Content-Type`/
  başlık/bayt ölçümü YAPMAZ. Bir web düzeltmesinin canlıda olduğunu
  söylemeden önce artık kullanıcıdan ekran görüntüsü beklemek yerine
  doğrudan bakılabilir. **Flutter/Pages tarafı için bu KANITLANMADI.**
- Siteyi ben açıp bakamam (yalnızca yukarıdaki istisna dışında).
  **Ekran görüntüsü tek enstrümandır** — derleme
  kimliğinin ürüne gömülmesinin asıl gerekçesi budur.

### Merge sonrası dal hijyeni (bugünün ikinci hatası)

`main` squash merge kullanıyor. Merge edilmiş bir dala yeni commit
eklemeye devam etmek, aynı işi İKİ kez var eder ve bir sonraki merge'de
çakışma üretir. 15 Ağustos'ta bunun bedeli yalnızca çakışma da olmadı:
`AdminDashboard.tsx` "auto-merging" dedi ama 126 satırlık bir bloğu
**iki kez** yazdı; `tsc` yakaladı (`TS2393`/`TS2451`).

**Her merge'den SONRA dalı sıfırla:**
`git fetch origin main && git checkout -B <dal> origin/main`

**Ve bir squash-merge çakışmasını çözerken derleyiciye güvenme:**
tekrarlanan JSX'i hiçbir şey yakalamaz. `npm run lint` + mükerrer
bildirim/kullanım taraması (`grep -c` ile her yeni bileşen "1 bildirim +
1 kullanım" mı) şart.

### "Koşu yok" demeden ÖNCE — filtre neyi eliyor? (26 Ağustos 2026)

O gün bir merge'den hemen sonra `actions_list`'e **`status: completed`**
filtresiyle bakılıp *"merge sha'sı için tek bir koşu yok"* denildi ve
buradan **yanlış bir kural uyduruldu** ("MCP token'ı Actions'ı hiç
tetiklemiyor"). Gerçek: koşu VARDI, o an `in_progress`'ti; filtre onu doğru
şekilde eliyordu. Kullanıcı ekran görüntüsüyle gösterdi.

**Kural:** bir koşunun yokluğunu iddia etmeden önce `queued` ve
`in_progress`'i de sor — ya da hiç filtre verme. Ve tetiklenme gecikmeli
olabilir: aynı gün bir `pull_request` koşusu push'tan ~20 dakika sonra
başladı, yani "iki dakika sonra baktım, yoktu" hiçbir şey kanıtlamaz.

**Asıl ders bu dosyanın kendisiyle ilgili:** bir gözlemden kural
ÇIKARIRKEN, gözlemin kendisinin bir filtreden geçip geçmediğine bak.
Buraya yazılan yanlış bir kural, hiç yazılmamış olmasından daha zararlı —
sonraki oturum onu ölçüm sanır.

### PR'da CI koşmazsa

MCP ile açılan PR'larda GitHub `pull_request` iş akışını tetiklemeyebiliyor
(15 Ağustos, PR #266: tek bir `mobile-build` koşusu oluşmadı). O durumda
merge etmeden önce native derlemeyi doğrulamak için Actions → Run workflow
→ dal seç → **`web: false`** (yalnızca derler, paylaşılan siteyi
DEĞİŞTİRMEZ). Yeni bir platform eklentisi eklenmediyse bu adım atlanabilir,
ama atlandığı commit'te bunu açıkça söyle.

**PR #267'de CI koştu ve İLK denemede Android'i düşürdü — kaydı önemli:**
`--dart-define=BUILD_TIME=${{ ... }}` TIRNAKSIZDI ve değer boşluk taşıyor
(`15.08 11:58`); kabuk onu ikiye bölüp ikinci parçayı hedef dosya sandı
(`Target file "11:58" not found.`, 32 saniyede düştü). **Yerelde
görünmüyordu:** `flutter test` bu define'ları hiç kullanmıyor ve ben
YAML'ı yalnızca PyYAML ile ayrıştırıp "adım var" diye doğrulamıştım —
derleme komutunu koşmamıştım. Düzeltme sekiz satırda argümanı tırnağa
almak; **negatif eş yerelde kuruldu** (`flutter build web` ile önce hata
birebir üretildi, sonra tırnaklı hâlin derlendiği VE iki sabitin de
`main.dart.js`'e gömüldüğü ölçüldü — `buildLabel` çalışma anında
hesaplandığından birleşik dize aranmaz, iki sabit ayrı ayrı aranır).
**Ders: bir workflow adımının YAML'ı geçerli olması, ürettiği KABUK
SATIRININ doğru olduğunu kanıtlamaz** — değeri boşluk/özel karakter
taşıyabilen her `--dart-define`/argüman tırnaklanmalı ve mümkünse o
komut yerelde bir kez gerçekten koşturulmalı.

## Sorun Bildirildiğinde İLK ADIM: "web'de bu nasıl yapılmış?"

Kullanıcı kararı (9 Ağustos 2026, sözleri birebir): *"Bizim webde çalışan
bir uygulamamız var ve bunun aynısını mobile app'e geçiriyoruz. App için
bir şey yapacağın zaman her zaman ilk önce web'deki uygulamaya bakıp, onu
app'e uygulamaya çalışman lazım. Sorun bildirdiğim zaman yine dönüp bunu
web'de nasıl yapmışız diye inceleyip ondan sonra harekete geçmen lazım.
Sürekli yama yapıp geri alman kabul edilemez."*

Aşağıdaki "Etki Analizi" bölümü bu kuralı zaten içeriyordu ama YALNIZCA
yeni parça yazarken uygulanıyordu. **Kural hata triyajı için de, hatta
ÖNCELİKLE onun için geçerli:** bir hata/görsel fark bildirildiğinde ilk
eylem Flutter tarafını kurcalamak DEĞİL, `src/`'deki karşılığını (bileşen,
sarmalayıcı zinciri, sınıflar, kararlar) okumaktır. Ancak ondan sonra
"port bunu nerede farklı yapmış?" sorusu sorulur.

**Bu kuralın atlanmasının somut bedeli — tek bir düzen sorusu, dört tur:**

| Parça | Yapılan | Sonuç |
|---|---|---|
| 16 | Tahta/mesaj arasına 56px boşluk eklendi (yama) | Parça 39'da geri alındı |
| 17 | `max-w-[680px]`in hiç uygulanmadığı bulundu | Gerçek düzeltme |
| 39 | Kaydırmada kesilen gölge için eksen-kırpıcı yazıldı (yama) | Parça 40'ta geri alındı |
| 40 | `App.tsx`'in düzeni OKUNDU: 680 her bölümün kendi üzerinde | 5 dakikalık gerçek düzeltme |

16 ve 39'un ikisi de semptomu bastıran, sonradan geri alınan yamalardı.
`App.tsx`'in sarmalayıcı zincirini bir kez okumak ilk turda bitirirdi.

**Pratikte:**

1. Bildirilen davranışın web'deki dosyasını aç ve OKU (yalnızca değerleri
   değil: sarmalayıcı zinciri, hangi kap neyi sınırlıyor, ne kırpıyor, ne
   akıyor). Gerekirse `npm run build` + Chromium ile ÖLÇ.
2. Portta o yapının karşılığını bul; fark yapısal mı, değer mi?
3. Ancak bundan sonra kod yaz. **Yapısal farkı değer/boşluk/kırpma
   ayarıyla kapatmaya çalışma** — bu projede üç kez denendi, üçünde de
   geri alındı.
4. Ölçüm yaparken İZOLE widget'ı değil GERÇEK ekranı ölç — Parça 40'ta
   izole ölçüm "fark yok" deyip beni yanlış sonuca götürdü (bkz. o
   parçanın notu).

## Etki Analizi (ZORUNLU — her parçanın İLK adımı)

Bu, kök `CLAUDE.md`'deki **"Çalışma İlkesi: Önce Etki Analizi, Sonra
Doküman Senkronu"** kuralının porta özgü sürümüdür — kural projenin
TAMAMI için geçerli (web/backend/mobil); burada yalnızca Dart tarafının
kendi değişmezleri somutlaştırılıyor. Kök tablodaki "mobile/ DIŞINDA bir
dosya" satırı bu iki dosyayı birbirine bağlar.

Kullanıcı isteği (6 Ağustos 2026): "yapılacak her geliştirmenin etkilemesi
muhtemel yerleri iyi analiz etmek gerekiyor". Gerekçe: bu projede dalgaların
büyük kısmı **derleyicinin ve testlerin göremediği** türden — imza
değişikliğini `dart analyze` yakalar, ama web↔mobil paritesinin sessizce
ayrışmasını, Türkçe dil kuralının tek bir dosyada unutulmasını ya da bir
değişmezin (kuyruk/determinizm) delinmesini hiçbir şey yakalamaz.

**Yazmaya başlamadan önce** şu üç soruyu cevapla:

1. **Bu kodun web'de bir KAYNAĞI var mı?** Varsa portun kendisi kadar,
   web'in o dosyaya bağlı KARARLARI da taşınmalı (ör. `player_stats` vs
   `player_stats_overall` ayrımı bir tercih değil, web'in yazılı
   gerekçesi). Kaynağı okumadan port yazma.
2. **Değiştirdiğim şeyi kim OKUYOR?** Yalnızca çağıranlar değil: aynı
   tabloya yazan öteki istemci (web!), aynı JSON'u ayrıştıran öteki taraf,
   aynı fixture'a bakan testler, aynı üreticiden beslenen ikinci dosya.
3. **Hangi görünmez değişmeze dokunuyorum?** Aşağıdaki tarama tek komutluk;
   şüphelendiğinde koş, yeni bir değişmez eklediğinde listeye ekle.

```bash
cd mobile
grep -rn "toUpperCase()\|toLowerCase()" app/lib/            # Türkçe: trUpper/trLower şart
grep -rn "\.sort(" app/lib/ kelimeki_core/lib/ | grep -v trCompare  # metin sıralaması → trCompare
grep -rn "DateTime.now()\|Random()" kelimeki_core/lib/      # core determinizmi (yalnız SystemRng meşru)
grep -rn "local_game_saves" app/lib/                        # yalnız cloud_save_repo (TableWriteQueue)
grep -rln "\.from('" app/lib/                               # Supabase yalnız veri katmanında
grep -rn "await newRepo(" app/test/*_test.dart              # testWidgets İÇİNDE çıkarsa newRepoForWidget'a çevir (runAsync)
grep -rn "Path.combine\|PathOperation" app/lib/             # CanvasKit'te PathOps GÜVENİLMEZ (bkz. Parça 18) — evenOdd kullan
grep -rn "Color(0xFF" app/lib/src/ui/ | grep -v tokens.dart # renk paleti TEK kaynaktan: ui/tokens.dart (bkz. Parça 54)
grep -rn "MaskFilter" app/lib/ --include=*.dart -l | grep -v neo_box  # gölge çizimi TEK yerden (bkz. Parça 144)
```

Sonuncusu bir PERFORMANS değişmezi, görsel değil: keyfi bir `Path` üzerine
uygulanan `MaskFilter.blur`un analitik hızlı yolu YOK — her çağrı offscreen
doku + gerçek gauss geçişi demek. Tahtanın 169 hücresi bu yüzden kare başına
~340 blur ediyordu ve cihazda oyun ekranının TAMAMI ağır çekimdi. `neo_box.dart`
artık her deseni bir kez rasterleştirip önbellekten basıyor; gölgeyi başka bir
dosyada elle çizmek o önbelleği baypas eder. Yeni bir gölgeli yüzey gerekiyorsa
`NeoBox` / `ShapeDecorationWithCssShadows` üzerinden geç.

Sonuncusunun otomatik hâli `test/color_tokens_test.dart` — elle grep'lemene
gerek yok, tam takım koşarken zaten kontrol ediliyor (hem `tokens.dart` ↔
`tailwind.config.js` eşitliği hem "yerel kopya açılmış mı" taraması).

**Son tam tarama: 8 Ağustos 2026 (Parça 23, sürükleme performans düzeltmesi)
— yedisi de temiz.** İlk tam tarama 6 Ağustos'taydı; o turda bulunan TEK gerçek ihlal
(`score_stats_section`'daki `toUpperCase` → "BIRINCILIK") parça 4'te
düzeltilmişti. Değişmez listesi kapsamlı DEĞİL — derleyicinin göremediği
yeni bir kural eklediğinde (ör. yeni bir üretilmiş dosya, yeni bir "tek
kaynaktan" kuralı) buraya bir satır da ekle, aksi halde bir sonraki oturum
onu bilmez.

**Grep'e girmeyen ama aynı sınıftan bir değişmez — İKİ oyun ekranı aynı
deseni paylaşıyor:** `ui/game/game_screen.dart` (yerel/YZ) ve
`ui/live/online_game_screen.dart` (Canlı) sürükle-bırak katmanını, joker
akışını ve mesaj satırı kuralını BİLİNÇLİ olarak ayrı ayrı taşıyor — web'in
App.tsx ↔ OnlineGameScreen.tsx ayrımının birebir eşleniği (kök CLAUDE.md o
ikisi için de "ikisi deseni paylaşıyor, biri değişirse diğeri de" diyor).
Bu dosyalardan birinde sürükleme/joker/mesaj davranışı değişirse ÖTEKİ de
aynı PR'da güncellenmeli; hiçbir derleyici/test bunu yakalamaz.

**Grep'e giren ama testlerin ASLA yakalayamayacağı bir değişmez — özel
`Canvas` çizimi iki motorda ayrışabilir:** `flutter test` native Skia ile
render eder, web derlemesi ise CanvasKit ile — ikisi her zaman aynı sonucu
vermez. 8 Ağustos 2026'da `Path.combine(PathOperation.difference, ...)`
CanvasKit'te `MaskFilter.blur` ile birlikte deliği kaybedip tüm hücreyi düz
doldururken native Skia'da kusursuz çalışıyordu (Parça 18) — "246/246 yeşil"
bu konuda hiçbir şey kanıtlamadı. Kural: `CustomPainter`/`Decoration` içinde
PathOps (`Path.combine`) KULLANMA, deliği `PathFillType.evenOdd` ile ifade
et. Yeni bir özel çizim eklerken (ya da böyle bir render şüphesi doğduğunda)
tarayıcıda ölç — bu ortamda yapılabilir:
`flutter build web --release --target=lib/<minik_harness>.dart
--output=build/webprobe` → `python3 -m http.server` → Playwright/Chromium
(`/opt/pw-browsers/chromium-1194/chrome-linux/chrome`, `--use-angle=swiftshader`).
Tüm uygulamayı boot etmeye çalışma (sözlük/Supabase açılışta asılı kalıyor),
yalnızca şüpheli widget'ı render eden bir harness derle; harness'i ve
`build/webprobe`'u iş bitince sil.

## Parça Bitirme Kontrol Listesi (ZORUNLU — her parçanın son adımı)

0. **Cihazda doğrulanması gereken bir şey eklediysen `mobile/TESTING.md`'ye
   yaz.** `flutter test` veri katmanını SAHTE uçlarla sınıyor — "testler
   yeşil" ile "sunucuyla gerçekten konuşuyor" arasındaki boşluk oradaki
   listeyle kapanıyor. Bir parçanın "Doğrulama sınırı" notu yazıldıysa,
   karşılığı bir kontrol maddesi olarak o dosyada da olmalı; aksi halde
   borç yalnızca bu dosyanın içinde kaybolur (kök `TESTING.md` ile aynı
   refleks).

1. **Oyun kurallarının tek doğruluk kaynağı ŞİMDİLİK web'deki TypeScript
   motoru** (`src/game` + `src/utils`). Dart portu (`mobile/kelimeki_core`)
   birebir davranış kopyasıdır ve eşitlik **golden vector** fixture'larıyla
   (aşağıda) otomatik kanıtlanır. Kullanıcı web'in geleceği konusunda "emin
   değilim" dedi — web ileride Flutter Web'e geçerse kanonik taraf Dart'a
   çevrilebilir; golden vector altyapısı bu geçişi güvenli kılmak için de var.
2. **Backend değişiklikleri onaylandı ve UYGULANDI (5 Ağustos 2026)** —
   ayrıntı aşağıdaki "Backend Hazırlığı" bölümünde: (a) `submit_move`'a
   istemci üretimli hamle UUID'si (`p_move_id`); (b) `app_config` tablosu +
   `mobile_min_supported_version` kaydı.
3. **Admin paneli mobil uygulamaya GİRMEYECEK** — web'de kalıyor. Bu,
   `api.ts`'in büyük bir bölümünün hiç port edilmemesi demek.
4. **Kelime anlamları (`meanings.json`, 6.3 MB) uygulamaya GÖMÜLECEK** —
   kullanıcı boyutu sorun etmedi; sıkıştırılmış ~1.5-2 MB. Sunucudan çekme /
   sonradan indirme seçenekleri konuşuldu ve elendi (offline + anında açılış).
   **6 Ağustos 2026'da BİÇİM netleşti — JSON değil SQLite (kullanıcı onayı):**
   web JSON'u fetch edip TAMAMINI RAM'de tutuyor; mobilde bu 6.5 MB'lık bir
   parse gecikmesi + onlarca MB kalıcı bellek demekti. Asset build-time'da
   tek tablolu bir SQLite'a çevriliyor (`npm run generate-meanings-db` →
   `mobile/app/assets/dictionary/meanings.db`, 63.896 kelime, **5.26 MB ham
   / ~2.0 MB gzip** — ölçüldü), uygulama sorgu anında TEK SATIR okuyor:
   açılış maliyeti sıfır, bellek maliyeti sıfıra yakın. Auth fazı gelince
   web'in iki yollu sırası kurulabilir (önce Supabase `word_meaning` RPC,
   hata/offline'da bu yerel db) — bugünkü iş yedek katmana dönüşür, çöpe
   gitmez.
5. **State yönetimi: ek framework YOK** (Riverpod/Bloc yok) — motor zaten bir
   reducer; uygulama katmanı ince bir `ChangeNotifier` kabuğu olacak.
6. **Sözlük: düz `HashSet<String>`** — mevcut YZ algoritması prefix araması
   yapmıyor (havuz taraması + `canSpell`), trie/DAWG ancak YZ yeniden
   yazılırsa anlam kazanır. `WordSource` arayüzü o kapıyı açık bırakır.
   Tahmini bellek ~4-6 MB, soğuk açılışta bir kez yüklenir.


## Karar Kayıtları (`mobile/docs/`) — geçmiş, arşivlenmiş

Bu dosya artık **yaşayan bir indeks** — port mimarisi, klasör yapısı ve
ZORUNLU süreç kuralları (Etki Analizi, Deploy Doğrulaması, Parça Bitirme
Kontrol Listesi, Golden Vector İş Akışı) burada kalır. Tarihli "Parça N"
build/karar günlüğü — bu dosyanın eskiden YARIDAN FAZLASINI oluşturan
`## Web ↔ Uygulama Arasındaki Kabul Edilmiş Farklar` bölümü VE onun
`## Sıradaki Fazlar`ın altında (aynı Parça numaralandırmasıyla) süren
devamı dahil — **`mobile/docs/*.md`** altına taşındı (24 Ağustos 2026,
context split; bkz. kök `CLAUDE.md`'deki aynı işlemin gerekçesi — "Karar
Kayıtları" bölümü).

**Bir "Parça N" atfı ararken** (kod yorumlarında/CLAUDE.md içinde geçen
"bkz. mobile/CLAUDE.md, Parça N" gibi) günlük ÜÇ CİLDE ayrıldı — numaraya
göre doğru cilde git:

| Parça | Cilt |
|---|---|
| 1-48 | `mobile/docs/parca-log-1-48.md` (dondurulmuş) |
| 49-109 | `mobile/docs/parca-log-49-109.md` (dondurulmuş) |
| 110-138 | `mobile/docs/parca-log-110-138.md` (dondurulmuş — 26 Ağustos 2026) |
| **139+** | `mobile/docs/parca-log.md` — **AKTİF, yeni girişler buraya** |

⚠ **Bir cildi baştan sona OKUMA — `grep` ile ara.** Ciltler tam bu yüzden
var: tek dosya 714 KB'a çıkmıştı ve bir atıf için onu okumak bağlamın üçte
birini yakıyordu (24 Ağustos 2026; gerekçe aktif cildin başlığında).
Bütçeyi `npm run check-doc-size` ölçüyor, sınıra gelince yeni cilt açılır.

| Konu | Dosya |
|---|---|
| Backend hazırlığı (submit_move idempotency, 5 Ağustos 2026) + Depolama katmanı + Flutter iskeleti + uygulama ikonu/splash + MembershipPerksBox | `mobile/docs/setup-log.md` |
| Web derlemesi (test ortamı), Appetize, Play Store imzalama/.aab, karşılama katmanının web'e özgü ayrışması | `mobile/docs/build-and-distribution-log.md` |
| **Web ↔ Uygulama Arasındaki Kabul Edilmiş Farklar — Parça günlüğü** (DÖRT cilt, yukarıdaki tabloya bak) | `mobile/docs/parca-log.md` + `-110-138` + `-49-109` + `-1-48` |
| FAZ A1 — cihaz testi tur durumu | `mobile/docs/cihaz-testi-log.md` |
| Cihaz testi — Arkadaşlar + Canlı oyun bölümleri (iki gerçek oturum ister) | `mobile/docs/testing-arkadaslar-canli.md` |

**Yeni bir "Parça N" notu eklerken:** parça numarasını bir öncekinin devamı
olarak ver ve **AKTİF cilde** (`mobile/docs/parca-log.md`) yaz — dondurulmuş
ciltlere ASLA (`check-doc-size` bunu yakalar). Aktif ciltte girişler en yeni
EN ÜSTTE duruyor, yenisini oraya ekle. Eğer not HER PARÇAYI ilgilendiren bir süreç kuralıysa (ör.
"her yeni ekranda bu kontrolü de yap" gibi) o zaman bu dosyadaki ZORUNLU
bölümlerden birine (Etki Analizi / Parça Bitirme Kontrol Listesi) eklenmeli,
tek bir parçanın notuna değil.

## Klasör Yapısı

```
mobile/
  CLAUDE.md                  # bu dosya
  app/                       # Flutter uygulaması (iskelet — aşağıdaki bölüm)
    pubspec.yaml             # kelimeki_core (path) + supabase_flutter +
                             # sqflite/shared_preferences + share_plus/
                             # path_provider (paylaşım, 5c — DİKKAT: 13
                             # Ağustos 2026'dan beri `lib/` altında
                             # path_provider importu YOK, ama SİLME:
                             # native'de geçici paylaşım dosyasını
                             # share_plus onunla yazıyor, bkz. Parça 84)
                             # + app_links
                             # (davet deep link'i, parça 8) +
                             # sqflite_common_ffi_web (YALNIZCA web test
                             # ortamı — koşullu import'un arkasında, mobil
                             # derleme onu hiç görmez; bkz. "Web Derlemesi")
    web/                     # Flutter web iskeleti (TEST ORTAMI, ürün değil).
                             # sqflite_sw.js + sqlite3.wasm ÜRETİLMİŞ
                             # (`dart run sqflite_common_ffi_web:setup`) ama
                             # derlemede ağa çıkılmasın diye repoda tutulur.
    assets/icon/             # ÜRETİLMİŞ (elle düzenlenmez) — kaynak
                             # public/icon.svg (web), `node
                             # mobile/scripts/generate-app-icon-masters.mjs`
                             # yeniden üretir. iOS AppIcon/Android mipmap-*/
                             # splash'in ARA kaynağı — bkz. "Uygulama İkonu
                             # / Splash".
    assets/dictionary/words_tr.txt
                             # ÜRETİLMİŞ (elle düzenlenmez) — kaynak
                             # src/data/words.ts; `npm run generate-golden-vectors`
                             # yeniden üretir. SIRA words.ts'teki WORD_LIST
                             # sırasıdır ve DEĞİŞMEZ SÖZLEŞMEDİR (aşağı bkz.).
                             # Uygulama paketinin İÇİNDE, çünkü Flutter paket
                             # kökü dışından asset kabul etmez — kelimeki_core
                             # testleri de TEK kopya kalsın diye buradan okur.
    assets/fonts/            # Space Grotesk / Space Mono / Nunito (web'le aynı
                             # aileler) + MPLUSRounded1c-ExtraBold-subset.ttf:
                             # ÜRETİLMİŞ alt küme, YALNIZCA rütbe rozetinin
                             # harfi; web'in src/fonts/files/ kopyasıyla aynı
                             # subset (yeni bir kademe harfi eklenirse ikisi de
                             # yeniden üretilmeli — bkz. Parça 114)
    lib/main.dart            # portre kilidi + bootstrap + runApp
    lib/src/
      bootstrap.dart         # AppServices: sözlük Future'ı + supabase + sürüm kapısı
      config/env.dart        # --dart-define SUPABASE_URL/ANON_KEY; appVersion sabiti
      config/version_gate.dart # app_config.mobile_min_supported_version kontrolü (fail-open)
      data/dictionary_loader.dart # rootBundle + Isolate.run → SetWordSource
      data/supabase_client.dart   # anahtar yoksa null → tam offline mod (web'deki configured)
      data/online_api.dart   # submit_move sarmalayıcısı: p_move_id UUID + retry
      data/online_games_api.dart # Canlı oyun davet/kabul: list_my_online_games/
                             # create/respond RPC'leri + sıra/son-tarih +
                             # "hafif süpürme" + Realtime aboneliği + kova
                             # filtreleri/süre etiketleri (saf fonksiyonlar)
      data/cloud_save_repo.dart   # local_game_saves senkronu (girişli YZ oyunları)
      data/game_record.dart  # buildGameRecord portu (`games` satırı)
      data/games_api.dart    # games/game_finishes + dayanıklı kuyruk/flush +
                             # beğeni (toggle/stats/likers/list_liked_games) +
                             # dondurulmuş sohbet (messages/chat_flags)
      data/stats_api.dart    # player_stats / leaderboard / my_leaderboard_rank
      data/league_rewards_api.dart # k-lig ödül/rütbe kayıtları (league_rewards
                             # + mark_league_rewards_seen) — kutlama banner'ı
      data/feedback_api.dart # Görüş Bildir: submit + kuyruk + flush + rate limit
      data/friends_api.dart  # arkadaşlık RPC'leri + davet linki üretimi/çözümü
      data/friend_invite_inbox.dart # gelen davet linkleri → pending_events
      data/chat_api.dart     # Canlı oyun sohbeti + sessize alma/raporlama
                             # (ChatRepo/ChatGateway) — yalnız Canlı oyunlar
      game/game_controller.dart # ChangeNotifier motor kabuğu + otomatik YZ turu
      storage/               # SQLite + prefs katmanı (bkz. "Depolama Katmanı"):
                             # app_database (şema), app_storage (giriş kapısı),
                             # local_save_store (karantinalı kayıt), pending_queue_store,
                             # pending_event_store, chat_read_store, flags_store
      ui/                    # app.dart, update_required_screen.dart,
                             # theme.dart (ÜRÜNÜN TEK teması — testler de
                             # `kelimekiTheme()` kullanır; M3'ün varsayılan
                             # harf aralığını sıfırlar, bkz. Parça 78),
                             # form_input.dart (TÜM giriş alanlarının tek
                             # dekorasyonu/metin stili, bkz. Parça 79),
                             # tap_target.dart (48 dp dokunma hedefi
                             # asgarisi — kMinTapTarget + TapTarget, bkz.
                             # Parça 134), loading_note.dart (ortak
                             # "Yükleniyor…" göstergesi; web
                             # LoadingNote.tsx ile birebir), ve:
      ui/auth/               # giriş-kayıt-şifremi-unuttum modalı, hesap
                             # butonu, avatar, Terms/Privacy,
                             # reset_password_modal (recovery kapısı),
                             # delete_account_modal.dart (uygulama içinden
                             # hesap silme — ROADMAP madde 2, mağaza
                             # blokeri; bkz. docs/decisions/account-deletion.md)
      ui/intro/              # intro_screen.dart — İLK AÇILIŞ tanıtımı
                             # (Parça 116/117/118): 4 sayfalık PageView,
                             # Setup'ın ÖNÜNDE; ATLAMA YOK, tek çıkış son
                             # sayfadaki "HEMEN OYNA". Tekrar açma yolu
                             # Setup'ın logo altı link satırı ("Tanıtım",
                             # yalnız misafir); kapısı app.dart'taki
                             # _HomeGate, bayrağı FlagsStore.seenIntro.
                             # Metinler web'in karşılama katmanından
                             # (Landing.tsx) BİREBİR — web metni değişirse
                             # buraya elle taşınmalı (bunu zorlayan bir test
                             # YOK). Yanındaki iki dosya:
                             #   demo_board_data.dart — ÜRETİLMİŞ (kaynak
                             #     src/landing/demoBoard.ts, DEMO_TILES_2
                             #     + DEMO_TILES_4;
                             #     npm run generate-demo-board-dart)
                             #   ozellik_ikonlari.dart — "Neler var" altı
                             #     özellik ikonu; web'in OzellikIkonlari.tsx'i
                             #     ile ELLE senkron (Material DEĞİL, ilkel
                             #     şekiller — Icons.* iki platformda FARKLI
                             #     vektör demek olurdu)
      ui/game/               # tahta/raf/header/modaller (oyun ekranının
                             # tamamı) + PAYLAŞILAN küçük parçalar:
                             # modal_shell (KModal — başlıklı 360px pencere),
                             # dialog_shell (KDialogCard — 384px onay/uyarı
                             # kartı; İKİSİ AYRI, web'de de öyle),
                             # neo_box/neo_button, player_badge,
                             # player_avatar_row, action_sheet, count_badge
      ui/score/              # skor kartı, k-lig, oyuncu kartı, oyun geçmişi,
                             # score_box_row (paylaşılan görselin üst şeridi)
      ui/rank/               # k-lig rütbe/ödül katmanı (Parça 61-62):
                             # rank_scores (isim yanındaki mührün puan
                             # kaynağı — leaderboard view'ı, toplu),
                             # league_rank (9 kademelik eşik/ödül tablosu —
                             # SQL ve leagueRank.ts ile ELLE senkron, ÜÇ
                             # kopya!), rank_seal (roset CustomPainter),
                             # rank_header_seal (skor kartlarının başlık
                             # mührü), rank_progress_bar (PAYLAŞILAN çubuk +
                             # RewardBadge), reward_banner (kutlama/düşüş),
                             # rank_info_modal, league_rewards_host (yığın:
                             # yalnızca EN ÜSTTEKİ ekranın host'u çalışır)
      ui/chat/               # chat_thread (paylaşılan baloncuk listesi —
                             # arşiv VE canlı sohbet ikisi de kullanır) +
                             # game_chat_history_modal (bitmiş oyunun arşivi) +
                             # chat_modal (Canlı sohbet penceresi) +
                             # chat_settings_modal (sessize alma/raporlama)
      ui/setup/              # kurulum ekranı (yeni oyun / devam edenler) +
                             # recent_games_section ("Son Oynadıklarım") +
                             # membership_perks_box (misafir "Neden Üye
                             # Olmalıyım?" kutusu, 7 Ağustos 2026)
      ui/feedback/           # feedback_modal ("Görüş Bildir" formu)
      ui/friends/            # friends_modal (3 sekme + davet paylaşımı +
                             # paylaşılan onay/sonuç diyalogları) +
                             # friend_moderation_sheet (satırdaki 🚫/🚩
                             # ikonundan açılan GERİ ALMA paneli)
      ui/live/               # Canlı oyun: live_games_tab (3 alt sekme +
                             # kartlar), live_game_create_form,
                             # friend_suggest_modal (kabul sonrası öneri),
                             # online_game_screen (TAHTA — game_screen.dart
                             # ile sürükleme/joker/mesaj desenini PAYLAŞIR,
                             # biri değişirse öteki de güncellenmeli)
      util/semver.dart, util/uuid.dart, util/share_board.dart,
      util/platform.dart      # bu istemcinin platformu (ios/android/app-web) —
                             # telemetri; web `src/utils/platform.ts` karşılığı,
                             # değer kümesi sunucu kısıtıyla ELLE senkron
    util/avatar_picker.dart # profil fotoğrafı seçimi (image_picker sarmalayıcısı,
                             # yalnızca galeri) — enjekte edilebilir PickAvatarFn
    android/ ios/            # flutter create çıktısı + elle değişiklikler (aşağı bkz.)
    test/                    # util, controller (golden replay!), widget duman testleri
  kelimeki_core/             # saf Dart motor paketi (Flutter bağımlılığı YOK)
    pubspec.yaml             # SIFIR bağımlılık (bilinçli — offline pub get)
    lib/kelimeki_core.dart   # tek barrel export = genel API
    lib/src/
      constants.dart         # SIZE/CORNER/köşe geometrisi (constants.ts)
      model/                 # Tile/Player/GameState/HistoryEntry + enum'lar
      actions.dart           # sealed GameAction sınıfları (Action union'ı)
      engine/reducer.dart    # GameEngine.reduce (gameReducer.ts) + createInitialState
      engine/bag.dart        # buildBag/drawTiles/remainingTiles (bag.ts)
      rules/board.dart       # kelime çıkarımı (board.ts)
      rules/validator.dart   # doğrulama+bölge+vergi+puanlama (validator.ts)
      rules/ranking.dart     # rankPlayers (ranking.ts)
      rules/league_points.dart # leaguePoints/computeRanks (leaguePoints.ts)
      ai/find_move.dart      # findAIMove (ai.ts)
      data/tiles.dart        # 100 taşlık dağılım (tiles.ts)
      text/turkish.dart      # trLower/trUpper/trCompare (turkish.ts)
      dictionary/word_source.dart # WordSource arayüzü + SetWordSource
      online/online_state.dart    # OnlineGameStatePublic (snake_case fromJson)
      serialize/codec.dart   # GameState JSON codec'i (kanonik biçim)
      serialize/board_snapshot.dart # games.board_snapshot (boardSnapshot.ts)
      rng.dart               # Rng arayüzü, SystemRng, Mulberry32, shuffleList
    test/
      run_all.dart           # TÜM testler: `dart run test/run_all.dart`
      support/               # mini test çatısı, action decoder, json diff
      goldens/*.json         # ÜRETİLMİŞ fixture'lar (elle düzenlenmez)
```

Henüz OLMAYANLAR (sıradaki fazlar): Setup'taki "Arkadaşınla (N)" rozeti +
girişte Canlı sekmesi varsayılanı, "Arkadaşınla paylaş" butonu, Hesap
Ayarları ekranı (ayrıntı: "Sıradaki parçalar" satırı, auth+Canlı fazının
sonunda).

## Porta Taşınan Değişmezler (PORT_BRIEF §7, 6 Ağustos 2026)

Web'de 5 Ağustos'ta bulunan iki hatadan (#224) PORT_BRIEF §7'ye "kodu değil
değişmezi taşı" notuyla eklenen (#225) iki kural, iskelete BİRER PRİMİTİF
olarak kondu — sonraki fazlar bunları kullanmak ZORUNDA, kural yorum satırı
değil kod:

- **`data/write_queue.dart` — `TableWriteQueue`:** satır sahibi tablo başına
  tek serileşmiş yazma yolu; okuma, bekleyen yazmalar çözülmeden yapılmaz
  (`read`/`idle`). Web'deki `local_game_saves` DELETE→SELECT yarışının
  (silinen YZ kaydının listede yeniden belirmesi) Dart eşleniği önlemi —
  yarış React'e özgü değil, aynı şemaya giden her istemci üretir. Depolama/
  senkron fazında `local_game_saves`e (ve satır sahibi her yeni tabloya)
  giden TÜM erişim bu kuyruktan geçecek; kuyruğu atlayan tek çağrı yarışı
  geri getirir.
- **`auth/account_scope.dart` — `AccountScope`:** oturuma bağlı state'in
  hesap değişiminde sıfırlanması TEK yerden, `user.id` karşılaştırmasıyla.
  `supabase_flutter`'ın `onAuthStateChange`'i `tokenRefreshed`'i saatte bir
  TAZE User nesnesiyle yayınlar — nesne kimliğine bakan karar web'deki
  hatayı aynen üretir. İlk olay sıfırlama sayılmaz (web'deki "mount yolunu
  dokunulmamış bırak" inceliği). Auth fazında dinleyici her olayda yalnızca
  `onAuthEvent(user?.id)` çağıracak; oturumu aşan ömürlü her controller
  sıfırlamasını `registerReset` ile buraya kaydedecek.

İkisi de `test/invariants_test.dart`'ta test edildi — DELETE/SELECT yarışı
minyatürü (kuyruksuz okuma bayat görür, kuyruklu görmez), hata kuyruğu
kilitlemez, tokenRefreshed no-op'u, çıkış/ikinci-hesap sıfırlaması.

## kelimeki_core — Tasarım Sözleşmeleri

Bunlar "tercih" değil, golden vector paritesinin dayandığı DEĞİŞMEZLER:

- **Sıfır bağımlılık, saf Dart.** Flutter/dart:io/dart:ui/ağ yok. Sözlük
  `WordSource`, rastgelelik `Rng`, saat `GameEngine.nowIso` olarak enjekte
  edilir. Motor içinde `Random()`/`DateTime.now()` ASLA çağrılmaz — çağrılırsa
  replay determinizmi (ve testler) kırılır. `dart pub get` ağa çıkmadan
  çalışır; testler `package:test` yerine düz `dart run` betiği (bu ortamda
  pub.dev erişimi garantisi olmadığından bilinçli).
- **Ekleme sırası anlamlıdır.** TS tarafında JS nesne/Set ekleme sırası şu
  davranışları belirler ve Dart'ta LinkedHashMap/LinkedHashSet ile birebir
  korunur: `placed` map'inin sırası (ana kelimenin başlangıç hücresi),
  `computeInvasionSplit`'teki dokunulan-bölge sırası (vergi satırlarının
  `moveHistory` sırası), YZ kelime havuzunun sırası (eş puanlı hamlelerde
  "ilk bulunan kazanır"). **`words_tr.txt`'nin satır sırası bu yüzden
  sözleşmedir** — alfabetik yeniden sıralamak YZ'nin hamle seçimini değiştirir.
- **Kararlı sıralama.** JS `Array.sort` kararlı, Dart `List.sort` DEĞİL —
  `rankPlayers`/`computeRanks` indeks tie-break'iyle kararlılığı elle kurar.
  Yeni bir sıralama port ederken aynı tuzağa dikkat.
- **Kanonik JSON.** `Tile`/`HistoryEntry`/`GameState` toJson, TS'in opsiyonel
  alanlarını yalnızca doluyken yazar (`wild` yalnız true iken, `owner` yalnız
  atanmışken…). Golden vector derin karşılaştırması bu biçime dayanır;
  `serialize/codec.dart` ile üreticinin (`generate-golden-vectors.ts`)
  `serState`'i birlikte değişmek zorunda.
- **"Parse, don't validate."** `gameStateFromJson` ya tamamen geçerli bir
  `GameState` üretir ya fırlatır — Dart'ın null safety'siyle yarım/bozuk bir
  state TEMSİL EDİLEMEZ. Web'deki `ErrorBoundary`+bozuk localStorage sınıfı
  hatanın mobil karşılığı bu katmanda imkânsızlaştırılıyor; depolama katmanı
  (gelecek faz) fırlatmayı yakalayıp kaydı SİLMEDEN karantinaya alacak.
- **Türkçe mesaj metinleri motorun parçasıdır.** Reducer'ın kullanıcıya
  görünen tüm mesajları web ile birebir aynıdır ve testler mesajları da
  karşılaştırır. Metin değişikliği = önce TS'te değiştir, vektörleri yeniden
  üret, Dart'ı uydur.
- **`Mulberry32` yalnız test/replay içindir** ve 64-bit int maskeleriyle JS
  bit desenini taklit eder — Dart VM'de doğru, **dart2js'te YANLIŞ çalışır**
  (JS number semantiği). Üretim `SystemRng` kullanır; web'e dart2js ile motor
  taşınacaksa (karar 1'in ileri senaryosu) bu sınıf yeniden ele alınmalı.
- **`invasionShare(basePts, n)`** TS'te iki yerde inline tekrarlanan formülün
  Dart'taki TEK karşılığıdır (validator + YZ) — üçüncü bir kopya açma.

## Golden Vector İş Akışı — motor değişikliklerinin zorunlu adımı

Amaç: TS motoru ile Dart motoru arasındaki HERHANGİ bir davranış ayrışmasını
otomatik yakalamak. Mekanizma: `scripts/generate-golden-vectors.ts` web'in
ÜRETİM kodunu (import ederek — kopya değil) tohumlu PRNG'yle koşturur, action
dizileri + beklenen state anlık görüntülerini `test/goldens/*.json`'a yazar;
`test/run_all.dart` aynı action'ları Dart motorunda aynı tohumla oynatıp
derin karşılaştırır.

**Kural: `src/game/` ya da `src/utils/`'ın motor dosyalarına (validator, ai,
board, bag, ranking, leaguePoints, turkish, random, tiles, gameReducer,
constants, types) dokunan HER PR'da:**

```bash
npm run generate-golden-vectors          # repo kökünden; fixture'ları yeniden üretir
cd mobile/kelimeki_core && dart pub get && dart run test/run_all.dart
```

Testler kırılırsa Dart portu da aynı PR'da güncellenir — fixture'ları güncel
tutup Dart'ı güncellememek, paritenin sessizce yalana dönüşmesidir. (CI yok —
kök CLAUDE.md'deki migration disipliniyle aynı: bu adımlar elle, ama isteğe
bağlı değil.)

- Üretici, `src/utils/random.ts`'e eklenen `setRandomSource()` kancasını
  kullanır (üretim kodu hiç çağırmaz) ve `startedAt`'i `''`e normalize eder
  (TS gerçek saat gömer, Dart motoruna `nowIso: () => ''` verilir).
- Snapshot politikası: insan/sync/crafted senaryolarında her adım; YZ
  oyunlarında her 5 adımda bir + son adım (dosya boyutu için — `moveHistory`
  her snapshot'ta tam gömülü olduğundan her-adım kaydetmek dosyayı karesel
  büyütür).
- Fixture envanteri ve ne kanıtladıkları:
  - `turkish.json` — trLower/trUpper birebir; trCompare işaret eşitliği
    (Dart'ta ICU yok; tablo tabanlı collator `localeCompare('tr')` ile bu
    vektörler üzerinden hizalanır — birincil: Türkçe alfabe sırası, üçüncül:
    küçük harf önce).
  - `invasion_formula.json` — `round(basePts*(n+1)/(6n))`, basePts 0..1500 ×
    n 1..3 KAPSAMLI tarama: JS `Math.round` ↔ Dart `.round()` eşitliği bu
    alanda kanıtlı (negatif girdi oluşamaz).
  - `ranking.json` — 200 rastgele oyuncu seti: rankPlayers sırası+rank'i,
    computeRanks, leaguePoints (kararlı sıralama davranışı dahil).
  - `scoring.json` — 6 el yapımı kenar durumu (X3 merkez, X2 bölge, X3'ün
    X2'yi yutması, çapraz kelime, bingo, jokerler) + 60 rastgele
    (geçerlilik aranmayan — fark testi) calcScore/calcWordRawScores durumu.
  - `remaining_tiles.json` — `remainingTiles` ("Kalan Taşlar"/TORBA dökümü),
    60 rastgele durum: tahta + bakanın rafı + **bekleyen (`state.placed`)
    taşlar**, tahtadaki ve masadaki jokerler dahil. 18 Ağustos 2026'da
    eklendi; o güne kadar bu fonksiyonun HİÇ parite kapsaması yoktu ve tam o
    gün iki tarafta birden aynı hata bulundu (bekleyen taşlar "dışarıda"
    sayılıyordu — bkz. Parça 112). Üçüncü parametre atlanırsa fixture
    düşer.
  - `reducer_ai2.json` — 2 kişilik tam YZ oyunu, doğal bitişe kadar (33
    hamle: 32 kelime + 1 pas, 3 bölge vergisi satırı, skorlar 189-189).
  - `reducer_ai4.json` — 4 kişilik tam YZ oyunu + 8. hamlede SURRENDER
    (kademeli teslim: raf→torba, skor sıfırlama, oyun devam) + bingo + bölge
    vergileri, doğal bitiş.
  - `reducer_human2.json` — insan aksiyonlarının tamamı: seçim toggle'ı,
    yerleştir/geri al, TÜM doğrulama hataları (hizasız/boşluklu/köşesiz/
    sözlükte olmayan kelime), gerçek kelime oynama, karıştır, yeniden
    adlandır, taş değiştirme akışı, pas, joker (yerleştir/harf değiştir/
    taşı/geri al/skipWordCheck ile oyna), teslim → oyun bitişi, bitmiş oyunda
    no-op action'lar, ABANDON.
  - `reducer_crafted_finish.json` — elle kurgulanmış bitiş: yalnız-joker
    bitiş bonusu (+50), X3 çarpanı, oyun sonu raf puanı düşümü.
  - `reducer_crafted_bingo.json` — Bingo mesaj metni, HEM insan HEM YZ
    şablonu (17 Ağustos 2026). `reducer_ai4` bingo İÇERİYOR ama YZ
    oyunlarında snapshot her 5 adımda bir alındığından o hamlenin `message`
    alanı hiçbir snapshot'a düşmüyordu — yani metin korumasızdı; bingo notu
    eklenirken fixture'lar yeniden üretilip SIFIR fark çıkması bunu ortaya
    çıkardı. **Fixture YZ'yi SOL-ÜST köşeye (0) kuruyor — ama bu artık bir
    ZORUNLULUK değil, yalnızca fixture'ın kurulumu.** Yazıldığı gün öyleydi
    ve gerekçesi burada yazılıydı ("`tryCornerStart` başlangıç hücresini
    köşe bloğunun İÇİNDEN seçip kelimeyi sağa/aşağı uzatıyor, sağ-alt
    köşede 7 harflik ilk hamle tahtadan taşıyor"); AYNI GÜN o kısıt
    kaldırıldı (bkz. Parça 109), artık dört köşeden de bingo mümkün.
  - `reducer_crafted_ai_exchange.json` — YZ'nin "hamle yok → raf değiştir"
    dalı (yalnız B'lerden raf hiçbir kelime heceleyemez; doğal oyunda nadir).
  - `reducer_sync.json` — SYNC_ONLINE_STATE birleşme mantığı: aynı
    turn_count'ta taslak taşların korunması + `subtractPlacedFromRack`
    (taş çoğaltma hatasının önlemi), turn ilerleyince taslağın temizlenmesi.
- Bilinçli kapsam DIŞI (vektörlerde yok): `MOVE_PLACED_TILE`in dolu hücreye
  reddi gibi bazı tekil no-op korumaları (kod birebir port, düşük risk);
  YZ'nin `freshCorners` çok-köşe dalı (üretimde erişilemez, TS'te de not
  düşülmüş); `boardSnapshot`/`outline` (henüz port edilmedi — outline UI
  fazının işi, boardSnapshot depolama fazının).

## Doğrulama Durumu (5 Ağustos 2026)

- Dart 3.12.2 (Linux x64) ile: `dart analyze` temiz, `dart run
  test/run_all.dart` → **6.746 kontrol, 0 hata** — İLK üretimden itibaren
  tam parite (tek düzeltme turu bile gerekmedi; port TS satır satır
  izlenerek yazıldı).
- `npm run lint` (tsc) web tarafında temiz — `random.ts` kancası davranış
  değiştirmez (varsayılan hâlâ `Math.random`).
- Dart SDK repoya/CI'a bağlanmadı — bu ortamda scratchpad'e indirilip
  kullanıldı; geliştirici makinesinde standart `dart` kurulumu yeterli.

## Sonraya Bırakılan İşler (mobil)

Kök `CLAUDE.md`'nin "Web'de Yapılacak İşler" listesinin mobil karşılığı —
kararı verilmiş ama henüz yapılmamış işler. Bir madde uygulanınca buradan
silinip kendi tarihli parça notuna taşınır.

- **KGP uyarısı — ileride derlemeyi KIRACAK (23 Ağustos 2026'da `.aab`
  log'unda ölçüldü, bugün yalnızca uyarı):** `image_picker_android`,
  `share_plus` ve `shared_preferences_android` Kotlin Gradle Plugin'i
  kendileri uyguluyor; Flutter'ın uyarısı birebir *"Future versions of
  Flutter will fail to build if your app uses plugins that apply KGP"*.
  Bugün acil DEĞİL (derleme geçiyor) ve bu eklentiler bizim değil —
  çözümü kendi sürümlerini Built-in Kotlin'e geçmiş sürümlere yükseltmek.
  Flutter yükseltmesi yapılırken ÖNCE bu üçünün changelog'una bak;
  aksi halde yükseltme günü derleme sebebi anlaşılmayan bir şekilde kırılır.
- ~~Bağlantı durumu göstergesi (`useOnlineStatus` portu)~~ — **YAPILDI**
  (14 Ağustos 2026): karar mantığı Parça 96'da (`util/online_status.dart` +
  `connectivity_plus`), Board alt şeridindeki görsel "Çevrimdışı" rozeti
  Parça 97'de.
- **Kayıt onayı maili kaydın GELDİĞİ kanala dönmeli (10 Ağustos 2026,
  kullanıcı kararı — sözleri: "Kişilerin kayıt başvurusu hangi kanaldan
  geliyorsa o kanala yönlendirilmeleri doğrusu"):** Bugün `signUp()`
  hiçbir `emailRedirectTo` geçmiyor, dolayısıyla GoTrue onay linkini
  Supabase'deki tek Site URL'e (kelimeki.com) atıyor — uygulamadan kayıt
  olan kişi de tarayıcıya düşüyor, oradan uygulamaya dönüp ELLE giriş
  yapmak zorunda kalıyor. TESTING.md 9.4 koşulurken gözlendi (kullanıcı
  uygulamadan T3 olarak kayıt oldu, link tarayıcıda kelimeki.com'u açtı
  ve orada duran ESKİ T5 oturumunu gösterdi — bkz. aşağıdaki "bu bir hata
  DEĞİL" notu).
  - **Yapılacak:** `AuthService.signUp` mobilde `emailRedirectTo:
    kelimeki://auth` (ya da benzeri bir yol) geçsin; web istemcisi
    DEĞİŞMESİN (o zaten doğru kanalda). Dashboard → Authentication → URL
    Configuration → **Redirect URLs**'e bu URI eklenmeli — `kelimeki://reset`
    için yapılan aynı el işi (bkz. Parça 6); eklenmezse GoTrue sessizce
    Site URL'e düşürür ve hiçbir şey değişmez.
  - **Asıl kazanç yalnızca "doğru uygulama açılıyor" değil:** link
    uygulamaya dönerse PKCE `code_verifier` ZATEN o cihazın uygulama
    deposunda olduğundan supabase_flutter takası yapıp kullanıcıyı
    DOĞRUDAN girişli bırakır — "e-postanı doğrula, sonra dönüp giriş yap"
    adımı tamamen kalkar. Bugün bu takas yapılamıyor çünkü verifier
    uygulamada, link ise başka bir origin'de (tarayıcı) açılıyor.
  - **`signup_channel` ile KARIŞTIRMA:** o alan 'direct'/'form' ayrımını
    (hangi FORMDAN gelindiği) tutuyor; buradaki "kanal" platform —
    uygulama mı tarayıcı mı. İkisi bağımsız.
  - **Doğrulaması FAZ B'ye bağlı:** custom şema (`kelimeki://`) yalnızca
    GERÇEKTEN kurulu bir native uygulama varken işletim sistemi tarafından
    yakalanabilir; GitHub Pages web derlemesinde test EDİLEMEZ (Parça
    28'in aynı sınırı). Aynı turda `kelimeki://reset` de ilk kez gerçek
    cihazda doğrulanacağından ikisi birlikte ele alınmalı.
  - **Bugünkü davranış bir HATA değil, kayda geçsin:** T3'ün onay linki
    sunucuda gerçekten işledi (`email_confirmed_at` linke basılan an) ve
    tarayıcıdaki T5 oturumuna DOKUNMADI (`last_sign_in_at` bir saat
    öncesinde kaldı) — yani link kimseyi giriş yaptırmadı, yalnızca o
    origin'de zaten duran oturum göründü. PKCE'nin verifier'ı öteki
    origin'de olduğundan takas yapılamıyor; bu aynı zamanda güvenlik
    açısından doğru taraf (aksi halde bir kullanıcının onay linki başka
    bir hesabın açık oturumunu sessizce ezerdi).

