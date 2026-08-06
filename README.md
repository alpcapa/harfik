# Kelimeki

**Kelimeki**, köşe bölgeleri ve akıllı yapay zekâ rakiple oynanan, mobil öncelikli **Türkçe kelime oyunudur**. Vite + React + TypeScript + Tailwind CSS ile geliştirilmiştir.

## Oyun

- **13×13 tahta** — çapraz kelime yerleştirmeli klasik bir tahta oyunu mekaniği; ortadaki 5×5 altın bölge her kelimeyi x2 yapar, tam merkez ayrıca X3 (üç kat kelime).
- **Köşe bölgeleri** — Her oyuncu 4×4'lük bir köşeden başlar (2 kişilik oyunda sol-üst ↔ sağ-alt, 4 kişilik oyunda dört köşenin her biri bir oyuncuda). İlk hamle köşenin ev işaretli tek karesine değmek zorundadır. İlk hamleden sonra bir rakibin bölgesine taş koymanın hiçbir ön koşulu yok — her zaman serbest.
- **Genişleyen bölge** — Bir oyuncunun bölgesi 4×4 köşeyle sınırlı değil; köşesinden başlayıp yalnızca kendi taşlarıyla ortogonal olarak bağlı hücrelere doğru genişler, her hamleden sonra yeniden hesaplanır. Rakip bölgesine vergi ödeyerek konan bir taş, kendi zincirine bağlıysa artık oynayanın bölgesine geçer.
- **Bölge vergisi** — Bir hamle rakip bölgesinin içine düşerse (girme) ya da dışarıdan sınırına bitişik olursa (değme), hamlenin puanının 1/3'ü bölge sahibine aktarılır, 2/3'ü oynayanda kalır (iki farklı bölgeyle birden etkileşirse üç kişi eşit paylaşır: herkese 1/3). Hamle öncesinde onay penceresi gösterilir.
- **Akıllı YZ** — Rafından heceleyebildiği, sözlükçe geçerli en yüksek puanlı hamleyi arar; çapraz kelimeleri de doğrular.
- **Tam sözlük** — TDK Güncel Türkçe Sözlük (12. baskı) kaynaklı **~63 bin oynanabilir kelime**, anlamlarıyla birlikte.
- **Türkçe alfabe** — Ç, Ğ, İ, Ö, Ş, Ü dahil tam harf dağılımı ve puanlar. Joker (`?`) desteklenir. Torba, oyuncu sayısından bağımsız olarak sabit 100 taş.
- **Bingo bonusu** — 7 taşın tamamını tek hamlede kullanınca +25 puan.
- **Dokunmatik** — Mobil öncelikli düzen; harf seç → kareye dokun → **Oyna**.

## Teknoloji

- [Vite 5](https://vitejs.dev/)
- [React 18](https://react.dev/) + TypeScript
- [Tailwind CSS](https://tailwindcss.com/)
- [Supabase](https://supabase.com/) — opsiyonel (auth, lider tablosu, istatistikler)
- [Vercel](https://vercel.com/) ile dağıtım

## Geliştirme

```bash
npm install      # bağımlılıkları yükle
npm run dev      # geliştirme sunucusu (http://localhost:5173)
npm run build    # üretim derlemesi (dist/)
npm run preview  # derlemeyi yerelde önizle
npm run lint     # TypeScript tip kontrolü
npm run test     # Playwright duman testleri (tests/smoke.spec.ts)
```

`npm run test` kritik yolu kontrol eder (uygulama açılıyor, oyun başlıyor, YZ
oynuyor, SPA fallback çalışıyor) — kapsamlı bir paket değil. Canlı oyun,
mesajlaşma, e-posta bildirimleri gibi iki gerçek oturum ve gerçek gelen kutusu
gerektiren akışların elle koşulan kontrol listesi: [`TESTING.md`](TESTING.md).

## Proje Yapısı

```
src/
├── components/
│   ├── Board.tsx                # 13×13 oyun tahtası (köşe renkleri, dinamik bölge hatları, bonus bölgesi)
│   ├── Rack.tsx                 # oyuncunun harf kutusu
│   ├── Tile.tsx                 # tek harf bileşeni
│   ├── GameHeader.tsx           # skor, sıra göstergesi
│   ├── GameOver.tsx             # oyun sonu ekranı
│   ├── Setup.tsx                # oyun başlangıç / oyuncu kurulum ekranı
│   ├── LogoMark.tsx             # "kelimeki" logosu — statik SVG path (üretilmiş, bkz. scripts/generate-logo-paths.mjs), font bağımsız
│   ├── UserMenu.tsx             # hesap menüsü (giriş / hesap ayarları / skor kartı)
│   ├── HelpModal.tsx            # nasıl oynanır sayfası
│   ├── AuthModal.tsx            # giriş / kayıt / şifre sıfırlama
│   ├── ResetPasswordModal.tsx   # şifre sıfırlama e-postasındaki bağlantıdan sonra yeni şifre belirleme
│   ├── AccountSettingsModal.tsx # profil düzenleme (avatar, kullanıcı adı)
│   ├── ScoreCard.tsx            # oyuncu istatistikleri
│   ├── RecentGamesSection.tsx   # Setup'taki "Yapay Zeka ile"/"Arkadaşınla" sekmelerinde son 5 biten oyun listesi
│   ├── GameHistoryModal.tsx     # geçmiş oyunların listesi (kalp ikonu: favori, karta tıkla: tahta önizlemesi), Tümü/Favoriler filtresi
│   ├── GameBoardPreview.tsx     # bir oyunun bitiş anındaki tahtasının salt-okunur önizlemesi
│   ├── MoveHistoryModal.tsx     # oyun geçmişi (hamle hamle)
│   ├── ChatThread.tsx           # oyun içi mesajlaşma: paylaşılan sohbet baloncuğu listesi (canlı + arşiv)
│   ├── ChatModal.tsx            # oyun içi mesajlaşma: Canlı oyunda gerçek sohbet penceresi (yalnızca Canlı oyunlar)
│   ├── ChatSettingsModal.tsx    # oyun içi mesajlaşma Faz 2: kişi sessize alma / rapor etme ayarları (ChatModal'ın dişli ikonundan açılır)
│   ├── GameChatHistoryModal.tsx # oyun içi mesajlaşma: bitmiş bir oyunun dondurulmuş sohbet kaydının salt-okunur görünümü
│   ├── Leaderboard.tsx          # lider tablosu (k-lig)
│   ├── KLigMark.tsx             # "k-lig" logosu — statik SVG path (üretilmiş, bkz. scripts/generate-klig-paths.mjs), font bağımsız
│   ├── CountBadge.tsx           # ortak kırmızı sayaç rozeti (sekme başlıkları, "Arkadaşlar" satırı vb.)
│   ├── MeaningModal.tsx         # kelime anlamı penceresi
│   ├── RemainingTilesModal.tsx  # torbada kalan taşlar
│   ├── WildcardModal.tsx        # joker taşı harf seçimi
│   ├── FeedbackModal.tsx        # görüş/şikayet bildirme formu
│   ├── AdminDashboard.tsx       # admin paneli: üyeler, oyunlar, büyüme grafiği, geri bildirim (yalnızca is_admin)
│   ├── MemberMessageModal.tsx   # admin panelinden bir üyeye serbest metinli mesaj gönderme compose modalı
│   ├── AdminChatTranscriptModal.tsx # admin paneli Şikayetler sekmesi: bitmiş bir Canlı oyunun tam sohbet dökümü
│   ├── PlayerScoreCard.tsx      # bir oyuncunun ScoreCard'ının salt-okunur görünümü (admin panelinden ve k-lig'den açılır)
│   ├── GrowthChart.tsx          # admin büyüme grafiği (generic zaman serisi çizgi grafiği)
│   ├── PrivacyModal.tsx         # gizlilik politikası
│   ├── TermsModal.tsx           # kullanım koşulları
│   ├── Modal.tsx                # paylaşılan modal kabuğu
│   ├── ActionSheet.tsx          # iOS tarzı alttan açılan aksiyon menüsü (ör. tahta önizlemesi → Paylaş/Kapat)
│   ├── SharedGamePage.tsx       # herkese açık /game/:id sayfası (girişsiz de erişilebilir)
│   ├── FriendsModal.tsx         # arkadaş arama/ekleme, gelen istekler, kalıcı davet linki paylaşımı
│   ├── FriendInvitePage.tsx     # herkese açık /davet/:token sayfası (girişsiz de erişilebilir)
│   ├── LiveGamesTab.tsx         # Canlı sekmesi: davet bekleyen/aktif/rakip bekleyen oyun listesi + Kabul/Reddet
│   ├── LiveGameCreateForm.tsx   # Canlı oyun kurulumu: oyuncu sayısı + arkadaş seçici + davet gönderme
│   ├── FriendSuggestModal.tsx   # bir Canlı davet kabul edildikten sonra, henüz arkadaş olunmayan katılımcılara toplu istek gönderme önerisi
│   ├── OnlineGameScreen.tsx     # gerçek Canlı oyun ekranı — Board/Rack/GameHeader'ı Supabase state'ine (Realtime) bağlar
│   ├── Avatar.tsx               # profil fotoğrafı bileşeni
│   ├── PlayerAvatarRow.tsx      # oyun kartlarında "N Kişilik Oyun" başlığı yerine geçen katılımcı avatarları (YZ → robot, misafir → "?")
│   ├── PlayerBadge.tsx          # renkli oyuncu sıra/koltuk rozeti
│   ├── LandscapeHint.tsx        # yatay modda gösterilen kapatılabilir dikey-mod önerisi banner'ı
│   ├── ErrorBoundary.tsx        # kök seviye React crash yakalayıcı
│   └── AddToHomeScreen.tsx      # PWA ana ekrana ekle
├── game/
│   ├── types.ts       # GameState, Player, Tile tipleri
│   ├── constants.ts   # tahta sabitleri, köşe hesapları, bonus konumları
│   └── gameReducer.ts # useReducer ile oyun durum makinesi
├── data/
│   ├── words.ts          # Türkçe kelime listesi (~63 bin kelime, üretilmiş)
│   ├── wordSetLoader.ts  # words.ts'i ayrı bir chunk olarak lazy-load eder
│   ├── meanings.json     # kelime → anlamlar (tembel yüklenir, ~9 MB)
│   ├── meanings.ts       # anlam yükleyici
│   └── tiles.ts          # Türkçe harf dağılımı ve puanlar (100 taş)
├── utils/
│   ├── validator.ts    # kelime doğrulama, bölge kuralları, puanlama
│   ├── ai.ts           # YZ oyuncu mantığı
│   ├── board.ts        # tahta yardımcıları (kelime bulma, hücre key)
│   ├── boardSnapshot.ts # oyun sonu tahtasının games.board_snapshot JSON'una serileştirilmesi/geri yüklenmesi
│   ├── bag.ts          # taş torbası (buildBag, drawTiles)
│   ├── outline.ts      # bölge/bonus dış hat SVG path üretimi
│   ├── turkish.ts      # trUpper / trLower (i/İ, ı/I dönüşümü)
│   ├── random.ts       # karıştırma
│   ├── ranking.ts      # oyun sonu sıralama (teslim olanlar en sona)
│   ├── gameRecord.ts   # buildGameRecord — bir GameState'ten games tablosuna yazılacak kaydı üretir (canlı oyun bitişi ve gecikmeli terk-edilme kaydı ortak)
│   ├── gameStorage.ts  # devam eden oyunun localStorage kalıcılığı + terk temizliği (yalnızca misafir/girişsiz kullanıcı — girişli kullanıcı sunucudaki local_game_saves'i kullanır, cihazlar arası + çoklu oyun, bkz. lib/api.ts)
│   ├── gameSync.ts      # bitmiş oyunlar için çevrimdışı/misafir kuyruğu
│   ├── feedbackSync.ts # geri bildirim formu için çevrimdışı kuyruk
│   ├── onboarding.ts   # ilk açılış hızlı başlangıç ipucu bayrağı
│   ├── visitTracking.ts # anonim misafir ziyaret kimliği, cihaz/standalone tespiti, UTM kaynağı
│   ├── shareBoardImage.ts # bir DOM düğümünü (tahta önizlemesi) paylaşılabilir PNG'ye çevirir (html-to-image)
│   ├── friendInvite.ts # bekleyen arkadaşlık davet token'ı için tek seferlik localStorage kuyruğu
│   ├── csvExport.ts    # admin paneli tabloları/grafikleri için CSV indirme yardımcısı
│   ├── leaguePoints.ts # k-lig puanı hesaplama (GameHistoryModal ve SharedGamePage ortak)
│   └── profileFields.ts # cinsiyet seçenekleri, GG/AA/YYYY ↔ ISO tarih dönüşümü (AuthModal ve AccountSettingsModal ortak)
├── hooks/
│   ├── useAuth.tsx        # Supabase auth context
│   ├── useModalA11y.ts    # modal odak hapsi, Escape, dialog yığını
│   ├── useOnlineStatus.ts # çevrimiçi/çevrimdışı durumu izler
│   ├── useNicknameAvailability.ts # takma isim uygunluğu (debounce'lu RPC kontrolü, AuthModal + AccountSettingsModal ortak)
│   └── useAppIconBadge.ts # PWA ikonu üzerinde Badge API ile kırmızı yuvarlak/beyaz sayı rozeti
└── lib/
    ├── supabase.ts        # Supabase istemcisi
    ├── api.ts             # saveGame, fetchLeaderboard, auth, fetchMeaning
    ├── pwa.ts             # PWA/service worker yardımcıları
    └── database.types.ts  # şema tipleri

mobile/                    # Flutter (iOS+Android) portu — ayrıntı: mobile/CLAUDE.md
├── kelimeki_core/         # oyun motorunun saf Dart portu (web motoruna eşitliği
│                          # golden vector testleriyle kanıtlı: dart run test/run_all.dart)
└── app/                   # Flutter uygulaması: Yapay Zeka'ya karşı oyun uçtan uca
    │                      # oynanabilir (kurulum/tahta/raf/sürükle-bırak, kurallar,
    │                      # kelime anlamı, hamle geçmişi), Supabase oturumu
    │                      # (giriş/kayıt), bulut kayıt senkronu, skor kartı/k-lig,
    │                      # oyun geçmişi (tahta önizlemesi, beğeni, sohbet
    │                      # arşivi, paylaşma), Son Oynadıklarım listesi
    ├── assets/dictionary/ # üretilmiş asset'ler: words_tr.txt (kaynak
    │                      # src/data/words.ts — npm run generate-golden-vectors)
    │                      # ve meanings.db (npm run generate-meanings-db)
    └── assets/fonts/      # Space Grotesk / Space Mono / Nunito (web'le aynı aileler)
```

## Supabase (opsiyonel)

Çevrimiçi özellikler (kullanıcı hesapları, lider tablosu, istatistikler, kelime anlamları) Supabase ile sağlanır. Anahtarlar ayarlı değilse oyun **çevrimdışı** olarak sorunsuz çalışır.

**Şema** `supabase/migrations/` altındadır (kronolojik, artan sırada — en güncel şema için hepsi sırayla uygulanır). İlk dört migration temel şemayı kurar:

- `20260628090000_init.sql` — `profiles`, `games`, `words` tabloları; `leaderboard` & `player_stats` view'ları; RLS politikaları; auth trigger'ı; `is_valid_word` RPC.
- `20260628090100_seed_words.sql` — başlangıçtaki çekirdek kelime listesi.
- `20260628090200_add_word_meanings.sql` — `pos` ve `meanings` sütunları ile `word_meaning` RPC.
- `20260628090300_seed_dictionary.sql` — TDK Güncel Türkçe Sözlük'ten kelimeleri anlamlarıyla yükler.

Sonraki migration'lar `player_stats`/`leaderboard` view'larını, oyun istatistiklerini (en uzun kelime, en iyi hamle, sıralama/`total_score` lig puanı, teslim olma cezası vb.) ve sözlük düzeltmelerini kademeli olarak ekler — güncel listeyi görmek için klasöre bakın.

**Migration'ları uygulama:**

```bash
supabase link --project-ref xvqlizifakkkoqahaxsg
supabase db push
```

> Bu depoda CI ile otomatik migration akışı yok; production'a uygulama şu an Claude Code oturumları tarafından Supabase MCP (`apply_migration`) ile elle yapılıyor — detay ve senkron kuralları için `CLAUDE.md`'ye bakın.

**İstemci yapılandırması** — `.env.example` dosyasını `.env` olarak kopyalayıp doldurun:

```bash
VITE_SUPABASE_URL=https://xvqlizifakkkoqahaxsg.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_...   # Project Settings → API
```

**Edge Functions** (`supabase/functions/`) — Supabase MCP (`deploy_edge_function`) ile deploy edilir, `supabase functions deploy` CLI akışı kullanılmaz. Şu anki fonksiyonlar:

- `_shared/email.ts` — gerçek bir fonksiyon değil, Brevo'yla e-posta gönderen tüm fonksiyonların paylaştığı ortak kod (Brevo çağrısı, HTML escape, tek yönlü noreply notu). Her deploy çağrısında ilgili fonksiyonun `files` listesine ayrıca eklenir (Supabase her fonksiyonu kendi bağımsız paket olarak dağıttığından).
- `feedback-reply/` — admin panelinden bir görüş bildirimine yanıt gönderildiğinde çağrılır; Brevo'nun Transactional Email API'siyle (SMTP değil, ayrı bir `BREVO_API_KEY` Edge Function secret'ı ile) yanıtı gönderenin e-postasına iletir ve `feedback.reply`/`replied_at`/`replied_by` alanlarını günceller.
- `admin-send-message/` — admin panelinin Üyeler tablosundan bir üyeye elle yazılan serbest metinli mesajı (konu + gövde) aynı Brevo API'siyle gönderir; bir feedback kaydına bağlı olmadığından DB'ye bir şey yazmaz.
- `play-ai-turn/` — Canlı (online) bir oyunda sırası gelen YZ koltuğunun turunu tamamen sunucuda oynar; YZ'nin gerçek rafı bu sayede hiçbir zaman tarayıcıya gönderilmez (bkz. `CLAUDE.md`, "Canlı Oyun — Faz 3"). `_game/` altındaki `ai.ts`/`validator.ts`/`board.ts`/`constants.ts`/`types.ts`/`turkish.ts`/`tiles.ts`/`wordSet.ts` kopyalarını kullanır — `src/`'deki kaynaklar değişirse elle senkronize edilmeli.
- `notify-friend-request/` / `notify-game-invite/` — bir arkadaşlık isteği ya da Canlı oyun daveti oluşturulduğunda alıcıya işlemsel (marketing_consent'e bağlı olmayan) bir e-posta bildirimi gönderir; aynı Brevo API'sini kullanır. Best-effort/fire-and-forget çağrılır (`src/lib/api.ts`), bir e-posta hatası isteğin/davetin kendisini etkilemez. Detay için `CLAUDE.md`'deki "İşlemsel e-posta bildirimleri" bölümüne bakın.
- `notify-deadline-warnings/` — Canlı oyunda sırası gelen oyuncuya (48 saatlik `turn_deadline`) ve YZ'ye karşı devam eden oyunlara (7 günlük terk-edilme penceresi) süre 24 saatten az kalınca hatırlatma gönderir. Projenin ilk `pg_cron` + `pg_net` job'u — kullanıcı etkileşimine bağlı diğer "hafif" desenlerin aksine (`check_turn_timeout` gibi) 15 dakikada bir kendiliğinden tetiklenir, `verify_jwt: false`.
- `notify-friend-request-reminders/` — 3 gün cevapsız kalan arkadaşlık isteklerine tek seferlik bir hatırlatma e-postası gönderir. İkinci `pg_cron` job'u, günde bir kez (08:00 UTC) tetiklenir. Detay için `CLAUDE.md`'deki "Arkadaşlık isteği hatırlatma e-postası" bölümüne bakın.
- `notify-turn-timeout-surrender/` — bir Canlı oyunda sırası gelen oyuncu 48 saat içinde hamle yapmayıp otomatik teslim olduğunda (ve bu, oyunun gerçekten bittiği ana denk geldiğinde) ilgili oyunculara -2 k-lig cezasını bildirir. `check_turn_timeout` RPC'sinden `net.http_post` ile SQL içinden tetiklenir, `verify_jwt: false`.
- `notify-local-game-abandoned/` — Yapay Zeka'ya karşı 7 gün boyunca hiç hamle yapılmayıp terk edilmiş sayılan bir yerel oyunun -2 k-lig cezasını hesap sahibine bildirir; `saveGame` gerçek bir `surrendered:true` kaydı eklediğinde tetiklenir.
- `notify-account-banned/` / `notify-account-unbanned/` — admin bir hesabı dondurduğunda/dondurmayı kaldırdığında ilgili kullanıcıya bildirim gönderir.

Altı işlemsel bildirim türü (`notify-friend-request`, `notify-friend-request-reminders`, `notify-game-invite`, `notify-deadline-warnings`, `notify-turn-timeout-surrender`, `notify-local-game-abandoned`) alıcının `profiles.email_notifications_enabled` tercihine (varsayılan açık, Hesap Ayarları'ndan kapatılabilir) bağlıdır — kapalıysa gönderim sessizce atlanır. Hesap güvenliği/admin yazışması niteliğindeki diğer fonksiyonlar (`notify-account-banned`/`notify-account-unbanned`, `feedback-reply`, `admin-send-message`) bu tercihe bakmadan her zaman gönderilir.

Yukarıdaki tüm e-posta gönderen fonksiyonlar `noreply@kelimeki.com` adresinden gönderiyor (tek yönlü — gerçek bir `destek@` gelen kutusu henüz kurulmadı, bilinçli olarak ertelendi). `feedback-reply`/`admin-send-message`'ın gönderdiği e-postaların altında "Bu e-posta noreply adresinden gönderilmiştir. Cevap için tıklayın" notu var — link `kelimeki.com/?contact=1&re=<id>`'e gider (`<id>`, cevaben geldiği mesajın kaydı), `App.tsx`'teki bir effect bu parametreleri okuyup genel "Görüş Bildir" formunu (`FeedbackModal`, `source="general"`) otomatik açar ve yeni gönderilen mesajı `feedback.related_to` ile önceki mesaja bağlar. `admin-send-message` artık kendi gönderdiği mesajı da `feedback`'e (`origin: 'admin'`) yazıyor — admin panelinde "kime ne yazıldığı" kalıcı olarak görünür.

## Sözlük Verisi

Kelimeler ve anlamları **TDK Güncel Türkçe Sözlük (12. baskı)** kaynaklıdır;
[ogun/guncel-turkce-sozluk](https://github.com/ogun/guncel-turkce-sozluk) (MIT lisansı) üzerinden alınmıştır. Ham dökümdeki çok sözcüklü maddeler birleştirilir ("dulavrat otu" → "dulavratotu"); ardından yalnızca Türk alfabesi harfleri içeren 2–25 harfli tokenlar tutularak süzülür. Çok sözcüklü atasözü/deyim/özel isim gibi oynanamayacak maddeler sonradan ayrıca temizlenmiştir (bkz. `supabase/migrations/2026071913*_remove_*`), bu yüzden güncel liste ilk süzülen haliyle aynı değildir — **~63 bin oynanabilir kelime**. TDK'de eksik olan başlıca dünya ülkesi/başkent/dil adları `scripts/proper-nouns.mjs` ile ayrıca eklenir.

Üretilen dosyaları yeniden oluşturmak için:

```bash
# 1) Kaynağı indir ve aç
curl -sSL -o gts.json.tar.gz \
  https://raw.githubusercontent.com/ogun/guncel-turkce-sozluk/master/sozluk/v12/v12.gts.json.tar.gz
tar xzf gts.json.tar.gz

# 2) Veri dosyalarını üret
GTS_JSON=./gts.json npm run build:dict
```

## Dağıtım

Depo Vercel'e bağlanıp doğrudan dağıtılabilir; `vercel.json` Vite ön ayarlarını içerir. Main branch'e merge otomatik deploy tetikler.

---

İyi oyunlar!
