-- Kelimeki — `push_tokens.app_version` + `admin_push_version_breakdown`
-- (ROADMAP #12, 31 Ağustos 2026)
--
-- SORU (kullanıcı, 1.0.3 duyurusundan sonra): "kaç kişi yenide?"
-- Bugün CEVAPLANAMIYOR ve sebebi ölçüldü: `app_version` damgası yalnızca
-- İKİ tabloda var — `game_starts` ve `client_errors`. Yani sürümü ancak
-- biri YZ'li YEREL oyun açtığında ya da HATA aldığında görüyoruz:
--   · yalnızca Canlı oynayan kullanıcı hiç görünmüyor,
--   · port `anon_id` göndermediğinden android satırlarında cihaz
--     sayılamıyor (`admin_app_version_breakdown`ın `devices` kolonu 0),
-- dolayısıyla eldeki tek şey "kaç OYUN açıldı", "kaç KİŞİ" değil.
--
-- ÇÖZÜM `push_tokens`: satır `user_id` ile anahtarlı ve `pushTokenlariHizala`
-- HER AÇILIŞTA (ve her öne dönüşte) koşuyor — yani oyun oynamak gerekmiyor.
-- Kapsam "bildirim izni vermiş herkes"; izin vermeyen görünmez ve bu dürüst
-- bir sınır, ölçüm de zaten "kaça bildirim gidiyor"un kapsamıyla aynı olur.
--
-- ⚠ GERİYE DÖNÜK DOLDURULAMAZ (`games.platform`/`game_starts.app_version`
-- ile aynı sınıf): mevcut satırlar null kalır ve ancak o cihaz 1.0.4+ ile
-- açıldığında dolar. Yani "bilinmiyor" bir süre ÇOĞUNLUK olacak — bu bir
-- arıza değil, kolonun doğum tarihi.
--
-- ⚠ CHECK KISITI YOK (aynı gerekçe: `client_errors.app_version`). Öngörülmemiş
-- bir sürüm dizgisi satırı DÜŞÜRMEMELİ — telemetri, veriyi kaybetmektense
-- tuhaf bir değer taşımayı tercih eder.
alter table public.push_tokens add column if not exists app_version text;

comment on column public.push_tokens.app_version is
  'Token en son hangi uygulama sürümüyle hizalandı (mobile/app/lib/src/config/env.dart → appVersion). 1.0.4 ÖNCESİ satırlarda null.';

-- ── `register_push_token` — üçüncü parametre ───────────────────────────────
-- ⚠ ESKİ 2 PARAMETRELİ SÜRÜM ÖNCE DÜŞÜRÜLÜYOR, üstüne yazılmıyor. Sebep:
-- `p_app_version`in varsayılanı olsa bile iki fonksiyon YAN YANA dururdu ve
-- 2 argümanlı bir çağrı ikisine de uyup "function is not unique" (42725)
-- hatası verirdi. Yani "geriye dönük uyumluluk için eskisini bırakalım"
-- refleksi burada TAM TERSİ sonuç verir.
--
-- Sahadaki eski istemciler (1.0.0–1.0.3) `{p_token, p_platform}` ADLI
-- argümanlarla çağırıyor; PostgREST bunu varsayılanı olan üçüncü parametreyi
-- atlayarak bu fonksiyona çözer, yani onlar için davranış DEĞİŞMEZ ve
-- `app_version` null kalır.
drop function if exists public.register_push_token (text, text);

create or replace function public.register_push_token (
  p_token text,
  p_platform text,
  p_app_version text default null
) returns void
  language plpgsql
  security definer
  set search_path to 'public'
  as $function$
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli.';
  end if;
  if p_token is null or length(p_token) < 20 then
    raise exception 'Geçersiz token.';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'Geçersiz platform: %', p_platform;
  end if;

  insert into public.push_tokens (token, user_id, platform, app_version, updated_at)
  values (p_token, auth.uid(), p_platform, left(p_app_version, 32), now())
  on conflict (token) do update
    set user_id = auth.uid(),
        platform = excluded.platform,
        -- ⚠ `coalesce` YOK ve bu bilinçli: eski istemci null gönderirse satır
        -- null'a DÖNMELİ. Aksi halde bir cihaz 1.0.4'e çıkıp sonra eskiye
        -- düşürülürse tabloda sonsuza kadar yanlış (yeni) sürüm görünürdü.
        app_version = excluded.app_version,
        updated_at = now();
end;
$function$;

revoke all on function public.register_push_token (text, text, text) from public;
grant execute on function public.register_push_token (text, text, text) to authenticated;

-- ── Admin: "kaç KİŞİ hangi sürümde" ───────────────────────────────────────
-- `admin_app_version_breakdown`ın (game_starts) YERİNE geçmiyor, YANINA
-- geliyor — ikisi farklı soru cevaplıyor ve ikisi de gerekli:
--   · o tablo   → "hangi sürümden kaç oyun açıldı" (misafir dahil, izin
--                  gerekmez, ama yalnızca YEREL oyunlar)
--   · bu tablo  → "hangi sürümde kaç KİŞİ var" (giriş + bildirim izni
--                  gerekir, ama oyun oynamak gerekmez)
--
-- `p_days` penceresi `updated_at`e bakıyor: token her açılışta hizalandığından
-- bu fiilen "son N günde uygulamayı AÇAN kişi" demek. Uygulamayı silen ama
-- token'ı bayat kalan cihaz pencerenin dışına düşer (satır FCM
-- `UNREGISTERED` dönene kadar silinmez — bkz. `_shared/push.ts`).
create or replace function public.admin_push_version_breakdown (p_days integer default 30)
  returns table (
    platform    text,
    app_version text,
    kisi        bigint,
    cihaz       bigint,
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
  select coalesce(pt.platform, 'bilinmiyor')    as platform,
         coalesce(pt.app_version, 'bilinmiyor') as app_version,
         -- ⚠ İKİ SAYI, çünkü biri diğerinin yerini tutmuyor: bir kişinin
         -- birden çok cihazı olabilir (kişi < cihaz) ve aynı cihaz hesap
         -- değiştirdiğinde token DEVREDİLİR, yani tek satır kalır.
         count(distinct pt.user_id)             as kisi,
         count(*)                               as cihaz,
         max(pt.updated_at)                     as last_seen
  from public.push_tokens pt
  where pt.updated_at >= v_since
  group by 1, 2
  order by count(distinct pt.user_id) desc, 1, 2;
end;
$$;

revoke all on function public.admin_push_version_breakdown (integer) from public, anon;
grant execute on function public.admin_push_version_breakdown (integer) to authenticated, service_role;
