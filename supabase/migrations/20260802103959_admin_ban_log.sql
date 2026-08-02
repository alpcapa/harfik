create table public.admin_ban_log (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  banned boolean not null,
  created_at timestamptz not null default now()
);

create index admin_ban_log_target_idx on public.admin_ban_log(target_user_id);

alter table public.admin_ban_log enable row level security;

create policy admin_ban_log_select_admin on public.admin_ban_log
  for select
  using (public.is_admin());

comment on table public.admin_ban_log is 'Hesap dondurma/dondurma-kaldırma aksiyonlarının denetim kaydı — admin_set_user_banned tarafından yazılır, Üyeler > Kayıtlar bölümünde okunur.';
