-- Canlı (online) oyun — 3. faz, 1. adım: gerçek zamanlı senkron oynanış için
-- state şeması. Bu migration yalnızca tabloları/RLS'i kurar — init/submit_move
-- RPC'leri (2. ve 3. adım) henüz yok, bu yüzden tablolar şu an hiçbir yerden
-- yazılmıyor.
--
-- Üç tabloya bilinçli olarak bölündü:
--   1) online_game_states — herkese (katılımcılara) açık, Realtime'a
--      abone olunacak "kamuya güvenli" state (tahta, sıra, skorlar...).
--      RAF İÇERMEZ.
--   2) online_game_secrets — bag + her koltuğun rafı. RLS açık ama HİÇBİR
--      role (anon/authenticated) grant verilmedi — yalnızca ileride yazılacak
--      security definer RPC'ler (init_online_game/submit_move/get_my_rack)
--      erişebilir. Realtime replication'da asla görünmeyecek şekilde ayrı
--      tabloya konuldu (aksi halde participant'lara SELECT açmak zorunda
--      kalıp rakibin rafını da göndermiş olurduk).
--   3) online_game_moves — ek/append-only hamle geçmişi (audit log). Hem
--      geçmiş ekranı hem anti-hile analizinde kullanılacak; hard check
--      constraint'lerle (rack boyutu, joker sayısı, puan tavanı) bariz
--      sunucu-dışı/bozulmuş veriye baştan izin vermiyor. Gerçek hamle
--      doğrulaması hâlâ client-side (validator.ts) kalacak — bu constraint'ler
--      onun yerine geçmez, yalnızca bariz saçma değerleri (ör. tek hamlede
--      9 taş ya da 50000 puan) veritabanı seviyesinde engelleyen bir güvenlik
--      ağı.

-- ── Ortak yardımcı: bir kullanıcı bir Canlı oyunun katılımcısı mı? ───────────
-- "Katılımcı" = kurucu YA DA daveti accepted olan davetli (declined/pending
-- olanlar state'i göremez — zaten online_games yalnızca tüm davetler kabul
-- edilince 'active'e geçiyor). RLS policy'leri içinde tekrar tekrar aynı
-- subquery'i yazmamak için tek yerde tanımlandı.
create or replace function public.is_online_game_participant(p_game_id uuid, p_uid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select p_uid is not null and exists (
    select 1 from public.online_games og
    where og.id = p_game_id
      and (
        og.created_by = p_uid
        or exists (
          select 1 from public.game_invites gi
          where gi.online_game_id = og.id and gi.invitee_id = p_uid and gi.status = 'accepted'
        )
      )
  );
$$;

revoke all on function public.is_online_game_participant(uuid, uuid) from public, anon;
grant execute on function public.is_online_game_participant(uuid, uuid) to authenticated;

-- ── ONLINE_GAME_STATES ───────────────────────────────────────────────────────
create table public.online_game_states (
  online_game_id     uuid primary key references public.online_games (id) on delete cascade,
  board              jsonb not null,
  bonuses            jsonb not null default '{}'::jsonb,
  -- Player[] ama rack YOK — her oyuncu için yalnızca rack_count (kaç taşı
  -- kaldığı, kart/rakip UI'ında görünür olması gereken tek bilgi).
  players            jsonb not null,
  current            int not null default 0 check (current between 0 and 3),
  turn_count         int not null default 0,
  consecutive_passes int not null default 0,
  is_game_over       boolean not null default false,
  end_reason         text check (end_reason in ('normal', 'surrender')),
  last_move_cells    jsonb not null default '[]'::jsonb,
  bag_count          int not null default 0 check (bag_count >= 0),
  started_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.online_game_states is 'Canlı oyunun katılımcılara açık, rack içermeyen anlık state''i — Realtime aboneliğinin temeli. Yazma yalnızca ileride eklenecek security definer RPC''ler üzerinden (init_online_game/submit_move).';
comment on column public.online_game_states.players is 'Player[] (src/game/types.ts) ama her elemanda rack yerine rack_count var — rakibin elindeki harfler bu tablodan asla okunamaz.';

alter table public.online_game_states enable row level security;

create policy online_game_states_select_party on public.online_game_states
  for select using (public.is_online_game_participant(online_game_id, auth.uid()));

revoke all on public.online_game_states from public, anon;
grant select on public.online_game_states to authenticated;

-- ── ONLINE_GAME_SECRETS ──────────────────────────────────────────────────────
-- Bilinçli olarak anon/authenticated'e HİÇBİR grant verilmiyor (friend_requests
-- tarzı tam kilitli tablo deseni) — RLS burada ikinci bir savunma katmanı,
-- asıl engel table-level grant'in hiç olmaması. Yalnızca security definer
-- RPC'ler (tablo sahibi olarak çalıştıklarından grant'e tabi değiller)
-- okuyabilir/yazabilir.
create table public.online_game_secrets (
  online_game_id uuid primary key references public.online_games (id) on delete cascade,
  bag            jsonb not null,
  -- player_count uzunluğunda dizi, slots ile aynı sırada — insan koltuğu için
  -- Tile[], YZ koltuğu için de Tile[] (YZ turunu hesaplayan client aynı
  -- RPC yolundan okuyacak, ayrı bir kod yolu açmamak için).
  racks          jsonb not null,
  updated_at     timestamptz not null default now()
);

comment on table public.online_game_secrets is 'Bag + tüm koltukların rafı — hiçbir client rolüne (anon/authenticated) grant verilmedi, yalnızca security definer RPC''ler erişebilir. Realtime''a hiç dahil edilmeyecek.';

alter table public.online_game_secrets enable row level security;

-- ── ONLINE_GAME_MOVES ────────────────────────────────────────────────────────
create table public.online_game_moves (
  id                  uuid primary key default gen_random_uuid (),
  online_game_id      uuid not null references public.online_games (id) on delete cascade,
  turn                int not null check (turn >= 1),
  player_index        int not null check (player_index between 0 and 3),
  -- YZ hamlelerinde null.
  player_user_id      uuid references auth.users (id),
  action              text not null check (action in ('play', 'pass', 'exchange', 'surrender')),
  words               jsonb not null default '[]'::jsonb,
  word_scores         jsonb,
  points              int not null default 0,
  -- HistoryEntry.lostShares ile aynı şekil: [{"to":<player_index>,"amount":<int>}].
  lost_shares         jsonb,
  tile_count          int not null default 0,
  -- 'play' hamlesinde konan taşlar: [{"r":int,"c":int,"letter":str,"wild":bool,"wildLetter":str}].
  placements          jsonb,
  finish_joker_count  int not null default 0,
  bingo               boolean not null default false,
  created_at          timestamptz not null default now(),

  -- ── Hard anti-hile guardrail'leri ──────────────────────────────────────
  -- Gerçek hamle doğrulaması hâlâ client-side (validator.ts); bunlar yalnızca
  -- bariz/bozulmuş değerleri veritabanı seviyesinde reddeden bir güvenlik ağı.
  constraint online_game_moves_tile_count_range check (tile_count between 0 and 7), -- RACK_SIZE
  constraint online_game_moves_joker_range check (finish_joker_count between 0 and 2), -- torbadaki toplam joker
  constraint online_game_moves_points_sane check (points between 0 and 1500), -- gerçekçi tavanın kat kat üstü, sanity ceiling
  constraint online_game_moves_placements_len check (jsonb_array_length(coalesce(placements, '[]'::jsonb)) <= 7),
  constraint online_game_moves_action_shape check (
    (action = 'play' and tile_count between 1 and 7)
    or (action = 'exchange' and tile_count between 1 and 7 and points = 0 and bingo = false and finish_joker_count = 0)
    or (action in ('pass', 'surrender') and tile_count = 0 and points = 0 and bingo = false and finish_joker_count = 0)
  )
);

comment on table public.online_game_moves is 'Ek/append-only hamle geçmişi (audit log) — oyun geçmişi ekranı + anti-hile analizi için. Yazma yalnızca ileride eklenecek submit_move RPC''si üzerinden.';

create index online_game_moves_game_turn_idx on public.online_game_moves (online_game_id, turn);

alter table public.online_game_moves enable row level security;

create policy online_game_moves_select_party on public.online_game_moves
  for select using (public.is_online_game_participant(online_game_id, auth.uid()));

revoke all on public.online_game_moves from public, anon;
grant select on public.online_game_moves to authenticated;
