-- Avatar değiştirme 20 Temmuz 2026'dan beri KIRIKTI — sahibe kendi
-- klasörü için SELECT hakkı geri veriliyor.
--
-- ZİNCİR:
--   * 20260628100000_profile_avatar — kovayı ve DÖRT politikayı kurdu
--     (avatars_public_read / insert / update / delete). Avatar yükleme ve
--     DEĞİŞTİRME o gün çalışıyordu (üretimdeki tek nesne 28 Haziran'da
--     oluşup 29 Haziran'da güncellenmiş — ikisi de başarılı).
--   * 20260720064708_security_hardening — `avatars_public_read`i düşürdü.
--     Gerekçesi yazılıydı: "kova zaten public (storage.buckets.public =
--     true), objeler /storage/v1/object/public/... üzerinden RLS'e hiç
--     takılmadan servis ediliyor; bu SELECT politikası nesne erişimi için
--     gereksizdi, yalnızca bucket'taki TÜM dosya adlarının storage list
--     endpoint'iyle dışarıdan sayılmasına izin veriyordu."
--
-- GEREKÇE OKUMA İÇİN DOĞRUYDU, YAZMA İÇİN DEĞİL. İstemci (hem web
-- `uploadAvatar` hem mobil `AuthService.uploadAvatar`) `upsert: true` ile
-- yüklüyor; bu, storage-api tarafında `INSERT ... ON CONFLICT DO UPDATE`
-- demek ve çakışan satırın çağırana GÖRÜNÜR olmasını gerektiriyor. SELECT
-- politikası kalkınca kullanıcı KENDİ avatar satırını bile göremez oldu,
-- dolayısıyla mevcut avatarın üzerine yazma şu hatayla reddediliyordu:
--   new row violates row-level security policy for table "objects"  (403)
-- Bu, üretimde geri alınan bir transaction içinde authenticated rolüyle
-- BİREBİR yeniden üretildi (kullanıcının cihazda gördüğü mesajın aynısı).
--
-- Etkisi İKİ İSTEMCİDE de vardı (port hatası DEĞİL): yalnızca İLK avatar
-- yüklemesi (çakışacak satır yok → düz INSERT) çalışmaya devam ediyordu,
-- her DEĞİŞTİRME 20 Temmuz'dan beri kırıktı. 13 Ağustos'a kadar fark
-- edilmemesinin sebebi, o tarihten sonra kimsenin avatarını değiştirmemesi.
--
-- ÇÖZÜM `avatars_public_read`i GERİ GETİRMEK DEĞİL — o, sertleştirmenin
-- kapattığı "herkesin dosya adlarını listeleyebilmesi" açığını yeniden
-- açardı. Bunun yerine SAHİBE ÖZEL bir SELECT: kullanıcı yalnızca kendi
-- klasöründeki satırları görür. Bu, upsert için yeterli ve hiçbir şey
-- sızdırmıyor (kendi avatarının URL'i zaten profilinde yazılı, kova da
-- zaten public). Doğrulandı: düzeltmeyle birlikte hem üzerine yazma hem
-- yeni uzantıyla ilk yükleme geçiyor, BAŞKASININ klasörü hâlâ 0 satır.
drop policy if exists "avatars_owner_read" on storage.objects;

create policy "avatars_owner_read" on storage.objects
  for select using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid ()::text
  );
