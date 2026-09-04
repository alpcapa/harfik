-- Kelimeki — kafa kafaya çubuğu: kararı SKORDAN türetme, satırın `result`unu kullan.
--
-- HATA (4 Eylül 2026, kullanıcı bildirdi): *"teslimleri beraberlik olarak
-- sayıyor. Danyal ile Ironman arasında 1 oyun var ve teslim olduğu için gri
-- (beraberlik) gibi gözüküyor."*
--
-- KÖK SEBEP — fonksiyon yalnızca ÇAĞIRANIN teslim bayrağını görebiliyordu:
-- `games` satırı kişi başına yazılıyor, yani `g.surrendered` "BEN teslim
-- oldum mu" demek. Rakip teslim olduğunda onun skoru 0'a çekiliyor
-- (`ai_score`), çağıranın skoru da 0 ise satır 0-0 görünüyor ve eski kural
-- onu `draws`a yazıyordu. Gerçek vaka birebir buydu:
--
--   Danyal  : surrendered=true , 0-0 → lose  ✅ (eski kural doğru)
--   Ironman : surrendered=false, 0-0 → tie   ❌ (doğrusu win)
--
-- ÇÖZÜM — cevap zaten satırda: `games.result` ('win'/'lose'/'tie'), bitişte
-- `_finish_online_game_records` tarafından `rankPlayers` mantığıyla yazılıyor
-- ve teslim olanı puanından BAĞIMSIZ olarak sona koyuyor. Skoru yeniden
-- yorumlamak, o kararı ikinci kez ve EKSİK bilgiyle vermekti.
--
-- ÖLÇÜLDÜ (canlı, 2 kişilik Canlı oyunların tamamı = 119 satır): skordan
-- türetilen karar ile `result` 115 satırda AYNI, 4 satırda ayrışıyor ve
-- dördü de aynı yönde — "tie" sanılan, aslında "win". Yani değişiklik tam
-- olarak bu hatayı düzeltiyor, başka hiçbir satırı oynatmıyor.
--
-- `result` NOT NULL ve CHECK ile üç değere kısıtlı, yani wins+losses+draws
-- her zaman games ediyor (çubuğun %100 etmesi buna bağlı — 119/119 doğrulandı).
--
-- ⚠ `security definer` ve `search_path` KORUNMALI; `create or replace`
-- grant'leri düşürmüyor ama yine de doğrulandı: anon=false, authenticated=true.
create or replace function public.head_to_head_stats(p_other uuid)
returns table(games integer, wins integer, losses integer, draws integer)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    count(*)::int as games,
    count(*) filter (where g.result = 'win')::int  as wins,
    count(*) filter (where g.result = 'lose')::int as losses,
    count(*) filter (where g.result = 'tie')::int  as draws
  from public.games g
  join public.online_games og on og.id = g.online_game_id
  where g.user_id = auth.uid()
    -- Kendi kartına bakarken kafa kafaya anlamsız.
    and p_other is distinct from auth.uid()
    and og.player_count = 2
    and og.slots @> jsonb_build_array(
      jsonb_build_object('type', 'human', 'user_id', p_other::text)
    );
$function$;
