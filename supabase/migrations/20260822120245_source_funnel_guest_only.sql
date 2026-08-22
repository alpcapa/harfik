-- Kelimeki — Kaynak Hunisi artık BAŞTAN SONA misafir hunisi
--
-- "Gelen" baştan beri misafir-only idi (bkz. is_guest migration'ı); bu
-- değişiklikle "Başlayan" ve "Biten" de aynı kitleye iniyor, yani tablo ilk kez
-- TEK bir popülasyonu ölçüyor: *bu kanaldan gelip HENÜZ ÜYE OLMADAN ürünü
-- deneyen insanlar*. Kullanıcı isteği (22 Ağustos 2026).
--
-- Dönüş tipi DEĞİŞMİYOR (aynı 8 kolon, aynı sıra) — yalnızca üç sayacın
-- FİLTRESİ değişiyor. Yine de drop+create kullanılıyor: bu kod tabanında
-- `create or replace`in sessizce ikinci bir overload yarattığı gerçek bir vaka
-- var (`fix_withdraw_report_wrong_overload`, 14 Ağustos 2026) ve grant'ler
-- zaten elle geri kuruluyor.
--
-- ÖNCEKİ MIGRATION'IN BAŞLIĞINDA BİR HATA VARDI (20260822043116): "Biten
-- sütununun tabanı starts DEĞİL visitors olmaya devam ediyor" diyordu, oysa
-- istemci o gün tabanı `starts` olarak uyguladı (tamamlanma oranı) — doğrusu
-- odur. Uygulanmış bir migration dosyası geriye dönük düzeltilmediğinden kayıt
-- burada.
--
-- DEĞİŞENLER
--   starts/starters : `game_starts` → yalnızca `is_guest is true`
--   finishes        : `game_finishes` → yalnızca `user_id is null`
--
-- DEĞİŞMEYENLER (bilinçli)
--   visitors        : `guest_visits` zaten yalnızca oturum kapalıyken yazılıyor
--   signups         : hesap açılışı — huninin dönüşüm adımı, misafir/üye
--                     ayrımı burada anlamsız
--   member_games /  : ÜYELERİN oyunları, üyenin KAYIT damgasına göre. AYRI bir
--   players           dimension ve BİLEREK korunuyor: hesabı takip ettiğinden
--                     ("bu kanal değerli üye getirdi mi") cihaz etiketinden
--                     daha güvenilir — bir üye başka bir cihazdan oynarsa cihaz
--                     etiketi 'bilinmiyor'a düşer, kayıt damgası düşmez.
--                     Tabloda gösterilmiyor, CSV'de duruyor.
--
-- ⚠ `is_guest is true` yazılıyor, `is not false` DEĞİL: NULL "bilinmiyor"dur
-- (22 Ağustos öncesi satırlar + damgalamayan istemci) ve bilinmeyeni misafir
-- saymak ölçümü şişirirdi. Aynı sebeple `starters` da yalnız misafir cihazları
-- sayıyor — aksi halde oran (`başlatan cihaz / gelen`) payı ile paydası farklı
-- kitlelerden gelirdi.

drop function if exists public.admin_source_funnel (integer);

create function public.admin_source_funnel (p_days integer default 30)
  returns table (
    source        text,
    visitors      bigint,
    starts        bigint,
    starters      bigint,
    signups       bigint,
    finishes      bigint,
    member_games  bigint,
    players       bigint
  )
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
  st as (
    -- NULL burada 'direkt' DEĞİL 'bilinmiyor': web `?ref=` yokken bile açıkça
    -- 'direkt' yazıyor, dolayısıyla null yalnızca damgalamayan bir istemciden
    -- (bugün mobil port) gelebilir.
    select coalesce(gs.utm_source, 'bilinmiyor') as src,
           count(*) as n,
           count(distinct gs.anon_id) as uniq
    from public.game_starts gs
    where gs.created_at >= v_since
      and gs.is_guest is true
    group by 1
  ),
  fi as (
    -- "Biten" — `starts` ile AYNI kapsam (yerel/YZ), AYNI etiket sözleşmesi ve
    -- artık AYNI kitle (üye olmadan oynayanlar).
    select coalesce(gf.utm_source, 'bilinmiyor') as src,
           count(*) as n
    from public.game_finishes gf
    where gf.created_at >= v_since
      and gf.user_id is null
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
           count(*) as n,
           count(distinct gm.user_id) as pl
    from public.games gm
    join public.profiles p on p.id = gm.user_id
    where gm.created_at >= v_since
    group by 1
  ),
  k as (
    select src from v
    union select src from st
    union select src from fi
    union select src from s
    union select src from g
  )
  select k.src,
         coalesce(v.n, 0),
         coalesce(st.n, 0),
         coalesce(st.uniq, 0),
         coalesce(s.n, 0),
         coalesce(fi.n, 0),
         coalesce(g.n, 0),
         coalesce(g.pl, 0)
  from k
  left join v on v.src = k.src
  left join st on st.src = k.src
  left join fi on fi.src = k.src
  left join s on s.src = k.src
  left join g on g.src = k.src
  order by coalesce(v.n, 0) desc, coalesce(st.n, 0) desc, coalesce(s.n, 0) desc, k.src;
end;
$function$;

revoke all on function public.admin_source_funnel (integer) from public, anon;
grant execute on function public.admin_source_funnel (integer) to authenticated, service_role;
