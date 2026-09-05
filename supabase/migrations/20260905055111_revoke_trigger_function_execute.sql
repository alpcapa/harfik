-- Trigger fonksiyonlarının gereksiz REST erişimi — 5 Eylül 2026,
-- Play Store öncesi güvenlik geçişi, ROADMAP #21.
--
-- Bu dört fonksiyon YALNIZCA trigger olarak çağrılmalı, ama `anon` ve
-- `authenticated`e `execute` izniyle duruyorlardı, yani
-- /rest/v1/rpc/<ad> uçları herkese açıktı. Ötekiler zaten doğru
-- yapılandırılmış (`handle_new_user`, `_notify_welcome_email`,
-- `_notify_your_turn`, `feedback_rate_limit_check` → yalnızca
-- `service_role`), yani bu bir tutarsızlıktı: sekiz trigger
-- fonksiyonunun dördü kuruluştaki örtük grant'i temizlemeyi atlamış.
--
-- ⚠ SÖMÜRÜLEBİLİR OLDUKLARI GÖSTERİLMEDİ: Postgres bir trigger
-- fonksiyonunun doğrudan çağrılmasını reddeder. Bu bir derinlemesine
-- savunma ve advisor gürültüsü temizliği; sekiz uyarının dördünü kapatır.
--
-- TRIGGER'LAR BOZULMAZ — bu depoda ÖLÇÜLDÜ, varsayılmadı. Aynı işlem
-- `feedback_rate_limit_check` için 22 Temmuz 2026'da yapılmıştı
-- (`20260722122236_revoke_feedback_rate_limit_check_execute`); o tarihten
-- sonra `feedback` tablosuna 18 satır girdi (3 Eylül'e kadar) ve her biri
-- o BEFORE INSERT trigger'ından geçmek zorundaydı. Sebep: EXECUTE izni
-- `create trigger` anında kontrol edilir, trigger ATEŞLENİRKEN değil.
--
-- Dördünün de bir trigger'a bağlı olduğu doğrulandı (RPC olarak kullanılan
-- yok):
--   _game_finishes_strip_anon_id → game_finishes.game_finishes_strip_anon_id
--   handle_friend_request_insert → friend_requests.friend_requests_before_insert
--   keep_signup_utm_source       → profiles.trg_keep_signup_utm_source
--   trg_award_league_rewards     → games.games_award_league_rewards

revoke execute on function public._game_finishes_strip_anon_id() from public, anon, authenticated;
revoke execute on function public.handle_friend_request_insert()  from public, anon, authenticated;
revoke execute on function public.keep_signup_utm_source()        from public, anon, authenticated;
revoke execute on function public.trg_award_league_rewards()      from public, anon, authenticated;
