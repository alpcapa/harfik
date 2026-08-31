-- Kelimeki — `game_finishes.anon_id`: bitmiş tarafta BENZERSİZ CİHAZ sayılabilsin
--
-- GEREKÇE (28 Ağustos 2026, kullanıcı sordu: *"Bitirenler kaç unique kişi?
-- Ya da hepsi farklı kişi mi?"* → "Evet işlere ekle"). Kaynak hunisinde
-- "Başlayan" tarafında `starters` (benzersiz cihaz) VARDI, "Biten" tarafında
-- karşılığı YOKTU. Yani "şu kadar bitiş kaç kişiden geldi" sorusunun dürüst
-- cevabı "1 ile N arası, bilinmiyor"du — ve bu, kampanya kararını doğrudan
-- etkileyen bir körlük: 117 oyunun 64 cihazdan geldiği, üstelik İKİ cihazın
-- tek başına 47 oyun başlattığı ölçülmüştü.
--
-- ⚠ EKLENMEME SEBEBİ BİR EKSİKLİK DEĞİL, YAZILI BİR GİZLİLİK KARARIYDI
-- (`20260822043039_game_finishes_utm_source`): bu tablo `user_id` TAŞIYOR ve
-- yanına cihaz kodunu koymak `PrivacyModal` bölüm 6'daki *"anonim cihaz
-- kodunuz hesabınızla ASLA eşleştirilmez"* taahhüdünü bozardı.
-- `game_starts`te `anon_id` bulunabilmesinin sebebi tam tersi: o tablo hesap
-- kimliği HİÇ taşımıyor, yalnızca bir `is_guest` bayrağı var.
--
-- TAAHHÜDÜ BOZMADAN ÇÖZÜM: `anon_id` YALNIZCA `user_id` NULL iken yazılır.
-- İkisi aynı satırda hiçbir zaman bulunmadığından cihaz↔hesap eşlemesi
-- DOĞMAZ, taahhüt aynen ayakta kalır. Huninin misafir sütunları zaten
-- `user_id is null` filtreliyor, yani ölçü tam da o satırlar için üretiliyor.
--
-- ⚠ İKİ KATMANLI ZORLAMA, ve ikincisinin sebebi bu projenin kendi dersi.
--   1. CHECK kısıtı: değişmez SQL'de yazılı, yoruma bırakılmıyor.
--   2. BEFORE INSERT trigger: `user_id` doluyken `anon_id`i sessizce NULL'a
--      çeker, yani kısıt istemci girdisinden ASLA tetiklenemez.
-- Neden ikisi birden: bu kod tabanında "bir telemetri alanı yüzünden kayıt
-- düşer" sınıfı yazılı bir tehlike (`platform.dart`: *"kısıt dışında bir
-- değer yollamak games insert'ini düşürür, yani bir telemetri alanı yüzünden
-- oyun kaydı kaybolur"*). Tek başına CHECK, ileride bir istemci ikisini
-- birden yollarsa BİTİŞ TELEMETRİSİNİ KAYBETTİRİRDİ — yani gizliliği
-- korurken ölçümü öldürürdü. Trigger o kaybı imkânsız kılıyor; CHECK ise
-- doğrudan SQL'e karşı değişmezi kanıtlıyor. Aynı desen `client_errors`ın
-- `_mask_route` trigger'ında zaten var ("tek savunma hattı OLMAMALI").
--
-- ⚠ GERİYE DÖNÜK DOLDURULAMAZ (`games.platform`, `game_starts.utm_source`,
-- `game_finishes.utm_source` ile aynı sınıf) — bir sonraki reklam
-- harcamasından ÖNCE girmesinin sebebi bu.
--
-- KAPSAM SINIRI (bugün doğru, yarın değişebilir): Flutter portu `anon_id`
-- YOLLAMIYOR — portun damgalama katmanı (`visitTracking.ts` karşılığı) hiç
-- yazılmadı, `logGameStart` da aynı sebeple null gönderiyor. Yani port
-- satırları `finishes`e girer, `finishers`a GİRMEZ. Pratikte bir sapma
-- yaratmıyor: port `utm_source`u da null gönderdiğinden o satırlar zaten
-- 'bilinmiyor' kaynağında toplanıyor, reklam kampanyalarının baktığı
-- satırlarda (instagram vb.) yalnızca web var. Port damgalamayı eklerse
-- BURASI DA güncellenmeli (`games_api.dart`ın kendi notuyla aynı kanca).

alter table public.game_finishes
  add column if not exists anon_id uuid;

comment on column public.game_finishes.anon_id is
  'Cihazın anonim kodu — YALNIZCA user_id NULL iken yazılır (trigger + CHECK zorluyor). Aynı satırda hesap kimliğiyle asla bulunmaz: PrivacyModal 6. bölümdeki "anonim kod hesabınızla eşleştirilmez" taahhüdü budur. Flutter portu bugün göndermiyor.';

-- Trigger ÖNCE: kısıt eklenirken tabloda zaten uyumsuz satır olmasın diye
-- değil (kolon yeni, hepsi NULL), ileriki INSERT'ler için.
create or replace function public._game_finishes_strip_anon_id ()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
  as $$
begin
  -- Hesap kimliği varsa cihaz kodu DÜŞER. Reddetmiyoruz: bir telemetri
  -- alanının kaydı düşürmesi bu projede kayıtlı bir hata sınıfı.
  if new.user_id is not null then
    new.anon_id := null;
  end if;
  return new;
end;
$$;

drop trigger if exists game_finishes_strip_anon_id on public.game_finishes;
create trigger game_finishes_strip_anon_id
  before insert or update on public.game_finishes
  for each row execute function public._game_finishes_strip_anon_id ();

alter table public.game_finishes
  drop constraint if exists game_finishes_anon_xor_user;
alter table public.game_finishes
  add constraint game_finishes_anon_xor_user
  check (anon_id is null or user_id is null);

-- Kolon bazlı grant: bu tabloda yetkiler KOLON KOLON verilmiş (ölçüldü:
-- information_schema.column_privileges), yani yeni kolon kendiliğinden
-- kapsanMAZ ve grant unutulursa istemci insert'i düşer.
grant insert (anon_id) on public.game_finishes to anon, authenticated;

-- ── Kaynak Hunisi: "Biten" tarafına benzersiz cihaz sayacı ────────────────
-- Dönüş tipi değişiyor (9. kolon), yani `create or replace` YETMEZ — ayrıca
-- bu kod tabanında onun sessizce ikinci bir overload yarattığı gerçek bir
-- vaka var (`fix_withdraw_report_wrong_overload`). drop + create, grant'ler
-- elle.
drop function if exists public.admin_source_funnel (integer);

create function public.admin_source_funnel (p_days integer default 30)
  returns table (
    source        text,
    visitors      bigint,
    starts        bigint,
    starters      bigint,
    signups       bigint,
    finishes      bigint,
    finishers     bigint,
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
    -- AYNI kitle (üye olmadan oynayanlar).
    --
    -- `uniq` (28/31 Ağustos 2026): `starters`ın bitmiş taraftaki eşi.
    -- `count(distinct)` NULL'ları saymaz, yani `anon_id` kolonundan ÖNCEKİ
    -- satırlar ve damgalamayan istemciler (port) buraya girmez — `finishes`
    -- ile arasındaki fark tam olarak odur ve istemci bunu böyle anlatıyor.
    select coalesce(gf.utm_source, 'bilinmiyor') as src,
           count(*) as n,
           count(distinct gf.anon_id) as uniq
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
         coalesce(fi.uniq, 0),
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
