-- Rütbe düşüş bildirimi (12 Ağustos 2026, kullanıcı isteği: "üzgünüz
-- rütbeniz geriledi gibi hafif üzücü bir popup").
--
-- Yeni kind: 'rank_down' — bir games satırı (pratikte yalnızca -2'lik
-- teslim/terk cezası) toplam puanı bir rütbe eşiğinin ALTINA indirdiğinde
-- açılır. Ödül/kutlamaların aksine TEKRARLANABİLİR bir olay: aynı eşikten
-- ikinci kez düşülürse `on conflict ... do update set seen_at = null` ile
-- mevcut satırın "görüldü" işareti sıfırlanır, banner yeniden gösterilir
-- (rank_up/points_reward'daki "hayatta bir kez" kuralının bilinçli tersi).
--
-- Tespit yalnızca trigger yolundan: eski toplamı bilmek için bu insert'in
-- puan katkısı (delta) gerekiyor — trigger NEW satırdan hesaplayıp yeni
-- p_delta parametresiyle geçiyor; backfill/elle çağrılar 0 geçer (düşüş
-- bildirimi üretmez). -2'lik tek adım eşik aralıklarından (>=50) küçük
-- olduğundan bir insert en fazla BİR eşiği aşağı kesebilir, yine de kontrol
-- tüm eşikleri tarar (genel doğruluk).
--
-- NOT: ödül/rütbe-kutlama satırlarına DOKUNULMUYOR — puan eşiğin altına
-- inince verilmiş points_reward geri alınmaz, tekrar yükselince de (satır
-- unique + hiç silinmediğinden) İKİNCİ kez verilmez; rank_up kutlaması da
-- tekrarlanmaz. Değişen tek şey gösterim (düşmeli rütbe) + bu nazik uyarı.

alter table public.league_rewards drop constraint league_rewards_kind_check;
alter table public.league_rewards
  add constraint league_rewards_kind_check
  check (kind in ('points_reward', 'points_milestone', 'rank_up', 'rank_down'));

-- İmza değiştiğinden (yeni parametre) overload kalmasın diye drop + create.
drop function public._award_league_rewards(uuid);

create function public._award_league_rewards(p_user_id uuid, p_delta integer default 0)
returns void
language plpgsql
security definer
set search_path = public
as $$
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

  loop
    select coalesce(sum(points), 0)::int into v_bonus
    from league_rewards where user_id = p_user_id and kind = 'points_reward';
    v_total := v_base + v_bonus;

    insert into league_rewards (user_id, kind, threshold, points)
    select p_user_id, 'points_reward', t.threshold, t.points
    from (values (50, 5), (100, 10), (200, 25), (500, 50), (1000, 100)) as t(threshold, points)
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
  from (values (50), (100), (200), (500), (1000)) as t(threshold)
  where t.threshold <= v_total
  on conflict (user_id, kind, threshold) do nothing;

  -- Rütbe düşüşü: puanı DÜŞÜREN bir katkıda (p_delta < 0), eski toplamın
  -- üzerinde olup yenisinin altında kaldığı her eşik için bildirim.
  -- Ödül puanı bu dalda değişmediğinden (negatif katkı yeni ödül açamaz)
  -- v_total ile v_prev aynı v_bonus'u paylaşır.
  if p_delta < 0 then
    v_prev := v_total - p_delta;
    insert into league_rewards (user_id, kind, threshold, points)
    select p_user_id, 'rank_down', t.threshold, 0
    from (values (50), (100), (200), (500), (1000)) as t(threshold)
    where t.threshold <= v_prev and t.threshold > v_total
    on conflict (user_id, kind, threshold)
    do update set seen_at = null, created_at = now();
  end if;
end;
$$;

revoke all on function public._award_league_rewards(uuid, integer) from public, anon, authenticated;

create or replace function public.trg_award_league_rewards()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is not null then
    perform _award_league_rewards(
      new.user_id,
      case
        when new.surrendered then -2
        when new.rank = 1 then 2
        when new.rank = 2 and new.player_count <> 2 then 1
        else 0
      end
    );
  end if;
  return new;
end;
$$;
