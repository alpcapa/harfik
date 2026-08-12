// Minimum sürüm kapısı — app_config.mobile_min_supported_version
// (20260805225630 migration'ı) açılışta okunur; bu binary eşiğin altındaysa
// UpdateRequiredScreen gösterilir.
//
// FAIL-OPEN: tabloya ulaşılamazsa (offline, Supabase yapılandırılmamış,
// zaman aşımı) kapı GEÇİLİR — yerel YZ oyunu offline bir haktır, sürüm
// kontrolü onu rehin alamaz. Eşik yalnızca sunucu SÖZLEŞMESİ kırıldığında
// yükseltilir; offline oyuncu zaten o sözleşmeyi kullanmıyor.
import 'dart:io' show Platform;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/semver.dart';
import 'env.dart';

enum VersionGateStatus {
  /// Sürüm yeterli ya da kontrol yapılamadı (fail-open).
  ok,

  /// Sunucu eşiği bu binary'den yüksek — güncelleme zorunlu.
  updateRequired,
}

Future<VersionGateStatus> checkVersionGate(SupabaseClient? client) async {
  if (client == null) return VersionGateStatus.ok;
  try {
    final row = await client
        .from('app_config')
        .select('value')
        .eq('key', 'mobile_min_supported_version')
        .maybeSingle()
        .timeout(const Duration(seconds: 5));
    final value = row?['value'];
    if (value is! Map) return VersionGateStatus.ok;
    final platformKey = Platform.isIOS ? 'ios' : 'android';
    final min = value[platformKey];
    if (min is! String || min.isEmpty) return VersionGateStatus.ok;
    return compareSemver(appVersion, min) < 0
        ? VersionGateStatus.updateRequired
        : VersionGateStatus.ok;
  } catch (_) {
    return VersionGateStatus.ok; // fail-open
  }
}
