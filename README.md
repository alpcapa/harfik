# Harfik

**Harfik**, köşe bölgeleri ve akıllı yapay zekâ rakiple oynanan, mobil öncelikli **Türkçe kelime oyunudur**. Vite + React + TypeScript + Tailwind CSS ile geliştirilmiştir.

## Oyun

- **13×13 tahta** — Scrabble benzeri kelime yerleştirme, harf/kelime bonusları (H2, H3, K2, K3).
- **Köşe bölgeleri** — Her oyuncu 5×5'lik bir köşeden başlar. 2 kişilik oyunda çapraz köşeler (sol-üst ↔ sağ-alt), 4 kişilik oyunda dört köşe kullanılır. Kendi köşen korunmuştur; rakipler ancak sen sınır karesine taş koyduktan sonra girebilir.
- **Köşe vergisi** — Rakip köşesinde oynanan hamlenin puanı ikiye bölünür: yarısı saldırgana kalır, yarısı köşe sahibine aktarılır. Hamle öncesinde onay penceresi gösterilir.
- **Akıllı YZ** — Rafından heceleyebildiği, sözlükçe geçerli en yüksek puanlı hamleyi arar; çapraz kelimeleri de doğrular.
- **Tam sözlük** — TDK Güncel Türkçe Sözlük (12. baskı) kaynaklı **92.771 oynanabilir kelime**, anlamlarıyla birlikte.
- **Türkçe alfabe** — Ç, Ğ, İ, Ö, Ş, Ü dahil tam harf dağılımı ve puanlar. Joker (`?`) desteklenir. Toplam 186 taş.
- **Bingo bonusu** — 7 taşın tamamını tek hamlede kullanınca +50 puan.
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
│   ├── Board.tsx                # 13×13 oyun tahtası (köşe renkleri, bonus kareler)
│   ├── Rack.tsx                 # oyuncunun harf kutusu
│   ├── Tile.tsx                 # tek harf bileşeni
│   ├── GameHeader.tsx           # skor, sıra göstergesi
│   ├── GameOver.tsx             # oyun sonu ekranı
│   ├── Setup.tsx                # oyun başlangıç / oyuncu kurulum ekranı
│   ├── UserMenu.tsx             # hesap menüsü (giriş / profil / lider tablosu)
│   ├── HelpModal.tsx            # nasıl oynanır sayfası
│   ├── AuthModal.tsx            # giriş / kayıt / şifre sıfırlama
│   ├── AccountSettingsModal.tsx # profil düzenleme (avatar, kullanıcı adı)
│   ├── ScoreCard.tsx            # oyuncu istatistikleri
│   ├── Leaderboard.tsx          # lider tablosu
│   ├── MeaningModal.tsx         # kelime anlamı penceresi
│   ├── RemainingTilesModal.tsx  # torbada kalan taşlar
│   ├── Modal.tsx                # paylaşılan modal kabuğu
│   ├── Avatar.tsx               # profil fotoğrafı bileşeni
│   └── AddToHomeScreen.tsx      # PWA ana ekrana ekle
├── game/
│   ├── types.ts       # GameState, Player, Tile tipleri
│   ├── constants.ts   # tahta sabitleri, köşe hesapları, bonus konumları
│   └── gameReducer.ts # useReducer ile oyun durum makinesi
├── data/
│   ├── words.ts       # Türkçe kelime listesi (92.771 kelime, üretilmiş)
│   ├── meanings.json  # kelime → anlamlar (tembel yüklenir, ~6 MB)
│   ├── meanings.ts    # anlam yükleyici
│   └── tiles.ts       # Türkçe harf dağılımı ve puanlar (186 taş)
├── utils/
│   ├── validator.ts   # kelime doğrulama, bölge kuralları, puanlama
│   ├── ai.ts          # YZ oyuncu mantığı
│   ├── board.ts       # tahta yardımcıları (kelime bulma, hücre key)
│   ├── bag.ts         # taş torbası (buildBag, drawTiles)
│   ├── turkish.ts     # trUpper / trLower (i/İ, ı/I dönüşümü)
│   └── random.ts      # karıştırma
├── hooks/
│   └── useAuth.tsx    # Supabase auth context
└── lib/
    ├── supabase.ts        # Supabase istemcisi
    ├── api.ts             # saveGame, fetchLeaderboard, auth, fetchMeaning
    └── database.types.ts  # şema tipleri
```

## Supabase (opsiyonel)

Çevrimiçi özellikler (kullanıcı hesapları, lider tablosu, istatistikler, kelime anlamları) Supabase ile sağlanır. Anahtarlar ayarlı değilse oyun **çevrimdışı** olarak sorunsuz çalışır.

**Şema** `supabase/migrations/` altındadır:

- `20260628090000_init.sql` — `profiles`, `games`, `words` tabloları; `leaderboard` & `player_stats` view'ları; RLS politikaları; auth trigger'ı; `is_valid_word` RPC.
- `20260628090100_seed_words.sql` — başlangıçtaki çekirdek kelime listesi.
- `20260628090200_add_word_meanings.sql` — `pos` ve `meanings` sütunları ile `word_meaning` RPC.
- `20260628090300_seed_dictionary.sql` — TDK Güncel Türkçe Sözlük'ten 92.771 kelimeyi anlamlarıyla yükler.

**Migration'ları uygulama:**

```bash
supabase link --project-ref xvqlizifakkkoqahaxsg
supabase db push
```

**İstemci yapılandırması** — `.env.example` dosyasını `.env` olarak kopyalayıp doldurun:

```bash
VITE_SUPABASE_URL=https://xvqlizifakkkoqahaxsg.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_...   # Project Settings → API
```

## Sözlük Verisi

Kelimeler ve anlamları **TDK Güncel Türkçe Sözlük (12. baskı)** kaynaklıdır;
[ogun/guncel-turkce-sozluk](https://github.com/ogun/guncel-turkce-sozluk) (MIT lisansı) üzerinden alınmıştır. Ham dökümdeki çok sözcüklü maddeler birleştirilir ("dulavrat otu" → "dulavratotu"); ardından yalnızca Türk alfabesi harfleri içeren 2–25 harfli tokenlar tutularak **92.771 oynanabilir kelimeye** süzülür.

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
