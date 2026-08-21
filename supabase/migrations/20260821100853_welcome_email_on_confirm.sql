-- Yeni üyeye "hoş geldiniz" e-postası (21 Ağustos 2026, kullanıcı isteği).
--
-- NE ZAMAN: kayıt anında DEĞİL, e-posta ADRESİ DOĞRULANDIĞINDA. Üç sebep,
-- üçü de ölçüldü/kanıtlı:
--   1. Bu projede e-posta doğrulaması AÇIK (26 hesabın 24'ü `created_at`ten
--      SONRA onaylanmış; `agreed_to_terms`in yıllardır `false` kalmasının
--      sebebi de buydu — signUp() session döndürmüyor). Kayıt anında mail
--      atmak, henüz sahipliği kanıtlanmamış bir adrese yazmak demek:
--      bounce oranı domainin gönderim itibarını yakar (bu proje DKIM/DMARC'ı
--      düzeltmek için ayrıca uğraştı, bkz. kök CLAUDE.md "Brevo SMTP").
--   2. Kullanıcı o anda ZATEN bir mail alıyor (onay maili). İkincisini aynı
--      saniyede yollamak ikisini de değersizleştirir.
--   3. Üretimde 2 hesap hiç onaylamamış — onlar fiilen üye değil ve
--      "Hemen Oyna" düğmesi onlar için çalışmaz.
--
-- İDEMPOTENS: `profiles.welcome_email_sent_at`. Trigger önce ATOMİK olarak
-- iddia ediyor (`where welcome_email_sent_at is null`), yalnızca satırı
-- gerçekten kaptıysa `net.http_post` çağırıyor — `reminder_sent_at`/
-- `deadline_warning_sent_at` ile aynı desen.

alter table public.profiles
  add column if not exists welcome_email_sent_at timestamptz;

comment on column public.profiles.welcome_email_sent_at is
  'Hoş geldiniz e-postasının GÖNDERİLMEYE ÇALIŞILDIĞI an (atomik iddia). '
  'Bu özellikten ÖNCE onaylanmış hesaplarda geriye dönük dolduruldu — '
  'orada "gönderildi" değil "atlandı" anlamına gelir.';

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
  -- çıkılıyor — telemetri/bildirim hiçbir koşulda kaydı düşürmemeli.
  update public.profiles
    set welcome_email_sent_at = now()
    where id = new.id and welcome_email_sent_at is null;
  get diagnostics _claimed = row_count;

  if _claimed then
    -- `check_turn_timeout`taki aynı pg_net deseni. Transaction geri
    -- alınırsa istek kuyruğa hiç girmez (testlerde bu bilinçli olarak
    -- kullanılıyor).
    perform net.http_post(
      url := 'https://xvqlizifakkkoqahaxsg.supabase.co/functions/v1/notify-welcome',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := jsonb_build_object('user_id', new.id)
    );
  end if;

  return new;
end;
$function$;

revoke all on function public._notify_welcome_email() from public, anon, authenticated;

drop trigger if exists on_auth_user_welcome on auth.users;
create trigger on_auth_user_welcome
  after insert or update of email_confirmed_at on auth.users
  for each row execute function public._notify_welcome_email();

-- Geriye dönük: MEVCUT onaylı üyelere ASLA toplu mail gitmesin. Bu satırlar
-- "gönderildi" değil "bu özellikten önce üye oldu, atlandı" demek (kolon
-- yorumunda da yazılı). Hiç onaylamamış hesaplar BİLEREK null bırakılıyor:
-- yarın onaylarlarsa hoş geldiniz mailini hak ediyorlar.
update public.profiles p
set welcome_email_sent_at = u.email_confirmed_at
from auth.users u
where u.id = p.id
  and p.welcome_email_sent_at is null
  and u.email_confirmed_at is not null;
