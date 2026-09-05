-- `league_rewards` okuma politikası: `auth.uid()` satır başına değil BİR KEZ.
--
-- NEDEN (5 Eylül 2026, incelemenin 3. geçişi — performans): Supabase
-- performans advisor'ının tek WARN seviyeli kalemi buydu
-- (`auth_rls_initplan`). Politika `using (auth.uid() is not null)` yazıyordu;
-- planlayıcı bunu satır başına yeniden değerlendiriyor. `(select auth.uid())`
-- ise bir InitPlan'a dönüşüp sorgu başına bir kez koşuyor.
--
-- ⚠ ÖLÇÜ DÜRÜSTLÜĞÜ: tablo 26 satır (k-lig kademe/ödül tablosu, sabit
-- yapılandırma), yani bugünkü kazanç okuma başına 26 çağrı yerine 1 — pratikte
-- ÖLÇÜLEBİLİR DEĞİL. Değişikliğin gerekçesi hız değil, **advisor listesini
-- temiz tutmak**: bir sonraki inceleme geçişi bu zemine bakacak ve tek
-- kalıcı WARN'ın gürültü olarak öğrenilmesi, gerçek bir WARN'ın gözden
-- kaçmasının en olağan yolu.
--
-- Aynı düzeltmenin bu depodaki öncülü: `20260802212119_rls_auth_uid_initplan_perf`.
-- Anlam DEĞİŞMİYOR — `auth.uid()` bir ifade içinde zaten `stable`.

alter policy league_rewards_select_authenticated
  on public.league_rewards
  using ((select auth.uid()) is not null);
