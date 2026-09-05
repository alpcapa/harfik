-- `list_my_online_games` — N+1 alt sorguları LATERAL birleştirmeye çevirildi.
--
-- NEDEN (5 Eylül 2026, incelemenin 3. geçişi — performans): bu RPC
-- uygulamanın EN SICAK sorgusu (`pg_stat_statements`, 69 günlük pencere:
-- 35.513 çağrı, ortalama 25,76 ms, veritabanı yürütme süresinin %3,8'i —
-- Realtime'dan sonra en büyük ikinci kalem ve uygulamanın KENDİ kodundan
-- gelen en büyük kalem). Üç Realtime tüketicisi (Setup rozeti, LiveGamesTab
-- listesi, uygulama ikonu rozeti) her rakip hamlesinde onu yeniden çağırıyor.
--
-- ÖLÇÜLEN kusur: gövde slot başına AYNI satırı birden çok kez okuyordu.
-- 69 oyunluk gerçek bir kullanıcıda (`explain (analyze, buffers)`):
--   * `profiles` PK'sine slot başına İKİ ayrı bağıntılı alt sorgu
--     (`name` ve `avatar_url` ayrı ayrı) → 149 + 149 döngü, 295 + 295 tampon
--   * `my_invite_status` ve `my_invite_id` BİREBİR aynı sorgu, iki kez
--     → 69 + 69 döngü, 85 + 85 tampon
--   * `relation` için `friend_requests`e üç ayrı `exists`
--
-- ⚠ KAZANÇ TAMPONDA, SÜREDE DEĞİL — ilk ölçüm YANILTICIYDI ve düzeltildi.
-- İlk turda eski gövde `authenticated` rolüyle (RLS uygulanarak), yenisi
-- `postgres` ile (RLS'siz) ölçülmüş ve "12,1 → 6,0 ms" gibi görünmüştü.
-- Oysa fonksiyonun sahibi `postgres` ve BYPASSRLS taşıyor, yani
-- `security definer` gövdesinde RLS ZATEN uygulanmıyor. Aynı koşulda
-- (ikisi de RLS'siz, aynı kullanıcı, 10 tur, çıktının tamamı tüketilerek):
--
--   tampon:  1.240 → 706   (**%43 az**)
--   süre:    4,75 → 4,84 ms  (fark yok; yeni sürüm marjinal olarak yavaş)
--
-- Yani bu veri boyutunda darboğaz G/Ç değil CPU (jsonb kurma + slot başına
-- sıralama) ve her şey zaten shared_buffers'da ("hit", tek bir "read" yok).
-- Üretimdeki 25,76 ms ortalamanın çoğu da bu planın değil eşzamanlılığın/
-- bağlantı yükünün payı.
--
-- NEDEN YİNE DE DEĞİŞTİRİLDİ: eski plan slot başına İKİ indeks inişi
-- yapıyordu (`profiles_pkey`, 149 + 149 döngü); yeni gövdede planlayıcı
-- bunu tek bir hash join'e çevirebiliyor. Kullanıcı başına oyun sayısı
-- büyüdükçe indeks inişleri doğrusal artar, hash kurulumu artmaz — bu bir
-- PROJEKSİYON, bugünkü veride ölçülmüş bir kazanç DEĞİL. Bugünkü kanıt
-- yalnızca "tampon yarıya indi, çıktı bit bit aynı, süre değişmedi".
--
-- ÇIKTI DEĞİŞMEDİ — kanıt: 51 kullanıcının HEPSİ için eski ve yeni gövde
-- yan yana koşulup `array_agg(to_jsonb(t))` ile karşılaştırıldı, sıfır fark.
-- Karşılaştırmanın kör olmadığı üç negatif eşle ayrıca kanıtlandı (`name`,
-- slot `invite_status` ve `my_invite_id` tek tek bozulduğunda sırasıyla
-- 21/21/20 kullanıcıda fark çıktı).
--
-- ⚠ TEK İSTİSNA — `pending_outgoing`/`pending_incoming` dalını MEVCUT VERİ
-- HİÇ UYARMIYOR (o dalı bilerek ters çevirdiğimizde karşılaştırma sıfır
-- fark verdi, yani veri orada kör). Eşdeğerlik ölçümle değil gövdeden
-- kanıtlandı: eski `pending_outgoing` "user_id = ben AND friend_id = slot
-- olan bir satır var mı", yeni `giden` ise ÇİFTİN satırları (ben→slot ya da
-- slot→ben) üzerinde `bool_or(user_id = ben)`. Çift kümesindeki bir satırda
-- `user_id = ben` ise `friend_id` zorunlu olarak slot'tur, yani iki koşul
-- aynı; `gelen` için simetriği. Kendisi olma durumu ikisinde de daha
-- önceki `self` dalında yakalanıyor. Satır yoksa `bool_or` NULL döner ve
-- `case when null` alınmaz — `exists`in false'uyla aynı.
--
-- Not: `create or replace` ACL'i korur — `anon`un execute yetkisi YOK
-- (5 Eylül güvenlik geçişi) ve bu değişiklikten sonra da yok; doğrulandı.
-- Dış `where` aynı kaldı, yani görünürlüğe hiç dokunulmadı.

create or replace function public.list_my_online_games()
returns table(
  id uuid,
  created_by uuid,
  player_count integer,
  status text,
  slots jsonb,
  created_at timestamp with time zone,
  my_role text,
  my_invite_status text,
  my_invite_id uuid
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    og.id,
    og.created_by,
    og.player_count,
    og.status,
    (
      select jsonb_agg(
        case
          when (elem.slot ->> 'type') = 'human' then
            elem.slot || jsonb_build_object(
              'name', pr.ad,
              'avatar_url', pr.avatar_url,
              'relation', case
                when (elem.slot ->> 'user_id')::uuid = auth.uid() then 'self'
                when fr.kabul then 'accepted'
                when fr.giden then 'pending_outgoing'
                when fr.gelen then 'pending_incoming'
                else null
              end,
              'invite_status', inv.status
            )
          else elem.slot
        end
        order by elem.ord
      )
      from jsonb_array_elements(og.slots) with ordinality as elem(slot, ord)
      -- Ad + avatar TEK okumada (önce iki ayrı bağıntılı alt sorguydu).
      left join lateral (
        select coalesce(p.display_name, p.first_name) as ad, p.avatar_url
        from public.profiles p
        where p.id = (elem.slot ->> 'user_id')::uuid
      ) pr on true
      -- Üç `exists` yerine çiftin satırları üzerinde tek geçiş.
      left join lateral (
        select
          bool_or(f.status = 'accepted') as kabul,
          bool_or(f.user_id = auth.uid()) as giden,
          bool_or(f.friend_id = auth.uid()) as gelen
        from public.friend_requests f
        where (f.user_id = auth.uid() and f.friend_id = (elem.slot ->> 'user_id')::uuid)
           or (f.user_id = (elem.slot ->> 'user_id')::uuid and f.friend_id = auth.uid())
      ) fr on true
      left join lateral (
        select gi_slot.status
        from public.game_invites gi_slot
        where gi_slot.online_game_id = og.id
          and gi_slot.invitee_id = (elem.slot ->> 'user_id')::uuid
        order by gi_slot.created_at desc
        limit 1
      ) inv on true
    ) as slots,
    og.created_at,
    case when og.created_by = auth.uid() then 'creator' else 'invitee' end as my_role,
    -- Aynı satırın `status` ve `id`si TEK okumada (önce iki özdeş alt sorgu).
    mine.status as my_invite_status,
    mine.id as my_invite_id
  from public.online_games og
  left join lateral (
    select gi.id, gi.status
    from public.game_invites gi
    where gi.online_game_id = og.id and gi.invitee_id = auth.uid()
    order by gi.created_at desc
    limit 1
  ) mine on true
  where og.created_by = auth.uid()
     or exists (
       select 1 from public.game_invites gi2
       where gi2.online_game_id = og.id and gi2.invitee_id = auth.uid()
     )
  order by og.created_at desc;
$function$;
