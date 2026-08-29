// Push token DEVRİ tablo upsert'üyle DEĞİL RPC ile yapılır.
//
// NEDEN VAR (29 Ağustos 2026, gerçek cihaz testi adım 2.5'te bulundu):
// aynı telefonda A çıkıp B girdiğinde `push_tokens` satırı A'DA KALIYORDU.
// Sebep RLS: birincil anahtar `token` olduğundan B'nin upsert'ü UPDATE
// dalına düşüyor, `push_tokens_update_own` politikası `USING (auth.uid() =
// user_id)` ile MEVCUT satıra bakıyor ve satır A'nın olduğu için B'ye
// görünmüyor. Canlı veritabanında ölçüldü (işlem içinde, rollback ile):
//
//   ERROR 42501: new row violates row-level security policy
//                (USING expression) for table "push_tokens"
//
// Bedeli boşa gönderim DEĞİL, YANLIŞ KİŞİYE gönderim.
//
// ⚠ **Bunu bir widget/birim testi YAKALAYAMAZ** ve bu testin var olma
// sebebi tam olarak budur: `push_lifecycle_test.dart`taki `FakeStore`
// yazılanı bir listeye ekliyor — RLS diye bir şey yok, dolayısıyla o test
// "çağrı yapıldı"yı kanıtlıyor, "yazma TUTTU"yu değil. Sahte uçla gerçek
// sunucu sözleşmesi arasındaki boşluk bu projede yazılı bir ders
// (kök CLAUDE.md: "testler yeşil ≠ sunucuyla gerçekten konuşuyor").
//
// Bu yüzden burada DAVRANIŞ değil KAYNAK taranıyor — aynı desen:
// `notification_channel_parity_test.dart`, `icon_parity_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

File _repo(String rel) => File('../../$rel');

void main() {
  const istemciYol = 'mobile/app/lib/src/data/push_gateways.dart';
  const migrationDizin = 'supabase/migrations';
  const fnAdi = 'register_push_token';

  late String istemci;      // yorumları ATILMIŞ hâli
  late String istemciHam;

  setUpAll(() {
    final f = _repo(istemciYol);
    expect(f.existsSync(), isTrue, reason: '$istemciYol bulunamadı');
    istemciHam = f.readAsStringSync();
    // ⚠ YORUMLAR ATILIR. İlk sürüm bunu yapmıyordu ve test KENDİ yazdığı
    // açıklamayı yakalayıp düştü: eski yolu ("from('push_tokens').upsert")
    // anlatan yorum, "eski yol geri gelmiş" sanıldı. Kaynak taraması kodu
    // okumalı, düzyazıyı değil — yoksa gerekçeyi yazmak testi bozar.
    istemci = istemciHam
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
  });

  test('istemci token yazmayı RPC ile yapıyor, tabloya doğrudan DEĞİL', () {
    expect(istemci.contains("rpc('$fnAdi'"), isTrue,
        reason: 'Token kaydı $fnAdi RPC\'siyle yapılmalı. Doğrudan tablo '
            'upsert\'ü RLS yüzünden hesap değişiminde SESSİZCE reddediliyor '
            've bildirim yanlış kişiye düşüyor.');

    // Negatif taraf: eski yol geri gelmesin.
    final tabloYazmasi = RegExp(r"from\(\s*'push_tokens'\s*\)\s*\.\s*upsert");
    expect(tabloYazmasi.hasMatch(istemci), isFalse,
        reason: '`push_tokens` tablosuna DOĞRUDAN upsert geri gelmiş. '
            'Devir RLS tarafından reddedilir (42501) — RPC\'yi kullan.');
  });

  test('istemci user_id GÖNDERMİYOR — sunucu auth.uid()ten alıyor', () {
    // Güvenlik değişmezi: `user_id` istemciden gelseydi, çağıran token'ı
    // başkasının üstüne yazabilirdi.
    final rpcBloku = istemci.substring(istemci.indexOf("rpc('$fnAdi'"));
    final params = rpcBloku.substring(0, rpcBloku.indexOf('});') + 1);
    expect(params.contains('user_id'), isFalse,
        reason: 'RPC çağrısına user_id geçilmiş. Fonksiyon onu auth.uid()ten '
            'almalı; istemciden alırsa token başkasının üstüne yazılabilir.');
    expect(params.contains('p_token') && params.contains('p_platform'), isTrue,
        reason: 'RPC parametre adları (p_token/p_platform) değişmiş olabilir');
  });

  test('migration gerçekten repoda ve fonksiyonu SECURITY DEFINER', () {
    final dizin = Directory('../../$migrationDizin');
    expect(dizin.existsSync(), isTrue, reason: '$migrationDizin bulunamadı');
    final dosya = dizin
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains(fnAdi) && f.path.endsWith('.sql'))
        .toList();
    expect(dosya, isNotEmpty,
        reason: '$fnAdi migration dosyası repoda yok — canlıya elle '
            'uygulanmış bir fonksiyon, repoda izi olmadan kalmamalı '
            '(kök CLAUDE.md, "Migration\'lar" bölümü).');
    final sql = dosya.first.readAsStringSync();
    expect(sql.contains('security definer'), isTrue,
        reason: 'Fonksiyon SECURITY DEFINER değilse RLS\'i aşamaz ve '
            'düzeltmenin tamamı anlamsız kalır.');
    expect(sql.contains('auth.uid()'), isTrue,
        reason: 'user_id auth.uid()ten alınmalı');
  });
}
