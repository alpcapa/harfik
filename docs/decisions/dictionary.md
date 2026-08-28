# Sözlük İşlemleri — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026). Kaynak: 'Sözlüğe Kelime/Anlam Ekleme' + 'Kelime Listesi Code-Splitting'i' bölümleri. Elle kelime ekleme prosedürü için BURAYA bak.

## Sözlüğe Kelime/Anlam Ekleme (15 Ağustos 2026)

`src/data/words.ts` ÜRETİLMİŞ bir dosyadır ve elle düzenlenmez; tam üretim
(`npm run build:dict`) 100 MB'lık GTS kaynağını ister ve o repoda YOK. Elle
madde eklemek için GTS'e gerek OLMAYAN yol: üç listeden birine yaz, sonra
`npm run augment-dictionary`.

| Liste | Ne için | Kural |
|---|---|---|
| `scripts/proper-nouns.mjs` | ülke/başkent/şehir/dil adları | zaten varsa dokunma |
| `scripts/extra-words.mjs` | GTS'te hiç geçmeyen diğer sözcükler | zaten varsa dokunma |
| `scripts/extra-meanings.mjs` | VAR OLAN kelimeye ek anlam | varsa listeye ekler |

**Hangisini seçeceğini kelimenin sözlükte olup olmadığı belirler, tahminle
değil ÖLÇEREK.** Önce `meanings.json` + `public.words` ikisine birden bak;
ikisi ayrışmış olabilir (bkz. "id"/"pi" vakası, `20260705153000`).

**15 Ağustos 2026'da bu adım YANLIŞ yapıldı ve düzeltmesi iki migration
tuttu — dersi burada:** kullanıcı *sahip/iye* anlamıyla "ıs" (ı ile) istedi;
ben sözlükte "is" (i ile — kurum/kara leke) maddesini bulup "kelime zaten
var, demek ki ek anlam istiyor" diye yorumladım ve anlamı YANLIŞ kelimeye
ekledim. **Türkçede i/ı ayrımı iki ayrı kelime demektir** — `ıssız`
(= sahipsiz) ı'lı olandan türer. Bu proje `trUpper`/`trLower` kuralıyla bu
riski zaten tanıyor; sözlüğe dokunurken de geçerli: eklenecek kelimeyi
**verilen harfle** ara, benzerini bulunca "aynıdır" varsayma. Kontrol
kolay — `is_valid_word('IS')` ile `is_valid_word('İS')` FARKLI kelimelere
çözülür ve sunucu bunu doğru yapıyor (ölçüldü).

`augment-dictionary` üç çıktı üretir: `words.ts`, `meanings.json` ve
YALNIZCA o çalıştırmada değişen maddeler için yeni bir migration
(`<damga>_add_words.sql`, ana seed dosyasına dokunmaz). Ardından **zincirin
kalanı zorunlu** — her halkanın atlanması ayrı bir arıza üretir:

| Adım | Atlanırsa |
|---|---|
| `npm run generate-golden-vectors` + `dart run test/run_all.dart` | `words_tr.txt` bayat kalır → mobil YZ farklı kelime seçer, parite testleri düşer |
| Migration'ı canlıya uygula + `list_migrations` ile dosya adını eşleştir | Kelime yerelde YEŞİL görünür ama OYNA'da sunucu reddeder (`is_valid_word` tabloda bulamaz) |
| `npm run generate-meanings-db` | Mobilde taşa dokununca "anlamı bulunamadı" |
| `README.md` kelime sayısı / `mobile/CLAUDE.md`'deki somut rakam | Doküman koddan kopar (bu proje bunu bir kez 92.503 ↔ ~64 bin farkıyla yaşadı) |

⚠ **"Zaten varsa dokunma" bir SESSİZ tuzak taşıyor — var olan bir maddeyi
SONRADAN düzeltmek İŞE YARAMAZ (28 Ağustos 2026'da yaşandı).** `extra-words`
ve `proper-nouns` yalnızca EKLER: kelime `meanings.json`'da bir kez göründükten
sonra, listedeki girdisini değiştirmek (sınıfını ya da anlamını) betik
tarafından atlanır ve ekrana `Yapacak bir şey yok` yazılır. O gün `mö`nün
sınıfı `ünl.` → `a.` çevrilirken tam bu oldu; düzenleme yapıldı, betik koştu,
hiçbir şey değişmedi.

**Kural bilinçli** (extras listesi GTS maddelerini ezmemeli) ve DEĞİŞMEDİ —
değişen sessizlik: betik artık sapmayı görünce **uyarıyor** (`⚠ extra-words.mjs
sözlükten AYRIŞMIŞ ve bu düzenleme UYGULANMADI: …`). Karşılaştırma sınıfta
katı, anlamlarda ALT KÜME — çünkü aynı kelimeye `extra-meanings` üzerinden
sonradan anlam eklenmiş olabilir ve o meşru bir farktır.

**Düzeltmeyi gerçekten uygulamanın yolu** (uyarı da bunu yazıyor): maddeyi
`src/data/meanings.json`'dan SİL, sonra `npm run augment-dictionary` koş.
Betiğin tohumu o dosya olduğundan madde "yeni" sayılır, yeniden eklenir ve
bir migration üretilir; migration `on conflict do update` olduğu için canlıdaki
satırı da düzeltir. Ardından zincirin kalanı her zamanki gibi koşulur.

**Yeni bir liste dosyası açılırsa İKİ betiğe birden tanıtılmalı**
(`augment-dictionary.mjs` VE `build-dictionary.mjs`) — yalnızca birincisine
eklemek, ileride GTS ile yapılacak bir tam üretimde o maddelerin SESSİZCE
düşmesi demektir. `extra-words.mjs` eklenirken ikisi birden bağlandı.

**Yayılma gecikmesi (bilinçli) — ÜÇ yüzey, üç ayrı hız.** "Kelime ekledim"
tek başına hiçbir istemcide görünmez; kelime üç yerde birden yaşıyor:

| Yüzey | Kelime nerede | Ne gerekiyor |
|---|---|---|
| Sunucu | `public.words` tablosu | Migration canlıya uygulanır → **anında**, merge beklemez |
| Web | `src/data/words.ts` → ayrı JS chunk'ı, **derlemeye gömülü** | **main'e merge → Vercel deploy** |
| App | `mobile/app/assets/dictionary/words_tr.txt`, **paketin içinde** | **Yeni derleme + yeni Play sürümü + kullanıcının güncellemesi** |

Web'in `validator.ts`'i kendi gömülü listesine baktığından, migration
uygulanmış olsa bile kelime deploy edilene kadar arayüzde geçersiz görünür.

⚠ **28 Ağustos 2026 — bu bölüm eskiden şöyle bitiyordu: *"Bugün mobil
yalnızca test ortamı olduğundan sorun değil — mağazaya çıkıldığında bu,
'web'de kabul edilen kelimeyi mobil reddediyor' olarak görünür."* O gün
GELDİ:** app Play'de kapalı testte (`1.0.0 (407)`), yani bugün eklenen bir
kelime bir sonraki mobil sürüme kadar app'te geçersiz kalır. Pratik kural:
**kelime eklemelerini biriktir ve bir sonraki mobil sürüme bindir.** Sunucu
+ web'i hemen güncellemek serbest ve zararsız (web daha hoşgörülü olur,
oyun bozulmaz) — ama fark bilinçli kabul edilmiş olur.

Not: kapalı testte yeni bir sürüm çıkarmak **14 günlük tester sayacını
etkilemez** (sayaç opt-in durumuna bakar, sürümlere değil).

## Kelime Listesi Code-Splitting'i

`src/data/words.ts` (~63k kelime, ~860 KB kaynak) 24 Temmuz 2026'ya kadar `validator.ts` ve `ai.ts` tarafından **statik** `import` ile çekiliyordu — `vite.config.ts`'te `manualChunks` olmadığından bu, PageSpeed'in mobilde ölçtüğü ana JS paketine (~395 KiB transfer, 102 KiB'ı "unused") gömülüyor, Setup ekranı daha render olmadan indirilip parse ediliyordu. Artık `src/data/wordSetLoader.ts` üzerinden ayrı bir chunk (`words-*.js`) olarak dinamik `import()` ile geliyor:

- `main.tsx`, `preloadWordSet()`'i uygulama daha render olmadan (fire-and-forget) tetikler — ana JS paketi bu veriyi beklemeden çalışır, indirme arka planda paralel sürer.
- `validator.ts`/`ai.ts` artık `WORD_SET`'i doğrudan import etmiyor, `getWordSet()` (henüz yüklenmediyse fırlatan) üzerinden okuyor — `ai.ts`'teki `WORD_POOL` da modül yüklenirken değil ilk `findAIMove` çağrısında lazy hesaplanıp önbelleğe alınıyor (`getWordPool()`).
- `gameReducer.ts` senkron bir `useReducer` reducer'ı olduğundan (await edemez), gerçek hamle doğrulama (`App.tsx`'teki canlı `moveStatus`), "Oyna" (`handlePlay`) ve YZ turu efekti `wordsReady` bayrağıyla korunuyor — kelime listesi hazır olmadan bu üçü tetiklenmiyor. Setup ekranındaki "Oyunu Başlat" da aynı şekilde `isWordSetReady()`'e kadar "Hazırlanıyor…" gösterip devre dışı kalıyor. Pratikte Setup'ta oyuncu kurulumuna harcanan birkaç saniye içinde chunk zaten yüklenmiş oluyor; bu bayraklar sadece güvenlik ağı (ör. kaydedilmiş bir oyunun YZ sırasında doğrudan açılması gibi Setup'ı atlayan senaryolar için).
- `words-*.js`, VitePWA'nın varsayılan `generateSW` precache listesine otomatik dahil oluyor (diğer JS parçaları gibi) — offline oynanabilirlik bozulmuyor, sadece ilk ziyarette (ya da SW güncellemesinde) bir kez ayrıca indiriliyor.

