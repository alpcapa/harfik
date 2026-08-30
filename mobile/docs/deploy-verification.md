# Deploy Doğrulaması — tarihli gözlemler ve post-mortem'ler

`mobile/CLAUDE.md` → "Deploy Doğrulaması" bölümünün ARKA PLANI. Oradaki
kurallar (hangi yüzey nereden yayınlanır, derleme kimliği, üç tuzak, bu
oturumun gözlem sınırı) HER TURDA gerekli; buradaki tarihli anlatılar ise
yalnızca o kuralın NEDEN böyle olduğunu ararken.

⚠ Bu dosya **grep'lenmek** için var, baştan sona okunmak için değil
(30 Ağustos 2026'da `mobile/CLAUDE.md` 81 KB'a çıkıp uyarı bandına girince
ayrıldı — kesme noktası boyut değil İÇERİĞİN TÜRÜ: kural ↔ anlatı).

## Merge sonrası dal hijyeni — 15 Ağustos 2026'nın ikinci hatası

`main` squash merge kullanıyor. Merge edilmiş bir dala yeni commit
eklemeye devam etmek, aynı işi İKİ kez var eder ve bir sonraki merge'de
çakışma üretir. 15 Ağustos'ta bunun bedeli yalnızca çakışma da olmadı:
`AdminDashboard.tsx` "auto-merging" dedi ama 126 satırlık bir bloğu
**iki kez** yazdı; `tsc` yakaladı (`TS2393`/`TS2451`).

**28 Ağustos 2026'dan beri bu kural MEKANİK olarak zorlanıyor:** kullanıcı
GitHub'da "Automatically delete head branches" ayarını açtı, yani merge
edilen dal sunucuda kendiliğinden siliniyor. Artık disipline değil ayara
bağlı — ama tuzağı da beraberinde geliyor: **silinmiş bir dala push etmek
onu DİRİLTİR** ve aynı işi ikinci kez var eder. Merge'den sonra o dala bir
daha dokunma.

## "Koşu yok" demeden ÖNCE — filtre neyi eliyor? (26 Ağustos 2026)

O gün bir merge'den hemen sonra `actions_list`'e **`status: completed`**
filtresiyle bakılıp *"merge sha'sı için tek bir koşu yok"* denildi ve
buradan **yanlış bir kural uyduruldu** ("MCP token'ı Actions'ı hiç
tetiklemiyor"). Gerçek: koşu VARDI, o an `in_progress`'ti; filtre onu doğru
şekilde eliyordu. Kullanıcı ekran görüntüsüyle gösterdi.

**Kural:** bir koşunun yokluğunu iddia etmeden önce `queued` ve
`in_progress`'i de sor — ya da hiç filtre verme. Ve tetiklenme gecikmeli
olabilir: aynı gün bir `pull_request` koşusu push'tan ~20 dakika sonra
başladı, yani "iki dakika sonra baktım, yoktu" hiçbir şey kanıtlamaz.

**Asıl ders bu dosyanın kendisiyle ilgili:** bir gözlemden kural
ÇIKARIRKEN, gözlemin kendisinin bir filtreden geçip geçmediğine bak.
Buraya yazılan yanlış bir kural, hiç yazılmamış olmasından daha zararlı —
sonraki oturum onu ölçüm sanır.

## PR #267 — bir workflow adımının YAML'ı geçerli, ürettiği KABUK SATIRI değil

**PR #267'de CI koştu ve İLK denemede Android'i düşürdü — kaydı önemli:**
`--dart-define=BUILD_TIME=${{ ... }}` TIRNAKSIZDI ve değer boşluk taşıyor
(`15.08 11:58`); kabuk onu ikiye bölüp ikinci parçayı hedef dosya sandı
(`Target file "11:58" not found.`, 32 saniyede düştü). **Yerelde
görünmüyordu:** `flutter test` bu define'ları hiç kullanmıyor ve ben
YAML'ı yalnızca PyYAML ile ayrıştırıp "adım var" diye doğrulamıştım —
derleme komutunu koşmamıştım. Düzeltme sekiz satırda argümanı tırnağa
almak; **negatif eş yerelde kuruldu** (`flutter build web` ile önce hata
birebir üretildi, sonra tırnaklı hâlin derlendiği VE iki sabitin de
`main.dart.js`'e gömüldüğü ölçüldü — `buildLabel` çalışma anında
hesaplandığından birleşik dize aranmaz, iki sabit ayrı ayrı aranır).
**Ders: bir workflow adımının YAML'ı geçerli olması, ürettiği KABUK
SATIRININ doğru olduğunu kanıtlamaz** — değeri boşluk/özel karakter
taşıyabilen her `--dart-define`/argüman tırnaklanmalı ve mümkünse o
komut yerelde bir kez gerçekten koşturulmalı.

## Sistem yazı boyutu — sınıf 2 risk kütüğü (28 Ağustos 2026)

Kullanıcı sordu: *"Bir de başka sessiz sıkışma olan yerler var mı?"* İki
yöntemle arandı; ikisinin de sınırı yazılı, çünkü "temiz çıktı" ile "sorun
yok" aynı şey değil.

**1. Dinamik tarama (takımın tamamı, iki ölçekte).** Her karede tüm
`RenderParagraph`ların genişliği dökülüp 1,0 ile 1,3 karşılaştırıldı.
901 ortak metinden 35'i daraldı, ama bunların çoğu ZARARSIZ: sarabilen bir
metin daralınca yalnızca uzar, bilgi kaybolmaz. Zarar ölçütü daralma değil
**kırpılma** (`didExceedMaxLines || maxLines != null || !softWrap`). O
süzgeçten geçen: **tek bir yer** — `game_history_modal.dart:1150`, oyun
geçmişi satırındaki oyuncu adı, **101,9 → 88,8 px (-13,1)**; sebebi yanındaki
`TESLİM OLDU` rozetinin metin olması. Bilgi sıfırlanmıyor, ~2 karakter
kırpılıyor.

⚠ **Bu taramanın KÖRLÜĞÜ ölçüldü ve önemli:** kullanıcının bildirdiği asıl
hata (arkadaşlık isteği satırı) düzeltme KAPATILIP tekrar koşturulduğunda
bile listede ÇIKMADI — çünkü mevcut testler o satırı 420 px genişlikte ve
kısa bir adla ("Esiner") çiziyor, yani sıkışma o veriyle hiç doğmuyor.
Tarama yalnızca testlerin GERÇEKTEN çizdiği ekranı ve veriyi görür. Dar
ekran + uzun ad gibi uç veriyi ancak ona özel bir test yakalar
(`text_scale_test.dart` tam bunu yapıyor: 360 px + "Esiner Yıldırım").

**2. Yapısal tarama.** `lib/src/ui` altındaki 24 `TextOverflow.ellipsis`
sitesi, "kırpılabilir metin + onu ezebilecek METİN kardeş" desenine göre
tarandı. Beş aday çıktı — **hiçbiri ölçülmedi**, yalnızca desen eşleşmesi:

| Yer | Ezen kardeş |
|---|---|
| `setup_screen.dart:1977` | `SENİN HAMLEN BEKLENİYOR` (11 px, tracking 1 — en uzun etiket) |
| `live_games_tab.dart:683` | sağdaki durum etiketi (`onlineStatusLabel`) |
| `game_over_modal.dart:234` | `(TESLİM)` |
| `game_history_modal.dart:1150` | `TESLİM OLDU` — **ölçülen tek vaka** |
| `recent_games_section.dart:285` | skor metni |

Beşi de aynı ailenin üyesi: satırdaki tek esnek öğe bir isim/başlık, kardeşi
ise ölçekle büyüyen bir metin. **1,3 tavanında beklenen zarar "birkaç
karakter kırpılması" düzeyinde** — arkadaşlık satırındaki gibi sıfıra inen
bir vaka değil; bu yüzden bugün düzeltilmedi. Tavan yükseltilirse ya da
biri cihazda şikayet konusu olursa çözüm aynı: `buyukOlcek(context)` ile
satırı ikiye böl.
