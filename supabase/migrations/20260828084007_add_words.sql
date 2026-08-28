-- Kelimeki — elle tutulan kelime/anlam listelerinin uygulanması
-- Kaynak: scripts/{proper-nouns,extra-words,extra-meanings}.mjs
--         (scripts/augment-dictionary.mjs ile üretildi).
-- 4 yeni madde, 0 anlam güncellemesi.
-- Tekrar çalıştırmaya güvenli (ON CONFLICT DO UPDATE).

insert into public.words (word, len, points, pos, meanings) values
  ('banu', char_length('banu'), public.kelimeki_points('banu'), 'a.', '["Hanımefendi, soylu kadın.","Gelin.","Bağ, bahçe."]'::jsonb),
  ('banü', char_length('banü'), public.kelimeki_points('banü'), 'a.', '["Kadın, hanım.","Hanımefendi, soylu kadın."]'::jsonb),
  ('lapis', char_length('lapis'), public.kelimeki_points('lapis'), 'a.', '["Lapis lazuli olarak bilinen koyu mavi değerli taş; dilimizde daha çok tam hâliyle ya da laciverttaşı, lacivert taşı olarak anılır."]'::jsonb),
  ('mö', char_length('mö'), public.kelimeki_points('mö'), 'ünl.', '["İneğin çıkardığı sesi anlatan söz, inek sesi."]'::jsonb)
on conflict (word) do update set len = excluded.len, points = excluded.points, pos = excluded.pos, meanings = excluded.meanings;
