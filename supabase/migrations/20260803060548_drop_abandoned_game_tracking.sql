-- "Terk" (kullanıcının kendi isteğiyle oyunu bırakması) kavramını tamamen
-- kaldırır. Bu durum 29 Temmuz 2026'da UI'dan zaten kalkmıştı: oyun içinde
-- logoya basınca çıkan "-2 puan kırılacak, emin misin?" onayı kaldırılıp
-- logo koşulsuz Setup'a dönmeye çevrildiği için, bir oyuncunun bir oyunu
-- ANLIK olarak terk etmesi artık mümkün değil. Geriye yalnızca süre aşımı
-- kaldı: yerel/YZ oyunlarında 7 gün hareketsizlik (ABANDON_TIMEOUT_MS),
-- Canlı oyunlarda 48 saatlik sıra aşımı (check_turn_timeout) — ikisi de
-- "teslim" olarak sayılıyor ve -2 k-lig cezası uyguluyor.
--
-- Sonuç olarak `game_finishes.completed` fiilen sabit bir kolona dönüşmüştü
-- (production'da 155 satırın tamamı true, hiç false yok — yani bu kolonu
-- düşürmek sıfır bilgi kaybı) ve admin panelinin Büyüme > Oyun grafiğindeki
-- "Terk" serisi bundan sonra hep boş kalacaktı. Her ikisi de kaldırılıyor.

-- 1) p_source'suz eski aşırı yükleme (31 Temmuz 2026'daki
--    admin_game_activity_include_online migration'ından kalma ölü kod —
--    istemci her zaman p_source geçiyor). Zaten kaldırılması gerekiyordu.
drop function if exists public.admin_game_activity_series (integer, text, text, integer);

-- 2) Güncel aşırı yükleme: dönüş tipinden games_abandoned kalkıyor, bu
--    yüzden create or replace yetmiyor (Postgres dönüş sütunları değişince
--    drop + create ister).
drop function if exists public.admin_game_activity_series (integer, text, text, integer, text);

-- 3) Artık hiçbir kod yolu false yazmıyor.
alter table public.game_finishes
  drop column if exists completed;

create function public.admin_game_activity_series (
  p_periods integer default 30,
  p_granularity text default 'day',
  p_scope text default 'total',
  p_player_count integer default null,
  p_source text default 'total'
) returns table (
  bucket date,
  games_finished bigint,
  games_finished_same_session bigint,
  games_finished_multi_session bigint,
  games_surrendered bigint,
  avg_duration_seconds numeric,
  avg_duration_same_session_seconds numeric,
  avg_duration_multi_session_seconds numeric
) language plpgsql stable security definer
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
  with local_agg as (
    select
      date_trunc(v_unit, created_at at time zone 'Europe/Istanbul') as bucket,
      count(*) filter (where not ended_by_surrender) as cnt_done,
      count(*) filter (where not ended_by_surrender and not multi_session) as cnt_done_same,
      count(*) filter (where not ended_by_surrender and multi_session) as cnt_done_multi,
      count(*) filter (where ended_by_surrender) as cnt_surrendered,
      sum(duration_seconds) filter (where not ended_by_surrender) as dur_sum,
      sum(duration_seconds) filter (where not ended_by_surrender and not multi_session) as dur_sum_same,
      sum(duration_seconds) filter (where not ended_by_surrender and multi_session) as dur_sum_multi
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
      count(*) filter (where any_surrendered) as cnt_surrendered,
      sum(extract(epoch from (finished_at - started_at))) filter (where not any_surrendered) as dur_sum
    from online_games_agg
    where p_source in ('total', 'online')
      and p_scope <> 'guest'
      and (p_player_count is null or player_count = p_player_count)
    group by 1
  )
  select
    d.bucket::date as bucket,
    coalesce(l.cnt_done, 0) + coalesce(o.cnt_done, 0) as games_finished,
    coalesce(l.cnt_done_same, 0) as games_finished_same_session,
    coalesce(l.cnt_done_multi, 0) + coalesce(o.cnt_done, 0) as games_finished_multi_session,
    coalesce(l.cnt_surrendered, 0) + coalesce(o.cnt_surrendered, 0) as games_surrendered,
    case when (coalesce(l.cnt_done, 0) + coalesce(o.cnt_done, 0)) > 0
      then (coalesce(l.dur_sum, 0)::numeric + coalesce(o.dur_sum, 0)::numeric) / (coalesce(l.cnt_done, 0) + coalesce(o.cnt_done, 0))
      else null end as avg_duration_seconds,
    case when coalesce(l.cnt_done_same, 0) > 0
      then l.dur_sum_same::numeric / l.cnt_done_same
      else null end as avg_duration_same_session_seconds,
    case when (coalesce(l.cnt_done_multi, 0) + coalesce(o.cnt_done, 0)) > 0
      then (coalesce(l.dur_sum_multi, 0)::numeric + coalesce(o.dur_sum, 0)::numeric) / (coalesce(l.cnt_done_multi, 0) + coalesce(o.cnt_done, 0))
      else null end as avg_duration_multi_session_seconds
  from generate_series(v_start, v_end, v_step) as d (bucket)
  left join local_agg l on l.bucket = d.bucket
  left join online_agg o on o.bucket = d.bucket
  order by d.bucket;
end;
$$;

revoke all on function public.admin_game_activity_series (integer, text, text, integer, text) from public, anon;
grant execute on function public.admin_game_activity_series (integer, text, text, integer, text) to authenticated;
