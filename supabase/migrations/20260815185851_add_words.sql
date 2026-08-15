-- Kelimeki — elle tutulan kelime/anlam listelerinin uygulanması
-- Kaynak: scripts/{proper-nouns,extra-words,extra-meanings}.mjs
--         (scripts/augment-dictionary.mjs ile üretildi).
-- 5 yeni madde, 1 anlam güncellemesi.
-- Tekrar çalıştırmaya güvenli (ON CONFLICT DO UPDATE).

insert into public.words (word, len, points, pos, meanings) values
  ('evsel', char_length('evsel'), public.kelimeki_points('evsel'), 'sf.', '["Evle ilgili."]'::jsonb),
  ('is', char_length('is'), public.kelimeki_points('is'), 'a.', '["Dumanın değdiği yerde bıraktığı kara leke","Yakıtın tam yanmamasından oluşan, dumanla yükselen kömürleşmiş tanecikler","► sürme (II)","Eski Türkçede ve halk ağzında sahip, iye, malik (\"ıssız\" sözcüğü bu kökten türemiştir)."]'::jsonb),
  ('lila', char_length('lila'), public.kelimeki_points('lila'), 'sf.', '["Açık eflatun veya leylak rengi."]'::jsonb),
  ('ma', char_length('ma'), public.kelimeki_points('ma'), null, '["Arapçada cansız nesnelere işaret eden veya \"o şey ki\" anlamına gelen bağlayıcı kök (örnek: mâ-ba''d — sondaki).","Eski dilde su."]'::jsonb),
  ('nil', char_length('nil'), public.kelimeki_points('nil'), null, '["Afrika''nın kuzeydoğusundan geçerek Akdeniz''e dökülen, dünyanın en uzun nehirlerinden biri."]'::jsonb),
  ('tikli', char_length('tikli'), public.kelimeki_points('tikli'), 'sf.', '["İstem dışı kas hareketi veya alışkanlık hâline gelmiş garip bir davranışı (tiki) olan kimse."]'::jsonb)
on conflict (word) do update set len = excluded.len, points = excluded.points, pos = excluded.pos, meanings = excluded.meanings;
