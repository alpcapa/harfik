-- Kelimeki — destek@kelimeki.com kutusuna gelen cevaplar için "haber verme"
-- tablosu (25 Ağustos 2026, kullanıcı kararı).
--
-- KARARIN ÖZETİ: `noreply@` yalnızca transactional/sistemsel maillerde
-- kullanılacak ve GERÇEKTEN cevaplanamaz olacak; görüş bildirim yanıtları ve
-- admin'in üyelere yazdığı mesajlar `destek@kelimeki.com` üzerinden gidecek.
-- Kullanıcı o maile "Yanıtla" derse cevap ZOHO kutusuna düşer — mailin asıl
-- yeri orası, admin panelinde OKUNMAZ. Panelin tek işi haber vermek:
-- "Geri Bildirim" sekmesindeki alt sekme satırına küçük bir "Zoho" düğmesi
-- eklendi, üstünde kırmızı sayılı rozet var, tıklanınca Zoho gelen kutusunu
-- açar.
--
-- NEDEN BU TABLO GEREKLİ: Zoho'nun okunmamış sayısını uygulama kendiliğinden
-- bilemez. Zoho'da `destek@`'e gelen her mailin bir KOPYASI Brevo Inbound
-- Parsing adresine yönlendiriliyor, Brevo da `inbound-email` Edge
-- Function'ına POST ediyor; fonksiyon buraya bir satır yazıyor. Yani bu tablo
-- bir posta kutusu DEĞİL, bir sayaç/bildirim kaydı.
--
-- ⚠ BİLEREK GÖVDE SAKLANMIYOR. Yalnızca kimden/konu/tarih tutuluyor —
-- kullanıcının mail metni tek bir yerde (Zoho) kalsın diye. Bu, "mail Zoho'ya
-- düşsün ama uyarı gelsin" kararının doğrudan karşılığı; bir gün panelde
-- okuma istenirse şema genişletilir, ama o zaman `docs/decisions/`'a gerekçe
-- yazılmalı (bkz. CLAUDE.md → "Karar Kayıtları").

create table if not exists public.support_inbox (
  id          uuid primary key default gen_random_uuid (),
  received_at timestamptz not null default now(),
  from_email  text,
  from_name   text,
  subject     text,
  -- Aynı mailin iki kez POST edilmesine karşı (Brevo yeniden dener) tekillik.
  message_id  text unique,
  seen_at     timestamptz,
  seen_by     uuid references auth.users (id) on delete set null
);

comment on table public.support_inbox is
  'destek@kelimeki.com kutusuna gelen cevapların HABER kaydı (gövde saklanmaz — mail Zoho''da okunur). Admin panelindeki "Zoho" rozetinin sayacı.';
comment on column public.support_inbox.message_id is
  'Gelen mailin RFC Message-ID''si — Brevo aynı maili yeniden POST ederse ikinci satır açılmasın diye unique.';
comment on column public.support_inbox.seen_at is
  'Admin "Zoho" rozetine tıklayıp kutuya gittiğinde dolar; rozet bu sütuna göre sayar.';

-- Rozet sorgusu yalnızca görülmemişleri sayıyor — kısmi index tam da o sorguya bakar.
create index if not exists support_inbox_unseen_idx
  on public.support_inbox (received_at desc)
  where seen_at is null;

alter table public.support_inbox enable row level security;

-- Yalnızca adminler okuyabilir/işaretleyebilir. INSERT politikası BİLEREK YOK:
-- satırları yalnızca `inbound-email` Edge Function'ı service-role anahtarıyla
-- (RLS'i atlayarak) yazar. Politikasız bir tabloya anon/authenticated rolü
-- insert edemez — yani panele sahte "cevap geldi" satırı POST edilemez.
drop policy if exists support_inbox_select_admin on public.support_inbox;
create policy support_inbox_select_admin on public.support_inbox
  for select using (public.is_admin ());

drop policy if exists support_inbox_update_admin on public.support_inbox;
create policy support_inbox_update_admin on public.support_inbox
  for update using (public.is_admin ()) with check (public.is_admin ());
