// `util/game_list_order.dart` — oyun listelerinin sıralama kuralı.
//
// Vakalar web ikizinin doğrulama betiğiyle BİREBİR aynı
// (`npm run verify-game-list-order`); iki taraf aynı kuralı okumak zorunda.
//
// NEDEN ÖNEMLİ: bu kural İKİ ayrı isteğin kesişimi ve biri ötekini
// geçersiz kılmadan yaşamak zorunda —
//   31 Ağustos: "son oynanan her zaman en üstte olacak"
//    3 Eylül  : "sıra sende bekleyenlerde bitmeye en yakın üstte"
// Çözüm asimetrik: sıra BENDE artan, sıra RAKİPTE azalan. Aşağıdaki iki
// yön iddiası bu dengenin negatif eşleri.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/game_list_order.dart';

class _G {
  final String id;
  final bool mine;
  final int? dl;
  const _G(this.id, this.mine, this.dl);
}

void main() {
  String sirala(List<_G> gs) => orderActiveGames(gs,
          myTurn: (g) => g.mine, deadlineMs: (g) => g.dl)
      .map((g) => g.id)
      .join(',');

  group('aktif oyunlar', () {
    test('sırası bende olanlar HER ZAMAN üstte', () {
      expect(
          sirala(const [_G('rakip', false, 900), _G('bende', true, 100)]),
          'bende,rakip');
    });

    test('SIRA BENDE: en yakın bitiş üstte (ARTAN) — 3 Eylül isteği', () {
      expect(
          sirala(const [
            _G('gec', true, 900),
            _G('yakin', true, 100),
            _G('orta', true, 500),
          ]),
          'yakin,orta,gec');
    });

    test('SIRA RAKİPTE: son oynanan üstte (AZALAN) — 31 Ağustos KORUNUR', () {
      expect(
          sirala(const [
            _G('eski', false, 100),
            _G('yeni', false, 900),
            _G('orta', false, 500),
          ]),
          'yeni,orta,eski',
          reason: 'listenin tamamı artana çevrilirse bu düşer');
    });

    test('deadline null "sıra bende" grubunda EN SONA düşer', () {
      // null'ı 0 saymak onu EN ÜSTE taşırdı — eski koddaki hazır tuzak.
      expect(
          sirala(const [_G('bilinmiyor', true, null), _G('yakin', true, 100)]),
          'yakin,bilinmiyor');
    });

    test('deadline null "sıra rakipte" grubunda da EN SONA düşer', () {
      expect(
          sirala(
              const [_G('bilinmiyor', false, null), _G('yeni', false, 900)]),
          'yeni,bilinmiyor');
    });

    test('eşit ölçütte giriş sırası korunur (Dart sort KARARLI DEĞİL)', () {
      expect(
          sirala(const [
            _G('a', true, 100),
            _G('b', true, 100),
            _G('c', true, 100),
          ]),
          'a,b,c');
    });
  });

  group('orderByExpiry — davetler ve yerel kayıtlar', () {
    String exp(List<int?> xs) {
      final items = [for (var i = 0; i < xs.length; i++) (v: xs[i], i: i)];
      return orderByExpiry(items, (t) => t.v).map((t) => t.i).join(',');
    }

    test('bitmeye en yakın üstte (ARTAN)', () {
      expect(exp(const [300, 100, 200]), '1,2,0');
    });
    test('null EN SONA', () {
      expect(exp(const [null, 200, 100]), '2,1,0');
    });
    test('hepsi null → giriş sırası', () {
      expect(exp(const [null, null, null]), '0,1,2');
    });
    test('eşit değerlerde giriş sırası korunur', () {
      expect(exp(const [100, 100]), '0,1');
    });
  });
}
