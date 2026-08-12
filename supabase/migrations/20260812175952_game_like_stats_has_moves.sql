-- Hamle geçmişi ikonu yalnızca GERÇEKTEN dökümü olan kartlarda görünsün
-- (12 Ağustos 2026, kullanıcı bildirdi: "YZ oyunlarda içi boş geliyor").
--
-- Kök sebep bir hata DEĞİL: `games.moves` bugün eklendi ve Canlı oyunlar
-- migration içinde geriye dönük dolduruldu (66/66), yerel/YZ oyunlar ise
-- dolduruLAMADI (bitmiş bir yerel oyunun `moveHistory`'si hiçbir yerde
-- saklanmıyor — kurtarılacak veri yok). Yani bugün YZ kartlarının hepsi
-- boş; BUNDAN SONRA bitenler dolu olacak. Bu yüzden ikonu "YZ oyunlarda
-- hiç gösterme" YANLIŞ olurdu — doğru kural "dökümü olmayan kartta
-- gösterme".
--
-- Karar bilgisi liste sorgusuna `moves`u ÇEKMEDEN gerekiyor (satır başına
-- ~6.8 KB; lazy yükleme tam bu yüzden var), o yüzden kartın öteki
-- rozetlerini zaten besleyen `game_like_stats`e ekleniyor — sayfa başına
-- TEK toplu RPC, EK BİR GİDİŞ-DÖNÜŞ YOK. `message_count` ile aynı desen.
--
-- `has_moves` katılımcı kapısına TABİ DEĞİL (mesaj sayacının aksine):
-- `moves` kolonunun kendisi istemci rollerine açık (bkz.
-- `games_moves_snapshot`) ve içeriği zaten herkese görünür olan
-- `board_snapshot`ın anlattığından fazlasını söylemiyor — oyun kaydı,
-- özel yazışma değil. Yalnızca misafir (uid null) kapısı korunuyor.
--
-- Dönüş tipi değiştiğinden `create or replace` YETMEZ: drop + create ve
-- grant'ler elle yeniden kuruluyor.

drop function if exists public.game_like_stats(uuid[]);

create function public.game_like_stats(p_game_ids uuid[])
returns table (
  game_id uuid,
  like_count bigint,
  liked_by_me boolean,
  message_count bigint,
  has_moves boolean
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
           g.message_count as msg_count,
           (g.moves is not null) as has_moves
    from public.games g
    where g.id = any(p_game_ids)
      and auth.uid() is not null
  )
  select t.requested_id as game_id,
         count(gl.user_id) as like_count,
         coalesce(bool_or(gl.user_id = auth.uid()), false) as liked_by_me,
         case
           when t.ogid is null then 0::bigint
           when public.is_admin()
                or public.is_online_game_participant(t.ogid, auth.uid())
             then coalesce(t.msg_count, 0)::bigint
           else 0::bigint
         end as message_count,
         t.has_moves
  from targets t
  left join public.game_likes gl on gl.game_id = t.canonical_id
  group by t.requested_id, t.ogid, t.msg_count, t.has_moves;
$$;

revoke all on function public.game_like_stats(uuid[]) from public, anon;
grant execute on function public.game_like_stats(uuid[]) to authenticated;
