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
      ve "N gün içinde iptal edilir" satırı olmalı.
- [ ] **Kabul.** Oyun `active` olmalı, tahta/torba kurulmalı, iki tarafta da
      "Devam Edenler"e geçmeli. Kabul sonrası arkadaş önerisi modalı çıkmalı
      (henüz arkadaş olunmayan katılımcılar varsa).
- [ ] **Ret.** Kart, daveti GÖNDERENİN listesinden de **anında** kalkmalı
      (oyun `abandoned` olur). Hiçbir yerde "bekliyor" olarak durmamalı.
- [ ] **Login varsayılanı.** Bekleyen bir davet varken çıkış yapıp tekrar gir:
      "Arkadaşınla" sekmesi otomatik açılmalı ve "Oyun Davetleri" alt sekmesi
      seçili gelmeli (davetler devam eden oyunlardan öncelikli).

## 2. Canlı oyun — oynanış

- [ ] **Sıra netliği.** Sırası sende değilken "Sıra: {isim}" bandı görünmeli;
      YZ koltuğunda ise nabız gibi atan "hamlesini hesaplıyor…" hâli.
- [ ] **Kalan süre yalnızca sende.** "Devam Edenler" listesinde "N saat sonra
      teslim sayılacak" **yalnızca sırası sende olan** satırlarda görünmeli.
      "Rakibin hamlesi bekleniyor" satırında görünmemeli — o süre rakibe ait.
- [ ] **Off-turn deneme.** Sıra sende değilken de taş yerleştirebilmeli,
      Board'da geçerlilik dış hattı/puan rozeti çalışmalı, "Oyna" pasif
      kalmalı. Rakip oynayınca deneme taşları rafa dönüp "Oyna" aktifleşmeli.
- [ ] **Sürükle-bırak.** Raftan tahtaya, tahtada taşıma, tahtadan rafa geri
      alma — üçü de çalışmalı (yerel oyundakiyle aynı davranış).
- [ ] **Realtime.** Karşı taraf oynadığında ekran kendiliğinden güncellenmeli.
      Sekmeyi arka plana alıp geri dönünce de senkron olmalı (mobil tarayıcılar
      arka plandaki websocket'i askıya alıyor, ön plana dönüşte elle yenileniyor).
- [ ] **4 kişilikte YZ turu.** 3. insan oynadıktan sonra YZ kendiliğinden
      oynamalı — uygulamayı kapatıp açmaya gerek kalmadan.
- [ ] **Skor kutusu → skor kartı.** Header'daki bir insan oyuncunun kutusuna
      dokununca `PlayerScoreCard` açılmalı; YZ kutusu tıklanabilir olmamalı.

## 3. Oyun içi mesajlaşma

- [ ] **İlk açılış.** Tahtanın altındaki "Mesajlaşma" → hoşgeldin popup'ı
      ("Devam") → sohbet penceresi. Buton yalnızca Canlı oyunlarda görünmeli,
      YZ oyununda hiç olmamalı.
- [ ] **Gönderme.** 200 karakter sınırı ve canlı "x/200" sayacı çalışmalı.
      Kendi mesajın sağda/kendi renginde, karşınınki solda.
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
