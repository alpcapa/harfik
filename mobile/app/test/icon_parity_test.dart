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

String _f(num v) => v.toStringAsFixed(3);

final _numRe = RegExp(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');
List<double> _nums(String s) =>
    [for (final m in _numRe.allMatches(s)) double.parse(m.group(0)!)];

/* ── SVG path → mutlak parçalar ─────────────────────────────────────────── */

final _tokRe =
    RegExp(r'[MmLlHhVvCcSsAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');
final _letterRe = RegExp(r'^[A-Za-z]$');

List<String> _parseSvgPath(String d) {
  final toks = [for (final m in _tokRe.allMatches(d)) m.group(0)!];
  final segs = <String>[];
  var i = 0;
  double x = 0, y = 0, sx = 0, sy = 0;
  String? cmd;
  double? c2x, c2y;

  List<double> take(int n) {
    final v = <double>[];
    for (var k = 0; k < n; k++) {
      expect(i + k < toks.length, isTrue, reason: 'path erken bitti: $d');
      v.add(double.parse(toks[i + k]));
    }
    i += n;
    return v;
  }

  while (i < toks.length) {
    if (_letterRe.hasMatch(toks[i])) {
      cmd = toks[i];
      i++;
    } else if (cmd == 'M') {
      cmd = 'L'; // `M x y x2 y2` → ikinci çift örtük L
    } else if (cmd == 'm') {
      cmd = 'l';
    }
    expect(cmd, isNotNull, reason: 'path komutsuz başladı: $d');
    switch (cmd) {
      case 'M':
      case 'm':
        final v = take(2);
        x = cmd == 'M' ? v[0] : x + v[0];
        y = cmd == 'M' ? v[1] : y + v[1];
        sx = x;
        sy = y;
        c2x = null;
        break;
      case 'L':
      case 'l':
        final v = take(2);
        final nx = cmd == 'L' ? v[0] : x + v[0];
        final ny = cmd == 'L' ? v[1] : y + v[1];
        segs.add('L ${_f(x)} ${_f(y)} ${_f(nx)} ${_f(ny)}');
        x = nx;
        y = ny;
        c2x = null;
        break;
      case 'H':
      case 'h':
        final v = take(1);
        final nx = cmd == 'H' ? v[0] : x + v[0];
        segs.add('L ${_f(x)} ${_f(y)} ${_f(nx)} ${_f(y)}');
        x = nx;
        c2x = null;
        break;
      case 'V':
      case 'v':
        final v = take(1);
        final ny = cmd == 'V' ? v[0] : y + v[0];
        segs.add('L ${_f(x)} ${_f(y)} ${_f(x)} ${_f(ny)}');
        y = ny;
        c2x = null;
        break;
      case 'C':
      case 'c':
        final v = take(6);
        final a = cmd == 'C'
            ? v
            : [v[0] + x, v[1] + y, v[2] + x, v[3] + y, v[4] + x, v[5] + y];
        segs.add('C ${_f(x)} ${_f(y)} ${_f(a[0])} ${_f(a[1])} '
            '${_f(a[2])} ${_f(a[3])} ${_f(a[4])} ${_f(a[5])}');
        c2x = a[2];
        c2y = a[3];
        x = a[4];
        y = a[5];
        break;
      case 'S':
      case 's':
        final v = take(4);
        final a = cmd == 'S' ? v : [v[0] + x, v[1] + y, v[2] + x, v[3] + y];
        // Düz (smooth) eğri: ilk kontrol noktası öncekinin YANSIMASI.
        final r1x = c2x == null ? x : 2 * x - c2x;
        final r1y = c2y == null ? y : 2 * y - c2y;
        segs.add('C ${_f(x)} ${_f(y)} ${_f(r1x)} ${_f(r1y)} '
            '${_f(a[0])} ${_f(a[1])} ${_f(a[2])} ${_f(a[3])}');
        c2x = a[0];
        c2y = a[1];
        x = a[2];
        y = a[3];
        break;
      case 'A':
      case 'a':
        final v = take(7);
        expect(v[2], 0, reason: 'döndürülmüş yay desteklenmiyor: $d');
        expect(v[3], 0, reason: 'largeArc desteklenmiyor: $d');
        expect((v[0] - v[1]).abs() < 1e-9, isTrue,
            reason: 'eliptik yay desteklenmiyor: $d');
        final nx = cmd == 'A' ? v[5] : x + v[5];
        final ny = cmd == 'A' ? v[6] : y + v[6];
        segs.add(
            'A ${_f(x)} ${_f(y)} ${_f(nx)} ${_f(ny)} ${_f(v[0])} ${_f(v[4])}');
        x = nx;
        y = ny;
        c2x = null;
        break;
      case 'Z':
      case 'z':
        segs.add('L ${_f(x)} ${_f(y)} ${_f(sx)} ${_f(sy)}');
        x = sx;
        y = sy;
        break;
      default:
        fail('bilinmeyen path komutu "$cmd": $d');
    }
  }
  return segs;
}

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
          for (final s in _parseSvgPath(a['d']!)) {
            items.add('$kind $s');
          }
          break;
        case 'rect':
          items.add('$kind rect ${_f(double.parse(a['x']!))} '
              '${_f(double.parse(a['y']!))} ${_f(double.parse(a['width']!))} '
              '${_f(double.parse(a['height']!))} '
              '${_f(double.parse(a['rx'] ?? '0'))}');
          break;
        default:
          var r = double.parse(a['r']!);
          // Dolu + kenarlıklı daire: BOYANAN yarıçap r + kalınlık/2.
          if (filled && a.containsKey('strokeWidth')) {
            r += double.parse(a['strokeWidth']!) / 2;
          }
          items.add('$kind circle ${_f(double.parse(a['cx']!))} '
              '${_f(double.parse(a['cy']!))} ${_f(r)}');
      }
    }
    out[fn.group(1)!] = items;
  }
  return out;
}

/* ── port ───────────────────────────────────────────────────────────────── */

/// `..moveTo/..lineTo/..cubicTo/..arcToPoint` zincirini mutlak parçalara çevirir.
List<String> _dartPath(String src) {
  final segs = <String>[];
  double x = 0, y = 0;
  final opRe = RegExp(r'\.\.(moveTo|lineTo|cubicTo|arcToPoint)\(');
  for (final m in opRe.allMatches(src)) {
    final arg = _balanced(src, m.end);
    switch (m.group(1)) {
      case 'moveTo':
        final v = _nums(arg);
        x = v[0];
        y = v[1];
        break;
      case 'lineTo':
        final v = _nums(arg);
        segs.add('L ${_f(x)} ${_f(y)} ${_f(v[0])} ${_f(v[1])}');
        x = v[0];
        y = v[1];
        break;
      case 'cubicTo':
        final v = _nums(arg);
        segs.add('C ${_f(x)} ${_f(y)} ${_f(v[0])} ${_f(v[1])} '
            '${_f(v[2])} ${_f(v[3])} ${_f(v[4])} ${_f(v[5])}');
        x = v[4];
        y = v[5];
        break;
      default:
        final off = _nums(RegExp(r'Offset\(([^)]*)\)').firstMatch(arg)!.group(1)!);
        final r = double.parse(
            RegExp(r'Radius\.circular\(([\d.]+)\)').firstMatch(arg)!.group(1)!);
        final sweep = arg.contains('clockwise: true') ? 1.0 : 0.0;
        segs.add('A ${_f(x)} ${_f(y)} ${_f(off[0])} ${_f(off[1])} '
            '${_f(r)} ${_f(sweep)}');
        x = off[0];
        y = off[1];
    }
  }
  return segs;
}

/// `start` açılış parantezinin HEMEN ardındaki konumsa, kapanışına kadarki metin.
String _balanced(String src, int start) {
  var depth = 1, i = start;
  while (depth > 0) {
    expect(i < src.length, isTrue, reason: 'parantez dengesiz');
    if (src[i] == '(') depth++;
    if (src[i] == ')') depth--;
    i++;
  }
  return src.substring(start, i - 1);
}

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
      final arg = _balanced(body, c.end);
      final kind =
          RegExp(r',\s*fill\s*,?\s*$').hasMatch(arg) ? 'fill' : 'stroke';
      switch (c.group(1)) {
        case 'Line':
          final v = _nums(arg);
          items.add('$kind L ${_f(v[0])} ${_f(v[1])} ${_f(v[2])} ${_f(v[3])}');
          break;
        case 'RRect':
          final v = _nums(arg);
          items.add('$kind rect ${_f(v[0])} ${_f(v[1])} ${_f(v[2])} '
              '${_f(v[3])} ${_f(v[4])}');
          break;
        case 'Circle':
          final off =
              _nums(RegExp(r'Offset\(([^)]*)\)').firstMatch(arg)!.group(1)!);
          final r = val(RegExp(r'\)\s*,\s*([^,]+),').firstMatch(arg)!.group(1)!);
          items.add('$kind circle ${_f(off[0])} ${_f(off[1])} ${_f(r)}');
          break;
        default:
          items.addAll(_dartPath(arg).map((s) => '$kind $s'));
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
