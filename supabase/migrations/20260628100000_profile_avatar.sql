-- Harfik — profil avatarı (profil fotoğrafı) desteği
-- profiles tablosuna avatar_url ekler, avatarlar için herkese açık bir
-- depolama kovası (storage bucket) ve RLS politikaları oluşturur ve
-- leaderboard görünümüne avatarı ekler.

-- ── PROFİL AVATAR SÜTUNU ─────────────────────────────────────────────────────
alter table public.profiles
  add column if not exists avatar_url text;

-- ── DEPOLAMA KOVASI ──────────────────────────────────────────────────────────
-- Herkese açık okuma (public = true) — küçük profil küçük resimleri için.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Politikalar: herkes okuyabilir; kullanıcı yalnızca kendi klasörünü
-- (path öneki = kullanıcı kimliği) yönetebilir.
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_user_insert" on storage.objects;
create policy "avatars_user_insert" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid ()::text
  );

drop policy if exists "avatars_user_update" on storage.objects;
create policy "avatars_user_update" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid ()::text
  );

drop policy if exists "avatars_user_delete" on storage.objects;
create policy "avatars_user_delete" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid ()::text
  );

-- ── LEADERBOARD GÖRÜNÜMÜ (avatar dahil) ──────────────────────────────────────
create or replace view public.leaderboard
with (security_invoker = true) as
select
  g.user_id,
  p.username,
  p.display_name,
  p.avatar_url,
  max(g.player_score) as best_score,
  count(*) as games_played,
  count(*) filter (where g.result = 'win') as wins
from public.games g
left join public.profiles p on p.id = g.user_id
where g.user_id is not null
group by g.user_id, p.username, p.display_name, p.avatar_url
order by best_score desc;
