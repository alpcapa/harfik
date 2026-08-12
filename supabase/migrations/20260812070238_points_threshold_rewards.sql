-- Ödüller oyun SAYISINDAN k-lig PUAN eşiklerine taşındı (12 Ağustos 2026,
-- kullanıcı onayı — önizleme görselle onaylandı). Yeni kural: rütbe
-- eşikleriyle bire bir aynı puan eşikleri tek seferlik ödül de verir:
-- 50 puan → +5, 100 → +10, 200 → +25, 500 → +50, 1000 → +100.
-- Oyun-sayısı ("50 tamamlanan oyun → +5") ödülü tamamen kalktı — gerekçe:
-- RankInfoModal'daki ilerleme çubuğu puan eşiklerini gösteriyor; ödülün
-- oyun sayısına bağlı olması iki ayrı ölçek yaratıyordu ve (+5)/(+10)
-- etiketleri ancak tek ölçekte dürüst yazılabilirdi.
--
-- Veri dönüşümü: mevcut 'games_reward' satırları 'points_reward'a çevrildi —
-- uygulandığı gün üç kullanıcının +5'i (threshold 50, üçü de 50+ puanda)
-- yeni semantikte de aynı değeri taşıyor, kimsenin toplamı değişmedi;
-- 49 puanlı hesap iki kuralda da ödülsüz.
--
-- Zincirleme not: ödül puanı toplamın kendisine eklendiğinden (50'ye gelen
-- +5 ile 55 olur) fonksiyon ödülleri döngüyle, sabitlenene kadar dağıtır —
-- mevcut tabloda eşik araları ödüllerden büyük olduğundan pratikte tek tur
-- yeter, döngü güvenlik ağı.
--
-- Verilmiş ödül GERİ ALINMAZ: puan -2 cezalarıyla eşiğin altına inse de
-- points_reward satırı (ve puanı) kalır — rütbe gösteriminin (düşmeli)
-- aksine ödül tek seferlik ve kalıcıdır (kutlama kayıtlarıyla aynı ilke).

alter table public.league_rewards drop constraint league_rewards_kind_check;
update public.league_rewards set kind = 'points_reward' where kind = 'games_reward';
alter table public.league_rewards
  add constraint league_rewards_kind_check
  check (kind in ('points_reward', 'points_milestone', 'rank_up'));

create or replace function public._award_league_rewards(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base integer;
  v_bonus integer;
  v_total integer;
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

  -- Puan eşiği ödülleri — ödülün kendisi toplamı büyüttüğünden yeni eşik
  -- açılmadığı sürece döngü tek turda biter.
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
end;
$$;

-- Yeni kurala göre backfill (uygulandığı gün no-op çıktı: dönüştürülen üç
-- +5 satırı yeni kuralla birebir aynı hak edişti).
select public._award_league_rewards(u.user_id)
from (select distinct user_id from public.games where user_id is not null) u;
