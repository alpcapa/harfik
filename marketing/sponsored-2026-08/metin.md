# Sponsorlu gönderi — 6 gün × 433 TL/gün (≈ 2.598 TL)

**Platform:** Instagram (kullanıcı kararı, 20 Ağustos 2026 — tek platformda
koşturulacak).
**Hedef:** kelimeki.com'a trafik → üyelik → oyun.
**Görseller:** `kelimeki-01…05.png`, 1080×1080 (2× ölçek: 2160×2160), carousel sırası 1→5.

---

## 1 · Görsellerin kurgusu

| # | Kare | Görevi |
|---|---|---|
| 1 | Logo + "Kelime bul, bölgeni büyüt, tahtayı ele geçir." + sağ üstte 4 kişilik tahta + rakamlar | Durdurucu: bu ne, kime |
| 2 | Gerçek 2 kişilik tahta + X2/X3 | Kanıt: ekran görüntüsü değil, oyunun kendisi |
| 3 | Dört adım (köşe → bölge → merkez → vergi) | **Asıl fark** — neden başka bir kelime oyunu değil |
| 4 | 4 kişilik tahta + YZ / canlı / sohbet | Kiminle oynanır (48 saat kuralı itirazı kapatıyor) |
| 5 | Dokuz k-lig rütbesi + "kelimeki.com — hemen oyna" | Üyelik sebebi + net çağrı |

Adres **her karenin altında** duruyor: carousel'de kullanıcı son kareye kadar
gitmeyebiliyor, 3. karede bırakan da adresi görmüş oluyor.

---

## 2 · Gönderi metni — Instagram (kampanya metni)

> Kelime bul, bölgeni büyüt, tahtayı ele geçir 🧩
>
> 13×13'lük tahtanın dört köşesi oyuncuların. Kendi köşenden başlıyor, koyduğun her taşla bölgeni büyütüyorsun. Rakibin bölgesine oynayabilirsin — ama vergisini ödersin 😏
>
> 🔹 63.000+ kelime (TDK kaynaklı)
> 🔹 2 veya 4 kişi: yapay zekaya ya da arkadaşlarına karşı
> 🔹 Her hamle için 48 saat — aynı anda çevrimiçi olmak gerekmiyor
> 🔹 Ücretsiz · kurulum yok · reklam yok
>
> 👉 kelimeki.com
>
> #kelimeoyunu #zekaoyunu #bulmaca #türkçe #ücretsizoyun

**Neden bu beş:** Instagram'da hashtag artık erişimin küçük bir parçası;
konuyu tarif eden az sayıda alakalı etiket, uzun bir listeden daha temiz
görünüyor ve gönderiyi spam'e yakın göstermiyor. İlk satır feed'de kesilmeden
görünen tek satır — kanca orada.

### Kısa varyant (A/B testi için)

> Bu bir kelime oyunu ama asıl soru şu: kelimeyi NEREYE koyacaksın? 🧩
>
> Köşenden başla, bölgeni büyüt, rakibinin alanına girmeyi göze al (vergisi var 😏).
> Ücretsiz, kurulum yok, tarayıcıda çalışıyor.
>
> 👉 kelimeki.com
>
> #kelimeoyunu #zekaoyunu #bulmaca #türkçe #ücretsizoyun

---

## 3 · LinkedIn varyantı — KAMPANYA DIŞI, organik paylaşım için

> Türkçe kelime oyunlarında herkes aynı soruyu soruyor: "en yüksek puanlı kelime hangisi?"
>
> Kelimeki'de ikinci bir soru daha var: nereye koyacaksın?
>
> 13×13'lük tahtanın dört köşesi oyunculara ait. Herkes kendi köşesinden başlıyor ve koyduğu her taşla bölgesini büyütüyor. Rakibin bölgesine oynamak serbest — ama kazandığın puanın bir kısmı ona geçiyor. Yani hamleni seçerken yalnızca harflere değil, haritaya da bakıyorsun.
>
> • TDK kaynaklı 63.000+ kelimelik sözlük
> • 2 veya 4 kişilik; yapay zekaya ya da arkadaşlarına karşı
> • Canlı oyunda aynı anda çevrimiçi olmak şart değil — her hamle için 48 saat
> • Tarayıcıda çalışıyor: kurulum yok, reklam yok, ücretsiz
>
> Denemek istersen: kelimeki.com
>
> #KelimeOyunu #Türkçe #Oyun #WebOyunu #YanProje

**Neden böyle:** LinkedIn ilk ~2 satırdan sonrasını "…daha fazla" ile kesiyor,
o yüzden fark (nereye koyacaksın?) ilk iki satırda. 3–5 hashtag LinkedIn'de
optimum; fazlası erişimi düşürüyor.

---

## 4 · Reklam kurulumu — atlanırsa kampanya ölçülemez

**1) Hedef URL'de mutlaka `?ref=` kullan.**

```
https://kelimeki.com/?ref=instagram
```

Site kaynak etiketini **yalnızca `?ref=` parametresinden** okuyor
(`src/utils/visitTracking.ts` → `captureUtmSource`). Meta'nın
otomatik eklediği `utm_source=...` bu projede **hiçbir yere yazılmaz** —
`?ref=` yoksa ziyaretçi admin panelindeki huniye "direkt" olarak düşer ve
kampanyanın getirdiği trafiği ayırt edemezsin. (Platformun kendi utm
parametrelerini ayrıca eklemesi sorun değil, yeter ki `ref=` de olsun.)

**2) Kampanya hedefi:** Sitede kurulu bir Meta pixel'i **yok** (bilinçli: üçüncü taraf izleyici kullanılmıyor). Dolayısıyla platform
"üyelik" için optimize edemez. Hedefi **Trafik** seç ve optimizasyonu
**"Açılış sayfası görüntüleme"** yap — "Link tıklaması" tıklayıp sayfa
açılmadan çıkanları da sayıyor, aradaki fark bu bütçede ciddi.

**3) CTA butonu:** "Oyna" varsa o; yoksa "Daha fazla bilgi".

**4) Sonucu nereden okuyacaksın:** Admin paneli → **Büyüme › Kullanıcı ›
Kaynak Hunisi**. Kampanyadan sonra `instagram` satırı belirir ve
kaynak başına **Kişi → Üye → Oyun** üçlüsünü verir; zaman filtresi
(Son 7/30 gün) yukarıdaki kontrollerden geliyor.

**5) Bilinen ölçüm sınırı (rakamı okurken hatırla):** `?ref=` **ilk temasta**
saklanıyor. Siteye daha önce uğramış biri reklamdan gelirse eski etiketi
korunur, yani huni kampanyayı **eksik** sayar — asla fazla saymaz.

---

## 5 · Bütçe hakkında bir not

Bütçenin tamamı tek platformda (Instagram) koşuyor — bölünseydi 6 gün ×
~216 TL'lik iki kampanya, ikisinde de öğrenme aşamasını tamamlamaya
yetmeyen bir hacim üretirdi. LinkedIn'de aynı görselleri organik paylaş;
hangisinin çalıştığını gördükten sonra bütçeyi oraya kaydırabilirsin.

**Geçen haftanın "kimse üye olmadı" gözlemi ölçülebilir:** paylaşımı
Setup/Tanıtım'daki "Paylaş" düğmesiyle yaptıysan link `?ref=arkadas`
taşıyordu ve o satır zaten Kaynak Hunisi'nde duruyor. Düz kopyalanmış bir
link kullandıysan trafik "direkt" satırında birikmiştir; o durumda gerçekten
"kimse gelmedi" mi yoksa "geldi ama etiketsiz mi" ayırt edilemez — bu
kampanyada `?ref=instagram` bunu kalıcı olarak çözer.

---

## 6 · Trial reel — `kelimeki-reel.mp4`

**Dosya:** 1080×1920, 9.4 sn, H.264 + sessiz ses izi, ~450 KB.
**Üretimi:** `npm run build && npm run generate-reel`.

Video çizim ya da ekran kaydı DEĞİL: Playwright üretim uygulamasını gerçekten
sürüyor — kayıtlı bir oyun ortası açılıyor, taşlar raftan tahtaya
sürükleniyor, OYNA'ya basılıyor, yapay zeka cevabını veriyor. Yani ekranda
görünen her şey oyunun kendisi.

Akış: dolu tahta (kanca) → 6 taş sürüklenir → tahta yeşile döner, **+50**
rozeti çıkar → OYNA → skor 148'den 198'e → yapay zeka cevap verir → kapanış
kartı. Alt şeritte her karede `kelimeki.com` duruyor.

**Oynanan kelime ARKADAŞ ve bu tesadüf değil** — hem reklamın mesajıyla
örtüşüyor hem de hamlenin geçerliliği elle seçilmedi: `scripts/reel/senaryo.ts`
üretim yapay zekasını (`findAIMove`) çağırıp bu rafın en iyi hamlesini ölçtü.

### Reel açıklaması

> Kelime oyunu, ama asıl soru şu: NEREYE koyacaksın? 🧩
>
> Köşenden başla, bölgeni büyüt. Rakibin alanına girmek serbest — ama vergisini ödersin 😏
>
> Ücretsiz, kurulum yok. Link profilde 👆
>
> #kelimeoyunu #zekaoyunu #bulmaca #türkçe #ücretsizoyun

### Yayınlarken üç not

1. **Bio linkine AYRI etiket koy:** `https://kelimeki.com/?ref=ig-bio`.
   Reel organik, ücretli kampanya `?ref=instagram` kullanıyor; aynı etiketi
   paylaşırlarsa ikisi hunide tek satıra karışır ve hangisinin üye getirdiği
   ayırt edilemez. `?ref=` ilk temasta saklandığından bu ayrımı sonradan
   düzeltmek mümkün değil.
2. **Reel'de açıklamadaki link tıklanabilir değil** — dönüşüm yolu reel →
   profil → bio linki. Bio'da link yoksa video ne kadar izlenirse izlensin
   sıfır trafik üretir.
3. **Müziği Instagram'ın kendi düzenleyicisinde ekle.** Video sessiz (yalnızca
   uyumluluk için boş bir ses izi var); trend bir ses seçmek reels
   dağıtımında ölçülebilir fark yaratıyor.

---

## 7 · Görselleri yeniden üretmek

```bash
npm run build                          # derlenmiş CSS gerekli
node scripts/sponsored-post/build.mjs  # 5 PNG'yi yeniden yazar
```

Tahtalar, rütbeler ve logo **üretim bileşenlerinden** çiziliyor
(`Board`, `RankSeal`, `LandingLogo`, `PLAYER_COLORS`, `RANK_TIERS`) — palet,
rütbe tablosu ya da tanıtım tahtası değişirse görseller tek komutla takip
eder, elle güncellenmesi gereken ikinci bir kopya yok.
