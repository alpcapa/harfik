-- list_my_online_games'e my_invite_id ekler — 5. adımdaki Kabul/Reddet
-- akışı, respond_to_game_invite(p_invite_id, p_accept) RPC'sini çağırmak
-- için game_invites.id'ye ihtiyaç duyuyor, önceki sürüm bunu döndürmüyordu.
-- Dönüş tablosunun sütunları değiştiğinden create or replace yetmiyor,
-- önce drop edilmesi gerekiyor.
drop function if exists public.list_my_online_games();

create function public.list_my_online_games()
returns table (
  id uuid,
  created_by uuid,
  player_count int,
  status text,
  slots jsonb,
  created_at timestamptz,
  my_role text,
  my_invite_status text,
  my_invite_id uuid
)
language sql
security definer
set search_path = public
stable
as $$
  select
    og.id, og.created_by, og.player_count, og.status, og.slots, og.created_at,
    case when og.created_by = auth.uid() then 'creator' else 'invitee' end as my_role,
    gi.status as my_invite_status,
    gi.id as my_invite_id
  from public.online_games og
  left join public.game_invites gi
    on gi.online_game_id = og.id and gi.invitee_id = auth.uid()
  where og.created_by = auth.uid()
     or exists (
       select 1 from public.game_invites gi2
       where gi2.online_game_id = og.id and gi2.invitee_id = auth.uid()
     )
  order by og.created_at desc;
$$;

revoke all on function public.list_my_online_games() from public, anon;
grant execute on function public.list_my_online_games() to authenticated;
