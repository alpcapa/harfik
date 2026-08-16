-- Kelimeki — damgalama öncesi 23 üyenin kaynağı `arkadas` olarak dolduruldu
--
-- Kullanıcı kararı (16 Ağustos 2026, kendi ifadesiyle): *"Bütün üyeler benim
-- sayemde geldi. Hepsini ben davet ettim. Belki bir kaç tanesi de onların
-- arkadaşları olabilir. … Zaten google'dan vb organik trafik gelmedi, en
-- azından üye gelmedi. Başka yerde bir reklam tanıtım henüz yapılmadı. Onun
-- için özetle hepsi arkadaş."*
--
-- NEDEN BU BİR TAHMİN DEĞİL: `signup_utm_source` 16 Ağustos 2026'da eklendi ve
-- geriye dönük doldurulamaz — şemada bu bilgi hiçbir yerde yazılı DEĞİL. Ama
-- damgalama öncesi dönemin tek gerçek kaynağı, kullanıcı kazanımını bizzat
-- yapmış olan hesap sahibinin bilgisidir: o tarihe kadar hiç reklam/tanıtım
-- yayınlanmadı ve organik aramadan üye gelmedi. Yani burada "bilmediğimizi
-- uyduruyor" değil, "şemanın taşımadığı ama BİLİNEN gerçeği yazıyoruz".
--
-- ÖNCEKİ TURDAKİ İTİRAZ NEDEN DÜŞTÜ: bir gün önce `invited_by` üzerinden
-- yapılacak kısmi bir backfill'e karşı çıkmıştım, çünkü 5 kayıttan 2'sinde
-- (Minka, Esiner) davet kabulü üyelikten 96-98 SAAT sonraydı — yani onlar
-- zaten üyeyken bir arkadaşının linkine tıklamıştı ve `invited_by` sonradan
-- dolmuştu. O itiraz "hangi MEKANİZMANIN getirdiği" sorusuna aitti; bu
-- migration ise KANALI yazıyor ve kullanıcı ikisinin de arkadaş kanalı
-- olduğunu doğruladı. Yani ölçüm hâlâ geçerli, sonucu değiştiren yeni bilgi.
--
-- KAPSAM tarihle SINIRLI (`created_at < now()`): ileride mobil uygulamadan
-- gelen kayıtlar da (istemci damgalamadığından) null olacak ve onlar "arkadaş"
-- DEĞİL. Bu migration'ın bir daha çalıştırılması ya da benzerinin körlemesine
-- kopyalanması o kayıtları süpürmesin diye kapsam bugüne kilitlendi.
--
-- GERİ ALINABİLİR: tüm 23 satırın önceki değeri NULL'dı (ölçüldü: damgalı
-- satır sayısı 0), yani geri almak `update … set signup_utm_source = null
-- where signup_utm_source = 'arkadas' and created_at < '2026-08-16'`.
--
-- `trg_keep_signup_utm_source` (write-once) bu alanı UPDATE'e kapattığından
-- trigger geçici olarak devre dışı bırakılıyor — kolonu eklerken kayda geçen
-- "yanlış bir değeri düzeltmek için trigger'ı disable etmek gerekir" yan
-- etkisinin ilk kullanımı.

alter table public.profiles disable trigger trg_keep_signup_utm_source;

update public.profiles
set signup_utm_source = 'arkadas'
where signup_utm_source is null
  and created_at < now();

alter table public.profiles enable trigger trg_keep_signup_utm_source;
