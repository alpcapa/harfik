-- "Genel" sekmesindeki İkincilik sayacı, 2 kişilik oyunlardaki ikincilikleri
-- saymıyordu: `player_stats.second_places` `count(*) filter (where rank = 2)`
-- iken `player_stats_overall.second_places` ayrıca `player_count <> 2`
-- filtresi taşıyordu. Sonuç, kullanıcının bildirdiği tutarsızlık: yalnızca
-- 2 kişilik oynayan bir oyuncunun kartında "2 Oyunculu" sekmesi 21 İkincilik
-- gösterirken "Genel" 0 gösteriyordu (Minka, 42 oyunun tamamı 2 kişilik).
--
-- Filtre `player_stats_overall` yazıldığında (29 Temmuz 2026) DOĞRUYDU: o
-- tarihte İkincilik hücresi yalnızca 4 kişilik/Genel sekmede gösteriliyordu,
-- çünkü 2 kişilik bir oyunda ikinci olmak kaybetmekle aynı şey ve lig puanı
-- getirmiyor. Ama 1 Ağustos 2026'da kullanıcı isteğiyle İkincilik ÜÇ sekmede
-- birden, bilgi amaçlı gösterilmeye başlandı (bkz. CLAUDE.md, ScoreCard
-- notu) — o değişiklik yalnızca UI'daki `useWideLayout` koşulunu kaldırdı,
-- bu view'daki filtreyi fark etmemişti.
--
-- `total_score` BİLEREK DEĞİŞMİYOR: lig puanı kuralı ("2 kişilikte ikincilik
-- 0 puan") hâlâ geçerli ve doğru yer orası. Değişen yalnızca bilgi amaçlı
-- SAYAÇ, ki artık `player_stats` ile birebir aynı tanımı kullanıyor —
-- Genel = 2 kişilik + 4 kişilik değişmezliği sağlanmış oluyor.
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
    from games g2
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
  count(*) filter (where rank = 2) as second_places,
  sum(
    case
      when surrendered then -2
      when rank = 1 then 2
      when rank = 2 and player_count <> 2 then 1
      else 0
    end
  )::integer as total_score,
  count(*) filter (where surrendered) as surrendered_count,
  count(*) filter (where online_game_id is null) as local_games_played,
  count(*) filter (where online_game_id is not null) as online_games_played,
  max(best_word_score) as best_word_score
from games g
where user_id is not null
group by user_id;
