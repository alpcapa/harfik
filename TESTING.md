# Kelimeki — Elle Test Kontrol Listesi

Bu dosya, `npm run test`'in (Playwright, `tests/smoke.spec.ts`) **yapısı gereği**
kapsayamadığı akışlar içindir: iki ayrı gerçek oturum, gerçek bir gelen kutusu
ve gerçek Supabase Auth gerektiren her şey. Otomatik testin kapsamı bilinçli
olarak dar (uygulama açılıyor mu, oyun başlıyor mu, YZ oynuyor mu) — aşağıdakiler
onun ulaşamadığı yer.

**Bu liste bir ilerleme kaydı değildir.** "Şu an nerede kaldık" bilgisi bilerek
yok: o bilgi her testten sonra yanlışa döner. Liste her sürüm öncesi (ya da
ilgili alana dokunan bir değişiklikten sonra) baştan koşulabilecek şekilde
yazıldı. Bir bölümü koşarken sonuçları not almak istersen bu dosyayı değil,
oturumun kendisini kullan.

**Ön koşul:** iki ayrı test hesabı (ör. T1/T2) ve ikisine de erişebildiğin
gerçek e-posta adresleri. Mailinator gibi geçici kutular font/logo render'ı
için güvenilir DEĞİL (gelen HTML'i sanitize edip uzak görselleri düşürüyorlar) —
e-posta görünümünü gerçek bir gelen kutusunda doğrula.

**Deploy sonrası:** test etmeden önce sayfayı bir kez yenile. PWA servis
çalışanı yeni sürümü arka planda alıp uyguluyor, ilk açılışta hâlâ eski JS
çalışıyor olabilir (bkz. `CLAUDE.md` → "PWA — Servis Çalışanı Güncellemesi").

---

## 1. Canlı oyun — davet akışı

- [ ] **Davet gönderme.** "Arkadaşınla" → "+ Yeni Canlı Oyun" → 2 kişilik, bir
      arkadaş seç → "Davet Gönder". **"Davetiniz gönderilmiştir."** ekranı
      çıkmalı, kime gittiğini yazmalı. "Tamam"a basınca listeye dönmeli.
- [ ] **Tek davet = tek oyun.** Gönderimden sonra `online_games`'te o çift için
      TEK satır olmalı. (Onay ekranı eklenmeden önce, geri bildirim olmadığı
      için insanlar butona tekrar basıp 25-35 saniye arayla ikinci bir oyun
      açıyordu — iki farklı kullanıcıda görüldü.)
- [ ] **4 kişilik + YZ.** 2 arkadaş seçip gönderince "4. koltuk Yapay Zeka ile
      doldurulacak, tamam mı?" onayı çıkmalı; "Hayır" denince listede kalıcı
      bir "🤖 Yapay Zeka" satırı belirmeli ve bir daha sorulmamalı.
- [ ] **Davetlinin görünümü.** Karşı hesapta "Oyun Davetleri" sekmesinde kart
      görünmeli, katılımcıların yanında "Davet gönderen"/"Bekliyor" etiketleri
      ve "N gün M saat sonra iptal edilecek" satırı olmalı (süre + sonunda ne
      olacağı — 5 Ağustos 2026'da "Bugün iptal edilir" gibi yanlış/süresiz
      ifadelerden bu kalıba geçildi).
- [ ] **Kabul.** Oyun `active` olmalı, tahta/torba kurulmalı, iki tarafta da
      "Devam Edenler"e geçmeli. Kabul sonrası arkadaş önerisi modalı çıkmalı
      (henüz arkadaş olunmayan katılımcılar varsa).
- [ ] **Ret.** Kart, daveti GÖNDERENİN listesinden de **anında** kalkmalı
      (oyun `abandoned` olur). Hiçbir yerde "bekliyor" olarak durmamalı.
- [ ] **Login varsayılanı.** Bekleyen bir davet varken çıkış yapıp tekrar gir:
      "Arkadaşınla" sekmesi otomatik açılmalı ve "Oyun Davetleri" alt sekmesi
      seçili gelmeli (davetler devam eden oyunlardan öncelikli). **Testi
      "Yapay Zeka ile" sekmesindeyken çıkarak koş** — Canlı sekmesindeyken
      çıkarsan seçim yeni oturuma taşındığından test, varsayılan hiç
      çalışmasa bile geçer (5 Ağustos 2026'ya kadar tam olarak bu oluyordu,
      bkz. bölüm 8'in son iki maddesi).
- [ ] **Kurma formunun arkadaş listesi hesap değişiminde tazelenmeli.** Bir
      hesapla "+ Yeni Canlı Oyun"u aç (arkadaş listesi yüklensin), kapatmadan
      çıkış yapıp BAŞKA bir hesapla gir, tekrar "+ Yeni Canlı Oyun"a bas.
      Yeni hesabın KENDİ arkadaş listesi görünmeli — önceki hesabınki (hatta
      kendi adının listede belirmesi) DEĞİL. (5 Ağustos 2026: `LiveGameCreateForm`
      arkadaşları yalnızca mount'ta çekiyordu, bu form modal değil tam görünüm
      olduğundan çıkış→giriş döngüsünü mount'ta kalarak atlatabiliyordu.)

## 2. Canlı oyun — oynanış

- [ ] **Sıra netliği.** Sırası sende değilken "Sıra: {isim}" bandı görünmeli;
      YZ koltuğunda ise nabız gibi atan "hamlesini hesaplıyor…" hâli.
- [ ] **Kalan süre yalnızca sende.** "Devam Edenler" listesinde "N saat sonra
      teslim sayılacak" **yalnızca sırası sende olan** satırlarda görünmeli.
      "Rakibin hamlesi bekleniyor" satırında görünmemeli — o süre rakibe ait.
- [ ] **Off-turn deneme.** Sıra sende değilken de taş yerleştirebilmeli,
      Board'da geçerlilik dış hattı/puan rozeti çalışmalı, "Oyna" pasif
      kalmalı. Rakip oynayınca deneme taşları rafa dönüp "Oyna" aktifleşmeli.
- [ ] **Geçerli taslakta mesaj kararlı.** Sıra sende + tahtada geçerli
      (yeşil çerçeveli) bir taslak varken alttaki mesaj HER ZAMAN "Oyna
      tuşuyla kelimeyi onayla." olmalı — taş seçmeden boş hücreye dokunmak
      ("Önce bir harf seç."i yazsa bile), uygulamayı arka plana alıp geri
      dönmek (senkron) ya da başka ekrana geçip dönmek metni DEĞİŞTİRMEMELİ;
      özellikle rakibin son hamle özeti ("X: +N puan …") görünmemeli
      (6 Ağustos 2026'da bulunan üç-farklı-mesaj hatası).
- [ ] **Sürükle-bırak.** Raftan tahtaya, tahtada taşıma, tahtadan rafa geri
      alma — üçü de çalışmalı (yerel oyundakiyle aynı davranış).
- [ ] **Realtime.** Karşı taraf oynadığında ekran kendiliğinden güncellenmeli.
      Sekmeyi arka plana alıp geri dönünce de senkron olmalı (mobil tarayıcılar
      arka plandaki websocket'i askıya alıyor, ön plana dönüşte elle yenileniyor).
- [ ] **4 kişilikte YZ turu.** 3. insan oynadıktan sonra YZ kendiliğinden
      oynamalı — uygulamayı kapatıp açmaya gerek kalmadan.
- [ ] **Skor kutusu → skor kartı.** Header'daki bir insan oyuncunun kutusuna
      dokununca `PlayerScoreCard` açılmalı; YZ kutusu tıklanabilir olmamalı.
- [ ] **Oyun bitince "Tekrar Oyna" (11 Ağustos 2026).** Oyun bitince "Oyna"nın
      yerini **"Tekrar Oyna"** almalı ("Canlı Listesi" DEĞİL). Tıkla → onay
      ("… ile aynı kadroda yeni bir oyun açılacak … Emin misin?"). Vazgeç
      hiçbir şey göndermemeli; onayla → "Davetiniz gönderilmiştir." → Tamam
      listeye dönmeli, yeni oyun "Rakip Bekleniyor"da görünmeli ve karşı
      hesaba davet + `notify-game-invite` e-postası gitmeli. **Biten oyunu
      SEN kurmamışsan da çalışmalı** (kurucu artık sen olursun) ve 4 kişilik
      + YZ'li bir oyunda YZ yine 4. koltukta kalmalı. Rakibi arkadaşlıktan
      çıkarıp denersen "Yalnızca arkadaşlarını davet edebilirsin." görünmeli
      ve ekranda kalınmalı.
- [ ] **Yerel/YZ oyununda da "Tekrar Oyna" (11 Ağustos 2026).** Bir YZ oyununu
      bitir: buton "Yeni Oyun Aç" DEĞİL "Tekrar Oyna" olmalı; onaydan sonra
      Setup'a uğramadan aynı kadroyla taze bir oyun açılmalı. **Aynı ekranda
      iki oyunu üst üste bitir** — Skor Kartı → "Tüm Oyunlarım"da İKİSİ de
      görünmeli (Flutter portunda burada sessiz bir kayıt kaybı bulunmuştu).

## 3. Oyun içi mesajlaşma

- [ ] **İlk açılış.** Tahtanın altındaki "Mesajlaşma" → hoşgeldin popup'ı
      ("Devam") → sohbet penceresi. Buton yalnızca Canlı oyunlarda görünmeli,
      YZ oyununda hiç olmamalı.
- [ ] **Gönderme.** 200 karakter sınırı ve canlı "x/200" sayacı çalışmalı.
      Kendi mesajın sağda/kendi renginde, karşınınki solda.
- [ ] **Sıralama — en yeni EN ÜSTTE, ÜÇ ekranda birden.** Sohbet penceresi
      (`ChatModal`), biten oyunun sohbet arşivi (Tüm Oyunlarım → konuşma
      balonu rozeti) ve admin sohbet dökümü (Şikayetler → "Sohbeti
      Görüntüle"). Üçü de aynı `ChatThread`'i besliyor ama yön kararı her
      birinin KENDİ çağrısında — biri değişirse üçü de kontrol edilmeli.
      (9 Ağustos 2026'ya kadar yalnızca sohbet penceresi doğru yöndeydi;
      iki arşiv ekranı ters duruyordu. Admin dökümü ise 10 Ağustos akşamına
      kadar canlıda hâlâ ters kaldı — düzeltme port dalında mahsur
      kalmıştı, bkz. `CLAUDE.md` → "Port dalında mahsur kalan web
      düzeltmeleri".)
- [ ] **Yazışma gizliliği (10 Ağustos 2026).** k-lig'den başka bir oyuncunun
      kartına gir → "Tüm Oyunlar". Onun **katılmadığın** bir Canlı oyununun
      kartında konuşma balonu rozeti **HİÇ ÇIKMAMALI** — ne sayı ne içerik.
      Kendi katıldığın oyunlarda normal görünmeli; admin hepsini görebilmeli.
      (O tarihe kadar `games.messages` girişli HERKESE açıktı — skor/tahta
      herkese görünür olsa da yazışma değil.)
- [ ] **Karşı tarafta.** Sohbet kapalıyken gelen mesaj için popup (gönderenin
      avatarı + adı + metin) çıkmalı ve **yalnızca elle** kapanmalı; butonda
      kırmızı nokta belirmeli. Sohbeti açınca nokta sıfırlanmalı.
- [ ] **Geç giriş.** Uygulama kapalıyken mesaj gelsin; tekrar girince kırmızı
      nokta çıkmalı. Hiç yeni mesaj yokken **çıkmamalı** (ilk sürümde yanlış
      pozitif veriyordu).
- [ ] **Sessize alma.** Sohbet başlığındaki dişli → kişi → "Kişiyi Sessize Al"
      → onay. Artık o kişiden popup/kırmızı nokta gelmemeli, ama mesajları
      sohbette görünmeye devam etmeli. İsminin yanında 🚫 çıkmalı.
- [ ] **Rapor etme.** Aynı panelden neden yazıp gönder → onay → **"Şikayetiniz
      iletildi."** ekranı. Rozet 🚩'a dönmeli (rapor otomatik olarak sessize
      de alır). Raporlanan kişide **hiçbir değişiklik olmamalı** (bilinçli:
      endüstri standardı, misilleme riski).
- [ ] **Mesaja dokunma.** Karşı tarafın mesaj balonuna dokununca da aynı ayar
      paneli o kişiyle açılmalı.
- [ ] **Kişi bazlı kalıcılık.** Aynı kişiyle YENİ bir Canlı oyun aç: 🚫/🚩
      rozetleri orada da görünmeli (durum oyuna değil kişiye bağlı).
- [ ] **Geri çekme.** "Raporu Geri Çek" → onay. Bayrak kalkmalı; sessize alma
      bundan etkilenmemeli (bağımsız). Aynı kişi tekrar raporlanabilmeli.
- [ ] **Geri çekilen rapor admin'de hâlâ "okunmamış".** Kart "Geri Çekildi"
      rozetini alır ama soluklaşMAmalı ve bekleyen sayaçlarından düşMEmeli —
      admin ne yaşandığını görüp okundu işaretlemeyi kendisi seçmeli. (Bir
      dönem geri çekme otomatik `handled=true` yapıyordu; rapor admin hiç
      bakmadan "incelenmiş" görünüyordu.)
- [ ] **Admin.** Admin Paneli → Geri Bildirim → Şikayetler: kart "Yeni"
      rozetiyle görünmeli, "Sohbeti Görüntüle" (yalnızca BİTMİŞ oyunlarda)
      dökümü açmalı, "Kişiye Git →" Üyeler tablosunda o satırı vurgulamalı.

## 4. Süre aşımı ve cezalar

Bunlar gerçek zamanda 24-48 saat/7 gün bekler; acele ediyorsan veritabanından
`turn_deadline`/`updated_at`/`created_at` geçmişe çekilerek tetiklenebilir.

**Süreyi geçmişe çekerken:** yalnızca test hesaplarının satırlarına dokun,
`id` ile hedefleyerek. Bu tablolarda gerçek kullanıcıların oyunları da duruyor
ve buradaki her akış gerçek bir e-posta gönderip gerçek bir k-lig cezası
uyguluyor. Değişiklikten sonra, tetiklemeden önce, cron'un/süpürmenin gerçekte
neyi kapsayacağını bir kez sorgulayıp doğrula.

**Mail hangi hesaba gidiyor:** uyarılan/teslim olan taraf hangi hesapsa mail
ona gider. Görsel doğrulama yapacaksan testi, o taraf **gerçek gelen kutusu
olan** hesap olacak şekilde kur (bkz. yukarıdaki Mailinator notu) — gerekirse
önce bir hamle oynayıp sırayı o tarafa geçir.

- [ ] **24 saat uyarısı.** Sırası gelen oyuncuya "Oyun Süresi Doluyor!" maili.
      Fonksiyonun **iki ayrı dalı** var (Canlı oyun + devam eden YZ oyunu) —
      ikisini aynı anda pencereye sokup **iki mail** geldiğini doğrula, tek
      dal çalışıyor olabilir. Metin isme iyelik eki eklememeli: "X **tarafından
      açılan** oyun" (takma isimlerde ünlü uyumu garanti edilemez).
- [ ] **48 saat aşımı (Canlı).** Sırası gelen otomatik teslim: puanı 0, rafı
      torbaya karışır. 2 kişilikte oyun anında biter. Teslim olana -2, karşı
      tarafa galibiyet +2. Teslim olana "Süre Aşımından Sona Erdi" maili.
- [ ] **Teslim sonrası torba sayacı.** `online_game_states.bag_count`, teslim
      olanın rafı geri karıştıktan sonra gerçek torbaya (`online_game_secrets.
      bag`) eşit olmalı. **4 kişilikte** asıl görünür: teslim oyunu bitirmediği
      için kalan oyuncular tahtada torbayı doğru görmeli, bir sonraki hamleyi
      beklemeden.
- [ ] **7 gün (YZ oyunu).** Devam eden YZ oyunu terk edilmiş sayılır, -2 ve
      bilgilendirme maili. Misafirde yalnızca yerel kayıt silinir (ceza yok).
- [ ] **Hiç oynanmamış YZ oyunu iz bırakmamalı.** Girişliyken bir YZ oyunu aç,
      **hiç hamle yapmadan** logoya bas. Setup'ta "Devam Edenler" listesinde
      hiçbir satır kalmamalı ve "Yapay Zeka ile" rozeti artmamalı — sekme
      değiştirip dönmeye gerek kalmadan, **ilk görünüşte**. (Satır zaten
      siliniyordu; listeyi çeken sorgu silme sunucuda commit edilmeden yola
      çıktığından kaydı bir kez daha gösteriyordu — 5 Ağustos 2026. Bu yüzden
      "sekme değiştirince düzeliyor" bir geçiş sayılmaz.) Oyunu 2+ hamle
      oynayıp terk edince ise satır listede KALMALI, bu doğru davranış.
- [ ] **Süpürme öne dönüşte de çalışıyor.** Uygulamayı Setup'ta açık bırakıp
      arka plana al, süreyi geçmişe çek, sonra öne getir — tam yeniden
      yüklemeden süpürülmeli. (Eskiden yalnızca mount'ta çalışıyordu, ceza
      kullanıcı uygulamayı baştan açana kadar gecikiyordu.)
- [ ] **7 gün (davet).** Yanıtlanmamış davet kendiliğinden iptal olur —
      **iki tarafta da**. Kuranın "Rakip Bekleniyor" listesinden ve
      **davetlinin "Davet Bekliyor" listesinden** kalkmalı; davetli tarafı
      ayrıca kontrol et, iptal yalnızca `online_games.status`'ü değiştirip
      `game_invites` satırını `pending` bıraktığından bu kova bir dönem
      filtrelemeyi atlamıştı. Rozetlerin de düşmesi lazım (Setup'taki
      "Arkadaşınla", "Oyun Davetleri" alt sekmesi, PWA ikonu).

## 5. E-posta bildirimleri

Onbir Edge Function var; hepsi `noreply@kelimeki.com`'dan, Brevo üzerinden.
**Gerçek bir gelen kutusunda** kontrol et (bkz. yukarıdaki Mailinator notu).
Her birinde: marka kartı + logo görünüyor mu, Türkçe karakterler doğru mu,
buton doğru yere gidiyor mu.

- [ ] Arkadaşlık isteği (`notify-friend-request`)
- [ ] Arkadaşlık isteği hatırlatması — 3 gün sonra, tek sefer
- [ ] Canlı oyun daveti (`notify-game-invite`)
- [ ] Süre uyarısı (`notify-deadline-warnings`, cron)
- [ ] Canlı süre aşımı teslimi (`notify-turn-timeout-surrender`)
- [ ] Yerel oyun terk edilmesi (`notify-local-game-abandoned`)
- [ ] Hesap dondurma / dondurmayı kaldırma
- [ ] Geri bildirim yanıtı ve admin mesajı — "cevap için tıklayın" linki
      siteyi `?contact=1` ile açıp formu otomatik açmalı
- [ ] **Opt-out.** Hesap Ayarları'ndan e-posta bildirimlerini kapat; tercih
      edilebilir olanlar (yukarıdaki ilk altı) gitmemeli, hesap güvenliği ve
      admin yazışması gitmeye devam etmeli.

## 6. Auth e-postaları (Supabase şablonları)

Bunlar Edge Function değil, Supabase Auth'un kendi mailleri. Şablonlar
`supabase/email-templates/*.html`'de duruyor ama **repodan otomatik
okunmuyor** — Dashboard → Authentication → Emails → Templates'e elle
yapıştırılmaları gerekiyor. Şablon dosyaları değiştiyse Dashboard'daki
kopyanın da güncellendiğini doğrula.

- [ ] Kayıt onayı, şifre sıfırlama, e-posta değişikliği — üçü de marka kartıyla
      gelmeli, gönderen "Kelimeki &lt;noreply@kelimeki.com&gt;" olmalı.

## 7. Bildirim rozetleri (site geneli)

Kırmızı yuvarlak sayı rozeti tek bir bileşenden gelir (`CountBadge`) ve her
zaman **bekleyen iş sayısını** gösterir. Bu, bölüm bölüm test edilirken
gözden kaçıyor: bir sekmeye rozet eklenip onu kapsayan üst sekmenin toplamı
güncellenmeyince sayılar sessizce ayrışıyor (iki ayrı kez oldu). Aşağıdakileri
tek turda, gerçekten bekleyen bir iş varken kontrol et.

- [ ] **Toplama zinciri.** Bekleyen bir geri bildirim VE bekleyen bir şikayet
      aynı anda varken: Admin Paneli'ndeki "Gelen Kutusu" ve "Şikayetler" alt
      sekmeleri kendi sayılarını, üstteki "Geri Bildirim" tab'ı ikisinin
      TOPLAMINI, `UserMenu`'deki "Admin Paneli" satırı da aynı toplamı
      göstermeli — üçü asla ayrışmamalı.
- [ ] **Diğer rozetler.** `UserMenu` → "Arkadaşlar" (bekleyen istek), Setup →
      "Yapay Zeka ile"/"Arkadaşınla" ve bunların alt sekmeleri, `FriendsModal`
      → "İstekler". Hepsi sağ üst köşede yuvarlak rozet olmalı; başlığa
      gömülü " (N)" biçiminde bir sayı **hiçbir yerde kalmamalı**.
- [ ] **Sayı değil, nokta olması gerekenler.** Board footer'ındaki
      "Mesajlaşma" (okunmamış mesaj) ve `UserMenu` avatarı — bunlar
      boolean gösterge, sayı taşımaz, bu doğru davranış.
- [ ] **Rozet olMAması gerekenler.** "Değiştir (N)" (seçili taş sayısı) ve
      "Arkadaşlarını Seç (N/3)" (seçim ilerlemesi) — bunlar bekleyen iş değil,
      metin içinde kalmalı.

## 8. "Bekleyen iş öne çıksın" — varsayılan sekmeler

Rozet bekleyen işi gösterir; bu kural kullanıcıyı oraya götürür. Dört ekran
aynı deseni paylaşıyor, dolayısıyla biri bozulduğunda diğerleri de şüpheli.
Her birinde gerçekten bekleyen bir iş varken ekranı **kapatıp yeniden aç**.

- [ ] **Canlı sekmesi.** Bekleyen davet varsa "Oyun Davetleri", yoksa
      "Devam Edenler" açık gelmeli.
- [ ] **Davet SONRADAN gelmişken.** Yukarıdakinin asıl kırıldığı hâl, ayrıca
      koş: önce "Arkadaşınla"ya bir kez gir (davet YOKKEN — liste önbelleğe
      girsin), çık; **sonra** sana bir davet gönderilsin; tekrar gir.
      "Oyun Davetleri" açılmalı. (Önbellekten hidrate edilen bayat liste
      varsayılanı bir kez yanlış uygulayıp kalıcılaştırıyordu — 5 Ağustos
      2026. Aynısı hesap değiştirmeden, sadece "Yapay Zeka ile"ye gidip
      dönerek de üretilebilir.)
- [ ] **Arkadaşlar penceresi.** Bekleyen istek varsa "İstekler" açık gelmeli.
      Ama "+ Yeni Canlı Oyun" içindeki "arkadaş eklemek için tıkla"
      bağlantısından açılınca **"Ara & Ekle"de kalmalı** — o açık bir niyet,
      ezilmemeli.
- [ ] **Arkadaşlık ikonları (11 Ağustos 2026).** Satır aksiyonları metin
      değil ikon: kişi-ekle (mavi) · kum saati (gri, dokun → iptal) ·
      kişi-onay (mavi, gelen isteği kabul) · adam- (kırmızı, çıkar —
      yalnızca "Arkadaşlarım"da). **Dördü de önce onay sorar**, hiçbiri
      dokunulduğu an iş yapmaz; onayı iptal edince karşı hesapta hiçbir şey
      olmamalı. "Ara & Ekle" (arama + Tüm Üyeler) **zaten arkadaş olunanları
      HİÇ göstermez** — orada kırmızı adam- görünmemeli; bir gelen isteği
      oradan kabul edince satır listeden düşmeli. Bir sayfanın tamamı
      arkadaş çıksa bile "Tüm Üyeler" boş kalmamalı (sonraki sayfa gelir).
      Skor kartında (k-lig → bir satır) arkadaş durumu **yeşil kişi-onay**
      — listedeki kırmızı adam- DEĞİL (bilinçli), dokununca yine çıkarma
      onayı açmalı.
- [ ] **Kişiye tıklamak skor kartını açar — ÜÇ sekmede de (11 Ağustos
      2026).** "Arkadaşlarım", "İstekler" ve "Ara & Ekle" (arama + Tüm
      Üyeler) satırlarında **avatara/isme** tıkla → o kişinin skor kartı
      açılmalı. Aksiyon ikonu bundan ayrışık: ikona tıklamak kartı DEĞİL
      onay diyaloğunu açmalı. Kartın kendi arkadaşlık simgesinden bir işlem
      yapıp (ör. çıkar) kartı kapatınca satırdaki ikon ANINDA yeni duruma
      dönmeli.
- [ ] **Admin paneli.** Bekleyen geri bildirim/şikayet varsa "Geri Bildirim"
      açık gelmeli (yoksa "Büyüme"). Gelen kutusunda bekleyen yokken yalnızca
      şikayet varsa doğrudan **"Şikayetler"** alt sekmesi açılmalı — aksi
      halde rozette sayı görünüp boş bir "Gelen Kutusu" karşılar.
- [ ] **YZ sekmesi.** "Son Oynananlar"a geç, "Arkadaşınla"ya gidip dön —
      "Devam Edenler" açılmalı. (İki taraf da sıfırlanır; bu bilinçli, akıllı
      varsayılan ancak sıfırlanan bir sekmede çalışabiliyor.)
- [ ] **Elle seçim ezilmemeli.** Bir ekranı açıp veri yüklenmeden HEMEN bir
      sekmeye dokun — liste gelince seçimin değişmemeli.
- [ ] **Sekme kendiliğinden DEĞİŞMEMELİ.** Bir sekmede otururken yeni bir
      davet/istek gelsin: yalnızca rozet artmalı, sekme zıplamamalı.
- [ ] **Seçim bir sonraki oturuma TAŞINMAMALI.** "Arkadaşınla" sekmesindeyken
      çıkış yap, sonra Canlı'da **hiçbir bekleyen işi olmayan** bir hesapla
      gir (rozet 0, aktif oyunda sıra rakipte olsun): "Yapay Zeka ile" ile
      açılmalı. Bu, bölüm 1'deki "Login varsayılanı"nın negatif eşi — orada
      sekmenin doğru açılması varsayılanın çalıştığını KANITLAMIYOR, çünkü
      taşınan seçim de aynı sonucu veriyordu. (`Setup`/`LiveGamesTab` çıkışta
      unmount olmuyor, `mainView` hiçbir yerde sıfırlanmıyordu — 5 Ağustos
      2026.)
- [ ] **Varsayılan İKİNCİ hesaba da uygulanmalı.** Bekleyen işi OLMAYAN bir
      hesapla gir (sekme "Yapay Zeka ile"de kalsın), çıkış yap, sonra bekleyen
      daveti/sırası OLAN başka bir hesapla gir: "Arkadaşınla" açılmalı. Aynı
      sekmede ikinci giriş olduğundan, "bir kez uygula" bayrağı hesap başına
      sıfırlanmazsa bu adım sessizce çalışmaz — yukarıdaki maddeyle birlikte
      koş, ikisi birbirinin kör noktasını kapatıyor.

## 9. Auth hata mesajları

Hepsi Türkçe olmalı — ham İngilizce ("User is banned", "Invalid login
credentials") görünmemeli. Bilinmeyen bir hata olduğu gibi geçer, bu doğru:
uydurma bir Türkçe cümleyle gizlemek hata ayıklamayı imkânsız kılardı.

- [ ] **Hatalı giriş.** Yanlış şifre → "E-posta ya da şifre hatalı."
- [ ] **Dondurulmuş hesap.** → "Hesabınız donduruldu. Gerekçesi ve itiraz yolu
      e-posta adresinize gönderildi." Şifre doğru da yanlış da olsa aynı mesaj
      çıkar (GoTrue şifreyi doğrulamadan ban'a bakıyor, ölçüldü).
- [ ] **Zaten kayıtlı e-posta.** Kayıt formunda mevcut bir adresle dene.
- [ ] **Form doğrulamaları bozulmamış.** Boş ad/soyad, alınmış takma isim →
      kendi Türkçe mesajları çıkmalı (bunlar aynı `catch`'ten geçiyor,
      çeviri katmanı onları ezmemeli).
- [ ] **E-posta linkinden gelen geri bildirim.** Bir bildirim mailindeki
      "cevap için tıklayın" ile gel, mesaj gönder: gönderim sonrası
      **üyelik teklifi çıkmamalı**, yalnızca teşekkür + "Kapat". (Uygulama
      içinden — oyun sonu, Terms/Privacy — açılan formda teklif hâlâ çıkar.)

## 10. k-lig ödül & rütbe sistemi

Ödül/rütbe kayıtları sunucuda, `games` tablosuna satır ekleyen bir trigger'la
(`games_award_league_rewards`) açılır; kutlama banner'ının "bir kez göster"
garantisi `league_rewards.seen_at` ile cihazdan bağımsızdır. Bu zincirin
büyük kısmı otomatik test edilemiyor (gerçek oturum + gerçek oyun bitişi
gerekiyor).

- [ ] **Kutlama banner'ı bir kez çıkar.** Görülmemiş bir ödülün varken
      (test için bir satırın `seen_at`'i SQL'le null'a çekilebilir) siteye
      gir: mühür damgalı, konfetili banner ekranın ORTASINDA, karartılmış
      arka planla çıkmalı. "Devam"dan sonra sayfa yenilense de, BAŞKA bir
      cihazdan girilse de bir daha çıkmamalı.
- [ ] **Banner oyun ortasında çıkmaz.** Devam eden bir YZ/Canlı oyunun
      ekranındayken banner asla belirmemeli; oyun bitince (ya da Setup'a
      dönünce) bekleyen kutlama kendiliğinden gösterilmeli.
- [ ] **Birleşik özet.** Aynı anda birden fazla görülmemiş kayıt varken
      (ör. geçmişe dönük backfill) TEK banner çıkmalı: rütbe varsa başlık
      rütbe, ödül puanı yeşil satırda toplam olarak.
- [ ] **Ödül toplama doğru.** 50 k-lig puanına İLK ulaşmada +5 eklenmeli
      (toplam 55 olur); puan -2 cezalarıyla eşiğin altına inse de verilmiş
      ödül GERİ ALINMAMALI. "Genel = 2 kişilik + 4 kişilik + ödül" toplamı
      tutmalı.
- [ ] **Mühür popup'ı.** Skor Kartı başlığı ile ✕ arasında ortalanmış büyük
      mühre (dış kenarı TIRTIKLI — noter mührü gibi) dokun: damga
      animasyonuyla bilgi popup'ı açılmalı (kademe adı +
      puan + "+N eşik ödülü dahil" + sıradaki rütbe hedefi + hedefe akan
      ilerleme çubuğu; en üst kademede çubuk yok). Çubuk etiketleri: sol
      eşiğin ödülü YEŞİL "(+5)✓" (alınmış), hedef eşiğin ödülü GRİ "(+10)"
      (henüz alınmamış) — yeşil+✓ yalnızca alınmış ödülde. Popup İSTENDİĞİ
      KADAR
      tekrar açılabilmeli (kutlamanın aksine "bir kez göster" kuralı yok).
      Başkasının kartında da (PlayerScoreCard) aynı mühür/popup çalışmalı.
- [ ] **Popup'ta ✕ var, "KAPAT" butonu YOK.** Kapatma yalnızca sağ üstteki
      ✕ (ve Escape / karartılmış zemine dokunma) ile — kartın altında tam
      genişlikte bir buton OLMAMALI. Kutlama/düşüş banner'ında ise "DEVAM"
      butonu KALMALI (o gerçek bir aksiyon: ödülleri görüldü işaretler).
- [ ] **Kart gölgesinde beyaz hale yok.** Hem bilgi popup'ının hem kutlama/
      düşüş banner'ının kartı karartılmış zeminde yalnızca yumuşak, koyu
      bir düşen gölge taşımalı — sol/üst kenarda beyaz bir parıltı (nömorfik
      `shadow-raised`) GÖRÜNMEMELİ. İkisi aynı kart, biri değişirse öteki de.
- [ ] **Küçük rozetler de tırtıklı.** k-lig listesi/Skor Kartı satırlarındaki
      18-20px'lik mühürlerin dış kenarı da testere dişli olmalı (büyük
      mühürle aynı siluet, 24 diş) — düz çember GÖRÜNMEMELİ. Dişler
      telefonda net ayrışmalı, harf (özellikle Ç/Ş sedillası) tırtığa
      DEĞMEMELİ. Fark: küçük mühürde iç kesikli halka yok, harf daha büyük.
- [ ] **Harf dikeyde ortalı — kuyruklu olanlar dahil.** Ç ve Ş (sedillalı)
      dairede M/O/U/D ile AYNI ölçüde ortalı durmalı; alta yakın/aşağı
      kaymış görünmemeli. Kolay kontrol: k-lig listesinde Çaylak ve
      Şampiyon satırlarını Oyuncu/Ustaca ile yan yana karşılaştır.
- [ ] **Rütbe düşmeli.** -2 ceza alıp eşiğin altına inen bir hesabın mührü
      (k-lig listesi, Skor Kartı, PlayerScoreCard) bir alt kademeye İNMELİ —
      üç yer de aynı kademeyi göstermeli (hepsi güncel `total_score`'dan
      türetiliyor). Puan tekrar eşiği aşarsa damga geri gelir ama rütbe
      banner'ı İKİNCİ kez ÇIKMAMALI ve ödül İKİNCİ kez VERİLMEMELİ (her
      eşik hayatta bir kez).
- [ ] **Rütbe düşüş banner'ı.** Eşiğin altına inince konfetisiz, üzgün bir
      banner çıkmalı ("Rütben geriledi! … Kazandıkça geri yükselirsin!") ve
      bir kez gösterilmeli; aynı eşikten İKİNCİ kez düşülürse yeniden
      çıkmalı (diğer banner'ların aksine tekrarlanabilir). Görülmemiş
      olumlu bir kutlama ile çakışırsa yalnızca olumlu olan gösterilmeli.
      Banner'da kaybedilen eşiğe geri dönüş çubuğu olmalı; hedef etiketi
      YALNIZCA SAYI ("50" — "puan" kelimesi YOK) ve altında yeşil "(+5)✓"
      (ödül + onay işareti =
      zaten alındı — kişi geri düşse bile yeşil ✓ kalır). Aynı kural bilgi
      popup'ında: düşmüş biri mühre dokununca hedef rozeti yeşil "(+N)✓"
      olmalı — hiç düşmemişte hedef GRİ "(+N)", ✓ yok.
- [ ] **k-lig sırası tutarlı.** Listedeki sıra/puan (leaderboard view) ile
      "senin sıran" satırı (my_leaderboard_rank RPC) aynı toplamı (ödül
      dahil) göstermeli.
