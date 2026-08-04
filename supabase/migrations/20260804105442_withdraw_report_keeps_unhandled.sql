-- Kelimeki — rapor geri çekilince artık "handled" otomatik true olmuyor.
-- Kullanıcı geri bildirimi: geri çekilmiş bir rapor admin ekranında hâlâ
-- "okunmamış" (Yeni) sayılmalı ki admin ne yaşandığını görsün, isterse
-- detaylı incelesin, isterse kendisi okundu işaretlesin — withdraw'ın
-- kendisi bir "inceleme" değil, yalnızca raporlayanın kendi kararı.
-- Rozet zaten withdrawn_at'e öncelik verip "Geri Çekildi" gösteriyor
-- (AdminDashboard.tsx) — bu değişiklik yalnızca `handled`i (dolayısıyla
-- soluklaşma + admin_get_pending_count'a dahil olma) etkiliyor.
create or replace function public.withdraw_online_game_chat_reports(
  p_game_id uuid,
  p_target_user_id uuid
) returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Oturum açık değil.';
  end if;

  update public.online_game_chat_reports
  set withdrawn_at = now()
  where online_game_id = p_game_id
    and reporter_user_id = auth.uid()
    and reported_user_id = p_target_user_id
    and withdrawn_at is null;
end;
$$;

-- Geriye dönük düzeltme: bu migration'dan önce withdraw sırasında
-- otomatik handled=true olmuş, admin tarafından hiç ayrıca incelenmemiş
-- raporları "okunmamış"a geri döndür. Sadece iki test satırı var (bkz.
-- doğrulama notu) — gerçek bir admin incelemesinden geçip geçmediğini
-- ayırt edecek ayrı bir iz olmadığından, hepsi geri alınıyor.
update public.online_game_chat_reports
set handled = false
where withdrawn_at is not null
  and handled = true;
