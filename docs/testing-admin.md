# Elle test — Admin paneli

> `TESTING.md`'nin 9.7-9.15 arası bölümleri. 26 Ağustos 2026'da o dosya
> 124 KB ile uyarı bandına girdiği için buraya taşındı (kök `CLAUDE.md` →
> "Doküman Boyutu Bütçesi"). **Hiçbir madde değişmedi**, bölüm numaraları
> da korundu — atıflar kırılmasın diye.
>
> **Neden bu blok:** hepsi yalnızca admin hesabıyla, çoğu canlı veriyle
> koşuluyor; `TESTING.md`'de kalan listenin tamamı normal bir kullanıcı
> hesabıyla koşulabiliyor. Kesme noktası boyut değil, KİMİN koştuğu.
>
> **Kararların kendisi burada DEĞİL** — "neden bu metrik, tanımı ne"
> soruları `docs/decisions/admin-panel.md`'de. Burası yalnızca kontrol
> listesi.
>
> ⚠ Yeni bir admin paneli kontrolü BURAYA yazılır; kök `TESTING.md`'ye değil.

## 9.7. Admin — Aktif Oyuncu / Aktivasyon / Retention (14 Ağustos 2026)

Üç panel Büyüme > Kullanıcı'ya eklendi. Üç RPC de canlıda gerçek admin
JWT'siyle koşuldu (yetki matrisi dahil); aşağıdakiler yalnızca gerçek
tarayıcıda görülebilecek olanlar. **Admin hesabı gerekiyor.**

- [ ] **Üçü de yükleniyor.** Admin Paneli → Büyüme → Kullanıcı: "Yeni Üye /
      Ziyaret"in altında sırasıyla **Aktif Oyuncu** grafiği, **Aktivasyon**
      (4 kutu), **Retention** tablosu görünmeli. Hiçbiri "Yükleniyor…"da
      asılı kalmamalı.
- [ ] **Aktif Oyuncu grafiği iki seri gösteriyor** ("Aktif Oyuncu (28 gün)"
      mavi, "Dönem İçi Aktif" amber) ve legend'dan tek tek açılıp
      kapanabiliyor. Tanım artık altta paragraf DEĞİL: "CSV İndir"in solundaki
      `?` rozetine dokun → popup'ta "…bu sayı bilerek MAU değil" cümlesi
      çıkmalı (17 Ağustos 2026'da taşındı).
- [ ] **Periyot/granülerlik kontrolü grafiği GERÇEKTEN değiştiriyor.**
      Üstteki periyot kombosunu değiştir: Aktif Oyuncu grafiği de yeniden
      çekilmeli (Yeni Üye/Ziyaret ile aynı kontrolleri paylaşıyor).
      **Aktivasyon ve Retention DEĞİŞMEMELİ** — ikisi bilerek periyoda bağlı
      değil (kohortun ekseni kayıt haftası, aktivasyon tüm zamanların oranı).
- [ ] **Retention tablosu üçgen görünmeli.** En yeni kohort ÜSTTE; sağ üst
      köşe boş (penceresi tamamlanmamış haftalar hiç çizilmiyor). Bir hücrenin
      üstüne gel → "3/10 üye aktif" gibi bir ipucu çıkmalı.
- [ ] **Hücre yazısı HER tonda okunabilir olmalı** — en koyu hücrede bile
      (%100'e yakın oran) rakam net görünmeli. Ton yalnızca ikincil işaret;
      oran zaten sayıyla yazıyor.
- [ ] **CSV'ler ham sayı veriyor.** Retention'da "CSV İndir" → dosyada yüzde
      DEĞİL aktif üye SAYILARI ve bir "Üye" (payda) sütunu olmalı.
- [ ] **NEGATİF EŞİ ŞART — admin olmayan hesap.** Sıradan bir hesapla giriş
      yap: "Admin Paneli" menü satırı HİÇ görünmemeli. (RPC'ler sunucuda
      ayrıca `Yetkisiz erişim.` fırlatıyor, ama UI'ın da sızdırmadığı
      görülmeli.)

> **Sayıları okurken:** 23 hesabın 4'ü test hesabı ve 325 oyunun 27'si
> onlara ait — bunları eleyen bir bayrak YOK (kullanıcı kararı: test verisi
> sonradan silinecek). Bu ölçekte kohort eğrileri gürültüdür; buradaki amaç
> enstrümantasyonun ÇALIŞTIĞINI doğrulamak, eğrileri yorumlamak değil.

## 9.8. Admin — Platform dökümü (14 Ağustos 2026) — **PARK EDİLDİ**

> **TABLO 15 Ağustos 2026'da PANELDEN KALDIRILDI** (kullanıcı kararı: bugün
> karar verdirecek bir şey söylemiyor, uygulamalar mağazaya çıkınca
> web/iOS/Android/diğer olarak yeniden yapılandırılacak). **Veri toplanmaya
> DEVAM EDİYOR** (`games.platform` + `online_game_clients`).
>
> Aşağıdaki UI maddeleri bilerek **kutusuz** — bugün koşulacak bir iş
> DEĞİLLER, tablo geri geldiğinde çevrilecek bir taslaktırlar. Doğrulama o
> güne kadar SQL'den yapılır. Bu bölümdeki tek KOŞULABİLİR madde en alttaki
> gizlilik metni kontrolü (veri toplandığı sürece geçerli).

**Tablo geri geldiğinde koşulacaklar (bugün DEĞİL):**

- **Tablo yükleniyor.** Admin Paneli → Büyüme → Kullanıcı: "Cihaz"ın
  hemen altında **Platform** tablosu (Platform / Oyun / Oyuncu / %).
  "Cihaz"dan farkı ekranda yazmalı — 17 Ağustos 2026'dan beri tablonun
  altındaki paragrafta değil, "CSV İndir"in solundaki `?` popup'ında
  (bkz. 9.11), yani tablo geri gelirken `HINTS`e kendi girdisi de eklenmeli.
- **Web'den oynanan yeni bir oyun `Web` satırına düşüyor.** kelimeki.com'da
  girişliyken bir YZ oyunu BİTİR (yarıda bırakma — satır ancak oyun
  bitince yazılıyor), sonra paneli aç: `Web` satırının "Oyun" sayısı 1
  artmalı. Toplam da artmalı, `Bilinmiyor` DEĞİŞMEMELİ.
- **Uygulamadan oynanan oyun `iOS`/`Android` satırına düşüyor.** Aynı
  şeyi mobil uygulamada yap (GitHub Pages web derlemesinde `App (Tarayıcı)`
  satırına düşer — o da doğru davranış, uygulamanın tarayıcıdaki hâli).
- **Canlı oyun da sayılıyor.** İki hesapla bir Canlı oyunu SONUNA kadar
  bitir; her katılımcı KENDİ oynadığı istemcinin satırına düşmeli (biri
  web'den biri app'ten oynadıysa iki farklı satır).
- **"Bilinmiyor" satırı GİZLENMEMELİ.** Kolon 14 Ağustos 2026'da eklendi;
  öncesinde biten ~300 oyun orada toplanıyor. Satırı görmüyorsan tablo
  yanlış filtreliyor demektir — yüzdeler de yalancı olur.
- **CSV İndir** çalışmalı; dosyada Platform/Oyun/Oyuncu/% sütunları ve bir
  TOPLAM satırı olmalı.

**Bugün koşulabilir:**

- [ ] **Gizlilik metni güncel.** Gizlilik Politikası → "Toplanan Veriler"de
      "Bir oyunu hangi istemciden oynadığınız…" maddesi olmalı (mobil
      uygulamadaki metin de AYNI). Tablo panelde olmasa da veri
      toplandığından bu madde metinde KALMALI.

## 9.9. Admin — Kaynak Hunisi (16 Ağustos 2026)

"Ziyaretçi Kaynağı" tablosunun yerini aldı: kaynak → **Kişi** → **Başlayan**
→ **Üye** → **Oyun**. İlk sütun eskisiyle aynı sayı. Sunucu tarafı canlıda
rollback'li senaryolarla doğrulandı (yetki matrisi, damgalama, write-once
trigger, toplamların korunması); aşağıdakiler gerçek istemcide görülmesi
gerekenler.

- [ ] **"Başlayan" sütunu gerçekten sayıyor (21 Ağustos 2026, ROADMAP #9).**
      Misafirken (çıkış yapıp) yapay zekaya karşı bir oyun BAŞLAT, hemen
      logoya basıp çık — bitirmene gerek YOK. Admin panelinde Kaynak
      Hunisi'nde o cihazın kaynağının (`?ref=` ile gelmediysen `direkt`)
      "Başlayan" değeri 1 ARTMALI, "Oyun" değeri DEĞİŞMEMELİ. Bu ayrım işin
      bütün sebebi: "Oyun" yalnızca BİTMİŞ ve yalnızca GİRİŞLİ kullanıcının
      oyununu sayıyor.
- [ ] **Aynı cihazda ikinci oyun: "Başlayan" 2, ama yüzde modunda cihaz
      sayısı 1 kalmalı.** `%` düğmesine bas — "Başlayan" yüzdesi başlatan
      benzersiz CİHAZ / kişi oranıdır, oyun adedi değil.
- [ ] **"Tekrar Oyna" da bir başlangıçtır.** Bir oyunu bitirip kartın
      altındaki "Tekrar Oyna"ya bas → "Başlayan" yine artmalı. (Web'de her
      iki yol da tek bir `startLocalGame` yardımcısından geçiyor; portta iki
      ekran da `GamesRepo.logStart` çağırıyor.)
- [ ] **Devam eden oyuna DÖNMEK bir başlangıç DEĞİL.** Yarım bırakılmış bir
      oyunu "Devam Eden Oyun" satırından sürdür → "Başlayan" ARTMAMALI.
      Artıyorsa aynı oyun her oturum dönüşünde tekrar sayılıyor demektir.

- [ ] **Tablo yükleniyor ve zaman filtresine bağlı.** Admin Paneli → Büyüme →
      Kullanıcı: "Kaynak Hunisi (Son N …)" başlığı üstteki granülerlik/periyot
      seçimini takip etmeli; seçim değişince sayılar değişmeli.
- [ ] **Bugünkü beklenen tablo — İKİ satır: `direkt` ve `arkadas`.**
      "Bilinmiyor" satırı OLMAMALI: 16 Ağustos 2026'da damgalama öncesi 23
      üyeden 22'si `arkadas`, hesap sahibi ise `direkt` olarak dolduruldu
      (hesap sahibinin bilgisi: o tarihe kadar üyelerin tamamı davetle geldi,
      kendisi hariç). Bilinmiyor ancak
      damgalamayan bir istemciden (bugün: mobil uygulama) kayıt gelirse
      yeniden belirir.
- [ ] **Davet linki `?ref=arkadas` taşıyor VE yakalanıyor (21 Ağustos 2026,
      ROADMAP #7).** Arkadaşlar → "Arkadaşını Davet Et" ile link üret;
      URL'in sonunda `?ref=arkadas` OLMALI. Sonra o linki **temiz bir
      tarayıcıda** (gizli sekme) aç ve devtools'ta
      `localStorage.getItem('kelimeki:utm-source')` → **`"arkadas"`**
      dönmeli. `null` dönüyorsa etiket konuyor ama yakalanmıyor demektir —
      hata tam olarak buydu ve `boot.tsx`te düzeltildi.
      **Not:** bu, `arkadas` satırının eski "%100 dönüşüm"ünü de anlamlı
      hale getiriyor; o rakam bu düzeltmeden ÖNCE bir ölçüm değil tesadüftü
      (iki uç aynı popülasyonu ölçmüyordu).
- [ ] **`direkt` satırında tam 1 üye olmalı (hesap sahibi).** Projeyi kuran
      hesap kimse tarafından davet edilmedi; geri kalan 22 üye `arkadas`.
- [ ] **Yeni bir kayıt kaynağını damgalıyor.** Gizli sekmede
      `kelimeki.com/?ref=instagram` aç, sonra ORADAN üye ol → panelde
      `instagram` satırı belirmeli, "Üye" 1 olmalı. Aynı hesapla bir oyun
      bitir → aynı satırın "Oyun"u 1 olmalı.
- [ ] **`?ref=` olmadan üye olan `Direkt`e düşmeli** (Bilinmiyor'a DEĞİL) —
      ikisi bilinçli olarak ayrı: Bilinmiyor = damgalanmamış (eski üyeler ve
      mobil uygulama kayıtları).
- [ ] **İlk temas kazanır.** Önce `?ref=instagram` ile gel, sonra siteyi
      `?ref=` olmadan (ya da başka bir ref ile) tekrar aç ve ANCAK O ZAMAN üye
      ol → kaynak hâlâ `instagram` olmalı.
- [ ] **TOPLAM satırı tutuyor mu.** Üç sütunun toplamı, satırların toplamına
      eşit olmalı; "Üye" toplamı o dönemdeki yeni üye sayısıyla (Yeni Üye/Ziyaret
      grafiği) tutarlı olmalı.
- [ ] **`% / Sayı` düğmesi dönüşümlü çalışmalı.** Tablonun sağ üstünde, "CSV
      İndir"in yanında. Bas → üç sütun birden yüzdeye dönmeli; tekrar bas →
      sayılara dönmeli. Aktif mod her zaman vurgulu (mavi/kalın) olmalı, yani
      hangi moddasın bakınca anlaşılmalı.
- [ ] **Yüzdelerin TABANI sütuna göre farklı.** "Kişi" sütunu SÜTUN payı
      (TOPLAM satırı **100.0%**); "Üye" ve "Oyun" ise o SATIRIN "Kişi"sine
      göre dönüşüm. Doğrulaması kolay: kişi=40, üye=6 olan bir satırda "Üye"
      **%15.0** göstermeli.
- [ ] **"Oyun" yüzdesi oyun ADEDİNDEN değil, OYNAYAN KİŞİDEN hesaplanmalı.**
      Aynı satırda oyun=25 ama oynayan kişi=4 ise "Oyun" yüzdesi %62.5 DEĞİL
      **%10.0** (4/40) olmalı. Oynayan kişi sayısını CSV'den doğrula.
- [ ] **Kişi = 0 olan satırda oran "—" olmalı** (0.0% ya da sonsuz DEĞİL).
      Backfill sonrası bu durumda bir satır KALMADI; kontrol etmek için
      damgalamayan bir istemciden (mobil uygulama) bir kayıt bekle ya da
      SQL'de tek satırlık bir örnekle rollback içinde dene.
- [ ] **CSV düğmeden bağımsız.** Yüzde modundayken "CSV İndir" → dosyada yine
      HAM SAYILAR olmalı (yüzde değil).
- [ ] **CSV İndir** çalışmalı; dosyada Kaynak/Kişi/Üye/Oyun/**Oynayan Kişi**
      sütunları ve bir TOPLAM satırı olmalı.
- [ ] **`?` popup'ı okunuyor mu.** Tanım artık tablonun altında paragraf
      DEĞİL — "CSV İndir"in sağındaki `?` rozetine dokun: popup "Kişi"/"Üye"/
      "Oyun" tanımlarını, kohort OLMADIĞINI, Bilinmiyor/Direkt farkını ve
      oranın %100'ü aşabileceğini anlatmalı. Bu tablo bu not olmadan kolayca
      yanlış okunur.
- [ ] **Gizlilik metni güncel.** Gizlilik Politikası → "Toplanan Veriler"de
      kaynak etiketi maddesi olmalı ve "Son güncelleme: 16 Ağustos 2026"
      yazmalı (mobil uygulamadaki metin de AYNI).

## 9.10. Admin — Oyun Süresi (Medyan) + YZ Dengesi (16 Ağustos 2026)

İki değişiklik: süre grafiği ORTALAMADAN medyana geçti (+ p90 serisi) ve
Büyüme > Oyun'a yeni bir "YZ Dengesi" paneli eklendi. Sunucu tarafı canlıda
gerçek admin JWT'siyle doğrulandı (yetki matrisi, dönen değerlerin bağımsız
ölçümle birebir eşleşmesi); aşağıdakiler gerçek istemcide görülmesi
gerekenler.

- [ ] **Grafik başlığı "Oyun Süresi (Medyan)" olmalı** — "Ortalama Oyun
      Süresi" YAZMAMALI. Legend'da üç seri açık (**Genel**, **Tek Oturumda**,
      **Günlere Yayılan**) + **Uzun kuyruk (p90)** KAPALI gelmeli.
- [ ] **Sayı gerçekten düştü mü.** Yerel/tek oturum kovasında değer saatler
      değil DAKİKALAR mertebesinde olmalı (ölçüm anında ~18 dk; eski ortalama
      ~247 dk gösteriyordu). Saatlerce süren bir değer görürsen ortalamaya
      geri dönülmüş demektir.
- [ ] **p90 legend'ı açılınca medyanın belirgin ÜSTÜNDE bir eğri çizmeli**
      (kuyruk gerçek: ölçüm anında 49 oyun 1 saatten, 7 oyun 1 günden uzundu).
      p90 medyanın altında çıkıyorsa seriler karışmış demektir.
- [ ] **Hiç biten oyunu olmayan kovada süre 0 DEĞİL, boş olmalı** (grafikte
      nokta yok / tabloda "—"). 0 dakika "çok hızlı bitmiş oyun" gibi okunur.
- [ ] **Kaynak filtresi hâlâ çalışıyor.** Toplam / Canlı / Yapay Zeka arasında
      geçiş yapınca süre değerleri değişmeli; "Toplam", iki kaynağın ham
      sürelerinin TEK bir medyanı olmalı (iki medyanın ortalaması DEĞİL —
      Toplam genelde iki kaynağın arasında bir yerde çıkar, ikisinin tam
      ortasında değil).
- [ ] **CSV İndir** çalışmalı; başlıkta ortalama değil medyan/p90 sütunları
      olmalı.
- [ ] **YZ Dengesi paneli görünüyor.** Büyüme > Oyun'un üst kısmında, beğeni/
      paylaşma kutularının altında **ÜÇ** kutu: "2 Kişilik — İnsan Birincilik",
      "4 Kişilik — İnsan Birincilik" ve "4 Kişilik — İnsan İkincilik"
      (üçüncüsü 17 Ağustos 2026'da eklendi).
- [ ] **2 kişilikte İKİNCİLİK kutusu OLMAMALI.** Orada rank=2 kaybetmenin
      kendisi (canlıda ölçüldü: ikincilik sayısı = kayıp sayısı) ve k-lig
      puanı getirmiyor — kutu çıkıyorsa filtre atlanmış demektir.
- [ ] **Her kutuda rastgele referansı YAZMALI** — 2 kişilikte "rastgele %50",
      4 kişilikte "rastgele %25" (ikincilik kutusunda da %25: rastgele bir
      sonuçta 1. olmak da 2. olmak da aynı olasılıkta). Bu satır olmadan
      4 kişilikteki düşük yüzde yanlış okunur.
- [ ] **Sayılar tutarlı mı.** Birincilik kutusundaki `NG / NB / NM` toplamı,
      o oyuncu sayısındaki teslimsiz yerel oyun sayısına eşit olmalı; yüzde =
      G / (G+B+M). İkincilik kutusundaki `N/M`nin paydası (M) aynı sayı
      olmalı — iki kutu AYNI oyun kümesini bölüyor.
- [ ] **Üç kutu aynı yükseklikte ve taşmıyor.** Telefonda etiketler 2-3
      satıra sarabilir, bu normal; kutular birbirinden farklı boyda olmamalı
      ve sayfa YANA kaymamalı.
- [ ] **`?` popup'ı toplamı anlatmalı.** Başlığın yanındaki `?`: metin,
      asıl denge sayısının birincilik + ikincilik TOPLAMI olduğunu ve
      rastgele karşılığının %50 olduğunu söylemeli. (Ölçüm anında 4 kişilik:
      %31 + %18 = %49-50 bandı, yani neredeyse tam rastgele.)
- [ ] **Teslim olunan oyunlar sayılmamalı.** 7 günlük terk cezası almış bir
      oyun (bkz. bölüm 4) bu panelde ne "M" ne toplam sayıya girmeli — süre
      aşımıyla biten bir oyundan sonra sayılar DEĞİŞMEMELİ.
- [ ] **Canlı oyunlar sayılmamalı.** Bir Canlı oyun bitir → YZ Dengesi
      sayıları değişmemeli (panel yalnızca Yapay Zeka'ya karşı oynananları
      kapsıyor).
- [ ] **Hiç yerel oyun yokken** panel "Henüz Yapay Zeka'ya karşı tamamlanmış
      oyun yok." demeli — boş kutular ya da "%0" DEĞİL.
- [ ] **Admin olmayan hesap panele hiç giremiyor** (menüde "Admin Paneli"
      satırı yok) — bu iki RPC de admin dışına kapalı.
- [ ] **YZ güçlendi: 2 kişilik birincilik oranı ZAMANLA DÜŞMELİ
      (17 Ağustos 2026, bkz. `mobile/CLAUDE.md` Parça 109).** YZ'nin
      sağ-alt köşedeki ilk hamle kısıtı kaldırıldı — 2 kişilikte YZ HER
      ZAMAN o köşede olduğundan bu panel, düzeltmenin gerçek oyunlarda
      işe yarayıp yaramadığını gösteren TEK ölçüm. Düzeltme öncesi değer
      **%57** (95/167) idi; bundan sonra bitirilen oyunlarda oranın
      rastgeleye (%50) doğru inmesi BEKLENEN davranış, regresyon DEĞİL.
      **Panel kümülatif olduğundan tek bir oyunla okunmaz** — 20-30 yeni
      oyun birikene kadar sayıya bakıp karar verme. 4 kişilik kutular bu
      değişiklikten çok daha az etkilenir (orada YZ koltuklarının yalnızca
      biri köşe 3'te).

## 9.11. Admin — metrik tanımı `?` rozetleri (17 Ağustos 2026)

Grafik/tablo altındaki uzun açıklama paragrafları kaldırılıp tek bir popup'a
taşındı. Ekranda kalan tek "açıklama" aktivasyonun DAĞILIM satırı — o bir
açıklama değil veri.

- [ ] **Her CSV'nin yanında bir `?` var — 11 yer.** 6 grafik (Yeni Üye/Ziyaret,
      Aktif Oyuncu, Arkadaşlık, Oyun Sayısı, Oyun Süresi, Beğeni/Paylaşma) +
      3 tablo (Retention, Kaynak Hunisi, Cihaz) + 2 liste (Üyeler, Geri
      Bildirim). `?` her zaman "CSV İndir"in SOLUNDA.
- [ ] **CSV'si olmayan iki panelde `?` başlığın yanında:** "Aktivasyon" ve
      "YZ Dengesi". Bu ikisi CSV'ye bağlansaydı açıklamaları kaybolurdu.
      Toplam 13 rozet; her birinin `HINTS`te kendi metni var, ikisi aynı
      metni göstermemeli.
- [ ] **`?` bir DAİRE, elips değil** ve bulunduğu satırı büyütmemeli — kontrol
      satırının yüksekliği "CSV İndir"in tek başına olduğu hâlle aynı kalmalı.
- [ ] **Popup açılıyor ve kapanıyor.** Dokun → başlık + metin; "Kapat" ve
      Escape kapatmalı. Panelin kendisi kapanMAMALI (iç içe dialog).
- [ ] **Veri YOKKEN de `?` görünmeli.** Periyodu hiç veri olmayan bir aralığa
      çek (ör. en kısa periyot + boş bir kova): tablo "Bu aralıkta veri yok."
      derken `?` hâlâ orada olmalı — "bu grafik neyi sayıyor?" sorusu tam da
      o anda sorulur. (CSV'nin kaybolması BEKLENEN: indirilecek satır yok.)
- [ ] **Aktivasyonun dağılım satırı EKRANDA kalmalı** ("İlk oyununu bitirme
      dağılımı — aynı gün: N · 1-3 gün: N · sonra: N"). Bu veri, popup'a
      taşınMAMALI; popup yalnızca "Aktive = …" tanımını anlatmalı.
- [ ] **Uzun metin taşmıyor.** "Kaynak Hunisi" popup'ı en uzunu — telefonda
      kart ekrana sığmalı, sığmıyorsa kartın KENDİSİ kaydırılabilmeli (panel
      değil).
- [ ] **Hiçbir grafiğin altında artık hikaye paragrafı YOK.**

## 9.13. Admin — Üyeler tablosundaki kayıt alanları (21 Ağustos 2026)

Tablo artık kayıt formunun tüm alanlarını ve izinleri taşıyor (18 kolon).

- [ ] **Tablo yana kaydırılıyor, SAYFA kaymıyor.** Kaydırma tablonun kendi
      kabında kalmalı; panelin kendisi ya da arka plan yatay kaymamalı.
- [ ] **İsim kolonu SABİT.** Sağa doğru kaydır: İsim hem başlıkta hem her
      satırda solda kalmalı, altından geçen içerik onun İÇİNDEN görünmemeli
      (zemin opak) ve sağ kenarında ince bir ayraç çizgisi olmalı.
- [ ] **Sabit hücre satırın tonunu ALIYOR.** Bir şikayet kartından "Kişiye
      Git →" ile gel: vurgulanan satırın İSİM hücresi de mavi tonlanmalı,
      beyaz kalmamalı. (Farede: satırın üstüne gelince hover tonu da isim
      hücresini kapsamalı.)
- [ ] **Uzun ad taşırmıyor.** 18 karakterden uzun bir ada sahip hesapta isim
      kırpılıp `...` ile bitmeli; sabit kolon geri kalan kolonları ekrandan
      İTMEMELİ (telefonda bile en az birkaç kolon görünür kalmalı).
- [ ] **Girilmemiş her alan `—`.** Cinsiyet/Doğum/Kaynak/Davet Eden'i boş
      bir hesapta kontrol et — boş hücre değil tire görünmeli.
- [ ] **`Koşullar` neredeyse herkeste "Evet".** Kayıt formunda zorunlu
      olduğundan "Hayır" yalnızca onayın kayda hiç geçmediği çok eski
      hesap(lar)da görünür. **Bu, düzeltilmiş bir hatanın regresyon
      kontrolü:** eskiden HERKESTE "Hayır" çıkardı.
- [ ] **Yeni bir kayıt "Evet" ile geliyor.** Test hesabıyla kayıt ol →
      satırında Koşullar "Evet" olmalı. (E-posta doğrulaması açıkken de —
      düzeltmenin asıl noktası bu.)
- [ ] **`Pazarlama` ve tarihi tutarlı.** Onay verilmişse tarih dolu,
      verilmemişse `—`. Hesap Ayarları'ndan onayı aç/kapat → paneli kapatıp
      yeniden aç → yeni değer ve yeni tarih görünmeli (**"ileride yapılan
      değişiklikler yansımalı" maddesinin kontrolü**).
- [ ] **`E-posta Bildirimi` Açık/Kapalı** (Evet/Hayır DEĞİL) ve varsayılanı
      Açık. Hesap Ayarları'ndan kapat → tabloda "Kapalı".
- [ ] **`Kanal` ile `Kaynak` karışmıyor.** Kanal Direkt/Form; Kaynak
      `?ref=` etiketi (ör. `instagram`, `arkadas`, `direkt`) ya da `—`.
- [ ] **`Davet Eden`** yalnızca davet linkiyle gelen üyelerde dolu.
- [ ] **İzin hücrelerinde kırmızı YOK** — yeşil (verilmiş) ya da nötr gri.
      Kırmızı bu tabloda yalnızca "Donduruldu" durumuna ait.
- [ ] **CSV tabloyla aynı.** İndir, aç: kolonlar ekrandakiyle aynı sırada,
      Ad ve Soyad AYRI sütun, boş alanlar gerçekten BOŞ (tire değil).
- [ ] **`?` popup'ı** Koşullar/Pazarlama/E-posta Bildirimi ayrımını ve
      Kanal ↔ Kaynak farkını anlatıyor.
- [ ] **Admin olmayan hiçbir şey göremiyor** (RPC `Yetkisiz erişim.` verir).

## 9.12. Admin — "Hatalar" sekmesi (21 Ağustos 2026, ROADMAP #3)

İstemci hata telemetrisi. Kayıtlar anonim (`client_errors`, hesap kimliği
YOK) ve okuma yalnızca admin'e açık.

- [ ] **Dördüncü sekme görünüyor ve kırpılmıyor.** Telefonda (dar ekran)
      sekmeler 2×2 ızgara, geniş ekranda tek sıra olmalı; hiçbir genişlikte
      etiket kesilmemeli ve yatay kaydırma oluşmamalı. **Bu, düzeltilmiş bir
      hatanın regresyon kontrolü:** dört sekme tek sıraya sığmıyordu ve panel
      onu sessizce kırpıyordu.
- [ ] **Sekmede rozet YOK.** "Geri Bildirim"de kırmızı sayı rozeti çıkabilir,
      "Hatalar"da ASLA — rozet bu projede "bekleyen iş" demek, hata kaydı bir
      gözlem.
- [ ] **Pencere seçici çalışıyor** (24 saat / 7 / 30 / 90 gün) ve seçim
      değişince liste yeniden yükleniyor.
- [ ] **PLATFORM seçici çalışıyor** (31 Ağustos 2026, ROADMAP #11): Tüm
      Platformlar / Web / iOS / Android / App (web). Seçim değişince liste
      yeniden yükleniyor ve **sayılar da daralıyor** — eleme sunucuda,
      gruplamadan ÖNCE yapılıyor. Somut kontrol: iki platformda birden
      görülen bir satır bul ("Platform" sütununda virgülle iki değer yazar);
      "Tüm Platformlar"daki **Kez/Cihaz** sayısı, tek platform seçilince
      DÜŞMELİ. Aynı kalıyorsa eleme istemciye kaymış demektir ve sayılar
      yanlıştır. (31 Ağustos'ta canlıda böyle bir satır vardı:
      `[online_games_repo.load] AuthApiException…` — android+app-web'de
      2 kez/2 cihaz, yalnız android'de 1/1.)
- [ ] **CSV filtreyi izliyor:** bir platform seçiliyken CSV indir → yalnızca o
      platformun satırları ve daraltılmış sayılar olmalı ("CSV ekranda
      görüneni indirir" sözü).
- [ ] ⚠ **Platformu boş olan kayıtlar** (yayınlanmayan masaüstü hedefleri)
      bir platform seçiliyken görünmez; "Tüm Platformlar"da `?` olarak
      durur. Listede olmayan bir platform değeri de aynı şekilde yalnızca
      "Tüm Platformlar"da okunur — `client_errors.platform` üzerinde
      BİLEREK kısıt yok.
- [ ] **Hiç kayıt yoksa "Bu pencerede hata kaydı yok."** — boş bir liste
      değil, açık bir metin.
- [ ] **Kartta "Kez" ve "Cihaz" AYRI AYRI okunuyor.** İkisi karıştırılırsa
      metrik anlamsızlaşır: 40 kez / 1 cihaz bir kişinin döngüsü, 3 kez /
      3 cihaz yaygın bir hata.
- [ ] **Karta dokununca yol, ilk görülme ve örnek yığın açılıyor**, tekrar
      dokununca kapanıyor.
- [ ] **Yol maskelenmiş.** Bir kayıtta `/davet/<token>` ya da `/game/<uuid>`
      HAM görünüyorsa bu bir GİZLİLİK hatasıdır — `/davet/:token` ve
      `/game/:id` olmalı.
- [ ] **CSV iniyor** ve örnek yığını da içeriyor.
- [ ] **`?` popup'ı açılıyor**, "Kez ≠ Cihaz" ayrımını anlatıyor, hız
      sınırını **saatte** 10 diye söylüyor (süreç ömrü DEĞİL) ve platform
      filtresinin sayıları da daralttığını yazıyor.
- [ ] **Admin OLMAYAN bir hesap bu sekmeyi hiç görmemeli** (Admin Paneli
      girişi zaten çıkmaz) — ayrıca doğrudan sorgulayan biri de satırları
      okuyamamalı (tabloda SELECT politikası YOK).
- [ ] **Gerçek bir kayıt oluşuyor mu:** çevrimdışıyken bir Canlı oyunda hamle
      dene — bu BEKLENEN bir durum, telemetriye satır DÜŞMEMELİ. Kaydın
      gerçekten oluştuğunu görmek için tarayıcı konsolundan
      `window.dispatchEvent(new PromiseRejectionEvent('unhandledrejection',
      { promise: Promise.reject(new Error('elle test')), reason: new
      Error('elle test') }))` çalıştır → panelde "elle test" belirmeli.
- [ ] **Tekrar bastırma:** aynı hatayı arka arkaya iki kez tetikle — panelde
      TEK satır olmalı (aynı imza pencere başına bir kez gönderilir).
      ⚠ 31 Ağustos 2026'da pencere SÜREÇ ÖMRÜNDEN son 1 saate taşındı
      (ROADMAP #10): aynı hata bir saat sonra YENİDEN gönderilir, yani
      "Kez" sayacının artması bir hata değil beklenen davranıştır.
- [ ] **GÜRÜLTÜ ELENİYOR (23 Ağustos 2026, ilk gerçek veriden):** Siteyi
      **Instagram/Facebook uygulamasının içindeki tarayıcıdan** (Android)
      aç, biraz gez ve sekmeyi kapat → panelde
      `Error invoking postMessage: Java exception…` YA DA `Script error.`
      BELİRMEMELİ. Bunlar uygulama-içi tarayıcının kendi enjekte ettiği
      script'ten geliyor, bizim kodumuzla ilgisi yok. Belirirse filtre
      kırılmıştır (`isThirdPartyError`).
- [ ] **Oturum düşmesi hata sayılmıyor:** girişliyken başka bir sekmeden
      çıkış yap (ya da tarayıcı depolamasından `sb-*-auth-token` anahtarını
      sil) ve eski sekmede "Arkadaşınla" sekmesine dön →
      `permission denied for function list_my_online_games` panele
      DÜŞMEMELİ. **Ama bu, aynı mesajı sonsuza dek gizlemek DEĞİL:** oturumu
      geçerli bir kullanıcı aynı mesajı alıyorsa o GERÇEK bir grant
      hatasıdır ve panelde görünmeli.

## 9.15. Admin — Sürüm Dağılımı + hata kartında sürüm (23 Ağustos 2026)

Mağaza öncesi hazırlık. **Bugün app yayında olmadığı için tablo yalnızca
web/bilinmiyor satırları gösterir — asıl sınama uygulamalar çıkınca.**

- [ ] Büyüme > Kullanıcı'da **"Sürüm Dağılımı"** tablosu Cihaz'ın hemen
      altında görünüyor; sayı sütununun başlığı **"Başlangıç"** (Ziyaretçi
      DEĞİL — bu tablo oyun açılışı sayıyor).
- [ ] Sürümsüz satırlar **—** ile çiziliyor (web'in sürümü yok; "bilinmiyor"
      yazmak eksik veri izlenimi verirdi).
- [ ] `?` popup'ı "kullanıcı değil oyun açılışı sayar" ve "kapsam yalnızca YZ
      oyunları" sınırlarını söylüyor.
- [ ] CSV iniyor ve başlık satırı "Başlangıç" diyor.
- [ ] Hatalar sekmesinde bir web kaydında **"Sürüm:" satırı HİÇ ÇIKMIYOR**
      (web sürüm göndermez — boş bir satır her web hatasında gürültü olurdu).
- [ ] **APP ÇIKINCA:** telefondan bir YZ oyunu aç → tabloda `ios · 1.0.0`
      (ya da android) satırı belirmeli; uygulamada bir hata oluştur →
      hata kartında "Sürüm: 1.0.0" görünmeli ve "Yol" alanı `game` /
      `online-game` / `intro` gibi gerçek bir ekran adı olmalı, `app` değil.
- [ ] **APP ÇIKINCA:** `mobile_min_supported_version`'ı yükseltmeden ÖNCE bu
      tabloya bak — eski sürümden hâlâ oyun açılıyorsa eşiği yükseltmek o
      kullanıcıları uygulamadan kilitler.

## 9.14. Admin — kart başlıklarında gönderen adı (23 Ağustos 2026)

Geri Bildirim (Gelen Kutusu) ve Şikayetler kartlarının başlığı. Bu bölüm bir
kullanıcı raporunun regresyon kontrolü: ad tek satırdaki TEK esnek öğe
olduğundan telefonda hep O kırpılıyordu (`Ser…`, `kelimekitest4@sh…`).
Admin paneli oturum + admin rolü istediğinden otomatik test EDİLEMİYOR.

- [ ] **TELEFONDA** Gelen Kutusu'nu aç: her kartta gönderenin adı (ya da
      misafirse e-posta adresi) **TAMAMEN** görünmeli — hiçbir yerde `…` ile
      biten bir ad olmamalı. Rozetler (`Yanıtlandı`/`Oyun Sonu`/`Gönderilen`/
      `↳ Cevaben`) ve tarih adın ALTINDAKİ satırda, tarih sağ uçta.
- [ ] **En uzun vaka:** misafir bir geri bildirim (uzun e-posta adresi) ve
      girişli bir üyenin kaydı (ad + ` · ` + e-posta) — ikisi de sarmalı,
      kırpılmamalı, karttan taşmamalı.
- [ ] **Şikayetler alt sekmesinde aynısı:** `{raporlayan} → {raporlanan}`
      satırı tam görünmeli.
- [ ] **Kart açılıp kapanıyor** (başlık iki satıra çıkınca dokunma davranışı
      bozulmamalı) ve `Okundu işaretle` / `Yanıtla` / silme aynen çalışmalı.
- [ ] **Üyeler tablosundaki isim kolonu DEĞİŞMEDİ** — orada 150px kapak ve
      `title` bilinçli (sabit kolon dar ekranda tüm alanı yemesin diye).
