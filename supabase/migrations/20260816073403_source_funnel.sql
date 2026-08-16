-- Kelimeki — Büyüme > Kullanıcı: "Ziyaretçi Kaynağı" tablosu funnel'a döndü
-- (kaynak > kişi > üye > oyun)
--
-- Kullanıcı isteği (16 Ağustos 2026): *"Admin ziyaretçi kaynağı tablosunu
-- funnel şeklinde yapabilir miyiz? Şöyle kaynak (web, arkadaş, linked-in,
-- instagram, etc.) > kişi (kaç kişi gelmiş) > üye (kaç kişi üye olmuş) >
-- oyun (kaç oyun oynanmış) yukarıdaki zaman filtrelerine göre çalışabilir."*
--
-- FUNNEL'IN SON İKİ ADIMI BUGÜNE KADAR HESAPLANAMIYORDU ve bu, şemanın
-- bilinçli bir kararıydı: `guest_visits` tamamen anonim (`anon_id` yalnızca
-- localStorage'da üretilen bir uuid) ve bir ziyaretçiyi SONRADAN açtığı
-- hesaba bağlayacak hiçbir alan YOK — olsaydı `PrivacyModal`'daki
-- "hiçbir kişisel veri içermez" taahhüdünü bozardı. Ölçüldü (bu migration
-- yazılırken): 266 benzersiz ziyaretçi, 23 üye, aralarında SIFIR bağ.
--
-- ÇÖZÜM ziyaret satırlarını hesaba BAĞLAMAK DEĞİL (o taahhüt aynen duruyor):
-- kayıt anında PROFİLİN KENDİSİNE ilk-temas kaynağı damgalanıyor
-- (`profiles.signup_utm_source`) — gender/birth_date/marketing_consent ile
-- BİREBİR aynı yol: istemci `sharedxp_pending_profile`e yazar,
-- `handle_new_user` trigger'ı okur (böylece e-posta doğrulaması AÇIKKEN de
-- çalışır — `agreed_to_terms`in yıllardır taşıdığı eksikliği tekrarlamaz).
-- Funnel iki AYRI dimension'ı yan yana koyuyor; `guest_visits` ile `profiles`
-- arasında JOIN YOK.
--
-- GERİYE DÖNÜK DOLDURULAMAZ (`games.platform` ile birebir aynı gerekçe):
-- mevcut 23 üyenin hangi kanaldan geldiği hiçbir yerde yazılı değil,
-- `signup_utm_source` onlarda null kalır ve funnel'da "Bilinmiyor" satırında
-- toplanır. Bu yüzden kolon, pazarlama linkleri yayınlanmadan ÖNCE ekleniyor.
--
-- NULL ≠ 'direkt' (bilinçli ayrım): web artık `?ref=` YOKSA bile AÇIKÇA
-- 'direkt' damgalıyor, yani null yalnızca "bu istemci damgalamadı" demek —
-- bu özellikten önceki üyeler ve (bugün) Flutter portundan gelen kayıtlar.
-- Böylece uygulama kayıtları "Direkt" satırını sessizce şişirmiyor.
--
-- ZAMAN PENCERESİ her adıma KENDİ olay tarihinden uygulanır (kohort DEĞİL):
-- kişi = penceredeki ziyaret, üye = penceredeki kayıt, oyun = penceredeki
-- biten oyun. Yani 60 gün önce üye olup bugün oynayan biri "oyun"a girer,
-- "üye"ye girmez — pazarlama sorusu "bu dönemde ne oldu", "bu dönemde gelen
-- kohort ne yaptı" değil.

alter table public.profiles add column if not exists signup_utm_source text;

comment on column public.profiles.signup_utm_source is
  'Kayıt anında damgalanan ilk-temas ?ref= etiketi (Büyüme > Kullanıcı funnel''ı). null = damgalanmamış (bu özellikten önceki üye ya da web dışı istemci), ''direkt'' = web''den ref''siz geliş.';

-- Yalnızca kayıt anında (handle_new_user) yazılır; sonraki UPDATE'ler alanı
-- DEĞİŞTİREMEZ. `profiles`in UPDATE grant'i tablo düzeyinde `authenticated`'e
-- açık olduğundan bu olmadan kullanıcı kendi kaynağını değiştirebilir, ya da
-- ileride tüm profili yayan bir `updateProfile` yaması onu sessizce silebilirdi
-- (`marketing_consent_at`i koruyan trg_set_marketing_consent_at ile aynı gerekçe).
create or replace function public.keep_signup_utm_source()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  new.signup_utm_source := old.signup_utm_source;
  return new;
end;
$function$;

drop trigger if exists trg_keep_signup_utm_source on public.profiles;
create trigger trg_keep_signup_utm_source
  before update on public.profiles
  for each row execute function public.keep_signup_utm_source();

-- handle_new_user: yalnızca `_utm` okuma/yazma satırları eklendi, geri kalanı
-- 20260729113942_marketing_consent'teki hâliyle AYNI.
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
  -- Serbest metin (`?ref=` etiketi kullanıcı kontrolünde) — 32 karakterle
  -- sınırlanıyor ki funnel tablosunu uydurma uzun bir satır bozmasın.
  _utm := nullif(left(trim(
    coalesce(new.raw_user_meta_data -> 'sharedxp_pending_profile' ->> 'utmSource', '')
  ), 32), '');

  insert into public.profiles (
    id, username, first_name, last_name, display_name, signup_channel,
    gender, birth_date, marketing_consent, marketing_consent_at,
    signup_utm_source
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
    case when _marketing then now() else null end,
    _utm
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;

-- Funnel: kaynak > kişi > üye > oyun. Kaynak kümesi ÜÇ adımın BİRLEŞİMİ —
-- bir kaynak yalnızca üye üretmiş (ziyaretçisi pencereye düşmemiş) olabilir.
create or replace function public.admin_source_funnel(p_days integer default 30)
returns table(source text, visitors bigint, signups bigint, games bigint)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_since timestamptz := now() - (greatest(p_days, 1) || ' days')::interval;
begin
  if not public.is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  with v as (
    select coalesce(gv.utm_source, 'direkt') as src,
           count(distinct gv.anon_id) as n
    from public.guest_visits gv
    where gv.created_at >= v_since
    group by 1
  ),
  s as (
    select coalesce(p.signup_utm_source, 'bilinmiyor') as src,
           count(*) as n
    from public.profiles p
    where p.created_at >= v_since
    group by 1
  ),
  g as (
    select coalesce(p.signup_utm_source, 'bilinmiyor') as src,
           count(*) as n
    from public.games gm
    join public.profiles p on p.id = gm.user_id
    where gm.created_at >= v_since
    group by 1
  ),
  k as (
    select src from v union select src from s union select src from g
  )
  select k.src,
         coalesce(v.n, 0),
         coalesce(s.n, 0),
         coalesce(g.n, 0)
  from k
  left join v on v.src = k.src
  left join s on s.src = k.src
  left join g on g.src = k.src
  order by coalesce(v.n, 0) desc, coalesce(s.n, 0) desc, k.src;
end;
$function$;

-- Supabase yeni fonksiyonlara varsayılan anon+authenticated EXECUTE veriyor —
-- önce temizlenip yalnızca istenen roller veriliyor (bkz.
-- 20260725053640_revoke_toggle_game_favorite_anon dersi).
revoke all on function public.admin_source_funnel(integer) from public, anon, authenticated;
grant execute on function public.admin_source_funnel(integer) to authenticated, service_role;
