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
  gizlenir) — bu listenin çoğu koşulamaz.
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
- [ ] **İlk açılış.** Uygulama açılıyor, portre kilitli, splash sonrası
      kurulum ekranı geliyor. Logo ve yazı tipleri (Space Grotesk/Mono,
      taşlarda Nunito) doğru — sistem yazı tipine düşmüş görünmemeli.
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
      OYNA. Puan artmalı, YZ kendi turunu oynamalı.
- [ ] **Sürükle-bırak.** Raftan tahtaya, tahtada taşıma, tahtadan rafa geri
      alma. Hayalet taş parmağın ÜSTÜNDE görünmeli (30px kaldırma).
- [ ] **Joker.** Jokeri tahtaya koy → harf seçici açılmalı; konmuş jokere
      tekrar dokun → seçici "Geri Al" seçenekli açılmalı, taş geri
      ALINMAMALI (dokunma ile sürükleme farklı davranır).
- [ ] **Taş değiştirme / pas.** İkisi de sırayı ilerletmeli; pas onay
      sorusu çıkmalı.
- [ ] **Bölge vergisi.** Rakip bölgesine değen bir hamlede "Sınır İhlali!"
      onayı çıkmalı, kabul edilince puan bölünmeli.
- [ ] **Kelime anlamı.** Hamle geçmişinde bir kelimeye dokun → anlam modalı
      (yerel SQLite asset'ten) açılmalı.
- [ ] **Oyun sonu.** Torba+raf bitince sonuç ekranı; sıralama ve kalan taş
      düşümü doğru.
- [ ] **Kalıcılık.** Oyun ortasında uygulamayı TAMAMEN kapat, yeniden aç →
      "Devam Eden Oyun" satırı görünmeli, dokununca aynı tahta/raf/tur ile
      devam etmeli.

## 2. Hesap (auth)

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

**Android tarafı:** Apple üyeliği gerekmiyor. Workflow'un ürettiği
`kelimeki-apk` artefaktını indirip (Actions → çalıştırma → Artifacts) bir
Android cihaza kurabilir ya da Appetize.io gibi bir tarayıcı emülatörüne
yükleyip iPad'den test edebilirsin.
