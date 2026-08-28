-- Kelimeki — elle tutulan kelime/anlam listelerinin uygulanması
-- Kaynak: scripts/{proper-nouns,extra-words,extra-meanings}.mjs
--         (scripts/augment-dictionary.mjs ile üretildi).
-- 1 yeni madde, 0 anlam güncellemesi.
-- Tekrar çalıştırmaya güvenli (ON CONFLICT DO UPDATE).

insert into public.words (word, len, points, pos, meanings) values
  ('mö', char_length('mö'), public.kelimeki_points('mö'), 'a.', '["İneğin çıkardığı ses, inek sesi."]'::jsonb)
on conflict (word) do update set len = excluded.len, points = excluded.points, pos = excluded.pos, meanings = excluded.meanings;
