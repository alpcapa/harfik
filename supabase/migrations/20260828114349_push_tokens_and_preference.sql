-- Kelimeki — push bildirimleri: cihaz token tablosu + tercih anahtarı.
-- (ROADMAP madde 13 — Sürüm B; FCM, Android bugün, iOS anahtar yüklenince.)
--
-- ── NEDEN AYRI BİR TERCİH ANAHTARI (karar: 26 Ağustos 2026) ────────────────
--   `email_notifications_enabled` DURUYOR ve push onu BASTIRMIYOR: iki
--   BAĞIMSIZ anahtar, ikisi de açık gelir. Otomatik bastırma teknik olarak
--   kolaydı ama YANLIŞ olurdu — token bayatlarsa (uygulama silinmiş, bildirim
--   sistem ayarından kapatılmış, token yenilenmemiş) push GİTMEZ; e-postayı da
--   bastırmışsak kullanıcı HİÇBİR ŞEY almaz. Bu, iki bildirim almaktan çok
--   daha kötü ve SESSİZ bir arıza: kimse şikayet etmez, yalnızca oyunlar ölür.
--
-- ── TOKEN'IN BİRİNCİL ANAHTAR OLMASI BİLİNÇLİ ─────────────────────────────
--   FCM kayıt token'ı CİHAZ+UYGULAMA kurulumu başına benzersizdir, kullanıcı
--   başına değil. Aynı telefonda A çıkıp B giriş yaparsa token AYNI kalır ve
--   artık B'ye aittir — `on conflict (token) do update set user_id = ...` bunu
--   tek adımda devreder. `(user_id, token)` bileşik anahtar olsaydı aynı token
--   iki kullanıcıda birden durur ve A'ya gitmesi gereken bildirim B'nin
--   telefonunda çıkardı.
--
-- ── platform DEĞER KÜMESİ ─────────────────────────────────────────────────
--   Yalnızca 'android' | 'ios'. `util/platform.dart` üçüncü bir değer
--   ('app-web') üretiyor ama Flutter WEB derlemesi bir TEST ORTAMI, ürün
--   değil ve FCM web push'u bu projede kapsam dışı — üçüncü değeri kabul
--   etmek, hiç gönderilemeyecek satırlar biriktirmek olurdu.

-- ── 1) Tercih anahtarı ────────────────────────────────────────────────────
alter table public.profiles
  add column if not exists push_notifications_enabled boolean not null default true;

comment on column public.profiles.push_notifications_enabled is
  'Uygulama push bildirimlerini alma tercihi (varsayılan açık). '
  'email_notifications_enabled''dan BAĞIMSIZ: biri kapanınca öteki bastırılmaz — '
  'token bayatlarsa kullanıcının hiçbir şey almaması riskine karşı bilinçli karar.';

-- ── 2) Cihaz token tablosu ────────────────────────────────────────────────
create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.push_tokens is
  'FCM cihaz kayıt token''ları. Birincil anahtar TOKEN''dır (cihaz+kurulum '
  'başına benzersiz), user_id değil — aynı cihazda hesap değişince satır '
  'devredilir, çoğaltılmaz. Bir kullanıcının birden çok cihazı olabilir.';

create index if not exists push_tokens_user_id_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;

-- `(select auth.uid())` sarmalaması: RLS initplan performans kuralı
-- (20260802212119_rls_auth_uid_initplan_perf) — semantik aynı.
create policy push_tokens_select_own on public.push_tokens
  for select using ((select auth.uid()) = user_id);

create policy push_tokens_insert_own on public.push_tokens
  for insert with check ((select auth.uid()) = user_id);

-- ⚠ UPDATE'in `with check`i ŞART: yalnızca `using` verilirse kullanıcı KENDİ
-- satırını başka bir user_id'ye taşıyabilir (satırı "bağışlayabilir") ve o
-- kişinin bildirimleri bu cihaza düşer. `using` "hangi satırı düzenleyebilir",
-- `with check` "düzenleme SONUCU ne olabilir" sorusunu cevaplar.
create policy push_tokens_update_own on public.push_tokens
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy push_tokens_delete_own on public.push_tokens
  for delete using ((select auth.uid()) = user_id);

create trigger trg_push_tokens_updated_at
  before update on public.push_tokens
  for each row execute function public.set_updated_at();
