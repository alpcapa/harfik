-- Harfik — leaderboard'a total_score eklenir, sıralama total_score'a göre yapılır.
-- Kullanıcının kendi sırasını döndüren RPC de eklenir.

-- Leaderboard görünümünü yeniden oluştur (total_score dahil, toplam puana göre sıralı).
drop view if exists public.leaderboard;
create view public.leaderboard
with (security_invoker = true) as
select
  g.user_id,
  p.username,
  p.display_name,
  p.avatar_url,
  max(g.player_score)        as best_score,
  sum(g.player_score)        as total_score,
  count(*)                   as games_played,
  count(*) filter (where g.result = 'win') as wins
from public.games g
left join public.profiles p on p.id = g.user_id
where g.user_id is not null
group by g.user_id, p.username, p.display_name, p.avatar_url
order by total_score desc;

-- RPC: oturum açan kullanıcının toplam puana göre sırasını ve toplam puanını döner.
create or replace function public.my_leaderboard_rank (p_user_id uuid)
  returns table (rank bigint, total_score bigint)
  language sql
  stable
  security invoker
  set search_path = public
  as $$
  select ranked.rank, ranked.total_score
  from (
    select
      g.user_id,
      sum(g.player_score) as total_score,
      rank() over (order by sum(g.player_score) desc) as rank
    from public.games g
    where g.user_id is not null
    group by g.user_id
  ) ranked
  where ranked.user_id = p_user_id;
$$;
