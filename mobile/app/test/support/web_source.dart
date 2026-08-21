// Web kaynağını okuyup değer çeken parite testlerinin ortak yardımcıları.
//
// Kullananlar: `layout_parity_test.dart`, `icon_parity_test.dart`.
// (`help_text_parity_test`/`legal_text_test`/`rank_tiers_parity_test` kendi
// okuyucularını taşıyor — onlar bu dosyadan ÖNCE yazıldı, dokunulmadı.)
//
// ⚠ EN ÖNEMLİ KURAL: aranan şey BULUNAMAZSA test DÜŞER, geçmez. Bir web
// sabitinin adı değişince testin sessizce hiçbir şey karşılaştırmayıp yeşil
// kalması ("boşa geçen test") bu dosyadaki `expect`lerle engelleniyor.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Testler `mobile/app` dizininden de repo kökünden de koşabiliyor.
final Directory repoRoot = Directory.current.path.endsWith('mobile/app')
    ? Directory('../..')
    : Directory('.');

String readRepoFile(String rel) =>
    File('${repoRoot.path}/$rel').readAsStringSync();

/// İlk eşleşmenin 1. grubu. Eşleşme yoksa testi DÜŞÜRÜR.
String pick(String src, RegExp re, String ne) {
  final m = re.firstMatch(src);
  expect(m, isNotNull,
      reason: '$ne bulunamadı — kaynağın yapısı değiştiyse bu testin '
          'ayrıştırıcısı da güncellenmeli');
  return m!.group(1)!;
}

/// Tüm eşleşmelerin 1. grubu. Hiç eşleşme yoksa testi DÜŞÜRÜR.
List<String> pickAll(String src, RegExp re, String ne) {
  final out = [for (final m in re.allMatches(src)) m.group(1)!];
  expect(out, isNotEmpty,
      reason: '$ne hiç bulunamadı — ayrıştırıcıyı güncelle');
  return out;
}
