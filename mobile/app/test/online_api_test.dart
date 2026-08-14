// `OnlineApi.submitMove`'un retry/idempotency döngüsü — mobilin ASIL
// güvenilirlik özelliği ve 13 Ağustos 2026 denetimine kadar SIFIR test
// kapsamı vardı.
//
// Neden ekran testleri yetmiyordu: `online_game_screen_test.dart`ın 15
// testi "hamle sunucuya gitti" davranışını `FakeOnlineGamesGateway`
// sınırının ÜSTÜNDE ölçüyor; döngü o sınırın ALTINDA (gateway → OnlineApi
// → supabase.rpc). Denetim bunu somut olarak gösterdi: `final id = moveId
// ?? uuidV4()` satırı döngünün İÇİNE taşınsa — her denemede YENİ uuid,
// yani idempotensi tamamen kırılır ve sunucuda çifte hamle riski geri
// gelir — 389 testin hiçbiri düşmüyordu. Parça 86'nın dersinin aynısı:
// bir sözleşmeyi enjekte edilebilir sınırın ÜSTÜNDE test etmek, o sınırın
// ALTINDAKİ iletimi kanıtlamaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/online_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  test('taşıma hatasında AYNI p_move_id ile yeniden denenir (idempotensi)',
      () async {
    final ids = <Object?>[];
    var calls = 0;
    final api = OnlineApi.withRpc((params) async {
      calls++;
      ids.add(params['p_move_id']);
      if (calls == 1) throw Exception('soket koptu');
    });

    await api.submitMove(gameId: 'g1', action: 'pass');

    expect(calls, 2);
    // ASIL SÖZLEŞME: iki denemenin id'si BİREBİR aynı olmalı. Farklı
    // olsaydı sunucudaki `(online_game_id, move_id)` unique index'i devreye
    // giremez, ilk denemesi aslında ulaşmış bir hamle ikinci kez işlenirdi.
    expect(ids, hasLength(2));
    expect(ids[0], isNotNull);
    expect(ids[1], ids[0]);
  });

  test('PostgrestException sunucunun KESİN kararı — retry YOK, aynen fırlar',
      () async {
    var calls = 0;
    final api = OnlineApi.withRpc((_) async {
      calls++;
      throw PostgrestException(message: 'Sıra sende değil.');
    });

    await expectLater(
      api.submitMove(gameId: 'g1', action: 'pass'),
      throwsA(isA<PostgrestException>()),
    );
    // Kural reddini tekrar denemek anlamsız (ve sunucuyu boşuna yorar).
    expect(calls, 1);
  });

  test('taşıma hatası maxAttempts boyunca sürerse hata yüzeye çıkar',
      () async {
    var calls = 0;
    final api = OnlineApi.withRpc((_) async {
      calls++;
      throw Exception('timeout');
    });

    await expectLater(
      api.submitMove(gameId: 'g1', action: 'pass', maxAttempts: 2),
      throwsA(isA<Exception>()),
    );
    expect(calls, 2); // sessizce başarı DÖNMEZ
  });

  test('moveId açıkça verilirse o kullanılır (çağıranın retry kancası)',
      () async {
    final ids = <Object?>[];
    final api = OnlineApi.withRpc((params) async {
      ids.add(params['p_move_id']);
    });

    await api.submitMove(
        gameId: 'g1', action: 'pass', moveId: 'sabit-move-id');

    expect(ids, ['sabit-move-id']);
  });
}
