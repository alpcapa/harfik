// Vektör parite testlerinin ortak ayrıştırıcıları: web SVG path'i ↔ portun
// `Path()..moveTo/lineTo/cubicTo/arcToPoint` zinciri.
//
// NEDEN AYRI DOSYA (30 Ağustos 2026): bu iki ayrıştırıcı
// `icon_parity_test.dart` içinde doğdu ("Neler var" özellik ikonları için).
// İkinci bir elle-senkron ikon çifti (`RelationIcons.tsx` ↔
// `relation_icons.dart`) eklenince aynı mantık ikinci kez gerekti —
// kopyalamak yerine buraya çıkarıldı. Kopya olsaydı biri düzeltilip öteki
// unutulurdu; bu repoda "ikiz dosya" hatası tam böyle doğuyor.
//
// YÖNTEM: iki taraf da KANONİK bir çizim listesine indirgeniyor —
// `L/C/A` + mutlak koordinatlar, üç ondalık. Böylece web'in göreli SVG
// komutları (`v`, `l`, `c`, `s`, `a`, `h`) ile portun mutlak
// `lineTo/cubicTo/arcToPoint`'i aynı dile çevriliyor.
//
// KAPSAM DIŞI: renk, boy, `strokeWidth`/`strokeCap` gibi Paint ayarları.
// Burada yalnızca GEOMETRİ karşılaştırılıyor.
import 'package:flutter_test/flutter_test.dart';

String f(num v) => v.toStringAsFixed(3);

final _numRe = RegExp(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');
List<double> nums(String s) =>
    [for (final m in _numRe.allMatches(s)) double.parse(m.group(0)!)];

final _tokRe =
    RegExp(r'[MmLlHhVvCcSsAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?');
final _letterRe = RegExp(r'^[A-Za-z]$');

/// SVG `d` → mutlak parçalar.
List<String> parseSvgPath(String d) {
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
        segs.add('L ${f(x)} ${f(y)} ${f(nx)} ${f(ny)}');
        x = nx;
        y = ny;
        c2x = null;
        break;
      case 'H':
      case 'h':
        final v = take(1);
        final nx = cmd == 'H' ? v[0] : x + v[0];
        segs.add('L ${f(x)} ${f(y)} ${f(nx)} ${f(y)}');
        x = nx;
        c2x = null;
        break;
      case 'V':
      case 'v':
        final v = take(1);
        final ny = cmd == 'V' ? v[0] : y + v[0];
        segs.add('L ${f(x)} ${f(y)} ${f(x)} ${f(ny)}');
        y = ny;
        c2x = null;
        break;
      case 'C':
      case 'c':
        final v = take(6);
        final a = cmd == 'C'
            ? v
            : [v[0] + x, v[1] + y, v[2] + x, v[3] + y, v[4] + x, v[5] + y];
        segs.add('C ${f(x)} ${f(y)} ${f(a[0])} ${f(a[1])} '
            '${f(a[2])} ${f(a[3])} ${f(a[4])} ${f(a[5])}');
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
        segs.add('C ${f(x)} ${f(y)} ${f(r1x)} ${f(r1y)} '
            '${f(a[0])} ${f(a[1])} ${f(a[2])} ${f(a[3])}');
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
        segs.add('A ${f(x)} ${f(y)} ${f(nx)} ${f(ny)} ${f(v[0])} ${f(v[4])}');
        x = nx;
        y = ny;
        c2x = null;
        break;
      case 'Z':
      case 'z':
        segs.add('L ${f(x)} ${f(y)} ${f(sx)} ${f(sy)}');
        x = sx;
        y = sy;
        break;
      default:
        fail('bilinmeyen path komutu "$cmd": $d');
    }
  }
  return segs;
}

/// `..moveTo/..lineTo/..cubicTo/..arcToPoint` zincirini mutlak parçalara çevirir.
List<String> dartPath(String src) {
  final segs = <String>[];
  double x = 0, y = 0;
  final opRe = RegExp(r'\.\.(moveTo|lineTo|cubicTo|arcToPoint|close)\(');
  double startX = 0, startY = 0;
  for (final m in opRe.allMatches(src)) {
    final arg = balanced(src, m.end);
    switch (m.group(1)) {
      case 'moveTo':
        final v = nums(arg);
        x = v[0];
        y = v[1];
        startX = x;
        startY = y;
        break;
      case 'lineTo':
        final v = nums(arg);
        segs.add('L ${f(x)} ${f(y)} ${f(v[0])} ${f(v[1])}');
        x = v[0];
        y = v[1];
        break;
      case 'cubicTo':
        final v = nums(arg);
        segs.add('C ${f(x)} ${f(y)} ${f(v[0])} ${f(v[1])} '
            '${f(v[2])} ${f(v[3])} ${f(v[4])} ${f(v[5])}');
        x = v[4];
        y = v[5];
        break;
      case 'close':
        // SVG `Z`nin karşılığı: başlangıca kapanan çizgi.
        segs.add('L ${f(x)} ${f(y)} ${f(startX)} ${f(startY)}');
        x = startX;
        y = startY;
        break;
      default:
        final off = nums(RegExp(r'Offset\(([^)]*)\)').firstMatch(arg)!.group(1)!);
        final r = double.parse(
            RegExp(r'Radius\.circular\(([\d.]+)\)').firstMatch(arg)!.group(1)!);
        final sweep = arg.contains('clockwise: true') ? 1.0 : 0.0;
        segs.add('A ${f(x)} ${f(y)} ${f(off[0])} ${f(off[1])} '
            '${f(r)} ${f(sweep)}');
        x = off[0];
        y = off[1];
    }
  }
  return segs;
}

/// `start` açılış parantezinin HEMEN ardındaki konumsa, kapanışına kadarki metin.
String balanced(String src, int start) {
  var depth = 1, i = start;
  while (depth > 0) {
    expect(i < src.length, isTrue, reason: 'parantez dengesiz');
    if (src[i] == '(') depth++;
    if (src[i] == ')') depth--;
    i++;
  }
  return src.substring(start, i - 1);
}
