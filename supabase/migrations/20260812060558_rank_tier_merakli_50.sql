-- Meraklı rütbe eşiği 25 → 50 (12 Ağustos 2026, kullanıcı kararı: "Bence 25
-- yerine 50'de başlasın"). Yeni merdiven: Çaylak 0 · Meraklı 50 · Oyuncu 100
-- · Usta 200 · Şampiyon 500 · Destan 1000. İstemci tarafındaki karşılığı
-- `src/utils/leagueRank.ts` — iki liste ELLE senkron (bkz. CLAUDE.md,
-- "k-lig Ödül & Rütbe Sistemi").
--
-- Eski 25 eşiğinin `rank_up` kayıtları siliniyor: hiçbiri henüz görülmedi
-- (banner UI'ı bu an itibarıyla hiç deploy olmadı, tüm satırlar seen_at=null)
-- ve bayat kalsalar banner tarafında `tierFor(25)` artık Çaylak'a çözüleceği
-- için yanlış bir "Yeni rütben: Çaylak" kutlaması üretirlerdi. Ardından
-- backfill, yeni 50 eşiğini hak edenlere (uygulandığı gün: Ironman 83,
-- Zesiner 73, Minka 58) kutlama kaydını yeniden açıyor — 49 puanlı Esiner
-- yeni kurala göre Çaylak, satır almıyor.

create or replace function public._award_league_rewards(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_completed integer;
  v_base integer;
  v_bonus integer;
  v_total integer;
begin
  if p_user_id is null then
    return;
  end if;

  select count(*) into v_completed
  from games where user_id = p_user_id and not surrendered;

  insert into league_rewards (user_id, kind, threshold, points)
  select p_user_id, 'games_reward', t.threshold, t.points
  from (values (50, 5), (100, 10), (250, 25), (500, 50), (1000, 100)) as t(threshold, points)
  where t.threshold <= v_completed
  on conflict (user_id, kind, threshold) do nothing;

  select coalesce(sum(case
    when surrendered then -2
    when rank = 1 then 2
    when rank = 2 and player_count <> 2 then 1
    else 0 end), 0)::int
  into v_base from games where user_id = p_user_id;

  select coalesce(sum(points), 0)::int into v_bonus
  from league_rewards where user_id = p_user_id and kind = 'games_reward';

  v_total := v_base + v_bonus;

  if v_total >= 100 then
    insert into league_rewards (user_id, kind, threshold, points)
    select p_user_id, 'points_milestone', gs.m, 0
    from generate_series(100, (v_total / 100) * 100, 100) as gs(m)
    on conflict (user_id, kind, threshold) do nothing;
  end if;

  insert into league_rewards (user_id, kind, threshold, points)
  select p_user_id, 'rank_up', t.threshold, 0
  from (values (50), (100), (200), (500), (1000)) as t(threshold)
  where t.threshold <= v_total
  on conflict (user_id, kind, threshold) do nothing;
end;
$$;

delete from public.league_rewards where kind = 'rank_up' and threshold = 25;

select public._award_league_rewards(u.user_id)
from (select distinct user_id from public.games where user_id is not null) u;
