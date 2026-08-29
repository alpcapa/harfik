-- Skor kartındaki "Y:59/C:E" satırını BAŞKALARININ kartında da gösterebilmek
-- için (29 Ağustos 2026, kullanıcı isteği: "Yaş ve cinsiyet tüm kişi skor
-- kartlarında ismin altında olmalı. Kendi profilimde görmemin hiç bir mantığı
-- ve faydası yok. Skor kartlar herkes tarafından görülebiliyor ve bu da
-- görünmeli").
--
-- Neden bir RPC: `profiles`in SELECT RLS'i kilitli — bir kullanıcı yalnızca
-- KENDİ satırını okuyabiliyor. Bu yüzden satır bugüne kadar yalnızca kendi
-- kartında çizilebiliyordu; başkasının kartını besleyen kaynakların
-- (leaderboard view'ı, list_friends, game_likers, online_game oyuncuları,
-- admin_list_members) hiçbiri bu iki alanı taşımıyor.
--
-- ⚠ Neden `birth_date` DEĞİL `age`: kart yalnızca yaşı gösteriyor, doğum
-- GÜNÜ hiçbir yerde kullanılmıyor. Tam tarihi yayınlamak gösterilenden fazla
-- veri açardı (ve doğum günü kimlik doğrulamada sık kullanılan bir alan);
-- fonksiyon türetilmiş tam sayıyı döndürüyor, ham tarih sunucuda kalıyor.
--
-- Yaş hesabı istemcideki `calculateAge`/`_age` ile AYNI tanım olmak zorunda:
-- "tamamlanmış yıl" — doğum günü bu yıl henüz geçmediyse bir eksik.
-- `age(current_date, birth_date)` tam da bunu verir.
create or replace function public.get_profile_age_gender(p_user_id uuid)
returns table (age int, gender text)
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when p.birth_date is null then null
      else extract(year from age(current_date, p.birth_date))::int
    end,
    p.gender
  from profiles p
  where p.id = p_user_id;
$$;

-- Skor kartı MİSAFİRE de açık (k-lig listesi ve player_stats view'ları anon'a
-- SELECT veriyor, satıra tıklamak oturum istemiyor) — yetkiyi o yüzeyle
-- hizalıyoruz, aksi halde kart girişliyle misafirde farklı görünürdü.
revoke all on function public.get_profile_age_gender(uuid) from public;
grant execute on function public.get_profile_age_gender(uuid) to anon, authenticated;
