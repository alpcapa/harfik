-- Kelimeki — platform (istemci) boyutu: web / iOS / Android
--
-- NEDEN (14 Ağustos 2026, kullanıcı isteği — Flutter portu yayına çıkmadan ÖNCE):
-- Girişli tarafta bir kullanıcının app'ten mi yoksa web'den mi oynadığını söyleyen
-- HİÇBİR alan yoktu. `guest_visits.device_type`/`is_standalone` yalnızca oturum
-- KAPALIYKEN yazılıyor (tarayıcı mobil mi masaüstü mü — "app mi web mi" DEĞİL).
-- Bu kolon eklenmeden mobil lansmanı ölçmek imkânsızdı: "kaç oyuncu app'e geçti"
-- sorusunun geriye dönük cevabı olmazdı, çünkü geçmiş veri sonradan etiketlenemez.
--
-- ============================ İKİ KAYNAK, TEK CEVAP ============================
-- Platform İKİ ayrı yerde tutuluyor, çünkü `games` satırlarını İKİ FARKLI taraf
-- yazıyor:
--   * YEREL (YZ) oyunlar → satırı İSTEMCİ yazıyor (`saveGame`/`buildGameRecord`),
--     yani platformu doğrudan biliyor: games.platform.
--   * CANLI oyunlar → satırı SUNUCU yazıyor (`_finish_online_game_records`), yani
--     platformu bilemez. Bunun için oyun başına/oyuncu başına küçük bir tablo var
--     (online_game_clients) ve istemci Canlı oyunu açtığında bir kez yazıyor.
-- Admin dökümü ikisini OKUMA ANINDA birleştiriyor (`coalesce`) — yani "tek cevap"
-- tek bir yerde (admin_platform_breakdown) üretiliyor, iki kopya yok.
--
-- ==================== NEDEN submit_move'a DOKUNULMADI (bilinçli) ===============
-- En doğal yer her hamlede platformu almak olurdu (`submit_move`), ama o fonksiyon
-- 424 satır ve projenin EN KRİTİK RPC'si (her Canlı hamle oradan geçiyor); imzasına
-- parametre eklemek onu drop+create etmeyi gerektiriyor. Bir telemetri alanı için,
-- üstelik mobil lansmanın hemen öncesinde, o riski almaya değmez. Bunun yerine
-- yalnızca bu işe hizmet eden, çağrılmazsa hiçbir şeyi bozmayan ayrı bir RPC var:
-- `set_online_game_platform` (fire-and-forget; başarısız olursa oyun etkilenmez).

-- ---------------------------------------------------------------------------
-- 1) games.platform — YEREL oyunlarda istemcinin yazdığı alan
-- ---------------------------------------------------------------------------
alter table public.games
  add column if not exists platform text
  check (platform is null or platform in ('web', 'ios', 'android', 'app-web'));

comment on column public.games.platform is
  'Bu kaydı YAZAN istemci: web | ios | android | app-web (Flutter''ın web test derlemesi — '
  'ürün değil, geliştirici test ortamı; gerçek web trafiğini kirletmesin diye AYRI bir değer). '
  'Yalnızca YEREL oyunlarda dolu; Canlı oyunların satırını sunucu yazdığından orada null kalır '
  've platform online_game_clients''ten çözülür (bkz. admin_platform_breakdown).';

-- games'in TABLO düzeyinde grant'i YOK (10 Ağustos 2026 gizlilik düzeltmesi) —
-- yeni her kolon tek tek verilmeli, yoksa istemci yazamaz.
-- SELECT bilerek VERİLMİYOR: bu kolonu okuması gereken tek taraf admin ve o
-- SECURITY DEFINER RPC üzerinden okuyor. `games` satırları girişli HERKESE açık
-- olduğundan SELECT vermek "bu kullanıcı hangi cihazdan oynuyor" bilgisini
-- gereksizce herkese açardı (bkz. games.messages dersi).
grant insert (platform) on public.games to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) online_game_clients — CANLI oyunlarda oyuncu başına platform
-- ---------------------------------------------------------------------------
create table if not exists public.online_game_clients (
  online_game_id uuid not null references public.online_games(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('web', 'ios', 'android', 'app-web')),
  updated_at timestamptz not null default now(),
  primary key (online_game_id, user_id)
);

comment on table public.online_game_clients is
  'Canlı oyun başına, oyuncu başına son bilinen istemci platformu. İstemci Canlı oyunu '
  'açtığında set_online_game_platform ile bir kez yazar. Yalnızca telemetri — oyun akışının '
  'hiçbir yerinde okunmuyor, yazılamazsa hiçbir şey bozulmaz.';

alter table public.online_game_clients enable row level security;
-- Bilinçli olarak HİÇ policy yok: yazma yalnızca aşağıdaki SECURITY DEFINER
-- RPC'den, okuma yalnızca admin RPC'sinden. İstemci rollerinin tabloya doğrudan
-- erişimi de ayrıca kaldırılıyor (Supabase yeni tablolara varsayılan grant verir).
revoke all on public.online_game_clients from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) set_online_game_platform — istemcinin çağırdığı tek yazma yolu
-- ---------------------------------------------------------------------------
-- Fire-and-forget: geçersiz girdi/yetkisiz çağrı SESSİZCE yok sayılır (exception
-- fırlatılmaz), çünkü çağıran taraf sonucu beklemiyor ve bir telemetri hatası
-- Canlı oyun ekranının açılışını bozmamalı.
create or replace function public.set_online_game_platform(
  p_game_id uuid,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return;
  end if;
  if p_platform is null or p_platform not in ('web', 'ios', 'android', 'app-web') then
    return;
  end if;
  if not is_online_game_participant(p_game_id, v_uid) then
    return;
  end if;

  insert into public.online_game_clients (online_game_id, user_id, platform, updated_at)
  values (p_game_id, v_uid, p_platform, now())
  on conflict (online_game_id, user_id)
  do update set platform = excluded.platform, updated_at = now();
end;
$$;

revoke all on function public.set_online_game_platform(uuid, text) from public, anon, authenticated;
grant execute on function public.set_online_game_platform(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) admin_platform_breakdown — iki kaynağı okuma anında birleştiren TEK yer
-- ---------------------------------------------------------------------------
create or replace function public.admin_platform_breakdown(
  p_days integer default 30
)
returns table(platform text, games bigint, players bigint)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
begin
  if not is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    coalesce(g.platform, c.platform, 'bilinmiyor') as platform,
    count(*)::bigint as games,
    count(distinct g.user_id)::bigint as players
  from public.games g
  left join public.online_game_clients c
    on c.online_game_id = g.online_game_id and c.user_id = g.user_id
  where g.user_id is not null
    and g.created_at > now() - make_interval(days => greatest(p_days, 1))
  group by 1
  order by 2 desc, 1;
end;
$$;

revoke all on function public.admin_platform_breakdown(integer) from public, anon, authenticated;
grant execute on function public.admin_platform_breakdown(integer) to authenticated;
