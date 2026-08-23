// Kelimeki — onaylanmamış hesapları hatırlatır, sonra siler.
//
// AKIŞ (ROADMAP #10):
//   0. saat  kayıt — Supabase onay maili gönderir, link 24 saat geçerli
//  ~20. saat TEK SEFERLİK hatırlatma: TAZE link + "24 saat içinde
//            tamamlamazsan hesabın silinecek"
//   48. saat hâlâ onaysızsa hesap SİLİNİR; e-posta ve takma ad serbest kalır
//
// İLKE: hatırlatma aralığı = linkin ömrü. Böylece kullanıcının kutusunda HER
// AN geçerli bir link bulunur (0-24 ilk mail, 24-48 hatırlatma). İlk taslak
// 3 gün/7 gündü ve 24-72. saatler arasında ÖLÜ BÖLGE bırakıyordu.
//
// ⚠ CRON SAATLİK OLMAK ZORUNDA. Günlük bir iş ölü bölgeyi geri getirir:
// 12:00'de kayıt olanı ertesi gün 11:00'de kontrol edersen henüz 23 saatliktir,
// atlanır ve hatırlatma 47. saatte gider — oysa ilk link 24. saatte ölmüştür.
// Hatırlatma ayrıca 24 saatlik ömrün BİTİMİNDEN ÖNCE (20. saat) atılır ki iki
// linkin geçerlilik aralığı üst üste binsin.
//
// ⚠ `Email OTP expiration` 86400 (24 saat) OLMAK ZORUNDA. 3600'e çekilirse bu
// şema sessizce işlevsiz kalır — hatırlatma maili neredeyse hep ölü link taşır.
// Supabase bunu `auth_otp_long_expiry` (WARN) olarak işaretliyor; uyarı
// BİLİNÇLİ olarak kabul edildi (bkz. ROADMAP #10).
//
// notify-deadline-warnings / notify-friend-request-reminders ile aynı desen:
// pg_cron + pg_net tetikler, verify_jwt KAPALI (cron çağırıyor, kullanıcı
// JWT'si yok), yalnızca kendi service-role client'ıyla çalışır.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { CORS_HEADERS, escapeHtml, sendBrevoEmail, buildBrandedEmailHtml } from '../_shared/email.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// Opsiyonel savunma-derinliği katmanı — notify-deadline-warnings'teki aynı
// gerekçe. Tanımlı değilse davranış değişmez.
const CRON_SECRET = Deno.env.get('CRON_SECRET');

const HATIRLATMA_ESIGI_MS = 20 * 60 * 60 * 1000;
const SILME_ESIGI_MS = 48 * 60 * 60 * 1000;

interface Damga {
  id: string;
  display_name: string | null;
  first_name: string | null;
  confirm_reminder_sent_at: string | null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function buildHtml(actionLink: string, recipientName?: string): string {
  const greeting = recipientName ? `Merhaba ${escapeHtml(recipientName)},` : 'Merhaba,';
  const body = `
    <p style="margin:0 0 16px 0;font-size:15px;line-height:1.6;color:#1B2430;">${greeting}</p>
    <p style="margin:0 0 24px 0;font-size:15px;line-height:1.6;color:#1B2430;">Kelimeki'ye kayıt oldun ama e-posta adresini henüz doğrulamadın. Aşağıdaki butona tıkladığında hesabın açılır ve doğrudan oyuna girersin.</p>
    <p style="margin:0 0 24px 0;">
      <a href="${escapeHtml(actionLink)}" style="display:inline-block;background-color:#2563EB;color:#FFFFFF;font-size:15px;font-weight:600;text-decoration:none;padding:12px 28px;border-radius:8px;">Hesabımı Tamamla</a>
    </p>
    <p style="margin:24px 0 0 0;padding-top:12px;border-top:1px solid #DCE2EA;font-size:13px;line-height:1.6;color:#8A93A2;">Bu bağlantı 24 saat geçerlidir. Hesabını 24 saat içinde tamamlamazsan kaydın silinir — dilediğin zaman aynı e-posta ve takma adla yeniden kayıt olabilirsin. Bu, gönderilecek son hatırlatmadır.</p>
  `;
  return buildBrandedEmailHtml('Hesabını tamamla', body);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  if (CRON_SECRET && req.headers.get('Authorization') !== `Bearer ${CRON_SECRET}`) {
    return jsonResponse({ error: 'Yetkisiz.' }, 401);
  }

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch { /* gövdesiz çağrı = gerçek mod */ }
  // PROVA MODU: hiçbir şey göndermez/silmez, yalnızca ne yapacağını raporlar.
  const dryRun = body.dryRun === true;

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // auth şeması PostgREST'e açık olmadığından kullanıcılar admin API ile
  // okunuyor. Bugün ~37 üye var; liste 1000'i aşarsa sayfalama gerekir —
  // rapora `sayfaSiniriAsildi` olarak yansıtılıyor, sessizce kırpılmıyor.
  const { data: liste, error: listeHata } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (listeHata) {
    console.error('[sweep-unconfirmed] listUsers hatası:', listeHata.message);
    return jsonResponse({ ok: true, reason: 'list_error' });
  }
  const tumu = liste?.users ?? [];
  const simdi = Date.now();

  // Onaysız VE hiç giriş yapmamış olanlar. İkinci koşul bir emniyet kemeri:
  // "Confirm email" bir dönem kapalıyken açılmış bir hesap onaysız görünüp
  // gerçekte kullanılıyor olabilir.
  const adaylar = tumu.filter((u) => !u.email_confirmed_at && !u.last_sign_in_at && !!u.email);

  const silinecek = adaylar.filter((u) => simdi - Date.parse(u.created_at) >= SILME_ESIGI_MS);
  const hatirlatilacakHam = adaylar.filter((u) => {
    const yas = simdi - Date.parse(u.created_at);
    return yas >= HATIRLATMA_ESIGI_MS && yas < SILME_ESIGI_MS;
  });

  // Damgası dolu olanları ele — hatırlatma ömür boyu TEK.
  const ilgiliIdler = [...hatirlatilacakHam, ...silinecek].map((u) => u.id);
  const { data: damgalar } = ilgiliIdler.length
    ? await supabase.from('profiles')
        .select('id, display_name, first_name, confirm_reminder_sent_at')
        .in('id', ilgiliIdler)
    : { data: [] as Damga[] };
  const damgaOf = new Map<string, Damga>(((damgalar ?? []) as Damga[]).map((p) => [p.id, p]));
  const hatirlatilacak = hatirlatilacakHam.filter((u) => !damgaOf.get(u.id)?.confirm_reminder_sent_at);

  // SİLME GUARD'I — YALNIZCA KİŞİNİN KENDİ ÜRETTİĞİ veri silmeyi engeller.
  //
  // ⚠ ÖLÇÜLDÜ (23 Ağustos 2026, ilk prova koşusu): "onaysız hesabın verisi
  // olamaz" varsayımı EKSİK. Kişi veri üretemez (her yazma yolu oturum ister)
  // ama BAŞKALARI ona işaret eden kayıt üretebilir — canlıda bir örneği çıktı:
  // hiç onaylamamış bir hesaba GELEN bekleyen arkadaşlık isteği vardı, çünkü
  // onaysız hesaplar arkadaş aramasında görünüyor.
  //
  // Bu tür kayıtlar silmeyi ENGELLEMEZ: satırla birlikte cascade olurlar ve
  // isteği gönderen kişi zaten hiç kaydolmamış birini beklemektedir. Engelleseydi
  // o hesabın takma adı sonsuza dek kilitli kalırdı — düzeltmeye çalıştığımız
  // sorunun ta kendisi. Yine de raporda GÖRÜNÜRLER, sessizce yok sayılmazlar.
  const silinecekIdler = silinecek.map((u) => u.id);
  const veriliIdler = new Set<string>();
  const gelenReferans = new Map<string, number>();
  if (silinecekIdler.length > 0) {
    for (const tablo of ['games', 'local_game_saves', 'friend_requests'] as const) {
      const { data } = await supabase.from(tablo).select('user_id').in('user_id', silinecekIdler);
      (data ?? []).forEach((r: { user_id: string }) => veriliIdler.add(r.user_id));
    }
    for (const [tablo, kolon] of [['friend_requests', 'friend_id'], ['game_invites', 'invitee_id']] as const) {
      const { data } = await supabase.from(tablo).select(kolon).in(kolon, silinecekIdler);
      (data ?? []).forEach((r: Record<string, string>) => {
        const id = r[kolon];
        gelenReferans.set(id, (gelenReferans.get(id) ?? 0) + 1);
      });
    }
  }

  const yasSaat = (u: { created_at: string }) => Math.round((simdi - Date.parse(u.created_at)) / 3600000);
  const rapor = {
    ok: true,
    dryRun,
    sayfaSiniriAsildi: tumu.length >= 1000,
    onaysizToplam: adaylar.length,
    hatirlatilacak: hatirlatilacak.map((u) => ({
      email: u.email, yasSaat: yasSaat(u), ad: damgaOf.get(u.id)?.display_name ?? null,
    })),
    silinecek: silinecek.filter((u) => !veriliIdler.has(u.id)).map((u) => ({
      email: u.email, yasSaat: yasSaat(u), ad: damgaOf.get(u.id)?.display_name ?? null,
      // Silinince cascade olacak, BAŞKALARININ ona işaret eden kayıtları.
      cascadeOlacakGelenKayit: gelenReferans.get(u.id) ?? 0,
    })),
    verisiOlduguIcinAtlanan: silinecek.filter((u) => veriliIdler.has(u.id)).map((u) => u.email),
    gonderildi: 0,
    silindi: 0,
    hatalar: [] as string[],
  };

  if (dryRun) return jsonResponse(rapor);

  // ── HATIRLATMA ────────────────────────────────────────────────────────────
  // `email_notifications_enabled` BİLEREK kontrol edilmiyor: bu bir tercihe
  // bağlı bildirim değil, hesabın yaşam döngüsü (uyarmadan silmek olmaz) —
  // notify-account-banned ile aynı sınıf. Zaten onaysız kullanıcı o tercihi
  // hiç değiştirememiş olur (oturum açamıyor).
  if (BREVO_API_KEY) {
    for (const u of hatirlatilacak) {
      // ATOMİK İDDİA: iki eşzamanlı koşu aynı kişiye iki mail atmasın.
      const { data: iddia } = await supabase.from('profiles')
        .update({ confirm_reminder_sent_at: new Date().toISOString() })
        .eq('id', u.id).is('confirm_reminder_sent_at', null).select('id');
      if (!iddia || iddia.length === 0) continue;

      try {
        // ⚠ `password` ZORUNLU bir parametre ama MEVCUT kullanıcının parolasını
        // EZMEZ — 23 Ağustos 2026'da üretimde ölçüldü: kullanıcının orijinal
        // parolası çalışmaya devam etti, buraya geçilen değer reddedildi.
        // Yalnızca kullanıcı henüz yoksa kullanılıyor.
        const { data: link, error: linkHata } = await supabase.auth.admin.generateLink({
          type: 'signup', email: u.email!, password: `Gecici-${crypto.randomUUID()}`,
        });
        const actionLink = link?.properties?.action_link;
        if (linkHata || !actionLink) throw new Error(linkHata?.message ?? 'action_link yok');

        const p = damgaOf.get(u.id);
        const ad = p?.display_name || p?.first_name || undefined;
        const res = await sendBrevoEmail(BREVO_API_KEY, {
          to: { email: u.email!, name: ad },
          subject: 'Kelimeki — Hesabını tamamla',
          htmlContent: buildHtml(actionLink, ad),
        });
        if (!res.ok) throw new Error(`Brevo ${res.status}`);
        rapor.gonderildi++;
      } catch (e) {
        // Gönderim başarısızsa damgayı GERİ AL ki bir sonraki saat tekrar
        // denensin — aksi halde kişi hiç uyarılmadan silinir.
        await supabase.from('profiles').update({ confirm_reminder_sent_at: null }).eq('id', u.id);
        rapor.hatalar.push(`hatirlatma ${u.email}: ${e instanceof Error ? e.message : String(e)}`);
      }
    }
  }

  // ── SİLME ─────────────────────────────────────────────────────────────────
  for (const u of silinecek) {
    if (veriliIdler.has(u.id)) continue;
    const { error } = await supabase.auth.admin.deleteUser(u.id);
    if (error) rapor.hatalar.push(`silme ${u.email}: ${error.message}`);
    else rapor.silindi++;
  }

  return jsonResponse(rapor);
});
