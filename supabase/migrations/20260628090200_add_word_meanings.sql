-- Harfik — words tablosuna sözlük anlamları ekler
-- TDK Güncel Türkçe Sözlük (12. baskı) maddeleri için sözcük türü ve
-- anlam listesi sütunları. Asıl veri 20260628090300_seed_dictionary.sql
-- ile yüklenir.

-- ── Yeni sütunlar ─────────────────────────────────────────────────────────────
alter table public.words
  add column if not exists pos      text,            -- sözcük türü (a., sf., -i ...)
  add column if not exists meanings jsonb not null default '[]'::jsonb; -- anlam dizisi

comment on column public.words.pos is 'Sözcük türü kısaltması (TDK), örn. a., sf., -i.';
comment on column public.words.meanings is 'Sözlük anlamlarının JSON dizisi (string[]).';

-- ── RPC: bir kelimenin anlamlarını döndürür ──────────────────────────────────
-- İstemci oynanan/seçilen kelimenin anlamlarını DB'den çekebilir.
create or replace function public.word_meaning (p_word text)
  returns table (word text, pos text, meanings jsonb)
  language sql
  stable
  security invoker
  set search_path = public
  as $$
  select w.word, w.pos, w.meanings
  from public.words w
  where w.word = lower(p_word);
$$;
