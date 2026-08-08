# Kelimeki Mobil — Cihaz Test Kontrol Listesi

Bu dosya, `flutter test`'in **yapısı gereği** kapsayamadığı her şey içindir:
gerçek Supabase (auth/RLS/RPC), gerçek platform kanalları (paylaş sayfası,
dosya sistemi), gerçek derleme ve gerçek cihaz davranışı. Otomatik testler
(142 test) veri katmanını **sahte uçlarla** sınıyor — yani "testler yeşil"
demek "sunucuyla gerçekten konuşuyor" demek DEĞİL. Bir sütun adı ya da RPC
parametresi yanlışsa liste sessizce boş döner ve bunu yalnızca burada
görürsün.

Kök dizindeki `TESTING.md` (web) ile aynı disipline tabidir: **bir ilerleme
kaydı değildir**, her sürüm öncesi baştan koşulabilir.

**Ön koşullar:**
- Uygulama gerçek anahtarlarla derlenmiş olmalı:
  `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
  Anahtar verilmezse uygulama tamamen offline moda düşer (hesap özellikleri
  gizlenir) — bu listenin çoğu koşulamaz. CI bunları depo sırlarından
  (`SUPABASE_URL`/`SUPABASE_ANON_KEY`) okuyor; sırlar boşken üretilen APK
  yalnızca 0. ve 1. bölümler için kullanılabilir.
- **Anahtarın gerçekten gömüldüğünü ilk açılışta doğrula:** kurulum
  ekranında hesap/giriş girişi görünüyorsa gömülmüştür; görünmüyorsa APK
  offline modda derlenmiş demektir (sırlar eksik ya da yanlış adla
  girilmiş).
- İki test hesabı (ör. T1/T2) ve **aynı hesapla açılmış bir web oturumu**:
  bu listenin en değerli maddeleri web ↔ mobil aynı veriyi görüyor mu diye
  soruyor.
- Web'de zaten oynanmış birkaç biten oyun (geçmiş/istatistik ekranlarının
  boş kalmaması için).

**Neden bu kadar çok "web'den kontrol et" var:** mobil ve web AYNI tabloları
paylaşıyor (`games`, `local_game_saves`, `profiles`, `player_stats`).
Mobilin yazdığını web'in doğru okuması (ve tersi) bu portun temel
sözleşmesi — tek taraflı bakmak bir hatayı gizleyebilir.

---

## 0. Derleme ve ilk açılış

- [ ] **Derleme geçiyor.** GitHub Actions → "Mobil derleme" → en son
      çalıştırma yeşil olmalı (analiz+testler, Android APK, iOS imzasız).
      Port dalına `mobile/**` altında her push otomatik tetikliyor; elle
      çalıştırma (Run workflow) yalnızca dosya main'e girdikten sonra
      Actions sekmesinde belirir.
      Bu, bu ortamda HİÇ koşulmamış olan `pod install`/gradle adımlarının
      ilk gerçek kanıtı — özellikle beş platform eklentisi
      (sqflite, shared_preferences, supabase_flutter, share_plus,
      path_provider) için.
- [ ] **Uygulama ikonu.** Ana ekranda/Appetize'ın uygulama listesinde
      "kelimeki" el yazısı ikonu görünmeli — Flutter'ın varsayılan mavi kuş
      DEĞİL (7 Ağustos 2026'ya kadar bu hiç üretilmemişti, ilk Appetize
      denemesinde fark edildi).
- [ ] **Splash ekranı.** Uygulama açılırken kısa bir an beyaz zemin
      üzerinde "kelimeki" logosu görünmeli — siyah ekran ya da mavi kuş
      GÖRÜNMEMELİ. Android'de sistem karanlık modda olsa bile splash beyaz
      kalmalı (uygulamanın kendisi karanlık tema desteklemiyor, bkz.
      mobile/CLAUDE.md "Uygulama İkonu / Splash").
- [ ] **İlk açılış.** Uygulama açılıyor, portre kilitli (yatay tutulan bir
      cihazda bile splash ANINDA dikey kalmalı — `screenOrientation="portrait"`
      native kilidi, bkz. CLAUDE.md), splash sonrası kurulum ekranı geliyor.
      Logo ve yazı tipleri (Space Grotesk/Mono, taşlarda Nunito) doğru —
      sistem yazı tipine düşmüş görünmemeli.
- [ ] **Sözlük yükleniyor.** "Oyunu Başlat" başlangıçta "HAZIRLANIYOR…"
      gösterip birkaç saniye içinde etkinleşmeli (63.890 kelime asset'ten
      bir isolate'te okunuyor).
- [ ] **Sürüm kapısı.** Uygulama açılıyorsa `app_config
      .mobile_min_supported_version` kontrolü geçmiş demektir. (Kapıyı
      test etmek istersen o satırı geçici olarak `99.0.0` yapıp uygulamayı
      yeniden aç: "güncelleme gerekli" ekranı çıkmalı — sonra geri al.)

## 1. Oyun (offline çekirdek)

Bu bölüm anahtarsız da koşulabilir; sunucuyla ilgisi yok.

- [ ] **2 kişilik oyun.** Kurulum → Oyunu Başlat → köşeden kelime kur →
      OYNA. Puan artmalı, YZ kendi turunu oynamalı. **Kendi hamlenin mesaj
      satırı ("Misafir: +N puan Kelimeler: …") YZ oynamadan ÖNCE en az ~1
      saniye görünür kalmalı** — YZ'nin kendi mesajıyla ANINDA üstüne
      yazması bir regresyon (8 Ağustos 2026'da bulundu: web'in `AI_THINK_MS`
      gecikmesi ilk portta hiç taşınmamıştı, YZ bir sonraki event-loop
      turunda [≈0 ms] oynuyordu — kullanıcı kendi hamlesinin mesajını hiç
      göremiyordu; düzeltme + enjekte edilebilir `aiThinkDelay`, bkz.
      mobile/CLAUDE.md Parça 21).
- [ ] **Sürükle-bırak.** Raftan tahtaya, tahtada taşıma, tahtadan rafa geri
      alma. Hayalet taş parmağın ÜSTÜNDE görünmeli (30px kaldırma).
- [ ] **Joker.** Jokeri tahtaya koy → harf seçici açılmalı; konmuş jokere
      tekrar dokun → seçici "Geri Al" seçenekli açılmalı, taş geri
      ALINMAMALI (dokunma ile sürükleme farklı davranır). **Seçici hiçbir
      zaman ekranın altından taşmamalı/kesilmemeli** — tüm harfler (A'dan
      Z'ye) görünür ya da kaydırılarak erişilebilir olmalı; özellikle
      YATAY modda ya da kısa yüksekliğe sahip ekranlarda kontrol et (8
      Ağustos 2026'da bir kullanıcı bunu iPad yatay modda kesik gördü —
      `showModalBottomSheet`'in eksik `isScrollControlled` parametresi
      yüzünden, bkz. mobile/CLAUDE.md Parça 20).
- [ ] **Taş değiştirme / pas.** İkisi de sırayı ilerletmeli; pas onay
      sorusu çıkmalı.
- [ ] **Bölge vergisi.** Rakip bölgesine değen bir hamlede "Sınır İhlali!"
      onayı çıkmalı, kabul edilince puan bölünmeli.
- [ ] **Kelime anlamı.** Tahtadaki ONAYLANMIŞ (Oyna ile kesinleşmiş) bir
      taşa dokun → o hücreden geçen yatay/dikey kelimelerin anlam modalı
      (yerel SQLite asset'ten) açılmalı — tetikleyici Hamle Geçmişi
      DEĞİL, doğrudan tahta (`game_screen.dart` `_handleCellTap`'in ilk
      dalı; web'de de aynı — `MoveHistoryModal.tsx`'te hiçbir anlam
      tetikleyicisi yok, tetikleyici `App.tsx`'in `handleCellClick`'i).
- [ ] **Oyun sonu.** Torba+raf bitince sonuç ekranı; sıralama ve kalan taş
      düşümü doğru.
- [ ] **Kalıcılık.** Oyun ortasında uygulamayı TAMAMEN kapat, yeniden aç →
      "Devam Eden Oyun" satırı görünmeli, dokununca aynı tahta/raf/tur ile
      devam etmeli.

## 2. Hesap (auth)

- [ ] **Misafir üyelik kutusu.** Setup ekranını misafir (girişsiz) olarak
      aç — hem boş kurulum formunun altında hem (bir oyun yarıda bırakılıp
      "Devam Eden Oyun" görünümüne düşünce) o görünümün altında "Neden
      Ücretsiz Üye Olmalıyım?" kutusu görünmeli: 6 madde (yeşil ✓ ikonlu,
      web'le birebir aynı sıra/metin) + "GİRİŞ YAP / KAYIT OL" butonu.
      Butona dokununca giriş/kayıt modalı açılmalı. Giriş yapılmışken bu
      kutu hiçbir yerde görünmemeli.
- [ ] **Kayıt.** Yeni bir e-postayla kayıt ol. Takma isim alanı boşluk
      kabul etmemeli; kullanılan bir takma isim yazınca "Bu takma isim
      kullanımda." uyarısı çıkmalı ("✓ Kullanılabilir" satırının yanında
      onay ikonu görünmeli — ✓ karakteri gömülü yazı tiplerinde yok, ikon
      kullanılıyor).
- [ ] **Profil gerçekten kuruldu.** Kayıt sonrası web'e AYNI hesapla gir:
      Hesap Ayarları'nda ad/soyad/takma isim/cinsiyet/doğum tarihi dolu
      olmalı. (Bunları `handle_new_user` trigger'ı yazıyor — mobilin
      metadata'yı doğru gönderdiğinin tek kanıtı bu.)
- [ ] **Pazarlama onayı.** Kayıtta işaretlediysen web'de Hesap
      Ayarları'ndaki kutu işaretli ve altında kabul tarihi görünmeli.
- [ ] **Giriş/çıkış.** Çıkış yapınca hesap özellikleri gizlenmeli; tekrar
      giriş yapınca geri gelmeli.
- [ ] **Oturum kalıcılığı.** Uygulamayı tamamen kapatıp aç — hâlâ girişli
      olmalı (token yenileme `supabase_flutter`'ın kendi deposunda).
- [ ] **Yanlış şifre.** Türkçe hata mesajı gelmeli, ham İngilizce
      ("Invalid login credentials") DEĞİL.
- [ ] **Kullanım Koşulları / Gizlilik.** Kayıt formundaki linkler açılmalı,
      metin web'dekiyle aynı olmalı.
- [ ] **Şifre sıfırlama — ÖN KOŞUL (tek seferlik el işi):** Supabase
      Dashboard → Authentication → URL Configuration → Redirect URLs
      listesine `kelimeki://reset` eklenmiş olmalı. Eklenmeden test etme:
      GoTrue izinsiz redirect'i sessizce Site URL'e (web'e) düşürür,
      bağlantı uygulamayı hiç açmaz — bu bir uygulama hatası DEĞİLDİR.
- [ ] **Şifre sıfırlama — sıcak başlangıç.** Giriş penceresi → "Şifremi
      unuttum" → e-posta gir → "BAĞLANTI GÖNDER" → altın renkli "Şifre
      sıfırlama bağlantısı e-postana gönderildi." çıkmalı. Uygulama AÇIKKEN
      e-postadaki bağlantıya dokun: uygulama öne gelmeli ve her şeyin
      önünde "Yeni Şifre Belirle" penceresi açılmalı. Yeni şifreyi belirle
      → "Şifren başarıyla değiştirildi." → KAPAT → girişli olarak devam
      (recovery oturumu zaten açık). Eski şifreyle giriş artık reddedilmeli,
      yenisiyle çalışmalı.
- [ ] **Şifre sıfırlama — soğuk başlangıç.** Uygulamayı tamamen kapat,
      bağlantıya e-postadan dokun: uygulama açılıp aynı pencere gelmeli
      (PKCE code takası ilk URI'de de çalışıyor olmalı). ÖNEMLİ: bağlantıya
      sıfırlamayı İSTEYEN CİHAZDA dokunulmalı — PKCE verifier o cihazda
      saklı; başka cihazda açılırsa takas başarısız olur, bu beklenen
      davranıştır.
- [ ] **Süresi geçmiş bağlantı.** Eski bir sıfırlama e-postasındaki
      bağlantıya dokun: uygulama normal açılmalı ve KİLİTLENMEMELİ —
      sıfırlama penceresi ÇIKMAZ, görünür bir hata da yok (dönüş linki
      `error` parametresi taşır, supabase_flutter bunu akışa hata olarak
      verir, dinleyici yalnızca loglar; web de aynı durumda sessizce ana
      sayfaya düşüyor — bilinçli parite, ayrı bir hata ekranı eklenmedi).
      Kullanıcı yeni bir bağlantı isteyerek devam eder.
- [ ] **Web etkilenmedi.** Web'deki "Şifremi unuttum" akışı aynen çalışmalı
      (web `redirectTo` olarak kendi origin'ini göndermeye devam ediyor —
      mobil değişikliği yalnızca mobilin kendi isteğini etkiler).

## 3. Bulut kayıtları (web ↔ mobil aynı oyun)

Bu bölüm portun en kritik sözleşmesi: **aynı `local_game_saves` tablosu**.

- [ ] **Mobilde başla → webde sürdür.** Girişliyken mobilde bir YZ oyunu
      başlat, birkaç hamle yap, logoya basıp Setup'a dön. Web'de "Yapay
      Zeka ile" sekmesinde AYNI oyun "Devam Eden Oyunlar"da görünmeli ve
      aynı tahtayla açılmalı.
- [ ] **Webde başla → mobilde sürdür.** Tersi de çalışmalı.
- [ ] **Çoklu oyun.** Girişli kullanıcı aynı anda birden fazla YZ oyunu
      açabilmeli; liste hepsini göstermeli.
- [ ] **Hiç oynanmamış oyun iz bırakmamalı.** Yeni oyun aç, HİÇ hamle
      yapmadan logoya bas → listede kalmamalı (web'in `turnCount<2`
      kuralı). Sekme değiştirip geri dönünce de görünmemeli.
- [ ] **Misafir kaydının taşınması.** Çıkış yap, misafirken bir oyun
      başlat, birkaç hamle yap, Setup'a dön. Sonra giriş yap → oyun
      "Devam Eden Oyunlar"a taşınmalı ve **1. oyuncunun adı hesap adın**
      olmalı ("Misafir" DEĞİL).
- [ ] **Avatar şeridi.** Devam eden oyun satırında insan koltuğu senin
      avatarın/baş harflerin, YZ koltukları robot ikonu olmalı; misafirken
      insan koltuğu "?" olmalı.

## 4. Biten oyun kayıtları ve istatistikler

- [ ] **Oyun bitir → webde gör.** Mobilde bir oyunu sonuna kadar oyna.
      Web'deki Skor Kartı'nda oyun sayısı artmalı, k-lig puanı doğru
      değişmeli (2 kişilikte 1.=+2, 2.=0).
- [ ] **Skor Kartı (mobil).** Üç sekme (Genel / 2 Oyunculu / 4 Oyunculu),
      "Oyuncu İstatistikleri" ve "Oyun İstatistikleri" blokları dolu
      gelmeli. Etiketler Türkçe büyük harfle doğru ("BİRİNCİLİK",
      "BIRINCILIK" değil).
- [ ] **Genel = 2 + 4.** Genel sekmesindeki Toplam Oyun/Birincilik/
      İkincilik, iki sekmenin toplamına eşit olmalı.
- [ ] **k-lig sıralaması.** Liste açılmalı, kaydırınca sayfa sayfa
      yüklenmeli; kendi satırın listede değilse altta kısayol çıkmalı.
      Bir isme dokununca o oyuncunun kartı açılmalı.
- [ ] **Misafir kuyruğu.** Çıkış yap, misafirken bir oyunu BİTİR, sonra
      giriş yap → o oyun hesabına işlenmeli (web'deki Skor Kartı'ndan
      doğrula).
- [ ] **Terk cezası.** (Uzun test — 7 gün.) Bir oyunu yarıda bırak ve 7 gün
      dokunma; sonra Setup'ı aç → oyun silinmeli, k-lig puanından -2
      düşmeli ve "-2 puan" bildirim e-postası gelmeli. Sabırsızsan
      `local_game_saves.updated_at`'i SQL ile 8 gün geriye çekip test et.

## 5. Oyun geçmişi

- [ ] **Liste.** Skor Kartı → "Tüm Oyunları Gör". Kartlarda tarih,
      Canlı/Yapay Zeka rozeti, sıralama, Puan ve **k-lig** sütunları.
      Kaydırınca sayfa sayfa yüklenmeli.
- [ ] **Tahta önizlemesi.** Bir karta dokun → o oyunun bitişteki tahtası
      açılmalı (bölge tonları, köşe filigranları, X2/X3 dahil). Tekrar
      dokunmak kapatmalı.
- [ ] **Web'de oynanan oyunlar da görünmeli** — geçmiş ortak tablodan
      geliyor, mobilde oynanmış olmasına gerek yok.
- [ ] **Beğeni.** Kalbe dokun → dolmalı ve sayı artmalı. Web'de AYNI oyunu
      aç: kalp orada da dolu olmalı.
- [ ] **Beğenenler.** Sayıya dokun → liste açılmalı; bir isme dokununca o
      kişinin skor kartı açılmalı.
- [ ] **Favoriler sekmesi.** Yalnızca beğendiğin oyunları göstermeli —
      başkasının oyununu beğendiysen o da listede olmalı ve satırda
      **senin adın hiçbir yere yapışmamalı** (o satır onun).
- [ ] **Sohbet arşivi.** Web'de oynanmış, mesajlaşılmış bir Canlı oyunun
      kartında konuşma balonu rozeti + mesaj sayısı olmalı; dokununca
      dondurulmuş sohbet açılmalı. Sessize aldığın biri varsa isminin
      yanında 🚫 görünmeli.

## 6. Paylaşma

- [ ] **Paylaş menüsü.** Açık tahta önizlemesine dokun → alttan
      "Paylaş / Kapat / Vazgeç" menüsü, arka plan kararmış olmalı.
- [ ] **Sistem paylaş sayfası.** "Paylaş" → iOS/Android paylaş sayfası
      açılmalı; görsel önizlemesi **skor kutuları + tahta** olmalı.
- [ ] **Link çalışıyor.** Paylaşımı kendine gönder (Notlar/WhatsApp),
      linke tıkla: `kelimeki.com/game/<id>` sayfası **girişsiz** açılmalı
      ve aynı tahtayı göstermeli. (Bu, `set_game_shared` RPC'sinin
      gerçekten çalıştığının kanıtı — bayrak yazılmazsa sayfa boş gelir.)
- [ ] **Kapat.** Menüden "Kapat" tahtayı kapatmalı.

## 7. Son Oynadıklarım

- [ ] **Liste.** Setup'ta (girişli, devam eden oyunların altında) son 5
      biten YZ oyunu görünmeli: avatar şeridi, tarih, puan, k-lig.
- [ ] **Hedefe gitme.** Bir satıra dokun → Tüm Oyunlarım açılmalı ve **o
      oyunun tahtası zaten açık** olmalı, kart ekranın ortasında. (Hedef
      listenin gerisindeyse sayfalama otomatik ilerler — bunu test etmek
      için epeyce bitmiş oyunun olması gerekir.)
- [ ] **Tüm Oyunlarım linki.** Sağ üstteki link listeyi odaklanmadan
      açmalı.
- [ ] **Hiç bitmiş oyun yoksa bölüm hiç görünmemeli** (boş başlık
      gösterilmiyor).

## 8. Dayanıklılık (uçak modu)

- [ ] **Offline oyun.** Uçak moduna al, YZ oyunu oynanmaya devam etmeli
      (motor ve sözlük tamamen yerel).
- [ ] **Offline bitiş kuyruğa girmeli.** Uçak modundayken bir oyunu bitir,
      sonra ağı aç ve uygulamayı yeniden başlat → kayıt sunucuya işlenmeli
      (web'deki Skor Kartı'ndan doğrula). Kayıt kaybolmamalı.
- [ ] **Mükerrer kayıt olmamalı.** Yukarıdaki kayıt Skor Kartı'nda **bir
      kez** görünmeli (aynı id ile ikinci gönderim 23505 alır ve başarı
      sayılır).
- [ ] **Offline listeler çökmemeli.** Uçak modunda geçmiş/k-lig ekranlarını
      aç: boş liste ya da "Yükleniyor…" ile kalmalı, hata ekranı/çökme
      OLMAMALI.

## 9. Görüş Bildir

- [ ] **Misafir gönderim.** Girişsizken bir oyun bitir → GameOver'daki
      "GÖRÜŞ BİLDİR" → mesaj + e-posta yaz → GÖNDER → "Teşekkürler" +
      "{e-posta} ile üyeliğine devam etmek ister misin?" teklifi çıkmalı.
      Web admin panelinde (Geri Bildirim sekmesi) mesaj o e-postayla,
      kaynağı oyun-sonu olarak görünmeli.
- [ ] **Üyelik teklifi → kayıt.** Teklifte EVET → kayıt formu doğrudan
      açılmalı, e-posta önceden dolu; kayıt tamamlanınca admin panelinde
      Üyeler tablosunda kanal "Form" görünmeli (`signup_channel='form'`).
- [ ] **Girişli gönderim.** Girişliyken formda e-posta alanı OLMAMALI
      ("Yanıt e-postan: …" satırı var); gönderilen mesaj admin panelinde
      hesabına bağlı görünmeli.
- [ ] **Terms/Privacy içi link.** Kayıt formundaki Kullanım Koşulları →
      "Görüş Bildir formu" linki formu açmalı (kaynak: genel).
- [ ] **Offline kuyruk.** Uçak modunda mesaj gönder → "Teşekkürler"
      görünmeli (mesaj kuyruğa girdi); ağı açıp Setup'a dönünce mesaj
      sunucuya işlenmeli (admin panelinden doğrula). Kuyruk girişsiz de
      boşalır — oyun kayıtlarının aksine oturum beklemez.
- [ ] **Rate limit.** 10 dakika içinde 4. mesajda "Çok fazla mesaj
      gönderdin…" hatası çıkmalı, mesaj gönderilmemeli.

## 10. Arkadaşlar

- [ ] **Modal + rozet.** Girişliyken hesap menüsünde "Arkadaşlar" satırı
      görünmeli; başka bir hesaptan sana istek gönderilince (web'den
      gönderilebilir) satırda kırmızı sayı rozeti + avatarda kırmızı nokta
      çıkmalı (tazelenme: uygulamayı yeniden açınca ya da modalı açıp
      kapatınca — Realtime bilinçli yok, web'de de yok).
- [ ] **Varsayılan sekme.** Bekleyen istek varken modal "İstekler"
      sekmesiyle açılmalı; Kabul Et → kişi "Arkadaşlarım"a düşmeli,
      web tarafında da arkadaş görünmeli.
- [ ] **Ara & Ekle.** Boş kutuda "Tüm Üyeler" listesi kaydırdıkça
      20'şer büyümeli; 2+ karakterle arama çalışmalı; Ekle → "İSTEK
      GÖNDERİLDİ" (karşı hesapta istek görünmeli); karşılıklı istek
      senaryosu: karşı taraf sana zaten istek göndermişse Ekle anında
      "ARKADAŞSINIZ" olmalı (sunucu trigger'ı) ve e-posta GİTMEMELİ.
- [ ] **Davet linki.** "Arkadaşını Davet Et" sistem paylaş sayfasını
      açmalı; link `https://kelimeki.com/davet/…` biçiminde olmalı ve
      webde açılıp çalışmalı (üye olmayan kayıt akışına düşmeli).
- [ ] **Davet linki uygulamada.** Uygulama kuruluyken
      `kelimeki://davet/<token>` linkine dokun (test için token'ı web
      linkinden alıp şemayı elle kur, ör. notlara yapıştırıp aç):
      girişliysen "X ile artık arkadaşsınız" diyaloğu; girişsizsen
      "giriş yaptığında ekleneceksiniz" önizlemesi, giriş sonrası
      Setup'ta otomatik kabul.
- [ ] **PlayerScoreCard simgesi.** k-lig/arkadaş listesinden birinin
      kartını aç: arkadaşsan yeşil onay işareti (dokun → çıkar onayı),
      değilsen kişi-ekle ikonu (dokun → istek onayı) görünmeli; kendi
      kartında simge OLMAMALI.

## 11. Canlı oyun — davet/kabul + tahta

İki gerçek hesap gerekir (biri web'de olabilir).

- [ ] **Davet gönderme.** ARKADAŞINLA → "+ Yeni Canlı Oyun Aç" → 2
      oyunculu, bir arkadaş seç → Davet Gönder: "Davetiniz gönderilmiştir."
      ekranı; karşı hesapta (web LiveGamesTab ya da mobil) davet
      görünmeli ve davetliye e-posta gitmeli (`notify-game-invite`,
      alıcının `email_notifications_enabled` açıksa).
- [ ] **4 kişilik YZ kuralı.** 4 oyunculu + 2 arkadaşla gönderimde
      "4. koltuk Yapay Zeka…" onayı çıkmalı; HAYIR → listede kalıcı
      "Yapay Zeka" satırı; 3 arkadaş seçiliyken YZ satırı pasif olmalı.
      Sunucu tarafı: oluşan oyunda 4. koltuk `{"type":"ai"}` olmalı.
- [ ] **Davet alma + varsayılan sekme.** Sana davet gönderilmişken
      ARKADAŞINLA'yı aç: "Oyun Davetleri" alt sekmesi kendiliğinden
      seçili gelmeli (rozetle), kartta katılımcılar doğru durum
      etiketleriyle (Davet gönderen/Kabul etti/Bekliyor) listelenmeli.
- [ ] **Kabul → öneri → aktif.** Kabul Et: henüz arkadaş olmadığın
      katılımcı varsa arkadaşlık önerisi modalı çıkmalı (Devam → istek
      web'de görünmeli); tüm davetler kabul olunca oyun iki tarafta da
      "Devam Edenler"e düşmeli, sıra kimdeyse onda "Senin Hamlen
      Bekleniyor" + kalan süre (yalnız sırası olanda) görünmeli.
- [ ] **Ret.** Reddet: oyun HER İKİ tarafın listesinden de anında
      kalkmalı (web `decline_game_invite_abandons_game` — oyun
      `abandoned`).
- [ ] **Realtime.** İki cihaz açıkken web'den yeni davet gönder: mobil
      ARKADAŞINLA açıkken liste ~1sn içinde kendiliğinden güncellenmeli
      (arka plandan dönüşte de — lifecycle resumed tazelemesi).
- [ ] **Süresi dolmuş davet süpürmesi.** 7 günden eski pending bir
      davet varsa (test için `created_at` SQL ile geriye çekilebilir)
      liste açılınca kendiliğinden kaybolmalı (`check_invite_expiry`) —
      davetLİnin listesinde de (hayalet davet regresyonu).
- [ ] **Setup'taki "Arkadaşınla (N)" rozeti.** Bekleyen bir davetin/sırası
      sende olan bir oyunun varken uygulamayı aç: kurulum ekranındaki
      "ARKADAŞINLA" sekme butonunun sağ üst köşesinde kırmızı bir sayı
      rozeti görünmeli VE sekme kendiliğinden "Arkadaşınla" ile açılmalı
      (elle "Yapay Zeka ile"ye dokunmana gerek kalmadan). Bekleyen işi
      giderdikten (hamleni oyna/daveti yanıtla) sonra Setup'a dönünce
      rozet kaybolmalı.
- [ ] **Otomatik geçiş yalnızca girişte, bir kez.** Yukarıdaki sekmeden
      elle "Yapay Zeka ile"ye dön — uygulama tekrar Canlı'ya ZORLA
      GERİ ÇEKMEMELİ (rozet sayısı değişse bile).
- [ ] **Hesap değişimi.** Bekleyen işi olan bir hesapla "Arkadaşınla"
      sekmesindeyken çıkış yap → "Yapay Zeka ile"ye dönmeli (bomboş bir
      "Arkadaşınla" ekranında kalmamalı). Farklı bir hesapla giriş yap —
      o hesabın kendi bekleyen işi varsa yine otomatik "Arkadaşınla"ya
      geçmeli (ilk hesaptan kalan bir kilitlenme olmamalı).
- [ ] **"Arkadaşınla paylaş".** Logonun altındaki "Nasıl oynanır? ·
      Arkadaşınla paylaş" satırındaki linke dokun: sistem paylaş sayfası
      açılmalı, paylaşılan metin "Hemen ücretsiz dene!" + linkte
      `?ref=arkadas` olmalı. Web admin panelinde (Büyüme > Kullanıcı >
      Ziyaretçi Kaynağı) bu linkten gelen bir ziyaret "arkadas" kaynağıyla
      görünmeli (misafirken açılırsa).

### Tahta (oynanış)

- [ ] **Açılış.** "Devam Edenler"de bir oyuna dokun: tahta, KENDİ rafın
      (rakibin taşları HİÇBİR yerde görünmemeli), skorlar ve doğru sıra
      gelmeli. Rakibin rafı ağ trafiğinde de olmamalı (yalnızca
      `get_my_online_rack` çağrılır).
- [ ] **Hamle.** Sıra sendeyken kelime kur → OYNA: hamle web tarafında
      anında görünmeli, skor/torba/raf iki tarafta da tutmalı. Bölge
      vergisi varsa önce "Sınır İhlali!" onayı çıkmalı ve kabul edilen
      pay rakibin skoruna geçmeli.
- [ ] **Sıra sende değilken egzersiz.** Rakibi beklerken taş yerleştir:
      yeşil/kırmızı çerçeve + puan rozeti çalışmalı, mesaj "Kelime geçerli
      — Sıra: X" demeli, OYNA PASİF olmalı. Rakip oynayınca deneme taşları
      kendiliğinden rafa dönmeli ve OYNA aktifleşmeli.
- [ ] **Realtime.** İki cihaz açıkken rakip hamle yapsın: tahtan ~1sn
      içinde güncellenmeli. Uygulamayı arka plana alıp (ya da ekranı
      kilitleyip) rakip oynadıktan sonra geri dön — ön plana dönüşte
      tahta kendiliğinden senkronlanmalı (websocket askıya alınmışsa bile).
- [ ] **PAS GEÇ / DEĞİŞTİR.** İkisi de onay/akış sonrası sunucuya gitmeli;
      taş değiştirmede raf yenilenmeli, torba sayısı DEĞİŞMEMELİ.
- [ ] **YZ koltuğu (4 kişilik).** Sıra YZ'ye gelince nabız atan
      "… hamlesini hesaplıyor" bandı çıkmalı ve YZ birkaç saniye içinde
      kendiliğinden oynamalı (`play-ai-turn`). Uygulamayı kapatıp açmaya
      GEREK KALMAMALI.
- [ ] **Mobil ağ dayanıklılığı (p_move_id).** Hamleyi gönderirken uçak
      moduna al/aç ya da zayıf şebekede dene: aynı hamle İKİ KEZ
      işlenmemeli (skor bir kez artmalı), "Sıra sende değil." gibi sahte
      bir hata çıkmamalı.
- [ ] **Süre aşımı.** Sırası gelenin 48 saati dolmuşsa (SQL ile
      `turn_deadline` geriye çekilerek test edilebilir) ekran açılınca
      otomatik teslim işlemeli ve oyun doğru şekilde sonlanmalı/devam
      etmeli (2 kişilikte biter, 4 kişilikte sıra ilerler).
- [ ] **Logo çıkışı teslim DEĞİL.** Oyun içinde logoya bas: yalnızca Canlı
      listesine dönmeli, oyun bitmemeli, sıra/skor değişmemeli.
- [ ] **Oyun sonu.** Oyun bitince GameOver modalı + kapatınca "CANLI
      LİSTESİ" butonu çıkmalı; skor kartı/k-lig puanları web ile
      tutmalı (`games` satırı her insan katılımcı için ayrı yazılır).

### Mesajlaşma (Faz 1 sohbet + Faz 2 sessize alma/raporlama)

- [ ] **Buton görünürlüğü.** Board altındaki "Mesajlaşma" butonu YALNIZCA
      Canlı oyun ekranında görünmeli; yerel/YZ oyun ekranında hiç
      çizilmemeli.
- [ ] **İlk açılış tanıtımı.** Bir hesapla o oyunda İLK kez "Mesajlaşma"ya
      dokun: "Oyun içi mesajlaşmaya hoşgeldiniz!" penceresi çıkmalı,
      "DEVAM" → sohbet penceresi açılmalı. Aynı hesapla tekrar aç (başka
      bir Canlı oyunda da olabilir) — tanıtım BİR DAHA çıkmamalı (bayrak
      hesaba özel, oyuna özel değil).
- [ ] **Gönder/al gerçek zamanlı.** İki hesapla (biri web olabilir) aynı
      Canlı oyunu aç, mobilden mesaj gönder → web'de ~1sn içinde görünmeli
      (ve tersi). Mesajlar en YENİ üstte sıralanmalı.
- [ ] **Popup + rozet.** Sohbet KAPALIYKEN karşı taraf mesaj gönderirse
      Board'daki "Mesajlaşma" butonunda kırmızı nokta + bir popup
      ("CEVAP VER"/"KAPAT") çıkmalı; CEVAP VER sohbeti açmalı. Sohbet
      AÇIKKEN gelen mesaj popup AÇMADAN doğrudan listeye eklenmeli.
- [ ] **Rozet kalıcılığı (uygulama yeniden başlatma).** Karşı taraf mesaj
      gönderdikten SONRA uygulamayı tamamen kapat, aç, aynı oyuna gir —
      kırmızı nokta hâlâ görünmeli (okundu damgası `chat_last_read`
      tablosunda, cihaza özel). Sohbeti aç → nokta kaybolmalı; uygulamayı
      tekrar kapat/aç → nokta bir daha ÇIKMAMALI (aynı mesajlar için).
- [ ] **Sessize alma.** Dişli ikonundan bir katılımcıyı seç → "Kişiyi
      Sessize Al" → onay → 🚫 rozeti hem ayarlar listesinde hem o kişinin
      mesaj balonlarının yanında görünmeli. O kişiden yeni bir mesaj
      gelirse popup AÇILMAMALI ama mesaj sohbet geçmişinde görünmeye
      devam etmeli. Aynı kişiyle BAŞKA bir Canlı oyun aç — sessize alma
      hâlâ geçerli olmalı (durum kişiye bağlı, oyuna değil).
- [ ] **Raporlama.** Bir katılımcıyı raporla (neden yaz → onayla) →
      "Şikayetiniz iletildi." ekranı; kişi otomatik sessize de alınmalı
      (🚩 rozeti). Web admin panelinde Geri Bildirim → Şikayetler
      sekmesinde rapor "Yeni" olarak görünmeli. Raporlanan hesapta
      HİÇBİR iz/bildirim OLMAMALI (bilinçli tasarım).
- [ ] **Rapor geri çekme.** Raporu geri çek → 🚩 kalkmalı, 🚫 (sessize
      alma) AYRI bir durum olduğundan kalmaya devam etmeli (kaldırmak
      istersen ayrıca kapatman gerekir).
- [ ] **Mesaj balonuna dokunma.** Karşı tarafın bir mesaj balonuna
      doğrudan dokun (rozet olmasa bile) → o kişinin ayarlar detayı
      açılmalı. Kendi mesajına dokununca hiçbir şey olmamalı.
- [ ] **Sohbet arşivi ile tutarlılık.** Oyun bitince (bkz. bölüm 5 "Sohbet
      arşivi") dondurulmuş sohbette de aynı mute/rapor rozetleri (bugünkü
      GÜNCEL duruma göre, o oyundaki değil) görünmeli.

## 12. Hesap Ayarları

- [ ] **Açılış + hidrasyon.** Hesap menüsü → "⚙️ Hesap Ayarları": Ad/
      Soyad/Takma İsim/E-posta/Cinsiyet/Doğum Tarihi alanları profildeki
      GERÇEK değerlerle dolu gelmeli — boş/varsayılan DEĞİL. Pazarlama
      onayı işaretliyse altında "Kabul tarihi: GG.AA.YYYY SS:DD" satırı
      görünmeli.
- [ ] **Ad/Soyad/Takma isim değiştir → Kaydet.** "Profil güncellendi."
      notu çıkmalı; uygulamayı kapatıp aç (ya da webde aynı hesaba gir) —
      yeni değerler kalıcı olmalı, Setup'taki hesap satırı/avatar menüsü
      de yeni ismi göstermeli.
- [ ] **Takma isim benzersizliği.** Başka bir hesabın kullandığı bir isim
      yaz: "Bu takma isim kullanımda." çıkmalı, KAYDET devre dışı kalmalı.
      Kendi mevcut ismini AYNEN yeniden yazarsan kontrol hiç tetiklenmemeli
      ("Kontrol ediliyor…" görünmemeli).
- [ ] **E-posta değişikliği.** Yeni bir e-posta yaz → Kaydet: "E-posta
      değişikliği için onay bağlantısı gönderildi." notu çıkmalı, hesap
      e-postası HENÜZ değişmemiş olmalı (GoTrue onay linkine kadar).
      Yeni adrese gelen onay linkine tıklayınca değişiklik tamamlanmalı.
- [ ] **Profil + e-posta aynı anda değiştirilirse.** İkisini birden
      değiştirip Kaydet'e bas: PROFİL kısmı e-posta adımından önce zaten
      başarıyla tamamlanmışsa, e-posta adımı bir hata verse bile "Profil
      güncellendi." notu KAYBOLMAMALI (ikisi birden görünmeli).
- [ ] **Pazarlama onayı aç/kapa.** Checkbox'ı işaretle → Kaydet → tekrar
      aç (Setup'a dönüp geri gel): işaretli kalmalı, "Kabul tarihi" o anki
      zamanla dolmalı. Kapat → Kaydet → tekrar aç: kabul tarihi satırı
      kaybolmalı (web'in sunucu-taraflı `marketing_consent_at` trigger'ı
      ile aynı davranış — istemci bu alanı hiç göndermiyor).
- [ ] **E-posta bildirimi tercihi.** Kapat → Kaydet → başka bir hesaptan
      kendine bir arkadaşlık isteği/Canlı davet gönder: bildirim maili
      GİTMEMELİ. Şifre sıfırlama gibi zorunlu maillerin hâlâ geldiğini
      doğrula (bu tercihten etkilenmemeli).
- [ ] **Doğum tarihi doğrulaması.** Geçersiz bir tarih (ör. 31/13/1990)
      yaz → Kaydet: Türkçe hata mesajı ("Doğum ayı geçersiz." vb.) çıkmalı,
      hiçbir şey kaydedilmemeli.
- [ ] **Profil fotoğrafı — seçim + izin.** "FOTOĞRAF DEĞİŞTİR"e bas:
      iOS'ta ilk kez galeri izni istenmeli (`NSPhotoLibraryUsageDescription`
      metni Türkçe görünmeli), Android'de doğrudan galeri açılmalı. Galeriyi
      İPTAL edersen hiçbir şey olmamalı (hata/not/YÜKLENİYOR çıkmamalı).
- [ ] **Profil fotoğrafı — başarılı yükleme.** Bir görsel seç: buton kısa
      süreliğine "YÜKLENİYOR…" gösterip devre dışı kalmalı, ardından
      "Profil fotoğrafı güncellendi." notu + YENİ fotoğraf hem bu modalde
      hem Setup/hesap menüsündeki avatarda görünmeli. Uygulamayı kapatıp
      aç (ya da webde aynı hesaba gir) — fotoğraf kalıcı olmalı.
- [ ] **Profil fotoğrafı — RLS.** Yüklenen dosyanın gerçekten `avatars`
      kovasında `<kendi-uid>/avatar.<ext>` yoluna gittiğini (Supabase
      Dashboard → Storage) doğrula; başka bir kullanıcının klasörüne
      yazma denemesi (varsa bir test aracıyla) RLS tarafından reddedilmeli.
- [ ] **Profil fotoğrafı — önbellek kırma.** Yeni bir fotoğrafla üzerine
      yaz (aynı hesap, ikinci kez "FOTOĞRAF DEĞİŞTİR"): eski fotoğraf
      önbellekte takılı kalmadan YENİ görsel hemen görünmeli (URL'deki
      `?v=` zaman damgası sayesinde).
- [ ] **Profil fotoğrafı — sınır kontrolleri.** 2 MB'ı aşan bir görsel
      seçmeyi dene: "Görsel 2 MB'den küçük olmalı." hatası çıkmalı, hiçbir
      şey yüklenmemeli. Bir resim-DIŞI dosya (galeri buna izin veriyorsa)
      seçilirse "Lütfen bir görsel dosyası seç." hatası çıkmalı.

---

## Web derlemesi (ücretsiz tarayıcı test ortamı)

**Adres:** `https://alpcapa.github.io/kelimeki/` — her mobil push'ta
kendiliğinden güncellenir (`.github/workflows/mobile-build.yml`, `web` işi).
Süre limiti yok, kurulum yok, iPad Safari'de doğrudan açılır.

**Neden var:** geliştiricinin elinde ne Mac ne Android cihaz var; Apple
Developer üyeliği askıda (TestFlight yok) ve Appetize'ın ücretsiz katmanı
3 dakikayla sınırlı. Flutter'ın web hedefi **aynı Dart kodunu aynı çizim
motoruyla** (CanvasKit) koşturuyor — yani yukarıdaki listenin büyük
bölümü burada gerçekten koşulabilir.

**Burada koşulabilen bölümler:** 1 (oyun çekirdeği), 2 (auth), 3 (bulut
kayıtları), 4 (biten oyun kayıtları), 5 (oyun geçmişi), 7 (Son
Oynadıklarım), 12 (Hesap Ayarları — profil fotoğrafı hariç, o zaten
salt-okunur/platform bağımsız). Hepsi saf Dart + ağ; platform kanalı
gerektirmiyorlar.

### Web derlemesiyle neyi test EDEMEZSİN

Bunları "geçti" saymak bir hatayı gizler — hepsi hâlâ gerçek cihaz ister:

- **Bölüm 6 (Paylaşma).** `share_plus` web'de tarayıcının Web Share
  API'sine düşer; iOS/Android'in native paylaş sayfası DEĞİL. Görsel
  yakalama + dosya eki davranışı farklı.
- **Bölüm 8 (Uçak modu / dayanıklılık).** Tarayıcının ağ/önbellek
  semantiği native'inkiyle aynı değil; işletim sisteminin uygulamayı
  arka planda öldürmesi de burada yok.
- **Bölüm 0'ın "ilk açılış"ı.** Splash, portre kilidi (`SystemChrome`),
  uygulama ikonu — hiçbiri web'de geçerli değil.
- **Oturum kalıcılığı.** `supabase_flutter` web'de token'ı farklı bir
  depoda tutuyor; "uygulamayı tamamen kapat, hâlâ girişli ol" maddesi
  native davranışı kanıtlamaz.
- **Depolama arka ucu.** Web'de native SQLite yok; `sqflite_common_ffi_web`
  (WASM sqlite3 + IndexedDB) devrede (bkz. `lib/src/storage/web_db.dart`).
  Şema/sorgu/store kodu aynı, ama "gerçek cihazda SQLite dosyası çökme
  anında tutarlı mı" sorusu burada yanıtlanmaz.
- **Gerçek dokunmatik jestler.** Sürükle-bırağın parmak altındaki hissi,
  30px kaldırma, jest çakışmaları — fare/trackpad ile ölçülemez.
- **Performans.** Farklı derleyici (dart2js), farklı GPU yolu.

### İlk açılışta doğrula

- [ ] Sağ üstte **GİRİŞ** butonu ve altbilgide **"sunucu bağlı"** — ikisi
      de varsa Supabase sırları derlemeye gömülmüş demektir.
- [ ] Altbilgide **"Sözlük: 63890 kelime"** (yükleniyor'da takılı kalmamalı).
- [ ] **OYUNU BAŞLAT** çalışıyor ve tahta çiziliyor — depolama katmanı
      (IndexedDB) kurulmuş demektir. "KAYITLAR KONTROL EDİLİYOR…" takılı
      kalırsa web depolama arka ucu bozulmuştur.
- [ ] **Tahtadaki boş hücreler "gömük" görünüyor** (her karenin sol-üstü hafif
      koyu, sağ-altı hafif parlak — nömorfik oyuk); hücreler DÜZ/tek renk
      görünüyorsa CanvasKit özel çizimi bozulmuş demektir. Bu, `flutter test`'in
      YAPISAL OLARAK göremediği bir hata sınıfı (testler native Skia ile render
      eder, tarayıcı CanvasKit ile) — bir kez gerçekten yaşandı, bkz.
      `mobile/CLAUDE.md` Parça 18. Aynı kontrol altın X2 bölgesi ve köşe
      bölgeleri için de geçerli: soluk/yıkanmış görünmemeliler.

---

## TestFlight kurulumu (Apple Developer üyeliği geldiğinde)

Bu bölüm bir kontrol listesi değil, **tek seferlik kurulum** notu.

1. **App Store Connect'te uygulama kaydı.** appstoreconnect.apple.com →
   Uygulamalar → yeni. Bundle ID: `com.kelimeki.kelimeki` (Xcode
   projesinde zaten bu; Android `applicationId` de aynı).
2. **App Store Connect API anahtarı.** Kullanıcılar ve Erişim →
   Entegrasyonlar → App Store Connect API → anahtar üret ("App Manager"
   rolü). `.p8` dosyası **yalnızca bir kez** indirilir. Üç değer gerekli:
   Key ID, Issuer ID, `.p8` içeriği.
3. **GitHub deposu sırları** (Settings → Secrets → Actions):
   `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
   `APP_STORE_CONNECT_KEY_P8`, ayrıca imzalama için `MATCH_PASSWORD` ve
   sertifika deposu erişimi (aşağı bkz.).
4. **İmzalama.** Mac'in olmadığından sertifikayı elle üretemezsin;
   `fastlane match` sertifika + profili CI'da üretip **ayrı bir özel
   depoda** şifreli saklar (ilk çalıştırma üretir, sonrakiler tekrar
   kullanır). Apple hesap başına dağıtım sertifikası sayısı sınırlı
   olduğundan her çalıştırmada yenisini üretmek ÇALIŞMAZ — kalıcı depo
   şart.
5. **Workflow'a yükleme işi eklenir** (`.github/workflows/mobile-build.yml`
   içindeki `ios` işinin devamı): imzalı `.ipa` derle → TestFlight'a
   yükle.
6. **iPad'de test.** TestFlight uygulamasını App Store'dan kur, davet
   maili gelince "Kabul Et" → Kelimeki gerçek bir uygulama olarak açılır.
   Yukarıdaki bölümler bundan sonra koşulabilir.

## Üyelik OLMADAN test (Appetize.io — tarayıcı emülatörü)

**Sabit linkler — bunlara dokun, "Start"a bas, hepsi bu.** Her
Android/iOS derlemesi bittiğinde CI aynı iki Appetize uygulamasını
otomatik günceller; linkler bir daha değişmez, hiçbir yükleme/dosya
seçme adımı gerekmez:

- **Android** → https://appetize.io/app/oexlhcjxdl6onjr4dewaarnvwa
- **iOS** → https://appetize.io/app/onpdavcakhztlouyedivwrcrdi

**Bunlar nasıl kalıcı kalıyor (`.github/workflows/mobile-build.yml`,
"Appetize'a otomatik yükleme"):** derleme bitip GitHub Release'e
yüklendikten hemen sonra, o dosyanın herkese açık indirme URL'i
Appetize'ın REST API'sine (`POST /v1/apps/<public-key>`, gövde
`{"url": ...}`) gönderiliyor — Appetize dosyayı SUNUCU SUNUCUYA kendisi
çekiyor, tarayıcı hiç devreye girmiyor. Bu, `APPETIZE_API_TOKEN` adlı bir
GitHub Actions secret'ı gerektiriyor (Appetize → Organization Settings →
API Token → Developer rolü); secret yoksa adım sessizce atlanır, derleme
etkilenmez.

**Neden bu yola geçildi (7 Ağustos 2026):** iPad Safari'nin dosya
seçicisi/sürükle-bırak'ı `.apk` için günlerce çözülemeyen iki ayrı
belirtiye takıldı — dosya seçicide SOLUK/tıklanamaz kalıyordu (iOS
`.apk` uzantısını tanımıyor, hangi Appetize sekmesi seçili olursa olsun)
ve sürükle-bırak dosyayı "aktif" gösterse de yükleme **400 Bad
Request**'le reddediliyordu. İkisi de tarayıcı/iOS kaynaklı, elle
düzeltilebilecek bir ayar değildi — kökten çözüm dosya seçiciyi
DEVREDEN ÇIKARMAK oldu.

iOS'un neden üyelik gerektirmediği: Appetize iOS uygulamasını cihaz
`.ipa`'sı olarak değil **simülatör `.app`'i** olarak istiyor ve simülatör
derlemeleri imzasız. Bu derleme DEBUG modda (Flutter simülatör için
release desteklemiyor) — JIT ile çalıştığından biraz yavaş, animasyonlar
takılabilir; görsel/işlevsel doğrulama için sorun değil ama PERFORMANS bu
derlemeden ölçülmez.

Artefaktlar (`kelimeki-apk`, `kelimeki-ios-simulator`) hâlâ üretiliyor —
gerçek bir Android cihaza kurmak istersen APK'yı oradan da indirebilirsin.

Üyelik yalnızca gerçek cihaza kurulum (TestFlight) ve App Store yayını
için gerekli.
