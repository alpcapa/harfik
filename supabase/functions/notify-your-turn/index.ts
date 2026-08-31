// Kelimeki — "sıra sende" push bildirimi (ROADMAP #13 / Faz 4, 30 Ağustos
// 2026). Bir hamle sırayı devrettiğinde, sırası GELEN insan oyuncuya push
// gönderir. E-POSTA KANALI BİLEREK YOK: #13'ün tablosunda bu olayın e-posta
// geçmişi hiç olmadı ve hamle sıklığında e-posta gürültü olurdu — teslim
// uyarısı (24 saat kala, `notify-deadline-warnings`) e-posta tarafını
// zaten karşılıyor.
//
// TETİKLEYİCİ İSTEMCİ DEĞİL, SUNUCU: `online_game_states.current` ilerleyince
// koşan `_notify_your_turn` trigger'ı pg_net ile burayı çağırıyor
// (migration: 20260830194913_notify_your_turn_trigger.sql). İstemciden
// çağrılsaydı sahadaki eski sürümler (1.0.2 ve tüm eski web sekmeleri)
// hamle yapınca bildirim ÜRETMEZDİ — Faz 4'ün "SÜRÜM GEREKTİRMEZ" vaadi
// ancak sunucu tetiklemesiyle tutuyor.
//
// Auth: verify_jwt KAPALI (pg_net JWT taşımıyor — cron fonksiyonlarıyla
// aynı sınıf; bkz. kök CLAUDE.md "Edge Function deploy", sayım bu
// fonksiyonla YEDİ → SEKİZ oldu). ⚠ Bu yüzden HEDEF GÖVDEDEN ALINMAZ:
// dışarıdan elle çağrılabilen bir fonksiyona `target_user_id` geçirmek,
// herkese keyfi push tetikletmek olurdu. Gövde yalnızca `online_game_id`
// taşır; kimin sırası olduğunu, oyunun bitip bitmediğini ve koltuğun insan
// olup olmadığını fonksiyon service-role client'ıyla KENDİSİ okur — yani
// kötü niyetli bir çağrı en fazla, gerçekten sırası gelen kişiye gerçek
// durumu söyleyen bir bildirim üretebilir. (Tekrar-çağrı spam'ine karşı
// asıl bastırma trigger'da: hedef son 10 dakikada hamle yaptıysa pg_net
// çağrısı hiç yapılmıyor.)
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS } from '../_shared/email.ts';
import { sendPushToUser } from '../_shared/push.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
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
  const gameId = body.online_game_id;
  if (!gameId) {
    return jsonResponse({ error: 'online_game_id gerekli.' }, 400);
  }

  const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Hedef GÖVDEDEN DEĞİL canlı durumdan (başlıktaki güvenlik gerekçesi).
  const [{ data: game }, { data: state }] = await Promise.all([
    db.from('online_games')
      .select('status, player_count, slots')
      .eq('id', gameId)
      .maybeSingle(),
    db.from('online_game_states')
      .select('current, is_game_over')
      .eq('online_game_id', gameId)
      .maybeSingle(),
  ]);

  if (!game || !state || game.status !== 'active' || state.is_game_over) {
    return jsonResponse({ ok: true, pushed: 0, reason: 'not_active' });
  }
  const slots = game.slots as { type: string; user_id?: string | null }[];
  const slot = slots?.[state.current as number];
  if (!slot || slot.type !== 'human' || !slot.user_id) {
    return jsonResponse({ ok: true, pushed: 0, reason: 'not_human' });
  }
  const targetId = slot.user_id;

  // "Kim oynadı" — son hamle. YZ hamlesinde player_user_id null (şema).
  // Hamleci profili tek sorguda: son hamle + profil ayrı ayrı, çünkü hamle
  // YZ'ninse profil sorgusu hiç gerekmiyor.
  const { data: lastMove } = await db
    .from('online_game_moves')
    .select('player_user_id')
    .eq('online_game_id', gameId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  let actorName = 'Yapay Zeka';
  if (lastMove?.player_user_id) {
    const { data: prof } = await db
      .from('profiles')
      .select('display_name, first_name')
      .eq('id', lastMove.player_user_id)
      .maybeSingle();
    actorName = prof?.display_name || prof?.first_name || 'Rakibin';
  }

  // Metin kullanıcı onaylı (30 Ağustos 2026). Başlık kartlardaki "SIRA
  // SENDE" diliyle aynı aileden. `link`i 1.0.3+ istemciler okuyup tahtayı
  // doğrudan açıyor (Faz 3); eski istemcide dokunuş yalnızca uygulamayı
  // açar — sözleşme `_shared/push.ts` başlığında.
  const pushed = await sendPushToUser(db, targetId, {
    title: 'Sıra sende!',
    body: `${actorName} hamlesini yaptı — ${game.player_count} kişilik oyunda sıra sende.`,
    link: `kelimeki://oyun/${gameId}`,
    // Aynı oyunun yeni "sıra sende"si eskisinin YERİNE geçsin (bkz.
    // `_shared/push.ts` → `PushMessage.tag`). Bu bildirim hamle
    // sıklığında geldiğinden birikmeye en açık olan bu.
    tag: `sira:${gameId}`,
  });

  return jsonResponse({ ok: true, pushed });
});
