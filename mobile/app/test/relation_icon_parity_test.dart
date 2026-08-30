// İlişki ikonu "istek gönderildi" (kişi + kum saati) — web SVG'si ↔ portun
// `CustomPainter`'ı.
//
// NEDEN VAR (30 Ağustos 2026): `RelationIcons.tsx`in dört ikonundan üçü
// gerçek Material glyph'i ve port onları `Icons.*` ile çiziyor — font gömülü
// olduğundan iki platform BENZER değil AYNI vektörü gösteriyor, senkron
// sorunu YOK. Dördüncüsünün ("bekliyor") Material'da karşılığı olmadığından
// ELLE çizildi ve porta ELLE kopyalandı; yani `OzellikIkonlari` ile aynı
// duruma düştü. O çift için yazılan testin gerekçesi burada da geçerli:
// elle senkron bir kopya, senkronu ZORLAYAN bir şey olmadan bayatlar.
//
// YÖNTEM: ortak ayrıştırıcı (`support/vector_parity.dart`) iki tarafı da
// kanonik bir çizim listesine indirger. Web'in `H/V/Z` gibi kısayolları ile
// portun `lineTo/close`u aynı dile çevrilir, yani "aynı şekli farklı
// komutlarla yazmak" testi düşürmez; farklı ŞEKİL düşürür.
//
// KAPSAM DIŞI: renk (çağırandan geliyor, `color_tokens_test`in işi) ve boy.
import 'package:flutter_test/flutter_test.dart';

import 'support/vector_parity.dart';
import 'support/web_source.dart';

/// Web fonksiyonunun gövdesindeki `<path d="…" />` sırası korunarak.
List<String> _webPaths(String src, String fnAdi) {
  final fn = pick(src, RegExp('export function $fnAdi\\((.*?)\n}', dotAll: true),
      '$fnAdi fonksiyonu');
  return pickAll(fn, RegExp(r'<path d="([^"]*)"'), '$fnAdi içindeki path');
}

void main() {
  test('PersonPendingIcon web SVG\'siyle birebir aynı geometriyi çiziyor', () {
    final web = _webPaths(
        readRepoFile('src/components/RelationIcons.tsx'), 'PersonPendingIcon');
    final port =
        readRepoFile('mobile/app/lib/src/ui/friends/relation_icons.dart');

    // Boşa geçme koruması: web tarafı TAM iki path vermeli (kişi + rozet).
    // Biri silinirse aşağıdaki karşılaştırma "iki boş liste eşit" diye
    // sessizce yeşil kalabilirdi.
    expect(web, hasLength(2),
        reason: 'PersonPendingIcon iki <path> taşımalı (kişi + kum saati)');

    final beklenen = [for (final d in web) ...parseSvgPath(d)];
    final gercek = [
      ...dartPath(pick(port, RegExp(r'Path _kisi\(\) =(.*?);\n', dotAll: true),
          '_kisi gövdesi')),
      ...dartPath(pick(port,
          RegExp(r'Path _kumSaati\(\) =(.*?);\n', dotAll: true),
          '_kumSaati gövdesi')),
    ];

    // Ölçülen adet — iki ayrıştırıcı aynı anda sessizce daha az şey üretirse
    // liste karşılaştırması yine eşit çıkardı.
    expect(beklenen, hasLength(25),
        reason: 'web tarafı 25 çizim vermeliydi — ikon değişti mi?');
    expect(gercek, beklenen, reason: 'kişi+kum saati geometrisi ayrışmış');
  });
}
