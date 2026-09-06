# Kelimeki

**Kelimeki**, köşe bölgeleri ve akıllı yapay zeka rakiple oynanan, mobil öncelikli **Türkçe kelime oyunudur**. Vite + React + TypeScript + Tailwind CSS ile geliştirilmiştir.

## Oyun

- **13×13 tahta** — çapraz kelime yerleştirmeli klasik bir tahta oyunu mekaniği; ortadaki 5×5 altın bölge her kelimeyi x2 yapar, tam merkez ayrıca X3 (üç kat kelime).
- **Köşe bölgeleri** — Her oyuncu 4×4'lük bir köşeden başlar (2 kişilik oyunda sol-üst ↔ sağ-alt, 4 kişilik oyunda dört köşenin her biri bir oyuncuda). İlk hamle köşenin ev işaretli tek karesine değmek zorundadır. İlk hamleden sonra bir rakibin bölgesine taş koymanın hiçbir ön koşulu yok — her zaman serbest.
- **Genişleyen bölge** — Bir oyuncunun bölgesi 4×4 köşeyle sınırlı değil; köşesinden başlayıp yalnızca kendi taşlarıyla ortogonal olarak bağlı hücrelere doğru genişler, her hamleden sonra yeniden hesaplanır. Rakip bölgesine vergi ödeyerek konan bir taş, kendi zincirine bağlıysa artık oynayanın bölgesine geçer.
- **Bölge vergisi** — Bir hamle rakip bölgesinin içine düşerse (girme) ya da dışarıdan sınırına bitişik olursa (değme), hamlenin puanından bir pay bölge sahibine aktarılır. Etkileşilen rakip bölge sayısına (n) göre: n=1'de 2/3 oynayanda kalır, 1/3 bölge sahibine gider; n=2'de yarısı oynayanda kalır, kalan yarısı iki sahip arasında eşit bölünür (kişi başı 1/4); n=3'te 1/3 oynayanda kalır, kalan 2/3 üç sahip arasında eşit bölünür (kişi başı 2/9) — genel formül `basePts*(n+1)/(6n)`. Hamle öncesinde onay penceresi gösterilir.
- **Akıllı YZ** — Rafından heceleyebildiği, sözlükçe geçerli en yüksek puanlı hamleyi arar; çapraz kelimeleri de doğrular.
- **Zorluk (Kolay · Normal · Zor)** — Yapay Zeka oyununun başında seçilir ve oyun boyunca değişmez (4 kişilikte üç YZ'ye birden). Normal = en iyi hamle; Kolay = en iyi 4 hamleden rastgele biri; Zor henüz seçilemiyor (yeni motoru ROADMAP #23 Faz 5'te). k-lig puanı seviyeye göre: birinci Kolay +1 / Normal +2 / Zor +4, 4 kişilikte ikinci 0 / +1 / +2, teslim her seviyede -2. Canlı oyunda seviye yok (Normal). YZ oyununun kartlarında ve tahta altındaki şeritte seviye rozeti (Kolay yeşil · Normal turuncu · Zor kırmızı); Canlı oyunda rozet yok. Web ve Flutter portunda aynı seçici/rozet/puan (parite testli).
- **Tam sözlük** — TDK Güncel Türkçe Sözlük (12. baskı) kaynaklı **~63 bin oynanabilir kelime**, anlamlarıyla birlikte.
- **Türkçe alfabe** — Ç, Ğ, İ, Ö, Ş, Ü dahil tam harf dağılımı ve puanlar. Joker (`?`) desteklenir. Torba, oyuncu sayısından bağımsız olarak sabit 100 taş.
- **Bingo bonusu** — 7 taşın tamamını tek hamlede kullanınca +25 puan.
- **k-lig ödül & rütbe sistemi** — Puana bağlı 9 kademeli rütbe mührü (Çaylak 0 → Meraklı 50 → Oyuncu 100 → Usta 250 → Şampiyon 500 → Destan 1000 → Efsane 2500 → Uzaylı 5000 → Kozmik 10000 — damga güncel puandan türetilir, puan gerilerse kademe de düşer; Kozmik en üst kademedir) ve aynı eşiklere bağlı tek seferlik ödüller (**ödül = eşik/10**: 50 → +5, 100 → +10, 250 → +25, 500 → +50, 1000 → +100, 2500 → +250, 5000 → +500, 10000 → +1000; verilen ödül puan sonradan gerilese de geri alınmaz). Ödül/rütbe/100'lük puan eşikleri, damga+konfeti animasyonlu bir kutlama banner'ıyla bir kez bildirilir; rütbe gerilerse üzgün bir bilgilendirme banner'ı çıkar. Kademelerin ve ödüllerin tam listesi oyun içindeki "Nasıl oynanır?" ekranında da var.
- **Dokunmatik** — Mobil öncelikli düzen; harf seç → kareye dokun → **Oyna**.

## Teknoloji

- [Vite 5](https://vitejs.dev/)
- [React 18](https://react.dev/) + TypeScript
- [Tailwind CSS](https://tailwindcss.com/)
- [Supabase](https://supabase.com/) — opsiyonel (auth, lider tablosu, istatistikler)
- [Vercel](https://vercel.com/) ile dağıtım

## Geliştirme

```bash
npm install      # bağımlılıkları yükle
npm run dev      # geliştirme sunucusu (http://localhost:5173)
npm run build    # üretim derlemesi (dist/)
npm run preview  # derlemeyi yerelde önizle
npm run lint     # TypeScript tip kontrolü
npm run test     # Playwright testleri (tests/*.spec.ts — duman + yazı ölçeği)

# Birim test çatısı yok; riskli saf mantık ayrı doğrulama betikleriyle sınanır:
npm run verify-cloud-save-mirror # bulut kaydının çevrimdışı karar mantığı
npm run verify-fetch-my-games    # oyun geçmişi: ağ hatası ↔ boş liste ayrımı
npm run verify-live-games-load    # canlı oyun listesi: düşen istek sessizce tekrarlanır
npm run verify-shared-realtime    # canlı oyun aboneliği: üç çağıran → tek Realtime kanalı
npm run verify-demo-board        # karşılama katmanındaki tanıtım tahtası sözlüğe karşı doğrulanır
npm run verify-remaining-tiles   # "Kalan Taşlar" dökümü ↔ oyun sonu raf düşümü
npm run verify-swap-invariants   # taş değiştirme: taslak taşlar yok olmuyor + senkron seçimi düşürüyor
npm run verify-edge-engine-parity # motorun üçüncü kopyası (Edge Function) src/'den ayrışmadı mı
npm run verify-error-reporting   # istemci hata telemetrisi: ne kaydedilir/kaydedilmez, tekrar bastırma, hız sınırı
npm run verify-away-return       # "uzun aradan sonra öne dönüş = ekrana yeniden giriş" eşiği

# Üretilmiş dosyalar — kaynağı değişince ELLE yeniden üretilir:
npm run generate-logo-paths  # LogoMark.tsx + portun logo_mark_data.dart'ı (tek komut, iki taraf)
npm run generate-klig-paths  # KLigMark.tsx + portun klig_mark_data.dart'ı
npm run generate-icons       # favicon / app icon (public/) — og-image DEĞİL
npm run generate-og-image    # public/og-image.png (sosyal paylaşım kartı)
npm run generate-play-assets # Play mağaza ikonu + öne çıkan görsel
npm run generate-store-header # marketing/store/ — mağaza başlık görseli (4096×2304, ≤1 MB)
npm run generate-golden-vectors  # Flutter portu parite fixture'ları (motor değişince ZORUNLU)
npm run generate-meanings-db     # meanings.json → portun SQLite asset'i
npm run verify-league-tiers      # k-lig kademe/ödül tablosu: migration SQL'i ↔ TS
npm run verify-league-points     # k-lig puan tablosu (Kolay/Normal/Zor): SQL ↔ TS ↔ Dart
npm run simulate-ai-levels       # YZ seviye kadranı: üretimin findAIMoves+pickTopMove çiftiyle "en iyi N'den rastgele" ↔ Normal, YZ↔YZ (ROADMAP #23)
npm run generate-initial-main-view-golden # giriş sekmesi kuralı: web→port davranış golden'ı
npm run generate-demo-board-dart # karşılama tahtası → portun tanıtım ekranı için demo_board_data.dart
```

`npm run test` kritik yolu kontrol eder (uygulama açılıyor, oyun başlıyor, YZ
oynuyor, SPA fallback çalışıyor) — kapsamlı bir paket değil. Canlı oyun,
mesajlaşma, e-posta bildirimleri gibi iki gerçek oturum ve gerçek gelen kutusu
gerektiren akışların elle koşulan kontrol listesi: [`TESTING.md`](TESTING.md) (admin paneli kontrolleri: [`docs/testing-admin.md`](docs/testing-admin.md)).

Flutter portunun kendi testleri `mobile/app`'te `flutter test` ile koşar
(veri katmanı sahte uçlarla sınanır); gerçek Supabase/platform davranışının
cihazda koşulan listesi: [`mobile/TESTING.md`](mobile/TESTING.md) (arkadaşlık + Canlı oyun turları: [`mobile/docs/testing-arkadaslar-canli.md`](mobile/docs/testing-arkadaslar-canli.md); tarihli etkileşim/görünüm turları: [`mobile/docs/testing-ux-turlari.md`](mobile/docs/testing-ux-turlari.md)). Derlemeyi
(imzasız iOS + Android APK + web) doğrulayan GitHub Actions iş akışı
`mobile/**` dokunan her PR'da ve `main`e her push'ta otomatik koşar:
`.github/workflows/mobile-build.yml`.

Web tarafında `lint`+`build`+`test`'i koşturan ayrı bir iş akışı var
(18 Ağustos 2026'da eklendi — `src/**`/`scripts/**`/`tests/**` dokunan her
PR'da ve `main`e her push'ta): `.github/workflows/web-ci.yml`. Aynı iş akışı
2 Eylül 2026'dan beri **mobil test paketini de** koşuyor (`parite` işi):
mobil testlerin bir bölümü web kaynak dosyalarını okuyor, yani saf bir web
değişikliği bir mobil testi düşürebiliyor — bir kez düşürdü de.

## Proje Yapısı

```
src/
├── main.tsx                     # ince kabuk: fontlar + derleme kimliği + "karşılama katmanı mı, uygulama mı" kararı
├── boot.tsx                     # uygulamanın gerçek açılışı (React ağacı, PWA, /game//davet path eşlemesi) — main.tsx DİNAMİK import eder
├── components/
│   ├── Board.tsx                # 13×13 oyun tahtası (köşe renkleri, dinamik bölge hatları, bonus bölgesi)
│   ├── Rack.tsx                 # oyuncunun harf kutusu
│   ├── Tile.tsx                 # tek harf bileşeni
│   ├── GameHeader.tsx           # skor, sıra göstergesi
│   ├── GameOver.tsx             # oyun sonu ekranı
│   ├── Setup.tsx                # oyun başlangıç / oyuncu kurulum ekranı
│   ├── LogoMark.tsx             # "kelimeki" logosu — statik SVG path (üretilmiş, bkz. scripts/generate-logo-paths.mjs), font bağımsız
│   ├── UserMenu.tsx             # hesap menüsü (giriş / hesap ayarları / skor kartı)
│   ├── HelpModal.tsx            # nasıl oynanır sayfası
│   ├── AuthModal.tsx            # giriş / kayıt / şifre sıfırlama
│   ├── ResetPasswordModal.tsx   # şifre sıfırlama e-postasındaki bağlantıdan sonra yeni şifre belirleme
│   ├── AccountSettingsModal.tsx # profil düzenleme (avatar, kullanıcı adı) + "Hesabımı Sil" girişi
│   ├── DeleteAccountModal.tsx   # hesabı uygulama içinden silme onayı (açılışta kuru çalıştırma raporu)
│   ├── ScoreCard.tsx            # oyuncu istatistikleri
│   ├── ScoreStatsSection.tsx    # "Oyuncu / Oyun İstatistikleri" kutu ızgarası (ScoreCard ve PlayerScoreCard ortak)
│   ├── RecentGamesSection.tsx   # Setup'taki "Yapay Zeka ile"/"Arkadaşınla" sekmelerinde son 5 biten oyun listesi
│   ├── GameHistoryModal.tsx     # geçmiş oyunların listesi (kalp: favori · balon: sohbet arşivi · dosya: hamle dökümü · karta tıkla: tahta önizlemesi), Tümü/Favoriler filtresi
│   ├── GameBoardPreview.tsx     # bir oyunun bitiş anındaki tahtasının salt-okunur önizlemesi
│   ├── MoveHistoryModal.tsx     # oyun geçmişi (hamle hamle)
│   ├── ChatThread.tsx           # oyun içi mesajlaşma: paylaşılan sohbet baloncuğu listesi (canlı + arşiv)
│   ├── ChatModal.tsx            # oyun içi mesajlaşma: Canlı oyunda gerçek sohbet penceresi (yalnızca Canlı oyunlar)
│   ├── ChatSettingsModal.tsx    # oyun içi mesajlaşma Faz 2: kişi sessize alma / rapor etme ayarları (ChatModal'ın dişli ikonundan açılır)
│   ├── GameChatHistoryModal.tsx # oyun içi mesajlaşma: bitmiş bir oyunun dondurulmuş sohbet kaydının salt-okunur görünümü
│   ├── Leaderboard.tsx          # lider tablosu (k-lig)
│   ├── KLigMark.tsx             # "k-lig" logosu — statik SVG path (üretilmiş, bkz. scripts/generate-klig-paths.mjs), font bağımsız
│   ├── RankSeal.tsx             # k-lig rütbe rozeti (kurdeleli roset SVG — k-lig satırları, Skor Kartı başlığı, tanıtım sayfası, ödül banner'ı)
│   ├── RankInfoModal.tsx        # Skor Kartı'ndaki mühre dokununca açılan rütbe bilgi popup'ı (puan + ödül payı + sıradaki hedef)
│   ├── RewardBanner.tsx         # k-lig kutlama/düşüş banner'ı (rütbe atlama · puan eşiği ödülü · 100'lük kilometre taşı · rütbe gerileme — damga+konfeti animasyonu)
│   ├── LeagueRewardsHost.tsx    # görülmemiş league_rewards kayıtlarını çekip tek birleşik RewardBanner gösteren sürücü
│   ├── CountBadge.tsx           # ortak kırmızı sayaç rozeti (sekme başlıkları, "Arkadaşlar" satırı vb.)
│   ├── MeaningModal.tsx         # kelime anlamı penceresi
│   ├── RemainingTilesModal.tsx  # torbada kalan taşlar
│   ├── WildcardModal.tsx        # joker taşı harf seçimi
│   ├── FeedbackModal.tsx        # görüş/şikayet bildirme formu
│   ├── AdminDashboard.tsx       # admin paneli: üyeler, oyunlar, büyüme (aktif oyuncu/aktivasyon/retention/kaynak hunisi/YZ dengesi), geri bildirim + şikayetler (yalnızca is_admin); metrik tanımları "?" rozetlerinin açtığı popup'ta
│   ├── MemberMessageModal.tsx   # admin panelinden bir üyeye serbest metinli mesaj gönderme compose modalı
│   ├── AdminChatTranscriptModal.tsx # admin paneli Şikayetler sekmesi: bitmiş bir Canlı oyunun tam sohbet dökümü
│   ├── PlayerScoreCard.tsx      # bir oyuncunun ScoreCard'ının salt-okunur görünümü (admin panelinden ve k-lig'den açılır)
│   ├── GrowthChart.tsx          # admin büyüme grafiği (generic zaman serisi çizgi grafiği)
│   ├── PrivacyModal.tsx         # gizlilik politikası
│   ├── TermsModal.tsx           # kullanım koşulları
│   ├── Modal.tsx                # paylaşılan modal kabuğu
│   ├── ActionSheet.tsx          # iOS tarzı alttan açılan aksiyon menüsü (ör. tahta önizlemesi → Paylaş/Kapat)
│   ├── SharedGamePage.tsx       # herkese açık /game/:id sayfası (girişsiz de erişilebilir)
│   ├── FriendsModal.tsx         # arkadaş arama/ekleme, gelen istekler, kalıcı davet linki paylaşımı
│   ├── FriendInvitePage.tsx     # herkese açık /davet/:token sayfası (girişsiz de erişilebilir) — davet kartı + oyunun tanıtımı (tahta/ikonlar landing/ ile tek kaynak)
│   ├── LiveGamesTab.tsx         # Canlı sekmesi: davet bekleyen/aktif/rakip bekleyen oyun listesi + Kabul/Reddet
│   ├── LiveGameCreateForm.tsx   # Canlı oyun kurulumu: oyuncu sayısı + arkadaş seçici + davet gönderme
│   ├── FriendSuggestModal.tsx   # bir Canlı davet kabul edildikten sonra, henüz arkadaş olunmayan katılımcılara toplu istek gönderme önerisi
│   ├── FriendModerationModal.tsx # arkadaş satırındaki 🚫/🚩 rozetinden açılan geri alma paneli (sessizden çıkar / raporu geri çek)
│   ├── OnlineGameScreen.tsx     # gerçek Canlı oyun ekranı — Board/Rack/GameHeader'ı Supabase state'ine (Realtime) bağlar
│   ├── RelationIcons.tsx        # arkadaşlık ilişkisi ikonları (ekle · bekliyor · kabul et · çıkar) — FriendsModal ve PlayerScoreCard ortak; üçünün path'i Flutter portuyla aynı fonttan, "bekliyor" (kişi + kum saati) elle çizildi ve porta parite testiyle bağlandı
│   ├── Avatar.tsx               # profil fotoğrafı bileşeni
│   ├── PlayerAvatarRow.tsx      # oyun kartlarında "N Kişilik Oyun" başlığı yerine geçen katılımcı avatarları (YZ → robot, misafir → "?")
│   ├── PlayerBadge.tsx          # renkli oyuncu sıra/koltuk rozeti
│   ├── AiLevelBadge.tsx         # YZ zorluk rozeti (Kolay/Zor; Normal'de render edilmez) — 4 oyun kartı + Setup "devam eden oyun" satırı
│   ├── LandscapeHint.tsx        # yatay modda gösterilen kapatılabilir dikey-mod önerisi banner'ı
│   ├── ErrorBoundary.tsx        # kök seviye React crash yakalayıcı
│   ├── LoadingNote.tsx          # ortak "Yükleniyor…" göstergesi (Flutter portundaki KLoadingNote ile birebir)
│   └── AddToHomeScreen.tsx      # PWA ana ekrana ekle
├── game/
│   ├── types.ts       # GameState, Player, Tile tipleri
│   ├── constants.ts   # tahta sabitleri, köşe hesapları, bonus konumları
│   └── gameReducer.ts # useReducer ile oyun durum makinesi
├── data/
│   ├── words.ts          # Türkçe kelime listesi (~63 bin kelime, üretilmiş)
│   ├── wordSetLoader.ts  # words.ts'i ayrı bir chunk olarak lazy-load eder
│   ├── meanings.json     # kelime → anlamlar (tembel yüklenir, ~6,2 MB — service worker precache'inde BİLEREK yok)
│   ├── meanings.ts       # anlam yükleyici
│   └── tiles.ts          # Türkçe harf dağılımı ve puanlar (100 taş)
├── utils/
│   ├── validator.ts    # kelime doğrulama, bölge kuralları, puanlama
│   ├── ai.ts           # YZ oyuncu mantığı
│   ├── board.ts        # tahta yardımcıları (kelime bulma, hücre key)
│   ├── boardSnapshot.ts # oyun sonu tahtasının games.board_snapshot JSON'una serileştirilmesi/geri yüklenmesi
│   ├── bag.ts          # taş torbası (buildBag, drawTiles)
│   ├── outline.ts      # bölge/bonus dış hat SVG path üretimi
│   ├── turkish.ts      # trUpper / trLower (i/İ, ı/I dönüşümü) + trCompare (Türkçe alfabetik sıralama)
│   ├── random.ts       # karıştırma
│   ├── ranking.ts      # oyun sonu sıralama (teslim olanlar en sona)
│   ├── gameRecord.ts   # buildGameRecord — bir GameState'ten games tablosuna yazılacak kaydı üretir (canlı oyun bitişi ve gecikmeli terk-edilme kaydı ortak)
│   ├── gameStorage.ts  # devam eden oyunun localStorage kalıcılığı + terk temizliği (yalnızca misafir/girişsiz kullanıcı — girişli kullanıcı sunucudaki local_game_saves'i kullanır, cihazlar arası + çoklu oyun, bkz. lib/api.ts)
│   ├── cloudSaveMirror.ts # girişli kullanıcının devam eden oyunu için offline ayna/önbellek/silme kuyruğu (write-behind) + saf karar fonksiyonları
│   ├── gameSync.ts      # bitmiş oyunlar için çevrimdışı/misafir kuyruğu
│   ├── feedbackSync.ts # geri bildirim formu için çevrimdışı kuyruk
│   ├── onboarding.ts   # ilk açılış hızlı başlangıç ipucu bayrağı
│   ├── visitTracking.ts # anonim misafir ziyaret kimliği, cihaz/standalone tespiti, UTM kaynağı
│   ├── platform.ts     # bu istemcinin platformu ('web') — telemetri, tek kaynak
│   ├── offlineNotice.ts # sunucuya ulaşılamadığında gösterilen metinler + ağ hatası tespiti (Flutter portuyla testli olarak senkron)
│   ├── shareBoardImage.ts # bir DOM düğümünü (tahta önizlemesi) paylaşılabilir PNG'ye çevirir (html-to-image)
│   ├── shareLink.ts    # ?ref=arkadas etiketli davet linki + native paylaşım/panoya kopyalama (Setup ve karşılama katmanı ORTAK — iki ayrı uygulama sessizce ayrışmasın diye)
│   ├── boardZoom.ts    # tahtanın çift dokunuşla 2× büyütülmesi: çift dokunuş dedektörü, pan sınırlama, transform matrisi (saf; portun board_zoom.dart'ıyla senkron)
│   ├── draftRescue.ts  # ıskalanan dokunuşu en yakın taslak taşa yönlendirir (npm run verify-draft-rescue)
│   ├── ghostClick.ts   # bir jestin ardından gelen "hayalet" click'i yutar (dokunmatikte compat mouse olayları O ANDAKİ DOM'a düşer) — dört çağrı yeri ortak
│   ├── errorReporting.ts # istemci hata telemetrisi (client_errors) — beklenen durumlar BİLEREK kaydedilmez, saatte 10 kayıt tavanı (zaman penceresi, süreç ömrü DEĞİL)
│   ├── friendInvite.ts # bekleyen arkadaşlık davet token'ı için tek seferlik localStorage kuyruğu
│   ├── csvExport.ts    # admin paneli tabloları/grafikleri için CSV indirme yardımcısı
│   ├── leaguePoints.ts # k-lig puanı hesaplama — (rank, count, surrendered, level); SQL league_points_for ↔ Dart ile verify-league-points kilitler
│   ├── aiLevel.ts      # YZ zorluğunun ürün yüzü: etiketler, Setup'ta seçilebilir seviyeler (Zor Faz 5'e kadar yok), null→Normal ayrıştırma
│   ├── leagueRank.ts   # k-lig rütbe kademeleri (Çaylak→Kozmik, 9 kademe: eşik/renk/ödül — sunucudaki _award_league_rewards VE portun league_rank.dart'ı ile ELLE senkron, üç kopya)
│   ├── pendingLiveGames.ts # Canlı taraftaki "bekleyen iş" sayısı (bekleyen davet + sırası sende olan oyun) — Setup rozeti ve PWA ikon rozeti ortak
│   ├── gameListOrder.ts # devam eden oyun/davet listelerinin sıralaması: "sıra bende" bitmeye en yakın ÜSTTE, "sıra rakipte" en geç ÜSTTE, son tarihi olmayan en sona (npm run verify-game-list-order; portun game_list_order.dart'ıyla senkron)
│   ├── scoreLine.ts    # kart altı puan satırı (devam eden + son oynanan kartlar): koltuk sırasıyla puanlar " - " ile — portun score_line.dart'ıyla metin birebir
│   ├── recentGameAvatars.ts # "Son Oynananlar" satırındaki rakip avatarının çözümü — eşleme OYUNLA sınırlı (donmuş players anlık görüntüsü user_id taşımadığından isimle eşleme yanlış yüz gösterebilirdi)
│   ├── headToHead.ts   # skor kartındaki kafa kafaya oran çubuğunun dilimleri — kümülatif yuvarlama, üç dilim TAM 100 eder (npm run verify-head-to-head; portun head_to_head.dart'ıyla senkron)
│   ├── rematchSlots.ts # "Tekrar Oyna" kadrosu: ilk koltuk ÇAĞIRAN, YZ'ler SONDA (create_online_game'in üç kısıtı) — oyun ekranı ve oyun geçmişi ORTAK kullanır (npm run verify-rematch-slots; portun rematchSlots'uyla senkron)
│   └── profileFields.ts # cinsiyet seçenekleri, GG/AA/YYYY ↔ ISO tarih dönüşümü (AuthModal ve AccountSettingsModal ortak)
├── legal/            # SPA dışındaki statik sayfaların üreticisi — /gizlilik/, /kullanim-kosullari/,
│                    # /hesap-silme/ (hukuki) + /nasil-oynanir/ (SEO; içeriği HelpModal'dan ithal).
│                    # Sayfa yollarının tek kaynağı scripts/static-pages.js: hem sayfa tipini
│                    # hem service worker'ın gezinme fallback muafiyet listesini besler
├── landing/
│   ├── Landing.tsx     # karşılama katmanının tamamı (derleme/dev zamanında statik HTML'e render edilip index.html'e gömülür) — SUNUCUDA render edilir, hook/olay/tarayıcı globali YOK
│   ├── LandingLogo.tsx # logoyu üç kez çizmek için SVG sprite'ı (path verisi LogoMark'tan; üç ham kopya gzip'te 10 KB yiyordu)
│   ├── OzellikIkonlari.tsx # "Neler var" bölümündeki altı özellik ikonu — Material DEĞİL, ilkel şekillerden (portun ozellik_ikonlari.dart'ıyla ELLE senkron)
│   ├── demoBoard.ts    # tanıtım tahtalarının (2 ve 4 kişilik) taşları — gerçek Board.tsx ile render edilir, npm run verify-demo-board ile sözlüğe karşı doğrulanır; ikisi de npm run generate-demo-board-dart ile porta üretilir
│   └── render.tsx      # renderToStaticMarkup sarmalayıcısı — Vite eklentisi (scripts/landing-plugin.js) Node'da çağırır
├── fonts/
│   ├── *.css              # kendi sunucumuzdan servis edilen @font-face tanımları (main.tsx import eder)
│   └── files/             # .woff2 dosyaları — mplus-rounded-1c-800-subset.woff2 ÜRETİLMİŞ
│                          # (yalnızca RankSeal'ın harfi; yeniden üretimi: CLAUDE.md → "Rütbe Rozeti Fontu")
├── hooks/
│   ├── useAuth.tsx        # Supabase auth context
│   ├── useModalA11y.ts    # modal odak hapsi, Escape, dialog yığını
│   ├── useOnlineStatus.ts # çevrimiçi/çevrimdışı durumu izler
│   ├── useNicknameAvailability.ts # takma isim uygunluğu (debounce'lu RPC kontrolü, AuthModal + AccountSettingsModal ortak)
│   ├── useAppIconBadge.ts # PWA ikonu üzerinde Badge API ile kırmızı yuvarlak/beyaz sayı rozeti
│   ├── useRankScores.tsx  # isimlerin yanındaki rütbe mührü için k-lig puanı (toplu, leaderboard view'ı)
│   └── useBoardZoom.ts    # tahta zoom'unun React tarafı (durum, tanıtım balonu kararı, sürükleme sırasında devre dışı)
└── lib/
    ├── supabase.ts        # Supabase istemcisi
    ├── api.ts             # saveGame, fetchLeaderboard, auth, fetchMeaning
    ├── pwa.ts             # PWA/service worker yardımcıları
    └── database.types.ts  # şema tipleri

.claude/                   # oturum başlangıç hook'u: npm install + Flutter SDK +
                           # pub get (Dart testleri yerelde koşabilsin)
marketing/                 # reklam/tanıtım + mağaza çıktıları — üretilmiş görsel/metin;
                           # uygulamaya girmez (node scripts/sponsored-post/build.mjs)
└── store/                 # mağaza listeleme görselleri (npm run generate-store-header)

mobile/                    # Flutter (iOS+Android) portu — ayrıntı: mobile/CLAUDE.md
├── kelimeki_core/         # oyun motorunun saf Dart portu (web motoruna eşitliği
│                          # golden vector testleriyle kanıtlı: dart run test/run_all.dart)
└── app/                   # Flutter uygulaması: Yapay Zeka'ya karşı oyun uçtan uca
    │                      # oynanabilir (kurulum/tahta/raf/sürükle-bırak, kurallar,
    │                      # kelime anlamı, hamle geçmişi), Supabase oturumu
    │                      # (giriş/kayıt/şifre sıfırlama), bulut kayıt senkronu,
    │                      # skor kartı/k-lig (rütbe mührü, ödül banner'ı),
    │                      # oyun geçmişi (tahta önizlemesi, beğeni, sohbet
    │                      # arşivi, hamle dökümü, paylaşma), Son Oynadıklarım,
    │                      # Görüş Bildir, arkadaşlık sistemi (davet linki dahil),
    │                      # Canlı (çok oyunculu) oyun: davet/kabul + gerçek
    │                      # zamanlı tahta + oyun içi mesajlaşma (sessize alma/
    │                      # raporlama dahil), ilk açılış tanıtımı (4 sayfalık
    │                      # IntroScreen — web'in karşılama katmanının porta
    │                      # taşınan hikâye kısmı), push bildirimleri (FCM —
    │                      # izin akışı Canlı sekmesindeki gerçek bağlama
    │                      # bağlı) ve kayıt onayı linkinin uygulamaya
    │                      # dönmesi (App Links). Admin paneli BİLİNÇLİ
    │                      # olarak yok.
    ├── assets/dictionary/ # üretilmiş asset'ler: words_tr.txt (kaynak
    │                      # src/data/words.ts — npm run generate-golden-vectors)
    │                      # ve meanings.db (npm run generate-meanings-db)
    ├── lib/src/ui/intro/  # ilk açılış tanıtımı; demo_board_data.dart ÜRETİLMİŞ
    │                      # (kaynak src/landing/demoBoard.ts —
    │                      # npm run generate-demo-board-dart)
    └── assets/fonts/      # Space Grotesk / Space Mono / Nunito (web'le aynı aileler)
                           # + MPLUSRounded1c-ExtraBold-subset.ttf — YALNIZCA k-lig
                           # rütbe rozetinin harfi; ÜRETİLMİŞ (alt kümelenmiş),
                           # web'in src/fonts/files/ kopyasıyla aynı subset
```

## Supabase (opsiyonel)

Çevrimiçi özellikler (kullanıcı hesapları, lider tablosu, istatistikler, kelime anlamları) Supabase ile sağlanır. Anahtarlar ayarlı değilse oyun **çevrimdışı** olarak sorunsuz çalışır.

**Şema** `supabase/migrations/` altındadır (kronolojik, artan sırada — en güncel şema için hepsi sırayla uygulanır). İlk dört migration temel şemayı kurar:

- `20260628090000_init.sql` — `profiles`, `games`, `words` tabloları; `leaderboard` & `player_stats` view'ları; RLS politikaları; auth trigger'ı; `is_valid_word` RPC.
- `20260628090100_seed_words.sql` — başlangıçtaki çekirdek kelime listesi.
- `20260628090200_add_word_meanings.sql` — `pos` ve `meanings` sütunları ile `word_meaning` RPC.
- `20260628090300_seed_dictionary.sql` — TDK Güncel Türkçe Sözlük'ten kelimeleri anlamlarıyla yükler.

Sonraki migration'lar `player_stats`/`leaderboard` view'larını, oyun istatistiklerini (en uzun kelime, en iyi hamle, sıralama/`total_score` lig puanı, teslim olma cezası vb.) ve sözlük düzeltmelerini kademeli olarak ekler — güncel listeyi görmek için klasöre bakın.

**Migration'ları uygulama:**

```bash
supabase link --project-ref xvqlizifakkkoqahaxsg
supabase db push
```

> Bu depoda CI ile otomatik migration akışı yok; production'a uygulama şu an Claude Code oturumları tarafından Supabase MCP (`apply_migration`) ile elle yapılıyor — detay ve senkron kuralları için `CLAUDE.md`'ye bakın.

**İstemci yapılandırması** — `.env.example` dosyasını `.env` olarak kopyalayıp doldurun:

```bash
VITE_SUPABASE_URL=https://xvqlizifakkkoqahaxsg.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_...   # Project Settings → API
```

**Edge Functions** (`supabase/functions/`) — Supabase MCP (`deploy_edge_function`) ile deploy edilir, `supabase functions deploy` CLI akışı kullanılmaz. Şu anki fonksiyonlar:

- `_shared/email.ts` — gerçek bir fonksiyon değil, Brevo'yla e-posta gönderen tüm fonksiyonların paylaştığı ortak kod (Brevo çağrısı, HTML escape, iki gönderen sabiti ve iki alt not metni). Her deploy çağrısında ilgili fonksiyonun `files` listesine ayrıca eklenir (Supabase her fonksiyonu kendi bağımsız paket olarak dağıttığından).
- `_shared/push.ts` — yine gerçek bir fonksiyon değil: FCM HTTP v1 ile mobil uygulamaya push bildirimi gönderen ortak kod (servis hesabı → RS256 JWT → OAuth2 token → gönderim; token önbellekli). `FCM_SERVICE_ACCOUNT` secret'ı tanımlı değilse tüm yüzey sessizce kapalı kalır. Hiçbir genel fonksiyonu FIRLATMAZ — push, e-postanın yanında **ikincil** bir kanal ve onu düşürmesi kabul edilemez. Google `UNREGISTERED`/`INVALID_ARGUMENT` dönerse çağıran, ölü token'ı `push_tokens`tan siler.
- `feedback-reply/` — admin panelinden bir görüş bildirimine yanıt gönderildiğinde çağrılır; Brevo'nun Transactional Email API'siyle (SMTP değil, ayrı bir `BREVO_API_KEY` Edge Function secret'ı ile) yanıtı gönderenin e-postasına iletir ve `feedback.reply`/`replied_at`/`replied_by` alanlarını günceller.
- `admin-send-message/` — admin panelinin Üyeler tablosundan bir üyeye elle yazılan serbest metinli mesajı (konu + gövde) aynı Brevo API'siyle gönderir; bir feedback kaydına bağlı olmadığından DB'ye bir şey yazmaz.
- `play-ai-turn/` — Canlı (online) bir oyunda sırası gelen YZ koltuğunun turunu tamamen sunucuda oynar; YZ'nin gerçek rafı bu sayede hiçbir zaman tarayıcıya gönderilmez (bkz. `CLAUDE.md`, "Canlı Oyun — Faz 3"). `_game/` altındaki `ai.ts`/`validator.ts`/`board.ts`/`constants.ts`/`types.ts`/`turkish.ts`/`tiles.ts`/`wordSet.ts` kopyalarını kullanır — `src/`'deki kaynaklar değişirse elle senkronize edilmeli.
- `notify-friend-request/` / `notify-game-invite/` — bir arkadaşlık isteği ya da Canlı oyun daveti oluşturulduğunda alıcıya işlemsel (marketing_consent'e bağlı olmayan) bir e-posta bildirimi gönderir; aynı Brevo API'sini kullanır. Best-effort/fire-and-forget çağrılır (`src/lib/api.ts`), bir e-posta hatası isteğin/davetin kendisini etkilemez. Detay için `CLAUDE.md`'deki "İşlemsel e-posta bildirimleri" bölümüne bakın.
- `notify-deadline-warnings/` — Canlı oyunda sırası gelen oyuncuya (48 saatlik `turn_deadline`) ve YZ'ye karşı devam eden oyunlara (7 günlük terk-edilme penceresi) süre 24 saatten az kalınca hatırlatma gönderir. E-postanın YANINDA (yerine değil) mobil uygulamaya push bildirimi de atar — alıcının `profiles.push_notifications_enabled` tercihi ve `push_tokens` satırları varsa. Projenin ilk `pg_cron` + `pg_net` job'u — kullanıcı etkileşimine bağlı diğer "hafif" desenlerin aksine (`check_turn_timeout` gibi) 15 dakikada bir kendiliğinden tetiklenir, `verify_jwt: false`.
- `notify-friend-request-reminders/` — 3 gün cevapsız kalan arkadaşlık isteklerine tek seferlik bir hatırlatma e-postası gönderir. İkinci `pg_cron` job'u, günde bir kez (08:00 UTC) tetiklenir. Detay için `CLAUDE.md`'deki "Arkadaşlık isteği hatırlatma e-postası" bölümüne bakın.
- `notify-turn-timeout-surrender/` — bir Canlı oyunda sırası gelen oyuncu 48 saat içinde hamle yapmayıp otomatik teslim olduğunda (ve bu, oyunun gerçekten bittiği ana denk geldiğinde) ilgili oyunculara -2 k-lig cezasını bildirir. `check_turn_timeout` RPC'sinden `net.http_post` ile SQL içinden tetiklenir, `verify_jwt: false`.
- `notify-local-game-abandoned/` — Yapay Zeka'ya karşı 7 gün boyunca hiç hamle yapılmayıp terk edilmiş sayılan bir yerel oyunun -2 k-lig cezasını hesap sahibine bildirir; `saveGame` gerçek bir `surrendered:true` kaydı eklediğinde tetiklenir.
- `notify-account-banned/` / `notify-account-unbanned/` — admin bir hesabı dondurduğunda/dondurmayı kaldırdığında ilgili kullanıcıya bildirim gönderir.
- `notify-welcome/` — e-posta adresini doğrulayan yeni üyeye hoş geldiniz e-postası gönderir; `verify_jwt: false` (Postgres tarafından tetikleniyor).
- `sweep-unconfirmed-accounts/` — 20. saatte tek seferlik hatırlatma gönderir, 48. saatte hâlâ doğrulanmamış hesabı siler (üçüncü `pg_cron` job'u, saatlik, `verify_jwt: false`). Kural: kimse uyarılmadan silinmez.
- `delete-my-account/` — kullanıcının KENDİ hesabını uygulama içinden silmesi (Apple 5.1.1(v) + Play'in veri silme şartı). Kimliği çağıranın kendi JWT'siyle doğrular, sonra service-role ile `delete_account_cascade` RPC'sini çağırır, `avatars` kovasındaki dosyaları siler ve `auth.admin.deleteUser` ile hesabı kapatır. `dryRun` bayrağıyla hiçbir şey silmeden sayan bir KURU ÇALIŞTIRMA modu var — onay penceresi bunu gösteriyor. Kaskadın tamamı ve kararları: `docs/decisions/account-deletion.md`.
- `inbound-email/` — `destek@kelimeki.com` kutusuna gelen cevapların HABERİNİ `support_inbox` tablosuna yazar (admin panelindeki "Zoho" rozetinin sayacı). Brevo Inbound Parsing webhook'u tarafından çağrılır, `verify_jwt: false` — tek koruma `?key=` parametresindeki `INBOUND_EMAIL_SECRET`; sır tanımsızsa fonksiyon 503 ile kapalı kalır. **Mail gövdesi saklanmaz**, mailin asıl yeri Zoho kutusudur.

Altı işlemsel bildirim türü (`notify-friend-request`, `notify-friend-request-reminders`, `notify-game-invite`, `notify-deadline-warnings`, `notify-turn-timeout-surrender`, `notify-local-game-abandoned`) alıcının `profiles.email_notifications_enabled` tercihine (varsayılan açık, Hesap Ayarları'ndan kapatılabilir) bağlıdır — kapalıysa gönderim sessizce atlanır. Hesap güvenliği/admin yazışması niteliğindeki diğer fonksiyonlar (`notify-account-banned`/`notify-account-unbanned`, `feedback-reply`, `admin-send-message`) bu tercihe bakmadan her zaman gönderilir.

E-posta gönderen fonksiyonlar **iki gönderenden birini** kullanır (25 Ağustos 2026 kararı, ayrıntı: `docs/decisions/support-email.md`):

- **`noreply@kelimeki.com`** — yukarıdaki tüm `notify-*`/`sweep-*` bildirimleri ve Supabase Auth şablonları. Bu adres gerçekten cevaplanamaz (Zoho'da karşılığı olan bir kutu/grup yok, yazılan mail geri döner), bu yüzden maillerin altında "bu adrese gönderilen yanıtlar okunmaz, bize destek@kelimeki.com adresinden ulaş" notu vardır.
- **`destek@kelimeki.com`** — `feedback-reply` ve `admin-send-message`, yani bir insanın yazdığı mailler. Gerçek bir Zoho posta kutusu: kullanıcı "Yanıtla" derse cevap oraya düşer. `sendBrevoEmail`'in `sender` parametresi verilmezse noreply@ kullanılır, yani destek gönderenini açıkça geçmek gerekir.

Kullanıcının doğrudan yanıtı **admin panelinde okunmaz** — mailin asıl yeri Zoho kutusudur. Panel yalnızca haber verir: Geri Bildirim sekmesinin alt sekme satırındaki küçük "Zoho" düğmesi, üstünde kırmızı sayılı rozet, tıklanınca sayaç sıfırlanıp Zoho gelen kutusu açılır (sayacı `inbound-email` → `support_inbox` besler). İkinci bir yol olarak destek maillerinin altındaki "siteden de yazabilirsin" linki `kelimeki.com/?contact=1&re=<id>`'e gider; `App.tsx`'teki bir effect bu parametreleri okuyup genel "Görüş Bildir" formunu (`FeedbackModal`, `source="general"`) otomatik açar ve yeni mesajı `feedback.related_to` ile önceki mesaja bağlar — bu yol Zoho'ya DEĞİL doğrudan admin paneline düşer. `admin-send-message` kendi gönderdiği mesajı da `feedback`'e (`origin: 'admin'`) yazar, böylece "kime ne yazıldığı" panelde kalıcı olarak görünür.

## Sözlük Verisi

Kelimeler ve anlamları **TDK Güncel Türkçe Sözlük (12. baskı)** kaynaklıdır;
[ogun/guncel-turkce-sozluk](https://github.com/ogun/guncel-turkce-sozluk) (MIT lisansı) üzerinden alınmıştır. Ham dökümdeki çok sözcüklü maddeler birleştirilir ("dulavrat otu" → "dulavratotu"); ardından yalnızca Türk alfabesi harfleri içeren 2–25 harfli tokenlar tutularak süzülür. Çok sözcüklü atasözü/deyim/özel isim gibi oynanamayacak maddeler sonradan ayrıca temizlenmiştir (bkz. `supabase/migrations/2026071913*_remove_*`), bu yüzden güncel liste ilk süzülen haliyle aynı değildir — **~63 bin oynanabilir kelime**. TDK'de eksik olan başlıca dünya ülkesi/başkent/dil adları `scripts/proper-nouns.mjs`, GTS'te hiç geçmeyen diğer oynanabilir sözcükler `scripts/extra-words.mjs`, var olan bir kelimeye eklenen günlük dildeki anlamlar ise `scripts/extra-meanings.mjs` ile tamamlanır — üçü de `npm run augment-dictionary` ile 100 MB'lık GTS kaynağı indirilmeden uygulanabilir.

Üretilen dosyaları yeniden oluşturmak için:

```bash
# 1) Kaynağı indir ve aç
curl -sSL -o gts.json.tar.gz \
  https://raw.githubusercontent.com/ogun/guncel-turkce-sozluk/master/sozluk/v12/v12.gts.json.tar.gz
tar xzf gts.json.tar.gz

# 2) Veri dosyalarını üret
GTS_JSON=./gts.json npm run build:dict
```

## Dağıtım

Depo Vercel'e bağlanıp doğrudan dağıtılabilir; `vercel.json` Vite ön ayarlarını içerir. Main branch'e merge otomatik deploy tetikler.

---

İyi oyunlar!
