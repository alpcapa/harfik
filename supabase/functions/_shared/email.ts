// Kelimeki — admin panelinden gönderilen e-postalar için ortak yardımcılar
// (feedback-reply ve admin-send-message arasında paylaşılır). Her iki
// fonksiyon da tek yönlü noreply@ adresinden gönderdiğinden, alıcının
// cevap yazması gerektiğinde nereye tıklaması gerektiğini gösteren aynı
// notu paylaşırlar.
export const KELIMEKI_SENDER = { name: 'Kelimeki', email: 'noreply@kelimeki.com' };

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

// Supabase Auth mailleri (supabase/email-templates/*.html — reset-password,
// confirm-signup, change-email) ile aynı kart/logo görünümü. Auth şablonları
// Dashboard'da yaşadığından bu HTML'i otomatik paylaşamıyorlar — bu yüzden
// aynı yapı (logo + beyaz kart + footer) burada elle tekrarlanıyor; ikisi
// görsel olarak birbirinden sapmasın diye reset-password.html değişirse bu
// wrapper da elle senkronize edilmeli.
export function buildBrandedEmailHtml(title: string, bodyHtml: string): string {
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

// kelimeki.com'daki ?contact=1 parametresini App.tsx okuyup genel "Görüş
// Bildir" formunu (source: 'general') otomatik açar — bkz. App.tsx'teki
// showContactFeedback effect'i. threadId verilirse ?re=<id> olarak eklenir;
// App.tsx bunu okuyup yeni gönderilen mesajı feedback.related_to ile bu
// mesaja bağlar (tam bir e-posta thread'i değil ama en azından admin
// panelinde "bu, şu mesaja cevaben geldi" bağlantısını kurar).
export function buildNoreplyNoticeHtml(threadId?: string): string {
  const url = threadId
    ? `https://kelimeki.com/?contact=1&re=${encodeURIComponent(threadId)}`
    : 'https://kelimeki.com/?contact=1';
  return `
    <p style="margin: 24px 0 0 0; padding-top: 12px; border-top: 1px solid #DCE2EA; font-size: 12px; color: #8A93A2; font-style: italic;">
      Bu e-posta noreply adresinden gönderilmiştir. Cevap vermek için <a href="${url}" style="color: #2563EB; text-decoration: underline;">tıklayın</a>.
    </p>
  `;
}

export async function sendBrevoEmail(
  apiKey: string,
  params: { to: { email: string; name?: string }; subject: string; htmlContent: string },
): Promise<Response> {
  return fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': apiKey,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sender: KELIMEKI_SENDER,
      to: [params.to],
      subject: params.subject,
      htmlContent: params.htmlContent,
    }),
  });
}
