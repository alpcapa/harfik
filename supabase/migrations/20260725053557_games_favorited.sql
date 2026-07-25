-- Oyun geçmişinde bir oyunu favoriye eklemek için games.favorited sütunu.
-- Genel bir UPDATE politikası açmak istemiyoruz (games satırları bilerek
-- tarihi/değişmez kayıtlar — leaderboard/player_stats bunlara güveniyor;
-- genel UPDATE erişimi kullanıcının kendi skorunu/oyuncu listesini
-- değiştirmesine kapı aralardı). Bunun yerine yalnızca favorited alanını
-- değiştiren, sahiplik kontrollü dar bir RPC eklenir (diğer admin_* / RPC'lerle
-- aynı security definer deseni).

alter table public.games
  add column if not exists favorited boolean not null default false;

create or replace function public.toggle_game_favorite(p_game_id uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_owner uuid;
  v_new boolean;
begin
  select user_id into v_owner from public.games where id = p_game_id;
  if v_owner is null or v_owner <> auth.uid() then
    raise exception 'Yetkisiz erişim.';
  end if;

  update public.games set favorited = not favorited where id = p_game_id
  returning favorited into v_new;

  return v_new;
end;
$$;

revoke all on function public.toggle_game_favorite(uuid) from public;
grant execute on function public.toggle_game_favorite(uuid) to authenticated;
