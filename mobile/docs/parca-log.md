# Parça Günlüğü — AKTİF

> **Yeni girişler BURAYA**, en yeni en başta. Bu cilt **Parça 110'dan itibaren**.
>
> **Hangi cilt?** Parça 1-48 → `parca-log-1-48.md` · Parça 49-109 →
> `parca-log-49-109.md` · Parça 110+ → `parca-log.md` (aktif).
> Kod yorumlarındaki "bkz. mobile/CLAUDE.md, Parça N" atıfları bu üçünden
> birine düşer.
>
> ⚠ **Bir cildi BAŞTAN SONA OKUMA — `grep` ile ara.** Ciltler tam da bu
> yüzden var: tek bir atıf için yüz binlerce bayt okumak bağlamı yakar.
>
> **Neden ciltlere ayrıldı (24 Ağustos 2026):** tek dosya 714 KB'a (9.800
> satır) çıkmıştı — 24 Ağustos'taki context split'in ÇÖZDÜĞÜ sorun yer
> değiştirip burada birikmişti. Kesimler bölüm/parça sınırlarından yapıldı,
> hiçbir satır değişmedi. Tekrarını önleyen kontrol:
> `npm run check-doc-size` (bkz. kök `CLAUDE.md` → "Doküman Boyutu
> Bütçesi") — bu cilt de sınıra gelince yenisi açılır.

   - ✅ **Parça 139 — uygulama içinden hesap silme (25 Ağustos 2026,
     ROADMAP madde 2, MAĞAZA BLOKERİ; web + port + migration + Edge
     Function AYNI PR'da):** Apple 5.1.1(v) ve Google'ın veri silme şartı,
     hesap açtıran uygulamalarda uygulama İÇİNDEN başlatılabilen bir silme
     yolu istiyor. `kelimeki.com/hesap-silme/` yalnızca Data safety
     formuna verilen TALEP adresiydi; işi yapan taraf yoktu.
     **Kaskadın tamamı, verilmiş karar (anonimleştirme) ve canlıda ölçülen
     tuzaklar: `docs/decisions/account-deletion.md`** — burada yalnızca
     portu ilgilendiren kısım.
     - **Yeni dosya `ui/auth/delete_account_modal.dart`** — web
       `src/components/DeleteAccountModal.tsx` portu. AÇILIŞTA KURU
       ÇALIŞTIRMA (`previewAccountDeletion`): silinecekler gerçek sayılarla
       listelenir, sıfır satırlar gizlenir, "Kalacaklar" bölümü
       başkalarının korunacak kayıt sayısını söyler. **Kuru çalıştırma
       düşerse silme butonu ETKİNLEŞMEZ** — sunucuya ulaşılamıyorsa (ya da
       hesap silinemez bir hesapsa) butonu açmak yanlış bir söz verir.
     - **`AuthService.previewAccountDeletion`/`deleteMyAccount` +
       `AccountDeletionReport`** (`data/auth_service.dart`). `FunctionException`
       yakalanıp `details['error']` OKUNUYOR: sunucunun Türkçe mesajını
       (ör. *"Yönetici hesabı uygulama içinden silinemez."*) yutup genel bir
       metin göstermek teşhisi imkânsız kılardı — Parça 124'ün ("düşen istek
       'hiç oyunun yok' DEMEZ") aynı sınıfı.
     - **`NeoButtonVariant.red` eklendi** (`ui/game/neo_button.dart`).
       Gölge değerleri accent/gold/orange ile BİREBİR aynı; web'de de tek
       `.btn-raised` sınıfı + `bg-*` deseni var, yani port yeni bir görsel
       dil uydurmuyor. Renk `kRed` — `tokens.dart` dışında renk yazılmıyor
       (`color_tokens_test.dart` bunu zaten tarıyor).
     - **`account_settings_modal.dart`e giriş:** KAYDET'in ALTINDA, bir
       ayracın arkasında, formun akışının DIŞINDA — web'in yerleşimiyle
       birebir ("ayarlarımı kaydediyorum" akışının parçası gibi
       görünmesin). `TapTarget(alignment: Alignment.centerLeft)` — 11 px'lik
       bir metin çıplak bir `GestureDetector` ile Parça 132/134'ün dokunma
       hedefi kuralını çiğnerdi; `centerLeft` çünkü ortalamak hizayı bozar
       ("← Geri" vakası).
     - **Türkçe kuralı yine devrede:** onay kelimesi `SİL` ve karşılaştırma
       `trUpper` ile. Native `toUpperCase()` "sil"i "SIL" (noktasız I)
       yapar ve eşleşme SESSİZCE tutmazdı — kullanıcı doğru kelimeyi yazıp
       butonun açılmadığını görürdü.
     - **`legal_modals.dart` AYNI PR'da güncellendi** (Gizlilik 5. bölüm +
       "Son güncelleme: 25 Ağustos 2026"). Atlansa `legal_text_test.dart`
       düşerdi — ama mobil CI'ın web metnine bağlı tek kapısı O DEĞİLMİŞ:
       **`signup_test.dart` de politikanın 5. bölümünden bir CÜMLE arıyordu**
       (`'30 gün içinde kalıcı olarak silinir'`) ve ilk koşuda 508/509 ile
       düştü. Bulan CI oldu, tarama değil — bu ortamda Flutter SDK yok.
       **Ders:** hukuki metnin bağımlıları `legal_text_test.dart` ile sınırlı
       değil; metni değiştirirken `grep -rn "<değişen cümle>" mobile/app/test/`
       de koşulmalı. İddia yeni gerçeklere bağlandı (uygulama içi yol VAR +
       talep yolu hâlâ 30 gün), silinmedi.
     - **Regresyon:** `account_settings_test.dart`e bir test —
       "HESABIMI SİL" dokunulunca pencere açılıyor, `AuthService.fake` bir
       Supabase client taşımadığından kuru çalıştırma düşüyor, SEBEP
       görünür oluyor ve `KALICI OLARAK SİL` butonunun `onPressed`i `null`
       kalıyor. Yani testin sınadığı şey görünüm değil, yukarıdaki
       "kuru çalıştırma düşerse buton açılmaz" SÖZLEŞMESİ.
     - **Doğrulama sınırı:** gerçek (kuru olmayan) silme bu oturumda HİÇ
       çalıştırılmadı — geri dönüşü yok. Cihaz kontrolleri
       `mobile/TESTING.md` bölüm 21'de; ilk gerçek kullanım ROADMAP madde 4
       (test hesaplarının silinmesi) olacak.
     - **`mobile/` DIŞINDA da dosya değişti** (kök `CLAUDE.md`'nin kuralı):
       `src/lib/api.ts`, `src/components/DeleteAccountModal.tsx`,
       `src/components/AccountSettingsModal.tsx`, `src/legal/*`,
       `supabase/migrations/*`, `supabase/functions/delete-my-account/`,
       `tests/smoke.spec.ts`, `ROADMAP.md`, `README.md`, `TESTING.md`,
       `docs/decisions/account-deletion.md` — hepsi AYNI PR'da.
     - **Yan iş (doküman bütçesi):** `mobile/TESTING.md` uyarı bandındaydı
       (160 KB) ve kural *"bir sonraki dokunuşta böl"* diyor. Test
       ORTAMLARI (web derlemesi, FAZ B cihaz turu, TestFlight, Appetize)
       `mobile/docs/test-ortamlari.md`ye taşındı — kesme noktası içeriğin
       TÜRÜ: burası her sürüm önce baştan koşulan kontrol listesi, orası
       "nereden/nasıl koşulur". Dosya 160 → 141 KB. Hâlâ uyarı bandında;
       bir sonraki dokunuşta sıradaki aday Arkadaşlar + Canlı oyun
       bölümleri (~32 KB).

   - ✅ **Parça 110 — Setup girişli/misafir ayrımı + footer'a "Paylaş"
     (17 Ağustos 2026, `setup_screen.dart`, `setup_screen_test.dart`;
     web `Setup.tsx` AYNI PR'da):** İsteğin kaynağı bölüm 1 spesifikasyonu —
     kullanıcının sözleri: *"Girişli kullanıcılarda Kelimeki logosunun
     altındaki tanıtım yazısı ve linkler kalksın… Bu model birebir app'lerde
     de çalışacak değil mi? O şekilde istiyorum."* İki değişiklik, ikisi de
     yalnızca girişli kullanıcıyı ilgilendiriyor — misafirin görünümüne
     KESİNLİKLE dokunulmadı.
     - **(1) Logonun altındaki tanıtım paragrafı + "Nasıl oynanır? ·
       Arkadaşınla paylaş" satırı artık YALNIZCA `auth.user == null`
       (misafir) iken render ediliyor.** İki `SizedBox(height:20)` vardı:
       biri logo↔paragraf arasında, biri link satırı↔"OYUN TİPİ" arasında.
       **İlk denemede İKİSİ de koşulsuz bırakılmıştı** — bu, girişli
       kullanıcıda 40px'lik bir boşluk üretirdi (web'de tam 20px olması
       gerekirken). Kendi kendine yakalandı: yalnızca İKİNCİ SizedBox
       (link satırından sonraki, "OYUN TİPİ"nin hemen üstündeki) koşulsuz
       bırakıldı — spec'in "portun 20 px'i ZATEN elle yazılmış, silme,
       yerinde bırak" talimatının işaret ettiği tam olarak bu satır. İlk
       SizedBox (logo↔paragraf arası) paragraf/link bloğunun İÇİNE, guest
       şartına taşındı — girişlide artık HİÇBİR telafi marjı olmadan logo
       doğrudan tek bir 20px'lik boşlukla "OYUN TİPİ"ye bağlanıyor (web'in
       ölçülen değeriyle birebir: 20.00px, misafirde 152.50/136.50px'lik
       ölçümler DEĞİŞMEDİ çünkü o dal aynen duruyor).
     - **(2) Footer'daki hukuki link satırı `Row`dan `Wrap`e çevrildi**
       (`alignment: WrapAlignment.center, spacing: 8, runSpacing: 4`) —
       web'in `flex-wrap` güvenlik ağının Flutter karşılığı. Flutter'da bir
       `Row` taşması `RenderFlex overflowed` (debug'da sarı/siyah çubuk,
       release'de kırpma) demek — web'in sessizce yatay kaydırdığı bir
       taşmadan çok daha görünür/yıkıcı bir hata sınıfı, bu yüzden `Wrap`
       zorunlu bir güvenlik önlemi (yalnızca web'i taklit etmek için değil).
       Girişli kullanıcı için üçüncü bir madde eklendi: **"Paylaş"** —
       `Icon(Icons.share, size:12, color:_muted)` + `SizedBox(width:4)` +
       `Text('Paylaş', fontFamily:'SpaceMono', fontSize:10, color:_muted)`,
       hukuki linklerle AYNI punto/renk (`_LegalLink` ile görsel dil
       tutarlı, ama kendisi tıklanabilir bir link stilinde değil — web'in
       glyph+metin ikilisiyle birebir). Dokununca **mevcut `_handleShare`**
       ÇAĞIRILIYOR (yeni bir paylaşım fonksiyonu YAZILMADI) — bu, misafirin
       "Arkadaşınla paylaş" linkiyle BİREBİR AYNI çağrı
       (`(widget.share ?? shareBoard)(png: null, text: 'Hemen ücretsiz
       dene!', url: '$webOrigin/?ref=arkadas', origin:
       shareOriginFrom(context))`), yani admin panelindeki "Kaynak
       Hunisi"nin dayandığı `?ref=arkadas` UTM parametresi korunuyor.
     - **Adı BİLEREK "Arkadaşını Davet Et" DEĞİL "Paylaş"** — o isim
       `FriendsModal`'daki AYRI bir özelliğin (kalıcı davet token'ı,
       `create_friend_invite_link`) adı; bu buton genel bir site/tahta
       linkini `?ref=arkadas` ile paylaşıyor, isim çakışması kafa
       karıştırırdı.
     - **`webOrigin` sabiti** (env.dart) `https://kelimeki.com` — mevcut
       "Arkadaşınla paylaş" testinde zaten `sharedUrl` ==
       `'https://kelimeki.com/?ref=arkadas'` diye doğrulanmıştı, yeni
       "Paylaş" testi AYNI beklentiyi taşıyor.
     - **Test — 4 yeni test, negatif eş gerektirmeyen ama davranışı iki
       yönden (var/yok) sınayan çiftler:** girişlide paragraf/link YOK +
       logo→"OYUN TİPİ" tam 20px; misafirde paragraf/link HÂLÂ var
       (mevcut testler zaten bunu sınıyordu, ek bir "misafirde" testi
       netlik için eklendi); footer'da "Paylaş" misafirde YOK, girişlide
       VAR ve dokununca `_handleShare`'i doğru parametrelerle çağırıyor.
       Mevcut GUEST-variant testler (`'"Arkadaşınla paylaş" ?ref=arkadas
       linkini paylaşır'`, `'tanıtım paragrafı … ORTALI'`, `'Setup başlık
       bloğu ve hukuki alt satır web ile aynı'`, `'logo altındaki yazı
       bloğu…'`) HİÇ DEĞİŞTİRİLMEDİ — hepsi `services()` (auth yok, yani
       `auth.user == null`) kullandığından yeni koşulun `if` dalına
       girmeye devam ediyorlar.
     - **`mobile/` DIŞINDA dosya değişti** (`src/components/Setup.tsx`,
       yeni `src/components/RelationIcons.tsx`'teki `ShareIcon`, kök
       `CLAUDE.md`) → aynı PR'da, aynı commit'te teslim edildi (Parça
       Bitirme Kontrol Listesi madde 1) — port dalında mahsur kalma
       riski yok.
     - **Web tarafındaki `ShareIcon`** Flutter'ın KENDİ `Icons.share`
       (U+E593, `share_baseline`) glyph'inden fontTools ile çıkarılıp
       web'e taşındı — `RelationIcons.tsx`'in kendi belgelediği yöntemle
       (unitsPerEm 512 → 24'lük viewBox, y ekseni ters) ve render edilip
       GÖRSEL olarak doğrulandı (bu dosyanın kendi başlığındaki "codepoint
       hafızadan yazılırsa yanlış glyph çizilir" uyarısı gereği).
     - **Doğrulama sınırı — bu oturumda Flutter/Dart SDK YOK**
       (`flutter: command not found`, Parça 103-109'un aynı sınırı):
       `flutter analyze`/`flutter test` KOŞULAMADI; değişiklikler elle
       (bracket/paren dengesi + tam diff okuması) doğrulandı, tek gerçek
       kanıt CI (`mobile-build.yml`). Web yarısı `npm run lint` +
       `npm run build` + Playwright duman testleriyle (3/3) doğrulandı,
       ayrıca derlenmiş CSS + Chromium ile GERÇEK ölçüm yapıldı (guest
       152.50/136.50px değişmedi; girişli 20.00px; footer buton
       ~52.7×15px, ≈356px'te ikinci satıra sarıyor, negatif eş ile
       — `flex-wrap` kaldırılınca 320px'te GERÇEKTEN yatay taşma
       oluştuğu doğrulanıp geri eklendi).
     - **AYNI GÜN bulunan eksik: footer'da AYRAÇ yoktu (`·`) — "birebir"
       isteğinin ihlali.** Web girişli footer'da `Kullanım Koşulları ·
       Gizlilik Politikası · [ikon] Paylaş` çiziyor: `Setup.tsx`'te
       `<span>·</span>` ile "Paylaş" butonu AYNI `{user && (<>…</>)}`
       fragment'ının içinde, yani girişlide İKİ ayraç var, misafirde BİR.
       Port yalnızca butonu taşımış, ayracı atlamıştı → `… Gizlilik
       Politikası [ikon] Paylaş`. Kullanıcının kuralı açıktı ("Bu model
       birebir app'lerde de çalışacak değil mi? O şekilde istiyorum"),
       yani bu kozmetik bir ayrıntı değil doğrudan bir sapma. Düzeltme:
       `if (auth.user != null)` koşuluna bağlı ikinci bir `Text('·')` —
       stil yukarıdaki mevcut ayraçla BİREBİR aynı (SpaceMono/10/`_muted`),
       yeni bir stil yazılmadı.
     - **Bunun DÖRT test yeşilken hayatta kalmasının sebebi ölçülebilir:**
       eklenen testlerin hepsi metnin VARLIĞINI (`find.text('Paylaş')`)
       doğruluyordu; hiçbiri maddeler ARASINDAKİ tutkalı (ayraç/boşluk)
       ölçmüyordu. Artık iki footer testi ayraç SAYISINI de ölçüyor —
       misafirde `findsOneWidget`, girişlide `findsNWidgets(2)`. Finder
       güvenli: logo altındaki misafir link satırı BOŞLUKLU `' · '`
       kullanıyor (`setup_screen.dart:921`) ve teşhis satırı
       `.join(' · ')` ile TEK bir `Text` üretiyor, ikisi de bu finder'a
       takılmıyor; `account_button`/`score_card`/`player_score_card`'daki
       `TextSpan(text: '·')`'lar ise `Text.rich`in tam metnine gömülü
       olduğundan eşleşmiyor (hepsi grep'lenerek doğrulandı).
     - **Ders — "birebir" bir port isteğinde MADDELERİ karşılaştırmak
       yetmez, ARALARINDAKİ tutkalı (ayraç, boşluk, sıra) da karşılaştır;**
       ve içerik varlığını doğrulayan bir test, bu sınıf bir farkı
       yapısal olarak GÖREMEZ (kök `CLAUDE.md`'nin "negatif eş" dersinin
       kardeşi: aradığın şeyin YOKLUĞUNDA da geçen bir kontrol bir şey
       kanıtlamaz).
     - **Doğrulama sınırı (bu düzeltmeye özgü):** bu oturumda da Flutter/
       Dart SDK YOK, yani spec'in istediği negatif eş (ayracı geri silip
       testin GERÇEKTEN düştüğünü görmek) yerelde KURULAMADI — tek kanıt
       CI. Testin düşeceği aritmetik olarak kesin (ayraç silinince girişli
       footer'da 2 değil 1 `Text('·')` kalır), ama bu bir çıkarım, ölçüm
       değil.

   - ✅ **Parça 111 — misafir giriş uyarısındaki buton "DEVAM" → "OYNA"**
     (18 Ağustos 2026, kullanıcı bildirdi; web `Setup.tsx` ile AYNI PR).
     - **Neden:** uyarı metni üyeliğin faydalarını sayıyor ("istatistikler,
       k-lig ve arkadaşınla canlı oyun için lütfen giriş yapın"), bu yüzden
       "DEVAM" o cümlenin DEVAMI gibi okunup *"devam edersem üyeliğe
       gider"* izlenimi veriyordu — kullanıcının sözleri: *"Yazıyı okuyunca
       devama basmak üyeliğe götürecekmiş gibi düşündürüyor."* Yeni etiket
       ne olacağını söylüyor: misafir olarak oyun başlar.
     - **Davranış HİÇ değişmedi** — `_GuestChoice.proceed` dalı, ✕/dışarı
       dokunuşun oyunu başlatMAması, "GİRİŞ YAP"ın giriş penceresini
       açması aynı. Değişen tek şey `kDialogButton`ın `label`ı.
     - **Test:** `setup_screen_test.dart`'taki misafir akışı `find.text('OYNA')`e
       çevrildi ve ayrıca `expect(find.text('DEVAM'), findsNothing)` eklendi —
       yalnızca yeni etiketi aramak, eski etiket bir şekilde ekranda kalsaydı
       (ör. ikinci bir kopya) bunu göremezdi.
     - **Doğrulama sınırı:** bu oturumda Flutter/Dart SDK YOK (`flutter` ve
       `dart` bulunamadı), yani port testleri yerelde KOŞULAMADI — Dart
       yarısının kanıtı CI. Web yarısı ölçüldü: `tsc` temiz, Playwright
       18/18 yeşil ve negatif eş (modal locator'ı bozulunca ilgili İKİ test
       GERÇEKTEN düştü, üçüncü bir test etkilenmedi) koşuldu.

   - ✅ **Parça 112 — "Kalan Taşlar" (TORBA) dökümü bekleyen taşları
     RAKİBİN eline yazıyordu** (18 Ağustos 2026, kullanıcı bildirdi;
     web `bag.ts`/`RemainingTilesModal.tsx` ile AYNI PR).
     - **Semptom:** kullanıcı torba boşken, son hamlesini onaylamadan önce
       YZ'nin elinde kalacak taşları sayıp **10 puan** buldu; bitiş kartında
       **-7** gördü ve "hata mı var?" diye sordu.
     - **Bitiş kartı DOĞRUYDU** (`endGame` rakibin gerçek rafını topluyor) —
       yanlış olan DÖKÜMDÜ. Kök sebep bir kova boşluğu: `PLACE_TILE` taşı
       raftan ÇIKARIP `state.placed`e koyuyor, `board`a ancak `PLAY` yazıyor;
       `remainingTiles` yalnızca `board` + `myRack`i düştüğünden o aradaki
       taşlar "dışarıda" (= rakipte) sayılıyordu. Fark tam olarak masadaki
       bekleyen taşların puanıydı (10 − 7 = 3).
     - **Port birebir aynı hatayı taşıyordu** — `bag.dart` web'in doğrudan
       portu olduğundan kusur da portlanmıştı; `remainingTiles(board, myRack,
       [placedTiles = const []])` ve modalın `state.placed.values.toList()`
       geçmesiyle iki taraf birlikte düzeltildi.
     - **Bu fonksiyonun HİÇ parite kapsaması yoktu** — `remaining_tiles.json`
       (60 durum, bekleyen taşlı ve jokerli) eklendi ve `run_all.dart` onu
       tüketiyor. Ayrıca `game_screen_test.dart`'a widget regresyonu: taş koy
       → TORBA → **93** kalmalı (düzeltmeden önce 94). Web tarafında
       `npm run verify-remaining-tiles` üretim reducer'ıyla 13 kontrol
       koşuyor ve negatif eşte 7'si GERÇEKTEN düşüyor.
     - **Mevcut golden fixture'lar DEĞİŞMEDİ** (ölçüldü — reducer davranışı
       aynı, yalnızca yeni fixture eklendi).
     - **Doğrulama sınırı:** bu oturumda Flutter/Dart SDK YOK, port testleri
       yerelde KOŞULAMADI — Dart yarısının kanıtı CI. Web yarısı ölçüldü
       (`tsc` temiz, `npm run build` temiz, Playwright 18/18, verify 13/13).

   - ✅ **Parça 113 — k-lig rütbe rozeti yeniden tasarlandı: tırtıklı mühür
     bırakıldı, yerine kurdeleli roset (18 Ağustos 2026, `rank_seal.dart`
     + web `RankSeal.tsx`, AYNI PR):** Kullanıcı: *"Bizim rütbe badge'leri
     beğenmiyorum. Özellikle ince tırtıklar çok kötü. Bana … altı kurdeleli
     badge alternatifleri ver 3 tane. Bizim standart font kullanmak şart
     değil… Albenili ama egzajere değil, basit ama şık bir şey."*
     - **Üç alternatif sunuldu (dolu madalya / çizgisel rozet / altıgen
       madalyon) ve ÜÇÜ DE seçilmedi.** Kullanıcı bunun yerine bir
       **referans görsel** gönderdi (klasik ödül roseti: dolu dalgalı disk +
       içte açık halka + V kesikli iki kurdele) ve *"Bundan istiyorum.
       Rengini sen ayarla"*, ardından *"Bu imajı birebir kopyala ve ona
       giydir"* dedi. Yani tasarım kararı benim üç önerimden değil, o
       görselin oranlarından türetildi — **bir tasarım isteğinde kullanıcı
       kendi referansını verirse, hazırladığın alternatifleri savunma;
       referansı ölçüp kopyala.**
     - **İki dosya AYNI sabit setini taşıyor ve ELLE senkron** (`CY=16.6`,
       `TIP_R=15`, `VALLEY_R=12.675`, `LOBES=14`, `EDGE_W=2`, `RING_R=11`,
       `RING_W=1.3`, beş noktalı kurdele poligonu, `darken`/`sealRibbonColor`
       ×0.86) — web bir `<polygon>`, port bir `Path` çiziyor. Biri
       değişirse öteki de değişmeli; ayrıntılı gerekçeler kök `CLAUDE.md`'de.
     - **CanvasKit güvenliği baştan kuruldu (Parça 18'in dersi):**
       `Path.combine`/PathOps HİÇ kullanılmıyor — eski mührün kesikli iç
       halkası yay yay çiziliyordu, yeni halka düz bir `drawCircle`, o
       karmaşa tamamen kalktı.
     - **Punto merdiveni ÖLÇÜLDÜ, tahmin edilmedi** (web tarafında gerçek
       Space Grotesk 700 ile `canvas.measureText`): tek harf tam boyda
       **18** / kompaktta **20.5**, "+50" **13**, "1000" **10.5**, "+1000"
       **8.5**. Yeni `sealShowsRing(text, {compact})` — halka yalnızca tam
       boyda VE tek harfte; rakamlı glyph'ler halkaya sığmıyor.
     - **`String.length` KULLANILDI, `.characters` DEĞİL** — web `text.length`
       (UTF-16) ile birebir parite; basılabilen tüm glyph'ler (Ç M O U Ş D
       E Z T, rakamlar, '+') tek kod birimi, ayrıca `characters` doğrudan
       bir bağımlılık değil.
     - **`sealBaselineEm` korundu ama sabitleri yeni fonta göre yeniden
       ölçüldü** (`kSealInkAscEm` .71→**.66**, `kSealDescenderEm` .21→**.215**)
       — 12 Ağustos'ta öğrenilen "harf FONT metriklerinden değil MÜREKKEP
       kutusundan ortalanır" kuralı aynen geçerli, yalnızca yazı tipi
       Space Mono'dan Space Grotesk 700'e geçtiği için sayılar değişti.
     - **Test:** `league_rewards_test.dart`'ın mühür testleri yeni tasarıma
       çekildi — punto merdiveni + `sealShowsRing` (yeni test); ilkel sayımı
       artık **4 `drawPath`** (iki kurdele + madalyon dolgu + madalyon kenar)
       ve halka `drawCircle` (tam boyda 1, kompaktta 0), `drawArc` her iki
       boyda da **0**; mürekkep-ortalama testi merkezi `kSealCy`'ye,
       tarama sınırını halkanın içine (10.2) ve mürekkep tespitini BEYAZ
       harfe (`green > 160`, madalyon dolgusu artık kademe rengi) çekti.
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde
       Flutter/Dart SDK YOK (`flutter`/`dart` bulunamadı, Parça 103-112'nin
       aynı sınırı): `flutter analyze`/`flutter test` KOŞULAMADI ve
       **negatif eş kurulamadı** — Dart yarısının tek kanıtı CI. Web yarısı
       tam doğrulandı: `tsc` temiz, `npm run build` temiz, Playwright
       **18/18**, ve GERÇEK üretim bileşeni (esbuild → `renderToStaticMarkup`
       → Chromium/DPR 2) dokuz kademe × dört boy + dört banner glyph'iyle
       render edilip gözle denetlendi. Tanıtım sayfası bütçesi ölçüldü:
       `dist/index.html` ham **254.144** / gzip **22.250** bayt (öncesi
       254.958 / 22.147 — ham −814, gzip +103; ihmal edilebilir).
     - **Cihazda doğrulanacak:** iki `TESTING.md`'nin ilgili maddeleri yeni
       tasarıma göre yeniden yazıldı (eski "tırtık her boyda" maddesi artık
       geçersiz).
     - ⚠️ **Bu parçanın font/punto/metrik notları AYNI GÜN Parça 114 ile
       DEĞİŞTİ** — aşağıya bkz. (yazı tipi artık Space Grotesk 700 değil,
       `kSealInkAscEm` .66 değil).

   - ✅ **Parça 114 — rozetin İÇİNDEKİ font: M PLUS Rounded 1c ExtraBold
     (18 Ağustos 2026, `rank_seal.dart`, `pubspec.yaml`,
     `test/support/test_fonts.dart`, yeni `assets/fonts/…-subset.ttf`
     + web `RankSeal.tsx`/`src/fonts/`, AYNI PR):** Parça 113'ün rozeti
     onaylandıktan hemen sonra kullanıcı: *"Yanlız içindeki font hoşuma
     gitmedi. Daha basık ve yuvarlak hatlı bir font bulalım. Alternatif
     ver bir kaç tane."* Altı aday GERÇEK rozetin içinde render edilip
     gösterildi (tarif edilerek değil — Parça 52'nin kum saati kararıyla
     aynı yöntem), kullanıcı M PLUS Rounded 1c 800'ü seçti.
     - **İKİ platform AYNI alt kümeyi taşıyor** (`pyftsubset`, 108 glyph):
       web 6.3 KB woff2, port **14.4 KB ttf** (`assets/fonts/
       MPLUSRounded1c-ExtraBold-subset.ttf`, `pubspec.yaml`'da
       `MPlusRounded1c` / weight 800). Kaynak TTF 3.6 MB — alt kümeleme
       zorunlu, dosya ÜRETİLMİŞ. Komut ve gerekçe kök `CLAUDE.md` →
       "Rütbe Rozeti Fontu".
     - **GİZLİ BAĞ — yeni bir kademe HARFİ eklenirse subset yeniden
       üretilmeli.** Portta bunun bedeli web'den AĞIR: Flutter otomatik
       font fallback YAPMAZ, kapsam dışı bir glyph **TOFU (boş kare)**
       çizer (bu proje aynı dersi ✓/★/🤖'da üç kez yaşadı). Bugünkü
       aralık ASCII + tüm Türkçe harfleri kapsıyor.
     - **`test_fonts.dart` da yüklemek ZORUNDA:** `flutter_test` pubspec
       fontlarını otomatik yüklemiyor (Parça 1'in dersi) — `loadAppFonts`
       bu aileyi yüklemezse mühürdeki harf Ahem bloğuna döner ve
       `league_rewards_test`in MÜREKKEP-ORTALAMA testi (piksel tarayan
       test) sessizce anlamsızlaşır: blok her zaman kusursuz ortalıdır.
     - **Sabitler yeniden ÖLÇÜLDÜ, taşınmadı** (web tarafında gerçek
       fontla, `canvas.measureText`in `actualBoundingBox*` alanları):
       `kSealInkAscEm` .66 → **.745**, `kSealDescenderEm` .215 → **.22**.
       Bu fontta aralık çok dar — basılabilen HER glyph için azami
       merkezleme sapması 0.0075 em (eski fontta 0.03 em).
     - **Punto merdiveni DEĞİŞTİ ve bu sefer PİKSELLE ölçüldü:** tek harf
       **18** / kompakt **20.5** (AYNI kaldı), 2-3 karakter 13 → **12**,
       4 karakter 10.5 → **9.5**, 5+ 8.5 → **8**. M PLUS'ın rakamları
       Space Grotesk'ten belirgin geniş. **Ders:** `textAnchor="middle"`
       (ve `TextPainter`ın ortalaması) mürekkebi değil ADVANCE kutusunu
       ortalar — yan boşlukları asimetrik bir glyph (`+1000`) yalnızca
       `measureText`le hesaplanan bir tavandan taşar; ilk ladder (12/10/
       8.5) tam bu yüzden beş glyph'te poligonu deliyordu ve bu ancak
       gerçek rozet 20× büyütülüp beyaz pikselleri poligona karşı
       taranarak görüldü.
     - **Test:** `league_rewards_test.dart`'ın `sealFontSize` beklentileri
       yeni merdivene çekildi (20.5 / 18 / 12 / 12 / 9.5 / 8). Mühür
       geometrisi/ilkel sayımı DEĞİŞMEDİ.
     - **Doğrulama sınırı — Parça 113'ün aynısı:** bu oturumda Flutter/
       Dart SDK YOK, `flutter analyze`/`flutter test` KOŞULAMADI ve
       **negatif eş kurulamadı** — Dart yarısının tek kanıtı CI. Web
       yarısı tam doğrulandı (`tsc`, `npm run build`, Playwright 18/18,
       gerçek üretim bileşeniyle 9 kademe × 4 boy + 8 banner glyph'i
       render edilip gözle denetlendi; bütçe ham **254.096** / gzip
       **22.248** bayt + ayrı 6.268 baytlık font asset'i).
     - **Cihazda doğrulanacak:** mühürdeki harfin TOFU olmadığı ve iki
       platformda AYNI göründüğü (özellikle Ç/Ş sedillası ve banner'ın
       `+1000` glyph'i) — `mobile/TESTING.md` bölüm 13.

   - ✅ **Parça 115 — rütbe mührü İSİMLERİN yanına da geldi: yedi yüzey, tek
     toplu sorgu (18 Ağustos 2026, yeni `ui/rank/rank_scores.dart`,
     `data/stats_api.dart`, `account_button.dart`, `score_card_modal.dart`,
     `player_score_card_modal.dart`, `setup_screen.dart`, `friends_modal.dart`,
     `live_game_create_form.dart`, `live_games_tab.dart` + web yarısı AYNI
     PR'da):** Kullanıcı isteği (tam metni kök `CLAUDE.md` → "Rütbe mührü
     artık İSİMLERİN yanında da").
     - **Migration GEREKMEDİ:** `leaderboard` view'ı `user_id`+`total_score`
       veriyor ve `security_invoker = false` ile kilitli RLS'i bypass
       ediyor; yeni `StatsGateway.rankScores(userIds)` tek `in` sorgusuyla
       toplu okuyor. **`player_stats`in mod bazlı toplamıyla KARIŞTIRMA** —
       o ödülleri saymadığı için 17 Ağustos'ta Setup'tan kaldırılmıştı;
       `leaderboard.total_score` ödül DAHİL, yani mühür hesap menüsündeki
       k-lig satırıyla ayrışamaz.
     - **`RankScores` (ChangeNotifier), Riverpod/Bloc yok** (karar #5):
       `tierOf(id)` puan bilinmiyorsa `null` döner (mühür HİÇ çizilmez —
       "0 puan" ile "henüz yüklenmedi" AYRI şeyler), `ensure(ids)` yalnızca
       EKSİK id'ler için ağa gider ve `notifyListeners`ı bir sonraki
       microtask'a erteler; bu yüzden `build` içinden çağrılabilir
       ("setState during build" hatası doğmaz).
     - **Boylar satırın PUNTOSUNA bağlı ve web tarafında ÖLÇÜLDÜ** (derlenmiş
       CSS + Chromium): 12px isim → **16**, 14px → **18**, 16px → **20**.
       Üç sayı da iki platformda ELLE senkron — biri değişirse öteki de.
     - **Başlıktaki 34px'lik mühür KALDI** (o tıklanabilir, `RankInfoModal`'ı
       açar). Bu yüzden `score_card_test.dart`'ın mevcut geometri testi
       artık `find.byType(RankSeal).first` yerine **BOYA göre** seçiyor —
       kartta iki mühür var, sıraya güvenmek kırılgan.
     - **`_PendingGameCard` StatelessWidget olduğundan lookup FONKSİYON
         olarak geçiliyor** (`tierOf`), web'de aynı yerde context kullanıldı
       (orada satır bileşeni dört seviye aşağıda). Üç çağrı yerinin ÜÇÜ de
       geçmek zorunda — biri atlanırsa mühür yalnızca bir kovada çıkar.
     - **Testler:** hesap menüsü (18px + ismin sağında), `FriendsModal`
       ("Arkadaşlarım" satırı), `ScoreCard` (20px isim mührü + 34px başlık
       mührünün DURDUĞU). Beş sahte `StatsGateway` de yeni metodu uygulamak
       zorunda kaldı; `score_card_test`inki gerçek ucun INNER JOIN'ini
       taklit ediyor (`rows`ta olmayan id sonuçta YOK — Parça 46'nın dersi).
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde
       Flutter/Dart SDK YOK (`which flutter dart` → boş), yani
       `flutter analyze`/`flutter test` KOŞULAMADI ve **negatif eş
       kurulamadı** — Dart yarısının tek kanıtı CI (Parça 103-114'ün aynı
       sınırı). Web yarısı tam doğrulandı: `npm run lint`, `npm run build`,
       Playwright **18/18**, ve gerçek Chromium ölçümü (kutular
       16.00/18.00/20.00, boşluk 6.00, dikey merkezler isimle aynı, yatay
       taşma 0; dokuz kademe harfi de tofu'suz).
     - **CI'ın SÖYLEDİĞİ (bu parça yazıldıktan sonra ölçüldü):** `dart
       analyze lib/ test/` temiz ve **454 test yeşil**; web derlemesi de
       geçti. **Ama ilk koşuda DÜŞTÜ** ve sebebi tam da bu sınırdı:
       eklenen test var olmayan bir sahte uç adı (`_FakeFriendsGateway`)
       ve var olmayan bir alan adı (`friendRows`, doğrusu `friendsRows`)
       kullanıyordu — Flutter SDK'sı olan bir oturumda `dart analyze`
       bunu saniyeler içinde yakalardı. **Ders: SDK'sız bir oturumda
       yazılan Dart testinde, kullanılan HER sahte uç/alan adını kaynağa
       karşı grep'le doğrula** — "kodu okudum, doğru görünüyor" burada
       derleyicinin yerini tutmuyor.
     - **Cihazda doğrulanacak:** yedi yüzeyde mühürün göründüğü ve doğru
       kademeyi çizdiği — `mobile/TESTING.md` bölüm 13'e madde eklendi.

   - ✅ **Parça 116 — portun KENDİ ilk açılış tanıtımı: `IntroScreen` +
     hesap menüsünde "Tanıtım" (19 Ağustos 2026, yeni
     `ui/intro/intro_screen.dart`, `storage/flags_store.dart`,
     `ui/app.dart`, `ui/auth/account_button.dart`):** Kullanıcı web'in
     GitHub Pages derlemesine bakıp sordu — *"girişsiz setupda geri ok yok
     değil mi?"*, sonra asıl noktayı koydu: *"Ama bence olmalı sanki.
     App'e gelenler tanıtım görmeyecek mi?"* Sunulan üç seçenekten
     **"Tam tanıtım ekranını şimdi yapalım"** seçildi.
     - **Sezgi ÖLÇÜLDÜ ve doğru çıktı:** grep taraması portun ne bir
       tanıtım ekranı ne de web'deki otomatik "Hızlı Başlangıç" popup'ı
       taşıdığını gösterdi — `FlagsStore.seenQuickstart` depoda VAR ve
       `storage_test.dart`'ta test EDİLİYOR ama **hiçbir UI tüketicisi
       YOK**. Yani uygulamaya ilk gelen, oyunun ne olduğunu hiçbir yerde
       okumadan doğrudan "OYUNU BAŞLAT"a bakıyordu.
     - **Web'in karşılama katmanı OLDUĞU GİBİ port EDİLMEDİ ve bu bilinçli:**
       o katmanın yarısı web'e özgü bir amaca hizmet ediyor (ham HTML'de
       taranabilir metin, SEO, OG kartı, kapı script'i, `?ref=` paylaşımı).
       Porta taşınan şey HİKÂYE: kahraman cümlesi + dört rakam kutusu,
       "Nasıl oynanır?" dört adımı (metinleri ve 5×5 mini ızgaraları
       `Landing.tsx`ten BİREBİR), dokuz k-lig rütbesi. **Metinler ELLE
       SENKRON** — bunu zorlayan bir test YOK (`help_text_parity_test`
       yalnızca `HelpModal`'ı kapsıyor).
     - **Mini ızgara gerçek `BoardWidget` DEĞİL, 25 küçük kareden ibaret**
       (web'in `MiniIzgara`'sının aynısı): tam tahtayı çizmek 169 hücre +
       territory hesabı demek ve tanıtımda anlatılan şey geometri değil
       KURAL. Renkler `playerColors`/`tokens.dart`tan geliyor, yerel kopya
       açılmadı (Parça 54'ün kuralı).
     - **Rütbe tablosu ELLE YAZILMADI**, `kRankTiers` + `RankSeal(size:30)`
       ile çiziliyor — dördüncü bir senkron kopya açmamak için (SQL ↔ TS ↔
       Dart zaten üç kopya). Kelime sayısı web'in `KELIME_SAYISI` sabitiyle
       aynı değeri taşıyan tek bir `kKelimeSayisi` sabitinde.
     - **Kapı (`_HomeGate`, `app.dart`) web'in kapı script'inden YAPISAL
       olarak farklı ve bu kayda değer:** web kararı `<head>`teki senkron
       bir script ile İLK BOYAMADAN ÖNCE veriyor (FOUC yok); portta bayrak
       SharedPreferences'ta, yani asenkron. Bu yüzden karar verilene kadar
       hiçbir şey boyanmıyor (`_showIntro == null` → düz `kBg` ekranı).
       **`services.storage == null` ise kapı HİÇ devreye girmiyor** —
       mevcut testlerin ve önizlemelerin hiçbiri `storage` geçmiyor
       (grep'le doğrulandı), dolayısıyla bu değişiklik onların davranışını
       bit düzeyinde değiştirmedi. Depo AÇILAMAZSA da tanıtım GÖSTERİLMEZ:
       bayrak yazılamayacağı için her açılışta tekrar çıkardı (Parça 45'in
       "ayna kendisi bir kayıp yoluna dönüşebiliyordu" dersinin kardeşi —
       yeni bir katman, hata durumunda kullanıcıyı kilitleyen bir döngü
       kurmamalı).
     - **Bayrak `seen_quickstart` DEĞİL yeni bir `seen_intro`** (web'in
       `kelimeki:seen-intro` anahtarının karşılığı): ikisi farklı şeyler —
       biri "tanıtımı gördü", öteki web'de oyun İÇİNDE çıkan hızlı
       başlangıç popup'ı. Aynı bayrağı paylaşmak, ileride quickstart porta
       gelirse ikisini birbirine kilitlerdi.
     - **Hesap menüsündeki "✨  Tanıtım" bayrağa DOKUNMUYOR** — oradan
       açmak bir "tekrar gösterim" değil kullanıcının kendi isteği; ekran
       `Navigator.push` ile açılıp `onDone`da pop ediliyor. Setup başlığına
       ok KONMADI (gerekçe: "Karşılama Katmanı" bölümü madde 3).
       **BU MADDE AYNI GÜN DEĞİŞTİ — bkz. Parça 117:** menü girişi
       kaldırılıp Setup'ın logo altı link satırına taşındı; "bayrağa
       dokunmuyor" kuralı aynen geçerli.
     - **Test — 5 yeni test (`intro_screen_test.dart`) + 1 kablo testi
       (`account_button_test.dart`):** dört sayfa/DEVAM/BAŞLA/"Atla",
       kapının üç dalı (ilk açılış → tanıtım + bayrak GERÇEKTEN yazılıyor;
       ikinci açılış → doğrudan Setup; depo yok → doğrudan Setup) ve menü
       maddesinin `IntroScreen`'i açtığı. Kapı testleri GERÇEK `AppStorage`
       (sqflite ffi) kullanıyor — bayrağın yazıldığını sahte bir depoyla
       "kanıtlamak" hiçbir şey kanıtlamaz; her birinin sonunda
       `drainRealIo` var (Parça 11/13/64/74'ün dersi).
     - **Mevcut bir testi kırmadan önce düzeltildi:** `account_button_test`
       satır aralığı testi "Hesap Ayarları − Nasıl Oynanır?"ı TEK bir satır
       aralığı sayıyordu; araya "Tanıtım" girince o fark ikiye katlanırdı.
       Ölçüm iki ayrı aralığa bölündü, sıra testine de yeni madde eklendi.
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde
       Flutter/Dart SDK YOK (`which flutter dart` → boş), yani
       `flutter analyze`/`flutter test` KOŞULAMADI ve **negatif eş
       kurulamadı** — Dart yarısının tek kanıtı CI (Parça 103-115'in aynı
       sınırı). Buna karşılık kullanılan HER sembol (sahte uç adları, alan
       adları, `AppStorage.open` imzası, `AppServices` parametreleri)
       kaynağa karşı grep'lendi — Parça 115'te CI'ı düşüren tam olarak bu
       adımın atlanmasıydı. Parantez dengesi de betikle tarandı.
     - **Cihazda doğrulanacak (AYNI GÜN Parça 117 ile güncellendi):**
       temiz kurulumda tanıtımın çıkması, "HEMEN OYNA" sonrası bir daha
       ÇIKMAMASI, Setup'taki "Tanıtım" linkinden her zaman açılabilmesi,
       mini ızgaraların ve dokuz rütbe mührünün doğru çizilmesi (mühür
       fontu M PLUS — TOFU riski, Parça 114) — `mobile/TESTING.md` bölüm
       0.4 (yeni) eklendi.

   - ✅ **Parça 117 — tanıtımdan ATLAMA kaldırıldı; "Tanıtım" menüden
     Setup'ın link satırına, "Paylaş" oradan footer'a taşındı; footer'a
     "© Kelimeki" eklendi (19 Ağustos 2026, `intro_screen.dart`,
     `account_button.dart`, `setup_screen.dart`):** Parça 116'nın ekranını
     gören kullanıcı üç değişiklik istedi (sözleri): *"sadece introyu
     atlama olmasın. Sonuna kadar geçip Hemen Oyna ya da Oyun Başlat vb ile
     setup'a gitmeli. Tanıtımı menüye koymak yerine, paylaş'ı universal
     ikonuyla beraber web'deki gibi footer'a alıp, onun yerine mi koysak.
     Footer'ın altına da "c Kelimeki" olsun"*.
     - **(a) Atlama YOK, tek çıkış son sayfadaki düğme.** Sağ üstteki
       "Atla" satırı tamamen kalktı; son sayfanın düğmesi `BAŞLA` →
       **`HEMEN OYNA`**. Satırın yerine sabit bir `SizedBox(height: 24)`
       kondu — `_Sayfa`nın kendi `top: 8` dolgusu tek başına sayfayı
       ekranın tepesine yapıştırıyordu; yani 44px'lik kontrolü silmek
       dikey ritmi de bozuyordu. Karar web'in karşılama katmanıyla da
       tutarlı: orada da bir kapatma/atlama düğmesi yok.
     - **(b) "Tanıtım" hesap menüsünden Setup'a taşındı.**
       `account_button.dart`'tan üç dokunuş birden çıkarıldı (import,
       `case 'intro'`, `PopupMenuItem`); Setup'ın logo altı link
       satırındaki "Arkadaşınla paylaş"ın yerini aldı ve o paylaşım
       footer'a indi. `seenIntro` bayrağına DOKUNMAMA kuralı aynen taşındı
       (`_openIntro` yalnızca `Navigator.push` + `pop`).
     - **(c) Footer'daki "Paylaş" artık GİRİŞTEN BAĞIMSIZ — bu bir kapsam
       genişletmesi değil, WEB'İN KENDİ davranışı.** `Setup.tsx` okundu:
       o buton `{user && …}` gibi bir koşula BAĞLI DEĞİL (`handleShare`
       oturumdan bağımsız çalışıyor, kod yorumunda da yazılı). Port 17
       Ağustos'ta onu yanlışlıkla girişliye kilitlemişti; iki
       `if (auth.user != null)` guard'ı (ayraç + düğme) kaldırıldı.
       Misafirin footer'ı artık üç maddeli.
     - **(d) "© Kelimeki"** hukuki satırın altına, web'in "Son çağrı"
       footer'ıyla aynı stille (`SpaceMono` 10px, `_muted`) ve aynı 12px
       boşlukla (web `gap-3`, ÖLÇÜLMÜŞ değer) eklendi. Web'de karşılığı
       olmayan teşhis satırı en altta kalmaya devam ediyor.
       - ⚠ **AYNI GÜN BULUNAN HATA — satır SOLA yapışıyordu** (kullanıcı
         cihazda gördü, ekran görüntüsüyle bildirdi; web'de ortalı).
         `textAlign` unutulmuştu: kapsayıcı `Column`
         `CrossAxisAlignment.stretch` olduğundan `Text` tam genişliği
         kaplıyor ve varsayılan hizası `start`. Üstündeki hukuki satır
         `WrapAlignment.center` ile, ALTINDAKİ teşhis satırı da
         `TextAlign.center` ile zaten ortalıydı — atlanan tek satır buydu,
         yani iki komşusunun arasında sessizce ayrıştı.
       - **Bu tür bir sapmayı GEOMETRİYLE ölçemezsin.** `stretch` altında
         `getRect(...).center.dx` iki durumda da ekran merkezini verir;
         kayan şey kutu DEĞİL kutunun içindeki glyph'ler. Mevcut footer
         testi de bu yüzden yeşil kalmıştı (o yalnızca telif satırının
         hukuki satırın ALTINDA olduğunu ölçüyor — dikey sıra doğruydu).
         Regresyon testi bu yüzden boyamayı belirleyen özelliğin kendisini
         ölçüyor: `tester.widget<Text>(...).textAlign == TextAlign.center`
         (aynı dosyada zaten kullanılan bir kalıp, yeni bir yöntem
         icat edilmedi). Hizayı `Center`/`Align` ile sağlayan yeni bir
         footer satırı eklenirse bu assertion da ona göre güncellenmeli.
     - **GÖRÜNÜR SONUÇ, bilerek:** logo altı link satırı YALNIZCA
       MİSAFİRDE çiziliyor (17 Ağustos kararı), yani girişli kullanıcının
       artık tanıtıma dönüş yolu YOK. Bu bir kayıp gibi görünüyor ama
       web'le PARİTE: oradaki `<` düğmesi de yalnızca girişsizde
       render ediliyor ve gerekçesi kök `CLAUDE.md`'de yazılı (girişli
       kullanıcı için o kaçış deliğinin değeri yok — kapı onu zaten
       katmanı hiç göstermeden uygulamaya alıyor).
     - **Test:** `intro_screen_test.dart` — "Atla" testi silindi, kalan
       testler dört sayfayı gezip `HEMEN OYNA`ya basıyor ve **her sayfada**
       `Atla` yokluğunu ölçüyor (tek bir sayfada yokluğunu görmek onu
       başka bir sayfada ekarte etmez); kapı testi de aynı yoldan geçiyor.
       `account_button_test.dart` Parça 116'dan önceki hâline döndü (sıra/
       aralık ölçümleri) + "Tanıtım" menüde YOK assertion'ı.
       `setup_screen_test.dart`: link satırı testi artık `IntroScreen`
       açılışını ölçüyor, footer testleri misafirde de "Paylaş" + İKİ
       ayraç + "© Kelimeki" bekliyor (telif satırının hukuki satırın
       ALTINDA olduğu geometriyle doğrulanıyor).
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde de
       Flutter/Dart SDK YOK, yani `flutter analyze`/`flutter test`
       KOŞULAMADI ve **negatif eş kurulamadı** — tek kanıt CI (Parça
       103-116'nın aynı sınırı). Kullanılan her sembol
       (`IntroScreen`/`kIntroPageCount`/`_InlineLink`/`pumpSetup`/
       `pumpMenu`) kaynağa karşı grep'lendi ve dört dosyanın parantez
       dengesi betikle tarandı.
     - **Cihazda doğrulanacak:** tanıtımda hiçbir sayfada atlama olmaması,
       "HEMEN OYNA"nın Setup'a düşürüp bayrağı yazması, Setup'taki
       "Tanıtım" linkinin (misafirde) tanıtımı açması, footer'ın üç madde +
       "© Kelimeki" göstermesi ve "Paylaş"ın misafirde de çalışması —
       `mobile/TESTING.md` bölüm 0.4 güncellendi.

   - ✅ **Parça 118 — tanıtım ekranı BAŞTAN yazıldı: kullanıcı ilk sürümü
     reddetti, dört slaytın içeriğini kendisi tarif etti (19 Ağustos 2026,
     `ui/intro/intro_screen.dart` yeniden yazıldı + yeni
     `ui/intro/demo_board_data.dart` [ÜRETİLMİŞ] +
     `ui/intro/ozellik_ikonlari.dart`; web tarafında yeni
     `scripts/generate-demo-board-dart.ts`):** Parça 116/117'nin ekranı
     GitHub Pages'e çıkınca kullanıcı ilk slaydı görüp reddetti (sözleri):
     *"Bu tanıtım değil kaçırım olmuş. Bunu göre devam etmez. İlk sayfada
     alttaki boş alanda oyun görseli şart. Webdeki gibi tahtaya bir bak
     bölümünü (sadece ilk 2 kişilik olanı altta yazılarıyla) koy. 2 ve 3
     birleşip 2. slayt olmalı. (Dört bölümde: Nasıl oynanır aynı şekilde 4
     kutu) 3. Slayt: neler var bölümü (webin aynısı 6 kutu) 4. Slayt: k-lig
     bölümü. (Webin aynı gösterim şekliyle (9 kutu) görüntü, tarz, font,
     renk herşey weble aynı olsun.*
     - **Şikâyet estetik değil YAPISALDI:** ilk slayt logo + kahraman +
       paragraf + dört rakam kutusundan ibaretti ve altında koca bir boşluk
       kalıyordu; ekranın ürünü GÖSTERDİĞİ tek yer yoktu. Sayfa sayısı aynı
       (4) kaldı ama içerik tamamen web'in karşılama katmanının bölümlerine
       eşlendi: (1) kahraman + rakamlar + **"Tahtaya bir bak"** (yalnız 2
       kişilik tahta, X2/X3 legend'ı ve altındaki açıklamayla), (2) "Nasıl
       oynanır?" DÖRT adım (eski 2. ve 3. slayt birleşti), (3) "Neler var"
       ALTI kutu, (4) k-lig DOKUZ rütbe.
     - **Tahta ekran görüntüsü/çizim DEĞİL, gerçek `BoardWidget`** —
       `buildSnapshotGameState(kDemoTiles2, 2, [...])` ile besleniyor, yani
       köşe tonlaması/bölge dış hattı/X2/X3/ev işareti oyunda ne
       görünüyorsa birebir o. Web de aynı kararı verdi (`GameBoardPreview`
       → `Board`); ikinci bir "tanıtım tahtası" çizimi bu kod tabanının en
       sık tekrarlayan hata sınıfını (sessiz ayrışma) büyütürdü.
     - **Taşlar ELLE KOPYALANMADI, ÜRETİLİYOR:** `npm run
       generate-demo-board-dart` `src/landing/demoBoard.ts`in
       `DEMO_TILES_2`sini okuyup `demo_board_data.dart`ı yazıyor
       (`generate-golden-vectors`/`generate-logo-paths` ile aynı
       esbuild+node deseni). Gerekçe: o tahtanın her yatay/dikey diziliminin
       gerçek bir Türkçe kelime olduğunu YALNIZCA `npm run
       verify-demo-board` kanıtlıyor ve o betik TS tarafını okuyor — elle
       bir kopya, doğrulanmayan ikinci bir kaynak demek olurdu. **Web
       tahtası değişirse bu komut yeniden koşulmalı** (kök `CLAUDE.md`'nin
       komut tablosuna ve iki README ağacına eklendi).
     - **460/680 kısıtı EKRANDAN alınıp SAYFA İÇERİĞİNE taşındı — bu, tahta
       slaydının ön koşuluydu.** Parça 116'da tüm `IntroScreen` tek bir
       `ConstrainedBox(maxWidth: 460)` içindeydi; tahta orada kalsaydı 428
       px'lik bir kaba sıkışırdı ve `Tile.tsx`'in `vw` tabanlı `clamp()`ı
       yüzünden harf/hücre oranı gerçek oyundan sapardı — **web bu tuzağa
       İKİ KEZ düştü** (kök `CLAUDE.md` → "kök sebep font DEĞİL GENİŞLİKTİ")
       ve çözümü tahtayı metin sütununun DIŞINA, kendi `max-w-[680px] px-3`
       kabına almaktı. Port aynısını yapıyor: `_Kolon` (460, yatay dolgu
       İÇERİDE — `max-w-[460px] px-4` bir border-box'tır, Parça 72'nin
       dersi) metin için, tahta için ayrı bir 680'lik `ConstrainedBox`.
     - **Altı özellik ikonu porta TAŞINDI ve bu bir karar DEĞİŞİKLİĞİ:**
       web'in `OzellikIkonlari.tsx`'i "portta karşılığı YOK ve olmayacak"
       diyordu; "webin aynısı (6 kutu)" isteği onu geçersiz kıldı. Port
       `Icons.*` KULLANMIYOR — web ikonları Material glyph'i değil, ilkel
       şekillerden (daire/dikdörtgen/çizgi/yay) kurulu; `Icons.*` iki
       platformda FARKLI vektör demek olurdu (`RelationIcons` ilkesinin
       tersten uygulanması). Aynı şekiller `CustomPainter` ile çiziliyor.
       **İki dosya ELLE SENKRON — 21 Ağu 2026'dan beri `icon_parity_test.dart`
       zorluyor** (Parça 128); o test yazılırken portun noktaları webden
       küçük çıktı (0.9 ↔ 1.4) ve düzeltildi.
     - **`OzellikIkonTuru` enum'ı + `OzellikIkon.turden` fabrikası** eklendi:
       altı kart bir `const` veri listesinde taşınıyor ve fabrikalar `const`
       olamıyor. Yeni bir ikon eklenirse İKİSİ de (enum + `turden`)
       güncellenmeli.
     - **Rütbe tablosu yine `kRankTiers` + `RankSeal`den çiziliyor** (elle
       yazılmadı) — SQL ↔ TS ↔ Dart zaten üç kopya, dördüncüsünü açmak
       eşik/ödül değişiminde ilk sessizce ayrışacak yeri üretirdi.
     - **`GridView` yerine `IntrinsicHeight(Row(stretch, Expanded…))`**
       (özellik kartları 2 sütun, rütbeler 3 sütun): kart yükseklikleri
       içeriğe göre değişiyor ve sayfa zaten kaydırılabilir bir `Column` —
       sabit en-boy oranlı bir ızgara ya kırpardı ya boşluk bırakırdı.
     - **Dar ekran koruması:** rakam kutularının sayısı/etiketi ve rütbe
       adları `FittedBox(scaleDown)` içinde — 320 px'te "Ücretsiz" 14 px
       mono ile taşıyor ve Flutter'da taşma "RenderFlex overflowed" çubuğu
       demek (web'in sessiz yatay kaydırmasından çok daha görünür bir hata,
       Parça 110'un dersi).
     - **Test — `intro_screen_test.dart`e dört slaydın İÇERİĞİNİ ölçen yeni
       bir test:** tahta (`BoardWidget` + "13×13" + X2 legend'ı), dört adımın
       dördü, altı özellikten ikisi, ve `RankSeal` sayısının
       `kRankTiers.length` olduğu. **Yakalanan finder tuzağı:** 2. slaytta
       "Köşenden başla" ARANMIYOR — 1. slayttaki tahta açıklaması da aynı
       cümleyle başlıyor ve `PageView` komşu sayfayı önbellekte tutuyor;
       iddia adımın gövde metnine ("İlk kelimen köşendeki ev karesine")
       bağlandı.
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumun konteynerinde de
       Flutter/Dart SDK YOK (`which flutter dart` → boş), yani
       `flutter analyze`/`flutter test` KOŞULAMADI ve **negatif eş
       kurulamadı** — Dart yarısının tek kanıtı CI (Parça 103-117'nin aynı
       sınırı). Buna karşılık Parça 115'in dersi uygulandı: kullanılan HER
       sembol (`BoardWidget` alanları, `buildSnapshotGameState`,
       `GamePlayerSnapshot`, `RankTier`/`RankSeal`, `NeoButton`,
       `ShapeDecorationWithCssShadows`/`kRaisedShadows`, `playerColors`,
       `LogoMark`, tokenlar) kaynağa karşı grep'lendi ve iki dosyanın
       parantez dengesi betikle tarandı. Üretilen `demo_board_data.dart`
       52 taşıyla TS kaynağına birebir eşleşiyor (üretici tarafından
       yazıldı, elle düzenlenmedi).
     - **Cihazda doğrulanacak:** dört slaydın içeriği, tahtanın gerçek oyun
       ekranıyla AYNI harf/hücre oranında çizilmesi, dokuz rütbe mührünün
       TOFU olmaması ve dar ekranda "RenderFlex overflowed" çubuğu
       çıkmaması — `mobile/TESTING.md` bölüm 0.4 güncellendi.
     - **CI İLK KOŞUDA DÜŞTÜ ve sebebi tam da o "tek kanıt CI" sınırıydı
       (PR #298, koşu 32246388405 — 455 geçti, 4 düştü):** ilk slayttaki
       dört rakam kutusunun `Row`u `crossAxisAlignment: stretch` taşıyordu
       ve sayfa kaydırılabilir bir `Column` içinde (yükseklik SINIRSIZ) —
       Flutter `BoxConstraints forces an infinite height` ile patlıyor,
       yani IntroScreen'in İLK sayfası hiç render EDİLEMİYORDU (dört
       başarısızlığın dördü de o sayfaya dokunan testler: üç
       `intro_screen_test` + `setup_screen_test`'in "Tanıtım linki"
       testi). **Bu ders bu kod tabanında ZATEN üç kez yazılıydı** (Parça
       3'ün raf satırı, Parça 4'ün skor kutuları, Parça 24) ve aynı
       dosyanın öteki İKİ ızgarası (`_NelerVarSayfasi`, `_RutbeSayfasi`)
       doğru şekilde `IntrinsicHeight` ile sarılmıştı — atlanan yalnızca
       bu üçüncüsüydü. Düzeltme: `_Kutular`ın `Row`u da `IntrinsicHeight`
       içine alındı (stretch KORUNDU — dört kutu web'deki gibi eşit
       yükseklikte kalmalı). **Ders:** `stretch` bir `Column`da yatayda
       (bounded) esnetir, bir `Row`da DİKEYDE (unbounded) — aynı satırı
       Column'dan Row'a kopyalarken bu ayrım sessizce tersine döner ve
       SDK'sız bir oturumda yalnızca CI yakalar.
     - **CANLIDA GÖRÜNCE ÜÇÜNCÜ TUR — alt düğme kalktı, logo dört slayta
       taşındı (19 Ağustos 2026, aynı gün, kullanıcının sözleri):**
       *"Alttaki kocaman Devam butonu çok gereksiz. Altta sadece ince bir
       nokta alanı bıraksak herkes parmakla ilerleyeceğini bilir sadece en
       son slaytta Hemen Oyna olabilir. Diğer 2-3-4 slaytların alt
       kısımlarında büyük boşluk var. Bütünlük açısından ilk slayttaki
       kelimeki logosunu tüm slaytlara taşıyabiliriz."*
       - **`DEVAM` tamamen kalktı**, ilerleme yalnızca `PageView`
         kaydırması; alt şeritte yalnız nokta göstergesi kaldı ve son
         sayfada `HEMEN OYNA` çıkıyor. Kazanılan ~60px doğrudan içeriğe
         gitti — 1. slaytta tahtanın neredeyse tamamı ilk ekrana sığıyor
         (öncesinde alt satırları kesiliyordu). Nokta göstergesi artık hem
         konum hem TEK gezinme ipucu.
       - **`LogoMark` `PageView`ın DIŞINA, sabit üst alana alındı** —
         sayfa başına kopyalanmadı: dört slaytta da tek örnek, birebir
         aynı yerde (web'in kilitli şeridinin porttaki karşılığı; oradaki
         park efekti YOK, slaytlar tek ekran boyunda). 1. slaydın
         görünümü değişmedi, yalnızca logosu bir kat yukarı taşındı.
       - **YAKALANAN GERÇEK TUZAK — `PageView` fareyle SÜRÜKLENMİYORDU:**
         Flutter'ın varsayılan `ScrollBehavior`ı web/masaüstünde fareyi
         `dragDevices`e almaz. `DEVAM` durduğu sürece görünmezdi; kalktığı
         an `alpcapa.github.io`'yu bilgisayardan açan biri slaytlar
         arasında hiç ilerleyemez, atlama da olmadığından tanıtımda
         KİLİTLİ kalırdı (çıkışın tek yolu son sayfadaki düğme).
         `PageView`a tüm `PointerDeviceKind`leri kabul eden bir
         `scrollBehavior` verildi; telefonda davranış birebir aynı.
         **Bu, ekran görüntüsü alınırken ortaya çıktı** — ilk turda dört
         kare de birbirinin AYNISI çıktı, çünkü kaydırma hiç işlemiyordu.
       - **Testler yeni sözleşmeye çekildi** (`intro_screen_test.dart`):
         ilerleme artık `tester.drag(find.byType(PageView), ...)`, ve
         ölçülen üç yeni iddia var — ara sayfalarda HİÇBİR `NeoButton`
         yok, `LogoMark` her sayfada TEK kopya (sayfa başına kopyalansaydı
         bu sayı 1'de kalmazdı), düğme yalnızca son sayfada çıkıyor.
       - **BU OTURUMDA ARTIK SDK VAR:** Flutter stable (3.47) kaba
         kuruldu, yani `flutter analyze` + `flutter test` GERÇEKTEN
         koşuldu (`intro_screen_test` + `setup_screen_test` 29/29) ve
         ekran görüntüleri gerçek `flutter build web` çıktısından,
         Chromium'la 390×844/DPR 2'de alındı — mockup DEĞİL. Parça
         103-118'in "tek kanıt CI" sınırı bu iş için geçerli değil.
     - **DÖRDÜNCÜ TUR — 1. slayt tek ekrana sığdırıldı, kutular
       dengelendi (19 Ağustos 2026, kullanıcı ekran görüntüsüne bakıp
       tarif etti):** *"Birinci slayttaki tahtaya bir bak kalsın sadece,
       oyuna bir bak gitsin ve üstündeki kutulara yakınlaşsın. Böylece tam
       sığacaktır. Bir slaytlarda kutuların daraltıp, aralarındaki
       boşlukları biraz açıp dengeli yapmaya çalış."*
       - Tahta bölümünün `h2`si ("Oyun tam olarak böyle görünüyor")
         KALDIRILDI, yalnız üst başlık kaldı; rakam kutularıyla arası
         36 → **16**, üst başlıkla tahta arası 12 → **8**. Sonuç ÖLÇÜLDÜ
         (390×844): tahta + X2/X3 legend'ı + üç satırlık açıklama artık
         KAYDIRMADAN tek ekranda. `_BolumBasligi`in `baslik`ı bu yüzden
         nullable oldu.
       - Kartlar daraldı, araları açıldı: adım/özellik kartı dolgusu
         12 → **10**, adım kartları arası 10 → **14**, özellik ve rütbe
         ızgaralarının boşluğu 8 → **12**, rütbe kutusu dikey dolgusu
         10 → **8**.
       - **Bunlar web'in DEĞERLERİNDEN bilinçli sapma** (web'de o bölümler
         sonsuz kaydırılan tek bir sayfanın parçası, portta her slayt tek
         ekrana sığmak zorunda). Metin/renk/yapı paritesi aynen duruyor;
         sapan yalnızca boşluk ölçüleri.
       - **YAN BULGU — üst başlıklar TÜRKÇE BÜYÜK HARF kuralını
         çiğniyordu:** Dart'ın `toUpperCase()`i `KELIME`/`FIYAT`/
         `TAHTAYA BIR BAK`/`K-LIG` üretiyordu (noktasız I). Web'de
         dönüşümü CSS `text-transform: uppercase` yapıyor ve
         `<html lang="tr">` sayesinde tarayıcı Türkçe kuralını uyguluyor —
         Chromium'da ÖLÇÜLDÜ: web `KELİME` / `TAHTAYA BİR BAK` / `K-LİG`
         basıyor. Portun tamamında `toUpperCase()`in yalnızca İKİ kullanım
         yeri vardı ve ikisi de bu dosyadaydı; ikisi de
         `kelimeki_core`'un `trUpper`ına çevrildi. **Yeni bir başlık
         eklerken `toUpperCase()` YAZMA** — kök CLAUDE.md'nin "Türkçe Dil
         Notu" kuralı Dart tarafında da geçerli.
     - **BEŞİNCİ TUR — dikey ortalama (üç varyant denendi) ve BEŞİNCİ
       SLAYT: 4 kişilik tahta (19 Ağustos 2026, aynı gün):**
       - Kullanıcı 2/3/4. slaytların altındaki boşluğu sordu; üç hâl de
         gerçek derlemeden ekran görüntüsüyle gösterildi ve **C seçildi**:
         (A) logo sabit + ortalama yok → boşluk altta toplanıyor;
         (B) logo sabit + içerik ortalı → logo ile başlık arasında
         GÖRÜNÜR bir kopukluk açılıyor (ölçüldü, ~250px); (C) logo da
         ortalanan bloğun İLK öğesi → kopukluk yok, boşluk üste taşınıyor.
         Yani logo bir tur önce `PageView`ın DIŞINDAYDI, şimdi `_Sayfa`nın
         içinde — bir üstteki maddedeki "sabit üst alan" kararı bu turda
         GEÇERSİZLEŞTİ.
       - `_Sayfa`ya `ortala` bayrağı: `ConstrainedBox(minHeight) → Center`.
         **`IntrinsicHeight` GEREKMİYOR** — kaydırma görünümü dikeyde
         sınırsız kısıt verdiğinden `Center` çocuğunun boyuna oturur,
         `minHeight` onu en az bir ekran boyuna çeker; içerik uzunsa
         hiçbir şey değişmez. 1. slayt BİLEREK ortalanmıyor (kullanıcı
         "ilk slayt böyle kalsın" dedi ve orası zaten ekranı dolduruyor).
       - **BEŞİNCİ SLAYT** (kullanıcı: *"webdeki 4 oyunculu görseli ve
         altındaki yazıyı da 2. slayt yap. Diğerleri 3-4-5 olsun"*): web'in
         karşılama katmanında bu, 1. slayttaki tahtanın yanındaki yatay
         kaydırmalı ikinci görsel; portta ayrı bir slayt oldu. Metin
         web'den BİREBİR. X2/X3 legend'ı burada TEKRARLANMIYOR — web de
         tekrarlamıyor, ve testte bunun negatif eşi var.
       - **Taşlar yine ELLE KOPYALANMADI:** `generate-demo-board-dart`
         artık `DEMO_TILES_4`ü de yazıyor (`kDemoTiles4`, 70 taş).
         `_TahtaBolumu` parametrik hâle geldi (taşlar/oyuncu sayısı/
         erişim etiketi/açıklama/legend) — ikinci bir tahta bileşeni
         yazmak, doğrulanmayan ikinci bir kaynak demek olurdu.
       - `kIntroPageCount` 4 → **5**; nokta göstergesi ve testler bu
         sabiti okuduğundan başka hiçbir yerde sayı güncellenmedi.

   - ✅ **Parça 119 — 1. slayt HÂLÂ kayıyordu: dört rakam kutusu 2. slayda
     taşındı (19 Ağustos 2026, `intro_screen.dart`,
     `intro_screen_test.dart`):** Kullanıcı cihazda gördü — *"1. slayt hâlâ
     aşağıya kayıyor ve bu app mantığına aykırı. Şöyle yapalım: 1.
     slayttaki board'un üstündeki 4 kutuyu (63K kelime vb) 2. slayt board
     üstüne taşıyalım… Böylece 2 slayt daha dengeli içeriğe sahip olacak ve
     aşağıya kaymayacak. Diğer 3 slayt aynı kalıyor."* Aynen uygulandı.
     - **Parça 118'in "ÖLÇÜLDÜ (390×844): … KAYDIRMADAN tek ekranda"
       cümlesi YANLIŞMIŞ.** O turda tahta başlığı kısaltılıp boşluklar
       daraltılmıştı ve sonuç ölçülmüş gibi yazılmıştı, ama gerçek cihaz
       aksini gösterdi. Bu ortamda Flutter SDK olmadığından o "ölçüm"
       gerçek bir çalıştırmaya dayanamazdı — **bir sonraki oturum bu tür
       bir cümleyi, arkasında koşulmuş bir komut yoksa yazmasın.**
     - **Denge:** 1. slayttan kutular + üstündeki 20px boşluk (~78px)
       düştü; 2. slayt yalnızca tahtadan ibaret olduğu için zaten boştu ve
       o kadar doldu. İki slayt da logo → içerik → tahta ritmini koruyor;
       kutu → tahta mesafesi iki slaytta da AYNI (16).
     - **`_Sayfa`nın `ortala` bayrağı KALDIRILDI.** Beş slaydın beşi de
       artık `true` geçiyordu — tek değerli bir bayrak, bir sonraki
       oturumu artık var olmayan bir ayrımı ("1. slayt ortalanmaz") geri
       getirmeye çağıran ölü yapılandırmadır. Davranış tek; kaydırma
       fallback'i (`SingleChildScrollView`) DURUYOR, daha küçük/dar
       ekranlarda hâlâ devreye girebilir.
     - **ASIL KAZANIM BİR TEST:** `intro_screen_test.dart`e slaydın DİKEY
       `maxScrollExtent`ini ölçen bir kontrol eklendi (420×900'de iki
       tahtalı slayt için de 0 bekleniyor). Bu, o dosyadaki içerik
       testlerinin GÖREMEDİĞİ sınıf: "hangi metin hangi slaytta" ölçen
       assertion'lar, iki slayt da ekrandan taşarken de yeşil kalır —
       nitekim Parça 118'den beri öyle kaldılar. Yardımcı `.first`
       KULLANMIYOR (PageView bir gün komşu sayfayı canlı tutarsa ölçüm
       sessizce yanlış slayda kayardı) ve Scrollable'ı eksenine bakarak
       seçiyor (PageView'ınki yatay). Hata mesajı taşan piksel sayısını
       yazıyor — CI kırmızıya dönerse ne kadar kısaltmak gerektiği doğrudan
       görünür.
     - **AYNI TURDA İKİNCİ BULGU — X2/X3 legend'ı alt alta duruyordu.**
       Kullanıcı sordu: *"Ekrana sığmayınca alta mı atıyor?"* — **HAYIR.**
       Port legend'ı baştan DİKEY kodlamıştı (iki `_Rozet` arasına
       `SizedBox(height: 6)`), yani sığsa da alt alta duruyordu; web ise
       `flex flex-wrap items-center justify-center gap-x-4 gap-y-1.5`
       kullanıyor. Flutter karşılığı `Wrap` (spacing 16 / runSpacing 6 —
       web'in iki gap'i birebir).
       - **Web'in sarma eşiği ÖLÇÜLDÜ** (derlenmiş `dist` + Chromium,
         `http://` üzerinden, sekiz genişlikte): her öğe **166.1px**, ikisi
         + 16px gap = **348.2** → 320px'te SARIYOR, 360px ve üstünde YAN
         YANA. Yani web'de pratikte her telefonda yan yana.
       - **Portun eşiği web'inkinden YÜKSEK ve bu bilinçli:** legend
         `_Kolon`un içinde, yani 16+16 dolgu yiyor (web'in `ul`i dar
         ekranda tam viewport genişliğinde — ölçümde `kap` 320-414 arası
         viewport'a eşit çıktı). Port ~380px altında sarar. Dolguyu
         legend için delmek metin sütunu düzenini bozardı; sarmak zaten
         doğru davranış.
       - **`_Rozet`ten `Flexible` KALKMAK ZORUNDAYDI:** `Wrap` çocuklarına
         SINIRSIZ genişlik kısıtı verir ve orada flex'li bir çocuk
         "RenderFlex children have non-zero flex but incoming width
         constraints are unbounded" ile patlar. Web'de de karşılığı yok
         (`<li>` `shrink-0`).
       - **Testi KONUM ölçüyor, varlık değil:** iki rozetin ekranda
         olduğunu ölçen mevcut assertion, ikisi alt alta dururken de
         yeşildi — bu hatanın aylarca görünmemesinin sebebi tam olarak bu.
         Yeni test iki rozetin `top`unun eşit ve X3'ün X2'nin sağında
         olduğunu ölçüyor (420×900).
       - Yan fayda: bir satır eksildiğinden 1. slayt ~20px daha kısaldı.

     - ⚠ **İKİ YENİ TEST İLK CI KOŞUSUNDA DÜŞTÜ — sebep üründe DEĞİL
       TESTTEYDİ: `intro_screen_test.dart` GERÇEK FONTLARI YÜKLEMİYORDU.**
       Taslak PR #301'in "Analiz + testler" işi: `459 passed, 2 failed` —
       *"1. slayt 29.0 px taşıyor"* ve *"aynı satırda olmalı; üstleri 730.0
       ve 750.0"*. İkisi de UYDURMA bir düzeni ölçüyordu.
       - `flutter_test` pubspec'teki fontları OTOMATİK YÜKLEMEZ;
         varsayılan **Ahem**'de her glyph `fontSize × fontSize` bir
         BLOKTUR. 27 karakterlik legend metni 11px'te **297px** yer kaplar
         — gerçek Space Grotesk'te **144px** (web'de ölçüldü). Yani
         legend test ortamında HİÇBİR genişlikte yan yana sığamazdı, ve
         bütün paragraflar fazladan satırlara sarıp slaydı şişiriyordu:
         29px'lik "taşma" gerçek cihazın değil Ahem'in geometrisiydi.
       - Düzeltme yeni bir mekanizma DEĞİL, projenin kendi altyapısı:
         `setUpAll(loadAppFonts)` (`test/support/test_fonts.dart`).
         Ölçüm yapan kardeş testlerin hepsi (`board_render_test`,
         `game_header_test`, `account_button_test`, `chat_test`…) baştan
         beri bu satırı taşıyor; `intro_screen_test` bugüne kadar YALNIZCA
         metin varlığı ölçtüğü için ihtiyaç duymamıştı — geometri ölçmeye
         başladığı an ihtiyaç doğdu.
       - **KURAL:** bir teste ilk kez `getRect`/`getSize`/kaydırma payı
         gibi bir GEOMETRİ ölçümü eklerken, o dosyanın `loadAppFonts`
         çağırıp çağırmadığını KONTROL ET. Çağırmıyorsa ölçtüğün şey
         ürünün düzeni değil Ahem'in düzenidir — ve test ya sahte bir
         kırmızı (buradaki gibi) ya da daha kötüsü sahte bir yeşil verir.
       - Yan fayda: bu tur, "test yazdım ama koşamadım" durumunda taslak
         PR'ın gerçekten iş gördüğünü gösterdi — hata üretime hiç
         çıkmadan, ilk CI koşusunda yakalandı.

     - ⚠ **TESTİ GEÇTİ AMA CİHAZDA HÂLÂ TAŞIYORDU — test boyu yüzeyi
       temsil etmiyordu (19 Ağustos 2026, aynı gün, merge SONRASI).**
       Kullanıcı GitHub Pages web derlemesini iOS Safari'de açtı: 1.
       slaydın açıklama metninin son satırı kesiliyordu. Test 420×900'de
       yeşildi; **Safari'nin durum çubuğu + alt adres çubuğu görünür
       yüksekliği ~150px kısaltıyor** ve o yüzey hiç test edilmiyordu.
       - **Slaydın gerçek yüksekliği ÖLÇÜLDÜ** (gerçek Space Grotesk/Space
         Mono ttf'leri Chromium'a yüklenip portun `_Kolon` stilleri —
         19/13/12/9px, height 1.3/1.6/1.6/1.5 — birebir kurularak, sonra
         sabit yükseklikler koddan toplanarak): içerik **686/710/701 px**
         (390/414/430 genişlik), krom **47 px**, yani gereken ekran
         **733-757 px** + güvenli alanlar. **Isınma turu ŞART:** ilk
         `document.fonts.ready` fontlar hiç İSTENMEDEN çözülüyor, o yüzden
         ilk ölçüm yedek fontla çıkıyor — ilk turda 390'ın başlığı
         414'ünkinden KISA göründü, yani daha geniş sütun daha çok satır
         demek oluyordu; imkânsız bir sonuç ölçümün bozuk olduğunu
         söyledi.
       - **Kullanıcının önerisi uygulandı (krom kısaldı, içeriğe
         dokunulmadı): 47 → 29 px.** Üst boşluk 16 → **8**, nokta şeridi
         üst dolgusu 8 → **6**, ara sayfaların alt boşluğu 16 → **8**;
         ayrıca `_Sayfa`nın dikey dolgusu 8 → **4** (ve `minHeight`
         telafisi −16 → **−8**; o sayı dolgunun İKİ KATI olmak zorunda).
         Toplam **26 px** kazanıldı — bir açıklama satırı 19.2 px.
       - **Üst boşluğun gerekçesi zaten GEÇERSİZDİ:** yorumu *"`_Sayfa`nın
         `top: 8` dolgusu tek başına sayfayı tepeye yapıştırıyordu"*
         diyordu, ama sayfalar bu turda dikeyde ORTALANMAYA başlamıştı —
         içerik sığdığında `Center` boşluğu zaten eşit dağıtıyor,
         sığmadığında ise o boşluk yalnızca yer çalıyor.
       - **SON SAYFANIN düğme dalına DOKUNULMADI** (`top: 12, bottom: 16`):
         orası zaten en kısa slayt ve HEMEN OYNA'nın dokunma alanı
         daralmamalı.
       - **Test artık İKİ boyda koşuyor:** 420×900 ve **430×740** —
         ikincisi tam olarak "geniş telefon ama kısa görünür alan"
         durumunu, yani kullanıcının baktığı yüzeyi temsil ediyor.
         **DERS:** bir düzen testinin boyu, ürünün gerçekten göründüğü EN
         DAR/EN KISA yüzeyi temsil etmiyorsa test yeşil olsa da hiçbir şey
         garanti etmez; burada "yeşil test + bozuk cihaz" tam olarak bu
         yüzden oldu.

     - ⚠ **ÜÇÜNCÜ TUR — "1. slaytta ekstra bir satır boşluk var" (kullanıcı,
       merge sonrası cihazda; scroll hâlâ çalışıyordu).** Kullanıcının
       teşhisi: *"Tahtaya bak 2. slaytta direkt butonların altındayken 1.
       slaytta ekstra bir satır boşluk var. Onu da 2. slayt gibi yaparsan
       düzelecek."*
       - **ÖLÇÜLDÜ ve teşhis KISMEN çürüdü:** iki slayttaki `SizedBox` de
         BİREBİR 16'ydı, yani fark yapısal değil **optik** — `height: 1.6`
         satır kutusu son satırın ALTINA da leading koyuyor (gerçek Space
         Grotesk'le **2.8px**), 2. slayttaki kutuların ise sert kenarı var.
         Yani "bir satır" değil ~3px; tek başına kaydırmayı durdurmaya
         yetmezdi.
       - **Sihirli sayıyla telafi EDİLMEDİ:** `Text.textHeightBehavior`ın
         `applyHeightToLastDescent: false`'u tam bu iş için var — kutu
         descender'da bitiyor, iki slayt gerçekten aynı hizaya geliyor.
         Kahraman paragrafına ve tahta altı açıklamaya uygulandı
         (ikincisi slaydın SON öğesi, oradaki leading doğrudan yüksekliğe
         biniyordu).
       - **Asıl taşma için boşluklar kırpıldı** (içerik metnine
         DOKUNULMADI): logo→içerik 16→**12**, başlık→paragraf 12→**10**,
         paragraf/kutular→tahta bölümü 16→**12** (İKİ slaytta da aynı
         sayı — kullanıcı ikisinin aynı görünmesini istedi), tahta→legend
         12→**8**, legend→açıklama 12→**8**. Leading'lerle birlikte
         toplam **~23px**.
       - **Test boyları sıkılaştırıldı: 420×900, 430×710, 414×720.**
         **414 EN KÖTÜ DURUM, en dar ekran DEĞİL** — orada kahraman
         başlığı iki satıra sarıyor ama tahta yine geniş; 430'da başlık
         tek satıra sığdığından slayt daha KISA. "Daha dar ekran = daha
         zor" sezgisi burada yanlış ve bu ancak ölçerek görüldü.

     - **Doğrulama sınırı — DÜRÜST KAYIT:** Flutter/Dart SDK yine YOK,
       `flutter test` KOŞULAMADI; yeni testin GEÇTİĞİ de, taşımanın kaymayı
       gerçekten sıfırladığı da bu oturumda kanıtlanamadı. Tek kanıt CI
       (Parça 103-118'in aynı sınırı) ve ardından cihazda gözle teyit.

   - ✅ **Parça 120 — oyun sonu kartına k-lig sütunu + ad artık kırpılıyor
     (20 Ağustos 2026, `game_over_modal.dart` + web `GameOver.tsx`, AYNI
     PR):** Kullanıcı webde bitmiş bir oyunun kartında kaybedenin yanındaki
     **-2**'yi k-lig cezası sanıp "kazanan neden puan almamış? Etki
     analizine ne oldu?" diye sordu.
     - **Önce ÖLÇÜLDÜ, koda dokunulmadı — ve HATA YOKTU:** o -2 rafta kalan
       taşların düşümü (`GameOver.tsx:43`, başlığı zaten "KALAN"), sunucuda
       kazanan `rank 1`/`win`/**+2** almış (k-lig 121 → 123), kaybeden
       `rank 2`/`lose`/**0** (2 kişilikte ikincilik puan getirmez —
       `player_stats`'ın yazılı kuralı), `surrendered` ikisinde de `false`.
       Kullanıcı kanıtı görünce kabul etti. **Ders: "bir şeyi bozmuşsun"
       suçlaması da bir HİPOTEZDİR** — savunmaya geçmeden ve "düzeltmeye"
       kalkmadan önce ölç; burada "düzeltme" çalışan bir puanlamayı
       bozacaktı.
     - **Ama karışıklık MEŞRU'ydu ve ürün olarak kapatıldı:** kart oyunun
       k-lig'e KATKISINI hiçbir yerde göstermiyordu, dolayısıyla tek görünen
       eksi sayı ceza gibi okunuyordu. En sağa `leaguePoints`/
       `formatLeaguePoints`'tan (oyun kartlarıyla AYNI fonksiyonlar) beslenen
       bir k-lig sütunu eklendi — elle hesap YOK, yani kart ile Skor Kartı
       sessizce ayrışamaz.
     - **Aynı turda ONARILAN, ÖNCEDEN de var olan düzen hatası:** ad
       kırpılmıyordu — uzun bir ad ("Yapay Zeka 1"; ad alanının uzunluk
       sınırı YOK) satırı ikiye sarıp 320px'te skoru kartın DIŞINA
       taşırıyordu. Yeni sütun bunu büyütürdü, birlikte düzeltildi.
     - **Genişlikler MÜREKKEPLE ölçüldü, tahminle değil — her kutu KENDİ en
       geniş içeriğine eşit:** "KALAN" başlığı 28.86 → **29**; skor "271"
       20px mono'da **36.72** → **37** (36'da sayı kutusunu birebir doldurup
       soldaki eksiye yapışıyor, "-2208" gibi okunuyordu); "k-lig" başlığı
       19.98 → **20**. Ada yer açmak için başlık 10→**9**, skor 22→**20**.
     - **Kullanıcı SİMÜLASYON İSTEDİ ("yer daralacak, uzun isimde ne olacağını
       göster önce") ve bu işin şeklini değiştirdi:** web'in ÜRETİM
       `<GameOver>`i Node'da `renderToStaticMarkup` ile beş senaryo × üç
       genişlikte render edilip derlenmiş CSS'le Chromium'da ölçüldü/ekran
       görüntüsü alındı — kod yazılmadan ÖNCE. Ölçülen: 390px'te 16
       karakterlik ad bile kırpılmıyor, 360px'te yalnız 13+, 320px'te uzun
       adlar kırpılıyor; **taşma her genişlikte 0**, satır 23px sabit.
     - **İki karar simülasyona bakılarak verildi:** (a) 320px + teslim uç
       durumu OLDUĞU GİBİ bırakıldı (ad erken kırpılıyor, taşma/bilgi kaybı
       yok); (b) "KALAN TAŞ"ı iki satıra bölmek DENENDİ ve geri alındı
       ("altlı üstlü kötü duruyor") — başlık tek satır "Kalan"/`KALAN`.
       Ayrıca alttaki hamle sayısı satırın iki ucundan alınıp etiketin
       YANINA çekildi (8px, ortalı).
     - **21 Ağustos — "Toplam ortalı duruyor" (kullanıcı) ve ölçüm ONU DA
       çürüttü ama şikâyet HAKLIYDI:** sütunlar zaten sağa yaslıydı (16
       satırın 16'sında metnin sağ kenarı = kutunun sağ kenarı; glyph yan
       boşluğu 20px mono'da 0.24, 13px'te −0.04, yani ihmal edilebilir).
       Yanılsamanın kaynağı KUTU BOŞLUĞUYDU: k-lig'in `-` gösterdiği ve
       skorun 2 haneli olduğu satırlarda skorun **solunda 19.5, sağında
       20.0 px** boşluk kalıyor, yani skor komşularının mürekkebi arasında
       TAM ORTALANIYORDU. **Blok sağa çapalı olduğundan sol boşluğu
       Toplam'ın, sağ boşluğunu k-lig'in genişliği belirler; Kalan'ın
       genişliği İKİSİNİ DE etkilemez** — bu yüzden yalnız "kutuları
       daraltmak" simetriyi BOZMUYOR, boşlukların da asimetrik olması
       gerekiyordu. Kutular içeriğe indirildi (32/40/24 → **29/37/20**) ve
       sütun araları 4/4 yerine **4 / 8 / 4** yapıldı (Toplam'ın SOLU daha
       geniş): aynı satır artık **20.5 sola / 16.0 sağa**. Sağ blok
       104 → **100px**; yan fayda 390px'te "Konstantinopolis" kırpılmıyor.
     - **Portun başlık `letterSpacing`'i SESSİZ bir sapmaydı, aynı turda
       düzeltildi:** Dart `0.5` kullanıyordu, web `tracking-wide` = 0.025em
       yani 9px'te **0.225**. Port başlıkları bu yüzden webden genişti
       (KALAN 30.24 vs 28.86) ve yeni dar kutulara SIĞMAZDI — yani bu, kutu
       daraltmanın yan ürünü olarak ortaya çıkan gerçek bir parite hatası.
       `_ColHeader` web'in değerine çekildi.
     - **Portun `_PlayerRow`u artık `playerCount` alıyor** (k-lig puanı için)
       ve ad `Expanded`+`Flexible`+`ellipsis` ile kırpılıyor; `_ColHeader`
       9 punto. Genişlik/punto sayıları iki tarafta ELLE senkron —
       **21 Ağu 2026'dan beri GENİŞLİKLER `layout_parity_test.dart` ile
       zorlanıyor** (Parça 127); puntolar hâlâ korumasız.
     - **Mevcut Dart testleri DEĞİŞMEDİ ve bu kontrol EDİLDİ** (`_PlayerRow`
       dosya-private, `GameOverModal`'ın imzası aynı, `'Toplam hamle'`/
       `'(TESLİM)'` metinleri duruyor) — grep ile doğrulandı, varsayılmadı.
     - **Doğrulama sınırı — DÜRÜST KAYIT:** bu oturumda da Flutter/Dart SDK
       YOK (`which flutter dart` → boş), yani `flutter analyze`/`flutter test`
       KOŞULAMADI ve **negatif eş kurulamadı** — Dart yarısının tek kanıtı CI
       (Parça 103-119'un aynı sınırı). Web yarısı tam doğrulandı:
       `npm run lint` + `npm run build` temiz, Playwright **18/18**, ve
       gerçek üretim bileşeniyle üç genişlikte ölçüm + ekran görüntüsü.
       21 Ağustos turunda da aynı sınır geçerli; web tarafı yeniden ölçüldü
       (320/360/390/834 — yatay taşma **0**, sütun içi taşma **yok**, satır
       yüksekliği sabit) ve önce/sonra ekran görüntüsü alındı.
     - **Cihazda doğrulanacak:** bir oyunu bitirip kartta k-lig sütununun
       çıktığı, teslim olan satırda **-2**'nin k-lig sütununda (Kalan'da
       DEĞİL) durduğu, uzun adların kırpıldığı ve **üç sütunun sayısının da
       kolonun sağına yapışık göründüğü** (özellikle k-lig `-` gösterirken
       skorun ortalı DURMADIĞI) — `mobile/TESTING.md` bölüm 1.

   - ✅ **Parça 121 — "Oyun başladı" telemetrisi (`game_starts`), web + port
     AYNI PR (21 Ağustos 2026, ROADMAP #9):** İlk Instagram kampanyasında
     huninin son adımı KÖR çıktı (`instagram`: 80 kişi / 0 üye / 0 oyun).
     Panel doğruydu; ölçülen ŞEY eksikti — yalnızca BİTMİŞ oyun kaydediliyor,
     yerel oyunun medyanı 18,1 dk, ve "Oyun" sütunu misafir oyunlarını tanım
     gereği hiç görmüyor. Yani "açılış sayfası mı çalışmıyor, oyun mu fazla
     uzun bir taahhüt?" sorusu ayrılamıyordu.
     - **Portun payı:** `GamesGateway.logGameStart` + `GamesRepo.logStart`
       (web `logGameStart` paritesi) ve `StartAction` dispatch eden İKİ ekran
       da onu çağırıyor — `setup_screen.dart` (`_logGameStart`) ve
       `game_screen.dart` ("Tekrar Oyna"). Biri atlanırsa huni sessizce eksik
       sayar; web'de aynı risk tek bir `startLocalGame` yardımcısıyla
       kapatıldı.
     - **Port `anon_id`/`?ref=` GÖNDERMİYOR ve bu bilinçli:** web'in
       `visitTracking.ts`inin karşılığı porta hiç girmedi. İkisi de null
       gidiyor, satır sunucuda `'bilinmiyor'` kaynağına düşüyor — `'direkt'`e
       yazmak web'in gerçek doğrudan trafiğini şişirirdi. Port mağazaya
       çıkarken damgalama eklenirse `SupabaseGamesGateway.logGameStart` de
       güncellenmeli.
     - **Şemada `user_id` YOK** — `legal_modals.dart` bölüm 6'daki "anonim kod
       hesabınızla ASLA eşleştirilmez" taahhüdü bunu yasaklıyor. Metin bu
       PR'da genişletildi (kod artık oyun başlangıcında da, girişliyken de
       gidiyor — ama hesap kimliği olmadan) ve tarih İKİ tarafta birden 21
       Ağustos'a çekildi; `legal_text_test.dart` zaten bunu zorluyordu.
     - **Yeni Dart testi:** `game_record_test.dart` → `logStart` sayaç satırını
       yazıyor VE gateway fırlatsa bile `logStart` fırlatmıyor (telemetri
       hiçbir koşulda oyun başlatmayı düşüremez).
     - **Doğrulama sınırı:** Flutter/Dart SDK bu ortamda yine YOK, Dart yarısı
       yalnızca CI'da koşuyor. Sunucu tarafı canlıda rollback'li senaryolarla
       ölçüldü (anon yazabiliyor/okuyamıyor, girişli okuyamıyor, admin
       olmayan RPC `Yetkisiz erişim.`, damgasız satır `bilinmiyor`a düşüyor).
     - **Cihazda doğrulanacak:** `mobile/TESTING.md` bölüm 4.

   - ✅ **Parça 122 — davet linki `?ref=arkadas` taşıyor (21 Ağustos 2026,
     ROADMAP #7, web + port AYNI PR):** `friends_api.dart`ın `buildInviteUrl`i
     web'in aynı fonksiyonuyla birlikte güncellendi. Port da WEB linki üretip
     paylaşıyor (`$webOrigin/davet/$token`), yani yalnız web'i değiştirmek
     porttan paylaşılan davetleri etiketsiz bırakır ve admin panelindeki
     Kaynak Hunisi'nde `direkt` satırını şişirirdi.
     - **`parseInviteToken` ETKİLENMİYOR:** `uri.pathSegments` sorgu dizesini
       içermez, gelen link uygulamaya düşerse token yine doğru çözülür
       (kod okunarak doğrulandı).
     - **Etiketi YAKALAYAN taraf web** — portta `visitTracking.ts`in bir
       karşılığı yok. Web tarafında asıl hata buradaydı: `captureUtmSource`
       `App.tsx`'teydi ve `/davet/:token` route'u `App`'i hiç mount etmiyor,
       yani etiket konsa bile kaydedilmiyordu; çağrı `boot.tsx`e taşındı.
     - **CI'da 2 test düştü ve HATA BENDEYDİ:** `friends_test.dart` eski URL'i
       İKİ yerde kilitliyordu (`buildInviteUrl` beklentisi + paylaşım
       metninin panoya kopyalanan hâli). Ürünü değiştirip onu kilitleyen
       testleri güncellememek klasik bir regresyon — üstelik etki analizinde
       `parseInviteToken`ın etkilenmediğini OKUYARAK doğrulamıştım ama portun
       TESTLERİNİ hiç grep'lememiştim. **Ders: bir dizeyi/URL'i değiştirirken
       `grep -rn "<eski dize>" mobile/app/test` da koş** — kök `CLAUDE.md`'nin
       "aynı fixture'a bakan testler" maddesi tam bunu diyor.
     - Düzeltirken ilk test GÜÇLENDİRİLDİ: artık yalnızca dizeyi değil,
       etiketli linkin `parseInviteToken` ile hâlâ doğru token'a çözüldüğünü
       de sınıyor (yani sorgu parametresinin ayrıştırmayı bozmadığı artık
       yorumda değil TESTTE yazılı).
     - **Flutter SDK bu ortamda YOK** — hem değişikliğin hem düzeltmenin
       kanıtı CI.

   - ✅ **Parça 123 — istemci hata telemetrisi (21 Ağustos 2026, ROADMAP #3,
     web + port AYNI PR):** portta her çökme `debugPrint`e gidiyordu, yani
     kullanıcının cihazında ölüyordu. Yeni `lib/src/data/error_reporter.dart`
     hataları anonim olarak `client_errors` tablosuna yazıyor; kurallar web'in
     `src/utils/errorReporting.ts`iyle BİREBİR aynı (ayrıntı: kök
     `CLAUDE.md` → "İstemci Hata Telemetrisi").
     - **İKİ yakalayıcı ve ikisi de ŞART, farklı sınıfları görüyorlar:**
       `FlutterError.onError` widget ağacındaki (build/layout/paint)
       hatalarını, `runZonedGuarded` zone dışına kaçan async hataları.
       Yalnızca birini kurmak ötekinin gördüğünü sessizce kaçırır. İkisi de
       `main.dart`'ta, `bootstrap()`ten ÖNCE kuruluyor ki açılış sırasında
       doğan bir hata da yakalansın — gönderim ise Supabase bağlanana kadar
       sessizce düşüyor (`ErrorReporter.configure`, `bootstrap`ten çağrılır).
     - **`FlutterError.onError`'ın ÖNCEKİ değeri çağrılmaya DEVAM EDİYOR** —
       aksi halde yerel geliştirmede kırmızı ekran/konsol logu kaybolurdu.
     - **`route` portta sabit `'app'`:** web'in `location.pathname`i yok;
       ekran adı taşımak yerine yığına bakılıyor. Web'de o alan
       maskeleniyor (`/davet/:token`), portta maskelenecek bir şey yok.
     - **NE KAYDEDİLMEZ kuralı ve tek istisnası:** çevrimdışılık +
       `isNetworkError`a düşen her şey elenir, AMA yalnızca `kind != manual`
       iken. Bu istisnanın TEK sebebi `cloud_save_repo.upsert`'ün "KAYIP"
       noktası (Parça 38/45'in mirası): oradaki hata çoğu zaman AĞ
       hatasıdır, raporlanmaya değer kılan şey AYNANIN DA yazılamamış
       olmasıdır. Koşulsuz bir filtre, telemetrinin var olma sebebi olan
       kaydı tam da sessizce düşürürdü — tasarım turunda yakalandı.
     - **Sink deseni:** `ClientErrorSink` soyut, gerçek uç Supabase; testler
       bellek içi sahte geçiyor. `test/error_reporter_test.dart` 8 test —
       dedup, oturum başına 10 kayıt tavanı, ağ filtresi + `manual`
       istisnası, 500/4000 kırpma, hedef fırlatınca akışın sürmesi.
     - **Admin paneli PORTA GİRMEDİ** (bilinçli, "Üst Düzey Kararlar" #3) —
       "Hatalar" sekmesi yalnızca webde.
     - **Gizlilik metni AYNI PR'da:** `legal_modals.dart` §6, anonim kodun
       üçüncü bir durumda (hata kaydı) da gönderildiğini söylüyor.
       Tarihler `legal_text_test.dart` ile kilitli.
     - **Flutter SDK bu ortamda YOK** — Dart yarısının kanıtı CI.

   - ✅ **Parça 124 — düşen istek "hiç oyunun yok" DEMEZ (21 Ağustos 2026,
     web + port AYNI PR):** Kullanıcının yanındaki gerçek bir oyuncu, sırası
     KENDİSİNDEYKEN Canlı sekmesinde *"Devam eden bir Canlı oyunun yok."*
     gördü; oyun ~9 dakika sonra kendiliğinden geldi. Kök sebep ve dört
     katmanın tamamı kök `CLAUDE.md` → "Düşen istek 'hiç oyunun yok' DEMEZ"
     bölümünde (sunucu logları oradan ölçüldü: 16/16 çağrı 200 ve oyunu
     İÇERİYORDU; kırılan şey ağ değişiminde yarıda kalan istekti).
     - **`OnlineGamesRepo._fetchWithRetry`** — web `retryOnNetworkFailure`
       ile AYNI gecikmeler (**400 / 1200 ms**) ve AYNI dar kapsam: yalnızca
       `isNetworkError` eşleşirse tekrarlanır; sunucunun KENDİ reddi
       (yetki/kural) tekrarlanmaz. Gecikme testlere enjekte edilebiliyor
       (`delay:`) — aksi halde testler gerçek zamanlayıcı beklerdi
       (bekleyen-timer flake sınıfı).
     - **`OnlineGamesGateway.subscribe`'a `onResubscribe` kancası:** kanal
       KOPUP yeniden bağlanınca çağrılır, İLK `subscribed` atlanır. Kopuk
       kanal olay yayınlamaz ve kopukken olanları sonradan OYNATMAZ (28
       Temmuz dersi), yani yeniden bağlanmanın kendisi tek kurtarma sinyali.
       **`subscribeGame`'e DOKUNULMADI** — o tek oyunun kendi kanalı, aynı
       dosyada ve karıştırması kolay.
     - **`LiveGamesTab` artık ÜÇ ayrı cümle kuruyor:** çevrimdışı →
       `kOfflineNoConnection` (değişmedi); bağlantı var + elde liste YOK →
       `kLoadFailedNotice` + **TEKRAR DENE**; liste VAR ama tazelenemedi →
       liste EKRANDA KALIR + ince `kStaleDataNotice` şeridi. **14 Ağustos'ta
       burada `kOfflineNoConnection` gösteriliyordu ve bu 21 Ağustos'ta
       KALDIRILDI** — bağlantısı çalışan kullanıcıya "internet yok" demek
       yanlış bilgiydi (kullanıcının kendi itirazı). Üç metin de
       `offline_notice.dart`ta ve `offline_notice_test.dart` onları web
       dosyasını OKUYARAK karşılaştırıyor.
     - **Otomatik merdiven** (3/8/20/30 sn, son basamak tekrarlanır) web ile
       aynı; `dispose()` timer'ı iptal ediyor.
     - **Testler:** `live_games_test.dart`e 5 repo + 2 widget testi
       (ilk istek düşüp ikincisi başarılı → liste GELİYOR; üç deneme de
       düşerse null; sunucu reddi tekrarlanmaz; yeniden bağlanma sinyali;
       bağlantı varken "internet yok" DEMEZ; liste varken bayat notu).
       Sahte gateway'e `netFailFirst` + `lastOnChange`/`lastOnResubscribe`
       eklendi.
     - **Flutter SDK bu ortamda YOK** — Dart yarısının kanıtı CI.

   - ✅ **Parça 125 — logonun altında "← Geri" (21 Ağustos 2026, web + port
     AYNI PR):** Kullanıcı bildirdi: *"Bazı kullanıcılar oyundan setup'a
     dönüşü bulamıyor."* Logo baştan beri Setup'a dönüyordu — eksik olan
     davranış değil GÖRÜNÜRLÜKTÜ. Karar zinciri ve web ölçümleri kök
     `CLAUDE.md` → "`GameHeader` — logonun altında '← Geri'".
     - **BU, WEB'İ BİREBİR TAŞIYAMADIĞIMIZ nadir yerlerden biri.** Webde
       etiket `absolute` — header'ın yüksekliğine hiç dokunmuyor VE logoyla
       aynı `<button>`ın içinde olduğundan tıklanabilir. Flutter'da bu
       birleşim YOK: kutusunun DIŞINA taşan bir çocuk dokunuş ALMAZ
       (`RenderBox.hitTest` önce `size.contains`e bakıyor), oysa etiketin de
       tıklanabilir olması kullanıcının açık şartıydı.
     - **Çözüm — etiket LOGONUN KENDİ kutusuna çapalı** (logo `Stack` +
       `Clip.none`), header'ın dış kutusuna DEĞİL. Böylece Row ne kadar uzun
       olursa olsun etiket her zaman logonun tam altında; header ve tahta
       bir piksel oynamıyor (webdeki 0px sapmanın aynısı).
     - **⚠ İLK DENEME CI'DA DÜŞTÜ ve gerçek bir hata buldu:** etiket
       header'ın dış Stack'ine konup konumu STACK'İN ÜSTÜNDEN
       hesaplanmıştı. Ama Row logodan belirgin biçimde uzun (CI'da 360px'te
       **48px** — GİRİŞ/avatar ve skor kutusu satır yükseklikleri logodan
       büyük) ve logo o Row içinde ORTALANDIĞINDAN aşağı kayıyor; sabit
       konumdaki etiket logonun ÜSTÜNE BİNİYORDU. Bu ortamda Flutter SDK
       olmadığından ancak CI gösterebildi.
     - **⚠ BİLİNÇLİ SAPMA — etiket portta TIKLANABİLİR DEĞİL:** kutusunun
       dışına taşan çocuk dokunuş almıyor ve bunu aşmanın tek yolu Row'un
       yüksekliğini/hizasını bozmaktan geçiyordu. Kaçış yolu webdeki gibi
       zaten LOGO; etiket onu GÖSTEREN bir ipucu. Webde tek bir `<button>`
       ikisini birden kapsıyor.
     - **Sabitler ELLE SENKRON:** `kBackFontSize` (11) ve `kBackGap` (3) ↔
       web `BACK_FONT_SIZE`/`BACK_GAP`; renk `kText` ↔ `text-text`. Biri
       değişirse öteki de değişmeli — **21 Ağu 2026'dan beri iki SAYIYI
       `layout_parity_test.dart` zorluyor** (Parça 127); renk hâlâ
       korumasız.
     - **Sol kenar hizası:** header'ın 12px yatay dolgusu = Board'unki, yani
       etiket tahtanın sol kenarıyla hizalı. **⚠ Board'un yatay dolgusu
       değişirse hiza sessizce bozulur.**
     - **Testler** (`game_header_test.dart`, 2 yeni): görünür + logonun
       hemen altında + sol kenar 12 + dokunuş logoyla AYNI eylemi yapıyor
       (iki ayrı `GestureDetector`, tek eylem); ve 360/390/834'te skor
       kutusunun logoyla dikey hizası BOZULMUYOR + taşma istisnası yok.
     - **Flutter SDK bu ortamda YOK** — Dart yarısının kanıtı CI.

   - ✅ **Parça 126 — giriş varsayılanı: YZ boşken "Arkadaşınla" açılır
     (21 Ağustos 2026, web + port AYNI PR):** Kullanıcı *"hâlâ YZ tabı
     geliyor oyun olmamasına rağmen"* dedi. Kural ve canlıdan ölçülen veri
     kök `CLAUDE.md` → "Giriş varsayılanına İKİNCİ kural".
     - **Portta İKİNCİ bir hata daha vardı:** `pendingCounts()` ağ hatasında
       `0/0` dönüyordu ve çağıran `_appliedLoginDefault`ı KOŞULSUZ
       tüketiyordu — yani düşen tek bir istek "girişte doğru sekmeyi aç"
       kararını o oturum için yakıyordu. Bu, webde aynı gün düzeltilen
       hatanın portta kalmış ikizi. Artık `null` dönüyor ve karar
       tüketilmiyor.
     - **Karar İKİ yerden tetikleniyor** (`_applyInitialTab`): sayılar
       geldiğinde ve `_cloudSaves` geldiğinde. Hangisinin önce döneceği
       belli değil ve karar İKİSİNİ birden gerektiriyor — yalnızca birinden
       tetiklenseydi, ilk turda ertelenen karar bir daha hiç uygulanmaz,
       yalnızca foreground/Realtime tazelemesini beklerdi.
     - **⚠ İLK SÜRÜM CI'DA DÜŞTÜ (iki MEVCUT `setup_screen_test` testi):**
       kararı hem sayılara hem YZ listesine bağlamıştım, oysa kural (1)
       (bekleyen iş) YZ listesine hiç ihtiyaç duymuyor — YZ listesi
       yüklenmeyen bir hesapta kullanıcı bekleyen işine rağmen YZ
       sekmesinde kalıyordu. Yalnızca YENİ kural eksik veriye duyarlı.
       **Mevcut testlerin bunu yakalaması, testlerin gerçekten davranışa
       bağlı olduğunun kanıtı.**
     - **`decideInitialMainView` + `InitialMainView` ELLE SENKRON** web'in
       `pendingLiveGames.ts`'iyle; `PendingLiveGameCounts` üçüncü alan aldı
       (`activeCount`). Biri değişirse öteki de değişmeli — **21 Ağu 2026'dan
       beri DAVRANIŞ olarak testli** (Parça 128: 112 vakalık tüketici golden
       + CI'da tazelik kontrolü).
     - **Test:** `live_games_test.dart` — 7 kural kontrolü (kullanıcının
       bildirdiği vaka dahil) + `pendingCounts` ağ hatasında null.
     - **Flutter SDK bu ortamda YOK** — Dart yarısının kanıtı CI.

   - ✅ **Parça 127 — düzen paritesi artık CI'da (21 Ağustos 2026,
     `layout_parity_test.dart`):** Kullanıcı sordu: *"Web ve app her konuda
     paralel değil mi? Her seferinde o eksik bu diyip duruyorsun. Emin ol."*
     Ölçüldü ve o an hepsi tutuyordu — ama **pariteyi KORUYAN bir mekanizma
     yoktu.** Bugüne kadar yalnızca beş web dosyası (`HelpModal`,
     Terms/Privacy, `offlineNotice`, `leagueRank`, migration SQL'i) ve golden
     vector'lar zorlanıyordu; düzen SAYILARININ hepsi "ELLE SENKRON, zorlayan
     test YOK" notuyla yaşıyordu. Yeni test o notu **on çiftte** geçersiz
     kılıyor: Dart testi WEB kaynağını okuyup regex'le sayıyı çekiyor ve port
     sabitiyle karşılaştırıyor (`rank_tiers_parity_test.dart` deseni).
     - **Kapsam (altı grup):** (1) `GameHeader`/`UserMenu`'nün 375/465 akıcı
       ailesi — 11 çift (`PLAYER_BOX_WIDTH`…`LOGO_HEIGHT` + üç `GIRIS_*`);
       (2) `Board` filigranları (köşe rakamı / X2 / X3); (3) `GameOver` sağ
       blok sütunları (29/37/20); (4) k-lig OHP sütunu (34); (5) tekrar
       gecikmeleri + otomatik merdiven + çevrimdışı doğrulama süresi;
       (6) "← Geri" puntosu ve boşluğu (11/3).
     - **⚠ EN ÖNEMLİ KURAL — bir değer BULUNAMAZSA test DÜŞER, geçmez.**
       `_pick`/`_pickAll` her çağrıda varlığı `expect` ediyor; aksi halde
       web'de bir sabitin adı değişince test SESSİZCE hiçbir şey
       karşılaştırmaz ve yeşil kalır ("boşa geçen test" — bu kod tabanında
       `rank_tiers_parity_test`'in alt sınır kontrolüyle zaten tanınan risk).
     - **ÖLÇÜLEN HATA — "Board.tsx'teki TÜM clamp'leri say, üç tane olmalı"
       YANLIŞTI.** İlk sürüm tam bunu yapıyordu ve doğrulama koşusunda düştü:
       dosyada **BEŞ** `calc()`siz clamp var — üç filigran + hücrenin taban
       puntosu + "+puan" rozeti — ve son ikisinin portta akıcı bir karşılığı
       YOK. Düzeltme: her filigran ÇİZDİĞİ ŞEYE çapalanıyor (`{num}`, `X2`,
       `'X3'`), sayıya değil. **Ders: parite testinde ADET saymak kırılgan,
       İÇERİĞE çapalamak sağlam.**
     - **`calc()`siz clamp ↔ `fluidSize`:** `clamp(MIN, Bvw, MAX)` portta
       `fluidSize(w, MIN, 0, B, MAX)` demek; test A parametresinin
       gerçekten `0` olduğunu ayrıca kontrol ediyor.
     - **KAPSAM DIŞI (o günün dürüst sınırı):** `TESLIM_FONT_SIZE`,
       `RankSeal` geometrisi, `ozellik_ikonlari.dart` ve
       `decideInitialMainView`. **AYNI GÜN Parça 128 dördünü de kapattı** —
       her biri farklı bir mekanizmayla; aşağı bkz.
     - **Flutter SDK bu ortamda YOK** — testin kendisi üç yoldan doğrulandı:
       (a) her regex'in gerçek kaynak dosyalara karşı Python'da yeniden
       koşturulması (grup 2 hatasını bu yakaladı), (b) Dart dosyasının
       ayraç dengesi, (c) her çapanın `grep`le kaynağında teyidi. Dart
       yarısının kanıtı yine CI.

   - ✅ **Parça 134 — dokunma hedefleri 48 dp; "← Geri" ise TAMAMEN ölüydü
     (24 Ağustos 2026, kullanıcı beş kontrolü de aynı cümleyle bildirdi):**
     *"biraz üstüne basınca çalışıyor"* — alt şerit linkleri, "Detaylı
     Kurallar", "← Geri", avatar. Bir gün önce (Parça 132) alt şerit için
     zaten bir düzeltme çıkılmıştı ve kullanıcı aynı şikayeti tekrarladı.
     - **Neden yetmedi — dersin tamamı sayıda:** Parça 132 dolguyu kaptan
       öğelere taşıdı ("hedefler 18 → 32") ama **ekrandaki kutu hiç
       ÖLÇÜLMEDİ**; `layout_parity_test.dart` yalnızca KAYNAKTA dolgunun
       durduğunu doğruluyor. Yeni `test/tap_target_test.dart` gerçek
       kutuyu ölçtü (390×844): alt şerit **31.0**, "← Geri" **29.3**,
       "Detaylı Kurallar" **14.0** — Material asgarisi 48. Yani düzeltme
       doğru yöndeydi, MİKTARI yanlıştı. Bir dolgu "biraz büyüttük" diye
       değil, ölçülen kutu asgariyi geçtiği için yeterlidir.
     - **KÜRESEL KAYMA DEĞİL (elenen hipotez):** dokunuş koordinatları
       topluca kaysaydı 24 px'lik tahta hücrelerine taş sürüklemek de
       bozulurdu; kullanıcı sorunsuz oynuyor. Sorun tek tek hedeflerin
       küçüklüğü.
     - **"← Geri" YAPISAL bir hataydı, küçüklük değil:** etiket bir
       `Stack(clipBehavior: Clip.none)` içinde `Positioned` ile logonun
       kutusunun DIŞINA taşırılmıştı ve Flutter'da böyle bir çocuk hiç
       dokunuş ALMAZ (`RenderBox.hitTest` önce `size.contains`). Ölçülen
       kutu 90.8 × 29.3 = sadece logo. **Kodun kendi yorumu bunu "bilinçli
       sapma, kaçış yolu webdeki gibi zaten LOGO" diye savunuyordu ve bu
       savunma yanlıştı:** webde etiket `<button>`ın İÇİNDE bir `<span>`
       (`absolute top-full`) ve DOM'da tıklama ataya KABARDIĞI için orada
       pekâlâ çalışıyor. Yani port webi taklit etmiyordu, ondan ayrılmıştı
       — "önce web'e bak" kuralının tam olarak yakalaması gereken sınıf.
     - **Çözüm tek kaynakta:** `ui/tap_target.dart` → `kMinTapTarget` (48)
       + `TapTarget` (çocuğu ORTALAR, görünümü değiştirmez, kutuyu
       büyütür). Uygulandığı yerler: alt şeridin üç linki, "← Geri"
       (artık akışta, logo ile TEK hedef), HelpModal'ın iki linki, avatar,
       GİRİŞ, kimlik yer tutucusu, Setup'ın "Nasıl oynanır? · Tanıtım" ve
       hukuki link satırları, "TÜM OYUNLARIM".
     - **"← Geri"nin bedeli ölçülü:** blok Row'da dikey ORTALANDIĞINDAN,
       etiketin altta kapladığı kadar (`kBackGap + kBackFontSize`) ÜSTTE de
       boşluk bırakılıyor — simetri olmasa logo yukarı kayar ve skor
       kutularıyla hizası bozulurdu (kullanıcının 21 Ağustos'taki
       "header'ı bozmadan" şartı; `game_header_test.dart` 1 px toleransla
       kilitliyor). Header ~25 px uzuyor; tahta bir `SingleChildScrollView`
       içinde olduğundan yalnızca kaydırma boyu değişiyor.
     - **İKİ BİLİNÇLİ İSTİSNA, gerekçesi kendi dosyasında:** akan
       paragrafın içindeki `WidgetSpan` linki (`legal_modals.dart`) —
       büyütmek satır yüksekliğini bozar; ve her mesaj baloncuğundaki 9
       puntoluk sessize alma/raporlama rozeti (`chat_thread.dart`) —
       sohbetin her satırını şişirirdi, aynı panele başlıktaki dişliden de
       ulaşılıyor.
     - **WEB DE AYNI KUSURU TAŞIYORDU (paylaşılan hata, port kusuru
       değil):** `Board.tsx` alt şeridi, `HelpModal.tsx`'in iki linki,
       `Setup.tsx`'in link/hukuki satırları `min-h-[48px]` aldı;
       `UserMenu.tsx`'in avatarı `min-w/h-[48px] -m-2` ile büyüdü — negatif
       marj dış kutuyu 32'ye geri çektiğinden **webde düzen bir piksel bile
       oynamıyor** (Flutter'da negatif marj olmadığından portta bedeli
       header'ın uzaması).
     - **Lider tablosu/skor kartı "boş açılıyor" — durum vardı, OKUNMUYORDU:**
       kullanıcı *"önce 1-2 saniye bir popup görüyorum, sonra sıralama
       üstüne geliyor"* dedi. `leaderboard_modal` ve `ScoreStatsSection`
       zaten "Yükleniyor…" gösteriyordu ama 12 punto, gri, küçük harf.
       İki platformda tek bileşene alındı (`KLoadingNote` /
       `LoadingNote`): 13 punto, kalın, accent, harf aralıklı. Metin
       BİLEREK aynı kaldı (kullanıcı alışkanlığı + birkaç test bu dizeyi
       arıyor). **ANİMASYON YOK ve bu bilinçli:** sonsuz tekrarlı bir
       spinner `pumpAndSettle` ile dinginleşmez, yani bu durumu ekranda
       gören 20'den fazla widget test dosyası zaman aşımına düşerdi.
       Gecikmenin kendisi UI'ın işi DEĞİL — lider tablosu sorgusu sunucuda
       ölçüldü: **4.3 ms yürütme / 15 ms planlama**; kalanı mesafe
       (veritabanı `ap-south-1`/Mumbai, bkz. `docs/decisions/product-backlog.md`).
     - **Testler:** `tap_target_test.dart` artık ölçmekle kalmıyor, 48
       asgarisini İDDİA ediyor (avatar + GİRİŞ eklendi; ölçüm CI log'una
       basılmaya devam ediyor). `game_header_test.dart`e "etikete dokunmak
       da Setup'a döner" regresyon kilidi eklendi. `layout_parity_test`in
       alt şerit testi 4/10 dolgusu yerine iki tarafta da 48 asgarisini
       kontrol ediyor; `setup_screen_test`in paragraf→link boşluğu 16 → 33
       (metin artık 48'lik kutunun ORTASINDA).
     - **Doğrulama sınırı:** bu ortamda Flutter/Dart SDK YOK —
       `dart analyze`/`flutter test` KOŞULAMADI, Dart yarısının kanıtı CI.
       Değiştirilen her Dart dosyasının ayraç dengesi elle tarandı ve
       parite testlerinin regex'leri gerçek kaynaklara karşı Python'da
       yeniden koşturuldu. Web tarafı temiz: `tsc`, `npm run build`,
       Playwright **29/29**. Cihazda teyit kullanıcıdan bekleniyor.

   - ✅ **Parça 135 — "← Geri" ayrı satıra taşındı; yükleme durumu artık
     pencereyi büyütmüyor (24 Ağustos 2026, cihaz testinin İKİNCİ turu):**
     Parça 134'ten sonra kullanıcı `71eb73a` derlemesini iPad'de denedi.
     - **"Geri tuşu tam üstüne basarsan ok ama biraz altına gelirse
       çalışmıyor. Geri ile board arasındaki boşluğu biraz kısarsak hem
       daha iyi çalışır hem de header'ı bu kadar büyütmüş olmayız."**
       Ölçüm: Parça 134'ün çözümü etiketi logoyla aynı `TapTarget`e almıştı
       ve blok Row'da dikey ORTALANDIĞINDAN, logonun skor kutularıyla
       hizasını korumak için etiketin altına eklenen her 1 px header'a
       **2 px** ekliyordu. Yani "altına pay ekle" ile "header küçülsün"
       matematiksel olarak çelişiyordu — üç seçenek kullanıcıya sayılarıyla
       sunuldu, seçimi "Geri'yi tahtanın üstüne al" oldu.
     - **Yeni düzen:** header satırı yalnızca logo + skor kutuları + hesap
       (hepsi 48 px'lik hedefler, hiza korunuyor); "← Geri" ise ayrı bir
       satır olarak tahtanın üstündeki **zaten var olan** boşluğu
       kullanıyor — o boşluk artık tıklanabilir. Logo+skor bandı 77 → 58
       px; etiketin altında 13 px pay var; logo ↔ etiket arası 3 → ~9 px
       (etiket artık logonun kutusuna değil SATIRIN altına çapalı, satırın
       boyunu 48'lik hedefler belirliyor).
     - **Yeni gerekçeli istisna:** etiketin kutusu 48 GENİŞ ama 24 YÜKSEK
       (`TapTarget.minHeight` — bu tur eklendi). 48'lik bir yükseklik
       header ile tahta arasına 20 px'lik boş bir bant açardı ve hemen
       üstündeki logo aynı eylem için zaten tam boy bir hedef.
     - **Web DEĞİŞMEDİ ve bu bilinçli:** orada etiket `<button>`ın içinde
       mutlak konumlu bir `<span>` ve DOM'da tıklama ataya kabardığından
       hem 3 px yukarıda durabiliyor hem tıklanabiliyor. Ayrışan şey değer
       değil YAPI; `layout_parity_test` artık `kBackGap`i karşılaştırmak
       yerine bu ayrımı kayda geçiriyor (ve `kBackGap`in geri gelmesini
       yakalıyor).
     - **"Tek pencere açılmalı, datanın olduğu kısımda yükleniyor
       yazmalı":** *"Leaderboard ve skor kartı arkada küçük pencerede
       yükleniyor (1-2 saniye) çıkıyor sonra büyük pencereler geliyor."*
       Sebep Parça 134'ün eksiği DEĞİL, `KModal`in yüksekliğini içeriğinden
       alması (`MainAxisSize.min` + dikey ortalı): yüklenirken içerik tek
       satır → küçük pencere; veri gelince iki yöne birden büyüyor. Artık
       yer BAŞTAN ayrılıyor — lider tablosunda listenin KENDİ tavanı kadar
       (ekranın %50'si), skor kartında aynı ızgara `—` değerleriyle
       çizilerek. **Aynı kusur webde de vardı**, iki taraf birlikte
       düzeltildi.
     - **Paylaş penceresinin konumu — hata DEĞİL:** Safari'nin kendi
       paylaşım sayfası; webde konumunu uygulama seçemiyor. Native tarafta
       `sharePositionOrigin` zaten veriliyor (`share_board.dart`,
       `friends_modal.dart`) — değişiklik gerekmedi, kayda geçsin diye
       yazılı.
     - **Testler:** `game_header_test.dart` artık etiketin ALTINA
       dokunulduğunda da Setup'a dönüldüğünü iddia ediyor (`tapAt`,
       `kBackBottomPad / 2`); logo↔etiket arası sabit sayı yerine aralık
       olarak kilitli, çünkü satırın boyu artık 48'lik hedeflerden türüyor.
     - **Doğrulama sınırı:** Flutter SDK bu ortamda yok; Dart yarısının
       kanıtı CI. Web: `tsc`, `npm run build`, Playwright 29/29.

   - ✅ **Parça 136 — "Paylaş" atlanmıştı; kutusuz hedef taraması artık
     TESTTE (24 Ağustos 2026, cihaz testinin ÜÇÜNCÜ turu, Android):**
     kullanıcı *"footerdaki paylaşın hâlâ tıklanmadığını farkettim, yine
     yukarısına dokunmak gerekiyor"* dedi.
     - **Kök sebep düzeltmede değil TARAMADAYDI:** Parça 134'te kutusuz
       dokunulabilirleri ararken "GestureDetector'ın DOĞRUDAN çocuğu `Text`
       mi" diye baktım; Setup footer'ındaki "Paylaş"ın çocuğu ikon + metin
       taşıyan bir `Row` olduğundan desene hiç takılmadı. Yani düzeltme
       doğruydu, KAPSAMI eksikti.
     - **İki katmanlı ders, ikisi de uygulandı:** (1) tarama çocuğun
       TÜRÜNE değil, kutuya bir ÖLÇÜ veren bir şey (`padding`, `width`,
       `height`, `SizedBox`, `Container`, `constraints`, `TapTarget`…)
       olup olmadığına bakmalı; (2) **elle koşulan bir tarama bir daha
       koşulmaz** — `tap_target_test.dart` artık `lib/src/ui` altını
       kendisi tarıyor ve kutusuna hiç ölçü vermeyen her
       `GestureDetector`/`InkWell`i düşürüyor. 11 gerekçeli istisna adıyla
       ve sebebiyle listeli (`_olcusuzIstisnalar`); yeni bir tanesi
       eklenirse CI kırmızı olur.
     - **Aynı taramanın ortaya çıkardığı öteki hedefler:** skor kartının
       "k-lig #N · puan" satırı ve "TÜM GEÇMİŞ OYUNLAR" linki (~14-19 px),
       oyuncu kartındaki k-lig satırı; ve header'daki oyuncu skor kutuları
       — satır zaten 48 px olduğundan onları 48'e çıkarmak BEDAVA oldu
       (`minWidth: 0`, genişlik akıcı sistemden gelmeye devam ediyor).
     - **`TapTarget.alignment` (CI yakaladı):** kutuyu büyütmek çocuğu
       ORTALADIĞINDAN, bir kenara hizalı duran metinler kayıyordu —
       "← Geri" 48 px'lik kutuda 4 px sağa kaçıp tahtanın sol kenarıyla
       hizasını kaybetti ve `game_header_test` bunu düşürdü. Varsayılan
       orta kaldı; hizalı hedefler `alignment` veriyor.
     - **AÇIK KALAN:** misafirken YZ oyunu açılışında tahtanın "takılarak"
       gelmesi. Bu ortamda profil alınamıyor; koddan iki aday çıkarıldı ve
       ikisi de "Canlı bekleyen oyunda olmuyor" gözlemine uyuyor:
       (A) misafir uyarı penceresinin kapanma animasyonu bitmeden geçişin
       başlaması (`showDialog`'un sonucu animasyon bitmeden döner) — Canlı
       yolunda böyle bir pencere yok; (B) 169 hücrenin bulanık gölgeleriyle
       ilk rasterizasyonu — `OnlineGameScreen` önce "Yükleniyor…" gösterip
       tahtayı geçişten SONRA çiziyor. Ayırt edici deneme kullanıcıya
       verildi: GİRİŞLİYKEN YZ oyunu açmak (uyarı penceresi çıkmaz).

   - ✅ **Parça 137 — tahta açılışta "takılarak" geliyordu: geçiş boyunca
     artık Canlı oyundakiyle AYNI "Yükleniyor…" gösteriliyor (24 Ağustos
     2026, Android):** kullanıcı *"YZ ile girişsiz oyun açtığında board'un
     ekrana gelmesi takılarak oluyor. Arkadaşınla bekleyen oyun
     çağırdığında olmuyor"* dedi.
     - **Ayırt edici deneme teşhisi kesinleştirdi:** iki aday vardı — (A)
       misafir uyarı penceresinin kapanma animasyonuyla geçişin üst üste
       binmesi, (B) tahtanın ilk çizim maliyeti. Kullanıcı *"girişli açılış
       da takılıyor"* dedi; girişli yolda o pencere HİÇ çıkmadığından (A)
       elendi.
     - **Maliyet koddan ölçüldü:** her boş hücre `NeoBox` içinde
       `MaskFilter.blur`lu İKİ iç gölge (`_InsetShadowPainter`) + bir
       `ClipRRect` taşıyor → 169 hücre ≈ 340 bulanıklaştırma; kart da blur
       20/14/60'lık üç gölge çiziyor. Hepsi route geçişinin ortasındaki TEK
       karede. Canlı oyunda yaşanmamasının sebebi de bu: `OnlineGameScreen`
       geçiş sırasında "Yükleniyor…" gösterip tahtayı SONRA çiziyor.
     - **İlk çözüm gölgeleri ERTELEMEKTİ** (`BoardWidget.cheapPaint`) ve
       çalışıyordu; ama kullanıcı yerine TUTARLILIĞI seçti: *"Neden bekleyen
       oyunlar gibi kısa bir yükleniyor çıkartmıyoruz? Her yerde aynı
       deneyim en azından."* Doğru karar — hem tek mekanizma kalıyor hem
       daha garantili: geçiş boyunca ekranda tek bir metin var, tahta HİÇ
       çizilmiyor (cheapPaint'te hücreler yine kuruluyor/çiziliyordu,
       yalnızca blur'ları atlanıyordu). `cheapPaint` tamamen geri alındı.
     - **Uygulama:** `GameScreen` route animasyonunu dinliyor
       (`ModalRoute.of(context)!.animation`, ilk kare sonrası okunur) ve
       bitene kadar `Scaffold(body: Center(KLoadingNote()))` döndürüyor;
       route yoksa/animasyon bittiyse (testler, ilk route) hiç beklenmiyor.
       `OnlineGameScreen`in kendi yükleme metni de aynı `KLoadingNote`a
       çekildi — iki ekran artık birebir aynı görünüyor.
     - **Kalıcı çözüm DEĞİL, kayda geçti:** maliyet ortadan kalkmıyor,
       hareketli karelerin dışına taşınıyor. Kök çözüm hücre çiziminin
       önbelleğe alınması (~7 çeşit görünüm × tek `ui.Image`) —
       `docs/decisions/product-backlog.md`, mağaza turundan sonrası.
     - **Regresyon kilidi:** `game_screen_test.dart` route ile push edip
       animasyonun ORTASINDA "Yükleniyor…" görünür + `BoardWidget` YOK,
       `pumpAndSettle` sonrası tersini iddia ediyor — ikinci iddia yükleme
       durumunun takılı kalmasını da yakalıyor.

   - ✅ **Parça 136 — "Paylaş" atlanmıştı; kutusuz hedef taraması artık
     TESTTE (24 Ağustos 2026, cihaz testinin ÜÇÜNCÜ turu, Android):**
     kullanıcı *"footerdaki paylaşın hâlâ tıklanmadığını farkettim, yine
     yukarısına dokunmak gerekiyor"* dedi.
     - **Kök sebep düzeltmede değil TARAMADAYDI:** Parça 134'te kutusuz
       dokunulabilirleri ararken "GestureDetector'ın DOĞRUDAN çocuğu `Text`
       mi" diye baktım; Setup footer'ındaki "Paylaş"ın çocuğu ikon + metin
       taşıyan bir `Row` olduğundan desene hiç takılmadı. Yani düzeltme
       doğruydu, KAPSAMI eksikti.
     - **İki katmanlı ders, ikisi de uygulandı:** (1) tarama çocuğun
       TÜRÜNE değil, kutuya bir ÖLÇÜ veren bir şey (`padding`, `width`,
       `height`, `SizedBox`, `Container`, `constraints`, `TapTarget`…)
       olup olmadığına bakmalı; (2) **elle koşulan bir tarama bir daha
       koşulmaz** — `tap_target_test.dart` artık `lib/src/ui` altını
       kendisi tarıyor ve kutusuna hiç ölçü vermeyen her
       `GestureDetector`/`InkWell`i düşürüyor. 11 gerekçeli istisna adıyla
       ve sebebiyle listeli (`_olcusuzIstisnalar`); yeni bir tanesi
       eklenirse CI kırmızı olur.
     - **Aynı taramanın ortaya çıkardığı öteki hedefler:** skor kartının
       "k-lig #N · puan" satırı ve "TÜM GEÇMİŞ OYUNLAR" linki (~14-19 px),
       oyuncu kartındaki k-lig satırı; ve header'daki oyuncu skor kutuları
       — satır zaten 48 px olduğundan onları 48'e çıkarmak BEDAVA oldu
       (`minWidth: 0`, genişlik akıcı sistemden gelmeye devam ediyor).
     - **`TapTarget.alignment` (CI yakaladı):** kutuyu büyütmek çocuğu
       ORTALADIĞINDAN, bir kenara hizalı duran metinler kayıyordu —
       "← Geri" 48 px'lik kutuda 4 px sağa kaçıp tahtanın sol kenarıyla
       hizasını kaybetti ve `game_header_test` bunu düşürdü. Varsayılan
       orta kaldı; hizalı hedefler `alignment` veriyor.
     - **AÇIK KALAN:** misafirken YZ oyunu açılışında tahtanın "takılarak"
       gelmesi. Bu ortamda profil alınamıyor; koddan iki aday çıkarıldı ve
       ikisi de "Canlı bekleyen oyunda olmuyor" gözlemine uyuyor:
       (A) misafir uyarı penceresinin kapanma animasyonu bitmeden geçişin
       başlaması (`showDialog`'un sonucu animasyon bitmeden döner) — Canlı
       yolunda böyle bir pencere yok; (B) 169 hücrenin bulanık gölgeleriyle
       ilk rasterizasyonu — `OnlineGameScreen` önce "Yükleniyor…" gösterip
       tahtayı geçişten SONRA çiziyor. Ayırt edici deneme kullanıcıya
       verildi: GİRİŞLİYKEN YZ oyunu açmak (uyarı penceresi çıkmaz).

   - ✅ **Parça 137 — tahta açılışta "takılarak" geliyordu: gölgeler geçiş
     bitene kadar erteleniyor (24 Ağustos 2026, Android):** kullanıcı
     *"YZ ile girişsiz oyun açtığında board'un ekrana gelmesi takılarak
     oluyor. Arkadaşınla bekleyen oyun çağırdığında olmuyor"* dedi.
     - **Ayırt edici deneme kullanıcıya verildi ve cevabı teşhisi
       kesinleştirdi:** iki aday vardı — (A) misafir uyarı penceresinin
       kapanma animasyonuyla geçişin üst üste binmesi, (B) tahtanın ilk
       çizim maliyeti. Kullanıcı *"girişli açılış da takılıyor"* dedi;
       girişli yolda o pencere HİÇ çıkmadığından (A) elendi.
     - **Maliyet koddan ölçüldü:** her boş hücre `NeoBox` içinde
       `MaskFilter.blur`lu İKİ iç gölge (`_InsetShadowPainter`) + bir
       `ClipRRect` taşıyor → 169 hücre ≈ 340 bulanıklaştırma; kartın kendisi
       de blur 20/14/60'lık üç gölge çiziyor. Hepsi route geçişinin
       ortasındaki TEK karede. Canlı oyunda yaşanmamasının sebebi de bu:
       `OnlineGameScreen` geçiş sırasında "Yükleniyor…" gösterip tahtayı
       SONRA çiziyor.
     - **Çözüm — `BoardWidget.cheapPaint`:** geçiş sürerken bulanık gölgeler
       ATLANIR; renk, çerçeve, taşlar, filigranlar aynı kalır. Tahta
       GİZLENMİYOR, yalnızca gölgesiz. `GameScreen` route animasyonunu
       dinleyip (`ModalRoute.of(context)!.animation`, ilk kare sonrası
       okunur) bitince tam çizime geçiyor; route yoksa/animasyon bittiyse
       (testler, ilk route) hiç beklenmiyor.
     - **Kalıcı çözüm DEĞİL, kayda geçti:** maliyet ortadan kalkmıyor,
       hareketli karelerin dışına taşınıyor. Kök çözüm hücre çiziminin
       önbelleğe alınması (~7 çeşit görünüm × tek `ui.Image`) —
       `docs/decisions/product-backlog.md`'ye yazıldı, mağaza turundan
       sonraya bırakıldı (görsel regresyon riski var ve projede piksel
       golden'ı yok).
     - **`OnlineGameScreen`e uygulanmadı ve bu bilinçli:** orada tahta zaten
       veri geldikten (yani geçiş bittikten) sonra çiziliyor, bayrak ölü kod
       olurdu. Web de değişmedi — CSS gölgelerini tarayıcı farklı işliyor ve
       orada böyle bir şikayet yok.
     - **Regresyon kilidi:** `game_screen_test.dart` route ile push edip
       animasyonun ORTASINDA `cheapPaint == true`, `pumpAndSettle` sonrası
       `false` olduğunu iddia ediyor — ikinci iddia gölgelerin kalıcı olarak
       kaybolmasını da yakalıyor.

   - ✅ **Parça 138 — taslak sürerken kelime anlamı AÇILMIYOR; ve
     sürüklemenin 30 px kaldırılmış olduğu bulundu (24 Ağustos 2026,
     Android):** kullanıcı *"koyduğum taşın üstüne basıp geri almaya
     çalıştığımda oradaki daha önce bulunan kelimelerin anlamları açıldı...
     Bu zaten yanlış, kelime anlamı deneme yapılırken hiç açılmamalı. Bu
     kritik bir problem, deneyimi tamamen bozuyor"* dedi.
     - **İki şey üst üste binmişti:** (a) ~24 px'lik hücrede taslak taşını
       geri almak için dokunan parmak sık sık KOMŞU (oynanmış) taşa isabet
       ediyor; (b) isabet edince pahalı bir sonuç doğuyordu — anlam
       penceresi. (a) büyütülerek çözülemez (ızgara ölçüsü kuralın kendisi),
       ama (b) çözülebilir ve acıyı veren o.
     - **Kural:** taslak hamle sürerken (`state.placed` boş değilken)
       oynanmış bir taşa dokunmak HİÇBİR ŞEY yapmaz. Taslak boşken davranış
       değişmedi. Dört yüzeyde birden (web `App.tsx` +
       `OnlineGameScreen.tsx`, port `game_screen.dart` +
       `online_game_screen.dart`); webde ayrıca `cursor-pointer` kalkıyor.
     - **ÖNCEKİ BİR TEŞHİSİM DÜZELDİ — kayda değer:** 48 px turunda
       "küresel bir koordinat kayması yok, çünkü sürükleme çalışıyor"
       demiştim. Yanlıştı: sürükleme yolu parmağın **30 px ÜZERİNİ** hedef
       alıyor (`DRAG_LIFT = 30` / `_dragLift`+`_liftedY`) — hayalet taş da
       bırakma hedefi de o kaldırılmış noktayı kullanıyor. Dokunuş yolunda
       telafi YOK. Yani sürüklemenin isabetli hissedilmesi dokunuşun da
       isabetli olduğunu kanıtlamıyor; kullanıcının dört kontrolde
       tekrarladığı *"biraz üstüne basınca çalışıyor"* cümlesi tam bu
       asimetriyle tutarlı. **Yine de çözüm dokunuşa offset eklemek
       DEĞİL** — sabit bir kaydırma büyük hedeflerde işi bozar; doğru
       cevap hedefi büyütmek (48 dp turu) ve büyütülemeyende ıskalamayı
       zararsız yapmak.
     - **AYNI TURUN İKİNCİ PARÇASI — IŞKALAMA KURTARMA (kullanıcı sordu:
       *"yanyana 3 harf koydum ve ortadakini geri almak istiyorum, o zaman
       yanlışlıkla yandaki taş geri gelmez değil mi?"*):** sessiz ıskalama
       acıyı aldı ama isabeti düzeltmedi. Taslak sürerken oynanmış taşlar
       ZATEN ölü olduğundan alanlarını taslak taşına devretmek bedava:
       oynanmış bir taşa dokunulduğunda komşusundaki taslak geri alınır.
       - **Kullanıcının sorduğu vaka risksiz:** yan yana üç taslak taşının
         ortasına dokunmak zaten TASLAK hücresine düşer, kural hiç
         çalışmaz. Kural YALNIZCA oynanmış hücrelerden tetiklenir.
       - **BOŞ hücreler dokunulmaz** — yoksa kelimeyi dizerken bir sonraki
         harfi yan hücreye koymak zorlaşırdı. (Testle kilitli.)
       - **Gerçek belirsizlik vakası VAR ve tahmin edilmiyor:** mevcut bir
         taşın hem üstüne hem altına harf konduğunda (tam da "iki kelimenin
         birleştiği yer") o taşın İKİ komşusu birden taslak olur. O zaman
         dokunuş NOKTASINA en yakın olan seçilir; mesafeler eşitse ya da
         ızgara ölçülemiyorsa hiçbir şey yapılmaz — yanlış taşı geri almak,
         hiç tepki vermemekten daha kötü. Bunun için `onCellTap` artık
         dokunuşun global noktasını da taşıyor (`onTap` → `onTapUp`).
       - **WEB'E DE UYGULANDI (aynı tur, kullanıcı isteği: *"Bir çok insan
         mobil browser kullanıyor, mouse değil"* — haklı, ilk kararım
         yanlıştı):** `src/utils/draftRescue.ts` → `nearbyDraftCell`, aynı
         aday sırası/en-yakın-merkez/eşitlik kuralı. Tıklama noktası
         `Board.tsx`'in `onCellClick`ine eklendi; komşu hücrelerin ölçüsü
         DOM'daki `data-cell` özniteliğinden okunuyor. `npm run
         verify-draft-rescue` 11 kontrolle doğruluyor (negatif eş kuruldu:
         eşitlik kuralı bozulunca GERÇEKTEN düşüyor). Aynı turda webde
         "konmuş taşa dokunma" davranışı da tek kaynağa alındı
         (`tapPlacedTile`) — joker penceresi/compat click yutma yalnızca
         pointer akışında.
     - **Test:** `meaning_test.dart` korumayı DÖRT dosyada birden ve SIRAYA
       bakarak kilitliyor (tahta-taşı dalının İÇİNDE, anlam çağrısından
       ÖNCE). Widget testi mümkün değil: `MeaningStore` gerçek sqflite
       async'i kullanıyor ve `testWidgets`ın sahte zamanında çözülmüyor,
       store'suz bir ekranda ise `store == null` dalı zaten erken dönüp
       korumayı değil EKSİKLİĞİ ölçerdi. Kurtarmanın kendisi ise GERÇEK
       widget testleriyle kilitli (`game_screen_test.dart`, üç vaka: tek
       komşu → geri alınır, iki komşu → dokunulmaz, boş hücre → hâlâ taş
       konur).

   - ✅ **Parça 133 — bölge kuralı: kendi bloğundaki DESTEKSİZ rakip taşı
     artık zinciri kesmiyor (24 Ağustos 2026, kullanıcı gerçek bir oyunda
     yakaladı):** *"Rakip benim bölgemin içinde UMAR yazdı. Ben de üstüne PÜR
     yazdım. Bölgenin büyümesini beklerken büyümedi."*
     - **Önce HATA DEĞİL diye doğrulandı, sonra kuralın kendisi tartışıldı.**
       Ekran görüntüsündeki renklerden tahmin etmek yerine oyunun gerçek
       satırı Supabase'ten okundu: "UMAR"ın U'su (9,9) ZATEN kullanıcınındı,
       rakip yalnızca M-A-R'ı (9,10..12) eklemişti; kullanıcı da PÜR'ü
       **rakibin R'sine** asmıştı. Üretimdeki `computeAllTerritories` o
       tahtada koşturuldu: (9,12) rakip taşı taşıdığından zinciri kesiyor,
       P(7,12) ve Ü(8,12) bağlanamıyordu — yani kod dokümandaki kuralı doğru
       uyguluyordu.
     - **Ama kullanıcının itirazı haklıydı ve tutarsızlık gerçekti:** (9,12)
       hücresi **zaten onun bölgesi** sayılıyordu (taban iddia; rakibin
       zinciri oraya ulaşmıyor) ve rakip oraya bitişik oynasa ona **vergi**
       ödeyecekti. Yani hücre kira toplanan ama üzerinden yürünemeyen bir
       alandı.
     - **Yeni kural:** kendi 4×4 bloğunun içindeki bir hücre, üzerinde rakip
       taşı olsa bile, o taş **rakibin kendi zincirine bağlı değilse** senin
       zincirini kesmez — **iletken**dir. Rakip bölgesini oraya gerçekten
       taşımışsa hiçbir şey değişmez (hücre onun, zincir kesilir, vergi
       ödenir). Bu, zaten var olan "blok içi BOŞ hücreler geçittir"
       istisnasının doğal devamı.
     - **TASARIM TUZAĞI, ölçülerek yakalandı:** iletken hücreyi zincire ÜYE
       yapmak çakışma üretiyor — taşın sahibi o hücreye kendi taşlarıyla
       ulaşabildiği bir tahtada hücre HEM onun HEM blok sahibinin zincirine
       giriyor ve "iki oyuncunun bölgesi asla çakışmaz" değişmezi kırılıyor.
       Bu yüzden `chain` (üyelik) ile `visited` (gezinme) AYRI iki küme:
       iletken hücre gezilir, üye olmaz. Değişmez hem web'de hem Dart
       testinde ayrıca assert ediliyor.
     - **İki geçiş, sırası önemli:** önce her oyuncunun SAF zinciri (yalnızca
       kendi taşları), sonra "bu rakip taşı destekli mi" sorusu O saf zincire
       sorulur. Kapıyı ikinci geçişin kendi sonucuna sormak dairesel olurdu
       (A'nın zinciri B'ninkine, B'ninki A'nınkine bağlı).
     - **Kapsam kendiliğinden dar:** blok DIŞINDAKİ bölge zaten yalnızca
       kendi taşlarından oluştuğundan kural **sadece kendi bloğunun içinde**
       çalışabilir; tarafsız alandaki izole rakip taşı hâlâ keser.
     - **Golden vector'lar yeniden üretildi → SIFIR fark.** Yani mevcut
       senaryoların hiçbiri bu dala girmiyordu ve iki motor burada sessizce
       ayrışabilirdi. Bu yüzden yeni bir fixture eklendi:
       `test/goldens/territory.json` (5 vaka) + `run_all.dart` →
       `testTerritory()`. Vakalar elle kurgulandı; biri kuralın NEGATİF dalı
       (`destekli_rakip_tasi_keser` — rakip bölgesini gerçekten taşımış).
       **Fixture'ın kurala duyarlı olduğu kanıtlandı:** kural geçici geri
       alınıp yeniden üretildiğinde ilgili vaka 18 → 16 hücreye düşüyor.
     - **Etkilenen yüzeyler tek kaynaktan besleniyor** (ayrı ayrı
       güncellenmedi, gerek yok): tahta çizimi (`board_widget.dart` /
       `Board.tsx`), bölge vergisi (`computeInvasionSplit`) ve YZ
       (`find_move.dart` / `ai.ts`) hepsi `computeAllTerritories` çağırıyor.
       `HelpModal` metni bu mekaniği hiç anlatmadığından dokunulmadı
       (dolayısıyla `help_text_parity_test` de etkilenmedi).
     - **Devam eden oyunlar anında etkilenir** — bölge her hamlede tahtadan
       yeniden hesaplanıyor, saklanmıyor.
     - **Doğrulama sınırı:** Flutter/Dart SDK bu ortamda yok; Dart yarısının
       kanıtı CI. Yerinde yapılanlar: `tsc`, `npm run build`, Playwright
       29/29, golden üretimi, iki Dart dosyasının ayraç dengesi, ve kuralın
       kullanıcının GERÇEK tahtasında ölçülmesi (bölge 34 → 36, tam olarak
       P ve Ü; Bobola 19 → 19; çakışan hücre 0).
   - ✅ **Parça 132 — alt şeridin dokunma hedefleri 18 → 32 px (24 Ağustos
     2026, kullanıcı cihazda bildirdi):** Play yükleme akışı kullanıcı
     tarafından bilerek durduruldu: *"Buna başlamadan app'de dikkatimi çeken
     1-2 konu var… board altındaki hamleler, mesajlar ve nasıl oynanır
     linkleri tıklayınca hemen açılmıyorlar. Kaç defa basmam gerekti."*
     - **Teşhis yeni DEĞİL — 22 Ağustos jest denetiminde ZATEN ölçülmüş ve
       bilinçli olarak ertelenmişti** (`docs/decisions/touch-ux-bugs.md` →
       "Denetimde bulunan ama DÜZELTİLMEYEN"). Orada hedefler 18 px ölçülmüş
       (WCAG 2.2 asgarisi 24), ama "hedefler GENİŞ olduğundan pratik ıskalama
       riski çok düşük" denmişti. **Gerçek kullanım o yargıyı çürüttü.**
     - **Ertelemenin TEKNİK gerekçesi de yanlıştı, ve çözüm oradan çıktı.**
       Not "Flutter'da negatif margin yok, `Padding` şeridi gerçekten 12 px
       büyütür" diyordu — bu, dolgunun EKLENECEĞİNİ varsayıyor. Oysa dolgu
       zaten vardı, sadece YANLIŞ YERDEYDİ (kapta). Kaptan alınıp her ÖĞEYE
       taşınınca şeridin dış ölçüsü (4 + 18 + 10 = **32**) hiç değişmiyor —
       satırın boyunu artık en uzun çocuk belirliyor — ama hedefler 18 → 32
       çıkıyor. Negatif margin GEREKMİYOR, yani iki platform AYNI çözümü
       kullanıyor ve "ayrı bir düzen turu" da gerekmedi.
     - **Web KANONİK ve web de kırıktı** (metodoloji gereği önce oraya
       bakıldı): `Board.tsx`'in üç düğmesinde de dolgu yoktu, kap
       `px-[10px] pb-[10px] pt-1` taşıyordu — portun `fromLTRB(10, 4, 10, 10)`
       ile BİREBİR aynısı. Yani bu bir port sapması değil, ortak bir kusur;
       ikisi de AYNI PR'da düzeltildi.
     - **BEŞ öğe de dolgu taşımak ZORUNDA** (Hamleler · ayraç `·` ·
       Mesajlaşma · Çevrimdışı · Nasıl Oynanır?). Yalnızca dokunulabilirler
       büyürse ayraç ve "Çevrimdışı" 32 px'lik satırda ortalanır ve dolgu
       asimetrik olduğundan (4/10) ~3 px kayarlar. Portta ortak değer
       `_footerItemPadding = EdgeInsets.only(top: 4, bottom: 10)`; ayraç ve
       "Çevrimdışı" kendi yatay değerlerini koruyor
       (`fromLTRB(6, 4, 6, 10)` / `fromLTRB(0, 4, 8, 10)`).
     - **Rozet METİN kutusuna çapalı KALDI:** portta `Padding` bilerek
       `Stack`in DIŞINDA (rozet `Positioned(top: -4, right: -4)` ile Row'un
       kutusuna çapalı; içeri alınsa dolgu kadar kayardı). Web'de karşılığı
       `relative`in iç bir `<span>`e taşınması. Ölçüldü: rozetin şeride göre
       konumu ÖNCE de SONRA da aynı (`top = 0`) — hiç oynamadı.
     - **ÖLÇÜLDÜ** (web tarafı; derlenmiş `dist/assets/*.css` + Chromium,
       DPR 2, `document.fonts.ready`, `http://` üzerinden, sınıf dizeleri
       `Board.tsx`'ten OKUNARAK), 390 px / çevrimiçi:
       Hamleler **1418 → 2521** px², Mesajlaşma **1700 → 3022** px²,
       Nasıl Oynanır? **2265 → 4027** px²; şerit yüksekliği **32 → 32**
       (değişmedi), yatay taşma 0 (320/360/390/834/1194'te). ÖNCE
       ölçümündeki 1418/2265, 22 Ağustos denetiminin kayda geçirdiği
       sayılarla BİREBİR aynı — harness'in sadık olduğunun kanıtı.
     - **Regresyon kilidi `layout_parity_test.dart`'ta** (bu tür bir geri
       alma hiçbir widget testini düşürmez): kabın yalnızca yatay dolgu
       taşıdığı, `_footerItemPadding`in 4/10 olduğu, İKİ tarafta da tam
       **5** öğenin dikey dolgu taşıdığı ve rozetin çapası ölçülüyor.
       **Negatif eş dördü de ayrı ayrı:** web düzeltmesi geri alınınca kap
       eşleşmesi + rozet çapası kayboluyor ve `pt-1 pb-[10px]` sayısı
       5 → 0; portta dolgu kaba geri konunca kap eşleşmesi kayboluyor ve
       4/10 sayısı 5 → 3.
     - **44 px'lik iOS asgarisi yine UYGULANMADI** (Parça 68'in aynı
       gerekçesi): satır ~13 px yüksekliğinde ve 44 px hem kardeş
       kontrolleri hem kartın kendi dokunuşunu yutardı. Çıta WCAG'ın
       24'ünün üstünde, şeridin kendi boyunda (32).
     - **Doğrulama sınırı:** Flutter SDK bu ortamda YOK — `flutter analyze`
       / `flutter test` KOŞULAMADI, Dart yarısının kanıtı CI.
       `board_widget.dart` parantez/ayraç dengesi elle tarandı (0/0/0) ve
       parite testinin regex'leri gerçek kaynaklara karşı Node'da
       (JS ≈ Dart regex semantiği) tek tek sınandı. Web tarafı temiz:
       `npm run lint`, `npm run build`, `verify-*` ve Playwright **29/29**.

   - ✅ **Parça 131 — release APK'da İNTERNET İZNİ YOKTU (24 Ağustos 2026,
     ilk gerçek cihaz kurulumu):** Kullanıcı Play için ekran görüntüsü
     çekmek üzere `mobile-latest` APK'sını Android telefonuna kurdu, tanıtımı
     geçip Setup'a geldi ve GİRİŞ'e basınca şunu aldı:
     `ClientException with SocketException: Failed host lookup:
     '<ref>.supabase.co' (OS Error: No address associated with hostname,
     errno = 7)`.
     - **Mesaj DNS hatasına benziyor ama sebep ağ DEĞİL izin.** URL doğruydu
       — hatadaki proje ref'i web'in `index.html`'indeki `preconnect`
       satırıyla BİREBİR aynı (ilk kontrol bu oldu, ref/typo ihtimali böyle
       elendi). Android, `INTERNET` izni olmayan bir uygulamada ad
       çözümleyiciyi de kapatıyor ve tam olarak bu "No address associated
       with hostname" hatasını üretiyor.
     - **Kök sebep:** Flutter şablonu `INTERNET`i YALNIZCA
       `android/app/src/debug/` ve `profile/` manifestlerine koyuyor (hot
       reload için). Release derlemesi `main/`i birleştiriyor ve orada YOKTU
       — repoda `uses-permission` geçen başka hiçbir satır da yoktu
       (`grep`le doğrulandı) ve kullandığımız eklentilerin HİÇBİRİ eklemiyor:
       `connectivity_plus` yalnız `ACCESS_NETWORK_STATE` veriyor,
       `supabase_flutter` saf Dart. Yani release APK internetsiz çıkıyordu ve
       sunucuya dokunan HER özellik (giriş/kayıt, Canlı oyun, k-lig, sohbet,
       telemetri) ölüydü.
     - **Ekrandaki ikinci ipucu de aynı sebebi doğruluyor:** "İnternet
       bağlantısı yok" uyarısı ÇIKMADI, ham hata göründü — çünkü
       `connectivity_plus` (`ACCESS_NETWORK_STATE` izni var) WiFi'ı görüp
       "bağlı" diyor. Yani `offlineNotice` yanlış davranmadı; ona yanlış
       bilgi verildi.
     - **Neden bugüne kadar görünmedi — Parça 122'nin (share_plus/iPad)
       AYNI SINIFI:** cihaz testleri GitHub Pages'teki Flutter WEB
       derlemesinde yapılıyor, orada Android izin modeli hiç yok; debug APK
       ise izni yukarıdaki debug manifestinden otomatik alıyor. Web derlemesi
       native-only kusurları YAPISAL olarak gizliyor — bu, aynı dersin ikinci
       kez ve bu sefer mağaza blokeri boyutunda tekrarı.
     - **Regresyon CI'da ve KAYNAĞI DEĞİL DERLENMİŞ ÇIKTIYI okuyor**
       (`mobile-build.yml` → "İnternet izni pakete girdi mi", APK derleme ile
       artefakt yükleme adımlarının ARASINDA — izinsiz bir paket kimse
       indiremeden düşer). Kaynak manifesti grep'lemek yetmezdi: izin oraya
       yazılmadan bir eklentiden de gelebilir, ya da bir merger kuralı onu
       düşürebilir; sorulan soru "yazdık mı" değil "PAKETE girdi mi". Aynı
       felsefe `.aab` imzasını geri okuyan adımda zaten vardı.
     - **Negatif eş ölçüldü** (üç durum, kontrol mantığı yerelde koşturuldu):
       izin varken geçiyor; `uses-permission` satırı silinince GERÇEKTEN
       düşüyor; birleşmiş manifest hiç bulunamazsa da düşüyor (kontrolün
       sessizce "geçmiş" sayılması engellendi).
     - **Doğrulama sınırı:** Flutter SDK/Android SDK bu ortamda YOK — düzeltme
       burada derlenip cihaza kurulamadı. Kanıt zinciri: manifest XML'i
       ayrıştırılarak izin doğrulandı, CI adımının mantığı üç senaryoda
       koşturuldu, kalan kanıt CI'ın kendi koşusu ve kullanıcının cihazı.
     - **iOS ETKİLENMEDİ** — orada giden ağ trafiği için izin kavramı yok
       (ATS yalnızca HTTPS zorluyor, zaten HTTPS kullanıyoruz).

   - ✅ **Parça 130 — mağaza öncesi telemetri: sürüm, rota ve `appVersion`
     paritesi (23 Ağustos 2026):** Kullanıcı *"özellikle ileride app tarafı
     geldiğinde eksik ne var?"* diye sorunca yapılan denetim üç boşluk buldu;
     üçü de app çıkmadan kapatılması gerekenlerdi.
     - **🔴 `appVersion` ↔ `pubspec.yaml` elle senkron ve TEST YOKTU — ama bu
       boşluk PARALEL bir turda ZATEN kapatılmıştı.** Denetim onu bağımsız
       olarak buldu ve testini yazdı; `main`'e alınırken görüldü ki Play
       yayını turu (22 Ağustos) AYNI testi aynı gerekçeyle çoktan eklemiş
       (`app_version_parity_test.dart` — aynı regex, `+N` build numarasını
       aynı sebeple dışarıda bırakan aynı karar). Bu daldaki kopya
       DÜŞÜRÜLDÜ; kanonik olan `main`'inki, o zaten CI'dan geçmiş ve sürüm
       1.0.0'a çıkarken ilk gerçek sınavını da vermiş.
       **Kayda değer olan, iki turun aynı riski bağımsız olarak birinci
       öncelik saymasıdır:** `env.dart:appVersion` bir teşhis metni değil,
       ZORUNLU GÜNCELLEME KAPISININ girdisi (`version_gate.dart` onu
       `app_config.mobile_min_supported_version` ile karşılaştırıyor).
       Ayrışmanın en kötü hâli sinsi: pubspec 1.1.0'a çıkar, `env.dart`
       1.0.0 kalır, mağazaya 1.1.0 yüklenir; eşik 1.1.0 yapıldığında
       GÜNCELLEMİŞ kullanıcılar kendini 1.0.0 bildirdiğinden hepsi
       uygulamadan KİLİTLENİR — üstelik güncelleyerek çıkamazlar.
     - **🟠 Sürüm dağılımını ölçen hiçbir alan yoktu.** Zorunlu güncelleme
       kolu vardı ama onu ne zaman çekeceğini gösteren VERİ yoktu. Artık
       `logGameStart` `platform` + `app_version` gönderiyor (`game_starts`ta
       `platform` da YOKTU — `app_version` tek başına ios ile android'i
       ayıramaz) ve `client_errors` her kayda `app_version` ekliyor. Panelde
       karşılığı: Büyüme > Kullanıcı → "Sürüm Dağılımı" tablosu ve hata
       kartındaki "Sürüm:" satırı. **Sayılan şey OYUN AÇILIŞI, kullanıcı
       DEĞİL** — port `anon_id` göndermediğinden app satırlarında cihaz
       sayılamıyor (web'in `visitTracking` damgasının portu hâlâ yok).
     - **🟡 `route` alanı portta SABİT `'app'`ti.** Web'de o kolon
       '/'/'/game/:id' diye ayrışıp "hangi ekranda?" sorusunu cevaplıyor; app
       trafiği baskın hâle gelince kolon tamamen ölürdü. Yeni
       `ErrorReporterRouteObserver` (`MaterialApp.navigatorObservers`)
       rotayı izliyor; adlar push yerlerinde `RouteSettings(name: …)` ile
       veriliyor (`intro`, `game`, `online-game`), adsız rota KÖK sayılıyor —
       yani yeni bir ekranın adı unutulursa kayıt yanlış olmaz, yalnızca
       ayrıntısını kaybeder. `MaterialApp.home`un '/' adı da köke eşleniyor.
     - **`error_reporter_test.dart` iki yeni test aldı** (rota gözlemcisi
       push/pop'ta alanı günceller; adsız rota kök sayılır) ve mevcut alan
       testi `app_version`ı da kontrol ediyor.
     - **Doğrulama sınırı:** Flutter SDK bu ortamda YOK — Dart tarafının
       kanıtı CI. Sunucu tarafı (migration + iki RPC) canlıda gerçek admin
       JWT'siyle koşuldu ve sahte app satırlarıyla doğrulandı (hepsi
       rollback): `[ios 0.1.0 starts=2 devices=2]`, `[android 0.2.0 starts=1
       devices=0]`, hata kartında `versions=0.1.0 platforms=ios`; admin
       olmayan çağrı `Yetkisiz erişim.` aldı.

   - ✅ **Parça 129 — sürükleme eşiği: fare ile parmak aynı sayıyı
     kullanamaz (22 Ağustos 2026):** Web'de bir kullanıcının joker raporu
     üzerine yapılan jest denetimi ikinci bir hata buldu ve o hata PORTTA DA
     vardı — `_dragThreshold = 6` satırının yorumu zaten "web
     DRAG_THRESHOLD" diyordu, yani bilinçli bir kopyaydı.
     - **Sorun:** parmak 6 logical px oynayan bir dokunuş "sürükleme"
       sayılıyor, sürükleme de aynı hücrede bittiğinden **hiçbir şey**
       yapmıyordu — raf taşı seçilmiyor, konmuş taş geri alınmıyor, joker
       seçici açılmıyordu. Yanlış bir şey değil, *hiçbir şey*: kullanıcıya
       "dokunuşum işlemedi" olarak görünen sessiz bir kayıp.
     - **Ölçüm web tarafında yapıldı** (Chromium, `hasTouch`+`isMobile`,
       390×844, CDP ham dokunuş olayları): 0–4 px titreşimde üç jest de
       çalışıyor, **6 px ve üstünde üçü de ölüyor**. Flutter SDK bu ortamda
       olmadığından portta aynı ölçüm KOŞULAMADI — ama kod yolu birebir
       aynı (`_moveTileDrag`in `d.moved` geçişi) ve `kTouchSlop`un Flutter'da
       **18** olması, 6'nın platform normunun ne kadar altında kaldığının
       bağımsız kanıtı (Android touch slop 8, iOS ~10).
     - **Düzeltme:** eşik `PointerDeviceKind`e bağlandı —
       `_dragThresholdMouse = 6`, `_dragThresholdTouch = 10`; `_moveTileDrag`
       artık `_dragThresholdFor(e.kind)` kullanıyor. İKİ oyun ekranı da
       (`game_screen.dart`, `online_game_screen.dart`) — biri atlanırsa yerel
       ve Canlı oyun kendi aralarında ayrışırdı.
     - **`PointerDeviceKind` için açık import ŞART** (`package:flutter/gestures.dart`
       show PointerDeviceKind): `material.dart` üzerinden gelmesine
       güvenilmedi, `intro_screen.dart`taki mevcut kullanım da aynı açık
       importu taşıyor.
     - **TESTLİ:** `layout_parity_test.dart`e yeni bir test — DÖRT dosyanın
       (iki web + iki Dart) hem SAYILARINI hem de eşiğin pointer türüne bağlı
       SEÇİLDİĞİNİ doğruluyor. İkincisi olmadan test yarım kalırdı: sabit
       doğru olup kullanılmıyorsa değeri yok.
     - **Regex'ler V8'de doğrulandı** (dosyanın kendi uyarısı: prototipi
       Python'da değil node'da koştur) — 12/12 eşleşti ve beklenen değeri
       döndürdü. Dart yarısının kanıtı yine CI.
     - **Bu turun ÖTEKİ hatası (hayalet click) portu ETKİLEMEDİ ve `mobile/`
       altında o yüzden hiçbir değişiklik gerekmedi** — Flutter'da dokunuş
       kendi hit-test'inden geçiyor, uyumluluk (compat) mouse olayı diye bir
       şey yok. Ayrıntı: kök `CLAUDE.md` → "Jest Sınıfı Denetimi".

   - ✅ **Parça 128 — kalan dört korumasız çift de kilitlendi (21 Ağustos
     2026):** Parça 127 on çifti kapatmış, dördünü "sayı çifti değil, yapı/
     algoritma kopyası" diye dışarıda bırakmıştı. Kullanıcı *"kalan dört
     korumasız çifti de kilitleyelim"* deyince dördü de kapatıldı — ama
     **tek bir mekanizmayla değil**, her biri neyin kopyalandığına göre.

     | Çift | Mekanizma |
     |---|---|
     | `RankSeal` geometrisi | 15 sabit + darken katsayısı + kompakt eşiği + punto merdiveni + sedillalı harf listesi → `layout_parity_test.dart` |
     | Özellik ikonları | iki çizimi de KANONİK listeye indirgeyip karşılaştırma → `icon_parity_test.dart` |
     | `TESLIM_FONT_SIZE` | sayı yok → ALTINDAKİ DEĞİŞMEZ kaynakta doğrulanıyor |
     | `decideInitialMainView` | 112 vakalık TÜKETİCİ golden + CI'da tazelik kontrolü |

     - **ÖLÇÜLEN GERÇEK SAPMA — port noktaları webden küçüktü.** Web
       `<circle r="0.6" fill stroke-width="1.6">` ile çiziyor, yani BOYANAN
       yarıçap `0.6 + 1.6/2 = 1.4`; port dolu daireyi `0.9` ile çiziyordu.
       13px'lik ikonda 1.52 px'e karşı 0.98 px — üç noktada birden (robot'un
       iki gözü + wifi-off'un noktası). **Tahminle değil ölçülerek doğrulandı:**
       web SVG'si Chromium'da 40× büyütülüp boyanan piksel aralığı tarandı →
       1.400. Port düzeltildi; test daha yazılırken işini gördü.
     - **İkon karşılaştırması SAYI SAYMIYOR, DİLİ ÇEVİRİYOR.** Web göreli SVG
       komutları (`v`, `l`, `c`, `s`, `a`) kullanıyor, port mutlak
       `lineTo/cubicTo/arcToPoint`. İkisi de `stroke|fill` + `L/C/A/rect/circle`
       + mutlak koordinat listesine indirgeniyor; böylece "tek path içinde iki
       alt yol" ile "iki ayrı `drawLine`" eşleşiyor. Sıra KORUNUYOR (çizim
       sırası tahtadaki dolu karenin ızgara çizgilerinin üstünde kalmasını
       belirliyor).
     - **`TESLIM_FONT_SIZE` için sayı karşılaştırmak YANLIŞ eşdeğerlik
       iddiası olurdu** — web akıcı bir clamp, port `FittedBox`. Ortak olan
       şey DEĞİŞMEZ: teslim kutusu diğerleriyle aynı boyda kalmalı. Web bunu
       `lineHeight: SCORE_FONT_SIZE`, port `SizedBox(height: scoreFontSize)`
       ile sağlıyor; test ikisini de KAYNAKTA doğruluyor. Biri sabit bir
       sayıya çevrilirse kutular ayrışır ve test düşer.
     - **`decideInitialMainView`de karşılaştırılacak sayı YOK, DAVRANIŞ var** —
       aynı sonucu veren iki farklı yazım geçerlidir, aynı yazımı veren iki
       farklı sonuç olamaz. Bu yüzden golden vector deseni: web'in ÜRETİM
       fonksiyonu tüm girdi uzayında koşturuluyor. **Tüketici, örneklem
       DEĞİL** — (1+27)×(1+3) = 112 vaka; örneklemede bir dal sessizce
       sınanmadan kalabilirdi. Üretici üç sonucun da (`live`/`local`/`null`)
       temsil edildiğini ayrıca kontrol ediyor.
     - **⚠ GOLDEN BAYATLAMA DELİĞİ AÇIKÇA KAPATILDI:** golden üretilmiş bir
       dosya, yani TS kuralı değişip golden yeniden üretilmezse Dart testi
       ESKİ tabloya karşı GEÇER. `web-ci.yml` artık üreticiyi koşup
       `git diff --exit-code` ile tazeliği zorluyor; golden değişince de
       `mobile/**` dosyası değiştiğinden `mobile-build.yml` tetikleniyor ve
       Dart testi koşuyor. Zincir böyle kapanıyor. **Negatif eş ölçüldü:**
       kuralda tek bir `> 0` → `> 1` değişikliği tazelik adımını GERÇEKTEN
       düşürüyor. (İlk denemede adım "sessiz" kaldı — golden o an git'te
       TAKİPSİZDİ ve `git diff` takipsiz dosyayı görmez; `git add` sonrası
       doğru sonuç alındı.)
     - **Ortak yardımcılar `test/support/web_source.dart`e çıkarıldı**
       (`readRepoFile`/`pick`/`pickAll`) — üç parite testi paylaşıyor. Daha
       eski üç parite testi (`help_text`/`legal_text`/`rank_tiers`) kendi
       okuyucularını taşımaya devam ediyor; onlara dokunulmadı.
     - **⚠ CI İKİ GERÇEK HATA BULDU — ve ikisi de AYNI kök sebepten:
       prototipleme MANTIĞI doğrular, DİLİ değil.** Ayrıştırıcılar önce
       Python'da yazılıp Dart'a çevrildi; iki kez Python'ın semantiği
       kopyalandı:
       1. **`Match.end()` ↔ `Match.end`** — Python'da metot, Dart'ta GETTER.
          `dart analyze` iki hatayla düştü (artı iki gereksiz `!` uyarısı —
          `flutter analyze` uyarıyı da hata sayıyor).
       2. **`\w` ASCII ↔ Unicode** — Python'ın `\w`si Unicode farkında ve
          `ÇŞ`yi eşliyor; Dart'ınki (V8 gibi) yalnızca ASCII eşliyor. Yani
          `kSealDescenderChars = '(\w+)'` prototipte ÇALIŞTI, Dart'ta HİÇ
          eşleşmedi ve RankSeal testi düştü. Türkçe harf içerebilecek bir
          yeri yakalarken `\w` KULLANMA — `[^']+` gibi açık bir sınıf yaz.
       **KALICI DERS: Dart regex'ini PYTHON'DA DEĞİL NODE'DA (V8) prototiple.**
       Dart'ın `RegExp`i irregexp tabanlı, yani V8 ile aynı aile; Python'ın
       `re`si başka bir ailedir. Bu tur ikinci düzeltmede node'a geçildi ve
       15 sabit + darken + eşik + merdiven + sedilla + TESLİM kontrollerinin
       hepsi orada doğrulandı; negatif eş de node'da ölçüldü (`\w`ye geri
       dönünce iki kontrol GERÇEKTEN düşüyor). Ayrıca getter/metot
       karışıklığı (`isEmpty/length/keys/values/entries/first/last`) ve
       kalan tüm `\w` kullanımları mekanik olarak tarandı — geri kalanların
       hepsi ASCII tanımlayıcı yakalıyor, güvenli.
     - **Flutter SDK bu ortamda YOK** — dört doğrulama yolu: (a) her
       ayrıştırıcı önce Python'da gerçek dosyalara karşı koşturuldu (ikon
       karşılaştırmasında İKİ parser hatamı bu yakaladı: `final ad = Path()…`
       değişkenine alınmış yolu görmüyordum ve `drawRRect(…, fill)`ın
       sondaki virgülü yüzünden dolgu/kenarlık ayrımını kaçırıyordum);
       (b) Dart dosyalarının ayraç dengesi, string/yorum/interpolasyon
       farkında bir tarayıcıyla — **tarayıcı önce CI'da ZATEN YEŞİL olan
       dosyaları "dengesiz" gösterdi, yani araç kontrol grubuyla
       doğrulanmadan kullanılmadı**; (c) `npm run lint`; (d) golden
       üreticisinin gerçekten koşması. Dart yarısının kanıtı yine CI.


---
