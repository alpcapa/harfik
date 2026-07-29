-- Kelimeki — Canlı oyun bitişinde `games.board_snapshot`'ı da doldur.
--
-- online_game_finish_to_games migration'ı (29 Temmuz 2026) board_snapshot'ı
-- bilinçli olarak NULL bırakmıştı (v1) — client tarafındaki
-- serializeBoardSnapshot'ın (src/utils/boardSnapshot.ts) SQL karşılığı ayrı
-- bir adıma bırakılmıştı. Kullanıcı gerçek bir Canlı oyunu Tüm Oyunlarım'da
-- açtığında "Bu oyun için tahta görüntüsü kaydedilmemiş." mesajını görünce
-- bunun eklenmesini istedi.
--
-- serializeBoardSnapshot yalnızca dolu hücreleri {r,c,l,o,w?} olarak tutar:
-- l = harf (joker ise wildLetter, ama submit_move'un play dalı zaten wild
-- taşlarda 'letter' alanını wildLetter'a eşitliyor — bkz. aşağıdaki
-- v_placed_tile inşası, satır ~189-193 — bu yüzden burada da doğrudan
-- 'letter' okunabiliyor, ayrı bir case gerekmiyor), o = owner (koltuk
-- indeksi), w = yalnızca joker taşlarda true (yoksa hiç yazılmıyor).
-- v_board zaten submit_move'un aynı transaction'ında güncel hâliyle elde
-- bulunduğundan (bitiş dalından hemen önce hesaplanan son hamle dahil),
-- ekstra bir sorguya gerek yok — 13x13'ü tarayıp dolu hücreleri topluyoruz.
--
-- Yalnızca bundan sonra biten Canlı oyunlar için geçerli — daha önce
-- bitmiş oyunların board_snapshot'ı geriye dönük doldurulmuyor (online
-- state zaten iş bitince başka bir yerde saklanmıyor, geri getirilemez).

create or replace function public.submit_move(p_game_id uuid, p_action text, p_placements jsonb DEFAULT NULL::jsonb, p_exchange_letters jsonb DEFAULT NULL::jsonb, p_words jsonb DEFAULT '[]'::jsonb, p_word_scores jsonb DEFAULT NULL::jsonb, p_base_points integer DEFAULT 0, p_lost_shares jsonb DEFAULT '[]'::jsonb)
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
  v_fp_scores int[];
  v_fp_ranks int[];
  v_fp_rank int;
  v_fp_tied1 int;
  v_fp_sorted_idx int[];
  v_fp_players_json jsonb;
  v_fp_slot jsonb;
  v_fp_result text;
  v_fp_snapshot jsonb;
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
    -- YZ'nin sırası: kimse "sahibi" olmadığından, oyunun herhangi bir
    -- katılımcısı YZ adına gönderebilir (bkz. supabase/functions/play-ai-turn/).
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

      -- Tahtaya sunucudaki gerçek taşın kendi puanıyla yaz.
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

    -- Jokerli bitiş bonusu: TAMAMEN sunucuda, client'a hiç güvenmeden.
    if v_rack_count_after = 0 and coalesce(array_length(v_bag_arr, 1), 0) = 0
       and v_actual_joker_count = v_tile_count then
      v_finish_joker_count := v_actual_joker_count;
      v_finish_bonus := case when v_finish_joker_count >= 2 then 50 when v_finish_joker_count = 1 then 25 else 0 end;
    end if;

    -- Bölge vergisi paylarını doğrula (toplam basePts'i aşamaz).
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
    -- Taş değiştirmek de pas gibi puansız bir turdur (aynı sayaca dahil —
    -- bkz. CLAUDE.md "Oyun bitişi").
    v_consecutive_passes := v_consecutive_passes + 1;

  else -- pass
    v_tile_count := 0;
    v_new_rack := array(select jsonb_array_elements(v_rack));
    v_rack_count_after := coalesce(array_length(v_new_rack, 1), 0);
    v_consecutive_passes := v_consecutive_passes + 1;
  end if;

  -- Tüm oyuncuların rafları (gizli tablo) — yalnızca sırası gelenin rafı değişti.
  v_new_racks := '[]'::jsonb;
  for i in 0 .. v_player_count - 1 loop
    if i = v_current then
      v_new_racks := v_new_racks || jsonb_build_array(to_jsonb(v_new_rack));
    else
      v_new_racks := v_new_racks || jsonb_build_array(v_racks -> i);
    end if;
  end loop;

  -- Herkese açık players dizisini güncelle.
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
        v_player := v_player || jsonb_build_object(
          'score', (v_player ->> 'score')::int + v_actor_score_delta,
          'bestMoveScore', greatest((v_player ->> 'bestMoveScore')::int, p_base_points),
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

  -- Bitiş kontrolü: herhangi bir oyuncunun rafı boşken torba da boşsa,
  -- ya da art arda pas/değişim eşiği (activePlayerCount * MAX_PASS_ROUNDS —
  -- surrender henüz desteklenmediğinden activePlayerCount = player_count).
  v_is_game_over := false;
  if coalesce(array_length(v_bag_arr, 1), 0) = 0 then
    for i in 0 .. v_player_count - 1 loop
      if ((v_new_players -> i) ->> 'rackCount')::int = 0 then
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

    -- Faz 3.5: oyun bitince her insan katılımcı için kendi hesabına bir
    -- `games` kaydı oluştur (bkz. dosya başındaki not) — rankPlayers'daki
    -- ile aynı "competition ranking".
    v_fp_scores := array(
      select (v_new_players -> gs ->> 'score')::int
      from generate_series(0, v_player_count - 1) gs
    );
    v_fp_ranks := array_fill(0, array[v_player_count]);
    for i in 0 .. v_player_count - 1 loop
      v_fp_rank := 1;
      for j in 0 .. v_player_count - 1 loop
        if v_fp_scores[j + 1] > v_fp_scores[i + 1] then
          v_fp_rank := v_fp_rank + 1;
        end if;
      end loop;
      v_fp_ranks[i + 1] := v_fp_rank;
    end loop;
    v_fp_tied1 := 0;
    for i in 0 .. v_player_count - 1 loop
      if v_fp_ranks[i + 1] = 1 then
        v_fp_tied1 := v_fp_tied1 + 1;
      end if;
    end loop;

    -- players jsonb snapshot'ı rankPlayers (src/utils/ranking.ts) ile aynı
    -- sırayla inşa edilmeli: skora göre AZALAN, eşitlikte orijinal koltuk
    -- sırası korunarak (stable sort) — computeRanks (client) sıralama
    -- yapmıyor, girdinin zaten bu sırada olduğunu varsayıyor.
    v_fp_sorted_idx := array(
      select gs
      from generate_series(0, v_player_count - 1) gs
      order by (v_new_players -> gs ->> 'score')::int desc, gs asc
    );

    v_fp_players_json := '[]'::jsonb;
    for i in 1 .. v_player_count loop
      v_fp_players_json := v_fp_players_json || jsonb_build_array(jsonb_build_object(
        'name', (v_new_players -> v_fp_sorted_idx[i] ->> 'name'),
        'score', (v_new_players -> v_fp_sorted_idx[i] ->> 'score')::int,
        'is_ai', (v_new_players -> v_fp_sorted_idx[i] ->> 'isAI')::boolean,
        'surrendered', (v_new_players -> v_fp_sorted_idx[i] ->> 'surrendered')::boolean,
        'colorIndex', (v_new_players -> v_fp_sorted_idx[i] ->> 'colorIndex')::int
      ));
    end loop;

    -- Tahta anlık görüntüsü — client'taki serializeBoardSnapshot'ın SQL
    -- karşılığı: yalnızca dolu hücreler {r,c,l,o,w?} olarak. v_board bu
    -- transaction'da güncel (son hamle dahil) hâliyle elde bulunuyor.
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'r', gr,
        'c', gc,
        'l', (v_board -> gr -> gc) ->> 'letter',
        'o', coalesce(((v_board -> gr -> gc) ->> 'owner')::int, 0)
      ) || case when ((v_board -> gr -> gc) ->> 'wild')::boolean is true
                then jsonb_build_object('w', true)
                else '{}'::jsonb
           end
    ), '[]'::jsonb)
    into v_fp_snapshot
    from generate_series(0, 12) gr, generate_series(0, 12) gc
    where jsonb_typeof(v_board -> gr -> gc) <> 'null';

    for i in 0 .. v_player_count - 1 loop
      v_fp_slot := v_slots -> i;
      if (v_fp_slot ->> 'type') = 'human' then
        v_fp_result := case
          when v_fp_ranks[i + 1] > 1 then 'lose'
          when v_fp_tied1 > 1 then 'tie'
          else 'win'
        end;
        insert into public.games (
          user_id, player_score, ai_score, result, turn_count, player_count,
          best_move_score, move_count, move_points_sum, rank, surrendered,
          players, longest_word, online_game_id, board_snapshot
        ) values (
          (v_fp_slot ->> 'user_id')::uuid,
          (v_new_players -> i ->> 'score')::int,
          (
            select max((v_new_players -> k ->> 'score')::int)
            from generate_series(0, v_player_count - 1) k
            where k <> i
          ),
          v_fp_result,
          v_turn_count + 1,
          v_player_count,
          nullif((v_new_players -> i ->> 'bestMoveScore')::int, 0),
          nullif((v_new_players -> i ->> 'moveCount')::int, 0),
          nullif((v_new_players -> i ->> 'moveScoreSum')::int, 0),
          v_fp_ranks[i + 1],
          false,
          v_fp_players_json,
          nullif(v_new_players -> i ->> 'longestWord', ''),
          p_game_id,
          v_fp_snapshot
        );
      end if;
    end loop;
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
$function$
