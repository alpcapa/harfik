-- Kod incelemesi (Orta bulgular): 12 foreign key'de kapsayan index yoktu
-- (Supabase advisor: unindexed_foreign_keys) ve online_game_chat_reports
-- tablosunda SELECT için iki permissive policy çakışıyordu (gereksiz ekstra
-- değerlendirme). Davranış değişikliği yok — yalnızca performans.

create index if not exists admin_ban_log_actor_user_id_idx on public.admin_ban_log (actor_user_id);
create index if not exists feedback_replied_by_idx on public.feedback (replied_by);
create index if not exists feedback_user_id_idx on public.feedback (user_id);
create index if not exists game_finishes_user_id_idx on public.game_finishes (user_id);
create index if not exists online_game_chat_reports_online_game_id_idx on public.online_game_chat_reports (online_game_id);
create index if not exists online_game_chat_reports_reported_user_id_idx on public.online_game_chat_reports (reported_user_id);
create index if not exists online_game_chat_reports_reporter_user_id_idx on public.online_game_chat_reports (reporter_user_id);
create index if not exists online_game_message_mutes_muted_user_id_idx on public.online_game_message_mutes (muted_user_id);
create index if not exists online_game_message_mutes_muter_user_id_idx on public.online_game_message_mutes (muter_user_id);
create index if not exists online_game_messages_sender_user_id_idx on public.online_game_messages (sender_user_id);
create index if not exists online_game_moves_player_user_id_idx on public.online_game_moves (player_user_id);
create index if not exists profiles_invited_by_idx on public.profiles (invited_by);

-- online_game_chat_reports_select_admin + online_game_chat_reports_select_own
-- her SELECT'te ikisi de ayrı ayrı değerlendiriliyordu (ikisi de permissive,
-- OR mantığıyla birleşiyorlardı zaten) — tek policy'de birleştirildi.
drop policy if exists online_game_chat_reports_select_admin on public.online_game_chat_reports;
drop policy if exists online_game_chat_reports_select_own on public.online_game_chat_reports;

create policy online_game_chat_reports_select_admin_or_own on public.online_game_chat_reports
  for select
  using (is_admin() or reporter_user_id = (select auth.uid()));
