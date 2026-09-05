-- Oturumsuz (anon) kimlik sızıntısının kapatılması — 5 Eylül 2026,
-- Play Store öncesi güvenlik geçişi.
--
-- ÖLÇÜM (bu migration'dan önce, `set local role anon` ile):
--   select from profiles            →  0 satır   ✅ RLS tutuyor
--   select from games               →  0 satır   ✅ RLS tutuyor
--   select from leaderboard         → 30 satır   ❌ (user_id + ad + soyad DOLU)
--   select from player_stats        → 46 satır   ❌
--   select from player_stats_overall→ 30 satır   ❌
--   select from k_lig_siralama      → 30 satır   ❌
--   get_profile_age_gender(30 UUID) → 19 kişide yaş + cinsiyet ❌
--
-- Yani niyet ile sonuç birbirini yalanlıyordu: `profiles_select_own_or_admin`
-- politikası bir kullanıcının YALNIZCA kendi profilini okumasına izin veriyor
-- (başkalarının adı bilerek view'lara emanet edilmiş), ama o view'lar
-- `SECURITY DEFINER` olduğu için RLS'i atlıyor ve `anon`'a açıktı. Sonuç:
-- yayınlanmış anon anahtarıyla, oturum açmadan, tüm üye listesi + ad soyad +
-- 19 kişinin yaşı/cinsiyeti okunabiliyordu.
--
-- ⚠ ADVISOR'IN ÖNERDİĞİ DÜZELTME YAPILMADI. Panel "view'ları
-- `security_invoker`a çevir" diyor; bu ÖZELLİĞİ KIRAR — invoker modunda
-- `profiles` politikası devreye girer ve GİRİŞLİ kullanıcı da kendi
-- satırından başkasını göremez, k-lig listesi boşalır. Düzeltme bu yüzden
-- grant'te: `anon` gider, `authenticated` AYNEN kalır.
--
-- ⚠ `k_lig_siralama` zaten `security_invoker=true` taşıyor ama `leaderboard`
-- (definer) view'ından select ettiği için o ayar tek başına hiçbir işe
-- yaramıyordu — atlama aşağıdan yukarı miras kalıyor. Dördü birlikte
-- kapatılmalı, üçü değil.
--
-- KULLANICI ETKİSİ: YOK. Doğrulandı — bu view'ları okuyan her istemci yolu
-- oturum arkasında: web `Leaderboard` yalnızca UserMenu/ScoreCard/
-- PlayerScoreCard'dan mount ediliyor; `useRankScores` misafirde `key` boş
-- olduğu için isteği HİÇ göndermiyor; portun `RankScores.ensure`ı aynı
-- şekilde `id != null` filtresiyle çıkıyor. İki anon route (`/game/:id`,
-- `/davet/:token`) yalnızca `get_shared_game` ve `get_friend_invite_info`
-- çağırıyor — ikisi de `anon`'da KALIYOR, bilerek.
--
-- `my_leaderboard_rank` BİLEREK dokunulmadı: `SECURITY INVOKER` ve
-- `k_lig_siralama`yı okuduğundan aşağıdaki revoke onu geçişli olarak zaten
-- kapatıyor. En dar değişiklik tercih edildi.
--
-- GERİ ALMA (tek satır, anında):
--   grant select on public.leaderboard to anon;  -- ve diğer üçü

revoke select on public.leaderboard          from anon;
revoke select on public.player_stats         from anon;
revoke select on public.player_stats_overall from anon;
revoke select on public.k_lig_siralama       from anon;

-- Fonksiyonlarda PUBLIC rolüne kuruluşta ÖRTÜK `execute` verilir; yalnızca
-- `anon`dan revoke etmek bu yüzden tek başına YETMEZ — PUBLIC üzerinden
-- erişim açık kalırdı. Depodaki mevcut desen de bu (`revoke all ... from
-- public, anon`).
revoke execute on function public.get_profile_age_gender(uuid) from public, anon;
