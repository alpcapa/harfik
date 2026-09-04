-- Kelimeki — `feedback` de istemciden `created_at` alıyor, aynı kapıya girsin.
--
-- NEDEN (4 Eylül 2026): "Görüş Bildir" formunun offline kuyruğu mesajın
-- YAZILDIĞI anı zaten tutuyordu (TTL için) ama SUNUCUYA GÖNDERMİYORDU —
-- günler sonra iletilen bir mesaj admin panelinde yazıldığı güne değil
-- İLETİLDİĞİ güne düşüyordu. Terk kayıtlarındaki (20260904055358) aynı hata
-- sınıfının ikinci örneği; kullanıcı "bu mantık admindeki tüm datalar için de
-- geçerli olmalı" dedi ve tarama bu tabloyu buldu.
--
-- Kuyruk artık damgayı gönderdiğine göre, ileri tarih uydurma yüzeyi burada
-- da açıldı — `games`/`game_finishes` ile AYNI trigger'a bağlanıyor
-- (`_clamp_created_at`: now()+5dk'yı aşan damga sessizce now()'a kırpılır).
--
-- ⚠ Bu üç tablo, istemcinin `created_at` yazabildiği TÜM tablolar. Yenisi
-- eklenirse trigger'ı ona da bağla — tarama kaydı için bkz.
-- docs/decisions/local-game-persistence.md → "Terk kaydı SÜPÜRME anına...".
drop trigger if exists feedback_clamp_created_at on public.feedback;
create trigger feedback_clamp_created_at
  before insert on public.feedback
  for each row execute function public._clamp_created_at();
