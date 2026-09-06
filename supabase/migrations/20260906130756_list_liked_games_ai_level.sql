-- Seviyeli YZ — Faz 3: `list_liked_games` dönüşüne `ai_level` (ROADMAP #23,
-- 23.3 → "Faz 3 — Web ürün yüzeyi").
--
-- NEDEN: Faz 1 (`20260906114252`) `games.ai_level` kolonunu ve kolon
-- düzeyinde SELECT'i verdi; `fetchMyGames`in `cols` dizesi o günden beri
-- seçiyor. Beğenilenler sekmesi ise bu RPC'den okuyor ve RPC kolonu
-- DÖNDÜRMÜYORDU — Faz 3'te kartlar puanı seviyeyle hesaplarken o sekme
-- Kolay bir oyunun puanını Normal formülüyle (+2) gösterecekti; aynı oyun
-- "Tüm Oyunlarım"da +1. `GameHistoryEntry.ai_level` bu yüzden opsiyoneldi;
-- bu migration'dan sonra iki kaynak da veriyor ve alan zorunluya çekildi.
--
-- TUZAK (23.4): dönüş tipi değişiyor → `create or replace` "cannot change
-- return type" verir → drop + create + grant elle. Fonksiyon INVOKER
-- (`security definer` DEĞİL — 20260810174204'teki karar aynen korunuyor:
-- `games`in kolon grant'leri okuyanı sınırlar; `ai_level` SELECT'i Faz 1'de
-- verildi, yani invoker altında okunabilir — ölçüldü, aşağıdaki doğrulama).
-- Gövde `coalesce(mine.X, g.X)` deseniyle aynen: Canlı oyunda beğenilen
-- satır başkasınınsa KENDİ satırım tercih ediliyor (orada `ai_level` her
-- zaman null — Canlı'da seviye yok; desen yine de bozulmasın diye aynı).
--
-- DOĞRULAMA (uygulama sonrası, MCP `execute_sql`):
--   select proname, prosecdef, pg_get_function_result(oid)
--   from pg_proc where proname = 'list_liked_games';
--   → prosecdef = false, sonuç tipinin son kolonu `ai_level text`.

drop function if exists public.list_liked_games(uuid, integer, integer, integer);

create function public.list_liked_games(
  p_user_id uuid,
  p_player_count integer default null,
  p_offset integer default 0,
  p_limit integer default 20
)
returns table(
  id uuid,
  created_at timestamp with time zone,
  player_count integer,
  players jsonb,
  player_score integer,
  ai_score integer,
  rank integer,
  surrendered boolean,
  online_game_id uuid,
  user_id uuid,
  liked_at timestamp with time zone,
  ai_level text
)
language sql
stable
set search_path to 'public'
as $$
  select
    coalesce(mine.id, g.id) as id,
    coalesce(mine.created_at, g.created_at) as created_at,
    coalesce(mine.player_count, g.player_count) as player_count,
    coalesce(mine.players, g.players) as players,
    coalesce(mine.player_score, g.player_score) as player_score,
    coalesce(mine.ai_score, g.ai_score) as ai_score,
    coalesce(mine.rank, g.rank) as rank,
    coalesce(mine.surrendered, g.surrendered) as surrendered,
    coalesce(mine.online_game_id, g.online_game_id) as online_game_id,
    coalesce(mine.user_id, g.user_id) as user_id,
    gl.created_at as liked_at,
    coalesce(mine.ai_level, g.ai_level) as ai_level
  from public.game_likes gl
  join public.games g on g.id = gl.game_id
  left join public.games mine
    on g.online_game_id is not null
    and mine.online_game_id = g.online_game_id
    and mine.user_id = p_user_id
  where gl.user_id = p_user_id
    and (p_player_count is null
         or coalesce(mine.player_count, g.player_count) = p_player_count)
  order by gl.created_at desc
  offset p_offset
  limit p_limit + 1;
$$;

revoke all on function public.list_liked_games(uuid, integer, integer, integer) from public;
revoke all on function public.list_liked_games(uuid, integer, integer, integer) from anon;
grant execute on function public.list_liked_games(uuid, integer, integer, integer) to authenticated;
