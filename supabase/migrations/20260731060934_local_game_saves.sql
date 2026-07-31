-- local_game_saves: girişli kullanıcının devam eden yerel (YZ) oyun
-- kayıtları — cihazlar arası senkron + çoklu eşzamanlı oyun için. Misafir
-- kullanıcılar hâlâ yalnızca localStorage (kelimeki:game-state) kullanır, bu
-- tabloya hiç dokunmaz.
create table public.local_game_saves (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  state jsonb not null,
  player_count integer not null check (player_count = any (array[2, 4])),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.local_game_saves is 'Girişli kullanıcının devam eden yerel (YZ) oyun kayıtları — cihazlar arası senkron + çoklu eşzamanlı oyun için. Misafir kullanıcılar hâlâ yalnızca localStorage (kelimeki:game-state) kullanır.';

create index local_game_saves_user_id_idx on public.local_game_saves (user_id);

alter table public.local_game_saves enable row level security;

create policy local_game_saves_select_own on public.local_game_saves
  for select using (auth.uid() = user_id);

create policy local_game_saves_insert_own on public.local_game_saves
  for insert with check (auth.uid() = user_id);

create policy local_game_saves_update_own on public.local_game_saves
  for update using (auth.uid() = user_id);

create policy local_game_saves_delete_own on public.local_game_saves
  for delete using (auth.uid() = user_id);

create trigger trg_local_game_saves_updated_at
  before update on public.local_game_saves
  for each row execute function public.set_updated_at();
