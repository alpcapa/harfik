// Hücre kümesi → tamamen yuvarlatılmış dış hat Path'i —
// src/utils/outline.ts'in birebir portu, çıktı SVG dizesi yerine ui.Path
// (karar: mobile/CLAUDE.md — algoritma taşınır, çıktı platforma uyar).
// Koordinatlar IZGARA BİRİMİ cinsindendir (0..13); çizen taraf ölçekler.
//
// Web'deki gerekçe aynen geçerli: hücre başına CSS border yalnızca dışbükey
// köşeleri yuvarlar; genişleyen bölge kollarının İÇBÜKEY köşeleri de aynı
// yarıçapla yuvarlanmalı. extraOpen, kümenin dışına bakan bir kenarı da
// "çizgisiz" sayabilmek için (açık uçlu zincirler desteklenir).
import 'dart:ui';

typedef ExtraOpen = bool Function(int r, int c, int nr, int nc);

List<List<Offset>> _traceEdges(List<(int, int)> cells, ExtraOpen? extraOpen) {
  final cellSet = {for (final c in cells) '${c.$1},${c.$2}'};
  bool isOpen(int r, int c, int nr, int nc) =>
      cellSet.contains('$nr,$nc') ||
      (extraOpen != null && extraOpen(r, c, nr, nc));

  final out = <String, List<Offset>>{};
  final inCount = <String, int>{};
  void addEdge(Offset a, Offset b) {
    final ak = '${a.dx.toInt()},${a.dy.toInt()}';
    final bk = '${b.dx.toInt()},${b.dy.toInt()}';
    (out[ak] ??= []).add(b);
    inCount[bk] = (inCount[bk] ?? 0) + 1;
  }

  for (final cell in cells) {
    final r = cell.$1, c = cell.$2;
    final x = c.toDouble(), y = r.toDouble();
    if (!isOpen(r, c, r - 1, c)) addEdge(Offset(x, y), Offset(x + 1, y));
    if (!isOpen(r, c, r, c + 1)) {
      addEdge(Offset(x + 1, y), Offset(x + 1, y + 1));
    }
    if (!isOpen(r, c, r + 1, c)) {
      addEdge(Offset(x + 1, y + 1), Offset(x, y + 1));
    }
    if (!isOpen(r, c, r, c - 1)) addEdge(Offset(x, y + 1), Offset(x, y));
  }

  Offset? popEdge(Offset p) {
    final list = out['${p.dx.toInt()},${p.dy.toInt()}'];
    if (list == null || list.isEmpty) return null;
    return list.removeLast();
  }

  Offset parseKey(String k) {
    final i = k.indexOf(',');
    return Offset(
        double.parse(k.substring(0, i)), double.parse(k.substring(i + 1)));
  }

  final paths = <List<Offset>>[];

  // 1) Gelen kenarı olmayan noktalar gerçek "açık uç" başlangıcıdır.
  for (final startKey in out.keys.toList()) {
    if ((inCount[startKey] ?? 0) > 0) continue;
    while ((out[startKey]?.length ?? 0) > 0) {
      final startPt = parseKey(startKey);
      final path = <Offset>[startPt];
      var cur = startPt;
      for (;;) {
        final next = popEdge(cur);
        if (next == null) break;
        path.add(next);
        cur = next;
      }
      if (path.length > 1) paths.add(path);
    }
  }

  // 2) Geriye kalan her şey kapalı halka olmalı.
  for (final startKey in out.keys.toList()) {
    while ((out[startKey]?.length ?? 0) > 0) {
      final startPt = parseKey(startKey);
      final path = <Offset>[startPt];
      var cur = startPt;
      for (;;) {
        final next = popEdge(cur);
        if (next == null) break;
        path.add(next);
        if (next == startPt) break;
        cur = next;
      }
      if (path.length > 1) paths.add(path);
    }
  }

  return paths;
}

/// Ardışık, aynı yöndeki (düz devam eden) noktaları atar.
List<Offset> _simplifyPath(List<Offset> pts) {
  final closed = pts.length > 2 && pts.first == pts.last;
  final core = closed ? pts.sublist(0, pts.length - 1) : pts;
  final n = core.length;
  if (n < 3) return pts;
  final result = <Offset>[];
  for (var i = 0; i < n; i++) {
    if (!closed && (i == 0 || i == n - 1)) {
      result.add(core[i]);
      continue;
    }
    final prev = core[(i - 1 + n) % n];
    final cur = core[i];
    final next = core[(i + 1) % n];
    final d1 = cur - prev;
    final d2 = next - cur;
    final cross = d1.dx * d2.dy - d1.dy * d2.dx;
    final sameDir = d1.dx * d2.dx + d1.dy * d2.dy > 0;
    if (cross == 0 && sameDir) continue;
    result.add(cur);
  }
  if (closed) result.add(result.first);
  return result;
}

Offset _offsetPoint(Offset from, Offset to, double dist) {
  final len = (to - from).distance;
  if (len == 0) return from;
  final t = (dist < len / 2 ? dist : len / 2) / len;
  return from + (to - from) * t;
}

void _addRoundedLoop(Path path, List<Offset> pts, double radius) {
  final core = pts.sublist(0, pts.length - 1);
  final n = core.length;
  if (n < 2) return;
  for (var i = 0; i < n; i++) {
    final prev = core[(i - 1 + n) % n];
    final cur = core[i];
    final next = core[(i + 1) % n];
    final inPt = _offsetPoint(cur, prev, radius);
    final outPt = _offsetPoint(cur, next, radius);
    if (i == 0) {
      path.moveTo(inPt.dx, inPt.dy);
    } else {
      path.lineTo(inPt.dx, inPt.dy);
    }
    path.quadraticBezierTo(cur.dx, cur.dy, outPt.dx, outPt.dy);
  }
  path.close();
}

void _addRoundedOpen(Path path, List<Offset> pts, double radius) {
  final n = pts.length;
  if (n < 2) return;
  path.moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < n - 1; i++) {
    final inPt = _offsetPoint(pts[i], pts[i - 1], radius);
    final outPt = _offsetPoint(pts[i], pts[i + 1], radius);
    path.lineTo(inPt.dx, inPt.dy);
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, outPt.dx, outPt.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
}

/// Hücre kümesinin dış hattı (delikler/ayrık parçalar dahil) — köşeleri
/// `radius` (ızgara birimi) kadar yuvarlatılmış tek Path. Boş küme → boş Path.
Path buildRoundedOutlinePath(
  List<(int, int)> cells,
  double radius, {
  ExtraOpen? extraOpen,
}) {
  final path = Path();
  for (final raw in _traceEdges(cells, extraOpen)) {
    final p = _simplifyPath(raw);
    final closed = p.length > 2 && p.first == p.last;
    if (closed) {
      _addRoundedLoop(path, p, radius);
    } else {
      _addRoundedOpen(path, p, radius);
    }
  }
  return path;
}
