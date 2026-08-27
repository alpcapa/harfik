# Arkadaşlık Sistemi — Karar Kaydı

> **Bölünme notu (25 Ağustos 2026):** Bu dosya, `docs/decisions/live-game-and-friends.md`nin
> üç parçaya ayrılmış hâlinin biri. Ayrım `npm run check-doc-size`in uyarı bandına
> girilmesiyle zorunlu oldu (156 KB / 200 KB — kural: *"uyarı bandındaki dosyayı bir
> sonraki dokunuşunda böl"*, bkz. kök `CLAUDE.md`). İçerik SATIR SATIR AYNI, yalnızca
> yer değiştirdi. Kardeş dosyalar: `friends.md` (arkadaşlık sistemi),
> `live-game.md` (Canlı oyun Faz 2-3.6, sunucu tarafı), `online-game-screen.md`
> (`OnlineGameScreen.tsx` — canlı oyun ekranının UI kararları).

## "Ara & Ekle" iki hatası: yutulan kaydırma + mükerrer üye (27 Ağustos 2026)

Kullanıcı bildirdi: *"Arkadaşlar - Ara&Ekle'de scroll down bir yerde
takılıyor, sonuna kadar gitmiyor."* Aramada İKİ ayrı hata çıktı — biri
istemcide (port), biri sunucuda. Aynı ekranda olmaları tesadüf; kökleri
ayrı.

### 1. Portta: modalın içine ikinci bir kaydırılabilir konmuştu

`friends_modal.dart`'ın "Ara & Ekle" sekmesi üye listesini
`ConstrainedBox(maxHeight: 320) > ListView(shrinkWrap: true)` içinde
çiziyordu — yani `KModal`'ın gövde `SingleChildScrollView`'ının **İÇİNE**
ikinci bir kaydırılabilir. Aynı modaldeki öteki iki sekme ("Arkadaşlarım",
"İstekler") düz `Column`; tutarsızlık yalnızca burada.

**Ölçüldü** (widget testi, 420×560 — klavye `autofocus` ile açık olduğundan
gerçek cihazda kalan yükseklik bu civarda):

| | Düzeltmeden önce | Sonra |
|---|---|---|
| Modal gövdesinin gösterdiği aralık | y 119 → 518 | y 119 → 518 |
| İç listenin kapladığı aralık | y 326 → **646** | — (iç liste YOK) |
| 60 sürüklemeden sonra dış kaydırma offset'i | **0.0** | 2864.0 |
| Son üyenin (46.) konumu | y 600–620 (**ekran dışı**) | y 452–472 |

Yani listenin alt **128 px'i** — son ~2,5 satır ve "Yükleniyor…" nöbetçisi —
ekranın altında kalıyordu ve oraya ulaşmanın yolu yoktu.

**Kök sebep bir kural farkı: Flutter iç içe kaydırmayı ZİNCİRLEMEZ.**
Tarayıcı, iç kutu ucuna gelince kaydırmayı dıştakine devreder (web'in
`max-h-[50vh] overflow-y-auto`'su bu yüzden `FriendsModal.tsx`'te sorun
çıkarmıyor — web tarafı ETKİLENMEDİ, dokunulmadı). Flutter'da iç `ListView`
jesti tümüyle sahiplenir: parmağını listenin üzerine koyan kullanıcı dış
gövdeyi **hiç** kaydıramaz. Ölçülen `0.0` tam olarak bu.

**Düzeltme — iç kaydırılabiliri EKLEMEK değil KALDIRMAK:** liste artık öteki
iki sekme gibi düz bir `Column`, modalda tek bir kaydırılabilir var.
Sayfalama dinleyicisi listenin kendi denetleyicisinden modalın gövdesine
taşındı: `KModal`'a `bodyController` adında isteğe bağlı bir parametre
eklendi (varsayılanı `null`, öteki ~15 modal etkilenmedi), `FriendsModal`
kendi `_bodyScroll`'unu oraya veriyor. Dinleyici artık üç sekmede de
ateşlendiğinden `_loadMoreAllUsers` iki koruma kazandı: sekme `search`
değilse ve arama kutusunda 2+ karakter varsa sayfa istemez — o iki durumda
"tüm üyeler" listesi zaten çizilmiyor.

⚠ **Genel kural (bu modalın ötesinde):** `KModal`'ın gövdesi zaten
kaydırılabilir. İçine ikinci bir `ListView`/`SingleChildScrollView` koyma —
uzun liste gerekiyorsa `Column` + `bodyController` deseni. Sabit bir
`maxHeight` bunu kurtarmaz, tam tersine hatayı görünmez kılar: 900 px'lik
bir test penceresinde gövde taşmadığı için hata **hiç görünmüyordu**,
yalnızca klavye açıkken ortaya çıkıyordu.

**Regresyon:** `friends_test.dart`'a bir test eklendi — parmak GERÇEK bir
liste satırının üzerinde başlayıp 60 kez sürükleniyor, sonra son üyenin
gövdenin içinde olması ve modalda hiç `ListView` bulunmaması isteniyor.
**Negatif eşi kanıtlandı:** düz `Column` eski `ConstrainedBox > ListView`
hâline geri alınınca test düşüyor (`Actual: <620.0>` vs beklenen `<= 518.0`).

### 2. Sunucuda: `LEFT JOIN` + karşılıklı `OR` = sessiz çoğaltma

`list_users_for_friend` ve `search_users_for_friend`, ilişkiyi bulmak için
`friend_requests`'e karşılıklı bir koşulla `left join` yapıyordu. **İki yön
de satır olarak varsa** (A→B ve B→A ayrı ayrı istek göndermiş — tamamen
meşru) join o profil için İKİ satır üretiyor ve aynı üye listede iki kez
çıkıyor. `limit/offset` join satırlarını saydığından 20'lik bir sayfa 19
farklı üye taşıyor.

Bu, bir gün önce düzeltilen `list_my_online_games`/`list_friends` hatasının
(`20260827121628`, bkz. `live-game.md`) **AYNI sınıfı**. Canlıda ölçüldü:
47 profilin 46'sını gören iki üyede join 47 satır döndürüyordu.

**Düzeltme** (`20260827153857_dedupe_friend_candidate_lists`, canlıya
uygulandı ve doğrulandı — 47 → 46):
- `distinct on (p.id)` ile profil başına tek satır; hangi satırın kalacağı
  deterministik: önce `'accepted'` (arkadaşlık bir "bekliyor"u ezer), sonra
  `fr.created_at`, sonra `fr.user_id`.
- Sıralamaya `id` eşitlik-bozucusu: `order by name` TEK BAŞINA toplam bir
  sıra değil. Bugün aynı ada sahip iki üye yok ama `first_name` benzersiz
  değil, ve Postgres eşitlikte sıra garanti etmez — offset sayfalaması iki
  çağrı arasında satır atlayıp tekrarlayabilirdi.

Dönüş şekli `(id, name, avatar_url, relation)` ve yetkiler değişmedi, yani
**uygulama güncellemesi beklemiyor** — web de portun eski sürümü de düzelmiş
listeyi anında alıyor.

## Arkadaşlık Sistemi (Canlı Oyun — Faz 1)

Kullanıcılar "karşılıklı/canlı oyun" istiyor — bunun ön koşulu olarak eklenen 1. faz: arkadaşlık. Henüz senkron oynanış/davetli oyun kurma yok, yalnızca kim kiminle arkadaş olacağının altyapısı (bkz. proje sohbetindeki analiz: tüm mimariyi değiştirmeye gerek yok, oyun motoru saf fonksiyonlar olduğundan aynen kalıyor — değişen şey state'in nerede yaşadığı, bu faz sadece sosyal grafiği kuruyor). İki bağımsız yol var:

- **(A) Mevcut kullanıcıyı arayıp ekleme** — `friend_requests` tablosu (`user_id, friend_id, status: pending|accepted`, birincil anahtar ikisi birden). "Arkadaş mıyız" her zaman iki yönü de kontrol eder. Uygulama içi (RLS ile korunan, `friend_requests_select_own`/`insert_self`/`update_addressee`/`delete_either` politikaları) bildirimin yanında, 29 Temmuz 2026'dan beri alıcıya bir de **e-posta bildirimi** gidiyor (bkz. aşağıdaki "İşlemsel e-posta bildirimleri" bölümü) — öncesinde bilerek hiçbir e-posta gönderilmiyordu (maliyet/gürültü kaygısı, anlık sosyal bildirim yalnızca `UserMenu`'deki "Arkadaşlar" rozetiyle gösteriliyordu), ama kullanıcı geri bildirimiyle bundan dönüldü: alıcı uygulamayı hiç açmazsa istekten tamamen habersiz kalıyordu. Karşı taraftan zaten bekleyen bir istek varsa (`handle_friend_request_insert` trigger'ı) yeni bir satır açmak yerine mevcut olan otomatik `accepted`'a çevrilir (karşılıklı istek durumu) — bu durumda e-posta gönderilmez (habersiz kalınacak "bekleyen" bir şey yok, ilişki zaten anında kuruldu).
  **"Ara & Ekle" sekmesinde tüm üyeler alfabetik/lazy listesi (31 Temmuz 2026):** Öncesinde arama kutusu boşken (2 karakterden az) hiçbir sonuç gösterilmiyordu — kullanıcı, arama yapmadan da tüm üyeleri gezip istediği kadar kişi ekleyebilmek istedi. `list_users_for_friend(p_offset, p_limit)` RPC'si eklendi (security definer, `search_users_for_friend` ile aynı şekli — id/name/avatar_url/relation — döndürür ama BİLEREK ayrı bir fonksiyon: arama kendi 2-karakter/20-sonuç kısıtını korurken bu, `Leaderboard`'daki `IntersectionObserver` tabanlı lazy-load deseniyle (offset/limit, sayfa başı 20) sınırsız kaydırılabilir). `FriendsModal.tsx`'te arama kutusu boşken bu liste ("Tüm Üyeler" başlığıyla, `max-h-[50vh] overflow-y-auto`) gösterilir, 2+ karakter yazılınca eski arama sonuçlarına döner. Satır render'ı (`renderFriendRow`) ve ilişki güncelleme mantığı (`patchRelation`) iki liste arasında paylaşılır — bir kullanıcıya arama sonucundan ya da tüm-üyeler listesinden istek gönderilmesi/kabul edilmesi/iptal edilmesi fark etmeksizin her iki listede de anında yansır. Ekle butonu her satırda bağımsız olduğundan kullanıcı listeden istediği kadar kişiye art arda istek gönderebilir.
- **(B) Henüz üye olmayanlar dahil, kalıcı davet linkiyle davet etme** — asıl kullanıcı kazanım (büyüme) mekanizması bu; "mevcut arkadaş listesiyle sınırlı kalmasın" kararının sonucu. `friend_invite_links` tablosu kullanıcı başına **tek, kalıcı/reusable** bir token tutar (`create_friend_invite_link` RPC'si, ilk çağrıda oluşturur sonrakilerde aynısını döner — tek kullanımlık DEĞİL, kullanıcı aynı linki istediği kadar kişiye/WhatsApp grubuna tekrar tekrar gönderebilir). `FriendsModal`'daki "Arkadaşını Davet Et" butonu linki oluşturup `navigator.share` (skor paylaşımındaki (`GameHistoryModal`) aynı share→clipboard fallback deseni) ile WhatsApp/SMS/DM gibi kanallara açar — **e-posta kullanılmaz**, bu hem büyüme hem maliyet hedefini aynı anda karşılıyor.

**`/davet/:token`** (`FriendInvitePage.tsx`, `main.tsx`'teki `/game/:id` ile aynı router'sız path-eşleme desenine eklendi) girişsiz de erişilebilir bir sayfa — `get_friend_invite_info` RPC'si (anon+authenticated) "X seni davet ediyor" önizlemesini döner. Tıklayan zaten girişliyse `accept_friend_invite` RPC'si arkadaşlığı doğrudan `accepted` açar (link tıklaması zaten bilinçli bir onay, `pending` beklemeye gerek yok); girişsizse sayfadaki "Giriş Yap / Kayıt Ol" butonu `AuthModal`'ı açar, `useAuth()`'un `user`'ı dolar dolmaz aynı sayfa daveti otomatik işler. **E-posta doğrulaması açıkken taze bir kayıt** doğrulama linkine tıklanana kadar oturum açmaz ve o link genelde `/davet/:token`'a değil uygulamanın köküne döner — bu riski karşılamak için sayfa mount olur olmaz token'ı `localStorage`'a (`friendInvite.ts`, `gameStorage.ts`'teki terk edilmiş oyun kuyruğuyla aynı read-then-clear deseni) kuyruklar; `App.tsx`'teki bir fallback effect (`user` dolunca) bu kuyruğu okuyup daveti oradan da işleyebilir.

`accept_friend_invite` ayrıca `friend_invite_links.use_count`'u artırır ve (ilk kezse) `profiles.invited_by`'ı doldurur — `guest_visits.utm_source`'un ilk-temas ilkesiyle aynı mantık, ileride admin Büyüme panelinde "arkadaş daveti ile gelen kayıt" metriği için kullanılabilir (henüz eklenmedi).

`search_users_for_friend`/`list_friends`/`list_incoming_friend_requests` RPC'leri `security definer` — `profiles.select` RLS'i `lock_down_profiles_games_select` migration'ından beri owner-or-admin'e kilitli olduğundan (`game_likers`/`leaderboard` ile aynı gerekçe) başka kullanıcıların adını okumak için gerekiyor; **e-posta hiçbir zaman döndürülmez** (projenin genel ilkesi, bkz. Skor Kartı notundaki e-posta gizliliği).

**Kapsam dışı (henüz yok, bkz. aşağıdaki Faz 2):** Faz 1 yazıldığında oyun daveti/kurma burada listeleniyordu — 27 Temmuz 2026'da Faz 2 ile eklendi. Hâlâ kapsam dışı olanlar: gerçek zamanlı senkron oynanış (Faz 3), zaman aşımı/oto-teslim (Faz 4). Faz 2 eklenmeden önce arkadaş eklemenin tek somut faydası `FriendsModal`'ın "Arkadaşlarım" sekmesinde bir kişiye tıklayınca `PlayerScoreCard`'ı açmasıydı — `Leaderboard`/`GameHistoryModal`'daki `likerToPlayerSummary` ile aynı desende bir adaptör kullanır. Artık ikinci (ve asıl) somut fayda: arkadaşını Canlı bir oyuna davet edebilmek.
  **11 Ağustos 2026 — kişiye dokunmak artık ÜÇ sekmede de kartı açıyor (kullanıcı isteği: "Arkadaşlarımda kişilere tıklayınca skor kartına gidiyorum ama Ara & Ekle'de bu yok"):** "İstekler" ve "Ara & Ekle" (hem arama sonucu hem "Tüm Üyeler") satırları düz `<Avatar>`+`<span>` çiziyordu. Üçü de artık ortak bir `personButton(id, name, avatarUrl)` kullanıyor; "Arkadaşlarım"ın satır-içi kopyası silindi (ikinci bir tıklama yolu açılmadı). Adaptör de genelleşti: `friendToPlayerSummary(f: FriendRow)` yerine `toPlayerSummary(id, name, avatarUrl)` — üç listenin veri tipi farklı (`FriendRow`/`IncomingRequest`/`FriendSearchResult`), ortak olan yalnızca bu üç alan. **"İstekler" sekmesi kullanıcı yalnızca "Ara & Ekle" dediği hâlde bilerek dahil edildi** (bir isteği yanıtlamadan önce gönderenin kartına bakmak, üç listenin içinde bu davranışın en faydalı olduğu yer) — kapsamı kendi genişletmek de daraltmak kadar riskli olduğundan gerekçe burada yazılı, istenmezse tek satırlık geri alma. **Kart kapanınca ilişki tazeleniyor** (`fetchFriendRelation` + `patchRelation` + iki listenin yeniden çekimi): `PlayerScoreCard`'ın kendi arkadaşlık simgesinden (bkz. `RelationIcons`) ekleme/çıkarma yapılabildiğinden, bu olmadan kartta "çıkar"a basıp kapatan kullanıcı satırda hâlâ eski ikonu görürdü. Dokunma alanı (`flex-1`) ile aksiyon ikonunun 44px hedefi ayrışık — ikisi birbirini yutmuyor. Flutter portu aynı gün aynı değişikliği aldı (`mobile/CLAUDE.md`, Parça 53).

### Hoş geldiniz e-postası (21 Ağustos 2026, kullanıcı isteği)

Yeni üyeye tek seferlik bir karşılama maili: kısa bir hoş geldiniz + **Hemen
Oyna** düğmesi + "Görüş Bildir"e davet. `notify-welcome` Edge Function'ı.

**NE ZAMAN — kayıt anında DEĞİL, e-posta ADRESİ DOĞRULANDIĞINDA.** Bu, işin
tek gerçek tasarım kararı ve üç ölçüme dayanıyor:
1. Bu projede e-posta doğrulaması **AÇIK** — 26 hesabın 24'ü `created_at`ten
   SONRA onaylanmış. (`agreed_to_terms`in yıllarca `false` kalmasının sebebi
   de aynı gerçekti: `signUp()` session döndürmüyor.)
2. Kayıt anında adresin sahipliği henüz kanıtlanmamıştır; oraya yazmak bounce
   üretir ve **domainin gönderim itibarını yakar** — bu proje DKIM/DMARC'ı
   düzeltmek için ayrıca uğraşmıştı (bkz. "Brevo SMTP").
3. Üretimde **2 hesap hiç onaylamamış**. Onlar fiilen üye değil ve "Hemen
   Oyna" düğmesi onlar için çalışmaz.

**Zincir:** `auth.users` üzerindeki `on_auth_user_welcome` trigger'ı
(`after insert or update of email_confirmed_at`) → `_notify_welcome_email()`
→ `net.http_post` → Edge Function. `verify_jwt` **KAPALI** (çağıran Postgres,
JWT yok) — `notify-turn-timeout-surrender` ile aynı desen.

**İdempotens:** `profiles.welcome_email_sent_at`. Trigger önce ATOMİK olarak
iddia ediyor (`where welcome_email_sent_at is null`), yalnızca satırı
gerçekten kaptıysa çağırıyor. **Doğrulandı** (geri alınan transaction, üç
aşama): onaysız kayıtta damga boş / kuyruk 0; onay anında damga dolu / kuyruk
1 ve gövde doğru `user_id`; İKİNCİ bir onay güncellemesinde kuyruk hâlâ 1
(mükerrer yok).

**Trigger ADI önemli:** INSERT olayında `on_auth_user_created` bu trigger'dan
ÖNCE koşmalı ki `profiles` satırı var olsun — Postgres aynı olaydaki
trigger'ları ADA GÖRE sıralıyor ve "created" < "welcome". Yeni bir
`auth.users` trigger'ı eklenirse bu sıra kontrol edilmeli.

**ÖLÇÜLEN KIRILGANLIK — `net.http_post`un varsayılan zaman aşımı 5 sn ve
soğuk başlangıç bunu aşıyor.** Doğrulama turunda birebir yaşandı: ilk çağrı
`Timeout of 5000 ms reached … HTTP Request/Response time: 4843 ms` ile düştü,
hemen ardından yapılan ikinci (sıcak) çağrı 200 döndü. Bu bildirimde bedeli
diğerlerinden ağır: mail kullanıcı başına HAYATTA BİR KEZ gidiyor ve damga
çağrıdan ÖNCE konduğundan kaybedilen istek bir daha DENENMİYOR. Süre açıkça
**20 sn**'ye çekildi (ikinci migration). **Projedeki diğer `net.http_post`
çağrıları hâlâ varsayılan 5 sn'de** — orada kayıp daha ucuz (cron tekrar
deniyor ya da olay tekrarlanabiliyor), ama yeni bir "bir kez gönderilir"
bildirimi eklenirse bu tuzağı hatırla.

**Açık uçtaki koruma (verify_jwt kapalı):** `user_id` GİZLİ DEĞİL — k-lig ve
`game_likers` gibi RPC'ler girişli herkese kullanıcı id'si döndürüyor. Bu
yüzden fonksiyon üç şeyi kendisi doğruluyor: hesap var ve **adresi
doğrulanmış**; `welcome_email_sent_at` **son 15 dakika içinde** damgalanmış
(tekrar çağrılarak mail bombardımanı yapılamasın); alıcı işlemsel bildirimleri
kapatmamış (`email_notifications_enabled`). **Gerçek HTTP çağrısıyla
doğrulandı:** var olmayan bir id → `{"sent":false,"reason":"not_confirmed"}`,
gerçek bir üyenin (geriye dönük doldurulmuş, yani bayat) damgası →
`{"sent":false,"reason":"stale_claim"}` — yani mevcut üyelere kaza eseri mail
GİTMİYOR.

**Geriye dönük doldurma:** mevcut TÜM onaylı üyelerin damgası
`email_confirmed_at`e çekildi, yani bu özellik canlıya çıktığında kimseye
toplu mail gitmedi. Kolon yorumunda yazılı: o satırlarda damga "gönderildi"
değil **"atlandı"** demek. Hiç onaylamamış 2 hesap BİLEREK null bırakıldı —
yarın onaylarlarsa maili hak ediyorlar.

**Metin (kullanıcının taslağı düzeltilerek):** kullanıcının taslağı hitapta
karışıktı (*"Sayın … / Sizi aramızda"* = siz, *"hoşgeldin / oyununu /
atarsan"* = sen). Projenin diğer beş e-postası tamamen **siz** kullanıyor, o
yüzden metin siz'e sabitlendi. Ayrıca: **"hoş geldiniz" AYRI yazılır** (TDK) —
bir kelime oyununun mailinde bitişik yazmak özellikle kötü olurdu; *"yorum
atmak"* gündelik olduğundan ürünün kendi yüzey adı olan **"Görüş Bildir"**
kullanıldı (kullanıcı böylece nereye gideceğini de biliyor); *"şimdi hemen"*
ikilemesi tekile indi. Düğme etiketi kullanıcının istediği gibi **"Hemen
Oyna"** kaldı — gövde siz'ken düğmenin sen kipinde olması tutarsız görünebilir
ama düğme bir cümle değil ETİKET ve karşılama sayfasının kendi CTA'sı da
"HEMEN OYNA".

**Bağlantı düz `https://kelimeki.com`** — `?ref=` etiketi BİLEREK
eklenmedi: `captureUtmSource` first-touch çalışıyor ve mail linkine bir etiket
koymak, kullanıcının BAŞKA bir cihazda ilk temasını "hosgeldin" diye
damgalayıp Kaynak Hunisi'nin ziyaretçi tarafını kirletirdi.

**Doğrulama sınırı:** gerçek bir gönderim (Brevo'ya giden mail) TEST
EDİLMEDİ — bunun tek yolu gerçek bir kişiye mail atmak. Guard'ların hepsi
gerçek HTTP çağrısıyla, trigger zinciri geri alınan transaction'la
doğrulandı; uçtan uca teyit ilk gerçek kayıtta (ya da bir test hesabıyla)
yapılmalı — `TESTING.md` bölüm 12.

### Onaylanmamış hesap süpürmesi — hatırlat, sonra sil (23 Ağustos 2026)

**Neden — gerçek bir kullanıcıda gözlendi.** "Sel Sezer" kayıt olurken
e-postasını yanlış yazdı (`sel_eb@` yerine `sel_en@`), **47 saniye sonra**
doğru adresle tekrar kayıt oldu — ama takma adı `Sweetpain` az önce KENDİ ölü
hesabı tarafından kapılmıştı, `Sweetpain.` yazmak zorunda kaldı. **Aynı
e-posta ile iki hesap MÜMKÜN DEĞİL** (`users_email_partial_key`); mesele
takma ad rezervasyonuydu — `profiles_display_name_tr_lower_key` hiç
onaylanmamış bir hesabın adını da süresiz tutuyor. (O gün elle çözüldü: boş
hesap silindi, ad düzeltildi, üye 38 → 37.)

**Ölçüldü:** 37 üyenin **3'ü** hiç onaylanmamış, ikisi **26/28 gündür** öyle —
linkleri 680/632 saat önce ölmüş, bir daha asla onaylanamazlar ama adları
(`H56`, `Cacan`) rezerve. Onaylanmamış hesabı süpüren HİÇBİR mekanizma yoktu
(iki mevcut cron job'un ikisi de yalnızca bildirim gönderiyor).

| Zaman | Ne olur |
|---|---|
| 0. saat | Kayıt, onay maili gider (link **24 saat** geçerli) |
| ~20. saat | **Tek seferlik hatırlatma** — TAZE link + "24 saat içinde tamamlamazsan hesabın silinecek" |
| 48. saat | Hâlâ onaysızsa **hesap silinir**; e-posta ve takma ad serbest kalır |

**İlke: hatırlatma aralığı = linkin ömrü.** Böylece kutuda HER AN geçerli bir
link bulunur (0-24 ilk mail, 24-48 hatırlatma). İlk taslak 3 gün/7 gündü ve
24-72. saatler arasında **ölü bölge** bırakıyordu — kullanıcı yakaladı.

**⚠ CRON SAATLİK OLMAK ZORUNDA** (`25 * * * *`; dakika :25, öteki iki cron'la
çakışmasın diye). Günlüğe çekilirse ölü bölge geri gelir: 12:00'de kayıt olanı
ertesi gün 11:00'de kontrol edersen henüz 23 saatliktir, atlanır ve hatırlatma
47. saatte gider — oysa ilk link 24. saatte ölmüştür. Hatırlatma tam bu yüzden
eşiğin (24s) BİRAZ ÖNCESİNDE (~20s) atılıyor: iki linkin geçerlilik aralığı
üst üste binsin.

**⚠ `net.http_post` timeout'u 60 sn (varsayılan 5 sn DEĞİL).** Bu proje aynı
tuzağa bir kez düştü (`welcome_email_http_timeout`): soğuk başlangıç 5 sn'yi
aşıp isteği düşürmüştü. Bu fonksiyon ayrıca N kullanıcı için SIRAYLA link
üretip mail gönderiyor.

**Kimse uyarılmadan silinmez — silme ÜÇ koşulun hepsini ister:** onaysız ·
hatırlatma gönderilmiş (`profiles.confirm_reminder_sent_at` dolu) · o
damgadan bu yana 24 saat geçmiş. Yan fayda: bir Brevo kesintisi artık silmeyi
BLOKLAR (hatırlatma gidemezse damga da konmaz), sessizce kullanıcı kaybettirmez.
Kural kullanıcının isteğinden doğdu — 26/28 günlük iki eski hesaba da önce
hatırlatma gönderildi ("belki geri kazanırız"), sistem sonra silsin diye.

**Ölçülen teknik zemin** (üretimde, geçici bir Edge Function ile — sonra
etkisiz hâle getirildi): yönetici `generateLink({type:'signup'})` çağrısı
onaylanmamış bir hesap için taze `action_link` + `hashed_token` DÖNDÜRÜYOR
(`verification_type: signup`); o jetonla doğrulama **oturum açıyor** ve
`email_confirmed_at`ı dolduruyor → **tek mail, tek tık, direkt içeri**; ve
**kendi başına mail ATMIYOR** (çağrı **42 ms**, auth loglarında gönderim kaydı
yok). Zorunlu `password` parametresi MEVCUT parolayı EZMİYOR — varsayılmadı,
üretimde ölçüldü (eski parola `EVET`, üretilen geçici parola `HAYIR`).
Kullanıcının tıklaması da canlıda doğrulandı: hatırlatma 19:35:42 →
`email_confirmed_at` **ve** `last_sign_in_at` 19:38:08 (aynı an).

**Neden Supabase'in kendi "onay mailini yeniden gönder" akışı DEĞİL:** stok
şablon "hesabın silinecek" diyemez, ve markalı bir ara sayfadan yeniden
göndermek kullanıcıyı iki mail + iki tıklamaya sokardı. Kullanıcı bu git-geli
açıkça reddetti; tek mail/tek tık yukarıdaki ölçümle mümkün olduğu için
seçildi.

**⚠⚠ `Email OTP expiration` 3600 → 86400 (24 saat) yapıldı** (Dashboard →
Authentication → Sign In / Providers → Email; Dashboard ayarı olduğundan
repoda/migration'da HİÇ izi yok, kaydı yalnızca burada). **Bu şemanın
temeli** — 1 saate dönerse hatırlatma maili neredeyse hep ölü link taşır ve
kimse fark etmez. Supabase bunu `auth_otp_long_expiry` (**WARN**) olarak
işaretliyor ve bu uyarı BİLİNÇLİ kabul edildi (ölçüldü: değişiklikten önce
denetimde YOKTU, sonra ÇIKTI). **Bir sonraki oturum `get_advisors` çıktısını
temizlemek için 3600'e geri çekmesin.** Bedeli dürüstçe: ayar paylaşımlı,
**şifre sıfırlama linki de** 24 saat yaşıyor; 7 gün BU YÜZDEN reddedildi —
"Require current password when updating" KAPALI olduğundan (ölçüldü) o link
tam hesap devralma yolu.

**Silme guard'ı — ilk sürüm FAZLA GENİŞTİ ve prova modu yakaladı.** Varsayım
"onaysız + hiç giriş yapmamış hesabın verisi olamaz" idi; prova çıktısı
`verisiOlduguIcinAtlanan: ["canangecmen@gmail.com"]` dedi. Sebep: onaylanmamış
hesaplar arkadaş aramasında GÖRÜNÜYOR, biri ona istek göndermişti. Guard artık
yalnızca hesabın KENDİ oluşturduğu kaydı sayıyor (`games`, `local_game_saves`,
gönderdiği `friend_requests`); gelen referanslar cascade ile gideceğinden
yalnızca `cascadeOlacakGelenKayit` diye raporlanıyor. **Ders: "bu durumda veri
olamaz" bir gerekçe değil bir varsayım — otomatik silmede prova modu şart.**

**Yakalanan tuzak:** `admin.createUser` metadata'sız çağrılırsa
`profiles_first_name_not_blank` kısıtına takılıp `Database error creating new
user` verir — sunucudan hesap yaratan her kod gerçek bir kaydı taklit edip
ad/soyad göndermek zorunda.

**Yan bulgu:** bu akış `notify-welcome` zincirini de tetikledi ve
`{"ok":true,"sent":true}` döndü — `TESTING.md` bölüm 12'de "gerçek gönderim
test edilmedi" diye duran madde böylece üretimde kanıtlandı.

**Parçalar:** `profiles.confirm_reminder_sent_at`
(`20260823190529_confirm_reminder_sent_at`), Edge Function
`sweep-unconfirmed-accounts` (`verify_jwt: false` — cron çağırıyor, JWT yok;
`deploy_edge_function`e bu değer AÇIKÇA geçilmeli, bkz. o bölümdeki kayıtlı
tuzak), cron `20260823193949_sweep_unconfirmed_accounts_cron`. Eşikler
fonksiyonun başındaki üç sabitte (20s / 48s / hatırlatmadan sonra 24s) —
biri değişirse hukuki metin de değişmeli. Elle kontrol listesi:
`TESTING.md` bölüm 18.

**Hukuki metin AYNI PR'da:** `src/legal/LegalContent.tsx` 5. bölüme saklama
cümlesi + portun `legal_modals.dart`'ı (`legal_text_test.dart` "Son
güncelleme" tarihlerini karşılaştırıyor, port bayat kalsa mobil CI düşer).

**HENÜZ ÖLÇÜLMEDİ:** onaysız hesap dururken aynı e-postayla **yeniden kayıt**
denenirse ne oluyor? Supabase'in onay mailini yeniden göndermesi beklenir —
öyleyse tamamen kendi kendine işleyen ÜÇÜNCÜ bir kurtarma yolu var demektir.
Varsayma, ölç.

**Bilinçli olarak YAPILMAYAN:** admin Üyeler tablosuna "onaylanmamış" filtresi
— kullanıcı onayladı ama "hemen canlıya alalım" kapsamının dışında kaldı,
kendi maddesi olarak `ROADMAP.md`'de duruyor.

**Bounce (geri dönen mail) görünürlüğü de YAPILMADI ve bu artık bir varsayım
değil ÖLÇÜM:** uygulama bir mailin bounce ettiğini HİÇ bilmiyor, tek kaynak
Brevo panelindeki gönderim logu — ve o panelde **1-23 Ağustos 2026 arasında
TOPLAM 1 bounce** var (büyük olasılıkla bu bölümü doğuran yanlış-adres
vakasının kendisi). Yani webhook + tablo + admin görünürlüğü kurmanın bedeli,
kapatacağı soruna göre orantısız; üstelik yanlış adresin asıl sonucu (ölü
hesabın takma adı kilitlemesi) yukarıdaki süpürmeyle zaten çözüldü. **Bir
sonraki oturum bunu "eksik" diye açmasın** — koşul şu: Brevo panelinde bounce
oranı görünür biçimde artarsa (ör. haftada birkaç), o zaman ölç ve yeniden
değerlendir.

### Davet sayfası zenginleştirildi (25 Ağustos 2026, kullanıcı isteği)

Kullanıcı `/davet/:token` ekranının ekran görüntüsünü gönderip *"bu ekranı biraz
daha zenginleştirelim"* dedi. Öncesinde sayfa **logo + tek cümle + iki düğme**
idi: 390×844'lük bir telefonda ekranın alt üçte ikisi boştu ve linke tıklayan
kişi — tanım gereği Kelimeki'yi HİÇ bilmeyen biri — "Kayıt Ol"a basmadan önce
neye kayıt olduğunu gösteren tek bir şey göremiyordu. Bu, büyümenin ASIL kanalı
olan yüzey (`FriendsModal`'ın davet linki, `?ref=arkadas`) için ölçülebilir bir
kayıp: dönüşüm tamamen "arkadaşım göndermiş" güvenine kalıyordu.

Eklenenler (`FriendInvitePage.tsx`):
- **Davet kartı** — davet edenin baş harf avatarı (`Avatar`), "ARKADAŞLIK DAVETİ"
  üst başlığı, mevcut cümle (artık `h1`) ve tek bir **"Daveti Kabul Et"** düğmesi.
- **"Kelimeki nedir?" bölümü** — kısa tanıtım metni, GERÇEK tanıtım tahtası,
  X2/X3 açıklama rozetleri, dört özellik kutusu ve alt CTA (aynı etiket).
- **Hukuki alt şerit** (`Setup.tsx`'in footer'ıyla aynı iki katmanlı yapı) —
  paylaş linki BİLEREK yok: bu sayfadaki kişi henüz üye değil, davet edilen taraf.
- **`error` dalı artık çıkmaz değil**: "tekrar dene" yazıyordu ama tekrar
  denemenin tek yolu sayfayı yenilemekti; "Tekrar Dene" düğmesi durumu `ready`e
  döndürüp kabul effect'ini yeniden tetikliyor. Aynı şekilde `invalid` dalına da
  "Kelimeki'ye Git" düğmesi eklendi.

**Tanıtım içeriği karşılama katmanıyla TEK KAYNAK:** tahta
`src/landing/demoBoard.ts`ten (her kelimesi `npm run verify-demo-board` ile
sözlüğe karşı doğrulanıyor), ikonlar `src/landing/OzellikIkonlari.tsx`ten,
X2/X3 rozetlerinin zeminleri ise `Board.tsx`in `GOLD_ZONE_STYLE`/
`CENTER_ZONE_STYLE` sabitlerinden (bu iş sırasında `export` edildiler) geliyor.
İkinci bir tanıtım tahtası çizmek ya da renk kodunu elle yazmak bu kod
tabanının en sık tekrarlayan hata sınıfı olurdu. Buna karşılık **kelime sayısı
gibi rakamlar bilerek yok**: `KELIME_SAYISI` sabiti `Landing.tsx`in İÇİNDE ve o
dosyayı import etmek tüm karşılama katmanını uygulama paketine sokardı; elle
yazmak ise üçüncü bir kopya demekti.

**İkinci tur — TEK DÜĞME (aynı gün, kullanıcı isteği):** *"En üstteki
arkadaşlık davet kutusundaki buton altındaki yazıları tamamen kaldır. Tek buton
'Daveti kabul et' olsun. Alttaki buton da aynı."* İlk sürümde kartta yan yana
"Giriş Yap"/"Kayıt Ol" ve altlarında iki blok açıklama vardı (bir ipucu cümlesi
+ "kabul edince ne olur" üç maddesi); üçü de kaldırıldı, iki düğme tek bir
**"Daveti Kabul Et"**e indi ve sayfanın altındaki CTA da aynı etiketi aldı.
Gerekçe: ziyaretçiye sorulan soru hesabının olup olmadığı DEĞİL, daveti kabul
edip etmediği — hesap ayrımı zaten `AuthModal`'ın kendi işi ve orada iki yönlü
geçiş linki var ("Zaten hesabın var mı? Giriş yap"), yani üye olan biri de tek
düğmeden ilerliyor (tarayıcıda doğrulandı). Aynı işi yapan iki düğmenin iki
farklı ad taşıması da bir okuma yükü. Kart 409 → 240 px'e, sayfa 1541 → 1371
px'e indi.

**Ölçümler** (Chromium, 390×844, davet RPC'si sahte bir adla mock'lanarak, ilk
tur): sayfa 844 → 1541 px; 320/390/1280 px genişliklerin hiçbirinde yatay taşma yok;
uzun bir ad (`Ayşegül Karahanoğlu`) düzeni bozmuyor. Paket maliyeti
`dist/assets/boot-*.js` 800.94 → 808.77 KB ham, 228.50 → 230.98 KB gzip.

**Tanıtım bölümü yalnızca GİRİŞSİZ ziyaretçiye çıkıyor** (`showPitch = !user`):
girişli biri zaten üye, onun için sayfa bir saniyelik ara durak (davet otomatik
işleniyor), oyunu anlatmak gürültü olurdu.

**Flutter portu ETKİLENMEDİ:** portta `/davet` diye bir sayfa yok — davet
token'ı `friend_invite_inbox.dart` üzerinden kuyruğa giriyor ve `setup_screen`
girişsizken tek satırlık bir önizleme diyaloğu gösteriyor (bkz. oradaki not).
İleride o diyaloğu zenginleştirmek istenirse bu bölüm referans, ama bugün iki
platform bilinçli olarak FARKLI yüzeyler kullanıyor.

**Regresyon:** duman testi (`tests/smoke.spec.ts`, `/davet/:token` testi) artık
"Kelimeki nedir?" başlığını ve `role="img"` tanıtım tahtasını da arıyor — import
zinciri koparsa ya da bölüm sessizce düşerse orada yakalanır. Elle koşulacak
liste: `TESTING.md` → "21. Davet sayfası".

### İşlemsel e-posta bildirimleri (arkadaşlık isteği + Canlı oyun daveti)

29 Temmuz 2026'da eklendi (`notify-friend-request`/`notify-game-invite` Edge Function'ları). Kullanıcının gözlemi: hem arkadaşlık isteği hem Canlı oyun daveti yalnızca uygulama-içi bir rozetle görünüyordu (`UserMenu`'deki "Arkadaşlar" rozeti / Setup'taki "Arkadaşınla (N)"); alıcı uygulamayı hiç açmazsa bundan tamamen habersiz kalıyordu — Canlı oyun davetinde bu daha da vahimdi çünkü `online_game_invite_expiry` (7 gün) daveti sessizce iptal ediyordu, kişi kaçırdığının farkına bile varamıyordu. Bunlar **işlemsel (transactional) bildirimlerdir, `marketing_consent`'e (kayıt formundaki opsiyonel pazarlama onayı) bağlı DEĞİLDİR** — Kelimeki'nin kendi tanıtım/promosyon içeriği değil, alıcının hesabına gelen somut, kişiye özel bir olayı (birinin ona istek/davet göndermesini) bildiriyorlar; tıpkı şifre sıfırlama ya da geri bildirim yanıtı maili gibi.

- **`supabase/functions/notify-friend-request/`** — `sendFriendRequest` (`src/lib/api.ts`) `friend_requests`'e insert'ten hemen sonra, insert sonucu hâlâ `'pending'` ise (karşılıklı otomatik kabulle `handle_friend_request_insert` trigger'ı tarafından anında `accepted`'a çevrilmediyse) çağrılır. Fonksiyon çağıranın kendi JWT'siyle `friend_requests`'te gerçekten böyle bir `pending` satır olduğunu doğrular (RLS `friend_requests_select_own` yalnızca ilişkinin taraflarına izin verdiğinden keyfi bir alıcıya mail atılamaz), sonra service-role bir client'la (`play-ai-turn`'deki aynı ayrım — `auth.users` hiçbir client rolüne hiç açılmaz) alıcının e-postasını ve iki tarafın `profiles.display_name`/`first_name`'ini okuyup Brevo Transactional API ile gönderir.
- **`supabase/functions/notify-game-invite/`** — `createOnlineGame` (`src/lib/api.ts`) `create_online_game` RPC'si başarılı döndükten hemen sonra `online_game_id`'yi geçerek çağrılır. Fonksiyon çağıranın gerçekten o oyunun kurucusu (`created_by`) olduğunu doğrular, sonra service-role bir client'la o oyundaki TÜM `pending` `game_invites` satırlarını (4 kişilikte birden fazla olabilir) tarayıp her birine ayrı bir e-posta gönderir — döngü sıralı (`for...of`), Brevo'ya art arda tek tek istek.
- **Best-effort/fire-and-forget:** Her iki Edge Function da istemciden `void notifyFriendRequest(...)`/`void notifyGameInvite(...)` ile çağrılır (`src/lib/api.ts`) — arkadaşlık isteği/Canlı oyun daveti zaten sunucuda başarıyla oluşmuş olduğundan, bir e-posta gönderim hatası (Brevo kesintisi, `BREVO_API_KEY` eksikliği vb.) kullanıcıya hiç yansıtılmaz, yalnızca `console.error` ile loglanır. Aynı sebeple her iki fonksiyon da "yumuşak" başarısızlık durumlarında (istek zaten `pending` değil, alıcının e-postası bulunamadı, Brevo hatası) 200 OK + `{ok:true, sent:false}` döner — gerçek 4xx/5xx yalnızca auth/yetki/girdi hatalarında.
- **`invokeEdgeFunction`** (`src/lib/api.ts`, eski adıyla `invokeAdminFunction`) — bu iki yeni fonksiyon admin'e özgü olmadığından (herhangi bir oturum açmış kullanıcı çağırabilir), ortak yardımcı jenerik bir isme yeniden adlandırıldı; `sendFeedbackReply`/`sendMemberMessage` çağrıları da güncellendi, davranışta değişiklik yok.
- **Kapsam dışı bırakılan:** Canlı oyun DAVETİ (`online_game_invite_expiry`'nin 7 günlük penceresi) için süre dolmadan önce bir hatırlatma maili hâlâ yok — yalnızca arkadaşlık isteği için aşağıdaki (1 Ağustos 2026) 3 günlük tek seferlik hatırlatma eklendi, Canlı oyun davetine henüz uygulanmadı. `respond_to_game_invite`/`removeFriend` gibi durum DEĞİŞİKLİKLERİ (kabul/red/arkadaşlıktan çıkma) için de e-posta yok — yalnızca YENİ bir istek/davet açıldığında gönderiliyor.
- **Kullanıcı metni HTML'e gömülmeden ÖNCE kaçılır; kalan tek pencere alıcının e-posta İSTEMCİSİ (15 Ağustos 2026, kullanıcı sorusu üzerine denetlendi — kod DEĞİŞTİRİLMEDİ):** Kullanıcı, "sohbette/Görüş Bildir'de yazılan linkler tıklanabilir olmamalı" diye sordu. Denetim doğruladı ve iki katman ayrı ayrı ölçüldü.
  - **Uygulama içi: hiçbir yerde tıklanabilir DEĞİL, üstelik yapısal olarak.** `src/` altında `dangerouslySetInnerHTML` HİÇ kullanılmıyor (yani kullanıcı metni hiçbir yerde HTML olarak yorumlanamaz) ve linkleştirme (autolink) kodu hiç yazılmadı; sohbet balonu düz bir JSX metin düğümü (`{m.message}`), Flutter tarafı düz `Text(m.message)` — `Linkify`/`launchUrl` yok. Geri bildirim metni de admin panelinde aynı şekilde düz metin. Biri `<a href="…">` yazsa ekranda o etiketin kendisi görünür. **Yeni bir mesaj/serbest metin yüzeyi eklenirken bu iki değişmez korunmalı.**
  - **E-posta: kullanıcı kontrollü HER alan `escapeHtml`'den geçiyor** (`_shared/email.ts`) — `display_name`, davet/istek gönderenin adı, geri bildirim metni, admin yanıtı; `<` → `&lt;` olduğundan enjekte edilmiş bir bağlantı e-postada da doğmuyor. Konu satırı gövdenin aksine `escapeHtml`'e tabi olmadığından ayrı bir `sanitizeForSubject` var (gerekçesi o fonksiyonun kendi yorumunda: biri adını "ÜCRETSİZ KAZANDIN TIKLA" yapıp GERÇEK `noreply@kelimeki.com` adresinden gelen bir mailin konusunda gösterebiliyordu — marka güvenilirliğini istismar eden bir phishing vektörü).
  - **KAYDA GEÇEN KALINTI — takma isim, alıcının istemcisinde tıklanabilir hale gelebilir (kullanıcı kararı: "şimdilik değiştirme").** Gmail/Apple Mail gibi istemciler DÜZ METİN içindeki `evil.com` gibi ifadeleri kendileri linkleştirir. Bizim HTML'imiz bağlantı üretmiyor, ama istemci render ederken üretebilir. Teorik olarak iki yer: (1) `feedback-reply`, kişinin kendi mesajını ona geri alıntılıyor — olası bağlantıyı yalnızca onu YAZAN kişi görür, pratik risk yok; (2) **`display_name`**, arkadaşlık/davet maillerinde KARŞI TARAFA gösteriliyor (`<strong>${escapeHtml(inviterName)}</strong>`) — boşluk yasak (`display_name_no_whitespace`) ve istemcide `maxLength={10}`, yani `evil.com` gibi kısa bir alan adı sığar. Vektör dar (10 karakter, boşluksuz, alıcı zaten o kişiden davet bekliyor) ve gerçek bir açık DEĞİL — bir istemci davranışı. Kapatılmak istenirse seçenekler: mail gövdesinde noktalı bir takma ismi maskelemek, ya da adı `<strong>` ile vurgulamadan yazmak. **Bir daha denetlenirse "bu neden düzeltilmemiş?" sorusunun cevabı budur** — bilinçli, kullanıcı onaylı bir kabul.
- **Marka şablonu (29 Temmuz 2026):** İlk sürümde bu iki fonksiyonun (ve `feedback-reply`/`admin-send-message`'ın) HTML'i düz metin+buton (`-apple-system` font, kart/logo yok) idi — kullanıcı gerçek bir şifre sıfırlama mailiyle (Supabase Auth şablonu, `supabase/email-templates/reset-password.html` — logo header + beyaz kart + footer) karşılaştırınca tutarsızlığı fark etti. `_shared/email.ts`'e reset-password.html'in kart yapısını birebir tekrarlayan bir `buildBrandedEmailHtml(title, bodyHtml)` eklendi (logo `https://kelimeki.com/email-logo.png`, kart `#DCE2EA` çerçeve/`16px` radius, buton `#2563EB`, footer metni `#8A93A2`) — dört Edge Function'ın da (`notify-friend-request`, `notify-game-invite`, `feedback-reply`, `admin-send-message`) gövde üreten fonksiyonları artık düz `<div>` yerine bu wrapper'ı çağırıyor; `buildNoreplyNoticeHtml`'in renkleri de aynı palete (`#DCE2EA`/`#8A93A2`/`#2563EB`) çekildi. Auth şablonları (Dashboard'da yaşıyor) bu wrapper'ı otomatik paylaşamıyor — reset-password.html değişirse bu wrapper da elle senkronize edilmeli, aksi halde tekrar sapabilirler.
- **Arkadaşlık isteği hatırlatma e-postası (1 Ağustos 2026, `notify-friend-request-reminders` Edge Function'ı):** Kullanıcı gözlemi — yukarıdaki anlık bildirimden sonra alıcı yanıtlamazsa istek sessizce unutulup gidiyordu. Sohbet sırasında expire etmenin de aynı sonucu verdiği (tek fark gönderenin iptal edip tekrar gönderebilmesi) netleşince, çözüm olarak expire yerine bir hatırlatma tercih edildi. `friend_requests`'e eklenen `reminder_sent_at` (nullable, `friend_request_reminder_column` migration'ı), bir istek 3 gün cevapsız kalınca gönderilen TEK SEFERLİK hatırlatmanın zamanını tutar — `deadline_warning_sent_at` ile birebir aynı desen (`is(..., null)` filtreli atomik UPDATE ile "iddia edilir", tekrar tekrar tetiklenmesi zararsız, en fazla bir kez mail gider). Cancel (satır tamamen silinir) ve resend (yeni satır, bu alan yeniden null) sayacı doğal olarak sıfırlar — `online_game_states`/`local_game_saves`'in aksine ayrı bir reset trigger'ı gerekmedi. **Projedeki İKİNCİ pg_cron job'u** — `deadline_warnings_cron`'un 15 dakikalık hassasiyetinin aksine (24-48 saatlik dar pencereler için gerekliydi), burada gün bazlı bir eşik (3 gün) yeterli olduğundan AYRI, günlük bir cron'a bağlandı (`0 8 * * *` ≈ 11:00 İstanbul, `friend_request_reminders_cron` migration'ı). `verify_jwt: false` — `notify-deadline-warnings` ile aynı gerekçe (cron çağırıyor, kullanıcı JWT'si yok). E-posta metni bilinçli olarak isme doğrudan iyelik eki eklemiyor ("XYZ'nin ... isteği" DEĞİL, "XYZ tarafından gönderilen ... istek") — takma isimler keyfi olduğundan Türkçe ünlü uyumu programatik garanti edilemiyor (bkz. "Sıra: {isim}" dersi, Canlı Oyun — Faz 3). **Deploy notu:** `notify-deadline-warnings`'teki aynı import-yolu tuhaflığı burada da tekrarlandı — ilk denemede `'../_shared/email.ts'` "Module not found" hatası verdi, `'./_shared/email.ts'`e geçilince sorunsuz deploy oldu (kesin sebep hâlâ netleştirilmedi). Query/atomik-iddia mantığı disposable, backdated bir test satırıyla doğrulandı — gerçek bir kullanıcıya fabrike bir bildirim gitmesin diye Brevo'ya gerçekten gönderim YAPILMADI, yalnızca SQL seviyesinde "due" sorgusu ve `is(reminder_sent_at, null)` filtreli UPDATE'in ikinci çağrıda no-op döndüğü (mükerrer gönderim koruması) test edilip temizlendi. Migration uygulandığı anda production'da 3 günden eski bekleyen gerçek bir istek yoktu.
