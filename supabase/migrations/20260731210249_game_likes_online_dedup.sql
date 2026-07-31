-- Bir Canlı (online_game_id dolu) oyunda, oyun bitince HER insan katılımcı
-- için AYRI bir `games` satırı açılıyor (bkz. CLAUDE.md "Canlı Oyun — Faz 3",
-- _finish_online_game_records) — aynı `online_game_id`'yi paylaşan, ama farklı
-- `id`/`user_id` taşıyan N satır. `game_likes.game_id` bugüne kadar bu
-- SPESİFİK satırın id'sine bağlıydı, yani aynı gerçek oyun iki farklı
-- kullanıcının kendi satırından ayrı ayrı beğenilebiliyordu — kullanıcı
-- bunu bizzat yaşadı: kendi satırından beğendiğinde favorilerinde bir
-- kayıt, rakibinin skor kartından AYNI oyunu beğendiğinde farklı görünüşte
-- (farklı isim/perspektif) İKİNCİ bir kayıt oluşuyordu — sanki aynı oyunu
-- iki kez, biri kendisiyle oynamış gibi.
--
-- Düzeltme üç parça: (1) beğeni artık `online_game_id` grubu için TEK bir
-- kanonik satıra (grup içindeki en küçük id) bağlanıyor — hangi satırdan
-- beğenilirse beğenilsin aynı satırda birikiyor, tek kayıt/tek toggle;
-- (2) mevcut mükerrer beğeniler bu migration'da kanonik satıra taşınıp
-- fazlalıklar siliniyor; (3) favoriler listesi artık kanonik satırı OLDUĞU
-- GİBİ değil, hedef kullanıcının (favorileri görüntülenen kişinin) KENDİ
-- katılımcı satırı varsa onu tercih ederek gösteriyor (list_liked_games) —
-- aksi halde GameHistoryModal'daki "meIndex"/güncel takma isim ikamesi
-- (bkz. GameHistoryModal.tsx satır ~192) kanonik satırın SAHİBİNİ "ben"
-- sanıp yanlış oyuncuyu vurgulardı (kullanıcının bildirdiği "sanki
-- kendimle oynamışım gibi" görünümünün asıl sebebi buydu).

-- ── 1) Mevcut mükerrer beğenileri kanonik satıra taşı ──────────────────────
with canonical_map as (
  select g.id as game_id, (min(g.id::text) over (partition by g.online_game_id))::uuid as canonical_id
  from public.games g
  where g.online_game_id is not null
)
insert into public.game_likes (game_id, user_id, created_at)
select cm.canonical_id, gl.user_id, min(gl.created_at)
from public.game_likes gl
join canonical_map cm on cm.game_id = gl.game_id
where cm.game_id <> cm.canonical_id
group by cm.canonical_id, gl.user_id
on conflict (game_id, user_id) do nothing;

with canonical_map as (
  select g.id as game_id, (min(g.id::text) over (partition by g.online_game_id))::uuid as canonical_id
  from public.games g
  where g.online_game_id is not null
)
delete from public.game_likes gl
using canonical_map cm
where cm.game_id = gl.game_id
  and cm.game_id <> cm.canonical_id;

-- ── 2) toggle_game_like — artık kanonik satıra karşı çalışıyor ─────────────
create or replace function public.toggle_game_like(p_game_id uuid)
returns boolean
language plpgsql
set search_path to 'public'
as $$
declare
  v_new boolean;
  v_canonical uuid;
begin
  if auth.uid() is null then
    raise exception 'Yetkisiz erişim.';
  end if;

  select coalesce(
    (select min(g2.id::text)::uuid from public.games g2 where g2.online_game_id = g.online_game_id),
    g.id
  ) into v_canonical
  from public.games g
  where g.id = p_game_id;

  if v_canonical is null then
    raise exception 'Oyun bulunamadı.';
  end if;

  if exists (select 1 from public.game_likes where game_id = v_canonical and user_id = auth.uid()) then
    delete from public.game_likes where game_id = v_canonical and user_id = auth.uid();
    v_new := false;
  else
    insert into public.game_likes (game_id, user_id) values (v_canonical, auth.uid());
    v_new := true;
  end if;

  return v_new;
end;
$$;

-- ── 3) game_like_stats — istenen her id için kanonik satırın sayısını/beğeni
-- durumunu döner (istenen id'nin kendisiyle, LiveGamesTab'daki gibi hangi
-- satırdan sorulursa sorulsun aynı sonuç) ──────────────────────────────────
create or replace function public.game_like_stats(p_game_ids uuid[])
returns table(game_id uuid, like_count bigint, liked_by_me boolean)
language sql
stable
set search_path to 'public'
as $$
  with targets as (
    select g.id as requested_id,
           coalesce(
             (select min(g2.id::text)::uuid from public.games g2 where g2.online_game_id = g.online_game_id),
             g.id
           ) as canonical_id
    from public.games g
    where g.id = any(p_game_ids)
  )
  select t.requested_id as game_id,
         count(gl.user_id) as like_count,
         coalesce(bool_or(gl.user_id = auth.uid()), false) as liked_by_me
  from targets t
  left join public.game_likes gl on gl.game_id = t.canonical_id
  group by t.requested_id;
$$;

-- ── 4) game_likers — aynı kanonikleştirme ──────────────────────────────────
create or replace function public.game_likers(p_game_id uuid)
returns table(user_id uuid, display_name text, first_name text, avatar_url text)
language sql
security definer
stable
set search_path to 'public'
as $$
  with canonical as (
    select coalesce(
      (select min(g2.id::text)::uuid from public.games g2 where g2.online_game_id = g.online_game_id),
      g.id
    ) as id
    from public.games g
    where g.id = p_game_id
  )
  select p.id, p.display_name, p.first_name, p.avatar_url
  from public.game_likes gl
  join public.profiles p on p.id = gl.user_id
  join canonical c on c.id = gl.game_id
  order by gl.created_at desc;
$$;

-- ── 5) list_liked_games — favoriler listesi artık game_likes.game_id'yi
-- (kanonik satır) OLDUĞU GİBİ değil, p_user_id'nin (favorileri görüntülenen
-- kişi) o online_game_id için KENDİ satırı varsa onu göstererek döner —
-- fetchMyGames'in eski `game_likes.select('games!inner(...)')` join'inin
-- yerine geçer. Yerel (online_game_id null) oyunlarda tek satır zaten
-- olduğundan davranış değişmiyor.
create or replace function public.list_liked_games(
  p_user_id uuid,
  p_player_count int default null,
  p_offset int default 0,
  p_limit int default 20
)
returns table (
  id uuid,
  created_at timestamptz,
  player_count int,
  players jsonb,
  player_score int,
  ai_score int,
  rank int,
  surrendered boolean,
  online_game_id uuid,
  message_count int,
  user_id uuid,
  liked_at timestamptz
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
    coalesce(mine.message_count, g.message_count) as message_count,
    coalesce(mine.user_id, g.user_id) as user_id,
    gl.created_at as liked_at
  from public.game_likes gl
  join public.games g on g.id = gl.game_id
  left join public.games mine
    on g.online_game_id is not null
    and mine.online_game_id = g.online_game_id
    and mine.user_id = p_user_id
  where gl.user_id = p_user_id
    and (p_player_count is null or coalesce(mine.player_count, g.player_count) = p_player_count)
  order by gl.created_at desc
  offset p_offset
  limit p_limit + 1;
$$;

revoke all on function public.list_liked_games(uuid, int, int, int) from public, anon;
grant execute on function public.list_liked_games(uuid, int, int, int) to authenticated;
