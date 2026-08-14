-- Kelimeki — admin Büyüme paneli: aktif oyuncu serisi, retention kohortları, aktivasyon
--
-- NEDEN (14 Ağustos 2026, kullanıcı isteği): panel bugüne kadar yalnızca "kaç yeni
-- üye/ziyaret geldi" ve "kaç oyun bitti" sorularını yanıtlıyordu. Hiçbir metrik
-- "gelen KALDI mı?" sorusunu sormuyordu — yani en pahalı soru (kullanıcı kazanımı)
-- ölçülüyor, en değerlisi (elde tutma) ölçülmüyordu.
--
-- ============================ "AKTİF OYUNCU" TANIMI ============================
-- TEK KAYNAK: _admin_user_activity view'ı. Bir kullanıcı, şu ÜRÜN eylemlerinden
-- birini yaptığı anda aktiftir: oyun bitirme, Canlı hamle, Canlı sohbet mesajı,
-- beğeni, arkadaşlık isteği, Canlı oyun kurma.
--
-- Hepsi APPEND-ONLY olay tablolarıdır ve asıl mesele budur: GEÇMİŞ bir ay için de
-- yeniden hesaplanabilirler. Bir metriğin "MAU" sayılabilmesinin şartı, penceresinin
-- istenen herhangi bir tarih için yeniden üretilebilmesidir.
--
-- BİLEREK KULLANILMAYAN dört sinyal (14 Ağustos 2026'da canlıda ÖLÇÜLDÜ):
--   * auth.users.last_sign_in_at — token yenilemede güncellenMİYOR (yani gerçek
--     giriş anı; 15 kullanıcıda son refresh, last_sign_in_at'ten >2 saat yeni).
--     Ama tek bir ÜZERİNE YAZILAN kolon: "şu an son 28 günde giriş yapmış mı"
--     sorusunu yanıtlar, geçmiş bir ay için ASLA. Seri üretilemez.
--   * auth.refresh_tokens — ~saatlik "uygulama açıktı" nabzı (427 satır), AMA
--     ~26 günde budanıyor (en eski satır 26 günlük, ilk hesap 28 Haziran'dan) ve
--     auth'un iç tablosu: bir Supabase değişikliğinde sessizce kırılır.
--   * auth.audit_log_entries — SIFIR satır (kapalı ya da budanıyor).
--   * guest_visits — TASARIM GEREĞİ yalnızca oturum KAPALIYKEN yazılıyor (RLS
--     insert'i yalnız anon rolüne veriyor) ve hesapla eşleştirilemez (PrivacyModal
--     taahhüdü).
--
-- SONUÇ: girişli kullanıcı için "uygulamayı açtı" sinyali BU ŞEMADA YOK. Buradaki
-- metrik bu yüzden bilerek "MAU" DEĞİL, "aktif oyuncu"dur — uygulamayı açıp hiçbir
-- şey yapmadan çıkanı saymaz. Gerçek MAU istenirse append-only bir "app_opens"
-- olayı (anon_id + nullable user_id, kullanıcı başına günde bir satır) eklenmeli;
-- o yeni bir kişisel veri olduğundan PrivacyModal de güncellenmek zorunda.
--
-- ======================= AKTİVASYON NEDEN FARKLI TANIMLI =======================
-- admin_activation_stats BİLEREK bu view'ı KULLANMIYOR: "aktivasyon" sorusu
-- "hiç oyun BİTİRDİ mi" (public.games satırı), "herhangi bir şey yaptı mı" değil.
-- Bir arkadaşlık isteği göndermiş ama hiç oyun bitirmemiş üye aktif OYUNCU sayılır
-- ama aktive olmuş SAYILMAZ. İki farklı soru, iki farklı tanım — biri ötekine
-- "tutarlılık" gerekçesiyle uydurulMAMALI.

-- ---------------------------------------------------------------------------
-- Ortak aktiflik olayı görünümü (yalnızca SECURITY DEFINER fonksiyonlar okur)
-- ---------------------------------------------------------------------------
create or replace view public._admin_user_activity as
  select g.user_id, g.created_at from public.games g where g.user_id is not null
  union all
  select m.player_user_id, m.created_at from public.online_game_moves m where m.player_user_id is not null
  union all
  select c.sender_user_id, c.created_at from public.online_game_messages c
  union all
  select l.user_id, l.created_at from public.game_likes l
  union all
  select f.user_id, f.created_at from public.friend_requests f
  union all
  select o.created_by, o.created_at from public.online_games o;

-- Supabase yeni view/tablolara varsayılan olarak anon+authenticated GRANT'i verir —
-- bu view kullanıcı kimliklerini çapraz tablolardan birleştirdiğinden hiçbir istemci
-- rolüne açılmamalı; yalnızca aşağıdaki definer fonksiyonlar okuyor.
revoke all on public._admin_user_activity from public, anon, authenticated;

comment on view public._admin_user_activity is
  'Admin büyüme metrikleri için ortak "aktif oyuncu" olay akışı. İstemciye KAPALI. '
  'Yeni bir ürün eylemi (ör. yeni bir sosyal özellik) aktiflik sayılacaksa buraya eklenir — '
  'aktif oyuncu serisi ve retention kohortları bu tek kaynaktan beslendiğinden ikisi asla ayrışmaz.';

-- ---------------------------------------------------------------------------
-- 1) Aktif oyuncu serisi — kova içi + 28 günlük yuvarlanan pencere
-- ---------------------------------------------------------------------------
-- 28 gün (30 değil) bilinçli: tam dört hafta olduğundan hafta-içi/hafta-sonu
-- dalgalanması pencereye eşit dağılır, sayı takvim ayı uzunluğuyla oynamaz.
create or replace function public.admin_active_players_series(
  p_periods integer default 30,
  p_granularity text default 'day'
)
returns table(bucket date, active_in_bucket bigint, active_28d bigint)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_unit text := case
    when p_granularity = 'year' then 'year'
    when p_granularity = 'month' then 'month'
    when p_granularity = 'week' then 'week'
    else 'day'
  end;
  v_step interval := case
    when v_unit = 'year' then interval '1 year'
    when v_unit = 'month' then interval '1 month'
    when v_unit = 'week' then interval '1 week'
    else interval '1 day'
  end;
  v_end timestamp := date_trunc(v_unit, now() at time zone 'Europe/Istanbul');
  v_start timestamp := v_end - (greatest(p_periods, 1) - 1) * v_step;
begin
  if not is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    d.bucket::date as bucket,
    (
      select count(distinct a.user_id)
      from public._admin_user_activity a
      where (a.created_at at time zone 'Europe/Istanbul') >= d.bucket
        and (a.created_at at time zone 'Europe/Istanbul') <  d.bucket + v_step
    ) as active_in_bucket,
    (
      select count(distinct a.user_id)
      from public._admin_user_activity a
      where (a.created_at at time zone 'Europe/Istanbul') >= d.bucket + v_step - interval '28 days'
        and (a.created_at at time zone 'Europe/Istanbul') <  d.bucket + v_step
    ) as active_28d
  from generate_series(v_start, v_end, v_step) as d (bucket)
  order by d.bucket;
end;
$$;

revoke all on function public.admin_active_players_series(integer, text) from public, anon, authenticated;
grant execute on function public.admin_active_players_series(integer, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Retention kohortları — kayıt haftasına göre, uzun (long) biçimde
-- ---------------------------------------------------------------------------
-- Pivotlamayı istemci yapar; SQL'de dinamik kolon üretmek gerekmesin diye
-- her hücre ayrı bir satır olarak döner.
--
-- YALNIZCA TAMAMLANMIŞ haftalar döner: penceresi henüz bitmemiş bir hafta her
-- zaman yapay olarak düşük görünür ve kohort tablosunun son köşegenini yalan
-- söyleyen bir "düşüş" gibi gösterirdi.
create or replace function public.admin_retention_cohorts(
  p_cohorts integer default 8
)
returns table(cohort_week date, cohort_size bigint, week_offset integer, active_users bigint)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_now timestamp := now() at time zone 'Europe/Istanbul';
  v_first timestamp := date_trunc('week', v_now) - (greatest(p_cohorts, 1) - 1) * interval '1 week';
begin
  if not is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  with cohort_members as (
    select
      date_trunc('week', u.created_at at time zone 'Europe/Istanbul') as cw,
      u.id as user_id
    from auth.users u
    where date_trunc('week', u.created_at at time zone 'Europe/Istanbul') >= v_first
  ),
  sizes as (
    select cm.cw, count(*) as n from cohort_members cm group by cm.cw
  ),
  cells as (
    select s.cw, s.n, o.off
    from sizes s
    cross join generate_series(0, greatest(p_cohorts, 1) - 1) as o (off)
    -- pencere TAMAMEN geçmişte mi?
    where s.cw + (o.off + 1) * interval '1 week' <= v_now
  )
  select
    c.cw::date as cohort_week,
    c.n as cohort_size,
    c.off as week_offset,
    (
      select count(distinct a.user_id)
      from public._admin_user_activity a
      join cohort_members cm on cm.user_id = a.user_id and cm.cw = c.cw
      where (a.created_at at time zone 'Europe/Istanbul') >= c.cw + c.off * interval '1 week'
        and (a.created_at at time zone 'Europe/Istanbul') <  c.cw + (c.off + 1) * interval '1 week'
    ) as active_users
  from cells c
  order by c.cw, c.off;
end;
$$;

revoke all on function public.admin_retention_cohorts(integer) from public, anon, authenticated;
grant execute on function public.admin_retention_cohorts(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Aktivasyon — "kayıt oldu ama hiç oyun bitirmedi" ve ilk oyuna kadar geçen süre
-- ---------------------------------------------------------------------------
-- NEGATİF SÜRE GERÇEK BİR DURUM, hata değil: misafirken oynanıp bitirilen bir oyun
-- gameSync kuyruğuyla (kelimeki:pending-games) kişi SONRADAN üye olunca hesabına
-- işleniyor ve games.created_at oyunun GERÇEK bitiş anını taşıyor — yani hesabın
-- yaratılmasından önce olabilir. Bu kişiler "kayıttan önce zaten oynuyordu"
-- demektir; süre sıfıra kırpılıyor (greatest(..., 0)).
create or replace function public.admin_activation_stats()
returns table(
  total_users bigint,
  activated_users bigint,
  never_activated bigint,
  activated_same_day bigint,
  activated_within_3_days bigint,
  activated_later bigint,
  median_hours_to_first_game numeric
)
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
  with firsts as (
    select
      u.created_at as signed_up,
      (select min(g.created_at) from public.games g where g.user_id = u.id) as first_game
    from auth.users u
  ),
  gaps as (
    select
      f.first_game is not null as activated,
      greatest(f.first_game - f.signed_up, interval '0') as gap
    from firsts f
  )
  select
    count(*)::bigint,
    count(*) filter (where activated)::bigint,
    count(*) filter (where not activated)::bigint,
    count(*) filter (where activated and gap < interval '1 day')::bigint,
    count(*) filter (where activated and gap >= interval '1 day' and gap < interval '3 days')::bigint,
    count(*) filter (where activated and gap >= interval '3 days')::bigint,
    round(
      percentile_cont(0.5) within group (
        order by (case when activated then extract(epoch from gap) / 3600.0 end)::double precision
      )::numeric,
      1
    )
  from gaps;
end;
$$;

revoke all on function public.admin_activation_stats() from public, anon, authenticated;
grant execute on function public.admin_activation_stats() to authenticated;
