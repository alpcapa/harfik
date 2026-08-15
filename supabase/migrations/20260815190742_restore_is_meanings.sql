-- Kelimeki — 'is' anlamlarını geri al: sahip/iye anlamı YANLIŞ kelimeye eklenmişti
-- =====================================================================
-- 20260815185851_add_words.sql, 'sahip, iye, malik' anlamını 'is' (i ile —
-- dumanın bıraktığı kara leke) maddesine ekledi. Doğru kelime 'ıs' (ı ile);
-- ikisi ayrı maddelerdir ve "ıssız" sözcüğü ı ile olandan türer. Yeni madde
-- aynı turda üretilen 20260815190645_add_words.sql ile ekleniyor; burada
-- yalnızca 'is' GTS'teki üç özgün anlamına döndürülüyor.
--
-- Kaynak: src/data/meanings.json (elle yazılmadı, oradan üretildi).

update public.words set pos = 'a.', meanings = '["Dumanın değdiği yerde bıraktığı kara leke","Yakıtın tam yanmamasından oluşan, dumanla yükselen kömürleşmiş tanecikler","► sürme (II)"]'::jsonb
where word = 'is';
