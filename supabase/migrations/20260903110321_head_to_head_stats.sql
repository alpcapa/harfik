-- Kafa kafaya istatistik: çağıran ile bakılan kişi arasında oynanmış
-- 2 KİŞİLİK Canlı oyunların sayısı ve kazanma dağılımı.
--
-- NEDEN SUNUCUDA (3 Eylül 2026, kullanıcı isteği — skor kartının altındaki
-- oran çubuğu): istemcide `fetchMyGames` SAYFALI (20'şer) ve iki kişi
-- arasındaki TÜM oyunları saymak geçmişin tamamını sayfalamak demekti.
-- Ayrıca donmuş `games.players` anlık görüntüsü `user_id` TAŞIMIYOR, yani
-- istemcide eşleme ancak İSİMLE yapılabilirdi; takma adlar değiştirilebildiği
-- için o yol sessizce yanlış sayardı. Sunucuda `online_games.slots` gerçek
-- `user_id` taşıyor — kesin eşleme.
--
-- ⚠ GÜVENLİK SINIRI: SECURITY DEFINER RLS'i bypass ediyor, o yüzden tek
-- koruma `g.user_id = auth.uid()` koşuludur ve fonksiyon SADECE çağıranın
-- KENDİ `games` satırlarını okur. Karşı tarafın hiçbir satırı okunmuyor;
-- onun hakkında öğrenilen tek şey "bu oyunun koltuğunda mıydı", ki bunu
-- çağıran zaten `list_my_online_games` ile görebiliyor. Yani yeni bir
-- görünürlük AÇILMIYOR.
--
-- YALNIZCA 2 KİŞİLİK (kullanıcı kararı): 4 kişilik bir oyunda ikinizin
-- arasındaki sonucu öteki iki oyuncu belirlemiş olabilir, "kafa kafaya"
-- demek yanıltıcı olurdu.
--
-- Sonuç çağıranın BAKIŞ AÇISINDAN: `wins` = çağıran kazandı,
-- `losses` = bakılan kişi kazandı, `draws` = eşit skor.
create or replace function public.head_to_head_stats(p_other uuid)
returns table(games int, wins int, losses int, draws int)
language sql
security definer
stable
set search_path to 'public'
as $$
  select
    count(*)::int as games,
    -- Teslim olan HER ZAMAN kaybeder: skoru 0'a çekiliyor ama rakip de 0
    -- puanla bitirmiş olabilir, o yüzden bayrak skordan ÖNCE bakılıyor.
    count(*) filter (
      where g.surrendered is not true and g.player_score > g.ai_score
    )::int as wins,
    count(*) filter (
      where g.surrendered is true or g.player_score < g.ai_score
    )::int as losses,
    count(*) filter (
      where g.surrendered is not true and g.player_score = g.ai_score
    )::int as draws
  from public.games g
  join public.online_games og on og.id = g.online_game_id
  where g.user_id = auth.uid()
    -- Kendi kartına bakarken kafa kafaya anlamsız.
    and p_other is distinct from auth.uid()
    and og.player_count = 2
    -- `ai_score` 2 kişilik oyunda RAKİBİN skorudur (`buildGameRecord`:
    -- bestOpponentScore), yani karşılaştırma doğrudan yapılabiliyor.
    and og.slots @> jsonb_build_array(
      jsonb_build_object('type', 'human', 'user_id', p_other::text)
    );
$$;

revoke all on function public.head_to_head_stats(uuid) from public;
grant execute on function public.head_to_head_stats(uuid) to authenticated;

comment on function public.head_to_head_stats(uuid) is
  'Çağıran ile p_other arasında oynanmış 2 kişilik Canlı oyunların sayısı ve kazanma dağılımı. Yalnızca çağıranın kendi games satırlarını okur.';
