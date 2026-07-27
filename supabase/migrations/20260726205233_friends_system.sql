-- Arkadaşlık sistemi — Canlı (online) oyun özelliğinin 1. fazı.
-- İki bağımsız yol: (A) mevcut bir Kelimeki kullanıcısını arayıp ekleme
-- (uygulama içi istek/kabul, e-posta YOK — maliyet ve gürültü yaratmasın
-- diye); (B) henüz üye olmayanlar dahil, kalıcı/reusable bir davet linkiyle
-- WhatsApp/SMS/DM gibi kanallardan davet etme — bize hiçbir e-posta
-- maliyeti çıkarmayan asıl kullanıcı kazanım mekanizması.

-- ── FRIEND_REQUESTS ─────────────────────────────────────────────────────────
-- Tek satır iki anlama gelir: pending iken "user_id, friend_id'ye istek
-- gönderdi", accepted iken (yön anlamsızlaşır) "ikisi arkadaş". "Arkadaş
-- mıyız" sorgusu her iki yönü de kontrol eder.
create table public.friend_requests (
  user_id      uuid not null references auth.users(id) on delete cascade,
  friend_id    uuid not null references auth.users(id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

comment on table public.friend_requests is 'Arkadaşlık istekleri/ilişkileri. status=accepted iken satırın yönü (kim önce istek attı) anlamsızdır, sadece geçmiş bilgisi olarak kalır.';

create index friend_requests_friend_id_idx on public.friend_requests (friend_id);

alter table public.friend_requests enable row level security;

-- Yalnızca ilişkinin iki tarafı da kendi satırını görebilir.
create policy friend_requests_select_own on public.friend_requests
  for select using (auth.uid() in (user_id, friend_id));

-- Yalnızca kendi adına istek gönderebilirsin.
create policy friend_requests_insert_self on public.friend_requests
  for insert with check (auth.uid() = user_id);

-- Kabul: yalnızca isteği ALAN taraf, yalnızca pending→accepted yönünde.
create policy friend_requests_update_addressee on public.friend_requests
  for update
  using (auth.uid() = friend_id and status = 'pending')
  with check (auth.uid() = friend_id and status = 'accepted');

-- Reddetme (pending sil), iptal (kendi gönderdiğini sil) ya da arkadaşlıktan
-- çıkarma (accepted sil) — ilişkinin her iki tarafı da silebilir.
create policy friend_requests_delete_either on public.friend_requests
  for delete using (auth.uid() in (user_id, friend_id));

-- Karşı taraftan zaten bekleyen bir istek varsa (A, B'ye atmışken B de A'ya
-- atmaya çalışırsa) yeni bir satır açmak yerine mevcut olanı doğrudan kabul
-- edilmiş say — iki taraflı "karşılıklı istek" durumunu sessizce çözer.
create or replace function public.handle_friend_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.friend_requests
    where user_id = new.friend_id and friend_id = new.user_id and status = 'pending'
  ) then
    update public.friend_requests
      set status = 'accepted', responded_at = now()
      where user_id = new.friend_id and friend_id = new.user_id;
    new.status := 'accepted';
    new.responded_at := now();
  end if;
  return new;
end;
$$;

create trigger friend_requests_before_insert
  before insert on public.friend_requests
  for each row execute function public.handle_friend_request_insert();

-- ── Arama, liste, istek RPC'leri ────────────────────────────────────────────
-- profiles.select RLS'i owner-or-admin'e kilitli (lock_down_profiles_games_select,
-- 22 Temmuz 2026) — başka kullanıcıların adını okumak için (leaderboard/
-- game_likers'daki aynı gerekçeyle) security definer gerekiyor. E-posta hiçbir
-- zaman döndürülmez (projenin genel ilkesi).

create or replace function public.search_users_for_friend(p_query text)
returns table(id uuid, name text, avatar_url text, relation text)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null then
    raise exception 'Oturum açık değil.';
  end if;
  if length(trim(p_query)) < 2 then
    return;
  end if;

  return query
    select
      p.id,
      coalesce(p.display_name, p.first_name) as name,
      p.avatar_url,
      case
        when fr.status = 'accepted' then 'accepted'
        when fr.user_id = auth.uid() then 'pending_outgoing'
        when fr.friend_id = auth.uid() then 'pending_incoming'
        else null
      end as relation
    from public.profiles p
    left join public.friend_requests fr
      on (fr.user_id = auth.uid() and fr.friend_id = p.id)
      or (fr.user_id = p.id and fr.friend_id = auth.uid())
    where p.id <> auth.uid()
      and (p.display_name ilike '%' || p_query || '%' or p.first_name ilike '%' || p_query || '%')
    order by name
    limit 20;
end;
$$;

revoke all on function public.search_users_for_friend(text) from public, anon;
grant execute on function public.search_users_for_friend(text) to authenticated;

create or replace function public.list_friends()
returns table(friend_id uuid, name text, avatar_url text, since timestamptz)
language sql
security definer
set search_path = public
stable
as $$
  select
    case when fr.user_id = auth.uid() then fr.friend_id else fr.user_id end as friend_id,
    coalesce(p.display_name, p.first_name) as name,
    p.avatar_url,
    fr.responded_at as since
  from public.friend_requests fr
  join public.profiles p
    on p.id = case when fr.user_id = auth.uid() then fr.friend_id else fr.user_id end
  where fr.status = 'accepted'
    and auth.uid() in (fr.user_id, fr.friend_id)
  order by fr.responded_at desc nulls last;
$$;

revoke all on function public.list_friends() from public, anon;
grant execute on function public.list_friends() to authenticated;

create or replace function public.list_incoming_friend_requests()
returns table(requester_id uuid, name text, avatar_url text, created_at timestamptz)
language sql
security definer
set search_path = public
stable
as $$
  select fr.user_id as requester_id,
         coalesce(p.display_name, p.first_name) as name,
         p.avatar_url,
         fr.created_at
  from public.friend_requests fr
  join public.profiles p on p.id = fr.user_id
  where fr.friend_id = auth.uid() and fr.status = 'pending'
  order by fr.created_at desc;
$$;

revoke all on function public.list_incoming_friend_requests() from public, anon;
grant execute on function public.list_incoming_friend_requests() to authenticated;

-- ── FRIEND_INVITE_LINKS ─────────────────────────────────────────────────────
-- Kalıcı/reusable kişisel davet linki — tek kullanımlık değil, kullanıcı
-- aynı linki istediği kadar kişiye/kanala (WhatsApp, SMS, DM) gönderebilir.
-- Her kullanıcının en fazla bir linki olur (inviter_id primary key).
create table public.friend_invite_links (
  inviter_id uuid primary key references auth.users(id) on delete cascade,
  token      text not null unique default encode(gen_random_bytes(9), 'hex'),
  created_at timestamptz not null default now(),
  use_count  int not null default 0
);

comment on table public.friend_invite_links is 'Kullanıcı başına kalıcı bir davet linki (token) — henüz üye olmayanlar dahil arkadaş kazanmak için (WhatsApp vb. paylaşım). Tek kullanımlık değil, tekrar tekrar paylaşılabilir.';

alter table public.friend_invite_links enable row level security;

create policy friend_invite_links_select_own on public.friend_invite_links
  for select using (auth.uid() = inviter_id);

create or replace function public.create_friend_invite_link()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
begin
  if v_uid is null then
    raise exception 'Oturum açık değil.';
  end if;

  select token into v_token from public.friend_invite_links where inviter_id = v_uid;
  if v_token is not null then
    return v_token;
  end if;

  insert into public.friend_invite_links (inviter_id) values (v_uid)
  returning token into v_token;
  return v_token;
end;
$$;

revoke all on function public.create_friend_invite_link() from public, anon;
grant execute on function public.create_friend_invite_link() to authenticated;

-- Girişsiz de çağrılabilir — /davet/:token sayfasının kayıt/giriş öncesi
-- "X seni davet ediyor" önizlemesi için.
create or replace function public.get_friend_invite_info(p_token text)
returns table(inviter_name text)
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(p.display_name, p.first_name, 'Bir kullanıcı')
  from public.friend_invite_links fil
  join public.profiles p on p.id = fil.inviter_id
  where fil.token = p_token;
$$;

revoke all on function public.get_friend_invite_info(text) from public;
grant execute on function public.get_friend_invite_info(text) to anon, authenticated;

-- profiles.invited_by — büyüme takibi için (ilk temas, bir daha değişmez).
-- guest_visits.utm_source'un ilk-temas ilkesiyle aynı mantık; ileride admin
-- panelinde "arkadaş daveti ile gelen kayıt" metriği için kullanılabilir.
alter table public.profiles add column invited_by uuid references auth.users(id) on delete set null;
comment on column public.profiles.invited_by is 'Bu kullanıcı bir arkadaş davet linkiyle katıldıysa, linki oluşturan kullanıcı (ilk temas, tekrar değişmez).';

-- Linki tıklayıp (girişli olarak) kabul eder: arkadaşlık kaydını doğrudan
-- accepted olarak açar/günceller (tıklama zaten bilinçli bir onaydır, ayrıca
-- pending beklemeye gerek yok), use_count'u artırır, invited_by'ı (ilk kez
-- ise) doldurur.
create or replace function public.accept_friend_invite(p_token text)
returns table(inviter_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_inviter uuid;
begin
  if v_uid is null then
    raise exception 'Oturum açık değil.';
  end if;

  select fil.inviter_id into v_inviter
  from public.friend_invite_links fil
  where fil.token = p_token;

  if v_inviter is null then
    raise exception 'Geçersiz davet linki.';
  end if;

  if v_inviter = v_uid then
    raise exception 'Kendi linkinle arkadaş olamazsın.';
  end if;

  if exists (
    select 1 from public.friend_requests
    where (user_id = v_inviter and friend_id = v_uid) or (user_id = v_uid and friend_id = v_inviter)
  ) then
    update public.friend_requests
      set status = 'accepted', responded_at = now()
      where (user_id = v_inviter and friend_id = v_uid) or (user_id = v_uid and friend_id = v_inviter);
  else
    insert into public.friend_requests (user_id, friend_id, status, responded_at)
    values (v_inviter, v_uid, 'accepted', now());
  end if;

  update public.friend_invite_links set use_count = use_count + 1 where inviter_id = v_inviter;
  update public.profiles set invited_by = v_inviter where id = v_uid and invited_by is null;

  return query select coalesce(p.display_name, p.first_name, 'Bir kullanıcı') from public.profiles p where p.id = v_inviter;
end;
$$;

revoke all on function public.accept_friend_invite(text) from public, anon;
grant execute on function public.accept_friend_invite(text) to authenticated;
