// Mini test çatısı — package:test bilinçli olarak KULLANILMIYOR (sıfır
// bağımlılık, offline `dart pub get`; bkz. pubspec.yaml notu).
import 'dart:io';

int _failures = 0;
int _checks = 0;

int get failureCount => _failures;

void check(bool cond, String Function() msg) {
  _checks++;
  if (!cond) {
    _failures++;
    stderr.writeln('FAIL: ${msg()}');
  }
}

void summarizeAndExit() {
  if (_failures == 0) {
    stdout.writeln('OK — $_checks kontrol, 0 hata');
    exit(0);
  }
  stderr.writeln('BAŞARISIZ — $_checks kontrol, $_failures hata');
  exit(1);
}

/// JSON değerleri için derin eşitlik; uyuşmazlıkta ilk farkın yolunu döner
/// (eşitse null).
String? jsonDiff(Object? expected, Object? actual, [String path = r'$']) {
  if (expected is Map && actual is Map) {
    for (final k in expected.keys) {
      if (!actual.containsKey(k)) return '$path.$k (beklenen anahtar yok)';
      final d = jsonDiff(expected[k], actual[k], '$path.$k');
      if (d != null) return d;
    }
    for (final k in actual.keys) {
      if (!expected.containsKey(k)) return '$path.$k (fazladan anahtar)';
    }
    return null;
  }
  if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      return '$path (uzunluk ${expected.length} != ${actual.length})';
    }
    for (var i = 0; i < expected.length; i++) {
      final d = jsonDiff(expected[i], actual[i], '$path[$i]');
      if (d != null) return d;
    }
    return null;
  }
  if (expected is num && actual is num) {
    // JSON'da 5 ile 5.0 aynı değer sayılır.
    return expected.toDouble() == actual.toDouble() ? null : '$path ($expected != $actual)';
  }
  return expected == actual ? null : '$path ($expected != $actual)';
}
