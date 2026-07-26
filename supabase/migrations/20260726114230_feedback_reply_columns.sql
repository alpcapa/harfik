-- Görüş bildirime admin yanıtı — yanıt DB'de saklanır, e-posta gönderimi ayrı
-- bir Edge Function'da (Brevo Transactional API ile) yapılır. Var olan
-- feedback_update_admin RLS politikası (is_admin()) yeni kolonları da kapsar,
-- ayrı bir politika gerekmiyor.

alter table public.feedback
  add column if not exists reply text,
  add column if not exists replied_at timestamptz,
  add column if not exists replied_by uuid references auth.users (id) on delete set null;

alter table public.feedback
  add constraint feedback_reply_length check (reply is null or char_length(reply) between 1 and 5000);

comment on column public.feedback.reply is 'Admin tarafından gönderilen yanıt metni (Brevo ile e-posta olarak da iletilir).';
comment on column public.feedback.replied_at is 'Yanıtın gönderildiği an.';
comment on column public.feedback.replied_by is 'Yanıtı gönderen admin kullanıcı.';
