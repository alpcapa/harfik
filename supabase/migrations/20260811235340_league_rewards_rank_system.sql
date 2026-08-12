-- k-lig Ödül & Rütbe Sistemi (11 Ağustos 2026, kullanıcı onaylı tasarım)
--
-- Üç mekanik tek tabloda:
--   * games_reward     — kademeli, tek seferlik oyun ödülleri: 50 tamamlanan
--                        oyun → +5, 100 → +10, 250 → +25, 500 → +50, 1000 → +100.
--                        "Tamamlanan" = surrendered olmayan games satırı
--                        (teslim/terk ödül sayacına girmez).
--   * points_milestone — her 100 k-lig puanı eşiğinde (100, 200, 300…) bir
--                        kutlama kaydı (points=0, yalnızca banner için).
--   * rank_up          — rütbe eşiği aşımı (25/100/200/500/1000; Çaylak=0
--                        taban, satır açılmaz). Rütbe DÜŞMEZ — ulaşılan en
--                        yüksek threshold kalıcı kayıttır.
--
-- seen_at: kutlama banner'ının "bir kez göster" işareti — cihazdan bağımsız,
-- `reminder_sent_at`/`deadline_warning_sent_at` ile aynı atomik iddia deseni.
--
-- Ödüller toplam puana yalnızca points_milestone/rank_up DEĞİL games_reward
-- satırlarının points'iyle girer; total_score'u hesaplayan ÜÇ yer birden
-- güncellendi (player_stats_overall, leaderboard, my_leaderboard_rank) —
-- `player_stats` (mod bazlı) BİLEREK değişmedi: ödül moda bölünemez, bu
-- yüzden "Genel = 2 kişilik + 4 kişilik" değişmezi artık "…+ ödül puanı"
-- (yeni `bonus_points` kolonu UI'da bunu açıkça gösterir).

create table public.league_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('games_reward', 'points_milestone', 'rank_up')),
  threshold integer not null check (threshold > 0),
  points integer not null default 0 check (points between 0 and 1000),
  seen_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, kind, threshold)
);

create index league_rewards_user_idx on public.league_rewards (user_id);

alter table public.league_rewards enable row level security;

-- games tablosuyla aynı görünürlük duruşu: rütbe/ödül, zaten herkese açık
-- olan lig puanının parçası — security_invoker view'lar (leaderboard,
-- player_stats_overall) satırları okuyabilsin diye SELECT tüm girişli
-- kullanıcılara açık. Yazma yolları tamamen kapalı: insert yalnızca aşağıdaki
-- SECURITY DEFINER ödül fonksiyonundan, seen_at yalnızca kendi RPC'sinden.
create policy league_rewards_select_authenticated on public.league_rewards
  for select using (auth.uid() is not null);

revoke all on table public.league_rewards from anon;
revoke insert, update, delete on table public.league_rewards from authenticated;

-- Ödül/kilometre taşı/rütbe tespiti — hem games INSERT trigger'ı hem
-- geriye dönük backfill aynı fonksiyonu kullanır (bkz. CLAUDE.md'deki
-- `_finish_online_game_records` dersi: aynı mantık iki yerde kopyalanmaz).
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
  from (values (25), (100), (200), (500), (1000)) as t(threshold)
  where t.threshold <= v_total
  on conflict (user_id, kind, threshold) do nothing;
end;
$$;

revoke all on function public._award_league_rewards(uuid) from public, anon, authenticated;

create or replace function public.trg_award_league_rewards()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is not null then
    perform _award_league_rewards(new.user_id);
  end if;
  return new;
end;
$$;

-- games'e yazan HER yol (yerel saveGame, misafir kuyruğu flush'ı, Canlı
-- _finish_online_game_records, terk-edilme cezası) bu tek trigger'dan geçer.
create trigger games_award_league_rewards
after insert on public.games
for each row execute function public.trg_award_league_rewards();

-- Banner "görüldü" işareti — yalnızca çağıranın KENDİ görülmemiş satırları.
create or replace function public.mark_league_rewards_seen()
returns void
language sql
security definer
set search_path = public
as $$
  update league_rewards set seen_at = now()
  where user_id = auth.uid() and seen_at is null;
$$;

revoke all on function public.mark_league_rewards_seen() from public, anon;
grant execute on function public.mark_league_rewards_seen() to authenticated;

-- ---- total_score'u hesaplayan üç yer + yeni rank_tier/bonus_points ----

-- 1) player_stats_overall — total_score artık ödül dahil; sona iki yeni
-- kolon eklendi (create or replace view sona ekleme ile uyumlu):
-- rank_tier (ulaşılan en yüksek rütbe eşiği, 0=Çaylak) ve bonus_points
-- (UI'da "Genel = sekmeler + ödül" farkını açıklamak için).
create or replace view public.player_stats_overall as
select
  user_id,
  count(*) as games_played,
  count(*) filter (where result = 'win') as wins,
  count(*) filter (where result = 'lose') as losses,
  count(*) filter (where result = 'tie') as ties,
  max(player_score) as best_score,
  round(avg(player_score))::integer as avg_score,
  max(best_move_score) as best_move_score,
  (
    select g2.longest_word
    from games g2
    where g2.user_id = g.user_id and g2.longest_word is not null
    order by char_length(g2.longest_word) desc
    limit 1
  ) as longest_word,
  round(
    sum(move_points_sum) filter (where move_points_sum is not null)::numeric
      / nullif(sum(move_count) filter (where move_points_sum is not null), 0)::numeric,
    2
  ) as avg_move_score,
  count(*) filter (where rank = 1) as first_places,
  count(*) filter (where rank = 2) as second_places,
  (sum(
    case
      when surrendered then -2
      when rank = 1 then 2
      when rank = 2 and player_count <> 2 then 1
      else 0
    end
  ) + coalesce((select sum(r.points) from league_rewards r where r.user_id = g.user_id), 0))::integer as total_score,
  count(*) filter (where surrendered) as surrendered_count,
  count(*) filter (where online_game_id is null) as local_games_played,
  count(*) filter (where online_game_id is not null) as online_games_played,
  max(best_word_score) as best_word_score,
  coalesce((select max(r.threshold) from league_rewards r where r.user_id = g.user_id and r.kind = 'rank_up'), 0)::integer as rank_tier,
  coalesce((select sum(r.points) from league_rewards r where r.user_id = g.user_id), 0)::integer as bonus_points
from games g
where user_id is not null
group by user_id;

-- 2) leaderboard — total_score ödül dahil, sona rank_tier eklendi
-- (satırlardaki mühür rozeti için).
create or replace view public.leaderboard
with (security_invoker = true) as
select
  g.user_id,
  p.username,
  p.first_name,
  p.last_name,
  p.display_name,
  p.avatar_url,
  max(g.player_score)                       as best_score,
  (sum(
    case
      when g.surrendered then -2
      when g.rank = 1 then 2
      when g.rank = 2 and g.player_count <> 2 then 1
      else 0
    end
  ) + coalesce((select sum(r.points) from public.league_rewards r where r.user_id = g.user_id), 0))::int as total_score,
  count(*)                                  as games_played,
  count(*) filter (where g.result = 'win')  as wins,
  coalesce((select max(r.threshold) from public.league_rewards r where r.user_id = g.user_id and r.kind = 'rank_up'), 0)::int as rank_tier
from public.games g
inner join public.profiles p on p.id = g.user_id
group by g.user_id, p.username, p.first_name, p.last_name, p.display_name, p.avatar_url
order by total_score desc;

-- 3) my_leaderboard_rank — sıralama da ödül dahil toplamla hesaplanmalı,
-- aksi halde leaderboard view'ıyla farklı sıra üretirdi.
create or replace function public.my_leaderboard_rank (p_user_id uuid)
  returns table (rank bigint, total_score bigint)
  language sql
  stable
  security invoker
  set search_path = public
  as $$
  select ranked.rank, ranked.total_score
  from (
    select
      g.user_id,
      sum(
        case
          when g.surrendered then -2
          when g.rank = 1 then 2
          when g.rank = 2 and g.player_count <> 2 then 1
          else 0
        end
      ) + coalesce((select sum(r.points) from public.league_rewards r where r.user_id = g.user_id), 0) as total_score,
      rank() over (
        order by sum(
          case
            when g.surrendered then -2
            when g.rank = 1 then 2
            when g.rank = 2 and g.player_count <> 2 then 1
            else 0
          end
        ) + coalesce((select sum(r.points) from public.league_rewards r where r.user_id = g.user_id), 0) desc
      ) as rank
    from public.games g
    where g.user_id is not null
    group by g.user_id
  ) ranked
  where ranked.user_id = p_user_id;
$$;

-- ---- Geriye dönük backfill: mevcut kullanıcıların hak edişleri ----
-- Kuru önizleme (11 Ağustos 2026): 3 kullanıcı +5 oyun ödülü (50+ tamamlanan
-- oyun), 4 kullanıcı rank_tier=25 (Meraklı), henüz kimse 100 puan eşiğinde
-- değil. Satırlar seen_at=null açılır — her kullanıcı ilk girişte tek bir
-- birleşik kutlama banner'ı görür (istemci hepsini tek seferde işaretler).
select public._award_league_rewards(u.user_id)
from (select distinct user_id from public.games where user_id is not null) u;
