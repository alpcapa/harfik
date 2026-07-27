-- Kayıt formuna Cinsiyet ve Doğum Tarihi de eklendi (öncesinde yalnızca
-- Hesap Ayarları'ndan girilebiliyordu). handle_new_user trigger'ı artık
-- sharedxp_pending_profile'daki gender/birthDate'i de okuyup profiles
-- satırını daha ilk oluşturulduğu anda dolduruyor — bu, e-posta doğrulaması
-- açıkken (signUp() session döndürmediğinde) bile çalışır, çünkü trigger
-- auth.users insert'inde (onay beklenmeden) tetiklenir; ayrı bir "oturum
-- açılınca profili güncelle" adımına ihtiyaç yok (first_name/last_name/
-- display_name zaten aynı yöntemle çalışıyordu).

create or replace function public.handle_new_user ()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
  as $$
declare
  _first   text;
  _last    text;
  _display text;
  _channel text;
  _gender  text;
  _birth   date;
begin
  _first := coalesce(
    new.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'firstName',
    ''
  );
  _last := coalesce(
    new.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'lastName',
    ''
  );
  _display := coalesce(
    new.raw_user_meta_data ->> 'display_name',
    nullif(trim(_first || ' ' || _last), ''),
    split_part(new.email, '@', 1)
  );
  _channel := new.raw_user_meta_data ->> 'signup_channel';
  if _channel is null or _channel not in ('direct', 'form') then
    _channel := 'direct';
  end if;
  _gender := nullif(new.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'gender', '');
  if _gender not in ('female', 'male', 'unspecified') then
    _gender := null;
  end if;
  begin
    _birth := nullif(new.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'birthDate', '')::date;
  exception when others then
    _birth := null;
  end;

  insert into public.profiles (id, username, first_name, last_name, display_name, signup_channel, gender, birth_date)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    _first,
    _last,
    _display,
    _channel,
    _gender,
    _birth
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
