-- Harfik — games tablosuna en iyi hamle puanı ve en uzun kelime eklenir;
-- player_stats görünümü bu iki alanı da hesaplar.

alter table public.games
  add column if not exists best_move_score integer,
  add column if not exists longest_word text;

-- player_stats görünümünü yeniden oluştur.
create or replace view public.player_stats
with (security_invoker = true) as
select
  g.user_id,
  count(*)                              as games_played,
  count(*) filter (where g.result = 'win')  as wins,
  count(*) filter (where g.result = 'lose') as losses,
  count(*) filter (where g.result = 'tie')  as ties,
  max(g.player_score)                   as best_score,
  round(avg(g.player_score))::int       as avg_score,
  max(g.best_move_score)                as best_move_score,
  (
    select g2.longest_word
    from public.games g2
    where g2.user_id = g.user_id
      and g2.longest_word is not null
    order by char_length(g2.longest_word) desc
    limit 1
  )                                     as longest_word
from public.games g
where g.user_id is not null
group by g.user_id;
