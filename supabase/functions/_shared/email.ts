// Kelimeki — Edge Function'ların gönderdiği e-postalar için ortak yardımcılar.
//
// İKİ GÖNDEREN VAR VE AYRIM BİLİNÇLİ (25 Ağustos 2026, kullanıcı kararı:
// "noreply demek cevaplanamaz demek; hiçbir uygulama noreply'a cevap kabul
// etmez, biz de etmemeliyiz"):
//
//   KELIMEKI_SENDER          → noreply@kelimeki.com — TRANSACTIONAL/sistemsel
//     bildirimler (sıra sende, davet, hesap durumu, hoş geldin…). Bu adres
//     GERÇEKTEN cevaplanamaz: Zoho'da `noreply@` diye bir kutu/grup yok, oraya
//     yazılan mail geri döner. Bu yüzden bu maillerin altına
//     `buildNoReplyNoticeHtml()` ile "bu adres yanıtlanamaz, bize destek@'ten
//     ulaş" notu konur — kullanıcı bounce yemeden nereye yazacağını görsün.
//
//   KELIMEKI_SUPPORT_SENDER  → destek@kelimeki.com — İNSANIN YAZDIĞI mailler
//     (feedback-reply: görüş bildirime admin yanıtı; admin-send-message:
//     admin'in bir üyeye doğrudan mesajı). Bu adres GERÇEK bir Zoho posta
//     kutusu, "Yanıtla" çalışır ve cevap oraya düşer.
//
// ⚠ Yeni bir Edge Function mail gönderiyorsa bu ikisinden birini SEÇMEK
// zorunda: bir insan cevap bekliyor mu (destek@) yoksa makine mi konuşuyor
// (noreply@)? Varsayılan yok, bilerek — üçüncü bir adres uydurma.
export const SUPPORT_EMAIL = 'destek@kelimeki.com';

export const KELIMEKI_SENDER = { name: 'Kelimeki', email: 'noreply@kelimeki.com' };
export const KELIMEKI_SUPPORT_SENDER = { name: 'Kelimeki Destek', email: SUPPORT_EMAIL };

// Tarayıcı, Authorization + Content-Type: application/json header'ları içeren
// bir isteği "basit istek" saymadığından önce bir OPTIONS preflight'ı gönderir;
// bu header'lar olmadan preflight 403/405 döner ve supabase-js bunu asıl
// isteği hiç göndermeden "Failed to send a request to the Edge Function"
// (fetch-level hata) olarak fırlatır. Her iki fonksiyon da hem OPTIONS'a hem
// gerçek yanıtlara bu header'ları eklemeli.
export const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Kullanıcı-kontrollü bir ismi (display_name/first_name) e-posta KONU
// satırına gömmeden önce güvenli hale getirir. Konu satırları gövdenin
// aksine escapeHtml'e tabi değildi — biri kendi adını uzun/keyfi bir
// metne (ör. "ÜCRETSİZ KAZANDIN TIKLA") çevirip gerçek noreply@kelimeki.com
// adresinden gelen bir e-postanın konu satırında bunu gösterebiliyordu
// (marka güvenilirliğini istismar eden bir sosyal mühendislik/phishing
// vektörü). Satır sonu/kontrol karakterleri temizlenip makul bir uzunlukta
// kırpılır — isim seçimini engellemez, yalnızca konu satırının kısa/tek
// satırlık kalmasını garanti eder.
export function sanitizeForSubject(name: string, maxLen = 40): string {
  // Regex kaçış dizileri yerine bilinçli olarak kod noktası karşılaştırması
  // kullanılıyor — kontrol karakterlerini (satır sonu dahil, kod noktası 32'den
  // küçük olan her şey + DEL/127) boşluğa çevirip ardışık boşlukları teke indiriyor.
  const withoutControlChars = Array.from(name)
    .map((ch) => {
      const code = ch.codePointAt(0) ?? 0;
      return code < 32 || code === 127 ? ' ' : ch;
    })
    .join('');
  const cleaned = withoutControlChars.split(/\s+/).filter(Boolean).join(' ').trim();
  if (!cleaned) return 'Bir kullanıcı';
  if (cleaned.length <= maxLen) return cleaned;
  return `${cleaned.slice(0, maxLen - 1).trimEnd()}...`;
}

// Supabase Auth mailleri (supabase/email-templates/*.html — reset-password,
// confirm-signup, change-email) ile aynı kart/logo görünümü. Auth şablonları
// Dashboard'da yaşadığından bu HTML'i otomatik paylaşamıyorlar — bu yüzden
// aynı yapı (logo + beyaz kart + footer) burada elle tekrarlanıyor; ikisi
// görsel olarak birbirinden sapmasın diye reset-password.html değişirse bu
// wrapper da elle senkronize edilmeli.
export function buildBrandedEmailHtml(
  title: string,
  bodyHtml: string,
  footerNoticeHtml = '',
): string {
  return `
<body style="margin:0;padding:0;background-color:#F5F7FA;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F5F7FA;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px;width:100%;background-color:#FFFFFF;border:1px solid #DCE2EA;border-radius:16px;overflow:hidden;">
          <tr>
            <td align="center" style="padding:32px 32px 8px 32px;">
              <img src="https://kelimeki.com/email-logo.png" width="140" height="56" alt="Kelimeki" style="display:block;border:0;outline:none;text-decoration:none;color:#2563EB;font-size:22px;font-weight:700;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
            </td>
          </tr>
          <tr>
            <td style="padding:16px 32px 32px 32px;">
              <h1 style="margin:0 0 16px 0;font-size:20px;line-height:1.4;color:#1B2430;">${escapeHtml(title)}</h1>
              ${bodyHtml}
              ${footerNoticeHtml}
            </td>
          </tr>
        </table>
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px;width:100%;">
          <tr>
            <td align="center" style="padding:20px 32px;">
              <span style="font-size:12px;color:#8A93A2;">© Kelimeki · kelimeki.com</span>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
  `;
}

// Ortak not kutusu — iki notice de aynı görünsün diye tek yerden.
function noticeShell(inner: string): string {
  return `
    <p style="margin: 24px 0 0 0; padding-top: 12px; border-top: 1px solid #DCE2EA; font-size: 12px; color: #8A93A2; font-style: italic;">
      ${inner}
    </p>
  `;
}

// TRANSACTIONAL (noreply@) mailler için. Bu adrese yazılan mail GERİ DÖNER —
// kullanıcıyı bounce'a göndermemek için gidilecek adres burada açıkça yazılı.
export function buildNoReplyNoticeHtml(): string {
  return noticeShell(
    `Bu otomatik bir bildirimdir; bu adrese gönderilen yanıtlar okunmaz. Bize ulaşmak için ` +
      `<a href="mailto:${SUPPORT_EMAIL}" style="color: #2563EB; text-decoration: underline;">${SUPPORT_EMAIL}</a> ` +
      `adresine yazabilirsin.`,
  );
}

// DESTEK (destek@) mailleri için. Artık "cevap veremezsin, tıkla" demiyor —
// adres gerçek bir kutu, doğrudan yanıtlamak ÇALIŞIYOR. Sitedeki form yine de
// ikinci bir yol olarak duruyor: kelimeki.com'daki ?contact=1 parametresini
// App.tsx okuyup genel "Görüş Bildir" formunu (source: 'general') otomatik
// açar; threadId verilirse ?re=<id> olarak eklenir ve gönderilen mesaj
// feedback.related_to ile bu mesaja bağlanır (admin panelinde "↳ Cevaben").
//
// ⚠ İki yolun VARDIĞI YER FARKLI ve bu bilinçli: doğrudan yanıt Zoho
// kutusuna düşer (admin panelinde okunmaz, yalnızca "Zoho" rozetini artırır),
// sitedeki form ise doğrudan admin paneline düşer.
export function buildSupportReplyNoticeHtml(threadId?: string): string {
  const url = threadId
    ? `https://kelimeki.com/?contact=1&re=${encodeURIComponent(threadId)}`
    : 'https://kelimeki.com/?contact=1';
  return noticeShell(
    `Bu e-postayı doğrudan yanıtlayabilirsin — cevabın ${SUPPORT_EMAIL} adresine ulaşır. ` +
      `Dilersen <a href="${url}" style="color: #2563EB; text-decoration: underline;">siteden de yazabilirsin</a>.`,
  );
}

/**
 * Brevo hatasını admin'in ANLAYACAĞI bir cümleye çevirir.
 *
 * Özel olarak ele alınan tek durum: `destek@kelimeki.com` Brevo'da gönderen
 * olarak doğrulanmamışsa API 400 döner. Bu, kurulum sırasında beklenen ve
 * yalnızca admin'in düzeltebileceği bir durum — genel "E-posta gönderilemedi"
 * mesajı admin'i Brevo paneline yönlendirmez, saatlerce koda baktırır.
 */
export function brevoErrorMessage(status: number, detail: string): string {
  const lower = detail.toLowerCase();
  if (status === 400 && (lower.includes('sender') || lower.includes('from'))) {
    return `E-posta gönderilemedi: ${SUPPORT_EMAIL} Brevo'da doğrulanmış gönderen değil. ` +
      `Brevo → Settings → Senders'a bu adresi ekleyip doğrula, sonra tekrar dene.`;
  }
  return 'E-posta gönderilemedi.';
}

/**
 * Brevo Transactional API çağrısı.
 *
 * `sender` verilmezse noreply@ kullanılır — yani bir fonksiyon hiçbir şey
 * yapmazsa TRANSACTIONAL sayılır. İnsanın yazdığı mailler `sender`ı
 * KELIMEKI_SUPPORT_SENDER olarak açıkça geçmek zorunda.
 *
 * `replyTo` ayrıca veriliyor çünkü bazı istemciler "Yanıtla"da From yerine
 * Reply-To'ya bakar; destek maillerinde ikisinin de destek@'i göstermesi
 * gerekiyor.
 */
export async function sendBrevoEmail(
  apiKey: string,
  params: {
    to: { email: string; name?: string };
    subject: string;
    htmlContent: string;
    sender?: { name: string; email: string };
    replyTo?: { name?: string; email: string };
  },
): Promise<Response> {
  return fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': apiKey,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sender: params.sender ?? KELIMEKI_SENDER,
      to: [params.to],
      ...(params.replyTo ? { replyTo: params.replyTo } : {}),
      subject: params.subject,
      htmlContent: params.htmlContent,
    }),
  });
}
