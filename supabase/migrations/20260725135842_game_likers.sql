-- Kalp ikonunun yanındaki beğeni sayısına dokununca "kimler beğendi" listesi
-- gösterilebilsin diye: bir oyunu beğenen kullanıcıların (en yeni önce)
-- görünen adı + avatarını döner. profiles tablosunun SELECT RLS'i
-- (owner-or-admin) başkalarının adını doğrudan okumaya izin vermediğinden
-- security definer gerekiyor — leaderboard/Leaderboard.tsx'teki isimler de
-- aynı sebeple security_invoker=false bir view üzerinden geliyor. Soyad
-- (last_name) burada hiç döndürülmüyor — uygulamanın her yerindeki "soyad
-- asla gösterilmez" kuralıyla tutarlı (bkz. Leaderboard/PlayerScoreCard).
create or replace function public.game_likers(p_game_id uuid)
returns table(user_id uuid, display_name text, first_name text, avatar_url text)
language sql
security definer
stable
set search_path to 'public'
as $$
  select p.id, p.display_name, p.first_name, p.avatar_url
  from public.game_likes gl
  join public.profiles p on p.id = gl.user_id
  where gl.game_id = p_game_id
  order by gl.created_at desc;
$$;

revoke all on function public.game_likers(uuid) from public, anon;
grant execute on function public.game_likers(uuid) to authenticated;
