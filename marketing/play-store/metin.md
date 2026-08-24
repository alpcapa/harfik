# Google Play — mağaza vitrini (22–23 Ağustos 2026)

Bu dosya Play Console'a ELLE girilecek metinleri ve cihazdan alınacak ekran
görüntülerinin çekim listesini taşıyor. Görseller `node scripts/play-store/build.mjs`
ile üretilir (ekran görüntüleri HARİÇ — aşağı bkz.).

| Varlık | Dosya | Durum |
|---|---|---|
| Mağaza ikonu 512×512 | `store-icon-512.png` | ✅ üretildi |
| Öne çıkan görsel 1024×500 | `feature-graphic.png` | ✅ üretildi |
| Telefon ekran görüntüleri (7) | kullanıcıda | ✅ cihazdan alındı, 1080×2072'ye kırpıldı (23 Ağu 2026) |

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
- Her kenar 320–3840 px.
- **En/boy oranı 2:1'i AŞAMAZ.** Bu satır 24 Ağustos 2026'ya kadar *"16:9 ile
  9:16 arasında; telefonun 1080×2400'ü bu aralıkta — kırpma yapma"* diyordu.
  **İkisi de yanlıştı ve birbiriyle çelişiyordu:** 1080×2400 = **1:2.22**,
  yani 16:9'un (1:1.78) de 2:1'in de dışında. Modern telefonların ham
  ekran görüntüsü Play'e OLDUĞU GİBİ yüklenemez.
- **Bu yüzden kırpmak ZORUNLU** — ve zaten öyle yapıldı: 23 Ağustos'ta
  cihazdan alınan 7 kare `1080×2400` idi, üst durum çubuğu ve alt gezinme
  çubuğu kırpılarak **`1080×2072` (1:1.92)** hâline getirildi. Yeni kare
  çekilirse aynı işlem gerekir; oranı önce ölç, sonra yükle.
- Ölçmek için:
  `python3 -c "import struct;f=open('X.png','rb');f.read(16);w,h=struct.unpack('>II',f.read(8));print(w,h,round(h/w,2))"`

### ⚠ Çekmeden ÖNCE — gizlilik
Bu görseller HERKESE AÇIK yayınlanıyor ve sonradan silinse de indirilmiş
olabilir. Bu yüzden:
- **Gerçek arkadaşlarının adı/avatarı görünmesin** — canlı oyun ve arkadaş
  listesi ekranlarını test hesaplarıyla (T1/T2 gibi) çek.
- E-posta adresi geçen hiçbir ekranı çekme (Hesap Ayarları).
- Sohbet ekranında gerçek yazışma olmasın; test mesajı yaz.
- Bildirim çubuğunu temizle (bildirim yok, pil/şebeke dolu).

### Çekim listesi — tek tek

Play en fazla 8 kabul ediyor; **4 yeterli, 6 ideal.** İlk 2-3 kare arama
sonuçlarında ve listenin başında görünen karelerdir — en iyi olanları başa koy.
Aşağıdaki sıra, listede görünecek sıradır.

---

**1 — Oyun ekranı, oyunun ortası** *(en önemli kare)*

Nasıl: Setup → "Yapay Zeka ile" → 2 Kişilik → OYUNU BAŞLAT → **en az 8-10
hamle oyna** (ya da devam eden bir oyunu aç). Zaten yarıda kalmış bir oyunun
varsa onu kullan, daha hızlı.

Karede görünmeli: tahtanın en az yarısı dolu · en az iki oyuncunun renkli
bölge dış hatları · raf dolu · üstteki skor kutuları.

Neden: oyunun asıl mekaniği (bölge büyütme) yalnızca bu karede anlaşılıyor.

---

**2 — Geçerli bir hamle kurulmuşken**

Nasıl: aynı oyunda raftan tahtaya birkaç taş koy, **OYNA'ya basma.**

Karede görünmeli: konmuş taşların **yeşil** doğrulama dış hattı · yanındaki
puan rozeti · alttaki OYNA düğmesi etkin.

Neden: "bu oyun nasıl oynanıyor" sorusunu tek karede cevaplıyor.

---

**3 — Kurulum ekranı, "Arkadaşınla" sekmesi**

Nasıl: oyun ekranında logonun altındaki **"← Geri"** → "OYUN TİPİ" altında
**"Arkadaşınla"** sekmesine dokun.

Karede görünmeli: iki sekme (Yapay Zeka ile / Arkadaşınla) · "Devam Edenler"
listesinde en az bir oyun.

⚠ **Test hesabıyla çek** (T1/T2). Gerçek arkadaşlarının adı/avatarı bu karede
görünmemeli — görseller herkese açık yayınlanıyor.

Neden: iki oyun modunun varlığını gösteren tek kare.

---

**4 — Skor kartı**

Nasıl: sağ üstteki avatar → **"Skor Kartı"**.

Karede görünmeli: başlıktaki **rütbe mührü** · k-lig puanı · istatistik
kutuları (Toplam Oyun, Birincilik, En Yüksek Oyun Puanı…).

Neden: uzun vadeli ilerleme/rütbe sistemini gösteriyor.

---

**5 — Kelime anlamı**

Nasıl: oyun ekranında tahtadaki bir kelimeye dokun.

Karede görünmeli: kelime + TDK anlamı penceresi, arkada tahta.

Neden: rakiplerinden ayrıştığın yer — sözlük uygulamanın içinde.

---

**6 — Nasıl Oynanır (kurallar)**

Nasıl: oyun ekranının alt şeridinde **"Nasıl Oynanır?"** → "Hızlı Başlangıç".

Karede görünmeli: kural maddeleri (bölge, X2/X3, bingo).

Neden: oyunun öğrenilebilir olduğunu gösteriyor.

---

**İSTEĞE BAĞLI 7 — k-lig sıralaması** (avatar → "k-lig Sıralama")

⚠ **Bu karede GERÇEK kullanıcıların takma adları görünür.** Uygulama içinde
zaten girişli herkese açıklar, ama mağaza vitrini çok daha geniş bir yayın.
Çekeceksen bunu bilerek çek; istemiyorsan 4. kare (kendi skor kartın) zaten
aynı mesajı veriyor.

---

### Çekmemen gerekenler

- **Hesap Ayarları** — e-posta adresi görünür.
- **Arkadaşlar listesi / arkadaş arama** — gerçek isimler.
- **Gerçek yazışma içeren Mesajlaşma ekranı** — çekeceksen test mesajı yaz.
- **Admin paneli** — mağaza vitrininde işi yok.

### Nasıl çekilir

- Android'de **Güç + Ses Kısma** tuşlarına birlikte bas.
- **Kırpma, düzenleme, çerçeve ekleme YOK** — telefonun ürettiği dosyayı
  olduğu gibi gönder (genelde 1080×2400, Play'in istediği aralıkta).
- Her karede önce **bildirim çubuğunu temizle** (bildirim yok, pil/şebeke dolu).

### Çekim sonrası
Dosyaları bana gönder — boyut/oran/alfa kontrolünü ölçerim, Play'in
reddedeceği bir şey varsa yüklemeden önce görürüz.
