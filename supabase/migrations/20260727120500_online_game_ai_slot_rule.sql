-- Canlı oyun kompozisyon kuralı: 2 kişilikte YZ'ye hiç izin verilmez (her
-- iki koltuk da insan olmalı); 4 kişilikte yalnızca 4. koltuk (index 3) YZ
-- olabilir, 2. ve 3. koltuklar (index 1-2) her zaman insan olmalı. Bu, bir
-- Canlı oyunun en az bir gerçek arkadaş katılımı garanti etmesi ve YZ'nin
-- sadece dolgu (4. koltuk) olarak kalması için — istemci tarafındaki
-- kurulum UI'ı zaten bu kuralı uygular, burada aynısı sunucu tarafında da
-- zorlanıyor (istemciyi atlayan doğrudan RPC çağrılarına karşı).
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

    if v_slot_type = 'ai' then
      if p_player_count = 2 then
        raise exception '2 kişilik Canlı oyunda her iki oyuncu da insan olmalı.';
      elsif p_player_count = 4 and i <> 3 then
        raise exception '4 kişilik Canlı oyunda yalnızca 4. koltuk Yapay Zeka olabilir.';
      end if;
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
  end if;

  return v_game_id;
end;
$$;
