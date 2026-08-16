-- YZ zorluk dengesi: yerel (Yapay Zeka'ya karşı) oyunlarda insanın
-- kazanma/berabere/kaybetme dağılımı, oyuncu sayısı bazında.
--
-- Gerekçe (16 Ağustos 2026): veri zaten `games`te duruyordu ama admin
-- panelinde hiç gösterilmiyordu — oysa bu tek sayı oyunun eğlence
-- dengesini doğrudan söylüyor ve YZ'ye (`src/utils/ai.ts` /
-- `kelimeki_core`) dokunan her değişiklikte regresyon buradan görünür.
-- Ölçüm anındaki değer: 124/260 = %48.
--
-- KAPSAM KARARLARI:
--  * Yalnızca yerel oyunlar (`online_game_id is null`) — Canlı oyunda
--    rakip insan, YZ dengesiyle ilgisi yok.
--  * `surrendered` satırlar DIŞARIDA: onlar bir beceri sonucu değil,
--    7 günlük terk-edilme cezasının kaydı (bkz. "Terk edilen oyunun
--    otomatik temizliği"). İçeri alınsalardı YZ olduğundan güçlü
--    görünürdü.
--  * Zaman penceresi YOK — bugünkü hacimde (260 oyun) günlük kırılım
--    gürültü olurdu. YZ değiştirilirse pencere tek satırla eklenir.
--
-- Çıkış sütunu bilerek `players` (`player_count` DEĞİL): plpgsql'de
-- OUT parametresi ile tablo kolonu aynı adı taşıyınca `group by`
-- belirsizleşiyor.

create or replace function public.admin_ai_balance()
returns table(
  players integer,
  games bigint,
  wins bigint,
  ties bigint,
  losses bigint
)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $function$
begin
  if not public.is_admin () then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    g.player_count as players,
    count(*) as games,
    count(*) filter (where g.result = 'win') as wins,
    count(*) filter (where g.result = 'tie') as ties,
    count(*) filter (where g.result = 'lose') as losses
  from public.games g
  where g.online_game_id is null
    and not g.surrendered
  group by g.player_count
  order by g.player_count;
end;
$function$;

revoke all on function public.admin_ai_balance() from public;
revoke all on function public.admin_ai_balance() from anon;
grant execute on function public.admin_ai_balance() to authenticated;
grant execute on function public.admin_ai_balance() to service_role;
