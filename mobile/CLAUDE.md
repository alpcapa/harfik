# Kelimeki Mobil (Flutter) Portu — Claude Code Rehberi

Bu dosya, web uygulamasının (kök `CLAUDE.md`) Flutter/iOS+Android portuna ait
TÜM kararların ve yapının kaydıdır — kök `CLAUDE.md` ile aynı refleks:
**anlamlı her değişiklikte bu dosya da aynı PR'da güncellenir.** Web tarafına
dokunan bir port değişikliği olduğunda (ör. `src/utils/random.ts`'teki test
kancası gibi) kök `CLAUDE.md` de kontrol edilir.

## Üst Düzey Kararlar (5 Ağustos 2026, kullanıcıyla birlikte verildi)

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
    pubspec.yaml             # kelimeki_core (path) + supabase_flutter
    assets/dictionary/words_tr.txt
                             # ÜRETİLMİŞ (elle düzenlenmez) — kaynak
                             # src/data/words.ts; `npm run generate-golden-vectors`
                             # yeniden üretir. SIRA words.ts'teki WORD_LIST
                             # sırasıdır ve DEĞİŞMEZ SÖZLEŞMEDİR (aşağı bkz.).
                             # Uygulama paketinin İÇİNDE, çünkü Flutter paket
                             # kökü dışından asset kabul etmez — kelimeki_core
                             # testleri de TEK kopya kalsın diye buradan okur.
    lib/main.dart            # portre kilidi + bootstrap + runApp
    lib/src/
      bootstrap.dart         # AppServices: sözlük Future'ı + supabase + sürüm kapısı
      config/env.dart        # --dart-define SUPABASE_URL/ANON_KEY; appVersion sabiti
      config/version_gate.dart # app_config.mobile_min_supported_version kontrolü (fail-open)
      data/dictionary_loader.dart # rootBundle + Isolate.run → SetWordSource
      data/supabase_client.dart   # anahtar yoksa null → tam offline mod (web'deki configured)
      data/online_api.dart   # submit_move sarmalayıcısı: p_move_id UUID + retry
      game/game_controller.dart # ChangeNotifier motor kabuğu + otomatik YZ turu
      ui/                    # app.dart, home_screen.dart (İSKELET), update_required_screen.dart
      util/semver.dart, util/uuid.dart
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
      rng.dart               # Rng arayüzü, SystemRng, Mulberry32, shuffleList
    test/
      run_all.dart           # TÜM testler: `dart run test/run_all.dart`
      support/               # mini test çatısı, action decoder, json diff
      goldens/*.json         # ÜRETİLMİŞ fixture'lar (elle düzenlenmez)
```

Henüz OLMAYANLAR (sıradaki fazlar): depolama katmanı (SQLite/karantina),
gerçek oyun UI'ı, Canlı oyun ekranları, `meanings.json` gömme (karar 4 —
iskelette bilerek yok, MeaningModal'ın UI fazında eklenecek).

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
    `screenOrientation="portrait"`, ve kelimeki.com için `autoVerify`'lı App
    Links intent-filter'ı. **assetlinks.json henüz YOK** — imzalama anahtarı
    oluşturulduğunda sitenin `/.well-known/assetlinks.json` yayınlaması
    gerekiyor (web tarafına dokunan iş; o güne dek filtre zararsız).
    iOS Universal Links (associated domains entitlement + AASA dosyası)
    tamamen Apple hesabı gerektirdiğinden hiç başlanmadı.
  - `Info.plist`: iPhone VE iPad portre-kilidi, `CFBundleDisplayName`
    "Kelimeki". Portre kilidi ayrıca runtime'da `SystemChrome` ile —
    web'deki `LandscapeHint` banner'ının yerine geçen kesin çözüm.
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

## Sıradaki Fazlar (mutabık kalınan sıra)

1. ~~Backend güvenilirlik migration'ları~~ — TAMAMLANDI (5 Ağustos 2026,
   bkz. "Backend Hazırlığı" bölümü).
2. ~~`mobile/app/` Flutter iskeleti~~ — TAMAMLANDI (5 Ağustos 2026, bkz.
   "Flutter Uygulama İskeleti" bölümü; açık kalanlar: assetlinks.json,
   iOS Universal Links, gerçek cihaz doğrulaması).
3. **Depolama katmanı** — SQLite (kayıt/kuyruklar) + SharedPreferences
   (bayraklar); versiyonlu şema, karantina (asla silme), atomik yazım.
   localStorage anahtar eşlemesi ana sohbette kararlaştırıldı (PORT_BRIEF +
   konuşma kaydı); uygulanırken buraya tablo olarak geçirilecek.
4. **UI portu** — 51 React bileşeninin Flutter'da yeniden yazımı (çeviri
   değil); admin paneli/PWA/LandscapeHint/csvExport bilinçli olarak YOK.
5. **Çok kullanıcılı eşzamanlılık testi** — iki gerçek oturumlu headless
   harness (web tarafında hiç yapılamamış e2e; PORT_BRIEF'te "unproven"
   olarak işaretli); `p_move_id` retry davranışı da bu harness'te gerçek
   HTTP/PostgREST katmanıyla ayrıca doğrulanmalı (şimdilik yalnızca SQL
   seviyesinde doğrulandı).
