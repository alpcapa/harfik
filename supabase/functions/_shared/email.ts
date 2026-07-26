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
    <p style="margin-top: 20px; padding-top: 12px; border-top: 1px solid #eee; font-size: 11px; color: #999; font-style: italic;">
      Bu e-posta noreply adresinden gönderilmiştir. Cevap vermek için <a href="${url}" style="color: #2f6fed; text-decoration: underline;">tıklayın</a>.
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
