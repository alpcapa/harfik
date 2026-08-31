// Kelimeki — bir arkadaşlık isteği gönderildiğinde alıcıya e-posta bildirimi
// yollar (`sendFriendRequest`, src/lib/api.ts, insert başarılı olup istek
// hâlâ 'pending' ise hemen ardından tetikler). Bu işlemsel bir bildirimdir
// (marketing_consent'e bağlı DEĞİL) — kayıt formundaki pazarlama onayı yalnızca
// Kelimeki'nin kendi tanıtım içeriği içindir, burada ise alıcının kendi
// hesabına gelen somut bir isteği bildiriyoruz.
//
// Eklenme gerekçesi (29 Temmuz 2026): Arkadaşlık istekleri öncesinde
// bilinçli olarak hiç e-posta göndermiyordu (bkz. friends_system migration'ı,
// maliyet/gürültü kaygısı) — yalnızca UserMenu'deki rozet vardı. Kullanıcı
// uygulamayı hiç açmazsa isteğin varlığından habersiz kalıyordu; bu Edge
// Function o boşluğu dolduruyor.
//
// Auth: çağıranın kendi JWT'siyle bir client oluşturulur (feedback-reply ile
// aynı desen) — hem kimliğini doğrulamak hem de RLS'in
// (friend_requests_select_own) yalnızca ilişkinin taraflarına izin vermesi
// sayesinde "gerçekten böyle bir istek var mı" kontrolü için kullanılır;
// böylece keyfi bir alıcıya mail atılamaz. Alıcının e-postası (auth.users,
// hiçbir client rolüne hiç açılmaz) ve isimler ayrı bir service-role
// client'la okunur — play-ai-turn'deki aynı ayrım.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sanitizeForSubject, sendBrevoEmail, buildBrandedEmailHtml, buildNoReplyNoticeHtml } from '../_shared/email.ts';
import { sendPushToUser } from '../_shared/push.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function buildHtml(inviterName: string, recipientName?: string): string {
  const greeting = recipientName ? `Merhaba ${escapeHtml(recipientName)},` : 'Merhaba,';
  const body = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">${greeting}</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;"><strong>${escapeHtml(inviterName)}</strong> seni Kelimeki'de arkadaş olarak eklemek istiyor.</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Kelimeki'yi Aç</a>
    </p>
    <p style="margin:24px 0 0 0;padding-top:12px;border-top:1px solid #DCE2EA;font-size:13px;line-height:1.6;color:#8A93A2;">Uygulamayı açtığında hesap menündeki arkadaşlık rozetinden isteği kabul edebilir ya da reddedebilirsin.</p>
  `;
  return buildBrandedEmailHtml('Yeni arkadaşlık isteği', body, buildNoReplyNoticeHtml());
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Yetkisiz.' }, 401);
  }
  const jwt = authHeader.replace('Bearer ', '');

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return jsonResponse({ error: 'Yetkisiz.' }, 401);
  }

  let body: { friend_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  const friendId = body.friend_id;
  if (!friendId) {
    return jsonResponse({ error: 'friend_id gerekli.' }, 400);
  }

  // Satırın gerçekten var olması VE hâlâ 'pending' olması, isteğin gerçekten
  // gönderildiğini ve karşılıklı otomatik kabul (handle_friend_request_insert
  // trigger'ı) ile sonuçlanmadığını doğrular.
  const { data: reqRow, error: reqError } = await supabase
    .from('friend_requests')
    .select('status')
    .eq('user_id', userData.user.id)
    .eq('friend_id', friendId)
    .maybeSingle();

  if (reqError || !reqRow || reqRow.status !== 'pending') {
    return jsonResponse({ ok: true, sent: false, reason: 'not_pending' });
  }

  if (!BREVO_API_KEY) {
    console.error('[notify-friend-request] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ ok: true, sent: false, reason: 'no_api_key' });
  }

  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const [{ data: authUser }, { data: profiles }] = await Promise.all([
    serviceClient.auth.admin.getUserById(friendId),
    serviceClient
      .from('profiles')
      .select('id, display_name, first_name, email_notifications_enabled')
      .in('id', [userData.user.id, friendId]),
  ]);

  const recipientEmail = authUser?.user?.email;
  const inviterProfile = profiles?.find((p) => p.id === userData.user.id);
  const recipientProfile = profiles?.find((p) => p.id === friendId);
  const inviterName = inviterProfile?.display_name || inviterProfile?.first_name || 'Bir kullanıcı';
  const recipientName = recipientProfile?.display_name || recipientProfile?.first_name || undefined;

  // İşlemsel-ama-tercih-edilebilir bildirim — alıcı bunu Hesap Ayarları'ndan
  // kapatmış olabilir (bkz. CLAUDE.md, marketing_consent'ten AYRI alan).
  //
  // ⚠ Bu tercih YALNIZCA e-postayı kapatıyor. Eskiden burada `return` vardı;
  // push eklendiğinde o `return` iki tercihi tek tercihe indirirdi — "e-postayı
  // kapat, bildirim açık kalsın" diyen kullanıcı hiçbir şey almazdı.
  // (Aynı hata `notify-deadline-warnings`'te GERÇEKTEN yaşandı, 30 Ağustos
  // 2026'da bulundu; bkz. `_shared/push.ts` → `sendPushToUser`.)
  const emailAcik = recipientProfile?.email_notifications_enabled !== false;

  let sent = false;
  let emailReason: string | undefined;
  if (!recipientEmail) {
    console.error('[notify-friend-request] Alıcının e-postası bulunamadı:', friendId);
    emailReason = 'no_email';
  } else if (!emailAcik) emailReason = 'recipient_opted_out';
  else {
    const brevoRes = await sendBrevoEmail(BREVO_API_KEY, {
      to: { email: recipientEmail, name: recipientName },
      // İsim, gövdenin aksine escapeHtml'e değil sanitizeForSubject'e tabi —
      // konu satırı HTML render edilmediğinden escape değil, kontrol
      // karakteri/uzunluk sınırlaması gerekiyor (bkz. _shared/email.ts).
      subject: `Kelimeki — ${sanitizeForSubject(inviterName)} sana arkadaşlık isteği gönderdi`,
      htmlContent: buildHtml(inviterName, recipientName),
    });
    if (brevoRes.ok) sent = true;
    else {
      const detail = await brevoRes.text();
      console.error('[notify-friend-request] Brevo hatası:', brevoRes.status, detail);
      emailReason = 'brevo_error';
    }
  }

  // Push İKİNCİ kanal ve e-postadan SONRA — sıra bilinçli: `sendPushToUser`
  // ne fırlatır ne de e-postanın sonucunu etkiler.
  const pushed = await sendPushToUser(serviceClient, friendId, {
    title: 'Yeni arkadaşlık isteği',
    body: `${inviterName} seni Kelimeki'de arkadaş olarak eklemek istiyor.`,
    // Önek GÖNDEREN'in kimliğiyle: 3 gün sonraki hatırlatıcı (
    // `notify-friend-request-reminders`) AYNI etiketi kullanıyor, yani
    // hatırlatma bu bildirimin yerine geçiyor — ikisi aynı işi anlatıyor.
    tag: `arkadas:${userData.user.id}`,
  });

  return jsonResponse({ ok: true, sent, pushed, ...(emailReason ? { reason: emailReason } : {}) });
});
