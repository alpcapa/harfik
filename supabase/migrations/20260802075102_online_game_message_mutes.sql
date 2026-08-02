-- Kelimeki — Oyun İçi Mesajlaşma, Faz 2: kişiyi sessize alma. Sessize alma
-- mesajı GİZLEMEZ (tüm geçmiş herkese aynı kalır, ChatThread hiç
-- değişmiyor) — yalnızca alanın "yeni mesaj" popup'ını ve okunmamış
-- rozetini o gönderen için bastırır (bkz. OnlineGameScreen.tsx'teki
-- realtime insert handler'ı). Oyun bazlıdır (online_game_messages'la aynı
-- ölçek) — global/kalıcı bir "engelleme" DEĞİLDİR, başka bir Canlı oyunda
-- hiçbir etkisi yoktur.
create table public.online_game_message_mutes (
  online_game_id uuid not null references public.online_games (id) on delete cascade,
  muter_user_id  uuid not null references auth.users (id),
  muted_user_id  uuid not null references auth.users (id),
  created_at     timestamptz not null default now(),
  primary key (online_game_id, muter_user_id, muted_user_id),
  constraint online_game_message_mutes_not_self check (muter_user_id <> muted_user_id)
);

alter table public.online_game_message_mutes enable row level security;

-- Yalnızca kendi sessize alma kayıtlarını görebilir/ekleyebilir/silebilir —
-- friend_requests'in aksine tek yönlü bir ilişki, karşı taraf (sessize
-- alınan kişi) bu satırı ASLA göremez — "kimin sessize aldığı" bilerek
-- gizli kalıyor (bkz. ürün kararı: sessize alma/rapor tamamen tek taraflı,
-- karşı tarafa hiçbir şekilde yansımıyor).
create policy online_game_message_mutes_select_own on public.online_game_message_mutes
  for select using (muter_user_id = auth.uid());

create policy online_game_message_mutes_insert_own on public.online_game_message_mutes
  for insert with check (
    muter_user_id = auth.uid()
    and public.is_online_game_participant(online_game_id, auth.uid())
    and public.is_online_game_participant(online_game_id, muted_user_id)
  );

create policy online_game_message_mutes_delete_own on public.online_game_message_mutes
  for delete using (muter_user_id = auth.uid());

revoke all on public.online_game_message_mutes from public, anon;
grant select, insert, delete on public.online_game_message_mutes to authenticated;
