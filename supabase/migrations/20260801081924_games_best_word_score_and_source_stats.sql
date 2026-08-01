-- Skor kartına eklenen yeni istatistikler için:
-- (1) "En Yüksek Puanlı Kelime" — bir oyunda oynanan en yüksek puanlı TEK
--     kelimenin (X2/X3 çarpanı dahil) nihai puanı. best_move_score'dan
--     farklı — o bir HAMLEnin (birden fazla kelime + bonus içerebilir)
--     toplam puanıdır, bu ise tek bir kelimenin kendi puanı.
-- (2) "Yapay Zeka ile" / "Arkadaşınla" oyun sayısı dökümü — games.online_game_id
--     null ise yerel (YZ), dolu ise Canlı (arkadaşınla) oyun.
alter table public.games add column best_word_score integer;

comment on column public.games.best_word_score is
  'Bu oyunda oynanan en yüksek puanlı TEK kelimenin (X2/X3 çarpanı dahil) nihai puanı. best_move_score''den farklı — o bir HAMLEnin (birden fazla kelime + bonus içerebilir) toplam puanıdır.';

create or replace view public.player_stats as
 SELECT user_id,
    player_count,
    count(*) AS games_played,
    count(*) FILTER (WHERE result = 'win'::text) AS wins,
    count(*) FILTER (WHERE result = 'lose'::text) AS losses,
    count(*) FILTER (WHERE result = 'tie'::text) AS ties,
    max(player_score) AS best_score,
    round(avg(player_score))::integer AS avg_score,
    max(best_move_score) AS best_move_score,
    ( SELECT g2.longest_word
           FROM games g2
          WHERE g2.user_id = g.user_id AND g2.player_count = g.player_count AND g2.longest_word IS NOT NULL
          ORDER BY (char_length(g2.longest_word)) DESC
         LIMIT 1) AS longest_word,
    round(sum(move_points_sum) FILTER (WHERE move_points_sum IS NOT NULL)::numeric / NULLIF(sum(move_count) FILTER (WHERE move_points_sum IS NOT NULL), 0)::numeric, 2) AS avg_move_score,
    count(*) FILTER (WHERE rank = 1) AS first_places,
    count(*) FILTER (WHERE rank = 2) AS second_places,
    sum(
        CASE
            WHEN surrendered THEN '-2'::integer
            WHEN rank = 1 THEN 2
            WHEN rank = 2 AND player_count <> 2 THEN 1
            ELSE 0
        END)::integer AS total_score,
    count(*) FILTER (WHERE surrendered) AS surrendered_count,
    count(*) FILTER (WHERE online_game_id IS NULL) AS local_games_played,
    count(*) FILTER (WHERE online_game_id IS NOT NULL) AS online_games_played,
    max(best_word_score) AS best_word_score
   FROM games g
  WHERE user_id IS NOT NULL
  GROUP BY user_id, player_count;

create or replace view public.player_stats_overall as
 SELECT user_id,
    count(*) AS games_played,
    count(*) FILTER (WHERE result = 'win'::text) AS wins,
    count(*) FILTER (WHERE result = 'lose'::text) AS losses,
    count(*) FILTER (WHERE result = 'tie'::text) AS ties,
    max(player_score) AS best_score,
    round(avg(player_score))::integer AS avg_score,
    max(best_move_score) AS best_move_score,
    ( SELECT g2.longest_word
           FROM games g2
          WHERE g2.user_id = g.user_id AND g2.longest_word IS NOT NULL
          ORDER BY (char_length(g2.longest_word)) DESC
         LIMIT 1) AS longest_word,
    round(sum(move_points_sum) FILTER (WHERE move_points_sum IS NOT NULL)::numeric / NULLIF(sum(move_count) FILTER (WHERE move_points_sum IS NOT NULL), 0)::numeric, 2) AS avg_move_score,
    count(*) FILTER (WHERE rank = 1) AS first_places,
    count(*) FILTER (WHERE rank = 2 AND player_count <> 2) AS second_places,
    sum(
        CASE
            WHEN surrendered THEN '-2'::integer
            WHEN rank = 1 THEN 2
            WHEN rank = 2 AND player_count <> 2 THEN 1
            ELSE 0
        END)::integer AS total_score,
    count(*) FILTER (WHERE surrendered) AS surrendered_count,
    count(*) FILTER (WHERE online_game_id IS NULL) AS local_games_played,
    count(*) FILTER (WHERE online_game_id IS NOT NULL) AS online_games_played,
    max(best_word_score) AS best_word_score
   FROM games g
  WHERE user_id IS NOT NULL
  GROUP BY user_id;
