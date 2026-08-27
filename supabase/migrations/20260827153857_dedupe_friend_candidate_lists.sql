-- "Ara & Ekle" listelerindeki MÜKERRER satır — 27 Ağustos 2026.
--
-- `list_users_for_friend` ve `search_users_for_friend`, ilişkiyi bulmak için
-- `friend_requests`'e KARŞILIKLI bir koşulla LEFT JOIN yapıyor:
--     (fr.user_id = auth.uid() and fr.friend_id = p.id)
--  or (fr.user_id = p.id       and fr.friend_id = auth.uid())
-- İki yön de satır olarak varsa (A→B ve B→A ayrı ayrı istek göndermiş —
-- tamamen MEŞRU bir durum, trigger karşılıklı isteği 'accepted'a çevirse de
-- iki satır durmaya devam ediyor) join O PROFİL İÇİN İKİ satır üretiyor ve
-- aynı üye listede iki kez çıkıyor. Bu, 27 Ağustos 2026'da düzeltilen
-- `list_my_online_games` / `list_friends` hatasının (20260827121628) AYNI
-- sınıfı: "LEFT JOIN + karşılıklı OR = sessiz çoğaltma".
--
-- CANLIDA ÖLÇÜLDÜ (düzeltmeden önce): 47 profilin 46'sını gören iki üye
-- için join 47 satır döndürüyordu — yani her birinde tam olarak bir üye
-- mükerrerdi. `limit/offset` JOIN SATIRLARINI saydığından 20'lik bir sayfa
-- 19 farklı üye taşıyordu.
--
-- İki düzeltme:
--  1. `distinct on (p.id)` — profil başına TEK satır. Hangi satır kalacağı
--     rastgele değil: önce 'accepted' (arkadaşlık bir "bekliyor"u ezer),
--     sonra `fr.created_at`, sonra `fr.user_id` — tamamen deterministik.
--  2. Sıralamaya `id` eşitlik-bozucusu — `order by name` TEK BAŞINA toplam
--     bir sıra DEĞİL; aynı ada sahip iki üye varsa (bugün yok ama
--     `first_name` benzersiz değil) offset sayfalaması iki çağrı arasında
--     satır atlayıp tekrarlayabilirdi. Postgres eşitlikte sıra garanti
--     etmez.
--
-- Dönüş şekli (id, name, avatar_url, relation) ve yetkiler DEĞİŞMEDİ —
-- istemci sözleşmesi aynı, uygulama güncellemesi gerekmiyor.

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
    select d.id, d.name, d.avatar_url, d.relation
    from (
      select distinct on (p.id)
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
      order by p.id, (fr.status = 'accepted') desc nulls last, fr.created_at, fr.user_id
    ) d
    order by d.name, d.id
    limit p_limit offset p_offset;
end;
$$;

create or replace function public.search_users_for_friend(p_query text)
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
  if length(trim(p_query)) < 2 then
    return;
  end if;

  return query
    select d.id, d.name, d.avatar_url, d.relation
    from (
      select distinct on (p.id)
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
        and (p.display_name ilike '%' || p_query || '%' or p.first_name ilike '%' || p_query || '%')
      order by p.id, (fr.status = 'accepted') desc nulls last, fr.created_at, fr.user_id
    ) d
    order by d.name, d.id
    limit 20;
end;
$$;

revoke all on function public.list_users_for_friend(int, int) from public, anon;
grant execute on function public.list_users_for_friend(int, int) to authenticated;
revoke all on function public.search_users_for_friend(text) from public, anon;
grant execute on function public.search_users_for_friend(text) to authenticated;
