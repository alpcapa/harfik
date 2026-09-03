-- Okuma: `security definer` DEĞİL (invoker). Gerek yok — çağıran kendi `games`
-- satırlarını zaten okuyabiliyor, `game_finish_seen`de de yalnızca kendi
-- satırlarını görüyor. En az ayrıcalık ilkesi.
create or replace function public.unseen_finished_online_games()
returns setof uuid
language sql
stable
set search_path to 'public'
as $$
  select g.id
  from public.games g
  left join public.game_finish_seen s on s.game_id = g.id
  where g.user_id = auth.uid()
    and g.online_game_id is not null
    and s.game_id is null
  order by g.created_at desc;
$$;

-- İşaretleme: RLS'te yazma politikası YOK, bu yüzden definer.
--   p_online_game_id null  → benim TÜM görülmemiş bitmiş Canlı oyunlarım
--                            ("Son Oynananlar" sekmesi ziyaret edildi)
--   p_online_game_id dolu  → yalnızca o oyun (bitiş modalı gösterildi)
--
-- İkinci yol ŞART: yalnızca toplu işaretleme olsaydı, oyunu bitiren hamleyi
-- yapan kişi (bitiş modalını GÖREN kişi) kendi oyunu için de rozet alırdı.
-- Tersi de geçerli: bitiş modalında toplu işaretleme yapmak, o sırada
-- görülmemiş BAŞKA oyunları da sessizce silerdi.
create or replace function public.mark_game_finishes_seen(
  p_online_game_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_count integer;
begin
  -- ⚠ GÜVENLİK SINIRI: `g.user_id = auth.uid()`. Anon çağrıda auth.uid()
  -- null olduğundan hiçbir satır eşleşmez (canlıda doğrulandı: yabancı bir
  -- kimlik 0 satır yazıyor ve 0 satır görüyor).
  insert into public.game_finish_seen (game_id, user_id)
  select g.id, g.user_id
  from public.games g
  where g.user_id = auth.uid()
    and g.online_game_id is not null
    and (p_online_game_id is null or g.online_game_id = p_online_game_id)
  on conflict (game_id) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.unseen_finished_online_games() from public;
revoke all on function public.mark_game_finishes_seen(uuid) from public;
-- ⚠ "revoke ... from public" anon'u KALDIRMAZ: Supabase'in
-- `alter default privileges` ayarı yeni fonksiyonlara anon için de EXECUTE
-- veriyor ve bu AYRI bir grant. 3 Eylül 2026'da kafa kafaya RPC'sinde
-- öğrenildi (ikinci bir migration gerekmişti) — bu kez aynı migration'da.
revoke execute on function public.unseen_finished_online_games() from anon;
revoke execute on function public.mark_game_finishes_seen(uuid) from anon;
grant execute on function public.unseen_finished_online_games() to authenticated;
grant execute on function public.mark_game_finishes_seen(uuid) to authenticated;
