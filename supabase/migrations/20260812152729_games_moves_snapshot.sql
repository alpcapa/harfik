-- games.moves — bitmiş bir oyunun TAM hamle dökümünü dondurur (12 Ağustos 2026).
--
-- NEDEN: "Tüm Oyunlarım"daki her kartta, sohbet rozetinin yanında bir hamle
-- geçmişi ikonu olacak; dokununca o oyunun dökümü `MoveHistoryModal` ile
-- açılacak. Veri iki sebeple DONDURULMAK zorunda:
--   1. Yerel (YZ) oyunlarda `moveHistory` yalnızca `GameState` içinde yaşıyor;
--      `local_game_saves` satırı oyun bitince siliniyor, `games` bu alanı
--      taşımıyordu — yani veri hiçbir yerde kalmıyordu.
--   2. Canlı oyunlarda `online_game_moves` duruyor AMA RLS'i yalnızca
--      KATILIMCIYA açık; Favoriler'den başkasının oyununu açan biri hamleleri
--      göremezdi. Sohbette (games.messages) bu tam da dondurarak çözülmüştü.
-- Dondurmak ayrıca yerel/Canlı ayrımını da ortadan kaldırıyor: istemcide tek
-- kod yolu.
--
-- KOLON YETKİSİ — Parça 51'in tuzağı, unutulursa kolon istemciye GÖRÜNMEZ:
-- `games` tablosunda tablo düzeyinde SELECT YOK (chat gizliliği için
-- kaldırılmıştı), yetkiler kolon kolon veriliyor (bugün 20 kolon). Yeni kolon
-- açıkça grant edilmezse `select moves` sessizce hata verir.
--
-- GİZLİLİK KARARI (kolon bazında yeniden soruldu — Parça 51'in dersi):
-- `moves` bir OYUN verisi, `messages` gibi kullanıcı yazışması DEĞİL —
-- oynanan kelimeler ve puanları, yani `board_snapshot`la aynı sınıf. O kolon
-- zaten anon+authenticated'e açık; `moves` de aynı iki role veriliyor.
-- Görünürlük RLS'in kendisiyle sınırlı kalmaya devam ediyor (değiştirilmedi):
-- `games_select_authenticated` girişli kullanıcı şartını koruyor, anon yalnız
-- `get_shared_game` RPC'siyle görebildiği alanları görüyor — o RPC'ye moves
-- EKLENMEDİ, paylaşılan oyun sayfasının kapsamı bilerek aynı kaldı.

alter table public.games add column if not exists moves jsonb;

grant select (moves) on public.games to anon;
grant select (moves) on public.games to authenticated;

-- Canlı bir oyunun `online_game_moves` satırlarını `GameState.moveHistory`
-- ile AYNI şekle çevirir — istemcideki `buildMoveHistory`nin (web
-- `OnlineGameScreen.tsx`, mobil `online_games_api.dart`) SQL karşılığı.
--
-- TEK TANIM olarak yazıldı çünkü İKİ çağıranı var: oyun bitişi
-- (`_finish_online_game_records`) ve bu migration'ın geriye dönük backfill'i.
-- İki kopya açmak, bu projede daha önce `fix_online_finish_players_order`
-- hatasını üreten sınıf (aynı mantığın iki yerde ayrışması).
--
-- Sıra istemciyle aynı: `turn`, sonra `created_at`.
--
-- `lostShares` satırları GENİŞLETİLİR: bir hamle rakip bölgesine değdiyse,
-- pay alan her oyuncu için ayrı bir `invasionFrom` satırı eklenir. Modal
-- bunları kart olarak GÖSTERMEZ ama toplam puana katar — atılırlarsa
-- toplamlar bozulur (şartnamede açıkça "alan kırpma YOK" deniyor).
--
-- Opsiyonel alanlar yalnızca DOLUYKEN yazılır (kanonik JSON sözleşmesi —
-- `HistoryEntry`in TS/Dart codec'leri de böyle).
create or replace function public._online_moves_snapshot(p_game_id uuid)
returns jsonb
language sql
stable
security definer
set search_path to 'public'
as $$
  with ordered as (
    -- Sıra numarası TÜM satırlar üzerinden BİR KEZ hesaplanır ve vergi
    -- satırlarına ebeveyninden taşınır. İlk yazımda iki dal AYRI AYRI
    -- `row_number()` kullanıyordu; ikinci dal yalnızca lost_shares'i OLAN
    -- satırları saydığından numaralar ebeveynle eşleşmiyor ve vergi satırı
    -- listenin başına düşüyordu (gerçek veriyle koşulunca yakalandı: turn 9'un
    -- vergisi 1. sıraya çıkmıştı).
    select m.*, row_number() over (order by m.turn, m.created_at) as ord
    from public.online_game_moves m
    where m.online_game_id = p_game_id
  )
  select coalesce(jsonb_agg(entry order by ord, sub), '[]'::jsonb)
  from (
    select o.ord, 0 as sub,
      jsonb_build_object(
        'turn', o.turn,
        'player', o.player_index,
        'words', coalesce(o.words, '[]'::jsonb),
        'points', o.points
      )
      || case when o.word_scores is not null and jsonb_typeof(o.word_scores) = 'array'
              then jsonb_build_object('wordScores', o.word_scores) else '{}'::jsonb end
      || case when coalesce(o.finish_joker_count, 0) <> 0
              then jsonb_build_object('finishJokerCount', o.finish_joker_count) else '{}'::jsonb end
      || case when o.bingo is true
              then jsonb_build_object('bingo', true) else '{}'::jsonb end
      || case when o.action <> 'play'
              then jsonb_build_object('action', o.action) else '{}'::jsonb end
      || case when o.action = 'exchange'
              then jsonb_build_object('tileCount', o.tile_count) else '{}'::jsonb end
      || case when jsonb_array_length(coalesce(o.lost_shares, '[]'::jsonb)) > 0
              then jsonb_build_object('lostShares', o.lost_shares) else '{}'::jsonb end
      as entry
    from ordered o

    union all

    -- Bölge vergisi (invasionFrom) satırları — payı ALAN oyuncunun skoruna
    -- eklenen puan. `sub` bunları kendi hamlelerinin HEMEN ardına koyuyor
    -- (istemcideki döngü sırası).
    select o.ord, (s.ordinality)::int as sub,
      jsonb_build_object(
        'turn', o.turn,
        'player', (s.value ->> 'to')::int,
        'words', coalesce(o.words, '[]'::jsonb),
        'points', (s.value ->> 'amount')::int,
        'invasionFrom', o.player_index
      ) as entry
    from ordered o
    cross join lateral jsonb_array_elements(coalesce(o.lost_shares, '[]'::jsonb)) with ordinality as s(value, ordinality)
  ) rows;
$$;

revoke all on function public._online_moves_snapshot(uuid) from public, anon, authenticated;

-- Oyun bitiş yazıcısı artık hamle dökümünü de donduruyor. Fonksiyonun geri
-- kalanı (ranking, players json, board snapshot, messages) DEĞİŞMEDİ —
-- yalnızca `v_fp_moves` hesabı ve insert'e eklenen kolon.
create or replace function public._finish_online_game_records(
  p_game_id uuid, p_board jsonb, p_players jsonb, p_slots jsonb,
  p_player_count integer, p_turn_count integer
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_fp_sorted_idx int[];
  v_fp_ranks int[];
  v_fp_rank int;
  v_fp_prev_score int;
  v_fp_prev_surrendered boolean;
  v_fp_idx int;
  v_fp_cur_score int;
  v_fp_cur_surrendered boolean;
  v_fp_tied1 int;
  v_fp_players_json jsonb;
  v_fp_snapshot jsonb;
  v_fp_messages jsonb;
  v_fp_moves jsonb;
  v_fp_slot jsonb;
  v_fp_result text;
begin
  v_fp_sorted_idx := array(
    select gs
    from generate_series(0, p_player_count - 1) gs
    order by
      coalesce((p_players -> gs ->> 'surrendered')::boolean, false) asc,
      (p_players -> gs ->> 'score')::int desc,
      gs asc
  );

  v_fp_ranks := array_fill(0, array[p_player_count]);
  v_fp_rank := 0;
  for pos in 1 .. p_player_count loop
    v_fp_idx := v_fp_sorted_idx[pos];
    v_fp_cur_score := (p_players -> v_fp_idx ->> 'score')::int;
    v_fp_cur_surrendered := coalesce((p_players -> v_fp_idx ->> 'surrendered')::boolean, false);
    if pos = 1 or v_fp_cur_score <> v_fp_prev_score or v_fp_cur_surrendered <> v_fp_prev_surrendered then
      v_fp_rank := pos;
    end if;
    v_fp_ranks[v_fp_idx + 1] := v_fp_rank;
    v_fp_prev_score := v_fp_cur_score;
    v_fp_prev_surrendered := v_fp_cur_surrendered;
  end loop;

  v_fp_tied1 := 0;
  for i in 0 .. p_player_count - 1 loop
    if v_fp_ranks[i + 1] = 1 then
      v_fp_tied1 := v_fp_tied1 + 1;
    end if;
  end loop;

  v_fp_players_json := '[]'::jsonb;
  for pos in 1 .. p_player_count loop
    v_fp_players_json := v_fp_players_json || jsonb_build_array(jsonb_build_object(
      'name', (p_players -> v_fp_sorted_idx[pos] ->> 'name'),
      'score', (p_players -> v_fp_sorted_idx[pos] ->> 'score')::int,
      'is_ai', (p_players -> v_fp_sorted_idx[pos] ->> 'isAI')::boolean,
      'surrendered', coalesce((p_players -> v_fp_sorted_idx[pos] ->> 'surrendered')::boolean, false),
      'colorIndex', (p_players -> v_fp_sorted_idx[pos] ->> 'colorIndex')::int
    ));
  end loop;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'r', gr,
      'c', gc,
      'l', (p_board -> gr -> gc) ->> 'letter',
      'o', coalesce(((p_board -> gr -> gc) ->> 'owner')::int, 0)
    ) || case when ((p_board -> gr -> gc) ->> 'wild')::boolean is true
              then jsonb_build_object('w', true)
              else '{}'::jsonb
         end
  ), '[]'::jsonb)
  into v_fp_snapshot
  from generate_series(0, 12) gr, generate_series(0, 12) gc
  where jsonb_typeof(p_board -> gr -> gc) <> 'null';

  with seat_map as (
    select (p_slots -> i ->> 'user_id')::uuid as user_id, i as seat_idx
    from generate_series(0, p_player_count - 1) i
    where (p_slots -> i ->> 'type') = 'human'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'name', coalesce(p_players -> sm.seat_idx ->> 'name', 'Oyuncu'),
      'colorIndex', (p_players -> sm.seat_idx ->> 'colorIndex')::int,
      'message', m.message,
      'created_at', m.created_at
    ) order by m.created_at), '[]'::jsonb)
  into v_fp_messages
  from public.online_game_messages m
  join seat_map sm on sm.user_id = m.sender_user_id
  where m.online_game_id = p_game_id;

  -- Hamle dökümü (yeni) — tek tanımlı yardımcıdan.
  v_fp_moves := public._online_moves_snapshot(p_game_id);

  for i in 0 .. p_player_count - 1 loop
    v_fp_slot := p_slots -> i;
    if (v_fp_slot ->> 'type') = 'human' then
      v_fp_result := case
        when coalesce((p_players -> i ->> 'surrendered')::boolean, false) then 'lose'
        when v_fp_ranks[i + 1] > 1 then 'lose'
        when v_fp_tied1 > 1 then 'tie'
        else 'win'
      end;
      insert into public.games (
        user_id, player_score, ai_score, result, turn_count, player_count,
        best_move_score, move_count, move_points_sum, rank, surrendered,
        players, longest_word, online_game_id, board_snapshot, messages,
        best_word_score, moves
      ) values (
        (v_fp_slot ->> 'user_id')::uuid,
        (p_players -> i ->> 'score')::int,
        (
          select max((p_players -> k ->> 'score')::int)
          from generate_series(0, p_player_count - 1) k
          where k <> i
        ),
        v_fp_result,
        p_turn_count,
        p_player_count,
        nullif((p_players -> i ->> 'bestMoveScore')::int, 0),
        nullif((p_players -> i ->> 'moveCount')::int, 0),
        nullif((p_players -> i ->> 'moveScoreSum')::int, 0),
        v_fp_ranks[i + 1],
        coalesce((p_players -> i ->> 'surrendered')::boolean, false),
        v_fp_players_json,
        nullif(p_players -> i ->> 'longestWord', ''),
        p_game_id,
        v_fp_snapshot,
        v_fp_messages,
        nullif((p_players -> i ->> 'bestWordScore')::int, 0),
        v_fp_moves
      );
    end if;
  end loop;
end;
$function$;

-- Geriye dönük doldurma — YALNIZCA Canlı oyunlar. Yerel (YZ) oyunların hamle
-- geçmişi hiçbir yerde saklanmadığından kurtarılamaz; o kartlar
-- `board_snapshot`taki gibi "kaydedilmemiş" diyecek.
update public.games g
set moves = public._online_moves_snapshot(g.online_game_id)
where g.online_game_id is not null
  and g.moves is null;
