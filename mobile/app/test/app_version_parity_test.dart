// Ürün sürümü TEK KAYNAK: `pubspec.yaml`. `env.dart`teki `appVersion` sabiti
// onun elle tutulan kopyası — ve bu testten önce onu koruyan HİÇBİR ŞEY
// yoktu.
//
// NEDEN ÖNEMLİ (23 Ağustos 2026, mağaza öncesi denetim): `appVersion` yalnızca
// bir teşhis metni değil, ZORUNLU GÜNCELLEME KAPISININ girdisi —
// `version_gate.dart` onu `app_config.mobile_min_supported_version` ile
// karşılaştırıyor. İki kopya ayrışırsa hata sinsi ve ağır:
//
//   pubspec 0.2.0'a çıkar, env 0.1.0'da kalır, mağazaya 0.2.0 yüklenir.
//   Sen "herkes güncelledi" deyip eşiği 0.2.0 yaparsın. GÜNCELLEMİŞ
//   kullanıcılar kendini hâlâ 0.1.0 bildirdiğinden hepsi uygulamadan
//   KİLİTLENİR — üstelik güncelleyerek çıkamazlar.
//
// Ters yön de bozuk: env ileride kalırsa eşik hiç tutmaz ve kapı sessizce
// devre dışı kalır.
//
// Derleyici bunu göremez (iki taraf da düz metin), CI'da bunu yakalayan tek
// şey bu test. Projedeki `rank_tiers_parity_test`/`client_platform_parity_test`
// ile aynı desen: KANONİK kaynağı dosyadan oku, kopyayla karşılaştır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/config/env.dart';

void main() {
  test('env.dart appVersion, pubspec.yaml sürümüyle birebir aynı', () {
    // `flutter test` her zaman `mobile/app`ten koşuyor; yol yine de dosyanın
    // varlığıyla doğrulanıyor ki sessizce boş bir eşleşmeye düşmeyelim.
    final pubspec = File('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue,
        reason: 'pubspec.yaml bulunamadı — test mobile/app dizininden koşmalı');

    // `version: 0.1.0+1` → sürüm kısmı '+' işaretinden ÖNCESİ. Build numarası
    // (`+1`) mağaza için ayrı bir sayaç ve `appVersion`da yeri YOK — semver
    // karşılaştırması (`compareSemver`) onu ayrıştıramaz.
    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(\+\d+)?\s*$',
            multiLine: true)
        .firstMatch(pubspec.readAsStringSync());
    expect(match, isNotNull,
        reason: 'pubspec.yaml içinde `version: X.Y.Z(+N)` satırı bulunamadı');

    expect(
      appVersion,
      match!.group(1),
      reason: 'env.dart:appVersion ile pubspec.yaml:version AYRIŞTI. '
          'Sürüm yükseltirken İKİSİNİ birden değiştir — aksi halde zorunlu '
          'güncelleme kapısı yanlış sürümle karşılaştırır ve güncel '
          'kullanıcıları uygulamadan kilitleyebilir.',
    );
  });
}
