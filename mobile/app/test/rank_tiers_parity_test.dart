// Rütbe merdiveni — web `leagueRank.ts` KANONİK kaynaktır.
//
// NEDEN VAR: kademe tablosu (ad/harf/renk/eşik/ödül) ÜÇ kopya olarak elle
// senkron tutuluyor — SQL'deki `_award_league_rewards` ↔
// `src/utils/leagueRank.ts` ↔ `lib/src/ui/rank/league_rank.dart`. Üç dosya
// da başlığında "biri değişirse ÜÇÜ birden değişmeli — hiçbir derleyici/test
// bunu yakalamaz" diye uyarıyordu ve bu 14 Ağustos 2026'ya kadar DOĞRUYDU:
// `league_rewards_test.dart` yalnızca İÇ tutarlılığı ölçüyor (ödül = eşik/10,
// kümülatif toplamların farklılığı, sınır davranışı). O testlerin HEPSİ,
// web'de bir eşik değişip portta değişmese de geçmeye devam ederdi — kural
// kendi içinde tutarlı kalır, yalnızca iki platform ayrışırdı.
//
// Bu test o boşluğun TS ↔ Dart yarısını kapatıyor: web'in kaynak dosyasını
// okuyup satır satır karşılaştırıyor (`color_tokens_test.dart`ın tailwind'i
// okuyan deseninin aynısı).
//
// SQL YARISI KAPSAM DIŞI (dürüst sınır): `_award_league_rewards`ın güncel
// tanımı tek bir migration dosyasında durmuyor — sonraki migration'lar
// fonksiyonu yeniden yazıyor, yani "şu an canlıda ne var" sorusu ancak
// veritabanına sorularak yanıtlanır ve bir birim testi bunu yapamaz.
// Migration uygulanırken canlıda doğrulanması gereken şey olarak kalıyor.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/rank/league_rank.dart';

/// Repo kökü — testler `mobile/app`'ten koşuyor.
final _root = Directory.current.path.endsWith('mobile/app')
    ? Directory('../..')
    : Directory('.');

class _WebTier {
  final String name;
  final String letter;
  final int color;
  final int threshold;
  final int reward;
  const _WebTier(this.name, this.letter, this.color, this.threshold, this.reward);
}

/// `{ name: 'Çaylak', letter: 'Ç', color: '#8A93A2', threshold: 0, reward: 0 }`
List<_WebTier> _webTiers() {
  final src = File('${_root.path}/src/utils/leagueRank.ts').readAsStringSync();
  final block = RegExp(r'RANK_TIERS:\s*RankTier\[\]\s*=\s*\[(.*?)\n\];', dotAll: true)
      .firstMatch(src)
      ?.group(1);
  expect(block, isNotNull,
      reason: 'leagueRank.ts içinde RANK_TIERS dizisi bulunamadı — dosyanın '
          'yapısı değiştiyse bu testin ayrıştırıcısı da güncellenmeli');
  final out = <_WebTier>[];
  for (final m in RegExp(
          r"name:\s*'([^']+)',\s*letter:\s*'([^']+)',\s*color:\s*'#([0-9A-Fa-f]{6})',"
          r"\s*threshold:\s*(\d+),\s*reward:\s*(\d+)")
      .allMatches(block!)) {
    out.add(_WebTier(
      m.group(1)!,
      m.group(2)!,
      int.parse('FF${m.group(3)!}', radix: 16),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    ));
  }
  return out;
}

void main() {
  test('kRankTiers, web leagueRank.ts ile BİREBİR aynı', () {
    final web = _webTiers();

    // Ayrıştırıcı sessizce 0 satır bulup testi "geçirmesin" diye alt sınır.
    expect(web.length, greaterThanOrEqualTo(9),
        reason: 'web RANK_TIERS beklenenden az satır verdi — ayrıştırıcı '
            'bozulmuş olabilir');
    expect(kRankTiers.length, web.length,
        reason: 'Kademe SAYISI ayrışmış: web ${web.length}, port '
            '${kRankTiers.length}. Yeni bir kademe eklenirken ÜÇ kopya da '
            '(SQL, leagueRank.ts, league_rank.dart) güncellenmeli.');

    for (var i = 0; i < web.length; i++) {
      final w = web[i];
      final p = kRankTiers[i];
      final where = '${i + 1}. kademe (web: "${w.name}")';
      expect(p.name, w.name, reason: '$where — ad ayrışmış');
      expect(p.letter, w.letter, reason: '$where — mühür harfi ayrışmış');
      expect(p.threshold, w.threshold, reason: '$where — EŞİK ayrışmış');
      expect(p.reward, w.reward, reason: '$where — ÖDÜL ayrışmış');
      // Web hex literal yazıyor, port palet token'ı (kAccent gibi) kullanıyor;
      // karşılaştırma çözülmüş değer üzerinden.
      expect(p.color.toARGB32(), w.color,
          reason: '$where — RENK ayrışmış (port token kullanıyor, web hex; '
              'token yanlış seçilmiş olabilir)');
    }
  });

  test('ödül = eşik/10 kuralı web tarafında da geçerli', () {
    // Bu kural portun kendi testinde zaten var; burada KAYNAĞA karşı
    // doğrulanıyor — kural web'de bozulursa port sessizce ona uymasın.
    for (final w in _webTiers()) {
      expect(w.reward, w.threshold ~/ 10,
          reason: 'web "${w.name}" kademesinde ödül = eşik/10 kuralı bozulmuş '
              '(eşik ${w.threshold}, ödül ${w.reward}). Kural bilinçli olarak '
              'değiştiyse portun testi de güncellenmeli.');
    }
  });
}
