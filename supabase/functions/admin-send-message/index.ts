// Kelimeki — admin panelindeki Üyeler tablosundan tek bir üyeye elle
// yazılan mesajı (konu + gövde admin tarafından girilir) Brevo Transactional
// API ile gönderir. feedback-reply'dan farkı: bir feedback kaydına yanıt
// vermiyor, YENİ bir tane açıyor (origin: 'admin') — böylece "kime ne
// yazıldığı" admin panelinin Geri Bildirim sekmesinde kalıcı olarak görünür.
// Kayıt e-postadan ÖNCE oluşturuluyor çünkü mail içindeki "cevap için
// tıklayın" linkine bu kaydın id'si (?re=<id>) gömülüyor — Brevo gönderimi
// başarısız olursa önceden oluşturulan kayıt geri alınır (silinir).
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, buildNoreplyNoticeHtml, sendBrevoEmail } from '../_shared/email.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function buildMessageHtml(message: string, feedbackId: string, toName?: string): string {
  const greeting = toName ? `Merhaba ${escapeHtml(toName)},` : 'Merhaba,';
  return `
    <div style="font-family: -apple-system, sans-serif; max-width: 480px; margin: 0; color: #1a1a1a;">
      <p>${greeting}</p>
      <p style="white-space: pre-wrap;">${escapeHtml(message)}</p>
      <p style="font-size: 13px; color: #555; margin-top: 20px;">Saygılarımızla,<br/>Kelimeki Müşteri Hizmetleri</p>
      ${buildNoreplyNoticeHtml(feedbackId)}
    </div>
  `;
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

  let body: { to_user_id?: string; to_email?: string; to_name?: string; subject?: string; message?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  const toUserId = body.to_user_id?.trim() || undefined;
  const toEmail = body.to_email?.trim();
  const toName = body.to_name?.trim() || undefined;
  const subject = body.subject?.trim();
  const message = body.message?.trim();

  if (!toEmail || !subject || !message || subject.length > 200 || message.length > 5000) {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  if (!BREVO_API_KEY) {
    console.error('[admin-send-message] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ error: 'E-posta gönderim yapılandırması eksik.' }, 500);
  }

  const { data: inserted, error: insertError } = await supabase
    .from('feedback')
    .insert({
      user_id: toUserId ?? null,
      email: toEmail,
      subject,
      message,
      origin: 'admin',
      handled: true,
    })
    .select('id')
    .single();

  if (insertError || !inserted) {
    console.error('[admin-send-message] Kayıt oluşturma hatası:', insertError?.message);
    return jsonResponse({ error: 'Mesaj kaydedilemedi, gönderilmedi.' }, 500);
  }

  const brevoRes = await sendBrevoEmail(BREVO_API_KEY, {
    to: { email: toEmail, name: toName },
    subject,
    htmlContent: buildMessageHtml(message, inserted.id, toName),
  });

  if (!brevoRes.ok) {
    const detail = await brevoRes.text();
    console.error('[admin-send-message] Brevo hatası:', brevoRes.status, detail);
    await supabase.from('feedback').delete().eq('id', inserted.id);
    return jsonResponse({ error: 'E-posta gönderilemedi.' }, 502);
  }

  return jsonResponse({ ok: true });
});
