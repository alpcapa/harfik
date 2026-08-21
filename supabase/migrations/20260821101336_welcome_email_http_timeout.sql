-- ÖLÇÜLEN KIRILGANLIK: `net.http_post`un varsayılan zaman aşımı 5 saniye ve
-- Edge Function'ın SOĞUK başlangıcı bunu aşabiliyor. Doğrulama turunda
-- birebir yaşandı: fonksiyona yapılan İLK çağrı
-- "Timeout of 5000 ms reached ... HTTP Request/Response time: 4843 ms" ile
-- düştü, hemen ardından yapılan ikinci (sıcak) çağrı 200 döndü.
--
-- Bu, bu bildirimde diğerlerinden DAHA PAHALI: hoş geldiniz maili kullanıcı
-- başına HAYATTA BİR KEZ gönderiliyor ve `welcome_email_sent_at` çağrıdan
-- ÖNCE damgalandığı için kaybedilen bir istek bir daha DENENMİYOR. Süre
-- 20 saniyeye çekiliyor — soğuk başlangıç için fazlasıyla yeterli, ve
-- `net.http_post` zaten asenkron (trigger'ı ya da kaydı bekletmiyor).
create or replace function public._notify_welcome_email()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'auth'
as $function$
declare
  _claimed boolean := false;
begin
  -- Yalnızca adresi DOĞRULANMIŞ hesaplar. INSERT dalı bugün ulaşılamaz
  -- (doğrulama açık, satır onaysız doğuyor) ama e-posta doğrulaması bir
  -- gün kapatılırsa hoş geldiniz maili sessizce hiç gitmesin diye duruyor.
  if new.email_confirmed_at is null then
    return new;
  end if;

  -- Atomik iddia: aynı satır iki kez kapılamaz, dolayısıyla mail en fazla
  -- bir kez tetiklenir. `profiles` satırı UPDATE dalında her zaman var;
  -- INSERT dalında `on_auth_user_created` bu trigger'dan ÖNCE koşar
  -- (Postgres aynı olayda trigger'ları ADA GÖRE sıralar: "created" <
  -- "welcome"), yani satır oradan gelir. Yine de bulunamazsa sessizce
  -- çıkılıyor — bildirim hiçbir koşulda kaydı düşürmemeli.
  update public.profiles
    set welcome_email_sent_at = now()
    where id = new.id and welcome_email_sent_at is null;
  get diagnostics _claimed = row_count;

  if _claimed then
    -- `check_turn_timeout`taki aynı pg_net deseni, tek farkı açık zaman
    -- aşımı (yukarıdaki gerekçe). Transaction geri alınırsa istek kuyruğa
    -- hiç girmez (testlerde bu bilinçli olarak kullanılıyor).
    perform net.http_post(
      url := 'https://xvqlizifakkkoqahaxsg.supabase.co/functions/v1/notify-welcome',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := jsonb_build_object('user_id', new.id),
      timeout_milliseconds := 20000
    );
  end if;

  return new;
end;
$function$;

revoke all on function public._notify_welcome_email() from public, anon, authenticated;
