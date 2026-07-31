-- Takma isim (display_name) artık zorunlu ve Türkçe'ye duyarlı biçimde
-- (İ/I ayrımı dahil) büyük/küçük harften bağımsız benzersiz — bkz.
-- src/utils/turkish.ts:trLower() ile birebir aynı normalleştirme, aksi
-- halde "Deniz" ve "deniz" ayrı sayılıp aynı sorun (iki hesap aynı görünen
-- isimle) case farkıyla tekrarlanabilirdi. Mevcut veride (18 profil) ne
-- null ne çakışma vardı (elle doğrulandı), backfill gerekmedi.

create or replace function public.tr_lower(text)
returns text
language sql
immutable
parallel safe
as $$
  select lower(replace(replace($1, 'İ', 'i'), 'I', 'ı'));
$$;

comment on function public.tr_lower(text) is 'Türkçe''ye duyarlı küçük harfe çevirme (İ→i, I→ı) — src/utils/turkish.ts:trLower() ile birebir aynı, benzersizlik karşılaştırmalarında kullanılır.';

alter table public.profiles
  alter column display_name set not null;

create unique index profiles_display_name_tr_lower_key
  on public.profiles (public.tr_lower(display_name));

comment on index profiles_display_name_tr_lower_key is 'Takma isim benzersizliği, Türkçe büyük/küçük harf duyarsız.';

-- Kayıt formunda/hesap ayarlarında canlı uygunluk kontrolü için. auth.uid()
-- ile kendi mevcut takma ismini otomatik hariç tutar (authenticated iken);
-- signup akışında (henüz oturum yok) auth.uid() null olduğundan tüm
-- profillere karşı kontrol eder. Yalnızca advisory/UX amaçlı — asıl
-- doğruluk kaynağı yukarıdaki unique index.
create or replace function public.check_nickname_available(p_nickname text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select not exists (
    select 1 from public.profiles
    where public.tr_lower(display_name) = public.tr_lower(p_nickname)
      and (auth.uid() is null or id <> auth.uid())
  );
$$;

revoke all on function public.check_nickname_available(text) from public, anon, authenticated;
grant execute on function public.check_nickname_available(text) to anon, authenticated;
