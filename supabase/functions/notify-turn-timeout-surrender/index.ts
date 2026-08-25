// Kelimeki — bir Canlı oyunda sırası gelen oyuncu 48 saat içinde hamle
// yapmazsa (`check_turn_timeout` RPC'si, "Canlı Oyun — Faz 3.6") otomatik
// teslim olur; bu fonksiyon o oyuncuya (ve varsa AYNI ANDA -2 cezası
// uygulanan diğer daha önce teslim olmuş oyunculara) durumu bildiren bir
// e-posta gönderir.
//
// Tetikleyici: `check_turn_timeout`, oyunun GERÇEKTEN bittiği anda (kalan
// aktif oyuncu sayısı 1'e düştüğünde — `_finish_online_game_records`
// çağrıldığı, yani `games` satırlarının ve -2 cezasının GERÇEKTEN
// uygulandığı an) `net.http_post` ile bu fonksiyonu SQL içinden çağırır
// (`notify-deadline-warnings`'in cron'dan çağırdığı aynı pg_net deseni,
// farkı zamanlanmış değil bir RPC'nin içinden tetiklenmesi). Bu yüzden
// `verify_jwt` KAPALI — çağıran bir kullanıcı değil Postgres'in kendisi,
// hiçbir JWT taşımıyor.
//
// 4 kişilik bir oyunda bir oyuncu erken teslim olsa bile (aktif sayısı
// hâlâ >1 ise) oyun hemen bitmez — bu yüzden -2 cezası da o an
// uygulanmaz, yalnızca oyun GERÇEKTEN son bulduğunda (aktif sayısı 1'e
// düştüğünde) TÜM önceden teslim olmuş oyuncular için AYNI ANDA
// uygulanır. Bu fonksiyon da tam o ana denk geldiğinden, o oyundaki
// TÜM teslim olmuş insan koltuklarına (yalnızca en son teslim olana
// değil) e-posta gönderir — hepsinin cezası bu anda gerçekten işlendi.
//
// Güvenlik: verify_jwt kapalı olduğundan bu endpoint teorik olarak
// herkese açık bir POST hedefi — kötüye kullanımı önlemek için fonksiyon
// kendi başına `online_game_states.end_reason='surrender'` VE
// `is_game_over=true` olduğunu, ayrıca hedef koltuğun gerçekten
// `surrendered:true` olduğunu doğrulamadan e-posta göndermiyor; sahte bir
// online_game_id ile çağrılırsa (ya da oyun timeout DIŞINDA bir sebeple
// bittiyse) sessizce no-op döner.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sendBrevoEmail, buildBrandedEmailHtml, buildNoReplyNoticeHtml } from '../_shared/email.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function joinTurkishList(names: string[]): string {
  if (names.length === 0) return 'Rakibin';
  if (names.length === 1) return names[0];
  return `${names.slice(0, -1).join(', ')} ve ${names[names.length - 1]}`;
}

function buildHtml(name: string, opponentNames: string, playerCount: number): string {
  const greeting = `Sayın ${escapeHtml(name)},`;
  const body = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">${greeting}</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">${escapeHtml(opponentNames)} ile oynadığınız ${playerCount} kişilik oyun 48 saat içinde hamle yapmadığınızdan dolayı sonlanmış ve maalesef k-lig puanınızdan 2 puan düşürülmüştür.</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">Tekrar oyun başlatmak için aşağıdaki butona tıklayın.</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Oyun Aç</a>
    </p>
    <p style="font-size:13px;color:#8A93A2;margin-top:20px;">Saygılarımızla,<br/><span style="display: inline-block; margin-top: 4px;">Kelimeki Müşteri Hizmetleri</span></p>
  `;
  return buildBrandedEmailHtml('Oyununuz Süre Aşımından Sona Erdi', body, buildNoReplyNoticeHtml());
}

interface Slot {
  type: 'human' | 'ai';
  user_id?: string;
}
interface PlayerState {
  name: string;
  isAI?: boolean;
  surrendered?: boolean;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  let body: { online_game_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz istek.' }, 400);
  }

  const gameId = body.online_game_id?.trim();
  if (!gameId) {
    return jsonResponse({ error: 'online_game_id gerekli.' }, 400);
  }

  if (!BREVO_API_KEY) {
    console.error('[notify-turn-timeout-surrender] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ ok: true, sent: 0, reason: 'no_api_key' });
  }

  const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const [{ data: game }, { data: state }] = await Promise.all([
    serviceClient.from('online_games').select('slots, player_count').eq('id', gameId).maybeSingle(),
    serviceClient
      .from('online_game_states')
      .select('players, end_reason, is_game_over')
      .eq('online_game_id', gameId)
      .maybeSingle(),
  ]);

  if (!game || !state || state.end_reason !== 'surrender' || !state.is_game_over) {
    return jsonResponse({ ok: true, sent: 0, reason: 'not_finished_by_timeout' });
  }

  // Atomik "iddia" — bu fonksiyon verify_jwt=false ile herkese açık bir POST
  // hedefi olduğundan, yukarıdaki kontrol tek başına yeterli değil: oyunun
  // surrendered/is_game_over durumu bir kez sağlandıktan sonra KALICI olarak
  // true kaldığından, bitmiş bir oyunun online_game_id'sini bilen herkes bu
  // URL'e tekrar tekrar POST atarak aynı kullanıcı(lar)a "-2 puan cezası
  // aldın" mailini sınırsız kez gönderebilirdi. `timeout_notified_at`'i
  // yalnızca hâlâ null iken dolduran bu UPDATE, `deadline_warning_sent_at`
  // deseniyle aynı: `.is(...)` filtresi eşleşmezse (zaten bildirilmiş) hiçbir
  // satır güncellenmez, `claimed` null döner ve fonksiyon mail göndermeden çıkar.
  const { data: claimed } = await serviceClient
    .from('online_game_states')
    .update({ timeout_notified_at: new Date().toISOString() })
    .eq('online_game_id', gameId)
    .is('timeout_notified_at', null)
    .select('online_game_id')
    .maybeSingle();

  if (!claimed) {
    return jsonResponse({ ok: true, sent: 0, reason: 'already_notified' });
  }

  const slots = game.slots as Slot[];
  const players = state.players as PlayerState[];

  const recipients = slots
    .map((seat, index) => ({ seat, player: players[index], index }))
    .filter((x) => x.seat.type === 'human' && !!x.player?.surrendered && !!x.seat.user_id);

  if (recipients.length === 0) {
    return jsonResponse({ ok: true, sent: 0, reason: 'no_surrendered_humans' });
  }

  let sent = 0;
  for (const r of recipients) {
    // Alıcı başına try/catch — biri hata verirse (ör. getUserById/Brevo
    // geçici sorunu) diğer alıcılara gönderim yine de denensin (aynı
    // gerekçe notify-deadline-warnings/notify-friend-request-reminders'da).
    try {
      const opponentNames = slots
        .map((seat, i) => ({ seat, i }))
        .filter(({ i }) => i !== r.index)
        .map(({ seat, i }) => players[i]?.name || (seat.type === 'ai' ? 'Yapay Zeka' : 'Oyuncu'));

      const [{ data: authUser }, { data: recipientProfile }] = await Promise.all([
        serviceClient.auth.admin.getUserById(r.seat.user_id!),
        serviceClient.from('profiles').select('email_notifications_enabled').eq('id', r.seat.user_id!).maybeSingle(),
      ]);

      // İşlemsel-ama-tercih-edilebilir bildirim — alıcı bunu kapattıysa atla.
      if (recipientProfile?.email_notifications_enabled === false) continue;

      const email = authUser?.user?.email;
      if (!email) {
        console.error('[notify-turn-timeout-surrender] Alıcının e-postası bulunamadı:', r.seat.user_id);
        continue;
      }

      const brevoRes = await sendBrevoEmail(BREVO_API_KEY, {
        to: { email, name: r.player.name },
        subject: 'Kelimeki — Oyununuz Süre Aşımından Sona Erdi',
        htmlContent: buildHtml(r.player.name, joinTurkishList(opponentNames), game.player_count),
      });

      if (brevoRes.ok) {
        sent += 1;
      } else {
        const detail = await brevoRes.text();
        console.error('[notify-turn-timeout-surrender] Brevo hatası:', brevoRes.status, detail);
      }
    } catch (err) {
      console.error('[notify-turn-timeout-surrender] alıcı hatası:', r.seat.user_id, err);
    }
  }

  return jsonResponse({ ok: true, sent });
});
