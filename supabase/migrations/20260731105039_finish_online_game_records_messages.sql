-- Kelimeki — Oyun İçi Mesajlaşma, Faz 1 (devam): _finish_online_game_records
-- artık o oyunun online_game_messages'ını `games.messages` jsonb'sine
-- dondurup her insan katılımcının satırına kopyalıyor — board_snapshot'ın
-- zaten yaptığı "bitişte anlık görüntü al" işleminin sohbet karşılığı.
--
-- Fonksiyonun geri kalanı (sıralama/rank/players_json/board_snapshot
-- mantığı) 20260729091525_online_game_turn_timeout_surrender.sql'deki
-- tanımla BİREBİR AYNI — yalnızca yeni v_fp_messages hesabı ve insert'e
-- eklenen `messages` sütunu farklı. Postgres'te dönüş tipi/gövde değişince
-- create or replace yeterli (imza aynı kaldığından drop gerekmiyor).
create or replace function public._finish_online_game_records(
  p_game_id uuid,
  p_board jsonb,
  p_players jsonb,
  p_slots jsonb,
  p_player_count int,
  p_turn_count int
) RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_fp_sorted_idx int[];
  v_fp_ranks int[];
  v_fp_rank int;
  v_fp_prev_score int;
  v_fp_prev_surrendered boolean;
  v_fp_idx int;
  v_fp_cur_score int;
  v_fp_cur_surrendered boolean;
  v_fp_tied1 int;
  v_fp_players_json jsonb;
  v_fp_snapshot jsonb;
  v_fp_messages jsonb;
  v_fp_slot jsonb;
  v_fp_result text;
begin
  -- players jsonb snapshot'ı rankPlayers (src/utils/ranking.ts) ile aynı
  -- sırayla inşa edilmeli: önce teslim OLMAMIŞ oyuncular skora göre azalan,
  -- ardından teslim olanlar (kendi aralarında yine skora göre azalan) —
  -- computeRanks (client) sıralama yapmıyor, girdinin zaten bu sırada
  -- olduğunu varsayıyor.
  v_fp_sorted_idx := array(
    select gs
    from generate_series(0, p_player_count - 1) gs
    order by
      coalesce((p_players -> gs ->> 'surrendered')::boolean, false) asc,
      (p_players -> gs ->> 'score')::int desc,
      gs asc
  );

  v_fp_ranks := array_fill(0, array[p_player_count]);
  v_fp_rank := 0;
  for pos in 1 .. p_player_count loop
    v_fp_idx := v_fp_sorted_idx[pos];
    v_fp_cur_score := (p_players -> v_fp_idx ->> 'score')::int;
    v_fp_cur_surrendered := coalesce((p_players -> v_fp_idx ->> 'surrendered')::boolean, false);
    if pos = 1 or v_fp_cur_score <> v_fp_prev_score or v_fp_cur_surrendered <> v_fp_prev_surrendered then
      v_fp_rank := pos;
    end if;
    v_fp_ranks[v_fp_idx + 1] := v_fp_rank;
    v_fp_prev_score := v_fp_cur_score;
    v_fp_prev_surrendered := v_fp_cur_surrendered;
  end loop;

  v_fp_tied1 := 0;
  for i in 0 .. p_player_count - 1 loop
    if v_fp_ranks[i + 1] = 1 then
      v_fp_tied1 := v_fp_tied1 + 1;
    end if;
  end loop;

  v_fp_players_json := '[]'::jsonb;
  for pos in 1 .. p_player_count loop
    v_fp_players_json := v_fp_players_json || jsonb_build_array(jsonb_build_object(
      'name', (p_players -> v_fp_sorted_idx[pos] ->> 'name'),
      'score', (p_players -> v_fp_sorted_idx[pos] ->> 'score')::int,
      'is_ai', (p_players -> v_fp_sorted_idx[pos] ->> 'isAI')::boolean,
      'surrendered', coalesce((p_players -> v_fp_sorted_idx[pos] ->> 'surrendered')::boolean, false),
      'colorIndex', (p_players -> v_fp_sorted_idx[pos] ->> 'colorIndex')::int
    ));
  end loop;

  -- Tahta anlık görüntüsü — client'taki serializeBoardSnapshot'ın SQL
  -- karşılığı: yalnızca dolu hücreler {r,c,l,o,w?} olarak.
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'r', gr,
      'c', gc,
      'l', (p_board -> gr -> gc) ->> 'letter',
      'o', coalesce(((p_board -> gr -> gc) ->> 'owner')::int, 0)
    ) || case when ((p_board -> gr -> gc) ->> 'wild')::boolean is true
              then jsonb_build_object('w', true)
              else '{}'::jsonb
         end
  ), '[]'::jsonb)
  into v_fp_snapshot
  from generate_series(0, 12) gr, generate_series(0, 12) gc
  where jsonb_typeof(p_board -> gr -> gc) <> 'null';

  -- Sohbet anlık görüntüsü — o oyunda gönderilmiş tüm mesajları, gönderenin
  -- koltuk numarasından o anki (o hamlede güncellenmiş) adı/rengiyle
  -- eşleyip kronolojik bir jsonb dizisine dondurur. Yalnızca insan
  -- koltukları mesaj gönderebildiğinden (RLS: sender_user_id = auth.uid())
  -- eşleme yalnızca human slot'lara bakar.
  with seat_map as (
    select (p_slots -> i ->> 'user_id')::uuid as user_id, i as seat_idx
    from generate_series(0, p_player_count - 1) i
    where (p_slots -> i ->> 'type') = 'human'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'name', coalesce(p_players -> sm.seat_idx ->> 'name', 'Oyuncu'),
      'colorIndex', (p_players -> sm.seat_idx ->> 'colorIndex')::int,
      'message', m.message,
      'created_at', m.created_at
    ) order by m.created_at), '[]'::jsonb)
  into v_fp_messages
  from public.online_game_messages m
  join seat_map sm on sm.user_id = m.sender_user_id
  where m.online_game_id = p_game_id;

  for i in 0 .. p_player_count - 1 loop
    v_fp_slot := p_slots -> i;
    if (v_fp_slot ->> 'type') = 'human' then
      v_fp_result := case
        when coalesce((p_players -> i ->> 'surrendered')::boolean, false) then 'lose'
        when v_fp_ranks[i + 1] > 1 then 'lose'
        when v_fp_tied1 > 1 then 'tie'
        else 'win'
      end;
      insert into public.games (
        user_id, player_score, ai_score, result, turn_count, player_count,
        best_move_score, move_count, move_points_sum, rank, surrendered,
        players, longest_word, online_game_id, board_snapshot, messages
      ) values (
        (v_fp_slot ->> 'user_id')::uuid,
        (p_players -> i ->> 'score')::int,
        (
          select max((p_players -> k ->> 'score')::int)
          from generate_series(0, p_player_count - 1) k
          where k <> i
        ),
        v_fp_result,
        p_turn_count,
        p_player_count,
        nullif((p_players -> i ->> 'bestMoveScore')::int, 0),
        nullif((p_players -> i ->> 'moveCount')::int, 0),
        nullif((p_players -> i ->> 'moveScoreSum')::int, 0),
        v_fp_ranks[i + 1],
        coalesce((p_players -> i ->> 'surrendered')::boolean, false),
        v_fp_players_json,
        nullif(p_players -> i ->> 'longestWord', ''),
        p_game_id,
        v_fp_snapshot,
        v_fp_messages
      );
    end if;
  end loop;
end;
$function$;

revoke all on function public._finish_online_game_records(uuid, jsonb, jsonb, jsonb, int, int) from public;
revoke all on function public._finish_online_game_records(uuid, jsonb, jsonb, jsonb, int, int) from anon;
revoke all on function public._finish_online_game_records(uuid, jsonb, jsonb, jsonb, int, int) from authenticated;
