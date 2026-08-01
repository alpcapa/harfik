-- Canlı oyunlarda da "en yüksek puanlı kelime" istatistiğini takip etmek
-- için: init_online_game_state her oyuncuyu bestWordScore:0 ile başlatır,
-- submit_move her 'play' hamlesinde p_word_scores'tan (word/score/x2/x3)
-- gerçek (çarpanlı) en yüksek tek kelime puanını hesaplayıp günceller,
-- _finish_online_game_records oyun bitince bunu games.best_word_score'a yazar.

CREATE OR REPLACE FUNCTION public.init_online_game_state(p_game_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_count int;
  v_slots jsonb;
  v_slot jsonb;
  v_slot_type text;
  v_full_bag jsonb;
  v_bag_arr jsonb[];
  v_players jsonb := '[]'::jsonb;
  v_racks jsonb := '[]'::jsonb;
  v_board jsonb;
  v_name text;
  v_corner int;
  v_from int;
  v_to int;
begin
  if exists (select 1 from public.online_game_states where online_game_id = p_game_id) then
    return;
  end if;

  select player_count, slots into v_player_count, v_slots
  from public.online_games where id = p_game_id;

  if v_player_count is null then
    raise exception 'Oyun bulunamadı.';
  end if;

  with tile_data (letter, pts, cnt) as (
    values
      ('?', 0, 2), ('A', 1, 12), ('B', 3, 2), ('C', 4, 2), ('Ç', 3, 2), ('D', 3, 2), ('E', 1, 8),
      ('F', 7, 1), ('G', 5, 1), ('Ğ', 8, 1), ('H', 5, 1), ('I', 2, 4), ('İ', 1, 7), ('J', 10, 1),
      ('K', 1, 7), ('L', 1, 7), ('M', 2, 4), ('N', 1, 5), ('O', 2, 3), ('Ö', 7, 1), ('P', 5, 1),
      ('R', 1, 6), ('S', 2, 3), ('Ş', 4, 2), ('T', 1, 5), ('U', 2, 3), ('Ü', 3, 2), ('V', 7, 1),
      ('Y', 3, 2), ('Z', 4, 2)
  ),
  expanded as (
    select td.letter, td.pts
    from tile_data td, generate_series(1, td.cnt)
  ),
  shuffled as (
    select letter, pts from expanded order by random()
  )
  select jsonb_agg(jsonb_build_object('letter', letter, 'pts', pts)) into v_full_bag from shuffled;

  v_bag_arr := array(select jsonb_array_elements(v_full_bag));

  select jsonb_agg(row_val) into v_board
  from (
    select (select jsonb_agg(null::jsonb) from generate_series(1, 13)) as row_val
    from generate_series(1, 13)
  ) t;

  for i in 0 .. v_player_count - 1 loop
    v_slot := v_slots -> i;
    v_slot_type := v_slot ->> 'type';
    v_from := i * 7 + 1;
    v_to := i * 7 + 7;

    if v_slot_type = 'human' then
      select coalesce(display_name, first_name) into v_name
      from public.profiles where id = (v_slot ->> 'user_id')::uuid;
      v_name := coalesce(v_name, 'Oyuncu ' || (i + 1));
    else
      v_name := case when v_player_count = 2 then 'Yapay Zeka' else 'Yapay Zeka ' || (i + 1) end;
    end if;

    v_corner := case
      when v_player_count = 2 then (case when i = 0 then 0 else 3 end)
      else i
    end;

    v_players := v_players || jsonb_build_array(jsonb_build_object(
      'name', v_name,
      'corners', jsonb_build_array(v_corner),
      'colorIndex', i % 4,
      'isAI', v_slot_type = 'ai',
      'surrendered', false,
      'rackCount', 7,
      'score', 0,
      'bestMoveScore', 0,
      'bestWordScore', 0,
      'longestWord', '',
      'moveCount', 0,
      'moveScoreSum', 0
    ));

    v_racks := v_racks || jsonb_build_array(to_jsonb(v_bag_arr[v_from:v_to]));
  end loop;

  insert into public.online_game_states (
    online_game_id, board, bonuses, players, current, turn_count,
    consecutive_passes, is_game_over, end_reason, last_move_cells,
    bag_count, started_at, updated_at, turn_deadline
  ) values (
    p_game_id, v_board, '{"6,6": "tw"}'::jsonb, v_players, 0, 0,
    0, false, null, '[]'::jsonb,
    array_length(v_bag_arr, 1) - v_player_count * 7, now(), now(), now() + interval '48 hours'
  );

  insert into public.online_game_secrets (online_game_id, bag, racks, updated_at)
  values (
    p_game_id,
    to_jsonb(v_bag_arr[(v_player_count * 7 + 1) : array_length(v_bag_arr, 1)]),
    v_racks,
    now()
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.submit_move(p_game_id uuid, p_action text, p_placements jsonb DEFAULT NULL::jsonb, p_exchange_letters jsonb DEFAULT NULL::jsonb, p_words jsonb DEFAULT '[]'::jsonb, p_word_scores jsonb DEFAULT NULL::jsonb, p_base_points integer DEFAULT 0, p_lost_shares jsonb DEFAULT '[]'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_rack_size constant int := 7;
  v_max_pass_rounds constant int := 2;
  v_uid uuid := auth.uid();
  v_player_count int;
  v_slots jsonb;
  v_current_slot jsonb;
  v_players jsonb;
  v_new_players jsonb;
  v_board jsonb;
  v_current int;
  v_turn_count int;
  v_consecutive_passes int;
  v_is_game_over boolean;
  v_end_reason text;
  v_last_move_cells jsonb;
  v_bag jsonb;
  v_racks jsonb;
  v_new_racks jsonb;
  v_rack jsonb;
  v_rack_arr jsonb[];
  v_bag_arr jsonb[];
  v_used boolean[];
  v_new_rack jsonb[];
  v_tile_count int;
  v_placement jsonb;
  v_r int;
  v_c int;
  v_letter text;
  v_wild boolean;
  v_wild_letter text;
  v_key text;
  v_matched_idx int;
  v_placed_tile jsonb;
  v_actual_joker_count int := 0;
  v_finish_joker_count int := 0;
  v_finish_bonus int := 0;
  v_rack_count_after int;
  v_draw_n int;
  v_share jsonb;
  v_to_idx int;
  v_amount int;
  v_shares_total int := 0;
  v_actor_net int;
  v_actor_score_delta int := 0;
  v_next int;
  v_player jsonb;
  v_new_longest text;
  v_remaining int;
  v_new_best_word_score int;
  v_word_entry jsonb;
  v_word_mult int;
  v_word_final int;
begin
  if v_uid is null then
    raise exception 'Oturum açık değil.';
  end if;
  if p_action not in ('play', 'pass', 'exchange') then
    raise exception 'Geçersiz eylem.';
  end if;

  select og.player_count, og.slots into v_player_count, v_slots
  from public.online_games og
  where og.id = p_game_id
  for update;

  if v_player_count is null then
    raise exception 'Oyun bulunamadı.';
  end if;

  select s.players, s.board, s.current, s.turn_count, s.consecutive_passes,
         s.is_game_over, s.last_move_cells
    into v_players, v_board, v_current, v_turn_count, v_consecutive_passes,
         v_is_game_over, v_last_move_cells
  from public.online_game_states s
  where s.online_game_id = p_game_id
  for update;

  if v_players is null then
    raise exception 'Oyun state''i henüz kurulmamış.';
  end if;
  if v_is_game_over then
    raise exception 'Oyun zaten bitti.';
  end if;

  v_current_slot := v_slots -> v_current;
  if (v_current_slot ->> 'type') = 'human' then
    if (v_current_slot ->> 'user_id')::uuid <> v_uid then
      raise exception 'Sıra sende değil.';
    end if;
  elsif (v_current_slot ->> 'type') = 'ai' then
    if not public.is_online_game_participant(p_game_id, v_uid) then
      raise exception 'Bu oyunun katılımcısı değilsin.';
    end if;
  else
    raise exception 'Sıra sende değil.';
  end if;

  select sec.bag, sec.racks into v_bag, v_racks
  from public.online_game_secrets sec
  where sec.online_game_id = p_game_id
  for update;

  v_rack := v_racks -> v_current;
  v_bag_arr := array(select jsonb_array_elements(v_bag));

  if p_action = 'play' then
    if p_placements is null or jsonb_array_length(p_placements) = 0 then
      raise exception 'Yerleştirilecek taş yok.';
    end if;
    v_tile_count := jsonb_array_length(p_placements);
    if v_tile_count > v_rack_size then
      raise exception 'Rafta olmayan sayıda taş oynanmaya çalışıldı.';
    end if;
    if p_base_points < 0 then
      raise exception 'Geçersiz puan.';
    end if;

    v_rack_arr := array(select jsonb_array_elements(v_rack));
    v_used := array_fill(false, array[array_length(v_rack_arr, 1)]);
    v_last_move_cells := '[]'::jsonb;

    for i in 0 .. v_tile_count - 1 loop
      v_placement := p_placements -> i;
      v_r := (v_placement ->> 'r')::int;
      v_c := (v_placement ->> 'c')::int;
      if v_r is null or v_c is null or v_r < 0 or v_r > 12 or v_c < 0 or v_c > 12 then
        raise exception 'Geçersiz hücre.';
      end if;
      if jsonb_typeof(v_board -> v_r -> v_c) <> 'null' then
        raise exception 'Dolu hücreye taş konamaz.';
      end if;

      v_wild := coalesce((v_placement ->> 'wild')::boolean, false);
      v_letter := v_placement ->> 'letter';
      v_key := case when v_wild then '?' else v_letter end;

      v_matched_idx := null;
      for j in 1 .. array_length(v_rack_arr, 1) loop
        if not v_used[j] and (v_rack_arr[j] ->> 'letter') = v_key then
          v_matched_idx := j;
          exit;
        end if;
      end loop;
      if v_matched_idx is null then
        raise exception 'Rafında olmayan taş oynanmaya çalışıldı.';
      end if;
      v_used[v_matched_idx] := true;

      v_placed_tile := jsonb_build_object(
        'letter', v_letter,
        'pts', (v_rack_arr[v_matched_idx] ->> 'pts')::int,
        'owner', v_current
      );
      if v_wild then
        v_wild_letter := coalesce(v_placement ->> 'wildLetter', v_letter);
        v_placed_tile := v_placed_tile || jsonb_build_object(
          'wild', true, 'wildLetter', v_wild_letter, 'letter', v_wild_letter
        );
        v_actual_joker_count := v_actual_joker_count + 1;
      end if;

      v_board := jsonb_set(v_board, array[v_r::text, v_c::text], v_placed_tile);
      v_last_move_cells := v_last_move_cells || jsonb_build_array(jsonb_build_array(v_r, v_c));
    end loop;

    v_new_rack := array[]::jsonb[];
    for j in 1 .. array_length(v_rack_arr, 1) loop
      if not v_used[j] then
        v_new_rack := v_new_rack || v_rack_arr[j];
      end if;
    end loop;

    v_draw_n := least(v_rack_size - coalesce(array_length(v_new_rack, 1), 0), coalesce(array_length(v_bag_arr, 1), 0));
    if v_draw_n > 0 then
      v_new_rack := v_new_rack || v_bag_arr[1:v_draw_n];
      v_bag_arr := case when array_length(v_bag_arr, 1) > v_draw_n
        then v_bag_arr[v_draw_n + 1 : array_length(v_bag_arr, 1)]
        else array[]::jsonb[]
      end;
    end if;

    v_rack_count_after := coalesce(array_length(v_new_rack, 1), 0);
    v_consecutive_passes := 0;

    if v_rack_count_after = 0 and coalesce(array_length(v_bag_arr, 1), 0) = 0
       and v_actual_joker_count = v_tile_count then
      v_finish_joker_count := v_actual_joker_count;
      v_finish_bonus := case when v_finish_joker_count >= 2 then 50 when v_finish_joker_count = 1 then 25 else 0 end;
    end if;

    for i in 0 .. jsonb_array_length(p_lost_shares) - 1 loop
      v_share := p_lost_shares -> i;
      v_to_idx := (v_share ->> 'to')::int;
      v_amount := (v_share ->> 'amount')::int;
      if v_to_idx is null or v_to_idx < 0 or v_to_idx >= v_player_count or v_to_idx = v_current then
        raise exception 'Geçersiz bölge vergisi hedefi.';
      end if;
      if v_amount is null or v_amount < 0 then
        raise exception 'Geçersiz bölge vergisi tutarı.';
      end if;
      v_shares_total := v_shares_total + v_amount;
    end loop;
    if v_shares_total > p_base_points then
      raise exception 'Bölge vergisi toplamı kazanılan puanı aşamaz.';
    end if;

    v_actor_net := p_base_points - v_shares_total;
    v_actor_score_delta := v_actor_net + v_finish_bonus;

  elsif p_action = 'exchange' then
    if p_exchange_letters is null or jsonb_array_length(p_exchange_letters) = 0 then
      raise exception 'Değiştirilecek taş yok.';
    end if;
    if coalesce(array_length(v_bag_arr, 1), 0) = 0 then
      raise exception 'Torba boş — taş değiştirilemez.';
    end if;
    v_tile_count := jsonb_array_length(p_exchange_letters);
    if v_tile_count > v_rack_size then
      raise exception 'Rafta olmayan sayıda taş değiştirilmeye çalışıldı.';
    end if;

    v_rack_arr := array(select jsonb_array_elements(v_rack));
    v_used := array_fill(false, array[array_length(v_rack_arr, 1)]);

    for i in 0 .. v_tile_count - 1 loop
      v_letter := p_exchange_letters ->> i;
      v_matched_idx := null;
      for j in 1 .. array_length(v_rack_arr, 1) loop
        if not v_used[j] and (v_rack_arr[j] ->> 'letter') = v_letter then
          v_matched_idx := j;
          exit;
        end if;
      end loop;
      if v_matched_idx is null then
        raise exception 'Rafında olmayan taş değiştirilmeye çalışıldı.';
      end if;
      v_used[v_matched_idx] := true;
    end loop;

    v_new_rack := array[]::jsonb[];
    for j in 1 .. array_length(v_rack_arr, 1) loop
      if not v_used[j] then
        v_new_rack := v_new_rack || v_rack_arr[j];
      else
        v_bag_arr := v_bag_arr || v_rack_arr[j];
      end if;
    end loop;
    v_bag_arr := array(select unnest(v_bag_arr) order by random());

    v_draw_n := least(v_tile_count, coalesce(array_length(v_bag_arr, 1), 0));
    if v_draw_n > 0 then
      v_new_rack := v_new_rack || v_bag_arr[1:v_draw_n];
      v_bag_arr := case when array_length(v_bag_arr, 1) > v_draw_n
        then v_bag_arr[v_draw_n + 1 : array_length(v_bag_arr, 1)]
        else array[]::jsonb[]
      end;
    end if;

    v_rack_count_after := coalesce(array_length(v_new_rack, 1), 0);
    v_consecutive_passes := v_consecutive_passes + 1;

  else -- pass
    v_tile_count := 0;
    v_new_rack := array(select jsonb_array_elements(v_rack));
    v_rack_count_after := coalesce(array_length(v_new_rack, 1), 0);
    v_consecutive_passes := v_consecutive_passes + 1;
  end if;

  v_new_racks := '[]'::jsonb;
  for i in 0 .. v_player_count - 1 loop
    if i = v_current then
      v_new_racks := v_new_racks || jsonb_build_array(to_jsonb(v_new_rack));
    else
      v_new_racks := v_new_racks || jsonb_build_array(v_racks -> i);
    end if;
  end loop;

  v_new_players := '[]'::jsonb;
  for i in 0 .. v_player_count - 1 loop
    v_player := v_players -> i;
    if i = v_current then
      if p_action = 'play' then
        v_new_longest := v_player ->> 'longestWord';
        for k in 0 .. jsonb_array_length(p_words) - 1 loop
          if char_length(p_words ->> k) > char_length(v_new_longest) then
            v_new_longest := p_words ->> k;
          end if;
        end loop;

        v_new_best_word_score := coalesce((v_player ->> 'bestWordScore')::int, 0);
        for k in 0 .. coalesce(jsonb_array_length(p_word_scores), 0) - 1 loop
          v_word_entry := p_word_scores -> k;
          v_word_mult := case
            when coalesce((v_word_entry ->> 'x3')::boolean, false) then 3
            when coalesce((v_word_entry ->> 'x2')::boolean, false) then 2
            else 1
          end;
          v_word_final := coalesce((v_word_entry ->> 'score')::int, 0) * v_word_mult;
          if v_word_final > v_new_best_word_score then
            v_new_best_word_score := v_word_final;
          end if;
        end loop;

        v_player := v_player || jsonb_build_object(
          'score', (v_player ->> 'score')::int + v_actor_score_delta,
          'bestMoveScore', greatest((v_player ->> 'bestMoveScore')::int, p_base_points),
          'bestWordScore', v_new_best_word_score,
          'longestWord', v_new_longest,
          'moveCount', (v_player ->> 'moveCount')::int + 1,
          'moveScoreSum', (v_player ->> 'moveScoreSum')::int + p_base_points,
          'rackCount', v_rack_count_after
        );
      else
        v_player := v_player || jsonb_build_object('rackCount', v_rack_count_after);
      end if;
    elsif p_action = 'play' then
      for k in 0 .. jsonb_array_length(p_lost_shares) - 1 loop
        v_share := p_lost_shares -> k;
        if (v_share ->> 'to')::int = i then
          v_player := jsonb_set(
            v_player, '{score}',
            to_jsonb(((v_player ->> 'score')::int + (v_share ->> 'amount')::int))
          );
        end if;
      end loop;
    end if;
    v_new_players := v_new_players || jsonb_build_array(v_player);
  end loop;

  v_is_game_over := false;
  if coalesce(array_length(v_bag_arr, 1), 0) = 0 then
    for i in 0 .. v_player_count - 1 loop
      if not coalesce(((v_new_players -> i) ->> 'surrendered')::boolean, false)
         and ((v_new_players -> i) ->> 'rackCount')::int = 0 then
        v_is_game_over := true;
        exit;
      end if;
    end loop;
  end if;
  if not v_is_game_over and v_consecutive_passes >= v_player_count * v_max_pass_rounds then
    v_is_game_over := true;
  end if;

  if v_is_game_over then
    v_end_reason := 'normal';
    for i in 0 .. v_player_count - 1 loop
      v_remaining := 0;
      for k in 0 .. jsonb_array_length(v_new_racks -> i) - 1 loop
        v_remaining := v_remaining + ((v_new_racks -> i -> k) ->> 'pts')::int;
      end loop;
      v_new_players := jsonb_set(
        v_new_players,
        array[i::text, 'score'],
        to_jsonb(greatest(0, ((v_new_players -> i) ->> 'score')::int - v_remaining))
      );
    end loop;

    perform public._finish_online_game_records(
      p_game_id, v_board, v_new_players, v_slots, v_player_count, v_turn_count + 1
    );
  end if;

  v_next := (v_current + 1) % v_player_count;

  update public.online_game_secrets
    set bag = to_jsonb(v_bag_arr), racks = v_new_racks, updated_at = now()
    where online_game_id = p_game_id;

  update public.online_game_states
    set board = v_board,
        players = v_new_players,
        current = v_next,
        turn_count = v_turn_count + 1,
        consecutive_passes = v_consecutive_passes,
        is_game_over = v_is_game_over,
        end_reason = v_end_reason,
        last_move_cells = coalesce(v_last_move_cells, '[]'::jsonb),
        bag_count = coalesce(array_length(v_bag_arr, 1), 0),
        turn_deadline = case when v_is_game_over then null else now() + interval '48 hours' end,
        deadline_warning_sent_at = null,
        updated_at = now()
    where online_game_id = p_game_id;

  insert into public.online_game_moves (
    online_game_id, turn, player_index, player_user_id, action,
    words, word_scores, points, lost_shares, tile_count, placements,
    finish_joker_count, bingo
  ) values (
    p_game_id, v_turn_count, v_current, v_uid, p_action,
    coalesce(p_words, '[]'::jsonb), p_word_scores,
    case when p_action = 'play' then v_actor_score_delta else 0 end,
    case when p_action = 'play' and jsonb_array_length(p_lost_shares) > 0 then p_lost_shares else null end,
    v_tile_count,
    case when p_action = 'play' then p_placements else null end,
    case when p_action = 'play' then v_finish_joker_count else 0 end,
    case when p_action = 'play' then (v_tile_count >= v_rack_size) else false end
  );

  if v_is_game_over then
    update public.online_games set status = 'finished', updated_at = now() where id = p_game_id;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public._finish_online_game_records(p_game_id uuid, p_board jsonb, p_players jsonb, p_slots jsonb, p_player_count integer, p_turn_count integer)
 RETURNS void
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
        players, longest_word, online_game_id, board_snapshot, messages,
        best_word_score
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
        v_fp_messages,
        nullif((p_players -> i ->> 'bestWordScore')::int, 0)
      );
    end if;
  end loop;
end;
$function$;
