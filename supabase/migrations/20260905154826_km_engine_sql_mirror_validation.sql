-- Kelimeki — motorun SQL aynası, 2. bölüm: YAPISAL DOĞRULAMA + SÖZLÜK.
-- 1. bölüm (kelime çıkarma + skor) için bkz. 20260905154617_km_engine_sql_mirror.sql;
-- oradaki "neden SQL, neden Edge Function değil" gerekçesi burası için de geçerli.
--
-- Bu bölüm, `submit_move`un bugün HİÇ yapmadığı kontrolü ekliyor: bir hamlenin
-- KURALLARA UYGUN olup olmadığı. Bugün sunucu yalnızca "hücre boş mu" ve "taş
-- gerçekten rafında mı" diye soruyor — yani meşru bir katılımcı taşlarını
-- tahtaya dağınık serpebilir, hiçbir kelime oluşturmayabilir, sözlükte olmayan
-- bir dizi yazabilir. Aynalar src/utils/validator.ts'teki
-- `validatePlacementStructural` + sözlük kapısıdır; ayrım (yapısal ↔ sözlük)
-- bilerek korundu.

-- Köşe bölgesinin satır/sütun aralığı — src/game/constants.ts `cornerBounds`.
-- 0 = sol-üst, 1 = sağ-üst, 2 = sol-alt, 3 = sağ-alt (SIZE=13, CORNER=4 →
-- üst köşeler 0..3, alt köşeler 9..12).
create or replace function public._km_corner_bounds(p_corner int)
returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'r0', case when p_corner in (0,1) then 0 else 9 end,
    'r1', case when p_corner in (0,1) then 3 else 12 end,
    'c0', case when p_corner in (0,2) then 0 else 9 end,
    'c1', case when p_corner in (0,2) then 3 else 12 end
  );
$$;

-- Köşenin en uç (tek) hücresi — `cornerCell`; ilk hamlenin değmesi zorunlu
-- "ev" karesi. Board'da HomeMark ile gösterilen hücre.
create or replace function public._km_corner_cell(p_corner int)
returns jsonb language sql immutable as $$
  select jsonb_build_array(
    case when p_corner in (0,1) then 0 else 12 end,
    case when p_corner in (0,2) then 0 else 12 end
  );
$$;

-- Oyuncunun HENÜZ kendi taşını koymadığı köşeleri — `freshCorners`.
create or replace function public._km_fresh_corners(
  p_board jsonb, p_own_corners jsonb, p_owner int
) returns int[] language plpgsql immutable as $$
declare
  v_out int[] := '{}';
  v_i int; v_corner int; v_b jsonb; v_r int; v_c int;
  v_used boolean; v_cell jsonb;
begin
  for v_i in 0 .. jsonb_array_length(p_own_corners) - 1 loop
    v_corner := (p_own_corners ->> v_i)::int;
    v_b := public._km_corner_bounds(v_corner);
    v_used := false;
    for v_r in (v_b ->> 'r0')::int .. (v_b ->> 'r1')::int loop
      for v_c in (v_b ->> 'c0')::int .. (v_b ->> 'c1')::int loop
        v_cell := p_board -> v_r -> v_c;
        if v_cell is not null and jsonb_typeof(v_cell) <> 'null'
           and (v_cell ->> 'owner')::int = p_owner then
          v_used := true; exit;
        end if;
      end loop;
      exit when v_used;
    end loop;
    if not v_used then v_out := v_out || v_corner; end if;
  end loop;
  return v_out;
end;
$$;

-- Yapısal doğrulama — `validatePlacementStructural` aynası.
-- Dönüş: null = geçerli, aksi halde kullanıcıya gösterilecek Türkçe gerekçe
-- (metinler src'dekiyle BİREBİR — iki yüzey aynı hatayı aynı cümleyle
-- anlatmalı). Sözlük kontrolü burada YOK, ayrı fonksiyonda.
create or replace function public._km_validate_structural(
  p_board jsonb, p_placed jsonb, p_owner int, p_own_corners jsonb, p_is_first boolean
) returns text language plpgsql stable as $$
declare
  v_keys text[]; v_key text;
  v_rows int[] := '{}'; v_cols int[] := '{}';
  v_horiz boolean; v_vert boolean;
  v_r int; v_c int; v_min int; v_max int; v_i int;
  v_fresh int[]; v_corner int; v_cc jsonb;
  v_starts_fresh boolean := false;
  v_connects boolean := false;
  v_cell jsonb;
begin
  v_keys := array(select jsonb_object_keys(p_placed));
  if array_length(v_keys, 1) is null then
    return 'Harf yerleştirilmedi.';
  end if;

  foreach v_key in array v_keys loop
    v_r := split_part(v_key, ',', 1)::int;
    v_c := split_part(v_key, ',', 2)::int;
    if not (v_rows @> array[v_r]) then v_rows := v_rows || v_r; end if;
    if not (v_cols @> array[v_c]) then v_cols := v_cols || v_c; end if;
  end loop;
  v_horiz := array_length(v_rows, 1) = 1;
  v_vert := array_length(v_cols, 1) = 1;
  if not v_horiz and not v_vert then
    return 'Harfler aynı satır ya da sütunda olmalı.';
  end if;

  -- Süreklilik: uçlar arasındaki her hücre ya bu tur konmuş ya tahtada olmalı.
  if v_horiz then
    v_r := v_rows[1];
    select min(x), max(x) into v_min, v_max from unnest(v_cols) x;
    for v_c in v_min .. v_max loop
      v_cell := p_board -> v_r -> v_c;
      if (p_placed -> (v_r || ',' || v_c)) is null
         and (v_cell is null or jsonb_typeof(v_cell) = 'null') then
        return 'Harfler arasında boşluk bırakılamaz.';
      end if;
    end loop;
  else
    v_c := v_cols[1];
    select min(x), max(x) into v_min, v_max from unnest(v_rows) x;
    for v_r in v_min .. v_max loop
      v_cell := p_board -> v_r -> v_c;
      if (p_placed -> (v_r || ',' || v_c)) is null
         and (v_cell is null or jsonb_typeof(v_cell) = 'null') then
        return 'Harfler arasında boşluk bırakılamaz.';
      end if;
    end loop;
  end if;

  -- Kullanılmamış köşesinin EV karesine değiyor mu?
  v_fresh := public._km_fresh_corners(p_board, p_own_corners, p_owner);
  foreach v_key in array v_keys loop
    v_r := split_part(v_key, ',', 1)::int;
    v_c := split_part(v_key, ',', 2)::int;
    if v_fresh is not null then
      foreach v_corner in array v_fresh loop
        v_cc := public._km_corner_cell(v_corner);
        if v_r = (v_cc ->> 0)::int and v_c = (v_cc ->> 1)::int then
          v_starts_fresh := true; exit;
        end if;
      end loop;
    end if;
    exit when v_starts_fresh;
  end loop;

  if p_is_first then
    if not v_starts_fresh then
      return 'İlk kelimen kendi köşe karesine değmeli.';
    end if;
  else
    -- Bağlanmıyorsa, henüz kullanılmamış bir köşeden bağımsız yeni bir
    -- kelimeyle başlamak da (ilk hamledeki gibi) geçerlidir.
    foreach v_key in array v_keys loop
      v_r := split_part(v_key, ',', 1)::int;
      v_c := split_part(v_key, ',', 2)::int;
      for v_i in 1 .. 4 loop
        declare
          v_nr int := v_r + case v_i when 1 then -1 when 2 then 1 else 0 end;
          v_nc int := v_c + case v_i when 3 then -1 when 4 then 1 else 0 end;
        begin
          continue when v_nr < 0 or v_nr > 12 or v_nc < 0 or v_nc > 12;
          v_cell := p_board -> v_nr -> v_nc;
          if v_cell is not null and jsonb_typeof(v_cell) <> 'null' then
            v_connects := true; exit;
          end if;
        end;
      end loop;
      exit when v_connects;
    end loop;
    if not v_connects and not v_starts_fresh then
      return 'Kelime mevcut harflere bağlanmalı.';
    end if;
  end if;

  if jsonb_array_length(public._km_formed_words(p_board, p_placed)) = 0 then
    return 'Geçerli kelime oluşmadı.';
  end if;

  return null;
end;
$$;

-- Sözlük kapısı: oluşan kelimelerin HEPSİ `public.words`ta olmalı.
-- `is_valid_word` zaten Türkçe küçültmeyi (İ→i, I→ı) yapıyor.
-- Mesaj biçimi `formatInvalidWordsReason` ile aynı.
create or replace function public._km_validate_words(p_board jsonb, p_placed jsonb)
returns text language plpgsql stable as $$
declare
  v_words jsonb := public._km_formed_words(p_board, p_placed);
  v_bad text[] := '{}';
  v_i int; v_w text; v_list text;
begin
  for v_i in 0 .. jsonb_array_length(v_words) - 1 loop
    v_w := v_words -> v_i ->> 'word';
    if not public.is_valid_word(v_w) then
      v_bad := v_bad || ('"' || v_w || '"');
    end if;
  end loop;
  if array_length(v_bad, 1) is null then return null; end if;
  if array_length(v_bad, 1) = 1 then
    return v_bad[1] || ' geçerli bir kelime değil.';
  end if;
  v_list := array_to_string(v_bad[1:array_length(v_bad,1)-1], ', ')
            || ' ve ' || v_bad[array_length(v_bad,1)];
  return v_list || ' geçerli kelimeler değil.';
end;
$$;
