# Cihaz testi — Arkadaşlar + Canlı oyun

> `mobile/TESTING.md`'nin 10. ve 11. bölümleri. 26 Ağustos 2026'da o dosya
> 141 KB ile uyarı bandında olduğu için buraya taşındı (kök `CLAUDE.md` →
> "Doküman Boyutu Bütçesi"). **Hiçbir madde değişmedi**, bölüm numaraları
> da korundu — kod/doküman atıfları kırılmasın diye.
>
> **Neden bu ikisi:** ikisi de YAPISI GEREĞİ iki gerçek oturum (iki ayrı
> hesap, çoğu zaman iki cihaz) istiyor; `mobile/TESTING.md`'de kalan
> listenin tamamı tek cihazda koşulabiliyor. Yani kesme noktası boyut değil,
> KOŞULMA BİÇİMİ.
>
> ⚠ Yeni bir arkadaşlık/Canlı oyun kontrolü BURAYA yazılır; kök
> `mobile/TESTING.md`'ye değil.

## 10. Arkadaşlar

- [ ] **Davet linki `?ref=arkadas` taşıyor (Parça 122).** Arkadaşlar →
      "Arkadaşını Davet Et" ile link üret ve paylaş penceresinde/panoda
      URL'e bak: `https://kelimeki.com/davet/<token>**?ref=arkadas**`
      OLMALI. Etiket yoksa davetle gelip üye olan herkes admin panelindeki
      Kaynak Hunisi'nde `direkt` satırına düşer. Linki temiz bir tarayıcıda
      açtığında davet sayfası normal açılmalı (sorgu parametresi token
      çözümünü BOZMAZ).

- [ ] **Modal + rozet.** Girişliyken hesap menüsünde "Arkadaşlar" satırı
      görünmeli; başka bir hesaptan sana istek gönderilince (web'den
      gönderilebilir) satırda kırmızı sayı rozeti + **avatarda aynı sayıyı
      gösteren rozet** (16 Ağustos 2026'ya kadar sayısız bir noktaydı)
      çıkmalı (tazelenme: uygulamayı yeniden açınca ya da modalı açıp
      kapatınca — Realtime bilinçli yok, web'de de yok).
- [ ] **Varsayılan sekme.** Bekleyen istek varken modal "İstekler"
      sekmesiyle açılmalı; Kabul Et → kişi "Arkadaşlarım"a düşmeli,
      web tarafında da arkadaş görünmeli.
- [ ] **Ara & Ekle — liste SONUNA KADAR kaydırılabiliyor (27 Ağustos 2026,
      kullanıcı bildirdi).** Klavye açıkken (kutu `autofocus`, yani modal
      açılır açılmaz açık) parmağını doğrudan BİR ÜYE SATIRININ üzerine koy
      ve yukarı sürükle: modal kaymalı ve listenin sonuna (son üye +
      gerekiyorsa "Yükleniyor…") ulaşılabilmeli. Eskiden liste kendi
      kaydırılabiliri içindeydi ve Flutter iç içe kaydırmayı
      zincirlemediğinden alt ~2,5 satır erişilemiyordu. **Dar ekranda
      dene** — geniş ekranda hata görünmez.
- [ ] **Ara & Ekle — aynı üye İKİ KEZ çıkmamalı (27 Ağustos 2026,
      `20260827153857`).** Karşılıklı istek göndermiş bir çift varsa o üye
      listede tek satır olmalı. Sunucu düzeltmesi, uygulama sürümünden
      bağımsız — eski derlemede de düzelmiş olmalı.
- [ ] **Ara & Ekle.** Boş kutuda "Tüm Üyeler" listesi kaydırdıkça
      20'şer büyümeli; 2+ karakterle arama çalışmalı; **kişi-ekle ikonuna**
      dokun → onay ("… arkadaş olarak eklemek istiyor musun?") → "Arkadaşlık
      isteğiniz iletilmiştir." → satırdaki ikon **kum saatine** dönmeli
      (karşı hesapta istek görünmeli); karşılıklı istek senaryosu: karşı
      taraf sana zaten istek göndermişse mesaj "Arkadaş oldunuz." olmalı
      (sunucu trigger'ı) ve e-posta GİTMEMELİ.
      **Satır aksiyonları 11 Ağustos 2026'da metin butonlarından ikonlara
      indirildi.** Üç ikon: kişi-ekle (mavi) · kum saati (gri, dokun →
      iptal) · kişi-onay (mavi, gelen isteği kabul). Kural: ikon, dokunuşun
      NE YAPACAĞINI söyler; **hiçbiri anında iş yapmaz, hepsi önce onay
      sorar** (dokunup "Vazgeç" dediğinde karşı hesapta hiçbir şey
      OLMAMALI — bunu da kontrol et).
- [ ] **Ara & Ekle arkadaşları GÖSTERMEZ (aynı gün, kullanıcı isteği).**
      Zaten arkadaş olduğun biri ne aramada ne "Tüm Üyeler" listesinde
      çıkmalı — kırmızı "adam-" ikonu bu iki listede HİÇ görünmemeli
      (arkadaş çıkarma yalnızca "Arkadaşlarım" sekmesinde ve skor kartında).
      Bir gelen isteği buradan kabul edince satır listeden düşmeli ("Arkadaş
      oldunuz." mesajından sonra "Arkadaşlarım"da görünmeli). Aramada
      bulunanların HEPSİ arkadaşsa "Bulunanların hepsi zaten arkadaşın"
      metni çıkmalı; "Tüm Üyeler"de bir sayfanın tamamı arkadaş çıksa bile
      liste boş kalmamalı, sonraki sayfa kendiliğinden gelmeli.
- [ ] **Davet linki.** "Arkadaşını Davet Et" sistem paylaş sayfasını
      açmalı; link `https://kelimeki.com/davet/…` biçiminde olmalı ve
      webde açılıp çalışmalı (üye olmayan kayıt akışına düşmeli).
- [ ] **Davet linki uygulamada — uygulama AÇIKKEN (sıcak).** Uygulama
      arka planda AÇIK dururken `kelimeki://davet/<token>` linkine dokun
      (test için token'ı web linkinden alıp şemayı elle kur, ör. notlara
      yapıştırıp aç): girişliysen "X ile artık arkadaşsınız" diyaloğu;
      girişsizsen "giriş yaptığında ekleneceksiniz" önizlemesi, giriş
      sonrası Setup'ta otomatik kabul.
- [ ] **Davet linki uygulamada — uygulama KAPALIYKEN (soğuk başlangıç,
      13 Ağustos 2026, Parça 87).** Uygulamayı görev yöneticisinden
      TAMAMEN kapat, sonra aynı linke dokun: uygulama açılmalı VE davet
      işlenmeli. Öncesinde token sessizce kayboluyordu (`AppLinks`in
      soğuk-başlangıç linkini yalnızca İLK dinleyiciye bir kez basması;
      o dinleyici supabase_flutter oluyordu) — sıcak akış çalıştığı için
      görünmüyordu, bu yüzden İKİ maddeyi de ayrı ayrı koş. **Mükerrer
      kontrolü:** "artık arkadaşsınız" diyaloğu YALNIZCA BİR KEZ
      çıkmalı, üst üste iki kez DEĞİL.
- [ ] **Davet REDDEDİLİNCE artık konuşuyor (26 Ağustos 2026, Parça 142).**
      Girişliyken **KENDİ** davet linkine dokun: sunucu bunu kalıcı olarak
      reddediyor (`P0001`) ve ekranda **"Kendi linkinle arkadaş olamazsın."**
      (sunucunun kendi cümlesi) çıkmalı. Öncesinde ekranda HİÇBİR ŞEY
      olmuyordu. Aynı şekilde bozuk/uydurma bir token da bir mesaj almalı.
- [ ] **Ağ hatasında davet KAYBOLMUYOR (26 Ağustos 2026, Parça 142).**
      Uçak modunu aç, sonra geçerli bir davet linkine dokun (girişliyken):
      bağlantı mesajı çıkmalı. Uçak modunu KAPAT ve uygulamayı öne getir
      (kapatıp açman gerekmez) — davet kendiliğinden işlenmeli, "artık
      arkadaşsınız" çıkmalı. Öncesinde token o anda siliniyordu ve davet
      tamamen kayıptı.

- [ ] **Misafirken geçersiz link.** Çıkış yap, bozuk bir
      `kelimeki://davet/<uydurma>` linkine dokun: **"Bu davet linki
      açılamadı — süresi dolmuş ya da geçersiz olabilir."** çıkmalı.
      Uçak modunda aynı linke dokununca ise **bağlantı** mesajı çıkmalı
      (teşhis uydurulmuyor: uygulama linkin geçersizliğini çevrimdışıyken
      BİLEMEZ). Bağlantıyı açıp aynı linke tekrar dokun — bu kez gerçek
      sonuç görünmeli (çevrimdışı dalı "gösterildi" damgasını geri alıyor).

- [ ] **PlayerScoreCard simgesi.** k-lig/arkadaş listesinden birinin
      kartını aç: arkadaşsan ismin yanında **yeşil "kişi-onay"** (adam +
      tik) görünmeli — listelerdeki kırmızı "adam-" DEĞİL; bu bilinçli bir
      istisna (kullanıcı kararı: aksiyon sütununda değil, ismin yanında
      duruyor). Dokununca yine **çıkarma onayı** açılmalı. Arkadaş değilsen
      kişi-ekle ikonu (dokun → istek onayı) görünmeli; kendi kartında simge
      OLMAMALI. **Dikkat:** aynı yeşil-adam-tik glyph'i "Ara & Ekle"de MAVİ
      olarak "gelen isteği kabul et" demek — renkler karışmamalı.
- [ ] **Onay/sonuç diyalogları (9 Ağustos 2026, Parça 32).** Aynı ekrandaki
      arkadaş-ekle/çıkar/kabul-et/iptal-et onay diyaloğu (yatay/geniş
      ekranda bile — özellikle iPad'de kontrol et) küçük/kompakt kalmalı,
      ekranın TAMAMINA yayılmamalı. Her işlemin (Gönder/Çıkar/Kabul Et/
      İptal Et) SONRASINDA bir "Tamam" sonuç mesajı çıkmalı: "Arkadaşlık
      isteğiniz iletilmiştir." / "Arkadaşlıktan çıkarıldı." / "Arkadaş
      oldunuz." / "Arkadaşlık isteği iptal edildi." (karşılıklı anlık kabul
      durumunda "{isim} ile artık arkadaşsınız." — bu mobile özgü, web'de
      karşılığı yok, bilinçli).
- [ ] **Ağ hatasında SAHTE başarı YOK (13 Ağustos 2026, Parça 89).**
      Uçak modunu aç, sonra Arkadaşlar'da bir isteği **Reddet** / **Kabul
      Et** ve birine **arkadaşlık isteği gönder**: üçünde de
      **"İşlem başarısız oldu."** çıkmalı. Öncesinde sırasıyla "İstek
      reddedildi." / "Arkadaş oldunuz." / "Arkadaşlık isteğiniz
      iletilmiştir." gösteriliyordu — hiçbiri gerçekleşmemişken. Uçak
      modunu kapatıp tekrar dene: normal sonuç mesajları dönmeli.
- [ ] **Kişiye dokunmak skor kartını açar — ÜÇ sekmede de (11 Ağustos
      2026, Parça 53).** "Arkadaşlarım", "İstekler" ve "Ara & Ekle"
      (hem arama sonucu hem "Tüm Üyeler") satırlarında **avatara/isme**
      dokun → o kişinin skor kartı açılmalı. Aksiyon ikonu bundan
      AYRIŞIK olmalı: ikona dokunmak kartı DEĞİL onay diyaloğunu
      açmalı (ikisi birbirini yutmamalı). Kartın kendi arkadaşlık
      simgesinden bir işlem yapıp (ör. çıkar) kartı kapatınca satırdaki
      ikon ANINDA yeni duruma dönmeli — eski ikon kalmamalı.
- [ ] **Moderasyonu arkadaş satırından geri alma (14 Ağustos 2026, Parça
      91).** Ön koşul: bir Canlı oyunda karşı tarafı sessize al ya da
      şikayet et (bölüm 11), sonra o oyun **bitsin** (ya da listeden
      düşsün). Arkadaşlar → "Arkadaşlarım": o kişinin satırında,
      "arkadaşlıktan çıkar" ikonunun **SOLUNDA** 🚩 (yalnızca sessize
      aldıysan 🚫) çıkmalı. Dokun → "Kişi Ayarları" paneli; oradan
      "Şikayeti Geri Çek" / "Sessizden Çıkar" → **onay adımı** → sonuç
      mesajı. Panel kapanınca ikon **HEMEN** kaybolmalı.
      **Asıl kanıt burada:** oyun bittikten sonra sohbet penceresine
      artık girilemediğinden, bu panel olmadan şikayeti geri çekmenin
      TEK yolu o kişiyle yeni bir oyun açmaktı.
      **Negatif eş — atlama:** hiçbir moderasyon durumu OLMAYAN bir
      arkadaşın satırında bu ikon **hiç görünmemeli**. Yalnızca "ikon
      var" kontrolü, ikonu koşulsuz çizen yanlış bir kural altında da
      geçerdi.
      **Kapsam:** panelden YENİ şikayet açılamaz (bilinçli — şikayet
      hakkında olduğu konuşmaya bağlı); panel bunu söyleyen bir not
      göstermeli. Emoji fallback'i de burada kontrol edilmiş oluyor —
      🚫/🚩 boş kare (tofu) çıkmamalı.
      **14 Ağustos 2026'da HER İKİ YOL da koşuldu ve GEÇTİ:**
      - *Sessizden çıkarma:* ikon çıktı, panelden çıkarıldı, ANINDA
        kalktı. Üretimden teyit — mute tablosu 0 satıra düştü ve
        provenance oyunu **`finished`**'dı, yani kısayol tam da
        tasarlandığı yerde (oyun bittikten sonra) çalıştı.
      - *Şikayet → geri çekme:* aktif bir oyunun sohbetinden şikayet
        edildi (08:19:14), arkadaş satırında 🚩 çıktı, panelden geri
        çekildi (08:20:11) → ikon **kaybolmadı, 🚫'ye döndü** (şikayet
        otomatik sessize aldığından ve geri çekme mute'a dokunmadığından
        — beklenen davranış), sonra sessizden de çıkarılınca tamamen
        kalktı. Yani tasarımın DÖRT durumu da tek turda görüldü.
      **Üretimden okunan asıl kanıt: `handled` = `false` KALDI.** Bu,
      4 Ağustos'ta yazılıp 10 gün ölü bir SQL overload'ında mahsur kalan
      düzeltmenin (`fix_withdraw_report_wrong_overload`) **mobil
      istemciden** ilk doğrulaması — web'de aynı gün, mobilde burada.

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
      **Test davetini `create_online_game` RPC'siyle kur** (istemciden
      DEĞİL): davet e-postasını istemci gönderdiğinden RPC doğrudan
      çağrıldığında kimseye mail gitmez. **Gerçek bir kullanıcının
      bekleyen davetini ASLA kullanma** — süpürme onu da iptal eder.
      **17 Ağustos 2026'da koşuldu ve GEÇTİ** (tek kullanımlık T1→T2
      daveti `abandoned`'a döndü, sonra tamamen silindi; `game_invites`
      satırı tasarım gereği `pending` kalıyor — kovaların hepsi
      `online_games.status`'e de baktığından davet hiçbir listede
      görünmüyor).
- [ ] **Setup'taki "Yapay Zeka ile (N)" rozeti (15 Ağustos 2026, Parça
      101).** Girişliyken devam eden N adet YZ oyunun varken kurulum
      ekranını aç: "YAPAY ZEKA İLE" sekme butonunun sağ üstünde N rozeti
      olmalı ve bu sayı hemen altındaki **"DEVAM EDENLER" alt sekmesinin
      rozetiyle AYNI** olmalı (kapsayan sekme = kapsananların toplamı).
      Regresyon belirtisi: alt sekmede sayı var, üstteki sekmede hiç yok.
      Misafirken tek slot olduğundan rozet 0 ya da 1 olur.
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

- [ ] **Etiket puntoları (Parça 55; metin/punto 30 Ağustos 2026'da
      değişti).** "Devam Edenler"deki durum etiketi **"SIRA SENDE!"**
      (yeşil) / **"SIRA RAKİPTE"** (kırmızı) web'le aynı boyda olmalı
      (13 px); hemen altındaki kalan-süre satırı (10 px, yalnızca
      "N saat M dakika kaldı") ondan belirgin KÜÇÜK — ikisi eşit
      görünüyorsa regresyon. Davet kartlarının sağ üstündeki süre etiketi
      (9 px) bu ikisinden de küçük.

### Tahta (oynanış)

- [ ] **Açılış.** "Devam Edenler"de bir oyuna dokun: tahta, KENDİ rafın
      (rakibin taşları HİÇBİR yerde görünmemeli), skorlar ve doğru sıra
      gelmeli. Rakibin rafı ağ trafiğinde de olmamalı (yalnızca
      `get_my_online_rack` çağrılır).
- [ ] **Hamle.** Sıra sendeyken kelime kur → OYNA: hamle web tarafında
      anında görünmeli, skor/torba/raf iki tarafta da tutmalı. Bölge
      vergisi varsa önce "Sınır İhlali!" onayı çıkmalı (kabul butonu
      solda, VAZGEÇ sağda — bkz. mobile/CLAUDE.md Parça 25; metin bölüm
      1'deki gibi renkli vurgulu) ve kabul edilen pay rakibin skoruna
      geçmeli.
- [ ] **Bingo bonusu Canlı'da da yazıyor (17 Ağustos 2026).** 7 taşı birden
      koyup OYNA → mesaj satırında `(Bingo bonusu +25)`. **Rakibin bingo'su
      geldiğinde de yazmalı** — Canlı ekranı mesajı reducer'dan DEĞİL
      `online_game_moves` satırlarından yeniden üretiyor (`row.bingo`), yani
      yerel oyundan TAMAMEN ayrı bir kod yolu; bölüm 1'de geçmesi burayı
      kanıtlamaz. Web'de aynı oyunu açıp metnin birebir aynı olduğunu
      doğrula (dört kopya: iki reducer + iki Canlı ekran).
- [ ] **Sıra sende değilken egzersiz.** Rakibi beklerken taş yerleştir:
      yeşil/kırmızı çerçeve + puan rozeti çalışmalı, mesaj "Kelime geçerli
      — Sıra: X" demeli, OYNA PASİF olmalı. Rakip oynayınca deneme taşları
      kendiliğinden rafa dönmeli ve OYNA aktifleşmeli.
- [ ] **Terk edilen oyunun -2 cezası "Devam Et"e basınca da yazılmalı
      (13 Ağustos 2026, Parça 89 — kalıcı testi YOK, elle kontrol şart).**
      Misafirken bir YZ oyununu `turnCount>=2` olacak kadar oynayıp Setup'a
      dön; cihaz saatini 7 gün ileri al (ya da 7 gün bekle) ve satır hâlâ
      görünürken **"Devam Et"e dokun**. Beklenen: satır kaybolur VE terk
      kaydı üretilir (bu cihazda giriş yapınca Skor Kartı'nda -2'li teslim
      kaydı görünmeli). Öncesinde bu dal olayı ATOMİK olarak silip çöpe
      atıyordu — ceza kalıcı olarak kayboluyordu. Karşılaştırma: aynı
      senaryoyu "Devam Et"e BASMADAN (yalnız Setup'ı açıp kapatarak)
      koşmak zaten çalışıyordu.
- [ ] **"Sıra: X" bandının rengi (13 Ağustos 2026, Parça 88).** Sıra
      rakipteyken çıkan kırmızı bant, ekrandaki DİĞER kırmızılarla (bandın
      kendi nabız noktası, hata mesajları) AYNI tonda olmalı — öncesinde
      zemin/çerçeve tahtaya özel bir kırmızıdan (`#E0483A`) geliyordu, metin
      ve nokta ise token kırmızısından (`#DC2626`): tek bantta iki ton.
      Bandın artık kabarık bir gölgesi (`shadow-raised`) ve web'le aynı
      dolgusu olmalı — web'le yan yana koyup karşılaştır.
- [ ] **Çevrimdışı Canlı oyun AÇILIŞI (14 Ağustos 2026, Parça 96).** Uçak
      modunda "Devam Edenler"den bir Canlı oyuna dokun: ekran
      "Yükleniyor…"da ASILI KALMAMALI; "Canlı oyun için internet gerekiyor"
      başlıklı panel + **TEKRAR DENE** + **← CANLI LİSTESİ** çıkmalı.
      Uçak modunu kapatıp TEKRAR DENE'ye bas → oyun normal açılmalı.
      Aynısını web'de de dene (iki platform aynı metni gösteriyor).
- [ ] **Çevrimdışı panel DÜZGÜN çiziliyor (Parça 96).** Uçak modunda bir
      Canlı oyuna gir: kart İÇERİĞİNE göre küçülmeli — ekran boyu beyaz bir
      dikdörtgen OLMAMALI (`NeoBox` shrink-wrap etmiyor, o yüzden düz
      `DecoratedBox` kullanılıyor).
- [ ] **Çevrimdışı kelime anlamı (Parça 96).** Uçak modunda bir YZ oyununda
      oynanan kelimeye dokun: "Kelime anlamları için internet bağlantısı
      gerekiyor." çıkmalı — "Bu kelimenin anlamı bulunamadı." DEĞİL.
      **NATIVE derlemede (gerçek iOS/Android) bu mesaj HİÇ çıkmamalı:**
      orada sözlük uygulama paketinde, gerçek anlam gelmeli. Web
      derlemesinde ise sözlük HTTP ile çekildiğinden mesaj beklenen davranış.
- [ ] **Çevrimdışı sekme metinleri (Parça 96).** Uçak modunda Setup'a dön:
      ARKADAŞINLA'nın üç alt sekmesi de "İnternet bağlantısı yok" demeli.
      YAPAY ZEKA İLE sekmesinde devam eden oyunun yoksa linkli öneri
      ("Hemen oyun aç.") çıkmalı ve link yeni oyun formunu açmalı; devam
      eden oyunun VARSA liste normal görünüp oynanabilmeli.
- [ ] **Tahta alt şeridinde "Çevrimdışı" uyarısı (14 Ağustos 2026, Parça
      97).** Bir oyun (YZ ya da Canlı — İKİSİNİ DE dene, ayrı ekranlar)
      AÇIKKEN uçak modunu aç: şeridin sağında, "Nasıl Oynanır?"ın hemen
      solunda kırmızı **"Çevrimdışı"** belirmeli — ekrandan çıkıp girmeye
      GEREK KALMADAN. Puntosu kardeşleriyle (Hamleler · Mesajlaşma · Nasıl
      Oynanır?) aynı görünmeli, daha küçük değil. Uçak modunu kapat: uyarı
      kendiliğinden kalkmalı. **Uçak modunu Kontrol Merkezi'nden aç (yani
      uygulamadan ÇIKARAK) — Parça 98'in kök sebebi tam buydu:** uygulama
      askıdayken bağlantı olayı kaçırılıyor, öne dönüşte durum yeniden
      okunmazsa uyarı hiç çıkmıyor. **Aynısını web'de de kontrol et** — oradaki
      punto düzeltmesi (#256) de henüz cihazda görülmedi, ikisi birlikte
      bakılmalı.
- [ ] **Çevrimdışı hamlede METİN (Parça 96).** Uçak modunda OYNA/PAS GEÇ:
      mesaj satırında **"Bağlantı yok — Canlı oyun için internet
      gerekiyor."** çıkmalı — ham "ClientException/Failed to fetch" DEĞİL.
      Karşılaştırma: sunucunun kendi reddi (ör. sıra sende değilken bir
      şekilde gönderim) hâlâ kendi metniyle görünmeli.
- [ ] **Gönderim hatası taşlar TAHTADAYKEN de görünür (14 Ağustos 2026,
      Parça 95).** Sıra sendeyken geçerli bir kelime kur, uçak modunu aç ve
      OYNA'ya bas: mesaj satırında bir HATA görünmeli ("Bağlantı yok."
      benzeri bir ağ hatası) — "Oyna tuşuyla kelimeyi onayla." DEĞİL ve
      sessizlik hiç değil. Taşlar tahtada kalmaya devam eder. Sonra bir
      taşa dokunup taslağı değiştir: hata kaybolmalı (geçmişe ait).
      Aynısını web'de de kontrol et (iki ekran bu davranışı paylaşıyor).
      Öncesinde port "GÖNDERİLİYOR" deyip ~5sn sonra sessizce eski hâline
      dönüyordu, web hiçbir şey yapmıyordu.
- [ ] **Oyun sonu → "Oyun Geçmişi" DOLU gelir (14 Ağustos 2026, Parça 95).**
      Canlı bir oyunu bitir, GameOver modalındaki "OYUN GEÇMİŞİ"ne dokun:
      oyunun tüm hamleleri listelenmeli. "Henüz kazanılmış bir puan yok."
      görüyorsan regresyon — kıyas için tahta altındaki "Hamleler" linki
      (aynı listeyi göstermeli) ve YZ oyununun oyun sonu modalı.
- [ ] **Sohbet ön plana dönüşte tazelenir (14 Ağustos 2026, Parça 95).**
      İki cihaz/sekmeyle: app'i arka plana al (ana ekrana çık ya da başka
      bir sekmeye geç), karşı taraftan web'den mesaj gönder, sonra app'e
      DÖN. Mesaj kendiliğinden gelmeli — oyundan çıkıp tekrar girmeye
      GEREK KALMADAN. Popup ÇIKMAMALI (arka planda birikenler için tek bir
      okunmamış rozeti); sohbeti açınca mesaj listede olmalı. Bu, iPad'de
      iki Safari sekmesi arasında gidip gelerek de üretilebilir.
- [ ] **Boş taslakta OYNA/GERİ AL (13 Ağustos 2026, Parça 88).** Sıra
      SENDEYKEN, hiç taş yerleştirmeden OYNA'ya bas: buton **aktif** olmalı
      ve mesaj satırında **"Harf yerleştirilmedi."** çıkmalı — gri/tepkisiz
      bir buton DEĞİL. Sunucuya hiçbir şey gitmemeli (sıra sende kalmalı).
      GERİ AL de boş taslakta aktif olmalı (basınca hiçbir şey olmaz,
      zararsız). Aynısını yerel/YZ oyununda da kontrol et — iki ekran bu
      davranışı paylaşıyor.
- [ ] **Sürüklerken rakip oynarsa (Parça 58).** Bir taşı PARMAĞINI
      KALDIRMADAN sürüklerken karşı taraftan hamle gelsin: sürükleme o an
      bitmeli — hayalet taş kaybolmalı, rafta boş slot kalmamalı ve sayfa
      yeniden KAYDIRILABİLİR olmalı (alt butonlara ulaşılabilmeli).
      Regresyon belirtisi: taş havada asılı kalır ve ekran tamamen
      tepkisiz görünür.
- [ ] **Oyun bitince "TEKRAR OYNA" (Parça 59).** Bir Canlı oyunu sonuna
      kadar bitir: raf satırındaki buton "TEKRAR OYNA" olmalı ("CANLI
      LİSTESİ" DEĞİL). Dokun → onay ("… ile aynı kadroda yeni bir oyun
      açılacak … Emin misin?", kabul butonu SOLDA). VAZGEÇ hiçbir şey
      göndermemeli. Onayla → "Davetiniz gönderilmiştir." → TAMAM listeye
      dönmeli ve yeni oyun "Rakip Bekleniyor"da görünmeli; KARŞI hesapta
      yeni bir davet + `notify-game-invite` e-postası olmalı.
- [ ] **Tekrar Oyna — 4 kişilik + YZ.** 4 kişilik ve son koltuğu YZ olan
      bitmiş bir oyunda aynı akış: onay metninde "4. koltuk yine Yapay Zeka
      olacak." çıkmalı ve yeni oyunda 4. koltuk gerçekten `{"type":"ai"}`
      olmalı (sunucudan doğrula). Biten oyunu SEN kurmamışsan da çalışmalı —
      kurucu artık sen olursun.
- [ ] **Tekrar Oyna — artık arkadaş değilseniz.** Rakibi arkadaşlıktan
      çıkarıp dene: "Yalnızca arkadaşlarını davet edebilirsin." mesajı
      görünmeli ve TAMAM'a basınca LİSTEYE DÖNÜLMEMELİ (oyun ekranı ayakta
      kalmalı).
- [ ] **Takılı sürüklemeden kurtuluş (web `clearStuckDrag` portu).** Bir
      taşı sürüklerken uygulamayı arka plana al (ana ekrana çık) ve geri
      dön: sürükleme temizlenmiş olmalı — uygulamayı KAPATIP AÇMAK
      gerekmemeli. Aynı kontrol YZ oyununda (Yapay Zeka ile) da geçerli.
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
- [ ] **Süre aşımı — İKİ DALI DA koş, biri ötekini kanıtlamaz.** Sırası
      gelenin 48 saati dolmuşsa (SQL ile `turn_deadline` geriye çekilerek)
      "Arkadaşınla" sekmesini açmak süpürmeyi tetiklemeli. **2 kişilik:**
      oyun BİTER (`status='finished'`, `end_reason='surrender'`), teslim
      olanın skoru 0 + rafı torbaya döner, kalanın skorundan kendi raf
      puanı düşülür, `games` satırları yazılır (teslim eden rank 2 / lose),
      k-lig **−2**, ve teslim olana **uyarı e-postası** gider. **4 kişilik:**
      oyun BİTMEZ — sıra bir sonraki teslim olmamış koltuğa geçer,
      `turn_count` +1, `turn_deadline` yeniden 48 saate kurulur ve **mail
      GİTMEZ** (mail yalnızca oyun gerçekten bittiğinde). Her iki dalda da
      `online_game_states.bag_count` gerçek torbaya EŞİT olmalı (4 Ağustos
      `check_turn_timeout_bag_count` regresyonu — hata iki dalda da vardı,
      yalnızca 4 kişilikte görünüyordu).
      **17 Ağustos 2026'da koşuldu ve GEÇTİ** (2 kişilik: torba 70→77,
      k-lig 10→8, `net._http_response` `{"ok":true,"sent":1}` ve mail
      ulaştı; 4 kişilik: torba 65→72, oyun `active` kaldı, mail yok).
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
- [ ] **Uyarı pencerelerinin tasarımı (Parça 102).** Yeni mesaj popup'ı,
      sohbet tanıtımı, "Pas Geçiyorsun!", "Tekrar Oyna", "Sınır İhlali!" ve
      arkadaşlık onayları — HEPSİ web'in kartıyla aynı görünmeli: panel
      zemini, yumuşak düşen gölge, yuvarlatılmış köşe, altta MAVİ dolgulu
      kabul + gri nötr vazgeç butonu (Material'ın beyaz kartı ve mavi METİN
      butonları DEĞİL). Kabul butonu her zaman SOLDA. Dar bir telefonda kart
      ekranın iki yanında yalnızca 16px boşluk bırakmalı (eskiden 40'tı).
      Referans görüntü: `mobile/app/build/screenshots/dialog_message_popup.png`.
- [ ] **Popup kapanınca rozet temizlenir (HATA DEĞİL).** Popup çıktıysa
      kapatmak (CEVAP VER / KAPAT — ikisi de) o mesajı okundu sayar, yani
      rozet kalmaz. Bu bilinçli ve web'de de aynı; rozetin kalıcı olduğu tek
      durum susturulmuş göndericidir (popup hiç çıkmaz).
- [ ] **Popup + rozet.** Sohbet KAPALIYKEN karşı taraf mesaj gönderirse
      Board'daki "Mesajlaşma" butonunda **sayı rozeti** + bir popup
      ("CEVAP VER"/"KAPAT") çıkmalı; CEVAP VER sohbeti açmalı. İKİ mesaj
      gelirse rozet **2** göstermeli. Rozet etiketin son harflerini kapatır
      (kabul edilen bedel) ama sağdaki "Nasıl Oynanır?" ile ÇAKIŞMAMALI.
      Sohbet AÇIKKEN gelen mesaj popup AÇMADAN doğrudan listeye eklenmeli.
- [ ] **Popup kendiliğinden KAPANMAZ; zemine dokunmak da kapatmaz
      (Parça 104).** Popup çıktıktan sonra hiçbir şeye dokunmadan bekle —
      kapanmamalı (otomatik kapanma YOK, web'de de yok). Sonra popup'ın
      DIŞINDA bir yere (tahta/başlık) dokun — yine kapanmamalı; kapanmanın
      tek yolu CEVAP VER / KAPAT. **Bu madde 16 Ağustos 2026'da eklendi:**
      Flutter'ın `showDialog` varsayılanı zemin dokunuşuyla kapanmaktı,
      web'de ise popup'ın zemini tıklanamaz. Bildirilen bir hata değil,
      kod incelemesinde bulundu (bkz. `mobile/CLAUDE.md`, Parça 104).
- [ ] **Rozet kalıcılığı (uygulama yeniden başlatma).** Karşı taraf mesaj
      gönderdikten SONRA uygulamayı tamamen kapat, aç, aynı oyuna gir —
      rozet hâlâ görünmeli (okundu damgası `chat_last_read` tablosunda,
      cihaza özel). Sohbeti aç → rozet kaybolmalı; uygulamayı tekrar kapat/aç
      → rozet bir daha ÇIKMAMALI (aynı mesajlar için).
- [ ] **Sessize alma.** Dişli ikonundan bir katılımcıyı seç → "Kişiyi
      Sessize Al" → onay → 🚫 rozeti hem ayarlar listesinde hem o kişinin
      mesaj balonlarının yanında görünmeli. O kişiden yeni bir mesaj
      gelirse **popup AÇILMAMALI** ama **rozet ARTMALI**
      (15 Ağustos 2026 kararı: mute yalnızca popup'ı bastırır) ve mesaj
      sohbet geçmişinde görünmeye devam etmeli. Aynı oyunda
      susturulMAMIŞ başka biri yazarsa hem rozet hem popup çıkmalı
      (4 kişilik bir oyunda kontrol edilebilir). Aynı kişiyle BAŞKA bir
      Canlı oyun aç — sessize alma hâlâ geçerli olmalı (durum kişiye
      bağlı, oyuna değil).
- [ ] **Raporlama.** Bir katılımcıyı raporla (neden yaz → onayla) →
      "Şikayetiniz iletildi." ekranı; kişi otomatik sessize de alınmalı
      (🚩 rozeti). Web admin panelinde Geri Bildirim → Şikayetler
      sekmesinde rapor "Yeni" olarak görünmeli. Raporlanan hesapta
      HİÇBİR iz/bildirim OLMAMALI (bilinçli tasarım).
- [ ] **Rapor geri çekme.** Raporu geri çek → 🚩 kalkmalı, 🚫 (sessize
      alma) AYRI bir durum olduğundan kalmaya devam etmeli (kaldırmak
      istersen ayrıca kapatman gerekir).
      **Geri çekilen rapor admin'in bekleyen işinden DÜŞMEMELİ (14 Ağustos
      2026, Parça 90).** Web admin panelinde Geri Bildirim → Şikayetler:
      kart "Geri Çekildi" rozetiyle görünmeli ama SOLUKLAŞMAMALI, ve hesap
      menüsündeki "Admin Paneli" satırının kırmızı sayacı azalmamalı — geri
      çekme raporlayanın kararı, admin'in incelemesi değil. (Bu davranış 4
      Ağustos'ta yazıldı ama yanlış bir SQL overload'ına uygulandığı için 10
      gün üretimde hiç çalışmadı; bu madde onun ilk gerçek uçtan uca
      kontrolü.)
- [ ] **Çevrimdışıyken davete BASILAMAZ (15 Ağustos 2026'da ölçüldü —
      madde bu yönde DÜZELTİLDİ).** Uçak modunda "Oyun Davetleri" alt
      sekmesi tek bir **"İnternet bağlantısı yok"** ekranı göstermeli;
      davet kartı (dolayısıyla Kabul Et/Reddet) hiç çizilmemeli. Çevrimiçi
      olunca kart geri gelmeli.
      **Bu madde bir dönem "uçak modunda davete bas → 'İşlem başarısız
      oldu.' çıkmalı" diyordu ve YANLIŞTI:** o metin Parça 90'da yazıldı,
      AYNI GÜN Parça 96 sekmeyi çevrimdışı kapısının arkasına aldı ve
      senaryo ulaşılamaz hâle geldi. `kFriendActionFailed` yine de ölü kod
      DEĞİL — bağlantı sinyali "online" derken isteğin düştüğü durumlar
      (captive portal, sunucu/RLS hatası, sekme çizildikten sonra kopan
      bağlantı) hâlâ o dala düşüyor; orada mesaj görünmeli.
      **Arkadaşlık isteklerinin (FriendsModal) yanıtı bu kapının DIŞINDA**
      — orada çevrimdışı gate YOK, bkz. bölüm 10'daki kendi maddesi.
- [ ] **Mesaj balonuna dokunma.** Karşı tarafın bir mesaj balonuna
      doğrudan dokun (rozet olmasa bile) → o kişinin ayarlar detayı
      açılmalı. Kendi mesajına dokununca hiçbir şey olmamalı.
- [ ] **Sohbet arşivi ile tutarlılık.** Oyun bitince (bkz. bölüm 5 "Sohbet
      arşivi") dondurulmuş sohbette de aynı mute/rapor rozetleri (bugünkü
      GÜNCEL duruma göre, o oyundaki değil) görünmeli.
