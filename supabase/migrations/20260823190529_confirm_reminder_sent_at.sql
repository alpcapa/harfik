-- Kelimeki — onaylanmamış hesaplar: hatırlatma damgası (23 Ağustos 2026)
--
-- GEREKÇE: onaylanmamış bir hesap bugün SÜRESİZ duruyor ve takma adı kalıcı
-- olarak rezerve ediyor. Ölçüldü (23 Ağustos): 37 üyenin 3'ü hiç onaylanmamış,
-- ikisi 26/28 gündür öyle. Gerçek bir kullanıcı bu yüzden kendi takma adını
-- alamadı (bkz. ROADMAP #10, "Sel Sezer" vakası).
--
-- AKIŞ: 0. saat kayıt (link 24 saat geçerli) → ~20. saat tek seferlik
-- hatırlatma (TAZE link) → 48. saat hâlâ onaysızsa hesap silinir.
-- İlke: hatırlatma aralığı = linkin ömrü, böylece kutuda her an geçerli bir
-- link bulunur. Bu kolon o tek seferliği garanti eder.
--
-- Desen `friend_requests.reminder_sent_at` ve `profiles.welcome_email_sent_at`
-- ile aynı: `is null` filtreli ATOMİK bir UPDATE ile "iddia edilir", böylece
-- işin tekrar tetiklenmesi mükerrer mail üretmez.
alter table public.profiles
  add column if not exists confirm_reminder_sent_at timestamptz;

comment on column public.profiles.confirm_reminder_sent_at is
  'E-posta onayı hatırlatması gönderildiği an (tek seferlik, atomik iddia). Onaylanmayan hesap ~48 saatte silinir — sweep-unconfirmed-accounts.';
