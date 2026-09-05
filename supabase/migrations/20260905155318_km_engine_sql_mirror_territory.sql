-- Kelimeki — motorun SQL aynası, 3. bölüm: BÖLGE ve BÖLGE VERGİSİ.
-- 1-2. bölüm için bkz. 20260905154617 / 20260905154826.
--
-- Bu bölüm ROADMAP #18'in en pahalı parçası: vergiyi sunucuda hesaplayabilmek
-- için tüm bölgeleri (computeAllTerritories) yeniden kurmak gerekiyor. Vergi
-- sunucuda hesaplanmazsa, bir katılımcı `p_lost_shares`i boş göndererek
-- vergiyi tamamen kaçırabilir (kazandığı puanın ~1/3'ünü fazladan tutar).
--
-- ⚠ `_km_invasion_split` `_km_all_territories`i çağırıyor ama o BİR SONRAKİ
-- migration'da (20260905155347) tanımlı. Sıra sorun değil: plpgsql gövdeleri
-- oluşturma anında çözülmez, çağrı çalışma zamanında bağlanır. İlk uygulanan
-- sürümde `_km_all_territories` burada, ölü bir döngüyle birlikteydi;
-- dosyaya nihai (temizlenmiş) gövdesiyle bir sonraki migration'a yazıldı ki
-- taze bir veritabanı ölü kodu hiç görmesin.

create or replace function public._km_conquered_chain(
  p_board jsonb, p_own_corners jsonb, p_owner int, p_supported jsonb default null
) returns jsonb language plpgsql immutable as $$
declare
  v_chain jsonb := '{}'::jsonb;
  v_visited jsonb := '{}'::jsonb;
  v_stack text[] := '{}';
  v_i int; v_corner int; v_b jsonb;
  v_r int; v_c int; v_k text; v_cell jsonb;
  v_foe jsonb; v_foe_owner text;
  v_top text; v_n int; v_nr int; v_nc int; v_nk text; v_ncell jsonb;
begin
  for v_i in 0 .. jsonb_array_length(p_own_corners) - 1 loop
    v_corner := (p_own_corners ->> v_i)::int;
    v_b := public._km_corner_bounds(v_corner);
    for v_r in (v_b ->> 'r0')::int .. (v_b ->> 'r1')::int loop
      for v_c in (v_b ->> 'c0')::int .. (v_b ->> 'c1')::int loop
        v_k := v_r || ',' || v_c;
        v_cell := p_board -> v_r -> v_c;
        if v_cell is not null and jsonb_typeof(v_cell) <> 'null'
           and (v_cell ->> 'owner')::int is distinct from p_owner then
          v_foe_owner := v_cell ->> 'owner';
          if p_supported is null or v_foe_owner is null then
            v_foe := null;
          else
            v_foe := p_supported -> v_foe_owner::int;
          end if;
          continue when v_foe is null or (v_foe ? v_k);
          if not (v_visited ? v_k) then
            v_visited := v_visited || jsonb_build_object(v_k, true);
            v_stack := v_stack || v_k;
          end if;
          continue;
        end if;
        if not (v_visited ? v_k) then
          v_visited := v_visited || jsonb_build_object(v_k, true);
          v_chain := v_chain || jsonb_build_object(v_k, true);
          v_stack := v_stack || v_k;
        end if;
      end loop;
    end loop;
  end loop;

  while array_length(v_stack, 1) > 0 loop
    v_top := v_stack[array_length(v_stack, 1)];
    v_stack := v_stack[1 : array_length(v_stack, 1) - 1];
    v_r := split_part(v_top, ',', 1)::int;
    v_c := split_part(v_top, ',', 2)::int;
    for v_n in 1 .. 4 loop
      v_nr := v_r + case v_n when 1 then -1 when 2 then 1 else 0 end;
      v_nc := v_c + case v_n when 3 then -1 when 4 then 1 else 0 end;
      continue when v_nr < 0 or v_nr > 12 or v_nc < 0 or v_nc > 12;
      v_nk := v_nr || ',' || v_nc;
      continue when v_visited ? v_nk;
      v_ncell := p_board -> v_nr -> v_nc;
      if v_ncell is not null and jsonb_typeof(v_ncell) <> 'null'
         and (v_ncell ->> 'owner')::int = p_owner then
        v_visited := v_visited || jsonb_build_object(v_nk, true);
        v_chain := v_chain || jsonb_build_object(v_nk, true);
        v_stack := v_stack || v_nk;
      end if;
    end loop;
  end loop;

  return v_chain;
end;
$$;

create or replace function public._km_invasion_split(
  p_coords jsonb, p_owner int, p_players jsonb, p_base_pts int, p_board jsonb
) returns jsonb language plpgsql immutable as $$
declare
  v_terr jsonb := public._km_all_territories(p_board, p_players);
  v_n int := jsonb_array_length(p_players);
  v_touched int[] := '{}';
  v_i int; v_j int; v_r int; v_c int; v_nr int; v_nc int; v_k text; v_d int;
  v_cnt int; v_share int; v_shares jsonb := '[]'::jsonb;
begin
  for v_i in 0 .. jsonb_array_length(p_coords) - 1 loop
    v_r := (p_coords -> v_i ->> 0)::int;
    v_c := (p_coords -> v_i ->> 1)::int;
    for v_d in 0 .. 4 loop
      v_nr := v_r + case v_d when 1 then -1 when 2 then 1 else 0 end;
      v_nc := v_c + case v_d when 3 then -1 when 4 then 1 else 0 end;
      continue when v_nr < 0 or v_nr > 12 or v_nc < 0 or v_nc > 12;
      v_k := v_nr || ',' || v_nc;
      for v_j in 0 .. v_n - 1 loop
        continue when v_j = p_owner;
        if (v_terr -> v_j) ? v_k and not (v_touched @> array[v_j]) then
          v_touched := v_touched || v_j;
        end if;
      end loop;
    end loop;
  end loop;

  v_cnt := coalesce(array_length(v_touched, 1), 0);
  if v_cnt = 0 then
    return jsonb_build_object('pts', p_base_pts, 'shares', '[]'::jsonb);
  end if;
  v_share := round((p_base_pts::numeric * (v_cnt + 1)) / (6 * v_cnt))::int;
  foreach v_i in array (select array_agg(x order by x) from unnest(v_touched) x) loop
    v_shares := v_shares || jsonb_build_array(jsonb_build_object('to', v_i, 'amount', v_share));
  end loop;
  return jsonb_build_object('pts', p_base_pts - v_share * v_cnt, 'shares', v_shares);
end;
$$;
