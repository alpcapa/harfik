-- Harfik — profiles.agreed_to_terms sütunu eklenir; leaderboard'a last_name dahil edilir.

-- ── AGREED_TO_TERMS ──────────────────────────────────────────────────────────
alter table public.profiles
  add column if not exists agreed_to_terms boolean not null default false;

-- ── LEADERBOARD GÖRÜNÜMÜ (last_name dahil) ────────────────────────────────────
drop view if exists public.leaderboard;
create view public.leaderboard
with (security_invoker = true) as
select
  g.user_id,
  p.username,
  p.first_name,
  p.last_name,
  p.display_name,
  p.avatar_url,
  max(g.player_score)                       as best_score,
  sum(g.player_score)                       as total_score,
  count(*)                                  as games_played,
  count(*) filter (where g.result = 'win')  as wins
from public.games g
inner join public.profiles p on p.id = g.user_id
group by g.user_id, p.username, p.first_name, p.last_name, p.display_name, p.avatar_url
order by total_score desc;
