-- Hesap Ayarları'ndaki "Şifre Değiştir" bloğu kaldırılıp yerine cinsiyet ve
-- doğum tarihi eklendi (kullanıcı geri bildirimi: şifre alanlarını görünce
-- değiştirmesi gerektiğini sanıyordu). İkisi de opsiyonel.
alter table public.profiles
  add column gender text check (gender in ('female', 'male', 'unspecified')),
  add column birth_date date;
