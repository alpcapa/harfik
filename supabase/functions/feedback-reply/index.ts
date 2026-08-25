// Kelimeki — admin panelinden gönderilen görüş bildirimi yanıtlarını Brevo
// Transactional Email API ile e-posta olarak iletir ve feedback tablosuna
// (reply/replied_at/replied_by) kaydeder.
//
// Auth: SUPABASE_URL/SUPABASE_ANON_KEY (runtime tarafından otomatik
// sağlanır) ile çağıranın kendi JWT'si kullanılarak bir client oluşturulur —
// bu sayede select/update RLS'i (is_admin()) doğal olarak uygulanır, ayrı
// bir yetki kontrolü kod tekrarı gerekmez. BREVO_API_KEY, Supabase Dashboard
// → Edge Functions → Secrets üzerinden elle eklenmiş bir custom secret'tır
// (SMTP kimlik bilgilerinden farklı, Brevo'nun HTTP API'si için).
import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  CORS_HEADERS,
  escapeHtml,
  buildSupportReplyNoticeHtml,
  sendBrevoEmail,
  buildBrandedEmailHtml,
  brevoErrorMessage,
  KELIMEKI_SUPPORT_SENDER,
} from '../_shared/email.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function buildReplyHtml(
  originalMessage: string,
  reply: string,
  feedbackId: string,
  recipientName?: string,
): string {
  const greeting = recipientName ? `Merhaba ${escapeHtml(recipientName)},` : 'Merhaba,';
  const body = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">${greeting}</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">Bizimle iletişime geçtiğin için çok teşekkürler. Cevabımız aşağıdaki gibidir:</p>
    <blockquote style="margin:0 0 16px 0;padding:10px 14px;border-left:3px solid #DCE2EA;color:#1B2430;font-size:15px;line-height:1.6;white-space:pre-wrap;">${escapeHtml(reply)}</blockquote>
    ${buildSupportReplyNoticeHtml(feedbackId)}
    <p style="font-size:12px;color:#8A93A2;margin-top:20px;">Gönderdiğin mesaj:<br/><em style="white-space: pre-wrap;">${escapeHtml(originalMessage)}</em></p>
    <p style="font-size:13px;color:#8A93A2;margin-top:12px;">Saygılarımızla,<br/><span style="display: inline-block; margin-top: 4px;">Kelimeki Müşteri Hizmetleri</span></p>
  `;
  return buildBrandedEmailHtml('Geri bildiriminize yanıt', body);
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

  let body: { feedback_id?: string; reply?: string; recipient_name?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  const feedbackId = body.feedback_id;
  const replyText = body.reply?.trim();
  const recipientName = body.recipient_name?.trim() || undefined;

  if (!feedbackId || !replyText || replyText.length > 5000) {
    return jsonResponse({ error: 'Geçersiz yanıt metni.' }, 400);
  }

  const { data: row, error: fetchError } = await supabase
    .from('feedback')
    .select('id, email, message')
    .eq('id', feedbackId)
    .single();

  if (fetchError || !row) {
    return jsonResponse({ error: 'Geri bildirim bulunamadı.' }, 404);
  }

  if (!row.email) {
    return jsonResponse({ error: 'Bu geri bildirimde e-posta adresi yok, yanıt gönderilemez.' }, 400);
  }

  if (!BREVO_API_KEY) {
    console.error('[feedback-reply] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ error: 'E-posta gönderim yapılandırması eksik.' }, 500);
  }

  // Bu maili bir İNSAN yazdı — gönderen destek@, "Yanıtla" gerçek bir
  // kutuya (Zoho) düşer. Cevap admin panelinde OKUNMAZ, yalnızca "Zoho"
  // rozetini artırır (bkz. supabase/migrations/…_support_inbox.sql).
  const brevoRes = await sendBrevoEmail(BREVO_API_KEY, {
    to: { email: row.email },
    subject: 'Kelimeki — Geri bildiriminize yanıt',
    htmlContent: buildReplyHtml(row.message, replyText, feedbackId, recipientName),
    sender: KELIMEKI_SUPPORT_SENDER,
    replyTo: KELIMEKI_SUPPORT_SENDER,
  });

  if (!brevoRes.ok) {
    const detail = await brevoRes.text();
    console.error('[feedback-reply] Brevo hatası:', brevoRes.status, detail);
    return jsonResponse({ error: brevoErrorMessage(brevoRes.status, detail) }, 502);
  }

  const { error: updateError } = await supabase
    .from('feedback')
    .update({
      reply: replyText,
      replied_at: new Date().toISOString(),
      replied_by: userData.user.id,
    })
    .eq('id', feedbackId);

  if (updateError) {
    console.error('[feedback-reply] Kayıt güncelleme hatası:', updateError.message);
    return jsonResponse({ error: 'Yanıt gönderildi ama kaydedilemedi.' }, 500);
  }

  return jsonResponse({ ok: true });
});
