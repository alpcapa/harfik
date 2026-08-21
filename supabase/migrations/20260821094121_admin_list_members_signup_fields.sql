-- Admin > Üyeler: kayıt sırasında doldurulan TÜM alanlar (izinler dahil).
--
-- Üç parça:
--
-- 1. `handle_new_user` `agreedToTerms`i HİÇ OKUMUYORDU. İki istemci de
--    (web `signUp`, portun `signUp`u) bu alanı `sharedxp_pending_profile`
--    metadata'sında BAŞTAN BERİ gönderiyor; trigger gender/birthDate/
--    marketingConsent/utmSource'u okurken bunu atlamış. `profiles`e ancak
--    signUp() ANINDA oturum açıldıysa (e-posta doğrulaması KAPALIYKEN)
--    çalışan istemci-taraflı bir update yazıyordu — doğrulama açık olduğu
--    için o dal hiç koşmadı. Sonuç ÖLÇÜLDÜ: 26 üyenin 26'sında
--    `agreed_to_terms = false`, yani kolon yapısal olarak hep yalan
--    söylüyordu. Bu eksiklik `marketing_consent` eklenirken zaten yazılıydı
--    (kök CLAUDE.md, "ÖNCEDEN VAR OLAN bir eksiklik") — kolon panele
--    konacağı için artık düzeltiliyor.
--
-- 2. Geriye dönük doldurma VARSAYIMLA DEĞİL, gerçek kayıttan:
--    `auth.users.raw_user_meta_data`da onay hâlâ duruyor (26 hesabın
--    25'inde `agreedToTerms: true`, hiçbirinde `false`). Sadece `profiles`e
--    kopyalanmamış. Metadata'sı olmayan tek hesap (sistemin ilk üyesi)
--    DOKUNULMADAN `false` kalıyor — orada bilinen bir şey yok, uydurmuyoruz.
--
-- 3. `admin_list_members` kayıt formunun tüm alanlarını + izinleri döndürüyor.
--    Dönüş kolonları değiştiğinden `create or replace` YETMEZ (Postgres
--    kuralı) — drop + create + grant'ler elle yeniden kuruluyor.

-- ── 1. Trigger artık onayı da yazıyor ────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  _first     text;
  _last      text;
  _display   text;
  _channel   text;
  _gender    text;
  _birth     date;
  _marketing boolean;
  _terms     boolean;
  _utm       text;
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
  -- Kullanım Koşulları onayı — iki istemci de gönderiyor, trigger bugüne
  -- kadar okumuyordu. Bozuk/eksik bir değerde `false`a düşer: onayı
  -- OLMADIĞI hâlde var göstermek, tersinden daha kötü.
  begin
    _terms := coalesce(
      (new.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'agreedToTerms')::boolean,
      false
    );
  exception when others then
    _terms := false;
  end;
  -- Serbest metin (`?ref=` etiketi kullanıcı kontrolünde) — 32 karakterle
  -- sınırlanıyor ki funnel tablosunu uydurma uzun bir satır bozmasın.
  _utm := nullif(left(trim(
    coalesce(new.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'utmSource', '')
  ), 32), '');

  insert into public.profiles (
    id, username, first_name, last_name, display_name, signup_channel,
    gender, birth_date, agreed_to_terms, marketing_consent,
    marketing_consent_at, signup_utm_source
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
    _terms,
    _marketing,
    case when _marketing then now() else null end,
    _utm
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;

-- ── 2. Geriye dönük: onayı auth metadata'sından kurtar ───────────────────
update public.profiles p
set agreed_to_terms = true
from auth.users u
where u.id = p.id
  and p.agreed_to_terms = false
  and (u.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'agreedToTerms')::boolean is true;

-- ── 3. Üyeler tablosu: kayıt alanları + izinler ─────────────────────────
drop function if exists public.admin_list_members();

create function public.admin_list_members()
returns table(
  id uuid,
  email text,
  username text,
  first_name text,
  last_name text,
  display_name text,
  gender text,
  birth_date date,
  avatar_url text,
  agreed_to_terms boolean,
  marketing_consent boolean,
  marketing_consent_at timestamptz,
  email_notifications_enabled boolean,
  is_admin boolean,
  signup_channel text,
  signup_utm_source text,
  invited_by_name text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  banned_until timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
begin
  if not public.is_admin () then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    u.id,
    u.email::text,
    p.username,
    p.first_name,
    p.last_name,
    p.display_name,
    p.gender,
    p.birth_date,
    p.avatar_url,
    coalesce(p.agreed_to_terms, false),
    coalesce(p.marketing_consent, false),
    p.marketing_consent_at,
    coalesce(p.email_notifications_enabled, true),
    coalesce(p.is_admin, false),
    coalesce(p.signup_channel, 'direct'),
    p.signup_utm_source,
    -- Daveti gönderen üyenin görünen adı. Herkese açık kısa kimlik kuralı
    -- (nickname → ad) burada BİLEREK kullanılmıyor: bu satır yalnızca
    -- admin'e dönüyor ve "kim davet etti" sorusunun cevabı olarak tam ad
    -- daha kullanışlı.
    nullif(trim(coalesce(pi.display_name, trim(coalesce(pi.first_name, '') || ' ' || coalesce(pi.last_name, '')))), '') as invited_by_name,
    u.created_at,
    u.last_sign_in_at,
    u.banned_until
  from auth.users u
  left join public.profiles p on p.id = u.id
  left join public.profiles pi on pi.id = p.invited_by
  order by u.created_at desc;
end;
$function$;

revoke all on function public.admin_list_members() from public, anon;
grant execute on function public.admin_list_members() to authenticated, service_role;
