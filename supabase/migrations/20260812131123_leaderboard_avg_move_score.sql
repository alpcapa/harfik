-- k-lig sıralamasına OHP (ortalama hamle puanı) kolonu
-- Kullanıcı isteği (12 Ağustos 2026): "leaderboard tablosunda Puan
-- kolonunun soluna OHP (ortalama hamle puanı) kolonu ekle".
--
-- İfade `player_stats_overall.avg_move_score` ile BİREBİR AYNI (ağırlıklı
-- ortalama: toplam hamle puanı / toplam hamle sayısı, 2 basamağa
-- yuvarlanmış). Bu bir tercih değil zorunluluk: aynı oyuncunun Skor
-- Kartı'ndaki "Ortalama Hamle Puanı" ile k-lig satırındaki OHP'si aynı
-- sayı olmalı — biri değişirse öteki de değişmeli.
--
-- View `drop` DEĞİL `create or replace` ile güncelleniyor: yeni kolon
-- SONA eklendiğinden bu mümkün ve böylece hem grant'ler hem
-- `security_invoker = false` ayarı (lock_down_profiles_games_select
-- migration'ı — view, `profiles`/`games`in kilitli SELECT RLS'ini sahibi
-- olarak aşıyor) olduğu gibi korunuyor. Kolon SIRASI kullanıcıya görünen
-- sırayı belirlemiyor; istemci `*` ile çekip alanları ADIYLA okuyor,
-- "Puan'ın soluna" yerleşimi UI'da yapılıyor.
create or replace view public.leaderboard as
  select
    g.user_id,
    p.username,
    p.first_name,
    p.last_name,
    p.display_name,
    p.avatar_url,
    max(g.player_score) as best_score,
    (sum(
      case
        when g.surrendered then -2
        when g.rank = 1 then 2
        when g.rank = 2 and g.player_count <> 2 then 1
        else 0
      end
    ) + coalesce((select sum(r.points) from public.league_rewards r where r.user_id = g.user_id), 0))::integer as total_score,
    count(*) as games_played,
    count(*) filter (where g.result = 'win') as wins,
    coalesce((select max(r.threshold) from public.league_rewards r where r.user_id = g.user_id and r.kind = 'rank_up'), 0) as rank_tier,
    round(
      sum(g.move_points_sum) filter (where g.move_points_sum is not null)::numeric
        / nullif(sum(g.move_count) filter (where g.move_points_sum is not null), 0)::numeric,
      2
    ) as avg_move_score
  from public.games g
  join public.profiles p on p.id = g.user_id
  group by g.user_id, p.username, p.first_name, p.last_name, p.display_name, p.avatar_url
  order by (sum(
      case
        when g.surrendered then -2
        when g.rank = 1 then 2
        when g.rank = 2 and g.player_count <> 2 then 1
        else 0
      end
    ) + coalesce((select sum(r.points) from public.league_rewards r where r.user_id = g.user_id), 0))::integer desc;

-- "Senin sıran" kısayolu (kullanıcı yüklenen satırlar arasında değilse
-- listenin altında ayrı bir satır olarak çizilir) AYNI tabloda AYNI
-- kolonları gösterdiğinden OHP'yi o da döndürmeli — aksi halde o tek
-- satırda kolon boş kalır ve tablo hizasız görünür.
-- Dönüş tipi değiştiğinden `create or replace` yetmiyor: drop + create,
-- ardından grant'ler elle geri kuruluyor.
drop function if exists public.my_leaderboard_rank(uuid);

create function public.my_leaderboard_rank(p_user_id uuid)
returns table(rank bigint, total_score bigint, avg_move_score numeric)
language sql
stable
set search_path to 'public'
as $$
  select ranked.rank, ranked.total_score, ranked.avg_move_score
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
      round(
        sum(g.move_points_sum) filter (where g.move_points_sum is not null)::numeric
          / nullif(sum(g.move_count) filter (where g.move_points_sum is not null), 0)::numeric,
        2
      ) as avg_move_score,
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

grant execute on function public.my_leaderboard_rank(uuid) to anon, authenticated, service_role;
