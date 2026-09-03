-- Biten Canlı oyunun "bunu gördüm" işareti (3 Eylül 2026, kullanıcı isteği).
--
-- SORUN: hamleni yapıp uygulamayı kapatıyorsun, sen yokken rakip oynuyor ve
-- oyun bitiyor. Bitiş modalını HİÇ görmüyorsun; oyunun bittiğini ancak "Son
-- Oynananlar"a girersen fark ediyorsun. Kullanıcı push bildirimini BİLEREK
-- eledi (*"oyun bitti mesajı atmak işin dozunu kaçırabilir"*); çözüm uygulama
-- içi: sekmede kırmızı sayı + satırda "Oyun Bitti (Yeni)".
--
-- ⚠ NEDEN `games`'E KOLON DEĞİL, AYRI TABLO: `games`in SELECT politikası
-- `auth.uid() is not null`, yani GİRİŞLİ HERKES herkesin satırını okuyor.
-- Oraya bir "gördü" kolonu eklemek kimin ne zaman listesine baktığını herkese
-- açardı — düşük dozda ama gerçek bir etkinlik sinyali. Bu repo aynı sınıfı
-- bir kez yaşadı (`games.messages` girişli herkese açıktı, 10 Ağustos 2026'da
-- kapatıldı: "skor/tahta herkese görünür olsa da yazışma değil"). Ayrı tabloda
-- RLS satır bazında kilitlenebiliyor.
create table if not exists public.game_finish_seen (
  -- `games` satırları KİŞİ BAŞINA (2 kişilik oyun → 2 satır, 2 farklı
  -- user_id; canlıda doğrulandı), yani `game_id` tek başına birincil anahtar
  -- olarak yeterli. `user_id` yalnızca RLS ve indeks için taşınıyor.
  game_id uuid primary key references public.games(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  seen_at timestamptz not null default now()
);

create index if not exists game_finish_seen_user_idx
  on public.game_finish_seen(user_id);

alter table public.game_finish_seen enable row level security;

-- Yalnızca kendi satırını OKUR. Yazma/silme politikası BİLEREK yok —
-- işaretleme `mark_game_finishes_seen` (security definer) üzerinden geçer.
-- Canlıda doğrulandı: `authenticated` kendi işaretini bile silemiyor.
drop policy if exists game_finish_seen_select_own on public.game_finish_seen;
create policy game_finish_seen_select_own on public.game_finish_seen
  for select using ((select auth.uid()) = user_id);

-- GERİ DOLDURMA: bugüne kadarki tüm biten Canlı oyunlar "görülmüş" sayılır.
-- Olmasaydı özellik açıldığı an herkese geçmişinin tamamı kadar bir rozet
-- çıkardı (uygulandığında canlıda 138 satır / 16 kişi).
insert into public.game_finish_seen (game_id, user_id)
select g.id, g.user_id
from public.games g
where g.online_game_id is not null and g.user_id is not null
on conflict (game_id) do nothing;

comment on table public.game_finish_seen is
  'Kullanicinin biten Canli oyununun bitisini GORDUGU isareti. games tablosunun SELECT politikasi girisli herkese acik oldugundan bu bilgi oraya kolon olarak eklenmedi.';
