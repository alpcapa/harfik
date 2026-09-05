-- Kelimeki — `computeAllTerritories` aynası (motorun SQL kopyası, 4/4).
-- Bir önceki migration'daki ilk sürümde ölü bir döngü vardı; nihai gövde bu.
--
-- İKİ GEÇİŞ ve SIRASI ÖNEMLİ — src/utils/validator.ts'teki uzun yorumun
-- gerekçesi burada da geçerli: ön geçiş her oyuncunun SAF zincirini (yalnızca
-- kendi taşları) hesaplar; ikinci geçiş "bu rakip taşı gerçekten rakibin
-- bölgesine bağlı mı" sorusunu O saf zincire sorar. Kapıyı ikinci geçişin
-- kendi sonucuna sormak dairesel olurdu (A'nın zinciri B'ninkine, B'ninki
-- A'nınkine bağlı).
--
-- ⚠ İLETKEN HÜCRE (24 Ağustos 2026 kural değişikliği): kendi 4×4 bloğunun
-- içindeki, rakibin KENDİ zincirine bağlı OLMAYAN bir rakip taşı zinciri
-- kesmez — üzerinden geçilir ama zincire ÜYE OLMAZ. Üye olsaydı aynı hücre
-- iki oyuncunun bölgesine birden girip "bölgeler asla çakışmaz" değişmezini
-- kırardı.
--
-- Bu kuralın canlı verideki izi ÖLÇÜLDÜ: 2.641 gerçek hamle yeniden
-- oynatıldığında yalnızca 3 hamlede kayıtlı vergi ile bu ayna ayrışıyor ve
-- üçünde de ESKİ kural kayıtlı değeri birebir üretiyor (10 ve 12 Ağustos ile
-- 24 Ağustos'ta, kural yayınlanmadan önce oynanmış hamleler). Yani ayrışma
-- aynanın hatası değil, tarihin kendisi.

create or replace function public._km_all_territories(p_board jsonb, p_players jsonb)
returns jsonb language plpgsql immutable as $$
declare
  v_n int := jsonb_array_length(p_players);
  v_supported jsonb := '[]'::jsonb;
  v_chains jsonb := '[]'::jsonb;
  v_out jsonb := '[]'::jsonb;
  v_i int; v_ci int; v_p jsonb;
  v_terr jsonb; v_corner int; v_b jsonb; v_r int; v_c int; v_k text;
  v_captured boolean;
begin
  -- 1. geçiş: SAF zincirler (yalnızca kendi taşları).
  for v_i in 0 .. v_n - 1 loop
    v_p := p_players -> v_i;
    if coalesce((v_p ->> 'surrendered')::boolean, false) then
      v_supported := v_supported || jsonb_build_array('{}'::jsonb);
    else
      v_supported := v_supported || jsonb_build_array(
        public._km_conquered_chain(p_board, coalesce(v_p -> 'corners', '[]'::jsonb), v_i, null));
    end if;
  end loop;

  -- 2. geçiş: "bu rakip taşı destekli mi" sorusu SAF zincire sorulur.
  for v_i in 0 .. v_n - 1 loop
    v_p := p_players -> v_i;
    if coalesce((v_p ->> 'surrendered')::boolean, false) then
      v_chains := v_chains || jsonb_build_array('{}'::jsonb);
    else
      v_chains := v_chains || jsonb_build_array(
        public._km_conquered_chain(p_board, coalesce(v_p -> 'corners', '[]'::jsonb), v_i, v_supported));
    end if;
  end loop;

  -- Taban iddia: kendi köşe bloğunun, BAŞKA hiçbir oyuncunun zincirine
  -- girmemiş hücreleri de bölgeye eklenir. Teslim olan oyuncunun bölgesi
  -- (kendi köşesi dahil) boş kalır — doğal/sahipsiz alana döner.
  for v_i in 0 .. v_n - 1 loop
    v_p := p_players -> v_i;
    if coalesce((v_p ->> 'surrendered')::boolean, false) then
      v_out := v_out || jsonb_build_array('{}'::jsonb);
      continue;
    end if;
    v_terr := v_chains -> v_i;
    for v_ci in 0 .. jsonb_array_length(coalesce(v_p -> 'corners', '[]'::jsonb)) - 1 loop
      v_corner := (v_p -> 'corners' ->> v_ci)::int;
      v_b := public._km_corner_bounds(v_corner);
      for v_r in (v_b ->> 'r0')::int .. (v_b ->> 'r1')::int loop
        for v_c in (v_b ->> 'c0')::int .. (v_b ->> 'c1')::int loop
          v_k := v_r || ',' || v_c;
          continue when v_terr ? v_k;
          select bool_or((v_chains -> g) ? v_k) into v_captured
          from generate_series(0, v_n - 1) g where g <> v_i;
          if not coalesce(v_captured, false) then
            v_terr := v_terr || jsonb_build_object(v_k, true);
          end if;
        end loop;
      end loop;
    end loop;
    v_out := v_out || jsonb_build_array(v_terr);
  end loop;

  return v_out;
end;
$$;
