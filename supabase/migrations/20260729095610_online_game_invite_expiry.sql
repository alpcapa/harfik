-- Canlı oyun davetleri için 7 günlük zaman aşımı: bir oyun `pending`
-- durumunda (en az bir davet hâlâ yanıtlanmamış) 7 gün kalırsa oyun
-- tamamen iptal edilir (status='abandoned') — kimseye ceza yok, yerel
-- oyundaki ABANDON_TIMEOUT_MS ile aynı süre/gerekçe (gameStorage.ts).
-- check_turn_timeout ile aynı "hafif" desen: cron yok, no-op RPC'yi
-- herhangi bir katılımcının istemcisi tetikler (bkz. CLAUDE.md).

create or replace function public.check_invite_expiry(p_game_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_game record;
begin
  if v_uid is null then
    raise exception 'Oturum açık değil.';
  end if;

  select * into v_game from public.online_games where id = p_game_id for update;
  if v_game is null then
    raise exception 'Oyun bulunamadı.';
  end if;

  -- "Taraf" kontrolü: online_games_select_party RLS politikasıyla aynı
  -- desen (kurucu YA DA herhangi bir durumdaki davetli) — is_online_game_participant
  -- burada kullanılamaz çünkü o yalnızca accepted davetlileri sayar, henüz
  -- yanıtlanmamış (pending) bir davetlinin de bu süpürmeyi tetikleyebilmesi
  -- gerekiyor.
  if not (
    v_game.created_by = v_uid
    or exists (
      select 1 from public.game_invites gi
      where gi.online_game_id = p_game_id and gi.invitee_id = v_uid
    )
  ) then
    raise exception 'Bu oyunun tarafı değilsin.';
  end if;

  if v_game.status <> 'pending' then
    return;
  end if;
  if now() - v_game.created_at <= interval '7 days' then
    return;
  end if;

  update public.online_games
    set status = 'abandoned', updated_at = now()
    where id = p_game_id and status = 'pending';
end;
$$;

revoke all on function public.check_invite_expiry(uuid) from public, anon;
grant execute on function public.check_invite_expiry(uuid) to authenticated;
