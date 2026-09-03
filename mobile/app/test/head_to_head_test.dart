// `util/head_to_head.dart` — kafa kafaya oran çubuğunun kuralı.
//
// Vakalar web ikizinin doğrulama betiğiyle BİREBİR aynı
// (`npm run verify-head-to-head`).
//
// NEDEN ÖNEMLİ: bar bir ORANı gösteriyor ve yüzdeler toplamı 100 etmezse
// çubuğun ucunda görünür bir boşluk/taşma oluşur. Üç dilimi bağımsız
// yuvarlamak tam olarak bunu yapar (33+33+33=99) — "toplam HER ZAMAN 100"
// iddiası o hatanın negatif eşi.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/head_to_head.dart';

HeadToHead h(int games, int wins, int losses, int draws) =>
    HeadToHead(games: games, wins: wins, losses: losses, draws: draws);

void main() {
  group('yön: sol = BAKILAN kişi, sağ = BAKAN kişi', () {
    test('bakılan kişi daha çok kazandıysa SOL dilim büyük', () {
      // Canlıdan ölçülen gerçek vaka: A→B 14 oyun, 5 galibiyet, 9 mağlubiyet.
      final b = headToHeadBar(h(14, 5, 9, 0));
      expect(b.left, greaterThan(b.right));
      expect(b.left, ((9 * 100) / 14).round());
    });
  });

  group('yüzdeler toplamı HER ZAMAN 100', () {
    for (final c in const [
      [14, 5, 9, 0],
      [3, 1, 1, 1],
      [1, 1, 0, 0],
      [7, 3, 3, 1],
      [100, 33, 33, 34],
    ]) {
      test('${c[0]} oyun (${c[1]}/${c[2]}/${c[3]})', () {
        final b = headToHeadBar(h(c[0], c[1], c[2], c[3]));
        expect(b.left + b.middle + b.right, 100,
            reason: 'sol=${b.left} orta=${b.middle} sağ=${b.right}');
      });
    }
  });

  group('uç durumlar', () {
    test('hiç oyun yok → üçü de 0 ve blok çizilmez', () {
      final b = headToHeadBar(h(0, 0, 0, 0));
      expect([b.left, b.middle, b.right], [0, 0, 0]);
      expect(hasHeadToHead(h(0, 0, 0, 0)), isFalse);
      expect(hasHeadToHead(null), isFalse);
      expect(hasHeadToHead(h(1, 1, 0, 0)), isTrue);
    });

    test('hepsini BAKAN kazandıysa sağ 100', () {
      final b = headToHeadBar(h(4, 4, 0, 0));
      expect(b.right, 100);
      expect(b.left, 0);
    });

    test('hepsini BAKILAN kazandıysa sol 100', () {
      final b = headToHeadBar(h(4, 0, 4, 0));
      expect(b.left, 100);
      expect(b.right, 0);
    });

    test('hepsi beraberlikse orta 100', () {
      expect(headToHeadBar(h(2, 0, 0, 2)).middle, 100);
    });
  });

  group('fromJson', () {
    test('eksik/boş alanlar 0 olur', () {
      final x = HeadToHead.fromJson(const {'games': 3, 'wins': 2});
      expect([x.games, x.wins, x.losses, x.draws], [3, 2, 0, 0]);
    });
  });
}
