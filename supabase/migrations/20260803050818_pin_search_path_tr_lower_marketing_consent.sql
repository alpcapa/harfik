-- Kod incelemesi (Düşük bulgu): tr_lower ve set_marketing_consent_at
-- fonksiyonlarında search_path sabitlenmemişti. SECURITY DEFINER
-- olmadıklarından kritik bir açık değil, ama hijyen kalemi — bir role'ün
-- search_path'ini manipüle edip bu fonksiyonların çözümlediği isimsiz
-- (unqualified) nesneleri farklı bir şemadaki isim-benzeri bir nesneye
-- yönlendirmesi teorik olarak mümkün olurdu. İkisi de yalnızca `public`
-- şemasındaki nesnelere (ya da hiç şema-bağımlı nesneye) ihtiyaç
-- duyduğundan, search_path'i public'e sabitlemek davranışı değiştirmez.
alter function public.tr_lower(text) set search_path = public, pg_temp;
alter function public.set_marketing_consent_at() set search_path = public, pg_temp;
