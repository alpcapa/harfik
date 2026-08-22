-- Kelimeki — `game_starts.is_guest`: huninin "Başlayan" adımı misafire iniyor
--
-- NEDEN: Kaynak Hunisi bugüne kadar ÜÇ farklı kitleyi yan yana koyuyordu ve
-- bunu hiçbir yerde söylemiyordu. "Gelen" BAŞTAN BERİ yalnızca misafir
-- (`App.tsx`: `if (... || user) return;` — ziyaret kaydı yalnızca oturum
-- KAPALIYKEN yazılıyor), "Başlayan" ile "Biten" ise karışıktı. Sonuç: aylardır
-- oynayan bir üyenin oyunları, "bu kanal işe yaradı mı" sorusunun cevabını
-- boğuyordu (ölçüldü: `arkadas` satırında 292 üye oyunu).
--
-- Kullanıcının beklentisi de buydu (22 Ağustos 2026, sözleriyle): *"gelenler
-- üye olmadan kaç oyun başlatmış (başlayan), gelenler üye olmadan kaç oyun
-- bitirmiş (biten)"*.
--
-- "Biten" bunu ZATEN yapabiliyordu — `game_finishes.user_id` nullable (299
-- satır: 42 misafir / 257 üye). "Başlayan" YAPAMIYORDU: `game_starts` bilerek
-- `user_id` TAŞIMIYOR (tablonun kendi yorumu: anon_id ile hesap kimliğini aynı
-- satırda birleştirmek `PrivacyModal` bölüm 6'daki taahhüdü bozardı).
--
-- ⚠ ÇÖZÜM `user_id` DEĞİL, BAYRAK. Bir boolean hangi hesap olduğunu söylemez
-- ve anon kodu bir hesapla eşleştirmeye izin vermez — yani gizlilik taahhüdü
-- ("bu kayıtların hiçbirinde hesap kimliğiniz YER ALMAZ") aynen ayakta kalıyor
-- ve hukuki metinlerde değişiklik GEREKMİYOR.
--
-- ⚠ YALNIZ BİRİNİ AYIRMAK YANLIŞ OLURDU: "Başlayan" ile "Biten" bir çift ve
-- `biten/başlayan` tamamlanma oranını besliyor. Yalnız "Biten"i misafire
-- indirmek oranı "misafir bitişi ÷ TÜM başlangıçlar" yapıp sessizce düşük
-- gösterirdi. İkisi birlikte iniyor.
--
-- ⚠ GERİYE DÖNÜK DOLDURULAMAZ (`games.platform`/`utm_source` ile aynı sınıf):
-- mevcut 81 satırda bayrak NULL kalır ve NULL "bilinmiyor" demektir, misafir
-- SAYILMAZ. Yani huninin "Başlayan" sütunu bu değişiklikten sonra bir süre
-- düşük görünecek — uydurma bir varsayılan yazmak (hepsini misafir saymak)
-- ölçümü sessizce yanlışlardı.

alter table public.game_starts
  add column if not exists is_guest boolean;

comment on column public.game_starts.is_guest is
  'Bu oyun oturum KAPALIYKEN mi başlatıldı (huninin "Başlayan" adımı misafiri sayar). BİLEREK user_id DEĞİL bir bayrak: hangi hesap olduğunu söylemediğinden anon_id ile hesap eşleştirmesi doğmuyor. NULL = damgalamayan istemci ya da 22 Ağustos 2026 öncesi satır — misafir SAYILMAZ, geriye dönük doldurulamaz.';

create index if not exists game_starts_is_guest_idx
  on public.game_starts (is_guest);

-- Kolon düzeyinde insert yetkisi: tabloda INSERT grant'i kolon kolon veriliyor
-- (yeni her kolon tek tek eklenmeli, yoksa istemci yazamaz).
grant insert (is_guest) on public.game_starts to anon, authenticated;
