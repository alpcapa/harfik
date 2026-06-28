# Harfik

**Harfik**, evrilen bir tahtaya ve akıllı bir yapay zekâ rakibe sahip, mobil öncelikli bir **Türkçe kelime oyunudur**. Tek dosyalık `LexFront` HTML prototipi; Vite + React + TypeScript + Tailwind CSS ile modern bir web projesine dönüştürülmüştür.

## Oyun

- **13×13 tahta** — Scrabble benzeri kelime yerleştirme, harf/kelime bonusları (2H, 3H, 2K, 3K).
- **Tahta evrimi** — Her birkaç hamlede tahta değişir: boş kareler çatlar, çatlamış kareler "boşluğa" dönüşerek oynanamaz hâle gelir ve yeni bonuslar belirir.
- **Bölgeler** — Oyuncu sol-alt köşeden, YZ sağ-üst köşeden başlar.
- **Akıllı YZ** — Rafından heceleyebildiği, sözlükçe geçerli en yüksek puanlı hamleyi arar; çapraz kelimeleri de doğrular.
- **Tam sözlük** — TDK Güncel Türkçe Sözlük (12. baskı) kaynaklı **63.101 oynanabilir kelime**, anlamlarıyla birlikte.
- **Türkçe alfabe** — Ç, Ğ, İ, Ö, Ş, Ü dahil tam harf dağılımı ve puanlar. Joker (`?`) desteklenir.
- **Dokunmatik** — Mobil öncelikli düzen; harf seç → kareye dokun → **Oyna**.

## Teknoloji

- [Vite 5](https://vitejs.dev/)
- [React 18](https://react.dev/) + TypeScript
- [Tailwind CSS](https://tailwindcss.com/)
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
├── components/        # React bileşenleri
│   ├── Board.tsx      # 13×13 oyun tahtası
│   ├── Rack.tsx       # oyuncunun harf rafı
│   ├── Tile.tsx       # tek harf bileşeni
│   ├── GameHeader.tsx # skor, sıra, torba sayısı
│   └── GameOver.tsx   # oyun sonu ekranı
├── game/
│   ├── types.ts       # paylaşılan tipler
│   ├── constants.ts   # tahta boyutu, bonus yerleşimi, bölgeler
│   └── gameReducer.ts # useReducer ile durum yönetimi
├── data/
│   ├── words.ts       # Türkçe kelime listesi (63.101 kelime, üretilmiş)
│   ├── meanings.json  # kelime → anlamlar (tembel yüklenir, ~6 MB)
│   ├── meanings.ts    # anlam yükleyici (getLocalMeaning)
│   └── tiles.ts       # Türkçe harf dağılımı ve puanlar
└── utils/
    ├── validator.ts      # kelime doğrulama ve puanlama
    ├── ai.ts             # YZ oyuncu mantığı
    ├── boardEvolution.ts # tahta evrim mantığı
    ├── board.ts          # tahta yardımcıları
    ├── bag.ts            # taş torbası
    └── random.ts         # karıştırma / rastgele seçim
```

## Renk Paleti

| Amaç      | Renk      |
| --------- | --------- |
| Arka plan | `#080C10` |
| Accent    | `#00C8FF` |
| YZ rengi  | `#FF4060` |
| Altın     | `#FFD040` |

## Supabase (veritabanı)

Çevrimiçi özellikler (kullanıcı hesapları, liderlik tablosu, istatistikler, DB'deki kelime listesi) Supabase ile sağlanır. Anahtarlar ayarlı değilse oyun **çevrimdışı/yerel** olarak sorunsuz çalışır.

**Şema** `supabase/migrations/` altındadır:

- `20260628090000_init.sql` — `profiles`, `games`, `words` tabloları; `leaderboard` & `player_stats` view'ları; RLS politikaları; auth trigger'ı; `is_valid_word` RPC.
- `20260628090100_seed_words.sql` — başlangıçtaki çekirdek kelime listesini `words` tablosuna yükler.
- `20260628090200_add_word_meanings.sql` — `words` tablosuna `pos` (sözcük türü) ve `meanings` (jsonb) sütunları ile `word_meaning` RPC ekler.
- `20260628090300_seed_dictionary.sql` — TDK Güncel Türkçe Sözlük'ten 63.101 kelimeyi **anlamlarıyla** yükler (üretilmiştir).

**Migration'ları uygulama**

Supabase CLI ile:

```bash
supabase link --project-ref xvqlizifakkkoqahaxsg
supabase db push
```

veya her `.sql` dosyasını Supabase panelindeki **SQL Editor**'da çalıştırarak.

**İstemci yapılandırması** — `.env.example` dosyasını `.env` olarak kopyalayıp doldurun:

```bash
VITE_SUPABASE_URL=https://xvqlizifakkkoqahaxsg.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_...   # Project Settings → API
```

Veri erişimi `src/lib/` altında: `supabase.ts` (istemci), `api.ts` (saveGame, fetchLeaderboard, fetchPlayerStats, auth, `isValidWordRemote`, `fetchMeaning`), `database.types.ts` (şema tipleri).

## Sözlük verisi

Kelimeler ve anlamları **TDK Güncel Türkçe Sözlük (12. baskı)** kaynaklıdır;
açık veri olarak [ogun/guncel-turkce-sozluk](https://github.com/ogun/guncel-turkce-sozluk)
(MIT lisansı) üzerinden alınmıştır. Ham döküm (99.236 madde), yalnızca Türk
alfabesi harfleri içeren tek sözcüklü maddelere indirgenerek **63.101 oynanabilir
kelimeye** süzülür.

Üretilen dosyalar (`src/data/words.ts`, `src/data/meanings.json`,
`supabase/migrations/20260628090300_seed_dictionary.sql`) repoda tutulur;
yeniden üretmek için:

```bash
# 1) Kaynağı indir ve aç (~100 MB açılmış NDJSON)
curl -sSL -o gts.json.tar.gz \
  https://raw.githubusercontent.com/ogun/guncel-turkce-sozluk/master/sozluk/v12/v12.gts.json.tar.gz
tar xzf gts.json.tar.gz

# 2) Veri dosyalarını üret
GTS_JSON=./gts.json npm run build:dict
```

## Dağıtım

Depo Vercel'e bağlanıp doğrudan dağıtılabilir; `vercel.json` Vite ön ayarlarını içerir.

```bash
npm i -g vercel
vercel
```

---

Türkçe kelimelerin tadını çıkar. İyi oyunlar! ⚡
