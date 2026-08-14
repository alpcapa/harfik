-- Düzeltme: bir önceki migration'da (admin_growth_retention_activation) üç yeni
-- fonksiyonun hata mesajı gereksiz yere ASCII'ye indirilmişti ('Yetkisiz erisim.').
-- Projedeki DİĞER TÜM admin RPC'leri 'Yetkisiz erişim.' kullanıyor; ayrıca repodaki
-- migration dosyası zaten Türkçesini taşıyordu, yani DOSYA İLE ÜRETİM AYRIŞMIŞTI —
-- kök CLAUDE.md'nin migration disiplini tam olarak bunu yasaklıyor.
--
-- DERS: MCP üzerinden SQL uygularken Türkçe karakterleri "temkinli olsun diye"
-- ASCII'ye indirme — kanal Türkçeyi sorunsuz taşıyor (bu migration'ın kendisi
-- kanıt). İndirgeme yalnızca sessiz bir dosya↔üretim farkı üretir.
--
-- Gövde bunun dışında bir önceki migration ile BİREBİR aynı; create or replace
-- grant'leri korur ama dosyayla tam eşleşsin diye revoke/grant satırları da
-- tekrarlanıyor (idempotent).

comment on view public._admin_user_activity is
  'Admin büyüme metrikleri için ortak "aktif oyuncu" olay akışı. İstemciye KAPALI. Yeni bir ürün eylemi (ör. yeni bir sosyal özellik) aktiflik sayılacaksa buraya eklenir — aktif oyuncu serisi ve retention kohortları bu tek kaynaktan beslendiğinden ikisi asla ayrışmaz.';

create or replace function public.admin_active_players_series(
  p_periods integer default 30,
  p_granularity text default 'day'
)
returns table(bucket date, active_in_bucket bigint, active_28d bigint)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
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
    d.bucket::date as bucket,
    (
      select count(distinct a.user_id)
      from public._admin_user_activity a
      where (a.created_at at time zone 'Europe/Istanbul') >= d.bucket
        and (a.created_at at time zone 'Europe/Istanbul') <  d.bucket + v_step
    ) as active_in_bucket,
    (
      select count(distinct a.user_id)
      from public._admin_user_activity a
      where (a.created_at at time zone 'Europe/Istanbul') >= d.bucket + v_step - interval '28 days'
        and (a.created_at at time zone 'Europe/Istanbul') <  d.bucket + v_step
    ) as active_28d
  from generate_series(v_start, v_end, v_step) as d (bucket)
  order by d.bucket;
end;
$$;

revoke all on function public.admin_active_players_series(integer, text) from public, anon, authenticated;
grant execute on function public.admin_active_players_series(integer, text) to authenticated;

create or replace function public.admin_retention_cohorts(
  p_cohorts integer default 8
)
returns table(cohort_week date, cohort_size bigint, week_offset integer, active_users bigint)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_now timestamp := now() at time zone 'Europe/Istanbul';
  v_first timestamp := date_trunc('week', v_now) - (greatest(p_cohorts, 1) - 1) * interval '1 week';
begin
  if not is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  with cohort_members as (
    select
      date_trunc('week', u.created_at at time zone 'Europe/Istanbul') as cw,
      u.id as user_id
    from auth.users u
    where date_trunc('week', u.created_at at time zone 'Europe/Istanbul') >= v_first
  ),
  sizes as (
    select cm.cw, count(*) as n from cohort_members cm group by cm.cw
  ),
  cells as (
    select s.cw, s.n, o.off
    from sizes s
    cross join generate_series(0, greatest(p_cohorts, 1) - 1) as o (off)
    -- pencere TAMAMEN geçmişte mi?
    where s.cw + (o.off + 1) * interval '1 week' <= v_now
  )
  select
    c.cw::date as cohort_week,
    c.n as cohort_size,
    c.off as week_offset,
    (
      select count(distinct a.user_id)
      from public._admin_user_activity a
      join cohort_members cm on cm.user_id = a.user_id and cm.cw = c.cw
      where (a.created_at at time zone 'Europe/Istanbul') >= c.cw + c.off * interval '1 week'
        and (a.created_at at time zone 'Europe/Istanbul') <  c.cw + (c.off + 1) * interval '1 week'
    ) as active_users
  from cells c
  order by c.cw, c.off;
end;
$$;

revoke all on function public.admin_retention_cohorts(integer) from public, anon, authenticated;
grant execute on function public.admin_retention_cohorts(integer) to authenticated;

create or replace function public.admin_activation_stats()
returns table(
  total_users bigint,
  activated_users bigint,
  never_activated bigint,
  activated_same_day bigint,
  activated_within_3_days bigint,
  activated_later bigint,
  median_hours_to_first_game numeric
)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
begin
  if not is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  with firsts as (
    select
      u.created_at as signed_up,
      (select min(g.created_at) from public.games g where g.user_id = u.id) as first_game
    from auth.users u
  ),
  gaps as (
    select
      f.first_game is not null as activated,
      greatest(f.first_game - f.signed_up, interval '0') as gap
    from firsts f
  )
  select
    count(*)::bigint,
    count(*) filter (where activated)::bigint,
    count(*) filter (where not activated)::bigint,
    count(*) filter (where activated and gap < interval '1 day')::bigint,
    count(*) filter (where activated and gap >= interval '1 day' and gap < interval '3 days')::bigint,
    count(*) filter (where activated and gap >= interval '3 days')::bigint,
    round(
      percentile_cont(0.5) within group (
        order by (case when activated then extract(epoch from gap) / 3600.0 end)::double precision
      )::numeric,
      1
    )
  from gaps;
end;
$$;

revoke all on function public.admin_activation_stats() from public, anon, authenticated;
grant execute on function public.admin_activation_stats() to authenticated;
