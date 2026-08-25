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
npm run test    # Playwright duman testleri (tests/smoke.spec.ts)
npm run generate-golden-vectors  # Flutter portu parite fixture'ları (bkz. "Flutter / Mobil Port")
npm run generate-meanings-db     # Flutter portu için meanings.json → SQLite asset'i
npm run generate-demo-board-dart # Karşılama tahtası → portun intro ekranı için demo_board_data.dart
npm run verify-cloud-save-mirror # Bulut kaydı offline karar mantığı (saf fonksiyon kontrolleri)
npm run verify-draft-rescue      # Iskalanan dokunuşun en yakın taslak taşına yönlendirilmesi
npm run verify-fetch-my-games    # Oyun geçmişi: ağ hatası ↔ boş liste ayrımı (sahte Supabase ucu)
npm run verify-league-tiers      # k-lig kademe/ödül tablosu: migration SQL'i ↔ leagueRank.ts
npm run generate-initial-main-view-golden # Giriş sekmesi kuralı: web→port davranış golden'ı (CI tazeliği zorluyor)
npm run verify-live-games-load    # Canlı oyun listesi: düşen istek sessizce tekrarlanır (boş liste sanılmaz)
npm run verify-demo-board        # Karşılama katmanındaki tanıtım tahtası sözlüğe karşı doğrulanır
npm run verify-remaining-tiles   # "Kalan Taşlar" dökümü ↔ oyun sonu raf düşümü değişmezi
npm run check-doc-size           # doküman boyutu bütçesi (bkz. "Doküman Boyutu Bütçesi")
npm run verify-draft-rescue      # ıskalanan dokunuşun en yakın taslak taşına yönlendirilmesi
npm run verify-error-reporting   # istemci hata telemetrisi: ne kaydedilir/kaydedilmez, tekrar bastırma, hız sınırı
npm run augment-dictionary       # Sözlüğe elle madde ekleme (GTS'siz — bkz. "Sözlüğe Kelime/Anlam Ekleme")
npm run build:dict               # Sözlüğün TAM üretimi — 100 MB'lık GTS kaynağını ister
npm run generate-logo-paths      # LogoMark.tsx + portun logo_mark_data.dart'ını birlikte üretir
npm run generate-klig-paths      # KLigMark.tsx + portun klig_mark_data.dart'ını birlikte üretir
npm run generate-icons           # favicon / app icon (public/) — og-image DEĞİL
npm run generate-og-image        # public/og-image.png (sosyal paylaşım kartı)
npm run generate-play-assets     # Play mağaza ikonu (512) + öne çıkan görsel (1024×500)
```

**`npm run test` neyi kapsıyor, neyi kapsamıyor:** `tests/smoke.spec.ts` kapsamlı bir test paketi DEĞİL — "uygulama açılıyor, 2 kişilik bir oyun başlatılabiliyor, YZ hamle yapıyor, bilinmeyen bir path SPA fallback'iyle açılıyor" düzeyinde bir kritik-yol kontrolü. Buraya kadar hatasız gelmek reducer/YZ/skor/bölge hesaplama zincirinin ucuna kadar çalıştığı ve `ErrorBoundary`'nin devreye girmediği anlamına geliyor.

Projenin geri kalanının çok büyük bölümü (Canlı oyun, mesajlaşma, e-posta bildirimleri, admin paneli) **yapısı gereği otomatik test edilemiyor**: iki ayrı gerçek oturum, gerçek gelen kutusu ve gerçek Supabase Auth gerektiriyor. Bunlar için elle koşulan kontrol listesi ayrı bir dosyada: **`TESTING.md`**. Yeni bir Canlı oyun/mesajlaşma/e-posta özelliği eklendiğinde o listeyi de güncelle — `CLAUDE.md`/`README.md` senkron kontrolüyle aynı refleks.

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
| `src/data/meanings.json` | `npm run generate-meanings-db` |
| `LogoMark`/`KLigMark` | `npm run generate-logo-paths` / `generate-klig-paths` (ikisi de web+Dart yazar) |
| Canlı oyun / mesajlaşma / e-posta özelliği | `TESTING.md` (elle koşulan liste) |
| `mobile/app/` — sunucuya/platforma dokunan bir şey | `mobile/TESTING.md` (cihazda koşulan liste) |
| Migration | Canlıya uygula + doğrula + `list_migrations` ile dosya adını eşleştir |
| Yeni kullanıcı verisi ya da görünürlük değişikliği | `TermsModal`/`PrivacyModal` |
| `App.tsx`'teki joker/mesaj/raf desenleri | `OnlineGameScreen.tsx` (ikisi deseni paylaşıyor) |
| `mobile/` DIŞINDA bir dosya (port işi sırasında) | kök `CLAUDE.md`/`README.md` — port dokümanı TEK BAŞINA yetmez |

Mobil portun kendi (daha ayrıntılı, Dart'a özgü) sürümü: `mobile/CLAUDE.md`,
"Etki Analizi" ve "Parça Bitirme Kontrol Listesi" bölümleri — orada tek
komutluk bir grep taraması da var.

## Git / Branch Kuralı

- Branch adı: `claude/<kısa-açıklama>` formatı
- Her feature/fix ayrı branch → PR → main'e merge
- Main'e merge = Vercel otomatik deploy tetiklenir

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
deploy bekleniyor demektir. 25 Ağustos 2026'da ölçülen bir kolaylık:
**`kelimeki.com` bu oturumdan `WebFetch` ile doğrudan okunabiliyor**
(`curl`/`bash` hâlâ çıkamıyor) — "doğru sayfa mı yayında" sorusunu cevaplar,
başlık/bayt ölçmez; Flutter/Pages yüzeyi için kanıtlanmadı. Ayrıntı (bu oturumun gözlem sınırı, merge
sonrası dal hijyeni, PR'da CI koşmazsa ne yapılacağı):
`mobile/CLAUDE.md` → "Deploy Doğrulaması".

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
| **active** | İsteğe bağlı okunur ama BÜYÜMEYE devam eder | 120 KB / **200 KB** |
| **frozen** | Dondurulmuş arşiv; okuması opt-in, tek kural BÜYÜMEMESİ | kendi tavanı |

**Sınır aşılınca ne yapılır** (betik zaten yazdırıyor):
- **auto** → tarihli "neden böyle" anlatılarını `docs/decisions/*.md` ya da
  `mobile/docs/*.md`'ye taşı; burada yalnızca HER YERDE geçerli kural/
  değişmez kalsın.
- **active** → yeni bir **cilt** aç: dosyayı bir bölüm/parça sınırından kes,
  dondurulmuş yarıyı betikteki `FROZEN` listesine ekle, yeni girişler aktif
  ciltte devam etsin. Örnek: `mobile/docs/parca-log*.md` (üç cilt).
- **frozen** → arşive yazılmış demektir; girişi AKTİF cilde taşı.

**CI'da koşuyor:** `.github/workflows/docs-size.yml`, yalnızca `**/*.md`
değiştiğinde. `npm install` ve derleme YOK (saniyeler) — bu repoda
"yalnızca doküman değişikliği ücretsizdir" kuralı bilerek korunuyor.

⚠ **Uyarı bandındaki dosyayı bir sonraki dokunuşunda böl.** Uyarı, sınıra
çarpmadan önce hareket etme fırsatıdır; biriktirilirse kontrolün anlamı
kalmaz. Bugün uyarı bandında olanlar: `docs/decisions/components.md`,
`mobile/TESTING.md`, `mobile/docs/parca-log.md`.
(`docs/decisions/live-game-and-friends.md` 25 Ağustos 2026'da tam bu kural
gereği bölündü — 156 KB'lık dosya `friends.md` / `live-game.md` /
`online-game-screen.md` olarak üçe ayrıldı, üçü de 64 KB'ın altında. Kural
işledi: dosya "bir gün" değil, ilk dokunuşta bölündü.)

**Bu dosya (`CLAUDE.md`) da kuralı yazarken 111 KB'a çıkıp uyarı bandına
girmişti** — kuralı yazmak, kuralın konusu olan dosyayı büyüttü. Öngörülen
çare hemen uygulandı: en büyük tek konu bloğu (yerel oyun kalıcılığı, 35 KB)
`docs/decisions/local-game-persistence.md`'ye taşındı, dosya 76 KB'a indi.
Bu, "active" sınıfı için beklenen davranışın örneği: sınıra çarpmadan böl.

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
| Bileşen post-mortem'leri (RemainingTilesModal, GameOver, CountBadge, UserMenu, RelationIcons, AuthModal, AccountSettingsModal, ScoreCard/Leaderboard, Setup, PlayerAvatarRow, LandscapeHint, AddToHomeScreen, useAppIconBadge, Board, GameHeader, HelpModal, LogoMark, useModalA11y, TermsModal/PrivacyModal) | `docs/decisions/components.md` |
| Dokunmatik/hover hata sınıfları (ghost click, drag threshold, sticky hover) | `docs/decisions/touch-ux-bugs.md` |
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
| Sonraya bırakılan ürün fikirleri (karar verildi, henüz yapılmadı) | `docs/decisions/product-backlog.md` |

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
  legal/        # hukuki metinlerin TEK KAYNAĞI + /gizlilik/ · /kullanim-kosullari/ ·
                # /hesap-silme/ statik sayfa üreticisi (bkz. "Hukuki Statik Sayfalar")
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
  utils/        # Saf fonksiyonlar (validator, board, boardSnapshot, ai, bag, gameStorage, cloudSaveMirror, gameRecord, gameSync, feedbackSync, visitTracking, ranking, leaguePoints, leagueRank, onboarding, csvExport, friendInvite, profileFields, platform, offlineNotice, shareLink, pendingLiveGames, errorReporting, ghostClick...)
  data/         # Kelime listesi (~63k), harf dağılımı, kelime anlamları, wordSetLoader (lazy chunk)
  lib/          # Supabase istemcisi ve API sarmalayıcısı
  fonts/        # @font-face tanımları (main.tsx import eder) + files/*.woff2 — bunlardan
                # mplus-rounded-1c-800-subset.woff2 ÜRETİLMİŞ, yalnızca RankSeal'ın harfi
                # (yeniden üretimi: "k-lig Ödül & Rütbe Sistemi" → Rütbe Rozeti Fontu)
  hooks/        # useAuth, useModalA11y, useOnlineStatus, useAppIconBadge, useNicknameAvailability, useRankScores
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
- **Joker (`?`):** 2 adet, 0 puan, oynanırken herhangi bir Türkçe harfe dönüşür. Tahtaya bu turda konmuş (henüz "Oyna" ile onaylanmamış) bir jokere tekrar dokunmak artık onu geri almaz — `WildcardModal` tekrar açılır (başlık "Jokeri Hangi Harfe Çevir?") ve seçilen yeni harf `SET_WILD_LETTER` action'ıyla (`src/game/gameReducer.ts`) hücredeki `wildLetter`'ı günceller; taş geri alınmaz. Geri alma bu modda hâlâ iki yoldan mümkün: modaldeki "Geri Al" butonu (`RECALL_CELL` dispatch eder) ya da taşı doğrudan rafa sürükleyerek (mevcut sürükle-bırak `RECALL_CELL` yolu, dokunmadan ayrışır — sürükleme hâlâ eski davranışı korur, yalnızca hareketsiz dokunuş/tık yeni davranışa geçti). Sıradan (joker olmayan) yerleştirilmiş bir taşa dokunmak hâlâ doğrudan geri alır, davranış değişmedi. `App.tsx` (yerel/YZ oyun) ve `OnlineGameScreen.tsx` (Canlı oyun) aynı deseni birebir paylaşıyor (`pendingWild.editing` bayrağı) — biri değişirse diğeri de güncellenmeli.
  **BULUNAN HATA (22 Ağustos 2026, bir kullanıcı bildirdi — DOKUNMATİKTE bu
  düzenleme yolu baştan beri kırıktı):** *"Tahtaya joker koyup değiştirmek
  için üzerine tekrar tıkladığında tablo açılmadı ve önce konan A harfi
  C'ye döndü."* Kök sebep jokerde ya da reducer'da DEĞİL, olay sırasında:
  dokunmatik tarayıcılar bir jestin pointer olaylarından SONRA uyumluluk
  (compat) `mousedown`/`mouseup`/`click` üretir ve bu üçü hit-test'i
  **O ANDAKİ DOM** üzerinde yapar. Pencere `endDrag`in içinde, yani
  `pointerup` sırasında açıldığından (React ayrık olayı senkron flush eder),
  compat click artık hücrenin değil **YENİ RENDER EDİLMİŞ modalın** üstüne
  düşüyordu. Sonuç parmağın tahtadaki konumuna göre değişiyor — ikisi de
  kullanıcının tarifinde var: harf ızgarasındaki bir taşa denk gelirse joker
  sessizce başka bir harfe dönüyor, modalın zeminine denk gelirse pencere
  açıldığı anda kapanıyor ("tablo açılmadı").
  **ÖLÇÜLDÜ, tahmin edilmedi** (Chromium, `hasTouch`+`isMobile`, 390×844,
  jokerli bir kayıttan devam edilerek): olay zinciri `pointerdown → pointerup
  (hücre) → mousedown/mouseup/click (MODAL)`; tahtanın alt üç satırındaki
  hücreler harf ızgarasıyla örtüşüyor ve kullanıcının bildirdiği semptom
  birebir üretildi — (10,5)'te **A → C**, (11,5)'te A → Ğ, (12,7)'de A → H;
  üst satırlarda ise pencere zemine düşen click'le anında kapanıyordu.
  **Düzeltme yeni bir mekanizma DEĞİL, projenin kendi mekanizmasının doğru
  yere uygulanması:** iki ekranda da zaten bir sürükleme sonrası hayalet
  click'i yutan bir bayrak + belge düzeyinde capture dinleyicisi vardı;
  joker dalı da artık onu kuruyor. Mekanizma aynı gün **`src/utils/ghostClick.ts`**'e
  (`swallowNextClick()`) çıkarıldı — iki ekranın kopyaları tek kaynağa indi ve
  aynı sınıfın öteki iki örneği (aşağı bkz.) de oradan besleniyor. Bayrağın
  temizlenmesi `setTimeout(0)` yerine bir sonraki jestin `pointerdown`ına bağlandı —
  compat olayları AYNI jestin parçası ve kendileri pointerdown ÜRETMEZ
  (ölçüldü), yani temizleme olay sırasına bağlı; zamanlayıcı bu Chromium'da
  da işe yarıyor (ölçüldü) ama sıra hiçbir yerde garanti değil ve hatanın
  kendisi zaten tarayıcılar arası olay zamanlaması farkından doğuyor.
  Yutucu ayrıca `detail === 0` olan click'leri (klavyeyle tetiklenen
  Enter/Space) baştan dışarıda bırakıyor — onlar bir pointer jestinin
  parçası değil.
  **Yan fayda:** raftan SÜRÜKLENEREK konan bir joker de pencereyi aynı
  `pointerup` içinde açıyor; o dal da artık aynı korumayı taşıyor.
  **Flutter portu ETKİLENMEDİ ve `mobile/` altında hiçbir değişiklik
  gerekmedi** — orada dokunuş Flutter'ın kendi hit-test'inden geçiyor,
  compat click diye bir şey yok (`game_screen.dart` → `_tapPlacedTile`).
  **Regresyon:** `tests/smoke.spec.ts` 22 → **23 test** — dokunmatik bir
  bağlamda (`test.use({ hasTouch, isMobile })`; masaüstü profilinde hata
  GÖRÜNMEZ, `tap()` bile çalışmaz) joker konup üzerine dokunuluyor: pencere
  açık kalmalı, harf değişmemeli, ve ardından GERÇEK bir harf seçimi hâlâ
  çalışmalı. Test, hücrenin harf ızgarasıyla gerçekten örtüştüğünü ayrıca
  ölçüyor — düzen değişip örtüşme kaybolursa testi sessizce geçirmek yerine
  düşürüyor. **Negatif eş:** joker dalındaki tek satır kaldırılınca test
  GERÇEKTEN düşüyor.
- **Torba:** Oyuncu sayısından bağımsız olarak sabit 100 taş (Türkçe dağılım, `src/data/tiles.ts`). Not: bir ara tüm modlarda 186'ya çıkarılmıştı, ama simülasyon torbanın gerçek bitirişini (rafını torba boşken tamamen bitirme + rakip puanlarını kapma) neredeyse imkânsız kıldığını gösterdi (4 oyunculuda 0/10), bu yüzden 100'e geri dönüldü. Bölge artık statik 5×5 değil dinamik/genişleyen olduğundan (bkz. yukarı), 4 oyunculu oyunlarda köşe sınırıyla etkileşim için torbayı büyütmeye (eski `BAG_SCALE_BY_PLAYER_COUNT` denemesi) gerek kalmadı; kaldırıldı.
- **Teslim olma (kademeli):** Bir oyuncu teslim olduğunda (`Player.surrendered`, `SURRENDER` action, `src/game/gameReducer.ts`) oyun tümüyle bitmez — o oyuncu sırayı devretmeden çekilir, kalan oyuncular (YZ ve/veya diğer hotseat oyuncuları) oynamaya devam eder; sıra rotasyonu ve pas-turu sayacı yalnızca teslim olmamış oyuncuları sayar (`nextActiveIndex`/`activePlayerCount`). Teslim olan oyuncunun puanı dondurulmaz, **sıfırlanır** (`score: 0`) ve rafında kalan kullanılmamış taşlar torbaya geri karıştırılır (`shuffle`) — böylece o taşlar kalan oyuncular için tamamen kaybolmaz. Oyun yalnızca teslim sonrası aktif oyuncu sayısı 1'e düşünce biter: 2 kişilik oyunda tek teslim bunu anında tetikler; 4 kişilikte sırasıyla 3 → 2 → (üçüncü teslimde) 1 aktif oyuncuya iner ve o son kalan oyuncu kazanır — sıralama, teslim olanları puanlarından bağımsız olarak her zaman en sona koyan `rankPlayers` (`src/utils/ranking.ts`) ile hesaplanır ve hem `GameOver` hem `buildGameRecord`'un (`App.tsx`) skor kaydı bunu kullanır. **29 Temmuz 2026'da logo davranışı değişti — artık manuel/anlık bir teslim yolu yok:** Öncesinde logoya tıklamak bir "Çık" onay modalı açıyor, sırası gelen hâlâ oyundaki insan oyuncuyu (hotseat'te herkes kendi sırasında teslim olabilsin diye) ya da yoksa hesap sahibini (1. oyuncu) hedefleyip `SURRENDER` dispatch ediyordu — Canlı oyundaki 48 saatlik zaman aşımı modeli (bkz. "Canlı Oyun — Faz 3.6") YZ tarafına da uygulanınca (kullanıcı isteği) bu modal tamamen kaldırıldı: logo artık HER DURUMDA (onay sorulmadan, kimin sırası olduğuna bakılmadan) doğrudan Setup'a döner (`handleLogoClick`, `App.tsx`, bkz. aşağıdaki "Devam eden oyunun kalıcılığı"). Setup'taki Yapay Zeka sekmesinde çalışan mevcut kurulumda zaten yalnızca 1. oyuncu (hesap sahibi) insan olabildiğinden (diğerleri her zaman YZ), bu modalın hotseat dalı ("başka bir insan oyuncuyu teslim et, diğerleri devam etsin") pratikte hiç tetiklenmiyordu — kaybı yok. `SURRENDER` action'ının kendisi (`gameReducer.ts`) ve yukarıda anlatılan kademeli teslim mekaniği (puan sıfırlama, raf→torba, `rankPlayers` sıralaması) hâlâ duruyor, ama artık local oyunda hesap sahibi için bunu tetikleyen TEK yol aşağıdaki 7 günlük terk edilme kuralı (`takePendingAbandonedGame`, gecikmeli -2 ceza) — anlık bir "Çık" kararı artık mümkün değil. `games.players` jsonb'sindeki her satırda hâlâ `surrendered` alanı var; `GameHistoryModal` yalnızca teslim olan oyuncunun kendi satırında (genel/üst köşede değil) "Teslim Oldu" rozeti gösterir.
- **Teslim sonrası izleme (4 kişilik) — 29 Temmuz 2026'dan beri UI'dan tetiklenemiyor:** Bu bölüm, hesap sahibinin logo üzerinden anlık teslim olabildiği eski tasarımı anlatıyordu (`spectating = rackPlayer.surrendered && !state.isGameOver`, `App.tsx` — dolduğunda rafı/Oyna/Pas Geç/Değiştir/Karıştır/Geri Al butonları yerine "Teslim oldun — oyunu izliyorsun" bandı gösterilip `GameHeader`'ın `exitDisabled` prop'uyla çıkış da kilitleniyordu). Yukarıdaki değişiklikle (logo artık her zaman onaysız Setup'a dönüyor) hesap sahibi için `SURRENDER`'ı UI'dan tetikleyen tek yol kalktığından, bu `spectating` dalı artık pratikte hiç ulaşılamıyor — kod (JSX/`exitDisabled` dahil) bilinçli olarak silinmedi (reducer'ın `SURRENDER` yeteneği hâlâ geçerli bir kavram, ileride başka bir tetikleyici eklenebilir) ama şu an local akışta kimse bu bandı göremez. 2 kişilik oyunda zaten hiç yaşanmıyordu (tek teslim `activePlayerCount<=1`'i tetikleyip oyunu anında bitirdiğinden, `endGame`).
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

## Form Input'ları — iOS Safari Zoom Bug'ı (31 Temmuz 2026)

Kullanıcı, oyun sonrası çıkan "Görüş Bildir" formuna (`FeedbackModal`) dokununca sayfanın otomatik yakınlaştığını (zoom), formu kapattıktan sonra da bu yakınlaşmanın kendiliğinden geri açılmayıp elle (parmakla) küçültmek gerektiğini bildirdi. Kök sebep `FeedbackModal`'a özgü değildi: iOS Safari, odaklanılan bir `input`/`textarea`/`select`'in **hesaplanan font-size'ı 16px'in altındaysa** sayfayı otomatik yakınlaştırıyor — proje genelinde neredeyse tüm form alanları (`inputCls` ortak class'ı, `text-sm`=14px) hatta bazı yerlerde `text-xs`=12px (`AdminDashboard`'ın geri bildirim yanıt kutusu, `ChatModal`) kullanıyordu, yani bu yalnızca bu formda değil dokunulan HER formda (AuthModal, AccountSettingsModal, ChatModal, FriendsModal, ResetPasswordModal, MemberMessageModal, LiveGameCreateForm, AdminDashboard) yaşanan sistemik bir sorundu.

**İlk düzeltme yanlış gerekçeyle işe yaramadı (31 Temmuz 2026, aynı gün ikinci değişiklik — kullanıcı formların hâlâ büyüdüğünü bildirdi):** İlk sürüm `input, textarea, select { font-size: 16px; }` kuralını `@layer` DIŞINDA (unlayered) yazıp "Tailwind'in `@tailwind base/components/utilities` çıktısı CSS Cascade Layers'a göre katmansız kurallardan her zaman daha düşük öncelikli sayılır" gerekçesine dayanıyordu. Bu gerekçe **yanlıştı**: Tailwind v3.4 (`tailwindcss: ^3.4.17`, bu projenin sürümü) `@tailwind` direktiflerini derlerken hiç native CSS `@layer` bloğu ÜRETMİYOR — `npm run build` sonrası `dist/assets/index-*.css` içinde `@layer` araması sıfır sonuç veriyor (doğrulandı). Yani "unlayered katmanlıyı ezer" mekanizması hiç devreye girmiyordu; gerçek belirleyici düz CSS **specificity**'ydi: `.text-sm`/`.text-xs` gibi bir CLASS selector (specificity 0,1,0) `input` gibi bir ELEMENT selector'dan (0,0,1) specificity'de her zaman üstündür — kaynak sırasından bağımsız olarak kazanır. Sonuç: `class="... text-sm ..."` taşıyan (ki proje genelindeki `inputCls` ortak class'ı tam olarak bunu yapıyor) input'lar hâlâ 14px/12px'te kalıyor, iOS Safari hâlâ zoom yapıyordu — kullanıcının bildirdiği tam olarak buydu.

**Gerçek düzeltme:** Aynı kurala `!important` eklendi (`input, textarea, select { font-size: 16px !important; }`) — specificity yarışını tamamen devre dışı bırakıyor, class'tan bağımsız her zaman kazanıyor. Derlenmiş CSS'te (`input,textarea,select{font-size:16px!important}`) doğrulandı.

Bir sonraki form/modal eklendiğinde aynı deseni (küçük punto istense bile input/textarea/select elemanının kendisi hep ≥16px kalmalı) otomatik olarak miras alıyor — ayrı bir işlem gerekmiyor, kural elemente göre (class'tan bağımsız) uygulanıyor. **Ders:** Tailwind v3'te `@layer`/cascade-layer tabanlı bir öncelik varsayımı kurmadan önce derlenmiş CSS çıktısında gerçekten `@layer` üretilip üretilmediğini doğrula — sürüme göre değişebilir, varsayımla ilerlemek (ilk sürümde olduğu gibi) sessizce işe yaramayan bir düzeltmeye yol açabilir.

## Türkçe Dil Notu

Büyük/küçük harf dönüşümünde **mutlaka** `trUpper()` / `trLower()` (`src/utils/turkish.ts`) kullanılmalı. Native `toUpperCase()`/`toLowerCase()` i/İ ve ı/I harflerini yanlış dönüştürür.

Alfabetik sıralamada da aynı sebeple native `<`/`localeCompare()` (locale verilmeden) yerine **mutlaka** `trCompare()` (`src/utils/turkish.ts`, `localeCompare(..., 'tr')` sarmalayıcısı) kullanılmalı — aksi halde ş/ğ/ü/ö/ç/ı/İ gibi harfler yanlış sıralanır (`AdminDashboard.tsx`'teki Üyeler tablosunda zaten bu desen kullanılıyordu, `trCompare` bunu 1 Ağustos 2026'da paylaşılan bir yardımcıya çıkardı). **Arkadaş seçim listeleri** (`FriendsModal.tsx`'in Arkadaşlarım/Ara & Ekle sekmeleri, `LiveGameCreateForm.tsx`'in arkadaş seçici, `FriendSuggestModal.tsx`) bu tarihte fark edilen bir hatayla düzeltildi: `fetchFriends()` (`list_friends` RPC'si) isme göre değil `responded_at desc`'e (en son kabul edilen önce) göre dönüyordu, `searchUsersForFriend`/`listUsersForFriend` ise backend'in `order by name`'i veritabanının varsayılan (Türkçe'ye özel olmayan) collation'ına güveniyordu — üçü de artık `trCompare` ile client tarafında (yeniden) sıralanıyor; "Tüm Üyeler" sayfalı listesinde bu sıralama her yeni sayfa geldiğinde TÜM birikmiş listeye uygulanıyor (yalnızca son sayfaya değil), aksi halde backend collation'ının sayfa sınırlarında Türkçe harfleri yanlış gruplaması düzelmeden kalırdı. `list_incoming_friend_requests` (İstekler sekmesi) bilerek dokunulmadı — bir seçim listesi değil, `created_at desc` (en yeni istek önce) burada daha anlamlı.

## Supabase

Env değişkenleri olmadan uygulama offline çalışır — `useAuth` içindeki `configured` flag'i `false` olur ve tüm hesap/lider tablosu özellikleri gizlenir. Lokal geliştirmede Supabase gerekmez.

### Auth e-postaları — Brevo SMTP (Supabase'in varsayılan mailer'ı DEĞİL)

Supabase Auth (kayıt onayı, şifre sıfırlama vb.) e-postaları artık **Brevo** üzerinden özel SMTP ile gönderiliyor — Supabase'in kendi varsayılan/paylaşımlı mail servisi çoktan terk edildi. Bir kullanıcı "e-posta gelmedi/spam'e düştü" derse **ilk şüpheli Supabase'in default mailer'ı OLMASIN** — o zaten devre dışı. Bunun yerine Brevo tarafına bak: gönderen domain'in SPF/DKIM/DMARC kaydı hâlâ geçerli mi, Brevo hesabında gönderim/kota limiti mi devrede, Brevo'nun kendi gönderim loglarında o adrese ne olmuş (kabul/ret/bounce). SMTP kimlik bilgileri koda değil doğrudan Supabase Dashboard'a (Authentication → Emails → SMTP Settings) girildiği için repoda hiçbir iz bırakmaz — bu yüzden bu not burada duruyor, koddan çıkarılamaz.

**E-posta şablonları (branding):** Brevo yalnızca taşıyıcıdır (SMTP relay) — mailin HTML içeriği/markası Supabase Dashboard → Authentication → Emails → Templates'te tanımlanır, bu da SMTP kimlik bilgileri gibi repoda hiçbir iz bırakmaz. Kelimeki markalı şablonların kaynağı `supabase/email-templates/*.html`'de tutulur (confirm-signup, reset-password, change-email) — ama bunlar Supabase Auth tarafından otomatik okunmaz, her değişiklikte Dashboard'daki ilgili template'e elle yapıştırılması gerekir. 20 Temmuz 2026'da bu şablonlar hiç kaydedilmemiş/kaybolmuş olduğu ortaya çıktı — kullanıcı gerçek bir onay maili aldığında hâlâ Supabase'in stok İngilizce varsayılan metni ("Confirm your email address" / "Follow the link below...") geliyordu, hiçbir Kelimeki markası yoktu. Bir kullanıcı "mailde branding yok" derse önce Dashboard'daki template'in bu repo dosyalarıyla eşleşip eşleşmediğini kontrol et.

20 Temmuz 2026'da bu yüzden yaşanan bir teslimat sorunu şu şekilde çözüldü: Brevo'daki **Sender** hâlâ rebrand öncesinden kalma `Harfik <kişisel-hotmail-adresi>` idi — DKIM "Default" (domain'e özel değil) ve DMARC uyarılıydı, Brevo'nun kendi paneli de "senders not compliant with Google/Yahoo/Microsoft's new requirements" diyordu. Brevo → Settings → Senders, domains, IPs → **Domains** sekmesinden `kelimeki.com` domain olarak eklenip verilen DNS kayıtları domain'in DNS'ine girildi, sonra sender `Kelimeki <noreply@kelimeki.com>` olarak yeniden eklendi. **DÜZELTME (25 Ağustos 2026, GoDaddy panelinden 14 kaydın tamamı okundu):** bu cümle uzun süre "SPF/DKIM/DMARC girildi" diyordu; gerçekte girilen **DKIM (`brevo1/2._domainkey`) + DMARC (`p=none`) + `brevo-code` doğrulaması**, ve **SPF kaydı HİÇ YOK** — kök `kelimeki.com` üzerinde `v=spf1` ile başlayan bir TXT bulunmuyor. Teslimat yine de sağlam, çünkü DMARC SPF **veya** DKIM'den biri hizalanırsa geçer ve Brevo'nun DKIM'i `kelimeki.com` adına imzalıyor; Brevo'nun zarf adresi (Return-Path) kendi domaininde olduğundan kök SPF'e zaten bakılmıyor (`mail`/`r.mail`/`img.mail` CNAME'lerinin `brevosend.com`'a gitmesinin sebebi bu). **Bu yanlış cümlenin bedeli ölçüldü:** 25 Ağustos'ta `destek@kelimeki.com` kurulumu planlanırken üç tur boyunca "mevcut SPF kaydını birleştir, ikinci TXT açma" uyarısı yazıldı — birleştirilecek kayıt hiç yoktu. Domaine ilk SPF kaydı yazılırken Brevo da `include:spf.brevo.com` ile içine alınmalı. **KURULDU (25 Ağustos 2026):** domaine ilk SPF kaydı `v=spf1 include:zohomail.eu include:spf.brevo.com ~all` olarak yazıldı ve **Brevo regresyonu ölçüldü — SPF/DKIM/DMARC üçü de PASS**, zincir bozulmadı. Aynı gün `destek@kelimeki.com` gerçek bir posta kutusu olarak açıldı (Zoho Mail, AVRUPA veri merkezi) ve MX artık Zoho'ya bakıyor; `noreply@kelimeki.com` bir GRUP olarak aynı kutuya düşüyor, yani kullanıcıların "Yanıtla" cevapları artık kaybolmuyor. **Bundan sonra "mail gelmedi" teşhisinde İKİ sistem var:** giden = Brevo (Auth SMTP + Transactional API), gelen = Zoho. Ayrıntı, as-built kayıtlar ve test sonuçları: `marketing/play-store/console-formlari.md` → "destek@kelimeki.com — kurulum". Sonuç: DKIM signature "kelimeki.com" ✓, DMARC "configured" ✓, uyumluluk uyarısı yeşile döndü. Yani gönderen adı/adresi **"Kelimeki" / `noreply@kelimeki.com`** olmalı — bir daha "Harfik" görülürse (sender listesinde ya da gönderen adında) bu geriye gitmiş demektir, DNS kaydı silinmiş/domain doğrulaması bozulmuş olabilir, Brevo → Senders, domains, IPs'ten kontrol et.

### Geri bildirim yanıtları — Brevo Transactional API (SMTP'den AYRI, ilk Edge Function)

Yukarıdaki "Auth e-postaları — Brevo SMTP" bölümü yalnızca Supabase Auth'un kendi ürettiği mailleri (kayıt onayı, şifre sıfırlama) kapsar — bu akış Supabase Dashboard'da yapılandırılır ve uygulama kodundan keyfi bir mail göndermek için **kullanılamaz**. Görüş bildirimlere admin panelinden yanıt gönderebilmek için 26 Temmuz 2026'da ayrı bir mekanizma kuruldu: Brevo'nun **HTTP Transactional Email API**'si (`POST https://api.brevo.com/v3/smtp/email`), SMTP kimlik bilgilerinden tamamen farklı bir **API key** ile çağrılıyor.

- Bu API key, Supabase Dashboard → Edge Functions → **Secrets** altına `BREVO_API_KEY` adıyla **custom secret** olarak elle girildi (kullanıcı tarafından) — SMTP şifresi gibi bu da repoda/koda hiç yazılmaz, yalnızca bu not burada duruyor.
- Bu, projedeki **ilk Supabase Edge Function**: `supabase/functions/feedback-reply/` — admin panelinden çağrılır (`sendFeedbackReply`, `src/lib/api.ts`), çağıranın kendi JWT'siyle bir Supabase client oluşturur (RLS/`is_admin()` doğal olarak uygulanır, ayrı bir yetki kontrolü kod tekrarı gerekmez), gönderen adresi olarak zaten SPF/DKIM/DMARC doğrulanmış `noreply@kelimeki.com`'u (bkz. yukarıdaki sender kurulumu) kullanır, e-postayı gönderdikten sonra `feedback.reply`/`replied_at`/`replied_by`'ı günceller. Deploy `supabase functions deploy` CLI'ı ile DEĞİL, migration'larla aynı gerekçeyle (CI/CLI erişimi yok) Supabase MCP'nin `deploy_edge_function`'ı ile production'a doğrudan yapılıyor — yeni bir Edge Function eklenirse/değiştirilirse aynı yolu izle.
- Yalnızca `feedback.email` dolu olan satırlar yanıtlanabilir; `feedback_rate_limit` gibi bu da bir güvenlik ağı değil sadece pratik bir sınır — anonim/e-postasız gönderimlere mail atılamaz.
- **26 Temmuz 2026'nın ikinci değişikliği — "hafif çözüm" (gerçek `destek@` gelen kutusu bilinçli olarak ERTELENDİ):** Kullanıcıya gerçek iki yönlü mail yazışması (Brevo Inbound Parsing + yeni bir subdomain/MX kaydı + `feedback_messages` gibi çok mesajlı bir şema) kurmak yerine, şimdilik daha ucuz bir ara çözüm seçildi — iş büyüyünce gerçek `destek@` kutusuna geçilebilir, o zamana kadar bu not burada bir hatırlatma. İki parça eklendi:
  1. `supabase/functions/admin-send-message/` — admin panelinin Üyeler tablosundaki her satıra eklenen "Mesaj Gönder" linkinden (`MemberMessageModal.tsx`) tetiklenir; admin serbest bir Konu + Mesaj yazar, aynı Brevo API'siyle gönderilir. İki fonksiyon da ortak `supabase/functions/_shared/email.ts`'i kullanıyor (Brevo çağrısı, HTML escape, sender sabiti) — Supabase her fonksiyonu bağımsız bir paket olarak deploy ettiğinden, `deploy_edge_function` her iki fonksiyon için de `_shared/email.ts`'i kendi `files` listesine ayrıca eklemek zorunda (tek bir yerde deploy edip diğerinin otomatik görmesi mümkün değil).
  2. Hem `feedback-reply` hem `admin-send-message`'ın gönderdiği e-postaların altına artık farklı stilde (küçük, gri, italik) bir not ekleniyor: "Bu e-posta noreply adresinden gönderilmiştir. Cevap için tıklayın" — `tıklayın` `kelimeki.com/?contact=1`'e giden altı çizili bir link. Bu link bir mail istemcisinde form açtıramayacağından (mail'ler JS/form çalıştırmaz) en yakın pratik çözüm seçildi: `App.tsx`'teki bir `useEffect` sayfa yüklenince `?contact=1` parametresini okuyup genel "Görüş Bildir" formunu (`FeedbackModal`, `source="general"`) otomatik açıyor, sonra `history.replaceState` ile parametreyi URL'den temizliyor (yenilemede tekrar açılmasın diye). Kullanıcı gerçekten mail'e "Yanıtla" derse o cevap hâlâ `noreply@kelimeki.com`'a gider ve kimse görmez — bu link sadece "buraya tıkla, formu doldur" alternatifini sunuyor, gerçek bir iki yönlü yazışma değil.
     **`fromEmailLink` — bu yoldan gelene üyelik teklifi gösterilmiyor (4 Ağustos 2026):** `FeedbackModal` gönderim sonrası misafire "{e-posta} ile üyeliğine devam etmek ister misin?" teklifi çıkarıyor. Ama `?contact=1`'den gelen kişiye zaten BİZ mail atmışız — e-postası bizde kayıtlı ve büyük olasılıkla hesabı da var. En uç örneği hesabı DONDURULMUŞ bir kullanıcının itiraz etmesi: giriş yapamadığından girişsiz görünüyor, itirazını gönderiyor ve sonunda "üye olmak ister misin?" teklifi alıyordu — zaten üyesi. Uygulama bunu tek başına anlayamaz (ziyaretçi girişsiz, elde yalnızca bir e-posta metni var) ve "bu e-posta kayıtlı mı" diye sormak hesap-varlığı sızdıran bir enumeration açığı olurdu; bu yüzden çözüm sorgu değil BAĞLAM: yeni `fromEmailLink` prop'u yalnızca App.tsx'teki İKİ `?contact=1` çağrı yerinde geçiliyor, teklif orada gizleniyor. Uygulama içindeki diğer giriş noktaları (oyun sonu formu, Terms/Privacy) dokunulmadı — orada gerçekten misafir olan biri form doldurabilir, teklif hâlâ anlamlı.

**26 Temmuz 2026'nın üçüncü değişikliği — görünürlük + kısmi bağlama (`feedback_origin_subject_related_to` migration'ı):** Yukarıdaki ikinci değişiklikten hemen sonra iki gerçek eksik fark edildi: (1) `admin-send-message` DB'ye hiçbir şey yazmadığından, admin gönderdiği mesajı bir daha hiçbir yerde göremiyordu — "kime ne yazdım" sorusunun cevabı yoktu; (2) `?contact=1` linkinden gelen her yeni "Genel" geri bildirim (hem bir `feedback-reply` yanıtına hem bir `admin-send-message` mesajına gelen cevaplar dahil) birbirinden ve orijinal mesajdan ayırt edilemeyen, tamamen bağımsız yeni bir satır olarak giriyordu.
- `admin-send-message` artık Brevo'ya göndermeden ÖNCE `feedback`'e `{origin: 'admin', subject, message, user_id: <alıcı>, handled: true}` olarak bir satır YAZIYOR (`.select('id').single()` ile id'yi geri alıyor) — Brevo gönderimi başarısız olursa bu satır geri silinir (`delete().eq('id', inserted.id)`), böylece "gönderilmedi ama kayıtta duruyor" tutarsız bir durum oluşmaz. Kayıt e-postadan önce oluşturuluyor çünkü mailin içine (aşağıya bkz.) bu satırın id'si gömülüyor.
- `_shared/email.ts`'teki sabit `NOREPLY_NOTICE_HTML` bir fonksiyona (`buildNoreplyNoticeHtml(threadId?: string)`) çevrildi — `threadId` verilirse link `?contact=1&re=<threadId>` olur. `feedback-reply` kendi `feedbackId`'sini, `admin-send-message` da az önce oluşturduğu satırın id'sini buraya veriyor.
- `App.tsx`'teki `?contact=1` effect'i artık `re` parametresini de okuyup `contactRelatedTo` state'inde tutuyor ve `FeedbackModal`'ın yeni `relatedTo` prop'una geçiyor; `FeedbackModal` → `submitFeedbackDurable`/`feedbackSync.ts` → `submitFeedback` bunu `feedback.related_to`'ya yazıyor (kendine referans veren nullable FK, `on delete set null`).
- Admin panelinde (`AdminDashboard.tsx`) `origin: 'admin'` satırları "Gönderilen" rozetiyle ve `→ {alıcı}` başlığıyla (normal satırlardaki "kimden geldi" etiketinin tersi) ayrışır, "Yanıtla" gösterilmez. `related_to` dolu satırlar "↳ Cevaben" rozetiyle işaretlenir; genişletilince üstte hangi mesaja cevaben geldiği kısa bir alıntıyla (`feedback?.find(x => x.id === f.related_to)` — liste zaten sayfalamasız tamamen client'ta) gösterilir.
- `feedback_insert_any` RLS politikası gevşetildi: `user_id is null or auth.uid() = user_id or is_admin()` — önceki hâli yalnızca kendi adına (ya da anonim) insert'e izin veriyordu, admin artık "Mesaj Gönder" ile BAŞKA bir kullanıcı adına da satır ekleyebiliyor.
- **Hâlâ çözülmeyen kısım:** Bu, `related_to` yalnızca kişi GERÇEKTEN linke tıklayıp SİTEDEKİ formdan yazarsa çalışır. Kişi mail programında doğrudan "Yanıtla"ya basarsa o cevap yine `noreply@kelimeki.com`'a gider, hiçbir yere düşmez, hiçbir şeye bağlanmaz — gerçek bir e-posta thread'i hâlâ yok, bunun için hâlâ gerçek bir `destek@` gelen kutusu + Brevo Inbound Parsing gerekir (bkz. yukarıdaki "hafif çözüm" notu).

### Migration'lar — CI yok, elle uygulama

Kullanıcı iPad üzerinden çalışıyor; bunu tetikleyip sonucunu takip edecek bir CLI/CI erişimi yok. Bu yüzden **her yeni migration'ı Claude'un kendisi, Supabase MCP (`apply_migration`/`execute_sql`) ile doğrudan production'a uygulaması gerekiyor** — migration dosyasını repoya eklemek tek başına yeterli değil. Akış:

1. Migration dosyasını normal şekilde `supabase/migrations/` altına yaz.
2. SQL'i kullanıcıya açıkça göster (ne çalıştırılacağını gizleme).
3. Supabase MCP ile aynı SQL'i doğrudan production'a uygula, sonra `execute_sql` ile canlıda doğrula (view/fonksiyon tanımını tekrar oku).
4. Uyguladığını kullanıcıya açıkça söyle ("canlıya uyguladım, doğruladım" gibi) — sessizce dosya eklemekle yetinme.
5. **Her migration'da zorunlu:** `list_migrations` çağırıp `apply_migration`'ın döndürdüğü gerçek versiyon numarasını dosya adındaki zaman damgasıyla karşılaştır — session'ın dosyayı yazdığı an ile sunucuda uygulandığı an birkaç saniye/dakika farklı olabiliyor. Eşleşmiyorsa dosyayı `git mv` ile gerçek versiyona yeniden adlandır ve bunu da commit'e dahil et. Bunu "genelde iyi fikir" değil, adım 1-4 kadar zorunlu bir adım say — 23 Temmuz 2026'da tam bu yüzden ayrı bir PR (#141) açmak gerekti çünkü ilk PR bu kontrol yapılmadan merge edilmişti.

**4 Ağustos 2026 — `.github/workflows/supabase-migrations.yml` tamamen kaldırıldı:** (O tarihte repoda başka workflow kalmamıştı; 6 Ağustos 2026'da mobil port için `mobile-build.yml` eklendi — Flutter analiz/test + Android APK + imzasız iOS + web test ortamı derler, Supabase'e ya da web uygulamasına HİÇ dokunmaz, bkz. `mobile/CLAUDE.md`.) Bu dosya (main'e push'ta `supabase link` + `supabase db push` çalıştırıyordu) yukarıdaki elle-uygulama akışıyla baştan beri çelişiyordu — migration'lar MCP ile zaten uygulanmış geldiğinden `db push` her seferinde "değişiklik yok" diyordu, yani hiçbir güvenlik ağı sağlamıyor, yalnızca bir kalıntı olarak duruyordu. Kullanıcı bir GitHub Actions hata maili alınca incelendi: son başarılı çalışma 3 Ağustos 11:16'ydı, ondan sonraki iki çalışmanın ikisi de `supabase link` adımında `Unexpected error retrieving remote project status: {"message":"Unauthorized"}` ile düşmüştü — yani `SUPABASE_ACCESS_TOKEN` GitHub secret'ı 3 Ağustos'ta 11:16-13:29 arasında geçersizleşmişti. **Hiçbir migration etkilenmedi** (workflow `db push`'a hiç gelemeden ölüyordu, o günün migration'ları zaten MCP ile uygulanıp doğrulanmıştı) ama her migration içeren merge bir hata maili üretiyordu — gerçek bir sorunmuş izlenimi veren, gerçekte hiçbir şey ifade etmeyen bir gürültü. Token'ı yenilemek yerine workflow kaldırıldı: `SUPABASE_ACCESS_TOKEN`/`SUPABASE_DB_PASSWORD` secret'ları repoda BAŞKA HİÇBİR YERDE kullanılmıyordu (uygulamanın kendisi Vercel'deki `VITE_SUPABASE_*` değişkenlerini kullanır, bunlarla ilgisi yok) ve Claude'un MCP erişimi de bu secret'tan tamamen bağımsız. Secret'lar GitHub'da duruyor olabilir, zararsız — ileride gerçekten CI'a geçilirse token'ın yenilenmesi gerekeceğini unutma.
**İleride gerçekten CI'a dönülürse iki şeye dikkat:** (1) migration geçmişi — elle uygulama sürdükçe `supabase_migrations.schema_migrations` ile repo arasındaki eşleşme `db push`'un beklediği durumdan sapabilir (bkz. hemen aşağıdaki 15 Temmuz notu, aynı sebeple yaşanmış bir kopukluk); (2) Edge Function'lar da MCP'nin `deploy_edge_function`'ıyla deploy ediliyor — `supabase functions deploy` CLI'ına geçilirse `verify_jwt: false` olması gereken üç fonksiyonun (`notify-deadline-warnings`, `notify-friend-request-reminders`, `notify-turn-timeout-surrender`) bu ayarı `config.toml`'a taşınmalı, aksi halde cron/Postgres kaynaklı çağrılar 401 almaya başlar (bkz. "Edge Function deploy'ları" bölümü).

**10 Ağustos 2026 — üçüncü workflow: `.github/workflows/branch-cleanup.yml` (elle tetiklenen dal temizliği).** Repoda 209 uzak dal birikmişti (19'u Haziran, 142'si Temmuz, 48'i Ağustos) ve açık PR yoktu — yani neredeyse hepsi işini bitirmiş, yalnızca duruyorlardı. Temizliği Claude oturumundan yapmak MÜMKÜN DEĞİL: bu ortamın git kimliği yalnızca **push** yetkisine sahip, `git push origin --delete` GitHub'dan **403** alıyor (denendi ve doğrulandı — hiçbir dal silinmedi, işlem temiz bir no-op oldu) ve GitHub MCP araçlarında dal silen bir uç yok (`create_branch` var, delete yok). Bu yüzden iş GitHub'ın kendi tarafına, workflow'un `GITHUB_TOKEN`'ına taşındı. **Varsayılan DRY RUN**; `dry_run: false` ile gerçekten siler. Dokunmadığı dört küme: varsayılan dal, `keep` listesi (varsayılanı `main` + aktif mobil port dalı), branch protection'lı dallar ve **AÇIK bir PR'ın head'i olan dallar** (merge edilmemiş iş silinmesin). Özet olarak silinen her dalın sha'sını yazar — geri yükleme hem oradan (`git push origin <sha>:refs/heads/<ad>`) hem PR sayfasındaki "Restore branch" düğmesinden mümkün. **Asıl kalıcı çözüm bu dosya DEĞİL:** Settings → General → Pull Requests → **"Automatically delete head branches"** açılırsa merge edilen her PR'ın dalı kendiliğinden silinir; bu workflow o zaman yalnızca PR'sız/artık dallar için elde kalır. `git`'in "merge edilmiş" saydığı yalnızca 42 daldı — kalan 161'i squash merge edildiğinden ataları eşleşmiyor; yani **dal temizliğinde güvenilecek sinyal `git branch --merged` DEĞİL, PR durumudur** (`git cherry`/`rev-list` sayıları da aynı sebeple yanıltıcı: örnek bir dal 859 "eşleşmeyen" commit gösterirken işi aylar önce PR #157 ile merge edilmişti).

15 Temmuz 2026'da bu yüzden repo ile production'ın migration geçmişi (`supabase_migrations.schema_migrations`) birbirinden kopmuştu: geçmiş migration'lar CI yerine elle (muhtemelen `apply_migration` ile, kendi otomatik zaman damgasıyla) uygulanmış, dosya adlarındaki timestamp'lerle hiç eşleşmiyordu, `supabase db push` bu yüzden sürekli "Remote migration versions not found" hatasıyla fail ediyordu. Tüm dosyaların içeriği tek tek production'da doğrulanıp (`games.players` jsonb için eksik olan tek dosya da eklendi) kayıt tablosu repodaki 26 dosyayla birebir eşleşecek şekilde yeniden yazıldı. Yeni migration eklerken bu senkronu bozmamak için 1-4 adımlarını takip et.

**19 Temmuz 2026'da farklı türde bir kopukluk daha yaşandı** (büyüme grafiği/admin paneli genişletmesi sırasında): bir oturum yukarıdaki 1-4 akışını doğru takip edip migration'ları production'a uyguladı, ama o oturum bitmeden önce kod/dosya değişiklikleri **commit edilmeden** kaldı — üstelik bu değişiklikler, konuyla tamamen alakasız bir başlığa sahip (ilk commit'inden kalma, sonradan hiç güncellenmemiş) **açık bir PR'a** gömülüydü. Sonraki bir oturum, admin panelinde veri gözükmediğini görünce bunu "kod hiç yazılmamış/kaybolmuş" sandı ve migration'ları introspection'dan (`pg_get_functiondef` vb.) sıfırdan yeniden inşa etti — bu da neredeyse iki paralel/çakışan implementasyona (iki ayrı PR, farklı migration timestamp'leri) yol açıyordu; şans eseri açık PR fark edilip onun üstüne inşa edilerek toparlandı. Dersler:
1. "X özelliği bozuk/veri gözükmüyor" tarzı bir sorunla karşılaşınca, koda dalmadan önce **açık PR'lara ve branch'lere bak** (`list_pull_requests`) — production'da migration'lar zaten uygulanmış ama karşılık gelen kod hiç merge edilmemiş olabilir.
2. Çok commit'li bir PR'ın başlığı yalnızca ilk commit'i yansıtabilir; gövdesine/commit listesine bakmadan başlığı "alakasız" diye atlama.
3. Bir migration dosyası yazılıp `apply_migration` ile uygulandıktan sonra dosya adı **mutlaka** `list_migrations`'ın döndürdüğü gerçek versiyon numarasıyla eşleştirilmeli — session'ın dosyayı yazdığı an ile `apply_migration`'ın sunucuda çalıştığı an birkaç saniye/dakika farklı olabiliyor, aksi halde 15 Temmuz'daki sorun tekrarlanır.

### Edge Function deploy'ları — `deploy_edge_function` MCP aracının iki tuzağı (2 Ağustos 2026, kod incelemesi sırasında bulundu/çözüldü)

Aylardır CLAUDE.md'nin çeşitli yerlerinde ayrı ayrı "kesin sebebi netleştirilmedi" notuyla kayıtlı duran `_shared/email.ts` import yolu tutarsızlığı (bazı fonksiyonlar `'../_shared/email.ts'`, bazıları `'./_shared/email.ts'`) bu incelemede kök sebebiyle birlikte çözüldü — ayrıca bu sırada **ikinci, daha tehlikeli bir tuzak** da bulundu. İkisi de `deploy_edge_function` MCP aracının kendi davranışıyla ilgili, kodun kendisiyle değil.

1. **Import yolu — kök sebep artık netleşti:** Araç, verdiğin `entrypoint_path`i olduğu gibi kullanmıyor, tüm dosyaları örtük bir `source/` klasörünün altına yerleştiriyor. Doğru/kararlı tarif: `entrypoint_path: "source/index.ts"` VER, entrypoint dosyasının adını da `"source/index.ts"` YAP (böylece gerçekte `source/source/index.ts`e iner) ve kardeş bağımlılık dosyalarını (`_shared/email.ts` gibi) **hiçbir `source/` öneki OLMADAN** adlandır (böylece `source/_shared/email.ts`e iner) — bu durumda `source/source/index.ts`'ten `source/_shared/email.ts`'e giden doğru göreli yol her zaman `'../_shared/email.ts'`dir. `'./_shared/email.ts'` kullanan 6 fonksiyonun (`notify-account-banned`, `notify-account-unbanned`, `notify-deadline-warnings`, `notify-friend-request-reminders`, `notify-local-game-abandoned`, `notify-turn-timeout-surrender`) bugüne kadar hiç patlamadan çalışmasının sebebi, o fonksiyonların ilk deploy'unda bu tarifin (muhtemelen) tutarlı uygulanmamış olması, yani dosyaların gerçekte BEKLENENDEN farklı bir iç içe klasör yapısına yerleşmiş olmasıydı — CLAUDE.md'de "CI/CLI deploy'a geçilirse 6 fonksiyon anında bozulur" diye zaten öngörülmüştü, bu doğru bir öngörüydü. **Düzeltme:** 6 fonksiyonun hepsi `'../_shared/email.ts'`e çevrilip yukarıdaki tarifle yeniden deploy edildi — artık 11 Edge Function'ın tamamı aynı, tek doğru importu kullanıyor.
2. **`verify_jwt` — aracın kendi varsayılanı `true`, parametre REQUIRED değilse bile geçilmezse önceki deploy'un değerini KORUMUYOR:** Bu araçla (CLI/`supabase functions deploy` değil) yapılan bir redeploy'da `verify_jwt` parametresi verilmezse, önceden `false` olan bir fonksiyon SESSİZCE `true`'ya döner — kod hiç değişmese bile. Bu, `notify-deadline-warnings`i (cron tarafından JWT'siz çağrılıyor, `verify_jwt:false` olması ŞART) bu incelemenin bir yan etkisi olarak neredeyse kırıyordu: fonksiyonun kodunu (CRON_SECRET kontrolü, satır başına try/catch) güncelleyip `verify_jwt` belirtmeden deploy edince araç onu `true`'ya çevirdi, `list_edge_functions`'la fark edilip aynı anda ikinci bir deploy'la (bu kez `verify_jwt: false` açıkça verilerek) geri alındı — production'a hiç sızmadı ama neredeyse pg_cron'un 15 dakikada bir 401 almaya başlamasına yol açıyordu. **Kural: `deploy_edge_function`'ı çağırmadan ÖNCE her zaman `list_edge_functions`/`get_edge_function` ile fonksiyonun MEVCUT `verify_jwt` değerini kontrol et ve deploy çağrısına AYNI değeri açıkça geçir — asla parametreyi atlayıp aracın varsayılanına (`true`) güvenme.** Projedeki `verify_jwt:false` olması gereken üç fonksiyon: `notify-deadline-warnings`, `notify-friend-request-reminders` (ikisi de pg_cron'dan JWT'siz çağrılıyor), `notify-turn-timeout-surrender` (Postgres'in kendisinden `net.http_post` ile JWT'siz çağrılıyor) — geri kalan sekizi `true`.

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
