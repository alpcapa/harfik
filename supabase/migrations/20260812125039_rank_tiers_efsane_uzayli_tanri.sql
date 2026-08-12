-- k-lig rütbe kademeleri genişletildi (12 Ağustos 2026, kullanıcı isteği).
--
-- İki değişiklik:
--   1. Usta eşiği 200 → 250. Bu, ödül tablosunu "ödül = eşik/10" kuralına
--      TAM oturtuyor — 200→25 bu kuralın tek kırık üyesiydi.
--   2. Destan'ın (1000) üstüne üç yeni kademe: Efsane 2500 (+250),
--      Uzaylı 5000 (+500), Tanrı 10000 (+1000). Tanrı EN ÜST kademe;
--      oraya varan orada kalır.
--
-- Tanrı'nın ödülü (1000) `league_rewards_points_check`'in tavanına
-- (points <= 1000) TAM oturuyor — bir üst kademe eklenecekse o kısıt da
-- büyütülmeli.
--
-- Eşik değiştirmek mevcut satırları öksüz bırakabilirdi; uygulamadan önce
-- kontrol edildi: `league_rewards`ta yalnızca threshold=50 satırları var
-- (3 points_reward + 3 rank_up), yani 200'e bağlı hiçbir kayıt yok.
-- Backfill GEREKMİYOR — fonksiyon zaten idempotent (`on conflict do
-- nothing`) ve bir sonraki oyun bitişinde eksik eşikleri kendiliğinden
-- tamamlıyor; ayrıca aşağıda tüm kullanıcılar için bir kez çağrılıyor.
--
-- ⚠ ÜÇ KOPYA ELLE SENKRON: buradaki iki (values ...) listesi, web'in
-- `src/utils/leagueRank.ts`'i ve Flutter portunun
-- `mobile/app/lib/src/ui/rank/league_rank.dart`'ı tek kaynak DEĞİL.

create or replace function public._award_league_rewards(
  p_user_id uuid,
  p_delta integer default 0
) returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_base integer;
  v_bonus integer;
  v_total integer;
  v_prev integer;
  v_inserted integer;
begin
  if p_user_id is null then
    return;
  end if;

  select coalesce(sum(case
    when surrendered then -2
    when rank = 1 then 2
    when rank = 2 and player_count <> 2 then 1
    else 0 end), 0)::int
  into v_base from games where user_id = p_user_id;

  -- Ödül puanı toplamın İÇİNE sayıldığından bir ödül bir sonraki eşiği
  -- tetikleyebilir; döngü yeni satır açılmayana kadar sürer.
  loop
    select coalesce(sum(points), 0)::int into v_bonus
    from league_rewards where user_id = p_user_id and kind = 'points_reward';
    v_total := v_base + v_bonus;

    insert into league_rewards (user_id, kind, threshold, points)
    select p_user_id, 'points_reward', t.threshold, t.points
    from (values (50, 5), (100, 10), (250, 25), (500, 50), (1000, 100),
                 (2500, 250), (5000, 500), (10000, 1000)) as t(threshold, points)
    where t.threshold <= v_total
    on conflict (user_id, kind, threshold) do nothing;

    get diagnostics v_inserted = row_count;
    exit when v_inserted = 0;
  end loop;

  if v_total >= 100 then
    insert into league_rewards (user_id, kind, threshold, points)
    select p_user_id, 'points_milestone', gs.m, 0
    from generate_series(100, (v_total / 100) * 100, 100) as gs(m)
    on conflict (user_id, kind, threshold) do nothing;
  end if;

  insert into league_rewards (user_id, kind, threshold, points)
  select p_user_id, 'rank_up', t.threshold, 0
  from (values (50), (100), (250), (500), (1000),
               (2500), (5000), (10000)) as t(threshold)
  where t.threshold <= v_total
  on conflict (user_id, kind, threshold) do nothing;

  if p_delta < 0 then
    v_prev := v_total - p_delta;
    insert into league_rewards (user_id, kind, threshold, points)
    select p_user_id, 'rank_down', t.threshold, 0
    from (values (50), (100), (250), (500), (1000),
                 (2500), (5000), (10000)) as t(threshold)
    where t.threshold <= v_prev and t.threshold > v_total
    on conflict (user_id, kind, threshold)
    do update set seen_at = null, created_at = now();
  end if;
end;
$function$;

-- Mevcut kullanıcılar için bir kez çalıştır: eşik listesi değiştiğinden
-- hak edilmiş ama henüz açılmamış bir satır varsa şimdi açılsın. p_delta 0
-- geçiliyor — bu bir ceza turu DEĞİL, dolayısıyla hiç `rank_down` üretmez.
do $$
declare r record;
begin
  for r in select distinct user_id from games where user_id is not null loop
    perform public._award_league_rewards(r.user_id, 0);
  end loop;
end $$;
