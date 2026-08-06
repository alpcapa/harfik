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
   **6 Ağustos 2026'da BİÇİM netleşti — JSON değil SQLite (kullanıcı onayı):**
   web JSON'u fetch edip TAMAMINI RAM'de tutuyor; mobilde bu 6.5 MB'lık bir
   parse gecikmesi + onlarca MB kalıcı bellek demekti. Asset build-time'da
   tek tablolu bir SQLite'a çevriliyor (`npm run generate-meanings-db` →
   `mobile/app/assets/dictionary/meanings.db`, 63.890 kelime, **5.26 MB ham
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
      storage/               # SQLite + prefs katmanı (bkz. "Depolama Katmanı"):
                             # app_database (şema), app_storage (giriş kapısı),
                             # local_save_store (karantinalı kayıt), pending_queue_store,
                             # pending_event_store, chat_read_store, flags_store
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

**Henüz BAĞLANMAYAN uçlar (sonraki fazların işi):** `LocalSaveStore`'u
gerçek kaydet/yükle akışına bağlayan UI (Setup/oyun ekranı), terk olayını
-2 cezasına çeviren üst katman (web `takePendingAbandonedGame` +
`buildGameRecord` eşleniği), kuyrukları sunucuya boşaltan flush (web
`flushPendingGames`/`feedbackSync`) — flush, Supabase'e yazarken
`TableWriteQueue`dan geçmek ZORUNDA (bkz. "Porta Taşınan Değişmezler").

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

- **Raf başlığındaki swap aksiyon metni** — `src/components/Rack.tsx`
  swap modunda başlığı `` `${title} — değiştirilecek taşları seç` ``
  yapıyor; aynı talimat zaten tahtanın altındaki mesaj satırında var.
  Uygulamada kaldırıldı (kullanıcı isteği), web'de duruyor ve bir sorun
  üretmiyor.
- **Anlam metnindeki `►`** — uygulama bunu `→` ile değiştiriyor (bkz.
  Parça 9). Web'de aynı karakter duruyor ve DÜZGÜN çiziliyor: tarayıcılar
  karakter bazında sistem yedeğine düşer (Chromium'da ekran görüntüsüyle
  doğrulandı). ÖLÇÜLDÜ: web'in subset woff2'lerinde (225-333 glyph) ne `►`
  ne `→` var — yani web'de ikisi de yedek fonttan basılır, `→`ye geçmek
  tipografik bir kazanç SAĞLAMAZ, yalnızca iki platformun metnini aynı
  yapardı. Flutter'da ise fark gerçek (tam TTF'lerde `→` var, `►` yok).

Eski (silinmiş) başlık: "Web'de Bekleyen Küçük Düzeltmeler" — o hâliyle
liste bir iş kuyruğu gibi okunuyordu; kullanıcı kararıyla anlamı değişti.

- **Raf başlığındaki swap aksiyon metni** — `src/components/Rack.tsx`
  swap modunda başlığı `` `${title} — değiştirilecek taşları seç` ``
  yapıyor; aynı talimat zaten tahtanın altındaki mesaj satırında var.
  Uygulamada kaldırıldı (bkz. aşağıdaki parça günlüğü), web'de duruyor.
- **Anlam metnindeki `►` (opsiyonel, web BOZUK DEĞİL)** — uygulama bunu
  `→` ile değiştiriyor (bkz. Parça 9). Web'de aynı karakter duruyor ve
  DÜZGÜN çiziliyor: tarayıcılar karakter bazında sistem yedeğine düşer
  (Chromium'da ekran görüntüsüyle doğrulandı). ÖLÇÜLDÜ: web'in subset
  woff2'lerinde (225-333 glyph) ne `►` ne `→` var — yani web'de ikisi de
  yedek fonttan basılır, `→`ye geçmek tipografik bir kazanç SAĞLAMAZ,
  yalnızca iki platformun metnini aynı yapar. Tek satırlık değişiklik
  (`MeaningModal.tsx`), aciliyeti yok.

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
     (native share ayrı parça), MembershipPerksBox/girişli dallar (auth
     fazı).
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
     turuncuya dönüyor, sağdaki "N seçili" duruyor). **Web'de aynı satır
     kaldırılana kadar bu bilinçli bir sapmadır** — parite tablosuna
     bakarken "port eksik" sanılmasın.
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
   - Sıradaki parça: kurallar ("Nasıl oynanır?") ekranı.
5. **Çok kullanıcılı eşzamanlılık testi** — iki gerçek oturumlu headless
   harness (web tarafında hiç yapılamamış e2e; PORT_BRIEF'te "unproven"
   olarak işaretli); `p_move_id` retry davranışı da bu harness'te gerçek
   HTTP/PostgREST katmanıyla ayrıca doğrulanmalı (şimdilik yalnızca SQL
   seviyesinde doğrulandı).
