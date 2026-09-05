-- Kelimeki — ROADMAP #18 gölge fazı: KAPSAM SAYACI (payda).
--
-- NEDEN (5 Eylül 2026, ölçüldü): gölge fazının çıkış kapısı "move_shadow_diffs
-- BOŞ kalsın" diye yazılmıştı. Ama boş bir tablo İKİ ANLAMA gelir ve ikisi
-- birbirinin tam zıddı:
--
--   (a) sunucu motoru istemciyle birebir uyuştu  → zorlamaya geçilebilir
--   (b) o koddan hiç hamle geçmedi (ya da sensör öldü) → HİÇBİR ŞEY bilinmiyor
--
-- Tablo tek başına ikisini AYIRAMIYOR. Gölge fazı canlıya alındıktan ~1 saat
-- sonra ölçüldüğünde gerçek durum buydu: 0 sapma, ama PAYDA yalnızca **10
-- hamle** (7 oyun, 6 oyuncu) — ve ROADMAP'in "cihazda ayrıca sına" dediği
-- riskli yolların TAMAMI sıfır kapsamlıydı (0 vergili hamle, 0 joker bitişi,
-- 0 bingo). Yani kapı nominal olarak açıktı, kanıt olarak boştu.
--
-- Bu tablo paydayı KAYDA GEÇİRİR: her gölge kontrolü bir gün satırını artırır,
-- ve riskli yolları AYRI AYRI sayar. Böylece "boş" iddiası kendi kendini
-- kanıtlar hâle gelir ve zorlama kararı ölçüye bağlanır, tahmine değil.
--
-- ⚠ SAYAÇ ASLA GERÇEK HAMLEYİ ETKİLEYEMEZ: artırım kendi iç exception bloğuyla
-- sarılı — sayaçtaki bir hata ne hamleyi bozar ne de `move_shadow_diffs`e
-- sahte bir 'hata' satırı yazdırır.

create table if not exists public.move_shadow_coverage (
  gun date primary key default current_date,
  hamle int not null default 0,          -- gölge kontrolünden geçen TOPLAM hamle (payda)
  cok_oyunculu int not null default 0,   -- 3+ oyunculu masa (bölge etkileşimi burada zorlaşır)
  vergi int not null default 0,          -- bölge vergisi doğuran hamle
  joker int not null default 0,          -- joker taş içeren hamle
  teslim_var int not null default 0,     -- masada teslim olmuş oyuncu varken oynanan hamle
  blokta_rakip int not null default 0    -- oyuncunun KENDİ 4x4 bloğunda rakip taşı
                                         -- (24 Ağustos "iletken hücre" kuralının ÖN KOŞULU)
);

comment on table public.move_shadow_coverage is
  'ROADMAP #18 gölge fazının PAYDASI — move_shadow_diffs "boş" derken kaç hamlenin gerçekten kontrol edildiğini ve riskli yolların kaç kez geçildiğini gösterir. Zorlama fazına geçiş bu sayaçlara bakılarak verilir.';

alter table public.move_shadow_coverage enable row level security;
-- Politika YOK: anon/authenticated göremez. Yazım SECURITY DEFINER içinden.
revoke all on public.move_shadow_coverage from anon, authenticated;

-- `blokta_rakip` yardımcısı: oyuncunun kendi köşe blok(lar)ının içinde,
-- SAHİBİ KENDİSİ OLMAYAN bir taş var mı. İletken hücre kuralı yalnızca bu
-- koşul sağlandığında devreye girebilir — kuralın "yükte" olup olmadığını
-- kanıtlamaz, ama sıfırsa kuralın HİÇ denenmediğini kesin olarak gösterir.
create or replace function public._km_foe_in_own_block(
  p_board jsonb, p_own_corners jsonb, p_owner int
) returns boolean language plpgsql immutable as $$
declare
  v_i int; v_corner int; v_b jsonb; v_r int; v_c int; v_cell jsonb;
begin
  for v_i in 0 .. jsonb_array_length(coalesce(p_own_corners, '[]'::jsonb)) - 1 loop
    v_corner := (p_own_corners ->> v_i)::int;
    v_b := public._km_corner_bounds(v_corner);
    for v_r in (v_b ->> 'r0')::int .. (v_b ->> 'r1')::int loop
      for v_c in (v_b ->> 'c0')::int .. (v_b ->> 'c1')::int loop
        v_cell := p_board -> v_r -> v_c;
        if v_cell is not null and jsonb_typeof(v_cell) <> 'null'
           and (v_cell ->> 'owner')::int is distinct from p_owner then
          return true;
        end if;
      end loop;
    end loop;
  end loop;
  return false;
end;
$$;

revoke all on function public._km_foe_in_own_block(jsonb, jsonb, int) from anon, authenticated;
