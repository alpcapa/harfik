-- Kelimeki — Oyun İçi Mesajlaşma, Faz 2: sessize alma / raporlama / rapor
-- geri çekme RPC'leri + admin okuma RPC'leri.

-- ── mute_online_game_participant ────────────────────────────────────────────
-- p_muted=true: upsert (idempotent mute). p_muted=false: unmute (delete).
-- Rapor edilmiş biri de bu şekilde "unmute" edilebilir (checkbox kapatılır)
-- — rozet o zaman raporun kalıcılığı yüzünden yine de bayrak olarak kalır
-- (bkz. admin_list_chat_reports / client-side rozet mantığı: bayrak AKTİF
-- bir rapor varlığına bakar, mute tablosuna değil).
create or replace function public.mute_online_game_participant(
  p_game_id uuid,
  p_target_user_id uuid,
  p_muted boolean
) returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Oturum açık değil.';
  end if;
  if p_target_user_id = auth.uid() then
    raise exception 'Kendinizi sessize alamazsınız.';
  end if;
  if not public.is_online_game_participant(p_game_id, auth.uid())
     or not public.is_online_game_participant(p_game_id, p_target_user_id) then
    raise exception 'Geçersiz oyun/katılımcı.';
  end if;

  if p_muted then
    insert into public.online_game_message_mutes (online_game_id, muter_user_id, muted_user_id)
    values (p_game_id, auth.uid(), p_target_user_id)
    on conflict (online_game_id, muter_user_id, muted_user_id) do nothing;
  else
    delete from public.online_game_message_mutes
    where online_game_id = p_game_id
      and muter_user_id = auth.uid()
      and muted_user_id = p_target_user_id;
  end if;
end;
$$;

revoke all on function public.mute_online_game_participant(uuid, uuid, boolean) from public, anon;
grant execute on function public.mute_online_game_participant(uuid, uuid, boolean) to authenticated;

-- ── report_online_game_participant ──────────────────────────────────────────
-- Rapor satırı ekler VE hedefi otomatik sessize alır (tek transaction,
-- atomik) — ürün kararı: "rapor = her zaman + mute", tek ikon (bayrak)
-- gösterilsin diye. Aynı kişi için daha önce raporlar olsa da (geri
-- çekilmiş ya da hâlâ aktif) yeni bir satır olarak eklenir — "tekrar tekrar
-- gönderilebilir" kuralı.
create or replace function public.report_online_game_participant(
  p_game_id uuid,
  p_target_user_id uuid,
  p_reason text
) returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_reason text := trim(p_reason);
begin
  if auth.uid() is null then
    raise exception 'Oturum açık değil.';
  end if;
  if p_target_user_id = auth.uid() then
    raise exception 'Kendinizi rapor edemezsiniz.';
  end if;
  if char_length(v_reason) = 0 or char_length(v_reason) > 500 then
    raise exception 'Rapor nedeni 1-500 karakter arasında olmalı.';
  end if;
  if not public.is_online_game_participant(p_game_id, auth.uid())
     or not public.is_online_game_participant(p_game_id, p_target_user_id) then
    raise exception 'Geçersiz oyun/katılımcı.';
  end if;

  insert into public.online_game_chat_reports (online_game_id, reporter_user_id, reported_user_id, reason)
  values (p_game_id, auth.uid(), p_target_user_id, v_reason);

  insert into public.online_game_message_mutes (online_game_id, muter_user_id, muted_user_id)
  values (p_game_id, auth.uid(), p_target_user_id)
  on conflict (online_game_id, muter_user_id, muted_user_id) do nothing;
end;
$$;

revoke all on function public.report_online_game_participant(uuid, uuid, text) from public, anon;
grant execute on function public.report_online_game_participant(uuid, uuid, text) to authenticated;

-- ── withdraw_online_game_chat_reports ───────────────────────────────────────
-- Raporu gönderen kişi vazgeçebilir — bu kişiye karşı benim (bu oyundaki)
-- TÜM açık (withdrawn_at is null) raporlarımı tek seferde kapatır. Sessize
-- alma bundan ETKİLENMEZ (bilerek bağımsız — spam sebebiyle sessize almış
-- olabilir, rapor sebebiyle değil); isterlerse ayrıca
-- mute_online_game_participant(..., false) ile ayrıca kaldırırlar.
create or replace function public.withdraw_online_game_chat_reports(
  p_game_id uuid,
  p_target_user_id uuid
) returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Oturum açık değil.';
  end if;

  update public.online_game_chat_reports
  set withdrawn_at = now(), handled = true
  where online_game_id = p_game_id
    and reporter_user_id = auth.uid()
    and reported_user_id = p_target_user_id
    and withdrawn_at is null;
end;
$$;

revoke all on function public.withdraw_online_game_chat_reports(uuid, uuid) from public, anon;
grant execute on function public.withdraw_online_game_chat_reports(uuid, uuid) to authenticated;

-- ── admin_list_chat_reports ──────────────────────────────────────────────────
-- Flags sekmesi için — raporlayan/raporlanan isimlerini de birlikte döner
-- (admin_list_members'ın profiles join deseninin küçük bir versiyonu) ki
-- Admin panelinde ayrı bir üye sorgusu gerekmesin.
create or replace function public.admin_list_chat_reports()
  returns table (
    id uuid,
    online_game_id uuid,
    reporter_user_id uuid,
    reporter_name text,
    reported_user_id uuid,
    reported_name text,
    reason text,
    created_at timestamptz,
    handled boolean,
    withdrawn_at timestamptz,
    game_finished boolean
  )
  language plpgsql
  stable
  security definer
  set search_path = public, auth
  as $$
begin
  if not public.is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select
    r.id,
    r.online_game_id,
    r.reporter_user_id,
    coalesce(rp.display_name, rp.first_name, 'Oyuncu'),
    r.reported_user_id,
    coalesce(tp.display_name, tp.first_name, 'Oyuncu'),
    r.reason,
    r.created_at,
    r.handled,
    r.withdrawn_at,
    exists (select 1 from public.games g where g.online_game_id = r.online_game_id)
  from public.online_game_chat_reports r
  left join public.profiles rp on rp.id = r.reporter_user_id
  left join public.profiles tp on tp.id = r.reported_user_id
  order by r.created_at desc;
end;
$$;

revoke all on function public.admin_list_chat_reports() from public, anon;
grant execute on function public.admin_list_chat_reports() to authenticated;

-- ── admin_mark_chat_report_handled ───────────────────────────────────────────
create or replace function public.admin_mark_chat_report_handled(p_id uuid, p_handled boolean)
  returns void
  language plpgsql
  security definer
  set search_path = public, auth
  as $$
begin
  if not public.is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  update public.online_game_chat_reports set handled = p_handled where id = p_id;
end;
$$;

revoke all on function public.admin_mark_chat_report_handled(uuid, boolean) from public, anon;
grant execute on function public.admin_mark_chat_report_handled(uuid, boolean) to authenticated;

-- ── admin_get_finished_game_chat ─────────────────────────────────────────────
-- Yalnızca BİTMİŞ oyunlar için: games.messages zaten oyun bittiğinde
-- _finish_online_game_records tarafından donduruluyor (bkz.
-- 20260731105039). games tablosu yalnızca biten oyunları tuttuğundan, bir
-- online_game_id için satır bulunması "oyun bitti" ile eşdeğer. Her insan
-- katılımcı satırı aynı messages kopyasını taşıdığından `limit 1` yeterli.
-- Bitmemiş bir oyun için boş dizi döner (v1 kapsamı bilerek bu kadar —
-- canlı/bitmemiş oyun dökümü admin'e gösterilmiyor).
create or replace function public.admin_get_finished_game_chat(p_online_game_id uuid)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public, auth
  as $$
declare
  v_messages jsonb;
begin
  if not public.is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  select g.messages into v_messages
  from public.games g
  where g.online_game_id = p_online_game_id
  limit 1;

  return coalesce(v_messages, '[]'::jsonb);
end;
$$;

revoke all on function public.admin_get_finished_game_chat(uuid) from public, anon;
grant execute on function public.admin_get_finished_game_chat(uuid) to authenticated;
