-- Arkadaşlar > "Ara & Ekle" sekmesinde, arama kutusuna hiçbir şey yazılmadan
-- da tüm üyelerin alfabetik/sayfalı bir listesinin gösterilebilmesi için —
-- `search_users_for_friend` bilerek dokunulmadı (en az 2 karakter şartı ve
-- 20 sonuç limiti hâlâ geçerli, o RPC'nin davranışı değişmiyor), bunun
-- yerine aynı şekli (id, name, avatar_url, relation) döndüren ayrı bir
-- sayfalı (offset/limit) fonksiyon eklendi.
create or replace function public.list_users_for_friend(p_offset int default 0, p_limit int default 20)
returns table(id uuid, name text, avatar_url text, relation text)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null then
    raise exception 'Oturum açık değil.';
  end if;

  return query
    select
      p.id,
      coalesce(p.display_name, p.first_name) as name,
      p.avatar_url,
      case
        when fr.status = 'accepted' then 'accepted'
        when fr.user_id = auth.uid() then 'pending_outgoing'
        when fr.friend_id = auth.uid() then 'pending_incoming'
        else null
      end as relation
    from public.profiles p
    left join public.friend_requests fr
      on (fr.user_id = auth.uid() and fr.friend_id = p.id)
      or (fr.user_id = p.id and fr.friend_id = auth.uid())
    where p.id <> auth.uid()
    order by name
    limit p_limit offset p_offset;
end;
$$;

revoke all on function public.list_users_for_friend(int, int) from public, anon;
grant execute on function public.list_users_for_friend(int, int) to authenticated;
