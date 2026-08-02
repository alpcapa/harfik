create or replace function public.admin_set_user_banned(p_user_id uuid, p_banned boolean)
returns void
language plpgsql
security definer
set search_path = public, auth
as $function$
begin
  if not public.is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Kendi hesabınızı devre dışı bırakamazsınız.';
  end if;

  update auth.users
  set banned_until = case when p_banned then now() + interval '100 years' else null end
  where id = p_user_id;

  insert into public.admin_ban_log (target_user_id, actor_user_id, banned)
  values (p_user_id, auth.uid(), p_banned);
end;
$function$;
