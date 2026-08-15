// Platform değer kümesi — sunucudaki check kısıtı KANONİK kaynaktır.
//
// NEDEN VAR: `currentPlatform`ın döndürdüğü dize doğrudan `games.platform`
// sütununa yazılıyor ve o sütunda bir check kısıtı var. Kısıtta olmayan bir
// değer yollamak insert'i düşürür — yani bir TELEMETRİ alanı yüzünden oyun
// KAYDI kaybolur (skor, k-lig puanı, hamle dökümü). Derleyici bunu
// göremez: iki taraf da sadece `String`.
//
// Test, migration SQL'ini okuyup `kClientPlatforms` ile karşılaştırıyor
// (`rank_tiers_parity_test.dart`ın web kaynağını okuyan deseninin aynısı) ve
// ayrıca `currentPlatform`ın HER hedefte bu kümenin içinde (ya da null)
// kaldığını doğruluyor.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/platform.dart';

/// Repo kökü — testler `mobile/app`'ten koşuyor.
final _root = Directory.current.path.endsWith('mobile/app')
    ? Directory('../..')
    : Directory('.');

void main() {
  test('kClientPlatforms, migration check kısıtıyla birebir aynı', () {
    final sql = File('${_root.path}/supabase/migrations/'
            '20260814204059_games_platform.sql')
        .readAsStringSync();
    // Kısıt SQL'de üç kez geçiyor (games.platform, online_game_clients.platform
    // ve RPC'nin girdi doğrulaması) — ÜÇÜ de aynı kümeyi saymak zorunda,
    // biri güncellenip diğeri unutulursa satır ya reddedilir ya sessizce
    // atlanır.
    final matches =
        RegExp(r"platform (?:is null or platform )?(?:not )?in \(([^)]*)\)")
            .allMatches(sql)
            .toList();
    expect(matches.length, 3,
        reason: 'Migration üç yerde de platform kümesini saymalı');
    for (final m in matches) {
      final values = RegExp("'([^']+)'")
          .allMatches(m.group(1)!)
          .map((v) => v.group(1)!)
          .toSet();
      expect(values, kClientPlatforms);
    }
  });

  test('currentPlatform her hedefte geçerli bir değer (ya da null) döner', () {
    for (final target in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = target;
      final p = currentPlatform;
      if (p != null) expect(kClientPlatforms, contains(p));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS ve Android kendi değerlerini döner', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(currentPlatform, 'ios');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(currentPlatform, 'android');
    // Yayınlanmayan bir hedef: uydurma bir değer YERİNE null — sütun
    // nullable olduğundan satır sorunsuz kaydedilir, yalnızca ölçülmez.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(currentPlatform, isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
