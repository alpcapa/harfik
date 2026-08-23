// Sürüm — `pubspec.yaml` KANONİK kaynaktır.
//
// NEDEN VAR (22 Ağustos 2026, Play yüklemesi hazırlığı): sürüm İKİ yerde
// elle senkron tutuluyor ve ikisi de bunu başlığında yazıyor
// (`env.dart` → "pubspec.yaml'daki `version` ile BİRLİKTE artırılır"), ama
// bugüne kadar hiçbir şey bunu ZORLAMIYORDU — biri artırılıp öteki
// unutulsa `dart analyze` de testler de yeşil kalırdı.
//
// AYRIŞMANIN BEDELİ SESSİZ VE GEÇ ÇIKAR: `pubspec.yaml`'ın `version`'ı
// Play'e giden `versionName`'i belirler, `env.dart`'ın `appVersion`'ı ise
// (a) Setup ekranındaki "Sürüm x.y.z" satırını ve (b) minimum sürüm
// kapısını (`version_gate.dart`, `app_config.mobile_min_supported_version`
// ile karşılaştırılıyor) besler. İkisi ayrışırsa mağazadaki sürüm ile
// kullanıcının GÖRDÜĞÜ sürüm farklı olur ve — asıl tehlikeli olan —
// eşik yükseltildiğinde kapı YANLIŞ sürümü karşılaştırır: gerçekte
// yeterli bir binary "güncelleme zorunlu" ekranında kilitlenebilir ya da
// tersine, eski bir binary kapıdan geçebilir.
//
// `+N` (build number) KASITLI OLARAK karşılaştırma dışında: CI onu
// `--build-number=${{ github.run_number }}` ile eziyor (Play aynı
// versionCode'u iki kez kabul etmiyor), yani pubspec'teki değer zaten
// bağlayıcı değil. Karşılaştırılan şey `+`'dan ÖNCEKİ semver.
//
// Desen `rank_tiers_parity_test.dart`/`color_tokens_test.dart` ile aynı:
// kaynak dosyayı oku, ayrıştır, karşılaştır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/config/env.dart';

void main() {
  test('env.dart appVersion, pubspec.yaml sürümüyle aynı', () {
    // Testler `mobile/app`'ten koşuyor.
    final pubspec = File('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue,
        reason: 'pubspec.yaml bulunamadı — test `mobile/app` içinden koşmalı.');

    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?\s*$',
            multiLine: true)
        .firstMatch(pubspec.readAsStringSync());
    expect(match, isNotNull,
        reason: 'pubspec.yaml içinde `version: x.y.z(+N)` satırı okunamadı.');

    expect(
      appVersion,
      match!.group(1),
      reason: 'Sürüm İKİ yerde birden artırılmalı: pubspec.yaml `version` ve '
          'lib/src/config/env.dart `appVersion`.',
    );
  });
}
