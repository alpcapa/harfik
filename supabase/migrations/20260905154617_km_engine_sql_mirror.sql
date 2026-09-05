-- Kelimeki — oyun motorunun SQL AYNASI (kelime çıkarma, skor, yapısal
-- doğrulama, bölge/vergi). `submit_move` bunları kullanarak istemciden gelen
-- puanı/kelimeleri/vergiyi YOK SAYIP kendisi hesaplayacak.
--
-- ⚠ NEDEN SQL, NEDEN EDGE FUNCTION DEĞİL (5 Eylül 2026, ölçüldü):
-- Motorun zaten Deno'da bir kopyası var (`supabase/functions/_game/`) ve
-- `play-ai-turn` onu kullanıyor — yani "Edge Function'a taşı" ilk bakışta
-- bedava görünüyor. Ölçünce tersi çıktı:
--   * Edge yolu her hamleye BİR AĞ ADIMI daha ekler ve her soğuk isolate'te
--     `wordSet.ts` 63.905 kelimeyi 64 paralel sayfayla belleğe yükler
--     (~1 MB). Bu maliyet YZ turunda kabul edilmişti (oyun başına birkaç
--     kez) ama insan hamlesinin kritik yoluna girerse kullanıcı bekler —
--     nitekim aynı yükleme sıralıyken "takıldı" hissi verdiği bu depoda
--     kayıtlı (28 Temmuz 2026).
--   * SQL yolunda sözlük zaten `public.words` (63.905 satır, `word` PRIMARY
--     KEY). Bir hamlenin oluşturabileceği EN FAZLA 8 kelimenin tamamı için
--     ölçülen süre: 1,1 ms (sıcak; ilk çağrıda 15 ms). Ek gidiş-dönüş YOK,
--     hesap `submit_move`un zaten tuttuğu satır kilitlerinin içinde.
--   * İstemci sözleşmesi DEĞİŞMİYOR: RPC imzası aynı kalıyor, yani Play
--     Store'a çıkmış/kurulu mobil sürümler kırılmıyor, bir "revoke penceresi"
--     beklemek gerekmiyor. Edge yolu her iki istemcinin de göçünü ve eski
--     sürüm kuyruğu erimeden kapatılamayacak bir EXECUTE grant'ini gerektirirdi.
--
-- ⚠ BU MOTORUN DÖRDÜNCÜ KOPYASI. Diğer üçü: src/ (kaynak),
-- supabase/functions/_game/ (Deno), mobile/kelimeki_core/ (Dart). Bu depo
-- üçüncü kopyanın aylarca sessizce ayrıştığını yaşadı ve o yüzden
-- `npm run verify-edge-engine-parity` kapısı var. Bu kopya METİN olarak
-- karşılaştırılamaz (farklı dil), bu yüzden kanıt DAVRANIŞSAL:
-- `npm run verify-sql-engine-parity` gerçek üretim hamlelerini yeniden
-- oynatıp bu fonksiyonların kayıtlı puanı birebir ürettiğini doğrular.
--
-- Sabitler src/game/constants.ts ile birebir: SIZE=13, CORNER=4,
-- BONUS_ZONE=[4..8]², BOARD_CENTER=(6,6) X3, RACK_SIZE=7, BINGO_BONUS=25.

-- ── Tahta yardımcıları ──────────────────────────────────────────────────────

-- Bir taşın GÖRÜNEN harfi (joker ise seçilen harf) — src/utils/board.ts
-- `tileLetter`. Not: taşın `pts`i joker için 0'dır, harfe dönüşse bile.
create or replace function public._km_tile_letter(p_tile jsonb)
returns text language sql immutable as $$
  select case
    when p_tile is null or jsonb_typeof(p_tile) = 'null' then null
    when coalesce((p_tile ->> 'wild')::boolean, false)
      then coalesce(p_tile ->> 'wildLetter', '')
    else p_tile ->> 'letter'
  end;
$$;

-- (r,c)'deki etkin harf: önce bu turun yerleştirmeleri, sonra tahta.
-- `p_placed` "r,c" anahtarlı bir jsonb nesnesi (src'deki `Placed` ile aynı).
create or replace function public._km_letter_at(
  p_board jsonb, p_placed jsonb, p_r int, p_c int
) returns text language sql immutable as $$
  select coalesce(
    public._km_tile_letter(p_placed -> (p_r || ',' || p_c)),
    public._km_tile_letter(p_board -> p_r -> p_c)
  );
$$;

-- (r,c)'den (dr,dc) yönünde uzanan TAM kelime + koordinatları.
-- src/utils/board.ts `fullWordWithCoords` ile birebir: önce başa kadar geri
-- git, sonra sona kadar topla.
create or replace function public._km_full_word(
  p_board jsonb, p_placed jsonb, p_r int, p_c int, p_dr int, p_dc int
) returns jsonb language plpgsql immutable as $$
declare
  v_sr int := p_r;
  v_sc int := p_c;
  v_rr int;
  v_rc int;
  v_word text := '';
  v_coords jsonb := '[]'::jsonb;
  v_letter text;
begin
  while v_sr - p_dr between 0 and 12 and v_sc - p_dc between 0 and 12
        and public._km_letter_at(p_board, p_placed, v_sr - p_dr, v_sc - p_dc) is not null loop
    v_sr := v_sr - p_dr;
    v_sc := v_sc - p_dc;
  end loop;

  v_rr := v_sr;
  v_rc := v_sc;
  loop
    exit when v_rr < 0 or v_rr > 12 or v_rc < 0 or v_rc > 12;
    v_letter := public._km_letter_at(p_board, p_placed, v_rr, v_rc);
    exit when v_letter is null;
    v_word := v_word || v_letter;
    v_coords := v_coords || jsonb_build_array(jsonb_build_array(v_rr, v_rc));
    v_rr := v_rr + p_dr;
    v_rc := v_rc + p_dc;
  end loop;

  return jsonb_build_object('word', v_word, 'coords', v_coords);
end;
$$;

-- Bu turda oluşan tüm kelimeler — src/utils/board.ts `getFormedWords`.
-- Ana kelime yerleştirme yönünde, ardından her yerleştirme için çapraz
-- kelime. 2 harften kısa olanlar atılır; tekrar imzası BAŞLANGIÇ+BİTİŞ
-- hücresidir (aynı hücreden başlayan yatay/dikey iki kelime aynı metni
-- yazsa bile ayrı sayılmalı).
create or replace function public._km_formed_words(p_board jsonb, p_placed jsonb)
returns jsonb language plpgsql immutable as $$
declare
  v_keys text[];
  v_rows int[] := '{}';
  v_horiz boolean;
  v_seen text[] := '{}';
  v_result jsonb := '[]'::jsonb;
  v_key text;
  v_r int;
  v_c int;
  v_first_r int;
  v_first_c int;
  v_fw jsonb;
  v_sig text;
  v_last jsonb;
  v_cdr int;
  v_cdc int;
begin
  v_keys := array(select jsonb_object_keys(p_placed));
  if array_length(v_keys, 1) is null then
    return '[]'::jsonb;
  end if;

  -- Yerleştirmelerin sırası: jsonb_object_keys sırası deterministik değil,
  -- bu yüzden ANA kelimenin başlangıcı olarak src'deki `coords[0]` yerine
  -- yönü satır/sütun tekliğinden buluyoruz; kelime zaten iki uca da
  -- uzatıldığından hangi yerleştirmeden başlandığı sonucu DEĞİŞTİRMEZ.
  foreach v_key in array v_keys loop
    v_r := split_part(v_key, ',', 1)::int;
    if not (v_rows @> array[v_r]) then
      v_rows := v_rows || v_r;
    end if;
  end loop;
  v_horiz := array_length(v_rows, 1) = 1;

  v_first_r := split_part(v_keys[1], ',', 1)::int;
  v_first_c := split_part(v_keys[1], ',', 2)::int;

  -- Ana kelime.
  v_fw := public._km_full_word(
    p_board, p_placed, v_first_r, v_first_c,
    case when v_horiz then 0 else 1 end,
    case when v_horiz then 1 else 0 end
  );
  if char_length(v_fw ->> 'word') >= 2 then
    v_last := (v_fw -> 'coords') -> (jsonb_array_length(v_fw -> 'coords') - 1);
    v_sig := ((v_fw -> 'coords' -> 0 ->> 0) || ',' || (v_fw -> 'coords' -> 0 ->> 1)
              || '-' || (v_last ->> 0) || ',' || (v_last ->> 1));
    v_seen := v_seen || v_sig;
    v_result := v_result || jsonb_build_array(v_fw);
  end if;

  -- Her yerleştirme için çapraz kelime.
  v_cdr := case when v_horiz then 1 else 0 end;
  v_cdc := case when v_horiz then 0 else 1 end;
  foreach v_key in array v_keys loop
    v_r := split_part(v_key, ',', 1)::int;
    v_c := split_part(v_key, ',', 2)::int;
    v_fw := public._km_full_word(p_board, p_placed, v_r, v_c, v_cdr, v_cdc);
    continue when char_length(v_fw ->> 'word') < 2;
    v_last := (v_fw -> 'coords') -> (jsonb_array_length(v_fw -> 'coords') - 1);
    v_sig := ((v_fw -> 'coords' -> 0 ->> 0) || ',' || (v_fw -> 'coords' -> 0 ->> 1)
              || '-' || (v_last ->> 0) || ',' || (v_last ->> 1));
    continue when v_seen @> array[v_sig];
    v_seen := v_seen || v_sig;
    v_result := v_result || jsonb_build_array(v_fw);
  end loop;

  return v_result;
end;
$$;

-- ── Puanlama ────────────────────────────────────────────────────────────────

-- Kelimenin harf puanları toplamı (kelime çarpanı UYGULANMADAN) —
-- src/utils/validator.ts `wordRawPoints`. Puan önce bu turun taşından,
-- yoksa tahtadaki taştan okunur.
create or replace function public._km_word_raw_points(
  p_coords jsonb, p_board jsonb, p_placed jsonb
) returns int language plpgsql immutable as $$
declare
  v_sum int := 0;
  v_i int;
  v_r int;
  v_c int;
  v_tile jsonb;
begin
  for v_i in 0 .. jsonb_array_length(p_coords) - 1 loop
    v_r := (p_coords -> v_i ->> 0)::int;
    v_c := (p_coords -> v_i ->> 1)::int;
    v_tile := p_placed -> (v_r || ',' || v_c);
    if v_tile is null or jsonb_typeof(v_tile) = 'null' then
      v_tile := p_board -> v_r -> v_c;
    end if;
    if v_tile is not null and jsonb_typeof(v_tile) <> 'null' then
      v_sum := v_sum + coalesce((v_tile ->> 'pts')::int, 0);
    end if;
  end loop;
  return v_sum;
end;
$$;

-- Kelimenin bu turdaki YENİ taşlarından biri X3'e (6,6) ya da X2 bölgesine
-- (satır/sütun 4..8) değiyor mu — src/utils/validator.ts `wordBonusFlags`.
-- X3 varsa X2 ile BİRLEŞMEZ.
create or replace function public._km_word_bonus(p_coords jsonb, p_placed jsonb)
returns jsonb language plpgsql immutable as $$
declare
  v_has_tw boolean := false;
  v_zone boolean := false;
  v_i int;
  v_r int;
  v_c int;
  v_new jsonb;
begin
  for v_i in 0 .. jsonb_array_length(p_coords) - 1 loop
    v_r := (p_coords -> v_i ->> 0)::int;
    v_c := (p_coords -> v_i ->> 1)::int;
    v_new := p_placed -> (v_r || ',' || v_c);
    continue when v_new is null or jsonb_typeof(v_new) = 'null';
    if v_r = 6 and v_c = 6 then
      v_has_tw := true;
    end if;
    if v_r between 4 and 8 and v_c between 4 and 8 then
      v_zone := true;
    end if;
  end loop;
  return jsonb_build_object('x2', (not v_has_tw) and v_zone, 'x3', v_has_tw);
end;
$$;

-- Her kelimenin ham puanı + bonus bayrakları — `calcWordRawScores` aynası.
-- submit_move'un `bestWordScore` hesabı bu çıktıyı olduğu gibi tüketiyor.
create or replace function public._km_word_scores(p_board jsonb, p_placed jsonb)
returns jsonb language plpgsql immutable as $$
declare
  v_words jsonb := public._km_formed_words(p_board, p_placed);
  v_out jsonb := '[]'::jsonb;
  v_i int;
  v_fw jsonb;
  v_bonus jsonb;
begin
  for v_i in 0 .. jsonb_array_length(v_words) - 1 loop
    v_fw := v_words -> v_i;
    v_bonus := public._km_word_bonus(v_fw -> 'coords', p_placed);
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'word', v_fw ->> 'word',
      'score', public._km_word_raw_points(v_fw -> 'coords', p_board, p_placed),
      'x2', v_bonus -> 'x2',
      'x3', v_bonus -> 'x3'
    ));
  end loop;
  return v_out;
end;
$$;

-- Turun toplam puanı — `calcScore` aynası: Σ (ham puan × çarpan) + bingo.
create or replace function public._km_calc_score(p_board jsonb, p_placed jsonb)
returns int language plpgsql immutable as $$
declare
  v_words jsonb := public._km_formed_words(p_board, p_placed);
  v_total int := 0;
  v_i int;
  v_fw jsonb;
  v_bonus jsonb;
  v_mult int;
begin
  for v_i in 0 .. jsonb_array_length(v_words) - 1 loop
    v_fw := v_words -> v_i;
    v_bonus := public._km_word_bonus(v_fw -> 'coords', p_placed);
    v_mult := case
      when (v_bonus ->> 'x3')::boolean then 3
      when (v_bonus ->> 'x2')::boolean then 2
      else 1
    end;
    v_total := v_total + public._km_word_raw_points(v_fw -> 'coords', p_board, p_placed) * v_mult;
  end loop;
  -- BINGO_BONUS: raf tamamen kullanıldıysa (RACK_SIZE=7).
  if (select count(*) from jsonb_object_keys(p_placed)) >= 7 then
    v_total := v_total + 25;
  end if;
  return v_total;
end;
$$;
