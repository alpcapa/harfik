# Canlı Oyun (Faz 2 → 3.6) — Karar Kaydı

> **Bölünme notu (25 Ağustos 2026):** Bu dosya, `docs/decisions/live-game-and-friends.md`nin
> üç parçaya ayrılmış hâlinin biri. Ayrım `npm run check-doc-size`in uyarı bandına
> girilmesiyle zorunlu oldu (156 KB / 200 KB — kural: *"uyarı bandındaki dosyayı bir
> sonraki dokunuşunda böl"*, bkz. kök `CLAUDE.md`). İçerik SATIR SATIR AYNI, yalnızca
> yer değiştirdi. Kardeş dosyalar: `friends.md` (arkadaşlık sistemi),
> `live-game.md` (Canlı oyun Faz 2-3.6, sunucu tarafı), `online-game-screen.md`
> (`OnlineGameScreen.tsx` — canlı oyun ekranının UI kararları).


## Rozet oyundan DÖNÜŞTE tazelenmiyordu — web'in bedava aldığı garanti (28 Ağustos 2026)

Bir gün sonra AYNI rozet, BAŞKA bir kancadan yine bayat kaldı. Kullanıcı
bildirdi: *"Hiç bekleyen oyunum kalmamış olmasına rağmen tab'da 1 uzun süre
durdu. Sonra ekran kapandı, açınca gitti."* Son cümle teşhisin kendisi —
ekranı kapatıp açmak `AppLifecycleState.resumed` demek, yani rozeti
düzelten şey zaten var olan bir kancaydı; eksik olan **dönüş anı**ydı.

**Kök sebep bu kez unutulmuş bir kanca değil, bir YAPI farkı:**

| | Web (`App.tsx`) | Port (`setup_screen.dart`) |
|---|---|---|
| Canlı tahta açılınca Setup | **unmount** (erken `return <OnlineGameScreen…>`, satır 1190) | **mount'ta KALIR** (`MaterialApp.home` + `Navigator.push`) |
| Dönüşte rozet | remount → effect baştan koşar → **bedava tazelenir** | hiçbir şey koşmaz |

Yani web bu garantiyi tasarımından ötürü alıyor; port onu kaybetmişti ve
kimse fark etmemişti çünkü Realtime olayı çoğu zaman yetişiyordu. Olay
kaçınca (zayıf bağlantı, kanal kopması) geri getiren hiçbir şey kalmıyordu.

**Liste bu garantiyi baştan beri taşıyordu.** `live_games_tab._openGame`
dönüşte `_reload()` çağırıyor, yorumu da niyeti açıkça yazıyor: *"Realtime
da tetikler ama dönüş anı garanti."* Rozet o satırın hemen yanında eksikti —
27 Ağustos'takiyle aynı çelişki (kapsayan rozet ↔ kapsanan liste), farklı
kancadan. Düzeltme yeni bir mekanizma değil: `LiveGamesTab.onGameClosed` →
`SetupScreen._scheduleLiveBadgeRefresh`.

⚠ **Sürüm B için kod yorumuna yazıldı:** Canlı tahtayı açan İKİNCİ bir kapı
(bildirime dokununca doğru oyunu aç) eklenince o kapı da bunu çağırmalı.
İki kapı olduğunda doğru çare callback değil, Setup'a takılacak bir
`RouteObserver` (`didPopNext`) — tek kapı varken onu kurmak erken soyutlama
olurdu.

**Bu, kaçırılan olayın kalıcı kayba dönüştüğü BEŞİNCİ yer.** Aynı soru
yine geçerli: *"olay kaçarsa ne olur ve onu kim geri getirir?"* — ama bu
vaka ikinci bir soru daha ekliyor: **"web bu garantiyi nereden alıyor?"**
Web'in mimarisinden bedavaya gelen bir davranış, portta ELLE kurulmak
zorunda; parite denetimi yalnızca kancaları değil, kancaların gerekliliğini
DOĞURAN yapı farklarını da karşılaştırmalı.

**Test tuzakları (ikisi de ölçüldü):** `find.byType` varsayılan olarak sahne
dışını atlar — push edilmiş rotanın altındaki Setup'ı görmek için
`skipOffstage: false` şart, ki hatanın kaynağı zaten "sahne dışında ama
MOUNT" durumu. Ve `tester.pageBack()` bir AppBar geri butonu arıyor; Canlı
tahtanın kendi çıkış düzeni olduğundan rota doğrudan pop ediliyor.

## "Arkadaşınla" rozeti bayat kaldı: kaçırılan olay, geri getirilemedi (27 Ağustos 2026)

Kullanıcı bildirdi: zayıf bağlantıda (havuz başı) bekleyen 8 oyunu oynadı,
**rozet 8'de takılı kaldı** — oysa listedeki her satır "Rakibin hamlesi
bekleniyor" diyordu. Rozet ile liste birbiriyle ÇELİŞİYORDU. Bir süre sonra
kendiliğinden düzeldi; kullanıcının tahmini ("bağlantıdan olabilir mi?")
doğruydu, ama kusur bizdeydi.

**Ölçülen asimetri** — liste kendini toparlıyor, rozet toparlamıyordu:

| Tazeleme kancası | Liste (`live_games_tab`) | Rozet (`setup_screen`) |
|---|---|---|
| Açılış | ✅ | ✅ |
| Realtime olayı | ✅ | ✅ |
| Öne dönüş | ✅ | ✅ |
| **Kanal kopup yeniden bağlanınca** (`onResubscribe`) | ✅ | ❌ |
| **Bağlantı geri gelince** (`onlineStatus`) | ✅ | ❌ |

Kanal koptuğunda kendi hamlelerinin yayınladığı olaylar kayboluyor;
`pendingCounts()` de ağ hatasında `null` döndüğünden (bilinçli — son bilinen
rozet korunur) sayı bayat kalıyordu. **Web'de `Setup.tsx` bunun için
`window.addEventListener('online', …)` kuruyor** — yani portta bu bir
PARİTE KIRILMASIYDI, yeni bir tasarım sorusu değil.

Rozet artık her iki kancayı da taşıyor.

**Bu, kaçırılan olayın kalıcı kayba dönüştüğü DÖRDÜNCÜ yer** (sohbet
Realtime'ı, bulut senkronu, `useOnlineStatus` aynı çareyi almıştı). Olay
tabanlı yeni bir durum eklerken ilk soru: *"olay kaçarsa ne olur ve onu
kim geri getirir?"*

**Test yazarken iki tuzak ölçüldü** (ikisi de testi SESSİZCE yanlış yere
baktırıyordu):

1. `FakeOnlineGamesGateway` yalnızca SON aboneyi tutuyordu. Sekme açıkken
   hem rozet hem liste abone; `lastOnResubscribe` listeninkini gösteriyordu,
   yani test listeyi tetikleyip rozetten sonuç bekliyordu. Harness artık
   tüm aboneleri tutuyor (`fireAllOnResubscribe`).
2. `find.ancestor(...).first` — rozet YOKKEN zincirin ucu boşalıyor ve
   `findsNothing` eşleştiricisi mismatch'i tarif ederken patlıyor ("No
   results have been found yet"), yani hata mesajı testin gerçek sonucunu
   gizliyor. `.first` kaldırıldı.

Testin kendisi "araç canlı mı" kontrolüyle başlıyor: olay gelmeden rozetin
BAYAT kaldığı önce ölçülüyor — o satır düşerse sonraki iddialar boşuna
geçerdi.

## Koltuk indeksi çöktü: RPC slotu ÇOĞALTIYORDU (27 Ağustos 2026)

Bir kullanıcı bildirdi: 4 kişilik Canlı oyunda **kendi yeşil köşesine taş
koyamıyor** ("İlk kelimen kendi köşe karesine değmeli"), **mor (YZ) köşesine**
koyunca "Kelime geçerli" diyor ama **OYNA pasif** kalıyor.

**Kök sebep — ölçüldü, tahmin edilmedi.** `list_my_online_games` slot dizisini
üç `LEFT JOIN` ile kurup `jsonb_agg` yapıyordu. `friend_requests` bir slot
için İKİ satır eşlediğinde o slot diziye **iki kez** giriyor ve sonraki tüm
indeksler kayıyor. Canlı veride ölçülen:

| | Değer |
|---|---|
| `og.slots` (ham) | `[Ironman, Cem, Fb1907, ai]` — 4 |
| RPC'nin döndürdüğü | `[Ironman, Cem, **Cem**, Fb1907, ai]` — **5** |
| `slots.indexWhere(ben)` | **3** (olması gereken 2) |

İstemci koltuk indeksini POZİSYONEL okuyor (`indexWhere`), yani 3. koltuğun
rafını, rengini ve köşesini kullandı. **Sunucu (`submit_move`) ham
`og.slots`'u okuduğundan doğru koltuğu biliyordu** — OYNA'nın pasif kalması
bu yüzden davranışın DOĞRU yarısıydı; yanlış olan istemcinin gösterdiği her
şeydi.

**İki satır neden var — bu bir hata DEĞİL:** `handle_friend_request_insert`
tetikleyicisi, iki kişi birbirine istek gönderdiğinde ikisini de `accepted`
yapıyor (karşılıklı istek = otomatik arkadaşlık). Yani karşılıklı çift
MEŞRU bir durum ve tekrar edecek. O gün 27 kabul satırından yalnızca 1'i
karşılıklıydı — bu yüzden bugüne kadar görünmemişti; nadirdi, imkânsız
değil.

**Düzeltme** (`20260827121628_fix_slot_duplication_in_list_my_online_games`):
join YOK, her alan skaler alt sorgudan geliyor — slot başına tam bir satır
üretilmesi artık YAPISAL garanti. Yan kazanç: `relation` deterministik oldu
(eskiden karşılıklı çiftte hangi satırın join'e düştüğü belirsizdi ve
`pending_outgoing`/`pending_incoming` arasında salınabiliyordu).

**Aynı kökten ikinci belirti:** `list_friends`'te `distinct` yoktu —
karşılıklı çift arkadaşı listede İKİ KEZ gösteriyordu (ölçüldü: 4 satır,
3 farklı kişi). `distinct on` eklendi; doğrulandı: 3/3.

**Nöbetçi:** hata SESSİZDİ — hiçbir yerde iz bırakmadı, teşhis elle SQL
koşularak yapıldı. İki istemci de artık `slots.length != playerCount`
olduğunda telemetriye yazıyor (`online_game.slot_count_mismatch`). Bu
düzeltmeyi tekrarlamaz, ama tekrarını GÖRÜNÜR kılar.

**Cihazda doğrulandı** (27 Ağustos 2026): kullanıcı oyunu yeniden açtı,
kendi yeşil köşesine oynayabildi. Sunucu düzeltmesi olduğundan yeni bir
sürüm gerekmedi — ama koltuk indeksi oyun ekranı açılırken BİR KEZ
hesaplandığından, düzeltme anında elinde bozuk liste bulunan istemcinin
listeyi yeniden yüklemesi (uygulamayı kapatıp açması) gerekti.

**Ders (bu dosyanın dışında da geçerli):** bir jsonb dizisini
`jsonb_agg` + `LEFT JOIN` ile yeniden kurmak, join'in tekilliği garanti
edilmedikçe diziyi sessizce ÇOĞALTIR. Sıra/indeks anlam taşıyan bir dizide
bu, veriyi bozmakla eşdeğerdir. Böyle bir yerde join yerine skaler alt
sorgu kullan.


## Canlı Oyun — Faz 2 (Davet + Kabul Akışı)

27 Temmuz 2026'da eklendi. Faz 1'in (artık `friends.md`) üzerine kurulu — arkadaşlık ilişkisi olmadan kimseyi davet edemezsin. Bu fazda hâlâ gerçek zamanlı senkron oynanış YOK: yalnızca "kimin katılacağı" belirleniyor, oyun kabul edilenlerin hepsi tamamlanınca `active` durumuna geçiyor ama tahta/raf/skor state'i henüz hiçbir yerde yok (Faz 3'ün işi).

### Veri modeli

- **`online_games`** — bir Canlı oyun kurulumu: `created_by`, `player_count` (2|4), `status` (`pending|active|finished|abandoned`), `slots` (jsonb dizi — `{"type":"human","user_id":uuid}` ya da `{"type":"ai"}`, index 0 her zaman kurucu). Hiç insan davetlisi yoksa (teoride mümkün değil, bkz. aşağıdaki kural) oyun beklemeden `active` olurdu.
- **`game_invites`** — her insan koltuğu (kurucu hariç) için ayrı bir davet satırı: `online_game_id`, `invitee_id`, `status` (`pending|accepted|declined`). `friend_requests`'teki istek/kabul deseniyle tutarlı RLS (yalnızca kurucu ya da davetli kendi satırlarını görebilir/yanıtlayabilir).
- Her ikisinin de RLS'i `friends_system` migration'ındaki desenle aynı — bkz. `20260727105825_online_games_invites.sql`.

### RPC'ler (hepsi `security definer`, yalnızca `authenticated`'e `grant`)

- **`create_online_game(p_player_count, p_slots)`** — yeni oyunu kurar, insan koltukları için `game_invites` satırlarını açar. Doğrulamalar: ilk koltuk her zaman çağıranın kendisi olmalı, insan koltukları zaten arkadaş olunan kişiler olmalı (aksi halde reddedilir), ve **kompozisyon kuralı**: 2 kişilikte her iki koltuk da insan olmak zorunda (YZ'ye hiç izin yok), 4 kişilikte yalnızca 4. koltuk (index 3) YZ olabilir, 2. ve 3. koltuklar her zaman insan olmalı. Bu kural bir Canlı oyunun en az bir/iki gerçek arkadaş katılımı garanti etmesi için — istemci UI'ı (`LiveGameCreateForm.tsx`) zaten bunu uyguluyor, RPC aynısını sunucu tarafında da zorluyor (`20260727122207_online_game_ai_slot_rule.sql`, ilk migration'dan ayrı bir sonraki adımda eklendi).
- **`list_my_online_games()`** — çağıranın taraf olduğu (kurduğu ya da davet edildiği) tüm oyunları döner; `my_role` (`creator|invitee`), `my_invite_status`, `my_invite_id` (Kabul/Reddet için gereken `game_invites.id`) taşır. `slots` sunucu tarafında zenginleştirilir — her insan koltuğuna `name`/`avatar_url` (`profiles`'tan, RLS'i kilitli olduğundan `leaderboard`/`game_likers` ile aynı gerekçeyle security definer gerekiyor), `relation` (`search_users_for_friend`'daki aynı sözlük + çağıranın kendi koltuğu için `'self'`) ve `invite_status` (o koltuktaki kişinin KENDİ `game_invites` durumu — kurucunun koltuğunda hiç davet satırı olmadığından her zaman `null`, istemci bunu `created_by` ile karşılaştırıp "Davet gönderen" olarak gösterir) eklenir. Dönüş tablosu iki kez değişti (önce `my_invite_id`, sonra `relation`/`invite_status` zenginleştirmesi) — ikisi de henüz production'a uygulanmamışken tek migration'da birleştirildi (`20260727132239_list_my_online_games_invite_id_and_names.sql`) çünkü Postgres'te dönüş sütunları değişince `create or replace` yetmiyor, `drop function` + yeniden `create` gerekiyor.
- **`respond_to_game_invite(p_invite_id, p_accept)`** — bir daveti kabul/red eder. Kabul edilince o oyundaki TÜM davetler artık `accepted` ise `online_games.status` `active`'e geçer.
  **Ret oyunu ANINDA sonlandırır (3 Ağustos 2026, `decline_game_invite_abandons_game` migration'ı, kullanıcı bildirdi):** Öncesinde ret dalı yalnızca `game_invites.status`'u `'declined'` yapıp `online_games`'e HİÇ dokunmuyordu (fonksiyonda `if p_accept then …` vardı ama `else` yoktu). Oyun `pending` kalıyor, daveti GÖNDEREN kişinin "Bekleyen Oyunlar" listesinde (`my_role='creator' && status='pending'` kovası) `check_invite_expiry`'nin 7 günlük süpürmesine kadar duruyordu. O 7 günlük pencere YANITLANMAMIŞ davet için var — sonucun gerçekten bilinmediği durum; ret ise kesin bir cevap ve kompozisyon kuralı gereği geri dönüşsüz (2 kişilikte iki koltuk da, 4 kişilikte 2. ve 3. koltuklar zorunlu insan olduğundan tek ret kadroyu asla tamamlanamaz kılar), yani oyun çoktan ölüyken "yanıt bekleniyor" gibi görünüyordu. Ret dalı artık oyunu doğrudan `'abandoned'`a çekiyor — `check_invite_expiry`'nin zaten kullandığı aynı son durum, listenin üç kovası da yalnızca `pending`/`active` eşlediğinden oyun anında her yerden kayboluyor. Satır SİLİNMİYOR: `game_invites`'teki `'declined'` satırıyla birlikte oyunun neden bittiğinin kaydını taşıyor. Production'da geri alınan transaction'lar içinde gerçek RPC gerçek davetli kimliğiyle çağrılarak doğrulandı — ret → oyun `abandoned` + davet `declined`/`responded_at` dolu; kabul (regresyon kontrolü) → oyun `active` + tahta/torba kuruldu.

### UI akışı

- **`Setup.tsx`'e "Oyun Tipi" seçici eklendi** — "Oyuncu Sayısı" bölümünün hemen üstünde, aynı görsel dilde iki sekme: **Yapay Zeka ile** (mevcut yerel/anında akış, hiç değişmedi) / **Arkadaşınla** (bu fazın tüm UI'ı). Seçim App.tsx'te tutulur (`mainView` state, `'local'|'live'`), Setup'a controlled prop olarak geçilir — bilinçli olarak Setup'ın kendi 2/4 kişilik seçicisinin İÇİNE üçüncü bir seçenek olarak eklenmedi, çünkü yerel oyun anında başlar, Canlı oyun davet kabul edilene kadar bekler — bu iki eylem çok farklı sonuçlar üretir (biri tahtayı hemen açar, diğeri hiçbir yere gitmeden "davet gönderildi" der), aynı butonun arkasına gizlenmemeli.
- **`LiveGamesTab.tsx`** ("Arkadaşınla" seçiliyken gösterilir) — `list_my_online_games()`'i çeker, dört bölümde gösterir: **Davet Bekliyor** (çağıran davetli, `my_invite_status='pending'`), **Aktif Oyunlar** (`status='active'` — Faz 3'ten beri gerçekten oynanabilir, satıra dokununca `OnlineGameScreen` açılır, bkz. aşağıdaki Faz 3 bölümü), **Kabul Ettin — Diğerleri Bekleniyor** (çağıran davetli VE zaten `my_invite_status='accepted'`, ama oyun genel olarak hâlâ `status='pending'` — 4 kişilik bir oyunda diğer davetliler henüz yanıtlamadıysa), **Rakip Bekleniyor** (çağıran kurucu, `status='pending'`). "+ Yeni Canlı Oyun" butonu `LiveGameCreateForm`'a geçer.
  **Bulunan hata (28 Temmuz 2026, gerçek hesapla test edilirken):** "Kabul Ettin — Diğerleri Bekleniyor" bölümü eklenene kadar bu durum (davetli, kabul etmiş, oyun hâlâ pending) hiçbir filtreye düşmüyordu — `invites` yalnızca hâlâ `pending` olan davetleri, `active` yalnızca `status='active'`'i, `waiting` yalnızca kurucuyu kapsıyordu. Sonuç: bir davetli daveti kabul ettiğinde (4 kişilikte diğerleri henüz yanıtlamamışsa) oyun listeden tamamen kayboluyordu — ne "Aktif" altında görünüyordu ne başka bir yerde, kullanıcıya "kabul ettim ama hiçbir şey olmadı" izlenimi veriyordu.
  - **Davet satırları** — her katılımcıyı (yalnızca daveti göndereni değil) avatar+isimle listeler, karşılarında **"Davet gönderen" / "Kabul etti" / "Reddetti" / "Bekliyor"** etiketi (çağıranın kendi koltuğu dahil — orada da gerçek adı + "Bekliyor" gösterilir, "Sen" gibi özel bir etiket YOK, ilk denemede vardı ama kafa karıştırdığı için kaldırıldı). Kabul Et/Reddet butonları `respond_to_game_invite`'ı çağırır.
    **Etiketin rengi (30 Ağustos 2026, kullanıcı isteği):** "Kabul etti"
    **yeşil**, "Bekliyor" **kırmızı**; "Reddetti" ve "Davet gönderen"
    bilinçli olarak nötr kaldı — buradaki kırmızı "hâlâ cevap bekleniyor"
    uyarısı, "olumsuz sonuç" değil, ikisini aynı renge boyamak o ayrımı
    silerdi. Renk kararı etiketle AYNI yerde ve aynı dal sırasında duruyor
    (`participantLabelClass`, `LiveGamesTab.tsx` ↔ `_participantLabelColor`,
    portun `live_games_tab.dart`'ı) — etiket değişirse rengi de aynı elden
    değişsin diye.
    Kullanıcı ayrıca sordu: *"biri reddedince davet düşüyor mu, göstermeye
    devam mı ediyor?"* — **düşüyor, ÖLÇÜLDÜ:** canlı
    `respond_to_game_invite`in ret dalı oyunu `abandoned` yapıyor
    (`20260803132047_decline_game_invite_abandons_game`, `pg_get_functiondef`
    ile canlıdan doğrulandı) ve yukarıdaki dört kova yalnızca
    `pending`/`active` eşliyor; canlıda 86 davetin 2'si reddedilmiş, ikisi de
    görünmez oyunlarda (`declined` + `status in ('pending','active')` = **0
    satır**). Yani "Bekliyor"u turuncuya çekip kırmızıyı "Reddetti"ye
    ayırmanın bir karşılığı olmazdı — kırmızı bekleyende kaldı. Port tarafında testli (`live_games_test.dart`, widget'ın
    çizdiği `Text`in gerçek rengini okuyor; negatif eş doğrulandı).
  - **İlk tasarım denemesi** (relation tabanlı satır-içi +/✓ göstergesi — her katılımcının yanında arkadaş ekle/zaten arkadaşsın ikonu) kullanıcı geri bildirimiyle kaldırıldı: "kim arkadaşım" ile "kim bu oyunda ne durumda" bilgilerini aynı satırda karıştırıp kafa karıştırıyordu. Arkadaş ekleme ayrı bir adıma taşındı (aşağıya bkz.).
  - **"Kabul Ettin — Diğerleri Bekleniyor"/"Rakip Bekleniyor" da davet kartıyla aynı detayı gösterir** (28 Temmuz 2026, PR #165) — ilk sürümde bu iki bölüm de `Aktif` gibi tek satırlık bir `GameRow` (başlık + "Rakip bekleniyor" rozeti) kullanıyordu; 4 kişilik bir oyunda bunun tek başına yetersiz olduğu fark edildi (kullanıcı geri bildirimi: "kiminle oynayacaksın" sorusunun cevabı, kabul ettikten SONRA da görünmeli, sadece davet anında değil). Davet kartındaki katılımcı listesi ortak `PendingGameCard` bileşenine çıkarıldı — hem davet satırlarında (Kabul/Reddet butonlarıyla) hem bu iki bölümde (butonsuz, yalnızca `${player_count} Kişilik Canlı Oyun` başlığıyla) aynı "Kiminle Oynayacaksın" listesini render eder, böylece kim kabul etti/kim hâlâ bekliyor her zaman görünür kalır.
- **`LiveGameCreateForm.tsx`** — Oyuncu Sayısı (2/4) + arkadaş seçici + "Davet Gönder". Kural `create_online_game`'in sunucu tarafı kısıtıyla birebir eşleşir:
  - **2 kişilik** — tekli seçim (radio gibi davranır), YZ seçeneği hiç yok, tam 1 arkadaş seçilmeden buton pasif.
  - **4 kişilik** — çoklu seçim, minimum 2 / maksimum 3. **2 arkadaş seçiliyken buton aktif** ama tıklanınca önce bir onay sorulur: *"4. koltuk Yapay Zeka ile doldurulacak, tamam mı?"* — Evet denirse gönderilir; **Hayır** denirse popup kapanır ve listede kalıcı bir **"🤖 Yapay Zeka"** satırı belirir (normal bir arkadaş gibi checkbox'lı) — bir daha popup çıkmaz, kullanıcı istediği zaman bu satırı işaretleyip/kaldırıp YZ'yi devreye sokabilir. 3 arkadaş seçilirse (tam insan kadrosu) popup hiç devreye girmez.
  - Arkadaş listesi boşsa düz metin yerine tıklanabilir tek satır: *"Henüz hiç arkadaşın yok. **Arkadaş eklemek ve davet etmek için tıkla.**"* — tıklanınca `FriendsModal` doğrudan "Ara & Ekle" sekmesiyle açılır, kapanınca liste yenilenir.
  - **Gönderim onay ekranı (3 Ağustos 2026, kullanıcı isteği):** Öncesinde `createOnlineGame` başarılı olunca form sessizce kapanıp listeye dönüyordu — kullanıcı davetin gerçekten gidip gitmediğini anlayamadığını bildirdi. Artık form yerini *"Davetiniz gönderilmiştir."* ekranına bırakıyor (kime gittiğini de yazar; YZ koltuğu varsa "4. koltuk Yapay Zeka." notu eklenir), `onCreated` yalnızca "Tamam"a basılınca çağrılıyor. Desen `FriendSuggestModal`'ın *"Arkadaşlık davetiniz iletilmiştir."* ve `ChatSettingsModal`'ın `report-sent` ekranlarıyla aynı. İsimler gönderim anında dondurulur (`sentTo`) — listeye dönülene kadar `selected`/`friends` değişebilir.
  - **Bulunan hata (5 Ağustos 2026) — arkadaş listesi hesap değişimini atlatıyordu:** Kullanıcı, T1'den T2'ye geçip "+ Yeni Canlı Oyun"a basınca listede `Ironman` ve **`T2`**'yi (yani KENDİSİNİ) gördüğünü, başka bir sekmeye gidip dönünce `Ironman, T1`'e düzeldiğini bildirdi. Gösterilen aslında T1'in arkadaş listesiydi. Kök sebep: `reloadFriends` yalnızca mount'ta (`useEffect(..., [])`) çalışıyordu ve bu bileşen çıkış→giriş döngüsünü mount'ta kalarak atlatabiliyor — `LiveGamesTab`'ın `if (creating)` dalı `if (!user)` kontrolünden ÖNCE döndüğünden, form açıkken çıkış yapılsa bile bileşen sökülmüyor (bir modal değil, tam bir görünüm). Sekme değişimi `LiveGamesTab`'ı unmount edip `creating`'i sıfırladığından liste ancak öyle düzeliyordu. **Düzeltme:** bağımlılık `[user?.id]` — `user` REFERANSI değil, çünkü `useAuth` her `onAuthStateChange` olayında (`TOKEN_REFRESHED` dahil) yeni bir `User` nesnesi set ediyor (bkz. `CountBadge`'in "user referansı hesap değişimi değildir" notu). **Bilinçli olarak DOKUNULMAYAN:** `LiveGamesTab`'daki `creating`/`!user` render sırası — asıl yapısal sebep o, ama düzeltmek çıkış anında formu (ve doldurulmuş seçimleri) anında söktüğü için ayrı bir karar; bildirilen hata `[user?.id]` ile tamamen kapanıyor. **Kardeş tarama:** aynı "mount'a bağlı, kullanıcıya özel çekim" deseni `AdminDashboard`/`FriendsModal`/`GameHistoryModal`/`ScoreCard`'da da var ama hepsi MODAL — çıkış `UserMenu`'den yapıldığından bir modal açıkken çıkış yapılamıyor, yani hesap değişimini atlatamıyorlar; `LiveGameCreateForm` tam görünüm olduğu için tek istisnaydı.
- **`FriendSuggestModal.tsx`** — bir daveti **kabul ettikten** sonra devreye girer: o oyundaki, çağıranın henüz arkadaşı olmadığı (relation `'self'`/`'accepted'` DIŞINDAKİ) katılımcıları önceden işaretli checkbox listesiyle gösterir — *"Bu kişileri arkadaşın olarak eklemek ister misin?"* İşaretli kalanlara `sendFriendRequest` çağrılır (tekil hata — ör. zaten bekleyen bir istek varsa gelen unique violation — sessizce yutulur, diğerlerini engellemez), sonra *"Arkadaşlık davetiniz iletilmiştir."* onayı gösterilir. İki taraf da birbirini işaretli bırakırsa `handle_friend_request_insert` trigger'ı (Faz 1) sayesinde otomatik karşılıklı `accepted` olurlar — ekstra bir mekanizma gerekmedi.

### Kapsam dışı (Faz 3'e bırakıldı, aşağıda anlatılıyor)

Faz 2 yazıldığında burada "gerçek zamanlı senkron oynanış yok, Faz 3'ün işi" notu vardı — 28 Temmuz 2026'da Faz 3 (aşağıdaki bölüm) bunu büyük ölçüde tamamladı: tahta/raf/skor artık Supabase'de yaşıyor ve gerçekten oynanabiliyor.

## Canlı Oyun — Faz 3 (Gerçek Zamanlı Senkron Oynanış)

28 Temmuz 2026'da eklendi. Faz 2'nin (yukarı) üzerine kurulu — bir `online_games` satırı `active` olmadan (yani tüm davetler kabul edilmeden) bu fazın hiçbir parçası devreye girmez. **`aynı branch'te (henüz main'e merge edilmemiş PR #165) art arda küçük, birbirini onaylatan adımlarla inşa edildi** — her adım ayrı bir migration/commit, her migration production'a uygulanmadan önce kullanıcıya gösterilip onaylatıldı (bkz. aşağıdaki "Migration'lar" bölümündeki zorunlu akış).

**Mimari karar (Faz 2'de konuşulup burada da geçerli):** kelimenin sözlükte olup olmadığı, bitişiklik/köşe kuralları ve puan hesabı (basePts/words/wordScores/lostShares — `validator.ts`) hâlâ **client tarafında** hesaplanıp sunucuya gönderiliyor; sunucu bunlara güveniyor, `validator.ts`'in tamamını SQL'e taşımak bilinçli olarak kapsam dışı bırakıldı (arkadaş arası casual oyun için kabul edilen hile riski). Sunucunun **gerçekten** doğruladığı/hesapladığı şeyler aşağıda `submit_move` altında listeleniyor — bunlar "hiçbir doğrulama yok" ile "her şeyi sunucu hesaplıyor" arasında bilinçli bir orta nokta.

### Veri modeli — üç tabloya bilinçli bölünme

- **`online_game_states`** — katılımcılara açık, **RAF İÇERMEYEN** anlık state: `board`, `bonuses`, `players` (her oyuncuda `rack` yerine yalnızca `rackCount`), `current`, `turn_count`, `consecutive_passes`, `is_game_over`, `end_reason`, `last_move_cells`, `bag_count`. RLS: yalnızca katılımcı (`is_online_game_participant(game_id, uid)` — kurucu ya da daveti `accepted` olan) `select` edebilir; hiçbir role `insert`/`update` grant'i yok, yazma yalnızca aşağıdaki `security definer` RPC'ler üzerinden. `supabase_realtime` publication'ına eklendi (`online_game_states_realtime` migration'ı) — `OnlineGameScreen`'in Realtime aboneliği bunun üzerinden çalışıyor.
- **`online_game_secrets`** — `bag` + tüm koltukların gerçek `racks`'i. **anon/authenticated'e hiçbir grant verilmedi** (friend_requests tarzı tam kilitli desen) — yalnızca `security definer` RPC'ler (tablo sahibi olarak grant'e tabi olmadıklarından) erişebilir. Realtime publication'ına da hiç eklenmedi — rakibin rafı hiçbir client'a hiçbir yoldan sızmaz.
- **`online_game_moves`** — ek/append-only hamle geçmişi (audit log). Katılımcılar `select` edebilir (oyun geçmişi ekranı için), yazma yine yalnızca RPC üzerinden. Hard `check` constraint'ler bariz bozulmuş/enjekte edilmiş değerleri veritabanı seviyesinde reddediyor: `tile_count` 0-7 arası (RACK_SIZE), `finish_joker_count` 0-2 arası (torbadaki toplam joker), `points` 0-1500 arası (gerçekçi tavanın kat kat üstü, sıkı bir üst sınır değil sadece sanity ceiling), `placements` dizisi 7'yi geçemez, ve `action_shape` kısıtı play/exchange/pass'in hangi alanları doldurup hangilerini sıfır bırakması gerektiğini zorluyor. **Ders (canlı testte yakalandı):** ilk yazımda `turn >= 1` kısıtlanmıştı ama yerel oyunda turlar 0'dan başlıyor (`turnCount: 0` ilk hamlede) — `submit_move` aynı sayacı kullandığından ilk hamle her zaman reddediliyordu; `fix_online_game_moves_turn_check` migration'ıyla `turn >= 0`'a düzeltildi.

### RPC'ler

- **`init_online_game_state(p_game_id)`** — bir oyun `active` olduğu an (`respond_to_game_invite`/`create_online_game` içinden `perform` ile çağrılır, client'a hiç açık değil) tahtayı kurar: **torba sunucu tarafında karıştırılır** (`order by random()`, `src/data/tiles.ts` ile birebir aynı 100 taşlık dağılım) — client'ın "rastgele" dağıtımına güvenilmiyor, aksi halde biri kendi rafını lehine kurabilirdi. Her koltuğa `RACK_SIZE=7` taş dağıtır, boş 13×13 tahta + tek X3 hücresini (`buildInitialBonuses`) ve `cornersFor`/`PLAYER_COLORS` kuralına göre `players` dizisini kurar. İdempotent (state zaten varsa no-op).
- **`get_my_online_rack(p_game_id)`** — çağıranın **kendi** rafını döner (`online_game_secrets`'i okuyabilen tek client yolu) — kendi koltuğunu `online_games.slots`'tan bulup yalnızca o indeksin rafını döner, başkasınınkini asla.
- **`submit_move(p_game_id, p_action, p_placements, p_exchange_letters, p_words, p_word_scores, p_base_points, p_lost_shares, p_move_id)`** — `'play'|'pass'|'exchange'` (`'surrender'` bilinçli olarak kapsam dışı, aşağıya bkz.). **`p_move_id` (5 Ağustos 2026, `submit_move_move_id_idempotency` migration'ı — Flutter portu hazırlığı):** opsiyonel, istemci üretimli hamle UUID'si; aynı UUID'yle gelen yeniden deneme (mobil ağda yanıtı kaybolan istek) hamle zaten işlenmişse hiçbir şey yapmadan başarı döner — öncesinde böyle bir retry sahte bir 'Sıra sende değil.' reddi alırdı. Web istemcisi bu parametreyi GÖNDERMİYOR (null → dedup atlanır, davranış değişmedi); eski imza drop+create ile değiştirildiğinden (overload/300-ambiguous riski) grant'ler migration içinde yeniden kuruldu. Ayrıntı/doğrulama: `mobile/CLAUDE.md`, "Backend Hazırlığı". Sunucunun gerçekten doğruladığı/hesapladığı şeyler:
  - **Sıra kontrolü** — yalnızca `online_game_states.current` koltuğundaki kişinin kendi `auth.uid()`'i hamle gönderebilir (`for update` kilidiyle eşzamanlı çift gönderim de engellenir).
  - **Taş sahipliği** — play/exchange'de belirtilen her taş, oyuncunun sunucudaki gizli rafında harf bazlı (joker `'?'` anahtarıyla) bir multiset eşleştirmesiyle gerçekten var mı kontrol edilip oradan düşülür; rafta olmayan bir taş oynanmaya/değiştirilmeye çalışılırsa reddedilir.
  - **Tahtaya yazılan puan** (`pts`) client'ın gönderdiği değil, eşleşen rafta gerçekten kayıtlı taşın kendi puanı — biri "bu joker aslında yüksek puanlı bir harfmiş" diyemez.
  - **Hedef hücrenin gerçekten boş olması** (sunucu tahtasına göre).
  - **Jokerli bitiş bonusu ve bingo bayrağı** client'tan hiç alınmıyor — tamamen sunucuda, gerçek yerleştirmelerden (kaç tanesi joker) ve rafın/torbanın gerçekten boşalıp boşalmadığından yeniden hesaplanıyor.
  - **Bölge vergisi payları** (`lostShares`) doğrulanıyor: hedef oyuncu indeksleri geçerli aralıkta olmalı, toplam `basePts`'i aşamaz.
  - Bunların ötesinde `basePts`/`words`/`wordScores` client'tan olduğu gibi alınır (yukarıdaki mimari karar). Hamle sonunda `online_game_moves`'a bir audit satırı eklenir, sıra ilerletilir (`turn_count`+1, `current` bir sonraki koltuğa döner — surrender henüz yok, basit round-robin), ve herhangi bir oyuncunun rafı boşken torba da boşsa ya da art arda pas/değişim `player_count × MAX_PASS_ROUNDS`'a ulaşırsa oyun `online_games.status='finished'` olur (`endGame`'in sunucu karşılığı — kalan raf puanları her oyuncudan düşülür).
  - Production'da gerçek bir test oyunuyla (dispozable, sonra silinen) uçtan uca doğrulandı: sıra/taş-sahipliği/dolu-hücre/vergi-toplamı reddi, pas/değişim/oyna akışları, sunucu-taraflı gerçek puan yazımı.

### UI — `OnlineGameScreen.tsx`

Kendi dosyasına taşındı: **`docs/decisions/online-game-screen.md`** (bölünme notu
yukarıda). Ekranın taş sürükleme, joker, mesajlaşma, raf ve senkron davranışları
orada.

### Oyun bitişi → `games` tablosu entegrasyonu

29 Temmuz 2026'da eklendi (`online_game_finish_to_games` migration'ı). `online_games.status='finished'` olduğu an — yani `submit_move`'un bitiş dalının içinde, aynı transaction'da — her insan koltuk için KENDİ hesabına ayrı bir `games` satırı açılıyor. Bu, yerel oyundaki `buildGameRecord`'dan (`src/utils/gameRecord.ts`) bilinçli bir sapma: o yalnızca hesap sahibini (0. koltuk) kaydeder çünkü hotseat'te diğer "insan" oyuncular aynı cihazı paylaşır, kendi hesapları yoktur — Canlı'da ise koltuklar GERÇEKTEN farklı hesaplar olabileceğinden hepsi kendi kaydını almalı, yoksa yalnızca kurucunun Sanal Lig'i güncellenir, diğer katılımcılarınki hiç güncellenmezdi.

- **Rank/sonuç mantığı** `rankPlayers`'daki (`src/utils/ranking.ts`) "competition ranking" ile birebir aynı — 29 Temmuz 2026'da (`online_game_turn_timeout_surrender` migration'ı, bkz. aşağıdaki "Faz 3.6") surrender-farkında hâle getirildi: önce teslim OLMAMIŞ oyuncular skora göre azalan, ardından teslim olanlar (kendi aralarında yine skora göre azalan) sıralanır — tıpkı `rankPlayers`'ın aktif/teslim ayrımı gibi. Bu mantık artık ortak bir yardımcı fonksiyonda (`_finish_online_game_records`, aşağıya bkz.) yaşıyor.
- **`ai_score`** (legacy alan adı, "en iyi rakip skoru" anlamında genel kullanılıyor) diğer TÜM koltukların (YZ dahil) en yüksek skoru.
- **`player_stats` view'ı** (Sanal Lig/Skor Kartı totalleri) hiç değiştirilmedi — `games` satırı doğru `user_id`/`player_score`/`rank`/`result`/`player_count`/`surrendered` ile yazıldığı sürece lig puanı otomatik doğru hesaplanıyor, ayrı bir "online lig puanı" mantığına gerek yok.
- **`board_snapshot` artık doluyor (29 Temmuz 2026, `online_finish_board_snapshot` migration'ı)** — v1'de bilinçli olarak NULL bırakılmıştı; kullanıcı gerçek bir Canlı oyunu Tüm Oyunlarım'da açtığında "Bu oyun için tahta görüntüsü kaydedilmemiş." mesajını görünce eklenmesini istedi. `submit_move`'un bitiş dalına, client'taki `serializeBoardSnapshot`'ın (`src/utils/boardSnapshot.ts`) SQL karşılığı eklendi: `v_board`'u (13×13, o transaction'daki son hamle dahil güncel hâli) tarayıp yalnızca dolu hücreleri `{r,c,l,o,w?}` olarak toplayan tek bir `select ... jsonb_agg(...) from generate_series(0,12) gr, generate_series(0,12) gc where jsonb_typeof(v_board -> gr -> gc) <> 'null'` sorgusu — `l` alanı doğrudan `letter` anahtarından okunuyor çünkü `submit_move`'un play dalı joker taşlarda zaten `letter`'ı `wildLetter`'a eşitliyor (bkz. `v_placed_tile` inşası), ayrı bir case gerekmiyor. Production'daki gerçek bitmiş 4 kişilik oyunun (`7a738722-...`) board'u üzerinde bu sorgu migration uygulanmadan ÖNCE izole olarak doğrulandı (94 dolu hücre, joker hücrelerinde `l`'nin doğru harfe çözüldüğü ve `w:true` taşındığı elle kontrol edildi). **Yalnızca bundan sonra biten Canlı oyunlar için geçerli** — daha önce bitmiş oyunların (`7a738722-...`, `a9dd7b40-...`) `board_snapshot`'ı geriye dönük doldurulamadı, çünkü online state oyun bitince başka bir yerde saklanmıyor, o oyunların tahtası artık kurtarılamaz — `GameHistoryModal` bu satırlarda hâlâ null-toleranslı davranıp "tahta görüntüsü kaydedilmemiş" gösteriyor.
- **Yeni `games.online_game_id` sütunu** (nullable, `online_games`'e FK) — bu kaydın bir Canlı oyundan geldiğini işaretliyor. `GameHistoryModal.tsx`'teki oyun kartları bu alan doluysa `bg-panel` (hafif gri), boşsa `bg-bg` (beyaz) zemin kullanıyor — kullanıcı geri bildirimi: "Tüm Oyunlarım" listesinde Canlı oyunlar yerel oyunlardan görsel olarak ayrışmalı.
- **Geriye dönük doldurma:** Bu migration'dan ÖNCE bitmiş 2 gerçek test oyunu (4 kişilik T1/T2/Ironman/YZ4 ve 2 kişilik Ironman/AlpTEST) için aynı mantıkla bir kereliğine elle backfill SQL'i çalıştırıldı — geriye dönük hiçbir otomatik job yok, yalnızca o an mevcut iki oyun için tek seferlik bir düzeltme.
- **Doğrulama:** Mantık, bu iki gerçek oyunun bilinen final skorlarıyla (`execute_sql` ile salt-okunur bir simülasyon) elle doğrulandı önce, sonra production'a uygulanıp aynı iki oyun için gerçekten backfill edildi ve satırların rank/sonuç/`ai_score` değerleri beklenenle bire bir eşleşti.
- **Bulunan hata — `players` snapshot dizisi sıralı değildi (29 Temmuz 2026, aynı gün, kullanıcı Skor Kartı'nda kontrol ederken):** Kullanıcı 4 kişilik test oyununu Tüm Oyunlarım listesinde açtığında sıralamanın yanlış göründüğünü bildirdi — Ironman ve YZ4 (ikisi de 106 puan, gerçek 2.'likte beraber) 3. sırada gösteriliyordu, gerçek sonuncu (T2, 93 puan) 2. sırada görünüyordu. Kök sebep: yukarıdaki `v_fp_players_json` inşası oyuncuları KOLTUK sırasıyla (T1, T2, Ironman, YZ4) diziyordu. Modaldeki per-oyuncu sıralama gösterimi `computeRanks(entry.players)`'tan (`src/utils/leaguePoints.ts`) geliyor ve bu fonksiyon SIRALAMA YAPMIYOR — yalnızca ardışık elemanları karşılaştırıp aynı (skor, surrendered) ise aynı sırayı veriyor, yani girdinin ZATEN skora göre azalan sırada olduğunu varsayıyor. Yerel oyunlar bu varsayımı `buildGameRecord`'daki (`src/utils/gameRecord.ts`) `players: ranked.map(...)` ile (önce sıralayıp SONRA snapshot alarak) sağlıyor; yeni online kodu bunu atlamıştı — koltuk sırasıyla `[T1(122), T2(93), Ironman(106), YZ4(106)]` girdisinde `computeRanks` pozisyonel olarak `[1,2,3,3]` üretiyordu (tam da ekran görüntüsündeki hata), doğrusu `[1,4,2,2]`. Not: `games.rank`/`result` SKALER sütunları zaten doğruydu (ayrı bir `v_fp_ranks` hesabından geliyor) — yalnızca `players` jsonb dizisinin eleman SIRASI yanlıştı, `player_stats` view'ı da (Sanal Lig totalleri) skaler sütunlardan hesaplandığından bundan hiç etkilenmedi. **Düzeltme** (`fix_online_finish_players_order` migration'ı, `20260729081244`): `v_fp_players_json` artık önce `v_fp_sorted_idx int[]` ile (skora göre azalan, eşitlikte koltuk indeksi artan — `rankPlayers`'daki (`src/utils/ranking.ts`) JS stabil-sort davranışının SQL karşılığı) sıralı bir indeks dizisi hesaplayıp diziyi bu sırayla inşa ediyor. Migration'dan ÖNCE zaten backfill edilmiş 3 satırın (4 kişilik test oyunu, `online_game_id='7a738722-...'`) `players` alanı da elle aynı düzeltilmiş sırayla (`T1, Ironman, YZ4, T2`) `UPDATE` edildi — 2 kişilik test oyununun (`a9dd7b40-...`) koltuk sırası tesadüfen skora göre azalandı, o satırların düzeltilmesine gerek olmadı.

### Canlı Oyun — Faz 3.6 (Zaman aşımı ile otomatik teslim)

29 Temmuz 2026'da eklendi (`online_game_turn_timeout_surrender` migration'ı). Kullanıcının tasarım kararı: Canlı'da manuel bir "Teslim Ol" butonu YOK — üstteki logo/"←" hâlâ yalnızca Canlı listesine döner, oyunu bitirmez (bu davranış değişmedi). Bunun yerine **sırası gelen oyuncu 48 saat içinde hamle yapmazsa otomatik teslim olur** — yerel oyundaki kademeli teslim mantığıyla birebir aynı: puanı sıfırlanır, rafındaki taşlar torbaya karışır (karıştırılarak), kalan oyuncular sırayla oynamaya devam eder, aktif oyuncu sayısı 1'e düşünce oyun biter ve o son kalan oyuncu kazanır. Cron/arka plan job'u YOK (bu projede CI/CLI erişimi olmadığından her şey elle uygulanan migration'larla yönetiliyor) — bunun yerine YZ turu tetiklemesiyle AYNI "hafif" desen: `check_turn_timeout(p_game_id)` RPC'si süre dolmadıysa no-op'tur, dolmuşsa teslimi uygular; herhangi bir katılımcının istemcisi bunu çağırabilir.

- **Şema:** `online_game_states`e `turn_deadline timestamptz` eklendi — `init_online_game_state` ilk turda, `submit_move` her tur ilerlemesinde `now() + 48 saat`'e ayarlıyor (oyun bitince `null`). `players[i].surrendered` alanı zaten vardı (yerel `Player` tipiyle aynı şema, `init_online_game_state`'te hep `false` başlıyordu) — bu migration'a kadar hiç `true`'ya çekilmiyordu.
- **`check_turn_timeout(p_game_id)`** — yalnızca `authenticated`'e grant edilmiş (submit_move ile aynı desen). Sırayı/state'i/gizli tabloyu `for update` ile kilitleyip: (1) oyun zaten bittiyse ya da `turn_deadline` henüz geçmediyse ya da sırası gelen koltuk YZ'yse (YZ zaten `play-ai-turn` ile otomatik oynuyor) ya da o koltuk zaten teslim olmuşsa NO-OP döner; (2) aksi halde sırası gelen koltuğu teslim eder — rafındaki taşlar torbaya karışır, puanı 0'a çekilir, `surrendered:true`/`rackCount:0` işaretlenir; (3) kalan aktif (teslim olmamış) koltuk sayısı 1'e düşerse oyun biter (`_finish_online_game_records` çağrılır, aşağıya bkz.), düşmezse sıra bir sonraki teslim olmamış koltuğa geçer ve `turn_deadline` yeniden 48 saate ayarlanır; (4) her durumda `online_game_moves`'a `action:'surrender'` bir audit satırı eklenir (bu kısıt zaten `fix_online_game_moves_turn_check`'ten beri `'surrender'`i destekliyordu, ileriye dönük bırakılmıştı).
  **Bulunan hata (4 Ağustos 2026, `check_turn_timeout_bag_count` migration'ı) — `bag_count` güncellenmiyordu:** Fonksiyon teslim olan oyuncunun rafını gerçek torbaya (`online_game_secrets.bag`) doğru karıştırıyordu ama onun istemciye açık aynası olan `online_game_states.bag_count`'a İKİ dalında da hiç dokunmuyordu. Bugüne kadar fark edilmemesinin sebebi `submit_move`'un bu alanı her hamlede gerçek torbadan yeniden hesaplaması (`bag_count = coalesce(array_length(v_bag_arr, 1), 0)`) — yani hata bir sonraki hamlede kendiliğinden düzeliyordu. Etkisi yalnızca görsel (oyun sonu tespiti/taş çekme/puanlama hep gerçek torbayı okuyor), ama 4 kişilik oyunlarda gerçekten görünür: orada teslim oyunu bitirmediğinden kalan oyuncular bir sonraki hamleye kadar — yani 48 saate kadar — torbayı 7'ye kadar eksik görebiliyordu. 2 kişilikte teslim oyunu anında bitirdiğinden pratikte kimse görmüyordu. Migration iki dala da `bag_count` satırını ekledi ve etkilenmiş 3 mevcut satırı (hepsi bitmiş oyun, hepsi tam 7 eksik — ikisi gerçek kullanıcı oyunu) gerçek torbaya eşitledi. **TESTING.md bölüm 4 elle koşulurken bulundu** — otomatik testin ulaşamadığı bir yer olduğu için o listenin değerini gösteren somut bir örnek.
  **17 Ağustos 2026 — düzeltme GERÇEK istemciyle, İKİ DALDA da doğrulandı:** o güne kadar kanıt yalnızca migration'ın kendi backfill'iydi. Ortak SQL turunda iki test oyununun `turn_deadline`'ı geçmişe çekilip süpürme gerçek uygulamadan tetiklendi ve iki dal ayrı ayrı ölçüldü — 4 kişilik (oyun BİTMEZ) dalında torba 65 → **72** ve `bag_count` **72**; 2 kişilik (oyun BİTER) dalında 70 → **77** ve `bag_count` **77**. Dalların ikisini birden koşmak şart: hata orijinal hâlinde İKİSİNDE de vardı ama yalnızca 4 kişilikte kullanıcıya görünüyordu (2 kişilikte oyun anında bittiğinden kimse bakamıyordu), yani tek dal koşmak düzeltmenin yarısını sınamadan bırakırdı.
- **Paylaşılan bitiş yardımcısı — `_finish_online_game_records`:** 29 Temmuz'un önceki değişikliğinde (`online_game_finish_to_games`) `submit_move`'un bitiş dalına gömülü olan ranking/players-json/board-snapshot/`games`-insert mantığı, hem `submit_move` hem `check_turn_timeout`'un çağırabileceği ortak bir `SECURITY DEFINER` fonksiyona çıkarıldı. **Gerekçe — aynı gün daha önce yaşanan `fix_online_finish_players_order` hatası:** o hata tam olarak "aynı mantığın iki farklı yerde kopyalanıp ayrışması" riskinin somut bir örneğiydi; teslim/zaman-aşımı ile normal bitiş artık İKİ ayrı kod yolu olacağından, bu sefer baştan tek bir yardımcıya çıkarılıp ikisinin de aynı sıralama/players-json/board-snapshot mantığını paylaşması sağlandı. Fonksiyon `p_players` parametresini (zaten rack-puanı düşülmüş, güncel `surrendered` bayraklarıyla) alıp: skora göre azalan/teslim-olmamışlar-önce sıralı bir indeks dizisi hesaplıyor, `games.rank`i bu sırayla üretiyor, her `human` koltuk için `result` artık `surrendered` ise doğrudan `'lose'` (rank/tied1'den bağımsız — `buildGameRecord`'daki (`src/utils/gameRecord.ts`) yerel eşdeğeriyle aynı kural), değilse eskisi gibi rank/tied1 tabanlı, ve `games.surrendered` sütununa artık hardcoded `false` yerine gerçek bayrağı yazıyor. Doğrudan uç kullanıcıya AÇILMIYOR (`revoke all ... from public/anon/authenticated`) — yalnızca `perform` ile başka `SECURITY DEFINER` fonksiyonlardan çağrılabilir, çünkü parametrelerine güvenip doğrudan `games`'e satır ekliyor.
- **`submit_move`'un bitiş dalı** artık bu yardımcıyı çağırıyor (kod tekrarı kalmadı) ve her tur ilerlemesinde `turn_deadline`'ı da güncelliyor. Ayrıca "bag boşken rafı boş olan biri oyunu bitirir" kontrolü artık `not surrendered` şartını da taşıyor — bir koltuk zaten teslim olmuşsa (rafı kalıcı olarak boş) bu tek başına oyunu normal yoldan bitirmemeli, bitiş yalnızca `check_turn_timeout`'un aktif-oyuncu-sayısı kontrolünden gelmeli.
- **UI:**
  - **`fetchOnlineGameDeadlines(gameIds)` / `checkOnlineGameTurnTimeout(gameId)`** (`src/lib/api.ts`) — sırasıyla `turn_deadline`'ları okur, RPC'yi çağırır.
  - **`LiveGamesTab.tsx`** — "Aktif Oyunlar" listesindeki her satırda, durum etiketinin altında küçük bir "kalan süre" göstergesi (`remainingTimeLabel`, Setup'taki `remainingDays`'in saat cinsinden eşdeğeri — süre azaldıkça kırmızı/kalın, ≤6 saatte "acil" sayılır). **3 Ağustos 2026 — yalnızca sırası ÇAĞIRANDA olan oyunlarda gösteriliyor:** `turn_deadline` her zaman sırası gelen oyuncuya aittir, ama gösterge her aktif satırda çıkıyordu; "Rakibin hamlesi bekleniyor" etiketinin altında "N saat sonra teslim sayılacak" yazınca kullanıcı bunu KENDİ süresi sanıyordu (kullanıcı bildirdi), oysa o süre dolduğunda teslim olan taraf rakip. Artık `isMyTurn ? remainingTimeLabel(deadline) : null` — bilgi kaybı yok, sırası kendisinde olmayan oyunda kullanıcının yapabileceği bir şey zaten yok; `isMyTurn` henüz `undefined` iken (turns tablosu yüklenmemiş) de gizli kalır, karşı tarafa ait bir süre bir an bile görünmesin diye. Liste her açıldığında, yerel olarak bilinen `turn_deadline`'lardan HERHANGİ biri zaten geçmişse (gereksiz RPC çağrısından kaçınmak için önce client-side kontrol) o oyun(lar) için `check_turn_timeout` tetiklenip liste bir kez daha tazelenir — asılı kalmış bir oyun, kullanıcı bu sekmeyi her açtığında kendiliğinden çözülür.
  - **`OnlineGameScreen.tsx`** — `refresh()` döngüsüne (Realtime olayı/foreground dönüşü/mount) YZ-tetikleme çağrısının yanına `checkOnlineGameTurnTimeout` da eklendi (kendi `timeoutCheckingRef` bayrağıyla, `aiTriggeringRef` ile aynı "ardışık refresh'leri üst üste bindirme" koruması). Ayrıca 10 dakikalık bir `setInterval` eklendi — ekran açık kalıp hiçbir hamle/foreground olayı gerçekleşmezse (ör. biri bekleme ekranını saatlerce açık bırakırsa) zaman aşımının hiç taranmaması riskini azaltıyor; 48 saatlik pencereye göre sık olması gerekmiyor.
- **Doğrulama (production'da, gerçek test hesaplarıyla, tek seferlik/geri alınmış senaryolar):** Migration uygulanmadan önce SQL simülasyonlarıyla mantık doğrulanmıştı (bkz. genel ilke, "Migration'lar" bölümü); bu sefer ayrıca **gerçek `submit_move`/`check_turn_timeout`'u** disposable sahte oyunlarla (gerçek test hesaplarının id'leriyle, `online_games`/`online_game_states`/`online_game_secrets`/`game_invites` satırları elle eklenip `set local role authenticated; set local request.jwt.claims=...` ile katılımcı simüle edilerek) uçtan uca çağırdım: (1) 2 kişilik oyunda tek teslim → anında bitiş, doğru kazanan/`rank`/`result`/`players` sırası, rafın torbaya tam dönüşü (bag 86→93). (2) 4 kişilik oyunda art arda 2 teslim → her ikisinde de sıra doğru bir sonraki aktif koltuğa geçti, oyun bitmedi. (3) Aynı oyunda 3. teslim (yalnızca YZ koltuğu kalınca) → oyun bitti, 3 insan koltuğun da `games` satırı doğru (`rank=2` hepsi berabere, `result='lose'`, `surrendered=true`) oluştu, YZ'ye (insan olmadığından) hiç satır açılmadı. (4) Ayrıca normal (zaman aşımsız) bir `submit_move('pass')` çağrısı da aynı refactor sonrası hâlâ doğru çalıştığı (sıra ilerliyor, `turn_deadline` yenileniyor) doğrulandı. Dört senaryonun da test verisi (`games`/`online_game_*`/`game_invites` satırları) doğrulama sonrası tamamen silindi, production'da hiçbir iz bırakmadı.
- **Kart metinleri sadeleşti (30 Ağustos 2026, kullanıcı isteği — kozmetik, davranış AYNI):** Aktif oyun kartındaki durum etiketi `Senin Hamlen Bekleniyor` → **`SIRA SENDE!`**, `Rakibin hamlesi bekleniyor` → **`SIRA RAKİPTE`**; punto 11 → **13 px**, altındaki kalan-süre 8 → **10 px**. Kutu BÜYÜMEDİ: yeni etiketler kısa (`SIRA RAKİPTE` 12 karakter), eskisi 11 px'te bile daha genişti. Etiketler kaynakta BÜYÜK harfle yazılı — CSS `uppercase` zaten uyguluyor ama Türkçe i→İ dönüşümü tarayıcının `lang` duyarlılığına kalıyordu; portun `trUpper`ı da idempotent kalsın diye iki taraf aynı dizeyi taşıyor.

  **Aynı gün, aynı turda ikinci ve üçüncü geçiş (kullanıcı her seferinde ekran görüntüsüne bakıp söyledi):** süre 10 → 9 → **8 px**, sonuna parantez içinde **sürenin sonucu**, ve `SIRA SENDE!`nin yanına **`>`** (etiketin İÇİNDE, yani boyutu/rengi koşulsuz aynı; `SIRA RAKİPTE`de YOK — `>` "git oyna" demek, rakipteyken yapılacak bir şey yok). Parantez, yukarıda "kabul edilen bilgi kaybı" diye yazılan şeyi geri getiriyor — ama bu kez fiil olarak değil **ceza miktarıyla**: `(Teslim -2 puan)`. ⚠ **Setup'ın yerel YZ kaydında parantez İKİ DALLI:** orada -2 her zaman geçerli değil (`willSurrender` false — henüz bir tam tur oynanmamış — ise kayıt yalnızca siliniyor), o dal `(Silinecek)` yazıyor; ayrım zaten `verb`de vardı, parantez ona bağlandı. Olmayan bir cezayla korkutmamak için. **Genişlik ölçüldü, tahmin edilmedi:** port testleri 320 px'e zorlanıp koşturuldu, hiçbir `RenderFlex overflow` çıkmadı (en uzun hâli `30 SAAT 5 DAKİKA KALDI (TESLİM -2 PUAN)`, 420 px'te ~234 px).

  ⚠ **Ok, etiketle AYNI puntoda olmasına rağmen küçük görünüyordu — ve bu ancak PİKSEL ölçülerek anlaşıldı.** Kullanıcı *"oku yazıyla aynı büyüklüğe getir"* dedi; ilk tepki "zaten aynı, dizenin içinde" olurdu. Ekran görüntüsü taranınca (pixelRatio 3, `PIL` ile yeşil piksellerin dikey uzanımı): 13 px'te büyük harflerin mürekkep yüksekliği **27 px**, aynı puntodaki `>` yalnızca **17 px** — çünkü `>` matematik hizasında oturan, harf boyuna çıkmayan bir glif. Eşitleyen punto 13 × 27/17 ≈ **21**. Ok bu yüzden etiketin dizesinden çıkarılıp kendi öğesine alındı (`TurnArrow` / `turnArrowSpan`). **21'e çıkarınca ikinci bir sapma doğdu:** taban çizgisine hizalı `>` harflerin 8 piksel yukarısında kalıyordu (ok y 507-534, harfler y 516-542) → 2,67 mantıksal px aşağı kaydırıldı; son ölçümde merkezler arası fark **0,17 px**. Satır kutusu `height: 13/21` ile 13 px'e kilitli, yoksa 21 px'lik ok kartı uzatırdı. **Port tuzağı:** `WidgetSpan`in çocuğu bir widget'tır ve saran `TextSpan`in rengini MİRAS ALMAZ — `const` bir span yazılsaydı ok siyah çıkardı, o yüzden renk parametre. Yan etki: davet kartının sağ üstündeki süre de 9 px olduğundan artık bu satırla EŞİT boyda — `mobile/docs/testing-arkadaslar-canli.md`'deki punto maddesi buna göre düzeltildi.

  **Üç sayaç da tek kalıba indi: yalnızca `N gün M saat kaldı`.** Öncesinde her biri kendi fiilini taşıyordu — `sonra teslim sayılacak` (aktif oyun, 48 sa) · `sonra iptal edilecek` (davet, 7 gün) · `sonra silinecek`/`sonra teslim sayılacak` (Setup'ın yerel YZ kaydı, 7 gün). Üçüncüsü kullanıcının listelemediği bir yerdi ve ayrıca bildirildi; aynı hizaya çekildi çünkü ikisi de "devam eden oyun" satırı ve kullanıcı ikisini yan yana görüyor. **Kabul edilen bilgi kaybı:** fiil, sürenin sonunda NE olacağını söylüyordu — özellikle Setup'taki `teslim sayılacak` hesaba gelecek **-2 cezanın** tek uyarısıydı. Bu yüzden fiil süre DOLDUĞUNDA geri geliyor (`Bugün teslim sayılacak` / `Bugün silinecek`): "Bugün" tek başına hiçbir şey anlatmazdı ve bilgi değeri tam orada en yüksek. Geri sayarken ise kartın kendisi (davet mi, sıra mı, yerel kayıt mı) hangi sürenin işlediğini zaten söylüyor.

- **Süre aşımından teslim olana uyarı e-postası (2 Ağustos 2026, `check_turn_timeout_notify_surrender` migration'ı, `notify-turn-timeout-surrender` Edge Function'ı):** Kullanıcı isteği — 48 saat hamle yapılmadığı için otomatik teslim olan oyuncu bunu bir e-postayla öğrenmeli, sadece bir dahaki girişte fark etmemeli. Metin sabit: "{rakip(ler)} ile oynadığınız {2/4} kişilik oyun 48 saat içinde hamle yapmadığınızdan dolayı sonlanmış ve maalesef k-lig puanınızdan 2 puan düşürülmüştür. Tekrar oyun başlatmak için aşağıdaki butona tıklayın." + bir **"Oyun Aç"** butonu (`https://kelimeki.com`, `notify-friend-request`'teki "Kelimeki'yi Aç" butonuyla aynı desen — özel bir "yeni oyun kur" deep-link'i yok, kullanıcı ana sayfadan kendisi başlatıyor).
  - **Tetikleyici — oyun GERÇEKTEN bittiği an, çağıranın kimliğinden bağımsız:** `check_turn_timeout` client tarafından HERHANGİ bir katılımcı tarafından tetiklenebildiğinden (yukarıdaki "hafif" desen — süresi dolan oyuncunun kendisi değil, başka bir katılımcının ekranı da bu RPC'yi çağırabilir), e-postayı "kim çağırdı" değil "gerçekte ne oldu" belirlemeli. Bu yüzden bildirim `submit_move`/`notify-friend-request` gibi client'tan `invokeEdgeFunction` ile DEĞİL, doğrudan `check_turn_timeout`'un SQL gövdesinden `net.http_post` ile tetikleniyor (`notify-deadline-warnings`'in cron'dan kullandığı AYNI pg_net çağrısı, farkı zamanlanmış değil bir RPC'nin içinden anlık tetiklenmesi) — bu yüzden Edge Function'ın `verify_jwt`'i KAPALI (çağıran Postgres'in kendisi, hiçbir kullanıcı JWT'si taşımıyor).
  - **4 kişilik oyunlarda "kim zaman aşımına uğradı" ile "kimin -2 cezası şu an gerçekten uygulandı" AYNI ŞEY DEĞİL:** Bir oyuncu erken teslim olsa bile aktif oyuncu sayısı hâlâ >1 ise oyun hemen bitmiyor (bkz. yukarıdaki `check_turn_timeout` açıklaması) — `_finish_online_game_records` (dolayısıyla `games` satırı + gerçek -2 cezası) yalnızca aktif sayı 1'e düştüğünde, yani oyun GERÇEKTEN son bulduğunda çalışıyor. Bu yüzden `net.http_post` çağrısı yalnızca `if v_active_count <= 1` (bitiş) dalının İÇİNE, `_finish_online_game_records`'tan hemen sonra eklendi — ve Edge Function o oyundaki TÜM teslim olmuş insan koltuklarına (yalnızca en son zaman aşımına uğrayana değil) mail gönderiyor, çünkü hepsinin cezası TAM O ANDA birlikte işleniyor (biri günler önce, biri az önce teslim olmuş olsa bile). 2 kişilik oyunda zaten tek teslim = anında bitiş olduğundan bu ayrım hiç gözlenmiyor, yalnızca 4 kişilikte önemli.
  - **Rakip isimleri/oyuncu sayısı `profiles`'a hiç gitmeden `online_game_states.players[i].name`'den okunuyor** — bu alan zaten oyunun başında (`init_online_game_state`) çözülüp dondurulmuş görünen ismi taşıyor (YZ koltukları için "Yapay Zeka"/"Yapay Zeka N"), yani ek bir sorgu gerekmiyor; yalnızca alıcının GERÇEK e-posta adresi için servis-rol client'la `auth.admin.getUserById` çağrılıyor (`auth.users` hiçbir client rolüne hiç açılmadığından). Birden fazla rakip varsa isimler Türkçe "A, B ve C" kalıbıyla birleştiriliyor (`joinTurkishList`).
  - **Güvenlik — `verify_jwt` kapalıyken kötüye kullanım koruması:** Bu uç teorik olarak herkese açık bir POST hedefi olduğundan, fonksiyon önce hedef `online_game_id`'nin GERÇEKTEN `online_game_states.end_reason='surrender'` VE `is_game_over=true` olduğunu, sonra da her alıcı koltuğun GERÇEKTEN `players[i].surrendered=true` olduğunu doğruluyor — sahte/var olmayan bir id ya da normal (timeout dışı) biten bir oyunla çağrılırsa sessizce `{sent:0}` döner, kimseye mail gitmez.
  - **Doğrulama:** (1) Deploy edilmiş Edge Function'a rastgele/var olmayan bir `online_game_id` ile gerçek bir `net.http_post` çağrısı yapılıp `{"ok":true,"sent":0,"reason":"not_finished_by_timeout"}` döndüğü (hiçbir mail gitmediği) doğrulandı. (2) `check_turn_timeout`'un YENİ eklenen `net.http_post` satırı, disposable bir 2 kişilik test oyunuyla (gerçek iki test hesabının id'leriyle, `online_games`/`online_game_states`/`online_game_secrets` satırları elle eklenip zaten süresi geçmiş bir `turn_deadline` verilerek) bir transaction içinde uçtan uca çağrıldı — state geçişleri (`is_game_over:true`, `end_reason:'surrender'`, teslim olan koltuğun `score:0`) VE `net.http_request_queue`'ya doğru `{"online_game_id": "..."}` gövdesiyle bir istek kuyruklandığı doğrulandı, sonra `rollback` ile geri alındı — pg_net'in arka plan işçisi COMMIT edilmemiş bir satırı hiçbir zaman göremediğinden bu, gerçek bir e-posta göndermeden `net.http_post`'un doğru çalıştığını kanıtlayan güvenli bir yöntem (aynı mantık `notify-deadline-warnings`'in ilk doğrulamasında da kullanılmıştı). (3) **17 Ağustos 2026 — UÇTAN UCA, gerçek gönderimle kapandı:** iki test hesabının (T1↔T2) gerçek bir Canlı oyununun `turn_deadline`'ı geçmişe çekilip süpürme GERÇEK uygulamadan tetiklendi; `net._http_response`'ta fonksiyonun cevabı **`{"ok":true,"sent":1}`** (oyunun bitiş saniyesiyle aynı damga) ve mail T1'in gerçek gelen kutusuna ulaştı. Yani zincirin daha önce yalnızca rollback'le simüle edilen son halkası (pg_net'in COMMIT sonrası isteği gerçekten atması + Edge Function'ın Brevo'ya gönderimi) artık kanıtlı. Aynı turda 4 kişilik dalın mail ÜRETMEDİĞİ de doğrulandı (oyun bitmediğinden `net.http_post` hiç çağrılmıyor) — negatif eşi olmayan bir "mail geldi" gözlemi, fonksiyonun KOŞULSUZ gönderip göndermediğini ayırt edemezdi.

### Teslim süresi uyarı e-postaları — projenin İLK gerçek cron job'u (31 Temmuz 2026)

Kullanıcı isteği: hem Canlı oyunlarda sırası gelen oyuncuya (48 saatlik `turn_deadline`), hem de YZ'ye karşı oynanan "Devam Eden Oyunlar"a (7 günlük `ABANDON_TIMEOUT_MS` terk-edilme penceresi) süre 24 saatin altına düşünce bir hatırlatma e-postası gitsin — konu "Oyun Süresi Doluyor!", metin "{oyunu açan}'nin açtığı {N} kişilik oyunun süresi dolmak üzere. 24 saat içinde hamle yapmadığınız taktirde teslim olmuş sayılacaksınız ve lig puanınızdan 2 puan düşülecek.", altında "Şimdi Oyna" butonu.

**İlk sürüm uygulama-içi bir banner'dı, kullanıcı e-posta istediğini fark edip geri aldırdı:** İlk yorumda kullanıcı bu davranışı Canlı'da tarif edince, bunu OnlineGameScreen/App.tsx'te (mesaj alanının yerine) kırmızı bir banner olarak inşa ettim (`turn_deadline`'ı `OnlineGameStatePublic` tipine ekleyip `canAct && <24h` iken gösteren bir uyarı, YZ tarafında da `resumeDeadlineRef` ile bir eşdeğeri). Kullanıcı test edip "sen sitedeki görüntü ve mesajları da mı değiştirdin?" diye sorunca "hayır, sadece uygulama-içi bir banner ekledim, email göndermedim" diye netleştirdim — bunun üzerine kullanıcı "prompt'ta email yazmayı atlamışım" deyip bu değişikliği (`git revert`) geri aldırdı ve gerçekten email istediğini belirtti. **Ders:** "24 saat kala X yapılsın" gibi bir istek geldiğinde X'in ne olduğu (uygulama-içi mesaj mı, e-posta mı) belirsizse önce netleştir — özellikle proje zaten bu ikisini net ayrı ele alan bir tarihe sahipken (bkz. yukarıdaki tüm "işlemsel e-posta bildirimleri" bölümü).

**Neden bu, projenin İLK gerçek zamanlanmış (cron) görevi — önceki "hafif" desenden bilinçli sapma:** `check_turn_timeout`/`check_invite_expiry` gibi önceki tüm "süre doldu mu" kontrolleri kullanıcı etkileşimine bağlı çalışıyordu (birisi uygulamayı açtığında tetikleniyordu) — bu bir hatırlatma E-POSTASI için işe yaramaz, çünkü tam olarak KİMSENİN uygulamayı açmadığı bir oyuncuya ulaşması gerekiyor; "birisi açınca kontrol et" deseni burada kendi kendini yenen bir mantık olurdu. Bu yüzden — kullanıcının açık onayıyla ("Evet, gerçek zamanlanmış görev kurulsun") — Supabase'in `pg_cron` + `pg_net` uzantıları ilk kez bu projede etkinleştirildi (`deadline_warnings_cron` migration'ı). `pg_cron` her 15 dakikada bir `net.http_post` ile yeni bir Edge Function'ı (`notify-deadline-warnings`) tetikliyor; kullanıcı etkileşiminden tamamen bağımsız çalışıyor.

- **Şema (`deadline_warning_email_columns_and_triggers` migration'ı):** Hem `online_game_states` hem `local_game_saves`'e `deadline_warning_sent_at timestamptz` eklendi — bu deadline için uyarı zaten gönderildi mi. `turn_deadline` her yenilendiğinde (`submit_move`, `check_turn_timeout`'un her iki dalı) bu alan da `null`'a çekiliyor ki bir sonraki 24 saatlik yaklaşımda uyarı tekrar gönderilebilsin. `local_game_saves` için `set_updated_at()` yerine yeni bir `touch_local_game_save()` trigger'ı geldi — **kritik incelik:** bu trigger `deadline_warning_sent_at`'i yalnızca `new.state is distinct from old.state` iken (yani gerçek bir hamlede) sıfırlıyor; aksi halde cron'un kendi "gönderildi" işaretlemesi (yalnızca `deadline_warning_sent_at`'i dolduran, `state`'e dokunmayan bir UPDATE) bu trigger'ı tetikleyip flag'i anında kendi kendine geçersiz kılardı (sonsuz tekrar gönderim riski) — ilk taslakta bu ayrım yoktu, kod yazılırken fark edilip düzeltildi.
- **`notify-deadline-warnings` Edge Function'ı** (`supabase/functions/notify-deadline-warnings/`) — **`verify_jwt: false`** (projedeki DİĞER tüm Edge Function'ların aksine): çağıranın kimliği hiç kontrol edilmiyor çünkü çağıran cron'un kendisi, herhangi bir kullanıcı JWT'si taşımıyor; fonksiyon kendi service-role client'ıyla çalışıp dışarıdan hiçbir parametre almıyor. Bunun güvenli olmasının sebebi: (1) hiçbir girdi kabul etmiyor, her çağrıda AYNI sabit taramayı yapıyor; (2) her satır `.is('deadline_warning_sent_at', null)` filtreli bir UPDATE ile atomik olarak "iddia edilip" işaretlendiğinden tekrar tekrar (kötü niyetli ya da eşzamanlı) çağrılması en fazla "no-op" sonucu verir, asla mükerrer e-posta göndermez. İki ayrı tarama yapıyor: (a) `online_game_states` — `is_game_over=false AND turn_deadline` şu an ile +24 saat arasında olan VE henüz uyarılmamış satırlar; sırası gelen koltuğun (`slots[current]`) `user_id`'sinden e-postayı, `online_games.created_by`'dan "kimin açtığı" ismini okuyor. (b) `local_game_saves` — burada sabit bir deadline sütunu olmadığından (`deadline = updated_at + ABANDON_TIMEOUT_MS`), pencere `updated_at`'in eşdeğer bir aralığına çevrilerek sorgulanıyor (`updated_at > now()-7gün AND <= now()-7gün+24saat`); YZ oyununda "oyunu açan" her zaman hesap sahibinin kendisi olduğundan aynı isim hem alıcı hem "açan" olarak kullanılıyor. **Marka şablonu** diğer `notify-*` fonksiyonlarıyla aynı (`buildBrandedEmailHtml`), ama `_shared/email.ts`'e import yolu farklı: diğer fonksiyonlar `'../_shared/email.ts'` kullanırken bu fonksiyon `'./_shared/email.ts'` kullanıyor — ilk deploy denemesinde `'../...'` ile "Module not found" hatası alındı (`deploy_edge_function`'ın bu MCP çağrısında dosyaları nasıl konumlandırdığına dair bir tutarsızlık, kesin sebebi netleştirilmedi), `'./...'`e geçilince sorunsuz deploy oldu — ileride bu fonksiyona dokunulursa bu farkı korumak gerekiyor.
- **Cron kurulumu (`deadline_warnings_cron` migration'ı):** `create extension if not exists pg_cron;` / `pg_net;` sonra `cron.schedule('notify-deadline-warnings', '*/15 * * * *', $$ select net.http_post(url := '.../functions/v1/notify-deadline-warnings', ...); $$)`. `pg_net` `public` şemasına kuruldu (linter WARN veriyor, "Extension in Public") — `alter extension pg_net set schema extensions` denendi ama pg_net `SET SCHEMA`'yı desteklemiyor (`0A000` hatası) — bu, pg_net kullanan Supabase projelerinde bilinen/kabul edilen bir kısıt, düzeltilmeye çalışılmadı (DROP+CREATE denemek cron job'un `net.http_post` çağrısını bozma riski taşırdı, kazanç riske değmedi).
- **Doğrulama (production'da, gerçek satırlarla):** Migration'lar uygulandıktan hemen sonra fonksiyon `select net.http_post(...)` ile SQL üzerinden elle bir kez tetiklendi (bu ortamdan doğrudan HTTP erişimi proxy tarafından engellendiğinden — Vercel preview URL'lerinde yaşanan aynı kısıt — `net._http_response` tablosundan sonucu okumak gerekti). Sonuç: `{"ok":true,"sentOnline":2,"sentLocal":0}` — gerçekten süresi 24 saatin altına düşmüş 2 canlı oyun bulunup **gerçek bir kullanıcıya (Ebru/"Bobola") iki gerçek e-posta gönderildi**; bu test verisi değil, halihazırda üretimde var olan ve gerçekten bu pencereye düşen oyunlardı — kullanıcıya bu şeffaf şekilde bildirildi. `deadline_warning_sent_at` alanlarının doğru işaretlendiği ayrıca sorgulanıp doğrulandı.
- **Kapsam dışı:** Süre dolmadan önce ikinci bir hatırlatma (ör. son 1 saat) — yalnızca TEK bir 24 saatlik eşik var, istenirse aynı desenle (ayrı bir `*_sent_at` sütunu/eşiği) eklenebilir. Davet (henüz kabul edilmemiş) zaman aşımı (`online_game_invite_expiry`, aşağıya bkz.) bu kapsamda DEĞİL — yalnızca AKTİF oyun/devam eden YZ oyunu kapsandı, kullanıcı yalnızca bunları istedi.

### Davet zaman aşımı (7 gün — kapsam dışı listesinden çıktı)

29 Temmuz 2026'da eklendi (`online_game_invite_expiry` migration'ı). Yukarıdaki Faz 3.6 yalnızca AKTİF oyun içindeki sıra zaman aşımını (48 saat) kapsıyordu; bekleyen davetler (`online_games.status='pending'`, en az bir davet hâlâ yanıtlanmamış) için ayrı bir kural yoktu. Kullanıcının tasarım kararı — iki seçenekten ("oyunu iptal et" / "boş koltuğu YZ ile doldur") **iptal**i seçti: 7 gün içinde tüm davetler yanıtlanmazsa oyun kimseye ceza uygulanmadan tamamen iptal edilir, sadece listeden kalkar. Süre/gerekçe yerel oyundaki `ABANDON_TIMEOUT_MS` (`gameStorage.ts`) ile birebir aynı — tek bir "7 gün" kavramı artık üç yerde geçerli: yerel Devam Eden Oyun, Canlı oyun davetleri, (ve ayrı olarak) aktif Canlı oyunda sıra 48 saat.

- **`check_invite_expiry(p_game_id)`** — yalnızca `authenticated`'e grant edilmiş, `check_turn_timeout` ile aynı no-op deseni: oyun `pending` değilse ya da `created_at`'ten bu yana 7 gün geçmediyse hiçbir şey yapmaz; geçtiyse `online_games.status`'u `'abandoned'`e çeker (bu değer zaten tablonun `check` kısıtında vardı, şema değişikliği gerekmedi). Yetki kontrolü `is_online_game_participant`'ı KULLANMIYOR — o fonksiyon yalnızca `accepted` davetlileri "katılımcı" sayıyor, ama henüz yanıtlamamış (hâlâ `pending`) bir davetlinin de bu süpürmeyi tetikleyebilmesi gerekiyor; bunun yerine `online_games_select_party` RLS politikasıyla aynı "taraf" deseni (kurucu YA DA `game_invites`'ta herhangi bir durumda bir satırı olan davetli) inline tekrarlandı. `game_invites` satırlarının kendisi dokunulmadan (hâlâ `pending`) kalıyor — yalnızca `online_games.status` değişiyor.
  **Bulunan hata (4 Ağustos 2026) — "ayrı bir istisna kodu gerekmedi" varsayımı BAŞTAN BERİ YANLIŞTI:** Bu madde, `game_invites`'a dokunmamanın güvenli olduğunu şu gerekçeyle savunuyordu: "`list_my_online_games`'in tüm mevcut filtrelerinde (`active`/`pending` kontrolleri) `abandoned` hiçbirine düşmez, oyun listeden doğal olarak kaybolur". Bu cümle yazıldığı gün de doğru değildi — `LiveGamesTab.tsx`'teki DÖRT kovadan üçü (`active`, `waiting`, `acceptedWaiting`) gerçekten `g.status`'e bakıyor ama `invites` kovası SADECE `my_role`/`my_invite_status`'e bakıyordu. Sonuç: süresi dolup iptal edilen bir davet KURANIN listesinden doğru şekilde kalkıyor, ama DAVETLİNİN "Davet Bekliyor" listesinde sonsuza dek duruyordu — üstelik "BUGÜN İPTAL EDİLİR" etiketiyle, yani istemci verinin süresinin dolduğunu bilip kartı yine de çiziyordu. Aynı eksik iki yerde daha vardı: `fetchPendingLiveGameCounts` (`src/utils/pendingLiveGames.ts`) — hayalet davet Setup'taki "Arkadaşınla (N)" rozetini, PWA ikon rozetini (`useAppIconBadge`) ve girişte otomatik Canlı sekmesine geçiren `inviteCount > 0` koşulunu şişiriyordu — ve `LiveGamesTab`'ın varsayılan alt sekme seçimi (`hasInvites`), kullanıcıyı bomboş bir "Oyun Davetleri" sekmesine düşürebiliyordu. Üçüne de `g.status === 'pending'` eklendi. **Veri bozulması yoktu:** `respond_to_game_invite`'ın kabul dalı zaten `where id = v_game_id and status = 'pending'` içerdiğinden `abandoned` bir oyun diriltilemiyordu (`init_online_game_state` hiç çağrılmıyordu) — ama "Kabul Et"e basılırsa `game_invites` satırı yine de `accepted`'a çekildiğinden kart sessizce kaybolup hiçbir oyun başlamıyordu, yani kullanıcı için kafa karıştırıcı bir çıkmazdı. **Ders:** "şu filtre zaten bunu eler, ayrı kod gerekmez" gibi bir gerekçeyi yazmadan önce filtrelerin HEPSİNİ tek tek okuyun — burada dördün üçü gerçekten eliyordu, gözden kaçan tek istisna yeterliydi. Özelliğin eklendiği 29 Temmuz'dan bu yana hiç fark edilmemesinin sebebi de bu: 7 günlük süre gerçek kullanımda daha yeni dolmaya başlıyordu, TESTING.md bölüm 4 elle koşulup süre yapay olarak geçmişe çekilene kadar kimse bu yola girmemişti.
- **UI:** `checkInviteExpiry(gameId)` (`src/lib/api.ts`) RPC'yi çağırır. `LiveGamesTab.tsx`'teki `loadGames` artık aktif-oyun sıra-zaman-aşımı süpürmesiyle AYNI turda, `pending` oyunlardan `created_at + ABANDON_TIMEOUT_MS <= now()` olanları da (client-side ön kontrol, gereksiz RPC'den kaçınmak için) tespit edip `check_invite_expiry`'yi tetikliyor, sonra listeyi bir kez daha tazeliyor — iki süpürme (turn-timeout + invite-expiry) tek bir `Promise.all`'da birleşti, ayrı ayrı ikinci bir round-trip gerekmedi. `PendingGameCard`'daki her davet/bekleme kartının başlığının altına artık `remainingInviteDays` ile hesaplanan bir kalan-süre satırı eklendi (Setup'taki `remainingDays` ile aynı ilke/süre — ≤1 günde kırmızı/kalın). **4 Ağustos 2026 — metin tutarlılığı:** süre dolduğunda "Bugün iptal edilir" yazıyordu; hem yanlıştı (iptal gelecekte değil, süre ZATEN dolmuş) hem de projenin diğer sayaçlarıyla ("Süresi doldu - teslim oldu", `remainingTimeLabel`) tutarsızdı — "Süresi doldu" oldu. Kalan süre metni de "N gün M saat kaldı" yerine `remainingTimeLabel`/`SavedGameRow` kalıbına ("... sonra iptal edilecek" — süre + o sürenin sonunda NE olacağı) hizalandı. Süresi dolmuş bir davetin bu etiketle görünmesi artık yalnızca geçici bir durum: `invites` kovasındaki status filtresi (yukarı bkz.) onu süpürme çalışır çalışmaz listeden düşürüyor — hem "Davet Bekliyor" (yanıt bekleyen) hem "Kabul Ettin — Diğerleri Bekleniyor"/"Rakip Bekleniyor" kartlarında görünür, çünkü `PendingGameCard` üçünde de aynı bileşen.
- **Doğrulama (production'da, disposable test verisiyle):** Migration uygulanıp `list_migrations`'daki gerçek versiyonla dosya adı eşleştirildikten sonra, gerçek test hesaplarıyla (T1 kurucu, T2 davetli) sahte bir `online_games` satırı `created_at = now() - 8 gün` ile eklenip `check_invite_expiry`'nin davetli tarafından çağrılması `status`'u `pending`'den `abandoned`'a çevirdiği doğrulandı; `created_at = now() - 2 gün` olan (henüz süresi dolmamış) bir satırda RPC'nin no-op kaldığı (status hâlâ `pending`) ayrıca doğrulandı; taraf olmayan üçüncü bir hesabın (Ironman) çağrısının `'Bu oyunun tarafı değilsin.'` hatasıyla reddedildiği doğrulandı. Test verisi sonra tamamen silindi.

## Düşen istek "hiç oyunun yok" DEMEZ (21 Ağustos 2026)

**Vaka:** Kullanıcının yanındaki **BeckyH**, sırası KENDİSİNDEYKEN uygulamayı
açtı ve "Arkadaşınla" sekmesinde *"Devam eden bir Canlı oyunun yok."* gördü.
Oyun ~9 dakika sonra kendiliğinden belirdi; arada YZ'ye karşı bir oyun açıp
oynadı.

**Teşhis ÖLÇÜLDÜ, tahmin edilmedi.** Sunucu tarafı TEMİZ: o oturumdaki 16
`list_my_online_games` çağrısının 16'sı **200** döndü ve **aktif oyunu
İÇERİYORDU** — kanıt, her birinin hemen ardından gelen
`online_game_states?...in.(<oyun id>)` isteği (`fetchOnlineGameTurns` boş
listede HİÇ istek atmaz, yani o istek listenin dolu geldiğinin kanıtı).
`client_errors` **0 satır** (JS çökmesi yok), `game_starts` satırları o günün
derlemesini koşturduğunu gösteriyor. Telefonunun IP'si oturum boyunca
**31.143.14.211 ↔ 178.250.94.110** arasında gidip geliyordu.

**Kök sebep (çıkarım, açıkça çıkarım):** ağ değişimi (WiFi↔hücresel) uçuştaki
bir isteği yarıda kesti; `listMyOnlineGames` hatayı YUTUP `[]` döndü ve UI
bunu "gerçekten hiç oyun yok" diye okudu. **Tekrar deneme YOKTU** ve listeyi
yeniden tetikleyen tek şey öne dönüş/Realtime olduğundan yanlış ekran KALDI.
**İkinci bulgu:** düşen yükleme `appliedDefaultTabRef`i de sessizce TÜKETTİ,
yani "girişte Canlı sekmesini aç" kararı o oturum için bir daha çalışamadı —
büyük olasılıkla YZ oyunu açmasının sebebi bu.

**Kullanıcının koyduğu sınır (sözleriyle):** *"Oraya İnternet bağlantısı yok
çıkartmak da doğru değil çünkü başka yerlere girince bunun doğru olmadığını
görecekler."* — yani düzeltme etiketi değiştirmek DEĞİL, sorunu gerçekten
çözmek zorundaydı. Onaylanan ölçüt: **kullanıcı hiçbir zaman gerçek olmayan
bir şey görmemeli ve iyileşmek için hiçbir şey yapmak zorunda kalmamalı.**

### Dört katman (hepsi İKİ platformda)

| Katman | Ne yapar |
|---|---|
| **Ağ-özel tekrar** (`retryOnNetworkFailure` / `_fetchWithRetry`) | Düşen istek **400 ms** ve **1200 ms** sonra sessizce tekrarlanır. Anlık kesintiyi kullanıcı hiç görmeden kapatır. |
| **`[]` ≠ `null` ayrımı** | `listMyOnlineGames`/`fetchOnlineGameTurns`/`fetchOnlineGameDeadlines` artık hatada **`null`** döner. `[]` yalnızca "sunucu gerçekten boş dedi" demektir. |
| **Otomatik merdiven** (3/8/20/30 sn, son basamak tekrarlanır) | Kesinti sürerse UI kendi kendine denemeye devam eder — kullanıcının hiçbir şey yapması gerekmez. Yalnızca sekme GÖRÜNÜRKEN kurulur. |
| **Yeniden bağlanma kancası** (`onResubscribe`) | Realtime kanalı koparsa o sırada yayınlanan olaylar KALICI kayıptır (28 Temmuz dersi); yeniden bağlanmanın kendisi bir tazeleme sinyali olarak kullanılıyor. |

### Ne YAZILIR — üç ayrı cümle, üçü de doğru

- `OFFLINE_NO_CONNECTION` — YALNIZCA `navigator.onLine === false` iken.
- `LOAD_FAILED_NOTICE` (*"Oyunların şu an yüklenemedi."*) + **Tekrar Dene** —
  bağlantı VAR ama elde gösterilecek hiç liste yok.
- `STALE_DATA_NOTICE` (*"Güncellenemedi"*) — liste ekranda ama tazelenemedi;
  veri **bayat, yanlış değil**. İnce bir şerit, dokunma hedefi DEĞİL.

**"Hiç oyunun yok" artık YALNIZCA sunucu gerçekten boş dediğinde çıkar.**

### Yakalanan yan hatalar

- **Tek başarısız yükleme `appliedDefaultTabRef`i tüketiyordu** (`Setup.tsx`)
  ve `useAppIconBadge` rozeti sıfırlıyordu — ikisi de artık `counts === null`
  iken erken dönüyor, son bilinen değeri koruyor.
- **`useOnlineStatus` asimetrik debounce aldı:** çevrimdışıya geçiş **1500
  ms** doğrulanmadan uygulanmaz, çevrimiçi ANINDA uygulanır. Sebep ölçüldü:
  `navigator.onLine` spesifikasyona göre `false` iken gerçekten bağlantısız,
  ama **ağ değişimi anında** kısa bir `false` penceresi doğuyor ve o pencerede
  uçuştaki istekler iptal ediliyor — sunucuda HİÇBİR iz bırakmadan. İlk ölçüm
  BİLEREK debounce edilmez (soğuk açılışta uyarı hemen çıkmalı).
- **`isNetworkError`e `PostgrestError` NESNESİ verilmez, `error.message`
  verilir** — nesne `"[object Object]"`e serileşir ve hiçbir kalıba uymaz,
  yani tekrar deneme sessizce hiç çalışmazdı.

### Doğrulama

`npm run verify-live-games-load` — **22 kontrol** (15'i bu vaka, 7'si aynı
gün eklenen giriş varsayılanı kuralı), ÜRETİM fonksiyonlarını sahte
bir Supabase ucuyla koşturuyor: ağ hatası → `null` + **3** çağrı; boş liste →
`[]` + **1** çağrı; **ilk istek düşüp ikincisi başarılı** (kullanıcının
vakası) → liste geliyor; sunucunun KENDİ reddi → tekrar YOK; yapılandırılmamış
istemci → `[]` (hata değil). **Negatif eş ölçüldü:** tekrar katmanı
kaldırılınca **4** kontrol, `null` yerine `[]` dönülünce **3** kontrol
GERÇEKTEN düşüyor. `tests/smoke.spec.ts`e ayrıca "kısa kesinti çevrimdışı
uyarısı ÜRETMEZ" testi eklendi (paket 20 → **21**); debounce kaldırılınca
düşüyor. CI'a eklendi (`web-ci.yml`).

**Duman testiyle sınanamayan kısım ve sebebi:** bu kod yolu oturum açmış bir
kullanıcı istiyor, dev sunucusunda Supabase yapılandırılmadığından tarayıcıda
ulaşılamıyor — `verify-*` betiği deseninin (esbuild + node) var olma sebebi bu.

**Mobil portun karşılığı:** `mobile/CLAUDE.md`, Parça 118 — aynı gecikmeler (**21 Ağu 2026'dan beri `layout_parity_test.dart` ile testli**),
aynı üç metin (`offline_notice.dart` ↔ `offlineNotice.ts`, parite testi
karşılaştırıyor), aynı merdiven.
