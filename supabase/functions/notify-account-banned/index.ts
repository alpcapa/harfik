// Kelimeki — bir hesap admin tarafından dondurulunca (Üyeler tablosundaki
// "Hesabı Dondur" linki, `admin_set_user_banned(true)`) o kullanıcıya
// süresiz dondurulduğunu bildiren bir uyarı e-postası gönderir. Dondurma
// kaldırıldığında (unban) HİÇBİR mail gönderilmez — kullanıcı isteği
// yalnızca dondurma anını kapsıyor.
//
// Auth: admin-send-message ile aynı desen — çağıranın kendi JWT'siyle
// `is_admin()` kontrolü yapılır (anon-key client). Hedefin e-postası/adı ve
// (varsa) en güncel şikayet tarihi (`online_game_chat_reports`) ayrı bir
// service-role client'la okunur — auth.users hiçbir client rolüne hiç
// açılmadığından (notify-friend-request'teki aynı ayrım).
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sendBrevoEmail, buildBrandedEmailHtml } from '../_shared/email.ts';

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

function formatIstanbulDateTime(iso: string): string {
  return new Intl.DateTimeFormat('tr-TR', {
    timeZone: 'Europe/Istanbul',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(iso));
}

function buildHtml(name: string | undefined, reportDate: string | null): string {
  const greeting = name ? `Sayın ${escapeHtml(name)},` : 'Sayın kullanıcımız,';
  const reasonSentence = reportDate
    ? `${escapeHtml(formatIstanbulDateTime(reportDate))} tarihinde tarafımıza ulaşan bir şikayet neticesinde ve yapmış olduğumuz incelemeler sonunda`
    : 'Yapmış olduğumuz incelemeler sonunda';
  const body = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">${greeting}</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">${reasonSentence}, Kullanım Koşulları'na aykırı hareket ettiğiniz tespit edilmiş olup hesabınız süresiz olarak dondurulmuştur.</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">Bir yanlışlık olduğunuzu düşünüyorsanız lütfen aşağıdaki linkten bizimle temasa geçiniz.</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com/?contact=1" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Bizimle İletişime Geç</a>
    </p>
    <p style="font-size:13px;color:#8A93A2;margin-top:20px;">Saygılarımızla,<br/><span style="display: inline-block; margin-top: 4px;">Kelimeki Müşteri Hizmetleri</span></p>
  `;
  return buildBrandedEmailHtml('Hesabınız Dondurulmuştur', body);
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

  const { data: isAdmin } = await supabase.rpc('is_admin');
  if (!isAdmin) {
    return jsonResponse({ error: 'Bu işlem için yetkin yok.' }, 403);
  }

  let body: { user_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  const targetUserId = body.user_id?.trim();
  if (!targetUserId) {
    return jsonResponse({ error: 'user_id gerekli.' }, 400);
  }

  if (!BREVO_API_KEY) {
    console.error('[notify-account-banned] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ ok: true, sent: false, reason: 'no_api_key' });
  }

  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const [{ data: authUser }, { data: profile }, { data: lastReport }] = await Promise.all([
    serviceClient.auth.admin.getUserById(targetUserId),
    serviceClient.from('profiles').select('display_name, first_name').eq('id', targetUserId).maybeSingle(),
    serviceClient
      .from('online_game_chat_reports')
      .select('created_at')
      .eq('reported_user_id', targetUserId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);

  const recipientEmail = authUser?.user?.email;
  if (!recipientEmail) {
    console.error('[notify-account-banned] Hedefin e-postası bulunamadı:', targetUserId);
    return jsonResponse({ ok: true, sent: false, reason: 'no_email' });
  }

  const recipientName = profile?.display_name || profile?.first_name || undefined;

  const brevoRes = await sendBrevoEmail(BREVO_API_KEY, {
    to: { email: recipientEmail, name: recipientName },
    subject: 'Kelimeki — Hesabınız Dondurulmuştur',
    htmlContent: buildHtml(recipientName, lastReport?.created_at ?? null),
  });

  if (!brevoRes.ok) {
    const detail = await brevoRes.text();
    console.error('[notify-account-banned] Brevo hatası:', brevoRes.status, detail);
    return jsonResponse({ ok: true, sent: false, reason: 'brevo_error' });
  }

  return jsonResponse({ ok: true, sent: true });
});
