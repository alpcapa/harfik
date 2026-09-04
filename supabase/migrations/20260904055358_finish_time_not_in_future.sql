-- Kelimeki — bitiş anı GELECEKTE olamaz (istemciden gelen `created_at` kapısı).
--
-- NEDEN (4 Eylül 2026): terk-edilme kayıtları artık `created_at`i İSTEMCİDEN
-- alıyor. Gerekçe: o satırlar sürenin dolduğu an değil, kullanıcının
-- uygulamayı bir sonraki açtığı an yazılıyor; damgalanmazsa bir haftalık
-- terkler "bugün"e düşüyor (sahada görüldü: bir kullanıcının 19 kaydı tek bir
-- saniyeye, panelde "dün 38 teslim").
--
-- `games.created_at` zaten istemciden geliyordu (offline kuyruk, gerçek bitiş
-- anını korumak için) — bu açık YENİ DEĞİL, yalnızca artık ikinci bir tabloda
-- da var. İkisine de aynı kapı konuyor.
--
-- KAPI YALNIZCA İLERİ TARİHE: geçmiş bir tarih meşru (offline kuyruk, terk
-- süpürmesi, misafirken oynanıp sonra hesaba taşınan oyunlar hep geçmiş
-- yazar). İleri tarih hiçbir meşru akışta oluşamaz ve grafiklerin sağ ucunu
-- bozar.
--
-- ⚠ CHECK DEĞİL TRIGGER: `now()` volatile, Postgres onu CHECK içinde kabul
-- etmiyor. Bu tabloda zaten BEFORE INSERT trigger deseni var (`_mask_route`).
--
-- ⚠ REDDETMİYOR, KIRPIYOR: saati birkaç dakika ileri kurulmuş bir telefon
-- yüzünden gerçek bir oyun kaydını çöpe atmak, tarihi düzeltmekten çok daha
-- pahalı. 5 dakikalık pay normal saat sapmasına; ötesi sessizce `now()`a
-- çekilir.
create or replace function public._clamp_created_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.created_at is null or new.created_at > now() + interval '5 minutes' then
    new.created_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists games_clamp_created_at on public.games;
create trigger games_clamp_created_at
  before insert on public.games
  for each row execute function public._clamp_created_at();

drop trigger if exists game_finishes_clamp_created_at on public.game_finishes;
create trigger game_finishes_clamp_created_at
  before insert on public.game_finishes
  for each row execute function public._clamp_created_at();
