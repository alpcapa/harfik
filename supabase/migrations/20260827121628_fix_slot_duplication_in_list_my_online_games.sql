-- Slot dizisi ÇOĞALIYORDU: `list_my_online_games` slotları üç LEFT JOIN ile
-- kurup `jsonb_agg` yapıyordu. `friend_requests` bir slot için İKİ satır
-- eşlediğinde (iki kişi birbirine istek gönderip `handle_friend_request_insert`
-- ikisini de 'accepted' yaptığında — bu bilinçli bir özellik, hata değil) o
-- slot diziye iki kez giriyor ve SONRAKİ TÜM İNDEKSLER KAYIYOR.
--
-- 27 Ağustos 2026'da bir kullanıcı bildirdi: 4 kişilik oyunda kendi yeşil
-- köşesine taş koyamıyor, "İlk kelimen kendi köşe karesine değmeli" diyor;
-- MOR (YZ) köşesine koyunca "geçerli" diyor ama OYNA pasif kalıyor.
-- Ölçüldü: RPC 4 slotluk oyun için 5 eleman döndürüyordu
-- ([Ironman, Cem, Cem, Fb1907, ai]), istemcinin `slots.indexWhere(...)` ile
-- bulduğu koltuk 2 yerine 3 çıkıyordu. İstemci o koltuğun rafını/rengini/
-- köşesini kullanıyor; sunucu (`submit_move`) ham `og.slots`'u okuduğundan
-- doğru koltuğu biliyor — OYNA'nın pasif kalması bu yüzden DOĞRU yarısıydı.
--
-- Düzeltme: join YOK. Her alan skaler alt sorgudan geliyor, yani slot başına
-- tam bir satır üretilmesi yapısal olarak garanti — ileride başka bir tabloda
-- mükerrer satır oluşsa da dizi çoğalamaz.
--
-- Yan kazanç: `relation` artık DETERMİNİSTİK. Eskiden karşılıklı çiftte
-- hangi satırın join'e düştüğü belirsizdi ve 'pending_outgoing' ile
-- 'pending_incoming' arasında salınabiliyordu; şimdi öncelik sırası açıkça
-- yazılı (self → accepted → outgoing → incoming).
create or replace function public.list_my_online_games()
returns table(
  id uuid, created_by uuid, player_count integer, status text, slots jsonb,
  created_at timestamp with time zone, my_role text, my_invite_status text,
  my_invite_id uuid
)
language sql stable security definer set search_path to 'public'
as $function$
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
              'name', (
                select coalesce(p.display_name, p.first_name)
                from public.profiles p
                where p.id = (elem.slot ->> 'user_id')::uuid
              ),
              'avatar_url', (
                select p.avatar_url from public.profiles p
                where p.id = (elem.slot ->> 'user_id')::uuid
              ),
              'relation', case
                when (elem.slot ->> 'user_id')::uuid = auth.uid() then 'self'
                when exists (
                  select 1 from public.friend_requests fr
                  where fr.status = 'accepted'
                    and ((fr.user_id = auth.uid() and fr.friend_id = (elem.slot ->> 'user_id')::uuid)
                      or (fr.user_id = (elem.slot ->> 'user_id')::uuid and fr.friend_id = auth.uid()))
                ) then 'accepted'
                when exists (
                  select 1 from public.friend_requests fr
                  where fr.user_id = auth.uid()
                    and fr.friend_id = (elem.slot ->> 'user_id')::uuid
                ) then 'pending_outgoing'
                when exists (
                  select 1 from public.friend_requests fr
                  where fr.user_id = (elem.slot ->> 'user_id')::uuid
                    and fr.friend_id = auth.uid()
                ) then 'pending_incoming'
                else null
              end,
              'invite_status', (
                select gi_slot.status
                from public.game_invites gi_slot
                where gi_slot.online_game_id = og.id
                  and gi_slot.invitee_id = (elem.slot ->> 'user_id')::uuid
                order by gi_slot.created_at desc
                limit 1
              )
            )
          else elem.slot
        end
        order by elem.ord
      )
      from jsonb_array_elements(og.slots) with ordinality as elem(slot, ord)
    ) as slots,
    og.created_at,
    case when og.created_by = auth.uid() then 'creator' else 'invitee' end as my_role,
    (
      select gi.status from public.game_invites gi
      where gi.online_game_id = og.id and gi.invitee_id = auth.uid()
      order by gi.created_at desc limit 1
    ) as my_invite_status,
    (
      select gi.id from public.game_invites gi
      where gi.online_game_id = og.id and gi.invitee_id = auth.uid()
      order by gi.created_at desc limit 1
    ) as my_invite_id
  from public.online_games og
  where og.created_by = auth.uid()
     or exists (
       select 1 from public.game_invites gi2
       where gi2.online_game_id = og.id and gi2.invitee_id = auth.uid()
     )
  order by og.created_at desc;
$function$;

-- Aynı kökten ikinci belirti: karşılıklı çift, arkadaşı listede İKİ KEZ
-- gösteriyordu (ölçüldü: bir kullanıcının 4 "arkadaş" satırı, 3 farklı kişi).
-- `distinct on` ile kişi başına tek satır; en yeni `since` korunuyor.
create or replace function public.list_friends()
returns table(friend_id uuid, name text, avatar_url text, since timestamp with time zone)
language sql stable security definer set search_path to 'public'
as $function$
  select q.friend_id, q.name, q.avatar_url, q.since
  from (
    select distinct on (b.friend_id)
      b.friend_id, b.name, b.avatar_url, b.since
    from (
      select
        case when fr.user_id = auth.uid() then fr.friend_id else fr.user_id end as friend_id,
        coalesce(p.display_name, p.first_name) as name,
        p.avatar_url,
        fr.responded_at as since
      from public.friend_requests fr
      join public.profiles p
        on p.id = case when fr.user_id = auth.uid() then fr.friend_id else fr.user_id end
      where fr.status = 'accepted'
        and auth.uid() in (fr.user_id, fr.friend_id)
    ) b
    order by b.friend_id, b.since desc nulls last
  ) q
  order by q.since desc nulls last;
$function$;
