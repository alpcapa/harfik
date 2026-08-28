-- Kelimeki — hesap silme kaskadına push token'ları eklendi (ROADMAP madde 13).
-- Fonksiyonun geri kalanı 20260825201353_delete_account_cascade ile BİREBİR
-- aynı; yalnızca dört satır eklendi (bildirim, sayım, rapor, silme).

create or replace function public.delete_account_cascade(
  p_uid uuid,
  p_dry_run boolean default true
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_anon    constant text := 'Silinmiş oyuncu';
  v_email   text;
  v_name    text;
  v_admin   boolean;
  v_rapor   jsonb;
  n_games_kendi        int;
  n_games_baskalarinin int;
  n_players_girisi     int;
  n_messages_girisi    int;
  n_state_koltuk       int;
  n_yarim_oyun         int;
  n_msg                int;
  n_moves              int;
  n_mutes              int;
  n_reports            int;
  n_feedback           int;
  n_likes              int;
  n_friend_req         int;
  n_invite_links       int;
  n_local_saves        int;
  n_league             int;
  n_game_invites       int;
  n_clients            int;
  n_ban_log            int;
  n_game_finishes      int;
  n_eslenemeyen        int;
  n_push_tokens        int;
begin
  if p_uid is null then
    raise exception 'Kullanıcı kimliği verilmedi.' using errcode = '22023';
  end if;

  select u.email into v_email from auth.users u where u.id = p_uid;
  if not found then
    raise exception 'Hesap bulunamadı.' using errcode = 'P0002';
  end if;

  select p.display_name, p.is_admin into v_name, v_admin
  from public.profiles p where p.id = p_uid;

  -- Yönetici hesabı bu yoldan silinemez. Projede tek bir admin var ve
  -- `Ironman` için "HİÇBİR KOŞULDA SİLİNMEZ" yazılı bir karar (ROADMAP #4).
  -- Yanlışlıkla basılan bir butonun geri dönüşü yok; kapıyı sunucuda kapat.
  if coalesce(v_admin, false) then
    raise exception 'Yönetici hesabı uygulama içinden silinemez.' using errcode = 'P0001';
  end if;

  -- ── Koltuk eşlemesi: (oyun, koltuk indeksi) ──────────────────────────────
  create temp table _del_seats on commit drop as
  select og.id as game_id, (x.ord - 1)::int as seat
  from public.online_games og,
       lateral jsonb_array_elements(og.slots) with ordinality as x(slot, ord)
  where x.slot ->> 'user_id' = p_uid::text;

  -- Hiç bitmemiş (kimsenin dondurulmuş `games` kaydı olmayan) oyunlar.
  -- `created_by` da katılıyor: kişi bir oyunu açıp koltuğu hiç dolmamış
  -- olabilir.
  create temp table _del_yarim on commit drop as
  select distinct og.id
  from public.online_games og
  where (og.id in (select game_id from _del_seats) or og.created_by = p_uid)
    and not exists (select 1 from public.games g where g.online_game_id = og.id);

  -- ── Sayım (kuru çalıştırma da bunu döndürür) ─────────────────────────────
  select count(*) into n_games_kendi from public.games where user_id = p_uid;

  select count(*) into n_games_baskalarinin
  from public.games g join _del_seats s on s.game_id = g.online_game_id
  where g.user_id is distinct from p_uid;

  select coalesce(sum(k), 0) into n_players_girisi from (
    select (select count(*) from jsonb_array_elements(coalesce(g.players, '[]'::jsonb)) e
            where (e ->> 'colorIndex')::int = s.seat) as k
    from public.games g join _del_seats s on s.game_id = g.online_game_id
    where g.user_id is distinct from p_uid
  ) t;

  select coalesce(sum(k), 0) into n_messages_girisi from (
    select (select count(*) from jsonb_array_elements(coalesce(g.messages, '[]'::jsonb)) e
            where (e ->> 'colorIndex')::int = s.seat) as k
    from public.games g join _del_seats s on s.game_id = g.online_game_id
    where g.user_id is distinct from p_uid
  ) t;

  select count(*) into n_state_koltuk
  from public.online_game_states st join _del_seats s on s.game_id = st.online_game_id
  where st.online_game_id not in (select id from _del_yarim);

  select count(*) into n_yarim_oyun from _del_yarim;

  select count(*) into n_msg from public.online_game_messages where sender_user_id = p_uid;
  select count(*) into n_moves from public.online_game_moves where player_user_id = p_uid;
  select count(*) into n_mutes from public.online_game_message_mutes
    where muter_user_id = p_uid or muted_user_id = p_uid;
  select count(*) into n_reports from public.online_game_chat_reports
    where reporter_user_id = p_uid or reported_user_id = p_uid;
  select count(*) into n_feedback from public.feedback where user_id = p_uid;
  select count(*) into n_likes from public.game_likes where user_id = p_uid;
  select count(*) into n_friend_req from public.friend_requests
    where user_id = p_uid or friend_id = p_uid;
  select count(*) into n_invite_links from public.friend_invite_links where inviter_id = p_uid;
  select count(*) into n_local_saves from public.local_game_saves where user_id = p_uid;
  select count(*) into n_league from public.league_rewards where user_id = p_uid;
  select count(*) into n_game_invites from public.game_invites where invitee_id = p_uid;
  select count(*) into n_clients from public.online_game_clients where user_id = p_uid;
  select count(*) into n_ban_log from public.admin_ban_log where target_user_id = p_uid;
  select count(*) into n_game_finishes from public.game_finishes where user_id = p_uid;
  select count(*) into n_push_tokens from public.push_tokens where user_id = p_uid;

  -- Koltuk eşlemesi KURULAMAYAN satırlar: `online_game_id` boş olduğu için
  -- hangi koltuğun kime ait olduğu bilinemiyor. Ada göre eşleştirme YAPILMAZ
  -- (yukarıdaki tuzak) — sessizce yok saymak yerine RAPORLANIR. Bugün canlıda
  -- sıfır: çok insanlı bir oyunun `games` satırı her zaman online_game_id
  -- taşıyor (ölçüldü, 25 Ağustos 2026).
  select count(*) into n_eslenemeyen
  from public.games g
  where g.online_game_id is null
    and g.user_id is distinct from p_uid
    and (select count(*) from jsonb_array_elements(coalesce(g.players, '[]'::jsonb)) e
         where coalesce((e ->> 'is_ai')::boolean, false) = false) > 1;

  v_rapor := jsonb_build_object(
    'ok', true,
    'dryRun', p_dry_run,
    'hesap', jsonb_build_object('id', p_uid, 'email', v_email, 'ad', v_name),
    'silinecek', jsonb_build_object(
      'profil', 1,
      'games_kendi', n_games_kendi,
      'yarim_online_oyun', n_yarim_oyun,
      'online_game_messages', n_msg,
      'online_game_message_mutes', n_mutes,
      'online_game_chat_reports', n_reports,
      'online_game_clients', n_clients,
      'feedback', n_feedback,
      'game_likes', n_likes,
      'friend_requests', n_friend_req,
      'friend_invite_links', n_invite_links,
      'local_game_saves', n_local_saves,
      'league_rewards', n_league,
      'game_invites', n_game_invites,
      'admin_ban_log', n_ban_log,
      'push_tokens', n_push_tokens
    ),
    'anonimlestirilecek', jsonb_build_object(
      'games_baskalarinin', n_games_baskalarinin,
      'players_girisi', n_players_girisi,
      'messages_girisi', n_messages_girisi,
      'online_game_states_koltuk', n_state_koltuk
    ),
    'kimliksizlestirilecek', jsonb_build_object(
      'game_finishes', n_game_finishes,
      'online_game_moves', n_moves
    ),
    'eslenemeyen_games_satiri', n_eslenemeyen
  );

  if p_dry_run then
    drop table _del_seats;
    drop table _del_yarim;
    return v_rapor;
  end if;

  -- ── UYGULA ───────────────────────────────────────────────────────────────
  -- SIRA ÖNEMLİ: anonimleştirme, `online_games` satırları silinmeden ÖNCE
  -- yapılmalı — silinirse `games.online_game_id` SET NULL olur ve koltuk
  -- eşlemesi bir daha kurulamaz.

  -- (a) Başkalarının dondurulmuş kayıtlarında adı anonimleştir.
  update public.games g
  set players = coalesce((
        select jsonb_agg(
          case when (e ->> 'colorIndex')::int = s.seat
               then jsonb_set(e, '{name}', to_jsonb(v_anon)) else e end
          order by ord)
        from jsonb_array_elements(g.players) with ordinality as t(e, ord)
      ), g.players),
      messages = case
        when g.messages is null then null
        else coalesce((
          select jsonb_agg(
            case when (e ->> 'colorIndex')::int = s.seat
                 then jsonb_set(e, '{name}', to_jsonb(v_anon)) else e end
            order by ord)
          from jsonb_array_elements(g.messages) with ordinality as t(e, ord)
        ), g.messages)
      end
  from _del_seats s
  where g.online_game_id = s.game_id and g.user_id is distinct from p_uid;

  -- (b) KORUNAN (bitmiş) oyunların canlı durumundaki koltuk adı.
  update public.online_game_states st
  set players = jsonb_set(st.players, array[s.seat::text, 'name'], to_jsonb(v_anon))
  from _del_seats s
  where st.online_game_id = s.game_id
    and st.online_game_id not in (select id from _del_yarim);

  -- (c) Yarım kalan oyunlar tümüyle gider (state/secrets/moves/messages/
  --     mutes/reports/clients/invites hepsi CASCADE).
  delete from public.online_games where id in (select id from _del_yarim);

  -- (d) Kişinin KENDİ oyun kayıtları (games.user_id FK'si SET NULL olduğundan
  --     `auth.users` silinse bile bunlar kalırdı — açıkça siliyoruz).
  delete from public.games where user_id = p_uid;

  -- (e) Kişinin gönderdiği görüş/şikayet mesajları ve ona yazılan admin
  --     mesajları (feedback.user_id FK'si SET NULL — açıkça siliniyor).
  delete from public.feedback where user_id = p_uid;

  -- (f) FK'si NO ACTION olanlar — temizlenmezse deleteUser FK ihlaliyle düşer.
  delete from public.online_game_messages where sender_user_id = p_uid;
  delete from public.online_game_message_mutes
    where muter_user_id = p_uid or muted_user_id = p_uid;
  delete from public.online_game_chat_reports
    where reporter_user_id = p_uid or reported_user_id = p_uid;
  -- Hamleler ötekinin oyun kaydının parçası: satır KALIR, kimlik gider.
  update public.online_game_moves set player_user_id = null where player_user_id = p_uid;

  -- (g) Push cihaz token'ları (28 Ağustos 2026, ROADMAP madde 13).
  --     FK'si ZATEN `on delete cascade`, yani `auth.admin.deleteUser`
  --     BAŞARILI OLURSA bu satır olmasa da veri kalmazdı. Yine de açıkça
  --     siliniyor ve gerekçe ÖLÇÜLDÜ, varsayılmadı:
  --     (1) `delete-my-account`, `deleteUser` DÜŞERSE hata döndürüp hesabı
  --         AYAKTA bırakıyor ("Verilerin silindi ama hesap kapatılamadı.
  --         Lütfen tekrar dene."). O durumda FK hiç tetiklenmez; token açık
  --         silinmezse verileri silinmiş bir kişinin telefonuna push gitmeye
  --         DEVAM ederdi. Yani pencere milisaniyelik değil — kullanıcı
  --         tekrar deneyene kadar açık.
  --     (2) Kuru çalıştırma raporu kullanıcıya ne silineceğini gösteriyor;
  --         eksik bir rapor yanlış bir vaattir.
  delete from public.push_tokens where user_id = p_uid;

  drop table _del_seats;
  drop table _del_yarim;
  return v_rapor;
end;
$$;


comment on function public.delete_account_cascade(uuid, boolean) is
  'Hesap silme kaskadı (ROADMAP madde 2). p_dry_run=true hiçbir şey yazmaz, '
  'yalnızca sayıları döndürür. auth.users satırını SİLMEZ — onu çağıran '
  'delete-my-account Edge Function''ı service-role admin API ile yapar. '
  'Yalnızca service_role çağırabilir.';

revoke all on function public.delete_account_cascade(uuid, boolean) from public;
revoke all on function public.delete_account_cascade(uuid, boolean) from anon;
revoke all on function public.delete_account_cascade(uuid, boolean) from authenticated;
grant execute on function public.delete_account_cascade(uuid, boolean) to service_role;
