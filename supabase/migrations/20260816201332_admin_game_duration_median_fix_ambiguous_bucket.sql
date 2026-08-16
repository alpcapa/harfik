-- 20260816000000_admin_game_duration_median.sql'in DÜZELTMESİ.
--
-- O migration uygulandı ama fonksiyon HER çağrıda patlıyordu:
--   ERROR 42702: column reference "bucket" is ambiguous
--   DETAIL: It could refer to either a PL/pgSQL variable or a table column.
--
-- Sebep: yeni eklenen `dur_agg` CTE'si `bucket`i ÇIPLAK seçiyor ve
-- `group by bucket` diyor; fonksiyonun OUT parametresi de `bucket`
-- adını taşıdığından plpgsql hangisi olduğunu çözemiyor. Fonksiyonun
-- ESKİ hâlinde bu sorun yoktu çünkü hiçbir CTE `bucket`i çıplak
-- REFERANS ETMİYORDU: ötekiler `date_trunc(...) as bucket` ile bir
-- ifadeye ad veriyor (referans değil) ve `group by 1` konumsal
-- yazılmış. Yani hata tam olarak bu turda eklenen satırlardan doğdu.
--
-- Düzeltme: `dur_agg` içinde CTE takma adıyla nitele (`dd.bucket`).
--
-- DERS (bu projede ikinci kez): bir migration'ın SQL'inin geçerli
-- olması ÇALIŞACAĞINI kanıtlamaz — `admin_game_activity_include_online`
-- da aynı şekilde uygulandıktan sonra ilk çağrıda tip hatasıyla
-- patlamıştı. Fonksiyon uygulandıktan sonra GERÇEK bir çağrıyla
-- (rol simülasyonuyla) sınanmadan iş bitmiş sayılmaz.

create or replace function public.admin_game_activity_series(
  p_periods integer default 30,
  p_granularity text default 'day',
  p_scope text default 'total',
  p_player_count integer default null,
  p_source text default 'total'
)
returns table(
  bucket date,
  games_finished bigint,
  games_finished_same_session bigint,
  games_finished_multi_session bigint,
  games_surrendered bigint,
  med_duration_seconds numeric,
  med_duration_same_session_seconds numeric,
  med_duration_multi_session_seconds numeric,
  p90_duration_seconds numeric
)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
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
  with local_agg as (
    select
      date_trunc(v_unit, created_at at time zone 'Europe/Istanbul') as bucket,
      count(*) filter (where not ended_by_surrender) as cnt_done,
      count(*) filter (where not ended_by_surrender and not multi_session) as cnt_done_same,
      count(*) filter (where not ended_by_surrender and multi_session) as cnt_done_multi,
      count(*) filter (where ended_by_surrender) as cnt_surrendered
    from public.game_finishes
    where p_source in ('total', 'local')
      and (
        p_scope = 'total'
        or (p_scope = 'registered' and user_id is not null)
        or (p_scope = 'guest' and user_id is null)
      )
      and (p_player_count is null or player_count = p_player_count)
    group by 1
  ),
  online_games_agg as (
    select
      g.online_game_id,
      max(g.created_at) as finished_at,
      min(ogs.started_at) as started_at,
      bool_or(g.surrendered) as any_surrendered,
      max(g.player_count) as player_count
    from public.games g
    join public.online_game_states ogs on ogs.online_game_id = g.online_game_id
    where g.online_game_id is not null
    group by g.online_game_id
  ),
  online_agg as (
    select
      date_trunc(v_unit, finished_at at time zone 'Europe/Istanbul') as bucket,
      count(*) filter (where not any_surrendered) as cnt_done,
      count(*) filter (where any_surrendered) as cnt_surrendered
    from online_games_agg
    where p_source in ('total', 'online')
      and p_scope <> 'guest'
      and (p_player_count is null or player_count = p_player_count)
    group by 1
  ),
  -- Ham süreler: yerel + Canlı TEK kümede. Medyan, ortalamanın aksine
  -- iki ayrı kovadan BİRLEŞTİRİLEMEZ (sum/count gibi yeniden kurulamaz),
  -- bu yüzden percentile'lar bu birleşik küme üzerinde hesaplanıyor.
  -- Canlı oyunlar her zaman "günlere yayılan" tarafında (48 saatlik sıra
  -- penceresi) — sayım sütunlarındaki aynı kural.
  durations as (
    select
      date_trunc(v_unit, created_at at time zone 'Europe/Istanbul') as bucket,
      duration_seconds::numeric as dur,
      multi_session as is_multi
    from public.game_finishes
    where p_source in ('total', 'local')
      and not ended_by_surrender
      and (
        p_scope = 'total'
        or (p_scope = 'registered' and user_id is not null)
        or (p_scope = 'guest' and user_id is null)
      )
      and (p_player_count is null or player_count = p_player_count)
    union all
    select
      date_trunc(v_unit, finished_at at time zone 'Europe/Istanbul'),
      extract(epoch from (finished_at - started_at))::numeric,
      true
    from online_games_agg
    where p_source in ('total', 'online')
      and p_scope <> 'guest'
      and not any_surrendered
      and (p_player_count is null or player_count = p_player_count)
  ),
  dur_agg as (
    -- dd.bucket: OUT parametresi `bucket` ile çakışmasın (42702).
    select
      dd.bucket as bucket,
      (percentile_cont(0.5) within group (order by dd.dur))::numeric as med_all,
      (percentile_cont(0.5) within group (order by dd.dur)
        filter (where not dd.is_multi))::numeric as med_same,
      (percentile_cont(0.5) within group (order by dd.dur)
        filter (where dd.is_multi))::numeric as med_multi,
      (percentile_cont(0.9) within group (order by dd.dur))::numeric as p90_all
    from durations dd
    group by dd.bucket
  )
  select
    d.bucket::date as bucket,
    coalesce(l.cnt_done, 0) + coalesce(o.cnt_done, 0) as games_finished,
    coalesce(l.cnt_done_same, 0) as games_finished_same_session,
    coalesce(l.cnt_done_multi, 0) + coalesce(o.cnt_done, 0) as games_finished_multi_session,
    coalesce(l.cnt_surrendered, 0) + coalesce(o.cnt_surrendered, 0) as games_surrendered,
    da.med_all as med_duration_seconds,
    da.med_same as med_duration_same_session_seconds,
    da.med_multi as med_duration_multi_session_seconds,
    da.p90_all as p90_duration_seconds
  from generate_series(v_start, v_end, v_step) as d (bucket)
  left join local_agg l on l.bucket = d.bucket
  left join online_agg o on o.bucket = d.bucket
  left join dur_agg da on da.bucket = d.bucket
  order by d.bucket;
end;
$function$;
