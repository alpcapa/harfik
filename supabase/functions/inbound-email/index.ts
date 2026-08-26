// Kelimeki — destek@kelimeki.com kutusuna gelen mailin HABERİNİ kaydeder.
//
// AKIŞ (25 Ağustos 2026 kararı, bkz. …_support_inbox.sql):
//   kullanıcı "Yanıtla" → destek@kelimeki.com (Zoho, mailin asıl yeri)
//     → Zoho kuralı bir KOPYASINI mail.kelimeki.com'daki Brevo Inbound
//       adresine yönlendirir
//         → Brevo Inbound Parsing bu fonksiyona POST eder
//           → `support_inbox`'a bir satır → admin panelindeki "Zoho" rozeti
//
// ⚠ BU BİR POSTA KUTUSU DEĞİL. Mail gövdesi BİLEREK saklanmıyor; yalnızca
// kimden/konu/tarih. Admin rozete tıklayıp Zoho'da okur. "Panelde de okuyalım"
// istenirse şema ve bu fonksiyon birlikte genişletilmeli — gövde eklemek tek
// başına yetmez, o zaman spam/ek dosya/boyut soruları da açılır (gerekçe:
// marketing/play-store/console-formlari.md → "Brevo zaten var, neden onunla
// almıyoruz?").
//
// GÜVENLİK: Brevo JWT taşımaz, bu yüzden `verify_jwt: false` deploy edilir —
// yani uç herkese açıktır. Tek kapı `?key=` sorgu parametresindeki paylaşılan
// sır (Supabase → Edge Functions → Secrets → INBOUND_EMAIL_SECRET). Sır
// tanımlı değilse fonksiyon KAPALI kalır (503): yapılandırılmamış bir uç,
// panele sahte "cevap geldi" satırı POST edilebilen açık bir uçtan iyidir.
import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const INBOUND_EMAIL_SECRET = Deno.env.get('INBOUND_EMAIL_SECRET');

/** Kendi adreslerimizden gelen kopyalar döngü yaratmasın (Zoho'nun Sent
 *  kopyası, Brevo'nun kendi gönderimi, bounce servisleri). */
const OWN_ADDRESSES = ['destek@kelimeki.com', 'noreply@kelimeki.com'];

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** Sabit zamanlı olmayan ama uzunluk-güvenli karşılaştırma — sır 32+ karakter
 *  rastgele olduğundan zamanlama saldırısı pratik bir tehdit değil; yine de
 *  erken çıkışı engellemek için tüm baytlar dolaşılıyor. */
function secretMatches(given: string | null, expected: string): boolean {
  if (!given || given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

/**
 * `SentAtDate` ayrıştırılamazsa ŞİMDİ'ye düşer.
 *
 * ⚠ `new Date('saçma').toISOString()` **RangeError fırlatır** — ham hâliyle
 * bırakılırsa tek bir bozuk tarih tüm isteği 500'e çevirir ve Brevo aynı
 * bozuk gövdeyi sonsuza kadar yeniden dener. Bu, dosyanın kendi kuralının
 * tersi olurdu: ayrıştırılamayan JSON'a bilerek 200 dönüyoruz, tam da
 * düzelmesi mümkün olmayan bir döngü doğmasın diye. Tarih zaten yalnızca
 * sıralama içindir; haberi kaybetmektense saati kaydırmak yeğdir.
 */
function parseReceivedAt(raw?: string): string {
  if (raw) {
    const t = new Date(raw);
    if (!Number.isNaN(t.getTime())) return t.toISOString();
    console.error('[inbound-email] SentAtDate ayrıştırılamadı, şimdi kullanılıyor:', raw);
  }
  return new Date().toISOString();
}

type BrevoAddress = { Name?: string; Address?: string };
type BrevoItem = {
  MessageId?: string;
  Subject?: string;
  From?: BrevoAddress;
  To?: BrevoAddress[];
  SentAtDate?: string;
  Headers?: Record<string, unknown>;
};

/** Otomatik yanıtlar (tatil mesajı, bounce) admin'e "cevap geldi" diye
 *  gösterilmemeli — rozet "bekleyen İŞ" demek (bkz. CLAUDE.md → CountBadge). */
function isAutoReply(item: BrevoItem): boolean {
  const headers = item.Headers ?? {};
  const get = (k: string): string => {
    const hit = Object.entries(headers).find(([hk]) => hk.toLowerCase() === k);
    return hit ? String(hit[1] ?? '').toLowerCase() : '';
  };
  const autoSubmitted = get('auto-submitted');
  if (autoSubmitted && autoSubmitted !== 'no') return true;
  if (get('x-autoreply') || get('x-autorespond')) return true;
  const precedence = get('precedence');
  return precedence === 'bulk' || precedence === 'auto_reply' || precedence === 'junk';
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  if (!INBOUND_EMAIL_SECRET) {
    console.error('[inbound-email] INBOUND_EMAIL_SECRET tanımlı değil — uç kapalı.');
    return json({ error: 'Not configured.' }, 503);
  }
  if (!secretMatches(new URL(req.url).searchParams.get('key'), INBOUND_EMAIL_SECRET)) {
    return json({ error: 'Unauthorized.' }, 401);
  }

  let payload: { items?: BrevoItem[] };
  try {
    payload = await req.json();
  } catch {
    // Ayrıştırılamayan gövde için 200: 4xx/5xx dönersek Brevo aynı bozuk
    // isteği tekrar tekrar dener, düzelmesi mümkün olmayan bir döngü olur.
    console.error('[inbound-email] Gövde JSON değil.');
    return json({ ok: true, ignored: 'invalid-json' });
  }

  const items = Array.isArray(payload.items) ? payload.items : [];
  if (items.length === 0) return json({ ok: true, ignored: 'empty' });

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const rows: Record<string, unknown>[] = [];
  let skipped = 0;
  for (const item of items) {
    const fromEmail = item.From?.Address?.trim().toLowerCase() ?? null;
    if (fromEmail && OWN_ADDRESSES.includes(fromEmail)) {
      skipped++;
      continue;
    }
    if (isAutoReply(item)) {
      skipped++;
      continue;
    }
    rows.push({
      from_email: fromEmail,
      from_name: item.From?.Name?.trim() || null,
      subject: item.Subject?.trim().slice(0, 300) || null,
      // Message-ID yoksa satır yine yazılsın (null unique kısıtını ihlal
      // etmez) — haber vermek, tekilliği garantilemekten önemli.
      message_id: item.MessageId?.trim() || null,
      received_at: parseReceivedAt(item.SentAtDate),
    });
  }

  if (rows.length === 0) return json({ ok: true, skipped });

  // Aynı mail iki kez POST edilirse (Brevo yeniden dener) message_id unique
  // kısıtı ikinci satırı engeller — ignoreDuplicates ile bu bir hata değil,
  // sessiz bir no-op olsun.
  const { error } = await supabase
    .from('support_inbox')
    .upsert(rows, { onConflict: 'message_id', ignoreDuplicates: true });

  if (error) {
    // Burada 500 DOĞRU: yazma hatası geçici olabilir, Brevo'nun yeniden
    // denemesini İSTİYORUZ (yukarıdaki JSON hatasının tersine).
    console.error('[inbound-email] support_inbox yazma hatası:', error.message);
    return json({ error: 'Kaydedilemedi.' }, 500);
  }

  return json({ ok: true, inserted: rows.length, skipped });
});
