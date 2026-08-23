-- Kelimeki — Kaynak Hunisi: "Oyun" → "Biten", artık misafiri de sayıyor
--
-- Dönüş tipi değiştiğinden `create or replace` YETMEZ: drop + create ve
-- grant'ler elle geri kuruluyor (bkz. 20260725053640 dersi ve 14 Ağustos'taki
-- `fix_withdraw_report_wrong_overload` vakası — imza değişince düzeltme ölü
-- bir overload'a gidebiliyor).
--
-- DEĞİŞEN ÖLÇÜ: `finishes` artık `game_finishes.utm_source`tan geliyor, yani
-- CİHAZ etiketli ve MİSAFİRİ DE sayıyor. Eski ölçü (yalnızca üyelerin bitirdiği
-- oyunlar, `games` ∪ `profiles.signup_utm_source`) SİLİNMEDİ — `member_games`
-- olarak duruyor ve CSV'de dışa aktarılıyor; bilgi kaybı yok.
--
-- Böylece `starts` (game_starts) ile `finishes` (game_finishes) AYNI kapsamı
-- (yerel/YZ oyunları), AYNI etiket sözleşmesini ve AYNI kitleyi (misafir dahil)
-- ölçüyor — yani "başlayan → biten" ilk kez gerçekten karşılaştırılabilir bir
-- çift. `signups`/`member_games`/`players` ise `profiles`ten gelir: AYRI bir
-- dimension, aralarında join YOK ve olamaz.
--
-- ⚠ Bitmiş tarafta "benzersiz cihaz" YOK: `game_finishes` bilerek `anon_id`
-- taşımıyor (gizlilik taahhüdü — bkz. kolon migration'ı), yani `starters`ın
-- karşılığı üretilemiyor. Bu yüzden yüzde modunda "Biten" sütununun tabanı
-- `starts` DEĞİL satırın `visitors`ı olmaya devam ediyor.

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
    -- NULL burada 'direkt' DEĞİL 'bilinmiyor': web `?ref=` yokken bile
    -- açıkça 'direkt' yazıyor, dolayısıyla null yalnızca damgalamayan bir
    -- istemciden (bugün mobil port) gelebilir.
    select coalesce(gs.utm_source, 'bilinmiyor') as src,
           count(*) as n,
           count(distinct gs.anon_id) as uniq
    from public.game_starts gs
    where gs.created_at >= v_since
    group by 1
  ),
  fi as (
    -- "Biten" — `starts` ile AYNI sözleşme ve AYNI kapsam (yerel/YZ), misafir
    -- dahil. Bu satırın var olma sebebi tam olarak misafiri görebilmek.
    select coalesce(gf.utm_source, 'bilinmiyor') as src,
           count(*) as n
    from public.game_finishes gf
    where gf.created_at >= v_since
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
    -- Eski ölçü: yalnızca ÜYELERİN bitirdiği oyunlar, üyenin KAYIT kaynağına
    -- göre. Tabloda gösterilmiyor, CSV'de duruyor.
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
