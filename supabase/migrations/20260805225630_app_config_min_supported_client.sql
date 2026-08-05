-- Uygulama yapılandırma tablosu + mobil minimum sürüm kaydı (Flutter portu
-- hazırlığı, bkz. mobile/CLAUDE.md "Üst Düzey Kararlar" #2b).
--
-- Gerekçe: PWA her deploy'da kendini güncelleyebiliyor; mağazadan kurulan
-- mobil binary güncellenmeyi reddedebilir. submit_move gibi paylaşılan bir
-- sözleşme ileride kırılmak zorunda kalırsa, eski binary'lere "önce güncelle"
-- diyebilmek için uygulamanın açılışta okuyacağı bir eşik gerekiyor. Web
-- istemcisi bu tabloyu HİÇ okumuyor — web davranışı değişmedi.
--
-- Yazma yolu bilinçli olarak YOK (insert/update/delete grant'i hiçbir client
-- rolüne verilmiyor; RLS'te de yalnızca select politikası var): değer
-- değişikliği migration/SQL ile yapılır — admin paneline taşınırsa o gün
-- is_admin() politikası + grant birlikte eklenir.
--
-- anon'a da select açık: sürüm kontrolü login'den ÖNCE, uygulama açılışında
-- yapılmalı (girişi olmayan misafir de eski binary'de takılı kalabilir).

create table public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

create policy app_config_select_all on public.app_config
  for select using (true);

revoke all on public.app_config from anon, authenticated;
grant select on public.app_config to anon, authenticated;

-- Başlangıç değeri: henüz yayınlanmış mobil sürüm yok — 0.0.0 hiçbir şeyi
-- engellemez. Mobil uygulama semver karşılaştırmasıyla kendi platform
-- anahtarını okuyacak.
insert into public.app_config (key, value) values (
  'mobile_min_supported_version',
  jsonb_build_object('android', '0.0.0', 'ios', '0.0.0')
);
