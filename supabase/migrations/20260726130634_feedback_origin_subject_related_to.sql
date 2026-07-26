-- (A) Admin panelinden ("Mesaj Gönder") başlatılan mesajların da feedback
-- tablosunda görünür/kalıcı olması için origin + subject kolonları.
-- (B) E-postadaki "cevap için tıklayın" linkine gömülen referansla (?contact=1&re=<id>)
-- gelen yeni bir geri bildirimi, hangi önceki mesaja cevaben geldiğine bağlamak
-- için related_to (kendine referans veren nullable FK).

alter table public.feedback
  add column if not exists origin text not null default 'user' check (origin in ('user', 'admin')),
  add column if not exists subject text,
  add column if not exists related_to uuid references public.feedback (id) on delete set null;

create index if not exists feedback_related_to_idx on public.feedback (related_to);

comment on column public.feedback.origin is '"user": kullanıcının gönderdiği geri bildirim; "admin": admin panelinden (Mesaj Gönder) başlatılan mesaj.';
comment on column public.feedback.subject is 'Yalnızca origin=admin satırlarda dolu — admin-send-message ile gönderilen mesajın konusu.';
comment on column public.feedback.related_to is 'Bu satır, e-postadaki "cevap için tıklayın" linkinden (?contact=1&re=<id>) hangi önceki mesaja cevaben geldiyse onu işaret eder.';

-- Admin artık "Mesaj Gönder" ile başka bir kullanıcı adına da satır ekleyebilmeli
-- (önceki politika yalnızca auth.uid() = user_id ya da anonim (null) insert'e izin veriyordu).
drop policy if exists feedback_insert_any on public.feedback;
create policy feedback_insert_any on public.feedback
  for insert
  with check (user_id is null or auth.uid () = user_id or public.is_admin ());
