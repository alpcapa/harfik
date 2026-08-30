-- Kelimeki — elle tutulan kelime/anlam listelerinin uygulanması
-- Kaynak: scripts/{proper-nouns,extra-words,extra-meanings}.mjs
--         (scripts/augment-dictionary.mjs ile üretildi).
-- 5 yeni madde, 0 anlam güncellemesi.
-- Tekrar çalıştırmaya güvenli (ON CONFLICT DO UPDATE).

insert into public.words (word, len, points, pos, meanings) values
  ('çilav', char_length('çilav'), public.kelimeki_points('çilav'), 'a.', '["İran usulü pirinç pilavı."]'::jsonb),
  ('kanola', char_length('kanola'), public.kelimeki_points('kanola'), 'a.', '["Turpgiller familyasından, sarı çiçekli kolza bitkisinin zararlı asitlerden arındırılarak ıslah edilmesiyle elde edilen yağ bitkisi."]'::jsonb),
  ('refil', char_length('refil'), public.kelimeki_points('refil'), 'a.', '["Biten bir ürünün yerine takılan yedek dolum veya yedek parça.","Bir kabı yeniden doldurma, tekrar doldurma."]'::jsonb),
  ('sü', char_length('sü'), public.kelimeki_points('sü'), 'a.', '["Eski Türkçede asker, ordu, askerî birlik."]'::jsonb),
  ('tarot', char_length('tarot'), public.kelimeki_points('tarot'), 'a.', '["Geleceği öğrenmek veya rehberlik almak amacıyla kullanılan 78 kartlık özel deste."]'::jsonb)
on conflict (word) do update set len = excluded.len, points = excluded.points, pos = excluded.pos, meanings = excluded.meanings;
