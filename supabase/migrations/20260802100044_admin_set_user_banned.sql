-- Kelimeki — Admin paneli: bir kullanıcı hesabını devre dışı bırakma/aktif
-- etme. Şikayet (bkz. online_game_chat_reports) geri çekilmiş olsa bile
-- admin raporlanan kişi hakkında aksiyon alabilmeli — kullanıcı isteği.
-- Supabase Auth (GoTrue), auth.users.banned_until dolu ve gelecekte bir
-- tarihse yeni girişe/refresh'e izin vermiyor; zaten var olan kısa ömürlü
-- access token'lar süresi dolana kadar geçerli kalabilir (oturum anında
-- kesme kapsam dışı — GoTrue'nun standart ban davranışı bu).
create or replace function public.admin_set_user_banned(p_user_id uuid, p_banned boolean)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
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
end;
$$;

revoke all on function public.admin_set_user_banned(uuid, boolean) from public, anon;
grant execute on function public.admin_set_user_banned(uuid, boolean) to authenticated;
