-- Kelimeki — admin panelindeki üye "Kayıtlar" listesinde kullanıcıya görünen
-- iki etiket "rapor" yerine "şikayet" diyor.
--
-- Kullanıcı isteği (4 Ağustos 2026): "rapor et" İngilizceden türeme ve burada
-- ne anlama geldiği net değil; kullanıcıya görünen TÜM metinlerde "şikayet"
-- kullanılacak. İstemci tarafındaki karşılıkları (ChatSettingsModal,
-- ChatThread, TermsModal, PrivacyModal) aynı commit'te değişti; bu iki etiket
-- ise SQL'de üretildiğinden ayrı bir migration gerektirdi.
--
-- Kod tarafı bilerek DEĞİŞMEDİ — `kind` değerleri (`report_received` /
-- `report_withdrawn`) aynı kalıyor, çünkü `PlayerScoreCard` bunlara göre ikon
-- seçiyor (🚩/↩️) ve tablo/RPC adları da (`online_game_chat_reports`,
-- `report_online_game_participant`) teknik terminolojiyi koruyor. "k-lig"
-- rebrand'iyle aynı ilke: yalnızca GÖRÜNEN metin değişir.
--
-- Fonksiyonun geri kalanı 20260802104024_admin_get_member_activity_log ile
-- birebir aynı — yalnızca iki `title` sabiti değişti.
create or replace function public.admin_get_member_activity_log(p_user_id uuid)
returns table (
  kind text,
  created_at timestamptz,
  title text,
  detail text
)
language plpgsql
stable
security definer
set search_path = public, auth
as $function$
begin
  if not public.is_admin() then
    raise exception 'Yetkisiz erişim.';
  end if;

  return query
  select 'signup'::text, u.created_at, 'Üye Oldu'::text, null::text
  from auth.users u
  where u.id = p_user_id

  union all
  select
    case when l.banned then 'ban' else 'unban' end,
    l.created_at,
    case when l.banned then 'Hesabı Donduruldu' else 'Dondurma Kaldırıldı' end,
    coalesce(ap.display_name, ap.first_name, 'Admin') || ' tarafından'
  from public.admin_ban_log l
  left join public.profiles ap on ap.id = l.actor_user_id
  where l.target_user_id = p_user_id

  union all
  select 'feedback_user'::text, f.created_at, 'Görüş/Mesaj Gönderdi'::text,
    coalesce(nullif(f.subject, ''), left(f.message, 140))
  from public.feedback f
  where f.user_id = p_user_id and f.origin = 'user'

  union all
  select 'feedback_admin'::text, f.created_at, 'Admin Mesaj Gönderdi'::text,
    coalesce(nullif(f.subject, ''), left(f.message, 140))
  from public.feedback f
  where f.user_id = p_user_id and f.origin = 'admin'

  union all
  select 'feedback_replied'::text, f.replied_at, 'Admin Yanıt Verdi'::text,
    coalesce(nullif(f.subject, ''), left(f.reply, 140))
  from public.feedback f
  where f.user_id = p_user_id and f.replied_at is not null

  union all
  select 'report_received'::text, r.created_at, 'Şikayet Edildi'::text, r.reason
  from public.online_game_chat_reports r
  where r.reported_user_id = p_user_id

  union all
  select 'report_withdrawn'::text, r.withdrawn_at, 'Şikayet Geri Çekildi'::text, r.reason
  from public.online_game_chat_reports r
  where r.reported_user_id = p_user_id and r.withdrawn_at is not null

  order by created_at desc nulls last;
end;
$function$;

revoke all on function public.admin_get_member_activity_log(uuid) from public, anon;
grant execute on function public.admin_get_member_activity_log(uuid) to authenticated;
