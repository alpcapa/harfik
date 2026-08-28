// `_shared/push.ts` — saf mantığın testleri.
//
// KOŞMA: `deno test supabase/functions/_shared/push_test.ts`
// CI'da KOŞMUYOR (CI'da Deno yok) — Flutter SDK'sıyla aynı model: araç bu
// ortama indirilebiliyor ve bir değişikliği göndermeden ÖNCE koşulur.
//
// Ağ YOK, gerçek kimlik bilgisi YOK: birincisi saf bir sınıflandırıcı,
// ikincisi kendi ürettiği anahtar çiftiyle imza gidiş-dönüşü yapıyor.
// ⚠ DIŞ BAĞIMLILIK YOK ve bu bilinçli: `jsr:@std/assert` bu ortamdan
// çekilemiyor (proxy 403) ve `kelimeki_core` testleri de aynı gerekçeyle
// `package:test` yerine düz bir betik kullanıyor. İki satırlık iddia
// yardımcısı, bir bağımlılığın koşulamamasından iyidir.
import { importPrivateKey, isUnregistered } from './push.ts';

function assert(kosul: boolean, mesaj = 'iddia tutmadı'): void {
  if (!kosul) throw new Error(mesaj);
}
function assertEquals<T>(gercek: T, beklenen: T, mesaj?: string): void {
  if (gercek !== beklenen) {
    throw new Error(mesaj ?? `beklenen ${beklenen}, gelen ${gercek}`);
  }
}

Deno.test('isUnregistered — KALICI iki biçim token silmeyi tetikler', () => {
  assert(isUnregistered(404, '{"error":{"status":"UNREGISTERED"}}'));
  assert(isUnregistered(400, '{"error":{"status":"INVALID_ARGUMENT"}}'));
});

Deno.test('isUnregistered — GEÇİCİ hatalar token\'a DOKUNMAZ', () => {
  // Bu testin asıl konusu şu: bir kota ya da kimlik hatası "bayat token"
  // sayılsaydı TEK bir 429, kullanıcıların TÜM cihazlarını silerdi ve bunu
  // kimse fark etmezdi (kimse "bildirim gelmiyor" diye şikayet etmez).
  assertEquals(isUnregistered(401, 'invalid authentication credentials'), false);
  assertEquals(isUnregistered(403, 'SenderId mismatch'), false);
  assertEquals(isUnregistered(429, 'QUOTA_EXCEEDED'), false);
  assertEquals(isUnregistered(500, 'INTERNAL'), false);
  assertEquals(isUnregistered(503, 'UNAVAILABLE'), false);
  // Durum kodu doğru ama gövde başka bir şey diyorsa da silme: 400 çok genel
  // bir koddur ve yükün başka bir alanı da hatalı olabilir.
  assertEquals(isUnregistered(400, 'Invalid JSON payload received'), false);
  assertEquals(isUnregistered(404, 'Requested entity was not found'), false);
});

Deno.test('importPrivateKey — PEM ayrıştırma + RS256 imza gidiş-dönüşü',
  async () => {
    // Gerçek servis hesabı anahtarı gerekmiyor: aynı algoritmayla bir çift
    // üretip, kendi PEM sarmalayıcımızdan geçirip imzalıyoruz ve AÇIK
    // anahtarla doğruluyoruz. Bu, jetonun Google'a gitmeden önce doğru
    // imzalandığını kanıtlar — aksi halde hata ancak canlıda, 401 olarak
    // görünürdü.
    const pair = await crypto.subtle.generateKey(
      {
        name: 'RSASSA-PKCS1-v1_5',
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]),
        hash: 'SHA-256',
      },
      true,
      ['sign', 'verify'],
    ) as CryptoKeyPair;

    const pkcs8 = new Uint8Array(
      await crypto.subtle.exportKey('pkcs8', pair.privateKey),
    );
    let bin = '';
    for (const b of pkcs8) bin += String.fromCharCode(b);
    const b64 = btoa(bin);
    // Servis hesabı JSON'undaki biçimin aynısı: 64 karakterlik satırlar +
    // başlık/dipnot. Ayrıştırıcı bunların hepsini atmak zorunda.
    const pem = '-----BEGIN PRIVATE KEY-----\n' +
      (b64.match(/.{1,64}/g) ?? []).join('\n') +
      '\n-----END PRIVATE KEY-----\n';

    const imported = await importPrivateKey(pem);
    const data = new TextEncoder().encode('kelimeki.header.claim');
    const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', imported, data);

    assert(
      await crypto.subtle.verify('RSASSA-PKCS1-v1_5', pair.publicKey, sig, data),
      'PEM\'den içe aktarılan anahtarla üretilen imza doğrulanamadı',
    );
  });

Deno.test('importPrivateKey — satır sonu KAÇIŞLARI çözülmemişse de çalışır',
  async () => {
    // JSON.parse `\n`leri gerçek satır sonuna çevirir, ama secret elle
    // yapıştırılırken tek satıra sıkışmış bir PEM de gelebilir. Ayrıştırıcı
    // TÜM boşlukları attığı için ikisi de aynı sonucu vermeli.
    const pair = await crypto.subtle.generateKey(
      {
        name: 'RSASSA-PKCS1-v1_5',
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]),
        hash: 'SHA-256',
      },
      true,
      ['sign', 'verify'],
    ) as CryptoKeyPair;
    const pkcs8 = new Uint8Array(
      await crypto.subtle.exportKey('pkcs8', pair.privateKey),
    );
    let bin = '';
    for (const b of pkcs8) bin += String.fromCharCode(b);
    const tekSatir = '-----BEGIN PRIVATE KEY-----' + btoa(bin) +
      '-----END PRIVATE KEY-----';
    const imported = await importPrivateKey(tekSatir);
    const data = new TextEncoder().encode('x');
    const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', imported, data);
    assert(await crypto.subtle.verify('RSASSA-PKCS1-v1_5', pair.publicKey, sig, data));
  });
