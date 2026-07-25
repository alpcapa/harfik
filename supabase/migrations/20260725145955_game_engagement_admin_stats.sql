-- Kelimeki — Admin paneli: beğeni/paylaşma zaman serisi + toplamlar
--
-- Admin panelinde şu ana kadar beğeni (game_likes) ve paylaşma (games.shared)
-- için hiçbir toplu/istatistik görünümü yoktu — yalnızca oyuncunun kendi
-- kartında oyun başına sayı görünüyordu. `games.shared` sadece bir bayrak,
-- NE ZAMAN paylaşıldığına dair bir zaman damgası taşımıyordu; bu yüzden
-- Büyüme > Oyun sekmesindeki diğer seriler gibi günlük/haftalık bir
-- "paylaşma" grafiği kurulamıyordu. `shared_at` ekleniyor; set_game_shared
-- artık ilk paylaşımda bunu da (idempotent — sonraki paylaşımlarda üzerine
-- yazmadan, coalesce ile) dolduruyor. Bu migration'dan ÖNCE zaten
-- shared=true olan satırlarda ne zaman paylaşıldığı bilinmediğinden
-- shared_at null kalıyor (geriye dönük doldurulamaz) — bu eski paylaşımlar
-- zaman serisinde hiçbir kovaya düşmeyecek, ama toplam paylaşılan oyun
-- sayısına (shared=true, tarihten bağımsız) dahil olmaya devam edecek.

alter table public.games add column if not exists shared_at timestamptz;

create or replace function public.set_game_shared(p_game_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz erişim.';
  end if;

  update public.games
  set shared = true, shared_at = coalesce(shared_at, now())
  where id = p_game_id;
  return true;
end;
$$;

-- Zaman serisi: beğeni sayısı (game_likes.created_at) ve paylaşma sayısı
-- (games.shared_at — yalnızca ilk paylaşım anı), diğer admin_*_activity_series
-- fonksiyonlarıyla aynı İstanbul saat dilimi kova mantığıyla.
create or replace function public.admin_engagement_activity_series (
  p_periods integer default 30,
  p_granularity text default 'day'
)
  returns table (
    bucket date,
    likes  bigint,
    shares bigint
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
  if not public.is_admin () then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    d.bucket::date     as bucket,
    coalesce(l.cnt, 0) as likes,
    coalesce(s.cnt, 0) as shares
  from generate_series(v_start, v_end, v_step) as d (bucket)
  left join (
    select date_trunc(v_unit, created_at at time zone 'Europe/Istanbul') as bucket, count(*) as cnt
    from public.game_likes
    group by 1
  ) l on l.bucket = d.bucket
  left join (
    select date_trunc(v_unit, shared_at at time zone 'Europe/Istanbul') as bucket, count(*) as cnt
    from public.games
    where shared_at is not null
    group by 1
  ) s on s.bucket = d.bucket
  order by d.bucket;
end;
$$;

revoke all on function public.admin_engagement_activity_series (integer, text) from public, anon;
grant execute on function public.admin_engagement_activity_series (integer, text) to authenticated;

-- Toplamlar: tüm-zamanların toplam beğeni sayısı ve toplam paylaşılan oyun
-- sayısı (shared_at'ten bağımsız — migration öncesi paylaşılanlar dahil).
create or replace function public.admin_engagement_totals ()
  returns table (
    total_likes        bigint,
    total_shared_games bigint
  )
  language plpgsql
  stable
  security definer
  set search_path = public, auth
  as $$
begin
  if not public.is_admin () then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    (select count(*) from public.game_likes)              as total_likes,
    (select count(*) from public.games where shared = true) as total_shared_games;
end;
$$;

revoke all on function public.admin_engagement_totals () from public, anon;
grant execute on function public.admin_engagement_totals () to authenticated;
