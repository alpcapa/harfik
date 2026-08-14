-- Kelimeki — `withdraw_online_game_chat_reports`: 4 Ağustos 2026'daki
-- "handled otomatik true olmasın" düzeltmesi YANLIŞ overload'a uygulanmış.
--
-- Zincir:
--  * 3 Ağustos (`person_scoped_chat_moderation`): 2-arg imza (uuid, uuid)
--    DROP edildi, kişi-bazlı 1-arg (p_target_user_id) yaratıldı — o günkü
--    `set withdrawn_at = now(), handled = true` gövdesiyle (o gün doğruydu,
--    handled sorunu henüz bulunmamıştı).
--  * 4 Ağustos (`withdraw_report_keeps_unhandled`): düzeltme
--    `create or replace ... (p_game_id uuid, p_target_user_id uuid)` ile
--    yazıldı — yani bir gün önce SİLİNEN 2-arg imzayı YENİDEN YARATTI ve
--    düzeltmeyi ona uyguladı. İstemcilerin çağırdığı 1-arg sürüme hiç
--    dokunmadı.
--
-- İstemciler yalnız `p_target_user_id` geçiyor (web `src/lib/api.ts`,
-- mobil `mobile/app/lib/src/data/chat_api.dart`), yani üretimde HÂLÂ
-- `handled = true` yapan sürüm çağrılıyor: geri çekilen bir şikayet
-- admin'in bekleyen-iş sayacından (`fetchAdminPendingCount`) düşüyor ve
-- panelde soluklaşıyor — tam da 4 Ağustos'ta düzeltilmek istenen davranış
-- (geri çekme raporlayanın kararıdır, admin'in İNCELEMESİ değildir).
--
-- Veri durumu (uygulamadan önce ölçüldü): bozulmuş satır YOK. Son geri
-- çekme 2026-08-04 10:49, 4 Ağustos migration'ı 10:54'te backfill yapmıştı;
-- o tarihten beri hiç geri çekme olmadığından hata bugüne kadar UYKUDA
-- kaldı. Bu yüzden geriye dönük bir düzeltme (backfill) GEREKMİYOR —
-- `handled = true` olan iki geri çekilmiş satır, backfill'den SONRA admin
-- tarafından gerçekten okundu işaretlenmiş durumda, onlara dokunmak
-- gerçek bir incelemeyi geri almak olurdu.

-- 1) İstemcilerin çağırdığı sürüm: `handled`'a artık dokunmuyor.
create or replace function public.withdraw_online_game_chat_reports(
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
  where reporter_user_id = auth.uid()
    and reported_user_id = p_target_user_id
    and withdrawn_at is null;
end;
$$;

-- 2) Hortlak 2-arg overload'u düşür. Kimse çağırmıyor (iki istemci de tek
-- argüman geçiyor) ve 4 Ağustos dosyasında `revoke` olmadığından EXECUTE'u
-- PUBLIC+anon dahil herkeste kalmış — projenin "yeni fonksiyonda önce
-- revoke all" kuralına aykırı bir kalıntı. Ayrıca iki overload birlikte
-- durduğu sürece PostgREST'in hangisini seçtiği argüman sayısına bağlı
-- kalıyor; tek imza bırakmak bu belirsizliği de kapatıyor.
drop function if exists public.withdraw_online_game_chat_reports (uuid, uuid);
