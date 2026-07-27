-- Kelimeki — Admin paneli: Büyüme > Kullanıcı altında arkadaşlık verilerini
-- takip eden bölüm. Arkadaşlık sistemi (26 Temmuz 2026, bkz. CLAUDE.md
-- "Arkadaşlık Sistemi") eklendiğinden beri admin panelinde bu konuda hiçbir
-- toplu istatistik yoktu. `profiles.invited_by` o migration'da zaten
-- "ileride admin Büyüme panelinde 'arkadaş daveti ile gelen kayıt' metriği
-- için kullanılabilir (henüz eklenmedi)" notuyla eklenmişti — bu migration
-- onu ilk kez gerçek bir metriğe bağlıyor.

-- Zaman serisi: gönderilen istek sayısı (friend_requests.created_at) ve
-- kurulan arkadaşlık sayısı (status=accepted olduğu an, responded_at) —
-- diğer admin_*_activity_series fonksiyonlarıyla aynı İstanbul saat dilimi
-- kova mantığı (game_engagement_admin_stats migration'ındaki desenin aynısı).
create or replace function public.admin_friend_activity_series (
  p_periods integer default 30,
  p_granularity text default 'day'
)
  returns table (
    bucket             date,
    requests_sent      bigint,
    friendships_formed bigint
  )
  language plpgsql
  stable
  security definer
  set search_path = public, auth
  as $$
declare
  v_unit text := case
    when p_granularity = 'year' then 'year'
    when p_granularity = 'month' then 'month'
    when p_granularity = 'week' then 'week'
    else 'day'
  end;
  v_step interval := case
    when v_unit = 'year' then interval '1 year'
    when v_unit = 'month' then interval '1 month'
    when v_unit = 'week' then interval '1 week'
    else interval '1 day'
  end;
  v_end timestamp := date_trunc(v_unit, now() at time zone 'Europe/Istanbul');
  v_start timestamp := v_end - (greatest(p_periods, 1) - 1) * v_step;
begin
  if not is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    d.bucket::date     as bucket,
    coalesce(r.cnt, 0) as requests_sent,
    coalesce(f.cnt, 0) as friendships_formed
  from generate_series(v_start, v_end, v_step) as d (bucket)
  left join (
    select date_trunc(v_unit, created_at at time zone 'Europe/Istanbul') as bucket, count(*) as cnt
    from public.friend_requests
    group by 1
  ) r on r.bucket = d.bucket
  left join (
    select date_trunc(v_unit, responded_at at time zone 'Europe/Istanbul') as bucket, count(*) as cnt
    from public.friend_requests
    where status = 'accepted' and responded_at is not null
    group by 1
  ) f on f.bucket = d.bucket
  order by d.bucket;
end;
$$;

revoke all on function public.admin_friend_activity_series(integer, text) from public, anon;
grant execute on function public.admin_friend_activity_series(integer, text) to authenticated;

-- Toplamlar: tüm zamanların arkadaşlık/istek/davet linki sayıları.
create or replace function public.admin_friend_totals ()
  returns table (
    total_friendships      bigint,
    total_pending_requests bigint,
    total_invite_links     bigint,
    total_invite_signups   bigint
  )
  language plpgsql
  stable
  security definer
  set search_path = public, auth
  as $$
begin
  if not is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    (select count(*) from public.friend_requests where status = 'accepted') as total_friendships,
    (select count(*) from public.friend_requests where status = 'pending') as total_pending_requests,
    (select count(*) from public.friend_invite_links) as total_invite_links,
    (select count(*) from public.profiles where invited_by is not null) as total_invite_signups;
end;
$$;

revoke all on function public.admin_friend_totals() from public, anon;
grant execute on function public.admin_friend_totals() to authenticated;
