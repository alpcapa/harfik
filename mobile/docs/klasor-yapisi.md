# Mobil Portun Klasör Yapısı — açıklamalı ağaç

**4 Eylül 2026'da `mobile/CLAUDE.md`'den BURAYA taşındı.** Gerekçe doküman
boyutu bütçesi (kök `CLAUDE.md` → "Doküman Boyutu Bütçesi"): o dosya `auto`
sınıfında, yani HER TURDA bağlama yükleniyor ve 80 KB'lık uyarı bandına
girmişti. Bu ağaç tek başına **24,5 KB** — dosyanın %30'u — ve içeriğinin
büyük kısmı dosya başına tarihli "neden böyle" notu, yani her turda değil
**o dosyaya dokunurken** gereken bilgi. Kesme noktası yine boyut değil
içeriğin türü: `mobile/CLAUDE.md`'de her yerde geçerli KURAL kalır, burada
dosya başına AYRINTI yaşar.

⚠ **Ağacın hiçbir satırı değiştirilmeden taşındı** — atıflar kırılmasın
diye (repodaki önceki bölmelerin kuralı).

**Nasıl okunur:** baştan sona DEĞİL, `grep` ile. Bir dosyanın nerede
durduğunu ya da yanındaki uyarıyı ararken:
`grep -n "push_repo" mobile/docs/klasor-yapisi.md`

**Nasıl güncellenir:** port işine yeni bir dosya/klasör girdiğinde bu ağaca
da bir satır ekle — `mobile/CLAUDE.md`'nin "Parça Bitirme Kontrol Listesi"
2. maddesi bunu buraya yönlendiriyor. Özet ağaç (klasör düzeyinde) orada
duruyor; bir KLASÖR eklenirse ikisi de güncellenir.

---

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
      data/game_record.dart  # buildGameRecord portu (`games` satırı) — `ai_level`
                             # YALNIZCA doluysa yazılır (Normal = alan yok; fikstür
                             # `web_game_record.json` bayt-bayt buna dayanır)
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
      data/push_repo.dart    # push token yaşam döngüsü (kayıt/yenileme/
                             # temizlik) — İKİ dikiş: PushMessaging (FCM) ve
                             # PushTokenStore (push_tokens tablosu). DEĞİŞMEZ:
                             # tabloda satır varsa o cihaz bildirim GÖSTEREBİLİR.
                             # ⚠ Onarımı TETİKLEYEN yer app.dart'taki _HomeGate:
                             # açılış + `resumed` + oturum değişimi. Burada
                             # 28 Ağustos 2026'ya kadar "her açılışta kendini
                             # onarır" yazıyordu ve YANLIŞTI — çağrı yalnızca
                             # Canlı sekmesinin _reload()'undaydı (Parça 159)
      data/push_gateways.dart # yukarıdaki iki dikişin GERÇEK uçları
                             # (firebase_messaging ↔ Supabase upsert) +
                             # izinDurumu(AuthorizationStatus) eşlemesi +
                             # FirebasePushTapSource (bildirime dokunma —
                             # onMessageOpenedApp + getInitialMessage)
      # ⚠ Linkleri YALNIZCA app_links yakalar; Flutter'ın kendi rota yolu
      #   KAPALI (manifest + onUnknownRoute — 11 cihazda çöküyordu, ROADMAP
      #   Faz 7). İkinci bir yönlendirme kaynağı EKLEME.
      data/notification_shade.dart # panelde DURAN bildirimleri temizler
                             # (ROADMAP #15) — MethodChannel
                             # `kelimeki/bildirimler`, Kotlin ucu
                             # MainActivity'de. ⚠ Kanal/metot adı iki dilde
                             # ELLE yazılı: uyuşmazlık SESSİZ arıza (Dart
                             # MissingPluginException'ı yutuyor) →
                             # notification_shade_parity_test bunu zorluyor.
                             # iOS BİLEREK yok: rozet orada aps.badge'den
                             # gelir, sunucu onu hiç göndermiyor.
      data/push_taps.dart    # bildirime DOKUNMA dikişi (Faz 3):
                             # PushTapSource arayüzü + pushMessageLink
                             # (data.link → Uri, saf). PushMessaging'e
                             # BİLEREK eklenmedi — o dikiş token yaşam
                             # döngüsünün sözleşmesi, sahteleri kırardı
      data/game_link_inbox.dart # kelimeki://oyun/<id> gelen kutusu —
                             # FriendInviteInbox'un kardeşi ama KALICI
                             # DEĞİL (bildirime dokunmak anlık niyet;
                             # bayat tahta açılmaz). İki kaynak: app_links
                             # akışı + push dokunuşları. Tüketen _HomeGate
      data/analytics.dart    # GA4 olay kanalı — errorReporter deseni
                             # (global tek örnek, fire-and-forget,
                             # yapılandırılmamışken no-op). Olay adları
                             # SÖZLEŞME, dosya başlığında liste
      data/analytics_gateway.dart # gerçek uç (FirebaseAnalytics.logEvent)
      data/store_update.dart # Play In-App Update — "açılışta yeni sürüm
                             # varsa uyar ve yaptır". Sunucuda sürüm satırı
                             # TUTMAZ (Play'in kendisi bilir). YALNIZCA
                             # Android VE yalnızca Play'den kurulmuş pakette
                             # çalışır — yan yüklenmiş .apk'da sessizce
                             # `bilinmiyor` döner (bkz. "Güncelleme" bölümü)
      data/push_init.dart    # Firebase.initializeApp sarmalayıcısı — web ve
                             # Android/iOS DIŞI platformlarda `false` döner
                             # (GitHub Pages web derlemesi açılışta ölmesin)
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
                             # Parça 134), text_scale.dart (sistem yazı
                             # boyutu: kMaxTextScale tavanı + buyukOlcek
                             # eşiği — bkz. "Sistem Yazı Boyutu"),
                             # loading_note.dart (ortak
                             # "Yükleniyor…" göstergesi; web
                             # LoadingNote.tsx ile birebir),
                             # devam_eden_govde.dart ("devam eden oyun"
                             # kartının ORTAK gövdesi + tipografisi —
                             # Setup'ın YZ kartı ile Canlı oyun kartı
                             # buradan beslenir; 2 Eylül 2026'da düzen
                             # private kaldığı için iki kart AYRIŞMIŞTI),
                             # ve:
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
                             # tamamı) + board_zoom.dart (çift dokunuşla 2×
                             # zoom + pan; algılayıcı `clock.now()` kullanır
                             # — DateTime.now() sahte saatte ilerlemez,
                             # bkz. Parça 175) + PAYLAŞILAN küçük parçalar:
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
      ui/push/               # push_permission_flow — İKİ ayrı iş, karıştırma:
                             # (a) pushTokenlariHizala — token'ı sistem izniyle
                             #     hizalar, SORMAZ. Çağıranı _HomeGate (açılış +
                             #     `resumed` + oturum değişimi) ve Canlı sekmesi.
                             # (b) pushIzniAkisi — KENDİ onay penceremiz; sistem
                             #     diyaloğu ancak kullanıcı "Aç" derse açılır.
                             #     Tetikleyici "Canlı sekmesi açıldı VE aktif
                             #     oyun/davet var" (AndroidManifest'teki not +
                             #     Parça 158). Hizalama buna BAĞLI DEĞİL — (a) ve
                             #     (b) 28 Ağustos'a kadar aynı yola bağlıydı ve
                             #     hata tam oradan çıktı (Parça 159)
      ui/online_games_scope.dart # OnlineGamesScope — Canlı oyun DEPOSUNUN ağaç
                             # genelinde erişilebilir hâli (InheritedWidget,
                             # kökte bir kez). Tüketicisi bugün oyun
                             # geçmişindeki "Tekrar Oyna" (rövanş): depo o
                             # modala kadar hiç taşınmıyordu ve elden geçirmek
                             # İKİ zinciri birden değiştirmeyi gerektiriyordu
                             # (setup→RecentGamesSection, account_button→
                             # ScoreCardModal). Aynı gerekçe online_scope.dart'ta
                             # yazılı; ayrıca showGameHistory'nin beş çağrı
                             # yerinden birinin auth geçmemesi yüzünden kafa
                             # kafaya çubuğu bir kez sessizce kaybolmuştu
                             # (Parça 185)
      ui/online_scope.dart   # OnlineScope — bağlantı durumunun AĞAÇ GENELİNDE
                             # erişilebilir hâli (InheritedNotifier, kökte bir
                             # kez kurulur). Tüketicisi bugün KAvatar: çevrimiçine
                             # dönünce yüklenememiş görseli yeniden dener.
                             # ⚠ Parametre geçirmek yerine kapsam seçildi çünkü
                             # KAvatar'ın 19 çağrı yeri var — yeni bir çağrı
                             # yerinde unutmak hatayı sessizce geri getirirdi
      ui/route_observer.dart # kRouteObserver — RouteAware `didPopNext`.
                             # Web'in "route değişince remount" davranışının
                             # port karşılığı; SetupScreen oyundan DÖNÜŞTE
                             # rozetini bununla tazeliyor (Parça 153)
      ui/friends/            # friends_modal (3 sekme + davet paylaşımı +
                             # paylaşılan onay/sonuç diyalogları) +
                             # friend_moderation_sheet (satırdaki 🚫/🚩
                             # ikonundan açılan GERİ ALMA paneli) +
                             # relation_icons.dart — ilişki ikonlarının
                             # dördünden ÜÇÜ gerçek Material glyph'i
                             # (Icons.* ile çizilir, senkron sorunu yok);
                             # bu dosyada YALNIZCA "bekliyor" var: kişi +
                             # küçük kum saati, Material'da karşılığı
                             # olmadığından ELLE çizildi. Web
                             # RelationIcons.tsx ile elle senkron ama
                             # senkronu ZORLAYAN bir test var
                             # (relation_icon_parity_test.dart)
      ui/live/               # Canlı oyun: live_games_tab (3 alt sekme +
                             # kartlar), live_game_create_form,
                             # friend_suggest_modal (kabul sonrası öneri),
                             # online_game_screen (TAHTA — game_screen.dart
                             # ile sürükleme/joker/mesaj desenini PAYLAŞIR,
                             # biri değişirse öteki de güncellenmeli),
                             # open_online_game (tahtayı açan TEK kapı —
                             # listeden dokunuş da bildirim yönlendirmesi
                             # de bunu çağırır; 14 parametrelik kurulum
                             # İKİNCİ kez yazılmasın diye Faz 3'te çıkarıldı)
      util/deep_link.dart    # gelen URI'lerin TEK ayrıştırma noktası
                             # (davet · auth dönüşü · Canlı oyun push linki)
      util/push_rules.dart   # "izin sorulsun mu?" saf kararı (en çok 3 kez,
                             # 7 gün arayla) + platform adı doğrulaması
      util/semver.dart, util/uuid.dart, util/share_board.dart,
      util/game_list_order.dart # devam eden oyun/davet listelerinin sıralaması
                             # (web `gameListOrder.ts` ikizi) — ⚠ Dart `List.sort`
                             # KARARLI DEĞİL, eşitlikte indeks tie-break'i şart
      util/recent_game_avatars.dart # "Son Oynadıklarım" satırındaki rakip
                             # avatarı: eşleme OYUNLA sınırlı (donmuş `players`
                             # anlık görüntüsü `user_id` taşımaz, isimle eşleme
                             # yanlış yüz gösterirdi) — web `recentGameAvatars.ts`
      util/score_line.dart   # kart altı puan satırı (devam eden + son oynanan):
                             # koltuk sırasıyla puanlar " - " ile — web
                             # `scoreLine.ts` ikizi, metin birebir (Parça 192)
      util/head_to_head.dart # skor kartındaki kafa kafaya oran çubuğunun
                             # dilimleri — KÜMÜLATİF yuvarlama (üç bağımsız
                             # yuvarlama 33+33+33=99 verir), web `headToHead.ts`
                             # ikizi; `test/head_to_head_test.dart` ↔
                             # `npm run verify-head-to-head` aynı vakalar
      util/away_return.dart  # "uzun aradan sonra öne dönüş = ekrana yeniden
                             # giriş" eşiği (5 dk); web `src/utils/awayReturn.ts`
                             # ile ELLE senkron — `away_return_test.dart` eşiği
                             # WEB DOSYASINI OKUYARAK kilitliyor, biri değişip
                             # öteki kalırsa test paketi düşer
      util/ai_level.dart     # YZ zorluğunun ÜRÜN yüzü (web `aiLevel.ts` ikizi):
                             # etiketler, Setup'ta seçilebilir liste (Zor Faz 5'e
                             # kadar YOK), seviye açıklamaları (`aiLevelPitch` +
                             # `aiLevelDescription`; puan cümlesi `leaguePoints`ten
                             # türetilir, 4 kişilikte ikincilik dahil), rozet metni
                             # (Normal → null) — `ai_level_parity_test` web
                             # kaynağıyla kilitler
      util/platform.dart      # bu istemcinin platformu (ios/android/app-web) —
                             # telemetri; web `src/utils/platform.ts` karşılığı,
                             # değer kümesi sunucu kısıtıyla ELLE senkron
    util/avatar_picker.dart # profil fotoğrafı seçimi (image_picker sarmalayıcısı,
                             # yalnızca galeri) — enjekte edilebilir PickAvatarFn
    android/ ios/            # flutter create çıktısı + elle değişiklikler (aşağı bkz.)
    test/                    # util, controller (golden replay!), widget duman testleri
      support/vector_parity.dart # web SVG path'i ↔ portun Path()..lineTo
                             # zinciri: ikisini kanonik çizim listesine
                             # indiren ORTAK ayrıştırıcı. İki parite testi
                             # kullanıyor (icon_parity, relation_icon_parity)
                             # — üçüncü bir elle-senkron vektör çifti
                             # eklenirse kopyalama, buradan tüket
      support/fake_analytics.dart # sahte GA4 ucu — configure eden test
                             # tearDown'da analytics.reset() çağırmak
                             # ZORUNDA (global tek örnek, sızıntı)
      support/real_io.dart   # `drainRealIo` — GERÇEK sqflite/prefs I/O'suna
                             # gerçek zaman payı tanır. Gerçek depoyla çizen
                             # HER ekran testi bunu kullanmak ZORUNDA, yoksa
                             # sqflite'ın kilit-uyarı Timer'ı sökülmede
                             # "A Timer is still pending" ile düşer. Kendi
                             # kopyanı yazma — üç kopya tam bu yüzden tek
                             # kaynağa indi (Parça 168)
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
