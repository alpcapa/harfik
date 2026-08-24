-- Kelimeki — TÜM ziyaretlerde (girişli + girişsiz) anonim cihaz/OS pingi
--
-- `guest_visits`e BİLİNÇLİ OLARAK dokunulmadı: o tablo yalnızca oturum
-- KAPALIYKEN yazılıyor ve Kaynak Hunisi'ni besliyor — huni 22 Ağustos
-- 2026'da tam olarak "yalnızca misafir" kalsın diye daraltıldı
-- (`source_funnel_guest_only` migration'ı). `guest_visits`i girişli
-- kullanıcıları da kapsayacak şekilde genişletmek o kararı geri alırdı ve
-- huniye üye trafiğini geri karıştırırdı.
--
-- Ama kullanıcı isteği (24 Ağustos 2026, verbatim): "Funnel'ın amacı
-- değişik kaynaklardan gelen kişilerin hareketlerini takip etmekti...
-- Bu tamamen misafir (girişsiz) datası. Cihaz datası ise gelen tüm
-- insanların (girişli veya girişsiz) hangi cihazlardan, işletim
-- sistemlerinden vb geldiğini görmek. Girişliler için kişisel bilgi
-- olarak ilişkilendirilmeleri gerekmiyor. Anonim olsunlar." — yani admin
-- panelindeki "Cihaz" tablosu huniden BAĞIMSIZ bir soru soruyor ve girişli
-- kullanıcıları da kapsamalı.
--
-- Çözüm: AYRI, tamamen bağımsız bir tablo — `device_visits`. Şema/RLS
-- deseni `game_starts`in aynısı: anonim `anon_id` (guest_visits ile aynı
-- cihaz kimliği, istemci tarafında localStorage'da üretilir), BİLEREK
-- `user_id` YOK — anonim cihaz kodunu hesapla aynı satırda birleştirmek
-- PrivacyModal bölüm 6'nın "asla eşleştirilmez" taahhüdünü bozardı. Okuma
-- yalnızca aşağıdaki admin RPC'sinden — client rollerine hiçbir SELECT
-- politikası verilmedi (guest_visits'in aksine, orada da SELECT client'a
-- hiç açık değildi zaten, aynı desen).
--
-- `guest_visits.device_type`/`os_version`/`device_model` ve onları okuyan
-- `admin_guest_device_breakdown` RPC'si BİLEREK SİLİNMEDİ/dokunulmadı —
-- yazılmaya devam ediyor (guest_visits'in kendi yazarları hiç değişmedi),
-- yalnızca admin panelindeki "Cihaz" tablosu artık bu yeni tablodan
-- besleniyor (`fetchAdminPlatformBreakdown`'ın "kod duruyor, çağrılmıyor"
-- hâliyle aynı desen).

create table if not exists public.device_visits (
  id            uuid primary key default gen_random_uuid (),
  anon_id       uuid not null,
  device_type   text not null,
  os_version    text,
  device_model  text,
  created_at    timestamptz not null default now()
);

comment on table public.device_visits is 'Girişli VEYA girişsiz HER ziyarette (günde bir kez, cihaz başına) atılan tamamen anonim "hangi cihaz/OS" pingi — guest_visits''ten BAĞIMSIZ (o yalnızca girişsizken yazılır ve Kaynak Hunisi''ni besler; bu tablo hiçbir huniyi beslemez, yalnızca admin panelindeki "Cihaz" dökümü için). anon_id istemci tarafında localStorage''da üretilen rastgele bir uuid''dir; BİLEREK user_id YOK, hesapla asla eşleştirilmez.';
comment on column public.device_visits.device_type is 'navigator.userAgent''tan okunan işletim sistemi sınıfı: "ios"/"android"/"desktop" (bkz. src/utils/visitTracking.ts, getDeviceType).';
comment on column public.device_visits.os_version is 'İyi niyetle (best-effort) navigator.userAgent''tan ayrıştırılan işletim sistemi sürümü. Ayrıştırılamazsa null. Şimdilik hiçbir admin ekranında gösterilmiyor.';
comment on column public.device_visits.device_model is 'İyi niyetle (best-effort) navigator.userAgent''tan ayrıştırılan cihaz bilgisi. iOS''ta yalnızca "iPhone"/"iPad" genel kategorisi (tarayıcı gerçek model vermiyor); Android''de sık sık null (User-Agent reduction). Masaüstünde her zaman null. Şimdilik hiçbir admin ekranında gösterilmiyor.';

create index if not exists device_visits_created_at_idx on public.device_visits (created_at desc);
create index if not exists device_visits_anon_id_idx on public.device_visits (anon_id);

alter table public.device_visits enable row level security;

drop policy if exists device_visits_insert_any on public.device_visits;
create policy device_visits_insert_any on public.device_visits
  for insert
  to anon, authenticated
  with check (true);

-- Büyüme > Kullanıcı: cihaz tipi başına benzersiz ziyaretçi sayısı — girişli
-- VE girişsiz TÜM ziyaretleri kapsar (guest_visits'in tersine).
create or replace function public.admin_device_breakdown (
  p_days integer default 30
)
  returns table (
    device_type  text,
    visitors     bigint
  )
  language plpgsql
  stable
  security definer
  set search_path = public, auth
  as $$
begin
  if not public.is_admin () then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    coalesce(dv.device_type, 'bilinmiyor') as device_type,
    count(distinct dv.anon_id) as visitors
  from public.device_visits dv
  where dv.created_at >= now() - (greatest(p_days, 1) || ' days')::interval
  group by 1
  order by visitors desc;
end;
$$;

revoke all on function public.admin_device_breakdown (integer) from public, anon;
grant execute on function public.admin_device_breakdown (integer) to authenticated;
