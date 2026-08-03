-- Kelimeki — bir davet reddedilince oyunu ANINDA sonlandır.
--
-- Bulunan hata (3 Ağustos 2026, kullanıcı bildirdi): `respond_to_game_invite`
-- ret dalında yalnızca `game_invites.status`'u 'declined' yapıp
-- `online_games.status`'a hiç dokunmuyordu. Oyun `pending` kalıyor, daveti
-- GÖNDEREN kişinin "Bekleyen Oyunlar" listesinde (LiveGamesTab'ın
-- `my_role='creator' && status='pending'` kovası) 7 gün boyunca duruyordu —
-- `check_invite_expiry` `created_at + 7 gün` dolana kadar temizlemiyordu.
--
-- Bu, zaman aşımının beklediği belirsizliğin tam tersi bir durum: ret KESİN
-- bir cevap. Üstelik kompozisyon kuralı gereği (2 kişilikte iki koltuk da,
-- 4 kişilikte 2. ve 3. koltuklar zorunlu insan) tek bir ret kadroyu asla
-- tamamlanamaz hale getiriyor, yani oyun gerçekten ölü — yine de kullanıcıya
-- "yanıt bekleniyor" gibi görünüyordu.
--
-- Düzeltme: ret dalı oyunu doğrudan 'abandoned'a çeker. Bu, süresi dolan
-- davetlerin (`check_invite_expiry`) zaten kullandığı aynı son durum;
-- LiveGamesTab'ın üç kovası da yalnızca 'pending'/'active' eşlediğinden oyun
-- ANINDA her yerden kaybolur. Satır, "bu oyun neden bitti" kaydı olarak
-- duruyor (silinmiyor) — `game_invites`teki 'declined' satırıyla birlikte
-- reddin izini taşıyor.
create or replace function public.respond_to_game_invite(p_invite_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  else
    -- Ret: oyun bir daha asla başlayamaz, hemen sonlandır.
    update public.online_games
      set status = 'abandoned', updated_at = now()
      where id = v_game_id and status = 'pending';
  end if;
end;
$function$;
