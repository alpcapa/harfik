-- Kelimeki — onaylanmamış hesap süpürmesi: SAATLİK cron (23 Ağustos 2026)
--
-- ⚠ SAATLİK OLMAK ZORUNDA — günlüğe çekilirse özellik sessizce bozulur.
-- Gerekçe: onay linki 24 saat yaşıyor ve hatırlatma 20. saatte atılıyor.
-- Günlük bir iş 12:00'de kayıt olanı ertesi gün 11:00'de kontrol eder,
-- kişi henüz 23 saatliktir, atlanır; hatırlatma ancak 47. saatte gider —
-- oysa ilk link 24. saatte ölmüştür ve arada 23 saatlik bir ÖLÜ BÖLGE kalır.
-- Saatlik koşuda o pencere en fazla 1 saat.
--
-- ⚠ timeout 60 sn (varsayılan 5 sn DEĞİL). Bu proje aynı tuzağa bir kez
-- düştü: `welcome_email_http_timeout` — soğuk başlangıç 5 sn'yi aşıp isteği
-- düşürmüştü. Bu fonksiyon ayrıca N kullanıcı için sırayla link üretip mail
-- gönderiyor, yani 5 sn kolayca yetmez.
--
-- Diğer iki cron'la aynı dakikada koşmasın diye :25'e alındı
-- (notify-deadline-warnings */15, notify-friend-request-reminders 08:00).
select cron.schedule(
  'sweep-unconfirmed-accounts',
  '25 * * * *',
  $$
  select net.http_post(
    url := 'https://xvqlizifakkkoqahaxsg.supabase.co/functions/v1/sweep-unconfirmed-accounts',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);
