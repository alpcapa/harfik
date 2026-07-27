-- list_my_online_games'i genişletir:
-- 1) my_invite_id — Kabul/Reddet akışı respond_to_game_invite'ı çağırmak
--    için game_invites.id'ye ihtiyaç duyuyor, önceki sürüm bunu döndürmüyordu.
-- 2) slots içindeki her insan koltuğu ad/avatar/arkadaşlık ilişkisi VE o
--    koltuğun kendi davet durumuyla zenginleştiriliyor (name, avatar_url,
--    relation, invite_status) — davet edilen kişi kiminle oynayacağını
--    (yalnızca daveti gönderenle değil, diğer davetli oyuncularla da) ve
--    onların daveti kabul edip etmediğini görebilsin. `relation` ayrıca
--    davet kabul edildikten sonra "bu kişileri arkadaş eklemek ister
--    misin?" önerisinde henüz arkadaş olunmayanları filtrelemek için
--    istemci tarafında kullanılıyor.
-- `relation` değerleri search_users_for_friend'daki aynı sözlük:
-- 'self' | 'accepted' | 'pending_outgoing' | 'pending_incoming' | null.
-- `invite_status`, o koltuktaki kişinin KENDİ game_invites satırının
-- durumu ('pending'|'accepted'|'declined'); kurucunun kendi koltuğu için
-- hiç davet satırı olmadığından null'dur (istemci bunu created_by ile
-- karşılaştırıp "Davet gönderen" olarak gösterir).
-- profiles.select RLS'i owner-or-admin'e kilitli olduğundan (diğer
-- security-definer RPC'lerle aynı gerekçe) bu fonksiyon da security
-- definer olmak zorunda; slots zaten yalnızca bu oyunun tarafı olan
-- çağıranın erişebildiği satırlarda döndüğünden (WHERE koşulu), başka bir
-- yetki sızıntısı yok.
--
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
    og.id,
    og.created_by,
    og.player_count,
    og.status,
    (
      select jsonb_agg(
        case
          when (elem.slot ->> 'type') = 'human' then
            elem.slot || jsonb_build_object(
              'name', coalesce(p.display_name, p.first_name),
              'avatar_url', p.avatar_url,
              'relation', case
                when (elem.slot ->> 'user_id')::uuid = auth.uid() then 'self'
                when fr.status = 'accepted' then 'accepted'
                when fr.user_id = auth.uid() then 'pending_outgoing'
                when fr.friend_id = auth.uid() then 'pending_incoming'
                else null
              end,
              'invite_status', gi_slot.status
            )
          else elem.slot
        end
        order by elem.ord
      )
      from jsonb_array_elements(og.slots) with ordinality as elem(slot, ord)
      left join public.profiles p
        on p.id = (elem.slot ->> 'user_id')::uuid and (elem.slot ->> 'type') = 'human'
      left join public.friend_requests fr
        on (elem.slot ->> 'type') = 'human'
        and ((fr.user_id = auth.uid() and fr.friend_id = (elem.slot ->> 'user_id')::uuid)
          or (fr.user_id = (elem.slot ->> 'user_id')::uuid and fr.friend_id = auth.uid()))
      left join public.game_invites gi_slot
        on (elem.slot ->> 'type') = 'human'
        and gi_slot.online_game_id = og.id
        and gi_slot.invitee_id = (elem.slot ->> 'user_id')::uuid
    ) as slots,
    og.created_at,
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
