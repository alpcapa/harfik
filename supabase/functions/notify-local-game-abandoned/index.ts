// Kelimeki — Yapay Zeka'ya karşı oynanan ve 7 gün boyunca hiç hamle
// yapılmadığı için terk edilmiş sayılan bir yerel oyunun -2 k-lig cezasını
// hesap sahibine bildiren e-posta. `saveGame` (src/lib/api.ts) bir kaydı
// GERÇEKTEN yeni eklediğinde `game.surrendered === true` ise bu fonksiyonu
// fire-and-forget çağırır — yerel (Yapay Zeka) oyunlarda `surrendered:true`
// yalnızca bu 7 günlük terk-edilme akışından gelir (manuel/anlık teslim
// yolu 29 Temmuz 2026'da tamamen kaldırıldı, bkz. CLAUDE.md "Teslim olma"),
// yani bu bayrak tek başına "bu kayıt bir terk-edilme cezası" anlamına
// geliyor — ayrı bir işaret/parametre taşımaya gerek yok.
//
// Auth: notify-account-banned'in aksine burada hedef İLE çağıran AYNI kişi
// (kullanıcı kendi terk ettiği oyunun cezasını kendi hesabına bildiriyor),
// bu yüzden service-role client'a hiç gerek yok — çağıranın kendi JWT'siyle
// hem e-postasını (`auth.getUser()`) hem adını (`profiles`, `auth.uid() =
// id` RLS'i kendi satırını okumaya zaten izin veriyor) okuyoruz.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sendBrevoEmail, buildBrandedEmailHtml, buildNoReplyNoticeHtml } from '../_shared/email.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function buildHtml(name: string, playerCount: number): string {
  const greeting = `Sayın ${escapeHtml(name)},`;
  const body = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">${greeting}</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">Yapay Zeka'ya karşı açtığınız ${playerCount} kişilik oyun 7 gün boyunca hamle yapmadığınızdan dolayı sonlanmış ve maalesef k-lig puanınızdan 2 puan düşürülmüştür.</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">Tekrar oyun başlatmak için aşağıdaki butona tıklayın.</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Oyun Aç</a>
    </p>
    <p style="font-size:13px;color:#8A93A2;margin-top:20px;">Saygılarımızla,<br/><span style="display: inline-block; margin-top: 4px;">Kelimeki Müşteri Hizmetleri</span></p>
  `;
  return buildBrandedEmailHtml('Oyununuz Süre Aşımından Sona Erdi', body, buildNoReplyNoticeHtml());
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

  let body: { player_count?: number; game_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  // Gerçekten böyle bir terk-edilme kaydı var mı doğrula — önceden
  // çağıranın gönderdiği çıplak player_count'a hiç sorgusuz güveniliyordu,
  // yani herhangi bir girişli kullanıcı kendine sahte bir "-2 puan" maili
  // gönderebiliyordu (kod incelemesi). Yerel terk-edilme akışında
  // surrendered:true YALNIZCA gerçek 7 günlük terk-edilme kuyruğundan gelir
  // (bkz. dosya başındaki not) — bu yüzden kendi hesabına ait, online_game_id
  // null, surrendered=true bir satırın varlığı yeterli kanıt.
  if (!body.game_id) {
    return jsonResponse({ ok: true, sent: false, reason: 'missing_game_id' });
  }
  const { data: gameRow } = await supabase
    .from('games')
    .select('id, player_count, surrendered, online_game_id, user_id')
    .eq('id', body.game_id)
    .eq('user_id', userData.user.id)
    .maybeSingle();
  if (!gameRow || !gameRow.surrendered || gameRow.online_game_id !== null) {
    return jsonResponse({ ok: true, sent: false, reason: 'not_verified' });
  }
  // Metindeki oyuncu sayısı artık istemcinin gönderdiği değeri değil,
  // doğrulanmış satırdan (gameRow) okunuyor.
  const playerCount = gameRow.player_count === 4 ? 4 : 2;

  if (!BREVO_API_KEY) {
    console.error('[notify-local-game-abandoned] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ ok: true, sent: false, reason: 'no_api_key' });
  }

  const email = userData.user.email;
  if (!email) {
    console.error('[notify-local-game-abandoned] Kullanıcının e-postası bulunamadı:', userData.user.id);
    return jsonResponse({ ok: true, sent: false, reason: 'no_email' });
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('display_name, first_name, email_notifications_enabled')
    .eq('id', userData.user.id)
    .maybeSingle();

  // İşlemsel-ama-tercih-edilebilir bildirim — kendisi kapattıysa gönderme.
  if (profile?.email_notifications_enabled === false) {
    return jsonResponse({ ok: true, sent: false, reason: 'recipient_opted_out' });
  }

  const name = profile?.display_name || profile?.first_name || 'kullanıcımız';

  const brevoRes = await sendBrevoEmail(BREVO_API_KEY, {
    to: { email, name },
    subject: 'Kelimeki — Oyununuz Süre Aşımından Sona Erdi',
    htmlContent: buildHtml(name, playerCount),
  });

  if (!brevoRes.ok) {
    const detail = await brevoRes.text();
    console.error('[notify-local-game-abandoned] Brevo hatası:', brevoRes.status, detail);
    return jsonResponse({ ok: true, sent: false, reason: 'brevo_error' });
  }

  return jsonResponse({ ok: true, sent: true });
});
