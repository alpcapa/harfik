-- Kelimeki — "Oyun başladı" olayı: huninin son adımı artık kör değil
--
-- GEREKÇE (20-21 Ağustos 2026, ROADMAP #9). İlk Instagram kampanyası ölçüldü
-- ve huninin son adımı KÖR çıktı: `instagram` etiketiyle 80 kişi / 0 üye /
-- 0 oyun. Panel doğru çalışıyordu; sorun ÖLÇÜLEN ŞEYDE:
--   * Bugüne kadar yalnızca BİTMİŞ oyun kaydediliyordu. "Oyun başladı" olayı
--     yoktu — `game_starts` tablosu 20 Temmuz 2026'da "hiçbir yerde ihtiyaç
--     görülmedi" gerekçesiyle kaldırılmıştı
--     (`remove_game_starts_add_session_split_counts`). O gün doğruydu; ücretli
--     trafik gelince yanlış oldu.
--   * Yerel oyunun medyan süresi 18,1 dakika (16 Ağustos 2026 ölçümü).
--     Reklamdan gelen soğuk bir ziyaretçinin ilk temasta bunu BİTİRMESİNİ
--     beklemek gerçekçi değil — yani "0 oyun" büyük olasılıkla "kimse
--     bitirmedi" demek, "kimse oynamadı" değil.
--   * Huninin "Oyun" sütunu zaten misafir oyunlarını göremiyor (`games`
--     satırı yalnızca girişli kullanıcı için açılıyor), o yüzden misafir
--     ağırlıklı bir kampanyada o sütun TANIM GEREĞİ 0.
-- Sonuç: "açılış sayfası mı çalışmıyor, yoksa oyun mu fazla uzun bir taahhüt?"
-- sorusu bugünkü veriyle ayrılamıyordu. İkisi tamamen farklı aksiyon
-- gerektiriyor. Geriye dönük doldurulamaz (`games.platform` ve
-- `profiles.signup_utm_source` ile aynı sınıf) — bir sonraki reklam
-- harcamasından ÖNCE eklenmesinin sebebi bu.
--
-- ⚠ TABLODA `user_id` YOK ve bu BİLİNÇLİ bir gizlilik kararı.
-- `PrivacyModal` (bölüm 6) anonim cihaz kodu için şunu taahhüt ediyor:
-- "hesabınızla ASLA eşleştirilmez". `anon_id` ile `user_id`'yi aynı satıra
-- koymak tam olarak o eşleştirmeyi yapardı. Bu yüzden `game_starts`
-- `guest_visits`in desenini birebir izliyor: tamamen anonim. Bedeli, Büyüme >
-- Oyun'daki Kayıtlı/Misafir kırılımının bu olay için yapılamaması — ama o
-- kırılım bu işin sorduğu soruya (kaynak başına dönüşüm) gerekmiyor ve
-- bitmiş taraf için `game_finishes` zaten sağlıyor.
--
-- KAPSAM: yerel (YZ'ye karşı) oyunlar — `game_finishes`in birebir aynası.
-- Canlı oyunların "başlama" anı zaten sunucuda kayıtlı
-- (`online_game_states.started_at`), ayrıca Canlı oyun hesap + arkadaş
-- gerektirdiğinden soğuk reklam trafiğinin girebileceği bir yol değil.
--
-- `utm_source` SÖZLEŞMESİ (`profiles.signup_utm_source` ile aynı):
--   * web `?ref=` hiç yoksa bile AÇIKÇA 'direkt' gönderir,
--   * dolayısıyla NULL yalnızca "bu istemci damgalamıyor" demektir (bugün:
--     Flutter portu) ve RPC'de 'bilinmiyor' olarak sayılır.
-- Bu ayrım olmadan port satırları 'direkt' satırını sessizce şişirirdi.

create table if not exists public.game_starts (
  id            uuid primary key default gen_random_uuid (),
  anon_id       uuid,
  player_count  integer not null,
  utm_source    text,
  created_at    timestamptz not null default now ()
);

comment on table public.game_starts is
  'Başlatılan her YEREL (YZ) oyun için anonim sayaç kaydı (misafir dahil). Kişisel veri içermez ve BİLEREK user_id TAŞIMAZ — anon_id ile hesap kimliğini aynı satırda birleştirmek PrivacyModal bölüm 6''daki "hesabınızla asla eşleştirilmez" taahhüdünü bozardı. anon_id, cihazda saklanan rastgele koddur (guest_visits ile aynı); istemci damgalamıyorsa (bugün mobil port) null olur.';

create index if not exists game_starts_created_at_idx on public.game_starts (created_at desc);
create index if not exists game_starts_utm_source_idx on public.game_starts (utm_source);

alter table public.game_starts enable row level security;

-- Yazma her iki istemci rolüne de açık (girişli kullanıcı da oyun başlatır),
-- OKUMA hiçbirine açık değil: select politikası YOK, tabloyu yalnızca
-- security definer admin RPC'si okuyabiliyor (`game_finishes` ile aynı duruş).
drop policy if exists game_starts_insert_anon on public.game_starts;
create policy game_starts_insert_anon on public.game_starts
  for insert
  to anon
  with check (true);

drop policy if exists game_starts_insert_authenticated on public.game_starts;
create policy game_starts_insert_authenticated on public.game_starts
  for insert
  to authenticated
  with check (true);

-- ── Kaynak Hunisi: "Başlayan" adımı ─────────────────────────────────────────
-- Dönüş tipi değiştiğinden `create or replace` YETMEZ: drop + create ve
-- grant'ler elle geri kuruluyor (bkz. 20260725053640 dersi).
--
-- `starts`   = başlatılan oyun ADEDİ,
-- `starters` = o oyunları başlatan BENZERSİZ cihaz sayısı.
-- İkisi ayrı, çünkü "kişilerin yüzde kaçı oynamaya BAŞLADI" sorusu oyun
-- adediyle yanıtlanamaz — bir cihaz 50 oyun başlatabilir (mevcut `games`/
-- `players` çiftindeki aynı ders).
--
-- `starters` ile `visitors` AYNI kimlikten (`anon_id`) sayıldığından
-- `starters / visitors` bu tablodaki TEK gerçek cihaz-bazlı dönüşüm oranıdır;
-- `signups`/`players` ise `profiles.signup_utm_source` üzerinden gelir, yani
-- ayrı bir dimension (aralarında join YOK, olamaz).

drop function if exists public.admin_source_funnel (integer);

create function public.admin_source_funnel (p_days integer default 30)
  returns table (
    source    text,
    visitors  bigint,
    starts    bigint,
    starters  bigint,
    signups   bigint,
    games     bigint,
    players   bigint
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
    union select src from s
    union select src from g
  )
  select k.src,
         coalesce(v.n, 0),
         coalesce(st.n, 0),
         coalesce(st.uniq, 0),
         coalesce(s.n, 0),
         coalesce(g.n, 0),
         coalesce(g.pl, 0)
  from k
  left join v on v.src = k.src
  left join st on st.src = k.src
  left join s on s.src = k.src
  left join g on g.src = k.src
  order by coalesce(v.n, 0) desc, coalesce(st.n, 0) desc, coalesce(s.n, 0) desc, k.src;
end;
$function$;

revoke all on function public.admin_source_funnel (integer) from public, anon;
grant execute on function public.admin_source_funnel (integer) to authenticated, service_role;
