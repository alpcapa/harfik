-- Oyun geçmişindeki "Paylaş" aksiyonu artık gerçek bir kelimeki.com/game/:id
-- linki üretiyor. games tablosu tamamen kilitli olduğundan (RLS: yalnızca
-- sahibi ya da admin okuyabiliyor), bir oyunu link üzerinden herkese açık
-- (girişsiz dahil) görünür kılmak için opsiyonel bir shared bayrağı ve iki
-- dar/security definer RPC ekleniyor:
--   - set_game_shared: yalnızca kendi oyununu paylaşabilen sahibi, shared'i
--     true'ya çeker (paylaş butonuna her basışta çağrılır, idempotent).
--   - get_shared_game: shared=true olan bir oyunun önizleme için gereken
--     minimum alanlarını (skor/kelime gibi başka hiçbir kişisel veri yok)
--     hem anon hem authenticated'e döner — /game/:id herkese açık sayfası bunu kullanır.
--
-- Supabase yeni fonksiyonlara varsayılan olarak hem anon hem authenticated'e
-- doğrudan EXECUTE veriyor (bkz. 20260725053640_revoke_toggle_game_favorite_anon
-- migration'ındaki aynı ders) — bu yüzden bu sefer baştan "revoke all" ile
-- temizleyip yalnızca istenen rollere grant ediliyor.

alter table public.games
  add column if not exists shared boolean not null default false;

create or replace function public.set_game_shared(p_game_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_owner uuid;
begin
  select user_id into v_owner from public.games where id = p_game_id;
  if v_owner is null or v_owner <> auth.uid() then
    raise exception 'Yetkisiz erişim.';
  end if;

  update public.games set shared = true where id = p_game_id;
  return true;
end;
$$;

revoke all on function public.set_game_shared(uuid) from public, anon, authenticated;
grant execute on function public.set_game_shared(uuid) to authenticated;

create or replace function public.get_shared_game(p_game_id uuid)
returns table(board_snapshot jsonb, players jsonb, player_count integer, created_at timestamptz)
language sql
security definer
stable
set search_path to 'public'
as $$
  select g.board_snapshot, g.players, g.player_count, g.created_at
  from public.games g
  where g.id = p_game_id and g.shared = true;
$$;

revoke all on function public.get_shared_game(uuid) from public, anon, authenticated;
grant execute on function public.get_shared_game(uuid) to anon, authenticated;
