-- Bitmiş Canlı oyunun DONDURULMUŞ sohbet arşivi (games.messages) bugüne
-- kadar GİRİŞLİ HERKESE açıktı: `games`in tek SELECT politikası
-- (`games_select_authenticated`) yalnızca "oturum var mı" diye bakıyor,
-- satır sahipliğine bakmıyor. Yani k-lig → oyuncu kartı → "Tüm Oyunlar"
-- zincirinden (ya da doğrudan API'den, anon anahtarı zaten herkeste)
-- başkasının yazışmaları okunabiliyordu. 10 Ağustos 2026'da kullanıcı
-- fark etti; canlıda gerçek bir oyunla doğrulandı (katılımcı olmayan bir
-- hesabın kimliğiyle 5 mesajın tamamı gönderen adlarıyla geldi).
--
-- Canlı sohbetin KENDİSİ (online_game_messages) zaten katılımcıya kilitli
-- ve `admin_get_finished_game_chat` ayrı bir security definer yol — sızan
-- tek yüzey bu dondurulmuş kopyaydı.
--
-- İki parça:
--   1) Okuma katılımcı/admin kapısının arkasına alınır (bu fonksiyon).
--   2) `messages` kolonu istemci rollerinden tamamen kaldırılır — RLS
--      SATIR bazlı olduğundan asıl kapatma yolu kolon yetkisi. DİKKAT:
--      Postgres'te tablo düzeyinde SELECT varken kolon düzeyinde REVOKE
--      ETKİSİZDİR; tablo yetkisi kaldırılıp kalan kolonlar tek tek
--      verilmek zorunda (aşağıdaki liste `messages` HARİÇ tüm kolonlar —
--      yeni bir kolon eklenirse bu listeye de eklenmeli, yoksa istemci
--      onu okuyamaz).
--
-- `message_count` BİLEREK okunabilir kalıyor (kullanıcı kararı): rozet
-- fazladan bir istek atmadan çizilebilsin diye. Sızan bilgi yalnızca "bu
-- oyunda N mesaj vardı", içerik değil; rozete dokunan yetkisiz kullanıcı
-- artık "Yazışmaları görmeye yetkiniz yok." mesajını görüyor.

create or replace function public.game_chat_archive(p_game_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_online uuid;
  v_msgs jsonb;
begin
  select g.online_game_id, g.messages
    into v_online, v_msgs
  from public.games g
  where g.id = p_game_id;

  -- Var olmayan/erişilemeyen oyun: yetkisizle aynı cevap (varlık sızdırma).
  if not found then
    return jsonb_build_object('allowed', false, 'messages', '[]'::jsonb);
  end if;

  -- Yerel (YZ) oyunda sohbet kavramı yok — satır her zaman boş, gizlenecek
  -- bir şey de yok.
  if v_online is null then
    return jsonb_build_object('allowed', true,
                              'messages', coalesce(v_msgs, '[]'::jsonb));
  end if;

  if public.is_admin()
     or public.is_online_game_participant(v_online, auth.uid()) then
    return jsonb_build_object('allowed', true,
                              'messages', coalesce(v_msgs, '[]'::jsonb));
  end if;

  return jsonb_build_object('allowed', false, 'messages', '[]'::jsonb);
end;
$$;

revoke all on function public.game_chat_archive(uuid) from public;
revoke all on function public.game_chat_archive(uuid) from anon;
grant execute on function public.game_chat_archive(uuid) to authenticated;

-- Kolon yetkisi: tablo düzeyindeki SELECT kaldırılıp `messages` DIŞINDAKİ
-- kolonlar geri veriliyor (bkz. yukarıdaki Postgres notu).
revoke select on public.games from anon;
revoke select on public.games from authenticated;

grant select (
  id, user_id, player_score, ai_score, result, turn_count, created_at,
  best_move_score, move_count, move_points_sum, player_count, rank,
  surrendered, players, longest_word, board_snapshot, shared, shared_at,
  online_game_id, message_count, best_word_score
) on public.games to anon;

grant select (
  id, user_id, player_score, ai_score, result, turn_count, created_at,
  best_move_score, move_count, move_points_sum, player_count, rank,
  surrendered, players, longest_word, board_snapshot, shared, shared_at,
  online_game_id, message_count, best_word_score
) on public.games to authenticated;
