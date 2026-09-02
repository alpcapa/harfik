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

## İkinci tur: ✕ butonları ve raf taşı (27 Ağustos 2026)

Kullanıcı: *"Bir de app'de bazı tıklamalar yine biraz üstte gibi. Mesela
skor kartı x'de dikkatimi çekti. Tüm bu tip tıklamaları kontrol etmek
lazım."* + *"harfi yakalamak bazen zor oluyor hala. Web'de düzenleme
yapmıştık, alanı genişletmiştik. Bu app'e de uygulandı mı?"*

**"Yine"** kelimesi doğru: bu, 24 Ağustos'un 48 dp turunun AYNI hata
sınıfı. Asıl soru neden o tur bunları kaçırdığıydı.

### Neden kaçtılar: taramanın kendi kuralı onları güvende sayıyordu

`tap_target_test.dart`'ın kaynak taraması bir `GestureDetector`/`InkWell`
gördüğünde çevresinde "kutuya ölçü veren" bir işaret arıyor ve o listede
**`IconButton` de var**. Yani `IconButton` gören tarama o dokunulabiliri
ölçülmüş varsayıp geçiyordu. Oysa Material'ın `IconButton`'ı:

- `visualDensity: VisualDensity.compact` ile 48 → **40×40**,
- üstüne `padding: EdgeInsets.zero` ile daha da aşağı iner.

> **Ders:** bir taramanın "güvende" listesi, güvende OLMAYAN bir şeyi
> içerebilir. Listeye bir tür eklerken "bu tür gerçekten bir asgari
> garanti ediyor mu?" diye sor — `IconButton` etmiyordu.

### Ölçüm (390×844, düzeltmeden önce)

| Hedef | Kutu | Not |
|---|---|---|
| `KDialogCard` ✕ | **28 × 28** | web'in `w-7 h-7`'si birebir taşınmıştı |
| `KModal` ✕ (skor kartı dahil) | **40 × 40** | `visualDensity: compact` |
| `RankInfoModal` / `RewardBanner` ✕ | 40 × 40 | aynı |
| `ChatModal` dişlisi | 40 × 40 | ✕'in tam yanında |
| Raf taşı | **46.3 × 46** | çevresi ölü alan (aşağı bkz.) |
| Web modal ✕'leri (9 yer) | **28 × 28** | `w-7 h-7` |

### Çözüm: kutuyu büyüt, dolgusunu aynı kadar kıs

Görselin kıpırdamaması ŞART — bu, projenin hamle rozetinde uyguladığı
takasın (13 Ağustos 2026) aynısı.

- **Port:** yeni bir `KIconButton` (`tap_target.dart`) — 48×48, sıfır
  dolgu. Çağıranlar telafi ediyor: `KModal` başlık dolgusu `20/12/16` →
  `16/8/12`; köşe butonlarında `Positioned` 8 → 4, `KDialogCard`'da 12 → 2.
  Ölçüldü: ✕ ikonunun rect'i düzeltmeden önce ve sonra **birebir aynı**
  (`333.0, 386.5, 351.0, 404.5`).
- **Web:** DOM'da telafiye gerek yok — bir sözde-eleman düzeni hiç
  etkilemez. Tek bir yardımcı sınıf (`.tap-expand`, `src/index.css`) 48×48'lik
  bir `::after` koyuyor; dokuz ✕'e eklendi, hiçbir konum yeniden
  hesaplanmadı.

⚠ `.tap-expand`'i `overflow-hidden` bir kapsayıcıda kullanırken düğmenin
kenardan en az 10 px içeride olduğundan emin ol — taşan kısım kırpılırsa
dokunuş almaz. (Bugünkü tek örnek `Modal.tsx`in kartı; oradaki ✕ 20 px
dolgunun içinde.)

**Bilinçli istisna:** `auth_modal.dart`'ın şifre göster/gizle düğmesi
(`InputDecoration.suffix`). Alan yüksekliği web paritesi gereği 38
(`theme_test.dart` ölçüyor); 48'lik bir kutu alanı bozardı. Aynı eylem
klavyeden de erişilebilir ve yanlış dokunuşun bedeli sıfır.

### ⚠ `.tap-expand` KONUM KURALI KATMANLI OLMAK ZORUNDA — 31 Ağustos 2026

Bir kullanıcı bildirdi: *"Girişsiz oyun açılış uyarısı X kaymış. Bunun gibi
başka var mı kontrol et."* ✕ sağ üst köşe yerine kartın SOL ÜSTÜNDE
duruyordu ve metni aşağı itiyordu.

**Sebep bir CSS kaynak-sırası çakışması.** `.tap-expand` `position:
relative` tanımlıyor (sözde-elemanın çapası). Kural KATMANSIZ yazılmıştı;
Tailwind'in `.absolute` utility'siyle **aynı specificity'de** (ikisi de tek
class = 0,1,0) ve derlenmiş CSS'te **ondan sonra** geldiğinden onu
eziyordu. Sonuç: `absolute top-3 right-3 … tap-expand` taşıyan her ✕
`relative` olup normal akışa giriyordu.

**Ölçüldü** (derlenmiş CSS + canlı, 390 px):

| | Önce | Sonra |
|---|---|---|
| `getComputedStyle(x).position` | **`relative`** | `absolute` |
| ✕'in kart sağ kenarından uzaklığı | **317 px** | **13 px** |
| Görsel kutu | 28×28 | 28×28 |
| Dokunma hedefi (`::after`) | 48×48 | 48×48 |
| Metnin kart üstünden uzaklığı | 69 px | 25 px |

Derlenmiş CSS ofsetleri: `.absolute` **10737**, `.tap-expand` **32746** →
sonra gelen kazanıyor.

**DÜZELTME:** konum kuralı `@layer components` içine alındı. Tailwind
components katmanını utilities'ten ÖNCE yayınladığından `absolute` artık
kazanıyor; konum utility'si OLMAYAN çağıranlar `relative` almaya devam
ediyor. `::after` kuralları katman dışında kalabilir — hiçbir utility ile
çakışmıyorlar. (`:where()` ile specificity düşürmek de işe yarardı ama
seçilmedi: desteklenmeyen bir tarayıcıda seçici tümüyle geçersiz sayılıp
kural DÜŞER ve hedefler sessizce bozulurdu; katman yaklaşımının böyle bir
riski yok.)

**İKİNCİ TUR — ✕ köşeye oturunca içerikle ÇAKIŞTI.** Kullanıcı düzeltmeyi
görüp *"Olmuş ama yazıyla arasında hiç boşluk yok"* dedi. Doğal sonuç: ✕
akıştayken metnin yanında değildi, köşeye oturunca yanına geldi. Ölçüldü
(390 px): ✕'in sol kenarı 333, metnin ilk satırının sağ ucu 323.7 →
**9,3 px** ve dikeyde **14 px örtüşme**. Metnin `pr-6`'sı (24 px) ✕'in
kapladığı 41 px'i karşılamıyordu.

⚠ **Yatay boşluk açmak YANLIŞ çözümdü, ölçüldü:** `pr-8` cümleyi 2 satırdan
**3 satıra** çıkarıp kartı 153,5 → 176,3 px yapıyor VE ilk satırın sağında
38 px'lik ragged bir boşluk bırakıyordu. Doğru çözüm metni ✕'in ALTINDAN
başlatmak: kart `p-6` → `px-6 pb-6 pt-12` (üst dolgu 24 → 48), paragrafın
artık gereksiz `pr-6`'sı kaldırıldı. Sonuç: örtüşme **0**, ✕ ile metin arası
**10 px**, satır sayısı **2** (korundu), kart 177,5 px.

**Aynı desendeki DÖRT kart birden düzeltildi** (hepsi birebir aynı kart
sınıfı + mutlak ✕): `Setup` (Giriş uyarısı), `FriendsModal`,
`PlayerScoreCard`, `OnlineGameScreen` (mesaj penceresi — orada ilk çocuk bir
paragraf değil avatar+isim satırı; uzun bir takma ad ✕'in altına girerdi).
`RankInfoModal` ve `RewardBanner` DIŞARIDA bırakıldı, bilinçli: onlar
280 px'lik `text-center` kartlar, içerik `mx-auto` 88 px'lik mühür ve
ortalanmış başlıklar — köşeye ulaşmıyorlar.

**KAPSAM — altı yer birden bozuktu ve hepsi bu tek değişiklikle düzeldi:**
`Setup` (Giriş uyarısı), `RankInfoModal`, `FriendsModal`,
`PlayerScoreCard`, `RewardBanner`, `OnlineGameScreen`. Altısı da birebir
aynı sınıf dizesini taşıyor.

**Kullanıcının "başka var mı" sorusu tarandı** — `index.css`'teki KATMANSIZ
her özel sınıf, tanımladığı özellik için bir Tailwind utility'siyle aynı
elemanda kullanılıyor mu diye kontrol edildi. Çakışma toplamı: **6, hepsi
bu vaka.** `reward-*` sınıfları (`opacity`/`animation`) hiçbir yerde
`opacity-*`/`animate-*` utility'siyle birlikte kullanılmıyor;
`input,textarea,select { font-size }` kuralı ise bilinçli ve zaten
`!important` (iOS zoom bug'ı).

**REGRESYON TESTİ:** `tests/smoke.spec.ts` → *"`.tap-expand` konumu utility
ile ÇAKIŞMIYOR"*. Hem konumu hem 48×48 hedefi ölçüyor (sınıfı tamamen
kaldırarak "düzeltmek" ikinci iddiaya takılır). Negatif eş doğrulandı:
kural katmandan çıkarılınca test `Received: "relative"` ile düşüyor.

**DERS:** özel bir sınıf, bir Tailwind utility'sinin kontrol ettiği bir
özelliği (position, opacity, display, font-size…) tanımlıyorsa **katmansız
bırakma** — aynı specificity'de sırf sonra geldiği için utility'yi sessizce
ezer. Bu kod tabanı aynı sınıf hatayı bir kez de ters yönde yaşadı
(`input` element selector'ı `.text-sm` class'ını ezemedi, `!important`
gerekti — bkz. kök `CLAUDE.md` → "Form Input'ları").

**Flutter portu ETKİLENMİYOR** — orada CSS cascade diye bir şey yok,
`TapTarget` kutuyu doğrudan büyütüyor.

### `UserMenu` de `.tap-expand`e geçti — 30 Ağustos 2026

Web'de `.tap-expand` kullanmayan son yer `UserMenu`'nün avatar düğmesiydi;
hedef orada `min-w-[48px] min-h-[48px] -m-2` ile büyütülmüştü (17 Ağustos
2026, sınıf daha yokken). İkisi denk — dokunma alanı da düzen kutusu da
aynı — ama artık projenin tek deseni kullanılıyor.

⚠ **Görsel bir düzeltme DEĞİLDİ.** Bu değişiklik, bir kullanıcının
iPhone'da bildirdiği "skor kutusunun sağ kenarı kesiliyor" sorununu çözmek
için yapıldı ve çözmedi; gerçek sebep şeridin `outline`ı kırpmasıydı
(`docs/decisions/components.md` → `GameHeader`). Ölçüldü: avatar ile skor
kutusu arasındaki görünen boşluk iki hâlde de 8 px, avatarın konumu aynı —
çünkü o düğmenin arka planı/çerçevesi yok, 48 px'lik kutu şeffaf.

**O turdan kalan ÜÇ ders** (üçü de bu vakada ayrı ayrı hataya yol açtı):

1. **Bir sarmalayıcının `getBoundingClientRect()`i "boyalı kutu" değildir.**
   Görsel bir iddiayı ölçerken BOYANAN elemanı ölç, onu saran kutuyu değil.
2. **Bir kenarı TEK SATIR örnekleyerek ölçme.** Bu vakada y=108 taranmış, o
   satır tesadüfen yuvarlak bir köşeye denk gelmiş ve kenar "var" görünüp
   yanlış sonuca götürmüştü. Kenarın tamamını tara (dikey profil).
3. **Kaldırdığın bir Tailwind sınıfıyla eski hâli test edemezsin** — JIT
   onu artık üretmiyor. Öncesi/sonrası karşılaştırmasını inline stille kur.

### Raf taşı: ölü alanı hedefe DEVRET

"Harfi yakalamak zor" şikayeti bir parite eksiği değildi — **web'de de
aynıydı**. (Kullanıcının hatırladığı web düzenlemesi `draftRescue`;
o zaten portta doğmuştu ve `DRAG_LIFT` ile birlikte iki tarafta da var.)

Taşın hedefi tam taş kadardı ve **çevresi ölü alandı**: altında raf
kutusunun 12 px dolgusu, üstünde seçili taşın 7 px kalkma payı, aralarında
3 px boşluk. Parmağın temas merkezi nişan noktasının ALTINDA kaldığından
ıskalamalar tam da alttaki o ölü banda düşüyordu.

Tahta hücresinin aksine burada ölü alan **devredilebilir**:

| | Önce | Sonra |
|---|---|---|
| Hedef | 46.3 × 46 | **49.3 × 65** (alan 2,1×) |
| Taşın çizildiği yer | x 24.0–70.3, y 412–458 | **birebir aynı** |
| Rafın dış kutusu | 12–378 × 374–470 | **birebir aynı** |
| Komşu hedefler arası | 3 px ölü | **0** |

Sayısal takas: raf dolgusu `all(12)` → `fromLTRB(10.5, 12, 10.5, 0)`, satır
53 → 65, her yuvaya `(1.5, 0, 1.5, 12)`. Yatay toplam korunduğu için
taşların genişliği bile aynı kalıyor. Web'de birebir aynı sayılar
(`px-[10.5px]` + hücre `px-[1.5px]`, `min-h-[65px]`, hücre
`h-[65px] pt-[7px] pb-3`, `gap: 0`).

> **Kural:** büyütülemeyen bir hedefin (tahta hücresi) yanındaki ıskalamayı
> ZARARSIZ yap; büyütülebilen bir hedefin (raf taşı) yanındaki ölü alanı
> ona DEVRET. İkisi de aynı gözlemin sonucu.

### Regresyon — iddia "büyüdü mü" değil, "görsel KIPIRDADI mı"

Asıl risk hedefi büyütürken düzeni sessizce kaydırmak. Bu yüzden testler
düzeltmeden ÖNCEKİ ölçümleri golden olarak tutuyor:
`tap_target_test.dart` (✕ ikon rect'i, raf taşlarının yedi rect'i, rafın
dış kutusu, başlığın x'i, komşu hedefler arası boşluk) ve
`tests/smoke.spec.ts` (✕'in GÖRSEL kutusunun 8 px ALTINA tıklamak modalı
kapatmalı; raf hedefi 65, taş 46, aradaki görsel boşluk hâlâ 3 px).

**Negatif eşleri kanıtlandı:** dolgu telafisi kaldırılınca ✕ ikonu 4 px
sola kayıyor ve test düşüyor (`Actual: 329.0` vs `333.0`); raf yuvasının
alt dolgusu kaldırılınca taş 12 px aşağı iniyor ve test düşüyor
(`taş 0 üst: 12.0`); web'de `tap-expand`/hücre yüksekliği geri alınınca
smoke testi düşüyor (`Received: 46` vs `65`).

Ayrıca yeni bir kaynak taraması eklendi: **`lib/src/ui` altında ham
`IconButton` kalmadı** — hepsi `KIconButton`'dan geçiyor, tek istisna
yukarıda gerekçesiyle yazılı.

### Ek: "benzer tüm yerlere uygulandı mı?" — tarama ve joker ızgarası (27 Ağustos 2026)

Kullanıcı ✕ düzeltmesinden sonra sordu: *"Skor kartındaki dokunma
düzeltmesi benzer tüm yerlere uygulandı mı?"* Doğru soru — ✕'ler bir
kaynak taramasıyla kilitlenmişti ama o tarama yalnızca **ham `IconButton`**
arıyor. Aynı hata sınıfı `IconButton` KULLANMAYAN bir yerde de olabilir.

Bu yüzden `lib/src/ui` altındaki tüm dokunulabilirler, çevrelerinde 48'in
altında AÇIK bir ölçü (`width`/`height`/`minWidth`/`minHeight`) olup
olmadığına göre tarandı; çıkan adaylar ekranda tek tek ÖLÇÜLDÜ. Tek gerçek
bulgu **joker harf ızgarası** oldu.

**Joker ızgarası — ölçülen: 48 × 44, dört yanında 6 px ölü boşluk.**
Genişlik tam sınırda, yükseklik altında. Buradaki ıskalamanın bedeli
diğerlerinden farklı ve gerçek: **yanlış HARF seçilir** — 22 Ağustos'ta
bildirilen *"önce konan A harfi C'ye döndü"* hatasının aynı sonucu, bu kez
başka bir sebeple.

Düzeltme rafla aynı desen (ölü alanı hedefe devret), ama yalnızca **zayıf
eksende**: `mainAxisSpacing: 0` + `mainAxisExtent: 50` + hücre içinde
`bottom: 6`. Sonuç 48 × 50, satırlar dikeyde aralıksız, **satır adımı hâlâ
50** — yani her satırdaki taş ızgara içinde tam eski yerinde.

Yatay 6 px BİLEREK duruyor: genişlik zaten 48 ve boşluğu hücreye almak
taşları 1 px daraltırdı (6 hücre × 6 = 36 ≠ 5 boşluk × 6 = 30). Rafta bu
telafi mümkündü (kutunun kendi dolgusu 12 → 10,5), burada değil.

**Toplam yükseklik:** düzenleme dalında SIFIR değişiklik (ızgara +6, üstteki
boşluk 12 → 6; "GERİ AL" ölçülen değeriyle birebir aynı yerde). Düzenleme
olmayan dalda kart 6 px uzuyor ve ortalandığı için içerik 3 px yukarı
kayıyor — ızgaranın İÇİNDE hiçbir şey oynamıyor. Web'de birebir aynı
sayılar (`gap-y-0`, hücre `h-[50px] pb-1.5`, `mt-3` → `mt-1.5`); tıklama
taştan HÜCREYE taşındı.

### Ek: oyun kartındaki üç ikon — üçüncü alet, "YÖNLENDİR" (27 Ağustos 2026)

Kullanıcı sordu: *"oyun kartlarında yer alan mesaj balonu ve hamleler ikonu
tıklaması nasıl? Orada da sorun var mı?"* **Vardı — ve bunlar uygulamadaki
EN KÜÇÜK hedeflerdi.** Ölçüldü (390×844, "Tüm Oyunlarım" kartı):

| Hedef | Kutu | Alan |
|---|---|---|
| Kalp (beğeni) | 15 × 13 | 195 px² |
| Mesaj balonu + sayı | 18.5 × 13 | 240 px² |
| Hamle dökümü ikonu | 19 × 13 | 247 px² |
| *karşılaştırma:* düzeltilmiş ✕ | 48 × 48 | 2304 px² |

Yani standardın **onda biri**. Şikayet yeni de değil: 12 Ağustos 2026'da
kullanıcı *"en az 4-5 kere dokunmam gerekti, tam basamazsan oyun detayları
açılıp kapanıyor"* demişti. O günkü düzeltme hedefi BÜYÜTMEDİ — yalnızca
hamle ikonunu mesaj balonuyla EŞİTLEDİ (121 → 247 px²).

**Neden büyütülmedi ve hâlâ büyütülemiyor:** satırın kendi yüksekliği 14 px
ve kart 74 px (ölçüldü). 44'lük bir kutu satırı ve dolayısıyla HER kartı
~104 px'e çıkarırdı — listenin tamamı %40 uzardı.

**Yani bu, tahta hücresiyle aynı sınıf.** Projede artık üç alet var ve
hangisinin kullanılacağı hedefin büyütülüp büyütülemediğine bağlı:

| Durum | Alet | Örnek |
|---|---|---|
| Hedef büyütülebilir | **BÜYÜT** (kutuyu büyüt, dolguyu aynı kadar kıs) | ✕'ler, joker ızgarası, raf taşı |
| Büyütülemez, ıskalamanın bedeli var | **YÖNLENDİR** | tahta taslak taşı (`draftRescue`), **oyun kartı ikonları (yeni)** |
| Büyütülemez, ıskalamanın bedeli yok edilebilir | **ZARARSIZLAŞTIR** | taslak sürerken anlam penceresinin açılmaması |

**Uygulama (`icon_tap_rescue.dart`):** kartın kendi dokunuş yakalayıcısı
zaten satırın tamamını kapsıyor ve ıskalayan dokunuş bugün oraya düşüyor.
Artık `onTap` yerine `onTapUp` kullanılıyor; nokta bir ikonun dikeyde
±14 px genişletilmiş kutusuna düşüyorsa o ikonun eylemi çalışıyor, düşmüyorsa
davranış **birebir eskisi gibi** (kart açılıp kapanır). Hedef 13 → 41 px
yükseklik, alan ~240 → ~760 px² (3,2 katı). **Düzen hiç değişmiyor.**

⚠ **YALNIZCA DİKEY — bilinçli.** Zayıf eksen dikey (13 px); yatayda ikonlar
18.5–19 px ve aralarında 2 px var. Yatayda da genişletmek bölgeleri üst üste
bindirir ve "hangisi" sorusunu doğururdu — `draftRescue`'nun oradaki cevabı
"belirsizse hiçbir şey yapma"ydı; burada o soruyu HİÇ DOĞURMAMAK daha iyi:
x aralıkları ayrık kaldığından aday her zaman en fazla bir tanedir. Yatay
ıskalamalar gerçekten sorun çıkarırsa ayrı bir iş olarak, ÖLÇÜYLE ele alınır.

**Web'de mekanizma FARKLI, sonuç aynı:** DOM'da düğmeler zaten
`stopPropagation` taşıyor ve bir sözde-eleman düzeni hiç etkilemiyor, yani
yönlendirmeye gerek yok — `.tap-expand-y` (yalnızca dikey, 41 px) üç düğmeye
de eklendi. Yükseklik portun `kIconRescueSlopY` payıyla birebir aynı.

**Regresyon:** `game_likes_test.dart` — ikonun 12 px ALTINA dokunmak sohbeti
/ hamle dökümünü açmalı; ikonlardan uzak bir ıskalama ise kartı ESKİSİ GİBİ
açmalı (kurtarmanın kartın kendi dokunuşunu yutmadığının kanıtı). Test
ayrıca kutunun hâlâ küçük olduğunu ölçüyor — bir gün büyütülürse test
sessizce anlamsızlaşmasın diye. **Negatif eş:** `onTapUp` kaldırılıp `onTap`
geri konunca iki test de düşüyor.

### Ek: kurtarma BOŞ hücreleri de kapsadı — kısıtın gerekçesi dardı (27 Ağustos 2026)

Kullanıcı Sürüm A'yı cihazda test ederken bildirdi: *"A testinde her şey
geçti ama tahtaya konan taşı kaldırmak için ilk tıklama yakalamıyor.
İkincide ya da üçüncüde yakalanıyor."*

**ÖLÇÜLDÜ (420×900), tahmin edilmedi:** tahta hücresi **26,2 px**. Taslak
taşı (0,0)'a konup hemen ALTINDAKİ boş hücreye (1,0) dokunulduğunda:

```
ÖNCE   → placed: [0,0]   mesaj: "Önce bir harf seç."
SONRA  → placed: []      mesaj: "Oyna tuşuyla kelimeyi onayla."
```

Yani taş geri alınmıyordu **ve** ekrana geri almaya çalışan kullanıcıyla
hiç ilgisi olmayan bir uyarı yazıyordu.

**Kör nokta 24 Ağustos'un kendi kısıtındaydı.** `draftRescue` o gün şöyle
sınırlanmıştı:

> *"⚠ YALNIZCA OYNANMIŞ hücrelerden çağrılır; BOŞ hücrelere hiç dokunulmaz
> — yoksa kelimeyi dizerken bir sonraki harfi yan hücreye koymak
> zorlaşırdı."*

Gerekçe **doğru ama yalnızca bir raf taşı SEÇİLİYKEN geçerli.** Seçim
yokken boş bir hücreye dokunmak zaten hiçbir iş yapmıyor — motor
(`_placeTile`) yalnızca o mesajı üretip aynı durumu döndürüyor. Yani o
durumda kurtarmanın bedeli **sıfır**.

Koşul bu yüzden dar tutuldu: `selectedTile == null && placed.isNotEmpty`.
Seçili taş varken davranış **hiç değişmedi** — ve bunu bir negatif eş
testi koruyor (ikinci taş seçilip komşu hücreye konuyor, kurtarma
karışmıyor).

> **Ders:** bir kısıtın gerekçesini yazarken HANGİ DURUMDA geçerli
> olduğunu da yaz. "Boş hücrelere dokunma" cümlesi tek başına doğru
> görünüyordu; eksik olan "…çünkü orada bir harf konabilir" koşuluydu ve
> o koşul sağlanmadığında kısıt bedava bir kayba dönüşüyordu.

Dört yüzeyde birden uygulandı (port `game_screen.dart` +
`online_game_screen.dart`, web `App.tsx` + `OnlineGameScreen.tsx`).
Regresyon: her iki platformda da bir pozitif (ıskalama geri alır) ve bir
negatif (seçiliyken harf koyar) test. Negatif eşleri kanıtlandı — koşul
`false` yapılınca ikisi de düşüyor.

### Ek: Sınıf 1'in ÜÇÜNCÜ örneği — yutmanın kapsamı dardı (28 Ağustos 2026)

Bir kullanıcı bildirdi: *"tahtaya konan taşı geri almak için tıkladığında
2 harf birden geri geliyor."*

**Kök sebep jokerde ya da reducer'da değil, yutmanın KAPSAMINDA.**
`tapPlacedTile` (`App.tsx` ↔ `OnlineGameScreen.tsx`) compat click'i yalnızca
JOKER dalında yutuyordu:

```ts
if (tile.wild) {
  if (swallow) swallowNextClick();   // ← yalnızca burada
  setPendingWild({ r, c, editing: true });
} else {
  dispatch({ type: 'RECALL_CELL', r, c });   // ← yutma YOK
}
```

22 Ağustos'ta bu doğru görünüyordu: sıradan bir taş geri alınınca compat
click BOŞALMIŞ hücreye düşüyor ve orada hiçbir şey yapmıyordu. Yani yutma
"gereksiz" sayılmıştı.

**O varsayımı 27 Ağustos'taki boş-hücre kurtarması sessizce geçersiz kıldı**
(yukarıdaki "kurtarma BOŞ hücreleri de kapsadı" eki). Kurtarma tam da o
boş hücreye anlam yükledi: *"seçim yokken boş hücreye dokunmak zaten hiçbir
iş yapmıyor, yani kurtarmanın bedeli sıfır."* Bedel sıfır değildi — hayalet
click de "hiçbir iş yapmayan" bir dokunuştu ve artık komşudaki taslak taşı
geri alıyor.

**ÖLÇÜLDÜ** (Chromium, `hasTouch`+`isMobile`, 390×844; iki komşu taslak taş,
(0,0) ve (0,1)); zincir enstrümante edilerek okundu:

```
tapPlacedTile 0,1 swallow=true      ← pointerup: (0,1) geri alındı  ✔
handleCellClick 0,1 sel=null        ← compat click, hücre artık BOŞ
BOS-HUCRE KURTARMA -> 0,0           ← kurtarma komşu taslağı buluyor
tapPlacedTile 0,0 swallow=false     ← (0,0) da geri alındı          ✘
```

Raf **5 → 7**; doğrusu 5 → 6.

⚠ **Masaüstü faresinde GÖRÜNMÜYOR ve sebebi öğretici:** orada `click`in
hedefi az önce SÖKÜLEN taş düğümü oluyor; React kopmuş bir düğümü hiçbir
fiber'a eşleyemediğinden olay sessizce düşüyor. Compat click ise hit-test'i
O ANDAKİ DOM üzerinde yapıyor, yani hâlâ bağlı olan HÜCREYE düşüyor. Aynı
hata masaüstünde ölçülseydi "yok" sonucu çıkardı — nitekim ilk denemede
çıktı.

**Düzeltme, yutmanın koşulunu dalın türünden jestin KAYNAĞINA çevirmek:**

```ts
if (swallow) swallowNextClick();     // pointer akışından geldiyse HER DAL
if (tile.wild) setPendingWild(...); else dispatch(RECALL_CELL);
```

Gerekçe: pointer akışından gelen dokunuş DOM'u her hâlükârda değiştiriyor —
ya taş sökülüyor ya pencere açılıyor. İkisi de compat click'i başka bir
öğenin üstüne düşürüyor.

**Ders — bu bölümün kendi kuralına eklenecek satır:** Sınıf 1'de "bu click
zaten hiçbir şey yapmıyor" gerekçesiyle yutmayı ATLAMA. O gerekçe bir
DAVRANIŞ varsayımı ve başka bir PR onu haberin olmadan geçersiz kılabilir;
nitekim tam olarak bu oldu. Yutmanın koşulu her zaman "jest DOM'u değiştirdi
mi", "sonrasında bir şey olur mu" değil.

**Regresyon:** `tests/smoke.spec.ts` 37 → **38 test**, dokunmatik blokta
(masaüstü profilinde hata görünmez). İki komşu taslak taş konup birine
dokunuluyor; raf tam BİR artmalı ve komşu taş tahtada kalmalı. Negatif eş
kuruldu: yutma yeniden joker dalına hapsedilince test gerçekten düşüyor
(*"rafa BİRDEN FAZLA taş döndü"*).

**Flutter portu ETKİLENMEDİ — ama bu İDDİA DEĞİL, ÖLÇÜM (kullanıcı sordu:
*"Mobilde aynı sorun yok mu?"*).** Port yapısal olarak bağışık: compat click
diye bir şey yok ve yerleştirilmiş hücreler `Listener`a, diğerleri
`GestureDetector`a gidiyor (`board_widget.dart`) — tek jest iki yolu birden
tetiklemiyor. Aynı senaryo portta koşuldu (420×900, iki komşu taslak, birine
dokunuş): **raf 5 → 6**, komşu taş tahtada kaldı.

Kodu okuyup "bağışık" demek yetmezdi: aynı gün web tarafında tam olarak bu
hata MASAÜSTÜ profilinde ölçülüp "yok" sonucu vermişti. Ölçüm kalıcılaştı —
`mobile/app/test/game_screen_test.dart` → *"taslak taşa dokunmak YALNIZCA o
taşı geri alır"* (592. test), web'deki eşiyle aynı adı taşıyor. Portun kendi
ıskalama kurtarması da var, yani ileride bir dokunuş yolu eklenirse bu
koruma kaymayı yakalar.

### Ek: İKİ eşik, tek sanılıyordu — titreşimli dokunuş (27 Ağustos 2026)

Kullanıcı, boş-hücre kurtarması çıktıktan SONRA aynı şikayeti tekrarladı:
*"Hâlâ tahtaya koyulan taşı her zaman alamıyorum. 1-2 denemeden sonra
alabiliyorum. Yine alt kısım çok iyi kavramıyor sanki."*

**Bir gün önceki düzeltme eksikti ve nedeni ölçüldü:** kurtarma YALNIZCA
"parmak hiç kıpırdamadı" dalında çalışıyordu. Parmak 10 px'i aşınca jest
**sürükleme** sayılıp bambaşka bir yola giriyor.

Ölçüm (420×900, taslak taşa dokunup bırakma):

| Parmak kayması | Önce | Sonra |
|---|---|---|
| 6 px | taş geri alındı | geri alındı |
| **12 px** | **hiçbir şey** | geri alındı |
| **20 px** | **hiçbir şey** | geri alındı |

Raf tarafı da aynı yoldan geçiyordu: 12/20 px kayan dokunuşta
`selectedTile` `null` kalıyor, yani **taş seçilemiyordu bile**. Bu, daha
önce "rafta harfi yakalamak zor" diye bildirilen şikayetin ikinci yarısı —
hedefin ALANINI büyütmek onu çözmemişti, çünkü sorun alanda değil JESTTE.

**Kök sebep: iki ayrı karar tek eşikle veriliyordu.**

| Karar | Doğru eşik | Neden |
|---|---|---|
| Hayaleti GÖSTER | 10 px (Android touch slop) | Sürüklemenin başladığını erken bildir |
| BIRAKMA mı dokunuş mu | **24 px** | Parmak 10 px'i istemeden aşıyor |

24, tahta hücresinin (~26 px) hemen altında: bir hücreden az giden jest
zaten bir hedef ifade edemiyor.

⚠ **Eşik bir BELİRSİZLİĞİ de çözüyor ve bu bilinçli.** Bırakma noktası
30 px KALDIRILMIŞ olduğundan (`DRAG_LIFT`), "taşı bir üst hücreye taşı"
jesti parmağın neredeyse hiç kıpırdamaması demek — yani "geri al" ile AYNI
jest. Belirsizlik, açık ara daha sık olan niyet lehine çözüldü: **kısa jest
= geri al.** Taşı taşımak hâlâ mümkün (daha uzun bir jestle ya da geri alıp
yeniden koyarak); `game_screen_test`in "sürükle-bırak: raftan tahtaya +
tahtada taşıma + rafa geri alma" testi bunu koruyor.

Raf taşı için ek bir kısa yol var: jest hâlâ RAFIN ÜSTÜNDE bittiyse bu bir
bırakma olamaz (rafa taş bırakılmıyor) — mesafeye bakmadan dokunuş sayılır.
Bu aynı zamanda "raf taşına dokundum, tahtaya kondu" riskini de kapatıyor:
kaldırılmış nokta rafın 30 px üstünü, yani tahtanın alt satırını
hedefliyordu.

> **Ders:** bir eşik iki farklı soruyu cevaplıyorsa, muhtemelen iki eşik
> olmalı. "Sürükleme başladı mı?" ile "kullanıcı bırakmak mı istedi?" aynı
> soru değil; ilkinin cevabı erken, ikincisinin cevabı geç verilmeli.

Dört yüzeyde birden (port `game_screen.dart` + `online_game_screen.dart`,
web `App.tsx` + `OnlineGameScreen.tsx`). Regresyon: her iki platformda
6/12/20 (port) ve 8/14/22 px (web) için ayrı testler; portta ayrıca "raf
taşı seçildi VE istemeden tahtaya konmadı" iddiası. Negatif eşleri
kanıtlandı — eşik 0'a çekilince iki platformda da düşüyorlar.

### Ek: testin kendi kırılganlığı — rastgele raf + joker (27 Ağustos 2026)

Yukarıdaki kurtarma testleri PR'da yeşil geçip **`main`'de düştü**. Uygulama
hatası değildi; testin kendi kırılganlığıydı ve CI logu kök sebebi birebir
yazdırdı:

```
<div class="overflow-y-auto px-5 pt-4 pb-5"> from
<div class="fixed inset-0 z-[150] ..."> subtree intercepts pointer events
  > 785 | await page.locator('[data-rack-tile="0"]').click();
```

Raf **rastgele** dağıtılıyor ve torbada 2 joker var. `[data-rack-tile="0"]`
bir jokerse tahtaya konulduğunda *"Joker Hangi Harf Olsun?"* penceresi
açılıyor; o pencere tam ekran bir `Modal` (`z-[150]`) olduğundan sonraki
HER tıklamayı yutuyor. Olasılık düşük (~%2) — yani test "çoğu zaman"
geçiyor, bu da onu daha kötü yapıyor: yeşil bir CI hiçbir şey kanıtlamıyor.

**Düzeltme rastgeleliği yok saymak değil, ondan BAĞIMSIZ olmak:** seçim
artık sabit bir indeks değil, "joker OLMAYAN ilk taş" (rafta `★` taşımayan).
İndeks her seçimden önce yeniden hesaplanıyor — taş konunca raftan düşüyor
ve kalan taşların indeksleri kayıyor. Ayrıca ikinci tıklamadan önce
`getByRole('dialog')` sayısının 0 olduğu iddia ediliyor: seçimin gerçekten
jokersiz olduğunun doğrudan kanıtı ve düşen senaryonun ta kendisi.

> **Ders:** rastgele bir durumdan (dağıtılan raf) sabit bir indeksle
> örnek almak, testi bir kumara çevirir. Ya durumu sabitle ya da örneği
> ARADIĞIN ÖZELLİĞE göre seç — "0. taş" değil "jokersiz taş".

### 48'in ALTINDA KALANLAR — gerekçeleriyle (aynı tarama)

Bunlar bilinçli olarak değiştirilmedi. Yeni bir tanesi eklenirse
`tap_target_test.dart` düşer.

| Yer | Ölçü | Neden bırakıldı |
|---|---|---|
| `friends_modal` ilişki + moderasyon ikonları | 44 × 44 | iOS HIG asgarisi; **dört dalın dördü de önce onay diyaloğu açıyor**, yani ıskalamanın bedeli sıfır. 48 yapmak liste satırının yüksekliğini her yerde değiştirirdi |
| `game_history_modal` kalp / mesaj / hamle ikonları | 15–19 × 13 | Satır 14 px, kart 74 px — büyütmek listenin tamamını %40 uzatırdı. **Bunun yerine YÖNLENDİRME** (yukarı bkz.): etkin hedef 41 px |
| `chat_thread` moderasyon rozeti | 9 punto | HER baloncukta olduğundan sohbeti şişirirdi; aynı panele başlıktaki dişliden de gidiliyor — **o dişli artık 48** |
| `auth_modal` şifre göster/gizle | 38 px alanın `suffix`i | Alan yüksekliği web paritesi gereği 38 (`theme_test.dart` ölçüyor); yanlış dokunuşun bedeli sıfır |
| `legal_modals` paragraf içi link | satır yüksekliği | Büyütmek akan metnin satır aralığını bozar |
| `game_header` "← Geri" | 48 × 24 | Header ile tahta arasındaki bantta; hemen üstündeki logo aynı eylem için tam boy hedef |
| Tahta hücresi | ~24 | **Büyütülemez** — ızgara ölçüsü oyunun kuralı. Bunun yerine ıskalama zararsızlaştırıldı (`draftRescue` + taslak sürerken anlam penceresinin açılmaması) |

> **Ders:** "hepsine uygulandı mı?" sorusunun cevabı bir liste değil bir
> TARAMA olmalı — ve tarama şekle göre yapılmalı (kutuya ölçü veren bir şey
> var mı), türe göre değil. Bu ders 24 Ağustos'ta bir kez alınmıştı
> (`GestureDetector`'ın çocuğu `Text` mi diye bakan tarama "Paylaş"ı
> kaçırmıştı); `IconButton`'ın güvende sayılması aynı hatanın ikinci biçimi.

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

### Ek: taramayı ŞEKLE göre yap, TÜRE göre değil (24 Ağustos 2026, üçüncü tur)

48 px turundan sonra kullanıcı Android'de bir hedefin daha kaçtığını
bildirdi: Setup footer'ındaki **"Paylaş"**. Düzeltme doğruydu, **taramanın
kapsamı** eksikti — kutusuz dokunulabilirleri ararken "`GestureDetector`ın
DOĞRUDAN çocuğu `Text` mi" diye bakılmıştı; "Paylaş"ın çocuğu ikon + metin
taşıyan bir `Row` olduğundan desene hiç takılmadı.

> **Kural:** bir dokunma hedefi taraması çocuğun TÜRÜNE değil, kutuya bir
> ÖLÇÜ veren bir şey (`padding`, `width`/`height`, `SizedBox`, `Container`,
> `constraints`, `TapTarget`…) olup olmadığına bakmalı.
>
> **Ve:** elle koşulan bir tarama bir daha koşulmaz. `tap_target_test.dart`
> artık `lib/src/ui` altını kendisi tarıyor; ölçüsüz her tappable testi
> düşürüyor, gerekçeli istisnalar adıyla listeli.

Aynı turda `TapTarget`e `alignment` eklendi: kutuyu büyütmek çocuğu
ortaladığından, bir kenara HİZALI duran metinler kayıyordu ("← Geri" 48
px'lik kutuda 4 px sağa kaçıp tahtanın sol kenarıyla hizasını kaybetti —
CI yakaladı).

### Ek: sürükleme 30 px KALDIRILMIŞ, dokunuş değil — teşhisimi düzelten bulgu (24 Ağustos 2026)

48 px turunda "küresel bir koordinat kayması yok, çünkü sürükleme sorunsuz
çalışıyor" demiştim. **Bu çıkarım hatalıydı** ve kod bunu açıkça gösteriyor:
sürükleme yolu parmağın **30 px ÜZERİNİ** hedef alıyor (`DRAG_LIFT = 30`,
`App.tsx`; portta `_dragLift`/`_liftedY`, `game_screen.dart`) — hem hayalet
taş hem BIRAKMA hedefi o kaldırılmış noktayı kullanıyor. Dokunuş yolunda
böyle bir telafi yok.

Yani sürüklemenin isabetli hissedilmesi, dokunuşun da isabetli olduğunu
kanıtlamıyor: iki yol farklı noktaya nişan alıyor. Kullanıcının dört ayrı
kontrolde tekrarladığı *"biraz üstüne basınca çalışıyor"* cümlesi bu
asimetriyle birebir tutarlı — parmağın bildirilen temas MERKEZİ, nişan
alınan noktanın altında kalıyor.

> **Ders:** "şu yol çalışıyor, demek ki koordinatlar doğru" demeden önce o
> yolun bir telafi taşıyıp taşımadığına bak.

**Buna rağmen çözüm dokunuşa offset EKLEMEK değil.** Bir kaydırma sabiti
büyük hedeflerde işi bozar ve her yüzeyi yeniden ayarlamayı gerektirir;
sektörün çözümü hedefi büyütmek (48 dp turu). Tahta hücresi (~24 px)
büyütülemeyen tek istisna — ızgara ölçüsü kuralın kendisi.

### Ek: küçültülemeyen hedefte ıskalamayı ZARARSIZ yap (24 Ağustos 2026)

Kullanıcı: *"2 kelimenin birleştiği yere bir taş koyup deneme yaparken
(oynaya basmadan) koyduğum taşın üstüne basıp geri almaya çalıştığımda
oradaki daha önce bulunan kelimelerin anlamları açıldı... Bu zaten yanlış,
kelime anlamı deneme yapılırken hiç açılmamalı. Bu kritik bir problem,
deneyimi tamamen bozuyor."*

İki ayrı şey üst üste binmişti: (a) ~24 px'lik hücrede taslak taşını geri
almaya çalışan dokunuş sık sık KOMŞU (oynanmış) taşa isabet ediyor;
(b) komşuya isabet edince pahalı bir sonuç doğuyordu — anlam penceresi.

(a) büyütülerek çözülemez. (b) çözülebilir ve asıl acıyı veren o:

> **Kural:** büyütülemeyen bir hedefin yanındaki ıskalamalar SESSİZ olmalı.
> Taslak hamle sürerken (`placed` boş değilken) oynanmış bir taşa dokunmak
> artık hiçbir şey yapmıyor — kullanıcı yeniden deniyor, bedel sıfır.
> Taslak boşken (rakibin sırası ya da kendi sıranda henüz taş koymadan)
> anlam penceresi eskisi gibi açılıyor.

Dört yüzeyde birden uygulandı (web `App.tsx` + `OnlineGameScreen.tsx`, port
`game_screen.dart` + `online_game_screen.dart`); webde ayrıca taslak
sürerken `cursor-pointer` kalkıyor (çalışmayan bir kontrol tıklanır
görünmemeli). `meaning_test.dart` korumanın DÖRT dosyada da, tahta-taşı
dalının içinde ve anlam çağrısından ÖNCE durduğunu kilitliyor.


### Ek: kurtarma web'e de taşındı (24 Ağustos 2026)

İlk kararım "web'de gerek yok, orada birincil girdi fare" idi. Kullanıcı
düzeltti: *"Bir çok insan mobil browser kullanıyor, mouse değil."* Haklı —
mobil tarayıcıda aynı 24 px'lik hücre ve aynı parmak var.

`src/utils/draftRescue.ts` → `nearbyDraftCell`, Flutter'daki
`_nearbyDraftCell` ile aynı kurallar: ortogonal komşular, tek aday varsa o,
birden çok adayda dokunuş noktasına en yakın olan, eşitlikte/ölçüm
yokluğunda **null**. Tıklama noktası `Board.tsx`'in `onCellClick`ine
eklendi; komşu hücre ölçüleri DOM'daki `data-cell` özniteliğinden okunuyor.

`npm run verify-draft-rescue` 11 kontrolle doğruluyor (web tarafında birim
test çatısı yok — `verify-cloud-save-mirror`la aynı esbuild+node deseni) ve
**negatif eş kuruldu:** eşitlik kuralı kaldırılınca "tam orta dokunuş →
null" kontrolü gerçekten düşüyor.

## Zoom pan menzili YARIYDI — "kutu zoom'lu ölçülüyor" varsayımı (2 Eylül 2026, web)

Bir kullanıcı gerçek bir oyunda bildirdi: *"Web'te zoom'da ciddi problem.
Zoom yapınca alt kısım altta kalıyor ve görünmüyor."*

**Kök sebep `useBoardZoom.ts`'te tek bir bölme:** pan, sınırlama boyutunu
`r.width / BOARD_ZOOM_SCALE` diye veriyordu; yorumu da gerekçeyi yazıyordu
— *"kutu ZOOM'LU ölçüldüğünden bölünür"*. **Varsayım yanlıştı:** `boxOf`
GÖRÜNÜR KARE (`absolute inset-0`) ve ölçeklenen o değil İÇİNDEKİ ızgara
(`transform` iç `div`de). Yani o dikdörtgen her zaman ölçeksiz.

**ÖLÇÜLDÜ** (390 px görünüm, kare 366 px): erişilebilen en uç öteleme
**−183 px**'te duruyordu, doğrusu **−366**. Tam yarısı, yani tahtanın
alt/sağ yarısına ASLA kaydırılamıyor.

⚠ **Belirti neden "ciddi" göründü:** `toggleAt` DOĞRU menzili kullanıyor,
yani dokunulan noktaya odaklı açılış çalışıyordu; kullanıcı alt yarıdan
zoom açtığında doğru yeri görüyor, sonra parmağını kaydırdığı anda ilk
`panZoom` daha dar sınırla yeniden kırpıp tahtayı geri ZIPLATIYORDU.
İki kod yolunun aynı sınırı paylaşmaması hatayı hem gizledi hem büyüttü.

**Port ETKİLENMEDİ:** orada `panBy(delta, gridSize)` ve `toggleAt(focal,
gridSize)` AYNI boyutu alıyor, bölme hiç yok. Yani bu bir parite kayması
değil, web'e sonradan giren bir varsayımdı (PR #398).

**Ders:** ölçekli bir düzende "hangi kutu ölçekli" sorusunu yorumla
cevaplama, ÖLÇ. Ve aç/kapa ile sürükleme aynı sınırı kullanmalı — ayrı
hesaplanırsa biri doğru çalışıp ötekini örter.

**Kapı:** `tests/smoke.spec.ts` → *"zoom açıkken SONA kadar kaydırılabilir
— son satır görünür olur"*. Test matematiği değil DAVRANIŞI ölçüyor: sonuna
kadar kaydırınca son hücre görünür karenin içine girmeli. Negatif eşi
kanıtlandı — bölme geri konunca −366 yerine −183 ölçülüp düşüyor.
