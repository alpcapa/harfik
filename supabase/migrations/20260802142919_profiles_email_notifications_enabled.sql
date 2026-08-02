-- Kelimeki — işlemsel-ama-tercih-edilebilir e-posta bildirimleri için tek bir
-- ana anahtar (bkz. CLAUDE.md sohbet geçmişi / kullanıcı analizi, 2 Ağustos
-- 2026'nın ikinci konusu). Bu, marketing_consent'ten TAMAMEN ayrı bir alan:
-- marketing_consent yalnızca Kelimeki'nin kendi tanıtım/promosyon içeriğini
-- kapsıyor (opt-in, varsayılan false); bu yeni alan ise gerçek bir olaya
-- bağlı ama sıklığı/gürültüsü kullanıcıyı rahatsız edebilecek işlemsel
-- mailleri kapsıyor (opt-out, varsayılan true) — arkadaşlık isteği/hatırlatma,
-- Canlı oyun daveti, süre uyarısı, süre aşımı/terk-edilme ceza bildirimleri.
--
-- Hesap güvenliği/admin yazışması gibi ZORUNLU mailler (Auth, hesap
-- dondurma/kaldırma, geri bildirim yanıtı, admin mesajı) bu bayrağa hiç
-- bakmıyor — her zaman gönderiliyor.
alter table public.profiles
  add column email_notifications_enabled boolean not null default true;

comment on column public.profiles.email_notifications_enabled is
  'Arkadaşlık isteği/hatırlatması, Canlı oyun daveti, süre uyarısı ve süre aşımı/terk-edilme ceza bildirimi gibi işlemsel-ama-tercih-edilebilir e-postaları alma tercihi (varsayılan açık). Hesap güvenliği/admin yazışması gibi zorunlu maillere etkisi yok.';
