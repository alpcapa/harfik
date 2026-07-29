-- Canlı (online) oyun — 3. faz, 2. adım: bir oyun 'active' olduğunda
-- tahtayı kurup torbayı sunucu tarafında karıştırıp rafları dağıtan init
-- fonksiyonu. Bilinçli olarak sunucu tarafında karıştırılıyor — client'ın
-- gönderdiği bir "hazır state"e güvenmek, rafını kendi lehine kuran bir
-- client'a açık kapı bırakırdı (bkz. CLAUDE.md'deki anti-hile notu).
--
-- Doğrudan client'a açık DEĞİL (authenticated'e execute grant'i yok) —
-- yalnızca create_online_game (hiç insan davetlisi yoksa, teoride) ve
-- respond_to_game_invite (son davet kabul edilip status 'active'e
-- geçtiğinde) içeriden çağırıyor. İkisi de zaten security definer olarak
-- çalıştığından fonksiyon sahibi bu iç çağrıyı yapabiliyor, ayrı bir grant
-- gerekmiyor.
--
-- İdempotent: online_game_states'te zaten bir satır varsa (iki tetikleyici
-- yoldan yanlışlıkla iki kez çağrılırsa) sessizce hiçbir şey yapmadan döner.
create or replace function public.init_online_game_state(p_game_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
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

  -- Torba: sabit 100 taşlık Türkçe dağılım (src/data/tiles.ts ile birebir
  -- aynı sayılar), sunucu tarafında karıştırılır.
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

  -- Boş 13x13 tahta ((Tile|null)[][] — src/game/types.ts).
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

    -- cornersFor (src/game/constants.ts): 2 oyunculu 0/3, 4 oyunculu 0/1/2/3.
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
      'longestWord', '',
      'moveCount', 0,
      'moveScoreSum', 0
    ));

    v_racks := v_racks || jsonb_build_array(to_jsonb(v_bag_arr[v_from:v_to]));
  end loop;

  insert into public.online_game_states (
    online_game_id, board, bonuses, players, current, turn_count,
    consecutive_passes, is_game_over, end_reason, last_move_cells,
    bag_count, started_at, updated_at
  ) values (
    -- bonuses: buildInitialBonuses() — tahtanın tam ortası (SIZE=13,
    -- floor(13/2)=6) tek X3 hücresi.
    p_game_id, v_board, '{"6,6": "tw"}'::jsonb, v_players, 0, 0,
    0, false, null, '[]'::jsonb,
    array_length(v_bag_arr, 1) - v_player_count * 7, now(), now()
  );

  insert into public.online_game_secrets (online_game_id, bag, racks, updated_at)
  values (
    p_game_id,
    to_jsonb(v_bag_arr[(v_player_count * 7 + 1) : array_length(v_bag_arr, 1)]),
    v_racks,
    now()
  );
end;
$$;

revoke all on function public.init_online_game_state(uuid) from public, anon, authenticated;

-- ── Tetikleyiciler ────────────────────────────────────────────────────────────
-- create_online_game: hiç insan davetlisi yoksa (bugünkü kompozisyon
-- kurallarında pratikte imkansız ama fonksiyon defensif olarak bu dalı
-- koruyordu) oyun beklemeden 'active' olur — bu durumda da state hemen
-- kurulmalı.
create or replace function public.create_online_game(p_player_count int, p_slots jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_game_id uuid;
  v_slot jsonb;
  v_slot_type text;
  v_slot_user uuid;
  v_seen_users uuid[] := array[]::uuid[];
  v_pending_invites int := 0;
begin
  if v_uid is null then
    raise exception 'Oturum açık değil.';
  end if;
  if p_player_count not in (2, 4) then
    raise exception 'Geçersiz oyuncu sayısı.';
  end if;
  if jsonb_array_length(p_slots) <> p_player_count then
    raise exception 'Koltuk sayısı oyuncu sayısıyla eşleşmiyor.';
  end if;

  v_slot := p_slots -> 0;
  if (v_slot ->> 'type') <> 'human' or (v_slot ->> 'user_id')::uuid <> v_uid then
    raise exception 'İlk koltuk oyunu kuran kişi olmalı.';
  end if;

  for i in 0 .. jsonb_array_length(p_slots) - 1 loop
    v_slot := p_slots -> i;
    v_slot_type := v_slot ->> 'type';
    if v_slot_type not in ('human', 'ai') then
      raise exception 'Geçersiz koltuk türü.';
    end if;

    if v_slot_type = 'human' then
      v_slot_user := (v_slot ->> 'user_id')::uuid;
      if v_slot_user is null then
        raise exception 'İnsan koltuğunda user_id eksik.';
      end if;
      if v_slot_user = any (v_seen_users) then
        raise exception 'Aynı kullanıcı birden fazla koltukta olamaz.';
      end if;
      v_seen_users := v_seen_users || v_slot_user;

      if v_slot_user <> v_uid and not exists (
        select 1 from public.friend_requests fr
        where fr.status = 'accepted'
          and ((fr.user_id = v_uid and fr.friend_id = v_slot_user)
            or (fr.user_id = v_slot_user and fr.friend_id = v_uid))
      ) then
        raise exception 'Yalnızca arkadaşlarını davet edebilirsin.';
      end if;
    end if;
  end loop;

  insert into public.online_games (created_by, player_count, slots)
  values (v_uid, p_player_count, p_slots)
  returning id into v_game_id;

  for i in 0 .. jsonb_array_length(p_slots) - 1 loop
    v_slot := p_slots -> i;
    if (v_slot ->> 'type') = 'human' and (v_slot ->> 'user_id')::uuid <> v_uid then
      insert into public.game_invites (online_game_id, invitee_id)
      values (v_game_id, (v_slot ->> 'user_id')::uuid);
      v_pending_invites := v_pending_invites + 1;
    end if;
  end loop;

  if v_pending_invites = 0 then
    update public.online_games set status = 'active', updated_at = now() where id = v_game_id;
    perform public.init_online_game_state(v_game_id);
  end if;

  return v_game_id;
end;
$$;

revoke all on function public.create_online_game(int, jsonb) from public, anon;
grant execute on function public.create_online_game(int, jsonb) to authenticated;

-- respond_to_game_invite: son bekleyen davet de kabul edilip oyun
-- 'active'e geçtiği an state hemen kuruluyor.
create or replace function public.respond_to_game_invite(p_invite_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_game_id uuid;
  v_remaining_pending int;
begin
  if v_uid is null then
    raise exception 'Oturum açık değil.';
  end if;

  select online_game_id into v_game_id
  from public.game_invites
  where id = p_invite_id and invitee_id = v_uid and status = 'pending';

  if v_game_id is null then
    raise exception 'Davet bulunamadı ya da zaten yanıtlanmış.';
  end if;

  update public.game_invites
    set status = case when p_accept then 'accepted' else 'declined' end,
        responded_at = now()
    where id = p_invite_id;

  if p_accept then
    select count(*) into v_remaining_pending
    from public.game_invites
    where online_game_id = v_game_id and status = 'pending';

    if v_remaining_pending = 0 then
      update public.online_games
        set status = 'active', updated_at = now()
        where id = v_game_id and status = 'pending';

      if found then
        perform public.init_online_game_state(v_game_id);
      end if;
    end if;
  end if;
end;
$$;

revoke all on function public.respond_to_game_invite(uuid, boolean) from public, anon;
grant execute on function public.respond_to_game_invite(uuid, boolean) to authenticated;
