-- Harfik — is_valid_word RPC'si Türkçe büyük/küçük harf kuralını uygular.
-- Standart lower() İ→i ve I→ı dönüşümünü bozar; replace ile düzeltilir.

create or replace function public.is_valid_word (p_word text)
  returns boolean
  language sql
  stable
  security invoker
  set search_path = public
  as $$
  select exists (
    select 1 from public.words
    where word = lower(replace(replace(p_word, 'İ', 'i'), 'I', 'ı'))
  );
$$;
