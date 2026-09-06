-- Seviyeli YZ — Faz 1: sunucu (ROADMAP #23, 23.3 → "Faz 1 — Sunucu").
--
-- SIFIR DAVRANIŞ DEĞİŞİKLİĞİ. Bu migration'dan sonra hiçbir kullanıcı için
-- tek bir k-lig puanı değişmez: bugüne kadarki HER `games` satırı `ai_level`
-- = null taşır ve null Normal dalıdır (bugünkü formül). Kanıt aşağıda,
-- "Uygulama öncesi/sonrası" bölümünde — uygulamadan önce ve sonra alınan
-- karma değerleri birebir aynı.
--
-- =============================== NE GELDİ ===============================
-- 1) `games.ai_level` — yerel YZ oyununda seçilen zorluk: kolay | normal |
--    zor. Null = seviyesiz kayıt (bu migration'dan önceki her şey + TÜM
--    Canlı oyunlar; Canlı'da seviye yok, Normal sayılır — 23.0).
-- 2) `league_points_for(rank, player_count, surrendered, ai_level)` —
--    k-lig puan tablosunun TEK SQL kaynağı. Bugüne kadar bu formül
--    ("teslim -2, 1. +2, 2. +1 yalnız 4 kişilikte") sunucuda BEŞ kopya
--    hâlinde yaşıyordu ve beşi de `case` bloğu olarak elle senkrondu:
--      player_stats · player_stats_overall · leaderboard (view'lar)
--      _award_league_rewards · trg_award_league_rewards (fonksiyonlar)
--    ⚠ ROADMAP 23.1 DÖRT diyordu; beşincisi (`trg_award_league_rewards`,
--    `rank_down_notice` migration'ının delta hesabı) canlıdan
--    `pg_get_functiondef` ile bulundu — bir kopya daha kaçmıştı. Beşi de
--    artık bu fonksiyonu çağırıyor; `k_lig_siralama` ve
--    `my_leaderboard_rank` `leaderboard`dan okuduğundan kendiliğinden
--    düzeldi (onlara dokunulmadı).
-- 3) `get_shared_game` dönüşüne `ai_level` — `/game/:id` sayfası Faz 3'te
--    kartta seviyeyi gösterecek ve puanı doğru formülle hesaplayacak.
-- 4) `admin_ai_balance` seviye kırılımı — Kolay ~%30 / Zor ~%70 hedefleri
--    SAHADA yalnızca bununla ölçülecek (23.0). Bugün tek satır grubu
--    (`normal`), yani panel değişmeden çalışır.
--
-- ============================ PUAN TABLOSU (23.0) =========================
--   | Oyun                       | 1. sıra          | 2. sıra          | Teslim |
--   | Yerel 2 kişilik            | 1 / 2 / 4        | yok              | -2     |
--   | Yerel 4 kişilik            | 1 / 2 / 4        | 0 / 1 / 2        | -2     |
--   | Canlı 4 kişilik (seviyesiz)| 2                | 1                | -2     |
--   (Kolay / Normal / Zor; Normal = bugünkü değer, her hücrede.)
-- Tablo aşağıda bir `(values ...)` listesi olarak yazıldı ki
-- `npm run verify-league-points` onu MEKANİK olarak ayrıştırıp web'in
-- `leaguePoints.ts`i ve portun `league_points.dart`ıyla karşılaştırabilsin
-- (`verify-league-tiers`in deseni). Listeyi `case`e çevirme — betik kör kalır.
--
-- =============================== TUZAKLAR ================================
-- * `games`in tablo düzeyinde SELECT grant'i YOK (10 Ağustos 2026 gizlilik
--   düzeltmesi), kolon tek tek verilir. `platform` şablonu SELECT'i bilerek
--   VERMİYORDU; burada tersi ŞART: geçmiş kartları ve `fetchMyGames` puanı
--   bu kolonla hesaplayacak (Faz 3). INSERT tablo düzeyinde zaten var
--   (canlıdan ölçüldü), yine de açıkça yazıldı — `platform`la aynı desen.
-- * Dönüş tipi değişen iki fonksiyon (`get_shared_game`, `admin_ai_balance`)
--   `create or replace` ile GÜNCELLENEMEZ ("cannot change return type") →
--   drop + create + revoke/grant elle (20260812131123 dersi).
-- * View'lar `create or replace` ile: kolon listesi değişmiyor, yani
--   grant'ler ve `security_invoker` ayarları olduğu gibi kalıyor.
-- * `_award_league_rewards` gövde değişikliği, imza aynı (uuid, integer).
--
-- ====================== UYGULAMA ÖNCESİ / SONRASI KANITI ==================
-- Uygulamadan ÖNCE (6 Eylül 2026) alınan karmalar, uygulamadan SONRA aynı
-- sorguyla yeniden alındı ve BİREBİR eşleşti (satır sayısı + md5):
--   select 'player_stats_overall', count(*), md5(string_agg(user_id::text||':'||total_score||':'||rank_tier||':'||bonus_points, ',' order by user_id)) from public.player_stats_overall
--   union all select 'player_stats', count(*), md5(string_agg(user_id::text||':'||player_count||':'||total_score, ',' order by user_id, player_count)) from public.player_stats
--   union all select 'leaderboard', count(*), md5(string_agg(user_id::text||':'||total_score||':'||rank_tier, ',' order by user_id)) from public.leaderboard
--   union all select 'k_lig_siralama', count(*), md5(string_agg(user_id::text||':'||sira||':'||total_score, ',' order by user_id)) from public.k_lig_siralama
--   union all select 'league_rewards', count(*), md5(string_agg(user_id::text||':'||kind||':'||threshold||':'||points, ',' order by user_id, kind, threshold)) from public.league_rewards;
--   ÖNCE: player_stats_overall 30 / 6a1c0f01… · player_stats 48 / 8adaa454… ·
--         leaderboard 30 / b0344e3d… · k_lig_siralama 30 / a8a74692… ·
--         league_rewards 27 / 0cf352bb…   (953 oyun)
--   SONRA: aynı beş değer, bayt-eş.
-- Ayrıca `admin_ai_balance()`nin eski çıktısı (2 kişilik 620 oyun
-- 321G/3B/296M, 4 kişilik 115 oyun 35G/1B/79M/24 ikincilik) yeni sürümde
-- `ai_level='normal'` etiketiyle aynen döndü.

-- ---------------------------------------------------------------------------
-- 1) games.ai_level
-- ---------------------------------------------------------------------------
alter table public.games
  add column if not exists ai_level text
  check (ai_level is null or ai_level in ('kolay', 'normal', 'zor'));

comment on column public.games.ai_level is
  'Yerel YZ oyununda seçilen zorluk: kolay | normal | zor (ROADMAP #23). Null = seviyesiz kayıt '
  '(bu kolondan önce biten her oyun + TÜM Canlı oyunlar) ve Normal sayılır — k-lig puanı '
  'league_points_for() ile hesaplanır, null orada Normal dalına düşer. Oyun BAŞINDA kilitlenir, '
  'oyun içinde değiştirilemez; 4 kişilikte üç YZ''ye birden uygulanır. Yazan: istemci '
  '(buildGameRecord, Faz 3''ten itibaren).';

-- INSERT tablo düzeyinde zaten var (ölçüldü), SELECT ise kolon kolon veriliyor
-- ve bu kolon için ŞART (bkz. yukarıdaki tuzak). İkisi de açıkça.
grant insert (ai_level), select (ai_level) on public.games to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) league_points_for — k-lig puanının TEK SQL kaynağı
-- ---------------------------------------------------------------------------
-- immutable: girdisi dışında hiçbir şeye bakmıyor; view'ların içinde satır
-- başına çağrıldığından planlayıcının inline edebilmesi için bu şart.
-- ⚠ `(values ...)` listesi `npm run verify-league-points` tarafından
-- ayrıştırılıyor: satır biçimi `('seviye', sıra, puan)` — değiştirme.
create or replace function public.league_points_for(
  p_rank integer,
  p_player_count integer,
  p_surrendered boolean,
  p_ai_level text
)
returns integer
language sql
immutable
parallel safe
set search_path to ''
as $$
  select case
    when p_surrendered then -2
    -- 2 kişilikte ikincilik = kaybetmek; puan yok, seviyeden bağımsız.
    when p_rank = 2 and p_player_count = 2 then 0
    else coalesce((
      select t.puan
      from (values
        ('kolay',  1, 1), ('kolay',  2, 0),
        ('normal', 1, 2), ('normal', 2, 1),
        ('zor',    1, 4), ('zor',    2, 2)
      ) as t(seviye, sira, puan)
      where t.seviye = coalesce(p_ai_level, 'normal') and t.sira = p_rank
    ), 0)
  end;
$$;

comment on function public.league_points_for(integer, integer, boolean, text) is
  'k-lig puan tablosunun tek kaynağı (ROADMAP #23, 23.0): teslim -2; 1. sıra Kolay 1 / Normal 2 / Zor 4; '
  '2. sıra yalnız 4 kişilikte Kolay 0 / Normal 1 / Zor 2; diğer 0. ai_level null = Normal. '
  'Web leaguePoints.ts ve port league_points.dart aynı tabloyu taşır — npm run verify-league-points kilitler.';

revoke all on function public.league_points_for(integer, integer, boolean, text) from public;
grant execute on function public.league_points_for(integer, integer, boolean, text)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3) Beş kopya → tek çağrı
-- ---------------------------------------------------------------------------
-- 3a) player_stats (mod bazlı) — kolon listesi/sırası DEĞİŞMEDİ.
create or replace view public.player_stats as
 SELECT user_id,
    player_count,
    count(*) AS games_played,
    count(*) FILTER (WHERE result = 'win'::text) AS wins,
    count(*) FILTER (WHERE result = 'lose'::text) AS losses,
    count(*) FILTER (WHERE result = 'tie'::text) AS ties,
    max(player_score) AS best_score,
    round(avg(player_score))::integer AS avg_score,
    max(best_move_score) AS best_move_score,
    ( SELECT g2.longest_word
           FROM games g2
          WHERE g2.user_id = g.user_id AND g2.player_count = g.player_count AND g2.longest_word IS NOT NULL
          ORDER BY (char_length(g2.longest_word)) DESC
         LIMIT 1) AS longest_word,
    round(sum(move_points_sum) FILTER (WHERE move_points_sum IS NOT NULL)::numeric / NULLIF(sum(move_count) FILTER (WHERE move_points_sum IS NOT NULL), 0)::numeric, 2) AS avg_move_score,
    count(*) FILTER (WHERE rank = 1) AS first_places,
    count(*) FILTER (WHERE rank = 2) AS second_places,
    sum(public.league_points_for(rank, player_count, surrendered, ai_level))::integer AS total_score,
    count(*) FILTER (WHERE surrendered) AS surrendered_count,
    count(*) FILTER (WHERE online_game_id IS NULL) AS local_games_played,
    count(*) FILTER (WHERE online_game_id IS NOT NULL) AS online_games_played,
    max(best_word_score) AS best_word_score
   FROM games g
  WHERE user_id IS NOT NULL
  GROUP BY user_id, player_count;

-- 3b) player_stats_overall — kolon listesi/sırası DEĞİŞMEDİ.
create or replace view public.player_stats_overall as
 SELECT user_id,
    count(*) AS games_played,
    count(*) FILTER (WHERE result = 'win'::text) AS wins,
    count(*) FILTER (WHERE result = 'lose'::text) AS losses,
    count(*) FILTER (WHERE result = 'tie'::text) AS ties,
    max(player_score) AS best_score,
    round(avg(player_score))::integer AS avg_score,
    max(best_move_score) AS best_move_score,
    ( SELECT g2.longest_word
           FROM games g2
          WHERE g2.user_id = g.user_id AND g2.longest_word IS NOT NULL
          ORDER BY (char_length(g2.longest_word)) DESC
         LIMIT 1) AS longest_word,
    round(sum(move_points_sum) FILTER (WHERE move_points_sum IS NOT NULL)::numeric / NULLIF(sum(move_count) FILTER (WHERE move_points_sum IS NOT NULL), 0)::numeric, 2) AS avg_move_score,
    count(*) FILTER (WHERE rank = 1) AS first_places,
    count(*) FILTER (WHERE rank = 2) AS second_places,
    (sum(public.league_points_for(rank, player_count, surrendered, ai_level))
      + COALESCE(( SELECT sum(r.points) AS sum
           FROM league_rewards r
          WHERE r.user_id = g.user_id), 0::bigint))::integer AS total_score,
    count(*) FILTER (WHERE surrendered) AS surrendered_count,
    count(*) FILTER (WHERE online_game_id IS NULL) AS local_games_played,
    count(*) FILTER (WHERE online_game_id IS NOT NULL) AS online_games_played,
    max(best_word_score) AS best_word_score,
    COALESCE(( SELECT max(r.threshold) AS max
           FROM league_rewards r
          WHERE r.user_id = g.user_id AND r.kind = 'rank_up'::text), 0) AS rank_tier,
    COALESCE(( SELECT sum(r.points) AS sum
           FROM league_rewards r
          WHERE r.user_id = g.user_id), 0::bigint)::integer AS bonus_points
   FROM games g
  WHERE user_id IS NOT NULL
  GROUP BY user_id;

-- 3c) leaderboard — kolon listesi/sırası DEĞİŞMEDİ (security_invoker=false
-- ayarı ve grant'ler korunuyor; k_lig_siralama + my_leaderboard_rank buradan
-- okuduğundan onlara dokunulmuyor).
create or replace view public.leaderboard as
 SELECT g.user_id,
    p.username,
    p.first_name,
    p.last_name,
    p.display_name,
    p.avatar_url,
    max(g.player_score) AS best_score,
    (sum(public.league_points_for(g.rank, g.player_count, g.surrendered, g.ai_level))
      + COALESCE(( SELECT sum(r.points) AS sum
           FROM league_rewards r
          WHERE r.user_id = g.user_id), 0::bigint))::integer AS total_score,
    count(*) AS games_played,
    count(*) FILTER (WHERE g.result = 'win'::text) AS wins,
    COALESCE(( SELECT max(r.threshold) AS max
           FROM league_rewards r
          WHERE r.user_id = g.user_id AND r.kind = 'rank_up'::text), 0) AS rank_tier,
    round(sum(g.move_points_sum) FILTER (WHERE g.move_points_sum IS NOT NULL)::numeric / NULLIF(sum(g.move_count) FILTER (WHERE g.move_points_sum IS NOT NULL), 0)::numeric, 2) AS avg_move_score
   FROM games g
     JOIN profiles p ON p.id = g.user_id
  GROUP BY g.user_id, p.username, p.first_name, p.last_name, p.display_name, p.avatar_url
  ORDER BY ((sum(public.league_points_for(g.rank, g.player_count, g.surrendered, g.ai_level))
      + COALESCE(( SELECT sum(r.points) AS sum
           FROM league_rewards r
          WHERE r.user_id = g.user_id), 0::bigint))::integer) DESC;

-- 3d) _award_league_rewards — yalnızca v_base'in hesabı değişti; eşik/ödül
-- listeleri (`verify-league-tiers`in okuduğu üç `(values ...)`) AYNEN duruyor.
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

  select coalesce(sum(public.league_points_for(rank, player_count, surrendered, ai_level)), 0)::int
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

-- 3e) trg_award_league_rewards — BEŞİNCİ kopya (delta hesabı). Trigger'ın
-- kendisi (`games_award_league_rewards`, after insert) değişmiyor.
create or replace function public.trg_award_league_rewards()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.user_id is not null then
    perform _award_league_rewards(
      new.user_id,
      public.league_points_for(new.rank, new.player_count, new.surrendered, new.ai_level)
    );
  end if;
  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4) get_shared_game — dönüşe ai_level (dönüş tipi değişti → drop + create)
-- ---------------------------------------------------------------------------
drop function if exists public.get_shared_game(uuid);

create function public.get_shared_game(p_game_id uuid)
returns table(
  board_snapshot jsonb,
  players jsonb,
  player_count integer,
  created_at timestamptz,
  ai_level text
)
language sql
security definer
stable
set search_path to 'public'
as $$
  select g.board_snapshot, g.players, g.player_count, g.created_at, g.ai_level
  from public.games g
  where g.id = p_game_id and g.shared = true;
$$;

revoke all on function public.get_shared_game(uuid) from public, anon, authenticated;
grant execute on function public.get_shared_game(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) admin_ai_balance — seviye kırılımı (dönüş tipi değişti → drop + create)
-- ---------------------------------------------------------------------------
-- `not g.surrendered` filtresi ve tanımlar AYNEN korunuyor (23.4: yoksa
-- eski/yeni satırlar karşılaştırılamaz). Yeni kolon SONA eklendi; istemci
-- alanları adıyla okuyor. Null → 'normal' — bugünkü tek grup.
drop function if exists public.admin_ai_balance();

create function public.admin_ai_balance()
returns table(
  players integer,
  games bigint,
  wins bigint,
  ties bigint,
  losses bigint,
  second_places bigint,
  ai_level text
)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
begin
  if not public.is_admin () then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    g.player_count as players,
    count(*) as games,
    count(*) filter (where g.result = 'win') as wins,
    count(*) filter (where g.result = 'tie') as ties,
    count(*) filter (where g.result = 'lose') as losses,
    count(*) filter (where g.rank = 2) as second_places,
    coalesce(g.ai_level, 'normal') as ai_level
  from public.games g
  where g.online_game_id is null
    and not g.surrendered
  group by g.player_count, coalesce(g.ai_level, 'normal')
  order by g.player_count, coalesce(g.ai_level, 'normal');
end;
$function$;

revoke all on function public.admin_ai_balance() from public, anon;
grant execute on function public.admin_ai_balance() to authenticated, service_role;
