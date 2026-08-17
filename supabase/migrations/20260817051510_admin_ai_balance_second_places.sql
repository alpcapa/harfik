-- YZ Dengesi paneline 4 kişilik oyunlarda İKİNCİLİK sayısı eklendi.
--
-- Gerekçe: 4 kişilik oyunda k-lig ikinciliğe de puan veriyor
-- (`player_stats`: rank=2 AND player_count<>2 THEN 1), yani panel bugün
-- "insan puan alıyor mu" sorusunun yalnızca yarısını ölçüyordu.
--
-- Tanım BİLEREK `player_stats.second_places` ile BİREBİR aynı ifade
-- (`count(*) filter (where rank = 2)`) — aynı metriğin iki yerde sessizce
-- ayrışması bu projenin en sık tekrarlayan hata sınıfı (bkz. CountBadge
-- rozet zinciri, player_stats_overall_second_places).
--
-- Ölçüldü (17 Ağustos 2026, uygulanmadan önce): rank hiçbir satırda null
-- DEĞİL; rank=1 sayısı wins+ties'a eşit (2 kişilikte 98 = 95+3, 4 kişilikte
-- 30 = 29+1), yani `result='tie'` birincilik paylaşımı demek ve rank=2
-- kavramı iyi tanımlı.
--
-- Dönüş tipi değiştiğinden `create or replace` YETMEZ — drop + create
-- gerekiyor, grant'ler de elle yeniden kuruluyor (yeni fonksiyonda önce
-- "revoke all" kuralı).

drop function if exists public.admin_ai_balance();

create function public.admin_ai_balance()
returns table(
  players integer,
  games bigint,
  wins bigint,
  ties bigint,
  losses bigint,
  second_places bigint
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
    count(*) filter (where g.rank = 2) as second_places
  from public.games g
  where g.online_game_id is null
    and not g.surrendered
  group by g.player_count
  order by g.player_count;
end;
$function$;

revoke all on function public.admin_ai_balance() from public, anon;
grant execute on function public.admin_ai_balance() to authenticated, service_role;
