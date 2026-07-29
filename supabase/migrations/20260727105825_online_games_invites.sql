-- Canlı (online) oyun — 2. faz: davet + kabul akışı için veri katmanı.
-- Henüz gerçek zamanlı senkron oynanış yok (Faz 3); bu migration yalnızca
-- "kim kiminle oynayacak" kurulumunu ve davet durumunu saklar.

-- ── ONLINE_GAMES ─────────────────────────────────────────────────────────────
-- slots: player_count uzunluğunda bir dizi, her eleman ya
-- {"type":"human","user_id":"<uuid>"} ya da {"type":"ai"}. Sıra sabittir ve
-- src/game/constants.ts'teki cornersFor ile eşleşir (index 0 = oluşturan,
-- her zaman slot 0'da human olarak kendini gösterir).
create table public.online_games (
  id           uuid primary key default gen_random_uuid (),
  created_by   uuid not null references auth.users (id) on delete cascade,
  player_count int not null check (player_count in (2, 4)),
  status       text not null default 'pending' check (status in ('pending', 'active', 'finished', 'abandoned')),
  slots        jsonb not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.online_games is 'Canlı oyun kurulumu — kurucu, oyuncu sayısı, koltuk kompozisyonu (arkadaş/YZ) ve durum. Gerçek oyun state''i (tahta/raf/skor) Faz 3''te eklenecek.';
comment on column public.online_games.slots is 'player_count uzunluğunda dizi: {"type":"human","user_id":uuid} | {"type":"ai"}. index 0 = oluşturan.';

create index online_games_created_by_idx on public.online_games (created_by);

-- RLS bu bölümün sonunda, game_invites de oluşturulduktan sonra etkinleştiriliyor
-- (online_games'in select politikası game_invites'a referans veriyor).

-- ── GAME_INVITES ─────────────────────────────────────────────────────────────
create table public.game_invites (
  id             uuid primary key default gen_random_uuid (),
  online_game_id uuid not null references public.online_games (id) on delete cascade,
  invitee_id     uuid not null references auth.users (id) on delete cascade,
  status         text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at     timestamptz not null default now(),
  responded_at   timestamptz,
  unique (online_game_id, invitee_id)
);

comment on table public.game_invites is 'Bir online_games satırındaki her insan koltuğu için ayrı davet satırı. friend_requests''teki istek/kabul deseniyle tutarlı.';

create index game_invites_invitee_id_idx on public.game_invites (invitee_id);

-- ── RLS — her iki tablo için (online_games'in select politikası game_invites'a
-- referans verdiğinden ikisi de var olduktan sonra ekleniyor) ──────────────────

alter table public.online_games enable row level security;

create policy online_games_select_party on public.online_games
  for select using (
    auth.uid() = created_by
    or exists (
      select 1 from public.game_invites gi
      where gi.online_game_id = online_games.id and gi.invitee_id = auth.uid()
    )
  );

create policy online_games_insert_self on public.online_games
  for insert with check (auth.uid() = created_by);

-- Doğrudan client update'i yalnızca kurucuya (ör. ileride iptal) açık;
-- pending→active geçişi respond_to_game_invite RPC'si (security definer,
-- RLS'i bypass eder) tarafından yapılır.
create policy online_games_update_creator on public.online_games
  for update using (auth.uid() = created_by);

create policy online_games_delete_creator on public.online_games
  for delete using (auth.uid() = created_by);

alter table public.game_invites enable row level security;

create policy game_invites_select_party on public.game_invites
  for select using (
    auth.uid() = invitee_id
    or exists (
      select 1 from public.online_games og
      where og.id = game_invites.online_game_id and og.created_by = auth.uid()
    )
  );

create policy game_invites_insert_creator on public.game_invites
  for insert with check (
    exists (
      select 1 from public.online_games og
      where og.id = online_game_id and og.created_by = auth.uid()
    )
  );

-- Kabul/red: yalnızca davetli, yalnızca pending'ten.
create policy game_invites_update_invitee on public.game_invites
  for update
  using (auth.uid() = invitee_id and status = 'pending')
  with check (auth.uid() = invitee_id and status in ('accepted', 'declined'));

-- Kurucu, henüz cevaplanmamış bir daveti iptal edebilir (oyunu tamamen
-- silmeden tek bir koltuğu geri almak isterse — 4. faz'a kadar UI'da
-- kullanılmayabilir ama data katmanında tutarlılık için var).
create policy game_invites_delete_creator on public.game_invites
  for delete using (
    status = 'pending'
    and exists (
      select 1 from public.online_games og
      where og.id = online_game_id and og.created_by = auth.uid()
    )
  );

-- ── RPC'ler ──────────────────────────────────────────────────────────────────

-- Yeni bir Canlı oyun kurar. p_slots, index 0'ı oluşturanın kendisi olacak
-- şekilde tam kompozisyonu taşır (insan koltukları için user_id, YZ
-- koltukları için sadece type:'ai'). İnsan koltuklarındaki her arkadaş için
-- bir game_invites satırı açılır; hiç insan davetlisi yoksa (herkes YZ)
-- oyun beklemeden doğrudan 'active' olur.
create or replace function public.create_online_game(p_player_count int, p_slots jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_game_id uuid;
  v_slot jsonb;
  v_slot_type text;
  v_slot_user uuid;
  v_seen_users uuid[] := array[]::uuid[];
  v_pending_invites int := 0;
begin
  if v_uid is null then
    raise exception 'Oturum açık değil.';
  end if;
  if p_player_count not in (2, 4) then
    raise exception 'Geçersiz oyuncu sayısı.';
  end if;
  if jsonb_array_length(p_slots) <> p_player_count then
    raise exception 'Koltuk sayısı oyuncu sayısıyla eşleşmiyor.';
  end if;

  v_slot := p_slots -> 0;
  if (v_slot ->> 'type') <> 'human' or (v_slot ->> 'user_id')::uuid <> v_uid then
    raise exception 'İlk koltuk oyunu kuran kişi olmalı.';
  end if;

  for i in 0 .. jsonb_array_length(p_slots) - 1 loop
    v_slot := p_slots -> i;
    v_slot_type := v_slot ->> 'type';
    if v_slot_type not in ('human', 'ai') then
      raise exception 'Geçersiz koltuk türü.';
    end if;

    if v_slot_type = 'human' then
      v_slot_user := (v_slot ->> 'user_id')::uuid;
      if v_slot_user is null then
        raise exception 'İnsan koltuğunda user_id eksik.';
      end if;
      if v_slot_user = any (v_seen_users) then
        raise exception 'Aynı kullanıcı birden fazla koltukta olamaz.';
      end if;
      v_seen_users := v_seen_users || v_slot_user;

      if v_slot_user <> v_uid and not exists (
        select 1 from public.friend_requests fr
        where fr.status = 'accepted'
          and ((fr.user_id = v_uid and fr.friend_id = v_slot_user)
            or (fr.user_id = v_slot_user and fr.friend_id = v_uid))
      ) then
        raise exception 'Yalnızca arkadaşlarını davet edebilirsin.';
      end if;
    end if;
  end loop;

  insert into public.online_games (created_by, player_count, slots)
  values (v_uid, p_player_count, p_slots)
  returning id into v_game_id;

  for i in 0 .. jsonb_array_length(p_slots) - 1 loop
    v_slot := p_slots -> i;
    if (v_slot ->> 'type') = 'human' and (v_slot ->> 'user_id')::uuid <> v_uid then
      insert into public.game_invites (online_game_id, invitee_id)
      values (v_game_id, (v_slot ->> 'user_id')::uuid);
      v_pending_invites := v_pending_invites + 1;
    end if;
  end loop;

  if v_pending_invites = 0 then
    update public.online_games set status = 'active', updated_at = now() where id = v_game_id;
  end if;

  return v_game_id;
end;
$$;

revoke all on function public.create_online_game(int, jsonb) from public, anon;
grant execute on function public.create_online_game(int, jsonb) to authenticated;

-- Kendi taraf olduğun (kurduğun ya da davet edildiğin) tüm Canlı oyunları
-- listeler; kendi rolünü ve (davetliysen) kendi davet durumunu da döner.
create or replace function public.list_my_online_games()
returns table (
  id uuid,
  created_by uuid,
  player_count int,
  status text,
  slots jsonb,
  created_at timestamptz,
  my_role text,
  my_invite_status text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    og.id, og.created_by, og.player_count, og.status, og.slots, og.created_at,
    case when og.created_by = auth.uid() then 'creator' else 'invitee' end as my_role,
    gi.status as my_invite_status
  from public.online_games og
  left join public.game_invites gi
    on gi.online_game_id = og.id and gi.invitee_id = auth.uid()
  where og.created_by = auth.uid()
     or exists (
       select 1 from public.game_invites gi2
       where gi2.online_game_id = og.id and gi2.invitee_id = auth.uid()
     )
  order by og.created_at desc;
$$;

revoke all on function public.list_my_online_games() from public, anon;
grant execute on function public.list_my_online_games() to authenticated;

-- Bir daveti kabul/red eder. Kabul edilince, o oyundaki TÜM davetler artık
-- accepted ise oyun 'active'e geçer (henüz gerçek oynanış başlamaz, Faz 3).
create or replace function public.respond_to_game_invite(p_invite_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_game_id uuid;
  v_remaining_pending int;
begin
  if v_uid is null then
    raise exception 'Oturum açık değil.';
  end if;

  select online_game_id into v_game_id
  from public.game_invites
  where id = p_invite_id and invitee_id = v_uid and status = 'pending';

  if v_game_id is null then
    raise exception 'Davet bulunamadı ya da zaten yanıtlanmış.';
  end if;

  update public.game_invites
    set status = case when p_accept then 'accepted' else 'declined' end,
        responded_at = now()
    where id = p_invite_id;

  if p_accept then
    select count(*) into v_remaining_pending
    from public.game_invites
    where online_game_id = v_game_id and status = 'pending';

    if v_remaining_pending = 0 then
      update public.online_games
        set status = 'active', updated_at = now()
        where id = v_game_id and status = 'pending';
    end if;
  end if;
end;
$$;

revoke all on function public.respond_to_game_invite(uuid, boolean) from public, anon;
grant execute on function public.respond_to_game_invite(uuid, boolean) to authenticated;
