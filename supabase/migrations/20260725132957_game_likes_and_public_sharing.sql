-- Sanal Lig'den herkes herkesin skor kartına girip oyunlarını görebiliyor
-- (PlayerScoreCard.tsx, 25 Temmuz 2026 sabahki değişiklik) — ama bunun
-- çalışabilmesi için gereken `games` SELECT politikası 22 Temmuz'daki
-- lock_down_profiles_games_select migration'ıyla zaten owner-or-admin'e
-- kilitlenmişti (fetchPlayerStats/fetchMyGames/fetchGameBoardSnapshot'taki
-- yorumlar bir "herkese açık select politikası" varsayıyordu, ama bu üç
-- gün önce kaldırılmıştı) — yani başkasının kartını açan admin olmayan bir
-- kullanıcı boş istatistik/boş oyun listesi/açılmayan tahta görüyordu. Bu
-- migration hem bu regresyonu düzeltiyor hem de kullanıcı isteğiyle iki yeni
-- davranış ekliyor: (1) herkes herkesin oyununu beğenebilsin (yalnızca oyun
-- sahibi değil), (2) herkes herkesin oyununu paylaşabilsin.

-- games tablosu artık herhangi bir girişli kullanıcıya (yalnızca sahibi/admin
-- değil) açık — skor/tahta gibi veriler zaten Sanal Lig'in kendi doğası
-- gereği yarı-kamusal, kişisel veri (e-posta vb.) hiç barındırmıyor.
drop policy if exists games_select_own_or_admin on public.games;
create policy games_select_authenticated on public.games
  for select
  using (auth.uid() is not null);

-- Beğeni artık games.favorited (tek bayrak, yalnızca sahibi değiştirebilir)
-- yerine ayrı bir tablo: bir oyunu birden fazla kullanıcı (sahibi dahil,
-- sahip olmadan da) beğenebilir. game_likes tablosu bilerek games'ten ayrı
-- tutuluyor — games hâlâ tarihi/değişmez bir kayıt, genel bir UPDATE
-- politikası açılmıyor.
create table public.game_likes (
  game_id uuid not null references public.games(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (game_id, user_id)
);

create index game_likes_user_id_idx on public.game_likes (user_id);

alter table public.game_likes enable row level security;

-- Kim neyi beğenmiş herkese (girişli) açık görünür olmalı — aksi halde
-- başka birinin kartındaki "Favoriler" sekmesi (o kişinin beğendiği
-- oyunlar) hiç kimseye görünmezdi, yalnızca kendi beğenilerine.
create policy game_likes_select_authenticated on public.game_likes
  for select
  using (auth.uid() is not null);

create policy game_likes_insert_self on public.game_likes
  for insert
  with check (auth.uid() = user_id);

create policy game_likes_delete_self on public.game_likes
  for delete
  using (auth.uid() = user_id);

-- Eski favorited=true kayıtlarını (oyun sahibinin kendi beğenisi olarak)
-- yeni tabloya taşı.
insert into public.game_likes (game_id, user_id, created_at)
select id, user_id, created_at
from public.games
where favorited = true and user_id is not null
on conflict do nothing;

drop function if exists public.toggle_game_favorite(uuid);

alter table public.games drop column if exists favorited;

-- Tek bir oyun için beğeni durumunu (yalnızca çağıranın kendi satırı için)
-- tersine çevirir. game_likes'ın kendi RLS'i (insert/delete: yalnızca kendi
-- user_id'n) bu işlemi zaten kapsadığından security definer'a gerek yok.
create or replace function public.toggle_game_like(p_game_id uuid)
returns boolean
language plpgsql
set search_path to 'public'
as $$
declare
  v_new boolean;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz erişim.';
  end if;

  if exists (select 1 from public.game_likes where game_id = p_game_id and user_id = auth.uid()) then
    delete from public.game_likes where game_id = p_game_id and user_id = auth.uid();
    v_new := false;
  else
    insert into public.game_likes (game_id, user_id) values (p_game_id, auth.uid());
    v_new := true;
  end if;

  return v_new;
end;
$$;

revoke all on function public.toggle_game_like(uuid) from public, anon;
grant execute on function public.toggle_game_like(uuid) to authenticated;

-- Paylaşma artık oyun sahibine özel değil — herhangi bir girişli kullanıcı
-- gördüğü herhangi bir oyunu (kendi kartında ya da başkasının kartında)
-- paylaşabilir; mesaj metni buna göre jenerik hale getirildi (bkz.
-- GameHistoryModal.tsx'teki SHARE_MESSAGE, "oynadığım" yerine "bu oyun").
create or replace function public.set_game_shared(p_game_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz erişim.';
  end if;

  update public.games set shared = true where id = p_game_id;
  return true;
end;
$$;
