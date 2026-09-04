# Sürüm Kütüğü — Play'e yüklenen her paket

**Bu dosya KANONİK kaydıdır:** hangi sürüm, hangi `versionCode`, hangi
commit'ten, ne zaman yüklendi ve şu an ne durumda. "Yayında olan paket
hangisi?" sorusunun tek cevap yeri burasıdır.

**Neden ayrı bir dosya (4 Eylül 2026, kullanıcı isteği):** kütük daha önce
`build-and-distribution-log.md`in içinde, "Play Store İmzalama" bölümünün
altında bir alt başlıktı — yani adı imzalamayı anlatan 25 KB'lık bir karar
kaydının içinde gömülüydü ve bulunması için önce o dosyayı bilmek
gerekiyordu. Kullanıcı *"bir tane App version dosyası yap, bugüne kadar
çıkan tüm sürümleri güncel tut"* dedi. İçerik taşındı, **kopyalanmadı**;
eski yerinde yalnızca buraya bir işaret var.

⚠ Bu dosyanın kendisi bir bölünme dersinin ürünü: 2 Eylül 2026'ya kadar
kütük diye bir şey YOKTU, "hangi `versionCode` yayında" bilgisi
`ROADMAP.md`'nin sürüm turu bölümüyle karar kaydı arasında ikiye bölünmüştü
ve biri kapanırken öteki kapanmamıştı. **İş bölümü:** burası hangi PAKETİN
yayında olduğunu tutar; `ROADMAP.md` sürüm TURUNU (ne girdi, hangi kapı
açıldı) anlatır; `docs/decisions/roadmap-arsiv.md` kapanmış turları saklar.

---

## `versionCode` nereden geliyor

`.github/workflows/mobile-build.yml`:

```
flutter build appbundle --release "--build-number=${{ github.run_number }}"
```

Yani **`versionCode` = GitHub Actions koşu numarası.** `pubspec.yaml`'daki
`+1` Play'e HİÇ gitmez — orada hep `+1` yazması bir hata değil, CI onu
eziyor. (Play aynı `versionCode`'u iki kez kabul etmediğinden `pubspec`'in
sabit değeri ikinci yüklemede reddedilirdi; kural bu yüzden var.)

Pratik sonuç: **`versionCode` bir koşu numarasıdır**, o koşunun sayfasından
hangi commit'ten derlendiği okunabilir. `sha` sütununu doldurmanın en kolay
yolu budur.

---

## Kütük

| Sürüm | versionCode | sha | pubspec'te sürüm | Play'e yükleme | Durum | İçerik |
|---|---|---|---|---|---|---|
| 0.1.0 | — | `28b93ac` | 19 Ağu 2026 | **yüklenmedi** | — | Play öncesi; mağaza hazırlığı başlamamıştı. Yine de 16 mobil commit taşıyor (tanıtım ekranı, rütbe rozeti, dokunmatik düzeltmeler) — hepsi 1.0.0 ile yayına çıktı |
| 1.0.0 | ölçülmedi | `b4accee` (sürüm) · `48f01a1` (Sürüm B) | 23 Ağu 2026 | **5 gönderim** (25-28 Ağu) | yayınlandı → pasif | Mağaza kapısı + push/derin bağlantı + dokunma isabeti paketleri. In-App Update YOKTU (bkz. `build-and-distribution-log.md` → "Güncelleme modeli") |
| 1.0.1 | ölçülmedi | `7dd56ad` | 29 Ağu 2026 | **29 Ağu, 18:53** (Submission 7) | yayınlandı → pasif | Zorunlu güncelleme kullanılabilir hâle getirildi (mağaza butonu). Yaş/cinsiyet satırı aynı gün GERİ ALINDI — pakete girmedi |
| 1.0.2 | **435** | `d3d4702` | 30 Ağu 2026 | **30 Ağu, 12:07** (Submission 8) | yayınlandı → pasif | Faz 1 paketi + Play In-App Update. İnceleme **10 dk** (15:29 → Published 15:39, Console saatleri) |
| 1.0.3 | **449** | — | 31 Ağu 2026 (`c1c0437`) | **31 Ağu, 08:00** | yayınlandı → pasif | Telemetriden çıkan İKİ ÇÖKME (derin bağlantı rotası — 11 cihaz · rafta sınır dışı erişim) + bildirim rozetinin gerçekten sıfırlanması |
| 1.0.4 | **467** | — | 31 Ağu 2026 (`72278c3`) | **1 Eyl, 10:25** | yayınlandı → pasif | Faz 6'nın istemci yarısı + Faz 7'nin iki çökmesi + hata hız sınırı |
| 1.0.5 | **501** | `4a0a29b` | 1 Eyl 2026 (`f28b3da`) | **2 Eyl, 14:22** (paket) · sürüm 17:58'de güncellendi | yayınlandı → **pasif** (4 Eyl, 1.0.6 devraldı) | Tahta zoom'u + zoom tanıtım balonu + yazı ölçeği + mesaj kutusu etiketi + cihaz turu düzeltmeleri (rozet kırpması · alt şerit · çevrimdışı şerit · zoom çerçevesi · filigranlar). `.aab` 63.146.275 bayt, SHA-256 `200e82b9…451d4`. İnceleme ≈23 dk. Yayın sonrası cihazda doğrulandı (kullanıcı: *"1.0.5 turu testi tamam."*) |
| **1.0.6** | **525** | `711eaaa` | 3 Eyl 2026 (`a33fdaa`) | **4 Eyl, 15:53** (Submission 12) | ✅ **kapalı testte YAYINDA** (Alpha) | Aşağı bkz. |

⚠ **1.0.0/1.0.1'in `versionCode`'u hâlâ ölçülmedi** (Console'un paket
listesi ekran görüntüsünde 435'te kesiliyordu). Ama gönderim ↔ SÜRÜM ADI
eşlemesi 4 Eylül 2026'da **tarih yakınlığından çıkarım olmaktan çıktı**:
`pubspec.yaml`'ın geçmişi hangi tarih aralığında hangi sürüm adının
derlendiğini kesin söylüyor (aşağıda "Ne yapıldı — sürüm sürüm"). Her
gönderim bu pencerelerden birine düşüyor ve üç ÖLÇÜLMÜŞ çapa (Submission
8 = 1.0.2/435, 11 = 1.0.5/501, 12 = 1.0.6/525) pencerelerle çelişmiyor.

⚠ **Bunun ilk düzelttiği şey:** eski tablo Submission 1-4'ü "1.0.0 öncesi"
sanıyordu. Değil — `pubspec` **23 Ağustos 19:36'dan** beri 1.0.0 diyordu,
yani mağazaya çıkan ilk beş gönderimin hepsi **1.0.0** adıyla gitti
(farklı `versionCode`'larla). "1.0.0'ın içeriği" derken tek bir paketi
değil, 23-29 Ağustos arasında art arda yüklenen beş paketi kastediyoruz.

⚠ **Eşlemenin dayandığı tek varsayım:** Console'un saatiyle git'in saatinin
aynı çerçevede olması. En dar marj 18 dakika (Submission 6, ki o zaten
paket değil form). Üç saatlik bir kayma varsayılsa Submission 8 = 1.0.1
çıkardı ve bu ÖLÇÜMLE çelişirdi — yani kayma yok.

⚠ 1.0.3 ve 1.0.4'ün `sha`sı boş: `versionCode` koşu numarası olduğundan
Actions'ta 449 ve 467 numaralı koşuların `head_sha`sına bakılarak
doldurulabilir. Doldurulmadı çünkü ölçülmedi.

---

## Gönderim geçmişi (Console → Publishing overview → Submission activity)

Console'un kendi kaydı, 4 Eylül 2026'da okundu. **Sürüm eşlemesi
`pubspec.yaml`'ın sürüm pencerelerine dayanıyor** (aşağıdaki "Ne yapıldı"
bölümü) — "ölçüldü" işaretli üç satır Console'dan doğrudan okundu,
ötekiler pencereye düşürüldü. `versionCode`'lar 435'in altında hâlâ
ölçülmedi.

| # | Gönderim | Kapsam | Durum | Sürüm (çıkarım) |
|---|---|---|---|---|
| 12 | 4 Eyl 2026, 15:53 | Closed testing - Alpha | ✅ **Published** | **1.0.6 (525)** — ölçüldü |
| 11 | 2 Eyl 2026, 17:24 | Closed testing - Alpha | Published | 1.0.5 (501) |
| 10 | 1 Eyl 2026, 13:27 | Closed testing - Alpha | Published | 1.0.4 (467) |
| 9 | 31 Ağu 2026, 11:01 | Closed testing - Alpha | Published | 1.0.3 (449) |
| 8 | 30 Ağu 2026, 15:29 | Closed testing - Alpha | Published | **1.0.2 (435)** — ölçüldü |
| 7 | 29 Ağu 2026, 18:53 | Closed testing - Alpha | Published | 1.0.1 (bump'tan 58 dk sonra) |
| 6 | 29 Ağu 2026, 17:37 | **App Content** | Published | paket değil — form gönderimi |
| 5 | 28 Ağu 2026, 00:54 | Closed testing - Alpha | Published | **1.0.0** |
| 4 | 26 Ağu 2026, 22:33 | Closed testing - Alpha | Published | **1.0.0** (eskiden "1.0.0 öncesi" yazıyordu — YANLIŞTI) |
| 3 | 26 Ağu 2026, 11:52 | Closed testing - Alpha | Published | **1.0.0** (aynı düzeltme) |
| 2 | 26 Ağu 2026, 08:57 | Closed testing - Alpha | Published | **1.0.0** (aynı düzeltme) |
| 1 | 25 Ağu 2026, 19:23 | Closed testing - Alpha, **Store Listing, App Content, Advanced distribution, Store settings** | Published | **1.0.0** + mağaza kaydının tamamı |

⚠ **Her gönderim bir SÜRÜM değil.** Submission 6 yalnızca "App Content"
formu; 1 numaralı gönderim mağaza kaydının tamamını taşıyor. Yani
"12 gönderim" ile "12 sürüm" aynı şey değil — kütükteki paket sayısıyla
buradaki satır sayısı bilerek tutmuyor.

⚠ Console'un kaydı **1 Mayıs 2026'dan itibaren** tutuluyor (sayfanın kendi
notu). Daha eskisi burada görünmez.

## 1.0.6 (525) — YAYINDA (gönderim 4 Eyl 2026, 15:53 · Published 16:22'den önce)

**Paket:** `mobile-latest` prerelease'indeki `kelimeki.aab`, koşu 525,
`711eaaa`'dan derlenmiş, release anahtarıyla imzalı (4 Eyl 10:36).

| | |
|---|---|
| İndirme | `https://github.com/alpcapa/kelimeki/releases/download/mobile-latest/kelimeki.aab` |
| Boyut | 63.210.820 bayt |
| SHA-256 | `96f176e64d79a622a2c33cb8e49588c9ce9f15ad13e6bb55060b0f99b4769aca` |
| Yüklendiği an | 4 Eyl 2026, 10:36:00 UTC (release varlığı) |

⚠ Bu SHA-256 **4 Eylül 10:36'daki** pakete ait. `mobile-latest` her mobil
derlemede üzerine yazıldığından, gönderimden önce indirdiğin dosyanın
özetini bununla KARŞILAŞTIR — tutmuyorsa arada yeni bir derleme olmuş
demektir ve gönderdiğin paket bu satırın anlattığı paket değildir.

**Sürüm adı (Console):** `1.0.6 (525)`

**Sürüm notları (`tr-TR`, 491/500 karakter):**

```
Yenilikler
• Oyun geçmişinde "Tekrar Oyna": biten bir Canlı oyunun aynı kadrosuyla rövanş daveti gönder.
• Skor kartında kafa kafaya oran çubuğu — bir rakibe karşı galibiyet/beraberlik/mağlubiyet dağılımın.
• Biten Canlı oyunlarda "Yeni" rozeti: sonucunu görmediklerin işaretli.
• Listelerde süresi bitmeye en yakın oyun en üstte.

Düzeltmeler
• iPad'de paylaşım penceresinin asılı kalması.
• Kafa kafaya oranında teslimlerin beraberlik sayılması.
• Terk edilen oyunun yanlış güne yazılması.
```

**Notlara giren commit'ler:** `c9f03fd` · `76a7151` · `a966dec` ·
`a33fdaa` · `d07c06d` · `711eaaa`.

⚠ **Notlara girmeyen iki değişiklik — ve biri hakkında YANLIŞ gerekçe
yazılmıştı (4 Eylül 2026'da düzeltildi):**

| PR | Gerçekte ne oldu | Notlara neden girmedi |
|---|---|---|
| #427 — "Yeni Canlı Oyun" çökmesi (`913c14f`) | `mobile/` altında **sıfır** dosya: `LiveGamesTab.tsx` + web CI kapısı | Doğru gerekçe: **web-only**, bu pakette yok |
| #426 — kafa kafaya avatarları 18 → 26 px (`1bfb997`) | `mobile/app/lib/src/ui/score/player_score_card_modal.dart` **DEĞİŞTİ** (16 satır) — yani pakete GİRDİ | Kozmetik (8 px'lik avatar); 491/500 karakterlik notta yer yoktu |

**Hata nasıl doğdu:** dosya listesi `git show --stat | grep mobile/` ile
okunmuştu ve `--stat` uzun yolları `.../lib/src/ui/score/…` diye kısalttığı
için o satır grep'e takılmadı. **Ders:** bir commit'in hangi alanlara
dokunduğunu `--stat` çıktısından grep'leme — `--name-only` kullan (o yolu
kısaltmaz). Sürüm notu YANLIŞ DEĞİL (o değişiklik zaten duyurulmayacak
kadar küçüktü), yalnızca gerekçesi yanlıştı.

**Cihaz doğrulaması:** APK (`711eaaa`) 4 Eylül'de cihazda koşuldu; §0-§4'ün
koşulabilir maddeleri geçti (ayrıntı: `cihaz-testi-log.md` → "FAZ B — İLK
GERÇEK CİHAZ TURU"). Kullanıcı kuralı sağlandı: *"apk ile test edip
sorunsuz olduğundan emin olmadan aab yapılmayacak."*

---

## Ne yapıldı — sürüm sürüm

**Bu bölüm 4 Eylül 2026'da eklendi**, kullanıcı sorusuyla: *"bu tabloda
nelerin yapıldığı bilgisi yok"*. Yukarıdaki kütük hangi PAKETİN yayında
olduğunu söylüyordu ama içeriğini tek satırlık etiketlerle geçiyordu.

**Yöntem — çıkarım değil, ölçüm:** her sürümün penceresi `pubspec.yaml`'ın
geçmişinden geliyor (hangi commit sürüm adını değiştirdi), pencereye düşen
commit'ler ise **mobil pakete gerçekten giren** dosyalara göre süzüldü:

```
git log --first-parent <önceki bump>..<bu bump> -- \
  mobile/app/lib mobile/app/android mobile/app/ios \
  mobile/app/assets mobile/kelimeki_core/lib
```

⚠ **Sadece `mobile/docs` değiştiren commit'ler listede YOK** — doküman
pakete girmiyor. ⚠ **`web + port` etiketi**, aynı commit'in `src/` altında
da dosya değiştirdiğini söyler (bu depoda çoğu düzeltme iki tarafa birden
gider); `yalnız port` ise değişikliğin tamamen Flutter tarafında olduğunu.

⚠ **Sürüm penceresi ile DERLEME anı aynı şey değil.** 1.0.5 ve 1.0.6 için
derleme sha'sı biliniyor (`4a0a29b`, `711eaaa`), o yüzden pencereleri orada
kesildi. Ötekilerde sınır bir sonraki sürüm bump'ıdır — yani son bir iki
commit teorik olarak o paketin derlemesinden SONRA girmiş olabilir.

### 0.1.0 — 16 mobil commit

*Pencere: 19 Ağu 02:15 → 23 Ağu 19:36*

**Play'e hiç yüklenmedi** — ama 16 mobil commit taşıyor ve hepsi 1.0.0
paketiyle sahaya çıktı. Öne çıkanlar: **ilk açılış tanıtım ekranı**
(`IntroScreen`, dört slayttan beşe, web'in karşılama katmanıyla hizalandı,
atlama yok), **yeni rütbe rozeti + kendi alt küme fontu** ve isim yanındaki
mühürler, en üst rütbenin adının **Tanrı → Kozmik** olması, k-lig sırasının
tek kaynağa (`k_lig_siralama` view'ı) indirilmesi, giriş sekmesi varsayılanı
("YZ tarafı boşken Arkadaşınla açılsın") ve iki dokunmatik jest hatası
(jokerin harfi kendiliğinden değişiyordu · titreşimli dokunuş kayboluyordu).

<details><summary>Commit dökümü (16)</summary>

| sha | Tarih | Ne | Kapsam |
|---|---|---|---|
| `28b93ac` | 19.08.2026 | Tanıtım ikonları, yeni rütbe rozeti + fontu, isim yanı mühürler ve karşılama metin turu | web + port |
| `8a08499` | 19.08.2026 | Kozmetik metin/boşluk turu + hukuki metin ve doküman denetimi | web + port |
| `14ec7fb` | 19.08.2026 | Portun ilk açılış tanıtımı: IntroScreen (atlama yok) + Setup'ta Tanıtım linki | yalnız port |
| `0d75b98` | 19.08.2026 | Tanıtım ekranı: dört slayt web'in karşılama katmanıyla hizalandı | web + port |
| `958f1d3` | 19.08.2026 | Tanıtım ekranı: beş slayt, alt düğme kalktı, logo içerikle birlikte ortalanıyor | yalnız port |
| `478ffce` | 19.08.2026 | En üst rütbe: Tanrı → Kozmik (T → K), web + port | web + port |
| `e200c90` | 19.08.2026 | Port düzeltmeleri: footer telifi ortalandı, tanıtım 1./2. slayt dengelendi, X2/X3 legend'i yan yana | yalnız port |
| `53e423c` | 19.08.2026 | Tanıtım kromu 47 → 29 px: 1. slayt iOS Safari'de de sığıyor | yalnız port |
| `4a1d88a` | 19.08.2026 | Tanıtım: son satır leading'i kaldırıldı + boşluklar kırpıldı (~23px) | yalnız port |
| `f0f71e0` | 21.08.2026 | k-lig sırası tek kaynaktan: k_lig_siralama view'ı + OHP eşitlik bozucu | web + port |
| `6b35fb7` | 21.08.2026 | Oyun sonu kartı, kaynak hunisi, hata telemetrisi, admin üyeler tablosu ve hoş geldiniz e-postası | web + port |
| `bacbd9d` | 21.08.2026 | Canlı liste düşen istekte "oyunun yok" demesin + oyundan Setup'a dönüş görünür olsun | web + port |
| `20149e1` | 21.08.2026 | Giriş varsayılanı: YZ tarafı boşken "Arkadaşınla" açılsın | web + port |
| `3773ffb` | 22.08.2026 | test(mobile): kalan dört korumasız web↔port çiftini de kilitle | yalnız port |
| `0d4ccc1` | 22.08.2026 | Kaynak Hunisi: misafir hunisi (game_finishes/game_starts kaynak etiketi) | web + port |
| `c62e219` | 22.08.2026 | Dokunmatik jest hataları: joker harfi kendiliğinden değişiyordu + titreşimli dokunuş kayboluyordu | web + port |

</details>

### 1.0.0 — 28 mobil commit

*Pencere: 23 Ağu 19:36 → 29 Ağu 17:55*

**Mağazaya çıkan ilk sürüm adı — tek paket değil, 23-29 Ağustos arasında
art arda yüklenen BEŞ paket** (Submission 1-5). En kalabalık sürüm (28 mobil
commit). Dört blok hâlinde:

- **Mağaza kapısı:** imzalama + `.aab` üretimi, mağaza vitrini, hukuki statik
  sayfalar, **uygulama içinden hesap silme** (mağaza blokeriydi), `AD_ID`
  izninin kaldırılması, `/.well-known/assetlinks.json` parmak izi,
  onaylanmamış hesap süpürmesi.
- **Push + derin bağlantı** (`48f01a1`, "Sürüm B"): bildirim kanalı
  `IMPORTANCE_HIGH`, push token yaşam döngüsü, kanal parite testi.
- **Kapalı testten dönen dokunma isabeti paketleri** ("Sürüm A" ve "A2"):
  48 dp dokunma hedefleri, bırakma kararı için ayrı eşik, "Buradan başla"
  balonu, ıskalanan dokunuşun komşu taslağa yönlendirilmesi, "← Geri"nin
  ayrı satıra taşınması.
- **Performans ve çökme:** tahtanın HER KAREDE yeniden boyanması
  (`RepaintBoundary`) ve nömorfik dekorun raster önbelleğe alınması — oyun
  ekranının ağır çekimi buydu; ayrıca **release APK'da eksik `INTERNET`
  izni** (giriş ve tüm sunucu özellikleri ölüydü) ve kurucusu silinmiş
  oyunun (`created_by NULL`) Canlı listeyi düşürmesi.

Oyun kuralı da bu pencerede değişti: **kendi 4×4 bloğundaki desteksiz rakip
taşı artık bölge zincirini kesmiyor** (`18689eb`).

⚠ **In-App Update mekanizması bu sürümde YOKTU** — 1.0.0 kitlesinin
güncellenememesinin sebebi bu; bir kereye mahsus `app_config` eşiğiyle
süpürüldü (bkz. `mobile/CLAUDE.md` → "Güncelleme").

<details><summary>Commit dökümü (28)</summary>

| sha | Tarih | Ne | Kapsam |
|---|---|---|---|
| `b4accee` | 23.08.2026 | Google Play yayını: imzalama, .aab, sürüm 1.0.0, mağaza vitrini, hukuki statik sayfalar | web + port |
| `f13af84` | 23.08.2026 | Onaylanmamış hesap süpürmesi: hatırlat, sonra sil | web + port |
| `4513c37` | 24.08.2026 | Admin kart başlıkları, hata telemetrisi gürültü filtresi ve mağaza öncesi sürüm/rota alanları | web + port |
| `d59306d` | 24.08.2026 | Cihaz dökümü artık girişli ziyaretleri de kapsıyor (device_visits) | web + port |
| `fafdcb2` | 24.08.2026 | Release APK'da eksik INTERNET izni: giriş ve tüm sunucu özellikleri ölüydü | yalnız port |
| `6e481b7` | 24.08.2026 | İki teknik borç ve elenen 8px eşiği kayda geçti | web + port |
| `18689eb` | 24.08.2026 | Bölge kuralı: kendi bloğundaki desteksiz rakip taşı zinciri kesmiyor | web + port |
| `71eb73a` | 24.08.2026 | Dokunma hedefleri 48 dp; "Yükleniyor…" okunur hâle getirildi (web + port) | web + port |
| `ee26383` | 24.08.2026 | "← Geri" ayrı satıra taşındı; açılış ve yükleme deneyimi her yerde aynı | web + port |
| `825451c` | 25.08.2026 | Taslak sürerken anlam açılmıyor; ıskalanan dokunuş komşu taslağa yönleniyor | web + port |
| `17b194f` | 25.08.2026 | Play imza parmak izi: /.well-known/assetlinks.json yayınla | yalnız port |
| `69d5478` | 26.08.2026 | Uygulama içinden hesap silme (ROADMAP madde 2, mağaza blokeri) | web + port |
| `53e401c` | 26.08.2026 | Kullanım Koşulları §2: hesabı kendin silme cümlesi (web + port) | web + port |
| `42a1f67` | 26.08.2026 | Hesap silme uyarısı kırmızı + kalın + ünlemli (web + port) | web + port |
| `c947b10` | 26.08.2026 | Canlı oyun listesi: kurucusu silinmiş oyun (created_by NULL) listeyi düşürüyordu | web + port |
| `4e9aac6` | 26.08.2026 | Hesap menüsü: k-lig satırı puan geç gelince açık menüde hiç belirmiyordu | yalnız port |
| `e7e1e79` | 26.08.2026 | Doküman bölünmesi + davet hataları görünür oldu + tanıtıma DEVAM düğmesi | web + port |
| `009d478` | 26.08.2026 | Sürükleme donması: tahta her karede yeniden BOYANIYORDU (RepaintBoundary) | yalnız port |
| `8d83ed6` | 26.08.2026 | Oyun ekranı ağır çekim: bir boyamanın MALİYETİ (nömorfik dekor raster önbelleği) | yalnız port |
| `5d8c549` | 26.08.2026 | "Buradan başla" balonu: ilk hamlenin nereye yapılacağı (web + port) | web + port |
| `f9c3846` | 27.08.2026 | Sürüm A: kapalı testten gelen dört düzeltme (dokunma hedefleri, Ara & Ekle, rozet, koltuk) | web + port |
| `24c5b0c` | 27.08.2026 | Sürüm A2: dokunma isabeti paketi — beş düzeltme (web + port) | web + port |
| `0651e5e` | 28.08.2026 | Titreşimli dokunuş kayboluyordu: bırakma kararı için AYRI eşik (web + port) | web + port |
| `48f01a1` | 28.08.2026 | Sürüm B: derin bağlantı kanalı + push bildirimleri (mağaza blokeri) + sözlük/görsel düzeltmeler | web + port |
| `6409458` | 28.08.2026 | Bildirim kanalı IMPORTANCE_HIGH + kanal parite testi + push token yaşam döngüsü | yalnız port |
| `b0cff6e` | 29.08.2026 | Cihaz testi turu: iki push hatası, sistem font ölçeği, offline profil ve görsel düzeltmeler | web + port |
| `0803b95` | 29.08.2026 | Bağlantı dönünce avatar yeniden denensin + 3.5 kaydı | yalnız port |
| `b1aa863` | 29.08.2026 | AD_ID izni kaldırıldı, gizlilik politikasına Google eklendi | web + port |

</details>

### 1.0.1 — 3 mobil commit

*Pencere: 29 Ağu 17:55 → 30 Ağu 13:43*

Tek amaçlı bir sürüm: **zorunlu güncelleme ekranının butonu çalışır hâle
geldi** (`UpdateRequiredScreen` → mağazaya yollama). 1.0.0'ın çıkışsız
ekranının çaresi.

⚠ Aynı gün eklenen **yaş/cinsiyet satırı GERİ ALINDI** (`a6a1776`,
revert #369) — yani bu pakete girmedi. Kütükte "üç commit" görünmesinin
sebebi bu; net içerik tek maddedir.

<details><summary>Commit dökümü (3)</summary>

| sha | Tarih | Ne | Kapsam |
|---|---|---|---|
| `7dd56ad` | 29.08.2026 | Zorunlu güncelleme kullanılabilir hâle getirildi: sürüm 1.0.1 + mağaza butonu | yalnız port |
| `5b77159` | 29.08.2026 | Yaş/cinsiyet satırı tüm skor kartlarında (web + port) | web + port |
| `a6a1776` | 29.08.2026 | Revert #369 — yaş/cinsiyet satırı sıradaki işlerle birlikte yayına girecek | web + port |

</details>

### 1.0.2 — 6 mobil commit

*Pencere: 30 Ağu 13:43 → 31 Ağu 10:20*

**Play In-App Update** bu sürümle geldi — günlük güncelleme yolu. ⚠ Kod
1.0.2'nin İÇİNDE olduğundan sahadaki 1.0.0/1.0.1 kitlesi onu ancak bu
sürüme geçtikten SONRA görür.

Bildirim fazları 1-3 aynı pencerede kapandı: davet bildirimleri canlıya
alındı, **bildirime dokununca doğru yere gitme** ve Analytics'in ilk altı
olayı. Düzeltmeler: hayalet "Devam Eden Oyun" kartı, bekleyen oyun
sıralaması, header'da avatarın komşusunu boyaması, iPhone'da kaybolan pasif
skor kutusu kenarı (`outline` 0.5 → 1 px). Sözlüğe 5 kelime.

<details><summary>Commit dökümü (6)</summary>

| sha | Tarih | Ne | Kapsam |
|---|---|---|---|
| `d3d4702` | 30.08.2026 | Faz 1 paketi + Play In-App Update — sürüm 1.0.2 | web + port |
| `37e68e4` | 30.08.2026 | Faz 2 (davet bildirimleri, canlıda) + kart/ikon cilası ve bir hata düzeltmesi | web + port |
| `afeb08d` | 30.08.2026 | Faz 3: bildirime dokununca doğru yere gitme + Analytics'in ilk altı olayı | yalnız port |
| `c9a4886` | 31.08.2026 | Header'da avatarın komşusunu boyaması + 5 yeni kelime + Faz 4 saha kayıtları | web + port |
| `d3d08a3` | 31.08.2026 | GameHeader: pasif skor kutusunun kenarı iPhone'da kayboluyordu (outline 0.5px → 1px) | web + port |
| `9a611b4` | 31.08.2026 | Hayalet "Devam Eden Oyun" + bekleyen oyun sıralaması + Üyeler başlık satırı sabit | web + port |

</details>

### 1.0.3 — 3 mobil commit

*Pencere: 31 Ağu 10:20 → 31 Ağu 23:08*

**Telemetriden çıkan iki çökmenin düzeltmesi** — sahada ölçülmüş, tahmin
değil: derin bağlantı rotası **11 cihazda** çökertiyordu ve rafta sınır dışı
bir erişim vardı. Ayrıca bildirim rozetinin gerçekten sıfırlanması
(ROADMAP #15) ve "kaç kişi hangi sürümde" ölçümünün açılması (#12).

<details><summary>Commit dökümü (3)</summary>

| sha | Tarih | Ne | Kapsam |
|---|---|---|---|
| `c1c0437` | 31.08.2026 | Sürüm 1.0.3 — appVersion + pubspec birlikte artırıldı | yalnız port |
| `0783783` | 31.08.2026 | Bildirim rozeti gerçekten sıfırlansın (#15) + "kaç kişi hangi sürümde" ölçülebilsin (#12) | web + port |
| `b8d5e78` | 31.08.2026 | Telemetriden çıkan iki çökme: derin bağlantı rotası (11 cihaz) + rafta sınır dışı erişim | yalnız port |

</details>

### 1.0.4 — 2 mobil commit

*Pencere: 31 Ağu 23:08 → 1 Eyl 14:43*

Küçük bir telemetri turu: istemci hata **hız sınırı zamana bağlandı**
(#10), admin panelinde **platform filtresi** (#11), kaynak hunisine
"Bitiren Cihaz" kırılımı.

<details><summary>Commit dökümü (2)</summary>

| sha | Tarih | Ne | Kapsam |
|---|---|---|---|
| `72278c3` | 31.08.2026 | Sürüm 1.0.4 — appVersion + pubspec birlikte artırıldı | yalnız port |
| `cec6cbc` | 01.09.2026 | Telemetri turu: hız sınırı ZAMANA bağlandı (#10) · panelde platform filtresi (#11) · huniye "Bitiren Cihaz" | web + port |

</details>

### 1.0.5 — 11 mobil commit

*Pencere: 1 Eyl 14:43 → 2 Eyl (derleme `4a0a29b`)*

**Tahta zoom'u:** boş kareye/çerçeveye çift dokunuşla 2× büyütme + parmakla
pan, üstüne merkez kareyi işaret eden **tek seferlik tanıtım balonu**. Tek
dokunuşlar birebir korunuyor.

**Yazı boyutu — üçüncü hata sınıfı (SARMA):** sabit genişlikli sütunlarda
metin ölçekle büyüyünce satır kırıyordu; bir kullanıcı bitirme modalında
`241` skorunu `24`/`1` diye okumuştu. Çözüm `ScaledCell`.

Mesaj kutusunun üstüne yönlendirme etiketi. Geri kalanı **APK cihaz
turlarından** dönen düzeltmeler: hamle puanı rozetinin kırpılması ve zoom'da
tahtanın dışına çizilmesi (rozet klibi transform'lu katmandaydı, işe
yaramıyordu), tahta alt şeridinin çevrimdışı hâli, k-lig sütunlarının
sarması, devam eden oyun kartının web'den ayrışması, zoom'da kalıcı çerçeve,
filigranların yazı ölçeğiyle bölgeyi taşırması, bölge çizgisinin kenarda
incelmesi.

<details><summary>Commit dökümü (11)</summary>

| sha | Tarih | Ne | Kapsam |
|---|---|---|---|
| `f28b3da` | 01.09.2026 | Tahta zoom'u (1.0.5): çift dokunuşla 2× büyütme + parmakla pan | yalnız port |
| `db4ae31` | 01.09.2026 | Zoom, APK'dan gelen iki bulgu: bölge çizgisi kenarda incelmesin + kenarlar/boşluklar da çift dokunuş yüzeyi | yalnız port |
| `154cba8` | 01.09.2026 | Hamle puanı rozeti kırpılmasın (APK turu 3) + telemetri sınır notu | yalnız port |
| `f12f10e` | 01.09.2026 | Zoom tanıtım balonu (port): merkez kareyi işaret eden tek seferlik ipucu | yalnız port |
| `a238911` | 02.09.2026 | Yazı boyutu: sabit genişlikli sütunlarda sarma (bitirme modalı puanları bölünüyordu) | yalnız port |
| `df6fcce` | 02.09.2026 | Mesaj kutusunun üstüne yönlendirme etiketi (web + port) | web + port |
| `4a46900` | 02.09.2026 | Cihaz turu: üç bulgu (k-lig sütunları · devam eden oyun kartı · alt şerit) | web + port |
| `a3a7847` | 02.09.2026 | Hamle rozeti zoom'da tahtanın dışına çiziliyordu (web + port) | web + port |
| `d4d85be` | 02.09.2026 | Rozet klibi transform'lu katmandaydı — işe yaramıyordu | web + port |
| `1abbe23` | 02.09.2026 | Tahta alt şeridi + rozet kırpması: portu web ile hizala, çevrimdışı hâli düzelt | web + port |
| `4a0a29b` | 02.09.2026 | Zoom'da kalıcı çerçeve + filigranların yazı ölçeğiyle bölgeyi taşırması | yalnız port |

</details>

### 1.0.6 — 7 mobil commit

*Pencere: 3 Eyl (derleme sonrası) → 4 Eyl (derleme `711eaaa`)*

**Yenilikler:** oyun geçmişindeki aksiyon menüsüne **"Tekrar Oyna"** (biten
bir Canlı oyunun aynı kadrosuyla rövanş daveti), skor kartına **kafa kafaya
oran çubuğu** (+ avatarları 18 → 26 px), biten Canlı oyunlarda **"Yeni"
rozeti**, listelerde "süresi bitmeye en yakın olan üstte" sıralaması.

**Düzeltmeler:** iPad'de asılı kalan paylaşım penceresi, devam eden oyun
kartlarının iki sekmede ayrışması, kafa kafaya oranında teslimlerin
beraberlik sayılması, terk edilen oyunun yanlış güne yazılması.

<details><summary>Commit dökümü (7)</summary>

| sha | Tarih | Ne | Kapsam |
|---|---|---|---|
| `c9f03fd` | 03.09.2026 | ROADMAP temizliği + iki gerçek hata: devam eden oyun kartlarının ayrışması ve iPad'de asılı kalan paylaşım | web + port |
| `76a7151` | 03.09.2026 | Liste sıralaması "bitmeye en yakın üstte" + madde 8 kapanışı (cihaz turu tamam) | web + port |
| `a966dec` | 03.09.2026 | Skor kartına kafa kafaya oran çubuğu + "Tüm Oyunlar" etiketi tekleşti | web + port |
| `a33fdaa` | 03.09.2026 | "Oyun Bitti (Yeni)" — biten Canlı oyunun haberi + sürüm 1.0.6 | web + port |
| `1bfb997` | 03.09.2026 | Kafa kafaya çubuğunun avatarlarını büyüt (18 → 26 px) | web + port |
| `d07c06d` | 04.09.2026 | Admin verisinde iki hata: terk kaydının tarihi ve kafa kafaya teslimi | web + port |
| `711eaaa` | 04.09.2026 | Oyun geçmişine "Tekrar Oyna" (rövanş) + FAZ B ilk gerçek cihaz turunun kaydı | web + port |

</details>


---

## Bir sürüm yüklendiğinde ne yapılır

1. **Kütüğe satır ekle** — sürüm, `versionCode`, `sha`, yükleme tarihi.
   `versionCode` ile `sha`yı BİRLİKTE yaz: sahadaki bir ekran
   görüntüsündeki `Derleme <sha>` satırını Console'daki kayda bağlamanın en
   kısa yolu bu.
2. **`.aab`nin SHA-256'sını yaz** — indirdiğin anda. `mobile-latest` her
   mobil derlemede ÜZERİNE yazıldığından "şu an orada duran paket" ile
   "Play'e yüklediğin paket" birkaç saat sonra aynı şey olmayabilir.
3. **Bir önceki sürümün durumunu güncelle** (yayında → pasif).
4. **"Ne yapıldı — sürüm sürüm"e bir bölüm aç** — özet + commit dökümü.
   Dökümü elle yazma, o bölümdeki `git log --first-parent … -- mobile/app/lib
   …` komutunu koş; "hangi commit gerçekten pakete girdi" sorusunun tek
   dürüst cevabı bu. ⚠ Bir commit'in dokunduğu alanları `--stat` çıktısından
   grep'leme, `--name-only` kullan (bkz. 1.0.6 → #426 vakası).
5. **Sürüm turunu `ROADMAP.md`'de kapat**, kapanınca arşive taşı — bu dosya
   turu değil PAKETİ tutar.

## İnceleme süresi

| Sürüm | Gönderim | Yayın | Süre | Kaynak |
|---|---|---|---|---|
| 1.0.2 (435) | 30 Ağu 15:29 | 15:39 | **10 dk** | Console |
| 1.0.5 (501) | 2 Eyl 17:24 | ~17:58 | **~34 dk** | Console (gönderim) + release satırının "Last updated"ı |
| 1.0.6 (525) | 4 Eyl 15:53 | ≤ 16:22 | **≤ 29 dk** | Console (gönderim) + 16:22'de "Published" görüldü |

⚠ **DÜZELTME (4 Eylül 2026):** bu bölüm daha önce 1.0.5 için **"≈23 dakika
(~14:40 → ~15:03)"** diyordu. O rakam Console'dan değil kullanıcının
bildirdiği anlardan türetilmişti ve **YÜKLEME ile GÖNDERİMİ karıştırıyordu**:
Console'a göre paket 14:22'de YÜKLENDİ ama incelemeye 17:24'te GÖNDERİLDİ.
İkisi arasında üç saat var. Doğru süre ~34 dk.

**Ders:** `.aab`yi yüklemek onu incelemeye sokmaz. Süreyi ölçerken
"Submission activity"deki **gönderim** anını al, paket listesindeki yükleme
anını değil.

⚠ **1.0.6'nın süresi bir ÜST SINIR, ölçüm değil.** Console'un "Submitted"
sütunu gönderim anını verir ama YAYIN anını satırın kendisi göstermiyor;
elimizdeki tek şey 16:22'de çekilen ve satırı "Published" gösteren ekran
görüntüsü. Yani inceleme 29 dakikadan KISA sürmüş, ne kadar kısa
bilinmiyor. Kesin süre satırın ok işaretine girilerek okunabilir —
okunmadı.

Çıkarım: "10 dakika" bir kural değil **alt sınır**; üç ölçümün üçü de
(10 dk · ~34 dk · ≤29 dk) yarım saat bandında. Yarım saati normal say ve
"yayınlanmadı herhâlde" teşhisini bir saatten önce kurma.

⚠ **Published ≠ testçinin telefonunda.** Kapalı testte paket yayınlansa bile
testçiye ulaşması için ayrı koşullar var; ayrıntı ve çare (opt-in linkine
tekrar girme) `build-and-distribution-log.md` → "Kapalı test" bölümünde.
