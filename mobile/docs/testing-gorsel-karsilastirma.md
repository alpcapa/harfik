# Cihaz Testi — Web ile Yan Yana Görsel Karşılaştırma

> `mobile/TESTING.md`'den 1 Eylül 2026'da taşındı (dosya 122 KB ile uyarı
> bandına girmişti; kesme noktası İÇERİĞİN TÜRÜ: burası tekrarlanan özellik
> listesi değil, görsel PARİTE denetimi — çoğu maddesi bir kez ya da görsel
> bir değişiklikten sonra koşulur). Bölüm numarası (0.5) ve madde metinleri
> korunmuştur, atıflar kırılmasın diye.

## 0.5 Web ile yan yana görsel karşılaştırma (Parça 56)

- [ ] **Setup'ta oyuncu satırında PUAN olmamalı (17 Ağustos 2026) — bu
      madde WEB'i sınıyor, portu değil.** GİRİŞLİ bir hesapla "Yapay Zeka
      ile" → "+ Yeni Yapay Zeka Oyunu" formunu aç: 1. koltuk satırında
      yalnızca ad görünmeli, yanında `Ironman (92)` gibi parantezli bir
      sayı OLMAMALI. **Portta bu gösterim zaten hiç yoktu**, yani madde
      aynı zamanda "iki taraf artık aynı" kontrolü. Sayı geri gelirse
      `Setup.tsx`'e `accountTotalScore` benzeri bir hesap geri konmuş
      demektir — o toplam k-lig ödüllerini (`bonus_points`) İÇERMEDİĞİNDEN
      gerçek puandan sapar (ölçülen fark 92 ↔ 97); doğru sayı hesap
      menüsündeki k-lig satırında (ayrıntı: kök `CLAUDE.md`, `Setup`).
- [ ] **Tahta ile raf arasındaki boşluk (17 Ağustos 2026) — bu madde
      WEB'i sınıyor, portu değil.** Bir oyunu iki platformda yan yana aç:
      tahta kartının ALTI ile raf kartının ÜSTÜ arasındaki mesafe aynı
      olmalı (ölçülen hedef **40px** = 4 + 30px'lik mesaj kutusu + 6).
      Web'de dar görünüyorsa mesaj satırının `min-h-[30px]`i düşmüş
      demektir — eski `min-h-[15px]` bağlayıcı değildi ve gerçek yükseklik
      20.5px'e düşüyordu. **İki satıra taşan uzun bir mesajda** (ör. çok
      kelimeli, vergi paylı bir hamle) web kutusu büyür, port `maxLines: 2`
      ile keser — o durumda küçük bir fark olması BEKLENEN.
- [ ] **Raf başlığı (17 Ağustos 2026) — üç şey birden.** İki platformu yan
      yana aç: (a) sağda **"7 harf" YAZMAMALI** (ikisinde de kaldırıldı);
      (b) oyuncunun adı **büyük harfe çevrilmemiş** olmalı (`Ironman`,
      `IRONMAN` değil) ve iki tarafta da aynı kalınlıkta görünmeli — ikisi
      de 700, fark yalnızca büyük harften geliyordu; (c) **ad ile taşların
      arası iki tarafta da aynı** (13px). **DEĞİŞTİR'e basıp iki taş seç:**
      sağda **"2 seçili" ÇIKMALI** — bu sayaç bilerek KALDI, çıkmıyorsa
      "7 harf"i kaldırırken fazlası silinmiş demektir. Seçili taş yukarı
      kalkarken **adın üstüne binmemeli** (web'e portun 7px'lik rezervi
      eklendi).
- [ ] **Rafın ALTINDAKİ buton satırı (17 Ağustos 2026, Parça 108) — bu madde
      PORTU sınıyor.** İki platformu yan yana aç: PAS GEÇ / DEĞİŞTİR /
      KARIŞTIR / GERİ AL / TORBA butonlarının **yazı boyu, harf aralığı ve
      YÜKSEKLİĞİ** aynı görünmeli; özellikle **TORBA ötekilerden uzun
      OLMAMALI** (13px'lik mavi sayaç satırı yükseltiyor, web flex ile
      hepsini eşitliyor). Butonlar arası boşluk ve **raf ↔ OYNA arası** da
      6px. **DEĞİŞTİR'e bas:** swap satırındaki DEĞİŞTİR ↔ VAZGEÇ boşluğu da
      6px olmalı (portta 8'di). Port butonları web'den **2px kısa kalabilir**
      — bu BİLİNÇLİ (web'in çerçevesi yer kaplıyor, portunki kaplamıyor).
- [ ] **Hesap Ayarları: "FOTOĞRAF DEĞİŞTİR" butonu (17 Ağustos 2026) — bu
      madde WEB'i sınıyor, portu değil.** Hesap menüsü → Hesap Ayarları'nı
      iki platformda yan yana aç: buton avatarın sağındaki BOŞLUĞUN
      TAMAMINI doldurmalı (sağ kenarı, altındaki "JPG/PNG, en fazla 10 MB"
      satırının hizaladığı sağ kenarla aynı), yazısı ortada **ve KALIN**
      (iki tarafta da 700). Web'de içeriğine göre daralıyorsa
      `w-full`/`flex-1`, ince görünüyorsa `font-bold` düşmüş demektir.
- [ ] **Filigranlar taşların ÜSTÜNE binmemeli (17 Ağustos 2026, Parça
      107).** Köşe bölgesine ve merkezdeki X2 bölgesine taş konmuş bir oyun
      aç: soluk köşe rakamı ve **X2** yalnızca BOŞ hücrelerde görünmeli,
      taşların üzerinden GEÇMEMELİ (web'de taşlar `z-[5]` ile filigranın
      üstünde). Bölge/hamle dış hatları ise filigranın ÜSTÜNDE kalmalı
      (web `z-10`). **Sürüklerken de bak:** bir taslak taşı parmakla
      kaldırdığında kaynak hücre boş çizilir, o hücrede filigran GÖRÜNMELİ.
- [ ] **Tahta filigranları (17 Ağustos 2026, Parça 106).** Bir oyun aç ve
      tahtayı iki platformda yan yana koy: (a) köşelerdeki soluk oyuncu
      RAKAMLARI aynı büyüklükte ve aynı yazı tipinde (Space Mono) olmalı —
      app'te belirgin KÜÇÜK görünüyorsa punto yine kutuya sığdırılıyor
      demektir; (b) merkezdeki büyük **X2** filigranı aynı büyüklükte
      olmalı (eskiden app'te BÜYÜKTÜ); (c) tam ortadaki turuncu hücrenin
      **X3** etiketi hücreyi DOLDURMAMALI, web'deki gibi küçük kalmalı
      (azami 12px — app'te eskiden ~37px, üç katıydı). Fark yalnızca
      punto/font; renk ve saydamlık zaten aynıydı. **Geniş bir ekranda
      (iPad) bak** — üç formül de `clamp` tavanına orada oturuyor.
- [ ] **Header'da avatarın dikey hizası (17 Ağustos 2026, Parça 106) —
      bu madde WEB'i sınıyor, portu değil.** Profil FOTOĞRAFI olan bir
      hesapla oyun ekranını iki platformda aç: sağ üstteki avatarın dikey
      merkezi, yanındaki skor kutularının merkeziyle aynı hizada olmalı.
      Web'de 3.5px yukarıda duruyorsa `UserMenu`'deki butondan `flex`
      düşmüş demektir. **Baş harfli (fotoğrafsız) bir hesapla test etmek
      bu hatayı GÖSTERMEZ** — sapma yalnızca `<img>` avatarda oluşuyor.
- [ ] **İçerik sütunu genişliği (13 Ağustos 2026, Parça 72).** GENİŞ bir
      ekranda (iPad yatay) Setup'ı iki platformda yan yana aç: "YAPAY ZEKA
      İLE"/"ARKADAŞINLA" butonlarının ve "OYUNU BAŞLAT"ın genişliği
      BİREBİR aynı olmalı. Web `max-w-[460px] px-4` bir border-box, yani
      içerik **428** — app daha geniş görünüyorsa dolgu yine kutunun
      dışına kaçmıştır. (Dar ekranda ikisi zaten aynı; fark yalnızca
      460+32'den geniş ekranlarda ortaya çıkar, o yüzden telefonda test
      etmek bu hatayı GÖSTERMEZ.)
- [ ] **GİRİŞ satırının konumu (13 Ağustos 2026, Parça 73 + 76).** Sağ
      üstteki GİRİŞ/avatar butonunun ÜSTÜNDEKİ boşluk web'le aynı olmalı
      (**12**); butonla logo ARASI ise **4**. App'te buton web'dekinden
      aşağıda duruyorsa dikey dolgu yine simetrik verilmiş demektir —
      web'de bu satır Setup içeriğinden AYRI bir kutu (üst 12), logo
      bloğu da `-mt-5` ile kabın `py-6`sının 20'sini geri alıyor. Aradaki
      4, kullanıcının portu tercih ettiği tek yer: **web porta uyduruldu**,
      yani burada web 12 görünüyorsa `-mt-5` geri alınmış demektir.
- [ ] **Logo altındaki yazı bloğu (13 Ağustos 2026, Parça 77).** Geniş bir
      ekranda iki platformu yan yana aç: tanıtım paragrafı İKİSİNDE de
      **4 satır** olmalı ve satır sonları aynı yerde kırılmalı (ilk satır
      "… kuşat. Ama" ile bitiyor). App'te 5 satıra düşüyorsa Material 3'ün
      0.25 harf aralığı yine sızmış demektir — aynı kontrol "Nasıl
      oynanır? · Arkadaşınla paylaş" satırının genişliği için de geçerli.
- [ ] **Harf aralığı: hiçbir metin web'den geniş DEĞİL (13 Ağustos 2026,
      Parça 78).** Material 3'ün 0.25 tracking'i tema seviyesinde
      kapatıldı; bu TÜM ekranların metin genişliğini ~%1-2 daraltıyor.
      Bölüm 0.5'i koşarken her ekrana bir kez bak: bir yerde satır sonu
      web'den farklı kırılıyor ya da bir etiket kutusuna sığmıyorsa not al
      (testler geometriyi doğruluyor ama her ekranı gözle kontrol
      edemiyor).
- [ ] **"+ Yeni …" butonu ve alt sekmeler (13 Ağustos 2026, Parça 80).**
      Her iki sekmede de (Yapay Zeka ile / Arkadaşınla) turuncu butonun
      yüksekliği ve altındaki sekme satırıyla arasındaki boşluk web ile
      aynı olmalı; sekmelerin kendi arası da web'deki kadar. Port
      12/6/12 kullanıyordu, web 20/8/20.
- [ ] **Form alanları (13 Ağustos 2026, Parça 79).** Giriş/kayıt, Hesap
      Ayarları, Görüş Bildir, arkadaş arama, sohbet ve şikayet kutuları —
      hepsi AYNI görünmeli: 38px yükseklik, 16 punto, 12px yatay dolgu,
      odakta mavi çerçeve. Çok satırlı olanlarda (sohbet/şikayet) da aynı
      dolgu/çerçeve geçerli. Klavye açıkken metnin kutuya dikey ortalı
      durduğunu da kontrol et.
- [ ] **Arkadaş onay/bilgi diyalogları.** "Arkadaşlıktan çıkar" gibi bir
      onay diyaloğu aç: kart genişliği ve iç dolgusu web ile aynı olmalı
      (384 kutu, 24 dolgu → içerik 336).
- [ ] **Modal başlığı: ✕ sağa dayalı (12 Ağustos 2026, Parça 71).** Skor
      Kartı'nı iki platformda yan yana aç: ✕ kartın sağ kenarına aynı
      uzaklıkta olmalı ve rütbe mührü kartın ORTASINDA değil, **başlık ile
      ✕ arasının** ortasında durmalı. (Portta ✕ 40px'lik bir dokunma
      hedefi taşıdığından buton kutusu web'inkinden büyük — bakılacak şey
      GLYPH'in konumu.)
- [ ] **Modal yüksekliği farkı web test derlemesinde NORMAL.** Skor
      Kartı'nın altındaki "TÜM GEÇMİŞ OYUNLAR" linki web'de görünüp
      mobilde kesiliyorsa bu bir hata DEĞİL: iOS Safari'de CSS `vh`
      tarayıcı çubuklarının altını da sayar, Flutter ise yalnızca görünür
      alanı görür. **Native'de kesilme olmamalı** — FAZ B'de doğrula:
      iPad yatay/dikey ve iPhone dikeyde modal, içeriğin tamamını
      kaydırmasız göstermeli.

Bu bölümü bir kez, iki sekmeyi (kelimeki.com ve alpcapa.github.io) AYNI
hesapla açıp yan yana koyarak koş.

- [ ] **Kartlar ve sekmeler "kabarık" görünmeli, düz DEĞİL.** Canlı oyun
      kartları, davet kartları, "Son Oynadıklarım" satırları, Setup'taki
      Devam Eden Oyun ve oyuncu satırları, skor kartındaki istatistik
      kutuları, oyun geçmişi kartları ve TÜM alt sekme çubukları (Devam
      Edenler/Oyun Davetleri/Son Oynananlar; Genel/2/4) web'deki gibi
      yumuşak gölge taşımalı. Düz/kağıt gibi duruyorsa regresyon.
- [ ] **Tahta ↔ mesaj ↔ raf boşlukları (Parça 57).** Oyun ekranında
      tahtanın alt kenarı ile mesaj satırı arasında, ve mesaj ile raf
      arasında web'dekiyle aynı nefes payı olmalı. Tahta mesaja YAPIŞIK
      duruyorsa regresyon (11 Ağustos 2026'ya kadar tam olarak öyleydi).
      Hem YZ hem Canlı oyun ekranında kontrol et — ikisi ayrı dosya.
- [ ] **Setup başlık bloğu.** Logo ile paragraf arası ve paragraf ile
      "Nasıl oynanır? · Arkadaşınla paylaş" satırı arası web'le aynı
      olmalı; paragraf 4 satır sürüyorsa satır aralığı da aynı görünmeli
      (portta daha ferah duruyorsa regresyon).
- [ ] **Setup'ın en altı.** "Kullanım Koşulları · Gizlilik Politikası"
      görünmeli ve ikisi de ilgili modalı açmalı. (Altındaki `Sürüm … ·
      depo ok` teşhis satırı BİLİNÇLİ olarak yalnızca app'te var.)
- [ ] **Arkadaşlar modalı.** Üç sekmenin (Arkadaşlarım/İstekler/Ara &
      Ekle) puntosu ve "Arkadaşını Davet Et"in altındaki küçük butonların
      boyu web'le aynı olmalı.

