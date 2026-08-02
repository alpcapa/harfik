-- 36 RLS policy'sinde `auth.uid()` her satır için yeniden değerlendiriliyordu
-- (Supabase advisor: auth_rls_initplan). `(select auth.uid())` sarmalaması
-- Postgres'in bunu bir InitPlan olarak bir kez hesaplayıp önbelleğe almasını
-- sağlıyor — davranış birebir aynı kalıyor, yalnızca büyük tablolarda sorgu
-- performansı iyileşiyor. Semantik değişiklik yok; yalnızca ifade sarmalama.

alter policy profiles_insert_self on public.profiles
  with check ((select auth.uid()) = id);

alter policy profiles_update_self on public.profiles
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

alter policy profiles_select_own_or_admin on public.profiles
  using (((select auth.uid()) = id) or is_admin());

alter policy games_insert_self on public.games
  with check ((select auth.uid()) = user_id);

alter policy games_select_authenticated on public.games
  using ((select auth.uid()) is not null);

alter policy game_finishes_insert_self on public.game_finishes
  with check ((select auth.uid()) = user_id);

alter policy game_likes_select_authenticated on public.game_likes
  using ((select auth.uid()) is not null);

alter policy game_likes_insert_self on public.game_likes
  with check ((select auth.uid()) = user_id);

alter policy game_likes_delete_self on public.game_likes
  using ((select auth.uid()) = user_id);

alter policy feedback_insert_any on public.feedback
  with check ((user_id is null) or ((select auth.uid()) = user_id) or is_admin());

alter policy friend_requests_select_own on public.friend_requests
  using (((select auth.uid()) = user_id) or ((select auth.uid()) = friend_id));

alter policy friend_requests_insert_self on public.friend_requests
  with check ((select auth.uid()) = user_id);

alter policy friend_requests_update_addressee on public.friend_requests
  using (((select auth.uid()) = friend_id) and (status = 'pending'::text))
  with check (((select auth.uid()) = friend_id) and (status = 'accepted'::text));

alter policy friend_requests_delete_either on public.friend_requests
  using (((select auth.uid()) = user_id) or ((select auth.uid()) = friend_id));

alter policy friend_invite_links_select_own on public.friend_invite_links
  using ((select auth.uid()) = inviter_id);

alter policy online_games_select_party on public.online_games
  using (
    ((select auth.uid()) = created_by)
    or (exists (
      select 1 from game_invites gi
      where gi.online_game_id = online_games.id and gi.invitee_id = (select auth.uid())
    ))
  );

alter policy online_games_insert_self on public.online_games
  with check ((select auth.uid()) = created_by);

alter policy online_games_update_creator on public.online_games
  using ((select auth.uid()) = created_by);

alter policy online_games_delete_creator on public.online_games
  using ((select auth.uid()) = created_by);

alter policy game_invites_insert_creator on public.game_invites
  with check (
    exists (
      select 1 from online_games og
      where og.id = game_invites.online_game_id and og.created_by = (select auth.uid())
    )
  );

alter policy game_invites_update_invitee on public.game_invites
  using (((select auth.uid()) = invitee_id) and (status = 'pending'::text))
  with check (((select auth.uid()) = invitee_id) and (status = any (array['accepted'::text, 'declined'::text])));

alter policy game_invites_delete_creator on public.game_invites
  using (
    (status = 'pending'::text)
    and (exists (
      select 1 from online_games og
      where og.id = game_invites.online_game_id and og.created_by = (select auth.uid())
    ))
  );

alter policy game_invites_select_party on public.game_invites
  using (
    ((select auth.uid()) = invitee_id)
    or is_online_game_creator(online_game_id, (select auth.uid()))
  );

alter policy online_game_states_select_party on public.online_game_states
  using (is_online_game_participant(online_game_id, (select auth.uid())));

alter policy online_game_moves_select_party on public.online_game_moves
  using (is_online_game_participant(online_game_id, (select auth.uid())));

alter policy local_game_saves_select_own on public.local_game_saves
  using ((select auth.uid()) = user_id);

alter policy local_game_saves_insert_own on public.local_game_saves
  with check ((select auth.uid()) = user_id);

alter policy local_game_saves_update_own on public.local_game_saves
  using ((select auth.uid()) = user_id);

alter policy local_game_saves_delete_own on public.local_game_saves
  using ((select auth.uid()) = user_id);

alter policy online_game_messages_select_party on public.online_game_messages
  using (is_online_game_participant(online_game_id, (select auth.uid())));

alter policy online_game_messages_insert_self on public.online_game_messages
  with check (
    (sender_user_id = (select auth.uid()))
    and is_online_game_participant(online_game_id, (select auth.uid()))
  );

alter policy online_game_message_mutes_select_own on public.online_game_message_mutes
  using (muter_user_id = (select auth.uid()));

alter policy online_game_message_mutes_insert_own on public.online_game_message_mutes
  with check (
    (muter_user_id = (select auth.uid()))
    and is_online_game_participant(online_game_id, (select auth.uid()))
    and is_online_game_participant(online_game_id, muted_user_id)
  );

alter policy online_game_message_mutes_delete_own on public.online_game_message_mutes
  using (muter_user_id = (select auth.uid()));

alter policy online_game_chat_reports_select_own on public.online_game_chat_reports
  using (reporter_user_id = (select auth.uid()));

alter policy online_game_chat_reports_insert_own on public.online_game_chat_reports
  with check (
    (reporter_user_id = (select auth.uid()))
    and is_online_game_participant(online_game_id, (select auth.uid()))
    and is_online_game_participant(online_game_id, reported_user_id)
  );
