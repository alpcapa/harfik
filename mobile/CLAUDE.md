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
- Siteyi ben açıp bakamam. **Ekran görüntüsü tek enstrümandır** — derleme
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
```

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

## Backend Hazırlığı (5 Ağustos 2026 — production'a uygulandı)

İki migration, kök CLAUDE.md'deki zorunlu akışla (SQL dosyası + MCP ile canlıya
uygulama + canlıda doğrulama + `list_migrations` versiyon eşleştirme) uygulandı.
**Web istemcisinin davranışı İKİSİNDE de değişmedi** — doğrulamanın bir parçası
olarak eski (parametresiz) çağrı şekli canlıda test edildi.

- **`20260805225619_submit_move_move_id_idempotency`** — `online_game_moves`e
  nullable `move_id uuid` kolonu + `(online_game_id, move_id)` kısmi unique
  index; `submit_move` imzasına `p_move_id uuid default null` eklendi.
  Parametre eklemek overload yaratacağından (PostgREST'te 8-argümanlı çağrı
  iki fonksiyona da uyar → 300 ambiguous) eski imza DROP edilip fonksiyon tek
  başına yeniden CREATE edildi; grant'ler (authenticated+service_role) birebir
  geri kuruldu. Dedup kontrolü `online_games` satır kilidinden SONRA ve
  `player_user_id = auth.uid()` şartıyla yapılır (eşzamanlı özdeş retry'lar
  kilitte serileşir; başkasının move_id'siyle hamle yutma kapalı). **Amaç:**
  mobil ağlarda "istek gitti, yanıt kayboldu" retry'ı bugüne kadar sahte bir
  'Sıra sende değil.' reddine dönüşüyordu — artık aynı `p_move_id` ile gelen
  yeniden deneme sessizce başarı döner, çifte hamle yapısal olarak imkânsız.
  Web istemcisi/`play-ai-turn` parametreyi göndermiyor (null → dedup atlanır,
  bugünkü davranış). Mobil istemci HER hamlede `p_move_id` gönderecek ve
  "başarı ya da kesin ret" varsayabilecek.
  - **Doğrulama (production, disposable oyun, transaction+rollback):** T1/T2
    test hesaplarıyla gerçek `init_online_game_state`+`submit_move` çağrıları:
    move_id'li pas → tur ilerledi + hamle satırında move_id; AYNI move_id ile
    retry → hatasız döndü, tur İLERLEMEDİ, ikinci satır açılmadı; move_id'SİZ
    (mevcut web çağrı şekli) pas → normal işledi, satırda move_id null. Tümü
    rollback edildi, sıfır iz (leftover=0 sorgusuyla ayrıca teyit).
- **`20260805225630_app_config_min_supported_client`** — `app_config(key,
  value jsonb, updated_at)` tablosu, RLS: herkese (anon dahil — sürüm kontrolü
  login'den önce yapılmalı) SELECT, hiçbir client rolüne yazma yolu YOK
  (değer değişikliği migration/SQL ile). Seed: `mobile_min_supported_version`
  = `{"android":"0.0.0","ios":"0.0.0"}` (hiçbir şeyi engellemez). Mobil
  uygulama açılışta okuyup semver karşılaştırmasıyla "önce güncelle" ekranı
  gösterecek. Doğrulama: anon rolüyle satır okundu; authenticated rolüyle
  UPDATE denemesi `insufficient_privilege` ile reddedildi.

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
                             # dekorasyonu/metin stili, bkz. Parça 79), ve:
      ui/auth/               # giriş-kayıt-şifremi-unuttum modalı, hesap
                             # butonu, avatar, Terms/Privacy,
                             # reset_password_modal (recovery kapısı)
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

## Depolama Katmanı (`mobile/app/lib/src/storage/`, 6 Ağustos 2026)

Web'in localStorage kalıcılığının mobil karşılığı — SQLite (sqflite) +
SharedPreferences. Tasarımın amacı PORT_BRIEF §7'deki "bozuk kayıt → çökme
döngüsü → ErrorBoundary'den elle silme" sınıfını YAPISAL olarak imkânsız
kılmak; dört kural:

1. **"Parse, don't validate"** — yükleme `gameStateFromJson`dan geçer: ya
   tamamen geçerli state ya fırlatma; yarım state temsil edilemez.
2. **Karantina, ASLA silme** — çözülemeyen/bilinmeyen-sürümlü kayıt
   `quarantined_saves`e taşınır (sebep + zaman damgasıyla), kullanıcı temiz
   başlar, veri teşhis için durur. Aynı bozuk kayıt iki kez okunamayacağı
   için çökme döngüsü kurulamaz.
3. **Versiyonlu payload** — her kayıtta `payload_version`; şekil değişince
   `_payloadMigrations`e adım eklenir; zinciri olmayan sürüm (gelecekten
   gelen kayıt dahil) tahmin edilmez, karantinaya gider. DB şema sürümü
   (`kDbSchemaVersion`, yıkıcı olmayan migrasyonlar, downgrade'de dokunma)
   AYRI bir kavramdır.
4. **Tek blob yok** — kayıt/karantina/kuyruk/olay/damga ayrı tablolar; biri
   bozulunca diğerlerini rehin alamaz. Atomiklik transaction'lardan bedava.

Saat her store'a ENJEKTE edilir (`nowMs`) — core'daki determinizm
sözleşmesinin devamı; testler 7 günlük süreleri ileri sararak koşuyor.

**localStorage → mobil eşleme tablosu** (tartışmada kararlaştırılan, artık
uygulanmış hâli — web→mobil VERİ taşınması yok, localStorage okunamaz;
girişli kullanıcının bulut tarafı `local_game_saves` senkron fazının işi):

| Web anahtarı | Mobil karşılığı |
|---|---|
| `kelimeki:game-state` | `local_saves` tablosu, tek `guest` slotu (`LocalSaveStore`) — 7 günlük terk süresi (`abandonTimeout`, web `ABANDON_TIMEOUT_MS`) dolunca kayıt `pending_events`'e (`abandoned-game`) taşınır; yüklenen oyun web'deki gibi `multiSession=true` işaretlenir |
| `kelimeki:pending-abandoned-game` | `pending_events` satırı — `takeAll` SELECT+DELETE'i tek transaction'da (web'in read-then-clear/StrictMode savunmasının atomik hâli) |
| `kelimeki:pending-games` | `pending_queue` (`kind='finished-game'`) — id dedup (ilk kayıt kalır), tür başına 300 sınırı (`kMaxPendingPerKind`), okumada 7 günlük TTL (`pendingExpiry`); sunucuya flush senkron fazında |
| `kelimeki:pending-feedback` | `pending_queue` (`kind='feedback'`) — aynı mekanik |
| `kelimeki:pending-friend-invite-token` | `pending_events` (`friend-invite-token`) |
| `kelimeki:chat-last-read:<gameId>` | `chat_last_read` tablosu (`ChatReadStore`) — sınırsız dinamik anahtar prefs'e değil tabloya |
| `kelimeki:seen-quickstart` / `seen-chat-intro` | SharedPreferences (`FlagsStore`) |
| `kelimeki:anon-id` / `anon-visit-date` / `utm-source` | SharedPreferences — anonId bir kez üretilir, UTM first-touch (ikinci yazma yok sayılır, web `captureUtmSource` ilkesi) |
| `kelimeki_landscape_hint_dismissed`, `kelimeki_a2hs_dismissed` | YOK — portre kilidi native, PWA banner'ı mobilde anlamsız (bilinçli düşürüldü) |

`AppStorage.open()` tek giriş kapısı; bootstrap'ta sözlükle aynı desenle
fire-and-forget açılır (`AppServices.storage`, ilk kareyi bekletmez),
`HomeScreen` durum satırı gösterir. Testler `sqflite_common_ffi` ile
masaüstü VM'de GERÇEK SQLite üzerinde (cihaz gerekmez): dolu-oyun roundtrip
(motor + gerçek sözlükle üretilmiş state), bozuk-payload karantinası,
bilinmeyen-sürüm karantinası, 7 günlük terk olayı (tek seferlik take),
kuyruk dedup/300-sınırı/TTL/tür-izolasyonu, damga ve bayrak davranışları.

**Bu bölümde "henüz bağlanmayan uç" KALMADI** (7 Ağustos 2026 itibarıyla):
kaydet/yükle UI'ı UI parça 5-6'da, terk→-2 üst katmanı auth parça 3b'de,
`finished-game` flush'ı 3b'de, `feedback` flush'ı Görüş Bildir parçasında
bağlandı. Yeni bir kuyruk türü eklenirse aynı kural geçerli: satır sahibi
tabloya giden flush `TableWriteQueue`dan geçmek ZORUNDA (bkz. "Porta
Taşınan Değişmezler"; `feedback` tablosu append-only/satır sahipliği
olmayan bir insert olduğundan o kuyruğa bilinçli olarak GİRMİYOR — okuma
yolu yok, DELETE→SELECT yarışı kurulamaz).

## Flutter Uygulama İskeleti (`mobile/app/`, 5 Ağustos 2026)

Gerçek UI DEĞİL — kablolama iskeleti: motor + sözlük + Supabase + sürüm
kapısı + idempotent hamle gönderimi uçtan uca bağlı ve test edilmiş durumda.
`HomeScreen` şimdilik bir durum paneli + "Motor testi: YZ vs YZ" düğmesi.

- **Kimlik/platform:** org `com.kelimeki`, proje adı `kelimeki` (Android
  paket adı `com.kelimeki.kelimeki` — mağazaya İLK yüklemeye kadar
  değiştirilebilir, sonrasında kalıcı; değiştirilecekse o ilk yüklemeden
  önce). `flutter create --platforms=android,ios` çıktısı olduğu gibi
  commit'li; elle yapılan platform değişiklikleri ŞUNLARLA sınırlı:
  - `AndroidManifest.xml`: `android:label="Kelimeki"`,
    `screenOrientation="portrait"`, kelimeki.com için `autoVerify`'lı App
    Links intent-filter'ı, ve `kelimeki` custom şeması için ikinci bir
    intent-filter (7 Ağustos 2026, şifre sıfırlama parçası — host
    kısıtlanmadı ki gelecekteki `kelimeki://...` linkleri de geçsin;
    custom şema assetlinks/imza gerektirmez, bugün ÇALIŞIR durumda).
    **assetlinks.json henüz YOK** — imzalama anahtarı
    oluşturulduğunda sitenin `/.well-known/assetlinks.json` yayınlaması
    gerekiyor (web tarafına dokunan iş; o güne dek filtre zararsız).
    iOS Universal Links (associated domains entitlement + AASA dosyası)
    tamamen Apple hesabı gerektirdiğinden hiç başlanmadı.
  - `Info.plist`: iPhone VE iPad portre-kilidi, `CFBundleDisplayName`
    "Kelimeki", ve `CFBundleURLTypes` ile `kelimeki` custom şeması (aynı
    parça — Universal Links'in aksine Apple hesabı gerektirmez). Portre
    kilidi ayrıca runtime'da `SystemChrome` ile — web'deki `LandscapeHint`
    banner'ının yerine geçen kesin çözüm.
- **Bootstrap deseni (`bootstrap.dart`):** tüm dış dünya tek `AppServices`
  nesnesinde — widget testleri sahte servislerle pump edebiliyor. Sözlük
  yüklemesi ilk kareyi BEKLETMEZ (web'deki preloadWordSet gibi Future olarak
  taşınır); satır ayrıştırma `Isolate.run`'da.
- **Sürüm kapısı FAIL-OPEN:** `app_config`a ulaşılamazsa (offline/anahtarsız/
  5sn zaman aşımı) kapı geçilir — yerel YZ oyunu offline bir haktır; eşik
  yalnızca sunucu sözleşmesi kırıldığında yükseltilir ve o durumda offline
  oyuncu zaten etkilenmez. `appVersion` sabiti (env.dart) pubspec `version`
  ile BİRLİKTE artırılmalı — **sürüm disiplini:** release commit'i ikisini
  birden değiştirir (package_info_plus eklentisi tek sabit için bilinçli
  olarak alınmadı).
- **`OnlineApi.submitMove`:** her çağrı `p_move_id` UUID'si üretir
  (20260805225619 migration'ının istemci yarısı); taşıma hatalarında AYNI
  id ile 3 denemeye kadar üstel bekleme, `PostgrestException`'da (sunucunun
  kesin kararı) asla retry yok. `uuid` paketi yerine 15 satırlık yerel v4
  üretimi (Random.secure) — bağımlılık tasarrufu.
- **`GameController`:** karar #5'in gereği — framework'süz `ChangeNotifier`;
  YZ sırası gelince bir sonraki event-loop turunda otomatik `AiPlayAction`
  (web'deki App.tsx effect'inin eşleniği), `autoPlayAi: false` ile testlerde
  kapatılabilir.
- **`anonKey` deprecation'ı bilinçli susturuldu** (supabase_client.dart):
  web istemcisi legacy anon key kullanıyor; publishable key'e geçiş iki
  istemcinin birlikte vereceği ayrı bir karar.
- **Doğrulama durumu (5 Ağustos 2026):** Flutter 3.38.4 (Linux) ile
  `flutter analyze` temiz; `flutter test` 6/6 — en önemlisi
  `game_controller_test.dart`, golden `reducer_ai2` senaryosunu (tohum
  12345) uygulamanın KENDİ katmanından (GameController + gerçek asset
  dosyası) yeniden oynatıp final skor/tur sayısını fixture'la birebir
  doğruluyor; ayrıca autoPlayAi'nin kendiliğinden hamle sürdüğü ve sürüm
  kapısının UpdateRequiredScreen'e yönlendirdiği test edildi.
  **Doğrulama sınırı:** bu ortamda Android SDK/emülatör/gerçek cihaz YOK —
  `flutter build apk`/`build ios` hiç koşulmadı; gerçek cihazda ilk açılış
  (asset yükleme süresi, Supabase bağlantısı, App Links) kullanıcının
  cihazıyla teyit edilmeli. Supabase'e gerçek bağlantı da test edilmedi
  (anahtarlar --dart-define ile verilecek).

## Uygulama İkonu / Splash (7 Ağustos 2026)

`flutter create`'in varsayılan mavi kuş ikonu, kullanıcı Appetize.io'da
uygulamayı ilk kez çalıştırdığında fark edildi — o ana kadar hiç
dokunulmamıştı. Yeni bir marka görseli İCAT EDİLMEDİ: kaynak, web'in
`public/icon.svg`'si (kök `scripts/generate-icons.mjs`'in ürettiği, PWA
ikonunu/favicon'u besleyen aynı SVG — tahta filigranı + "kelimeki" el
yazısı). Mobil ikon web'deki `icon-512.png` ile PİKSEL AÇISINDAN aynı
kompozisyondan türetiliyor.

- **`mobile/scripts/generate-app-icon-masters.mjs`** (kök `node_modules`'daki
  Playwright/sharp'ı kullanır, repo kökünden `node mobile/scripts/generate-app-icon-masters.mjs`
  ile çalıştırılır) `public/icon.svg`'yi okuyup iki ARA görsel üretir
  (`mobile/app/assets/icon/`, elle düzenlenmez):
  - `icon-source.png` — 1024×1024, opak beyaz zemin, tam kanama. iOS
    `AppIcon.appiconset` + Android LEGACY (`mipmap-*`) ikonunun kaynağı.
  - `icon-adaptive-fg.png` — 1024×1024, ŞEFFAF zemin, içerik `<rect
    fill="#ffffff"/>` zemin dikdörtgeni kaldırılıp %66'lık güvenli bölgeye
    küçültülmüş. Android ADAPTIVE ikonun ön katmanı VE splash görseli
    olarak İKİ amaçla kullanılıyor — Android 12+'nin native splash API'si
    de aynı dairesel maskeleme kısıtına tabi, tek dosya iki yerde güvenle
    kullanılabiliyor.
  - **%66 güvenli bölge NEDEN:** Android adaptive ikon maskeleri (dairesel/
    squircle/yuvarlatılmış kare, launcher'a göre değişir) merkezi ~%61'lik
    bir daireyi hiçbir zaman kesmiyor; web'deki `icon-512.png`'de kelime
    kenarlara çok yakın (~%93 genişlik) — doğrudan kullanılsaydı bazı
    launcher'larda "k"/"i" harflerinin kenarları kırpılırdı.
- **Üretici paketler** (`dev_dependencies`, yalnızca `dart run` sırasında
  kullanılır, derlenmiş uygulamaya girmez): `flutter_launcher_icons` (iOS
  AppIcon.appiconset + Android mipmap-*/mipmap-anydpi-v26 adaptive XML) ve
  `flutter_native_splash` (Android 12+ splash API + eski `launch_background`
  + iOS `LaunchScreen.storyboard`) — ikisi de pubspec.yaml'daki kendi
  anahtarlarından (`flutter_launcher_icons:`/`flutter_native_splash:`)
  yapılandırılıyor, ayrı bir yaml dosyası yok. **`flutter_native_splash`
  `^2.4.8` bu Flutter SDK'sının (3.35.4) sabitlediği `meta 1.16.0` ile
  çakışıyor** (`meta ^1.18.0` istiyor) — `^2.4.7`'de kal.
  `flutter_native_splash`'in `web: false` bayrağı bilinçli: `web/` klasörü
  ayrı bir TEST ORTAMI (bkz. yukarı "Web Derlemesi"), elle kurulmuş
  `index.html`/CanvasKit ayarlarına bu üretici hiç dokunmasın diye kapalı.
  Çalıştırma sırası: `flutter pub get` → `dart run flutter_launcher_icons`
  → `dart run flutter_native_splash:create`.
- **Işlem sonrası doğrulama ZORUNLU — üreticiler platform dosyalarını
  MERKEZDEN yeniden yazıyor, elle yazılmış özel ayarları sessizce
  silebiliyor:** `flutter_native_splash`'in `AndroidManifest.xml`'i
  yeniden biçimlendirmesi (`dart run` çıktısı) bu PR'da `android:screenOrientation="portrait"`
  attribute'unu SESSİZCE düşürmüştü — bu, yukarıdaki "Flutter Uygulama
  İskeleti" bölümünde belgelenmiş, BİLİNÇLİ bir native portre kilidi (Dart
  tarafındaki `SystemChrome` kilidi yalnızca Flutter motoru başladıktan
  SONRA devreye giriyor; native splash motor başlamadan ÖNCE gösterildiğinden
  bu attribute olmadan cihaz yatay tutuluyorsa splash bir an yatay
  görünebilirdi). Fark, iki dosyayı `git show HEAD:...` ile üretici
  ÖNCESİ haliyle karşılaştırıp (XML için `xml.etree`, plist için
  `plistlib` — attribute/key kümesini SIRADAN/BOŞLUKTAN bağımsız
  karşılaştırarak) yakalandı; attribute geri eklendi. **Ders — bir platform
  dosyası üretici tarafından yeniden yazıldığında `git diff`in "değişti"
  demesi yetmez, NE değiştiğini attribute seviyesinde doğrula** (biçim
  farkı mı, gerçek bir kayıp mı). `Info.plist`'te tek gerçek ekleme
  `UIStatusBarHidden=false` (native_splash'in kendi, zararsız eklemesi) —
  aynı yöntemle doğrulandı, başka hiçbir key kaybolmadı/değişmedi.
- **Doğrulama:** `dart analyze` temiz, `flutter test` 142/142 (ikon/splash
  yalnızca asset+config dosyalarını değiştirdiğinden Dart kodu hiç
  etkilenmedi). Gerçek cihazda/Appetize'da görsel doğrulama kullanıcıdan
  bekleniyor — bu ortamda Android SDK/Xcode yok, yalnızca üretilen PNG'ler
  bu oturumda gözle kontrol edildi (web'deki marka ile birebir aynı).

## MembershipPerksBox — Setup Misafir Kutusu (7 Ağustos 2026)

`src/components/Setup.tsx`'teki `MembershipPerksBox`'ın portu —
`lib/src/ui/setup/membership_perks_box.dart`. Web'in iki çağrı yerine
(misafirin "Devam Eden Oyun" görünümü, `topMargin: true` = web
`className="mt-2"`; misafirin boş kurulum formu, `topMargin: false`)
birebir aynı iki yerde: `_buildSavedGameView` ve `_buildNewGameForm`.

- **Gate widget'ın KENDİSİNDE** (`if (auth.user != null) return
  SizedBox.shrink()`), çağıranlarda değil — `_buildNewGameForm` hem
  misafirin boş formunda (`showCancel:false`) hem girişli kullanıcının
  "+ Yeni" formunda (`showCancel:true`) çağrıldığından (web'in aynı
  `else` dalını paylaşan deseniyle birebir), tek bir yerden gate etmek
  iki çağrı yerinde de kod tekrarını önlüyor — `AccountButton`'ın kendi
  `auth.user`/`configured` kontrolünü içeride yapması deseniyle tutarlı.
- **`auth.configured`'a BİLEREK bakılmıyor** — web de bakmıyor
  (`Setup.tsx`, `useAuth()`'tan yalnızca `user/profile/loading/profileLoading`
  okunuyor, `configured` hiç). Yani Supabase yapılandırılmamış (offline)
  bir ortamda bile kutu görünür — web'in kendisi de böyle davranıyor,
  `AuthService.signIn`/`signUp` zaten `_client==null` iken sessizce no-op
  olduğundan (`auth_service.dart`) tıklanabilir ama zararsız kalıyor,
  mobilde ekstra bir gate eklemek istenmeyen bir davranış farkı (scope
  dışı bir "düzeltme") olurdu.
- **Bulunan hata (bu iş sırasında, ekran görüntüsüyle yakalandı) — ✓
  (U+2713) glyph'i SpaceMono'da yok:** ilk sürüm web'deki `✓` karakterini
  `Text` widget'ına aynen kopyalamıştı; web'de tarayıcı otomatik font
  fallback yaptığından görünüyordu, Flutter'da otomatik fallback OLMADIĞI
  için (`fontFamilyFallback` verilmedikçe) boş kare (tofu) render etti.
  Bu proje bu DERSİ zaten bir kez öğrenmişti (`auth_modal.dart`'ın
  `_StatusLine`'ı, nickname kontrolündeki "✓ Kullanılabilir" için) — aynı
  çözüm tekrarlandı: karakter yerine `Icon(Icons.check, size: 12,
  color: _green)`. **Ders:** web'den Unicode sembol/emoji kopyalanan her
  yerde önce bu iki dosyadaki (`_StatusLine`, şimdi bu widget) örneğe
  bakılmalı — bu proje artık üçüncü kez aynı "gömülü fontta glyph yok"
  tuzağına düşmemeli (★/► için de aynı ders daha önce not edilmişti, bkz.
  yukarıdaki `_StatusLine` alıntısındaki yorum).
- **Gölge/renk değerleri elle tahmin edilmedi, ölçüldü:** kutunun
  `shadow-raised` gölgesi (index.css) `NeoButtonVariant.neutral`'ın
  gölgesiyle (`neo_button.dart`) BİREBİR AYNI rgba/offset/blur
  değerlerine sahip olduğu doğrulanıp (0x80A3B1C6/(2,2)/6 ve
  0xD9FFFFFF/(-2,-2)/5) doğrudan oradan kopyalandı — yeni bir gölge
  sabiti icat edilmedi. Zemin/çerçeve rengi (`bg-accent/5`/`border-accent/30`)
  tailwind.config'teki `accent:'#2563EB'` üzerinden hesaplanan opaklıklar
  (0x0D/0x4D).
- **Doğrulama:** `dart analyze` temiz; `flutter test` 143/143 (yeni test:
  misafirde 6 madde + buton görünüyor + `showLoginModal` gerçekten
  `AuthModal`'ı açıyor; ayrıca "anti-kaçış" testine kutunun "Devam Eden
  Oyun" görünümünde de çıktığı doğrulaması eklendi). Görsel doğrulama
  gerçek render'la yapıldı — Flutter Web derlemesi (bkz. "Web Derlemesi"
  bölümü) Chromium'da açılıp ekran görüntüsü alındı; ✓ glyph hatası TAM
  BU YÖNTEMLE yakalandı (widget testleri metni doğru buluyordu ama
  glyph'in görsel olarak render olup olmadığını göremez — bu ayrım bir
  ders: metin eşleşmesi doğru ≠ görsel olarak doğru render).

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

## Web Derlemesi — ÜRÜN DEĞİL, TEST ORTAMI (7 Ağustos 2026)

Flutter'ın web hedefi bu porta üçüncü bir platform olarak EKLENMEDİ; ürün
hedefi hâlâ yalnızca iOS + Android. Web derlemesi tek bir sorunu çözüyor:
**geliştiricinin çalıştırabileceği hiçbir cihazı yok.** iPad'den çalışıyor,
Mac yok, Android telefon yok, Apple Developer üyeliği askıda (TestFlight
yok), tarayıcı emülatörü (Appetize) ücretsiz katmanda 3 dakikayla sınırlı.
Aynı Dart kodu aynı çizim motoruyla (CanvasKit) koştuğundan yerleşim/font/
gölge/oyun akışı doğrulaması burada ücretsiz ve süresiz yapılabiliyor.

Adres `https://alpcapa.github.io/kelimeki/`; `main`e giren her mobil
değişiklikte `.github/workflows/mobile-build.yml`'in `web` işi GitHub
Pages'e deploy ediyor. **PR'larda deploy YOK** (site paylaşılan bir test
ortamı, merge edilmemiş kodla değiştirilemez) — PR'da bunun yerine `test`
işi web'i deploy etmeden DERLİYOR, yani web'e özgü kırılmalar yine
yakalanıyor. NE KANITLAR / NE KANITLAMAZ ayrımı `mobile/TESTING.md`'de ("Web
derlemesi") — kısaca: platform kanalı gerektiren her şey (paylaş sayfası,
dosya sistemi, oturum kalıcılığı, ikon/splash, gerçek dokunmatik jestler,
performans) hâlâ gerçek cihaz ister.

**KURAL — web dalı mobil kod yolunu DEĞİŞTİREMEZ.** Üç kırık noktanın
üçünde de mobil taraf bire bir korundu; yeni bir platform-bağımlı API
kullanırken aynı deseni izle:

| Kırılan | Sebep | Çözüm |
|---|---|---|
| Sözlük hiç yüklenmiyordu | `Isolate.run` web'de yok ("Unsupported operation: new RawReceivePort") | `kIsWeb` dalı (`dictionary_loader.dart`) — derleme zamanı sabiti olduğundan mobil derlemede web dalı tamamen elenir |
| Depolamaya bağlı her ekran asılı kalıyordu | `sqflite`'ın native platform kanalı tarayıcıda yok | `sqflite_common_ffi_web` (WASM sqlite3 + IndexedDB) aynı `DatabaseFactory` arayüzünü verir → şema/sorgu/store kodu HİÇ değişmedi |
| Kelime anlamları açılamıyordu | asset kopyası `dart:io` ile dosyaya yazılıyor | web dalı kopyayı IndexedDB'ye yazar; "güncel mi" sorusu ayrı damga dosyası yerine ADA gömülü sha256 ile yanıtlanır |

**Koşullu import deseni (`lib/src/storage/web_db.dart`).** `sqflite_common_ffi_web`
yalnızca web'de derlenebilen js_interop içeriyor — doğrudan import edilirse
iOS/Android derlemesini KIRAR. Üçlü dosya: `web_db.dart` (`export ... if
(dart.library.js_interop) ...`), `web_db_stub.dart` (mobil, her zaman
`null`), `web_db_web.dart` (web). Tek kullanım yeri `openAppDatabase` +
`MeaningStore._open`; ikisi de "çağıran kendi fabrikasını geçtiyse hiç
devreye girme" kuralını uyguluyor, bu yüzden **testlerin hiçbiri
etkilenmedi** (142/142 aynen geçiyor).

**`web/` klasörü depoda tutuluyor** — içindeki `sqflite_sw.js` ve
`sqlite3.wasm` `dart run sqflite_common_ffi_web:setup` ile ÜRETİLİR ama
derleme anında ağdan indirilmemesi için repoya konmuştur. `sqflite_common_ffi_web`
sürümü yükseltilirse bu iki dosya da yeniden üretilmeli.

**Yeni bir platform API'si eklerken sor:** web'de var mı? Yoksa (a) `kIsWeb`
ile dallan, (b) koşullu import'un arkasına al, ya da (c) sessizce
işlevsizleş (anlam modalı asset açılamazsa "anlam bulunamadı" der, oyun
akışı bozulmaz). Ne yaparsan yap, web derlemesinin ASILI KALMAMASI şart —
asılı bir ekran bütün test ortamını kullanılmaz yapıyor.

## Appetize — Otomatik Yükleme (7 Ağustos 2026)

**Sabit linkler** (bir daha değişmez, her derlemede otomatik güncellenir):
- Android → https://appetize.io/app/oexlhcjxdl6onjr4dewaarnvwa
- iOS → https://appetize.io/app/onpdavcakhztlouyedivwrcrdi

**Sorun:** geliştirici iPad'den çalışıyor, Appetize'a manuel yükleme
iOS Safari'nin dosya seçicisinde günlerce iki ayrı belirtiyle tıkanıyordu:
(1) dosya seçicide `.apk` SOLUK/tıklanamaz kalıyordu — sebep iOS'un
`.apk`'ya karşılık gelen bir UTI (Uniform Type Identifier) tanımlaması,
Appetize'ın hangi platform sekmesi seçili olursa olsun bu değişmiyordu
(ilk teşhis "platform sekmesi yanlış" idi, ikinci denemede aynı sekmeyle
tekrar başarısız olunca bu teşhis de çürüdü); (2) dosya seçici yerine
sürükle-bırak denendiğinde dosya "aktif" görünüyordu ama yükleme
**400 Bad Request**'le reddediliyordu — muhtemelen iPad Safari'nin
uygulamalar-arası (Files → Safari) büyük dosya sürüklemesinin XHR/fetch
multipart isteğine tam veri aktarmaması. İkisi de tarayıcı/iOS kaynaklı,
Appetize tarafında elle düzeltilebilecek bir ayar değildi.

**Çözüm — dosya seçiciyi tamamen devreden çıkarmak:** Appetize'ın REST
API'si (`https://api.appetize.io/v1/apps/`) `{"url": ...}` gövdesiyle
POST edilirse dosyayı **sunucu sunucuya** kendisi çekiyor — iPad'in
tarayıcısı hiç işin içine girmiyor. Bu, web arayüzünde görünmeyen ama
API'de baştan beri var olan bir yol (`maxep/appetize-upload-action`
GitHub Action'ının kaynağından bulundu — `POST /v1/apps/[public-key]`,
gövde `{url, platform, note, timeout}`, HTTP Basic Auth `username=<API
token>`). `.github/workflows/mobile-build.yml`'deki `android`/`ios`
işlerinin sonuna, GitHub Release'e yükleme adımından hemen sonra birer
`curl` adımı eklendi — o dosyanın az önce yüklendiği herkese açık
`mobile-latest` release URL'ini Appetize'a gönderiyor.

**İki aşamalı kuruluş — NEDEN `public-key` sabit bir değer:** İlk koşuda
`public-key` verilmeden POST edilirse Appetize YENİ bir app oluşturuyor
(her koşuda ayrı bir tane, hesabı dolduracak kadar). Bunun yerine bir
KEŞİF koşusu yapıldı (`public-key` yok) → dönen `publicKey` job log'undan
okunup (`echo "$resp" | jq '{publicKey, appURL}'`) İKİNCİ bir commit'le
workflow'a sabit parametre olarak gömüldü (`/v1/apps/oexlh.../` gibi) —
artık her koşu AYNI app'i günceller, `appURL` (yukarıdaki linkler) bir
daha değişmiyor. `manageURL` alanı bilerek log'a hiç yazdırılmıyor —
action'ın kendisi bunu `core.setSecret` ile maskeliyor, aynı ihtiyat
burada da uygulandı (`publicKey`/`appURL` Appetize'ın kendi tasarımı
gereği zaten paylaşılabilir — session linkleri herkese açık).

**Gereken tek kurulum: `APPETIZE_API_TOKEN` secret'ı.** Appetize →
Organization Settings → API Token → **Developer** rolüyle üretilip
GitHub'a repo secret'ı olarak eklendi
(`https://github.com/alpcapa/kelimeki/settings/secrets/actions`). Adım
bu secret olmadan da KIRILMAZ — `if [ -z "$APPETIZE_API_TOKEN" ]; then
exit 0; fi` ile sessizce atlanır, derleme etkilenmez.

**Bu ortamdan (Claude Code oturumu) doğrudan denenemedi:**
`api.appetize.io`/`appetize.io`'ya bu oturumun ağ proxy'si 403 ile engel
koyuyor (`CONNECT tunnel failed`) — API'nin var olduğu ve çalıştığı GitHub
Actions runner'ından (proxy'siz, gerçek internet erişimi olan ortam)
gerçek bir keşif koşusuyla kanıtlandı, kör kod yazılmadı.

**Doğrulama:** Keşif koşusu (commit `1fc8522`) gerçek `APPETIZE_API_TOKEN`
ile hem Android hem iOS için gerçekten yeni birer Appetize app'i açtı —
job log'larında dönen `publicKey`/`appURL` doğrudan okunup ikinci
commit'e (bu bölümdeki sabit değerler) aynen taşındı. Uçtan uca (linke
tıklayıp Start'a basma) doğrulaması kullanıcının kendi cihazından
bekleniyor — bu ortamdan `appetize.io` erişilemediğinden ben açıp
göremiyorum.

## Karşılama Katmanı (web) — bilinçli ayrışma, portta YOK (18 Ağustos 2026)

Web'e 18 Ağustos 2026'da girişsiz ilk ziyaretçiye gösterilen bir karşılama/
tanıtım katmanı eklendi (kök `CLAUDE.md` → "Karşılama Katmanı" bölümleri —
kapı script'i, statik HTML prerender, tanıtım tahtaları, k-lig mühürleri,
SSS). Bu bölüm önceki "Web ↔ Uygulama Arasındaki Kabul Edilmiş Farklar"
listesinin TERSİ bir durum: burada web'in ÇÖZDÜĞÜ bir şeyi app'in eskisi
gibi bırakması değil, web'de YENİ bir özellik var ve app'te hiç YOK — üç
madde:

1. **Kurulum ekranındaki `<` (tanıtım sayfasına dönüş) düğmesi web'e
   özgüdür, BİLİNÇLİ ayrışmadır — porta EKLENMEYECEK.** Uygulamada
   karşılama katmanı hiç olmadığından bu düğmenin gideceği bir yer de yok;
   bir sonraki denetimde biri "port geride kalmış" deyip düğmeyi porta
   eklemeye kalkışmasın diye
   bu not burada duruyor.
2. **Uygulamanın kendi ilk açılış/tanıtım ekranı AYRI ve planlı bir iş** —
   ana port spesifikasyonu (PORT_BRIEF) bunu *"Setup'ın ÖNÜNE eklenen yeni
   bir ekran, kalıcı bir 'bir daha gösterme' bayrağıyla; mevcut ekranlar
   değişmez; mağaza çıkışından önce bitmeli"* olarak tarif ediyor ve aynı
   hikâye omurgasını (web'in karşılama katmanındaki metin/görseller)
   kullanacak. Bu iş şu an başlamadı.
3. **O ekran geldiğinde bile Setup başlığına bir ok/düğme KONMAYACAK.**
   Native bir uygulamada kök ekranın sol üstündeki geri oku navigasyon
   yığınını POP etmek demektir; Setup zaten kök ekran ve iOS'ta bu,
   sistemin kendi geri hareketiyle (edge-swipe) çakışırdı. Tanıtıma dönüş
   yerine **hesap menüsüne** ("Nasıl Oynanır?"in hemen yanına) gelecek —
   port o menüyü zaten bilgilendirici maddeler için kullanıyor (k-lig, Skor
   Kartı, Arkadaşlar, Nasıl Oynanır?, Hesap Ayarları), başlık geometrisine
   hiç dokunmaz ve senkron tutulması gereken yeni bir şekil yaratmaz.

## Web ↔ Uygulama Arasındaki Kabul Edilmiş Farklar

Port sırasında fark edilen, uygulamada ÇÖZÜLMÜŞ ama web'de bilinçli olarak
BIRAKILAN farklar. **Kullanıcı kararı (6 Ağustos 2026): "Web'de şimdiye
kadar bir sorun yaşamadım, o taraf düzgün çalışıyor. Değişiklik yapıp riske
sokmanın anlamı yok — ek bir faydası yoksa o tarafa dokunmayalım."**

Yani bu liste bir "yapılacaklar" listesi DEĞİL, bir karar kaydı: aşağıdaki
maddeler web'de ölçülerek KUSURSUZ çalıştığı doğrulandı, uygulamadaki
farklılık platform kısıtından doğuyor. **Bir sonraki oturum bunları "eksik"
sanıp web'e dokunmasın.** Yalnızca ölçülebilir yeni bir fayda (gerçek bir
kullanıcı şikâyeti, ölçülen bir hata) çıkarsa yeniden değerlendirilir.

- ~~**Raf başlığındaki swap aksiyon metni**~~ → **ARTIK FARK YOK
  (17 Ağustos 2026):** kullanıcı Blok 6 görsel turunda iki ekranı yan yana
  koyup metni web'den de kaldırttı (*"ismin yanında ayrıca mesaj yazmamalı,
  mesaj satırında zaten yazıyor"*) — yani 6 Ağustos'ta port için verilen
  karar on bir gün sonra web'e de uygulandı. `Rack.tsx` artık koşulsuz
  yalnızca adı basıyor. Bilgi kaybı yok, ölçüldü: swap modu adın altın
  rengi (`#D97706`), sağdaki "N seçili" sayacı, mesaj satırındaki talimat
  ve DEĞİŞTİR/VAZGEÇ butonlarıyla belli. Portta bu davranışı koruyan bir
  test zaten var (`game_screen_test.dart` → `findsNothing`).
- **Anlam metnindeki `►`** — uygulama bunu `→` ile değiştiriyor (bkz.
  Parça 9). Web'de aynı karakter duruyor ve DÜZGÜN çiziliyor: tarayıcılar
  karakter bazında sistem yedeğine düşer (Chromium'da ekran görüntüsüyle
  doğrulandı). ÖLÇÜLDÜ: web'in subset woff2'lerinde (225-333 glyph) ne `►`
  ne `→` var — yani web'de ikisi de yedek fonttan basılır, `→`ye geçmek
  tipografik bir kazanç SAĞLAMAZ, yalnızca iki platformun metnini aynı
  yapardı. Flutter'da ise fark gerçek (tam TTF'lerde `→` var, `►` yok).

Eski (silinmiş) başlık: "Web'de Bekleyen Küçük Düzeltmeler" — o hâliyle
liste bir iş kuyruğu gibi okunuyordu; kullanıcı kararıyla anlamı değişti.

- ~~**Raf başlığındaki swap aksiyon metni**~~ → kapandı, yukarıdaki
  (17 Ağustos 2026) nota bkz. — metin web'den de kaldırıldı.
- **Anlam metnindeki `►` (opsiyonel, web BOZUK DEĞİL)** — uygulama bunu
  `→` ile değiştiriyor (bkz. Parça 9). Web'de aynı karakter duruyor ve
  DÜZGÜN çiziliyor: tarayıcılar karakter bazında sistem yedeğine düşer
  (Chromium'da ekran görüntüsüyle doğrulandı). ÖLÇÜLDÜ: web'in subset
  woff2'lerinde (225-333 glyph) ne `►` ne `→` var — yani web'de ikisi de
  yedek fonttan basılır, `→`ye geçmek tipografik bir kazanç SAĞLAMAZ,
  yalnızca iki platformun metnini aynı yapar. Tek satırlık değişiklik
  (`MeaningModal.tsx`), aciliyeti yok.

   - ✅ **Parça 49 — geri bildirim kuyruğunun flush'ı YALNIZCA uygulama
     açılışında koşuyordu; "Setup'a her geliş" notu yanlıştı (10 Ağustos
     2026, `setup_screen.dart`):** TESTING.md 9.5 (offline kuyruk) cihazda
     GEÇTİ — ama testten önce verdiğim tahmin ("Setup'a dönüş yetmeyecek")
     kodun gerçeğiyle uyuşuyordu, o yüzden geçişin sebebi kontrol edildi.
     - **Bayat varsayım:** `flushPending()` yalnızca `initState`'te
       çağrılıyordu ve yanındaki yorum bunu "mobil karşılığı Setup'a her
       geliş" diye anlatıyordu. Doğru DEĞİL: `SetupScreen`
       `MaterialApp.home`, oyunlar `Navigator.push` ile açılıyor, yani ekran
       hiç unmount OLMUYOR — `initState` uygulama başına BİR KEZ koşuyor.
       Yani Setup'ta otururken ağ dönerse kuyruk, uygulama yeniden
       başlatılana kadar bekliyordu.
     - **Cihaz testinin geçmesi bu boşluğu çürütmez:** web derlemesinde
       Safari sekmeyi (özellikle uçak modundan sonra) yeniden yükleyebiliyor
       ve her yeniden yükleme TAZE bir `initState` demek — bölüm 8'de aynı
       davranış zaten gözlenmişti. Native'de böyle bir yeniden yükleme yok.
       **Ders: "test geçti" ile "kod doğru" farklı şeyler; testin hangi
       MEKANİZMAYLA geçtiği doğrulanmadan bir gap kapanmış sayılmaz.**
     - **Düzeltme, Parça 44'ün simetriği:** `didChangeAppLifecycleState`'in
       `resumed` dalı artık `_scheduleCloudSync()`in yanında
       `feedback?.flushPending()` de çağırıyor. Debounce YOK ve gerekmiyor —
       kuyruk boşken `flushPending` ağa hiç dokunmadan erken dönüyor
       (`readAll` boşsa 0), yani her öne dönüşte çağırmak bedelsiz.
       Yanıltıcı `initState` yorumu da düzeltildi.
     - **Test — negatif eş doğrulamasıyla:** `setup_cloud_test.dart`'a yeni
       bir test; gerçek `FeedbackRepo` sqflite'a bağlı olduğundan (ve onun
       gerçek I/O'su testWidgets'ın sahte zaman bölgesinde çözülmediğinden —
       Parça 6 dersi) `flushPending`i override eden bir `SpyFeedbackRepo`
       kullanılıyor: ölçülen şey deponun kendisi değil KABLO. Mount'ta 1,
       paused→resumed sonrası 2 çağrı. `setup_screen.dart` `git stash` ile
       geri alınınca test GERÇEKTEN `+0 -1` ile düştü, geri konunca yeşile
       döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 301/301
       yeşil** (300'den +1). `kelimeki_core`'a hiç dokunulmadı.
     - **Kalan sınır (Parça 44'ün aynısı):** uygulama ÖNDEYKEN ağ geri
       gelirse (öne dönüş olayı hiç oluşmadan) kuyruk yine bekler — web'in
       `online` olayının tam karşılığı Flutter'da paketsiz yok. Veri kaybı
       riski yok (kuyruk kalıcı, 7 gün TTL), yalnızca gecikme.

   - ✅ **Parça 50 — "Kalan Taşlar" ham `Dialog`taydı (Parça 26/47'nin ÜÇÜNCÜ
     örneği) + oyun sonu butonu web'de büyürken portta küçük kalıyordu
     (10 Ağustos 2026, `remaining_tiles_modal.dart`, `game_screen.dart`,
     `online_game_screen.dart`):** Kullanıcı bölüm 10'a başlamadan iki
     bulgu bildirdi; ikisi de web kaynağı okunarak teşhis edildi.
     - **(a) Torba dökümü iPad'de devasa açılıyordu.** Web
       `RemainingTilesModal.tsx` paylaşılan `Modal`'ı (360px kart)
       kullanıyor ve hücreleri `h-12` ile **sabit 48px** yüksekliğe
       bağlıyor. Port kendi `Dialog`'unu kuruyor (üst sınır YOK — geniş
       ekranda kart yayılıyor) ve `childAspectRatio: 1.05` ile KARE hücre
       üretiyordu, yani kart genişledikçe taşlar da büyüyordu.
       **`KModal` + `GridView.builder(mainAxisExtent: 48)`'e taşındı** —
       Parça 47'de joker seçicide öğrenilen aynı iki ders (`GridView.count`
       sabit yükseklik veremiyor; ham `Dialog` üst sınır taşımıyor).
       Yan kazanç, yine Parça 47'deki gibi: başlık artık `KModal`
       üzerinden `trUpper`dan geçiyor ("KALAN TAŞLAR") — web'in
       `uppercase` CSS'iyle hizalandı, port düz "Kalan Taşlar" yazıyordu.
     - **ÜÇÜNCÜ kez aynı sınıf:** GameOver (Parça 26), joker seçici (47),
       şimdi bu. `modal_shell.dart`'ın kendi başlığındaki "diğer ikisi de
       buna taşındı" notu bu parçaya kadar GERÇEK DEĞİLDİ. **Yeni bir
       modal eklerken ilk soru "web hangi bileşeni kullanıyor?" olmalı;
       ham `Dialog` kurmak neredeyse her zaman bir sapma.**
     - **(b) Oyun sonu butonu.** Web'de raf satırındaki buton oyun bitince
       "Yeni Oyun Aç"a dönüşüyor ve `text-[15px]` + `px-5` ile OYNA'dan
       (`text-[12px]`) belirgin BÜYÜK oluyor; raf `flex-1 min-w-0`
       olduğundan daralıyor — kullanıcının tarif ettiği "1-2 taş kalınca
       buton büyüyor, Yeni Oyun Aç dikkat çekiyor" etkisi bu. Port
       etiketi `'YENİ\nOYUN'` diye ELLE iki satıra bölüp 13px'te
       bırakmıştı, yani buton hiç büyümüyordu. Tek satır + 15px yapıldı;
       OYNA da 13→12px'e (web değeri) çekildi. Canlı ekranın karşılığı
       (`'CANLI\nLİSTESİ'`, 12px, `horizontal: 16`) aynı şekilde tek satır
       15px + 20 padding oldu — iki ekran "bilinçli kod tekrarı" çifti
       olduğundan AYNI PR'da (bkz. "Etki Analizi").
     - **Rafın daralması ek bir iş gerektirmedi:** portun rafı zaten
       `Expanded` ve taşları `Expanded` (web'in `repeat(N, 1fr)`
       karşılığı), yani buton büyüyünce taşlar web'deki gibi kendiliğinden
       inceliyor.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** (1) GENİŞ bir
       yüzeyde (1200×900 — hatanın gerçekten göründüğü iPad koşulu) kartın
       360px `ConstrainedBox`'ı ve hücre yüksekliğinin tam 48 olduğu;
       (2) OYNA'nın 12, oyun bitince "YENİ OYUN AÇ"ın 15 punto olduğu.
       İki lib dosyası AYRI AYRI `git stash`lenip her iki test de GERÇEKTEN
       `+0 -1` ile düştü, geri konunca yeşile döndü. Mevcut TORBA testi de
       yeni büyük harfli başlığa güncellendi.
     - **Test tuzağı (yeni):** 1200×900'de dikey içerik viewport'u aştığından
       "TORBA" düğmesi ekran dışında kalıyor ve `tap` sessizce ıskalıyordu —
       modal hiç açılmadan test "0 widget" diye düşüyor, sebep yanıltıcı
       görünüyor. `tester.ensureVisible` şart; ayrıca modalın gerçekten
       açıldığını doğrulayan bir ara `expect` eklendi ki bir daha aynı hata
       yanlış yeri işaret etmesin.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 303/303
       yeşil** (301'den +2). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor —
       `mobile/TESTING.md` bölüm 1'e iki yeni madde eklendi.

   - ✅ **Parça 51 — GİZLİLİK: bitmiş Canlı oyunun sohbet arşivi GİRİŞLİ
     HERKESE açıktı (10 Ağustos 2026, `game_chat_archive_participants_only`
     migration'ı + web `api.ts`/`GameChatHistoryModal.tsx`/`PrivacyModal.tsx`
     + mobil `games_api.dart`/`game_chat_history_modal.dart`):** Kullanıcı
     sordu: "k-lig'den kişiye tıklayıp skor kartına, oradan tüm oyunlarına
     erişiliyor — sohbet geçmişleri de ulaşılabilir oluyor, değil mi?"
     Haklıydı.
     - **Önce ÖLÇÜLDÜ, tahmin edilmedi:** `games`in tek SELECT politikası
       `games_select_authenticated` = `auth.uid() IS NOT NULL` — satır
       sahipliğine hiç bakmıyor. Canlıda gerçek bir oyunla, o oyuna hiç
       katılmamış bir hesabın kimliğiyle (`set local role authenticated` +
       `request.jwt.claims`) sorgulandı: **5 mesajın tamamı gönderen
       adlarıyla geldi.**
     - **Arayüzde ikon gizlemek çözüm DEĞİL:** `anon` anahtarı JS paketinde
       herkese açık, yani hesabı olan herkes doğrudan `select=messages`
       çekebilirdi. Düzeltmenin veritabanında olması şarttı.
     - **Postgres tuzağı (bu iş sırasında öğrenildi):** tablo düzeyinde
       SELECT verilmişken `revoke select (messages)` ETKİSİZ. Tablo yetkisi
       kaldırılıp kalan 21 kolon tek tek verilmek zorunda — **`games`e yeni
       bir kolon eklenirse bu listeye de eklenmeli**, yoksa istemci onu hiç
       okuyamaz (sessiz bir "kolon yok" hatası olarak görünür).
     - **Yeni `game_chat_archive(p_game_id)` RPC'si** (security definer):
       `is_online_game_participant` ya da `is_admin()` ise
       `{allowed:true, messages:[…]}`, değilse `{allowed:false,
       messages:[]}`. Var olmayan oyunda da yetkisizle AYNI cevap (varlık
       sızdırmamak için). Yerel/YZ oyunlarda (`online_game_id is null`)
       sohbet kavramı yok, `allowed:true` + boş dönüyor.
     - **`allowed` içerikten AYRI taşınıyor** — "hiç mesaj yok" ile "görme
       yetkin yok" iki farklı durum; yetkisiz kullanıcı artık boş bir
       arşiv değil **"Yazışmaları görmeye yetkiniz yok."** görüyor
       (kullanıcı isteği). Ağ/parse hatasında `allowed:true` dönülüyor —
       geçici bir hata yüzünden kullanıcıya yanlışlıkla "yetkin yok"
       dememek için.
     - **`message_count` de AYNI GÜN kapatıldı (ikinci yarı,
       `chat_count_participants_only` migration'ı):** İlk sürümde sayaç
       bilerek okunabilir bırakılmıştı ("rozet fazladan istek atmadan
       çizilsin; sızan bilgi yalnızca N, içerik değil"). Kullanıcı bunu
       yeniden değerlendirip *"sadece yetkisi olanlara gözüksün"* dedi —
       haklı: "X ile Y şu oyunda N kez mesajlaştı" da bir üstveri ve rozet
       zaten AÇILAMAYAN bir kontroldü (dokununca "yetkiniz yok").
       - **Maliyet sıfıra yakın, çünkü liste zaten sayfa başına TEK toplu
         RPC çağırıyor:** `game_like_stats(p_game_ids)`. Sayaç oraya
         eklendi — EK BİR GİDİŞ-DÖNÜŞ YOK. Kolon grant listesinden düştü
         (21 → 20), `fetchMyGames`/`GamesRepo.history` artık sayacı
         satırdan DEĞİL bu RPC'den okuyor.
       - **Fonksiyon SECURITY DEFINER olmak ZORUNDA kaldı:** kolon istemci
         rollerinden kalkınca INVOKER bir fonksiyon onu okuyamaz. Definer'da
         RLS bypass edildiğinden misafirin (uid null) hiçbir satır alamaması
         davranışı `auth.uid() is not null` ile ELLE korundu. Sayaç
         `is_admin() OR is_online_game_participant(...)` değilse 0; yerel
         oyunlarda (`online_game_id is null`) zaten 0.
       - **`list_liked_games` dönüşünden `message_count` çıkarıldı** —
         sayaç iki sekmede de tek kaynaktan geliyor.
       - **Ad BİLEREK değişmedi:** `game_like_stats` artık kartın tüm
         rozetlerini besliyor, adı dar kalıyor; ama canlıdaki web bu adı
         çağırıyor — yeniden adlandırmak deploy'a kadar beğenileri de
         kırardı. Yeni kolon eklemek eski istemciyi etkilemiyor (fazladan
         alanı yok sayıyor).
       - **Test:** yetkisiz oyunun kartında rozetin HİÇ çizilmediğini,
         yetkilide sayının göründüğünü doğrulayan ikinci bir test;
         `FakeGamesGateway.likeStats` artık `unauthorizedChats` kapısını da
         taklit ediyor (sahte uç gerçek ucun HER kararını taklit etmeli —
         Parça 46'nın dersi). Kapı sahteden kaldırılınca test GERÇEKTEN
         düştü, geri konunca yeşile döndü.
     - **Etki taraması yapıldı, kırılan yok:** iki istemcide de `games`
       üzerinde hiç `select('*')` yok (hepsi açık kolon listesi); `games`i
       okuyan 13 fonksiyonun hiçbiri `messages` döndürmüyor; SECURITY
       INVOKER olan üçü (`list_liked_games`, `game_like_stats`,
       `toggle_game_like`) gövdelerinde bu kolona hiç dokunmuyor. Canlıda
       doğrulandı: liste sorgusu, `board_snapshot`, `message_count` ve
       `list_liked_games` düzeltmeden sonra da çalışıyor; katılımcı RPC ile
       5 mesajı görüyor, katılımcı olmayan hem doğrudan okumada
       `insufficient_privilege` alıyor hem RPC'den `allowed:false`.
     - **Doküman senkronu (kuralın gereği):** kök `CLAUDE.md`'nin Faz 1
       sohbet bölümündeki *"bu yeni alan aynı görünürlük seviyesinde
       kalıyor, yeni bir gizlilik sorunu yaratmıyor"* cümlesi YANLIŞTI —
       düzeltildi ve dersi yazıldı. `PrivacyModal`'ın "tüm kayıtlı
       kullanıcılara açık" ifadesi de artık gerçeğe uymuyordu; "yalnızca o
       oyunun katılımcılarına ve yönetici ekibine açıktır" olarak
       değiştirildi, "Son güncelleme" 10 Ağustos 2026'ya çekildi.
     - **Test — negatif eş doğrulamasıyla:** `game_likes_test.dart`'a
       yetkisiz durumun mesajı GÖSTERMEDİĞİNİ ve "yetkiniz yok" metnini
       gösterdiğini doğrulayan yeni bir test; `FakeGamesGateway`'e gerçek
       uçtaki katılımcı kapısının karşılığı olan `unauthorizedChats`
       eklendi. `_allowed = res.allowed` satırı `true`ya sabitlenince test
       GERÇEKTEN düştü, geri konunca yeşile döndü.
     - Doğrulama: web `npm run lint` + `npm run build` temiz; mobil
       `flutter analyze` temiz, **tam takım 305/305 yeşil** (303'ten +2 —
       biri içerik kapısı, biri rozet kapısı).
     - **CANLIDA, İKİ YÖNLÜ doğrulandı (10 Ağustos 2026 akşamı, gerçek
       hesapla):** yetkisiz kullanıcı başkasının oyununda rozeti HİÇ
       görmüyor, kendi katıldığı oyunda rozet görünüp sohbet açılıyor.
       İkinci yön şart: "yabancıda ikon yok" tek başına, rozet HERKES için
       bozulsaydı da doğru çıkardı — iki durum dışarıdan aynı görünür.
       (Kök CLAUDE.md'nin "aradığın davranışın YOKLUĞUNDA da geçen bir
       kontrol bir şey kanıtlamaz" dersinin canlı örneği.) Ayrıca
       production bundle'ı (`index-6EThUgtN.js`) doğrudan indirilip
       `game_chat_archive`/`game_like_stats`/"Yazışmaları görmeye yetkiniz
       yok." dizelerinin ve liste sorgusundan `message_count`'un
       ÇIKARILDIĞININ orada olduğu teyit edildi.
     - **Ders: "bu satır zaten herkese açık, o hâlde yeni kolon da sorun
       değil" akıl yürütmesi KOLON bazında yeniden sorulmalı** — aynı
       satırda kamuya açık (skor, tahta) ve mahrem (yazışma) veri bir arada
       olabilir.

   - ✅ **Parça 52 — arkadaşlık satırlarında metin butonları ikonlara indi
     (11 Ağustos 2026, `friends_modal.dart`, `player_score_card_modal.dart`
     + web `RelationIcons.tsx`/`FriendsModal.tsx`/`PlayerScoreCard.tsx`):**
     Kullanıcı isteği — "Ara & Ekle ve Arkadaşlar sekmesinde yazı yerine
     ikonlar; ekle/çıkar butonları kalkacak". Parça 42'de (dün) yalnızca
     `PlayerScoreCard`'ın simgesi iki platformda aynı vektöre çekilmişti; bu
     onun listelere yayılmış hâli.
     - **Kural — ikon, DOKUNUŞUN NE YAPACAĞINI söyler, ilişkinin adını
       değil.** Bu yüzden "arkadaşsınız" durumu yeşil `check_circle` DEĞİL
       kırmızı `person_remove`: dokunulunca yapılan şey çıkarmak. Yeşil onay
       durumu anlatıyordu, eylemi değil — Parça 42'de "keşfedilebilirlik
       zayıf" diye not düşülen zaaf tam buydu ve kullanıcının "adam-" fikri
       onu kapattı. `check_circle` artık HİÇBİR yerde kullanılmıyor.
     - **Dört durum, dört glyph** (iki platformda aynı): `person_add_alt_1`
       (mavi, ekle) · `hourglass_top` (gri, istek gönderildi → iptal) ·
       `how_to_reg` (mavi, gelen isteği kabul) · `person_remove` (kırmızı,
       çıkar). "İstekler" sekmesindeki Kabul Et/Reddet butonlarına
       DOKUNULMADI — orası bir durum değil iki ayrı karar.
     - **Kum saatini kullanıcı seçti** (saat/kum saati/üç nokta üçlüsü
       gerçek fontla çizilip gösterildi). Karar öncesi ölçüm: `flutter build`
       gerekmeden, glyph'ler fonttan çıkarılıp bir HTML mock'una konup
       Chromium'da render edildi — tasarım tercihi tarif edilerek değil
       GÖRÜLEREK verildi.
     - **Bulunan tuzak — codepoint'i hafızadan yazma:** ilk denemede
       `schedule`/`person_remove` vb. kodlarını hafızadan yazdım ve tamamen
       başka glyph'ler çıktı (saat yerine hamburger çizgi, person_remove
       yerine `<>`). `cmap`'te "o kodda bir glyph VAR" demek aradığın ikon
       olduğu anlamına GELMİYOR. Tek doğru kaynak Flutter'ın kendi
       `packages/flutter/lib/src/material/icons.dart`'ı; ayrıca font olarak
       `bin/cache/artifacts/material_fonts/` kopyası kullanılmalı (devtools
       altındaki ayrı bir sürüm). Hata yalnızca ÖNİZLEMEYİ render ettiğim
       için yakalandı — kod yazılsaydı sessizce yanlış ikon girecekti.
     - **Web'de path'ler tek dosyada:** `src/components/RelationIcons.tsx`
       (4 ikon). `PlayerScoreCard`'ın inline `PersonAddIcon`/`CheckCircleIcon`
       tanımları oraya taşındı — `FriendsModal` da aynı path'i kullandığından
       ikinci kopya açılmadı. Flutter tarafı fontu gömülü taşıdığından
       `Icons.*` doğrudan; yani iki platform BENZER değil AYNI vektör.
     - **44px dokunma hedefi + erişilebilirlik:** ikon 20px, etrafındaki
       görünmez alan 44px (iOS asgarisi; metin butonu bunu doğal olarak
       sağlıyordu). Metin kalktığı için `aria-label`/`Semantics.label` artık
       ekran okuyucunun TEK bilgi kaynağı — boş bırakılamaz.
     - **Yeni yol: "Ara & Ekle"den çıkarma.** `accepted` satırı eskiden
       tıklanamaz bir "Arkadaşsınız" metniydi; ikona dönünce çıkarma oradan
       da mümkün oldu (`_confirmThenRemoveCandidate` / web'de aynı onay
       state'i yapısal tiple paylaşıldı — ikinci bir diyalog açılmadı) ve
       sonrasında `patchRelation` ile ikon anında `person_add`'e dönüyor.
     - **Test — negatif eş doğrulamasıyla:** `friends_test.dart`'ın üç
       assertion'ı yeni ikonlara çevrildi (onay diyaloğundaki "ÇIKAR"
       METNİ kaldı — yalnızca satır ikonlaştı). İki lib dosyası `git stash`
       ile geri alınınca 3 test GERÇEKTEN düştü, geri konunca 15/15.
     - Doğrulama: `flutter analyze` temiz, **tam takım 305/305**; web
       `npm run lint` + `npm run build` temiz. Gerçek widget görüntüsü
       `build/screenshots/friends_modal.png`'de (kırmızı adam- ikonları).
     - **Doğrulama sınırı:** cihazda görsel/dokunma teyidi kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 10 buna göre güncellendi.
     - **AYNI GÜN, kullanıcının üç düzeltmesi (ikisi yukarıdaki kararları
       kısmen geri alıyor — kayda geçsin):**
       1. **"Ara & Ekle" artık arkadaşları HİÇ göstermiyor** — "onlar
          Arkadaşlarım altında var". Yani yukarıda "yan fayda" diye
          yazdığım *"Ara & Ekle'den çıkarma yolu açıldı"* pratikte ortadan
          kalktı; `accepted` dalı savunma amaçlı duruyor ama ulaşılamaz.
          **Eleme fetch'te DEĞİL render'da:** `_allUsers.length` sayfalama
          offset'i olduğundan diziden atmak sayfaları kaydırıp üye
          atlatırdı. İkinci incelik, Parça 31'in tekrarı: eleme sonrası
          liste kaydırılamayacak kadar kısa kalırsa `ScrollController`
          dinleyicisi HİÇ ateşlenmez ve sonraki sayfa gelmez —
          `_autoLoadIfNotScrollable` (post-frame `maxScrollExtent<=0`
          kontrolü) bunu kapatıyor, testi de var.
       2. **`PlayerScoreCard`'da arkadaş durumu yeşil `how_to_reg`** —
          kırmızı `person_remove` "ismin yanında iyi durmuyor". Bu, bu
          parçanın kendi kuralına ("ikon eylemi söyler") bilinçli bir
          istisna: listede ikon bir AKSİYON sütununda, kartta ismin
          yanında durup durum rozeti gibi okunuyor; dokunuş yine çıkarma
          onayını açtığından kural onay diyaloğuyla korunuyor. **Aynı
          glyph artık iki şey anlatıyor** (listede mavi = "gelen isteği
          kabul et", kartta yeşil = "arkadaşsınız") — renk ayrımı bu
          yüzden zorunlu, ikisini aynı renge çekme.
       3. **Denetim: "bütün ikon dokunuşları onay soruyor mu?"** — HAYIR
          soruyordu. `FriendsModal`'da "ekle" ve "kabul et" ANINDA iş
          yapıyordu; `PlayerScoreCard` ise dört dalın hepsinde onay
          soruyordu. Asimetri `_confirmThenAdd` ile kapatıldı (metin
          ilişkiden türetiliyor) + sonrasında sonuç mesajı. Denetim
          sırasında ikinci bir sapma da bulundu: skor kartının
          `pendingIncoming`/`null` onay metinleri web'in
          `friendDialogCopy`sinden sessizce ayrışmıştı ("İsteği Kabul
          Et"/"Gönder") — web'e hizalandı, artık uygulama içinde de tek
          dil. **Bilinçli kapsam dışı:** "İstekler" sekmesindeki metin
          butonlu "Kabul Et" (orası etiketli iki ayrı karar, kazara
          dokunma riski ikon kadar yüksek değil; "Reddet"in onayı zaten
          var).
       - Doğrulama: `flutter analyze` temiz, **tam takım 307/307** (+2
         yeni test: kabul de onaydan geçiyor + satır listeden düşüyor;
         bir sayfanın tamamı arkadaş çıkınca sonraki sayfa yine geliyor).
         Negatif eş: iki lib dosyası `git stash`lenince 4 test GERÇEKTEN
         düştü, geri konunca yeşile döndü. Web yarısı ayrı PR (#232).

   - ✅ **Parça 53 — kişiye dokunmak skor kartını açıyor: yalnızca
     "Arkadaşlarım"da vardı, üç listeye birden yayıldı (11 Ağustos 2026,
     `friends_modal.dart` + web `FriendsModal.tsx`):** Kullanıcı bildirdi —
     *"Arkadaşlarımda kişilere tıklayınca skor kartına gidiyorum ama Ara &
     Ekle'de bu yok. Bence orada da olmalı."*
     - **Web kaynağı önce okundu (kuralın ilk adımı) ve kullanıcıyı
       doğruladı:** `FriendsModal.tsx`'te yalnızca "Arkadaşlarım" satırı
       `setSelectedFriend(friendToPlayerSummary(f))` ile tıklanabilir;
       "İstekler" ve `renderFriendRow` (Ara & Ekle'nin hem arama hem "Tüm
       Üyeler" listesini besleyen ortak satırı) düz `<Avatar>`+`<span>`
       çiziyordu. Yani bu bir port sapması DEĞİL, iki platformda da olan
       bir eksikti — düzeltme İKİ tarafa birden yazıldı.
     - **"İstekler" de dahil edildi (kullanıcı yalnızca Ara & Ekle'yi
       söylemişti):** kapsamı KENDİ genişletmek de daraltmak kadar riskli
       (bkz. Parça 36'nın dersi), bu yüzden gerekçe açıkça yazılıyor ve
       kullanıcıya bildirildi: bir arkadaşlık isteğini yanıtlamadan önce
       gönderenin kartına bakmak, üç listenin İÇİNDE bu davranışın en
       faydalı olduğu yer. İstenmezse tek satırlık geri alma.
     - **Ortak `_personButton(id, name, avatarUrl)` (web'de aynı işi yapan
       `personButton`)** — üç liste de bunu kullanıyor; "Arkadaşlarım"ın
       kendi satır-içi kopyası silindi, ikinci bir tıklama yolu açılmadı.
       Web'de `friendToPlayerSummary(f: FriendRow)` yerini genel bir
       `toPlayerSummary(id, name, avatarUrl)`e bıraktı — üç listenin veri
       tipi farklı (`FriendRow` / `IncomingRequest` / `FriendSearchResult`),
       ortak olan yalnızca bu üç alan.
     - **Kart kapanınca ilişki TAZELENİYOR** (`closeSelectedFriend`):
       `PlayerScoreCard`'ın kendi arkadaşlık simgesinden ekleme/çıkarma
       yapılabildiğinden, kapanışta `fetchFriendRelation` +
       `patchRelation` ile satırın ikonu güncelleniyor, ayrıca iki liste
       yeniden çekiliyor. Bu olmadan kartta "çıkar"a basıp kapatan
       kullanıcı, satırda hâlâ eski ikonu görürdü — Parça 52'nin
       "aksiyondan sonra ikon anında değişmeli" davranışının kardeşi.
     - **Dokunma alanı ile aksiyon ikonu AYRIŞIK:** kişi butonu
       `Expanded`/`flex-1` ile satırın metin+avatar kısmını kaplıyor,
       ikon kendi 44px hedefinde kalıyor — yani "karta git" ile "ekle/
       çıkar" birbirini yutmuyor (Parça 52'nin 44px kuralı korunuyor).
     - **Test — negatif eş doğrulamasıyla:** `friends_test.dart`'a üç
       listede de dokunuşun `PlayerScoreCardModal`'ı açtığını doğrulayan
       yeni bir test; `pumpModal`'ın `withStats` bayrağı bunun için var
       (kart `StatsRepo` olmadan hiç açılmaz). `friends_modal.dart`
       `git stash` ile geri alınınca test GERÇEKTEN düştü (`Expected:
       exactly one matching candidate / Actual: Found 0 widgets with type
       "PlayerScoreCardModal"`), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       308/308 yeşil** (307'den +1). Web `npm run lint` + `npm run build`
       temiz. `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda dokunma teyidi kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 10'a madde eklendi.

   - ✅ **Parça 54 — renk denetimi: "iki ayrı yeşil" bir yeşil sorunu
     DEĞİLDİ, palet sürüklenmesiydi; `ui/tokens.dart` ile yapısal olarak
     kapatıldı (11 Ağustos 2026, 30 dosya + yeni `test/color_tokens_test.dart`):**
     Parça 42'nin açık bıraktığı iş ("11 `_green` kullanım yeri site site
     denetlenmedi") kullanıcı isteğiyle koşuldu. Denetim, aranan hatanın
     çok ötesini buldu.
     - **Web'in gerçeği önce sabitlendi (kuralın ilk adımı):**
       `tailwind.config.js`'te `green: #16A34A` / `red: #DC2626` /
       `gold: #B7791F` / `muted: #5A6673`. Bunların DIŞINDA yalnızca İKİ
       sabit-yazılmış renk var ve ikisi de **tek bir dosyada**,
       `Board.tsx`: `#1FA05C`/`#E0483A` (hamle dış hattı + puan rozeti +
       sürükleme hedefi çerçevesi). Üçüncü bir istisna `Rack.tsx`'in swap
       başlığındaki `#D97706`. Hepsi grep'le doğrulandı, hafızadan
       yazılmadı.
     - **Bulgu — sapma yeşille sınırlı DEĞİLDİ:** portun her dosyası kendi
       `const Color _x = ...` kopyasını taşıyordu ve kopyalar ayrışmıştı.
       `_red` **13 dosyada iki değere** bölünmüştü (8 dosya `#E0483A`, 5
       dosya `#DC2626`) — yani aynı hata kırmızıda yeşilden DAHA yaygındı.
       Üstelik `count_badge.dart`'ın satırında `// web bg-red` yorumu VARDI
       ve yine yanlış değeri taşıyordu: yorum niyeti doğru yazıyor, değer
       yanlış. Ek olarak `chat_settings_modal`'ın `_void`'i `#EDF1F7`
       (portun ESKİ sayfa zemini) — web'in `#E8EBEF`'i değil.
     - **İki oyun ekranının mesaj rengi haritası DÖRT dalıyla birden
       yanlıştı:** web `MESSAGE_COLORS` dördü de token
       (`text-red/green/gold/muted`); port `#E0483A`/`#1FA05C`/`#D97706`/
       `#5B6472` kullanıyordu. Sonuncusu hiçbir yerde karşılığı olmayan,
       uydurulmuş bir değerdi; `#D97706` ise `Rack.tsx`'ten yanlış yere
       taşınmıştı (orada doğru, burada değil).
     - **Düzeltme yapısal:** yeni `lib/src/ui/tokens.dart`
       (`kText/kMuted/kAccent/kBorder/kRed/kGreen/kGold/kPanel/kVoid/
       kOrange/kBg`) tailwind paletinin TEK Dart karşılığı; tahtaya özel
       ikili ayrı ve AÇIKÇA token-olmayan adlarla (`kMoveValid`/
       `kMoveInvalid`) duruyor ki bir daha karıştırılmasın. 30 dosyadaki
       yerel kopyalar migrasyonla tokenlara bağlandı. Beyaz (`#FFFFFF`)
       bilinçli olarak KAPSAM DIŞI: `bg` ve `tile-bg` aynı değere sahip,
       bir literalden hangisi olduğu anlaşılamaz.
     - **Regresyon koruması — 3 test, ikisi kaynak tarayıcı:** (1)
       `tokens.dart` gerçekten `tailwind.config.js`'i mi taşıyor (test
       web'in dosyasını OKUYUP karşılaştırıyor — web bir rengi değiştirir
       ve port takip etmezse düşer); (2) `lib/` altında token değerini
       tekrar yazan bir literal kaldı mı (yeni yerel kopyayı yakalar); (3)
       `kMoveValid/kMoveInvalid` yalnızca o üç dosyada mı kullanılıyor.
       **Negatif eş, ikisi de ayrı ayrı:** `kRed` eski yanlış değere
       çekilince test 1 GERÇEKTEN düştü (`"red" web ile ayrışmış`),
       `chat_modal`'a yerel kopya geri konunca test 2 GERÇEKTEN düştü
       (dosya adını ve doğru token'ı işaret ederek).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       311/311 yeşil** (308'den +3). `kelimeki_core`'a hiç dokunulmadı
       (motor renk tutmuyor). Ekran görüntüleri gözle kontrol edildi.
     - **Ders — "denetle" istenen şeyin sınırında durma:** görev "11
       `_green` kullanım yerini kontrol et"ti; aynı taramayı kırmızıya
       uygulamak sıfır ek maliyetti ve iki katı hata çıkardı. Bir hatayı
       ÜRETEN mekanizma (her dosyada yerel palet kopyası) bulunduğunda,
       o mekanizmanın ürettiği DİĞER örnekleri de ara — tek renk düzeltmek
       `isMyTurn ? _green : _red` gibi satırları yarı-doğru bırakırdı.
     - **Denetimde bulunan ama bu parçada bilinçli olarak ERTELENEN iki
       şey** (renk değil, ayrı sınıf): `live_games_tab`'ın durum etiketi
       puntosu ve "Sınır İhlali!" diyaloğunun vurguları — kullanıcı isteğiyle
       AYNI GÜN Parça 55'te kapatıldı, aşağı bkz.

   - ✅ **Parça 55 — Parça 54'ün ertelediği iki madde (11 Ağustos 2026,
     `live_games_tab.dart`, yeni `ui/game/invasion_confirm.dart`):**
     - **(a) Durum etiketi 10px'ti, web'de `text-[11px]`.** Düzeltirken
       KARDEŞİNE de bakıldı ve ikinci bir sapma çıktı: `PendingGameCard`'ın
       kalan-süre etiketi 8px, web'de `text-[9px]`. **İkisi karıştırılmamalı**
       — aktif satırdaki kalan-süre GERÇEKTEN 8px (web'de de öyle), yani
       "hepsini eşitle" yanlış olurdu; üç etiketin üçü de ayrı ayrı web
       kaynağından okundu.
     - **(b) "Sınır İhlali!" onayı düz metindi**, web'de kazanılacak puan
       yeşil + kalın, her bölge sahibine giden pay kırmızı + kalın, sahibin
       adı yalnızca kalın (`<strong>` rengi yok — gövde rengini miras alıyor,
       bu ayrım testte de sabitlendi).
     - **Diyalog PAYLAŞILAN bir dosyaya çıkarıldı** (`showInvasionConfirm`).
       `game_screen` ↔ `online_game_screen` çifti sürükleme/joker/mesaj
       desenini bilinçli olarak ayrı taşıyor, ama bu diyalog o desenlerden
       biri değil: iki ekranda BİREBİR aynı metin + aynı vurgu kuralı, ve
       düz-metin hâli de iki kopya olarak duruyordu. `invasionShare`
       formülünün core'da tek kopya tutulmasıyla aynı gerekçe. Yan fayda:
       tek bir izole test iki ekranı birden kapsıyor.
     - **Test — negatif eş, ikisi için ayrı ayrı:** punto 10'a geri
       çekilince `Expected: <11> Actual: <10.0>` ile, span stilleri
       kaldırılınca ilgili test GERÇEKTEN düştü; ikisi de geri konunca
       yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       312/312 yeşil** (311'den +1; punto kontrolü mevcut teste eklendi,
       ayrı test SAYILMIYOR). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor —
       `mobile/TESTING.md` bölüm 11'e madde eklendi.

   - ✅ **Parça 56 — genel tasarım denetimi: EN BÜYÜK fark gölgelerdi, punto
     değil (11 Ağustos 2026, 8 dosya):** Kullanıcı aynı Setup ekranının app
     ve web ekran görüntüsünü yan yana koyup *"küçük font size, type, kutu
     ölçüleri vb tüm tasarımsal farklılıkları analiz et… her şeyin web ile
     uyumlu olup olmadığını kontrol et"* dedi.
     - **Yöntem — Tailwind sınıfından zihnen türetme YOK (Parça 33 dersi):**
       `npm run build` ile derlenen GERÇEK CSS, Chromium'da (Playwright)
       render edilip `getComputedStyle`/`getBoundingClientRect` ile okundu.
       Bu, ilk hipotezimi bir kez çürüttü: alt sekmelerin `py-2` (8px)
       olduğunu sanıp "port 10 kullanıyor, fark var" diye not almıştım —
       ölçüm web'in `py-2.5` (10px) olduğunu, yani portun DOĞRU olduğunu
       gösterdi. Ölçmeden düzeltseydim çalışan bir değeri bozacaktım.
     - **Asıl bulgu, tek tek farklardan büyük: web'in `shadow-raised`/
       `btn-raised*` gölgeleri kartlarda ve sekmelerde HİÇ port edilmemişti.**
       Port yalnızca BUTONLARA (NeoButton) gölge veriyordu; kart/panel/
       istatistik kutusu/alt sekme düz `BoxDecoration` idi. Kullanıcının
       "app daha düz duruyor" izlenimi tam olarak buydu. **10 site**
       düzeltildi: Canlı oyun kartı, davet kartı, iki alt sekme çubuğu
       (Setup + Canlı), "Son Oynadıklarım" satırı, skor kartı sekmesi +
       istatistik kutusu, oyun geçmişi kartı, Setup oyuncu satırı, Devam
       Eden Oyun satırı.
       - `shadow-raised` ile `btn-raised-neutral` index.css'te BİREBİR AYNI
         iki katman — `kRaisedShadows`; seçili/accent yüzeyler üç katmanlı
         `kRaisedAccentShadows` (ikisi de `neo_box.dart`).
       - `ShapeDecorationWithCssShadows`'a `borderColor`/`borderWidth`
         eklendi. **`padding` override'ı kritik:** `Decoration.padding`
         çocuğu çerçeve kadar içeri iter, yani BoxDecoration'dan geçen bir
         kutunun DIŞ ölçüsü birebir korunuyor — gölge eklerken düzen kaymadı.
     - **Ölçülen ve düzeltilen metrik farkları:**
       | Yer | Web (ölçüldü) | Port (öncesi) |
       |---|---|---|
       | Setup: logo → paragraf | 20px | 16 |
       | Setup: paragraf → link satırı | 16px | 12 |
       | Setup: paragraf satır yüksekliği | 12/16px (`text-xs`) | 1.5 (=18) |
       | Arkadaşlar: sekme puntosu | 11px | 10 |
       | Arkadaşlar: küçük buton dolgusu | 6/12px (`py-1.5 px-3`) | 7/10 |
       | Sohbet balonu satır yüksekliği | 1.375 (`leading-snug`) | 1.35 |
       İlk ikisinin kök sebebi ortak ve öğreticiydi: web'de blok `gap-1`
       taşıyor VE çocuklar `mt-4`/`mt-3` — flexbox'ta **gap ile margin
       TOPLANIR**, port yalnızca margin'i taşımıştı.
     - **Setup'ın en altındaki "Kullanım Koşulları · Gizlilik Politikası"
       satırı porta hiç girmemişti** — modaller vardı ama yalnızca kayıt
       formundan ulaşılabiliyordu. Eklendi (web'le aynı 10px mono/muted).
       Teşhis satırı (`Sürüm … · depo ok`) BİLİNÇLİ olarak duruyor: web'de
       karşılığı yok ama cihaz testinde aktif olarak kullanılıyor (Parça
       45'te tam bu yüzden eklendi), hukuki satırın ALTINA alındı.
     - **Doğrulanan ve DEĞİŞTİRİLMEYENLER** (ölçüldü, zaten doğru): modal
       kabuğu (360px/12px radius/#B8C2D1/başlık 14px-1.5ls/gövde dolguları),
       oyun kartı dolgusu 8/10, skor istatistik kutusu 12/4, k-lig satırı
       6/8, oyun geçmişi filtre sekmesi 11px/6px, sohbet balonu 10/6 + 12px
       radius, Setup bölüm etiketi ve OYUN TİPİ butonu.
     - **Test — negatif eş, iki ayrı kanıt:** Setup geometrisi (20/16px +
       12/16 satır + hukuki satır) ve gölgelerin varlığı ayrı testlerde
       sabitlendi. Eski boşluklar geri konunca `Expected: a numeric value
       within <1.5> of <16> / Actual: <12.0>`, gölgeler geri alınınca
       "oyun kartı/pasif sekme gölgesiz kalmamalı" ile GERÇEKTEN düştüler.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       313/313 yeşil** (312'den +1). İlk koşuda 1 test düştü ama iki temiz
       koşu daha yapıldı ve tekrarlamadı — bu, Parça 13/21'de belgelenen
       sqflite yazma-kilidi timer flake'i, bu parçayla ilgisiz.
       `kelimeki_core`'a hiç dokunulmadı.
     - **Denetimde bulunan ama BU PARÇADA düzeltilmeyen iki şey** (ikisi de
       ayrı bir tur istiyor, aşağıdaki "Sonraya Bırakılan İşler"e eklendi):
       metin girişi dolgusu (port v10, web `py-2`=8) ve `InputDecoration`ın
       8 dosyada kopyalanmış olması — ikincisi Parça 54'teki renk
       sürüklenmesiyle AYNI sınıf bir risk.

   - ✅ **Parça 57 — tahta ile mesaj arasındaki boşluk: Parça 39'da YANLIŞ
     ölçmüşüm (11 Ağustos 2026, `game_screen.dart`, `online_game_screen.dart`):**
     Kullanıcı app ve web'i yan yana koyup *"app'te tahta ile mesaj ve mesaj
     ile harfler arasında web'deki boşluk yok"* dedi.
     - **Kök sebep benim kendi hatam:** Parça 39'da 56px'lik yamayı
       kaldırırken web'in gerçek boşluğunu "mesaj kabının `pt-1`i, yani
       4px" diye yazmıştım — ama `Board.tsx`'in KENDİ dış sarmalayıcısı da
       `px-3 pt-1.5 **pb-3**` taşıyor. Yani web'de tahta kartının altı ile
       mesaj arası 12 + 4 = **16px**; port yalnızca 4px bırakmıştı.
       Chromium'da gerçek DOM'la ölçüldü.
     - **Aynı turda iki sapma daha çıktı:** mesaj ile raf satırı arası
       web'de `gap-1.5` = 6px (port 4), ve mesaj bloğunun yatay dolgusu
       web'de `px-3` = 12 (port 16). Üçü de düzeltildi; buton satırı
       (`12, 6, 12, 12`) zaten doğruydu.
     - **Ders — bir sarmalayıcının boşluğunu ölçerken YALNIZCA o elemanın
       kendi sınıflarına bakma:** komşusunun `pb-*`i de aradaki mesafeye
       giriyor. Parça 39 tam bu yüzden yanlış çıktı ve bir yamayı
       kaldırırken yerine yanlış değeri koydu. Doğru refleks: iki düğümün
       GERÇEK `getBoundingClientRect` farkını ölç (Parça 56'da kullanılan
       yöntem), sınıf okuyarak toplama yapma.
     - **Test — negatif eş:** boşluklar `ValueKey('message-line')` ile
       ölçülüp sabitlendi (16 ± 0.5 ve 6 ± 0.5). Tahtanın alt dolgusu eski
       hâline çevrilince test GERÇEKTEN `Expected: within <0.5> of <16> /
       Actual: <4.0>` ile düştü — 4.0 tam olarak kullanıcının "boşluk yok"
       dediği değer.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       314/314 yeşil** (313'ten +1). İki ekranda da AYNI değişiklik
       (bilinçli kod tekrarı çifti). `kelimeki_core`'a dokunulmadı.

   - ✅ **Parça 58 — sürükleme ortasında rakip oynayınca taş havada asılı
     kalıp EKRAN KİLİTLENİYORDU; web'in `clearStuckDrag` neti porta hiç
     girmemişti (11 Ağustos 2026, `game_screen.dart`,
     `online_game_screen.dart`):** Kullanıcı gerçek bir iki kişilik Canlı
     oyundan sonra bildirdi: *"sürüklerken aynı anda karşı taraf da hamle
     yapınca oldu galiba. Harf takıldı kaldı. Hiçbir şey çalışmaz oldu.
     Kapatıp açınca … herşey normaldi."* Ekran görüntüsünde iz görünüyordu:
     tahtanın üstünde asılı kalmış büyük bir taş ve rafta ondan boşalan yer.
     - **İlk teşhisim YANLIŞTI ve testle çürütüldü.** `_refresh()`in
       `SyncOnlineStateAction`'ı sürükleme state'ine hiç dokunmadığından,
       rakibin hamlesi `placed`i temizleyip kaynak taşın `Listener`'ını
       söküyor → `PointerUpEvent` hiç ulaşmıyor diye düşünmüştüm. Repro
       testi (hem raf hem tahta kaynağı için) yazıldı ve **mevcut kodda
       GEÇTİ**: Flutter olayı pointer-down anında kaydedilen hit-test
       yoluna gönderdiğinden, yaprak `Listener` ağaçtan kalksa bile up
       yerine ulaşıyor. Yani "kaybolan pointer-up" hipotezi ölçülerek
       elendi — kod yazmadan önce.
     - **Sonra web okundu (kuralın ilk adımı) ve gerçek boşluk çıktı:**
       `App.tsx` ve `OnlineGameScreen.tsx`'in İKİSİNDE de adı doğrudan
       `clearStuckDrag` olan bir effect var — `visibilitychange` + `blur`
       dinleyip `dragRef`i ve ghost'u temizliyor. Yani web bu hata sınıfını
       (sürükleme ortasında kaybolan pointer) TANIYOR ve kurtuluş yolu
       sunuyor; port bu neti hiç taşımamış, bu yüzden tek kurtuluş yolu
       uygulamayı kapatıp açmaktı — kullanıcının yaptığı tam buydu.
     - **İki düzeltme, ikisi de testli:**
       1. **Lifecycle neti (web parity, İKİ ekranda birden):**
          `didChangeAppLifecycleState` `resumed` DIŞINDA bir duruma
          geçerken bekleyen sürüklemeyi iptal ediyor. `game_screen.dart`'ta
          `WidgetsBindingObserver` hiç yoktu, eklendi (`initState`'te
          `addObserver`, `dispose`'ta `removeObserver`).
       2. **Sync tur ilerletince sürükleme biter (`online_game_screen.dart`):**
          `_refresh()` dispatch'ten ÖNCE `turnCount`u okuyup ilerlediyse
          `_cancelTileDrag()` çağırıyor. Gerekçe semptom bastırma değil
          tutarlılık: reducer'ın `turnAdvanced` dalı taslak taşları zaten
          rafa geri döndürüyor ve rafı sunucudakiyle değiştiriyor — hayalet
          taş bundan sonra SİLİNMİŞ bir kaynağı gösteriyor.
     - **Neden kilitlenme "hiçbir şey çalışmıyor" gibi hissettiriyor:**
       `_dragRef` asılı kalınca `SingleChildScrollView`
       `NeverScrollableScrollPhysics`te kilitli kalıyor (Parça 15'in
       düzeltmesi) — dikeyde içerik ekranı aştığında OYNA/PAS GEÇ satırına
       kaydırılamıyor, yani butonlara fiziksel olarak ulaşılamıyor.
     - **Test — negatif eş doğrulamasıyla, ÜÇ test:** raf ve tahta kaynağı
       için ayrı ayrı "rakip hamle yaparsa ekran DONMUYOR" (parmak hâlâ
       ekranDAYKEN hayalet taş ve kaydırma kilidi gitmeli) + iki ekranda
       birer "arka plana alınırsa drag İPTAL olur". İki lib dosyası AYRI
       AYRI `git stash`lendi: `game_screen.dart` geri alınınca 1 test
       (`Expected: null / Actual: NeverScrollableScrollPhysics`),
       `online_game_screen.dart` geri alınınca 3 test GERÇEKTEN düştü;
       ikisi de geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       318/318 yeşil** (314'ten +4). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama SINIRI — dürüst kayıt:** cihazdaki ASIL tetikleyici
       (up'ın gerçekten kaybolduğu an) bu ortamda YENİDEN ÜRETİLEMEDİ;
       yukarıdaki iki düzeltme "rakip aynı anda oynadı" senaryosunu
       kapatıyor ve hangi sebeple olursa olsun **kurtuluş yolu açıyor**
       (uygulamayı arka plana alıp geri getirmek yetiyor, kapatıp açmak
       gerekmiyor). Aynı belirti tekrar bildirilirse tetikleyici hâlâ
       aranmalı. `mobile/TESTING.md` bölüm 11'e iki madde eklendi.
     - **Ayrıca araştırıldı, HATA DEĞİL:** kullanıcı oyun bitince OYNA'nın
       yerinde "yeni oyun aç" yerine "canlı izle gibi bir şey" yazdığını ve
       basınca Setup'a döndüğünü bildirdi. Web `OnlineGameScreen.tsx` oyun
       bitince TAM OLARAK bunu yapıyor: `<button onClick={onBack}>Canlı
       Listesi</button>` — port birebir aynı (Parça 50'de puntosu da web'e
       hizalanmıştı). Canlı bir oyun tek başına başlatılamadığından (davet
       + kabul gerekiyor) doğru hedef listenin kendisi; "+ Yeni Canlı Oyun"
       butonu orada. Değiştirmek İKİ platformu birden ilgilendiren bir ürün
       kararı olur, tek taraflı portta yapılmadı. **Kullanıcı aynı gün bu
       kararı verdi ve buton "Tekrar Oyna"ya çevrildi — bkz. Parça 59.**

   - ✅ **Parça 59 — oyun bitince "TEKRAR OYNA": aynı kadroyla yeni bir Canlı
     oyun (11 Ağustos 2026, `online_games_api.dart`, `online_game_screen.dart`
     + web `OnlineGameScreen.tsx`):** Parça 58'de "hata değil, web ile birebir"
     diye kapattığım buton hakkında kullanıcı ürün kararını verdi: *"canlı
     oyunda ideali 'Tekrar Oyna' çıkmalı. Basınca da aynı kişiyle oyun açsın …
     arkadaşıyla oynamışsa, o kişiye oyun daveti göndersin. Emin misin
     olmalı."* İki platforma AYNI GÜN uygulandı (web yarısı ayrı bir `main`
     tabanlı PR).
     - **Tek akış, iki dal değil:** "YZ ile" ve "arkadaşıyla" ayrı kodlar
       değil — biten oyunun KADROSU aynen taşınıyor; insan koltuklarına davet
       gidiyor, YZ koltuğu YZ kalıyor. Canlı'da zaten 2 kişilikte YZ olamıyor,
       4 kişilikte yalnız son koltuk YZ olabiliyor, yani "kadroyu kopyala"
       ikisini de karşılıyor.
     - **`rematchSlots` (saf fonksiyon) sırayı `create_online_game`'in üç
       kısıtından TÜRETİYOR, biten oyundan kopyalamıyor:** (1) ilk koltuk
       ÇAĞIRAN olmak zorunda — biten oyunu ben kurmamış olabilirim (`my_role
       == 'invitee'`), kendimi başa alıyorum; (2) 4 kişilikte YZ yalnız son
       koltukta olabilir — insanları kendi aralarındaki sırayla koruyup
       YZ'leri sona yazmak bunu kendiliğinden sağlıyor; (3) 2 kişilikte YZ
       zaten olamaz. **Kısıtlar RPC kaynağından okundu, hatırlanmadı**
       (`online_games_invites.sql` + `online_game_ai_slot_rule.sql`) — sırayı
       "olduğu gibi gönder" demek, kurucu ben değilsem her seferinde
       `'İlk koltuk oyunu kuran kişi olmalı.'` ile reddedilirdi.
     - **Zenginleştirme alanları RPC'ye gitmiyor:** `list_my_online_games`
       koltuklara `name`/`avatar_url`/`relation`/`invite_status` ekliyor;
       `NewGameSlot` yalnız `type`+`user_id` yazdığından bu alanlar
       `online_games.slots` jsonb'sine sızmıyor.
     - **Sunucu reddi olduğu gibi gösteriliyor:** aradan arkadaşlıktan
       çıkılmışsa RPC `'Yalnızca arkadaşlarını davet edebilirsin.'` fırlatıyor.
       Mesaj `friendErrorText` ile (LiveGameCreateForm'un AYNI RPC için
       kullandığı helper — `_errorText`in ham `toString()` gürültüsü değil)
       gösteriliyor ve hata dalında listeye DÖNÜLMÜYOR. İstemci tarafına
       ikinci bir arkadaşlık kontrolü eklenmedi: tek doğruluk kaynağı RPC.
     - **Metinler mevcut kalıplardan alındı, yenisi icat edilmedi:**
       "Davetiniz gönderilmiştir." + "{isimler} yanıt verince oyun
       başlayacak." + " 4. koltuk Yapay Zeka." — `LiveGameCreateForm`'un
       gönderim ekranıyla birebir. Onay diyaloğunda kabul butonu SOLDA
       (Parça 25 kuralı).
     - **Test — negatif eş doğrulamasıyla, 4 test:** `rematchSlots` için iki
       birim testi (kurucu olmasam da başa geçiyorum; 4 kişilikte YZ sonda
       kalıp insan sırası korunuyor) + iki widget testi (VAZGEÇ hiçbir şey
       göndermiyor → onay → `create` doğru sayı/koltuklarla çağrılıyor →
       "Davetiniz gönderilmiştir." → TAMAM listeye dönüyor; sunucu reddi
       dalında mesaj görünüyor ve ekran ayakta kalıyor). Ekran dosyası
       `git stash`lenince (saf helper yerinde bırakılarak) iki widget testi
       de GERÇEKTEN düştü (`Found 0 widgets with text "TEKRAR OYNA"`), geri
       konunca yeşile döndü.
     - **Sahte uca `createError` eklendi** — genel `failWith`ten ayrı, çünkü
       ekran o sırada yüklü ve öteki uçların çalışmaya devam etmesi gerekiyor
       (Parça 46'nın dersi: sahte uç gerçek ucun HER hata yolunu taklit
       etmeli).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 322/322
       yeşil** (318'den +4). Web `npm run lint` + `npm run build` temiz.
       `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** gerçek `create_online_game` çağrısı (davetin
       karşı hesapta belirmesi, `notify-game-invite` e-postası, artık arkadaş
       olmayan biriyle gelen ret) iki hesapla cihazda doğrulanmalı —
       `mobile/TESTING.md` bölüm 11'e madde eklendi.
     - **Yerel/YZ oyun ekranına DOKUNULMADI:** orada buton hâlâ "YENİ OYUN AÇ"
       ve Setup'a dönüyor — istek açıkça "canlı oyunda" diyordu ve Setup'ta
       zaten tek dokunuşluk bir YZ kurulum formu var. İstenirse ayrı bir
       parça.

   - ✅ **Parça 60 — "TEKRAR OYNA" yerel/YZ ekranına da geldi; sessiz bir
     k-lig kaybı BU ÇALIŞMA SIRASINDA yakalandı (11 Ağustos 2026,
     `game_screen.dart`, `setup_screen.dart` + web `App.tsx`):** Kullanıcı
     Parça 59'dan sonra "yerel/YZ ekranına da uygulasak mı?" diye sordu.
     Kayıt oturumu (`activeSaveIdRef` / `CloudGameSession._saveId`) oyun
     bitince id'yi zaten sıfırlıyor, yani yeni oyun kendiliğinden yeni bir
     satır alıyor — uygulama iki tarafta da temiz oturdu.
     - **Onay Canlı'dakiyle AYNI, gerekçesi FARKLI:** Canlı'da onay dışa
       dönük bir eylemi (davet göndermek) koruyor; yerelde öyle bir sonuç
       yok (oyun anında ve iz bırakmadan terk edilebilir, `turnCount<2`).
       Yine de kondu: AYNI konumdaki buton oyun bitince parmağın altında
       OYNA'dan TEKRAR OYNA'ya dönüşüyor — kazara dokunuş tam da bu yüzden
       olası, ve iki kardeş ekranın aynı davranması bu projede bir kural.
     - **Kadro yeniden hesaplanmıyor:** biten oyunun `players` adları/YZ
       bayrakları Setup'ın `doStart`/`_startNewGame`'inin ürettiğinin
       AYNISI — `StartAction`/`{type:'START'}` doğrudan onlarla çağrılıyor.
     - **BULUNAN GERÇEK HATA — `recorded` bayrağı ekran oturumu başına tek
       seferlikti:** `setup_screen.dart`'ın `_openGame`'i oyun bitince
       `games` satırını yazan dinleyiciyi `var recorded = false` ile
       koruyordu. Bu, ekran YALNIZCA Setup'a dönerek terk edilebildiği
       sürece doğruydu (dönüş closure'ı bitiriyordu). "TEKRAR OYNA" aynı
       ekranda ikinci bir oyun başlatabildiğinden bayrak sıfırlanmazsa o
       oyun HİÇ kaydedilmezdi — ne `games` satırı, ne k-lig puanı, ne oyun
       geçmişi; üstelik SESSİZCE. Dinleyici artık `isGameOver` false'a
       düştüğünde bayrağı sıfırlıyor.
     - **Web'de bu hata YOK ve sebebi öğretici:** oradaki kayıt bir
       `useEffect(..., [state.isGameOver])` — bağımlılık false→true'ya
       yeniden geçtiğinde effect kendiliğinden yeniden çalışıyor. Portun
       elle yazılmış dinleyicisi bu "yeniden tetiklenme"yi taklit etmiyordu.
       **Ders: bir React effect'ini elle bir `addListener`'a çevirirken
       "bağımlılık DEĞİŞTİĞİNDE yeniden çalışır" garantisini de taşı** —
       tek seferlik bir bool o garantiyi sessizce düşürür.
     - **Test — negatif eş doğrulamasıyla, 2 yeni test:** (1)
       `game_screen_test.dart` — oyun bitince buton "TEKRAR OYNA"
       ("YENİ OYUN AÇ" DEĞİL), VAZGEÇ yeni oyun başlatmıyor, onay TAZE bir
       oyun açıyor (turnCount 0, aynı kadro, buton yine OYNA); ekran dosyası
       `git stash`lenince GERÇEKTEN düştü. (2) `setup_cloud_test.dart` —
       aynı ekranda ikinci oyun da kaydediliyor; bayrak sıfırlaması geri
       alınınca GERÇEKTEN `Expected: an object with length of <2>` ile
       düştü. Ayrıca iki MEVCUT test eski etikete bağlıydı, beklentileri
       güncellendi (Parça 50'nin ASIL sözleşmesi — tek satır, 15px — aynen
       korunuyor, yalnızca metin değişti).
     - **Test tuzağı:** GameOver'ı kapatmak Parça 48'den beri "Görüş
       Bildir" formunu açıyor; formu da kapatmazsan modal bariyeri sonraki
       dokunuşları yutuyor ve hata "buton yok" gibi görünüyor.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 324/324
       yeşil** (322'den +2). Web `npm run lint` + `npm run build` temiz.
       `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda teyit kullanıcıdan bekleniyor —
       `mobile/TESTING.md` bölüm 1'e madde eklendi. En kritik maddesi
       "aynı ekranda ART ARDA iki oyun bitir, İKİSİ de Skor Kartı'nda
       görünsün" — yukarıdaki sessiz kaybın gerçek uçla kontrolü.

   - ✅ **Parça 61 — k-lig Ödül & Rütbe Sistemi'nin UI katmanı (12 Ağustos
     2026, 9 yeni dosya [8'i `ui/rank/` + `data/league_rewards_api.dart`] +
     14 değişen; web `leagueRank.ts`/`RankSeal`/`RewardBanner`/
     `RankInfoModal`/`LeagueRewardsHost` + `Modal.headerCenter` portu):**
     Sunucu tarafı (league_rewards tablosu, `games` trigger'ı, view
     kolonları) web PR'ıyla ZATEN canlıda — yani mobilde bitirilen bir oyun
     ödülü bugün de kazanıyordu, yalnızca kullanıcıya gösterecek katman
     yoktu. Bu parça o katmanı ekliyor; SUNUCUYA HİÇ DOKUNULMADI.
     - **Dosya yerleşimi kararları:** (a) rütbe/ödül UI'ı `ui/score/`'a
       serpiştirilmedi, kendi `ui/rank/` klasörüne alındı — banner ve host
       "skor kartı" değil, uygulama seviyesinde bir katman; (b) veri katmanı
       `stats_api.dart`'a EKLENMEDİ, ayrı `data/league_rewards_api.dart`
       oldu: stats_api bilinçli olarak üç SALT OKUNUR view/RPC taşıyor,
       buradaysa bir YAZMA yolu (`mark_league_rewards_seen`) + kendi modeli
       var; proje deseni zaten alan başına bir dosya (chat/friends/feedback).
     - **Host mimarisi — web'in "aynı anda tek host" garantisi Flutter'da
       KENDİLİĞİNDEN GEÇERLİ DEĞİL:** Web'de App.tsx erken return'lerle
       dallandığından üç mount birbirini dışlıyor. Portta `SetupScreen`
       `MaterialApp.home`'dur ve oyun ekranları onun ÜZERİNE push edilir —
       Setup'ın host'u oyun sırasında MOUNT KALIR. Çözüm: host'lar modül
       seviyesinde bir yığına kaydolur, YALNIZCA EN ÜSTTEKİ çalışır (yığın
       Navigator'la aynı sırayı izler; oyun pop edilince Setup'ınki
       kendiliğinden yeniden etkinleşip kontrol koşar). `MaterialApp.builder`
       içinde TEK global host + ayrı bir "suppress sinyali" alternatifi
       değerlendirildi ve elendi: web'in `suppress` prop'unu iki ekrana
       taşımak zaten gerekiyordu, yığın çözümü ise web'in kod şeklini
       (`LeagueRewardsHost(suppress: ...)`) birebir koruyor.
     - **Mount noktaları:** `setup_screen` (suppress YOK — giriş/backfill
       kutlaması burada), `game_screen` ve `online_game_screen`
       (`suppress: !state.isGameOver`). Yerel oyunda ayrıca
       `_recordFinishedGame` kayıt sunucuya düşer düşmez
       `requestLeagueRewardCheck()` çağırıyor (web'in
       `saveGameDurable(...).then(requestLeagueRewardCheck)` deseni);
       Canlı'da buna gerek yok, `suppress`in düşmesi yetiyor. Misafirde
       host tamamen no-op (tek ağ isteği bile atılmıyor, testle sabit).
     - **BULUNAN İKİ GÖRSEL HATA — ikisini de ÖLÇÜM yakaladı, kod okuması
       DEĞİL** (ekran görüntüsü + Chromium'da gerçek fontla karşılaştırma):
       1. **`✓` karakteri Space Mono'da YOK.** Web'de düz bir `✓` basılıyor
          ve tarayıcı sessizce yedek fonta düşüyor (Chromium'da doğrulandı:
          computed font "Space Mono, monospace", glyph monospace
          yedeğinden geliyor). Flutter yedek fonta düşmediğinden TOFU (boş
          kutu) çiziyordu. Rozet artık Material `Icons.check` kullanıyor —
          her platformda ve testlerde garanti. **Ders: web'de çalışan bir
          Unicode glyph portta çalışacak demek DEĞİL; fontun içerdiğini
          varsayma, render edip bak.**
       2. **Material 3'ün varsayılan `letterSpacing: 0.25`'i sessizce
          miras alınıyordu.** "Sıradaki rütbe: Oyuncu · 100 puan" 33
          karakterde tam 8.25px (33×0.25) şişip 230px'lik karta sığmıyor ve
          İKİ SATIRA düşüyordu. Aynı metin Chromium'da gerçek Space Mono ile
          222.16px, tek satır — yani geometri (280 kart / 1px çerçeve / 24px
          dolgu / 11px punto) web ile BİREBİRDİ, fark yalnızca bu tracking'ti.
          `ui/rank/` metinleri artık `letterSpacing: kNoTracking` (0) taşıyor.
          **Bu bulgu bu parçanın DIŞINDA da geçerli olabilir** — portun
          `ThemeData(useMaterial3: true)` kullanan diğer ekranlarında
          `letterSpacing` yazmayan her metin 0.25 miras alıyor; ayrı bir
          denetim işi (aşağıdaki "Sonraya Bırakılan İşler"e eklendi).
     - **`RankSeal` CanvasKit-güvenli:** kesikli iç halka `Path.combine`/
       PathOps ile DEĞİL, tek tek `drawArc`'larla çiziliyor (Parça 18 dersi).
       Ortadaki harf SVG'nin `dominant-baseline: central`ı gibi FONT
       METRİKLERİNE göre (ascent/descent ortası) yerleştiriliyor — `Center`
       satır kutusuna göre hizalayıp glyph'i hafif yukarı kaçırırdı.
       Kompakt kural (`size < 24` → halkasız + harf 19→27) saf fonksiyona
       (`sealIsCompact`/`sealFontSize`) çıkarıldı ki testlenebilsin.
     - **`KModal`'a `headerCenter` yuvası** (web `Modal.headerCenter`) —
       `headerAction`'a DOKUNULMADI (ChatModal'ın dişlisi onu kullanıyor).
       Verilmezse başlık eskisi gibi tüm boşluğu alır (`Expanded`), verilirse
       başlık kendi genişliğinde durur (`Flexible`) ve yuva ortalanır.
     - **`tokens.dart`'a `kTilePts`** (tailwind `tile-pts`, `#8A93A2`) —
       Çaylak kademesinin rengi. `color_tokens_test`in TAİLWİND PARİTE
       testine eklendi, "yerel kopya" taramasına BİLEREK eklenmedi: `lib/`
       altında bu değerde 8 literal var ve hepsi `tile-pts` DEĞİL (beşi form
       placeholder'ı — web oraya hiç renk yazmıyor, tarayıcı varsayılanı).
       Beyazın dışlanmasıyla aynı gerekçe; ayrım gerektiren bu migrasyon
       ayrı bir denetim işi.
     - **`PlayerStats`'a `bonusPoints` + `rankTier`** (yalnızca
       `player_stats_overall`'da dolu). `rankTier`'ı UI OKUMUYOR — rütbe
       güncel puandan türetiliyor ("düşmeli" sürüm); kolon yalnızca "hangi
       eşikler kutlandı" kaydı, web `PlayerStats.rank_tier` ile aynı gerekçe.
     - **`RankProgressBar` PAYLAŞILAN:** web ilerleme çubuğunu iki yerde
       (bilgi popup'ı + düşüş banner'ı) ayrı ayrı yazmış; port
       `showInvasionConfirm` ile aynı gerekçeyle tek dosyaya aldı (aynı
       görsel + aynı rozet kuralı, iki kopya sessizce ayrışır).
     - **Test — 26 yeni test (`test/league_rewards_test.dart`), ikisi
       negatif eşle doğrulandı:** `hasPositive` guard'ı kaldırılınca öncelik
       testi GERÇEKTEN düştü (`Expected: null / Actual: RankDownInfo`);
       rozet `claimed ? kGreen : kMuted` sabitlenince renk testi GERÇEKTEN
       düştü. Kapsam: eşik sınırları/negatif puan/renk tokenları, ödül
       tablosunun SQL ile aynılığı, `rewardAlreadyClaimed` prefix çıkarımı,
       `buildRewardSummary` birleştirme + öncelik + bilinmeyen tür,
       repo/gateway (unseen→markSeen, ağ hatası), host akışı (banner,
       DEVAM=markSeen, suppress, misafir no-op, düşüş çubuğu, puan
       çekilemezse çubuk gizli), bilgi popup'ı rozet kuralı + en üst kademe,
       mühür kompakt eşiği. Ayrıca üç ekran görüntüsü
       (`build/screenshots/reward_banner*.png`, `rank_info_modal.png`) —
       yukarıdaki iki hata tam da bunlara bakarak bulundu.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 350/350
       yeşil** (324'ten +26; ilk tam koşuda `setup_cloud_test`'in "TEKRAR
       OYNA … İKİNCİ oyun" testi bir kez düştü ama tek başına ve ikinci tam
       koşuda geçti — yük altındaki bir zamanlama flake'i, bu parçanın
       eklediği kod o testin insert yolunu geciktirmiyor).
       `kelimeki_core`'a hiç dokunulmadı (motor ödül/rütbe bilmiyor).
     - **Doğrulama sınırı:** gerçek `league_rewards` tablosu/RPC'si ve
       "cihazdan bağımsız bir kez göster" garantisi bu ortamdan
       doğrulanamadı (gerçek oturum + gerçek oyun bitişi gerekiyor) —
       `mobile/TESTING.md` bölüm 13 eklendi (web'in kök `TESTING.md` bölüm
       10'unun mobil eşleniği, artı "web'de görülen kutlama mobilde
       ÇIKMAMALI" çapraz maddesi).
     - **AYNI GÜN, kullanıcının üç görsel düzeltmesi (ekran görüntüsüyle
       geldi — üçü de İKİ platforma birden uygulandı, bkz. kök
       `CLAUDE.md`):**
       1. **Mührün dış kenarı TIRTIKLI** (referans: testere dişli
          sertifika damgası) — 24 diş, uç 21.0 / vadi 18.8 viewBox
          birimi, stroke 2.0. Üç sabit web `RankSeal.tsx` ile ELLE
          senkron: web aynı üçlüyle bir `<polygon>` üretiyor, port
          `Path`. **İlk sürümde kompakt mühür (k-lig satırları, <24px)
          düz çember bırakılmıştı** — gerekçe "18px'te diş derinliği
          <1px'e düşüp alt-piksel gürültüsüne dönüyor" idi; AYNI GÜN
          ölçülüp ÇÜRÜTÜLDÜ, bkz. aşağıdaki 5. madde.
       2. **İlerleme çubuğunun sağ etiketi yalnızca SAYI.** İlk sürüm
          "100 puan" yazıyordu; "puan" kelimesi hemen ÜSTTEKİ "Sıradaki
          rütbe: Oyuncu · 100 puan" satırında zaten geçtiğinden alt alta
          tekrar oluyordu. **Sayının kendisi KALDI** — ilk denemede tüm
          etiketi kaldırıp kullanıcıya düzelttirdim; istek "sonundaki
          puan yazısını kaldır"dı, çubuğun eşiğini gizlemek değil.
       3. **Düşüş banner'ının başlığına ünlem:** "Rütben geriledi!"
       4. **Mühürdeki harf büyüdü — tam boyda 19 → 23.** Sayı ÖLÇÜLEREK
          seçildi: kademe harflerinin (Ç M O U Ş D) `getBBox`'ı gerçek
          Space Mono 700 ile Chromium'da okundu, merkeze en uzak köşe Ç'de
          23'te **15.48**, 24'te **16.20** — iç kesikli halka r=16
          olduğundan 24'te Ç/Ş'nin sedillası halkayı taşıyor (zoom'lu
          render'da da görüldü). **Kompakt 27'DE KALDI:** oradaki sınır
          dış çemberin iç kenarı (20.5 − 2.5/2 = 19.25) ve 27 zaten 18.17
          ile tavana yakın (azami ~28.6) — bir punto artış görünmez, taşma
          riski gerçek; o boy bir tur önce tam bu yüzden 19'dan 27'ye
          çıkarılmıştı. Web `RankSeal.tsx` ile aynı gün aynı değere çekildi.
       5. **Tırtık HER BOYA yayıldı** (kullanıcı: "leaderboard'daki küçük
          rozetlerde tırtık olamıyor mu?") — 1. maddedeki "kompakt düz
          çember kalsın" gerekçesi ÖLÇÜLMEDEN yazılmış ve YANLIŞTI: hesap
          DPR 1 varsayıyordu, retinada (DPR 3) 0.9 CSS px = 2.7 cihaz
          pikseli. Web tarafında 18px/DPR3 render edilip büyütülerek
          doğrulandı, dişler net. Diş sayısı bilerek aynı (24) — tek
          siluet, tek sabit seti. **Kompakt harf 27'de KALDI ve bu sefer
          MÜREKKEPLE ölçüldü:** tırtık yayılınca iç sınır daraldı (düz
          çemberin iç kenarı 19.25 → vadi iç kenarı 17.8) ve harfin bbox
          köşesi 18.17, yani KUTU taşıyor — ama kutunun köşesi boş; 20×
          ölçekte piksel taranınca en uzak mürekkep 16.56 (Ç), sınıra
          1.24 birim var. **Yuvarlak harflerde bbox köşesini sınır sanmak
          yanlış pozitif üretir.**
       6. **Kart gölgesi düz düşen gölgeye çevrildi** (kullanıcı: "üst ve
          sol tarafındaki beyaz gölge iyi durmuyor") — `kRaisedShadows`in
          sol-üst beyaz parıltısı nömorfik YÜZEYLER için tasarlandı,
          `bg-black/40` üstünde yüzen bir kartta hale gibi okunuyordu.
          Yeni `kFloatingCardShadows` (`neo_box.dart`, web `Modal.tsx`'in
          `0 20px 45px rgba(15,23,42,.5)`'i) hem `RankInfoModal` hem
          `RewardBanner` kartında — İKİSİ AYNI KART, biri değişirse öteki
          de. Mührün kendi 88px'lik dairesi `kRaisedShadows` TAŞIMAYA
          DEVAM ediyor (web'de de `shadow-raised`).
       7. **Bilgi popup'ında kocaman "KAPAT" butonu kalktı, sağ üste ✕
          geldi** — salt bilgi veren bir popup'ın altına tam genişlikte
          aksiyon butonu konmaz; stil `KModal`ın ✕'inden birebir alındı.
          ~~**Banner'ın "DEVAM"ı KALDI:** o gerçek bir aksiyon (ödülleri
          görüldü işaretler).~~ — **AYNI GÜN geri alındı, bkz. Parça 69:**
          kullanıcı kuralı banner'lara da genişletti ("bu banner'larda
          kapat, devam vb olmamalı, sadece X"); işaretleme kaybolmadı, ✕
          aynı `onClose`'a bağlandı.
       8. **Kuyruklu harfler (Ç/Ş) mühürde alta kaçıyordu — taban çizgisi
          artık MÜREKKEPTEN hesaplanıyor** (kullanıcı: "Ç, Ş gibi altında
          kuyruk olan karakterler ortalı durmuyor, alta daha yakın
          duruyor"). Eski hâl web'de `dominant-baseline="central"`, portta
          `TextPainter`ın satır kutusu ortalaması — İKİSİ DE mürekkebi
          değil FONT METRİKLERİNİ (ascent/descent) ortalıyor. Ölçüm iki
          ayrı sapma gösterdi: TÜM harfler ~1.2 birim aşağıdaydı (Space
          Mono'nun descent'i ink descent'inden büyük), Ç/Ş sedilla yüzünden
          ~2.5 birim DAHA aşağıdaydı — 27 puntoda toplam 2.85 birim, yani
          kullanıcının gördüğü fark. **Düzeltme harf başına tablo DEĞİL,
          iki ölçülmüş sabit:** `kSealInkAscEm` (.71 — M/U/D .70,
          yuvarlaklar .72'nin ortalaması) ve `kSealDescenderEm` (.21);
          taban çizgisi `(inkAsc − varsa descender)/2` kadar merkezin
          ALTINA konuyor (`sealBaselineEm`). Painter `computeLineMetrics()`
          ile satır kutusunun tepesinden `baseline` kadar geri alıyor —
          `Center`/`tp.height/2` ile hizalamak tam da düzeltilen hatayı
          geri getirirdi. Düzeltmeden sonra azami sapma 27'de **0.32**,
          23'te **0.27** (ölçüldü). Web `RankSeal.tsx`'in `baselineY`'siyle
          AYNI formül, ikisi ELLE senkron — biri değişirse öteki de.
          **Yan bulgu (bilinçli KULLANILMADI):** mürekkep yukarı kayınca
          Ç'nin merkeze en uzak mürekkebi 16.56 → **12.61**'e (fs=27),
          tam boyda 10.74'e düştü — yani 4. maddedeki punto tavanları
          artık çok daha gevşek; kullanıcı mevcut görünümü onayladığından
          punto DEĞİŞTİRİLMEDİ, yalnızca kayda geçti.
     - **Doğrulama (düzeltmeler sonrası):** `flutter analyze` "No issues
       found!"; **tam takım 351/351 yeşil** (350'den +1). 1-4. maddeler
       için yeni test eklenmedi, mevcut üç assertion güncellendi
       (`find.text('Rütben geriledi!')`, `find.text('100')` +
       `find.text('100 puan')` findsNothing, ve "çubuk gizli" testi artık
       `find.byType(RankProgressBar)` yokluğunu ölçüyor — eşik metnine
       bağlı olmadığından etiket bir daha değişirse yanlış yeri işaret
       etmez). 5-7 için: mühür testi artık painter'ı sahte bir `Canvas`'a
       çizdirip ilkelleri SAYIYOR (iki boyda da `drawCircle` YOK, iki
       `drawPath` var; `drawArc` yalnızca tam boyda) — "tırtık mı düz
       çember mi" sorusu ekran görüntüsüne bakmadan yanıtlanıyor; ayrıca
       yeni bir test ✕'in varlığını + "KAPAT"ın yokluğunu + kart
       gölgesini doğruluyor, banner'ın kendi testine de aynı gölge
       assertion'ı eklendi. **Negatif eş, üçü ayrı ayrı:** `rank_seal.dart`
       stash'lenince `Expected: <0> Actual: <2>` (çemberler geri geldi),
       iki modal dosyası stash'lenince hem gölge testi (`Actual: [Instance
       of 'CssShadow', Instance of 'CssShadow']`) hem ✕ testi (`Found 1
       widget with text "KAPAT"`) GERÇEKTEN düştü. Ekran görüntüsü
       `build/screenshots/rank_info_modal.png` yeniden üretilip gözle
       kontrol edildi (tırtıklı mavi mühür, sağ üstte ✕, beyaz halesiz
       kart, `50` / `83` / `100` etiketleri, solda yeşil `(+5)✓`, sağda
       gri `(+10)`). **8. madde (ölçüldü, ayrı test):** `RankSeal(size:440)`
       gerçek fontlarla render edilip `RepaintBoundary.toImage` ile PNG'ye
       çekiliyor, iç halkanın içindeki (r<15 viewBox birimi) mürekkep
       piksel piksel taranıp altı kademe harfinin (Ç Ş M O U D) dikey
       merkezi ölçülüyor — her birinin sapması <0.6 VE Ç ile M'nin farkı
       <0.6 olmalı. **Negatif eş:** `rank_seal.dart` stash'lenince test
       GERÇEKTEN `Ç dikeyde ortalı değil: 2.85` ile düştü, geri konunca
       yeşile döndü. **Tam takım 352/352 yeşil** (351'den +1); ilk koşuda
       ilgisiz bir test bir kez düşüp sonraki iki temiz koşuda hiç
       tekrarlamadı (Parça 13/21'de belgelenen sqflite yazma-kilidi
       flake'i — bu parçanın kodu o testin yoluna hiç değmiyor).

   - ✅ **Parça 62 — rütbe merdiveni 6'dan 9 kademeye çıktı: Usta 250,
     üstüne Efsane/Uzaylı/Tanrı (12 Ağustos 2026, `league_rank.dart`,
     `tokens.dart`, `tailwind.config.js` + web `leagueRank.ts` +
     `rank_tiers_efsane_uzayli_tanri` migration'ı):** Kullanıcı isteği —
     *"Usta 200'ü 250 yapalım. Destan'dan sonra 2500 Efsane. 5000 Uzaylı.
     10000 Tanrı olsun. Ödül puanları da aynı mantığa göre ayarla.
     Tanrı'dan sonra hep tanrı olarak kalsın."* Yeni bir mekanizma YOK;
     üç kopyalı tablo (SQL ↔ TS ↔ Dart) genişletildi.
     - **Ödül = eşik/10 kuralı bu değişiklikle tabloya TAM oturdu.**
       Kural zaten 5 kademede geçerliydi, TEK kırık üye Usta'ydı (200
       eşik / 25 ödül). Kullanıcının eşiği 250'ye çekmesi onu farkında
       olmadan onardı — yeni üçlü de aynı orandan türetildi (250/500/
       1000). Tanrı'nın 1000'i `league_rewards_points_check`in tavanına
       (`points <= 1000`) TAM oturuyor: bir üst kademe eklenecekse o
       kısıt da büyütülmeli, bu üç dosyaya not düşüldü.
     - **Kümülatif toplamlar PAİRWİSE FARKLI olmak ZORUNDA** —
       `rewardAlreadyClaimed` ödenen eşik kümesini yalnızca TOPLAM ödül
       puanından türetiyor. Yeni dizi 0/5/15/40/90/190/440/940/1940;
       farklılık artık bir yorum değil TEST (aşağı bkz.).
     - **Uzaylı'nın harfi "Z", "U" DEĞİL** — U zaten Usta'da ve mühür tek
       glyph gösterdiğinden iki kademe yalnızca renkleriyle ayrışırdı.
       Kullanıcı önce *"Mühür harfleri yerine uygun imojiler mi
       yaratsak?"* diye sordu; üç ÖLÇÜLMÜŞ itirazla emoji elendi ve
       kullanıcı harfleri seçti: (a) emoji kendi renkleriyle çizilir,
       `fill`/`color` yok sayılır — kademe rengi (mührün tek kimlik
       taşıyıcısı) kaybolurdu; (b) k-lig satırındaki mühür 18px, o boyda
       emoji detayı okunmaz (harf okunuyor); (c) CanvasKit renkli emojiyi
       çalışma anında `fonts.gstatic.com`'dan çekiyor (Parça 29'da
       ölçüldü, `pubspec.yaml`'da gömülü emoji fontu YOK) — ağ engelliyse
       boş daire çıkar, harfte böyle bir bağımlılık yok.
     - **Üç yeni palet token'ı** (`kIndigo`/`kCyan`/`kGoldBright`) —
       "her kademe rengi bir palet token'ıdır" değişmezi kırılmasın diye
       `tailwind.config.js`'e de eklendiler (kanonik kaynak orası) ve
       `color_tokens_test`in HEM tailwind parite HEM "yerel kopya"
       taramasına girdiler; `kTilePts` gibi bir istisna gerekmedi, bu üç
       değerin `lib/` altında başka anlamı yok. **`tailwind.config.js`
       `mobile/` DIŞINDA** — port dalında mahsur kalmasın diye web yarısı
       (leagueRank.ts + migration + tailwind) AYNI GÜN `main` tabanlı ayrı
       bir dalda teslim edildi (Parça Bitirme Kontrol Listesi madde 1).
     - **Canlıda GERÇEK fonksiyonla doğrulandı (geri alınan transaction):**
       disposable bir hesaba 4900 sahte galibiyet yazılıp gerçek
       `_award_league_rewards` çağrıldı — 8 eşiğin TAMAMI (Tanrı dahil)
       tetiklendi. Bu aynı zamanda ödül geri besleme döngüsünü de
       kanıtladı: 9800 taban puan tek başına 10000'i geçmiyor, biriken
       940 ödül puanıyla geçiyor. `rollback` sonrası iz kalmadığı ayrıca
       sorgulandı. Migration'dan ÖNCE de kontrol edildi: eşik 200'de hiç
       `league_rewards` satırı yoktu, yani Usta değişikliği hiçbir kaydı
       öksüz bırakmadı.
     - **Test — negatif eş doğrulamasıyla:** `league_rewards_test.dart`'ın
       sınırları (249/250 … 999999→Tanrı), renkleri ve ödül tablosu
       genişletildi; ödül testi artık sabit listeyi karşılaştırmakla
       kalmayıp `reward == threshold ~/ 10` kuralını da her kademede
       zorluyor. Yeni bir test kümülatif toplamların farklılığını
       sabitliyor. "En üst kademede çubuk yok" testi 1200/Destan'dan
       12000/Tanrı'ya taşındı ve kardeşi eklendi ("Destan artık en üst
       DEĞİL — Efsane hedefiyle çubuk çizilir"); bu eşleşme bilinçli, tek
       başına ilki merdiven yanlış kısaltılsa da geçerdi. `league_rank.dart`
       + `tokens.dart` + `tailwind.config.js` birlikte `git stash`lenince
       takım GERÇEKTEN `+0 -2` (derleme hatası — belirsizliksiz) ile
       düştü, geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       354/354 yeşil** (352'den +2). `kelimeki_core`'a hiç dokunulmadı
       (motor rütbe/ödül bilmiyor), golden vector turu gerekmedi.
     - **Doğrulama sınırı:** cihazda görsel teyit (yeni üç rengin mühürde
       ve ilerleme çubuğunda nasıl durduğu, "Z" harfinin okunabilirliği)
       kullanıcıdan bekleniyor — `mobile/TESTING.md` bölüm 13 güncellendi.

   - ✅ **Parça 63 — k-lig tablosuna OHP (ortalama hamle puanı) kolonu
     (12 Ağustos 2026, `stats_api.dart`, `leaderboard_modal.dart` + web
     `leaderboard`/`my_leaderboard_rank` + `Leaderboard.tsx`):** Kullanıcı
     isteği — *"Hem web hem de app'te leaderboard tablosunda Puan kolonunun
     soluna OHP kolonu ekle (mouseover/hover ya da tıklanınca/değince hint
     olarak ne olduğu gösterilsin) rakamlar düz gri olsun."* Web yarısı
     `main` tabanlı ayrı bir dalda teslim edildi (Parça Bitirme Kontrol
     Listesi madde 1).
     - **Sunucu — sayı ELLE hesaplanmadı, `player_stats_overall`'ın
       İFADESİ birebir kopyalandı:** `avg_move_score` bir AĞIRLIKLI
       ortalama (`sum(move_points_sum)/nullif(sum(move_count),0)`, 2
       basamak), oyun başına ortalamaların ortalaması DEĞİL. `leaderboard`
       view'ına aynı ifade eklendi ki bir oyuncunun k-lig satırındaki OHP
       ile Skor Kartı'ndaki "Ortalama Hamle Puanı" HİÇBİR ZAMAN
       ayrışamasın. Migration'dan ÖNCE canlıda doğrulandı: 15 kullanıcının
       TAMAMINDA iki ifade birebir eşleşti (0 sapma, 0 null, aralık
       6.70-15.54).
     - **`create or replace view`, drop/create DEĞİL** — kolon SONA
       eklendiğinde grant'ler ve `security_invoker = false` (owner hakları;
       view'ın `profiles`/`games` üzerindeki kilitli RLS'i bypass etmesini
       sağlayan şey) korunuyor. Uygulandıktan sonra canlıda `set local role
       authenticated` + gerçek bir JWT iddiasıyla teyit edildi: sıradan bir
       hesap hâlâ 15 satırın hepsini OHP dolu görüyor.
     - **`my_leaderboard_rank` de genişletildi** ("senin sıran" kısayolu):
       dönüş TİPİ değiştiğinden `drop function` + `create` şart, grant'ler
       elle geri kuruldu. Kısayol AYNI tabloda AYNI kolonları çizdiğinden
       alan eklenmeseydi o tek satırda OHP boş kalır, tablo hizasız
       görünürdü.
     - **`parseNullableDouble` — ölçülemeyen bir varsayımın dürüst
       kaydı:** `PlayerStats` `numeric` alanları düz `as num?` ile okuyor
       ve bu cihazda çalıştığı kanıtlanmış (yani PostgREST numeric'i JSON
       SAYISI döndürüyor); ama bu ortamdan REST ucuna erişilemediğinden
       (proxy 403) OHP alanları için AYNI varsayım ÖLÇÜLEMEDİ. Bir dize
       gelseydi `as num?` tüm k-lig listesini bir TypeError ile düşürürdü —
       iki olasılığı da kabul etmek iki satır, yeni bir bağımlılık yok.
     - **Hint iki yoldan da açılıyor, çünkü tek yol yetmez:** `Tooltip`
       (masaüstü hover — web `title`) VE başlığa dokununca açılan bir
       satır (`_showOhpHint`). Dokunmatikte hover DİYE BİR ŞEY olmadığından
       tooltip tek başına keşfedilemez; web'de de aynı ikili var (`title`
       + tıklanınca açılan paragraf).
     - **Renk kararı ölçülerek değil KURALDAN geldi:** "düz gri" =
       `kMuted`, yani `tailwind muted` token'ı (`color_tokens_test` bunu
       zaten web'e karşı doğruluyor) — yeni bir gri icat edilmedi. Puan
       kolonunun mavi/kalın kalması testte AYRICA sabitlendi, aksi halde
       "gri yaptım" iddiası Puan'ı da griye çekseydi geçerdi.
     - **Test — negatif eş doğrulamasıyla, İKİ TURDA:** ilk tur iki lib
       dosyasını birden `git stash`ledi ve DERLEME hatası verdi (güçlü ama
       UI iddialarını sınamıyor); ikinci turda yalnızca
       `leaderboard_modal.dart` geri alınıp `stats_api.dart` yerinde
       bırakıldı — widget testi GERÇEKTEN `Found 0 widgets with text
       "OHP"` ile düştü, `parseNullableDouble` testi (doğru şekilde) geçti.
       **Bunu mümkün kılmak için test, hint metnini `ohpHint` SABİTİ
       yerine düz dizeyle yazıyor:** sabite bağlanan bir assertion, widget
       hint'i hiç göstermese bile derlenir ve negatif eş kanıtlanamazdı.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       356/356 yeşil** (354'ten +2). `kelimeki_core`'a hiç dokunulmadı
       (motor istatistik bilmiyor), golden vector turu gerekmedi.
     - **Doğrulama sınırı:** gerçek `leaderboard`/`my_leaderboard_rank`
       uçlarından gelen OHP'nin cihazda göründüğü ve Skor Kartı'ndaki
       sayıyla eşleştiği kullanıcıdan bekleniyor — `mobile/TESTING.md`
       bölüm 4'e çapraz kontrol maddesi eklendi.
     - **AYNI GÜN, kullanıcının iki düzeltmesi + bir sorusu (iki platforma
       birden uygulandı, bkz. kök `CLAUDE.md`):**
       1. **Rakamlar 14 → 11px** (satırın kendi puntosundan küçük). Puan
          14/kalın/mavi kaldı ve bu testte AYRICA sabitlendi — aksi halde
          "küçülttüm" iddiası Puan'ı da küçültseydi geçerdi.
       2. **Açıklama artık başlığın ALTINA açılan bir kutu DEĞİL, TAM
          ÜSTÜNDE aşağı bakan kuyruklu bir balon.** `Tooltip` kaldırıldı:
          Flutter'ın kendi balonu kendi metnini kendi konumunda gösterip
          İKİNCİ bir balon üretirdi. Yeni yapı `OverlayPortal` +
          `CompositedTransformFollower` (`targetAnchor: topRight` /
          `followerAnchor: bottomRight`) — başlık satırı modalın kaydırma
          kabında yaşadığından normal bir `Stack` çocuğu hem kırpılır hem
          satır yüksekliğini değiştirirdi.
          - **İki ayrı bayrak, çünkü kapanma kuralları farklı:**
            `_ohpHintHover` (masaüstü `MouseRegion` — fare çekilince
            kapanır) ve `_ohpHintPinned` (dokunuş; mobilde hover DİYE BİR
            ŞEY YOK). Görünürlük ikisinin BİRLEŞİMİ (`_syncOhpHint`).
          - **Tam ekran bariyer YALNIZCA pinned iken var** — hover'da da
            olsaydı fare başlığın üstündeyken tüm modal tıklanamaz olurdu.
            Bariyer başlığı da kapladığından "tekrar dokununca kapanır"
            kuralı ondan geliyor (ayrı bir toggle yolu gerekmedi).
          - Kuyruk `Path.combine`/PathOps KULLANMIYOR (Parça 18 dersi):
            düz bir üçgen `drawPath` + yalnızca İKİ EĞİK kenarın stroke'u
            (üst kenar kutunun kendi çerçevesiyle çakışıyor, 1px yukarı
            kaydırılarak dikiş kapatılıyor).
          - Metin `letterSpacing: 0` taşıyor — Material 3'ün varsayılan
            0.25 tracking'i ("Sonraya Bırakılan İşler"deki açık madde) bu
            yeni metne sızmasın diye.
       3. **Kullanıcının sorusu — "OHP şu anda o şekilde hesaplanmıyor
          mu?" — canlı veriyle DOĞRULANDI, kod değişmedi.** View'ın değeri
          15 kullanıcının TAMAMINDA `sum(move_points_sum)/sum(move_count)`
          ile birebir eşleşiyor; ayrım kanıtlı: oyun başına ortalamaların
          ortalaması T5'te 9.86 verirken gerçek değer 12.59 — yani yeni
          metin ("tüm oyunlarda yapılan TÜM HAMLELERİN ortalaması") mevcut
          hesabı doğru tarif ediyor ve öteki yöntem için YANLIŞ olurdu.
     - **Doğrulama (düzeltmeler sonrası):** `flutter analyze` "No issues
       found!"; **tam takım 356/356 yeşil** (yeni test eklenmedi, mevcut
       OHP testi genişletildi: punto + balonun başlığın ÜSTÜNDE olduğu +
       üç kapanma yolu — dışarı dokunuş, tekrar dokunuş). **Negatif eş:**
       `leaderboard_modal.dart` `git stash`lenince test GERÇEKTEN
       `Expected: <11> Actual: <14.0>` ile düştü, geri konunca yeşile
       döndü. Balon gerçek fontlarla render edilip (geçici bir
       `RepaintBoundary` harness'i, sonra silindi) gözle kontrol edildi:
       başlığın üstünde, kuyruk OHP'yi gösteriyor, metin büyük harfe
       dönmemiş, kırpılma yok.

   - ✅ **Parça 64 — CI'da tekrarlayan sqflite timer flake'i:
     `setup_cloud_test.dart` yük altında düşüyordu (12 Ağustos 2026,
     `setup_cloud_test.dart`):** Port dalı `main`'e merge edilirken CI'ın
     `Analiz + testler` işi düştü; log'da tek hata `A Timer is still
     pending even after the widget tree was disposed.` (`!timersPending`,
     `binding.dart:2542`) ve yığın izi doğrudan sqflite'ın
     `txnWriteSynchronized`ına iniyordu: `_SetupScreenState._syncCloud` →
     `GamesRepo.flushPending` → `PendingQueueStore.readAll` → gerçek bir
     sqflite yazması (TTL süpürmesi).
     - **Sınıf zaten belgeliydi ama BU dosyada uygulanmamıştı:** Parça 11
       aynı hatayı `online_game_chat_test.dart`'ta yaşayıp çözmüştü
       (`tester.runAsync` + gerçek zaman payı; Parça 13'te 50ms yük
       altında yetmeyip 200ms'ye çıkarılmıştı). `setup_cloud_test.dart`'ın
       GERÇEK depoyu (`memGamesRepo`) kullanan testleri aynı yolu
       tetikliyordu ama hiç pay tanımıyordu — sahte zamanda yazma
       ilerlemediğinden sqflite'ın ~10 saniyelik kilit-uyarı `Timer`'ı
       iptal edilmeden kalıyordu.
     - **`tearDown`'da depoyu kapatmak ÇÖZMEZ** (denemeden önce SDK
       kaynağından doğrulandı): `!timersPending` kontrolü test GÖVDESİ
       biter bitmez, kullanıcı `tearDown`'undan ÖNCE çalışıyor. Gerçek
       zamanı gövdenin İÇİNDE tanımak tek yol.
     - **Düzeltme:** dosyaya ortak bir `drainRealIo(tester)` yardımcısı
       (200ms `runAsync` + `pump`) eklendi ve `memGamesRepo` kullanan DÖRT
       testin sonuna çağrıldı.
     - **Dürüst doğrulama sınırı — negatif eş KURULAMADI:** flake yerelde
       ÜÇ temiz tam koşuda (merge öncesi 356/356 ×2, düzeltme sonrası
       356/356) hiç tekrarlamadı; yalnızca CI'ın paylaşımlı runner'ında,
       dört ayrı koşuda (#91/#92/#93/#96 — üçü bu dosyada, biri
       kardeşinde) görüldü. Yani "geri alınca düşüyor" gösterilemez;
       gerçek kanıt CI'ın yeşile dönmesi. **Parça 13'ün dersinin bir üst
       basamağı:** tek dosya koşusu yanlış güven verir → tam paket koşusu
       da yanlış güven verebilir, bazı flake'leri YALNIZCA yüklü bir
       runner yakalıyor.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       356/356 yeşil** (yeni test yok — dört mevcut testin gövdesine
       gerçek-zaman payı eklendi). `kelimeki_core`'a hiç dokunulmadı.

   - ✅ **Parça 65 — "Tüm Oyunlarım"daki her karta hamle geçmişi ikonu:
     `games.moves` (12 Ağustos 2026, `game_record.dart`, `games_api.dart`,
     `game_history_modal.dart`, `board_widget.dart`, `history_entry.dart` +
     web `gameRecord.ts`/`api.ts`/`GameHistoryModal.tsx` +
     `games_moves_snapshot` migration'ı):** "Sonraya Bırakılan İşler"deki
     madde kapandı — kullanıcı isteği: *"mesaj balonunun yanına aynı boyda
     bir file ikonu koyup tüm hamleleri getirmek", "Lazy yükleme olarak.
     Hamleler dialogunda nasılsa aynısı gelsin, tüm detaylarıyla"*.
     - **Yeni UI maliyeti ~sıfır:** `MoveHistoryModal` (Parça 8) zaten
       hazır ve `GameState` alıyor; `buildSnapshotGameState([], playerCount,
       players)` üstüne `moveHistory` konarak açılıyor. Yeni modal, yeni
       bağımlılık, yeni asset YOK.
     - **İkon KOPYALANMADI, paylaşıldı:** `board_widget.dart`'ın alt
       şeridindeki `_DocumentIcon` public `DocumentIcon`a çevrildi (boyut +
       renk parametreli). Aynı şeyi açan iki kontrol aynı görünmeli
       (`RelationIcons` ilkesi). **Web tarafında da aynı hizalama
       yapıldı** — `GameHistoryModal.tsx`'in yeni `MovesIcon`'u
       `Board.tsx`'in path'leriyle birebir (ilk yazımda satır çizgileri
       `M8 13h8M8 17h5` diye sapmıştı, `M9 13h6M9 17h6` oldu).
     - **Dokunma hedefi BİLİNÇLİ olarak 44px'e çıkarılMADI:** Parça 52'nin
       "ikon-only kontrol 44px görünmez alan taşır" kuralı burada
       uygulanmadı — istek açıkça "aynı boyda" diyordu ve hemen yanındaki
       sohbet rozeti de 11px; 44px'lik bir alan ~20px'lik satırda kardeş
       kontrolleri ve kartın kendi dokunuşunu (tahtayı aç/kapa) yutardı.
       Iskalanan dokunuş yıkıcı değil (kart açılır). Cihazda rahatsız
       ederse İKİ rozet BİRLİKTE büyütülmeli.
     - **Ağ hatası ile "kaydedilmemiş" AYRI taşınıyor:** `GamesRepo.moves`
       artık `({bool ok, List<HistoryEntry>? moves})` dönüyor —
       `boardSnapshot`'ın ikisini de `null`a çeken davranışından BİLİNÇLİ
       sapma (web de ayırıyor). Çevrimdışı kullanıcıya "kaydedilmemiş"
       demek yanlış olurdu: veri sunucuda duruyor. Hata ÖNBELLEĞE GİRMEZ,
       tekrar dokunuş yeniden dener.
     - **SQL'de bulunan gerçek hata (kök `CLAUDE.md`'de ayrıntısı):**
       `_online_moves_snapshot`ın iki UNION dalı AYRI `row_number()`
       üretiyordu, vergi satırları yanlış sıraya düşüyordu — ortak bir
       `ordered` CTE'siyle düzeltildi. **İfadeyi gerçek veriye karşı
       KOŞTURDUĞUM için bulundu, okumakla değil.**
     - **Yan bulgu — `HistoryEntry.toJson`'ın anahtar SIRASI web'den
       sapmıştı:** port TS'in ARAYÜZ bildirim sırasını izliyordu, oysa
       `JSON.stringify` ÇALIŞMA ANINDAKİ ekleme sırasını yazıyor
       (`pushHistory`: turn, player, words, points, sonra wordScores…).
       Golden vector karşılaştırması YAPISAL olduğundan bugüne kadar
       görünmedi; `games.moves` iki istemcinin de aynı satırı yazmasını
       gerektirdiği an `web_game_record.json` fikstürü bunu bayt bayt
       yakaladı. Dart çalışma anı sırasına hizalandı. **Ders: "kanonik
       JSON" sözleşmesi TİP BİLDİRİMİNE değil, TS'in çalışma anındaki
       nesne literaline bakar.**
     - **Fikstür CERRAHİ yeniden üretildi:** web'in ÜRETİM
       `buildGameRecord`'u fikstürün KENDİ state'leriyle koşturulup
       yalnızca `record` yarısı yeniden yazıldı (girinti korunarak).
       Anlamsal diff: TEK değişiklik iki senaryoya eklenen `moves` (46 ve
       12 satır) — id/saat/tahta/skorlar bit düzeyinde aynı kaldı.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:**
       `game_likes_test.dart`'a iki test (rozet HER kartta + sohbet rozeti
       yokken de var + döküm gerçekten LAZY + modal içeriği; ağ hatası ile
       "kaydedilmemiş"in AYRI mesajlar olduğu + hatanın önbelleğe
       girmediği). `game_history_modal.dart` `git stash`lenince ikisi de
       GERÇEKTEN düştü (`+15 -2`); `history_entry.dart` ayrıca
       stash'lenince fikstür testleri GERÇEKTEN düştü (anahtar sırası —
       `Differ at offset 3296`), ikisi de geri konunca yeşile döndü.
       `FakeGamesGateway`e `movesCalls` eklendi (lazy iddiasının kanıtı).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       358/358 yeşil** (356'dan +2). `kelimeki_core` DEĞİŞTİ
       (`history_entry.dart`) — kural gereği Dart çekirdek testleri
       koşuldu: **6746 kontrol, 0 hata**; golden vector fixture'ları TS
       tarafı hiç değişmediğinden yeniden üretilmedi. Web `npm run lint` +
       `npm run build` temiz.
     - **Doğrulama sınırı:** gerçek `games.moves` okuması (kolon grant'i,
       gerçek satırlar) cihazda doğrulanmalı — `mobile/TESTING.md` bölüm
       5'e madde eklendi. Migration canlıya uygulandı ve altı değişmezle
       doğrulandı (bkz. kök `CLAUDE.md`).

   - ✅ **Parça 66 — "Nasıl Oynanır?"a rütbe/ödül bölümü + bölüm
     başlıklarının `uppercase`ı Parça 10'dan beri eksikmiş (12 Ağustos
     2026, `help_modal.dart` + web `HelpModal.tsx`):** Kullanıcı bir
     doküman-tazelik denetimi isterken *"mesela rank olayını nasıl oynanır
     alt kısma ekleyebiliriz"* dedi. Denetim onu doğruladı: k-lig bölümü
     yalnızca puanın nasıl KAZANILDIĞINI anlatıyordu — -2 cezası, ödül
     eşikleri ve dokuz rütbe hiçbir yerde yazmıyordu.
     - **Tablo ELLE YAZILMIYOR, `kRankTiers`ten çiziliyor** (web'de
       `RANK_TIERS`ten) — eşik/ödül değişirse iki ekran da kendiliğinden
       takip eder. Bu bilinçli: kademe tablosu zaten ÜÇ KOPYA elle senkron
       (SQL ↔ `leagueRank.ts` ↔ `league_rank.dart`); "Nasıl Oynanır?"a
       elle bir tablo yazmak DÖRDÜNCÜ kopyayı açardı ve sessizce
       ayrışacak ilk yer orası olurdu.
     - **Metin web'den BİREBİR kopyalandı** (Parça 10'un kuralı: kural
       metinleri özetlenmez) — `**kalın**` işaretlemesi `_runs()` ile
       TextSpan'e çevriliyor. Yeni `_RankRow` widget'ı `_TileRow`un hemen
       öncesinde: 26px'lik ortalanmış harf (kademe renginde) + kalın ad +
       " — N puan" + yeşil "(ödül +N)".
     - **YAN BULGU, kod okumasıyla DEĞİL yan yana render'la bulundu:**
       web'in `<h3 ... uppercase>`ı porta hiç geçmemiş — on bölüm başlığı
       da ("Puan Tablosu", "Bölge Vergisi"…) küçük harfle çiziliyordu.
       Parça 10 "web'in yardımcıları birebir taşındı (Section/P/Pill/…)"
       diyordu, yani niyet buydu, yalnızca `text-transform` atlanmıştı.
       `trUpper` eklendi — native `toUpperCase` DEĞİL (Türkçe kural:
       "Nasıl" → "NASIL", noktalı I üretmemeli). **Bu, istenen işin
       KAPSAMI DIŞINDAYDI ve bilerek yapıldı:** aynı dosyada, tek satır,
       ve tam da bu projenin en sık tekrarlayan hata sınıfı (sessiz
       web↔port ayrışması); istenmezse tek satırlık geri alma.
     - **Ölçüm — iki ekran GERÇEKTEN yan yana render edildi:** mobil
       tarafta `HelpModal` 420×1400'de pump edilip bölüme kaydırılarak
       PNG'ye çekildi (geçici harness, sonra silindi); web tarafında
       `npm run build` çıktısı yerel bir sunucudan Playwright/Chromium'la
       açılıp aynı bölüme kaydırıldı. Uppercase farkı TAM BURADA görüldü —
       ekran görüntüsü olmadan iki tarafın kodunu okumak bunu vermezdi
       (`uppercase` bir CSS sınıfı, Dart'ta karşılığı yok, yani "eksik
       olan" görünmez bir şeydi).
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** yeni bir
       test dokuz kademenin `kRankTiers`ten çizildiğini (harf/ad/eşik/
       ödül; Çaylak'ta "(ödül +0)" YOK) ve -2 paragrafını doğruluyor;
       mevcut bölüm-başlığı testi büyük harfli beklentilere çevrildi
       (metinler ELLE büyük yazıldı ki `trUpper`ı kendisiyle
       karşılaştıran bir totoloji kurulmasın). `help_modal.dart`
       `git stash`lenince 2 test GERÇEKTEN düştü (`Found 0 widgets with
       text "Rütbeler ve Ödüller"`, `Found 0 widgets with text "Ç"`);
       ayrı bir turda yalnızca `trUpper(title!)` → `title!` çevrilince
       başlık testi GERÇEKTEN `bölüm yok: NASIL OYNANIR?` ile düştü.
       İkisi de geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       359/359 yeşil** (358'den +1). Web `npm run lint` + `npm run build`
       temiz. `kelimeki_core`'a hiç dokunulmadı (yalnızca `trUpper`
       import edildi) — golden vector turu gerekmedi.
     - ~~**Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor~~
       — **12 Ağustos 2026'da cihazda KOŞULDU ve GEÇTİ** (dokuz kademe,
       eşik/ödül değerleri ve büyük harf başlıklar; web'le yan yana
       ayrışma yok). Kontrol maddeleri `mobile/TESTING.md` bölüm 13'te
       (web'in eşi kök `TESTING.md` bölüm 10'da).

   - ✅ **Parça 67 — hamle ikonu artık yalnızca dökümü OLAN kartta; kullanıcının
     teşhisi ölçülerek çürütüldü (12 Ağustos 2026, `games_api.dart`,
     `game_history_modal.dart` + web `api.ts`/`GameHistoryModal.tsx` +
     `game_like_stats_has_moves` migration'ı):** Kullanıcı bildirdi: *"Tüm
     oyunlarda ikon var ama YZ oyunlarda içi boş geliyor, canlı oyunlarda
     dolu geliyor. YZ hiç olmayacaksa onlarda ikonu göstermesek daha iyi."*
     - **Önerilen düzeltmeyi UYGULAMADIM, çünkü dayandığı varsayım ölçümle
       çürüdü.** Canlıda: 245 yerel oyunun tamamı `moves is null`, 66 Canlı
       oyunun tamamı dolu — kullanıcının gözlemi doğru. Ama sebep TÜR değil
       ZAMANLAMA: en yeni yerel oyun 12:09 UTC'de bitmiş, kolon 15:27'de
       açılmış (`games_moves_snapshot`), yazan kod 16:04'te deploy edilmiş
       (#241). Yani kolon var olduğundan beri HİÇ yerel oyun bitmemiş;
       `buildGameRecord` `moves`u yazıyor ve `saveGame` kaydı
       `insert({...game})` ile olduğu gibi gönderiyor (ikisi de kaynaktan
       doğrulandı), dolayısıyla bundan sonra bitenler DOLU olacak.
       "YZ'de hiç gösterme" kuralı o oyunları kalıcı olarak sakatlardı.
     - **Kullanıcının NİYETİ yine de doğruydu ve uygulandı:** boş bir
       diyalog açan ikon kötü bir kontrol. Doğru kural tür bazlı değil veri
       bazlı — **"dökümü olmayan kartta gösterme"**.
     - **Karar bilgisi `moves` çekilmeden gerekiyor** (satır başına ~6.8 KB;
       lazy yükleme tam bu yüzden var), o yüzden kartın öteki rozetlerini
       zaten besleyen `game_like_stats` RPC'sine `has_moves` eklendi —
       sayfa başına TEK toplu çağrı, EK GİDİŞ-DÖNÜŞ YOK. `message_count`in
       Parça 51'de aynı RPC'ye taşınmasıyla birebir aynı desen.
     - **Sahte uç de gerçek ucun bu kararını taklit ediyor:**
       `FakeGamesGateway.likeStats` artık `has_moves`u `movesByGame`den
       türetiyor — Parça 46'nın dersi (sahtenin eksik bir dalı, o dal
       hakkındaki testleri sessizce anlamsız kılar). Bu olmadan yeni kural
       testlerde hiç sınanamazdı.
     - **Ulaşılamaz hale gelen bir test dalı düzeltildi:** eski test "kolon
       null → 'kaydedilmemiş'" mesajını doğruluyordu; ikon artık o kartta
       hiç çizilmediğinden o modal UI'dan AÇILAMIYOR. Test, yeni ve gerçek
       kullanıcı davranışını ölçecek şekilde yeniden yazıldı (dökümü olan
       kart ikonu gösterir, olmayan göstermez); "kaydedilmemiş" dalı kodda
       savunma amaçlı duruyor. Ağ hatası dalı KORUNDU — o hâlâ ulaşılabilir
       (sunucuda döküm var, istek düşüyor), yalnızca kurgusu `movesByGame`
       dolu olacak şekilde düzeltildi.
     - **Test — negatif eş doğrulamasıyla:** yeni test aynı listede dökümü
       OLAN ve OLMAYAN iki kart kuruyor — tek başına "YZ'de gösterme" gibi
       yanlış bir kural da geçerdi, o yüzden ikisi bir arada.
       `game_history_modal.dart` `git stash`lenince test GERÇEKTEN
       kullanıcının bildirdiği semptomu üretti (`Found 1 widget with key
       [<'moves-g-eski'>]`), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 360/360
       yeşil** (359'dan +1). Web `npm run lint` temiz. Migration canlıya
       uygulandı ve gerçek JWT'yle üç kontrolle doğrulandı (Canlı hepsi
       true, güncel yerel hepsi false, ve **en kritiği** bir YEREL satıra
       `moves` yazılınca bayrak true'ya döndü — geri alındı).
       `kelimeki_core`'a hiç dokunulmadı.
     - ~~**Doğrulama sınırı:** "yeni biten bir YZ oyununda ikon GERÇEKTEN
       çıkıyor mu" bu ortamdan doğrulanamaz~~ — **12 Ağustos 2026'da
       cihazda KOŞULDU ve GEÇTİ:** yeni bitirilen bir YZ oyununun kartında
       ikon çıktı, döküm doluydu. Kolon açılalı beri hiç yerel oyun
       bitmemişti, yani bu, "bundan sonra bitenler DOLU olacak"
       çıkarımının ilk gerçek uçtan uca kanıtı — Parça 67'nin kullanıcının
       teşhisini ("YZ'de hiç olmayacak") çürüten ölçümü doğrulandı.
       Kontrol maddeleri `mobile/TESTING.md` bölüm 5 ve kök `TESTING.md`
       bölüm 3'te. **Aynı turda dokunma alanı sorunu bildirildi → Parça
       68.**

   - ✅ **Parça 68 — hamle rozetinin dokunma alanı sohbet rozetinin YARISIYMIŞ
     (12 Ağustos 2026, `game_history_modal.dart` + web `GameHistoryModal.tsx`):**
     Parça 67'nin doğrulama sınırı cihazda koşuldu ve **geçti** (yeni bitirilen
     bir YZ oyununda ikon çıktı, döküm doluydu) — ama aynı turda kullanıcı yeni
     bir sorun bildirdi: *"hamleler ikonuna elle dokunmakta zorlandım, en az 4-5
     kere dokunmam gerekti. Tam basamazsan oyun detayları açılıp kapanıyor
     sürekli. Mesaj ikonu iyi bence, onunla aynı şekilde olabilir."*
     - **Parça 65 bu şikâyeti ÖNCEDEN yazmıştı** ("cihazda rahatsız ederse İKİ
       rozet BİRLİKTE büyütülmeli") — yani karar bilinçliydi, yalnızca ölçüsü
       yanlıştı. O not "aynı boyda" istendiği için hedefleri EŞİT sanıyordu.
     - **Ölçüm bunu çürüttü, üstelik İKİ platformda birden:** gerçek widget +
       gerçek fontlarla sohbet **18.8×13.0 = 244px²**, hamle **11×11 = 121px²**
       — tam yarısı. Web'de aynı yapı, aynı sonuç (derlenmiş CSS + Chromium):
       sohbet 18.9×13.5 = 255px², hamle 12×12 = 144px². **Fark tesadüf değil
       yapısal:** sohbet kontrolünün dokunma kutusuna sayı ETİKETİ de dahil
       (`Row(icon, gap, Text('N'))`), hamle ikonunda etiket yok. İki istemcinin
       6px'lik boşluğu bile birebir aynı çıktı — kusur ortak, düzeltme de ortak.
     - **Düzeltme ikonu YERİNDEN OYNATMIYOR:** dolgu eklenip önündeki boşluk
       aynı kadar kısılıyor (mobil `SizedBox` 6→2 + `horizontal: 4`; web
       `px-1 py-px` + `-mx-1` negatif margin, yani layout ayak izi hiç
       değişmiyor). Sonuç: mobil 121→**247px²**, web 144→**280px²**, ikonun
       görsel konumu ve 6px boşluk BİREBİR aynı (ölçüldü: mobilde kutu sol
       kenarı 225.6→221.6, +4px dolgu ile ikon yine 225.6'da).
     - **Dikey neden 13'te kaldı:** satırın kendi yüksekliği zaten 13 (kalp ve
       sohbet ikisi de 13); daha fazlası satırı, dolayısıyla HER kartı büyütür.
       44px'lik iOS asgarisi yine UYGULANMADI — Parça 65'in gerekçesi
       (~13px'lik satırda 44px'lik alan kardeş kontrolleri ve kartın kendi
       dokunuşunu yutar) hâlâ geçerli, ve kullanıcı çıtayı zaten "mesaj ikonu
       kadar" diye koydu.
     - **Test bir SABİTİ değil ORANI kilitliyor:** yeni test iki kutuyu ölçüp
       `hamle >= sohbet` diyor (+ ikonun görsel konumunun kaymadığını). Sohbet
       rozeti ileride değişirse hamle rozeti onunla taşınmak ZORUNDA kalır —
       Parça 65'in "iki rozet birlikte" notunun çalıştırılabilir hâli; yorum
       satırı bunu sağlamıyordu, nitekim sağlayamadı.
     - **Negatif eş:** `game_history_modal.dart` `git stash`lenince test
       GERÇEKTEN kullanıcının semptomunu üretti (`Expected: >= 18.758, Actual:
       11.0`), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 361/361
       yeşil** (360'tan +1). Web `npm run lint` + `npm run build` temiz.
       `kelimeki_core`'a hiç dokunulmadı — golden vector turu gerekmedi.
     - **Doğrulama sınırı:** "artık rahat dokunuluyor" ancak gerçek parmakla
       ölçülür — `mobile/TESTING.md` bölüm 5'e madde eklendi.

   - ✅ **Parça 69 — kutlama/düşüş banner'ında "DEVAM" kalktı, yerine ✕
     (12 Ağustos 2026, `reward_banner.dart` + web `RewardBanner.tsx`):**
     Kullanıcı, bölüm 13'ün cihaz turunda: *"bence bu banner'larda kapat,
     devam vb olmamalı, sadece X."* Bu, AYNI GÜN `RankInfoModal`'a verilen
     kararın (ilk sürümde bilinçli olarak yalnızca popup'a uygulanmıştı)
     banner'lara genişletilmesi — o notta *"Banner'ın DEVAM'ı KALIR: o
     gerçek bir aksiyon"* yazıyordu; gerekçe teknik olarak doğruydu ama
     kullanıcı görsel tutarlılığı tercih etti. Eski karar dört yerde birden
     yazılıydı (kök + mobil `CLAUDE.md`, kök + mobil `TESTING.md`,
     `rank_info_modal.dart` yorumu) ve hepsi düzeltildi — bayat kalan bir
     "KALIR" cümlesi bir sonraki oturumu geri aldırırdı.
     - **Asıl risk kozmetik DEĞİL:** "DEVAM" yalnızca kapatmıyordu,
       `onClose` → `LeagueRewardsHost._close` → `markSeen()` zincirini
       tetikleyen TEK yoldu (`mark_league_rewards_seen`). Butonu silip ✕'i
       farklı bir yola bağlamak, banner'ı **her açılışta yeniden gösteren**
       bir hataya yol açardı. ✕ bilerek AYNI `widget.onClose`'a bağlandı;
       web'de de aynı (`useModalA11y` üzerinden Escape zaten oraya bağlı).
     - **✕ kopyalanmadı, `RankInfoModal`'dan birebir alındı** (mobilde
       `IconButton` + `Icons.close` 18px/`kMuted`/`tooltip: 'Kapat'`,
       webde `Modal.tsx`'in class'ları) — iki kart aynı kart, ikisi
       birlikte değişir.
     - **Kapsam sınırı (bilinçli):** "DEVAM" metni başka iki yerde daha
       var — `FriendSuggestModal` ve sohbet hoşgeldin popup'ı. İkisi de
       birer ONAY adımı (istek gönder / karşılandı), kapatma butonu değil;
       kullanıcının cümlesi "bu banner'lar" diyordu. Dokunulmadı.
     - **Test — negatif eş doğrulamasıyla:** mevcut banner testi ✕'e
       çevrildi ve iki şeyi birden ölçüyor: tam genişlikte bir aksiyon
       butonu OLMADIĞI + ✕'in `markSeen`'i HÂLÂ çağırdığı (`markSeenCalls`
       0 → 1). `reward_banner.dart` `git stash`lenince test GERÇEKTEN düştü
       (`Found 0 widgets` — ✕ yok), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; tam takım
       **361/361** yeşil. Web `npm run lint` + `npm run build` temiz.
       `kelimeki_core`'a dokunulmadı.
     - **Doğrulama sınırı:** cihazda görsel teyit + "kapattıktan sonra bir
       daha çıkmıyor" kontrolü kullanıcıdan bekleniyor — kök ve mobil
       `TESTING.md`'deki ilgili madde bu iki şeyi birlikte soracak şekilde
       yeniden yazıldı.

   - ✅ **Parça 70 — banner başlıklarına emoji + KARTIN GENİŞLİĞİ web'den
     sapmış çıktı (12 Ağustos 2026, `reward_banner.dart` + web
     `RewardBanner.tsx`):** Kullanıcı iki turda istedi: önce *"Rütben
     Geriledi!'nin yanına üzgün emoji"*, ardından *"👏 bunu rütbe
     yükseltmeye, 🎉 bunu da 100'lerde koyabiliriz"*. Üç başlık:
     `'Rütben geriledi! 😔'` (pensive — "Üzgünüz…" alt satırının nazik
     tonuyla eşleşiyor; 😢 fazla dramatik kalırdı),
     `'Yeni rütben: X! 👏'`, `'N k-lig puanına ulaştın! 🎉'`. Dördüncü
     varyant (`'Eşik ödülü kazandın!'`) BİLEREK emojisiz kaldı — kullanıcı
     onu saymadı ve pratikte neredeyse hiç görünmüyor (rütbe/kilometre
     taşı olmadan tek başına ödül).
     - **Aynı turda "100'lerde de X olmalı" isteği zaten karşılanmıştı:**
       DEVAM butonu ortak düzendeydi, Parça 69'da kaldırılınca dört
       varyanttan birden kalkmıştı.
     - **GERÇEK BULGU — kartın genişliği web'den sapmış, ✕ dışarı
       taşıyordu:** kutlama ekran görüntüsüne bakınca ✕'in kartın DIŞINDA,
       gri zeminde durduğu görüldü. Ölçüm sebebi verdi: web'de kart
       `w-[280px]` ile HER ZAMAN 280, portta ise Stack'in
       konumlandırılmamış çocuğu GEVŞEK kısıt aldığından **içeriğe göre
       büzülüyordu** (kutlama 238.5, düşüş 280 — düşüş kartı ilerleme
       çubuğu sayesinde 280'e ulaştığından orada görünmüyordu).
       `Positioned(right: 8)` Stack'e göre konumlandığı için dar kartta ✕
       dışarı düşüyordu. **Bu sapma ✕'ten ÖNCE de vardı**, yalnızca
       ölçülecek bir kenar olmadığından görünmüyordu. Düzeltme yamayla
       (✕'i kaydırmak) değil web'e hizalayarak: `width: double.infinity`.
     - **Ders:** bir ekran görüntüsünü "emoji çıktı mı" diye açıp
       geçmeyin — Parça 69'un ✕'ini DÜŞÜŞ görüntüsünde doğrulamıştım ve
       "tamam" demiştim; aynı ✕ KUTLAMA varyantında bozuktu. Bir bileşenin
       tek varyantını görmek onu doğrulamaz.
     - **Regresyon testi:** kart genişliğinin 280 olduğu ve ✕'in kart
       sınırları İÇİNDE kaldığı artık ölçülerek doğrulanıyor (kutlama
       varyantında — bozuk olan oydu).
     - **Tek satırlık iş DEĞİL — bu projenin ÜÇ KEZ düştüğü tuzağa
       değiyor:** Flutter, tarayıcının aksine **otomatik font fallback
       YAPMAZ**; gömülü SpaceGrotesk'te bu glyph olmadığından fallback'siz
       **tofu (boş kare)** çizilir. Aynı hata daha önce `_StatusLine`'ın
       ✓'sinde, `help_modal`'ın 🎯'sinde ve ★'da yaşandı. Başlığın
       `TextStyle`'ına projedeki kurulu liste eklendi:
       `fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji']`
       (altı kullanım yeriyle aynı). Fallback yalnızca birincil fontta
       OLMAYAN glyph'ler için devreye girdiğinden kutlama başlıkları hiç
       etkilenmiyor. Web tarafında gerek yok — tarayıcı kendi fallback'ini
       yapıyor.
     - **Tofu OLMADIĞI okunarak değil GÖRÜLEREK doğrulandı:** ekran
       görüntüsü testi koşulup PNG açıldı — emoji renkli ve doğru glyph
       olarak çizilmiş (aynı görüntü Parça 69'un ✕'ini de kanıtladı:
       sağ üstte ✕, altta DEVAM yok).
     - **Cihaz uyarısı (Parça 29'un bulgusu, hâlâ geçerli):** Flutter
       Web/CanvasKit renkli emoji için çalışma anında
       `fonts.gstatic.com`'dan Noto Color Emoji ÇEKİYOR. GitHub Pages test
       derlemesi CanvasKit kullandığından, ağın Google Fonts'a erişimi
       kısıtlıysa emoji BOŞ görünebilir — bu bir kod hatası değil, web
       test ortamının yapısal sınırı. **Native (iOS/Android) derlemede bu
       risk YOK** (Skia/Impeller doğrudan işletim sisteminin emoji
       fontunu kullanır).
     - Doğrulama: `flutter analyze` temiz; tam takım **361/361** yeşil
       (iki başlık assertion'ı yeni metne çevrildi); web `npm run lint` +
       `npm run build` temiz.

   - ✅ **Parça 71 — Skor Kartı başlığında ✕ sola kaymıştı: `Flexible`ın
     görünmez `flex: 1`'i (12 Ağustos 2026, `modal_shell.dart`):** Kullanıcı
     mobil ve web Skor Kartı'nın ekran görüntülerini yan yana koyup
     *"mobilde X kaymış, ayrıca webdeki skor kartla ölçüleri farklı"* dedi.
     İKİ ayrı iddia vardı; ölçüm birini doğruladı, ötekini çürüttü.
     - **✕ — GERÇEK port hatası.** Web'de başlık `shrink-0` (doğal
       genişlik, hiç esnemez). Port bunu `Flexible(child: label)` diye
       taşımıştı — ama **`Flexible`ın varsayılanı `flex: 1`**: başlık boş
       alanın YARISINI pay olarak alıyor, `fit: loose` olduğundan doğal
       genişliğinde kalıyor ve **artan pay yeniden dağıtılmadığından**
       Row'un sonunda ölü boşluk olarak birikiyordu. Ölçüldü (360px kart):
       ✕'in merkezi sağ kenardan **75.3px** içerideydi; web'de (derlenmiş
       CSS + Chromium ile aynı düzen kurulup ölçüldü) **35.0**. Aynı hata
       mührü de kartın ortasına itiyordu (+12.7; web +35.6 — mühür kartın
       değil "başlık ile ✕ arasının" ortasında durmalı, kök CLAUDE.md'nin
       `headerCenter` kararı). Düzeltme: `headerCenter` varken başlık
       ÇIPLAK widget döner. Sonra: ✕ **32.0**, mühür **+34.3** — web ile
       ~1-3px içinde. (Kalan 3px, portun ✕ butonunun daha büyük dokunma
       hedefi taşımasından: 40px buton + 12 sağ dolgu ≈ web'in 28px buton +
       20 dolgusu. Bilinçli.)
     - **Yükseklik — port hatası DEĞİL, ölçülerek elendi.** Kullanıcı
       web'de "TÜM GEÇMİŞ OYUNLAR" linkinin göründüğünü, mobilde kesilip
       kaydırma gerektiğini bildirdi. Ölçüm: içerik İKİ tarafta da aynı
       (556px); fark yalnızca SINIRDA. iOS Safari'de CSS `vh` **büyük
       viewport**'u (tarayıcı çubuklarının altını da) sayar, yani web'in
       `max-h-[85vh]`'si görünür alanın %85'inden BÜYÜK olabiliyor;
       Flutter'ın `MediaQuery.sizeOf(context).height`'i ise görünür alan.
       Aynı iPad'de: Safari görünür yükseklik 683 → modal 580.5 (%85) →
       **52.5px kesiliyor**. Native'de kesilme YOK: iPad yatay (834),
       iPad dikey (1194), iPhone dikey (852) — üçünde de modal 633'te
       (içerik boyu) kalıyor, sınıra hiç dayanmıyor. Yani sorun ASIL
       ÜRÜNDE yaşanmıyor, yalnızca web test derlemesinde görünüyor.
       Sabit DEĞİŞTİRİLMEDİ — %85 web'in yazılı kararı ve native'de zaten
       yetiyor; bir Safari tuhaflığı için iki platformun da davranışını
       değiştirmek yanlış olurdu. (`score_card_test.dart`de bu zaten
       "gerçek cihaz boyutlarında kaydırmasız sığar" testiyle korunuyordu.)
     - **Ders:** web'in `shrink-0`/`flex-1` gibi sınıflarını porta
       çevirirken Flutter'ın VARSAYILANLARINI oku — `Flexible` "esneme"
       değil "esneme payı al" demek. Bu, sınıfın adına bakıp doğru
       göründüğü için gözden kaçan bir sınıf hata.
     - **Test:** yeni bir regresyon testi ✕'in sağ kenardan uzaklığını ve
       mührün merkezden sapmasını gerçek `ScoreCardModal` üzerinde
       ölçüyor (ikisi de web'in ölçülen değerlerine bağlı).
     - Doğrulama: `flutter analyze` temiz; tam takım **362/362** yeşil
       (361'den +1). Web'e hiç dokunulmadı (yalnızca ölçüm için kullanıldı).

   - ✅ **Parça 72 — Setup web'den %7.5 GENİŞ'ti: `max-w-[N] px-*` bir
     BORDER-BOX'tır (13 Ağustos 2026, `setup_screen.dart`,
     `friends_modal.dart`):** Kullanıcı aynı şikâyeti **ikinci kez**
     bildirdi: *"tablardan ikisi arasında geçiş yaptığımda butonların,
     kutuların ölçülerinin farklı olduğunu net görebiliyorum. Daha önce de
     belirtmiştim ama hala düzelmedi. Tüm app ölçülerini web ile
     karşılaştır."*
     - **Parça 29 bunu YARIM düzeltmişti.** O turda sabit 480→460'a
       çekilmişti; doğru sayı buydu ama **dolgunun yeri yanlıştı.**
       Tailwind `box-sizing: border-box` altında `max-w-[460px] px-4`
       demek "dış kutu ≤460, **içerik 460−32 = 428**" demek. Port ise
       yatay dolguyu `ConstrainedBox`'ın **DIŞINA** (`SingleChildScroll
       View.padding`) koymuştu → içerik 460, yani web'den **32px (%7.5)
       geniş**. Kullanıcının ekran görüntülerinden ölçülen oran
       (780/725 = **1.076**) bu 32px'le birebir örtüştü.
     - **Testin YEŞİL kalması bu hatanın hayatta kalma sebebiydi:** Parça
       29'un regresyon testi yalnızca "460'lık bir `ConstrainedBox` var mı"
       ve "eski 480 kalmamış mı" diye bakıyordu — ikisi de doğruydu, içerik
       yine de yanlıştı. Test artık GERÇEK genişliği ölçüyor (tam genişlik
       buton = **428**); negatif eşle doğrulandı (düzeltme geri alınınca
       `Actual: 460.0`). **Ders: bir kısıtın VARLIĞINI doğrulayan test, o
       kısıtın SONUCUNU doğrulamaz.**
     - **Denetim — web'deki `max-w-[…]` kullanan HER yer tek tek
       karşılaştırıldı:**

       | Web | kutu + dolgu | içerik | Port | Durum |
       |---|---|---|---|---|
       | `Setup.tsx:536` | 460 + `px-4` | 428 | dolgu DIŞARIDA | **düzeltildi** |
       | `Board.tsx:416` | 680 + `px-3` | 656 | 680 + iç 12 | ✓ |
       | `GameHeader.tsx:89` | 680 + `px-3 py-2.5` | 656 | 680 + 12/10 | ✓ |
       | `App.tsx:1393` | 680 + `px-3` | 656 | ✓ | ✓ |
       | `OnlineGameScreen:1013` | 680 + `px-3` | 656 | ✓ | ✓ |
       | `Modal.tsx:38` | 360 | 360 | 360 | ✓ |
       | `ActionSheet:43` | 360 | 360 | 360 | ✓ |
       | Confirm/InfoDialog | `max-w-sm` 384 + `p-6` | 336 | 384 + **20** | **düzeltildi** (24) |

       Yani 680'lik oyun ekranı zinciri (Parça 40'ta düzeltilmişti) baştan
       DOĞRUYDU — dolgu orada zaten kutunun içinde. Yanlış olan iki yer
       Setup ve arkadaş diyaloglarıydı.
     - **Bilinçli bırakılan 2px:** web'de GİRİŞ satırı ayrı bir kutu
       (`App.tsx:1074`, 460 + `px-3.5`) olduğundan sağ kenarı içerik
       sütunundan 2px dışarıda; portta AccountButton aynı 16'lık dolgunun
       içinde, yani içerikle HİZALI. 2px için negatif margin/Transform
       hilesi yapmaya değmez ve hizalı olması daha doğru görünüyor.
     - Doğrulama: `flutter analyze` temiz; tam takım **362/362** yeşil.
       Web'e hiç dokunulmadı (yalnızca kaynak olarak okundu).

   - ✅ **Parça 73 — GİRİŞ satırı 12px aşağıdaydı: web'in `-mt-3`'ü gözden
     kaçmış (13 Ağustos 2026, `setup_screen.dart`):** Parça 72'nin genişlik
     düzeltmesi cihazda onaylandıktan hemen sonra kullanıcı: *"sağ üstteki
     giriş butonunun üstündeki boşluk app'de daha fazla, biraz aşağıda
     duruyor."*
     - **Web'de bu ekran İKİ ayrı kutu** (`App.tsx`, kurulum dalı): üstte
       `px-3.5 pt-3` ile GİRİŞ/avatar satırı, altında `main` içinde
       `px-4 py-6` ile Setup içeriği. Port tek sütun kullandığından dikey
       dolguyu `symmetric(vertical: 24)` ile simetrik vermişti → GİRİŞ'in
       üstü 24 (olması gereken 12).
     - **Asıl tuzak `py-6`nın 24'ünde DEĞİL:** Setup'ın logo bloğu
       `-mt-3` (**−12px**) negatif margin taşıyor, yani GİRİŞ ile logo
       arası 24 değil **12**. Bu görülmezse "arada 24 olmalı" diye yanlış
       düzeltilirdi. Derlenmiş CSS + Chromium'da iki viewport'ta (1000 ve
       420) ölçüldü: **12.0 / 12.0** — ikisi de viewport'tan bağımsız.
     - Düzeltme: kaydırma dolgusu asimetrik (`top: 12, bottom: 24`) ve
       AccountButton'ın `bottom: 4`'ü yerine KOŞULSUZ bir 12px boşluk
       (`auth.configured` false iken web'de de satır boş bir kutu olarak
       render edildiğinden logonun üstü yine 12+12 = 24 kalır).
     - **Ölçüm neden canlı siteden yapılamadı:** Chromium bu ortamdan
       `kelimeki.com`a çıkamıyor (`ERR_CONNECTION_RESET`, proxy) — bunun
       yerine `dist/assets/*.css` ile birebir DOM harness'i kurulup
       ölçüldü. Yerel `dist`i olduğu gibi servis etmek işe YARAMAZDI:
       Supabase env'i olmadan `UserMenu` hiç render edilmiyor.
     - **Test:** yeni bir regresyon testi iki boşluğu da ölçüyor
       (12/12); düzeltmeden önce GERÇEKTEN düştü (`Expected: <12>,
       Actual: <24.0>`).
     - Doğrulama: `flutter analyze` temiz; tam takım **363/363** yeşil
       (362'den +1). Web'e dokunulmadı.
     - **CI bu PR'da KIRMIZI döndü ama sebebi bu değişiklik DEĞİLDİ** —
       aşağıdaki flake; aynı commit'te düzeltildi.

   - ✅ **Parça 74 — sqflite timer flake'i geri döndü, bu kez YANLIŞ YERE
     pay tanındığı için (13 Ağustos 2026, `online_game_chat_test.dart`):**
     Parça 73'ün PR'ında (#245) CI'ın `Analiz + testler` işi düştü:
     `361 tests passed, 2 failed`. Düşen ikisi de
     `online_game_chat_test.dart`'ın "gerçek depo" grubundaydı ve hata
     Parça 11/13/64'ten tanıdık: *"A Timer is still pending even after the
     widget tree was disposed."*
     - **Benim diff'imle ilgisi yoktu** (yalnızca `setup_screen*`
       dosyalarına dokunulmuştu) ve bir önceki koşuda (#109) aynı testler
       geçmişti — yani flake.
     - **Ama kör bir "yeniden koş" doğru cevap değildi:** CI'ın yığın izi
       payın YANLIŞ YERDE olduğunu gösterdi. Testlerin sonundaki 200ms'lik
       `runAsync` payı, testteki yoruma göre modal açılışındaki
       `_markChatReadTo` yazması için konmuştu; oysa iz
       `_loadChat` → `_seedInitialUnread` → `ChatReadStore.markRead`'i
       işaret ediyordu — **EKRAN AÇILIŞINDA** başlayan başka bir yazma.
       Yüklü bir runner'da o yazma `pumpScreen`den sonra sarkıyor ve
       sondaki tek pay ona yetmiyor.
     - **Düzeltme sayıyı şişirmek değil, payı doğru noktaya koymak:**
       dosyaya ortak bir `drainRealIo(tester)` yardımcısı eklendi
       (`setup_cloud_test.dart`'takiyle aynı ad/desen), elle yazılmış iki
       bekleyiş ona çevrildi ve **`pumpScreen`den hemen sonra da**
       çağrıldı. Yani pay artık her İKİ yazma noktasının ardında.
     - **Doğrulama sınırı (Parça 64'ün aynısı):** flake yerelde hiç
       tekrarlamıyor (tam takım 363/363 yeşil), yalnızca CI'ın paylaşımlı
       runner'ında görülüyor — negatif eş kurulamaz, gerçek kanıt CI'ın
       yeşile dönmesi.

   - ✅ **Parça 75 — "Yükleniyor…" TERMİNAL bir duruma dönebiliyordu:
     senkronun herhangi bir adımı fırlarsa liste hiç çizilmiyordu
     (13 Ağustos 2026, `setup_screen.dart`):** Kullanıcı cihazda bildirdi:
     *"Ironman YZ tabına geçince 'yükleniyor' takılı kaldı."*
     - **Önce veri kontrol edildi, koda dalınmadı:** canlıda Ironman'ın
       `local_game_saves` satırı SIFIR — yani başarılı bir liste boş liste
       dönmeliydi ve ekranda "Devam eden bir Yapay Zeka oyunun yok."
       yazmalıydı. `CloudSaveRepo.list()` boş sonuçta null DÖNMÜYOR ve
       `TableWriteQueue` kilitlenmiyor (ikisi de kaynaktan doğrulandı), yani
       "sunucu boş döndü, ekran bunu gösteremedi" tek başına bir açıklama
       değildi.
     - **Kök sebep YAPISAL, web ile karşılaştırınca çıktı:** web'de misafir
       migrasyonu, `flushPendingGames` ve `refreshCloudSaves` ÜÇ AYRI
       effect — biri patlarsa ötekiler yine koşar. Port hepsini tek bir
       `_syncCloud` içinde ARDIŞIK `await`lerle koşturuyor; liste adımından
       ÖNCEKİ korumasız bir `await` fırlarsa fonksiyon oracıkta kesiliyor,
       `_cloudSaves` sonsuza dek `null` kalıyor ve `null` tam olarak
       "Yükleniyor…" demek. Üstelik çağrı `unawaited` olduğundan hata
       hiçbir yere düşmüyordu — ekranda tek iz kalıcı spinner.
     - **Düzeltme — izolasyon, yeni bir mekanizma değil:** senkronun dört
       riskli adımı (misafir migrasyonu, `services.games` Future'ı,
       liste+ceza, `pendingMirrorCount`) artık kendi `try`ında; her biri
       loglanıp AKIŞ DEVAM EDİYOR. Yani hangi adım patlarsa patlasın liste
       çiziliyor — web'in "ayrı effect" garantisinin tek fonksiyondaki
       karşılığı. Sıra/semantik değişmedi.
     - **Test — negatif eş doğrulamasıyla:** `setup_cloud_test.dart`'a
       `pendingMirrorCount`u fırlatan bir sahte repo (`ThrowingMirrorCountRepo`)
       + boş bir gateway ile yeni bir test: "Yükleniyor…" YOK, "Devam eden
       bir Yapay Zeka oyunun yok." VAR. Adımın `try`ı kaldırılınca test
       GERÇEKTEN kullanıcının semptomunu üretti (`Found 1 widget with text
       "Yükleniyor…"`), geri konunca yeşile döndü. Test yardımcısına
       (`services`/`pumpSetup`) opsiyonel bir `cloud` parametresi eklendi —
       verilmezse mevcut 10 çağrı yeri BİREBİR aynı.
     - **Bilinçli sınır:** hangi adımın gerçekten patladığı cihazda
       BİLİNMİYOR (log toplanamadı) — düzeltme bir adımı onarmıyor,
       "herhangi bir adımın patlaması ekranı kilitlemesin" sınıfını
       kapatıyor. Aynı belirti tekrarlarsa Setup'ın teşhis satırı (Parça 45)
       ve `debugPrint` çıktısı ilk bakılacak yer.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 364/364
       yeşil** (363'ten +1). `kelimeki_core`'a hiç dokunulmadı.

   - ✅ **Parça 76 — logo ile GİRİŞ/avatar satırı arası: bu sefer WEB porta
     uyduruldu (13 Ağustos 2026, `Setup.tsx` + `setup_screen.dart`):**
     Kullanıcı: *"App'de kelimeki logosuyla avatar satırı arası ideal şu
     anda. Ama web'de ekstra bir boşluk var. Web'i app gibi yap."*
     - **Ölçüm (derlenmiş CSS + Chromium, 420/1000):** web'de GİRİŞ
       butonunun altı ile logonun üstü arası **12**; portta (o an canlıda
       olan `main` derlemesi) **4**. Fark 8px.
     - **Parça 73 ile ÇAKIŞIYORDU ve fark edilmeseydi sessiz bir sapma
       doğuracaktı:** dün bu boşluğu portta 4'ten 12'ye çıkarıp web'e
       uydurmuştum (o PR henüz merge edilmediği için kullanıcının cihazda
       gördüğü hâlâ 4'tü). Yalnızca web'i 4'e çekseydim, #245 merge olunca
       port 12'ye çıkıp ayrışma TERS yönde geri gelecekti. Bu yüzden
       ikisi birden 4'e sabitlendi: portun `SizedBox(height: 12)`i 4'e
       geri alındı, web `-mt-3` → **`-mt-5`** (kabın `py-6`sından 20
       yiyor). **Parça 73'ün ASIL konusu olan ÜST boşluk (24 → 12)
       aynen duruyor** — o web'e uyum, bu ondan ayrı bir sayı.
     - **Yön istisnası bilinçli** (Parça 42'nin emsali): kural "web
       kanonik" ama kullanıcı açıkça portun görünümünü seçtiğinde web
       değişir — amaç estetik dayatma değil, sessiz ayrışmayı önlemek.
     - **Test — negatif eş doğrulamasıyla:** Parça 73'ün testi (`GİRİŞ
       satırının üstü/altı web ile aynı`) 12/4'e güncellendi; port 12'ye
       geri çevrilince GERÇEKTEN `Expected: <4> Actual: <12.0>` ile
       düştü, 4'e alınınca yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 364/364 yeşil**;
       web `npm run lint` + `npm run build` temiz. `kelimeki_core`'a hiç
       dokunulmadı.
     - **Doğrulama sınırı:** iki tarafın yan yana görsel teyidi
       kullanıcıdan bekleniyor (web canlıya, port GitHub Pages'e deploy
       olduktan SONRA — ikisi farklı zamanlarda yayına girdiğinden ara
       dönemde fark görünebilir).

   - ✅ **Parça 77 — logo altındaki paragraf 5 satır, web'de 4: Material 3'ün
     0.25 tracking'i (13 Ağustos 2026, `setup_screen.dart`):** Kullanıcı iki
     ekran görüntüsünü yan yana koydu — app'te "Ama" alt satıra düşüyordu.
     - **Kök sebep, "Sonraya Bırakılan İşler"de zaten yazılı olan borç:**
       `ThemeData(useMaterial3: true)` → `bodyMedium.letterSpacing = 0.25`,
       ve `letterSpacing` YAZMAYAN her `Text` bunu miras alıyor (widget'ın
       kendi style'ı o alanı `null` bıraktığında `Text` DefaultTextStyle
       ile MERGE ediyor). Web'de `text-xs font-mono` hiçbir letter-spacing
       kurmuyor (hesaplanan değer `normal`). 0.25 × ~57 karakter ≈ 14px →
       satır taşıyor. Ölçüldü: app 80px/5 satır, web 64px/4 satır.
     - **Düzeltme cerrahi:** paragraf + iki link + ayraç `letterSpacing: 0`.
       Global çözüm (temanın `textTheme`'ini 0'a çekmek) hâlâ doğru yol ama
       TÜM ekranların metin genişliğini değiştireceğinden ayrı bir ölçüm/
       ekran görüntüsü turu istiyor — o madde listede kaldı.
     - **Ayraç DEĞİŞTİRİLMEDİ, ölçülüp bırakıldı:** web `gap-2` (8+8) ile
       ayrılmış bir `·` kullanıyor (19.67), portun boşluklu `' · '`i 20.20 —
       0.5px fark; yeniden yapılandırmak kazanç değil risk olurdu.
     - **ÖLÇÜM TUZAĞI (bu turda iki kez düşüldü, ikisi de yakalandı):**
       (1) harness `file://` üzerinden açılınca Chromium woff2'yi CORS ile
       engelleyip SESSİZCE yedek monospace'e düşüyor — `getComputedStyle`
       hâlâ "Space Mono" diyor, ama ölçülen advance 0.602 (DejaVu), gerçek
       Space Mono 0.612. Çözüm: `python3 -m http.server` ile servis et ve
       canvas `measureText` ile advance'i DOĞRULA. (2) Yalnızca 400
       ağırlığını `@font-face` edip 700'ü unutunca linkler yedek fontla
       ölçülüyordu; 700 eklenince web değerleri portunkilerle birebir
       oturdu (94.25 / 121.19). İlk (hatalı) ölçüm "port %1.6 geniş" gibi
       görünen sahte bir fark üretmişti — düzeltmeye kalksam gerçek bir
       hatayı ÜRETECEKTİM.
     - **Mevcut test bu sapmayı NEDEN göremedi:** "Setup başlık bloğu"
       testi `fontSize`/`height` DEĞERLERİNİ kontrol ediyordu, ikisi de
       doğruydu; kırılan şey SONUÇTU (satır sayısı). Parça 72'nin dersinin
       birebir tekrarı. Yeni test render edilmiş yüksekliği (64 = 4×16) ve
       üç metnin EFEKTİF `letterSpacing`'ini ölçüyor; eski test de yerinde
       kaldı (o 390px'lik dar ekranı kapsıyor, yenisi 428px içerik için
       geniş ekran).
     - **Negatif eş:** `setup_screen.dart` `git stash`lenince test GERÇEKTEN
       `Expected: <64> Actual: <80.0>` ile düştü — yani kullanıcının
       bildirdiği semptomun ta kendisi.
     - Doğrulama: `flutter analyze` temiz, **tam takım 365/365 yeşil**
       (364'ten +1). Web'e HİÇ dokunulmadı (yalnızca ölçüm kaynağı olarak
       kullanıldı); `kelimeki_core`'a dokunulmadı.

   - ✅ **Parça 78 — M3 tracking'i tek kaynaktan kapatıldı; testler artık
     ÜRÜN temasıyla render ediyor (13 Ağustos 2026, yeni `ui/theme.dart` +
     `app.dart` + 25 test dosyası):** Parça 77'de Setup'ın bloğu tek tek
     yamanmıştı; kullanıcı "global letterSpacing düzeltmesini de yap"
     deyince "Sonraya Bırakılan İşler"deki borç kapatıldı.
     - **`kelimekiTheme()` (yeni `lib/src/ui/theme.dart`)** ürünün temasını
       tek yerde tanımlıyor; `zeroTrackingTextTheme` 15 metin stilinin
       (+`primaryTextTheme`) `letterSpacing`'ini 0'a çekiyor. YALNIZCA
       tracking sıfırlanıyor — punto/kalınlık/renk Material'ın kendi
       değerinde kalıyor (onlar zaten ekran ekran açıkça veriliyor).
     - **Asıl mesele tema DEĞİL, testlerin temayı TAKLİT ETMESİYDİ:** 25
       test dosyası kendi `ThemeData(fontFamily: 'SpaceGrotesk', …)`ını
       kuruyordu, yani `app.dart`'ı düzeltmek testlerde HİÇBİR ŞEY
       değiştirmezdi. 66 çağrı yeri `kelimekiTheme()`e çevrildi; bu aynı
       zamanda gerçek `colorScheme`i de testlere getirdi (Parça 71'in
       dersi: gerçek ekranı ölç, taklidini değil).
     - **Yeni `test/theme_test.dart` üç şeyi kilitliyor** (`color_tokens_test`
       deseninin tipografi karşılığı): `letterSpacing` yazmayan bir `Text`
       gerçekten 0 alıyor mu; temanın 15 stili de sıfır mı; ve **hiçbir
       test dosyası kendi `ThemeData`sını kurmuyor mu** — üçüncüsü olmadan
       bir sonraki oturum sessizce eski desene döner.
     - **Negatif eş:** `kelimekiTheme()`in `copyWith`i kaldırılınca ilk iki
       test GERÇEKTEN düştü (`Expected: <0> Actual: <0.25>` ve
       `displayLarge tracking taşıyor`), geri konunca yeşile döndü.
     - **Parça 77'nin yerel `letterSpacing: 0`ları BİLEREK duruyor** —
       artık gereksizler ama niyeti yerelde okunur kılıyorlar.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 368/368
       yeşil** (365'ten +3). Ekran görüntüleri yeniden üretilip gözle
       incelendi (Setup formu, Skor Kartı, Arkadaşlar modalı) — tema
       değişiminin bozduğu bir yer yok. `kelimeki_core`'a ve web'e hiç
       dokunulmadı.
     - **Doğrulama sınırı:** tracking kalkınca metinler ~%1-2 daralıyor;
       testler geometriyi (428 içerik, 44px sekme, 64px paragraf…) hâlâ
       doğruluyor ama TÜM ekranların cihazda gözle kontrolü kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 0.5'e madde eklendi.

   - ✅ **Parça 79 — giriş alanlarının 8 kopyası tek kaynağa indi; web'in
     GERÇEK puntosu 14 değil 16'ymış (13 Ağustos 2026, yeni
     `ui/form_input.dart` + 8 dosya):** Borç listesinin ikinci (ve son
     mobil) maddesi kapandı.
     - **Web'de bu stil TEK bir sınıf dizisi** ve dokuz bileşende BİREBİR
       aynı: `w-full bg-bg border border-border rounded-md px-3 py-2
       text-sm text-text outline-none focus:border-accent`. Port onu sekiz
       dosyaya kopyalamış ve kopyalar ayrışmıştı: dolgu **8 ya da 10**,
       punto **16 ya da tema varsayılanı**, dolgu rengi **beyaz ya da
       `_bg`**. Parça 54'teki renk sürüklenmesiyle aynı sınıf.
     - **ÖLÇÜM bir varsayımı düzeltti:** Parça 56 bu maddeyi yazarken
       puntoyu `text-sm` = 14 sanıyordu. Gerçekte `index.css`teki iOS zoom
       kuralı (`input, textarea, select { font-size: 16px !important }`)
       sınıfı EZİYOR — web'de görünen punto **16**. Ölçülen web değerleri:
       yükseklik **38** · punto **16** · satır **20** · dolgu **8/12** ·
       çerçeve 1px `#DCE2EA` (odakta `#2563EB`) · yarıçap 6 · zemin beyaz.
     - **Dikey dolgu 9, 8 DEĞİL — ve bu bir sihirli sayı değil:** CSS'te
       çerçeve kutunun DIŞINA eklenir (20+16+2 = 38); Flutter'da
       `OutlineInputBorder` çerçeveyi kutunun İÇİNE boyar, yani 8 dolguyla
       dış ölçü 36 kalıyordu. 1px çerçeve payı eklenince dış kutu 38 VE
       çerçevenin içindeki boşluk web'deki gibi 8 oluyor (ölçüldü;
       `kInputHeight` sabiti bunu adlandırıyor).
     - **`test/theme_test.dart` iki yeni kontrol aldı:** alanın gerçekten
       38 yüksekliğinde ve 16/20 puntoda render edildiği + **`lib/` altında
       ham `InputDecoration(` kurucusu kalmadığı** (regex `kInputDecoration(`
       çağrılarını yakalamıyor). İkincisi olmadan bir sonraki oturum yeni
       bir kopya açar ve kimse fark etmez.
     - **Negatif eş:** dolgu 8'e çekilince yükseklik testi GERÇEKTEN
       `Expected: <38.0> Actual: <36.0>` ile düştü; tarama regex'i
       gevşetilince (ham `contains`) sekiz dosya listelenip düştü.
     - **Temizlik:** kopyalarla birlikte ölü kalan yerel `_border`/`_accent`/
       `_text`/`_bg` sabitleri ve `reset_password_modal`ın yerel `border()`
       yardımcısı da silindi (analyze temiz).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 370/370
       yeşil** (368'den +2). Ekran görüntüleri yeniden üretilip gözle
       incelendi (kayıt formu, sohbet kutusu) — alanlar tek tip.
       `kelimeki_core`'a ve web'e hiç dokunulmadı.
     - **Doğrulama sınırı:** klavye açıkken gerçek cihazda alanların
       görünümü (özellikle çok satırlı sohbet/şikayet kutuları) gözle
       kontrol edilmeli — `mobile/TESTING.md` bölüm 0.5'e madde eklendi.

   - ✅ **Parça 80 — "+ Yeni …" butonu ve alt sekme satırı: üç boşluk da
     web'den dardı (13 Ağustos 2026, `setup_screen.dart`,
     `live_games_tab.dart`):** Kullanıcı bildirdi — *"yeni oyun aç butonu
     ile altındaki devam edenler butonları arasındaki fark web'den daha
     dar"*.
     - **Web'de bu boşlukların HİÇBİRİ elle yazılmıyor:** kapsayıcının
       `gap-5`i (20) butonla sekme satırı ve sekme satırıyla içerik
       arasını, sekme satırının `gap-2`si (8) de sekmelerin kendi arasını
       veriyor. Port üçünü de kendi sayılarıyla yazmıştı: **12 / 6 / 12**.
     - **Aynı turda ikinci bir sapma:** butonun kendisi. Web `text-sm`
       (14/20) + `py-2.5` → tam **40**; Setup onu 44'lük bir `SizedBox`'a
       sarıyordu, `LiveGamesTab` ise 13 punto + 12 dolguyla ~39.6 veriyordu
       — yani iki kardeş ekran birbirinden DE ayrışmıştı. İkisi de web'in
       değerlerine çekildi (`fontSize: 14`, `lineHeight: 20/14`,
       `padding: vertical 10`).
     - Ölçüm derlenmiş CSS + Chromium'da: buton **40** · buton→sekme **20**
       · sekmeler arası **8** · sekme→içerik **20** · sekme kutusu **38.5**.
     - **Test tuzağı — sekme METNİNDEN boşluk ölçme:** sekmeler `flex-1`
       ve metin ortalı olduğundan iki METİN arasındaki mesafe (101.6) kutu
       aralığıyla (8) hiç ilgili değil. Test kutuyu buluyor
       (`find.ancestor(... Stack).first`), metni değil.
     - **Negatif eş:** `setup_screen.dart` `git stash`lenince test
       GERÇEKTEN `Expected: <40> Actual: <44.0>` ile düştü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       371/371 yeşil** (370'ten +1). `kelimeki_core`'a ve web'e
       dokunulmadı.

   - ✅ **Parça 81 — yuvarlak avatarın ink vurgusu KAREYDİ: `PopupMenuButton`
     `borderRadius`unun varsayılanı yok (13 Ağustos 2026,
     `account_button.dart`):** Kullanıcı bildirdi — *"avatarın üzerine mouse
     ile gelince ve basınca yuvarlak avatar etrafında karenin köşelerini
     görebiliyorum. Web'de böyle bir şey olmuyor."*
     - **Web kaynağı önce okundu (kuralın ilk adımı) ve farkı verdi:**
       `UserMenu.tsx`'in avatar butonu `rounded-full active:scale-95
       transition-transform ring-offset-2 focus:outline-none` — yani
       **hiçbir zemin vurgusu YOK**, tek geri bildirim basınca küçülme.
     - **Kök sebep SDK kaynağından doğrulandı, tahmin edilmedi:**
       `PopupMenuButton`, `child` verildiğinde onu
       `InkWell(borderRadius: widget.borderRadius, …)` ile sarıyor
       (`popup_menu.dart:1712`) ve `borderRadius` alanının **varsayılan
       değeri yok** (satır 1350) → `null` → ink DİKDÖRTGEN. Hover/focus/
       basılı katmanı 32×32 kutuyu boyayıp dairenin dışındaki dört köşeyi
       görünür kılıyordu.
     - **ÖLÇÜLDÜ (geçici probe, sonra silindi):** `RepaintBoundary` ile
       yakalanan karede, avatarın kutusunda dairenin BELİRGİN dışında
       (yarıçap + 1.5px anti-alias payı) kalan beyaz olmayan piksel sayısı —
       dokunulmamış **0**, basılı **120** (`#efefef`, tam köşeden başlıyor:
       `(0,0)`, `(1,0)`…). Düzeltmeden sonra basılı **0**.
     - **İlk probe YANLIŞ "0" verdi ve bu kendi başına bir ders:** ink
       efektleri en yakın `Material` ATA'sının render nesnesi tarafından
       çizilir; `RepaintBoundary` o Material'ın ALTINDAysa yakalanan karede
       ink HİÇ görünmez. Boundary'nin İÇİNE kendi `Material`'ını koyunca
       ölçüm gerçeği gösterdi. **Bir "temiz" piksel ölçümü, ölçtüğün
       katmanın gerçekten o pikselleri boyayan katman olduğunu
       kanıtlamadan bir şey kanıtlamaz.**
     - **Düzeltme:** `borderRadius: BorderRadius.circular(avatarSize / 2)`
       — kutu kare (KAvatar `size × size`; `dot: true` iken bile `Stack`
       konumlandırılmamış çocuğuna göre boyutlandığından kutu büyümüyor),
       dolayısıyla yarıçap = yarım kenar tam daire veriyor.
     - **Kapsam taraması (Parça 54'ün dersi — mekanizmanın DİĞER
       örneklerini ara):** `PopupMenuButton` kod tabanında TEK yerde
       (`account_button.dart`). Öteki yuvarlak dokunma hedefleri risksiz —
       `IconButton` (✕, dişli, şifre göster) Material'da zaten
       `highlightShape: BoxShape.circle`, `_relationIconButton`
       (`friends_modal.dart`) hiç ink'siz `GestureDetector`, `InkWell`'in
       tek doğrudan kullanımı da dikdörtgen olması gereken `ActionSheet`
       satırı.
     - **Kalan bilinçli fark:** web'de HİÇ overlay yok (yalnızca
       `active:scale-95`); portta artık DAİRESEL bir Material overlay'i
       var. Kaldırmak yerine daireye çekmek seçildi — bildirilen hata
       "köşeler görünüyor"du ve dokunmatikte hiçbir geri bildirim
       bırakmamak web'in scale-95'ini de port etmeyi gerektirirdi (ayrı
       bir iş). Ayrışma burada kayıtlı.
     - **Test YAPISAL, gerekçesiyle birlikte:** basılı durumu piksel piksel
       yakalayan bir test bu binding'de SONLANMIYOR (menü açılış animasyonu
       + M3 `InkSparkle` `pumpAndSettle`'ı asıyor; `Timeout` ile
       doğrulandı). Bu yüzden kalıcı test `PopupMenuButton.borderRadius`'u
       VE aynı yarıçapın gerçekten `InkWell`'e indiğini sabitliyor —
       Parça 34'ün deseninin aynısı (bir kez piksel ölç, kalıcı testte
       sözleşmeyi pinle).
     - **Negatif eş:** `account_button.dart` `git stash`lenince test
       GERÇEKTEN `Expected: not null / Actual: <null>` ile düştü, geri
       konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       372/372 yeşil** (371'den +1). `kelimeki_core`'a ve web'e
       dokunulmadı.
     - **Doğrulama sınırı:** cihazda (gerçek trackpad hover + dokunuş)
       görsel teyit kullanıcıdan bekleniyor — `mobile/TESTING.md` bölüm
       2'ye madde eklendi.

   - ✅ **Parça 82 — avatar DEĞİŞTİRME 20 Temmuz'dan beri kırıkmış; port
     hatası DEĞİL, sunucu politikası (13 Ağustos 2026,
     `avatars_owner_read_for_upsert` migration'ı):** Kullanıcı bölüm 12'yi
     koşarken fotoğraf güncellemede `StorageException(message: new row
     violates row-level security policy, statusCode: 403)` aldı.
     - **Parça 14'ün doğrulama sınırı KAPANDI** ("gerçek Storage upload'ı
       cihazda doğrulanmalı") — ve kapanır kapanmaz gerçek bir hata buldu.
     - **Önce web kaynağı okundu, sonra kod karşılaştırıldı:** portun
       `AuthService.uploadAvatar`'ı web `uploadAvatar` ile birebir (aynı
       yol `<uid>/avatar.<ext>`, aynı `upsert: true`, aynı MIME/boyut
       kontrolü). Yani kodda fark yoktu — sorun sunucudaydı.
     - **Kök sebep ve tam zincir kök `CLAUDE.md`'de** ("Profil fotoğrafı
       yükleme" maddesi): `security_hardening` (20 Temmuz) `avatars_public_read`
       SELECT politikasını "kova zaten public, gereksiz" diye düşürmüş;
       gerekçe okuma için doğru, ama `upsert` = `INSERT ... ON CONFLICT DO
       UPDATE` ve bu, çakışan satırın GÖRÜNÜR olmasını gerektiriyor.
     - **Ölçüldü, tahmin edilmedi:** üretimde geri alınan transaction'larla
       (a) sahibi olan kullanıcı kendi satırını göremiyor (`count = 0`),
       (b) hata BİREBİR yeniden üretildi (`ERROR: 42501: new row violates
       row-level security policy for table "objects"`), (c) düzeltmeyle
       hem üzerine yazma hem yeni uzantıyla ilk yükleme geçti, başkasının
       klasörü hâlâ 0 satır.
     - **Teşhis sırasında YAPTIĞIM HATA, kayda geçsin:** ilk denemede RLS'i
       simüle etmek için yazdığım `DO $$ ... $$` bloğunda `set local role
       authenticated` YOKTU — blok yükseltilmiş rolle koştu, RLS hiç
       uygulanmadı ve üretime GERÇEK bir sahte satır (`avatar.png`) yazdı.
       Fark edilip silindi (`storage.allow_delete_query` ile; storage
       tabloları doğrudan silmeye karşı trigger'la korumalı), ama
       `avatar.jpg`'nin `updated_at`'i bugüne kaydı (kozmetik, uygulama o
       alanı okumuyor). **Ders: RLS'i "simüle eden" bir sorgu, rolü
       gerçekten değiştirmiyorsa hiçbir şey simüle etmez — üstelik
       transaction'sız çalışırsa üretime yazar. `begin; set local role
       authenticated; set local request.jwt.claims = …; … rollback;`
       kalıbından şaşma.**
     - **`mobile/` DIŞINDA dosya değişti** (`supabase/migrations/`,
       `CLAUDE.md`) → kök `CLAUDE.md` aynı commit'te güncellendi (Parça
       Bitirme Kontrol Listesi madde 1).
     - ~~**Doğrulama sınırı:** düzeltme SQL seviyesinde kanıtlandı; gerçek
       istemciyle uçtan uca teyit bekleniyor~~ — **13 Ağustos 2026'da
       KAPANDI: kullanıcı hem uygulamada hem web'de fotoğrafı birkaç kez
       değiştirdi, 403 bir daha görülmedi.** Yani düzeltme yalnızca SQL'de
       değil gerçek storage-api yolunda da çalışıyor.

   - ✅ **Parça 83 — avatar giriş sınırı 10 MB, ama SAKLANAN küçültülüyor
     (13 Ağustos 2026, yeni `util/avatar_image.dart`, `avatar_picker.dart`,
     `auth_service.dart`, `account_settings_modal.dart` + web
     `api.ts`/`AccountSettingsModal.tsx`):** Kullanıcı Parça 82'nin
     düzeltmesinden hemen sonra *"2 Mb biraz az kalıyor, 2'nin altında
     resim bulamadım"* dedi. Ölçülen gerçek: iPhone HEIC 1.5-3 MB, iPhone
     JPEG 2-4 MB, Android 50-200MP 3-12 MB — 2 MB gerçekten dardı.
     - **Sınırı yükseltmek TEK BAŞINA yanlış çözüm:** 10 MB'lık bir
       orijinali, hiçbir zaman 96 px'den büyük gösterilmeyen bir avatar
       için depolamak ve her açılışta indirmek israf. 10 MB artık yalnızca
       "ne SEÇEBİLİRSİN" sınırı; saklanan her zaman küçültülmüş hâli
       (~50-150 KB). Kullanıcının sorusuna ("storage problemi olmayacak
       değil mi?") cevap: hayır — yükleme küçültmeden SONRA yapılıyor.
     - **Bellek tuzağı — "önce çöz, sonra küçült" YANLIŞ:** 48MP'lik bir
       görselin ham RGBA'sı ~190 MB. `ui.instantiateImageCodec`'in
       `targetWidth`'i çözmeyi ZATEN hedef boyutta yapıyor, tepe bellek
       küçük kalıyor. Ölçekleme bu yüzden kodek seviyesinde.
     - **İKİ KATMAN, çünkü `image_picker` her yerde aynı davranmıyor
       (kaynaktan doğrulandı, tahmin değil):** native'de
       `pickImage(maxWidth/maxHeight/imageQuality)` yeniden boyutlandırmayı
       platforma yaptırıp küçük bir JPEG döndürüyor; **Flutter web'de bu üç
       parametre sessizce yok sayılıyor** — `image_picker_for_web`
       kaynağında birebir yazılı ("not supported on the web ... silently
       ignored"). GitHub Pages test ortamı tam olarak o dal olduğundan
       ikinci katman (`shrinkAvatarIfNeeded`) şart. İkinci katman yalnızca
       400 KB eşiği aşılınca çalışıyor — native'de çalışsaydı küçücük bir
       JPEG'i PNG'ye çevirip BÜYÜTÜRDÜ (`dart:ui` yalnızca PNG/rawRgba
       yazabiliyor).
     - **Kare kırpma BİLİNÇLİ olarak yok:** avatar iki platformda da
       dairesel `cover` ile gösteriliyor, kırpma görüntüleme anında oluyor;
       web'in `uploadAvatar`'ı da hiç kırpmıyor.
     - **Bozuk/çözülemeyen görselde orijinal döner** — küçültme bir
       iyileştirme, yükleme yolunu kırmamalı; gerçek MIME/boyut doğrulaması
       zaten `AuthService.uploadAvatar`'da.
     - **Test — 4 birim + 1 kablo testi:** eşik altı AYNEN geçer (kodek hiç
       çağrılmaz), eşik üstü küçülür ve hedef kenar kodeke iletilir, kodek
       patlarsa orijinal döner, yeniden kodlama büyütürse orijinal korunur;
       ayrıca modal testi seçilen görselin YÜKLEMEDEN ÖNCE küçültme
       katmanından geçtiğini doğruluyor. Negatif eş: modaldeki çağrı geri
       alınınca test derleme hatasıyla düştü (parametre yok — kaba ama
       kesin: kablo yük taşıyor).
     - **`mobile/` DIŞINDA dosya değişti** (`src/lib/api.ts`,
       `src/components/AccountSettingsModal.tsx`, `CLAUDE.md`) → kök
       `CLAUDE.md` aynı commit'te güncellendi; web `npm run lint` temiz.
     - ~~**Doğrulama sınırı:** gerçek galeriden fotoğraf seçip saklanan
       boyutun küçüldüğünü görmek cihazda doğrulanmalı~~ — **13 Ağustos
       2026'da KAPANDI: kullanıcı iki platformda da birkaç kez yükleme
       yaptı, sorun çıkmadı.** Kontrol maddeleri (özellikle "saklanan
       dosya ~50-150 KB olmalı") `mobile/TESTING.md` bölüm 12 ve kök
       `TESTING.md` bölüm 9.5'te duruyor — ilerideki bir regresyon için.
       **Aynı gün kovadan ÖLÇÜLDÜ:** 82 KB ve 123 KB, ikisi de
       `image/jpeg` — bant tuttu ve mimetype küçültmenin gerçekten
       koştuğunu kanıtlıyor (koşmasaydı orijinal PNG/HEIC türü kalırdı).
       Ayrıntı + Parça 82'nin RLS düzeltmesini de doğrulayan zaman
       damgaları: kök `CLAUDE.md`, "Profil fotoğrafı yükleme".

   - ✅ **Parça 84 — paylaşımda tahta görseli HİÇ gitmiyordu: görselli dal
     web'de her seferinde patlıyor, WhatsApp da linkten sitenin GENEL
     og:image kartını üretiyordu (13 Ağustos 2026, `share_board.dart`):**
     Kullanıcı bölüm 6'yı koşarken iki paylaşımı yan yana koydu —
     *"App'te paylaş board yerine jenerik Kelimeki gösterimini gönderiyor,
     web'de oyunun görselini. App'de web gibi paylaşmalı."*
     - **Web kaynağı önce okundu (kuralın ilk adımı):**
       `GameHistoryModal.tsx` `handleShare` PNG'yi `new File([blob],
       'kelimeki.png')` ile kurup `navigator.canShare({files})` dalından
       paylaşıyor. Yani web GERÇEKTEN dosya paylaşıyor; app'in gönderdiği
       jenerik kart, metin+link yedeğinin (Parça 35) doğal sonucu —
       WhatsApp linke bakıp `index.html`'in site geneli `og:image`'ini
       çiziyor. Yani belirti "yanlış görsel" değil, **görselin HİÇ
       gitmemesi**.
     - **Kök sebep:** portun görselli dalı `path_provider`'ın
       `getTemporaryDirectory()`si + `dart:io` `File` ile geçici dosya
       yazıyordu; ikisi de Flutter web'de çalışmıyor → dal her seferinde
       fırlıyor, `catch` metin yedeğine düşüyordu. Parça 35'te eklenen o
       yedek burada hatayı GİZLEDİ: paylaş sayfası açıldığı için akış
       "çalışıyor" görünüyordu.
     - **Düzeltme:** dosya yazımı bizden kütüphaneye taşındı —
       `XFile.fromData(png, mimeType: 'image/png', name: 'kelimeki.png')`
       + `fileNameOverrides: const ['kelimeki.png']`. Web'de share_plus
       baytları `readAsBytes()` ile alıp `navigator.share({files})`e
       veriyor (web'in AYNI dalı); native'de path boş kaldığından
       share_plus'ın kendisi geçici dizine yazıyor
       (`method_channel_share.dart`, `_getFile` — kaynaktan doğrulandı).
       `fileNameOverrides` ŞART: `cross_file`'ın io uygulaması `name`i YOK
       SAYIYOR (paket belgesinde yazılı), onsuz native'de ad kayboluyor.
       Bu kod yolu artık `path_provider`a hiç dokunmuyor (`dart:io` importu
       da düştü).
     - **`downloadFallbackEnabled: false` (yalnızca web'de anlamlı):**
       varsayılan `true` iken `canShare({files})` false dönerse share_plus
       paylaşmak yerine PNG'yi sessizce İNDİRİYOR; web'in kendi yedeği ise
       metin+link. `false` ile o durumda fırlayıp bizim yedeğimize
       düşüyoruz — zincir web `handleShare` ile hizalandı.
     - **GERÇEK CanvasKit derlemesinde ÖLÇÜLDÜ (Parça 18/27'nin yöntemi;
       tahminle kapatılmadı):** minik bir web harness'i derlenip
       Playwright/Chromium'da koşuldu —
       `getTemporaryDirectory()` **FIRLATTI**, `File(...).writeAsBytes()`
       **"Unsupported operation: _Namespace"** ile fırlattı,
       `XFile.fromData(...)` **ÇALIŞTI** (11 bayt, mime/name korunuyor) ve
       share_plus web eklentisinin `prepareData`'sı **files DOLU** bir
       `ShareData` üretti — yani `navigator.share({files})` dalı artık
       gerçekten besleniyor. Harness ve `build/webprobe` iş bitince
       silindi.
     - **Test — negatif eş doğrulamasıyla:** `share_recent_test.dart`'a
       yeni bir test; path_provider kanalı gerçek bir geçici dizine
       mock'lanıp kanala giden `paths`/`mimeTypes`/`text` ve DİSKTEKİ
       baytlar doğrulanıyor (`.../kelimeki.png`, `image/png`, birebir PNG).
       `fileNameOverrides` kaldırılınca test GERÇEKTEN düştü, geri konunca
       yeşile döndü. Parça 35'in yedek-zincir testi de hâlâ geçiyor
       (artık `MissingPluginException` bizim kodumuzdan değil share_plus'ın
       `_getFile`'ından geliyor — sonuç aynı, zincir sağlam).
     - **`flutter test` bu hatayı YAPISAL OLARAK göremez** (native VM'de
       `dart:io` çalışır, eski kod da testi geçerdi) — bu yüzden kanıt
       tarayıcı ölçümü, testin işi sözleşmeyi (veri destekli XFile + doğru
       ad/tip/bayt) kalıcı olarak pinlemek. Parça 18'in dersinin tekrarı.
     - **`path_provider` pubspec'te KALDI, bilinçli:** artık `lib/` altında
       hiçbir import yok, ama native'de geçici dosyayı yazan share_plus
       onu kullanıyor — yani bağımlılık kayboldu değil, bir katman aşağı
       indi. Sahip olduğumuz bir özelliğin gereksinimini örtük bırakmamak
       için bildirimde tutuldu.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       378/378 yeşil** (377'den +1). `kelimeki_core`'a ve web'e hiç
       dokunulmadı — `mobile/` DIŞINDA dosya değişmedi.
     - **Doğrulama sınırı:** gerçek paylaş sayfasında görselin gerçekten
       eklendiği (ve WhatsApp'ın jenerik kart yerine tahtayı gösterdiği)
       cihazda teyit edilmeli — `mobile/TESTING.md` bölüm 6 güncellendi.

   - ✅ **Parça 85 — aksiyon menüsünden ayrı "Vazgeç" paneli kaldırıldı
     (13 Ağustos 2026, `action_sheet.dart` + web `ActionSheet.tsx`):**
     Kullanıcı kararı — *"Bence kapat ve vazgeç aynı şey. Paylaş ve Kapat
     olsun sadece."*
     - **Önce web kaynağı okundu (kuralın ilk adımı) ve kapsam ölçüldü:**
       "Vazgeç" bir aksiyon DEĞİL, `ActionSheet` bileşeninin kendi ikinci
       paneliydi (iOS aksiyon menüsü geleneği) — çağıranlar yalnızca
       `Paylaş`/`Kapat` geçiyor. İki platformda da **tek kullanım yeri**
       var (`GameHistoryModal`ın tahta önizlemesi), yani paneli bileşenden
       düşürmek başka hiçbir ekranı etkilemiyor.
     - **Kullanıcının önermesi teknik olarak tam doğru değildi ama karar
       yine de sağlam:** "Kapat" tahta önizlemesini de kapatıyor, "Vazgeç"
       yalnızca menüyü kapatıp tahtayı açık bırakıyordu. Bu ayrım
       kullanıcıya hiç görünmüyordu (aynı boy/konumda iki nötr buton),
       nitekim aynı kullanıcı bir tur önce ikisinin de aynı şeyi yaptığını
       bildirmişti — ayrımı korumak için ikinci bir buton taşımak, kazandan
       çok karışıklık üretiyordu.
     - **Aksiyonsuz çıkış yolu KAYBOLMADI** (bu, kaldırmanın ön koşuluydu):
       mobilde `showModalBottomSheet`'in varsayılan `isDismissible`/
       `enableDrag`'i, web'de dış katmanın `onClick={onClose}`'u +
       `useModalA11y`'nin Escape'i. İkisi de `null` döndürdüğünden hiçbir
       `onSelect` çalışmıyor — yani "Vazgeç"in DAVRANIŞI duruyor, yalnızca
       butonu kalktı.
     - **İki platform AYNI PR'da** (dal `main` tabanlı, stranding riski
       yok — bkz. Parça Bitirme Kontrol Listesi madde 1). Tek taraflı
       kaldırmak, bu projenin en sık tekrarlayan hata sınıfını (sessiz
       web↔port ayrışması) yeniden üretirdi.
     - **Layout tuzağı:** kalan tek paneli saran `Column`
       (`crossAxisAlignment: stretch`) SİLİNMEMELİ — `ConstrainedBox`
       gevşek kısıt verdiğinden panel tek başına bırakılsa metin
       genişliğine büzülürdü. Yorumla sabitlendi.
     - **Test — negatif eş doğrulamasıyla:** mevcut menü testinde
       `find.text('Vazgeç')` artık `findsNothing`; ayrıca YENİ bir test
       zemine dokunmanın menüyü aksiyonsuz kapattığını (tahta AÇIK kalıyor,
       `share` çağrılmıyor, `set_game_shared` yazılmıyor) doğruluyor —
       "kullanıcı kapana kısılmadı" iddiasının kanıtı. `isDismissible:
       false` geçici olarak eklenince test GERÇEKTEN düştü
       (`Expected: no matching candidates / Actual: ... "Paylaş"`), geri
       alınınca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       379/379 yeşil** (378'den +1). Web `npm run lint` + `npm run build`
       temiz. `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (`src/components/ActionSheet.tsx`,
       `CLAUDE.md`) → kök `CLAUDE.md` aynı commit'te güncellendi.
     - **Doğrulama sınırı:** cihazda görsel teyit (menünün iki butonlu
       göründüğü + dışarı dokununca aksiyonsuz kapandığı) kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 6 güncellendi.

   - ✅ **Parça 86 — paylaşım iPad'de HİÇ çalışmayacaktı: `sharePositionOrigin`
     üç çağrı yerinin hiçbirinde verilmiyordu (13 Ağustos 2026,
     `share_board.dart`, `game_history_modal.dart`, `setup_screen.dart`,
     `friends_modal.dart`):** Kullanıcının "tüm app geliştirmeleri hem
     Android hem iOS için geçerli değil mi, her şeyi baştan test etmemiz
     gerekmeyecek?" sorusunu cevaplarken bulundu — cevabın canlı örneği
     çıktı.
     - **Kaynaktan doğrulandı, tahmin değil** (`FPPSharePlusPlugin.m`,
       satır 418-443): iPad'de paylaş sayfası bir POPOVER ve iOS ankraj
       istiyor. Eklenti bunu SERT bir koşul olarak uyguluyor —
       `isIpad && (origin kök view'ın dışında || CGRectIsEmpty(origin))`
       ise paylaşmak yerine **`FlutterError` DÖNDÜRÜYOR**. Dart tarafında
       bu `PlatformException`; bizim `catch`imiz onu yutuyor, metin
       yedeğine düşüyor, o da AYNI sebeple patlıyor → ikinci `catch` →
       kullanıcıya **hiçbir şey olmuyor**. iPhone ve Android'de parametre
       yok sayılıyor (`Parameter ignored on other platforms`).
     - **Neden bugüne kadar görünmedi — ve dersin özeti bu:** kullanıcı
       cihaz testini GitHub Pages web derlemesinde yapıyor; orada
       share_plus'ın WEB eklentisi çalışıyor (`navigator.share`), iOS
       kanalına hiç uğranmıyor. FAZ B (gerçek cihaz) henüz koşulmadı.
       Yani bu, "aynı Dart kodu iki platformda da aynı çalışır"
       varsayımının kırıldığı yer: kod TAMAMEN paylaşımlı, kıran şey
       platform kanalının kendi sözleşmesi.
     - **ÜÇ çağrı yerinin ÜÇÜ de kırıktı** (yalnızca bugün eklenen görsel
       paylaşımı değil): `game_history_modal` (tahta paylaşımı),
       `setup_screen` ("Arkadaşınla paylaş"), `friends_modal` (davet
       linki — orası `SharePlus.instance`'ı doğrudan çağırıyor). Bir
       hatayı bulduğunda ÜRETEN mekanizmanın diğer örneklerini de ara
       (Parça 54'ün dersi) — tek çağrı yerini düzeltmek ötekileri sessizce
       kırık bırakırdı.
     - **Ortak `shareOriginFrom(BuildContext)`** (`share_board.dart`):
       widget'ın kendi `RenderBox`'ından global dikdörtgeni alıp EKRANLA
       KESİŞTİRİYOR — iOS ankrajın kök view'ın İÇİNDE olmasını da şart
       koşuyor, kaydırma yüzünden kısmen dışarı taşan bir kutu yine hataya
       düşerdi. Kutu yoksa/boşsa ekran ortasında 1×1'lik bir yedek (boş
       OLMAMASI şart, `CGRectIsEmpty`).
     - **`origin` parametresi BİLEREK ZORUNLU** (`ShareBoardFn` typedef'inde
       `required Rect?`): opsiyonel olsaydı yeni bir çağrı yeri onu sessizce
       atlar ve paylaşım yalnızca iPad'de, yalnızca gerçek cihazda ölürdü.
       Nitekim `flutter analyze` değişiklikten hemen sonra 4 hatayla üç
       çağrı yerini + iki test sahtesini işaret etti — derleyicinin
       yakalayabileceği bir şeyi çalışma anına bırakmamak tam olarak bu.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI katman:** (a) çağıran
       katman — `_ShareCall` artık `origin`i de kaydediyor, ankrajın boş
       OLMADIĞI ve ekranın İÇİNDE kaldığı doğrulanıyor; (b) kanal katmanı —
       mock'lanan `dev.fluttercommunity.plus/share` çağrısında
       `originX/Y/Width/Height` alanları bekleniyor. **İlk denemede
       yalnızca (a) yazılmıştı ve YETERSİZDİ:** o test enjekte edilen sahte
       `share`i ölçtüğünden `shareBoard`ın `ShareParams`e iletip
       iletmediğini göremiyordu — `sharePositionOrigin` satırı silinince
       test GEÇMEYE devam etti. (b) eklenince aynı silme GERÇEKTEN düştü
       (`Expected: <10.0> / Actual: <null>`). **Ders: bir sözleşmeyi
       enjekte edilebilir bir sınırın ÜSTÜNDE test etmek, o sınırın
       ALTINDAKİ iletimi kanıtlamaz** — hangi katmanı ölçtüğünü sor.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       379/379 yeşil** (yeni test yok, mevcut ikisine assertion eklendi).
       `kelimeki_core`'a ve web'e hiç dokunulmadı.
     - **Doğrulama sınırı — bu ortamda KANITLANAMAZ:** gerçek bir iPad
       gerekiyor. Kanıt zinciri kaynak okuması + kanal seviyesinde test;
       gerçek popover FAZ B'de doğrulanmalı. `mobile/TESTING.md` bölüm 6
       ve FAZ B'ye maddeler eklendi.

   - ✅ **Parça 87 — üç sessiz hata: HEIC avatar reddi, yutulan galeri
     izni hatası, kaybolan soğuk-başlangıç davet linki (13 Ağustos 2026,
     `avatar_picker.dart`, `auth_service.dart`, `account_settings_modal.dart`,
     `friend_invite_inbox.dart`, `setup_screen.dart`):** Üçü de "hiçbir şey
     olmuyor" sınıfından — kullanıcıya hata bile göstermeden başarısız
     oluyorlardı. Üçü de kaynak koddan ölçülerek doğrulandı.
     - **(a) HEIC seçen Android kullanıcısı avatarını YÜKLEYEMİYORDU — ve
       sebep "HEIC" DEĞİLDİ.** İlk teşhis "Android'de HEIC baytları
       geliyor, MIME haritasında yok" idi; `image_picker`ın Android
       kaynağı okununca ÇÜRÜDÜ: `ImageResizer.java`'nın `shouldScale`ı
       `maxWidth != null || maxHeight != null || imageQuality < 100` —
       bizim 512/512/85 parametrelerimizle HER ZAMAN true, yani görsel
       JPEG'e yeniden kodlanıyor (`saveAsPNG = bitmap.hasAlpha()`, aksi
       hâlde JPEG). **Ama çıktı `createImageOnExternalDirectory("/scaled_"
       + outputImageName, ...)` ile yazılıyor — UZANTI KORUNUYOR.** Yani
       dosya `scaled_IMG_x.heic`, içi JPEG; `XFile.mimeType` de o
       platformda null. Uzantıya bakan eski kod `application/octet-stream`
       üretip `uploadAvatar`ın `image/*` kontrolüne takılıyordu: **geçerli
       bir JPEG, yalan söyleyen bir uzantı yüzünden reddediliyordu.**
       - **Düzeltme uzantı haritasını genişletmek DEĞİL, baytları okumak:**
         yeni `sniffImageMime` (JPEG/PNG/GIF/WebP/BMP + ISO-BMFF `ftyp`
         markası) ve öncelik sırasını sabitleyen `resolveAvatarMime`
         (baytlar → platformun bildirdiği tip → uzantı). Baytlar asla yalan
         söylemez ve sunucuya giden şey de zaten onlar.
       - **HEIC düz bir imzayla YAKALANAMAZ** — ilk baytı `0x00`; `ftyp`
         offset 4'te, marka 8-12'de. Bu yüzden sniff'te ayrı bir dal var.
       - **iOS'ta sorun yoktu ve bu da ölçüldü:**
         `FLTImagePickerMetaDataUtil.getImageMIMETypeFromImageData`
         yalnızca İLK baytı kokluyor (JPEG/PNG/GIF); HEIC `0x00` ile
         başladığından `MIMETypeOther` → suffix nil → `kFLTImagePickerDefaultSuffix
         = @".jpg"`. Flutter web'de ise `maxWidth/maxHeight/imageQuality`
         sessizce yok sayılıyor (Parça 83'te belgeliydi), yani baytlar
         GERÇEKTEN HEIC olabiliyor — sniff üç platformda da doğru cevabı
         verdiği için ayrı dal gerekmedi.
       - `auth_service.dart`'ın `_extByMime`ine heic/heif/bmp eklendi ki
         storage yolu (`<uid>/avatar.<ext>`) yanlış adlandırılmasın.
       - **`resolveAvatarMime` AYRI ve saf bir fonksiyon, çünkü test
         edilecek sözleşme SIRA:** `pickAvatarImage` platform kanalına
         bağlı, widget testinde çalışmaz — Parça 86'nın dersi (bir
         sözleşmeyi enjekte edilebilir sınırın ÜSTÜNDE test etmek, altındaki
         iletimi kanıtlamaz) burada baştan uygulandı.
     - **(b) Galeri izni reddedilince EKRANDA HİÇBİR ŞEY olmuyordu.**
       `pickAvatar`/`shrinkAvatar` çağrıları `try`ın DIŞINDAYDI; izin
       reddinde `image_picker`ın fırlattığı `PlatformException` en yakın
       `catch`e hiç uğramadan akışı kesiyor, `_uploadingAvatar` bile
       kurulmadığından tek bir piksel değişmiyordu. İkisi de `try` içine
       alındı; Türkçe, eyleme dönük bir hata gösteriliyor ("Fotoğraf
       seçilemedi. Galeri izni verildiğinden emin ol.") — Parça 45'in
       "sessiz yutma yok" dersinin aynı sınıfı.
     - **(c) Uygulama KAPALIYKEN dokunulan davet linki SESSİZCE
       kayboluyordu.** `friend_invite_inbox.dart`'ın eski başlığı "cold
       start'ta ilk URI da bu akışa dahil" diyordu — YANLIŞTI ve mekanizma
       kaynaktan okunarak doğrulandı: `AppLinks` Dart tarafında bir
       SINGLETON ve tek bir `StreamController.broadcast()` üzerinden
       çoğullama yapıyor; native taraf (`AppLinksIosPlugin.swift:107`,
       `AppLinksPlugin.java:133`) soğuk başlangıç linkini `initialLinkSent`
       bayrağıyla YALNIZCA İLK `onListen`da bir kez akışa basıyor.
       **Broadcast akışları geç abone olana geçmiş olayları TEKRARLAMAZ.**
       `bootstrap()`ta bu inbox `await initSupabase()` VE
       `await checkVersionGate(supabase)` (gerçek bir ağ çağrısı, 5 sn'ye
       kadar) tamamlandıktan SONRA kuruluyor; supabase_flutter ise
       `Supabase.initialize` içinde (`detectSessionInUri` varsayılan true)
       `uriLinkStream`e ondan ÖNCE abone oluyor — yani ilk dinleyici o,
       bayrağı o tüketiyor.
       - **Kurtarma yolu `getInitialLink()`:** native tarafta düz bir
         method-channel okuması (`case "getInitialLink": result(initialLink)`),
         `initialLinkSent` bayrağını TÜKETMİYOR — supabase'in auth akışını
         bozmadan aynı URI'yi bir kez daha okuyabiliyoruz. Hata yutuluyor
         ve loglanıyor: bir davet linki uygulamanın açılışını bloke edemez.
       - **Mükerrer kayıt riski gerçek ve kapatıldı:** aynı link hem sıcak
         akıştan hem kurtarmadan düşebiliyor ve `PendingEventStore.add`
         düz bir insert — dedup'ı YOK. Yeni saf `inviteTokensFromEvents`
         bir `takeAll` PARTİSİNDEKİ mükerrerleri (ve bozuk kayıtları)
         eliyor. Dedup **parti bazında**: kalıcı bir "görüldü" listesi
         TUTULMUYOR, yani bir sonraki oturumda aynı davet linkine yeniden
         dokunmak hâlâ çalışıyor.
       - **Widget testi DENENDİ ve TERK EDİLDİ:** `SetupScreen`
         `pumpAndSettle`ı asıyor (canlı rozet/senkron zamanlayıcıları —
         Parça 8'in aynı tuzağı); sınırlı `pump` döngüleri de kurtarmadı,
         test 400 sn zaman aşımına düştü. Bu yüzden karar saf bir fonksiyona
         çıkarılıp ORADA test edildi — gerekçe fonksiyonun kendi doc
         yorumunda da yazılı.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** (a) için
       `account_settings_test.dart`'a 5 test (bayt önceliği, HEIC `ftyp`
       markası, yedek zinciri, picker fırlatması, shrink fırlatması);
       `resolveAvatarMime`den sniff çağrısı çıkarılınca 2 test GERÇEKTEN
       düştü (`Expected: 'image/heic' / Actual: 'application/octet-stream'`).
       (b) için modaldeki `try/catch` geri alınınca iki test de GERÇEKTEN
       düştü (`Found 0 widgets with text containing Fotoğraf seçilemedi`).
       (c) için `friends_test.dart`'a saf bir dedup testi.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       385/385 yeşil** (379'dan +6). `kelimeki_core`'a ve web'e hiç
       dokunulmadı — `mobile/` DIŞINDA dosya değişmedi.
     - **Doğrulama sınırı:** üçü de gerçek cihaz istiyor — Android'de
       HEIC seçimi, izin reddi diyaloğu ve `kelimeki://davet/<token>`
       soğuk başlangıcı (custom şema yalnızca KURULU bir uygulamada
       yakalanır, web derlemesinde test EDİLEMEZ — Parça 28'in aynı
       sınırı). `mobile/TESTING.md` bölüm 10/12 ve FAZ B'ye maddeler
       eklendi.
     - **Ders — "web'de de böyle" bir savunma DEĞİL, ama "web'de yok" da
       bir gerekçe değil:** (a) ve (b) web'de yaşanmıyor (tarayıcının
       dosya seçicisi MIME'i doğru bildiriyor, izin diyaloğu yok), (c)
       ise web'de kavram olarak yok (deep link yerine gerçek bir sayfa
       var). Üçü de porta ÖZGÜ, platform kanallarının kendi
       sözleşmelerinden doğuyor — Parça 86'nın `sharePositionOrigin`
       bulgusuyla aynı aile. **Kaynak koda inmeden hiçbiri bulunamazdı;**
       üçünde de belirti aynıydı: "hiçbir şey olmuyor".

   - ✅ **Parça 88 — kardeş-ekran denetimi: üç sapma, biri motorun kendi
     mesajını ulaşılamaz kılıyordu (13 Ağustos 2026, `game_screen.dart`,
     `online_game_screen.dart`):** `game_screen.dart` ↔ `online_game_screen.dart`
     çifti "Etki Analizi"nin değişmezi gereği elle senkron tutuluyor ve
     hiçbir derleyici/test bunu yakalamıyor — planlı bir denetimle üç fark
     bulundu. **Üçü de web kaynağından TEK TEK doğrulandı**, denetim
     raporuna güvenilmedi.
     - **(a) Boş taslakta OYNA/GERİ AL devre dışıydı; web'de değil.**
       Web: `disabled={!canAct || validating || !wordsReady}` (App.tsx:1450)
       ve `disabled={!canAct}` (1501) — `placed.isEmpty` koşulu YOK. Port
       DÖRT yerde birden (iki ekran × iki buton) bu koşulu taşıyordu, artı
       `online_game_screen.dart:700`'de mesajı yutan bir iç guard.
       - **Asıl mesele kozmetik değil:** motor bu durum için ÖZEL bir
         mesaj taşıyor — `validator.dart:57` / `validator.ts:62`,
         **"Harf yerleştirilmedi."** Butonu kapatmak o mesajı ULAŞILAMAZ
         kılıyordu; kullanıcı gri bir butonla kalıyor ve sebebini hiçbir
         yerde okuyamıyordu. Bu, Parça 87'de düzeltilen üç hatanın aynı
         sınıfı: sessiz ret.
       - **Web'in KENDİ yazılı gerekçesi de bu yönde:** `OnlineGameScreen.tsx:705-714`
         (3 Ağustos 2026) *"kullanıcıyı PASİF bir butona basmaya çağıran,
         sebebi hiçbir yerde yazmayan çelişkili bir ekrandı — özelliği
         yazan kişiyi bile yanılttı"* diyor. Karar bu yüzden "web'e
         hizala" oldu; portun davranışını bilinçli bir sapma olarak
         kaydetmek, motorun taşıdığı mesajı kalıcı olarak ölü kod
         yapardı.
     - **(b) Canlı "Sıra: X" bandı YANLIŞ kırmızıyı kullanıyordu ve kendi
       içinde tutarsızdı.** Zemin/çerçeve `#E0483A` (`kMoveInvalid` —
       TAHTAYA özel kırmızı) üzerine kuruluydu, **ama yorumu doğru şekilde
       "web bg-red/10" diyordu**; aynı bandın nabız noktası ve metni ise
       ZATEN `kRed` (`#DC2626`) kullanıyordu. Yani tek bir bantta iki
       kırmızı vardı. Parça 54'ün ("her dosyada yerel palet kopyası")
       taraması bunu göremiyor, çünkü değerler alfa türevi
       (`0x1A…`/`0x66…`), `Color(0xFF…)` değil. Ayrıca `shadow-raised`
       hiç yoktu ve dolgu 12/10 idi (web `px-4 py-3` = 16/12). Üçü de
       düzeltildi; renkler artık `_red.withValues(alpha: 0.1/0.4)` —
       `move_history_modal.dart:319`'un zaten kullandığı deyim, yani
       token ilişkisi kodda görünür.
     - **(c) "Tekrar Oyna" hata dalının butonu "TAMAM" diyordu, web
       "Kapat".** Web'de bunlar İKİ AYRI dal (`sent` → "Tamam", `error` →
       "Kapat"); port ikisini tek diyalogda birleştirdiğinden etiket artık
       içeriğe göre seçiliyor.
     - **Test — negatif eş doğrulamasıyla, DÖRT ayrı kanıt:** iki lib
       dosyası birlikte `git stash`lenip testler koşuldu; dördü de
       GERÇEKTEN düştü — yerel A2 ve Canlı A2 `Expected: not null /
       Actual: <null>` (buton kapalı), A3 `Found 1 widget with text
       "TAMAM"`, A1 dekorasyon tipi tutmadığından. Geri konunca yeşile
       döndü.
     - **Test yazarken düşülen tuzak (kayda geçsin):** yeni testin
       `expect(controller.state.turnCount, 0)` iddiası düştü — `craftedState()`
       sıfırdan başlamıyor (turnCount 2). Kodda değil TESTTE hata vardı;
       "hamle işlenmemeli" iddiası mutlak bir sayıya değil ÖNCEKİ değere
       bağlanmalıydı. Bir fikstürün başlangıç durumunu varsaymadan önce
       oku.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       388/388 yeşil** (385'ten +3; A3 mevcut testin güncellenmesi olduğu
       için ayrı test SAYILMIYOR). `kelimeki_core`'a ve web'e hiç
       dokunulmadı — `mobile/` DIŞINDA dosya değişmedi.
     - **Doğrulama sınırı:** bandın görsel teyidi (yeni kırmızı + gölge +
       dolgu) cihazda bekleniyor — `mobile/TESTING.md` bölüm 11'e madde
       eklendi.
     - **Denetimin "belirsiz" bulguları BİLİNÇLİ olarak kapsam dışı:**
       30px sabit mesaj satırı, "Kalan Taşlar"ın `myIndex`i, yeni-mesaj
       popup'ının biçimi ve rematch'in "Gönderiliyor…" durumu — dördü de
       web'e karşı ölçülmeden "sapma" sayılamaz, ayrı bir tur istiyorlar.
       Bir bulguyu doğrulamadan düzeltmek bu projede daha önce iki kez
       geri alındı (Parça 16→17, 39→40).

   - ✅ **Parça 89 — beş paralel denetimin bulguları: bir VERİ KAYBI yolu, üç
     SAHTE BAŞARI mesajı (13 Ağustos 2026, `setup_screen.dart`,
     `friends_modal.dart`):** Kullanıcı isteğiyle beş salt-analiz denetimi
     koşuldu (Türkçe metin paritesi, elle senkron kopyalar, sessiz hata
     yutma, test kalitesi, sunucu yetkileri). **Raporlar körlemesine
     UYGULANMADI** — her bulgu kaynaktan tek tek doğrulandı; aşağıdakiler
     doğrulananlar.
     - **(a) VERİ KAYBI — `_resumeSavedGame` terk olaylarını tüketip
       çöpe atıyordu.** `drainAbandonedGames()` `PendingEventStore.takeAll`
       kullanıyor = **atomik SELECT+DELETE**, yani dönüş değerini atmak
       olayları KALICI olarak siler. `_resumeSavedGame`'in `state == null`
       dalı ("tam bu anda süresi doldu") bunu çıplak çağırıp sonucu hiç
       okumuyordu; oysa olayları -2 cezalı `games` kaydına çeviren tek
       tüketici `_sweepLocalAbandoned`.
       - **Tetikleyici somut:** misafir Setup'ta "Devam Eden Oyun" satırı
         dururken 7 günlük süre dolar, "Devam Et"e dokunur → kayıt olaya
         çevrilir → bu dal olayı yutar. Terk edilen oyunun tam `GameState`'i
         ve -2 cezası bir daha üretilemez (bir sonraki açılışta süpürme
         hiçbir şey bulamaz).
       - Düzeltme tek satır: `_sweepLocalAbandoned()` çağır.
       - **Aynı fonksiyonda ikinci, daha dar bir sıralama hatası:**
         `_sweepLocalAbandoned` ÖNCE drain edip SONRA `games == null` diye
         dönüyordu — o dalda da olaylar kaybolurdu. `games` artık drain'den
         ÖNCE çözülüyor. **Kural: yıkıcı bir okuma (`takeAll`) yapmadan
         önce sonucu tüketecek her şeyin hazır olduğundan emin ol.**
     - **(b) SAHTE BAŞARI — `FriendsModal` ağ hatasında gerçekleşmemiş
       sonuçlar bildiriyordu.** Üç akış: `_handleRespond` hatayı tamamen
       yutup `void` döndüğünden "Arkadaş oldunuz." ve "İstek reddedildi."
       KOŞULSUZ gösteriliyordu; `_handleSend` hatada `null` dönüyor ve
       `null != accepted` olduğundan "Arkadaşlık isteğiniz iletilmiştir."
       çıkıyordu — istek hiç gitmemişken.
       - **Sessiz retten DAHA KÖTÜ:** kullanıcı yanlış bilgilendiriliyor,
         üstelik liste tazelenmediğinden ekran mesajla çelişiyor (reddedilen
         istek yerinde duruyor).
       - `_handleRespond` artık `bool` dönüyor; üç çağrı yeri de sonucu
         kontrol ediyor. Hata metni İCAT EDİLMEDİ — `chat_settings_modal`'ın
         zaten kullandığı `'İşlem başarısız oldu.'` paylaşıldı.
       - **Aynı dosyadaki `_confirmThenRemoveCandidate`/`_confirmThenCancel`
         baştan DOĞRUYDU** (başarı diyaloğunu `try` İÇİNDE gösteriyorlar) —
         yani bu bir desen hatası değil, iki akışın o desenden sapmasıydı.
     - **Test — negatif eş doğrulamasıyla:** `friends_test.dart`'a ağ
       hatasında reddetmenin "İstek reddedildi." DEĞİL "İşlem başarısız
       oldu." dediğini doğrulayan test. `friends_modal.dart` `git stash`
       lenince GERÇEKTEN düştü (`Found 1 widget with text "İstek
       reddedildi."` — kullanıcının göreceği sahte başarının ta kendisi).
     - **Test tuzağı (kayda geçsin):** satır butonu ve onay diyaloğunun
       kabul butonu ikisi de `trUpper`dan geçiyor → finder `'Reddet'` değil
       **`'REDDET'`** olmalı. Ayrıca `pumpModal` `FriendsModal` GRUBUNUN
       içinde tanımlı; testi başka bir gruba eklemek "Method not found"
       verir.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       389/389 yeşil** (388'den +1). `kelimeki_core`'a dokunulmadı.
     - **AÇIK BOŞLUK — (a) için test YOK:** düzeltme kaynaktan kanıtlandı
       (takeAll yıkıcı + tek meşru tüketici `_sweepLocalAbandoned`) ama
       widget seviyesinde tekrarlanabilir bir kurulum (loadSave null DÖNERKEN
       kuyrukta olay olması) yazılmadı. `mobile/TESTING.md` bölüm 1'e elle
       kontrol maddesi eklendi; kalıcı test hâlâ borç.
     - **Denetimlerin diğer bulguları — durum:**
       - **Elle senkron kopyalar: TEMİZ.** Rütbe/ödül üç kopya (SQL↔TS↔Dart)
         birebir, ödül=eşik/10 dokuz kademede de tutuyor, kümülatif toplamlar
         pairwise farklı; üretilmiş dosyalar bayat değil (motor dosyaları
         golden'lardan sonra DEĞİŞMEMİŞ); RankSeal geometrisi ve renk paleti
         senkron. Çıkan üç bayat YORUM ayrı bir commit'te düzeltildi.
         **Denetimin "kör nokta" dediği `tile-border` (#C7D0DC) DÜZELTİLDİ:**
         token `src/`'de de hiç kullanılmıyor, yani iki tarafta da ölü —
         izlenmemesi bir eksiklik değil.
       - **Sunucu: bir uykuda hata bulundu** (`withdraw_online_game_chat_reports`
         overload'ı) — Parça 90'da düzeltildi.
       - **Test kalitesi:** en güçlü bulgu `OnlineApi.submitMove`'un
         retry/idempotency döngüsünün SIFIR test kapsamı olması — Parça
         90'da kapatıldı.
       - **Türkçe metin paritesi:** denetim İKİ kez oturum limitine takıldı,
         sonuç ALINAMADI — Parça 90'da elle koşuldu ve gerçek bir bulgu
         çıkardı (Gizlilik Politikası bayattı).

   - ✅ **Parça 90 — Parça 89'un üç açık maddesi kapandı; hukuki metin
     denetimi bir GİZLİLİK YALANI buldu (14 Ağustos 2026,
     `fix_withdraw_report_wrong_overload` migration'ı, `online_api.dart`,
     `legal_modals.dart`, `live_games_tab.dart`, `games_api.dart`,
     `game_history_modal.dart`, `recent_games_section.dart`):** Parça 89
     üç işi "sonraya" bırakmıştı (uykudaki sunucu hatası, `OnlineApi`'nin
     sıfır testi, tamamlanamayan Türkçe metin denetimi); üçü de bu parçada
     kapandı ve sonuncusu beklenenden ağır bir bulgu çıkardı.
     - **(a) Sunucu — `withdraw_online_game_chat_reports`'un YANLIŞ
       overload'ı düzeltilmişti (uygulandı, kanıtlandı).** 4 Ağustos'taki
       "geri çekme `handled`'a dokunmasın" düzeltmesi, bir gün önce DROP
       edilmiş 2-arg imzayı `create or replace` ile yeniden yaratıp ona
       uygulanmıştı; istemcilerin çağırdığı 1-arg sürüm hâlâ
       `handled = true` yapıyordu. **Bozulmuş veri YOKTU** (son geri çekme
       04.08 10:49, migration 10:54 — o tarihten beri hiç geri çekme
       olmamış), yani hata gerçekti ama uykudaydı. Migration 1-arg sürümü
       düzeltip hortlak overload'ı düşürdü (o overload ayrıca
       `SECURITY DEFINER` + EXECUTE'u PUBLIC'te — "yeni fonksiyonda önce
       revoke all" kuralına aykırı bir kalıntı).
       **Canlıda geri alınan bir transaction'la DAVRANIŞ testi yapıldı**
       (varlık kontrolü değil): gerçek bir satır (`83535bba…`)
       `handled=false`a çekilip RPC gerçek raporlayanın kimliğiyle
       çağrıldı → `withdrawn_at` doldu, `handled` **`false` KALDI**;
       `rollback` sonrası satırın eski hâline (`handled=true`,
       `withdrawn_at=null`) döndüğü ayrıca sorgulandı.
     - **(b) `OnlineApi.submitMove` artık testli** — mobilin ASIL
       güvenilirlik özelliği (aynı `p_move_id` ile retry) sıfır kapsamdaydı.
       `OnlineApi.withRpc` test dikişi (`SubmitMoveRpc` typedef'i) +
       `test/online_api_test.dart` (4 test): aynı id ile yeniden deneme,
       `PostgrestException`'da tek çağrı + rethrow, `maxAttempts` tükenince
       hatanın yüzeye çıkması, açık `moveId`. **Negatif eş, İKİ AYRI
       kanıt:** `final id = moveId ?? uuidV4()` döngünün İÇİNE taşınınca
       idempotensi testi GERÇEKTEN düştü (`Expected: '31769d3e…' Actual:
       '43a67f74…'`); `PostgrestException` rethrow'u kaldırılınca çağrı
       sayısı testi düştü (`Expected: <1> Actual: <3>`). Parça 86'nın
       dersinin doğrudan uygulaması: ekranın 15 testi `FakeOnlineGamesGateway`
       sınırının ÜSTÜNDE ölçüyor, döngü o sınırın ALTINDA.
     - **(c) Türkçe metin denetimi — port, kullanıcıya kendi verisi
       hakkında GERÇEK OLMAYAN bir şey söylüyordu.** `legal_modals.dart`ın
       başlığı "METİNLER WEB'DEN BİREBİR KOPYALANMIŞTIR … web metni
       değişirse buraya da aynen taşınmalı" diyordu ama bunu ZORLAYAN
       hiçbir şey yoktu ve gerçekten kaçtı: 10 Ağustos'ta
       `game_chat_archive_participants_only` (Parça 51) sohbet arşivini
       katılımcı+admin'e kilitledi, web'in Gizlilik Politikası düzeltildi,
       port ESKİ cümleyi ("mevcut skor/tahta görünürlüğüyle aynı şekilde
       tüm kayıtlı kullanıcılara açıktır") taşımaya devam etti. Metin
       web'in bugünkü hâline çekildi, "Son güncelleme" 2 → 10 Ağustos.
       - **`test/legal_text_test.dart` bunu KALICI olarak zorluyor** —
         `color_tokens_test.dart`ın tailwind'i okuyan deseninin hukuki
         metin karşılığı: web'in `TermsModal.tsx`/`PrivacyModal.tsx`
         dosyalarını OKUYUP kendi "Son güncelleme" tarihlerini portunkiyle
         karşılaştırıyor (tam metin karşılaştırması satır kaydırma/kaçış
         farklarıyla kırılgan olurdu; tarih, projenin yerleşik disiplini
         gereği her metin değişikliğinde güncelleniyor, yani "port bayat
         mı?" sorusunun güvenilir vekili). Üçüncü test, tarihten bağımsız
         olarak eski/yanlış cümlenin geri gelmediğini de sabitliyor.
         **Negatif eş:** metin eski hâline döndürülünce 3 testin 2'si
         GERÇEKTEN düştü.
     - **(d) Aynı denetimde bulunan iki SESSİZ HATA daha (Parça 89'un
       "sahte başarı" sınıfının kardeşleri):**
       1. **Canlı davet yanıtı ağ hatasında hiçbir şey söylemiyordu**
          (`live_games_tab.dart`) — `_handleRespond`'ın `catch`i yalnızca
          logluyordu; kullanıcı Kabul Et/Reddet'e basıyor, kart yerinde
          duruyor, ekranda hiçbir açıklama yok. Parça 89'un
          `FriendsModal` için açtığı `kFriendActionFailed` sabiti
          paylaşıldı (yeni metin icat edilmedi).
       2. **Oyun geçmişi ağ hatasını "hiç oyunun yok" diye gösteriyordu**
          — `GamesRepo.history` boş liste dönüp hatayı yutuyordu, iki
          tüketici de (`GameHistoryModal`, `RecentGamesSection`) bunu
          "Henüz kayıtlı bir oyunun yok." / "Henüz bitmiş bir Yapay Zeka
          oyunun yok." diye çiziyordu. **Çevrimdışı bir kullanıcıya bu,
          oyunlarının silindiğini düşündürür.** Dönüş kaydına `failed`
          eklendi (`moves`un `ok`/`boardSnapshot`un null ayrımıyla aynı
          gerekçe — "veri yok" ile "ulaşamadım" AYRI şeyler) ve iki ekran
          da artık "Oyun geçmişi yüklenemedi. Bağlantını kontrol edip
          tekrar dene." diyor. `RecentGamesSection` ayrıca başarısız
          çekimle önbelleği EZMİYOR — önceki mount'un listesi çevrimdışı
          gösterilmeye devam edebilsin.
       - **`GameHistoryModal`'da bayrak İKİ yükleme yolunda da set
         ediliyor** (`_loadInitial` + `_loadPage`): ikincisi sekme
         değişiminin de (offset 0) yolu, orada bir hata "favori
         işaretlediğin oyun yok" diye görünürdü.
       - **`FakeGamesGateway`e `failList` eklendi** — Parça 46'nın dersi:
         sahtenin taklit etmediği bir hata yolu, o yol hakkındaki testleri
         sessizce anlamsız kılar; bu hata tam da bu yüzden 398 test
         yeşilken görünmezdi. **Negatif eş:** iki ekranın dalları
         kapatılınca yeni iki test de GERÇEKTEN düştü (`Found 0 widgets
         with text containing yüklenemedi`).
       - **AYNI GÜN web'e de taşındı (aynı PR):** `fetchMyGames` de artık
         `failed` döndürüyor, `GameHistoryModal`/`RecentGamesSection` aynı
         mesajı gösteriyor. İlk sürümde yalnızca mobil düzeltilip web kök
         `CLAUDE.md`'nin bekleme listesine yazılmıştı; kullanıcı "onu da
         kapat" deyince aynı dalda bitirildi (dal `main` tabanlı ve zaten
         web dosyaları içeriyor — ikinci bir dal açmak Kontrol Listesi
         madde 1'in "teslim et" amacına hizmet etmezdi). Web'de birim test
         çatısı olmadığından oradaki kanıt farklı: `tsc` sözleşmeyi
         GERÇEKTEN zorluyor (bir return sitesinden `failed` düşürülünce
         `TS2741` ile kırıldı — negatif eş), mesaj üretim paketinde iki
         çağrı yerinde de var, duman testleri geçiyor; davranışın gözle
         teyidi `TESTING.md` bölüm 9.6'da.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       398/398 yeşil** (389'dan +9). `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (`supabase/migrations/`) → kök
       `CLAUDE.md` aynı commit'te güncellendi (Kontrol Listesi madde 1).
     - **Doğrulama sınırı:** ~~(a) gerçek istemciyle uçtan uca (bir şikayeti
       geri çekip admin panelinde hâlâ "Yeni" göründüğünü doğrulamak)
       cihazda/web'de teyit edilmeli~~ — **14 Ağustos 2026'da KAPANDI:**
       kullanıcı gerçek hesapla geri çekti, `handled` `false` kaldı, kart
       admin panelinde "Yeni" görünüp sayaca dahil oldu, sonra elle okundu
       işaretlendi. Ayrıntı + çıkarımın nasıl elemeyle yapıldığı: kök
       `CLAUDE.md`, aynı maddenin sonu. (b) `OnlineApi` testleri sahte bir
       RPC ile ölçüyor, gerçek PostgREST retry'ı hâlâ Faz 6'nın (çok
       kullanıcılı harness) işi; (d.2) gerçek ağ kesintisiyle "yüklenemedi"
       mesajının göründüğü cihazda doğrulanmalı — `mobile/TESTING.md`
       bölüm 5/11'e maddeler eklendi.
     - **Ders — bir dosyanın BAŞLIĞINDAKİ "birebir kopyalanmıştır" notu bir
       garanti DEĞİL, bir niyet beyanıdır.** Bu proje aynı sınıfı renkler
       (Parça 54 → `color_tokens_test`) ve tipografi (Parça 78 →
       `theme_test`) için zaten testle bağlamıştı; hukuki metin en uzun
       süre bağlanmadan kalan ve yanlış olduğunda BEDELİ EN AĞIR olan
       kopyaydı — kullanıcıya kendi verisinin görünürlüğü hakkında yanlış
       bilgi veriyordu. Yeni bir "elle senkron" kopya açarken sor: bunu
       hangi test zorluyor?

   - ✅ **Parça 91 — şikayeti geri çekmenin TEK yolu, raporladığın kişiyle
     YENİ bir oyun açmaktı (14 Ağustos 2026, yeni
     `ui/friends/friend_moderation_sheet.dart`, `chat_api.dart`,
     `friends_modal.dart` + web `FriendModerationModal.tsx`):** Kullanıcı
     bölüm 10'u koşarken duvara çarptı ve çözümü kendisi tarif etti:
     *"arkadaşlar listesinde o kişinin satırında arkadaşlıktan çıkart
     işaretinin soluna bayrak/Sessiz ikonu koymak ve tıklandığında
     settings'i açmak."*
     - **Kök sebep bir kod hatası DEĞİL, bir erişim boşluğu:** sessize
       alma/şikayet 3 Ağustos'tan beri KİŞİ bazlı (oyunlar arası taşınıyor)
       ama geri almanın giriş noktası hâlâ **AKTİF** bir oyunun sohbet
       ayarlarıydı (`ChatSettingsModal`, dişli). Oyun bitince
       `LiveGamesTab` onu listelemiyor, arşiv (`GameChatHistoryModal`)
       bilerek salt-görsel — yani durum kalıcı, kontrolü ulaşılamaz.
       **Kalıcı bir durumu geri almanın yolu, o durumun oluştuğu geçici
       bağlama bağlıysa er ya da geç kapanır** — kişi bazlı yapılırken
       kontrol de kişi bazlı bir yere taşınmalıydı.
     - **KAPSAM bilinçli olarak yalnızca GERİ ALMA.** Yeni şikayet burada
       YOK: bir şikayet hakkında olduğu KONUŞMAYA bağlı
       (`online_game_chat_reports.online_game_id`) ve admin panelindeki
       "Sohbeti Görüntüle" o dökümü açıyor — arkadaş listesinden açılan
       bir şikayet zorunlu olarak ESKİ bir oyuna iliştirilir ve admin
       ilgisiz bir yazışma okurdu. Bu yüzden ikon da yalnızca durum
       VARKEN çiziliyor: bu bir kısayol, moderasyon menüsü değil.
     - **Sunucuda DEĞİŞİKLİK YOK — ama sessizden çıkarma OYUN İD'Sİ
       İSTİYOR ve bu kaynaktan okunarak bulundu:**
       `mute_online_game_participant` katılımcılık kontrolünü `p_muted`
       dalından ÖNCE yapıyor, yani MUTE'u KALDIRMAK bile geçerli bir ortak
       oyun id'si gerektiriyor. Provenance olarak mute/rapor satırının
       KENDİ `online_game_id`'si kullanılıyor (o satır ancak ikisi de
       katılımcıyken yazılabildiğinden geçerliliği garantili) — yeni
       `ChatRepo.myModeration()` iki tablodan `userId → gameId` haritası
       döndürüyor. `withdrawReports` zaten kişi bazlı, id İSTEMİYOR.
     - **Canlıda rol simülasyonuyla doğrulandı (hepsi rollback):** iki
       tablodan da `online_game_id` okunabiliyor; **BİTMİŞ** bir oyunun
       id'siyle sessizden çıkarma GEÇİYOR (1 satır → 0) —
       `is_online_game_participant` oyunun `status`üne bakmıyor, yani
       kısayol tam da en çok gerektiği yerde çalışıyor. Bu, "eski oyun
       id'si hâlâ geçerli mi?" sorusunun tahminle değil ölçümle
       cevaplanması gereken kısmıydı.
     - **`ChatRepo` zinciri dört yeni durakla threadlendi** (services →
       Setup/GameScreen/OnlineGameScreen → GameHeader → AccountButton →
       FriendsModal) ve **`LiveGameCreateForm` da dahil edildi**: o ekran
       da `showFriendsModal` açıyor ve atlanırsa AYNI satır bir girişte
       ikonlu, öbüründe ikonsuz görünürdü — bu projenin en sık tekrarlayan
       hata sınıfı (sessiz ayrışma), burada baştan kapatıldı.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** dört yeni
       test (yalnızca durumu OLAN satırda ikon + konumu "çıkar"ın solunda;
       panel → onay → geri çekme → ikon KAYBOLUYOR; sessizden çıkarmanın
       kaydın geldiği oyun id'siyle çağrıldığı; `chat` yokken ikon HİÇ
       çizilmediği). (1) İkon render koşulu kapatılınca ÜÇÜ GERÇEKTEN
       düştü — dördüncüsü (yokluk iddiası) doğru şekilde geçmeye devam
       etti. (2) `if (changed) await _reloadModeration();` kapatılınca
       kullanıcının göreceği bayat-bayrak semptomu BİREBİR üretildi
       (`Expected: no matching candidates / Actual: Found 1 widget with
       text "🚩"`). İkisi de geri konunca yeşile döndü.
     - **Sahte uç gerçek ucun sözleşmesini taklit ediyor** (Parça 46'nın
       dersi): `FakeChatGateway.myModeration` yalnızca kimlikleri değil
       oyun id'sini de döndürüyor — aksi halde "sessizden çıkarma doğru
       id'yle çağrılıyor mu" sorusu testlerde sorulaMAZDI.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       402/402 yeşil** (398'den +4). `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (web yarısı aynı gün, aynı
       dalda) → kök `CLAUDE.md` + `TESTING.md` aynı commit'te güncellendi
       (Parça Bitirme Kontrol Listesi madde 1).
     - ~~**Doğrulama sınırı:** gerçek `myModeration` sorgusu + gerçek
       `setMute`/`withdrawReports` RPC'leri mobilde iki hesapla
       doğrulanmalı~~ — **AYNI GÜN İKİ PLATFORMDA DA KAPANDI.** Web:
       ikon doğru satırda çıktı, temiz satırda çıkmadı, geri çekme
       çalıştı ve `handled`'a dokunmadı. Mobil: 🚫 arkadaş satırında
       çıktı, panelden sessizden çıkarıldı, ikon ANINDA kalktı.
     - **Mobil turun ürettiği kanıt, "çalıştı" beyanından güçlü:**
       üretimde `online_game_message_mutes` **0 satıra** düştü ve
       provenance oyununun (`866eb714…`) durumu **`finished`** — yani
       sessizden çıkarma BİTMİŞ bir oyunun id'siyle gerçek istemciden
       geçti. Bu tam olarak özelliğin varlık sebebi: `mute_online_game_participant`
       katılımcılık kontrolünü `p_muted` dalından ÖNCE yaptığından
       sessizden ÇIKARMAK bile geçerli bir oyun id'si istiyor, ve o id'nin
       bitmiş bir oyuna ait olması sorun ETMİYOR. Daha önce yalnızca
       rollback'li simülasyonla gösterilmişti; artık gerçek uçtan uca.
       Ayrıca `ChatRepo` kablolaması ve emoji fallback'i (🚫 tofu değil)
       de bu turda kapandı.
     - **İkinci yol (şikayet → geri çekme) de AYNI GÜN mobilde koşuldu ve
       tasarımın DÖRT durumunu birden gösterdi:** aktif oyunun sohbetinden
       şikayet (08:19:14) → satırda 🚩 → panelden geri çekme (08:20:11) →
       ikon **kaybolmadı, 🚫'ye döndü** → sessizden çıkarma → ikon kalktı.
       Ortadaki adım kullanıcıya önceden söylenmeseydi "geri çektim ama
       ikon duruyor" diye YANLIŞ bir hata bildirimi üretebilirdi: şikayet
       otomatik sessize alıyor ve geri çekme mute'a bilinçli olarak
       dokunmuyor. **Üretimden asıl kanıt `handled` = `false` KALDI** —
       4 Ağustos'ta yazılıp 10 gün ölü bir overload'da mahsur kalan
       düzeltmenin mobil istemciden ilk doğrulaması (bkz. Parça 90 (a)).
     - **Web ↔ mobil metin paritesi VARSAYILMADI, ölçüldü:** kullanıcı
       paneli mobilde ilk kez görünce "web'e de uyguladık mı?" diye
       sordu; `FriendModerationModal.tsx` ile `friend_moderation_sheet.dart`
       13 dize üzerinden karşılaştırıldı (durum cümlesinin üç varyantı,
       iki buton, onay adımı, iki sonuç mesajı, hata metni, alttaki
       "şikayet sohbetten yapılır" notu) — **13/13 birebir**. Bu dosya
       çiftinin `legal_modals.dart` gibi otomatik bir parite testi YOK;
       biri değişirse öteki elle güncellenmeli.

   - ✅ **Parça 92 — üç kullanıcı isteği, üçü de İKİ platformda birden
     (14 Ağustos 2026, `setup_screen.dart`, `leaderboard_modal.dart`,
     `board_widget.dart`, `game_screen.dart`, `online_game_screen.dart` +
     web `Board.tsx`/`App.tsx`/`OnlineGameScreen.tsx`/`Leaderboard.tsx`):**
     Kullanıcı: *"1. Mobilde girişsiz YZ oyun başlatınca web'deki uyarı
     çıkmıyor. 2. Leaderboard OHP kolonunu az daha puan kolonuna
     yaklaştır. 3. Board altındaki X2/X3 legendları kaldır. Onun yerine
     board'un sağ alt köşesine Hamleler, Mesajlaşma ile aynı stil, 'Nasıl
     Oynanır?' ekle."*
     - **(1) Misafir uyarısı — web'de VARDI, porta hiç girmemişti.** Web
       `Setup.tsx`'in `handleStart`i giriş yapılmamışsa oyunu BAŞLATMADAN
       önce bir uyarı açıyor ("Oyunların istatistikleri, k-lig ve
       arkadaşınla canlı oyun için lütfen giriş yapın." + GİRİŞ YAP /
       DEVAM); port doğrudan `_startNewGame`e gidiyordu. Kaynak okunup
       aynı metin/butonlar `KModal(title: '')` ile taşındı (`GameOverModal`
       emsali — ham `Dialog` kurmak bu projede üç kez geri alındı, bkz.
       Parça 26/47/50).
       - **Sonuç ÜÇ DEĞERLİ olmak ZORUNDA:** ilk taslağım "GİRİŞ YAP" ile
         ✕'i aynı `false`a düşürüyordu, yani ayırt edilemiyorlardı ve
         yanına gereksiz bir yan-etki bayrağı koymuştum. `_GuestChoice
         {login, proceed, dismiss}` ile üçü ayrıldı: DEVAM → oyun başlar,
         GİRİŞ YAP → giriş penceresi açılır ve oyun BAŞLAMAZ (web'de de
         öyle), ✕/zemin → hiçbir şey olmaz. **Bir diyaloğun dönüşü
         `bool` ise "iptal" ile "başka bir yola saptı"yı ayıramazsın** —
         `showDialog<T>` zaten jenerik, enum kullanmanın maliyeti yok.
       - `auth.loading` iken uyarı GÖSTERİLMEZ (kimlik henüz bilinmiyorken
         girişli kullanıcıyı yanlışlıkla durdurmamak için) — web'in
         `profileLoading` beklemesiyle aynı refleks.
     - **(2) OHP ↔ Puan — sağa hizalı bir sütunu SOLA çekmenin tek yolu
       SAĞINDAKİNİ daraltmak.** OHP'nin kendi genişliğini büyütmek/
       küçültmek onu yerinden oynatmaz (metin sağa yaslı; kutu büyüyünce
       yalnızca sol kenarı büyür). Puan 52 → **44** (web `w-12`→`w-10`);
       ölçüldü: iki sütunun sağ kenarları arası **44.0 px**, web'de de
       aynı. Web'de ÜÇ çağrı yeri birden değişmek zorunda (başlık, satır,
       "senin sıran") — biri atlanırsa hiza bozulur.
       - **AYNI GÜN ikinci tur — "OHP başlığı ortalı değil" (kullanıcı):**
         doğruydu ve ÖLÇÜLDÜ: başlığın ink merkezi değerlerin **7.07 px
         sağındaydı**; kıyas için "Puan"ın kendi sapması yalnızca 1.67 px,
         yani sorun OHP'ye özgüydü. **Sebep alignment değil GENİŞLİK:**
         iki dize de sağa yaslıyken merkezleri, genişlik farkının YARISI
         kadar ayrışır — "OHP" 3 karakter/9px (19.53 px ink), değer 5
         karakter/11px (33.67); (33.67−19.53)/2 = 7.07. "Puan"da fark
         tesadüfen küçük (26.05 vs 29.39), o yüzden orada göze batmıyor.
       - **Çözüm sihirli bir kaydırma DEĞİL, kutuyu içeriğe eşitlemek:**
         sütun 52 → **`_kOhpColumnWidth = 34`** (değerin ink genişliği) ve
         başlık `TextAlign.right` → **`center`**. Kutu daralınca SAĞ kenar
         yerinde kalır (boşluk `Expanded` "Oyuncu"ya gider), yani 44 px'lik
         OHP↔Puan hizası ve değerlerin konumu HİÇ değişmez. **Değerler
         sağa yaslı KALMALI** — başlığı ortalamak için değerleri de
         ortalamak, 1 basamaklı bir ortalamada (`9.50`) ondalık hizasını
         bozardı. Web'de aynı sayı `w-[34px]`; ölçülen kalan sapma 0.16 px.
       - **Test SIHIRLI SAYIYI değil SÖZLEŞMEYİ pinliyor** (Parça 81'in
         deseni): üç parça birden — başlık ve değer kutuları AYNI
         genişlikte + başlık `center` + değer `right` + **kutu genişliği
         gerçekten değerin ink genişliği mi** (`TextPainter` ile aynı
         stille ÖLÇÜLEREK, `closeTo(34, 1)` sabitiyle değil). Üçü birden
         gerekli: yalnızca genişlik eşitliğine bakan bir test eski hâlde de
         geçerdi (ikisi de 52'ydi) — nitekim negatif eşte önce o geçti,
         hatayı `TextAlign` yakaladı (`Expected: TextAlign.center /
         Actual: TextAlign.right`).
     - **(3) Tahta alt şeridi.** `- kelime X2 · - kelime X3` legend'ı
       silinip yerine Hamleler/Mesajlaşma ile AYNI stilde (SpaceMono 12
       bold, `letterSpacing 0.5`, `kAccent`) bir "Nasıl Oynanır?" butonu
       kondu; soru-işareti ikonu `_HelpIconPainter` ile web'in SVG
       path'lerinden birebir çizildi (`RelationIcons` ilkesi — glyph
       kopyalanmaz, aynı vektör kullanılır). Yeni opsiyonel `onOpenHelp`
       prop'u; verilmezse buton hiç çizilmez. İKİ oyun ekranı da
       `showHelpModal(context)` bağladı (bilinçli kod tekrarı çifti).
       **Bilgi kaybı yok:** X2/X3 zaten tahtanın kendi filigranlarında ve
       kurallar ekranında yazılı.
     - **Test — negatif eş doğrulamasıyla, ÜÇÜ AYRI AYRI:** (a)
       `setup_screen_test.dart` — mevcut "oyun başlar" testi artık uyarıyı
       görüp DEVAM'a basıyor, artı iki YENİ test (girişli kullanıcıda
       uyarı HİÇ çıkmamalı; ✕ ne oyun başlatmalı ne giriş penceresi
       açmalı); (b) `score_card_test.dart`'ın OHP testine iki sütunun
       sağ kenar farkını 44'e sabitleyen bir assertion; (c)
       `game_screen_test.dart` — legend metinlerinin YOK, "Nasıl
       Oynanır?"ın VAR olduğu ve dokununca kuralların açıldığı. Üç lib
       değişikliği ayrı ayrı geri alınınca üçü de GERÇEKTEN düştü
       (`Found 0 widgets with text containing lütfen giriş yapın`;
       `Expected: a numeric value within <0.5> of <44> Actual: <52.0>`;
       `Found 0 widgets with text "Nasıl Oynanır?"`), geri konunca yeşile
       döndü.
     - **Test yazarken düşülen iki tuzak (kayda geçsin):** (1) kurallar
       penceresinin varsayılan adımı "NASIL OYNANIR?" DEĞİL **"HIZLI
       BAŞLANGIÇ"** — başlığı tahminle yazan assertion 0 widget buldu;
       (2) `auth_test.dart`'ın hesap menüsü testi `find.textContaining
       ('Nasıl Oynanır?')` kullanıyordu ve artık İKİ eşleşme buluyor
       (menü maddesi + tahta şeridi) — emoji önekiyle TAM eşleşmeye
       (`'❓  Nasıl Oynanır?'`) çevrildi. **Yeni bir yere var olan bir
       metni eklerken, o metni arayan MEVCUT testleri de tara.**
     - **Web duman testi de bu değişiklikle İKİ KEZ kırıldı** (ayrıntı ve
       kalıcı ders kök `CLAUDE.md`'de): Playwright'ın `getByRole(name:)`
       eşleşmesi varsayılan olarak büyük/küçük harf DUYARSIZ ALT DİZE
       arıyor → "Nasıl **Oyna**nır?" `OYNA` butonuyla çakıştı; `exact:
       true` eklenince bu sefer 0 sonuç, çünkü `exact` aynı zamanda
       harf DUYARLI ve DOM metni `Oyna` (büyük harf yalnızca CSS
       `uppercase`). Doğrusu `{ name: 'Oyna', exact: true }`.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       405/405 yeşil** (402'den +3). Web `npm run lint` + `npm run build`
       + `npm run test` (Playwright, 2 passed) temiz. `kelimeki_core`'a
       hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (web yarısı aynı gün, aynı
       dalda) → kök `CLAUDE.md` + `TESTING.md` aynı commit'te güncellendi
       (Parça Bitirme Kontrol Listesi madde 1).
     - **Doğrulama sınırı:** cihazda görsel/dokunma teyidi kullanıcıdan
       bekleniyor — `mobile/TESTING.md` bölüm 1/4'e maddeler eklendi.

   - ✅ **Parça 93 — `HelpModal` metin paritesi: denetlendi (TEMİZ çıktı) ve
     artık bir testle bağlı (14 Ağustos 2026, yeni
     `test/help_text_parity_test.dart`):** "Sonraya Bırakılan İşler"in ilk
     maddesi kapandı. Parça 90 hukuki metinleri bağlamıştı; `HelpModal`'ın
     aynı "birebir kopya" sözleşmesi hâlâ yalnızca bir YORUM satırıyla
     korunuyordu — ve o sözleşme bu projede bir kez zaten kırılmıştı
     (Gizlilik metni dört gün bayat kalıp kullanıcıya kendi verisi hakkında
     yanlış bilgi verdi).
     - **Denetim sonucu TEMİZ:** 11/11 bölüm başlığı, 9/9 Hızlı Başlangıç
       maddesi portta var; paragrafların 30/40'ı normalize edilmiş hâliyle
       BİREBİR, kalan 10'un hepsi açıklanabilir (9'u uzunluk filtresine
       takılan bölüm başlığı, 1'i iki tarafın da KENDİ motorundan okuduğu
       `BINGO_BONUS`/`$bingoBonus`). Yani düzeltilecek bir sapma YOKTU —
       değerli olan bulgu değil, bundan sonrasını koruyan test.
     - **Vekil olarak "Son güncelleme" KULLANILAMADI** (hukuki metinlerdeki
       çözüm): `HelpModal.tsx`te öyle bir damga yok. Onun yerine metnin
       YAPISI vekil alındı — web'de makine-okunur duran `<Section title="…">`
       ve `<QuickItem icon="…">` listeleri porta karşı doğrulanıyor. Bu, asıl
       korkulan hata sınıfını tam olarak yakalıyor: **web'e yeni bir bölüm
       eklenip porta eklenmemesi.** Parça 66'nın "Rütbeler ve Ödüller"i tam
       böyle kaçabilirdi.
     - **Test kendi regex'ine karşı da korunuyor:** başlık/ikon sayısına bir
       ALT SINIR (≥11 / ≥9) konuldu — web JSX'i yeniden düzenlenirse regex
       sessizce 0 eşleşme bulup "geçemez". Bu, `legal_text_test`in
       `isNotNull` kontrolüyle aynı refleks.
     - **İki ek değişmez de pinlendi:** rütbe tablosunun İKİ tarafta da elle
       yazılmadığı (`RANK_TIERS`/`kRankTiers` — dördüncü bir elle senkron
       kopya açılırsa eşik değişiminde ilk sessizce ayrışacak yer orası) ve
       bingo bonusunun motordan okunduğu.
     - **DÜRÜST SINIR (teste de yazıldı):** bu test var olan bir paragrafın
       İÇİNDEKİ cümle değişikliğini YAKALAMAZ. Tam metin karşılaştırması
       JSX ↔ Dart arasında kırılgan olurdu (web cümleyi `<strong>`larla
       parçalıyor, port `**` ile işaretliyor; biri `{BINGO_BONUS}` diğeri
       `$bingoBonus` gömüyor) — o ayrışma elle denetim istiyor, bugünkü tur
       onu yaptı.
     - **Denetim aracının kendisi İKİ KEZ yanlış cevap verdi, ikisi de
       ölçümle yakalandı — kayda değer:** (1) ilk çıkarıcı web'i
       `export function HelpModal`ten dilimliyordu, ama o fonksiyon dosyanın
       SONUNDA (satır 415), içerik ondan önceki const'larda → "web paragraf:
       0" ile TÜM metin elenmişti; (2) Dart tarafında bitişik dize
       birleştirmesi (`'a'\n'b'`) hesaba katılmayınca her paragraf parçalara
       bölünüp 137 sahte "eksik" üretti. **Ders: bir parite denetimi
       "fark bulundu" derse önce ARACI şüphelen** — bu iki artefakt
       düzeltilmeden önce rapor, gerçekte var olmayan onlarca eksik
       gösteriyordu; körlemesine "düzeltmeye" kalksaydım çalışan metni
       bozardım.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 409/409
       yeşil** (405'ten +4). **Negatif eş:** web'e sahte bir
       `<Section title="Yepyeni Bölüm">` eklenince test GERÇEKTEN korkulan
       hata mesajıyla düştü (`Web'de "Yepyeni Bölüm" bölümü var, portta
       YOK`), web dosyası geri alınınca yeşile döndü. `kelimeki_core`'a ve
       üretim koduna hiç dokunulmadı — yalnızca yeni bir test.

   - ✅ **Parça 94 — rütbe tablosunun TS ↔ Dart yarısı da testle bağlandı
     (14 Ağustos 2026, yeni `test/rank_tiers_parity_test.dart`):** Parça
     93'ün açtığı soruyu ("bu 'elle senkron' kopyayı hangi test zorluyor?")
     projedeki EN ÇOK uyarılan kopyaya sordum ve cevap "hiçbiri" çıktı.
     - **Mevcut testler bu ayrışmayı yapısal olarak GÖREMİYORDU:**
       `league_rewards_test.dart` yalnızca İÇ tutarlılığı ölçüyor (ödül =
       eşik/10, kümülatif toplamların farklılığı, sınır davranışı). Web'de
       bir eşik değişip portta değişmese o testlerin HEPSİ geçmeye devam
       ederdi — kural kendi içinde tutarlı kalır, yalnızca iki platform
       ayrışırdı. Üç dosyanın da başlığındaki "hiçbir derleyici/test bunu
       yakalamaz" cümlesi kelimesi kelimesine doğruydu.
     - **Test `color_tokens_test`in desenini izliyor:** web'in
       `src/utils/leagueRank.ts`'ini OKUYUP `RANK_TIERS` satırlarını
       ayrıştırıyor ve `kRankTiers` ile alan alan karşılaştırıyor
       (ad/harf/eşik/ödül/renk). **Renk karşılaştırması çözülmüş değer
       üzerinden** — web hex literal yazıyor, port palet token'ı
       (`kAccent` gibi) kullanıyor; yanlış token seçilirse yakalanır.
     - **Ayrıştırıcı kendi sessiz başarısızlığına karşı korunuyor** (Parça
       93'ün aynı refleksi): satır sayısına ≥9 alt sınırı var, yani TS
       dosyası yeniden düzenlenip regex 0 eşleşme bulursa test "geçemez".
     - **SQL yarısı BİLİNÇLİ kapsam dışı ve bu teste yazıldı:**
       `_award_league_rewards`ın güncel tanımı tek bir migration dosyasında
       DURMUYOR (sonraki migration'lar fonksiyonu yeniden yazıyor), yani
       "şu an canlıda ne var" sorusu ancak veritabanına sorularak
       yanıtlanır — bir birim testi bunu yapamaz. Eşik/ödül değiştiren her
       migration canlıda ayrıca doğrulanmaya devam edecek.
     - **Bayat iddialar aynı commit'te düzeltildi:** üç dosya (`leagueRank.ts`,
       `league_rank.dart`, kök `CLAUDE.md`) hâlâ "hiçbir derleyici/test bunu
       yakalamaz" diyordu — artık yarısı yanlış. Üçü de "TS ↔ Dart testli,
       SQL korumasız" olarak güncellendi. **Bir korumayı eklerken onun
       yokluğunu anlatan cümleleri de ara** — aksi halde bir sonraki oturum
       var olan testi bilmeden çalışır.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 411/411
       yeşil** (409'dan +2) — tablo şu an GERÇEKTEN senkron. **Negatif eş:**
       TS'te Usta'nın eşiği 250→300 yapılınca test GERÇEKTEN
       `4. kademe (web: "Usta") — EŞİK ayrışmış / Expected: <300> Actual:
       <250>` ile düştü, web dosyası geri alınınca yeşile döndü.

   - ✅ **Parça 95 — Canlı oyun cihaz turu (TESTING.md bölüm 11): beş bulgu,
     ÜÇÜ web'de (14 Ağustos 2026):** Bölüm 11 ilk kez iki gerçek hesapla
     baştan koşuldu. Çıkan beş bulgunun yalnızca ikisi porta özgüydü; üçü
     web'in kendi hatasıydı ve port ya doğru davranıyordu ya da aynı hatayı
     web'den miras almıştı. **Bu turun en genel dersi:** paylaşılan bir
     kuralı "her zaman türet" diye sağlamlaştırırken, o kanalı kullanan
     MEŞRU/TAZE mesajların da yutulup yutulmadığını sor.
     - **(1) Boş taslakta OYNA — web'in Canlı ekranı sessizdi (web
       düzeltmesi).** `OnlineGameScreen.tsx:760`'ta `if
       (placedCoords.length === 0) return;` vardı: hiç taş koymadan OYNA'ya
       basınca hiçbir şey olmuyor, mesaj satırında bir önceki metin
       ("Taşlar rafa geri alındı") duruyordu. **Port BU KONUDA ZATEN
       DOĞRUYDU** — Parça 88'de bu guard bilerek kaldırılmış ve
       `_handlePlay`e gerekçesi yazılmıştı; web'in Canlı ekranı geride
       kalmıştı (yerel ekran `App.tsx` de doğruydu: PLAY'i reducer'a
       dispatch ediyor, reducer aynı validator'dan "Harf yerleştirilmedi."
       üretiyor). Guard kaldırıldı; `validatePlacementStructural` zaten boş
       taslakta doğru mesajı döndürüyor ve `moveStatus` boş taslakta `null`
       olduğundan mesaj görünür oluyor.
     - **(2) Gönderim hatası mesaj satırında HİÇ görünmüyordu (İKİ
       platformda birden — en ciddi bulgu).** Uçak modunda kelime koyup
       OYNA'ya basınca web'de hiçbir şey olmuyor, portta "GÖNDERİLİYOR"
       ~5sn sonra sessizce eski hâline dönüyordu. Kök sebep 6 Ağustos'taki
       `myTurnValidNote`/`myTurnNote` kuralı: "geçerli taslak + sıra sende"
       iken mesaj satırı KOŞULSUZ türetiliyor. O kural bayat mesajlara
       karşı doğruydu ama **gönderim hatası bayat değil** — kullanıcının az
       önce bastığı butonun sonucu; hamle reddedilince taşlar tahtada
       kaldığından taslak hâlâ geçerli oluyor ve hata sonsuza dek
       görünmüyordu. Çözüm iki tarafta da aynı: hatalar reducer'ın
       `state.message`ına DEĞİL ayrı bir `submitError`/`_submitError`
       kanalına yazılıyor ve türetilen notlardan ÖNCE geliyor; taslağın
       imzası (hücre+harf+jokerin harfi) değiştiği an sıfırlanıyor.
       Reducer'a hiç dokunulmadı (motor dosyası — golden vector paritesi).
       **`App.tsx`e de uygulandı** çünkü orada ulaşılabilir bir dal var:
       sunucu sözlüğü kelimeyi reddederse (`moveStatus` YEREL sözlükle
       hesaplandığından taslak geçerli görünür) mesaj yutuluyordu. **Portun
       yerel ekranı bilerek DEĞİŞMEDİ** — orada sözlük tamamen pakette,
       sunucuya hiç sorulmuyor, yani ulaşılabilir bir gönderim hatası YOK;
       eklemek ölü kod olurdu.
     - **(3) Sohbet ön plana dönüşte tazelenmiyordu (İKİ platformda
       birden).** Kullanıcı "app'den web'e mesajlar anında gidiyor ama
       web'den app'e gelmiyor, setup'a çıkıp girince geliyor" dedi.
       Asimetrinin sebebi kanal değil KURTARMA yolları: oyun state'i ÜÇ
       yoldan tazeleniyor (Realtime + periyodik + ön plana dönüş) ama
       sohbet YALNIZCA Realtime'a bağlıydı — oysa "arka planda websocket
       askıya alınır, kaçırılan olay bir daha oynatılmaz" gerekçesi (web
       `OnlineGameScreen.tsx`'te 340-345'te yazılı) iki tablo için de
       aynen geçerli. iPad'de iki Safari sekmesi arasında gidip gelmek tam
       da bu durumu üretiyor: web sekmesine yazarken app sekmesi arka
       planda. Aynı üçlü dinleyici + aynı 1sn debounce sohbete de kuruldu
       (portta `didChangeAppLifecycleState`'in resume dalına `_fetchChat()`).
       **Popup bilerek tetiklenmiyor** — arka planda biriken beş mesaj için
       beş popup değil, tek okunmamış rozeti; abonelik de yeniden
       kurulmuyor (`_loadChat` = veri + abonelik, `_fetchChat` = yalnız veri).
     - **(4) Oyun sonu modalının hamle geçmişi Canlı'da BOŞ (port
       düzeltmesi).** "Oyun Geçmişi" linki "Henüz kazanılmış bir puan yok."
       diyordu, ama AYNI ekranın tahta altındaki "Hamleler" linki dolu
       listeyi gösteriyordu. Yapısal sapma: web'in `GameOver`u
       `onOpenHistory`i bir **callback** olarak alıp HANGİ state'in
       gösterileceğini ebeveyne bırakıyor (`App.tsx` kendi state'ini,
       `OnlineGameScreen.tsx` sunucu satırlarından türettiği `historyState`i
       geçiyor); port bu kararı widget'ın İÇİNE gömüp `state`i doğrudan
       kullanıyordu — Canlı'da reducer'ın `moveHistory`si boş olduğundan
       sonuç boş liste. `onOpenHistory` artık ZORUNLU parametre (iki çağrı
       yeri de kararı vermek zorunda) ve iki yer de tek bir `_historyState`
       getter'ından besleniyor.
     - **(5) "Çevrimdışı" rozeti okunmuyordu (web, kullanıcı isteği).**
       Board alt şeridindeki gösterge `text-[8px]`ti; kardeşleri
       (Hamleler · Mesajlaşma · Nasıl Oynanır?) `text-[12px] font-mono
       font-bold tracking-[0.5px]`. Tam da çevrimdışıyken okunması gereken
       tek gösterge şeridin en küçük yazısıydı — kardeşlerle birebir aynı
       sınıflara çekildi (yalnız rengi farklı). **Portta bu göstergenin
       KARŞILIĞI HİÇ YOK** (`useOnlineStatus` porta hiç girmemiş); bulgu
       (2)'nin düzeltmesi "app hiçbir şey söylemiyor" kısmını kapattığından
       ayrı bir bağlantı göstergesi eklemek bu turun kapsamına alınmadı —
       "Sonraya Bırakılan İşler"e yazıldı.
     - **Doğrulama:** `flutter analyze` temiz; **tam takım 414/414 yeşil**
       (411'den +3 — üçü de yeni). `npm run lint` + `npm run build` temiz,
       Playwright duman testleri 2/2. **Üç negatif eş ayrı ayrı koşuldu:**
       (a) GameOver'a `_historyState` yerine `state` geçilince yeni test
       düştü; (b) `submitError` türetilen notlardan SONRAYA alınınca
       "Bağlantı yok." bulunamadı (kullanıcının gördüğü semptomun birebir
       kendisi); (c) resume dalından `_fetchChat()` çıkarılınca sohbet
       tazeleme testi düştü. **Mevcut "sunucu reddi mesaj satırına düşer"
       testinin bu hatayı neden göremediği kayda değer:** o test PAS GEÇ
       kullanıyor, pas'ta tahta boş, dolayısıyla `myTurnNote` hiç devreye
       girmiyor — yeni test taşları TAHTADA bırakarak reddettiriyor.
     - **Cihazda doğrulanacak:** beş düzeltmenin hiçbiri gerçek iki-hesap
       akışında henüz koşulmadı; maddeler `mobile/TESTING.md` bölüm 11 ve
       kök `TESTING.md` bölüm 2'ye eklendi.

   - ✅ **Parça 96 — Canlı oyun çevrimdışıyken ne diyor? İki sessiz yol
     kapatıldı (14 Ağustos 2026, kullanıcı YAYINDAKİ webde bildirdi):**
     Kullanıcı ana ekrana eklediği webde uçak modunu denedi: (a) listeden
     hamle bekleyen bir Canlı oyuna dokununca ekran beyaz "Yükleniyor…"da
     asılı kaldı ve ancak çevrimiçi olunca yüklendi, (b) tahta açıkken
     hamle yapınca hiçbir şey olmadı. Ardından doğru soruyu sordu:
     *"Offline sadece YZ oyunlar için mi geçerli? Eğer öyleyse ... bir
     uyarı gerekir (hem web hem de app için)"*.
     - **Cevap evet ve bu bir tasarım kararı:** Canlı oyunda tahta/raf/torba
       sunucuda otoriter (`online_game_states`/`online_game_secrets`);
       offline dayanıklılık yalnızca yerel/YZ için var (localStorage +
       `cloudSaveMirror`). Sorun kuralın kendisi değil, kullanıcının bunu
       yalnızca SESSİZLİKTEN çıkarmak zorunda kalmasıydı.
     - **(a) Sonsuz "Yükleniyor…" — "ekranı koru" davranışının kapsam
       hatası.** İki platformda da yükleme başarısız olunca sessizce
       dönülüyordu (`if (!publicState) return` / `if (snap == null)
       return; // ağ hatası — ekran korunur`). Bu TAZELEMEDE doğru (bayat
       veri hiç veriden iyidir) ama İLK yüklemede korunacak bir şey yok:
       `_loaded` hiç true olmuyor, ekran sonsuza dek yükleniyor kalıyor.
       Artık ilk yükleme başarısızsa `loadFailed`/`_loadFailed` işaretlenip
       ne olduğunu anlatan bir panel + **TEKRAR DENE** + **← CANLI LİSTESİ**
       gösteriliyor; tazeleme davranışı DEĞİŞMEDİ.
     - **(b) Hamle hatası artık ham ağ metni değil.** Parça 95'in
       `submitError`i hatayı görünür yapmıştı ama içerik
       "ClientException: Failed to fetch…" gibi bir şeydi. Artık ağ katmanı
       hataları kısa bir uyarıya çevriliyor; **sunucunun KENDİ reddi
       ("Sıra sende değil.") olduğu gibi kalıyor** — bilinmeyen bir hatayı
       "bağlantı yok" diye maskelemek hata ayıklamayı imkânsız kılardı
       (aynı ilke: `friendlyAuthMessage`).
     - **Metinler TEK KAYNAKTA ve testli:** `src/utils/offlineNotice.ts` ↔
       `mobile/app/lib/src/util/offline_notice.dart`. Yeni
       `test/offline_notice_test.dart` web dosyasını OKUYUP üç metni de
       karşılaştırıyor (`color_tokens_test`/`rank_tiers_parity_test`
       deseni) — biri değişip öteki kalırsa test düşer.
     - **Metin bilerek "çevrimdışısın" DEMİYOR, "sunucuya ulaşılamıyor"
       diyor.** Kullanıcının önerdiği cümle "Şu anda çevrimdışısınız"dı ama
       aynı metin sunucu erişilemez olduğunda da DOĞRU olmak zorunda ve
       Flutter tarafında gerçek bir bağlantı API'si yok (`useOnlineStatus`
       portu hâlâ eksik — bkz. "Sonraya Bırakılan İşler"). İçeriğin üç
       parçası korundu: sorun ne, ne yapmalı, alternatif ne (YZ).
     - **`isNetworkError` `dart:io` KULLANMIYOR** (web derlemesini kırardı)
       — tip yerine metin eşlemesi; kalıplar arasında **Safari'nin "Load
       failed"i** de var, port iPad Safari'de test edildiğinden şart.
     - **Doğrulama:** `flutter analyze` temiz, **tam takım 420/420** (414'ten
       +6). `npm run lint`/`build` temiz, Playwright 2/2. **Üç negatif eş:**
       `_loadFailed` ataması kaldırılınca panel testi "Yükleniyor…" bulup
       düştü; `isNetworkError` dalı kaldırılınca kısa uyarı bulunamadı;
       web'deki metin tek kelime değiştirilince parite testi "mesaj satırı
       metni ayrışmış" dedi.
     - **(a)'nın WEB yarısı ilk sürümde İŞE YARAMADI (aynı gün, cihazda
       bildirildi):** yalnızca "null döndü" dalı ele alınmıştı, oysa web'de
       `getMyOnlineRack` hatada `throw` ediyor → `Promise.all` reddediliyor →
       `setLoadFailed` satırına hiç ulaşılmıyordu. Üç çağrı tek try/catch'e
       alındı. **Portta bu delik yoktu** (`loadGame` zaten üçünü de sarıyor)
       ve Flutter testi tam bu yüzden geçmişti — test doğruydu, web'in
       FARKLI hata sözleşmesini temsil etmiyordu. Ders: aynı düzeltmeyi iki
       platforma uygularken "hata nasıl yüzeye çıkıyor?" sorusunu her
       platform için ayrı sor.
     - **Sekmelerin kendisi de konuşuyor (aynı gün, ikinci tur):** panelden
       dönen kullanıcı Canlı sekmelerinde "davetiniz yok"/"Yükleniyor…"
       görüyordu. Panelin geri butonu hedef adı taşımayan **"Geri Dön"e**
       çevrildi; `live_games_tab`'ın üç alt sekmesi çevrimdışıyken tek bir
       **"İnternet bağlantısı yok"** gösteriyor; **YZ sekmesi bilinçli
       olarak farklı konuşuyor** — orada oynanabilir bir şey var, o yüzden
       linkli bir öneri ("Hemen oyun aç." → `_creatingLocal = true`, "+ YENİ
       YAPAY ZEKA OYUNU AÇ" ile aynı). Öneri yalnızca gösterilecek KAYIT
       YOKKEN çıkar: devam eden YZ oyunları çevrimdışı da oynanabiliyor.
       **Mekanizma web'den farklı, metin aynı:** web `useOnlineStatus`
       kullanıyor, portta bağlantı API'si olmadığından sinyal `_loadFailed`
       ("son yükleme sunucuya ulaşamadı").
     - **Aynı turun iki küçük düzeltmesi:** "Hemen oyun aç." metin-içi link
       DEĞİL gerçek `NeoButton` (turuncu, "+ YENİ YAPAY ZEKA OYUNU AÇ" ile
       aynı varyant); ve öneri artık `saves == null` iken GÖSTERİLMİYOR —
       liste bilinmiyorken "hiç oyunun yok" demek erken yargı, çevrimdışıyken
       ağ denemesi bitince aynadan gerçek liste geliyor.
     - **Kelime anlamı porta DOKUNMADI:** web'de çevrimdışı "anlamı
       bulunamadı" çıkıyordu (6.3 MB `meanings.json` precache'te yok) ve
       oraya web'e ÖZEL bir mesaj eklendi; portta anlamlar
       `assets/dictionary/meanings.db` ile pakette olduğundan çevrimdışı
       zaten çalışıyor — eklenecek bir şey yok.
     - **App turunda çıkan İKİ düzeltme (aynı gün):**
       - **Panel BOZUK çiziliyordu** (kullanıcı ekran görüntüsüyle bildirdi):
         kart ekran boyu beyaz bir dikdörtgene dönüşüyordu. Sebep `NeoBox` —
         çocuğunu `SizedBox.expand` ile sarıyor, yani gelen kısıtları
         DOLDURUYOR; boyutu dışarıdan belli olan yerler için tasarlanmış,
         `Center` altında shrink-wrap ETMİYOR. Düz bir `DecoratedBox`a
         çevrildi. **Ölçüldü:** kart 420x900 ekranda 900 → **251** px;
         negatif eş NeoBox geri konunca 900'e dönüyor ve yeni test düşüyor.
       - **Kelime anlamı çevrimdışı "bulunamadı" diyordu** — ve bu, bir
         önceki turda YAZDIĞIM iddiayı çürüttü. "Portta sözlük pakette,
         çevrimdışı çalışır" NATIVE için doğru ama portun test ortamı olan
         **Flutter web derlemesi** için YANLIŞ: orada asset de HTTP ile
         çekiliyor (`MeaningStore._openWeb` ilk açılışta 6 MB'ı IndexedDB'ye
         kopyalar) ve uçak modunda o çekim düşüyor. `MeaningStore` artık
         açılış hatasını `unavailable` bayrağında tutuyor, modal o durumda
         web'le AYNI metni gösteriyor (parite testine de eklendi).
         **Ders: "asset pakette" demek her derleme hedefi için aynı şeyi
         ifade etmiyor.**
     - **Bağlantı sinyali porta geldi (`connectivity_plus`, kullanıcı
       onayıyla):** Çevrimdışı mesajı Setup'ta uzunca "Yükleniyor…"dan sonra
       çıkıyordu — kullanıcı *"hemen çıkmalı bence"* dedi. Kök sebep
       yapısaldı: port çevrimdışı kararını bir ağ çağrısının BAŞARISIZ
       olmasını bekleyerek veriyordu (`_loadFailed`) ve uçak modunda Supabase
       auth'un token yenileme tekrarları bunu saniyelere çıkarıyordu; web ise
       `navigator.onLine` ile ANINDA karar veriyordu. `util/online_status.dart`
       (web `useOnlineStatus` portu) `AppServices.onlineStatus` olarak
       eklendi; `LiveGamesTab`, `SetupScreen` ve `RecentGamesSection` bunu
       dinliyor. **`_loadFailed` yolları KALDIRILMADI** — ikisi birlikte
       çalışıyor: bağlantı sinyali HIZLI ama iyimser ("arayüz var" ≠
       "internet var": captive portal, bozuk DNS), başarısız yükleme YAVAŞ
       ama kesin; mesaj ikisinden biri doğruysa çıkıyor.
       - **Testi ağ cevabını beklemediğini KANITLIYOR:** sahte uç asılı bir
         future dönüyor (`listHangs`), yani test ancak karar bağlantı
         sinyalinden geliyorsa geçiyor. Negatif eş: koşul kaldırılınca
         "İnternet bağlantısı yok" bulunamıyor.
       - **Doğrulama sınırı:** `pubspec.lock` bu ortamda yenilendi (yalnızca
         yeni paketler + Dart kısıtı; başka sürüm oynaması yok) ama
         **Android/iOS derlemesi burada koşulamıyor** — plugin'in native
         tarafı yalnızca CI'daki `mobile-build.yml` ile doğrulanabilir.
     - **Yan etki, 15 Ağustos 2026'da cihaz turunda ölçüldü — bu değişiklik
       AYNI GÜN yazılmış BAŞKA bir test maddesini geçersiz kıldı:** Parça
       90, "uçak modunda bir Canlı davete Kabul Et/Reddet'e bas → 'İşlem
       başarısız oldu.' çıkmalı" maddesini eklemişti; birkaç saat sonra bu
       parça `LiveGamesTab`'ın ÜÇ alt sekmesini de çevrimdışı kapısının
       arkasına aldığından davet kartı artık hiç çizilmiyor — basılacak bir
       buton yok. Kullanıcı doğru olanın bu olduğunu belirtti ("bu şekilde
       iyi bence"): hata sonrası açıklama yerine en baştan "burada
       yapılacak bir şey yok" demek. **`kFriendActionFailed` ölü kod
       DEĞİL** — bağlantı sinyali "online" derken isteğin düştüğü durumlar
       (captive portal, sunucu/RLS hatası, sekme çizildikten sonra kopan
       bağlantı) hâlâ o dala düşüyor; ayrıca `FriendsModal`'ın kendi yanıt
       akışında çevrimdışı kapısı HİÇ YOK (grep ile doğrulandı), yani Parça
       89'un maddesi orada aynen geçerli. Kod değişmedi, `mobile/TESTING.md`
       bölüm 11'deki madde gerçeğe çekildi.
       **Ders:** bir ekranı çevrimdışı kapısının arkasına alırken, o ekranın
       İÇİNDEKİ kontroller hakkında yazılmış test maddelerini de tara — kapı
       onları sessizce ulaşılamaz kılıyor ve madde bir sonraki turda "hata"
       gibi görünüyor.
     - **Cihazda doğrulanacak:** iki senaryo da `mobile/TESTING.md` bölüm 11
       ve kök `TESTING.md` bölüm 2'ye eklendi.

   - ✅ **Parça 97 — tahta alt şeridindeki "Çevrimdışı" uyarısı porta hiç
     girmemişti (14 Ağustos 2026, `board_widget.dart`, `game_screen.dart`,
     `online_game_screen.dart`, `setup_screen.dart`, `live_games_tab.dart`):**
     Kullanıcı Parça 96'nın deploy'undan sonra bildirdi: *"Bir de tahta altında
     çevrimdışı (kırmızı) uyarıyı da göremedim."*
     - **Web önce okundu (kuralın ilk adımı) ve orada SORUN YOKTU:**
       `Board.tsx` `useOnlineStatus()`ü KENDİ İÇİNDE çağırıyor ve `!online`
       iken şeridin sağ grubunda (`gap-2` = 8px, "Nasıl Oynanır?"ın solunda)
       kırmızı bir "Çevrimdışı" basıyor — bu turda (#256) puntosu da
       kardeşleriyle eşitlenmişti. Yani bildirilen şey bir REGRESYON değil,
       portun hiç sahip olmadığı bir gösterge: iki `CLAUDE.md` de bunu
       "Flutter portunda karşılığı HİÇ YOK" diye zaten yazıyordu.
     - **Bu parçayı MÜMKÜN KILAN şey Parça 96:** gösterge bir bağlantı sinyali
       ister ve o sinyal porta dün geldi (`OnlineStatus`). Ondan önce
       eklenebilecek tek şey `_loadFailed` gibi dolaylı bir vekildi — yerel/YZ
       oyununda hiç ağ çağrısı olmadığından orada HİÇBİR ZAMAN tetiklenmezdi,
       yani rozet tam da en çok gerektiği ekranda ölü kalırdı.
     - **Enjeksiyon, hook değil:** web'de her `Board` göstergeyi kendiliğinden
       alıyor; Flutter'da `BoardWidget` saf bir widget olduğundan
       `OnlineStatus? onlineStatus` prop'u eklendi ve İKİ oyun ekranı da
       (`game_screen.dart` + `online_game_screen.dart` — bilinçli kod tekrarı
       çifti) geçiyor. Verilmezse uyarı hiç çizilmez: salt-okunur önizlemeler
       (`hideFooter`) ve mevcut testler etkilenmedi.
     - **Yalnızca sağ grup `ListenableBuilder` içinde** — gerçek senaryo
       kullanıcının oyun AÇIKKEN uçak moduna geçmesi; doğrudan okuma o anda
       hiçbir şey değiştirmezdi (ekran yeniden inşa edilmiyor). Kapsam bilerek
       dar: Parça 23'ün dersi gereği bağlantı değişimi 169 hücrelik tahtayı
       yeniden çizmemeli.
     - **Punto/renk tahminle DEĞİL, web'in sınıflarından birebir:**
       `text-[12px] font-mono font-bold tracking-[0.5px] text-red` →
       12/SpaceMono/bold/0.5/`kRed`. Test bunları SABİT SAYIYLA değil
       KARDEŞİYLE ("Nasıl Oynanır?") karşılaştırıyor — biri değişirse öteki de
       değişmek zorunda kalıyor (Parça 68'in "sabiti değil oranı kilitle"
       deseni).
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** (1)
       `game_screen_test.dart` — çevrimiçiyken uyarı YOK, ekranı YENİDEN PUMP
       ETMEDEN bağlantı düşünce ANINDA çıkıyor, stil kardeşiyle aynı, bağlantı
       dönünce kalkıyor. `ListenableBuilder` düz bir `Builder`a çevrilince test
       GERÇEKTEN düştü — yani reaktiflik iddiası kanıtlı, "prop var" değil.
       (2) `online_game_screen_test.dart` — yalnızca KABLOYU ölçen kısa bir
       test; `onlineStatus: widget.onlineStatus` satırı silinince GERÇEKTEN
       düştü. İkincisi şart, çünkü iki ekranın ayrışması derleyicinin
       göremediği klasik hata sınıfı.
     - **Testte üretim koduna debug setter EKLENMEDİ:** bağlantıyı açıp
       kapatmak için test-yerel bir `_ToggleOnlineStatus extends OnlineStatus`
       alt sınıfı (`super.fake()`, platform kanalına hiç dokunmuyor) —
       `AuthService.debugSetUser` emsali varken üretim yüzeyi büyütülmedi.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 424/424
       yeşil** (422'den +2). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** gerçek uçak modunda görsel teyit cihazda
       yapılmalı — `mobile/TESTING.md` bölüm 11'e madde eklendi. Web'in
       göstergesi de aynı turda (#256) düzeltilip henüz cihazda
       görülmediğinden ikisi BİRLİKTE kontrol edilmeli.

   - ✅ **Parça 98 — asıl kök sebep rozette DEĞİL bağlantı durumundaydı: kaçırılan
     `offline` olayı kalıcı kayıptı (14 Ağustos 2026, `useOnlineStatus.ts`,
     `online_status.dart`):** Kullanıcı AYNI bulguyu ikinci kez bildirdi
     (*"tahta altında çevrimdışı (kırmızı) uyarıyı da göremedim"*) — Parça
     97'de portun eksik göstergesini eklemiştim ama o turda web için
     *"sorun yok"* demiştim ve bunu KODU OKUYARAK söylemiştim.
     - **Bu sefer ÖLÇÜLDÜ:** `npm run build` + gerçek uygulama Chromium'da
       açılıp bir YZ oyunu başlatıldı, `context.setOffline(true)` ile uçak
       modu simüle edildi — rozet çıktı (12px, `rgb(220,38,38)`, Space Mono,
       kardeşinden 8px). Yani web'in RENDER'ı gerçekten doğruydu.
     - **Ama hook'ta gerçek bir boşluk vardı:** `useOnlineStatus` YALNIZCA
       `online`/`offline` olaylarını dinliyordu. Kullanıcı ana ekrana eklenmiş
       PWA'da test ediyor ve uçak modunu açmak için Kontrol Merkezi'ne
       çıkıyor — sayfa o anda askıya alınıyor, olay JS'e hiç ulaşmıyor, durum
       bayat `true` kalıyor ve rozet BİR DAHA çıkmıyor.
     - **Senaryo gerçek tarayıcıda BİREBİR üretildi:** `navigator.onLine`
       `addInitScript` ile kontrol edilebilir yapılıp OLAY ATEŞLENMEDEN false
       çekildi → rozet yok; `visibilitychange` gönderildi → rozet çıktı.
       **Negatif eş:** düzeltme `git stash`lenip yeniden derlenince öne
       dönüşten sonra da rozet ÇIKMADI (0) — kullanıcının gördüğü semptomun
       ta kendisi.
     - **Bu, kaçırılan olayın bu projede kalıcı kayba dönüştüğü ÜÇÜNCÜ yer:**
       sohbet Realtime'ı (Parça 95) ve bulut senkronu (Parça 44) aynı çareyi
       almıştı — "öne dönüşte gerçeği yeniden oku". Gerekçe iki kez yazılmış
       ama bu hook'a hiç uygulanmamıştı.
     - **Port da aynı kancayı aldı** (`OnlineStatus` artık
       `WidgetsBindingObserver`, `resumed`'da `refresh()`): `connectivity_plus`
       akışı da askıdaki uygulamada olay kaçırabilir. **Bu yarısı TESTSİZ
       KALDI:** üretim kurucusu platform kanalı istediğinden ve `fake()`
       bilerek observer kaydetmediğinden davranış widget testinde sınanamadı —
       ve tam bu yüzden CİHAZ turu onun tek kanıtı oldu (aşağı bkz.).
     - **Ders — "web'de sorun yok" da bir TEŞHİSTİR ve ölçüm ister.** Parça
       34'ün dersi ("ölçmeden YOK SAYMA") burada bir üst basamağa çıktı:
       render'ı doğru olan bir bileşen, onu BESLEYEN durum bayatladığı için
       hiç görünmeyebilir. Kullanıcı aynı şeyi ikinci kez bildiriyorsa
       kapatmadan önce zinciri UÇTAN UCA koştur.
     - Doğrulama: `npm run lint` + `npm run build` temiz, Playwright **3/3**
       (yeni kalıcı regresyon testiyle); `flutter analyze` temiz, tam takım
       **424/424**.
     - **CİHAZDA DOĞRULANDI (14 Ağustos 2026, kullanıcı): "her şey normal".**
       Kontrol maddesi uçak modunun Kontrol Merkezi'nden — yani uygulamadan
       ÇIKARAK — açılmasını istiyor, ki kök sebep tam oydu. **Bu tur, Parça
       97'nin göstergesini ve Parça 98'in öne-dönüş kancasını AYNI ANDA
       kapatıyor; portun resume kancası için de tek kanıt bu** (yukarıdaki
       "testsiz kaldı" notunun karşılığı: test yoksa cihaz turu opsiyonel
       değildir).

   - ✅ **Parça 99 — port artık hangi istemci olduğunu SÖYLÜYOR: platform
     telemetrisi (14 Ağustos 2026, yeni `util/platform.dart`,
     `game_record.dart`, `online_games_api.dart`, `online_game_screen.dart`):**
     Kullanıcı isteği ("Platform column'u da ekle"). Sunucu tarafı ve web
     yarısı aynı gün eklendi (bkz. kök `CLAUDE.md`); bu parça portun yarısı.
     - **Neden ŞİMDİ:** `games` satırında istemciyi söyleyen hiçbir alan
       yoktu ve bu alan geriye dönük DOLDURULAMAZ — port yayına çıktıktan
       sonra eklenirse lansmanın ilk günleri sonsuza dek ölçülemez kalırdı.
       Port yazmazsa satırlar boş platformla gider, yani bu değişikliğin
       varlık sebebi tam olarak portun kendisi.
     - **`dart:io`'nun `Platform.isIOS`'ü KULLANILMADI** — `dart:io` web
       derlemesinde yok, import etmek `flutter build web`i kırardı (portun
       test ortamı `mobile-build.yml`de gerçekten derleniyor). `kIsWeb` +
       `defaultTargetPlatform` her hedefte çalışıyor.
     - **Bilinmeyen hedefte `null`, uydurma değer DEĞİL:** masaüstü
       (macOS/Windows/Linux) yayınlanmıyor ama sunucudaki check kısıtında
       olmayan bir değer yollamak `games` insert'ini DÜŞÜRÜR — yani bir
       telemetri alanı yüzünden oyun KAYDI (skor, k-lig, hamle dökümü)
       kaybolur. Sütun nullable, `null` satırı sorunsuz kaydediyor.
     - **Yerel taraf `NewGameRecord`ta bir ALAN, `toJson`da hesaplanan bir
       değer DEĞİL:** kayıt çevrimdışı kuyruğa serileşip günler sonra
       gönderilebiliyor ve satır oyunun GERÇEKTEN oynandığı istemciyi
       anlatmalı (web de kuyruğa aynı şekilde yazıyor). Alan eklenmeden
       önce kuyruğa girmiş kayıtlarda `null` — `fromJson` bunu tolere
       ediyor, kayıt yine gönderiliyor.
     - **Canlı taraf AYRI bir tabloya yazıyor** (`online_game_clients`):
       Canlı'da `games` satırını SUNUCU yazdığından istemcinin kim olduğu
       oraya hiç ulaşmıyor. `reportPlatform` oyun ekranının `initState`inde
       BİR KEZ, `_refresh()` döngüsünün DIŞINDA kendi satırında çağrılıyor
       — telemetri, oyun durumu senkronuyla aynı kod yolunu paylaşmamalı
       (hatası oyunu etkilemesin) ve her Realtime olayında tekrar yazmanın
       anlamı yok (upsert olduğundan mükerrer çağrı zararsız, sadece
       gereksiz). Hata TAMAMEN yutuluyor; sunucu da yetkisiz/geçersiz
       girdide sessizce no-op dönüyor (canlıda doğrulandı).
     - **`submit_move`'a parametre EKLENMEDİ** — projenin en kritik RPC'si,
       lansman öncesi imza değişikliğinin riski kazancından büyük; gerekçe
       ve ölçüm kök `CLAUDE.md`'de.
     - **Değer kümesi testle bağlandı:** `test/client_platform_parity_test.dart`
       migration SQL'ini OKUYUP `kClientPlatforms` ile karşılaştırıyor
       (`color_tokens_test`/`rank_tiers_parity_test` deseni) — kısıt üç
       yerde geçtiğinden üçü de ayrı ayrı sayılıyor, ve `currentPlatform`ın
       her hedefte kümede (ya da null) kaldığı ayrıca doğrulanıyor.
     - **Fikstür `platform` HARİÇ karşılaştırılıyor:** `web_game_record.json`
       iki istemcinin AYNI satırı ürettiğini kanıtlar, ama bu alan tanımı
       gereği farklı olmak ZORUNDA. Test onu ayırıp kalan 20 sütunu bayt
       bayt karşılaştırıyor ve ayrıca "iki taraf da yazıyor + değerler
       kümede + BİRBİRİNDEN farklı" diyor — sonuncusu olmadan port web'in
       sabitini kopyalasa test geçerdi. Fikstürün `record` yarısı web'in
       ÜRETİM kodu koşturularak yeniden üretildi (Parça 65'in cerrahi
       yöntemi; anlamsal diff yalnızca iki `"platform": "web"` satırı).
     - **Negatif eş, İKİ AYRI kanıt:** `kClientPlatforms`e sahte bir değer
       eklenince parite testi GERÇEKTEN düştü (`does not contain 'desktop'`);
       `NewGameRecord.toJson`dan `platform` çıkarılınca iki fikstür testi de
       GERÇEKTEN düştü (`port platformu yazmıyor — lansman ölçülemez kalır`).
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 427/427
       yeşil** (424'ten +3). `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (web yarısı + migration + admin
       paneli + Gizlilik Politikası) → kök `CLAUDE.md`/`README.md`/
       `TESTING.md` aynı commit'te güncellendi (Kontrol Listesi madde 1).
     - **Gizlilik metni İKİ tarafta birden güncellendi** — yeni bir kişisel
       veri toplandığında `PrivacyModal`/`legal_modals.dart` güncellenmek
       ZORUNDA (proje kuralı) ve `legal_text_test.dart` "Son güncelleme"
       tarihlerini karşılaştırdığından port bayat kalsa test düşerdi.
     - **Doğrulama sınırı:** gerçek bir cihazdan oynanan oyunun `ios`/
       `android` satırına düştüğü ancak cihazda görülebilir —
       `mobile/TESTING.md` bölüm 5'e ve kök `TESTING.md` 9.8'e maddeler
       eklendi.

   - ✅ **Parça 100 — kırmızı nokta artık mute'tan BAĞIMSIZ: susturulan
     kişinin mesajı da rozeti artırır, yalnızca popup bastırılır (15 Ağustos
     2026, `online_game_screen.dart`, `board_widget.dart` + web
     `OnlineGameScreen.tsx`):** Bölüm 11'in mesajlaşma turunda kullanıcı önce
     "T2 sessizdeymiş, o yüzden mesaj çıkmadı" dedi, sonra doğru soruyu
     sordu ("mute etmiş kişide, mute edilmiş kişiden gelen mesaj kırmızı
     nokta çıkarmıyor ama diğerlerinden gelirse çıkıyor mu?") ve ardından
     ürün kararını kendisi verdi.
     - **Bu bir hata düzeltmesi DEĞİL, bilinçli bir davranış değişikliği.**
       Eski davranış (mute ikisini birden bastırır) web'de de portta da
       tutarlıydı ve gerekçesi yazılıydı. Kullanıcının gerekçesi daha
       güçlü çıktı: taciz vektörü POPUP; nokta rahatsız etmiyor, üstelik
       susturulan kişinin ne yazdığını görmek şikayet etmenin ön koşulu
       olabilir. Tam alıntı ve üç ayaklı gerekçe kök `CLAUDE.md`'de
       ("Oyun İçi Mesajlaşma — Faz 2", ilk madde).
     - **İKİ yerde birden değişti, tek yer YETMEZDİ:** ilk yüklemedeki
       tohumlama (`_seedInitialUnread`) ve Realtime dalı (`_onChatMessage`).
       Yalnızca birini değiştirmek, uygulama KAPALIYKEN gelen mesajlarla
       AÇIKKEN gelenler arasında sessiz bir tutarsızlık üretirdi — aynı
       kullanıcı aynı mesaj için bir gelişte nokta görür, ötekinde görmezdi.
     - **`mutes` parametresi `_seedInitialUnread`'den KALDIRILDI**, imzada
       ölü bir argüman olarak bırakılmadı; çağıran onu zaten `_chatState`e
       (rozetler + popup kapısı) yüklemeye devam ediyor.
     - **Mevcut testler bu değişikliği YAKALAYAMAZDI ve bu kayda değer:**
       iki mute testi de yalnızca popup'ın açılMAdığını ölçüyordu; rozete
       hiç bakmıyorlardı. Yani filtre yanlışlıkla "sohbet geneli sessize
       alma"ya dönüşse bile takım yeşil kalırdı. Rozet için üretim koduna
       bir `ValueKey('chat-unread-dot')` eklendi (projedeki `like-count-*`/
       `moves-*` deseni) ve iki test de artık noktayı ölçüyor: susturulan
       gönderende **popup YOK + nokta VAR**, susturulmamışta **ikisi de
       VAR** (ikincisi olmadan "hiç nokta çıkmıyor" gibi ters bir regresyon
       da geçerdi).
     - **Negatif eş:** `online_game_screen.dart` `git stash`lenince mute
       testi GERÇEKTEN düştü (`chat-unread-dot` bulunamadı), geri konunca
       yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 427/427
       yeşil** (yeni test yok — mevcut iki teste assertion eklendi). Web
       `npm run lint` + `npm run build` + `npm run test` (Playwright 3/3)
       temiz. `kelimeki_core`'a hiç dokunulmadı.
     - **`mobile/` DIŞINDA dosya değişti** (web yarısı aynı gün, aynı
       dalda) → kök `CLAUDE.md` + iki `TESTING.md` aynı commit'te
       güncellendi (Parça Bitirme Kontrol Listesi madde 1).
     - ~~**Doğrulama sınırı:** iki gerçek hesapla cihazda teyit bekleniyor —
       özellikle 4 kişilik bir oyunda "susturulmamış gönderen hâlâ popup
       açıyor" kontrolü~~ → **16 Ağustos 2026'da cihazda KOŞULDU ve GEÇTİ**,
       4 kişilik kontrol dahil. Yani kararın iki yarısı da gerçek uçla
       kanıtlandı: susturulanda popup YOK/rozet VAR, susturulmayanda İKİSİ
       de var — filtrenin yanlışlıkla "sohbet geneli sessize alma"ya
       dönüşmediğinin tek gerçek kanıtı bu ikinci yarı (2 kişilikte
       görünmez). Maddeler `mobile/TESTING.md` bölüm 11 ve kök
       `TESTING.md` bölüm 3'te.

   - ✅ **Parça 101 — "Yapay Zeka ile" sekme rozeti porta hiç girmemişti
     (15 Ağustos 2026, `setup_screen.dart`):** Kullanıcı bölüm 11 turunda
     ekran görüntüsüyle bildirdi: *"YZ bekleyen 2 oyun olmasına ve devam
     edenlerde 2 yazmasına rağmen ana tabda sayı yok."*
     - **Web kaynağı önce okundu (kuralın ilk adımı) ve kullanıcıyı
       doğruladı:** `Setup.tsx`'in OYUN TİPİ satırı İKİ sekmeye de rozet
       veriyor — `{label:'Yapay Zeka ile', badge: localSaveCount}` ve
       `{label:'Arkadaşınla', badge: liveActionCount}`. Port yalnızca
       ikincisini taşımıştı; `YAPAY ZEKA İLE` butonuna `badge` hiç
       geçilmiyordu, `_ChoiceButton` de `badge<=0` iken Stack'i hiç
       kurmadığından rozet TAMAMEN yoktu (soluk/sıfır değil, yok).
     - **Formül web'den birebir:** `_localSaveCount` = girişliyse
       `_cloudSaves?.length ?? 0`, misafirse `_savedState != null ? 1 : 0`
       (web `user ? (cloudSaves?.length ?? 0) : savedGame ? 1 : 0`).
     - **Bu, `CountBadge`'in "toplama kuralı"nın somut örneği** (kök
       `CLAUDE.md`): kapsayan sekmenin rozeti kapsananların toplamı olmak
       zorunda. Burada "Devam Edenler" alt sekmesi 2 gösterirken onu
       KAPSAYAN "Yapay Zeka ile" hiçbir şey göstermiyordu — kullanıcının
       gördüğü tutarsızlık tam olarak zincirin kopmasıydı.
     - **Test İKİ rozeti birden ölçüyor**, yalnızca yenisini değil:
       `badgeOf('DEVAM EDENLER') == badgeOf('YAPAY ZEKA İLE') == 2`.
       Yalnızca üsttekine bakan bir test, ikisi ayrışsa da geçerdi — asıl
       korunması gereken değişmez sayının kendisi değil EŞİTLİĞİ.
     - **Negatif eş:** `setup_screen.dart` `git stash`lenince test
       GERÇEKTEN kullanıcının semptomunu üretti (`Expected: <2> / Actual:
       <null>` — yani rozet hiç yok), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       428/428 yeşil** (427'den +1). Web'e hiç dokunulmadı (orada rozet
       zaten doğru); `kelimeki_core`'a dokunulmadı.
     - **Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor —
       `mobile/TESTING.md` bölüm 11'e madde eklendi.

   - ✅ **Parça 102 — SEKİZ diyalog düz `AlertDialog`'du: site diliyle hiç
     alakası yoktu (15 Ağustos 2026, yeni `ui/game/dialog_shell.dart` +
     `ui/game/{game_screen,invasion_confirm}.dart`,
     `ui/live/online_game_screen.dart`, `ui/friends/friends_modal.dart`):**
     Kullanıcı bölüm 11'in mesajlaşma turunda yeni-mesaj popup'ının ekran
     görüntüsünü gönderip *"çıkan popup bizim site genelinde kullandığımız
     tasarımlarla alakası yok. Başka uyarı pencerelerinde de benzer durumu
     gördüm. App'deki tüm uyarı pencerelerini tarayıp web ile uyumlu hale
     getir"* dedi.
     - **Aynı turda bildirilen İKİNCİ şey bir hata DEĞİLDİ ve kaynaktan
       doğrulandı:** *"popup çıktığı için kırmızı nokta çıkmıyor, okumuş
       kabul ediyor."* Gözlem doğru, davranış bilinçli ve web'de de aynı —
       `closeMessagePopup` (web) ve `_showNewMessagePopup`'ın dönüşü (port)
       popup kapanınca mesajı okundu işaretliyor; web'de gerekçesi yorumda
       yazılı (*"popup'taki mesaj zaten doğrudan ekranda gösterildiğinden…
       aksi halde kırmızı nokta popup kapatıldıktan sonra da kalıcı
       kalıyordu"*). Nokta mesaj geldiği an çıkıyor, yalnızca popup'ın
       altında kalıyor. Düzeltilecek bir şey yok.
     - **Web'de İKİ ayrı kabuk var ve port yalnızca birini taşımıştı:**
       `Modal.tsx` (başlıklı, ✕'li, ayraçlı 360px pencere → `KModal`) ve
       `App.tsx`/`OnlineGameScreen.tsx`/`FriendsModal.tsx`'in satır içi
       `fixed inset-0 z-[200]` onay popup'ları (384px kart). **Üç web
       dosyası da BİREBİR AYNI sınıfları taşıyor**, yani tek bir kanonik
       kart var — port onu hiç port etmemiş, sekiz yerde ham `AlertDialog`
       kullanmıştı (Material varsayılanı: beyaz kart, Material tipografisi,
       mavi metin butonları).
     - **Değerler ölçüldü, tahmin edilmedi** (Parça 33'ün dersi): derlenmiş
       `dist/assets/*.css` gerçek DOM'a uygulanıp Chromium'da okundu — kart
       384/24/16 + `#B8C2D1` + `0 20px 45px rgba(15,23,42,.5)`, başlık
       16/700, gövde 14/1.625, boşluklar 16 ve 20, buton 12/tracking 1/
       dikey 10/yükseklik 38. **İlk harness sessizce yedeğe düştü** (CSS
       yolu `file://`de çözülmedi, her şey tarayıcı varsayılanı çıktı) —
       Parça 77'nin aynı tuzağı; HTTP'den servis edilince düzeldi.
     - **`friends_modal.dart` kartı elle çizmişti ve O DA sapmıştı**
       (başlık 15, gövde 13/1.5, buton 11, kart gölgesi yok) — yani desen
       kod tabanında vardı ama tek kaynak değildi. Şimdi on çağrı yerinin
       (8 AlertDialog + bu 2) hepsi `dialog_shell.dart`tan geçiyor.
     - **İki YAPISAL bulgu, ikisi de yeni testin ÖLÇÜMÜYLE çıktı:**
       1. **`Dialog`ın varsayılan `insetPadding`i yanlardan 40**, web'in
          kaplaması `px-4` = 16. Dar ekranda fark gerçek: 420px'lik bir
          telefonda web kartı 384 çizerken port 340'a sıkışıyordu.
       2. **`DecoratedBox`, `Decoration.padding`i ONURLANDIRMIYOR** —
          yalnızca `Container` ediyor. Çerçeve içeriğin üstüne binip içerik
          334 yerine 336 oluyordu; web `border-box` olduğundan 334 doğru.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** yeni
       `dialog_shell_test.dart` (5 test + 1 ekran görüntüsü) kart
       geometrisini/tipografisini/buton sırasını ölçüyor VE `lib/` altında
       ham `AlertDialog` kalmadığını tarıyor (`color_tokens_test`/
       `theme_test`in kaynak tarayan deseni — bu olmadan yeni bir
       AlertDialog sessizce girer). `invasion_confirm.dart`'ta `KDialogCard`
       geçici olarak `AlertDialog`a çevrilince tarama GERÇEKTEN dosyayı adıyla
       işaret ederek düştü; `insetPadding` satırı kaldırılınca buton
       genişliği GERÇEKTEN 334 → 290 düştü. İkisi de geri konunca yeşile
       döndü.
     - **Mevcut testlerde çıkan tuzak:** diyalog butonları artık Material
       değil `NeoButton`, ve alt şeritte de AYNI etiketli NeoButton'lar var
       (PAS GEÇ / TEKRAR OYNA) — `find.widgetWithText(NeoButton, 'PAS GEÇ')`
       iki eşleşme veriyor. Diyalog dokunuşları artık
       `find.descendant(of: find.byType(KDialogCard), …)` ile kapsamlı;
       alt şerit butonlarını da saran ilk (fazla geniş) regex düzeltildi.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım 436/436
       yeşil** (428'den +8). `kelimeki_core`'a hiç dokunulmadı; web'e hiç
       dokunulmadı (yalnızca ölçüm kaynağı olarak okundu).
     - ~~**Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor.~~
       Ekran görüntüsü `build/screenshots/dialog_message_popup.png` olarak
       üretilip gözle incelendi (panel zemin, düşen gölge, accent CEVAP VER
       + nötr KAPAT) → **16 Ağustos 2026'da cihazda KOŞULDU ve GEÇTİ**
       (`mobile/TESTING.md` bölüm 11, "Uyarı pencerelerinin tasarımı" —
       yeni mesaj popup'ı, sohbet tanıtımı, "Pas Geçiyorsun!", "Tekrar
       Oyna", "Sınır İhlali!" ve arkadaşlık onaylarının HEPSİ tek turda
       kontrol edildi). Sekiz ham `AlertDialog`ın hiçbiri geride kalmamış.

   - ✅ **Parça 103 — sayısız kırmızı noktalar `CountBadge`e çevrildi
     (16 Ağustos 2026, `board_widget.dart` + `k_avatar.dart` + web
     `Board.tsx`/`Avatar.tsx`):** Kullanıcı *"insanlar mesajlarda çıkan
     kırmızı noktayı farketmiyorlar. Onu da her yerde kullandığımız sayılı
     olana döndürmek nasıl olur? Bir de avatardakini"* dedi.
     - **Bilinçli bir kararın tersine çevrilmesi, hata düzeltmesi DEĞİL.**
       İki gösterge de kök `CLAUDE.md`'de "var/yok bilgisi taşıyor, adet
       değil" gerekçesiyle açıkça `CountBadge` DIŞINDA tutulmuştu ve o
       gerekçe hâlâ tutarlı — ama fark edilmeyen bir gösterge, doğru
       sınıflandırılmış olsa da işe yaramıyor. Eski gerekçe silinmedi,
       tarihiyle birlikte "tersine çevrildi" olarak duruyor.
     - **Sayı zaten vardı, boolean'a indiriliyordu:** `_chatState.unreadCount`
       ve `_incomingRequests`. Prop'lar `BoardWidget.unreadMessageCount` ve
       `KAvatar.badgeCount` oldu (`hasUnreadMessage`/`dot` kalktı).
     - **Web ile kasıtlı fark:** web avatar rozeti arkadaşlık isteği +
       admin bekleyen işinin TOPLAMI; portta admin paneli olmadığından
       (bilinçli, "Üst Düzey Kararlar" #3) tek kaynak arkadaşlık isteği.
     - **Konum web'de ÖLÇÜLEREK seçildi, ikisine birden uygulandı:** rozet
       satır içi OLAMAZ — şeride ~20px eklerdi ve 360px'lik bir telefonda
       "Mesajlaşma" ile "Nasıl Oynanır?" arasında yalnızca 7.8px boşluk var.
       `top/right: -4` ile rozetin sağ kenarı en dar durumda 3.8px pay
       bırakıyor (iki haneli sayıda da — rozet sağdan sabitli). Beyaz halka
       (web `ring-2 ring-panel`) rozeti altındaki mavi etiketten ayırıyor.
     - **Test anahtarı yeniden adlandırıldı** (`chat-unread-dot` →
       `chat-unread-badge`) ve iki mute testinden biri artık SAYIYI ölçüyor:
       ikinci bir mesaj gelince rozet `1`→`2` olmalı. Parça 100'de eklenen
       "var/yok" kontrolü tek başına, sayacın hiç artmadığı bir regresyonu
       yakalayamazdı.
     - **Doğrulama sınırı ve SONUCU — bu sınır AYNI GÜN gerçekleşti:** bu
       oturumun konteynerinde Flutter SDK YOK (`flutter: command not
       found`), yani `flutter analyze`/`flutter test` KOŞULAMADI. Web yarısı
       tam doğrulandı (`npm run lint`, `npm run build`, Playwright 3/3,
       derlenmiş CSS + Chromium ölçümü) ama **Dart yarısı `main`'e merge
       edilince CI'da DÜŞTÜ**: `mobile-build.yml`, `b2ca8fa`ta 434 geçti
       **2 düştü**. `flutter analyze` temizdi, `kelimeki_core`/Android/iOS
       job'ları geçti — düşen yalnızca iki widget testiydi ve ikisi de
       üretim kodu hatası DEĞİL, bu değişikliğin test beklentilerine
       yansıtılmamış olmasıydı:
       - `friends_test`: avatar da artık sayı gösterdiğinden `"2"` İKİ yerde
         (menü satırı + avatar) → `findsOneWidget` düştü. Düzeltme
         `findsNWidgets(2)` ile geçiştirilMEdi; avatar rozeti `KAvatar` alt
         ağacında AYRICA ölçülüyor, böylece hangi "2"nin hangisi olduğu
         testten okunuyor ve rozet yanlış yere düşerse test yine yakalar.
       - `online_game_chat_test`: sayacın `1→2` arttığını ölçmek için aynı
         susturulmuş gönderenden ikinci mesaj eklenmişti, dolayısıyla
         thread'de iki 🚫 rozeti var → `findsNWidgets(2)`.
       **Ders:** bir görsel göstergeyi "var/yok"tan "sayı"ya çevirmek, o
       göstergeyi ölçen HER testin beklentisini de değiştirir — aynı sayı
       artık birden fazla yerde yazıyor olabilir. Flutter koşulamayan bir
       oturumda bu ancak CI'da görülür; PR'ı merge etmeden CI'ı beklemek
       (ya da en azından merge sonrası run'ı KONTROL ETMEK) şart.
       Düzeltme `60d2113` ile merge edildi, dört job da yeşil.
     - **16 Ağustos 2026 — İKİ PLATFORM DA gerçek cihazda teyit edildi.**
       Web: avatar rozetinin toplamı, oyun ekranında kırpılmaması, sohbet
       rozetinin sayması ve "Nasıl Oynanır?" ile çakışmaması. Mobil
       (`mobile/TESTING.md` bölüm 10 + 11): arkadaşlık isteğinde avatarda
       nokta değil SAYI, menüdeki "Arkadaşlar" rozetiyle aynı sayı; sohbet
       kapalıyken gelen mesajda sayaç, ikinci mesajda **2**; sohbet açılınca
       sıfırlanması ve uygulama kapat/aç sonrası geri gelmemesi; susturulmuş
       gönderende popup YOK ama rozet ARTIYOR.

   - ✅ **Parça 104 — yeni mesaj popup'ı ZEMİNE dokununca kapanıyordu; web'de
     zemin tıklanamaz (16 Ağustos 2026, `online_game_screen.dart`):**
     **Bildirilen bir hata DEĞİL — bir yanlış anlamanın yan ürünü, kayda
     öyle geçsin.** Kullanıcı iki cihazlı mesajlaşma turunu koşup *"Popup
     geldi ve gitti"* dedi; ben bunu "kendiliğinden kayboldu" diye okudum,
     oysa "iki taraf da mesaj attı ve göründü" demekti — yani madde
     GEÇMİŞTİ. Araştırma yine de gerçek bir web↔port sapması buldu ve
     düzeltildi; ama bu bölümü bir kullanıcı şikayeti sanan bir sonraki
     oturum yanlış bir izin peşine düşer.
     - **Önce "otomatik kapanma" arandı ve KOD ÜZERİNDEN ELENDİ:**
       `_showNewMessagePopup` içinde ne `Timer` ne `Future.delayed` var;
       `_fetchChat`/`_seedInitialUnread` `newMessagePopup`a HİÇ dokunmuyor
       (yalnızca `messages`/`unreadCount`), yani ön plana dönüşteki
       tazeleme (Parça 95) dialog route'unu kapatamaz; `Navigator.pop`
       çağıran altı yerin hiçbiri bu popup'ın yolunda değil. Yani mesaj
       "kendiliğinden" gitmiyor.
     - **Geriye kalan TEK buton-dışı çıkış yolu barrier'dı ve o gerçek bir
       web sapması:** web'de popup `fixed inset-0 z-[200]` bir kapta ve o
       kabın **hiç `onClick`i yok** (`OnlineGameScreen.tsx:1482`) — kapatma
       yalnızca ✕ / CEVAP VER / KAPAT. Flutter'ın `showDialog`ı ise
       VARSAYILAN olarak `barrierDismissible: true`, yani ekranın herhangi
       bir yerine (tahtaya, başlığa) dokunmak popup'ı kapatıyordu. Kullanıcı
       için bu, mesajın kendiliğinden kaybolması gibi görünür — üstelik
       kapanış `unreadCount: 0` + `markChatRead` de yaptığından geriye
       rozet bile kalmıyor, yani mesaj hiç görünmemiş gibi oluyor.
       `barrierDismissible: false` eklendi.
     - **Parça 85'in "kapana kısılma" gerekçesi burada GEÇERSİZ ve bu
       bilinçli:** orada (ActionSheet) zemin dokunuşu aksiyonsuz çıkışın
       TEK yoluydu, o yüzden bilerek açık bırakılmıştı; burada iki görünür
       buton var ve KAPAT web'in ✕'iyle aynı işi yapıyor. Web'deki ✕ porta
       EKLENMEDİ — `KDialogCard`'ın kapatma ikonu yok ve KAPAT onunla
       fonksiyonel olarak özdeş.
     - **Test — mevcut popup testine eklendi:** zemine (`tapAt(Offset(5,5))`)
       dokunulunca popup'ın DURDUĞU doğrulanıyor. Düzeltme olmadan bu
       assertion kullanıcının tarif ettiği semptomu birebir üretir (popup ve
       mesaj ekrandan kaybolur).
     - **Doğrulama sınırı — Parça 103'ün dersi HÂLÂ geçerli:** bu oturumun
       konteynerinde Flutter SDK YOK (`flutter: command not found`), yani
       `flutter analyze`/`flutter test` KOŞULAMADI; kanıt CI'ın
       (`mobile-build.yml`) yeşile dönmesi. **Cihazda 16 Ağustos 2026'da
       KOŞULDU ve GEÇTİ** — popup ne kendiliğinden kapandı ne de zemine
       (tahta/başlık) dokununca; tek kapanma yolu CEVAP VER / KAPAT.
       Bildirilen bir hata değildi, kod incelemesinde bulunmuştu; yine de
       gerçek bir sapmaydı ve artık uçtan uca doğrulandı.
     - **Kapsam dışı (bilinçli):** `showKConfirm`/`showKInfo` hâlâ
       varsayılan `barrierDismissible: true` — onlar kullanıcının KENDİ
       başlattığı onay/bilgi kartları ve zemin dokunuşu orada "vazgeç"e
       eşdeğer; zararsız. Zararlı olan, kullanıcının istemediği bir anda
       ÜSTÜNE gelen bir bildirimin kazara kapanmasıydı.
     - **Ders — bir test turu raporunu "hata bildirimi" diye okumadan önce
       maddenin BEKLENEN sonucunu oku.** `mobile/TESTING.md` bölüm 11'in
       ilgili maddesi zaten "iki taraf da mesaj atabilmeli" diyordu; kısa
       bir "geldi ve gitti" cevabını o maddeye göre yorumlamak yerine
       kendi hipotezime göre yorumladım ve kullanıcıya "bu hata" dedim.
       Bu, Parça 36'nın dersinin (bir isteğin kapsamını KENDİN daraltma)
       simetriği: **kullanıcının cevabına kendin bir şikayet EKLEME.**
       Bedeli burada küçüktü (tek satırlık, gerçek bir sapmayı kapatan bir
       değişiklik) ama aynı refleks bir sonraki turda çalışan bir şeyi
       "düzeltmeye" kalkabilir.

   - ✅ **Parça 105 — BAYAT bir liste satırından devam etmek offline oynanan
     hamleleri KALICI olarak siliyordu (16 Ağustos 2026,
     `cloud_save_repo.dart`, `setup_screen.dart`):** Kullanıcı Blok 7
     turunda bildirdi: *"uçak modunda devam eden 4 kişilik yz oyunda
     yaptığım hamleyi geri çıkıp girince hatırlamadı. 2 kişilik yeni oyun
     açtım, oynadım, geri çıkıp tekrar girdiğimde sorun yoktu onda. Ama 4
     kişilik oyunda … aynı sonuç. İlk haline geri dönüyor."*
     - **Kalıcılık katmanı SAĞLAMDI ve bunu doğrulamak teşhisin yarısıydı:**
       `origin/main` = kullanıcının test ettiği derleme (`1c0bd39`) ve
       kalıcılık dosyalarında fark yok; `_offlineList`in "ayna KOŞULSUZ
       kazanır" kuralı ve aynı id'nin hem önbellekte hem aynada olduğu
       senaryo `cloud_save_test.dart`ta ZATEN testli ve geçiyordu. Yani
       hata repo katmanında değil, onu ÇAĞIRAN akıştaydı.
     - **Kök sebep — Setup listesi bir ANLIK GÖRÜNTÜ, ama `_resumeCloudSave`
       ona sorgusuz güveniyordu.** Oyundan çıkışta liste `_syncCloud` ile
       tazeleniyor; o zincir `flushMirrored` + `list()` yani İKİ ağ
       çağrısı, ve uçak modunda bunlar hemen düşmüyor, zaman aşımına
       oynuyor. O pencerede kullanıcı aynı satıra tekrar dokunursa oyun
       PRE-GAME state'le açılıyor — üstelik `CloudGameSession` kurulur
       kurulmaz mevcut state'i yazdığından (kurucudaki `_onChange()`) o
       bayat state 600 ms sonra AYNAYI EZİYOR ve offline hamleler
       kurtarılamaz biçimde siliniyordu. Belirti bire bir "ilk haline
       geri dönüyor".
     - **Asimetriyi de tam olarak bu açıklıyor** (ve teşhisi doğrulayan
       şey buydu): YENİ açılan 2 kişilik oyunun satırı çıkıştan ÖNCEKİ
       listede YOKTU, yani kullanıcı satır belirene kadar — yani
       `_syncCloud` bitene kadar — beklemek ZORUNDAYDI ve o noktada liste
       tazeydi. Devam eden oyunun satırı ise zaten ekrandaydı; hemen
       dokunmak mümkündü. Yani hata "4 kişilik"e değil "listede ZATEN
       duran satıra" bağlı.
     - **Düzeltme — `CloudSaveRepo.newerPendingState(id, userId,
       knownUpdatedAtMs)`:** `_resumeCloudSave` açmadan hemen önce "bu id
       için aynada daha yeni bir state var mı?" diye soruyor ve varsa onu
       restore ediyor. Karşılaştırma `list()`in online dalındaki kuralın
       AYNISI (`savedAtMs > updatedAtMs`) — bilerek: taze bir listede
       satır zaten aynadan geldiğinden damgalar eşit olur ve null döner
       (gereksiz yeniden yükleme yok), başka bir cihazın yazdığı DAHA YENİ
       sunucu satırı da eski bir aynayla ezilmez. Depo okunamazsa
       elimizdekiyle devam edilir — oyunu açmayı engellemiyor.
     - **`CloudGameSession`'ın kurucudaki ilk yazması BİLEREK DURUYOR.**
       Onu "resumeSaveId varsa atla" diye kapatmak da hasarı azaltırdı ama
       yanlış katman olurdu: web'in autosave effect'i de RESUME_SAVED
       sonrası yazıyor (satırın `updated_at`i tazelenip 7 günlük terk
       süresi geri itiliyor). Doğru düzeltme, yazılan state'in TAZE
       olmasını garanti etmek.
     - **Teşhis satırının belirsizliği de kapatıldı** — bu tur onun
       yüzünden bir el kaybetti: kullanıcı `depo ok, bekleyen 0` bildirdi
       ama `pendingMirrorCount` depo erişilemediğinde de **0** dönüyordu,
       yani o "0" hiçbir şey kanıtlamıyordu. Artık ulaşılamazsa **-1**
       dönüyor ve teşhis satırı `bekleyen ?` yazıyor.
     - **Test — negatif eş MEKANİZMAYI KANITLAYAN ayrı bir test olarak:**
       `cloud_save_test.dart`a üç test (bayat satırdan devam hamleleri
       silmiyor; **MEKANİZMA testi** — bayat state ile devam edilirse ayna
       GERÇEKTEN eziliyor, yani guard cargo-cult değil; taze listede
       `newerPendingState` null dönüyor) ve `setup_cloud_test.dart`a bir
       KABLO testi (`FresherStateRepo` — Setup gerçekten soruyor mu ve
       dönen state'i kullanıyor mu; Parça 86'nın dersi: sözleşmeyi
       enjekte edilebilir sınırın ÜSTÜNDE test etmek altındaki iletimi
       kanıtlamaz). `pendingMirrorCount`ın -1'i ile gerçek sayıyı dönen
       yolu karşıt eş olarak aynı dosyada duruyor.
     - **Doğrulama — bu oturumda Flutter YOK** (`flutter: command not
       found`, Parça 103/104'ün aynı sınırı): `flutter analyze`/
       `flutter test` KOŞULAMADI, kanıt CI oldu — PR #274'te dördü de
       yeşil (analiz + **440 test**, 436'dan +4; Android APK; iOS
       imzasız; web derlemesi). Merge sha `6b71eaa`.
     - **CİHAZDA DOĞRULANDI (16 Ağustos 2026, kullanıcı):** uçak modunda
       var olan bir oyuna girip hamle yapıp çıkıp hemen tekrar girildiğinde
       hamle DURDU — *"Kaydetti bu sefer. Çalışıyor."* Yani düzeltme
       yalnızca repo katmanında değil gerçek akışta da çalışıyor;
       `mobile/TESTING.md` bölüm 8'deki madde ilerideki bir regresyon için
       duruyor (**hızlı** koşulmalı — bekleyerek koşulursa liste tazelenir
       ve senaryo hiç oluşmaz).
     - **Ders — "repo katmanı testli ve geçiyor" bir SONUÇ değil bir
       ELEME:** doğru soru "bu veriyi kim ne zaman OKUYOR ve okuduğu şey ne
       kadar taze?" idi. Bu projenin kalıcılık katmanı bir yıl boyunca
       "yazma yolu" üzerinden düşünüldü (ayna, önbellek, silme kuyruğu);
       kaybın gerçekleştiği yer ise OKUMA yoluydu — ekranda duran bir
       anlık görüntü. Bir ekran, elindeki veriyle YAZMA başlatıyorsa o
       verinin tazeliği bir varsayım değil, kontrol edilmesi gereken bir
       ön koşuldur.

   - ✅ **Parça 106 — tahta filigranları KUTUYA sığdırılıyordu (web'de punto
     ekran genişliğine bağlı) + fontu da yanlıştı; ayrıca web'in avatar
     hizası bozuktu (17 Ağustos 2026, `board_widget.dart` + web
     `UserMenu.tsx`):** Blok 6'nın (görsel yan yana) kalan iki maddesi.
     Kullanıcı iki ekranı yan yana koyup köşe rakamlarının ve X2/X3
     filigranlarının "farklı boyut/tasarımda" olduğunu, ayrıca web'de
     avatarın skor kutularının merkezine göre yukarıda durduğunu bildirdi.
     - **(a) Filigranlar — üç ayrı sapma, ikisi gözle görünmeyen türden.**
       Web (`Board.tsx`) puntoyu kutuya SIĞDIRMIYOR, `clamp` ile ekran
       genişliğine bağlıyor: köşe `clamp(80px,32vw,220px)`, X2
       `clamp(60px,24vw,165px)`, X3 `clamp(7px,1.9vw,12px)`; ilk ikisi
       `font-mono` + `leading-none`. Port ise `FittedBox` kullanıyordu
       (punto kutunun oranından çıkıyor) ve **köşe/X2 için `fontFamily` hiç
       vermiyordu** — yani yazı tipi temanın SpaceGrotesk'ine düşüyordu.
       Kullanıcının "tasarım da farklı" demesinin sebebi buydu; punto farkı
       ise yön yön değişiyordu: köşe rakamı web'den KÜÇÜK (kutu 4/13 ×
       satır yüksekliği), X2 ve özellikle X3 ise BÜYÜK — X3 48px'lik bir
       hücreyi doldurduğundan ~37px, web'in azami 12px'inin üç katı.
     - **Düzeltme sihirli sayı içermiyor:** üç `clamp` de `fluidSize` ile
       birebir taşındı (Parça 24'ün `tile_widget.dart`'ta kullandığı aynı
       desen — `vw` girdisi `MediaQuery.sizeOf(context).width`), `fontFamily:
       'SpaceMono'` ve `height: 1` (=`leading-none`) eklendi.
     - **`Center` + `OverflowBox` ŞART:** köşe rakamının satır kutusu
       (220) kendi 4/13'lük alanından (680px'lik tahtada ~203) BÜYÜK ve
       web'de de taşıyor; `FractionallySizedBox` çocuğuna TIGHT kısıt
       verdiğinden araya konmazsa yazı ortalanmak yerine kutunun üstünden
       çizilirdi. Rakamın MÜREKKEBİ (~0.7em = 154) kutuya sığdığından
       görünür bir kırpma yok.
     - **(b) Avatar hizası — bu sefer WEB yanlıştı, port doğruydu.**
       `<button>` varsayılan `inline-block` ve fotoğraflı hesapta `Avatar`
       bir `<img>` (inline-level) döndürüyor → satır kutusu → resmin ALTINA
       7px taban çizgisi payı → buton 39px ve resim üste yaslı → header'ın
       `items-center`'ı 39px'lik kabı ortalayınca fotoğraf skor kutusu
       merkezinin **3.5px üstünde** kalıyor. Butona `flex` eklendi.
       Ayrıntı + ölçüm: kök `CLAUDE.md`, `UserMenu` maddesi.
     - **ÖLÇÜM, iki madde için de tahminin yerini aldı** (derlenmiş
       `dist/assets/*.css` + Chromium, 390/834/1194): filigran puntoları
       124.8/93.6/7.41 ve 220/165/12 olarak okundu; avatar merkezi
       düzeltmeden önce 26 (kutu 29.5), sonra üç genişlikte de birebir eşit.
       Ölçüm ayrıca hatanın KAPSAMINI daralttı: avatar sapması yalnızca
       profil FOTOĞRAFI olan hesaplarda var (baş harf yedeği `display:flex`,
       rozetli sarmalayıcı `inline-flex` — ikisi de 32px kalıyor).
     - **Test:** `board_render_test.dart`'a iki test (geniş ekranda clamp
       tavanı 220/165/12 + `fontFamily`/`height`; dar ekranda clamp ortası
       124.8/93.6/7.41). Filigranlar yalnızca BOŞ hücrelerde çizildiğinden
       bitmiş bir golden fixture kullanılamaz — testler boş tahtalı bir
       `emptyBoardState()` ile ve tahtayı gerçek genişliğinde (680/374)
       çizen ayrı bir `pumpBoardSized` ile koşuyor (`pumpBoard`ın sabit 560
       kutusu ve 90px payı burada yanıltıcı olurdu).
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde
       Flutter SDK YOK (`flutter: command not found`, Parça 103/104/105'in
       aynı sınırı), yani `flutter analyze`/`flutter test` KOŞULAMADI ve
       **negatif eş kurulamadı**; testler eski kodda zorunlu olarak düşerdi
       (eski `Text`lerin `style.fontSize`'ı `null`), ama bu gösterilmedi —
       tek kanıt CI (`mobile-build.yml`). Web yarısı tam doğrulandı
       (`npm run lint`, `npm run build`, Playwright 3/3, Chromium ölçümü).
     - ~~**Cihazda doğrulanacak:** iki `TESTING.md`'ye maddeler eklendi.~~
       → **17 Ağustos 2026'da iPad'de KOŞULDU ve GEÇTİ:** köşe rakamları
       iki tarafta aynı boy/font, merkez **X2** aynı boy ve **X3 hücreyi
       DOLDURMUYOR** (web'in 12px tavanına oturuyor). Yani `FittedBox`tan
       `fluidSize`a geçiş gerçek CanvasKit'te de web'le aynı sonucu
       veriyor — negatif eşin kurulamadığı (Flutter SDK'sız oturum) bu
       parçada tek gerçek kanıt buydu. **Header avatarının dikey hizası
       AYNI turda koşulmadı** (o web-only ve FOTOĞRAFLI hesap ister).
     - **CI'ın YAKALADIĞI hata bu parçadan DEĞİL, bir önceki dalda merge
       bekleyen commit'lerden çıktı (kayda değer):** PR #277'nin ilk
       koşusunda **442 geçti, 1 düştü** — `score_card_test.dart`'ın
       `find.text('#3 · 8 puan')` beklentisi (`Found 0 widgets`). Sebep
       Parça 106 değil, 17 Ağustos sabahındaki "k-lig satırındaki nokta
       boşluğu" commit'i: satır düz `Text`ten `Text.rich`e çevrilip
       ayırıcının iki yanına 2px'lik `WidgetSpan` konmuştu (web `mx-0.5`),
       yani düz metin artık `'#3·8 puan'` — ama testi güncellenmemişti.
       **O üç commit hiç CI görmemişti**: PR #276 merge edildikten SONRA
       aynı dala push edildiklerinden `pull_request` tetikleyicisi bir daha
       çalışmamıştı (workflow yalnızca `main`'e push ve PR'da koşuyor).
       Test artık literal dize yerine SÖZLEŞMEYİ ölçüyor — düz metin
       `'#3·8 puan'` VE ayırıcının iki yanındaki boşlukların 2px'lik
       `WidgetSpan` olduğu (boşluk karakteri DEĞİL), yani o commit'in asıl
       iddiasını da koruyor.
     - **Ders:** merge edilmiş bir PR'ın dalına eklenen commit'ler sessizce
       CI'sız kalıyor. Bir dala "merge sonrası" commit atıldıysa, o dal
       yeni bir PR'a girene kadar hiçbir şey doğrulanmamıştır — bu, bu
       oturumda Flutter SDK'sının olmamasıyla birleşince (yerelde
       `flutter test` de koşulamıyor) tek doğrulama yolunu PR'a bağlıyor.

   - ✅ **Parça 107 — filigranlar TAŞLARIN ÜSTÜNE biniyordu: web'in z-index
     sırası porta hiç geçmemişti (17 Ağustos 2026, `board_widget.dart`):**
     Kullanıcı Parça 106'nın deploy'undan sonra iki ekranı yan yana koyup
     bildirdi: *"Web'de watermark'lar taşların üstünden görünmeyecek şekilde
     ayarlamıştık, app'de hâlâ görünüyorlar."* Ekran görüntüsünde X2
     filigranı `E Ğ E` taşlarının üzerinden geçiyordu.
     - **Web önce okundu (kuralın ilk adımı) ve TAM katman sırasını verdi:**
       `Board.tsx`'te taş içeren hücreler `relative z-[5]` alıyor ve o
       satırın kendi yorumu gerekçeyi yazıyor ("köşe/bonus filigranları
       (z-index:auto) taşın ÜZERİNDE boyanmasın diye"); dış hat SVG'si ve
       puan rozeti ise `z-10`. Yani sıra: **arka planlar → filigran →
       taşlar → dış hatlar**. Filigran DOM'da en sonda olduğu hâlde taşın
       altında kalıyor, çünkü tek belirleyici z-index.
     - **Portta bu sıra otomatik değil:** Flutter'da z-index yok, `Stack`
       çocuk sırası = boyama sırası. Port ızgara → dış hatlar → filigran
       diye diziyordu, yani filigran HER ŞEYİN üstünde. İki sapma birden:
       taşların üstüne biniyordu (bildirilen) ve dış hatların üstüne
       biniyordu (bildirilmedi, çok daha silik).
     - **Çözüm — taşları ayrı katmana taşımak DEĞİL, filigranı kesmek:**
       filigran katmanı ızgaradan sonra ama dış hatlardan ÖNCE çiziliyor ve
       bir `ClipPath` ile taş bulunan hücreler kesiliyor
       (`_WatermarkClipper`). Sonuç "taşın altında" ile görsel olarak aynı;
       alternatif (ızgarayı biri arka planlar biri taşlar için iki kez
       inşa etmek) 169 hücreyi iki katına çıkarırdı — Parça 23'te sürükleme
       sırasındaki tek fazladan ızgara inşasının bile ölçülebilir bir
       maliyeti olduğu görülmüştü.
     - **Delik `PathFillType.evenOdd` ile, `Path.combine`/PathOps ile
       DEĞİL** — Parça 18'in dersi: PathOps CanvasKit'te deliği sessizce
       kaybediyor, native Skia'da çalışıyor, yani `flutter test` o hata
       sınıfını GÖREMEZ. `neo_box.dart` zaten aynı deyimi kullanıyor.
     - **`dragHiddenKey` bilerek kesilmiyor:** o hücre boş çiziliyor (bkz.
       `_buildCell`), dolayısıyla filigran orada GÖRÜNMELİ. Kural
       `_buildCell`in koşuluyla birebir aynı: bayrak yalnızca `placed`
       taşını gizler, `board` taşını DEĞİL — testi yazarken önce bunu
       ters kurup düzelttim.
     - **Kesme kutusu ızgara geometrisinden türetiliyor** (13 hücre, 3px
       boşluk); `_gap` sabiti `GridView`in `mainAxisSpacing`/
       `crossAxisSpacing` değeriyle ELLE senkron — biri değişirse kesilen
       kutular hücrelerden kayar, bu yüzden sabitin yanına yazıldı.
     - **Test:** `board_render_test.dart`'a yeni bir test — clipper'ın
       ürettiği path'te onaylanmış taşın ve taslak taşın merkezi
       `contains == false`, sürüklenen taslağın kaynağı ile boş köşe/bonus
       hücreleri `contains == true`. Yani "filigran nerede çizilir"
       sorusunu ekran görüntüsüne bakmadan yanıtlıyor.
     - **Doğrulama sınırı — Parça 106'nın aynısı:** bu oturumun
       konteynerinde Flutter SDK YOK (`flutter: command not found`), yani
       `flutter analyze`/`flutter test` KOŞULAMADI ve **negatif eş
       kurulamadı**; tek kanıt CI. ~~Cihazda görsel teyit de bekleniyor~~
       → **17 Ağustos 2026'da iPad'de KOŞULDU ve GEÇTİ:** filigranlar
       taşların ALTINDA kalıyor, dış hatlar üstünde. Bu, `ClipPath` +
       `PathFillType.evenOdd` çözümünün gerçek CanvasKit'te de çalıştığının
       tek kanıtı — Parça 18'in dersi gereği PathOps kullanılmamıştı ve
       `flutter test` (native Skia) bu farkı yapısal olarak göremezdi.

   - ✅ **Parça 108 — rafın ALTINDAKİ aksiyon satırı web'den dört noktada
     sapmıştı (17 Ağustos 2026, `game_screen.dart`,
     `online_game_screen.dart`):** Kullanıcı Blok 6 turunda bildirdi:
     *"Rafın altındaki butonlar da farklı. Web'in aynısı olmalı."* Bu sefer
     yön normal (web kanonik) — port düzeltildi, web'e HİÇ dokunulmadı.
     - **Web ÖLÇÜLDÜ (derlenmiş CSS + Chromium), sınıflardan zihnen
       türetilmedi** (Parça 33'ün dersi): `font-sans` (Space Grotesk) ·
       11px · 700 · **tracking 1.2px** · **line-height 16.5px (=1.5)** ·
       dolgu 10/6 · radius 6 · **gap 6** · buton yüksekliği **41.5**.
     - **Dört sapma:**
       | | web | port (öncesi) |
       |---|---|---|
       | tracking | **1.2** | 1.0 (NeoButton varsayılanı) |
       | satır yüksekliği | **1.5** | 1.2 (varsayılan) |
       | swap satırı boşluğu | **6** (`gap-1.5`) | 8 |
       | buton yükseklikleri | flex `stretch` → **hepsi eşit** | `Row` varsayılanı `center` → TORBA ötekilerden uzun |
     - **Sonuncusu tek başına en sinsi olanı ve tam da düzeltmenin YAN
       ETKİSİYDİ:** TORBA'nın 13px'lik sayacı satır yüksekliğini belirliyor
       (web'de 19.5px). Yalnızca tracking/satır düzeltilseydi fark 2.4 →
       **3px**e çıkıp YENİ bir görünür tutarsızlık üretecekti. Web'de bunu
       flex'in `align-items: stretch` varsayılanı kapatıyor; Flutter `Row`
       varsayılanı `center` olduğundan `IntrinsicHeight` +
       `CrossAxisAlignment.stretch` şart (çıplak `stretch` sınırsız
       yükseklikte patlar — raf satırında öğrenilen aynı ders).
     - **NeoButton'ın VARSAYILANLARINA dokunulmadı** (Parça 37'nin deseni):
       değerler yalnızca ölçülen 14 çağrı yerine geçiliyor. Tarandı —
       varsayılana güvenen başka 4 çağrı yeri var
       (`friend_moderation_sheet` ×3, `setup_screen` ×1) ve onların web
       karşılığı ölçülmedi; varsayılanı değiştirmek onları da sessizce
       kaydırırdı.
     - **Kapsam BİLİNÇLİ olarak 2px genişletildi:** raf ↔ OYNA arası da 8'di,
       web `flex gap-1.5 items-stretch` = **6**. Aynı satır ailesi, tek
       karakterlik ölçülmüş bir düzeltme — gerekçesi burada yazılı olduğu
       için yapıldı (Parça 53'ün kuralı: kapsamı kendi genişletmek de
       daraltmak kadar riskli, ama gerekçe yazılırsa meşru).
     - **Kalan 2px BİLİNÇLİ (Parça 37'nin emsali):** web 41.5, port 39.5 —
       fark tam olarak web'in `border`ının yer kaplaması; portta çerçeve
       `foregroundDecoration`da ve layout'a değmiyor. Telafi için 1px dolgu
       EKLENMEDİ (çerçeve bir gün decoration'a taşınırsa iki kez sayılacak
       bir sihirli sayı olurdu).
     - **Test:** `game_screen_test.dart`'a yeni bir test — dört butonun
       punto/tracking/satır yüksekliği, 6px boşluk, ve **TORBA'nın ötekilerle
       AYNI yükseklikte** olduğu. Sonuncusu olmadan tracking düzeltmesi
       yukarıdaki 3px'lik regresyonu üretip yine geçerdi.
     - **Doğrulama sınırı — Parça 106/107'nin aynısı:** bu oturumun
       konteynerinde Flutter SDK YOK, `dart analyze`/`flutter test`
       KOŞULAMADI ve **negatif eş kurulamadı**; parantez dengesi elle
       taranıp doğrulandı, tek gerçek kanıt CI. Cihazda görsel teyit
       bekleniyor (`mobile/TESTING.md` 0.5).

   - ✅ **Parça 109 — sağ-alt köşedeki YZ her oyuna 29 puan geride
     başlıyordu: `tryCornerStart` kelimeyi yalnızca evden İLERİ uzatıyordu
     (17 Ağustos 2026, `find_move.dart` + web `ai.ts`):** Kullanıcı
     *"sağ alttaki YZ genelde hep sonuncu oluyor. Benim de dikkatimi
     çekmişti. Bunu düzelt acil."* dedi.
     - **Kural okundu, sonra ölçüldü (bu sırayla).** `validatePlacement`
       ilk hamlede YALNIZCA "konan hücrelerden biri ev karesi olsun" diyor
       — yön ya da "4×4 blokta başla" şartı YOK. Yani kısıt oyunun değil
       `tryCornerStart`'ın kendi döngüsünündü; üstelik tutarsızlık YZ'nin
       İÇİNDEYDİ: `tryPlace` (çapalı hamleler) baştan beri `idx` döngüsüyle
       kelimeyi iki yöne de uzatıyordu.
     - **Ölçüm (üretim `findAIMove`, raf `A B A R T M A`, boş tahta):**
       köşe 0/1/2 → `7 taş "ABARTMA" 35 puan`; **köşe 3 → `4 taş "ABAT"
       6 puan`.** 2 kişilikte YZ HER ZAMAN köşe 3'te (`cornersFor`), yani
       bu her oyunda tekrarlanan 29 puanlık bir açılış handikabıydı.
       Düzeltmeden sonra dört köşe de 7 taş / 35 puan (köşe 3: `12,6 …
       12,12`, merkeze doğru).
     - **Düzeltme:** kelimenin HANGİ harfinin eve denk geleceği (`idx`)
       tek tek deneniyor; kelime evden geriye ve ileriye uzayabiliyor.
     - **Döngü SIRASI sözleşmedir, iki motorda da aynı yazıldı**
       (`for W → for idx → for horiz in [true,false]`): `consider` eşit
       puanda İLK bulunanı tutuyor (strict `>`), sıra ayrışırsa iki motor
       farklı hamle seçer ve parite SESSİZCE kırılır — golden vector
       karşılaştırması bunu ancak o senaryo tetiklenirse yakalar.
     - **Golden vector'lar yeniden üretildi; DÖRT fixture değişti ve
       dördü de açıklandı** (üçü besbelli, dördüncüsü değildi):
       `reducer_ai2`/`reducer_ai4`/`reducer_sync` — ilk fark 5. adımdaki
       `AI_PLAY`, yani köşe 3'ün ilk hamlesi. **`reducer_human2` ise SIFIR
       `AI_PLAY` içeriyor ve yine de değişti** — sebebi `humanScenario`'nun
       "geçerli hamleler"i `playBestMove` ile, yani üretim `findAIMove`'unu
       İNSAN adına çağırarak oynatması; 2 kişilikte 2. oyuncu köşe 3'te
       olduğundan o çağrı da `tryCornerStart`'a düşüyor. `JE` (11 puan)
       evden hem dikey (`11,12→12,12`) hem yatay (`12,11→12,12`)
       kurulabiliyor, ikisi de AYNI puan → "ilk bulunan kazanır" artık
       yatayı seçiyor. Tahta değişince senaryonun DİNAMİK koordinatları
       (`findEmptyCell` ve sağ-komşu taraması) kayıyor. Finaller aynı.
       **Ders: bir fixture'da `AI_PLAY` olmaması, o senaryonun YZ'ye
       dokunmadığı anlamına GELMEZ** — üretici kelime aramasını insan
       hamlelerini üretmek için de kullanıyor.
     - **Kapsam dışı, kullanıcıya bildirildi:** `getWordPool` havuzu 2-7
       harfle sınırlı, yani YZ 8+ harfli bir kelimeyi çapaya ekleyerek
       bile kurmuyor (kurallara uygun olurdu). Bu ayrı bir karar; bu
       parçada DEĞİŞMEDİ.
     - **Doğrulama sınırı — Parça 106/107/108'in aynısı:** bu oturumun
       konteynerinde Flutter/Dart SDK YOK (`flutter: command not found`),
       yani `dart run test/run_all.dart` KOŞULAMADI — **motor değişikliği
       olduğu hâlde Dart yarısının tek kanıtı CI.** Web yarısı tam
       doğrulandı (`npm run lint`, `npm run build`, Playwright 3/3, ölçüm
       betiği). Dart portu satır satır web'e karşı okundu; `cornerBounds`
       artık kullanılmıyor (Dart'ta kütüphane importu olduğundan
       kullanılmayan-import hatası doğurmuyor, web'de import satırından
       çıkarıldı).

   - ✅ **Parça 110 — Setup girişli/misafir ayrımı + footer'a "Paylaş"
     (17 Ağustos 2026, `setup_screen.dart`, `setup_screen_test.dart`;
     web `Setup.tsx` AYNI PR'da):** İsteğin kaynağı bölüm 1 spesifikasyonu —
     kullanıcının sözleri: *"Girişli kullanıcılarda Kelimeki logosunun
     altındaki tanıtım yazısı ve linkler kalksın… Bu model birebir app'lerde
     de çalışacak değil mi? O şekilde istiyorum."* İki değişiklik, ikisi de
     yalnızca girişli kullanıcıyı ilgilendiriyor — misafirin görünümüne
     KESİNLİKLE dokunulmadı.
     - **(1) Logonun altındaki tanıtım paragrafı + "Nasıl oynanır? ·
       Arkadaşınla paylaş" satırı artık YALNIZCA `auth.user == null`
       (misafir) iken render ediliyor.** İki `SizedBox(height:20)` vardı:
       biri logo↔paragraf arasında, biri link satırı↔"OYUN TİPİ" arasında.
       **İlk denemede İKİSİ de koşulsuz bırakılmıştı** — bu, girişli
       kullanıcıda 40px'lik bir boşluk üretirdi (web'de tam 20px olması
       gerekirken). Kendi kendine yakalandı: yalnızca İKİNCİ SizedBox
       (link satırından sonraki, "OYUN TİPİ"nin hemen üstündeki) koşulsuz
       bırakıldı — spec'in "portun 20 px'i ZATEN elle yazılmış, silme,
       yerinde bırak" talimatının işaret ettiği tam olarak bu satır. İlk
       SizedBox (logo↔paragraf arası) paragraf/link bloğunun İÇİNE, guest
       şartına taşındı — girişlide artık HİÇBİR telafi marjı olmadan logo
       doğrudan tek bir 20px'lik boşlukla "OYUN TİPİ"ye bağlanıyor (web'in
       ölçülen değeriyle birebir: 20.00px, misafirde 152.50/136.50px'lik
       ölçümler DEĞİŞMEDİ çünkü o dal aynen duruyor).
     - **(2) Footer'daki hukuki link satırı `Row`dan `Wrap`e çevrildi**
       (`alignment: WrapAlignment.center, spacing: 8, runSpacing: 4`) —
       web'in `flex-wrap` güvenlik ağının Flutter karşılığı. Flutter'da bir
       `Row` taşması `RenderFlex overflowed` (debug'da sarı/siyah çubuk,
       release'de kırpma) demek — web'in sessizce yatay kaydırdığı bir
       taşmadan çok daha görünür/yıkıcı bir hata sınıfı, bu yüzden `Wrap`
       zorunlu bir güvenlik önlemi (yalnızca web'i taklit etmek için değil).
       Girişli kullanıcı için üçüncü bir madde eklendi: **"Paylaş"** —
       `Icon(Icons.share, size:12, color:_muted)` + `SizedBox(width:4)` +
       `Text('Paylaş', fontFamily:'SpaceMono', fontSize:10, color:_muted)`,
       hukuki linklerle AYNI punto/renk (`_LegalLink` ile görsel dil
       tutarlı, ama kendisi tıklanabilir bir link stilinde değil — web'in
       glyph+metin ikilisiyle birebir). Dokununca **mevcut `_handleShare`**
       ÇAĞIRILIYOR (yeni bir paylaşım fonksiyonu YAZILMADI) — bu, misafirin
       "Arkadaşınla paylaş" linkiyle BİREBİR AYNI çağrı
       (`(widget.share ?? shareBoard)(png: null, text: 'Hemen ücretsiz
       dene!', url: '$webOrigin/?ref=arkadas', origin:
       shareOriginFrom(context))`), yani admin panelindeki "Kaynak
       Hunisi"nin dayandığı `?ref=arkadas` UTM parametresi korunuyor.
     - **Adı BİLEREK "Arkadaşını Davet Et" DEĞİL "Paylaş"** — o isim
       `FriendsModal`'daki AYRI bir özelliğin (kalıcı davet token'ı,
       `create_friend_invite_link`) adı; bu buton genel bir site/tahta
       linkini `?ref=arkadas` ile paylaşıyor, isim çakışması kafa
       karıştırırdı.
     - **`webOrigin` sabiti** (env.dart) `https://kelimeki.com` — mevcut
       "Arkadaşınla paylaş" testinde zaten `sharedUrl` ==
       `'https://kelimeki.com/?ref=arkadas'` diye doğrulanmıştı, yeni
       "Paylaş" testi AYNI beklentiyi taşıyor.
     - **Test — 4 yeni test, negatif eş gerektirmeyen ama davranışı iki
       yönden (var/yok) sınayan çiftler:** girişlide paragraf/link YOK +
       logo→"OYUN TİPİ" tam 20px; misafirde paragraf/link HÂLÂ var
       (mevcut testler zaten bunu sınıyordu, ek bir "misafirde" testi
       netlik için eklendi); footer'da "Paylaş" misafirde YOK, girişlide
       VAR ve dokununca `_handleShare`'i doğru parametrelerle çağırıyor.
       Mevcut GUEST-variant testler (`'"Arkadaşınla paylaş" ?ref=arkadas
       linkini paylaşır'`, `'tanıtım paragrafı … ORTALI'`, `'Setup başlık
       bloğu ve hukuki alt satır web ile aynı'`, `'logo altındaki yazı
       bloğu…'`) HİÇ DEĞİŞTİRİLMEDİ — hepsi `services()` (auth yok, yani
       `auth.user == null`) kullandığından yeni koşulun `if` dalına
       girmeye devam ediyorlar.
     - **`mobile/` DIŞINDA dosya değişti** (`src/components/Setup.tsx`,
       yeni `src/components/RelationIcons.tsx`'teki `ShareIcon`, kök
       `CLAUDE.md`) → aynı PR'da, aynı commit'te teslim edildi (Parça
       Bitirme Kontrol Listesi madde 1) — port dalında mahsur kalma
       riski yok.
     - **Web tarafındaki `ShareIcon`** Flutter'ın KENDİ `Icons.share`
       (U+E593, `share_baseline`) glyph'inden fontTools ile çıkarılıp
       web'e taşındı — `RelationIcons.tsx`'in kendi belgelediği yöntemle
       (unitsPerEm 512 → 24'lük viewBox, y ekseni ters) ve render edilip
       GÖRSEL olarak doğrulandı (bu dosyanın kendi başlığındaki "codepoint
       hafızadan yazılırsa yanlış glyph çizilir" uyarısı gereği).
     - **Doğrulama sınırı — bu oturumda Flutter/Dart SDK YOK**
       (`flutter: command not found`, Parça 103-109'un aynı sınırı):
       `flutter analyze`/`flutter test` KOŞULAMADI; değişiklikler elle
       (bracket/paren dengesi + tam diff okuması) doğrulandı, tek gerçek
       kanıt CI (`mobile-build.yml`). Web yarısı `npm run lint` +
       `npm run build` + Playwright duman testleriyle (3/3) doğrulandı,
       ayrıca derlenmiş CSS + Chromium ile GERÇEK ölçüm yapıldı (guest
       152.50/136.50px değişmedi; girişli 20.00px; footer buton
       ~52.7×15px, ≈356px'te ikinci satıra sarıyor, negatif eş ile
       — `flex-wrap` kaldırılınca 320px'te GERÇEKTEN yatay taşma
       oluştuğu doğrulanıp geri eklendi).
     - **AYNI GÜN bulunan eksik: footer'da AYRAÇ yoktu (`·`) — "birebir"
       isteğinin ihlali.** Web girişli footer'da `Kullanım Koşulları ·
       Gizlilik Politikası · [ikon] Paylaş` çiziyor: `Setup.tsx`'te
       `<span>·</span>` ile "Paylaş" butonu AYNI `{user && (<>…</>)}`
       fragment'ının içinde, yani girişlide İKİ ayraç var, misafirde BİR.
       Port yalnızca butonu taşımış, ayracı atlamıştı → `… Gizlilik
       Politikası [ikon] Paylaş`. Kullanıcının kuralı açıktı ("Bu model
       birebir app'lerde de çalışacak değil mi? O şekilde istiyorum"),
       yani bu kozmetik bir ayrıntı değil doğrudan bir sapma. Düzeltme:
       `if (auth.user != null)` koşuluna bağlı ikinci bir `Text('·')` —
       stil yukarıdaki mevcut ayraçla BİREBİR aynı (SpaceMono/10/`_muted`),
       yeni bir stil yazılmadı.
     - **Bunun DÖRT test yeşilken hayatta kalmasının sebebi ölçülebilir:**
       eklenen testlerin hepsi metnin VARLIĞINI (`find.text('Paylaş')`)
       doğruluyordu; hiçbiri maddeler ARASINDAKİ tutkalı (ayraç/boşluk)
       ölçmüyordu. Artık iki footer testi ayraç SAYISINI de ölçüyor —
       misafirde `findsOneWidget`, girişlide `findsNWidgets(2)`. Finder
       güvenli: logo altındaki misafir link satırı BOŞLUKLU `' · '`
       kullanıyor (`setup_screen.dart:921`) ve teşhis satırı
       `.join(' · ')` ile TEK bir `Text` üretiyor, ikisi de bu finder'a
       takılmıyor; `account_button`/`score_card`/`player_score_card`'daki
       `TextSpan(text: '·')`'lar ise `Text.rich`in tam metnine gömülü
       olduğundan eşleşmiyor (hepsi grep'lenerek doğrulandı).
     - **Ders — "birebir" bir port isteğinde MADDELERİ karşılaştırmak
       yetmez, ARALARINDAKİ tutkalı (ayraç, boşluk, sıra) da karşılaştır;**
       ve içerik varlığını doğrulayan bir test, bu sınıf bir farkı
       yapısal olarak GÖREMEZ (kök `CLAUDE.md`'nin "negatif eş" dersinin
       kardeşi: aradığın şeyin YOKLUĞUNDA da geçen bir kontrol bir şey
       kanıtlamaz).
     - **Doğrulama sınırı (bu düzeltmeye özgü):** bu oturumda da Flutter/
       Dart SDK YOK, yani spec'in istediği negatif eş (ayracı geri silip
       testin GERÇEKTEN düştüğünü görmek) yerelde KURULAMADI — tek kanıt
       CI. Testin düşeceği aritmetik olarak kesin (ayraç silinince girişli
       footer'da 2 değil 1 `Text('·')` kalır), ama bu bir çıkarım, ölçüm
       değil.

   - ✅ **Parça 111 — misafir giriş uyarısındaki buton "DEVAM" → "OYNA"**
     (18 Ağustos 2026, kullanıcı bildirdi; web `Setup.tsx` ile AYNI PR).
     - **Neden:** uyarı metni üyeliğin faydalarını sayıyor ("istatistikler,
       k-lig ve arkadaşınla canlı oyun için lütfen giriş yapın"), bu yüzden
       "DEVAM" o cümlenin DEVAMI gibi okunup *"devam edersem üyeliğe
       gider"* izlenimi veriyordu — kullanıcının sözleri: *"Yazıyı okuyunca
       devama basmak üyeliğe götürecekmiş gibi düşündürüyor."* Yeni etiket
       ne olacağını söylüyor: misafir olarak oyun başlar.
     - **Davranış HİÇ değişmedi** — `_GuestChoice.proceed` dalı, ✕/dışarı
       dokunuşun oyunu başlatMAması, "GİRİŞ YAP"ın giriş penceresini
       açması aynı. Değişen tek şey `kDialogButton`ın `label`ı.
     - **Test:** `setup_screen_test.dart`'taki misafir akışı `find.text('OYNA')`e
       çevrildi ve ayrıca `expect(find.text('DEVAM'), findsNothing)` eklendi —
       yalnızca yeni etiketi aramak, eski etiket bir şekilde ekranda kalsaydı
       (ör. ikinci bir kopya) bunu göremezdi.
     - **Doğrulama sınırı:** bu oturumda Flutter/Dart SDK YOK (`flutter` ve
       `dart` bulunamadı), yani port testleri yerelde KOŞULAMADI — Dart
       yarısının kanıtı CI. Web yarısı ölçüldü: `tsc` temiz, Playwright
       18/18 yeşil ve negatif eş (modal locator'ı bozulunca ilgili İKİ test
       GERÇEKTEN düştü, üçüncü bir test etkilenmedi) koşuldu.

   - ✅ **Parça 112 — "Kalan Taşlar" (TORBA) dökümü bekleyen taşları
     RAKİBİN eline yazıyordu** (18 Ağustos 2026, kullanıcı bildirdi;
     web `bag.ts`/`RemainingTilesModal.tsx` ile AYNI PR).
     - **Semptom:** kullanıcı torba boşken, son hamlesini onaylamadan önce
       YZ'nin elinde kalacak taşları sayıp **10 puan** buldu; bitiş kartında
       **-7** gördü ve "hata mı var?" diye sordu.
     - **Bitiş kartı DOĞRUYDU** (`endGame` rakibin gerçek rafını topluyor) —
       yanlış olan DÖKÜMDÜ. Kök sebep bir kova boşluğu: `PLACE_TILE` taşı
       raftan ÇIKARIP `state.placed`e koyuyor, `board`a ancak `PLAY` yazıyor;
       `remainingTiles` yalnızca `board` + `myRack`i düştüğünden o aradaki
       taşlar "dışarıda" (= rakipte) sayılıyordu. Fark tam olarak masadaki
       bekleyen taşların puanıydı (10 − 7 = 3).
     - **Port birebir aynı hatayı taşıyordu** — `bag.dart` web'in doğrudan
       portu olduğundan kusur da portlanmıştı; `remainingTiles(board, myRack,
       [placedTiles = const []])` ve modalın `state.placed.values.toList()`
       geçmesiyle iki taraf birlikte düzeltildi.
     - **Bu fonksiyonun HİÇ parite kapsaması yoktu** — `remaining_tiles.json`
       (60 durum, bekleyen taşlı ve jokerli) eklendi ve `run_all.dart` onu
       tüketiyor. Ayrıca `game_screen_test.dart`'a widget regresyonu: taş koy
       → TORBA → **93** kalmalı (düzeltmeden önce 94). Web tarafında
       `npm run verify-remaining-tiles` üretim reducer'ıyla 13 kontrol
       koşuyor ve negatif eşte 7'si GERÇEKTEN düşüyor.
     - **Mevcut golden fixture'lar DEĞİŞMEDİ** (ölçüldü — reducer davranışı
       aynı, yalnızca yeni fixture eklendi).
     - **Doğrulama sınırı:** bu oturumda Flutter/Dart SDK YOK, port testleri
       yerelde KOŞULAMADI — Dart yarısının kanıtı CI. Web yarısı ölçüldü
       (`tsc` temiz, `npm run build` temiz, Playwright 18/18, verify 13/13).

   - ✅ **Parça 113 — k-lig rütbe rozeti yeniden tasarlandı: tırtıklı mühür
     bırakıldı, yerine kurdeleli roset (18 Ağustos 2026, `rank_seal.dart`
     + web `RankSeal.tsx`, AYNI PR):** Kullanıcı: *"Bizim rütbe badge'leri
     beğenmiyorum. Özellikle ince tırtıklar çok kötü. Bana … altı kurdeleli
     badge alternatifleri ver 3 tane. Bizim standart font kullanmak şart
     değil… Albenili ama egzajere değil, basit ama şık bir şey."*
     - **Üç alternatif sunuldu (dolu madalya / çizgisel rozet / altıgen
       madalyon) ve ÜÇÜ DE seçilmedi.** Kullanıcı bunun yerine bir
       **referans görsel** gönderdi (klasik ödül roseti: dolu dalgalı disk +
       içte açık halka + V kesikli iki kurdele) ve *"Bundan istiyorum.
       Rengini sen ayarla"*, ardından *"Bu imajı birebir kopyala ve ona
       giydir"* dedi. Yani tasarım kararı benim üç önerimden değil, o
       görselin oranlarından türetildi — **bir tasarım isteğinde kullanıcı
       kendi referansını verirse, hazırladığın alternatifleri savunma;
       referansı ölçüp kopyala.**
     - **İki dosya AYNI sabit setini taşıyor ve ELLE senkron** (`CY=16.6`,
       `TIP_R=15`, `VALLEY_R=12.675`, `LOBES=14`, `EDGE_W=2`, `RING_R=11`,
       `RING_W=1.3`, beş noktalı kurdele poligonu, `darken`/`sealRibbonColor`
       ×0.86) — web bir `<polygon>`, port bir `Path` çiziyor. Biri
       değişirse öteki de değişmeli; ayrıntılı gerekçeler kök `CLAUDE.md`'de.
     - **CanvasKit güvenliği baştan kuruldu (Parça 18'in dersi):**
       `Path.combine`/PathOps HİÇ kullanılmıyor — eski mührün kesikli iç
       halkası yay yay çiziliyordu, yeni halka düz bir `drawCircle`, o
       karmaşa tamamen kalktı.
     - **Punto merdiveni ÖLÇÜLDÜ, tahmin edilmedi** (web tarafında gerçek
       Space Grotesk 700 ile `canvas.measureText`): tek harf tam boyda
       **18** / kompaktta **20.5**, "+50" **13**, "1000" **10.5**, "+1000"
       **8.5**. Yeni `sealShowsRing(text, {compact})` — halka yalnızca tam
       boyda VE tek harfte; rakamlı glyph'ler halkaya sığmıyor.
     - **`String.length` KULLANILDI, `.characters` DEĞİL** — web `text.length`
       (UTF-16) ile birebir parite; basılabilen tüm glyph'ler (Ç M O U Ş D
       E Z T, rakamlar, '+') tek kod birimi, ayrıca `characters` doğrudan
       bir bağımlılık değil.
     - **`sealBaselineEm` korundu ama sabitleri yeni fonta göre yeniden
       ölçüldü** (`kSealInkAscEm` .71→**.66**, `kSealDescenderEm` .21→**.215**)
       — 12 Ağustos'ta öğrenilen "harf FONT metriklerinden değil MÜREKKEP
       kutusundan ortalanır" kuralı aynen geçerli, yalnızca yazı tipi
       Space Mono'dan Space Grotesk 700'e geçtiği için sayılar değişti.
     - **Test:** `league_rewards_test.dart`'ın mühür testleri yeni tasarıma
       çekildi — punto merdiveni + `sealShowsRing` (yeni test); ilkel sayımı
       artık **4 `drawPath`** (iki kurdele + madalyon dolgu + madalyon kenar)
       ve halka `drawCircle` (tam boyda 1, kompaktta 0), `drawArc` her iki
       boyda da **0**; mürekkep-ortalama testi merkezi `kSealCy`'ye,
       tarama sınırını halkanın içine (10.2) ve mürekkep tespitini BEYAZ
       harfe (`green > 160`, madalyon dolgusu artık kademe rengi) çekti.
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde
       Flutter/Dart SDK YOK (`flutter`/`dart` bulunamadı, Parça 103-112'nin
       aynı sınırı): `flutter analyze`/`flutter test` KOŞULAMADI ve
       **negatif eş kurulamadı** — Dart yarısının tek kanıtı CI. Web yarısı
       tam doğrulandı: `tsc` temiz, `npm run build` temiz, Playwright
       **18/18**, ve GERÇEK üretim bileşeni (esbuild → `renderToStaticMarkup`
       → Chromium/DPR 2) dokuz kademe × dört boy + dört banner glyph'iyle
       render edilip gözle denetlendi. Tanıtım sayfası bütçesi ölçüldü:
       `dist/index.html` ham **254.144** / gzip **22.250** bayt (öncesi
       254.958 / 22.147 — ham −814, gzip +103; ihmal edilebilir).
     - **Cihazda doğrulanacak:** iki `TESTING.md`'nin ilgili maddeleri yeni
       tasarıma göre yeniden yazıldı (eski "tırtık her boyda" maddesi artık
       geçersiz).
     - ⚠️ **Bu parçanın font/punto/metrik notları AYNI GÜN Parça 114 ile
       DEĞİŞTİ** — aşağıya bkz. (yazı tipi artık Space Grotesk 700 değil,
       `kSealInkAscEm` .66 değil).

   - ✅ **Parça 114 — rozetin İÇİNDEKİ font: M PLUS Rounded 1c ExtraBold
     (18 Ağustos 2026, `rank_seal.dart`, `pubspec.yaml`,
     `test/support/test_fonts.dart`, yeni `assets/fonts/…-subset.ttf`
     + web `RankSeal.tsx`/`src/fonts/`, AYNI PR):** Parça 113'ün rozeti
     onaylandıktan hemen sonra kullanıcı: *"Yanlız içindeki font hoşuma
     gitmedi. Daha basık ve yuvarlak hatlı bir font bulalım. Alternatif
     ver bir kaç tane."* Altı aday GERÇEK rozetin içinde render edilip
     gösterildi (tarif edilerek değil — Parça 52'nin kum saati kararıyla
     aynı yöntem), kullanıcı M PLUS Rounded 1c 800'ü seçti.
     - **İKİ platform AYNI alt kümeyi taşıyor** (`pyftsubset`, 108 glyph):
       web 6.3 KB woff2, port **14.4 KB ttf** (`assets/fonts/
       MPLUSRounded1c-ExtraBold-subset.ttf`, `pubspec.yaml`'da
       `MPlusRounded1c` / weight 800). Kaynak TTF 3.6 MB — alt kümeleme
       zorunlu, dosya ÜRETİLMİŞ. Komut ve gerekçe kök `CLAUDE.md` →
       "Rütbe Rozeti Fontu".
     - **GİZLİ BAĞ — yeni bir kademe HARFİ eklenirse subset yeniden
       üretilmeli.** Portta bunun bedeli web'den AĞIR: Flutter otomatik
       font fallback YAPMAZ, kapsam dışı bir glyph **TOFU (boş kare)**
       çizer (bu proje aynı dersi ✓/★/🤖'da üç kez yaşadı). Bugünkü
       aralık ASCII + tüm Türkçe harfleri kapsıyor.
     - **`test_fonts.dart` da yüklemek ZORUNDA:** `flutter_test` pubspec
       fontlarını otomatik yüklemiyor (Parça 1'in dersi) — `loadAppFonts`
       bu aileyi yüklemezse mühürdeki harf Ahem bloğuna döner ve
       `league_rewards_test`in MÜREKKEP-ORTALAMA testi (piksel tarayan
       test) sessizce anlamsızlaşır: blok her zaman kusursuz ortalıdır.
     - **Sabitler yeniden ÖLÇÜLDÜ, taşınmadı** (web tarafında gerçek
       fontla, `canvas.measureText`in `actualBoundingBox*` alanları):
       `kSealInkAscEm` .66 → **.745**, `kSealDescenderEm` .215 → **.22**.
       Bu fontta aralık çok dar — basılabilen HER glyph için azami
       merkezleme sapması 0.0075 em (eski fontta 0.03 em).
     - **Punto merdiveni DEĞİŞTİ ve bu sefer PİKSELLE ölçüldü:** tek harf
       **18** / kompakt **20.5** (AYNI kaldı), 2-3 karakter 13 → **12**,
       4 karakter 10.5 → **9.5**, 5+ 8.5 → **8**. M PLUS'ın rakamları
       Space Grotesk'ten belirgin geniş. **Ders:** `textAnchor="middle"`
       (ve `TextPainter`ın ortalaması) mürekkebi değil ADVANCE kutusunu
       ortalar — yan boşlukları asimetrik bir glyph (`+1000`) yalnızca
       `measureText`le hesaplanan bir tavandan taşar; ilk ladder (12/10/
       8.5) tam bu yüzden beş glyph'te poligonu deliyordu ve bu ancak
       gerçek rozet 20× büyütülüp beyaz pikselleri poligona karşı
       taranarak görüldü.
     - **Test:** `league_rewards_test.dart`'ın `sealFontSize` beklentileri
       yeni merdivene çekildi (20.5 / 18 / 12 / 12 / 9.5 / 8). Mühür
       geometrisi/ilkel sayımı DEĞİŞMEDİ.
     - **Doğrulama sınırı — Parça 113'ün aynısı:** bu oturumda Flutter/
       Dart SDK YOK, `flutter analyze`/`flutter test` KOŞULAMADI ve
       **negatif eş kurulamadı** — Dart yarısının tek kanıtı CI. Web
       yarısı tam doğrulandı (`tsc`, `npm run build`, Playwright 18/18,
       gerçek üretim bileşeniyle 9 kademe × 4 boy + 8 banner glyph'i
       render edilip gözle denetlendi; bütçe ham **254.096** / gzip
       **22.248** bayt + ayrı 6.268 baytlık font asset'i).
     - **Cihazda doğrulanacak:** mühürdeki harfin TOFU olmadığı ve iki
       platformda AYNI göründüğü (özellikle Ç/Ş sedillası ve banner'ın
       `+1000` glyph'i) — `mobile/TESTING.md` bölüm 13.

   - ✅ **Parça 115 — rütbe mührü İSİMLERİN yanına da geldi: yedi yüzey, tek
     toplu sorgu (18 Ağustos 2026, yeni `ui/rank/rank_scores.dart`,
     `data/stats_api.dart`, `account_button.dart`, `score_card_modal.dart`,
     `player_score_card_modal.dart`, `setup_screen.dart`, `friends_modal.dart`,
     `live_game_create_form.dart`, `live_games_tab.dart` + web yarısı AYNI
     PR'da):** Kullanıcı isteği (tam metni kök `CLAUDE.md` → "Rütbe mührü
     artık İSİMLERİN yanında da").
     - **Migration GEREKMEDİ:** `leaderboard` view'ı `user_id`+`total_score`
       veriyor ve `security_invoker = false` ile kilitli RLS'i bypass
       ediyor; yeni `StatsGateway.rankScores(userIds)` tek `in` sorgusuyla
       toplu okuyor. **`player_stats`in mod bazlı toplamıyla KARIŞTIRMA** —
       o ödülleri saymadığı için 17 Ağustos'ta Setup'tan kaldırılmıştı;
       `leaderboard.total_score` ödül DAHİL, yani mühür hesap menüsündeki
       k-lig satırıyla ayrışamaz.
     - **`RankScores` (ChangeNotifier), Riverpod/Bloc yok** (karar #5):
       `tierOf(id)` puan bilinmiyorsa `null` döner (mühür HİÇ çizilmez —
       "0 puan" ile "henüz yüklenmedi" AYRI şeyler), `ensure(ids)` yalnızca
       EKSİK id'ler için ağa gider ve `notifyListeners`ı bir sonraki
       microtask'a erteler; bu yüzden `build` içinden çağrılabilir
       ("setState during build" hatası doğmaz).
     - **Boylar satırın PUNTOSUNA bağlı ve web tarafında ÖLÇÜLDÜ** (derlenmiş
       CSS + Chromium): 12px isim → **16**, 14px → **18**, 16px → **20**.
       Üç sayı da iki platformda ELLE senkron — biri değişirse öteki de.
     - **Başlıktaki 34px'lik mühür KALDI** (o tıklanabilir, `RankInfoModal`'ı
       açar). Bu yüzden `score_card_test.dart`'ın mevcut geometri testi
       artık `find.byType(RankSeal).first` yerine **BOYA göre** seçiyor —
       kartta iki mühür var, sıraya güvenmek kırılgan.
     - **`_PendingGameCard` StatelessWidget olduğundan lookup FONKSİYON
         olarak geçiliyor** (`tierOf`), web'de aynı yerde context kullanıldı
       (orada satır bileşeni dört seviye aşağıda). Üç çağrı yerinin ÜÇÜ de
       geçmek zorunda — biri atlanırsa mühür yalnızca bir kovada çıkar.
     - **Testler:** hesap menüsü (18px + ismin sağında), `FriendsModal`
       ("Arkadaşlarım" satırı), `ScoreCard` (20px isim mührü + 34px başlık
       mührünün DURDUĞU). Beş sahte `StatsGateway` de yeni metodu uygulamak
       zorunda kaldı; `score_card_test`inki gerçek ucun INNER JOIN'ini
       taklit ediyor (`rows`ta olmayan id sonuçta YOK — Parça 46'nın dersi).
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde
       Flutter/Dart SDK YOK (`which flutter dart` → boş), yani
       `flutter analyze`/`flutter test` KOŞULAMADI ve **negatif eş
       kurulamadı** — Dart yarısının tek kanıtı CI (Parça 103-114'ün aynı
       sınırı). Web yarısı tam doğrulandı: `npm run lint`, `npm run build`,
       Playwright **18/18**, ve gerçek Chromium ölçümü (kutular
       16.00/18.00/20.00, boşluk 6.00, dikey merkezler isimle aynı, yatay
       taşma 0; dokuz kademe harfi de tofu'suz).
     - **CI'ın SÖYLEDİĞİ (bu parça yazıldıktan sonra ölçüldü):** `dart
       analyze lib/ test/` temiz ve **454 test yeşil**; web derlemesi de
       geçti. **Ama ilk koşuda DÜŞTÜ** ve sebebi tam da bu sınırdı:
       eklenen test var olmayan bir sahte uç adı (`_FakeFriendsGateway`)
       ve var olmayan bir alan adı (`friendRows`, doğrusu `friendsRows`)
       kullanıyordu — Flutter SDK'sı olan bir oturumda `dart analyze`
       bunu saniyeler içinde yakalardı. **Ders: SDK'sız bir oturumda
       yazılan Dart testinde, kullanılan HER sahte uç/alan adını kaynağa
       karşı grep'le doğrula** — "kodu okudum, doğru görünüyor" burada
       derleyicinin yerini tutmuyor.
     - **Cihazda doğrulanacak:** yedi yüzeyde mühürün göründüğü ve doğru
       kademeyi çizdiği — `mobile/TESTING.md` bölüm 13'e madde eklendi.

## FAZ A1 — Cihaz Testi Tur Durumu (son güncelleme: 17 Ağustos 2026)

**Bu bölüm iki `TESTING.md`'nin BİLİNÇLİ olarak tutmadığı tek şeyi tutar:**
o dosyalar "bir ilerleme kaydı değildir, her sürüm öncesi baştan
koşulabilir" diyor ve bu doğru — ama o yüzden "bu turda nereye kadar
geldik?" sorusunun cevabı hiçbir yerde yazılı değildi ve yalnızca
konuşma bağlamında yaşıyordu. Bir oturum kapandığında kayboluyor, sonraki
oturum ya baştan çıkarım yapıyor ya da yapması gerektiğini hiç bilmiyor.

**Bu bir kalıcı "tik listesi" DEĞİL, TURA ÖZGÜ bir anlık görüntü.** Yeni
bir tam tur başladığında (yeni sürüm, büyük bir refactor) sıfırlanır.
Buradaki "✅", "bu turda koşuldu" demektir — "bir daha koşulmasın" değil.

### Bölüm bölüm (FAZ A1 = GitHub Pages web derlemesi, iPad Safari)

| Bölüm | Durum | Not |
|---|---|---|
| 0 · Derleme / ilk açılış | ✅ | FAZ A0 |
| 0.5 · Web ile yan yana görsel | ✅ | **17 Ağu'da (Blok 6) KAPANDI — bölümün TAMAMI koşuldu, sıfır bulgu.** Öncesi: birçok tur (Parça 29/33/37/56/72-80). **17 Ağu:** k-lig nokta boşluğu, avatar↔logo (kapatıldı), tahta filigranlarının puntosu/fontu + header avatar hizası (Parça 106), filigranların taşların altında kalması (Parça 107), Setup'taki parantezli puanın kaldırılması ve tahta↔raf boşluğu (ikisi web-only, port kanonik alındı) — **17 Ağu'daki bu kümenin TAMAMI aynı gün cihazda koşuldu ve geçti, sıfır bulgu.** Turdan iki YENİ web işi çıktı (Hesap Ayarları fotoğraf butonu: tam genişlik + kalın; raf başlığındaki swap aksiyon metninin kaldırılması) — **17 Ağu'da PR #282 ile `main`'e merge edildi**, deploy sonrası tek bir bakışla teyit edilecek |
| 1 · Oyun (offline çekirdek) | ✅ | Parça 15/20/21/22 buradan çıktı |
| 2 · Hesap (auth) | ✅ | **9-12 (deep link) FAZ B'ye ertelendi** |
| 3 · Bulut kayıtları | ✅ | 6/6 — Parça 29 |
| 4 · Biten oyun kayıtları / istatistik | ✅ | Parça 33; OHP çapraz kontrolü Parça 63 |
| 5 · Oyun geçmişi | ✅ | Parça 35, sonra 67/68 ek turlar; **17 Ağu: ağ hatası maddesi (Parça 90) de koşuldu** |
| 6 · Paylaşma | 🟡 | görsel düzeltmesi koşuldu (Parça 84); **iPad ankrajı (Parça 86) gerçek iPad ister → FAZ B** |
| 7 · Son Oynadıklarım | ✅ | 16 Ağu (Blok 7) |
| 8 · Dayanıklılık (uçak modu) | ✅ | 8.2/8.3/8.5/8.6 — Parça 43-46; 16 Ağu: uçak modunda ÇIK–GİR hamleyi siliyordu (Parça 105) → düzeltme **aynı gün cihazda doğrulandı** |
| 9 · Görüş Bildir | ✅ | **17 Ağu: bölümün TAMAMI koşuldu, sıfır bulgu** (Parça 48'in "kapatmak da formu açar" düzeltmesi dahil). "Üyelik teklifi → kayıt" ikinci turda gerçekten tamamlandı: `T4` açıldı, `signup_channel='form'`, ve misafirken oynanan oyun kuyruktan hesaba doğru işlendi (oyun 10:08, hesap 10:10 — `created_at` gerçek bitiş anını taşıdığından kayıt kronolojik doğru yere oturdu, `platform='app-web'`) |
| 10 · Arkadaşlar | ✅ | tamamı (11 Ağu) + moderasyon geri alma, iki yol (14 Ağu, Parça 91) |
| 11 · Canlı oyun | ✅ | 14 Ağu: davet/kabul + tahta koşuldu (Parça 95, 5 bulgu). **16 Ağu: mesajlaşma alt bölümünün 14 maddesi de koşuldu — hepsi geçti, sıfır bulgu** (Parça 11/100/102/104'ün doğrulama sınırları kapandı). **17 Ağu: ret + hesap değişimi de koşuldu — sıfır bulgu.** **17 Ağu akşamı: SQL isteyen son iki madde de koşuldu (süresi dolmuş davet + 48 saat sıra aşımı, iki dalıyla) — bölüm TAMAMEN kapandı, sıfır bulgu** |
| 12 · Hesap Ayarları | ✅ | avatar RLS + küçültme uçtan uca (Parça 82/83) |
| 13 · k-lig ödül & rütbe | ✅ | 12 Ağu (Parça 66) |

**FAZ B (gerçek native iOS/Android): HİÇ BAŞLAMADI** — ön koşulları bile
yapılmadı (imzalama anahtarı, Apple Developer üyeliği, `assetlinks.json`).
Oraya ertelenmiş bilinen maddeler: `kelimeki://` deep link'leri (davet +
şifre sıfırlama + kayıt onayı kanalı), paylaş sayfasının iPad popover
ankrajı (Parça 86), HEIC seçimi ve galeri izni reddi (Parça 87).

> **17 Ağustos 2026 — kayıt onayı deep link'inin YOKLUĞU cihazda bizzat
> gözlendi (bulgu değil, ertelemenin somut bedeli):** portta misafirken
> Görüş Bildir'den e-posta verilip üye olununca, onay e-postasındaki bağlantı
> doğal olarak `kelimeki.com`'u açtı — uygulamayı değil. Üstelik o sekmede
> BAŞKA bir hesap (T2) açık olduğundan kullanıcı önce onun oturumunu gördü.
> Elle app sekmesine geçip yeni hesapla giriş yapmak sorunu çözdü ve
> misafir kuyruğu bozulmadan hesaba işlendi. **Mağazaya çıkışta bu akış
> kabul edilemez** — FAZ B'de `kelimeki://` kanalı kurulunca yeniden
> koşulmalı.


> **17 Ağustos 2026 — Blok 5'in ilk bulgusu: misafir uyarısı YANLIŞ kabukla
> çiziliyordu.** Kullanıcı ekran görüntüsüyle bildirdi: *"çıkan popup
> başlıksız"* — kartın üstünde boş bir bant ve bir ayraç duruyordu.
> **Kök sebep kabuk seçimi:** web'de İKİ ayrı kabuk var (bkz.
> `dialog_shell.dart` başlığı) ve bu uyarı ortak `Modal.tsx`'i KULLANMIYOR;
> `Setup.tsx` içinde elle kurulmuş 384px'lik onay kartı
> (`max-w-sm`/`rounded-2xl`/`p-6`, ✕ köşede `absolute`). Port `KModal`a
> `title: ''` geçmişti — yorumunda niyet doğru yazılıydı ("web'de bu popup
> başlıksız") ama `KModal` başlık bandını boş başlıkla da çiziyor.
> **Düzeltme:** uyarı `KDialogCard`a taşındı; kabuğa opsiyonel bir `onClose`
> eklendi (✕ 28×28, kart kenarından 12px — web `top-3 right-3`; gövdeye
> web'in `pr-6`sı). `onClose` verilmeyen 8 kullanım yeri BİREBİR aynı kaldı
> (dolgu Container'dan çocuğa taşındı, görsel sonuç aynı). Regresyon testi:
> `setup_screen_test.dart` → *"misafir uyarısı KModal DEĞİL web onay kartını
> kullanır"*.
> **Ders:** bir modalı porta taşırken "web'de başlık var mı?" yetmez, önce
> **"web hangi kabuğu kullanıyor?"** sorulmalı — bu projede web'in iki
> kabuğu var ve biri ortak bileşen değil, ekranın kendi içinde.

### Cihaz turu GÖRMEMİŞ, biriken maddeler

Son iki günde düzeltme yapıldıkça listeye madde eklendi ama o maddeler
hiç koşulmadı. Bir sonraki tur bunlarla başlamalı:

- ~~**16 Ağustos (Parça 105) — veri kaybı:** uçak modunda var olan bir
  oyunu aç → hamle yap → çık → **listeyi beklemeden** tekrar gir~~ →
  **16 Ağustos'ta AYNI GÜN cihazda koşuldu ve GEÇTİ** (*"Kaydetti bu
  sefer. Çalışıyor."*), **17 Ağustos'ta regresyon olarak bir kez daha
  koşuldu ve teşhis satırındaki `bekleyen ?` ↔ `bekleyen 0` ayrımı da
  gözle doğrulandı.** Madde `TESTING.md` bölüm 8'de duruyor — **hızlı**
  koşulmalı, beklenirse liste tazelenir ve senaryo hiç oluşmaz.
- ~~**15 Ağustos (Parça 101):** "YAPAY ZEKA İLE" sekme rozeti = "Devam
  Edenler" alt sekmesinin rozetiyle aynı sayı~~ → **16 Ağustos'ta Blok 7
  turunda koşuldu.**
- ~~**15 Ağustos (Parça 100):** susturulmuş gönderende rozet ÇIKMALI (popup
  çıkmamalı)~~ → **16 Ağustos'ta iki platformda da koşuldu** (Parça 103
  turuyla birlikte); **4 kişilik "susturulmamış gönderende ikisi de
  çıkmalı" kontrolü de 16 Ağustos'ta mesajlaşma turunda koşuldu.**
- ~~**16 Ağustos (Parça 102/104):** sekiz diyaloğun web kartına çekilmesi
  (kabul butonu solda, mavi dolgu) + popup'ın zemin dokunuşuyla
  kapanmaması~~ → **16 Ağustos'ta mesajlaşma turunda koşuldu.**
- ~~**14 Ağustos (Parça 96):** çevrimdışı Canlı oyun — açılışta panel +
  hamlede açıklayıcı uyarı (iki platform)~~ → **16 Ağustos'ta Blok 7
  turunda koşuldu** (uçak modu adımlarıyla birlikte).
- ~~**16-17 Ağustos — kök `TESTING.md`'nin İKİ yeni admin bölümü hiç
  koşulmadı:** 9.10 + 9.11~~ → **17 Ağustos'ta koşuldu, ikisi de tamamen
  GEÇTİ** (PR #276 preview'ında, admin hesabıyla). Sıfır bulgu; tek çıktı
  bir ürün isteği oldu: 4 kişiliğe "İkincilik" kutusu (aynı gün eklendi).
  **9.10 bu yüzden yeniden koşulmalı** — YZ Dengesi artık 2 değil 3 kutu ve
  etiketler `Kazanma` → `Birincilik` oldu; bölümün YZ Dengesi maddeleri
  buna göre yeniden yazıldı.
- ~~**14 Ağustos (Parça 95) — Canlı turunun BEŞ düzeltmesi, hiçbiri cihazda
  teyit edilmedi:** boş taslakta OYNA (web Canlı) · gönderim hatasının
  görünmesi (iki platform, uçak modu) · sohbetin ön plana dönüşte
  tazelenmesi (iki platform) · oyun sonu → Oyun Geçmişi (port) ·
  "Çevrimdışı" rozetinin puntosu (web)~~ → **17 Ağustos'ta BEŞİ DE tek
  turda koşuldu, hepsi geçti, sıfır bulgu.** Sohbet tazelemesi bilerek İKİ
  YÖNDE denendi (web→port ve port→web) — kullanıcının ilk raporu tam da
  asimetrikti (bir yön çalışıyor, öteki çalışmıyordu), tek yön koşmak o
  hatayı bir kez daha kaçırırdı.
- ~~**14 Ağustos (Parça 90/92):** girişsiz başlatma uyarısı (bölüm 1) ·
  tahta altındaki "Nasıl Oynanır?" (bölüm 1, İKİ oyun ekranında da) ·
  OHP hizası + başlık ortalama (bölüm 4 ve kök bölüm 10) · ağ hatasında
  "yüklenemedi" mesajı (bölüm 5 ve kök 9.6)~~ → **17 Ağustos'ta DÖRDÜ DE
  koşuldu** (ağ hatası Blok 3'te, kalan üçü Blok 5'te). Tek bulgu misafir
  uyarısının yanlış modal kabuğuydu (yukarıdaki nota bkz.); OHP hizası ve
  başlık ortalama iki platformda yan yana doğrulandı. Kök **9.10** da yeni
  üç kutulu YZ Dengesi hâliyle yeniden koşuldu.
- ~~**17 Ağustos (Parça 106-107 + aynı bloğun web işi)**~~ → **KÜMENİN
  TAMAMI 17 Ağustos'ta iPad'de koşuldu ve GEÇTİ, sıfır bulgu:** tahta
  filigranlarının puntosu/fontu + katman sırası (port, Parça 106/107 —
  köşe rakamları ve X2 aynı boy/font, X3 hücreyi doldurmuyor, filigranlar
  taşların altında) · header avatarının dikey hizası (web, FOTOĞRAFLI
  hesapla) · Setup'ta parantezli puanın olmaması (web) · tahta↔raf
  boşluğu 40px (web porta uyduruldu) · raf başlığı üçlüsü ("7 harf" yok,
  ad BÜYÜK HARF değil, başlık↔taş 13px) · rafın altındaki aksiyon satırı
  (port, Parça 108 — TORBA dahil eşit yükseklik, 6px boşluklar).
  **106/107 için bu tur tek gerçek kanıttı** (Flutter SDK'sız yazıldılar,
  negatif eşleri kurulamamıştı). Aynı turda çıkan İKİ yeni web işi
  (Hesap Ayarları'ndaki fotoğraf butonu: tam genişlik + kalın; raf
  başlığındaki swap aksiyon metninin kaldırılması) **17 Ağustos'ta PR #282
  ile `main`'e merge edildi** — Vercel deploy'undan sonra tek bir bakışla
  teyit edilecek (`mobile/TESTING.md` 0.5).
- ~~**13 Ağustos (Parça 72-89):** içerik sütunu genişliği · GİRİŞ satırı
  konumu · logo altı yazı bloğu · harf aralığı · "+ Yeni …" butonu ve alt
  sekmeler · form alanları · avatarın YUVARLAK vurgusu · "Yükleniyor…"
  takılı kalmama · ActionSheet'te "Vazgeç" yokluğu · ağ hatasında sahte
  başarı yokluğu · "Sıra: X" bandının rengi/gölgesi~~ → **17 Ağustos'ta
  ON BİRİ DE koşuldu ve GEÇTİ, sıfır bulgu.** Bunlar dört gün boyunca
  birikmişti ve hepsi ölçülerek yazılmış (derlenmiş CSS + Chromium)
  düzeltmelerdi — cihaz turu hiçbirinde bir sapma bulmadı.

- **17 Ağustos (Parça 109) — YZ'nin sağ-alt köşe handikabı:** 2 kişilik
  bir oyunda YZ'nin İLK hamlesi artık evden sola/yukarı da uzayabilmeli
  (bkz. `mobile/TESTING.md` bölüm 1). Ölçüm boş tahtada yapıldı, gerçek
  oyun akışında gözle teyit edilmedi; ayrıca bu parçanın Dart yarısı
  Flutter SDK'sız bir oturumda yazıldığından `dart run test/run_all.dart`
  hiç koşulmadı — CI dışında kanıtı yok.

- **18 Ağustos (Parça 113-114) — yeni rütbe rozeti + içindeki yeni font
  (M PLUS Rounded 1c 800; harf TOFU olmamalı, iki platformda aynı
  görünmeli — özellikle Ç/Ş ve banner'ın `+1000`'i):** k-lig listesi (18px),
  Skor Kartı/oyuncu kartı başlığı (34px) ve kutlama/düşüş banner'ı (76px)
  artık dalgalı disk + kurdele; eski tırtıklı mühür hiçbir yerde kalmamalı,
  küçük rozette halka YOK, banner'ın rakamlı glyph'lerinde de yok. Web ile
  yan yana bak (iki dosya elle senkron). Parça yazılırken Flutter SDK
  olmadığından Dart yarısı yalnızca CI ile doğrulandı.

- **18 Ağustos (Parça 115) — mühür artık İSİMLERİN yanında, yedi yüzey:**
  hesap menüsü başlığı (18px) · Skor Kartı (20px) · oyuncu kartı (20px) ·
  Setup'taki hesap koltuğu (18px) · Arkadaşlar'ın ÜÇ sekmesi (18px) ·
  "+ Yeni Canlı Oyun" arkadaş seçici (18px) · oyun daveti katılımcıları
  (16px). Skor kartlarında artık İKİ mühür var (34px başlık + 20px isim),
  ikisi aynı kademeyi göstermeli. Ayrıca "puan bilinmiyor" ile "0 puan"
  ayrımı: liste açılırken bir an için herkesin yanında Çaylak BELİRMEMELİ,
  YZ/misafir koltuğunda mühür HİÇ olmamalı. Bu parça da Flutter SDK'sız
  bir oturumda yazıldı — Dart yarısının tek kanıtı CI.

- **19 Ağustos (kozmetik metin turu) — "Nasıl Oynanır?"ın Hızlı Başlangıç'ında
  üç madde web'de yeniden yazıldı, port AYNI PR'da birebir güncellendi:**
  bağlanma maddesinin parantezi sona alındı ("… bağlanmalıdır. (Senin veya
  rakibinin)"), bonus maddesi "ikiye, üçe" → **"ikiye veya üçe"**, TDK
  maddesine **"(Birkaç istisna dışında)"** eklendi. **`help_text_parity_test`
  bunu YAKALAMAZ** — o yalnızca bölüm başlıklarını ve madde ikonlarını
  karşılaştırıyor (kendi dosya başlığında "var olan bir paragrafın İÇİNDEKİ
  cümle değişimi" açıkça sınır olarak yazılı), yani cümle senkronu ELLE
  yapılmak zorunda. Aynı turda `kelimeki_core`'un `validator.dart`'ındaki
  yorum "sınır vergisi" → "bölge vergisi" olarak web'le hizalandı (kök
  `CLAUDE.md` → "Bölge vergisi" maddesindeki terminoloji notu: `sınır ihlali`
  EYLEM, `bölge vergisi` BEDEL — üçüncü bir terim üretme). Kod davranışı
  değişmedi. Bu parça da Flutter SDK'sız bir oturumda yazıldı — Dart
  yarısının tek kanıtı CI.
  Aynı turda Detaylı Kurallar'ın "Genel Bakış" paragrafındaki son cümle de
  iki tarafta birden netleştirildi: rakibin KELİMESİNE değmek tek başına
  vergi doğurmuyor, karar yalnızca BÖLGE temasına bakıyor (`validator`ın
  `computeInvasionSplit`i taşa değil `computeAllTerritories` kümelerine
  bakar) — yani hiçbir bölgeye ait olmayan izole bir rakip taşına bitişik
  oynamak ücretsiz.

- **19 Ağustos — isim yanındaki mühürler isme yaklaştı (kullanıcı isteği,
  web + port aynı PR):** sekiz yüzeyde de `SizedBox(width: 6)` → **4**
  (web `gap-1.5` → `gap-1`). Mühür BOYLARI (16/18/20) değişmedi. Yan fayda:
  `player_score_card_modal.dart` zaten 6px kullanıyordu ama web'in aynı
  yeri 8px'ti (ad+mühür+arkadaşlık ikonu tek `gap-2` kabındaydı) — web o
  turda ad+mühür için ayrı bir sarmalayıcı aldı, yani sessiz bir ayrışma
  kapandı. Mevcut testler mührün yalnızca ismin SAĞINDA olduğunu sınıyor
  (birebir piksel değil), o yüzden düşen bir test yok; ölçüm web tarafında
  yapıldı, Dart yarısının kanıtı yine CI.

Liste bir gün BOŞALIRSA öyle kalmasını bekleme: yeni bir düzeltme
yazıldığında buraya yine madde eklenmeli (kural değişmedi: yazıldığı gün
cihazda görülmemiş her düzeltme burada birikir).

~~**Özel uyarı — kök `TESTING.md` 9.6 ilk koşuşunda DÜŞTÜ**~~ →
**17 Ağustos'ta baştan koşuldu ve GEÇTİ** (negatif eşi dahil: admin →
Üyeler → sıfır oyunlu bir üyenin kartı → çevrimİÇİ boş liste normal mesaj
veriyor). Tur, kodda değil **belgede** bir hata çıkardı: 3. madde
çevrimdışı + boş önbellekte "yüklenemedi" bekliyordu, oysa aynı gün
eklenen çevrimdışı öneri (`offlineNode`) araya giriyor ve "Hemen oyun aç."
çıkıyor; ayrıca "Arkadaşınla → Son Oynananlar" çevrimdışı HİÇ
çizilmiyor (`LiveGamesTab`'ın `!online` dalı üç alt sekmeyi birden kısa
devre yapıyor), yani orada "eski liste kalmalı" beklentisi anlamsızdı.
Madde düzeltildi. **Bu, "koşulmamış madde bir şey kanıtlamaz"ın somut
örneği** — 14 Ağustos'tan 17 Ağustos'a kadar belge yanlıştı ve kimse
görmedi.

### Sıradaki tur için öneri

**Bölüm 11 KAPANDI** (17 Ağustos): üç turda bitti — davet/kabul + tahta
(14 Ağu, beş bulgu → Parça 95), mesajlaşma (16 Ağu, sıfır bulgu), ret +
hesap değişimi (17 Ağu, sıfır bulgu). Aynı turda Parça 95'in beş
düzeltmesinin hepsi de cihazda teyit edildi, yani **14 Ağustos'tan beri
biriken Canlı borcu tamamen kapandı.**

**17 Ağustos'ta DÖRT küme birden kapandı:** ağ hatası/offline (kök 9.6 +
mobil bölüm 5 + bölüm 8), Canlı (bölüm 11), Görüş Bildir (bölüm 9) ve —
akşam, Blok 5 + Blok 6 ile — Parça 90/92'nin kalanları ve **görsel yan
yana karşılaştırmanın TAMAMI (bölüm 0.5)**.

### FAZ A1'İN CİHAZ TURLARI BİTTİ (17 Ağustos 2026)

Koşulacak cihaz maddesi KALMADI ve **ortak SQL turu da aynı gün koşuldu**
(aşağıya bkz.). Geriye tek bir şey kaldı ve o da bir cihaz turu değil:

1. ~~Merge bekleyen iki web işi~~ → PR #282 ile `main`'de; ~~ortak SQL
   turu~~ → koşuldu (aşağı).
2. **FAZ B** (gerçek native iOS/Android) — ön koşulları hâlâ yapılmadı
   (imzalama anahtarı, Apple Developer üyeliği, `assetlinks.json`).
   Bölüm 6'nın 🟡'si de oraya bağlı (iPad paylaş ankrajı, Parça 86).
   **17 Ağustos 2026 — üçü de kapalı olduğu için gerçek tur ERTELENDİ**
   (kullanıcı kararı: Android cihaz yok, Apple üyeliği şimdilik
   aktifleştirilmeyecek). O gün yalnızca bir TRİYAJ yapıldı:
   `mobile/TESTING.md` → "Appetize triyajı" — hangi maddenin emülatörde
   gerçekten kanıtlanabildiği, hangisinin yalnızca yanlış güven vereceği
   madde madde ayrıldı. **Android imzalama anahtarı bilerek ÜRETİLMEDİ:**
   üretim anahtarı kaybedilirse uygulama Play Store'da bir daha asla
   güncellenemez, yani üretimi/yedeklenmesi hesap sahibinin kararı —
   `assetlinks.json` de onun SHA-256'sına bağlı olduğundan sırayla
   beklemede.

Şu an bilinen bir veri kaybı yolu YOK (Parça 105 aynı gün doğrulandı).

### Ortak SQL turu — koşuldu ve GEÇTİ (17 Ağustos 2026)

Bölüm 11'in kalan iki maddesi, satırların Supabase MCP ile geriye
tarihlenmesini gerektiriyordu; üç senaryo kurulup süpürme GERÇEK
uygulamadan (T1 → "Arkadaşınla") tetiklendi. Üçü de tahminlerle birebir
uyuştu:

| Senaryo | Ölçülen sonuç |
|---|---|
| Süresi dolmuş davet (`create_online_game` ile kurulan tek kullanımlık T1→T2, `created_at` −8 gün) | `online_games.status` → `abandoned`; `game_invites` satırı tasarım gereği `pending` kaldı, davet hiçbir kovada görünmedi |
| 2 kişilik sıra aşımı (T1↔T2, sıra T1'de) | Oyun `finished`/`end_reason='surrender'`; T1 skor 0 + raf torbaya (**70 → 77**, `bag_count` 77); T2 22 → 10 (kendi raf puanı düşüldü); `games` satırları T2 rank 1 win / T1 rank 2 lose+surrendered; T1 k-lig **10 → 8**, oyun sayısı 12 → 13; `net._http_response` **`{"ok":true,"sent":1}`** ve mail T1'in gerçek kutusuna ulaştı |
| 4 kişilik sıra aşımı (T1+T2+T3+YZ, sıra T3'te) | Oyun `active` KALDI; T3 teslim/skor 0/raf 0; sıra 2 → **3** (YZ koltuğu), tur 2 → 3, `turn_deadline` +48s; torba **65 → 72** ve `bag_count` **72**; **mail GİTMEDİ** |

**Bu tur İKİ eski doğrulama sınırını birden kapattı** (ayrıntı kök
`CLAUDE.md`): `notify-turn-timeout-surrender`ın pg_net → Edge Function →
Brevo zinciri bugüne dek yalnızca rollback'li bir simülasyonla
gösterilmişti; `check_turn_timeout_bag_count` düzeltmesinin kanıtı da
yalnızca migration'ın kendi backfill'iydi.

**Kurulum disiplini — bir daha koşulursa aynısı geçerli:** (a) test daveti
`create_online_game` RPC'siyle kuruldu, istemciden DEĞİL — davet e-postası
istemciden gönderildiğinden bu yol kimseye mail atmıyor; (b) **gerçek bir
kullanıcının bekleyen daveti ASLA kullanılmaz** (o turda üretimde tam da
öyle bir davet vardı ve süpürme onu da iptal ederdi) — kurulumdan sonra
"süresi geçmiş görünen satırların HEPSİ benim mi?" diye ayrı bir tarama
koşuldu; (c) tek kullanımlık davet doğrulamadan sonra silindi, iki gerçek
test oyunu ise (artık meşru birer oyun kaydı olduklarından) bırakıldı.

**İki dalı da koşmak ŞART, biri ötekini kanıtlamaz:** `bag_count` hatası
İKİ dalda da vardı ama yalnızca 4 kişilikte kullanıcıya görünüyordu; mail
ise yalnızca 2 kişilik dalda üretiliyor — tek dal koşmak, fonksiyonun maili
KOŞULSUZ gönderip göndermediğini de ayırt edemezdi.

## Sonraya Bırakılan İşler (mobil)

Kök `CLAUDE.md`'nin "Web'de Yapılacak İşler" listesinin mobil karşılığı —
kararı verilmiş ama henüz yapılmamış işler. Bir madde uygulanınca buradan
silinip kendi tarihli parça notuna taşınır.

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

## Sıradaki Fazlar (mutabık kalınan sıra)

1. ~~Backend güvenilirlik migration'ları~~ — TAMAMLANDI (5 Ağustos 2026,
   bkz. "Backend Hazırlığı" bölümü).
2. ~~`mobile/app/` Flutter iskeleti~~ — TAMAMLANDI (5 Ağustos 2026, bkz.
   "Flutter Uygulama İskeleti" bölümü; açık kalanlar: assetlinks.json,
   iOS Universal Links, gerçek cihaz doğrulaması).
3. ~~Depolama katmanı~~ — TAMAMLANDI (6 Ağustos 2026, bkz. "Depolama
   Katmanı" bölümü; açık uçlar orada listeli: kaydet/yükle UI bağlantısı,
   terk cezası üst katmanı, sunucuya flush).
4. **UI portu — PARÇA PARÇA ilerliyor** (kullanıcı kararı, 6 Ağustos 2026);
   admin paneli/PWA/LandscapeHint/csvExport bilinçli olarak YOK.
   - ✅ **Parça 1 — tahta render katmanı** (`lib/src/ui/game/`):
     `player_colors.dart` (PLAYER_COLORS hex'leri birebir; renk core'a
     girmez, UI'da yaşar), `outline.dart` (outline.ts'in birebir portu —
     çıktı SVG dizesi değil ui.Path; içbükey köşe yuvarlatma dahil),
     `tile_widget.dart` (rack/placed/board varyantları, joker ★),
     `board_widget.dart` (bölge tonları + dış hatlar, köşe numarası ve X2
     filigranları, X3 hücresi, ev işareti — web'deki HomeMark SVG path'i
     birebir, son-hamle koyulaştırması, MoveOverlay çerçevesi + puan
     rozeti). Ana ekrandaki YZ vs YZ motor testi artık canlı tahtayı
     çiziyor. Doğrulama: `board_render_test.dart` gerçek fixture
     state'lerini (reducer_ai4 finali — teslim olmuş oyuncunun hatsız
     kalması dahil; reducer_ai2 + overlay) çizip taş sayısını doğruluyor
     ve `build/screenshots/`a PNG üretiyor. Bilinçli eksikler:
     yerleştirme nabız animasyonu yok, alt bilgi şeridi
     (Hamleler/Mesajlaşma) ekran parçasının işi.
   - ✅ **Parça 2 — raf + dokunarak yerleştirme + oynanabilir GameScreen:**
     `rack_widget.dart` (Rack.tsx portu; sürükleme prop'ları bilinçli yok),
     `wild_letter_sheet.dart` (WildcardModal portu — alttan sayfa; editing
     modu + "Geri Al"), `move_status.dart` (App.tsx moveStatus useMemo'sunun
     portu), `game_screen.dart` (minimal oynanabilir ekran: basit skor
     satırı, liveMessage kuralı — geçersiz sebep kırmızı/geçerliyken yeşil,
     tahta + canlı çerçeve, raf, OYNA/PAS GEÇ/GERİ AL/KARIŞTIR, bölge
     vergisi "Sınır İhlali!" onayı, pas onayı). Web davranış paritesi:
     yerleştirilmiş taşa dokunmak geri alır AMA jokere dokunmak seçiciyi
     editing modunda yeniden açar (taş geri alınmaz); joker harf seçilmeden
     tahtaya konmaz. HomeScreen'e "Oyna: Sen vs Yapay Zeka (deneme)" girişi
     eklendi — yerel YZ oyunu cihazda UÇTAN UCA OYNANABİLİR durumda.
     Doğrulama: `game_screen_test.dart` — KELİME dizme (+7 rozeti, skor,
     longestWord), geçersiz dizilim mesajı ('"KM" geçerli bir kelime
     değil.'), taşa-dokun-geri-al, joker akışının tamamı; ekran görüntüsü
     `build/screenshots/game_screen_kelime.png`. Bilinçli eksikler: taş
     değiştirme (swap) UI akışı, kelime anlamı modalı, GameOver ekranı
     (şimdilik KAPAT), gerçek GameHeader; test ortamı notu: ★ (joker)
     SDK Roboto alt kümesinde yok — ekran görüntüsünde kutu görünür,
     cihaz fontlarında sorun değil.
   - ✅ **Görsel birebirlik düzeltmeleri (6 Ağustos 2026, kullanıcı web/app
     ekran görüntüsü karşılaştırmasıyla bildirdi):** üç fark kapatıldı.
     (1) **Sayfa zemini web'de BEYAZ** (`colors.bg=#FFFFFF`) — ilk portta
     #EDF1F7 kullanılmıştı; tahtanın beyaz sol-üst parlaması o zeminde
     "ince beyaz çizgi", koyu gölgeler "kalın gri bant" gibi okunuyordu.
     Zemin beyaza çekilince web'deki denge kendiliğinden geldi (gölge
     DEĞERLERİ zaten birebirdi — ders: gölge algısı zemine bağlı, değerle
     oynamadan önce zemini doğrula). (2) **Nömorfik iç gölgeler:**
     `neo_box.dart` — CSS inset box-shadow'un Flutter karşılığı (RRect'e
     kırpılmış alanda, kaydırılmış RRect'in dışı blur'lanır; sigma=blur/2).
     Board.tsx'in dört hücre stili (tarafsız/bölge/altın/merkez) iç+dış
     gölge değerleriyle birebir taşındı. (3) **Fontlar:** web'in üç ailesi
     (tailwind: sans=Space Grotesk, mono=Space Mono, tile=Nunito 800)
     Google Fonts statik TTF'leriyle `assets/fonts/`a gömüldü; tema
     varsayılanı Grotesk, taş harfleri Nunito 800 + web'in
     -webkit-text-stroke'unun karşılığı stroke katmanı (rafta 0.7, tahtada
     0.35), puan üst simgeleri/raf başlığı/skor kutuları SpaceMono. Taş
     harf rengi tahtada HER ZAMAN #1B2430 (web text-tile-letter) — ilk
     port oyuncu rengini kullanıyordu, düzeltildi. **Joker ★ Material
     ikonuyla** çizilir (Nunito'da U+2605 yok; web'de tarayıcının yedek
     fontu basıyor, Flutter'da güvenilir yol ikon). **Test dersi:**
     flutter_test pubspec fontlarını OTOMATİK YÜKLEMEZ — ekran görüntüsü
     üreten testler `support/test_fonts.dart` ile uygulamanın gerçek
     TTF'lerini FontLoader'dan yükler, yoksa her metin Ahem bloğu olur.
     Kontur katmanı her taş harfini iki Text yaptığından testlerde
     `find.text(...).first` gerekir.
   - ✅ **Tahta dış gölgesi "Orijinal gibi" düzeltmesi (6 Ağustos 2026,
     kullanıcı IMG_0853 ile bildirdi — önceki düzeltmeden sonra bile alt/sağ
     gölge "kalın gri levha" gibi duruyordu):** iki ayrı, üst üste binen kök
     sebep bulundu; ikisi de değerlerle değil MEKANİZMAYLA ilgiliydi.
     (1) **Ekran görüntüsü tuzağı:** beyaz zemin `RepaintBoundary`'nin
     DIŞINDAYDI — PNG'de gölgeler saydam zemin üzerine ham yarı-şeffaf gri
     olarak kaydedilip 24px'te kesiliyordu, yani görüntüdeki "levha"nın bir
     kısmı gerçek render değil yakalama artefaktıydı. Kural: gölge içeren bir
     ekran görüntüsünde opak zemin (ColoredBox) boundary'nin İÇİNDE olmalı ve
     pay (padding) gölgenin tam sönümüne yetmeli (burada 90px).
     (2) **Flutter `BoxDecoration.boxShadow` CSS box-shadow'un birebir
     karşılığı DEĞİL:** hem belirgin şekilde daha yoğun/koyu boyuyor hem de
     katman sırası TERS — CSS'te listedeki İLK gölge en üstte, Flutter'da son
     çizilen (listedeki son) üstte kalıyor. Çözüm `neo_box.dart`taki
     `CssShadow` + `ShapeDecorationWithCssShadows`: özel bir BoxPainter,
     gölgeleri sigma=blur/2 ile ve listeyi TERS sırayla (CSS semantiği)
     çizip üstüne dolguyu basar. `board_widget.dart`ın konteyneri artık
     web'in üçlü gölgesini (`8,8,20 rgba(163,177,198,.7)` +
     `-4,-4,14 rgba(255,255,255,.9)` + `0,20,60 rgba(163,177,198,.5)`)
     bu decoration'la taşıyor. Doğrulama piksel profiliyle: web ekran
     görüntüsünde tahtanın alt kenarından aşağı inen gri profil tepe R=197
     ve ~75px'te 233→255 yumuşak sönüm; düzeltme sonrası app PNG'sinde tepe
     R=198 ve aynı sönüm eğrisi — göz kararı değil ölçümle kapatıldı (bkz.
     kök CLAUDE.md'deki "ölçmeden teşhis koyma" dersleri). **Ders:** CSS
     gölge/efekt değerlerini Flutter'a "aynı sayıları yaz" diye taşımak
     yetmez — boyama modelinin kendisi farklıysa (yoğunluk, katman sırası,
     sigma tanımı) web'in çıktısı ölçülüp Flutter tarafında aynı ÇIKTIYI
     üreten mekanizma kurulmalı.
   - ✅ **Mesaj satırı tahtanın ALTINA taşındı (6 Ağustos 2026, kullanıcı
     bildirdi):** ilk portta mesaj skor satırıyla tahtanın arasındaydı; web'de
     gerçek sıra Board → mesaj → Rack (`App.tsx` ~1234, `w-full max-w-[680px]`
     bloğunun ilk çocuğu). Ayrıca web mesajı `font-mono` (Space Mono) basar —
     app'te de `fontFamily: 'SpaceMono'` yapıldı.
   - ✅ **Parça 3 — taş değiştirme akışı + GameOver ekranı + Torba dökümü +
     web buton düzeni (6 Ağustos 2026):**
     - **Buton düzeni artık web'le aynı yapıda** (`App.tsx` ~1257-1355): raf
       satırı = Raf (flex) + sağında OYNA (oyun bitmişse YENİ OYUN — pop ile
       HomeScreen'e döner; web'deki INIT/"Yeni Oyun Aç"ın eşleniği); alt
       satır normalde PAS GEÇ / DEĞİŞTİR / KARIŞTIR / GERİ AL / TORBA N,
       swap modunda DEĞİŞTİR (N) (altın #B7791F) / VAZGEÇ. Swap modunda
       OYNA hiç görünmez (web `!state.swapMode` koşulu). TORBA hiç disable
       olmaz (web'de de öyle — YZ sırasında/oyun bitince de açılır).
       DEĞİŞTİR torba boşken pasif. Raf satırı `IntrinsicHeight` içinde —
       `CrossAxisAlignment.stretch` Column içinde sınırsız yükseklikle
       patlar (test yakaladı), buton raf kartı boyuna böyle uzatılır.
     - **Swap akışı:** DEĞİŞTİR → `ToggleSwapModeAction` (reducer taşları
       önce rafa geri çağırır); raf dokunuşu swap modunda
       `ToggleSwapTileAction` (normalde `SelectTileAction`); onay
       `ConfirmSwapAction`. UI'da yeni kural mantığı YOK — hepsi core'da
       zaten vardı, bu parça yalnızca butonları bağladı.
     - **`game_over_modal.dart`** — `GameOver.tsx` portu: kazanan başlığı
       (mono 26/2px; beraberlikte altın "BERABERE", değilse kazanan
       renginde "{AD} KAZANDI"), `rankPlayers` sırasıyla satırlar
       (`player_badge.dart` = PlayerBadge.tsx portu, rank. ad, (TESLİM)
       rozeti, KALAN −N, TOPLAM skor oyuncu renginde), altta Toplam hamle.
       `GameScreen` oyun bittiği an modalı BİR KEZ açar (`_gameOverShown`
       bayrağı, web `gameOverDismissed`in eşleniği) — KAPAT'la kapatınca
       tahta görünür kalır, raf satırında YENİ OYUN belirir. Web'deki
       "Oyun Geçmişi"/"Görüş Bildir" linkleri BİLİNÇLİ eksik (hamle
       geçmişi modalı ve görüş formu sonraki parçalar).
     - **`remaining_tiles_modal.dart`** — `RemainingTilesModal.tsx` portu:
       core `remainingTiles` (dağılım − tahta − bakanın rafı), 5 sütun raf
       taşı + ×adet, tükenen harf %30 opak. `myIndex` = `_rackIndex`
       (web'deki not: `state.current` DEĞİL, YZ sırasında da açılabilir).
     - **`GameController.restore(GameState)`** eklendi — kayıttan devam /
       testte fixture'la başlama için dispatch dışı tek yol (web
       RESUME_SAVED eşleniği); GameOver testi `reducer_ai4` fixture'ının
       final state'iyle bunu kullanıyor.
     - **Web `rackPlayer` kuralı porta geldi:** sıra YZ'deyse raf yine
       İNSANIN rafını gösterir (`_rackIndex`) — önceki parça
       `state.current`ın rafını gösteriyordu (YZ sırasında YZ'nin rafı
       görünürdü, gizlilik değil ama web davranışından sapmaydı).
     - Doğrulama: `game_screen_test.dart` +5 test (swap seç/onayla/sıra
       devri/bag sabit/consecutivePasses; VAZGEÇ işlemsiz çıkış; TORBA
       dökümü 93 taş; GameOver kazanan+Teslim+YENİ OYUN; GameOver ekran
       görüntüsü `build/screenshots/game_over.png`, swap modu
       `game_screen_swap.png`). 29/29 yeşil.
   - ✅ **Parça 4 — gerçek GameHeader: logo + akıcı skor kutuları (6 Ağustos
     2026):**
     - **Logo tek kaynaktan:** `scripts/generate-logo-paths.mjs` artık web
       `LogoMark.tsx`'in yanında `mobile/app/lib/src/ui/game/
       logo_mark_data.dart`ı da üretiyor (aynı Caveat Bold glyph
       outline'ları; Caveat fontu uygulamaya HİÇ gömülmez) — logo değişirse
       `npm run generate-logo-paths` iki tarafı birden günceller, elle
       senkron yok. Üretici koşulduğunda web dosyasının değişmediği `git
       diff` ile doğrulandı. `logo_mark.dart`taki `parseSvgPath` yalnızca
       üreticinin ürettiği MUTLAK M/L/Q/C/Z komutlarını çözer ve bilinmeyen
       girdide FIRLATIR — üretici bir gün farklı komut üretirse sessiz bozuk
       çizim yerine test anında yakalanır (`game_header_test.dart` path'i
       gerçekten çözüp viewBox sınırlarıyla karşılaştırıyor).
     - **`game_header.dart`** — GameHeader.tsx portu: `_fluid()` web'in
       `clamp(min, calc(a+b·vw), max)` sisteminin birebir eşleniği (aynı
       katsayılar, 375→min/465→max uç noktaları); kutu = tint zemin + base
       çerçeve, aktif 2px / pasif 0.5px; İNSAN kutusu geniş, YZ kutusu dar
       ("YZ N" etiketi). **Teslim gösterimi — İKİ TARAF BİRLİKTE
       netleştirildi (kullanıcı kararı, aynı gün, üç adımda):** ilk sürüm
       web'in o günkü davranışını (soluklaştırma + küçük punto) izliyordu;
       kullanıcı önce "diğerleriyle aynı boy/tasarımda olsun, yalnızca puan
       alanında Teslim yazsın" dedi (soluklaştırma kalktı), sonra web'in o
       anki hâlini görünce nihai karar verildi: **aynı kutu/tasarım + puan
       alanını dolduran TESLİM + %45 soluklaştırma, web'de de app'te de.**
       App: puan satırı skorla AYNI yükseklikte sabit SizedBox, TESLİM
       FittedBox'la sığdırılır, kutu `Opacity(0.45)` ile solgun; test hem
       boy eşitliğini hem yalnızca teslim kutusunun soluk olduğunu ölçüyor.
       Web: `GameHeader.tsx`'e `TESLIM_FONT_SIZE` (11-16px, aynı 375/465
       sistemi) + `lineHeight: SCORE_FONT_SIZE` eklendi (bkz. kök
       CLAUDE.md); isim
       `trUpper` ile (CSS `uppercase`ın Türkçe-farkındalı karşılığı —
       İbrahim→İBRAHİM testte doğrulanıyor). **Çerçeve
       `foregroundDecoration`da** — web'in `border`→`outline` dersinin
       Flutter karşılığı: `BoxDecoration.border` içeriden yer kapladığından
       aktif/pasif kalınlık farkı dar YZ kutusunda skoru kırpardı; ön-katman
       dekorasyonu layout'a hiç dokunmaz. Sığmazsa şerit web'deki gibi yatay
       kaydırılır. `onPlayerTap` opsiyonel (Canlı oyunda skor kartı için,
       web `onPlayerClick`). **UserMenu'nün misafir durumu var (kullanıcı
       "Avatar (menü) eksik" deyince aynı gün eklendi):** sağ uçta web'in
       GIRIS_* akıcı sabitleriyle birebir bir "GİRİŞ" düğmesi
       (`_GirisButton`) — kaydırma kabının DIŞINDA (web'in "UserMenu
       overflow kabının içindeyken dropdown kırpılıyordu" dersi). Dokununca
       dürüst bir "hesap/Canlı oyun sonraki sürümde" diyaloğu gösterir;
       sahte giriş formu bilinçli YOK. Oturum-açık durum (avatar + dropdown)
       auth fazının işi.
     - **GameScreen düzeni web akışına çekildi:** AppBar + geçici skor
       satırı kalktı; içerik artık header → tahta → mesaj → raf → butonlar
       olarak TEK scroll akışında diziliyor, artan boşluk web'deki gibi en
       alta düşüyor (önceden tahta Expanded'ta tek başınaydı ve boşluk
       tahtayla mesajın ARASINA giriyordu). Logo dokunuşu oyundan çıkarır
       (şimdilik `Navigator.pop` — kaydet/yükle parçası gelince web'in
       "kaydet ve Setup'a dön" davranışına bağlanacak).
     - **İki Material tuzağı:** (1) `ButtonStyle.textStyle` tema fontunu
       MİRAS ALMAZ — fontFamily verilmezse testlerde metin Ahem bloğuna
       düşer (OYNA butonunda yaşandı); (2) buton bir satırda boyuna
       uzatılınca Material'ın stadium varsayılanı onu dev bir hap/daireye
       çevirir — web'in rounded-md/lg görünümü için her butona açık
       `RoundedRectangleBorder` verildi.
     - Doğrulama: `game_header_test.dart` (path çözümü + sınırlar,
       bilinmeyen komutta fırlatma, etiketler/logo dokunuşu + ekran
       görüntüsü `build/screenshots/game_header.png`, sığdırma garantisi).
     - **Bulunan test-düzeneği tuzağı (kullanıcı iPhone web ekran
       görüntüsüyle "kutular GİRİŞ'in altına giriyor, web'deki ayarlar
       bozulmadı umarım" deyince bulundu, 6 Ağustos 2026):**
       `tester.binding.setSurfaceSize` YALNIZCA çizim yüzeyini küçültür —
       `MediaQuery` hâlâ 800×600 varsayılan test penceresini bildirir.
       GameHeader kendini 800px'te sanıp TÜM akıcı değerleri maksimumda
       (66px kutu, 36px logo) çizdi, 420px'lik yüzeyde taştı — yani
       paylaşılan ekran görüntülerindeki kırpılma bir UYGULAMA hatası değil
       YAKALAMA artefaktıydı (cihazda MediaQuery doğru, web'le aynı).
       Düzeltme: `support/test_view.dart`teki `setPhoneViewSize`
       (devicePixelRatio=1 + physicalSize + surface birlikte) — MediaQuery
       kullanan HER widget testi bunu kullanmalı, yalnız `setSurfaceSize`
       yetmez. Web tarafının sığdırma ayarlarına HİÇ dokunulmadı (branch'te
       GameHeader.tsx diff'i yalnızca teslim satırı — doğrulandı).
       **Sığdırma garantisi artık ölçülen bir test:** 4 insan koltuğu +
       GİRİŞ 375/390'da, karışık kadro (2 insan + 2 YZ) 375-465'te
       kaydırmasız sığmalı. Bilinçli sınır: 4 insan + misafir GİRİŞ butonu
       (avatardan geniş) ~430px üstünde WEB'DE DE birkaç px görünmez
       kaydırmaya düşer — insan kutusu eğimi (4×25.56vw) genişleme hızını
       aşar, aynı formüller aynı sonucu verir; web bunu overflow-x güvenlik
       ağıyla kabul etmişti, app'te de aynı kabul geçerli.
   - ✅ **Parça 5 — kaydet/yükle bağlantısı (6 Ağustos 2026,
     `local_game_repo.dart`):** Depolama katmanı (LocalSaveStore, Parça
     "storage") artık gerçekten oyuna bağlı. İki sınıf:
     - **`LocalGameRepo`** — misafir slotunun (tek kayıt, web localStorage
       paritesi) politika katmanı. `local_saves` tablosunun TEK
       `TableWriteQueue`'suna sahip (PORT_BRIEF §7): hasSave/savedAtMs/
       loadSave hepsi `read()` üzerinden (bekleyen yazma bitmeden okuma
       yok), GameSession'ın tüm yazmaları `enqueue` üzerinden — web'deki
       DELETE/SELECT yarışı yapısal olarak imkânsız; test bunu end()
       beklenmeden hasSave sorarak kanıtlıyor. `drainAbandonedGames()` =
       web `takePendingAbandonedGame` akışı: LocalSaveStore.load'un 7
       günlük süre aşımında ürettiği terk olaylarını atomik tüketir,
       YALNIZCA `turnCount >= 2` oyunlar için pending_queue'ya
       (`finished-game`, 7 gün TTL) `{type:'abandoned-surrender', savedAt,
       state}` kaydı kuyruklar — payload TAM GameState taşır ki senkron
       fazı gerçek `games` satırını (buildGameRecord portu) oradan
       üretebilsin; sunucuya flush BİLİNÇLİ olarak o fazın işi.
     - **`GameSession`** — bir GameController'ı kalıcılığa bağlar:
       autosave `play && !isGameOver` HER değişimde (web autosave'i gibi
       koşulsuz — turnCount eşiği kayıtta DEĞİL çıkışta), `isGameOver` →
       slot silinir, `end()` (bilinçli çıkış: logo/YENİ OYUN dönüşü)
       `turnCount < 2` ise slotu İZ BIRAKMADAN siler (web handleLogoClick
       eşiği); uygulama kill edilirse (end çağrılmaz) autosave kalır,
       sonraki açılışta devam edilir — üçü de testli.
     - **HomeScreen (hâlâ iskelet, gerçek Setup ayrı parça):** açılışta
       `loadSave()` (süresi dolanı olaya çevirir) + `drainAbandonedGames()`
       süpürmesi — web'in "Setup her göründüğünde" refleksi. Kayıt varsa
       "Devam Eden Oyun" kartı (Senin Hamlen Bekleniyor + "N gün/saat sonra
       silinecek" — misafir dili, "teslim sayılacak" DEĞİL) + web'in
       anti-kaçış kuralı: kayıt bitmeden yeni oyun butonu HİÇ gösterilmez.
       "Devam Et" → `loadSave()` (null dönerse tam o an süresi dolmuş —
       liste tazelenir) → `controller.restore()` → GameScreen. Oyun
       ekranından HER dönüşte `session.end()` + durum tazelenir. Motor
       testi (YZ vs YZ) kalıcılığa bilerek BAĞLI DEĞİL (misafir slotunu
       kirletmesin).
     - Doğrulama: `local_game_repo_test.dart` (5 test, gerçek SQLite ffi +
       enjekte saat): autosave+roundtrip (multiSession işareti dahil),
       bitişte silme, 7 günlük terk (turnCount>=2 ceza kuyruklanır, <2 iz
       bırakmaz; ikinci 8 günlük sıçramada eski cezanın kuyruk TTL'ine
       takılıp düşmesi de web PENDING_EXPIRY paritesi olarak doğrulandı),
       kill-sonrası devam, yazma-okuma yarışı. 37/37 yeşil.
   - ✅ **Mesaj satırı geçerli taslakta türetiliyor (6 Ağustos 2026,
     kullanıcı web Canlı oyunda üç ekran görüntüsüyle buldu — üç istemci
     aynı gün aynı kurala çekildi):** `state.message` "son yazan kazanır"
     bir alan; taş seçmeden boş hücreye dokunmak "Önce bir harf seç."i
     yazıp geçerli taslağın "Oyna tuşuyla kelimeyi onayla."sını ezebiliyor
     (web Canlı'da senkron da mesajı silip satırı rakibin son hamlesine
     düşürüyordu). Kural: taslak GEÇERLİYSE metin state.message'tan okunmaz,
     türetilir. App'te testli: reducer'a bayat mesaj yazılsa bile satır
     türetilmiş metni gösterir (`game_screen_test.dart`). Ayrıntı: kök
     CLAUDE.md, "Mesaj satırı — geçerli taslakta metin artık TÜRETİLİYOR".
   - ✅ **Parça 6 — Setup ekranı (6 Ağustos 2026,
     `lib/src/ui/setup/setup_screen.dart`):** İskelet HomeScreen SİLİNDİ
     (motor testi/durum paneli göreviydi, tamamladı) — `app.dart` artık
     SetupScreen'e açılıyor; kalıcılık akışı (LocalGameRepo, süpürme,
     anti-kaçış) HomeScreen'den buraya taşındı. Web `Setup.tsx`'in MİSAFİR
     akışının portu: logo (52px) + tanıtım paragrafı (metin birebir),
     "OYUN TİPİ" sekmeleri (YAPAY ZEKA İLE seçili; ARKADAŞINLA → GİRİŞ
     düğmesiyle aynı dürüst "sonraki sürümde" diyaloğu), "OYUNCU SAYISI"
     2/4, renkli "OYUNCULAR" listesi (tint zemin + base çerçeve +
     PlayerBadge; 1. koltuk `guestPlayerName`='Misafir' + SEN, diğerleri
     "Yapay Zeka N" + YZN — web doStart'ın YZ adlarını AÇIKÇA geçtiği
     kural dahil: 2 kişilikte YZ'nin adı "Yapay Zeka 2", reducer
     varsayılanı "Yapay Zeka" DEĞİL), sözlük hazır olana dek
     "HAZIRLANIYOR…" gösteren OYUNU BAŞLAT. Misafirin tekil kaydı varsa
     form HİÇ çizilmez (anti-kaçış): "DEVAM EDEN OYUN" satırı — avatar
     şeridi (misafir "?" + robot çemberleri; fotoğraflı üye avatarı auth
     fazının işi), "Sıra: X", yeşil "SENİN HAMLEN BEKLENİYOR", web
     `remainingTime`'ın birebir portu kalan-süre etiketi (misafir dili
     "silinecek"; <24 saatte kırmızı + dakika hassasiyeti) + 7 gün
     paragrafı. Altta göze batmayan tek satır teşhis (sürüm · sözlük ·
     sunucu durumu) — iskelet panelden kalan tek iz. Bilinçli eksikler:
     "Nasıl oynanır?" (kurallar ekranı ayrı parça), "Arkadaşınla paylaş"
     (native share ayrı parça). Girişli dallar (cloudSaves, hesap satırı)
     auth fazında (parça 5) tamamlandı; MembershipPerksBox 7 Ağustos
     2026'da (bkz. "MembershipPerksBox — Setup Misafir Kutusu" bölümü).
     **İki test dersi:** (1) sqflite'ın GERÇEK async I/O'su `testWidgets`in
     fake-async bölgesinde ASLA çözülmez — ilk sürüm 10 dakika asılı kaldı;
     depolamaya dokunan her widget-test adımı `tester.runAsync` köprüsünden
     geçmek zorunda (hazırlık, initState zincirinin beklenmesi, dokunuş
     sonrası yükleme). (2) `toUpperCase()` Türkçe'de yasak — 'silinecek'
     noktasız I ile 'SILINECEK' oluyor; test yakaladı, `trUpper` kullanıldı
     (web'de CSS `uppercase` tr locale ile doğruydu, Dart'ta karşılığı
     trUpper). Doğrulama: `setup_screen_test.dart` (4 test: 2/4 kadro +
     ekran görüntüsü `build/screenshots/setup_form.png`; başlatılan oyunda
     Misafir+YZ kadrosu; ARKADAŞINLA diyaloğu; kayıt varken anti-kaçış +
     satırdan devam — turnCount/multiSession korunuyor) +
     `widget_smoke_test.dart` Setup'a göre güncellendi. 42/42 yeşil.
   - ✅ **Parça 7 — sürükle-bırak (6 Ağustos 2026):** Web App.tsx'in
     beginDrag/moveDrag/endDrag sisteminin birebir portu — üç akış da var:
     raftan tahtaya yerleştirme (joker sürüklenince önce harf seçici,
     `PlaceTileAction(rackIndex)`), tahtada taşıma (`MovePlacedTileAction`),
     tahtadan rafa sürükleyerek geri alma. Aynı sabitler: `DRAG_LIFT=30`
     (hayalet + bırakma hedefi parmağın 30px üzerinde; ızgara üst kenarına
     kırpılır — web'in "üst satıra bırakılamıyordu" düzeltmesi dahil),
     `DRAG_THRESHOLD=6` (altı dokunuş sayılır). Hayalet taş 46px,
     1.1 ölçek, gölgeli, `IgnorePointer` — SafeArea içi Stack overlay'inde.
     Kaynak taş görünmez çizilir (raf: opacity 0 yer tutar; tahta:
     dragHiddenKey), hedef hücre 2px KESİKLİ yeşil/kırmızı çerçeve alır
     (`_DashedBorderPainter` — web `outline: 2px dashed`).
     - **Dokunuş/sürükleme ayrımı web'deki gibi TEK pointer akışında:**
       drag handler'ları verildiğinde raf taşları ve YERLEŞTİRİLMİŞ hücreler
       GestureDetector yerine `Listener` taşır (Flutter'da pointer, basılan
       widget'ın hit-test yoluna bağlı kalır — web setPointerCapture'ın
       doğal karşılığı); hareketsiz bırakış = dokunuş (seç / joker-düzenle /
       geri al), eşik aşan hareket = sürükleme. İkisi birden dinlenseydi tek
       dokunuş çift işlem yapardı — web'in suppressClickRef'ine gerek
       kalmadı (boş hücrenin GestureDetector'ı zaten tetiklenmiyor, jest
       kaynak taşın Listener'ına ait). Swap modunda raf eski GestureDetector
       yolunda kalır (web `isDraggable = draggable && !swapMode`);
       `canAct/swapMode` guard'ı beginDrag'de `enabled` bayrağına iner —
       kapalıyken hareket yok sayılır, dokunuş çalışmaya devam eder.
     - **Hedef bulma geometrik:** web `elementFromPoint` yerine
       `gridKey`/`rackKey` RenderBox'larından global→hücre eşlemesi
       (13 hücre + 12×3px boşluk stride'ı; boşluğa düşen nokta soldaki
       hücreye sayılır — web'de null olurdu, kabul edilen küçük fark).
     - **Test yardımcıları ValueKey'e geçti:** `rack-$i` / `cell-$r-$c` —
       tip tabanlı (GestureDetector) indeksleme Listener'a geçişle kayardı;
       yeni bir hücre/raf finder'ı yazarken key kullan. Drag testlerinde
       DRAG_LIFT telafisi: hedef merkezin +30 ALTINA bırak (web Playwright
       testindeki aynı ders). Doğrulama: `game_screen_test.dart`
       sürükle-bırak testi (üç akış + dolu hücreye bırakma reddi + kaynak
       gizleme + sürükleme-anı ekran görüntüsü
       `build/screenshots/game_drag.png`). 43/43 yeşil.
   - ✅ **Raf kartı + raf taşları da CSS-semantikli gölgeye geçti
     (6 Ağustos 2026, kullanıcı bildirdi — "tahtadaki gölge sorunu rafta
     da var"):** İkisi de hâlâ `BoxShadow`'daydı (yoğun + ters katman);
     `ShapeDecorationWithCssShadows`'a opsiyonel `gradient` desteği
     eklenip raf kartı (web Rack.tsx çifti — koyu sağ-alt + İLK SÜRÜMDE
     HİÇ TAŞINMAMIŞ beyaz sol-üst parlama `-3,-3,10 beyaz .9`) ve raf
     taşı (Tile.tsx üçlüsü, altın gradyan dolgu) bu decoration'a taşındı.
     Tarama notu: `BoxShadow` kullanan kalan yerler bilinçli — bonus
     hücrelerinin 2-4px'lik minik dış gölgeleri (NeoBox.outerShadows,
     fark algılanamaz; hayalet taşın ek gölgesi ise bir alt maddeyle
     tamamen kaldırıldı); yeni bir panel/kart gölgesi eklerken varsayılan
     ŞÜPHE: web'den kopyalanan çok katmanlı box-shadow değerleri
     `CssShadow` ile taşınmalı.
   - ✅ **Buton gölgeleri + hayalet taş + OYNA disabled görünümü
     (6 Ağustos 2026, kullanıcı üç maddelik geri bildirimle):** (1) Hayalet
     (sürüklenen) taşın Flutter'a özgü EK koyu gölgesi kaldırıldı — taş
     artık yalnızca kendi altın gölge üçlüsüyle çiziliyor. **Bilinçli
     web sapması:** web'in hayaletinde aslında ek bir
     `drop-shadow(0 10px 16px rgba(0,0,0,0.35))` VAR (App.tsx ~1497), ama
     kullanıcı webi "taşırken shadow yok" diye algılayıp öyle istedi —
     Flutter'daki yoğun BoxShadow blob'u asıl şikayetti; bu subtle
     drop-shadow İSTENEREK taşınmadı, ileride "hayalette web'de olan gölge
     eksik" diye düzeltmeye kalkma. (2) Yeni **`neo_button.dart`
     (NeoButton)** — web `.btn-raised`/`.btn-raised-neutral`/gold
     butonlarının index.css gölge değerleriyle, CSS semantiğinde
     (`ShapeDecorationWithCssShadows`) tek ortak buton: accent (mavi zemin
     + beyaz yazı + üçlü gölge), neutral (panel zemin + `#DCE2EA` çerçeve
     + ikili gölge), gold. Disabled = web ile aynı: gölge YOK +
     `Opacity(0.35)` tüm butona — accent'te bu "açık mavi zemin üstünde
     beyaz yazı" görünümü verir (kullanıcının istediği; Material'ın gri
     disabled'ı DEĞİL, bu yüzden Filled/OutlinedButton yerine
     GestureDetector+Container). Kullanım yerleri: OYNA/YENİ OYUN (accent,
     13px/1.2), swap satırı DEĞİŞTİR (gold)/VAZGEÇ, alt sıra PAS
     GEÇ/DEĞİŞTİR/KARIŞTIR/GERİ AL/TORBA (neutral) — eski
     `_SmallButton`/`_playButtonStyle` silindi; Setup `_ChoiceButton`
     (seçili=accent/değil=neutral) ve OYUNU BAŞLAT (accent, 14px/2.0)
     NeoButton'a delegate; GameHeader `_GirisButton` aynı üçlü gölgeyi
     kendi Container'ında aldı (akıcı padding sistemi NeoButton'un sabit
     padding'ine uymadığından delegate edilmedi). Doğrulama: 43/43 test +
     `game_screen_kelime.png` (OYNA aktif mavi/beyaz + alt sıra soft
     gölgeler), `game_drag.png` (hayalet gölgesiz, OYNA disabled açık
     mavi), `game_screen_swap.png` (gold), `setup_form.png` gözle
     incelendi.
   - ⚠️ **Raf başlığı: yalnızca oyuncu adı — web'den BİLİNÇLİ sapma
     (6 Ağustos 2026, kullanıcı bildirdi):** Kullanıcı ekran görüntülerinde
     rafta "Sen" görüp "webde kişinin nickname'i yazıyor, yanında aksiyon
     yazısı yok" dedi. İki bulgu ayrıştı: (1) **"Sen" bir kod sabiti
     DEĞİLDİ** — `RackWidget.title` baştan beri `players[_rackIndex].name`;
     ekran görüntüsündeki "Sen" yalnızca `game_screen_test.dart`
     fixture'ının oyuncu adıydı (gerçek akışta misafirde "Misafir", auth
     gelince nickname). Fixture `Ironman`a çevrildi ki ekran görüntüleri
     temsili olsun — bir yan fayda: header skor kutusunda uzun adın
     kırpılma davranışı da artık görünüyor (web'de de `truncate`).
     **Ders: bir ekran görüntüsündeki metni "hardcode" sanmadan önce
     fixture'a bak.** (2) Aksiyon metni GERÇEKTEN vardı ama web'de de var:
     `src/components/Rack.tsx` swap modunda başlığı
     `` `${title} — değiştirilecek taşları seç` `` yapıyor (App.tsx ve
     OnlineGameScreen.tsx ikisi de `swapMode` geçiyor). Kullanıcı bunu
     istemedi — aksiyon metni zaten tahtanın altındaki mesaj satırında
     ("Değiştireceğin taşları seç, sonra "Değiştir"e bas."). Flutter'da
     kaldırıldı; başlık her durumda yalnızca ad (swap modunda rengi hâlâ
     turuncuya dönüyor, sağdaki "N seçili" duruyor). ~~**Web'de aynı satır
     kaldırılana kadar bu bilinçli bir sapmadır**~~ → **17 Ağustos 2026'da
     web'den de kaldırıldı, sapma kapandı** (kullanıcı Blok 6 turunda aynı
     gerekçeyi tekrarladı).
   - ✅ **Parça 8 — hamle geçmişi modalı + Board alt bilgi şeridi
     (6 Ağustos 2026):** `MoveHistoryModal.tsx` portu (`move_history_modal.
     dart`) — veri tamamen `GameState.moveHistory`'den geldiğinden (motorla
     birlikte portlanmış, golden vector'larla doğrulanmış) yeni asset/ağ
     çağrısı gerekmedi; bu yüzden kelime anlamı modalından ÖNCE yapıldı
     (o 6.5 MB'lık `meanings.json`'un mobil paketleme kararını bekliyor).
     Kapsanan web davranışları: en yeni üstte (ters sıra), `invasionFrom`
     dolu "vergi geliri" satırlarının kart olarak GÖSTERİLMEMESİ ve hamle
     sayısına katılmaması (ama toplam puana katılması), kelime başına
     "SÖZCÜK (ham puan ×2/×3)" satırı, Bingo/jokerli-bitiş/Sınır İhlali
     rozetleri + altlarındaki açıklama satırları, pas/değiştir/teslim
     metinleri, boş liste hâli.
     - **Ortak modal kabuğu çıkarıldı (`modal_shell.dart`, `KModal`):**
       web'de ~15 modal `Modal.tsx`'i paylaşıyor; Flutter'da ilk iki modal
       (Kalan Taşlar, GameOver) kendi Dialog'unu kurmuştu. Üçüncüsünde
       ortak kabuk yazıldı (360px, %85 yükseklik sınırı, mono/uppercase/
       accent başlık + ✕ + ayraç). Başlık `trUpper`'dan geçer (web'de CSS
       `uppercase`). Kalan Taşlar/GameOver'ın kendi kabukları ŞİMDİLİK
       DOKUNULMADAN kaldı — onları da taşımak ayrı bir görsel doğrulama
       turu demek; yeni modaller `KModal` kullanmalı.
     - **Board alt bilgi şeridi** (Parça 1'de bilinçli ertelenmişti):
       kart artık `Column[AspectRatio(1) ızgara, şerit]` — web'deki gibi
       şerit kartın kendi zemininde/gölgesinde, ayrı bir bant değil. Solda
       döküman ikonu + "Hamleler" (CustomPainter, web SVG path'i), sağda
       X2/X3 açıklaması. `hideFooter` (web'in aynı prop'u) salt-okunur
       render'lar için: `board_render_test.dart` sabit 560×560 kutuda
       çizdiğinden şeridi kapatıyor.
     - **Test ortamında Material ikon fontu eksikti:** `Icons.*` (joker
       yıldızı, modal ✕, YZ robotu) ekran görüntülerinde boş kutuya
       dönüyordu — ikon fontu SDK önbelleğinde yaşıyor, uygulama asset'i
       değil. `test_fonts.dart` artık `$FLUTTER_ROOT/bin/cache/artifacts/
       material_fonts/MaterialIcons-Regular.otf`'yi de yüklüyor. Gerçek
       cihazda sorun yoktu, yalnızca görüntüler yanıltıcıydı (önceki
       parçaların görüntülerinde jokerin "□" görünmesinin sebebi buydu).
       Aynı sebeple hamle geçmişindeki ★/★★ rozeti metin yerine
       `Icons.star` kullanıyor (taş jokerindeki aynı karar — ★ glyph'i
       Space Mono'da yok).
     - GameOver'a web'deki "Oyun Geçmişi" linki eklendi; "Görüş Bildir"
       hâlâ bilinçli eksik (form Supabase'e yazıyor → auth fazı).
     - Doğrulama: `move_history_test.dart` (3 test — zengin geçmişle tüm
       rozet/filtre dalları + `build/screenshots/move_history.png`, boş
       liste, GameScreen'de gerçek hamle sonrası footer linkinden açılış).
       46/46 yeşil.
   - ✅ **Parça 9 — kelime anlamı modalı (6 Ağustos 2026):** Üç katman.
     (1) **Asset üreticisi** `scripts/generate-meanings-db.mjs`
     (`npm run generate-meanings-db`): `src/data/meanings.json` → tek tablolu
     SQLite (`word` PRIMARY KEY, `pos`, `meanings` JSON dizisi, WITHOUT
     ROWID). Anahtarlar web'le AYNI `trLower` normalizasyonundan geçer.
     Çıktı deterministik (aynı girdi → aynı sha, git churn yok) ve yanına
     küçük bir `meanings.db.sha256` yazılır. **`meanings.json` değişirse bu
     script yeniden koşulmalı** — sözlük/golden vector disiplininin aynısı.
     (2) **`MeaningStore`** (`lib/src/data/meaning_store.dart`): asset'ler
     paket içinde yaşadığından doğrudan açılamaz — İLK SORGUDA bir kez
     uygulama db dizinine kopyalanır; "kopya güncel mi" sorusu 5 MB'ı
     okumadan, sha256 damgası karşılaştırılarak yanıtlanır (damga tutmazsa
     yeniden kopyalanır). Sonra `readOnly` açılıp tek satır sorgulanır.
     Hata durumunda (asset yok/bozuk) sessizce null döner — anlam gösterimi
     oyunun çalışmasına bağlı değil. **`databaseFactory` TEMBEL çözülür:**
     kurucuda okumak, anlam deposunu hiç kullanmayan ffi testlerini bile
     "databaseFactory not initialized" ile düşürüyordu.
     (3) **`MeaningModal`** (`MeaningModal.tsx` portu, `KModal` kabuğu):
     numaralı anlam listesi, iki kelimede ayraçlı alt başlık, yükleniyor ve
     "bulunamadı" hâlleri. Tetikleyici web `handleCellClick`'in ilk dalı —
     tahtadaki ONAYLANMIŞ bir taşa dokunmak, o hücreden geçen yatay+dikey
     kelimeleri gösterir.
     - **Motor dokunuşu:** `fullWordAt` (web `getFullWordAt` eşleniği)
       kelimeki_core'un board.dart'ında zaten var olan özel yardımcıyı saran
       PUBLIC bir fonksiyon olarak eklendi (davranış değişmedi). Kural gereği
       golden vector'lar yeniden üretildi (fixture'larda sıfır fark) ve Dart
       çekirdek testleri koşuldu: 6746 kontrol, 0 hata.
     - **Modal depoya değil `MeaningLookup` fonksiyonuna bağlı** — bu bir
       test kolaylığı değil zorunluluk: `initState`'te başlayan Future
       testWidgets'ın SAHTE zaman bölgesine bağlanır, `runAsync`'te beklemek
       onu ÇÖZMEZ (gerçek IO hiç ilerlemez). Widget testleri bu yüzden veriyi
       fake zone DIŞINDA (setUpAll) gerçek asset'ten okuyup besliyor; deponun
       kendi doğruluğu ayrı `test()` vakalarında sınanıyor. **`tester.pump`
       runAsync'in İÇİNDE ÇAĞRILMAZ** — denendi, kilitleniyor (5 dk).
     - **Ölçülen font bulgusu:** TDK verisindeki çapraz gönderme işareti
       `►` (U+25BA) ne Space Grotesk'te ne Space Mono'da VAR (fontTools ile
       ölçüldü); web'de tarayıcı sistem yedeğinden basıyor, Flutter'da cihaz
       yedeğine kalıyor ve garanti değil (testte boş kutu çıktı). Veri
       setinin TAMAMI tarandı: fontların kapsamadığı TEK karakter bu (16.298
       geçiş). Render anında bundled fontlarda var olan `→` ile
       değiştiriliyor; test bunu (`►` ekrana ulaşmamalı) doğruluyor.
     - Doğrulama: `meaning_test.dart` (4 test — asset ↔ kaynak JSON
       karşılaştırması + Türkçe büyük harfli sorgu + damga yenileme + modal
       render dalları + `build/screenshots/meaning_modal.png`). 50/50 yeşil.
   - ✅ **Parça 10 — kurallar ekranı (6 Ağustos 2026):** `HelpModal.tsx`
     portu (`help_modal.dart`): iki adım (Hızlı Başlangıç / Detaylı
     Kurallar), başlığın ÜSTÜNDEKİ linkle geçiş — `KModal`'a web'in
     `headerLink` prop'u eklendi. Web'in yardımcıları birebir taşındı
     (Section/P/Pill/TileRow/QuickItem). Setup'taki "Nasıl oynanır?" linki
     bağlandı (yanındaki "Arkadaşınla paylaş" hâlâ eksik — native share
     ayrı parça). Bingo bonusu metinde sabit değil, motordan
     (`bingoBonus`).
     - **Kural metinleri web'den BİREBİR kopyalandı** — özetlenmedi. Dosya
       başında bu kural yazılı; web metni değişirse buraya aynen taşınmalı
       (iki taraf tek kaynaktan üretilmiyor). Testler bunu iki cümle
       örnekleyerek koruyor ("puanın 1/3'ü bölge sahibine gider…" gibi).
       `<strong>` vurguları kaynakta `**...**` ile yazılıp `_runs()` ile
       TextSpan'e çevriliyor — Türkçe metin kaynakta okunur/kopyalanabilir
       kalsın diye.
     - **Puan tablosu artık motora karşı doğrulanıyor:** web tablosu elle
       yazılmış; test 28 harfin puanını `letterPoints` ile karşılaştırıyor,
       sapma olursa düşer.
     - **Emoji dersi (Material ikonlarının kardeşi):** `FontLoader` ile
       yüklenen aile, `TextStyle`'da ADIYLA referans verilmedikçe
       kullanılmıyor — ilk sürümde 🎯🏠🔗… ekran görüntüsünde boş kutu
       çıktı. `_QuickItem` artık `fontFamilyFallback: ['Noto Color Emoji',
       'Apple Color Emoji']` veriyor; bu hem testte gerçek emoji çizdiriyor
       hem cihazda doğru aileyi hedefliyor. `test_fonts.dart` emoji fontunu
       da yüklüyor. Ayrıca ÖLÇÜLDÜ: `★` (U+2605) hiçbir bundled fontta yok
       → taş jokerindeki kararla aynı şekilde `Icons.star` (WidgetSpan).
     - Doğrulama: `help_modal_test.dart` (3 test — 9 hızlı madde + motordan
       gelen bonus, iki yönlü adım geçişi + 10 bölüm başlığı + kural
       cümleleri, puan tablosu ↔ motor tutarlılığı; ekran görüntüleri
       `build/screenshots/help_quick.png` ve `help_detailed.png`).
       53/53 yeşil.
   - **Web UI paritesi bu parçayla tamamlandı** (misafir/YZ akışı için).
     Kalan bilinçli eksikler auth'a bağlı: "Görüş Bildir" formu,
     "Arkadaşınla paylaş" (native share), Canlı oyun ekranları, skor kartı/
     k-lig. Sıradaki faz: auth + Canlı oyun (bkz. "Sıradaki Fazlar").
5. **Auth + Canlı oyun fazı — PARÇA PARÇA ilerliyor** (Fable ile,
   6 Ağustos 2026'da başladı).
   - ✅ **Parça 1 — Supabase oturumu + hesap durumunun UI'a yansıması:**
     - **`AuthService`** (`lib/src/data/auth_service.dart`, ChangeNotifier —
       Üst Düzey Kararlar #5): web `useAuth`'un iki sözleşmesi aynen taşındı:
       (1) `user` set edilmesi ile profil çekiminin başlaması AYNI adımda
       (arada "user dolu ama profileLoading eski" render'ı yok — web'de
       yaşanmış kimlik-sıçraması hatası); (2) hiçbir hata `loading`/
       `profileLoading`'i sonsuza dek true bırakamaz. Kimlik kuralları
       birebir: `accountName` (display_name → first_name → profil
       YÜKLENDİYSE e-posta öneki; beklerken null → `accountPending`),
       `menuName` (UserMenu kuralı), `identityLoading`. Oturum kalıcılığı
       supabase_flutter'ın kendi deposunda — ek bir şey saklanmıyor.
       `friendlyAuthMessage` portu kod+regex eşlemesiyle web'le birebir
       (bilinmeyen hata null → orijinal mesaj gösterilir; `user_banned`
       bilgi-sızıntısı kararı web'de ölçülüp verildi, mesaj aynı).
       **`AuthService.fake`** (@visibleForTesting) ağsız test durumları
       kuruyor — gerçek `User` nesnesi gotrue kurucusuyla elle yaratılıyor.
     - **`LoginModal`** (`lib/src/ui/auth/login_modal.dart`) — AuthModal'ın
       LOGIN dalı: e-posta+şifre, boş alan istemci doğrulaması, Türkçe hata
       eşlemesi, girişte kendiliğinden kapanır. "Şifremi unuttum" (recovery
       deep-link ister) ve "Kayıt ol" (nickname benzersizliği/koşullar)
       SONRAKİ parçalar — dürüst "kelimeki.com üzerinden" diyaloğu, sahte
       form yok.
     - **`AccountButton`** (`lib/src/ui/auth/account_button.dart`) — web
       UserMenu çekirdeği, dört durum: yapılandırılmamış → hiç çizilmez;
       kimlik yükleniyor → "…" dairesi; oturumsuz → GİRİŞ (btn-raised,
       görsel eski `_GirisButton`dan taşındı — o sınıf silindi); oturumlu →
       `KAvatar` + açılır menü. Menü YALNIZCA çalışan maddeleri taşıyor
       (isim başlığı, Nasıl Oynanır?, Çıkış Yap) — k-lig/Arkadaşlar/Skor
       Kartı/Hesap Ayarları kendi ekranları portlanınca eklenecek
       (ARKADAŞINLA dürüstlük deseni). `KAvatar` (`k_avatar.dart`) web
       Avatar portu: initials() kuralı + tek karakter 0.55 oranı dersi.
     - **Kablolar:** `AppServices.auth` (bootstrap'te `AuthService(supabase)`
       — yapılandırılmamışsa configured=false, hesap UI'ı görünmez);
       GameHeader/GameScreen opsiyonel `auth` (testler/önizlemeler
       geçmeyebilir → web offline davranışı); Setup sağ üstte AccountButton
       (web App.tsx kurulum dalındaki UserMenu konumu), gövde
       `ListenableBuilder(auth)` ile tazelenir, 1. koltuk hesap dalı
       (avatar + kilitli isim / pending'de nötr "Yükleniyor…"),
       `_startNewGame` 1. oyuncuyu `accountName` ile başlatır (web doStart).
     - **Doğrulama:** `auth_test.dart` (10 test: friendlyAuthMessage kod/
       mesaj/null; accountName öncelik zinciri; accountPending; girişli
       Setup ekranı + oyunun hesap adıyla başlaması + hesap menüsü; GİRİŞ →
       giriş penceresi + boş alan hatası; pending'de kimlik sıçraması yok +
       `build/screenshots/setup_logged_in.png`). 63/63 yeşil.
       **Doğrulama sınırı:** gerçek Supabase el sıkışması (şifre girişi,
       oturum kalıcılığı, profil RLS okuması) bu ortamdan test EDİLEMEDİ —
       cihazda `--dart-define=SUPABASE_URL/ANON_KEY` ile kullanıcı
       doğrulamalı. Testte "İR" beklentisi yanlış çıktı: "Ironman" BÜYÜK
       I ile başlar, trUpper doğru şekilde "IR" üretir (Türkçe kural
       yalnızca küçük i'yi İ yapar) — baş harf beklentisi yazarken dikkat.
   - ✅ **Parça 2 — kayıt formu + Kullanım Koşulları/Gizlilik portları
     (6 Ağustos 2026):**
     - **`AuthModal`** (`lib/src/ui/auth/auth_modal.dart`) — Parça 1'in
       `LoginModal`'ı SİLİNDİ, yerine web `AuthModal.tsx` gibi tek modalda
       iki mod (giriş/kayıt, alttaki linkle geçiş). Kayıt formu web'le
       birebir: AD*/SOYAD* yan yana, TAKMA İSİM* (canlı durum satırı),
       E-POSTA* ("Doğrulama linki gönderilir" hint'i), CİNSİYET dropdown
       ('' Belirtilmedi + `genderOptions`), DOĞUM TARİHİ (yazarken otomatik
       "/" — `formatTrDateInput`), ŞİFRE* (göster/gizle), zorunlu koşullar
       + opsiyonel pazarlama checkbox'ları, "* Zorunlu alan" notu.
       **Doğrulama sırası web `submit()` ile aynı** (Ad → Soyad → Takma
       isim → E-posta → Şifre → koşullar → tarih) ve testle korunuyor.
       Koşullar satırında metne dokunmak checkbox'ı TOGGLE ETMEZ — linkler
       (TapGestureRecognizer) Terms/Privacy modallerini açar (web parity).
     - **Takma isim canlı kontrolü** — web `useNicknameAvailability`
       portu: boşluk `onChanged`'da anında silinir
       (`display_name_no_whitespace`), 400ms debounce + sıra sayacı (geç
       gelen eski yanıt yenisini ezemez), `check_nickname_available` RPC'si
       (`AuthService.checkNicknameAvailable`); durum `taken`/`checking`
       iken KAYIT OL devre dışı. Asıl doğruluk kaynağı yine DB unique
       index'i — yarışta `friendlyNicknameError` (regex: constraint adı +
       duplicate/unique) 'Bu takma isim zaten kullanılıyor.' üretir.
     - **`AuthService.signUp`** — web `signUp()` birebir:
       `sharedxp_pending_profile` metadata'sı camelCase anahtarlarla
       (firstName/lastName/agreedToTerms/gender/birthDate/
       marketingConsent), `display_name` metadata kökünde
       (`handle_new_user` trigger'ı okur — e-posta doğrulaması AÇIKKEN
       oturum açılmadığından sonradan update güvenilmez),
       `signup_channel: 'direct'` (mobil için ayrı kanal BİLİNÇLİ ertelendi
       — admin paneli yalnızca Direkt/Form tanıyor), `agreed_to_terms`
       yalnızca oturum HEMEN açıldıysa profile yazılır (web'in bilinen
       eksiğiyle aynı davranış — düzeltmek web'le birlikte ayrı karar).
       Dönüş `sessionOpened: bool` — false ise modal giriş moduna dönüp
       "Hesap oluşturuldu. E-postanı doğrulayıp giriş yap." gösterir.
     - **`legal_modals.dart`** — `TermsModal`/`PrivacyModal`, web
       metinleri BİREBİR (özet yok; KVKK maddeleri, Sarıyer/İstanbul,
       "Son güncelleme: 2 Ağustos 2026" dahil). Web metni değişirse buraya
       aynen taşınmalı (HelpModal'daki aynı kural). "Görüş Bildir formu"
       geçişi dürüst "kelimeki.com üzerinden" diyaloğuna bağlı (form auth
       fazının sonraki parçası). Testler iki modalden cümle örnekleyerek
       birebirliği koruyor.
     - **`profile_fields.dart`** — web `profileFields.ts` portu:
       `genderOptions`, `formatTrDateInput`, `trDateToIso` (Türkçe hata
       metinleri birebir; `FormatException` olarak fırlatır), `isoToTrDate`
       (hesap ayarları parçası için hazır).
     - **İki font bulgusu (ölçülerek):** (1) `DropdownButtonFormField.style`
       tema fontunu MİRAS ALMAZ (`ButtonStyle.textStyle` dersinin kardeşi)
       — fontFamily verilmeyince cihazda Roboto'ya, testte Ahem bloğuna
       (ekran görüntüsünde "siyah dikdörtgen") düşer; `fontFamily:
       'SpaceGrotesk'` açıkça verildi. (2) ✓ (U+2713) bundled fontların
       HİÇBİRİNDE yok (fontTools ile ölçüldü) — ★/► kararlarıyla aynı:
       durum satırı `Icons.check` + "Kullanılabilir".
     - **Üç test dersi:** (1) TextSpan linkleri `find.text` ile bulunamaz —
       `tester.tapOnText(find.textRange.ofSubstring(...))`; (2) üst üste
       iki modal açıkken ✕ için `find.byTooltip('Kapat').last`; (3)
       `build/unit_test_assets` bayatlarsa Material3 ink splash'i
       "ink_sparkle.frag ... Unsupported runtime stages format version"
       ile testi düşürür — kod hatası değil, klasörü silip yeniden koş.
     - Doğrulama: `signup_test.dart` (8 test: profile_fields birimleri,
       friendlyNicknameError, debounce/boşluk/dolu-isim + buton kilidi,
       doğrulama sırası — son adım 'Supabase yapılandırılmadı.' ile akışın
       signUp'a KADAR indiğinin kanıtı, Terms/Privacy linkleri + birebir
       metin örnekleri + link-checkbox ayrımı, tarih oto-ayırıcı + ekran
       görüntüsü `build/screenshots/signup_form.png`). 71/71 yeşil,
       `flutter analyze` temiz. **Doğrulama sınırı:** gerçek `signUp`
       (trigger'ın profili kurması, e-posta doğrulaması açık/kapalı
       dalları, gerçek nickname yarışı) bu ortamdan test EDİLEMEDİ —
       cihazda gerçek bir kayıtla doğrulanmalı.
   - ✅ **Parça 3a — bulut kayıtları senkronu (6 Ağustos 2026,
     `data/cloud_save_repo.dart`):** Girişli kullanıcının devam eden YZ
     oyunları artık web'le AYNI `local_game_saves` tablosunda — cihazlar
     arası devam (web'de başla → mobilde sürdür ve tersi) + çoklu oyun.
     Üç katman: `CloudSaveGateway` (satır kapısı — gerçek uç
     `SupabaseCloudSaveGateway`, testlerde bellek içi sahte),
     `CloudSaveRepo` (politika), `CloudGameSession` (misafir
     `GameSession`'ının bulut eşleniği).
     - **PORT_BRIEF §7 değişmezinin ilk gerçek kullanıcısı:**
       `local_game_saves`e giden HER yazma (upsert + silme) tablonun TEK
       `TableWriteQueue`'sundan geçer, listeleme kuyruk boşalana kadar
       bekler — web'deki DELETE→SELECT yarışı (silinen kaydın listede bir
       kez daha görünmesi) yapısal olarak imkânsız; test, silme uçuştayken
       listeleyerek kanıtlıyor.
     - **Web autosave davranışı birebir:** 600ms debounce (aynı süre/
       gerekçe), satır id'si ilk değişimde tembelce üretilir (web
       `activeSaveIdRef`), sunucudan devamda `resumeSaveId` ile dışarıdan
       verilir (aynı satır güncellenir, yenisi açılmaz — testli); oyun
       bitince satır silinir (bekleyen debounce iptal — gecikmeli upsert
       silinen satırı diriltemez); çıkışta `turnCount<2` ise satır İZ
       BIRAKMADAN silinir (web handleLogoClick). **Tek bilinçli sapma:**
       `turnCount>=2` çıkışında bekleyen debounce web'de İPTAL edilir (son
       ≤600ms kaybolabilir), mobilde AYNI satıra hemen flush edilir —
       mobil OS uygulamayı daha sert kapattığından daha taze veri; şema/
       anlam farkı yok. (İlk sürümde flush hiç çalışmıyordu — `detach()`
       timer'ı öldürdükten SONRA `_timer != null` kontrol ediliyordu;
       test yakaladı.)
     - **Listeleme kararları (web refreshCloudSaves'in liste kısmı):**
       bitmiş/play-dışı satır fırsatçı temizlenir; ağ hatasında `null`
       döner (web `[]` döndürüp yanlış "hiç oyunun yok" gösterirdi —
       mobilde UI eski listeyi korur); çözülemeyen satır SİLİNMEDEN
       atlanır (satır web istemcisi için geçerli olabilir — mobilin
       silme/karantina hakkı yok). **7 günlük satır listeye girmez ama
       SİLİNMEZ:** claim+(-2 ceza+`games` satırı) 3b'nin işi — satırı ceza
       üretmeden silmek cezayı YUTMAK olurdu; süresi dolan satırı şimdilik
       aynı hesabın web istemcisi süpürüyor.
     - **Misafir migrasyonu** (`migrateGuestSave` — web
       `migratingSavedGameRef` effect'i): girişte misafir slotu yeni bir
       uuid ile buluta taşınır; 1. oyuncunun adı hesap adına çevrilir
       ("Sıra: Misafir" kalıcı kalmasın — web 1 Ağustos düzeltmesi; isim
       düzeltme kanonik JSON üzerinden, `copyWith` zinciri yerine
       yaz→değiştir→geri-ayrıştır), Setup çağıranı `profileLoading`
       bitene kadar bekler; slot YALNIZCA sunucu yazımı doğrulanınca
       silinir (ağ hatasında dokunulmaz, sonraki denemede tekrar taşınır
       — testli).
     - **Setup girişli dalı** (web `user && !creatingLocal`): turuncu
       "+ Yeni Yapay Zeka Oyunu Aç" (NeoButton'a `orange` varyantı —
       gölgeler ÖLÇÜLDÜ, `.btn-raised` ile birebir aynı, yalnız zemin
       farklı) + "Devam Eden Oyunlar" listesi; form yalnızca butonla
       açılır, yanında VAZGEÇ (web creatingLocal/Vazgeç). Satırlar misafir
       `_SavedGameRow`'unun kendisi: girişli + `turnCount>=2` için kalan
       süre dili "teslim sayılacak" (web `willSurrender`), insan koltuk
       avatarı profil fotoğrafı/baş harfler (web `savedGameAvatars`).
       Girişliyken misafir slotuna HİÇ yazılmaz (web "girişliyken
       localStorage'a yazılmaz" kuralı — mükerrer ceza önlemi). Hesap
       değişimi kararı `user.id` ile (`_lastUserId` — web "user REFERANSI
       hesap değişimi değildir" dersi); değişimde liste/form sıfırlanır.
       Web'de oyun başlayınca Setup unmount olup `creatingLocal` sıfırlanır
       — mobilde ekran mount'ta kaldığından oyundan dönüşte elle
       sıfırlanır (test yakaladı: turnCount<2 çıkışında liste yerine form
       görünüyordu). Web'in "Devam Edenler / Son Oynananlar" alt sekmeleri
       BİLİNÇLİ eksik — "Son Oynananlar" bitmiş oyun geçmişi (`games`)
       ister, o 3b/skor kartı parçasının işi.
     - **Çapraz platform state uyumluluğu ÖLÇÜLDÜ (parçanın kritik
       doğrulaması):** web'in ÜRETİM reducer'ıyla (esbuild, tohumlu) 8 tur
       oynanmış + 1 taslak taşlı bir oyunun HAM kaydı (`JSON.stringify
       (state)` — serState normalizasyonu YOK, gerçek `startedAt` dahil)
       üretilip Dart'a verildi: `gameStateFromJson` sorunsuz çözdü, motor
       kullanabildi (RecallAll + Pass), ve Dart'ın kanonik geri-yazımı ham
       web JSON'uyla **yapısal olarak SIFIR farklı** çıktı (anahtar
       bazında özyinelemeli diff, 0 fark). Yani mobil web'in yazdığını
       okur, web de mobilin yazdığını okur — mobil satır web'in kendi
       yazdığı biçimin aynısı. Web bulut devamında `multiSession`
       İŞARETLEMEZ (yalnızca misafir localStorage yükleyicisi işaretler) —
       mobil bulut devamı da işaretlemez, bilinçli aynı davranış.
     - Doğrulama: `cloud_save_test.dart` (12 test — roundtrip, yazma-okuma
       yarışı, fırsatçı temizlik, süresi-dolmuş-satır-silinmez,
       bozuk-satır-atlanır, hata yutma, debounce birleştirme + tek satır,
       bitişte silme, iki `end()` dalı, resumeSaveId, migrasyon üç dalı) +
       `setup_cloud_test.dart` (4 widget testi — liste/teslim dili +
       ekran görüntüsü `build/screenshots/setup_cloud_list.png`, boş
       liste + form/Vazgeç döngüsü, satırdan devam→aynı satır, turnCount<2
       terk→iz yok). 87/87 yeşil, analyze temiz. **Doğrulama sınırı:**
       `SupabaseCloudSaveGateway` (gerçek PostgREST upsert/delete/select
       + RLS) bu ortamdan test EDİLEMEDİ — cihazda iki oturumla (web ↔
       mobil aynı hesap) uçtan uca doğrulanmalı. **Bilinçli ertelenen:**
       oyun İÇİNDE (GameHeader'dan) giriş yapılırsa oyun o an buluta
       DEVREDİLMEZ (web mid-game RENAME_PLAYER+devir effect'i) — misafir
       slotunda kalır, Setup'a dönüşte migrasyon taşır; sonuç aynı,
       yalnızca o oyun boyunca autosave yerel kalır.
   - ✅ **Parça 3b — bitmiş/terk edilmiş oyun kayıtları (6 Ağustos 2026):**
     Mobilde oynanan oyunlar artık k-lig'i besliyor — `games` satırı,
     anonim bitiş telemetrisi (`game_finishes`) ve 7 günlük terk cezası
     (-2) tam olarak web'in ürettiği biçimde.
     - **`serialize/board_snapshot.dart` (core)** — `boardSnapshot.ts`
       portu; yalnızca dolu hücreler `{r,c,l,o,w?}`, jokerde görünen harf.
       Alan adları/dizi sırası SÖZLEŞME (aynı satırı web okuyor). Ters
       yön (`buildSnapshotGameState`) BİLİNÇLİ port EDİLMEDİ — geçmiş
       tahtayı çizen ekran (skor kartı/oyun geçmişi) henüz yok.
     - **`data/game_record.dart`** — `gameRecord.ts` + `NewGame` portu:
       `NewGameRecord` (+`GamePlayerSnapshot`/`GameResult`), sütun adları
       `games` ile birebir. `newId`/`now` ENJEKTE edilir (core'un
       determinizm sözleşmesinin devamı — testler sabitliyor). Web'in
       `human.moveCount || null` JS-falsy kısayolu `nz()` ile korundu:
       0/'' değerleri null'a düşer.
     - **`data/games_api.dart`** — `GamesGateway` (3 uç: insert /
       telemetri / terk maili) + `GamesRepo` (politika). Web paritesi:
       23505 = başarı (idempotent retry); `notify-local-game-abandoned`
       YALNIZCA gerçek ilk insert'te (23505 dalında DEĞİL — kuyruktan
       tekrar denenen kayıt mükerrer "-2 puan" maili göndermesin);
       misafir/offline kayıt `pending_queue`ya (7 gün TTL, 300 sınırı),
       giriş yapılınca `flushPending` hesaba işler; oturum yoksa flush
       AĞA HİÇ DOKUNMAZ. `logFinish` web gibi best-effort — kuyruğa
       ALINMAZ (kök CLAUDE.md'deki `game_finishes` rollout kararıyla
       tutarlı).
     - **İki terk yolu TEK noktada birleşti:** `LocalGameRepo
       .drainAbandonedGames` artık ceza kuyruklamıyor, olayları ÇAĞIRANA
       veriyor; hem yerel (misafir, 7 gün) hem bulut (`claimAbandoned`)
       yolu `GamesRepo.recordAbandoned`'a akıyor — web'de de tek
       `buildGameRecord(state,true,0)+saveGameDurable+logGameFinish`
       vardı, iki kopya açmamak bilinçli (3a'daki `_finish_online_game
       _records` dersinin aynısı).
     - **7 günlük bulut süpürmesi (3a'da bilerek bırakılan uç):**
       `CloudSaveGateway.claimAbandoned` = web'in ATOMİK
       `.delete().eq(id).lt(updated_at,cutoff).select('state')` sorgusu —
       satır kilidi sayesinde ayrı RPC/kilit gerekmez; başka bir cihaz
       aynı anda süpürdüyse null döner ve ceza İKİ KEZ uygulanamaz
       (testli). `list()` artık `CloudSaveList(saves, abandoned)` dönüyor;
       Setup her senkron turunda `abandoned`ı cezaya çeviriyor.
     - **Kayıt oyun bittiği AN tutuluyor:** web'in `[state.isGameOver]`
       effect'i gibi — `_openGame` controller'a bir dinleyici takıyor,
       GameOver modalı kapatılmasa/ekrandan çıkılmasa bile kayıt gider;
       çıkışta bir kez daha denenir ama `recorded` bayrağı çift kaydı
       (her çağrı YENİ id üretirdi) engeller. Testli.
     - **Doğrulama — web üretim koduyla FİKSTÜR KARŞILAŞTIRMASI:**
       `test/fixtures/web_game_record.json`, web'in ÜRETİM
       `buildGameRecord`/`serializeBoardSnapshot`'ı tohumlu iki oyunla
       (2 kişilik doğal bitiş / 4 kişilik orta-oyun terk) koşturulup
       id+saat sabitlenerek üretildi; Dart portu AYNI state'ten
       `jsonEncode` düzeyinde BİREBİR AYNI satırı üretiyor (96 ve 42
       taşlı, jokerli tahtalar — boş bir karşılaştırma değil). Golden
       vector disiplininin bu katmandaki karşılığı; `gameRecord.ts`/
       `boardSnapshot.ts` değişirse fikstür yeniden üretilmeli.
       `test/game_record_test.dart` (11) + `local_game_repo_test`'in
       yeniden yazılan terk testi + `setup_cloud_test`'e eklenen iki
       uçtan uca test (bulut süpürmesi→ceza, oyun bitişi→kayıt).
       **100/100 yeşil**, `flutter analyze` temiz, core 6746 kontrol/0
       hata (yeni core dosyası eklendi, davranış değişmedi).
       **Doğrulama sınırı:** gerçek `games` insert'i/RLS'i, gerçek 23505,
       `game_finishes` insert'i ve Edge Function çağrısı bu ortamdan test
       EDİLEMEDİ — cihazda bir oyun bitirilip web'deki Skor Kartı'ndan
       doğrulanmalı.
   - ✅ **Parça 4 — Skor Kartı + k-lig + oyuncu kartı (6 Ağustos 2026,
     `lib/src/ui/score/`):** 3b'nin yazdığı veri artık kullanıcıya
     görünüyor.
     - **Wordmark tek kaynaktan (logo deseninin ikizi):**
       `scripts/generate-klig-paths.mjs` artık `klig_mark_data.dart`ı da
       yazıyor — `npm run generate-klig-paths` iki tarafı birden günceller
       (üretici koşulduğunda web `KLigMark.tsx`'in DEĞİŞMEDİĞİ `git diff`
       ile doğrulandı). `klig_mark.dart` çizimi `logo_mark.dart`ın
       `parseSvgPath`'ini paylaşıyor.
     - **`data/stats_api.dart`** — `PlayerStats`/`LeaderboardRow`/
       `MyLeaderboardRank` + `StatsGateway`/`StatsRepo`. "Genel" sekmesi
       AYRI view'dan (`player_stats_overall`) gelir; web'in gerekçesi
       aynen geçerli (ağırlıklı ortalama + longest_word iki hazır satırdan
       birleştirilemez). Salt okunur katman: yazma kuyruğu/dayanıklılık
       YOK, ağ hatasında null/boş döner. `shortName` web'in kısa kimlik
       kuralı (nickname → ad → Anonim; soyad ASLA).
     - **`ui/score/score_stats_section.dart`** — web `ScoreStatsSection`
       portu; ScoreCard ve PlayerScoreCard BU dosyayı paylaşıyor (web'de
       de iki kopya bir kez açılıp kod incelemesiyle tek kaynağa
       çekilmişti). Kutu ızgarası web'in `grid-cols-3` + `col-span-2`
       davranışını elle satırlara bölerek veriyor.
     - **`score_card_modal.dart`** (kendi kartın: avatar/isim/"Y:36/C:E",
       k-lig sırası → sıralamayı açar, üç sekme + iki ızgara),
       **`leaderboard_modal.dart`** (ilk 10 + kaydırınca 20'şer lazy —
       web IntersectionObserver'ın ScrollController karşılığı, kendi
       satırın vurgulu, listede yoksan "senin sıran" kısayolu),
       **`player_score_card_modal.dart`** (k-lig satırına dokununca).
       Hesap menüsüne k-lig ve Skor Kartı satırları eklendi (`stats`
       null iken hiç çizilmez — offline modda dürüstlük deseni).
       **Bilinçli eksikler:** "Tüm Geçmiş Oyunlar" linki (oyun geçmişi
       ayrı parça), PlayerScoreCard'daki arkadaşlık simgesi (arkadaşlık
       sistemi henüz yok) — çalışmayan kontrol koymuyoruz.
     - **KModal'a `titleWidget`** eklendi: web'de başlık bir ReactNode
       olabiliyor (k-lig'de 🏆 + wordmark) — String başlıkla temsil
       edilemiyordu.
     - **Ekran görüntüsü ÜÇ hata yakaladı** (kod okumasıyla değil):
       (1) etiketlerde native `toUpperCase` → "BIRINCILIK"/"KELIME"
       (noktasız I) — `trUpper`a çevrildi ve testle korumaya alındı;
       (2) 🏆 kutu çıkıyordu — `fontFamilyFallback` şart (help_modal'da
       öğrenilen ders, yeni bir emoji eklendiğinde tekrar geçerli);
       (3) "SIRA" başlığı 24px sütuna sığmayıp alt satıra kayıyordu →
       28px. Ayrıca `CrossAxisAlignment.stretch` bir Column içinde
       doğrudan kullanılınca "infinite height" ile patladı (parça 3'teki
       raf satırının AYNI dersi) — `IntrinsicHeight` ile sarıldı.
     - Doğrulama: `score_card_test.dart` (9 test — ayrıştırma/kısa
       kimlik/ağ hatası birimleri, skor kartı kimlik+sekme+kutular +
       sekme değişimi + `build/screenshots/score_card.png`, boş kayıt
       hâli, k-lig ilk sayfa/lazy ikinci sayfa (limit 10 → 20, offset 10)
       + `leaderboard.png`, satırdan oyuncu kartı, boş liste). 109/109
       yeşil, analyze temiz. **Doğrulama sınırı:** gerçek view/RPC
       sorguları (RLS dahil) bu ortamdan test EDİLEMEDİ — cihazda gerçek
       bir hesapla doğrulanmalı.
   - ✅ **Parça 5a — oyun geçmişi (6 Ağustos 2026,
     `ui/score/game_history_modal.dart`):** Skor Kartı'ndaki eksik link
     kapandı; 3b'nin yazdığı `games` satırları artık kart kart okunuyor.
     - **Etki analizi parçayı KÜÇÜLTTÜ (kuralın ilk gerçek faydası):**
       koda başlamadan yapılan tarama, `BoardWidget`'ın `compact`/
       `hideFooter` prop'larının parça 1/8'de ZATEN portlanmış olduğunu
       gösterdi — en riskli görünen kısım (canlı oyun tahtasına dokunmak)
       hiç gerekmedi, önizleme gerçek widget'ın salt-okunur çağrısı.
     - **`buildSnapshotGameState` core'a DEĞİL uygulama katmanına konuldu**
       (`data/game_record.dart`): yazma yönü yalnızca `Board` alıyor ve
       core'da, okuma yönü ise DB satır şeklini (`GamePlayerSnapshot`)
       istiyor — core'a taşımak veri katmanını motora sızdırırdı. Sonuç:
       core'a hiç dokunulmadı, golden vector turu gerekmedi.
     - **`GamesRepo`'ya İLK okuma yolu** (`history`/`boardSnapshot`) —
       `games` tablosuna erişim tek dosyada kalsın diye buraya (Supabase
       katman sınırı değişmezi). Sayfalama web'in `range(offset, offset +
       limit)` hilesiyle: bir FAZLA satır istenip `hasMore` ondan
       çıkarılıyor, ayrı bir count sorgusu yok. `board_snapshot` liste
       sorgusunda YOK (satır başına birkaç KB), yalnızca kart açılınca
       lazy çekilip önbelleğe alınıyor.
     - Kart içeriği web ile birebir: tarih, Canlı/Yapay Zeka rozeti (Canlı
       kayıtlar gri zeminle ayrışıyor), final sıralamasıyla oyuncu
       satırları (sıra, koltuk rozeti, ad, TESLİM OLDU, Puan, SL), eski
       kayıtların "Sen / En iyi rakip" yedeği + "+N diğer oyuncu"
       notu. Kendi satırında dondurulmuş ad yerine GÜNCEL ad
       (web `myCurrentName`); BAŞKASININ geçmişinde yedek satır "Sen"
       değil o kişinin adı (`isMe=false`, web'in kod incelemesiyle
       düzelttiği ayrım).
     - **Ekran görüntüsü İKİ hata yakaladı** (yine kod okumasıyla değil):
       (1) `_seatIndexFor`'da web'in İLK satırı (`colorIndex` varsa onu
       kullan) düşmüştü → 4 kişilik kartta dört oyuncu da "1"/turkuaz
       görünüyordu. Kök sebep tip seçimiydi: `GamePlayerSnapshot
       .colorIndex` `int` (varsayılan 0) idi, "yok" ile "0. koltuk" ayırt
       edilemiyordu → `int?` yapıldı (web `!== undefined`). Etki analizi
       taraması bu alanı yalnızca iki dosyanın okuduğunu gösterdiği için
       değişiklik kapalı devre kaldı. Regresyon testi eklendi (rozetler
       [0,1,2,3] olmalı). (2) "1." sıra numarası 14px sütuna sığmayıp alt
       satıra kayıyordu → 18px + `softWrap:false`.
     - Doğrulama: `game_history_test.dart` (12 test — sayfalama/filtre/ağ
       hatası/lazy snapshot birimleri, `buildSnapshotGameState`'in koltuk
       ve joker eşlemesi, kart içeriği + koltuk rozetleri +
       `build/screenshots/game_history.png`, güncel ad, eski kayıt
       yedeği, başkasının geçmişi, tahtayı aç/kapa, kayıt yok hâli, boş
       liste). 121/121 yeşil, analyze temiz. **Doğrulama sınırı:** gerçek
       `games` SELECT'i ve RLS'i cihazda doğrulanmalı.
     - **Bilinçli eksikler (5b):** beğeni (`game_likes` RPC'leri,
       "Favoriler" sekmesi, beğenenler listesi), paylaşma (PNG yakalama +
       native share), sohbet rozeti/dökümü, `RecentGamesSection`
       ("Son Oynadıklarım") ve onun `initialExpandedId` akışı.
   - ✅ **Parça 5b — beğeni zinciri + sohbet arşivi (6 Ağustos 2026,
     `ui/chat/`, `ui/score/game_history_modal.dart`, `data/games_api.dart`):**
     Kartın başlığına kalp + beğeni sayısı + sohbet rozeti, listeye
     Tümü/Favoriler sekmeleri geldi.
     - **Beğeni web'in İKİ sözleşmesini birebir koruyor:** (1) `likedByMe`
       her zaman İSTEĞİ YAPANIN durumu — listelenen kişiden bağımsız,
       böylece başkasının kartındaki oyun da beğenilebilir; (2) toggle
       İYİMSER: `flipLike` anında uygulanır, repo `null` dönerse (ağ
       hatası) aynı `flipLike` ikinci kez uygulanarak geri alınır. Repo
       state tutmuyor, geri alma kararı çağıranda (web'deki yer).
     - **`_mergeLikeStats` TEK sorgu** (`game_like_stats`) ve iki koruma:
       misafirde hiç sorulmuyor (beğeni oturum gerektirir), hata listeyi
       DÜŞÜRMÜYOR (geçmiş zaten elde, kartlar beğenisiz çizilir). İkisi de
       ayrı testlerle sabitlendi (sahte uç çağrılırsa `fail()`).
     - **`isMyRow` artık SATIR bazında** (`entry.userId == viewer`) —
       Favoriler listesi başkasının satırını döndürebildiğinden, web'in
       kod incelemesiyle kapattığı hata buraya taşınmadan önlendi: aksi
       halde görüntüleyenin güncel adı rakibin skoruna yapıştırılırdı.
       Regresyon testi var.
     - **Yakalanan parite farkı (5a'dan kalma):** "Yapay Zeka" rozeti
       `isOnline ? Canlı : Yapay Zeka` diye basitleştirilmişti; web koşulu
       `!isOnline && players'ta GERÇEKTEN bir YZ koltuğu var`. Eski
       (players'sız) yerel kayıtlar artık web'deki gibi rozetsiz.
     - **`ChatThread` paylaşılan bileşen olarak yazıldı** (bugün yalnızca
       arşiv tüketiyor; Canlı sohbet ekranı geldiğinde `mine` doldurulup
       aynı bileşen kullanılacak — web'de de tek bileşen iki yeri
       besliyor). Web'in `onBadgeClick`/`senderId` yolu BİLİNÇLİ YOK:
       arşivde zaten salt-görsel, canlı sohbet portlanana kadar çalışmayan
       kontrol koymuyoruz. Rozet eşlemesi renk indeksi üzerinden
       (`chat_flags_for_finished_game`) — donmuş snapshot kimlik taşımaz.
       Sıra ters ÇEVRİLMİYOR: arşiv bir döküm (web'de bir dönem
       `.reverse()` vardı, admin ekranıyla ayrıştığı için kaldırılmıştı).
       **BU SATIR ARTIK GEÇERSİZ — 9 Ağustos 2026'da dört ekran birden
       "en yeni en üstte"ye çevrildi (Parça 36); "arşiv bir döküm" ayrımı
       kullanıcı isteği değil bir yorumdu.**
     - **Test dersi — `find.text('1')` rozet numarasıyla çakışıyor:**
       beğeni/mesaj sayacı ile `PlayerBadge`'in koltuk numarası aynı metni
       üretiyor. Sayaçlara `ValueKey('like-count-…')`/`('chat-count-…')`
       eklendi; sayı doğrulaması key'in altındaki `Text`ten okunuyor.
     - Doğrulama: `game_likes_test.dart` (13 test) + ortak `gameRow`/`snap`/
       `newRepo` yardımcıları `test/support/game_rows.dart`'a çıkarıldı
       (iki test dosyası paylaşıyor). 134/134 yeşil, analyze temiz,
       `build/screenshots/chat_history.png`. **Doğrulama sınırı:** dört RPC
       (`toggle_game_like`, `game_like_stats`, `game_likers`,
       `list_liked_games`) ve `chat_flags_for_finished_game` cihazda gerçek
       oturumla doğrulanmalı.
     - **Bilinçli eksikler (5c):** paylaşma (tahta önizlemesine dokununca
       açılan ActionSheet + PNG yakalama + sistem paylaş sayfası +
       `set_game_shared`) ve `RecentGamesSection` ("Son Oynadıklarım") +
       `initialExpandedId`/karta ortalama akışı.
   - ✅ **Parça 5c — paylaşma + "Son Oynadıklarım" (6 Ağustos 2026,
     `util/share_board.dart`, `ui/game/action_sheet.dart`,
     `ui/game/player_avatar_row.dart`, `ui/score/score_box_row.dart`,
     `ui/setup/recent_games_section.dart`):** Oyun geçmişi zinciri
     tamamlandı; Setup'a biten oyunların kısa listesi geldi.
     - **İLK platform eklentileri:** `share_plus` + `path_provider`
       (paylaş sayfası ve geçici dosya). `pubspec.lock` bu ortamın Flutter
       3.35.4'ü ile yeniden çözüldüğü için ilgisiz paketlerde de sürüm
       düşüşü içeriyor — kullanıcının daha yeni SDK'sı bir sonraki
       `pub get`'te geri yükseltir, zararsız.
     - **Yakalama web'den DAHA basit çıktı:** web DOM'u `html-to-image`
       ile yakalamak zorunda (gradyan/gölge/SVG dış hatlarını elle canvas'a
       çizmek kırılgandı); Flutter'da `RepaintBoundary.toImage` bunu
       yerleşik ve kayıpsız veriyor — ek kütüphane yok. Yakalanan düğüm
       web'le aynı: `ScoreBoxRow` + tahta, beyaz zeminli.
     - **Sıra sözleşmesi web'le aynı:** önce `set_game_shared` (link ancak
       o bayrakla bir şey gösterir), sonra görsel, sonra paylaş. İşaretleme
       düşerse LİNKSİZ paylaşılır (hiç paylaşmamaktan iyi) — testi var.
     - **`ActionSheet` portu bir widget değil bir çağrı yardımcısı:** web
       karartma katmanını ve kayarak belirişi elle yazmıştı (kullanıcı
       "altta çıkıyor, fark edilmiyor" demişti); Flutter'ın
       `showModalBottomSheet`'i ikisini de yerleşik veriyor.
     - **`PlayerAvatarRow` ortak bileşene çıkarıldı** — Setup'ın devam eden
       oyun satırındaki `_AvatarStrip` (canlı `Player` listesi) ile "Son
       Oynadıklarım"ın satırı (dondurulmuş `games.players`) aynı görseli
       çiziyor; web'de de tek bileşen iki yeri besliyor. Misafir tespiti
       core'daki `guestPlayerName` sabitiyle — yeni bir kopya YAZILMADI
       (yazan `doStart` ile okuyan taraf sessizce ayrışmasın diye).
     - **`initialExpandedId`:** hedef bulunana kadar sayfa sayfa çekme
       (web'in düzeltmesi: "Son Oynadıklarım" tür filtreli, geçmiş listesi
       karma → hedef ilk sayfanın gerisinde kalabiliyor) + karta ortalama.
       Web burada iç içe kaydırma alanları yüzünden `scrollTop`'u elle
       hesaplamak zorunda kalmıştı; Flutter'da `Scrollable.ensureVisible
       (alignment: 0.5)` bunu çözüyor — tek incelik ListView'ın tembelliği:
       hedef henüz build edilmemişse birer viewport atlayıp tekrar bakan
       sınırlı bir döngü var.
     - **İKİ test tuzağı (ikisi de aynı kökten: sahte zaman gerçek işi
       tamamlamaz):** (1) widget testinde repoyu `await newRepo(...)` ile
       hazırlamak testi SÜRESİZ asıyor — `newRepoForWidget` (runAsync)
       eklendi, yeni widget testlerinde HER ZAMAN o kullanılmalı; (2)
       `RepaintBoundary.toImage` sahte zamanda hiç tamamlanmıyor, paylaş
       akışı sessizce orada asılı kalıyordu → yakalama `CaptureBoardFn`
       olarak enjekte edilebilir yapıldı; gerçek yakalayıcı AYRI bir testte
       `runAsync` ile (PNG imzası kontrolüyle) doğrulanıyor.
     - Doğrulama: `share_recent_test.dart` (8 test) + gerçek paylaşım
       görselinin kendisi `build/screenshots/share_image.png` olarak
       yazılıyor (paylaşılan PNG'nin BİREBİR aynısı — yakalama düğümü aynı),
       `build/screenshots/recent_games.png`. 142/142 yeşil, analyze temiz.
       **Doğrulama sınırı:** `set_game_shared` RPC'si ve gerçek sistem
       paylaş sayfası (share_plus/path_provider kanalları) cihazda
       doğrulanmalı.
     - **Bilinçli eksik:** Setup'ta web'deki "Devam Edenler / Son
       Oynananlar" ALT SEKMELERİ hâlâ yok — liste devam edenlerin altında
       duruyor; Canlı sekmesi (dolayısıyla `onlineOnly: true` kullanımı)
       Canlı oyun fazının işi.
   - ✅ **Parça 6 — deep link altyapısı + şifre sıfırlama (7 Ağustos 2026,
     `ui/auth/reset_password_modal.dart`):** AuthModal'daki son dürüstlük
     diyaloğu ("Şifremi unuttum → kelimeki.com üzerinden") gerçek akışla
     değişti; `kelimeki` custom şeması iki platforma da kaydedildi (bkz.
     yukarıdaki "Flutter Uygulama İskeleti" platform notları).
     - **Deep link borusu SIFIR özel kodla kuruldu — kaynaktan doğrulanan
       üç halka:** (1) gotrue 2.27.1'in `resetPasswordForEmail`'i PKCE
       verifier'ı `passwordRecovery` OLAY ADIYLA saklıyor ve dönüşteki
       `?code=...` takası (`exchangeCodeForSession`) bu adı okuyup
       `AuthChangeEvent.passwordRecovery` yayınlıyor — yani supabase_flutter
       v2'nin varsayılan PKCE akışında flow tipi değiştirmeye/elle URI
       ayrıştırmaya GEREK YOK (eski sürümlerde bilinen bir eksikti, bu
       sürümde kapalı — pub-cache kaynağı okunarak doğrulandı, tahminle
       değil). (2) supabase_flutter auth parametresi (`code`/`access_token`/
       `error*`) taşıyan HER gelen URI'yi app_links üzerinden kendisi
       yakalayıp `getSessionFromUrl`'a verir; taşımayanlara DOKUNMAZ —
       gelecekteki `kelimeki://davet/...` linkleri aynı `AppLinks()
       .uriLinkStream`'den (broadcast) bağımsız dinlenebilir, arkadaşlık
       parçası boruyu hazır bulacak. (3) Mobilde İLK (cold start) URI de
       aynı stream'e dahil — soğuk başlangıç için ayrı kod yok.
     - **`AuthService`:** `passwordRecovery`/`clearPasswordRecovery` (web
       useAuth), `sendPasswordReset` (web'den tek fark `redirectTo:
       resetRedirectUri` — `kelimeki://reset`, env.dart) ve `setNewPassword`
       portları. **Dashboard el işi:** bu URI Supabase → Authentication →
       URL Configuration → Redirect URLs'e eklenmeli (mobile/TESTING.md'de
       ön koşul maddesi) — eklenmezse GoTrue linki sessizce Site URL'e
       düşürür, repo/migration izi olmayan bir konfigürasyon.
     - **AuthModal forgot modu** web'le birebir: yalnız e-posta +
       "BAĞLANTI GÖNDER" + "Giriş ekranına dön"; başarı bilgisi ALTIN
       renkte — `_infoGold` web `infoTone`'un portu ("Hesap oluşturuldu"
       kırmızı kalır). Boş e-posta web'de HTML `required` ile engelli,
       mobil karşılığı açık kontrol ('E-posta zorunludur.').
     - **Kök recovery kapısı `MaterialApp.builder`'da** (web App.tsx erken
       dönüşü): builder Navigator'ı SARDIĞINDAN kapı hangi rota/dialog açık
       olursa olsun önde; alttaki ağaç sökülmez (state korunur — web'de de
       App component'i mount kalıp yalnızca render'ı değişiyordu), beyaz
       `ModalBarrier` web'in "boş sayfa + ortada modal" görünümünü verir.
       **İki incelik:** (a) katman Navigator'ın DIŞINDA yaşadığından kendi
       `Overlay`'i şart — KModal ✕'inin tooltip'i gibi Overlay isteyen her
       şey onsuz fırlatırdı; (b) `KModal`'a opsiyonel `onClose` eklendi
       (web Modal'ın prop'u) — route'suz inline render'da varsayılan
       `Navigator.pop` ALTTAKİ GERÇEK EKRANI pop ederdi.
     - **Süresi geçmiş bağlantı SESSİZ (bilinçli parite):** dönüş linki
       `error` parametresi taşır → supabase_flutter akışa hata verir →
       dinleyici yalnızca loglar; web de aynı durumda sessizce ana sayfaya
       düşüyor. Ayrı bir hata ekranı bilinçli eklenmedi (TESTING.md'de
       dürüst madde).
     - Doğrulama: `reset_password_test.dart` (5 test — bayrak birimi;
       forgot geçişi + boş e-posta + akışın `sendPasswordReset`'e indiği
       'Supabase yapılandırılmadı.' kanıtı; modal doğrulama sırası/
       metinleri + başarı + onDone; sunucu hatasının friendlyAuthMessage'tan
       geçişi; kök kapı — bariyerin dokunuşu yuttuğu dahil — + ekran
       görüntüsü `build/screenshots/reset_password.png`); auth_test'in eski
       diyalog beklentisi güncellendi. 148/148 yeşil, analyze temiz;
       manifest/plist elle düzenlemesi attribute seviyesinde doğrulandı
       (üretici dersinin refleksi — portre kilidi/mevcut filtreler birebir).
       **Doğrulama sınırı:** gerçek e-posta + deep link + PKCE takası bu
       ortamdan test EDİLEMEZ (Supabase'e gerçek istek + e-posta kutusu +
       cihaz gerekir) — TESTING.md bölüm 2'deki dört yeni maddeyle cihazda
       doğrulanmalı; Redirect URL Dashboard'a eklenmeden akış çalışmaz.
   - ✅ **Parça 7 — Görüş Bildir formu (7 Ağustos 2026,
     `data/feedback_api.dart`, `ui/feedback/feedback_modal.dart`):**
     depolama fazında açılıp bugüne dek boş duran `pending_queue`
     `kind='feedback'` kanalı artık gerçekten dolup boşalıyor; web
     `FeedbackModal.tsx` + `submitFeedback` (api.ts) +
     `submitFeedbackDurable`/`flushPendingFeedback` (feedbackSync.ts) portu.
     - **`FeedbackRepo` SENKRON kurulur** (storage Future'ını içeride
       bekler) — `AppServices.feedback` bu sayede GamesRepo gibi `Future`
       değil; AuthModal→Terms/Privacy zinciri gibi UI katmanları Future
       taşımadan referans alabildi. Supabase yapılandırılmamışken bile
       DOLU (gateway'i null) — web feedbackSync'in "configured değilken de
       kuyrukla" davranışı; mesaj hiçbir konfigürasyonda kaybolmaz.
     - **Flush OTURUM ŞARTSIZ** — `GamesRepo.flushPending`'den bilinçli
       fark: anonim geri bildirim RLS'te zaten serbest
       (`feedback_insert_any`), web de girişsiz flush'lıyor. Tetikleyici:
       Setup `initState` (web App.tsx mount + 'online' olayının karşılığı;
       connectivity dinleyicisi için paket EKLENMEDİ — Setup'a her dönüş
       yeterli). `feedback` tablosu `TableWriteQueue`ya bilinçli GİRMİYOR:
       append-only insert, okuma yolu yok — DELETE→SELECT yarışı kurulamaz.
     - **Web'in üç bot önleminden ikisi taşındı, biri bilinçli taşınmadı:**
       rate limit (3 mesaj/10dk — karar repo'da, geçmiş FlagsStore
       `feedback_submission_times`'ta; kuyruğa düşen de pencereye sayılır,
       web recordSubmission) ve MIN_SUBMIT_MS (1.5sn altı gönderim → hiçbir
       şey kaydetmeden sahte "gönderildi", modal'da). **Honeypot YOK** —
       gizli form alanı web crawler'ları için var, native uygulamada o
       vektör yok.
     - **"Üyeliğine devam" teklifi** (misafir + e-posta girmiş): EVET →
       AuthModal KAYIT modunda, e-posta önceden dolu,
       `signup_channel='form'` — AuthModal'a web'in `initialMode`/
       `initialEmail`/`signupChannel` prop'ları eklendi
       (`startInSignup`), `AuthService.signUp`'a `signupChannel` parametresi
       (varsayılan 'direct', davranış değişmedi). Web'in `fromEmailLink`
       prop'u BİLİNÇLİ yok — o bağlam yalnızca web'in `?contact=1` e-posta
       linkinden geliyor, mobilde öyle bir giriş yolu yok.
     - **İki bağlama:** GameOver'daki eksik "GÖRÜŞ BİLDİR" linki
       (`onFeedback` opsiyonel — testler/önizlemeler vermezse çizilmez;
       source `game_end`) ve Terms/Privacy içindeki "Görüş Bildir formu"
       linki (source `general`) — legal_modals'ın "sonraki sürümde" stub'ı
       SİLİNDİ; `_FeedbackLinkLine` callback'siz kurulursa ölü link yerine
       düz metin çizer. Zincir enjeksiyon disipliniyle taşındı (services →
       Setup/GameScreen → GameHeader/AccountButton/MembershipPerksBox →
       showLoginModal → AuthModal → legal modaller). `auth_modal` ↔
       `feedback_modal` BİLİNÇLİ döngüsel import — web'in GameHistoryModal
       ↔ PlayerScoreCard emsali: iki referans da yalnızca çalışma anında.
     - **Test yakaladı (gerçek hata):** ilk sürümde `late final _openedAt =
       _now()` — `late` TEMBEL değerlendirilir, ilk erişim `_submit`
       içindeydi; açılış zamanı gönderim anına eşitlenip HER ilk gönderim
       bot sanılırdı. `initState`'e taşındı. **Ders:** "açılış anını
       damgala" niyetiyle `late final x = now()` yazma — damga initState'te
       atılmalı.
     - **İki test-izolasyon dersi** (`feedback_test.dart` başındaki
       yorumlarda): (1) sqflite factory'si `inMemoryDatabasePath`'i AÇIK
       KALDIKÇA paylaşır — kapatmayan test dosyası sonrakine veri sızdırır;
       benzersiz temp dosya yolu kapatma sırasına bağımlı olmayan izolasyon
       verir. (2) id üreticisini repo başına sıfırlamak, aynı kuyruğa yazan
       iki reponun id çakışmasında enqueue dedup'ının ikinci kaydı sessizce
       yutmasına yol açar — sayaç global olmalı.
     - Doğrulama: `feedback_test.dart` (10 test — repo: başarı/kuyruk/
       gateway-null/rate-limit penceresi/flush-oturumsuz-bozuk-kayıt;
       modal: misafir tam akış + üyelik teklifi → KAYIT, girişli "Yanıt
       e-postan" + ekran görüntüsü `build/screenshots/feedback_form.png`,
       bot dalı, rate-limit hatası; bağlamalar: GameOver linki iki dal,
       Kayıt→Terms→form zinciri). 158/158 yeşil, analyze temiz.
       **Doğrulama sınırı:** gerçek `feedback` insert'i (RLS, user_id/
       e-posta fallback'i) cihazda doğrulanmalı — TESTING.md "Görüş
       Bildir" maddeleri.
   - ✅ **Parça 8 — arkadaşlık sistemi (7 Ağustos 2026,
     `data/friends_api.dart`, `data/friend_invite_inbox.dart`,
     `ui/friends/friends_modal.dart`):** Canlı oyunun ön koşulu kapandı —
     web Faz 1'in tam portu.
     - **`FriendsRepo`/`SupabaseFriendsGateway`:** web api.ts'in arkadaşlık
       bölümü birebir (arama/tüm üyeler/istek gönder-yanıtla/çıkar/ilişki/
       davet linki üret-önizle-kabul). `sendFriendRequest` dönüşü UI'a
       taşınır (karşılıklı istek → sunucu trigger'ı anında accepted; o
       durumda `notify-friend-request` maili BİLEREK gitmez — web parity).
       Listeler `trCompare` ile client'ta sıralanır; tüm-üyeler
       sayfalamasında HER sayfadan sonra TÜM birikmiş liste yeniden
       sıralanır (web'in Türkçe collation sayfa sınırı dersi). Tek bilinçli
       sapma: liste hatası web'in `[]`'i yerine `null` (StatsRepo kararı —
       yanlış "hiç arkadaşın yok" gösterme).
     - **`FriendsModal` (KModal):** üç sekme + davet butonu. Varsayılan
       sekme: bekleyen istek varsa "İstekler" (yalnızca GERÇEK sunucu
       verisiyle, bir kez — web hasFreshGames dersi; `initialTab` verilirse
       ezilmez). Çıkar/Reddet/İptal onay+sonuç diyalogları paylaşılan
       `confirmFriendAction`/`showFriendInfoDialog` yardımcılarında.
       Davet paylaşımı web'in aynı https linkini (`webOrigin/davet/:token`)
       sistem paylaş sayfasıyla gönderir — clipboard fallback'i mobilde
       bilinçli yok; sekme etiketleri/butonlar trUpper (web CSS uppercase).
     - **`CountBadge` portu** (`ui/game/count_badge.dart`, web anlam
       sözleşmesi yorumda) — İstekler sekmesi + hesap menüsündeki
       "Arkadaşlar" satırı kullanıyor; `KAvatar`'a web `Avatar.dot`
       eşleniği eklendi (sayısız var/yok noktası), hesap avatarında
       bekleyen istek göstergesi. `AccountButton` StatefulWidget oldu:
       sayaç mount + hesap değişimi (user.id kararı) + FriendsModal
       kapanışında tazelenir (web UserMenu anları; Realtime web'de de yok).
     - **`PlayerScoreCard` arkadaşlık simgesi:** isim yanında ilişkiye göre
       yeşil ✓ (çıkar onayı) / kişi-ekle ikonu (duruma göre ekle/kabul/
       iptal onayı) — `friends` verilmezse hiç çizilmez (eski davranış).
       Zincir: services → Setup/GameScreen → GameHeader → AccountButton →
       Leaderboard/ScoreCard → PlayerScoreCard (feedback zinciriyle aynı
       enjeksiyon disiplini).
     - **Davet deep link'i:** `FriendInviteInbox` app_links akışını dinler
       (supabase_flutter'la aynı broadcast akış — davet URI'ları auth
       parametresi taşımadığından iki dinleyici kesişmez; app_links artık
       DOĞRUDAN bağımlılık, zaten transitive'di). `parseInviteToken` iki
       biçimi tanır: `kelimeki://davet/<t>` ve `https://kelimeki.com/
       davet/<t>`. Token `pending_events`e (`friend-invite-token` —
       depolama fazında açılan kanal) yazılır; SetupScreen işler:
       girişliyse `takeAll` → `accept_friend_invite` → sonuç diyaloğu
       (web App.tsx yolu SESSİZDİ — mobilde sayfa olmadığından bilinçli
       ekleme); girişsizse kuyruk TÜKETİLMEZ, yalnızca son link için bir
       kez "X seni eklemek istiyor, giriş yapınca ekleneceksiniz"
       önizlemesi (web /davet sayfasının karşılığı). Kabul hatası token'ı
       web'deki gibi DÜŞÜRÜR (sonsuz yeniden deneme kilidi olmasın).
     - **İki test dersi:** (1) testWidgets İÇİNDE `await Future.delayed`
       fake-async bölgesinde ASILIR (timer pump'sız çözülmez) — 3+ dakika
       asılı kalan test bundan çıktı; (2) odaklı bir TextField'ın imleç
       animasyonu `pumpAndSettle`'ı asar (alan ekranda kaldıkça) — sınırlı
       `pump` kullan (feedback formunda görünmemişti çünkü gönderim alanı
       söküyordu).
     - Doğrulama: `friends_test.dart` (14 test — parse/inbox/repo
       sıralama-yön-bildirim/modal sekmeleri+patch+onaylar/AccountButton
       rozeti/PlayerScoreCard simgesi/kuyruk işleme; ekran görüntüsü
       `build/screenshots/friends_modal.png`). 172/172 yeşil, analyze +
       değişmez taraması temiz. **Doğrulama sınırı:** gerçek RPC'ler/RLS,
       gerçek davet e-postası/linki ve iki hesaplı karşılıklı-istek
       trigger'ı cihazda doğrulanmalı — TESTING.md "Arkadaşlar" bölümü.
     - **BU SINIR KAPANDI (11 Ağustos 2026, iki gerçek hesapla —
       `mobile/TESTING.md` bölüm 10'un tamamı geçti):** rozet + varsayılan
       "İstekler" sekmesi, kabul/çıkar/gönder/iptal dörtlüsü ve sonuç
       mesajları, "Tüm Üyeler" sayfalaması (20 → 22), arama, davet linki,
       `PlayerScoreCard` simgesinin üç hâli ve iPad yatayda diyalog
       genişliği. **Karşılıklı-istek trigger'ı sunucudan BAĞIMSIZ olarak
       da kanıtlandı:** `friend_requests` satırının `created_at` ile
       `responded_at`'i AYNI dakika (14:53) — bu, "Kabul Et"e basılmış bir
       isteğin değil `handle_friend_request_insert`'ün imzası; yani
       istemci kabul göndermedi, sunucu anında birleştirdi. Bir ekran
       görüntüsü/kullanıcı beyanı yerine veriden okunabilen bu tür bir iz
       aramak, "test geçti" ile "doğru mekanizma çalıştı" arasındaki farkı
       kapatıyor (bkz. Parça 49'un aynı dersi).
       **Hâlâ açık olan tek parça:** `kelimeki://davet/<token>` derin
       bağlantısı — custom şemayı yalnızca GERÇEKTEN kurulu bir uygulama
       yakalayabildiğinden web derlemesinde test EDİLEMEZ, FAZ B'de
       `kelimeki://reset` ile birlikte bakılacak.
   - ✅ **Parça 9 — Canlı oyun davet/kabul akışı (7 Ağustos 2026,
     `data/online_games_api.dart`, `ui/live/`):** Canlı fazın ilk alt
     parçası — web Faz 2'nin (davet + kabul) tam portu; ARKADAŞINLA sekmesi
     artık dürüst diyalog değil gerçek `LiveGamesTab`. Oynanış (tahta +
     `submit_move` + state senkronu) BİLİNÇLİ olarak sonraki alt parça —
     aktif oyuna dokunmak şimdilik dürüst "tahta sonraki sürümde,
     kelimeki.com'dan oynayabilirsin" diyaloğu gösteriyor.
     - **`OnlineGamesRepo`/`SupabaseOnlineGamesGateway`:** web api.ts'in
       `listMyOnlineGames`/`createOnlineGame`/`respondToGameInvite`/
       `fetchOnlineGameTurns`/`fetchOnlineGameDeadlines` bölümü, GamesRepo
       gateway/repo bölünmesiyle. Web sözleşmeleri birebir: `create`
       sonrası `notify-game-invite` fire-and-forget (hata yalnız loglanır);
       "hafif süpürme" `load()`un içinde — süresi ZATEN dolmuş sıra/davet
       görülürse `check_turn_timeout`/`check_invite_expiry` tetiklenip
       liste BİR KEZ daha çekilir (testte sahte sunucu etkisiyle iki fetch
       sayılarak kanıtlı); liste hatası `null` (StatsRepo kararı — UI eski
       listeyi korur). Realtime aboneliği ÜÇ tabloda (`online_games` +
       `game_invites` + `online_game_states` — web 4 Ağustos dersi: hamle
       yalnız state'i değiştirir), kanal adı `uuidV4` ile benzersiz, her
       tüketici 300ms debounce'lar (web kuralı).
     - **Kova filtreleri saf fonksiyon olarak** (`inviteBucket`/
       `activeBucket`/`waitingBucket`/`acceptedWaitingBucket`/
       `myTurnCount`): `inviteBucket` `status == pending` ŞARTINI taşıyor —
       web'in 4 Ağustos 2026 hayalet-davet hatası (iptal edilen davet
       davetlinin listesinde sonsuza dek kalıyordu) porta hiç girmeden
       kapandı, testi de var. `activeBucket` sıra-bende-önce sıralamasında
       indeks tie-break kullanıyor (Dart `List.sort` kararlı değil — core
       sözleşmesinin UI katmanındaki tekrarı).
     - **`LiveGamesTab`:** üç alt sekme (Devam Edenler / Oyun Davetleri /
       Son Oynananlar) `CountBadge` rozetli; varsayılan alt sekme kuralı
       web'in düzeltilmiş hâliyle — karar YALNIZCA sunucudan dönen taze
       sonucun setState'inde veriliyor (önbellek hidrasyonu initState'te,
       karara hiç değmiyor — hasFreshGames dersinin yapısal hâli), elle
       seçim kalıcı devre dışı bırakıyor, sekme sonradan otomatik
       değişmiyor. Modül seviyesinde `user.id` anahtarlı snapshot önbelleği
       (web liveGamesCache), hesap değişimi `user.id` karşılaştırmasıyla,
       eski yüklemenin sonucu `_loadSeq` sayacıyla düşürülüyor (web iptal
       jetonunun sayaç karşılığı). Kalan süre etiketi YALNIZCA sırası
       çağıranda olan satırda (web 3 Ağustos dersi). Kabul → henüz arkadaş
       olunmayan katılımcılar için `FriendSuggestModal` (hepsi önceden
       işaretli, tekil istek hatası yutulur) — web'in aynı akışı.
     - **`LiveGameCreateForm`:** kompozisyon kuralı istemcide de aynı
       (2 kişilikte tam 1 arkadaş/YZ yok; 4 kişilikte 2-3 arkadaş, yalnız
       4. koltuk YZ). 2 arkadaşla gönderimde "4. koltuk Yapay Zeka ile
       doldurulacak, tamam mı?" onayı; HAYIR → kalıcı YZ satırı (bir daha
       sorulmaz, 3 arkadaş seçiliyken pasif). Gönderim sonrası "Davetiniz
       gönderilmiştir." ekranı — isimler gönderim ANINDA dondurulur
       (web sentTo). Arkadaş listesi hesap değişiminde `user.id` ile
       yeniden çekilir (web 5 Ağustos dersi — form tam görünüm, mount'ta
       kalarak hesap değişimini atlatabilir). **Bilinçli sapma:** web'in
       viewport'a sabit alt barı yok (o, web'in #root scroll yapısına özgü
       bir düzeltmeydi; mobilde liste kendi 280px sınırında kaydırılıyor).
     - **Test dersi:** öneri modalının arkasındaki davet kartı aynı
       isimleri çizdiğinden `find.text` çakışır — finder
       `find.descendant(of: find.byType(Dialog))` ile daraltılmalı.
     - **Rozet konumu düzeltildi (aynı gün, kullanıcı bildirdi):** sekme
       rozetleri web'de SEKME KUTUSUNUN sağ üst köşesine oturur (`absolute
       -top-1 -right-1` — buton `relative`); ilk sürümde Stack yalnızca
       `Text`'i sardığından rozet METNİN yanına düşüyordu. Hem
       `LiveGamesTab._subTabBtn` hem `FriendsModal._tabBtn` (aynı hata
       oradan kopyalanmıştı) düzeltildi: Stack tüm kutuyu sarar, rozet
       `Positioned(top: -4, right: -4)`. **Ders:** rozetli bir sekme/buton
       porta gelirken Stack'in NEYİ sardığına bak — web'in `relative`
       referansı buton, metni saran Stack aynı koordinatlarla farklı yere
       konumlar.
     - Doğrulama: `live_games_test.dart` (16 test — kova filtreleri
       [status==pending şartı dahil], süre etiketleri enjekte nowMs ile,
       repo load/süpürme/null-hata/create+notify, LiveGamesTab varsayılan
       sekme + kabul→öneri→istek akışı + durum/kalan-süre etiketleri +
       `build/screenshots/live_games.png`, form 2/4 kuralları + YZ onayı +
       sentTo + VAZGEÇ); `setup_screen_test`'in eski ARKADAŞINLA diyalog
       beklentisi misafir giriş-çağrısı görünümüne güncellendi. 188/188
       yeşil, analyze + değişmez taraması temiz. **Doğrulama sınırı:**
       gerçek RPC'ler (`list_my_online_games`/`create_online_game`/
       `respond_to_game_invite`/süpürmeler), Realtime kanalları ve davet
       e-postası cihazda iki hesapla doğrulanmalı — TESTING.md bölüm 11.
   - ✅ **Parça 10 — Canlı oyun TAHTASI (7 Ağustos 2026,
     `ui/live/online_game_screen.dart`, `data/online_games_api.dart`
     oynanış yarısı):** web `OnlineGameScreen.tsx` portu — ARKADAŞINLA →
     "Devam Edenler"deki bir oyuna dokunmak artık gerçek tahtayı açıyor,
     hamleler `submit_move` ile sunucuya gidiyor.
     - **Veri katmanı:** `OnlineMoveRow` + `buildMoveHistory` (web'in aynı
       adlı fonksiyonu — bölge vergisi payları AYRI `invasionFrom`
       satırlarına açılır), `OnlineGameSnapshot` ve
       `OnlineGamesRepo.loadGame` (state + KENDİ rafım + hamleler TEK
       turda; ağ hatasında null → ekran korunur, liste tarafının aynı
       sözleşmesi). Gateway'e `gameState`/`myRack`/`moves`/`triggerAiTurn`/
       `submitMove`/`subscribeGame` eklendi; `submitMove` mevcut
       `OnlineApi`'ye delege ediyor, yani **her hamle `p_move_id` taşıyor
       ve taşıma hatasında AYNI id ile yeniden deneniyor** (mobil ağın asıl
       kazancı; web bu parametreyi göndermiyor). `triggerAiTurn`/
       `sweepTurnTimeout` 20sn tavanlı (web `withTimeout` gerekçesi:
       çağıranın "devam ediyor" bayrağı asılı kalmasın).
     - **`GameController.actingSeat`** (yeni, opsiyonel — web
       `onlineGameReducerRef`): reducer'ın yerel düzenleme action'ları
       `state.current`'ın rafı üzerinden işler; Canlı'da sıra bende
       olmasa da taş koyabildiğimden (`canEdit`) bu action'lar BENİM
       koltuğum üzerinden işlemeli. `current` reduce süresince sabitlenip
       sonra sunucu değerine geri yükleniyor; `SyncOnlineStateAction` muaf
       (current'ı gerçekten o belirliyor) ve no-op kısa devresi korunuyor
       (`copyWith` her seferinde yeni nesne üretip `identical` kontrolünü
       işlevsiz bırakırdı). Varsayılan null → **yerel oyunun davranışı
       bitine kadar aynı**, üç testle sabitlendi.
     - **Ekran:** `canAct` (sunucuya gönderim — gerçekten sıra bende) vs
       `canEdit` (salt yerel düzenleme — oyun bitmediyse her zaman) ayrımı;
       sıra bende değilken kırmızı "SIRA: X — oynaması bekleniyor" bandı
       (YZ koltuğunda nabız atan noktayla "hamlesini hesaplıyor…"), taş
       konulunca bandın yerini mesaj satırı alır; mesaj satırı web'in
       türetme kuralını bire bir izler (geçersiz sebep → `offTurnNote` →
       `myTurnNote` → `state.message` → son hamleden türetilen metin).
       `online_game_states` mesaj taşımadığından "Esiner: +13 puan (4 puanı
       Ironman kaptı) Kelimeler: ARA" gibi satırlar `online_game_moves`'tan
       reducer'ın AYNI şablonlarıyla yeniden üretiliyor. Logo yalnızca
       listeye döner (oyunu BİTİRMEZ — teslim yalnızca 48 saatlik zaman
       aşımıyla); oyun bitince OYNA'nın yerini "CANLI LİSTESİ" alır. Skor
       kutusuna dokunmak oyuncunun kartını açar (`onPlayerTap`, yalnızca
       Canlı'da — yerel ekran bu prop'u geçmiyor).
     - **Bilinçli kod tekrarı:** sürükle-bırak katmanı + tahta/raf/buton
       düzeni `game_screen.dart` ile neredeyse birebir. Web de bunu iki
       ayrı dosyada taşıyor; ortak kabuğa çıkarmak web↔mobil dosya
       eşlemesini dolaylı hale getirirdi. Karşılığında yeni bir senkron
       kuralı doğdu — "Etki Analizi" bölümüne değişmez olarak yazıldı.
     - **Bilinçli SAPMA — kelime doğrulaması yerel:** web `handlePlay`
       her kelimeyi `is_valid_word` RPC'siyle sorar (kelime başına bir
       gidiş-dönüş, hatada yerel sözlüğe düşer). Mobilde sözlük zaten
       pakette ve tahtadaki canlı yeşil/kırmızı çerçeve onu kullanıyor —
       N sıralı RPC hem yavaş hem "çerçeve yeşil ama OYNA hata veriyor"
       çelişkisi riski. Tek yerel `validatePlacement` yeterli; sunucu
       zaten kelime doğrulamıyor (mimari karar), güvenlik kaybı yok. Tek
       gerçek fark: `public.words`a uygulama sürümü çıkmadan eklenen bir
       kelimeyi web oynar, mobil oynayamaz.
     - **Bulunan hata (test yakaladı) — `late final AnimationController`
       dispose'ta doğuyor:** banner'ın nabız controller'ı `late final _pulse
       = AnimationController(...)` idi; `late` TEMBEL olduğundan sıra bir
       İNSANDAYKEN (isAiTurn false) alan hiç okunmuyor, ilk erişim
       `dispose()`taki `_pulse.dispose()` oluyor ve orada `createTicker`
       sökülmüş elemanın atasını arayıp "Looking up a deactivated widget's
       ancestor is unsafe" ile patlıyordu. `initState`'te kurmaya çevrildi.
       **`late final _openedAt = _now()` dersinin (parça 7) ikinci yüzü** —
       kural genelleşti: `late final` bir alana YAN ETKİLİ ya da bağlam
       gerektiren bir değer bağlama, kurulumu `initState`'te yap.
     - Doğrulama: `online_game_screen_test.dart` (15 test — buildMoveHistory
       vergi/aksiyon eşlemesi; loadGame çözümü + null dalları; actingSeat'in
       üç kuralı (benim rafımdan işler + current korunur + no-op + yerel
       davranış değişmedi); ekran: katılımcı değil, sıra rakipte banner +
       süre taraması + YZ tetiklenmez, YZ koltuğunda `play-ai-turn`
       tetiklenir, off-turn egzersiz (+7 rozeti, "Kelime geçerli — Sıra:
       Esiner", OYNA pasif/gönderim yok), sıra bende KELİME → OYNA →
       payload (words/basePoints/placements), PAS GEÇ onay+vazgeç, sunucu
       reddinin mesaj satırına düşmesi, Realtime olayının tazelemesi +
       aboneliğin sökülmesi, son hamle mesajı + ekran görüntüsü
       `build/screenshots/online_game.png`). Tam takım **203/203 yeşil**,
       analyze + değişmez taraması temiz. **Doğrulama sınırı:** gerçek
       `submit_move`/`get_my_online_rack`/`play-ai-turn`/Realtime ve iki
       hesaplı gerçek oynanış cihazda doğrulanmalı — TESTING.md bölüm 11.
     - **Bu parçanın kapsamı DIŞINDA (bilinçli):** oyun içi mesajlaşma
       (Board footer'daki "Mesajlaşma" butonu Canlı'da da henüz yok —
       sohbet + sessize alma/raporlama ayrı parça).
   - ✅ **Parça 11 — oyun içi mesajlaşma (7 Ağustos 2026, `data/chat_api.dart`,
     `ui/chat/chat_modal.dart`, `ui/chat/chat_settings_modal.dart`,
     `online_game_screen.dart` bağlantısı):** web Faz 1 (sohbet) + Faz 2
     (sessize alma/raporlama) portu — yalnızca Canlı oyunlarda, yerel/YZ
     ekranına hiç dokunulmadı.
     - **`ChatRepo`/`ChatGateway`:** web `fetchOnlineGameMessages`/
       `sendOnlineGameMessage`/`subscribeOnlineGameMessages`/
       `fetchMyChatMutes`/`fetchMyActiveChatReports`/`setChatMute`/
       `reportChatParticipant`/`withdrawChatReports` birebir. Mute/rapor
       web'in 3 Ağustos 2026 kararıyla KİŞİ bazlı — `myMutes`/
       `myActiveReports` gameId almaz. Mesaj göndermek RPC değil doğrudan
       RLS insert'i (1-200 karakter istemci tarafı kısıtı tekrarlanır);
       rapor sunucu tarafında hedefi otomatik sessize alır, istemci ayrıca
       `setMute` çağırmaz.
     - **`_ChatState extends ChangeNotifier`** (`online_game_screen.dart`,
       yeni desen): `showDialog` ile açılan `ChatModal`/`ChatSettingsModal`
       ebeveyn widget'ın state'i değişince OTOMATİK yeniden çizilmiyor —
       ikisi de bu paylaşılan `ChangeNotifier`'ı `ListenableBuilder` ile
       dinleyerek gerçek zamanlı mesaj/mute/rapor değişikliklerini açık
       diyalogların içine sızdırıyor. Board'ın kırmızı nokta rozeti için
       tepedeki tek `ListenableBuilder` artık `Listenable.merge([_controller,
       _chatState])` dinliyor.
     - **"İlk-ziyaret" okunmamış mesaj tohumlama** — web'in aynı dersi:
       `ChatReadStore`'da hiç damga yoksa TÜM geçmişi "okunmamış" saymak
       yanlış pozitif kırmızı nokta üretir (özellik ilk devreye girdiğinde
       zaten sohbeti okumuş herkes için); damga yoksa en son mesaja (ya da
       şimdiye) sessizce oturtulup unreadCount 0 başlatılıyor, yalnızca
       BUNDAN SONRAKİ gerçek yeni mesajlar sayılıyor.
     - **`ChatSettingsModal`** — web'in 7 view'lık durum makinesi birebir
       (liste → detay → mute-confirm/report-reason→confirm→sent/withdraw-
       confirm); üç işlemin (mute aç/kapa, rapor geri çek) HEPSİNDE ayrı
       "Emin misiniz?" adımı var, yalnızca rapor GÖNDERME değil (web 2
       Ağustos düzeltmesi). Rozet (🚩 rapor / 🚫 mute) hem katılımcı
       listesinde hem sohbetteki mesaj balonunun yanında — ikisi de
       tıklanıp doğrudan o kişinin detayına (`initialParticipantId`) açılır.
     - **Bulunan hata (test yakaladı) — `ChatRepo.send`/`report` `async`
       DEĞİLDİ:** doğrulama `throw Exception(...)` senkron olarak
       çağıranın stack'inde fırlıyordu (Future.error'a sarılmadan) —
       `expectLater(repo.send(...), throwsException)` gibi bir Future
       bekleyen test Future hiç oluşmadan çöktü. **Ders (parça 7'nin
       `late final _openedAt`/parça 10'un `late final _pulse` dersinin
       üçüncü kardeşi, ama farklı bir sınıf):** `if (invalid) throw ...`
       içeren bir metod `async` OLMAK ZORUNDA, aksi halde hata Future
       sözleşmesini bozup senkron fırlar.
     - **Test dersi (sqflite'ın gerçek I/O'suyla ilgili, yeni bir alt
       tuzak):** `_openChatModal()`'daki `unawaited(_markChatReadTo(...))`
       fire-and-forget gerçek bir sqflite yazması başlatıyor; sqflite'ın
       dahili ~10sn'lik yazma-kilidi uyarı `Timer`'ı bu yazma GERÇEK
       zamanda tamamlanıp iptal olana kadar bekliyor. Gerçek depoyla
       (`newStorageForWidget`) kurulan widget testlerinde `unmount`'tan
       hemen önce bu timer hâlâ "beklemede" sayılıp "A Timer is still
       pending even after the widget tree was disposed" ile test
       düşüyordu — `tester.runAsync` içinde kısa bir GERÇEK zaman uykusu +
       `tester.pump()` yazmanın bitmesine yetip timer'ı iptal ettiriyor.
       **7 Ağustos 2026 — süre 50ms→200ms'ye çıkarıldı:** dosya tek başına
       koşulduğunda 50ms yetiyordu ama TÜM paket koşulurken (CPU daha
       yoğun, gerçek I/O daha yavaş tamamlanıyor) ara sıra aynı "Timer is
       still pending" hatasıyla flaky düşüyordu — tek dosya çalıştırmak bu
       sınıf bir hatayı YAKALAMAZ, tam paket koşusu şart. **Ders:** parça
       6'daki "gerçek sqflite I/O'su `tester.runAsync` gerektirir" dersinin
       İNCELTİLMİŞ hâli — sorun kilitlenme değil, fire-and-forget bir
       yazmanın kütüphane-içi bir zamanlayıcıyı test bitene kadar canlı
       bırakması; her DB etkileşimini `runAsync`'e sarmak yetmez, `unawaited`
       bir yazmaya GERÇEK zaman
       tanımak gerekir.
     - Doğrulama: `chat_test.dart` (20 test — ChatRepo doğrulama/hata
       yutma/RPC delegasyonu, ChatModal sıralama/rozet/sayaç/hata +
       `build/screenshots/chat_modal.png`, ChatSettingsModal 7 view'ın
       tamamı) + `online_game_chat_test.dart` (9 test — Board footer
       görünürlüğü, storage'sız sohbet akışı + Realtime popup/rozet/mute
       bastırma/canlı güncelleme, gerçek depoyla ilk-ziyaret tanıtımı +
       kalıcılık). **Tam takım 232/232 yeşil**, analyze + değişmez
       taraması temiz. ~~**Doğrulama sınırı:** iki gerçek oturumlu tarayıcı
       arasında Realtime mesaj/mute/rapor akışı bu ortamdan test
       EDİLEMEDİ~~ — **16 Ağustos 2026'da iki gerçek hesapla cihazda
       KOŞULDU ve GEÇTİ** (`mobile/TESTING.md` bölüm 11 → Mesajlaşma, 14
       maddenin tamamı: gerçek zamanlı gönder/al, tanıtım bayrağının
       hesaba özel olması, popup+rozet, rozet kalıcılığı, sessize alma,
       raporlama, geri çekme, arşiv tutarlılığı). Bu parçanın YAZILDIĞI
       gün (7 Ağustos) açık bırakılan en büyük sınır — dokuz gün sonra
       kapandı.
   - ✅ **Parça 12 — Setup'taki "Arkadaşınla (N)" rozeti + girişte Canlı
     sekmesi varsayılanı + "Arkadaşınla paylaş" (7 Ağustos 2026,
     `data/online_games_api.dart`, `ui/setup/setup_screen.dart`,
     `data/auth_service.dart`):** Web `Setup.tsx`'in aynı üç web'in
     BİRLİKTE anlattığı özelliğin portu — üçü de mimari yenilik gerektirmedi,
     var olan kova filtrelerini/`shareBoard` yardımcısını bağlamaktı.
     - **`OnlineGamesRepo.pendingCounts()`** — web `fetchPendingLiveGameCounts`
       birebir: `load()`'u tekrar kullanıp `inviteBucket(games).length` +
       `myTurnCount(games, turns)` döner. Aynı `status==pending` şartını
       (web'in 4 Ağustos 2026 hayalet-davet dersi) miras alıyor çünkü
       `inviteBucket`'ın kendisini çağırıyor — ikinci bir kopya açılmadı.
       Ağ hatasında `0/0` (rozet geçici kaybolur, `LiveGamesTab` kendi
       listesini ayrıca çeker).
     - **Rozet + girişte otomatik "Arkadaşınla"ya geçiş** (`SetupScreen`) —
       web `liveActionCount`/`appliedLoginDefaultRef` birebir: 300ms
       debounce'lu Realtime aboneliği (`gateway.subscribe`) + foreground
       (`WidgetsBindingObserver.didChangeAppLifecycleState`) tazelemesi;
       `_appliedLoginDefault` yalnızca hesap başına BİR KEZ tetiklenir.
     - **Web'in İKİ dokümante edilmiş hatası port SIRASINDA baştan
       önlendi** (kod yazılırken, sonradan bulunmadı — etki analizinin web
       kaynağını okuma adımı sayesinde):
       1. `_appliedLoginDefault`, `_lastUserId` (mount id'siyle başlayan,
          `user.id` karşılaştırmalı) değişince sıfırlanıyor — web'in "ilk
          hesap ref'i tükettikten sonra ikinci hesap hiç Canlı'ya
          geçirilmiyordu" hatasının portu hiç yaşamaması.
       2. `_liveView`, yalnızca GİRİŞLİDEN başka bir şeye (çıkış/hesap
          değişimi) geçişte sıfırlanıyor (`_lastAuthUserIdForLiveViewReset`,
          web `lastAuthUserIdRef`) — misafirken "Arkadaşınla"ya girip login
          olan kullanıcı BİLEREK o sekmede bırakılıyor.
       **Port sırasında bulunan ÜÇÜNCÜ, mobile'a özgü bir uyum sorunu:**
       React'in `[user]` bağımlı effect'i mount'tan HEMEN SONRA kendiliğinden
       bir kez çalışıp ref'i gerçek mount id'sine eşitliyor (`prev===null`
       olduğundan sıfırlamıyor) — Dart'ın `ChangeNotifier.addListener`'ı
       mount'ta ASLA otomatik tetiklenmiyor. Bu farkı gözetmeden
       `_lastAuthUserIdForLiveViewReset`'i `null` bırakınca, halihazırda
       GİRİŞLİ mount olup SONRA çıkış yapan ilk gerçek `_onAuthEvent`
       çağrısı "ilk çalışma" sanılıp `_liveView`'i sıfırlamıyordu (yazılan
       testte hemen yakalandı) — düzeltme `initState`'te
       `_lastAuthUserIdForLiveViewReset = _lastUserId` ile React'in
       mount-anı effect'ini elle taklit etmek. **Ders:** bir web ref'inin
       başlangıç değerini (`useRef(null)` vs `useRef(user?.id)`) Dart'a
       birebir kopyalamak yetmez — React'in effect'lerin mount'ta bir kez
       kendiliğinden çalıştığı gerçeğini de hesaba katmak gerekiyor,
       `ChangeNotifier` bunu bedava vermiyor.
     - **`AuthService.debugSetUser`** (yeni, `@visibleForTesting`) —
       `debugTriggerPasswordRecovery` ile aynı desen: fake auth'ta gerçek
       `onAuthStateChange` akışı olmadığından, hesap değişimi/çıkış
       senaryolarını test etmenin tek yolu.
     - **"Arkadaşınla paylaş"** — web `handleShare`'in `?ref=arkadas` UTM
       linkini `shareBoard(png: null, ...)` ile paylaşır; ikinci bir paylaşım
       yardımcısı YAZILMADI, 5c'nin `shareBoard`'ı zaten dosyasız/metin+link
       paylaşımını destekliyordu. Web'in clipboard-fallback + "Link
       kopyalandı!" geçici durumu BİLİNÇLİ taşınmadı — `share_plus`
       iOS/Android'de her zaman native paylaş sayfasına düşer, "paylaşım
       API'si yok" durumu (yalnızca masaüstü tarayıcılara özgü) mobilde
       hiç oluşmaz. Test injection'ı `GameHistoryModal.share`'daki AYNI
       desen (`SetupScreen.share` opsiyonel param, `widget.share ??
       shareBoard`).
     - Doğrulama: `live_games_test.dart`'a 2 test (`pendingCounts` toplamı +
       ağ hatası), `setup_screen_test.dart`'a 5 test (rozet + otomatik geçiş,
       negatif eşi — bekleyen iş yokken geçiş OLMAMALI, hesap değişimi
       sıfırlaması + ikinci hesabın kendi otomatik geçişi, paylaş butonu).
       **Tam takım 238/238 yeşil**, analyze + değişmez taraması temiz.
       **Doğrulama sınırı:** gerçek Realtime aboneliği ve gerçek sistem
       paylaş sayfası cihazda doğrulanmalı.
   - ✅ **Parça 13 — Hesap Ayarları ekranı (7 Ağustos 2026,
     `data/auth_service.dart`, `ui/auth/account_settings_modal.dart`,
     `ui/auth/account_button.dart`):** Web `AccountSettingsModal.tsx`
     portu — hesap menüsündeki son "çalışmayan madde koymuyoruz" boşluğu
     kapandı (Nasıl Oynanır? ile Çıkış Yap arasına, web'in sırasındaki
     gibi).
     - **`AuthService`'e üç yeni metod + `KProfile` genişlemesi:**
       `refreshProfile()` (web `useAuth.refreshProfile` birebir —
       YALNIZCA profili yeniden çeker, `loading`/`profileLoading`'e HİÇ
       dokunmaz; `_fetchProfile`'ı KASITLI OLARAK çağırmıyor, o
       `_profileLoading`'i true'ya çekip Kaydet sonrası tüm hesap
       kimliğine bağlı UI'ın — avatar, Setup'taki isim — bir an
       "yükleniyor" görünmesine yol açardı), `updateProfile(patch)` (web
       `updateProfile` birebir — patch yalnızca DEĞİŞEN alanları taşır,
       satır yoksa yedek insert dener), `updateEmail(email)`.
       `KProfile`'a `marketingConsent`/`marketingConsentAt`/
       `emailNotificationsEnabled` eklendi (varsayılan sırasıyla
       false/null/true — web `?? true` kuralı `emailNotificationsEnabled`
       için `fromMap`'te `!= false` ile taşındı).
     - **Bilinçli eksik — profil fotoğrafı değiştirme:** web'in dosya
       seçici + `uploadAvatar` (Supabase Storage) akışı BU PARÇANIN
       KAPSAMI DIŞINDA bırakıldı — `image_picker` gibi yeni bir platform
       bağımlılığı + storage upload + izin yapılandırması gerektiriyor,
       tek başına ayrı bir parça. Mevcut fotoğraf (varsa) salt-okunur
       gösteriliyor, ekranda "kelimeki.com üzerinden düzenleyebilirsin"
       notu var — web'in "sonraki sürümde" dürüstlük deseniyle tutarlı
       (bkz. `LiveGameCreateForm`/`Setup`'taki benzer notlar).
     - **Nickname debounce KÜÇÜK bir kopya olarak taşındı, `AuthModal`'a
       DOKUNULMADI:** web'in `useNicknameAvailability` hook'u hem
       `AuthModal` hem `AccountSettingsModal`'ı besliyor — Flutter'da
       State'ler arası doğrudan paylaşılamayan bu ~40 satırlık debounce+
       durum mantığı, riskli bir refactor yerine (172+ testi olan
       `auth_modal.dart`'ı bozma riski) kendi içinde bilinçli olarak
       tekrarlandı — `game_screen.dart`/`online_game_screen.dart`
       arasındaki "bilinçli kod tekrarı" kararıyla aynı sınıf. Web'in
       `useNicknameAvailability(nickname, true, profile?.display_name)`
       "mevcut isimle aynıysa kontrol atla" davranışı da taşındı.
     - **Test dersi — `find.ancestor`/`find.descendant` zincirinin
       "en yakın ata" varsayımı YANLIŞ:** ilk test taslağı web/AuthModal
       test dosyasındaki `fieldByLabel` desenini (`find.descendant(of:
       find.ancestor(of: label, matching: Column), matching: TextField)`)
       kopyalayıp "Too many elements" ile patladı. Kök sebep: Flutter'ın
       `find.ancestor`'ı bir widget'ın YALNIZCA EN YAKIN eşleşen atasını
       değil, köke kadar TÜM eşleşen atalarını döner (`_collectAncestors`
       kaynağı doğrulandı) — form birden fazla iç içe `Column` taşıdığından
       (`_labeled`'in kendi Column'u + dış form Column'u), `descendant`
       bu ikisinin BİRLEŞİMİNDEN arama yapıp forma dağılmış TÜM
       `TextField`'ları (yalnızca hedeflenen alanı değil) döndürüyordu.
       `signup_test.dart`'ın aynı deseni her çağrı yerinde `.first` ekleyip
       (ambiguity'yi ÖRTEREK, çözmeden) kullanıyor — kırılgan bir emsal.
       **Düzeltme, emsali kopyalamak yerine:** her alana açık bir
       `ValueKey('field-...')` verilip testte `find.byKey(...)` kullanıldı
       — kesin, refactor'a dayanıklı, hiçbir ata/torun belirsizliği yok.
       **Ders:** bir test yardımcısını (`fieldByLabel` gibi) başka bir
       dosyadan kopyalarken, o yardımcının ÇAĞRI YERLERİNDE gizli bir
       `.first`/ek varsayım olup olmadığını da kontrol et — yalnızca
       tanımını kopyalamak yeterli değil.
     - **Yan bulgu (bu parçanın testi sırasında) — `online_game_chat_test.dart`
       flaky çıktı:** tek başına koşulduğunda hep geçen "ilk açılışta
       tanıtım gösterilir" testi, TAM paket koşulurken (CPU daha yoğun)
       ara sıra "A Timer is still pending" ile düştü — sqflite'ın dahili
       yazma-kilidi timer'ına tanınan 50ms'lik gerçek-zaman payı bazen
       yetmiyordu. 200ms'ye çıkarıldı (bkz. o parçanın CLAUDE.md notu,
       güncellendi). **Ders:** bu sınıf bir flake'i YALNIZCA tam paket
       koşusu yakalar — tek dosya çalıştırmak yanlış bir güven verir.
     - Doğrulama: `account_settings_test.dart` (5 test — hidrasyon
       [profil+e-posta+pazarlama onay tarihi], doğrulama sırası [Ad→
       Soyad→Takma isim→doğum tarihi→"Supabase yapılandırılmadı." ile
       ağ çağrısına ulaşma kanıtı — `signup_test.dart` ile AYNI sınır],
       mevcut isimle aynı takma isimde kontrol atlanması, dolu takma
       isimde KAYDET'in işlemsiz kalması, AccountButton menü satırı +
       modal açılışı). **Tam takım 243/243 yeşil**, analyze + değişmez
       taraması temiz. **Doğrulama sınırı:** gerçek `updateProfile`/
       `updateEmail`/`refreshProfile` (RLS, unique index yarışı, GoTrue
       e-posta değişikliği onayı) bu ortamdan test EDİLEMEDİ — cihazda
       gerçek bir hesapla doğrulanmalı, TESTING.md'ye ayrı bölüm eklendi.
   - ✅ **Parça 14 — profil fotoğrafı yükleme (7 Ağustos 2026,
     `data/auth_service.dart`, `util/avatar_picker.dart`,
     `ui/auth/account_settings_modal.dart`):** Parça 13'te bilinçli eksik
     bırakılan tek madde kapandı — Hesap Ayarları artık web'in
     `uploadAvatar` akışını (dosya seç → doğrula → `avatars` kovasına
     yükle → `profiles.avatar_url` güncelle) uçtan uca taşıyor.
     - **`AuthService.uploadAvatar({bytes, mimeType})`** — web
       `uploadAvatar` (`src/lib/api.ts`) portu: MIME (`image/*`) ve boyut
       (≤2 MB) doğrulaması istemci tarafında TEKRARLANIYOR (UI zaten
       kontrol ediyor, bu ikinci bir savunma katmanı), `avatars` kovasına
       `<uid>/avatar.<ext>` yoluna `uploadBinary(upsert:true)` ile yazıp
       `getPublicUrl` + `?v=<epoch ms>` önbellek-kırma parametresiyle
       `profiles.avatar_url`'i `updateProfile`'a devrediyor. RLS
       (`profile_avatar` migration'ı — yalnızca kendi `auth.uid()` klasörüne
       yazabilirsin) web'le aynı, dokunulmadı; `security_hardening`
       migration'ının yalnızca fazla bir SELECT policy'sini kaldırdığı,
       INSERT/UPDATE/DELETE kısıtının değişmediği kaynak okunarak
       doğrulandı. **Supabase Storage'ın Dart SDK'sı JS'ten farklı:**
       `getPublicUrl` düz bir `String` döner (JS'in `{data:{publicUrl}}`
       sarmalayıcısı yok) — port bu farkı gözetti.
     - **`util/avatar_picker.dart` (yeni, enjekte edilebilir):**
       `PickedImage`/`PickAvatarFn` + üretim `pickAvatarImage()` —
       `image_picker`in `ImageSource.gallery`'si (web'in
       `<input type="file" accept="image/*">`'ıyla aynı kapsam: yalnızca
       galeri, KAMERA BİLİNÇLİ YOK — ek bir kamera izni gerektirmeyen en
       yakın eşdeğer). `XFile.mimeType` platforma göre boş kalabildiğinden
       dosya uzantısından bir yedek harita (`_mimeByExt`) var; ikisi de
       tanınmazsa `application/octet-stream` (sessizce yanlış bir MIME
       uydurmuyoruz — `uploadAvatar`'ın `image/*` kontrolü bunu zaten
       reddeder). `share_board.dart`'taki `ShareBoardFn`/`CaptureBoardFn`
       ile AYNI enjeksiyon deseni: platform kanalı widget testinde
       çalışmaz, `AccountSettingsModal` seçimi opsiyonel `pickAvatar`
       parametresi olarak alır.
     - **UI:** avatar satırındaki "kelimeki.com üzerinden düzenleyebilirsin"
       notu kalktı; `KAvatar` + "FOTOĞRAF DEĞİŞTİR" (NeoButton, neutral) +
       "JPG/PNG, en fazla 2 MB" alt yazısı geldi. Yükleme sırasında buton
       "YÜKLENİYOR…" gösterip devre dışı kalıyor; başarıda yerel bir
       `_avatarUrlOverride` (web'in aynı gecikme sorunu — `refreshProfile`
       ağ gecikmesi boyunca eski fotoğraf görünmesin diye) + "Profil
       fotoğrafı güncellendi." notu; galeri iptal edilirse (`null`)
       sessizce hiçbir şey olmaz (web'de dosya seçmeden kapatmakla aynı).
     - **iOS izni:** `Info.plist`'e `NSPhotoLibraryUsageDescription`
       eklendi (galeri erişimi için zorunlu) — attribute-seviyesinde
       doğrulama yapıldı (üretici dersinin refleksi), başka hiçbir key
       kaybolmadı/değişmedi.
     - **Test sınırı — `AuthService.fake`'in `_client==null` kontrolü
       yükleme başarısını simüle etmeyi ENGELLİYOR:** `uploadAvatar`
       önce `_client == null` kontrolü yapıp fırlıyor — MIME/boyut
       doğrulaması ondan SONRA geliyor. Yani fake client'la HERHANGİ bir
       seçilmiş görsel (geçerli ya da değil) doğrudan "Supabase
       yapılandırılmadı."ya düşer; bu iki test (`_save()` testlerindeki
       AYNI desen) yalnızca akışın GERÇEKTEN `AuthService.uploadAvatar`'a
       ulaştığını kanıtlıyor — MIME/boyut doğrulama mantığının kendisi
       bu ortamdan test EDİLEMEDİ.
     - Doğrulama: `account_settings_test.dart`'a 2 test eklendi (seçim→
       yükleme→ağ çağrısına ulaşma; galeri iptali→no-op). **Tam takım
       245/245 yeşil**, analyze + değişmez taraması temiz (yeni
       `toLowerCase()` çağrısı `avatar_picker.dart`'ta bir dosya
       UZANTISI üzerinde — Türkçe metin değil, `trLower` gerektirmiyor).
       **Doğrulama sınırı:** gerçek galeri seçici, gerçek Storage upload'ı
       (RLS'in başka bir kullanıcının klasörüne yazmayı gerçekten
       reddettiği), public URL'in önbellek kırma davranışı ve 2 MB/
       resim-dışı-dosya reddi cihazda doğrulanmalı — TESTING.md'ye ayrı
       madde eklendi.
   - **Auth + Canlı oyun fazının web UI paritesi Parça 10'da tamamlanmıştı;
     Parça 14 ile son bilinçli eksik de kapandı** (admin paneli hariç —
     bilinçli kapsam dışı, bkz. "Üst Düzey Kararlar" #3). Kalan tek fark
     Şifre Değiştir'in mobilde hiç olmaması — web'de de zaten 2 Ağustos
     2026'da kaldırılmıştı, bu bir parite eksiği DEĞİL.
   - ✅ **Parça 15 — cihaz testi sırasında bulunan iki hata (8 Ağustos 2026,
     `game_screen.dart`, `online_game_screen.dart`, `setup_screen.dart`):**
     Kullanıcı, web derlemesini iPad Safari'de manuel test ederken (FAZ A0
     sonrası) iki gerçek hata buldu — üçüncü bir şikayet (yatay modda
     tahtanın yarısının görünmesi) web-test-ortamının doğal bir sınırıydı
     (native `screenOrientation="portrait"` kilidi tarayıcıda geçerli değil,
     gerçek uygulamada hiç yaşanmaz) ve dördüncüsü (dikeyde rafın altındaki
     butonların görünmemesi) yalnızca kaydırma gerektiriyordu — ikisi de
     kod değişikliği gerektirmedi.
     - **Raf/tahta taşı sürüklerken sayfa da kayıyordu.** Kök sebep: hem
       `game_screen.dart` hem `online_game_screen.dart`'ta TÜM oyun ekranı
       (tahta+mesaj+raf+butonlar) tek bir `SingleChildScrollView` içinde;
       sürükleme sistemi ham `Listener` kullanıyor (web `setPointerCapture`
       eşdeğeri, bilinçli tercih — bkz. Parça 7) ve bu, Flutter'ın jest
       arenasına HİÇ katılmıyor. Sonuç: `Scrollable`'ın kendi dikey sürükleme
       algılayıcısı aynı parmak hareketini bağımsızca "sayfa kaydırma"
       sanıp kazanıyor, taş sürüklenirken sayfa da kayıyordu — `Listener`
       arenaya katılmadığından bunu ENGELLEYECEK hiçbir mekanizma yoktu.
       **Düzeltme:** `SingleChildScrollView`'ın `physics`i artık aktif bir
       sürükleme sırasında (`_dragRef?.enabled == true`) `NeverScrollable
       ScrollPhysics`'e çekiliyor, aksi halde `null` (ambient/varsayılan
       davranış korunuyor — `ClampingScrollPhysics` gibi sabit bir değer
       YAZILMADI, iOS'taki bouncy varsayılanı bozmasın diye).
       `NeverScrollableScrollPhysics.shouldAcceptUserOffset` `false`
       döndüğünden `Scrollable` arenayı "kazansa" bile ekrana uygulanan
       kaydırma deltası sıfır kalıyor — pratikte sayfa hiç kaymıyor.
       `_dragRef` daha önce render tetiklemeden (setState'siz) okunup
       güncelleniyordu (bilinçli — web `dragRef`in salt veri taşıması); artık
       `physics` buna bağlı olduğundan `_beginTileDrag`/`_endTileDrag`/
       `_cancelTileDrag`'in HER ÜÇÜ de setState içine alındı — iki dosyada
       da BİREBİR aynı değişiklik (Parça 10'daki "bilinçli kod tekrarı"
       kararının bir sonucu: biri değişirse öteki de değişmek zorunda).
       **Test dersi:** `find.byType(SingleChildScrollView)` bu ekranlarda
       İKİ eşleşme veriyor — `GameHeader`'ın kendi (yatay) skor kutusu
       şeridi de aynı widget'ı kullanıyor (bkz. Parça 4). Testler
       `find.byWidgetPredicate((w) => w is SingleChildScrollView &&
       w.scrollDirection == Axis.vertical)` ile ana gövdeyi ayırt ediyor —
       yeni bir yerde aynı finder'ı kopyalarken bu ayrımı unutma.
     - **Setup'taki "Neden Ücretsiz Üye Olmalıyım?" kutusu üstündeki butona
       yapışık duruyordu.** Web kaynağı karşılaştırıldığında: kutu ile
       üstündeki eleman arasında web'de HER ZAMAN dıştaki flex kapsayıcının
       (`gap-5`=20px ya da iç kapsayıcının `gap-2`=8px, bağlama göre) verdiği
       taban boşluk var — `topMargin` prop'u (web `className="mt-2"`) bunun
       ÜSTÜNE binen EK boşluk, taban boşluğun YERİNE geçen tek boşluk değil.
       Flutter portu `_buildNewGameForm`'da (boş kurulum formunun altı) bu
       tabanı hiç taşımamıştı — diğer TÜM bölüm geçişlerinde (Oyuncu
       Sayısı→Oyuncular, Oyuncular→buton satırı) doğru `SizedBox(height:20)`
       vardı, yalnızca SONUNCUSU (buton satırı→kutu) unutulmuştu.
       `_buildSavedGameView`'da (misafirin "Devam Eden Oyun" görünümü) ise
       yalnızca `topMargin`in kendi 8px'i uygulanıyordu, web'in iç `gap-2`
       (8px) tabanı hiç yoktu — toplam 16px yerine 8px. **Düzeltme:** iki
       çağrı yerine de eksik `SizedBox` eklendi (`_buildNewGameForm`'a 20px,
       `_buildSavedGameView`'a 8px) — `MembershipPerksBox` widget'ının
       kendisine (renk/gölge/kenarlık/iç boşluklar) dokunulmadı, zaten
       ölçülerek web'le eşleşiyordu; sorun yalnızca ÇAĞIRANLARDAKİ eksik
       boşluktu. **Test:** mevcut "misafirde kutu" testine, OYUNU BAŞLAT
       butonunun alt kenarı ile kutu başlığının üst kenarı arasındaki
       farkın 15px'i aştığını doğrulayan bir ölçüm eklendi (önceden ~0px).
     - Doğrulama: `game_screen_test.dart`'ın mevcut sürükle-bırak testine
       sürükleme öncesi/sırası/sonrası `physics` kontrolü eklendi;
       `online_game_screen_test.dart`'a aynı deseni doğrulayan YENİ bir test
       eklendi (o dosyada daha önce gerçek pointer-gesture simülasyonu
       yoktu, yalnızca `dispatch` ile doğrudan action gönderiliyordu).
       **Tam takım 246/246 yeşil**, analyze + değişmez taraması temiz.
       Cihazda doğrulama kullanıcının kendi web derlemesi testinden geldi —
       bu parçanın "doğrulama sınırı"nı KAPATAN nadir bir örnek (genelde
       tersi oluyor).
   - ✅ **Parça 16 — Board/Rack gölgeleri sonraki panel tarafından ezilmiyordu
     (8 Ağustos 2026, `game_screen.dart`, `online_game_screen.dart`):**
     Kullanıcı, Parça 15'in hemen ardından tahtanın/raf kartının web'e göre
     "eksik/yanlış — daha hacimli ve gölgeli olmalı" göründüğünü bildirdi.
     **Yanlış ilk hipotez, ölçülerek elenmiş:** İlk şüphe `SingleChildScrollView`'ın
     varsayılan `Clip.hardEdge`'inin gölgenin taşmasını kırptığıydı (Board'un
     en büyük gölgesi blur:60 — geniş bir sönümleme payı istiyor, `board_render_test.dart`
     zaten bunun için 90px pay kullanıyordu). Bu ortamdan kelimeki.com'a VE
     `alpcapa.github.io`'ya ağ erişimi proxy tarafından engellendiğinden
     (`curl .../__agentproxy/status` ile doğrulandı — ikisi de 403), canlı
     karşılaştırma yapılamadı; bunun yerine `SingleChildScrollView`'a geçici
     olarak `clipBehavior: Clip.none` verilip `flutter test`'in ürettiği
     GERÇEK `game_screen_kelime.png`'yi yeniden üretip incelemek gibi
     YERİNDE bir doğrulama yöntemi kullanıldı — **sıfır fark**, hipotez
     çürüdü, değişiklik geri alındı.
     - **Gerçek kök sebep — paint SIRASI, klipleme değil:** `BoardWidget`'ı
       (aynı fixture, aynı 396px genişlik) TEK BAŞINA, `board_render_test.dart`'ın
       90px'lik boş-alan tekniğiyle yeniden render edilince gölge MÜKEMMEL
       göründü — yani gölgenin KENDİSİ ve BOYUTU asla sorun değildi. Fark
       şuydu: gerçek `GameScreen`'de Board'un HEMEN altında (aradaki mesaj
       satırı şeffaf, sorun değil) Raf kartının KENDİ OPAK zemini var — ve
       `Column` içinde SONRA çizilen bir kardeş, ÖNCE çizilenin üzerine
       boyar (Flutter'ın ve CSS'in normal akışta paylaştığı aynı kural).
       Board'un aşağı doğru sönümlenmeye vakit bulamayan gölgesi, birkaç
       piksel sonra başlayan Raf kartının zemini tarafından ezilip
       görünmez oluyordu — aynı sorun Raf kartının kendi (daha küçük,
       blur:14) gölgesi için de geçerliydi, hemen altındaki buton satırına
       karşı.
     - **Düzeltme — iki geçiş noktasına ölçülerek/gözlenerek ayarlanmış
       boşluk:** Board'un Padding'inden sonra `const SizedBox(height: 56)`
       (mesaj satırından ÖNCE) ve Raf/OYNA satırından sonraki buton
       satırının üst boşluğu 8→24px — **iki değer de 4-8-24-56 gibi
       yuvarlak sayılarla başlayıp `flutter test` ile ekran görüntüsü
       yeniden üretilip gözle incelenerek** (28→56'ya çıkarıldı, ilk
       deneme yetersizdi) bulundu; gölge değerlerinin KENDİSİNE
       dokunulmadı. Aynı iki değişiklik `online_game_screen.dart`'a da
       BİREBİR uygulandı (bilinçli kod tekrarı — bkz. Parça 10/15).
       **Bilinçli kapsam sınırı:** yalnızca DİKEY (aşağı doğru) sönümleme
       payı eklendi — yatay (sol/sağ) kenarlardaki küçük gölgeler
       (blur 14-20) hâlâ 12px'lik dar bir yatay Padding içinde, ama
       bunlar Board'un DOMİNANT gölgesi olmadığından ("voluminous" hissi
       asıl bu büyük alt gölgeden geliyor) ayrı bir düzeltme gerekmedi.
     - Doğrulama: `flutter analyze` temiz, **tam takım 246/246 yeşil**
       (spacing değişikliği hiçbir testi bozmadı — sürükleme testleri
       `tester.getCenter()` ile DİNAMİK konum okuduğundan otomatik
       adapte oldu). Görsel doğrulama dört ekran görüntüsüyle (KELİME,
       swap modu, sürükleme, Canlı oyun) yapıldı — hepsinde Board VE Rack
       kartlarının altında artık net, "hacimli" bir gölge var. **Ders —
       ikinci kez pekişti (bkz. Parça 15'in `SingleChildScrollView` dersi):
       bir görsel eksiklik bulunca ÖNCE en olası/kolay açıklamayı (klipleme)
       kodu OKUYARAK değil YERİNDE TEST EDEREK doğrula/çürüt** — bu
       ortamdan canlı siteye erişim olmasa bile `flutter test`'in ürettiği
       gerçek PNG'leri okuyup karşılaştırmak, salt kod okumaktan çok daha
       güvenilir bir teşhis yöntemi oldu.
   - ✅ **Parça 17 — Parça 16'nın "bilinçli kapsam sınırı" YETERSİZDİ: oyun
     ekranına web'in `max-w-[680px]` kart sınırı hiç uygulanmamıştı (8
     Ağustos 2026, `game_screen.dart`, `online_game_screen.dart`):**
     Kullanıcı, Parça 16'dan sonra deploy edilen GitHub Pages derlemesini
     iPad'de YATAY modda test edip tahtanın hâlâ "eksik/yanlış" göründüğünü,
     gerçek web'e (kelimeki.com, "Ironman" hesabıyla) benzemediğini
     bildirdi — ekran görüntüsünde tahta ekranın SOL kenarından SAĞ
     kenarına kadar (13 sütun ~103px'lik hücrelerle) gerilmiş, hiçbir
     gölge görünmüyordu.
     - **Kök sebep — Parça 16'nın "yatay gölgeler dominant değil" varsayımı
       yanlış çıktı:** `game_screen.dart`/`online_game_screen.dart`'ta
       Board'un (ve altındaki mesaj/raf/buton bloğunun) etrafında yalnızca
       `EdgeInsets.symmetric(horizontal: 12)` vardı — web'in AKSİNE
       (`GameHeader.tsx`, `Board.tsx`, `App.tsx`'in raf/buton container'ı
       — ÜÇÜ DE ayrı ayrı `w-full max-w-[680px]` taşıyor, bkz. kök
       CLAUDE.md'nin ilgili notları) mobil tarafta hiçbir üst sınır YOKTU.
       Dar bir telefon ekranında bu fark görünmüyordu (12px zaten dar
       ekranda yeterliydi), ama GENİŞ/YATAY bir ekranda (iPad yatay,
       ~1389px) Board kendi genişliğini doldurdukça 13×13 hücre devasa
       büyüyor, kart kenardan kenara gerilip gölgenin sönümleneceği HİÇBİR
       boşluk kalmıyordu — Parça 16'nın çözdüğü DİKEY ezilme meselesinden
       tamamen ayrı, yeni bir kök sebep. `setup_screen.dart`'ta bu sınır
       zaten vardı (`ConstrainedBox(maxWidth: 480)`, web'in `max-w-[460px]`
       eşleniği) — yalnızca OYUN ekranları bu deseni hiç almamıştı.
     - **Düzeltme:** Her iki ekranda da GameHeader+Board+mesaj+raf+buton
       bloğunun TAMAMI `Center(child: ConstrainedBox(constraints:
       BoxConstraints(maxWidth: 680), ...))` ile sarmalandı — web'in üç
       ayrı `max-w-[680px]` container'ının net görsel etkisiyle özdeş (hiç
       biri arka plan rengi taşımadığından tek bir ortak sarmalayıcıya
       indirgemek görsel fark yaratmıyor). Dar ekranlarda (680px altı)
       davranış DEĞİŞMEDİ — kısıt yalnızca genişlik 680'i AŞTIĞINDA devreye
       giriyor.
     - Doğrulama: `flutter analyze` temiz, **tam takım 246/246 yeşil**
       (mevcut testlerin hepsi 680px altı yüzey boyutlarında koştuğundan
       kısıt hiçbirini etkilemedi). Geçici bir betikle `GameScreen`
       1389×866 (kullanıcının bildirdiği iPad yatay ölçüsü) yüzeyinde
       render edilip PNG'ye yakalandı — düzeltmeden önce tahta kenardan
       kenara geriliyordu, düzeltmeden sonra 680px'lik ortalanmış bir
       "kart" olarak göründü ve kartın etrafında gölgenin sönümlenebileceği
       bariz beyaz boşluk oluştu (betik incelemeden sonra silindi, kalıcı
       test paketine eklenmedi — tek seferlik görsel doğrulama amaçlıydı).
       **Ders:** "küçük/dominant olmayan gölgeler" gerekçesiyle bir kapsam
       sınırı çizerken, o gerekçenin yalnızca test edilen ekran boyutunda
       (dar telefon) geçerli olabileceğini, GENİŞ ekranlarda aynı ihmalin
       katbekat büyüyebileceğini göz önünde bulundur — Parça 16'nın
       taraması yalnızca 396-760px yüzeylerde yapılmıştı, gerçek kullanıcı
       şikayeti çok daha geniş bir yüzeyden geldi.
   - ✅ **Parça 18 — `Path.combine` CanvasKit'te deliği KAYBEDİYOR: hücre-içi
     gölgeler tarayıcıda tamamen düz çıkıyordu (8 Ağustos 2026,
     `neo_box.dart`):** Parça 17'den sonra kullanıcı tahtanın genelinin
     düzeldiğini ama hücrelerin TEK TEK "gölgesiz/düz" kaldığını bildirdi.
     **Bu hata iki yanlış teşhisten sonra ancak ÖLÇÜLEREK bulundu — önemli
     olan da bu.**
     - **İlk (BAŞARISIZ) deneme — CSS parite ilkesi ihlal edildi:** Kod
       değerleri (`InsetShadow` renk/alfa/offset/blur) `Board.tsx`'in CSS
       `box-shadow` tanımlarıyla birebir aynı olduğu doğrulanmış, buradan
       "değerler doğru ama CanvasKit soluk basıyor" diye TAHMİN yürütülüp
       alfa/blur değerleri elle ~%50-80 artırılmıştı. Sonuç cihazda DAHA DA
       kötü oldu (kullanıcı: "şimdi daha silik"). Kullanıcı haklı olarak
       geri aldırdı: *"Tamamen tahminle iş yapıyorsun. Geri al ve CSS
       kurallarını bozma bir daha."* Commit geri alındı (`66055a6`), CSS
       değerlerine bir daha dokunulmadı.
     - **Doğru yöntem — üç motoru AYNI ölçüde yan yana koyup piksel ölçmek:**
       (1) `Board.tsx`'in hücre CSS'i birebir kopyalanarak bağımsız bir HTML
       yazıldı ve YEREL Chromium'da (Playwright, `/opt/pw-browsers`) DPR 2
       ile render edildi — hücre 38.375 CSS px, Flutter'ın kendi hesabıyla
       ((555−20−36)/13) birebir aynı. (2) `BoardWidget` `flutter test` ile
       TAM AYNI ölçüde (555 mantıksal px, pixelRatio 2) PNG'ye çekildi.
       (3) `flutter build web` ile SADECE `BoardWidget`'ı render eden minik
       bir harness derlenip yerel HTTP sunucusundan Chromium'da açıldı —
       **gerçek CanvasKit**. Üçünde de aynı hücrenin (0,5) aynı yatay
       tarama çizgisi okundu:
       | | t=0.03 | t=0.5 | t=0.97 |
       |---|---|---|---|
       | Web CSS (Chromium) | 197 | 221 | 235 |
       | Skia (`flutter test`) | 199 | 221 | 237 |
       | **CanvasKit (tarayıcı)** | **241** | **241** | **241** |
       Skia ile CSS 1-4 birim farkla ÖRTÜŞÜYOR — yani kod baştan doğruydu ve
       ilk denemedeki "değerleri artır" hamlesi tam da bu yüzden yanlıştı.
       CanvasKit ise gradyan ÜRETMİYOR, hücreyi tek bir düz renkle dolduruyor.
     - **Kök sebep, 241 sayısından okundu:** zemin #DDE4EE (221) üzerine önce
       koyu gölge (`0x99A3B1C6`, α .6) TÜM hücreye → 186, sonra beyaz gölge
       (`0xCCFFFFFF`, α .8) TÜM hücreye → **241.2**. Yani her iki gölge yolu
       da hücrenin TAMAMINI dolduruyor: ortadaki delik hiç uygulanmıyor.
       Delik `Path.combine(PathOperation.difference, outer, inner)` ile
       üretiliyordu — bu Skia'nın **PathOps** katmanına iner ve CanvasKit'te
       `MaskFilter.blur` ile birlikte deliği kaybediyor.
     - **Düzeltme (tek satırlık kavram, sihirli sayı YOK):** aynı delik artık
       PathOps'a hiç girmeyen saf bir dolgu kuralıyla ifade ediliyor —
       `Path()..fillType = PathFillType.evenOdd ..addRect(dış) ..addRRect(iç)`.
       Renk/alfa/offset/blur değerlerinin HİÇBİRİNE dokunulmadı, CSS paritesi
       korundu. Doğrulama aynı ölçüm döngüsüyle tekrarlandı: CanvasKit artık
       **200 → 221 → 237**, yani CSS (197 → 221 → 237) ile örtüşüyor; native
       Skia çıktısı ise düzeltme öncesiyle **bit düzeyinde aynı** (regresyon
       yok). Görsel olarak altın X2 bölgesi ve köşe bölgeleri de düzeldi —
       beyaz gölge onları da basıyormuş.
     - **Kapsam:** `Path.combine` tüm kod tabanındaki TEK kullanımdı (tarandı);
       `NeoBox`/`InsetShadow` yalnızca `board_widget.dart` tarafından
       tüketildiğinden dört hücre tipi (nötr, bölge, altın X2, merkez X3) tek
       düzeltmeyle kapsandı. `_CssShadowBoxPainter`'ın (kart/taş DIŞ gölgeleri)
       `MaskFilter`'ı düz bir `drawRRect` üzerinde — PathOps yok, CanvasKit'te
       zaten doğru çalışıyordu (ölçümde de doğrulandı).
     - **Doğrulama sınırı:** yerel Chromium'da GPU olmadığından SwiftShader
       (yazılım GL) kullanıldı; çıktıda birkaç soluk yatay bant var ama bunlar
       düzeltmeden ÖNCE de vardı, değişmediler ve kullanıcının gerçek cihaz
       ekran görüntülerinde hiç görünmüyorlar — ortam artefaktı sayıldı.
       iOS Safari'nin kendi CanvasKit'i cihazda ayrıca teyit edilmeli.
     - **Ders 1 — `flutter test` bu hata SINIFINI yapısal olarak göremez:**
       widget testleri native Skia ile render eder, hata yalnızca CanvasKit'te
       vardı. "246/246 yeşil" bu konuda hiçbir şey kanıtlamıyordu. Tarayıcıya
       özgü render şüphesi doğduğunda tek geçerli kanıt **web derlemesini
       gerçekten tarayıcıda açıp ölçmek** — ve bu, bu ortamda YAPILABİLİR:
       `flutter build web --target=<minik harness>` + `python3 -m http.server`
       + Playwright/Chromium. Tüm uygulamayı boot etmeye çalışma (sözlük/
       Supabase açılışta asılı kalıyor), yalnızca şüphelenilen widget'ı
       render eden bir harness derle.
     - **Ders 2 — "değerler aynı, o hâlde sorun yok" bir teşhis DEĞİL:**
       değer eşitliği yalnızca girdinin aynı olduğunu söyler; ÇIKTININ aynı
       olduğunu söylemez. Aradaki fark bir motor hatasıysa, değerleri
       kurcalamak (ilk denemedeki gibi) semptomu kovalamaktır ve genellikle
       daha da bozar. Önce çıktıyı ölç, sonra sebebi ara.
   - ✅ **Parça 19 — Setup ortalaması + DIŞ gölge saydam dolgunun altından
     sızıyordu (8 Ağustos 2026, `setup_screen.dart`, `neo_box.dart`):** İki
     ayrı kullanıcı bildirimi, ikisi de web paritesi eksiği.
     - **(a) Tanıtım paragrafı ve link satırı sola yaslıydı.** Web'de blok
       `text-center flex flex-col items-center` içinde — hem paragraf hem
       altındaki "Nasıl oynanır? · Arkadaşınla paylaş" satırı ORTALI.
       Flutter'da paragrafta `textAlign` hiç yoktu, link satırı da
       `Alignment.centerLeft` idi (~72px sapma). İkisi de düzeltildi.
       Hizalamayı koruyan bir test eklendi (link satırının yatay merkezi,
       içerik genişliğini kaplayan paragrafın merkeziyle eşleşmeli) ve
       **test düzeltme geri alınarak DOĞRULANDI** — eski hâlde 210 yerine
       138 ölçüp başarısız oluyor (kök CLAUDE.md'nin "negatif eşi" dersi:
       aradığın davranışın YOKLUĞUNDA da geçen bir kontrol boştur).
     - **(b) "Neden Ücretsiz Üye Olmalıyım?" kutusu grimsi/lavanta
       görünüyordu, web'de açık mavi-beyaz.** Kök sebep `neo_box.dart`'ta:
       `_CssShadowBoxPainter` dış gölgeleri tam bir rrect olarak çizip
       ÜSTÜNE dolguyu basıyordu. CSS'te dış gölge border-box'ın İÇİNE hiç
       boyanmaz; opak dolguda fark görünmez (dolgu altındakini örter) ama
       bu kutu projedeki **TEK saydam dolgulu** kullanım yeri
       (`Color(0x0D2563EB)` = web `bg-accent/5`) olduğundan gri gölge
       içeriden sızıyordu. Ölçümle doğrulandı: web CSS'i Chromium'da
       **(244,247,254)**, mobil **(200,210,226)** — ikisi de önceden
       hesapladığım değerlerle birebir çıktı (beyaz + %5 mavi vs beyaz +
       gri gölge + %5 mavi). Düzeltme: gölgeler artık şeklin kendi alanı
       DIŞLANARAK çiziliyor. `clipRRect` bir `ClipOp` almadığından kırpma
       evenOdd bir `clipPath` ile ifade edildi — Parça 18'deki aynı teknik,
       PathOps'a girmediğinden CanvasKit'te de güvenli. Düzeltme sonrası
       mobil **(244,247,254)** — web ile birebir. Opak kullanıcılar (tahta
       kartı, taşlar, raf, NeoButton, AccountButton) taranıp hepsinin opak
       olduğu doğrulandı, onlarda görünür değişiklik yok.
     - Doğrulama: `flutter analyze` temiz, **tam takım 247/247 yeşil**.
     - **Ders — bir "deploy oldu mu?" kontrolü teşhisin parçasıdır:** (a)
       düzeltildikten sonra kullanıcı hâlâ eski hâli bildirdi; GitHub
       Actions'a bakınca web işinin 11:42:48'de bittiği, ekran görüntüsünün
       11:44'te alındığı görüldü — yani ~1 dakikalık tarayıcı önbelleği.
       Kod yeniden kurcalanmadan önce **deploy zaman damgası ile ekran
       görüntüsü saati karşılaştırılmalı** (bu oturumda bir kez de
       gereksiz araştırmaya yol açtı). Ayrıca: hızlı art arda push'lar
       çalışan run'ı iptal ediyor, ama Pages deploy işi zincirin başında
       olduğundan (dakika 1-2) pratikte tamamlanıyor — iptal edilen run
       mutlaka "deploy olmadı" demek DEĞİL, job bazında bakılmalı.
   - ✅ **Parça 20 — joker seçici dar/yatay yükseklikte "RenderFlex
     overflowed" ile taşıyordu (8 Ağustos 2026, `wild_letter_sheet.dart`):**
     FAZ A1 (Bölüm 1: Oyun) cihaz testinde kullanıcı, iPad Safari'de bir
     jokeri tahtaya koyunca açılan "Joker Hangi Harf Olsun?" alt sayfasının
     ekranın altından taştığını, alt satırların (U/Ü/V/Y/Z) kesildiğini
     ekran görüntüsüyle bildirdi.
     - **Kök sebep, Flutter SDK kaynağından doğrulandı (tahmin değil):**
       `showModalBottomSheet`'in `isScrollControlled` parametresi
       verilmezse (varsayılan `false`) sheet'in maksimum yüksekliği
       `constraints.maxHeight * (9/16)` — ekranın yalnızca **%56**'sı
       olarak sabitleniyor (`bottom_sheet.dart`,
       `_defaultScrollControlDisabledMaxHeightRatio`). `wild_letter_sheet.dart`
       bu parametreyi hiç geçmiyordu ve içeriği (26 harflik 6 sütunlu
       ızgara + başlık) SARAN bir kaydırma alanı da yoktu (`Padding` →
       `Column(mainAxisSize.min)` → `GridView.count(shrinkWrap,
       NeverScrollableScrollPhysics)`) — kısıtlı yükseklik içeriğe
       yetmeyince `Column` klasik "RenderFlex overflowed" hatasıyla taştı.
       Web'in ortak `Modal.tsx`'i (`WildcardModal.tsx`'in kullandığı)
       `max-h-[85vh] overflow-y-auto` taşıdığından bu sınıf bir taşma web'de
       hiç yaşanmıyor — port sırasında `KModal`'a değil ham
       `showModalBottomSheet`'e gidildiğinden bu koruma hiç taşınmamıştı.
       Kullanıcının ekran görüntüsü muhtemelen iPad YATAY moddaydı (tahta
       ekranın yalnızca sol-üst çeyreğinde görünüyordu) — yatayda
       kullanılabilir yükseklik dikeye göre çok daha dar olduğundan %56
       sınırı orada daha kolay aşılıyor, ama sınır MUTLAK (ekran boyutundan
       bağımsız): yeterince kısa herhangi bir yükseklikte tekrarlanır.
     - **Düzeltme:** `showModalBottomSheet`'e `isScrollControlled: true`
       eklendi (sheet artık tam yüksekliğe kadar büyüyebiliyor) ve içerik
       `Padding` yerine `SingleChildScrollView` içine alındı (web'in
       `overflow-y-auto`'suyla aynı güvenlik ağı — çok küçük ekranlarda
       hâlâ sığmazsa taşmak yerine kaydırılır). `GERİ AL` butonu dahil
       tüm içerik aynı kaydırma alanının içinde.
     - **Test — negatif eş doğrulamasıyla:** `game_screen_test.dart`'a
       `showWildLetterSheet`'i oyun ekranından İZOLE (kendi `MaterialApp`/
       `Scaffold` pump'ı) açan yeni bir test eklendi — `Size(800, 420)`
       gibi kısa bir yüzeyde `tester.takeException()`'ın `null` olduğunu
       doğruluyor. Düzeltme geçici geri alınıp test GERÇEKTEN
       `FlutterError:<A RenderFlex overflowed by 368 pixels on the
       bottom.>` ile düştüğü görüldü, sonra düzeltme geri konup 10/10 yeşil
       olduğu doğrulandı (kök CLAUDE.md'nin "negatif eş" dersi — aradığın
       davranışın YOKLUĞUNDA da geçen bir kontrol boştur).
       **İki test-dersi notu:** (1) İlk deneme oyun ekranı üzerinden
       (`rackTile`/`boardCell` dokunarak) açmayı denedi — Parça 15-17'nin
       kendi `SingleChildScrollView`/`max-w-680px` düzeni yüzünden kısa
       yükseklikte raf ekran dışına düşüyor, test YANLIŞ sebepten
       (rack bulunamadı) düşüyordu; izole pump bu karışmayı ortadan
       kaldırdı. (2) `find.text('Z')` iki eşleşme veriyor (kontur+dolgu
       katmanı, bkz. joker akışı testindeki aynı desen) — `.first` gerekli.
     - Doğrulama: `flutter analyze` temiz, **tam takım 248/248 yeşil**
       (yalnızca `wild_letter_sheet.dart` + `game_screen_test.dart`
       değişti — `action_sheet.dart`'taki tek diğer `showModalBottomSheet`
       kullanımına bilerek dokunulmadı, o içerik kısa/sabit bir liste,
       aynı sınıf bir taşma riski taşımıyor).
     - ⚠️ **BU DÜZELTME YALNIZCA SEMPTOMU KAPATTI — Parça 47 (10 Ağustos
       2026) yapının kendisini değiştirdi:** web `WildcardModal.tsx`
       alttan açılan bir sayfa DEĞİL, ortalanmış `Modal` kullanıyor.
       Buradaki `isScrollControlled` yaması taşmayı durdurdu ama sheet
       ekran genişliğini kapladığından taşlar iPad'de devleşmeye devam
       etti; kullanıcı iki gün sonra "düzelmedi" diye bildirdi. Aşağıdaki
       Parça 47'ye bak.
   - ✅ **Parça 21 — YZ düşünme gecikmesi (1100 ms) hiç port edilmemişti
     (8 Ağustos 2026, `game_controller.dart`):** FAZ A1 (Bölüm 1: Oyun)
     cihaz testinde kullanıcı, iPad Safari'de web derlemesini test ederken
     kendi hamlesini OYNA ile onayladıktan sonra kendi hamlesinin mesaj
     satırını ("Misafir: +N puan Kelimeler: …") HİÇ göremediğini bildirdi —
     YZ anında oynayıp kendi mesajını üstüne yazıyordu.
     - **Kök sebep:** Web'de YZ hamlesi bilerek GECİKMELİ — `src/App.tsx`
       `const AI_THINK_MS = 1100;` + bir effect'te
       `setTimeout(() => dispatch({type:'AI_PLAY'}), AI_THINK_MS)`
       (cleanup'ta `clearTimeout`). Dart portundaki `_maybeScheduleAiTurn()`
       bu gecikmeyi hiç taşımamış — `Future<void>(() { ... dispatch(...) })`
       ile yalnızca bir sonraki event-loop turunu (≈0 ms) bekliyordu; YZ
       pratikte anında oynuyordu.
     - **Düzeltme:** `GameController`'a web'in `AI_THINK_MS`'iyle eşleşen,
       enjekte edilebilir bir `final Duration aiThinkDelay` alanı eklendi
       (varsayılan `Duration(milliseconds: 1100)`, kurucudan override
       edilebilir) — bu projenin "saat/rastgelelik enjekte edilir"
       sözleşmesinin (`rng`/`nowIso` ile aynı desen) devamı: testler gerçek
       zaman kaybetmeden hassas bir gecikme geçebiliyor. `_maybeScheduleAiTurn()`
       artık `Future<void>(...)` yerine bir `Timer` kullanıp referansı
       `Timer? _aiTimer` alanında tutuyor; timer ateşlendiğinde web effect
       cleanup'ının eşleniği olan aynı yeniden-kontrol (phase==play &&
       !isGameOver && players[current].isAI) korunuyor — gecikme boyunca
       state değiştiyse (restore/dispose/insan araya girdi) eski karar
       uygulanmıyor. Eski `_aiScheduled` bayrağının "üst üste tetiklenmeyi
       önleme" işlevi artık `_aiTimer?.isActive` ile okunuyor, ayrı bir
       bayrağa gerek kalmadı.
     - **`dispose()`'ta `_aiTimer?.cancel()` — bilinçli, yapısal önlem:**
       gecikme gerçek bir `Timer`'a dönüştüğü an, widget testlerinde ekran
       sökülürken bekleyen bir timer kalırsa bu proje "A Timer is still
       pending even after the widget tree was disposed" flake'ini yer
       (Parça 11/13'ün sqflite dersiyle AYNI hata sınıfı — bkz. yukarı).
       `dispose()`'un artık `_disposed=true` yapmasının yanında timer'ı da
       İPTAL etmesi bunu yapısal olarak önlüyor; `autoPlayAi:false` olan
       her yer (Canlı oyun `online_game_screen.dart`, testlerin çoğu) ve
       `actingSeat`/`_reduce`/no-op `identical` kısa devresi hiç
       etkilenmedi — yalnızca zamanlama katmanı değişti, `kelimeki_core`
       motoruna dokunulmadı (golden vector yeniden üretimi gerekmedi).
     - **Test — iki yeni `testWidgets`, `tester.pump(Duration)` ile FakeAsync
       saatini GERÇEK bekleme olmadan hassas ilerleterek:** (1) "gecikme
       dolmadan AI_PLAY dispatch edilmez, dolunca edilir" —
       `aiThinkDelay: 300ms` ile `pump(299ms)`'te `turnCount==0`,
       `pump(2ms)` daha sonra (`301ms` toplam) `turnCount>0` doğrulanıyor.
       (2) "dispose() bekleyen YZ timer'ını iptal eder" — `aiThinkDelay:
       500ms`, timer ateşlenmeden `dispose()` çağrılıyor; test sonunda
       `flutter_test`'in kendi pending-timer kontrolü (testWidgets'ın
       fake-async zon'unda YARATILAN her timer'ın test bitene kadar ateşlenmiş
       ya da iptal edilmiş olmasını zorunlu kılıyor) sessizce geçiyor.
       Düz `test()` + `Future.delayed` yerine bilerek `testWidgets` +
       `tester.pump` seçildi — hem deterministik hem de (2)'deki pending-timer
       kontrolünü GERÇEKTEN tetikleyebilen tek yol bu (plain `test()`'te
       böyle bir kontrol hiç yok).
     - **Negatif eş doğrulaması (ikisi de, kök CLAUDE.md dersi):** (1)
       ilk testte `aiThinkDelay: 300ms` geçici olarak `Duration.zero`'ya
       çekilip koşuldu — `pump(299ms)`'teki "gecikme dolmadan oynamamalı"
       assertion'ı `Expected: <0> Actual: <33>` ile GERÇEKTEN düştü (YZ
       gecikmesiz onlarca tur ilerlemişti), sonra 300ms'ye geri konup yeşile
       döndü. (2) `dispose()`'daki `_aiTimer?.cancel();` satırı geçici
       olarak yorum satırına alınıp yalnızca ikinci test koşuldu — GERÇEKTEN
       `A Timer is still pending even after the widget tree was disposed.`
       (`Failed assertion: line 1617 pos 12: '!timersPending'`) ile düştü,
       stack trace tam olarak `GameController._maybeScheduleAiTurn`'e işaret
       etti; satır geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, değişmez taraması temiz
       (`kelimeki_core`'a hiç dokunulmadı). **Tam takım iki ayrı temiz
       koşuda 250/250 yeşil** (248 + bu parçanın 2 yeni testi) — tam paket
       koşusunda iki AYRI, bu parçayla İLGİSİZ flake de gözlendi (biri
       `setup_cloud_test.dart`'ta sqflite'ın dahili 10 saniyelik yazma-kilidi
       timer'ının CPU yükü altında test bitmeden ateşlenmemesi — Parça 13'ün
       "bu sınıf bir flake'i YALNIZCA tam paket koşusu yakalar" dersiyle
       birebir aynı; ötekinin — "joker seçici… RenderFlex" — kök sebebi
       Parça 20'nin DÜZELTMESİ henüz rebase edilmeden önceki eski HEAD'e
       dayanıyordu, rebase sonrası hiç tekrarlamadı); ikisinin de stack
       trace'i `game_controller.dart`'a hiç değmiyor.
     - **Bilinçli sınır:** `autoPlayAi:true` olan gerçek bir Canlı/PWA
       akışında (yalnızca yerel/YZ oyunda kullanılıyor) 1.1sn'lik gecikmenin
       cihazda GÖRÜNÜR şekilde web paritesini sağladığı — kendi hamle
       mesajının artık en az ~1sn okunabilir kaldığı — bu ortamdan cihazda
       doğrulanamadı; `mobile/TESTING.md` Bölüm 1'e ayrı bir kontrol maddesi
       eklendi (aşağı bkz.).
   - ✅ **Parça 22 — avatar yedeği (misafir "?") gri, YZ robotu Material
     ikonuydu; web'de ikisi de farklı (8 Ağustos 2026, `k_avatar.dart`,
     `player_avatar_row.dart`):** FAZ A1 (Bölüm 2 öncesi, kalıcılık
     testinde) kullanıcı kelimeki.com'un ("web") ve
     `alpcapa.github.io`'nun ("app") aynı "Devam Eden Oyun" satırının
     ekran görüntülerini yan yana koyup avatarların FARKLI göründüğünü
     bildirdi.
     - **Kök sebep, iki ayrı bulgu — ikisi de kaynak koddan doğrulandı,
       CLAUDE.md'de belgeli bir bilinçli sapma DEĞİLDİ:**
       1. **"?" yedeği rengi.** Web `Avatar.tsx`'in fotoğrafsız/hatalı
          yükleme yedeği (`<span>`) HER ZAMAN `bg-accent` (tailwind
          `accent:'#2563EB'`) + `border-accent` + `text-white` — misafirin
          "?" hâli de dahil, web hiç bir "gri/nötr" yedek göstermiyor.
          `KAvatar`'ın yedeği ise `_panel`(#F5F7FA)/`_border`(#DCE2EA)
          zemin + `_muted`(#5A6673) gri yazı kullanıyordu — Parça 1'de
          ("KAvatar web Avatar portu: initials() kuralı + tek karakter
          0.55 oranı dersi") yalnızca punto/oran taşınmış, RENK hiç
          karşılaştırılmamıştı.
       2. **YZ robot avatarı.** Web `PlayerAvatarRow.tsx` gerçek 🤖
          (U+1F916) Unicode emoji'sini basıyor; Flutter portu
          `Icons.smart_toy_outlined` (Material ikonu) kullanıyordu —
          şekli TAMAMEN farklı. Bu, ★/✓ gibi "gömülü fontta glyph yok →
          ikona geç" kararlarından FARKLI bir sınıf: 🤖 bir emoji, ikon
          gerektiren bir font-eksikliği değil (help_modal.dart'taki
          🎯🏠🔗 ve k-lig'in 🏆'ı zaten `fontFamilyFallback` ile gerçek
          emoji basıyor) — port sırasında es geçilmiş bir ikame.
     - **Düzeltme:**
       - `KAvatar` `StatelessWidget`'tan `StatefulWidget`'a çevrildi —
         web'in `useState<boolean>(broken)` + `useEffect(() =>
         setBroken(false), [url])` deseninin birebir eşleniği: `_broken`
         alanı `didUpdateWidget`'ta `url` DEĞİŞİNCE sıfırlanıyor (web'in
         "eski bir yükleme hatası yeni geçerli bir URL'de kalıcı
         kalmasın" düzeltmesi). Container'ın zemin/çerçeve rengi artık
         KOŞULLU: fotoğraf başarıyla yükleniyorsa `_panel`/`_border`
         (web `<img border-border>`), yoksa/yüklenemezse `_accent`
         (0xFF2563EB) zemin+çerçeve + beyaz yazı (web `<span
         bg-accent border-accent text-white>`). `Image.network`'ün
         `errorBuilder`'ı BUILD SIRASINDA çağrıldığından `setState`'i
         doğrudan orada tetiklemek "called during build" hatası verir —
         web'in reaktif `onError`'unun eşleniği `addPostFrameCallback`'e
         ertelendi.
       - `PlayerAvatarRow._Avatar`'ın `isGuest` dalı, kendi elle yazılmış
         gri/beyaz "?" kopyasını (Container+Text, `_muted` renkli) TAMAMEN
         KALDIRDI — artık `KAvatar(name: '', size: size)`'a delege ediyor.
         Bu hem kod tekrarını kapattı hem de KAvatar'ın rengi düzelince
         ikisinin sessizce AYRIŞMASINI (biri düzelip diğeri unutulması)
         yapısal olarak imkânsızlaştırdı. `isAi` dalındaki
         `Icons.smart_toy_outlined` gerçek `Text('🤖')`'a çevrildi
         (`fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji']`
         — help_modal.dart'taki emoji dersiyle aynı), font-size oranı
         web'in `Math.round(size*0.55)`'iyle eşleşecek şekilde `0.6`'dan
         `0.55`'e düzeltildi (eski değer hiç web'den türetilmemiş,
         tahmini bir sayıymış). `player_avatar_row.dart`'taki artık
         kullanılmayan `_panel`/`_muted` sabitleri silindi.
     - **Etki taraması:** `KAvatar` 16 dosyada kullanılıyor (Hesap menüsü,
       Hesap Ayarları, Skor Kartı, k-lig, Arkadaşlar, Canlı oyun ekranları,
       Oyun Geçmişi…) — hiçbir mevcut test bu widget'ın renk/ikon
       detaylarını ASSERT ETMİYORDU (grep ile doğrulandı), bu yüzden
       düzeltme mevcut 250 testin HİÇBİRİNİ bozmadı; yalnızca YENİ
       `avatar_test.dart` bu davranışı doğruluyor.
     - **Yeni test — `avatar_test.dart` (5 test), negatif eş
       doğrulamasıyla:** "?" yedeğinin `_accent` renginde olduğu, isimli
       ama fotoğrafsız bir kullanıcının ("IR") da AYNI mavi rengi aldığı
       (renk yalnızca "?" özel durumu değil), YZ koltuğunun gerçek 🤖
       metnini gösterip `Icons.smart_toy_outlined`'ın hiç bulunmadığı,
       misafir koltuğunun da aynı mavi yedeği KAvatar üzerinden aldığı +
       bir ekran görüntüsü (`build/screenshots/avatar.png`, üç avatarı
       yan yana gösteriyor — web'deki mavi "?"/"IR" + gerçek robot
       emoji'siyle gözle karşılaştırıldı, birebir eşleşiyor). Düzeltme
       geçici geri alınıp (`git stash`) test dosyası koşuldu — assertion
       taşıyan 4 testin TAMAMI gerçekten düştü (yalnızca assertion'sız
       ekran görüntüsü testi geçti), sonra düzeltme geri konup 5/5 yeşile
       döndü (kök CLAUDE.md'nin "negatif eş" dersi).
     - Doğrulama: `flutter analyze` temiz, **tam takım 255/255 yeşil**
       (250 + bu parçanın 5 testi). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda/gerçek web derlemesinde görsel
       karşılaştırma kullanıcının paylaştığı iki ekran görüntüsüyle
       yapıldı (kod okuması DEĞİL) — deploy sonrası gerçek cihazda bir
       kez daha (sert yenileme sonrası) teyit edilmeli.
   - ✅ **Parça 23 — sürükleme HER pointer hareketinde tüm tahtayı (169
     hücre + territory hesabı) sıfırdan yeniden inşa ediyordu (8 Ağustos
     2026, `board_widget.dart`, `game_screen.dart`, `online_game_screen.dart`):**
     FAZ A1 cihaz testinde (iPad Safari, gerçek web derlemesi) kullanıcı taş
     sürüklerken "hafif titreyerek/takılarak" olduğunu bildirdi.
     - **Ölçüm (bu ortamda, native VM/Skia'da — gerçek cihaz/CanvasKit değil):**
       `board_widget.dart`'a geçici bir sayaç eklenip `flutter test`'te gerçek
       bir `tester.startGesture` + 30 adımlık `moveTo` dizisiyle sürükleme
       simüle edildi — **30 pointer-move adımı → `BoardWidget.build()` TAM 30
       KEZ çağrıldı (1:1)**, adım başı ortalama **~38-40ms** (60fps bütçesi
       16.7ms'nin 2 katından fazla). Kontrol: state değişmeden 30 `pump()` →
       0 board build, adım başı ~0.13ms — maliyetin tamamen bu per-move
       rebuild'den geldiği doğrulandı.
     - **Kök sebep:** `game_screen.dart`'taki `_moveTileDrag` (ve
       `online_game_screen.dart`'taki BİREBİR eşleniği) her
       `PointerMoveEvent`'te `setState(() { _ghost = _Ghost(...); })`
       çağırıyordu — bu, ekranın TÜM `build()`'ini yeniden çalıştırıyor, ki bu
       da her seferinde YENİ bir `BoardWidget(...)` örneği inşa ediyordu.
       `BoardWidget` bir `StatelessWidget` olduğundan (const değil), her yeni
       örnek `build()`'ini baştan çalıştırıyor — 169 hücre + territory hesabı
       + outline painter'lar her pointer hareketinde sıfırdan.
     - **Tasarım — üç parça:**
       1. `BoardWidget`'ın `dragOverKey`/`dragOverValid` parametreleri
          TAMAMEN KALDIRILDI (ve hücre inşa döngüsündeki kesikli-çerçeve
          bloğu) — `dragHiddenKey` KALDI (nadir değişiyor, sorun değil).
          `_DashedBorderPainter` public'e çevrildi (`DashedBorderPainter`) ki
          ekran katmanları da kullanabilsin — kopya YAZILMADI, sınıf taşındı.
       2. Her iki ekranda da `_Ghost? _ghost` alanı
          `final ValueNotifier<_Ghost?> _dragNotifier` oldu. `_moveTileDrag`
          artık `setState` YERİNE `_dragNotifier.value = _Ghost(...)` yazıyor
          — GameScreen'in tüm build'ini tetiklemeyi durduran asıl değişiklik.
          Ekrandaki hayalet taş + hover çerçevesi artık KOŞULSUZ duran tek bir
          `ValueListenableBuilder<_Ghost?>` (`Stack`teki eski
          `if (_ghost != null) _buildGhost()` yerine) — yalnızca kendi küçük
          alt ağacını günceller, `BoardWidget`'ı tetiklemez. `dispose()`'ta
          `_dragNotifier.dispose()` (`game_screen.dart`'ta `dispose()` hiç
          yoktu, eklendi; `online_game_screen.dart`'ta zaten vardı).
       3. **Hover çerçevesi artık ekran katmanının kendi overlay'i** —
          hücrenin ızgaradaki GERÇEK konumu `_gridKey`'in boyutundan
          `_cellAtGlobal` ile AYNI stride formülüyle (`(grid.size+gap)/13`)
          elle hesaplanıp `_stackKey`'e göre `Positioned` ile konumlandırılıyor
          (`_hoverHighlight`, `_buildGhost`'un `globalToLocal` deseniyle
          tutarlı).
     - **Bilinçli tasarım REVİZYONU — `dragHiddenKey` `_beginTileDrag`'de
       DEĞİL, eşik-aşımı anında dolduruluyor:** İlk taslak (kullanıcının
       verdiği brief) `dragHiddenKey`i `_beginTileDrag`de (pointer-down
       anında, eşik aşılmadan) hesaplamayı öneriyordu. Bu, web/eski
       davranıştan sapardı: sıradan bir dokunuşta (sürüklenmeden bırakılan)
       taş bir an için görünmez olurdu, üstelik yerine henüz hiçbir hayalet
       taş da çizilmemiş olurdu (ghost yalnızca eşik aşılınca `_moveTileDrag`
       içinde belirir) — bir görsel "delik". Bunun yerine `_hiddenSource`
       (board için `dragHiddenKey`, rafta `dragHiddenIndex`) `_moveTileDrag`in
       `d.moved` geçişinde (eşik İLK kez aşıldığında, sürükleme başına TEK
       sefer) `setState`'le dolduruluyor — hem web'in "gerçek hareket
       başlayınca kaynağı gizle" anıyla birebir örtüşüyor hem de performans
       hedefini aynen koruyor (sürükleme başına yalnızca BİR ekstra
       `setState`, per-move DEĞİL — brief'in izin verdiği "0-1 kez" toleransı
       içinde).
     - **Test — negatif eş doğrulamasıyla (kök CLAUDE.md dersi):** Yeni bir
       `testWidgets` (`game_screen_test.dart`), gerçek bir sürükleme simüle
       edip (`startGesture` + 30 adımlık `moveTo`, her adımda `pump()`) eşik
       aşıldıktan SONRAKİ `BoardWidget.build()` sayısını ölçüyor — bunun için
       `board_widget.dart`'a `@visibleForTesting int
       debugBoardBuildCountForTests` (yalnızca `kDebugMode`de artan bir
       sayaç) eklendi. Düzeltme GEÇİCİ OLARAK geri alınıp (`_dragNotifier`e
       yazımın `setState` içine alınması) test koşuldu — **GERÇEKTEN
       başarısız oldu: `Expected: <=1, Actual: <30>`** (30/30 rebuild, tam
       yukarıdaki ölçümle birebir eşleşen sayı), sonra düzeltme geri konup
       yeşile döndü. Ayrıca hover çerçevesinin/hayalet taşın GERÇEK render
       konumu (`tester.getRect`) `boardCell(0,0)`'ın rect'iyle < 1px farkla
       karşılaştırılarak doğrulandı (aynı desen `online_game_screen_test.dart`'ın
       mevcut sürükleme testine de eklendi) — ekran görüntüsünde (`game_drag.png`)
       hayalet taş (46px, cell'den büyük) hedefin üstüne tam oturduğundan
       kesikli çerçeveyi görsel olarak örtüyor (web'in DRAG_LIFT tasarımı
       gereği İKİSİ HER ZAMAN aynı noktada), bu yüzden konum yalnızca gözle
       değil bu geometrik assertion'la da kanıtlandı.
     - Doğrulama: `flutter analyze` temiz, değişmez taraması temiz (hiçbiri
       yeni bir ihlal göstermedi — dokunulan dosyalar zaten grep'in kapsamı
       DIŞINDA). **Tam takım iki ayrı temiz koşuda 256/256 yeşil** (255 + bu
       parçanın 1 yeni testi) — `game_screen_test.dart`/`online_game_screen_test.dart`'ın
       MEVCUT sürükleme testleri (raftan tahtaya/tahtada taşıma/rafa geri
       alma, sayfa kaymama) HİÇ DEĞİŞMEDEN geçti. `kelimeki_core`'a hiç
       dokunulmadı (golden vector yeniden üretimi gerekmedi) — bu tamamen
       Flutter render/state katmanına özgü bir düzeltme.
     - **Doğrulama sınırı:** Bu ortamda gerçek cihaz/CanvasKit performansı
       ÖLÇÜLEMEDİ — yalnızca native VM/Skia'da (`flutter test`) rebuild
       SAYISININ 30/30'dan 0'a düştüğü kanıtlandı; gerçek "artık daha akıcı
       hissediyor" teyidi kullanıcının cihazından (sert yenileme/yeni build
       sonrası) bekleniyor. `mobile/TESTING.md`'ye bir regresyon notu eklendi.
   - ✅ **Parça 24 — tahta taşı harf/puan puntosu EKRAN GENİŞLİĞİNE değil
     sabit bir sayıya bağlıydı; web geniş ekranda daha büyük harf çiziyor
     (8 Ağustos 2026, `tile_widget.dart`, yeni `fluid.dart`):** Kullanıcı
     kelimeki.com ("web") ile `alpcapa.github.io` ("app") ekran
     görüntülerini (ikisi de iPad) yan yana koyup "taş fontları biraz
     farklı gibi, web daha mı büyük?" diye sordu.
     - **Kök sebep, kaynak koddan (tahmin değil) doğrulandı:**
       `src/components/Tile.tsx`'te tahta harfi hücre/kart genişliğine
       DEĞİL, doğrudan tarayıcı VIEWPORT genişliğine (`vw`) bağlı:
       `clamp(14px, 3.8vw, 24px)` (puan üst simgesi aynı sistemde
       `clamp(6px, 1.6vw, 10px)`) — raf harfi ise web'de de sabit
       (`text-[24px]`/`10px`). Flutter portu (`tile_widget.dart`) tahta
       varyantını hiç `vw`'ye bağlamamıştı, sabit 20px/7px kullanıyordu.
       iPad gibi geniş bir ekranda (viewport >631px, `3.8vw` formülü
       zaten 24'ü aştığından web üst sınıra kilitleniyor) bu, web 24px
       çizerken app'in sabit 20px'te kalması demekti (~%17 küçük) —
       ekran görüntüsündeki fark kullanıcının izlenimi değil ÖLÇÜLEBİLİR
       bir gerçekti. **Dar ekranlarda ise TERSİ de doğruydu** (ölçüm
       sırasında bulundu): 390px'lik bir telefonda web'in formülü
       `0.038×390≈14.82px` verirken port sabit 20px basıyordu — yani port
       hem büyük ekranda küçük hem küçük ekranda BÜYÜK çiziyordu, ikisi de
       aynı kök sebepten (viewport'a hiç bağlı olmayan sabit sayı).
     - **Düzeltme — `game_header.dart`'ın `_fluid()`'i (web'in
       `clamp(min, calc(a+b·vw), max)` sisteminin Flutter karşılığı, Parça
       4'ten beri var) ortak `fluid.dart`'a (`fluidSize`) çıkarıldı:**
       tek dosyada özel kalması (Dart privacy dosya/kütüphane bazlı)
       ikinci bir kopya açmayı gerektirirdi — kural buydu ("aynı formülü
       iki widget'ın sessizce ayrıştırmasına izin verme"). `game_header.dart`
       kendi `_fluid` tanımını silip bu ortak fonksiyona geçti (davranış
       BİREBİR aynı — yalnızca isim/dosya taşındı, katsayılar dokunulmadı).
       `tile_widget.dart`'ın tahta/compact dalları artık
       `fluidSize(screenWidth, min, a, b, max)` çağırıyor
       (`MediaQuery.sizeOf(context).width` — web'in `vw`'sinin Flutter
       karşılığı): harf `fluidSize(w,14,0,3.8,24)` (compact önizlemede
       `fluidSize(w,8,0,2.4,14)`), puan `fluidSize(w,6,0,1.6,10)`. Raf
       varyantı (24/10) DOKUNULMADI — web'de de sabit.
     - **Test — negatif eş doğrulamasıyla (kök CLAUDE.md dersi):** Yeni
       `tile_font_size_test.dart` (5 test) — geniş ekranda (1024px) tahta
       harfinin GERÇEKTEN 24px'e kilitlendiği (eski sabit 20 burada
       farklı çıkardı), dar ekranda (390px) ~14.82px olduğu, 631px altında
       tabana (14px) kilitlendiği, raf harfinin ekran genişliğinden
       ETKİLENMEDİĞİ (24px sabit — regresyon güvencesi), puan üst
       simgesinin de aynı sistemi paylaştığı (geniş ekranda 10px).
       Doğrulama render edilmiş GERÇEK `Text` widget'ının `fontSize`'ını
       okuyor — `fluidSize`'ın kendisiyle karşılaştırıp hiçbir şey
       kanıtlamayan bir totoloji kurulmadı. Düzeltme geçici olarak
       `git stash`lanıp (yalnızca `tile_widget.dart`, `fluid.dart`/
       `game_header.dart` yerinde bırakılarak) test tekrar koşuldu — 5
       testten 4'ü GERÇEKTEN düştü (`Expected: <24> Actual: <20.0>` gibi;
       raf testi beklendiği gibi geçti, çünkü rack hiç değişmedi), sonra
       düzeltme geri konup 5/5 yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 261/261 yeşil**
       (256 + bu parçanın 5 testi). `kelimeki_core`'a hiç dokunulmadı.
       Tam takım koşusunda `game_screen_test.dart`'taki joker seçici
       testinde (`TileVariant.rack` kullanan, bu parçadan hiç
       etkilenmeyen bir widget) zararsız bir hit-test UYARISI (fatal
       değil, testi düşürmüyor) gözlendi — düzeltme öncesi aynı tam-takım
       koşusunda da vardı, bu parçayla ilgisiz/önceden var olan bir
       ortam tuhaflığı.
     - **Doğrulama sınırı:** cihazda/gerçek web derlemesinde görsel
       karşılaştırma bu oturumda yapılamadı (kaynak kod okuması +
       widget-test ölçümüyle doğrulandı) — deploy sonrası kullanıcının
       kendi cihazında (iPad + telefon, ikisi birden — fark her iki yönde
       de gerçek) teyit edilmeli.
   - ✅ **Parça 25 — "Pas Geç" onayının metni BAYATTI + tüm dört onay
     diyaloğunda kabul butonu VAZGEÇ'in YANLIŞ tarafındaydı (8 Ağustos
     2026, `game_screen.dart`, `online_game_screen.dart`):** Cihaz testi
     triyajı sırasında iki gerçek, birbirinden bağımsız hata bulundu.
     - **Bug 1 — kardeş ekran senkronsuzluğu, tam da `mobile/CLAUDE.md`'nin
       kendi uyardığı sınıftan:** Bu dosyanın "Etki Analizi" bölümü
       `game_screen.dart` (yerel/YZ) ile `online_game_screen.dart`'ın
       (Canlı) sürükle-bırak/joker/mesaj mantığını BİLİNÇLİ kod tekrarıyla
       taşıdığını ve "biri değişirse öteki de AYNI PR'da güncellenmeli"
       dediğini söylüyor — pas onayı bu uyarının somut bir örneğiydi.
       `online_game_screen.dart`'ın Pas Geç diyaloğu bir noktada web'e
       (`src/App.tsx`'in `showPassConfirm` bloğu) uydurulup başlığı
       "Pas Geçiyorsun!", gövdesi "Pas geçmek istediğinden emin misin?
       Sıran diğer oyuncuya geçer." olmuştu — ama `game_screen.dart`'taki
       ikizi hiç güncellenmemiş, hâlâ eski/bayat "Pas Geç" başlığı +
       "Sıranı pas geçmek istediğine emin misin?" gövdesini taşıyordu.
       Düzeltme: `game_screen.dart`'ın `_handlePass`'i web/`online_game_
       screen.dart` ile BİREBİR aynı metne çekildi — `online_game_screen.
       dart`'ın metnine HİÇ DOKUNULMADI (zaten doğruydu).
     - **Bug 2 — buton sırası web'in TERSİYDİ, tüm dört diyalogda:** Web
       (`src/App.tsx`) hem "Sınır İhlali!" hem "Pas Geçiyorsun!"
       diyaloglarında kabul/aksiyon butonunu (Oyna/Pas Geç) HER ZAMAN
       SOLDA, Vazgeç'i SAĞDA render ediyor (düz `flex` satırı, `row-reverse`
       yok — JSX'te `<button>Oyna</button>` `<button>Vazgeç</button>`'ten
       önce). Flutter portundaki dört diyalogun (`game_screen.dart`'ta
       Sınır İhlali + Pas Geçiyorsun, `online_game_screen.dart`'ta aynı
       ikisi) `actions:` listesi `[TextButton(VAZGEÇ), FilledButton(kabul)]`
       sırasındaydı — `AlertDialog.actions` liste sırasıyla soldan sağa
       dizildiğinden bu, VAZGEÇ'i solda, kabul butonunu sağda gösteriyordu
       (kullanıcı ekran görüntüsüyle doğruladı). Düzeltme: dördünde de
       liste `[FilledButton(kabul), TextButton(VAZGEÇ)]`'e çevrildi —
       `onPressed`/`child` içerikleri DOKUNULMADAN, yalnızca sıra değişti.
     - **Bilinçli DOKUNULMAYAN:** "Sınır İhlali!" diyaloğunun başlık/gövde
       metni (ikisi zaten web'le birebirdi, yalnızca buton sırası
       yanlıştı); `kelimeki_core` (motor dosyası değil, golden vector
       yeniden üretimi gerekmedi).
     - **Test — negatif eş doğrulamasıyla (kök CLAUDE.md dersi), İKİ AYRI
       spot-check:** `game_screen_test.dart`'a yeni bir test eklendi — Pas
       Geç butonuna dokunup açılan diyalogda (1) başlık+gövdenin web
       metniyle birebir olduğunu, (2) kabul butonunun (`FilledButton`,
       'PAS GEÇ') `getTopLeft().dx`'inin VAZGEÇ'inkinden (`TextButton`)
       KÜÇÜK (yani solda) olduğunu doğruluyor. **İki ayrı negatif-eş
       koşusu yapıldı:** (a) `git stash` ile YALNIZCA `game_screen.dart`'ın
       düzeltmesi geri alınıp (test dosyası düzeltilmiş hâliyle kaldı)
       test koşuldu — GERÇEKTEN `find.text('Pas Geçiyorsun!')` 0 widget
       buldu (`Expected: exactly one matching candidate, Actual: Found 0
       widgets`), stash pop ile geri alınıp yeşile döndü; (b) yalnızca
       buton SIRASI (metin doğru bırakılarak) geçici olarak eski hâline
       çevrilip test tekrar koşuldu — GERÇEKTEN `Expected: a value less
       than <169.22>, Actual: <252.62>` ile düştü (kabul butonu artık
       VAZGEÇ'in solunda değil sağındaydı), sonra doğru sıra geri konup
       yeşile döndü. İkisi de metin ve sıra hatalarının BAĞIMSIZ olarak
       yakalandığını kanıtlıyor — birinin varlığı diğerini maskelemiyor.
     - Doğrulama: `flutter analyze` temiz, mevcut `online_game_screen_test.
       dart`'taki Pas Geç testi (`find.widgetWithText(FilledButton, 'PAS
       GEÇ')`/`find.text('VAZGEÇ')` — widget-tipi/metin bazlı, sıraya
       duyarsız) hiç değişmeden geçti. **Tam takım 262/262 yeşil** (261 +
       bu parçanın 1 yeni testi). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda gerçek görsel teyit (yeni metin +
       düzeltilmiş buton sırası) bu oturumda yapılamadı — kullanıcının
       cihaz testi triyajı bu iki hatayı zaten bulduğundan, sonraki
       cihaz turunda "artık web'le birebir mi" diye bakması yeterli;
       `mobile/TESTING.md`'ye ayrı bir YENİ madde eklenmedi (mevcut
       "Taş değiştirme / pas" ve "Bölge vergisi" maddeleri beklenen
       metin/buton sırasını artık açıkça belirtiyor).
   - ✅ **Parça 26 — GameOver modalı ortak `KModal` kabuğunu kullanmıyordu
     (geniş/kare-değil, bottom "KAPAT" düğmesi web'de yok) + TORBA
     sayacı ayrı stillendirilmemişti (8 Ağustos 2026, `game_over_modal.dart`,
     `neo_button.dart`, `game_screen.dart`, `online_game_screen.dart`):**
     Cihaz testinde aynı turda bulunan, birbirinden bağımsız iki hata.
     - **Bug 1 — `GameOverModal` ham `Dialog` kuruyordu, paylaşılan
       `KModal`'ı hiç kullanmıyordu:** Web kaynağı (`src/components/
       GameOver.tsx`) TÜM içeriği (kazanan başlığı, oyuncu skor kartı,
       "Oyun Geçmişi"/"Görüş Bildir" linkleri) paylaşılan
       `<Modal title="" onClose={onClose}>`'un (`src/components/Modal.tsx`)
       `children`'ı olarak render ediyor — `title=""` başlık çubuğunu boş
       başlıkla gösterse de bırakıyor, kapatmanın TEK yolu sağ üstteki ✕.
       Web'de bottom bir "Kapat"/"KAPAT" düğmesi HİÇ YOK. Flutter portu
       ise kendi `Dialog(backgroundColor:..., shape:...)`'unu kuruyordu —
       genişlik sınırsız (360px web sabitine karşı geniş/"kare değil"
       render, kullanıcının cihaz ekran görüntüsü karşılaştırmasıyla
       bulduğu şey) ve altta `TextButton(child: Text('KAPAT'))` vardı —
       ikisi de web'de yok. `mobile/CLAUDE.md`'nin Parça 8'de zaten
       hazırladığı ortak `modal_shell.dart`'taki `KModal` (360px maxWidth,
       ✕, `title:''` desteği — kendi doc yorumu bu geçişi öngörmüştü:
       "Boş bırakılabilir — web'de GameOver `title=""` geçip yalnızca ✕
       gösterir") hiç kullanılmamıştı. **Düzeltme:** `GameOverModal.build()`
       artık `KModal(title: '', child: Column(...))` döndürüyor — dış
       `Dialog`/`Padding`/`backgroundColor`/`shape` boilerplate'i tamamen
       kaldırıldı, `KModal`'ın kendi 20/16/20/20 padding'i içeriğin
       kendi `SizedBox` boşluklarıyla çakışmadığından ekstra bir kırpma
       gerekmedi (görsel olarak `game_over.png` ekran görüntüsünde
       doğrulandı). Bottom link satırındaki `TextButton(child: Text
       ('KAPAT'))` tamamen silindi — "Oyun Geçmişi"/"Görüş Bildir"
       linkleri aynen kaldı, kapatma artık yalnızca KModal'ın ✕'i.
     - **Bug 2 — TORBA sayacı web'in `<span text-[13px] text-accent>`
       ayrımını taşımıyordu:** Web (`src/App.tsx` ~1360) `Torba <span
       className="text-[13px] text-accent">{state.bag.length}</span>`
       yazıyor — `<span>` yalnızca punto (13px, düğmenin kendi 11px'ine
       karşı) ve rengi (`#2563EB` mavi, düğmenin `text-text` koyu rengine
       karşı) EZİYOR, `font-bold`/`uppercase`/`tracking-[1.2px]` düğmeden
       miras kalıyor. `NeoButton` (`neo_button.dart`) tek düz bir
       `String label` alıp tek biçimli `Text` basıyordu — iki oyun
       ekranındaki (`game_screen.dart`, `online_game_screen.dart` —
       ikisi de bu deseni AYRI AYRI taşıyan bilinçli kod tekrarı çifti,
       bkz. dosyanın "Etki Analizi" bölümü) TORBA çağrıları düz
       `'TORBA ${state.bag.length}'` interpolasyonu geçiyordu, sayı hiç
       ayrışmıyordu. **Düzeltme:** `NeoButton`'a opsiyonel `List<InlineSpan>?
       richLabel` parametresi eklendi — doluysa `FittedBox` içinde
       `Text.rich(TextSpan(style: baseStyle, children: richLabel))`
       render ediliyor (taban stil düğmenin MEVCUT `TextStyle`'ıyla
       BİREBİR aynı — yalnızca web'in `<span>`inin ezdiği iki alan
       değişiyor), `null` iken (projedeki ~10 diğer çağrı yeri) davranış
       TAMAMEN aynı kalıyor. İki TORBA çağrı yerine de `richLabel: [
       TextSpan(text:'TORBA '), TextSpan(text:'$bagCount', style:
       TextStyle(fontSize:13, color:Color(0xFF2563EB), fontWeight:
       FontWeight.bold))]` eklendi — `label` parametresi a11y/semantics
       yedeği olarak aynen kaldı (Flutter'ın `find.text` matcher'ı zaten
       `Text.rich`'in `textSpan.toPlainText()`'ini karşılaştırdığından
       mevcut `find.text('TORBA 6')` testi hiç değişmeden geçmeye devam
       etti — bu yan bulgu ayrı bir kod değişikliği gerektirmedi).
     - **Bilinçli DOKUNULMAYAN:** `kelimeki_core` (motor dosyası değil,
       golden vector yeniden üretimi gerekmedi); `NeoButton`'ın diğer
       hiçbir çağrı yeri (richLabel varsayılan `null`, davranış birebir
       korunuyor); web `App.tsx`'in `spectating` dalındaki ikinci TORBA
       kopyası (kapsam dışı, bkz. Parça günlüğünün diğer maddelerindeki
       aynı gerekçe — mobilde `spectating` hiç ulaşılamıyor).
     - **Test — negatif eş doğrulamasıyla (kök CLAUDE.md dersi), İKİ AYRI
       kanıt:** (1) `game_screen_test.dart`'a yeni bir test eklendi —
       GameOver açıldıktan sonra `find.text('KAPAT')` artık `findsNothing`,
       `find.byTooltip('Kapat')` `findsOneWidget` ve tıklanınca modal
       kapanıyor; ikinci bir test `find.byType(Dialog)`'un TEK olduğunu
       (GameOverModal artık ikinci bir ham Dialog kurmuyor) ve 360px
       `maxWidth` taşıyan bir `ConstrainedBox` bulunduğunu doğruluyor.
       `game_over_modal.dart`'ın düzeltmesi `git stash push -- <dosya>`
       ile geçici geri alınıp test koşuldu — GERÇEKTEN `find.text('KAPAT')`
       1 widget buldu (`Expected: no matching candidates, Actual: Found 1
       widget`), `stash pop` ile geri alınıp yeşile döndü. (2)
       `game_screen_test.dart`'a (+ aynı fikirle `online_game_screen_test.
       dart`'a, `NeoButton` artık ortak katman olduğundan iki ekranda da
       ayrı test) TORBA'nın `Text.rich` çocuklarında `'6'`/`'60'` span'inin
       `fontSize:13`/`color:0xFF2563EB` taşıdığını doğrulayan testler
       eklendi. `neo_button.dart`'taki `if (richLabel != null)` dalı
       geçici olarak `if (false && richLabel != null)`'a çevrilip test
       koşuldu — GERÇEKTEN `type 'Null' is not a subtype of type
       'TextSpan' in type cast` ile düştü (richLabel hiç kullanılmadığından
       `Text.rich` yolu render olmuyordu), satır geri konup yeşile döndü.
     - Doğrulama: `flutter analyze` temiz. **Tam takım 266/266 yeşil**
       (gerçek baseline 263/263'tü — `git stash` ile bu parçadan önceki
       HEAD'e (7b53f70) dönülüp doğrulandı; Parça 25'in doc'undaki "262"
       rakamı bir öncekinden kalma küçük bir sapmaydı, buradaki 263→266
       delta kendi içinde tutarlı ve doğrulanmış — 3 yeni test: GameOver/
       KModal + TORBA stili (game_screen_test.dart 2 test) + TORBA stili
       (online_game_screen_test.dart 1 test)). `kelimeki_core`'a hiç
       dokunulmadı.
     - **Doğrulama sınırı:** cihazda gerçek görsel teyit (360px kare
       kart + ✕-only kapatma + TORBA sayacının gerçekten mavi/büyük
       göründüğü) bu oturumda yapılamadı — kullanıcının bir sonraki cihaz
       testi turunda web ile yan yana karşılaştırması bekleniyor;
       `mobile/TESTING.md`'nin Bölüm 1 "Oyun sonu" maddesine bu iki
       davranış (360px/✕-only/KAPAT-yok, TORBA sayaç stili) eklendi.
   - ✅ **Parça 27 — tahtadan rafa sürüklerken hayalet taş, board sınırını
     geçerken KAYBOLUYORDU: gerçek kök sebep bir CanvasKit özel durumu
     DEĞİL, Stack'in "yalnızca Positioned çocuk" değişmezinin ihlaliydi
     (8 Ağustos 2026, `game_screen.dart`/`online_game_screen.dart`
     `_hoverHighlight`):** Kullanıcı cihaz testinde bildirdi: "Tahtaya
     konan taşı sürükle bırak şeklinde rafa geri alırken board sınırını
     geçerken yok oluyor. Taş rafa dönüyor ama görünmüyor." Web'de aynı
     geçiş net görünüyor.
     - **Önce kod okumasıyla teşhis denendi, sonuçsuz kaldı:** sürükleme
       geometrisi (`_beginTileDrag`/`_moveTileDrag`/`_buildGhost`/
       `_hoverHighlight`) ve widget ağacı (`ValueListenableBuilder` →
       `Stack(children:[_hoverHighlight, _buildGhost])`, dış `_stackKey`
       Stack'inin doğrudan ikinci çocuğu) baştan sona okundu — hiçbir
       koşullu gizleme/kırpma mantığı GÖRÜNMÜYORDU. Kök CLAUDE.md'nin
       "tahminle düzeltme yapma" dersi (Parça 18 emsali) gereği koda
       müdahale edilmedi, ölçülerek ilerlendi.
     - **Adım 1 — native Skia'da widget-ağacı/geometri testi: hatayı hiç
       YAKALAMADI.** `flutter test` ile 20 adımlık senteze bir sürükleme
       simüle edilip her adımda hayalet taşın `TileWidget` sayısı VE
       gerçek `Rect`'i (`tester.getRect`) ölçüldü — sayaç hep `1`, `Rect`
       hep tutarlı/doğrusal kaldı, board'un alt kenarını (`boardBottom`)
       geçerken HİÇBİR ANOMALİ yoktu. Bu ADIM TEK BAŞINA "sorun yok"
       sonucuna götürüyordu — ama yalnızca widget LAYOUT geometrisini
       ölçüyordu, PAINT/kırpmayı DEĞİL (kritik ayrım, aşağıda).
     - **Adım 2 — gerçek CanvasKit'te (tarayıcı) ölçüm: hata BİREBİR
       tekrarlandı.** `GameScreen`'i (crafted küçük bir state ile,
       Supabase/sözlük boot etmeden) render eden minik bir web harness'i
       (`flutter build web --target=<harness>`) derleyip yerel Chromium'da
       (Playwright, `--use-angle=swiftshader --enable-unsafe-swiftshader`;
       CanvasKit'in varsayılan `gstatic.com` CDN'i bu ortamın proxy'sinde
       engelli olduğundan istekler yerel `build/webprobe/canvaskit/`
       dosyalarına `page.route`+`fulfill` ile yönlendirildi) açılıp
       GERÇEK bir pointer sürüklemesi (board hücresinden rafa, 24 küçük
       adım) sürülüp her adımda ekran görüntüsü alındı: hayalet taş K
       hücresi tam olarak board'un alt kenarını geçerken (adım ~17/24)
       KAYBOLUYOR ve rafa varana, hatta bırakılana kadar bir daha hiç
       görünmüyordu — kullanıcının tarifiyle birebir.
     - **Adım 3 — asıl kök sebep GENE native Skia'da, ama bu sefer doğru
       şeyi ölçerek bulundu:** Adım 1'in "geometri hep doğru" bulgusuyla
       Adım 2'nin "gerçek render'da kayboluyor" bulgusu birlikte ŞUNU
       ima ediyordu: widget hâlâ ağaçta/doğru konumda ama PAINT'te
       KIRPILIYOR — bir Flutter CLIP operasyonu layout geometrisini hiç
       değiştirmez, yalnızca paint'i etkiler, bu yüzden Adım 1'in
       `getRect` kontrolleri böyle bir hatayı yapısal olarak GÖREMEZDİ.
       `_hoverHighlight`/`_buildGhost`'u saran iç `Stack`'e GEÇİCİ bir
       `key` eklenip `flutter test`'te bu Stack'in GERÇEK render
       boyutu her adımda ölçüldü: board'un içindeyken `Size(420.0,
       900.0)` (tam ekran), board'un DIŞINA çıkar çıkmaz **`Size(0.0,
       0.0)`**'a çöküyor ve bir daha düzelmiyordu.
     - **Mekanizma:** `_hoverHighlight(g)`'in `g.overKey == null` (pointer
       artık board grid'inin üzerinde değil — tam da rafa doğru sürükleme
       sırasında olan şey) ve `grid==null||stack==null` erken dönüşleri
       ÇIPLAK `const SizedBox.shrink()` döndürüyordu — `Positioned` İÇİNE
       SARILMAMIŞ. Bu, onu saran `Stack(children:[_hoverHighlight(g),
       _buildGhost(g)])`'un TEK non-positioned çocuğu hâline getiriyordu
       (`_buildGhost` her zaman `Positioned` döner). Flutter'ın Stack
       boyutlandırma kuralı: non-positioned çocuk YOKSA Stack gelen
       constraint'in en büyüğüne (`constraints.biggest`) sığar; EN AZ BİR
       non-positioned çocuk VARSA Stack o çocu(kları)n boyutuna göre
       küçülür — burada tek non-positioned çocuk `SizedBox.shrink()`
       (0×0) olduğundan Stack'in KENDİSİ 0×0'a küçülüyordu. Stack'in
       varsayılan `clipBehavior: Clip.hardEdge`'i de bu 0×0 alanın
       dışındaki HER ŞEYİ (diğer çocuk olan hayalet taşın `Positioned`ı
       dahil) kırpıyordu — taş hâlâ doğru koordinatta "var" ama hiç
       boyanmıyordu.
     - **Düzeltme (sihirli sayı yok, tek satırlık kavram):** iki erken
       dönüş de artık `const Positioned(left: 0, top: 0, child:
       SizedBox.shrink())` döndürüyor — Stack'in "yalnızca Positioned
       çocuk" değişmezi hiçbir zaman bozulmuyor, Stack her zaman
       `constraints.biggest`e (tam ekran) sığıyor. `online_game_screen.
       dart`'taki BİREBİR AYNI kopya (`_hoverHighlight`, "bilinçli kod
       tekrarı" çifti) da aynı iki satırla düzeltildi.
     - **Test — negatif eş doğrulamasıyla:** her iki dosyaya da (kalıcı,
       teşhis harness'i DEĞİL) yeni bir regresyon testi eklendi — rafa
       doğru bir sürükleme başlatılıp pointer board'un dışına taşınıyor,
       hayalet taşın (Board/Rack DIŞINDAki tek `TileWidget`) en yakın
       `Stack` atasının render boyutu `isNot(Size.zero)` ile doğrulanıyor.
       Düzeltme `git stash push -- <dosya>` ile GEÇİCİ geri alınıp
       (önce `game_screen.dart`, sonra ayrı bir turda `online_game_
       screen.dart`) her iki test de GERÇEKTEN `Expected: not
       Size:<Size(0.0, 0.0)> / Actual: Size(0.0, 0.0)` ile düştüğü
       görüldü, `stash pop` ile geri konup yeşile döndü — ikisi de
       ayrı ayrı kanıtlandı.
     - **Ders 1 — "widget-ağacı testi temiz" tek başına bir CLIP hatasını
       EKARTE ETMEZ:** `tester.getRect`/element-sayımı yalnızca LAYOUT
       geometrisini görür; bir ata `ClipRect`/`Clip.hardEdge` ile
       kırpıyorsa geometri hâlâ "doğru" raporlanır, yalnızca PAINT
       etkilenir. Bu proje daha önce Parça 18'de "değerler doğru, o hâlde
       CanvasKit'e özgü bir motor hatası" diye tahmin yürütmüştü (yanlış
       çıkmıştı) — bu sefer önce native Skia'da geometri ölçülüp "temiz"
       bulununca CanvasKit-özel bir hata olduğu VARSAYILABİLİRDİ, ama
       Adım 3'teki ek ölçüm (Stack boyutu) gösterdi ki hata aslında
       EVRENSEL bir Flutter mantık hatasıydı — CanvasKit'e özgü hiçbir
       şey yoktu, yalnızca native testin İLK turu YANLIŞ ŞEYİ (rect,
       clip değil) ölçmüştü. "CanvasKit'e özgü" sonucuna varmadan önce
       native tarafta GERÇEKTEN paint/clip'i de ölçmek gerekiyor —
       yalnızca geometriyi ölçmek yeterli değil.
     - **Ders 2 — `Stack`'in "non-positioned çocuk boyutu belirler"
       kuralı sessiz bir tuzak:** Bir `Stack`'in TÜM çocuklarının
       `Positioned` olduğu bir yerde YENİ bir erken-dönüş/koşullu dal
       eklerken, o dalın da `Positioned` (ya da eşdeğer sıfır-etkili bir
       `Positioned` sarmalayıcı) döndürmesi gerekiyor — çıplak
       `SizedBox.shrink()`/`Container()` gibi "zararsız görünen" bir
       yer tutucu, Stack'in TÜM boyutunu (dolayısıyla diğer TÜM
       Positioned kardeşlerin görünürlüğünü) sessizce bozabilir.
     - Doğrulama: `flutter analyze` temiz, tam takım **267/267 yeşil**
       (266'dan +2 — Parça 27'nin iki yeni regresyon testi;
       `kelimeki_core`'a hiç dokunulmadı, motor dosyası değil).
     - **Doğrulama sınırı:** Bu düzeltme hem native Skia (`flutter test`)
       hem gerçek CanvasKit'te (Playwright/Chromium web harness, adım
       adım ekran görüntüsüyle) doğrulandı — ikisi de bu oturumda
       yapılabildi. Gerçek bir iOS/Android cihazda (Skia/Impeller, web
       değil) parite hâlâ kullanıcıdan bekleniyor, ama hata mekanizması
       (bir Flutter framework kuralı, platform/render backend'inden
       BAĞIMSIZ) evrensel olduğundan cihazda da aynı şekilde düzelmesi
       bekleniyor — bkz. `mobile/TESTING.md` Bölüm 1'e eklenen yeni
       kontrol maddesi.
   - ✅ **Parça 28 — Bölüm 2 (Hesap/auth) cihaz testinde bulunan üç bağımsız
     hata (9 Ağustos 2026, `account_button.dart`, `setup_screen.dart`,
     `recent_games_section.dart`, `live_games_tab.dart`):**
     - **Bug 1 — hesap menüsünde "k-lig Sıralama" AYRI bir liste maddesi
       olarak çıkıyordu, web'de öyle değil:** Web kaynağı (`UserMenu.tsx`
       satır ~193-218) k-lig'i ayrı bir `<button>` OLARAK DEĞİL, isim
       başlığının (avatar+isim) HEMEN ALTINDA, kendi başına tıklanabilir
       küçük bir alt-satır olarak gösteriyor — `KLigMark` + "#sıra · puan
       puan" formatında, `myRank` (`fetchMyLeaderboardRank`) null iken boş.
       Mobil port bunu bir `PopupMenuItem<String>(value:'league', child:
       Row([KLigMark, Text('Sıralama')]))` olarak, başlığın ALTINDAKİ bir
       liste maddesi şeklinde kurmuştu — kullanıcı cihaz testinde "k-lig
       Sıralama diye ayrı bir madde çıkmış, o aslında isim altında yer
       alan bir özellik" diye bildirdi. **Düzeltme:** `_AccountButtonState`
       artık web'in `myRank` state'iyle AYNI (`StatsRepo.myRank(userId)`,
       zaten vardı — yalnızca `LeaderboardModal` kullanıyordu) bir
       `MyLeaderboardRank? _myRank` tutuyor (`_incomingRequests` ile aynı
       mount+hesap-değişimi tazeleme deseni); başlık `PopupMenuItem`'ının
       `child`'ı artık `Row(avatar, Column([isim, if (rank varsa)
       GestureDetector(k-lig satırı)]))`. Devre dışı (`enabled:false`) bir
       `PopupMenuItem`in İÇİNDE bağımsız tıklanabilir bir alt-widget kurmak
       için standart yol kullanıldı: iç `GestureDetector.onTap` doğrudan
       `Navigator.of(context).pop('league')` çağırıyor — bu, `showMenu`'nün
       kendi route'unu bir değerle kapatıp `PopupMenuButton.onSelected`i
       tetiklemesiyle AYNI mekanizma, dıştaki `enabled:false`'tan bağımsız
       çalışıyor (context, `itemBuilder(context)`'in kendi parametresi —
       menü route'u henüz push edilmeden yakalanan ama AYNI Navigator'a ait
       bir ata context, `Navigator.of()` route pozisyonundan bağımsız en
       yakın Navigator'ı bulduğundan sorunsuz çalışıyor).
     - **Bug 2 — madde sırası yanlıştı + "Çıkış Yap"ın kendi üstünde çizgi
       yoktu:** Web sırası (`UserMenu.tsx`): Arkadaşlar → Skor Kartı →
       Nasıl Oynanır? → Hesap Ayarları → (varsa Admin) → **Çıkış Yap**
       (kendi `border-t border-border`'ı HER ZAMAN var, admin bloğundan
       bağımsız). Mobil: Skor Kartı → Arkadaşlar (ters sıra) ve tek
       `PopupMenuDivider` başlığın hemen altındaydı, Çıkış Yap'ın üstünde
       hiç yoktu — kullanıcı ekran görüntüsüyle bildirdi. **Düzeltme:**
       sıra web ile birebir hizalandı (Arkadaşlar artık Skor Kartı'ndan
       ÖNCE), başlığın altındaki `PopupMenuDivider` kaldırıldı, Çıkış
       Yap'ın hemen üstüne YENİ bir `PopupMenuDivider` eklendi.
     - **Bug 3 — Setup'ın "Yapay Zeka ile" listesi "Devam Edenler/Son
       Oynananlar" GERÇEK bir sekme sistemi DEĞİLDİ:** Bu, Flutter port
       Setup ekranını yazarken (Parça 5c dolaylarında) BİLİNÇLİ bırakılmış
       bir eksikti — kod içi yorum bunu açıkça "web'deki alt sekmeler
       BİLİNÇLİ eksik" diye kayda geçirmişti. Kullanıcı cihaz testinde
       tam bunu buldu: "Son oynadıklarım devam eden oyunlar altında
       geliyor eski formatta, webdeki gibi Tab sistemi olması lazım."
       Web (`Setup.tsx` satır ~285-334, `localSubTab` state'i) bunu
       `LiveGamesTab`'ın (Arkadaşınla) BİREBİR AYNI çözümüyle çözüyor:
       iki buton ("Devam Edenler"/"Son Oynananlar", seçili olan accent
       dolgu), altında YALNIZCA seçili sekmenin içeriği; `mainView`
       (Yapay Zeka ile ↔ Arkadaşınla) değişince her zaman "Devam
       Edenler"e döner. Mobil portun `LiveGamesTab`'ı (`live_games_tab.
       dart`) bu deseni ZATEN taşıyordu (`_subTabBtn`, `LiveSubTab` enum) —
       Setup'a taşınmamıştı. **Düzeltme:** yeni bir `_LocalSubTab {active,
       recent}` enum'ı + `_localSubTab` state'i eklendi; `_buildCloudListView`
       artık `LiveGamesTab._subTabBtn` ile BİREBİR AYNI görsel bir buton
       çifti (`_localSubTabBtn`, bilinçli kod tekrarı — dosya başındaki
       Etki Analizi tablosuna göre) çiziyor, `switch (_localSubTab)` ile
       ya "Devam Eden Oyunlar" listesini ya `RecentGamesSection`'ı
       gösteriyor (asla ikisi birden). `_liveView`'i (OYUN TİPİ sekmesi)
       değiştiren HER yer (4 nokta: girişte otomatik geçiş, hesap
       değişiminde sıfırlama, iki elle-seçim butonu) artık `_localSubTab`ı
       da `active`'e sıfırlıyor — web'in `useEffect(() => setLocalSubTab
       ('active'), [mainView])`'ı ile aynı davranış.
     - **Bug 3'ün yan bulgusu — `RecentGamesSection` boşken/yüklenirken
       SESSİZCE gizleniyordu, artık kendi başına bir SEKME içeriği olunca
       bu boş görünürdü:** Web `RecentGamesSection.tsx`'in `emptyMessage`
       prop'u (verilmişse "Yükleniyor…"/özel boş mesajı basar, verilmezse
       eskisi gibi `null` döner) mobil portta hiç yoktu — bileşen her
       zaman `games==null||games.isEmpty` iken `SizedBox.shrink()`
       dönüyordu. Bu, listenin ALTINA sessizce eklendiği eski kullanımda
       (Setup) fark edilmiyordu, ama "Son Oynananlar" artık KENDİ BAŞINA
       bir sekme içeriği olduğundan (hem Setup'ta hem — AYNI ÖNCEDEN VAR
       OLAN gap — `LiveGamesTab`'da) boş/yükleniyor durumunda kullanıcıya
       HİÇBİR geri bildirim vermeden tamamen boş bir sekme gösterirdi.
       `RecentGamesSection`'a opsiyonel bir `emptyMessage` parametresi
       eklendi (web'le aynı sözleşme — null ise davranış TAMAMEN aynı
       kalıyor); Setup "Henüz bitmiş bir Yapay Zeka oyunun yok." geçiyor,
       `LiveGamesTab` (aynı düzeltmeyle, aynı PR'da — bu ikisi de bilinçli
       kod tekrarı çifti) "Henüz bitmiş bir Canlı oyunun yok." geçiyor.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI dosya:** (1) yeni
       `test/account_button_test.dart` — Bug 1/2 için: "Sıralama" metninin
       hiçbir yerde bulunmadığını + isim altındaki "#3 · 47 puan" satırının
       Leaderboard'u açtığını, VE madde sırasının (`tester.getTopLeft`
       y-koordinatlarıyla) web ile aynı olduğunu + tek `PopupMenuDivider`in
       Hesap Ayarları ile Çıkış Yap ARASINDA durduğunu doğruluyor.
       `account_button.dart`'taki düzeltme `git stash push -- <dosya>` ile
       geçici geri alınıp iki test de GERÇEKTEN düştüğü (biri "Sıralama"
       metnini bulamayıp `#3` metnini de bulamadığından, diğeri sıra
       kontrolünde `223.5 < 175.5` gibi ters bir eşitsizlikle) görüldü,
       `stash pop` ile geri konup yeşile döndü. (2) `test/setup_cloud_test.
       dart`'a eklenen yeni bir test — varsayılan "Devam Edenler"de devam
       eden oyunun satırı GÖRÜNÜR + "Son Oynananlar"da GÖRÜNMEZ olduğunu,
       sekmeler arası geçişte tam tersinin doğru olduğunu, VE Arkadaşınla'ya
       geçip geri dönmenin "Devam Edenler"e sıfırladığını doğruluyor.
       `setup_screen.dart` + `recent_games_section.dart`'taki düzeltme
       birlikte geçici geri alınınca test GERÇEKTEN derleme hatasıyla
       düştü (`emptyMessage` parametresi yok — güçlü/belirsizliksiz bir
       başarısızlık), geri konup yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, tam takım **270/270 yeşil**
       (267'den +3 — Parça 28'in üç yeni regresyon testi). `kelimeki_core`'a
       hiç dokunulmadı.
     - **Doğrulama sınırı — DB tarafı ayrıca doğrulandı, UI cihazda
       bekleniyor:** Aynı cihaz testinde kullanıcının bildirdiği "pazarlama
       onayı DB'ye gerçekten yazıldı mı?" sorusu Supabase MCP ile canlı
       sorgulanıp doğrulandı (`profiles.marketing_consent=true`,
       `marketing_consent_at` sunucu tetikleyicisiyle dolu) — bu bir kod
       hatası DEĞİLDİ, zaten doğru çalışıyordu. Yukarıdaki üç UI
       düzeltmesinin GERÇEK cihazdaki son görsel teyidi (menü düzeni,
       k-lig satırının gerçek rank/puanla göründüğü, sekmelerin dokunmatik
       ekranda beklendiği gibi tepki verdiği) kullanıcının bir sonraki
       test turunda bekleniyor.
     - **Bilinçli olarak DOKUNULMAYAN iki bulgu — bunlar kod hatası
       DEĞİL:** (1) **Profil fotoğrafı 2 MB sınırı** (`account_settings_
       modal.dart`, Hesap Ayarları) — kullanıcı 2 MB altı bir fotoğraf
       bulmakta zorlandığını bildirdi, ama bu sınır `src/lib/api.ts`'teki
       `MAX_AVATAR_BYTES`/web `AccountSettingsModal.tsx` ile BİREBİR AYNI
       (`2 * 1024 * 1024`) — mobile'a özgü bir hata değil, iki platformun
       da paylaştığı bilinçli bir kısıt (muhtemelen Supabase Storage
       bucket politikasıyla da uyumlu); değiştirilecekse bu bir ürün
       kararı, tek başına mobil tarafta sessizce büyütülmedi. (2)
       **Şifre sıfırlama derin bağlantısı (`kelimeki://reset`) GitHub
       Pages web test ortamından tetiklenemedi** — kullanıcı e-postadaki
       bağlantıya dokununca "Safari cannot open the page because the
       address is invalid" gördü (madde 9-10), süresi geçmiş bağlantıda
       ise sessizce web'in kendi (kelimeki.com) fallback'ine düştü (madde
       11, aslında BEKLENEN web davranışı — mobil uygulamanın DEĞİL). Bu,
       bu test ortamının yapısal bir sınırı: `kelimeki://` özel URL
       şeması yalnızca GERÇEK kurulu bir native uygulama (TestFlight ya
       da Appetize.io'ya yüklenmiş bir `.ipa`/`.apk`) varken işletim
       sistemi tarafından yakalanabilir — düz bir web sayfası (GitHub
       Pages) bunu asla intercept edemez, kod tarafında düzeltilecek bir
       şey yok. Madde 9-12'nin deep-link kısımları FAZ B'ye (TestFlight/
       Appetize) ertelendi — kök CLAUDE.md'nin baştan beri planladığı
       "Bölüm 2 (Hesap/auth, excluding deep-link items)" ayrımı tam bu
       yüzdendi.
   - ✅ **Parça 29 — Bölüm 3 (Bulut kayıtları) cihaz testinde bulunan iki
     GERÇEK hata + bir üçüncüsünün araştırılıp KOD HATASI OLMADIĞININ
     kanıtlanması (9 Ağustos 2026, `account_button.dart`,
     `setup_screen.dart`):** Kullanıcı bulut kayıtlarının (mobil↔web
     senkron) 6/6 çalıştığını doğruladıktan sonra üç ekran görüntüsüyle
     bildirdi: "Menu items have bigger spacing... menü daha büyük...
     setup page seems to be wider... robot avatarları aynı değil."
     - **Bug 1 — hesap menüsü satırları/genişliği web'den GÖZLE GÖRÜLÜR
       büyüktü:** Kök sebep `PopupMenuItem`'ın Flutter varsayılanları —
       `height` (kaldırma dokunma hedefi için `kMinInteractiveDimension`,
       48px) HER satıra ZORUNLU bir minimum yükseklik dayatıyor, `padding`
       varsayılanı da yatayda 16px. Web'in gerçek satır boyu (`px-3
       py-2.5` = 12/10px dolgu + 12px punto) bunların ikisinden de
       belirgin küçük — fark ekran görüntülerinde satırlar arası boşluğun
       ve menü genişliğinin büyümesi olarak görünüyordu. **Düzeltme:** her
       `PopupMenuItem`e `height: 0` (varsayılan minimumu KALDIRIR, satır
       kendi içeriğine göre boyutlanır) + `padding: EdgeInsets.symmetric
       (horizontal: 12, vertical: 10)` (web `px-3 py-2.5`) eklendi; her
       satırın `child`'ı `SizedBox(width: 200)` (224 web `w-56` sabiti
       eksi 2×12 dolgu) içine sarılarak menünün TOPLAM genişliği de
       web'in `w-56`sına yakınsatıldı (Flutter'da `PopupMenuButton`'ın
       doğrudan bir "menü genişliği" API'si yok — genişlik en geniş
       satırın intrinsic genişliğine göre hesaplanıyor, bu yüzden her
       satırın içerik genişliğini elle sabitlemek gerekiyor).
     - **Bug 2 — Setup ekranı web'den daha geniş sınırlanıyordu:**
       `ConstrainedBox(maxWidth: 480)` kullanılıyordu; web kaynağı
       (`Setup.tsx` satır ~536) `max-w-[460px]` — **GameHeader/Board'un
       kullandığı 680'le KARIŞTIRILMAMALI**, Setup kendi (daha dar) sabitini
       taşıyor. 480→460 tek satırlık bir düzeltme.
     - **Bug 3 olarak bildirilen ("robot avatarları aynı değil") aslında
       KOD HATASI DEĞİL — CanvasKit'in web-özel emoji render sınırlaması,
       ölçülerek kanıtlandı:** Önce kaynak karşılaştırması yapıldı: mobil
       `player_avatar_row.dart`'taki robot avatarı (zemin `#E8EBEF`
       [web `bg-void`], kenarlık `#DCE2EA` [web `border-border`], `🤖`
       Unicode karakteri, punto `(size*0.55).round()`) web `PlayerAvatarRow.
       tsx`'in DEĞERLERİYLE BİREBİR AYNIYDI — kodda düzeltilecek bir şey
       yoktu. Bu proje daha önce (Parça 18, Parça 27) "değerler doğru
       görünüyor, o hâlde CanvasKit'e özgü bir render hatası olabilir"
       varsayımını KANITLAMADAN kabul etmemeyi öğrenmişti — bu sefer de
       aynı disiplinle, minik bir `flutter build web` harness'i (yalnızca
       `PlayerAvatarRow`'u render eden) derlenip Playwright/Chromium'da
       (gerçek CanvasKit) açıldı. Sonuç KESİN: robot emoji'nin bulunduğu
       yerde TAMAMEN BOŞ (rengi olmayan, çerçevesi olmayan, hiçbir glyph
       içermeyen düz `_void` renkli bir daire) render oluyordu — ne
       gerçek emoji ne bir yedek karakter. Ağ trafiği incelenince kök
       sebep netleşti: Flutter Web/CanvasKit, renkli emoji çizebilmek için
       çalışma anında `fonts.gstatic.com`'dan bir "Noto Color Emoji" web
       fontu ÇEKMEK ZORUNDA (yerleşik bir renkli-emoji fontu bundle
       etmiyor) — bu istek BU test ortamının proxy'sinde (agent sandbox)
       engelli olduğundan tamamen başarısız oluyor ve CanvasKit hiçbir
       yedek glyph'e bile düşmeden boş bırakıyor. **Gerçek native
       (iOS/Android) build bu sorunu hiç YAŞAMAZ** — Skia/Impeller doğrudan
       işletim sisteminin KENDİ kurulu emoji fontuna (Apple Color Emoji/
       Noto Color Emoji) erişir, ağ isteğine hiç ihtiyaç duymaz; kullanıcının
       gerçek iPad'inde Safari üzerinden test ettiği GitHub Pages derlemesi
       de teknik olarak CanvasKit kullandığından (bkz. "Web Derlemesi —
       ÜRÜN DEĞİL, TEST ORTAMI" bölümü) AYNI ağ-bağımlı davranışı taşıyor —
       kullanıcının cihazında Google Fonts'a erişim yavaş/kesintili/
       engellenmiş olursa (kurumsal ağ, gizlilik uzantısı, ITP vb.) aynı
       boş daire onda da görünebilir; bu senaryoda dahi kök neden koddaki
       bir hata değil, web test derlemesinin CanvasKit'in emoji stratejisine
       olan bu bağımlılığıdır. **Bilinçli olarak DOKUNULMADI** — kod zaten
       web'le birebir aynı değerleri taşıyor, "düzeltilecek" bir şey yok;
       gerçek/kesin doğrulama TestFlight/Appetize'daki native build'de
       yapılmalı (orada bu risk yapısal olarak mevcut değil).
     - **Test — negatif eş doğrulamasıyla:** Bug 1/2 için `account_button_
       test.dart`'a satır-aralığı (`<44px`, eski varsayılan 48px'e karşı) +
       satır-içerik-genişliği (`≈200px`) doğrulayan yeni bir test,
       `setup_screen_test.dart`'a da geniş bir viewport'ta `ConstrainedBox
       (maxWidth:460)` bulunduğunu VE eski `480`in hiç kalmadığını
       doğrulayan yeni bir test eklendi. İki dosyadaki düzeltme birlikte
       geçici geri alınınca İKİ test de GERÇEKTEN düştü (satır aralığı
       tam olarak eski varsayılan `48.0` ölçüldü, `ConstrainedBox(460)`
       hiç bulunamadı) — `stash pop` ile geri konup yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, tam takım **272/272 yeşil**
       (270'ten +2 — Parça 29'un iki yeni regresyon testi). Bug 3'ün
       araştırması İÇİN kullanılan `avatar_probe_harness.dart` (ve
       `build/webprobe`) TEŞHİS SONRASI silindi, kalıcı bir dosya değil.
     - **Ders — "kod web'le birebir aynı" bir bulgu, "o zaman görsel fark
       yanılsama" anlamına GELMEZ:** Bu proje daha önce hep "koddaki
       değerler doğru → CanvasKit'e özgü bir motor hatası olabilir, ÖLÇ"
       dersini işlemişti (Parça 18/27); Bug 3 aynı dersi bir adım daha
       ileri taşıyor — bazen "motor hatası" bile değil, motorun (CanvasKit)
       web'e özgü bir MİMARİ KARARININ (emoji'yi ağdan çekme) test
       ortamının ağ politikasıyla çakışmasıdır. İkisi de aynı sonuca
       varıyor: koda dokunmadan önce ölç, "değerler doğru" bulgusunu asla
       "görsel fark de yoktur" diye genişletme.
   - ✅ **Parça 30 — Parça 29'un ardından hesap menüsü hâlâ web'den boşluklu
     duruyordu + isim başlığının altındaki çizgi hâlâ hiç yoktu (9 Ağustos
     2026, `account_button.dart`):** Kullanıcı testine paralel olarak
     ("Ben testleri yaparken sen de...") istenen doğrudan bir düzeltme.
     Parça 29'un `height:0`/`padding`/`SizedBox(width:200)` müdahalesi satır
     boyunu Flutter'ın 48px varsayılanından kurtarmıştı ama iki AYRI kök
     sebep daha kalıyordu — ikisi de ÖLÇÜLEREK bulundu (`flutter test`te
     gerçek `Size`/`getTopLeft` okundu, tahminle değil):
     1. **"Nasıl Oynanır?"/"Hesap Ayarları" satırları 200px'e SIĞMAYIP İKİ
        SATIRA sarabiliyordu** (bir ölçümde 200×34, diğerlerinde 200×17) —
        kök sebep emoji glyph'lerinin (❓/⚙️/👥/📊/🚪) `itemStyle`'da
        `fontFamilyFallback` OLMADAN SpaceMono'dan yedek bir fonta
        düşmesi; help_modal.dart/player_avatar_row.dart'taki aynı ders
        buraya hiç taşınmamıştı. Web'de bu metinler asla sarmıyor (sabit,
        kısa etiketler) — `itemStyle`'a `fontFamilyFallback: ['Noto Color
        Emoji', 'Apple Color Emoji']` eklendi ve her etiket ortak bir
        `_menuLabel()` yardımcısıyla `maxLines:1, softWrap:false,
        overflow:TextOverflow.visible`'a bağlandı, satır ne olursa olsun
        KOŞULSUZ tek satırda kalıyor. **Dürüstlük notu:** bu wrap, gerçek
        fontlar yüklenmiş `flutter test`te KARARSIZ/tekrarlanamaz çıktı
        (bazı çalıştırmalarda 34px, bazılarında 17px — muhtemelen test
        sürecinin font-fallback çözümleme sırasına bağlı bir durum), yani
        bu düzeltme negatif-eş ile bu ortamda KANITLANAMADI; yine de
        `maxLines:1` + `fontFamilyFallback` kod olarak zararsız, web
        paritesine daha yakın ve mevcut 3 kullanım (help_modal/
        player_avatar_row/k-lig) ile tutarlı olduğundan tutuldu — gerçek
        CanvasKit'te (kullanıcının GitHub Pages derlemesi) satır genişliği
        emoji yedek fontunun ağdan (Google Fonts) çekilip çekilemediğine
        bağlı olabileceğinden (bkz. Parça 29'daki aynı ağ-bağımlılığı
        dersi) bu, tam da o riski önceden kapatan bir güvenlik önlemi.
     2. **İki çizgi de `PopupMenuDivider()`nin 16px'lik AYRI bir satır
        eklediği varsayımıyla yanlış modellenmişti — GERÇEK KÖK SEBEP,
        ölçülerek doğrulandı:** Web'in hem başlığın altındaki
        (`border-b border-border`, Parça 28'de hiç taşınmamıştı — kullanıcı
        bu turda "arkadaşlar üzerinde ince bir çizgi olmalı" diye bildirdi)
        hem Çıkış Yap'ın üstündeki (`border-t border-border`) çizgisi,
        düğmenin KENDİ kenarına oturan 1px'lik bir çizgi — CSS border-box
        modelinde ekstra bir satır/boşluk EKLEMİYOR. `PopupMenuDivider`
        (Flutter'ın kendi `_kMenuDividerHeight=16.0` sabiti) ise TAM
        BÖYLE bir ek satır davranışı sergiliyor. İkisi de
        `PopupMenuDivider` yerine `Container(decoration:
        BoxDecoration(border: Border(top/bottom: BorderSide(color:
        _border, width: 1))))`'a çevrildi — `padding` `PopupMenuItem`dan
        bu `Container`'a taşınarak çizginin menünün TAM genişliğinde
        (224px, `_menuItemWidth + 24`) kenardan kenara çizilmesi sağlandı
        (web'in `w-56` kartı gibi).
     3. **ÜÇÜNCÜ, ayrı bir kök sebep — menünün kendi `menuPadding`
        varsayılanı (8px dikey) web'in kartında hiç yok:** `PopupMenuButton`
        varsayılan olarak `EdgeInsets.symmetric(vertical: 8)` ekliyor
        (`_PopupMenuDefaultsM2/M3.menuPadding`) — kartın en üstünde
        (başlığın ÜSTÜNDE) ve en altında (Çıkış Yap'ın ALTINDA) web'de
        hiç karşılığı olmayan, görünmez 8+8=16px'lik bir boşluk. `
        menuPadding: EdgeInsets.zero` eklendi — ölçülen fark
        (üst: header top - card top) 20px'ten (8+12 başlık dolgusu) 12px'e
        (yalnızca başlığın kendi py-3'ü) düştü; benzer şekilde alt kenar
        18'den 10'a düştü.
     - **Test — negatif eş doğrulamasıyla, ÜÇ AYRI kanıt (2/3'ü GERÇEKTEN
       düşürülüp geri konarak doğrulandı, 1/3'ü — emoji wrap — bu ortamda
       kararsız çıktığından dürüstçe "kanıtlanamadı" olarak işaretlendi):**
       `account_button_test.dart`'a üç yeni test eklendi (tüm satırlar tek
       satırda + tutarlı aralık; `PopupMenuDivider` hiç yok + her iki
       Container'ın border'ı doğru kenarda + Hesap Ayarları↔Çıkış Yap
       aralığı hâlâ normal satır aralığında; kart üst/alt kenarının
       başlık/signout içeriğine olan mesafesi ~12/~10px). `menuPadding:
       EdgeInsets.zero` satırı geçici olarak yorumlanıp test koşuldu —
       GERÇEKTEN `Expected: closeTo(12,2) Actual:<20.0>` ile düştü, satır
       geri konup yeşile döndü. `PopupMenuDivider` kaldırma değişikliği de
       aynı şekilde eski (Parça 28) test dosyasının `find.byType
       (PopupMenuDivider)` beklentisini kırdığından (artık böyle bir
       widget yok), o eski test madde SIRASINI doğrulayacak şekilde
       güncellendi — çizginin varlığı artık yeni Parça 30 testlerinin işi.
     - Doğrulama: `flutter analyze` temiz, **tam takım 275/275 yeşil**
       (272'den +3 — bu parçanın üç yeni testi). `kelimeki_core`'a hiç
       dokunulmadı.
     - **Doğrulama sınırı:** gerçek CanvasKit'te (kullanıcının GitHub
       Pages derlemesi) satır sarma riskinin gerçekten var olup olmadığı
       bu oturumda KANITLANAMADI (native VM/Skia'da tekrarlanamadı, madde
       1'e bkz.) — `fontFamilyFallback`/`maxLines:1` önlemi buna rağmen
       tutuldu (zararsız + web paritesine yakın). Çizgi/dolgu
       düzeltmelerinin (madde 2-3) gerçek cihazda/web derlemesinde görsel
       teyidi kullanıcının bir sonraki test turunda bekleniyor.
   - ✅ **Parça 31 — k-lig sıralaması kısa listede otomatik tamamlanmıyordu +
     k-lig "?" bilgi rozeti/mavi rengi ScoreCard/PlayerScoreCard'da eksikti
     (9 Ağustos 2026, `leaderboard_modal.dart`, `score_card_modal.dart`,
     `player_score_card_modal.dart`, `klig_mark.dart`):** Kullanıcı iki
     ekran görüntüsüyle (mobil vs kelimeki.com, aynı hesap) bildirdi: k-lig
     listesi web'de (13 kayıtlı kullanıcı) tam liste + gerçek isimlerle
     açılırken mobilde ilk 10 + jenerik "Sen" satırıyla ("SENİN SIRAN"
     kısayolu) takılı kalıyordu; ayrıca mobildeki mavi "k-lig" yazısının
     yanında web'deki gibi bir "?" rozeti yoktu.
     1. **Kök sebep — web'in `IntersectionObserver`ı GÖRÜNÜRLÜĞE tepki
        veriyor, Flutter'ın `ScrollController.addListener`ı yalnızca
        POZİSYON DEĞİŞİMİNE:** Web'de sonraki sayfa, sentinel elemanı
        görünür alana GİRDİĞİNDE yükleniyor — liste zaten kısaysa (13
        satır, `max-h-[50vh]`e sığıyor) sentinel açılışta ZATEN görünür
        olduğundan hiç kaydırmaya gerek kalmadan ANINDA tetikleniyor.
        Mobil port `ScrollController.addListener`ı kaydırma POZİSYONU
        değiştiğinde çalışıyordu — içerik zaten sığıp `maxScrollExtent==0`
        kaldığında (kaydırılacak hiçbir şey olmadığından) bu listener HİÇ
        ateşlenmiyor, ikinci sayfa asla otomatik istenmiyordu. Düzeltme:
        her sayfa yüklemesinden SONRA (post-frame) `maxScrollExtent<=0 &&
        hasMore` kontrolü — doğruysa bir sonraki sayfa hemen istenip
        `hasMore` tükenene ya da liste gerçekten kaydırılabilir olana
        kadar zincirleniyor (`_maybeAutoLoadIfNotScrollable`).
     2. **k-lig "?" bilgi rozeti hiç port edilmemişti:** web `ScoreCard.tsx`/
        `PlayerScoreCard.tsx`nin ikisi de KLigMark'ın yanında küçük
        dairesel bir "?" rozeti taşıyor (`w-3.5 h-3.5 rounded-full border
        border-muted`) — `UserMenu`/`Leaderboard` başlığında YOK (üçü de
        ayrı ayrı kontrol edildi, "hepsine ekle" varsayımıyla
        genelleştirilmedi). Ortak `KLigInfoBadge` widget'ı (`klig_mark.dart`)
        eklenip her iki kartın k-lig satırına eklendi.
     3. **Yan bulgu, kod okurken bulundu (kullanıcının "mavi" tabiri
        doğrulanınca fark edildi) — KLigMark'ın rengi web'de `text-muted`
        DIŞ div'inden MİRAS ALINMIYOR:** web `KLigMark.tsx`'in `color`
        prop'u `KLIG_COLOR` (mavi `#2563EB`) varsayılanı taşıyor ve SVG'ye
        doğrudan React prop'u olarak geçiyor — kapsayan `text-muted` CSS
        class'ı yalnızca `currentColor` kullanan elemanları (düz metin,
        "?" rozetinin border/text'i) etkiler, KLigMark'ın SVG fill'ini
        ETKİLEMEZ. Mobil `score_card_modal.dart` bunu yanlış okuyup
        `KLigMark(color: _muted)` geçiyordu (Parça 4'ten kalma, bu oturumda
        bulundu) — logo griydi, web'de her zaman mavi. Kaldırıldı (varsayılan
        mavi); yeni eklenen `player_score_card_modal.dart`'ın satırı da
        BAŞTAN doğru (renksiz/varsayılan) yazıldı.
     4. **`PlayerScoreCardModal`e (başkasının kartı) k-lig satırının
        TAMAMI eklendi — yalnızca "?" değil:** kod okunurken dosyanın
        kendi üst yorumu ("k-lig satırına dokununca açılır") ile GERÇEK
        kodun çelişkisi bulundu — satır hiç yoktu. Web `PlayerScoreCard.tsx`
        birebir taşındı: `stats.myRank(userId)` ile o oyuncunun sırası +
        KLigMark+"?"+"#sıra · puan puan", dokununca `showLeaderboard` açar.
        `showLeaderboard`'ın gerektirdiği `AuthService` `PlayerScoreCardModal`e
        OPSİYONEL yeni bir `auth` parametresi olarak eklendi (`friends`/
        `games` ile aynı "yoksa ilgili özellik sessizce eksik kalır" deseni)
        ve dört çağrı yerine (`friends_modal.dart`, `leaderboard_modal.dart`
        ×2, `online_game_screen.dart`) trivially thread edildi —
        `game_history_modal.dart`'ın çağrı yeri BİLİNÇLİ atlandı (o dosyada
        hiç `AuthService` yok, threading çok daha büyük bir refactor
        gerektirirdi); orada k-lig satırı hâlâ görünür (bilgi kaybı yok)
        ama dokunuşu no-op kalır — "çalışmayan kontrol koymuyoruz" ilkesiyle
        BİLE tutarlı, çünkü satırın kendisi (rank/puan bilgisi) her zaman
        faydalı, yalnızca AKSİYONU (k-lig açma) auth olmadan mümkün değil.
     - **Test — negatif eş doğrulamasıyla, ÜÇ AYRI kanıt:** (1)
       `score_card_test.dart`'a yeni bir test — 12 satırlık kısa bir liste,
       uzun bir viewport'ta (kaydırmaya HİÇ gerek kalmadan) açılınca ikinci
       sayfanın kendiliğinden istendiğini, "SENİN SIRAN"/"Sen" hiç
       görünmediğini, kullanıcının gerçek adıyla listede olduğunu
       doğruluyor — `_maybeAutoLoadIfNotScrollable()` çağrıları geçici
       yorum satırına alınıp test GERÇEKTEN `Expected:<2> Actual:<1>` ile
       düştü, geri konup yeşile döndü. (2) `PlayerScoreCardModal`e yeni bir
       test — k-lig satırı + "?" rozeti + rank/puan + dokununca Leaderboard
       açılması; `auth` parametresi TAMAMEN kaldırılınca (4 çağrı yeri +
       widget alanı) test paketi DERLEME HATASIYLA düştü (`No named
       parameter with the name 'auth'`) — bu da geçerli bir negatif eş
       kanıtı, geri konup 11/11 yeşile döndü. (3) İki karta da `KLigMark`
       widget'ının `color` alanının `null` (yani varsayılan mavi) olduğunu
       doğrulayan assertion eklendi; `score_card_modal.dart`'ta geçici
       olarak `color: _muted` geri konunca test GERÇEKTEN `Expected: null
       Actual: Color(...muted...)` ile düştü, kaldırılıp yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 277/277 yeşil**
       (275'ten +2 — bu parçanın iki yeni testi; mevcut testlere eklenen
       assertion'lar ayrı test SAYILMIYOR). `kelimeki_core`'a hiç
       dokunulmadı.
     - **Doğrulama sınırı:** gerçek `leaderboard`/`myLeaderboardRank`
       RPC'leri, gerçek CanvasKit'te (kullanıcının GitHub Pages derlemesi)
       sentinel-görünürlük davranışı ve `game_history_modal.dart`'tan
       açılan bir oyuncu kartında k-lig satırının (auth'suz, bilgi-amaçlı)
       göründüğü ama tıklanamadığı davranışı cihazda/web derlemesinde
       teyit edilmeli.
   - ✅ **Parça 32 — arkadaş ekle onay diyaloğu geniş ekranda taşıyordu +
     işlem sonrası sonuç mesajı hiç çıkmıyordu (9 Ağustos 2026,
     `friends_modal.dart`, `player_score_card_modal.dart`):** Kullanıcı üç
     ekran görüntüsüyle (mobil skor kartları + web'in "+" simgesi) bildirdi:
     "Arkadaş istediği göndermek için bastığımda uyarı ekranı upuzun
     geliyor... göndere basınca gönderilmiştir vb uyarısı çıkmıyor." Ayrıca
     mobildeki (`Icons.person_add_alt_1`) arkadaş-ekle simgesinin web'in düz
     "+" karakterinden daha iyi göründüğünü belirtip web tarafında da
     uygulanmasını istedi — bu üçüncü madde KOD DEĞİŞİKLİĞİ olarak değil,
     kök `CLAUDE.md`'nin yeni "Web'de Yapılacak İşler" bekleme listesine
     bir madde olarak eklendi (web'e dokunulmadı, yalnızca not düşüldü).
     1. **Kök sebep — Flutter `Dialog`ın varsayılan üst genişlik sınırı
        YOK:** `dialog.dart` kaynağı doğrulandı —
        `constraints ?? dialogTheme.constraints ?? const
        BoxConstraints(minWidth: 280.0)` — yalnızca ALT sınır var, üst
        sınır yok. `confirmFriendAction`/`showFriendInfoDialog`
        (`friends_modal.dart`) bunu hiç geçmiyordu; geniş bir ekranda
        (iPad) `insetPadding`in bıraktığı TÜM alana yayılıyordu. Web'in
        kaynağı (`FriendsModal.tsx`'teki `ConfirmDialog`) `max-w-sm`
        (384px) kullanıyor — ikisine de `constraints: BoxConstraints
        (maxWidth: 384)` eklendi.
     2. **Kök sebep — web'in `handleFriendAction`i HER dört dalda da bir
        `resultMsg` gösteriyor, mobil portun `_onRelationTap`ı (Parça 4'ten
        kalma) HİÇBİRİNDE göstermiyordu:** `PlayerScoreCard.tsx` kaynağı
        okunup dört dalın metni birebir taşındı — accepted→remove:
        "Arkadaşlıktan çıkarıldı.", pendingOutgoing→cancel: "Arkadaşlık
        isteği iptal edildi.", pendingIncoming→accept: "Arkadaş oldunuz.",
        null→send: "Arkadaşlık isteğiniz iletilmiştir." (mobilin kendi
        eklediği, web'de karşılığı olmayan "$name ile artık arkadaşsınız."
        özel mesajı — karşılıklı anlık kabul durumu için — BİLİNÇLİ
        KORUNDU, yalnızca normal/tekil gönderim dalına eksik olan web
        mesajı eklendi). Hepsi zaten var olan `showFriendInfoDialog`
        (web `InfoDialog`) ile gösteriliyor, yeni bir widget gerekmedi.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** `friends_test.dart`'a
       (a) mevcut "arkadaşsa yeşil işaret" testine "Arkadaşlıktan
       çıkarıldı." sonuç mesajı assertion'ı eklendi, (b) yeni bir test —
       geniş (1200px) bir viewport'ta onay diyaloğunun kendi
       `constraints.maxWidth`inin (384) VE gerçek render boyutunun ≤384
       kaldığını, gönderince "Arkadaşlık isteğiniz iletilmiştir." çıktığını
       doğruluyor. `constraints: BoxConstraints(maxWidth: 384)` satırları
       geçici yorum satırına alınıp test koşuldu — GERÇEKTEN
       `Expected:<384> Actual:<1200.0>` ile düştü; ayrı bir turda
       `player_score_card_modal.dart`'taki dört `showFriendInfoDialog`
       çağrısı da geçici geri alınıp İKİ test de GERÇEKTEN `Found 0
       widgets with text "Arkadaşlıktan çıkarıldı."`/`"...iletilmiştir."`
       ile düştü — ikisi de geri konup yeşile döndü.
       **Ölçüm dersi:** `tester.getSize(find.byType(Dialog))` yanıltıcı —
       `Dialog`'un kendi build'i `Align -> ConstrainedBox(constraints) ->
       Material` şeklinde, yani `Dialog` widget'ının RENDER boyutu
       `Align`in kapladığı TÜM alan (ekran − insetPadding), İÇERİDEKİ
       kartın değil; genişlik testi bu yüzden widget'ın `constraints`
       ALANINI okuyarak + içteki `ConstrainedBox`ı ayrıca bularak yapıldı.
     - Doğrulama: `flutter analyze` temiz, **tam takım 278/278 yeşil**
       (277'den +1 — bu parçanın bir yeni testi; mevcut teste eklenen
       assertion ayrı test SAYILMIYOR). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** gerçek cihazda/web derlemesinde diyalog
       genişliğinin ve dört sonuç mesajının görsel teyidi kullanıcının bir
       sonraki test turunda bekleniyor.
   - ✅ **Parça 33 — Skor Kartı "mobilde scroll gerekiyor" şikayeti:
     ŞİKAYETİN KENDİSİ web-test-derlemesi artefaktı çıktı, ama araştırma
     İKİ gerçek parite hatası buldu (9 Ağustos 2026,
     `score_stats_section.dart`):** Kullanıcı AYNI hesabın (Ironman)
     kelimeki.com ve `alpcapa.github.io` ekran görüntülerini yan yana
     koyup web'de kartın tamamının sığdığını, mobilde kaydırmak
     gerektiğini bildirdi.
     - **Bu sefer ölçüm İKİ TARAFTA DA gerçek kodla yapıldı** (Parça
       18/27/29'un "ölçmeden teşhis koyma" dersinin doğal devamı; yeni
       olan: web tarafı da artık ELLE HESAPLANMIYOR). `npm install` +
       `npm run build` ile web'in DERLENMİŞ Tailwind CSS'i üretilip
       (`dist/assets/index-*.css`), `ScoreCard.tsx`/`ScoreStatsSection.tsx`/
       `Modal.tsx`'in DOM'u birebir kopyalanan geçici bir HTML'e konup
       yerel Chromium'da (Playwright) `getBoundingClientRect` ile ölçüldü;
       mobil taraf `flutter test` içinde `tester.getSize` ile. **İlk elle
       hesabım yanlıştı** (oyun kutularını 68px sandım, gerçek 80 — dar
       sütunda etiket iki satıra sarıyor); derlenmiş CSS ölçümü bunu
       düzeltti. **Ders: web'in "beklenen" ölçüsünü Tailwind sınıflarından
       ZİHNEN türetme — `npm run build` + Chromium ile ölç, bu ortamda
       yapılabiliyor.**
     - **Ölçüm sonucu — içerik paritesi ZATEN İYİYDİ:** düzeltmelerden
       sonra web modal içeriği **655** logical px, mobil **633** — mobil
       hatta 22px daha kompakt. Yani kaydırmanın sebebi içerik yüksekliği
       DEĞİL, **üst sınır**: web `max-h-[85vh]`, mobil
       `MediaQuery.height × 0.85`. iOS Safari'de `vh` GÖRÜNÜR viewport'tan
       BÜYÜK (tarayıcı kromunun kapladığı alanı saymaz), Flutter'ın
       MediaQuery'si ise web derlemesinde yalnızca görünür canvas'ı görür
       (kromun yediği ~140 logical px hariç). **Kullanıcının kendi ekran
       görüntüsü bunu kanıtlıyor:** web modalı görünür sayfa alanının
       %93'ünü kaplıyor — %85 sınırı görünür viewport'a göre olsaydı bu
       İMKÂNSIZ olurdu. Gerçek native derlemede MediaQuery = tam ekran
       olduğundan (iPad yatay ≈ 838 logical → 0.85×838 = 712 > 633) bu
       şikayet **cihazda tekrarlamaz**; `0.85` çarpanı web'in `85vh`inin
       doğru portu, değiştirilMEDİ.
     - **Bulunan gerçek hata 1 — oran parantezleri hiç port edilmemiş:**
       web `ScoreStatsSection.tsx` parantezleri RENDER'da ekliyor
       (`({c.rate})`), `pct()` yalnızca `"%83"` döndürüyor. Port `pct`'yi
       birebir taşımış ama sarmalamayı atlamış → mobil `%83`, web `(%83)`
       gösteriyordu (kullanıcının ekran görüntülerinde de görünüyor).
       `_CellBox` artık `'(${cell.rate!})'` basıyor.
     - **Bulunan gerçek hata 2 — sekme çubuğu 53px, web 44px:** iki ayrı
       sapma üst üste binmiş: (a) etiket `fontSize: 13` iken web `text-sm`
       = **14px**; (b) web'in `leading-none`u (line-height 1) hiç
       taşınmamış, Flutter fontun DOĞAL satır yüksekliğini (~1.3×)
       kullanıyordu. `fontSize: 14` + `height: 1` (iki satırda da) ile
       ölçülen değer **tam 44.0** oldu — web'le birebir.
     - **Test kurgusu dersi — üretimin KISITINI taklit et:** ilk regresyon
       testi çubuğu `Center`/`SizedBox` altına koydu ve 44 yerine **900**
       ölçtü. Sebep widget'ta değil kurguda: sekme butonunun iç `Column`u
       `MainAxisSize.max` ve SINIRLI bir yükseklik verilirse tüm alanı
       kaplıyor. Üretimde çubuk `SingleChildScrollView`ın `Column`unda
       yaşar → SINIRSIZ yükseklik → doğal boyuna sığar. Test artık aynı
       şekli (`SizedBox` → `Column(mainAxisSize.min)`) kuruyor. **Bir
       "yanlış" ölçüm çıktığında önce testin kısıt zincirini üretimle
       karşılaştır** — widget'ı düzeltmeye kalkmak burada yanlış olurdu.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:**
       `score_card_test.dart`'ın mevcut testi `(%70)`/`(%75)` bekleyecek
       şekilde güncellendi (+ `%70`'in artık BULUNMADIĞI assertion'ı), ve
       çubuk yüksekliğini 44.0'a sabitleyen yeni bir test eklendi.
       Parantez düzeltmesi geçici geri alınınca test GERÇEKTEN `Found 0
       widgets with text "(%70)"` ile, font/height düzeltmesi geri
       alınınca `Expected: <44.0> Actual: <53.0>` ile düştü; ikisi de
       geri konup yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 279/279 yeşil**
       (278'den +1). `kelimeki_core`'a hiç dokunulmadı; `mobile/` DIŞINDA
       hiçbir dosya değişmedi (ölçüm için üretilen `dist/`, geçici HTML ve
       geçici ölçüm testleri silindi).
     - **Doğrulama sınırı:** parantezlerin ve sekme çubuğunun görsel
       teyidi cihazda/web derlemesinde kullanıcıdan bekleniyor.
     - **Ek (aynı gün, kullanıcı düzeltmelerden sonra kartın HÂLÂ kesik
       geldiğini bildirince):** "native'de sığar" iddiası artık bir
       hesap değil KALICI BİR TEST — `score_card_test.dart`'a en uzun
       gerçek içerikle (3 haneli rakamlar + 8 harfli kelime) iki gerçek
       cihaz boyutunda kartın %85 sınırına HİÇ dayanmadığını doğrulayan
       bir test eklendi. Ölçülen: iPhone 14 (390×844) kart **633** /
       sınır **717** → sığıyor; iPad portre (834×1194) 633 / **1015** →
       sığıyor; web test derlemesinin iPad yatay canvas'ı (≈1194×700)
       ise 595 / **595** → tam sınıra dayanıyor, kaydırma gerekiyor.
       Yani fark tek bir yerden geliyor: tarayıcı kromu Flutter canvas'ını
       ~145 logical px kısaltıyor, CSS `vh` ise kısaltmıyor. Bu test aynı
       zamanda ileride içerik büyürse (yeni bir istatistik kutusu vb.)
       gerçek cihazda kaydırmaya düşüldüğünü yakalayan bir regresyon
       koruması.
   - ✅ **Parça 34 — fotoğraflı avatarın çerçeve halkası BOZUKTU; "artefakt"
     diye İKİ KEZ kapattığım gerçek bir hataydı (9 Ağustos 2026,
     `k_avatar.dart`):** Kullanıcı önce "mobilde avatar tam yuvarlak
     durmuyor, üst/alt/sağ/sol kenarları düz" dedi; ben ölçmeden "ekran
     görüntüsü artefaktı" deyip kapattım. Israr edip "içindeki resim
     yuvarlağı doldurmuyor, ince boşluklar var" deyince bu kez "o normal
     1px çerçeve" deyip yine kapattım — **her ikisi de yanlıştı.**
     - **Kök sebep (gerçek widget ölçülerek bulundu):** `Container`ın
       `clipBehavior: Clip.antiAlias` + `shape: BoxShape.circle` kırpması
       DIŞ daireye (çap `size`) göre yapılıyor; ama `BoxDecoration.border`
       çocuğu kenarlık kadar içeri ittiğinden çocuk `size − 2` kenarlı bir
       KARE oluyordu. Kare, halkayı (yarıçap `size/2 − 1` … `size/2`)
       KÖŞEGENLERDE aşıp üzerine boyuyor (decoration çocuktan ÖNCE
       çizilir), yalnızca N/S/E/W'de halka görünür kalıyordu. Sonuç: dört
       noktada gri "düz kenar", aralarda hiç çerçeve olmayan bozuk bir
       halka — tam da kullanıcının tarif ettiği görüntü. Web'de
       (`<img className="rounded-full ... border border-border">`) CSS
       `border-radius` BORDER kutusuna uygulanır ve halkanın İÇ kenarı da
       yuvarlanır: görüntü halkanın içindeki DAİREYE kırpılır, halka her
       yönde eşit 1px kalır.
     - **Kanıt — replika değil GERÇEK `KAvatar`, gerçek CanvasKit'te:**
       widget'ı yerel bir damalı PNG'yle render eden minik bir web
       harness'i derlenip Chromium'da (Playwright) açıldı ve halka
       15°'lik adımlarla örneklendi. **ÖNCE: 24 açının yalnızca 4'ünde
       (0/90/180/270°) çerçeve rengi (#DCE2EA) vardı; SONRA: 24/24.**
       Ekran görüntüleri de gözle karşılaştırıldı.
     - **Düzeltme:** görüntü `ClipOval` ile sarıldı ve boyutu
       `size − 2×_borderWidth` yapıldı — yani halkanın İÇ kenarına tam
       oturan daire. Kenarlık genişliği artık `_borderWidth` sabitinde
       (tek kaynak); `Border.all`a açıkça geçiliyor.
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:**
       `avatar_test.dart`'a yeni bir test — (1) `ClipOval` görüntünün
       atası, (2) görüntü boyutu 62 (64 − 2×1). Ağ görseli test ortamında
       YÜKLENMEDİĞİNDEN (errorBuilder devreye girer, ClipOval yalnızca
       yedek metni sarar) render boyutu ölçülemez; bu yüzden yükleme
       durumundan bağımsız olan widget ÖZELLİKLERİ sabitlendi. ClipOval
       kaldırılınca test GERÇEKTEN `Found 0 widgets with type "ClipOval"`,
       boyut `size`a döndürülünce `Expected: <62> Actual: <64.0>` ile
       düştü; ikisi de geri konup yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 280/280 yeşil**
       (279'dan +1). `kelimeki_core`'a hiç dokunulmadı.
     - **Ders — "artefakt/normal" demek de bir TEŞHİSTİR ve ölçüm ister:**
       Parça 18/27/29 hep "hatayı ölçmeden düzeltme" tuzağını anlatıyordu;
       bu parça simetrik olanı gösterdi: **hatayı ölçmeden YOK SAYMAK.**
       İlk turda kendi ürettiğim probe görüntüsünde halkanın N/S/E/W'de
       gri, köşegenlerde hiç olmadığı ZATEN görünüyordu — "1px çerçeve"
       diye bakıp geçmiştim. Doğru refleks: bir kullanıcı görsel bir farkı
       İKİNCİ kez bildiriyorsa, kapatmadan önce o farkı ölç (burada halkayı
       açı açı örneklemek 20 satırlık bir betikti). Uniform olması gereken
       bir şeyin uniform olup olmadığı gözle değil, örnekleyerek anlaşılır.
   - ✅ **Parça 35 — Bölüm 5 (Oyun geçmişi) cihaz testinde bildirilen üç
     bulgu: İKİSİ gerçek hata, ÜÇÜNCÜSÜ web ile ZATEN birebir (9 Ağustos
     2026, `game_history_modal.dart`, `share_board.dart`):** Kullanıcı
     "Tüm oyunlar penceresinde her şey geliyor. Like yapınca kalp kırmızı
     olması gerekirken gri/siyah oluyor. … Paylaş çalışmıyor. (Tepki yok)
     Mesajlar da çıkıyor ama sıralama ters. En yeni en üstte gelmeli."
     diye bildirdi.
     - **Bug 1 — beğenilmiş kalp GRİ kalıyordu.** Web
       (`GameHistoryModal.tsx` ~579) `className={entry.liked_by_me ?
       'text-red' : 'text-muted'}` ile ikonun rengini beğeni durumuna göre
       değiştiriyor; port ikonun ŞEKLİNİ (`favorite` ↔ `favorite_border`)
       doğru değiştiriyor ama `color`u koşulsuz `_muted` bırakıyordu — yani
       dolu kalp çiziliyordu, ama gri. `_red` (`0xFFDC2626`, tailwind
       `red`) sabiti dosyada ZATEN vardı (skor satırlarında kullanılıyor),
       yeni bir renk icat edilmedi.
     - **Bug 2 — "Paylaş"a dokununca hiçbir şey olmuyordu.** `shareBoard`
       (`share_board.dart`) TEK bir `try/catch` içindeydi: PNG'yi geçici
       dizine yaz → dosyalı `SharePlus.share`. Bu zincirin HERHANGİ bir
       adımı patlarsa (geçici dizin yok/dolu, o platformda `path_provider`
       kanalı yok — GitHub Pages web derlemesinde tam olarak bu) `catch`
       her şeyi yutuyor ve kullanıcıya HİÇBİR ŞEY olmuyordu. Web'in
       `handleShare`i ise bir YEDEK ZİNCİRİ: `navigator.canShare({files})`
       tutmazsa dosyasız `navigator.share({title,text,url})`e düşer. Aynı
       zincir porta eklendi — dosyalı paylaşım patlarsa (loglanır) metin+
       link paylaşımı denenir. **Kullanıcının paylaş sayfasını İPTAL
       etmesi bu dala DÜŞMEZ:** `share_plus` iptalde fırlatmaz,
       `ShareResult.dismissed` döner — yani iptal ikinci bir paylaş
       sayfası açtırmaz (kaynaktan doğrulandı, tahmin değil).
     - **Bulgu 3 — sohbet arşivi sıralaması PORT HATASI DEĞİL, mobil web
       ile BİREBİR aynı.** İkisi de eskiden-yeniye (kronolojik artan)
       gösteriyor; üstelik web'in `GameChatHistoryModal.tsx`'i tam bu
       satırda bir yorum taşıyor: bir dönem oradaki `.reverse()`
       kaldırılmış, çünkü AYNI veriyi gösteren `AdminChatTranscriptModal`
       reverse yapmıyordu ve iki ekran farklı sırada görünüyordu. Yani
       "en yeni üstte" istemek meşru bir ürün isteği ama İKİ PLATFORMU
       BİRLİKTE ilgilendiren bir karar (ve web'de üçüncü bir ekranı,
       admin dökümünü de). Tek taraflı mobilde çevirmek tam da web'in
       bilerek kapattığı ayrışmayı geri açardı — **bilinçli olarak
       DEĞİŞTİRİLMEDİ**, kullanıcıya bu şekilde bildirildi. (Karşılaştırma
       için: CANLI sohbet penceresi — `ChatModal` — web'de de mobilde de
       en yeni ÜSTTE; orada yazma alanı en üstte olduğundan bu tutarlı.
       Ters duran şey arşiv değil, ikisinin FARKLI olması — ve bu fark
       web'de de aynen var.)
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI kanıt:** (1)
       `game_likes_test.dart`'ın mevcut iyimser-güncelleme testine renk
       assertion'ları eklendi — dokunmadan ÖNCE `favorite_border` ikonunun
       rengi `_red` DEĞİL, dokunduktan sonra `favorite` ikonunun rengi TAM
       OLARAK `_red`. (Sıra önemli: beğenildikten sonra `favorite_border`
       ikonu artık ağaçta YOK, "önce gri" kontrolü tap'tan sonra
       yapılamaz.) Renk düzeltmesi geri alınınca test GERÇEKTEN `Expected:
       Color(0.8627, 0.1490, 0.1490) Actual: Color(0.3529, 0.4000,
       0.4510)` ile düştü. (2) `share_recent_test.dart`'a yeni bir test —
       `MethodChannel('dev.fluttercommunity.plus/share')` sahtelenip
       dosyalı paylaşımın (path_provider kanalı testte yok) patlaması
       sağlanıyor; TAM BİR çağrı yapıldığı, `args['text']`in
       `'$shareMessage\nhttps://kelimeki.com/game/a'` olduğu ve
       `args['uri']`nin null kaldığı doğrulanıyor. Yedek zincir geri
       alınınca test GERÇEKTEN `Expected: an object with length of <1>
       Actual: []` ile düştü; ikisi de geri konup yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 282/282 yeşil**
       (280'den +1 yeni test; kalp testine eklenen assertion'lar ayrı test
       SAYILMIYOR). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** yedek zincirin GERÇEK faydası (cihazda/web
       derlemesinde paylaş sayfasının artık gerçekten açılması) yalnızca
       cihazda görülebilir — testte kanıtlanan şey "dosyalı yol patlarsa
       metin+link yolu GERÇEKTEN çağrılıyor". Kalbin kırmızısı da cihazda
       gözle teyit edilmeli.
   - ✅ **Parça 36 — sohbet arşivi de "en yeni en üstte": DÖRT kez istenmiş,
     üç kez yalnızca yarısı yapılmış bir istek (9 Ağustos 2026,
     `game_chat_history_modal.dart` + web `GameChatHistoryModal.tsx`/
     `AdminChatTranscriptModal.tsx`):** Kullanıcı Parça 35'teki "mobil web
     ile birebir aynı" cevabıma itiraz etti: "bunu daha önce 2-3 kere
     söyledim ve yapıldı diye biliyorum… her yerde her zaman en yeni en
     üstte olmalı."
     - **Kayıt kullanıcıyı doğruladı.** Kök `CLAUDE.md` satır 532 (4 Ağustos
       2026, "kullanıcı isteği") sıralamayı `ChatModal`'da çevirmiş, ama
       aynı girdi arşiv görünümlerini AÇIKÇA dışarıda bırakmış: *"…arşiv
       görünümleri bu değişiklikten ETKİLENMEDİ — orada okuma yönü hâlâ
       eskiden-yeniye, çünkü onlar bir yazışma kutusu değil bir döküm."*
       **O gerekçe kullanıcıdan gelmiyordu**, kod incelemesi sırasında
       üretilmişti. Sonuç: aynı istek dört kez tekrarlandı, üç kez
       "tamamlandı" sayıldı; ben de Parça 35'te bu yarım işi "web ile
       birebir, dolayısıyla port hatası değil" diye savundum — teknik
       olarak doğru, kullanıcının isteği açısından yanlış bir cevaptı.
     - **Düzeltme — dört ekran, tek yön.** Yön kararı HER ZAMAN çağıranda
       (paylaşılan `ChatThread`/`chat_thread.dart` hiç sıralama yapmıyor,
       verilen diziyi yukarıdan aşağı basıyor): `ChatModal` (web+mobil,
       zaten doğruydu), `GameChatHistoryModal` (web `.reverse()` + mobil
       `.reversed`), `AdminChatTranscriptModal` (web `.reverse()`).
       Bu, kullanıcının 6 Ağustos'taki "web'e dokunmayalım" kararının
       bilinçli bir istisnası: istek açıkça "her yerde" dendiği için
       verildi ve yalnızca mobilde çevirmek, web'in bir dönem
       `GameChatHistoryModal`↔`AdminChatTranscriptModal` arasında kapattığı
       ayrışmayı bu sefer web↔mobil arasında geri açardı.
     - **Kaydırma eşleşmesi yalnızca CANLI sohbete özel:** `ChatModal`'da
       sıralama ile otomatik kaydırma birlikte değişmek ZORUNDA (`scrollTop
       = 0` / en üste kaydırma) — web'de bu bir kez unutulup geri
       alınmıştı. İki arşiv ekranı otomatik kaydırma YAPMIYOR (düz bir
       kaydırma kabı, en üstte açılıyor), bu yüzden orada yalnızca sıra
       çevrildi.
     - **Test — negatif eş doğrulamasıyla:** `game_likes_test.dart`'ın
       mevcut arşiv testine (fixture kronolojik artan: 09:05 → 09:06 →
       09:08) üç mesajın ekrandaki dikey sırasını ölçen assertion'lar
       eklendi — en yeni EN ÜSTTE olmalı. `.reversed` geri alınınca test
       GERÇEKTEN `Expected: a value less than <323.5> Actual: <423.5>` ile
       düştü, geri konup yeşile döndü.
     - **Bayat yorumlar da temizlendi** (aynı hatanın tekrar üretilmemesi
       için): `game_chat_history_modal.dart`'ın dosya başlığı ve bu
       dosyanın Parça 5b girdisi "arşiv bir döküm, ters çevrilmiyor"
       diyordu; kök `CLAUDE.md`'nin 4 Ağustos girdisi ve iki `TESTING.md`
       (kök bölüm 3, mobil bölüm 5 — ikincisini DÜN ben yanlış yönde
       yazmıştım) güncellendi.
     - Doğrulama: web `npm run lint` + `npm run build` temiz; mobil
       `flutter analyze` temiz, **tam takım 282/282 yeşil** (yeni test
       eklenmedi, mevcut arşiv testine assertion eklendi).
     - **Doğrulama sınırı:** üç ekranın gerçek görsel teyidi (özellikle
       admin dökümü — bu ortamdan admin paneline girilemiyor) kullanıcıdan
       bekleniyor.
     - **Ders — "bu ekran farklı bir kategoriye giriyor" gerekçesini KENDİN
       üretiyorsan, onu koda yazmadan önce kullanıcıya sor.** Bu proje
       "ölçmeden teşhis koyma" (Parça 18/27) ve "ölçmeden YOK SAYMA"
       (Parça 34) derslerini zaten öğrenmişti; bu üçüncüsü: **bir isteğin
       KAPSAMINI daraltan gerekçeyi kendin uydurma.** Bedeli burada aynı
       isteğin dört kez tekrarlanması oldu ve üç oturum boyunca görünmedi,
       çünkü her turda isteğin görünür yarısı (canlı sohbet) düzeliyordu.
   - ✅ **Parça 37 — sekme butonlarının puntosu ve satır yüksekliği web'den
     küçüktü; ÜÇ yerde birden (9 Ağustos 2026, `neo_button.dart`,
     `setup_screen.dart`, `live_games_tab.dart`):** Kullanıcı Bölüm 7 cihaz
     testinden sonra "tab fontları web'e göre biraz daha küçük gibi geldi"
     dedi — Parça 33'ün (skor kartı sekmelerinde 13 vs web'in 14'ü) aynı
     sınıfı, farklı yerlerde.
     - **Ölçüm, Parça 33'ün yöntemiyle** (Tailwind sınıflarından zihnen
       türetmek YASAK — o ders orada öğrenildi): `npm run build` ile web'in
       DERLENMİŞ CSS'i (`dist/assets/index-*.css`) üretilip, `Setup.tsx`/
       `LiveGamesTab.tsx`'in buton `className`'leri birebir kopyalanan bir
       HTML'e konup Chromium'da (Playwright) `getComputedStyle` +
       `getBoundingClientRect` ile okundu. `tailwind.config.js`'te
       `fontSize` override'ı OLMADIĞI da ayrıca kontrol edildi (olsaydı
       `text-sm`=14px varsayımı çürürdü).
       | | web (ölçüldü) | port (öncesi) |
       |---|---|---|
       | OYUN TİPİ + OYUNCU SAYISI (`text-sm`) | 14px / satır 20px / kutu 46 | 13px / satır 1.2 / ~41 |
       | Alt sekmeler (`text-[11px]`) | 11px / satır 16.5px / kutu 38.5 | 10px / doğal / ~33 |
     - **İki ayrı sapma vardı, ikincisi gözden kaçmıştı:** punto (1px) VE
       satır yüksekliği. Tailwind'in hazır punto sınıfları `line-height`i de
       belirliyor (`text-sm` → 14/20), keyfi değerlerde (`text-[11px]`)
       gövdeden 1.5 miras kalıyor; `NeoButton` ise sabit `height: 1.2`
       taşıyordu ve alt sekmeler hiç `height` vermiyordu (fontun doğal
       ~1.3'ü). Yalnızca puntoyu düzeltmek kutuyu hâlâ alçak bırakırdı.
       `NeoButton`'a opsiyonel `lineHeight` eklendi (`?? 1.2` — diğer ~10
       çağrı yerinin davranışı BİREBİR aynı kaldı); `_ChoiceButton`
       `20/14`, iki alt sekme `1.5` geçiyor.
     - **`_ChoiceButton` iki yerde kullanılıyor** (OYUN TİPİ sekmeleri +
       OYUNCU SAYISI 2/4) — web'de İKİSİ de `text-sm ... tracking-[1px]
       py-3`, yani tek düzeltme ikisi için de doğru; çağrı yerleri tek tek
       kontrol edildi, "paylaşılan bileşen, herhalde aynıdır" varsayımıyla
       geçilmedi.
     - **Kalan 2px BİLİNÇLİ:** düzeltmeden sonra kutu 44, web 46. Fark tam
       olarak web'in `border`ının yer kaplaması; Flutter'da çerçeve
       `foregroundDecoration`da (Parça 4'ün kararı — aktif/pasif kalınlık
       farkı düzeni kaydırmasın) ve yer KAPLAMIYOR. Telafi için 1px dolgu
       eklenMEDİ: çerçeve bir gün decoration'a taşınırsa iki kez sayılacak
       bir sihirli sayı olurdu. Test 44'ü, gerekçesiyle birlikte sabitliyor.
     - **Test — negatif eş doğrulamasıyla:** `setup_screen_test.dart`'a yeni
       bir test (punto 14 + satır 20/14 + OYUNCU SAYISI de 14 + kutu 44).
       `fontSize: 14, lineHeight: 20/14` geri alınınca test GERÇEKTEN
       `Expected: <14> Actual: <13.0>` ile düştü, geri konup yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 283/283 yeşil**
       (282'den +1). `kelimeki_core`'a hiç dokunulmadı; ölçüm için üretilen
       `dist/` ve geçici HTML/Playwright betikleri silindi.
     - **Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor.
       Alt sekmelerin `LiveGamesTab` kopyası da düzeltildi ama onun kendi
       ölçüm testi YOK — Setup'taki testin kardeşi olarak elle senkron
       tutuluyor (iki dosya zaten "bilinçli kod tekrarı" çifti).
   - ✅ **Parça 38 — girişli kullanıcı offline oynayınca hamleler SESSİZCE
     kayboluyordu; bulut kayıtlarına yerel ayna eklendi (9 Ağustos 2026,
     `storage/cloud_save_mirror_store.dart` (yeni), `app_database.dart` v2,
     `cloud_save_repo.dart`, `bootstrap.dart`, `setup_screen.dart`):**
     Bölüm 8 cihaz testinde kullanıcı buldu — girişliyken uçak modunda
     oynanan hamleler (doğrulama/OYNA/YZ cevabı hepsi çalışıyordu) ağ
     dönünce KAYBOLUYOR, oyun sunucudaki son senkron state'e geri
     düşüyordu.
     - **Kök sebep, kod okunarak doğrulandı:** girişli kullanıcı için oyun
       `CloudGameSession` ile kaydediliyor (`setup_screen.dart`,
       `if (user != null && cloud != null)`) ve **yerele HİÇ yazılmıyor** —
       `else` dalındaki misafir slotu yalnızca girişsizler için. Her
       hamledeki `upsert` ağ hatasını yakalayıp `false` dönüyor ve state'i
       DÜŞÜRÜYORDU: ne yeniden deneme kuyruğu ne yerel yedek vardı.
     - **"Web de aynısını yapıyor" bu sefer savunma DEĞİL** — iki gün önce
       (Parça 36) tam bu gerekçeyle yarım kalmış bir işi savunup
       yanılmıştım. Fark: portun kendi yazılı gerekçesi *"yerel YZ oyunu
       offline bir haktır"* (sürüm kapısının fail-open kararı buna
       dayanıyor) ve mobilde offline çalışmak native uygulamanın varlık
       sebebi; depolama katmanı (SQLite) zaten var, yalnızca misafirler
       için kullanılıyordu. Kullanıcı da "bence de şimdi düzeltelim" dedi.
     - **Tasarım — write-behind ayna, `local_saves` YENİDEN KULLANILMADI:**
       yeni bir `pending_cloud_saves` tablosu (şema v2, ekleyici migration).
       Sebep, o tablonun `load()`unun iki kararı: (1) 7 günlük terk-edilme
       süpürmesi — bulut satırının cezası sunucuda `claimAbandoned` ile
       veriliyor, aynı oyunu bir de yerelden süpürmek MÜKERRER -2 demek
       olurdu (girişli kullanıcının yerele yazmama kararının asıl gerekçesi
       buydu, Parça 3a); (2) `multiSession=true` işaretlemesi — bulut
       devamı web'de de mobilde de bunu bilinçli olarak yapmıyor. Ayna bu
       ikisine HİÇ girmiyor; depolama katmanının diğer üç kuralı (versiyonlu
       payload, parse-don't-validate, çözülemeyeni SİLME karantinaya al)
       aynen geçerli.
     - **Akış:** `upsert` ÖNCE aynaya yazar (yerel yazma her zaman başarılı),
       sonra sunucuyu dener; başarıda aynayı siler — yani online akışta tablo
       hep boş kalır, ek bir maliyet yok. `flushMirrored(userId)` bekleyenleri
       iter ve `_syncCloud`ta **listelemeden ÖNCE** çağrılır. `list(userId:)`
       aynayı bindirir: aynası sunucudakinden yeniyse onun state'i gösterilir,
       yalnızca aynada olan oyunlar (tamamen offline açılmış) listeye eklenir.
       `delete` aynayı da siler (bekleyen bir yazma satırı diriltmesin).
     - **En ince nokta — bindirme, terk kararından ÖNCE:** sunucu satırı 7
       günden eski ama ayna dünse, o oyun HAKSIZ yere `abandoned`a düşüp -2
       yerdi. Bindirme `updatedAtMs`i de tazelediğinden bu kapalı; ayrı bir
       testle sabitlendi (negatif eşte gerçekten `Expected: empty` ile
       düşüyor).
     - **Test — negatif eş doğrulamasıyla:** `cloud_save_test.dart`'a kalıcı
       bir `offline` bayrağı + 4 test (offline hamleler listede kaybolmuyor;
       ağ dönünce ayna itilip temizleniyor; tamamen offline açılan oyun
       listede; taze ayna haksız terki engelliyor). Ayna yazma satırı geri
       alınınca DÖRDÜ DE düştü (`+12 -4`), geri konunca yeşile döndü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 289/289 yeşil**
       (283'ten +6). `kelimeki_core`'a hiç dokunulmadı.
     - **Aynı gün, kullanıcı sorusuyla bulunan ÜÇ AÇIK (düzeltildi):**
       Kullanıcı "oyunu açıp interneti kapatıp 10 gün sonra dönersem 7 gün
       kuralı işler mi?" diye sordu — cevap HAYIR'dı ve bu, bu parçanın
       KENDİ açtığı bir gedikti: `_syncCloud` önce `flushMirrored` çağırdığı
       için 10 gün önceki ayna sunucuya yazılıyor, sunucu `updated_at`i
       bugüne çekiyor ve `list()` satırı taze görüp cezayı hiç uygulamıyordu
       (yani bir hamle offline oynayıp yıllarca kaybolmak cezadan muaf
       olmak demekti). İki kardeşi de vardı: (a) terk dalı aynayı SİLMİYORDU
       — satır silindikten sonra bir sonraki açılışta oyun "yalnızca aynada
       var" sanılıp DİRİLİYORDU (hem ceza yazılmış hem oyun devam ediyor);
       (b) sunucunun hiç görmediği (tamamen offline açılmış) oyunlar süre
       dolsa da hiç cezalandırılmıyordu — kodun kendi yorumunda bu açıkça
       yazılıydı. **Düzeltme:** `flushMirrored` süresi DOLMUŞ aynayı itmez
       (karar `list()`e bırakılır; son etkinlik anı `max(sunucu, ayna)`),
       terk dalı aynayı da siler, ve yalnızca-ayna satırları da 7 günde
       cezaya çevrilip aynadan silinir (bu satır cihaza özel olduğundan
       `claimAbandoned`ın yarış koruması gerekmiyor). İki yeni test negatif
       eşle doğrulandı — cutoff atlaması geri alınınca ikisi de düşüyor.
       **Ders:** yeni bir dayanıklılık katmanı eklerken "bu veriyi kim
       ZAMAN DAMGASI olarak okuyor?" diye sor — burada `updated_at` aynı
       anda hem "en son ne zaman kaydettim" hem "terk edildi mi" sorusunun
       cevabıydı; onu tazelemek ikinci sorunun cevabını sessizce siliyordu.
     - **Web'de AYNI kusur duruyor — bilinçli, kullanıcı kararıyla sonraya
       bırakıldı (9 Ağustos 2026):** `App.tsx`'in autosave'i girişli
       kullanıcıda `clearGameState()` çağırıp yalnızca sunucuya yazıyor,
       yani web'de offline hamleler hâlâ kayboluyor (kurulabilir PWA
       olduğundan bu gerçek bir senaryo). 7 gün CEZASI tarafında ayrışma
       YOK — web'de ayna hiç olmadığı için o açık orada hiç doğmadı, bu
       parçanın düzeltmesi mobili web'in zaten doğru olan davranışına geri
       getirdi. Kayıt: kök `CLAUDE.md`, "Web'de Yapılacak İşler" (mobildeki
       tasarım + kaçınılması gereken üç gedik oraya yazıldı).
     - **Doğrulama sınırı:** gerçek `local_game_saves` ucuyla (RLS, gerçek
       ağ kesintisi) uçtan uca doğrulama cihazda yapılmalı — `mobile/TESTING.md`
       Bölüm 8'e maddeler eklendi. **Bilinçli kapsam dışı:** ağ geri
       geldiğinde kendiliğinden flush eden bir bağlantı dinleyicisi YOK
       (web'de `online` olayı var); flush açılışta ve `_syncCloud`ta
       çalışıyor. Bu, veri kaybı riski DEĞİL (ayna kalıcı) — yalnızca
       senkron gecikmesi; connectivity paketi eklemeden çözülemiyor.
     - **Ayrıca doğrulandı, hata DEĞİL:** offline'ken sayfayı yenileyince
       Safari'nin "internet yok" sayfası çıkması ve logoya basınca aynısının
       olması, web test ortamına özgü — Flutter web geri navigasyonu tarayıcı
       geçmişine bağlı, offline'da o girdi ağa gidip sayfayı öldürüyor.
       Native'de tarayıcı/geçmiş yok. Not: sayfa öldüğü an bellek de gittiği
       için "çıkışta son bir kez yaz" türü bir çözüm zaten yetmezdi —
       kalıcı yerel yedek şarttı.
   - ✅ **Parça 39 — tahta ile mesaj arasındaki fazla boşluk + yatay modda
     kesilen tahta gölgesi (9 Ağustos 2026, `game_screen.dart`,
     `online_game_screen.dart`):** Bölüm 8 testinden önce kullanıcı iki
     görsel bulgu bildirdi; ikisi de ÖLÇÜLDÜ.
     - **(a) 56px'lik boşluk Parça 16'nın kalıntısıydı.** Web'de `<main>`
       içinde Board'dan sonra mesaj bloğu geliyor ve tek boşluk onun `pt-1`i
       (**4px**); mobilde araya 56px konmuştu. O 56px Parça 16'da "tahta
       gölgesi raf kartının opak zemini tarafından eziliyor" gerekçesiyle
       eklenmişti — ama web de AYNI yapıya sahip ve orada sorun yok. Gerçek
       kök sebep bir parça sonra bulunmuştu (Parça 17: `max-width 680` hiç
       uygulanmamış, tahta kenardan kenara gerilip gölgeye yer
       kalmıyordu). Yani 16'daki 56px bir çözüm değil bir SEMPTOM
       bastırmasıydı ve 17'den sonra yalnızca web'den sapan görünür bir
       boşluk olarak kaldı. Kaldırıldı; aynı parçada 8→24 yapılan buton
       satırı boşluğu da web'in `gap-1.5`ine (**6px**) çekildi.
       **Ders:** bir görsel semptomu boşluk/dolgu ekleyerek bastırdıysan,
       gerçek kök sebep sonradan bulunduğunda o bastırmayı GERİ AL — aksi
       halde iki düzeltme üst üste binip yeni bir sapma üretiyor.
     - **(b) "Yatay modda tahtanın arkasında hatalı gölge" — tetikleyici
       YÖN DEĞİL, KAYDIRILABİLİRLİK.** Gerçek CanvasKit'te (web derlemesi +
       Playwright, Parça 18/27'nin yöntemi) tahtanın sağ kenarındaki piksel
       profili ölçüldü: kaydırma yokken `217→228→238→243→247→250` diye
       sönümlenirken, kaydırma varken `217→255` ile bıçak gibi kesiliyordu.
       Kesin deney: AYNI genişlikte (834) yalnızca yüksekliği kısaltıp
       (1150→600) içeriği kaydırılabilir yapmak hatayı üretti — yani yönle
       ilgisi yok, yatayda görünmesinin sebebi içeriğin yalnızca orada
       ekranı aşması. Kesim tam olarak 680'lik içerik sütununun kenarında:
       kaydırma görünümü etkinleşince gölgenin widget sınırları DIŞINA
       taşan kısmı kırpılıyor.
     - **Elenen iki hipotez (ölçülerek):** `RepaintBoundary` ile tahtayı
       kendi katmanına almak piksel profilini HİÇ değiştirmedi (eklenip
       ölçüldü, sonra geri alındı); `_CssShadowBoxPainter`'ın kendi evenOdd
       kırpması da sebep değil (`rect.inflate(reach + 4)` ≈ 144px pay
       bırakıyor).
     - **Çözüm — eksen ayrımı:** `clipBehavior: Clip.none` gölgeyi
       düzeltiyor AMA kaydırılan içerik `GameHeader`'ın üstüne boyanıyor
       (Column'da header daha önce çizildiğinden) — ekran görüntüsüyle
       doğrulandı. Bu yüzden kaydırma görünümü `Clip.none` yapılıp yeni bir
       `_VerticalOnlyClipper` (`ClipRect(clipper:)`) ile SARILDI: dikeyde
       kırpar (header korunur), yatayda kırpmaz (gölge sönümlenir). Üç
       ölçümde de (portre, kısa portre, yatay) profil artık birebir aynı.
     - **Test — negatif eş doğrulamasıyla:** kırpıcının niyetini sabitleyen
       bir widget testi (dikeyde tam kutu, yatayda kutunun ±100px dışına
       taşan bir `Rect`). Kırpıcı normal bir tam-kutu dikdörtgenine
       çevrilince test GERÇEKTEN `Expected: a value less than <-100>
       Actual: <0.0>` ile düştü.
     - Doğrulama: `flutter analyze` temiz, **tam takım 290/290 yeşil**
       (289'dan +1). `kelimeki_core`'a hiç dokunulmadı; teşhis için
       kullanılan web harness'i ve `build/` çıktıları silindi.
     - **Doğrulama sınırı:** ölçümler yerel Chromium/SwiftShader'da yapıldı;
       gerçek iPad Safari'de görsel teyit kullanıcıdan bekleniyor.
   - ✅ **Parça 40 — "web'in birebir aynısını uygulayamıyor muyuz?": 680'lik
     sınır KAYDIRMAYI SARIYORDU, web'de ise her bölümün kendi üzerinde
     (9 Ağustos 2026, `game_screen.dart`, `online_game_screen.dart`):**
     Kullanıcı Parça 39'dan sonra da tahtanın sağ üstündeki gölgeyi "web'e
     göre çok belirgin" bulup haklı bir soru sordu.
     - **İlk ölçümüm YETERSİZDİ ve beni yanlış sonuca götürdü.** İZOLE
       `BoardWidget`'ı web'in derlenmiş CSS'iyle aynı geometride ölçüp
       "gölge birebir aynı, fark yok" demiştim — profiller gerçekten 1-2/255
       farkla örtüşüyordu (kart zemini `#DDE4EE`, yarıçap 18, üçlü gölge
       hepsi aynı). Ama izole widget GERÇEK EKRANIN sarmalayıcılarını
       taşımıyordu; sorun gölgede değil DÜZENDEYDİ. **Ders:** "değerler
       aynı" ölçümü, o değerlerin İÇİNDE YAŞADIĞI ağaç farklıysa hiçbir şey
       kanıtlamaz — parite ölçümü gerçek ekranın kendisinde yapılmalı.
     - **Kök sebep:** Web'de `min-h-[100dvh] flex flex-col` sayfanın TAMAMI
       akıyor ve `max-w-[680px]` her bölümün KENDİ üzerinde (GameHeader.tsx,
       Board.tsx, App.tsx'in alt container'ı) — yani 680 genişliğinde bir
       KIRPMA kabı hiç yok. Port ise 680'i header+içeriği saran TEK bir
       `ConstrainedBox`'a koymuştu; `SingleChildScrollView` o kabın içinde
       kaldığından kaydırma görünümünün KENDİSİ 680 genişliğindeydi ve
       tahtanın ~30px taşan gölgesini kırpıyordu.
     - **Parça 39'un `_VerticalOnlyClipper`'ı bir YAMAYDI, kaldırıldı.**
       Dün semptomu (yatayda kesilen gölge) doğru teşhis edip yanlış yerden
       çözmüştüm: kırpmayı eksene bölmek yerine kırpma kabının neden 680
       olduğunu sormalıydım. 200.000px'lik yapay bir kırpma dikdörtgeni de
       geride kalmayacaktı. Artık `clipBehavior` varsayılan, özel clipper
       yok — kaydırma görünümü TAM GENİŞLİK, 680 sınırı header'ın ve içerik
       sütununun kendi üzerinde (web'in deseni birebir).
     - **Doğrulama:** gerçek CanvasKit'te (tam `GameScreen`, yatay 1194x790)
       sağ kenar profili kaydırmadan ÖNCE ve SONRA birebir aynı:
       `221 197 206 217 228 238 243 247 250 251 252 253 254` — web
       referansıyla (`203 214 225 236 242 247 249 251 252`) aynı sönüm
       eğrisi. Kaydırılmış ekran görüntüsünde header hâlâ korunuyor (içerik
       üstüne binmiyor).
     - **Bulunan yapısal tuzak:** ilk yeniden düzenlemede `Expanded`
       doğrudan `Stack`'in çocuğu olarak kaldı ("Incorrect use of
       ParentDataWidget", 13 test düştü) — header ile kaydırma görünümünü
       saran `Column` şart.
     - **Test:** eski clipper testi, yerini yeni değişmeze bıraktı —
       kaydırma görünümünün genişliği viewport'a eşit olmalı (680 DEĞİL) ve
       içeride 680'lik `ConstrainedBox` bulunmalı; ikisi birden, çünkü
       yalnızca ilki Parça 17'nin hatasını (tahta kenardan kenara gerilir)
       geri açardı.
     - Doğrulama: `flutter analyze` temiz, **tam takım 290/290 yeşil**.
       `kelimeki_core`'a hiç dokunulmadı; teşhis harness'i silindi.
     - **Doğrulama sınırı:** ölçümler SwiftShader'da; gerçek iPad'de görsel
       teyit kullanıcıdan bekleniyor.
   - ✅ **Parça 41 — avatar menüsünün "Hesap menüsü" ipucu İKİ TARAFTAN DA
     kaldırıldı (9 Ağustos 2026, `account_button.dart` + web
     `UserMenu.tsx`):** Bir gün önce (Parça 40 sonrası web işi) mobildeki
     `PopupMenuButton.tooltip`'in web karşılığı olarak `UserMenu`'nün avatar
     butonuna `title="Hesap menüsü"` eklenmişti; kullanıcı bir sonraki turda
     bundan vazgeçip "hem web hem app'ten kaldır" dedi.
     - **Parametreyi tamamen SİLMEK yanlış olurdu:** `PopupMenuButton`'ın
       build'i `Tooltip(message: widget.tooltip ?? MaterialLocalizations
       .of(context).showMenuTooltip, ...)` diyor — null bırakmak İngilizce
       "Show menu" metnine düşürürdü, yani ipucu kaybolmaz, YABANCILAŞIRDI.
       Doğru yol boş dize: `Tooltip.build` `_tooltipMessage.isEmpty` iken
       çocuğu olduğu gibi döndürüp hiç overlay kurmuyor. İkisi de SDK
       kaynağı okunarak doğrulandı (`popup_menu.dart:1711`,
       `tooltip.dart:924`) — tahmin değil.
     - **Web'de `aria-label` DURUYOR, yalnızca `title` kaldırıldı** — biri
       ekran okuyucu erişilebilirliği, diğeri görünür hover balonu; istek
       yalnızca ikincisini kapsıyordu.
     - **Test:** `account_button_test.dart`'ın `pumpMenu` yardımcısı menüyü
       `find.byTooltip('Hesap menüsü')` ile açıyordu — artık
       `find.byType(PopupMenuButton<String>)` kullanıyor (widget tipiyle
       bulmak zaten daha sağlam, görünür metne/ipucuna bağlı değil).
       Ayrı bir negatif eş kurulmadı: davranış bir "yokluk" olduğundan
       (ipucu ÇIKMAMALI) ve tooltip'in kendisi artık ağaçta hiç
       oluşmadığından, `pumpMenu`'nün eski finder'ıyla ÇALIŞMAMASI zaten
       kaldırmanın kanıtı — testi eski hâlinde bırakmak paketi kırıyordu.
     - Doğrulama: `flutter analyze` temiz, **tam takım 290/290 yeşil**; web
       `npm run lint` + `npm run build` temiz. `kelimeki_core`'a hiç
       dokunulmadı. **Cihazda da doğrulandı** (kullanıcı, GitHub Pages web
       derlemesi, aynı gün): avatarda artık hiçbir ipucu balonu çıkmıyor —
       ne Türkçe metin ne de `tooltip` null bırakılsaydı çıkacak olan
       İngilizce "Show menu". Yani boş dize çözümü gerçek CanvasKit'te de
       beklendiği gibi çalışıyor.
   - ✅ **Parça 42 — arkadaşlık simgesi: bu sefer WEB porta hizalandı; yan
     bulgu olarak "iki ayrı yeşil" ortaya çıktı (9 Ağustos 2026,
     `player_score_card_modal.dart` + web `PlayerScoreCard.tsx`):**
     Kullanıcı iki skor kartını yan yana koyup "web'deki arkadaş ekle
     app'tekinden neden farklı?" diye sordu, sonra "hepsi app'teki gibi
     olsun" dedi.
     - **Fark İKİ noktadaydı, biri gözden kaçmıştı:** (1) web butonu
       20×20'lik yuvarlak bir rozet (`bg-accent/15` zemin +
       `border-accent/40` çerçeve) taşıyor, port kapsız çiziyor; (2) web
       çizgisel (outline) SVG, port dolu (filled) Material glyph'i. Bir
       gün önceki web değişikliği yalnızca glyph'i `+`'dan outline bir
       ikona çevirmiş, rozeti hiç sorgulamamıştı — bu yüzden fark devam
       etti. İkisi de web tarafında port yönünde kapatıldı.
     - **Yön bu kez TERS (port → web) ve bu bilinçli:** projenin kuralı
       "web kanonik, port ona uyar"; ama burada kullanıcı açıkça portun
       görünümünü tercih etti. Kural bir estetik dayatma değil, sessiz
       ayrışmayı önleme aracı — tercih açıkça belirtildiğinde web'in
       değişmesi de aynı amaca hizmet ediyor.
     - **Web'e yazılan path verisi PORTUN KENDİ FONTUNDAN çıkarıldı:**
       `MaterialIcons-Regular.otf` (Flutter SDK) → fontTools →
       `Icons.person_add_alt_1` (U+E494) ve `Icons.check_circle`
       (U+E159) outline'ları → 24'lük viewBox (unitsPerEm 512, ölçek
       24/512, y ters). Ölçülen sınırlar Material ızgarasıyla uyuştu
       (person_add y 4-20, check_circle 2-22 kare) — yani iki platform
       "benzer" değil AYNI vektörü çiziyor. Benzerini elle çizmek bu
       projenin "ölçmeden teşhis koyma" dersinin görsel karşılığı olurdu.
     - **✓ de aynı turda değişti:** web'de yeşil rozet içindeki `✓`
       karakteri dolu `check_circle` ikonuna çevrildi. Tek başına
       bırakılsaydı bu sefer O ayrışırdı — aynı butonun iki yüzü.
     - **Yan bulgu (gerçek, kapatılmadı) — web'de İKİ ayrı yeşil var:**
       tailwind token `green: #16A34A` (`text-green`: ✓ ikonu, "Senin
       Hamlen Bekleniyor" gibi metinler) ve `Board.tsx`'te hardcoded
       `#1FA05C` (`moveColor`, sürükleme dış hattı). Port ikincisini tek
       `_green`'i sanıp **12 yerde** kullanıyor; bazıları doğru
       (tahta/mesaj), bazıları değil. Bu parçada YALNIZCA ✓ ikonu
       düzeltildi (`0xFF16A34A`) — kalan 11 kullanım yeri site site web
       karşılığıyla karşılaştırılmadı. **Açık iş:** her `_green`
       kullanımının web'de token mı yoksa `#1FA05C` mi olduğunu
       denetleyen ayrı bir tur. Toplu bir "hepsini token yap" hamlesi
       YANLIŞ olurdu — tahta/hamle dış hattı gerçekten `#1FA05C`.
     - Doğrulama: `flutter analyze` temiz, **tam takım 290/290 yeşil**;
       web `npm run lint` + `npm run build` temiz, görsel kontrol
       derlenmiş gerçek CSS ile Chromium'da DPR 3'te yapıldı (buton
       kutusu 20×20, zemin şeffaf, çerçeve 0 ölçüldü). Web değişikliği
       ayrı bir `main` tabanlı PR ile (#228) canlıya alındı.
     - **Doğrulama sınırı:** iki platformun yan yana son görsel teyidi
       kullanıcıdan bekleniyor (renk farkı ✓'te artık yok, ama gözle
       ayırt edilemeyecek kadar küçüktü zaten).
   - ✅ **Parça 43 — offline'da "Devam Eden Oyunlar" BOŞ görünüyordu; ayna
     veriyi koruyordu ama görünürlüğü değil (10 Ağustos 2026,
     `app_database.dart` v3, `cloud_save_mirror_store.dart`,
     `cloud_save_repo.dart`):** Kullanıcı TESTING.md 8.2'yi koşarken buldu.
     Test kendi iddiasını GEÇTİ (uçak modunda oynanan hamleler ağ dönünce
     duruyordu — skor 82→144, torba 56→37 ile doğrulandı), ama ara adımda
     logoya basıp Setup'a dönünce oyun listede YOKTU.
     - **Kök sebep, kod okunarak (tahminle değil):** `CloudSaveRepo.list()`
       önce `gateway.list()` çağırıyor; offline'da bu fırlatıyor ve fonksiyon
       ORACIKTA `null` dönüyordu. Ayna bindirmesi ve "yalnızca aynada olan
       oyunlar" mantığının TAMAMI bu satırın altındaydı — yani Parça 38'in
       eklediği her şey tam da en çok gerektiği anda (offline) devre dışıydı.
       `null` gelince Setup eski listesini koruyor, o da yeni oyunu
       içermiyordu.
     - **Web de aynı davranıyor** (`refreshCloudSaves` hatada `[]` dönüp
       "Henüz bir Yapay Zeka oyunun yok." gösteriyor) — yani bir port
       paritesi eksiği DEĞİL. Ama native'de offline birinci sınıf bir
       beklenti (sürüm kapısının fail-open gerekçesi de bu), o yüzden
       porttan ileri gitmek bilinçli.
     - **Çözüm — son başarılı listenin yerel önbelleği:** yeni
       `cloud_save_cache` tablosu (şema v3, ekleyici migration) +
       `CloudSaveCacheStore`. Her BAŞARILI `list()` sonucu (birleştirilmiş
       hâli — ayna bindirmesi zaten uygulanmış) bu tabloya yazılıyor;
       `gateway.list()` fırlattığında yeni `_offlineList` önbellek + ayna
       bindirmesiyle listeyi çiziyor.
     - **Neden yalnızca ayna YETMEZ:** o zaman offline oynanmamış diğer
       oyunlar listeden düşerdi — bir sorunu başkasıyla değişmiş olurduk.
       Önbellek ayrıca o oyunlara offline DEVAM edebilmeyi de sağlıyor
       (state elde).
     - **Offline dalda ceza HİÇ uygulanmaz** (`abandoned` her zaman boş): 7
       günü dolmuş bir satırın gerçekten terk edilip edilmediği sunucuyla
       doğrulanmadan bilinemez (başka cihaz oynamış olabilir) ve
       `claimAbandoned`ın yarış koruması offline çalışamaz. Süresi geçmiş
       satırlar listeye de ALINMAZ — kullanıcı, bir sonraki çevrimiçi
       listelemede silinecek bir oyuna devam etmesin. Ağ dönünce ceza normal
       yoldan işliyor (testli).
     - **İki store'un rolü KARIŞTIRILMAMALI:** `pending_cloud_saves`
       sunucuya YAZILAMAMIŞ state'i tutar (kaynak kayıt — kaybolursa gerçek
       veri kaybı, o yüzden çözülemeyen satır KARANTİNAYA alınır);
       `cloud_save_cache` sunucuda ZATEN duran satırların salt gösterim
       kopyasıdır (bozulursa en fazla offline liste eksik görünür, o yüzden
       çözülemeyen satır sessizce ATLANIR). `delete()` ikisini birden
       temizliyor.
     - **Test yazarken bulunan ince nokta:** `_offlineList`te ayna KOŞULSUZ
       kazanmalı. Sunucu satırıyla karşılaştırmadaki `savedAtMs >` koruması
       burada YANLIŞ olurdu — orada ayna BAŞKA bir cihazın yazdığı satırdan
       eski olabilir, burada ise karşı taraf BU cihazın kendi önbelleği;
       bekleyen bir ayna tanımı gereği son başarılı yazmadan sonradır.
       İlk sürüm `>` kullanıyordu ve damgalar aynı tick'te eşit olduğu için
       önbellek kazanıp offline hamleleri gizliyordu (test yakaladı).
     - **Test dersi (kaskad):** ilk koşuda 3 test düştü ama yalnızca BİRİ
       gerçekti — ilk test `storage.db.close()`a varamadan fırladığı için
       sonraki testler onun DB'sinden artık ayna okuyup "1 bekliyordum, 2
       geldi" verdi. Bu dosyada bir test düştüğünde ÖNCE ilkini düzelt,
       sonrakileri ayrı hata sanma.
     - Doğrulama: `flutter analyze` temiz, **tam takım 293/293 yeşil**
       (290'dan +3). Negatif eş: `_offlineList` çağrısı geçici olarak
       `return null`a çevrilince yeni üç testin de (artı Parça 38'den bir
       tanesi) GERÇEKTEN düştüğü görüldü (`Expected: not null / Actual:
       <null>`), geri konunca yeşile döndü. `kelimeki_core`'a hiç
       dokunulmadı.
     - **Doğrulama sınırı:** gerçek cihazda (uçak modunda Setup'a dönüp
       oyunu listede GÖRMEK) teyit kullanıcıdan bekleniyor — TESTING.md
       bölüm 8'e ayrı madde eklendi.
   - ✅ **Parça 44 — ağ geri gelince bulut senkronu KENDİLİĞİNDEN koşmuyordu;
     web'in foreground dinleyicileri hiç port edilmemişti (10 Ağustos 2026,
     `setup_screen.dart`):** Kullanıcı 8.3'ü koşarken bildirdi — tamamen
     offline açılan oyun cihazda "Devam Edenler"de göründü (Parça 43
     çalıştı) ama ağ dönünce web'de dakikalarca ÇIKMADI.
     - **Teşhis tahminle değil sunucudan yapıldı:** `local_game_saves`
       sorgulandı; satır gerçekten yoktu (kullanıcı 10:09'da bildirdi),
       sonra tekrar sorgulandığında ORADAYDI — `updated_at` 10:17. Yani
       veri kaybı yok, flush geç çalışmış. Aradaki farkı yaratan şey
       kullanıcının o arada bir oyuna girip çıkması/uygulamayı yeniden
       başlatması olmalı.
     - **Kök sebep — port paritesi eksiği (yeni bir tasarım kararı DEĞİL):**
       `_syncCloud` yalnızca üç anda koşuyordu: `initState`, `_onAuthEvent`,
       ve bir oyundan Setup'a dönüş. Web ise `refreshCloudSaves` için
       `visibilitychange` + `focus` + `online` dinleyicilerini 4 Ağustos
       2026'da EKLEMİŞTİ (App.tsx; gerekçesi orada yazılı: "uygulama Setup'ta
       arka planda günlerce durup öne döndüğünde 7 günlük terk süpürmesi hiç
       tetiklenmiyordu"). Portun `didChangeAppLifecycleState`'i yalnızca
       `_scheduleLiveBadgeRefresh`'i çağırıyordu — rozet tazeleniyor, bulut
       senkronu tazelenmiyordu. Parça 38'in "bilinçli kapsam dışı" notu
       ("ağ dönünce kendiliğinden flush eden bir dinleyici YOK") bu eksiği
       zaten yazmıştı; bugünkü test onun gerçek maliyetini gösterdi.
     - **Düzeltme:** `didChangeAppLifecycleState`'in `resumed` dalı artık
       `_scheduleCloudSync()`i de çağırıyor (rozetle aynı 300ms debounce,
       aynı gerekçe). Yeni `_cloudSyncDebounce` timer'ı `dispose()`ta iptal
       ediliyor — Parça 11/21'in "bekleyen timer test bitince flake üretir"
       dersi. Ayrı bir connectivity paketi EKLENMEDİ: uçak modundan dönüş
       pratikte uygulamanın öne gelmesiyle birlikte oluyor, web de aynı
       yaklaşımı (olay dinleyicisi, ağ durumu sorgusu değil) kullanıyor.
     - **Kalan sınır (dürüstlük):** uygulama ÖNDEYKEN ağ geri gelirse (öne
       dönüş olayı hiç oluşmadan) senkron yine beklemez — web'in `online`
       olayının tam karşılığı Flutter'da paketsiz yok. Bu durumda kullanıcı
       bir oyuna girip çıkınca ya da uygulamayı öne/arkaya alınca senkron
       koşuyor; veri kaybı riski yok (ayna kalıcı), yalnızca gecikme.
     - Doğrulama: `flutter analyze` temiz, **tam takım 294/294 yeşil**
       (293'ten +1). Negatif eş: `_scheduleCloudSync()` çağrısı yorum
       satırına alınınca yeni test GERÇEKTEN düştü (`Expected: a value
       greater than <1> / Actual: <1>`), geri konunca yeşile döndü.
     - **Aynı turda kapatılan iki doğrulama sınırı (cihazda, gerçek
       hesapla):** (1) Parça 38'in `SupabaseCloudSaveGateway` ucu (gerçek
       PostgREST upsert + RLS) bu ortamdan hiç test edilememişti — 8.2'de
       offline oynanan hamleler web'de göründü, yani flush gerçek uçla
       uçtan uca çalışıyor; (2) Parça 43'ün offline listesi cihazda
       doğrulandı (uçak modunda Setup'a dönünce oyun listede, son
       oynandığı hâliyle).
     - **Hata OLMAYAN bir bulgu, aynı turda:** uçak modunda kelime anlamı
       "bulunamadı" dönüyor. Veri sağlam (`kurutaç` `meanings.json`'da VAR,
       63.890 kayıt) — sebep web derlemesine özgü: asset'ler uygulamaya
       gömülü değil HTTP ile indiriliyor, 5.26 MB'lık `meanings.db` uçak
       modunda çekilemiyor. Online'da çalıştığı kullanıcı tarafından
       doğrulandı. Native derlemede asset pakette olduğundan bu sorun
       yapısal olarak yok; `mobile/TESTING.md`'ye dürüst bir not eklendi.
   - ✅ **Parça 45 — depo açılamadığında offline hamleler SESSİZCE
     kayboluyordu; ayna kendisi bir kayıp yoluna dönüşebiliyordu (10 Ağustos
     2026, `cloud_save_repo.dart`, `setup_screen.dart`):** 8.5 testinde
     ortaya çıktı ve testin kendisi DÜŞTÜ — oyun terk sayılıp -2 yazıldı.
     - **Kanıt zinciri (sunucudan, tahminle değil):** kullanıcı offline
       oynadı, hamleler kayboldu; `local_game_saves` satırı SİLİNMİŞ ve
       `games`e 11:05'te bir teslim kaydı açılmıştı (k-lig -2 → -4). Yani
       bir senkron aynayı BOŞ bulmuş, 8 günlük satırı iddia etmiş.
       Hamlelerin kaybolması için `upsert`in İLK satırının (ayna yazması)
       fırlaması gerekir → depo o oturumda hiç açılmamış.
     - **Neden açılmamış (web'e özgü):** web derlemesinde SQLite
       `sqflite_sw.js` + `sqlite3.wasm` dosyalarını HTTP'den çekiyor; Safari
       arka plandaki sekmeyi atıp uçak modundayken yeniden yüklediyse bu
       fetch'ler başarısız olur. 8.2/8.3'te sayfa önce ONLINE yüklendiği
       için depo zaten açıktı — fark buydu. Native'de sqflite platform
       kanalı, indirilecek dosya yok.
     - **Ama iki GERÇEK hata ortaya çıkardı (native'de de geçerli):**
       (1) `upsert`te ayna yazması `try`ın DIŞINDAYDI ve çağrı `unawaited`
       — depo hata verirse tüm yazma fırlıyor, hata yutuluyor, hamle HEM
       yerelde HEM sunucuda kayboluyordu. Ayna veri kaybını ÖNLEMEK için
       eklenmişti; bu hâliyle kendisi bir kayıp yoluna dönüşüyordu.
       (2) `_syncCloud`'da `flushMirrored` fırlarsa `list()` HİÇ
       çalışmıyordu — tek bir depo hıçkırığı 7 günlük süpürme dahil tüm
       senkronu bloke ediyordu.
     - **Düzeltme:** depoya yapılan HER erişim artık `_tryMirror`/`_tryCache`
       üzerinden — hata izole edilip loglanıyor, çağıran akış devam ediyor.
       `upsert` ayna yazılamasa bile sunucuya yazmayı DENİYOR; ikisi de
       düşerse ayrı bir "KAYIP" logu basıyor (sessiz yutma yok).
       `_syncCloud`'da flush ayrıca `try` içinde (ikinci güvenlik ağı).
     - **Teşhis satırı:** Setup'ın alt satırı artık depo durumunu
       (`depo ok` / `DEPO YOK`) ve bekleyen ayna sayısını (`bekleyen N`,
       yalnızca >0 iken) gösteriyor. Bu olmadan aynı sınıf sorun ancak
       tahminle tartışılabiliyordu — cihazda görünür bir iz yoktu.
     - Doğrulama: `flutter analyze` temiz, **tam takım 296/296 yeşil**
       (294'ten +2). Negatif eş: `upsert`teki korumalı ayna yazması eski
       (korumasız) hâline çevrilince iki yeni test de GERÇEKTEN düştü
       (`Bad state: depo yok`), geri konunca yeşile döndü.
     - **Temizlik:** testin ürettiği sahte teslim kaydı (`games`
       `e750b8aa…`) silindi, T5'in k-lig puanı -4'ten -2'ye döndü. Oyunun
       kendisi kurtarılamadı — iddia satırı sildi, tam `GameState` hiçbir
       yerde saklanmıyor (yalnızca `board_snapshot`).
     - **8.5 aynı gün yeniden koşuldu ve GEÇTİ (cihazda, gerçek hesapla):**
       teşhis satırı `depo ok` gösterirken satır tekrar 8 gün geriye
       alındı; kullanıcı offline oynadı. Sunucudan üç kontrol de temiz —
       satır silinmedi, `turnCount` 16→22 / skor 144→181 (offline hamleler
       gitti), `updated_at` bugüne çekildi, k-lig **-2** kaldı ve fazladan
       `games` satırı açılmadı. Yani `flushMirrored`'ın `list()`ten ÖNCE
       koşması gerçek cihazda kanıtlandı.
     - **Geriye dönük not:** ilk (düşen) denemede `8ec0690a` satırının
       sunucuda `turnCount 4→8`e ilerlediği sonradan görüldü — yani depo o
       oturumda TAMAMEN ölü değildi, bir noktada çalışmıştı. "Depo hiç
       açılmadı" hipotezi bu yüzden kesin DEĞİL; kesin olan tek şey ayna
       yazmasının o an başarısız olduğu ve eski kodun bunu sessizce
       yuttuğu. Teşhis satırı bir dahaki sefere bunu tahmine bırakmayacak.
   - ✅ **Parça 46 — offline biten oyun "devam eden" olarak geri geliyordu:
     yazmaların kalıcı kuyruğu vardı, SİLMELERİN yoktu (10 Ağustos 2026,
     `app_database.dart` v4, `cloud_save_mirror_store.dart`,
     `cloud_save_repo.dart`):** TESTING.md 8.6 koşulurken bulundu ve ben
     bunu adımları verirken önceden tahmin etmiştim — kullanıcı doğruladı.
     - **Mekanizma:** oyun bitince `CloudGameSession` satırı siliyor;
       uçak modunda `gateway.delete` fırlıyor, `catch` yalnızca logluyordu.
       Ayna ve önbellek temizlendiği için oyun offline'da listeden
       kayboluyor, ama sunucudaki BİTMEMİŞ eski kopya duruyor — ağ dönünce
       `list()` onu canlı bir oyun sanıp geri getiriyordu. `list()`'in
       bitmiş satırları temizleyen dalı da devreye giremiyor, çünkü
       sunucudaki state hiç "bitmiş" hâle gelmemişti (o yazma da offline'da
       düşmüştü).
     - **Düzeltme:** yeni `pending_cloud_deletes` tablosu (şema v4) +
       `CloudSaveDeleteQueue`. `delete(id, userId:)` başarısız olursa id
       kuyruğa yazılıyor, `flushMirrored` yazmalardan SONRA / listelemeden
       ÖNCE bekleyen silmeleri tekrar deniyor, başarınca kuyruktan düşüyor.
       Sıra bilinçli: silme aynayı zaten temizlediğinden yazma/silme
       çakışması yok, ama liste birazdan silinecek satırı bir kez daha
       göstermemeli.
     - **`user_id` neden kuyrukta:** başka bir hesap açıkken onun adına
       silme denemek RLS'te sessiz no-op olur ve kuyruk sonsuza dek dolu
       kalırdı.
     - **Asıl ders — SAHTE UÇ, gerçek ucun HER hata yolunu taklit etmeli:**
       `FakeGateway.delete` `offline` bayrağını YOK SAYIYORDU (list ve
       upsert sayıyordu). Yani "uçak modunda silme başarısız olur" senaryosu
       testlerde hiç oluşmuyordu ve bu hata sınıfı yapısal olarak
       görünmezdi — 25 test yeşilken bile. Sahtenin eksik bir hata yolu,
       o yol hakkında testleri sessizce anlamsız kılıyor. Yeni bir gateway
       metodu eklerken "bu gerçek uçta nasıl patlar?" sorusu sahteye de
       sorulmalı.
     - Doğrulama: `flutter analyze` temiz, **tam takım 298/298 yeşil**
       (296'dan +2). Negatif eş: kuyruğa alma satırı kapatılınca iki test de
       düştü — ikincisi kullanıcının gördüğü hatayı birebir üretti
       (`Expected: empty / Actual: [Instance of 'CloudSave']`).
     - **Temizlik:** testin sunucuda bıraktığı artık satır (`74d38003…`,
       bitmiş oyunun bitmemiş kopyası) elle silindi.
     - **Cihazda doğrulandı (aynı gün, 8.6 yeniden koşuldu):** offline
       bitirilen oyun ağ dönünce listeye GERİ GELMEDİ; sunucuda
       `local_game_saves` satırı kalmadı, `games`te tek kayıt var, k-lig
       beklenen +2'yi aldı (iki beraberlik: -2 → 0 → 2).
     - **Gözlenen küçük pencere (bilinçli, düzeltilmedi):** kullanıcı,
       oyunun listede KISA BİR SÜRE görünüp sonra kaybolduğunu bildirdi.
       Sebep: ağ dönünce `_syncCloud` iki ayrı yoldan tetiklenebiliyor
       (öne dönüş + bir auth olayı). TEK bir `_syncCloud` içinde silme
       listelemeden önce biter, ama EŞZAMANLI iki çağrı arasında bu sıra
       garanti değil — biri listeyi çekerken diğerinin silmesi henüz
       tamamlanmamış olabiliyor. Kendini bir saniyede toparladığından ve
       veri açısından zararsız olduğundan şimdilik bırakıldı; gerçek çözüm
       `_syncCloud`u da tek bir kuyruğa almak olurdu (`TableWriteQueue`
       deseni, bu sefer senkron akışı için).
     - **Web'de de aynı gedik var** (offline biten oyunun satırı silinemezse
       unutuluyor) — kök `CLAUDE.md`'nin "Web'de Yapılacak İşler" listesine
       eklendi.
   - ✅ **Parça 47 — joker seçici alttan açılan SAYFAYDI, web ortalanmış bir
     MODAL kullanıyor; Parça 20 yalnızca semptomu yamamıştı (10 Ağustos
     2026, `wild_letter_sheet.dart`):** Kullanıcı ekran görüntüsüyle
     "düzelmedi" dedi ve haklıydı — 8 Ağustos'ta yükseklik sınırını
     (`isScrollControlled`) düzeltmiştim ama YAPI farkı duruyordu.
     - **Web kaynağı (önce okundu):** `WildcardModal.tsx` paylaşılan
       `Modal`'ı kullanıyor (ortalanmış 360px kart, başlık + ✕), ızgara
       `grid-cols-6 gap-1.5` ve her hücre `h-11` = **sabit 44px yükseklik**.
     - **Portun iki sapması:** (1) `showModalBottomSheet` — alttan açılıyor,
       başlık çubuğu/✕ yok; (2) `GridView.count` KARE hücre üretiyor ve
       sheet ekran genişliğini kapladığından iPad'de taş ~128px'e şişiyordu
       (web'in 360px kartında ~50×44). Kullanıcının gördüğü devasa harfler
       buydu.
     - **Düzeltme:** `KModal` + `showDialog`; ızgara `GridView.builder` +
       `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent: 44)`
       (`GridView.count` sabit yükseklik veremiyor, yalnızca en-boy oranı);
       "GERİ AL" `OutlinedButton`dan `NeoButton(neutral)`a çevrildi (web
       `.btn-raised-neutral`).
     - **Yan kazanç — başlık artık BÜYÜK HARF:** `KModal` başlığı
       `trUpper`dan geçiriyor (web'in `uppercase` CSS'i). Eski sheet düz
       yazıyordu; testlerdeki beklentiler de buna göre güncellendi. Yani
       yapıyı web'e çekmek, farkında olmadığımız bir tipografi sapmasını da
       kapattı.
     - **Ders (üçüncü kez):** semptomu bastıran yama, yapıyı web'e çekmekten
       PAHALIYA geliyor. Parça 16→17 ve 39→40'ta da aynı şey oldu; bu sefer
       maliyeti kullanıcının aynı sorunu iki kez bildirmesi oldu. Bir görsel
       sorun bildirildiğinde ilk soru "web bunu hangi BİLEŞENLE yapıyor?"
       olmalı, "hangi değeri ayarlarsam düzelir?" değil.
     - Doğrulama: `flutter analyze` temiz, **tam takım 299/299 yeşil**
       (298'den +1). Negatif eş: dosya `git stash` ile eski hâline
       döndürülünce 3 test düştü, geri alınınca yeşile döndü.
     - **Doğrulama sınırı:** cihazda görsel teyit kullanıcıdan bekleniyor.
   - ✅ **Parça 48 — GameOver'ı KAPATMAK "Görüş Bildir" formunu açmıyordu;
     web'in `onClose` yan etkisi hiç port edilmemişti (10 Ağustos 2026,
     `game_screen.dart`, `online_game_screen.dart`):** Kullanıcı TESTING.md
     bölüm 9'u koşarken buldu — bir oyunu sonuna kadar bitirip modaldaki
     "GÖRÜŞ BİLDİR" linkine BİLEREK dokunmadı, çünkü web'de ekranı kapatmak
     zaten formu açıyor; app'te hiçbir şey olmadı.
     - **Web kaynağı önce okundu (kuralın ilk adımı):** `src/App.tsx`
       (~1509-1518) ve `src/components/OnlineGameScreen.tsx` (~1306-1316)
       `<GameOver>`e İKİ ayrı callback geçiyor ve **ikisi de aynı formu
       açıyor** — `onOpenFeedback={() => setShowFeedback(true)}` (modal
       içindeki link) VE `onClose={() => { setGameOverDismissed(true);
       setShowFeedback(true); }}` (modalı kapatmak). Port yalnızca
       birincisini taşımıştı; `onClose`un ikinci satırı iki ekranda da
       hiç yoktu.
     - **Kapsam BİREBİR aynı, tesadüfen değil:** web'de kapatmanın HER
       yolu tek bir `onClose`a gidiyor (`Modal.tsx:25` backdrop'ta
       `onClick={onClose}`, ✕ butonu ve Escape aynı fonksiyonu çağırıyor).
       Flutter'da `showDialog`ın Future'ı ✕ / bariyer dokunuşu / Android
       geri tuşunun ÜÇÜNDE DE tamamlandığından, `await showGameOverModal
       (...)` sonrası formu açmak aynı üç yolu birden kapsıyor — ayrı bir
       "nasıl kapatıldı" ayrımı yapmaya gerek yok.
     - **İki ekranda birden**, çünkü bu dosyanın "Etki Analizi" bölümündeki
       değişmez tam olarak bunu söylüyor: `game_screen.dart` (yerel/YZ) ve
       `online_game_screen.dart` (Canlı) web'in App.tsx ↔ OnlineGameScreen.tsx
       ayrımının birebir eşleniği; birinde değişen davranış öbüründe de
       AYNI PR'da değişmeli. Bu parça o kuralın uygulandığı bir örnek —
       hata iki dosyada da vardı ve iki dosyada da düzeltildi.
     - **`auth == null` iken form HİÇ açılmıyor** (misafir değil,
       `AuthService` hiç enjekte edilmemiş önizleme/test durumu) — mevcut
       `onFeedback: auth == null ? null : ...` deseniyle tutarlı;
       `mounted` kontrolü `await`ten sonra tekrarlanıyor (ekran bu arada
       sökülmüş olabilir).
     - **Test — negatif eş doğrulamasıyla, İKİ AYRI dosya:** mevcut
       `game_screen_test.dart` GameOver testine kapatma sonrası formun
       başlığının ("GÖRÜŞLERİNİZ BİZİM İÇİN ÖNEMLİ", `trUpper`) göründüğü
       assertion'ı eklendi; `online_game_screen_test.dart`'ın `pumpScreen`
       yardımcısına `isGameOver` parametresi eklenip yeni bir test yazıldı
       (✕ → form açılmalı). İki lib dosyasının düzeltmesi `git stash` ile
       geçici geri alınıp her iki dosya AYRI AYRI koşuldu — ikisi de
       GERÇEKTEN `+0 -1: Some tests failed.` ile düştü, geri konunca
       yeşile döndü.
     - Doğrulama: `flutter analyze` "No issues found!"; **tam takım
       300/300 yeşil** (299'dan +1). `kelimeki_core`'a hiç dokunulmadı.
     - **Doğrulama sınırı:** cihazda teyit kullanıcıdan bekleniyor —
       9.3/9.4 bu düzeltme deploy edildikten sonra yeniden koşulacak
       (`mobile/TESTING.md` bölüm 9'a ayrı bir madde eklendi).
6. **Çok kullanıcılı eşzamanlılık testi** — iki gerçek oturumlu headless
   harness (web tarafında hiç yapılamamış e2e; PORT_BRIEF'te "unproven"
   olarak işaretli); `p_move_id` retry davranışı da bu harness'te gerçek
   HTTP/PostgREST katmanıyla ayrıca doğrulanmalı (şimdilik yalnızca SQL
   seviyesinde doğrulandı).
