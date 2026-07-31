-- Kelimeki — Oyun İçi Mesajlaşma, Faz 1 (yalnızca Canlı/online multiplayer
-- oyunlar — Yapay Zeka'ya karşı yerel oyunlarda tek insan oyuncu olduğundan
-- "gruba mesaj" kavramı anlamsız, bu yüzden kapsam dışı bırakıldı).
--
-- Mimari, mevcut üç parçalı Canlı state deseniyle (online_game_states/
-- online_game_secrets/online_game_moves) aynı: yeni, bağımsız bir
-- `online_game_messages` tablosu — katılımcılar select edebilir,
-- yazma (insert) da RPC'siz doğrudan RLS ile (gönderen kendi user_id'siyle
-- ve katılımcı olarak). `is_online_game_participant` (mevcut, bkz.
-- 20260728080626_online_game_state_schema.sql) aynen yeniden kullanılıyor.
--
-- Bitmiş bir oyunun sohbet kaydı `games.messages` jsonb'sine dondurulacak
-- (bkz. bir sonraki migration, _finish_online_game_records güncellemesi) —
-- board_snapshot'la birebir aynı desen. `message_count`, `fetchMyGames`'in
-- liste sorgusunu şişirmesin diye (board_snapshot'ın lazy-load edilme
-- gerekçesiyle aynı) generated bir sütun: liste tam mesaj içeriğini değil
-- yalnızca bu sayaçla "sohbet rozeti gösterilsin mi" kararını verir.

create table public.online_game_messages (
  id              uuid primary key default gen_random_uuid(),
  online_game_id  uuid not null references public.online_games (id) on delete cascade,
  sender_user_id  uuid not null references auth.users (id),
  message         text not null,
  created_at      timestamptz not null default now(),
  constraint online_game_messages_len check (char_length(message) between 1 and 200)
);

create index online_game_messages_game_idx on public.online_game_messages (online_game_id, created_at);

alter table public.online_game_messages enable row level security;

create policy online_game_messages_select_party on public.online_game_messages
  for select using (public.is_online_game_participant(online_game_id, auth.uid()));

create policy online_game_messages_insert_self on public.online_game_messages
  for insert with check (
    sender_user_id = auth.uid()
    and public.is_online_game_participant(online_game_id, auth.uid())
  );

revoke all on public.online_game_messages from public, anon;
grant select, insert on public.online_game_messages to authenticated;

-- Gerçek zamanlı popup/thread güncellemesi için Realtime'a eklenir —
-- online_game_states ile aynı gerekçe (online_game_secrets'ın aksine burada
-- gizlenecek bir şey yok, mesaj içeriği zaten katılımcılara açık).
alter publication supabase_realtime add table public.online_game_messages;

alter table public.games add column if not exists messages jsonb;
alter table public.games add column if not exists message_count integer
  generated always as (jsonb_array_length(coalesce(messages, '[]'::jsonb))) stored;

comment on column public.games.messages is 'Bitmiş bir Canlı oyunun dondurulmuş sohbet kaydı — {name,colorIndex,message,created_at}[] (bkz. _finish_online_game_records). Yerel/YZ oyunlarında her zaman null.';
comment on column public.games.message_count is 'messages dizisinin uzunluğu — GameHistoryModal listesinin sohbet rozetini göstermek için tam içeriği çekmeden kullandığı sayaç.';
