// Kelimeki — uygulama içinden hesap silme (ROADMAP madde 2, MAĞAZA BLOKERİ).
//
// NEDEN VAR: Apple 5.1.1(v) ve Google'ın veri silme şartı, hesap açtıran
// uygulamalarda uygulama İÇİNDEN başlatılabilen bir silme yolu istiyor.
// (Web'deki `/hesap-silme/` sayfası Play'in Data safety formuna verilen
// TALEP adresidir; bu fonksiyon işin kendisini yapan taraftır.)
//
// ── YETKİ MODELİ ──────────────────────────────────────────────────────────
// Kimlik ÇAĞIRANIN KENDİ JWT'siyle doğrulanır (`auth.getUser`), silinen de
// her zaman O kullanıcıdır — gövdeden gelen bir kullanıcı kimliği KABUL
// EDİLMEZ, öyle olsaydı fonksiyon "istediğim hesabı sil" ucuna dönerdi.
// Asıl kaskad `public.delete_account_cascade` RPC'sinde ve o RPC'nin
// execute yetkisi `authenticated`/`anon`tan geri alınmış durumda: yalnızca
// buradaki service-role client çağırabiliyor.
//
// ── ATOMİKLİK SINIRI (bilinçli) ───────────────────────────────────────────
// İki adım var: (1) RPC public şemayı tek işlemde temizler, (2)
// `auth.admin.deleteUser` hesabı siler. Sıra TERS ÇEVRİLEMEZ — dört tablonun
// FK'si NO ACTION olduğundan (`online_game_messages`, `online_game_moves`,
// `online_game_message_mutes`, `online_game_chat_reports`) temizlik
// yapılmadan deleteUser FK ihlaliyle düşer. (2) düşerse veri gitmiş ama
// hesap duruyor olur; RPC İDEMPOTENT (ikinci koşuda her sayaç 0 döner), yani
// kullanıcı butona tekrar bastığında hesap da silinir. Hata mesajı bunu
// açıkça söylüyor.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS } from '../_shared/email.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

/** Gerçek silme için istemcinin göndermesi gereken onay dizesi. Kazara bir
 *  `POST {}` isteğinin hesabı silmesini engelleyen son bariyer — UI zaten
 *  ayrı bir onay penceresi gösteriyor. */
const ONAY = 'HESABIMI SIL';

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return jsonResponse({ error: 'Yetkisiz.' }, 401);
  const jwt = authHeader.replace('Bearer ', '');

  const caller = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await caller.auth.getUser(jwt);
  if (userError || !userData?.user) return jsonResponse({ error: 'Yetkisiz.' }, 401);
  const uid = userData.user.id;

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { /* gövdesiz istek = kuru çalıştırma */ }
  // Varsayılan KURU: gövdesiz/bozuk bir istek asla silmez.
  const dryRun = body.dryRun !== false;
  if (!dryRun && body.confirm !== ONAY) {
    return jsonResponse({ error: 'Silme onayı eksik.' }, 400);
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Avatar dosyaları `avatars/<uid>/avatar.<ext>` yolunda (bkz. uploadAvatar).
  // Depolama kovası kaskada dahil DEĞİL — `auth.users` silinince dosyalar
  // öksüz kalır, bu yüzden açıkça siliniyor.
  const { data: avatarFiles } = await admin.storage.from('avatars').list(uid);
  const avatarPaths = (avatarFiles ?? []).map((f) => `${uid}/${f.name}`);

  const { data: rapor, error: rpcError } = await admin.rpc('delete_account_cascade', {
    p_uid: uid,
    p_dry_run: dryRun,
  });
  if (rpcError) return jsonResponse({ error: rpcError.message }, 400);

  const cikti = {
    ...(rapor as Record<string, unknown>),
    silinecek: {
      ...((rapor as { silinecek?: Record<string, unknown> })?.silinecek ?? {}),
      avatar_dosyalari: avatarPaths.length,
    },
  };

  if (dryRun) return jsonResponse(cikti);

  if (avatarPaths.length > 0) {
    const { error: storageError } = await admin.storage.from('avatars').remove(avatarPaths);
    // Dosya silinemezse hesabı silmekten VAZGEÇME: veri tabanı zaten
    // temizlendi, geri dönüş yok. Öksüz kalan bir avatar dosyası hiçbir
    // profile bağlı olmadığından kimseye gösterilmiyor; yine de raporda
    // görünüyor, sessizce yutulmuyor.
    if (storageError) console.error('[delete-my-account] avatar silinemedi:', storageError.message);
  }

  const { error: delError } = await admin.auth.admin.deleteUser(uid);
  if (delError) {
    console.error('[delete-my-account] deleteUser hatası:', delError.message);
    return jsonResponse({
      error: 'Verilerin silindi ama hesap kapatılamadı. Lütfen tekrar dene.',
      detay: delError.message,
    }, 500);
  }

  return jsonResponse({ ...cikti, hesapSilindi: true });
});
