// Kelimeki — 3 gün cevapsız kalan arkadaşlık isteklerine bir kereliğine
// hatırlatma e-postası gönderir.
//
// notify-deadline-warnings ile aynı desen: pg_cron + pg_net ile günde bir
// kez tetiklenir, verify_jwt KAPALI (cron çağırıyor, kullanıcı JWT'si yok),
// yalnızca kendi service-role client'ıyla çalışır. Her satır
// reminder_sent_at'i atomik (`.is(..., null)` filtreli UPDATE) ile "iddia
// edip" işaretlediğinden tekrar tekrar tetiklenmesi zararsız — en fazla bir
// kez e-posta gider. İstek bu 3 gün içinde kabul/reddedilirse (status
// pending'den çıkar) ya da iptal edilirse (satır tamamen silinir) sorguya
// hiç düşmez; iptal + yeniden gönderim de (yeni satır, reminder_sent_at
// yeniden null) sayacı doğal olarak sıfırlar — ayrı bir reset mantığına
// gerek yok.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sendBrevoEmail, buildBrandedEmailHtml } from './_shared/email.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const REMINDER_DELAY_MS = 3 * 24 * 60 * 60 * 1000;

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
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;"><strong>${escapeHtml(inviterName)}</strong> tarafından gönderilen arkadaşlık davetine henüz cevap vermedin. Atlamış olabilirsin diye hatırlatmak istedik.</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Kelimeki'yi Aç</a>
    </p>
    <p style="margin:24px 0 0 0;padding-top:12px;border-top:1px solid #DCE2EA;font-size:13px;line-height:1.6;color:#8A93A2;">Uygulamayı açtığında hesap menündeki arkadaşlık rozetinden isteği kabul edebilir ya da reddedebilirsin. Bu istek için gönderilecek son hatırlatma bu — bir daha tekrarlanmayacak.</p>
  `;
  return buildBrandedEmailHtml('Bekleyen bir arkadaşlık isteğin var', body);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (!BREVO_API_KEY) {
    console.error('[notify-friend-request-reminders] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ ok: true, sent: 0, reason: 'no_api_key' });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const cutoffIso = new Date(Date.now() - REMINDER_DELAY_MS).toISOString();

  const { data: due, error: dueErr } = await supabase
    .from('friend_requests')
    .select('user_id, friend_id')
    .eq('status', 'pending')
    .lte('created_at', cutoffIso)
    .is('reminder_sent_at', null);

  if (dueErr) {
    console.error('[notify-friend-request-reminders] sorgu hatası:', dueErr.message);
    return jsonResponse({ ok: true, sent: 0, reason: 'query_error' });
  }

  let sent = 0;

  for (const row of due ?? []) {
    // Atomik iddia — başka bir eşzamanlı/tekrar eden çalıştırma bu satırı
    // zaten işaretlemiş olabilir.
    const { data: claimed } = await supabase
      .from('friend_requests')
      .update({ reminder_sent_at: new Date().toISOString() })
      .eq('user_id', row.user_id)
      .eq('friend_id', row.friend_id)
      .is('reminder_sent_at', null)
      .select('user_id')
      .maybeSingle();
    if (!claimed) continue;

    const [{ data: recipientAuth }, { data: profiles }] = await Promise.all([
      supabase.auth.admin.getUserById(row.friend_id),
      supabase.from('profiles').select('id, display_name, first_name').in('id', [row.user_id, row.friend_id]),
    ]);

    const recipientEmail = recipientAuth?.user?.email;
    if (!recipientEmail) {
      console.error('[notify-friend-request-reminders] Alıcının e-postası bulunamadı:', row.friend_id);
      continue;
    }

    const inviterProfile = profiles?.find((p) => p.id === row.user_id);
    const recipientProfile = profiles?.find((p) => p.id === row.friend_id);
    const inviterName = inviterProfile?.display_name || inviterProfile?.first_name || 'Bir kullanıcı';
    const recipientName = recipientProfile?.display_name || recipientProfile?.first_name || undefined;

    const res = await sendBrevoEmail(BREVO_API_KEY, {
      to: { email: recipientEmail, name: recipientName },
      subject: 'Kelimeki — Bekleyen bir arkadaşlık isteğin var',
      htmlContent: buildHtml(inviterName, recipientName),
    });

    if (!res.ok) {
      console.error('[notify-friend-request-reminders] Brevo hatası:', res.status, await res.text());
      continue;
    }
    sent += 1;
  }

  return jsonResponse({ ok: true, sent });
});
