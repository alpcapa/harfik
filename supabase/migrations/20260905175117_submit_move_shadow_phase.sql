-- Kelimeki — ROADMAP #18 gölge fazı: submit_move'a ölçüm çağrısını ekler.
--
-- ⚠ GÖVDE ELLE YENİDEN YAZILMIYOR. 15 KB'lık fonksiyonu kopyalayıp içine
-- dört satır serpiştirmek, kopyalarken sessizce bir şey değiştirme riski
-- taşır — bu depo motorun ÜÇÜNCÜ kopyasında tam olarak bunu yaşadı. Onun
-- yerine canlı tanım `pg_get_functiondef` ile okunup ÜZERİNE yamanıyor ve
-- HER YAMANIN TUTTUĞU iddia ediliyor: çapa bulunamazsa migration düşer,
-- sessizce yanlış bir gövde yazılmaz.
--
-- Davranış DEĞİŞMİYOR: karar hâlâ istemcinin gönderdiği değerlerle veriliyor.
-- Eklenen tek şey ölçüm. Zorlama fazı AYRI bir migration olacak ve ancak
-- `move_shadow_diffs` gerçek oyunlarda boş kaldıktan sonra uygulanacak.
do $do$
declare
  v_def text;
  v_new text;
  v_old text;
begin
  v_def := pg_get_functiondef(
    'public.submit_move(uuid,text,jsonb,jsonb,jsonb,jsonb,integer,jsonb,uuid)'::regprocedure);

  -- 1) Yeni değişkenler
  v_old := E'  v_word_mult int;\n  v_word_final int;\nbegin';
  if position(v_old in v_def) = 0 then raise exception 'yama 1: çapa bulunamadı'; end if;
  v_new := E'  v_word_mult int;\n  v_word_final int;\n'
        || E'  -- ROADMAP #18 gölge fazı: taşlar UYGULANMADAN ÖNCEKİ tahta ve\n'
        || E'  -- "r,c" -> taş haritası. Vergi hesabı ÖNCEKİ tahtayı ister\n'
        || E'  -- (istemci de state.board ile hesaplıyor, state.placed ayrı).\n'
        || E'  v_board_before jsonb;\n'
        || E'  v_placed_map jsonb := ''{}''::jsonb;\nbegin';
  v_def := replace(v_def, v_old, v_new);

  -- 2) Yerleştirme döngüsünden ÖNCE tahtayı dondur
  v_old := E'    v_used := array_fill(false, array[array_length(v_rack_arr, 1)]);\n    v_last_move_cells := ''[]''::jsonb;';
  if position(v_old in v_def) = 0 then raise exception 'yama 2: çapa bulunamadı'; end if;
  v_new := v_old || E'\n    v_board_before := v_board;';
  v_def := replace(v_def, v_old, v_new);

  -- 3) Konan taşı haritaya da yaz
  v_old := E'      v_board := jsonb_set(v_board, array[v_r::text, v_c::text], v_placed_tile);\n      v_last_move_cells :=';
  if position(v_old in v_def) = 0 then raise exception 'yama 3: çapa bulunamadı'; end if;
  v_new := E'      v_board := jsonb_set(v_board, array[v_r::text, v_c::text], v_placed_tile);\n'
        || E'      v_placed_map := v_placed_map || jsonb_build_object(v_r || '','' || v_c, v_placed_tile);\n'
        || E'      v_last_move_cells :=';
  v_def := replace(v_def, v_old, v_new);

  -- 4) Gölge çağrısı
  v_old := E'    v_actor_net := p_base_points - v_shares_total;\n    v_actor_score_delta := v_actor_net + v_finish_bonus;';
  if position(v_old in v_def) = 0 then raise exception 'yama 4: çapa bulunamadı'; end if;
  v_new := v_old || E'\n\n'
        || E'    -- GÖLGE FAZI (ROADMAP #18): sunucu aynı hamleyi kendi motoruyla\n'
        || E'    -- hesaplar ve istemcininkiyle karşılaştırır; SAPMA VARSA yazar ama\n'
        || E'    -- kararı DEĞİŞTİRMEZ. Fonksiyon hiçbir koşulda hata fırlatmaz.\n'
        || E'    perform public._km_shadow_check(\n'
        || E'      p_game_id, v_turn_count, v_current, v_board_before, v_placed_map,\n'
        || E'      v_players, p_base_points, p_words, p_word_scores, p_lost_shares);';
  v_def := replace(v_def, v_old, v_new);

  -- Dördü de tuttu mu?
  if position('_km_shadow_check' in v_def) = 0 then raise exception 'gölge çağrısı eklenmedi'; end if;
  if position('v_board_before := v_board;' in v_def) = 0 then raise exception 'tahta dondurulmadı'; end if;
  if position('v_placed_map := v_placed_map ||' in v_def) = 0 then raise exception 'harita doldurulmadı'; end if;

  execute v_def;
end
$do$;
