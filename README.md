# Kelimeki

**Kelimeki**, köşe bölgeleri ve akıllı yapay zekâ rakiple oynanan, mobil öncelikli **Türkçe kelime oyunudur**. Vite + React + TypeScript + Tailwind CSS ile geliştirilmiştir.

## Oyun

- **13×13 tahta** — Scrabble benzeri kelime yerleştirme; ortadaki 5×5 altın bölge her kelimeyi x2 yapar, tam merkez ayrıca X3 (üç kat kelime).
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
```

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
│   ├── GameHistoryModal.tsx     # geçmiş oyunların listesi (tıklayınca bitiş tahtası önizlemesi)
│   ├── GameBoardPreview.tsx     # bir oyunun bitiş anındaki tahtasının salt-okunur önizlemesi
│   ├── MoveHistoryModal.tsx     # oyun geçmişi (hamle hamle)
│   ├── Leaderboard.tsx          # lider tablosu
│   ├── MeaningModal.tsx         # kelime anlamı penceresi
│   ├── RemainingTilesModal.tsx  # torbada kalan taşlar
│   ├── WildcardModal.tsx        # joker taşı harf seçimi
│   ├── FeedbackModal.tsx        # görüş/şikayet bildirme formu
│   ├── AdminDashboard.tsx       # admin paneli: üyeler, oyunlar, büyüme grafiği, geri bildirim (yalnızca is_admin)
│   ├── AdminPlayerDetail.tsx    # admin panelinden bir üyenin ScoreCard'ının salt-okunur görünümü
│   ├── GrowthChart.tsx          # admin büyüme grafiği (generic zaman serisi çizgi grafiği)
│   ├── PrivacyModal.tsx         # gizlilik politikası
│   ├── TermsModal.tsx           # kullanım koşulları
│   ├── Modal.tsx                # paylaşılan modal kabuğu
│   ├── Avatar.tsx               # profil fotoğrafı bileşeni
│   ├── PlayerBadge.tsx          # renkli oyuncu sıra/koltuk rozeti
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
│   ├── gameStorage.ts  # devam eden oyunun localStorage kalıcılığı + terk temizliği
│   ├── gameSync.ts      # bitmiş oyunlar için çevrimdışı/misafir kuyruğu
│   ├── feedbackSync.ts # geri bildirim formu için çevrimdışı kuyruk
│   ├── onboarding.ts   # ilk açılış hızlı başlangıç ipucu bayrağı
│   └── visitTracking.ts # anonim misafir ziyaret kimliği, cihaz/standalone tespiti, UTM kaynağı
├── hooks/
│   ├── useAuth.tsx        # Supabase auth context
│   ├── useModalA11y.ts    # modal odak hapsi, Escape, dialog yığını
│   └── useOnlineStatus.ts # çevrimiçi/çevrimdışı durumu izler
└── lib/
    ├── supabase.ts        # Supabase istemcisi
    ├── api.ts             # saveGame, fetchLeaderboard, auth, fetchMeaning
    ├── pwa.ts             # PWA/service worker yardımcıları
    └── database.types.ts  # şema tipleri
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
