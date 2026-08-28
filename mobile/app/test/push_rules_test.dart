// `util/push_rules.dart` — bildirim izni SORMA kararı.
//
// Neden bu kadar iddia var: Android 13+'ta ikinci redden sonra sistem
// diyaloğu bir daha açılmıyor, yani yanlış bir "sor" kararı GERİ ALINAMAZ.
// Karar saf bir fonksiyonda tutuluyor ki bu kurallar gözle değil testle
// korunsun.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/platform.dart';
import 'package:kelimeki/src/util/push_rules.dart';

/// Repo kökü — testler `mobile/app`'ten koşuyor.
final _root = Directory.current.path.endsWith('mobile/app')
    ? Directory('../..')
    : Directory('.');

void main() {
  final t0 = DateTime.utc(2026, 8, 28, 12);

  bool sor({
    bool aktifOyunVar = true,
    bool izinZatenVerildi = false,
    bool kaliciReddedildi = false,
    int soruldu = 0,
    DateTime? sonSorulma,
    DateTime? simdi,
  }) =>
      pushIzniSorulmali(
        aktifOyunVar: aktifOyunVar,
        izinZatenVerildi: izinZatenVerildi,
        kaliciReddedildi: kaliciReddedildi,
        soruldu: soruldu,
        sonSorulma: sonSorulma,
        simdi: simdi ?? t0,
      );

  test('aktif oyun YOKSA sorulmaz — konum değil DURUM', () {
    expect(sor(aktifOyunVar: false), isFalse,
        reason: 'oyunu olmayana, olmayan oyunlar için bildirim sorulmaz');
    expect(sor(aktifOyunVar: true), isTrue);
  });

  test('izin zaten verilmişse ya da KALICI reddedilmişse sorulmaz', () {
    expect(sor(izinZatenVerildi: true), isFalse);
    // Kalıcı rette sormak çifte zarar: sayfa çıkar, kullanıcı "Aç"a basar,
    // sistem diyaloğu HİÇ açılmaz ve kişi hiçbir şey olmadığını görür.
    expect(sor(kaliciReddedildi: true), isFalse);
  });

  test('azami üç kez', () {
    expect(sor(soruldu: 2, sonSorulma: t0.subtract(const Duration(days: 30))),
        isTrue);
    expect(sor(soruldu: 3, sonSorulma: t0.subtract(const Duration(days: 30))),
        isFalse, reason: 'üçüncüden sonra bir daha sorulmaz');
  });

  test('iki sorma arasında en az yedi gün', () {
    expect(sor(soruldu: 1, sonSorulma: t0.subtract(const Duration(days: 6, hours: 23))),
        isFalse, reason: 'yedi gün dolmadan tekrar sorulmaz');
    expect(sor(soruldu: 1, sonSorulma: t0.subtract(const Duration(days: 7))),
        isTrue, reason: 'tam yedi gün dolduğunda sorulabilir');
  });

  test('hiç sorulmadıysa aralık aranmaz', () {
    expect(sor(soruldu: 0, sonSorulma: null), isTrue);
  });

  group('pushPlatform — check kısıtına uymayan değer YOLLANMAZ', () {
    test('yalnızca android/ios geçer', () {
      expect(pushPlatform('android'), 'android');
      expect(pushPlatform('ios'), 'ios');
    });

    test("'app-web' ve null token KAYDETTİRMEZ", () {
      // `currentPlatform` telemetri için 'app-web' dönebiliyor; o değeri
      // olduğu gibi push_tokens'a yollamak insert'i check kısıtında düşürür
      // ve token hiç kaydedilmez — sessiz arıza.
      expect(pushPlatform('app-web'), isNull);
      expect(pushPlatform(null), isNull);
      expect(pushPlatform('web'), isNull);
      expect(pushPlatform('macos'), isNull);
    });
  });

  // `client_platform_parity_test.dart`ın aynı deseni: sunucudaki check kısıtı
  // KANONİK. İki kopyanın sessizce ayrışması bu kod tabanının en sık
  // tekrarlayan hata sınıfı — burada bedeli, token'ın hiç kaydedilmemesi ve
  // kullanıcının hiç bildirim almaması olurdu.
  test('pushPlatform kümesi, push_tokens check kısıtıyla birebir aynı', () {
    final sql = File('${_root.path}/supabase/migrations/'
            '20260828114349_push_tokens_and_preference.sql')
        .readAsStringSync();
    final m = RegExp(r"platform in \(([^)]*)\)").firstMatch(sql);
    expect(m, isNotNull, reason: 'Migration platform kısıtını saymalı');
    final sqlDegerleri = RegExp("'([^']+)'")
        .allMatches(m!.group(1)!)
        .map((v) => v.group(1)!)
        .toSet();

    // `pushPlatform`ın GEÇİRDİĞİ küme, SQL'in kabul ettiğiyle aynı olmalı.
    final gecenler = {
      for (final p in {...kClientPlatforms, 'macos', 'linux', 'windows'})
        if (pushPlatform(p) != null) p,
    };
    expect(gecenler, sqlDegerleri);
  });

  test('currentPlatform → pushPlatform zinciri her hedefte güvenli', () {
    // Asıl korunan şey bu zincir: telemetrinin platformu doğrudan
    // push_tokens'a AKTARILAMAZ.
    for (final target in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = target;
      final p = pushPlatform(currentPlatform);
      if (p != null) expect({'android', 'ios'}, contains(p));
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
