// `rematchSlots` (online_games_api.dart) — "Tekrar Oyna" kadro kuralı.
//
// Vakalar web ikizinin doğrulama betiğiyle BİREBİR aynı
// (`npm run verify-rematch-slots` → `src/utils/rematchSlots.ts`); iki taraf
// aynı kuralı okumak zorunda.
//
// NEDEN ÖNEMLİ: sıralama kozmetik DEĞİL, `create_online_game`in üç
// kısıtının karşılığı — (1) ilk koltuk çağıran, (2) 4 kişilikte YZ yalnız
// son koltukta, (3) 2 kişilikte YZ zaten olamaz. Kural sessizce bozulursa
// RPC reddeder ve hata ancak "Tekrar Oyna çalışmıyor" olarak kullanıcıda
// görünür.
//
// 4 Eylül 2026'da imza `OnlineGame` yerine KOLTUK LİSTESİ almaya çevrildi:
// oyun geçmişindeki "Tekrar Oyna" elinde bir `OnlineGame` değil, biten
// oyunun ayrıca okunmuş `slots` dizisi tutuyor.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/online_games_api.dart';

OnlineSlot _human(String id, {String? name}) =>
    OnlineSlot.human(userId: id, name: name);
const _ai = OnlineSlot.ai();

/// Kadroyu okunur bir dizgeye indirger — beklentiler böyle daha net.
String _ozet(List<NewGameSlot> slots) => slots
    .map((s) => s.humanUserId == null ? 'YZ' : s.humanUserId!)
    .join(',');

void main() {
  group('rematchSlots', () {
    test('kuran bensem sıra korunur', () {
      expect(_ozet(rematchSlots([_human('ben'), _human('rakip')], 'ben')),
          'ben,rakip');
    });

    test('kuran BEN DEĞİLSEM kendimi başa alırım', () {
      // Biten oyunu rakip kurmuş olabilir; rövanşı ben açıyorsam ilk koltuk
      // benim olmak ZORUNDA (create_online_game kısıtı 1).
      expect(_ozet(rematchSlots([_human('rakip'), _human('ben')], 'ben')),
          'ben,rakip');
    });

    test('YZ ortadayken sona taşınır, insanların sırası korunur', () {
      expect(
        _ozet(rematchSlots(
            [_human('a'), _ai, _human('ben'), _human('b')], 'ben')),
        'ben,a,b,YZ',
      );
    });

    test('iki YZ de sonda ve SAYISI korunur', () {
      expect(
        _ozet(rematchSlots([_ai, _human('ben'), _ai, _human('a')], 'ben')),
        'ben,a,YZ,YZ',
      );
    });

    test('koltuk sayısı hiçbir koşulda değişmez', () {
      // RPC oyuncu sayısını AYRICA alıyor; kadro ondan kısa/uzun gelirse
      // sessizce reddedilir.
      final vakalar = <List<OnlineSlot>>[
        [_human('ben'), _human('a')],
        [_human('ben'), _human('a'), _human('b'), _human('c')],
        [_human('ben'), _human('a'), _ai, _ai],
      ];
      for (final slots in vakalar) {
        expect(rematchSlots(slots, 'ben').length, slots.length);
      }
    });

    test('görüntü alanları RPC yüküne sızmaz', () {
      // `NewGameSlot.toJson` yalnız type + user_id yazmalı: name/avatar
      // yalnızca listeleme RPC'sinin eklediği alanlar.
      final json = rematchSlots(
              [_human('ben', name: 'Ben'), _human('a', name: 'Ali')], 'ben')
          .map((s) => s.toJson())
          .toList();
      expect(json[0].keys.toList()..sort(), ['type', 'user_id']);
      expect(json[0]['user_id'], 'ben');
      expect(json[1]['user_id'], 'a');
    });

    test('YZ koltuğu json olarak yalnız type taşır', () {
      final json = rematchSlots([_human('ben'), _ai], 'ben')
          .map((s) => s.toJson())
          .toList();
      expect(json[1], {'type': 'ai'});
    });
  });
}
