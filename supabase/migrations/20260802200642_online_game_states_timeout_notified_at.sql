-- notify-turn-timeout-surrender Edge Function'ı verify_jwt=false ile herkese
-- açık bir POST hedefi (çağıran Postgres'in kendisi, kullanıcı JWT'si yok —
-- bkz. check_turn_timeout). Fonksiyonun kendisi yalnızca hedef oyunun KALICI
-- DB durumunu (end_reason='surrender' AND is_game_over=true) doğruluyordu;
-- bu durum bir kez sağlandıktan sonra hep true kaldığından, bitmiş bir
-- oyunun online_game_id'sini bilen herkes aynı URL'e tekrar tekrar POST
-- atarak aynı kullanıcı(lar)a "-2 puan cezası aldın" mailini sınırsız kez
-- gönderebiliyordu. Bu sütun, notify-deadline-warnings/friend-request-reminders
-- fonksiyonlarındaki "atomik iddia" (`is(x_sent_at, null)` filtreli UPDATE)
-- deseninin aynısını burada da mümkün kılıyor.
alter table public.online_game_states
  add column if not exists timeout_notified_at timestamptz;
