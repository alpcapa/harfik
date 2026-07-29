-- Kelimeki — online_games/game_invites RLS'indeki karşılıklı referans zinciri
-- sonsuz özyinelemeye (Postgres 42P17) yol açıyordu:
--   online_games_select_party  → alt sorguyla game_invites'a bakıyor
--   game_invites_select_party  → alt sorguyla online_games'e bakıyor
-- Aynı transaction içinde online_games'i sorgulamak, RLS'in game_invites'ı
-- kontrol etmesine, o da tekrar online_games'i kontrol etmesine yol açıyor —
-- döngü.
--
-- Bu şimdiye kadar hiç tetiklenmemişti çünkü uygulamadaki TÜM diğer erişim
-- yolları (list_my_online_games, respond_to_game_invite, create_online_game,
-- submit_move, init_online_game_state, get_my_online_rack) SECURITY DEFINER
-- RPC'ler — bunlar tablo sahibi olarak çalıştığından RLS'i tamamen bypass
-- ediyor. play-ai-turn Edge Function'ı, online_games'i DOĞRUDAN (çağıranın
-- kendi JWT'siyle, RLS'e tabi) okuyan İLK kod yolu oldu ve döngüyü açığa
-- çıkardı — YZ'nin sırası hiç oynanmadan "Oyun bulunamadı." (404) ile
-- sessizce başarısız oluyordu (bkz. CLAUDE.md "Canlı Oyun — Faz 3").
--
-- Çözüm: game_invites_select_party'deki "ben bu oyunun kurucusuyum" alt
-- sorgusunu, is_online_game_participant ile aynı desende SECURITY DEFINER
-- bir yardımcı fonksiyona taşımak. Bu fonksiyon tablo sahibi olarak
-- çalıştığından online_games'in RLS'ini yeniden tetiklemiyor — döngü kırılıyor.
create function public.is_online_game_creator(p_game_id uuid, p_uid uuid)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select p_uid is not null and exists (
    select 1 from public.online_games og
    where og.id = p_game_id and og.created_by = p_uid
  );
$$;

drop policy game_invites_select_party on public.game_invites;

create policy game_invites_select_party on public.game_invites
  for select using (
    auth.uid() = invitee_id
    or public.is_online_game_creator(online_game_id, auth.uid())
  );
