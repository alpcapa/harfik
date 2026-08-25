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
| Web hukuki metin | `src/legal/LegalContent.tsx` (Gizlilik §5), `src/legal/render.tsx` (`/hesap-silme/`) |
| Port veri | `mobile/app/lib/src/data/auth_service.dart` (+ `AccountDeletionReport`) |
| Port UI | `mobile/app/lib/src/ui/auth/delete_account_modal.dart` + `account_settings_modal.dart` + `neo_button.dart` (`red` varyantı) |
| Port hukuki metin | `mobile/app/lib/src/ui/auth/legal_modals.dart` (tarih `legal_text_test.dart` ile zorlanıyor) |
| Testler | `tests/smoke.spec.ts`, `mobile/app/test/account_settings_test.dart` |

**Doğrulama sınırı:** gerçek (kuru olmayan) silme bu oturumda HİÇ
çalıştırılmadı — geri dönüşü yok. İlk gerçek kullanımı ROADMAP madde 4
(test hesaplarının silinmesi) olacak; cihaz kontrolleri `mobile/TESTING.md`
ve `TESTING.md`de.
