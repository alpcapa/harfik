// "Neler var" altı özellik ikonu — web SVG'si ↔ portun `CustomPainter`'ı.
//
// NEDEN VAR (21 Ağustos 2026): `OzellikIkonlari.tsx` ile
// `ozellik_ikonlari.dart` iki ELLE SENKRON kopya ve dosyanın kendi başlığı
// "biri değişirse öteki de değişmeli — bunu zorlayan bir test YOK" diyordu.
// İkisi de Material glyph'i DEĞİL, ilkel şekillerden (daire/dikdörtgen/
// çizgi/yay/eğri) kurulu ve AYNI 24'lük viewBox koordinatlarını kullanıyor —
// yani karşılaştırılabilirler.
//
// **Bu test yazılırken GERÇEK bir sapma buldu:** web'de noktalar
// `<circle r="0.6" fill stroke-width="1.6">` ile çiziliyor, yani BOYANAN
// yarıçap 1.4; port ise dolu bir daireyi `0.9` ile çiziyordu. 13px'lik ikonda
// web 1.52 px, port 0.98 px çap demek. Sapma ölçülerek doğrulandı (web SVG'si
// Chromium'da 40× büyütülüp boyanan piksel aralığı tarandı → 1.400) ve port
// düzeltildi.
//
// YÖNTEM: iki taraf da KANONİK bir çizim listesine indirgeniyor —
// `stroke|fill` + `L/C/A/rect/circle` + mutlak koordinatlar. Böylece web'in
// göreli SVG komutları (`v`, `l`, `c`, `s`, `a`) ile portun mutlak
// `lineTo/cubicTo/arcToPoint`'i aynı dile çevriliyor; biri "tek path içinde
// iki alt yol", öteki "iki ayrı drawLine" yazsa bile sonuç eşleşiyor.
//
// ⚠ SIRA ÖNEMLİ: liste sıralanmadan karşılaştırılıyor, çünkü çizim sırası
// üst üste binmede (tahtadaki dolu kare ızgara çizgilerinin ÜSTÜNDE) görünür
// bir fark yaratır.
//
// KAPSAM DIŞI: renk (çağırandan miras, `color_tokens_test`in işi), boy
// (varsayılan 13), `strokeWidth`/`strokeCap` gibi Paint ayarları ve
// `aria-hidden`. Burada yalnızca GEOMETRİ karşılaştırılıyor.
//
// ⚠ TRANSKRİPSİYON TUZAĞI (CI 21 Ağustos 2026'da yakaladı): bu ayrıştırıcı
// önce Python'da prototiplendi ve oradan Dart'a çevrildi — Python'da
// `Match.end()` bir METOT, Dart'ta `Match.end` bir GETTER. Prototipin API
// şekli olduğu gibi kopyalanınca `dart analyze` düştü. Prototipleme yöntemi
// MANTIĞI doğruluyor, DİLİ değil; çeviriden sonra getter/metot ayrımı ayrıca
// taranmalı.
import 'package:flutter_test/flutter_test.dart';

import 'support/web_source.dart';
import 'support/vector_parity.dart';

/// web adı → (port fonksiyonu, ÖLÇÜLEN çizim adedi).
///
/// Adet BOŞA GEÇME koruması: iki ayrıştırıcı da aynı anda sessizce daha az
/// şey üretirse liste karşılaştırması yine eşit çıkar ve test hiçbir şey
/// kanıtlamadan yeşil kalırdı. Sayılar gerçek dosyalardan ölçüldü.
const _pairs = <String, List<Object>>{
  'RobotIkon': ['_robot', 4],
  'IkiKisiIkon': ['_ikiKisi', 5],
  'SohbetIkon': ['_sohbet', 3],
  'CevrimdisiIkon': ['_cevrimdisi', 4],
  'TahtaIkon': ['_tahta', 4],
  'MadalyaIkon': ['_madalya', 5],
};

/* ── web ────────────────────────────────────────────────────────────────── */

Map<String, List<String>> _webIcons(String src) {
  final out = <String, List<String>>{};
  final fnRe = RegExp(
      r'export function (\w+)\(props: OzellikIkonProps\) \{(.*?)\n\}',
      dotAll: true);
  final elRe = RegExp(r'<(path|rect|circle)\s([^/]*?)/>', dotAll: true);
  final attrRe = RegExp(r'(\w+)="([^"]*)"');
  for (final fn in fnRe.allMatches(src)) {
    final items = <String>[];
    for (final el in elRe.allMatches(fn.group(2)!)) {
      final a = {
        for (final m in attrRe.allMatches(el.group(2)!))
          m.group(1)!: m.group(2)!
      };
      final filled = a['fill'] == 'currentColor';
      final kind = filled ? 'fill' : 'stroke';
      switch (el.group(1)) {
        case 'path':
          for (final s in parseSvgPath(a['d']!)) {
            items.add('$kind $s');
          }
          break;
        case 'rect':
          items.add('$kind rect ${f(double.parse(a['x']!))} '
              '${f(double.parse(a['y']!))} ${f(double.parse(a['width']!))} '
              '${f(double.parse(a['height']!))} '
              '${f(double.parse(a['rx'] ?? '0'))}');
          break;
        default:
          var r = double.parse(a['r']!);
          // Dolu + kenarlıklı daire: BOYANAN yarıçap r + kalınlık/2.
          if (filled && a.containsKey('strokeWidth')) {
            r += double.parse(a['strokeWidth']!) / 2;
          }
          items.add('$kind circle ${f(double.parse(a['cx']!))} '
              '${f(double.parse(a['cy']!))} ${f(r)}');
      }
    }
    out[fn.group(1)!] = items;
  }
  return out;
}

/* ── port ───────────────────────────────────────────────────────────────── */

Map<String, List<String>> _dartIcons(String src) {
  final consts = {
    for (final m in RegExp(r'const double (_k\w+) = ([\d.]+);').allMatches(src))
      m.group(1)!: double.parse(m.group(2)!)
  };
  double val(String tok) {
    final t = tok.trim();
    return consts[t] ?? double.parse(t);
  }

  final out = <String, List<String>>{};
  final fnRe = RegExp(
      r'\nvoid (_\w+)\(Canvas canvas, Paint stroke, Paint fill\) \{(.*?)\n\}',
      dotAll: true);
  for (final fn in fnRe.allMatches(src)) {
    var body = fn.group(2)!.replaceAll(RegExp(r'//[^\n]*'), '');
    // `final ad = Path()..…;` → `drawPath(ad, …)` çağrısına yerine koy.
    for (final v
        in RegExp(r'final (\w+) = (Path\(\).*?);\n', dotAll: true).allMatches(body)) {
      body = body
          .replaceAll('drawPath(${v.group(1)},', 'drawPath(${v.group(2)},')
          .replaceAll(v.group(0)!, '');
    }
    final items = <String>[];
    final callRe = RegExp(r'canvas\.draw(Line|RRect|Circle|Path)\s*\(');
    for (final c in callRe.allMatches(body)) {
      final arg = balanced(body, c.end);
      final kind =
          RegExp(r',\s*fill\s*,?\s*$').hasMatch(arg) ? 'fill' : 'stroke';
      switch (c.group(1)) {
        case 'Line':
          final v = nums(arg);
          items.add('$kind L ${f(v[0])} ${f(v[1])} ${f(v[2])} ${f(v[3])}');
          break;
        case 'RRect':
          final v = nums(arg);
          items.add('$kind rect ${f(v[0])} ${f(v[1])} ${f(v[2])} '
              '${f(v[3])} ${f(v[4])}');
          break;
        case 'Circle':
          final off =
              nums(RegExp(r'Offset\(([^)]*)\)').firstMatch(arg)!.group(1)!);
          final r = val(RegExp(r'\)\s*,\s*([^,]+),').firstMatch(arg)!.group(1)!);
          items.add('$kind circle ${f(off[0])} ${f(off[1])} ${f(r)}');
          break;
        default:
          items.addAll(dartPath(arg).map((s) => '$kind $s'));
      }
    }
    out[fn.group(1)!] = items;
  }
  return out;
}

void main() {
  test('altı özellik ikonu web SVG\'siyle birebir aynı geometriyi çiziyor', () {
    final web = _webIcons(readRepoFile('src/landing/OzellikIkonlari.tsx'));
    final port = _dartIcons(
        readRepoFile('mobile/app/lib/src/ui/intro/ozellik_ikonlari.dart'));

    // Boşa geçen test koruması: iki taraf da TAM altı ikon vermeli.
    expect(web.keys.toSet(), _pairs.keys.toSet(),
        reason: 'web ikon listesi değişmiş — eşleşme tablosunu güncelle');
    expect(port.keys.toSet(), {for (final v in _pairs.values) v[0] as String},
        reason: 'port ikon listesi değişmiş — eşleşme tablosunu güncelle');

    _pairs.forEach((w, pair) {
      final d = pair[0] as String;
      final beklenen = pair[1] as int;
      expect(web[w], hasLength(beklenen),
          reason: '$w web tarafında $beklenen çizim vermeliydi — ya ikon '
              'değişti ya ayrıştırıcı bozuldu');
      expect(port[d], web[w], reason: '$w ↔ $d geometrisi ayrışmış');
    });
  });
}
