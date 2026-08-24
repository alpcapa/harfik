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

### Eşiği 10'dan indirme denemesi — 8 ELENDİ (24 Ağustos 2026)

Kullanıcı cihazda *"oyun sırasında taş sürükleme de daha yavaş gibi"* dedi.
Sürükleme yolunda başka hiçbir şey değişmemişti (Parça 23'ün `_dragNotifier`
optimizasyonu yerinde, `setState` yalnızca sürüklemenin başında/sonunda), yani
tek aday yukarıdaki 6 → 10 değişikliğiydi: taşın kalkması için parmağın 4 px
daha oynaması gerekiyor.

"Android'in kendi touch slop'u 8" diye eşiği **8**'e indirmek önerildi ve
**yanlış çıktı** — kod yazılmadan, mevcut kilit okunarak yakalandı:

- Karşılaştırma `dist < eşik` (`App.tsx:1330`, `game_screen.dart:434`), yani
  eşik **dahil değil**.
- `smoke.spec.ts`'teki `JITTER = 8` testi tam 8 px'lik titreşimli bir
  dokunuşun hâlâ **dokunuş** sayılmasını kilitliyor.
- Eşik 10 → `8 < 10` → dokunuş ✅ · Eşik 8 → `8 < 8` yanlış → **sürükleme** ❌

Yani bu semantikte "8" yazmak Android'den **daha katı** olur ve yukarıdaki
sessiz kaybı geri getirir. 8 px toleransı korunacaksa eşik en fazla 9'a
inebilir — bugünkü 10'a göre kazanç **1 px**, yani anlamsız.

**Sonuç: "sayıyı düşürmek" diye bir seçenek yok.** Tolerans (8 px titreşim
dokunuş kalmalı) ile tepki hızı doğrudan çakışıyor. İkisini birden veren tek
tasarım, bugün tek bir `d.moved` bayrağının yaptığı **iki işi ayırmak**:
hayaletin belirmesi (erken, ~6) ile dokunuş/sürükleme KARARI (geç, 10) ayrı
eşiklere bağlanır. Bedeli: 6–10 bandında taş görünür şekilde kalkıp geri
oturur (eylem kaybolmaz, ama yeni bir görsel kıpırtı) — bandı hayaletsiz
bırakmak mümkün DEĞİL, çünkü orada parmak hâlâ aynı hücrenin üstünde ve
"bırakma" saymak taşı hiçbir yere koymaz.

**Karar: eşik 10'da BIRAKILDI** (kullanıcı kararı). Ayrım yapılmadı; gerçek
neden muhtemelen eşik değil, hayalet taşın hedef hücrenin iki katı olması —
o madde `docs/decisions/product-backlog.md`'de. Bir sonraki oturum "8 yapalım"
diye başlamasın diye bu bölüm burada.

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
  30 px'e çıkarılabilir. **O gün yapılmadı çünkü portta bedeli farklı
  sanıldı:** Flutter'da negatif margin yok, `Padding` şeridi gerçekten
  12 px büyütür ve tahta kartının yüksekliği ölçülmüş/dokümante bir değer.
  Hedefler GENİŞ olduğundan (1418 ve 2264 px²) pratik ıskalama riski
  düşük görüldü.
  **⚠ BU GEREKÇE İKİ GÜN SONRA ÇÜRÜDÜ — bkz. bir alttaki bölüm:** kullanıcı
  cihazda tam olarak bu üç linke "kaç defa basmam gerekti" dedi, ve
  "`Padding` şeridi 12 px büyütür" varsayımı da yanlıştı (dolgu EKLENMİYOR,
  kaptan öğelere TAŞINIYOR — dış ölçü değişmiyor).
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

## Alt şerit dokunma hedefleri: 18 → 32 px (24 Ağustos 2026)

Kullanıcı cihazda bildirdi (sözleriyle): *"board altındaki hamleler,
mesajlar ve nasıl oynanır linkleri tıklayınca hemen açılmıyorlar. Kaç defa
basmam gerekti."* — yani 22 Ağustos denetiminin "pratik ıskalama riski çok
düşük" yargısı GERÇEK KULLANIMDA ÇÜRÜDÜ. Bulgu zaten ölçülmüş ve yazılıydı;
eksik olan teşhis değil KARARDI.

**Ertelemenin gerekçesi de yanlıştı ve asıl çözüm oradan çıktı.** Not
"Flutter'da negatif margin yok, `Padding` şeridi gerçekten 12 px büyütür"
diyordu — bu, dolgunun EKLENECEĞİNİ varsayıyor. Oysa dolgu zaten var, sadece
YANLIŞ YERDE: kabın üzerinde. Kaptan alınıp her ÖĞEYE taşınınca şeridin dış
ölçüsü (4 + 18 + 10 = **32**) hiç değişmiyor — çünkü satırın boyunu artık en
uzun çocuk belirliyor — ama hedefler 18 → 32'ye çıkıyor. Negatif margin
GEREKMİYOR, yani iki platform da AYNI çözümü kullanabiliyor ve "ayrı bir
düzen turu" da gerekmiyor.

| | web (`Board.tsx`) | port (`board_widget.dart`) |
|---|---|---|
| Kap — ÖNCE | `px-[10px] pb-[10px] pt-1` | `fromLTRB(10, 4, 10, 10)` |
| Kap — SONRA | `px-[10px]` | `symmetric(horizontal: 10)` |
| Her öğe | `pt-1 pb-[10px]` | `_footerItemPadding` = `only(top: 4, bottom: 10)` |

**BEŞ öğenin de taşıması ŞART** (Hamleler · ayraç `·` · Mesajlaşma ·
Çevrimdışı · Nasıl Oynanır?). Yalnızca dokunulabilirler büyürse ayraç ve
"Çevrimdışı" 32 px'lik satırda ortalanır ve dolgu asimetrik olduğundan
(4/10) ~3 px kayarlar. Ayraç ve "Çevrimdışı" kendi asimetrik yatay
değerlerini koruyor (`fromLTRB(6, 4, 6, 10)` / `fromLTRB(0, 4, 8, 10)`).

**Rozet METİN kutusuna çapalı KALMALI.** Sohbet rozeti `-top-1 -right-1` ile
konumlu ve o konum web'de ölçülerek seçilmişti. Dolgulu kutuya çapalanırsa
4 px aşağı kayar. Web'de `relative` iç bir `<span>`e taşındı; portta
`Padding` zaten `Stack`in DIŞINDA. Ölçüldü: rozetin şeride göre konumu
ÖNCE de SONRA da aynı (`top = 0`) — yani hiç oynamadı.

**ÖLÇÜLDÜ** (derlenmiş `dist/assets/*.css` + Chromium, DPR 2,
`document.fonts.ready`, `http://` üzerinden; sınıf dizeleri `Board.tsx`'ten
OKUNARAK — kopyalanmadı, sapma imkânsız), 320/360/390/834/1194:

| 390 px, çevrimiçi | ÖNCE | SONRA |
|---|---|---|
| Hamleler | 78.77 × **18** = 1418 px² | 78.77 × **32** = 2521 px² |
| Mesajlaşma | 94.45 × **18** = 1700 px² | 94.45 × **32** = 3022 px² |
| Nasıl Oynanır? | 125.83 × **18** = 2265 px² | 125.83 × **32** = 4027 px² |
| Şerit yüksekliği | 32 | **32** (DEĞİŞMEDİ) |
| Yatay taşma | 0 | 0 |

ÖNCE ölçümündeki 1418/2265 px², 22 Ağustos denetiminin kayda geçirdiği
sayılarla BİREBİR aynı — harness'in üretimi sadık temsil ettiğinin kanıtı.

**Bilinen ve kabul edilen bedel:** çevrimdışı göstergesi görünürken ≤390 px'te
sağ grup ZATEN sarıyordu (web'de `flex-wrap`); o sarmalı durumda şerit
58 → **72** px oluyor (+14). Sarma yeni değil, yalnızca sarmalı satırın boyu
büyüdü; çevrimiçi durumda (kullanıcıların ezici çoğunluğu) şerit 32'de sabit.
Portta `flex-wrap` karşılığı yok — bu, önceden de var olan bir ayrışma,
bu turda DOKUNULMADI.

**Regresyon kilidi:** `mobile/app/test/layout_parity_test.dart` → *"alt şerit:
dikey dolgu KABINDA değil BEŞ öğenin de üzerinde"*. Kabın yalnızca yatay
dolgu taşıdığını, `_footerItemPadding`in 4/10 olduğunu, İKİ tarafta da tam
**5** öğenin dikey dolgu taşıdığını ve rozetin çapasını ölçüyor. **Negatif eş
ikisi de ayrı ayrı:** web düzeltmesi geri alınınca kap eşleşmesi ve rozet
çapası kayboluyor + `pt-1 pb-[10px]` sayısı 5 → 0; portta dolgu kaba geri
konunca kap eşleşmesi kayboluyor + 4/10 sayısı 5 → 3. Dördü de testi
GERÇEKTEN düşürüyor.

**44 px'lik iOS asgarisi burada yine UYGULANMADI** — `RelationIcons`'takinin
aksine bu satır ~13 px yüksekliğinde ve 44 px'lik bir alan hem kardeş
kontrolleri hem kartın kendi dokunuşunu yutardı; çıta WCAG 2.2'nin 24'ünün
üstünde, şeridin kendi boyunda (32).

**Doğrulama sınırı:** bu ortamda Flutter/Dart SDK YOK (`which flutter dart`
boş), yani `flutter analyze`/`flutter test` KOŞULAMADI — Dart yarısının
kanıtı CI. `board_widget.dart` parantez/ayraç dengesi elle taranarak
doğrulandı (0/0/0) ve parite testinin regex'lerinin gerçek kaynaklara
uyduğu Node'da (JS ≈ Dart regex semantiği) tek tek sınandı. Web tarafı
temiz: `npm run lint`, `npm run build`, `verify-*` betikleri ve Playwright
**29/29**.

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


## Dokunma Hedefi Asgarisi: 48 dp (24 Ağustos 2026 — ikinci tur)

Bir gün önceki düzeltme (yukarıdaki "18 → 32" notu) yetmedi. Kullanıcı
cihazda **beş** kontrolü de aynı cümleyle bildirdi: *"biraz üstüne basınca
çalışıyor"* — alt şeridin üç linki, "Detaylı Kurallar", "← Geri", avatar.

**Neden yetmediği, dersin tamamı sayıda:** ilk tur dolguyu kaptan öğelere
taşıdı ama **ekrandaki kutu hiç ÖLÇÜLMEDİ** — parite testi yalnızca
KAYNAKTA dolgunun durduğunu doğruluyordu. Portta yazılan yeni bir ölçüm
testi (`mobile/app/test/tap_target_test.dart`, 390×844) gerçek kutuları
verdi:

| Hedef | Ölçülen | Material asgarisi |
|---|---|---|
| alt şerit: Hamleler | 78.8 × **31.0** | 48 |
| alt şerit: Mesajlaşma | 94.4 × **31.0** | 48 |
| alt şerit: Nasıl Oynanır? | 125.8 × **31.0** | 48 |
| başlık: ← Geri | 90.8 × **29.3** | 48 |
| yardım: Detaylı Kurallar | 128.2 × **14.0** | 48 |

Yani düzeltme doğru yöndeydi, **miktarı** yanlıştı. Bir dolgu "biraz
büyüttük" diye değil, **ölçülen kutu asgariyi geçtiği için** yeterlidir.
Yukarıdaki notta 44/24 gibi daha alçak çıtaların "yeterli" sayılması da bu
turda geri alındı — çıta artık Material'ın 48'i.

**Elenen hipotez — küresel bir koordinat kayması DEĞİL:** dokunuş noktaları
topluca kaysaydı 24 px'lik tahta hücrelerine taş sürüklemek de bozulurdu;
kullanıcı sorunsuz oynayabiliyor. Sorun tek tek hedeflerin küçüklüğü.

**"← Geri" ise küçük değil, TAMAMEN ÖLÜYDÜ — ve bu hata sınıfı porta
özgü:** etiket bir `Stack(clipBehavior: Clip.none)` içinde `Positioned` ile
logonun kutusunun DIŞINA taşırılmıştı. Flutter'da kutusunun dışına taşan
bir çocuk hiç dokunuş almaz (`RenderBox.hitTest` önce `size.contains`e
bakar). Webde AYNI yapı çalışıyor, çünkü DOM'da tıklama en içteki elemandan
**ataya kabarır**: `<button>`ın içindeki `absolute top-full` bir `<span>`
pekâlâ butonu tetikler. Kodun kendi yorumu bunu "bilinçli sapma, kaçış yolu
webdeki gibi zaten logo" diye savunuyordu; savunma yanlıştı — port webi
taklit etmiyor, ondan ayrılıyordu.

> **Kural:** Web'den bir kontrol port edilirken "aynı görünüyor" yetmez —
> **kutunun kendisi** taşınmalı. DOM'da görsel taşma bedava, Flutter'da
> hedefi öldürüyor.

**Çözüm tek kaynakta:** `mobile/app/lib/src/ui/tap_target.dart` →
`kMinTapTarget` (48) + `TapTarget` (çocuğu ortalar, görünümü değiştirmez,
yalnızca kutuyu büyütür). Web tarafı aynı kusuru taşıdığından (paylaşılan
hata) `Board.tsx`, `HelpModal.tsx`, `Setup.tsx` `min-h-[48px]` aldı;
`UserMenu.tsx`'in avatarı `min-w/h-[48px] -m-2` ile büyüdü — negatif marj
dış kutuyu 32'ye geri çektiğinden **webde düzen bir piksel oynamıyor**.
Flutter'da negatif marj olmadığından portta bedel header'ın ~25 px uzaması
(logo, skor kutularıyla hizasını korusun diye blok dikey simetrik).

**İki bilinçli istisna** (gerekçesi kendi dosyasında yazılı, ölçüm testinin
başlığında da listeli): akan paragrafın içindeki `WidgetSpan` linki
(büyütmek satır yüksekliğini bozar) ve her mesaj baloncuğundaki 9 puntoluk
sessize alma/raporlama rozeti (sohbetin her satırını şişirirdi; aynı panele
pencere başlığındaki dişliden de ulaşılıyor).

**Doğrulama sınırı:** bu ortamda Flutter/Dart SDK YOK — Dart yarısının
kanıtı CI. Web tarafı temiz: `tsc`, `npm run build`, Playwright 29/29.

### Ek: hedefi büyütmenin GİZLİ maliyeti — dikey ortalama (24 Ağustos 2026)

İlk çözüm "← Geri"yi logoyla aynı `TapTarget`e alan bir Column'du ve
çalıştı; ama kullanıcı cihazda iki şey birden bildirdi: *"tam üstüne
basarsan ok ama biraz altına gelirse çalışmıyor"* ve *"header'ı bu kadar
büyütmüş olmayız"*.

Ölçüldüğünde ikisinin aynı sebepten geldiği çıktı: blok `Row`'da **dikey
ortalandığı** için, logonun skor kutularıyla hizasını korumak etiketin
altına eklenen her 1 px'e karşılık üstte de 1 px istiyordu. Yani
`header = 2 × (aşağı eklenen pay) + sabit`.

> **Kural:** dikey ortalanmış bir satırda bir hedefi AŞAĞI doğru büyütmek
> iki kat pahalıdır. Ödemek istemiyorsan hedefi o satırdan ÇIKAR — altında
> zaten boşluk varsa (burada header ile tahta arası) onu tıklanabilir
> yapmak bedavadır.

Sonuç: "← Geri" header satırının altına, tahtanın üstündeki mevcut boşluğa
taşındı. Logo+skor bandı 77 → 58 px, etiketin altında 13 px pay. Bedeli
logo↔etiket arasının 3 → ~9 px açılması (etiket artık logonun kutusuna
değil satırın altına çapalı).

**Web bu değişikliği ALMADI** — orada etiket `<button>`ın içinde bir
`<span>` ve tıklama ataya kabardığından hem 3 px yukarıda durabiliyor hem
çalışıyor. Ayrışan şey değer değil yapı; parite testi bunu kayda geçiriyor.

### Ek: "iki pencere açılıyor" — modal yüksekliği içerikten geliyordu

Kullanıcı: *"Leaderboard ve skor kartı arkada küçük pencerede yükleniyor
çıkıyor sonra büyük pencereler geliyor. Halbuki tek pencere açılmalı ve
datanın olduğu kısımda yükleniyor yazmalı."*

`KModal`/web `Modal` yüksekliğini içeriğinden alıyor ve dikeyde ortalı:
yüklenirken içerik tek satır → küçük pencere; veri gelince iki yöne birden
büyüyor. Bu bir yükleme durumu eksikliği DEĞİL, **yer ayırma** eksikliği.

Düzeltme: yükseklik baştan ayrılıyor — lider tablosunda listenin kendi
tavanı kadar (50vh, iki platformda da), skor kartında aynı ızgara `—`
değerleriyle çizilerek. İki platformda birden.
