-- Sohbet gizliliğinin ikinci yarısı (10 Ağustos 2026, kullanıcı kararı):
-- `game_chat_archive_participants_only` İÇERİĞİ kapattı ama `message_count`
-- bilerek okunabilir bırakılmıştı ("rozet fazladan bir istek atmadan
-- çizilsin"). Kullanıcı bunu yeniden değerlendirip "sadece yetkisi olanlara
-- gözüksün" dedi — haklı: "X ile Y şu oyunda N mesajlaştı" da bir üstveri ve
-- rozetin kendisi zaten AÇILAMAYAN bir kontroldü (dokununca "yetkiniz yok").
--
-- Kapatmanın maliyeti sıfıra yakın, çünkü liste zaten sayfa başına TEK bir
-- toplu RPC çağırıyor: `game_like_stats(p_game_ids)`. Sayaç oraya
-- eklendiğinden EK BİR GİDİŞ-DÖNÜŞ YOK. Fonksiyonun adı artık dar kalıyor
-- (yalnızca beğeni değil, kartın tüm rozetlerini besliyor) ama BİLEREK
-- yeniden adlandırılmadı: canlıdaki web bu adı çağırıyor, yeniden
-- adlandırmak deploy'a kadar beğenileri de kırardı. Yeni bir kolon eklemek
-- eski istemciyi hiç etkilemiyor (fazladan alanı yok sayıyor).
--
-- `game_like_stats` artık SECURITY DEFINER olmak ZORUNDA: `message_count`
-- istemci rollerinden kaldırıldığından INVOKER bir fonksiyon o kolonu
-- okuyamaz. Definer'a geçince RLS de bypass edildiğinden, misafirin (uid
-- null) eskiden RLS sayesinde hiçbir satır alamaması davranışı elle
-- korunuyor (`auth.uid() is not null` koşulu).
--
-- `list_liked_games` (Favoriler sekmesi) INVOKER kalıyor ve `message_count`
-- dönüşünden ÇIKARILDI — sayaç artık her iki sekmede de tek kaynaktan
-- (`game_like_stats`) geliyor.

-- 1) message_count kolonunu istemci rollerinden kaldır. (Tablo düzeyinde
--    SELECT varken kolon REVOKE'u etkisiz — bkz. önceki migration.)
revoke select on public.games from anon;
revoke select on public.games from authenticated;

grant select (
  id, user_id, player_score, ai_score, result, turn_count, created_at,
  best_move_score, move_count, move_points_sum, player_count, rank,
  surrendered, players, longest_word, board_snapshot, shared, shared_at,
  online_game_id, best_word_score
) on public.games to anon;

grant select (
  id, user_id, player_score, ai_score, result, turn_count, created_at,
  best_move_score, move_count, move_points_sum, player_count, rank,
  surrendered, players, longest_word, board_snapshot, shared, shared_at,
  online_game_id, best_word_score
) on public.games to authenticated;

-- 2) Kart rozetleri tek toplu RPC'den; sohbet sayacı katılımcı/admin kapılı.
drop function if exists public.game_like_stats(uuid[]);

create function public.game_like_stats(p_game_ids uuid[])
returns table(
  game_id uuid,
  like_count bigint,
  liked_by_me boolean,
  message_count bigint
)
language sql
stable
security definer
set search_path to 'public'
as $$
  with targets as (
    select g.id as requested_id,
           coalesce(
             (select min(g2.id::text)::uuid
                from public.games g2
               where g2.online_game_id = g.online_game_id),
             g.id
           ) as canonical_id,
           g.online_game_id as ogid,
           g.message_count as msg_count
    from public.games g
    where g.id = any(p_game_ids)
      -- Definer olduğumuz için RLS devrede değil; misafirin hiçbir şey
      -- görmemesi davranışı elle korunuyor.
      and auth.uid() is not null
  )
  select t.requested_id as game_id,
         count(gl.user_id) as like_count,
         coalesce(bool_or(gl.user_id = auth.uid()), false) as liked_by_me,
         case
           when t.ogid is null then 0::bigint  -- yerel oyunda sohbet yok
           when public.is_admin()
                or public.is_online_game_participant(t.ogid, auth.uid())
             then coalesce(t.msg_count, 0)::bigint
           else 0::bigint                       -- yetkisiz: rozet hiç çıkmaz
         end as message_count
  from targets t
  left join public.game_likes gl on gl.game_id = t.canonical_id
  group by t.requested_id, t.ogid, t.msg_count;
$$;

revoke all on function public.game_like_stats(uuid[]) from public;
revoke all on function public.game_like_stats(uuid[]) from anon;
grant execute on function public.game_like_stats(uuid[]) to authenticated;

-- 3) Favoriler listesi artık sayacı taşımıyor (tek kaynak: yukarıdaki RPC).
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
  liked_at timestamp with time zone
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
    gl.created_at as liked_at
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
