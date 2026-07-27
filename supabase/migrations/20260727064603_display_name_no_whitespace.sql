-- Bir oyuncu geri bildirimi: Sanal Lig'den açılan skor kartlarında bazı
-- kullanıcılar tam ad/soyadları gibi görünüyordu — meğer kişiler takma isim
-- (display_name) alanına doğrudan kendi gerçek adlarını (aralarında boşlukla,
-- ör. "Zeynep Esiner") yazmış. Kod tarafı zaten yalnızca display_name||
-- first_name gösteriyor (last_name hiç okunmuyor), yani bu bir kod hatası
-- değildi — ama kullanıcı deneyimini iyileştirmek için takma ismi tek
-- kelimeye (boşluksuz, özel karakterler serbest) zorluyoruz: böylece biri
-- "İsim Soyad" yazsa bile bitişik ("İsimSoyad") kalıp gerçek bir nickname
-- gibi görünür.

-- Önce mevcut kayıtlardaki boşlukları temizle (ör. "Avitan Mori" ->
-- "AvitanMori") — aksi halde aşağıdaki constraint mevcut verilerle çakışır.
update public.profiles
set display_name = regexp_replace(display_name, '\s+', '', 'g')
where display_name is not null and display_name ~ '\s';

alter table public.profiles
  add constraint profiles_display_name_no_whitespace
  check (display_name is null or display_name !~ '\s');
