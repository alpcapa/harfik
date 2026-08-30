-- Kelimeki — "sıra sende" push tetikleyicisi (ROADMAP #13 / Faz 4,
-- 30 Ağustos 2026). Kullanıcı isteği: "App'de notification özelliği
-- açanlara hamle sırası ... geldiğinde uyarılar çıkmalı."
--
-- NEDEN TRIGGER, NEDEN İSTEMCİ DEĞİL: sıra devri İKİ ayrı yoldan ilerliyor
-- (submit_move — insan VE YZ hamleleri — ile check_turn_timeout'un devir
-- dalı) ve ikisi de `online_game_states.current`i günceller. Kancayı bu
-- UPDATE'e asmak her iki yolu (ve ileride eklenecek bir üçüncüsünü) TEK
-- yerden yakalar; istemciden çağrılsaydı sahadaki eski sürümlerin hamleleri
-- bildirim üretmezdi — Faz 4'ün "SÜRÜM GEREKTİRMEZ" vaadi bununla tutuyor.
--
-- Desen `_notify_welcome_email` ile aynı (trigger → koşullar → net.http_post;
-- transaction rollback olursa istek kuyruğa hiç girmez). Bir FARK: burada
-- welcome'daki gibi bir "atomik iddia" kolonu YOK ve gerekmiyor — olay
-- (current'ın ilerlemesi) hamle başına doğal olarak bir kez oluşuyor,
-- deadline_warning_sent_at'ın çözdüğü "tekrar tetiklenen cron" sınıfı
-- burada hiç doğmuyor.
--
-- ROADMAP #13'ün iki tuzağı:
--   (a) "hamleyi YAPANA gönderme" — yapısal olarak imkânsız: hedef, hamle
--       SONRASI current koltuğu; v_next = (current+1) % player_count hiçbir
--       zaman hamleciyi göstermez (2+ oyuncu).
--   (b) "hızlı gidip gelen oyunda spam" — hedef oyuncu son 10 dakika içinde
--       bu oyunda hamle yaptıysa zaten oyunun başındadır: http_post HİÇ
--       yapılmaz. (Ölçü `online_game_moves.created_at`ten; ek kolon yok.
--       10 dakika bir ürün tahmini — şikayet gelirse tek satırlık ayar.)
--
-- Edge Function tarafındaki güvenlik simetrisi: `notify-your-turn`
-- verify_jwt KAPALI olduğundan hedefi GÖVDEDEN almaz, current'ı kendisi
-- okur — bu trigger'ın gönderdiği body bilerek yalnızca oyun id'si taşır.

create or replace function public._notify_your_turn()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_slot jsonb;
  v_target uuid;
begin
  -- Oyun bittiyse "sıra" yok. (submit_move bitişte current'ı yine ilerletir
  -- ve online_games.status'u AYNI transaction'da SONRA günceller — o yüzden
  -- karar status'tan değil NEW.is_game_over'dan okunuyor.)
  if new.is_game_over then
    return new;
  end if;
  -- `update of current` kolon listesi değeri DEĞİŞMEDEN de tetiklenir
  -- (Postgres, SET listesine bakar) — check_turn_timeout'un
  -- `v_next := v_current` dalı bu satırla eleniyor.
  if new.current = old.current then
    return new;
  end if;

  select og.slots -> new.current into v_slot
  from public.online_games og
  where og.id = new.online_game_id and og.status = 'active';

  -- Koltuk YZ ise, oyun aktif değilse ya da kurucu hesabını silmişse
  -- (user_id null — account-deletion kaskadı) sessizce çık.
  if v_slot is null or v_slot->>'type' <> 'human' then
    return new;
  end if;
  v_target := nullif(v_slot->>'user_id', '')::uuid;
  if v_target is null then
    return new;
  end if;

  -- Spam bastırması (yukarıdaki tuzak b).
  if exists (
    select 1 from public.online_game_moves m
    where m.online_game_id = new.online_game_id
      and m.player_user_id = v_target
      and m.created_at > now() - interval '10 minutes'
  ) then
    return new;
  end if;

  perform net.http_post(
    url := 'https://xvqlizifakkkoqahaxsg.supabase.co/functions/v1/notify-your-turn',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object('online_game_id', new.online_game_id)
  );

  return new;
end;
$function$;

revoke all on function public._notify_your_turn() from public, anon, authenticated;

drop trigger if exists online_game_states_notify_turn on public.online_game_states;
create trigger online_game_states_notify_turn
  after update of current on public.online_game_states
  for each row execute function public._notify_your_turn();

comment on function public._notify_your_turn() is
  'Sıra devrinde (current ilerleyince) sırası gelen İNSAN oyuncuya '
  '"sıra sende" push''u tetikler (notify-your-turn Edge Function''ı, '
  'pg_net ile). Hedef son 10 dk içinde hamle yaptıysa bastırılır.';
