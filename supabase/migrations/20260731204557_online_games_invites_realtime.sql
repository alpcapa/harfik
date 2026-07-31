-- LiveGamesTab/Setup rozeti canlı değil: bir davet gönderildiğinde alıcının
-- "Arkadaşınla" sekmesi açık kalsa bile hiçbir olay tetiklenmiyordu (yalnızca
-- mount/[user] effect'i baştan bir kez çekiyordu) — davet ancak sekme
-- değiştirilip geri dönülünce (yeniden mount) ya da uygulama aç/kapa edilince
-- görünüyordu. Aynı sebeple bir davet kabul edilince Setup'taki "Arkadaşınla
-- (N)" rozeti de yalnızca mainView değişince (Local'e dönülünce) tazeleniyordu.
--
-- online_game_states/online_game_messages'da olduğu gibi, bu iki tabloyu da
-- supabase_realtime publication'ına ekliyoruz — src/lib/api.ts'teki
-- subscribeOnlineGameState/subscribeOnlineGameMessages'ın aynı deseniyle
-- LiveGamesTab ve Setup artık game_invites/online_games değişikliklerini
-- anında dinleyebilecek. Realtime, RLS'i (online_games_select_party/
-- game_invites_select_party) normal select gibi uyguladığından yayın
-- filtresiz olsa da her istemci yalnızca kendi tarafı olduğu satırları görür.
alter publication supabase_realtime add table public.online_games;
alter publication supabase_realtime add table public.game_invites;
