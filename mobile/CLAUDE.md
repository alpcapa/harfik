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
2. **Parça günlüğü + ağaç:** parça günlüğüne giriş (ne yapıldı, hangi web
   dosyasının portu, bilinçli eksikler, bulunan hatalar/dersler, doğrulama
   ve doğrulama SINIRI) `mobile/docs/parca-log.md`'ye; **yeni dosyalar
   `mobile/docs/klasor-yapisi.md`'deki açıklamalı ağaca** (4 Eylül 2026'da
   oraya taşındı — bu dosyadaki özet ağaç yalnızca KLASÖR düzeyinde, bir
   klasör eklendiyse ikisi de); "Sıradaki parçalar" satırının güncellenmesi.
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
kod doğruydu, sitede yoktu. Kural zaten vardı ve yine atlandı — bu yüzden
çözüm bir kural DEĞİL, bir MEKANİZMA: derleme kimliği ürünün İÇİNDE.
Vaka kaydı: `mobile/docs/deploy-verification.md`.

### Nerede ne yayınlanır

| Yüzey | Nereden yayınlanır | Ne zaman |
|---|---|---|
| `kelimeki.com` (web app) | Vercel | `main`'e her merge |
| `alpcapa.github.io/kelimeki` (Flutter test ortamı) | Actions `mobile-build.yml` → Pages | YALNIZCA `main`'e push **ve** `mobile/**` değiştiyse (2 Eylül 2026'dan beri `mobile/**.md` HARİÇ — yalnızca doküman değişen bir PR artık derleme başlatmıyor; `.dart` ile birlikte değişirse KOŞAR) |
| Supabase (migration/Edge Function) | MCP ile doğrudan | Anında — dal/merge ile İLGİSİZ |

**Feature dalındaki bir commit sitede ASLA görünmez.** Bir PR açmak da
yetmez (workflow PR'da bilerek yayınlamıyor).

⚠ **AMA `mobile-latest` RELEASE'İ İÇİN BU GEÇERLİ DEĞİL:** yükleme adımının
koşulu `github.event_name != 'pull_request'`, yani bir DALA push da
yayınlıyor — yalnızca PR koşuları hariç. **Dalda çalışırken
`mobile-latest`in `main`'in derlemesi olduğunu VARSAYMA**; kurulan
derlemenin sha'sını Setup'ın teşhis satırından oku. Tablonun üçüncü satırı
tersine bir tuzak: sunucu değişikliği anında canlıdır, yani istemci
düzeltmesi henüz yokken sunucu davranışı değişmiş olabilir.
(29 Ağustos 2026 vakası: `mobile/docs/deploy-verification.md`.)

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

⚠ **TERSİ GEÇERLİ DEĞİL — "sürüm doğru" ≠ "özellik içinde".** Teşhis satırı
`main`'in son sha'sını gösterirken özellik yalnızca bir PR dalında olabilir;
github.io **yalnızca `main`'e push'ta** yayınlanır.

⚠ **ÜÇÜNCÜ tuzak — Play kapalı testinde "Published" ≠ testçinin
telefonunda.** Console yayınlanmış gösterirken cihazdaki paket saatlerce bir
önceki olabiliyor. Üç tuzağın da (bayat derleme · yanlış dal · Play gecikmesi)
tek enstrümanı aynı: **önce `Derleme <sha>` satırını oku.** Ayrıntı ve
`versionCode` ↔ koşu numarası eşlemesi:
`mobile/docs/build-and-distribution-log.md` → "Kapalı test: Published ≠
testçinin telefonunda".

Derleme kimliği *"bayat bir derlemeye mi bakıyorum?"* sorusunu cevaplar;
*"şu özellik bunun içinde mi?"* sorusunu CEVAPLAMAZ. Henüz merge edilmemiş
bir değişiklik için sha eşleşmesi hiçbir şey kanıtlamaz. Doğru soru şu:
**bu yüzey hangi daldan yayınlanıyor ve değişiklik o dalda mı?** (Tablo
yukarıda.) Merge etmeden cihazda görmek gerekiyorsa tek yol dalda bir
`workflow_dispatch` koşusu.

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
- **DÜZELTME 2 (2 Eylül 2026, ölçüldü): `curl` DE ÇIKIYOR** — ajan vekili
  üzerinden `curl -s https://kelimeki.com/ | grep kelimeki-build` derleme
  sha'sını doğrudan veriyor. Deploy doğrulaması için tercih edilen yol bu:
  `WebFetch` içeriği markdown'a çevirdiğinden `<meta>` etiketlerini GÖSTERMEZ,
  yani sha'yı okuyamaz. Aşağıdaki madde (ve kök `CLAUDE.md`'nin eski hâli)
  "`curl` çıkamıyor" diyordu; artık geçerli değil.
- **DÜZELTME (25 Ağustos 2026, ölçüldü): WEB yüzeyini açıp okuyabiliyorum.**
  O günkü "`curl`/`bash` siteye çıkamıyor" tespiti (yukarıda düzeltildi) ile
  birlikte yazılmıştı; `WebFetch` ARACI
  `https://kelimeki.com`'a ulaşıyor — o gün `/.well-known/assetlinks.json`
  (henüz yayında değildi → SPA kabuğu) ve `/gizlilik/` (statik sayfa, doğru
  başlıkla) ayrı ayrı okundu, yani araç hangi sayfanın servis edildiğini
  ayırt edebiliyor. **Sınırı:** içerik küçük bir modelle markdown'a
  çevriliyor — "doğru şey mi yayında" sorusunu cevaplar, `Content-Type`/
  başlık/bayt ölçümü YAPMAZ. Bir web düzeltmesinin canlıda olduğunu
  söylemeden önce artık kullanıcıdan ekran görüntüsü beklemek yerine
  doğrudan bakılabilir.
- **Flutter/Pages yüzeyi için `WebFetch` İŞE YARAMIYOR (29 Ağustos 2026'da
  ölçüldü):** `https://alpcapa.github.io/kelimeki/` çekildi ve dönen tek şey
  `kelimeki` başlığı oldu — 404 değil, yani sayfa servis ediliyor, ama araç
  JavaScript çalıştırmadığından canvas'a çizilen Flutter uygulamasının
  açılıp açılmadığını GÖSTEREMEZ. Web (React) tarafında işe yaramasının
  sebebi metnin HTML'de olması; Flutter web'de değil. Pages yüzeyinin
  "açılıyor mu" sorusu hâlâ yalnızca ekran görüntüsüyle cevaplanabilir.
- Siteyi ben açıp bakamam (yalnızca yukarıdaki istisna dışında).
  **Ekran görüntüsü tek enstrümandır** — derleme
  kimliğinin ürüne gömülmesinin asıl gerekçesi budur.

### Merge sonrası dal hijyeni (bugünün ikinci hatası)

Merge edilmiş bir dala commit eklemeye devam etmek aynı işi İKİ kez var
eder; `main` squash merge kullandığından bir sonraki merge'de çakışma
üretir — ve çakışmayı derleyiciye güvenerek çözemezsin, tekrarlanan JSX'i
hiçbir şey yakalamaz (`npm run lint` + mükerrer bildirim taraması şart).
28 Ağustos 2026'dan beri GitHub merge edilen dalı kendiliğinden siliyor;
tuzağı da beraberinde geliyor: **silinmiş bir dala push etmek onu
DİRİLTİR.** Vaka kaydı: `mobile/docs/deploy-verification.md`.

**Her merge'den SONRA yeni bir dal aç:**
`git fetch origin main && git checkout -B <YENİ-dal> origin/main`
(Yerel kopya duruyorsa `git branch -D <eski-dal>` ile onu da sil — yoksa
yanlışlıkla üstüne commit atmak hâlâ mümkün.)

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

Bu adımın 15 Ağustos 2026'da nasıl kırıldığı (boşluk taşıyan bir
`--dart-define` tırnaksız kaldı, `flutter test` bunu göremez) ve
*"koşu yok"* demeden önce hangi filtrenin neyi elediği:
`mobile/docs/deploy-verification.md`.

## Flutter SDK bu ortamda HAZIR — Dart'ı körlemesine yazma (26 Ağustos 2026;
## 4 Eylül 2026'da otomatikleşti)

⚠ **Aşağıdaki elle kurulum artık oturum başında KENDİLİĞİNDEN yapılıyor**
(`.claude/hooks/session-start.sh`): Flutter stable indirilir, iki paketin
`pub get`i çözülür ve `flutter`/`dart` PATH'e girer. Yani `flutter test`,
`dart analyze` ve `dart run test/run_all.dart` doğrudan koşulabilir —
soğuk konteynerde ~2,5 dk, sonraki oturumlarda ~2 sn (önbellekli).
Blok, hook koşmadığı bir bağlamda (yerel makine, hook devre dışı) elle
yapmak için duruyor.


Uzun süre "bu ortamda Flutter SDK yok, kanıt CI" diye çalışıldı. **Bunun
bedeli o gün ödendi:** `board_widget.dart`'ta bir blok taşınırken fazladan
bir `}` kaldı, `build()` orada kapandı, gerisi sınıf üyesi olarak ayrıştı ve
CI'da **84 hata** çıktı. Hepsi tek kök sebebin devamıydı.

**Neden hiçbir yerel kontrol yakalamadı:** fazladan bir `}` dosyayı
**sözdizimsel olarak GEÇERLİ** bırakıyor — `dart format` sorunsuz
ayrıştırıyor, parantez dengesi de tutuyor (metot erken kapanıyor, dosya
değil). Kırılma ANLAMSAL; onu yalnızca `dart analyze` görür.

**Yapılabiliyor (ölçüldü):** SDK indirilebiliyor VE `pub get` çözülüyor.

```bash
SC=<scratchpad>              # oturuma özel; her yeni oturumda TEKRAR gerekir
cd $SC && curl -sS -L -o f.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz
tar xf f.tar.xz && export PATH=$SC/flutter/bin:$PATH
flutter --disable-analytics
cd mobile/app && flutter pub get && dart analyze lib/ test/ && flutter test
```

⚠ **Sürüm CI'ınkiyle AYNI olmalı, "bir Flutter" yetmez.** (30 Ağustos
2026'da CI **3.47.2**'ye geçmişti; o gün yerelde 3.47.1 kullanıldı ve
sonuçlar CI ile örtüştü, ama yama farkı bir garanti değil — koşu log'undaki
önbellek anahtarından oku.) Önce 3.27.1
denendi ve `pub get` ÇÖZÜLMEDİ: `flutter_native_splash >=2.4.5` `path
^1.9.1` istiyor, o Flutter'ın `flutter_test`i ise `path 1.9.0`a sabitliyor.
CI'ın sürümü koşu log'unda yazılı (`flutter-linux-stable-<sürüm>-x64` önbellek
anahtarı) — oradan oku, tahmin etme.

Maliyet: ~700 MB indirme, birkaç dakika. **Bir Dart değişikliğini
göndermeden önce bu üç komutu koş** — bugün 524 test + `dart analyze` (exit
0) burada koşturuldu ve CI'la birebir aynı sonucu verdi (`[ÖLÇÜM]` satırları
dahil). "Kanıt CI" artık yalnızca native derleme (apk/ipa) için geçerli bir
sınır.

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
grep -rn "shareOriginFrom(context)" app/lib/                # iPad ankrajı: DÜĞMENİN kutusu şart, State.context ekranın TAMAMI olur ve paylaşım iPad'de ASILI KALIR (bkz. Parça 181)
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
akışını, mesaj satırı kuralını ve tahta zoom'unu (çift dokunuş + pan,
`board_zoom.dart` — Parça 175) BİLİNÇLİ olarak ayrı ayrı taşıyor — web'in
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

## Üst Düzey Kararlar

⚠ Bu bölümün başlığı 24 Ağustos 2026'daki doküman bölmesinde yanlışlıkla
"Parça Bitirme Kontrol Listesi" olmuştu — yani dosyada aynı başlık İKİ kez
vardı ve gerçek ad kayıptı. Kök `CLAUDE.md` buraya *"Üst Düzey Kararlar" #4*
diye atıf yapıyor; atıf 31 Ağustos 2026'ya kadar KIRIKTI.

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
   `mobile/app/assets/dictionary/meanings.db`, 63.905 kelime, **5.26 MB ham
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
| **Klasör yapısı — açıklamalı TAM ağaç** (dosya başına gerekçe/uyarı). Bu dosyadaki özet yalnızca klasör düzeyinde | `mobile/docs/klasor-yapisi.md` |
| Backend hazırlığı (submit_move idempotency, 5 Ağustos 2026) + Depolama katmanı + Flutter iskeleti + uygulama ikonu/splash + MembershipPerksBox + ilk doğrulama durumu (5 Ağustos 2026) | `mobile/docs/setup-log.md` |
| **SÜRÜM KÜTÜĞÜ — Play'e yüklenen her paket** (sürüm · versionCode · sha · tarih · durum · sürüm notları). "Hangi paket yayında?" sorusunun TEK cevap yeri | `mobile/docs/surumler.md` |
| Web derlemesi (test ortamı), Appetize, Play Store imzalama/.aab, karşılama katmanının web'e özgü ayrışması | `mobile/docs/build-and-distribution-log.md` |
| **Web ↔ Uygulama Arasındaki Kabul Edilmiş Farklar — Parça günlüğü** (DÖRT cilt, yukarıdaki tabloya bak) | `mobile/docs/parca-log.md` + `-110-138` + `-49-109` + `-1-48` |
| FAZ A1 — cihaz testi tur durumu | `mobile/docs/cihaz-testi-log.md` |
| Cihaz testi — Arkadaşlar + Canlı oyun bölümleri (iki gerçek oturum ister) | `mobile/docs/testing-arkadaslar-canli.md` |
| Cihaz testi — web ile yan yana GÖRSEL karşılaştırma (parite denetimi, §0.5) | `mobile/docs/testing-gorsel-karsilastirma.md` |
| Cihaz testi — etkileşim/görünüm turları (tarihli: dokunma hedefleri, sürükleme eşiği, yazı boyutu, akıcılık, zoom) | `mobile/docs/testing-ux-turlari.md` |
| Cihaz testi — push bildirimleri + derin bağlantılar + **güncelleme** (çoğu Play imzalı derleme ister) | `mobile/docs/testing-bildirimler.md` |
| Deploy doğrulaması — tarihli post-mortem'ler (dal hijyeni, "koşu yok" filtresi, PR #267, sınıf 2 risk kütüğü) **+ 31 Ağustos 2026'da buradan taşınan gerekçeler: 15/29 Ağustos deploy vakaları, güncelleme modelinin 1.0.1 ölçümü ve 1.0.0 süpürmesi, yazı boyutu envanteri** | `mobile/docs/deploy-verification.md` |
| Sonraya bırakılan mobil işler (karar verildi, henüz yapılmadı — KGP uyarısı, iOS borçları) | `mobile/docs/sonraya-birakilanlar.md` |

**Yeni bir "Parça N" notu eklerken:** parça numarasını bir öncekinin devamı
olarak ver ve **AKTİF cilde** (`mobile/docs/parca-log.md`) yaz — dondurulmuş
ciltlere ASLA (`check-doc-size` bunu yakalar). Aktif ciltte girişler en yeni
EN ÜSTTE duruyor, yenisini oraya ekle. Eğer not HER PARÇAYI ilgilendiren bir süreç kuralıysa (ör.
"her yeni ekranda bu kontrolü de yap" gibi) o zaman bu dosyadaki ZORUNLU
bölümlerden birine (Etki Analizi / Parça Bitirme Kontrol Listesi) eklenmeli,
tek bir parçanın notuna değil.

## Klasör Yapısı

**Açıklamalı TAM ağaç (dosya başına gerekçe/uyarı) buradan taşındı:
`mobile/docs/klasor-yapisi.md`** — 4 Eylül 2026, doküman boyutu bütçesi
(bu dosya `auto` sınıfı, her turda yükleniyor ve ağaç tek başına 24,5 KB'dı).
Bir dosyanın nerede durduğunu ya da yanındaki uyarıyı ararken o dosyayı
**grep'le**, baştan sona okuma.

Aşağıdaki özet yalnızca KLASÖR düzeyinde — "hangi katman neyi yapar"
sorusunu cevaplar, "bu dosya neden böyle" sorusunu cevaplamaz.

```
mobile/
  CLAUDE.md                # bu dosya (kural/değişmez)
  docs/                    # karar kayıtları + açıklamalı ağaç (yukarıdaki tablo)
  app/                     # Flutter uygulaması
    pubspec.yaml
    web/                   # Flutter web iskeleti — TEST ORTAMI, ürün değil
    assets/                # ÜRETİLMİŞ varlıklar (aşağı bkz.) + fontlar
    lib/main.dart          # portre kilidi + bootstrap + runApp
    lib/src/
      bootstrap.dart       # AppServices: sözlük Future'ı + supabase + sürüm kapısı
      config/              # env.dart (--dart-define, appVersion) + version_gate
      data/                # TEK veri katmanı: Supabase RPC sarmalayıcıları,
                           # depolar, dayanıklı kuyruklar, FCM/GA4 uçları,
                           # deep link gelen kutuları, Play In-App Update
      game/                # game_controller — ChangeNotifier motor kabuğu
      storage/             # SQLite + prefs (app_database/app_storage/…)
      ui/                  # ekranlar + widget'lar: app.dart, theme, tokens,
                           # auth/ intro/ game/ live/ score/ rank/ chat/
                           # setup/ friends/ feedback/ push/ + paylaşılan
                           # kabuklar (KModal/KDialogCard/NeoBox/KIconButton)
      util/                # saf yardımcılar: deep_link, push_rules, semver,
                           # share_board + web ikizleri (game_list_order,
                           # recent_game_avatars, head_to_head, score_line, platform,
                           # away_return, ai_level)
    test/                  # util + controller (golden replay) + widget testleri
                           # + support/ (paylaşılan test altyapısı)
    android/ ios/          # flutter create çıktısı + elle değişiklikler
  kelimeki_core/           # SAF Dart motor paketi — Flutter bağımlılığı YOK
    lib/src/               # constants · model · engine · rules · ai · data ·
                           # text · dictionary · online · serialize · rng
    test/run_all.dart      # `dart run test/run_all.dart` + goldens/*.json
```

**Ağaçtan çıkan, her zaman geçerli İKİ kural** (+ bir sözleşme: YZ zorluğunda
**Normal HİÇ YAZILMAZ** — `StartAction(aiLevel: null)`, `NewGameRecord`
`ai_level`i yalnızca doluysa; "alan yok = Normal" web/golden/bulut kaydı/
sunucu `coalesce` ile ortak, bkz. ROADMAP #23):

1. **ÜRETİLMİŞ dosyalar elle düzenlenmez** — kaynağı değiştir, üreticiyi koş:
   `assets/icon/*` (`mobile/scripts/generate-app-icon-masters.mjs`) ·
   `assets/dictionary/words_tr.txt` + `kelimeki_core/test/goldens/*.json`
   (`npm run generate-golden-vectors`) ·
   `assets/dictionary/meanings.db` (`npm run generate-meanings-db`) ·
   `ui/intro/demo_board_data.dart` (`npm run generate-demo-board-dart`) ·
   `ui/game/logo_mark_data.dart` (`npm run generate-logo-paths`) ·
   `ui/score/klig_mark_data.dart` (`npm run generate-klig-paths`) ·
   `assets/fonts/MPLUSRounded1c-ExtraBold-subset.ttf` (web'in subset'iyle
   AYNI) · `web/sqflite_sw.js` + `sqlite3.wasm` (derlemede ağa çıkılmasın
   diye repoda tutulur).
2. **ELLE senkron tutulan web↔port çiftleri** — derleyici görmez, uyuşmazlık
   SESSİZ arızadır. Çoğunun bir kapısı var (`app/test/*_parity_test.dart`:
   özellik ikonları, ilişki ikonları, MethodChannel/bildirim kanalı adları,
   k-lig kademeleri, `platform.dart`in değer kümesi ↔ sunucu kısıtı, yardım
   metni, giriş sekmesi kuralı, `appVersion` ↔ `pubspec`, YZ zorluğunun
   etiket/seçilebilir liste/seviye açıklamaları (hitap cümlesi + puan)/yardım paragrafı —
   `ai_level_parity_test`, 6 Eylül 2026) — **yeni bir
   elle-senkron çift eklerken testini de yaz**, desen hazır (web kaynağını/
   migration'ı okuyup karşılaştır). Bugün kapısı OLMAYAN iki çift:
   `intro_screen.dart` metinleri ↔ `Landing.tsx`, ve k-lig kademe
   tablosunun SQL yarısı (`_award_league_rewards`in güncel tanımı tek bir
   migration dosyasında durmadığından ancak canlıda doğrulanır).

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

## Ham `IconButton` KULLANMA — `KIconButton` (48×48)

Material'ın `IconButton`'ı bir dokunma asgarisi GARANTİ ETMEZ:
`visualDensity: VisualDensity.compact` kutuyu 48 → **40**, üstüne
`padding: EdgeInsets.zero` daha da aşağı indirir (ölçüldü: `KDialogCard`'ın
✕'i **28×28**'di). 24 Ağustos'un 48 dp turu bunları kaçırmıştı, çünkü
kaynak taraması `IconButton`ı "kutusuna ölçü veren" işaretlerden biri
sayıp geçiyordu.

**Kural:** başlıktaki/köşedeki her ikon düğmesi `KIconButton`
(`ui/tap_target.dart`) — 48×48, sıfır dolgu. `tap_target_test.dart`'taki
kaynak taraması `lib/src/ui` altında ham `IconButton` bırakılmasını
engelliyor; bilinçli bir istisna gerekirse gerekçesi O TESTE yazılır.

⚠ **Büyüttüğün kadar dolgudan kıs.** Hedefi büyütmenin gizli maliyeti
düzeni kaydırmaktır. `KModal` başlık dolgusu bu yüzden `20/12/16` →
`16/8/12`, köşe butonlarında `Positioned` 8 → 4 oldu; sonuç ✕'in
ekrandaki yerinin BİREBİR aynı kalması (`tap_target_test.dart` bunu golden
rect ile kilitliyor). Yeni bir yere ✕ koyarken aynı takası yap.

**Web'de karşılığı BAŞKA:** DOM'da sözde-eleman düzeni etkilemediğinden
telafi gerekmez — tek bir `.tap-expand` sınıfı (`src/index.css`) 48×48'lik
bir `::after` koyar. Yani bu kuralın iki yakası aynı SONUCU farklı yolla
üretir; port tarafında sözde-eleman diye bir şey yok.

Ayrıntı ve ölçümler: `docs/decisions/touch-ux-bugs.md` → "İkinci tur",
`mobile/docs/parca-log.md` → Parça 147.

## Güncelleme — Play SORAR, biz satır tutmayız (30 Ağustos 2026)

Kullanıcı kararı, sözleri birebir: *"Kimde hangi versiyon olursa olsun,
app'i açtığında daha yeni bir sürüm varsa uyarsın ve yapsın. Bu kadar
basit."*

**Öncesinde tek mekanizma `app_config.mobile_min_supported_version` idi** —
bir insanın Supabase'de bir satırı elle yükseltmesini bekleyen, ikili (ya
tamamen engelle ya hiçbir şey yapma) bir kapı. Sahada ölçüldü ki
çalışmıyordu (1.0.1 iki gün yayındayken kitlenin neredeyse tamamı hâlâ
1.0.0'daydı); rakamlar ve o günün kararı:
`mobile/docs/deploy-verification.md` → "Güncelleme modeli".

### Bugünkü model — iki katman, karıştırma

| Katman | Ne zaman | Nerede |
|---|---|---|
| **Play In-App Update** (GÜNLÜK yol) | her açılışta otomatik | `data/store_update.dart` + `_HomeGate` |
| `mobile_min_supported_version` (ACİL FREN) | yalnız sunucu sözleşmesi kırılınca | `config/version_gate.dart` |

**Günlük yolda kimsenin bir şey hatırlaması gerekmiyor:** güncelleme olup
olmadığını Play'in kendisi biliyor. Uygulama açılışta soruyor, varsa
**Immediate** akışını başlatıyor (tam ekran, Play çiziyor, güncelleme
uygulamanın İÇİNDE tamamlanıyor). Sunucuda tutulan bir sürüm numarası YOK.

⚠ **Eşiği artık RUTİN olarak yükseltme.** Her sürümde `app_config`'e
dokunmak bu modelde bir gerileme olur — o satır yalnızca "eski istemciyi bir
sunucu değişikliği kırdı" durumunda çekilir.

### ÜÇ SINIR — üçü de yapısal, gizlenmesin

1. **Yalnızca ANDROID.** iOS'ta karşılığı olan bir API yok. iOS günü gelince
   ayrı bir yol gerekir (App Store lookup + mağazaya yollama); bugün
   YAZILMADI, çünkü iOS yayında değil ve yazılsa test edilemezdi.
2. **Yalnızca Play'den KURULMUŞ pakette çalışır.** CI'ın debug `.apk`'sı yan
   yüklendiğinde Play uygulamayı tanımaz ve kontrol sessizce `bilinmiyor`
   döner. **Bu özelliğin cihaz doğrulaması ancak kapalı test kanalından
   kurulan derlemede yapılabilir** — bunu bilmeyen `.apk`da "çalışmıyor"
   diye saatlerce arar.
3. **Kod hangi sürümdeyse o sürümden İTİBAREN çalışır.** In-App Update
   1.0.2'nin içinde; sahadaki 1.0.0 kitlesi onu ancak 1.0.2'ye geçtikten
   sonra görür. Bu, mekanizmanın 1.0.0'da olmamasının bir seferlik faturası.

### 1.0.0 kitlesini bir kereye mahsus süpürmek — YAPILDI

Eşik 1.0.2'ye çekildi ve bu **son kez**; bir daha yükseltilmeyecek. Kimin ne
gördüğü, 1.0.0'ın butonsuz ekranının neden geriye dönük düzeltilemediği:
`mobile/docs/deploy-verification.md` → "Güncelleme modeli".

### Sürüm turunda hâlâ geçerli olan tek sıra kuralı

1. `appVersion` (`config/env.dart`) + `pubspec` sürümünü **birlikte** artır
   (`app_version_parity_test` ayrışmayı yakalar).
2. Derle, mağazaya yükle.
3. **Yeni sürümün gerçekten İNDİRİLEBİLİR olduğunu doğrula** — Play'de
   yayınlanması ile testçinin telefonuna inmesi AYNI ŞEY DEĞİL (bkz.
   `mobile/docs/build-and-distribution-log.md` → "Kapalı test").
4. Acil fren gerekiyorsa ANCAK BUNDAN SONRA eşiği yükselt.

⚠ Kapı **fail-open** (ağ hatasında kilitlemez), yani asıl risk ağ değil
SIRA: 4. adımı 3'ten önce yapmak, herkesi indirilemeyen bir güncellemeye
yönlendirmek demek.

### Neden `UpdateRequiredScreen`'in butonu da In-App Update'e bağlı

Kapı fırladıysa güncellemek EN ÇOK orada gerekiyor. Buton önce uygulama
içindeki akışı deniyor, olmazsa mağazayı dışarıda açıyor. **Yedek yolu
SİLME:** o ekranı görenler tanım gereği eski sürümde ve In-App Update yan
yüklenmiş pakette hiç çalışmıyor — yedeksiz kalırsa 1.0.0'ın hatası aynen
tekrarlanır (çıkışsız ekran).

## Sistem Yazı Boyutu — tavan VAR, ama tavan çözüm DEĞİL

Sistem yazı boyutu %200'e kadar büyüyebiliyor ve bu **yalnızca metni**
büyütüyor — kutu, ikon, dolgu sabit kalıyor. **İKİ AYRI hata sınıfı** doğuyor
ve tek bir çözüm ikisini birden kapatmıyor:

| | 1. TAŞMA | 2. SIFIRA SIKIŞMA |
|---|---|---|
| Belirti | sarı-siyah şerit | bilgi sessizce kayboluyor |
| Hata basılır mı | evet | **hayır** |
| Çözümü | `kMaxTextScale` tavanı | satırı İKİYE BÖLMEK |

**ÜÇÜNCÜ SINIF — SARMA (1 Eylül 2026):** sabit piksel genişlikli bir
kutudaki metin ölçekle büyüyünce kutuya sığmayıp **satır kırıyor**; bir
kullanıcı cihazda yakaladı: *"fontlarını büyüten kişilerde bitirme modalı
puanları bölüyor"* — skor `241` ekranda `24`/`1` diye okunuyordu. Taşma
ÜRETMEZ (ölçüldü: tavanda takımın tamamında taşma **sıfır**), sıkışma da
değildir; hiçbir hata basılmaz. **Tavan çözmez** ve dört vaka ölçek
1,0'da bile sarıyordu. Çözüm `ui/text_scale.dart` → **`ScaledCell`**: kutu
`scaledWidth` ile ölçekle büyür, metin `maxLines:1`+`softWrap:false` ile
asla sarmaz, yine de sığmazsa `FittedBox` küçültür. Kapı:
`test/text_wrap_test.dart` (19 sütunluk envanter + GameOver'ın gerçek
render'ı). ⚠ **Yeni bir sabit genişlikli sütun eklerken `SizedBox` değil
`ScaledCell` kullan** — aksi halde bu hata sessizce geri gelir.

⚠ **BİR SATIRI ÇEVİRİRKEN BAŞLIĞINI VE ARADAKİ SÜTUNLARI DA SAY** (2 Eylül
2026, cihazda yakalandı): k-lig lider tablosunda 1 Eylül turu yalnızca
`sıra` ve `skor` hücrelerini çevirmiş, **aralarındaki OHP sütununu ve
BAŞLIK satırının tamamını** atlamıştı. Sonuç cihazda `13.17` → `13.`/`17`
ve `SIRA` → `SIR`/`A`. Envanter de o üçünü hiç içermiyordu — bu yüzden
takım yeşil kaldı. Envantere `letterSpacing` alanı da o gün eklendi:
öncesinde modellenmiyordu ve sütunları olduğundan DAR sanıyordu.

**Tavan 1,3** (kullanıcı kararı). Ölçüldü: taşma sayısı ölçek 1,0'da 0 ·
1,3'te 10 · 2,0'da 73 — hasar 1,3'ten sonra patlıyor. 1,0'a kilitlemek
erişilebilirlik açısından savunulamazdı. Tam envanter:
`mobile/docs/deploy-verification.md` → "Sistem yazı boyutu".

**Kurallar:**

1. **Tavan TEK yerde:** `MaterialApp.builder` →
   `MediaQuery.withClampedTextScaling(maxScaleFactor: kMaxTextScale)`
   (`ui/text_scale.dart`). Ekran başına ölçek kısıtı YAZMA.
2. ⚠ **"Nasılsa tavan var" DEME.** Tavan yalnızca sınıf 1'i sınırlar.
   Sınıf 2 taşma üretmediği için hiçbir ölçüme girmez ve tavandan da
   etkilenmez: arkadaşlık isteği satırında isim, 360 px ekranda ölçek
   1,0'da 77,6 px · 1,3'te 53,2 px · 2,0'da **0,0 px** idi.
3. **Satırda tek esnek öğe + yanında METİN butonu = sınıf 2 riski.** İkon
   butonları (sabit 44-48 px) ölçekle büyümediğinden bu riski taşımaz —
   bu yüzden "Arkadaşlarım"/"Ara & Ekle" satırları bilerek bölünmedi,
   yalnızca "İstekler" bölündü. Eşik: `buyukOlcek(context)`.
4. **İki grubu `spaceBetween` ile yan yana koyan bir şerit `Row` DEĞİL
   `Wrap` olmalı** — iki grup da `shrink-0` olduğunda `Row` sığmadığı anda
   taşar. Tahtanın alt şeridi böyle düzeldi.
   ⚠ **AMA `Wrap`'e GENİŞLİĞİ AYRICA ZORLA** (`width: double.infinity`).
   Bu madde 28 Ağustos'tan 30 Ağustos 2026'ya kadar *"tek satıra sığdığı
   sürece davranış `Row` ile birebir aynı"* diyordu ve **YANLIŞTI**;
   bedelini bir kullanıcı cihazda ödedi (*"Hamleler, Mesajlaşma satırı
   Android'de ortaya kümelenmiş, iPhone'da kenarlara yaslı"*). Fark ana
   eksende KİMİN GENİŞLİĞİ DOLDURDUĞU: `Row` varsayılan
   `mainAxisSize.max` ile gelen genişliği kaplar, `Wrap` ise gevşek kısıt
   altında içeriğine küçülür — küçülen kutuda dağıtılacak boşluk
   kalmadığından `spaceBetween` sessizce no-op olur ve saran `Column`un
   `center` hizası kümeyi ortaya alır. Ölçüldü (390 px): şerit
   `38,4..351,6` yerine `10,0..380,0` olmalıydı.
   **Genel kural:** bir düzen widget'ını başkasıyla değiştirmek
   (`Row`↔`Wrap`, `Column`↔`Wrap`, `Flex`↔`Stack`) "sığdığı sürece aynı"
   DEĞİLDİR; ana eksendeki boyutlanma davranışı da değişir, ve bu fark
   yalnızca **konum** ölçen bir testle görülür — `tap_target_test` kutu
   BOYUTU ölçtüğü için hiç kıpırdamamıştı, o sessizlik "değişmedi" diye
   okunmuştu. Kapı: `test/text_scale_test.dart` → *"tahta alt şeridi
   ŞERİDİ DOLDURUR"* (iki farklı genişlikte ölçüyor).
   ⚠⚠ **Ve `Wrap`'e geçtikten sonra TAŞMA TESTİ SENİ KORUMAZ** (2 Eylül
   2026, Parça 178): `Wrap` taşmaz, **sarar**. "Taşma hatası yok + metinler
   görünür" diyen bir iddia, şerit iki satıra düşmüş hâlde DE geçer.
   Nitekim geçti: şerit çevrimdışıyken 48 → 96 px'e çıkıyordu ve testler
   yeşildi; kullanıcı sordu diye ölçülüp bulundu. **Bir `Wrap` eklediğinde
   aynı PR'da "tek satırda mı" iddiasını da yaz** — iki öğenin dikey
   konumunu karşılaştırmak yetiyor.
   ⚠ **Ve şeridi DOLU hâliyle ölç.** O tur şerit yalnızca çevrimiçi
   ölçülmüştü; "Çevrimdışı" beşinci öğe olarak girince eşik 305 → 405 px'e
   fırlıyor. Koşullu bir öğe (yalnız Canlı oyunda çıkan "Mesajlaşma",
   yalnız bağlantı yokken çıkan "Çevrimdışı") varsa **en dolu bileşimi**
   ölç, en yaygın olanı değil.
5. ⚠ **Takımı 1,3'te koşturmak CI KAPISI OLARAK KULLANILAMAZ** (denendi):
   31 test düşüyor ve çoğu gerçek hata değil — bu projede birçok test web
   paritesini piksel piksel ölçüyor, ölçek değişince o ölçümler tanım
   gereği kayıyor. Kalıcı kapı dar bir test: `test/text_scale_test.dart`
   (tavanın bağlı olduğu + alt şeridin taşmadığı + ismin daralmadığı).
   Envanteri yeniden çıkarmak gerekirse yöntem Parça 161'de yazılı.

**Web'de karşılığı YOK ve bu bir port eksiği değil:** tarayıcı `text-sm` gibi
px değerlerini sistem yazı boyutuyla ölçeklemez, kullanıcı tüm SAYFAYI
zoom'lar — kutular da birlikte büyür, sınıf 2 hiç doğmaz. Yani buraya
web'den kopyalanacak bir yapı yok, yalnızca ilkesi var (web'in `CARD_HEADER`
düzeltmesi, 23 Ağustos 2026: kırpılacak EN SON şey kimden geldiğidir).

### Sınıf 2 risk kütüğü

Ölçülen tek vaka `game_history_modal.dart`; beş yapısal aday daha var ve
hiçbiri ölçülmedi. ⚠ Taramanın körlüğü de ölçüldü: kullanıcının bildirdiği
ASIL hata bile listede çıkmamıştı, çünkü tarama yalnızca testlerin gerçekten
çizdiği ekranı ve veriyi görür. Envanter ve ölçümler:
`mobile/docs/deploy-verification.md` → "Sınıf 2 risk kütüğü".

## `KModal`'ın gövdesi ZATEN kaydırılabilir — içine ikincisini koyma

27 Ağustos 2026, bir kullanıcı bildirdi: *"Arkadaşlar - Ara&Ekle'de scroll
down bir yerde takılıyor, sonuna kadar gitmiyor."* Kök sebep bir kural
farkıydı: **Flutter iç içe kaydırmayı ZİNCİRLEMEZ.** Tarayıcı, iç kutu
ucuna gelince kaydırmayı dıştakine devreder — bu yüzden web'de aynı desen
(`max-h-[50vh] overflow-y-auto`) sorunsuz çalışıyor. Flutter'da iç
`ListView` jesti tümüyle sahiplenir: parmağını listenin üzerine koyan
kullanıcı dış gövdeyi **hiç** kaydıramaz (ölçüldü: 60 sürüklemeden sonra dış
offset `0.0`), ve iç listenin gövde dışına taşan kısmı kalıcı olarak
erişilemez kalır (ölçüldü: alt 128 px, son ~2,5 satır).

**Kural:** `KModal`'ın gövdesi bir `SingleChildScrollView`. İçine ikinci bir
`ListView`/`SingleChildScrollView` koyma. Uzun ya da sayfalı bir liste
gerekiyorsa düz bir `Column` çiz ve kaydırma dinleyicisini modalın kendi
gövdesine bağla: `KModal(bodyController: _bodyScroll)`. Sayfalama
dinleyicisi böylece üç sekmede de ateşlenir — istediğin listeyi
çizmediğinde erken `return` etmeyi unutma.

⚠ **Bu hata sınıfı GENİŞ pencerede GÖRÜNMEZ.** Sabit bir `maxHeight` (o
zamanki 320) gövdeyi taşırmadığı sürece her şey çalışıyor görünür; hata
yalnızca kullanılabilir yükseklik daralınca — yani **klavye açıkken** —
çıkar. 900 px'lik varsayılan test penceresi bu yüzden yalan söylüyordu.
Modal + `autofocus` bir metin kutusu içeren her testi **560 px** gibi
gerçekçi bir yükseklikte koş.

⚠ **Düz `Column`'un bedeli: satırlar TEMBEL inşa edilmez.** Bugünkü
listelerde (en fazla ~46 satır) ölçülebilir bir maliyeti yok, ama çok uzun
bir liste gerektiğinde çözüm **iç içe `ListView`'a dönmek DEĞİL** — o zaman
`KModal`'ın gövdesi `CustomScrollView` + `SliverList`'e çevrilir:
kaydırılabilir yine TEK kalır, satırlar yine tembel inşa edilir. Eşik ve
gerekçe: `ROADMAP.md` → madde 14.

Örnek/ilk kurban: `friends_modal.dart` ("Ara & Ekle"). Ayrıntı ve ölçümler:
`docs/decisions/friends.md`, `mobile/docs/parca-log.md` → Parça 146.

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
  - `reducer_ai2_kolay.json` — 2 kişilik tam YZ oyunu, `START`
    payload'ında `aiLevel: 'kolay'` (ROADMAP #23 Faz 2, 6 Eylül 2026): iki
    YZ de her hamlede en iyi 4'ten tohumlu seçer. `pickTopMove`ün
    rastgelelik sözleşmesini (tek elemanda çağrı YOK, çoklu listede TEK
    `nextDouble()`, torbayla AYNI `rng`) ve `_insertBounded`'ın "eşitte ilk
    bulunan önde" sıralı eklemesini kilitler — `sort` kullanılsaydı eşit
    puanlı adaylar yer değiştirip bu fixture düşerdi. Normal oyunlarda
    `aiLevel` anahtarı JSON'a hiç yazılmaz (web `JSON.stringify` +
    `codec.dart`ın `if (s.aiLevel != null)` sözleşmesi); eski fixture'lar bu
    sayede Faz 2'de bayt-eş kaldı.
  - `ai_level.json` — `AI_LEVEL_TOP_N` ↔ `aiLevelTopN` (Kolay 4 · Normal 1 ·
    Zor 1) kilidi; üçüncü kopya (Edge) `verify-edge-engine-parity`de.
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
  - `reducer_crafted_swap_draft.json` — swap modunda tahtada taslak taş
    varken `CONFIRM_SWAP` (5 Eylül 2026, hata avı geçişi #24). Bu
    kombinasyonu bugün DÖRT ekrandaki dört ayrı `if` engelliyor, yani
    doğal oyunda hiç oluşmuyor — fixture doğrudan reducer'a konuşuyor.
    Eskiden taslak taşlar rafa da torbaya da dönmeden siliniyordu (100 →
    98 taş); kural geri alınıp yeniden üretilerek fixture'ın duyarlı
    olduğu kanıtlandı.
  - `reducer_sync.json` — SYNC_ONLINE_STATE birleşme mantığı: aynı
    turn_count'ta taslak taşların korunması + `subtractPlacedFromRack`
    (taş çoğaltma hatasının önlemi), turn ilerleyince taslağın temizlenmesi,
    ve (2b adımı, hata avı #25) **rafı yeniden sıralayan bir senkronun
    indeks tabanlı `swapSelection`ı düşürmesi** — "Karıştır"dan sonra aynı
    indeks başka bir taşı gösterdiğinden seçim korunursa yanlış taş
    değiştirilirdi. ⚠ 2b bilerek 3. adımdan ÖNCE: orada `current` 1'e
    geçiyor ve `SHUFFLE_RACK` sırası gelen oyuncunun rafına işlediğinden
    senaryo sessizce anlamsızlaşırdı.
- Bilinçli kapsam DIŞI (vektörlerde yok): `MOVE_PLACED_TILE`in dolu hücreye
  reddi gibi bazı tekil no-op korumaları (kod birebir port, düşük risk);
  YZ'nin `freshCorners` çok-köşe dalı (üretimde erişilemez, TS'te de not
  düşülmüş); `boardSnapshot`/`outline` (henüz port edilmedi — outline UI
  fazının işi, boardSnapshot depolama fazının).

## Sonraya Bırakılan İşler (mobil)

Karar verilmiş ama henüz yapılmamış mobil işler (KGP uyarısı, iOS borçları,
ölçülmemiş riskler): **`mobile/docs/sonraya-birakilanlar.md`**. Bir madde
uygulanınca oradan silinip kendi tarihli parça notuna taşınır.
