// Kelimeki — FCM (Firebase Cloud Messaging) HTTP v1 göndericisi.
//
// ⚠ TEK KURAL, HER ŞEYDEN ÖNCE: **push, E-POSTA YOLUNU ASLA DÜŞÜREMEZ.**
// Bu modülü çağıran fonksiyonlar (bugün `notify-deadline-warnings`) CANLI
// kullanıcı yollarında: teslim uyarısı gitmezse insanlar k-lig puanı
// kaybediyor. Bu yüzden burada dışarı fırlayan HİÇBİR yol yok — her genel
// fonksiyon kendi hatasını yutup `false`/boş döndürür ve `console.error`a
// yazar. Çağıran taraf da push'u e-postadan SONRA ve ayrı bir `try/catch`
// içinde çağırmalı.
//
// ── NEDEN FCM, NEDEN DOĞRUDAN APNs DEĞİL (karar: 26 Ağustos 2026) ─────────
//   FCM iOS'a da teslim ediyor (arka planda APNs'i kendisi kullanıyor). Sunucu
//   FCM üzerinden yazılırsa iOS günü gelince yapılacak iş "ikinci bir gönderici
//   yazmak" DEĞİL, yalnızca APNs anahtarını Firebase'e yüklemek + uygulamaya
//   Push capability eklemek olur. APNs'e doğrudan konuşan bir yol seçilseydi
//   bu kazanç kaybolurdu.
//
// ── KİMLİK: servis hesabı → imzalı JWT → OAuth2 erişim jetonu ─────────────
//   FCM v1, eski "server key" başlığını KABUL ETMİYOR; OAuth2 bearer istiyor.
//   Akış: servis hesabının özel anahtarıyla RS256 imzalı bir JWT üret →
//   oauth2.googleapis.com'dan erişim jetonuna takas et → jetonla gönder.
//   Jeton 1 saat geçerli ve ISOLATE ÖMRÜ boyunca önbelleklenir (aşağı bkz.).
//
// ── SECRET ────────────────────────────────────────────────────────────────
//   `FCM_SERVICE_ACCOUNT` — Firebase Console → Proje ayarları → Servis
//   hesapları → "Yeni özel anahtar oluştur" JSON'unun TAMAMI, tek değer
//   olarak. Dashboard → Edge Functions → Secrets'tan girilir, REPODA DURMAZ.
//   Tanımlı DEĞİLSE bu modül sessizce no-op olur (`BREVO_API_KEY`in aynı
//   deseni): push kanalı kapalı kalır, e-posta kanalı etkilenmez.

/** `createClient(...)` sonucu — yalnızca tip için (çalışma anında silinir). */
import type { createClient } from 'jsr:@supabase/supabase-js@2';
type PushDb = ReturnType<typeof createClient>;

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/** Gönderim sonucu — çağıran bayat token'ı SİLEBİLSİN diye ayrıştırılmış. */
export interface PushResult {
  ok: boolean;
  /** Token artık geçersiz (uygulama silinmiş / token dönmüş) → satırı sil. */
  unregistered: boolean;
}

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

function readServiceAccount(): ServiceAccount | null {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!raw) return null;
  try {
    const sa = JSON.parse(raw) as Partial<ServiceAccount>;
    if (!sa.project_id || !sa.client_email || !sa.private_key) {
      console.error('[push] FCM_SERVICE_ACCOUNT eksik alan taşıyor.');
      return null;
    }
    return sa as ServiceAccount;
  } catch (err) {
    console.error('[push] FCM_SERVICE_ACCOUNT ayrıştırılamadı:', err);
    return null;
  }
}

/** Push kanalı yapılandırılmış mı — çağıran boş yere sorgu atmasın diye. */
export function pushConfigured(): boolean {
  return readServiceAccount() !== null;
}

/**
 * FCM yanıtı "bu token ARTIK GEÇERSİZ" mi diyor — yani satır silinmeli mi?
 *
 * SAF ve dışa açık, çünkü bu projedeki en pahalı yanlış karar burada
 * verilebilir: yanlış `true` GEÇERLİ bir cihazın token'ını siler (o kullanıcı
 * bir daha hiç bildirim almaz ve kimse fark etmez); yanlış `false` ölü bir
 * token'ı sonsuza kadar tutar ve her turda boşuna kota yakar. Testi
 * `push_test.ts`te.
 *
 * FCM bayat token'ı İKİ ayrı biçimde bildiriyor ve ikisi de KALICI:
 *   404 + UNREGISTERED      → uygulama silinmiş / token dönmüş
 *   400 + INVALID_ARGUMENT  → token biçimi artık geçersiz
 * Geri kalan her şey (401/403 kimlik, 429 kota, 5xx sunucu) GEÇİCİ sayılır —
 * o durumda token'a DOKUNULMAZ, yoksa bir kota hatası tüm cihazları silerdi.
 */
export function isUnregistered(status: number, body: string): boolean {
  if (status === 404) return body.includes('UNREGISTERED');
  if (status === 400) return body.includes('INVALID_ARGUMENT');
  return false;
}

function b64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * PEM (PKCS#8) özel anahtarı Web Crypto'nun anlayacağı CryptoKey'e çevirir.
 *
 * ⚠ `private_key` JSON'da `\n` KAÇIŞLARIYLA saklanır. Secret'a yapıştırılırken
 * JSON.parse bunları gerçek satır sonuna çevirdiği için burada ek bir işlem
 * gerekmiyor — ama PEM başlık/dipnot satırları ve TÜM boşluklar atılmalı,
 * yoksa base64 çözümü patlar.
 */
export async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

// Erişim jetonu önbelleği — ISOLATE ÖMRÜ boyunca. Edge Function isolate'i
// çağrılar arasında sıcak kalabildiğinden, her satır için yeniden token
// almak hem yavaş hem gereksiz. 60 sn'lik güvenlik payı: jeton tam da
// kullanılırken dolmasın.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(sa: ServiceAccount): Promise<string | null> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  try {
    const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
    const claim = b64url(new TextEncoder().encode(JSON.stringify({
      iss: sa.client_email,
      scope: FCM_SCOPE,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    })));
    const signingInput = `${header}.${claim}`;
    const key = await importPrivateKey(sa.private_key);
    const sig = new Uint8Array(await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      key,
      new TextEncoder().encode(signingInput),
    ));
    const jwt = `${signingInput}.${b64url(sig)}`;

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });
    if (!res.ok) {
      console.error('[push] OAuth2 jetonu alınamadı:', res.status, await res.text());
      return null;
    }
    const json = await res.json() as { access_token?: string; expires_in?: number };
    if (!json.access_token) {
      console.error('[push] OAuth2 yanıtında access_token yok.');
      return null;
    }
    cachedToken = {
      value: json.access_token,
      expiresAt: now + (json.expires_in ?? 3600),
    };
    return cachedToken.value;
  } catch (err) {
    console.error('[push] jeton üretilemedi:', err);
    return null;
  }
}

/**
 * Bir kullanıcının TÜM cihazlarına bildirim gönderir.
 *
 * ⚠ **HİÇBİR KOŞULDA FIRLATMAZ.** Çağrıldığı yerler canlı e-posta yolları;
 * push bir EK kanal ve arızası e-postayı düşüremez. Bu yüzden gövdenin
 * tamamı tek bir try/catch içinde ve çağıranlar bunu e-postadan SONRA
 * çağırmalı.
 *
 * ⚠ **`email_notifications_enabled`den BAĞIMSIZ** — bu fonksiyon yalnızca
 * `push_notifications_enabled`e bakar. Çağıran taraf da öyle davranmalı:
 * e-posta tercihi kapalı diye `continue`/`return` edip buraya hiç
 * gelmemek, iki tercihi tek tercihe indirger.
 *
 * **30 Ağustos 2026 — tam bu hata canlıda bulundu.**
 * `notify-deadline-warnings` (o gün push taşıyan TEK fonksiyon) e-posta
 * tercihi kapalı olan alıcıda `continue` ediyordu ve push satırına hiç
 * ulaşmıyordu; yani "e-postayı kapat, push açık kalsın" diyen kullanıcı
 * hiçbir şey almıyordu. Dosyanın kendi yorumu bağımsızlığı vaat ediyordu,
 * kodu tutmuyordu.
 *
 * Bayat token'lar (FCM `UNREGISTERED`/`INVALID_ARGUMENT`) burada SİLİNİR —
 * karar `isUnregistered`'da ve testi var (`_shared/push_test.ts`).
 *
 * @returns kaç cihaza gönderildiği (teşhis için; hata durumunda 0)
 */
export async function sendPushToUser(
  db: PushDb,
  userId: string,
  msg: { title: string; body: string; link?: string },
): Promise<number> {
  try {
    if (!pushConfigured()) return 0;

    // Tercih KAPALIYSA hiç sorgulamaya girme.
    const { data: prof } = await db
      .from('profiles')
      .select('push_notifications_enabled')
      .eq('id', userId)
      .maybeSingle();
    if (prof?.push_notifications_enabled === false) return 0;

    const { data: tokens } = await db
      .from('push_tokens')
      .select('token')
      .eq('user_id', userId);
    if (!tokens || tokens.length === 0) return 0;

    let gonderilen = 0;
    const bayat: string[] = [];
    for (const row of tokens as { token: string }[]) {
      const res = await sendPush({ token: row.token, ...msg });
      if (res.ok) gonderilen += 1;
      if (res.unregistered) bayat.push(row.token);
    }
    if (bayat.length > 0) {
      await db.from('push_tokens').delete().in('token', bayat);
    }
    return gonderilen;
  } catch (err) {
    console.error('[push] kullanıcıya gönderilemedi:', userId, err);
    return 0;
  }
}

/**
 * Tek bir cihaza bildirim gönderir.
 *
 * `data.link` — bildirime dokununca açılacak derin bağlantı
 * (`kelimeki://oyun/<id>`). Biçim `util/deep_link.dart`'taki
 * `buildOnlineGameLink` ile ELLE senkron; orada tanınmayan bir biçim
 * gönderilirse uygulama linki sessizce yok sayar.
 */
export async function sendPush(params: {
  token: string;
  title: string;
  body: string;
  link?: string;
}): Promise<PushResult> {
  const sa = readServiceAccount();
  if (!sa) return { ok: false, unregistered: false };

  const accessToken = await getAccessToken(sa);
  if (!accessToken) return { ok: false, unregistered: false };

  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: params.token,
            notification: { title: params.title, body: params.body },
            // `data` yükü uygulamanın dokunma yönlendirmesi için; FCM tüm
            // değerleri STRING istiyor.
            ...(params.link ? { data: { link: params.link } } : {}),
            android: {
              priority: 'high',
              notification: {
                // Android 8+ kanal kimliği — uygulama tarafındaki kanalla
                // AYNI olmalı, yoksa bildirim varsayılan kanala düşer ve
                // kullanıcının kanal ayarları işlemez.
                channel_id: 'kelimeki_oyun',
              },
            },
          },
        }),
      },
    );

    if (res.ok) return { ok: true, unregistered: false };

    const text = await res.text();
    const unregistered = isUnregistered(res.status, text);
    // Bayat token bir ARIZA değil, beklenen bir yaşam döngüsü olayı — onu
    // `console.error`a yazmak gerçek hataları gürültüye boğar.
    if (!unregistered) console.error('[push] FCM hatası:', res.status, text);
    return { ok: false, unregistered };
  } catch (err) {
    console.error('[push] gönderim hatası:', err);
    return { ok: false, unregistered: false };
  }
}
