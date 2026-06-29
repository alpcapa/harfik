-- Harfik — leaderboard'da yalnızca kayıtlı kullanıcılar gösterilsin.
-- LEFT JOIN → INNER JOIN: profili olmayan user_id'ler artık listede çıkmaz.

drop view if exists public.leaderboard;
create view public.leaderboard
with (security_invoker = true) as
select
  g.user_id,
  p.username,
  p.display_name,
  p.avatar_url,
  max(g.player_score)                       as best_score,
  sum(g.player_score)                       as total_score,
  count(*)                                  as games_played,
  count(*) filter (where g.result = 'win')  as wins
from public.games g
inner join public.profiles p on p.id = g.user_id
group by g.user_id, p.username, p.display_name, p.avatar_url
order by total_score desc;
