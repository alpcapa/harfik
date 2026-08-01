-- 3 gün cevapsız kalan arkadaşlık isteklerine tek seferlik bir hatırlatma
-- e-postası göndermek için (notify-friend-request-reminders Edge Function'ı,
-- deadline_warning_sent_at ile aynı desen — atomik `is(..., null)` filtreli
-- UPDATE ile "iddia edilir"). Cancel (satır silinir) ve resend (yeni satır,
-- bu alan yeniden null) doğal olarak sayacı sıfırlar — ayrı bir reset
-- trigger'ına gerek yok (online_game_states/local_game_saves'in aksine).
alter table public.friend_requests add column reminder_sent_at timestamptz;

comment on column public.friend_requests.reminder_sent_at is
  'Bu istek 3 gün cevapsız kaldığında gönderilen tek seferlik hatırlatma e-postasının zamanı (henüz gönderilmediyse null). notify-friend-request-reminders cron''u tarafından atomik olarak set edilir.';
