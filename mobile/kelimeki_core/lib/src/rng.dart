// Kelimeki core — enjekte edilebilir rastgelelik (src/utils/random.ts portu).
//
// Determinizm sözleşmesi: core hiçbir yerde kendi başına Random()/DateTime
// üretmez — GameEngine'e bir Rng enjekte edilir. Golden vector testleri
// TS tarafındaki mulberry32 ile BİREBİR aynı bit dizisini üreten Mulberry32'yi
// kullanır; uygulama SystemRng kullanır.
import 'dart:math' as math;

abstract interface class Rng {
  /// [0, 1) aralığında double — JS Math.random() sözleşmesi.
  double nextDouble();
}

/// Üretim: dart:math Random sarmalayıcısı.
class SystemRng implements Rng {
  final math.Random _r;
  SystemRng([math.Random? r]) : _r = r ?? math.Random();
  @override
  double nextDouble() => _r.nextDouble();
}

/// Test/replay: JS'teki mulberry32 ile bit-eş PRNG. 32-bit işlemler Dart'ın
/// 64-bit int'i üzerinde maskeyle taklit edilir (VM'de tam; dart2js'te
/// ÇALIŞMAZ — bkz. mobile/CLAUDE.md, bilinçli sınır).
class Mulberry32 implements Rng {
  int _a;
  Mulberry32(int seed) : _a = seed & 0xFFFFFFFF;

  static int _imul(int x, int y) {
    // JS Math.imul: 32-bit işaretli çarpma; burada işaretsiz 32-bit sonuca
    // maskeliyoruz (sonraki tüm kullanımlar zaten maskeli/işaretsiz).
    return (x * y) & 0xFFFFFFFF;
  }

  @override
  double nextDouble() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _a;
    t = _imul(t ^ (t >> 15), t | 1) & 0xFFFFFFFF;
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  }
}

/// Fisher–Yates: diziyi YERİNDE karıştırır ve aynı listeyi döndürür.
/// (TS: shuffle — Math.floor(random()*(i+1)) ile aynı adımlar.)
List<T> shuffleList<T>(List<T> a, Rng rng) {
  for (var i = a.length - 1; i > 0; i--) {
    final j = (rng.nextDouble() * (i + 1)).floor();
    final tmp = a[i];
    a[i] = a[j];
    a[j] = tmp;
  }
  return a;
}
