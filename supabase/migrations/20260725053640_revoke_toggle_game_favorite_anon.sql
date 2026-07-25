-- Supabase yeni fonksiyonlara varsayılan olarak hem anon hem authenticated'e
-- doğrudan EXECUTE veriyor (public'e değil) — önceki migration'daki
-- "revoke all ... from public" bu yüzden anon'u kapsamadı (bkz.
-- revoke_feedback_rate_limit_check_execute migration'ındaki aynı ders).
-- toggle_game_favorite zaten auth.uid() olmayan (anon) çağrılarda sahiplik
-- kontrolünde exception fırlatıyor, ama gereksiz bir RPC yüzeyini kapalı
-- tutmak için anon'un EXECUTE'u de açıkça kaldırılıyor.
revoke execute on function public.toggle_game_favorite(uuid) from anon;
