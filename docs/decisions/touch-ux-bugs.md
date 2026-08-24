# Dokunmatik/Hover Hata Sınıfları — Karar Kaydı

> docs/decisions/'e taşındı (context split, 24 Ağustos 2026). Kaynak: 'Jest Sınıfı Denetimi' + 'Dokunmatikte Yapışkan Hover' bölümleri.

## Jest Sınıfı Denetimi — dokunmatiğe özgü iki hata (22 Ağustos 2026)

Bir kullanıcının joker raporundan sonra kullanıcı sordu: *"Buna benzer başka
sorunlar olabilir mi?"* — jest yüzeylerinin tamamı iki platformda tarandı.
İki hata sınıfı çıktı; ikisi de MASAÜSTÜNDE GÖRÜNMÜYOR, yani duman testleri
(hepsi masaüstü profilinde koşuyor) bunları yapısal olarak göremiyordu.

### Sınıf 1 — jestin İÇİNDE değişen ekran, o jestin click'ini yiyor

Mekanizma ve joker vakası: "Joker (`?`)" bölümü. Mekanizma
**`src/utils/ghostClick.ts`** (`swallowNextClick()`) — modül düzeyinde tek
bayrak + tek capture dinleyicisi (aynı anda yalnızca BİR jest yaşar).
Denetimde aynı sınıfın **iki örneği daha** bulundu ve düzeltildi:

| Yer | Ne oluyordu |
|---|---|
| `Leaderboard` — OHP balonu | Balonu kapatmak için dışarı dokunmak, aynı jestin click'iyle ALTTAKİ k-lig satırını da açıyordu (o oyuncunun kartı) |
| `UserMenu` — hesap menüsü | Menüyü kapatmak için tahtaya dokunmak menüyü kapatıp AYNI dokunuşla taş yerleştiriyordu |

İkisi de platform normuna aykırıydı: bir popover'ı kapatan dokunuş
arkadakini çalıştırmaz. **Bu ikisi masaüstünde de yaşanıyordu** (fare
click'i de aynı jestin parçası), yani düzeltme dokunmatiğe özgü değil.

**Kalan sınır (bilinçli, kayda geçsin):** `swallowNextClick()` yalnızca
CLICK'i yutar. Hesap menüsü açıkken tahtadaki BU TURDA KONMUŞ bir taşa
dokunulursa o taş yine geri alınır — çünkü o eylem click'e değil `pointerup`a
bağlı (bkz. `Board`un `hasPending` dalı). Tam kapatmanın yolu menüye tam
ekran görünmez bir zemin (backdrop) koymak; yapılmadı, çünkü `UserMenu` bu
ortamda HİÇ render edilemiyor (Supabase yapılandırılmadan `null` dönüyor) ve
test edilemeyen bir yapısal değişiklik, tek satırlık kazanca göre orantısız
risk. Dar bir uç durum ve sonucu geri alınabilir (taş rafa döner).

**Temiz çıkanlar (ölçüldü/okundu, bir sonraki denetim tekrar aramasın):**
`GrowthChart`in tooltip'i `pointer-events-none` ve kabında `onClick` yok;
karşılama katmanının `main.tsx`teki dört düğme bağlaması `click` tabanlı
(click jestin SON olayı, ardından hayalet gelmez); geri kalan ~15 modalın
hepsi `onClick` ile açılıyor. Flutter portunda bu sınıf **yapısal olarak
yok** — orada dokunuş Flutter'ın kendi hit-test'inden geçiyor, compat mouse
olayı diye bir şey yok.

### Sınıf 2 — fareye göre ayarlanmış bir sabitin parmağa uygulanması

`DRAG_THRESHOLD` tek bir sayıydı (**6 px**) ve parmak için fazla dardı:
hafif titreyen bir dokunuş "sürükleme" sayılıp aynı hücrede bittiğinden
**hiçbir şey yapmıyordu**. Yanlış bir şey değil, *hiçbir şey* — kullanıcıya
"dokunuşum işlemedi" olarak görünen sessiz bir kayıp (bu kod tabanında daha
önce "ikona 4-5 kere dokunmam gerekti" diye bildirilen sınıfın kardeşi).

**ÖLÇÜLDÜ** (Chromium, `hasTouch`+`isMobile`, 390×844, CDP ham dokunuş
olaylarıyla; `tap()` hiç hareket üretmediğinden eşik ancak böyle ölçülüyor):

| Titreşim | Raf taşı seçimi | Konmuş taşı geri alma | Joker penceresi |
|---|---|---|---|
| 0–4 px | ✅ | ✅ | ✅ |
| 6 px ve üstü | ❌ | ❌ | ❌ |

Platform normları 6'nın ÜSTÜNDE: Android/Chrome touch slop **8 px**, iOS
~10 pt, Flutter `kTouchSlop` **18**. Yani Android'in kendisinin hâlâ
"dokunuş" saydığı bir jesti bu kod sürükleme sayıyordu.

**Bunu sinsi yapan asimetri:** taşı KOYMAK `onClick` yolundan gidiyor
(eşikten etkilenmez), geri almak/jokeri düzenlemek sürükleme yolundan —
yani kullanıcı "koyabiliyorum ama geri alamıyorum" yaşıyordu. Swap modunda
seçim de `onClick` olduğundan, normal modda seçilmeyen taş swap modunda
seçilebiliyordu.

**Düzeltme:** eşik pointer TÜRÜNE bağlandı — `DRAG_THRESHOLD_MOUSE = 6`
(fare, DEĞİŞMEDİ: imleç titremez), `DRAG_THRESHOLD_TOUCH = 10`. Ölçülen yeni
davranış: 9 px'e kadar dokunuş, 12 px'te sürükleme; gerçek sürükleme
(raftan tahtaya) etkilenmedi.

**DÖRT dosyada birden yaşıyor** — `App.tsx`, `OnlineGameScreen.tsx` ve
portun iki oyun ekranı (`game_screen.dart`, `online_game_screen.dart`;
orada `PointerDeviceKind.mouse` ayrımıyla). Biri unutulursa iki ekran ya da
iki platform sessizce ayrışır: **`mobile/app/test/layout_parity_test.dart`
dördünü birden kilitliyor** — hem sayıları hem eşiğin pointer türüne bağlı
seçildiğini (sabit doğru olup kullanılmazsa değeri yok).

### Regresyon — duman testleri artık dokunmatik bir bağlam da taşıyor

`tests/smoke.spec.ts` 22 → **24 test**, `dokunmatik jestler` describe'ı
altında (`test.use({ hasTouch, isMobile })`). Fikstür rastgele DEĞİL: raf
`['?','M','A','R','T','I','K']` olarak sabitleniyor — ilk sürüm torbadan
rastgele çekiyordu ve aranan harf bazı koşularda hiç gelmiyordu (gerçek bir
flake, ölçüldü). **Negatif eş, ikisi de ayrı ayrı:** joker dalındaki
`swallowNextClick()` kaldırılınca ve eşik 6'ya döndürülünce ilgili testler
GERÇEKTEN düşüyor.

### Denetimde bulunan ama DÜZELTİLMEYEN — gerekçeleriyle

- **Alt şeridin dokunma hedefleri 18 px yüksekliğinde** ("Hamleler",
  "Mesajlaşma", "Nasıl Oynanır?") — WCAG 2.2'nin 24×24 asgarisinin altında.
  ÖLÇÜLDÜ (390 px): 78.8×18 ve 125.8×18; şeridin üstünde 14 px, altında
  62 px boşluk var, yani web'de `py-1.5 -my-1.5` ile düzen HİÇ değişmeden
  30 px'e çıkarılabilir. **Yapılmadı çünkü portta bedeli farklı:** Flutter'da
  negatif margin yok, `Padding` şeridi gerçekten 12 px büyütür ve tahta
  kartının yüksekliği ölçülmüş/dokümante bir değer — iki platformu ayrıştırmadan
  düzeltmek ayrı bir düzen turu istiyor. Hedefler GENİŞ olduğundan (1418 ve
  2264 px²) pratik ıskalama riski, bildirilen 12×12'lik ikon vakasından
  (144 px²) çok düşük.
- **`title="…"` balonları dokunmatikte hiç görünmüyor** — denetimde 39
  eşleşmenin çoğu `ConfirmDialog`/`Section` PROP'u çıktı; gerçek HTML
  `title` yalnızca 4 yerde (FriendsModal'ın "arkadaşlıktan çıkar" ikonu,
  ChatSettingsModal'ın 🚫/🚩 rozetleri, admin "Sil"). Dördünde de `aria-label`
  var ve dokunuş zaten ne olacağını YAZAN bir onay diyaloğu açıyor, yani
  anlam dokunmatikte de erişilebilir. Değişiklik gerekmedi.

**Doğrulama sınırı:** `Leaderboard`/`UserMenu` düzeltmeleri otomatik test
EDİLEMEDİ — ikisi de oturum açmış bir kullanıcı + yapılandırılmış Supabase
istiyor, dev sunucusunda ulaşılamıyor (`TESTING.md` bölüm 16'ya elle
maddeler eklendi). Oyun ekranlarının ikisi de duman testleriyle kapalı.

## Dokunmatikte "Yapışkan Hover" (11 Ağustos 2026)

Kullanıcı, Setup'ın en altındaki **"Kullanım Koşulları"** linkinin altında,
modal kapandıktan sonra da duran bir alt çizgi kaldığını bildirdi (iPad).

Sebep bu linke özgü değil: dokunmatik cihazlarda tarayıcı, bir öğeye
dokunulduğunda `:hover`'ı üzerine yapıştırıp **ekranın başka bir yerine
dokunulana kadar** orada bırakıyor. `hover:underline` da bu yüzden kalıcı
bir çizgiye dönüşüyordu. Chromium'da `hasTouch` bağlamıyla birebir üretildi:
dokunmadan önce `none` → dokununca `underline` → 300 ms sonra hâlâ
`underline` → başka yere dokununca `none`.

**Düzeltme tek link yamamak DEĞİL** — projede 38 `hover:` yardımcısı var
(16'sı `hover:underline`) ve hepsi aynı davranışı üretiyor.
`tailwind.config.js`'e `future: { hoverOnlyWhenSupported: true }` eklendi:
Tailwind her `hover:` kuralını `@media (hover:hover) and (pointer:fine)`
içine alıyor, yani fareli cihazlarda davranış **birebir aynı** kalırken
dokunmatikte hover stili hiç uygulanmıyor. (Tailwind v4'te bu zaten
varsayılan; v3.4'te bayrakla açılıyor.) İkisi de ölçülerek doğrulandı —
dokunmatikte dokunuş sonrası `none`, masaüstünde hover'da `underline`.

**Yeni bir `hover:` sınıfı eklerken artık ekstra bir şey yapmaya gerek yok**,
bayrak proje geneline uygulanıyor. `active:` durumları bundan etkilenmez
(anlık, dokunuş bırakılınca kalkıyor).

