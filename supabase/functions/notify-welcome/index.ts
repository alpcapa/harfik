// Kelimeki — yeni üyeye "hoş geldiniz" e-postası (21 Ağustos 2026, kullanıcı
// isteği).
//
// TETİKLEYİCİ: `auth.users` üzerindeki `on_auth_user_welcome` trigger'ı, üye
// e-posta ADRESİNİ DOĞRULADIĞI anda `net.http_post` ile çağırır — kayıt
// anında DEĞİL. Gerekçe migration'da yazılı: bu projede doğrulama açık,
// kayıt anında adres henüz kanıtlanmamış olur (bounce = gönderim itibarı) ve
// kullanıcı o saniyede zaten onay mailini alıyor.
//
// Bu yüzden `verify_jwt` KAPALI — çağıran bir kullanıcı değil Postgres'in
// kendisi, hiçbir JWT taşımıyor (`notify-turn-timeout-surrender` ile aynı
// desen).
//
// GÜVENLİK: verify_jwt kapalı olduğundan bu uç teorik olarak herkese açık bir
// POST hedefi ve `user_id` GİZLİ DEĞİL (k-lig/`game_likers` gibi RPC'ler
// girişli herkese kullanıcı id'si döndürüyor). Bu yüzden fonksiyon üç şeyi
// kendisi doğruluyor:
//   1. Hesap gerçekten var ve e-postası DOĞRULANMIŞ.
//   2. `welcome_email_sent_at` YAKIN ZAMANDA damgalanmış (trigger'ın iddiası).
//      Bu, ucun tekrar tekrar çağrılarak bir kullanıcıya mail bombardımanı
//      yapılmasını engelliyor: pencere dışında sessizce no-op.
//   3. Alıcı işlemsel bildirimleri kapatmamış (`email_notifications_enabled`).
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sendBrevoEmail, buildBrandedEmailHtml } from '../_shared/email.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

/** Trigger'ın damgasıyla bu çağrı arasında kabul edilen azami gecikme. */
const CLAIM_WINDOW_MS = 15 * 60 * 1000;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function buildHtml(name: string | undefined): string {
  const greeting = name ? `Sayın ${escapeHtml(name)},` : 'Sayın kullanıcımız,';
  const body = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">${greeting}</p>
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">Kelimeki'ye hoş geldiniz. Sizi aramızda görmek bizi çok mutlu etti.</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">Hemen Yapay Zeka ile ilk oyununuzu oynayın; sonrasında uygulamadaki &quot;Görüş Bildir&quot; formundan izlenimlerinizi paylaşırsanız çok seviniriz.</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Hemen Oyna</a>
    </p>
    <p style="font-size:13px;color:#8A93A2;margin-top:20px;">Saygılarımızla,<br/><span style="display: inline-block; margin-top: 4px;">Kelimeki Müşteri Hizmetleri</span></p>
  `;
  return buildBrandedEmailHtml('Kelimeki’ye Hoş Geldiniz', body);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  let body: { user_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  const userId = body.user_id?.trim();
  if (!userId) {
    return jsonResponse({ error: 'user_id gerekli.' }, 400);
  }

  if (!BREVO_API_KEY) {
    console.error('[notify-welcome] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ ok: true, sent: false, reason: 'no_api_key' });
  }

  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const [{ data: authUser }, { data: profile }] = await Promise.all([
    serviceClient.auth.admin.getUserById(userId),
    serviceClient
      .from('profiles')
      .select('display_name, first_name, email_notifications_enabled, welcome_email_sent_at')
      .eq('id', userId)
      .maybeSingle(),
  ]);

  // 1. Adres doğrulanmış olmalı — doğrulanmamış bir adrese yazmıyoruz.
  if (!authUser?.user?.email_confirmed_at) {
    return jsonResponse({ ok: true, sent: false, reason: 'not_confirmed' });
  }

  // 2. Trigger'ın iddiası taze olmalı (tekrar çağrı koruması).
  const claimedAt = profile?.welcome_email_sent_at
    ? Date.parse(profile.welcome_email_sent_at)
    : NaN;
  if (!Number.isFinite(claimedAt) || Date.now() - claimedAt > CLAIM_WINDOW_MS) {
    return jsonResponse({ ok: true, sent: false, reason: 'stale_claim' });
  }

  // 3. İşlemsel bildirim tercihi — yeni üyede varsayılan açık, yine de
  //    diğer altı bildirimle aynı davranış.
  if (profile?.email_notifications_enabled === false) {
    return jsonResponse({ ok: true, sent: false, reason: 'opted_out' });
  }

  const recipientEmail = authUser.user.email;
  if (!recipientEmail) {
    console.error('[notify-welcome] Hedefin e-postası bulunamadı:', userId);
    return jsonResponse({ ok: true, sent: false, reason: 'no_email' });
  }

  const recipientName = profile?.display_name || profile?.first_name || undefined;

  const brevoRes = await sendBrevoEmail(BREVO_API_KEY, {
    to: { email: recipientEmail, name: recipientName },
    subject: 'Kelimeki — Hoş Geldiniz',
    htmlContent: buildHtml(recipientName),
  });

  if (!brevoRes.ok) {
    const detail = await brevoRes.text();
    console.error('[notify-welcome] Brevo hatası:', brevoRes.status, detail);
    return jsonResponse({ ok: true, sent: false, reason: 'brevo_error' });
  }

  return jsonResponse({ ok: true, sent: true });
});
