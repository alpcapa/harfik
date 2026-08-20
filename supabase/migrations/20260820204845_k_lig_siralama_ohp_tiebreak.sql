-- k-lig sıralaması: TEK KAYNAK + OHP eşitlik bozucu (20 Ağustos 2026)
--
-- SORUN ÖLÇÜLDÜ: aynı oyuncu (Bobola, 2 puan) k-lig listesinde 13., kendi
-- Skor Kartı'nda "#10" görünüyordu. İki ayrı sebep vardı, ikisi de burada
-- kapanıyor:
--
--  1) `my_leaderboard_rank` `rank()` kullanıyordu — eşit puanlı DÖRT
--     oyuncunun (T3 / Tess / Bobola / Cann, hepsi 2 puan) HEPSİNE 10 diyor.
--     Liste ise sırayı dizideki İNDEKSTEN (i+1) üretiyordu: 10, 11, 12, 13.
--  2) `leaderboard` view'ının `order by`ı YALNIZCA total_score — eşitlikte
--     satır sırası Postgres'in keyfine kalıyor ve sorgudan sorguya
--     DEĞİŞEBİLİYOR (aynı gün iki çalıştırmada 11/12/13 farklı çıktı).
--     Bu ayrıca `.range()` ile sayfalanan listede bir satırın iki kez
--     görünmesine ya da hiç görünmemesine yol açabiliyordu.
--
-- Çözüm: sıra artık TEK bir yerde — bu view'da — hesaplanıyor; hem liste,
-- hem "senin sıran" kısayolu, hem Skor Kartı başlığı aynı sayıyı okuyor.
-- Eşitlik bozucu: OHP (yüksek olan üstte), o da eşitse user_id (kararlı).

create or replace view public.k_lig_siralama
with (security_invoker = true) as
select
  row_number() over (
    order by
      l.total_score desc,
      round(l.avg_move_score, 2) desc nulls last,
      l.user_id asc
  ) as sira,
  l.*
from public.leaderboard l;

comment on view public.k_lig_siralama is
  'k-lig sıralamasının TEK kaynağı. Sıra: puan desc, OHP desc (nulls last), user_id asc. Hem liste (fetchLeaderboard) hem my_leaderboard_rank buradan okur — biri değişirse öteki de değişmeli.';

-- `security_invoker = true` (kullanıcı isteği) BURADA ÇALIŞIR, çünkü altındaki
-- `leaderboard` view'ı `security_invoker = false`: kilitli `profiles`/`games`
-- RLS'ini o bypass ediyor, dıştaki view'ın tek ihtiyacı çağıranın
-- `leaderboard` üzerinde SELECT hakkı — anon ve authenticated'te zaten var.
-- (Doğrudan profiles+games üzerine kurulan bir invoker view HİÇ satır
-- döndürmezdi: profiles SELECT'i owner-or-admin'e kilitli.)

revoke all on public.k_lig_siralama from public, anon, authenticated;
grant select on public.k_lig_siralama to anon, authenticated, service_role;

-- "Senin sıran" artık aynı view'dan. Dönüş kolonları/tipleri DEĞİŞMEDİ
-- (rank/total_score/avg_move_score), yani drop+create gerekmiyor ve mevcut
-- istemciler kırılmıyor — değişen tek şey sayının nereden geldiği:
-- `rank()` (eşitleri aynı sıraya koyan) yerine listenin kendi `row_number()`ı.
create or replace function public.my_leaderboard_rank(p_user_id uuid)
returns table(rank bigint, total_score bigint, avg_move_score numeric)
language sql
stable
set search_path to 'public'
as $function$
  select k.sira, k.total_score::bigint, k.avg_move_score
  from public.k_lig_siralama k
  where k.user_id = p_user_id;
$function$;
