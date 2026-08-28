// GEÇİCİ TEŞHİS — FCM kimlik zincirinin (servis hesabı → RS256 JWT → OAuth2
// jetonu → FCM) gerçekten çalışıp çalışmadığını, gerçek bir cihaz token'ı
// beklemeden ölçer (28 Ağustos 2026, ROADMAP madde 13).
//
// NEDEN VAR: push altyapısının sunucu yarısı, istemci yarısından ÖNCE
// yazıldı. Kimlik zinciri kırıksa (anahtar iptal, Cloud Messaging API kapalı,
// yanlış proje) bunu ancak Flutter istemcisi bitip gerçek bir bildirim
// beklenirken öğrenirdik — yani bir tam tur sonra. Bu fonksiyon o bilgiyi
// ŞİMDİ veriyor.
//
// NASIL ÇALIŞIR: bilerek GEÇERSİZ bir token'a gönderim dener.
//   kimlikZinciriSaglam=true  → Google kimliğimizi KABUL ETTİ, yalnızca
//                               token'ı reddetti (INVALID_ARGUMENT).
//   false                     → zincir KIRIK (401/403) ya da ağ. Ayrıntı
//                               fonksiyon log'unda.
//
// SIR SIZDIRMAZ: yalnızca iki boolean döner, hiçbir anahtar/jeton yazmaz.
// Bu yüzden `verify_jwt: false` zararsız — dışarıdan çağıran biri en fazla
// "kimlik bilgileri çalışıyor" bilgisini öğrenir.
//
// ⚠ SİLİNEBİLİR. İşi bitti sayılırsa Supabase Dashboard → Edge Functions →
// push-selftest → Delete. Bırakılırsa da bir maliyeti yok: cron'u yok,
// kimse çağırmıyor, yalnızca elle tetiklendiğinde çalışır.
//
// ⚠ YENİDEN DEPLOY EDİLİRSE kardeş dosya olarak KANONİK
// `supabase/functions/_shared/push.ts` yüklenmeli — ilk deploy'da yorumları
// kısaltılmış bir kopya gönderildi, davranış aynı ama metin aynı değil.
import { pushConfigured, sendPush } from '../_shared/push.ts';

Deno.serve(async () => {
  const yapilandirildi = pushConfigured();
  const sonuc = yapilandirildi
    ? await sendPush({
      token: 'GECERSIZ-TEST-TOKENI-kelimeki-selftest',
      title: 'test',
      body: 'test',
    })
    : null;
  return new Response(
    JSON.stringify({
      yapilandirildi,
      kimlikZinciriSaglam: sonuc?.unregistered === true,
      ham: sonuc,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});
