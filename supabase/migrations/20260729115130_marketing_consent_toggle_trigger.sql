-- Hesap Ayarları'ndan (AccountSettingsModal) sonradan vazgeçme/dahil olma
-- için: marketing_consent değiştiğinde marketing_consent_at'i her zaman
-- sunucu tarafında (client clock'a güvenmeden) otomatik güncelleyen bir
-- BEFORE UPDATE trigger'ı — kayıt formundaki (handle_new_user) aynı
-- "sunucu now()" ilkesini burada da koruyor. Yalnızca `marketing_consent`
-- GERÇEKTEN değiştiğinde çalışır (ilgisiz profil güncellemelerinde
-- marketing_consent_at'e dokunmaz); client'ın marketing_consent_at'e
-- doğrudan gönderdiği herhangi bir değer bilerek YOK SAYILIR (yalnızca
-- boolean geçişine göre üzerine yazılır) — tek doğruluk kaynağı bu trigger.
create or replace function public.set_marketing_consent_at()
returns trigger
language plpgsql
as $$
begin
  if new.marketing_consent is distinct from old.marketing_consent then
    new.marketing_consent_at := case when new.marketing_consent then now() else null end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_marketing_consent_at on public.profiles;
create trigger trg_set_marketing_consent_at
before update on public.profiles
for each row
execute function public.set_marketing_consent_at();
