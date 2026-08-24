# Backend Hazırlığı — Karar Kaydı

> mobile/docs/'e taşındı (context split, 24 Ağustos 2026). Kaynak: mobile/CLAUDE.md 'Backend Hazırlığı' bölümü.

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

---

## Depolama/İskelet/İkon/MembershipPerksBox — Karar Kaydı

> Yukarıdaki dosyanın devamı, aynı context split. Kaynak: 'Depolama Katmanı', 'Flutter Uygulama İskeleti', 'Uygulama İkonu / Splash', 'MembershipPerksBox' bölümleri.

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
  olarak alınmadı). **22 Ağustos 2026'dan beri TESTLİ** —
  `test/app_version_parity_test.dart` `pubspec.yaml`'ı okuyup `appVersion`
  ile karşılaştırıyor; o güne kadar bu kural yalnızca YAZILIYDI, hiçbir şey
  zorlamıyordu ve biri artırılıp öteki unutulsa `dart analyze` de testler de
  yeşil kalırdı. Ayrışmanın bedeli iki yönlü: mağazadaki `versionName` ile
  kullanıcının GÖRDÜĞÜ sürüm ayrışır, ve eşik yükseltildiğinde kapı YANLIŞ
  sürümü karşılaştırıp yeterli bir binary'yi "güncelleme zorunlu" ekranında
  kilitleyebilir. `+N` (build number) karşılaştırma DIŞINDA — CI onu
  `--build-number` ile eziyor, pubspec'teki değer bağlayıcı değil.
  **Sürüm 22 Ağustos 2026'da `0.1.0` → `1.0.0`** (ilk Play yüklemesi,
  ROADMAP FAZ B → 0.A3); canlıdaki eşik o an ölçüldü, iki platformda da
  `0.0.0`, yani kapı etkilenmedi.
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

