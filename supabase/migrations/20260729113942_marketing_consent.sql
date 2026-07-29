-- Kayıt formuna ikinci, OPSİYONEL bir onay kutusu ekleniyor: "Pazarlama
-- iletişimi almayı kabul ediyorum". `agreed_to_terms`'ün aksine (yalnızca
-- düz bir boolean, ne zaman kabul edildiği hiç tutulmuyor) bu alan baştan
-- bir zaman damgasıyla birlikte tasarlandı — kullanıcı isteği.
alter table public.profiles
  add column if not exists marketing_consent boolean not null default false,
  add column if not exists marketing_consent_at timestamptz;

comment on column public.profiles.marketing_consent is 'Pazarlama iletişimi almayı kabul etti mi — kayıt formundaki opsiyonel (zorunlu olmayan) ikinci onay kutusu.';
comment on column public.profiles.marketing_consent_at is 'marketing_consent true olduğu andaki sunucu zaman damgası (kayıt anı) — false ise/hiç işaretlenmediyse null.';

-- handle_new_user: gender/birth_date ile aynı sebepten (e-posta doğrulaması
-- açıkken signUp() hemen oturum açmadığından, sonradan bir update'e
-- güvenilemez) marketing_consent de doğrudan burada, sharedxp_pending_profile
-- metadata'sından okunuyor.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  _first     text;
  _last      text;
  _display   text;
  _channel   text;
  _gender    text;
  _birth     date;
  _marketing boolean;
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
  _marketing := coalesce(
    (new.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'marketingConsent')::boolean,
    false
  );

  insert into public.profiles (
    id, username, first_name, last_name, display_name, signup_channel,
    gender, birth_date, marketing_consent, marketing_consent_at
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    _first,
    _last,
    _display,
    _channel,
    _gender,
    _birth,
    _marketing,
    case when _marketing then now() else null end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
