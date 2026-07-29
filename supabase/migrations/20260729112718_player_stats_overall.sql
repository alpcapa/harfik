-- Skor Kartı'na eklenen "Genel" sekmesi için: 2 ve 4 kişilik oyunların
-- TOPLAMINI gösteren bir view. `player_stats`'ın (user_id, player_count)
-- bazında ayrı satırlar döndürdüğü aynı hesaplamayı, `player_count`'a göre
-- gruplamadan (yani `games`'in tamamı üzerinden) tekrarlıyor — bilerek
-- client-side'da iki satırı toplamak yerine: avg_move_score (ağırlıklı
-- ortalama) ve longest_word gibi alanlar iki önceden-hesaplanmış satırdan
-- doğru şekilde birleştirilemez, ham `games` satırlarından yeniden
-- hesaplanmaları gerekir.
--
-- second_places/total_score, `player_stats`'taki AYNI kuralı koruyor: 2
-- kişilik bir oyunda rank=2 olmak sıradan bir kayıptır (lig puanı
-- getirmez, ScoreCard bu yüzden 2 kişilik sekmede "İkincilik" hücresini
-- hiç göstermez) — Genel sekmesi 4 kişilikle aynı tabloyu kullandığından
-- (kullanıcı isteği) buradaki "İkincilik" de yalnızca GERÇEK (4 kişilik,
-- puan getiren) ikincilikleri saymalı, yoksa 2 kişilikteki sıradan
-- kayıpları da "ikincilik" gibi göstermiş olurduk.
create or replace view public.player_stats_overall as
select
  user_id,
  count(*) as games_played,
  count(*) filter (where result = 'win') as wins,
  count(*) filter (where result = 'lose') as losses,
  count(*) filter (where result = 'tie') as ties,
  max(player_score) as best_score,
  round(avg(player_score))::integer as avg_score,
  max(best_move_score) as best_move_score,
  (
    select g2.longest_word
    from public.games g2
    where g2.user_id = g.user_id and g2.longest_word is not null
    order by char_length(g2.longest_word) desc
    limit 1
  ) as longest_word,
  round(
    sum(move_points_sum) filter (where move_points_sum is not null)::numeric
    / nullif(sum(move_count) filter (where move_points_sum is not null), 0)::numeric,
    2
  ) as avg_move_score,
  count(*) filter (where rank = 1) as first_places,
  count(*) filter (where rank = 2 and player_count <> 2) as second_places,
  sum(
    case
      when surrendered then -2
      when rank = 1 then 2
      when rank = 2 and player_count <> 2 then 1
      else 0
    end
  )::integer as total_score,
  count(*) filter (where surrendered) as surrendered_count
from public.games g
where user_id is not null
group by user_id;

grant select on public.player_stats_overall to anon, authenticated;
