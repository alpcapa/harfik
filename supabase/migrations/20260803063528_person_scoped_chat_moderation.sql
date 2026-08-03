-- Sessize alma ve rapor durumunu OYUN bazlıdan KİŞİ bazlıya taşır.
--
-- Kullanıcı isteği: "ben A kişisini sessize almışsam veya report etmişsem, o
-- sürekli bir durum olmalı ve tekrar o kişi ile oyun oynadığımda mesaj
-- kutusunda stop sign veya bayrak çıkmalı". Faz 2'de (2 Ağustos 2026) mute
-- ve rapor bilinçli olarak tek bir Canlı oyuna özeldi — aynı kişiyle yeni bir
-- oyun açılınca her şey sıfırlanıyordu, yani "bu kişiyi susturmuştum"
-- kararını her oyunda baştan vermek gerekiyordu.
--
-- Tabloların ŞEKLİ değişmiyor: satırlar hâlâ `online_game_id` taşıyor, çünkü
-- bir raporun HANGİ oyundaki/hangi konuşmadaki olaya dayandığı admin için
-- kritik bilgi (Şikayetler sekmesi ve "Sohbeti Görüntüle" buna dayanıyor);
-- mute satırında da hangi oyunda başladığının provenance değeri var. Değişen
-- şey KAPSAM: okuma tarafı (istemcideki fetch'ler) `online_game_id`
-- filtresini bırakıyor, yazma tarafı da (aşağıdaki iki fonksiyon) artık
-- (muter, muted) / (reporter, reported) ÇİFTİ üzerinden tüm oyunlara
-- uygulanıyor. Aksi halde "sessizden çıkar" yalnızca içinde bulunulan oyunun
-- satırını silip kişiyi eski bir oyunun satırı yüzünden sessiz bırakır,
-- "raporu geri çek" de bayrağı söndüremezdi.

-- ── mute_online_game_participant ────────────────────────────────────────────
-- Sessize alma hâlâ p_game_id ile YETKİLENDİRİLİYOR (yalnızca gerçekten
-- birlikte oynadığın birini susturabilirsin) ve satır o oyunun id'siyle
-- yazılıyor; ama sessizden ÇIKARMA artık o çifte ait TÜM satırları siler.
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
    -- Kişi bazlı: hangi oyunda susturulmuş olursa olsun hepsi kalkar.
    delete from public.online_game_message_mutes
    where muter_user_id = auth.uid()
      and muted_user_id = p_target_user_id;
  end if;
end;
$$;

-- ── withdraw_online_game_chat_reports ───────────────────────────────────────
-- p_game_id parametresi kaldırılıyor (imza değiştiğinden drop + create):
-- geri çekme yalnızca çağıranın KENDİ açtığı raporlara dokunduğundan bir
-- oyun bağlamına/katılımcılık kontrolüne ihtiyacı yok, ve bayrak artık kişi
-- bazlı olduğundan tek bir oyunun raporunu geri çekmek onu söndürmezdi.
drop function if exists public.withdraw_online_game_chat_reports (uuid, uuid);

create function public.withdraw_online_game_chat_reports(
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
  where reporter_user_id = auth.uid()
    and reported_user_id = p_target_user_id
    and withdrawn_at is null;
end;
$$;

revoke all on function public.withdraw_online_game_chat_reports (uuid) from public, anon;
grant execute on function public.withdraw_online_game_chat_reports (uuid) to authenticated;

-- ── chat_flags_for_finished_game ────────────────────────────────────────────
-- Biten bir oyunun sohbet ARŞİVİNDE (GameChatHistoryModal) de 🚫/🚩
-- rozetlerini gösterebilmek için. `games.messages` dondurulmuş satırları
-- bilerek `sender_user_id` TAŞIMIYOR (bkz. GameChatMessage) — o snapshot
-- girişli HER kullanıcıya açık olduğundan (games_select_authenticated),
-- kimliği oraya yazmak istemiyoruz. Bu yüzden istemciye kimlik hiç
-- göndermeden doğrudan CEVABI döndürüyoruz: hangi renk indeksindeki
-- oyuncuyu çağıran sessize almış/rapor etmiş.
--
-- `colorIndex`, init_online_game_state'te `i % 4` ile atanır ve oyuncu
-- sayısı en fazla 4 olduğundan koltuk indeksiyle BİREBİR aynıdır; dondurulan
-- mesaj da bu değeri taşıdığından eşleme kayıpsızdır (mevcut/eski oyunlar
-- dahil, snapshot'a hiç dokunmadan geriye dönük çalışır).
--
-- Yalnızca oyunun katılımcısına cevap verir — başkasının beğenip açtığı bir
-- oyunun arşivinde rozet çıkmaz (zaten o kişinin kendi mute/rapor kaydı
-- olamaz, ama sınırı sunucuda da açıkça çiziyoruz).
create or replace function public.chat_flags_for_finished_game(
  p_online_game_id uuid
) returns table (
  color_index int,
  muted boolean,
  reported boolean
)
language sql
stable
security definer
set search_path = public, auth
as $$
  with seats as (
    select
      i as color_index,
      (og.slots -> i ->> 'user_id')::uuid as user_id
    from public.online_games og
    cross join generate_series(0, og.player_count - 1) i
    where og.id = p_online_game_id
      and (og.slots -> i ->> 'type') = 'human'
      and public.is_online_game_participant(p_online_game_id, auth.uid())
  )
  select
    s.color_index,
    exists (
      select 1 from public.online_game_message_mutes m
      where m.muter_user_id = auth.uid() and m.muted_user_id = s.user_id
    ) as muted,
    exists (
      select 1 from public.online_game_chat_reports r
      where r.reporter_user_id = auth.uid()
        and r.reported_user_id = s.user_id
        and r.withdrawn_at is null
    ) as reported
  from seats s
  where s.user_id is not null
    and s.user_id <> auth.uid();
$$;

revoke all on function public.chat_flags_for_finished_game (uuid) from public, anon;
grant execute on function public.chat_flags_for_finished_game (uuid) to authenticated;
