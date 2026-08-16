-- Kelimeki — Kaynak Hunisi: yüzdeler artık SATIR YÖNÜNDE dönüşüm oranı
--
-- Kullanıcı isteği (16 Ağustos 2026, funnel'ın aynı günkü ikinci turu):
-- *"kişi %'ye dönünce toplamın yüzdesini göstersin. Ama üye yüzdesi kişinin
-- % kaçı üye olmuş, oyun yüzdesi de kişinin % kaçı oyun oynamışı göstersin."*
--
-- İlk sürümde üç sütunun da yüzdesi SÜTUN payıydı ve satır yönünde bir oran
-- BİLİNÇLİ olarak yoktu ("Kişi" anonim ziyaret, "Üye" hesap — iki ayrı
-- dimension). Kullanıcı isteği bunu tersine çeviriyor ve aslında damgalama
-- (`profiles.signup_utm_source`) yerleştikten sonra ANLAMLI hâle geliyor:
-- `?ref=instagram` ile gelen ziyaretçi de, oradan üye olan hesap da AYNI
-- etiketi taşıyacağından `üye / kişi` o kaynak için gerçek bir dönüşüm oranı.
-- Sınırı ekranda açıkça yazılıyor: iki uç da damgalanmamışsa oran anlamsız,
-- ve `kişi = 0` iken hiç hesaplanmıyor ("—").
--
-- BU MIGRATION'IN GEREKÇESİ: "kişinin % kaçı OYUN OYNAMIŞ" sorusu oyun
-- ADEDİYLE yanıtlanamaz — bir kişi 50 oyun oynayabilir, `oyun / kişi` %100'ü
-- kolayca aşar ve "kaç kişi oynadı" demek olmaz. Bu yüzden RPC'ye dördüncü
-- bir ölçü ekleniyor: `players` = o kaynağın damgasını taşıyan, pencerede EN
-- AZ BİR oyun bitirmiş BENZERSİZ kullanıcı sayısı. Tabloda "Oyun" sütunu sayı
-- modunda oyun adedini, yüzde modunda `players / visitors` oranını gösterir —
-- bu ayrım ekranın kendisinde de yazılı.
--
-- Dönüş tipi değiştiğinden `create or replace` YETMEZ: drop + create gerekiyor
-- ve grant'ler elle geri kuruluyor (bkz. 20260725053640 dersi).

drop function if exists public.admin_source_funnel(integer);

create function public.admin_source_funnel(p_days integer default 30)
returns table(source text, visitors bigint, signups bigint, games bigint, players bigint)
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
  s as (
    select coalesce(p.signup_utm_source, 'bilinmiyor') as src,
           count(*) as n
    from public.profiles p
    where p.created_at >= v_since
    group by 1
  ),
  g as (
    -- `n` oyun ADEDİ, `pl` o oyunları oynayan BENZERSİZ kişi sayısı.
    select coalesce(p.signup_utm_source, 'bilinmiyor') as src,
           count(*) as n,
           count(distinct gm.user_id) as pl
    from public.games gm
    join public.profiles p on p.id = gm.user_id
    where gm.created_at >= v_since
    group by 1
  ),
  k as (
    select src from v union select src from s union select src from g
  )
  select k.src,
         coalesce(v.n, 0),
         coalesce(s.n, 0),
         coalesce(g.n, 0),
         coalesce(g.pl, 0)
  from k
  left join v on v.src = k.src
  left join s on s.src = k.src
  left join g on g.src = k.src
  order by coalesce(v.n, 0) desc, coalesce(s.n, 0) desc, k.src;
end;
$function$;

-- Grant'ler drop ile kaybolur — mevcut ACL birebir geri kuruluyor.
revoke all on function public.admin_source_funnel(integer) from public, anon, authenticated;
grant execute on function public.admin_source_funnel(integer) to authenticated, service_role;
