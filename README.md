# Harfik

**Harfik**, evrilen bir tahtaya ve akıllı bir yapay zekâ rakibe sahip, mobil öncelikli bir **Türkçe kelime oyunudur**. Tek dosyalık `LexFront` HTML prototipi; Vite + React + TypeScript + Tailwind CSS ile modern bir web projesine dönüştürülmüştür.

## Oyun

- **13×13 tahta** — Scrabble benzeri kelime yerleştirme, harf/kelime bonusları (2H, 3H, 2K, 3K).
- **Tahta evrimi** — Her birkaç hamlede tahta değişir: boş kareler çatlar, çatlamış kareler "boşluğa" dönüşerek oynanamaz hâle gelir ve yeni bonuslar belirir.
- **Bölgeler** — Oyuncu sol-alt köşeden, YZ sağ-üst köşeden başlar.
- **Akıllı YZ** — Rafından heceleyebildiği, sözlükçe geçerli en yüksek puanlı hamleyi arar; çapraz kelimeleri de doğrular.
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
│   ├── words.ts       # Türkçe kelime listesi
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

## Dağıtım

Depo Vercel'e bağlanıp doğrudan dağıtılabilir; `vercel.json` Vite ön ayarlarını içerir.

```bash
npm i -g vercel
vercel
```

---

Türkçe kelimelerin tadını çıkar. İyi oyunlar! ⚡
