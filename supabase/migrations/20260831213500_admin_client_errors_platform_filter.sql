-- Kelimeki — hata panelinde PLATFORM filtresi (ROADMAP #11).
--
-- NEDEN ŞİMDİ: madde "app çıkınca" diye işaretliydi ve tetikleyicisi geldi —
-- panelde ios/android satırları web'le karışmaya başlıyor. Bugüne kadar tek
-- platform (web) olduğu için filtre gereksizdi.
--
-- ⚠ NEDEN SUNUCUDA, İSTEMCİDE DEĞİL. ROADMAP iki seçenek bırakmıştı
-- ("RPC'ye opsiyonel bir p_platform ya da panelde istemci tarafı filtre —
-- satır sayısı düşükken o da yeterli"). İstemci tarafı filtre bu fonksiyonun
-- ŞEKLİ yüzünden YANLIŞ sayı gösterir: satırlar (kind, message) ile
-- gruplanıyor ve `platforms` bir `string_agg`. Yani web'de de android'de de
-- görülen bir hata TEK satır ve `occurrences`/`devices` İKİSİNİN TOPLAMI.
-- İstemcide "platforms 'android' içeriyor mu" diye elemek o satırı gösterir
-- ama sayıları web'i de içerdiği hâlde bırakır — panelin bütün değeri o iki
-- sayı olduğundan bu sessiz bir yanlış olurdu. Sunucuda filtrelemek elemeyi
-- GRUPLAMADAN ÖNCE yapıyor, yani sayılar seçilen platforma ait.
--
-- ⚠ PARAMETRE EKLEMEK `create or replace` İLE OLMAZ: eski `(integer)` imzası
-- yerinde kalır, yeni imza `(integer, text)` olur ve tek argümanlı çağrı
-- İKİSİNE de uyup "function is not unique" (42725) verir. Bu proje o tuzağı
-- bir kez yaşadı (`fix_withdraw_report_wrong_overload`). Bu yüzden önce drop,
-- sonra create, sonra grant'ler ELLE yeniden.
--
-- KAPSAM SINIRI (bilinçli): `p_platform` yalnızca EŞİTLİK eliyor, yani
-- platformu NULL olan satırlar (yayınlanmayan masaüstü hedefleri) bir platform
-- seçiliyken görünmez. Onlar "Tümü" görünümünde `?` olarak duruyor — filtre
-- bir kolaylık, tek görüntüleme yolu değil. Değer kümesine burada da KISIT
-- KONMUYOR: `client_errors` tablosunun kendi gerekçesi geçerli — öngörülmemiş
-- bir değer yüzünden bir HATA RAPORUNU kör etmek, tam da görmek istediğimiz
-- şeyi kaybettirir.
drop function if exists public.admin_client_errors (integer);

create function public.admin_client_errors (
  p_days integer default 7,
  p_platform text default null
)
  returns table (
    kind        text,
    message     text,
    occurrences bigint,
    devices     bigint,
    platforms   text,
    builds      text,
    versions    text,
    routes      text,
    first_seen  timestamptz,
    last_seen   timestamptz,
    sample_stack text
  )
  language plpgsql
  stable
  security definer
  set search_path = public, auth
  as $$
declare
  v_since timestamptz := now() - (greatest(p_days, 1) || ' days')::interval;
begin
  if not public.is_admin () then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  with g as (
    select ce.kind as k,
           left(ce.message, 160) as sig,
           ce.anon_id, ce.platform, ce.build, ce.app_version, ce.route, ce.stack, ce.created_at
    from public.client_errors ce
    where ce.created_at >= v_since
      -- Eleme GRUPLAMADAN ÖNCE — yukarıdaki gerekçe.
      and (p_platform is null or ce.platform = p_platform)
  )
  select g.k,
         g.sig,
         count(*)                                   as occurrences,
         count(distinct g.anon_id)                  as devices,
         string_agg(distinct coalesce(g.platform, '?'), ', ' order by coalesce(g.platform, '?')) as platforms,
         string_agg(distinct coalesce(g.build, '?'), ', ' order by coalesce(g.build, '?'))       as builds,
         -- Sürümü OLMAYAN istemciler (web) burada hiç görünmesin: `filter`
         -- ile atılıyor, '?' ile doldurulMUYOR. Yalnız web'den gelen bir
         -- grupta sütun NULL kalır ve panel onu hiç çizmez — "sürüm yok"
         -- bilgisi zaten `platforms`ta yazılı.
         string_agg(distinct g.app_version, ', ' order by g.app_version)
           filter (where g.app_version is not null)                                              as versions,
         string_agg(distinct coalesce(g.route, '?'), ', ' order by coalesce(g.route, '?'))       as routes,
         min(g.created_at)                          as first_seen,
         max(g.created_at)                          as last_seen,
         (array_agg(g.stack order by g.created_at desc) filter (where g.stack is not null))[1]   as sample_stack
  from g
  group by g.k, g.sig
  order by count(*) desc, max(g.created_at) desc;
end;
$$;

revoke all on function public.admin_client_errors (integer, text) from public, anon;
grant execute on function public.admin_client_errors (integer, text) to authenticated, service_role;
