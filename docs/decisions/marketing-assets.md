# Reklam/Pazarlama Görselleri — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026). scripts/sponsored-post, scripts/play-store, scripts/kapak, scripts/reel.

## Reklam Görselleri (`scripts/sponsored-post/`, 20 Ağustos 2026)

Kullanıcının kendi network'üne yaptığı organik paylaşım beğeni aldı ama tek
bir üyelik/oyun getirmedi; bunun üzerine 6 gün × 433 TL'lik sponsorlu bir
carousel için 5 kare görsel üretildi (1080×1080, 2× ölçek). Çıktılar
`marketing/sponsored-2026-08/` (5 PNG + `metin.md`: LinkedIn ve Meta metin/
hashtag setleri, reklam kurulum notları).

```bash
npm run build                          # derlenmiş CSS ŞART (aşağı bkz.)
node scripts/sponsored-post/build.mjs  # 5 PNG'yi yeniden yazar
npm run generate-reel                  # kelimeki-reel.mp4 (bkz. aşağıdaki reel notu)
```

- **Görseller çizim DEĞİL, üretim bileşenlerinin sunucuda render'ı** —
  tahtalar `GameBoardPreview`→`Board` (`compact={false}`, `demoBoard.ts`),
  rütbeler `RankSeal` + `RANK_TIERS`, logo `LandingLogo`, adım şemalarının
  renkleri `PLAYER_COLORS`. Karşılama katmanının gerekçesiyle aynı: ikinci
  bir "tanıtım çizimi" sessiz ayrışma üretirdi. Palet/rütbe/tahta değişirse
  tek komutla takip ederler.
- **⚠ Poster dosyasında Tailwind sınıfı KULLANILMAZ, yalnızca inline `style`.**
  `tailwind.config.js`in `content`i `./index.html` + `./src/**/*.{ts,tsx}` —
  `scripts/` altındaki bir `text-[52px]` derlenmiş CSS'e HİÇ girmez ve
  sessizce uygulanmaz (`CountBadge`in `-right-2` tuzağının aynısı). İçe
  aktarılan üretim bileşenlerinin sınıfları `src/` tarandığı için zaten
  `dist` CSS'inde; `shadow-raised`/`btn-raised` de öyle.
- **⚠ Tahta `transform: scale` ile büyütülür, kap genişliğiyle DEĞİL.**
  `Board` `max-w-[680px]`, harf ise `vw` tabanlı bir `clamp` (`Tile.tsx`) —
  kabı oynatmak harf/hücre oranını bozar (18 Ağustos 2026'da karşılama
  katmanında yaşanan hata). Sayfa `http://` üzerinden açılıyor (`file://`
  tüm puntoları 16px okur, bkz. aynı bölüm).
- **Metinler `Landing.tsx`ten KOPYA DEĞİL** — reklam kopyası sayfa
  kopyasından kısadır. İkisi arasında senkron yükümlülüğü YOK; tek kaynak
  zorunluluğu yalnızca VERİ için (rütbe tablosu, palet, tahta taşları).
- **Ölçüldü** (Chromium, 1080 viewport, `document.fonts.ready`): beş karede de
  dikey/yatay taşma **0** — `Slide` `overflow:hidden` olduğundan taşma sessizce
  kırpılırdı, "sığdı" varsayılamaz.
- **`?ref=` ölçüm notu (`metin.md`de de yazılı):** kampanya URL'i
  `kelimeki.com/?ref=meta` gibi olmalı. `captureUtmSource`
  (`src/utils/visitTracking.ts`) YALNIZCA `?ref=` okuyor; platformların
  eklediği `utm_source=...` bu projede hiçbir yere yazılmaz, yani `?ref=`
  yoksa trafik admin panelindeki **Kaynak Hunisi**'nde "direkt" satırına
  düşer ve kampanya ayırt edilemez. Sitede Meta pixel'i / LinkedIn Insight
  Tag YOK (bilinçli), dolayısıyla platform üyeliğe göre optimize edemez —
  hedef "Trafik", optimizasyon "açılış sayfası görüntüleme".

### Google Play vitrini (`scripts/play-store/`, 23 Ağustos 2026)

`marketing/play-store/` → `store-icon-512.png` (512×512) +
`feature-graphic.png` (1024×500) + `metin.md` (Play'e elle girilecek
başlık/kısa/tam açıklama ve cihazdan alınacak ekran görüntülerinin çekim
listesi). `npm run generate-play-assets`.

- **Mağaza ikonu ELLE ÇİZİLMEZ, cihazdaki başlatıcı ikonun KAYNAĞINDAN
  küçültülür** (`mobile/app/assets/icon/icon-source.png`, yani
  `flutter_launcher_icons.image_path`) — ayrı bir kaynaktan üretilse
  mağazadaki ikon ile telefondaki ikon sessizce ayrışırdı.
- **İkisi de ALFASIZ** (`flatten`): Play ikona kendi maskesini uyguluyor,
  öne çıkan görsel ise 24-bit PNG/JPEG istiyor.
- **Öne çıkan görsel 2× çekilip 1×'e indiriliyor** — Play boyutu TAM
  1024×500 istediğinden doğrudan 1× çekmek tek seçenek gibi görünüyor, ama
  süperörnekleme gözle görülür şekilde daha keskin.
- **Ölçüm YAZMADAN ÖNCE:** güvenli kutu kenara 40/30 px'den yakınsa ya da
  sayfa taşıyorsa betik hiçbir dosya yazmadan `exit 1` — başarısız bir koşu
  diske "bitmiş gibi duran" bozuk bir görsel bırakmamalı. **Negatif eş
  ölçüldü:** kutu 600 → 980 px yapılınca betik gerçekten düşüyor ve
  `feature-graphic.png` HİÇ oluşmuyor.
- **⚠ Tanıtım videosu eklenirse tasarım gözden geçirilmeli:** Play o
  durumda öne çıkan görselin ORTASINA bir oynat düğmesi bindiriyor, yani
  tam da logonun üstüne.
- **Ekran görüntüleri burada ÜRETİLMEZ ve üretilemez** — Play'e giden
  telefon görüntülerinin uygulamanın gerçek görüntüsü olması gerekiyor,
  gerçek cihazdan alınmalı. Çekim listesi + gizlilik uyarıları (gerçek
  arkadaş adı/e-posta görünmemeli — görseller herkese açık yayınlanıyor)
  `metin.md`'de.

### Facebook sayfa kapağı (`scripts/kapak/`, 20 Ağustos 2026)

`marketing/sponsored-2026-08/kelimeki-fb-kapak.png` (1640×624).
`npm run generate-fb-cover`.

**⚠ Facebook kapağı İKİ FARKLI kırpılıyor** — masaüstünde geniş-alçak
(~820×312), telefonda dar-yüksek (~640×360) — ve masaüstünde profil fotoğrafı
SOL ALT köşeyi örtüyor. Tasarım bu yüzden "ortada güvenli kutu + kenarlarda
taşan dekor": okunması gereken her şey ortadaki 480 px'lik şeritte, iki yandaki
tahtalar bilerek kadraj dışına taşıyor. **Ölçüldü:** güvenli kutu x 170–650,
telefon kırpması x 90–730 → tamamen içeride. Betik bu kontrolü her çalıştırmada
tekrar ediyor, "sığdı" varsayılmıyor.

### Reel (`scripts/reel/`, 20 Ağustos 2026)

Instagram "trial reel" denemesi için 1080×1920 / 9.4 sn MP4
(`marketing/sponsored-2026-08/kelimeki-reel.mp4`). Video **ÜRETİM
UYGULAMASININ kendisi sürülerek** üretiliyor: Playwright kayıtlı bir oyun
ortasını açıyor, taşları raftan tahtaya sürüklüyor, OYNA'ya basıyor, YZ
cevabını veriyor.

- **Sahne elle yazılmadı, ÖLÇÜLDÜ.** `scripts/reel/senaryo.ts` üretim
  YZ'sini (`findAIMove`) tanıtım tahtasına karşı çağırıp oynanabilir
  hamleleri listeliyor; seçilen hamle (7. sütunda dikey **ARKADAŞ**, 50 puan)
  böylece sözlük/bitişiklik/puan açısından motorun kendisiyle garantili.
  Elle "şu kelimeyi şuraya koyayım" demek, çekim sırasında tahtanın kırmızıya
  dönmesiyle sonuçlanabilirdi.
- **⚠ `buildSnapshotGameState` `isGameOver: true` DÖNER** (bitmiş oyun
  önizlemeleri için yazıldı). Sahne onu `false`a çekmezse `loadGameState`
  kaydı "bitmiş" sayıp null dönüyor ve App ilk effect'te localStorage'ı
  SİLİYOR — ölçüldü: 4215 bayt yazılıyor, ~1 sn sonra null, Setup'ta
  "Devam Eden Oyun" satırı hiç çıkmıyor.
- **⚠ Kapanış kartı AYRI BİR CONTEXT'te render edilmeli.** Uygulamayı açan
  bağlamda PWA service worker'ı kayıtlı ve `navigateFallback` bilinmeyen her
  navigasyona `index.html` döndürüyor; ilk sürümde videonun son 2 saniyesi
  kapanış kartı yerine Setup ekranını gösterdi.
- **⚠ Sürükleme hedefi +30 px AŞAĞIDA** (`DRAG_LIFT`) — bu tuzak bu dokümanda
  zaten kayıtlı, betik onu telafi ediyor.
- **Taş SIRASI görsel bir karar:** yukarıdan aşağı dizmek ara adımlarda
  "ARKAD geçerli bir kelime değil" kırmızısını saniyelerce ekranda tutuyordu.
  Mevcut A'nın ALTINDAN başlayınca ara adımlar gerçek kelime oluyor
  (AD ✓ ADA ✓ ADAŞ ✓), doğrulama satırı hamlenin çoğunda yeşil kalıyor.
- **Kare kare (stop-motion) yakalanıyor, `recordVideo` DEĞİL:** o, videoyu
  viewport boyunda kaydedip büyütürken taş harflerini bulanıklaştırırdı;
  `page.screenshot` + `deviceScaleFactor: 2` gerçek 1080×1920 üretiyor.
  Kareler ffmpeg'in concat demuxer'ıyla, her karenin kendi süresiyle
  birleşiyor (bekleme = tek dosya + uzun süre).
- **Uygulama içeriği 540 px genişlikte 819 px sürüyor** (ölçüldü), kare ise
  9:16. Artan yer boş bırakılmıyor: altta kalıcı bir `kelimeki.com` şeridi
  bindiriliyor (`renderBantHtml`).
- **ffmpeg bu ortamda apt ile kuruldu** — Playwright'ın kendi ffmpeg'i
  (`/opt/pw-browsers/ffmpeg-1011`) yalnızca VP8/webm derlenmiş, H.264 yok.

