-- Kelimeki — telemetriye `app_version` (mağaza öncesi hazırlık, 23 Ağustos 2026)
--
-- GEREKÇE: web'de AYNI ANDA TEK bir canlı derleme var; mağazaya çıkıldığında
-- app'te aynı anda BEŞ sürüm olur ve hangi sürümde olduğunu söyleyen hiçbir
-- alan yok. İki somut sonucu var:
--
--   1. Hata triyajı körleşir. `client_errors.build` bir git sha'sı taşıyor —
--      panelde opak; "bu hata 0.2.0'da düzeldi mi?" sorusunu ancak sha↔sürüm
--      eşlemesini elle yaparak cevaplayabilirsin.
--   2. `app_config.mobile_min_supported_version` kolu VAR ama onu ne zaman
--      çekeceğini gösteren VERİ YOK. Eşiği erken yükseltmek güncel olmayan
--      kullanıcıları uygulamadan kilitler (`version_gate.dart`), geç
--      yükseltmek düzeltilmiş bir hatayı sahada yaşatmaya devam eder.
--
-- ⚠ GERİYE DÖNÜK DOLDURULAMAZ (`games.platform`/`game_starts` ile aynı sınıf)
-- — tam bu yüzden mağaza çıkışından ÖNCE ekleniyor.
--
-- ⚠ WEB'de bu alan NULL kalır ve bu bir eksiklik DEĞİL, anlamın kendisi:
-- web'in sürümü `build` (sha) ile zaten tekil olarak belirli. NULL = "sürümü
-- olmayan istemci", yani web. Uydurma bir değer ('web', '1.0') yazmak
-- dağılım tablosunu kirletirdi.
--
-- ⚠ platform/kind gibi burada da CHECK KISITI YOK: öngörülmemiş bir değer
-- yüzünden bir HATA RAPORUNU ya da bir oyun başlangıcını düşürmek, tam da
-- görmek istediğimiz şeyi kör eder (kolonun eklendiği iki tablonun kendi
-- migration'larındaki aynı gerekçe).
alter table public.client_errors add column if not exists app_version text;
alter table public.game_starts   add column if not exists app_version text;
-- `game_starts`ta `platform` da YOKTU (ölçüldü) — `app_version` tek başına
-- ios ile android'i ayıramaz (NULL sürüm zaten "web" demek, ama app'in iki
-- hedefi aynı satıra düşerdi). Değer kümesi `games.platform` kısıtıyla aynı
-- sözleşmeyi izler (`web`/`ios`/`android`/`app-web`) ama BURADA KISIT YOK:
-- orada geçersiz bir değer bir OYUN KAYDINI düşürür, burada yalnızca bir
-- sayaç satırını — ve düşen sayaç tam da görmek istediğimiz şeyi kör eder.
alter table public.game_starts   add column if not exists platform text;

comment on column public.game_starts.platform is
  'Oyunu başlatan istemci: web/ios/android/app-web. `games.platform` ile aynı sözleşme, kısıtsız.';
comment on column public.client_errors.app_version is
  'İstemcinin ürün sürümü (mobil: pubspec `version`). Web NULL bırakır — orada sürüm `build` sha ile tekil. Geriye dönük doldurulamaz.';
comment on column public.game_starts.app_version is
  'Oyunu başlatan istemcinin ürün sürümü. Sürüm dağılımını (min_supported_version kararını) besler; web NULL.';

-- Kolon grant'i GEREKMİYOR: iki tabloda da yetkiler TABLO düzeyinde
-- (`games`in aksine — orada kolon kolon veriliyor ve yeni her kolonun ayrıca
-- eklenmesi gerekiyor). Ölçüldü: information_schema.role_table_grants.

-- ── Hata paneli: gruplanmış satıra "sürümler" eklendi ──────────────────────
-- Dönüş tipi değiştiğinden `create or replace` YETMEZ (bu projede bir kez
-- ölü bir overload'a düzeltme yazıldı — `fix_withdraw_report_wrong_overload`);
-- drop + create ve grant'ler elle yeniden.
drop function if exists public.admin_client_errors (integer);

create function public.admin_client_errors (p_days integer default 7)
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

revoke all on function public.admin_client_errors (integer) from public, anon;
grant execute on function public.admin_client_errors (integer) to authenticated, service_role;

-- ── Sürüm dağılımı — "eşiği yükseltmek güvenli mi?" ────────────────────────
-- Kaynak `game_starts`: her YEREL oyun açılışında yazılıyor, MİSAFİR dahil,
-- yani girişten bağımsız en geniş kapsamlı istemci olayı.
--
-- ⚠ Bu tablo "kaç KULLANICI hangi sürümde" DEĞİL, "hangi sürümden kaç oyun
-- açıldı" der. Sebep ölçülmüş bir sınır: port `anon_id` GÖNDERMİYOR (web'in
-- `visitTracking.ts` damgasının portu henüz yok), dolayısıyla app satırlarında
-- cihaz sayılamaz. `devices` yine de dönülüyor — web tarafında dolu, app'te
-- 0 kalır; panel bu yüzden BAŞLANGIÇ sayısını gösteriyor. Port damgalamayı
-- eklerse burada değişiklik gerekmez, sayı kendiliğinden anlam kazanır.
--
-- ⚠ Kapsam yalnızca YEREL (YZ) oyunlar — `game_starts`ın kendi kapsamı. Yalnız
-- Canlı oynayan bir kullanıcı burada hiç görünmez.
create or replace function public.admin_app_version_breakdown (p_days integer default 30)
  returns table (
    platform    text,
    app_version text,
    starts      bigint,
    devices     bigint,
    last_seen   timestamptz
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
  select coalesce(gs.platform, 'bilinmiyor')    as platform,
         coalesce(gs.app_version, 'bilinmiyor') as app_version,
         count(*)                               as starts,
         count(distinct gs.anon_id)             as devices,
         max(gs.created_at)                     as last_seen
  from public.game_starts gs
  where gs.created_at >= v_since
  group by 1, 2
  order by count(*) desc, 1, 2;
end;
$$;

revoke all on function public.admin_app_version_breakdown (integer) from public, anon;
grant execute on function public.admin_app_version_breakdown (integer) to authenticated, service_role;
