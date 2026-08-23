# Google Play — mağaza vitrini (22–23 Ağustos 2026)

Bu dosya Play Console'a ELLE girilecek metinleri ve cihazdan alınacak ekran
görüntülerinin çekim listesini taşıyor. Görseller `node scripts/play-store/build.mjs`
ile üretilir (ekran görüntüleri HARİÇ — aşağı bkz.).

| Varlık | Dosya | Durum |
|---|---|---|
| Mağaza ikonu 512×512 | `store-icon-512.png` | ✅ üretildi |
| Öne çıkan görsel 1024×500 | `feature-graphic.png` | ✅ üretildi |
| Telefon ekran görüntüleri (2–8) | — | ⬜ **cihazdan alınacak** |

---

## Uygulama adı (≤30 karakter)

```
Kelimeki: Türkçe Kelime Oyunu
```
29 karakter (ölçüldü).

## Kısa açıklama (≤80 karakter)

```
Kelime kur, bölgeni büyüt, tahtayı ele geçir. Yapay zekaya ve arkadaşına karşı.
```
79 karakter (ölçüldü).

## Tam açıklama (≤4000 karakter)

```
Kelimeki, Türkçe için sıfırdan tasarlanmış bir kelime oyunu. Klasik kelime
oyunlarından farkı tek bir kuralda: tahtada bir bölgen var ve oyun, kelime
kurarak o bölgeyi büyütmek üzerine kurulu.

13×13'lük tahtada her oyuncu bir köşeden başlar. Kurduğun her kelime bölgeni
biraz daha genişletir; rakibinin bölgesine girersen puanın bir kısmı ona
gider — "bölge vergisi". Yani her hamlede iki soru var: kaç puan alıyorum ve
tahtanın neresini elimde tutuyorum?

NASIL OYNANIR
• Kendi köşendeki başlangıç karesinden başla, kelimelerle merkeze doğru ilerle.
• Ortadaki bölgeye taş koyarsan kelimenin puanı ikiye, tam merkezde üçe katlanır.
• Rakibin bölgesine değen ya da giren hamlelerde puanın bir kısmı ona aktarılır.
• Rafındaki yedi taşın hepsini tek hamlede kullanırsan bingo bonusu kazanırsın.
• Torba ve raflar bittiğinde oyun biter; elinde kalan taşlar puanından düşülür.

İKİ OYUN MODU
• Yapay zekaya karşı: 2 veya 4 kişilik, anında başlar. İnternet bağlantısı
  gerekmez — sözlük uygulamanın içinde.
• Arkadaşınla canlı: arkadaşını davet et, sırayla oyna. Sıra sana geçtiğinde
  haberin olur; hamle için 48 saatin var, oyun ekranından yazışabilirsin.

SÖZLÜK
TDK sözlüğüne dayalı, 63 binden fazla kelimelik bir liste (bulmacalarda sık
geçen birkaç madde ayrıca eklendi). Tahtadaki bir kelimeye dokunarak anlamına
bakabilirsin.

k-lig
Oynadığın her oyun k-lig puanına işler. Puan biriktikçe rütben yükselir:
Çaylak'tan başlayıp Meraklı, Oyuncu, Usta, Şampiyon, Destan, Efsane, Uzaylı ve
en tepede Kozmik. Belirli eşikleri geçtiğinde ek puan ödülü kazanırsın.
Sıralamayı, istatistiklerini ve geçmiş oyunlarının tahtalarını skor kartından
görebilirsin.

ÜCRETSİZ VE REKLAMSIZ
Kelimeki tamamen ücretsiz. Reklam yok, uygulama içi satın alma yok.
Hesap açmadan da yapay zekaya karşı oynayabilirsin; hesap yalnızca canlı
oyun, k-lig ve oyun geçmişi için gerekiyor.

Tarayıcıdan oynamak istersen: kelimeki.com
```

**Uzunluk kontrolü:** `python3 - <<'P'` ile ölç (aşağıdaki komut) — Play 4000
karakterde kesiyor ve kesilen metin sessizce kayboluyor.

---

## Ekran görüntüleri — GERÇEK CİHAZDAN

**Neden emülatör/Appetize/web değil:** Play'e giden görüntülerin uygulamanın
gerçek görüntüsü olması gerekiyor; farklı bir yüzeyden alınan görsel
"yanıltıcı ekran görüntüsü" olarak değerlendirilebilir. Appetize ve Flutter
web derlemesi aynı Dart kodunu koşturuyor ama gerçek Android çerçevesi değil.

**Uygulamayı cihaza kur:** en son test derlemesi `mobile-latest`
prerelease'inde — `https://github.com/alpcapa/kelimeki/releases/download/mobile-latest/kelimeki.apk`
(Chrome'dan indir, "bilinmeyen kaynak" iznini ver). Bu `.apk`, Play'e
yüklenecek `.aab` ile AYNI koddan derleniyor.

### Teknik gereksinim
- 2–8 adet, PNG veya JPEG, alfa YOK.
- Her kenar 320–3840 px, en/boy oranı 16:9 ile 9:16 arasında.
- Telefonun kendi ekran görüntüsü (genelde 1080×2400) bu aralıkta — **kırpma
  yapma**, olduğu gibi yükle.

### ⚠ Çekmeden ÖNCE — gizlilik
Bu görseller HERKESE AÇIK yayınlanıyor ve sonradan silinse de indirilmiş
olabilir. Bu yüzden:
- **Gerçek arkadaşlarının adı/avatarı görünmesin** — canlı oyun ve arkadaş
  listesi ekranlarını test hesaplarıyla (T1/T2 gibi) çek.
- E-posta adresi geçen hiçbir ekranı çekme (Hesap Ayarları).
- Sohbet ekranında gerçek yazışma olmasın; test mesajı yaz.
- Bildirim çubuğunu temizle (bildirim yok, pil/şebeke dolu).

### Çekim listesi (ilk üçü en önemlisi — listede önce onlar görünüyor)
1. **Oyun ekranı, oyunun ortası.** Tahta dolu, bölge dış hatları ve renkler
   net görünsün, raf dolu olsun. Asıl mekaniği anlatan tek kare bu.
2. **Geçerli bir hamle kurulmuşken.** Taşlar konmuş, doğrulama yeşil, puan
   rozeti görünür — "nasıl oynanıyor" sorusunu cevaplıyor.
3. **Kurulum ekranı, "Arkadaşınla" sekmesi.** İki oyun modunun varlığını
   gösteriyor.
4. **Skor kartı** — rütbe mührü, k-lig puanı ve istatistik kutuları.
5. **k-lig sıralaması.**
6. **Kelime anlamı penceresi** (tahtadaki bir kelimeye dokununca) ya da
   **Nasıl oynanır** ekranı.

4 kare yeterli; 6 daha iyi. Aynı oyundan iki benzer kare koymak yerine farklı
ekranlar seç.

### Çekim sonrası
Dosyaları bana gönder — boyut/oran/alfa kontrolünü ölçerim, Play'in
reddedeceği bir şey varsa yüklemeden önce görürüz.
