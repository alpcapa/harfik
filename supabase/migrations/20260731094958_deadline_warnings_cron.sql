create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'notify-deadline-warnings',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := 'https://xvqlizifakkkoqahaxsg.supabase.co/functions/v1/notify-deadline-warnings',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
