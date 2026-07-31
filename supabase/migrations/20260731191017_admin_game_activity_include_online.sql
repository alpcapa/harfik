-- Admin panelindeki "Büyüme > Oyun" grafiği yalnızca `game_finishes` tablosunu
-- okuyordu; bu tablo yalnızca YEREL (Yapay Zeka'ya karşı, aynı cihaz) oyunlar
-- bittiğinde `logGameFinish()` ile yazılıyor. Canlı (online) oyunlar
-- `_finish_online_game_records()` üzerinden tamamen sunucu tarafında
-- `public.games`'e yazılıyor ve `game_finishes`'e HİÇ dokunmuyor — sonuç
-- olarak biten Canlı oyunlar admin oyun grafiklerinde hiç görünmüyordu.
-- (Sanal Lig puanları `player_stats`/`player_stats_overall` view'ları
-- üzerinden zaten `games` tablosunu okuduğundan bu sorundan etkilenmiyordu,
-- doğrulandı.)
--
-- Bu migration `admin_game_activity_series`'e yeni bir `p_source`
-- ('total'|'local'|'online') parametresi ekliyor ve fonksiyonu hem
-- `game_finishes` (yerel/Yapay Zeka) hem `games`+`online_game_states`
-- (Canlı) tablolarını birleştirecek şekilde yeniden yazıyor. Online
-- oyunlarda `games` tablosuna katılımcı başına (koltuk başına) bir satır
-- yazıldığından, tek bir Canlı oyunu bir kez saymak için önce
-- `online_game_id` bazında gruplanıyor: herhangi bir koltuk teslim olduysa
-- (`surrendered`) oyun "Teslim" sayılıyor, süresi `online_game_states.started_at`
-- (oyunun gerçekten aktif olduğu an) ile bitiş anı arasındaki fark.
-- Online oyunların "Aynı Oturum"/"Çok Oturumlu" kavramı olmadığından hepsi
-- "Çok Oturumlu" tarafına yazılıyor (toplam = aynı+çok oturumlu değişmezliği
-- korunuyor). Online oyunların "Terk" kavramı yok (misafir yok, süresi dolan
-- sıra otomatik teslime dönüşüyor) — `games_abandoned` yalnızca yerelden geliyor.
-- `p_scope='guest'` iken online katkısı bilinçli olarak sıfır (Canlı oyunda
-- herkes girişli).
create or replace function public.admin_game_activity_series (
  p_periods integer default 30,
  p_granularity text default 'day',
  p_scope text default 'total',
  p_player_count integer default null,
  p_source text default 'total'
)
  returns table (
    bucket                              date,
    games_finished                      bigint,
    games_finished_same_session         bigint,
    games_finished_multi_session        bigint,
    games_surrendered                   bigint,
    games_abandoned                     bigint,
    avg_duration_seconds                numeric,
    avg_duration_same_session_seconds   numeric,
    avg_duration_multi_session_seconds  numeric
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
  with local_agg as (
    select
      date_trunc(v_unit, created_at at time zone 'Europe/Istanbul') as bucket,
      count(*) filter (where completed and not ended_by_surrender) as cnt_done,
      count(*) filter (where completed and not ended_by_surrender and not multi_session) as cnt_done_same,
      count(*) filter (where completed and not ended_by_surrender and multi_session) as cnt_done_multi,
      count(*) filter (where completed and ended_by_surrender) as cnt_surrendered,
      count(*) filter (where not completed) as cnt_abandoned,
      sum(duration_seconds) filter (where completed and not ended_by_surrender) as dur_sum,
      sum(duration_seconds) filter (where completed and not ended_by_surrender and not multi_session) as dur_sum_same,
      sum(duration_seconds) filter (where completed and not ended_by_surrender and multi_session) as dur_sum_multi
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
    coalesce(l.cnt_abandoned, 0) as games_abandoned,
    case when (coalesce(l.cnt_done, 0) + coalesce(o.cnt_done, 0)) > 0
      then (coalesce(l.dur_sum, 0) + coalesce(o.dur_sum, 0)) / (coalesce(l.cnt_done, 0) + coalesce(o.cnt_done, 0))
      else null end as avg_duration_seconds,
    case when coalesce(l.cnt_done_same, 0) > 0
      then l.dur_sum_same / l.cnt_done_same
      else null end as avg_duration_same_session_seconds,
    case when (coalesce(l.cnt_done_multi, 0) + coalesce(o.cnt_done, 0)) > 0
      then (coalesce(l.dur_sum_multi, 0) + coalesce(o.dur_sum, 0)) / (coalesce(l.cnt_done_multi, 0) + coalesce(o.cnt_done, 0))
      else null end as avg_duration_multi_session_seconds
  from generate_series(v_start, v_end, v_step) as d (bucket)
  left join local_agg l on l.bucket = d.bucket
  left join online_agg o on o.bucket = d.bucket
  order by d.bucket;
end;
$$;

revoke all on function public.admin_game_activity_series (integer, text, text, integer, text) from public, anon;
grant execute on function public.admin_game_activity_series (integer, text, text, integer, text) to authenticated;
