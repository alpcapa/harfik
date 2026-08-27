# Uygulama İçinden Hesap Silme (25 Ağustos 2026)

ROADMAP madde 2 — **MAĞAZA BLOKERİ** ve listedeki tek **GERİ DÖNÜŞSÜZ** iş.
Apple 5.1.1(v) ve Google'ın veri silme şartı, hesap açtıran uygulamalarda
uygulama İÇİNDEN başlatılabilen bir silme yolu istiyor. Hukuken zorunlu
değil (KVKK m.7/m.11 ve GDPR m.17 hak verir, buton şart koşmaz) — bu madde
**mağaza kapısı** için var.

**İki ayrı yüzey, karıştırma:**

| Yüzey | Ne | Kim ister |
|---|---|---|
| `kelimeki.com/hesap-silme/` | Statik sayfa; giriş yapamayanlar için TALEP kanalı (Görüş Bildir), 30 gün | Play'in **Data safety** formu bir web silme talep URL'i istiyor |
| Hesap Ayarları › **Hesabımı Sil** | İşi GERÇEKTEN yapan yol; onaylandığı anda uygulanır | Apple 5.1.1(v) + Play'in "hesap açtıran uygulama" kuralı |

---


## ⛔ ASLA SİLİNMEYECEK İKİ HESAP

Bu iki satır ROADMAP madde 4'te (test hesabı temizliği) duruyordu; madde
26 Ağustos 2026'da kullanıcı kararıyla kaldırıldı (*"gerekirse daha sonra
hesabımı silden ben yaparım, önemli bir konu değil"*). Kaydın kendisi
KALDI, çünkü bir temizlik/toplu işlem sırasında yanlışlıkla silinmelerinin
bedeli geri alınamaz:

| Hesap | Neden dokunulmaz |
|---|---|
| **T2** | Play Console **App access** formunda incelemeciye verilen hesap. Silinirse mağaza incelemesi uygulamaya giremez. |
| **Ironman** | Hesap sahibinin gerçek ana/admin hesabı (14 Ağustos 2026). |

Kalan test hesapları (T3, T5) bilerek duruyor; gerekirse sahibi uygulama
içindeki "Hesabımı Sil" ile kendisi siler. Büyüme metriklerini bir miktar
kirletmeleri kabul edildi.


## Mimari

```
İstemci (web AccountSettingsModal / port account_settings_modal)
   └─ DeleteAccountModal  ──►  delete-my-account (Edge Function, verify_jwt: TRUE)
                                  │  çağıranın KENDİ JWT'si → auth.getUser() → uid
                                  │  (istemci bir kullanıcı kimliği GÖNDERMEZ)
                                  ├─ service-role ► public.delete_account_cascade(uid, dryRun)
                                  ├─ storage.from('avatars').remove(<uid>/…)
                                  └─ auth.admin.deleteUser(uid)
```

`delete_account_cascade` **kullanıcıya açık değil**: `authenticated`/`anon`
rollerinden execute yetkisi geri alındı, yalnızca `service_role` çağırabiliyor
(canlıda doğrulandı: `proacl` = `postgres=X | service_role=X`). Bir uuid
parametresi alıp o kullanıcının her şeyini silen bir fonksiyon, RLS'in
koruyamayacağı bir yüzeydir.

**Kuru çalıştırma tesadüfi değil, tasarımın parçası:** `dryRun` **aynı**
fonksiyonun bayrağı, ayrı bir "önizleme sorgusu" değil. Yani kullanıcıya
gösterilen sayılar, sunucunun uygulayacağı planın ta kendisi. Onay penceresi
açılır açılmaz bunu çağırıyor; **kuru çalıştırma düşerse silme butonu
etkinleşmiyor** (sunucuya ulaşılamıyorsa ya da hesap silinemez bir hesapsa
butonu açmak yanlış bir söz verir).

---

## Verilmiş karar: kendi kayıtları SİLİNİR, başkalarınınki ANONİMLEŞİR

Kullanıcı kararı (25 Ağustos 2026: *"Anonimleştirme mantıklı"*).

| Satır | Ne oluyor |
|---|---|
| Silinen kişinin **kendi** `games` satırları | **SİLİNİR** — istatistikleri de böyle gider, amaç bu |
| **Başkalarının** `games` satırları | **KORUNUR**, jsonb'deki adı `Silinmiş oyuncu` olur (hem `players` hem `messages`) |

**"Rakiplerin puanı uçar mı?" — HAYIR, ölçüldü.** `games` oyun başına değil
**oyuncu başına bir satır** tutuyor ve `player_stats_overall` bir VIEW olarak
`FROM games g … GROUP BY user_id` yapıyor. Herkesin puanı YALNIZCA kendi
satırlarından hesaplanıyor. Oyun geçmişi ekranı da bakan kişinin KENDİ
satırındaki snapshot'ı okuduğundan liste bozulmuyor.

### Anahtar KOLTUK İNDEKSİ, ad DEĞİL — ve bu ölçüldü

Snapshot'ın alanları `name`, `score`, `colorIndex`, `is_ai`, `surrendered` —
**`user_id` YOK** (`messages` de aynı: `name` + `colorIndex` + `message`).
Ada göre eşleştirmek ad çakışmasında ve sonradan yapılan ad
değişikliklerinde YANLIŞ kişiyi anonimleştirir.

Doğru anahtar: `online_games.slots[i].user_id` ↔ `colorIndex = i`. Bu
değişmez projede zaten yazılı ve ikinci kez kullanılıyor — birincisi
`chat_flags_for_finished_game` (`person_scoped_chat_moderation`
migration'ı): *"colorIndex, init_online_game_state'te `i % 4` ile atanır ve
oyuncu sayısı en fazla 4 olduğundan koltuk indeksiyle BİREBİR aynıdır"*.

⚠ **Tuzağın gerçekleştiği KANITLANDI (canlı, kuru çalıştırma).** `T1`
hesabının anonimleştirilecek 11 satırı tek tek okundu: 10'unda koltuktaki ad
`T1`, birinde **`AlpTEST`** — yani hesabın SONRADAN değiştirilmiş ESKİ adı.
Ada göre eşleştiren bir uygulama o satırı sessizce atlar ve silinen kişinin
eski adı başkasının kaydında sonsuza dek kalırdı. Koltuk eşlemesi yakaladı.

---

## "Zaten cascade eder" varsayımı İKİ yerde yanlış çıktı

Bu projede o varsayım daha önce iki kez yanlış çıkmıştı (`CountBadge` rozet
zinciri, `check_invite_expiry` filtreleri); burada üçüncü ve dördüncü kez.

**1. `online_games.created_by` → `on delete CASCADE` idi.** `auth.users`
satırını silmek, o kişinin AÇTIĞI **bitmiş** oyunları da silerdi; bu da
`games.online_game_id`'yi (SET NULL) koparıp ÖTEKİ oyuncunun sohbet arşivi
rozetlerini (`chat_flags_for_finished_game`) ve o oyunun hamle/mesaj
kayıtlarını yok ederdi — yani "başkasının verisine dokunma" kuralını
sessizce çiğnerdi. Migration bunu **SET NULL**'a çevirdi (kolon nullable).
RLS karşılaştırmaları (`created_by = auth.uid()`) null'da eşleşmediğinden
gevşeme yok; `list_my_online_games`'in `case when created_by = auth.uid()
then 'creator' else 'invitee'` dalı da doğru sonucu verir.

**2. Dört tablonun FK'si NO ACTION** (ne cascade ne set null) — temizlenmezse
`auth.admin.deleteUser` doğrudan FK ihlaliyle **düşer**:

| Tablo | Kolon(lar) | Null? | Ne yapılıyor |
|---|---|---|---|
| `online_game_messages` | `sender_user_id` | NOT NULL | satır **silinir** |
| `online_game_moves` | `player_user_id` | NULLABLE | **SET NULL** — hamle geçmişi ötekinin oyun kaydının parçası, satır kalır |
| `online_game_message_mutes` | `muter_user_id`, `muted_user_id` | ikisi de NOT NULL | satır **silinir** |
| `online_game_chat_reports` | `reporter_user_id`, `reported_user_id` | ikisi de NOT NULL | satır **silinir** |

Ayrıca `games.user_id` ve `feedback.user_id` **SET NULL** olduğundan o
satırlar `auth.users` silinse bile KALIRDI — ikisi de açıkça siliniyor.

---

## Devam eden oyunlar

Koltuğu boşalan bir oyun oynanamaz. Kural: kişinin katıldığı (ya da açtığı)
bir `online_games` satırı, o oyuna ait **hiçbir `games` satırı yoksa** (yani
oyun hiç bitmemiş, kimsenin dondurulmuş kaydı yok) SİLİNİR — bütün çocuk
tabloları CASCADE ile gider. Bitmiş oyunlar KORUNUR.

Böylece "başkasının bitmiş oyun kaydı silinmez" kuralı duruyor, yarım oyun
da ortada asılı kalmıyor. Statüye (`pending`/`active`/`abandoned`) değil
`games` satırının VARLIĞINA bakılıyor — statü sözlüğü değişse de kural tutar.

---

## Bilinçli olarak DOKUNULMAYANLAR

- **`game_finishes.user_id` → SET NULL.** Huninin süre/oyuncu sayısı ölçümü
  kimliksiz kalıyor; tablonun kendi tasarımı bu.
- **`guest_visits` / `device_visits` / `game_starts` / `client_errors`** —
  hesapla HİÇ ilişkilendirilmiyor (`anon_id`), Gizlilik Politikası'nın 6.
  bölümü bunu zaten böyle anlatıyor.
- **`online_games.slots` içindeki uuid.** `auth.users` ve `profiles`
  gittikten sonra o değer hiçbir kişiye çözülemez, ama koltuk eşlemesi
  ötekinin arşivi için gerekli.
- **Silme onayı e-postası YOK.** Projenin *"KİMSE UYARILMADAN SİLİNMEZ"*
  ilkesi (`sweep-unconfirmed-accounts`) SİSTEMİN başlattığı silme içindir;
  burada silmeyi kişinin kendisi başlatıyor ve önünde iki onay adımı var.

---

## Kullanım Koşulları da güncellendi (ikinci turda)

İlk turda Koşullar'a DOKUNULMAMIŞTI ve gerekçesi ölçülmüştü: metnin tamamı
"sil" için tarandığında tek eşleşme §4'ün *"hesabınız … askıya alınabilir
veya silinebilir"* cümlesiydi — o BİZİM hesabı kapatma hakkımız, kullanıcının
kendi hesabını silmesi değil; yani yanlış hâle gelen bir cümle yoktu ve
mağaza şartı da Koşullar'ı istemiyor.

Kullanıcı yine de istedi (25 Ağustos 2026) ve §2 Hesap Sorumluluğu'na tek bir
cümle eklendi: *"Hesabınızı dilediğiniz zaman Hesap Ayarları'ndan kendiniz
silebilirsiniz; silme kalıcıdır ve geri alınamaz, kapsamı Gizlilik
Politikası'nın 5. bölümünde açıklanmıştır."* Gerekçe: yalnızca Koşullar'ı
okuyan biri bu yolu hiç öğrenmiyordu.

⚠ **Bedeli önceden söylenmişti ve gerçekleşti:** Koşullar'ın "Son güncelleme"
tarihini oynatmak portun `legal_modals.dart`'ını ZORUNLU kılıyor
(`legal_text_test.dart` İKİ tarihi de karşılaştırıyor), yani yeni bir mobil CI
turu ve **yeni bir `.aab`**. Metin değişikliği ucuz değil; hukuki metne
dokunmak her zaman bir paket turudur.

---

## Atomiklik sınırı (bilinçli)

İki adım var: (1) RPC public şemayı **tek işlemde** temizler, (2)
`auth.admin.deleteUser` hesabı siler. Sıra ters çevrilemez — yukarıdaki NO
ACTION tablosu yüzünden temizlik yapılmadan deleteUser düşer.

(2) düşerse "veri gitti, hesap duruyor" durumu oluşur. RPC **idempotent**
(ikinci koşuda her sayaç 0 döner), yani kullanıcı butona tekrar bastığında
hesap da silinir; hata mesajı bunu açıkça söylüyor
(*"Verilerin silindi ama hesap kapatılamadı. Lütfen tekrar dene."*).

---

## Yönetici hesabı silinemez

`delete_account_cascade` `profiles.is_admin` doğruysa `P0001` ile reddediyor
(canlıda doğrulandı). Gerekçe: projede tek admin var ve `Ironman` için
*"HİÇBİR KOŞULDA SİLİNMEZ"* yazılı bir karar (ROADMAP #4). Yanlışlıkla
basılan bir butonun geri dönüşü yok; kapı sunucuda kapalı — istemci
tarafında butonu gizlemek yetmezdi.

---

## Uyarı cümlesi kırmızı + kalın (26 Ağustos 2026)

Kullanıcı T1'i silmeden hemen önce modala bakarken istedi: en üstteki
*"Hesabın ve hesabına bağlı kişisel verilerin kalıcı olarak silinir. Bu
işlemin geri dönüşü yoktur!"* cümlesi siyah/normal ağırlıktayken altındaki
sayı dökümü kadar dikkat çekmiyordu — oysa **geri dönüşsüzlüğü söyleyen tek
cümle o**. Artık `text-red font-bold` (portta `kRed` + `FontWeight.bold`) ve
sonunda ünlem var. İki istemcide birebir.

## Onay kelimesi `SİL`, karşılaştırma `trUpper`

İki istemci de kullanıcıdan `SİL` yazmasını istiyor. Karşılaştırma **`trUpper`
ile** — mobil klavyede "sil" yazan birinin native `toUpperCase()` çıktısı
"SIL" (noktasız I) olur ve eşleşme **sessizce** tutmazdı. Projenin Türkçe dil
kuralının (kök `CLAUDE.md`) bir örneği daha.

Sunucu ayrıca `confirm: 'HESABIMI SIL'` bekliyor (ASCII — HTTP gövdesinde
taşınan bir sabit, kullanıcıya hiç gösterilmiyor) ve `dryRun`ı **varsayılan
true** kabul ediyor: gövdesiz/bozuk bir `POST` asla silmez.

---

## Ölçülen kuru çalıştırma (canlı, 25 Ağustos 2026)

`T1` (`alp.capa@hotmail.com`) için — hiçbir şey yazılmadı:

```
silinecek:  games_kendi 19 · yarim_online_oyun 7 · online_game_messages 19
            online_game_chat_reports 5 · online_game_clients 6 · game_invites 10
            friend_requests 3 · local_game_saves 1 · game_likes 1 · profil 1
anonimleştirilecek: games_baskalarinin 11 · players_girisi 11 · messages_girisi 19
                    online_game_states_koltuk 10
kimliksizleştirilecek: game_finishes 9 · online_game_moves 88
eslenemeyen_games_satiri: 0
```

`eslenemeyen_games_satiri`: koltuk eşlemesi KURULAMAYAN (yani
`online_game_id` boş ama birden fazla insan oyuncu taşıyan) satırlar. Ada
göre eşleştirme YAPILMIYOR — sessizce yok saymak yerine **raporlanıyor**.
Bugün canlıda **sıfır**: çok insanlı bir oyunun `games` satırı her zaman
`online_game_id` taşıyor (ölçüldü).

---

## Dokunulan dosyalar

| Taraf | Dosya |
|---|---|
| Migration | `supabase/migrations/20260825201353_delete_account_cascade.sql` |
| Edge Function | `supabase/functions/delete-my-account/index.ts` (`verify_jwt: true`) |
| Web API | `src/lib/api.ts` → `previewAccountDeletion` / `deleteMyAccount` |
| Web UI | `src/components/DeleteAccountModal.tsx` + `AccountSettingsModal.tsx` |
| Web hukuki metin | `src/legal/LegalContent.tsx` (Gizlilik §5 **ve** Koşullar §2), `src/legal/render.tsx` (`/hesap-silme/`) |
| Port veri | `mobile/app/lib/src/data/auth_service.dart` (+ `AccountDeletionReport`) |
| Port UI | `mobile/app/lib/src/ui/auth/delete_account_modal.dart` + `account_settings_modal.dart` + `neo_button.dart` (`red` varyantı) |
| Port hukuki metin | `mobile/app/lib/src/ui/auth/legal_modals.dart` (tarih `legal_text_test.dart` ile zorlanıyor) |
| Testler | `tests/smoke.spec.ts`, `mobile/app/test/account_settings_test.dart` |

---

## Gerçek kullanım — iki hesap silindi ve ölçüldü (26 Ağustos 2026)

Kaskad artık teorik değil: **T4** ve **T1**, `alpcapa.github.io/kelimeki`
(Flutter web, sha `53e401c`) üzerinden **uygulama içi yoldan** silindi.

**T4 — duman testi.** 1 yerel YZ oyunu, başka hiçbir şey. Silme sonrası 22
referans kontrolünün hepsi sıfır; takma ad serbest.
⚠ Bir eksik kaydedildi: T4 silinirken `games` satırının İÇERİĞİ (tarih,
tahta, skor) hiçbir yere kopyalanmamıştı ve kullanıcı sonradan "hangi
oyundu" diye sorduğunda **cevap verilemedi** — kuru çalıştırma SAYI
döndürüyor, İÇERİK değil. **Ders: test amaçlı bir silmeden önce envanteri
ayrıca çıkar.** T1'de bu yapıldı (19 oyunun tarih/rakip dökümü).

**T1 — asıl test.** Kaskadın her dalı çalıştı ve beklenen ile ölçülen her
sayı tuttu:

| Ne | Beklenen | Ölçülen |
|---|---|---|
| T1'e işaret eden 22 referans (auth, profil, games, mesaj, mute, rapor, davet, arkadaşlık, ban log, `slots`, avatar…) | 0 | **0** |
| Anonimleşen `games.players` girişi | 11 | **11** |
| Anonimleşen `games.messages` girişi | 19 | **19** |
| Anonimleşen `online_game_states` koltuğu | 10 | **10** |
| Veritabanının TAMAMINDA kalan `T1`/`AlpTEST` adı | 0 | **0** |
| Ironman (oyun/galibiyet/k-lig/rütbe/bonus) | 120/57/133/100/15 | **birebir aynı** |
| T2 (oyun/galibiyet/k-lig) | 12/3/−2 | **birebir aynı** |
| Silinen yarım online oyun | 7 | **7** (6 `abandoned` + 1 `active`) |
| Korunan bitmiş online oyun | 10 | **10**, hepsinin `games` kaydı yerinde |
| Avatar dosyası (83.815 bayt) | silinir | **silindi** |

**Koltuk indeksi kararı sahada kanıtlandı.** Anonimleşen 11 satırdan
birinde (29 Temmuz, Ironman'in kaydı, koltuk 1) ad `T1` DEĞİL hesabın
sonradan değiştirilmiş eski adı **`AlpTEST`** idi. Ada göre eşleştiren bir
uygulama o satırı sessizce atlar ve eski ad başkasının kaydında sonsuza dek
kalırdı; koltuk eşlemesi yakaladı.

**Modal ↔ sunucu tutarlılığı da doğrulandı:** T1'in penceresindeki dokuz
satırın dokuzu da sunucunun kuru çalıştırmasıyla birebir aynıydı. Modal
ayrıca **"Profil fotoğrafın 1"** gösterdi — o sayı SQL raporunda yok, Edge
Function'ın depolama kovasını listelemesinden geliyor; yani storage dalının
da bağlı olduğu böylece görüldü.

**Doğrulama sınırı (kalan):** cihazda (gerçek Android/iOS paketi) hiç
denenmedi — iki silme de Flutter **web** derlemesinden yapıldı. Cihaz
kontrolleri `mobile/TESTING.md` bölüm 21'de duruyor.

---

## SET NULL'ın bedeli: kurucusu silinmiş oyun İSTEMCİYİ düşürdü (26 Ağustos 2026)

Kaskadın "başkasının verisine dokunma" kararı doğruydu ve çalıştı — ama
**sözleşme değişikliği olarak istemcilere taşınmadı.** `created_by`
CASCADE'ten SET NULL'a çevrildiğinde o kolon artık NULL dönebilir hâle
geldi; iki istemcinin tipi de `string`/`String` kaldı.

**Belirti (kullanıcı bildirdi, gerçek cihaz, derleme `53e401c` = 372):**
*"Devam edenler, oyun davetleri (2 tane vardı) ve son oynadıklarım
gelmiyor"* — Canlı sekmesinin ÜÇÜ birden "Oyunların şu an yüklenemedi."
gösteriyor, TEKRAR DENE hiçbir şey yapmıyor. Skor Kartı normal açılıyor.

**Kök sebep — ölçüldü, tahmin edilmedi:**

- Ironman kimliğiyle koşulan `list_my_online_games()` **43 satır** dönüyor
  (RPC sağlam, `auth.uid()` doğru çözülüyor), bunların **2'sinde
  `created_by IS NULL`** — T1'in silinmesiyle boşalan kolon. Bugün
  veritabanının tamamında böyle **5 satır** var ve hepsi `finished`
  (yarım oyunlar zaten siliniyor — tasarım gereği).
- Port `OnlineGame.fromJson` içinde `m['created_by'] as String` yapıyordu
  → **fırlatıyor**. Tek bir bozuk satır TÜM listeyi düşürüyor, çünkü
  ayrıştırma tek geçişte.
- `OnlineGamesRepo.load()` hatayı yutup `null` dönüyor (sözleşme: "UI
  eskiyi korur") → elde hiç liste yoksa `kLoadFailedNotice`. Tekrar
  denemek çare değil: hata **deterministik**, ağ hatası değil.

**Neden hiçbir uyarı gelmedi:** `load()`'un `catch` bloğu yalnızca
`debugPrint` yapıyordu. Yani `client_errors`'ta tek satır yok; 36 saatlik
tabloda tek kayıt tamamen ilgisiz bir tarayıcı oturumundan geliyordu.
Teşhis elle SQL koşularak yapıldı — telemetri tam da bunun için kurulmuştu.

**Düzeltme (web + port, aynı PR):**

| Dosya | Değişiklik |
|---|---|
| `mobile/app/lib/src/data/online_games_api.dart` | `createdBy` → `String?`, cast `as String?`; `creatorSlot` ve `participantLabel` NULL GÜVENLİ (null==null tuzağı: `createdBy` de `userId` de null olabildiğinden çıplak eşitlik rastgele bir koltuğu "kurucu" ilan ederdi) |
| aynı dosya, `load()` | ayrıştırma hatası artık `errorReporter.report`'a düşüyor; **ağ hatası elenerek** (`isNetworkError`) — `report` varsayılan `manual` türünde o filtreyi kendisi uygulamaz |
| `src/lib/database.types.ts` | `created_by: string \| null` — tip artık dürüst |

Web **kodu** değişmedi ve buna gerek de yoktu: `LiveGamesTab`'in üç
tüketicisi de `?.name ?? 'Bir arkadaşın'` kalıbında; `HumanSlot.user_id`
NOT NULL olduğundan `user_id === created_by` karşılaştırması null'da
hiçbir koltuğu seçmiyor, yani "kurucu yok" doğru sonucu çıkıyor. Yanlış
olan yalnızca tipti — ve tip yanlış olduğu için port da yanlış cast'i
kopyalamıştı.

**Sunucu tarafı denetlendi, değişiklik GEREKMEDİ:** `created_by`'ye bakan
her yer (`is_online_game_creator`, `is_online_game_participant`,
`check_invite_expiry`, `online_games`/`game_invites` RLS politikaları)
yalnızca EŞİTLİK karşılaştırması yapıyor; NULL'da eşleşmiyor, yani hak
gevşemesi yok. Hayatta kalan oyuncu oyuna `game_invites` dalından
erişmeye devam ediyor (`is_online_game_participant`'in ikinci kolu).

**Ders — bu dosyanın en pahalı satırı:** *bir FK eylemini değiştirmek bir
SÖZLEŞME değişikliğidir.* `on delete cascade` → `set null`, "silinen satır"
sorusunu "NULL kolon" sorusuna çevirir ve o NULL'ı okuyan HER istemci
tipini genişletmek zorundadır. Kök `CLAUDE.md`'nin etki analizi tablosunda
bu satır yoktu; artık var ("Migration: bir kolon nullable oluyorsa
`database.types.ts` + portun `fromJson`'ı AYNI PR'da").
