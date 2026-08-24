-- Kelimeki — misafir ziyaretlerinde işletim sistemi ayrımı (iOS/Android/masaüstü)
--
-- Admin panelindeki "Cihaz" tablosu şimdiye kadar `getDeviceType()`'ın
-- `(pointer: coarse)` media query'sinden ürettiği kaba "mobile"/"desktop"
-- ayrımını gösteriyordu — bu, dokunmatik/fare ayrımıydı, İŞLETİM SİSTEMİ
-- DEĞİL. Kullanıcı isteğiyle istemci artık `navigator.userAgent`'tan gerçek
-- OS'i ("ios"/"android"/"desktop") okuyor (bkz. `src/utils/visitTracking.ts`).
--
-- `device_type` sütununda hiçbir CHECK kısıtı yok (düz `text`), yani şema
-- değişikliği GEREKMİYOR — yalnızca istemcinin yazdığı değer kümesi değişti.
-- Bu migration'ın tek işi: (1) eski değişmeyen sütun yorumunu güncellemek,
-- (2) `games.platform`in AKSİNE burada iyi niyetle işletim sistemi
-- SÜRÜMÜ ve (elde edilebiliyorsa) cihaz modelini de tutan iki yeni,
-- nullable sütun eklemek.
--
-- ⚠ GERİYE DÖNÜK AYRIŞTIRILAMAZ: bu migration'dan ÖNCEKİ ziyaretler
-- "mobile"/"desktop" değerini taşımaya devam eder — hangi OS olduğu hiçbir
-- zaman kurtarılamaz (`games.platform`'daki aynı sınıf kısıt). Admin
-- panelindeki etiket bu yüzden eski "mobile" değerini de ayrı bir "Mobil
-- (eski)" satırı olarak gösterir, yeni "ios"/"android" ile karıştırmaz.
--
-- os_version/device_model şimdilik HİÇBİR YERDE gösterilmiyor (kullanıcı
-- isteği: "lazım olursa koyarız") — yalnızca kaydediliyor. Tarayıcıların
-- kendi kısıtları burada dürüstçe belgelenmeli: iOS Safari cihaz modelini
-- HİÇ vermez (yalnızca "iPhone"/"iPad" genel kategorisi elde edilebiliyor);
-- Android'de de Chrome 110+'ın "User-Agent reduction"ı modeli çoğunlukla
-- User-Agent Client Hints'e taşıdığından düz User-Agent'tan model çoğu
-- zaman gelmiyor — her iki alan da bu yüzden NULLABLE ve sık sık boş kalması
-- beklenen bir durum, bir hata değil.

alter table public.guest_visits
  add column if not exists os_version text,
  add column if not exists device_model text;

comment on column public.guest_visits.device_type is
  'İstemcinin bildirdiği kaba cihaz sınıfı. 24 Ağustos 2026''dan ÖNCE: '
  '`(pointer: coarse)` media query''sinden "mobile"/"desktop" (dokunmatik mi '
  'fare mi). O tarihten SONRA: `navigator.userAgent`''tan işletim sistemi — '
  '"ios"/"android"/"desktop". İki dönem birbirine dönüştürülemez, admin '
  'ekranı eski "mobile" değerini ayrı bir satır olarak gösterir. Eski '
  'kayıtlarda (sütun hiç eklenmeden önce) null.';

comment on column public.guest_visits.os_version is
  'İyi niyetle (best-effort) `navigator.userAgent`''tan ayrıştırılan işletim '
  'sistemi sürümü (ör. iOS''ta "17.4", Android''de "13"). Ayrıştırılamazsa '
  'null. Şimdilik hiçbir admin ekranında GÖSTERİLMİYOR, yalnızca ileride '
  'ihtiyaç olursa diye tutuluyor.';

comment on column public.guest_visits.device_model is
  'İyi niyetle (best-effort) `navigator.userAgent`''tan ayrıştırılan cihaz '
  'bilgisi. iOS''ta tarayıcı gerçek model numarasını HİÇ vermediğinden yalnız '
  '"iPhone"/"iPad" genel kategorisi; Android''de tarayıcıya/sürüme göre model '
  'kodu (ör. "SM-G991B") ya da sıkça null (Chrome''un User-Agent reduction''ı '
  'modeli düz User-Agent''tan gizliyor). Masaüstünde her zaman null. Şimdilik '
  'hiçbir admin ekranında GÖSTERİLMİYOR.';
