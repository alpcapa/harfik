# Kelimeki — Claude Code Rehberi

## Proje Nedir?

Türkçe kelime oyunu. 13×13 tahtada köşe bölgeleriyle oynanan özgün bir mekanik. React + TypeScript, Vite ile build edilir, Vercel'e deploy edilir. Backend opsiyonel — Supabase env değişkenleri yoksa uygulama tamamen offline çalışır.

## Tech Stack

- **UI:** React 18 + TypeScript
- **Build:** Vite 5
- **Stil:** Tailwind CSS (nömorfik tasarım dili)
- **Backend (opsiyonel):** Supabase (auth, lider tablosu, istatistik, kelime anlamları)
- **Deploy:** Vercel

## Komutlar

```bash
npm run build   # TypeScript derleme + üretim build
npm run dev     # Geliştirme sunucusu
npm run preview # Üretim derlemesini yerelde önizle
npm run lint    # tsc --noEmit (ayrı bir ESLint kurulumu yok)
npm run test    # Playwright duman testleri (tests/*.spec.ts)
npm run generate-golden-vectors  # Flutter portu parite fixture'ları (bkz. "Flutter / Mobil Port")
npm run generate-meanings-db     # Flutter portu için meanings.json → SQLite asset'i
npm run generate-demo-board-dart # Karşılama tahtası → portun intro ekranı için demo_board_data.dart
npm run verify-cloud-save-mirror # Bulut kaydı offline karar mantığı (saf fonksiyon kontrolleri)
npm run verify-draft-rescue      # Iskalanan dokunuşun en yakın taslak taşına yönlendirilmesi
npm run verify-swap-invariants   # Taş değiştirme: taslak taşlar yok olmuyor + senkron rafı yeniden sıralarsa seçim düşüyor
npm run verify-edge-engine-parity # Motorun ÜÇÜNCÜ kopyası (supabase/functions/_game/) src/'den ayrışmadı mı — play-ai-turn onu kullanıyor
npm run verify-game-list-order   # Liste sıralaması: "sıra bende" artan ↔ "sıra rakipte" azalan, null en sona
npm run verify-recent-game-avatars # "Son Oynananlar" avatar çözümü: eşleme OYUNLA sınırlı mı (yanlış yüz koruması)
npm run verify-rematch-slots     # Rövanş kadrosu: ilk koltuk çağıran, YZ'ler sonda (create_online_game kısıtları)
npm run verify-head-to-head      # Kafa kafaya oran çubuğu: üç dilim TAM 100 eder mi (kümülatif yuvarlama)
npm run verify-fetch-my-games    # Oyun geçmişi: ağ hatası ↔ boş liste ayrımı (sahte Supabase ucu)
npm run verify-league-tiers      # k-lig kademe/ödül tablosu: migration SQL'i ↔ leagueRank.ts
npm run verify-league-points     # k-lig PUAN tablosu (seviyeye göre): league_points_for SQL ↔ leaguePoints.ts ↔ league_points.dart
npm run verify-sql-engine-parity # motorun DÖRDÜNCÜ (SQL) kopyası ↔ src/ sabitleri ve hata metinleri
npm run simulate-ai-levels       # YZ↔YZ kadran ölçümü (ROADMAP #23): üretimin findAIMoves+pickTopMove çiftiyle "en iyi N'den rastgele" ↔ Normal; `-- --oyun 200 --n 2,3,4`
npm run generate-initial-main-view-golden # Giriş sekmesi kuralı: web→port davranış golden'ı (CI tazeliği zorluyor)
npm run verify-live-games-load    # Canlı oyun listesi: düşen istek sessizce tekrarlanır (boş liste sanılmaz)
npm run verify-shared-realtime    # Canlı oyun aboneliği: üç çağıran → TEK Realtime kanalı (sunucu maliyeti çarpanı)
npm run verify-demo-board        # Karşılama katmanındaki tanıtım tahtası sözlüğe karşı doğrulanır
npm run verify-remaining-tiles   # "Kalan Taşlar" dökümü ↔ oyun sonu raf düşümü değişmezi
npm run check-doc-size           # doküman boyutu bütçesi (bkz. "Doküman Boyutu Bütçesi")
npm run verify-draft-rescue      # ıskalanan dokunuşun en yakın taslak taşına yönlendirilmesi
npm run verify-hook-order        # React hook sırası: erken `return` altında hook YOK (React #300 kapısı)
npm run verify-error-reporting   # istemci hata telemetrisi: ne kaydedilir/kaydedilmez, tekrar bastırma, hız sınırı
npm run verify-push-payload      # FCM yükünün ŞEKLİ: çakıştırma etiketi doğru seviyede mi, önekler çakışıyor mu
npm run verify-away-return       # "uzun aradan sonra öne dönüş = ekrana yeniden giriş" eşiği
npm run augment-dictionary       # Sözlüğe elle madde ekleme (GTS'siz — bkz. "Sözlüğe Kelime/Anlam Ekleme")
npm run build:dict               # Sözlüğün TAM üretimi — 100 MB'lık GTS kaynağını ister
npm run generate-logo-paths      # LogoMark.tsx + portun logo_mark_data.dart'ını birlikte üretir
npm run generate-klig-paths      # KLigMark.tsx + portun klig_mark_data.dart'ını birlikte üretir
npm run generate-icons           # favicon / app icon (public/) — og-image DEĞİL
npm run generate-og-image        # public/og-image.png (sosyal paylaşım kartı)
npm run generate-play-assets     # Play mağaza ikonu (512) + öne çıkan görsel (1024×500)
npm run generate-store-header    # marketing/store/ — mağaza başlık görseli (4096×2304, ≤1 MB)
# Öteki pazarlama üreticileri (generate-reel, generate-fb-cover) bu listede
# DEĞİL, kendi kararlarıyla birlikte docs/decisions/marketing-assets.md'de.
```

⚠ **Web CI mobil testleri de koşuyor** (`.github/workflows/web-ci.yml` →
`parite` işi, 2 Eylül 2026). Sebep: mobil testlerin bir bölümü web KAYNAK
dosyalarını okuyor (`readRepoFile`; ör. `layout_parity_test.dart`
`GameOver.tsx`teki `w-[29px]` sınıfından sayı çekiyor), yani saf bir web
değişikliği bir mobil testi düşürebiliyor. Bu bir kez gerçekleşti ve `main`
kırmızıya döndü. **Mobil testlere `mobile/` dışından yeni bir dosya
okutursan** o yolun `web-ci.yml`in `paths` listesinde karşılığı olduğundan
emin ol.

`tests/` altında üç spec var: `smoke.spec.ts` (kritik yol) ve
`text-scale.spec.ts` + `text-scale-normal.spec.ts` (yazı ölçeği; ikisi ayrı
dosya çünkü `--blink-settings` `launchOptions`ta ve Playwright onu DOSYA
düzeyinde istiyor — `describe` içinde kullanılamıyor). Ortak kurulum
`tests/gameOverFixture.ts`'te (`.spec.ts` değil, `testMatch` onu toplamaz).

**`npm run test` neyi kapsıyor, neyi kapsamıyor:** `tests/smoke.spec.ts` kapsamlı bir test paketi DEĞİL — "uygulama açılıyor, 2 kişilik bir oyun başlatılabiliyor, YZ hamle yapıyor, bilinmeyen bir path SPA fallback'iyle açılıyor" düzeyinde bir kritik-yol kontrolü. Buraya kadar hatasız gelmek reducer/YZ/skor/bölge hesaplama zincirinin ucuna kadar çalıştığı ve `ErrorBoundary`'nin devreye girmediği anlamına geliyor.

Projenin geri kalanının çok büyük bölümü (Canlı oyun, mesajlaşma, e-posta bildirimleri, admin paneli) **yapısı gereği otomatik test edilemiyor**: iki ayrı gerçek oturum, gerçek gelen kutusu ve gerçek Supabase Auth gerektiriyor. Bunlar için elle koşulan kontrol listesi ayrı bir dosyada: **`TESTING.md`** (admin paneli kontrolleri **`docs/testing-admin.md`**'de). Yeni bir Canlı oyun/mesajlaşma/e-posta özelliği eklendiğinde o listeyi de güncelle — `CLAUDE.md`/`README.md` senkron kontrolüyle aynı refleks.

## Çalışma İlkesi: Önce Etki Analizi, Sonra Doküman Senkronu

Kullanıcı isteği (6 Ağustos 2026, **projenin tamamı için** — web, backend,
mobil port, hepsi): *"yapılacak her geliştirmenin etkilemesi muhtemel
yerleri iyi analiz etmek gerekiyor"* ve *"her tamamladığın işten sonra
ilgili dosyaları kontrol edip güncellemeyi unutma"*.

Bu bir nezaket kuralı değil; bu kodtabanının somut deneyimi. Aşağıdaki
bölümlerin ÇOĞU aslında bu iki adımın atlanmasıyla doğmuş hataların
kaydı — "rozet zinciri yukarı takip edilmedi" (bkz. `CountBadge`),
"filtrelerin hepsi okunmadan 'zaten eler' denildi" (bkz.
`check_invite_expiry`), "iki istemci aynı satıra yazarken sıra garanti
sanıldı" (bkz. `local_game_saves` yarışı), "README kelime sayısı koddan
koptu" (bkz. "Belgeleri Güncel Tutma").

**İŞE BAŞLAMADAN ÖNCE — üç soru:**

1. **Bu kodun ikinci bir okuyucusu/yazarı var mı?** Aynı tabloya yazan
   öteki istemci (web ↔ mobil!), aynı JSON'u ayrıştıran öteki taraf, aynı
   üreticiden beslenen ikinci dosya, aynı fixture'a bakan testler.
2. **Değiştirdiğim şey bir ZİNCİRİN halkası mı?** Bir sayaç/rozet/filtre
   ise onu KAPSAYAN her seviye de güncellenmeli; bir filtre ise aynı veriyi
   eleyen TÜM filtreler tek tek okunmalı ("şu zaten eler" varsayımı bu
   projede iki kez yanlış çıktı).
3. **Derleyicinin göremeyeceği hangi değişmeze dokunuyorum?** Türkçe dil
   kuralı (`trUpper`/`trLower`/`trCompare`), migration senkronu, Edge
   Function `verify_jwt`, golden vector paritesi, üretilmiş dosyalar
   (logo/k-lig/meanings.db/words_tr.txt), Terms/Privacy kapsamı.

**İŞ BİTTİĞİNDE — `git status` oku ve dokunduğun her alanın eşini güncelle:**

| Dokunduğun yer | Aynı PR'da güncellenecek |
|---|---|
| Yeni dosya/component/hook, klasör yapısı, somut rakamlar | `CLAUDE.md` + `README.md` ("Belgeleri Güncel Tutma") |
| `src/game/`, `src/utils/` motor dosyaları | `npm run generate-golden-vectors` + Dart core testleri |
| Motorun **DÖRDÜNCÜ** kopyası: `supabase/migrations/`'deki `_km_*` fonksiyonları (`submit_move` hamleyi kendi hesaplıyor) | `src/`'deki kural değişirse SQL aynası da ELLE güncellenmeli. **`npm run verify-sql-engine-parity` sabitleri ve hata metinlerini kilitler** (CI'da); davranış paritesi ayrı kanıtlandı (2.641 gerçek hamle yeniden oynatıldı) ve `move_shadow_diffs` tablosu sürekli ölçüyor |
| Motorun **ÜÇÜNCÜ** kopyası: `supabase/functions/_game/` (`ai.ts`/`validator.ts`/`board.ts`/`constants.ts`/`types.ts`/`turkish.ts`/`tiles.ts`/`random.ts`) | `src/`'deki eşi değişirse ELLE kopyala **ve** `play-ai-turn`'ü yeniden deploy et. **`npm run verify-edge-engine-parity` bu ayrışmayı yakalar** (CI'da koşuyor) — golden vector'lar GÖREMEZ (yalnızca web↔port'u kanıtlar), derleyici de göremez (`tsconfig.json` yalnızca `src`'i içeriyor). Kapı 5 Eylül 2026'da, iki motor değişikliği (YZ köşe açılışı · bölge "iletken hücre" kuralı) buraya hiç işlenmediği ve aylarca CANLIDA kaldığı için eklendi |
| `src/data/meanings.json` | `npm run generate-meanings-db` |
| k-lig PUAN formülü (`league_points_for` SQL · `leaguePoints.ts` · `league_points.dart`) | Üçü birlikte + `npm run verify-league-points` (CI'da). Sunucuda formülü ASLA inline `case` olarak yeniden yazma — 6 Eylül 2026'ya kadar BEŞ kopyaydı (biri yalnızca canlıdan görülebiliyordu), betik altıncısını yakalar |
| `LogoMark`/`KLigMark` | `npm run generate-logo-paths` / `generate-klig-paths` (ikisi de web+Dart yazar) |
| Canlı oyun / mesajlaşma / e-posta özelliği | `TESTING.md` (elle koşulan liste) |
| Bir sayacı/rozeti besleyen alan (`PendingLiveGameCounts` gibi) | Rozet zincirinin HER seviyesi: alt sekme → üst sekme → uygulama ikonu (`useAppIconBadge`) → giriş varsayılanı (`decideInitialMainView`). Yeni alan bunlara GİRMELİ Mİ, ayrıca karar ver — "bekleyen iş" ile "haber" aynı şey değil (3 Eylül 2026) |
| `mobile/app/` — sunucuya/platforma dokunan bir şey | `mobile/TESTING.md` (cihazda koşulan ÖZELLİK listesi; arkadaşlık/Canlı oyun için `mobile/docs/testing-arkadaslar-canli.md`, tarihli etkileşim/görünüm turları için `mobile/docs/testing-ux-turlari.md`) |
| Migration | Canlıya uygula + doğrula + `list_migrations` ile dosya adını eşleştir |
| Migration bir kolonu **nullable** yapıyor (ya da FK'yi `cascade`→`set null` çeviriyor) | `database.types.ts` **ve** portun `fromJson`'ı — bu bir SÖZLEŞME değişikliği (bkz. `docs/decisions/account-deletion.md` → "SET NULL'ın bedeli") |
| Yeni kullanıcı verisi ya da görünürlük değişikliği | `TermsModal`/`PrivacyModal` |
| `App.tsx`'teki joker/mesaj/raf desenleri | `OnlineGameScreen.tsx` (ikisi deseni paylaşıyor) |
| `Setup.tsx`'in "devam eden oyun" kartı | `LiveGamesTab.tsx`'in aktif oyun kartı — ikisi AYNI düzeni paylaşıyor ve kullanıcı onları iki sekmede yan yana görüyor (2 Eylül 2026: biri düzeltilip öteki unutuldu, kart ayrıştı; port ikizi `ui/devam_eden_govde.dart`) |
| Bir Dart↔Kotlin/Swift MethodChannel adı ya da bildirim kanalı kimliği | Parite testi (`notification_*_parity_test.dart`) — derleyici görmez, uyuşmazlık SESSİZ arızadır |
| `register_push_token` gibi bir RPC'ye parametre EKLEME | Eski imzayı `drop` et, `create or replace` YETMEZ — iki imza yan yana kalır ve eski istemcinin çağrısı "function is not unique" (42725) verir |
| `mobile/` DIŞINDA bir dosya (port işi sırasında) | kök `CLAUDE.md`/`README.md` — port dokümanı TEK BAŞINA yetmez |
| `ROADMAP.md`'deki bir madde/faz KAPANDI (✅ · YAPILDI · CANLIDA · SAHADA) | Aynı PR'da `docs/decisions/roadmap-arsiv.md`'ye TAŞI — ROADMAP yalnızca AÇIK maddeleri tutar. Başlığı/numarayı/satırları değiştirme (atıflar kırılır); dosyanın kendi kuralıydı, uygulanmayınca %45'i kapanmış işe döndü (2 Eylül 2026) |

Mobil portun kendi (daha ayrıntılı, Dart'a özgü) sürümü: `mobile/CLAUDE.md`,
"Etki Analizi" ve "Parça Bitirme Kontrol Listesi" bölümleri — orada tek
komutluk bir grep taraması da var.

## Bağımlılık Sınıfı — `dependencies` = TARAYICIYA GİDEN

Yeni bir paket eklerken sınıfı "kim import ediyor" sorusuyla seç: `src/`
altındaki bir dosya import ediyorsa `dependencies`, yalnızca `scripts/` /
`tests/` / build yapılandırması kullanıyorsa `devDependencies`. **Bir
scriptin çağırdığı CLI de bir bağımlılıktır** — transitif olarak "zaten var"
olması onu bildirmemek için gerekçe değil.

Temizlik geçişinde (5 Eylül 2026) iki yönde de ihlal bulundu ve düzeltildi:
üç `@fontsource/*` paketi `dependencies`'teydi ama `src/`'de hiç import
edilmiyordu (fontlar repoda duruyor, bkz. "Font Yükleme Stratejisi";
paketlere yalnızca derleme-zamanı görsel üreticileri erişiyor), buna karşılık
14 npm script'in çağırdığı `esbuild` hiç bildirilmemişti. Ölçümler:
`docs/decisions/roadmap-arsiv.md` → "Temizlik geçişi".

## Git / Branch Kuralı

- Branch adı: `claude/<kısa-açıklama>` formatı
- Her feature/fix ayrı branch → PR → main'e merge
- Main'e merge = Vercel otomatik deploy tetiklenir

**Bir dal PR'sız BIRAKILMAZ (4 Eylül 2026, kullanıcı isteği).** Oturum
biterken dalda iş varsa iki seçenek vardır: PR aç, ya da dalı sil. Üçüncü
seçenek — "dursun, sonra bakarız" — bu depoda İKİ gerçek işi kaybetti:
`origin`'de duran sekiz eski `claude/*` dalı tarandığında, ikisinin `main`'e
HİÇ girmemiş iş taşıdığı görüldü (mağaza başlık görseli üreticisi, 22
Ağustos; ve kullanıcının bildirdiği bir hatanın web+port düzeltmesi, 21
Ağustos). İkisi de iki hafta boyunca kayıptı ve yalnızca dal temizliği
sırasında, tesadüfen bulundu. Kurtarma bedeli ayrıca düz bir cherry-pick
değildi: `main` o arada ilerlediğinden ikisi de elle uyarlandı (PR #441).
Bir dalı bilerek açık bırakıyorsan nedenini ve sıradaki adımı `ROADMAP.md`'ye
yaz — dalın kendisi bir hatırlatıcı DEĞİL, kimse ona bakmıyor.

⚠ **"Bu dal merge edilmiş mi?" sorusunu commit sayısıyla cevaplama — üç
tuzağı da bu depo tek turda yaşadı:**

| Tuzak | Neden yanıltıyor | Doğrusu |
|---|---|---|
| `git log main..dal` | Depo **squash** merge ediyor; merge edilmiş dalın commit'leri `main`'de ayrı SHA olarak GÖRÜNMEZ, dal "1500 commit ileri" çıkar | Commit'in getirdiği İÇERİĞİ `main`'de ara (dosya/sembol/metin) |
| Sığ klon | Oturumun klonu 50 commit'likti; `merge-base` boş dönüp dallar "ilgisiz geçmiş" gibi göründü | Önce `git fetch --unshallow` |
| Harf duyarlı `grep` | "AYRI zamanlarda" yazan bir not "ayrı zamanlarda" aranınca bulunamadı, merge edilmiş bir dal "kayıp iş var" sanıldı | Türkçe metinde `grep -i`; İ/ı dönüşümü için ayrıca `trUpper`/`trLower` refleksi |

`git cherry` de tek başına YETMEZ: yama-kimliği eşitliği arar, sonradan
farklı bağlamda yeniden inen bir değişikliği "yok" işaretler.

⚠ **Dal SİLMEYİ ajan yapamaz — iki kapı da kapalı (4 Eylül 2026'da ölçüldü).**
`git push --delete` → **403** (oturumun git kimliği yalnızca kendi tahsisli
dalına yazabiliyor), GitHub MCP'de ref silen araç YOK, ve
`branch-cleanup.yml`i **dispatch etmek de 403** (`Resource not accessible by
integration` — App'in `actions: write`i yok). Yani doğru davranış: dalları
silmeye çalışmak ya da "ben hallederim" demek değil, kullanıcıya şu adımı
vermek — **Actions → "Dal temizliği" → Run workflow**, önce `dry_run` AÇIK,
liste doğrulanınca KAPALI ile tekrar. O gün bir oturum önce "tetikleyebilirim"
diye söz verip yanıldı; vaat etmeden ÖNCE dene.

## Belgeleri Güncel Tutma

Anlamlı bir değişiklik yapıldığında (yeni dosya/component/util/hook, klasör yapısı değişikliği, sözlük kelime sayısı gibi somut rakamlar, migration/akış değişikliği vb.) **standart olarak** hem bu dosyayı (`CLAUDE.md`) hem de `README.md`'yi kontrol et ve gerekiyorsa aynı PR'da güncelle — özellikle "Klasör Yapısı" (burada) ve "Proje Yapısı" (`README.md`) ağaçları, ve `README.md`'deki kelime sayısı gibi rakamlar zamanla koddan kopabiliyor (23 Temmuz 2026'da fark edildi: README hâlâ eski **92.503** kelime rakamını taşıyordu, gerçek liste sonradan yapılan çok-sözcüklü madde temizlikleriyle ~64 bine düşmüştü; ayrıca `ErrorBoundary`/`PlayerBadge`/`useModalA11y`/`useOnlineStatus`/`gameStorage`/`gameSync`/`feedbackSync`/`onboarding`/`ranking`/`visitTracking` gibi dosyalar hiç listeye girmemişti). Bu bir "fırsat bulunca yapılır" işi değil — migration senkron kontrolü (aşağıda, "Migration'lar" bölümü) gibi asıl işin bir parçası say.

## Deploy Doğrulaması — "düzelttim" ≠ "canlıda"

Kullanıcı isteği (15 Ağustos 2026): *"bu yaşanan deploy sorunlarını kalıcı
olarak çözecek bir sistem geliştir"*. O gün aynı hata İKİ KEZ tekrarlandı:
düzeltme yazıldı, testler yeşildi, kullanıcı **BAYAT bir derlemeyi** test
edip "düzelmemiş" dedi. Kural (Parça 19: *"'deploy oldu mu?' kontrolü
teşhisin parçasıdır"*) zaten vardı ve yine atlandı — bu yüzden çözüm bir
kural değil bir MEKANİZMA: derleme kimliği artık ürünün İÇİNDE.

| Yüzey | Nereden | Ne zaman |
|---|---|---|
| `kelimeki.com` | Vercel | `main`'e her merge |
| `alpcapa.github.io/kelimeki` (Flutter test ortamı) | Actions `mobile-build.yml` → Pages | YALNIZCA `main`'e push **ve** `mobile/**` değiştiyse |
| Supabase (migration / Edge Function) | MCP ile doğrudan | Anında — dal/merge ile İLGİSİZ |

**Feature dalındaki bir commit sitede ASLA görünmez**; PR açmak da yetmez
(workflow PR'da bilerek yayınlamıyor). Üçüncü satır tersine bir tuzak:
sunucu değişikliği anında canlıdır, yani istemci düzeltmesi henüz yokken
sunucu davranışı değişmiş olabilir.

**Derleme kimliği:** web'de `<meta name="kelimeki-build">` +
`window.__KELIMEKI_BUILD__` (`vite.config.ts`, Vercel
`VERCEL_GIT_COMMIT_SHA`; yerelde `yerel`) — görünmez, çünkü normal
kullanıcıya sha göstermenin anlamı yok, devtools/`view-source` yeter.
Mobilde GÖRÜNÜR karşılığı Setup teşhis satırındaki `Derleme a1b2c3d · …`
(`mobile/app/lib/src/config/env.dart`, CI `--dart-define` ile veriyor).
**Bir düzeltmenin kullanıcıda görüneceğini söylemeden önce o sha'yı iste
ya da ekran görüntüsünden oku** — eşleşmiyorsa tartışılacak bir hata yok,
deploy bekleniyor demektir. **2 Eylül 2026'da ölçüldü: `curl` ARTIK ÇIKIYOR** (ajan vekili üzerinden) ve
bu, deploy doğrulamasının en kesin yolu:
```
curl -s https://kelimeki.com/ | grep kelimeki-build
kelimeki-build" content="ea0a1c8"
```
Yani derleme sha'sı için artık kullanıcıdan ekran görüntüsü beklemeye gerek
YOK — `main`'in başıyla karşılaştır, yeter. (Bu, 25 Ağustos'ta yazılan
"`curl`/`bash` çıkamıyor" tespitini geçersiz kılıyor; `WebFetch` de çalışıyor
ama içeriği markdown'a çevirdiğinden `<meta>` etiketlerini GÖSTERMEZ — sha
okumak için `curl` şart.) Flutter/Pages yüzeyi için kanıtlanmadı. Ayrıntı (bu oturumun gözlem sınırı, merge
sonrası dal hijyeni, PR'da CI koşmazsa ne yapılacağı):
`mobile/CLAUDE.md` → "Deploy Doğrulaması".

⚠ **`main`'e merge YAYIN GARANTİSİ DEĞİL — Vercel bir commit'i sessizce
atlayabiliyor (4 Eylül 2026, ölçüldü).** #447 merge edildi, GitHub Actions
`7312eb8` için koştu ve yeşildi, ama Vercel'in dağıtım listesinde o commit
için **hiç satır yoktu**; üretim 30+ dakika bir önceki commit'te (`a940626`)
kaldı ve site eski kodu servis etmeye devam etti. Hata mesajı yok, düşen bir
iş yok — tabloda "`main`'e her merge" satırı bunu vaat ediyor gibi görünse
de gerçek şu: **tek kanıt sha.** Yani "merge edildi" demek "canlıda" demek
değil; `curl` ile sha'yı OKU.

**Kurtarma — dalın Preview'ını Production'a yükselt** (Vercel → Deployments
→ dalın satırı → `…` → Promote to Production). Squash merge'te dal başının
AĞACI `main`'inkiyle birebir aynıdır (bu turda doğrulandı: iki commit de
`f49deda…` ağacını gösteriyordu), yani doğru kod anında canlıya çıkar.
⚠ **Bedeli:** sayfa artık DALIN sha'sını bildirir (`395778d`), `main`'in
başını değil — yani yukarıdaki "sha'yı `main`'le karşılaştır" kontrolü bir
sonraki gerçek üretim yayınına kadar eşleşmez. Karşılaştırmayı yaparken
bunu bil, yoksa "yayın yine kaçtı" diye yanlış teşhis koyarsın.
Ajan bunu kendi başına ölçemez: bu oturumun Vercel erişimi yalnızca BAŞKA
bir projeyi görüyordu (`list_deployments` → 403 / listede yalnızca
`sharedxp`), yani panel kullanıcıda. Ajanın yapabildiği tek şey siteyi
`curl`lamak — o da zaten kesin olan kanıt.

## Flutter / Mobil Port (`mobile/`)

5 Ağustos 2026'da başladı — iOS+Android için Flutter portu. **Tüm port
kararları/yapısı AYRI bir rehberde: `mobile/CLAUDE.md`** (bu dosyayla aynı
"anlamlı değişiklikte aynı PR'da güncelle" disiplinine tabidir). Web tarafını
ilgilendiren iki kanca:

- **Motor dosyalarına dokunan her PR golden vector'ları yeniden üretmeli:**
  `src/game/` ya da `src/utils/`'ın kural dosyaları (validator, ai, board,
  bag, ranking, leaguePoints, turkish, random, tiles, gameReducer, constants,
  types) değişirse `npm run generate-golden-vectors` koşulup
  `mobile/kelimeki_core` Dart testleri (`dart run test/run_all.dart`) aynı
  PR'da geçirilmeli — Dart motoru web motorunun birebir kopyası, parite bu
  fixture'larla kanıtlanıyor. Ayrıntı: `mobile/CLAUDE.md`, "Golden Vector İş
  Akışı".
- **`src/data/meanings.json` değişirse `npm run generate-meanings-db`
  koşulmalı:** Flutter portu anlamları JSON olarak DEĞİL, build-time'da
  üretilen bir SQLite asset'i olarak taşıyor (mobilde 6.5 MB JSON parse
  etmemek için) — script `mobile/app/assets/dictionary/meanings.db`'yi
  yeniden üretir. Web tarafı bu değişiklikten hiç etkilenmiyor, hâlâ
  `src/data/meanings.ts` üzerinden JSON'u kendisi yüklüyor. Ayrıntı:
  `mobile/CLAUDE.md`, "Üst Düzey Kararlar" #4.
- **Marka (wordmark) üreticileri iki tarafı birden yazar:** `npm run
  generate-logo-paths` ve `npm run generate-klig-paths`, web bileşenlerinin
  (`LogoMark.tsx`/`KLigMark.tsx`) yanında Flutter portunun path verisini de
  (`mobile/app/lib/src/ui/game/logo_mark_data.dart`,
  `mobile/app/lib/src/ui/score/klig_mark_data.dart`) üretir — logo/marka
  değişirse tek komut yeter, elle senkron YOK.
- **Play Store imzalama `mobile/` DIŞINDA da dosya değiştirdi (22 Ağustos
  2026):** `.github/workflows/mobile-build.yml`'in `android` işi artık `.apk`
  yanında imzalı bir `.aab` da üretiyor (Play `.apk` kabul etmiyor). Adım
  `ANDROID_KEYSTORE_BASE64` secret'ı yokken sessizce atlanıyor, yani bu
  değişiklik mevcut Appetize/web akışlarını HİÇ etkilemiyor. **24 Ağustos
  2026'da aynı adım `.aab`'yi `mobile-latest` prerelease'ine de yüklemeye
  başladı** — öncesinde paket yalnızca artefakttı, yani indirmek için GitHub
  oturumu + zip açma gerekiyordu (iPad'den yükleyen için `.apk`nın çözülmüş
  probleminin aynısı). Karar/ölçüm/tuzaklar (özellikle: keystore repoya
  girmez, Play App Signing'e kaydolma zorunluluğu ve `assetlinks.json`'a
  HANGİ parmak izinin gireceği): `mobile/CLAUDE.md` → "Play Store İmzalama
  ve `.aab`". Play Console'a girilecek formların cevap kağıdı (Data safety
  eşlemesi dahil): `marketing/play-store/console-formlari.md`.
- **`src/utils/random.ts`'teki `setRandomSource()`** yalnızca bu fixture
  üreticisi için var — üretim kodu hiç çağırmaz, davranış değişmedi
  (varsayılan `Math.random`).


## Doküman Boyutu Bütçesi — `npm run check-doc-size`

Kullanıcı isteği (24 Ağustos 2026): *"md dosyalarının büyümesinden dolayı
sürekli hata alıyor ve senin işlerin takılıyordu. Dosyaları böldük ve
düzeldi. Bundan sonra tekrar aynı şeyin yaşanmaması için gerekli kontrolleri
koyup ona göre zamanında önlem alalım."*

Aynı gün bu ders İKİ kez alındı: (1) `CLAUDE.md` her turu yiyordu →
bölündü; (2) **bölünme sorunu çözmedi, YER DEĞİŞTİRDİ** —
`mobile/docs/parca-log.md` sessizce 714 KB'a, yani eski `CLAUDE.md`'nin
YEDİ katına çıkmıştı. Yani "bir gün fark ederiz" işe yaramıyor; ölçüm
otomatik olmak zorunda.

`npm run check-doc-size` (bağımlılıksız node betiği) repodaki her `.md`
dosyasını ölçüp üç sınıfa ayırır — çünkü maliyetleri farklı:

| Sınıf | Ne | Uyarı / Sınır |
|---|---|---|
| **auto** | Her turda bağlama YÜKLENİR: `CLAUDE.md`, `mobile/CLAUDE.md` | 80 KB / **120 KB** |
| **active** | BAŞTAN SONA okunur ve büyümeye devam eder: `TESTING*`, `README`, `ROADMAP` | 120 KB / **200 KB** |
| **reference** | Yalnızca GREP'lenir: `docs/decisions/*`, `mobile/docs/parca-log*` | 200 KB / **300 KB** |
| **frozen** | Dondurulmuş arşiv; okuması opt-in, tek kural BÜYÜMEMESİ | kendi tavanı |

**Sınır aşılınca ne yapılır** (betik zaten yazdırıyor):
- **auto** → tarihli "neden böyle" anlatılarını `docs/decisions/*.md` ya da
  `mobile/docs/*.md`'ye taşı; burada yalnızca HER YERDE geçerli kural/
  değişmez kalsın.
- **active** → bir bölüm sınırından kes. Kesme noktası boyut değil İÇERİĞİN
  TÜRÜ olsun (tek oturum ↔ iki oturum, normal kullanıcı ↔ admin — örnek:
  `TESTING.md` → `docs/testing-admin.md`).
- **reference** → **önce BÖLME.** Bu dosyalar grep'leniyor, baştan sona
  okunmuyor; bölmek çoğu zaman baytı yer değiştirmekten ibaret. Sırayla:
  (1) bayat/aşılmış anlatıyı buda, (2) hâlâ büyükse bir **cilt** dondur
  (`FROZEN` listesi, örnek `mobile/docs/parca-log*.md`).
- **frozen** → arşive yazılmış demektir; girişi AKTİF cilde taşı.

⚠ **`reference` sınıfı 29 Ağustos 2026'da eklendi** (kullanıcı sorusu:
*"Büyüyen md dosyalarını bölme işini tüm md'lerde yapıyor muyuz? Gerek
var mı?"*). Ölçüldü: repoda 43 `.md`, 2.3 MB. Eski `active` bütçesi
ÖDENMEYEN bir maliyeti vekaleten ölçüyordu — o dosyalar isteğe bağlı ve
çoğunlukla grep'le okunuyor. **Bölmenin ise gerçek bedeli var ve bu repo
onu ödedi:** `docs/decisions/` 22 dosyaya çıktı ve doğru dosyayı bulmak
için yukarıdaki indeks tablosu gerekli hâle geldi (koddaki eski atıflar
bölünmeyle kırıldı). Kural kaldırılmadı, **daraltıldı**: bölme refleksi
artık yalnızca baştan sona okunan dosyalar için. Bir dosya uyarı bandına
girdiğinde ilk soru *"nasıl bölerim"* DEĞİL, ***"bunu baştan sona okuyan
var mı?"***

**CI'da koşuyor:** `.github/workflows/docs-size.yml`, yalnızca `**/*.md`
değiştiğinde. `npm install` ve derleme YOK (saniyeler) — bu repoda
"yalnızca doküman değişikliği ücretsizdir" kuralı bilerek korunuyor.

⚠ **Uyarı bandındaki dosyayı bir sonraki dokunuşunda böl.** Uyarı, sınıra
çarpmadan önce hareket etme fırsatıdır; biriktirilirse kontrolün anlamı
kalmaz.

**26 Ağustos 2026 — uyarı bandı TAMAMEN boşaltıldı** (kullanıcı: *"md
bölünme işini hallet"*). Beş dosya da kendi kuralına göre bölündü ve
`npm run check-doc-size` artık tek uyarı vermiyor:

| Dosya | Önce → Sonra | Nasıl |
|---|---|---|
| `CLAUDE.md` (auto) | 82 → **59 KB** | `## Supabase`'in tarihli anlatıları → `docs/decisions/supabase-ops.md`; kural/tablo burada kaldı |
| `docs/decisions/components.md` | 183 → **62 KB** | üç cilt: `-account` (59) · `-score` (64) · kendisi (62) |
| `mobile/docs/parca-log.md` | 151 → **12 KB** | Parça 110-138 donduruldu (`parca-log-110-138.md`, FROZEN listesinde) |
| `mobile/TESTING.md` | 141 → **109 KB** | Arkadaşlar + Canlı oyun → `mobile/docs/testing-arkadaslar-canli.md` |
| `TESTING.md` | 124 → **83 KB** | Admin kontrolleri (9.7-9.15) → `docs/testing-admin.md` |

**3 Eylül 2026 — `mobile/TESTING.md` yeniden uyarı bandına girdi** (121 KB)
ve aynı kuralla ikinci kez bölündü: tarihli etkileşim/görünüm turları (bölüm
14-25, sürükleme eşiği · dokunma hedefleri · yazı boyutu · akıcılık · zoom)
→ `mobile/docs/testing-ux-turlari.md`, dosya **93 KB**'a indi. Kesme noktası
yine içeriğin türü: her sürüm baştan koşulan ÖZELLİK listesi ↔ belirli bir
Parça'nın gerilemediğini doğrulayan TARİHLİ tur. Dosyanın bölüm
numaralarının 14'ten yeniden başlaması bu ayrımın zaten var olduğunun
kanıtıydı.

**4 Eylül 2026 — `mobile/CLAUDE.md` uyarı bandındaydı (80 KB), aynı
kuralla bölündü.** Dosyanın en büyük tek bloğu "Klasör Yapısı" ağacıydı:
**24,5 KB, dosyanın %30'u**, ve içeriğinin çoğu dosya başına tarihli
gerekçe/uyarı — yani her turda değil, O DOSYAYA dokunurken gereken bilgi.
Açıklamalı ağaç `mobile/docs/klasor-yapisi.md`'ye taşındı (satırlar
değiştirilmeden), yerine yalnızca KLASÖR düzeyinde bir özet + ağaçtan çıkan
iki kural (üretilmiş dosyalar listesi, elle senkron web↔port çiftleri)
kaldı; dosya **60 KB**'a indi. `auto` sınıfının kesme noktası bir kez daha
"kural ↔ dosya başına ayrıntı" oldu — kök `CLAUDE.md`'nin kendi 26 Ağustos
bölmesindeki ayrımın aynısı.

**Her kesme noktası boyut değil, İÇERİĞİN TÜRÜ:** kural ↔ anlatı, tek
oturum ↔ iki oturum, normal kullanıcı ↔ admin. Hiçbir satır
değiştirilmedi, bölüm numaraları korundu — atıflar kırılmasın diye.
(`docs/decisions/live-game-and-friends.md` 25 Ağustos 2026'da tam bu kural
gereği bölündü — 156 KB'lık dosya `friends.md` / `live-game.md` /
`online-game-screen.md` olarak üçe ayrıldı, üçü de 64 KB'ın altında. Kural
işledi: dosya "bir gün" değil, ilk dokunuşta bölündü.)

**Bu dosya (`CLAUDE.md`) da kuralı yazarken 111 KB'a çıkıp uyarı bandına
girmişti** — kuralı yazmak, kuralın konusu olan dosyayı büyüttü. Öngörülen
çare hemen uygulandı: en büyük tek konu bloğu (yerel oyun kalıcılığı, 35 KB)
`docs/decisions/local-game-persistence.md`'ye taşındı, dosya 76 KB'a indi.
Bu, "active" sınıfı için beklenen davranışın örneği: sınıra çarpmadan böl.

## Oturum Hijyeni — yeni oturum ÖNERİSİ ajanın işi (3 Eylül 2026)

Kullanıcı isteği, sözleri birebir: *"Bana gerektiğinde yeni session önerisi
yap"*. Gerekçe aynı gün yaşandı: tek bir oturum "avatar boyutu → APK →
canlıda çökme" zincirini taşıdı, birkaç kez sıkıştırma (compaction) yedi.
Sıkıştırma repoyu etkilemez, ama erken turların ÖLÇÜMLERİ özete iner.

**Kullanıcıdan beklenmiyor — bunu ben söyleyeceğim.** Bir iş kapandığında
(merge edildi, doğrulandı) ve sıradaki iş ONDAN BAĞIMSIZSA, tek cümlelik bir
öneri: *"Bu iş kapandı; sıradakine `/clear` ile temiz bir oturumda başlamak
daha verimli olur."*

| Öner | ÖNERME |
|---|---|
| İş kapandı + sıradaki konu ilgisiz | Zincir sürüyor: teşhis → düzeltme → PR → merge → doğrulama |
| Oturumda zaten sıkıştırma olduysa ve yeni bir konuya geçiliyorsa | Kullanıcı bir hata bildirmiş ve bağlam DEĞERLİ (bugünkü React #300 turu: eski turların kararları teşhisi hızlandırdı) |
| Çok okuma gerektiren bir tur başlıyorsa (cihaz testi turu, doküman bölme, sözlük işi) | Yalnızca "uzun sürdü" diye — süre değil KONU DEĞİŞİMİ ölçüt |

⚠ **Öneriyle birlikte devir notunu da ver:** dal adı, açık PR numarası,
bekleyen iş. Yeni oturum repoyu okuyabilir ama bu üçünü tahmin edemez.

## Karar Kayıtları (`docs/decisions/`) — geçmiş, arşivlenmiş

Bu dosya artık **yaşayan bir indeks**: mimari, komutlar, klasör yapısı,
oyun kuralları ve asla ihlal edilmemesi gereken değişmezleri tutar. Tarihli
"neden böyle yapıldı" anlatıları/post-mortem'ler — Karşılama Katmanı,
Admin Paneli, Canlı Oyun/Arkadaşlık, Mesajlaşma, k-lig, Reklam görselleri,
Hukuki sayfalar, SEO, Telemetri, Bileşen notları, dokunmatik/hover hata
sınıfları, PWA/Android notları, sözlük işlemleri, ürün fikir listesi —
**`docs/decisions/*.md`** altına taşındı (24 Ağustos 2026, context split).

**Neden:** bu dosya context penceresini her turda ~200K token dolduruyordu
ve oturumlar sürekli "autocompact thrashing" ile kesiliyordu. Tarihçe
gerçek/değerli (proje aynı hatayı iki kez yapmıyor çünkü burada yazılı),
ama HER TURDA hazır bulunması gerekmiyor — yalnızca o alanda çalışırken.

**Bir konuda çalışırken ilgili dosyayı OKU** (aşağıdaki tablo), koddaki
"bkz. CLAUDE.md, 'X bölümü'" gibi atıflar artık o dosyaların içinde arıyor
olabilir — atıf bulunamazsa önce buradaki tabloya bak.

| Konu | Dosya |
|---|---|
| Karşılama katmanı (`/`, landing/) — statik SEO sayfası, kapı script'i, tanıtım tahtası | `docs/decisions/landing-page.md` |
| Bileşen post-mortem'leri — **hesap/kimlik** (RemainingTilesModal, GameOver, CountBadge, UserMenu, RelationIcons, AuthModal, AccountSettingsModal, avatar) | `docs/decisions/components-account.md` |
| Bileşen post-mortem'leri — **skor/k-lig** (ScoreCard, k-lig rebrand'i, Leaderboard) | `docs/decisions/components-score.md` |
| Bileşen post-mortem'leri — **oyun ekranı/kabuk** (Setup, PlayerAvatarRow, LandscapeHint, AddToHomeScreen, useAppIconBadge, Board, GameHeader, HelpModal, LogoMark, useModalA11y, TermsModal/PrivacyModal) + port dalı teslim dersi | `docs/decisions/components.md` |
| Dokunmatik/hover hata sınıfları (ghost click, drag threshold, sticky hover) + iOS Safari form zoom post-mortem'i | `docs/decisions/touch-ux-bugs.md` |
| PWA servis çalışanı / Android uyumluluğu | `docs/decisions/pwa-and-android.md` |
| Sözlüğe kelime/anlam ekleme prosedürü + kelime listesi code-splitting | `docs/decisions/dictionary.md` |
| Admin paneli (tüm sekmeler, rozet zinciri, büyüme grafikleri, kaynak hunisi, retention) | `docs/decisions/admin-panel.md` |
| k-lig ödül & rütbe sistemi | `docs/decisions/league-system.md` |
| Arkadaşlık sistemi (istek/kabul, davet linki ve `/davet/:token` sayfası, işlemsel e-postalar) | `docs/decisions/friends.md` |
| Canlı Oyun — Faz 2-3.6 (veri modeli, RPC'ler, zaman aşımı, cron) | `docs/decisions/live-game.md` |
| Canlı oyun EKRANI (`OnlineGameScreen.tsx`) — sürükleme, joker, raf, senkron | `docs/decisions/online-game-screen.md` |
| Oyun içi mesajlaşma (Faz 1: mesajlaşma, Faz 2: sessize alma/raporlama) | `docs/decisions/chat-moderation.md` |
| Reklam/pazarlama görselleri (sponsored post, Play Store vitrini, FB kapağı, reel) | `docs/decisions/marketing-assets.md` |
| Hukuki statik sayfalar (`/gizlilik/`, `/kullanim-kosullari/`, `/hesap-silme/`) | `docs/decisions/legal-pages.md` |
| Uygulama içinden hesap silme (kaskad, anonimleştirme, `delete-my-account`) | `docs/decisions/account-deletion.md` |
| SEO (GSC/Bing, reindex adımları) | `docs/decisions/seo.md` |
| İstemci hata telemetrisi (`client_errors`, admin "Hatalar" sekmesi) | `docs/decisions/telemetry.md` |
| Yerel oyunun kalıcılığı, terk-edilme cezası, offline kuyruk | `docs/decisions/local-game-persistence.md` |
| E-posta gönderenleri (`noreply@` ↔ `destek@`), Zoho rozeti, inbound webhook kurulumu | `docs/decisions/support-email.md` |
| Supabase işletimi: Brevo SMTP/teslimat geçmişi, SPF-DKIM-DMARC'ın gerçek hâli, migration geçmişinin kopması, dal temizliği, Edge Function deploy tuzakları | `docs/decisions/supabase-ops.md` |
| Sonraya bırakılan ürün fikirleri (karar verildi, henüz yapılmadı) | `docs/decisions/product-backlog.md` |
| ROADMAP arşivi — kapanmış maddeler, fazlar ve sürüm turları (grep'lenir, baştan sona okunmaz) | `docs/decisions/roadmap-arsiv.md` |

**Yeni bir dated not eklerken:** eğer not, kod tabanında HER YERDE geçerli
bir kural/değişmez tarif ediyorsa (Türkçe harf kuralı, migration disiplini,
web↔port senkron kuralı gibi) bu dosyada kalsın. Eğer belirli bir özelliğin/
bileşenin "neden böyle" gerekçesiyse, ilgili `docs/decisions/*.md` dosyasına
eklensin — yeni bir konu ise yeni bir dosya açıp yukarıdaki tabloya bir satır
ekle.

## Klasör Yapısı

```
src/
  main.tsx      # ince kabuk: fontlar + derleme kimliği + kapı kararı (katman mı uygulama mı)
  boot.tsx      # uygulamanın gerçek açılışı — main.tsx DİNAMİK import eder (bkz. "Karşılama Katmanı").
                # `App` ve iki route sayfası buradan da LAZY yükleniyor: /davet ve /game
                # oyunun tamamını ve sözlüğü indirmesin diye (2026 → 885 KB, ölçüldü)
  landing/      # karşılama katmanı — derleme zamanında statik HTML (bkz. "Karşılama Katmanı")
  legal/        # SPA DIŞINDAKİ statik sayfaların üreticisi (`STATIC_PAGES`):
                # /gizlilik/ · /kullanim-kosullari/ · /hesap-silme/ + /nasil-oynanir/
                # ⚠ Dizin adı TARİHSEL — sonuncusu hukuki DEĞİL, SEO sayfası
                # (ROADMAP #6). İçeriğini KOPYALAMIYOR, HelpModal'dan İTHAL ediyor.
                # ⚠ Sayfa YOLLARININ tek kaynağı burada DEĞİL, scripts/static-pages.js'te
                # (`Sayfa.yol`un tipi + service worker denylist'i oradan türer; yeni
                # sayfa oraya girmeden derleme geçmez). src/ altında olamaz: dosya iki
                # composite projeye birden girip TS6305 veriyor — bkz. pwa-and-android.md
    Landing.tsx     # sayfanın tamamı; SUNUCUDA render edilir (hook/olay/tarayıcı globali YOK)
    LandingLogo.tsx # logoyu üç kez çizmek için SVG sprite (path verisi LogoMark'tan)
    OzellikIkonlari.tsx # "Neler var" altı özellik ikonu (Material DEĞİL — ilkel şekiller; portun ozellik_ikonlari.dart'ıyla ELLE senkron, `icon_parity_test.dart` ile testli)
    demoBoard.ts    # tanıtım tahtasının taşları — `npm run verify-demo-board` ile doğrulanır;
                    # iki tahta da (2 ve 4 kişilik) `npm run generate-demo-board-dart` ile porta üretilir
    render.tsx      # `renderToStaticMarkup` sarmalayıcısı (Node'da koşar)
  components/   # React UI bileşenleri
  game/         # Oyun mantığı ve durum yönetimi
    constants.ts    # Tahta sabitleri, köşe hesapları, bonus konumları
    gameReducer.ts  # useReducer tabanlı oyun state makinesi
    types.ts        # GameState, Player, Tile tipleri
  utils/        # Saf fonksiyonlar (validator, board, boardSnapshot, ai, bag, gameStorage, cloudSaveMirror, gameRecord, gameSync, feedbackSync, visitTracking, ranking, leaguePoints, leagueRank, onboarding, csvExport, friendInvite, profileFields, platform, offlineNotice, shareLink, shareBoardImage, pendingLiveGames, errorReporting, ghostClick, draftRescue, boardZoom, gameListOrder, recentGameAvatars, headToHead, rematchSlots, awayReturn, aiLevel, scoreLine, outline...)
  data/         # Kelime listesi (~63k), harf dağılımı, kelime anlamları, wordSetLoader (lazy chunk)
  lib/          # Supabase istemcisi ve API sarmalayıcısı
  fonts/        # @font-face tanımları (main.tsx import eder) + files/*.woff2 — bunlardan
                # mplus-rounded-1c-800-subset.woff2 ÜRETİLMİŞ, yalnızca RankSeal'ın harfi
                # (yeniden üretimi: "k-lig Ödül & Rütbe Sistemi" → Rütbe Rozeti Fontu)
  hooks/        # useAuth, useModalA11y, useOnlineStatus, useAppIconBadge, useNicknameAvailability, useRankScores, useBoardZoom
.claude/        # oturum kurulumu: hooks/session-start.sh — npm install + Flutter
                # stable + iki paketin pub get'i (bkz. mobile/CLAUDE.md, "Flutter
                # SDK bu ortamda HAZIR"). Amacı: Dart testleri YERELDE koşsun,
                # kanıt yalnızca CI olmasın.
marketing/      # reklam/tanıtım çıktıları (üretilmiş PNG + metin) — uygulamaya girmez
mobile/         # Flutter portu — kelimeki_core (saf Dart motor) + üretilmiş
                # sözlük asset'i + golden vector fixture'ları (bkz. mobile/CLAUDE.md)
```

## Kritik Sabitler (src/game/constants.ts)

| Sabit | Değer | Açıklama |
|-------|-------|----------|
| `SIZE` | 13 | Tahta boyutu (13×13) |
| `CORNER` | 4 | Köşe bölgesi kenar uzunluğu (4×4) |
| `RACK_SIZE` | 7 | Raftaki taş sayısı |
| `BINGO_BONUS` | 25 | 7 taşın hepsini tek hamlede kullanma bonusu |
| `MAX_PASS_ROUNDS` | 2 | Üst üste pas → oyun bitişi |

## Oyun Mekaniği Özeti

- **Köşe bölgeleri:** 4 köşe (0=sol-üst, 1=sağ-üst, 2=sol-alt, 3=sağ-alt), her biri 4×4. 2 oyuncuda her oyuncu tek bir köşeye sahiptir (1. oyuncu sol-üst=0, 2. oyuncu sağ-alt=3). 4 oyuncuda her oyuncu tek bir köşeye sahiptir (0,1,2,3 sırasıyla). Bir oyuncunun sahip olduğu köşeler `Player.corners: number[]` alanında tutulur (`cornersFor`, `src/game/constants.ts`).
- **Başlangıç karesi:** Her köşenin en uç tek hücresi (`cornerCell`, `src/game/constants.ts`) o oyuncunun zorunlu başlangıç noktasıdır — Board'da bir ev işaretiyle (`HomeMark`) gösterilir. İlk hamle mutlaka bu hücreye değmelidir (sadece 4×4 köşe bölgesine düşmesi yetmez); oradan tahtaya doğru genişlenir.
  **17 Ağustos 2026 — YZ bu kuralın YALNIZCA BİR YÖNÜNÜ kullanıyordu; sağ-alttaki YZ her oyuna 29 puan geride başlıyordu (kullanıcı bildirdi: "sağ alttaki YZ genelde hep sonuncu oluyor"):** `tryCornerStart` (`src/utils/ai.ts`) kelimeyi HER ZAMAN ev karesinden BAŞLATIP sağa/aşağı uzatıyordu. Bu, kuralın kendisinden gelen bir kısıt DEĞİL — doğrulama (`validatePlacement`, `src/utils/validator.ts:105`) yalnızca "konan hücrelerden biri ev karesi olsun" diyor, yön ya da "blokta başla" şartı yok; nitekim `tryPlace` (çapalı hamleler) baştan beri `idx` döngüsüyle iki yöne de uzatıyordu, yani tutarsızlık YZ'nin kendi içindeydi. **Sonuç köşeye göre asimetrikti ve ÖLÇÜLDÜ** (üretim `findAIMove`, raf `A B A R T M A`): köşe 0/1/2 → `7 taş "ABARTMA" 35 puan`, köşe 3 → `4 taş "ABAT" 6 puan`. 2 kişilik oyunda YZ HER ZAMAN köşe 3'tedir (`cornersFor`), yani bu her oyunda tekrarlanan bir açılış handikabıydı. **Düzeltme:** `tryCornerStart` artık kelimenin HANGİ harfinin eve denk geleceğini (`idx`) tek tek deniyor, kelime evden geriye ve ileriye uzayabiliyor. Düzeltmeden sonra dört köşe de `7 taş / 35 puan`; köşe 3 `12,6 … 12,12` oynuyor, yani merkeze doğru büyüyor. **Dart portu (`mobile/kelimeki_core/lib/src/ai/find_move.dart`) AYNI PR'da birebir güncellendi — döngü SIRASI da dahil:** `consider` eşit puanda İLK bulunanı tuttuğundan (strict `>`) sıra değişirse iki motor farklı hamle seçer ve parite sessizce kırılır. Golden vector'lar yeniden üretildi (bkz. o dosyanın fixture envanteri).
  **`ai.ts`'in kelime havuzu 2-7 harfle sınırlı** (`getWordPool`) — yani YZ 8+ harfli bir kelimeyi tahtadaki bir harfe ekleyerek bile ASLA kurmaz, çünkü o kelimeler havuza hiç girmiyor. Bu, kuralın değil YZ'nin kendi kısıtı (raf 7 + çapa 1 = 8 harf kurallara uygun olurdu) ve bu düzeltmeyle DEĞİŞMEDİ.
- **Genişleyen bölge:** Bir oyuncunun bölgesi köşe bölgesiyle sınırlı değil — köşesinden başlayıp, yalnızca kendi taşlarıyla ortogonal olarak bağlı hücrelere doğru genişler (`computeTerritory`/`computeAllTerritories`, `src/utils/validator.ts`). Genişleme monoton ve sadece oyuncunun kendi bölgesinden mümkündür: rakip taşları zinciri taşımaz. Her hamleden sonra tahtadan yeniden hesaplanır; `Board.tsx` bu dinamik bölgeleri hem boş hücre tonlamasında hem de bölgenin tam dış hattında (`buildOutline`) gösterir. Sonuç olarak, bir oyuncu vergi ödeyerek rakip bölgesine koyduğu taşı kendi zincirine (köşesine kadar kesintisiz kendi taşlarıyla) bağlarsa, o hücre bir sonraki hesaplamada kendi bölgesine geçer ve rakibin bölgesi orada küçülür — izole (zincire bağlanmayan) bir taş ise rakibin bölgesinde kalmaya devam eder. Bu, rakibin kendi 4×4 köşe bloğu için de geçerlidir — o blok hiçbir koşulda dokunulmaz değildir, yalnızca henüz kimse tarafından fethedilmemiş hücreler için taban/varsayılan sahiplik sağlar (bir kale fethi gibi düşünülebilir): rakip kendi köşesinden (ya da önce izole bıraktığı bir taşı sonradan zincirine bağlayarak) kesintisiz kendi taşlarıyla bu blokun içine kadar ulaşırsa, o hücreler — teorik olarak blok tamamen de olsa — asıl sahibinden rakibe geçer. Bir hücre aynı anda tek taş barındırdığından iki oyuncunun bölgesi asla çakışmaz (`computeAllTerritories` tüm oyuncuların "fetih zincirini" önce ayrı ayrı hesaplayıp köşe bloklarındaki taban iddiayı buna göre çözer).
  **İstisna — kendi 4×4 köşe bloğunun İÇİNDEKİ boş hücreler zinciri taşır:** Yukarıdaki "boş hücreler zinciri taşımaz" kuralı yalnızca bloğun *dışındaki* boş hücreler için geçerli. Bir oyuncunun kendi köşe bloğu içindeki, henüz kimse tarafından ele geçirilmemiş (fiilen rakip taşı bulunmayan) hücreler baştan itibaren o oyuncu için "geçit" sayılır (`computeConqueredChain` artık bu hücreleri de zincirin başlangıç tohumuna dahil ediyor) — böylece o oyuncu 4×4 bloğun HERHANGİ bir kenarına bitişik yeni bir taş koyduğunda (taş kendi renginde olduğu sürece), köşenin tam ucundaki başlangıç hücresinden fiilen taş taş ilerlemiş olmasına gerek kalmadan bölgesi oraya kadar hemen büyür. Örnek: bir oyuncunun 4×4 bloğunda hiç taş olmayan bir satırın hemen üzerine kendi renginde 4 harf (`MÜJD` gibi) koyup mevcut bir rakip taşına (`E`) bağlanarak kelime kurarsa — `MÜJD` bloğun boş (ama kendine ait) hücresine bitişik olduğundan bölgesine dahil olur, ama `E` rakibe ait GERÇEK bir taş olduğundan (zincir bloğun dışında hâlâ yalnızca gerçek bağlı taşlar üzerinden ilerlediğinden) bölgeye dahil olmaz ve rengini korur. **Bloğun içine sızmış DESTEKSİZ rakip taşı da geçittir (24 Ağustos 2026 — kural DEĞİŞTİ):** Bu cümle önceden şöyleydi: *"izole bir rakip taşı o tek hücrede zinciri kesip diğer boş hücrelerden dolaşılmasına neden olur"*. Bir kullanıcı gerçek bir oyunda bunun tutarsızlığını yakaladı: rakip onun 4×4 bloğunun üst satırına bağımsız taşlar koymuş (kendi zincirine bağlı DEĞİL), o da bu taşlardan birine asarak blok DIŞINA bir kelime kurmuş ve bölgesi büyümemişti. Tutarsızlık şurada: o hücre **zaten onun bölgesi sayılıyordu** (taban iddia — rakibin zinciri oraya ulaşmadığı için) ve rakip oraya bitişik oynasa ona **vergi ödeyecekti**; yani hücre kira toplanan ama üzerinden yürünemeyen bir alandı. Kural artık şu: kendi bloğunun içindeki bir hücre, üzerinde rakip taşı olsa bile, o taş **rakibin KENDİ zincirine bağlı değilse** senin zincirini kesmez — hücre **iletken**dir, üzerinden geçilir. Rakip bölgesini oraya gerçekten taşımışsa (taş kendi zincirine bağlıysa) hiçbir şey değişmez: hücre onundur, zinciri keser, sen oraya oynarsan vergi ödersin. **İletken hücre zincire ÜYE olmaz, yalnızca geçirir** — üye olsaydı aynı hücre hem taşın sahibinin hem blok sahibinin zincirine girip "iki oyuncunun bölgesi asla çakışmaz" değişmezini kırabilirdi (ölçüldü). Uygulama iki geçişli: önce her oyuncunun SAF zinciri (yalnızca kendi taşları), sonra "bu rakip taşı destekli mi" sorusu O saf zincire sorulur — kapıyı ikinci geçişin kendi sonucuna sormak dairesel olurdu. İstisna kendiliğinden dar kalıyor: blok DIŞINDAKİ bölgen zaten yalnızca kendi taşlarından oluştuğundan bu kural **sadece kendi 4×4 bloğunun içinde** çalışabilir; tarafsız alandaki izole bir rakip taşı hâlâ zinciri keser. Golden vector'lar yeniden üretildiğinde **sıfır fark** çıktı (yani mevcut senaryoların hiçbiri bu dala girmiyordu) — tam da bu yüzden `territory.json` fixture'ı eklendi: beş vaka, biri kuralın NEGATİF dalı (`destekli_rakip_tasi_keser`), ve fixture'ın kurala duyarlı olduğu kural geri alınıp yeniden üretilerek kanıtlandı (18 → 16 hücre).
- **Merkez bonus bölgesi:** Köşeler 4×4'e küçülünce ortada kalan şerit otomatik olarak 5×5'lik bir kare olur (`BONUS_ZONE`/`inBonusZone`, `src/game/constants.ts`) — tüm klasik bonus kareleri (K2/H2/H3) kaldırıldı, yerine bu tek bölge geldi. Bu bölgedeki bir hücreye o turda **yeni** bir taş konursa kelimenin puanı x2 olur — klasik bonus kare gibi, yalnızca hücre ilk kullanıldığı turda etkilidir (`wordPoints`, `src/utils/validator.ts`). Önceden (önceki bir turda) o hücreye konmuş bir taşa sırf bağlanmak/geçmek x2 kazandırmaz. Tahtanın tam ortasındaki tek hücre ayrıca X3'tür (üç kat kelime) — aynı şekilde yalnızca o hücreye o tur yeni bir taş konursa. X2 ve X3 hiçbir zaman aynı kelimede birleşmez: bir kelimenin yeni taşlarından biri X3 hücresindeyse o kelime tamamen ×3 sayılır — kelimenin başka bir yeni taşı ayrıca X2 bölgesine düşse bile üstüne X2 eklenmez (`wordPoints`, `src/utils/validator.ts`). X3'e hiç değmeyen bir kelime, yeni bir taşıyla X2 bölgesine düşerse sadece ×2 olur. (Aynı hamlede oluşan farklı kelimeler birbirinden bağımsızdır — biri X3, diğeri X2 alabilir, ama bunun sebebi iki ayrı kelimenin kendi kurallarını uygulaması, tek bir kelimenin çarpanları birleştirmesi değildir.) Board'da bölgenin arka planına büyük bir "X2" filigranı yazılır (köşelerdeki oyuncu numarası filigranıyla aynı mantık); merkez hücre altın zeminden ayrılan turuncu bir zeminle kendi "X3" etiketini taşır.
- **Köşeye giriş:** İlk hamleden sonra bir rakibin bölgesine taş koymanın hiçbir ön koşulu yok — her zaman serbest (eski "ihlal"/breach durumu kaldırıldı).
- **Bölge vergisi:** Bu turda konan taşlardan biri bir rakip bölgesinin (genişlemiş dinamik alan) içine düşüyorsa (girme) ya da kendisi bölgenin dışında kalsa bile sınırına bitişikse (değme), hamlenin puanından bir pay bölge sahi(pleri)ne aktarılır. Etkileşilen rakip bölge sayısına (n) göre oynayanın payı küçülür: n=1'de 2/3 oynayanda kalır, 1/3 tek bölge sahibine gider; n=2'de yarısı (1/2) oynayanda kalır, kalan yarısı iki bölge sahibi arasında eşit paylaşılır (kişi başı 1/4); n=3'te 1/3 oynayanda kalır, kalan 2/3 üç bölge sahibi arasında eşit paylaşılır (kişi başı 2/9) — genel formül, her bölge sahibinin payı `basePts*(n+1)/(6n)` (`computeInvasionSplit`, `src/utils/validator.ts`). İnsan oyuncu için "Oyna" öncesinde onay modalı (`invasionConfirm` state) gösterilir. YZ için de aynı kural otomatik uygulanır (`findAIMove` kendi bölge genişlemesini hesaba katarak güvenli/güvensiz hamleleri karşılaştırır).
  **Terminoloji (19 Ağustos 2026, kullanıcı sordu: "bazı yerlerde bölge vergisi, bazı yerlerde sınır ihlal vergisi diyoruz; hangisi daha yaygın?"):** İkisi AYNI şeyin iki farklı yüzü ve ayrım bilinçli — **`sınır ihlali` EYLEMİN adı** (onay diyaloğu başlığı `Sınır İhlali!` — `App.tsx`/`OnlineGameScreen.tsx`/portun `invasion_confirm.dart`'ı; `MoveHistoryModal` rozeti `Sınır İhlali`), **`bölge vergisi` o eylemin BEDELİNİN adı** (`HelpModal`'ın "Bölge Vergisi" bölümü + hızlı başlangıç maddesi, `submit_move`'un hata mesajları, bu doküman). Sayım yapıldığında tek gerçek tutarsızlık `Landing.tsx`'in "Nasıl oynanır" 4. adımıydı: `"Sınır ihlal vergisine dikkat!"` ikisini birleştirip projede başka HİÇBİR yerde geçmeyen üçüncü bir terim uyduruyordu (üstelik "ihlal vergisi" dilbilgisi olarak da tökezliyor). Başlık **"Bölge vergisine dikkat!"** oldu — karşılama katmanı kuralları ilk kez anlatan yüzey, orada verginin kanonik adı geçmeli. Aynı turda kod YORUMLARINDAKİ iki ölü varyant da (`köşe vergisi` → `types.ts`/`gameReducer.ts`, `sınır vergisi` → `validator.ts` + `_game/validator.ts` + portun `validator.dart`'ı) `bölge vergisi`ne çekildi; davranış değişmedi, golden vector'lar yeniden üretildi ve **sıfır fark** çıktı. Yeni bir yüzey eklerken bu ikiliği koru, üçüncü bir terim üretme.
- **Oyun bitişi:** Raf boş + torba boş → oyun biter. Her oyuncunun kendi elinde kalan raf taşlarının puanı kendi skorundan düşülür — rafını bitiren oyuncuya diğerlerinin kalan taş puanları eklenmez (`endGame`, `src/game/gameReducer.ts`). Alternatif: tüm oyuncular arka arkaya MAX_PASS_ROUNDS tur puansız geçerse (pas VEYA taş değiştirme — ikisi de skoru etkilemediğinden ve taş değiştirme torbadaki taş sayısını azaltmadığından aynı sayaca dahildir, yoksa oyuncular sürekli taş değiştirerek oyunu hiç bitirmeyebilirdi) biter. İstisna: oyunu bitiren hamledeki taşların TAMAMI jokerse (başka hiçbir harf yoksa) ekstra bir bitiş bonusu kazanılır — 1 joker +25, 2 joker +50 (`jokerFinishBonus`, `src/game/constants.ts`).
- **Tahta yakınlaştırması (1 Eylül 2026):** Tahtanın İÇİNE çift dokunuş 2×
  yakınlaştırır (dokunulan noktaya odaklı), zoom açıkken tahta parmakla
  kaydırılır, tekrar çift dokunuş eski hâline döndürür. Kapsam yalnızca
  tahta — raf/başlık/butonlar kımıldamaz. **Tek dokunuşlar birebir korunur
  ve GECİKMEZ:** ilk dokunuş normal işini yapar (taş konur ve KONDUĞU YERDE
  KALIR), pencere içinde gelen ikinci dokunuş yalnızca yutulup zoom'u
  değiştirir; çift yalnızca boş kareye/boşluğa/çerçeveye dokunuşla başlar,
  taşa dokunuş (geri alma, anlam penceresi, joker) çift BAŞLATAMAZ. Kaynak
  `src/utils/boardZoom.ts` + `src/hooks/useBoardZoom.ts`; iki oyun ekranı da
  aynı hook'u kullanır. **Port ile AYNI davranış** (kullanıcı kararı: *"her
  yerde aynı deneyim olsun"*) — port karşılığı
  `mobile/app/lib/src/ui/game/board_zoom.dart`, biri değişirse öteki de.
  ⚠ Kabul edilen tek yan etki: taş konduktan sonra 300 ms İÇİNDE aynı
  bölgeye (40 px) yapılan dokunuş çift sayılır, yani geri alma yerine zoom
  açar — insan ritminde erişilmiyor, testler bu yüzden araya 350 ms koyuyor.
  **Tanıtım balonu (1 Eylül 2026):** oyun ekranı açılışında merkez kareyi
  işaret eden tek seferlik ipucu — *"Boş kareye veya çerçevesine çift
  tıklama tahtayı büyütür. Hemen dene!"*. Kural İKİ değere birden bakıyor
  (`src/utils/onboarding.ts` → `shouldShowZoomHint`): gösterim sayacı
  (tavan 2) VE "denedi mi" — zoom bir kez denenirse balon anında kapanır ve
  bir daha hiç çıkmaz, hiç denenmezse ikinci bir açılışta bir kez daha
  çıkar. Bayraklar cihaz-yerel, yani Canlı oyunda hem açan hem karşı taraf
  kendi ilk açılışında görür. Port ikizi: `FlagsStore.shouldShowZoomHint`;
  metin iki tarafta BİREBİR aynı olmalı.
- **Joker (`?`):** 2 adet, 0 puan, oynanırken herhangi bir Türkçe harfe dönüşür. **Tahtaya konmuş bir jokerin `0` puanı KIRMIZI yazılır** (token `red`/`kRed`, 28 Ağustos 2026 kullanıcı isteği) — jokerin nereye harcandığı tahtada görünsün diye; RAF taşı bilinçli olarak dışarıda (orada ★ zaten ayırt ediyor). `Tile.tsx` ↔ `tile_widget.dart`, ikisi de testli. Tahtaya bu turda konmuş (henüz "Oyna" ile onaylanmamış) bir jokere tekrar dokunmak artık onu geri almaz — `WildcardModal` tekrar açılır (başlık "Jokeri Hangi Harfe Çevir?") ve seçilen yeni harf `SET_WILD_LETTER` action'ıyla (`src/game/gameReducer.ts`) hücredeki `wildLetter`'ı günceller; taş geri alınmaz. Geri alma bu modda hâlâ iki yoldan mümkün: modaldeki "Geri Al" butonu (`RECALL_CELL` dispatch eder) ya da taşı doğrudan rafa sürükleyerek (mevcut sürükle-bırak `RECALL_CELL` yolu, dokunmadan ayrışır — sürükleme hâlâ eski davranışı korur, yalnızca hareketsiz dokunuş/tık yeni davranışa geçti). Sıradan (joker olmayan) yerleştirilmiş bir taşa dokunmak hâlâ doğrudan geri alır, davranış değişmedi. `App.tsx` (yerel/YZ oyun) ve `OnlineGameScreen.tsx` (Canlı oyun) aynı deseni birebir paylaşıyor (`pendingWild.editing` bayrağı) — biri değişirse diğeri de güncellenmeli.
  **Dokunmatikte joker dalı `swallowNextClick()` KURMAK ZORUNDA** (`src/utils/ghostClick.ts`, 22 Ağustos 2026): tarayıcı jestin `pointerup`ından SONRA compat `click` üretir ve pencere o anda açıldığından click hücreye değil MODALA düşer (joker sessizce başka harfe dönüyor ya da pencere anında kapanıyordu). Raftan sürüklenerek konan joker de aynı korumayı taşır. **Kural: Sınıf 1'de "bu click zaten hiçbir şey yapmıyor" gerekçesiyle yutmayı ATLAMA** — 28 Ağustos'ta tam bu varsayım `draftRescue` ile geçersiz kalıp iki taşı birden geri aldırdı. Flutter portu ETKİLENMEZ (compat click yok). Regresyon `tests/smoke.spec.ts`te dokunmatik bağlamda (masaüstü profilinde hata GÖRÜNMEZ). Ölçümler, olay zinciri ve üç vakanın tamamı: `docs/decisions/touch-ux-bugs.md` → "Joker düzenleme yolu — Sınıf 1'in ilk vakası".
- **YZ seviyesi (Kolay / Normal / Zor — ROADMAP #23, motor Faz 2, 6 Eylül 2026):** `findAIMove(..., level)` (`src/utils/ai.ts`) artık `findAIMoves` (en iyi N hamlenin sıralı listesi; vergisiz hamle varsa yalnızca onlar) + `pickTopMove` (boş → null; tek eleman → o, rastgele değer ÇAĞRILMAZ; birden fazla → TEK `nextRandom()`, `floor(r·len)`) çiftidir; N `AI_LEVEL_TOP_N` (`src/game/constants.ts`: Kolay 4 · Normal 1 · Zor 1 — Zor Faz 5'e kadar Normal). **Normal hiç rastgele değer tüketmez**, bu yüzden golden'lar bayt-eş kaldı; Kolay torbayla AYNI enjekte edilebilir kaynaktan tüketir ve `reducer_ai2_kolay.json` bunu kilitler. Seviye `GameState.aiLevel?` (opsiyonel; yoksa Normal, Normal'de JSON'a YAZILMAZ — eski kayıtlar/bulut kayıtları/Canlı oyunlar hep alansız, `STORAGE_VERSION` sabit) — `START` payload'ıyla bir kez yazılır, değiştiren action YOK. **Ürün yüzeyi Faz 3'te geldi (6 Eylül 2026):** Setup'ın YZ formunda "Oyuncu sayısı"nın altında **Zorluk** radyogrubu (`SELECTABLE_AI_LEVELS`, `src/utils/aiLevel.ts` — Zor Faz 5'e kadar listede YOK), `App.startLocalGame` yalnızca Kolay/Zor'u payload'a koyar (Normal = alan yok — `'normal'` YAZMA, aynı şeyi ikinci biçimde söylemek olur), rövanş `state.aiLevel`i taşır. `buildGameRecord` → `games.ai_level` (Normal'de yine alansız → null); `leaguePoints(rank, count, surrendered, level)` dört kartta (`GameOver`/`GameHistoryModal`/`RecentGamesSection`/`SharedGamePage`) seviyeyle hesaplanır; `AiLevelBadge` YZ oyununda HER seviyede çıkar (6 Eylül 2026 gece, kullanıcı: Kolay YEŞİL · Normal TURUNCU · Zor KIRMIZI — `AI_LEVEL_BADGE_CLASS` ↔ port `aiLevelBadgeColor`), Canlı oyunda hiç çıkmaz — "YZ oyunu mu" kararı çağıranda (`aiLevelForBadge(raw, isAiGame)`: kartlarda `online_game_id`, paylaşım sayfasında kadroda YZ, oyun ekranında App.tsx ↔ OnlineGameScreen). Rozet tahtanın alt şeridinde de (`Board.aiLevel`, "Hamleler"in yanı, Canlı'daki "· Mesajlaşma"nın yeri; dokunulamaz, şeridin beş öğe sayımına GİRMEZ). Zorluk seçici butonları Arkadaşınla alt-sekmelerinin (`LiveGamesTab`) sınıf dizesiyle aynı, "Oyuncu sayısı"nın büyük butonu değil. ⚠ `leaguePoints`in `level`ine JS varsayılanı VERME — `verify-league-points` ariteyi `.length`le okuyor. Terminoloji tek: **Zorluk: Kolay · Normal · Zor**. **Port ikizi Faz 4'te (6 Eylül 2026):** `mobile/app/lib/src/util/ai_level.dart` + `ui/ai_level_badge.dart`, aynı sözleşme (Normal yazılmaz; `NewGameRecord.ai_level` yalnızca doluysa) — `ai_level_parity_test.dart` web etiket/seçilebilir liste/seviye açıklamaları/yardım paragrafını kilitler, Zor açılırken iki liste AYNI PR'da. **Seçici altı açıklama (6 Eylül 2026 akşamı, kullanıcı: *"bilimsel iş yapmıyoruz"*):** her seviyede kullanıcıya hitap eden bir cümle (`AI_LEVEL_PITCH`) + `leaguePoints`ten türetilen puan cümlesi (4 kişilikte ikincilik dahil) — `aiLevelDescription(level, count)`, port `aiLevelDescription`; YZ'nin nasıl zayıflatıldığı ürün metnine GİRMEZ, Zor'un metni bugünden hazır. ⚠ Üç kopya: Dart `aiLevelTopN` (golden `ai_level.json`) ve Edge `_game/constants.ts` (`verify-edge-engine-parity`, tohumlu Kolay adımı dahil); `AiLevel` tipinin kaynağı `src/game/types.ts`, `database.types.ts` yeniden dışa aktarır.
- **Torba:** Oyuncu sayısından bağımsız olarak sabit 100 taş (Türkçe dağılım, `src/data/tiles.ts`). Not: bir ara tüm modlarda 186'ya çıkarılmıştı, ama simülasyon torbanın gerçek bitirişini (rafını torba boşken tamamen bitirme + rakip puanlarını kapma) neredeyse imkânsız kıldığını gösterdi (4 oyunculuda 0/10), bu yüzden 100'e geri dönüldü. Bölge artık statik 5×5 değil dinamik/genişleyen olduğundan (bkz. yukarı), 4 oyunculu oyunlarda köşe sınırıyla etkileşim için torbayı büyütmeye (eski `BAG_SCALE_BY_PLAYER_COUNT` denemesi) gerek kalmadı; kaldırıldı.
- **Teslim olma (kademeli):** Bir oyuncu teslim olduğunda (`Player.surrendered`, `SURRENDER` action, `src/game/gameReducer.ts`) oyun tümüyle bitmez — o oyuncu sırayı devretmeden çekilir, kalan oyuncular (YZ ve/veya diğer hotseat oyuncuları) oynamaya devam eder; sıra rotasyonu ve pas-turu sayacı yalnızca teslim olmamış oyuncuları sayar (`nextActiveIndex`/`activePlayerCount`). Teslim olan oyuncunun puanı dondurulmaz, **sıfırlanır** (`score: 0`) ve rafında kalan kullanılmamış taşlar torbaya geri karıştırılır (`shuffle`) — böylece o taşlar kalan oyuncular için tamamen kaybolmaz. Oyun yalnızca teslim sonrası aktif oyuncu sayısı 1'e düşünce biter: 2 kişilik oyunda tek teslim bunu anında tetikler; 4 kişilikte sırasıyla 3 → 2 → (üçüncü teslimde) 1 aktif oyuncuya iner ve o son kalan oyuncu kazanır — sıralama, teslim olanları puanlarından bağımsız olarak her zaman en sona koyan `rankPlayers` (`src/utils/ranking.ts`) ile hesaplanır ve hem `GameOver` hem `buildGameRecord`'un (`App.tsx`) skor kaydı bunu kullanır. **29 Temmuz 2026'da logo davranışı değişti — artık manuel/anlık bir teslim yolu yok:** Öncesinde logoya tıklamak bir "Çık" onay modalı açıyor, sırası gelen hâlâ oyundaki insan oyuncuyu (hotseat'te herkes kendi sırasında teslim olabilsin diye) ya da yoksa hesap sahibini (1. oyuncu) hedefleyip `SURRENDER` dispatch ediyordu — Canlı oyundaki 48 saatlik zaman aşımı modeli (bkz. "Canlı Oyun — Faz 3.6") YZ tarafına da uygulanınca (kullanıcı isteği) bu modal tamamen kaldırıldı: logo artık HER DURUMDA (onay sorulmadan, kimin sırası olduğuna bakılmadan) doğrudan Setup'a döner (`handleLogoClick`, `App.tsx`, bkz. aşağıdaki "Devam eden oyunun kalıcılığı"). Setup'taki Yapay Zeka sekmesinde çalışan mevcut kurulumda zaten yalnızca 1. oyuncu (hesap sahibi) insan olabildiğinden (diğerleri her zaman YZ), bu modalın hotseat dalı ("başka bir insan oyuncuyu teslim et, diğerleri devam etsin") pratikte hiç tetiklenmiyordu — kaybı yok. `SURRENDER` action'ının kendisi (`gameReducer.ts`) ve yukarıda anlatılan kademeli teslim mekaniği (puan sıfırlama, raf→torba, `rankPlayers` sıralaması) hâlâ duruyor, ama artık local oyunda hesap sahibi için bunu tetikleyen TEK yol aşağıdaki 7 günlük terk edilme kuralı (`takePendingAbandonedGame`, gecikmeli -2 ceza) — anlık bir "Çık" kararı artık mümkün değil. `games.players` jsonb'sindeki her satırda hâlâ `surrendered` alanı var; `GameHistoryModal` yalnızca teslim olan oyuncunun kendi satırında (genel/üst köşede değil) "Teslim Oldu" rozeti gösterir.
- **Teslim sonrası izleme (4 kişilik) — 5 Eylül 2026'da SİLİNDİ:** `App.tsx`
  bir `spectating = rackPlayer.surrendered && !state.isGameOver` dalı
  taşıyordu (raf/aksiyon butonları yerine "Teslim oldun — oyunu izliyorsun"
  bandı + `GameHeader`'ın `exitDisabled` prop'uyla kilitli çıkış). 29 Temmuz
  2026'da logo onaysız Setup'a dönmeye başlayınca `SURRENDER`'ı UI'dan
  tetikleyen tek yol kalkmış, dal ERİŞİLEMEZ olmuş ama "ileride lazım olur"
  diye bırakılmıştı. Temizlik geçişinde ölçüldü: `SURRENDER` `src/` içinde
  hiçbir yerden dispatch edilmiyor ve **Flutter portu bu bandı hiç
  portlamamış** — yani kod ölü OLMAKLA KALMIYOR, web↔port paritesini de
  bozuyordu. Dal kaldırıldı (geri gerekirse git geçmişinde). Reducer'ın
  `SURRENDER` case'i DURUYOR: kavram geçerli, port da taşıyor ve
  `buildGameRecord`'un `surrendered`/`surrenderingIndex` yolu 7 günlük
  terk-edilme akışında CANLI kullanılıyor — kaldırılan yalnızca ona bağlı UI.
- **Teslim olanın bölgesi doğal alana döner:** Bir oyuncu teslim olduğunda bölgesi (`computeAllTerritories`, `src/utils/validator.ts`) — hem kendi köşesi hem daha önce fethettiği hücreler dahil — o oyuncu için boş `Set` olarak hesaplanır: kimseye ait olmayan, sahipsiz/"doğal" alana döner. Sonuç: Board'daki kalın dış hat çizgisi kalkar (`buildOutline`, `src/components/Board.tsx` aynı fonksiyonu tüketir), ve o bölgeye giren/sınırına değen kimse artık bölge vergisi ödemez (`computeInvasionSplit` de aynı `computeAllTerritories`'i kullandığından otomatik yansır). YZ'nin hamle değerlendirmesi de (`src/utils/ai.ts`) aynı fonksiyonu çağırdığından, YZ'ler teslim olmuş oyuncunun eski bölgesini serbestçe (paylaşımsız) kullanır.
- **Devam eden oyunun kalıcılığı, 7 günlük terk-edilme cezası ve offline
  kuyruğu:** kendi dosyasına taşındı —
  `docs/decisions/local-game-persistence.md` (misafir localStorage ↔
  girişli `local_game_saves` ayrımı, `savedGame` akışı, gecikmeli -2 cezası
  ve e-postası, `cloudSaveMirror` offline aynası, `gameSync` kuyruğu).
## Font Yükleme Stratejisi

Tüm fontlar (`src/fonts/*.css`, `main.tsx`'te import edilir) kendi sunucumuzdan `.woff2` olarak servis edilir, `font-display: swap` ile. 23 Temmuz 2026'da (PageSpeed'in render-blocking uyarısı yüzünden hepsi base64-gömülü tek bir CSS'ten bu yapıya geçirildiğinde) bu, logoda (Caveat) ve daha az belirgin biçimde Space Grotesk/Space Mono'da görünür bir FOUT'a yol açtı. Bu tek seferlik bir sorun değil: uygulama sık deploy edildiğinden ve PWA service worker'ı (`src/lib/pwa.ts`) her deploy sonrası arka planda güncelleyip sayfayı yeniden yüklediğinden, bir sonraki açılışta hâlâ eski (düzeltilmemiş) kod bir kez daha çalışıp sıçramayı tekrarlıyor — bu, herhangi bir düzeltmenin "işe yaramadığı" izlenimi verebilir, aslında düzeltme sonraki (arka plandaki güncelleme sonrası) açılışta devrede.

- **Logo (Caveat)** — tamamen kaldırıldı, statik SVG path'lere çevrildi (bkz. `LogoMark`, yukarıdaki "Bileşen Notları").
- **Space Grotesk 700 / Space Mono 400 / Space Mono 700** — Setup ekranında ilk boyamada görünen kalın buton etiketleri/açıklama paragrafı (700/400) ve `GameHeader`'daki skor kutuları (700) bu ağırlıkları kullanır; kullanıcı ikisindeki FOUT'u da ayrı ayrı bizzat bildirdi. `public/fonts/`'a taşınıp `index.html`'den `<link rel="preload">` ile öncelikli indirilir (bkz. ilgili `src/fonts/space-grotesk-inline.css`/`space-mono-inline.css` dosyalarındaki notlar). Bunlar canlı/değişken metin (skor, kullanıcı adı) render ettiğinden logodaki gibi statik path'e çevrilemez — preload en iyi pratik çözüm, garantili değil.
  **1 Ağustos 2026 — Space Mono 700 örneği, yanlış teşhisin nasıl zaman kaybettirdiğine dair bir ders:** Kullanıcı, YZ'nin skor kutusunun (dar kutu, `font-mono font-bold`) her hamleden kısa bir süre sonra "1…" diye kırpılıp kendiliğinden düzeldiğini bildirdiğinde, önce `GameHeader.tsx`'teki kutu genişliği/`border` hesaplarında (bkz. "Bileşen Notları" → `GameHeader` skor kutuları, madde 3) bir hata arandı ve gerçek de bir hata bulunup (`border`→`outline`) düzeltildi — ama kullanıcı PR Preview'da (her açılış TAZE bir sayfa, önbelleksiz font) sorunun AYNEN devam ettiğini bildirince asıl kök sebebin bu maddede zaten TANIMLANMIŞ olan (o zamana kadar "henüz raporlanmadı" diye bırakılmış) Space Mono 700'ün preload edilmemesi olduğu anlaşıldı — sayfa önce geniş bir fallback monospace'le boyanıp gerçek (dar) font `swap` ile geldiğinde yeniden akıyordu, dar YZ kutusunda bu ara an tam kenardan taşıp kırpılmaya yol açıyordu. **Ders:** "kısa süre görünüp kendiliğinden düzeliyor" tarifi güçlü bir FOUT/font-swap sinyali — bu proje zaten aynı belirtiyi Caveat/Space Grotesk'te yaşamıştı, yeni bir yerde görülünce önce BU listeye (henüz preload edilmemiş ağırlıklar) bakılmalı, layout/CSS box-model hesaplarına dalmadan önce.
- **Diğer ağırlıklar (Space Grotesk 400/500/600) ve Nunito (taş harfi fontu)** — henüz raporlanmadığından ve kritik ilk-boyama yolunda olmadığından dokunulmadı, hâlâ eski `./files/` + yalnızca-swap yolunda. Aynı şikayet başka bir ağırlıkta/yerde görülürse aynı desen uygulanmalı: dosyayı `public/fonts/`'a taşı, `index.html`'e `<link rel="preload">` ekle, `vite.config.ts`'teki `includeAssets`'e ekle (PWA precache için).

## Form Input'ları — iOS Safari Zoom Kuralı

`input`/`textarea`/`select` elemanının hesaplanan font-size'ı **her zaman
≥16px** kalmalı; kural `index.css`'te elemente göre ve `!important` ile
uygulanıyor (`input, textarea, select { font-size: 16px !important; }`),
yani yeni bir form/modal bunu kendiliğinden miras alır — `text-sm`/`text-xs`
sınıfı verilse bile. Aksi hâlde iOS Safari odaklanınca sayfayı yakınlaştırır
ve geri açmaz. Neden `!important` (ilk düzeltmenin yanlış `@layer`
gerekçesi, Tailwind v3'ün native `@layer` üretmediğinin ölçümü):
`docs/decisions/touch-ux-bugs.md` → "iOS Safari Zoom Bug'ı".

## Türkçe Dil Notu

Büyük/küçük harf dönüşümünde **mutlaka** `trUpper()` / `trLower()` (`src/utils/turkish.ts`) kullanılmalı. Native `toUpperCase()`/`toLowerCase()` i/İ ve ı/I harflerini yanlış dönüştürür.

Alfabetik sıralamada da aynı sebeple native `<`/`localeCompare()` (locale verilmeden) yerine **mutlaka** `trCompare()` (`src/utils/turkish.ts`, `localeCompare(..., 'tr')` sarmalayıcısı) kullanılmalı — aksi halde ş/ğ/ü/ö/ç/ı/İ gibi harfler yanlış sıralanır (`AdminDashboard.tsx`'teki Üyeler tablosunda zaten bu desen kullanılıyordu, `trCompare` bunu 1 Ağustos 2026'da paylaşılan bir yardımcıya çıkardı). **Arkadaş seçim listeleri** (`FriendsModal.tsx`'in Arkadaşlarım/Ara & Ekle sekmeleri, `LiveGameCreateForm.tsx`'in arkadaş seçici, `FriendSuggestModal.tsx`) bu tarihte fark edilen bir hatayla düzeltildi: `fetchFriends()` (`list_friends` RPC'si) isme göre değil `responded_at desc`'e (en son kabul edilen önce) göre dönüyordu, `searchUsersForFriend`/`listUsersForFriend` ise backend'in `order by name`'i veritabanının varsayılan (Türkçe'ye özel olmayan) collation'ına güveniyordu — üçü de artık `trCompare` ile client tarafında (yeniden) sıralanıyor; "Tüm Üyeler" sayfalı listesinde bu sıralama her yeni sayfa geldiğinde TÜM birikmiş listeye uygulanıyor (yalnızca son sayfaya değil), aksi halde backend collation'ının sayfa sınırlarında Türkçe harfleri yanlış gruplaması düzelmeden kalırdı. `list_incoming_friend_requests` (İstekler sekmesi) bilerek dokunulmadı — bir seçim listesi değil, `created_at desc` (en yeni istek önce) burada daha anlamlı.

## Supabase

Env değişkenleri olmadan uygulama offline çalışır — `useAuth` içindeki
`configured` flag'i `false` olur ve tüm hesap/lider tablosu özellikleri
gizlenir. Lokal geliştirmede Supabase gerekmez.

**Tarihli anlatılar/post-mortem'ler `docs/decisions/supabase-ops.md`'ye
taşındı** (Brevo SMTP'ye geçiş ve teslimat sorunu, SPF/DKIM/DMARC'ın gerçek
hâli, `feedback-reply`/`admin-send-message`'ın doğuşu, migration geçmişinin
iki kez repodan kopması, workflow'ların kaldırılması, dal temizliği). Burada
yalnızca HER SEFERİNDE uygulanacak kurallar var.

### E-posta — üç ayrı sistem, karıştırma

| Ne | Nereden | Yapılandırma nerede |
|---|---|---|
| Auth mailleri (kayıt onayı, şifre sıfırlama) | Brevo **SMTP** | Supabase Dashboard → Authentication → Emails (repoda İZ YOK) |
| Uygulamanın gönderdiği mailler | Brevo **Transactional API** | `BREVO_API_KEY` Edge Function secret'ı (repoda İZ YOK) |
| Gelen mail | **Zoho** (`destek@`) | Zoho paneli + DNS |

Şablonların kaynağı `supabase/email-templates/*.html` ama **otomatik
okunmaz** — her değişiklik Dashboard'a ELLE yapıştırılır. "Mailde branding
yok" denirse ilk bakılacak yer burasıdır.

⚠ **Gönderen seçimi zorunlu:** `noreply@` = makine konuşuyor, `destek@` =
insan konuşuyor (`_shared/email.ts` → `KELIMEKI_SENDER` ↔
`KELIMEKI_SUPPORT_SENDER`). `sendBrevoEmail`'e `sender` verilmezse noreply@
kullanılır. Yeni bir mail gönderen fonksiyon yazarken ikisinden birini SEÇ,
üçüncü bir adres uydurma. Ayrıntı: `docs/decisions/support-email.md`.

### Migration'lar — CI YOK, her migration ELLE uygulanır

Kullanıcı iPad'den çalışıyor; bunu tetikleyecek bir CLI/CI erişimi yok.
**Migration dosyasını repoya eklemek TEK BAŞINA YETMEZ.** Her seferinde:

1. Dosyayı `supabase/migrations/` altına yaz.
2. SQL'i kullanıcıya açıkça göster.
3. Supabase MCP ile canlıya uygula, sonra `execute_sql` ile DOĞRULA.
4. Uyguladığını açıkça söyle — sessizce dosya eklemekle yetinme.
5. **ZORUNLU:** `list_migrations` çağır, gerçek versiyon numarasını dosya
   adındaki zaman damgasıyla karşılaştır; tutmuyorsa `git mv` ile düzelt ve
   commit'e dahil et. (Bu adım atlandığı için 23 Temmuz 2026'da ayrı bir PR
   açmak gerekti.)

### Edge Function deploy — `deploy_edge_function`'ın İKİ tuzağı

1. **Dosya yerleşimi:** `entrypoint_path: "source/index.ts"` VER, entrypoint
   dosyasının adını da `"source/index.ts"` YAP, kardeş bağımlılıkları
   (`_shared/email.ts`) `source/` öneki OLMADAN adlandır. Doğru göreli yol
   her zaman `'../_shared/email.ts'`.
2. **`verify_jwt` sessizce sıfırlanır:** parametre geçilmezse araç `true`
   varsayar ve önceki değeri KORUMAZ. **Her deploy'dan ÖNCE
   `list_edge_functions` ile mevcut değeri oku ve AYNI değeri açıkça geçir.**
   `false` olması gereken YEDİ fonksiyon (5 Eylül 2026'da canlıdan sayıldı):
   `notify-deadline-warnings`, `notify-friend-request-reminders`,
   `notify-turn-timeout-surrender`, `notify-welcome`,
   `sweep-unconfirmed-accounts`, `inbound-email`, `notify-your-turn`.
   Yedisi de bir cron/webhook hedefi, yani gerçekten herkese açık bir POST
   ucu olmak zorunda; güvenlik geçişi (5 Eylül 2026) üçünü ayrıca okuyup
   doğru yazıldıklarını (atomik iddia, taze pencere, hedefi gövdeden değil
   canlı durumdan alma) kayda geçirdi.
   ⚠ Liste 30 Ağustos'ta SEKİZDİ; sekizinci `push-selftest` teşhis
   fonksiyonuydu ve temizlik geçişinde canlıdan silindi (aşağı bkz.).
   **Yeni bir fonksiyon `verify_jwt: false` alacaksa buraya YAZ** — bu liste
   deploy öncesi okunan tek envanter, eksik kalırsa bir sonraki deploy onu
   sessizce `true`ya çevirir.



## Web'de Yapılacak İşler (mobil porttan gelen fikirler, henüz yapılmadı)

Mobil port (bkz. `mobile/CLAUDE.md`) cihaz testi sırasında bazen web'de de
uygulanması gereken küçük iyileştirmeler ortaya çıkarıyor — bu bölüm o
fikirlerin unutulmaması için bir bekleme listesi, kod DEĞİL. Bir madde
uygulanınca buradan silinip ilgili bölümün kendi tarihli notuna taşınmalı
(kök `CLAUDE.md`'nin genel "değişiklik = tarihli not" disipliniyle aynı).

Şu an bekleyen madde YOK. (Arkadaş ekle simgesi, Çıkış Yap ikonu ve hesap
menüsü tooltip'i 9 Ağustos 2026'da; "Tüm Oyunlarım"daki hamle geçmişi ikonu
12 Ağustos 2026'da; oyun geçmişinin ağ-hatası mesajı 14 Ağustos 2026'da
uygulandı — kayıtları `UserMenu`, `Leaderboard`/`PlayerScoreCard` ve
`GameHistoryModal`/"Skor Kartı" bölümlerindeki tarihli notlara taşındı.)
