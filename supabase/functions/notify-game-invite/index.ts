// Kelimeki — bir Canlı oyun kurulup insan koltuklarına davet açıldığında
// (`createOnlineGame`, src/lib/api.ts, `create_online_game` RPC'si başarılı
// olduktan hemen sonra tetikler) her davetliye e-posta bildirimi yollar.
// İşlemsel bir bildirim (marketing_consent'e bağlı DEĞİL) — somut bir
// davetin var olduğunu bildiriyor, tanıtım değil.
//
// Eklenme gerekçesi (29 Temmuz 2026): davet yalnızca uygulama-içi bir rozetle
// (Setup'taki "Arkadaşınla (N)") görünüyordu. Alıcı 7 gün içinde uygulamayı
// hiç açmazsa online_game_invite_expiry migration'ındaki check_invite_expiry
// daveti sessizce iptal ediyordu — kullanıcı bundan hiç haberdar olmuyordu.
//
// Auth: çağıranın kendi JWT'siyle bir client oluşturulur; online_games'i bu
// client'la okuyup (RLS: online_games_select_party) hem "bu oyunun tarafı
// mısın" hem de ayrıca "gerçekten kurucusu musun" kontrolü yapılır — yalnızca
// kurucu bu bildirimi tetikleyebilir. Davetlilerin e-postası (auth.users) ve
// isimleri ayrı bir service-role client'la okunur (play-ai-turn'deki aynı
// ayrım — bu bilgiler hiçbir zaman client rolüne açılmaz).
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sanitizeForSubject, sendBrevoEmail, buildBrandedEmailHtml } from '../_shared/email.ts';

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

function buildHtml(inviterName: string, playerCount: number, recipientName?: string): string {
  const greeting = recipientName ? `Merhaba ${escapeHtml(recipientName)},` : 'Merhaba,';
  const body = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">${greeting}</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;"><strong>${escapeHtml(inviterName)}</strong> seni ${playerCount} kişilik bir Canlı Kelimeki oyununa davet etti.</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Daveti Gör</a>
    </p>
    <p style="margin:24px 0 0 0;padding-top:12px;border-top:1px solid #DCE2EA;font-size:13px;line-height:1.6;color:#8A93A2;">Uygulamayı açıp "Arkadaşınla" sekmesinden kabul edebilir ya da reddedebilirsin. Davet 7 gün içinde yanıtlanmazsa kendiliğinden iptal olur.</p>
  `;
  return buildBrandedEmailHtml('Canlı oyun daveti', body);
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

  let body: { online_game_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  const gameId = body.online_game_id;
  if (!gameId) {
    return jsonResponse({ error: 'online_game_id gerekli.' }, 400);
  }

  const { data: game, error: gameError } = await supabase
    .from('online_games')
    .select('created_by, player_count')
    .eq('id', gameId)
    .maybeSingle();

  if (gameError || !game || game.created_by !== userData.user.id) {
    return jsonResponse({ error: 'Bu oyunun kurucusu değilsin.' }, 403);
  }

  if (!BREVO_API_KEY) {
    console.error('[notify-game-invite] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ ok: true, sent: 0, reason: 'no_api_key' });
  }

  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const [{ data: invites, error: invitesError }, { data: inviterProfile }] = await Promise.all([
    serviceClient.from('game_invites').select('invitee_id').eq('online_game_id', gameId).eq('status', 'pending'),
    serviceClient.from('profiles').select('display_name, first_name').eq('id', userData.user.id).maybeSingle(),
  ]);

  if (invitesError || !invites || invites.length === 0) {
    return jsonResponse({ ok: true, sent: 0 });
  }

  const inviterName = inviterProfile?.display_name || inviterProfile?.first_name || 'Bir kullanıcı';
  let sentCount = 0;

  for (const invite of invites) {
    const [{ data: authUser }, { data: recipientProfile }] = await Promise.all([
      serviceClient.auth.admin.getUserById(invite.invitee_id),
      serviceClient
        .from('profiles')
        .select('display_name, first_name, email_notifications_enabled')
        .eq('id', invite.invitee_id)
        .maybeSingle(),
    ]);

    // İşlemsel-ama-tercih-edilebilir bildirim — bu davetli kapatmışsa yalnızca
    // onu atlıyoruz, diğer davetlilere gönderim devam ediyor.
    if (recipientProfile?.email_notifications_enabled === false) continue;

    const recipientEmail = authUser?.user?.email;
    if (!recipientEmail) {
      console.error('[notify-game-invite] Davetlinin e-postası bulunamadı:', invite.invitee_id);
      continue;
    }
    const recipientName = recipientProfile?.display_name || recipientProfile?.first_name || undefined;

    const brevoRes = await sendBrevoEmail(BREVO_API_KEY, {
      to: { email: recipientEmail, name: recipientName },
      // İsim, gövdenin aksine escapeHtml'e değil sanitizeForSubject'e tabi —
      // konu satırı HTML render edilmediğinden escape değil, kontrol
      // karakteri/uzunluk sınırlaması gerekiyor (bkz. _shared/email.ts).
      subject: `Kelimeki — ${sanitizeForSubject(inviterName)} seni Canlı bir oyuna davet etti`,
      htmlContent: buildHtml(inviterName, game.player_count as number, recipientName),
    });

    if (!brevoRes.ok) {
      const detail = await brevoRes.text();
      console.error('[notify-game-invite] Brevo hatası:', brevoRes.status, detail);
      continue;
    }
    sentCount += 1;
  }

  return jsonResponse({ ok: true, sent: sentCount });
});
