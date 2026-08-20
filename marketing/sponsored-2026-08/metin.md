# Sponsorlu gönderi — 6 gün × 433 TL/gün (≈ 2.598 TL)

**Hedef:** kelimeki.com'a trafik → üyelik → oyun.
**Görseller:** `kelimeki-01…05.png`, 1080×1080 (2× ölçek: 2160×2160), carousel sırası 1→5.
Kare oran hem LinkedIn hem Instagram/Facebook carousel'inde çalışır.

---

## 1 · Görsellerin kurgusu

| # | Kare | Görevi |
|---|---|---|
| 1 | Logo + "Kelime bul, bölgeni büyüt, tahtayı ele geçir." + rakamlar | Durdurucu: bu ne, kime |
| 2 | Gerçek 2 kişilik tahta + X2/X3 | Kanıt: ekran görüntüsü değil, oyunun kendisi |
| 3 | Dört adım (köşe → bölge → merkez → vergi) | **Asıl fark** — neden başka bir kelime oyunu değil |
| 4 | 4 kişilik tahta + YZ / canlı / sohbet | Kiminle oynanır (48 saat kuralı itirazı kapatıyor) |
| 5 | Dokuz k-lig rütbesi + "kelimeki.com — hemen oyna" | Üyelik sebebi + net çağrı |

Adres **her karenin altında** duruyor: carousel'de kullanıcı son kareye kadar
gitmeyebiliyor, 3. karede bırakan da adresi görmüş oluyor.

---

## 2 · Gönderi metni — LinkedIn

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

## 3 · Gönderi metni — Instagram / Facebook

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
> #kelimeoyunu #kelimeoyunları #türkçe #zekaoyunu #bulmaca #kelime #oyun #türkçeoyun #stratejioyunu #beyinjimnastiği #oyunönerisi #ücretsizoyun #bulmacaoyunu #mobiloyun #webgame

### Kısa varyant (A/B testi için)

> Bu bir kelime oyunu ama asıl soru şu: kelimeyi NEREYE koyacaksın? 🧩
>
> Köşenden başla, bölgeni büyüt, rakibinin alanına girmeyi göze al (vergisi var 😏).
> Ücretsiz, kurulum yok, tarayıcıda çalışıyor.
>
> 👉 kelimeki.com

---

## 4 · Reklam kurulumu — atlanırsa kampanya ölçülemez

**1) Hedef URL'de mutlaka `?ref=` kullan.**

```
https://kelimeki.com/?ref=meta
https://kelimeki.com/?ref=linkedin
```

Site kaynak etiketini **yalnızca `?ref=` parametresinden** okuyor
(`src/utils/visitTracking.ts` → `captureUtmSource`). Meta/LinkedIn'in
otomatik eklediği `utm_source=...` bu projede **hiçbir yere yazılmaz** —
`?ref=` yoksa ziyaretçi admin panelindeki huniye "direkt" olarak düşer ve
kampanyanın getirdiği trafiği ayırt edemezsin. (Platformun kendi utm
parametrelerini ayrıca eklemesi sorun değil, yeter ki `ref=` de olsun.)

**2) Kampanya hedefi:** Sitede kurulu bir Meta pixel'i / LinkedIn Insight Tag
**yok** (bilinçli: üçüncü taraf izleyici kullanılmıyor). Dolayısıyla platform
"üyelik" için optimize edemez. Hedefi **Trafik** seç ve optimizasyonu
**"Açılış sayfası görüntüleme"** yap — "Link tıklaması" tıklayıp sayfa
açılmadan çıkanları da sayıyor, aradaki fark bu bütçede ciddi.

**3) CTA butonu:** "Oyna" varsa o; yoksa "Daha fazla bilgi".
LinkedIn'de "Siteyi ziyaret et".

**4) Sonucu nereden okuyacaksın:** Admin paneli → **Büyüme › Kullanıcı ›
Kaynak Hunisi**. Kampanyadan sonra `meta` / `linkedin` satırı belirir ve
kaynak başına **Kişi → Üye → Oyun** üçlüsünü verir; zaman filtresi
(Son 7/30 gün) yukarıdaki kontrollerden geliyor.

**5) Bilinen ölçüm sınırı (rakamı okurken hatırla):** `?ref=` **ilk temasta**
saklanıyor. Siteye daha önce uğramış biri reklamdan gelirse eski etiketi
korunur, yani huni kampanyayı **eksik** sayar — asla fazla saymaz.

---

## 5 · Bütçe hakkında bir not

433 TL/gün'ü iki platforma bölmek yerine **tek platformda koşturmanı**
öneririm: 6 gün × ~216 TL'lik iki ayrı kampanya, her ikisinde de öğrenme
aşamasını tamamlamaya yetmeyen bir hacim üretir. Diğer platformda aynı
görselleri organik paylaş; hangisinin çalıştığını gördükten sonra bütçeyi
oraya kaydır.

**Geçen haftanın "kimse üye olmadı" gözlemi ölçülebilir:** paylaşımı
Setup/Tanıtım'daki "Paylaş" düğmesiyle yaptıysan link `?ref=arkadas`
taşıyordu ve o satır zaten Kaynak Hunisi'nde duruyor. Düz kopyalanmış bir
link kullandıysan trafik "direkt" satırında birikmiştir; o durumda gerçekten
"kimse gelmedi" mi yoksa "geldi ama etiketsiz mi" ayırt edilemez — bu
kampanyada `?ref=meta` bunu kalıcı olarak çözer.

---

## 6 · Görselleri yeniden üretmek

```bash
npm run build                          # derlenmiş CSS gerekli
node scripts/sponsored-post/build.mjs  # 5 PNG'yi yeniden yazar
```

Tahtalar, rütbeler ve logo **üretim bileşenlerinden** çiziliyor
(`Board`, `RankSeal`, `LandingLogo`, `PLAYER_COLORS`, `RANK_TIERS`) — palet,
rütbe tablosu ya da tanıtım tahtası değişirse görseller tek komutla takip
eder, elle güncellenmesi gereken ikinci bir kopya yok.
