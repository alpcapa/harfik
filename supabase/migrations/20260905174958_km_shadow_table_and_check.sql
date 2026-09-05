-- Kelimeki — ROADMAP #18 GÖLGE FAZI: ölçüm tablosu + karşılaştırma fonksiyonu.
--
-- NEDEN GÖLGE (kullanıcı kararı, 5 Eylül 2026): bu değişiklik %100 sunucu
-- tarafında, yani yeni bir derleme gerekmiyor ve web + SAHADAKİ HER kurulu
-- APK/IPA anında etkileniyor. Faydası da riski de aynı yerden geliyor:
-- kademeli yayın YAPILAMIYOR. Aynada tek bir sapma olsa dürüst bir oyuncunun
-- geçerli hamlesi reddedilir (mesaj kullanıcıya aynen gider — api.ts
-- `throw new Error(error.message)`).
--
-- Çözüm: önce ÖLÇ, sonra ZORLA. Bu fazda sunucu her hamleyi kendi motoruyla
-- hesaplar, istemcinin gönderdiğiyle karşılaştırır, SAPMA VARSA yazar ama
-- kararı DEĞİŞTİRMEZ. Gerçek oyunlarda, gerçek cihazlarda, gerçek eski
-- sürümlerde ölçüm toplar — elle APK denemesinden daha kapsamlı, çünkü
-- sahanın tamamını görür.
--
-- Hedef: `move_shadow_diffs` BOŞ kalsın. Doluysa SQL aynası ile istemci
-- motoru ayrışıyor demektir ve zorlama fazına GEÇİLMEZ.

create table if not exists public.move_shadow_diffs (
  id bigint generated always as identity primary key,
  online_game_id uuid not null,
  turn int not null,
  player_index int not null,
  alan text not null,          -- base_points | words | word_scores | lost_shares | structural | dictionary | hata
  istemci jsonb,
  sunucu jsonb,
  girdi jsonb,                 -- tekrar üretmek için: board(önce) + placed + players
  created_at timestamptz not null default now()
);

comment on table public.move_shadow_diffs is
  'ROADMAP #18 gölge fazı — submit_move''un sunucu hesabı ile istemcinin gönderdiği değerin ayrıştığı hamleler. Boş kalması hedeftir.';

create index if not exists move_shadow_diffs_created_idx on public.move_shadow_diffs (created_at desc);

alter table public.move_shadow_diffs enable row level security;
-- Politika YOK: anon/authenticated hiçbir şey göremez. Yazım SECURITY DEFINER
-- içinden yapıldığından RLS'i aşar; okuma yalnızca service role.
revoke all on public.move_shadow_diffs from anon, authenticated;

-- ⚠ HİÇBİR KOŞULDA HATA FIRLATMAZ: aynadaki bir bug gerçek bir hamleyi
-- bozamamalı. Gövde tümüyle exception ile sarılı; son çare 'hata' satırı.
create or replace function public._km_shadow_check(
  p_game_id uuid,
  p_turn int,
  p_owner int,
  p_board_before jsonb,     -- taşlar UYGULANMADAN ÖNCEKİ tahta
  p_placed jsonb,           -- "r,c" -> taş
  p_players jsonb,
  p_cli_base int,
  p_cli_words jsonb,
  p_cli_word_scores jsonb,
  p_cli_shares jsonb
) returns void language plpgsql security definer set search_path to 'public' as $$
declare
  v_corners jsonb;
  v_is_first boolean := true;
  v_r int; v_c int; v_cell jsonb;
  v_structural text; v_dict text;
  v_base int; v_ws jsonb; v_words jsonb; v_split jsonb;
  v_coords jsonb := '[]'::jsonb;
  v_k text;
  v_srv_shares text; v_cli_shares_t text;
  v_srv_words text; v_cli_words_t text;
  v_srv_ws text; v_cli_ws_t text;
  v_girdi jsonb;
begin
  v_girdi := jsonb_build_object('board', p_board_before, 'placed', p_placed, 'players', p_players);
  v_corners := coalesce(p_players -> p_owner -> 'corners', '[]'::jsonb);

  for v_r in 0 .. 12 loop
    for v_c in 0 .. 12 loop
      v_cell := p_board_before -> v_r -> v_c;
      if v_cell is not null and jsonb_typeof(v_cell) <> 'null'
         and (v_cell ->> 'owner')::int = p_owner then
        v_is_first := false; exit;
      end if;
    end loop;
    exit when not v_is_first;
  end loop;

  for v_k in select jsonb_object_keys(p_placed) loop
    v_coords := v_coords || jsonb_build_array(jsonb_build_array(
      split_part(v_k, ',', 1)::int, split_part(v_k, ',', 2)::int));
  end loop;

  v_structural := public._km_validate_structural(p_board_before, p_placed, p_owner, v_corners, v_is_first);
  if v_structural is not null then
    insert into public.move_shadow_diffs (online_game_id, turn, player_index, alan, istemci, sunucu, girdi)
    values (p_game_id, p_turn, p_owner, 'structural', null, to_jsonb(v_structural), v_girdi);
    return;  -- yapısal olarak geçersizse skor karşılaştırması anlamsız
  end if;

  v_dict := public._km_validate_words(p_board_before, p_placed);
  if v_dict is not null then
    insert into public.move_shadow_diffs (online_game_id, turn, player_index, alan, istemci, sunucu, girdi)
    values (p_game_id, p_turn, p_owner, 'dictionary', p_cli_words, to_jsonb(v_dict), v_girdi);
  end if;

  v_base := public._km_calc_score(p_board_before, p_placed);
  if v_base is distinct from p_cli_base then
    insert into public.move_shadow_diffs (online_game_id, turn, player_index, alan, istemci, sunucu, girdi)
    values (p_game_id, p_turn, p_owner, 'base_points', to_jsonb(p_cli_base), to_jsonb(v_base), v_girdi);
  end if;

  -- Kelimeler: sıradan bağımsız karşılaştır (istemci sırası deterministik değil).
  v_words := (select jsonb_agg(w ->> 'word' order by w ->> 'word')
              from jsonb_array_elements(public._km_formed_words(p_board_before, p_placed)) w);
  v_srv_words := coalesce(v_words::text, '[]');
  v_cli_words_t := coalesce((select jsonb_agg(x order by x)::text
                             from jsonb_array_elements_text(coalesce(p_cli_words, '[]'::jsonb)) x), '[]');
  if v_srv_words is distinct from v_cli_words_t then
    insert into public.move_shadow_diffs (online_game_id, turn, player_index, alan, istemci, sunucu, girdi)
    values (p_game_id, p_turn, p_owner, 'words', p_cli_words, v_words, v_girdi);
  end if;

  v_ws := public._km_word_scores(p_board_before, p_placed);
  v_srv_ws := coalesce((select string_agg((w->>'word')||'/'||(w->>'score')||'/'||(w->>'x2')||'/'||(w->>'x3'), ',' order by (w->>'word'))
                        from jsonb_array_elements(v_ws) w), '');
  v_cli_ws_t := coalesce((select string_agg((w->>'word')||'/'||(w->>'score')||'/'||(w->>'x2')||'/'||(w->>'x3'), ',' order by (w->>'word'))
                          from jsonb_array_elements(coalesce(p_cli_word_scores, '[]'::jsonb)) w), '');
  if v_srv_ws is distinct from v_cli_ws_t then
    insert into public.move_shadow_diffs (online_game_id, turn, player_index, alan, istemci, sunucu, girdi)
    values (p_game_id, p_turn, p_owner, 'word_scores', p_cli_word_scores, v_ws, v_girdi);
  end if;

  -- Vergi: İSTEMCİNİN base'i ile hesaplanır ki fark yalnızca BÖLGE hesabından
  -- gelsin (base zaten ayrıca karşılaştırıldı — iki hatayı birbirine karıştırma).
  v_split := public._km_invasion_split(v_coords, p_owner, p_players, p_cli_base, p_board_before);
  v_srv_shares := coalesce((select string_agg((s->>'to')||':'||(s->>'amount'), ',' order by (s->>'to')::int)
                            from jsonb_array_elements(v_split -> 'shares') s), '');
  v_cli_shares_t := coalesce((select string_agg((s->>'to')||':'||(s->>'amount'), ',' order by (s->>'to')::int)
                              from jsonb_array_elements(coalesce(p_cli_shares, '[]'::jsonb)) s), '');
  if v_srv_shares is distinct from v_cli_shares_t then
    insert into public.move_shadow_diffs (online_game_id, turn, player_index, alan, istemci, sunucu, girdi)
    values (p_game_id, p_turn, p_owner, 'lost_shares', p_cli_shares, v_split -> 'shares', v_girdi);
  end if;
exception when others then
  -- Ayna çökse bile GERÇEK HAMLE ETKİLENMEZ.
  begin
    insert into public.move_shadow_diffs (online_game_id, turn, player_index, alan, sunucu, girdi)
    values (p_game_id, p_turn, p_owner, 'hata', to_jsonb(sqlerrm), v_girdi);
  exception when others then null;
  end;
end;
$$;

revoke all on function public._km_shadow_check(uuid,int,int,jsonb,jsonb,jsonb,int,jsonb,jsonb,jsonb) from anon, authenticated;
