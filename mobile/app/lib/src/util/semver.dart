// Basit semver karşılaştırması — yalnızca sürüm kapısı için.
// "1.2.3" biçimini bekler; eksik alanlar 0 sayılır, "-beta"/"+build" ekleri
// yok sayılır (mağaza sürümlerimiz düz X.Y.Z, ön-sürüm sıralaması gereksiz).

int compareSemver(String a, String b) {
  List<int> parse(String s) {
    final core = s.split(RegExp(r'[-+]')).first;
    final parts = core.split('.');
    return [
      for (var i = 0; i < 3; i++)
        i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    ];
  }

  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i] < pb[i] ? -1 : 1;
  }
  return 0;
}
