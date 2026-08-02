-- Kelimeki — Oyun İçi Mesajlaşma, Faz 2: kişiyi rapor etme. Tekrar tekrar
-- gönderilebilir (append-only, "zaten raporlandı" engeli yok — her satır
-- ayrı bir vaka). Rapor etmek otomatik olarak hedefi de sessize alır
-- (report_online_game_participant RPC'si, aynı transaction'da bir mute
-- satırı da ekler) — arayüzde bayrak rozeti Zzz rozetinin yerini alır.
--
-- `withdrawn_at`: raporu gönderen kişi sonradan vazgeçebilir
-- (withdraw_online_game_chat_reports RPC'si) — bu durumda admin'in
-- gördüğü satır "Geri Çekildi" statüsüne döner (handled da otomatik true
-- olur, admin ayrıca "okundu" işaretlemesine gerek kalmaz) ama satırın
-- kendisi SİLİNMEZ, kalıcı bir kayıt olarak durur. Raporlanan kişi bunu
-- (raporun kendisini olduğu gibi) hiçbir zaman görmez — bkz. yukarıdaki
-- "karşı tarafa yansımıyor" ilkesi, mutes tablosuyla aynı.
create table public.online_game_chat_reports (
  id               uuid primary key default gen_random_uuid(),
  online_game_id   uuid not null references public.online_games (id) on delete cascade,
  reporter_user_id uuid not null references auth.users (id),
  reported_user_id uuid not null references auth.users (id),
  reason           text not null,
  created_at       timestamptz not null default now(),
  handled          boolean not null default false,
  withdrawn_at     timestamptz,
  constraint online_game_chat_reports_not_self check (reporter_user_id <> reported_user_id),
  constraint online_game_chat_reports_reason_len check (char_length(reason) between 1 and 500)
);

create index online_game_chat_reports_created_at_idx on public.online_game_chat_reports (created_at desc);

alter table public.online_game_chat_reports enable row level security;

-- Kullanıcı yalnızca KENDİ gönderdiği raporları görebilir (rozet mantığı
-- için — "bu kişiye karşı aktif bir raporum var mı" sorgusu); admin her
-- şeyi görür. Doğrudan insert client'tan yapılmaz (yalnızca RPC üzerinden,
-- sessize alma ile atomik olması için) — insert policy'si yine de
-- SECURITY DEFINER RPC'nin auth.uid() bağlamında (invoker değil, ama RPC
-- kendi içinde auth.uid() kontrolü yaptığından) çalışmasını sağlıyor.
create policy online_game_chat_reports_select_own on public.online_game_chat_reports
  for select using (reporter_user_id = auth.uid());

create policy online_game_chat_reports_select_admin on public.online_game_chat_reports
  for select using (public.is_admin());

create policy online_game_chat_reports_insert_own on public.online_game_chat_reports
  for insert with check (
    reporter_user_id = auth.uid()
    and public.is_online_game_participant(online_game_id, auth.uid())
    and public.is_online_game_participant(online_game_id, reported_user_id)
  );

-- Ne raporu gönderen (withdraw hariç, o ayrı bir RPC) ne admin (handled
-- toggle hariç, o da ayrı bir RPC) satırı doğrudan güncelleyemez — hem
-- withdraw hem handled-toggle SECURITY DEFINER RPC'ler üzerinden gidiyor,
-- ham `update` GRANT'i authenticated'e bilerek verilmiyor (feedback
-- tablosundaki gibi düz `update` grant'inden daha sıkı bir model —
-- moderasyon verisi olduğundan bilinçli bir tercih).
revoke all on public.online_game_chat_reports from public, anon;
grant select, insert on public.online_game_chat_reports to authenticated;
