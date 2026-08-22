-- Kelimeki — `game_finishes.utm_source`: huninin SON adımı artık misafiri de görüyor
--
-- GEREKÇE (22 Ağustos 2026, kullanıcı sordu). İlk Instagram kampanyasında
-- panel şunu gösteriyordu: `instagram` satırında 46 başlayan oyun, 3 üye,
-- **0 oyun**. Ölçüldü ve "0" GERÇEKTİ — üç üyenin üçü de üye olduğu dakikada
-- son kez girmiş, birer YZ oyunu açıp ORTASINDA bırakmıştı. Ama tablo yine de
-- asıl soruyu cevaplayamıyordu:
--
--   "Instagram'dan gelen MİSAFİRLER oyun bitiriyor mu?"
--
-- Çünkü huninin "Oyun" sütunu `games` satırlarını sayıyor ve o satır YALNIZCA
-- girişli kullanıcı için açılıyor — misafir oyunu oraya hiç yazılmaz. Misafir
-- bitirmeleri `game_finishes`te duruyordu (o gün 15, tüm zamanlarda 40) ama
-- tablo KAYNAK ETİKETİ TAŞIMADIĞINDAN hangisinin kampanyadan geldiği
-- bilinemiyordu. Yani 21 Ağustos'ta `game_starts`e eklenen etiketin bitmiş
-- taraftaki eşi eksikti: huni "başlayan"ı kaynağa göre görüyor, "biten"i
-- görmüyordu.
--
-- Bu, kampanya kararını doğrudan değiştiren bir ayrım: 38 cihazın hiçbiri
-- bitirmiyorsa sorun OYUNDA (fazla uzun bir taahhüt), bitirenler varsa sorun
-- yalnızca ÜYELİĞE DÖNÜŞÜMDE. İkisi tamamen farklı aksiyon gerektiriyor.
--
-- ⚠ GERİYE DÖNÜK DOLDURULAMAZ (`games.platform`, `profiles.signup_utm_source`
-- ve `game_starts.utm_source` ile aynı sınıf) — bir sonraki reklam
-- harcamasından ÖNCE eklenmesinin sebebi bu.
--
-- ⚠ `anon_id` EKLENMEDİ ve bu bilinçli: `game_finishes` `user_id` TAŞIYOR,
-- yanına cihaz kodunu koymak `PrivacyModal` bölüm 6'daki "anonim cihaz
-- kodunuz hesabınızla ASLA eşleştirilmez" taahhüdünü bozardı. Bedeli, bitmiş
-- tarafta "benzersiz CİHAZ" sayılamaması — `game_starts`teki `starters`ın
-- karşılığı yok. Kaynak başına "kaç oyun bitti" sorusu için gerekmiyor.
--
-- `utm_source` SÖZLEŞMESİ `game_starts` ile BİREBİR aynı:
--   * web `?ref=` hiç yoksa bile AÇIKÇA 'direkt' gönderir,
--   * dolayısıyla NULL yalnızca "bu istemci damgalamıyor" demektir (bugün:
--     Flutter portu) ve RPC'de 'bilinmiyor' olarak sayılır.
-- Bu ayrım olmadan port satırları 'direkt' satırını sessizce şişirirdi.
--
-- KAPSAM: `game_finishes` zaten yalnızca YEREL (YZ) oyunları yazıyor (Canlı
-- oyunlar `_finish_online_game_records` ile `games`e yazılıyor, buraya hiç
-- dokunmuyor) — yani "Başlayan" ve "Biten" artık BİREBİR aynı kapsamı ölçüyor
-- ve doğrudan karşılaştırılabilir.

alter table public.game_finishes
  add column if not exists utm_source text;

comment on column public.game_finishes.utm_source is
  'Cihazda saklanan ilk-temas `?ref=` etiketi (game_starts ile aynı sözleşme). Web `?ref=` yokken bile ''direkt'' yazar; NULL yalnızca damgalamayan bir istemciden (bugün mobil port) gelir ve admin RPC''sinde ''bilinmiyor'' sayılır.';

create index if not exists game_finishes_utm_source_idx
  on public.game_finishes (utm_source);

-- Grant tablo düzeyinde olduğundan yeni kolon kendiliğinden kapsanıyor; yine
-- de açıkça veriliyor (bir gün kolon bazlı grant'e geçilirse sessizce
-- kırılmasın — `games.messages` dersinin tersi yönü).
grant insert (utm_source) on public.game_finishes to anon, authenticated;
