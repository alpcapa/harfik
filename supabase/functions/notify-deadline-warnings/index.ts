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
import { CORS_HEADERS, escapeHtml, sendBrevoEmail, buildBrandedEmailHtml, buildNoReplyNoticeHtml } from '../_shared/email.ts';
import { pushConfigured, sendPushToUser } from '../_shared/push.ts';

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
  // İsme iyelik eki EKLEME ("X'nin açtığı" DEĞİL, "X tarafından açılan") —
  // takma isimler keyfi olduğundan Türkçe ünlü uyumu programatik olarak
  // garanti edilemez, sabit bir 'nin eki isimlerin çoğunda yanlış çıkıyordu
  // ("T1'nin" → doğrusu "T1'in", "Ironman'nin" → "Ironman'in").
  // `notify-friend-request-reminders`'taki ("X tarafından gönderilen") ve
  // OnlineGameScreen'deki ("Sıra: {isim}") aynı ek-istemeyen kalıp.
  const bodyText = `${escapeHtml(creatorName)} tarafından açılan ${playerCount} kişilik oyunun süresi dolmak üzere. 24 saat içinde hamle yapmadığınız takdirde teslim olmuş sayılacaksınız ve lig puanınızdan 2 puan düşülecek.`;
  const body = `
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">${bodyText}</p>
    <p style="margin:0 0 24px 0;">
      <a href="https://kelimeki.com" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Şimdi Oyna</a>
    </p>
  `;
  return buildBrandedEmailHtml('Oyun Süresi Doluyor!', body, buildNoReplyNoticeHtml());
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

/**
 * Teslim uyarısı bildiriminin metni — iki çağrı yeri (Canlı ve YZ oyunları)
 * aynı cümleyi kullansın diye tek yerde.
 *
 * E-postanın gövdesiyle AYNI bilgi, bildirim satırına sığacak kadar
 * kısaltılmış — iki kanal aynı olayı anlatıyor, farklı şey söylemesin.
 */
function deadlinePushBody(creatorName: string, playerCount: number): string {
  return `${creatorName} tarafından açılan ${playerCount} kişilik oyunda `
    + '24 saat içinde hamle yapmazsan teslim olmuş sayılacaksın.';
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
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
      const recipientEmail = recipientAuth?.user?.email;
      const creatorProfile = profiles?.find((p) => p.id === game.created_by);
      const creatorName = creatorProfile?.display_name || creatorProfile?.first_name || 'Bir arkadaşın';

      // İşlemsel-ama-tercih-edilebilir bildirim — alıcı bunu kapattıysa
      // YALNIZCA e-postayı atla.
      //
      // ⚠ **30 Ağustos 2026'da DÜZELTİLDİ.** Burada `continue` vardı ve push
      // çağrısı aşağıdaydı; yani e-posta bildirimini kapatan kullanıcı push
      // da alamıyordu. Bu dosyanın kendi yorumu iki tercihin BAĞIMSIZ
      // olduğunu söylüyordu, kodu tutmuyordu — o gün push kanalı üç davet
      // fonksiyonuna yayılırken bulundu.
      const emailAcik = recipientProfile?.email_notifications_enabled !== false;
      if (!recipientEmail) {
        console.error('[notify-deadline-warnings] Alıcının e-postası bulunamadı:', currentSlot.user_id);
      } else if (emailAcik) {
        if (await sendDeadlineEmail(recipientEmail, creatorName, game.player_count as number)) sentOnline += 1;
      }
      // Push İKİNCİ kanal ve e-postadan SONRA — sıra bilinçli: bu satır ne
      // fırlatır ne de e-postanın sonucunu etkiler (bkz. sendPushToUser).
      await sendPushToUser(supabase, currentSlot.user_id as string, {
        title: 'Oyun Süresi Doluyor!',
        body: deadlinePushBody(creatorName, game.player_count as number),
        tag: `sure:${row.online_game_id}`,
      });
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

      const recipientEmail = recipientAuth?.user?.email;
      // Yerel (YZ) oyunda "oyunu açan" her zaman hesap sahibinin kendisidir.
      const ownerName = ownerProfile?.display_name || ownerProfile?.first_name || 'Sen';

      // Yerel oyunda hesap sahibi hem alıcı hem "oyunu açan" — tercihi
      // kapattıysa YALNIZCA e-postayı atla (yukarıdaki aynı düzeltme).
      const emailAcik = ownerProfile?.email_notifications_enabled !== false;
      if (!recipientEmail) {
        console.error('[notify-deadline-warnings] Hesap sahibinin e-postası bulunamadı:', row.user_id);
      } else if (emailAcik) {
        if (await sendDeadlineEmail(recipientEmail, ownerName, row.player_count as number)) sentLocal += 1;
      }
      await sendPushToUser(supabase, row.user_id as string, {
        title: 'Oyun Süresi Doluyor!',
        body: deadlinePushBody(ownerName, row.player_count as number),
        // Ayrı önek: YZ oyunlarının id'si `local_game_saves`ten, canlı
        // oyunlarınki `online_games`ten geliyor — iki ayrı tabloda aynı
        // uuid çıkması olası değil ama etiket alanı düz bir isim alanı ve
        // buna GÜVENİLMEZ.
        tag: `sure-yerel:${row.id}`,
      });
    } catch (err) {
      console.error('[notify-deadline-warnings] local satır hatası:', row.id, err);
    }
  }

  // `pushKanali` bir teşhis alanı: bu ortamdan Edge Function secret'ları
  // OKUNAMIYOR, dolayısıyla `FCM_SERVICE_ACCOUNT`ın gerçekten yüklendiğini ve
  // biçiminin doğru olduğunu (geçerli JSON + project_id/client_email/
  // private_key) kanıtlayan tek gözlem noktası bu. Yükün geri kalanını
  // kimse ayrıştırmıyor (cron çağırıyor), yani eklemenin bedeli yok.
  return jsonResponse({
    ok: true,
    sentOnline,
    sentLocal,
    pushKanali: pushConfigured() ? 'acik' : 'kapali',
  });
});
