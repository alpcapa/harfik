// Girişte hangi sekmenin açılacağı — web kuralının TÜKETİCİ davranış paritesi.
//
// NEDEN GOLDEN, NEDEN SAYI KARŞILAŞTIRMASI DEĞİL (21 Ağustos 2026):
// `decideInitialMainView` web'de `src/utils/pendingLiveGames.ts`, portta
// `online_games_api.dart` — iki ELLE SENKRON kopya, ama karşılaştırılacak bir
// SAYI yok; kopyalanan şey ALGORİTMA. `layout_parity_test`in yöntemi (kaynağı
// okuyup değeri çekmek) burada işe yaramaz: aynı sonucu veren iki farklı
// yazım da geçerlidir, aynı yazımı veren iki farklı sonuç ise olamaz.
//
// Bu yüzden web'in ÜRETİM fonksiyonu TÜM girdi uzayında koşturulup
// `test/goldens/initial_main_view.json`e donduruluyor
// (`npm run generate-initial-main-view-golden`), bu test de portun kendi
// kopyasını aynı tabloya karşı sınıyor. 112 vaka = tüketici, örneklem değil.
//
// ⚠ BAYATLAMA DELİĞİ VE NASIL KAPATILDI: golden üretilmiş bir dosya, yani TS
// kuralı değişip golden yeniden üretilmezse bu test ESKİ tabloya karşı geçer.
// `web-ci.yml` üreticiyi koşup `git diff --exit-code` ile dosyanın tazeliğini
// zorluyor; golden değişince de `mobile/**` dosyası değiştiği için
// `mobile-build.yml` tetiklenip bu test koşuyor. Zincir böyle kapanıyor.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/online_games_api.dart';

import 'support/web_source.dart';

void main() {
  test('decideInitialMainView web golden\'ıyla TÜM girdi uzayında aynı', () {
    final golden = jsonDecode(
        readRepoFile('mobile/app/test/goldens/initial_main_view.json'));
    final cases = (golden as Map)['cases'] as List;

    // Boşa geçen test koruması: üretici 112 vaka yazıyor ve üç sonucu da
    // temsil ediyor. Golden bir gün boşalır/kırpılırsa test bunu söylemeli.
    expect(cases, hasLength(112),
        reason: 'golden beklenen vaka sayısını vermedi — üreticiyi koştur: '
            'npm run generate-initial-main-view-golden');
    expect({for (final c in cases) '${(c as Map)['expected']}'},
        {'live', 'local', 'null'},
        reason: 'golden üç sonucu da içermeli');

    for (final raw in cases) {
      final c = raw as Map;
      final sayac = c['counts'] == null
          ? null
          : PendingLiveGameCounts(
              (c['counts'] as List)[0] as int,
              (c['counts'] as List)[1] as int,
              (c['counts'] as List)[2] as int,
            );
      final kayitlar = c['saves'] == null
          ? null
          : List<Object?>.filled(c['saves'] as int, null);

      final sonuc = decideInitialMainView(sayac, kayitlar);
      final adi = sonuc == null
          ? null
          : (sonuc == InitialMainView.live ? 'live' : 'local');

      expect(adi, c['expected'],
          reason: 'counts=${c['counts']} saves=${c['saves']} → '
              'web "${c['expected']}" derken port "$adi" dedi');
    }
  });
}
