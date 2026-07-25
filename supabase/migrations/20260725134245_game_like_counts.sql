-- Kalp ikonunun yanında toplam beğeni sayısını göstermek için: bir grup oyun
-- id'si verildiğinde her biri için toplam beğeni sayısını VE çağıranın kendi
-- beğenip beğenmediğini tek sorguda döner (fetchMyGames'in ayrı bir
-- "myLikes" sorgusuna daha ihtiyacı kalmıyor, aynı bilgiyi burada veriyoruz).
-- game_likes SELECT RLS'i zaten herhangi bir girişli kullanıcıya açık
-- olduğundan (bkz. game_likes_and_public_sharing migration'ı) security
-- definer'a gerek yok.
create or replace function public.game_like_stats(p_game_ids uuid[])
returns table(game_id uuid, like_count bigint, liked_by_me boolean)
language sql
stable
set search_path to 'public'
as $$
  select gl.game_id, count(*) as like_count, bool_or(gl.user_id = auth.uid()) as liked_by_me
  from public.game_likes gl
  where gl.game_id = any(p_game_ids)
  group by gl.game_id;
$$;

revoke all on function public.game_like_stats(uuid[]) from public, anon;
grant execute on function public.game_like_stats(uuid[]) to authenticated;
