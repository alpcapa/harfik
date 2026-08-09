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
```

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
    pubspec.yaml             # kelimeki_core (path) + supabase_flutter +
                             # sqflite/shared_preferences + share_plus/
                             # path_provider (paylaşım, 5c) + app_links
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
      ui/                    # app.dart, update_required_screen.dart, ve:
      ui/auth/               # giriş-kayıt-şifremi-unuttum modalı, hesap
                             # butonu, avatar, Terms/Privacy,
                             # reset_password_modal (recovery kapısı)
      ui/game/               # tahta/raf/header/modaller (oyun ekranının
                             # tamamı) + PAYLAŞILAN küçük parçalar:
                             # modal_shell, neo_box/neo_button, player_badge,
                             # player_avatar_row, action_sheet, count_badge
      ui/score/              # skor kartı, k-lig, oyuncu kartı, oyun geçmişi,
                             # score_box_row (paylaşılan görselin üst şeridi)
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
                             # paylaşılan onay/sonuç diyalogları)
      ui/live/               # Canlı oyun: live_games_tab (3 alt sekme +
                             # kartlar), live_game_create_form,
                             # friend_suggest_modal (kabul sonrası öneri),
                             # online_game_screen (TAHTA — game_screen.dart
                             # ile sürükleme/joker/mesaj desenini PAYLAŞIR,
                             # biri değişirse öteki de güncellenmeli)
      util/semver.dart, util/uuid.dart, util/share_board.dart,
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

## Web Derlemesi — ÜRÜN DEĞİL, TEST ORTAMI (7 Ağustos 2026)

Flutter'ın web hedefi bu porta üçüncü bir platform olarak EKLENMEDİ; ürün
hedefi hâlâ yalnızca iOS + Android. Web derlemesi tek bir sorunu çözüyor:
**geliştiricinin çalıştırabileceği hiçbir cihazı yok.** iPad'den çalışıyor,
Mac yok, Android telefon yok, Apple Developer üyeliği askıda (TestFlight
yok), tarayıcı emülatörü (Appetize) ücretsiz katmanda 3 dakikayla sınırlı.
Aynı Dart kodu aynı çizim motoruyla (CanvasKit) koştuğundan yerleşim/font/
gölge/oyun akışı doğrulaması burada ücretsiz ve süresiz yapılabiliyor.

Adres `https://alpcapa.github.io/kelimeki/`, her mobil push'ta
`.github/workflows/mobile-build.yml`'in `web` işi GitHub Pages'e deploy
ediyor. NE KANITLAR / NE KANITLAMAZ ayrımı `mobile/TESTING.md`'de ("Web
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
       taraması temiz. **Doğrulama sınırı:** iki gerçek oturumlu tarayıcı
       arasında Realtime mesaj/mute/rapor akışı bu ortamdan test
       EDİLEMEDİ — cihazda iki hesapla doğrulanmalı, TESTING.md'ye ayrı
       bölüm eklendi.
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
6. **Çok kullanıcılı eşzamanlılık testi** — iki gerçek oturumlu headless
   harness (web tarafında hiç yapılamamış e2e; PORT_BRIEF'te "unproven"
   olarak işaretli); `p_move_id` retry davranışı da bu harness'te gerçek
   HTTP/PostgREST katmanıyla ayrıca doğrulanmalı (şimdilik yalnızca SQL
   seviyesinde doğrulandı).
