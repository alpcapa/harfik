-- Kelimeki — istemci hata telemetrisi (`client_errors`), ROADMAP #3
--
-- GEREKÇE: bugün istemcideki her çökme KULLANICININ CİHAZINDA ölüyor —
-- web'de ~81 `console.error`, portta ~74 `debugPrint`, artı `ErrorBoundary`.
-- Kimse görmüyor, aranamıyor, "kaç kişide oldu?" sorusu sorulamıyor. Bu
-- projede bedeli ÖLÇÜLMÜŞ: avatar yükleme 20 Temmuz'dan 13 Ağustos'a kadar
-- 403 veriyordu ve kimse fotoğrafını değiştirmediği için ÜÇ HAFTA görünmedi.
-- Mağazaya çıkıldığında konuşamayacağın kullanıcılar, elinde olmayan
-- cihazlarda hata alacak — telemetri tam o an tek görme yolu. Geriye dönük
-- doldurulamaz (`games.platform` ile aynı sınıf), o yüzden çıkıştan ÖNCE.
--
-- ⚠ `user_id` YOK — `game_starts` ile aynı gizlilik kararı: `PrivacyModal`
-- bölüm 6 anonim cihaz kodu için "hesabınızla ASLA eşleştirilmez" diyor,
-- `anon_id` ile `user_id`'yi aynı satıra koymak tam o eşleştirmeyi yapardı.
-- `anon_id` yine de gerekli, çünkü panelin cevaplaması gereken soru "kaç
-- SATIR" değil "kaç CİHAZDA".
--
-- ⚠ `route` NORMALLEŞTİRİLMİŞ gelir ('/davet/:token', '/game/:id') — ham
-- yol YAZILAMAZ: davet token'ı bir yetenek (capability), hata tablosuna
-- düşmesi onu sızdırırdı. Normalleştirmeyi istemci yapıyor; sunucu ayrıca
-- bir savunma katmanı olarak token benzeri uzun parçaları da maskeliyor.
--
-- ⚠ platform/kind üzerinde CHECK KISITI BİLEREK YOK. `games.platform`ta
-- kısıt DOĞRU, çünkü orada geçersiz bir değer bir OYUN KAYDINI düşürür ve
-- kayıt kıymetlidir. Burada tam tersi: öngörmediğimiz bir değer yüzünden
-- bir HATA RAPORUNU düşürmek, tam da görmek istediğimiz şeyi kör eder.

create table if not exists public.client_errors (
  id          uuid primary key default gen_random_uuid (),
  created_at  timestamptz not null default now (),
  anon_id     uuid,
  platform    text,
  build       text,
  kind        text not null,
  message     text not null,
  stack       text,
  route       text
);

comment on table public.client_errors is
  'İstemcide yakalanan hataların anonim telemetrisi (ROADMAP #3). BİLEREK user_id TAŞIMAZ. route normalleştirilmiş yoldur (/davet/:token) — ham token asla yazılmaz. message/stack kırpılmış gelir ve nadiren kullanıcının girdiği bir değeri içerebilir; bu yüzden gizlilik metninde açıkça anlatılıyor.';

create index if not exists client_errors_created_at_idx on public.client_errors (created_at desc);
create index if not exists client_errors_build_idx on public.client_errors (build);

alter table public.client_errors enable row level security;

-- Yazma her iki istemci rolüne de açık; OKUMA hiçbirine açık değil —
-- select politikası YOK, tabloyu yalnızca security definer admin RPC'si
-- okuyabiliyor (`game_finishes`/`game_starts` ile aynı duruş).
drop policy if exists client_errors_insert_anon on public.client_errors;
create policy client_errors_insert_anon on public.client_errors
  for insert to anon with check (true);

drop policy if exists client_errors_insert_authenticated on public.client_errors;
create policy client_errors_insert_authenticated on public.client_errors
  for insert to authenticated with check (true);

-- ── Sunucu tarafı savunma: uzun/token benzeri parçaları maskele ─────────────
-- İstemci normalleştirmeyi zaten yapıyor, ama tek savunma hattı olmasın:
-- yeni bir route eklenip normalleştirmesi unutulursa token yine sızmasın.
create or replace function public._mask_route (p_route text)
  returns text
  language sql
  immutable
  set search_path = ''
  as $$
    select case
      when p_route is null then null
      -- 12+ karakterlik hex/uuid benzeri parçalar → :id
      else regexp_replace(left(p_route, 200), '[0-9a-fA-F-]{12,}', ':id', 'g')
    end;
  $$;

create or replace function public._client_errors_mask ()
  returns trigger
  language plpgsql
  set search_path = ''
  as $$
begin
  new.route := public._mask_route (new.route);
  new.message := left(new.message, 500);
  new.stack := left(new.stack, 4000);
  return new;
end;
$$;

drop trigger if exists trg_client_errors_mask on public.client_errors;
create trigger trg_client_errors_mask
  before insert on public.client_errors
  for each row execute function public._client_errors_mask ();

-- ── Admin: ham satır listesi DEĞİL, GRUPLANMIŞ döküm ────────────────────────
-- ROADMAP'in şartı: "aynı hata kaç kişide, hangi derlemede". Ham liste ilk yüz
-- satırdan sonra okunmaz hâle gelir; imza bazlı gruplama tek okunabilir biçim.
create or replace function public.admin_client_errors (p_days integer default 7)
  returns table (
    kind        text,
    message     text,
    occurrences bigint,
    devices     bigint,
    platforms   text,
    builds      text,
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
    -- `ce.*` DEĞİL açık kolonlar: `kind`/`message` zaten `k`/`sig` olarak
    -- yeniden adlandırılıyor, `ce.*` onları ikinci kez getirip `group by`da
    -- belirsizlik üretirdi.
    select ce.kind as k,
           left(ce.message, 160) as sig,
           ce.anon_id, ce.platform, ce.build, ce.route, ce.stack, ce.created_at
    from public.client_errors ce
    where ce.created_at >= v_since
  )
  select g.k,
         g.sig,
         count(*)                                   as occurrences,
         count(distinct g.anon_id)                  as devices,
         string_agg(distinct coalesce(g.platform, '?'), ', ' order by coalesce(g.platform, '?')) as platforms,
         string_agg(distinct coalesce(g.build, '?'), ', ' order by coalesce(g.build, '?'))       as builds,
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
