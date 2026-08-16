-- Kelimeki — hesap sahibinin kaynağı `arkadas` değil `direkt`
--
-- Kullanıcı isteği (16 Ağustos 2026, backfill'in hemen ardından):
-- *"22 arkadaş 23 üye olmaz. 1 üyeyi direkte al"*.
--
-- Bir önceki migration (`backfill_signup_source_arkadas`) 23 üyenin HEPSİNİ
-- `arkadas` yapmıştı. Doğru olmayan tek satır hesap sahibininki: projeyi o
-- kurdu, kimse onu davet etmedi. Ölçüldü — `Ironman` sistemin İLK üyesi
-- (28 Haziran 2026, projenin başladığı gün) ve `invited_by` NULL. Yani
-- "1 üye" keyfi seçilmiyor; davetle gelmediği KESİN olan tek hesap bu.
--
-- KAYDA GEÇSİN — 22/22 = %100 bir ÖLÇÜM DEĞİL, tesadüf: ziyaretçi ucu
-- (22) yalnızca Setup'taki paylaş butonunun `?ref=arkadas` linkiyle gelenleri
-- sayıyor, üye ucu (22) ise ağırlıkla `/davet/:token` davet linkinden
-- gelenleri — o path `?ref=` TAŞIMIYOR, dolayısıyla iki uç aynı popülasyonu
-- ölçmüyor. Oranın %100 çıkması "arkadaş kanalı kusursuz dönüyor" DEMEK
-- DEĞİL. Asimetriyi gerçekten kapatmak isteyen çözüm ayrı: `buildInviteUrl`
-- (`FriendsModal.tsx`) davet linkine `?ref=arkadas` eklerse iki uç aynı
-- kanalı ölçmeye başlar (bilinçli olarak henüz yapılmadı).
--
-- Satır id ile DEĞİL `is_admin` + `invited_by is null` + "en eski üye"
-- koşuluyla seçiliyor ki migration bir kopyada/başka ortamda körlemesine
-- çalıştırılsa bile yanlış satırı yakalamasın.
--
-- Geri alınabilir: bu satırın önceki değeri `arkadas`'tı.

alter table public.profiles disable trigger trg_keep_signup_utm_source;

update public.profiles
set signup_utm_source = 'direkt'
where id = (
  select p.id from public.profiles p
  where p.is_admin and p.invited_by is null
  order by p.created_at
  limit 1
);

alter table public.profiles enable trigger trg_keep_signup_utm_source;
