-- pg_cron/pg_net zaten deadline_warnings_cron migration'ında etkinleştirildi
-- (IF NOT EXISTS ile güvenli tekrar). Günde bir kez (08:00 UTC ≈ 11:00
-- İstanbul) notify-friend-request-reminders'ı tetikler — deadline
-- hatırlatmalarının aksine (48 saatlik pencere, 15 dakikada bir kontrol
-- gerektiriyor) burada gün bazlı bir eşik (3 gün) olduğundan günlük tarama
-- yeterli.
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'notify-friend-request-reminders',
  '0 8 * * *',
  $$
  select net.http_post(
    url := 'https://xvqlizifakkkoqahaxsg.supabase.co/functions/v1/notify-friend-request-reminders',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
