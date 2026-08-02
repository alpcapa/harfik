// Kelimeki — hem Canlı (online) oyunlarda sırası gelen oyuncuya (48 saatlik
// turn_deadline) hem de YZ'ye karşı oynanan "Devam Eden Oyunlar"a (7 günlük
// ABANDON_TIMEOUT_MS terk-edilme penceresi) teslim süresine 24 saatten az
// kaldığında bir hatırlatma e-postası gönderir.
//
// pg_cron + pg_net ile düzenli aralıklarla (15 dakikada bir) tetiklenir —
// projedeki diğer "hafif" (kullanıcı etkileşimine bağlı) desenlerin AKSİNE
// (bkz. CLAUDE.md "Canlı Oyun — Faz 3.6", check_turn_timeout/
// check_invite_expiry), bu bildirim kimsenin uygulamayı açmasını beklemez —
// aksi halde tamamen terk edilmiş bir oyun için kimse tetiklenmeyi
// tetikleyemezdi. Bu yüzden verify_jwt KAPALI: çağıranın kimliği hiç
// kontrol edilmiyor (cron'un kendisi, dışarıdan parametre almıyor), fonksiyon
// SADECE kendi service-role client'ıyla çalışıyor. Tekrar tekrar çağrılması
// zararsız — her satır `deadline_warning_sent_at`'i atomik olarak
// (`.is(..., null)` filtreli UPDATE) "iddia edip" işaretlediğinden en fazla
// bir kez e-posta gider.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sendBrevoEmail, buildBrandedEmailHtml } from '../_shared/email.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// Opsiyonel savunma-derinliği katmanı (kod incelemesi, Orta bulgu):
// verify_jwt zaten kapalı olduğundan bu uç teorik olarak herkese açık bir
// POST hedefi. Tekrar tekrar çağrılması zararsız (atomik iddia sayesinde en
// fazla bir kez mail gider) ama gereksiz DB/Brevo yükü oluşturabilir. Bir
// `CRON_SECRET` custom secret'ı (BREVO_API_KEY ile aynı yerden, Dashboard →
// Edge Functions → Secrets) tanımlanıp pg_cron'un net.http_post çağrısına
// `Authorization: Bearer <secret>` header'ı eklenirse bu kontrol devreye
// girer; tanımlı değilse (bugünkü hâliyle) davranış DEĞİŞMEZ — bu yüzden
// geriye dönük uyumlu, isteğe bağlı bir sertleştirme.
const CRON_SECRET = Deno.env.get('CRON_SECRET');

// src/utils/gameStorage.ts'teki ABANDON_TIMEOUT_MS ile aynı sabit/gerekçe.
const ABANDON_TIMEOUT_MS = 7 * 24 * 60 * 60 * 1000;
const WARNING_WINDOW_MS = 24 * 60 * 60 * 1000;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function buildHtml(creatorName: string, playerCount: number): string {
  const bodyText = `${escapeHtml(creatorName)}'nin açtığı ${playerCount} kişilik oyunun süresi dolmak üzere. 24 saat içinde hamle yapmadığınız taktirde teslim olmuş sayılacaksınız ve lig puanınızdan 2 puan düşülecek.`;
  const body = `
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">${bodyText}</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Şimdi Oyna</a>
    </p>
  `;
  return buildBrandedEmailHtml('Oyun Süresi Doluyor!', body);
}

async function sendDeadlineEmail(email: string, creatorName: string, playerCount: number): Promise<boolean> {
  if (!BREVO_API_KEY) return false;
  const res = await sendBrevoEmail(BREVO_API_KEY, {
    to: { email },
    subject: 'Oyun Süresi Doluyor!',
    htmlContent: buildHtml(creatorName, playerCount),
  });
  if (!res.ok) {
    console.error('[notify-deadline-warnings] Brevo hatası:', res.status, await res.text());
  }
  return res.ok;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (CRON_SECRET && req.headers.get('Authorization') !== `Bearer ${CRON_SECRET}`) {
    return jsonResponse({ error: 'Yetkisiz.' }, 401);
  }

  if (!BREVO_API_KEY) {
    console.error('[notify-deadline-warnings] BREVO_API_KEY tanımlı değil.');
    return jsonResponse({ ok: true, sentOnline: 0, sentLocal: 0, reason: 'no_api_key' });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const windowEndIso = new Date(nowMs + WARNING_WINDOW_MS).toISOString();

  let sentOnline = 0;
  let sentLocal = 0;

  // ── Canlı oyunlar — sırası gelen oyuncunun 48 saatlik teslim süresi ──────
  const { data: dueOnline, error: onlineErr } = await supabase
    .from('online_game_states')
    .select('online_game_id, current, turn_deadline')
    .eq('is_game_over', false)
    .not('turn_deadline', 'is', null)
    .gt('turn_deadline', nowIso)
    .lte('turn_deadline', windowEndIso)
    .is('deadline_warning_sent_at', null);

  if (onlineErr) {
    console.error('[notify-deadline-warnings] online_game_states sorgu hatası:', onlineErr.message);
  }

  for (const row of dueOnline ?? []) {
    // Her satır kendi try/catch'inde — bir satırda beklenmedik bir hata
    // (ör. auth.admin.getUserById/Brevo'da geçici bir ağ sorunu) diğer
    // satırların işlenmesini engellemesin diye (önceden bir hata tüm
    // döngüyü kesip geri kalan satırları o çalıştırmada hiç denemeden
    // bırakıyordu — kod incelemesi).
    try {
      // Atomik iddia — bu satırı biz "sahiplendik" mi (başka bir eşzamanlı
      // çalıştırma aynı satırı zaten işaretlemiş olabilir).
      const { data: claimed } = await supabase
        .from('online_game_states')
        .update({ deadline_warning_sent_at: new Date().toISOString() })
        .eq('online_game_id', row.online_game_id)
        .is('deadline_warning_sent_at', null)
        .select('online_game_id')
        .maybeSingle();
      if (!claimed) continue;

      const { data: game } = await supabase
        .from('online_games')
        .select('created_by, player_count, slots')
        .eq('id', row.online_game_id)
        .maybeSingle();
      if (!game) continue;

      const slots = game.slots as { type: string; user_id?: string }[];
      const currentSlot = slots[row.current];
      if (!currentSlot || currentSlot.type !== 'human' || !currentSlot.user_id) continue;

      const [{ data: recipientAuth }, { data: profiles }] = await Promise.all([
        supabase.auth.admin.getUserById(currentSlot.user_id),
        supabase
          .from('profiles')
          .select('id, display_name, first_name, email_notifications_enabled')
          .in('id', [game.created_by, currentSlot.user_id]),
      ]);

      const recipientProfile = profiles?.find((p) => p.id === currentSlot.user_id);
      // İşlemsel-ama-tercih-edilebilir bildirim — alıcı bunu kapattıysa atla.
      if (recipientProfile?.email_notifications_enabled === false) continue;

      const recipientEmail = recipientAuth?.user?.email;
      if (!recipientEmail) {
        console.error('[notify-deadline-warnings] Alıcının e-postası bulunamadı:', currentSlot.user_id);
        continue;
      }

      const creatorProfile = profiles?.find((p) => p.id === game.created_by);
      const creatorName = creatorProfile?.display_name || creatorProfile?.first_name || 'Bir arkadaşın';
      if (await sendDeadlineEmail(recipientEmail, creatorName, game.player_count as number)) sentOnline += 1;
    } catch (err) {
      console.error('[notify-deadline-warnings] online satır hatası:', row.online_game_id, err);
    }
  }

  // ── YZ oyunları — 7 günlük terk-edilme penceresi ─────────────────────────
  // Sabit bir deadline sütunu yok — deadline = updated_at + ABANDON_TIMEOUT_MS
  // olduğundan pencere, updated_at üzerinden eşdeğer bir aralığa çevrilir.
  const localWindowStartIso = new Date(nowMs - ABANDON_TIMEOUT_MS).toISOString();
  const localWindowEndIso = new Date(nowMs - ABANDON_TIMEOUT_MS + WARNING_WINDOW_MS).toISOString();

  const { data: dueLocal, error: localErr } = await supabase
    .from('local_game_saves')
    .select('id, user_id, player_count')
    .gt('updated_at', localWindowStartIso)
    .lte('updated_at', localWindowEndIso)
    .is('deadline_warning_sent_at', null);

  if (localErr) {
    console.error('[notify-deadline-warnings] local_game_saves sorgu hatası:', localErr.message);
  }

  for (const row of dueLocal ?? []) {
    try {
      const { data: claimed } = await supabase
        .from('local_game_saves')
        .update({ deadline_warning_sent_at: new Date().toISOString() })
        .eq('id', row.id)
        .is('deadline_warning_sent_at', null)
        .select('id')
        .maybeSingle();
      if (!claimed) continue;

      const [{ data: recipientAuth }, { data: ownerProfile }] = await Promise.all([
        supabase.auth.admin.getUserById(row.user_id),
        supabase
          .from('profiles')
          .select('display_name, first_name, email_notifications_enabled')
          .eq('id', row.user_id)
          .maybeSingle(),
      ]);

      // Yerel oyunda hesap sahibi hem alıcı hem "oyunu açan" — tercihi kapattıysa atla.
      if (ownerProfile?.email_notifications_enabled === false) continue;

      const recipientEmail = recipientAuth?.user?.email;
      if (!recipientEmail) {
        console.error('[notify-deadline-warnings] Hesap sahibinin e-postası bulunamadı:', row.user_id);
        continue;
      }

      // Yerel (YZ) oyunda "oyunu açan" her zaman hesap sahibinin kendisidir.
      const ownerName = ownerProfile?.display_name || ownerProfile?.first_name || 'Sen';
      if (await sendDeadlineEmail(recipientEmail, ownerName, row.player_count as number)) sentLocal += 1;
    } catch (err) {
      console.error('[notify-deadline-warnings] local satır hatası:', row.id, err);
    }
  }

  return jsonResponse({ ok: true, sentOnline, sentLocal });
});
